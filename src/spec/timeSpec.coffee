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
      executeCode("""1::second + now => time later;
<<<later>>>;
""")

      verify(->
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate} : (time)")
        return
      )
    )

    it('can loop until a certain time', ->
      executeCode("""1::second + now => time later;
while (now < later)
{
  <<<now>>>;
  1::second => now;
}
<<<now>>>;
""")
      # Verify the first iteration, which'll sleep one second
      runs(->
        expect(console.log.calls.length).toEqual(1)
        expect(console.log).toHaveBeenCalledWith("0 : (time)")
        # Simulate that 1 second has passed
        helpers.fakeAudioContext.currentTime = 1
        jasmine.Clock.tick(1001)
      )
      # Verify the post-loop statement, after letting 1 second pass
      verify(->
        expect(console.log.calls.length).toEqual(2)
        expect(console.log).toHaveBeenCalledWith("#{helpers.fakeAudioContext.sampleRate} : (time)")
      )
    )
  )
)
