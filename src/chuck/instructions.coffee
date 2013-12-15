define("chuck/instructions", ["chuck/ugen"], (ugen) ->
  module = {}

  class Instruction
    constructor: (name, params, execute) ->
      @instructionName = name
      _(@).extend(params)
      @_executeCb = execute

    execute: (vm) =>
      if !@_executeCb
        return
      @_executeCb.call(@, vm)

  module.instantiateObject = (type) ->
    return new Instruction("InstantiateObject", type: type, (vm) ->
      ug = new ugen.UGen(type)
      vm.addUgen(ug)
      vm.pushToReg(ug)
    )

  module.allocWord = (offset) ->
    return new Instruction("AllocWord", offset: offset)

  module.popWord = ->
    return new Instruction("PopWord")

  module.preConstructor = (type, offset) ->
    return new Instruction("PreConstructor", type: type, offset: offset)

  module.assignObject = ->
    return new Instruction("AssignObject")

  module.symbol = (name) ->
    return new Instruction("Symbol", name: name)

  module.releaseObject2 = (offset) ->
    return new Instruction("ReleaseObject2", offset: offset)

  module.eoc = -> return new Instruction("Eoc")

  module.uGenLink = -> return new Instruction("UGenLink")

  return module
)
