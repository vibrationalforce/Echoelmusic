import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Hardware Ecosystem - Phase 10000 ULTIMATE
/// Tests all device combinations, cross-platform sync, and latency compensation
final class HardwareEcosystemTests: XCTestCase {

    // MARK: - Hardware Ecosystem Tests

    func testHardwareEcosystemSingleton() {
        let ecosystem1 = HardwareEcosystem.shared
        let ecosystem2 = HardwareEcosystem.shared
        XCTAssertTrue(ecosystem1 === ecosystem2, "HardwareEcosystem should be singleton")
    }

    func testEcosystemStatusReady() {
        let ecosystem = HardwareEcosystem.shared
        XCTAssertEqual(ecosystem.ecosystemStatus, .ready)
    }

    // MARK: - Audio Interface Registry Tests

    func testAudioInterfaceRegistryNotEmpty() {
        let registry = AudioInterfaceRegistry()
        XCTAssertFalse(registry.interfaces.isEmpty, "Audio interfaces should not be empty")
        XCTAssertGreaterThan(registry.interfaces.count, 50, "Should have 50+ audio interfaces")
    }

    func testUniversalAudioInterfacesExist() {
        let registry = AudioInterfaceRegistry()
        let uaInterfaces = registry.interfaces.filter { $0.brand == .universalAudio }
        XCTAssertFalse(uaInterfaces.isEmpty, "Universal Audio interfaces should exist")
        XCTAssertTrue(uaInterfaces.contains { $0.model == "Apollo Twin X" })
        XCTAssertTrue(uaInterfaces.contains { $0.model == "Volt 2" })
    }

    func testFocusriteInterfacesExist() {
        let registry = AudioInterfaceRegistry()
        let focusriteInterfaces = registry.interfaces.filter { $0.brand == .focusrite }
        XCTAssertFalse(focusriteInterfaces.isEmpty)
        XCTAssertTrue(focusriteInterfaces.contains { $0.model.contains("Scarlett") })
    }

    func testRMEInterfacesExist() {
        let registry = AudioInterfaceRegistry()
        let rmeInterfaces = registry.interfaces.filter { $0.brand == .rme }
        XCTAssertFalse(rmeInterfaces.isEmpty)
        XCTAssertTrue(rmeInterfaces.contains { $0.model == "Babyface Pro FS" })
    }

    func testMOTUInterfacesExist() {
        let registry = AudioInterfaceRegistry()
        let motuInterfaces = registry.interfaces.filter { $0.brand == .motu }
        XCTAssertFalse(motuInterfaces.isEmpty)
        XCTAssertTrue(motuInterfaces.contains { $0.model == "M2" })
        XCTAssertTrue(motuInterfaces.contains { $0.model == "M4" })
    }

    func testRecommendedDriverForMacOS() {
        let registry = AudioInterfaceRegistry()
        let driver = registry.recommendedDriver(for: .macOS)
        XCTAssertEqual(driver, .coreAudio)
    }

    func testRecommendedDriverForWindows() {
        let registry = AudioInterfaceRegistry()
        let driver = registry.recommendedDriver(for: .windows)
        XCTAssertEqual(driver, .asio)
    }

    func testRecommendedDriverForLinux() {
        let registry = AudioInterfaceRegistry()
        let driver = registry.recommendedDriver(for: .linux)
        XCTAssertEqual(driver, .pipeWire)
    }

    func testRecommendedDriverForAndroid() {
        let registry = AudioInterfaceRegistry()
        let driver = registry.recommendedDriver(for: .android)
        XCTAssertEqual(driver, .oboe)
    }

    // MARK: - MIDI Controller Registry Tests

    func testMIDIControllerRegistryNotEmpty() {
        let registry = MIDIControllerRegistry()
        XCTAssertFalse(registry.controllers.isEmpty)
        XCTAssertGreaterThan(registry.controllers.count, 30, "Should have 30+ MIDI controllers")
    }

    func testAbletonPush3Exists() {
        let registry = MIDIControllerRegistry()
        let push3 = registry.controllers.first { $0.model == "Push 3" }
        XCTAssertNotNil(push3)
        XCTAssertEqual(push3?.brand, .ableton)
        XCTAssertEqual(push3?.pads, 64)
        XCTAssertTrue(push3?.hasMPE ?? false)
        XCTAssertTrue(push3?.hasDisplay ?? false)
        XCTAssertTrue(push3?.isStandalone ?? false)
    }

