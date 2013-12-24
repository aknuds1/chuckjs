define("chuck/vm", ["chuck/logging", "chuck/ugen", "chuck/types"], (logging, ugen, types) ->
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

      deferred = Q.defer()
      return @_compute(byteCode)

    _compute: (byteCode) =>
      logging.debug("VM executing")
      while @_pc < byteCode.length && @_isRunning()
        instr = byteCode[@_pc]
        logging.debug("Executing instruction no. #{@_pc}: #{instr.instructionName}")
        instr.execute(@)
        ++@_pc
      if !@_isRunning()
        logging.debug("Halted VM execution for #{@_wakeTime} seconds")
        setTimeout(@_compute, @_wakeTime*1000)
      else
        logging.debug("VM execution has ended")
        # TODO: Invoke promise success handler

      # TODO: Return promise

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
    vm.execute(byteCode)
    return undefined

  return module
)
