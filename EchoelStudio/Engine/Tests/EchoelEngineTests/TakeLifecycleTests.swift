import XCTest
@testable import EchoelEngine

/// What a route change does to a take — simulated here, where the app's audio session is not:
/// the app's engine drives `TakeLifecycle` from `AVAudioSession.routeChangeNotification`, the
/// configuration change that rebuilds the graph, a pause from outside and the stop
/// (review 2026-10-28, 2.1). The route change under a real take is device-verified.
final class TakeLifecycleTests: XCTestCase {
    func testARouteChangeUnderAnArmedTrackWithoutATakeEndsNothing() {
        var take = TakeLifecycle()
        XCTAssertEqual(take.phase, .idle)
        XCTAssertFalse(take.endedFromOutside(), "nothing records, so nothing is announced")
        XCTAssertEqual(take.phase, .idle)
        XCTAssertFalse(take.ownsRecorder, "the rebuilt graph records through a recorder of its own")
        XCTAssertTrue(take.canBegin, "the input simply reopens and Record is ready")
    }

    func testARouteChangeUnderARecordingTakeEndsItOnceAndTheNextTakeWaitsForTheFile() {
        var take = TakeLifecycle()
        XCTAssertTrue(take.begin())
        XCTAssertEqual(take.phase, .recording)
        XCTAssertFalse(take.begin(), "one take at a time")

        // The route changes and the graph is rebuilt under the take.
        XCTAssertTrue(take.endedFromOutside(), "the song pauses for the take and the controller is told")
        XCTAssertEqual(take.phase, .ended)
        XCTAssertTrue(take.ownsRecorder, "the take keeps the recorder it began on; the new graph gets a new one")
        XCTAssertFalse(take.canBegin, "no new take before this one is written out")

        // The pause that follows, or a second route change, ends it no second time.
        XCTAssertFalse(take.endedFromOutside(), "announced once")
        XCTAssertEqual(take.phase, .ended)

        // The controller stops it: the file is written out, the recorder and ring still in use.
        XCTAssertTrue(take.stop())
        XCTAssertEqual(take.phase, .finishing)
        XCTAssertFalse(take.ownsRecorder)
        XCTAssertFalse(take.canBegin, "its writer still drains the ring")
        XCTAssertFalse(take.stop(), "stopped once")
        XCTAssertFalse(take.endedFromOutside(), "a route change while the file is written changes nothing")

        take.finished()
        XCTAssertEqual(take.phase, .idle)
        XCTAssertTrue(take.canBegin)
        XCTAssertTrue(take.begin(), "Record starts the next take on the new recorder")
    }

    func testTheTransportsOwnStopWritesARecordingTakeOut() {
        var take = TakeLifecycle()
        take.begin()
        XCTAssertTrue(take.stop(), "a take that nothing ended from outside stops as well")
        XCTAssertEqual(take.phase, .finishing)
        XCTAssertFalse(take.endedFromOutside(), "too late to end: it is being written")
        take.finished()
        XCTAssertEqual(take.phase, .idle)
    }

    func testFinishingWithoutATakeIsHarmless() {
        var take = TakeLifecycle()
        XCTAssertFalse(take.stop())
        take.finished()
        XCTAssertEqual(take.phase, .idle)
        XCTAssertEqual(take, TakeLifecycle())
    }
}
