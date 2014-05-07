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
    random2f: new ChuckStaticMethod("random2f", [new FunctionOverload([
        new FuncArg("min", float), new FuncArg("max", float)], (min, max) ->
      Math.random() * (max-min) + min
    )], "Math", float)
    log: new ChuckStaticMethod("log", [new FunctionOverload([
      new FuncArg("x", float)], (x) -> Math.log(x))], "Math", float)
    sin: new ChuckStaticMethod("sin", [new FunctionOverload([
      new FuncArg("x", float)], (x) -> Math.sin(x))], "Math", float)
  types.Math = new ChuckType("Math", Object, namespace: mathNamespace)

  return module
)
