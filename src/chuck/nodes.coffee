define("chuck/nodes", ["chuck/types"], (types) ->
  module = {}

  class NodeBase
    scanPass1: =>

    scanPass2: =>

    scanPass3: =>

    scanPass4: =>

    scanPass5: =>

   class ParentNodeBase
    constructor: (child) ->
      @_child = child

    scanPass1: (context) =>
      @_scanPass(1, context)

    scanPass2: (context) =>
        @_scanPass(2, context)

    scanPass3: (context) =>
      @_scanPass(3, context)

    scanPass4: (context) =>
      @_scanPass(4, context)

    scanPass5: (context) =>
      @_scanPass(5, context)

    _scanPass: (pass, context) =>
      if _(@_child).isArray()
        @_scanArray(@_child, pass, context)
      else
        @_child["scanPass#{pass}"](context)

    _scanArray: (array, pass, context) =>
      for c in array
        if _(c).isArray()
          @_scanArray(c, pass, context)
        else
          c["scanPass#{pass}"](context)

  module.Program = class extends ParentNodeBase

  module.BinaryExpression = class extends NodeBase
    constructor: (exp1, operator, exp2) ->
      @exp1 = exp1
      @operator = operator
      @exp2 = exp2

    scanPass2: (context) =>
      @exp1.scanPass2(context)
      @exp2.scanPass2(context)

    scanPass3: (context) =>
      @exp1.scanPass3(context)
      @exp2.scanPass3(context)

    scanPass4: (context) =>
      @exp1.scanPass4(context)
      @exp2.scanPass4(context)
      @operator.check()

    scanPass5: (context) =>
      debugger
      @exp1.scanPass5(context)
      @exp2.scanPass5(context)
      @operator.emit(context, @exp1, @exp2)

  class ExpressionBase extends NodeBase
    scanPass4: =>
      @groupSize = 0
      ++@groupSize

  module.DeclarationExpression = class extends ExpressionBase
    constructor: (typeDecl, varDecls) ->
      @typeDecl = typeDecl
      @varDecls = varDecls

    scanPass2: (context) =>
      @type = context.findType(@typeDecl.type)
      return undefined

    scanPass3: (context) =>
      for varDecl in @varDecls
        varDecl.value = context.addVariable(varDecl.name, @type.name)
      return undefined

    scanPass4: =>
      super()
      for varDecl in @varDecls
        varDecl.value.isDeclChecked = true
      return undefined

    scanPass5: (context) =>
      super()
      for varDecl in @varDecls
        context.emitAssignment(@type, varDecl.value)
      return undefined

  module.TypeDeclaration = class extends NodeBase
    constructor: (type) ->
      @type = type

  module.VariableDeclaration = class extends NodeBase
    constructor: (name) ->
      @name = name

  module.PrimaryExpression = class extends ExpressionBase
    constructor: (name) ->
      @name = name

    scanPass4: =>
      super()
      switch @name
        when "dac"
          @_meta = "value"
          @type = types.UGen
          break

    scanPass5: (context) =>
      super()
      switch @name
        when "dac"
          context.emitSymbol(name)
          break

  module.VariableDeclaration = class extends NodeBase
    constructor: (name) ->
      @name = name

  module.ChuckOperator = class
    check: (lhs, rhs) =>

    emit: (context, lhs, rhs) =>
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        context.emitUGenLink()

  return module
)
