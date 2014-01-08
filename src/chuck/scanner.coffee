define("chuck/scanner", ["chuck/nodes", "chuck/types", "chuck/instructions", "chuck/namespace"],
(nodes, types, instructions, namespaceModule) ->
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
      @frame.stack.push(undefined)

    append: (instruction) =>
      @instructions.push(instruction)

    allocateLocal: (type, value) =>
      local = new ChuckLocal(type.size, @frame.currentOffset, value.name)
      @frame.currentOffset += local.size
      @frame.stack.push(local)
      value.offset = local.offset
      return local

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

  class ScanningContext
    constructor: ->
      @code = new ChuckCode()
      @_globalNamespace = new namespaceModule.Namespace("global")
      for own k, type of types
        @_globalNamespace.addType(type)
      @_globalNamespace.commit()
      @_namespaceStack = [@_globalNamespace]
      @_currentNamespace = @_globalNamespace
      @_breakStack = []
      @_contStack = []

    findType: (typeName) =>
      type = @_currentNamespace.findType(typeName)
      return type

    findValue: (name) =>
      return @_currentNamespace.findValue(name)

    addVariable: (name, typeName) =>
      return @_currentNamespace.addVariable(name, typeName)

    pushToBreakStack: (statement) =>
      @_breakStack.push(statement)

    pushToContStack: (statement) =>
      @_contStack.push(statement)

    instantiateObject: (type) =>
      @code.append(instructions.instantiateObject(type))
      @_emitPreConstructor(type)

    allocateLocal: (type, value) =>
      local = @code.allocateLocal(type, value)
      @code.append(instructions.allocWord(local.offset))

    getNextIndex: =>
      # TODO
      return 0

    emitAssignment: (type, value) =>
      @instantiateObject(type)
      @allocateLocal(type, value)
      @code.append(instructions.assignObject())

    emitDac: =>
      @code.append(instructions.dac())

    emitUGenLink: =>
      @code.append(instructions.uGenLink())

    emitPopWord: =>
      @code.append(instructions.popWord())

    emitRegPushImm: (value) =>
      @code.append(instructions.regPushImm(value))
      return

    emitFuncCallMember: =>
      @code.append(instructions.funcCallMember())
      return

    emitRegPushMem: (offset) =>
      @code.append(instructions.regPushMem(offset))
      return

    emitRegDupLast: =>
      @code.append(instructions.regDupLast())
      return

    emitDotMemberFunc: (id) =>
      @code.append(instructions.dotMemberFunc(id))
      return

    emitTimesNumber: =>
      @code.append(instructions.timesNumber())

    emitRegPushNow: =>
      @code.append(instructions.regPushNow())

    emitAddNumber: =>
      @code.append(instructions.addNumber())
      return

    emitTimeAdvance: =>
      @code.append(instructions.timeAdvance())
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
    scanner.pass1()
    scanner.pass2()
    scanner.pass3()
    scanner.pass4()
    scanner.pass5()

    return scanner.byteCode

  return module
)
