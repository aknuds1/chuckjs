define(['chuck', "q", "spec/helpers"], (chuckModule, q, helpers) ->
  describe("Chuck", ->
    origAudioContext = window.AudioContext || window.webkitAudioContext
    fakeAudioContext = undefined
    fakeGainNode = undefined
    fakeOscillator = undefined
    fakeOscillatorGainNode = undefined
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()

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
    )

    afterEach(->
      window.AudioContext = origAudioContext
      helpers.afterEach()
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

      verify(->
        expect(fakeOscillatorGainNode.gain.value).toBe(0.6)
        expect(fakeOscillator.frequency.value).toBe(440)
      , 1001)
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
          expect(helpers.isChuckExecuting()).toBe(true)
          helpers.stopChuck()
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
          expect(helpers.isChuckExecuting()).toBe(true)
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
