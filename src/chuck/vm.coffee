define("chuck/vm", [], ->
  module = {}

  class Vm
    execute: (byteCode) =>


  module.execute = (byteCode) ->
    vm = new Vm()
    vm.execute(byteCode)
  return module
)
