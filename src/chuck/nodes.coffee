define("chuck/nodes", ["chuck/types", "chuck/logging"], (types, logging) ->
  module = {}

  class NodeBase
    constructor: (nodeType) ->
      @nodeType = nodeType

    scanPass1: =>

    scanPass2: =>

    scanPass3: =>

    scanPass4: =>

    scanPass5: =>

   class ParentNodeBase
    constructor: (child, nodeType) ->
      @_child = child
      @nodeType = nodeType

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
    constructor: (child) ->
      super(child, "Program")

  module.BinaryExpression = class extends NodeBase
    constructor: (exp1, operator, exp2) ->
      super("BinaryExpression")
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
      @operator.emit(context, @exp1, @exp2)
      #context.emitPopWord()

  class ExpressionBase extends NodeBase
    constructor: (nodeType) ->
      super(nodeType)

    scanPass4: =>
      @groupSize = 0
      ++@groupSize

  module.DeclarationExpression = class extends ExpressionBase
    constructor: (typeDecl, varDecls) ->
      super("DeclarationExpression")
      @typeDecl = typeDecl
      @varDecls = varDecls

    scanPass2: (context) =>
      @type = context.findType(@typeDecl.type)
      return undefined

    scanPass3: (context) =>
      for varDecl in @varDecls
        logging.debug("Adding variable '#{varDecl.name}' of type #{@type.name} to current namespace")
        varDecl.value = context.addVariable(varDecl.name, @type)
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
      super("TypeDeclaration")
      @type = type

  module.VariableDeclaration = class extends NodeBase
    constructor: (name) ->
      super("VariableDeclaration")
      @name = name

  module.PrimaryVariableExpression = class extends ExpressionBase
    constructor: (name) ->
      super("PrimaryVariableExpression")
      @name = name
      @_meta = "variable"

    scanPass4: (context) =>
      super()
      switch @name
        when "dac"
          @_meta = "value"
          @type = types.Dac
          break
        when "second"
          @type = types.Dur
          break
        when "now"
          @type = types.Time
          break
        when "true"
          @_meta = "value"
          @type = types.Int
        else
          value = context.findValue(@name)
          @type = value.type

    scanPass5: (context) =>
      super()
      switch @name
        when "dac"
          context.emitDac()
          break
        when "second"
          # Push the value corresponding to a second
          context.emitRegPushImm(1)
          break
        when "now"
          context.emitRegPushNow()
          break
        when "true"
          context.emitRegPushImm(1)
        else
          context.emitRegPushMem(0)

      return undefined

  module.PrimaryNumberExpression = class extends ExpressionBase
    constructor: (value) ->
      super("PrimaryNumberExpression")
      @value = value
      @_meta = "value"

    scanPass4: =>
      super()
      @type = types.Int

    scanPass5: (context) =>
      super()
      context.emitRegPushImm(@value)

  module.PrimaryHackExpression = class extends ExpressionBase
    constructor: (expression) ->
      super("PrimaryHackExpression")
      @_meta = "value"
      @expression = expression

    scanPass4: =>
      super()
      @expression.scanPass4()

    scanPass5: (context) =>
      super()
      @expression.scanPass5(context)
      types = [@expression.type]
      context.emitGack(types)

  module.PrimaryStringExpression= class extends ExpressionBase
    constructor: (value) ->
      super("PrimaryStringExpression")
      @_meta = "value"
      @value = value

    scanPass4: =>
      super()
      @type = types.String

    scanPass5: (context) =>
      super()
      context.emitRegPushImm(@value)

  module.DurExpression = class extends ExpressionBase
    constructor: (base, unit) ->
      super("DurExpression")
      @base = base
      @unit = unit

    scanPass2: =>
      super()
      @base.scanPass2()
      @unit.scanPass2()

    scanPass3: =>
      super()
      @base.scanPass3()
      @unit.scanPass3()

    scanPass4: =>
      super()
      @type = types.Dur
      @base.scanPass4()
      @unit.scanPass4()

    scanPass5: (context) =>
      super()
      @base.scanPass5(context)
      @unit.scanPass5(context)
      context.emitTimesNumber()

  module.VariableDeclaration = class extends NodeBase
    constructor: (name) ->
      super("VariableDeclaration")
      @name = name

  module.ChuckOperator = class
    check: (lhs, rhs) =>

    emit: (context, lhs, rhs) =>
      # UGen => UGen
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        context.emitUGenLink()
      # Time advance
      else if lhs.type.isOfType(types.Dur) && rhs.type.isOfType(types.Time)
        context.emitAddNumber()
        if rhs.name == "now"
          context.emitTimeAdvance()
      # Function call
      else if rhs.type.isOfType(types.Function)
        # FIXME
        context.emitRegPushImm(8)
        context.emitFuncCallMember()

  module.WhileStatement = class extends NodeBase
    constructor: (cond, body) ->
      super("WhileStatement")
      @condition = cond
      @body = body

    scanPass1: =>
      @condition.scanPass1()
      @body.scanPass1()
      return

    scanPass2: =>
      @condition.scanPass2()
      @body.scanPass2()
      return

    scanPass3: (context) =>
      @condition.scanPass3(context)
      @body.scanPass3(context)
      return

    scanPass4: (context) =>
      @condition.scanPass4(context)
      @body.scanPass4(context)
      return

    scanPass5: (context) =>
      startIndex = context.getNextIndex()
      @condition.scanPass5(context)
      # Push 0
      context.emitRegPushImm(0)
      context.emitBranchEq(0)
      @body.scanPass5(context)
      context.emitGoto(startIndex)
      context.evaluateBreaks()
      return

  module.CodeStatement = class extends ParentNodeBase
    constructor: (statementList) ->
      super(statementList, "CodeStatement")

  module.BreakStatement = class extends NodeBase
    constructor: ->
      super('BreakStatement')

    scanPass5: (context) ->
      context.emitBreak()
      return

  module.DotMemberExpression = class extends NodeBase
    constructor: (base, id) ->
      super("DotMemberExpression")
      @base = base
      @id = id

    scanPass2: =>
      @base.scanPass2()
      return

    scanPass3: =>
      @base.scanPass3()
      return

    scanPass4: (context) =>
      @base.scanPass4(context)
      @type = @base.type.findValue(@id).type
      return

    scanPass5: (context) =>
      @base.scanPass5(context)
      context.emitRegDupLast()
      context.emitDotMemberFunc(@id)
      return

  return module
)
