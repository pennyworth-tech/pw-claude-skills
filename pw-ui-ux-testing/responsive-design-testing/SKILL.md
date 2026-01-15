---
name: responsive-design-testing
description: Responsive design testing for multi-viewport validation, breakpoint testing, and mobile-first development. Use when validating responsive layouts, testing across screen sizes, or ensuring mobile compatibility.
license: MIT
---

# Responsive Design Testing

Comprehensive guide for testing responsive web design across devices and viewports.

## Viewport Testing Strategy

### Common Breakpoints (2026)
```typescript
const BREAKPOINTS = {
  // Mobile
  mobileS: { width: 320, height: 568 },   // iPhone SE
  mobileM: { width: 375, height: 667 },   // iPhone 8
  mobileL: { width: 414, height: 896 },   // iPhone 11 Pro Max

  // Tablet
  tabletS: { width: 768, height: 1024 },  // iPad Mini
  tabletL: { width: 1024, height: 1366 }, // iPad Pro

  // Desktop
  laptop: { width: 1366, height: 768 },   // Common laptop
  desktop: { width: 1920, height: 1080 }, // Full HD
  desktopL: { width: 2560, height: 1440 } // QHD
}
```

### Playwright Viewport Testing
```typescript
import { test, expect, devices } from '@playwright/test'

test.describe('Responsive Design', () => {
  // Test specific breakpoints
  for (const [name, viewport] of Object.entries(BREAKPOINTS)) {
    test(`should render correctly at ${name}`, async ({ browser }) => {
      const context = await browser.newContext({
        viewport
      })
      const page = await context.newPage()

      await page.goto('/')

      await expect(page).toHaveScreenshot(`homepage-${name}.png`)

      await context.close()
    })
  }

  // Test common devices
  const deviceList = [
    'iPhone 12',
    'iPhone 14 Pro Max',
    'iPad Pro 11',
    'Pixel 5',
    'Galaxy S21'
  ]

  for (const device of deviceList) {
    test(`should work on ${device}`, async ({ browser }) => {
      const context = await browser.newContext({
        ...devices[device]
      })
      const page = await context.newPage()

      await page.goto('/')

      // Device-specific assertions
      await expect(page.locator('.main-content')).toBeVisible()

      await context.close()
    })
  }
})
```

## Breakpoint Validation

### CSS Breakpoint Detection
```typescript
test.describe('Breakpoint Behavior', () => {
  test('should switch to mobile layout below 768px', async ({ page }) => {
    // Start desktop
    await page.setViewportSize({ width: 1024, height: 768 })
    await page.goto('/')

    // Desktop nav should be visible
    await expect(page.locator('nav.desktop-nav')).toBeVisible()
    await expect(page.locator('button.mobile-menu')).toBeHidden()

    // Switch to mobile
    await page.setViewportSize({ width: 767, height: 1024 })

    // Mobile nav should appear
    await expect(page.locator('nav.desktop-nav')).toBeHidden()
    await expect(page.locator('button.mobile-menu')).toBeVisible()
  })

  test('should show sidebar on tablet and above', async ({ page }) => {
    await page.goto('/dashboard')

    // Mobile - no sidebar
    await page.setViewportSize({ width: 375, height: 667 })
    await expect(page.locator('aside.sidebar')).toBeHidden()

    // Tablet - sidebar visible
    await page.setViewportSize({ width: 768, height: 1024 })
    await expect(page.locator('aside.sidebar')).toBeVisible()

    // Desktop - sidebar visible
    await page.setViewportSize({ width: 1200, height: 800 })
    await expect(page.locator('aside.sidebar')).toBeVisible()
  })
})
```

### Fluid Typography Testing
```typescript
test('typography should scale with viewport', async ({ page }) => {
  const getFontSize = async (selector: string) => {
    return page.evaluate((sel) => {
      const el = document.querySelector(sel)
      return el ? window.getComputedStyle(el).fontSize : null
    }, selector)
  }

  await page.goto('/')

  // Mobile
  await page.setViewportSize({ width: 375, height: 667 })
  const mobileFontSize = await getFontSize('h1')

  // Desktop
  await page.setViewportSize({ width: 1920, height: 1080 })
  const desktopFontSize = await getFontSize('h1')

  // Font should be larger on desktop
  expect(parseInt(desktopFontSize!)).toBeGreaterThan(parseInt(mobileFontSize!))
})
```

## Layout Shift Detection

### CLS Measurement
```typescript
test('should not have layout shifts during load', async ({ page }) => {
  await page.goto('/')

  const cls = await page.evaluate(() => {
    return new Promise<number>((resolve) => {
      let clsValue = 0

      new PerformanceObserver((list) => {
        for (const entry of list.getEntries() as any[]) {
          if (!entry.hadRecentInput) {
            clsValue += entry.value
          }
        }
      }).observe({ type: 'layout-shift', buffered: true })

      // Wait for potential shifts
      setTimeout(() => resolve(clsValue), 3000)
    })
  })

  // CLS should be under 0.1 (Good)
  expect(cls).toBeLessThan(0.1)
})
```

