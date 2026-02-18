import XCTest
@testable import Echoelmusic

/// Tests for optimization-related types: certificate pinning, dependency injection,
/// plugin separation, ProStreamEngine types, and hardware ecosystem registries
final class OptimizationTests: XCTestCase {

    // MARK: - Certificate Pinning Tests

    func testCertificatePinningDelegateExists() {
        let delegate = CertificatePinningDelegate()
        XCTAssertNotNil(delegate, "CertificatePinningDelegate should be instantiable")
    }

    func testCertificatePinningDelegateIsURLSessionDelegate() {
        let delegate = CertificatePinningDelegate()
        XCTAssertTrue(delegate is URLSessionDelegate, "CertificatePinningDelegate should conform to URLSessionDelegate")
    }

    // MARK: - ServiceContainer Dependency Injection Tests

    @MainActor
    func testServiceContainerRegisterAndResolve() {
        let container = ServiceContainer()

        container.register(StorageServiceProtocol.self) {
            MockStorageService()
        }

        let resolved = container.resolve(StorageServiceProtocol.self)
        XCTAssertNotNil(resolved, "Registered service should be resolvable")
    }

    @MainActor
    func testServiceContainerResolveUnregisteredReturnsNil() {
        let container = ServiceContainer()

        let resolved = container.resolve(AnalyticsServiceProtocol.self)
        XCTAssertNil(resolved, "Unregistered service should return nil")
    }

    @MainActor
    func testServiceContainerRegisterSingleton() {
        let container = ServiceContainer()
        let mockService = MockStorageService()

        container.registerSingleton(StorageServiceProtocol.self, instance: mockService)

        let resolved1 = container.resolve(StorageServiceProtocol.self)
        let resolved2 = container.resolve(StorageServiceProtocol.self)

        XCTAssertNotNil(resolved1)
        XCTAssertTrue(resolved1 === resolved2, "Singleton should return the same instance")
    }

    @MainActor
    func testServiceContainerReset() {
        let container = ServiceContainer()

        container.register(StorageServiceProtocol.self) {
            MockStorageService()
        }

        let before = container.resolve(StorageServiceProtocol.self)
        XCTAssertNotNil(before, "Service should be resolvable before reset")

        container.reset()

        let after = container.resolve(StorageServiceProtocol.self)
        XCTAssertNil(after, "Service should be nil after reset")
    }

    @MainActor
    func testServiceContainerResolveWithDefault() {
        let container = ServiceContainer()
        let fallback = MockStorageService()

        let resolved = container.resolve(StorageServiceProtocol.self, default: fallback)
        XCTAssertTrue(resolved === fallback, "Should return default when service is not registered")
    }

    @MainActor
    func testServiceContainerTestingFactory() {
        let testContainer = ServiceContainer.testing()
        XCTAssertNotNil(testContainer, "Testing container should be creatable")

        let resolved = testContainer.resolve(AnalyticsServiceProtocol.self)
        XCTAssertNil(resolved, "Fresh testing container should have no registrations")
    }

    // MARK: - Plugin Separation Tests

    func testTherapySessionPluginInstantiation() {
        let plugin = TherapySessionPlugin()
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.identifier, "com.echoelmusic.therapy-session")
        XCTAssertEqual(plugin.name, "Therapy Session Manager")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testLivePerformancePluginInstantiation() {
        let plugin = LivePerformancePlugin()
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.identifier, "com.echoelmusic.live-performance")
        XCTAssertEqual(plugin.name, "Live Performance Manager")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testResearchDataPluginInstantiation() {
        let plugin = ResearchDataPlugin()
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.identifier, "com.echoelmusic.research-data")
        XCTAssertEqual(plugin.name, "Research Data Analyzer")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testAccessibilityEnhancerPluginInstantiation() {
        let plugin = AccessibilityEnhancerPlugin()
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.identifier, "com.echoelmusic.accessibility-enhancer")
        XCTAssertEqual(plugin.name, "Accessibility Enhancer")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testContentCreatorPluginInstantiation() {
        let plugin = ContentCreatorPlugin()
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.identifier, "com.echoelmusic.content-creator")
        XCTAssertEqual(plugin.name, "Content Creator Suite")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testAllPluginsHaveUniqueIdentifiers() {
        let plugins: [EchoelmusicPlugin] = [
            TherapySessionPlugin(),
            LivePerformancePlugin(),
            ResearchDataPlugin(),
            AccessibilityEnhancerPlugin(),
            ContentCreatorPlugin()
        ]

        let identifiers = Set(plugins.map { $0.identifier })
        XCTAssertEqual(identifiers.count, 5, "All 5 plugins must have unique identifiers")
    }

    func testAllPluginsConformToProtocol() {
        let therapy: EchoelmusicPlugin = TherapySessionPlugin()
        let live: EchoelmusicPlugin = LivePerformancePlugin()
        let research: EchoelmusicPlugin = ResearchDataPlugin()
        let accessibility: EchoelmusicPlugin = AccessibilityEnhancerPlugin()
        let content: EchoelmusicPlugin = ContentCreatorPlugin()

        XCTAssertFalse(therapy.capabilities.isEmpty)
        XCTAssertFalse(live.capabilities.isEmpty)
        XCTAssertFalse(research.capabilities.isEmpty)
        XCTAssertFalse(accessibility.capabilities.isEmpty)
        XCTAssertFalse(content.capabilities.isEmpty)
    }

