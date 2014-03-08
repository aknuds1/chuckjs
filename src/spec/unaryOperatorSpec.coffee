define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe('UnaryOperator', ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    describe('PreIncnUmber', ->
      it('pre-increments a number', ->
        executeCode("""\
0 => int i;
<<<++i>>>;
<<<i>>>;
""")

        verify(->
          expect(console.log.calls.length).toBe(2)
          expect(console.log.calls[0].args[0]).toBe("1 : (int)")
          expect(console.log.calls[1].args[0]).toBe("1 : (int)")
        )
      )
    )

    describe('PostIncnUmber', ->
      it('post-increments a number', ->
        executeCode("""\
0 => int i;
<<<i++>>>;
<<<i>>>;
""")

        verify(->
          expect(console.log.calls.length).toBe(2)
          expect(console.log.calls[0].args[0]).toBe("0 : (int)")
          expect(console.log.calls[1].args[0]).toBe("1 : (int)")
        )
      )
    )
  )
)