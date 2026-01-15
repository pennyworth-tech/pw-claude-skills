---
name: web-performance-testing
description: Web performance testing with Lighthouse, Core Web Vitals, and performance budgets. Use when measuring web performance, optimizing load times, or implementing performance monitoring.
license: MIT
---

# Web Performance Testing

Comprehensive guide for measuring and optimizing web performance.

## Core Web Vitals

### Understanding CWV Metrics
```typescript
// Core Web Vitals thresholds (2026)
const coreWebVitals = {
  // Largest Contentful Paint - Loading performance
  LCP: {
    good: 2500,        // <= 2.5s
    needsImprovement: 4000,  // 2.5s - 4s
    poor: Infinity     // > 4s
  },

  // First Input Delay (being replaced by INP)
  FID: {
    good: 100,         // <= 100ms
    needsImprovement: 300,
    poor: Infinity
  },

  // Interaction to Next Paint (replacing FID in 2024)
  INP: {
    good: 200,         // <= 200ms
    needsImprovement: 500,
    poor: Infinity
  },

  // Cumulative Layout Shift - Visual stability
  CLS: {
    good: 0.1,         // <= 0.1
    needsImprovement: 0.25,
    poor: Infinity
  }
}
```

### Measuring CWV Programmatically
```typescript
// Using web-vitals library
import { onLCP, onFID, onCLS, onINP, onTTFB } from 'web-vitals'

const metrics: Record<string, number> = {}

onLCP((metric) => {
  metrics.LCP = metric.value
  console.log('LCP:', metric.value, metric.rating)
})

onFID((metric) => {
  metrics.FID = metric.value
})

onINP((metric) => {
  metrics.INP = metric.value
})

onCLS((metric) => {
  metrics.CLS = metric.value
})

onTTFB((metric) => {
  metrics.TTFB = metric.value
})
```

## Lighthouse CLI

### Basic Usage
```bash
# Run Lighthouse audit
npx lighthouse https://example.com --output=json --output-path=./report.json

# With specific categories
npx lighthouse https://example.com \
  --only-categories=performance,accessibility,best-practices \
  --output=html \
  --output-path=./report.html

# Headless mode
npx lighthouse https://example.com \
  --chrome-flags="--headless" \
  --output=json
```

### Programmatic Usage
```typescript
import lighthouse from 'lighthouse'
import * as chromeLauncher from 'chrome-launcher'

async function runLighthouse(url: string) {
  const chrome = await chromeLauncher.launch({ chromeFlags: ['--headless'] })

  const options = {
    logLevel: 'info',
    output: 'json',
    onlyCategories: ['performance'],
    port: chrome.port
  }

  const result = await lighthouse(url, options)

  await chrome.kill()

  return result?.lhr
}

// Usage
const report = await runLighthouse('https://example.com')
console.log('Performance score:', report?.categories.performance.score * 100)
```

### Lighthouse in Tests
```typescript
import { test, expect } from '@playwright/test'
import lighthouse from 'lighthouse'
import { chromium } from 'playwright'

test.describe('Performance', () => {
  test('should meet performance thresholds', async () => {
    const browser = await chromium.launch()
    const port = (browser as any)._browserContext._browser._port

    const result = await lighthouse('http://localhost:3000', {
      port,
      output: 'json',
      onlyCategories: ['performance']
    })

    const performanceScore = result?.lhr.categories.performance.score * 100

    expect(performanceScore).toBeGreaterThanOrEqual(90)

    // Check specific metrics
    const metrics = result?.lhr.audits
    expect(metrics['largest-contentful-paint'].numericValue).toBeLessThan(2500)
    expect(metrics['cumulative-layout-shift'].numericValue).toBeLessThan(0.1)
    expect(metrics['total-blocking-time'].numericValue).toBeLessThan(300)

    await browser.close()
  })
})
```

## Performance Budgets

