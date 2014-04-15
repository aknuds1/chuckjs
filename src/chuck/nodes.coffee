define("chuck/nodes", ["chuck/types", "chuck/logging", "chuck/audioContextService"],
(typesModule, logging, audioContextService) ->
  module = {}
  {types} = typesModule

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
      if !@_child
        return

      if _.isArray(@_child)
        return @_scanArray(@_child, pass, context)
      else
        return @_child["scanPass#{pass}"](context)

    _scanArray: (array, pass, context) =>
      for c in array
        if _.isArray(c)
          @_scanArray(c, pass, context)
        else
          c["scanPass#{pass}"](context)
      return

  module.Program = class extends ParentNodeBase
    constructor: (child) ->
      super(child, "Program")

  module.ExpressionStatement = class extends ParentNodeBase
    constructor: (exp) ->
      super(exp, "ExpressionStatement")

    scanPass5: (context, opts) =>
      opts = opts || {}
      shouldPop = if opts.pop? then opts.pop else true
      @_child.scanPass5(context)
      if @_child.type? && @_child.type.size > 0
        if shouldPop
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
      logging.debug("BinaryExpression #{@operator.name}: Type checked LHS, type #{@exp1.type.name}")
      @exp2.scanPass4(context)
      logging.debug("BinaryExpression #{@operator.name}: Type checked RHS, type #{@exp2.type.name}")
      @type = @operator.check(@exp1, @exp2, context)
      logging.debug("BinaryExpression #{@operator.name}: Type checked operator, type #{@type.name}")
      return

    scanPass5: (context) =>
      logging.debug("Binary expression #{@operator.name}: Emitting LHS")
      @exp1.scanPass5(context)
      logging.debug("Binary expression #{@operator.name}: Emitting RHS")
      @exp2.scanPass5(context)
      logging.debug("Binary expression #{@operator.name}: Emitting operator")
      @operator.emit(context, @exp1, @exp2)
      return

  class ExpressionBase extends NodeBase
    constructor: (nodeType, meta) ->
      super(nodeType)
      @_meta = meta

    scanPass4: =>
      @groupSize = 0
      ++@groupSize

  module.ExpressionList = class ExpressionList extends ExpressionBase
    constructor: (expression) ->
      super("ExpressionList")
      @_expressions = [expression]

    prepend: (expression) =>
      @_expressions.splice(0, 0, expression)
      @

    _scanPass: (pass) =>
      for exp in @_expressions
        exp["scanPass#{pass}"].apply(exp, Array.prototype.slice.call(arguments, 1))
      return

    scanPass1: _.partial(@prototype._scanPass, 1)
    scanPass2: _.partial(@prototype._scanPass, 2)
    scanPass3: _.partial(@prototype._scanPass, 3)
    scanPass4: _.partial(@prototype._scanPass, 4)

    scanPass5: (context) =>
      @_scanPass(5, context)
      @types = (exp.type for exp in @_expressions)
      @type = @types[0]

  module.DeclarationExpression = class extends ExpressionBase
    constructor: (typeDecl, varDecls) ->
      super("DeclarationExpression")
      @typeDecl = typeDecl
      @varDecls = varDecls

    scanPass2: (context) =>
      @type = context.findType(@typeDecl.type)
      logging.debug("Variable declaration of type #{@type.name}")
      return undefined

    scanPass3: (context) =>
      for varDecl in @varDecls
        logging.debug("Adding variable '#{varDecl.name}' of type #{@type.name} to current namespace")
        varDecl.value = context.addVariable(varDecl.name, @type)
      return undefined

    scanPass4: (context) =>
      super()
      for varDecl in @varDecls
        logging.debug("#{@nodeType} Checking variable #{varDecl.name}")
        varDecl.value.isDeclChecked = true
        context.addValue(varDecl.value)
      return

    scanPass5: (context) =>
      super()
      for varDecl in @varDecls
        if varDecl.array?
          logging.debug("#{@nodeType}: Instantiating array", varDecl)
        else
          logging.debug("#{@nodeType}: Emitting Assignment for value #{varDecl.value}")
      context.emitAssignment(@type, varDecl)

      return

  module.TypeDeclaration = class extends NodeBase
    constructor: (type) ->
      super("TypeDeclaration")
      @type = type

  module.VariableDeclaration = class extends NodeBase
    constructor: (name, array) ->
      super("VariableDeclaration")
      @name = name
      @array = array

  module.PrimaryVariableExpression = class extends ExpressionBase
    constructor: (name) ->
      super("PrimaryVariableExpression", "variable")
      @name = name
      @_emitVar = false

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
        when "ms"
          @type = types.Dur
          break
        when "samp"
          @type = types.Dur
          break
        when "hour"
          @type = types.Dur
          break
        when "now"
          @type = types.Time
          break
        when "true"
          @_meta = "value"
          @type = types.int
        else
          @value = context.findValue(@name)
          if !@value?
            context.findValue(@name, true)
          @type = @value.type
          logging.debug("Primary variable of type #{@type.name}")
          @type

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
        when "ms"
          # Push the value corresponding to a millisecond
          context.emitRegPushImm(audioContextService.getSampleRate()/1000)
          break
        when "samp"
          # Push the value corresponding to a sample
          context.emitRegPushImm(1)
          break
        when "hour"
          # Push the value corresponding to an hour
          context.emitRegPushImm(audioContextService.getSampleRate()*60*60)
          break
        when "now"
          context.emitRegPushNow()
          break
        when "true"
          context.emitRegPushImm(1)
        else
          # Emit symbol
          if @_emitVar
            logging.debug("#{@nodeType}: Emitting RegPushMemAddr (#{@value.offset}) since this is a variable")
            context.emitRegPushMemAddr(@value.offset)
          else
            logging.debug("#{@nodeType}: Emitting RegPushMem (#{@value.offset}) since this is a constant")
            context.emitRegPushMem(@value.offset)

      return undefined

  module.PrimaryIntExpression = class extends ExpressionBase
    constructor: (value) ->
      super("PrimaryIntExpression", "value")
      @value = parseInt(value)

    scanPass4: =>
      super()
      @type = types.int

    scanPass5: (context) =>
      super()
      logging.debug("#{@nodeType}: Emitting RegPushImm(#{@value})")
      context.emitRegPushImm(@value)

  module.PrimaryFloatExpression = class extends ExpressionBase
    constructor: (value) ->
      super("PrimaryFloatExpression", "value")
      @value = parseFloat(value)

    scanPass4: =>
      super()
      @type = types.float

    scanPass5: (context) =>
      super()
      context.emitRegPushImm(@value)

  module.PrimaryHackExpression = class extends ExpressionBase
    constructor: (expression) ->
      super("PrimaryHackExpression", "value")
      @expression = expression

    scanPass4: (context) =>
      super(context)
      logging.debug("#{@nodeType} scanPass4: Checking child expression")
      @expression.scanPass4(context)
      return

    scanPass5: (context) =>
      super()
      logging.debug("#{@nodeType}: Emitting child expression")
      @expression.scanPass5(context)
      logging.debug("#{@nodeType}: Emitting Gack, types:", (t.name for t in @expression.types))
      context.emitGack(@expression.types)
      return

  module.PrimaryStringExpression= class extends ExpressionBase
    constructor: (value) ->
      super("PrimaryStringExpression", "value")
      @value = value

    scanPass4: =>
      super()
      @type = types.String

    scanPass5: (context) =>
      super()
      context.emitRegPushImm(@value)

  module.PrimaryArrayExpression = class extends ExpressionBase
    constructor: (base, indices) ->
      super("PrimaryArrayExpression", "variable")
      @base = base
      @indices = indices

    scanPass1: =>
      super()
      @base.scanPass1()
      @indices.scanPass1()

    scanPass2: =>
      super()
      @base.scanPass2()
      @indices.scanPass2()

    scanPass3: =>
      super()
      @base.scanPass3()
      @indices.scanPass3()

    scanPass4: (context) =>
      super(context)
      logging.debug("#{@nodeType} scanPass4: Base")
      baseType = @base.scanPass4(context)
      logging.debug("#{@nodeType} scanPass4: Indices")
      @indices.scanPass4(context)
      logging.debug("#{@nodeType} scanPass4: Type determined to be #{baseType.name}")
      @type = baseType

    scanPass5: (context) =>
      logging.debug("#{@nodeType} emitting")
      super(context)
      @base.scanPass5(context)
      @indices.scanPass5(context)
      logging.debug("#{@nodeType}: Emitting ArrayAccess (as variable: #{@_emitVar})")
      context.emitArrayAccess(@type, @_emitVar)

  module.FuncCallExpression = class extends ExpressionBase
    constructor: (base, args) ->
      super("FuncCallExpression")
      @func = base
      @args = args

    scanPass1: =>
      super()
      @func.scanPass1()
      if @args?
        @args.scanPass1()

    scanPass2: =>
      super()
      @func.scanPass2()
      if @args?
        @args.scanPass2()

    scanPass3: =>
      super()
      @func.scanPass3()
      if @args?
        @args.scanPass3()

    scanPass4: (context) =>
      super(context)
      logging.debug("#{@nodeType} scanPass4: Checking type of @func")
      @func.scanPass4(context)
      if @args?
        @args.scanPass4(context)
      # Find method overload
      funcGroup = @func.value.value
      @_ckFunc = funcGroup.findOverload(if @args? then @args._expressions else null)
      @type = funcGroup.retType
      logging.debug("#{@nodeType} scanPass4: Got function overload #{@_ckFunc.name} with return type
 #{@type.name}")
      @type

    scanPass5: (context) =>
      logging.debug("#{@nodeType} scanPass5")
      super(context)
      if @args?
        logging.debug("#{@nodeType}: Emitting arguments")
        @args.scanPass5(context)

      if @_ckFunc.isMember
        logging.debug("#{@nodeType}: Emitting method instance")
        @func.scanPass5(context)
        logging.debug("#{@nodeType}: Emitting duplication of 'this' reference on stack")
        context.emitRegDupLast()

      logging.debug("#{@nodeType}: Emitting function #{@_ckFunc.name}")
      if @_ckFunc.isMember
        context.emitDotMemberFunc(@_ckFunc)
      else
        context.emitDotStaticFunc(@_ckFunc)

      # TODO: Calculate current frame offset
      context.emitRegPushImm(0)
      if @_ckFunc.isMember
        logging.debug("#{@nodeType}: Emitting instance method call")
        context.emitFuncCallMember()
      else
        logging.debug("#{@nodeType}: Emitting static method call")
        context.emitFuncCallStatic()

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

  module.UnaryExpression = class extends ExpressionBase
    constructor: (operator, exp) ->
      @op = operator
      @exp = exp

    scanPass4: (context) =>
      if @exp?
        @exp.scanPass4(context)
      @type = @op.check(@exp)

    scanPass5: (context) =>
      logging.debug("UnaryExpression: Emitting expression")
      @exp.scanPass5(context)
      logging.debug("UnaryExpression: Emitting operator")
      @op.emit(context)
      return

  module.ChuckOperator = class
    constructor: ->
      @name = "ChuckOperator"

    check: (lhs, rhs, context) =>
      if lhs.type == rhs.type
        if typesModule.isPrimitive(lhs.type) || lhs.type == types.String
          if rhs._meta == "variable"
            # Assign to variable
            rhs._emitVar = true
          return rhs.type
      if lhs.type == types.Dur && rhs.type == types.Time && rhs.name == "now"
        return rhs.type
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        return rhs.type
      if rhs.type.isOfType(types.Function)
        rhs.scanPass4(context)
        # Find method overload
        funcGroup = rhs.value.value
        # TODO: Make lhs into an ExpressionList
        rhs._ckFunc = funcGroup.findOverload([lhs])
        @type = funcGroup.retType
        logging.debug("#{@name} check: Got function overload #{rhs._ckFunc.name} with return type #{@type.name}")
        return @type
      if lhs.type == types.int && rhs.type == types.float
        lhs.castTo = rhs.type
        return types.float

    emit: (context, lhs, rhs) =>
      logging.debug("#{@name} scanPass5")
      lType = if lhs.castTo? then lhs.castTo else lhs.type
      rType = if rhs.castTo? then rhs.castTo else rhs.type
      # UGen => UGen
      if lType.isOfType(types.UGen) && rType.isOfType(types.UGen)
        context.emitUGenLink()
      # Time advance
      else if lType.isOfType(types.Dur) && rType.isOfType(types.Time)
        context.emitAddNumber()
        if rhs.name == "now"
          context.emitTimeAdvance()
      # Function call
      else if rType.isOfType(types.Function)
        if rhs._ckFunc.isMember
          logging.debug("#{@name}: Emitting duplication of 'this' reference on stack")
          context.emitRegDupLast()
          logging.debug("#{@nodeType}: Emitting instance method #{rhs._ckFunc.name}")
          context.emitDotMemberFunc(rhs._ckFunc)
          logging.debug("#{@nodeType} emitting instance method call")
        else
          logging.debug("#{@nodeType}: Emitting static method #{rhs._ckFunc.name}")
          context.emitDotStaticFunc(rhs._ckFunc)
          logging.debug("#{@nodeType} emitting static method call")
        # FIXME
        context.emitRegPushImm(8)
        if rhs._ckFunc.isMember
          context.emitFuncCallMember()
        else
          context.emitFuncCallStatic()
      # Assignment
      else if lType.isOfType(rType)
        isArray = rhs.indices?
        if !isArray
          logging.debug("ChuckOperator emitting OpAtChuck to assign one object to another")
        else
          logging.debug("ChuckOperator emitting OpAtChuck to assign an object to an array element")
        return context.emitOpAtChuck(isArray)

      return

  module.UnchuckOperator = class
    constructor: ->
      @name = "UnchuckOperator"

    check: (lhs, rhs, context) =>
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        return rhs.type

    emit: (context, lhs, rhs) =>
      # UGen => UGen
      if lhs.type.isOfType(types.UGen) && rhs.type.isOfType(types.UGen)
        context.emitUGenUnlink()

      return

  module.MinusChuckOperator = class
    constructor: ->
      @name = "MinusChuckOperator"

    check: (lhs, rhs, context) =>
      if lhs.type == rhs.type
        if typesModule.isPrimitive(lhs.type) || lhs.type == types.String
          if rhs._meta == "variable"
            # Assign to variable
            rhs._emitVar = true
          return rhs.type

    emit: (context, lhs, rhs) =>
      return context.emitMinusAssign()

  class AdditiveSubtractiveOperatorBase
    check: (lhs, rhs) =>
      if lhs.type == rhs.type
        return lhs.type
      if (lhs.type == types.Dur && rhs.type == types.Time) || (lhs.type == types.Time && rhs.type == types.Dur)
        return types.Time
      if lhs.type == types.int && rhs.type == types.int
        return types.int
      if (lhs.type == types.float && rhs.type == types.float) || (lhs.type == types.int && rhs.type == types.float) ||
      (lhs.type == types.float && rhs.type == types.int)
        return types.float

  module.PlusOperator = class extends AdditiveSubtractiveOperatorBase
    constructor: ->
      @name = "PlusOperator"

    emit: (context, lhs, rhs) =>
      logging.debug('PlusOperator emitting AddNumber')
      context.emitAddNumber()

  PlusPlusOperatorBase = class
    constructor: (name) ->
      @name = name

    check: (exp) =>
      exp._emitVar = true
      type = exp.type
      if type == types.int || type == types.float
        type
      else
        null

  module.PrefixPlusPlusOperator = class extends PlusPlusOperatorBase
    constructor: ->
      super("PrefixPlusPlusOperator")

    emit: (context) =>
      logging.debug("#{@name} emitting PreIncNumber")
      context.emitPreIncNumber()

  module.PostfixPlusPlusOperator = class extends PlusPlusOperatorBase
    constructor: ->
      super("PostfixPlusPlusOperator")

    emit: (context) =>
      logging.debug("#{@name} emitting PostIncNumber")
      context.emitPostIncNumber()

  module.MinusOperator = class extends AdditiveSubtractiveOperatorBase
    constructor: ->
      @name = "MinusOperator"

    emit: (context, lhs, rhs) =>
      logging.debug("#{@name} emitting SubtractNumber")
      context.emitSubtractNumber()

  module.MinusMinusOperator = class
    constructor: ->
      @name = "MinusMinusOperator"

  module.TimesOperator = class TimesOperator
    constructor: -> @name = "TimesOperator"

    check: (lhs, rhs, context) =>
      if lhs.type == types.float && rhs.type == types.float
        types.float

    emit: (context) =>
      context.emitTimesNumber()

  class GtLtOperatorBase
    check: (lhs, rhs) =>
      if lhs.type == rhs.type
        return lhs.type
      if lhs.type == types.Time && rhs.type == types.Time
        return types.int

  module.LtOperator = class extends GtLtOperatorBase
    constructor: ->
      @name = "LtOperator"

    emit: (context) =>
      logging.debug("#{@name}: Emitting")
      context.emitLtNumber()

  module.GtOperator = class extends GtLtOperatorBase
    constructor: ->
      @name = "GtOperator"

    emit: (context) =>
      logging.debug("#{@name}: Emitting")
      context.emitGtNumber()

  module.WhileStatement = class extends NodeBase
    constructor: (cond, body) ->
      super("WhileStatement")
      @condition = cond
      @body = body

    scanPass1: =>
      @condition.scanPass1()
      @body.scanPass1()
      return

    scanPass2: (context) =>
      @condition.scanPass2(context)
      @body.scanPass2(context)
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

  module.ForStatement = class extends NodeBase
    constructor: (c1, c2, c3, body) ->
      super("ForStatement")
      @c1 = c1
      @c2 = c2
      @c3 = c3
      @body = body

    scanPass2: (context) =>
      @c1.scanPass2(context)
      @c2.scanPass2(context)
      if @c3?
        @c3.scanPass2(context)
      @body.scanPass2(context)
      return

    scanPass3: (context) =>
      logging.debug("#{@nodeType}")
      context.enterScope()
      @c1.scanPass3(context)
      @c2.scanPass3(context)
      if @c3?
        @c3.scanPass3(context)
      @body.scanPass3(context)
      context.exitScope()
      return

    scanPass4: (context) =>
      logging.debug("#{@nodeType}")
      context.enterScope()
      logging.debug("#{@nodeType}: Checking the initial")
      @c1.scanPass4(context)
      logging.debug("#{@nodeType}: Checking the condition")
      @c2.scanPass4(context)
      if @c3?
        logging.debug("#{@nodeType}: Checking the post")
        @c3.scanPass4(context)
      logging.debug("#{@nodeType}: Checking the body")
      @body.scanPass4(context)
      context.exitScope()
      return

    scanPass5: (context) =>
      context.emitScopeEntrance()
      logging.debug("#{@nodeType}: Emitting the initial")
      @c1.scanPass5(context)
      startIndex = context.getNextIndex()
      # The condition
      logging.debug("#{@nodeType}: Emitting the condition")
      @c2.scanPass5(context, pop: false)
      context.emitRegPushImm(false)
      logging.debug("#{@nodeType}: Emitting BranchEq")
      branchEq = context.emitBranchEq()
      # The body
      context.emitScopeEntrance()
      logging.debug("#{@nodeType}: Emitting the body")
      @body.scanPass5(context)
      context.emitScopeExit()

      if @c3?
        logging.debug("#{@nodeType}: Emitting the post")
        @c3.scanPass5(context)
        context.emitPopWord()

      logging.debug("ForStatement: Emitting GoTo (instruction number #{startIndex})")
      context.emitGoto(startIndex)
      if @c2?
        breakJmp = context.getNextIndex()
        logging.debug("ForStatement: Configuring BranchEq instruction to jump to instruction number #{breakJmp}")
        branchEq.jmp = breakJmp

      context.evaluateBreaks()

      context.emitScopeExit()

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
      logging.debug("#{@nodeType} scanPass4")
      @base.scanPass4(context)
      @isStatic = @base.type.actualType?
      if @isStatic
        logging.debug("#{@nodeType} scanPass4: This is a static member expression")
      baseType = if @isStatic then @base.type.actualType else @base.type
      logging.debug("#{@nodeType} scanPass4: Finding member '#{@id}' in base type #{baseType.name}")
      @value = baseType.findValue(@id)
      @type = @value.type
      logging.debug("#{@nodeType} scanPass4: Member type is #{@type.name}")
      @type

    scanPass5: (context) =>
      logging.debug("#{@nodeType} scanPass5")
      if !@isStatic
        logging.debug("#{@nodeType} scanPass5: Emitting base expression")
        @base.scanPass5(context)
      return

  module.PostfixExpression = class extends NodeBase
    constructor: (base, operator) ->
      super("PostfixExpression", "variable")
      @exp = base
      @op = operator

    scanPass4: (context) =>
      @exp.scanPass4(context)
      @type = @op.check(@exp)

    scanPass5: (context) =>
      @exp.scanPass5(context)
      @op.emit(context)

  module.ArraySub = class extends NodeBase
    constructor: (exp) ->
      super("ArraySub")
      @exp = exp

    scanPass4: (context) =>
      logging.debug("#{@nodeType} scanPass4")
      @exp.scanPass4(context)

    scanPass5: (context) =>
      logging.debug("#{@nodeType}: Emitting array indices")
      @exp.scanPass5(context)

  return module
)
