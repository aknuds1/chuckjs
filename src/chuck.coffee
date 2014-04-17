define("chuck", ["chuck/parserService", "chuck/scanner", "chuck/vm", "chuck/logging", "chuck/audioContextService"],
(parserService, scanner, vmModule, logging, audioContextService) ->
  module = {}

  module.Chuck = class
    execute: (sourceCode) =>
      audioContextService.prepareForExecution()

      ast = parserService.parse(sourceCode)
      byteCode = scanner.scan(ast)
      @_vm = new vmModule.Vm()
      return @_vm.execute(byteCode)

    stop: =>
      if !@isExecuting()
        return

      @_vm.stop()
      return audioContextService.stopOperation()

    isExecuting: =>
      if !@_vm?
        return
      @_vm.isExecuting

  module.setLogger = (logger) ->
    logging.setLogger(logger)

  return module
)
