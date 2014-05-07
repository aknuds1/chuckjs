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

    describe("A Noise UGen", ->
      fakeRands = [0, 0.5, 1]

      beforeEach(->
        spyOn(Math, "random").and.callFake(->
          return fakeRands[Math.random.calls.count()-1]
        )
      )

      it("generates random values between -1 and +1", (done) ->
        promise = executeCode("""Noise n => dac;
3::samp => now;
""")

        verify(promise, done, ->
          for channel in helpers.receivedAudio
            expect(channel).toEqual([-1, 0, 1, 0], "Random signal should be generated between -1 and 1")
          return
        , helpers.getSampleInSeconds()*3)
      )
    )
  )
)
