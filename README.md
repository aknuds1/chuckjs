# ChucKJS

JavaScript ([CoffeeScript](http://coffeescript.org/)) parser for the [ChucK](http://chuck.cs.princeton.edu/) music
programming language, for execution within browser supporting the Web Audio API (e.g. Chrome).

[![Build Status](https://travis-ci.org/aknuds1/chuckjs.png?branch=master)](https://travis-ci.org/aknuds1/chuckjs)

This project is merely in its infancy at this stage, so don't expect too much at this point. I've currently implemented
parsing of a very small part of the grammar, and a VM capable of executing corresponding code to the point of
generating sound.

To see (or perhaps more importantly, hear) ChucKJS in practice, please visit our
[ChucK Demos](http://chuckdemos.com) site, which aggregates a number of playable demos taken from the official
[ChucK sources](https://github.com/spencersalazar/chuck/tree/master/src/examples).

## Build

In order to build ChucKJS, you'll need an installation of [Node](http://nodejs.org/) along with
[NPM](https://npmjs.org/). If you haven't already installed [Grunt](http://gruntjs.com), install it system-wide:

    npm install -g grunt-cli

Then, within the ChucKJS project root, install its dependencies (beneath the project root) via NPM:

    npm install

After doing this, you should be able to build ChucKJS, by running grunt:

    grunt

At this point, the parser has been built as lib/chuck/parser.js. CoffeeScript source files (in src/) are also compiled
to JavaScript beneath lib/. Additionally, ChucKJS and its dependencies are built into the file examples/js/chuck.js,
for the benefit of the examples within the examples/ directory. At this stage, you should be able to try the examples,
e.g. examples/example1.html.

## Test

There are self-contained example HTML files beneath the examples/ directory, which you are encouraged to try out. In
addition to these, ChucKJS is automatically tested via [Karma](http://karma-runner.github.io/). Run them as follows:

    karma start

## Donating

Support this project and [others by Arve Knudsen](https://www.gittip.com/Arve%20Knudsen/) on Gittip.

[![Support via Gittip](http://img.shields.io/gittip/Arve%20Knudsen.png)](https://www.gittip.com/Arve%20Knudsen/)
