#if canImport(AVFoundation)
// HardwareThemeTests.swift
// Echoelmusic
//
// Comprehensive tests for Hardware, Theme, Sequencer, and Performance types.
// Tests enums, structs, value types, Codable conformance, computed properties,
// boundary conditions, and default values.

import XCTest
import Foundation
@testable import Echoelmusic

// MARK: - EcosystemStatus Tests

final class EcosystemStatusTests: XCTestCase {

    func testAllCases() {
        let cases = EcosystemStatus.allCases
        XCTAssertEqual(cases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(EcosystemStatus.initializing.rawValue, "Initializing")
        XCTAssertEqual(EcosystemStatus.ready.rawValue, "Ready")
        XCTAssertEqual(EcosystemStatus.scanning.rawValue, "Scanning")
        XCTAssertEqual(EcosystemStatus.connected.rawValue, "Connected")
        XCTAssertEqual(EcosystemStatus.error.rawValue, "Error")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(EcosystemStatus(rawValue: "Ready"), .ready)
        XCTAssertNil(EcosystemStatus(rawValue: "invalid"))
    }
}

// MARK: - DeviceType Tests

final class DeviceTypeTests: XCTestCase {

    func testAllCasesCount() {
        let cases = DeviceType.allCases
        XCTAssertEqual(cases.count, 27)
    }

    func testAppleDeviceRawValues() {
        XCTAssertEqual(DeviceType.iPhone.rawValue, "iPhone")
        XCTAssertEqual(DeviceType.iPad.rawValue, "iPad")
        XCTAssertEqual(DeviceType.mac.rawValue, "Mac")
        XCTAssertEqual(DeviceType.appleWatch.rawValue, "Apple Watch")
        XCTAssertEqual(DeviceType.appleTv.rawValue, "Apple TV")
        XCTAssertEqual(DeviceType.visionPro.rawValue, "Apple Vision Pro")
    }

    func testAudioHardwareRawValues() {
        XCTAssertEqual(DeviceType.audioInterface.rawValue, "Audio Interface")
        XCTAssertEqual(DeviceType.midiController.rawValue, "MIDI Controller")
        XCTAssertEqual(DeviceType.synthesizer.rawValue, "Synthesizer")
        XCTAssertEqual(DeviceType.drumMachine.rawValue, "Drum Machine")
    }

    func testInvalidRawValue() {
        XCTAssertNil(DeviceType(rawValue: "Nonexistent"))
    }
}

// MARK: - DevicePlatform Tests

final class DevicePlatformTests: XCTestCase {

    func testAllCasesCount() {
        let cases = DevicePlatform.allCases
        XCTAssertEqual(cases.count, 15)
    }

    func testApplePlatformRawValues() {
        XCTAssertEqual(DevicePlatform.iOS.rawValue, "iOS")
        XCTAssertEqual(DevicePlatform.iPadOS.rawValue, "iPadOS")
        XCTAssertEqual(DevicePlatform.macOS.rawValue, "macOS")
        XCTAssertEqual(DevicePlatform.watchOS.rawValue, "watchOS")
        XCTAssertEqual(DevicePlatform.visionOS.rawValue, "visionOS")
    }

    func testSmartHomePlatforms() {
        XCTAssertEqual(DevicePlatform.homeKit.rawValue, "HomeKit")
        XCTAssertEqual(DevicePlatform.googleHome.rawValue, "Google Home")
        XCTAssertEqual(DevicePlatform.alexa.rawValue, "Alexa")
        XCTAssertEqual(DevicePlatform.matter.rawValue, "Matter")
    }
}

// MARK: - ConnectionType Tests

final class ConnectionTypeTests: XCTestCase {

    func testAllCasesCount() {
        let cases = ConnectionType.allCases
        XCTAssertEqual(cases.count, 23)
    }

    func testWiredConnectionRawValues() {
        XCTAssertEqual(ConnectionType.usb.rawValue, "USB")
        XCTAssertEqual(ConnectionType.usbC.rawValue, "USB-C")
        XCTAssertEqual(ConnectionType.thunderbolt.rawValue, "Thunderbolt")
        XCTAssertEqual(ConnectionType.hdmi.rawValue, "HDMI")
        XCTAssertEqual(ConnectionType.sdi.rawValue, "SDI")
        XCTAssertEqual(ConnectionType.xlr.rawValue, "XLR")
        XCTAssertEqual(ConnectionType.dmx.rawValue, "DMX")
        XCTAssertEqual(ConnectionType.midi5Pin.rawValue, "MIDI 5-Pin")
    }