### Budget Configuration
```json
// performance-budget.json
{
  "budgets": [
    {
      "resourceSizes": [
        { "resourceType": "script", "budget": 300 },
        { "resourceType": "stylesheet", "budget": 100 },
        { "resourceType": "image", "budget": 500 },
        { "resourceType": "font", "budget": 100 },
        { "resourceType": "total", "budget": 1000 }
      ],
      "resourceCounts": [
        { "resourceType": "script", "budget": 10 },
        { "resourceType": "stylesheet", "budget": 5 }
      ],
      "timings": [
        { "metric": "interactive", "budget": 3000 },
        { "metric": "first-contentful-paint", "budget": 1500 },
        { "metric": "largest-contentful-paint", "budget": 2500 }
      ]
    }
  ]
}
```

### Lighthouse with Budgets
```bash
npx lighthouse https://example.com \
  --budget-path=./performance-budget.json \
  --output=json
```

### CI Budget Enforcement
```typescript
import { test, expect } from '@playwright/test'

const PERFORMANCE_BUDGETS = {
  LCP: 2500,
  FID: 100,
  CLS: 0.1,
  TTFB: 800,
  TBT: 300,
  bundleSize: 300 * 1024, // 300KB JS
  imageSize: 500 * 1024   // 500KB images
}

test('should meet performance budgets', async ({ page }) => {
  await page.goto('/')

  // Measure with Performance Observer
  const metrics = await page.evaluate(() => {
    return new Promise(resolve => {
      const data: Record<string, number> = {}

      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'largest-contentful-paint') {
            data.LCP = entry.startTime
          }
        }
      }).observe({ entryTypes: ['largest-contentful-paint'] })

      // Wait for page to be fully loaded
      setTimeout(() => resolve(data), 5000)
    })
  })

  expect(metrics.LCP).toBeLessThan(PERFORMANCE_BUDGETS.LCP)
})
```

## Bundle Analysis

### Webpack Bundle Analyzer
```bash
npm install -D webpack-bundle-analyzer

# Generate stats
npx webpack --profile --json > stats.json

# Analyze
npx webpack-bundle-analyzer stats.json
```

### Source Map Explorer
```bash
npm install -D source-map-explorer

# Generate production build with source maps
npm run build

# Analyze bundle
npx source-map-explorer dist/main.*.js
```

### Bundle Size Testing
```typescript
import { test, expect } from '@playwright/test'
import { stat } from 'fs/promises'
import { glob } from 'glob'

test.describe('Bundle size', () => {
  test('JavaScript bundles should be under budget', async () => {
    const jsFiles = await glob('dist/**/*.js')

    let totalSize = 0
    for (const file of jsFiles) {
      const stats = await stat(file)
      totalSize += stats.size
    }

    const totalKB = totalSize / 1024

    // 300KB budget for JS
    expect(totalKB).toBeLessThan(300)
  })

  test('CSS should be under budget', async () => {
    const cssFiles = await glob('dist/**/*.css')

    let totalSize = 0
    for (const file of cssFiles) {
      const stats = await stat(file)
      totalSize += stats.size
    }

    const totalKB = totalSize / 1024

    // 100KB budget for CSS
    expect(totalKB).toBeLessThan(100)
  })
})
```

## Real User Monitoring (RUM)

### Performance Observer API
```typescript
// Collect real performance data
function initRUM() {
  // Navigation timing
  const observer = new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      sendToAnalytics('performance', {
        name: entry.name,
        value: entry.startTime,
        type: entry.entryType
      })
    }
  })

  observer.observe({
    entryTypes: [
      'largest-contentful-paint',
      'first-input',
      'layout-shift',
      'longtask',
      'navigation',
      'resource'
    ]
  })
}

// Send to analytics
function sendToAnalytics(event: string, data: Record<string, any>) {
  // Send to your analytics service
  fetch('/api/analytics', {
    method: 'POST',
    body: JSON.stringify({ event, ...data }),
    headers: { 'Content-Type': 'application/json' }
  })
}
```

