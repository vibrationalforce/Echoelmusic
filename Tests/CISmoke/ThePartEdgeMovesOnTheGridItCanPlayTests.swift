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
// ⚠️ THE LIMIT (AE-4a). A rule nobody calls proves nothing about a gesture; claims 1–3 prove that
// the rule a gesture asks is right.
//
// ⭐ AE-4b (2026-10-08) IS THE CALLER: the audio editor's two edge handles (`AudioPartEdgeHandles`
// in `Studio/AudioPartEditorView.swift`). Claims 4–8 pin it:
// 4. END-TO-END — the grid a handle snaps to is `snapUnit` at the editor's own scale
//    (`AudioPartEditor.snapZoom`: touch targets per bar on a pane that draws the whole file), and
//    a slide converts to ticks at the tempo the part's media elapses at.
// 5. END-TO-END — `AudioPartEditor.edgeEdit`, the ONE function preview and release both ask:
//    inward edges stay inside the part and pass `onlyLetsGo`; an outward start bottoms out on the
//    first grid line inside the file and is REFUSED (not walked back) when it would take a bar —
//    including the tie case that makes start legality non-monotone; an outward end stops at the
//    file's end and is refused over an earlier part that still plays.
// 6. END-TO-END — the preview line's place on the file, and the handles' 44-pt touch areas.
// 7. SOURCE-TEXT SCAN — one write per gesture: `trimRegionStart` and `resizeRegion` once each in
//    the file, both inside `.onEnded`, none while the finger moves; one `@GestureState`; hold
//    first (0.3 s, the canvas's); the grid comes from `snapUnit` alone.
// 8. SOURCE-TEXT SCAN — the stale "nothing in this build can trim a part" is gone from
//    `AudioWarp.swift`.
//
// ⚠️ HONEST GRADING FOR 4–8 (#433), against the parent of the AE-4b commit: claims 4–6 drive
// `AudioPartEditor.snapZoom`, `draggedTick`, `edgeEdit`, `edgeFraction` and `handleFrames`, which
// this commit creates, so the FILE no longer compiles against the parent and no assertion — 1–3
// included — has a verdict there. Every expectation in 4–6 was derived in Python from the rules as
// written (`activeRegion`, `candidateSampleTicks`, `trimmedStart`, `onlyLetsGo`, `keepsWhoPlays`,
// `endFitsMedia`) before it was typed here (#442). Claims 4–7 are FORWARD (one absence, #486); claim
// 8 is a REGRESSION guard (red on the parent by transcription: the sentence is there). Stripper
// for 7: TRAGEND, 3 of 18 verdicts flip — the file's prose names `trimRegionStart(`,
// `resizeRegion(` and `@GestureState` too, so the raw counts read 2, 2 and 2 against code-only
// 1, 1 and 1. Claim 8 reads the RAW file on purpose: the defect it guards is prose. All 18 claim-7
// verdicts and both claim-8 verdicts were driven in Python on the worktree (green) and the parent
// (anchor absent for 7; claim 8 red). What a hold-and-slide FEELS like on a phone — whether the page's
// scroll yields to the hold, whether 44 pt is enough at the file's first second — is a DEVICE
// PROBE and open.

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

    // MARK: 4 — the editor's grid and the slide's ticks (AE-4b)

    func testTheEditorSnapsToTheFinestGridAFingerCanHit() throws {
        // At 120 BPM a bar is 2 s. An 8-s file over 352 pt is 44 pt a second: a bar is 88 pt,
        // two targets — the bar grid. Four times wider, a beat is a target wide; sixteen, a step.
        XCTAssertEqual(AudioPartEditor.snapZoom(widthPoints: 352, fileSeconds: 8, mediaBPM: 120), 2)
        XCTAssertEqual(AudioPartEditor.snapZoom(widthPoints: 1_408, fileSeconds: 8, mediaBPM: 120), 8)
        XCTAssertEqual(AudioPartEditor.snapZoom(widthPoints: 5_632, fileSeconds: 8, mediaBPM: 120), 32)
        var units: [Int] = []
        for width: Double in [352, 1_408, 5_632] {
            let zoom = try XCTUnwrap(AudioPartEditor.snapZoom(widthPoints: width, fileSeconds: 8, mediaBPM: 120))
            units.append(PartTrim.snapUnit(zoom: zoom))
        }
        XCTAssertEqual(units, [Self.bar, Self.beat, Self.step], "the grid is `snapUnit`'s, at the editor's own scale")
        // The media tempo decides: a warped part whose media elapses at 60 BPM has 4-s bars, so the
        // same pane is four targets per bar and snaps to beats.
        XCTAssertEqual(AudioPartEditor.snapZoom(widthPoints: 352, fileSeconds: 8, mediaBPM: 60), 4)
        let unusable: [(Double, Double, Double)] = [(0, 8, 120), (.nan, 8, 120), (352, 0, 120),
                                                    (352, .infinity, 120), (352, 8, 0), (352, 8, .nan)]
        for (width, seconds, bpm) in unusable {
            XCTAssertNil(AudioPartEditor.snapZoom(widthPoints: width, fileSeconds: seconds, mediaBPM: bpm),
                         "an unusable pane \(width) pt / \(seconds) s / \(bpm) BPM has no grid")
        }
        // A slide is file seconds on this pane, then ticks at the media tempo: 44 pt = 1 s = 960.
        XCTAssertEqual(AudioPartEditor.draggedTick(from: 0, dragPoints: 44, widthPoints: 352,
                                                   fileSeconds: 8, mediaBPM: 120), 960)
        XCTAssertEqual(AudioPartEditor.draggedTick(from: 0, dragPoints: -22, widthPoints: 352,
                                                   fileSeconds: 8, mediaBPM: 120), -480)
        XCTAssertNil(AudioPartEditor.draggedTick(from: 0, dragPoints: .nan, widthPoints: 352,
                                                 fileSeconds: 8, mediaBPM: 120))
        XCTAssertNil(AudioPartEditor.draggedTick(from: .max, dragPoints: 44, widthPoints: 352,
                                                 fileSeconds: 8, mediaBPM: 120), "an overflowing edge is no edge")
    }

    // MARK: 5 — what a released slide writes (AE-4b)

    func testASlideMovesAnEdgeOnlyWhereTheRulesLetIt() {
        // An 8-s file over 352 pt snaps to bars (88 pt each); over 1 408 pt, to beats.
        let fine = 1_408.0
        func edit(_ edge: AudioPartEditor.Edge, _ points: Double, _ part: TimelineRegion,
                  _ regions: [TimelineRegion], width: Double = 352) -> AudioPartEditor.EdgeEdit? {
            AudioPartEditor.edgeEdit(edge, dragPoints: points, widthPoints: width, region: part,
                                     in: TimelineDocument(lanes: [], regions: regions),
                                     fileSeconds: 8, mediaBPM: 120)
        }

        // A plays bars 2…3 from one second into the file (1…3 s of 8).
        let a = region(2 * Self.bar, Self.bar, offsetSeconds: 1)
        // END, OUTWARD — one bar out over silence; then a long slide stops at the file's end:
        // three bars from 1 s reach 7 s, four would reach 9 s of an 8-s file.
        XCTAssertEqual(edit(.end, 88, a, [a]), .end(lengthTicks: 2 * Self.bar))
        XCTAssertEqual(edit(.end, 400, a, [a]), .end(lengthTicks: 3 * Self.bar),
                       "the end stops at the last grid line inside the file")
        // ...and is refused over a part that started earlier and still plays there: A, the later
        // start, would take bar 3 from it at the very first grid line.
        let d = region(0, 6 * Self.bar)
        XCTAssertNil(edit(.end, 88, a, [d, a]), "an end never takes a bar from an earlier part")
        // A part that starts LATER keeps its bars — the extension passes under it.
        let b = region(4 * Self.bar, Self.bar)
        XCTAssertEqual(edit(.end, 176, a, [a, b]), .end(lengthTicks: 3 * Self.bar))

        // START, OUTWARD — the file starts 1 s (half a bar) before A. On the bar grid there is no
        // line inside the file before bar 2: refused. On the beat grid the start bottoms out at
        // the file's first second, bar 1.5, and the part then plays its file from 0 s.
        XCTAssertNil(edit(.start, -88, a, [a]), "no bar line between the file's start and the part's")
        XCTAssertEqual(edit(.start, -352, a, [a], width: fine), .start(tick: 2 * Self.bar - 2 * Self.beat))
        let trimmed = a.trimmedStart(toTick: 2 * Self.bar - 2 * Self.beat, bpm: 120)
        XCTAssertEqual(trimmed?.contentOffsetSeconds ?? -1, 0, accuracy: 1e-9, "the file's first second")

        // ...and REFUSED, not walked back, when it would take a bar. A4 plays from 4 s into the
        // file, so bars 0…1 of file lie before it. C plays bar 1 and was placed first.
        let a4 = region(2 * Self.bar, Self.bar, offsetSeconds: 4)
        XCTAssertEqual(edit(.start, -88, a4, [a4]), .start(tick: Self.bar))
        let c = region(Self.bar, Self.bar)
        XCTAssertNil(edit(.start, -88, a4, [c, a4]), """
            a start moved onto C's TIES it, a tie goes to the later placement (A), and C loses bar 1
            """)
        XCTAssertEqual(edit(.start, -176, a4, [c, a4]), .start(tick: 0), """
            two bars back the start passes UNDER C (C now starts later and keeps bar 1) — legal again,
            which is why start legality is not monotone and a refused slide is not walked back
            """)

        // INWARD — both edges stay inside the part, however far the finger goes.
        let a2 = region(2 * Self.bar, 2 * Self.bar)
        XCTAssertEqual(edit(.start, 88, a2, [a2]), .start(tick: 3 * Self.bar))
        XCTAssertEqual(edit(.start, 500, a2, [a2]), .start(tick: 3 * Self.bar), "the start stops a grid line before the end")
        XCTAssertEqual(edit(.end, -88, a2, [a2]), .end(lengthTicks: Self.bar))
        XCTAssertEqual(edit(.end, -1_000, a2, [a2]), .end(lengthTicks: Self.bar), "the end stops a grid line after the start")
        // An inward start that would TIE a later part and win it is refused (`onlyLetsGo`).
        let x = region(3 * Self.bar, Self.bar)
        XCTAssertNil(edit(.start, 88, a2, [x, a2]), "a trim never takes a bar either")

        // No slide, an unknown part: no edit.
        XCTAssertNil(edit(.start, 0, a2, [a2]))
        XCTAssertNil(edit(.end, 0, a2, [a2]))
        XCTAssertNil(edit(.end, 88, a, [a2]), "a part that is not in the arrangement is not edited")
    }

    // MARK: 6 — the preview's place and the touch areas (AE-4b)

    func testThePreviewSitsWhereTheEdgeLandsAndEachHandleIsATarget() throws {
        let a = region(2 * Self.bar, Self.bar, offsetSeconds: 1)
        let window = ArrangeCanvas.AudioWindow(mediaRef: "a.wav", fromSeconds: 1, lengthSeconds: 2, gain: 1,
                                               fadeIn: 0, fadeOut: 0)
        // The start moved back half a bar sits at the file's 0 s; the end three bars long at 7 of 8 s.
        XCTAssertEqual(AudioPartEditor.edgeFraction(.start(tick: 2 * Self.bar - 2 * Self.beat), region: a,
                                                    window: window, fileSeconds: 8, mediaBPM: 120) ?? -1,
                       0, accuracy: 1e-12)
        XCTAssertEqual(AudioPartEditor.edgeFraction(.end(lengthTicks: 3 * Self.bar), region: a,
                                                    window: window, fileSeconds: 8, mediaBPM: 120) ?? -1,
                       0.875, accuracy: 1e-12)
        XCTAssertNil(AudioPartEditor.edgeFraction(.end(lengthTicks: Self.bar), region: a, window: window,
                                                  fileSeconds: 0, mediaBPM: 120))

        let hit = AudioPartEditor.handleHitPoints
        XCTAssertEqual(hit, 44, "the platform's touch target")
        func frames(_ start: Double, _ end: Double, _ width: Double) throws -> [ClosedRange<Double>] {
            let pair = try XCTUnwrap(AudioPartEditor.handleFrames(startX: start, endX: end, width: width))
            return [pair.start, pair.end]
        }
        // Apart: each centred on its edge.
        XCTAssertEqual(try frames(44, 132, 352), [22...66, 110...154])
        // Narrower than a target: pushed apart around the middle, touching, never sharing a point.
        XCTAssertEqual(try frames(100, 110, 352), [61...105, 105...149])
        // At the file's first and last second: kept inside the pane, whose clip would cut them.
        XCTAssertEqual(try frames(0, 10, 352), [0...44, 44...88])
        XCTAssertEqual(try frames(350, 352, 352), [264...308, 308...352])
        for pair in [(44.0, 132.0), (100, 110), (0, 10), (350, 352), (0, 352), (176, 176)] {
            let both = try frames(pair.0, pair.1, 352)
            for range in both {
                XCTAssertEqual(range.upperBound - range.lowerBound, hit, accuracy: 1e-9, "every handle is a full target")
                XCTAssertGreaterThanOrEqual(range.lowerBound, 0)
                XCTAssertLessThanOrEqual(range.upperBound, 352)
            }
            XCTAssertLessThanOrEqual(both[0].upperBound, both[1].lowerBound, "the two handles never overlap")
        }
        XCTAssertNil(AudioPartEditor.handleFrames(startX: 10, endX: 20, width: 80), "no room for two targets")
        XCTAssertNil(AudioPartEditor.handleFrames(startX: 20, endX: 10, width: 352))
        XCTAssertNil(AudioPartEditor.handleFrames(startX: .nan, endX: 10, width: 352))
    }

    // MARK: 7 — SOURCE: one write per gesture, the grid from `snapUnit` alone (AE-4b)

    func testTheHandlesWriteOnceOnReleaseAndSnapThroughTheOneRule() throws {
        let code = try source(Self.editorPath)
        XCTAssertEqual(Self.occurrences(of: "trimRegionStart(", in: code), 1, "one start writer in the editor")
        XCTAssertEqual(Self.occurrences(of: "resizeRegion(", in: code), 1, "one end writer in the editor")
        XCTAssertEqual(Self.occurrences(of: "@GestureState", in: code), 1, "the slide is the editor's one finger-rate state")
        guard let handles = Self.bracedBody(after: "private struct AudioPartEdgeHandles: View {", in: code),
              let ended = Self.bracedBody(after: ".onEnded {", in: handles),
              let moving = Self.bracedBody(after: ".updating($drag) {", in: handles) else {
            return XCTFail("ANCHOR MISSING: `AudioPartEdgeHandles`, its `.onEnded` or its `.updating` (#408)")
        }
        for write in ["timeline.trimRegionStart(id: region.id, toTick: tick, bpm: mediaBPM)",
                      "timeline.resizeRegion(id: region.id, lengthTicks: lengthTicks)"] {
            XCTAssertTrue(ended.contains(write), "the release writes `\(write)` — and only the release")
        }
        XCTAssertFalse(moving.contains("timeline"), """
            The slide touches the store while the finger moves. A write per frame is a write per \
            Undo step per frame; the edge is written once, on release.
            """)
        XCTAssertTrue(handles.contains("LongPressGesture(minimumDuration: 0.3)\n            .sequenced(before: DragGesture(minimumDistance: 0))"),
                      "hold first (the canvas's 0.3 s), so a swipe on the wave still scrolls the page")
        // The preview and the release ask the same question.
        guard let ask = Self.bracedBody(after: "private func edit(_ edge: AudioPartEditor.Edge, points: Double, width: Double) -> AudioPartEditor.EdgeEdit? {", in: handles) else {
            return XCTFail("ANCHOR MISSING: the handles' one question (#408)")
        }
        XCTAssertTrue(ask.contains("AudioPartEditor.edgeEdit("))
        XCTAssertEqual(Self.occurrences(of: "AudioPartEditor.edgeEdit(", in: code), 1, "asked in one place")
        XCTAssertTrue(ended.contains("edit(edge, points: Double(slide.translation.width), width: width)"))
        XCTAssertTrue(handles.contains("if let landing = edit(drag.edge, points: drag.points, width: width)"))
        // The grid is `snapUnit`'s and the rules are `PartTrim`'s — nothing here picks its own.
        guard let rule = Self.bracedBody(after: "fileSeconds: Double, mediaBPM: Double) -> EdgeEdit? {", in: code) else {
            return XCTFail("ANCHOR MISSING: `AudioPartEditor.edgeEdit` (#408)")
        }
        for asked in ["PartTrim.snapUnit(zoom: zoom)", "PartTrim.onlyLetsGo(", "PartTrim.keepsWhoPlays(",
                      "PartTrim.endFitsMedia(", "region.trimmedStart(toTick: 0, bpm: mediaBPM)"] {
            XCTAssertTrue(rule.contains(asked), "the edge rule no longer asks `\(asked)`")
        }
        for grid in ["ticksPerBeat", "ticksPerTransportStep"] {
            XCTAssertFalse(code.contains(grid), """
                The editor names `\(grid)` — a second grid. The handle snaps to `PartTrim.snapUnit` \
                and nothing else (#416).
                """)
        }
    }

    // MARK: 8 — the stale prose that said nothing could trim a part

    func testTheWarpSwitchNoLongerSaysNothingTrimsAPart() throws {
        let raw = try rawSource(Self.warpPath)
        XCTAssertFalse(raw.contains("Nothing in this build can trim a"), """
            `AudioWarp.swift` still says nothing in this build can trim a part. The part bar's Trim \
            buttons and, since AE-4b, the editor's edge handles do — the reason a trimmed window \
            keeps its length is that people make them.
            """)
        XCTAssertTrue(raw.contains("ONLY A WHOLE-FILE PART IS RESIZED"), "the rule itself stays")
    }

    // MARK: - Helpers

    private static let editorPath = "Sources/Echoelmusic/Studio/AudioPartEditorView.swift"
    private static let warpPath = "Sources/Echoelmusic/Sequencer/AudioWarp.swift"

    static func bracedBody(after head: String, in code: String) -> String? {
        guard let start = code.range(of: head), head.hasSuffix("{") else { return nil }
        var depth = 0
        var i = code.index(before: start.upperBound)   // the opening brace
        while i < code.endIndex {
            if code[i] == "{" {
                depth += 1
            } else if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<i]) }
            }
            i = code.index(after: i)
        }
        return nil
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func rawSource(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present under \(dir.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}
