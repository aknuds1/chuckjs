define(['chuck', "q"], (chuckModule, q) ->
  class Logger
    debug: ->
      console.debug.apply(undefined, arguments)
    warn: ->
      console.warn.apply(undefined, arguments)
    trace: ->
      console.trace.apply(undefined, arguments)
    error: ->
      console.error.apply(undefined, arguments)
    info: ->
      console.info.apply(undefined, arguments)

  describe("Chuck", ->
    origAudioContext = window.AudioContext || window.webkitAudioContext
    fakeAudioContext = undefined
    fakeGainNode = undefined
    fakeOscillator = undefined
    fakeOscillatorGainNode = undefined
    chuck = undefined
    err = undefined
    chuckModule.setLogger(new Logger())
    # Disable too eager logging of supposedly unhandled promise rejections
    q.stopUnhandledRejectionTracking()

    beforeEach(->
      err = undefined
      jasmine.Clock.useMock();

      fakeAudioContext = jasmine.createSpyObj("AudioContext", ["createGainNode", "createOscillator"])
      fakeAudioContext.currentTime = 1
      fakeAudioContext.destination = {name: "destination"}
      fakeGainNode = jasmine.createSpyObj("gainNode", ["connect", "disconnect"])
      fakeGainNode.gain = jasmine.createSpyObj("gainNode.gain", ["cancelScheduledValues", "setValueAtTime",
        "linearRampToValueAtTime"])
      numCalls = 0
      fakeAudioContext.createGainNode.andCallFake(->
        if numCalls == 0
          node = fakeGainNode
        else if numCalls == 1
          node = fakeOscillatorGainNode
        else
          throw new Error("Don't know which gain node to return")
        ++numCalls
        return node
      )
      fakeOscillatorGainNode = jasmine.createSpyObj("oscillatorGainNode", ["connect", "disconnect"])
      fakeOscillatorGainNode.gain = {}
      fakeOscillator = jasmine.createSpyObj("oscillator", ["connect", "start", "stop", "disconnect"])
      fakeOscillator.frequency = {}
      fakeAudioContext.createOscillator.andReturn(fakeOscillator)

      # Fake constructor
      window.AudioContext = ->
        _(this).extend(fakeAudioContext)

      chuck = new chuckModule.Chuck()
    )

    afterEach(->
      window.AudioContext = origAudioContext
      # Reset shared state
      err = undefined
      runs(->
        chuck.stop()
          .done(->
            err = false
          ,
          (e) ->
            err = e
          )
      )
      waitsFor(->
        err?
      , 10)
      runs(->
        if err
          throw new Error("Failed to stop ChucK: #{err}")
      )
    )

    # Execute code asynchronously; when execution has finished define the 'err' variable
    executeCode = (code) ->
      runs(->
        chuck.execute(code)
        .done(->
          err = false
          return
        ,
        (e) ->
          err = e
          return
        )
        # The execution itself starts asynchronously - trigger it
        jasmine.Clock.tick(1)
        return
      )
      return

    verify = (verifyCb) ->
      waitsFor(->
        err?
      , "Execution should finish", 10)

      runs(->
        if err
          throw new Error("An exception was thrown asynchronously: #{err}")

        expect(chuck.isExecuting()).toBe(false)
        if verifyCb?
          verifyCb()
      )

    it("can execute a program", ->
      executeCode("""SinOsc sin => dac;
2::second => now;
"""
      )

      runs(->
        # Verify the program's execution
        expect(fakeAudioContext.createGainNode).toHaveBeenCalled()
        expect(fakeGainNode.connect).toHaveBeenCalledWith(fakeAudioContext.destination)
        expect(fakeGainNode.gain.cancelScheduledValues).toHaveBeenCalledWith(0);
        expect(fakeGainNode.gain.value).toBe(1)
        expect(fakeOscillator.connect).toHaveBeenCalledWith(fakeOscillatorGainNode)
        expect(fakeOscillatorGainNode.connect).toHaveBeenCalledWith(fakeGainNode)
        expect(fakeOscillatorGainNode.gain.value).toBe(1)
        # Sine
        expect(fakeOscillator.type).toBe(0)
        expect(fakeOscillator.frequency.value).toBe(220)
        expect(fakeOscillator)
        expect(fakeOscillator.start).toHaveBeenCalledWith(0)

        # Let the program advance until its end
        jasmine.Clock.tick(2001)
      )

      verify(->
        expect(fakeOscillator.stop).toHaveBeenCalledWith(0)
        expect(fakeOscillatorGainNode.disconnect).toHaveBeenCalledWith(0)
        expect(fakeGainNode.disconnect).not.toHaveBeenCalled()
      )
    )

    it("supports adjusting oscillator parameters", ->
      executeCode("""SinOsc sin => dac;
0.6 => sin.gain;
440 => sin.freq;
1::second => now;
""")

      runs(->
        expect(fakeOscillator.frequency.value).toBe(440)
        expect(fakeOscillator.frequency.value).toBe(440)
      )
    )

    describe('looping', ->
      it('supports infinite while loops', ->
        # An infinite loop that sleeps between iterations so that we can stop the VM while it's sleeping
        executeCode("""while (true)
{
  1::second => now;
}
"""
        )
        runs(->
          expect(chuck.isExecuting()).toBe(true)
          chuck.stop()
          # Wake the VM up so that it can proceed to stop
          jasmine.Clock.tick(1001)
        )

        verify()
        return
      )

      it('supports breaking out of while loops', ->
        # Break and sleep, so that we can verify that code after the loop is executed
        executeCode("""while (true)
{
  break;
}
1::second => now;
"""
        )
        runs(->
          expect(chuck.isExecuting()).toBe(true)
          # Wake the VM up
          jasmine.Clock.tick(1001)

          verify()
          return
        )
        return
      )
    )

    describe('Console interaction', ->
      beforeEach(->
        spyOn(console, 'log')
      )

      it('can print to the console', ->
        str = "Hello world!"
        executeCode("<<<\"#{str}\">>>;")

        verify(->
          expect(console.log).toHaveBeenCalledWith("\"#{str}\" : (String)")
        )
      )
    )
  )
)
