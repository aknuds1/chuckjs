define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('An int', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it('is initialized to zero', (done) ->
      promise = executeCode("""int i;
<<<i>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("0 :(int)")
      )
    )
  )
)
