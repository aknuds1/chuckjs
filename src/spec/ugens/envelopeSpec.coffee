define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('An Envelope UGen', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("has a default duration of a 1000 samples", (done) ->
      promise = executeCode("""Envelope e;
<<<e.duration()>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1000.000000 :(dur)")
      )
    )

    it("has an adjustable duration", (done) ->
      promise = executeCode("""Envelope e;
e.duration(10::samp);
<<<e.duration()>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("10.000000 :(dur)")
      )
    )

    it('can apply an envelope to a signal', (done) ->
      promise = executeCode("""Step step => Envelope e => dac;
2::samp => e.duration;
// Attack
e.keyOn();
3::samp => now;
// Release
e.keyOff();
2::samp => now;
""")

      verify(promise, done, ->
        for channel in helpers.receivedAudio
          expect(channel).toEqual([0.5, 1, 1, 0.5, 0, 0, 0, 0], "The signal should be amplified correctly")
        return
      , helpers.getSampleInSeconds()*6)
    )
  )
)
