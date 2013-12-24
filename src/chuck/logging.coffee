define("chuck/logging", [], ->
  logger = undefined
  module = {}
  methods = ['error', 'warn', 'info', 'debug', 'trace']

  # Default no-op logging
  for name in methods
    module[name] = -> return undefined

  loggerProxy = (logger, level, others...) ->
    return logger[level].apply(logger, others)

  module.setLogger = (logger) ->
    for name in methods
      if !_(logger[name]).isFunction()
        throw new Error("Logger lacks method #{name}")

      module[name] = _(logger[name]).bind(logger)


  return module
)
