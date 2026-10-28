import XCTest
@testable import EchoelCore

final class FieldTests: XCTestCase {
    func testThePhasesFollowThePlayheadAndRestWhenStopped() {
        let beat = Double(MusicalTime.ticksPerQuarter)
        let playing = FieldFrame.at(tick: beat * 5.5, signature: .common, context: MusicalContext(), level: 0.5,
                                    pulse: nil, hrv: nil, coherence: nil, isPlaying: true)
        XCTAssertEqual(playing.beatPhase, 0.5, accuracy: 1e-12)
        XCTAssertEqual(playing.barPhase, 1.5 / 4, accuracy: 1e-12, "beat 6 of a 4/4 bar is half-way through its second beat")
        let stopped = FieldFrame.at(tick: beat * 5.5, signature: .common, context: MusicalContext(), level: 0.5,
                                    pulse: nil, hrv: nil, coherence: nil, isPlaying: false)
        XCTAssertEqual(stopped.beatPhase, 0)
        XCTAssertEqual(stopped.barPhase, 0)
    }

    func testRelatedKeysSitCloseOnTheCircleOfFifths() {
        XCTAssertEqual(FieldFrame.keyHue(root: 0), 0)
        XCTAssertEqual(FieldFrame.keyHue(root: 7), 1.0 / 12, accuracy: 1e-12, "G is one fifth from C")
        XCTAssertEqual(FieldFrame.keyHue(root: 2), 2.0 / 12, accuracy: 1e-12, "D is two")
        XCTAssertEqual(FieldFrame.keyHue(root: 5), 11.0 / 12, accuracy: 1e-12, "F is one fifth below")
        XCTAssertEqual(FieldFrame.keyHue(root: -1), FieldFrame.keyHue(root: 11))
    }

    /// The picture never invents a body: a reading outside 0 … 1 or not finite is absent.
    func testAnUnmeasuredOrBadBodyReadingIsAbsent() {
        let frame = FieldFrame(level: 7, pulse: 1.5, hrv: .nan, coherence: 0.4)
        XCTAssertEqual(frame.level, 1)
        XCTAssertNil(frame.pulse)
        XCTAssertNil(frame.hrv)
        XCTAssertEqual(frame.coherence, 0.4)
    }

    /// Asked to strobe at 10 Hz, the guard lets through no more than three flashes a second.
    func testNoMoreThanThreeFlashesASecond() {
        var limit = FlashLimit()
        let frameSeconds = 1.0 / 60
        var shown: [Double] = []
        for frame in 0..<600 {
            let strobe = (frame / 3) % 2 == 0 ? 1.0 : 0.0  // 10 Hz at 60 frames a second
            shown.append(limit.next(towards: strobe, after: frameSeconds))
        }
        // Count full swings of at least one flash step, rise then fall.
        var flashes = 0, anchor = shown[0], rising = true
        for value in shown {
            if rising, value - anchor >= FlashLimit.flashStep { rising = false; anchor = value }
            else if !rising, anchor - value >= FlashLimit.flashStep { rising = true; anchor = value; flashes += 1 }
            if rising { anchor = Swift.min(anchor, value) } else { anchor = Swift.max(anchor, value) }
        }
        XCTAssertLessThanOrEqual(Double(flashes) / 10, FlashLimit.flashesPerSecond)
    }

    func testTheGuardStillReachesASlowTarget() {
        var limit = FlashLimit()
        for _ in 0..<120 { _ = limit.next(towards: 0.5, after: 1.0 / 60) }
        XCTAssertEqual(limit.value, 0.5, accuracy: 1e-9, "a gentle change arrives within two seconds")
        XCTAssertEqual(limit.next(towards: .nan, after: 1), 0.5, "a bad target changes nothing")
    }
}
