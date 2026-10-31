import XCTest
@testable import EchoelCore

/// One camera, one producer: a take wins over the pulse and gives the camera back (wave W7).
final class CameraArbitrationTests: XCTestCase {
    func testATakeSuspendsThePulseAndGivesTheCameraBack() {
        var camera = CameraArbitration()
        let opened = camera.choosePulse()
        XCTAssertEqual(opened, [.openPulse])
        XCTAssertEqual(camera.holder, .pulse)
        let began = camera.beginTake()
        XCTAssertEqual(began, [.suspendPulse, .openTake], "the pulse pauses before the take opens")
        XCTAssertEqual(camera.holder, .take)
        let again = camera.beginTake()
        XCTAssertNil(again, "one take at a time")
        let ended = camera.endTake()
        XCTAssertEqual(ended, [.closeTake, .resumePulse])
        XCTAssertEqual(camera.holder, .pulse)
        let none = camera.endTake()
        XCTAssertEqual(none, [], "no take to end")
    }

    func testAPulseChosenDuringATakeWaitsForIt() {
        var camera = CameraArbitration()
        let began = camera.beginTake()
        XCTAssertEqual(began, [.openTake])
        let waiting = camera.choosePulse()
        XCTAssertEqual(waiting, [], "the take keeps the camera")
        XCTAssertTrue(camera.pulseChosen)
        let ended = camera.endTake()
        XCTAssertEqual(ended, [.closeTake, .resumePulse])
        let dropped = camera.dropPulse()
        XCTAssertEqual(dropped, [.closePulse])
        XCTAssertEqual(camera.holder, .none)
    }

    func testAPulseDroppedDuringATakeIsNotResumed() {
        var camera = CameraArbitration()
        _ = camera.choosePulse()
        _ = camera.beginTake()
        let dropped = camera.dropPulse()
        XCTAssertEqual(dropped, [], "the take holds the camera; nothing to close")
        let ended = camera.endTake()
        XCTAssertEqual(ended, [.closeTake])
        XCTAssertEqual(camera.holder, .none)
    }

    func testALateCallbackFromAnEarlierHolderIsStale() {
        var camera = CameraArbitration()
        _ = camera.beginTake()
        let take = camera.generation
        XCTAssertTrue(camera.isCurrent(take))
        _ = camera.endTake()
        XCTAssertFalse(camera.isCurrent(take), "the take's callbacks are dropped once it has ended")
        _ = camera.beginTake()
        XCTAssertFalse(camera.isCurrent(take), "and a new take has its own generation")
    }
}
