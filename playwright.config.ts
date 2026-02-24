import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './playwright',
  testMatch: '**/*.spec.ts',
  timeout: 30000,
  forbidOnly: !!process.env.CI,
  fullyParallel: true,
  workers: process.env.CI ? 4 : undefined,
  retries: process.env.CI ? 2 : 0,
  expect: {
    timeout: 15000,
  },
  reporter: [['list'], ['html', { open: 'never' }]],
  outputDir: 'playwright-results',
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:8888',
    reuseExistingServer: !process.env.CI,
    env: {
      VELA_API: 'http://localhost:8080',
      VELA_LOG_BYTES_LIMIT: '1000',
    },
  },
  use: {
    baseURL: 'http://localhost:8888',
    actionTimeout: 15000,
    navigationTimeout: 15000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    testIdAttribute: 'data-test',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],
});
