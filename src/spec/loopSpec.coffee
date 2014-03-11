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

    describe("of 'for' kind", ->
      it("can iterate until a condition is false", ->
        executeCode("""\
for (0 => int i; i < 2; ++i) {
  <<<i>>>;
}
""")

        verify(->
          expect(console.log.calls.length).toBe(2)
          expect(console.log.calls[0].args[0]).toBe("0 : (int)")
          expect(console.log.calls[1].args[0]).toBe("1 : (int)")
        )
      )

      it("can have an empty body", ->
        executeCode("""\
for (0 => int i; i < 5; i++) {
}
""")

        verify()
      )
    )
  )
)