// Copyright (c) 2020 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

'use strict';

// https://stylelint.io/user-guide/rules/

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
    'stylelint-declaration-strict-value',
  ],
  rules: {
    'color-named': 'never',
    'color-no-hex': true,
    'declaration-no-important': true,
    'declaration-colon-space-after': 'always',
    'declaration-empty-line-before': null,
    'font-weight-notation': 'named-where-possible',
    'no-descending-specificity': null,
    'rule-empty-line-before': [
      'always',
      {
        except: ['first-nested'],
        ignore: ['after-comment'],
      },
    ],
    'at-rule-empty-line-before': [
      'always',
      {
        except: ['after-same-name', 'first-nested'],
        ignore: ['after-comment'],
      },
    ],
    'max-nesting-depth': [
      2,
      { ignore: ['blockless-at-rules', 'pseudo-classes'] },
    ],
    'number-leading-zero': 'always',
    'length-zero-no-unit': true,
    // mostly disallows traditional BEM naming
    // since we're going for http://www.cutestrap.com/features/popsicle
    'selector-class-pattern': '^((?!(-|_)\\2{1,})[a-z0-9\\-])*$',
    'selector-max-compound-selectors': 3,
    'selector-max-specificity': [
      // setting for interim, try to lower especially last numer (id,class,type)
      '0,3,3',
      { ignoreSelectors: ['/:.*/', '/^\\.-[^-].*/'] },
    ],
    'selector-no-vendor-prefix': true,
    'selector-no-qualifying-type': [true, { ignore: ['attribute', 'class'] }],
    'scss/selector-no-redundant-nesting-selector': true,
    'color-format/format': {
      format: 'hsl',
    },
    'plugin/no-low-performance-animation-properties': [
      true,
      // we're ok with paint performance hit (for now)
      { ignoreProperties: ['color', 'background-color'] },
    ],
    'plugin/declaration-block-no-ignored-properties': true,
    'plugin/rational-order': [
      true,
      {
        'empty-line-between-groups': true,
      },
    ],
    // we handle prefers-reduced-motion this globally so it's ok
    // if affected css makes its way in
    'a11y/media-prefers-reduced-motion': null,
    'scale-unlimited/declaration-strict-value': [
      ['color', 'fill', 'stroke', '/-color/'],
      {
        ignoreKeywords: [
          'currentColor',
          'inherit',
          'transparent',
          'initial',
          'none',
        ],
      },
    ],
  },
};
