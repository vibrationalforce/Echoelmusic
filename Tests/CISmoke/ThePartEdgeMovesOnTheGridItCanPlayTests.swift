// ThePartEdgeMovesOnTheGridItCanPlayTests.swift
// Echoel — GMMW AE-4a (2026-10-08). The rules an edge handle moves by, before any handle exists.
//
// WHAT THIS GUARDS. The part bar's Trim buttons only take material away, one grid step inward,
// and `PartTrim.onlyLetsGo` refuses any tick a part GAINS — by construction. The audio editor's
// edge handles (AE-4b) also move an edge outward, so three pure rules now sit beside the inward
// one in `PartTrim`:
//   · `snapUnit(zoom:)` — the grid a handle snaps to: a bar, a beat, never finer than a step;
//   · `keepsWhoPlays(extending:replacing:in:)` — an outward edge fills silence and never takes a
//     bar from, or gives one up to, another part (#1440: precedence is defined once, in
//     `TimelineScheduling.activeRegion`, and asked here, never rebuilt);
//   · `endFitsMedia(_:mediaSeconds:mediaBPM:)` — an audio part's end stays inside its file.
//
// ⚠️ HONEST GRADING (#433), transcribed against the parent `6481aa7` and the worktree: every
// assertion here is FORWARD. The three functions are new in this commit, so this FILE does not
// compile against the parent's `Sources/` and no assertion has a verdict there; the arithmetic
// was driven in Python against the worktree's rules (#442: expectations from the algebra, not
// from a printed value). END-TO-END BEHAVIOUR over shipped value types throughout.
//
// ⚠️ THE LIMIT. No control calls these rules yet — that is AE-4b, which must call them and
// nothing else for an outward edge. A rule nobody calls proves nothing about a gesture; what this
// file proves is that the rule the gesture will ask is right.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePartEdgeMovesOnTheGridItCanPlayTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerBeat
    private static let step = TimelineTime.ticksPerTransportStep
    private static let lane = UUID()

    private func region(_ start: Int, _ length: Int, offsetSeconds: Double = 0) -> TimelineRegion {
        TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: start, lengthTicks: length,
                       contentOffsetSeconds: offsetSeconds)
    }

    // MARK: 1 — the snap

    func testTheHandleSnapsToABarABeatOrAStepAndNeverFiner() {
        XCTAssertEqual(PartTrim.snapUnit(zoom: 1), Self.bar, "the whole song on screen snaps to bars")
        XCTAssertEqual(PartTrim.snapUnit(zoom: 3.99), Self.bar)
        XCTAssertEqual(PartTrim.snapUnit(zoom: 4), Self.beat, "from zoom 4 a beat is wide enough to hit")
        XCTAssertEqual(PartTrim.snapUnit(zoom: 15.99), Self.beat)
        XCTAssertEqual(PartTrim.snapUnit(zoom: 16), Self.step, "from zoom 16 a step")
        XCTAssertEqual(PartTrim.snapUnit(zoom: 1_000), Self.step, "and never finer than a step")
        let unusable: [Double] = [.nan, .infinity, -.infinity, 0, -2]
        for bad in unusable {
            XCTAssertEqual(PartTrim.snapUnit(zoom: bad), Self.bar, "an unusable zoom \(bad) snaps to the bar")
        }
        // The floor is the transport's own step: a part can start and stop only on one.
        for zoom in stride(from: 0.5, through: 64, by: 0.5) {
            let unit = PartTrim.snapUnit(zoom: zoom)
            XCTAssertGreaterThanOrEqual(unit, Self.step)
            XCTAssertEqual(unit % Self.step, 0, "every snap unit is a whole number of transport steps")
        }
    }

    // MARK: 2 — an outward edge fills silence and takes nothing

    func testAnOutwardEdgeFillsSilenceButTakesNoBar() {
        // A alone: its end moves out over silence → allowed; its start moves earlier → allowed.
        let a = region(2 * Self.bar, Self.bar)
        let alone = TimelineDocument(lanes: [], regions: [a])
        var longer = a
        longer.lengthTicks = 2 * Self.bar
        XCTAssertTrue(PartTrim.keepsWhoPlays(extending: longer, replacing: a.id, in: alone),
                      "an end moved out over silence fills it")
        var earlier = a
        earlier.startTick = Self.bar
        earlier.lengthTicks = 2 * Self.bar
        XCTAssertTrue(PartTrim.keepsWhoPlays(extending: earlier, replacing: a.id, in: alone),
                      "a start moved earlier over silence fills it")

        // B starts at bar 3. A's end moved over bar 3 slides UNDER B: the later start wins, B
        // starts later than A, so B still plays bar 3 and nothing changes hands → allowed.
        let b = region(3 * Self.bar, Self.bar)
        let withB = TimelineDocument(lanes: [], regions: [a, b])
        var underB = a
        underB.lengthTicks = 2 * Self.bar
        XCTAssertTrue(PartTrim.keepsWhoPlays(extending: underB, replacing: a.id, in: withB),
                      "an edge moved under a later part takes nothing from it — the later start still wins")

        // C plays bar 1. A's start moved back to bar 0 passes UNDER C: at bar 1 C (start bar 1)
        // is still the later start and still plays; bar 0 was silence; bar 2 is A's as before.
        let c = region(Self.bar, Self.bar)
        let withC = TimelineDocument(lanes: [], regions: [c, a])
        var overC = a
        overC.startTick = 0
        overC.lengthTicks = 3 * Self.bar
        XCTAssertTrue(PartTrim.keepsWhoPlays(extending: overC, replacing: a.id, in: withC),
                      "a start moved back UNDER an earlier part leaves that part playing")

        // The refusal: D starts at bar 0 and runs to bar 4; A (bar 2) wins bars 2…3 over it.
        // Moving A's start to bar 0 TIES the starts, and a tie goes to the later placement — A —
        // so bars 0…1, which D played, change hands. Refused: an outward edge never takes a bar.
        let d = region(0, 4 * Self.bar)
        let overD = TimelineDocument(lanes: [], regions: [d, a])
        var stealing = a
        stealing.startTick = 0
        stealing.lengthTicks = 3 * Self.bar
        XCTAssertEqual(TimelineScheduling.activeRegion(in: overD, laneID: Self.lane, at: 0)?.id, d.id,
                       "precondition: D is heard at bar 0")
        XCTAssertFalse(PartTrim.keepsWhoPlays(extending: stealing, replacing: a.id, in: overD),
                       "moving A's start onto D's takes bars D played — refused")

        // And the other direction of the same law: an outward edge that GIVES UP a bar. F (start
        // bar 2) plays bar 2 over E (start bar 1). Moving F's start to bar 0 makes E the later
        // start, so E would play bar 2 — F loses a bar it played. Refused.
        let e = region(Self.bar, 3 * Self.bar)
        let f = region(2 * Self.bar, Self.bar)
        let eUnderF = TimelineDocument(lanes: [], regions: [e, f])
        XCTAssertEqual(TimelineScheduling.activeRegion(in: eUnderF, laneID: Self.lane, at: 2 * Self.bar)?.id, f.id,
                       "precondition: F is heard at bar 2")
        var fEarlier = f
        fEarlier.startTick = 0
        fEarlier.lengthTicks = 3 * Self.bar
        XCTAssertFalse(PartTrim.keepsWhoPlays(extending: fEarlier, replacing: f.id, in: eUnderF),
                       "moving F's start before E's hands bar 2 to E — refused")

        XCTAssertFalse(PartTrim.keepsWhoPlays(extending: longer, replacing: UUID(), in: alone),
                       "an unknown part cannot be extended")
    }

    // MARK: 3 — an audio part's end stays inside its file

    func testAnAudioEndStaysInsideItsFile() {
        // At 120 BPM a bar is 2 s. A two-bar part from the file's start reaches 4 s.
        let twoBars = region(0, 2 * Self.bar)
        XCTAssertTrue(PartTrim.endFitsMedia(twoBars, mediaSeconds: 4, mediaBPM: 120),
                      "a part ending exactly at the file's end fits")
        XCTAssertFalse(PartTrim.endFitsMedia(twoBars, mediaSeconds: 3.5, mediaBPM: 120),
                       "a part reaching past the file's end is refused")
        // The media offset counts: one second in, the same part reaches 5 s.
        let offset = region(0, 2 * Self.bar, offsetSeconds: 1)
        XCTAssertFalse(PartTrim.endFitsMedia(offset, mediaSeconds: 4, mediaBPM: 120))
        XCTAssertTrue(PartTrim.endFitsMedia(offset, mediaSeconds: 5, mediaBPM: 120))
        // The tempo the media elapses at decides, not the song's: at 60 BPM two bars are 8 s.
        XCTAssertFalse(PartTrim.endFitsMedia(twoBars, mediaSeconds: 4, mediaBPM: 60))
        XCTAssertTrue(PartTrim.endFitsMedia(twoBars, mediaSeconds: 8, mediaBPM: 60))
        let unusableMedia: [(Double, Double)] = [(.nan, 120), (4, .nan), (0, 120), (4, 0), (-1, 120), (.infinity, 120)]
        for (seconds, bpm) in unusableMedia {
            XCTAssertFalse(PartTrim.endFitsMedia(twoBars, mediaSeconds: seconds, mediaBPM: bpm),
                           "unusable media \(seconds) s at \(bpm) BPM refuses")
        }
    }
}
