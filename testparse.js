(function() {
  var DeclExpression, ExpFromBinary, ExpFromId, ExpressionStatement, IdList, Lexer, Parser, Program, SectionStatement, StatementList, TypeDecl, VarDecl, VarDeclList, helpers, lexer, parsed, parser, sourcecode, yy, _;

  Lexer = require('./lib/lexer').Lexer;

  Parser = require("./lib/parser").Parser;

  helpers = require('./lib/helpers');

  _ = require('lodash');

  _.str = require('underscore.string');

  _.mixin(_.str.exports());

  yy = {};

  yy.addLocationDataFn = function(first, last) {
    return function(obj) {
      return obj;
    };
  };

  yy.IdList = IdList = (function() {
    function IdList(id) {
      console.log('ID List', id);
      this.id = id;
    }

    return IdList;

  })();

  yy.TypeDecl = TypeDecl = (function() {
    function TypeDecl(idList) {
      this.idList = idList;
      console.log('Type declaration', idList);
    }

    return TypeDecl;

  })();

  yy.VarDecl = VarDecl = (function() {
    function VarDecl(name) {
      this.name = name;
      console.log("Variable declaration: " + name);
    }

    return VarDecl;

  })();

  yy.VarDeclList = VarDeclList = (function() {
    function VarDeclList(declarations) {
      this.declarations = declarations;
      console.log("Variable declaration list:", declarations);
    }

    return VarDeclList;

  })();

  yy.DeclExp = DeclExpression = (function() {
    function DeclExpression(typeDecl, varDecl) {
      var variables;
      this.typeDecl = typeDecl;
      this.varDecl = varDecl;
      variables = _.map(this.varDecl.declarations, function(decl) {
        return decl.name;
      });
      variables = _.str.join(", ", variables);
      console.log("Declaration expression, type " + typeDecl.idList.id + ", variables: " + variables);
    }

    return DeclExpression;

  })();

  yy.Program = Program = (function() {
    function Program(arrowExpression) {
      this.arrowExpression = arrowExpression;
      console.log("Program:", arrowExpression);
    }

    return Program;

  })();

  yy.ExpressionStatement = ExpressionStatement = (function() {
    function ExpressionStatement(expression) {
      this.expression = expression;
      console.log("Expression statement", this.expression);
    }

    return ExpressionStatement;

  })();

  yy.StatementList = StatementList = (function() {
    function StatementList(statements) {
      this.statements = statements;
      console.log("Statement list", this.statements);
    }

    return StatementList;

  })();

  yy.StatementSection = SectionStatement = (function() {
    function SectionStatement(section) {
      this.section = section;
      console.log("Section:", this.section);
    }

    return SectionStatement;

  })();

  yy.ExpFromId = ExpFromId = (function() {
    function ExpFromId(exp) {
      this.exp = exp;
      console.log("Expression from ID", this.exp);
    }

    return ExpFromId;

  })();

  yy.ExpFromBinary = ExpFromBinary = (function() {
    function ExpFromBinary(exp1, operator, exp2) {
      this.exp1 = exp1;
      this.operator = operator;
      this.exp2 = exp2;
      console.log("Expression from binary", this.exp1, this.operator, this.exp2);
    }

    return ExpFromBinary;

  })();

  lexer = new Lexer();

  parser = new Parser();

  parser.yy = yy;

  parser.lexer = {
    lex: function() {
      var tag, token;
      token = this.tokens[this.pos++];
      if (token) {
        tag = token[0], this.yytext = token[1], this.yylloc = token[2];
        this.yylineno = this.yylloc.first_line;
      } else {
        tag = '';
      }
      return tag;
    },
    setInput: function(tokens) {
      this.tokens = tokens;
      return this.pos = 0;
    },
    upcomingInput: function() {
      return "";
    }
  };

  sourcecode = "SinOsc sin => dac;";

  console.log("Tokens:", tokens);

  parsed = parser.parse(tokens);

}).call(this);
