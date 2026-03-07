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

// MARK: - AudioInterfaceRegistry Tests

final class AudioInterfaceRegistryTests: XCTestCase {

    func testBrandAllCasesCount() {
        let cases = AudioInterfaceRegistry.AudioInterfaceBrand.allCases
        XCTAssertEqual(cases.count, 20)
    }

    func testBrandRawValues() {
        XCTAssertEqual(AudioInterfaceRegistry.AudioInterfaceBrand.universalAudio.rawValue, "Universal Audio")
        XCTAssertEqual(AudioInterfaceRegistry.AudioInterfaceBrand.focusrite.rawValue, "Focusrite")
        XCTAssertEqual(AudioInterfaceRegistry.AudioInterfaceBrand.rme.rawValue, "RME")
        XCTAssertEqual(AudioInterfaceRegistry.AudioInterfaceBrand.ssl.rawValue, "SSL")
    }

    func testDriverTypeAllCasesCount() {
        let cases = AudioInterfaceRegistry.AudioDriverType.allCases
        XCTAssertEqual(cases.count, 15)
    }

    func testDriverRawValues() {
        XCTAssertEqual(AudioInterfaceRegistry.AudioDriverType.coreAudio.rawValue, "Core Audio")
        XCTAssertEqual(AudioInterfaceRegistry.AudioDriverType.asio.rawValue, "ASIO")
        XCTAssertEqual(AudioInterfaceRegistry.AudioDriverType.alsa.rawValue, "ALSA")
        XCTAssertEqual(AudioInterfaceRegistry.AudioDriverType.oboe.rawValue, "Oboe")
        XCTAssertEqual(AudioInterfaceRegistry.AudioDriverType.pipeWire.rawValue, "PipeWire")
    }

    func testRecommendedDriverForApple() {
        let registry = AudioInterfaceRegistry()
        XCTAssertEqual(registry.recommendedDriver(for: .iOS), .coreAudio)
        XCTAssertEqual(registry.recommendedDriver(for: .macOS), .coreAudio)
        XCTAssertEqual(registry.recommendedDriver(for: .iPadOS), .coreAudio)
        XCTAssertEqual(registry.recommendedDriver(for: .tvOS), .coreAudio)
        XCTAssertEqual(registry.recommendedDriver(for: .visionOS), .coreAudio)
    }

    func testRecommendedDriverForWindows() {
        let registry = AudioInterfaceRegistry()
        XCTAssertEqual(registry.recommendedDriver(for: .windows), .asio)
    }

    func testRecommendedDriverForLinux() {
        let registry = AudioInterfaceRegistry()
        XCTAssertEqual(registry.recommendedDriver(for: .linux), .pipeWire)
    }

    func testRecommendedDriverForAndroid() {
        let registry = AudioInterfaceRegistry()
        XCTAssertEqual(registry.recommendedDriver(for: .android), .oboe)
        XCTAssertEqual(registry.recommendedDriver(for: .wearOS), .oboe)
        XCTAssertEqual(registry.recommendedDriver(for: .androidTV), .oboe)
    }

    func testRecommendedDriverFallback() {
        let registry = AudioInterfaceRegistry()
        XCTAssertEqual(registry.recommendedDriver(for: .homeKit), .portAudio)
        XCTAssertEqual(registry.recommendedDriver(for: .custom), .portAudio)
    }

    func testInterfacesNotEmpty() {
        let registry = AudioInterfaceRegistry()
        XCTAssertFalse(registry.interfaces.isEmpty)
        XCTAssertGreaterThan(registry.interfaces.count, 50)
    }

    func testAudioInterfaceInit() {
        let iface = AudioInterfaceRegistry.AudioInterface(
            brand: .focusrite,
            model: "Test Interface",
            inputs: 2,
            outputs: 2,
            connectionTypes: [.usbC],
            platforms: [.macOS, .iOS]
        )

        XCTAssertEqual(iface.brand, .focusrite)
        XCTAssertEqual(iface.model, "Test Interface")
        XCTAssertEqual(iface.inputs, 2)
        XCTAssertEqual(iface.outputs, 2)
        XCTAssertTrue(iface.hasPreamps, "hasPreamps should default to true")
        XCTAssertFalse(iface.hasDSP, "hasDSP should default to false")
        XCTAssertFalse(iface.hasMIDI, "hasMIDI should default to false")
        XCTAssertEqual(iface.sampleRates, [44100, 48000, 88200, 96000, 176400, 192000])
        XCTAssertEqual(iface.bitDepths, [16, 24, 32])
    }
}

