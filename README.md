# ChuckJS

JavaScript (CoffeeScript) parser for the ChucK language.

This project is just in its infancy at this stage, so do not expect working code yet. I've just begun work on
implementing the parser through the Jison compiler generator, and I could really use some help in defining the grammar.

## Build

In order to build the ChuckJS, you'll need an installation of [Node](http://nodejs.org/) along with
[NPM](https://npmjs.org/). If you haven't already installed [Grunt](http://gruntjs.com), install it system-wide:

    npm install -g grunt-cli

Then, within the ChuckJS project root, install its dependencies (beneath the project root) via NPM:

    npm install

After doing this, you should be able to build the parser, by running grunt:

    grunt

At this point, the parser has been built as src/parser.js.

## Test

There is currently a single, simple test for ChuckJS, testparse.coffee. Run it as follows:

    coffee testparse.coffee

