// =============================================================================
// ECHOELMUSIC - SCREENSHOT UI TESTS
// Automated screenshot capture for App Store
// Version: 1.0.0 - Phase 10000 ULTIMATE MODE
// =============================================================================

import XCTest

/// UI Tests for capturing App Store screenshots
/// Run with: fastlane screenshots
final class EchoelmusicScreenshotTests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        app.launchForScreenshots(waitForAnimations: true)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Tests

    /// Screenshot 1: Bio-Reactive Audio - Main hero screen
    func test01_BioReactiveAudio() {
        // Navigate to main bio-reactive view
        navigateToMainScreen()

        // Wait for coherence animation to stabilize
        wait(for: 2.0)

        Snapshot.snapshot(ScreenshotName.bioReactiveAudio.rawValue)
    }

    /// Screenshot 2: Quantum Visualization - Sacred geometry and quantum effects
    func test02_QuantumVisualization() {
        navigateToVisualization()

        // Select quantum mode
        tapIfExists("Quantum")

        wait(for: 1.5)

        Snapshot.snapshot(ScreenshotName.quantumVisualization.rawValue)
    }

    /// Screenshot 3: Orchestra Scoring - Cinematic composition interface
    func test03_OrchestraScoring() {
        navigateToOrchestra()

        // Show orchestra sections
        tapIfExists("Orchestra")

        wait(for: 1.0)

        Snapshot.snapshot(ScreenshotName.orchestraScoring.rawValue)
    }

    /// Screenshot 4: Immersive Experience - 360 spatial audio
    func test04_ImmersiveExperience() {
        navigateToSpatialAudio()

        // Enable immersive mode
        tapIfExists("Immersive")

        wait(for: 1.5)

        Snapshot.snapshot(ScreenshotName.immersiveExperience.rawValue)
    }

    /// Screenshot 5: AI Studio - AI art and music generation
    func test05_AIStudio() {
        navigateToAIStudio()

        // Show generation interface
        tapIfExists("Generate")

        wait(for: 1.0)

        Snapshot.snapshot(ScreenshotName.aiStudio.rawValue)
    }

    /// Screenshot 6: Wellness - Meditation and breathing
    func test06_Wellness() {
        navigateToWellness()

        // Show breathing guide
        tapIfExists("Breathe")

        wait(for: 2.0)

        Snapshot.snapshot(ScreenshotName.wellness.rawValue)
    }

    /// Screenshot 7: Streaming - Professional live streaming
    func test07_Streaming() {
        navigateToStreaming()

        // Show streaming controls
        tapIfExists("Stream")

        wait(for: 1.0)

        Snapshot.snapshot(ScreenshotName.streaming.rawValue)
    }

    /// Screenshot 8: Hardware - Hardware ecosystem
    func test08_Hardware() {
        navigateToHardware()

        // Show connected devices
        tapIfExists("Devices")

        wait(for: 1.0)

        Snapshot.snapshot(ScreenshotName.hardware.rawValue)
    }

    /// Screenshot 9: Collaboration - Worldwide collaboration
    func test09_Collaboration() {
        navigateToCollaboration()

        // Show session view
        tapIfExists("Sessions")

        wait(for: 1.5)

        Snapshot.snapshot(ScreenshotName.collaboration.rawValue)
    }

    /// Screenshot 10: Accessibility - WCAG AAA accessibility
    func test10_Accessibility() {
        navigateToAccessibility()

        // Show accessibility profiles
        tapIfExists("Accessibility")

        wait(for: 1.0)

        Snapshot.snapshot(ScreenshotName.accessibility.rawValue)
    }

    // MARK: - All Screenshots in One Run

    /// Capture all screenshots in sequence (alternative to individual tests)
    func testAllScreenshots() {
        for screenshotName in ScreenshotName.allCases {
            switch screenshotName {
            case .bioReactiveAudio:
                navigateToMainScreen()
            case .quantumVisualization:
                navigateToVisualization()
                tapIfExists("Quantum")
            case .orchestraScoring:
                navigateToOrchestra()
            case .immersiveExperience:
                navigateToSpatialAudio()
            case .aiStudio:
                navigateToAIStudio()
            case .wellness:
                navigateToWellness()
            case .streaming:
                navigateToStreaming()
            case .hardware:
                navigateToHardware()
            case .collaboration:
                navigateToCollaboration()
            case .accessibility:
                navigateToAccessibility()
            }

            wait(for: 1.5)
            Snapshot.snapshot(screenshotName.rawValue)
        }
    }

    // MARK: - Navigation Helpers

    private func navigateToMainScreen() {
        // App launches to main screen by default
        // Ensure we're on home tab
        tapIfExists("Home")
    }

    private func navigateToVisualization() {
        tapIfExists("Visuals")
        tapIfExists("Visualization")
    }

    private func navigateToOrchestra() {
        tapIfExists("Create")
        tapIfExists("Orchestra")
    }

    private func navigateToSpatialAudio() {
        tapIfExists("Audio")
        tapIfExists("Spatial")
    }

    private func navigateToAIStudio() {
        tapIfExists("Create")
        tapIfExists("AI Studio")
    }

    private func navigateToWellness() {
        tapIfExists("Wellness")
        tapIfExists("Meditation")
    }

    private func navigateToStreaming() {
        tapIfExists("Stream")
        tapIfExists("Live")
    }

    private func navigateToHardware() {
        tapIfExists("Settings")
        tapIfExists("Hardware")
    }

    private func navigateToCollaboration() {
        tapIfExists("Collaborate")
        tapIfExists("Sessions")
    }

    private func navigateToAccessibility() {
        tapIfExists("Settings")
        tapIfExists("Accessibility")
    }

    // MARK: - Utility Methods

    private func tapIfExists(_ identifier: String) {
        // Try button first
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: 2.0) {
            button.tap()
            return
        }

        // Try tab bar button
        let tabButton = app.tabBars.buttons[identifier]
        if tabButton.waitForExistence(timeout: 1.0) {
            tabButton.tap()
            return
        }

        // Try static text (navigation links)
        let text = app.staticTexts[identifier]
        if text.waitForExistence(timeout: 1.0) {
            text.tap()
            return
        }

        // Try any element with accessibility identifier
        let element = app.otherElements[identifier]
        if element.waitForExistence(timeout: 1.0) {
            element.tap()
            return
        }

        print("⚠️ Element not found: \(identifier)")
    }

    private func wait(for seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func swipeUp() {
        app.swipeUp()
    }

    private func swipeDown() {
        app.swipeDown()
    }

    private func scrollToElement(_ element: XCUIElement) {
        var attempts = 0
        while !element.isHittable && attempts < 5 {
            swipeUp()
            attempts += 1
        }
    }
}

