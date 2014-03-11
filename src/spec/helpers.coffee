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

  err = undefined
  chuck = undefined
  origAudioContext = window.AudioContext || window.webkitAudioContext

  module.beforeEach = ->
    chuckModule.setLogger(new Logger())
    jasmine.clock().install();
    # Disable too eager logging of supposedly unhandled promise rejections
    q.stopUnhandledRejectionTracking()

    module.fakeAudioContext = jasmine.createSpyObj("AudioContext", ["createScriptProcessor"])
    module.fakeAudioContext.currentTime = 0
    module.fakeAudioContext.sampleRate = 48000
    module.fakeAudioContext.destination = {name: "destination"}
    module.fakeScriptProcessor = jasmine.createSpyObj("scriptProcessor", ["connect", "disconnect"])
    debugger
    module.fakeAudioContext.createScriptProcessor.and.callFake(-> module.fakeScriptProcessor)

    # Fake AudioContext constructor
    window.AudioContext = ->
      _(this).extend(module.fakeAudioContext)
      # Keep the constructed AudioContext
      module.fakeAudioContext = this

    chuck = new chuckModule.Chuck()
    err = undefined

  module.afterEach = ->
    window.AudioContext = origAudioContext

    # Reset shared state
    err = undefined

    chuck.stop()
    .then(->
      err = false
    , (e) ->
      throw new Error("Failed to stop ChucK: #{err}")
    )
    .always(->
      chuck = undefined
    )

  # Execute code asynchronously; when execution has finished define the 'err' variable
  module.executeCode = (code) ->
    promise = chuck.execute(code)
    .then(->
      err = false
      return
    ,
    (e) ->
      err = e
      return
    )
    # The execution itself starts asynchronously - trigger it
    jasmine.clock().tick(1)
    promise

  module.verify = (verifyCb, done, waitTime = undefined) ->
    if waitTime?
      module.processAllAudio(waitTime)

#    waitsFor(->
#      err?
#    , "Execution should finish", 10)

    if err
      throw new Error("An exception was thrown asynchronously\n#{err.stack}")

    expect(chuck.isExecuting()).toBe(false, "isExecuting should be false")
    if verifyCb?
      verifyCb()

    done()

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
