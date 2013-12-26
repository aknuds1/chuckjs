define("chuck", ["chuck/parserService", "chuck/scanner", "chuck/vm", "chuck/logging", "chuck/audioContextService"],
(parserService, scanner, vm, logging, audioContextService) ->
  module = {}

  module.Chuck = class
    execute: (sourceCode) =>
      audioContextService.prepareForExecution()

      ast = parserService.parse(sourceCode)
      byteCode = scanner.scan(ast)
      return vm.execute(byteCode)

    stop: =>
      return audioContextService.stopOperation()

  module.setLogger = (logger) ->
    logging.setLogger(logger)

  return module
)
