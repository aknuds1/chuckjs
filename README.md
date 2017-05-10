# ChucKJS

[![Greenkeeper badge](https://badges.greenkeeper.io/aknuds1/chuckjs.svg)](https://greenkeeper.io/)

JavaScript ([CoffeeScript](http://coffeescript.org/)) parser for the [ChucK](http://chuck.cs.princeton.edu/)
music programming language, for execution within browsers supporting the Web Audio API (e.g. Chrome, Firefox).

[![Build Status](https://travis-ci.org/aknuds1/chuckjs.png?branch=master)](https://travis-ci.org/aknuds1/chuckjs)

This project is merely in its infancy at this stage, so don't expect too much at this point. For example,
error checking is non-existent. We're basically at the point of having implemented a minimal part of the
language, just enough to be able to execute the
[official examples](https://github.com/spencersalazar/chuck/tree/master/src/examples) we have ported so far.

To see (or perhaps more importantly, hear) ChucKJS in practice, please visit our
[ChucK Demos](http://chuckdemos.com) site, which aggregates and lets you play back language demos.

## Current Status as of 9.13.2014
Focus has shifted to an attempt to automatically port ChucK to JavaScript, using the
[Emscripten](http://emscripten.org) tool. See my [ChucK fork](https://github.com/aknuds1/chuck) if you'd 
like to follow its progress, or perhaps even contribute.

## Build

In order to build ChucKJS, you'll need an installation of [Node](http://nodejs.org/) along with
[NPM](https://npmjs.org/). If you haven't already installed [Grunt](http://gruntjs.com), install it system-wide:

    npm install -g grunt-cli

Then, within the ChucKJS project root, install its dependencies (beneath the project root) via NPM:

    npm install

After doing this, you should be able to build ChucKJS, by running grunt:

    grunt

At this point, the parser has been built as lib/chuck/parser.js. CoffeeScript source files (in src/) are also
compiled to JavaScript beneath lib/. Additionally, ChucKJS and its dependencies are built into the file
examples/js/chuck.js, for the benefit of the examples within the examples/ directory. At this stage, you
should be able to try the examples, e.g. examples/example1.html.

## Test

There are self-contained example HTML files beneath the examples/ directory, which you are encouraged to try
out. In addition to these, ChucKJS is automatically tested via [Karma](http://karma-runner.github.io/).
Run these tests as follows:

    karma start

## Donating

Support this project and [others by Arve Knudsen](https://www.gittip.com/Arve%20Knudsen/) on Gittip.

[![Support via Gittip](http://img.shields.io/gittip/Arve%20Knudsen.png)](https://www.gittip.com/Arve%20Knudsen/)