    func testWirelessConnectionRawValues() {
        XCTAssertEqual(ConnectionType.bluetooth.rawValue, "Bluetooth")
        XCTAssertEqual(ConnectionType.bluetoothLE.rawValue, "Bluetooth LE")
        XCTAssertEqual(ConnectionType.wifi.rawValue, "WiFi")
        XCTAssertEqual(ConnectionType.airPlay.rawValue, "AirPlay")
        XCTAssertEqual(ConnectionType.ndi.rawValue, "NDI")
        XCTAssertEqual(ConnectionType.artNet.rawValue, "Art-Net")
        XCTAssertEqual(ConnectionType.osc.rawValue, "OSC")
    }

    func testStreamingProtocolRawValues() {
        XCTAssertEqual(ConnectionType.rtmp.rawValue, "RTMP")
        XCTAssertEqual(ConnectionType.srt.rawValue, "SRT")
        XCTAssertEqual(ConnectionType.webRTC.rawValue, "WebRTC")
        XCTAssertEqual(ConnectionType.hls.rawValue, "HLS")
    }
}

// MARK: - DeviceCapability Tests

final class DeviceCapabilityTests: XCTestCase {

    func testAllCasesCount() {
        let cases = DeviceCapability.allCases
        XCTAssertEqual(cases.count, 27)
    }

    func testAudioCapabilityRawValues() {
        XCTAssertEqual(DeviceCapability.audioInput.rawValue, "Audio Input")
        XCTAssertEqual(DeviceCapability.audioOutput.rawValue, "Audio Output")
        XCTAssertEqual(DeviceCapability.midiInput.rawValue, "MIDI Input")
        XCTAssertEqual(DeviceCapability.midiOutput.rawValue, "MIDI Output")
        XCTAssertEqual(DeviceCapability.spatialAudio.rawValue, "Spatial Audio")
        XCTAssertEqual(DeviceCapability.lowLatencyAudio.rawValue, "Low Latency Audio")
    }

    func testBiometricCapabilityRawValues() {
        XCTAssertEqual(DeviceCapability.heartRate.rawValue, "Heart Rate")
        XCTAssertEqual(DeviceCapability.hrv.rawValue, "HRV")
        XCTAssertEqual(DeviceCapability.bloodOxygen.rawValue, "Blood Oxygen")
        XCTAssertEqual(DeviceCapability.ecg.rawValue, "ECG")
        XCTAssertEqual(DeviceCapability.breathing.rawValue, "Breathing")
    }

    func testLightingCapabilityRawValues() {
        XCTAssertEqual(DeviceCapability.dmxControl.rawValue, "DMX Control")
        XCTAssertEqual(DeviceCapability.rgbControl.rawValue, "RGB Control")
        XCTAssertEqual(DeviceCapability.movingHead.rawValue, "Moving Head")
        XCTAssertEqual(DeviceCapability.laser.rawValue, "Laser")
    }
}

// MARK: - ConnectedDevice Tests

final class ConnectedDeviceTests: XCTestCase {

    func testInitialization() {
        let device = ConnectedDevice(
            name: "Test Device",
            type: .iPhone,
            platform: .iOS,
            connectionType: .bluetooth,
            capabilities: [.audioOutput, .heartRate]
        )

        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.type, .iPhone)
        XCTAssertEqual(device.platform, .iOS)
        XCTAssertEqual(device.connectionType, .bluetooth)
        XCTAssertEqual(device.capabilities, [.audioOutput, .heartRate])
        XCTAssertTrue(device.isActive)
        XCTAssertEqual(device.latencyMs, 0)
    }

    func testDefaultValues() {
        let device = ConnectedDevice(
            name: "Default",
            type: .mac,
            platform: .macOS,
            connectionType: .thunderbolt,
            capabilities: []
        )

        XCTAssertTrue(device.isActive, "Device should be active by default")
        XCTAssertEqual(device.latencyMs, 0, "Default latency should be 0")
    }

    func testCustomLatency() {
        let device = ConnectedDevice(
            name: "BT Device",
            type: .airPods,
            platform: .iOS,
            connectionType: .bluetooth,
            capabilities: [.audioOutput],
            latencyMs: 150.0
        )

        XCTAssertEqual(device.latencyMs, 150.0)
    }

    func testHashable() {
        let id = UUID()
        let device1 = ConnectedDevice(id: id, name: "A", type: .iPhone, platform: .iOS, connectionType: .wifi, capabilities: [])
        let device2 = ConnectedDevice(id: id, name: "A", type: .iPhone, platform: .iOS, connectionType: .wifi, capabilities: [])

        XCTAssertEqual(device1, device2)
    }

