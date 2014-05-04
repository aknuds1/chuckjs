define("chuck", ["chuck/parserService", "chuck/scanner", "chuck/vm", "chuck/logging", "chuck/audioContextService"],
(parserService, scanner, vmModule, logging, audioContextService) ->
  module = {}

  module.Chuck = class
    constructor: (@audioContext, @audioDestination) ->

    execute: (sourceCode, args) =>
      audioContextService.prepareForExecution(@audioContext, @audioDestination)

      ast = parserService.parse(sourceCode)
      byteCode = scanner.scan(ast)
      @_vm = new vmModule.Vm(args)
      return @_vm.execute(byteCode)

    stop: =>
      if !@isExecuting()
        deferred = Q.defer()
        deferred.resolve()
        deferred.promise

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
