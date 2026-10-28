import XCTest
@testable import EchoelDSP

final class BeatDerivedSourcesTests: XCTestCase {
    func testTooFewIntervalsStateNothing() {
        let readings = BeatDerivedSources.readings(rrMs: [800, 820, 810])
        XCTAssertNil(readings.hrv)
        XCTAssertNil(readings.coherence)
    }

    /// Alternating 800/840 ms: every successive difference is 40 ms, so RMSSD is 40 ms → 0.4.
    func testHRVIsRMSSDOverOneHundredMilliseconds() throws {
        let rr = (0..<20).map { (index: Int) -> Double in index % 2 == 0 ? 800 : 840 }
        let readings = BeatDerivedSources.readings(rrMs: rr)
        XCTAssertEqual(try XCTUnwrap(readings.hrv), 0.4, accuracy: 1e-9)
    }

    func testCoherenceNeedsSixteenIntervalsAndStaysWithinZeroToOne() throws {
        let breathing = (0..<12).map { (beat: Int) -> Double in 850 + 60 * sin(2 * Double.pi * Double(beat) / 10) }
        XCTAssertNil(BeatDerivedSources.readings(rrMs: breathing).coherence, "twelve beats are not a spectrum")
        let longer = (0..<64).map { (beat: Int) -> Double in 850 + 60 * sin(2 * Double.pi * Double(beat) / 10) }
        let coherence = try XCTUnwrap(BeatDerivedSources.readings(rrMs: longer).coherence)
        XCTAssertGreaterThanOrEqual(coherence, 0)
        XCTAssertLessThanOrEqual(coherence, 1)
    }

    /// Steps of 100 % are rejected beats; with most of them gone nothing is stated, never a low HRV.
    func testAPoorContactStatesNothing() {
        let rr = (0..<30).map { (index: Int) -> Double in index % 2 == 0 ? 600 : 1_200 }
        let readings = BeatDerivedSources.readings(rrMs: rr)
        XCTAssertNil(readings.hrv)
        XCTAssertNil(readings.coherence)
    }
}
