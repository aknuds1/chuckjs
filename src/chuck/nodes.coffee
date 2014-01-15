define("chuck/nodes", ["chuck/types", "chuck/logging", "chuck/audioContextService"],
(types, logging, audioContextService) ->
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
        return @_scanArray(@_child, pass, context)
      else
        return @_child["scanPass#{pass}"](context)

    _scanArray: (array, pass, context) =>
      for c in array
        if _(c).isArray()
          @_scanArray(c, pass, context)
        else
          c["scanPass#{pass}"](context)

  module.Program = class extends ParentNodeBase
    constructor: (child) ->
      super(child, "Program")

  module.ExpressionStatement = class extends ParentNodeBase
    constructor: (exp) ->
      super(exp)

    scanPass5: (context) =>
      @_child.scanPass5(context)
      if @_child.type? && @_child.type.size > 0
        logging.debug("ExpressionStatement: Emitting PopWord to remove superfluous return value")
        context.emitPopWord()
      else
        logging.debug("ExpressionStatement: Child expression has no return value")

  module.BinaryExpression = class extends NodeBase
    constructor: (exp1, operator, exp2) ->
      super("BinaryExpression")
      @exp1 = exp1
      @operator = operator
      @exp2 = exp2

    scanPass2: (context) =>
      @exp1.scanPass2(context)
      @exp2.scanPass2(context)
      return

    scanPass3: (context) =>
      @exp1.scanPass3(context)
      @exp2.scanPass3(context)
      return

    scanPass4: (context) =>
      @exp1.scanPass4(context)
      logging.debug("BinaryExpression: Type checked LHS, type #{@exp1.type.name}")
      @exp2.scanPass4(context)
      logging.debug("BinaryExpression: Type checked RHS, type #{@exp2.type.name}")
      @type = @operator.check(@exp1, @exp2, context)
      logging.debug("BinaryExpression: Type checked operator, type #{@type.name}")
      return

    scanPass5: (context) =>
      logging.debug("Binary expression: Emitting LHS")
      @exp1.scanPass5(context)
      logging.debug("Binary expression: Emitting RHS")
      @exp2.scanPass5(context)
      logging.debug("Binary expression: Emitting operator #{@operator.name}")
      @operator.emit(context, @exp1, @exp2)
      return

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
      logging.debug("Declaration of type #{@type.name}")
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
        logging.debug("DeclarationExpression emitting Assignment for value #{varDecl.value}")
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
          @type = types.Number
        else
          value = context.findValue(@name)
          @type = value.type
          logging.debug("Primary variable of type #{@type.name}")

    scanPass5: (context) =>
      super()
      switch @name
        when "dac"
          context.emitDac()
          break
        when "second"
          # Push the value corresponding to a second
          context.emitRegPushImm(audioContextService.getSampleRate())
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
      @value = parseFloat(value)
      @_meta = "value"

    scanPass4: =>
      super()
      @type = types.Number

    scanPass5: (context) =>
      super()
      context.emitRegPushImm(@value)

  module.PrimaryHackExpression = class extends ExpressionBase
    constructor: (expression) ->
      super("PrimaryHackExpression")
      @_meta = "value"
      @expression = expression

    scanPass4: (context) =>
      super(context)
      @expression.scanPass4(context)

    scanPass5: (context) =>
      super()
      @expression.scanPass5(context)
      context.emitGack([@expression.type])

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
      logging.debug('DurExpression')
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
    constructor: ->
      @name = "ChuckOperator"

    check: (lhs, rhs, context) =>
      if lhs.type == rhs.type
        if types.isPrimitive(lhs.type) || left.type == types.STRING
          return rhs.type
      if lhs.type == types.Dur && rhs.type == types.Time && rhs.name == "now"
        return rhs.type
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        return rhs.type
      if rhs.type.isOfType(types.Function)
        rhs.scanPass4(context)
        return rhs.type

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
      # Assignment
      else if lhs.type.isOfType(rhs.type)
        logging.debug("ChuckOperator emitting OpAtChuck to assign one object to another")
        return context.emitOpAtChuck()

      return

  module.PlusOperator = class
    constructor: ->
      @name = "PlusOperator"

    check: (lhs, rhs) =>
      if (lhs.type == types.Dur && rhs.type == types.Time)|| (lhs.type == types.Time && rhs.type == types.Dur)
        return types.Time

    emit: (context, lhs, rhs) =>
      logging.debug('PlusOperator emitting AddNumber')
      context.emitAddNumber()

  module.LtOperator = class
    constructor: ->
      @name = "LtOperator"

    check: (lhs, rhs) =>
      if lhs.type == types.Time && rhs.type == types.Time
        return types.Number

    emit: (context) =>
      logging.debug("LtOperator: Emitting")
      context.emitLtNumber()

  module.GtOperator = class
    constructor: ->
      @name = "GtOperator"

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
      logging.debug("WhileStatement: Type checking condition")
      @condition.scanPass4(context)
      logging.debug("WhileStatement: Body")
      @body.scanPass4(context)
      return

    scanPass5: (context) =>
      startIndex = context.getNextIndex()
      @condition.scanPass5(context)
      # Push break condition
      context.emitRegPushImm(false)
      logging.debug("WhileStatement: Emitting BranchEq")
      branchEq = context.emitBranchEq()
      @body.scanPass5(context)
      logging.debug("WhileStatement: Emitting GoTo (instruction number #{startIndex})")
      context.emitGoto(startIndex)
      context.evaluateBreaks()
      breakJmp = context.getNextIndex()
      logging.debug("WhileStatement: Configuring BranchEq instruction to jump to instruction number #{breakJmp}")
      branchEq.jmp = breakJmp
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
      logging.debug("DotMemberExpression, type: #{@type.name}")
      return

    scanPass5: (context) =>
      @base.scanPass5(context)
      context.emitRegDupLast()
      context.emitDotMemberFunc(@id)
      return

  return module
)
