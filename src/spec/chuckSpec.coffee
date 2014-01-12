define(['chuck', "q", "spec/helpers"], (chuckModule, q, helpers) ->
  describe("Chuck", ->
    fakeOscillator = undefined
    fakeOscillatorGainNode = undefined
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      fakeOscillatorGainNode = jasmine.createSpyObj("oscillatorGainNode", ["connect", "disconnect"])
      fakeOscillatorGainNode.gain = {}
      numCalls = 0
      helpers.fakeAudioContext.createGainNode.andCallFake(->
        if numCalls == 0
          node = helpers.fakeGainNode
        else if numCalls == 1
          node = fakeOscillatorGainNode
        else
          throw new Error("Don't know which gain node to return")
        ++numCalls
        return node
      )
      fakeOscillator = jasmine.createSpyObj("oscillator", ["connect", "start", "stop", "disconnect"])
      fakeOscillator.frequency = {}
      helpers.fakeAudioContext.createOscillator.andReturn(fakeOscillator)
    )

    afterEach(->
      helpers.afterEach()
    )

    it("can execute a program", ->
      executeCode("""SinOsc sin => dac;
2::second => now;
"""
      )

      runs(->
        # Verify the program's execution
        expect(helpers.fakeAudioContext.createGainNode).toHaveBeenCalled()
        expect(helpers.fakeGainNode.connect).toHaveBeenCalledWith(helpers.fakeAudioContext.destination)
        expect(helpers.fakeGainNode.gain.cancelScheduledValues).toHaveBeenCalledWith(0);
        expect(helpers.fakeGainNode.gain.value).toBe(1)
        expect(fakeOscillator.connect).toHaveBeenCalledWith(fakeOscillatorGainNode)
        expect(fakeOscillatorGainNode.connect).toHaveBeenCalledWith(helpers.fakeGainNode)
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
        expect(helpers.fakeGainNode.disconnect).not.toHaveBeenCalled()
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
