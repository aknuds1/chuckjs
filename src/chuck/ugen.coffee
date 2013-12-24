define("chuck/ugen", ["chuck/types"], (types) ->
  module = {}

  module.UGen = class UGen
    constructor: (type) ->
      @type = type
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
      else
        for i in [0..@_multiChanSize]
          @_multiChan.push(new UGen(types.UGen))

    add: (src) =>
      outs = src.numOuts
      ins = @numIns

      if outs >= 1 && ins == 1
        @_srcList.push(src)
        src._addDest(@)
      else if outs == 1 && ins >= 2
        for i in [0..@numIns]
          @_multiChan[i].add(src)

      return undefined

    _addDest: (dest) =>
      @_destList.push(dest)

  return module
)
