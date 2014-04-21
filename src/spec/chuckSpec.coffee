define(['chuck', "q", "spec/helpers", "chuck/types"], (chuckModule, q, helpers, typesModule) ->
  describe("Chuck", ->
    {executeCode, verify} = helpers
    {types} = typesModule

    beforeEach(->
      helpers.beforeEach()
      spyOn(types.SinOsc, "ugenTick")
      spyOn(console, 'log')
    )

    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("can execute a program", (done) ->
      promise = executeCode("""SinOsc sin => dac;
2::second => now;
"""
      )

      # Verify the program's execution
      expect(helpers.fakeAudioContext.createScriptProcessor).toHaveBeenCalled()
      expect(helpers.fakeScriptProcessor.connect).toHaveBeenCalledWith(helpers.fakeAudioContext.destination)

      # Sine
      dac = helpers.getDac()
      expect(dac._channels[0].sources.length).toBe(1, "Sine oscillator should be connected to DAC")
      sine = dac._channels[0].sources[0]
      expect(dac._channels[1].sources).toEqual([sine], "Sine oscillator should be connected to DAC")
      helpers.verifySinOsc(sine)

      verify(promise, done, ->
        dac = helpers.getDac()
        for i in [0...dac._channels.length]
          channel = dac._channels[i]
          expect(channel.sources.length).toBe(0, "DAC channel #{i} sources should be empty")
        expect(helpers.fakeScriptProcessor.disconnect).toHaveBeenCalled()
      , 2)
    )

    it("supports adjusting oscillator parameters", (done) ->
      promise = executeCode("""SinOsc sin => dac;
0.6 => sin.gain;
440 => sin.freq;
1::second => now;
""")

      dac = helpers.getDac()
      sine = dac._channels[0].sources[0]
      helpers.verifySinOsc(sine, 440, 0.6)

      verify(promise, done, null, 1)
    )

    describe('looping', ->
      describe('while', ->
        it('supports infinite loops', (done) ->
          # An infinite loop that sleeps between iterations so that we can stop the VM while it's sleeping
          promise = executeCode("""while (true)
  {
    1::second => now;
  }
  """)
          expect(helpers.isChuckExecuting()).toBe(true)
          helpers.stopChuck()
          # Audio callback should discover upon first invocation that there's nothing to do
          helpers.processAudio(0)

          verify(promise, done)
          return
        )

        it('supports breaking out of loops', (done) ->
          # Break and sleep, so that we can verify that code after the loop is executed
          promise = executeCode("""while (true)
  {
    break;
  }
  1::second => now;
  """)

          expect(helpers.isChuckExecuting()).toBe(true)

          verify(promise, done, null, 1)
          return
        )

        it('supports a greater than int condition', (done) ->
          promise = executeCode("""\
2 => int a;
1 => int b;
while (b > 0)
{
  0 => b;
  <<<a>>>;
}
""")

          verify(promise, done, ->
            expect(console.log).toHaveBeenCalledWith("2 :(int)")
          )
          return
        )
      )
    )

    describe('Console interaction', ->
      it('can print to the console', (done) ->
        str = "Hello world!"
        promise = executeCode("<<<\"#{str}\">>>;")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("\"#{str}\" : (String)")
        )
      )
    )

    describe('Comments', ->
      it('can ignore single-line comments', (done) ->
        str = "Test"
        promise = executeCode("<<<\"#{str}\">>>;// Ignore me")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("\"#{str}\" : (String)")
        )
      )
    )
  )
)
