define("chuck/lexer", ["chuck/helpers", "chuck/logging"], (helpers, logging) ->
  {count, last,  throwSyntaxError} = helpers

  class Lexer
    tokenize: (code) ->
      @ends       = []             # The stack for pairing up tokens.
      @tokens     = []             # Stream of parsed tokens in the form `['TYPE', value, location data]`.

      @chunkLine = 0
      @chunkColumn = 0
      code = @clean(code)

      @_matchers = []
      for own k, v of MATCHERS
        @_matchers.push([new RegExp("^#{k}"), v])

      i = 0
      while @chunk = code[i..]
        #logging.debug("Consuming chunk #{@chunk} at position #{i}")
        consumed =
          @identifierToken() or
          @floatToken()      or
          @intToken()        or
          @commentToken()    or
          @_matchToken()     or
          @whitespaceToken() or
          @stringToken()     or
          @literalToken()

        # Update position
        [@chunkLine, @chunkColumn] = @getLineAndColumnFromChunk(consumed)

        i += consumed

      @error "missing #{tag}" if tag = @ends.pop()
      return @tokens

    clean: (code) ->
      code = code.slice(1) if code.charCodeAt(0) is BOM
      code = code.replace(/\r/g, '').replace TRAILING_SPACES, ''
      if WHITESPACE.test code
        code = "\n#{code}"
        --@chunkLine
      code

    identifierToken: ->
      return 0 unless match = IDENTIFIER.exec(@chunk)
      id = match[0]
      idLength = id.length

      tag = 'ID'
      if id of ALIAS_MAP
        id = ALIAS_MAP[id]
      if id in KEYWORDS
        tag = id.toUpperCase()
        logging.debug("Token is a keyword: '#{id}'")
      else
        logging.debug("Token is an identifier: '#{id}'")

      poppedToken = undefined

      tagToken = @token tag, id, 0, idLength
      if poppedToken
        [tagToken[2].first_line, tagToken[2].first_column] = [poppedToken[2].first_line, poppedToken[2].first_column]

      logging.debug("Consumed ID of length #{idLength}")
      idLength

    # Matches integer numbers
    intToken: ->
      return 0 unless match = NUMBER.exec @chunk
      number = match[0]
      logging.debug("Token is an integer: #{number}")
      if /^0[BOX]/.test number
        @error "radix prefix '#{number}' must be lowercase"
      else if /^0\d*[89]/.test number
        @error "decimal literal '#{number}' must not be prefixed with '0'"
      else if /^0\d+/.test number
        @error "octal literal '#{number}' must be prefixed with '0o'"
      lexedLength = number.length
      if octalLiteral = /^0o([0-7]+)/.exec number
        number = '0x' + parseInt(octalLiteral[1], 8).toString 16
      if binaryLiteral = /^0b([01]+)/.exec number
        number = '0x' + parseInt(binaryLiteral[1], 2).toString 16
      @token 'NUMBER', number, 0, lexedLength
      lexedLength

    # Matches floating point numbers
    floatToken: ->
      return 0 unless match = FLOAT.exec @chunk
      number = match[0]
      logging.debug("Token is a float: #{number}")
      if /E/.test(number) and not /^0x/.test number
        @error "exponential notation '#{number}' must be indicated with a lowercase 'e'"
      lexedLength = number.length
      @token 'FLOAT', number, 0, lexedLength
      lexedLength

    stringToken: ->
      return 0 unless match = /^"(.+)"/.exec(@chunk)
      string = match[1]
      logging.debug("Token is a string: '#{string}', #{string.length}")
      @token('STRING_LIT', string)
      return match[0].length

    # Matches and consumes comments.
    commentToken: ->
      return 0 unless match = @chunk.match COMMENT
      [comment] = match
      logging.debug("Token is a comment", comment)
      return comment.length

    # Matches and consumes non-meaningful whitespace. Tag the previous token
    # as being "spaced", because there are some cases where it makes a difference.
    whitespaceToken: ->
      return 0 unless (match = WHITESPACE.exec @chunk) or (nline = @chunk.charAt(0) is '\n')
      if match?
        logging.debug("Consuming whitespace of length #{match[0].length}")
      prev = last @tokens
      prev[if match then 'spaced' else 'newLine'] = true if prev
      return if match then match[0].length else 0

    # The last token matcher, will create a token for any non-matched input
    literalToken: ->
      if match = /^;/.exec(@chunk)
        [value] = match
        tag = 'SEMICOLON'
        logging.debug('Token is a semicolon')
      else
        value = @chunk
        logging.debug("Unmatched token: '#{value}'")

      @token(tag, value)
      return value.length

    _matchToken: =>
      for matcher in @_matchers
        [re, token] = matcher
        match = re.exec(@chunk)
        if !match?
          #logging.debug("No match against '#{re}'")
          continue

        [value] = match
        logging.debug("Matched text '#{value}' against token #{token}")
        @token(token, value)
        return value.length

      return 0

    getLineAndColumnFromChunk: (offset) ->
      if offset is 0
        return [@chunkLine, @chunkColumn]

      if offset >= @chunk.length
        string = @chunk
      else
        string = @chunk[...offset]

      lineCount = count(string, '\n')

      column = @chunkColumn
      if lineCount > 0
        lines = string.split('\n')
        column = last(lines).length
      else
        column += string.length

      return [@chunkLine + lineCount, column]

    # Same as "token", exception this just returns the token without adding it
    # to the results.
    makeToken: (tag, value, offsetInChunk = 0, length = value.length) ->
      locationData = {}
      [locationData.first_line, locationData.first_column] = @getLineAndColumnFromChunk offsetInChunk

      # Use length - 1 for the final offset - we're supplying the last_line and the last_column,
      # so if last_column == first_column, then we're looking at a character of length 1.
      lastCharacter = Math.max 0, length - 1
      [locationData.last_line, locationData.last_column] =
      @getLineAndColumnFromChunk offsetInChunk + lastCharacter

      token = [tag, value, locationData]

      return token

    token: (tag, value, offsetInChunk, length) ->
      token = @makeToken(tag, value, offsetInChunk, length)
      @tokens.push token
      logging.debug("Pushed token '#{token[0]}'")
      return token

    # Throws a compiler error on the current position.
    error: (message, offset = 0) ->
      [first_line, first_column] = @getLineAndColumnFromChunk offset
      throwSyntaxError(message, {first_line, first_column})

  BOM = 65279

  # Token matching regexes.

  IDENTIFIER = /// ^
    [A-Za-z_][A-Za-z0-9_]*
  ///

  NUMBER = ///
    ^ 0[xX][0-9a-fA-F]+ |
    ^ 0[cC][0-7]+ |
    ^ [0-9]+
  ///i
  FLOAT = ///
    ^ (?:\d+\.\d*)|
    ^ (?:\d*\.\d+)
  ///i

  WHITESPACE = /^\s+/

  COMMENT = ///
    ^(?:\s*//.*)+
    ///

  TRAILING_SPACES = /\s+$/

  MATCHERS =
    '\\+\\+': 'PLUSPLUS'
    '\\-\\-': 'MINUSMINUS'
    ',': 'COMMA'
    '=>': 'CHUCK'
    '=<': 'UNCHUCK'
    '@=>': 'AT_CHUCK'    
    '\\+=>': 'PLUS_CHUCK'
    '-=>': 'MINUS_CHUCK'
    '::': 'COLONCOLON'
    '<<<': 'L_HACK'
    '>>>': 'R_HACK'
    '\\(': 'LPAREN'
    '\\)': 'RPAREN'
    '\\{': 'LBRACE'
    '\\}': 'RBRACE'
    '\\.': 'DOT'
    '\\+': 'PLUS'
    '-': 'MINUS'
    '\\*': 'TIMES'
    '\\/': 'DIVIDE'
    '<': 'LT'
    '>': 'GT'
    '\\[': 'LBRACK'
    '\\]': 'RBRACK'

  KEYWORDS = [
    'function'
    'while'
    'for'
    'break'
  ]

  ALIAS_MAP = {
    'fun': 'function'
  }

  return {
    tokenize: (sourceCode) ->
      return new Lexer().tokenize(sourceCode)
  }
)
