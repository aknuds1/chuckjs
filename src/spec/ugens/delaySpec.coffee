define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('A Delay', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("delays the signal by a set amount", (done) ->
      promise = executeCode("""Impulse i => Delay d => dac;
1 => i.next;
2::samp => d.delay;
4::samp => now;
""")

      verify(promise, done, ->
        for channel in helpers.receivedAudio
          expect(channel).toEqual([0, 0, 1, 0, 0], "Signal should be delayed")
      , helpers.getSampleInSeconds()*4)
    )

    it("has adjustable gain", (done) ->
      promise = executeCode("""Impulse i => Delay d => dac;
1 => i.next;
.5 => d.gain;
1::samp => now;
""")

      verify(promise, done, ->
        for channel in helpers.receivedAudio
          expect(channel).toEqual([0.5, 0], "Delayed signal should be gain adjusted")
      , helpers.getSampleInSeconds())
    )

    it("can be routed for feedback", (done) ->
      promise = executeCode("""Impulse i => Gain g => dac;
g => Delay d => g;
.5 => d.gain;
1::samp => d.delay;
// Fire impulse
1 => i.next;
5::samp => now;
""")

      verify(promise, done, ->
        for channel in helpers.receivedAudio
          expect(channel).toEqual([1, 0, 0.5, 0, 0.25, 0], "There should be feedback")
      , helpers.getSampleInSeconds()*5)
    )
  )
)
