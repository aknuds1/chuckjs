define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Numbers:", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe("A BiQuad UGen", ->
      it("has a certain impulse response", (done) ->
        promise = executeCode("""Impulse i => BiQuad f => dac;
// set the filter's pole radius
.99 => f.prad;
// set equal gain zeros
1 => f.eqzs;
// Set filter's resonant frequency
800 => f.pfreq;

1 => i.next;
10::samp => now;
""")

        verify(promise, done, ->
          for channel in helpers.receivedAudio
            channel = (sample.toFixed(3) for sample in channel)
            exp = (sample.toFixed(3) for sample in [1, 1.969, 1.897, 1.806, 1.697, 1.572, 1.432, 1.279, 1.115, 0.942, 0])
            expect(channel).toEqual(exp, "Impulse response should be as expected")
          return
        , helpers.getSampleInSeconds()*10)
      )
    )
  )
)
