---
name: ios-accessibility-testing
description: iOS accessibility testing for VoiceOver, Dynamic Type, color contrast, and WCAG compliance. Use when validating iOS app accessibility, testing assistive technology support, or ensuring inclusive design.
license: MIT
---

# iOS Accessibility Testing

Comprehensive guide for testing iOS app accessibility features and WCAG compliance.

## VoiceOver Testing

### Programmatic VoiceOver Validation
```swift
import XCTest

class VoiceOverTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        app = XCUIApplication()
        app.launch()
    }

    func testVoiceOverLabels() throws {
        // Verify accessibility labels exist
        let loginButton = app.buttons["login-button"]
        XCTAssertNotNil(loginButton.label, "Login button should have accessibility label")
        XCTAssertEqual(loginButton.label, "Sign in to your account")

        // Check for meaningful labels (not generic)
        XCTAssertFalse(loginButton.label.isEmpty)
        XCTAssertFalse(loginButton.label.lowercased().contains("button"))
    }

    func testVoiceOverHints() throws {
        let searchField = app.searchFields["search-field"]

        // Verify accessibility hint provides additional context
        XCTAssertNotNil(searchField.value(forKey: "accessibilityHint"))
    }

    func testAccessibilityTraits() throws {
        // Verify correct traits are set
        let element = app.buttons["submit"]
        let traits = element.accessibilityTraits

        XCTAssertTrue(traits.contains(.button), "Should have button trait")
    }

    func testNavigationOrder() throws {
        // Verify logical navigation order
        let elements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isAccessibilityElement == true"))
            .allElementsBoundByIndex

        // Check reading order follows visual layout
        var previousFrame = CGRect.zero
        for element in elements where element.isHittable {
            let frame = element.frame
            // Top-to-bottom, left-to-right order
            XCTAssertTrue(
                frame.minY >= previousFrame.minY - 10 || frame.minX > previousFrame.maxX,
                "Elements should follow logical reading order"
            )
            previousFrame = frame
        }
    }
}
```

### Manual VoiceOver Testing Checklist
```markdown
## VoiceOver Testing Protocol

### Navigation
- [ ] All interactive elements are reachable via swipe
- [ ] Focus order matches visual reading order
- [ ] Container groups are properly labeled
- [ ] Custom actions are discoverable (rotor)

### Labels
- [ ] All images have meaningful alt text
- [ ] Buttons describe their action, not appearance
- [ ] Form fields announce their purpose
- [ ] State changes are announced

### Traits
- [ ] Buttons have .button trait
- [ ] Headers have .header trait
- [ ] Links have .link trait
- [ ] Selected state is communicated

### Actions
- [ ] Custom gestures have VoiceOver alternatives
- [ ] Drag-and-drop has accessible alternative
- [ ] Double-tap activates focused element
```

## Dynamic Type Testing

### Programmatic Testing
```swift
class DynamicTypeTests: XCTestCase {
    var app: XCUIApplication!

    func testExtraExtraExtraLargeText() throws {
        // Launch with accessibility size
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        // Verify text is visible and not truncated
        let titleLabel = app.staticTexts["main-title"]
        XCTAssertTrue(titleLabel.exists)
        XCTAssertTrue(titleLabel.isHittable, "Title should be visible at XXXL size")

        // Check for text truncation indicators
        XCTAssertFalse(titleLabel.label.contains("..."), "Text should not be truncated")
    }

    func testAllDynamicTypeSizes() throws {
        let sizes = [
            "UICTContentSizeCategoryExtraSmall",
            "UICTContentSizeCategorySmall",
            "UICTContentSizeCategoryMedium",
            "UICTContentSizeCategoryLarge",
            "UICTContentSizeCategoryExtraLarge",
            "UICTContentSizeCategoryExtraExtraLarge",
            "UICTContentSizeCategoryExtraExtraExtraLarge",
            "UICTContentSizeCategoryAccessibilityMedium",
            "UICTContentSizeCategoryAccessibilityLarge",
            "UICTContentSizeCategoryAccessibilityExtraLarge",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]

        for size in sizes {
            app = XCUIApplication()
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size]
            app.launch()

            // Capture screenshot for visual review
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "DynamicType-\(size)"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Verify UI is usable
            XCTAssertTrue(app.buttons["primary-action"].isHittable,
                         "Primary action should be accessible at \(size)")

            app.terminate()
        }
    }
}
```

