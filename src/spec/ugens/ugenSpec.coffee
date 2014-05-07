define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  {executeCode, verify} = helpers

  # Properties common to UGens
  describe("A UGen", ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    it("can be queried for its last output sample", (done) ->
      promise = executeCode("""Impulse i => dac;
1 => i.next;
<<<i.last()>>>;
1::samp => now;
<<<i.last()>>>;
""")

      verify(promise, done, ->
        expect(console.log.calls.allArgs()).toEqual([["0.000000 :(float)"], ["1.000000 :(float)"]])
      , helpers.getSampleInSeconds()*2)
    )
  )

  describe('The UGen', ->
    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done) ->
      helpers.afterEach(done)
    )

    describe('Gain', ->
      it('supports adjusting gain', (done) ->
        promise = executeCode("""\
Gain g => dac;
0.5 => g.gain;
1::second => now;
""")

        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(1, "Gain should be connected to DAC")
        gain = dac._channels[0].sources[0]
        expect(dac._channels[1].sources).toEqual([gain], "Gain should be connected to DAC")

        expect(gain.type.name).toBe("Gain")
        expect(gain._gain).toBe(0.5, "Gain should be correctly set")

        verify(promise, done, null, 1)
      )
    )
  )
)
