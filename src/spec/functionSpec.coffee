define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("A function", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done)->
      helpers.afterEach(done)
    )

    it("can be called without arguments", (done) ->
      promise = executeCode("""func();

fun void func() {
    <<<"fun!">>>;
}
""")
      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("\"fun!\" : (String)")
      )
    )

    it("can be an empty definition", (done) ->
      promise = executeCode("""fun void func() {}
""")
      verify(promise, done)
    )
  )
)