### Visual Regression for Layout
```typescript
test.describe('Layout Stability', () => {
  test('no layout shift on image load', async ({ page }) => {
    // Take screenshot before images load
    await page.goto('/', { waitUntil: 'domcontentloaded' })
    const beforeImages = await page.screenshot()

    // Wait for all images
    await page.waitForLoadState('networkidle')
    const afterImages = await page.screenshot()

    // Compare screenshots for shifts
    // (Would typically use visual comparison library)
    expect(beforeImages).toBeDefined()
    expect(afterImages).toBeDefined()
  })

  test('content should not jump during font load', async ({ page }) => {
    await page.goto('/')

    // Check no FOUT/FOIT causing shifts
    const fontLoadCLS = await page.evaluate(() => {
      return new Promise<number>((resolve) => {
        let cls = 0
        const observer = new PerformanceObserver((list) => {
          for (const entry of list.getEntries() as any[]) {
            cls += entry.value
          }
        })
        observer.observe({ type: 'layout-shift', buffered: true })

        document.fonts.ready.then(() => {
          setTimeout(() => resolve(cls), 500)
        })
      })
    })

    expect(fontLoadCLS).toBeLessThan(0.05)
  })
})
```

## Touch vs Mouse Testing

### Touch Interaction Testing
```typescript
test.describe('Touch Interactions', () => {
  test.use({
    hasTouch: true,
    isMobile: true,
    viewport: { width: 375, height: 667 }
  })

  test('should handle touch gestures', async ({ page }) => {
    await page.goto('/gallery')

    const carousel = page.locator('.carousel')

    // Swipe left
    await carousel.dispatchEvent('touchstart', {
      touches: [{ clientX: 300, clientY: 200 }]
    })
    await carousel.dispatchEvent('touchmove', {
      touches: [{ clientX: 100, clientY: 200 }]
    })
    await carousel.dispatchEvent('touchend', {})

    // Verify next slide
    await expect(page.locator('.slide[data-index="1"]')).toBeVisible()
  })

  test('should have touch-friendly tap targets', async ({ page }) => {
    await page.goto('/')

    // All interactive elements should be at least 44x44 pixels
    const buttons = await page.locator('button, a, [role="button"]').all()

    for (const button of buttons) {
      const box = await button.boundingBox()
      if (box) {
        expect(box.width).toBeGreaterThanOrEqual(44)
        expect(box.height).toBeGreaterThanOrEqual(44)
      }
    }
  })
})
```

### Hover State Testing
```typescript
test.describe('Hover States', () => {
  test('hover effects only on non-touch devices', async ({ page }) => {
    // Desktop with mouse
    await page.setViewportSize({ width: 1200, height: 800 })
    await page.goto('/')

    const button = page.locator('.hover-button')

    // Hover should change style
    await button.hover()
    await expect(button).toHaveCSS('background-color', 'rgb(0, 100, 200)')
  })

  test('no hover dependency on mobile', async ({ browser }) => {
    const context = await browser.newContext({
      hasTouch: true,
      isMobile: true,
      viewport: { width: 375, height: 667 }
    })
    const page = await context.newPage()

    await page.goto('/')

    // Elements should be accessible without hover
    const dropdown = page.locator('.dropdown-trigger')
    await dropdown.tap()

    await expect(page.locator('.dropdown-menu')).toBeVisible()

    await context.close()
  })
})
```

## Orientation Testing

### Portrait vs Landscape
```typescript
test.describe('Orientation', () => {
  test('should handle orientation change', async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 375, height: 667 },
      isMobile: true
    })
    const page = await context.newPage()

    await page.goto('/video-player')

    // Portrait
    await expect(page.locator('.video-container')).toHaveCSS('height', '211px')

    // Rotate to landscape
    await page.setViewportSize({ width: 667, height: 375 })

    // Video should expand
    await expect(page.locator('.video-container')).toHaveCSS('height', '375px')

    await context.close()
  })

  test('should maintain usability in both orientations', async ({ page }) => {
    const orientations = [
      { width: 375, height: 667, name: 'portrait' },
      { width: 667, height: 375, name: 'landscape' }
    ]

    for (const { width, height, name } of orientations) {
      await page.setViewportSize({ width, height })
      await page.goto('/dashboard')

      // Critical elements should always be visible
      await expect(page.locator('header')).toBeVisible()
      await expect(page.locator('.main-content')).toBeVisible()

      // Take screenshot for visual review
      await expect(page).toHaveScreenshot(`dashboard-${name}.png`)
    }
  })
})
```

