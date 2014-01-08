define("chuck/namespace", [], ->
  module = {}

  module.Namespace = class
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

    findValue: (name) =>
      return @_scope.findValue(name)

    addVariable: (name, type, value) =>
      return @_scope.addVariable(name, type, @, value)

    commit: =>
      for scope in [@_scope, @_types]
        scope.commit()

  class ChuckValue
    constructor: (type, varName, namespace, isContextGlobal, value) ->
      @type = type
      @name = varName
      @owner = namespace
      @isContextGlobal = isContextGlobal
      @value = value

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

    addVariable: (name, type, namespace, value) =>
      chuckValue = new ChuckValue(type, name, namespace, undefined, value)

      @_addValue(chuckValue)
      return chuckValue

    findValue: (name) =>
      value = @_scopes[0][name]
      if value?
        return value
      return @_commitMap[name]

    addType: (type) =>
      @_addValue(type)

    commit: =>
      scope = @_scopes[0]
      for own k, v of @_commitMap
        scope[k] = v

      @_commitMap = []

    _addValue: (value) =>
      name = value.name
      lastScope = @_scopes[@_scopes.length-1]
      if @_scopes[0] != lastScope
        lastScope[name] = value
      else
        @_commitMap[name] = value

  return module
)