    func testCapabilitiesSet() {
        let capabilities: Set<DeviceCapability> = [.audioInput, .audioOutput, .midiInput, .midiOutput, .audioInput]
        XCTAssertEqual(capabilities.count, 4, "Set should deduplicate capabilities")
    }
}

// MARK: - MultiDeviceSession Tests

final class MultiDeviceSessionTests: XCTestCase {

    func testSyncModeAllCases() {
        let cases = MultiDeviceSession.SyncMode.allCases
        XCTAssertEqual(cases.count, 4)
    }

    func testSyncModeRawValues() {
        XCTAssertEqual(MultiDeviceSession.SyncMode.master.rawValue, "Master")
        XCTAssertEqual(MultiDeviceSession.SyncMode.slave.rawValue, "Slave")
        XCTAssertEqual(MultiDeviceSession.SyncMode.peer.rawValue, "Peer-to-Peer")
        XCTAssertEqual(MultiDeviceSession.SyncMode.cloud.rawValue, "Cloud Sync")
    }

    func testDefaultInit() {
        let session = MultiDeviceSession(name: "Test Session")

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertTrue(session.devices.isEmpty)
        XCTAssertEqual(session.syncMode, .peer)
        XCTAssertTrue(session.latencyCompensation)
    }

    func testCustomInit() {
        let device = ConnectedDevice(
            name: "Device",
            type: .iPad,
            platform: .iPadOS,
            connectionType: .wifi,
            capabilities: [.audioOutput]
        )
        let session = MultiDeviceSession(
            name: "Custom",
            devices: [device],
            syncMode: .master,
            latencyCompensation: false
        )

        XCTAssertEqual(session.devices.count, 1)
        XCTAssertEqual(session.syncMode, .master)
        XCTAssertFalse(session.latencyCompensation)
    }
}

// MARK: - AppThemeMode Tests

final class AppThemeModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AppThemeMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(AppThemeMode.dark.rawValue, "Dark")
        XCTAssertEqual(AppThemeMode.light.rawValue, "Light")
        XCTAssertEqual(AppThemeMode.system.rawValue, "System")
    }

    func testIconValues() {
        XCTAssertEqual(AppThemeMode.dark.icon, "moon.fill")
        XCTAssertEqual(AppThemeMode.light.icon, "sun.max.fill")
        XCTAssertEqual(AppThemeMode.system.icon, "circle.lefthalf.filled")
    }

    func testDisplayNames() {
        XCTAssertEqual(AppThemeMode.dark.displayName, "Dunkel")
        XCTAssertEqual(AppThemeMode.light.displayName, "Hell")
        XCTAssertEqual(AppThemeMode.system.displayName, "System")
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for mode in AppThemeMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(AppThemeMode.self, from: data)
            XCTAssertEqual(mode, decoded)
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(AppThemeMode(rawValue: "Dark"), .dark)
        XCTAssertEqual(AppThemeMode(rawValue: "Light"), .light)
        XCTAssertEqual(AppThemeMode(rawValue: "System"), .system)
        XCTAssertNil(AppThemeMode(rawValue: "Auto"))
    }
}

// MARK: - LiquidGlass.Tint Tests

final class LiquidGlassTintTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(LiquidGlass.Tint.allCases.count, 9)
    }

    func testOpacityValues() {
        XCTAssertEqual(LiquidGlass.Tint.clear.opacity, 0.1, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.subtle.opacity, 0.2, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.vibrant.opacity, 0.4, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.ultraThin.opacity, 0.05, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.thick.opacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.chromatic.opacity, 0.3, accuracy: 0.001)
    }

    func testCoherenceTintOpacity() {
        XCTAssertEqual(LiquidGlass.Tint.coherenceLow.opacity, 0.25, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.coherenceMedium.opacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(LiquidGlass.Tint.coherenceHigh.opacity, 0.45, accuracy: 0.001)
    }

    func testBlurValues() {
        XCTAssertEqual(LiquidGlass.Tint.clear.blur, 20)
        XCTAssertEqual(LiquidGlass.Tint.ultraThin.blur, 20)
        XCTAssertEqual(LiquidGlass.Tint.subtle.blur, 30)
        XCTAssertEqual(LiquidGlass.Tint.vibrant.blur, 40)
        XCTAssertEqual(LiquidGlass.Tint.thick.blur, 50)
        XCTAssertEqual(LiquidGlass.Tint.coherenceLow.blur, 35)
        XCTAssertEqual(LiquidGlass.Tint.coherenceMedium.blur, 35)
        XCTAssertEqual(LiquidGlass.Tint.coherenceHigh.blur, 35)
    }

    func testRawValues() {
        XCTAssertEqual(LiquidGlass.Tint.clear.rawValue, "Clear")
        XCTAssertEqual(LiquidGlass.Tint.coherenceHigh.rawValue, "Coherence High")
    }
}

