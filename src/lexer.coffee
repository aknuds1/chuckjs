if require?
  {count, last,  throwSyntaxError} = require('./helpers')
else
  {count, last,  throwSyntaxError} = window.chuckJsHelpers

class Lexer
  tokenize: (code) ->
    @ends       = []             # The stack for pairing up tokens.
    @tokens     = []             # Stream of parsed tokens in the form `['TYPE', value, location data]`.

    @chunkLine = 0
    @chunkColumn = 0
    code = @clean(code)

    i = 0
    while @chunk = code[i..]
      consumed =
        @identifierToken() or
        @commentToken()    or
        @whitespaceToken() or
        @stringToken()     or
        @numberToken()     or
        @literalToken()
      console.log("Consumed #{consumed} characters")

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
      @chunkLine--
    code

  identifierToken: ->
    return 0 unless match = IDENTIFIER.exec @chunk
    console.log(match)
    id = match[0]
    console.log("Token is an identifier", id)

    # Preserve length of id for location data
    idLength = id.length
    poppedToken = undefined

    tag = 'ID'

    tagToken = @token tag, id, 0, idLength
    if poppedToken
      [tagToken[2].first_line, tagToken[2].first_column] =
      [poppedToken[2].first_line, poppedToken[2].first_column]

    return id.length

  # Matches numbers, including decimals, hex, and exponential notation.
  # Be careful not to interfere with ranges-in-progress.
  numberToken: ->
    return 0 unless match = NUMBER.exec @chunk
    number = match[0]
    console.log("Token is a number #{number}")
    if /^0[BOX]/.test number
      @error "radix prefix '#{number}' must be lowercase"
    else if /E/.test(number) and not /^0x/.test number
      @error "exponential notation '#{number}' must be indicated with a lowercase 'e'"
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

  stringToken: ->
    switch quote = @chunk.charAt 0
      when "'" then [string] = SIMPLESTR.exec @chunk
      when '"' then string = @balancedString @chunk, '"'
    return 0 unless string
    console.log("stringToken")
    trimmed = @removeNewlines string[1...-1]
    @token 'STRING', quote + @escapeLines(trimmed) + quote, 0, string.length
    string.length

  # Matches and consumes comments.
  commentToken: ->
    return 0 unless match = @chunk.match COMMENT
    [comment, here] = match
    console.log("Token is a comment")
    comment.length

  # Matches and consumes non-meaningful whitespace. Tag the previous token
  # as being "spaced", because there are some cases where it makes a difference.
  whitespaceToken: ->
    return 0 unless (match = WHITESPACE.exec @chunk) or
    (nline = @chunk.charAt(0) is '\n')
    if match?
      console.log("whitespaceToken '#{match[0]}'")
    prev = last @tokens
    prev[if match then 'spaced' else 'newLine'] = true if prev
    if match then match[0].length else 0

  literalToken: ->
    if match = OPERATOR.exec @chunk
      console.log(OPERATOR)
      console.log('Operator yes') if match
      [value] = match
      console.log("Token is an operator: '{value}'")
    else
      value = @chunk.charAt 0
      console.log("Token is not an operator", value)
    tag = value
    if value is ';'
      console.log('Token is a semicolon')
      tag = 'SEMICOLON'
    else if value in CHUCK
      tag = 'CHUCK'
    @token tag, value
    value.length

  getLineAndColumnFromChunk: (offset) ->
    if offset is 0
      return [@chunkLine, @chunkColumn]

    if offset >= @chunk.length
      string = @chunk
    else
      string = @chunk[..offset-1]

    lineCount = count(string, '\n')

    column = @chunkColumn
    if lineCount > 0
      lines = string.split('\n')
      column = last(lines).length
    else
      column += string.length

    [@chunkLine + lineCount, column]

  # Same as "token", exception this just returns the token without adding it
  # to the results.
  makeToken: (tag, value, offsetInChunk = 0, length = value.length) ->
    locationData = {}
    [locationData.first_line, locationData.first_column] =
    @getLineAndColumnFromChunk offsetInChunk

    # Use length - 1 for the final offset - we're supplying the last_line and the last_column,
    # so if last_column == first_column, then we're looking at a character of length 1.
    lastCharacter = Math.max 0, length - 1
    [locationData.last_line, locationData.last_column] =
    @getLineAndColumnFromChunk offsetInChunk + lastCharacter

    token = [tag, value, locationData]

    token

  token: (tag, value, offsetInChunk, length) ->
    token = @makeToken tag, value, offsetInChunk, length
    @tokens.push token
    console.log("Pushed token '#{token[0]}'")
    token

  # Throws a compiler error on the current position.
  error: (message, offset = 0) ->
    [first_line, first_column] = @getLineAndColumnFromChunk offset
    throwSyntaxError message, {first_line, first_column}

# The character code of the nasty Microsoft madness otherwise known as the BOM.
BOM = 65279

# Token matching regexes.
IDENTIFIER = /// ^
  [A-Za-z_][A-Za-z0-9_]*
///

NUMBER     = ///
  ^ 0[xX][0-9a-fA-F]+{IS}? |
  ^ 0[cC][0-7]+{IS}? |
  ^ [0-9]+{IS}? |
  ^ ([0-9]+"."[0-9]*)|([0-9]*"."[0-9]+) # Float
///i

OPERATOR   = /// ^ (
  ?: => | # Chuck
  <= | # Unchuck
  !=> # Unchuck
) ///

WHITESPACE = /^[^\n\S]+/

COMMENT    = /^###([^#][\s\S]*?)(?:###[^\n\S]*|###$)|^(?:\s*#(?!##[^#]).*)+/

TRAILING_SPACES = /\s+$/

# Chuck tokens.
CHUCK = ['=>', '<=', '!=>']

if exports?
  exports.Lexer = Lexer
else
  ChuckLexer = Lexer
