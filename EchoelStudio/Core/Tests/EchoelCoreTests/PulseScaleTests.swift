import XCTest
@testable import EchoelCore

/// The one scale a heart rate moves the song on (BR-12): a rate in 40 … 200 bpm lands on its own
/// point, exactly as measured, and anything else is no pulse.
final class PulseScaleTests: XCTestCase {
    func testARateIsPlacedAsMeasuredNeverRoundedToAWholeBeat() throws {
        let between = try XCTUnwrap(PulseScale.normalized(beatsPerMinute: 72.4))
        XCTAssertEqual(between, (72.4 - 40) / 160)
        XCTAssertEqual(PulseScale.normalized(beatsPerMinute: 72), 0.2)
        XCTAssertNotEqual(between, 0.2, "72.4 bpm is not moved to the point of 72")
        XCTAssertNotEqual(PulseScale.normalized(beatsPerMinute: 72.6), PulseScale.normalized(beatsPerMinute: 73),
                          "nor 72.6 to the point of 73")
        XCTAssertEqual(PulseScale.normalized(beatsPerMinute: 40), 0)
        XCTAssertEqual(PulseScale.normalized(beatsPerMinute: 200), 1)
        XCTAssertEqual(PulseScale.normalized(beatsPerMinute: 120), 0.5)
    }

    func testARateOutsideFortyToTwoHundredIsNoPulse() {
        let outside: [Double] = [39.7, 200.3, 39.999, 200.001, 0, -72.4, .nan, .infinity, -.infinity]
        for rate in outside {
            XCTAssertNil(PulseScale.normalized(beatsPerMinute: rate), "\(rate)")
        }
    }

    func testAppleHealthReadsOnTheSameScale() {
        let rates: [Double] = [39.7, 40, 72.4, 120, 200, 200.3, .nan]
        for rate in rates {
            let shared = PulseScale.normalized(beatsPerMinute: rate)
            XCTAssertEqual(HealthPulse.normalized(beatsPerMinute: rate), shared, "\(rate)")
            let sample = HealthPulse.sample(beatsPerMinute: rate, measuredSecondsAgo: 1,
                                            nowMilliseconds: HealthPulse.clockLeadMilliseconds, epoch: 1, sequence: 1)
            XCTAssertEqual(sample.value, shared, "\(rate)")
        }
        XCTAssertEqual(HealthPulse.plausibleBeats, PulseScale.plausibleBeats)
    }
}
