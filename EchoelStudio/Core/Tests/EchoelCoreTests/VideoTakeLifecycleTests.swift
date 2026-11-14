import XCTest
@testable import EchoelCore

/// A call or Siri mid-take: the take lands with what was filmed, said plainly (wave W7).
final class VideoTakeLifecycleTests: XCTestCase {
    private func readyCamera() -> VideoTakeLifecycle {
        var life = VideoTakeLifecycle()
        let opened = life.open()
        XCTAssertNotNil(opened)
        life.handle(.opened, stamped: life.generation)
        XCTAssertEqual(life.phase, .ready)
        return life
    }

    func testATakeStoppedByTheMusicianLandsWhole() {
        var life = readyCamera()
        XCTAssertTrue(life.record())
        XCTAssertEqual(life.phase, .recording)
        XCTAssertTrue(life.handle(.started, stamped: life.generation))
        XCTAssertTrue(life.stop())
        XCTAssertEqual(life.phase, .finishing)
        XCTAssertTrue(life.handle(.fileClosed(usable: true), stamped: life.generation))
        XCTAssertEqual(life.phase, .landed)
        XCTAssertFalse(life.cutShort)
        XCTAssertTrue(life.canRecord, "the next take may begin")
    }

    func testATakeStartsAtItsFirstFrameWhenTheCameraGivesAPlausibleTime() {
        let reported: UInt64 = 1_000_000
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: 960_000, reported: reported, longestLead: 100_000), 960_000,
                       "the first frame, 40 000 units before its start was reported, places the take")
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: reported, reported: reported, longestLead: 100_000), reported)
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: nil, reported: reported, longestLead: 100_000), reported,
                       "a camera without frame times keeps today's start")
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: 0, reported: reported, longestLead: 100_000), reported,
                       "0 is a failed conversion")
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: 1_000_001, reported: reported, longestLead: 100_000), reported,
                       "a frame cannot come after its own report")
        XCTAssertEqual(VideoTakeLifecycle.startHostTime(frame: 899_999, reported: reported, longestLead: 100_000), reported,
                       "a frame far earlier than any capture delay is a failed conversion")
    }

    func testTheScreenStaysAwakeOnlyWhileATakeIsFilmedOrSaved() {
        var life = VideoTakeLifecycle()
        XCTAssertFalse(life.keepsScreenAwake, "a closed camera lets the screen sleep")
        life.open()
        XCTAssertFalse(life.keepsScreenAwake, "opening the camera is not a take")
        life.handle(.opened, stamped: life.generation)
        XCTAssertFalse(life.keepsScreenAwake, "the picture alone is not a take")
        XCTAssertTrue(life.record())
        XCTAssertTrue(life.keepsScreenAwake, "a take is filmed")
        life.handle(.started, stamped: life.generation)
        XCTAssertTrue(life.stop())
        XCTAssertTrue(life.keepsScreenAwake, "the take's file is being closed")
        life.handle(.fileClosed(usable: true), stamped: life.generation)
        XCTAssertFalse(life.keepsScreenAwake, "the take landed")
        XCTAssertTrue(life.record())
        life.handle(.interruptionBegan, stamped: life.generation)
        life.handle(.fileClosed(usable: true), stamped: life.generation)
        XCTAssertFalse(life.keepsScreenAwake, "a take cut short and landed lets the screen sleep")
        life.close()
        XCTAssertFalse(life.keepsScreenAwake)
    }

    func testAFirstFrameReportedAfterAQuickStopStillPlacesTheTake() {
        var life = readyCamera()
        life.record()
        XCTAssertTrue(life.stop())
        XCTAssertTrue(life.handle(.started, stamped: life.generation),
                      "a quick Stop must not throw away where the take begins")
        XCTAssertEqual(life.phase, .finishing)
        XCTAssertTrue(life.handle(.fileClosed(usable: true), stamped: life.generation))
        XCTAssertFalse(life.handle(.started, stamped: life.generation), "a landed take is placed already")
    }

    func testAFirstFrameReportedAfterAnInterruptionStillPlacesTheTake() {
        var life = readyCamera()
        life.record()
        let stamp = life.generation
        life.handle(.interruptionBegan, stamped: stamp)
        XCTAssertEqual(life.phase, .finishing)
        XCTAssertTrue(life.handle(.started, stamped: stamp))
        life.close()
        XCTAssertFalse(life.handle(.started, stamped: stamp), "a stale first frame places nothing")
    }

    func testAnInterruptedTakeLandsWithItsPartialFileAndSaysItWasCutShort() {
        var life = readyCamera()
        life.record()
        XCTAssertTrue(life.handle(.interruptionBegan, stamped: life.generation))
        XCTAssertEqual(life.phase, .finishing, "iOS closes the file; the take is not thrown away")
        XCTAssertTrue(life.cutShort)
        XCTAssertFalse(life.canRecord, "nothing is filmed while iOS holds the camera")
        XCTAssertTrue(life.handle(.fileClosed(usable: true), stamped: life.generation))
        XCTAssertEqual(life.phase, .landed)
        XCTAssertTrue(life.cutShort, "the caption says 'cut short'")
        XCTAssertFalse(life.canRecord, "still interrupted")
        XCTAssertTrue(life.handle(.interruptionEnded, stamped: life.generation))
        XCTAssertEqual(life.phase, .landed)
        XCTAssertTrue(life.canRecord)
        life.record()
        XCTAssertFalse(life.cutShort, "a new take starts whole")
    }

    func testAnInterruptionWhileThePictureShowsWaitsAndComesBack() {
        var life = readyCamera()
        XCTAssertTrue(life.handle(.interruptionBegan, stamped: life.generation))
        XCTAssertEqual(life.phase, .interrupted)
        XCTAssertFalse(life.record(), "nothing to film while iOS holds the camera")
        XCTAssertTrue(life.handle(.interruptionEnded, stamped: life.generation))
        XCTAssertEqual(life.phase, .ready)
        XCTAssertFalse(life.cutShort)
    }

    func testAnInterruptionWhileOpeningShowsOnceTheCameraIsOpen() {
        var life = VideoTakeLifecycle()
        life.open()
        life.handle(.interruptionBegan, stamped: life.generation)
        XCTAssertEqual(life.phase, .opening)
        life.handle(.opened, stamped: life.generation)
        XCTAssertEqual(life.phase, .interrupted)
        life.handle(.interruptionEnded, stamped: life.generation)
        XCTAssertEqual(life.phase, .ready)
    }

    func testAStaleGenerationChangesNothing() {
        var life = readyCamera()
        let old = life.generation
        life.close()
        XCTAssertNotNil(life.open())
        life.handle(.opened, stamped: life.generation)
        life.record()
        let before = life
        XCTAssertFalse(life.handle(.interruptionBegan, stamped: old))
        XCTAssertFalse(life.handle(.runtimeError, stamped: old))
        XCTAssertFalse(life.handle(.fileClosed(usable: true), stamped: old))
        XCTAssertEqual(life, before, "events from the camera that was closed are dropped")
        life.close()
        let closed = life
        XCTAssertFalse(life.handle(.opened, stamped: life.generation), "a closed camera hears nothing")
        XCTAssertEqual(life, closed)
    }

    func testAChangeOfLensDropsTheLateEventsOfTheLensPutAway() {
        var life = readyCamera()
        let back = life.generation
        XCTAssertTrue(life.changeLens())
        XCTAssertNotEqual(life.generation, back, "a new lens is a new generation")
        XCTAssertEqual(life.phase, .opening)
        XCTAssertFalse(life.handle(.opened, stamped: back), "the back lens's late answer is dropped")
        XCTAssertFalse(life.handle(.interruptionBegan, stamped: back))
        XCTAssertFalse(life.handle(.runtimeError, stamped: back))
        XCTAssertEqual(life.phase, .opening)
        XCTAssertTrue(life.handle(.opened, stamped: life.generation))
        XCTAssertEqual(life.phase, .ready)
    }

    func testAChangeOfLensIsRefusedWhileATakeIsFilmedOrSaved() {
        var life = readyCamera()
        life.record()
        let filming = life
        XCTAssertFalse(life.changeLens(), "never while filming")
        XCTAssertEqual(life, filming)
        life.stop()
        XCTAssertFalse(life.changeLens(), "nor while the file is closed")
        life.handle(.fileClosed(usable: true), stamped: life.generation)
        XCTAssertTrue(life.changeLens(), "after the take has landed it may")
        life.handle(.opened, stamped: life.generation)
        life.handle(.interruptionBegan, stamped: life.generation)
        XCTAssertFalse(life.changeLens(), "nor while iOS holds the camera")
    }

    func testARuntimeErrorWhileFilmingLandsWhatWasFilmedAndFails() {
        var life = readyCamera()
        life.record()
        XCTAssertTrue(life.handle(.runtimeError, stamped: life.generation))
        XCTAssertEqual(life.phase, .finishing)
        XCTAssertTrue(life.cutShort)
        life.handle(.fileClosed(usable: true), stamped: life.generation)
        XCTAssertEqual(life.phase, .failed, "the camera is not trusted after the error")
        XCTAssertFalse(life.canRecord)
        XCTAssertFalse(life.lostLastTake, "the file itself was kept")
        life.close()
        XCTAssertNotNil(life.open(), "closing and opening again is the way back")
    }

    func testARuntimeErrorWhileThePictureShowsFails() {
        var life = readyCamera()
        XCTAssertTrue(life.handle(.runtimeError, stamped: life.generation))
        XCTAssertEqual(life.phase, .failed)
        XCTAssertFalse(life.record())
    }

    func testAnUnusableFileIsSaidAndTheCameraFilmsOn() {
        var life = readyCamera()
        life.record()
        life.stop()
        life.handle(.fileClosed(usable: false), stamped: life.generation)
        XCTAssertEqual(life.phase, .ready)
        XCTAssertTrue(life.lostLastTake)
        XCTAssertTrue(life.record())
        XCTAssertFalse(life.lostLastTake)
        XCTAssertTrue(life.handle(.fileClosed(usable: true), stamped: life.generation),
                      "a take that ended by itself (the disk filled up) still lands")
        XCTAssertEqual(life.phase, .landed)
    }

    func testATakeThatCouldNotBeLaidOnTheSongIsNeverSaidToBeOnIt() {
        var life = readyCamera()
        life.record()
        life.stop()
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation),
                      "the file held the take, but the song did not get it")
        XCTAssertNotEqual(life.phase, .landed, "'landed' is the caption that says the take is on the song")
        XCTAssertEqual(life.phase, .ready)
        XCTAssertTrue(life.lastTakeNotPlaced)
        XCTAssertFalse(life.lostLastTake, "the file itself was not lost")
        XCTAssertTrue(life.record(), "the camera films on")
        XCTAssertFalse(life.lastTakeNotPlaced, "a new take starts without the old one's note")
        life.stop()
        XCTAssertTrue(life.handle(.fileClosed(usable: true), stamped: life.generation))
        XCTAssertEqual(life.phase, .landed)
        XCTAssertFalse(life.lastTakeNotPlaced)
    }

    func testATakeCutShortThatCouldNotBeLaidOnTheSongWaitsForTheCamera() {
        var life = readyCamera()
        life.record()
        life.handle(.interruptionBegan, stamped: life.generation)
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation))
        XCTAssertEqual(life.phase, .interrupted, "iOS still holds the camera")
        XCTAssertTrue(life.lastTakeNotPlaced)
        XCTAssertTrue(life.handle(.interruptionEnded, stamped: life.generation))
        XCTAssertEqual(life.phase, .ready)
        XCTAssertTrue(life.lastTakeNotPlaced, "the note stays until the next take")
    }

    func testATakeAfterARuntimeErrorThatCouldNotBeLaidOnTheSongFails() {
        var life = readyCamera()
        life.record()
        life.handle(.runtimeError, stamped: life.generation)
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation))
        XCTAssertEqual(life.phase, .failed, "the camera is not trusted after the error")
        XCTAssertTrue(life.lastTakeNotPlaced)
    }

    func testNotPlacedMeansNothingOutsideATakeOrFromAnOlderCamera() {
        var life = readyCamera()
        let ready = life
        XCTAssertFalse(life.handle(.notPlaced, stamped: life.generation), "no take is closing its file")
        XCTAssertEqual(life, ready)
        life.record()
        life.stop()
        let old = life.generation
        life.close()
        life.open()
        life.handle(.opened, stamped: life.generation)
        let reopened = life
        XCTAssertFalse(life.handle(.notPlaced, stamped: old), "a closed camera's take changes nothing")
        XCTAssertEqual(life, reopened)
        life.record()
        life.stop()
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation))
        XCTAssertTrue(life.lastTakeNotPlaced)
        life.close()
        XCTAssertFalse(life.lastTakeNotPlaced, "closing the camera clears the note")
    }

    func testATakeThatEndedByItselfAndCouldNotBeLaidOnTheSongFilmsOn() {
        var life = readyCamera()
        XCTAssertTrue(life.record())
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation),
                      "the disk filled up mid-take and the song did not get it")
        XCTAssertEqual(life.phase, .ready)
        XCTAssertTrue(life.lastTakeNotPlaced)
        XCTAssertFalse(life.lostLastTake)
        XCTAssertFalse(life.keepsScreenAwake, "nothing is filmed or saved any more")
        XCTAssertTrue(life.canRecord)
    }

    func testACallWhileAStoppedTakeIsSavedAndNotLaidOnTheSongWaitsForTheCamera() {
        var life = readyCamera()
        life.record()
        life.stop()
        XCTAssertTrue(life.handle(.interruptionBegan, stamped: life.generation))
        XCTAssertEqual(life.phase, .finishing, "a stopped take closes its file as it was")
        XCTAssertFalse(life.cutShort, "Stop ended it, not the call")
        XCTAssertTrue(life.handle(.notPlaced, stamped: life.generation))
        XCTAssertEqual(life.phase, .interrupted, "iOS holds the camera")
        XCTAssertFalse(life.canRecord)
        XCTAssertTrue(life.lastTakeNotPlaced)
        XCTAssertTrue(life.handle(.interruptionEnded, stamped: life.generation))
        XCTAssertEqual(life.phase, .ready)
        XCTAssertTrue(life.canRecord)
    }

    func testOnlyAPlacedTakeReportsAUsableFile() {
        XCTAssertEqual(VideoTakeLifecycle.Event.afterCommit(placed: true), .fileClosed(usable: true))
        XCTAssertEqual(VideoTakeLifecycle.Event.afterCommit(placed: false), .notPlaced)
        var life = readyCamera()
        life.record()
        life.stop()
        life.handle(.afterCommit(placed: false), stamped: life.generation)
        XCTAssertNotEqual(life.phase, .landed, "a take the song did not take is not said to be on it")
    }
}
