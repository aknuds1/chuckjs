define("chuck/instructions", ["chuck/ugen", "chuck/logging", "chuck/types"], (ugen, logging, typesModule) ->
  module = {}
  {types} = typesModule
  {uGenAdd, uGenRemove} = ugen

  callMethod = (vm) ->
    localDepth = vm.popFromReg()
    logging.debug("Popped local depth from stack: #{localDepth}")
    func = vm.popFromReg()
    logging.debug("Popped function from stack")
    stackDepth = func.stackDepth
    args = []
    i = 0
    logging.debug("Popping #{stackDepth} arguments from stack")
    while i < stackDepth
      logging.debug("Popping argument #{i} from stack")
      args.unshift(vm.popFromReg())
      ++i
    thisObj = undefined
    if func.isMember
      logging.debug("Function is a method, passing 'this' to it")
      thisObj = args.pop()
    retVal = func.apply(thisObj, args)
    if func.retType != types.void
      logging.debug("Pushing return value #{retVal} to stack")
      vm.pushToReg(retVal)

  class Instruction
    constructor: (name, params, execute) ->
      @instructionName = name
      _.extend(@, params)
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

  module.allocWord = (offset, isGlobal) ->
    return new Instruction("AllocWord", offset: offset, (vm) ->
      # TODO: Might want to make this depend on variable type
      vm.insertIntoMemory(@offset, 0, isGlobal)
      # Push memory stack index of value
      scopeStr = if isGlobal then "global" else "function"
      logging.debug("Pushing memory stack index #{@offset} (scope: #{scopeStr}) to regular stack")
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
      @type.preConstructor.isMember = true
      @type.preConstructor.stackDepth = 1
      @type.preConstructor.retType = types.void
      vm.pushToReg(@type.preConstructor)
      vm.pushToReg(@stackOffset)

      callMethod(vm)
    )

  module.assignObject = (isArray, isGlobal=true) ->
    new Instruction("AssignObject", {}, (vm) ->
      memStackIndex = vm.popFromReg()
      obj = vm.popFromReg()
      scopeStr = if isGlobal then "global" else "function"
      if !isArray
        logging.debug("#{@instructionName}: Assigning object to memory stack index #{memStackIndex}
         (scope: #{scopeStr}):", obj)
        vm.insertIntoMemory(memStackIndex, obj, isGlobal)
      else
        [array, index] = memStackIndex
        logging.debug("#{@instructionName}: Assigning object to array, index #{index} (scope: #{scopeStr}):", obj)
        array[index] = obj

      vm.pushToReg(obj)
      return
    )

  module.plusAssign = (isGlobal) ->
    new Instruction("PlusAssign", {}, (vm) ->
      memStackIndex = vm.popFromReg()
      rhs = vm.popFromReg()
      lhs = vm.getFromMemory(memStackIndex, isGlobal)
      result = lhs + rhs
      vm.insertIntoMemory(memStackIndex, result, isGlobal)
      vm.pushToReg(result)
      return
    )
  module.minusAssign = (isGlobal) ->
    new Instruction("MinusAssign", {}, (vm) ->
        memStackIndex = vm.popFromReg()
        rhs = vm.popFromReg()
        lhs = vm.getFromMemory(memStackIndex, isGlobal)
        result = lhs - rhs
        vm.insertIntoMemory(memStackIndex, result, isGlobal)
        vm.pushToReg(result)
        return
    )

  module.allocateArray = (type) ->
    new Instruction("AllocateArray", {}, (vm) ->
      sz = vm.popFromReg()
      logging.debug("#{@instructionName}: Allocating array of type #{type.name} and of size #{sz}")
      array = new Array(sz)
      for i in [0...sz]
        array[i] = 0
      vm.pushToReg(array)

      if typesModule.isObj(type.arrayType)
        # Push index
        logging.debug("#{@instructionName}: Pushing index to stack")
        vm.pushToReg(0)
      return
    )

  module.dac = ->
    return new Instruction("Dac", {}, (vm) ->
      vm.pushDac()
      return
    )

  module.releaseObject2 = (offset, isGlobal) ->
    return new Instruction("ReleaseObject2", offset: offset, (vm) ->
      vm.removeFromMemory(offset, isGlobal)
      return
    )

  module.eoc = -> return new Instruction("Eoc")

  module.uGenLink = -> return new Instruction("UGenLink", {}, (vm) ->
    dest = vm.popFromReg()
    src = vm.popFromReg()
    logging.debug("UGenLink: Linking node of type #{src.type.name} to node of type #{dest.type.name}")
    uGenAdd(dest, src)
    vm.pushToReg(dest)
    return
  )

  module.uGenUnlink = -> new Instruction("UGenUnlink", {}, (vm) ->
    dest = vm.popFromReg()
    src = vm.popFromReg()
    logging.debug("#{@instructionName}: Unlinking node of type #{src.type.name} from node of type #{dest.type.name}")
    uGenRemove(dest, src)
    vm.pushToReg(dest)
    return
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
    callMethod(vm)
  )

  module.funcCallStatic = -> new Instruction("FuncCallStatic", {}, (vm) ->
    localDepth = vm.popFromReg()
    logging.debug("Popped local depth from stack: #{localDepth}")
    func = vm.popFromReg()
    stackDepth = func.stackDepth
    logging.debug("Calling static method '#{func.name}'")
    vm.pushToReg(func)
    vm.pushToReg(localDepth)
    callMethod(vm)
  )

  module.funcCall = => new Instruction("FuncCall", {}, (vm) ->
    # TODO: Get rid of this
    localDepth = vm.popFromReg()
    func = vm.popFromReg()
    stackDepth = func.stackDepth
    logging.debug("#{@instructionName}: Calling function #{func.name}, with stackDepth #{stackDepth}")

    logging.debug("#{@instructionName}: Pushing current instructions to memory stack")
    vm.pushToMem(vm.instructions)
    logging.debug("#{@instructionName}: Pushing current instruction counter to memory stack")
    vm.pushToMem(vm._pc + 1)
    vm._nextPc = 0
    vm.instructions = func.code.instructions
    vm.enterFunctionScope()

    if func.needThis
      # Make this the first argument
      obj = vm.popFromReg()
      vm.pushToMem(obj, false)
      --stackDepth

    args = []
    for i in [0...stackDepth]
      arg = vm.popFromReg()
      args.unshift(arg)
    for arg in args
      vm.pushToMem(arg, false)

    return
  )

  module.funcReturn = -> new Instruction("FuncReturn", {}, (vm) ->
    logging.debug("#{@instructionName}: Returning from function")
    vm.exitFunctionScope()

    logging.debug("#{@instructionName}: Popping current instructions from memory stack")
    pc = vm.popFromMem(true)
    logging.debug("#{@instructionName}: Popping current instruction counter from memory stack")
    instructions = vm.popFromMem(true)
    vm._nextPc = pc
    vm.instructions = instructions

    return
  )

  module.regPushMemAddr = (offset, isGlobal) -> return new Instruction("RegPushMemAddr", {}, (vm) ->
    globalStr = if isGlobal then " global" else ""
    logging.debug("#{@instructionName}: Pushing#{globalStr} memory address (@#{offset}) to regular stack")
    vm.pushMemAddrToReg(offset, isGlobal)
    return
  )
  module.regPushMem = (offset, isGlobal) -> return new Instruction("RegPushMem", {}, (vm) ->
    globalStr = if isGlobal then " global" else ""
    logging.debug("#{@instructionName}: Pushing#{globalStr} memory value (@#{offset}) to regular stack")
    vm.pushToRegFromMem(offset, isGlobal)
    return
  )

  module.regDupLast = -> new Instruction("RegDupLast", {}, (vm) ->
    last = vm.regStack[vm.regStack.length-1]
    logging.debug("RegDupLast: Duplicating top of stack: #{last}")
    vm.regStack.push(last)
    return
  )

  module.dotMemberFunc = (func) -> new Instruction("DotMemberFunc", {}, (vm) ->
    logging.debug("#{@instructionName}: Popping instance from stack")
    vm.popFromReg()
    # TODO: Get implementation of function from object's vtable
    logging.debug("#{@instructionName}: Pushing instance method to stack:", func)
    vm.pushToReg(func)
  )

  module.dotStaticFunc = (func) -> new Instruction("DotStaticFunc", {}, (vm) ->
    logging.debug("DotStaticFunc: Pushing static method to stack:", func)
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

  module.divideNumber = -> new Instruction("DivideNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    number = lhs/rhs
    logging.debug("DivideNumber (#{lhs}/#{rhs}) resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.regPushNow = -> return new Instruction("RegPushNow", {}, (vm) ->
    vm.pushNow()
    return
  )

  module.regPushMe = -> return new Instruction("RegPushMe", {}, (vm) ->
    vm.pushMe()
    return
  )

  module.addNumber = -> return new Instruction("AddNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    number = lhs+rhs
    logging.debug("#{@instructionName} resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.preIncNumber = (isGlobal) -> new Instruction("PreIncnUmber", {}, (vm) ->
    memStackIndex = vm.popFromReg()
    val = vm.getFromMemory(memStackIndex, isGlobal)
    ++val
    vm.insertIntoMemory(memStackIndex, val, isGlobal)
    vm.pushToReg(val)
    return
  )

  module.postIncNumber = (isGlobal) -> new Instruction("PostIncnUmber", {}, (vm) ->
    memStackIndex = vm.popFromReg()
    val = vm.getFromMemory(memStackIndex, isGlobal)
    vm.pushToReg(val)
    ++val
    vm.insertIntoMemory(memStackIndex, val, isGlobal)
    return
  )

  module.subtractNumber = -> new Instruction("SubtractNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    number = lhs-rhs
    logging.debug("#{@instructionName}: Subtracting #{rhs} from #{lhs} resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.timesNumber = -> new Instruction("TimesNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    number = lhs*rhs
    logging.debug("#{@instructionName}: Multiplying #{lhs} with #{rhs} resulted in: #{number}")
    vm.pushToReg(number)
    return
  )

  module.ltNumber = -> new Instruction("LtNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    result = lhs < rhs
    logging.debug("#{@instructionName}: Pushing #{result} to regular stack")
    vm.pushToReg(result)
    return
  )

  module.gtNumber = -> new Instruction("GtNumber", {}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    result = lhs > rhs
    logging.debug("#{@instructionName}: Pushing #{result} to regular stack")
    vm.pushToReg(result)
    return
  )

  module.timeAdvance = -> return new Instruction("TimeAdvance", {}, (vm) ->
    time = vm.popFromReg()
    vm.suspendUntil(time)
    vm.pushToReg(time)
    return
  )

  formatFloat = (value) -> value.toFixed(6)

  module.gack = (types) -> new Instruction("Gack", {}, (vm) ->
    if types.length == 1
      module.hack(types[0]).execute(vm)
      return

    values = []
    for i in [0...types.length]
      values.unshift(vm.popFromReg())
    str = ""
    for tp, i in types
      value = values[i]
      if tp == types.float
        str += "#{formatFloat(value)} "
      else
        str += "#{value} "

      vm.pushToReg(value)

    console.log(str[0...str.length-1])
    return
  )

  module.hack = (type) -> new Instruction("Hack", {}, (vm) ->
    obj = vm.peekReg()
    logging.debug("Printing object of type #{type.name}:", obj)
    if _.isArray(obj)
      arrStr = _.str.join(",", obj)
      console.log("[#{arrStr}] :(#{type.name}[])")
    else if type == types.String
      console.log("\"#{obj}\" : (#{type.name})")
    else if type == types.float
      console.log("#{formatFloat(obj)} :(#{type.name})")
    else if type == types.int
      console.log("#{obj} :(#{type.name})")
    else
      console.log("#{obj} : (#{type.name})")
    return
  )

  module.branchEq = (jmp) -> new Instruction("BranchEq", {jmp: jmp}, (vm) ->
    rhs = vm.popFromReg()
    lhs = vm.popFromReg()
    result = lhs == rhs
    logging.debug("Comparing #{lhs} to #{rhs}: #{result}")
    if result
      logging.debug("Jumping to instruction number #{@jmp}")
      vm.jumpTo(@jmp)
    else
      logging.debug("Not jumping")
    return
  )

  module.goto = (jmp) -> new Instruction("Goto", {jmp: jmp}, (vm) ->
    logging.debug("Jumping to instruction number #{@jmp}")
    vm.jumpTo(@jmp)
    return
  )

  module.arrayAccess = (type, emitAddr) -> new Instruction("ArrayAccess", {}, (vm) ->
    logging.debug("#{@instructionName}: Accessing array of type #{type.name}")
    [idx, array] = [vm.popFromReg(), vm.popFromReg()]
    if !emitAddr
      val = array[idx]
      logging.debug("Pushing array[#{idx}] (#{val}) to regular stack")
      vm.pushToReg(val)
    else
      logging.debug("Pushing array (#{array}) and index (#{idx}) to regular stack")
      vm.pushToReg([array, idx])
    return
  )

  module.memSetImm = (offset, value, isGlobal) -> new Instruction("MemSetImm", {}, (vm) ->
    scopeStr = if isGlobal then "global" else "function"
    logging.debug("#{@instructionName}: Setting memory at offset #{offset} (scope: #{scopeStr}) to:", value)
    vm.insertIntoMemory(offset, value, isGlobal)
  )

  class UnaryOpInstruction extends Instruction
    constructor: (name, params, execute) ->
      super(name, params, execute)
      @_val = 0

    set: (val) =>
      @_val = val

  module.preCtorArrayTop = (type) -> new UnaryOpInstruction("PreCtorArrayTop", {}, (vm) ->
    index = vm.peekReg()
    array = vm.peekReg(1)
    if index >= array.length
      logging.debug("#{@instructionName}: Finished instantiating elements")
      vm.jumpTo(@_val)
    else
      logging.debug("#{@instructionName}: Instantiating element #{index} of type #{type.name}")
      module.instantiateObject(type).execute(vm)
  )

  module.preCtorArrayBottom = -> new UnaryOpInstruction("PreCtorArrayBottom", {}, (vm) ->
    logging.debug("#{@instructionName}: Popping object and index from stack")
    obj = vm.popFromReg()
    index = vm.popFromReg()
    logging.debug("#{@instructionName}: Peeking array from stack")
    array = vm.peekReg()

    logging.debug("#{@instructionName}: Assigning to index #{index} of array:", obj)
    array[index] = obj
    # Increment index
    logging.debug("#{@instructionName}: Pushing incremented index to stack")
    vm.pushToReg(index+1)

    # Goto top
    logging.debug("#{@instructionName}: Jumping to instruction #{@_val}")
    vm.jumpTo(@_val)
  )

  module.preCtorArrayPost = -> new Instruction("PreCtorArrayPost", {}, (vm) ->
    logging.debug("#{@instructionName}: Cleaning up, popping index from stack")
    # Pop index
    vm.popFromReg()
  )

  module.arrayInit = (type, count) -> new Instruction("ArrayInit", {}, (vm) ->
    logging.debug("#{@instructionName}: Popping #{count} elements from stack")
    values = []
    for i in [0...count]
      values.unshift(vm.popFromReg())
    logging.debug("#{@instructionName}: Pushing instantiated array to stack", values)
    vm.pushToReg(values)
  )

  return module
)
