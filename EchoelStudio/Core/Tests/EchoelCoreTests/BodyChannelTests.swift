import XCTest
@testable import EchoelCore

/// The G-A state vectors (`.claude/skills/g-a-body-modulation/references/FIXTURES.json`, group
/// `state`), generated from that file so none is copied by hand. Each case replays its events and
/// compares state, run, value and outcome after every one. Wave W1, Codex handover A1.
final class BodyChannelTests: XCTestCase {
    private typealias Event = BodyChannel.Event
    /// One expected step: state, run, value, outcome.
    private struct Expected {
        let state: BodyChannel.State, epoch: UInt64, value: Double?, outcome: BodyChannel.Outcome
        init(_ state: BodyChannel.State, _ epoch: UInt64, _ value: Double?, _ outcome: BodyChannel.Outcome) {
            self.state = state
            self.epoch = epoch
            self.value = value
            self.outcome = outcome
        }
    }

    private func replay(_ events: [(Event, Int64)], _ expected: [Expected], _ name: String,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        var channel = BodyChannel()
        XCTAssertEqual(events.count, expected.count, name, file: file, line: line)
        for (index, (event, now)) in events.enumerated() where index < expected.count {
            let step = try channel.step(event, at: now)
            let want = expected[index]
            XCTAssertEqual(step.state, want.state, "\(name) step \(index + 1) state", file: file, line: line)
            XCTAssertEqual(step.epoch, want.epoch, "\(name) step \(index + 1) run", file: file, line: line)
            XCTAssertEqual(step.value, want.value, "\(name) step \(index + 1) value", file: file, line: line)
            XCTAssertEqual(step.outcome, want.outcome, "\(name) step \(index + 1) outcome", file: file, line: line)
        }
    }

    /// No opt-in means no value and no active producer.
    func testS01DefaultOff() throws {
        try replay([
            (.tick, 0),
        ], [
            Expected(.off, 0, nil, .accepted),
        ], "S01_default_off")
    }

