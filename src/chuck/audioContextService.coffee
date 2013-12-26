define("chuck/audioContextService", ["q", "chuck/logging"], (q, logging) ->
  class AudioContextService
    createOscillator: =>
      return @_audioContext.createOscillator()

    getCurrentTime: =>
      return @_audioContext.currentTime
      
    prepareForExecution: =>
      logging.debug("Initializing audio context")
      AudioContext = window.AudioContext  || window.webkitAudioContext
      # Note that we re-create the audio context for each execution, e.g. in order to have a clean slate for each
      # test
      if @_audioContext?
        @outputNode.disconnect(0)
      @_audioContext = new AudioContext()
      @outputNode = @_audioContext.createGainNode()
      @outputNode.connect(@_audioContext.destination)

      @outputNode.gain.cancelScheduledValues(0)
      @outputNode.gain.value = 1
      
    stopOperation: =>
      now = @_audioContext.currentTime
      @outputNode.gain.cancelScheduledValues(now)
      @outputNode.gain.value = 0

      deferred = q.defer()
      deferred.resolve()
      return deferred.promise

  service = new AudioContextService()
  return service
)
