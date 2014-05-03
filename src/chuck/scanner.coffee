define("chuck/scanner", ["chuck/nodes", "chuck/types", "chuck/instructions", "chuck/namespace", "chuck/logging",
"chuck/libs/math", "chuck/libs/std", "chuck/libs/stk"],
(nodes, types, instructions, namespaceModule, logging, mathLib, stdLib, stkLib) ->
  module = {}
  class ChuckLocal
    constructor: (@size, @offset, @name, @isContextGlobal) ->

  class ChuckFrame
    constructor: ->
      @currentOffset = 0
      @stack = []

  class ChuckCode
    constructor: ->
      @instructions = []
      @frame = new ChuckFrame()

      @pushScope()

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

    allocateLocal: (type, value, isGlobal) =>
      local = new ChuckLocal(type.size, @frame.currentOffset, value.name, isGlobal)
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Allocating local #{value.name} of type #{type.name} at offset #{local.offset} (scope: #{scopeStr})")
      @frame.currentOffset += 1
      @frame.stack.push(local)
      value.offset = local.offset
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
      return locals

    getNextIndex: => @instructions.length

  class ScanningContext
    constructor: ->
      @code = new ChuckCode()
      @_globalNamespace = new namespaceModule.Namespace("global")
      for lib in [types, mathLib, stdLib, stkLib]
        for own k, type of lib.types
          @_globalNamespace.addType(type)
          typeType = _.extend({}, types.Class)
          typeType.actualType = type
          @_globalNamespace.addVariable(type.name, typeType, type)

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

    addVariable: (name, type) =>
      @_currentNamespace.addVariable(name, type, null, @_isGlobal)

    addConstant: (name, type, value) =>
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Adding constant #{name} (scope: #{scopeStr})")
      @_currentNamespace.addConstant(name, type, value, @_isGlobal)

    addValue: (value, name) =>
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Adding value #{name} (scope: #{scopeStr})")
      @_currentNamespace.addValue(value, name, @_isGlobal)

    createValue: (type, name) =>
      new namespaceModule.ChuckValue(type, name, @_currentNamespace, @_isGlobal)

    pushToBreakStack: (statement) =>
      @_breakStack.push(statement)

    pushToContStack: (statement) =>
      @_contStack.push(statement)

    instantiateObject: (type) =>
      logging.debug("Emitting instantiation of object of type #{type.name} along with preconstructor")
      @code.append(instructions.instantiateObject(type))
      @_emitPreConstructor(type)

    allocateLocal: (type, value, emit=true) =>
      scopeStr = if @_isGlobal then "global" else "function"
      logging.debug("Allocating local (scope: #{scopeStr})")
      local = @code.allocateLocal(type, value, @_isGlobal)
      if emit
        logging.debug("Emitting AllocWord instruction")
        @code.append(instructions.allocWord(local.offset, @_isGlobal))
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

    emitAssignment: (type, varDecl) =>
      {value, array} = varDecl
      if array?
        # Emit indices
        logging.debug("Emitting array indices")
        array.scanPass5(@)
        logging.debug("Emitting AllocateArray")
        @code.append(instructions.allocateArray(type))
        elemType = type.arrayType
        if types.isObj(elemType)
          startIndex = @_nextIndex()
          logging.debug("Emitting PreCtorArrayTop")
          top = @code.append(instructions.preCtorArrayTop(elemType))
          @_emitPreConstructor(elemType)
          logging.debug("Emitting PreCtorArrayBottom")
          bottom = @code.append(instructions.preCtorArrayBottom(elemType))
          top.set(@_nextIndex())
          bottom.set(startIndex)
          @code.append(instructions.preCtorArrayPost())

      isObj = types.isObj(type) || array?
      if isObj && !array? && !type.isRef
        @instantiateObject(type)

      @allocateLocal(type, value)
      if isObj && !type.isRef
        logging.debug("Emitting AssignObject")
        @code.append(instructions.assignObject(false, @_isGlobal))
      return

    emitPlusAssign: (isGlobal) =>
      @code.append(instructions.plusAssign(isGlobal))
      return
    emitMinusAssign: (isGlobal) =>
      @code.append(instructions.minusAssign(isGlobal))
      return

    emitDac: =>
      @code.append(instructions.dac())
      return

    emitUGenLink: =>
      @code.append(instructions.uGenLink())
      return

    emitUGenUnlink: =>
      @code.append(instructions.uGenUnlink())
      return

    emitPopWord: =>
      @code.append(instructions.popWord())
      return

    emitRegPushImm: (value) =>
      @code.append(instructions.regPushImm(value))
      return

    emitFuncCallMember: =>
      # The top of the stack should be the 'this' reference
      @code.append(instructions.funcCallMember())
      return

    emitFuncCallStatic: =>
      @code.append(instructions.funcCallStatic())
      return

    emitFuncCall: =>
      @code.append(instructions.funcCall())

    emitRegPushMemAddr: (offset, isGlobal) =>
      @code.append(instructions.regPushMemAddr(offset, isGlobal))
      return
    emitRegPushMem: (offset, isGlobal) =>
      @code.append(instructions.regPushMem(offset, isGlobal))
      return

    emitRegDupLast: =>
      @code.append(instructions.regDupLast())
      return

    emitDotStaticFunc: (func) =>
      @code.append(instructions.dotStaticFunc(func))
      return

    emitDotMemberFunc: (func) =>
      @code.append(instructions.dotMemberFunc(func))
      return

    emitTimesNumber: =>
      @code.append(instructions.timesNumber())
      return

    emitDivideNumber: =>
      @code.append(instructions.divideNumber())
      return

    emitRegPushNow: =>
      @code.append(instructions.regPushNow())
      return

    emitRegPushMe: =>
      @code.append(instructions.regPushMe())
      return

    emitAddNumber: =>
      @code.append(instructions.addNumber())
      return

    emitPreIncNumber: (isGlobal) => @code.append(instructions.preIncNumber(isGlobal))

    emitPostIncNumber: (isGlobal) => @code.append(instructions.postIncNumber(isGlobal))

    emitSubtractNumber: =>
      @code.append(instructions.subtractNumber())
      return

    emitTimesNumber: =>
      @code.append(instructions.timesNumber())

    emitLtNumber: =>
      @code.append(instructions.ltNumber())
      return

    emitGtNumber: =>
      @code.append(instructions.gtNumber())
      return

    emitTimeAdvance: =>
      @code.append(instructions.timeAdvance())
      return

    emitOpAtChuck: (isArray=false) =>
      logging.debug("Emitting AssignObject (isArray: #{isArray})")
      @code.append(instructions.assignObject(isArray, @_isGlobal))
      return

    emitGack: (types) =>
      @code.append(instructions.gack(types))
      return

    emitBranchEq: (jmp) =>
      @code.append(instructions.branchEq(jmp))

    emitGoto: (jmp) =>
      @code.append(instructions.goto(jmp))

    emitBreak: =>
      instr = instructions.goto()
      @code.append(instr)
      @_breakStack.push(instr)

    emitArrayAccess: (type, emitAddr) =>
      @code.append(instructions.arrayAccess(type, emitAddr))

    emitArrayInit: (type, count) => @code.append(instructions.arrayInit(type, count))

    emitMemSetImm: (offset, value, isGlobal) =>
      @code.append(instructions.memSetImm(offset, value, isGlobal))

    emitFuncReturn: =>
      @code.append(instructions.funcReturn())

    evaluateBreaks: =>
      while @_breakStack.length
        instr = @_breakStack.pop()
        instr.jmp = @_nextIndex()
      return

    finishScanning: =>
      locals = @code.finish()
      for local in locals
        @code.append(instructions.releaseObject2(local.offset, local.isContextGlobal))

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

    _emitPreConstructor: (type) =>
      if type.parent?
        @_emitPreConstructor(type.parent)

      if type.hasConstructor
        @code.append(instructions.preConstructor(type, @getCurrentOffset()))

      return

    _nextIndex: =>
      return @code.instructions.length

  class Scanner
    constructor: (ast) ->
      @_ast = ast
      @_context = new ScanningContext()

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
