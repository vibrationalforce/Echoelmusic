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
}
