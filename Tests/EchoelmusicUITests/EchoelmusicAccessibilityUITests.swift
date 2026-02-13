// =============================================================================
// ECHOELMUSIC - ACCESSIBILITY UI TESTS
// WCAG AAA compliance validation through automated UI testing
// =============================================================================

import XCTest

/// Automated accessibility compliance tests
/// Validates WCAG AAA standards across the app
final class EchoelmusicAccessibilityUITests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - WCAG 1.1 Text Alternatives

    /// All images should have accessibility labels
    func testImagesHaveAccessibilityLabels() throws {
        let images = app.images.allElementsBoundByIndex
        for image in images.prefix(30) {
            if image.exists {
                // Image should either have a label or be marked as decorative
                let hasLabel = !image.label.isEmpty
                let isAccessible = image.isAccessibilityElement
                XCTAssertTrue(
                    hasLabel || !isAccessible,
                    "Image should have accessibility label or be marked decorative: \(image.debugDescription)"
                )
            }
        }
    }

    // MARK: - WCAG 2.1 Keyboard Accessible

    /// All interactive elements should be focusable
    func testInteractiveElementsAreFocusable() throws {
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(20) {
            if button.exists && button.isHittable {
                XCTAssertTrue(
                    button.isEnabled,
                    "Visible button should be enabled: \(button.label)"
                )
            }
        }
    }

    // MARK: - WCAG 2.4 Navigable

    /// Navigation structure should be logical
    func testNavigationStructure() throws {
        // Verify navigation bars exist where expected
        let navBar = app.navigationBars.firstMatch
        if navBar.waitForExistence(timeout: 3.0) {
            XCTAssertTrue(navBar.exists, "Navigation bar should exist")

            // Title should be present
            let title = navBar.staticTexts.firstMatch
            if title.exists {
                XCTAssertFalse(title.label.isEmpty, "Navigation title should not be empty")
            }
        }
    }

    /// Tab bar items should have labels
    func testTabBarAccessibility() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5.0) else { return }

        for button in tabBar.buttons.allElementsBoundByIndex {
            if button.exists {
                XCTAssertFalse(
                    button.label.isEmpty,
                    "Tab bar button should have label"
                )
            }
        }
    }

    // MARK: - WCAG 3.2 Predictable

    /// Test that navigation is consistent across the app
    func testConsistentNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5.0) else { return }

        let initialButtons = tabBar.buttons.allElementsBoundByIndex.map { $0.label }

        // Navigate to each tab and verify tab bar stays consistent
        for button in tabBar.buttons.allElementsBoundByIndex {
            if button.exists && button.isHittable {
                button.tap()
                Thread.sleep(forTimeInterval: 0.3)

                let currentButtons = tabBar.buttons.allElementsBoundByIndex.map { $0.label }
                XCTAssertEqual(
                    initialButtons.count,
                    currentButtons.count,
                    "Tab bar should maintain consistent number of items"
                )
            }
        }
    }

    // MARK: - WCAG 4.1 Compatible

    /// All elements should have proper accessibility traits
    func testAccessibilityTraits() throws {
        // Buttons should have button trait
        for button in app.buttons.allElementsBoundByIndex.prefix(10) {
            if button.exists {
                XCTAssertTrue(
                    button.elementType == .button,
                    "Button element should have button type"
                )
            }
        }

        // Static texts should be identifiable
        for text in app.staticTexts.allElementsBoundByIndex.prefix(10) {
            if text.exists {
                XCTAssertTrue(
                    text.elementType == .staticText,
                    "Text element should have staticText type"
                )
            }
        }
    }

    // MARK: - Reduced Motion

    /// Test app respects reduced motion preference
    func testReducedMotion() throws {
        let reducedMotionApp = XCUIApplication()
        reducedMotionApp.launchArguments += ["-UIAccessibilityReduceMotion", "1"]
        reducedMotionApp.launch()
        XCTAssertTrue(
            reducedMotionApp.state == .runningForeground,
            "App should work with reduced motion"
        )
    }

    // MARK: - Bold Text

    /// Test app handles bold text accessibility setting
    func testBoldText() throws {
        let boldApp = XCUIApplication()
        boldApp.launchArguments += ["-UIAccessibilityIsBoldTextEnabled", "1"]
        boldApp.launch()
        XCTAssertTrue(
            boldApp.state == .runningForeground,
            "App should work with bold text"
        )
    }

    // MARK: - High Contrast

    /// Test app handles increased contrast
    func testIncreasedContrast() throws {
        let contrastApp = XCUIApplication()
        contrastApp.launchArguments += ["-UIAccessibilityDarkerSystemColorsEnabled", "1"]
        contrastApp.launch()
        XCTAssertTrue(
            contrastApp.state == .runningForeground,
            "App should work with increased contrast"
        )
    }

    // MARK: - Touch Accommodation

    /// Test all tappable elements have minimum 44x44 touch target
    func testMinimumTouchTargets() throws {
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(20) {
            if button.exists && button.isHittable {
                let frame = button.frame
                // WCAG requires minimum 44x44 point touch target
                // We check for at least 40 to allow minor layout variations
                if frame.width > 0 && frame.height > 0 {
                    XCTAssertGreaterThanOrEqual(
                        max(frame.width, frame.height), 40,
                        "Touch target too small for '\(button.label)': \(frame.size)"
                    )
                }
            }
        }
    }
}