### SwiftUI Dynamic Type Support
```swift
// Production code - proper Dynamic Type support
struct AccessibleText: View {
    var body: some View {
        VStack(spacing: 16) {
            // Uses Dynamic Type automatically
            Text("Headline")
                .font(.headline)

            // Custom font with Dynamic Type scaling
            Text("Custom")
                .font(.custom("MyFont", size: 17, relativeTo: .body))

            // Fixed size (avoid when possible)
            Text("Fixed - Not Recommended")
                .font(.system(size: 14))
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Allow up to XXXL
    }
}
```

## Color Contrast Testing

### WCAG Contrast Requirements
```swift
// Color contrast calculation utility
struct ContrastChecker {
    /// WCAG 2.1 minimum contrast ratios
    static let minimumAANormal = 4.5
    static let minimumAALarge = 3.0
    static let minimumAAANormal = 7.0
    static let minimumAAALarge = 4.5

    static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func adjust(_ value: CGFloat) -> CGFloat {
            return value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
    }

    static func contrastRatio(_ color1: UIColor, _ color2: UIColor) -> CGFloat {
        let l1 = relativeLuminance(color1)
        let l2 = relativeLuminance(color2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func meetsWCAG(_ foreground: UIColor, _ background: UIColor,
                          level: WCAGLevel = .AA, isLargeText: Bool = false) -> Bool {
        let ratio = contrastRatio(foreground, background)
        let minimum: CGFloat

        switch (level, isLargeText) {
        case (.AA, false): minimum = minimumAANormal
        case (.AA, true): minimum = minimumAALarge
        case (.AAA, false): minimum = minimumAAANormal
        case (.AAA, true): minimum = minimumAAALarge
        }

        return ratio >= minimum
    }

    enum WCAGLevel { case AA, AAA }
}

// Usage in tests
func testColorContrast() {
    let textColor = UIColor(named: "TextPrimary")!
    let backgroundColor = UIColor(named: "Background")!

    let ratio = ContrastChecker.contrastRatio(textColor, backgroundColor)
    XCTAssertGreaterThanOrEqual(ratio, 4.5,
        "Text contrast ratio \(ratio) is below WCAG AA minimum 4.5:1")
}
```

### Automated Color Scanning
```swift
class ColorContrastTests: XCTestCase {
    func testCriticalUIContrast() throws {
        let app = XCUIApplication()
        app.launch()

        // Capture screenshot for color analysis
        let screenshot = app.screenshot()

        // Use Accessibility Inspector or custom analysis
        // Note: Full programmatic color extraction requires private APIs
        // or visual testing tools like Percy/Chromatic

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Color-Contrast-Audit"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

## Reduce Motion Testing

```swift
class ReduceMotionTests: XCTestCase {
    func testReduceMotionEnabled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIReduceMotionEnabled", "YES"]
        app.launch()

        // Trigger animation
        app.buttons["show-modal"].tap()

        // Verify instant transition (no animation delay)
        let modal = app.otherElements["modal-view"]
        XCTAssertTrue(modal.waitForExistence(timeout: 0.5),
            "Modal should appear immediately with reduce motion")
    }

    func testAnimationsDisabled() throws {
        // Verify no motion sickness triggers
        let app = XCUIApplication()
        app.launchArguments = ["-UIReduceMotionEnabled", "YES"]
        app.launch()

        // Check parallax effects are disabled
        // Check auto-playing videos are paused
        // Verify carousel doesn't auto-scroll
    }
}
```

## Increase Contrast Testing

```swift
class IncreaseContrastTests: XCTestCase {
    func testHighContrastMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityDarkerSystemColorsEnabled", "YES"]
        app.launch()

