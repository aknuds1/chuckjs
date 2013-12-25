testFiles = []
files = window.__karma__.files

testRegex = /spec\/.+\.js/
testFiles = (file for own file of files when testRegex.test(file))

if testFiles.length <= 0
  throw new Error("Couldn't find any test files #{testFiles.length}")
requirejs.config({
  # Karma serves files from '/base'
  baseUrl: '/base',
  paths: {
    'q': 'lib/q'
  },
  # ask requirejs to load these files (all our tests)
  deps: testFiles,
  shim: {
  },
  # start test run, once requirejs is done
  callback: window.__karma__.start
});

require([], ->);
