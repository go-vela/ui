const { defineConfig } = require('cypress');

module.exports = defineConfig({
  e2e: {
    baseUrl: 'http://localhost:8888',
    video: false,
    defaultCommandTimeout: 20000,
    requestTimeout: 20000,
    responseTimeout: 20000,
    pageLoadTimeout: 30000,
    specPattern: 'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
    supportFile: 'cypress/support/e2e.js',
    // Retry failed tests once in CI
    retries: {
      runMode: 1,
      openMode: 0,
    },
    setupNodeEvents(on, config) {
      // Pass CI environment variable to Cypress as a boolean
      config.env.CI = process.env.CI === 'true' || process.env.CI === '1';
      
      return config;
    },
  },
});
