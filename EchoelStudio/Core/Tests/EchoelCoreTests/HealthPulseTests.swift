import XCTest
@testable import EchoelCore

/// Apple Health's heart rate as a body source (REC-1): a reading moves anything only while it is
/// recent by its MEASUREMENT time, a stale one reads as not measured, and nothing is invented.
final class HealthPulseTests: XCTestCase {
    private let lead = HealthPulse.clockLeadMilliseconds

    /// A channel for Health that has been started, as the producer starts it: the read permission
    /// cannot be asked back from iOS, so it stays unknown and fresh data is the evidence.
    private func started(at now: Int64) throws -> BodyChannel {
        var channel = BodyChannel(maximumAgeMilliseconds: HealthPulse.freshMilliseconds)
        _ = try channel.step(.start(.health, .unknown), at: now)
        return channel
    }

    func testTheRangeIsTheStrapsRange() {
        XCTAssertEqual(HealthPulse.normalized(beatsPerMinute: 40), 0)
        XCTAssertEqual(HealthPulse.normalized(beatsPerMinute: 200), 1)
        XCTAssertEqual(HealthPulse.normalized(beatsPerMinute: 120) ?? -1, 0.5, accuracy: 1e-12)
        XCTAssertNil(HealthPulse.normalized(beatsPerMinute: 39))
        XCTAssertNil(HealthPulse.normalized(beatsPerMinute: 230))
        XCTAssertNil(HealthPulse.normalized(beatsPerMinute: .nan))
    }

    func testARecentReadingIsMeasuredWithoutAnAnsweredPermission() throws {
        let now = lead + 10_000
        var channel = try started(at: now)
        let sample = HealthPulse.sample(beatsPerMinute: 72, measuredSecondsAgo: 5, nowMilliseconds: now,
                                        epoch: channel.epoch, sequence: 1)
        XCTAssertEqual(sample.capturedMilliseconds, now - 5_000)
        let step = try channel.step(.sample(sample), at: now)
        XCTAssertEqual(step.outcome, .accepted)
        XCTAssertEqual(step.state, .valid)
        XCTAssertEqual(step.value ?? -1, 0.2, accuracy: 1e-12)
    }

    func testAReadingOlderThanFreshIsNotMeasured() throws {
        let now = lead + 600_000
        var channel = try started(at: now)
        let sample = HealthPulse.sample(beatsPerMinute: 72, measuredSecondsAgo: HealthPulse.freshSeconds + 1,
                                        nowMilliseconds: now, epoch: channel.epoch, sequence: 1)
        let step = try channel.step(.sample(sample), at: now)
        XCTAssertEqual(step.outcome, .stale)
        XCTAssertNil(step.value)
    }

    func testAMeasuredValueGoesStaleWhenNoNewReadingComes() throws {
        let now = lead + 10_000
        var channel = try started(at: now)
        let sample = HealthPulse.sample(beatsPerMinute: 80, measuredSecondsAgo: 4, nowMilliseconds: now,
                                        epoch: channel.epoch, sequence: 1)
        XCTAssertNotNil(try channel.step(.sample(sample), at: now).value)
        let later = now - 4_000 + HealthPulse.freshMilliseconds + 1
        let step = try channel.step(.tick, at: later)
        XCTAssertEqual(step.state, .stale)
        XCTAssertNil(step.value)
    }

    func testAReadingFromBeforeTheAppStartedIsTooOldNotNegative() throws {
        let now = lead
        var channel = try started(at: now)
        let sample = HealthPulse.sample(beatsPerMinute: 70, measuredSecondsAgo: 3_600, nowMilliseconds: now,
                                        epoch: channel.epoch, sequence: 1)
        XCTAssertEqual(sample.capturedMilliseconds, 0)
        XCTAssertEqual(try channel.step(.sample(sample), at: now).outcome, .stale)
    }

    func testAReadingDatedAheadCountsAsJustTaken() throws {
        let now = lead + 1_000
        let sample = HealthPulse.sample(beatsPerMinute: 70, measuredSecondsAgo: -2, nowMilliseconds: now,
                                        epoch: 1, sequence: 1)
        XCTAssertEqual(sample.capturedMilliseconds, now)
    }

    func testAnImplausibleOrUndatedReadingIsInvalid() throws {
        let now = lead + 10_000
        var channel = try started(at: now)
        let good = HealthPulse.sample(beatsPerMinute: 72, measuredSecondsAgo: 5, nowMilliseconds: now,
                                      epoch: channel.epoch, sequence: 1)
        _ = try channel.step(.sample(good), at: now)
        let implausible = HealthPulse.sample(beatsPerMinute: 250, measuredSecondsAgo: 1, nowMilliseconds: now,
                                             epoch: channel.epoch, sequence: 2)
        let step = try channel.step(.sample(implausible), at: now)
        XCTAssertEqual(step.outcome, .invalid)
        XCTAssertNil(step.value, "never the last good value as a stand-in")
        let undated = HealthPulse.sample(beatsPerMinute: 72, measuredSecondsAgo: .nan, nowMilliseconds: now,
                                         epoch: channel.epoch, sequence: 3)
        XCTAssertNil(undated.capturedMilliseconds)
        XCTAssertEqual(try channel.step(.sample(undated), at: now).outcome, .invalid)
    }

    func testAnOlderReadingCannotRollTheValueBack() throws {
        let now = lead + 10_000
        var channel = try started(at: now)
        let newer = HealthPulse.sample(beatsPerMinute: 90, measuredSecondsAgo: 2, nowMilliseconds: now,
                                       epoch: channel.epoch, sequence: 1)
        _ = try channel.step(.sample(newer), at: now)
        let older = HealthPulse.sample(beatsPerMinute: 60, measuredSecondsAgo: 8, nowMilliseconds: now,
                                       epoch: channel.epoch, sequence: 2)
        let step = try channel.step(.sample(older), at: now)
        XCTAssertEqual(step.outcome, .ignoredOrder)
        XCTAssertEqual(step.value ?? -1, HealthPulse.normalized(beatsPerMinute: 90) ?? -2, accuracy: 1e-12)
    }

    func testHealthNeverLeavesTheDevice() {
        XCTAssertFalse(BioEgressPolicy.allowsEgress(.health))
    }
}
