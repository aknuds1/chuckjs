define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("An if statement", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("will not execute its body if the condition is false", (done) ->
      promise = executeCode("""if (false) {
    <<<"This should not execute">>>;
}
""")

      verify(promise, done, ->
        expect(console.log).not.toHaveBeenCalled()
      )
    )

    it("will execute its body if the condition is true", (done) ->
      promise = executeCode("""if (true) {
    <<<"This should execute">>>;
}
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalled()
      )
    )
  )
)