// MARK: - LiquidGlass.DepthLevel Tests

final class LiquidGlassDepthLevelTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(LiquidGlass.DepthLevel.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(LiquidGlass.DepthLevel.background.rawValue, 0)
        XCTAssertEqual(LiquidGlass.DepthLevel.base.rawValue, 1)
        XCTAssertEqual(LiquidGlass.DepthLevel.elevated.rawValue, 2)
        XCTAssertEqual(LiquidGlass.DepthLevel.floating.rawValue, 3)
        XCTAssertEqual(LiquidGlass.DepthLevel.overlay.rawValue, 4)
        XCTAssertEqual(LiquidGlass.DepthLevel.modal.rawValue, 5)
    }

    func testShadowRadiusIncreases() {
        let levels = LiquidGlass.DepthLevel.allCases.sorted { $0.rawValue < $1.rawValue }
        for i in 0..<(levels.count - 1) {
            XCTAssertLessThanOrEqual(
                levels[i].shadowRadius,
                levels[i + 1].shadowRadius,
                "Shadow radius should increase with depth"
            )
        }
    }

    func testShadowRadiusValues() {
        XCTAssertEqual(LiquidGlass.DepthLevel.background.shadowRadius, 0)
        XCTAssertEqual(LiquidGlass.DepthLevel.base.shadowRadius, 2)
        XCTAssertEqual(LiquidGlass.DepthLevel.elevated.shadowRadius, 8)
        XCTAssertEqual(LiquidGlass.DepthLevel.floating.shadowRadius, 16)
        XCTAssertEqual(LiquidGlass.DepthLevel.overlay.shadowRadius, 24)
        XCTAssertEqual(LiquidGlass.DepthLevel.modal.shadowRadius, 32)
    }

    func testZOffset() {
        XCTAssertEqual(LiquidGlass.DepthLevel.background.zOffset, 0)
        XCTAssertEqual(LiquidGlass.DepthLevel.base.zOffset, 10)
        XCTAssertEqual(LiquidGlass.DepthLevel.elevated.zOffset, 20)
        XCTAssertEqual(LiquidGlass.DepthLevel.modal.zOffset, 50)
    }
}

// MARK: - LiquidGlass.CornerStyle Tests

final class LiquidGlassCornerStyleTests: XCTestCase {

    func testSharpRadius() {
        let radius = LiquidGlass.CornerStyle.sharp.radius(for: CGSize(width: 100, height: 100))
        XCTAssertEqual(radius, 0)
    }

    func testRoundedRadius() {
        let radius = LiquidGlass.CornerStyle.rounded.radius(for: CGSize(width: 100, height: 100))
        XCTAssertEqual(radius, 12)
    }

    func testContinuousRadius() {
        let size = CGSize(width: 200, height: 100)
        let radius = LiquidGlass.CornerStyle.continuous.radius(for: size)
        XCTAssertEqual(radius, 20, "Continuous should be 20% of min dimension")
    }

    func testPillRadius() {
        let size = CGSize(width: 200, height: 50)
        let radius = LiquidGlass.CornerStyle.pill.radius(for: size)
        XCTAssertEqual(radius, 25, "Pill should be half of min dimension")
    }

    func testCircleRadius() {
        let size = CGSize(width: 100, height: 100)
        let radius = LiquidGlass.CornerStyle.circle.radius(for: size)
        XCTAssertEqual(radius, 50)
    }
}

// MARK: - EchoelBrand Constants Tests

final class EchoelBrandTests: XCTestCase {

    func testTagline() {
        XCTAssertEqual(EchoelBrand.taglineJoined, "Create from Within")
        XCTAssertEqual(EchoelBrand.slogan, "Create from Within")
        XCTAssertFalse(EchoelBrand.description.isEmpty)
    }

    func testDisclaimerTexts() {
        XCTAssertFalse(EchoelDisclaimer.short.isEmpty)
        XCTAssertFalse(EchoelDisclaimer.medium.isEmpty)
        XCTAssertFalse(EchoelDisclaimer.full.isEmpty)
        XCTAssertFalse(EchoelDisclaimer.seizureWarning.isEmpty)
        XCTAssertTrue(EchoelDisclaimer.full.contains("IMPORTANT"))
        XCTAssertTrue(EchoelDisclaimer.seizureWarning.contains("seizures"))
    }
}

