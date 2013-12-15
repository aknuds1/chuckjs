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
      @exp1.scanPass5(context)
      @exp2.scanPass5(context)
      @operator.emit()

  class ExpressionBase extends NodeBase
    scanPass4: =>
      @groupSize = 0
      ++@groupSize

  module.DeclarationExpression = class extends ExpressionBase
    constructor: (typeDecl, varDecl) ->
      @typeDecl = typeDecl
      @varDecl = varDecl

    scanPass3: (context) =>
      for varName in @varDecl
        varDecl.value = context.addVariable(varName, @typeDecl.type)

    scanPass4: =>
      super()
      @varDecl.value.isDeclChecked = true
      @type = varDecl.value.type

    scanPass5: (context) =>
      super()
      context.emitAssignment(@type, @varDecl.value)

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
      switch name
        when "dac"
          @_meta = "value"
          @type = types.UGen
          break

    scanPass5: (context) =>
      super()
      switch name
        when "dac"
          context.emitSymbol(name)
          break

  module.ChuckOperator = class
    check: (lhs, rhs) =>

    emit: (lhs, rhs) =>
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        context.emitUGenLink()

  return module
)
