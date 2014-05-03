define("chuck/vm", ["chuck/logging", "chuck/ugen", "chuck/types", "chuck/audioContextService"],
(logging, ugen, types, audioContextService) ->
  module = {}

  class Shred
    constructor: (args) ->
      @args = args || []

  module.Vm = class Vm
    constructor: (args) ->
      @regStack = []
      @memStack = []
      # Stack holding the stacks of currently called functions
      @_funcMemStacks = []
      @isExecuting = false
      @_ugens = []
      @_dac = new ugen.Dac()
      @_wakeTime = undefined
      @_pc = 0
      @_nextPc = 1
      @_shouldStop = false
      @_now = 0
      @_me = new Shred(args)
      @_nowSystem = 0
      @_gain = 1

    execute: (byteCode) =>
      @_pc = 0
      @isExecuting = true

      deferred = Q.defer()
      setTimeout(=>
        if !@_compute(byteCode, deferred)
          logging.debug("Ending VM execution")
          @_terminateProcessing()
          deferred.resolve()
          return

        # Start audio processing
        logging.debug("Starting audio processing")
        @_scriptProcessor = audioContextService.createScriptProcessor()
        @_scriptProcessor.onaudioprocess = (event) =>
          try
            @_processAudio(event, byteCode, deferred)
          catch error
            @_terminateProcessing()
            deferred.reject("Caught exception in audio processing callback after #{@_nowSystem} samples: #{error}")

          return
      , 0)
      return deferred.promise

    stop: =>
      logging.debug("Stopping VM")
      @_shouldStop = true
      return

    _compute: (instructions, deferred) =>
      try
        if @_pc == 0
          logging.debug("VM executing")
        else
          logging.debug("Resuming VM execution")

        @instructions = instructions

        while @_pc < instructions.length && @_isRunning()
          instr = @instructions[@_pc]
          logging.debug("Executing instruction no. #{@_pc}: #{instr.instructionName}")
          instr.execute(@)
          @_pc = @_nextPc
          ++@_nextPc

        if @_wakeTime? && !@_shouldStop
          sampleRate = audioContextService.getSampleRate()
          logging.debug("Halting VM execution for #{(@_wakeTime - @_now)/sampleRate} second(s)")
          return true
        else
          @_shouldStop = true
          logging.debug("VM execution has ended after #{@_nowSystem} samples:", @_shouldStop)
          return false
      catch err
        deferred.reject(err)
        throw err

    addUgen: (ugen) =>
      @_ugens.push(ugen)
      return

    # Push value to regular stack
    pushToReg: (value) =>
      if !value?
        throw new Error('pushToReg: value is undefined')
      @regStack.push(value)
      return

    pushMemAddrToReg: (offset, isGlobal) =>
      value = if isGlobal then @memStack[offset] else @_getFuncMemStack()[offset]
      scopeStr = if isGlobal then "global" else "function"
      logging.debug("Pushing memory stack address #{offset} (scope: #{scopeStr}) to regular stack:", value)
      @regStack.push(offset)

    pushToRegFromMem: (offset, isGlobal) =>
      value = if isGlobal then @memStack[offset] else @_getFuncMemStack()[offset]
      scopeStr = if isGlobal then "global" else "function"
      logging.debug("Pushing memory stack value @#{offset} (scope: #{scopeStr}) to regular stack:", value)
      @regStack.push(value)

    popFromReg: =>
      val = @regStack.pop()
      if !val?
        throw new Error("Nothing on the stack")
      return val

    peekReg: (offset) =>
      if !offset?
        offset = 0
      return @regStack[@regStack.length-(1+offset)]

    insertIntoMemory: (index, value, isGlobal) =>
      scopeStr = if isGlobal then "global" else "function"
      logging.debug("Inserting value #{value} (#{typeof value}) into memory stack at index #{index} (scope: #{scopeStr})")
      if isGlobal
        @memStack[index] = value
      else
        @_getFuncMemStack()[index] = value
      return

    removeFromMemory: (index) =>
      logging.debug("Removing element #{index} of memory stack")
      @memStack.splice(index, 1)
      return

    getFromMemory: (index) =>
      val = @memStack[index]
      logging.debug("Getting value from memory stack at index #{index}: #{val}")
      val

    pushToMem: (value, isGlobal=true) =>
      if !value?
        throw new Error('pushToMem: value is undefined')
      if isGlobal
        logging.debug("Pushing value to global memory stack:", value)
        @memStack.push(value)
      else
        logging.debug("Pushing value to function memory stack:", value)
        @_getFuncMemStack().push(value)

    popFromMem: =>
      @memStack.pop()

    pushDac: =>
      @regStack.push(@_dac)
      return

    pushNow: =>
      logging.debug("Pushing now (#{@_now}) to stack")
      @regStack.push(@_now)
      return

    pushMe: =>
      logging.debug("Pushing me to stack:", @_me)
      @regStack.push(@_me)
      return

    suspendUntil: (time) =>
      logging.debug("Suspending VM execution until #{time} (now: #{@_now})")
      @_wakeTime = time
      return

    jumpTo: (jmp) =>
      @_nextPc = jmp
      return

    enterFunctionScope: =>
      logging.debug("Entering new function scope")
      @_funcMemStacks.push([])
    exitFunctionScope: =>
      logging.debug("Exiting current function scope")
      @_funcMemStacks.pop()

    _terminateProcessing: =>
      logging.debug("Terminating processing")
      @_dac.stop()
      if @_scriptProcessor?
        @_scriptProcessor.disconnect(0)
        @_scriptProcessor = undefined
      @isExecuting = false

    ###* Get the current function memory stack
      ###
    _getFuncMemStack: =>
      @_funcMemStacks[@_funcMemStacks.length-1]

    _isRunning: =>
      return !@_wakeTime? && !@_shouldStop

    _processAudio: (event, byteCode, deferred) =>
      # Compute each sample

      samplesLeft = event.outputBuffer.getChannelData(0)
      samplesRight = event.outputBuffer.getChannelData(1)

      if @_shouldStop
        logging.debug("Audio callback finishing execution after processing #{@_nowSystem} samples")
        for i in [0...event.outputBuffer.length]
          samplesLeft[i] = 0
          samplesRight[i] = 0
        @_terminateProcessing()
        deferred.resolve()
        return

      logging.debug("Audio callback processing #{event.outputBuffer.length} samples")
      for i in [0...event.outputBuffer.length]
        # Detect if the VM should be awoken
        if @_wakeTime <= (@_nowSystem + 0.5)
          @_now = @_wakeTime
          @_wakeTime = undefined
          logging.debug("Letting VM compute sample, now: #{@_now}")
          @_compute(byteCode, deferred)
#            else
#              logging.debug("VM is not yet ready to wake up (#{@_wakeTime}, #{@_nowSystem})")

        # Is it correct to advance system time before producing frame? This entails that the time of the
        # first frame will be 1 rather than 0; this is how the original ChucK does it however.
        ++@_nowSystem

        frame = [0, 0]
        if !@_shouldStop
          @_dac.tick(@_nowSystem, frame)
        samplesLeft[i] = frame[0] * @_gain
        samplesRight[i] = frame[1] * @_gain

      if @_shouldStop
        logging.debug("Audio callback: In the process of stopping, flushing buffers")
      logging.debug("Audio callback finished processing, currently at #{@_nowSystem} samples in total")
      return

  return module
)
