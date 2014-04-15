define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('The debug print operator', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("can write a list of expressions", (done) ->
      promise = executeCode("""\
<<<"1 + 1 is", 1 + 1>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1 + 1 is 2")
        return
      )
    )
  )
)
