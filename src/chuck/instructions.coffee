define("chuck/instructions", [], ->
  module = {}

  module.InstantiateObject = class
    constructor: (type) ->
      @type = type

  module.AllocWord = class
    constructor: (offset) ->
      @offset = offset

  module.PreConstructor = class
    constructor: (type, offset) ->
      @type = type
      @offset = offset

  module.AssignObject = class

  module.Symbol = class
    constructor: (name) ->
      @name = name

  module.ReleaseObject2 = class
    constructor: (offset) ->
      @offset = offset

  module.Eoc = class

  return module
)

