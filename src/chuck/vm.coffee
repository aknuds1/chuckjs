define("chuck/vm", ["chuck/logging", "chuck/ugen", "chuck/types", "q", "chuck/audioContextService"],
(logging, ugen, types, q, audioContextService) ->
  module = {}

  class Vm
    constructor: ->
      @regStack = []
      @memStack = []
      @isExecuting = false
      @_ugens = []
      @_dac = new ugen.Dac()
      @_wakeTime = undefined
      @_pc = 0
      @_nextPc = 1
      @_shouldStop = false
      @_now = 0
      @_nowSystem = 0
      @_gain = 1

    execute: (byteCode) =>
      @_pc = 0
      @isExecuting = true

      deferred = q.defer()
      setTimeout(=>
        if !@_compute(byteCode, deferred)
          logging.debug("Ending VM execution")
          return

        # Start audio processing
        logging.debug("Starting audio processing")
        @_scriptProcessor = audioContextService.createScriptProcessor()
        @_scriptProcessor.onaudioprocess = (event) =>
          if !event.playbackTime?
            logging.warn("onaudioprocess: event.playbackTime is undefined")
            return

          # Compute each sample

#          logging.debug("ScriptProcessorNode audio processing callback invoked for #{event.outputBuffer.length} samples,
#          current time: #{event.playbackTime * audioContextService.getSampleRate()}", event.playbackTime,
#            audioContextService.getSampleRate())

          samplesLeft = event.outputBuffer.getChannelData(0)
          samplesRight = event.outputBuffer.getChannelData(1)
          for i in [0..event.outputBuffer.length-1]
            @_nowSystem = event.playbackTime * audioContextService.getSampleRate() + i
            # Detect if the VM should be awoken
            if @_wakeTime <= (@_nowSystem + 0.5)
              @_now = @_wakeTime
              @_wakeTime = undefined
              logging.debug("Letting VM compute sample, now: #{@_now}")
              if !@_compute(byteCode, deferred)
                logging.debug("VM has finished execution, finishing audio callback")
                break
#            else
#              logging.debug("VM is not yet ready to wake up (#{@_wakeTime}, #{@_nowSystem})")

            frame = [0, 0]
            @_dac.tick(@_nowSystem, frame)
            samplesLeft[i] = frame[0] * @_gain
            samplesRight[i] = frame[1] * @_gain

            ++@_nowSystem

          return
      , 0)
      return deferred.promise

    stop: =>
      logging.debug("Stopping VM")
      @_shouldStop = true
      return

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
          @_pc = @_nextPc
          ++@_nextPc

        if @_wakeTime? && !@_shouldStop
          sampleRate = audioContextService.getSampleRate()
          logging.debug("Halting VM execution for #{(@_wakeTime - @_now)/sampleRate} second(s)")
          
#          cb = =>
#            @_compute(byteCode, deferred)
#          setTimeout(cb, @_wakeTime/sampleRate*1000)
          return true
        else
          logging.debug("VM execution has ended")
          @_terminateProcessing()
          deferred.resolve()
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
        throw new Error('value is undefined')
      @regStack.push(value)
      return

    pushToRegFromMem: (offset) =>
      value = @memStack[offset]
      logging.debug("Pushing memory stack element #{offset} (#{value}) to regular stack")
      @regStack.push(value)

    popFromReg: =>
      val = @regStack.pop()
      if !val?
        throw new Error("Nothing on the stack")
      return val

    peekReg: =>
      return @regStack[@regStack.length-1]

    insertIntoMemory: (index, value) =>
      logging.debug("Inserting value #{value} into memory stack at index #{index}")
      @memStack[index] = value
      return

    removeFromMemory: (index) =>
      logging.debug("Removing element #{index} of memory stack")
      @memStack.splice(index, 1)
      return

    pushToMem: (value) =>
      if !value?
        throw new Error('value is undefined')
      @memStack.push(value)

    pushDac: =>
      @regStack.push(@_dac)
      return

    pushNow: =>
      logging.debug("Pushing now (#{@_now}) to stack")
      @regStack.push(@_now)
      return

    suspendUntil: (time) =>
      logging.debug("Suspending VM execution until #{time}")
      @_wakeTime = time
      return

    jumpTo: (jmp) =>
      @_nextPc = jmp
      return

    _terminateProcessing: =>
      logging.debug("Terminating processing")
      @_dac.stop()
      @_scriptProcessor.disconnect(0)
      @_scriptProcessor = undefined
      @isExecuting = false

    _isRunning: =>
      return !@_wakeTime? && !@_shouldStop

  module.Vm = Vm

  return module
)
