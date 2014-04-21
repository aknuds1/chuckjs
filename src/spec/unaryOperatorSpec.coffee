define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe('UnaryOperator', ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('PreIncnUmber', ->
      it('pre-increments a number', (done) ->
        promise = executeCode("""\
0 => int i;
<<<++i>>>;
<<<i>>>;
""")

        verify(promise, done, ->
          expect(console.log.calls.count()).toBe(2)
          expect(console.log.calls.allArgs()).toEqual([["1 :(int)"], ["1 :(int)"]])
        )
      )
    )

    describe('PostIncnUmber', ->
      it('post-increments a number', (done) ->
        promise = executeCode("""\
0 => int i;
<<<i++>>>;
<<<i>>>;
""")

        verify(promise, done, ->
          expect(console.log.calls.count()).toBe(2)
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["1 :(int)"]])
        )
      )
    )
  )
)
