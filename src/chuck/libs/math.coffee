# Math standard library
define("chuck/libs/math", ["chuck/types"], (typesModule) ->
  {ChuckType, ChuckStaticMethod, FuncArg, FunctionOverload} = typesModule
  {Object, float} = typesModule.types

  module = {}
  types = module.types = {}

  mathNamespace =
    pow: new ChuckStaticMethod("pow", [new FunctionOverload([new FuncArg("x", float),
      new FuncArg("y", float)], (x, y) -> Math.pow(x, y))], "Math", float)
  types.Math = new ChuckType("Math", Object, namespace: mathNamespace)

  return module
)
