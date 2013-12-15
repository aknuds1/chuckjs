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

    findType: (name) =>
      i = @_scopes.length-1
      while i >= 0
        type = scopes[i][name]
        if type?
          break
        --i

      return @_commitMap[name]

    addVariable: (name, typeName, namespace) =>
      value = new ChuckValue(typeName, name, namespace)
      lastScope = scopes[scopes.length-1];
      if @_scopes[0] != lastScope
        lastScope[name] = value
      else
        @_commitMap[name] = value

      return value

  class Namespace
    constructor: ->
      @_scope = new Scope()

    findType: (name) =>
      type = @_type.findType(name)
      if type?
        return type

      return @_parent.findType(name) if @_parent else undefined

    addVariable: (name, typeName) =>
      return @_scope.addVariable(name, typeName, @)

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
      @_instructions = []
      @frame = new ChuckFrame()

      @pushScope()

    pushScope: =>
      @frame.stack.push(undefined)

    append: (instruction) =>
      @_instructions.push(instruction)

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

    findType: (typeName) =>
      type = @_currentNamespace.findType(typeName)
      return type

    addVariable: (name, typeName) =>
      return @_currentNamespace.addVariable(name, typeName)

    instantiateObject: (type) =>
      @code.append(new instructions.InstantiateObject(type))
      @_emitPreConstructor(type)

    allocateLocal: (type, value) =>
      local = @code.allocateLocal(type, value)
      @code.append(new instructions.AllocWord(local.offset))

    emitAssignment: (type, value) =>
      @instantiateObject(type)
      @allocateLocal(type, value)
      @code.append(new instructions.AssignObject())
      @code.append(new instructions.PopWord())

    emitSymbol: (name) =>
      @code.append(new instructions.Symbol(name))

    emitUGenLink: =>
      @code.append(new instructions.UGenLink())

    finishScanning: =>
      locals = code.finish()
      for local in locals
        @code.append(new instructions.ReleaseObject2(local.offset))

      @code.append(new instructions.Eoc())

    _emitPreconstructor: (type) =>
      if type.parent?
        @_emitPreconstructor(type.parent)

      if type.hasConstructor
        @code.append(new instructions.PreConstructor(type, @code.frame.currentOffset))

  class Scanner
    constructor: (ast) ->
      @_ast = ast
      @_byteCode = []
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

    _pass: (num) =>
      programs = @_ast
      for program in programs
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
