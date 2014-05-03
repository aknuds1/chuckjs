define("chuck/audioContextService", ["chuck/logging"], (logging) ->
  class AudioContextService
    createOscillator: =>
      return @_audioContext.createOscillator()

    createGainNode: =>
      return @_audioContext.createGainNode()

    getSampleRate: => @_audioContext.sampleRate

    getCurrentTime: => @_audioContext.currentTime * @_audioContext.sampleRate

    prepareForExecution: (ac, dn) =>
      if ac?
        @_audioContext = ac
        if dn?
          @_audioDestination = dn
        else
          @_audioDestination = @_audioContext.destination

      if @_audioContext?
        logging.debug("Re-using AudioContext")
        return

      logging.debug("Initializing audio context")
      AudioContext = window.AudioContext  || window.webkitAudioContext
      # Note that we re-create the audio context for each execution, e.g. in order to have a clean slate for each
      # test
      @_audioContext = new AudioContext()
      if not @_audioDestination?
        @_audioDestination = @_audioContext.destination
      return

    createScriptProcessor: =>
      @_scriptProcessor = @_audioContext.createScriptProcessor(16384, 0, 2)
      @_scriptProcessor.connect(@_audioDestination)
      return @_scriptProcessor

    stopOperation: =>
      if @_scriptProcessor?
        @_scriptProcessor.disconnect(0)

      deferred = Q.defer()
      deferred.resolve()
      return deferred.promise

  service = new AudioContextService()
  return service
)
