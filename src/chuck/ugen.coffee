define("chuck/ugen", ["chuck/types", "chuck/audioContextService"], (types, audioContextService) ->
  module = {}

  module.UGen = class UGen
    constructor: (type, useGainNode=true) ->
      @type = type
      @_node = undefined
      if useGainNode
        @_gainNode = audioContextService.createGainNode()
        @_gainNode.gain.value = 1
      @size = @type.size
      @tick = @type.ugenTick
      @pmsg = @type.ugenPmsg
      @numIns = @type.ugenNumIns
      @numOuts = @type.ugenNumOuts
      @_srcList = []
      @_destList = []

    add: (src) =>
      src._gainNode.connect(@_node)

      @_srcList.push(src)
      src._addDest(@)
      return

    stop: =>
      for src in @_srcList
        src.stop()
      @_srcList.splice(0, @_srcList.length)
      if @_node.stop?
        @_node.stop(0)

      if @_destList.length == 0
        return

      for i in [0..@_destList.length-1]
        @_gainNode.disconnect(i)
      @_destList.splice(0, @_destList.length)
      # Disconnect from gain node
      @_node.disconnect(0)
      return

    setGain: (gain) =>
      @_gainNode.gain.value = gain
      return gain

    _addDest: (dest) =>
      @_destList.push(dest)
      return

    _setNode: (node) =>
      @_node = node
      @_node.connect(@_gainNode)
      return

  module.Dac = class Dac extends UGen
    constructor: ->
      super(types.Dac, false)
      @_node = audioContextService.outputNode

  return module
)
