// Karma configuration
module.exports = function (config) {
  config.set({
    // base path, that will be used to resolve files and exclude
    basePath: 'src',

    // frameworks to use
    frameworks: ['jasmine'],

    // list of files / patterns to load in the browser
    files: [
      // Load q before require, since we don't want it to register itself as a module
      'lib/q.js',
      '../node_modules/lodash/lodash.js',
      '../node_modules/underscore.string/lib/underscore.string.js',
      '../node_modules/requirejs/require.js',
      '../node_modules/karma-requirejs/lib/adapter.js',
      'test-main.coffee',
      {pattern: '**/*.coffee', included: false},
      {pattern: '**/*.js', included: false},
      '../lib/chuck/parser.js'
    ],

    // list of files to exclude
    exclude: [],

    // test results reporter to use
    // possible values: 'dots', 'progress', 'junit', 'growl', 'coverage'
    reporters: ['progress', 'growler'],

    // web server port
    port: 9876,

    // enable / disable colors in the output (reporters and logs)
    colors: true,

    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,

    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera (has to be installed with `npm install karma-opera-launcher`)
    // - Safari (only Mac; has to be installed with `npm install karma-safari-launcher`)
    // - PhantomJS
    // - IE (only Windows; has to be installed with `npm install karma-ie-launcher`)
    browsers: ['Chrome', 'PhantomJS'],

    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 60000,

    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false,

    preprocessors: {
      '**/*.coffee': ['coffee']
    },
    coffeePreprocessor: {
      options: {
        bare: true,
        sourceMap: false
      }
    },

    plugins: [
      'karma-phantomjs-launcher',
      'karma-jasmine',
      'karma-chrome-launcher',
      'karma-growler-reporter',
      'karma-requirejs',
      'karma-coffee-preprocessor'
    ]
  });
};
