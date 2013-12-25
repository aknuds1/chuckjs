define(['chuck'], (chuckModule) ->
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
    chuckModule.setLogger(new Logger())

    beforeEach(->
      jasmine.Clock.useMock();

      fakeAudioContext = jasmine.createSpyObj("AudioContext", ["createGainNode", "createOscillator"])
      fakeAudioContext.currentTime = 1
      fakeAudioContext.destination = {name: "destination"}
      fakeGainNode = jasmine.createSpyObj("gainNode", ["connect"])
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
    )

    describe("execute", ->
      it("can execute a program", ->
        success = undefined

        runs(->
          chuck.execute("""SinOsc sin => dac;
2::second => now;
"""
          )
            .then(-> success = true)
            .fail(-> success = false)
          jasmine.Clock.tick(2001)
        )

        waitsFor(-> success?)

        runs(->
          expect(success).toBe(true)
          expect(fakeAudioContext.createGainNode).toHaveBeenCalled()
          expect(fakeGainNode.connect).toHaveBeenCalledWith(fakeAudioContext.destination)
          expect(fakeGainNode.gain.cancelScheduledValues).toHaveBeenCalledWith(0);
          expect(fakeGainNode.gain.value).toBe(1)
          expect(fakeOscillator.connect).toHaveBeenCalledWith(fakeGainNode)
          # Sine
          expect(fakeOscillator.tyoe).toBe(0)
          expect(fakeOscillator.frequency.value).toBe(440)
          expect(fakeOscillator.start).toHaveBeenCalledWith(0)
        )
      )
    )

    describe("stop", ->
      it("can stop a program", ->
        # TODO: Supply a program that doesn't halt on its own
        chuck.execute("SinOsc sin => dac;")
        callback = jasmine.createSpy("stopCallback")
        chuck.stop(callback)

        now = fakeAudioContext.currentTime
        # This should be defined in test setup
        expect(now).toBeDefined()
        expect(fakeGainNode.gain.cancelScheduledValues).toHaveBeenCalledWith(now)
        expect(fakeGainNode.gain.setValueAtTime).toHaveBeenCalledWith(fakeGainNode.gain.value, now)
        stopDuration = 0.15
        stopTime = now + stopDuration
        expect(fakeGainNode.gain.linearRampToValueAtTime).toHaveBeenCalledWith(0, stopTime)
        expect(callback).not.toHaveBeenCalled()
        jasmine.Clock.tick(stopDuration*1000 + 1)
        expect(callback).toHaveBeenCalled()
        expect(fakeOscillator.stop).toHaveBeenCalledWith(0)
        expect(fakeOscillator.disconnect).toHaveBeenCalledWith(0)
      )
    )
  )
)
