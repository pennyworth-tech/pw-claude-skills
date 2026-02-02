---
name: ios-performance-testing
description: iOS app performance testing with XCTest metrics, Instruments profiling, and launch time optimization. Use when testing iOS app performance, measuring memory usage, or profiling CPU/GPU utilization.
license: MIT
version: 1.0.0
category: performance
platforms:
  - ios
frameworks:
  - XCTest
  - Instruments
tags:
  - ios
  - performance
  - profiling
  - metrics
  - mobile
trust_tier: 0
validation:
  validation_status: pending
---

# iOS Performance Testing

Comprehensive guide for testing and optimizing iOS app performance.

## XCTest Performance Metrics

### Basic Performance Testing
```swift
import XCTest

class PerformanceTests: XCTestCase {

    func testAppLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testAppLaunchToFirstFrame() throws {
        if #available(iOS 14.0, *) {
            let app = XCUIApplication()

            measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
                app.launch()
                // Wait for first interactive frame
                _ = app.buttons["main-action"].waitForExistence(timeout: 10)
            }
        }
    }

    func testScrollPerformance() throws {
        let app = XCUIApplication()
        app.launch()

        let table = app.tables["main-list"]

        measure(metrics: [XCTOSSignpostMetric.scrollDraggingMetric]) {
            table.swipeUp(velocity: .fast)
            table.swipeUp(velocity: .fast)
            table.swipeUp(velocity: .fast)
        }
    }
}
```

### Clock Metrics
```swift
class ClockMetricTests: XCTestCase {

    func testOperationDuration() {
        measure(metrics: [XCTClockMetric()]) {
            // Operation to measure
            performExpensiveOperation()
        }
    }

    func testWithBaseline() {
        let options = XCTMeasureOptions()
        options.iterationCount = 10

        // Set baseline from previous run
        measure(options: options) {
            performExpensiveOperation()
        }
    }

    func performExpensiveOperation() {
        // Simulate work
        Thread.sleep(forTimeInterval: 0.1)
    }
}
```

### Memory Metrics
```swift
class MemoryMetricTests: XCTestCase {

    func testMemoryUsage() {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTMemoryMetric()]) {
                let app = XCUIApplication()
                app.launch()

                // Navigate to memory-intensive screen
                app.buttons["photo-gallery"].tap()

                // Load content
                _ = app.collectionViews["gallery"].waitForExistence(timeout: 10)
            }
        }
    }

    func testPeakMemory() {
        if #available(iOS 14.0, *) {
            let memoryMetric = XCTMemoryMetric()

            measure(metrics: [memoryMetric]) {
                loadLargeDataSet()
            }
        }
    }
}
```

### CPU Metrics
```swift
class CPUMetricTests: XCTestCase {

    func testCPUUsage() {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTCPUMetric()]) {
                performCPUIntensiveTask()
            }
        }
    }

    func testCPUInstructions() {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTCPUMetric()]) {
                // Algorithm comparison
                sortLargeArray()
            }
        }
    }
}
```

## App Launch Time Testing

### Cold Launch
```swift
class LaunchTimeTests: XCTestCase {

    func testColdLaunchTime() throws {
        // Terminate any running instance
        let app = XCUIApplication()
        app.terminate()

        // Clear caches if possible via launch argument
        app.launchArguments = ["--clear-cache"]

        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testWarmLaunchTime() throws {
        let app = XCUIApplication()
        app.launch()
        app.terminate()

        // Warm launch - app data in memory
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testResumeLaunchTime() throws {
        let app = XCUIApplication()
        app.launch()

        // Background the app
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)

        // Measure resume
        measure {
            app.activate()
            _ = app.buttons["main-action"].waitForExistence(timeout: 5)
        }
    }
}
```

### Launch Time Benchmarks
```swift
struct LaunchTimeBenchmarks {
    // Industry standards (2026)
    static let coldLaunchTarget: TimeInterval = 2.0      // < 2 seconds
    static let warmLaunchTarget: TimeInterval = 1.0      // < 1 second
    static let resumeTarget: TimeInterval = 0.5          // < 500ms

    // Time to first frame
    static let ttffTarget: TimeInterval = 0.4            // < 400ms

    // Time to interactive
    static let ttiTarget: TimeInterval = 1.5             // < 1.5 seconds
}
```

## Memory Profiling

### Memory Leak Detection
```swift
class MemoryLeakTests: XCTestCase {

    func testForMemoryLeaks() throws {
        let app = XCUIApplication()
        app.launch()

        // Get initial memory
        let initialMemory = getAppMemoryUsage()

        // Repeat navigation cycle
        for _ in 0..<10 {
            app.buttons["detail-screen"].tap()
            _ = app.navigationBars["Detail"].waitForExistence(timeout: 5)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = app.navigationBars["Main"].waitForExistence(timeout: 5)
        }

        // Force garbage collection
        Thread.sleep(forTimeInterval: 2)

        // Check memory didn't grow significantly
        let finalMemory = getAppMemoryUsage()
        let growth = finalMemory - initialMemory

        // Allow 10% growth for caches
        XCTAssertLessThan(growth, initialMemory * 0.1,
            "Memory grew by \(growth) bytes - possible leak")
    }

    func getAppMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
```

### Peak Memory Testing
```swift
class PeakMemoryTests: XCTestCase {

    func testImageLoadingMemory() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to image-heavy screen
        app.buttons["gallery"].tap()

        measure(metrics: [XCTMemoryMetric()]) {
            // Scroll through gallery
            let gallery = app.collectionViews["photo-gallery"]
            for _ in 0..<5 {
                gallery.swipeUp(velocity: .fast)
            }
        }
    }

    func testMemoryWarningRecovery() throws {
        // Simulate memory pressure via Instruments or private API
        // Verify app handles gracefully
    }
}
```

