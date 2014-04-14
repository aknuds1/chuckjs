# Standard library
define("chuck/libs/std", ["chuck/types"], (typesModule) ->
  {ChuckType, ChuckStaticMethod, FuncArg, FunctionOverload} = typesModule
  {Object, float, int} = typesModule.types

  module = {}
  types = module.types = {}

  stdNamespace =
    mtof: new ChuckStaticMethod("mtof", [new FunctionOverload([new FuncArg("value", float)],
      (value) ->
        Math.pow(2, (value-69)/12) * 440
      )], "Std", float)
  types.Std = new ChuckType("Std", Object, namespace: stdNamespace)

  return module
)
