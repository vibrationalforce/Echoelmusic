import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProSessionEngine — Ableton-style session view.
/// Tests transport, clips, scenes, patterns, crossfader, tap tempo.
@MainActor
final class ProSessionEngineTests: XCTestCase {

    var sut: ProSessionEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = ProSessionEngine.defaultSession()
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization (5 tests)

    func testDefaultSessionInitialization() {
        XCTAssertNotNil(sut)
    }

    func testDefaultSessionHasTracks() {
        XCTAssertFalse(sut.tracks.isEmpty)
    }

    func testDefaultSessionHasScenes() {
        XCTAssertFalse(sut.scenes.isEmpty)
    }

    func testDefaultSessionBPM() {
        XCTAssertGreaterThan(sut.bpm, 0)
        XCTAssertLessThanOrEqual(sut.bpm, 300)
    }

    func testIsPlayingInitiallyFalse() {
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - Transport (6 tests)

    func testPlay() {
        sut.play()
        XCTAssertTrue(sut.isPlaying)
    }

    func testStop() {
        sut.play()
        sut.stop()
        XCTAssertFalse(sut.isPlaying)
    }

    func testPause() {
        sut.play()
        sut.pause()
        XCTAssertFalse(sut.isPlaying)
    }

    func testDoublePlayDoesNotCrash() {
        sut.play()
        sut.play()
        XCTAssertTrue(sut.isPlaying)
    }

    func testStopWithoutPlayDoesNotCrash() {
        sut.stop()
        XCTAssertFalse(sut.isPlaying)
    }

    func testPauseWithoutPlayDoesNotCrash() {
        sut.pause()
    }

    // MARK: - Track Management (5 tests)

    func testAddTrack() {
        let countBefore = sut.tracks.count
        let track = sut.addTrack(type: .audio, name: "Vocals")
        XCTAssertEqual(track.name, "Vocals")
        XCTAssertEqual(sut.tracks.count, countBefore + 1)
    }

    func testAddMIDITrack() {
        let track = sut.addTrack(type: .midi, name: "Synth")
        XCTAssertEqual(track.type, .midi)
    }

    func testAddScene() {
        let countBefore = sut.scenes.count
        let scene = sut.addScene(name: "Verse")
        XCTAssertEqual(scene.name, "Verse")
        XCTAssertEqual(sut.scenes.count, countBefore + 1)
    }

    func testAddReturnTrack() {
        let ret = sut.addReturnTrack(name: "Reverb")
        XCTAssertEqual(ret.name, "Reverb")
    }

    func testStopAllClips() {
        sut.play()
        XCTAssertTrue(sut.isPlaying, "Session should be playing after play()")
        sut.stopAllClips()
        // Session transport should still be playing even after stopping all clips
        XCTAssertTrue(sut.isPlaying, "Transport should remain playing after stopAllClips")
    }

    // MARK: - Clip Operations (6 tests)

    func testLaunchClip() {
        sut.play()
        sut.launchClip(trackIndex: 0, sceneIndex: 0)
        // Verify session is still playing after clip launch
        XCTAssertTrue(sut.isPlaying, "Session should remain playing after launching clip")
    }

    func testLaunchClipOutOfBoundsDoesNotCrash() {
        sut.launchClip(trackIndex: 999, sceneIndex: 999)
        // Engine should survive out-of-bounds access
        XCTAssertNotNil(sut, "ProSessionEngine should survive out-of-bounds clip launch")
    }

    func testStopClip() {
        sut.play()
        sut.launchClip(trackIndex: 0, sceneIndex: 0)
        sut.stopClip(trackIndex: 0, sceneIndex: 0)
        XCTAssertTrue(sut.isPlaying, "Transport should remain playing after stopping individual clip")
    }

    func testLaunchScene() {
        sut.play()
        sut.launchScene(sceneIndex: 0)
        XCTAssertTrue(sut.isPlaying, "Transport should remain playing after scene launch")
    }

    func testLaunchSceneOutOfBoundsDoesNotCrash() {
        sut.launchScene(sceneIndex: 999)
        XCTAssertNotNil(sut, "ProSessionEngine should survive out-of-bounds scene launch")
    }

    func testStopTrack() {
        sut.play()
        sut.stopTrack(trackIndex: 0)
    }

    // MARK: - Pattern Sequencer (5 tests)

    func testCreatePattern() {
        let clip = sut.createPattern(name: "Beat", steps: 16)
        XCTAssertEqual(clip.name, "Beat")
    }

    func testToggleStep() {
        let clip = sut.createPattern(name: "Pattern", steps: 16)
        sut.toggleStep(clipID: clip.id, step: 0)
    }

    func testSetStepVelocity() {
        let clip = sut.createPattern(name: "Pattern", steps: 16)
        sut.setStepVelocity(clipID: clip.id, step: 0, velocity: 0.9)
    }

    func testRandomizePattern() {
        let clip = sut.createPattern(name: "Random", steps: 16)
        sut.randomizePattern(clipID: clip.id, density: 0.5)
    }

    func testRandomizePatternInvalidID() {
        sut.randomizePattern(clipID: UUID(), density: 0.5)
    }

    // MARK: - Crossfader & Tempo (5 tests)

    func testSetCrossfader() {
        sut.setCrossfader(position: -1.0)
        sut.setCrossfader(position: 0.0)
        sut.setCrossfader(position: 1.0)
    }

    func testNudgeTempo() {
        let originalBPM = sut.bpm
        sut.nudgeTempo(amount: 1.0)
        XCTAssertEqual(sut.bpm, originalBPM + 1.0, accuracy: 0.01)
    }

    func testNudgeTempoNegative() {
        let originalBPM = sut.bpm
        sut.nudgeTempo(amount: -5.0)
        XCTAssertEqual(sut.bpm, originalBPM - 5.0, accuracy: 0.01)
    }

    func testTapTempo() {
        sut.tapTempo()
        sut.tapTempo()
        // Two taps should calculate interval
    }

    func testCaptureScene() {
        let scene = sut.captureScene()
        XCTAssertNotNil(scene)
    }

    // MARK: - Factory Methods (3 tests)

    func testDJSession() {
        let dj = ProSessionEngine.djSession()
        XCTAssertNotNil(dj)
        XCTAssertFalse(dj.tracks.isEmpty)
    }

    func testLivePerformanceSession() {
        let live = ProSessionEngine.livePerformance()
        XCTAssertNotNil(live)
        XCTAssertFalse(live.tracks.isEmpty)
    }

    func testDuplicateClip() {
        sut.duplicateClip(
            from: (trackIndex: 0, sceneIndex: 0),
            to: (trackIndex: 0, sceneIndex: 1)
        )
    }
}
