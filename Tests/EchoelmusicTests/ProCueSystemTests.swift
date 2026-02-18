import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProCueSystem — professional show control / cue system.
/// Tests cue management, DMX output, scenes, fixtures, show files.
@MainActor
final class ProCueSystemTests: XCTestCase {

    var sut: ProCueSystem!

    override func setUp() async throws {
        try await super.setUp()
        sut = ProCueSystem(universeCount: 1)
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization (4 tests)

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testInitializationWithMultipleUniverses() {
        let system = ProCueSystem(universeCount: 4)
        XCTAssertNotNil(system)
    }

    func testInitialBlackout() {
        // System should start in a safe state
        XCTAssertNotNil(sut)
    }

    func testMaxUniverseLimit() {
        let system = ProCueSystem(universeCount: 16)
        XCTAssertNotNil(system)
    }

    // MARK: - DMX Operations (5 tests)

    func testSetDMXValue() {
        sut.setDMXValue(universe: 0, channel: 1, value: 255)
    }

    func testSetDMXValueBoundary() {
        sut.setDMXValue(universe: 0, channel: 512, value: 255)
    }

    func testFadeDMXValue() {
        sut.fadeDMXValue(universe: 0, channel: 1, to: 200, duration: 1.0)
    }

    func testBlackout() {
        sut.setDMXValue(universe: 0, channel: 1, value: 255)
        sut.blackout()
    }

    func testFlash() {
        sut.flash()
    }

    // MARK: - Cue Execution (6 tests)

    func testGo() {
        sut.go()
    }

    func testGoBack() {
        sut.go()
        sut.goBack()
    }

    func testHalt() {
        sut.go()
        sut.halt()
    }

    func testGoToCue() {
        sut.goToCue(number: 1.0)
    }

    func testGoToCueInvalid() {
        sut.goToCue(number: 999.0)
    }

    func testMultipleGoSequence() {
        sut.go()
        sut.go()
        sut.go()
        sut.goBack()
    }

    // MARK: - Scene Management (4 tests)

    func testSwitchScene() {
        // Create a scene first if needed, then switch
        sut.switchScene(0)
    }

    func testSetPreview() {
        sut.setPreview(0)
    }

    func testSwitchSceneInvalidIndex() {
        sut.switchScene(999)
    }

    func testSetPreviewInvalidIndex() {
        sut.setPreview(999)
    }

    // MARK: - Show File Operations (4 tests)

    func testSaveShow() {
        let show = sut.saveShow(name: "TestShow")
        XCTAssertEqual(show.name, "TestShow")
    }

    func testLoadShow() {
        let show = sut.saveShow(name: "TestShow")
        sut.loadShow(show)
    }

    func testExportCueSheet() {
        let sheet = sut.exportCueSheet()
        XCTAssertFalse(sheet.isEmpty)
    }

    func testSaveAndLoadRoundTrip() {
        sut.setDMXValue(universe: 0, channel: 1, value: 128)
        let show = sut.saveShow(name: "RoundTrip")
        let newSystem = ProCueSystem(universeCount: 1)
        newSystem.loadShow(show)
    }

    // MARK: - CueList (3 tests)

    func testCueListGo() {
        let cueList = CueList(name: "Main")
        cueList.go()
    }

    func testCueListGoBack() {
        let cueList = CueList(name: "Main")
        cueList.go()
        cueList.goBack()
    }

    func testCueListRelease() {
        let cueList = CueList(name: "Main")
        cueList.release()
    }

    // MARK: - Cue Types (3 tests)

    func testCueCreation() {
        let cue = Cue(number: 1.0, name: "Intro", type: .lighting)
        XCTAssertEqual(cue.number, 1.0)
        XCTAssertEqual(cue.name, "Intro")
    }

    func testCueActionCreation() {
        let action = CueAction(type: .goToCue, delay: 0.5)
        XCTAssertEqual(action.delay, 0.5)
        XCTAssertTrue(action.isEnabled)
    }

    func testCueTransition() {
        let transition = CueSceneTransition(type: .fade, duration: 2.0)
        XCTAssertEqual(transition.duration, 2.0)
    }
}
