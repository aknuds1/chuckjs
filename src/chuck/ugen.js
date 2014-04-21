define("chuck/ugen", ["chuck/types", "chuck/logging"], function(types, logging) {
  var module = {}

  function UGenChannel() {
    var self = this
    self.current = 0
    self.sources = []
  }

  function uGenChannelTick(self, now) {
    var i,
      ugen,
      source

    self.current = 0
    if (self.sources.length === 0) {
      return self.current
    }

    // Tick sources
    ugen = self.sources[0]
    ugen.tick(now)
    self.current = ugen.current
    for (i = 1; i < self.sources.length; ++i) {
      source = self.sources[i]
      source.tick(now)
      self.current += source.current
    }

    return self.current
  }

  function uGenChannelAdd(self, source) {
    logging.debug("UGen channel: Adding source #" + self.sources.length)
    self.sources.push(source)
  }

  function uGenChannelRemove(self, source) {
    var idx = _.find(self.sources, function (src) { return src === source })
    logging.debug("UGen channel: Removing source #" + idx)
    self.sources.splice(idx, 1)
  }

  function uGenChannelStop(self) {
    self.sources.splice(0, self.sources.length)
  }

  module.UGen = function UGen(type) {
    var self = this,
      i
    self.type = type
    self.size = self.type.size
    self.pmsg = self.type.ugenPmsg
    self.numIns = self.type.ugenNumIns
    self.numOuts = self.type.ugenNumOuts
    self._channels = []
    for (i = 0; i < self.numIns; ++i) {
      self._channels.push(new UGenChannel())
    }
    self._tick = type.ugenTick ? type.ugenTick : function (input) { return input }
    self._now = -1
    self._destList = []
    self._gain = 1
  }
  module.UGen.prototype.stop = function() {
    var self = this, i
    for (i = 0; i < self._channels.length; ++i) {
      uGenChannelStop(self._channels[i])
    }

    if (self._destList.length === 0) {
      return
    }

    self._destList.splice(0, self._destList.length)
  }
  module.UGen.prototype.tick = function(now) {
    var self = this,
      sum = 0,
      i
    if (self._now >= now) {
      return self.current
    }

    self._now = now

    // Tick inputs
    for (i = 0; i < self._channels.length; ++i){
      sum += uGenChannelTick(self._channels[i], now)
    }
    sum /= self._channels.length

    // Synthesize
    self.current = self._tick.call(self, sum) * self._gain
    return self.current
  }
  module.UGen.prototype.setGain = function(gain) {
    var self = this
    self._gain = gain
    return gain
  }

  module.uGenAdd = function uGenAdd(self, src) {
    var i
    for (i = 0; i < self._channels.length; ++i) {
      uGenChannelAdd(self._channels[i], src)
    }

    _uGenAddDest(src, self)
  }

  module.uGenRemove = function uGenRemove(self, src) {
    var i
    for (i = 0; i < self._channels.length; ++i) {
      uGenChannelRemove(self._channels[i], src)
    }

    _ugenRemoveDest(src, self)
  }

  function _uGenAddDest(self, dest) {
    self._destList.push(dest)
  }

  function _ugenRemoveDest(self, dest) {
    var idx = _.find(self._destList, function (d) { return d == dest })
    logging.debug("UGen: Removing destination " + idx)
    self._destList.splice(idx, 1)
  }

  module.Dac = function Dac() {
    var self = this
    module.UGen.call(self, types.types.Dac)
  }
  module.Dac.prototype = Object.create(module.UGen.prototype)
  module.Dac.prototype.tick = function (now, frame) {
    var self = this,
      i
    module.UGen.prototype.tick.call(self, now)
    for (i = 0; i < frame.length; ++i) {
      frame[i] = self._channels[i].current
    }
  }

  return module
})
