# ChucK type library

class ChuckType
  constructor: (parent, hasConstructor=true, size=undefined) ->
    @parent = parent
    @hasConstructor = hasConstructor
    if size?
      @size = size
    else if parent?
      @size = parent.size

  isOfType: (otherType) =>
    if @ == otherType
      return true

    otherParent = other.parent
    while otherParent
      if @ == otherParent
        return true

      otherParent = otherParent.parent

    return @parent && @parent.isOfType(otherType)

ChuckObject = new ChuckType()
UGen = new ChuckType(ChuckObject, true, 8)
Osc = new ChuckType(UGen)
SinOsc = new ChuckType(Osc, false)
