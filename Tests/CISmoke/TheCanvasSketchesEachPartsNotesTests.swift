// TheCanvasSketchesEachPartsNotesTests.swift
// Echoel — modes census 2026-09-26, design slice 11: a part on the Arrange canvas shows its notes.
//
// WHAT THIS PINS. Every block on the canvas was the same grey bar, so two parts of one track
// looked alike and a composer evolve changed nothing on screen. A MIDI part's block now carries
// one short dash per note, along the part and by pitch.
//
// 1. END-TO-END BEHAVIOUR (`ArrangeCanvas.noteMarks`, pure, over real `Note`s): a mark starts
//    and runs where its note does, as a share of the part's length, in start order; the highest
//    note sits at the top and the lowest at the bottom, one shared pitch in the middle; nothing
//    for no notes or no length; a dense part is thinned EVENLY to `maxNoteMarks` — its last
//    mark still near the part's end — and thinning never moves a kept note's height.
// 2. END-TO-END BEHAVIOUR (`noteMarks(for:clip:)`, over real `TimelineRegion`s and `Clip`s):
//    the sketch is the notes the part PLAYS — windowed exactly as `ClipNoteEdit.visibleNotes`
//    windows them for the note editor and the player — and an audio clip, a missing clip and a
//    part whose window is still in seconds sketch nothing.
// 3. SOURCE: the canvas builds each block's marks from the clip grid by that one function and
//    hands them over cold; the block draws them in a `Canvas` overlay UNDER its border, takes
//    no touches through it and hides it from VoiceOver; the block itself still reads no store.
//
// Grading (§0, no Swift toolchain): `NoteMark`, `noteMarks` and `maxNoteMarks` do not exist on
// the parent (`8b28e987d`), so this file does not compile there — every claim is a FORWARD
// guard, one absence (#486). Claims 1-2 transcribed into Python and driven (the thinning over
// 1…1000 notes, the window over a trimmed and an untrimmed part); claim 3 transcribed against
// this tree, with mutants (the sketch overlay moved above the border, the hit-test line
// dropped, the store read inside the block, the marks built from the clip's raw notes): each red.
// Review of c51b1645a added: a fixture whose thinning drops BOTH extreme pitches (MED-1 — the
// span taken over the kept notes was green on the first fixture; red now), the fill and its
// geometry (LOW-9: a loop that never fills, every dash at y = 0 — each red), the editor's own
// window offset in the expected value, and an order check before slicing (LOW-8).
// NOT covered: whether a 2 pt dash in `surface` reads on the `dim` block on glass, and how a
// busy part looks at the smallest lane width — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part with a melody → its block on the canvas
// shows the melody's shape as dark dashes; press, hold and slide it — the dashes move with it;
// trim its start (part bar → Trim) — the dashes of the cut notes disappear; an imported audio
// part stays a plain bar.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCanvasSketchesEachPartsNotesTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    // MARK: 1 — the sketch of a part's notes, pure

    func testEachNoteIsDrawnWhereItPlaysAndByItsPitch() throws {
        let length = 4 * Self.bar
        // Deliberately out of start order: the sketch sorts.
        let notes = [Note(pitch: 64, startTick: Self.bar, lengthTicks: 480),
                     Note(pitch: 72, startTick: 0, lengthTicks: 240),
                     Note(pitch: 60, startTick: 3 * Self.bar, lengthTicks: Self.bar)]
        let marks = ArrangeCanvas.noteMarks(notes, lengthTicks: length)
        XCTAssertEqual(marks.count, 3)
        XCTAssertEqual(marks.map(\.start), [0, 0.25, 0.75], "in start order, as a share of the part")
        XCTAssertEqual(marks[0].length, 240.0 / Double(length), accuracy: 1e-12)
        XCTAssertEqual(marks[2].start + marks[2].length, 1, accuracy: 1e-12, "the last note runs to the end")
        let heights: [Double] = [0, 8.0 / 12.0, 1]   // annotated (#E2)
        XCTAssertEqual(marks.map(\.height), heights, "the highest note on top, the lowest at the bottom")

        let unison = ArrangeCanvas.noteMarks([Note(pitch: 50, startTick: 0, lengthTicks: 10),
                                              Note(pitch: 50, startTick: 100, lengthTicks: 10)],
                                             lengthTicks: Self.bar)
        XCTAssertEqual(unison.map(\.height), [0.5, 0.5], "one shared pitch sits in the middle")
        XCTAssertTrue(ArrangeCanvas.noteMarks([], lengthTicks: Self.bar).isEmpty, "no notes, no sketch")
        XCTAssertTrue(ArrangeCanvas.noteMarks(notes, lengthTicks: 0).isEmpty, "no length, no sketch")
        XCTAssertTrue(ArrangeCanvas.noteMarks(notes, lengthTicks: -Self.bar).isEmpty)
    }

    func testADensePartIsThinnedEvenlyWithoutMovingANote() {
        let limit = ArrangeCanvas.maxNoteMarks
        XCTAssertGreaterThan(limit, 0)
        let counts: [Int] = [1, limit - 1, limit, limit + 1, 2 * limit, 1_000]   // annotated (#E2)
        for count in counts {
            let length = count * 120
            let notes = (0..<count).map { (i: Int) -> Note in
                Note(pitch: 40 + (i * 7) % 29, startTick: i * 120, lengthTicks: 120)
            }
            let marks = ArrangeCanvas.noteMarks(notes, lengthTicks: length)
            XCTAssertLessThanOrEqual(marks.count, limit, "\(count) notes draw at most \(limit) dashes")
            if count <= limit { XCTAssertEqual(marks.count, count, "a part under the limit loses nothing") }
            let last = marks.last?.start ?? -1
            XCTAssertGreaterThanOrEqual(last, 1 - 12.0 / Double(count) - 1e-9,
                                        "\(count) notes: the sketch still reaches the part's end — thinned, not cut")
            // Every kept dash sits at its OWN note's height over the WHOLE part's pitch span.
            let low = notes.map(\.pitch).min() ?? 0, high = notes.map(\.pitch).max() ?? 0
            for mark in marks {
                let index = Int((mark.start * Double(length) / 120).rounded())
                let note = notes[index]
                let expected = high > low ? Double(high - note.pitch) / Double(high - low) : 0.5
                XCTAssertEqual(mark.height, expected, accuracy: 1e-12,
                               "\(count) notes: thinning does not move the note at step \(index)")
            }
        }
        // Review of c51b1645a, MED-1: the loop above keeps both extreme pitches at every count,
        // so a span taken over the KEPT notes passed it too. Here the only highest and the only
        // lowest note sit at ODD indices while the part thins by two — both are dropped, and a
        // kept note's height must still be measured against them.
        let count = 2 * limit
        var notes = (0..<count).map { (i: Int) -> Note in Note(pitch: 60, startTick: i * 120, lengthTicks: 120) }
        notes[1] = Note(pitch: 90, startTick: 120, lengthTicks: 120)
        notes[3] = Note(pitch: 30, startTick: 360, lengthTicks: 120)
        notes[4] = Note(pitch: 70, startTick: 480, lengthTicks: 120)
        let thinned = ArrangeCanvas.noteMarks(notes, lengthTicks: count * 120)
        XCTAssertEqual(thinned.count, limit, "every second note is kept")
        XCTAssertEqual(thinned[0].height, 0.5, accuracy: 1e-12,
                       "pitch 60 in a 30…90 part is the middle — over ALL notes, not the kept ones")
        XCTAssertEqual(thinned[2].height, 20.0 / 60.0, accuracy: 1e-12,
                       "pitch 70 sits a third down from the dropped 90, not at the top")
    }

    // MARK: 2 — the notes the part plays

    func testTheSketchIsTheWindowThePartPlays() {
        let lane = UUID()
        let inside = Note(pitch: 67, startTick: 600, lengthTicks: 480)
        let early = Note(pitch: 55, startTick: 100, lengthTicks: 120)
        let late = Note(pitch: 79, startTick: 3 * Self.bar, lengthTicks: 480)
        let clip = Clip(name: "melody", kind: .midi, melody: MelodyClip(notes: [late, early, inside]))
        let whole = TimelineRegion(laneID: lane, clipID: clip.id, startTick: 0, lengthTicks: 4 * Self.bar)
        let trimmed = TimelineRegion(laneID: lane, clipID: clip.id, startTick: 0, lengthTicks: Self.bar,
                                     contentOffsetTicks: 480)
        for region in [whole, trimmed] {
            // LOW-9: the offset the note editor uses, step alignment included.
            let expected = ArrangeCanvas.noteMarks(
                ClipNoteEdit.visibleNotes(clip.melody?.notes ?? [],
                                          offsetTicks: ClipNoteEdit.windowOffset(of: region) ?? -1,
                                          lengthTicks: region.lengthTicks),
                lengthTicks: region.lengthTicks)
            XCTAssertEqual(ArrangeCanvas.noteMarks(for: region, clip: clip), expected,
                           "the sketch windows the clip exactly as the note editor and the player do")
        }
        XCTAssertEqual(ArrangeCanvas.noteMarks(for: whole, clip: clip).count, 3)
        let cut = ArrangeCanvas.noteMarks(for: trimmed, clip: clip)
        XCTAssertEqual(cut.count, 1, "the trim hides the note before the window and the note after it")
        XCTAssertEqual(cut.first?.start ?? -1, 120.0 / Double(Self.bar), accuracy: 1e-12,
                       "and the kept note sits where the trimmed part plays it")

        let audio = Clip(name: "take", kind: .audio, melody: MelodyClip(notes: [inside]))
        XCTAssertTrue(ArrangeCanvas.noteMarks(for: whole, clip: audio).isEmpty, "an audio part sketches no notes")
        XCTAssertTrue(ArrangeCanvas.noteMarks(for: whole, clip: nil).isEmpty, "a part without its clip sketches nothing")
        let legacy = TimelineRegion(laneID: lane, clipID: clip.id, startTick: 0, lengthTicks: Self.bar,
                                    contentOffsetSeconds: 1.5)
        XCTAssertTrue(ArrangeCanvas.noteMarks(for: legacy, clip: clip).isEmpty,
                      "a window still in seconds is not guessed at — the note editor does not show it either")
    }

    // MARK: 3 — the canvas hands the marks over cold; the block draws them

    func testTheBlockDrawsTheMarksUnderItsBorderAndReadsNoStore() throws {
        let file = try source(Self.canvasPath)
        guard let canvasStart = file.range(of: "struct ArrangeCanvasView: View {"),
              let rulerStart = file.range(of: "struct ArrangeBarRuler: View {"),
              let blockStart = file.range(of: "struct ArrangePartBlock: View {"),
              let pure = file.range(of: "nonisolated static func noteMarks(for region: TimelineRegion, clip: Clip?) -> [NoteMark] {"),
              let pureEnd = file.range(of: "nonisolated static func noteMarks(_ notes: [Note], lengthTicks: Int) -> [NoteMark] {") else {
            return XCTFail("ANCHOR MISSING: the canvas, the ruler, the block or the two `noteMarks` (#454)")
        }
        // LOW-8: a reorder is one named failure, never a range trap that ends the bundle.
        guard canvasStart.upperBound <= rulerStart.lowerBound, pure.upperBound <= pureEnd.lowerBound else {
            return XCTFail("the canvas no longer precedes the ruler, or the two `noteMarks` swapped order — re-anchor (#454)")
        }
        let canvas = String(file[canvasStart.upperBound..<rulerStart.lowerBound])
        let block = String(file[blockStart.upperBound...])
        let window = String(file[pure.upperBound..<pureEnd.lowerBound])

        XCTAssertTrue(window.contains("ClipNoteEdit.windowOffset(of: region)"))
        XCTAssertTrue(window.contains("ClipNoteEdit.visibleNotes(clip.melody?.notes ?? [], offsetTicks: offset,"),
                      "the sketch windows the notes by the note editor's own rule (#416)")

        XCTAssertTrue(canvas.contains("@Environment(ClipStore.self) private var clipStore"))
        // A1b re-anchor: the lane reads each part's clip once into `clips` (the name tag reads the
        // same pass); the claim is unchanged — each part's marks come from ITS clip, via the pure function.
        XCTAssertTrue(canvas.contains(".map { ($0.id, ($0, clipStore.clip(id: $0.clipID))) },"),
                      "each part is paired with its own clip")
        XCTAssertTrue(canvas.contains("let sketches = clips.mapValues { ArrangeCanvas.noteMarks(for: $0.0, clip: $0.1) }"),
                      "each part's marks come from its own clip, through the one pure function")
        XCTAssertEqual(canvas.components(separatedBy: "clipStore.").count - 1, 1,
                       "the canvas reads the clip grid once, to build the sketches")
        XCTAssertTrue(canvas.contains("noteMarks: sketches[block.id] ?? [],"), "and hands each block its own")

        XCTAssertTrue(block.contains("let noteMarks: [ArrangeCanvas.NoteMark]"))
        guard let fill = block.range(of: ".fill(tint.opacity(Self.tintOpacity))"),
              let sketch = block.range(of: ".overlay { noteSketch }"),
              let border = block.range(of: ".overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)") else {
            return XCTFail("ANCHOR MISSING: the block's fill, its sketch overlay or its border (#454)")
        }
        XCTAssertLessThan(fill.lowerBound, sketch.lowerBound)
        XCTAssertLessThan(sketch.lowerBound, border.lowerBound,
                          "the dashes sit UNDER the border — the selection ring stays on top")
        guard let drawer = block.range(of: "private var noteSketch: some View {"),
              let drawerEnd = block.range(of: "private static let dashHeight: CGFloat", range: drawer.upperBound..<block.endIndex) else {
            return XCTFail("ANCHOR MISSING: `noteSketch` or `dashHeight` after it (#454)")
        }
        let drawing = String(block[drawer.upperBound..<drawerEnd.lowerBound])
        XCTAssertTrue(drawing.contains("Canvas { context, size in"))
        XCTAssertTrue(drawing.contains("for mark in noteMarks {"))
        // LOW-9: the dash is FILLED, at the mark's own place and height.
        XCTAssertTrue(drawing.contains("let rect = CGRect(x: CGFloat(mark.start) * size.width,"))
        XCTAssertTrue(drawing.contains("y: CGFloat(mark.height) * (size.height - dash),"))
        XCTAssertTrue(drawing.contains("context.fill(Path(rect), with: .color(tint))"),
                      "the dashes are drawn in the track's own hue, full strength, on its muted body (A1)")
        // Review of 3bab7f277, LOW-11 (tightened in review 11, LOW-3): the fill sits INSIDE the
        // per-mark loop — one dash per mark. The loop body is brace-matched, so a fill before the
        // loop or after its closing brace (one rect for no mark at all) is outside it.
        if let loop = drawing.range(of: "for mark in noteMarks {") {
            var depth = 1
            var end = loop.upperBound
            while end < drawing.endIndex, depth > 0 {
                if drawing[end] == "{" { depth += 1 } else if drawing[end] == "}" { depth -= 1 }
                if depth > 0 { end = drawing.index(after: end) }
            }
            XCTAssertTrue(drawing[loop.upperBound..<end].contains("context.fill(Path(rect),"),
                          "the dash is filled inside the loop over the marks")
        }
        XCTAssertEqual(drawing.components(separatedBy: "context.fill(").count - 1, 1, "one fill: the dash")
        XCTAssertTrue(drawing.contains(".allowsHitTesting(false)"),
                      "a tap or a hold on the dashes reaches the block — select and drag stay whole")
        XCTAssertTrue(drawing.contains(".accessibilityHidden(true)"), "the block speaks for the part")
        for banned in ["clipStore", "ClipStore", "TimelineStore", "timeline", "@State"] {
            XCTAssertFalse(block.contains(banned), "`ArrangePartBlock` contains `\(banned)` — it draws the marks it is handed")
        }
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
