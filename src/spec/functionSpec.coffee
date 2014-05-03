define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("A function", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done)->
      helpers.afterEach(done)
    )

    it("can be called without arguments", (done) ->
      promise = executeCode("""func();

fun void func() {
    "fun!" => String x;
    <<<x>>>;
}
""")
      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("\"fun!\" : (String)")
      )
    )

    it("can be an empty definition", (done) ->
      promise = executeCode("""fun void func() {}
""")
      verify(promise, done)
    )

    it("can receive arguments", (done) ->
      promise = executeCode("""fun void func(float x, int y, String z)
{
    <<<x>>>;
    <<<y>>>;
    <<<z>>>;
}

func(1.0, 1, "test");
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1.000000 :(float)")
        expect(console.log).toHaveBeenCalledWith("1 :(int)")
        expect(console.log).toHaveBeenCalledWith("\"test\" : (String)")
      )
    )

    it("can refer to global variables", (done) ->
      promise = executeCode("""1 => int x;
fun void func()
{
  <<<x>>>;
}

func();
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1 :(int)")
      )
    )

    it("can be overloaded", (done) ->
      promise = executeCode("""fun void func()
{
  func(1);
}

fun void func(int x)
{
  <<<x>>>;
}

func();
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1 :(int)")
      )
    )

    it("can advance time", (done) ->
      promise = executeCode("""func();

fun void func()
{
    1::samp => now;
    <<<now>>>;
}
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1 : (time)")
      , 1)
    )
  )
)
