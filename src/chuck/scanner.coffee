define("chuck/scanner", ["chuck/nodes", "chuck/types", "chuck/instructions", "chuck/namespace", "chuck/logging",
"chuck/libs/math", "chuck/libs/std", "chuck/libs/stk"],
(nodes, types, instructions, namespaceModule, logging, mathLib, stdLib, stkLib) ->
  module = {}

  class ChuckLocal
    constructor: (size, offset, name) ->
      @size = size
      @offset = offset
      @name = name

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

    allocateLocal: (type, value) =>
      local = new ChuckLocal(type.size, @frame.currentOffset, value.name)
      logging.debug("Allocating local #{value.name} of type #{type.name} at offset #{local.offset}")
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

    addVariable: (name, typeName) =>
      return @_currentNamespace.addVariable(name, typeName)

    addValue: (value) =>
      @_currentNamespace.addValue(value)

    pushToBreakStack: (statement) =>
      @_breakStack.push(statement)

    pushToContStack: (statement) =>
      @_contStack.push(statement)

    instantiateObject: (type) =>
      logging.debug("Emitting instantiation of object of type #{type.name} along with preconstructor")
      @code.append(instructions.instantiateObject(type))
      @_emitPreConstructor(type)

    allocateLocal: (type, value) =>
      logging.debug("Allocating local")
      logging.debug("Emitting AllocWord instruction")
      local = @code.allocateLocal(type, value)
      @code.append(instructions.allocWord(local.offset))

    getNextIndex: => @code.getNextIndex()

    enterScope: => @_currentNamespace.enterScope()
    exitScope: => @_currentNamespace.exitScope()

    emitScopeEntrance: =>
      logging.debug("Emitting entrance of nested scope")
      @code.pushScope()
      return

    emitScopeExit: =>
      logging.debug("Emitting exit of nested scope")
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
        if types.isObj(type)
          startIndex = @_nextIndex()
          logging.debug("Emitting PreCtorArrayTop")
          top = @code.append(instructions.preCtorArrayTop(type))
          @_emitPreConstructor(type)
          logging.debug("Emitting PreCtorArrayBottom")
          bottom = @code.append(instructions.preCtorArrayBottom(type))
          top.set(@_nextIndex())
          bottom.set(startIndex)
          @code.append(instructions.preCtorArrayPost())

      isObj = types.isObj(type) || array?
      if isObj && !array?
        @instantiateObject(type)

      @allocateLocal(type, value)
      if isObj
        logging.debug("Emitting AssignObject")
        @code.append(instructions.assignObject())
      return

    emitMinusAssign: =>
      @code.append(instructions.minusAssign())
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

    emitRegPushMemAddr: (offset) =>
      @code.append(instructions.regPushMemAddr(offset))
      return
    emitRegPushMem: (offset) =>
      @code.append(instructions.regPushMem(offset))
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

    emitAddNumber: =>
      @code.append(instructions.addNumber())
      return

    emitPreIncNumber: => @code.append(instructions.preIncNumber())

    emitPostIncNumber: => @code.append(instructions.postIncNumber())

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

    emitOpAtChuck: (isArray) =>
      logging.debug("Emitting AssignObject (isArray: #{isArray})")
      @code.append(instructions.assignObject(isArray))
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

    evaluateBreaks: =>
      while @_breakStack.length
        instr = @_breakStack.pop()
        instr.jmp = @_nextIndex()
      return

    finishScanning: =>
      locals = @code.finish()
      for local in locals
        @code.append(instructions.releaseObject2(local.offset))

      @code.append(instructions.eoc())
      return

    _emitPreConstructor: (type) =>
      if type.parent?
        @_emitPreConstructor(type.parent)

      if type.hasConstructor
        @code.append(instructions.preConstructor(type, @code.frame.currentOffset))

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
