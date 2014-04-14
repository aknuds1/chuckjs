define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('Time and duration', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it('can add two time values and chuck the result to a variable declaration', (done) ->
      promise = executeCode("""1::second + now => time later;
<<<later>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate} : (time)")
        return
      )
    )

    it('can loop until a certain time in seconds', (done) ->
      promise = executeCode("""1::second + now => time later;
while (now < later)
{
  <<<now>>>;
  1::second => now;
}
<<<now>>>;
""")
      # Verify the first iteration, which'll sleep one second
      expect(console.log.calls.count()).toBe(1)
      expect(console.log).toHaveBeenCalledWith("0 : (time)")

      # Verify the post-loop statement, after letting 1 second pass
      verify(promise, done, ->
        expect(console.log.calls.count()).toEqual(2)
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate} : (time)")
      , 1)
    )

    it('can loop until a certain time in milliseconds', (done) ->
      promise = executeCode("""1::ms + now => time later;
while (now < later)
{
  <<<now>>>;
  1::ms => now;
}
<<<now>>>;
""")
      # Verify the first iteration, which'll sleep one millisecond
      expect(console.log.calls.count()).toBe(1)
      expect(console.log).toHaveBeenCalledWith("0 : (time)")

      # Verify the post-loop statement, after letting 1 millisecond pass
      verify(promise, done, ->
        expect(console.log.calls.count()).toEqual(2)
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate/1000} : (time)")
        return
      , 0.001)
    )

    it('can loop until a certain time in samples', (done) ->
      promise = executeCode("""1::samp + now => time later;
while (now < later)
{
  <<<now>>>;
  1::samp => now;
}
<<<now>>>;
""")
      # Verify the first iteration, which'll sleep one sample
      expect(console.log.calls.count()).toBe(1)
      expect(console.log).toHaveBeenCalledWith("0 : (time)")

      # Verify the post-loop statement, after letting 1 sample pass
      verify(promise, done, ->
        expect(console.log.calls.count()).toEqual(2)
        expect(console.log).toHaveBeenCalledWith("1 : (time)")
        return
      , 1/helpers.fakeAudioContext.sampleRate)
    )

    it("can add a sample duration to a time and assign the result to a time variable", (done) ->
      promise = executeCode("""\
1::samp => dur d;
now + d => time t;
<<<t>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("1 : (time)")
      )
    )

    it("can add an hour duration to a time and assign the result to a time variable", (done) ->
      promise = executeCode("""\
1::hour => dur d;
now + d => time t;
<<<t>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("#{helpers.getSampleRate()*60*60} : (time)")
      )
    )
  )
)
