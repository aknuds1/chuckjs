define("chuck/dacService", ["chuck/ugen"], (ugen) ->
  module =
    dac: new ugen.Dac()
    bunghole: new ugen.Bunghole()

  module
)
