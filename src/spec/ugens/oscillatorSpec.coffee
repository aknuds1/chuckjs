define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('An oscillator', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('of the Step kind', ->
      it("produces signal defined by its 'next' property", (done) ->
        # TODO: Use shorter times
        promise = executeCode("""\
Step s => dac;
0.5 => s.next;
1::ms => now;
""")

        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(1, "Step should be connected to DAC")
        step = dac._channels[0].sources[0]
        expect(dac._channels[1].sources).toEqual([step], "Step should be connected to DAC")
        expect(step.type.name).toBe("Step")
        helpers.processAudio(0.001)
        for buffer in helpers.receivedAudio
          for i in [0...buffer.length]
            expect(buffer[i]).toEqual(0.5, "Step should produce a constant signal of 0.5")

        verify(promise, done, null, 1)
      )
    )
  )
)
