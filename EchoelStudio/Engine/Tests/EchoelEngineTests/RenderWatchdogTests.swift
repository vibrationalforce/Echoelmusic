import XCTest
@testable import EchoelEngine

final class RenderWatchdogTests: XCTestCase {
    private func seconds(_ value: Double) -> Duration { .milliseconds(Int64(value * 1_000)) }

    /// A count that keeps moving while the song plays is never a stall, however long it plays.
    func testARenderingGraphIsLeftAlone() {
        var watchdog = RenderWatchdog()
        for second in 0..<60 {
            XCTAssertEqual(watchdog.look(count: UInt64(second * 94), at: seconds(Double(second)), playing: true), .fine)
        }
    }

    /// A count that stands still for the limit while playing asks for a rebuild once; the next
    /// one waits a whole limit again.
    func testACountStandingStillForTwoSecondsAsksForOneRebuild() {
        var watchdog = RenderWatchdog()
        XCTAssertEqual(watchdog.look(count: 500, at: seconds(0), playing: true), .fine)
        XCTAssertEqual(watchdog.look(count: 500, at: seconds(1), playing: true), .fine, "one second is not a stall")
        XCTAssertEqual(watchdog.look(count: 500, at: seconds(2), playing: true), .heal(stalled: seconds(2)))
        XCTAssertEqual(watchdog.look(count: 500, at: seconds(3), playing: true), .fine, "the rebuild gets its time")
        XCTAssertEqual(watchdog.look(count: 500, at: seconds(4), playing: true), .heal(stalled: seconds(2)))
    }

    /// Rebuilds that bring nothing back are tried a few times; then it is said once and the
    /// watchdog stays quiet, until the count moves again — which starts the count of rebuilds over.
    func testADeadGraphIsRebuiltAFewTimesThenLeftToTheMusician() {
        var watchdog = RenderWatchdog()
        var verdicts: [RenderWatchdog.Verdict] = []
        for second in 0...20 {
            verdicts.append(watchdog.look(count: 7, at: seconds(Double(second)), playing: true))
        }
        let heals = verdicts.filter { if case .heal = $0 { return true } else { return false } }
        XCTAssertEqual(heals.count, RenderWatchdog.healLimit)
        XCTAssertEqual(verdicts.filter { $0 == .gaveUp }.count, 1)
        XCTAssertEqual(verdicts.last, .fine)

        XCTAssertEqual(watchdog.look(count: 8, at: seconds(21), playing: true), .fine)
        XCTAssertEqual(watchdog.look(count: 8, at: seconds(23), playing: true), .heal(stalled: seconds(2)),
                       "a graph that came back and stalled again is rebuilt again")
    }

    /// Paused, the count may stand still for ever; a new Play starts the wait from nothing. A
    /// rebuilt graph counts from zero again, which is a move, not a stall.
    func testAPauseAndANewGraphAreNeverAStall() {
        var watchdog = RenderWatchdog()
        XCTAssertEqual(watchdog.look(count: 900, at: seconds(0), playing: true), .fine)
        for second in 1...10 {
            XCTAssertEqual(watchdog.look(count: 900, at: seconds(Double(second)), playing: false), .fine)
        }
        XCTAssertEqual(watchdog.look(count: 900, at: seconds(11), playing: true), .fine)
        XCTAssertEqual(watchdog.look(count: 900, at: seconds(12), playing: true), .fine, "the wait started at Play")
        XCTAssertEqual(watchdog.look(count: 0, at: seconds(13), playing: true), .fine, "a new core starts at zero")
        XCTAssertEqual(watchdog.look(count: 0, at: seconds(10), playing: true), .fine, "a clock that went back")
        XCTAssertEqual(watchdog.look(count: 0, at: seconds(11), playing: true), .fine)
    }
}
