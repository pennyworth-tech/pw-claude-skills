---
name: web-e2e-testing
description: End-to-end web testing with Playwright, Vibium, and browser automation patterns. Use when testing full user flows, implementing E2E test suites, or validating cross-browser compatibility.
license: MIT
---

# Web E2E Testing with Playwright & Vibium

Comprehensive guide for end-to-end browser testing.

## Playwright Setup

### Installation
```bash
npm init playwright@latest

# Or manually
npm install -D @playwright/test
npx playwright install
```

### Configuration
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results.json' }]
  ],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] }
    }
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI
  }
})
```

## Basic E2E Tests

### Page Navigation and Assertions
```typescript
import { test, expect } from '@playwright/test'

test.describe('Homepage', () => {
  test('should display hero section', async ({ page }) => {
    await page.goto('/')

    // Title assertion
    await expect(page).toHaveTitle(/My App/)

    // Element visibility
    await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible()

    // Screenshot comparison
    await expect(page).toHaveScreenshot('homepage.png')
  })

  test('should navigate to about page', async ({ page }) => {
    await page.goto('/')

    await page.getByRole('link', { name: 'About' }).click()

    await expect(page).toHaveURL(/.*about/)
    await expect(page.getByRole('heading', { name: 'About Us' })).toBeVisible()
  })
})
```

### User Authentication Flow
```typescript
test.describe('Authentication', () => {
  test('should login successfully', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel('Email').fill('user@example.com')
    await page.getByLabel('Password').fill('password123')
    await page.getByRole('button', { name: 'Sign In' }).click()

    // Wait for redirect
    await expect(page).toHaveURL('/dashboard')
    await expect(page.getByText('Welcome back')).toBeVisible()
  })

  test('should show error on invalid credentials', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel('Email').fill('wrong@example.com')
    await page.getByLabel('Password').fill('wrongpassword')
    await page.getByRole('button', { name: 'Sign In' }).click()

    await expect(page.getByRole('alert')).toContainText('Invalid credentials')
    await expect(page).toHaveURL('/login')
  })
})
```

## Vibium Integration (AI-Native Testing)

### MCP Setup
```bash
# Add Vibium MCP server
claude mcp add vibium -- npx -y vibium
```

### Vibium Test Example
```typescript
// Using Vibium through Claude Code
// Natural language commands converted to actions

test('checkout flow with Vibium', async ({ page }) => {
  // Vibium provides AI-powered element selection
  await page.goto('/products')

  // AI finds elements by description
  await page.getByRole('button', { name: /add to cart/i }).first().click()
  await page.getByRole('link', { name: /cart/i }).click()
  await page.getByRole('button', { name: /checkout/i }).click()

  // Form filling
  await page.getByLabel(/email/i).fill('customer@example.com')
  await page.getByLabel(/card number/i).fill('4242424242424242')
  await page.getByLabel(/expiry/i).fill('12/25')
  await page.getByLabel(/cvc/i).fill('123')

  await page.getByRole('button', { name: /pay/i }).click()

  await expect(page.getByText(/order confirmed/i)).toBeVisible()
})
```

## Cross-Browser Testing

### Browser-Specific Tests
```typescript
test.describe('Cross-browser rendering', () => {
  test('should render correctly in all browsers', async ({ page, browserName }) => {
    await page.goto('/complex-ui')

    // Browser-specific handling
    if (browserName === 'webkit') {
      // Safari-specific adjustments
      await page.waitForTimeout(100) // WebKit may need extra time
    }

    // Take screenshot for comparison
    await expect(page).toHaveScreenshot(`complex-ui-${browserName}.png`)
  })
})
```

### Device Emulation
```typescript
test.describe('Mobile responsiveness', () => {
  test.use({
    viewport: { width: 375, height: 667 },
    isMobile: true,
    hasTouch: true
  })

  test('should show mobile menu', async ({ page }) => {
    await page.goto('/')

    // Desktop nav should be hidden
    await expect(page.getByRole('navigation', { name: 'main' })).toBeHidden()

    // Hamburger menu should be visible
    await page.getByRole('button', { name: 'Menu' }).click()

    await expect(page.getByRole('navigation', { name: 'mobile' })).toBeVisible()
  })
})
```

## Network Interception

### API Mocking
```typescript
test.describe('API Mocking', () => {
  test('should display mocked user data', async ({ page }) => {
    // Mock API response
    await page.route('**/api/user', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          id: '123',
          name: 'Mock User',
          email: 'mock@example.com'
        })
      })
    })

    await page.goto('/profile')

    await expect(page.getByText('Mock User')).toBeVisible()
    await expect(page.getByText('mock@example.com')).toBeVisible()
  })

  test('should handle API errors gracefully', async ({ page }) => {
    await page.route('**/api/data', async route => {
      await route.fulfill({
        status: 500,
        body: 'Internal Server Error'
      })
    })

    await page.goto('/data')

    await expect(page.getByRole('alert')).toContainText('Failed to load data')
    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible()
  })
})
```

### Request Interception
```typescript
test('should log network requests', async ({ page }) => {
  const requests: string[] = []

  page.on('request', request => {
    requests.push(request.url())
  })

  await page.goto('/dashboard')

  // Verify expected API calls were made
  expect(requests.some(url => url.includes('/api/user'))).toBeTruthy()
  expect(requests.some(url => url.includes('/api/metrics'))).toBeTruthy()
})
```

## Visual Testing

### Screenshots
```typescript
test.describe('Visual Regression', () => {
  test('homepage visual test', async ({ page }) => {
    await page.goto('/')

    // Full page screenshot
    await expect(page).toHaveScreenshot('homepage-full.png', {
      fullPage: true
    })

    // Component screenshot
    const hero = page.locator('.hero-section')
    await expect(hero).toHaveScreenshot('hero-section.png')
  })

  test('should handle dynamic content', async ({ page }) => {
    await page.goto('/dashboard')

    // Mask dynamic elements
    await expect(page).toHaveScreenshot('dashboard.png', {
      mask: [
        page.locator('.timestamp'),
        page.locator('.user-avatar')
      ]
    })
  })
})
```

### Visual Comparison Options
```typescript
await expect(page).toHaveScreenshot('page.png', {
  maxDiffPixels: 100,           // Allow some pixel differences
  maxDiffPixelRatio: 0.01,      // Or 1% different pixels
  threshold: 0.2,               // Color difference threshold
  animations: 'disabled',        // Disable CSS animations
  caret: 'hide',                // Hide blinking cursor
  scale: 'css'                  // Consistent scaling
})
```

## Video Recording

### Configuration
```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    video: {
      mode: 'on-first-retry',
      size: { width: 1280, height: 720 }
    }
  }
})
```

### Programmatic Recording
```typescript
test('record user flow', async ({ page, context }) => {
  // Start recording
  await context.tracing.start({ screenshots: true, snapshots: true })

  await page.goto('/onboarding')
  // ... test steps

  // Stop and save trace
  await context.tracing.stop({ path: 'trace.zip' })
})
```

## Page Object Model

### Page Class Definition
```typescript
// pages/LoginPage.ts
import { Page, Locator, expect } from '@playwright/test'

