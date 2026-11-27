import XCTest
@testable import EchoelCore

/// Where the arrangement's lanes scroll to: the page the follower turns while the song plays, and
/// the place Arrange opens on when the musician comes back to it.
final class ArrangePagingTests: XCTestCase {
    /// A scale with whole numbers: ten ticks a point.
    private let perPoint = 10.0
    /// A phone's lanes: 300 pt wide, so a tenth of them is 30 pt.
    private let width = 300.0
    /// Lanes long enough that no test reaches their end unless it means to.
    private let content = 100_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    /// The position in ticks that sits `x` points along the lanes at `perPoint`.
    private func at(_ x: Double) -> Double { x * perPoint }

    /// The standard zoom of a 4/4 song: a bar is `TimelineGeometry.pointsPerBar` (88 pt) wide.
    private var standard: Double {
        ArrangeZoom.ticksPerPoint(ArrangeZoom.base, meter: MeterMap(signature: .common))
    }

    /// The first tick of bar `number`, counted from 1, in 4/4.
    private func barStart(_ number: Tick) -> Tick { (number - 1) * bar }

    /// Where Arrange opens at the standard zoom in a phone's lanes, the song stopped and Follow
    /// Playhead on — the default state.
    private func openingStopped(leftAt left: Tick, playheadWhenLeft: Tick?, restingAt resting: Tick) -> Double {
        ArrangePaging.opening(leftEdge: left, playheadWhenLeft: playheadWhenLeft, restingAt: resting, playing: false,
                              follows: true, ticksPerPoint: standard, width: width, contentWidth: content)
    }

    // MARK: - Following while the song plays

    func testAPlayheadInsideTheViewTurnsNoPage() {
        XCTAssertNil(ArrangePaging.target(showing: at(100), ticksPerPoint: perPoint, left: 0, width: width))
        XCTAssertNil(ArrangePaging.target(showing: at(270), ticksPerPoint: perPoint, left: 0, width: width),
                     "the last tenth begins at 270")
        XCTAssertNil(ArrangePaging.target(showing: at(880), ticksPerPoint: perPoint, left: 880, width: width),
                     "on the left edge it shows")
    }

    func testNearTheRightEdgeThePageTurnsSoThePlayheadStandsATenthInFromTheLeft() {
        XCTAssertEqual(ArrangePaging.target(showing: at(280), ticksPerPoint: perPoint, left: 0, width: width), 250)
        XCTAssertEqual(ArrangePaging.target(showing: at(1_160), ticksPerPoint: perPoint, left: 880, width: width), 1_130)
    }

    func testAPlayheadThatJumpedPastTheRightEdgeIsPagedTo() {
        XCTAssertEqual(ArrangePaging.target(showing: at(2_000), ticksPerPoint: perPoint, left: 0, width: width), 1_970,
                       "a locate far ahead")
    }

    func testAPlayheadLeftOfTheViewPagesBackAndNeverBeforeTheStart() {
        XCTAssertEqual(ArrangePaging.target(showing: at(500), ticksPerPoint: perPoint, left: 880, width: width), 470)
        XCTAssertEqual(ArrangePaging.target(showing: at(10), ticksPerPoint: perPoint, left: 880, width: width), 0,
                       "a loop's wrap to bar 1 shows bar 1 at the edge")
    }

    func testNoWidthOrNoScaleTurnsNoPage() {
        XCTAssertNil(ArrangePaging.target(showing: at(2_000), ticksPerPoint: perPoint, left: 0, width: 0),
                     "before the first layout the lanes have no width")
        XCTAssertNil(ArrangePaging.target(showing: at(2_000), ticksPerPoint: perPoint, left: 0, width: .nan))
        XCTAssertNil(ArrangePaging.target(showing: at(2_000), ticksPerPoint: 0, left: 0, width: width))
        XCTAssertNil(ArrangePaging.target(showing: at(2_000), ticksPerPoint: .infinity, left: 0, width: width))
        XCTAssertNil(ArrangePaging.target(showing: at(2_000), ticksPerPoint: perPoint, left: .nan, width: width))
    }

    /// The playhead line draws a position that is not a number at the start (`TimelineGeometry`),
    /// so the page shows the line where it is drawn.
    func testAPositionThatIsNotANumberIsPagedToWhereTheLineDrawsIt() {
        XCTAssertEqual(ArrangePaging.target(showing: .nan, ticksPerPoint: perPoint, left: 880, width: width), 0)
        XCTAssertNil(ArrangePaging.target(showing: .nan, ticksPerPoint: perPoint, left: 0, width: width))
    }

    // MARK: - Opening where it was left

    func testPlayingItOpensWhereItWasLeft() {
        for before in [nil, 0, 25_000] as [Tick?] {
            XCTAssertEqual(ArrangePaging.opening(leftEdge: 8_800, playheadWhenLeft: before, restingAt: 0, playing: true,
                                                 follows: true, ticksPerPoint: perPoint, width: width,
                                                 contentWidth: content), 880,
                           "the follower pages to the playhead from there")
        }
    }

