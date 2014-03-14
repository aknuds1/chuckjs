define("chuck/logging", [], ->
  logger = undefined
  module = {}
  methods = ['error', 'warn', 'info', 'debug', 'trace']

  # Default no-op logging
  for name in methods
    module[name] = -> undefined

  module.setLogger = (logger) ->
    for name in methods
      if !_.isFunction(logger[name])
        throw new Error("Logger lacks method #{name}")

      module[name] = _.bind(logger[name], logger)

  return module
)
