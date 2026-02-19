import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProStreamEngine — OBS-style streaming engine.
/// Tests scenes, sources, transitions, studio mode, hotkeys, recording.
@MainActor
final class ProStreamEngineTests: XCTestCase {

    var sut: ProStreamEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = ProStreamEngine.defaultSetup()
    }

    override func tearDown() async throws {
        sut.stopAllStreams()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization (5 tests)

    func testDefaultSetupInitialization() {
        XCTAssertNotNil(sut)
    }

    func testDefaultSetupHasScenes() {
        XCTAssertFalse(sut.scenes.isEmpty)
    }

    func testMusicStreamSetup() {
        let music = ProStreamEngine.musicStreamSetup()
        XCTAssertNotNil(music)
        XCTAssertFalse(music.scenes.isEmpty)
    }

    func testVJStreamSetup() {
        let vj = ProStreamEngine.vjStreamSetup()
        XCTAssertNotNil(vj)
    }

    func testPodcastSetup() {
        let podcast = ProStreamEngine.podcastSetup()
        XCTAssertNotNil(podcast)
    }

    // MARK: - Scene Management (6 tests)

    func testAddScene() {
        let countBefore = sut.scenes.count
        let scene = sut.addScene(name: "Outro", color: .blue)
        XCTAssertEqual(scene.name, "Outro")
        XCTAssertEqual(sut.scenes.count, countBefore + 1)
    }

    func testRemoveScene() {
        let scene = sut.addScene(name: "Temp", color: .red)
        let countBefore = sut.scenes.count
        sut.removeScene(id: scene.id)
        XCTAssertEqual(sut.scenes.count, countBefore - 1)
    }

    func testRemoveNonexistentSceneDoesNotCrash() {
        let countBefore = sut.scenes.count
        sut.removeScene(id: UUID())
        XCTAssertEqual(sut.scenes.count, countBefore)
    }

    func testSwitchScene() {
        guard let sceneID = sut.scenes.first?.id else {
            XCTFail("No scenes available")
            return
        }
        sut.switchScene(sceneID)
    }

    func testSwitchSceneByName() {
        guard let name = sut.scenes.first?.name else {
            XCTFail("No scenes available")
            return
        }
        sut.switchSceneByName(name)
    }

    func testSetPreviewScene() {
        guard let sceneID = sut.scenes.first?.id else { return }
        sut.setPreviewScene(sceneID)
    }

    // MARK: - Source Management (5 tests)

    func testAddSource() {
        guard let sceneID = sut.scenes.first?.id else { return }
        let source = sut.addSource(to: sceneID, type: .camera(index: 0), name: "Webcam")
        XCTAssertNotNil(source)
    }

    func testAddSourceToInvalidScene() {
        let source = sut.addSource(to: UUID(), type: .camera(index: 0), name: "Cam")
        XCTAssertNil(source)
    }

    func testRemoveSource() {
        guard let sceneID = sut.scenes.first?.id else { return }
        if let source = sut.addSource(to: sceneID, type: .camera(index: 0), name: "Cam") {
            sut.removeSource(from: sceneID, sourceID: source.id)
        }
    }

    func testToggleSourceVisibility() {
        guard let sceneID = sut.scenes.first?.id else { return }
        if let source = sut.addSource(to: sceneID, type: .camera(index: 0), name: "Cam") {
            sut.toggleSourceVisibility(sceneID: sceneID, sourceID: source.id)
        }
    }

    func testReorderSource() {
        guard let sceneID = sut.scenes.first?.id else { return }
        sut.reorderSource(sceneID: sceneID, from: 0, to: 0)
    }

    // MARK: - Studio Mode (4 tests)

    func testToggleStudioMode() {
        sut.toggleStudioMode()
        XCTAssertTrue(sut.studioMode)
    }

    func testToggleStudioModeOff() {
        sut.toggleStudioMode()
        sut.toggleStudioMode()
        XCTAssertFalse(sut.studioMode)
    }

    func testTransitionToProgram() {
        sut.toggleStudioMode()
        sut.transitionToProgram()
    }

    func testQuickTransition() {
        sut.quickTransition(type: .cut)
    }

    // MARK: - Recording & Replay (4 tests)

    func testStartRecording() {
        sut.startRecording()
        XCTAssertTrue(sut.isRecording)
    }

    func testStopRecording() {
        sut.startRecording()
        sut.stopRecording()
        XCTAssertFalse(sut.isRecording)
    }

    func testToggleReplayBuffer() {
        sut.toggleReplayBuffer()
    }

    func testSaveReplay() {
        let url = sut.saveReplay()
        // May be nil if no replay buffer
        _ = url
    }

    // MARK: - Hotkeys (4 tests)

    func testAddHotkey() {
        let hotkey = sut.addHotkey(
            name: "Switch Camera",
            trigger: .keyboard(key: "1", modifiers: []),
            action: .switchScene(sceneID: UUID())
        )
        XCTAssertEqual(hotkey.name, "Switch Camera")
    }

    func testRemoveHotkey() {
        let hotkey = sut.addHotkey(
            name: "Test",
            trigger: .keyboard(key: "2", modifiers: []),
            action: .toggleRecording
        )
        sut.removeHotkey(id: hotkey.id)
    }

    func testRemoveNonexistentHotkeyDoesNotCrash() {
        sut.removeHotkey(id: UUID())
    }

    func testProcessHotkey() {
        let hotkey = sut.addHotkey(
            name: "Trigger",
            trigger: .keyboard(key: "3", modifiers: []),
            action: .toggleRecording
        )
        sut.processHotkey(hotkey.trigger)
    }

    // MARK: - Stats & Virtual Camera (3 tests)

    func testGetStats() {
        let stats = sut.getStats()
        XCTAssertNotNil(stats)
    }

    func testStartVirtualCamera() {
        sut.startVirtualCamera()
    }

    func testStopVirtualCamera() {
        sut.startVirtualCamera()
        sut.stopVirtualCamera()
    }
}
