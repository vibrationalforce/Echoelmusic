import XCTest
@testable import EchoelCore

final class ArrangeZoomTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)
    private let levels: [Double] = [0.25, 0.5, 1, 1.5, 2, 4, 8]
    /// Two bars of 4/4, then 7/8 from bar 3 on.
    private var changing: MeterMap {
        MeterMap(signature: .common, changes: [TimeSignatureChange(tick: 2 * bar, signature: TimeSignature(7, 8))])
    }

    func testATickSitsAtTheSameXInTheRulerAndTheLaneAtEveryZoomLevel() {
        let meter = changing
        for level in levels {
            let ticksPerPoint = ArrangeZoom.ticksPerPoint(level, meter: meter)
            let width = 88 * level
            // The ruler's bar lines: two 4/4 bars, then 7/8 bars, each as wide as its ticks.
            var expected = 0.0
            for index in Int64(0)...5 {
                let line = meter.tick(ofBar: index)
                XCTAssertEqual(TimelineGeometry.x(ofTick: line, ticksPerPoint: ticksPerPoint), expected,
                               accuracy: 1e-9, "bar \(index + 1) at zoom \(level)")
                expected += width * Double(meter.ticksPerBar(at: line)) / Double(bar)
            }
            // A block in a lane starting on any tick sits where the ruler draws that tick, and a
            // touch on that x names the same tick again.
            for tick in [Tick(0), 1, 479, bar, 2 * bar + 240, 5 * bar + 7] {
                let x = TimelineGeometry.x(ofTick: tick, ticksPerPoint: ticksPerPoint)
                XCTAssertEqual(TimelineGeometry.tick(atX: x, ticksPerPoint: ticksPerPoint, snap: .off, meter: meter),
                               tick, "tick \(tick) at zoom \(level)")
            }
        }
    }

    func testADragOfNPointsSpansNTimesTicksPerPointAndHalfAsFarAtTwiceTheZoom() {
        let meter = MeterMap(signature: .common)
        for level in levels {
            let ticksPerPoint = ArrangeZoom.ticksPerPoint(level, meter: meter)
            for points in [0.0, 1, 13, 88, -40, 333.5] {
                XCTAssertEqual(ArrangeZoom.ticks(dragged: points, ticksPerPoint: ticksPerPoint),
                               Tick((points * ticksPerPoint).rounded()), "\(points) pt at zoom \(level)")
            }
        }
        XCTAssertEqual(ArrangeZoom.ticks(dragged: 88, ticksPerPoint: ArrangeZoom.ticksPerPoint(1, meter: meter)), bar)
        XCTAssertEqual(ArrangeZoom.ticks(dragged: 88, ticksPerPoint: ArrangeZoom.ticksPerPoint(2, meter: meter)), bar / 2)
        XCTAssertEqual(ArrangeZoom.ticks(dragged: .nan, ticksPerPoint: 10), 0)
        XCTAssertEqual(ArrangeZoom.ticks(dragged: 10, ticksPerPoint: 0), 0)
        XCTAssertEqual(ArrangeZoom.ticks(dragged: .infinity, ticksPerPoint: 10), 0)
        XCTAssertEqual(ArrangeZoom.ticks(dragged: 1e300, ticksPerPoint: 10), MusicalTime.maximumTick)
    }

    func testThePreviewOfADragLandsWhereTheDropCommitsAtEveryZoomAndMagnet() {
        let meter = changing
        let track = Track(name: "Keys", kind: .instrument)
        for level in levels {
            let ticksPerPoint = ArrangeZoom.ticksPerPoint(level, meter: meter)
            for snap in [SnapGrid.off, .bar, .beat, .sixteenth, .eighthTriplet] {
                for start in [Tick(0), bar + 120, 3 * bar] {
                    let placement = Placement(clip: ClipID(), start: start)
                    for points in [5.0, 30, 61.7, -12, 200] {
                        let preview = ArrangeZoom.previewPoints(from: start, dragged: points, ticksPerPoint: ticksPerPoint,
                                                                snap: snap, meter: meter)
                        let shown = start + Tick((preview * ticksPerPoint).rounded())
                        let delta = ArrangeZoom.ticks(dragged: points, ticksPerPoint: ticksPerPoint)
                        let dropped: Tick
                        if case let .movePlacement(_, _, target)? = Arranging.moved(placement, in: track, byTicks: delta,
                                                                                     meter: meter, snap: snap) {
                            dropped = target
                        } else {
                            dropped = start
                        }
                        XCTAssertEqual(shown, dropped, "\(points) pt from \(start), \(snap), zoom \(level)")
                    }
                }
            }
        }
    }

    func testTheStoredLevelIsHeldToItsRangeAndNonsenseReadsAsTheStandardZoom() {
        for nonsense in [Double.nan, .infinity, -.infinity, 0, -2] {
            XCTAssertEqual(ArrangeZoom.level(nonsense), ArrangeZoom.base, "\(nonsense)")
            XCTAssertEqual(ArrangeZoom.ticksPerPoint(nonsense, meter: MeterMap(signature: .common)),
                           TimelineGeometry.ticksPerPoint(meter: MeterMap(signature: .common)))
        }
        XCTAssertEqual(ArrangeZoom.level(100), ArrangeZoom.range.upperBound)
        XCTAssertEqual(ArrangeZoom.level(0.01), ArrangeZoom.range.lowerBound)
        XCTAssertEqual(ArrangeZoom.pointsPerBar(2), 176, accuracy: 1e-9)

        // A pinch multiplies; a pinch that reports nothing usable leaves the level alone.
        XCTAssertEqual(ArrangeZoom.zoomed(1, by: 1.5), 1.5, accuracy: 1e-12)
        XCTAssertEqual(ArrangeZoom.zoomed(2, by: .nan), 2)
        XCTAssertEqual(ArrangeZoom.zoomed(2, by: 0), 2)
        XCTAssertEqual(ArrangeZoom.zoomed(4, by: 10), ArrangeZoom.range.upperBound)

        // The buttons step by two and stop at the ends.
        XCTAssertEqual(ArrangeZoom.zoomedIn(1), 2)
        XCTAssertEqual(ArrangeZoom.zoomedOut(1), 0.5)
        XCTAssertEqual(ArrangeZoom.zoomedIn(8), 8)
        XCTAssertEqual(ArrangeZoom.zoomedOut(0.25), 0.25)
        XCTAssertFalse(ArrangeZoom.canZoomIn(8))
        XCTAssertTrue(ArrangeZoom.canZoomIn(4))
        XCTAssertFalse(ArrangeZoom.canZoomOut(0.25))
        XCTAssertTrue(ArrangeZoom.canZoomOut(.nan), "a broken level reads as the standard zoom")
        XCTAssertEqual(ArrangeZoom.spoken(2), "200 percent")
    }
}
