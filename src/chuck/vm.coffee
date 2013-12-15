define("chuck/vm", [], ->
  module = {}

  class Vm
    constructor: ->
      @regStack = []
      @_ugens = []

    execute: (byteCode) =>
      pc = 0
      debugger
      while pc < byteCode.length
        instr = byteCode[pc++]
        instr.execute(@)

    addUgen: (ugen) =>
      @_ugens.push(ugen)

    # Push value to regular stack
    pushToReg: (value) =>
      @regStack.push(value)

  module.execute = (byteCode) ->
    vm = new Vm()
    vm.execute(byteCode)
    return undefined

  return module
)
