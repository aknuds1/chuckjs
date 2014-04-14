module.exports = function (grunt) {
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-shell');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-stencil')

  grunt.initConfig({
    coffee: {
      compile: {
        files: {
          'lib/grammar.js': 'language/grammar.coffee',
          'lib/chuck/helpers.js': 'src/chuck/helpers.coffee',
          'lib/chuck/lexer.js': 'src/chuck/lexer.coffee',
          'lib/chuck.js': 'src/chuck.coffee',
          'lib/chuck/audioContextService.js': 'src/chuck/audioContextService.coffee',
          'lib/chuck/instructions.js': 'src/chuck/instructions.coffee',
          'lib/chuck/logging.js': 'src/chuck/logging.coffee',
          'lib/chuck/nodes.js': 'src/chuck/nodes.coffee',
          'lib/chuck/parserService.js': 'src/chuck/parserService.coffee',
          'lib/chuck/scanner.js': 'src/chuck/scanner.coffee',
          'lib/chuck/types.js': 'src/chuck/types.coffee',
          'lib/chuck/ugen.js': 'src/chuck/ugen.coffee',
          'lib/chuck/vm.js': 'src/chuck/vm.coffee',
          'lib/chuck/namespace.js': 'src/chuck/namespace.coffee',
          'lib/chuck/libs/math.js': 'src/chuck/libs/math.coffee',
          'lib/chuck/libs/std.js': 'src/chuck/libs/std.coffee'
        }
      },
      compileExamples: {
        options: { bare: true },
        expand: true,
        flatten: false,
        cwd: 'pages/',
        src: ['**/*.coffee'],
        dest: 'examples/',
        ext: '.js'
      }
    },
    copy: {
      npm: {
        files: [
          {
            expand: true, cwd: 'node_modules', flatten: true, dest: 'lib/', filter: 'isFile',
            src: [
              'lodash/lodash.js',
              'underscore.string/lib/underscore.string.js',
              'almond/almond.js'
            ]
          }
        ]
      },
      lib: {
        files: [
          {expand: true, cwd: 'src/lib/', src: ['q.js'], dest: 'lib/'}
        ]
      },
      stencil: {
        files: [
          {
            expand: true, cwd: 'pages', dest: 'examples/', filter: 'isFile',
            src: [
              '**/*.js', '**/*.css'
            ]
          }
        ]
      }
    },
    shell: {
      minify: {
        options: { failOnError: true, stdout: true, stderr: true },
        command: 'node node_modules/requirejs/bin/r.js -o baseUrl=lib name=almond include=' +
          'chuck,lodash,underscore.string,chuck/parser wrap=false optimize=none ' +
          'out=examples/js/chuck.js'
      }
    },
    stencil: {
      options: {
        templates: 'pages/templates'
      },
      main: {
        options: {
          env: {
            root: ''
          }
        },
        files: {
          'examples/example1.html': ['pages/example1.dot.html'],
          'examples/example2.html': ['pages/example2.dot.html']
        }
      },
      basic: {
        options: {
          env: {
            root: '../'
          }
        },
        files: [
          {
            expand: true,
            cwd: 'pages',
            src: 'basic/**/*.dot.html',
            dest: 'examples/',
            ext: '.html',
            filter: 'isFile'
          }
        ]
      }

    }
  });

  grunt.registerTask('parser', 'Generate parser', function () {
    grunt.task.requires('coffee');
    var parserGenerator = require('./lib/grammar').generate;
    var parserCode = parserGenerator();
    parserCode = parserCode + "\nwindow.ChuckParser = parser.Parser;\n";
    grunt.file.write('lib/chuck/parser.js', parserCode);
  });

  grunt.registerTask('default', ['coffee', 'parser', 'copy', 'shell', 'stencil']);
};