    // MARK: - ProStreamEngine Types Tests

    func testProStreamSceneCreation() {
        let scene = ProStreamScene(name: "Test Scene")
        XCTAssertEqual(scene.name, "Test Scene")
        XCTAssertNotNil(scene.id)
        XCTAssertTrue(scene.sources.isEmpty)
        XCTAssertFalse(scene.isActive)
    }

    func testStreamSourceCreation() {
        let source = StreamSource(
            name: "Camera 1",
            type: .camera(index: 0)
        )
        XCTAssertEqual(source.name, "Camera 1")
        XCTAssertNotNil(source.id)
        XCTAssertTrue(source.isVisible)
    }

    func testStreamOutputCreation() {
        let output = StreamOutput(
            name: "Primary Stream",
            type: .rtmpStream
        )
        XCTAssertEqual(output.name, "Primary Stream")
        XCTAssertNotNil(output.id)
    }

    func testOutputConfigDefaults() {
        let config = OutputConfig()
        XCTAssertEqual(config.url, "")
        XCTAssertEqual(config.streamKey, "")
        XCTAssertEqual(config.audioSampleRate, 48000)
        XCTAssertEqual(config.audioChannels, 2)
    }

    func testStreamPresetYouTube() {
        let preset = StreamPreset.youtube()
        XCTAssertEqual(preset.platform, .youtube)
        XCTAssertEqual(preset.audioBitrate, 320)
        XCTAssertEqual(preset.keyframeInterval, 2)
    }

    func testStreamPresetTwitch() {
        let preset = StreamPreset.twitch()
        XCTAssertEqual(preset.platform, .twitch)
        XCTAssertEqual(preset.audioBitrate, 320)
    }

    func testStreamPresetCustom() {
        let preset = StreamPreset.custom(
            resolution: ._720p30,
            videoBitrate: 3_000_000,
            audioBitrate: 128
        )
        XCTAssertEqual(preset.platform, .custom)
        XCTAssertEqual(preset.videoBitrate, 3_000_000)
        XCTAssertEqual(preset.audioBitrate, 128)
    }

    func testOutputConfigFromPreset() {
        let preset = StreamPreset.youtube()
        let config = OutputConfig.from(preset: preset, streamKey: "test-key")

        XCTAssertEqual(config.streamKey, "test-key")
        XCTAssertEqual(config.videoBitrate, preset.videoBitrate)
        XCTAssertEqual(config.audioBitrate, preset.audioBitrate)
    }

    func testProStreamSceneWithSources() {
        let source1 = StreamSource(name: "Camera", type: .camera(index: 0))
        let source2 = StreamSource(name: "Screen", type: .screenCapture)

        let scene = ProStreamScene(
            name: "Multi-Source Scene",
            sources: [source1, source2]
        )

        XCTAssertEqual(scene.sources.count, 2)
        XCTAssertEqual(scene.sources[0].name, "Camera")
        XCTAssertEqual(scene.sources[1].name, "Screen")
    }

    // MARK: - HardwareEcosystem Tests

    func testHardwareEcosystemExists() {
        let ecosystem = HardwareEcosystem.shared
        XCTAssertNotNil(ecosystem, "HardwareEcosystem singleton should exist")
    }

    func testAudioInterfaceRegistryInstantiation() {
        let registry = AudioInterfaceRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.interfaces.isEmpty, "Audio interface registry should not be empty")
    }

    func testMIDIControllerRegistryInstantiation() {
        let registry = MIDIControllerRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.controllers.isEmpty, "MIDI controller registry should not be empty")
    }

    func testLightingHardwareRegistryInstantiation() {
        let registry = LightingHardwareRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.controllers.isEmpty, "Lighting hardware registry should not be empty")
    }

    func testVideoHardwareRegistryInstantiation() {
        let registry = VideoHardwareRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.cameras.isEmpty, "Video hardware registry cameras should not be empty")
    }

    func testBroadcastEquipmentRegistryInstantiation() {
        let registry = BroadcastEquipmentRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.switchers.isEmpty, "Broadcast equipment registry should not be empty")
    }

    func testVRARDeviceRegistryInstantiation() {
        let registry = VRARDeviceRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.devices.isEmpty, "VR/AR device registry should not be empty")
    }

    func testWearableDeviceRegistryInstantiation() {
        let registry = WearableDeviceRegistry()
        XCTAssertNotNil(registry)
        XCTAssertFalse(registry.devices.isEmpty, "Wearable device registry should not be empty")
    }
}

// MARK: - Mock Services for Testing

private final class MockStorageService: StorageServiceProtocol {
    func save(key: String, data: Data) throws {}
    func load(key: String) throws -> Data? { return nil }
    func delete(key: String) throws {}
}
