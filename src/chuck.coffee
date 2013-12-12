define("chuck", ["chuck/lexer"], ->
  module = {}

  module.Chuck = class
    constructor: ->
      AudioContext = window.AudioContext  || window.webkitAudioContext
      @_audioContext = new AudioContext()
      @_gainNode = @_audioContext.createGainNode()
      @_gainNode.connect(@_audioContext.destination)

    execute: (code) =>
      @_gainNode.gain.cancelScheduledValues(0)
      @_gainNode.gain.value = 1

    stop: (callback) =>
      now = @_audioContext.currentTime
      @_gainNode.gain.cancelScheduledValues(now)
      # Anchor beginning of ramp at current value.
      @_gainNode.gain.setValueAtTime(@_gainNode.gain.value, now)

      stopDuration = 0.15
      stopTime = now + stopDuration
      #logger.debug("Stopping at #{stopTime}")
      @_gainNode.gain.linearRampToValueAtTime(0, stopTime)

      setTimeout(=>
        callback()
      , stopDuration*1000)

  return module
)