// MARK: - Dark Mode Screenshots

/// Separate test class for dark mode screenshots
final class EchoelmusicDarkModeScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        // Launch in dark mode
        app.launchArguments += ["-UIUserInterfaceStyle", "Dark"]
        app.launchForScreenshots(waitForAnimations: true)
    }

    /// Dark mode version of bio-reactive audio
    func test01_BioReactiveAudio_Dark() {
        Thread.sleep(forTimeInterval: 2.0)
        Snapshot.snapshot("01_BioReactiveAudio_Dark")
    }

    /// Dark mode version of quantum visualization
    func test02_QuantumVisualization_Dark() {
        // Navigate to visualization
        if app.buttons["Visuals"].waitForExistence(timeout: 2.0) {
            app.buttons["Visuals"].tap()
        }
        Thread.sleep(forTimeInterval: 1.5)
        Snapshot.snapshot("02_QuantumVisualization_Dark")
    }
}

// MARK: - Watch Screenshots

/// Screenshots for Apple Watch (requires WatchKit scheme)
final class EchoelmusicWatchScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        app.launchForScreenshots(waitForAnimations: true)
    }

    /// Watch complication screenshot
    func test01_WatchCoherence() {
        Thread.sleep(forTimeInterval: 1.0)
        Snapshot.snapshot("Watch_01_Coherence")
    }

    /// Watch session screenshot
    func test02_WatchSession() {
        if app.buttons["Session"].waitForExistence(timeout: 2.0) {
            app.buttons["Session"].tap()
        }
        Thread.sleep(forTimeInterval: 1.0)
        Snapshot.snapshot("Watch_02_Session")
    }

    /// Watch breathing guide
    func test03_WatchBreathing() {
        if app.buttons["Breathe"].waitForExistence(timeout: 2.0) {
            app.buttons["Breathe"].tap()
        }
        Thread.sleep(forTimeInterval: 1.5)
        Snapshot.snapshot("Watch_03_Breathing")
    }
}
