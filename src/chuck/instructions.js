define("chuck/instructions", ["chuck/ugen", "chuck/logging", "chuck/types"], function (ugen, logging, typesModule) {
  var module = {}
  var types = typesModule.types

  var logDebug = function () {
//    logging.debug.apply(null, arguments)
  }

  function callFunction(vm, func, ri, riRet) {
    var stackDepth = func.stackDepth
    logDebug("Calling function", func)
    logDebug("Passing registers " + ri + " to " + ri + stackDepth - 1 + " as arguments")
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

  module.instantiateObject = function (type, ri) {
    return new Instruction("InstantiateObject", { type: type }, function (vm) {
      logDebug("Instantiating object of type #{type.name}")
      var ug = type.ugenNumOuts == 1 ? new ugen.MonoUGen(type) : new ugen.MultiChannelUGen(type)
      vm.addUgen(ug)
      vm.registers[ri] = ug
    })
  }

  module.preConstructor = function (type, ri) {
    return new Instruction("PreConstructor", {type: type}, function (vm) {
      // Duplicate top of stack, which should be object pointer
      logDebug("Calling pre-constructor of #{@type.name}")
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
      var obj
      if (!isArray) {
        obj = vm.registers[r1]
        logDebug(this.instructionName + ": Assigning object to register " + r2 + " (scope: " + scopeStr + "):", obj)
        tgtRegisters[r2] = obj
      }
      else {
        var array = memStackIndex[0]
        var index = memStackIndex[1]
        logDebug("#{@instructionName}: Assigning object to array, index #{index} (scope: #{scopeStr}):", obj)
        array[index] = obj
      }
    })
  }

  module.plusAssign = function (isGlobal) {
    return new Instruction("PlusAssign", {}, function (vm) {
      var memStackIndex = vm.popFromReg()
      var rhs = vm.popFromReg()
      var lhs = vm.getFromMemory(memStackIndex, isGlobal)
      var result = lhs + rhs
      vm.insertIntoMemory(memStackIndex, result, isGlobal)
      vm.pushToReg(result)
    })
  }
  module.minusAssign = function (isGlobal) {
    return new Instruction("MinusAssign", {}, function (vm) {
      var memStackIndex = vm.popFromReg()
      var rhs = vm.popFromReg()
      var lhs = vm.getFromMemory(memStackIndex, isGlobal)
      var result = lhs - rhs
      vm.insertIntoMemory(memStackIndex, result, isGlobal)
      vm.pushToReg(result)
    })
  }

  module.allocateArray = function (type) {
    return new Instruction("AllocateArray", {}, function (vm) {
      var sz = vm.popFromReg()
      logDebug("#{@instructionName}: Allocating array of type #{type.name} and of size #{sz}")
      var array = new Array(sz)
      var i
      for (i = 0; i < sz; ++i) {
        array[i] = 0
      }
      vm.pushToReg(array)

      if (typesModule.isObj(type.arrayType)) {
//         Push index
        logDebug("#{@instructionName}: Pushing index to stack")
        vm.pushToReg(0)
      }
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

  module.releaseObject2 = function (offset, isGlobal) {
    return new Instruction("ReleaseObject2", {}, function (vm) {
      vm.removeFromMemory(offset, isGlobal)
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

  module.uGenUnlink = function () {
    return new Instruction("UGenUnlink", {}, function (vm) {
      var dest = vm.popFromReg()
      var src = vm.popFromReg()
      logDebug("#{@instructionName}: Unlinking node of type #{src.type.name} from node of type #{dest.type.name}")
      dest.remove(src)
      vm.pushToReg(dest)
    })
  }

  module.funcCallStatic = function () {
    return new Instruction("FuncCallStatic", {}, function (vm) {
    var localDepth = vm.popFromReg()
    logDebug("Popped local depth from stack: #{localDepth}")
    var func = vm.popFromReg()
//    var stackDepth = func.stackDepth
    logDebug("Calling static method '#{func.name}'")
    vm.pushToReg(func)
    vm.pushToReg(localDepth)
    callFunction(vm)
  })
  }

  module.funcCall = function () {
    return new Instruction("FuncCall", {}, function (vm) {
      // TODO: Get rid of this
      /*var localDepth = */vm.popFromReg()
      var func = vm.popFromReg()
      var stackDepth = func.stackDepth
      logDebug("#{@instructionName}: Calling function #{func.name}, with stackDepth #{stackDepth}")

      logDebug("#{@instructionName}: Pushing current instructions to memory stack")
      vm.pushToMem(vm.instructions)
      logDebug("#{@instructionName}: Pushing current instruction counter to memory stack")
      vm.pushToMem(vm._pc + 1)
      vm._nextPc = 0
      vm.instructions = func.code.instructions
      vm.enterFunctionScope()

      if (func.needThis) {
//       Make this the first argument
        var obj = vm.popFromReg()
        vm.pushToMem(obj, false)
        --stackDepth
      }

      var args = [], i
      for (i = 0; i < stackDepth; ++i) {
        var arg = vm.popFromReg()
        args.unshift(arg)
      }
      for (i = 0; i < args.length; ++i) {
        vm.pushToMem(args[i], false)
      }
    })
  }

  module.funcReturn = function () {
    return new Instruction("FuncReturn", {}, function (vm) {
      logDebug("#{@instructionName}: Returning from function")
      vm.exitFunctionScope()

      logDebug("#{@instructionName}: Popping current instructions from memory stack")
      var pc = vm.popFromMem(true)
      logDebug("#{@instructionName}: Popping current instruction counter from memory stack")
      var instructions = vm.popFromMem(true)
      vm._nextPc = pc
      vm.instructions = instructions
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

  module.divideNumber = function () {
    return new Instruction("DivideNumber", {}, function (vm) {
      var rhs = vm.popFromReg()
      var lhs = vm.popFromReg()
      var number = lhs / rhs
      logDebug("DivideNumber (#{lhs}/#{rhs}) resulted in: #{number}")
      vm.pushToReg(number)
    })
  }

  module.regPushNow = function () {
    return new Instruction("RegPushNow", {}, function (vm) {
      vm.pushNow()
    })
  }

  module.regPushMe = function () {
    return new Instruction("RegPushMe", {}, function (vm) {
      vm.pushMe()
    })
  }

  module.preIncNumber = function (isGlobal) {
    return new Instruction("PreIncnUmber", {}, function (vm) {
      var memStackIndex = vm.popFromReg()
      var val = vm.getFromMemory(memStackIndex, isGlobal)
      ++val
      vm.insertIntoMemory(memStackIndex, val, isGlobal)
      vm.pushToReg(val)
    })
  }

  module.postIncNumber = function (isGlobal) {
    return new Instruction("PostIncnUmber", {}, function (vm) {
      var memStackIndex = vm.popFromReg()
      var val = vm.getFromMemory(memStackIndex, isGlobal)
      vm.pushToReg(val)
      ++val
      vm.insertIntoMemory(memStackIndex, val, isGlobal)
    })
  }

  module.subtractNumber = function () {
    return  new Instruction("SubtractNumber", {}, function (vm) {
      var rhs = vm.popFromReg()
      var lhs = vm.popFromReg()
      var number = lhs - rhs
      logDebug("#{@instructionName}: Subtracting #{rhs} from #{lhs} resulted in: #{number}")
      vm.pushToReg(number)
    })
  }

  module.ltNumber = function () {
    return  new Instruction("LtNumber", {}, function (vm) {
      var rhs = vm.popFromReg()
      var lhs = vm.popFromReg()
      var result = lhs < rhs
      logDebug("#{@instructionName}: Pushing #{result} to regular stack")
      vm.pushToReg(result)
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

  module.gack = function (types) {
    return new Instruction("Gack", {}, function (vm) {
      if (types.length === 1) {
        module.hack(types[0]).execute(vm)
        return
      }

      var values = [], i
      for (i = 0; i < types.length; ++i) {
        values.unshift(vm.popFromReg())
      }
      var str = ""
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

      vm.pushToReg(value)

      console.log(str.slice(0, str.length - 1))
    })
  }

  module.hack = function (type) {
    return new Instruction("Hack", {}, function (vm) {
      var obj = vm.peekReg()
      logDebug("Printing object of type #{type.name}:", obj)
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

  module.arrayAccess = function (type, emitAddr) {
    return new Instruction("ArrayAccess", {}, function (vm) {
      logDebug("#{@instructionName}: Accessing array of type #{type.name}")
      var idx = vm.popFromReg()
      var array = vm.popFromReg()
      var val
      if (!emitAddr) {
        val = array[idx]
        logDebug("Pushing array[#{idx}] (#{val}) to regular stack")
        vm.pushToReg(val)
      }
      else {
        logDebug("Pushing array (#{array}) and index (#{idx}) to regular stack")
        vm.pushToReg([array, idx])
      }
    })
  }

  module.memSetImm = function (offset, value, isGlobal) {
    return new Instruction("MemSetImm", {}, function (vm) {
      var scopeStr = isGlobal ? "global" : "function"
      logDebug("#{@instructionName}: Setting memory at offset #{offset} (scope: #{scopeStr}) to:", value)
      vm.insertIntoMemory(offset, value, isGlobal)
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

  module.preCtorArrayTop = function (type) {
    return new UnaryOpInstruction("PreCtorArrayTop", {}, function (vm) {
      var index = vm.peekReg()
      var array = vm.peekReg(1)
      if (index >= array.length) {
        logDebug("#{@instructionName}: Finished instantiating elements")
        vm.jumpTo(this._val)
      }
      else {
        logDebug("#{@instructionName}: Instantiating element #{index} of type #{type.name}")
        module.instantiateObject(type).execute(vm)
      }
    })
  }

  module.preCtorArrayBottom = function () {
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

  module.preCtorArrayPost = function () {
    return new Instruction("PreCtorArrayPost", {}, function (vm) {
      logDebug("#{@instructionName}: Cleaning up, popping index from stack")
//     Pop index
      vm.popFromReg()
    })
  }

  module.arrayInit = function (type, count) {
    return new Instruction("ArrayInit", {}, function (vm) {
      logDebug("#{@instructionName}: Popping #{count} elements from stack")
      var values = [], i
      for (i = 0; i < count; ++i) {
        values.unshift(vm.popFromReg())
      }
      logDebug("#{@instructionName}: Pushing instantiated array to stack", values)
      vm.pushToReg(values)
    })
  }

  module.negateNumber = function () {
    return new Instruction("NegateNumber", {}, function (vm) {
      logDebug("#{@instructionName}: Popping number from stack")
      var number = vm.popFromReg()
      logDebug("#{@instructionName}: Pushing negated number to stack")
      vm.pushToReg(-number)
    })
  }

  return module
})
