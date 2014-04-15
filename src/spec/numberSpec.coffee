define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Numbers:", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe("Floats", ->
      it("can parse floats that start with a dot", (done) ->
        promise = executeCode("<<<.1>>>;")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0.100000 :(float)")
        )
      )

      it("can parse floats that start with one or more digits", (done) ->
        promise = executeCode("<<<10.1>>>;")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("10.100000 :(float)")
        )
      )

      it("can parse floats that end with a dot", (done) ->
        promise = executeCode("<<<10.>>>;")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("10.000000 :(float)")
        )
      )
    )
  )
)
