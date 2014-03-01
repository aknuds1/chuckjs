define(['chuck', "q", "spec/helpers", "chuck/types"], (chuckModule, q, helpers, chuckTypes) ->

  describe("Chuck", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(chuckTypes.SinOsc, "ugenTick")
      spyOn(console, 'log')
    )

    afterEach(->
      helpers.afterEach()
    )

    verifySinOsc = (sinOsc, frequency=220, gain=1) ->
      expect(sinOsc.type.name).toBe("SinOsc")
      expect(sinOsc.data.num).toBe((1/helpers.fakeAudioContext.sampleRate)*frequency,
        "Frequency should be correctly set")
      expect(sinOsc._gain).toBe(gain, "Gain should be correctly set")

    it("can execute a program", ->
      executeCode("""SinOsc sin => dac;
2::second => now;
"""
      )

      runs(->
        # Verify the program's execution
        expect(helpers.fakeAudioContext.createScriptProcessor).toHaveBeenCalled()
        expect(helpers.fakeScriptProcessor.connect).toHaveBeenCalledWith(helpers.fakeAudioContext.destination)

        # Sine
        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(1, "Sine oscillator should be connected to DAC")
        sine = dac._channels[0].sources[0]
        expect(dac._channels[1].sources).toEqual([sine], "Sine oscillator should be connected to DAC")
        verifySinOsc(sine)
      )

      verify(->
        dac = helpers.getDac()
        for i in [0...dac._channels.length]
          channel = dac._channels[i]
          expect(channel.sources.length).toBe(0, "DAC channel #{i} sources should be empty")
        expect(helpers.fakeScriptProcessor.disconnect).toHaveBeenCalled()
      , 2)
    )

    it("supports adjusting oscillator parameters", ->
      executeCode("""SinOsc sin => dac;
0.6 => sin.gain;
440 => sin.freq;
1::second => now;
""")

      runs(->
        dac = helpers.getDac()
        sine = dac._channels[0].sources[0]
        verifySinOsc(sine, 440, 0.6)
      )

      verify(null, 1)
    )

    describe('looping', ->
      describe('while', ->
        it('supports infinite loops', ->
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
            # Audio callback should discover upon first invocation that there's nothing to do
            helpers.processAudio(0)
          )

          verify()
          return
        )

        it('supports breaking out of loops', ->
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
            return
          )

          verify(null, 1)
          return
        )

        it('supports a greater than int condition', ->
          executeCode("""\
1 => int c;
while (c > 0)
{
  0 => c;
  <<<c>>>;
}
"""
          )

          verify(->
            expect(console.log).toHaveBeenCalledWith("0 : (int)")
          )
          return
        )
      )
    )

    describe('Console interaction', ->
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