// MARK: - MIDIControllerRegistry Tests

final class MIDIControllerRegistryTests: XCTestCase {

    func testBrandAllCasesCount() {
        let cases = MIDIControllerRegistry.MIDIControllerBrand.allCases
        XCTAssertEqual(cases.count, 16)
    }

    func testControllerTypeAllCasesCount() {
        let cases = MIDIControllerRegistry.ControllerType.allCases
        XCTAssertEqual(cases.count, 10)
    }

    func testControllerTypeRawValues() {
        XCTAssertEqual(MIDIControllerRegistry.ControllerType.padController.rawValue, "Pad Controller")
        XCTAssertEqual(MIDIControllerRegistry.ControllerType.keyboard.rawValue, "Keyboard")
        XCTAssertEqual(MIDIControllerRegistry.ControllerType.mpeController.rawValue, "MPE Controller")
        XCTAssertEqual(MIDIControllerRegistry.ControllerType.windController.rawValue, "Wind Controller")
        XCTAssertEqual(MIDIControllerRegistry.ControllerType.drumController.rawValue, "Drum Controller")
    }

    func testControllersNotEmpty() {
        let registry = MIDIControllerRegistry()
        XCTAssertFalse(registry.controllers.isEmpty)
        XCTAssertGreaterThan(registry.controllers.count, 40)
    }

    func testControllerDefaultValues() {
        let controller = MIDIControllerRegistry.MIDIController(
            brand: .akai,
            model: "Test",
            type: .padController,
            connectionTypes: [.usb],
            platforms: [.macOS]
        )

        XCTAssertEqual(controller.pads, 0)
        XCTAssertEqual(controller.keys, 0)
        XCTAssertEqual(controller.faders, 0)
        XCTAssertEqual(controller.knobs, 0)
        XCTAssertFalse(controller.hasMPE)
        XCTAssertFalse(controller.hasDisplay)
        XCTAssertFalse(controller.isStandalone)
    }
}

// MARK: - VideoHardwareRegistry Tests

final class VideoHardwareRegistryTests: XCTestCase {

    func testCameraBrandAllCasesCount() {
        let cases = VideoHardwareRegistry.CameraBrand.allCases
        XCTAssertEqual(cases.count, 14)
    }

    func testCameraBrandRawValues() {
        XCTAssertEqual(VideoHardwareRegistry.CameraBrand.blackmagic.rawValue, "Blackmagic Design")
        XCTAssertEqual(VideoHardwareRegistry.CameraBrand.sony.rawValue, "Sony")
        XCTAssertEqual(VideoHardwareRegistry.CameraBrand.red.rawValue, "RED")
        XCTAssertEqual(VideoHardwareRegistry.CameraBrand.arri.rawValue, "ARRI")
    }

    func testVideoFormatAllCases() {
        let cases = VideoHardwareRegistry.VideoFormat.allCases
        XCTAssertEqual(cases.count, 7)
    }

    func testVideoFormatRawValues() {
        XCTAssertEqual(VideoHardwareRegistry.VideoFormat.hd720p.rawValue, "720p")
        XCTAssertEqual(VideoHardwareRegistry.VideoFormat.hd1080p.rawValue, "1080p")
        XCTAssertEqual(VideoHardwareRegistry.VideoFormat.uhd4k.rawValue, "4K UHD")
        XCTAssertEqual(VideoHardwareRegistry.VideoFormat.uhd8k.rawValue, "8K")
        XCTAssertEqual(VideoHardwareRegistry.VideoFormat.uhd12k.rawValue, "12K")
    }

    func testFrameRateAllCases() {
        let cases = VideoHardwareRegistry.FrameRate.allCases
        XCTAssertEqual(cases.count, 8)
    }

