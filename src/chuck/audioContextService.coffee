define("chuck/audioContextService", ["q", "chuck/logging"], (q, logging) ->
  class AudioContextService
    createOscillator: =>
      return @_audioContext.createOscillator()

    createGainNode: =>
      return @_audioContext.createGainNode()

    getSampleRate: => @_audioContext.sampleRate

    getCurrentTime: => @_audioContext.currentTime * @_audioContext.sampleRate

    prepareForExecution: =>
      logging.debug("Initializing audio context")
      AudioContext = window.AudioContext  || window.webkitAudioContext
      # Note that we re-create the audio context for each execution, e.g. in order to have a clean slate for each
      # test
      @_audioContext = new AudioContext()

    createScriptProcessor: =>
      @_scriptProcessor = @_audioContext.createScriptProcessor(16384, 0, 2)
      @_scriptProcessor.connect(@_audioContext.destination)
      return @_scriptProcessor

    stopOperation: =>
      if @_scriptProcessor?
        @_scriptProcessor.disconnect(0)

      deferred = q.defer()
      deferred.resolve()
      return deferred.promise

  service = new AudioContextService()
  return service
)
