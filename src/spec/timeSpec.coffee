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

    it('can loop until a certain time', (done) ->
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
      # Simulate that 1 second has passed
      helpers.processAudio(1)
      # Let the VM terminate
      helpers.processAudio(1)

      # Verify the post-loop statement, after letting 1 second pass
      verify(promise, done, ->
        expect(console.log.calls.count()).toEqual(2)
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate} : (time)")
      )
    )
  )
)