    func testNovationLaunchpadExists() {
        let registry = MIDIControllerRegistry()
        let launchpads = registry.controllers.filter { $0.brand == .novation && $0.model.contains("Launchpad") }
        XCTAssertFalse(launchpads.isEmpty)
    }

    func testNativeInstrumentsMaschineExists() {
        let registry = MIDIControllerRegistry()
        let maschine = registry.controllers.filter { $0.brand == .nativeInstruments && $0.model.contains("Maschine") }
        XCTAssertFalse(maschine.isEmpty)
    }

    func testAkaiMPCExists() {
        let registry = MIDIControllerRegistry()
        let mpc = registry.controllers.filter { $0.brand == .akai && $0.model.contains("MPC") }
        XCTAssertFalse(mpc.isEmpty)
    }

    func testMPEControllersExist() {
        let registry = MIDIControllerRegistry()
        let mpeControllers = registry.controllers.filter { $0.hasMPE }
        XCTAssertFalse(mpeControllers.isEmpty, "MPE controllers should exist")
        XCTAssertTrue(mpeControllers.contains { $0.brand == .roli })
        XCTAssertTrue(mpeControllers.contains { $0.brand == .expressiveE })
    }

    // MARK: - Lighting Hardware Registry Tests

    func testLightingRegistryNotEmpty() {
        let registry = LightingHardwareRegistry()
        XCTAssertFalse(registry.controllers.isEmpty)
    }

    func testDMXControllersExist() {
        let registry = LightingHardwareRegistry()
        let enttec = registry.controllers.filter { $0.brand == "ENTTEC" }
        XCTAssertFalse(enttec.isEmpty)
        XCTAssertTrue(enttec.contains { $0.name.contains("DMX USB Pro") })
    }

    func testSmartLightingSystemsExist() {
        let registry = LightingHardwareRegistry()
        XCTAssertFalse(registry.smartLightingSystems.isEmpty)
        XCTAssertTrue(registry.smartLightingSystems.contains { $0.name.contains("Philips Hue") })
        XCTAssertTrue(registry.smartLightingSystems.contains { $0.name.contains("Nanoleaf") })
    }

    // MARK: - Video Hardware Registry Tests

    func testVideoRegistryNotEmpty() {
        let registry = VideoHardwareRegistry()
        XCTAssertFalse(registry.cameras.isEmpty)
        XCTAssertFalse(registry.captureCards.isEmpty)
    }

    func testBlackmagicCamerasExist() {
        let registry = VideoHardwareRegistry()
        let blackmagic = registry.cameras.filter { $0.brand == .blackmagic }
        XCTAssertFalse(blackmagic.isEmpty)
    }

    func testNDICamerasExist() {
        let registry = VideoHardwareRegistry()
        let ndiCameras = registry.cameras.filter { $0.hasNDI }
        XCTAssertFalse(ndiCameras.isEmpty, "NDI cameras should exist")
    }

    func testCaptureCardsExist() {
        let registry = VideoHardwareRegistry()
        let elgato = registry.captureCards.filter { $0.brand == "Elgato" }
        XCTAssertFalse(elgato.isEmpty)
    }

    // MARK: - Broadcast Equipment Registry Tests

    func testBroadcastEquipmentNotEmpty() {
        let registry = BroadcastEquipmentRegistry()
        XCTAssertFalse(registry.switchers.isEmpty)
        XCTAssertFalse(registry.streamingPlatforms.isEmpty)
        XCTAssertFalse(registry.streamingProtocols.isEmpty)
    }

    func testATEMSwitchersExist() {
        let registry = BroadcastEquipmentRegistry()
        let atem = registry.switchers.filter { $0.type == .atem }
        XCTAssertFalse(atem.isEmpty)
        XCTAssertTrue(atem.contains { $0.model == "ATEM Mini" })
        XCTAssertTrue(atem.contains { $0.model.contains("Extreme") })
    }

    func testStreamingPlatformsExist() {
        let registry = BroadcastEquipmentRegistry()
        XCTAssertTrue(registry.streamingPlatforms.contains { $0.name == "YouTube Live" })
        XCTAssertTrue(registry.streamingPlatforms.contains { $0.name == "Twitch" })
        XCTAssertTrue(registry.streamingPlatforms.contains { $0.name == "Facebook Live" })
    }

    // MARK: - VR/AR Device Registry Tests

    func testVRARDevicesNotEmpty() {
        let registry = VRARDeviceRegistry()
        XCTAssertFalse(registry.devices.isEmpty)
    }

