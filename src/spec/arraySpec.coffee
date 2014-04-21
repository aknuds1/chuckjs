define(["chuck", "spec/helpers"], (chuckModule, helpers) ->
  describe("An array", ->
    {executeCode, verify} = helpers

    beforeEach(->
      helpers.beforeEach()
      spyOn(console, 'log')
    )
    afterEach((done)->
      helpers.afterEach(done)
    )

    it("can be instantiated with a size", (done) ->
      promise = executeCode("""int array[1];
<<<array[0]>>>;
""")
      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("0 :(int)")
      )
    )

    it("can be indexed with integer variables", (done) ->
      promise = executeCode("""int array[3];
1 => int i;
<<<array[i]>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("0 :(int)")
      )
    )

    it("has elements which can be assigned to", (done) ->
      promise = executeCode("""\
int array[2];
1 => array[0];
2 => array[1];
<<<array[0]>>>;
<<<array[1]>>>;
""")

      verify(promise, done, ->
        expect(console.log.calls.allArgs()).toEqual([["1 :(int)"], ["2 :(int)"]])
      )
    )

    it("can be queried for its capacity", (done) ->
      promise = executeCode("""\
int arr[2];
<<<arr.cap()>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("2 :(int)")
      )
    )

    it("can be queried for its size", (done) ->
      promise = executeCode("""\
int arr[2];
<<<arr.size()>>>;
""")

      verify(promise, done, ->
        expect(console.log).toHaveBeenCalledWith("2 :(int)")
      )
    )

    describe("of UGens", ->
      it("has elements which can be connected to destinations", (done) ->
        promise = executeCode("""\
SinOsc oscs[2];
oscs[0] => dac;
oscs[1] => dac;
1::second => now;
""")

        # Verify the program's execution while it's suspended
        dac = helpers.getDac()
        expect(dac._channels[0].sources.length).toBe(2, "Sine oscillators should be connected to DAC")
        sine1 = dac._channels[0].sources[0]
        sine2 = dac._channels[0].sources[1]
        expect(dac._channels[1].sources.length).toBe(2, "Sine oscillators should be connected to DAC")
        helpers.verifySinOsc(sine1)
        helpers.verifySinOsc(sine2)

        verify(promise, done, ->
          dac = helpers.getDac()
          for i in [0...dac._channels.length]
            channel = dac._channels[i]
            expect(channel.sources.length).toBe(0, "DAC channel #{i} sources should be empty")
          expect(helpers.fakeScriptProcessor.disconnect).toHaveBeenCalled()
        , 1)
      )
    )
  )
)
