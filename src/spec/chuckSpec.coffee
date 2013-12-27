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
      fakeAudioContext.createGainNode.andReturn(fakeGainNode)
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
          return undefined
        ,
        (e) ->
          err = e
          return undefined
        )
        # The execution itself starts asynchronously - trigger it
        jasmine.Clock.tick(1)
      )

    verify = (verifyCb) ->
      waitsFor(->
        err?
      , "Execution should finish", 10)

      runs(->
        if err
          throw new Error("An exception was thrown asynchronously: #{err}")

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
        expect(fakeOscillator.connect).toHaveBeenCalledWith(fakeGainNode)
        # Sine
        expect(fakeOscillator.type).toBe(0)
        expect(fakeOscillator.frequency.value).toBe(220)
        expect(fakeOscillator.start).toHaveBeenCalledWith(0)

        # Let the program advance until its end
        jasmine.Clock.tick(2001)
      )

      verify(->
        expect(fakeOscillator.stop).toHaveBeenCalledWith(0)
        expect(fakeOscillator.disconnect).toHaveBeenCalledWith(0)
        expect(fakeGainNode.disconnect).not.toHaveBeenCalled()
      )
    )

    it("can stop a program", ->
      # TODO: Supply a program that doesn't halt on its own
      executeCode("SinOsc sin => dac;")
      runs(->
        chuck.stop()
      )

      verify(->
        now = fakeAudioContext.currentTime
        # This should be defined in test setup
        expect(now).toBeDefined()
        expect(fakeGainNode.gain.cancelScheduledValues).toHaveBeenCalledWith(now)
        expect(fakeOscillator.stop).toHaveBeenCalledWith(0)
        expect(fakeOscillator.disconnect).toHaveBeenCalledWith(0)
        expect(fakeGainNode.gain.value).toBe(0)
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
