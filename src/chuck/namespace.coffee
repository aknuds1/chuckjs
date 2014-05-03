define("chuck/namespace", ["chuck/logging"], (logging) ->
  module = {}

  module.Namespace = class Namespace
    constructor: (name, parent) ->
      @name = name
      @_scope = new Scope()
      @_types = new Scope()
      @_parent = parent

    addType: (type) =>
      @_types.addType(type)
      return

    findType: (name) =>
      type = @_types.findType(name)
      if type?
        return type

      return if @_parent then @_parent.findType(name) else undefined

    findValue: (name, climb = false) =>
      val = @_scope.findValue(name, climb)
      if val?
        return val
      if climb && @_parent?
        @_parent.findValue(name, climb)

    addVariable: (name, type, value, isGlobal) =>
      @_scope.addVariable(name, type, @, value, isGlobal)

    addConstant: (name, type, value, isGlobal) =>
      @_scope.addConstant(name, type, @, value, isGlobal)

    addValue: (value, name, isGlobal=true) =>
      @_scope.addValue(value, name, isGlobal)

    commit: =>
      for scope in [@_scope, @_types]
        scope.commit()
      return

    enterScope: =>
      logging.debug("Namespace entering nested scope")
      @_scope.push()
    exitScope: =>
      logging.debug("Namespace exiting nested scope")
      @_scope.pop()

  module.ChuckValue = class ChuckValue
    constructor: (@type, @name, @owner, @isContextGlobal, @value, @isConstant=false) ->

  class Scope
    constructor: ->
      @_scopes = []
      @_commitMap = {}
      @push()

    push: =>
      @_scopes.push({})

    pop: =>
      @_scopes.pop()

    findType: (name) =>
      i = @_scopes.length-1
      while i >= 0
        type = @_scopes[i][name]
        if type?
          return type
        --i

      return @_commitMap[name]

    addVariable: (name, type, namespace, value, isGlobal=true) =>
      chuckValue = new ChuckValue(type, name, namespace, isGlobal, value)
      logging.debug("Scope: Adding variable #{name} to scope #{@_scopes.length-1}")
      @addValue(chuckValue)
      return chuckValue

    addConstant: (name, type, namespace, value, isGlobal=true) =>
      chuckValue = new ChuckValue(type, name, namespace, isGlobal, value, true)
      logging.debug("Scope: Adding constant #{name} to scope #{@_scopes.length-1}")
      @addValue(chuckValue)
      return chuckValue

    findValue: (name, climb) =>
      if !climb
        lastScope = @_scopes[@_scopes.length-1]
        value = lastScope[name]
        if value?
          return value

        if lastScope == @_scopes[0] then @_commitMap[name] else null
      else
        for scope in @_scopes.reverse()
          value = scope[name]
          if value?
            return value

        @_commitMap[name]

    addType: (type) =>
      @addValue(type)

    commit: =>
      scope = @_scopes[0]
      for own k, v of @_commitMap
        scope[k] = v

      @_commitMap = []

    addValue: (value, name=null) =>
      name = if name? then name else value.name
      lastScope = @_scopes[@_scopes.length-1]
      if @_scopes[0] != lastScope
        lastScope[name] = value
      else
        @_commitMap[name] = value

  return module
)