    func testFrameRateRawValues() {
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps24.rawValue, 24)
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps30.rawValue, 30)
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps60.rawValue, 60)
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps120.rawValue, 120)
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps240.rawValue, 240)
        XCTAssertEqual(VideoHardwareRegistry.FrameRate.fps1000.rawValue, 1000)
    }

    func testCamerasNotEmpty() {
        let registry = VideoHardwareRegistry()
        XCTAssertFalse(registry.cameras.isEmpty)
        XCTAssertGreaterThan(registry.cameras.count, 15)
    }

    func testCaptureCardsNotEmpty() {
        let registry = VideoHardwareRegistry()
        XCTAssertFalse(registry.captureCards.isEmpty)
    }

    func testCameraDefaultValues() {
        let camera = VideoHardwareRegistry.Camera(
            brand: .sony,
            model: "Test Cam",
            maxResolution: .uhd4k,
            maxFrameRate: .fps60,
            connectionTypes: [.hdmi]
        )

        XCTAssertFalse(camera.hasNDI)
        XCTAssertFalse(camera.hasSDI)
        XCTAssertFalse(camera.isPTZ)
    }

    func testCaptureCardDefaultValues() {
        let card = VideoHardwareRegistry.CaptureCard(
            brand: "Test",
            model: "Card 1",
            inputs: 2,
            maxResolution: .hd1080p,
            maxFrameRate: .fps60,
            connectionTypes: [.hdmi]
        )

        XCTAssertFalse(card.hasPassthrough)
        XCTAssertEqual(card.inputs, 2)
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

// MARK: - SequencerPattern Tests

final class SequencerPatternTests: XCTestCase {

    func testDefaultPatternAllInactive() {
        let pattern = SequencerPattern()
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<VisualStepSequencer.stepCount {
                XCTAssertFalse(pattern.isActive(channel: channel, step: step))
            }
        }
    }

    func testToggleStep() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))

        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))
    }

    func testDefaultVelocity() {
        let pattern = SequencerPattern()
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0, accuracy: 0.001)
    }

    func testSetVelocity() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual2, step: 3, velocity: 0.75)
        XCTAssertEqual(pattern.velocity(channel: .visual2, step: 3), 0.75, accuracy: 0.001)
    }

    func testVelocityClamping() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 1.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0, accuracy: 0.001)

        pattern.setVelocity(channel: .visual1, step: 0, velocity: -0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.0, accuracy: 0.001)
    }

    func testClearChannel() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .lighting, step: 0)
        pattern.toggle(channel: .lighting, step: 4)
        pattern.toggle(channel: .lighting, step: 8)
        pattern.clearChannel(.lighting)

        for step in 0..<VisualStepSequencer.stepCount {
            XCTAssertFalse(pattern.isActive(channel: .lighting, step: step))
        }
    }

    func testOutOfBoundsStepReturnsFalse() {
        let pattern = SequencerPattern()
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 99))
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 99), 0)
    }

    func testCodableRoundTrip() throws {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .effect1, step: 7)
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.8)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(pattern)
        let decoded = try decoder.decode(SequencerPattern.self, from: data)

        XCTAssertEqual(pattern, decoded)
        XCTAssertTrue(decoded.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(decoded.isActive(channel: .effect1, step: 7))
        XCTAssertEqual(decoded.velocity(channel: .visual1, step: 0), 0.8, accuracy: 0.001)
    }
}

// MARK: - VisualStepSequencer.Channel Tests

final class SequencerChannelTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(VisualStepSequencer.Channel.allCases.count, 8)
    }

    func testChannelRawValues() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.rawValue, 0)
        XCTAssertEqual(VisualStepSequencer.Channel.visual2.rawValue, 1)
        XCTAssertEqual(VisualStepSequencer.Channel.visual3.rawValue, 2)
        XCTAssertEqual(VisualStepSequencer.Channel.visual4.rawValue, 3)
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.rawValue, 4)
        XCTAssertEqual(VisualStepSequencer.Channel.effect1.rawValue, 5)
        XCTAssertEqual(VisualStepSequencer.Channel.effect2.rawValue, 6)
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.rawValue, 7)
    }

    func testChannelNames() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.name, "Visual A")
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.name, "Lighting")
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.name, "Bio Trigger")
    }

    func testChannelIdentifiable() {
        for channel in VisualStepSequencer.Channel.allCases {
            XCTAssertEqual(channel.id, channel.rawValue)
        }
    }
}

// MARK: - SequencerConstants Tests

final class SequencerConstantsTests: XCTestCase {

