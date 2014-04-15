define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Mathematics:', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('subtraction', ->
      it('can subtract two constant ints', (done) ->
        promise = executeCode("""\
4 - 2 => int i;
<<<i>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("2 : (int)")
          return
        )
      )

      it('can subtract two constant floats', (done) ->
        promise = executeCode("""\
4.5 - 2.0 => float i;
<<<i>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("2.5 : (float)")
          return
        )
      )

      it('can subtract and assign by chucking', (done) ->
        promise = executeCode("""\
2 => int x;
2 -=> x;
<<< x >>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0 : (int)")
        )
      )
    )

    describe("multiplication", ->
      it("can multiply two floats", (done) ->
        promise = executeCode("""2.1*2.0;""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("4.2 : (float)")
        )
      )
    )

    describe("division", ->
      it("can divide a dur expression in parentheses by another dur", (done) ->
        promise = executeCode("""<<<(4-2)>>>;""")
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("2 : (time)")
        )
      )
    )

    describe('Math.pow', ->
      it('can return the value of x to the power of y', (done) ->
        promise = executeCode("""\
<<<Math.pow(2, 3)>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("8 : (float)")
        )
      )
    )

    describe("Math.random2", ->
      returnedRand = 0.6
      beforeEach(->
        spyOn(Math, "random").and.returnValue(returnedRand)
      )

      it("returns a random int between a lower and upper bound", (done) ->
        min = 1
        max = 20
        promise = executeCode("<<<Math.random2(#{min}, #{max})>>>;")

        expRand = Math.floor(returnedRand * (max-min+1)) + min
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("#{expRand} : (int)")
        )
      )
    )
  )
)
