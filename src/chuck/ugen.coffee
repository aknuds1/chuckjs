define("chuck/ugen", [], ->
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
      if @_multiChanSize == 1
        # Mono
        @_multiChanSize = 0
        @_multiChan[0] = @

  return module
)
