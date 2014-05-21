define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  describe('An oscillator', ->
    beforeEach(->
      helpers.beforeEach(registerAudio: true)
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('of the Step kind', ->
      it("produces signal defined by its 'next' property", (done) ->
        promise = executeCode("""\
Step s => dac;
0.5 => s.next;
4::samp => now;
""")

        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(1, "Step should be connected to DAC")
        step = dac._channels[0].sources[0]
        expect(dac._channels[1].sources).toEqual([step], "Step should be connected to DAC")
        expect(step.type.name).toBe("Step")
        helpers.processAudio(helpers.getSampleInSeconds()*4)
        for buffer in helpers.receivedAudio
          for i in [0...buffer.length]
            expect(buffer[i]).toEqual(0.5, "Step should produce a constant signal of 0.5")

        verify(promise, done, null, 1)
      )
    )

    describe("of the Impulse kind", ->
      it("produces signal defined by its 'next' property for one sample", (done) ->
        promise = executeCode("""Impulse i => dac;
1::samp => now;
0.5 => i.next;
2::samp => now;
""")

        helpers.processAudio(helpers.getSampleInSeconds()*3)
        for channel in helpers.receivedAudio
          expect(channel).toEqual([0, 0.5, 0], "Impulse should generate correct signal")

        verify(promise, done, null, 1)
      )
    )

    describe("of the SinOsc kind", ->
      it("has a sync property that defaults to 0", (done) ->
        promise = executeCode("""SinOsc sin;
<<<sin.sync()>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0 :(int)")
        )
      )

      it("has a sync property that can be set", (done) ->
        promise = executeCode("""SinOsc sin;
<<<1 => sin.sync>>>;
<<<sin.sync()>>>;
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["1 :(int)"], ["1 :(int)"]])
        )
      )

      it("doesn't accept a sync value lower than 0", (done) ->
        promise = executeCode("""SinOsc sin;
<<<-1 => sin.sync>>>;
<<<sin.sync()>>>;
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["0 :(int)"]])
        )
      )

      it("doesn't accept a sync value higher than 2", (done) ->
        promise = executeCode("""SinOsc sin;
<<<3 => sin.sync>>>;
<<<sin.sync()>>>;
""")

        verify(promise, done, ->
          expect(console.log.calls.allArgs()).toEqual([["0 :(int)"], ["0 :(int)"]])
        )
      )

      it("can be frequency modulated by an input", (done) ->
        promise = executeCode("""Step m => SinOsc c => dac;
440 => c.freq;
2 => c.sync;
1 => m.next;
2::samp => now;
<<<c.last()>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0.057695 :(float)")
        , 1)
      )

      it("can sync its frequency to its input", (done) ->
        promise = executeCode("""Step m => SinOsc c => dac;
440 => c.freq;
1 => m.next;
2::samp => now;
<<<c.last()>>>;
<<<c.freq()>>>;
""")

        verify(promise, done, ->
          expect(console.log).toHaveBeenCalledWith("0.000131 :(float)")
          expect(console.log).toHaveBeenCalledWith("1.000000 :(float)")
        , 1)
      )
    )
  )
)
