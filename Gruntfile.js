module.exports = function (grunt) {
    grunt.loadNpmTasks('grunt-contrib-coffee');

    grunt.initConfig({
        coffee: {
            compile: {
                files: {
                    'lib/grammar.js': 'src/grammar.coffee',
                    'lib/helpers.js': 'src/helpers.coffee',
                    'lib/lexer.js': 'src/lexer.coffee',
                    'testparse.js': 'src/testparse.coffee'
                }
            }
        }
    });

    grunt.registerTask('parser', 'Generate parser', function () {
        grunt.task.requires('coffee');
        var parserGenerator = require('./lib/grammar').generate;
        var parserCode = parserGenerator();
        grunt.file.write('lib/parser.js', parserCode);
    });

    grunt.registerTask('default', ['coffee', 'parser']);
};
