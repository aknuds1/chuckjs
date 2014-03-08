define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Binary operator", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach
    )

    describe('Unchuck', ->
      it('can unlink two UGens', ->
        executeCode("""\
SinOsc sin => dac;
sin =< dac;
1::second => now;
""")

        runs(->
          # Verify the program's execution
          dac = helpers.getDac()
          expect(dac._channels[0].sources.length).toBe(0, "Sine oscillator should be discconnected from DAC")
        )

        verify(->
          expect(helpers.fakeScriptProcessor.disconnect).toHaveBeenCalled()
        , 1)
      )
    )
  )
)