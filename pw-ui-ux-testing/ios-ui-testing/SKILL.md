---
name: ios-ui-testing
description: iOS UI testing with XCTest/XCUITest for native app automation, gesture testing, and multi-device validation. Use when testing iOS apps, implementing UI automation, or validating user flows on iPhone/iPad.
license: MIT
---

# iOS UI Testing with XCTest/XCUITest

Comprehensive patterns and techniques for testing iOS native app interfaces.

## XCUITest Fundamentals

### Test Structure
```swift
import XCTest

class LoginUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testLoginFlow() throws {
        // Arrange
        let emailField = app.textFields["email-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]

        // Act
        emailField.tap()
        emailField.typeText("test@example.com")
        passwordField.tap()
        passwordField.typeText("password123")
        loginButton.tap()

        // Assert
        let welcomeLabel = app.staticTexts["welcome-label"]
        XCTAssertTrue(welcomeLabel.waitForExistence(timeout: 5))
    }
}
```

## Element Identification Strategies

### Accessibility Identifiers (Recommended)
```swift
// In production code
emailTextField.accessibilityIdentifier = "email-field"

// In test code
let emailField = app.textFields["email-field"]
```

### Predicate-Based Queries
```swift
// Label contains text
let predicate = NSPredicate(format: "label CONTAINS 'Submit'")
let button = app.buttons.matching(predicate).firstMatch

// Multiple conditions
let complexPredicate = NSPredicate(format: "label BEGINSWITH 'User' AND isEnabled == true")
let elements = app.staticTexts.matching(complexPredicate)
```

### Element Type Queries
```swift
// By type
app.buttons["submit"]
app.textFields["username"]
app.secureTextFields["password"]
app.staticTexts["welcome-message"]
app.images["profile-avatar"]
app.switches["notifications-toggle"]
app.sliders["volume-slider"]
app.cells["settings-row"]
app.tables["main-table"]
app.collectionViews["photo-gallery"]
app.navigationBars["Settings"]
app.tabBars["main-tab-bar"]
app.alerts["error-alert"]
app.sheets["action-sheet"]
```

## Gesture Testing

### Basic Gestures
```swift
// Tap
element.tap()
element.doubleTap()

// Long press
element.press(forDuration: 2.0)

// Swipe
element.swipeLeft()
element.swipeRight()
element.swipeUp()
element.swipeDown()

// Custom swipe with velocity
let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
start.press(forDuration: 0.1, thenDragTo: end)
```

### Pinch and Rotate
```swift
// Pinch (zoom)
element.pinch(withScale: 2.0, velocity: 1.0)  // Zoom in
element.pinch(withScale: 0.5, velocity: -1.0) // Zoom out

// Rotate
element.rotate(CGFloat.pi / 2, withVelocity: 1.0)  // 90 degrees
```

### Multi-Touch Gestures
```swift
// Two-finger tap
element.twoFingerTap()

// Custom multi-touch
let center = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
let finger1 = center.withOffset(CGVector(dx: -50, dy: 0))
let finger2 = center.withOffset(CGVector(dx: 50, dy: 0))
finger1.press(forDuration: 0.5, thenDragTo: finger2)
```

## Waiting Strategies

### Element Existence
```swift
// Wait for element to appear
let element = app.buttons["submit"]
XCTAssertTrue(element.waitForExistence(timeout: 10))

// Wait for element to disappear
let loadingSpinner = app.activityIndicators["loading"]
let expectation = XCTNSPredicateExpectation(
    predicate: NSPredicate(format: "exists == false"),
    object: loadingSpinner
)
wait(for: [expectation], timeout: 30)
```

### Custom Wait Conditions
```swift
func waitForCondition(timeout: TimeInterval, condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return false
}

// Usage
let success = waitForCondition(timeout: 10) {
    app.staticTexts["success-message"].exists
}
XCTAssertTrue(success, "Success message did not appear")
```

## Multi-Device Testing

