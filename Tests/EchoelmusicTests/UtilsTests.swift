// UtilsTests.swift
// Tests for DeviceCapabilities and HeadTrackingManager utilities
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Utils module
/// Coverage: DeviceCapabilities, HeadTrackingManager, HeadRotation, NormalizedPosition
final class UtilsTests: XCTestCase {

    // MARK: - HeadRotation Tests

    func testHeadRotationInitialization() {
        let rotation = HeadRotation()
        XCTAssertEqual(rotation.yaw, 0.0, accuracy: 0.001)
        XCTAssertEqual(rotation.pitch, 0.0, accuracy: 0.001)
        XCTAssertEqual(rotation.roll, 0.0, accuracy: 0.001)
    }

    func testHeadRotationCustomValues() {
        let rotation = HeadRotation(yaw: 1.5, pitch: -0.5, roll: 0.3)
        XCTAssertEqual(rotation.yaw, 1.5, accuracy: 0.001)
        XCTAssertEqual(rotation.pitch, -0.5, accuracy: 0.001)
        XCTAssertEqual(rotation.roll, 0.3, accuracy: 0.001)
    }

    func testHeadRotationDegreesConversion() {
        // 180 degrees = pi radians
        let rotation = HeadRotation(yaw: .pi, pitch: .pi / 2, roll: -.pi / 4)
        let degrees = rotation.degrees

        XCTAssertEqual(degrees.yaw, 180.0, accuracy: 0.1)
        XCTAssertEqual(degrees.pitch, 90.0, accuracy: 0.1)
        XCTAssertEqual(degrees.roll, -45.0, accuracy: 0.1)
    }

    func testHeadRotationDegreesZero() {
        let rotation = HeadRotation()
        let degrees = rotation.degrees

        XCTAssertEqual(degrees.yaw, 0.0, accuracy: 0.001)
        XCTAssertEqual(degrees.pitch, 0.0, accuracy: 0.001)
        XCTAssertEqual(degrees.roll, 0.0, accuracy: 0.001)
    }

    func testHeadRotationNegativeRadians() {
        let rotation = HeadRotation(yaw: -.pi, pitch: -.pi / 2, roll: -.pi)
        let degrees = rotation.degrees

        XCTAssertEqual(degrees.yaw, -180.0, accuracy: 0.1)
        XCTAssertEqual(degrees.pitch, -90.0, accuracy: 0.1)
        XCTAssertEqual(degrees.roll, -180.0, accuracy: 0.1)
    }

    func testHeadRotationSendable() {
        // HeadRotation should be Sendable for concurrent use
        let rotation = HeadRotation(yaw: 1.0, pitch: 2.0, roll: 3.0)

        Task {
            let _ = rotation.yaw
            let _ = rotation.degrees
        }

        XCTAssertEqual(rotation.yaw, 1.0)
    }

    // MARK: - NormalizedPosition Tests

