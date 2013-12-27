define("chuck/scanner", ["chuck/nodes", "chuck/types", "chuck/instructions"], (nodes, types, instructions) ->
  module = {}

  class ChuckValue
    constructor: (typeName, varName, namespace, isContextGlobal) ->
      @type = typeName
      @name = varName
      @owner = namespace
      @isContextGlobal = isContextGlobal

  class Scope
    constructor: ->
      @_scopes = []
      @_commitMap = {}
      @push()

    push: =>
      @_scopes.push({})

    findType: (name) =>
      i = @_scopes.length-1
      while i >= 0
        type = @_scopes[i][name]
        if type?
          return type
        --i

      return @_commitMap[name]

    addVariable: (name, typeName, namespace) =>
      value = new ChuckValue(typeName, name, namespace)

      @_addValue(value)
      return value

    addType: (type) =>
      @_addValue(type)

    commit: =>
      scope = @_scopes[0]
      for own k, v of @_commitMap
        scope[k] = v

      @_commitMap = []

    _addValue: (value) =>
      name = value.name
      lastScope = @_scopes[@_scopes.length-1];
      if @_scopes[0] != lastScope
        lastScope[name] = value
      else
        @_commitMap[name] = value

  class Namespace
    constructor: (name) ->
      @name = name
      @_scope = new Scope()
      @_types = new Scope()

    addType: (type) =>
      @_types.addType(type)

    findType: (name) =>
      type = @_types.findType(name)
      if type?
        return type

      return if @_parent then @_parent.findType(name) else undefined

    addVariable: (name, typeName) =>
      return @_scope.addVariable(name, typeName, @)

    commit: =>
      for scope in [@_scope, @_types]
        scope.commit()

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
      @_globalNamespace = new Namespace("global")
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

    emitTimesNumber: =>
      @code.append(instructions.timesNumber())

    emitRegPushNow: =>
      @code.append(instructions.regPushNow())

    emitAddNumber: =>
      @code.append(instructions.addNumber())

    emitTimeAdvance: =>
      @code.append(instructions.timeAdvance())

    emitGack: (types) =>
      @code.append(instructions.gack(types))

    emitBranchEq: (jmp) =>
      @code.append(instructions.branchEq(jmp))

    emitGoto: (jmp) =>
      @code.append(instructions.goto(jmp))

    finishScanning: =>
      locals = @code.finish()
      for local in locals
        @code.append(instructions.releaseObject2(local.offset))

      @code.append(instructions.eoc())

    _emitPreConstructor: (type) =>
      if type.parent?
        @_emitPreConstructor(type.parent)

      if type.hasConstructor
        @code.append(instructions.preConstructor(type, @code.frame.currentOffset))

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
