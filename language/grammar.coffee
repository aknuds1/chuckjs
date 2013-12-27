{Parser} = require('jison')
_ = require('underscore')

# Since we're going to be wrapped in a function by Jison in any case, if our
# action immediately returns a value, we can optimize by removing the function
# wrapper and just returning the value directly.
unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

# Our DSL for Jison grammar generation
o = (patternString, action, options) ->
  patternString = patternString.replace(/\s{2,}/g, ' ')
  patternCount = patternString.split(' ').length
  if !action?
    rule = [patternString, '$$ = $1;']
    if options?
      rule.push(options)
    return rule

  action = if match = unwrap.exec(action) then match[1] else "(#{action}())"

  # All runtime functions we need are defined on "yy"
  action = action.replace(/\bnew /g, '$&yy.')
  action = action.replace(/\b(?:Block\.wrap|extend)\b/g, 'yy.$&')

  # Returns a function which adds location data to the first parameter passed
  # in, and returns the parameter.  If the parameter is not a node, it will
  # just be passed through unaffected.
  addLocationDataFn = (first, last) ->
    if not last
      return "yy.addLocationDataFn(@#{first})"
    else
      return "yy.addLocationDataFn(@#{first}, @#{last})"

  action = action.replace(/LOC\(([0-9]*)\)/g, addLocationDataFn('$1'))
  action = action.replace(/LOC\(([0-9]*),\s*([0-9]*)\)/g, addLocationDataFn('$1', '$2'))

  rule = [patternString, "$$ = #{addLocationDataFn(1, patternCount)}(#{action});"]
  if options?
    rule.push(options)
#  console.log("Rule: #{rule}")
  return rule

grammar = {
  Program: [
    o('ProgramSection', -> new Program([$1]))
  ],
  ProgramSection: [
    o('StatementList')
  ],
  StatementList: [
    o('Statement', -> [$1]),
    o('Statement StatementList', -> [$1].concat($2))
  ],
  Statement: [
    o('ExpressionStatement')
  ],
  ExpressionStatement: [
    o('SEMICOLON', -> return undefined),
    o('Expression SEMICOLON')
  ],
  Expression: [
    o('ChuckExpression'),
    o('ChuckExpression COMMA expression', -> prependExpression($1, $3))
  ],
  ChuckExpression: [
    o('ArrowExpression'),
    o('ChuckExpression CHUCK ArrowExpression', -> new BinaryExpression($1, new ChuckOperator(), $3))
  ],
  ArrowExpression: [
    o('DeclExpression'),
  ],
  DeclExpression: [
    o('ConditionalExpression'),
    o('TypeDecl VarDeclList', -> new DeclarationExpression($1, $2, 0))
  ],
  VarDeclList: [
    o('VarDecl', -> [$1])
  ],
  VarDecl: [
    o('ID', -> new VariableDeclaration($1))
  ]
  Literal: [
    o('NULL', -> new Null)
  ],
  TypeDecl: [
    o('TypeDeclA'),
    o('TypeDeclB')
  ],
  TypeDeclA: [
    o('ID', -> new TypeDeclaration($1, 0)),
    o('ID AT_SYM', -> new TypeDeclaration($1, 1))
  ],
  TypeDeclB: [
    o('LT IdDot GT', -> new TypeDeclaration($2, 0)),
    o('LT IdDot GT AT_SYM', -> new TypeDeclaration($2, 1))
  ],
  ConditionalExpression: [
    o('LogicalOrExpression')
  ],
  LogicalOrExpression: [
    o('LogicalAndExpression')
  ],
  LogicalAndExpression: [
    o('InclusiveOrExpression')
  ],
  InclusiveOrExpression: [
    o('ExclusiveOrExpression')
  ],
  ExclusiveOrExpression: [
    o('AndExpression')
  ],
  AndExpression: [
    o('EqualityExpression')
  ],
  EqualityExpression: [
    o('RelationalExpression')
  ],
  RelationalExpression: [
    o('ShiftExpression')
  ],
  ShiftExpression: [
    o('AdditiveExpression')
  ],
  AdditiveExpression: [
    o('MultiplicativeExpression')
  ],
  MultiplicativeExpression: [
    o('TildaExpression')
  ],
  TildaExpression: [
    o('CastExpression')
  ],
  CastExpression: [
    o('UnaryExpression')
  ],
  UnaryExpression: [
    o('DurExpression')
  ],
  DurExpression: [
    o('PostfixExpression'),
    o('DurExpression COLONCOLON PostfixExpression', -> new DurExpression($1, $3))
  ],
  PostfixExpression: [
    o('PrimaryExpression')
  ],
  PrimaryExpression: [
    o('ID', -> new PrimaryVariableExpression($1)),
    o('NUMBER', -> new PrimaryNumberExpression($1)),
    o('STRING_LIT', -> new PrimaryStringExpression($1))
    o('L_HACK Expression R_HACK', -> new PrimaryHackExpression($2))
  ]
}

operators = []

tokens = []
for name, alternatives of grammar
  #console.log("Name: #{name}, alternatives:", alternatives)
  grammar[name] = for alt in alternatives
    theseAlternatives = alt[0].split(' ')
#    console.log("Alternative: '#{theseAlternatives}'")
    for token in theseAlternatives
      if !grammar[token] && !_(tokens).some((t) -> t == token)
#        console.log("Terminal token: '#{token}'")
        tokens.push(token)
      else
#        console.log("Non-terminal token: '#{token}'")
    if name == "Program"
      alt[1] = "return #{alt[1]}"
    #alt[1] = "return #{alt[1]}" if name is 'Program'
    alt
#  console.log("Result:", grammar[name])

parserConfig = {
  tokens: tokens.join(' '),
  bnf: grammar,
  operators: operators.reverse(),
  startSymbol: 'Program'
}
console.log('Tokens:', parserConfig.tokens)
console.log('BNF:', parserConfig.bnf)
console.log('Operators:', parserConfig.operators)

# Use SLR algorithm as this works for our grammar unlike the default (LALR).
# LALR should work though, as it does with Bison...
exports.generate = new Parser(parserConfig, {type: "slr"}).generate
