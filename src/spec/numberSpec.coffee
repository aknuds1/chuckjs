define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Numbers", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    describe("Floats", ->
      it("can parse floats that start with a dot", ->
        executeCode("<<<.1>>>;")

        verify(->
          expect(console.log).toHaveBeenCalledWith("0.1 : (float)")
        )
      )

      it("can parse floats that start with one or more digits", ->
        executeCode("<<<10.1>>>;")

        verify(->
          expect(console.log).toHaveBeenCalledWith("10.1 : (float)")
        )
      )

      it("can parse floats that end with a dot", ->
        executeCode("<<<10.>>>;")

        verify(->
          expect(console.log).toHaveBeenCalledWith("10 : (float)")
        )
      )
    )
  )
)