    /// A88-5 in the default state: Follow on, nothing cued, the musician works at bar 9, looks at
    /// the Mixer and comes back. The playhead stood on bar 1 when Arrange was left and stands there
    /// still, so bar 9 opens although bar 1 is out of sight from it.
    func testStoppedWithThePlayheadWhereItStoodItOpensWhereItWasLeft() {
        XCTAssertEqual(openingStopped(leftAt: barStart(9), playheadWhenLeft: 0, restingAt: 0), 704, accuracy: 1e-6,
                       "bar 9")
        XCTAssertEqual(openingStopped(leftAt: barStart(30), playheadWhenLeft: 0, restingAt: 0),
                       29 * TimelineGeometry.pointsPerBar, accuracy: 1e-6, "bar 30")
        XCTAssertEqual(openingStopped(leftAt: barStart(9), playheadWhenLeft: barStart(5), restingAt: barStart(5)), 704,
                       accuracy: 1e-6, "a cue at bar 5 that stayed where it was")
    }

    /// While Arrange was away the playhead moved — a locate on another view, or a Stop there after
    /// the song played on — so it opens on where Play now starts: the page the follower would turn.
    func testAPlayheadThatMovedWhileArrangeWasAwayOpensOnWherePlayStarts() {
        let twentieth = 19 * TimelineGeometry.pointsPerBar - width * ArrangePaging.leadIn
        XCTAssertEqual(openingStopped(leftAt: barStart(9), playheadWhenLeft: 0, restingAt: barStart(20)), twentieth,
                       accuracy: 1e-6, "the cue moved to bar 20")
        XCTAssertEqual(openingStopped(leftAt: barStart(9), playheadWhenLeft: barStart(12) + 480, restingAt: 0), 0,
                       "left while it played bar 12, stopped back at bar 1 in the Mixer")
    }

    func testAPlayheadThatMovedButShowsFromTheKeptPlaceOpensThere() {
        XCTAssertEqual(openingStopped(leftAt: barStart(9), playheadWhenLeft: 0, restingAt: barStart(10)), 704,
                       accuracy: 1e-6, "bar 10 is in sight from bar 9")
    }

