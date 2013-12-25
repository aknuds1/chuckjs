define("chuck/vm", ["chuck/logging", "chuck/ugen", "chuck/types", "q"], (logging, ugen, types, q) ->
  module = {}

  class Vm
    constructor: ->
      @regStack = []
      @memStack = []
      @_ugens = []
      @_dac = new ugen.UGen(types.Dac)
      @_now = 0
      @_wakeTime = undefined
      @_pc = 0

    _isRunning: =>
      return !@_wakeTime?

    execute: (byteCode) =>
      @_pc = 0

      deferred = q.defer()
      @_compute(byteCode, deferred)
      return deferred.promise

    _compute: (byteCode, deferred) =>
      try
        if @_pc == 0
          logging.debug("VM executing")
        else
          logging.debug("Resuming VM execution")
        while @_pc < byteCode.length && @_isRunning()
          instr = byteCode[@_pc]
          logging.debug("Executing instruction no. #{@_pc}: #{instr.instructionName}")
          instr.execute(@)
          ++@_pc
        if @_wakeTime?
          logging.debug("Halting VM execution for #{@_wakeTime} seconds")
          cb = => @_compute(byteCode, deferred)
          setTimeout(cb, @_wakeTime*1000)
          @_wakeTime = undefined
        else
          logging.debug("VM execution has ended")
          deferred.resolve()
      catch err
        deferred.reject(err)

    addUgen: (ugen) =>
      @_ugens.push(ugen)
      return undefined

    # Push value to regular stack
    pushToReg: (value) =>
      @regStack.push(value)
      return undefined

    popFromReg: =>
      return @regStack.pop()

    peekReg: =>
      return @regStack[@regStack.length-1]

    insertIntoMemory: (index, value) =>
      logging.debug("Inserting value #{value} into memory stack at index #{index}")
      @memStack[index] = value
      return undefined

    removeFromMemory: (index) =>
      logging.debug("Removing object at index #{index} of memory stack")
      @memStack.splice(index, 1)
      return undefined

    pushDac: =>
      @regStack.push(@_dac)
      return undefined

    pushNow: =>
      @regStack.push(@_now)
      return undefined

    suspendUntil: (time) =>
      @_wakeTime = time
      return undefined

  module.execute = (byteCode) ->
    vm = new Vm()
    return vm.execute(byteCode)

  return module
)
