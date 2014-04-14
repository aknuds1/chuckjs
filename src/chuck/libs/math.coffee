# Math standard library
define("chuck/libs/math", ["chuck/types"], (typesModule) ->
  {ChuckType, ChuckStaticMethod, FuncArg, FunctionOverload} = typesModule
  {Object, float, int} = typesModule.types

  module = {}
  types = module.types = {}

  mathNamespace =
    pow: new ChuckStaticMethod("pow", [new FunctionOverload([new FuncArg("x", float),
      new FuncArg("y", float)], (x, y) -> Math.pow(x, y))], "Math", float)
    random2: new ChuckStaticMethod("random2", [new FunctionOverload([new FuncArg("min", int),
      new FuncArg("max", int)], (min, max) ->
        Math.floor(Math.random() * (max-min+1)) + min
      )], "Math", int)
  types.Math = new ChuckType("Math", Object, namespace: mathNamespace)

  return module
)