    /// At age 2000 ms valid; at 2001 stale. Arrival never resets measurement age.
    func testS02AgeBoundary() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.tick, 2100),
            (.tick, 2101),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.stale, 1, nil, .accepted),
        ], "S02_age_boundary")
    }

    /// A previous producer cannot write after the selected source changed.
    func testS03SourceSwitch() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.start(.ble, .granted), 200),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 101, value: 0.75, quality: 0.9)), 201),
            (.sample(.init(source: .ble, epoch: 2, sequence: 1, capturedMilliseconds: 202, value: 0.25, quality: 0.9)), 202),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.waiting, 2, nil, .accepted),
            Expected(.waiting, 2, nil, .ignoredGeneration),
            Expected(.valid, 2, 0.25, .accepted),
        ], "S03_source_switch")
    }

    /// Same source name with old epoch is still an old producer.
    func testS04StopRestart() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.stop, 200),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 201, value: 0.75, quality: 0.9)), 201),
            (.start(.camera, .granted), 300),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 301, value: 0.75, quality: 0.9)), 301),
            (.sample(.init(source: .camera, epoch: 3, sequence: 1, capturedMilliseconds: 302, value: 0.75, quality: 0.9)), 302),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.off, 2, nil, .accepted),
            Expected(.off, 2, nil, .ignoredInactive),
            Expected(.waiting, 3, nil, .accepted),
            Expected(.waiting, 3, nil, .ignoredGeneration),
            Expected(.valid, 3, 0.75, .accepted),
        ], "S04_stop_restart")
    }

    /// Revocation invalidates current value and pending callback generation.
    func testS05PermissionRevoked() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.permission(.denied, source: .camera, epoch: 1), 200),
            (.sample(.init(source: .camera, epoch: 2, sequence: 1, capturedMilliseconds: 201, value: 0.75, quality: 0.9)), 201),
            (.permission(.granted, source: .camera, epoch: 2), 300),
            (.sample(.init(source: .camera, epoch: 2, sequence: 1, capturedMilliseconds: 301, value: 0.75, quality: 0.9)), 301),
            (.sample(.init(source: .camera, epoch: 3, sequence: 1, capturedMilliseconds: 302, value: 0.75, quality: 0.9)), 302),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.denied, 2, nil, .accepted),
            Expected(.denied, 2, nil, .ignoredInactive),
            Expected(.waiting, 3, nil, .accepted),
            Expected(.waiting, 3, nil, .ignoredGeneration),
            Expected(.valid, 3, 0.75, .accepted),
        ], "S05_permission_revoked")
    }

    /// Resume starts a new generation; switching source does not bypass suspension.
    func testS06Suspension() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.suspend, 200),
            (.start(.ble, .granted), 201),
            (.sample(.init(source: .ble, epoch: 3, sequence: 1, capturedMilliseconds: 202, value: 0.25, quality: 0.9)), 202),
            (.resume, 300),
            (.sample(.init(source: .ble, epoch: 3, sequence: 2, capturedMilliseconds: 301, value: 0.25, quality: 0.9)), 301),
            (.sample(.init(source: .ble, epoch: 4, sequence: 1, capturedMilliseconds: 302, value: 0.25, quality: 0.9)), 302),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.suspended, 2, nil, .accepted),
            Expected(.suspended, 3, nil, .accepted),
            Expected(.suspended, 3, nil, .ignoredInactive),
            Expected(.waiting, 4, nil, .accepted),
            Expected(.waiting, 4, nil, .ignoredGeneration),
            Expected(.valid, 4, 0.25, .accepted),
        ], "S06_suspension")
    }

    /// Duplicate sequence cannot keep a frozen sensor alive.
    func testS07DuplicateNotRefresh() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 2101, value: 0.75, quality: 0.9)), 2101),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.stale, 1, nil, .ignoredOrder),
        ], "S07_duplicate_not_refresh")
    }

    /// Newer sequence with older timestamp cannot roll value backwards.
    func testS08TimestampOrder() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.sample(.init(source: .camera, epoch: 1, sequence: 2, capturedMilliseconds: 99, value: 0.1, quality: 0.9)), 200),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.valid, 1, 0.75, .ignoredOrder),
        ], "S08_timestamp_order")
    }

    /// Quality threshold 0.7 is inclusive; lower quality removes the current value.
    func testS09QualityBoundary() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.5, quality: 0.7)), 100),
            (.sample(.init(source: .camera, epoch: 1, sequence: 2, capturedMilliseconds: 200, value: 0.9, quality: 0.699)), 200),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.5, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S09_quality_boundary")
    }

    /// A sample from the future is invalid, not clamped to now.
    func testS10FutureTimestamp() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 101, value: 0.75, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S10_future_timestamp")
    }

    /// Fresh callback does not make a measurement captured 2001 ms ago fresh.
    func testS11LateDelivery() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 2101),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.stale, 1, nil, .stale),
        ], "S11_late_delivery")
    }

    /// Out-of-domain normalized value is invalid; a new ordered sample recovers.
    func testS12InvalidRecovery() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 1.1, quality: 0.9)), 100),
            (.sample(.init(source: .camera, epoch: 1, sequence: 2, capturedMilliseconds: 200, value: 0.4, quality: 0.9)), 200),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
            Expected(.valid, 1, 0.4, .accepted),
        ], "S12_invalid_recovery")
    }

    /// Health read permission is not inferable; actual fresh data can be accepted.
    func testS13HealthReadUnknown() throws {
        try replay([
            (.start(.health, .unknown), 0),
            (.sample(.init(source: .health, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
        ], "S13_health_read_unknown")
    }

    /// Camera is not acquired before explicit usable authorization.
    func testS14CameraUnknown() throws {
        try replay([
            (.start(.camera, .unknown), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.waiting, 1, nil, .ignoredInactive),
        ], "S14_camera_unknown")
    }

    /// Quality above one is invalid rather than accepted as very good.
    func testS15QualityOutsideDomain() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 1.1)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S15_quality_outside_domain")
    }

    /// Missing normalized value cannot become plausible measurement.
    func testS16Null() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: nil, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S16_null")
    }

    /// JSON booleans are not numeric measurements.
    func testS17Boolean() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: nil, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S17_boolean")
    }

    /// Host monotonic clock must never go backwards.
    func testS18ClockReversal() throws {
        var channel = BodyChannel()
        _ = try channel.step(.tick, at: 20)
        XCTAssertThrowsError(try channel.step(.tick, at: 19)) { XCTAssertTrue($0 is BodyChannel.ClockWentBack) }
    }

    /// A new sequence with identical capture time is not a fresh measurement.
    func testS19EqualTimestamp() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
            (.sample(.init(source: .camera, epoch: 1, sequence: 2, capturedMilliseconds: 100, value: 0.1, quality: 0.9)), 200),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.valid, 1, 0.75, .accepted),
            Expected(.valid, 1, 0.75, .ignoredOrder),
        ], "S19_equal_timestamp")
    }

    /// Correct epoch does not override source identity.
    func testS20WrongSource() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .ble, epoch: 1, sequence: 1, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.waiting, 1, nil, .ignoredGeneration),
        ], "S20_wrong_source")
    }

    /// Malformed current-source sample invalidates instead of throwing through callback.
    func testS21MissingSequence() throws {
        try replay([
            (.start(.camera, .granted), 0),
            (.sample(.init(source: .camera, epoch: 1, sequence: nil, capturedMilliseconds: 100, value: 0.75, quality: 0.9)), 100),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.invalid, 1, nil, .invalid),
        ], "S21_missing_sequence")
    }

    /// Late camera denial cannot revoke the newly selected BLE source.
    func testS22StalePermission() throws {
        try replay([
            (.start(.camera, .unknown), 0),
            (.start(.ble, .granted), 10),
            (.sample(.init(source: .ble, epoch: 2, sequence: 1, capturedMilliseconds: 20, value: 0.6, quality: 0.9)), 20),
            (.permission(.denied, source: .camera, epoch: 1), 30),
        ], [
            Expected(.waiting, 1, nil, .accepted),
            Expected(.waiting, 2, nil, .accepted),
            Expected(.valid, 2, 0.6, .accepted),
            Expected(.valid, 2, 0.6, .ignoredGeneration),
        ], "S22_stale_permission")
    }
}
