const js = require('@eslint/js');

const nodeGlobals = {
  __dirname: 'readonly',
  Buffer: 'readonly',
  console: 'readonly',
  fetch: 'readonly',
  module: 'readonly',
  process: 'readonly',
  require: 'readonly',
  setTimeout: 'readonly',
  URL: 'readonly',
};

module.exports = [
  {
    ignores: ['node_modules/**', 'uploads/**'],
  },
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',
      globals: nodeGlobals,
    },
    rules: {
      'no-empty': ['warn', { allowEmptyCatch: true }],
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    },
  },
];
