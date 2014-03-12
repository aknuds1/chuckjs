define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Binary operator", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('Unchuck', ->
      it('can unlink two UGens', (done) ->
        promise = executeCode("""\
SinOsc sin => dac;
sin =< dac;
1::second => now;
""")

        # Verify the program's execution
        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(0, "Sine oscillator should be discconnected from DAC")

        verify(promise, done, ->
          expect(helpers.fakeScriptProcessor.disconnect).toHaveBeenCalled()
        , 1)
      )
    )
  )
)