// Copyright (c) 2019 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

'use strict';

module.exports = {
  ignoreFiles: ['src/scss/_reset.scss'],
  extends: [
    'stylelint-config-recommended-scss',
    'stylelint-config-rational-order',
    'stylelint-a11y/recommended',
    'stylelint-config-prettier',
  ],
  plugins: [
    'stylelint-color-format',
    'stylelint-high-performance-animation',
    'stylelint-declaration-block-no-ignored-properties',
  ],
  rules: {
    'color-named': 'never',
    'color-no-hex': true,
    'declaration-no-important': true,
    'declaration-colon-space-after': 'always',
    'max-nesting-depth': [
      2,
      { ignore: ['blockless-at-rules', 'pseudo-classes'] },
    ],
    'number-leading-zero': 'always',
    'length-zero-no-unit': true,
    'selector-class-pattern': '^((?!(-|_)\\2{1,}).)*$',
    'selector-max-compound-selectors': 3,
    'selector-max-specificity': [
      '0,3,3',
      { ignoreSelectors: ['/:.*/', '/^\\.-[^-].*/'] },
    ],
    'selector-no-vendor-prefix': true,
    'selector-no-qualifying-type': [true, { ignore: ['attribute', 'class'] }],
    'scss/selector-no-redundant-nesting-selector': true,
    'color-format/format': {
      format: 'hsl',
    },
    'plugin/no-low-performance-animation-properties': true,
    'plugin/declaration-block-no-ignored-properties': true,
    'a11y/media-prefers-reduced-motion': null, // we handle this globally
  },
};