## Container Query Testing

### Modern Container Queries
```typescript
test.describe('Container Queries', () => {
  test('card layout changes based on container size', async ({ page }) => {
    await page.goto('/cards')

    // In narrow container
    const narrowContainer = page.locator('.narrow-container .card')
    await expect(narrowContainer).toHaveCSS('flex-direction', 'column')

    // In wide container
    const wideContainer = page.locator('.wide-container .card')
    await expect(wideContainer).toHaveCSS('flex-direction', 'row')
  })
})
```

## Responsive Images

### Image Srcset Testing
```typescript
test.describe('Responsive Images', () => {
  test('should load appropriate image size', async ({ page }) => {
    // Mobile viewport
    await page.setViewportSize({ width: 375, height: 667 })

    const mobileImageRequest = page.waitForRequest((req) =>
      req.url().includes('hero') && req.url().includes('w=375')
    )

    await page.goto('/')
    await mobileImageRequest

    // Desktop viewport
    await page.setViewportSize({ width: 1920, height: 1080 })

    const desktopImageRequest = page.waitForRequest((req) =>
      req.url().includes('hero') && req.url().includes('w=1920')
    )

    await page.reload()
    await desktopImageRequest
  })

  test('images should have correct aspect ratios', async ({ page }) => {
    await page.goto('/')

    const images = await page.locator('img').all()

    for (const img of images) {
      const box = await img.boundingBox()
      if (box) {
        // Images should maintain aspect ratio (not stretched)
        const natural = await img.evaluate((el: HTMLImageElement) => ({
          width: el.naturalWidth,
          height: el.naturalHeight
        }))

        const displayRatio = box.width / box.height
        const naturalRatio = natural.width / natural.height

        // Allow 5% tolerance
        expect(Math.abs(displayRatio - naturalRatio)).toBeLessThan(0.05)
      }
    }
  })
})
```

## Accessibility at Different Sizes

### Touch Target Sizes
```typescript
test('touch targets meet minimum size requirements', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 667 })
  await page.goto('/')

  const interactiveElements = await page.locator('button, a, input, select').all()

  for (const element of interactiveElements) {
    const box = await element.boundingBox()
    if (box && box.width > 0 && box.height > 0) {
      // WCAG 2.5.5 - Target Size (Enhanced): 44x44px minimum
      expect(box.width).toBeGreaterThanOrEqual(44)
      expect(box.height).toBeGreaterThanOrEqual(44)
    }
  }
})
```

### Readable Text at All Sizes
```typescript
test('text should be readable at all viewport sizes', async ({ page }) => {
  const viewports = [
    { width: 320, height: 568 },
    { width: 768, height: 1024 },
    { width: 1920, height: 1080 }
  ]

  for (const viewport of viewports) {
    await page.setViewportSize(viewport)
    await page.goto('/')

    // Body text should be at least 16px
    const bodyFontSize = await page.evaluate(() => {
      const body = document.querySelector('body')
      return body ? parseFloat(window.getComputedStyle(body).fontSize) : 0
    })

    expect(bodyFontSize).toBeGreaterThanOrEqual(16)

    // Line length should be reasonable (45-75 characters)
    const lineWidth = await page.evaluate(() => {
      const paragraph = document.querySelector('p')
      return paragraph ? paragraph.offsetWidth : 0
    })

    // At 16px, 75 chars ~= 600px max
    expect(lineWidth).toBeLessThan(700)
  }
})
```

## CI/CD Integration

### Multi-Viewport Test Matrix
```yaml
name: Responsive Tests
on: [push, pull_request]

jobs:
  responsive:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        viewport:
          - { name: 'mobile', width: 375, height: 667 }
          - { name: 'tablet', width: 768, height: 1024 }
          - { name: 'desktop', width: 1920, height: 1080 }

    steps:
      - uses: actions/checkout@v4

      - name: Run tests for ${{ matrix.viewport.name }}
        run: |
          npx playwright test --project=${{ matrix.viewport.name }}

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: screenshots-${{ matrix.viewport.name }}
          path: test-results/
```

## Best Practices

1. **Mobile-first development** - Start with smallest viewport
2. **Test real devices** - Emulation misses some issues
3. **Content-based breakpoints** - Let content dictate breakpoints
4. **Flexible images** - Use srcset and picture elements
5. **Touch-friendly** - 44px minimum touch targets
6. **No horizontal scroll** - Content should fit viewport
7. **Readable text** - Minimum 16px, appropriate line length
8. **Test orientation** - Both portrait and landscape
9. **Performance on mobile** - Bandwidth and CPU constraints
10. **Accessible at all sizes** - Don't sacrifice a11y for mobile
