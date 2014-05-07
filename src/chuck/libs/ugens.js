define("chuck/libs/ugens", ["chuck/types", "chuck/audioContextService"], function (typesModule, audioContextService) {
  var ChuckType = typesModule.ChuckType,
    ChuckMethod = typesModule.ChuckMethod,
    FuncArg = typesModule.FuncArg,
    FunctionOverload = typesModule.FunctionOverload,
    float = typesModule.types.float,
    int = typesModule.types.int,
    UGen = typesModule.types.UGen,
    module = {},
    types = module.types = {}

  types.Impulse = new ChuckType("Impulse", UGen, {
    preConstructor: function () {
      var d = this.data = {}
      d.next = null
    },
    namespace: {
      next: new ChuckMethod("next", [new FunctionOverload([
          new FuncArg("value", float)],
        function (value) {
          return this.data.next = value
        })], "Impulse", float)
    },
    ugenTick: function () {
      var d = this.data
      if (d.next != null) {
        out = d.next
        d.next = null
        return out
      }
      return 0
    }
  })

  function biQuadSetReson(d) {
    d.a2 = d.prad * d.prad
    d.a1 = -2.0 * d.prad * Math.cos(2.0 * Math.PI * d.pfreq / d.srate)

    if (d.norm) {
      // Use zeros at +- 1 and normalize the filter peak gain.
      d.b0 = 0.5 - 0.5 * d.a2
      d.b1 = -1.0
      d.b2 = -d.b0
    }
  }
  types.BiQuad = new ChuckType("BiQuad", UGen, {
    preConstructor: function () {
      var d = this.data = {}
      d.a0 = d.b0 = 1
      d.a1 = d.a2 = 0
      d.b1 = d.b2 = 0
      d.pfreq = d.zfreq = 0
      d.prad = d.zrad = 0
      d.srate = audioContextService.getSampleRate()
      d.norm = false
      d.input0 = d.input1 = d.input2 = d.output0 = d.output1 = d.output2 = 0
    },
    namespace: {
      prad: new ChuckMethod("prad", [new FunctionOverload([
          new FuncArg("value", float)],
        function (value) {
          var d = this.data
          d.prad = value
          biQuadSetReson(d)
          return d.prad
        })], "Impulse", float),
      eqzs: new ChuckMethod("eqzs", [new FunctionOverload([
          new FuncArg("value", float)],
        function (value) {
          var d = this.data
          if (!value) {
            return value
          }

          d.b0 = 1.0
          d.b1 = 0.0
          d.b2 = -1.0
          return value
        })], "Impulse", int),
      pfreq: new ChuckMethod("pfreq", [new FunctionOverload([
          new FuncArg("value", float)],
        function (value) {
          var d = this.data
          d.pfreq = value
          biQuadSetReson(d)
          return value
        })], "Impulse", int)
    },
    ugenTick: function (input) {
      var d = this.data
      d.input0 = d.a0 * input
      d.output0 = d.b0 * d.input0 + d.b1 * d.input1 + d.b2 * d.input2
      d.output0 -= d.a2 * d.output2 + d.a1 * d.output1
      d.input2 = d.input1
      d.input1 = d.input0
      d.output2 = d.output1
      d.output1 = d.output0

      return d.output0
    }
  })

  types.Noise = new ChuckType("Noise", UGen, {
    ugenTick: function () {
      return -1 + 2*Math.random()
    }
  })

  return module
})
