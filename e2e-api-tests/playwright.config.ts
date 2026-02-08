import { defineConfig } from '@playwright/test'
import dotenv from 'dotenv'

dotenv.config()

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'playwright-results.xml' }],
    ['list']
  ],
  use: {
    actionTimeout: 30000,
    navigationTimeout: 30000,
  },
  timeout: 60000,
})
