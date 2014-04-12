define(["chuck", "spec/helpers", "chuck/logging"], (chuckModule, helpers, logging) ->
  {executeCode, verify} = helpers

  describe('An ADSR UGen', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    iit('can apply an envelope to a signal', (done) ->
      promise = executeCode("""\
SinOsc sin => ADSR e => dac;
e.set(1::second, 1::second, 0.5, 1::second);
e.noteOn();
// Progress to sustain stage
2::second => now;
// Let release do its thing, and let there be some time to verify that signal is muted
e.noteOff();
2::second => now;
""")

      dac = helpers.getDac()
      expect(dac._channels[0].sources.length).toBe(1, "ADSR should be connected to DAC")
      adsr = dac._channels[0].sources[0]
      expect(adsr.type.name).toBe("ADSR")
      expect(dac._channels[1].sources).toEqual([adsr], "ADSR should be connected to DAC")
      expect(adsr._channels[0].sources.length).toBe(1, "SinOsc should be connected to ADSR")

      # Verify attack stage
      helpers.processAudio(1)

      # Verify sustain stage
      helpers.processAudio(1)

      # Verify release stage
      helpers.processAudio(1)

      verify(promise, done, null, 1)
    )
  )
)