### Analyzing RUM Data
```typescript
// Backend aggregation
interface PerformanceData {
  p50: number
  p75: number
  p90: number
  p95: number
  p99: number
}

function calculatePercentiles(values: number[]): PerformanceData {
  const sorted = [...values].sort((a, b) => a - b)
  const percentile = (p: number) => sorted[Math.floor(sorted.length * p)]

  return {
    p50: percentile(0.5),
    p75: percentile(0.75),
    p90: percentile(0.90),
    p95: percentile(0.95),
    p99: percentile(0.99)
  }
}
```

## Load Testing

### K6 Performance Testing
```javascript
// load-test.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up
    { duration: '1m', target: 20 },    // Stay at 20
    { duration: '30s', target: 50 },   // Ramp up more
    { duration: '1m', target: 50 },    // Stay at 50
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests < 500ms
    http_req_failed: ['rate<0.01'],    // <1% failures
  },
}

export default function () {
  const res = http.get('https://example.com/api/data')

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  })

  sleep(1)
}
```

### Running Load Tests
```bash
# Run load test
k6 run load-test.js

# With HTML report
k6 run --out json=results.json load-test.js
```

## Image Performance

### Image Optimization Testing
```typescript
test.describe('Image Performance', () => {
  test('images should use modern formats', async ({ page }) => {
    await page.goto('/')

    const images = await page.evaluate(() => {
      return Array.from(document.images).map(img => ({
        src: img.currentSrc,
        format: img.currentSrc.split('.').pop()?.split('?')[0]
      }))
    })

    for (const img of images) {
      const format = img.format?.toLowerCase()
      expect(['webp', 'avif', 'svg']).toContain(format)
    }
  })

  test('images should be lazy loaded', async ({ page }) => {
    await page.goto('/')

    const belowFoldImages = await page.evaluate(() => {
      const viewportHeight = window.innerHeight
      return Array.from(document.images)
        .filter(img => img.getBoundingClientRect().top > viewportHeight)
        .map(img => img.loading)
    })

    for (const loading of belowFoldImages) {
      expect(loading).toBe('lazy')
    }
  })

  test('images should be properly sized', async ({ page }) => {
    await page.goto('/')

    const oversizedImages = await page.evaluate(() => {
      return Array.from(document.images)
        .filter(img => {
          const rect = img.getBoundingClientRect()
          return img.naturalWidth > rect.width * 2 ||
                 img.naturalHeight > rect.height * 2
        })
        .map(img => img.src)
    })

    expect(oversizedImages).toHaveLength(0)
  })
})
```

## CI/CD Integration

### GitHub Actions Workflow
```yaml
name: Performance Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Start server
        run: npm run preview &

      - name: Wait for server
        run: npx wait-on http://localhost:4173

      - name: Run Lighthouse
        uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            http://localhost:4173
            http://localhost:4173/about
          budgetPath: ./performance-budget.json
          uploadArtifacts: true

      - name: Assert performance
        run: |
          SCORE=$(cat .lighthouseci/lhr-*.json | jq '.categories.performance.score')
          if (( $(echo "$SCORE < 0.9" | bc -l) )); then
            echo "Performance score $SCORE is below 90%"
            exit 1
          fi
```

## Performance Targets

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP | < 2.5s | 2.5s - 4s | > 4s |
| FID | < 100ms | 100ms - 300ms | > 300ms |
| INP | < 200ms | 200ms - 500ms | > 500ms |
| CLS | < 0.1 | 0.1 - 0.25 | > 0.25 |
| TTFB | < 800ms | 800ms - 1800ms | > 1800ms |
| FCP | < 1.8s | 1.8s - 3s | > 3s |
| TTI | < 3.8s | 3.8s - 7.3s | > 7.3s |
| TBT | < 200ms | 200ms - 600ms | > 600ms |

## Best Practices

1. **Test real devices** - Lab data differs from field
2. **Monitor continuously** - Track trends over time
3. **Set budgets** - Enforce limits in CI
4. **Optimize images** - Largest impact for most sites
5. **Code split** - Load only what's needed
6. **Preconnect** - Reduce connection time
7. **Cache aggressively** - Reduce repeat load time
8. **Use CDN** - Geographic distribution
9. **Compress assets** - Gzip/Brotli everything
10. **Defer non-critical** - Prioritize above-fold content
