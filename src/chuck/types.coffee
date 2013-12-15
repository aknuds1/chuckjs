# ChucK type library
define("chuck/types", ->
  module = {}

  class ChuckType
    constructor: (name, parent, opts, constructorCb) ->
      @name = name
      @parent = parent
      @_constructor = constructorCb
      @_opts = opts || {}

      @_constructParent(parent, @_opts)

      if constructorCb
        constructorCb.call(@, @_opts)

    isOfType: (otherType) =>
      if @name == otherType.name
        return true

      parent = @parent
      while parent?
        if parent.isOfType(otherType)
          return true
        parent = parent.parent

      return false

    _constructParent: (parent, opts) =>
      if !parent?
        return

      opts = _(parent._opts).extend(opts)
      @_constructParent(parent.parent, opts)
      if parent._constructor?
        parent._constructor.call(@, opts)

  module.Object = new ChuckType("Object", undefined, {}, (opts) ->
    @hasConstructor = if opts.hasConstructor? then opts.hasConstructor else true
    @size = opts.size
  )
  module.UGen = new ChuckType("UGen", module.Object, size: 8, (opts) ->
    @ugenNumIns = opts.numIns
    @ugenNumOuts = opts.numOuts
  )
  module.Osc = new ChuckType("Osc", module.UGen, numIns: 1, numOuts: 1)
  module.SinOsc = new ChuckType("SinOsc", module.Osc, hasConstructor: false)

  return module
)
