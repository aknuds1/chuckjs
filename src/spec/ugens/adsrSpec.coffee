define(["chuck", "spec/helpers", "chuck/logging"], (chuckModule, helpers, logging) ->
  {executeCode, verify} = helpers

  describe('An ADSR UGen', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it('can apply an envelope to a signal', (done) ->
      promise = executeCode("""\
Step step => ADSR e => dac;
e.set(2::samp, 1::samp, 0.5, 1::samp);
e.keyOn();
// Progress to decay stage
1::samp => now;
// Progress to sustain stage, then allow for a sample of sustain before releasing the key
3::samp => now;
// Let release do its thing, and let there be some time to verify that signal is muted
e.keyOff();
1::samp => now;
""")

      dac = helpers.getDac()
      expect(dac._channels[0].sources.length).toBe(1, "ADSR should be connected to DAC")
      adsr = dac._channels[0].sources[0]
      expect(adsr.type.name).toBe("ADSR")
      expect(dac._channels[1].sources).toEqual([adsr], "ADSR should be connected to DAC")
      expect(adsr._channels[0].sources.length).toBe(1, "SinOsc should be connected to ADSR")

      # Verify attack start
      helpers.processAudio(helpers.getSampleInSeconds())
      for channel in helpers.receivedAudio
        expect(channel[0]).toEqual(0.5, "ADSR should amplify signal correctly")

      # Verify decay start
      helpers.processAudio(helpers.getSampleInSeconds())
      for channel in helpers.receivedAudio
        expect(channel[1]).toEqual(1, "ADSR should amplify signal correctly")

      # Verify sustain start
      helpers.processAudio(helpers.getSampleInSeconds())
      for channel in helpers.receivedAudio
        expect(channel[2]).toEqual(0.5, "ADSR should amplify signal correctly")

      # Verify sustain end
      helpers.processAudio(helpers.getSampleInSeconds())
      for channel in helpers.receivedAudio
        expect(channel[3]).toEqual(0.5, "ADSR should amplify signal correctly")

      # Verify release
      helpers.processAudio(helpers.getSampleInSeconds())
      for channel in helpers.receivedAudio
        expect(channel[4]).toEqual(0, "ADSR should amplify signal correctly")

      verify(promise, done, null, helpers.getSampleInSeconds())
    )
  )
)
