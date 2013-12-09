{Parser} = require 'jison'
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
    o('ProgramSection', -> new Program($1))
  ],
  ProgramSection: [
    o('StatementList', -> new SectionStatement($1))
  ],
  StatementList: [
    o('Statement', -> new StatementList($1))
  ],
  Statement: [
    o('ExpressionStatement')
  ],
  ExpressionStatement: [
    o('SEMICOLON', ->),
    o('Expression SEMICOLON', -> new ExpressionStatement($1))
  ],
  Expression: [
    o('ChuckExpression'),
    o('ChuckExpression COMMA expression', -> prependExpression($1, $3))
  ],
  ChuckExpression: [
    o('ArrowExpression'),
    o('ChuckExpression CHUCK ArrowExpression', -> new ExpFromBinary($1, $2, $3))
  ],
  ArrowExpression: [
    o('DeclExpression'),
    o('ArrowExpression ArrowOperator DeclExpression', -> new ExpFromBinary($1, $2, $3))
  ],
  DeclExpression: [
    o('ConditionalExpression'),
    o('TypeDecl VarDeclList', -> new DeclExp($1, $2, 0))
  ],
  VarDeclList: [
    o('VarDecl', -> new VarDeclList($1))
  ],
  VarDecl: [
    o('ID', -> new VarDecl($1))
  ]
  Literal: [
    o('NULL', -> new Null)
  ],
  TypeDecl: [
    o('TypeDeclA'),
    o('TypeDeclB')
  ],
  TypeDeclA: [
    o('ID', -> new TypeDecl(new IdList($1), 0)),
    o('ID AT_SYM', -> new TypeDecl(new IdList($1), 1))
  ],
  TypeDeclB: [
    o('LT IdDot GT', -> new TypeDecl($2, 0)),
    o('LT IdDot GT AT_SYM', -> new TypeDecl($2, 1))
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
    o('PostfixExpression')
  ],
  PostfixExpression: [
    o('PrimaryExpression')
  ],
  PrimaryExpression: [
    o('ID', -> new ExpFromId($1))
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
  lex: {
    rules: [
      ['\\/\\/.*', ""],
      ['[A-Za-z_][A-Za-z0-9_]*', "return 'ID'"],
      ['@', "return 'AT_SYM'"],
      ['\\s*', ""],
      [',', "return 'COMMA'"]
    ]
  },
  tokens: tokens.join(' '),
  bnf: grammar,
  operators: operators.reverse(),
  startSymbol: 'Program'
}
console.log('Tokens:', parserConfig.tokens)
console.log('BNF:', parserConfig.bnf)
console.log('Operators:', parserConfig.operators)

# Initialize the **Parser** with our list of terminal **tokens**, our **grammar**
# rules, and the name of the root. Reverse the operators because Jison orders
# precedence from low to high, and we have it high to low
# (as in [Yacc](http://dinosaur.compilertools.net/yacc/index.html)).
exports.generate = new Parser(parserConfig).generate
