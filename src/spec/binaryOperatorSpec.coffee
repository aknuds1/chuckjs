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

      it("can call a static method with a complex expression", (done) ->
        promise = executeCode("""\
<<<45*2 => Std.mtof>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1479.977691 :(float)")
        )
      )

      it("can call an instance method with a complex expression", (done) ->
        promise = executeCode("""Step s;
<<<0.5*2 => s.next>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1.000000 :(float)")
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

    describe("MinusChuck", ->
      it("can subtract from a variable and assign the result back", (done) ->
        promise = executeCode("""2 => int x;
1 -=> x;
<<<x>>>;
""")
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1 :(int)")
        )
      )
    )

    describe("PlusChuck", ->
      it("can add to a variable and assign the result back", (done) ->
        promise = executeCode("""0 => int x;
1 +=> x;
<<<x>>>;
""")
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1 :(int)")
        )
      )
    )

    describe('LessThan', ->
      it("can detect that a float is less than an int", (done) ->
        promise = executeCode("<<<0.9 < 1>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )
    )

    describe('GreaterThan', ->
      it("can detect that a float is greater than an int", (done) ->
        promise = executeCode("<<<1.1 > 1>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )
    )

    describe("LessThanOrEqual", ->
      it("can detect that a constant is less than another", (done) ->
        promise = executeCode("<<<0 <= 1>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )

      it("can detect that a constant is equal to another", (done) ->
        promise = executeCode("<<<0 <= 0>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )

      it("can detect that a constant is greater than another", (done) ->
        promise = executeCode("<<<1 <= 0>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("false :(int)")
        )
      )
    )

    describe("GreaterThanOrEqual", ->
      it("can detect that a constant is greater than another", (done) ->
        promise = executeCode("<<<1 >= 0>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )

      it("can detect that a constant is equal to another", (done) ->
        promise = executeCode("<<<0 >= 0>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("true :(int)")
        )
      )

      it("can detect that a constant is less than another", (done) ->
        promise = executeCode("<<<0 >= 1>>>;")

        verify(promise, done,->
          expect(console.log).toHaveBeenCalledWith("false :(int)")
        )
      )
    )
  )
)
