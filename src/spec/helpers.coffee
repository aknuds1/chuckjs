define("spec/helpers", ['chuck', "q"], (chuckModule, q) ->
  module = {}

  class Logger
    debug: ->
      console.debug.apply(undefined, arguments)
    warn: ->
      console.warn.apply(undefined, arguments)
    trace: ->
      console.trace.apply(undefined, arguments)
    error: ->
      console.error.apply(undefined, arguments)
    info: ->
      console.info.apply(undefined, arguments)

  chuck = undefined
  origAudioContext = window.AudioContext || window.webkitAudioContext

  module.beforeEach = ->
#    chuckModule.setLogger(new Logger())
    jasmine.clock().install();
    # Disable too eager logging of supposedly unhandled promise rejections
    q.stopUnhandledRejectionTracking()

    module.fakeAudioContext = jasmine.createSpyObj("AudioContext", ["createScriptProcessor"])
    module.fakeAudioContext.currentTime = 0
    module.fakeAudioContext.sampleRate = 48000
    module.fakeAudioContext.destination = {name: "destination"}
    module.fakeScriptProcessor = jasmine.createSpyObj("scriptProcessor", ["connect", "disconnect"])
    module.fakeAudioContext.createScriptProcessor.and.callFake(-> module.fakeScriptProcessor)

    # Fake AudioContext constructor
    window.AudioContext = ->
      _(this).extend(module.fakeAudioContext)
      # Keep the constructed AudioContext
      module.fakeAudioContext = this

    chuck = new chuckModule.Chuck()

  module.afterEach = (done) ->
    window.AudioContext = origAudioContext

    p = chuck.stop()
    .then(done
    , (e) ->
      done(new Error("Failed to stop ChucK: #{e}"))
    )
    .fin(->
      chuck = undefined
    )
    .done()

  # Execute code asynchronously
  module.executeCode = (code) ->
    promise = chuck.execute(code)
    # The execution itself starts asynchronously via setTimeout - trigger it
    jasmine.clock().tick(1)
    promise

  # Verify (asynchronous) ending of execution
  module.verify = (promise, done, verifyCb, waitTime = undefined) ->
    if waitTime?
      module.processAllAudio(waitTime)

    promise.done(->
      expect(chuck.isExecuting()).toBe(false, "isExecuting should be false")

      if verifyCb?
        verifyCb()

      done()
    )

  module.isChuckExecuting = -> chuck.isExecuting()
  module.stopChuck = -> chuck.stop()

  # Simulate processing of an audio buffer of a certain length
  module.processAudio = (seconds) ->
    event =
      outputBuffer:
        getChannelData: -> []
        length: seconds * module.fakeAudioContext.sampleRate
    chuck._vm._scriptProcessor.onaudioprocess(event)
    return

  # Process a number of audio samples (expressed in seconds), during which execution should finish, and make a
  # second audio callback call to allow for audio termination
  module.processAllAudio = (seconds) ->
    module.processAudio(seconds)
    module.processAudio(0)
    return

  module.getDac = -> chuck._vm._dac

  module.verifySinOsc = (sinOsc, frequency=220, gain=1) ->
    expect(sinOsc).toBeDefined()
    if !sinOsc?
      return
    expect(sinOsc.type.name).toBe("SinOsc")
    expect(sinOsc.data.num).toBe((1/module.fakeAudioContext.sampleRate)*frequency,
      "Frequency should be correctly set")
    expect(sinOsc._gain).toBe(gain, "Gain should be correctly set")

  return module
)