export class LoginPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly submitButton: Locator
  readonly errorMessage: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.submitButton = page.getByRole('button', { name: 'Sign In' })
    this.errorMessage = page.getByRole('alert')
  }

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.submitButton.click()
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message)
  }
}
```

### Using Page Objects
```typescript
import { test, expect } from '@playwright/test'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'

test('user login flow', async ({ page }) => {
  const loginPage = new LoginPage(page)
  const dashboardPage = new DashboardPage(page)

  await loginPage.goto()
  await loginPage.login('user@example.com', 'password')

  await dashboardPage.expectWelcomeMessage('Welcome back')
})
```

## Fixtures and Hooks

### Custom Fixtures
```typescript
// fixtures.ts
import { test as base } from '@playwright/test'
import { LoginPage } from './pages/LoginPage'

type MyFixtures = {
  loginPage: LoginPage
  authenticatedPage: Page
}

export const test = base.extend<MyFixtures>({
  loginPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page)
    await use(loginPage)
  },

  authenticatedPage: async ({ page }, use) => {
    // Perform login
    await page.goto('/login')
    await page.getByLabel('Email').fill('test@example.com')
    await page.getByLabel('Password').fill('password')
    await page.getByRole('button', { name: 'Sign In' }).click()
    await page.waitForURL('/dashboard')

    await use(page)
  }
})

export { expect } from '@playwright/test'

// Usage
test('authenticated user can access settings', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/settings')
  await expect(authenticatedPage).toHaveURL('/settings')
})
```

### Test Hooks
```typescript
test.describe('User flows', () => {
  test.beforeAll(async () => {
    // Run once before all tests
    await seedDatabase()
  })

  test.beforeEach(async ({ page }) => {
    // Run before each test
    await page.goto('/')
  })

  test.afterEach(async ({ page }, testInfo) => {
    // Capture screenshot on failure
    if (testInfo.status !== 'passed') {
      await page.screenshot({
        path: `screenshots/${testInfo.title}.png`
      })
    }
  })

  test.afterAll(async () => {
    // Cleanup after all tests
    await cleanupDatabase()
  })
})
```

## Parallel Execution

### Sharding
```bash
# Run in CI with sharding
npx playwright test --shard=1/4
npx playwright test --shard=2/4
npx playwright test --shard=3/4
npx playwright test --shard=4/4
```

### Worker Isolation
```typescript
// playwright.config.ts
export default defineConfig({
  workers: 4,
  fullyParallel: true,

  // Per-worker database
  use: {
    storageState: undefined
  }
})
```

## CI/CD Integration

### GitHub Actions
```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps

      - name: Run E2E tests
        run: npx playwright test

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## Best Practices

1. **Use locator strategies** - Role > Label > Text > TestID
2. **Auto-wait for elements** - Playwright handles waiting automatically
3. **Isolate tests** - Each test should be independent
4. **Use page objects** - Abstract page interactions
5. **Mock external services** - Control test environment
6. **Capture evidence** - Screenshots, videos, traces on failure
7. **Run in parallel** - Faster feedback
8. **Test critical paths** - Focus on user journeys
9. **Keep tests fast** - Target < 30s per test
10. **Review flaky tests** - Fix or quarantine immediately