    func testVisionProExists() {
        let registry = VRARDeviceRegistry()
        let visionPro = registry.devices.first { $0.model == "Vision Pro" }
        XCTAssertNotNil(visionPro)
        XCTAssertEqual(visionPro?.platform, .visionOS)
        XCTAssertTrue(visionPro?.hasSpatialAudio ?? false)
        XCTAssertTrue(visionPro?.hasEyeTracking ?? false)
        XCTAssertTrue(visionPro?.hasHandTracking ?? false)
    }

    func testMetaQuestExists() {
        let registry = VRARDeviceRegistry()
        let quest = registry.devices.filter { $0.brand == "Meta" && $0.model.contains("Quest") }
        XCTAssertFalse(quest.isEmpty)
    }

    func testMetaGlassesExist() {
        let registry = VRARDeviceRegistry()
        let glasses = registry.devices.first { $0.model == "Ray-Ban Meta" }
        XCTAssertNotNil(glasses)
    }

    // MARK: - Wearable Device Registry Tests

    func testWearableDevicesNotEmpty() {
        let registry = WearableDeviceRegistry()
        XCTAssertFalse(registry.devices.isEmpty)
    }

    func testAppleWatchExists() {
        let registry = WearableDeviceRegistry()
        let watches = registry.devices.filter { $0.brand == "Apple" && $0.model.contains("Watch") }
        XCTAssertFalse(watches.isEmpty)
    }

    func testWearOSDevicesExist() {
        let registry = WearableDeviceRegistry()
        let wearOS = registry.devices.filter { $0.platform == .wearOS }
        XCTAssertFalse(wearOS.isEmpty)
    }

    func testAirPodsExist() {
        let registry = WearableDeviceRegistry()
        let airpods = registry.devices.filter { $0.model.contains("AirPods") }
        XCTAssertFalse(airpods.isEmpty)
    }

    // MARK: - Cross-Platform Session Tests

