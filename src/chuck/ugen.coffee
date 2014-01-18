define("chuck/ugen", ["chuck/types", "chuck/audioContextService"], (types, audioContextService) ->
  module = {}

  module.UGen = class UGen
    constructor: (type) ->
      @type = type
      @size = @type.size
      @tick = @type.ugenTick
      @pmsg = @type.ugenPmsg
      @numIns = @type.ugenNumIns
      @numOuts = @type.ugenNumOuts
      @_srcList = []
      @_destList = []

    add: (src) =>
      @_srcList.push(src)
      src._addDest(@)
      return

    stop: =>
      for src in @_srcList
        src.stop()
      @_srcList.splice(0, @_srcList.length)

      if @_destList.length == 0
        return

      @_destList.splice(0, @_destList.length)
      return

    setGain: (gain) =>
      return gain

    _addDest: (dest) =>
      @_destList.push(dest)
      return

    _setNode: (node) =>
      return

  module.Dac = class Dac extends UGen
    constructor: ->
      super(types.Dac, false)

  return module
)
