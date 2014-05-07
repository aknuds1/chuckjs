define("chuck/libs/ugens", ["chuck/types", "chuck/audioContextService"], function (typesModule, audioContextService) {
  var ChuckType = typesModule.ChuckType,
    ChuckMethod = typesModule.ChuckMethod,
    FuncArg = typesModule.FuncArg,
    FunctionOverload = typesModule.FunctionOverload,
    float = typesModule.types.float,
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

  return module
})
