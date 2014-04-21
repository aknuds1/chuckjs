define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("A loop", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe("of the 'for' kind", ->
      it("can iterate until a condition is false", (done) ->
        promise = executeCode("""\
for (0 => int i; i < 2; ++i) {
  <<<i>>>;
}
""")

        verify(promise, done, ->
          expect(console.log.calls.count()).toBe(2)
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["1 :(int)"]])
        )
      )

      it("can have an empty body", (done) ->
        promise = executeCode("""\
for (0 => int i; i < 5; i++) {
}
""")

        verify(promise, done)
      )

      it("can access an array", (done) ->
        promise = executeCode("""\
int array[2];
for (0 => int i; i < 2; ++i) {
  <<<array[i]>>>;
}
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["0 :(int)"]])
        )
      )

      it("creates a scope for the start of the loop", (done) ->
        promise = executeCode("""\
for (0 => int i; i < 1; ++i) {
    <<<i>>>;
}
for (0 => int i; i < 1; ++i) {
    <<<i>>>;
}
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["0 :(int)"]])
        )
      )
    )

    describe("of the 'while' kind", ->
      it("creates a scope for the body of the loop", (done) ->
        promise = executeCode("""\
0 => int i;
while (i++ < 2) {
    0 => int y;
    <<<y>>>;
    1 => y;
}
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["0 :(int)"]])
        )
      )
    )
  )
)
