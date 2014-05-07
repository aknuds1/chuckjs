define("chuck/ugen", ["chuck/types", "chuck/logging", "chuck/audioContextService"], function (types, logging,
  audioContextService) {
  var module = {}

  function initializeUGen(self, type) {
    self.type = type
    self.size = self.type.size
    self.pmsg = self.type.ugenPmsg
    self.numIns = self.type.ugenNumIns
    self.numOuts = self.type.ugenNumOuts
    self._now = -1
    self._destList = []
    self._gain = 1
  }

  module.MultiChannelUGen = function MultiChannelUGen(type) {
    var i, self = this

    initializeUGen(this, type);

    self._channels = []
    for (i = 0; i < self.numIns; ++i) {
      self._channels.push(new module.MonoUGen(type, self))
    }
  }
  module.MultiChannelUGen.prototype.stop = function () {
    var self = this, i
    for (i = 0; i < self._channels.length; ++i) {
      self._channels[i]._stop()
    }
  }
  module.MultiChannelUGen.prototype.tick = function (now) {
    var self = this,
      i
    if (self._now >= now) {
      return
    }

    self._now = now

    // Tick channels
    for (i = 0; i < self._channels.length; ++i) {
      self._channels[i].tick(now)
    }
  }
  module.MultiChannelUGen.prototype.add = function add(src) {
    var self = this, i, srcUGens
    srcUGens = src instanceof module.MonoUGen ? [src, src] : src._channels
    for (i = 0; i < self._channels.length; ++i) {
      self._channels[i].add(srcUGens[i])
    }
  }
  module.MultiChannelUGen.prototype.remove = function (src) {
    var self = this, i
    for (i = 0; i < self._channels.length; ++i) {
      self._channels[i].remove(src)
    }
  }
  module.MultiChannelUGen.prototype.setGain = function (gain) {
    var self = this, i
    for (i = 0; i < self._channels.length; ++i) {
      self._channels[i].setGain(gain)
    }
    return gain
  }

  module.MonoUGen = function MonoUGen(type, parent) {
    var self = this
    initializeUGen(self, type)
    self.parent = parent
    self.current = 0
    self.pan = 1
    self._tick = type.ugenTick ? type.ugenTick : function (input) {
      return input
    }
    self.sources = []
  }
  module.MonoUGen.prototype.tick = function tick(now) {
    var self = this, i, source, sum

    if (self._now >= now) {
      return self.current
    }

    // Don't change self.current until after finishing computations, since other nodes that use our output in the
    // meantime should use the previously output sample
    sum = 0
    self._now = now

    // Tick sources
    if (self.sources.length > 0) {
      for (i = 0; i < self.sources.length; ++i) {
        source = self.sources[i]
        source.tick(now)
        sum += source.current
      }
    }

    // Synthesize
    self.current = self._tick.call(self, sum) * self._gain * self.pan
    return self.current
  }
  module.MonoUGen.prototype.setGain = function (gain) {
    var self = this
    self._gain = gain
    return gain
  }
  module.MonoUGen.prototype.add = function (src) {
    var self = this, i, srcUGens
    srcUGens = src instanceof module.MonoUGen ? [src] : src._channels
    for (i = 0; i < srcUGens.length; ++i) {
      logging.debug("UGen: Adding source #" + self.sources.length)
      self.sources.push(srcUGens[i])
      srcUGens[i]._destList.push(self)
    }
  }
  module.MonoUGen.prototype.remove = function (src) {
    var self = this, i, srcUGens
    srcUGens = src instanceof module.MonoUGen ? [src] : src._channels
    for (i = 0; i < srcUGens.length; ++i) {
      var idx = _.find(self.sources, function (s) { return s === srcUGens[i] })
      logging.debug("UGen: Removing source #" + idx)
      self.sources.splice(idx, 1)

      srcUGens[i]._removeDest(self)
    }
  }
  module.MonoUGen.prototype._removeDest = function (dest) {
    var self = this, idx
    idx = _.find(self._destList, function (d) {
      return d === dest
    })
    logging.debug("UGen: Removing destination " + idx)
    self._destList.splice(idx, 1)
  }
  module.MonoUGen.prototype._stop = function () {
    var self = this
    self.sources.splice(0, self.sources.length)
  }

  module.Dac = function Dac() {
    var self = this
    self._node = audioContextService.outputNode
    module.MultiChannelUGen.call(self, types.types.Dac)
  }
  module.Dac.prototype = Object.create(module.MultiChannelUGen.prototype)
  module.Dac.prototype.tick = function (now, frame) {
    var self = this,
      i
    module.MultiChannelUGen.prototype.tick.call(self, now)
    for (i = 0; i < frame.length; ++i) {
      frame[i] = self._channels[i].current
    }
  }

  function Bunghole() {
    var self = this
    module.MonoUGen.call(self, types.types.Bunghole)
  }
  Bunghole.prototype = Object.create(module.MonoUGen.prototype)
  module.Bunghole = Bunghole

  return module
})
