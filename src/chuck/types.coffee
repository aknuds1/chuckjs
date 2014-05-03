# ChucK type library
define("chuck/types", ["chuck/audioContextService", "chuck/namespace", "chuck/logging"],
(audioContextService, namespace, logging) ->
  module = {}
  TwoPi = Math.PI*2

  module.ChuckType = class ChuckType
    constructor: (name, parent, opts, constructorCb) ->
      opts = opts || {}
      @name = name
      @parent = parent
      @size = opts.size
      @_constructor = constructorCb
      @_opts = opts
      @_namespace = new namespace.Namespace()
      @isRef = opts.isRef || false

      @_constructParent(parent, @_opts)

      if constructorCb?
        constructorCb.call(@, @_opts)

      opts.namespace = opts.namespace || {}
      for own k, v of opts.namespace
        memberType = if v instanceof ChuckFunctionBase then types.Function else undefined
        @_namespace.addVariable(k, memberType, v)

    isOfType: (otherType) =>
      if @name == otherType.name
        return true

      parent = @parent
      while parent?
        if parent.isOfType(otherType)
          return true
        parent = parent.parent

      return false

    findValue: (name) =>
      val = @_namespace.findValue(name)
      if val?
        return val
      if @parent?
        return @parent.findValue(name)
      return

    _constructParent: (parent, opts) =>
      if !parent?
        return

      opts = _({}).extend(parent._opts).extend(opts).value()
      @_constructParent(parent.parent, opts)
      if parent._constructor?
        parent._constructor.call(@, opts)

  types = module.types = {}

  types.int = new ChuckType("int", undefined, size: 8, preConstructor: undefined)
  types.float = new ChuckType("float", undefined, size: 8, preConstructor: undefined)
  types.Time = new ChuckType("time", undefined, size: 8, preConstructor: undefined)
  types.dur = new ChuckType("dur", undefined, size: 8, preConstructor: undefined)
  types.String = new ChuckType("String", undefined, size: 8, preConstructor: undefined, isRef: true)

  module.FuncArg = class FuncArg
    constructor: (name, type) ->
      @name = name
      @type = type

  module.FunctionOverload = class FunctionOverload
    constructor: (args, func, @isBuiltIn=true, @name=null) ->
      args = if args? then args else []
      @arguments = args
      @func = func
      @stackDepth = args.length

    apply: (obj) =>
      @func.apply(arguments[0], arguments[1])

  class ChuckFunctionBase
    constructor: (name, overloads, isMember, typeName, retType) ->
      if !retType?
        throw new Error('retType unspecified')

      @name = name
      @isMember = isMember
      @_overloads = []
      @retType = retType
      @_typeName = typeName

      for overload in overloads
        @addOverload(overload)

    addOverload: (overload) ->
      if @_typeName
        overload.name = "#{overload.name}@#{@_typename}"
      overload.isMember = @isMember
      overload.retType = @retType
      if @isMember
        # Needs 'this' argument
        ++overload.stackDepth
      @_overloads.push(overload)

    findOverload: (args) ->
      args = if args? then args else []
      for mthd in @_overloads
        if mthd.arguments.length != args.length
          continue

        if !_.every(mthd.arguments, (a, index) ->
          a.type == args[index].type || (a.type == types.float && args[index].type == types.int))
          continue

        # logging.debug("#{@nodeType} scanPass4: Found matching overload with #{args.length} argument(s)")
        return mthd

      #logging.debug("#{@nodeType} scanPass4: Couldn't find matching method overload")
      null

    getNumberOfOverloads: ->
      @_overloads.length

  module.ChuckMethod = class ChuckMethod extends ChuckFunctionBase
    constructor: (name, overloads, typeName, retType) ->
      super(name, overloads, true, typeName, retType)

  module.ChuckStaticMethod = class ChuckStaticMethod extends ChuckFunctionBase
    constructor: (name, overloads, typeName, retType) ->
      super(name, overloads, false, typeName, retType)
      @isStatic = true

  module.ChuckFunction = class ChuckFunction extends ChuckFunctionBase
    constructor: (name, overloads, retType) ->
      super(name, overloads, false, null, retType)

  types.Function = new ChuckType("Function", null, null)
  constructObject = ->
  types.Object = new ChuckType("Object", undefined, preConstructor: constructObject, (opts) ->
    @hasConstructor = opts.preConstructor?
    @preConstructor = opts.preConstructor
    @size = opts.size
  )
  module.Class = new ChuckType("Class", types.Object)
  ugenNamespace =
    gain: new ChuckMethod("gain", [new FunctionOverload([new FuncArg("value", types.float)], (value) ->
      @setGain(value)
    )], "UGen", types.float)
  types.UGen = new ChuckType("UGen", types.Object, size: 8, numIns: 1, numOuts: 1, preConstructor: undefined,
  namespace: ugenNamespace, ugenTick: undefined
  (opts) ->
    @ugenNumIns = opts.numIns
    @ugenNumOuts = opts.numOuts
    @ugenTick = opts.ugenTick
  )
  class OscData
    constructor: ->
      @num = 0.0
      @sync = 0
      @width = 0.5
      @phase = 0
  oscNamespace =
    freq: new ChuckMethod("freq", [new FunctionOverload([new FuncArg("value", types.float)], (value) ->
      @setFrequency(value)
    )], "Osc", types.float)
  constructOsc = ->
    @data = new OscData()
    @setFrequency = (value) ->
      @data.num = (1/audioContextService.getSampleRate()) * value
      return value
    @setFrequency(220)
  types.Osc = new ChuckType("Osc", types.UGen, numIns: 1, numOuts: 1, preConstructor: constructOsc,
  namespace: oscNamespace)

  tickSinOsc = ->
    out = Math.sin(@data.phase * TwoPi)
    @data.phase += @data.num
    if @data.phase > 1
      @data.phase -= 1
    else if @data.phase < 0
      @data.phase += 1
    out
  types.SinOsc = new ChuckType("SinOsc", types.Osc, preConstructor: undefined, ugenTick: tickSinOsc)
  types.UGenStereo = new ChuckType("Ugen_Stereo", types.UGen, numIns: 2, numOuts: 2, preConstructor: undefined)
  constructDac = ->
    @_node = audioContextService.outputNode
  types.Dac = new ChuckType("Dac", types.UGenStereo, preConstructor: constructDac)
  types.void = new ChuckType("void")

  module.isObj = (type) ->
    return !module.isPrimitive(type)

  module.isPrimitive = (type) ->
    return type == types.dur || type == types.Time || type == types.int || type == types.float

  types.Gain = new ChuckType("Gain", types.UGenStereo)

  stepNamespace =
    next: new ChuckMethod("next", [new FunctionOverload([new FuncArg("value", types.float)], (value) ->
      # logging.debug("Step Oscillator: Setting value #{value} for next")
      @data.next = value
    )], "Step", types.float)
  constructStep = ->
    @data.next = 1
  tickStep = ->
    @data.next
  types.Step = new ChuckType("Step", types.Osc, namespace: stepNamespace, preConstructor: constructStep,
  ugenTick: tickStep)

  constructEnvelope = ->
    @data =
      target: 0
      value: 0
  types.Envelope = new ChuckType("Envelope", types.UGen, preConstructor: constructEnvelope)

  adsrNamespace =
    set: new ChuckMethod("set", [new FunctionOverload([
      new FuncArg("attack", types.dur), new FuncArg("decay", types.dur),
      new FuncArg("sustain", types.float), new FuncArg("release", types.dur)],
      (attack, decay, sustainLevel, release)  ->
        computeRate = (target, time) -> target / time
        d = @data
        d.attackRate = computeRate(1, attack)
        d.decayRate = computeRate(1-sustainLevel, decay)
        d.releaseRate = computeRate(sustainLevel, release)
        d.sustainLevel = sustainLevel
        # logging.debug("Having set ADSR parameters, at attack state: #{d.attackRate}, #{d.decayRate}, #{d.sustainLevel}, #{d.releaseRate}")
      )], "ADSR", types.void)
    keyOn: new ChuckMethod("keyOn", [new FunctionOverload([], ->
      logging.debug("keyOn state")
      @data.target = 1
      @data.rate = @data.attackRate
      @data.state = "attack"
    )], "ADSR", types.void)
    keyOff: new ChuckMethod("keyOff", [new FunctionOverload([], ->
      logging.debug("keyOff state")
      @data.rate = @data.releaseRate
      @data.target = 0
      @data.state = "release"
    )], "ADSR", types.void)
  constructAdsr = ->
    @data.attackRate = 0.001
    @data.decayRate = 0.001
    @data.sustainLevel = 0.5
    @data.releaseRate = 0.01
    @data.state = "attack"
    @data.rate = 1
    @data.value = 0
  tickAdsr = (input) ->
    d = @data
    switch d.state
      when "attack"
        d.value += d.rate
        # logging.debug("Attack state: value set to #{d.value}")
        if d.value >= d.target
          d.value = d.target
          d.rate = d.decayRate
          d.target = d.sustainLevel
          d.state = "decay"
          logging.debug("Transitioned to decay state, value: #{d.value}")
      when "decay"
        d.value -= d.decayRate
        # logging.debug("Decay state: value set to #{d.value}")
        if d.value <= d.sustainLevel
          d.value = d.sustainLevel
          d.rate = 0
          d.state = "sustain"
          # logging.debug("Transitioned to sustain state, value: #{d.value}")
      when "release"
        d.value -= d.rate
        # logging.debug("Release state: value set to #{d.value}")
        if d.value <= 0
          d.value = 0
          d.state = "done"
          # logging.debug("Transitioned to done state, value: #{d.value}")

    # logging.debug("State At end")
    input*d.value
  types.Adsr = new ChuckType("ADSR", types.Envelope, preConstructor: constructAdsr, namespace: adsrNamespace,
  ugenTick: tickAdsr)

  shredNamespace =
    args: new ChuckMethod("args", [new FunctionOverload([], ->
      @args.length
    )], "Shred", types.int)
    arg: new ChuckMethod("arg", [new FunctionOverload([new FuncArg("i", types.int)], (i) ->
      @args[i]
    )], "Shred", types.String)
  types.shred = new ChuckType("Shred", types.Object, namespace: shredNamespace)

  arrayNamespace =
    cap: new ChuckMethod("cap", [new FunctionOverload([], ->
      @.length
    )], "@array", types.int)
    size: new ChuckMethod("size", [new FunctionOverload([], ->
      @.length
    )], "@array", types.int)
  types["@array"] = new ChuckType("@array", types.Object, size: 1, namespace: arrayNamespace)

  module.createArrayType = (elemType, depth) ->
    type = new ChuckType(elemType.name, types["@array"])
    type.depth = depth
    type.arrayType = elemType
    type.isArray = true
    type

  return module
)
