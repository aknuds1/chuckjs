define("chuck/nodes", [], ->
  module = {}

  module.Program = class
    constructor: (arrowExpression) ->
      @arrowExpression = arrowExpression

  module.BinaryExpression = class
    constructor: (exp1, operator, exp2) ->
      @exp1 = exp1
      @operator = operator
      @exp2 = exp2

  module.ExpressionStatement = class
    constructor: (expression) ->
      @expression = expression
      console.log("Expression statement", @expression)

  module.StatementList = class
    constructor: (statements) ->
      @statements = statements

  module.DeclarationExpression = class
    constructor: (typeDecl, varDecl) ->
      @typeDecl = typeDecl
      @varDecl = varDecl
      variables = _(@varDecl.declarations).map((decl) ->
        return decl.name
      )
      variables = _.str.join(", ", variables)

  module.VariableDeclarationList = class
    constructor: (declarations) ->
      @declarations = declarations
      console.log("Variable declaration list:", declarations)

  module.IdList = class
    constructor: (id) ->
      @id = id

  module.TypeDeclaration = class
    constructor: (idList) ->
      @idList = idList
      console.log('Type declaration', idList)

  module.VariableDeclaration = class
    constructor: (name) ->
      @name = name

  module.SectionStatement = class
    constructor: (section) ->
      @section = section

  module.IdExpression = class
    constructor: (exp) ->
      @exp = exp
      console.log("Expression from ID", @exp)

  return module
)
