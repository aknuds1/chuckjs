define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Binary operators:", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe("Chuck", ->
      it("can call a static method", (done) ->
        promise = executeCode("""\
<<<90 => Std.mtof>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1479.977691 :(float)")
        )
      )

      it("can assign ints to floats", (done) ->
        promise = executeCode("""\
880 => float f;
<<<f>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("880.000000 :(float)")
        )
      )

      it("can assign strings", (done) ->
        promise = executeCode("""\
"test" => String str;
<<<str>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("\"test\" : (String)")
        )
      )
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

    describe("AtChuck", ->
      it("can assign an array literal to an array declaration", (done) ->
        promise = executeCode("""\
[0] @=> int hi[];
<<<hi>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("[0] :(int[])")
        )
      )
    )
  )
)
