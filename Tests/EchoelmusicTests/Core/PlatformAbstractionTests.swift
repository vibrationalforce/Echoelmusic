//
//  PlatformAbstractionTests.swift
//  EchoelmusicTests
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Unit tests for platform abstraction layer
//

import XCTest
@testable import Echoelmusic

@MainActor
final class PlatformAbstractionTests: XCTestCase {

    // MARK: - Platform Detection Tests

    func testPlatformDetection() {
        let platform = Platform.current

        // Verify platform is detected
        XCTAssertNotEqual(platform, .unknown, "Platform should be detected")

        // Verify display name
        XCTAssertFalse(platform.displayName.isEmpty, "Platform display name should not be empty")
    }

    func testPlatformCapabilities() {
        let platform = Platform.current

        // Test biofeedback support
        #if os(iOS) || os(watchOS)
        XCTAssertTrue(platform.supportsBiofeedback, "iOS/watchOS should support biofeedback")
        #elseif os(macOS)
        XCTAssertFalse(platform.supportsBiofeedback, "macOS should not support biofeedback")
        #endif

        // Test haptics support
        #if os(iOS) || os(watchOS)
        XCTAssertTrue(platform.supportsHaptics, "iOS/watchOS should support haptics")
        #elseif os(macOS)
        XCTAssertFalse(platform.supportsHaptics, "macOS should not support haptics")
        #endif

        // Test fullscreen support
        #if os(iOS) || os(macOS) || os(tvOS)
        XCTAssertTrue(platform.supportsFullscreen, "Platform should support fullscreen")
        #elseif os(watchOS)
        XCTAssertFalse(platform.supportsFullscreen, "watchOS should not support fullscreen")
        #endif
    }

    // MARK: - Platform Configuration Tests

    func testPlatformConfigurationInitialization() async {
        let config = PlatformConfiguration.shared

        // Verify initialization
        XCTAssertNotNil(config, "Platform configuration should initialize")
        XCTAssertEqual(config.currentPlatform, Platform.current, "Current platform should match detected platform")
    }

    func testDeviceIdiomDetection() async {
        let config = PlatformConfiguration.shared
        let idiom = config.idiom

        // Verify idiom is detected
        XCTAssertNotNil(idiom, "Device idiom should be detected")

        #if os(iOS)
        // On iOS, should be phone or tablet
        XCTAssertTrue(idiom == .phone || idiom == .tablet, "iOS idiom should be phone or tablet")
        #elseif os(macOS)
        XCTAssertEqual(idiom, .desktop, "macOS idiom should be desktop")
        #elseif os(watchOS)
        XCTAssertEqual(idiom, .watch, "watchOS idiom should be watch")
        #endif
    }

    func testScreenSizeDetection() async {
        let config = PlatformConfiguration.shared

        // Verify screen size is not zero
        XCTAssertGreaterThan(config.screenSize.width, 0, "Screen width should be greater than 0")
        XCTAssertGreaterThan(config.screenSize.height, 0, "Screen height should be greater than 0")
    }

    func testCapabilityChecking() async {
        let config = PlatformConfiguration.shared

        // Test biofeedback capability
        let hasBiofeedback = config.hasCapability(.biofeedback)

        #if os(iOS) || os(watchOS)
        XCTAssertTrue(hasBiofeedback, "iOS/watchOS should have biofeedback capability")
        #elseif os(macOS)
        XCTAssertFalse(hasBiofeedback, "macOS should not have biofeedback capability")
        #endif

        // Test networking capability (should always be true)
        XCTAssertTrue(config.hasCapability(.networking), "All platforms should have networking capability")
    }

    func testLayoutHelpers() async {
        let config = PlatformConfiguration.shared

        // Test recommended column count
        let columnCount = config.recommendedColumnCount()
        XCTAssertGreaterThan(columnCount, 0, "Column count should be greater than 0")
        XCTAssertLessThanOrEqual(columnCount, 4, "Column count should not exceed 4")

        // Test recommended padding
        let padding = config.recommendedPadding()
        XCTAssertGreaterThan(padding, 0, "Padding should be greater than 0")

        // Test recommended font scale
        let fontScale = config.recommendedFontScale()
        XCTAssertGreaterThan(fontScale, 0, "Font scale should be greater than 0")
        XCTAssertLessThanOrEqual(fontScale, 2.0, "Font scale should be reasonable")
    }

    // MARK: - Platform Color Tests

    func testPlatformColors() {
        let label = PlatformColor.label
        let background = PlatformColor.background

        // Verify colors are created
        XCTAssertNotNil(label, "Label color should be created")
        XCTAssertNotNil(background, "Background color should be created")

        // Verify SwiftUI color conversion
        let labelSwiftUI = label.swiftUIColor
        let backgroundSwiftUI = background.swiftUIColor
        XCTAssertNotNil(labelSwiftUI, "Label SwiftUI color should be created")
        XCTAssertNotNil(backgroundSwiftUI, "Background SwiftUI color should be created")
    }

    // MARK: - Platform Storage Tests

    func testStorageDirectories() {
        let storage = PlatformStorage.shared

        // Test documents directory
        let documentsDir = storage.documentsDirectory()

        #if os(iOS) || os(macOS) || os(watchOS)
        XCTAssertNotNil(documentsDir, "Documents directory should be available on iOS/macOS/watchOS")
        #endif

        // Test app support directory
        let appSupportDir = storage.appSupportDirectory()

        #if os(iOS) || os(macOS) || os(watchOS)
        XCTAssertNotNil(appSupportDir, "App support directory should be available on iOS/macOS/watchOS")
        #endif

        // Test caches directory
        let cachesDir = storage.cachesDirectory()

        #if os(iOS) || os(macOS) || os(watchOS)
        XCTAssertNotNil(cachesDir, "Caches directory should be available on iOS/macOS/watchOS")
        #endif
    }

    func testSaveAndLoadData() throws {
        let storage = PlatformStorage.shared
        let testData = "Test data for Echoelmusic".data(using: .utf8)!
        let filename = "test_platform_storage.txt"

        // Save data
        try storage.save(testData, to: filename, in: .caches)

        // Load data
        let loadedData = try storage.load(from: filename, in: .caches)

        // Verify data matches
        XCTAssertEqual(testData, loadedData, "Loaded data should match saved data")

        // Cleanup
        if let cachesDir = storage.cachesDirectory() {
            let fileURL = cachesDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Performance Tests

    func testPlatformDetectionPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Platform.current
            }
        }
    }

    func testCapabilityCheckingPerformance() async {
        let config = PlatformConfiguration.shared

        measure {
            for _ in 0..<1000 {
                _ = config.hasCapability(.biofeedback)
                _ = config.hasCapability(.haptics)
                _ = config.hasCapability(.networking)
            }
        }
    }
}
