define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('me', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("can be queried for the program's number of arguments when none are provided", (done) ->
      promise = executeCode("<<<me.args()>>>;")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("0 :(int)")
      )
    )

    it("can be queried for the program's number of arguments when some are provided", (done) ->
      promise = executeCode("<<<me.args()>>>;", ["foo", "bar"])

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("2 :(int)")
      )
    )

    it("can be queried for one of a program's arguments", (done) ->
      promise = executeCode("<<<me.arg(1)>>>;", ["foo", "bar"])

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("\"bar\" : (String)")
      )
    )
  )
)
