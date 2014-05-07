define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Math utilities:', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('Std.mtof', ->
      it("can convert a MIDI note number to frequency", (done) ->
        promise = executeCode("<<<Std.mtof(90)>>>;")
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("1479.977691 :(float)")
        )
      )
    )

    describe('Std.fabs', ->
      it("gives an absolute floating point value", (done) ->
        promise = executeCode("<<<Std.fabs(-2.1)>>>;")
        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("2.100000 :(float)")
        )
      )
    )
  )
)