    func testNormalizedPositionInitialization() {
        let position = NormalizedPosition()
        XCTAssertEqual(position.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(position.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(position.z, 0.0, accuracy: 0.001)
    }

    func testNormalizedPositionCustomValues() {
        let position = NormalizedPosition(x: 0.5, y: -0.5, z: 1.0)
        XCTAssertEqual(position.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(position.y, -0.5, accuracy: 0.001)
        XCTAssertEqual(position.z, 1.0, accuracy: 0.001)
    }

    func testNormalizedPositionBoundaryValues() {
        let position = NormalizedPosition(x: -1.0, y: 1.0, z: -1.0)
        XCTAssertEqual(position.x, -1.0, accuracy: 0.001)
        XCTAssertEqual(position.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(position.z, -1.0, accuracy: 0.001)
    }

    func testNormalizedPositionSendable() {
        // NormalizedPosition should be Sendable
        let position = NormalizedPosition(x: 0.1, y: 0.2, z: 0.3)

        Task {
            let _ = position.x
        }

        XCTAssertEqual(position.x, 0.1)
    }

    // MARK: - HeadTrackingManager Tests

    @MainActor
    func testHeadTrackingManagerInitialization() {
        let manager = HeadTrackingManager()

        XCTAssertFalse(manager.isTracking)
        XCTAssertEqual(manager.headRotation.yaw, 0.0, accuracy: 0.001)
        XCTAssertEqual(manager.normalizedPosition.x, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testHeadTrackingManagerStatusDescription() {
        let manager = HeadTrackingManager()

        let status = manager.statusDescription
        XCTAssertFalse(status.isEmpty)
        // Should contain either "available", "not available", or "ready"
        XCTAssertTrue(
            status.contains("available") || status.contains("ready") || status.contains("Tracking"),
            "Status should describe availability"
        )
    }

    @MainActor
    func testHeadTrackingManager3DAudioPosition() {
        let manager = HeadTrackingManager()

        let position = manager.get3DAudioPosition()
        XCTAssertEqual(position.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(position.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(position.z, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testHeadTrackingManagerListenerOrientation() {
        let manager = HeadTrackingManager()

        let orientation = manager.getListenerOrientation()
        XCTAssertEqual(orientation.yaw, 0.0, accuracy: 0.001)
        XCTAssertEqual(orientation.pitch, 0.0, accuracy: 0.001)
        XCTAssertEqual(orientation.roll, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testHeadTrackingManagerVisualizationColor() {
        let manager = HeadTrackingManager()

        let color = manager.getVisualizationColor()
        // At neutral position (0,0,0), colors should be at midpoint (0.5)
        XCTAssertEqual(color.red, 0.5, accuracy: 0.001)
        XCTAssertEqual(color.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testHeadTrackingManagerDirectionArrowNeutral() {
        let manager = HeadTrackingManager()

        let arrow = manager.getDirectionArrow()
        XCTAssertEqual(arrow, "○", "Neutral position should show circle")
    }

    @MainActor
    func testHeadTrackingManagerStopTrackingWhenNotTracking() {
        let manager = HeadTrackingManager()

        // Should not crash when stopping while not tracking
        manager.stopTracking()
        XCTAssertFalse(manager.isTracking)
    }

    @MainActor
    func testHeadTrackingManagerResetOrientationWhenNotTracking() {
        let manager = HeadTrackingManager()

        // Should not crash when resetting while not tracking
        manager.resetOrientation()
        XCTAssertFalse(manager.isTracking)
    }

    @MainActor
    func testHeadTrackingManagerStartTrackingWhenUnavailable() {
        let manager = HeadTrackingManager()

        // On simulator/devices without AirPods, should handle gracefully
        manager.startTracking()

        // Either tracking started (real device with AirPods) or didn't (no hardware)
        // Either way, should not crash
        if !manager.isAvailable {
            XCTAssertFalse(manager.isTracking)
        }
    }

    // MARK: - DeviceCapabilities Tests (MainActor required)

    @MainActor
    func testDeviceCapabilitiesInitialization() {
        let capabilities = DeviceCapabilities()

        XCTAssertFalse(capabilities.deviceModel.isEmpty, "Device model should be detected")
        XCTAssertFalse(capabilities.iOSVersion.isEmpty, "iOS version should be detected")
    }

    @MainActor
    func testDeviceCapabilitiesIOSVersionFormat() {
        let capabilities = DeviceCapabilities()

        // iOS version should be in format "X.Y" or "X.Y.Z"
        let components = capabilities.iOSVersion.components(separatedBy: ".")
        XCTAssertGreaterThanOrEqual(components.count, 2, "iOS version should have at least major.minor")

        // First component should be a number (major version)
        XCTAssertNotNil(Int(components[0]), "Major version should be numeric")
    }

    @MainActor
    func testDeviceCapabilitiesAudioConfiguration() {
        let capabilities = DeviceCapabilities()

        let config = capabilities.recommendedAudioConfig

        // Should return a valid configuration
        XCTAssertFalse(config.description.isEmpty)

        // Valid configurations
        let validConfigs: [DeviceCapabilities.AudioConfiguration] = [.spatialAudio, .binauralBeats, .standard]
        XCTAssertTrue(validConfigs.contains(config))
    }

    @MainActor
    func testDeviceCapabilitiesCapabilitySummary() {
        let capabilities = DeviceCapabilities()

        let summary = capabilities.capabilitySummary
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("Device:"))
        XCTAssertTrue(summary.contains("iOS"))
        XCTAssertTrue(summary.contains("ASAF"))
    }

    @MainActor
    func testDeviceCapabilitiesHeadTrackingCheck() {
        let capabilities = DeviceCapabilities()

        // Head tracking requires iOS 14+
        let versionComponents = capabilities.iOSVersion.components(separatedBy: ".")
        if let majorVersion = Int(versionComponents.first ?? "0") {
            if majorVersion >= 14 {
                XCTAssertTrue(capabilities.canUseHeadTracking)
            } else {
                XCTAssertFalse(capabilities.canUseHeadTracking)
            }
        }
    }

    @MainActor
    func testDeviceCapabilitiesSpatialAudioEngineCheck() {
        let capabilities = DeviceCapabilities()

        // Spatial audio engine requires iOS 15+
        let versionComponents = capabilities.iOSVersion.components(separatedBy: ".")
        if let majorVersion = Int(versionComponents.first ?? "0") {
            if majorVersion >= 15 {
                XCTAssertTrue(capabilities.canUseSpatialAudioEngine)
            } else {
                XCTAssertFalse(capabilities.canUseSpatialAudioEngine)
            }
        }
    }

    @MainActor
    func testDeviceCapabilitiesAirPodsDetection() {
        let capabilities = DeviceCapabilities()

        // Without AirPods connected, should be false
        if !capabilities.hasAirPodsConnected {
            XCTAssertNil(capabilities.airPodsModel)
            XCTAssertFalse(capabilities.supportsAPACCodec)
        }
    }

    @MainActor
    func testDeviceCapabilitiesSpatialAudioRequirements() {
        let capabilities = DeviceCapabilities()

        // Full spatial audio requires both ASAF support AND AirPods
        if capabilities.canUseSpatialAudio {
            XCTAssertTrue(capabilities.supportsASAF)
            XCTAssertTrue(capabilities.hasAirPodsConnected)
        }
    }

    @MainActor
    func testDeviceCapabilitiesAudioRouteMonitoring() {
        let capabilities = DeviceCapabilities()

        // Start monitoring
        capabilities.startMonitoringAudioRoute()

        // Stop monitoring - should not crash
        capabilities.stopMonitoringAudioRoute()

        // Start again to test re-initialization
        capabilities.startMonitoringAudioRoute()
        capabilities.stopMonitoringAudioRoute()
    }

    @MainActor
    func testDeviceCapabilitiesDetectCapabilities() {
        let capabilities = DeviceCapabilities()

        // Force re-detection
        capabilities.detectCapabilities()

        // Should still have valid values
        XCTAssertFalse(capabilities.deviceModel.isEmpty)
        XCTAssertFalse(capabilities.iOSVersion.isEmpty)
    }

    // MARK: - AudioConfiguration Tests

    func testAudioConfigurationDescriptions() {
        let spatialDescription = DeviceCapabilities.AudioConfiguration.spatialAudio.description
        let binauralDescription = DeviceCapabilities.AudioConfiguration.binauralBeats.description
        let standardDescription = DeviceCapabilities.AudioConfiguration.standard.description

        XCTAssertTrue(spatialDescription.contains("Spatial"))
        XCTAssertTrue(binauralDescription.contains("Brainwave") || binauralDescription.contains("Headphones"))
        XCTAssertTrue(standardDescription.contains("Standard") || standardDescription.contains("Stereo"))
    }

    // MARK: - Edge Case Tests

    func testHeadRotationExtremeValues() {
        // Test with extreme radian values
        let rotation = HeadRotation(yaw: 2 * .pi, pitch: -2 * .pi, roll: 10 * .pi)

        // Should not crash, values should be stored
        XCTAssertEqual(rotation.yaw, 2 * .pi, accuracy: 0.001)
        XCTAssertEqual(rotation.pitch, -2 * .pi, accuracy: 0.001)
        XCTAssertEqual(rotation.roll, 10 * .pi, accuracy: 0.001)
    }

    func testNormalizedPositionOutOfRange() {
        // Values outside -1 to 1 should still be stored (clamping happens elsewhere)
        let position = NormalizedPosition(x: 2.0, y: -2.0, z: 100.0)

        XCTAssertEqual(position.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(position.y, -2.0, accuracy: 0.001)
        XCTAssertEqual(position.z, 100.0, accuracy: 0.001)
    }

    // MARK: - Performance Tests

    func testHeadRotationDegreesConversionPerformance() {
        let rotation = HeadRotation(yaw: 1.5, pitch: 0.5, roll: -0.3)

        measure {
            for _ in 0..<10000 {
                let _ = rotation.degrees
            }
        }
    }

    @MainActor
    func testDeviceCapabilitiesInitializationPerformance() {
        measure {
            let _ = DeviceCapabilities()
        }
    }
}
