// Copyright (c) 2020 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

'use strict';

const autoprefixer = require('autoprefixer');
const purgecss = require('@fullhuman/postcss-purgecss');

const development = {
  plugins: [autoprefixer],
};

const production = {
  plugins: [
    purgecss({
      content: ['./src/**/*.elm', './src/static/index.js'],
      whitelist: ['html', 'body', 'svg', 'ansi'],
    }),
    autoprefixer,
  ],
};

if (process.env.NODE_ENV === 'production') {
  module.exports = production;
} else {
  module.exports = development;
}
