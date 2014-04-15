define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('STK:', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('JCRev', ->
      it("can be linked to other UGens", (done) ->
        promise = executeCode("JCRev rev => dac;")

        verify(promise, done)
      )

      it("has an adjustable mix parameter", (done) ->
        promise = executeCode("""\
JCRev rev;
<<<0.25 => rev.mix>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0.250000 :(float)")
        )
      )
    )
  )
)
