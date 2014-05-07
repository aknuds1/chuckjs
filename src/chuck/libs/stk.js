// STK library
define("chuck/libs/stk", ["chuck/types", "chuck/audioContextService"], function (typesModule, audioContextService) {
  var ChuckType = typesModule.ChuckType,
    ChuckMethod = typesModule.ChuckMethod,
    FuncArg = typesModule.FuncArg,
    FunctionOverload = typesModule.FunctionOverload,
    float = typesModule.types.float,
    int = typesModule.types.int,
    dur = typesModule.types.dur,
    UGen = typesModule.types.UGen,
    Osc = typesModule.types.Osc,
    void_ = typesModule.types.void,
    module = {},
    types = module.types = {};

  function isPrime(number) {
    var i;
    if (number === 2) {
      return true;
    }
    if (number & 1) {
      for (i = 3; i < Math.sqrt(number) + 1; i += 2) {
        if ((number % i) === 0) return false;
      }
      return true
    }

    return false
  }

  function Delay(delay, max) {
    var self = this;
    if (delay == null) {
      delay = 0
    }
    if (max == null) {
      max = 4096
    }

    // Writing before reading allows delays from 0 to length-1.
    // If we want to allow a delay of maxDelay, we need a
    // delay-line of length = maxDelay+1.
    self.length = max + 1;

    self.clear();

    self.inPoint = 0;

    if (delay > self.length - 1) {
      // The value is too big.
      // Force delay to maxLength.
      self.outPoint = self.inPoint + 1;
      delay = self.length - 1;
    }
    else if (delay < 0) {
      self.outPoint = self.inPoint;
      delay = 0;
    }
    else {
      self.outPoint = self.inPoint - delay;  // read chases write
    }
    self.delay = delay;

    while (self.outPoint < 0) {
      self.outPoint += self.length;  // modulo maximum length
    }
  }

  Delay.prototype.clear = function () {
    var self = this, i
    self.inputs = [];
    for (i = 0; i < self.length; ++i) {
      self.inputs.push(0);
    }
    self.output = 0;
  };
  Delay.prototype.tick = function (sample) {
    var self = this;
    self.inputs[self.inPoint++] = sample;
    // Check for end condition
    if (self.inPoint >= self.length) {
      self.inPoint = 0;
    }

    // Read out next value
    self.output = self.inputs[self.outPoint++];
    if (self.outPoint >= self.length) {
      self.outPoint = 0;
    }

    return self.output;
  };
  Delay.prototype.setDelay = function (delay) {
    var self = this
    if (delay > (self.length-1)) { // The value is too big.
      // Force delay to maxLength.
      self.outPoint = self.inPoint + 1
      self.delay = self.length - 1
    }
    else if (delay < 0) {
      self.outPoint = self.inPoint
      self.delay = 0
    }
    else {
      self.outPoint = self.inPoint - Math.floor(delay)  // read chases write
      self.delay = delay
    }

    while (self.outPoint < 0) {
      self.outPoint += self.length  // modulo maximum length
    }
  }
  types.Delay = Delay

  types.JcReverb = new ChuckType("JCRev", UGen, {
    preConstructor: function () {
      // Delay lengths for 44100 Hz sample rate.
      var lengths = [1777, 1847, 1993, 2137, 389, 127, 43, 211, 179];
      var i,
        delay,
        sampleRate = audioContextService.getSampleRate(),
        scaler = sampleRate / 44100,
        d,
        t60 = 4;

      d = this.data = {
        mix: 0.3,
        allpassDelays: [],
        combDelays: [],
        combCoefficient: [],
        allpassCoefficient: 0.7,
        lastOutput: []
      };

      if (scaler !== 1.0) {
        for (i = 0; i < 9; ++i) {
          delay = Math.floor(scaler * lengths[i]);
          if ((delay & 1) === 0) {
            delay++;
          }
          while (!isPrime(delay)) {
            delay += 2;
          }
          lengths[i] = delay;
        }
      }

      for (i = 0; i < 3; i++) {
        d.allpassDelays.push(new Delay(lengths[i + 4], lengths[i + 4]));
      }

      for (i = 0; i < 4; i++) {
        d.combDelays.push(new Delay(lengths[i], lengths[i]));
        d.combCoefficient.push(Math.pow(10.0, (-3 * lengths[i] / (t60 * sampleRate))));
      }

      d.outLeftDelay = new Delay(lengths[7], lengths[7]);
      d.outRightDelay = new Delay(lengths[8], lengths[8]);

      [d.allpassDelays, d.combDelays, [d.outRightDelay, d.outLeftDelay]].forEach(function (e) {
        e.forEach(function (delay) {
          delay.clear();
        });
      });
      d.lastOutput[0] = d.lastOutput[1] = 0;
    },
    namespace: {
      mix: new ChuckMethod("mix", [new FunctionOverload([
          new FuncArg("value", float)],
        function (value) {
          this.data.mix = value;
          return this.data.mix;
        })], "JCRev", float)
    },
    ugenTick: function (input) {
      var self = this,
        d = self.data,
        temp, temp0, temp1, temp2, temp3, temp4, temp5, temp6,
        filtout;

      temp = d.allpassDelays[0].output
      temp0 = d.allpassCoefficient * temp
      temp0 += input
      d.allpassDelays[0].tick(temp0)
      temp0 = -(d.allpassCoefficient * temp0) + temp;

      temp = d.allpassDelays[1].output;
      temp1 = d.allpassCoefficient * temp;
      temp1 += temp0
      d.allpassDelays[1].tick(temp1);
      temp1 = -(d.allpassCoefficient * temp1) + temp;

      temp = d.allpassDelays[2].output;
      temp2 = d.allpassCoefficient * temp;
      temp2 += temp1;
      d.allpassDelays[2].tick(temp2);
      temp2 = -(d.allpassCoefficient * temp2) + temp;

      temp3 = temp2 + (d.combCoefficient[0] * d.combDelays[0].output);
      temp4 = temp2 + (d.combCoefficient[1] * d.combDelays[1].output);
      temp5 = temp2 + (d.combCoefficient[2] * d.combDelays[2].output);
      temp6 = temp2 + (d.combCoefficient[3] * d.combDelays[3].output);

      d.combDelays[0].tick(temp3);
      d.combDelays[1].tick(temp4);
      d.combDelays[2].tick(temp5);
      d.combDelays[3].tick(temp6);

      filtout = temp3 + temp4 + temp5 + temp6;

      d.lastOutput[0] = d.mix * (d.outLeftDelay.tick(filtout));
      d.lastOutput[1] = d.mix * (d.outRightDelay.tick(filtout));
      temp = (1.0 - d.mix) * input;
      d.lastOutput[0] += temp;
      d.lastOutput[1] += temp;

      return (d.lastOutput[0] + d.lastOutput[1]) * 0.5;
    }
  });

  function blitSetFrequency(self, frequency) {
    var sampleRate = audioContextService.getSampleRate(),
      d = self.data

    d.p = sampleRate / frequency
    d.rate = Math.PI / d.p
    d.phase = 0
    blitUpdateHarmonics(self)
  }

  function blitUpdateHarmonics(self) {
    var d = self.data,
      maxHarmonics

    if (d.nHarmonics <= 0) {
      maxHarmonics = Math.floor(0.5 * d.p)
      d.m = 2 * maxHarmonics + 1
    }
    else
      d.m = 2 * d.nHarmonics + 1
  }

  types.Blit = new ChuckType("Blit", Osc, {
    preConstructor: function () {
      var self = this,
        d = self.data
      d.nHarmonics = 0
      self.setFrequency = function (frequency) {
        blitSetFrequency(self, frequency)
        return frequency
      }
      blitSetFrequency(self, 220)
    },
    namespace: {
      harmonics: new ChuckMethod("harmonics", [new FunctionOverload([
          new FuncArg("nHarmonics", int)],
        function (nHarmonics) {
          this.data.nHarmonics = nHarmonics
          return this.data.nHarmonics
        })], "Blit", int)
    },
    ugenTick: function () {
      var d = this.data,
        out,
        denominator
      // The code below implements the SincM algorithm of Stilson and
      // Smith with an additional scale factor of P / M applied to
      // normalize the output.

      // A fully optimized version of this code would replace the two sin
      // calls with a pair of fast sin oscillators, for which stable fast
      // two-multiply algorithms are well known. In the spirit of STK,
      // which favors clarity over performance, the optimization has not
      // been made here.

      // Avoid a divide by zero at the sinc peak, which has a limiting
      // value of 1.0.
      denominator = Math.sin(d.phase)
      if (denominator <= Number.EPSILON) {
        out = 1.0
      }
      else {
        out = Math.sin(d.m * d.phase)
        out /= d.m * denominator
      }

      d.phase += d.rate
      if (d.phase >= Math.PI) {
        d.phase -= Math.PI
      }

      return out
    }
  })

  function setEnvelopeTime(time) {
    if (time < 0) {
      time = -time
    }

    var d = this.data
    if (time === 0) {
      d.rate = Number.MAX_VALUE
    }
    else {
      d.rate = (d.target - d.value) / (time * audioContextService.getSampleRate())
    }

    if (d.rate < 0) {
      d.rate = -d.rate
    }
    d.time = time

    return time
  }

  function envelopeKeyOn(enable) {
    if (!enable) {
      envelopeKeyOff.call(this, 1)
      return 0
    }

    var d = this.data;
    d.target = d.mTarget
    if (d.value !== d.target) {
      d.state = 1
    }

    setEnvelopeTime.call(this, d.time)

    return 1
  }

  function envelopeKeyOff(enable) {
    if (!enable) {
      envelopeKeyOn.call(this, 1)
      return 0
    }

    var d = this.data;
    d.target = 0
    if (d.value !== d.target) {
      d.state = 1
    }
    setEnvelopeTime.call(this, d.time)
    return 1
  }

  types.Envelope = new ChuckType("Envelope", UGen, {
    preConstructor: function () {
      var self = this;
      self.data = {
        target: 0,
        value: 0,
        rate: 0.001,
        mTarget: 1,
        state: 0
      }

      self.data.time = self.data.mTarget / (self.data.rate * audioContextService.getSampleRate())
    },
    namespace: {
      keyOn: new ChuckMethod("keyOn", [new FunctionOverload([new FuncArg("enable", int)], envelopeKeyOn)], "Envelope", int),
      keyOff: new ChuckMethod("keyOff", [new FunctionOverload([new FuncArg("enable", int)], envelopeKeyOff)], "Envelope", int),
      time: new ChuckMethod("time", [new FunctionOverload([new FuncArg("time", float)], setEnvelopeTime)], "Envelope", dur)
    },
    ugenTick: function (input) {
      var d = this.data

      if (d.state) {
        if (d.target > d.value) {
          d.value += d.rate;
          if (d.value >= d.target) {
            d.value = d.target;
            d.state = 0;
          }
        }
        else {
          d.value -= d.rate;
          if (d.value <= d.target) {
            d.value = d.target;
            d.state = 0;
          }
        }
      }

      return input * d.value
    }
  });

  types.Adsr = new ChuckType("ADSR", types.Envelope, {
    preConstructor: function () {
      var d = this.data;
      d.attackRate = 0.001;
      d.decayRate = 0.001;
      d.sustainLevel = 0.5;
      d.releaseRate = 0.01;
      d.state = "attack";
      d.rate = 1;
      d.value = 0;
    },
    namespace: {
      set: new ChuckMethod("set", [new FunctionOverload([
          new FuncArg("attack", dur), new FuncArg("decay", dur),
          new FuncArg("sustain", float), new FuncArg("release", dur)],
        function (attack, decay, sustainLevel, release) {
          function computeRate(target, time) {
            return target / time
          }

          var d = this.data
          d.attackRate = computeRate(1, attack)
          d.decayRate = computeRate(1 - sustainLevel, decay)
          d.releaseRate = computeRate(sustainLevel, release)
          d.sustainLevel = sustainLevel
//         logging.debug("Having set ADSR parameters, at attack state: #{d.attackRate}, #{d.decayRate}, #{d.sustainLevel}, #{d.releaseRate}")
        })], "ADSR", void_),
      keyOn: new ChuckMethod("keyOn", [new FunctionOverload([], function () {
        var d = this.data;
//        logging.debug("keyOn state")
        d.target = 1
        d.rate = d.attackRate
        d.state = "attack"
      })], "ADSR", void_),
      keyOff: new ChuckMethod("keyOff", [new FunctionOverload([], function () {
        var d = this.data;
//        logging.debug("keyOff state")
        d.rate = d.releaseRate;
        d.target = 0;
        d.state = "release";
      })], "ADSR", void_)
    },
    ugenTick: function (input) {
      var d = this.data;
      switch (d.state) {
        case "attack":
          d.value += d.rate;
          //        logging.debug("Attack state: value set to #{d.value}")
          if (d.value >= d.target) {
            d.value = d.target
            d.rate = d.decayRate
            d.target = d.sustainLevel
            d.state = "decay"
//            logging.debug("Transitioned to decay state, value: #{d.value}")
          }
          break;
        case "decay":
          d.value -= d.decayRate;

          //        logging.debug("Decay state: value set to #{d.value}")
          if (d.value <= d.sustainLevel) {
            d.value = d.sustainLevel
            d.rate = 0;
            d.state = "sustain";
            //           logging.debug("Transitioned to sustain state, value: #{d.value}")
          }
          break;
        case "release":
          d.value -= d.rate;
          //        logging.debug("Release state: value set to #{d.value}")
          if (d.value <= 0) {
            d.value = 0;
            d.state = "done";
            //          logging.debug("Transitioned to done state, value: #{d.value}")
          }
          break;
      }

//    logging.debug("State At end")
      return input * d.value;
    }
  });

  types.Delay = new ChuckType("Delay", UGen, {
    preConstructor: function () {
      var d = this.data = {}
      d.delay = new Delay()
    },
    namespace: {
      delay: new ChuckMethod("delay", [new FunctionOverload([
          new FuncArg("value", dur)],
        function (value) {
          this.data.delay.setDelay(value)
          return value
        })], "Delay", dur)
    },
    ugenTick: function (input) {
      return this.data.delay.tick(input)
    }
  })

  return module;
});