    /// Before Arrange was ever left in the window nothing is kept: it opens at bar 1, or on where
    /// Play starts when that is out of sight from bar 1.
    func testWithNothingKeptItOpensOnWherePlayStartsWhenThatIsOutOfSight() {
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 0, playheadWhenLeft: nil, restingAt: 0, playing: false,
                                             follows: true, ticksPerPoint: perPoint, width: width,
                                             contentWidth: content), 0)
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 0, playheadWhenLeft: nil, restingAt: 25_000, playing: false,
                                             follows: true, ticksPerPoint: perPoint, width: width,
                                             contentWidth: content), 2_470,
                       "a tenth in from the left")
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 0, playheadWhenLeft: nil, restingAt: 2_800, playing: false,
                                             follows: true, ticksPerPoint: perPoint, width: width,
                                             contentWidth: content), 250,
                       "in the last tenth the page turns, as it does while playing")
    }

    func testWithFollowOffItOpensWhereItWasLeftWhereverPlayStarts() {
        for before in [nil, 0, 25_000] as [Tick?] {
            XCTAssertEqual(ArrangePaging.opening(leftEdge: 8_800, playheadWhenLeft: before, restingAt: 0, playing: false,
                                                 follows: false, ticksPerPoint: perPoint, width: width,
                                                 contentWidth: content), 880)
            XCTAssertEqual(ArrangePaging.opening(leftEdge: 0, playheadWhenLeft: before, restingAt: 25_000, playing: false,
                                                 follows: false, ticksPerPoint: perPoint, width: width,
                                                 contentWidth: content), 0)
        }
    }

    func testThePlaceIsKeptAsATickSoTheSameBarOpensAtAnotherZoom() {
        let twice = ArrangeZoom.ticksPerPoint(2, meter: MeterMap(signature: .common))
        let ninth = ArrangePaging.leftEdgeTick(atX: 8 * TimelineGeometry.pointsPerBar, ticksPerPoint: standard)
        XCTAssertEqual(ninth, barStart(9), "the left edge on bar 9")
        let x = ArrangePaging.opening(leftEdge: ninth, playheadWhenLeft: 0, restingAt: 0, playing: false, follows: true,
                                      ticksPerPoint: twice, width: width, contentWidth: content)
        XCTAssertEqual(x, 8 * 2 * TimelineGeometry.pointsPerBar, accuracy: 1e-6, "bar 9 at twice the width of a bar")
    }

    func testAPlaceBeyondTheLanesOpensOnTheirLastPage() {
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 20_000, playheadWhenLeft: 0, restingAt: 0, playing: true,
                                             follows: true, ticksPerPoint: perPoint, width: width, contentWidth: 1_000),
                       700, "the song grew shorter while another view was open")
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 20_000, playheadWhenLeft: 0, restingAt: 0, playing: true,
                                             follows: true, ticksPerPoint: perPoint, width: width, contentWidth: 200),
                       0, "lanes narrower than the view do not scroll")
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 0, playheadWhenLeft: nil, restingAt: 99_000, playing: false,
                                             follows: true, ticksPerPoint: perPoint, width: width,
                                             contentWidth: 10_000), 9_700,
                       "a page for a cue near the end is held to the last one")
    }

    func testABrokenPlaceOrScaleOpensAtTheStart() {
        XCTAssertEqual(ArrangePaging.opening(leftEdge: -500, playheadWhenLeft: 0, restingAt: 0, playing: true,
                                             follows: true, ticksPerPoint: perPoint, width: width,
                                             contentWidth: content), 0)
        for scale in [0, -1, Double.nan, .infinity] {
            XCTAssertEqual(ArrangePaging.opening(leftEdge: 8_800, playheadWhenLeft: nil, restingAt: 25_000,
                                                 playing: false, follows: true, ticksPerPoint: scale, width: width,
                                                 contentWidth: content), 0, "\(scale)")
        }
    }

    func testWithoutAWidthItOpensWhereItWasLeft() {
        for shown in [0, -10, Double.nan] {
            XCTAssertEqual(ArrangePaging.opening(leftEdge: 8_800, playheadWhenLeft: nil, restingAt: 0, playing: false,
                                                 follows: true, ticksPerPoint: perPoint, width: shown,
                                                 contentWidth: content), 880,
                           "nothing to judge whether the cue is in sight: \(shown)")
        }
    }

    func testAContentWidthThatIsNotANumberHoldsNothing() {
        XCTAssertEqual(ArrangePaging.opening(leftEdge: 20_000, playheadWhenLeft: 0, restingAt: 0, playing: true,
                                             follows: true, ticksPerPoint: perPoint, width: width, contentWidth: .nan),
                       2_000)
    }

    // MARK: - The ticks kept when Arrange is left

    func testTheLeftEdgeIsKeptAsTheTickItShows() {
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: 880, ticksPerPoint: perPoint), 8_800)
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: 88.04, ticksPerPoint: perPoint), 880, "to the nearest tick")
    }

    func testTheLeftEdgeTickIsNeverBeforeTheStartOrPastTheSong() {
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: -40, ticksPerPoint: perPoint), 0, "a bounce past the start")
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: .nan, ticksPerPoint: perPoint), 0)
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: 880, ticksPerPoint: 0), 0)
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: 880, ticksPerPoint: .nan), 0)
        XCTAssertEqual(ArrangePaging.leftEdgeTick(atX: 1e30, ticksPerPoint: perPoint), MusicalTime.maximumTick)
    }

    /// Stopped, the playhead is heard on its resting tick, so the tick kept is that one exactly and
    /// compares equal to it when the musician comes back.
    func testThePlayheadIsKeptAsTheTickItStandsOn() {
        XCTAssertEqual(ArrangePaging.playheadTick(heard: Double(barStart(9))), barStart(9))
        XCTAssertEqual(ArrangePaging.playheadTick(heard: 1_234.9), 1_234, "playing, the tick it is heard on")
        XCTAssertEqual(ArrangePaging.playheadTick(heard: .nan), 0, "drawn at the start, kept as the start")
        XCTAssertEqual(ArrangePaging.playheadTick(heard: -12), 0)
        XCTAssertEqual(ArrangePaging.playheadTick(heard: 1e30), MusicalTime.maximumTick)
    }

    func testThePlayheadIsReadBackFromItsStorage() {
        XCTAssertNil(ArrangePaging.keptTick(ArrangePaging.nothingKept), "before Arrange was ever left")
        XCTAssertNil(ArrangePaging.keptTick(-40))
        XCTAssertEqual(ArrangePaging.keptTick(0), 0, "bar 1 is a place, not nothing")
        XCTAssertEqual(ArrangePaging.keptTick(30_720), 30_720)
        XCTAssertEqual(ArrangePaging.keptTick(Int.max), MusicalTime.maximumTick)
    }

    /// The whole way round, as the view does it: both ticks kept on leaving and read back on coming
    /// back, the song stopped, Follow on and the playhead where it was — wherever that is.
    func testLeavingAndComingBackOpensOnTheSamePoint() {
        for resting in [Tick(0), 8_800] {
            for x in [0.0, 1, 263, 880, 12_345] {
                let left = ArrangePaging.leftEdgeTick(atX: x, ticksPerPoint: perPoint)
                let stored = Int(clamping: ArrangePaging.playheadTick(heard: Double(resting)))
                XCTAssertEqual(ArrangePaging.opening(leftEdge: left, playheadWhenLeft: ArrangePaging.keptTick(stored),
                                                     restingAt: resting, playing: false, follows: true,
                                                     ticksPerPoint: perPoint, width: width, contentWidth: content),
                               x, accuracy: 0.1, "left at \(x) with the playhead on \(resting)")
            }
        }
    }

    func testThePlaceIsKeptUnderItsOwnKeys() {
        XCTAssertEqual(ArrangePaging.storageKey, "arrange.leftEdgeTick")
        XCTAssertEqual(ArrangePaging.playheadStorageKey, "arrange.playheadTick")
        XCTAssertNotEqual(ArrangePaging.storageKey, ArrangePaging.playheadStorageKey)
    }
}
