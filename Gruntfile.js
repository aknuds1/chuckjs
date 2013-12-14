module.exports = function (grunt) {
    grunt.loadNpmTasks('grunt-contrib-coffee');

    grunt.initConfig({
        coffee: {
            compile: {
                files: {
                    'lib/grammar.js': 'src/grammar.coffee',
                    'lib/chuck/helpers.js': 'src/chuck/helpers.coffee',
                    'lib/chuck/lexer.js': 'src/chuck/lexer.coffee',
                    'lib/chuck.js': 'src/chuck.coffee',
                    'testparse.js': 'src/testparse.coffee'
                }
            }
        }
    });

    grunt.registerTask('parser', 'Generate parser', function () {
        grunt.task.requires('coffee');
        var parserGenerator = require('./lib/grammar').generate;
        var parserCode = parserGenerator();
        parserCode = parserCode + "\nChuckParser = parser.Parser;\n";
        grunt.file.write('lib/parser.js', parserCode);
    });

    grunt.registerTask('default', ['coffee', 'parser']);
};
