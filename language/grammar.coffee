{Parser} = require('jison')
_ = require('lodash')

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
    o('ProgramSectionList', -> new Program($1))
  ],
  ProgramSectionList: [
    o('ProgramSection', -> [$1])
    o('ProgramSection ProgramSectionList', -> [$1].concat($2))
  ],
  ProgramSection: [
    o('StatementList'),
    o('FunctionDefinition')
  ],
  StatementList: [
    o('Statement', -> [$1]),
    o('Statement StatementList', -> [$1].concat($2))
  ],
  Statement: [
    o('ExpressionStatement'),
    o('LoopStatement'),
    o('JumpStatement')
    o('CodeSegment'),
  ],
  ExpressionStatement: [
    o('SEMICOLON', -> return undefined),
    o('Expression SEMICOLON', -> new ExpressionStatement($1))
  ],
  Expression: [
    o('ChuckExpression', -> new ExpressionList($1)),
    o('ChuckExpression COMMA Expression', -> $3.prepend($1))
  ],
  ChuckExpression: [
    o('ArrowExpression'),
    o('ChuckExpression ChuckOperator ArrowExpression', -> new BinaryExpression($1, $2, $3))
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
    o('ID', -> new VariableDeclaration($1)),
    o('ID ArrayExpression', -> new VariableDeclaration($1, $2))
    o('ID ArrayEmpty', -> new VariableDeclaration($1, $2))
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
  TypeDecl2: [
    o('TypeDecl')
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
    o('ShiftExpression'),
    o('RelationalExpression LT ShiftExpression', -> new BinaryExpression($1, new LtOperator(), $3)),
    o('RelationalExpression GT ShiftExpression', -> new BinaryExpression($1, new GtOperator(), $3))
  ],
  ShiftExpression: [
    o('AdditiveExpression')
  ],
  AdditiveExpression: [
    o('MultiplicativeExpression'),
    o('AdditiveExpression PLUS MultiplicativeExpression', -> new BinaryExpression($1, new PlusOperator(), $3)),
    o('AdditiveExpression MINUS MultiplicativeExpression', -> new BinaryExpression($1, new MinusOperator(), $3))
  ],
  MultiplicativeExpression: [
    o('TildaExpression'),
    o("MultiplicativeExpression TIMES TildaExpression", -> new BinaryExpression($1, new TimesOperator(), $3))
    o("MultiplicativeExpression DIVIDE TildaExpression", -> new BinaryExpression($1, new DivideOperator(), $3))
  ],
  TildaExpression: [
    o('CastExpression')
  ],
  CastExpression: [
    o('UnaryExpression')
  ],
  UnaryExpression: [
    o('DurExpression'),
    o('PLUSPLUS UnaryExpression', -> new UnaryExpression(new PrefixPlusPlusOperator(), $2))
  ],
  DurExpression: [
    o('PostfixExpression'),
    o('DurExpression COLONCOLON PostfixExpression', -> new DurExpression($1, $3))
  ],
  PostfixExpression: [
    o('PrimaryExpression'),
    o('PostfixExpression ArrayExpression', -> new ArrayExpression($1, $2)),
    o('PostfixExpression LPAREN Expression RPAREN', -> new FuncCallExpression($1, $3)),
    o('PostfixExpression LPAREN RPAREN', -> new FuncCallExpression($1)),
    o('PostfixExpression DOT ID', -> new DotMemberExpression($1, $3)),
    o('PostfixExpression PLUSPLUS', -> new PostfixExpression($1, new PostfixPlusPlusOperator()))
  ],
  PrimaryExpression: [
    o('ID', -> new PrimaryVariableExpression($1)),
    o('NUMBER', -> new PrimaryIntExpression($1)),
    o('FLOAT', -> new PrimaryFloatExpression($1)),
    o('STRING_LIT', -> new PrimaryStringExpression($1)),
    o('L_HACK Expression R_HACK', -> new PrimaryHackExpression($2)),
    o('LPAREN Expression RPAREN', -> $2),
    o("ArrayExpression", -> new PrimaryArrayExpression($1))
  ],
  LoopStatement: [
    o('WHILE LPAREN Expression RPAREN Statement', -> new WhileStatement($3, $5)),
    o('FOR LPAREN ExpressionStatement ExpressionStatement Expression RPAREN Statement',
    -> new ForStatement($3, $4, $5, $7))
  ],
  CodeSegment: [
    o('LBRACE RBRACE', -> new CodeStatement()),
    o('LBRACE StatementList RBRACE', -> new CodeStatement($2))
  ],
  JumpStatement: [
    o('BREAK SEMICOLON', -> new BreakStatement())
  ],
  IdDot: [
    o('ID', -> [$1])
    o('ID DOT IdDot', -> $3.push($1))
  ],
  ArrayExpression: [
    o('LBRACK Expression RBRACK', -> new ArraySub($2))
  ],
  ArrayEmpty: [
    o('LBRACK RBRACK', -> new ArraySub())
  ],
  ChuckOperator: [
    o('CHUCK', -> new ChuckOperator()),
    o('AT_CHUCK', -> new AtChuckOperator()),
    o('PLUS_CHUCK', -> new PlusChuckOperator())
    o('MINUS_CHUCK', -> new MinusChuckOperator())
    o('UNCHUCK', -> new UnchuckOperator())
  ],
  FunctionDefinition: [
    o('FunctionDeclaration StaticDecl TypeDecl2 ID LPAREN ArgList RPAREN CodeSegment', ->
      new FunctionDefinition($1, $2, $3, $4, $6, $8)
    ),
    o('FunctionDeclaration StaticDecl TypeDecl2 ID LPAREN RPAREN CodeSegment', ->
      new FunctionDefinition($1, $2, $3, $4, [], $7)
    )
  ],
  ArgList: [
    o("TypeDecl VarDecl", -> [new Arg($1, $2)]),
    o("TypeDecl VarDecl COMMA ArgList", -> [new Arg($1, $2)].concat($4)),
  ],
  FunctionDeclaration: [
    o('FUNCTION', ->)
  ],
  StaticDecl: [
    o('', ->)
  ],
}

operators = []

tokens = []
for name, alternatives of grammar
  #console.log("Name: #{name}, alternatives:", alternatives)
  grammar[name] = for alt in alternatives
    theseAlternatives = alt[0].split(' ')
#    console.log("Alternative: '#{theseAlternatives}'")
    for token in theseAlternatives
      if !grammar[token] && !_.some(tokens, (t) -> t == token)
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
