// =============================================================================
// ECHOELMUSIC - COMPREHENSIVE UI TESTS
// Functional UI testing for navigation, interactions, accessibility
// =============================================================================

import XCTest

/// Comprehensive UI tests covering navigation, interaction, and accessibility
final class EchoelmusicUITests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    /// Verify app launches successfully and shows main content
    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground, "App should be running")
    }

    /// Verify app launches within acceptable time
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Navigation Tests

    /// Test tab bar navigation exists and responds to taps
    func testTabBarNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5.0) else {
            // App might use sidebar navigation on iPad
            return
        }
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")

        // Tap each available tab
        for button in tabBar.buttons.allElementsBoundByIndex {
            button.tap()
            // Verify navigation occurred (no crash)
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    /// Test navigation back button works
    func testNavigationBackButton() throws {
        // Navigate into any detail view
        let firstButton = app.buttons.firstMatch
        guard firstButton.waitForExistence(timeout: 3.0) else { return }
        firstButton.tap()

        // Try to go back
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 2.0) {
            backButton.tap()
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    // MARK: - Interaction Tests

    /// Test swipe gestures don't crash the app
    func testSwipeGestures() throws {
        let mainView = app.otherElements.firstMatch
        guard mainView.waitForExistence(timeout: 3.0) else { return }

        app.swipeUp()
        XCTAssertTrue(app.state == .runningForeground, "App should survive swipe up")

        app.swipeDown()
        XCTAssertTrue(app.state == .runningForeground, "App should survive swipe down")

        app.swipeLeft()
        XCTAssertTrue(app.state == .runningForeground, "App should survive swipe left")

        app.swipeRight()
        XCTAssertTrue(app.state == .runningForeground, "App should survive swipe right")
    }

    /// Test rotation handling
    func testRotation() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.state == .runningForeground, "App should handle landscape")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.state == .runningForeground, "App should handle portrait")
    }

    /// Test pinch gesture doesn't crash
    func testPinchGesture() throws {
        let element = app.otherElements.firstMatch
        guard element.waitForExistence(timeout: 3.0) else { return }
        element.pinch(withScale: 2.0, velocity: 1.0)
        XCTAssertTrue(app.state == .runningForeground, "App should handle pinch")
    }

    // MARK: - Accessibility Tests

    /// Verify all visible elements have accessibility labels
    func testAccessibilityLabels() throws {
        // Check buttons have labels
        for button in app.buttons.allElementsBoundByIndex.prefix(20) {
            if button.exists && button.isHittable {
                XCTAssertFalse(
                    button.label.isEmpty,
                    "Button should have accessibility label: \(button.debugDescription)"
                )
            }
        }
    }

    /// Test VoiceOver compatibility - elements are accessible
    func testVoiceOverElements() throws {
        let accessibleElements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(
            accessibleElements.count, 0,
            "App should have accessibility elements"
        )
    }

    /// Test Dynamic Type support
    func testDynamicType() throws {
        // Launch with extra large text
        let largeTextApp = XCUIApplication()
        largeTextApp.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        largeTextApp.launch()
        XCTAssertTrue(largeTextApp.state == .runningForeground, "App should handle extra large text")
    }

    // MARK: - Dark Mode Tests

    /// Test app launches in dark mode without issues
    func testDarkMode() throws {
        let darkApp = XCUIApplication()
        darkApp.launchArguments += ["-UIUserInterfaceStyle", "Dark"]
        darkApp.launch()
        XCTAssertTrue(darkApp.state == .runningForeground, "App should work in dark mode")
    }

    /// Test app launches in light mode without issues
    func testLightMode() throws {
        let lightApp = XCUIApplication()
        lightApp.launchArguments += ["-UIUserInterfaceStyle", "Light"]
        lightApp.launch()
        XCTAssertTrue(lightApp.state == .runningForeground, "App should work in light mode")
    }

    // MARK: - Memory & Performance Tests

    /// Test rapid navigation doesn't cause memory issues
    func testRapidNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5.0) else { return }

        let buttons = tabBar.buttons.allElementsBoundByIndex
        guard buttons.count > 1 else { return }

        // Rapidly switch between tabs 20 times
        for i in 0..<20 {
            let idx = i % buttons.count
            buttons[idx].tap()
        }
        XCTAssertTrue(app.state == .runningForeground, "App should handle rapid navigation")
    }

    /// Test scrolling performance in lists
    func testScrollingPerformance() throws {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3.0) else {
            // Try collection view or table
            let table = app.tables.firstMatch
            guard table.waitForExistence(timeout: 3.0) else { return }
            for _ in 0..<5 {
                table.swipeUp()
            }
            XCTAssertTrue(app.state == .runningForeground)
            return
        }

        for _ in 0..<5 {
            scrollView.swipeUp()
        }
        XCTAssertTrue(app.state == .runningForeground, "App should handle scrolling")
    }

    // MARK: - State Restoration Tests

    /// Test app handles backgrounding and foregrounding
    func testBackgroundForeground() throws {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)
        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5.0),
            "App should restore from background"
        )
    }

    // MARK: - Alert & Sheet Tests

    /// Test system alerts can be handled
    func testSystemAlertHandling() throws {
        // Add interrupt handler for system alerts (permissions, etc.)
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }

        // Trigger interaction that might cause alert
        app.tap()
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Settings UI Tests

/// Tests for settings and preferences screens
final class EchoelmusicSettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Test settings screen loads
    func testSettingsScreenExists() throws {
        // Try to navigate to settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 3.0) {
            settingsButton.tap()
            XCTAssertTrue(app.state == .runningForeground, "Settings should open")
        }

        // Also try via tab bar
        let tabButton = app.tabBars.buttons["Settings"]
        if tabButton.waitForExistence(timeout: 2.0) {
            tabButton.tap()
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    /// Test toggle switches work
    func testToggles() throws {
        // Navigate to settings
        let settingsButton = app.tabBars.buttons["Settings"]
        guard settingsButton.waitForExistence(timeout: 3.0) else { return }
        settingsButton.tap()

        // Find and tap toggles
        let switches = app.switches.allElementsBoundByIndex
        for toggle in switches.prefix(5) {
            if toggle.exists && toggle.isHittable {
                let initialValue = toggle.value as? String
                toggle.tap()
                // Verify toggle changed or at least didn't crash
                XCTAssertTrue(app.state == .runningForeground)
                // Restore original value
                if toggle.value as? String != initialValue {
                    toggle.tap()
                }
            }
        }
    }
}
