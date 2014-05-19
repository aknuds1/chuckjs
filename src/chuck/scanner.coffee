define("chuck/scanner", ["chuck/nodes", "chuck/types", "chuck/instructions", "chuck/namespace", "chuck/logging",
"chuck/libs/math", "chuck/libs/std", "chuck/libs/stk", "chuck/libs/ugens"],
(nodes, types, instructions, namespaceModule, logging, mathLib, stdLib, stkLib, ugensLib) ->
  module = {}
  {Instruction} = instructions
  class ChuckLocal
    constructor: (@size, @ri, @name, @isContextGlobal) ->

  class ChuckFrame
    constructor: ->
      @currentOffset = 0
      @stack = []

  class ChuckCode
    constructor: ->
      @instructions = []
      @frame = new ChuckFrame()
      # Current register index
      @_ri = 0

      @pushScope()

    allocRegister: (value) ->
      ri = ++@_ri
      if value?
        value.ri = ri
      ri

    pushScope: =>
      @frame.stack.push(null)
      return

    popScope: =>
      while @frame.stack.length > 0 && @frame.stack[@frame.stack.length-1]?
        @frame.stack.pop()
        --@frame.currentOffset
      # Pop sentinel
      @frame.stack.pop()
      logging.debug("After popping scope, current stack offset is #{@frame.currentOffset}")
      return

    append: (instruction) =>
      @instructions.push(instruction)
      return instruction

    allocateLocal: (type, value, isGlobal) ->
      ri = @allocRegister()
      local = new ChuckLocal(type.size, ri, value.name, isGlobal)
      scopeStr = if isGlobal then "global" else "function"
      logging.debug("Allocating local #{value.name} of type #{type.name} in register #{local.ri} (scope: #{scopeStr})")
      @frame.currentOffset += 1
      @frame.stack.push(local)
      value.ri = local.ri
      local

    finish: =>
      stack = @frame.stack
      locals = []
      while stack.length > 0 && stack[stack.length-1]?
        local = stack.pop()
        if local?
          @frame.currentOffset -= local.size
          locals.push(local)
      # Get rid of sentinel
      stack.pop()
      locals

    getNextIndex: => @instructions.length

  class ScanningContext
    constructor: ->
      @code = new ChuckCode()
      # Create global variables
      @_globalNamespace = new namespaceModule.Namespace("global")
      for lib in [types, mathLib, stdLib, stkLib, ugensLib]
        for own k, type of lib.types
          @_globalNamespace.addType(type)
          typeType = _.extend({}, types.Class)
          typeType.actualType = type
          value = @_globalNamespace.addVariable(type.name, typeType, type)
          @code.allocRegister(value)

      value = @_globalNamespace.addVariable("dac", types.types.Dac)
      @code.allocRegister(value)
      value = @_globalNamespace.addVariable("blackhole", types.types.Bunghole)
      @code.allocRegister(value)
      value = @_globalNamespace.addVariable("now", types.types.Time)
      @code.allocRegister(value)
      value = @_globalNamespace.addVariable("me", types.types.shred)
      @code.allocRegister(value)

      @_globalNamespace.commit()
      @_namespaceStack = [@_globalNamespace]
      @_currentNamespace = @_globalNamespace
      @_breakStack = []
      @_contStack = []
      @_codeStack = []
      @_isGlobal = true
      @_functionLevel = 0

    ###*
    Replace code object while storing the old one on the stack.
    ###
    pushCode: (name) =>
      @enterFunctionScope()
      logging.debug("Pushing code object")
      @_codeStack.push(@code)
      @code = new ChuckCode()
      @code.name = name
      @code

    ###*
    Restore code object at the top of the stack.
    ###
    popCode: =>
      logging.debug("Popping code object")
      toReturn = @code
      @code = @_codeStack.pop()
      @_isGlobal = @_codeStack.length == 0
      if @_isGlobal
        logging.debug("Back at global scope")

      @exitFunctionScope()

      toReturn

    enterFunctionScope: =>
      ++@_functionLevel
      @_isGlobal = false
      @enterScope()
      return
    exitFunctionScope: =>
      @exitScope()
      --@_functionLevel
      @_isGlobal = @_functionLevel <= 0
      return

    findType: (typeName) =>
      type = @_currentNamespace.findType(typeName)
      return type

    findValue: (name, climb=false) =>
      # Look locally first
      val = @_currentNamespace.findValue(name, climb)
      if val?
        return val
      # Look globally
      val = @_currentNamespace.findValue(name, true)

    addVariable: (name, type) ->
      @_currentNamespace.addVariable(name, type, null, @_isGlobal)

    addConstant: (name, type, value) ->
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Adding constant #{name} (scope: #{scopeStr})")
      @_currentNamespace.addConstant(name, type, value, @_isGlobal)

    addValue: (value, name) ->
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Adding value #{name} (scope: #{scopeStr})")
      @_currentNamespace.addValue(value, name, @_isGlobal)

    createValue: (type, name) ->
      new namespaceModule.ChuckValue(type, name, @_currentNamespace, @_isGlobal)

    pushToBreakStack: (statement) =>
      @_breakStack.push(statement)

    pushToContStack: (statement) =>
      @_contStack.push(statement)

    instantiateObject: (type, ri) =>
      logging.debug("Emitting instantiation of object of type #{type.name} along with preconstructor")
      @code.append(instructions.instantiateObject(type, ri))
      @_emitPreConstructor(type, ri)
      return

    ### Allocate new register. ###
    allocRegister: -> @code.allocRegister()

    allocateLocal: (type, value) ->
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Allocating local (scope: #{scopeStr})")
      local = @code.allocateLocal(type, value, @_isGlobal)
#      if emit
#        debugger
#        logging.debug("Emitting AllocWord instruction")
#        @code.append(instructions.allocWord(local.offset, @_isGlobal))
      local

    getNextIndex: => @code.getNextIndex()

    enterScope: => @_currentNamespace.enterScope()
    exitScope: => @_currentNamespace.exitScope()

    enterCodeScope: =>
      logging.debug("Entering nested code scope")
      @code.pushScope()
      return

    exitCodeScope: =>
      logging.debug("Exiting nested code scope")
      @code.popScope()
      return

    emitAssignment: (type, varDecl) ->
      {value, array} = varDecl
      local = @allocateLocal(type, value)
      if array?
        # Emit indices
        logging.debug("Emitting array indices")
        array.scanPass5(@)
        logging.debug("Emitting AllocateArray")
        @code.append(instructions.allocateArray(type, array.ri, local.ri))
        elemType = type.arrayType

        typesWithCtors = []
        addConstructors = (type) ->
          if type.parent?
            addConstructors(type.parent)
          if type.hasConstructor
            typesWithCtors.push(type)

        if types.isObj(elemType)
          logging.debug("Emitting PreCtorArray")
          addConstructors(elemType)
          @code.append(instructions.preCtorArray(elemType, array.ri, local.ri, typesWithCtors))

      isObj = types.isObj(type) || array?
      if isObj && !array? && !type.isRef
        @instantiateObject(type, local.ri)

      local.ri

    emitPlusAssign: (r1, r2, r3) =>
      @code.append(instructions.plusAssign(r1, r2, r3))
      return
    emitMinusAssign: (r1, r2, r3) =>
      @code.append(instructions.minusAssign(r1, r2, r3))
      return

    emitUGenLink: (r1, r2) ->
      @code.append(instructions.uGenLink(r1, r2))
      return

    emitUGenUnlink: (r1, r2) ->
      @code.append(instructions.uGenUnlink(r1, r2))
      return

    emitLoadConst: (value) ->
      r1 = @allocRegister()
      @code.append(new Instruction("LoadConst", {val: value, r1: r1}))
      r1

    emitLoadLocal: (r1) ->
      r2 = @allocRegister()
      @code.append(new Instruction("LoadLocal", {r1: r1, r2: r2}))
      r2

    emitFuncCallMember: (r1, r2) ->
      @code.append(new Instruction("FuncCallMember", {r1: r1, r2: r2}))
      return

    emitFuncCallStatic: (r1, r2) ->
      @code.append(new Instruction("FuncCallStatic", {r1: r1, r2: r2}))
      return

    emitFuncCall: ->
      @code.append(instructions.funcCall())

    emitRegPushMemAddr: (offset, isGlobal) =>
      @code.append(instructions.regPushMemAddr(offset, isGlobal))
      return
    emitRegPushMem: (offset, isGlobal) =>
      @code.append(instructions.regPushMem(offset, isGlobal))
      return

    emitDotStaticFunc: (func) ->
      @code.append(instructions.dotStaticFunc(func))
      return

    emitDotMemberFunc: (func, r1) ->
      r2 = @allocRegister()
      @code.append(new Instruction("DotMemberFunc", {func: func, r1: r1, r2: r2}))
      r2

    emitTimesNumber: (r1, r2, r3) ->
      @code.append(new Instruction("TimesNumber", {r1: r1, r2: r2, r3: r3}))
      return

    emitDivideNumber: (r1, r2, r3) ->
      @code.append(instructions.divideNumber(r1, r2, r3))
      return

    emitRegPushMe: =>
      @code.append(instructions.regPushMe())
      return

    emitAddNumber: (r1, r2, r3) ->
      @code.append(new Instruction("AddNumber", {r1: r1, r2: r2, r3: r3}))
      return

    emitPreIncNumber: (r1, r2) -> @code.append(instructions.preIncNumber(r1, r2))

    emitPostIncNumber: (r1, r2) -> @code.append(instructions.postIncNumber(r1, r2))

    emitSubtractNumber: (r1, r2, r3) ->
      @code.append(instructions.subtractNumber(r1, r2, r3))
      return

    emitTimesNumber: (r1, r2, r3) ->
      @code.append(new Instruction("TimesNumber", {r1: r1, r2: r2, r3: r3}))

    emitLtNumber: (r1, r2, r3) ->
      @code.append(new Instruction("LtNumber", {r1: r1, r2: r2, r3: r3}))
      return

    emitGtNumber: (r1, r2, r3) ->
      @code.append(new Instruction("GtNumber", {r1: r1, r2: r2, r3: r3}))
      return

    emitTimeAdvance: (r1) ->
      logging.debug("Emitting TimeAdvance of register #{r1}")
      @code.append(new Instruction("TimeAdvance", {r1: r1}))
      return

    emitOpAtChuck: (r1, r2, isArray=false) ->
      logging.debug("Emitting AssignObject of register #{r1} to #{r2} (isArray: #{isArray})")
      @code.append(instructions.assignObject(isArray, @_isGlobal, r1, r2))
      return

    emitGack: (types, registers) ->
      @code.append(instructions.gack(types, registers))
      return

    emitBranchEq: (r1, r2, jmp) ->
      logging.debug("Emitting BranchEq of registers " + r1 + " and " + r2)
      @code.append(new Instruction("BranchEq", {r1: r1, r2: r2, jmp: jmp}))

    emitGoto: (jmp) ->
      @code.append(instructions.goto(jmp))

    emitBreak: ->
      instr = instructions.goto()
      @code.append(instr)
      @_breakStack.push(instr)

    emitArrayAccess: (type, r1, r2, r3, emitAddr) ->
      @code.append(instructions.arrayAccess(type, r1, r2, r3, emitAddr))

    emitArrayInit: (type, registers, ri) -> @code.append(instructions.arrayInit(type, registers, ri))

    emitMemSetImm: (offset, value, isGlobal) ->
      @code.append(instructions.memSetImm(offset, value, isGlobal))

    emitFuncReturn: ->
      @code.append(instructions.funcReturn())

    emitNegateNumber: (r1, r2) -> @code.append(instructions.negateNumber(r1, r2))

    evaluateBreaks: =>
      while @_breakStack.length
        instr = @_breakStack.pop()
        instr.jmp = @_nextIndex()
      return

    finishScanning: =>
      @code.finish()
      @code.append(instructions.eoc())
      return

    addFunction: (funcDef) =>
      value = @findValue(funcDef.name)
      if value?
        funcGroup = value.value
        logging.debug("Found corresponding function group #{funcDef.name}")
      else
        # Create corresponding function group
        logging.debug("Creating function group #{funcDef.name}")
        type = new types.ChuckType("[function]", types.types.Function)
        funcGroup = new types.ChuckFunction(funcDef.name, [], funcDef.retType)
        type.func = funcGroup
        funcGroup.value = @addConstant(funcGroup.name, type, funcGroup)

      name = "#{funcDef.name}@#{funcGroup.getNumberOfOverloads()}@#{@_currentNamespace.name || ''}"
      logging.debug("Adding function #{name}")
      args = []
      for arg in funcDef.args
        funcArg = new types.FuncArg(arg.varDecl.name, types.types[arg.typeDecl.type])
        logging.debug("Adding function argument #{funcArg.name} of type #{funcArg.type.name}")
        args.push(funcArg)
      func = new types.FunctionOverload(args, null, false, name)
      funcGroup.addOverload(func)
      func.value = @addConstant(name, funcGroup.value.type, func)

      func

    getCurrentOffset: => @code.frame.currentOffset

    _emitPreConstructor: (type, ri) =>
      if type.parent?
        @_emitPreConstructor(type.parent, ri)

      if type.hasConstructor
        @code.append(instructions.preConstructor(type, ri))

      return

    _nextIndex: =>
      return @code.instructions.length

  class Scanner
    constructor: (ast) ->
      @_ast = ast
      @_context = new ScanningContext()
      # Current register index
      @_ri = 1

    pass1: =>
      @_pass(1)

    pass2: =>
      @_pass(2)

    pass3: =>
      @_pass(3)

    pass4: =>
      @_pass(4)

    pass5: =>
      @_pass(5)
      @_context.finishScanning()
      @byteCode = @_context.code.instructions

    _pass: (num) =>
      program = @_ast
      program["scanPass#{num}"](@_context)

  module.scan = (ast) ->
    scanner = new Scanner(ast)
    logging.debug("Scan pass 1")
    scanner.pass1()
    logging.debug("Scan pass 2")
    scanner.pass2()
    logging.debug("Scan pass 3")
    scanner.pass3()
    logging.debug("Scan pass 4")
    scanner.pass4()
    logging.debug("Scan pass 5")
    scanner.pass5()

    return scanner.byteCode

  return module
)
