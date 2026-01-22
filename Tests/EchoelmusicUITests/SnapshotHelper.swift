// =============================================================================
// ECHOELMUSIC - SNAPSHOT HELPER
// Fastlane screenshot automation helper
// Version: 1.0.0 - Phase 10000 ULTIMATE MODE
// =============================================================================

import Foundation
import XCTest

/// Fastlane Snapshot Helper for automated screenshot capture
/// Based on fastlane's SnapshotHelper with Echoelmusic customizations
enum Snapshot {
    // MARK: - Configuration

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    static var screenshotDirectory: URL? {
        if let path = ProcessInfo.processInfo.environment["SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_COMPLETE"] {
            // fastlane snapshot is running
            return URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        return nil
    }

    // MARK: - Screenshot Capture

    /// Take a screenshot with the given name
    /// - Parameters:
    ///   - name: Screenshot name (e.g., "01_BioReactiveAudio")
    ///   - waitForLoadingIndicator: Whether to wait for loading indicators to disappear
    static func snapshot(_ name: String, waitForLoadingIndicator: Bool = true) {
        if waitForLoadingIndicator {
            waitForLoadingIndicatorToDisappear()
        }

        print("📸 Capturing screenshot: \(name)")

        guard screenshotDirectory != nil else {
            print("📸 [Snapshot] Skipping screenshot (not running via fastlane)")
            return
        }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways

        // Add to test results
        if let testCase = getCurrentTestCase() {
            testCase.add(attachment)
        }

        // Save screenshot with proper naming
        saveScreenshot(screenshot, name: name)
    }

    /// Take a screenshot with automatic naming based on test method
    static func snapshotAuto() {
        let name = getCurrentTestName() ?? "screenshot_\(Date().timeIntervalSince1970)"
        snapshot(name)
    }

    // MARK: - Wait Helpers

    /// Wait for loading indicators to disappear
    static func waitForLoadingIndicatorToDisappear(timeout: TimeInterval = 10) {
        let app = XCUIApplication()

        // Wait for activity indicators
        let activityIndicator = app.activityIndicators.element
        if activityIndicator.exists {
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: activityIndicator)
            _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        }

        // Wait for progress views
        let progressView = app.progressIndicators.element
        if progressView.exists {
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: progressView)
            _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        }
    }

    /// Wait for element to appear
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Wait for element to disappear
    static func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Utility

    /// Set language for screenshot (used by fastlane)
    static func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        // Configure app for screenshot mode
        app.launchArguments += [
            "-AppleLanguages", "(\(deviceLanguage))",
            "-AppleLocale", "\"\(locale)\"",
            "-FASTLANE_SNAPSHOT", "true",
            "--screenshot-mode"
        ]

        // Disable animations for faster screenshots
        if !waitForAnimations {
            app.launchArguments += ["-UIViewAnimationDuration", "0"]
        }

        app.launch()
    }

    /// Get current device language from environment
    static var deviceLanguage: String {
        ProcessInfo.processInfo.environment["DEVICE_LANGUAGE"] ?? "en"
    }

    /// Get current locale from environment
    static var locale: String {
        ProcessInfo.processInfo.environment["SIMULATOR_LOCALE"] ?? "en_US"
    }

    // MARK: - Private Helpers

    private static func getCurrentTestCase() -> XCTestCase? {
        // Access current test case via reflection
        let testCaseClass: AnyClass? = NSClassFromString("XCTestCase")
        guard let testCaseClass = testCaseClass else { return nil }

        if let currentTest = testCaseClass.perform(NSSelectorFromString("currentTestCase"))?.takeUnretainedValue() as? XCTestCase {
            return currentTest
        }
        return nil
    }

    private static func getCurrentTestName() -> String? {
        getCurrentTestCase()?.name
    }

    private static func saveScreenshot(_ screenshot: XCUIScreenshot, name: String) {
        guard let directory = screenshotDirectory else { return }

        let filePath = directory.appendingPathComponent("\(name).png")

        do {
            try screenshot.pngRepresentation.write(to: filePath)
            print("📸 [Snapshot] Saved: \(filePath.path)")
        } catch {
            print("❌ [Snapshot] Failed to save: \(error)")
        }
    }
}

// MARK: - XCUIApplication Extension

extension XCUIApplication {
    /// Launch app configured for fastlane screenshots
    func launchForScreenshots(waitForAnimations: Bool = true) {
        Snapshot.setupSnapshot(self, waitForAnimations: waitForAnimations)
    }
}

// MARK: - Screenshot Names

/// Standardized screenshot names for App Store
enum ScreenshotName: String, CaseIterable {
    case bioReactiveAudio = "01_BioReactiveAudio"
    case quantumVisualization = "02_QuantumVisualization"
    case orchestraScoring = "03_OrchestraScoring"
    case immersiveExperience = "04_ImmersiveExperience"
    case aiStudio = "05_AIStudio"
    case wellness = "06_Wellness"
    case streaming = "07_Streaming"
    case hardware = "08_Hardware"
    case collaboration = "09_Collaboration"
    case accessibility = "10_Accessibility"

    var displayName: String {
        switch self {
        case .bioReactiveAudio: return "Bio-Reactive Audio"
        case .quantumVisualization: return "Quantum Visualization"
        case .orchestraScoring: return "Orchestra Scoring"
        case .immersiveExperience: return "Immersive Experience"
        case .aiStudio: return "AI Studio"
        case .wellness: return "Wellness"
        case .streaming: return "Streaming"
        case .hardware: return "Hardware"
        case .collaboration: return "Collaboration"
        case .accessibility: return "Accessibility"
        }
    }
}
