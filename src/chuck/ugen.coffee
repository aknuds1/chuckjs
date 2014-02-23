define("chuck/ugen", ["chuck/types", "chuck/logging"], (types, logging) ->
  module = {}

  class UGenChannel
    constructor: ->
      @current = 0
      @sources = []

    tick: (now) =>
      @current = 0
      if @sources.length == 0
        return @current

      # Tick sources
      ugen = @sources[0]
      ugen.tick(now)
      @current = ugen.current
      for source in (@sources[i] for i in [1...@sources.length])
        source.tick(now)
        @current += source.current

      @current

    add: (source) =>
      @sources.push(source)

  module.UGen = class UGen
    constructor: (type) ->
      @type = type
      @size = @type.size
      @pmsg = @type.ugenPmsg
      @numIns = @type.ugenNumIns
      @numOuts = @type.ugenNumOuts
      @_channels = (new UGenChannel() for i in [0..@numIns-1])
      @_tick = if type.ugenTick? then _(type.ugenTick).bind(@) else (input) -> input
      @_now = -1
      @_destList = []

    add: (src) =>
      for channel in @_channels
        channel.add(src)
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

    tick: (now) =>
      if @_now >= now
        return @current

      @_now = now

      # Tick inputs
      sum = 0
      for channel in @_channels
        sum += channel.tick(now)
      sum /= @_channels.length

      # Synthesize
      @current = @_tick(sum)
      return @current

    _addDest: (dest) =>
      @_destList.push(dest)
      return

  module.Dac = class Dac extends UGen
    tick: (now, frame) =>
      super(now)
      for i in [0...frame.length]
        frame[i] = @_channels[i].current
      return

  return module
)
