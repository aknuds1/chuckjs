define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Mathematics', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('Subtraction', ->
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
    )

    describe('pow', ->
      it('can return the value of x to the power of y', (done) ->
        promise = executeCode("""\
<<<Math.pow(2, 3)>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("8 : (float)")
        )
      )
    )

    describe("multiplication", ->
      it("can multiply two floats", (done) ->
        promise = executeCode("""<<<2.1*2.0>>>;""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("4.2 : (float)")
        )
      )
    )
  )
)