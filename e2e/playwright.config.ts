import { defineConfig, devices } from '@playwright/test';

import { APP_URL } from './support/urls';

export default defineConfig({
  testDir: './tests',
  globalSetup: './global-setup.ts',
  timeout: 60_000,
  expect: { timeout: 30_000 }, // Flutter's first paint is slow
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: { baseURL: APP_URL, trace: 'retain-on-failure' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'python3 -m http.server 8080 --bind 127.0.0.1 --directory ../client/build/web',
    url: APP_URL,
    reuseExistingServer: !process.env.CI,
  },
});
