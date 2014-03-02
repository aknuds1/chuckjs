define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Loops", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    describe("For", ->
      it("can iterate until a condition is false", ->
        executeCode("""\
for (0 => int i; i < 2; ++i) {
  <<<i>>>;
}
""")

        verify(->
          expect(console.log).toHaveBeenCalledWith("0 : (int)")
          expect(console.log).toHaveBeenCalledWith("1 : (int)")
        )
      )
    )
  )
)