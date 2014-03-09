define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Mathematics', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    describe('Subtraction', ->
      it('can subtract two constant ints', ->
        executeCode("""\
4 - 2 => int i;
<<<i>>>;
""")

        verify(->
          expect(console.log).toHaveBeenCalledWith("2 : (int)")
          return
        )
      )

      it('can subtract two constant floats', ->
        executeCode("""\
4.5 - 2.0 => float i;
<<<i>>>;
""")

        verify(->
          expect(console.log).toHaveBeenCalledWith("2.5 : (float)")
          return
        )
      )
    )

    describe('pow', ->
      it('can return the value of x to the power of y', ->
        executeCode("""\
<<<Math.pow(2, 3)>>>;
""")

        verify(->
          expect(console.log).toHaveBeenCalledWith("8 : (float)")
        )
      )
    )
  )
)