define("chuck/ugen", ["chuck/types", "chuck/audioContextService"], (types, audioContextService) ->
  module = {}

  module.UGen = class UGen
    constructor: (type) ->
      @type = type
      @_node = undefined
      @size = @type.size
      @tick = @type.ugenTick
      @pmsg = @type.ugenPmsg
      @numIns = @type.ugenNumIns
      @numOuts = @type.ugenNumOuts
      @_multiChanSize = Math.max(@numIns, @numOuts)
      @_multiChan = []
      @_srcList = []
      @_destList = []
      if @_multiChanSize == 1
        # Mono
        @_multiChanSize = 0
        @_multiChan[0] = @
      else if @_multiChanSize > 1
        for i in [0..@_multiChanSize-1]
          @_multiChan.push(new UGen(types.UGen))

    add: (src) =>
      src._node.connect(@_node)

      @_srcList.push(src)
      src._addDest(@)

      return undefined

    stop: =>
      for src in @_srcList
        src.stop()
      @_srcList.splice(0, @_srcList.length)
      if @_node.stop?
        @_node.stop(0)

      if @_destList.length == 0
        return

      for i in [0..@_destList.length-1]
        @_node.disconnect(i)
      @_destList.splice(0, @_destList.length)

    _addDest: (dest) =>
      @_destList.push(dest)

  module.Dac = class Dac extends UGen
    constructor: ->
      super(types.Dac)
      @_node = audioContextService.outputNode

  return module
)
