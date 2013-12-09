{Lexer} = require('./language/lexer')
{Parser} = require("./src/parser")
helpers = require('./language/helpers')
_ = require('underscore')
_.str = require('underscore.string')
_.mixin(_.str.exports())

yy = {}

yy.addLocationDataFn = (first, last) ->
  return (obj) ->
    return obj

yy.IdList = class IdList
  constructor: (id) ->
    console.log('ID List', id)
    @id = id

yy.TypeDecl = class TypeDecl
  constructor: (idList) ->
    @idList = idList
    console.log('Type declaration', idList)

yy.VarDecl = class VarDecl
  constructor: (name) ->
    @name = name
    console.log("Variable declaration: #{name}")

yy.VarDeclList = class VarDeclList
  constructor: (declarations) ->
    @declarations = declarations
    console.log("Variable declaration list:", declarations)

yy.DeclExp = class DeclExpression
  constructor: (typeDecl, varDecl) ->
    @typeDecl = typeDecl
    @varDecl = varDecl
    variables = _(@varDecl.declarations).map((decl) ->
      return decl.name
    )
    variables = _.str.join(", ", variables)
    console.log("Declaration expression, type #{typeDecl.idList.id}, variables: #{variables}")

yy.Program = class Program
  constructor: (arrowExpression) ->
    @arrowExpression = arrowExpression
    console.log("Program:", arrowExpression)

yy.ExpressionStatement = class ExpressionStatement
  constructor: (expression) ->
    @expression = expression
    console.log("Expression statement", @expression)

yy.StatementList = class StatementList
  constructor: (statements) ->
    @statements = statements
    console.log("Statement list", @statements)

yy.SectionStatement = class SectionStatement
  constructor: (section) ->
    @section = section
    console.log("Section:", @section)

yy.ExpFromId = class ExpFromId
  constructor: (exp) ->
    @exp = exp
    console.log("Expression from ID", @exp)

yy.ExpFromBinary = class ExpFromBinary
  constructor: (exp1, operator, exp2) ->
    @exp1 = exp1
    @operator = operator
    @exp2 = exp2
    console.log("Expression from binary", @exp1, @operator, @exp2)

lexer = new Lexer()

parser = new Parser()
parser.yy = yy
parser.lexer =
  lex: ->
    token = @tokens[@pos++]
    if token
      [tag, @yytext, @yylloc] = token
      @yylineno = @yylloc.first_line
    else
      tag = ''

    tag
  setInput: (tokens) ->
    @tokens = tokens
    @pos = 0
  upcomingInput: ->
    ""

sourcecode = "SinOsc sin2 => dac;"
tokens = lexer.tokenize(sourcecode)
console.log("Tokens:", tokens)
parsed = parser.parse(tokens)
#console.log(parsed)