    func testCreateCrossPlatformSession() async {
        let manager = CrossPlatformSessionManager.shared

        let devices = [
            SessionDevice(name: "iPhone", type: .iPhone, platform: .iOS, role: .bioSource),
            SessionDevice(name: "Windows PC", type: .windowsPC, platform: .windows, role: .host)
        ]

        let session = manager.createSession(name: "Test Session", devices: devices)

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.devices.count, 2)
        XCTAssertTrue(session.isCrossEcosystem, "Should be cross-ecosystem")
        XCTAssertTrue(session.ecosystems.contains(.apple))
        XCTAssertTrue(session.ecosystems.contains(.microsoft))
    }

    func testDeviceEcosystemDetection() {
        XCTAssertEqual(DeviceEcosystem.from(platform: .iOS), .apple)
        XCTAssertEqual(DeviceEcosystem.from(platform: .macOS), .apple)
        XCTAssertEqual(DeviceEcosystem.from(platform: .visionOS), .apple)
        XCTAssertEqual(DeviceEcosystem.from(platform: .android), .google)
        XCTAssertEqual(DeviceEcosystem.from(platform: .wearOS), .google)
        XCTAssertEqual(DeviceEcosystem.from(platform: .windows), .microsoft)
        XCTAssertEqual(DeviceEcosystem.from(platform: .questOS), .meta)
        XCTAssertEqual(DeviceEcosystem.from(platform: .linux), .linux)
        XCTAssertEqual(DeviceEcosystem.from(platform: .teslaOS), .tesla)
    }

    // MARK: - Latency Compensation Tests

    func testLatencyCompensationCalculation() {
        var compensation = LatencyCompensation()
        compensation.algorithm = .adaptive

        // Add measurements
        compensation.addMeasurement(10.0)
        compensation.addMeasurement(12.0)
        compensation.addMeasurement(11.0)
        compensation.addMeasurement(15.0)
        compensation.addMeasurement(9.0)

        // Should calculate median
        let offset = compensation.calculateOffset()
        XCTAssertGreaterThan(offset, 0)
        XCTAssertLessThan(offset, 20)
    }

    func testLatencyCompensationPredictive() {
        var compensation = LatencyCompensation()
        compensation.algorithm = .predictive

        for i in 1...10 {
            compensation.addMeasurement(Double(i) * 2.0)
        }

        let offset = compensation.calculateOffset()
        XCTAssertGreaterThan(offset, 0)
    }

    // MARK: - Device Combination Validation Tests

    func testAllCombinationsAreValid() {
        let combinations = DeviceCombinationPresets.crossEcosystemCombinations

        for combo in combinations {
            let devices = combo.devices.map { (type, platform, role) in
                SessionDevice(name: "\(type)", type: type, platform: platform, role: role)
            }
            let validation = DeviceCombinationPresets.validateCombination(devices)
            XCTAssertTrue(validation.isValid, "Combination '\(combo.name)' should be valid")
        }
    }

    func testCrossEcosystemCombinationsExist() {
        let combinations = DeviceCombinationPresets.crossEcosystemCombinations
        XCTAssertFalse(combinations.isEmpty)
        XCTAssertGreaterThan(combinations.count, 5)

        // Check specific combinations exist
        XCTAssertTrue(combinations.contains { $0.name == "iPhone + Windows PC" })
        XCTAssertTrue(combinations.contains { $0.name == "Android Tablet + iMac" })
    }

    // MARK: - Sync Protocol Tests

    func testProtocolSelectionForCrossEcosystem() {
        let devices = [
            SessionDevice(name: "iPhone", type: .iPhone, platform: .iOS),
            SessionDevice(name: "Android", type: .androidPhone, platform: .android)
        ]

        let protocols = CrossPlatformSyncProtocol.selectProtocols(for: devices)

        // Cross-ecosystem should use universal protocols
        XCTAssertEqual(protocols.transport, .webSocket)
    }

    func testProtocolSelectionForAppleOnly() {
        let devices = [
            SessionDevice(name: "iPhone", type: .iPhone, platform: .iOS),
            SessionDevice(name: "Mac", type: .mac, platform: .macOS)
        ]

        let protocols = CrossPlatformSyncProtocol.selectProtocols(for: devices)

        // Apple-only should use optimized protocols
        XCTAssertEqual(protocols.discovery, .bonjour)
        XCTAssertEqual(protocols.transport, .tcp)
    }

    // MARK: - Biometric Sync Data Tests

    func testBiometricSyncDataEncoding() {
        let data = BiometricSyncData(
            heartRate: 72.0,
            hrv: 45.0,
            coherence: 0.85,
            breathingRate: 12.0,
            sourceDeviceId: "test-device"
        )

        XCTAssertEqual(data.heartRate, 72.0)
        XCTAssertEqual(data.hrv, 45.0)
        XCTAssertEqual(data.coherence, 0.85)

        // Test encoding
        let encoder = JSONEncoder()
        XCTAssertNoThrow(try encoder.encode(data))
    }

    func testAudioSyncParametersEncoding() {
        let params = AudioSyncParameters(
            bpm: 120,
            volume: 0.8,
            isPlaying: true,
            sourceDeviceId: "test-device"
        )

        XCTAssertEqual(params.bpm, 120)
        XCTAssertTrue(params.isPlaying)

        let encoder = JSONEncoder()
        XCTAssertNoThrow(try encoder.encode(params))
    }

    // MARK: - Ecosystem Report Test

    func testGenerateReport() {
        let ecosystem = HardwareEcosystem.shared
        let report = ecosystem.generateReport()

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("HARDWARE ECOSYSTEM"))
        XCTAssertTrue(report.contains("AUDIO INTERFACES"))
        XCTAssertTrue(report.contains("MIDI CONTROLLERS"))
        XCTAssertTrue(report.contains("LIGHTING"))
        XCTAssertTrue(report.contains("VIDEO"))
        XCTAssertTrue(report.contains("BROADCAST"))
    }

    // MARK: - Performance Tests

    func testAudioInterfaceLookupPerformance() {
        let registry = AudioInterfaceRegistry()

        measure {
            for _ in 0..<1000 {
                _ = registry.interfaces.filter { $0.brand == .universalAudio }
            }
        }
    }

    func testMIDIControllerLookupPerformance() {
        let registry = MIDIControllerRegistry()

        measure {
            for _ in 0..<1000 {
                _ = registry.controllers.filter { $0.hasMPE }
            }
        }
    }

    func testDeviceCombinationValidationPerformance() {
        let devices = [
            SessionDevice(name: "Mac", type: .mac, platform: .macOS, role: .host),
            SessionDevice(name: "iPhone", type: .iPhone, platform: .iOS, role: .bioSource),
            SessionDevice(name: "Windows", type: .windowsPC, platform: .windows, role: .audioSource),
            SessionDevice(name: "Quest", type: .metaQuest, platform: .questOS, role: .visualOutput)
        ]

        measure {
            for _ in 0..<1000 {
                _ = DeviceCombinationPresets.validateCombination(devices)
            }
        }
    }
}
