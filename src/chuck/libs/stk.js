// STK library
define("chuck/libs/stk", ["chuck/types"], function (typesModule) {
  var ChuckType = typesModule.ChuckType,
    ChuckMethod = typesModule.ChuckMethod,
    FuncArg = typesModule.FuncArg,
    FunctionOverload = typesModule.FunctionOverload,
    float = typesModule.types.float,
    int = typesModule.types.int,
    UGen = typesModule.types.UGen,
    module = {},
    types = module.types = {};

  types.JcReverb = new ChuckType("JCRev", UGen, {
    preConstructor: function () {
      this.data = {
        mix: 0
      };
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
      var d = this.data
      return input;
    }
  });

  return module;
})
