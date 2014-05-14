define("chuck/vm", ["chuck/logging", "chuck/ugen", "chuck/types", "chuck/audioContextService"],
(logging, ugen, types, audioContextService) ->
  module = {}
  logDebug = -> #logging.debug.apply(null, arguments)

  compute = (self) ->
    if self._pc == 0
      logDebug("VM executing")
    else
      logDebug("Resuming VM execution")

    while self._pc < self.instructions.length && self._isRunning()
      instr = self.instructions[self._pc]
      logDebug("Executing instruction no. #{self._pc}: #{instr.instructionName}")
      instr.execute(self)
      self._pc = self._nextPc
      ++self._nextPc

    if self._wakeTime? && !self._shouldStop
      sampleRate = audioContextService.getSampleRate()
      logDebug("Halting VM execution for #{(self._wakeTime - self._now)/sampleRate} second(s)")
      return true
    else
      logDebug("VM execution has ended after #{self._nowSystem} samples:", self._shouldStop)
      self._shouldStop = true
      return false

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
      @_bunghole = new ugen.Bunghole()
      @_wakeTime = undefined
      @_pc = 0
      @_nextPc = 1
      @_shouldStop = false
      @_now = 0
      @_me = new Shred(args)
      @_nowSystem = 0
      @_gain = 1

    execute: (byteCode) ->
      @_pc = 0
      @isExecuting = true
      @instructions = byteCode

      deferred = Q.defer()
      setTimeout(=>
        if !compute(@)
          logDebug("Ending VM execution")
          @_terminateProcessing()
          deferred.resolve()
          return

        # Start audio processing
        logDebug("Starting audio processing")
        @_scriptProcessor = audioContextService.createScriptProcessor()
        @_scriptProcessor.onaudioprocess = (event) =>
          try
            @_processAudio(event, deferred)
          catch error
            @_terminateProcessing()
            deferred.reject("Caught exception in audio processing callback after #{@_nowSystem} samples: #{error}")

          return
      , 0)
      return deferred.promise

    stop: =>
      logDebug("Stopping VM")
      @_shouldStop = true
      return

    addUgen: (ugen) ->
      @_ugens.push(ugen)
      return

    # Push value to regular stack
    pushToReg: (value) ->
      if !value?
        throw new Error('pushToReg: value is undefined')
      @regStack.push(value)
      return

    pushMemAddrToReg: (offset, isGlobal) ->
      value = @_getMemStack(isGlobal)[offset]
      scopeStr = if isGlobal then "global" else "function"
      logDebug("Pushing memory stack address #{offset} (scope: #{scopeStr}) to regular stack:", value)
      @regStack.push(offset)

    pushToRegFromMem: (offset, isGlobal) ->
      value =  @_getMemStack(isGlobal)[offset]
      scopeStr = if isGlobal then "global" else "function"
      logDebug("Pushing memory stack value @#{offset} (scope: #{scopeStr}) to regular stack:", value)
      @regStack.push(value)

    popFromReg: ->
      val = @regStack.pop()
      if !val?
        throw new Error("Nothing on the stack")
      return val

    peekReg: (offset) ->
      if !offset?
        offset = 0
      return @regStack[@regStack.length-(1+offset)]

    insertIntoMemory: (index, value, isGlobal) ->
      scopeStr = if isGlobal then "global" else "function"
      logDebug("Inserting value #{value} (#{typeof value}) into memory stack at index #{index} (scope: #{scopeStr})")
      @_getMemStack(isGlobal)[index] = value
      return

    removeFromMemory: (index, isGlobal) ->
      logDebug("Removing element #{index} of memory stack")
      @_getMemStack(isGlobal).splice(index, 1)
      return

    getFromMemory: (index, isGlobal) ->
      memStack = @_getMemStack(isGlobal)
      val = memStack[index]
      scopeStr = if isGlobal then "global" else "function"
      logDebug("Getting value from memory stack at index #{index} (scope: #{scopeStr}):", val)
      val

    pushToMem: (value, isGlobal=true) ->
      if !value?
        throw new Error('pushToMem: value is undefined')
      memStack = @_getMemStack(isGlobal)
      if isGlobal
        logDebug("Pushing value to global memory stack:", value)
      else
        logDebug("Pushing value to function memory stack:", value)
      memStack.push(value)

    popFromMem: (isGlobal) ->
      @_getMemStack(isGlobal).pop()

    pushDac: ->
      @regStack.push(@_dac)
      return

    pushBunghole: ->
      @regStack.push(@_bunghole)
      return

    pushNow: ->
      logDebug("Pushing now (#{@_now}) to stack")
      @regStack.push(@_now)
      return

    pushMe: ->
      logDebug("Pushing me to stack:", @_me)
      @regStack.push(@_me)
      return

    suspendUntil: (time) ->
      logDebug("Suspending VM execution until #{time} (now: #{@_now})")
      @_wakeTime = time
      return

    jumpTo: (jmp) ->
      @_nextPc = jmp
      return

    enterFunctionScope: ->
      logDebug("Entering new function scope")
      @_funcMemStacks.push([])
    exitFunctionScope: ->
      logDebug("Exiting current function scope")
      @_funcMemStacks.pop()

    _terminateProcessing: ->
      logDebug("Terminating processing")
      @_dac.stop()
      if @_scriptProcessor?
        @_scriptProcessor.disconnect(0)
        @_scriptProcessor = undefined
      @isExecuting = false

    ###* Get the memory stack for the requested scope (global/function)
      ###
    _getMemStack: (isGlobal) ->
      if !isGlobal?
        throw new Error('isGlobal must be specified')
      if isGlobal
        @memStack
      else
        @_funcMemStacks[@_funcMemStacks.length-1]

    _isRunning: ->
      return !@_wakeTime? && !@_shouldStop

    _processAudio: (event, deferred) ->
      # Compute each sample

      samplesLeft = event.outputBuffer.getChannelData(0)
      samplesRight = event.outputBuffer.getChannelData(1)

      if @_shouldStop
        logDebug("Audio callback finishing execution after processing #{@_nowSystem} samples")
        for i in [0...event.outputBuffer.length]
          samplesLeft[i] = 0
          samplesRight[i] = 0
        @_terminateProcessing()
        deferred.resolve()
        return

      logDebug("Audio callback processing #{event.outputBuffer.length} samples")
      for i in [0...event.outputBuffer.length]
        # Detect if the VM should be awoken
        if @_wakeTime <= (@_nowSystem + 0.5)
          @_now = @_wakeTime
          @_wakeTime = undefined
          logDebug("Letting VM compute sample, now: #{@_now}")
          compute(@)
#            else
#              logDebug("VM is not yet ready to wake up (#{@_wakeTime}, #{@_nowSystem})")

        # Is it correct to advance system time before producing frame? This entails that the time of the
        # first frame will be 1 rather than 0; this is how the original ChucK does it however.
        ++@_nowSystem

        frame = [0, 0]
        if !@_shouldStop
          @_dac.tick(@_nowSystem, frame)
          # Suck samples
          @_bunghole.tick(@_nowSystem)
        samplesLeft[i] = frame[0] * @_gain
        samplesRight[i] = frame[1] * @_gain

      if @_shouldStop
        logDebug("Audio callback: In the process of stopping, flushing buffers")
      logDebug("Audio callback finished processing, currently at #{@_nowSystem} samples in total")
      return

  return module
)
