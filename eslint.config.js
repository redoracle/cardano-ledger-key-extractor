const js = require("@eslint/js");

module.exports = [
  // Base configuration for all files
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        // Node.js globals
        process: "readonly",
        Buffer: "readonly",
        console: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        module: "readonly",
        require: "readonly",
        exports: "readonly",
        global: "readonly",
        setTimeout: "readonly",
        setInterval: "readonly",
        clearTimeout: "readonly",
        clearInterval: "readonly",
      },
    },
    rules: {
      // Security-focused rules (keep these strict)
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-new-func": "error",
      "no-script-url": "error",
      "no-debugger": "error",
      "no-alert": "error",

      // Code quality (relaxed for CLI apps)
      "no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],
      "no-undef": "error",
      "prefer-const": "error",
      "no-var": "error",
      "no-console": "off", // CLI apps need console
      "no-process-exit": "off", // CLI apps need process.exit

      // Relaxed magic numbers for crypto constants
      "no-magic-numbers": "off", // Crypto code has many valid constants
    },
  },
  // Override for test files
  {
    files: ["tests/**/*.js", "**/*.test.js"],
    languageOptions: {
      globals: {
        // Jest globals
        describe: "readonly",
        test: "readonly",
        it: "readonly",
        expect: "readonly",
        beforeAll: "readonly",
        beforeEach: "readonly",
        afterAll: "readonly",
        afterEach: "readonly",
        jest: "readonly",
        // Node.js globals
        process: "readonly",
        Buffer: "readonly",
        console: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        module: "readonly",
        require: "readonly",
        exports: "readonly",
        global: "readonly",
        setTimeout: "readonly",
        setInterval: "readonly",
        clearTimeout: "readonly",
        clearInterval: "readonly",
      },
    },
    rules: {
      "no-console": "off",
      "no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_|^(error|e)$",
          caughtErrorsIgnorePattern: "^_|(error|e)$",
        },
      ],
      "no-magic-numbers": "off", // Test files have many test constants
    },
  },
  // Ignore patterns
  {
    ignores: ["node_modules/", "coverage/", "dist/", "build/", "docs/", "*.md"],
  },
];
