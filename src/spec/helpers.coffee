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

  module.beforeEach = ->
    chuckModule.setLogger(new Logger())
    jasmine.Clock.useMock();
    # Disable too eager logging of supposedly unhandled promise rejections
    q.stopUnhandledRejectionTracking()

    chuck = new chuckModule.Chuck()
    err = undefined

  module.afterEach = ->
    # Reset shared state
    err = undefined

    runs(->
      chuck.stop()
      .done(->
          err = false
        ,
        (e) ->
          err = e
        )
    )
    waitsFor(->
      err?
    , 10)
    runs(->
      if err
        throw new Error("Failed to stop ChucK: #{err}")

      chuck = undefined
    )

  # Execute code asynchronously; when execution has finished define the 'err' variable
  module.executeCode = (code) ->
    runs(->
      chuck.execute(code)
      .done(->
          err = false
          return
        ,
        (e) ->
          err = e
          return
        )
      # The execution itself starts asynchronously - trigger it
      jasmine.Clock.tick(1)
      return
    )
    return

  module.verify = (verifyCb, waitTime = undefined) ->
    if waitTime?
      runs(->
        jasmine.Clock.tick(waitTime)
      )

    waitsFor(->
      err?
    , "Execution should finish", 10)

    runs(->
      if err
        throw new Error("An exception was thrown asynchronously\n#{err.stack}")

      expect(chuck.isExecuting()).toBe(false)
      if verifyCb?
        verifyCb()
    )

  module.isChuckExecuting = -> chuck.isExecuting()
  module.stopChuck = -> chuck.stop()

  return module
)