### Device Matrix Configuration
```swift
// Test plan or scheme configuration
// Devices: iPhone 15 Pro, iPhone SE, iPad Pro
// iOS versions: 16.x, 17.x

func testAdaptiveLayout() throws {
    let device = UIDevice.current

    if device.userInterfaceIdiom == .pad {
        // iPad-specific assertions
        XCTAssertTrue(app.splitViews.firstMatch.exists)
    } else {
        // iPhone-specific assertions
        XCTAssertTrue(app.navigationBars.firstMatch.exists)
    }
}
```

### Orientation Testing
```swift
func testLandscapeLayout() throws {
    XCUIDevice.shared.orientation = .landscapeLeft

    // Wait for orientation change
    Thread.sleep(forTimeInterval: 0.5)

    // Assert landscape-specific UI
    XCTAssertTrue(app.buttons["sidebar-toggle"].exists)

    XCUIDevice.shared.orientation = .portrait
}
```

## Screenshot Capture

### On Failure
```swift
override func tearDownWithError() throws {
    if testRun?.failureCount ?? 0 > 0 {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Failure Screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Custom Screenshots
```swift
func captureScreenshot(name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

## Testing Patterns

### Page Object Pattern
```swift
protocol Screen {
    var app: XCUIApplication { get }
}

class LoginScreen: Screen {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var emailField: XCUIElement { app.textFields["email-field"] }
    var passwordField: XCUIElement { app.secureTextFields["password-field"] }
    var loginButton: XCUIElement { app.buttons["login-button"] }
    var errorMessage: XCUIElement { app.staticTexts["error-message"] }

    @discardableResult
    func enterEmail(_ email: String) -> Self {
        emailField.tap()
        emailField.typeText(email)
        return self
    }

    @discardableResult
    func enterPassword(_ password: String) -> Self {
        passwordField.tap()
        passwordField.typeText(password)
        return self
    }

    func tapLogin() -> HomeScreen {
        loginButton.tap()
        return HomeScreen(app: app)
    }
}

// Usage in test
func testLogin() throws {
    LoginScreen(app: app)
        .enterEmail("test@example.com")
        .enterPassword("password")
        .tapLogin()

    XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
}
```

### Data-Driven Testing
```swift
func testMultipleLogins() throws {
    let testCases = [
        (email: "user1@test.com", password: "pass1", shouldSucceed: true),
        (email: "user2@test.com", password: "wrong", shouldSucceed: false),
        (email: "", password: "pass", shouldSucceed: false)
    ]

    for testCase in testCases {
        app.terminate()
        app.launch()

        LoginScreen(app: app)
            .enterEmail(testCase.email)
            .enterPassword(testCase.password)
            .tapLogin()

        if testCase.shouldSucceed {
            XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5),
                         "Login should succeed for \(testCase.email)")
        } else {
            XCTAssertTrue(app.staticTexts["error-message"].waitForExistence(timeout: 5),
                         "Login should fail for \(testCase.email)")
        }
    }
}
```

## CI/CD Integration

### Fastlane Configuration
```ruby
# Fastfile
lane :ui_tests do
  scan(
    scheme: "AppUITests",
    devices: ["iPhone 15 Pro", "iPad Pro (12.9-inch)"],
    result_bundle: true,
    output_directory: "./test_results",
    code_coverage: true
  )
end
```

### GitHub Actions
```yaml
name: UI Tests
on: [push, pull_request]

jobs:
  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app
      - name: Run UI Tests
        run: |
          xcodebuild test \
            -scheme AppUITests \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -resultBundlePath TestResults.xcresult
      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

## Best Practices

1. **Use accessibility identifiers** - Most reliable element selection
2. **Implement Page Object pattern** - Maintainable test code
3. **Add explicit waits** - Avoid flaky tests
4. **Test on multiple devices** - Ensure UI adapts correctly
5. **Capture screenshots on failure** - Easier debugging
6. **Run tests in parallel** - Faster feedback
7. **Use launch arguments** - Control test environment
8. **Clean state between tests** - Independent test execution