    func testStepCount() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
    }

    func testBpmRange() {
        XCTAssertEqual(VisualStepSequencer.bpmRange.lowerBound, 60)
        XCTAssertEqual(VisualStepSequencer.bpmRange.upperBound, 180)
    }

    func testChannelCount() {
        XCTAssertEqual(VisualStepSequencer.channelCount, 8)
        XCTAssertEqual(VisualStepSequencer.channelCount, VisualStepSequencer.Channel.allCases.count)
    }
}

// MARK: - BioModulationState Tests

final class BioModulationStateTests: XCTestCase {

    func testDefaultValues() {
        let state = BioModulationState()
        XCTAssertEqual(state.coherence, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.heartRate, 70.0, accuracy: 0.001)
        XCTAssertEqual(state.hrvVariability, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.skipProbability, 0.0, accuracy: 0.001)
        XCTAssertFalse(state.tempoLockEnabled)
    }
}

// MARK: - SequencerPreset Tests

final class SequencerPresetTests: XCTestCase {

    func testFourOnFloor() {
        let preset = SequencerPreset.fourOnFloor
        XCTAssertEqual(preset.id, "four_on_floor")
        XCTAssertEqual(preset.name, "Four on Floor")
        XCTAssertEqual(preset.bpm, 120)
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 4))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 8))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 12))
        XCTAssertFalse(preset.pattern.isActive(channel: .visual1, step: 1))
    }

    func testBreakbeat() {
        let preset = SequencerPreset.breakbeat
        XCTAssertEqual(preset.id, "breakbeat")
        XCTAssertEqual(preset.bpm, 90)
    }

    func testAmbient() {
        let preset = SequencerPreset.ambient
        XCTAssertEqual(preset.bpm, 70)
    }

    func testMinimal() {
        let preset = SequencerPreset.minimal
        XCTAssertEqual(preset.bpm, 110)
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .lighting, step: 8))
    }

    func testBioReactive() {
        let preset = SequencerPreset.bioReactive
        XCTAssertEqual(preset.bpm, 100)
        // Even steps on bioTrigger channel
        for step in stride(from: 0, to: 16, by: 2) {
            XCTAssertTrue(preset.pattern.isActive(channel: .bioTrigger, step: step))
        }
    }

    func testPresetsListCount() {
        XCTAssertEqual(VisualStepSequencer.presets.count, 5)
    }
}

// MARK: - LauncherClip Tests

final class LauncherClipTests: XCTestCase {

    func testDefaultInit() {
        let clip = LauncherClip()
        XCTAssertEqual(clip.name, "New Clip")
        XCTAssertEqual(clip.color, .blue)
        XCTAssertEqual(clip.type, .empty)
        XCTAssertEqual(clip.state, .stopped)
        XCTAssertTrue(clip.loopEnabled)
        XCTAssertEqual(clip.duration, 4.0, accuracy: 0.001)
        XCTAssertEqual(clip.warpMode, .beats)
        XCTAssertEqual(clip.quantization, .bar1)
        XCTAssertEqual(clip.velocity, 1.0, accuracy: 0.001)
        XCTAssertNil(clip.followAction)
        XCTAssertNil(clip.audioFileURL)
        XCTAssertNil(clip.midiData)
    }

    func testClipTypeAllCases() {
        XCTAssertEqual(LauncherClip.ClipType.allCases.count, 3)
        XCTAssertEqual(LauncherClip.ClipType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherClip.ClipType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherClip.ClipType.empty.rawValue, "Empty")
    }

    func testClipStateRawValues() {
        XCTAssertEqual(LauncherClip.ClipState.stopped.rawValue, "Stopped")
        XCTAssertEqual(LauncherClip.ClipState.queued.rawValue, "Queued")
        XCTAssertEqual(LauncherClip.ClipState.playing.rawValue, "Playing")
        XCTAssertEqual(LauncherClip.ClipState.recording.rawValue, "Recording")
    }

    func testClipColorAllCases() {
        XCTAssertEqual(LauncherClip.ClipColor.allCases.count, 10)
    }

    func testWarpModeAllCases() {
        XCTAssertEqual(LauncherClip.WarpMode.allCases.count, 6)
        XCTAssertEqual(LauncherClip.WarpMode.beats.rawValue, "Beats")
        XCTAssertEqual(LauncherClip.WarpMode.complexPro.rawValue, "Complex Pro")
    }

