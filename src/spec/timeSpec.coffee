define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Time and duration', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach(->
      helpers.afterEach()
    )

    it('can add two time values and chuck the result to a variable declaration', ->
      executeCode("""1::second + now => time later;""")
    )

#    it('can loop until a certain time', ->
#    )
  )
)
