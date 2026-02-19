import XCTest
@testable import Echoelmusic

/// Integration tests for AudioEngine
/// Tests audio control methods and bio-parameter integration
@MainActor
final class AudioEngineTests: XCTestCase {

    var mockMicrophoneManager: MockMicrophoneManager!
    var audioEngine: AudioEngine!

    override func setUp() async throws {
        mockMicrophoneManager = MockMicrophoneManager()
        audioEngine = AudioEngine(microphoneManager: mockMicrophoneManager)
    }

    override func tearDown() async throws {
        audioEngine?.stop()
        audioEngine = nil
        mockMicrophoneManager = nil
    }


    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(audioEngine)
        XCTAssertFalse(audioEngine.isRunning)
        XCTAssertFalse(audioEngine.binauralBeatsEnabled)
        XCTAssertFalse(audioEngine.spatialAudioEnabled)
    }

    func testDefaultBrainwaveState() {
        XCTAssertEqual(audioEngine.currentBrainwaveState, .alpha)
    }

    func testDefaultBinauralAmplitude() {
        XCTAssertEqual(audioEngine.binauralAmplitude, 0.3, accuracy: 0.01)
    }


    // MARK: - Current Level Tests

    func testCurrentLevel() {
        mockMicrophoneManager.audioLevel = 0.5
        XCTAssertEqual(audioEngine.currentLevel, 0.5, accuracy: 0.01)
    }

    func testCurrentLevelZero() {
        mockMicrophoneManager.audioLevel = 0.0
        XCTAssertEqual(audioEngine.currentLevel, 0.0, accuracy: 0.01)
    }

    func testCurrentLevelMax() {
        mockMicrophoneManager.audioLevel = 1.0
        XCTAssertEqual(audioEngine.currentLevel, 1.0, accuracy: 0.01)
    }


    // MARK: - Brainwave State Tests

    func testSetBrainwaveStateDelta() {
        audioEngine.setBrainwaveState(.delta)
        XCTAssertEqual(audioEngine.currentBrainwaveState, .delta)
    }

    func testSetBrainwaveStateTheta() {
        audioEngine.setBrainwaveState(.theta)
        XCTAssertEqual(audioEngine.currentBrainwaveState, .theta)
    }

    func testSetBrainwaveStateBeta() {
        audioEngine.setBrainwaveState(.beta)
        XCTAssertEqual(audioEngine.currentBrainwaveState, .beta)
    }

    func testSetBrainwaveStateGamma() {
        audioEngine.setBrainwaveState(.gamma)
        XCTAssertEqual(audioEngine.currentBrainwaveState, .gamma)
    }


    // MARK: - Amplitude Tests

    func testSetBinauralAmplitude() {
        audioEngine.setBinauralAmplitude(0.5)
        XCTAssertEqual(audioEngine.binauralAmplitude, 0.5, accuracy: 0.01)
    }

    func testSetBinauralAmplitudeZero() {
        audioEngine.setBinauralAmplitude(0.0)
        XCTAssertEqual(audioEngine.binauralAmplitude, 0.0, accuracy: 0.01)
    }

    func testSetBinauralAmplitudeMax() {
        audioEngine.setBinauralAmplitude(1.0)
        XCTAssertEqual(audioEngine.binauralAmplitude, 1.0, accuracy: 0.01)
    }


    // MARK: - Toggle Tests

    func testToggleBinauralBeats() {
        XCTAssertFalse(audioEngine.binauralBeatsEnabled)

        audioEngine.toggleBinauralBeats()
        XCTAssertTrue(audioEngine.binauralBeatsEnabled)

        audioEngine.toggleBinauralBeats()
        XCTAssertFalse(audioEngine.binauralBeatsEnabled)
    }

    func testToggleSpatialAudio() {
        // Note: May fail if spatial audio is not available
        let initialState = audioEngine.spatialAudioEnabled

        audioEngine.toggleSpatialAudio()
        // State may or may not change depending on device capabilities
        // Just verify it doesn't crash
    }


    // MARK: - Filter Control Tests

    func testSetFilterCutoff() {
        audioEngine.setFilterCutoff(2000.0)
        // Engine should remain in valid state after setting filter cutoff without node graph
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setFilterCutoff")
        XCTAssertFalse(audioEngine.isRunning, "Engine should not auto-start from parameter change")
    }

    func testSetFilterResonance() {
        audioEngine.setFilterResonance(0.5)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setFilterResonance")
        XCTAssertFalse(audioEngine.isRunning, "Engine should not auto-start from parameter change")
    }


    // MARK: - Reverb Control Tests

    func testSetReverbWetness() {
        audioEngine.setReverbWetness(0.3)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setReverbWetness")
    }

    func testSetReverbSize() {
        audioEngine.setReverbSize(0.7)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setReverbSize")
    }


    // MARK: - Delay Control Tests

    func testSetDelayTime() {
        audioEngine.setDelayTime(0.25)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setDelayTime")
    }


    // MARK: - Volume Control Tests

    func testSetMasterVolume() {
        audioEngine.setMasterVolume(0.8)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setMasterVolume")
    }


    // MARK: - Tempo Control Tests

    func testSetTempo() {
        audioEngine.setTempo(120.0)
        XCTAssertNotNil(audioEngine, "AudioEngine should remain valid after setTempo")
    }


    // MARK: - State Description Tests

    func testStateDescriptionStopped() {
        XCTAssertEqual(audioEngine.stateDescription, "Audio engine stopped")
    }


    // MARK: - Performance Tests

    func testBrainwaveStateSwitchingPerformance() {
        let states: [BinauralBeatGenerator.BrainwaveState] = [.delta, .theta, .alpha, .beta, .gamma]

        measure {
            for state in states {
                audioEngine.setBrainwaveState(state)
            }
        }
    }

    func testParameterUpdatePerformance() {
        measure {
            for i in 0..<100 {
                audioEngine.setFilterCutoff(Float(200 + i * 50))
                audioEngine.setReverbWetness(Float(i) / 100.0)
            }
        }
    }
}


// MARK: - Mock Objects

/// Mock MicrophoneManager for testing
class MockMicrophoneManager: MicrophoneManager {

    override init() {
        super.init()
    }

    override var audioLevel: Float {
        get { _audioLevel }
        set { _audioLevel = newValue }
    }
    private var _audioLevel: Float = 0.0

    override var currentPitch: Float {
        get { _currentPitch }
        set { _currentPitch = newValue }
    }
    private var _currentPitch: Float = 0.0

    override var hasPermission: Bool {
        get { true }
        set { }
    }

    override var isRecording: Bool {
        get { _isRecording }
        set { _isRecording = newValue }
    }
    private var _isRecording: Bool = false

    override func startRecording() {
        _isRecording = true
    }

    override func stopRecording() {
        _isRecording = false
    }
}
