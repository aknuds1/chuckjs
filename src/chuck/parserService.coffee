define("chuck/parserService", ["chuck/lexer", "chuck/nodes", "chuck/logging"], (lexer, nodes, logging) ->
  yy = _.extend({}, nodes)

  yy.addLocationDataFn = (first, last) ->
    return (obj) ->
      return obj

  return {
    parse: (sourceCode) ->
      parser = new ChuckParser()
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

      tokens = lexer.tokenize(sourceCode)
      logging.debug("Parsing tokens:", tokens)
      return parser.parse(tokens)
  }
)
