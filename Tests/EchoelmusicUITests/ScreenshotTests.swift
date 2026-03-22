import XCTest

/// App Store screenshot automation for Echoelmusic.
///
/// Captures 10 key screens across all configured devices and languages.
/// Used by fastlane `capture_screenshots` via the EchoelmusicScreenshots scheme.
///
/// Naming: `{device}_{language}_{screenshot_name}.png`
/// Devices configured in `fastlane/Snapfile`.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshots

    /// 01 — Main Hub: Bio-reactive dashboard with live data
    func test01_MainHub() {
        // Wait for the main hub to fully load
        let mainView = app.otherElements.firstMatch
        XCTAssertTrue(mainView.waitForExistence(timeout: 10))

        // Allow bio-data to populate
        sleep(2)
        snapshot("01_BioReactiveHub")
    }

    /// 02 — Synth: DDSP bio-reactive synthesizer
    func test02_Synth() {
        tapTab("Synth")
        sleep(1)
        snapshot("02_BioReactiveSynth")
    }

    /// 03 — Mixer: Professional multi-track console
    func test03_Mixer() {
        tapTab("Mix")
        sleep(1)
        snapshot("03_ProMixer")
    }

    /// 04 — Effects: 20+ audio effects rack
    func test04_Effects() {
        tapTab("FX")
        sleep(1)
        snapshot("04_EffectsRack")
    }

    /// 05 — Sequencer: Step sequencer with patterns
    func test05_Sequencer() {
        tapTab("Seq")
        sleep(1)
        snapshot("05_StepSequencer")
    }

    /// 06 — Visuals: Bio-reactive Metal visualizations
    func test06_Visuals() {
        tapTab("Vis")
        sleep(2)
        snapshot("06_BioReactiveVisuals")
    }

    /// 07 — Video: Capture and edit with live color grading
    func test07_Video() {
        tapTab("Vid")
        sleep(1)
        snapshot("07_VideoEditor")
    }

    /// 08 — Lighting: DMX 512 / Art-Net control
    func test08_Lighting() {
        tapTab("Lux")
        sleep(1)
        snapshot("08_LightingControl")
    }

    /// 09 — Bio: Real-time biofeedback (HR, HRV, coherence)
    func test09_Bio() {
        tapTab("Bio")
        sleep(2)
        snapshot("09_Biofeedback")
    }

    /// 10 — Session: Multi-track DAW session view
    func test10_Session() {
        tapTab("Session")
        sleep(1)
        snapshot("10_ProSession")
    }

    // MARK: - Helpers

    /// Tap a tab by its label in the main navigation
    private func tapTab(_ label: String) {
        let tab = app.buttons[label].firstMatch
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        } else {
            // Try tab bar items
            let tabBarItem = app.tabBars.buttons[label].firstMatch
            if tabBarItem.waitForExistence(timeout: 3) {
                tabBarItem.tap()
            }
        }
    }
}
