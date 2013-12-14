define("chuck/scanner", ["chuck/nodes"], (nodes) ->
  module = {}

  class Scanner
    constructor: (ast) ->
      @_ast = ast
      @_byteCode = []

    pass1: =>

    pass2: =>
      expr = @_ast
      if expr instanceof nodes.BinaryExpression
        debugger

    pass3: =>

    pass4: =>

  module.scan = (ast) ->
    scanner = new Scanner()
    scanner.pass1()
    scanner.pass2()
    scanner.pass3()
    scanner.pass4()
    return scanner.byteCode

  return module
)
