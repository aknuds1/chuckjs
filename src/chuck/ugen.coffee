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

    tick: (now, frame) =>
      logging.debug("DAC ticking")
      frame[0] = 0
      frame[1] = 0
      srcFrame = []
      for src in @_srcList
        src.tick(now, srcFrame)
        frame[0] += srcFrame[0] / @_srcList.length
        frame[1] += srcFrame[1] / @_srcList.length

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
