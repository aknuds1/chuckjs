define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("Arrays", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    it("can be instantiated with a size", ->
      executeCode("""int array[1];
<<<array[0]>>>;
""")

      verify(->
        expect(console.log).toHaveBeenCalledWith("0 : (int)")
      )
    )
  )
)