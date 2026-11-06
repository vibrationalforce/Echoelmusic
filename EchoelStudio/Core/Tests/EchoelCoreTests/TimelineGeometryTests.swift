import XCTest
@testable import EchoelCore

final class TimelineGeometryTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)
    /// Two bars of 4/4, then 7/8 from bar 3 on.
    private var changing: MeterMap {
        MeterMap(signature: .common, changes: [TimeSignatureChange(tick: 2 * bar, signature: TimeSignature(7, 8))])
    }

    func testABarLineSitsWhereItsTicksPutItIn4Over4AndAfterAChangeTo7Over8() {
        let meter = changing
        let ticksPerPoint = TimelineGeometry.ticksPerPoint(meter: meter)
        XCTAssertEqual(ticksPerPoint, Double(bar) / 88, accuracy: 1e-9, "the first bar is 88 points wide")
        for index in Int64(0)...6 {
            let line = meter.tick(ofBar: index)
            XCTAssertEqual(TimelineGeometry.x(ofTick: line, ticksPerPoint: ticksPerPoint),
                           Double(line) / ticksPerPoint, accuracy: 1e-9, "bar \(index + 1)")
        }
        let third = TimelineGeometry.x(ofTick: meter.tick(ofBar: 2), ticksPerPoint: ticksPerPoint)
        let fourth = TimelineGeometry.x(ofTick: meter.tick(ofBar: 3), ticksPerPoint: ticksPerPoint)
        XCTAssertEqual(third, 176, accuracy: 1e-9, "two 4/4 bars before it")
        XCTAssertEqual(fourth - third, 77, accuracy: 1e-9, "a 7/8 bar is seven eighths of a 4/4 bar")
    }

    func testTheZoomIsAParameterAndANonsenseZoomFallsBackOrDrawsAtTheStart() {
        let meter = MeterMap(signature: .common)
        let zoomed = TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: 176)
        XCTAssertEqual(TimelineGeometry.x(ofTick: bar, ticksPerPoint: zoomed), 176, accuracy: 1e-9)
        XCTAssertEqual(TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: .nan),
                       TimelineGeometry.ticksPerPoint(meter: meter))
        XCTAssertEqual(TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: 0),
                       TimelineGeometry.ticksPerPoint(meter: meter))
        XCTAssertEqual(TimelineGeometry.x(ofTick: bar, ticksPerPoint: 0), 0)
        XCTAssertEqual(TimelineGeometry.x(ofPosition: 1_000, ticksPerPoint: .infinity), 0)
    }

    func testTheReadoutCountsBarBeatAndSixteenthFromOne() {
        let common = MeterMap(signature: .common)
        let quarter = MusicalTime.ticksPerQuarter
        XCTAssertEqual(TimelineGeometry.position(at: 0, meter: common).text, "1.1.1")
        XCTAssertEqual(TimelineGeometry.position(at: bar + 2 * quarter, meter: common).text, "2.3.1")
        XCTAssertEqual(TimelineGeometry.position(at: bar + 2 * quarter + 3 * quarter / 4, meter: common).text, "2.3.4")
        XCTAssertEqual(TimelineGeometry.position(at: bar + 2 * quarter + 239, meter: common).text, "2.3.1",
                       "a tick short of the next sixteenth still reads the one it is in")
        XCTAssertEqual(TimelineGeometry.position(at: bar + 2 * quarter, meter: common).spoken, "Bar 2, beat 3")
    }

    func testTheReadoutCountsTheBeatsOfTheMeterWhereThePlayheadIs() {
        let meter = changing
        let eighth = MusicalTime.ticksPerQuarter / 2
        // Bar 3 is the first 7/8 bar: seven beats of an eighth, two sixteenths each.
        XCTAssertEqual(TimelineGeometry.position(at: 2 * bar, meter: meter).text, "3.1.1")
        XCTAssertEqual(TimelineGeometry.position(at: 2 * bar + 6 * eighth, meter: meter).text, "3.7.1")
        XCTAssertEqual(TimelineGeometry.position(at: 2 * bar + 6 * eighth + eighth / 2, meter: meter).text, "3.7.2")
        XCTAssertEqual(TimelineGeometry.position(at: 2 * bar + 7 * eighth, meter: meter).text, "4.1.1")
    }

    func testANegativeOrNotANumberPositionReadsAsTheSongsStart() {
        let meter = MeterMap(signature: .common)
        let ticksPerPoint = TimelineGeometry.ticksPerPoint(meter: meter)
        XCTAssertEqual(TimelineGeometry.tick(clamping: .nan), 0)
        XCTAssertEqual(TimelineGeometry.tick(clamping: -480.5), 0)
        XCTAssertEqual(TimelineGeometry.tick(clamping: -.infinity), 0)
        XCTAssertEqual(TimelineGeometry.tick(clamping: .infinity), MusicalTime.maximumTick)
        XCTAssertEqual(TimelineGeometry.tick(clamping: 1_234.9), 1_234)
        XCTAssertEqual(TimelineGeometry.x(ofPosition: .nan, ticksPerPoint: ticksPerPoint), 0)
        XCTAssertEqual(TimelineGeometry.x(ofPosition: -960, ticksPerPoint: ticksPerPoint), 0)
        XCTAssertEqual(TimelineGeometry.x(ofTick: -960, ticksPerPoint: ticksPerPoint), 0)
        XCTAssertEqual(TimelineGeometry.x(ofPosition: 1_920, ticksPerPoint: ticksPerPoint), 44, accuracy: 1e-9)
        XCTAssertEqual(TimelineGeometry.position(atPosition: .nan, meter: meter).text, "1.1.1")
        XCTAssertEqual(TimelineGeometry.position(atPosition: -12, meter: meter).text, "1.1.1")
        XCTAssertEqual(TimelineGeometry.position(at: -12, meter: meter).text, "1.1.1")
    }
}
