# ChucK type library
define("chuck/types", ["chuck/audioContextService", "chuck/namespace"],
(audioContextService, namespace) ->
  module = {}

  class ChuckType
    constructor: (name, parent, opts, constructorCb) ->
      opts = opts || {}
      @name = name
      @parent = parent
      @_constructor = constructorCb
      @_opts = opts
      @_namespace = new namespace.Namespace()

      @_constructParent(parent, @_opts)

      if constructorCb?
        constructorCb.call(@, @_opts)

      opts.namespace = opts.namespace || {}
      for own k, v of opts.namespace
        memberType = if _(v).isFunction() then module.Function else undefined
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

      opts = _(parent._opts).extend(opts)
      @_constructParent(parent.parent, opts)
      if parent._constructor?
        parent._constructor.call(@, opts)

  module.Function = new ChuckType("Function", undefined)
  constructObject = ->
  module.Object = new ChuckType("Object", undefined, preConstructor: constructObject, (opts) ->
    @hasConstructor = opts.preConstructor?
    @preConstructor = opts.preConstructor
    @size = opts.size
  )
  ugenNamespace =
    gain: ->
      debugger
  module.UGen = new ChuckType("UGen", module.Object, size: 8, numIns: 1, numOuts: 1, preConstructor: undefined,
  namespace: ugenNamespace,
  (opts) ->
    @ugenNumIns = opts.numIns
    @ugenNumOuts = opts.numOuts
  )
  class OscData
    constructor: ->
      @num = 0.0
      @freq = 220.0
      @sync = 0
      @width = 0.5
      @srate =
        @phase = 0.0
  oscNamespace =
    freq: ->
      debugger
  constructOsc = ->
    @data = new OscData()
    @_setNode(audioContextService.createOscillator())
    @_node.frequency.value = 220
    @_node.start(0)
  module.Osc = new ChuckType("Osc", module.UGen, numIns: 1, numOuts: 1, preConstructor: constructOsc,
  namespace: oscNamespace)
  constructSinOsc = ->
    @_node.type = 0
  module.SinOsc = new ChuckType("SinOsc", module.Osc, preConstructor: constructSinOsc)
  module.UGenStereo = new ChuckType("Ugen_Stereo", module.UGen, numIns: 2, numOuts: 2, preConstructor: undefined)
  constructDac = ->
    @_node = audioContextService.outputNode
  module.Dac = new ChuckType("Dac", module.UGenStereo, preConstructor: constructDac)
  module.Int = new ChuckType("Int", undefined, size: 8, preConstructor: undefined)
  module.Time = new ChuckType("Time", undefined, size: 8, preConstructor: undefined)
  module.Dur = new ChuckType("Dur", undefined, size: 8, preConstructor: undefined)
  module.String = new ChuckType("String", undefined, size: 8, preConstructor: undefined)

  return module
)
