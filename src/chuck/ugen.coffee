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
      logging.debug("UGen channel: Adding source ##{@sources.length}")
      @sources.push(source)
      return

    remove: (source) =>
      idx = _.find(@sources, (src) -> src == source)
      logging.debug("UGen channel: Removing source ##{idx}")
      @sources.splice(idx, 1)
      return

    stop: =>
      @sources.splice(0, @sources.length)

  module.UGen = class UGen
    constructor: (type) ->
      @type = type
      @size = @type.size
      @pmsg = @type.ugenPmsg
      @numIns = @type.ugenNumIns
      @numOuts = @type.ugenNumOuts
      @_channels = (new UGenChannel() for i in [0...@numIns])
      @_tick = if type.ugenTick? then _.bind(type.ugenTick, @) else (input) -> input
      @_now = -1
      @_destList = []
      @_gain = 1

    add: (src) =>
      for channel in @_channels
        channel.add(src)
      src._addDest(@)
      return

    remove: (src) =>
      for channel in @_channels
        channel.remove(src)
      src._removeDest(@)
      return

    stop: =>
      for channel in @_channels
        channel.stop()

      if @_destList.length == 0
        return

      @_destList.splice(0, @_destList.length)
      return

    setGain: (gain) =>
      @_gain = gain
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
      @current = @_tick(sum) * @_gain
      return @current

    _addDest: (dest) =>
      @_destList.push(dest)
      return

    _removeDest: (dest) =>
      idx = _.find(@_destList, (d) -> d == dest)
      logging.debug("UGen: Removing destination #{idx}")
      @_destList.splice(idx, 1)
      return

  module.Dac = class Dac extends UGen
    constructor: ->
      super(types.types.Dac)

    tick: (now, frame) =>
      super(now)
      for i in [0...frame.length]
        frame[i] = @_channels[i].current
      return

  return module
)