        // Verify high contrast colors are used
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "High-Contrast-Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

## Keyboard Navigation Testing

```swift
class KeyboardNavigationTests: XCTestCase {
    func testKeyboardFocusOrder() throws {
        let app = XCUIApplication()
        app.launch()

        // Connect hardware keyboard in simulator
        // Tab through interface
        let emailField = app.textFields["email"]
        let passwordField = app.secureTextFields["password"]
        let submitButton = app.buttons["submit"]

        emailField.tap()

        // Simulate Tab key (requires hardware keyboard)
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(passwordField.hasFocus)

        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(submitButton.hasFocus)
    }

    func testFocusIndicator() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify focus ring is visible
        let focusedElement = app.buttons.firstMatch
        focusedElement.tap()

        // Visual verification via screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Focus-Indicator"
        add(attachment)
    }
}
```

## Accessibility Audit Integration

### Using Accessibility Inspector Programmatically
```swift
// Run accessibility audit via xctrace
// xctrace record --template 'Accessibility' --device 'iPhone 15' --attach 'YourApp'

class AccessibilityAuditTests: XCTestCase {
    func performAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        // iOS 17+ built-in audit
        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    func testAccessibilityAuditForScreen(_ screenName: String) throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to screen
        app.buttons[screenName].tap()

        // Capture for manual audit
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Audit-\(screenName)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Verify no critical issues
        let issues = auditScreen(app)
        XCTAssertTrue(issues.filter { $0.severity == .critical }.isEmpty,
                     "Critical accessibility issues found: \(issues)")
    }
}
```

## WCAG 2.1 Compliance Checklist

```markdown
## Level A (Minimum)
- [ ] 1.1.1 Non-text Content - Images have alt text
- [ ] 1.3.1 Info and Relationships - Headings, lists marked up
- [ ] 1.4.1 Use of Color - Not sole means of conveying info
- [ ] 2.1.1 Keyboard - All functionality keyboard accessible
- [ ] 2.4.1 Bypass Blocks - Skip navigation option
- [ ] 3.1.1 Language of Page - Language specified
- [ ] 4.1.2 Name, Role, Value - Elements properly identified

## Level AA (Target)
- [ ] 1.4.3 Contrast (Minimum) - 4.5:1 normal, 3:1 large text
- [ ] 1.4.4 Resize Text - 200% zoom without loss
- [ ] 1.4.10 Reflow - Content reflows at 320px width
- [ ] 1.4.11 Non-text Contrast - 3:1 for UI components
- [ ] 2.4.6 Headings and Labels - Descriptive
- [ ] 2.4.7 Focus Visible - Keyboard focus indicator
- [ ] 3.2.3 Consistent Navigation - Same order across pages
- [ ] 3.2.4 Consistent Identification - Same components labeled consistently

## Level AAA (Enhanced)
- [ ] 1.4.6 Contrast (Enhanced) - 7:1 normal, 4.5:1 large
- [ ] 2.4.9 Link Purpose - All links self-describing
- [ ] 2.4.10 Section Headings - Content organized with headings
```

## Best Practices

1. **Test with real assistive technologies** - Simulator testing is not sufficient
2. **Include users with disabilities** - Recruit for usability testing
3. **Support both VoiceOver and Switch Control** - Different interaction patterns
4. **Test all Dynamic Type sizes** - Including accessibility sizes
5. **Verify color is not the only indicator** - Use shapes, patterns, text
6. **Provide text alternatives** - For all meaningful images
7. **Maintain logical focus order** - Tab/swipe navigation follows visual flow
8. **Announce state changes** - Use UIAccessibility notifications
