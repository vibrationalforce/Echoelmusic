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

    /// Sky S2: the sky layer is the lowest claimant — it gets an idle camera, gives way to the
    /// pulse and to a take, and gets the camera back when they let go.
    func testTheSkyLayerGetsAnIdleCameraAndGivesWayToThePulse() {
        var camera = CameraArbitration()
        let step1 = camera.wantSky()
        XCTAssertEqual(step1, [.openSky])
        XCTAssertEqual(camera.holder, .sky)
        let step2 = camera.wantSky()
        XCTAssertEqual(step2, [], "already wanted")
        let step3 = camera.choosePulse()
        XCTAssertEqual(step3, [.closeSky, .openPulse], "the sky closes before the pulse opens")
        XCTAssertEqual(camera.holder, .pulse)
        let step4 = camera.dropPulse()
        XCTAssertEqual(step4, [.closePulse, .openSky], "the sky takes the camera back")
        let step5 = camera.dropSky()
        XCTAssertEqual(step5, [.closeSky])
        XCTAssertEqual(camera.holder, .none)
    }

    func testATakeClosesTheSkyAndReturnsTheCameraToThePulseBeforeTheSky() {
        var camera = CameraArbitration()
        _ = camera.wantSky()
        let step6 = camera.beginTake()
        XCTAssertEqual(step6, [.closeSky, .openTake])
        let step7 = camera.choosePulse()
        XCTAssertEqual(step7, [], "the take keeps the camera")
        let step8 = camera.endTake()
        XCTAssertEqual(step8, [.closeTake, .resumePulse], "the pulse comes before the sky")
        let step9 = camera.dropPulse()
        XCTAssertEqual(step9, [.closePulse, .openSky])
        _ = camera.beginTake()
        let step10 = camera.endTake()
        XCTAssertEqual(step10, [.closeTake, .openSky])
        XCTAssertEqual(camera.holder, .sky)
    }

    func testASkyWaitingBehindThePulseLeavesQuietly() {
        var camera = CameraArbitration()
        _ = camera.choosePulse()
        let step11 = camera.wantSky()
        XCTAssertEqual(step11, [], "the pulse keeps the camera")
        let step12 = camera.dropSky()
        XCTAssertEqual(step12, [], "nothing to close")
        let step13 = camera.dropPulse()
        XCTAssertEqual(step13, [.closePulse])
        XCTAssertEqual(camera.holder, .none)
        let before = camera.generation
        _ = camera.wantSky()
        XCTAssertNotEqual(camera.generation, before, "a new holder is a new generation")
    }
}
