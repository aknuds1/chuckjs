define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('The blackhole UGen', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("swallows audio output", (done) ->
      promise = executeCode("""Impulse i => blackhole;
// Fire impulse while it's connected to blackhole
1 => i.next;
1::samp => now;
// Connect to DAC, but now the impulse should be spent and produce no output
i => dac;
1::samp => now;
""")

      verify(promise, done, ->
        for channel in helpers.receivedAudio
          expect(channel).toEqual([0, 0, 0], "Impulse should be swallowed by blackhole")
        return
      , helpers.getSampleInSeconds()*2)
    )
  )
)
