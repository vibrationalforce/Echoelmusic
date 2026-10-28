import XCTest
@testable import EchoelDSP

/// The strap's packet as the Bluetooth profile defines it; the vectors are the earlier app's
/// (`TheStrapCannotPublishADeadBodyTests`) plus the wide rate and the energy field.
final class HeartRateMeasurementTests: XCTestCase {
    func testAStrapOffTheSkinIsNoMeasurement() {
        XCTAssertNil(HeartRateMeasurement([0x02, 70]), "contact supported, not detected")
        XCTAssertNil(HeartRateMeasurement([0x12, 70, 0x00, 0x04]), "and no phantom beats with it")
    }

    func testContactAndItsAbsenceAreTold() throws {
        let detected = try XCTUnwrap(HeartRateMeasurement([0x06, 70]))
        XCTAssertEqual(detected.beatsPerMinute, 70)
        XCTAssertEqual(detected.contact, .detected)
        let unsupported = try XCTUnwrap(HeartRateMeasurement([0x00, 70]))
        XCTAssertEqual(unsupported.contact, .unknown, "a strap that cannot tell is not called off the skin")
        XCTAssertTrue(unsupported.rrIntervalsMilliseconds.isEmpty)
    }

    func testRRIntervalsAreMillisecondsFrom1024ths() throws {
        let packet = try XCTUnwrap(HeartRateMeasurement([0x10, 70, 0x00, 0x04, 0x00, 0x02]))
        XCTAssertEqual(packet.rrIntervalsMilliseconds, [1_000, 500], "1024 and 512 of 1/1024 s")
    }

    func testAWideRateAndAnEnergyFieldAreRead() throws {
        // flags: wide rate + energy + intervals; rate 300; energy 0x1234; one interval of 1/2 s.
        let packet = try XCTUnwrap(HeartRateMeasurement([0x19, 0x2C, 0x01, 0x34, 0x12, 0x00, 0x02]))
        XCTAssertEqual(packet.beatsPerMinute, 300)
        XCTAssertEqual(packet.rrIntervalsMilliseconds, [500], "the energy bytes are skipped, not read as a beat")
    }

    func testAnEmptyOrCutPacketIsNoMeasurement() {
        XCTAssertNil(HeartRateMeasurement([]))
        XCTAssertNil(HeartRateMeasurement([0x01, 70]), "a wide rate needs two bytes")
        XCTAssertNil(HeartRateMeasurement([0x00]), "no rate byte")
        let odd = HeartRateMeasurement([0x10, 70, 0x00, 0x04, 0x00])
        XCTAssertEqual(odd?.rrIntervalsMilliseconds, [1_000], "a half interval at the end is dropped")
    }
}
