define("chuck/instructions", ["chuck/ugen", "chuck/logging", "chuck/types"], (ugen, logging, typesModule) ->
  module = {}

  callMember = (vm) ->
    localDepth = vm.popFromReg()
    logging.debug("Popped local depth from stack: #{localDepth}")
    func = vm.popFromReg()
    logging.debug("Popped function from stack")
    stackDepth = func.stackDepth
    args = []
    i = 0
    while i < stackDepth
      args.unshift(vm.popFromReg())
      logging.debug("Popping argument #{i} from stack: #{args[0]}")
      ++i
    thisObj = undefined
    if func.needThis
      logging.debug("Function is a method, passing 'this' to it")
      thisObj = args.pop()
    func.apply(thisObj, args)

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
      logging.debug("Instantiating object of type #{type.name}")
      ug = new ugen.UGen(type)
      vm.addUgen(ug)
      vm.pushToReg(ug)
    )

  module.allocWord = (offset) ->
    return new Instruction("AllocWord", offset: offset, (vm) ->
      # Push memory stack index of value
      logging.debug("Pushing memory stack index #{@offset} to regular stack")
      vm.pushToReg(@offset)
    )

  module.popWord = ->
    return new Instruction("PopWord", undefined, (vm) ->
      logging.debug("Popping from regular stack")
      vm.popFromReg()
    )

  module.preConstructor = (type, stackOffset) ->
    return new Instruction("PreConstructor", type: type, stackOffset: stackOffset, (vm) ->
      # Duplicate top of stack, which should be object pointer
      logging.debug("Calling pre-constructor of #{@type.name}")
      # Push 'this' reference
      vm.pushToReg(vm.peekReg())
      # Signal that this function needs a 'this' reference
      @type.preConstructor.needThis = true
      @type.preConstructor.stackDepth = 1
      vm.pushToReg(@type.preConstructor)
      vm.pushToReg(@stackOffset)

      callMember(vm)
    )

  module.assignObject = ->
    return new Instruction("AssignObject", {}, (vm) ->
      memStackIndex = vm.popFromReg()
      obj = vm.popFromReg()
      vm.insertIntoMemory(memStackIndex, obj)
      vm.pushToReg(obj)
      return undefined
    )

  module.dac = ->
    return new Instruction("Dac", {}, (vm) ->
      vm.pushDac()
      return undefined
    )

  module.releaseObject2 = (offset) ->
    return new Instruction("ReleaseObject2", offset: offset, (vm) ->
      logging.debug("Removing index #{offset} of memory stack")
      vm.removeFromMemory(offset)
      return undefined
    )

  module.eoc = -> return new Instruction("Eoc")

  module.uGenLink = -> return new Instruction("UGenLink", {}, (vm) ->
    dest = vm.popFromReg()
    src = vm.popFromReg()
    dest.add(src)
    return undefined
  )

  module.regPushImm = (val) -> return new Instruction("RegPushImm", val: val, (vm) ->
    logging.debug("RegPushImm: Pushing #{val} to stack")
    vm.pushToReg(val)
    return
  )

  module.funcCallMember = -> new Instruction("FuncCallMember", {}, (vm) ->
    localDepth = vm.popFromReg()
    func = vm.popFromReg()
    vm.pushToReg(func)
    vm.pushToReg(localDepth)
    logging.debug("Calling instance method '#{func.name}'")
    callMember(vm)
  )

  module.regPushMem = (offset) -> return new Instruction("RegPushMem", {}, (vm) ->
    logging.debug("RegPushMem")
    vm.pushToRegFromMem(offset)
    return
  )

  module.regDupLast = -> new Instruction("RegDupLaat", {}, (vm) ->
    last = vm.regStack[vm.regStack.length-1]
    logging.debug("RegDupLast: Duplicating top of stack: #{last}")
    vm.regStack.push(last)
    return
  )

  module.dotMemberFunc = (id) -> new Instruction("DotMemberFunc", {}, (vm) ->
    obj = vm.popFromReg()
    logging.debug("DotMemberFunc: Pushing method #{id} of type #{obj.type.name} to stack")
    func = obj.type.findValue(id).value
    vm.pushToReg(func)
    return
  )

  module.timesNumber = -> return new Instruction("TimesNumber", {}, (vm) ->
    lhs = vm.popFromReg()
    rhs = vm.popFromReg()
    number = lhs*rhs
    logging.debug("TimesNumber resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.regPushNow = -> return new Instruction("RegPushNow", {}, (vm) ->
    vm.pushNow()
    return undefined
  )

  module.addNumber = -> return new Instruction("AddNumber", {}, (vm) ->
    lhs = vm.popFromReg()
    rhs = vm.popFromReg()
    number = lhs+rhs
    logging.debug("AddNumber resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.timeAdvance = -> return new Instruction("TimeAdvance", {}, (vm) ->
    time = vm.popFromReg()
    vm.suspendUntil(time)
    vm.pushToReg(time)
    return
  )

  module.gack = (types) -> new Instruction("Gack", {}, (vm) ->
    module.hack(types[0]).execute(vm)
    return
  )

  module.hack = (type) -> new Instruction("Hack", {}, (vm) ->
    obj = vm.peekReg()
    logging.debug("Printing object of type #{type.name}")
    if type == typesModule.String
      console.log("\"#{obj}\" : (#{type.name})")
    else
      console.log("#{obj} : (#{type.name})")
    return
  )

  module.branchEq = (jmp) -> new Instruction("BranchEq", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    if lhs == rhs
      vm.jumpTo(jmp)
    return
  )

  module.goto = (jmp) -> new Instruction("Goto", {jmp: jmp}, (vm) ->
    logging.debug("Jumping to instruction #{@jmp}")
    vm.jumpTo(@jmp)
    return
  )

  return module
)
