---
name: ios-visual-testing
description: iOS visual regression testing with swift-snapshot-testing, multi-device validation, and trait variation testing. Use when testing SwiftUI/UIKit visual appearance, validating design systems, or catching UI regressions.
license: MIT
version: 1.0.0
category: visual-testing
platforms:
  - ios
frameworks:
  - swift-snapshot-testing
  - SwiftUI
  - UIKit
tags:
  - ios
  - visual-testing
  - snapshot
  - regression
  - mobile
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: verified
---

# iOS Visual Regression Testing

Comprehensive guide for visual testing of iOS apps using swift-snapshot-testing and best practices.

## swift-snapshot-testing Setup

### Installation
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
]

// In test target
.testTarget(
    name: "AppTests",
    dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

### Basic Usage
```swift
import XCTest
import SnapshotTesting

class ViewSnapshotTests: XCTestCase {

    func testLoginView() {
        let view = LoginView()

        assertSnapshot(of: view, as: .image)
    }

    func testLoginViewController() {
        let vc = LoginViewController()

        assertSnapshot(of: vc, as: .image)
    }
}
```

## Multi-Device Testing

### Device Configuration
```swift
import SnapshotTesting
import SwiftUI

extension ViewImageConfig {
    // iPhone devices
    static let iPhone15Pro = ViewImageConfig.iPhone15Pro
    static let iPhone15 = ViewImageConfig.iPhone15
    static let iPhoneSE = ViewImageConfig.iPhoneSe
    static let iPhone13Mini = ViewImageConfig.iPhone13Mini

    // iPad devices
    static let iPadPro12_9 = ViewImageConfig.iPadPro12_9
    static let iPadPro11 = ViewImageConfig.iPadPro11
    static let iPadMini = ViewImageConfig.iPadMini
}

class MultiDeviceSnapshotTests: XCTestCase {

    func testViewOnMultipleDevices() {
        let view = ProfileView()

        // Test on key devices
        assertSnapshot(of: view, as: .image(on: .iPhone15Pro), named: "iPhone15Pro")
        assertSnapshot(of: view, as: .image(on: .iPhoneSE), named: "iPhoneSE")
        assertSnapshot(of: view, as: .image(on: .iPadPro12_9), named: "iPadPro")
    }

    func testAcrossDeviceMatrix() {
        let view = DashboardView()

        let devices: [(String, ViewImageConfig)] = [
            ("iPhone15Pro", .iPhone15Pro),
            ("iPhone15", .iPhone15),
            ("iPhoneSE", .iPhoneSe),
            ("iPadPro12_9", .iPadPro12_9),
            ("iPadMini", .iPadMini)
        ]

        for (name, config) in devices {
            assertSnapshot(of: view, as: .image(on: config), named: name)
        }
    }
}
```

### Orientation Testing
```swift
class OrientationSnapshotTests: XCTestCase {

    func testLandscapeOrientation() {
        let view = VideoPlayerView()

        // Portrait
        assertSnapshot(
            of: view,
            as: .image(on: .iPhone15Pro(.portrait)),
            named: "portrait"
        )

        // Landscape
        assertSnapshot(
            of: view,
            as: .image(on: .iPhone15Pro(.landscape)),
            named: "landscape"
        )
    }
}
```

## Dark Mode Testing

### Light/Dark Mode Validation
```swift
class DarkModeSnapshotTests: XCTestCase {

    func testViewInBothModes() {
        let view = SettingsView()

        // Light mode
        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "light"
        )

        // Dark mode
        assertSnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "dark"
        )
    }

    func testAllColorSchemes() {
        let view = DashboardView()

        let modes: [(String, UIUserInterfaceStyle)] = [
            ("light", .light),
            ("dark", .dark)
        ]

        let devices: [(String, ViewImageConfig)] = [
            ("iPhone15Pro", .iPhone15Pro),
            ("iPadPro", .iPadPro12_9)
        ]

        for (modeName, style) in modes {
            for (deviceName, config) in devices {
                assertSnapshot(
                    of: view,
                    as: .image(on: config, traits: .init(userInterfaceStyle: style)),
                    named: "\(deviceName)-\(modeName)"
                )
            }
        }
    }
}
```

## Dynamic Type Testing

### Accessibility Sizes
```swift
class DynamicTypeSnapshotTests: XCTestCase {

    func testDynamicTypeSizes() {
        let view = ArticleView()

        let sizes: [(String, UIContentSizeCategory)] = [
            ("extraSmall", .extraSmall),
            ("small", .small),
            ("medium", .medium),
            ("large", .large),
            ("extraLarge", .extraLarge),
            ("extraExtraLarge", .extraExtraLarge),
            ("extraExtraExtraLarge", .extraExtraExtraLarge),
            ("accessibilityMedium", .accessibilityMedium),
            ("accessibilityLarge", .accessibilityLarge),
            ("accessibilityExtraLarge", .accessibilityExtraLarge),
            ("accessibilityExtraExtraLarge", .accessibilityExtraExtraLarge),
            ("accessibilityExtraExtraExtraLarge", .accessibilityExtraExtraExtraLarge)
        ]

        for (name, size) in sizes {
            assertSnapshot(
                of: view,
                as: .image(traits: .init(preferredContentSizeCategory: size)),
                named: name
            )
        }
    }

    func testCriticalSizes() {
        let view = LoginView()

        // Test extremes
        assertSnapshot(
            of: view,
            as: .image(traits: .init(preferredContentSizeCategory: .extraSmall)),
            named: "extraSmall"
        )

        assertSnapshot(
            of: view,
            as: .image(traits: .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)),
            named: "accessibility3XL"
        )
    }
}
```

## Trait Variation Testing

### Combined Traits
```swift
class TraitVariationTests: XCTestCase {

    func testTraitCombinations() {
        let view = ComplexView()

        // Accessibility + Dark Mode
        let traits = UITraitCollection(traitsFrom: [
            .init(userInterfaceStyle: .dark),
            .init(preferredContentSizeCategory: .accessibilityLarge),
            .init(accessibilityContrast: .high)
        ])

        assertSnapshot(
            of: view,
            as: .image(traits: traits),
            named: "dark-a11yLarge-highContrast"
        )
    }

    func testSizeClasses() {
        let view = AdaptiveView()

        // Compact width
        assertSnapshot(
            of: view,
            as: .image(traits: .init(horizontalSizeClass: .compact)),
            named: "compact"
        )

        // Regular width
        assertSnapshot(
            of: view,
            as: .image(traits: .init(horizontalSizeClass: .regular)),
            named: "regular"
        )
    }
}
```

## SwiftUI Preview Testing

### Testing SwiftUI Views
```swift
import SwiftUI
import SnapshotTesting

class SwiftUISnapshotTests: XCTestCase {

    func testSwiftUIView() {
        let view = ContentView()

        assertSnapshot(of: view, as: .image)
    }

    func testSwiftUIWithEnvironment() {
        let view = ThemedView()
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .accessibility1)

        assertSnapshot(of: view, as: .image)
    }

    func testSwiftUIWithFixedSize() {
        let view = CardView()
            .frame(width: 300, height: 200)

        assertSnapshot(of: view, as: .image)
    }
}
```

### Preview Snapshots
```swift
// Use previews as test source
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.sizeThatFits)

        ContentView()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}

class PreviewSnapshotTests: XCTestCase {

    func testContentViewPreviews() {
        // Test each preview configuration
        let lightView = ContentView()
        let darkView = ContentView().environment(\.colorScheme, .dark)

        assertSnapshot(of: lightView, as: .image, named: "light")
        assertSnapshot(of: darkView, as: .image, named: "dark")
    }
}
```

## Baseline Management

### Recording Baselines
```swift
class BaselineTests: XCTestCase {

    override func setUp() {
        super.setUp()

        // Record new baselines when needed
        // isRecording = true
    }

    func testWithBaseline() {
        let view = OnboardingView()

        // First run with isRecording = true creates baseline
        // Subsequent runs compare against baseline
        assertSnapshot(of: view, as: .image)
    }
}
```

### CI Configuration
```swift
// Environment-based recording
extension XCTestCase {
    var isRecordingSnapshots: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"
    }
}

class CISnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = isRecordingSnapshots
    }

    func testView() {
        assertSnapshot(of: MyView(), as: .image)
    }
}
```

## Device-Specific Layouts

### Notch and Dynamic Island
```swift
class SafeAreaSnapshotTests: XCTestCase {

    func testSafeAreaHandling() {
        let view = FullScreenView()

        // iPhone 15 Pro (Dynamic Island)
        assertSnapshot(
            of: view,
            as: .image(on: .iPhone15Pro),
            named: "dynamicIsland"
        )

        // iPhone SE (No notch)
        assertSnapshot(
            of: view,
            as: .image(on: .iPhoneSe),
            named: "noNotch"
        )

        // iPhone 14 (Notch)
        assertSnapshot(
            of: view,
            as: .image(on: .iPhone14),
            named: "notch"
        )
    }
}
```

## Component Library Testing

### Design System Validation
```swift
class DesignSystemSnapshotTests: XCTestCase {

    func testAllButtonVariants() {
        let variants: [(String, ButtonStyle)] = [
            ("primary", .primary),
            ("secondary", .secondary),
            ("outline", .outline),
            ("destructive", .destructive),
            ("ghost", .ghost)
        ]

        let states: [(String, Bool, Bool)] = [
            ("default", true, false),
            ("disabled", false, false),
            ("loading", true, true)
        ]

        for (variantName, style) in variants {
            for (stateName, enabled, loading) in states {
                let button = DSButton(
                    title: "Button",
                    style: style,
                    isEnabled: enabled,
                    isLoading: loading
                )

                assertSnapshot(
                    of: button,
                    as: .image,
                    named: "\(variantName)-\(stateName)"
                )
            }
        }
    }

    func testColorPalette() {
        let view = ColorPaletteView()

        assertSnapshot(of: view, as: .image(on: .iPhone15Pro), named: "light")

        assertSnapshot(
            of: view,
            as: .image(on: .iPhone15Pro, traits: .init(userInterfaceStyle: .dark)),
            named: "dark"
        )
    }
}
```

## Diff Generation

### Custom Diff Output
```swift
extension SnapshotTesting.Snapshotting where Value: View, Format == UIImage {
    static func imageDiff(precision: Float = 0.99) -> Snapshotting {
        return .image(precision: precision, perceptualPrecision: 0.98)
    }
}

class DiffTests: XCTestCase {

    func testWithPrecision() {
        let view = AnimatedView()

        // Allow small variations
        assertSnapshot(
            of: view,
            as: .image(precision: 0.95, perceptualPrecision: 0.95)
        )
    }
}
```

## CI/CD Integration

### GitHub Actions
```yaml
name: Visual Regression Tests

on: [pull_request]

jobs:
  snapshots:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true  # For snapshot images

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Snapshot Tests
        run: |
          xcodebuild test \
            -scheme AppTests \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -resultBundlePath SnapshotResults.xcresult

      - name: Upload Failed Diffs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-failures
          path: |
            **/Snapshots/__Snapshots__/**/*
            **/Snapshots/**/*.png
```

### Fastlane Integration
```ruby
lane :snapshot_tests do
  scan(
    scheme: "SnapshotTests",
    devices: ["iPhone 15 Pro"],
    result_bundle: true,
    output_directory: "./snapshot_results"
  )
end

lane :update_snapshots do
  ENV["RECORD_SNAPSHOTS"] = "true"
  scan(
    scheme: "SnapshotTests",
    devices: ["iPhone 15 Pro"]
  )
end
```

## Best Practices

1. **Organize by feature** - Group snapshots by screen/component
2. **Test critical devices** - iPhone SE (smallest), iPhone 15 Pro (latest), iPad
3. **Cover accessibility sizes** - At minimum XS, default, and accessibility sizes
4. **Validate both themes** - Light and dark mode for all views
5. **Use meaningful names** - `iPhone15Pro-dark-a11yLarge` format
6. **Commit baselines** - Store in version control (use Git LFS for large files)
7. **Review diffs carefully** - Visual changes should be intentional
8. **Automate in CI** - Catch regressions before merge
9. **Set precision thresholds** - Allow minor anti-aliasing differences
10. **Document expected changes** - When updating baselines intentionally
