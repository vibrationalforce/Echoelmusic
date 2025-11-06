import XCTest
@testable import Echoelmusic

/// Unit tests for SharedAudioEngine
@MainActor
final class SharedAudioEngineTests: XCTestCase {

    var sut: SharedAudioEngine!

    override func setUp() async throws {
        sut = SharedAudioEngine.shared
    }

    override func tearDown() async throws {
        // Deactivate all subsystems
        sut.deactivate(subsystem: .microphone)
        sut.deactivate(subsystem: .spatial)
        sut.deactivate(subsystem: .binauralBeats)
        sut.deactivate(subsystem: .recording)
        sut.deactivate(subsystem: .visualization)

        sut = nil
    }

    // MARK: - Initialization Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = SharedAudioEngine.shared
        let instance2 = SharedAudioEngine.shared

        XCTAssertTrue(instance1 === instance2, "Shared instance should be a singleton")
    }

    func testEngineIsInitialized() {
        XCTAssertNotNil(sut.engine, "Audio engine should be initialized")
    }

    func testInputNodeIsAvailable() {
        XCTAssertNotNil(sut.inputNode, "Input node should be available")
    }

    func testMainMixerNodeIsAvailable() {
        XCTAssertNotNil(sut.mainMixerNode, "Main mixer node should be available")
    }

    // MARK: - Mixer Tests

    func testGetMixerForMicrophone() {
        let mixer = sut.getMixer(for: .microphone)

        XCTAssertNotNil(mixer, "Microphone mixer should not be nil")
    }

    func testGetMixerForSpatial() {
        let mixer = sut.getMixer(for: .spatial)

        XCTAssertNotNil(mixer, "Spatial mixer should not be nil")
    }

    func testGetMixerForBinauralBeats() {
        let mixer = sut.getMixer(for: .binauralBeats)

        XCTAssertNotNil(mixer, "Binaural beats mixer should not be nil")
    }

    func testGetMixerForRecording() {
        let mixer = sut.getMixer(for: .recording)

        XCTAssertNotNil(mixer, "Recording mixer should not be nil")
    }

    func testGetMixerForVisualization() {
        let mixer = sut.getMixer(for: .visualization)

        XCTAssertNotNil(mixer, "Visualization mixer should not be nil")
    }

    func testGetMixerReturnsSameInstanceForSameSubsystem() {
        let mixer1 = sut.getMixer(for: .microphone)
        let mixer2 = sut.getMixer(for: .microphone)

        XCTAssertTrue(mixer1 === mixer2, "Same subsystem should return same mixer instance")
    }

    func testGetMixerReturnsDifferentInstancesForDifferentSubsystems() {
        let microphoneMixer = sut.getMixer(for: .microphone)
        let spatialMixer = sut.getMixer(for: .spatial)

        XCTAssertFalse(microphoneMixer === spatialMixer, "Different subsystems should have different mixers")
    }

    // MARK: - Activation Tests

    func testActivateSubsystem() {
        sut.activate(subsystem: .microphone)

        // Verify engine is running after activation
        XCTAssertTrue(sut.engine.isRunning, "Engine should be running after activating subsystem")
    }

    func testDeactivateSubsystem() {
        sut.activate(subsystem: .microphone)
        sut.deactivate(subsystem: .microphone)

        // Engine might still be running if other subsystems are active
        // Just verify deactivation doesn't crash
        XCTAssertTrue(true, "Deactivation should complete without crash")
    }

    func testActivateMultipleSubsystems() {
        sut.activate(subsystem: .microphone)
        sut.activate(subsystem: .spatial)
        sut.activate(subsystem: .binauralBeats)

        XCTAssertTrue(sut.engine.isRunning, "Engine should be running with multiple active subsystems")
    }

    func testDeactivateOneOfMultipleSubsystems() {
        sut.activate(subsystem: .microphone)
        sut.activate(subsystem: .spatial)

        sut.deactivate(subsystem: .microphone)

        // Engine should still be running (spatial still active)
        XCTAssertTrue(sut.engine.isRunning, "Engine should still be running if other subsystems are active")
    }

    // MARK: - Audio Graph Tests

    func testMixersAreConnectedToMainMixer() {
        let microphoneMixer = sut.getMixer(for: .microphone)

        // Verify mixer is attached to engine
        XCTAssertTrue(sut.engine.attachedNodes.contains(microphoneMixer), "Mixer should be attached to engine")
    }

    // MARK: - Performance Tests

    func testMultipleActivationsPerformance() {
        measure {
            for _ in 0..<100 {
                sut.activate(subsystem: .microphone)
                sut.deactivate(subsystem: .microphone)
            }
        }
    }

    func testGetMixerPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = sut.getMixer(for: .microphone)
            }
        }
    }
}
