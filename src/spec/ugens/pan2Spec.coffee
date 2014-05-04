define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe("A Pan2 UGen", ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("offers signal stereo panning", (done) ->
      promise = executeCode("""\
Step s => Pan2 p => dac;
1 => s.next;
1::samp => now;
// Pan hard left
-1 => p.pan;
1::samp => now;
// Pan hard right
1 => p.pan;
1::samp => now;
""")

      dac = helpers.getDac()
      expect(dac._channels[0].sources.length).toBe(1, "Pan2 should be connected to DAC")
      pan = dac._channels[0].sources[0].parent
      expect(dac._channels[1].sources).toEqual([pan._channels[1]], "Pan2 should be connected to DAC")
      expect(pan.type.name).toBe("Pan2")

      # Verify samples
      helpers.processAudio(helpers.getSampleInSeconds()*3)
      expect(helpers.receivedAudio[0]).toEqual([1, 1, 0], "Signal should be panned centre, then left and finally right")
      expect(helpers.receivedAudio[1]).toEqual([1, 0, 1], "Signal should be panned centre, then left and finally right")

      verify(promise, done, null, 1)
    )
  )
)