// MARK: - EchoelSpacing Tests

final class EchoelSpacingTests: XCTestCase {

    func testSpacingValues() {
        XCTAssertEqual(EchoelSpacing.xxs, 2)
        XCTAssertEqual(EchoelSpacing.xs, 4)
        XCTAssertEqual(EchoelSpacing.sm, 8)
        XCTAssertEqual(EchoelSpacing.md, 16)
        XCTAssertEqual(EchoelSpacing.lg, 24)
        XCTAssertEqual(EchoelSpacing.xl, 32)
        XCTAssertEqual(EchoelSpacing.xxl, 48)
        XCTAssertEqual(EchoelSpacing.xxxl, 64)
    }

    func testSpacingIncreases() {
        let values: [CGFloat] = [
            EchoelSpacing.xxs, EchoelSpacing.xs, EchoelSpacing.sm,
            EchoelSpacing.md, EchoelSpacing.lg, EchoelSpacing.xl,
            EchoelSpacing.xxl, EchoelSpacing.xxxl
        ]
        for i in 0..<(values.count - 1) {
            XCTAssertLessThan(values[i], values[i + 1], "Spacing should strictly increase")
        }
    }
}

// MARK: - EchoelRadius Tests

final class EchoelRadiusTests: XCTestCase {

    func testRadiusValues() {
        XCTAssertEqual(EchoelRadius.xs, 4)
        XCTAssertEqual(EchoelRadius.sm, 8)
        XCTAssertEqual(EchoelRadius.md, 12)
        XCTAssertEqual(EchoelRadius.lg, 16)
        XCTAssertEqual(EchoelRadius.xl, 24)
        XCTAssertEqual(EchoelRadius.full, 9999)
    }
}

// MARK: - EchoelAnimation Tests

final class EchoelAnimationTests: XCTestCase {

    func testTimingValues() {
        XCTAssertEqual(EchoelAnimation.quick, 0.15, accuracy: 0.001)
        XCTAssertEqual(EchoelAnimation.smooth, 0.3, accuracy: 0.001)
        XCTAssertEqual(EchoelAnimation.breathing, 4.0, accuracy: 0.001)
        XCTAssertEqual(EchoelAnimation.pulse, 1.0, accuracy: 0.001)
        XCTAssertEqual(EchoelAnimation.coherenceGlow, 2.0, accuracy: 0.001)
    }
}

// MARK: - EchoelIconConfig Tests

final class EchoelIconConfigTests: XCTestCase {

    func testIconSizesNotEmpty() {
        XCTAssertFalse(EchoelIconConfig.sizes.isEmpty)
    }

    func testAppStoreIconPresent() {
        let appStoreSizes = EchoelIconConfig.sizes.filter { $0.size == 1024 }
        XCTAssertFalse(appStoreSizes.isEmpty, "Should include 1024pt App Store icon")
    }

    func testIPhoneSizesPresent() {
        let iphoneSizes = EchoelIconConfig.sizes.filter { $0.platform == "iphone" }
        XCTAssertGreaterThan(iphoneSizes.count, 0)
    }

    func testMacSizesPresent() {
        let macSizes = EchoelIconConfig.sizes.filter { $0.platform == "mac" }
        XCTAssertGreaterThan(macSizes.count, 0)
    }

    func testWatchSizesPresent() {
        let watchSizes = EchoelIconConfig.sizes.filter { $0.platform == "watch" }
        XCTAssertGreaterThan(watchSizes.count, 0)
    }
}

// MARK: - EchoelBrandFont Tests

final class EchoelBrandFontTests: XCTestCase {

    func testPreferredFontNames() {
        XCTAssertEqual(EchoelBrandFont.preferredFontName, "AtkinsonHyperlegible-Regular")
        XCTAssertEqual(EchoelBrandFont.preferredFontNameBold, "AtkinsonHyperlegible-Bold")
    }
}

// MARK: - VaporwaveSpacing Tests

final class VaporwaveSpacingTests: XCTestCase {

    func testMatchesEchoelSpacing() {
        XCTAssertEqual(VaporwaveSpacing.xs, EchoelSpacing.xs)
        XCTAssertEqual(VaporwaveSpacing.sm, EchoelSpacing.sm)
        XCTAssertEqual(VaporwaveSpacing.md, EchoelSpacing.md)
        XCTAssertEqual(VaporwaveSpacing.lg, EchoelSpacing.lg)
        XCTAssertEqual(VaporwaveSpacing.xl, EchoelSpacing.xl)
        XCTAssertEqual(VaporwaveSpacing.xxl, EchoelSpacing.xxl)
    }
}

#endif
