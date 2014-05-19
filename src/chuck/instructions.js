define("chuck/instructions", ["chuck/ugen", "chuck/logging", "chuck/types"], function (ugen, logging, typesModule) {
  var module = {}
  var types = typesModule.types

  var logDebug = function () {
    logging.debug.apply(null, arguments)
  }

  function callFunction(vm, func, ri, riRet) {
    var stackDepth = func.stackDepth
    logDebug("Calling function", func)
    logDebug("Passing registers " + ri + " to " + (ri + stackDepth - 1) + " as arguments")
    var args = vm.registers.slice(ri, ri+stackDepth)
    var thisObj = undefined
    if (func.isMember) {
      logDebug("Function is a method, passing 'this' to it")
      thisObj = args.shift()
    }
    var retVal = func.apply(thisObj, args)
    if (func.retType != types.void) {
      logDebug("Assigning return value to register " + riRet + ":", retVal)
      vm.registers[riRet] = retVal
    }
  }

  function Instruction(name, params, execute) {
    var self = this
    self.instructionName = name
    _.extend(self, params)
    self._executeCb = execute
  }
  Instruction.prototype.execute = function (vm) {
    var self = this
    if (!self._executeCb) {
      return
    }
    self._executeCb.call(self, vm)
  }
  module.Instruction = Instruction

  function instantiateObject(type, vm) {
    logDebug("Instantiating object of type " + type.name)
    var ug = type.ugenNumOuts == 1 ? new ugen.MonoUGen(type) : new ugen.MultiChannelUGen(type)
    vm.addUgen(ug)
    return ug
  }
  module.instantiateObject = function (type, ri) {
    return new Instruction("InstantiateObject", { type: type }, function (vm) {
      var ug = instantiateObject(type, vm)
      vm.registers[ri] = ug
    })
  }

  module.preConstructor = function (type, ri) {
    return new Instruction("PreConstructor", {type: type}, function (vm) {
      // Duplicate top of stack, which should be object pointer
      logDebug("Calling pre-constructor of " + this.type.name)
//       Signal that this function needs a 'this' reference
      this.type.preConstructor.isMember = true
      this.type.preConstructor.stackDepth = 1
      this.type.preConstructor.retType = types.void

      callFunction(vm, this.type.preConstructor, ri)
    })
  }

  module.assignObject = function (isArray, isGlobal, r1, r2) {
    if (isGlobal == null) {isGlobal = true}
    return new Instruction("AssignObject", {}, function (vm) {
      var scopeStr = isGlobal ? "global" : "function"
      var tgtRegisters = isGlobal ? vm.globalRegisters : vm.registers
      var obj = vm.registers[r1]
      if (!isArray) {
        logDebug(this.instructionName + ": Assigning object to register " + r2 + " (scope: " + scopeStr + "):", obj)
        tgtRegisters[r2] = obj
      }
      else {
        var array = vm.registers[r2][0]
        var index = vm.registers[r2][1]
        logDebug("#{@instructionName}: Assigning object to array, index #{index} (scope: #{scopeStr}):", obj)
        array[index] = obj
      }
    })
  }

  module.plusAssign = function (r1, r2, r3) {
    return new Instruction("PlusAssign", {}, function (vm) {
      var lhs = vm.registers[r1]
      var rhs = vm.registers[r2]
      var result = lhs + rhs
      vm.registers[r3] = result
    })
  }
  module.minusAssign = function (r1, r2, r3) {
    return new Instruction("MinusAssign", {}, function (vm) {
      var lhs = vm.registers[r1]
      var rhs = vm.registers[r2]
      var result = lhs - rhs
      vm.registers[r3] = result
    })
  }

  module.allocateArray = function (type, r1, r2) {
    return new Instruction("AllocateArray", {}, function (vm) {
      var sz = vm.registers[r1]
      logDebug(this.instructionName + ": Allocating array of type " + type.name + " and of size " + sz +
        " in register " + r2)
      var array = new Array(sz)
      var i
      for (i = 0; i < sz; ++i) {
        array[i] = 0
      }
      vm.registers[r2] = array
//
//      if (typesModule.isObj(type.arrayType)) {
////         Push index
//        logDebug("#{@instructionName}: Pushing index to stack")
//        vm.pushToReg(0)
//      }
    })
  }

  module.dac = function () {
    return new Instruction("Dac", {}, function (vm) {
      vm.pushDac()
    })
  }

  module.bunghole = function () {
    return new Instruction("Bunghole", {}, function (vm) {
      vm.pushBunghole()
    })
  }

  module.eoc = function () {return new Instruction("Eoc") }

  module.uGenLink = function (r1, r2) {
    return new Instruction("UGenLink", {}, function (vm) {
      var src = vm.registers[r1]
      var dest = vm.registers[r2]
      logDebug("UGenLink: Linking node of type " + src.type.name + " to node of type " + dest.type.name)
      dest.add(src)
    })
  }

  module.uGenUnlink = function (r1, r2) {
    return new Instruction("UGenUnlink", {}, function (vm) {
      var src = vm.registers[r1]
      var dest = vm.registers[r2]
      logDebug("#{@instructionName}: Unlinking node of type " + src.type.name + " from node of type " + dest.type.name)
      dest.remove(src)
    })
  }

  module.funcCall = function (r1, r2) {
    return new Instruction("FuncCall", {}, function (vm) {
      // TODO: Get rid of this
//      var localDepth = vm.popFromReg()
      var func = vm.registers[r1]
      var stackDepth = func.stackDepth
      logDebug(this.instructionName + ": Calling function " + func.name + ", with stackDepth " + stackDepth)

      // Read arguments from enclosing scope
      var args = [], i
      for (i = 0; i < stackDepth; ++i) {
        args[i] = vm.registers[r2+i]
      }

      logDebug(this.instructionName + ": Pushing current instruction set and instruction counter to instructions stack")
      vm.instructionsStack.push([vm.instructions, vm._pc+1])
      vm._nextPc = 0
      vm.instructions = func.code.instructions
      vm.enterFunctionScope()

      // Assign arguments to local registers
      logDebug(this.instructionName + ": Copying " + args.length + " arguments to function registers")
      for (i = 0; i < args.length; ++i) {
        // The first register is reserved for the return value
        vm.registers[i+1] = args[i]
      }
    })
  }

  module.funcReturn = function () {
    return new Instruction("FuncReturn", {}, function (vm) {
      logDebug(this.instructionName + ": Returning from function")
      vm.exitFunctionScope()

      logDebug(this.instructionName + ": Popping current instructions and instruction counter from instructions stack")
      var instructionsAndPc = vm.instructionsStack.pop()
      vm.instructions = instructionsAndPc[0]
      vm._nextPc = instructionsAndPc[1]
    })
  }

  module.regPushMemAddr =  function(offset, isGlobal) {
    return new Instruction("RegPushMemAddr", {}, function (vm) {
      var globalStr = isGlobal ? " global" : ""
      logDebug("#{@instructionName}: Pushing#{globalStr} memory address (@#{offset}) to regular stack")
      vm.pushMemAddrToReg(offset, isGlobal)
    })
  }
  module.regPushMem = function (offset, isGlobal) {
    return new Instruction("RegPushMem", {offset: offset, isGlobal: isGlobal})
  }

  module.regDupLast = function () {
    return new Instruction("RegDupLast", {}, function (vm) {
      var last = vm.regStack[vm.regStack.length - 1]
      logDebug("RegDupLast: Duplicating top of stack: #{last}")
      vm.regStack.push(last)
    })
  }

  module.dotStaticFunc = function (func) {
    return new Instruction("DotStaticFunc", {}, function (vm) {
      logDebug("DotStaticFunc: Pushing static method to stack:", func)
      vm.pushToReg(func)
    })
  }

  module.divideNumber = function (r1, r2, r3) {
    return new Instruction("DivideNumber", {}, function (vm) {
      var lhs = vm.registers[r1]
      var rhs = vm.registers[r2]
      var number = lhs / rhs
      logDebug("DivideNumber (" + lhs + "/" + rhs + ") resulted in: " + number)
      vm.registers[r3] = number
    })
  }

  module.regPushMe = function () {
    return new Instruction("RegPushMe", {}, function (vm) {
      vm.pushMe()
    })
  }

  module.preIncNumber = function (r1, r2) {
    return new Instruction("PreIncNumber", {}, function (vm) {
      var val = vm.registers[r1]
      ++val
      vm.registers[r1] = vm.registers[r2] = val
    })
  }

  module.postIncNumber = function (r1, r2) {
    return new Instruction("PostIncNumber", {}, function (vm) {
      var val = vm.registers[r1]
      vm.registers[r2] = val
      vm.registers[r1] = ++val
    })
  }

  module.subtractNumber = function (r1, r2, r3) {
    return new Instruction("SubtractNumber", {}, function (vm) {
      var lhs = vm.registers[r1]
      var rhs = vm.registers[r2]
      var number = lhs - rhs
      logDebug("#{@instructionName}: Subtracting " + rhs + " from " + lhs + " resulted in: " + number)
      vm.registers[r3] = number
    })
  }

  module.gtNumber = function () {
    return new Instruction("GtNumber", {}, function (vm) {
      var rhs = vm.popFromReg()
      var lhs = vm.popFromReg()
      var result = lhs > rhs
      logDebug("#{@instructionName}: Pushing #{result} to regular stack")
      vm.pushToReg(result)
    })
  }

  function formatFloat(value) { return value.toFixed(6) }

  module.gack = function (types, registers) {
    return new Instruction("Gack", {}, function (vm) {
      if (types.length === 1) {
        module.hack(types[0], registers[0]).execute(vm)
        return
      }

      var values = _.map(registers, function (ri) {
        return vm.registers[ri]
      })
      var str = "", i
      for (i = 0; i < types.length; ++i) {
        var tp = types[i]
        var value = values[i]
        if (tp === types.float) {
          str += formatFloat(value) + ' '
        }
        else {
          str += value + ' '
        }
      }

      console.log(str.slice(0, str.length - 1))
    })
  }

  module.hack = function (type, r1) {
    return new Instruction("Hack", {}, function (vm) {
      var obj = vm.registers[r1]
      logDebug("Printing object of type " + type.name + ":", obj)
      if ( _.isArray(obj)) {
        var arrStr = _.str.join(",", obj)
        console.log("[" + arrStr + "] :(" + type.name + "[])")
        return
      }
      if (type === types.String) {
        console.log("\"" + obj + "\" : (" + type.name + ")")
      }
      else if (type === types.float || type === types.dur) {
        console.log(formatFloat(obj) + " :(" + type.name + ")")
      }
      else if (type === types.int) {
        console.log(obj + " :(" + type.name + ")")
      }
      else {
        console.log(obj + " : (" + type.name + ")")
      }
    })
  }

  module.goto = function (jmp) {
    return new Instruction("Goto", {jmp: jmp}, function (vm) {
      logDebug("Jumping to instruction number " + this.jmp)
      vm.jumpTo(this.jmp)
    })
  }

  module.arrayAccess = function (type, r1, r2, r3, emitAddr) {
    return new Instruction("ArrayAccess", {}, function (vm) {
      logDebug("#{@instructionName}: Accessing array of type #{type.name}")
      var array = vm.registers[r1]
      var idx = vm.registers[r2]
      var val
      if (!emitAddr) {
        val = array[idx]
        logDebug("Pushing array[#{idx}] (#{val}) to regular stack")
        vm.registers[r3] = val
      }
      else {
        logDebug("Pushing array (#{array}) and index (#{idx}) to regular stack")
        vm.registers[r3] = [array, idx]
      }
    })
  }

  function UnaryOpInstruction(name, params, execute) {
    var self = this
    Instruction.call(self, name, params, execute)
    self.val = 0
  }
  UnaryOpInstruction.prototype = Object.create(Instruction.prototype)
  UnaryOpInstruction.prototype.set = function (val) {
    var self = this
    self._val = val
  }

  module.preCtorArray = function (type, r1, r2, typesWithCtors) {
    return new UnaryOpInstruction("PreCtorArray", {}, function (vm) {
      var length = vm.registers[r1]
      var array = vm.registers[r2]
      var i, obj, j, typeWithCtor
      logDebug("Instantiating " + length + " array elements of type " + type.name)
      for (i = 0; i < length; ++i) {
        obj = instantiateObject(type, vm)
        for (j = 0; j < typesWithCtors.length; ++j) {
          typeWithCtor = typesWithCtors[j]
          logDebug("Calling pre-constructor for type " + typeWithCtor.name)
          typeWithCtor.preConstructor.call(obj)
        }
        array[i] = obj
      }
      logDebug(this.instructionName + ": Finished instantiating elements")
    })
  }

  module.preCtorArrayBottom = function (r1, r2) {
    return new UnaryOpInstruction("PreCtorArrayBottom", {}, function (vm) {
      logDebug("#{@instructionName}: Popping object and index from stack")
      var obj = vm.popFromReg()
      var index = vm.popFromReg()
      logDebug("#{@instructionName}: Peeking array from stack")
      var array = vm.peekReg()

      logDebug("#{@instructionName}: Assigning to index #{index} of array:", obj)
      array[index] = obj
//     Increment index
      logDebug("#{@instructionName}: Pushing incremented index to stack")
      vm.pushToReg(index + 1)

//     Goto top
      logDebug("#{@instructionName}: Jumping to instruction " + this._val)
      vm.jumpTo(this._val)
    })
  }

  module.arrayInit = function (type, registers, ri) {
    return new Instruction("ArrayInit", {}, function (vm) {
      logDebug(this.instructionName + ": Creating an array of " + registers.length + " element(s)")
      var values = _.map(registers, function (ri) {
        return vm.registers[ri]
      })
      logDebug(this.instructionName + ": Assigning instantiated array to register " + ri + ":", values)
      vm.registers[ri] = values
    })
  }

  module.negateNumber = function (r1, r2) {
    return new Instruction("NegateNumber", {}, function (vm) {
      var number = vm.registers[r1]
      vm.registers[r2] = -number
      logDebug("#{@instructionName}: Assigning negated number in register " + r1 + " to register " + r2)
    })
  }

  return module
})