## Frame Rate Testing

### UI Smoothness
```swift
class FrameRateTests: XCTestCase {

    func testScrollFrameRate() throws {
        if #available(iOS 14.0, *) {
            let app = XCUIApplication()
            app.launch()

            let scrollView = app.scrollViews["main-scroll"]

            measure(metrics: [XCTOSSignpostMetric.scrollDraggingMetric]) {
                for _ in 0..<3 {
                    scrollView.swipeUp(velocity: .fast)
                }
            }
        }
    }

    func testAnimationFrameRate() throws {
        if #available(iOS 14.0, *) {
            let app = XCUIApplication()
            app.launch()

            measure(metrics: [XCTOSSignpostMetric.animationMetric]) {
                app.buttons["animate"].tap()
                Thread.sleep(forTimeInterval: 1) // Wait for animation
            }
        }
    }
}
```

### Frame Drop Detection
```swift
struct FrameRateBenchmarks {
    // 60 FPS target (16.67ms per frame)
    static let targetFrameTime: TimeInterval = 1.0 / 60.0

    // 120 FPS for ProMotion devices
    static let proMotionFrameTime: TimeInterval = 1.0 / 120.0

    // Maximum acceptable frame drops
    static let maxDroppedFramesPercent: Double = 5.0

    // Hitches (frames > 33ms)
    static let hitchThreshold: TimeInterval = 0.033
}
```

## Instruments CLI Integration

### xctrace Commands
```bash
# Record performance trace
xctrace record --template 'Time Profiler' \
    --device 'iPhone 15 Pro' \
    --attach 'com.example.app' \
    --output trace.xcresult \
    --time-limit 30s

# Record with custom template
xctrace record --template 'Custom Performance' \
    --launch 'com.example.app' \
    --output launch-trace.xcresult

# Export trace data
xctrace export --input trace.xcresult \
    --output trace-data.xml \
    --type table-of-contents

# Analyze specific instrument
xctrace symbolicate --input trace.xcresult
```

### Automated Profiling in CI
```swift
class InstrumentsTests: XCTestCase {

    func runTimeProfiler() throws {
        // Use Process to run xctrace
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xctrace")
        process.arguments = [
            "record",
            "--template", "Time Profiler",
            "--device", "iPhone 15 Pro",
            "--attach", "com.example.app",
            "--output", "/tmp/profile.xcresult",
            "--time-limit", "30s"
        ]

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
    }
}
```

## Energy Profiling

### Battery Impact Testing
```swift
class EnergyTests: XCTestCase {

    func testBackgroundEnergyUsage() throws {
        let app = XCUIApplication()
        app.launch()

        // Background the app
        XCUIDevice.shared.press(.home)

        // Let it run in background
        Thread.sleep(forTimeInterval: 60)

        // Check energy impact via Instruments
        // or MetricKit in production
    }

    func testLocationEnergyImpact() throws {
        let app = XCUIApplication()
        app.launch()

        // Enable location tracking
        app.buttons["enable-location"].tap()

        // Run for duration
        Thread.sleep(forTimeInterval: 300)

        // Analyze with Energy Log instrument
    }
}
```

## Network Performance

### Request Latency Testing
```swift
class NetworkPerformanceTests: XCTestCase {

    func testAPIResponseTime() throws {
        let app = XCUIApplication()
        app.launch()

        measure {
            app.buttons["fetch-data"].tap()

            // Wait for response indicator
            let indicator = app.activityIndicators["loading"]
            _ = indicator.waitForExistence(timeout: 1)

            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: indicator
            )

            let result = XCTWaiter().wait(for: [expectation], timeout: 10)
            XCTAssertEqual(result, .completed)
        }
    }
}
```

## CI/CD Integration

### Performance Test Job
```yaml
# GitHub Actions
name: Performance Tests

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'  # Daily

jobs:
  performance:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Run Performance Tests
        run: |
          xcodebuild test \
            -scheme 'PerformanceTests' \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -resultBundlePath PerformanceResults.xcresult

      - name: Extract Metrics
        run: |
          xcrun xcresulttool get metrics \
            --path PerformanceResults.xcresult \
            --format json > metrics.json

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: performance-results
          path: |
            PerformanceResults.xcresult
            metrics.json

      - name: Check Regressions
        run: |
          python scripts/check_performance_regression.py \
            --baseline baseline-metrics.json \
            --current metrics.json \
            --threshold 10
```

### Baseline Management
```swift
// Store baselines in XCTest
class BaselineTests: XCTestCase {

    func testWithBaseline() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        // XCTest automatically manages baselines
        // Set new baseline: Edit Scheme > Test > Options > Baselines
        measure(options: options) {
            performOperation()
        }
    }
}
```

## Performance Targets

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Cold Launch | < 2s | 2-3s | > 3s |
| Warm Launch | < 1s | 1-1.5s | > 1.5s |
| TTI | < 1.5s | 1.5-2.5s | > 2.5s |
| Frame Rate | 60 fps | 55-60 fps | < 55 fps |
| Memory Growth | < 10% | 10-25% | > 25% |
| CPU Idle | < 5% | 5-15% | > 15% |
| Battery/hour | < 10% | 10-20% | > 20% |

## Best Practices

1. **Run on real devices** - Simulator performance differs significantly
2. **Test on oldest supported device** - Ensures acceptable performance for all users
3. **Establish baselines** - Track performance over time
4. **Automate in CI** - Catch regressions early
5. **Profile before optimizing** - Use Instruments to identify real bottlenecks
6. **Test under load** - Low memory, background apps, poor network
7. **Monitor in production** - Use MetricKit for real-world data
8. **Set budgets** - Define acceptable thresholds and enforce them
