module.exports = (grunt) ->
  grunt.initConfig({})

  grunt.registerTask('parser', 'Generate parser', ->
    parserGenerator = require('./language/grammar.coffee').generate
    parserCode = parserGenerator()
    grunt.file.write('src/parser.js', parserCode)
  )

  grunt.registerTask('default', ['parser'])
