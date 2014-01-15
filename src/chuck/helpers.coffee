define('chuck/helpers', [], ->
  module = {}

  # Count the number of occurrences of a string in a string.
  module.count = (string, substr) ->
    num = pos = 0
    return 1/0 unless substr.length
    num++ while pos = 1 + string.indexOf substr, pos
    num

  module.last = (array, back) -> array[array.length - (back or 0) - 1]

  module.throwSyntaxError = (message, location) ->
    error = new SyntaxError message
    error.location = location
    error.toString = syntaxErrorToString

    # Instead of showing the compiler's stacktrace, show our custom error message
    # (this is useful when the error bubbles up in Node.js applications that
    # compile CoffeeScript for example).
    error.stack = error.toString()
    throw error

  return module
)