    func testQuantizationBeats() {
        XCTAssertEqual(LauncherClip.Quantization.none.beats, 0)
        XCTAssertEqual(LauncherClip.Quantization.bar1.beats, 4)
        XCTAssertEqual(LauncherClip.Quantization.bar2.beats, 8)
        XCTAssertEqual(LauncherClip.Quantization.bar4.beats, 16)
        XCTAssertEqual(LauncherClip.Quantization.bar8.beats, 32)
        XCTAssertEqual(LauncherClip.Quantization.beat1.beats, 1)
        XCTAssertEqual(LauncherClip.Quantization.beat1_2.beats, 0.5)
        XCTAssertEqual(LauncherClip.Quantization.beat1_4.beats, 0.25)
    }

    func testQuantizationAllCases() {
        XCTAssertEqual(LauncherClip.Quantization.allCases.count, 8)
    }

    func testFollowActionAllCases() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.allCases.count, 9)
    }

    func testClipCodableRoundTrip() throws {
        let clip = LauncherClip(
            name: "Test Clip",
            color: .green,
            type: .audio,
            duration: 8.0
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(clip)
        let decoded = try decoder.decode(LauncherClip.self, from: data)

        XCTAssertEqual(decoded.name, "Test Clip")
        XCTAssertEqual(decoded.color, .green)
        XCTAssertEqual(decoded.type, .audio)
        XCTAssertEqual(decoded.duration, 8.0, accuracy: 0.001)
    }
}

// MARK: - LauncherTrack Tests

final class LauncherTrackTests: XCTestCase {

    func testDefaultInit() {
        let track = LauncherTrack()
        XCTAssertEqual(track.name, "Track")
        XCTAssertEqual(track.type, .audio)
        XCTAssertEqual(track.clips.count, 8)
        XCTAssertEqual(track.volume, 0.8, accuracy: 0.001)
        XCTAssertEqual(track.pan, 0, accuracy: 0.001)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSoloed)
        XCTAssertFalse(track.isArmed)
        XCTAssertEqual(track.color, .blue)
        XCTAssertEqual(track.sendLevels, [0, 0])
    }

    func testTrackTypeAllCases() {
        XCTAssertEqual(LauncherTrack.TrackType.allCases.count, 5)
        XCTAssertEqual(LauncherTrack.TrackType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherTrack.TrackType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherTrack.TrackType.group.rawValue, "Group")
        XCTAssertEqual(LauncherTrack.TrackType.return_.rawValue, "Return")
        XCTAssertEqual(LauncherTrack.TrackType.master.rawValue, "Master")
    }

    func testCustomClipCount() {
        let track = LauncherTrack(clipCount: 16)
        XCTAssertEqual(track.clips.count, 16)
    }
}

// MARK: - LauncherScene Tests

final class LauncherSceneTests: XCTestCase {

    func testDefaultInit() {
        let scene = LauncherScene()
        XCTAssertEqual(scene.name, "Scene")
        XCTAssertEqual(scene.color, .gray)
        XCTAssertNil(scene.tempo)
        XCTAssertNil(scene.timeSignature)
    }

    func testCustomInit() {
        let scene = LauncherScene(name: "Intro", color: .red)
        XCTAssertEqual(scene.name, "Intro")
        XCTAssertEqual(scene.color, .red)
    }

    func testCodableRoundTrip() throws {
        let scene = LauncherScene(name: "Bridge", color: .cyan)
        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(LauncherScene.self, from: data)

        XCTAssertEqual(decoded.name, "Bridge")
        XCTAssertEqual(decoded.color, .cyan)
    }
}

// MARK: - StepData Tests

final class StepDataTests: XCTestCase {

    func testDefaultValues() {
        let step = SequencerPattern.StepData()
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 1.0, accuracy: 0.001)
        XCTAssertEqual(step.parameter, 0.5, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        var step = SequencerPattern.StepData()
        step.isActive = true
        step.velocity = 0.6
        step.parameter = 0.9

        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequencerPattern.StepData.self, from: data)

        XCTAssertTrue(decoded.isActive)
        XCTAssertEqual(decoded.velocity, 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.parameter, 0.9, accuracy: 0.001)
    }
}

// MARK: - Notification Name Tests

final class NotificationNameTests: XCTestCase {

    func testSequencerStepTriggeredName() {
        XCTAssertEqual(Notification.Name.sequencerStepTriggered.rawValue, "sequencerStepTriggered")
    }
}
#endif
