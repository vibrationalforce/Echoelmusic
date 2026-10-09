// TheWaveCarriesTheFadesAndTheLevelTests.swift
// Echoel — GMMW AE-5 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.").
// The audio part editor gets the DAW's direct hand on a part's level: pull a fade out of a top
// corner, drag the level line — on a strip above the wave, through the part bar's own writers.
//
// WHAT THIS GUARDS. `AudioPartLevelStrip` draws the part's level envelope (a ramp up over the
// fade-in, the level line, a ramp down over the fade-out) with a grip at each top corner and the
// line between them. A released slide writes ONE store call — `setRegionFades` or
// `setRegionGain`, the calls the part bar's Fade in / Fade out / Part level fields already make —
// asked of the part as the store holds it then. The pure half is `AudioPartLevel`.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR on the pure half: a fade grip follows the finger across the part (one
//      bar spread over 192 points is 10 ticks a point — written from the algebra, #442), never past
//      what the other fade leaves (the fields' `inRange`/`outRange` rule), never below zero; the
//      first `holdStillPoints` of a slide are slack, so a finger that holds still writes nothing
//      (review S3); input that cannot be used writes nothing; the envelope's corner moves exactly
//      as far as the finger beyond the slack; fades that fill the part never cross their corners,
//      so the grips survive (review S2).
//   1b. END-TO-END BEHAVIOUR of the scale (review S1): a part that outlasts its file is measured on
//      its UNCUT window (`AudioPartEditor.partXs`), not on the window the wave cuts at the file's
//      end; its fade-out corner, past the pane, is held at the pane's edge — pulled in, it comes to
//      the finger and the fade starts where the finger is, at the file second the player fades
//      from; pushed out, it writes nothing it did not move.
//   2. END-TO-END BEHAVIOUR on the pure half: the level line follows the finger up and down
//      (unity half-way, the store's ceiling at the top, silence at the bottom), in the field's own
//      0.01 steps, held to `PartGain.range`; a hold — including on a Normalized level off the 0.01
//      grid — writes nothing.
//   3. END-TO-END BEHAVIOUR through the shipped write, on a real `TimelineStore`: a fade slide
//      changes the two fade lengths and NOTHING ELSE on the part (one struct comparison), a level
//      slide only the gain, each ONE Undo step; a hold, or a part on a track the fields would not
//      offer, leaves no Undo step.
//   4. SOURCE-TEXT SCAN of the strip: one `setRegionFades(` and one `setRegionGain(`, both in
//      `apply`; the gesture's release is the strip's one call of `apply`; no number field, slider
//      or stepper of its own (no second field set); the range and the fades are the part bar's
//      (`PartGain`, `PartFades`, #416); the touch areas are the edge handles' rule; the strip
//      measures on the uncut part, never the cut span; the readout shows a number as the field does.
//   5. SOURCE-TEXT SCAN of the editor: the pane mounts the strip once, above the wave, and the
//      wave's fades are measured on the same uncut part.
//   6. COUNTERWEIGHT: the part bar still mounts the three fields — the numeric home and the
//      VoiceOver path, which the strip deliberately is not.
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent and the worktree. This file
// names `AudioPartLevel`, which this same commit creates, so it does NOT compile against the
// parent's `Sources/` and no assertion has a verdict there. Claims 1–3 are FORWARD by
// construction; claims 4 and 5 would be red on the parent by anchor absence (one absence, #486 —
// a missing file now FAILS rather than skips, so a move cannot silence them); claim 6 is green on
// both. Mutants, each red on the claim it targets: a fade-in that eats the fade-out, no floor at
// zero, the fade-out dragged the wrong way, the corners measured from opposite ends, the cut span
// instead of the uncut part, a pinned corner that does not come to the finger, an outward push
// from a pinned corner that writes, no slack, a level on a 0.1 grid, no ceiling, a second
// `setRegionGain`, a number field in the strip, the strip below the wave, a write while sliding, a
// typed `0...2`, `String(format:` in the readout, the wave's fades on the cut span. Stripper
// `SourceText.codeOnly`: PROPHYLAKTISCH (0 of the scans' verdicts flip, measured raw against
// stripped under every source mutant).
//
// ⚠️ THE LIMIT. Nothing here renders the strip or moves a finger: whether the hold wins over the
// page's scroll, whether a 6-point grip reads as something to hold, whether 3 points of slack feel
// like a hold and not like lag, and whether a 44-point strip gives the level enough travel are a
// DEVICE PROBE (founder device session, family "audio editor").

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheWaveCarriesTheFadesAndTheLevelTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let stripPath = "Sources/Echoelmusic/Studio/AudioPartLevelStrip.swift"
    private static let editorPath = "Sources/Echoelmusic/Studio/AudioPartEditorView.swift"
    private static let barPath = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"

    /// A one-bar part whose fades are a half and a whole beat: on a 192-point part, 10 ticks a point.
    private static let lengths = PartFades.Lengths(fadeInTicks: 240, fadeOutTicks: 480, lengthTicks: bar)

    /// A slide that moves `points` BEYOND the hold's slack — the distance the change follows.
    private static func beyond(_ points: Double) -> Double {
        points < 0 ? points - AudioPartLevel.holdStillPoints : points + AudioPartLevel.holdStillPoints
    }

    // MARK: 1 — a fade grip follows the finger

    func testAFadeGripFollowsTheFingerAndLeavesTheOtherFade() throws {
        func edit(_ grip: AudioPartLevel.Grip, _ points: Double, endX: Double = 292,
                  pane: Double = 400) -> AudioPartLevel.Edit? {
            AudioPartLevel.edit(grip, points: points, lengths: Self.lengths, level: 1, startX: 100, endX: endX,
                                paneWidth: pane, heightPoints: 44)
        }
        XCTAssertEqual(edit(.fadeIn, Self.beyond(24)), .fades(fadeInTicks: 480, fadeOutTicks: 480),
                       "24 points right is 240 ticks longer")
        XCTAssertEqual(edit(.fadeIn, Self.beyond(300)), .fades(fadeInTicks: 1440, fadeOutTicks: 480),
                       "never into the fade-out — the fade-in field's own range")
        XCTAssertEqual(edit(.fadeIn, Self.beyond(-100)), .fades(fadeInTicks: 0, fadeOutTicks: 480), "never below no fade")
        XCTAssertEqual(edit(.fadeOut, Self.beyond(-24)), .fades(fadeInTicks: 240, fadeOutTicks: 720),
                       "the fade-out grows as its corner moves LEFT")
        XCTAssertEqual(edit(.fadeOut, Self.beyond(100)), .fades(fadeInTicks: 240, fadeOutTicks: 0))
        XCTAssertEqual(edit(.fadeOut, Self.beyond(-500)), .fades(fadeInTicks: 240, fadeOutTicks: 1680),
                       "never into the fade-in — the fade-out field's own range")
        XCTAssertNil(edit(.fadeIn, 0), "a slide that moves nothing writes nothing")
        XCTAssertNil(edit(.fadeIn, AudioPartLevel.holdStillPoints), "a finger that drifts while it holds writes nothing")
        XCTAssertNil(edit(.fadeOut, -AudioPartLevel.holdStillPoints))
        XCTAssertNil(edit(.fadeIn, Self.beyond(0.04)), "nor one that moves less than half a tick beyond the slack")
        XCTAssertNil(edit(.fadeIn, .nan))
        XCTAssertNil(edit(.fadeIn, .infinity))
        XCTAssertNil(edit(.fadeIn, Self.beyond(24), endX: 100), "no part, no fade")
        XCTAssertNil(edit(.fadeIn, Self.beyond(24), pane: 0), "no pane, no fade")

        let corners = try XCTUnwrap(AudioPartLevel.cornerXs(Self.lengths, startX: 100, endX: 292))
        XCTAssertEqual(corners.fadeIn, 124, accuracy: 1e-9, "the fade-in's corner: 240 ticks at 10 a point")
        XCTAssertEqual(corners.fadeOut, 244, accuracy: 1e-9, "the fade-out's: 480 ticks back from the end")
        let moved = PartFades.Lengths(fadeInTicks: 480, fadeOutTicks: 480, lengthTicks: Self.bar)
        XCTAssertEqual(try XCTUnwrap(AudioPartLevel.cornerXs(moved, startX: 100, endX: 292)).fadeIn,
                       corners.fadeIn + 24, accuracy: 1e-9, "the corner lands exactly under the finger, past the slack")

        // Review S2: fades that fill the part, on a scale where the two ends round differently.
        let width = 351.0, file = 7.3
        let full = PartFades.Lengths(fadeInTicks: 60, fadeOutTicks: 3780, lengthTicks: 3840)
        let end = 4 * width / file
        let met = try XCTUnwrap(AudioPartLevel.cornerXs(full, startX: 0, endX: end))
        XCTAssertLessThanOrEqual(met.fadeIn, met.fadeOut, "corners that meet never cross")
        XCTAssertNotNil(AudioPartEditor.handleFrames(startX: met.fadeIn, endX: met.fadeOut, width: width),
                        "…so the grips are still offered when the fades fill the part")
    }

    // MARK: 1b — the part's own scale, not the cut picture

    func testAPartThatOutlastsItsFileFadesWhereThePlayerFades() throws {
        // A 3-s file in a 2-bar part (4 s at 120 BPM) on a 300-point pane: 100 points a second.
        let window = ArrangeCanvas.AudioWindow(mediaRef: "loop.wav", fromSeconds: 0, lengthSeconds: 4, gain: 1,
                                               fadeIn: 0, fadeOut: 0)
        let part = try XCTUnwrap(AudioPartEditor.partXs(of: window, fileSeconds: 3, width: 300))
        XCTAssertEqual(part.start, 0)
        XCTAssertEqual(part.end, 400, accuracy: 1e-9, "the uncut part runs 100 points past the pane, as the file runs out")
        XCTAssertEqual(AudioPartEditor.span(of: window, fileSeconds: 3), 0...1, "premise: the wave's picture cuts it at 1")
        XCTAssertNil(AudioPartEditor.partXs(of: window, fileSeconds: 0, width: 300))
        XCTAssertNil(AudioPartEditor.partXs(of: window, fileSeconds: 3, width: .nan))

        let lengths = PartFades.Lengths(fadeInTicks: 0, fadeOutTicks: 0, lengthTicks: 2 * Self.bar)
        func edit(_ grip: AudioPartLevel.Grip, _ points: Double) -> AudioPartLevel.Edit? {
            AudioPartLevel.edit(grip, points: points, lengths: lengths, level: 1, startX: part.start, endX: part.end,
                                paneWidth: 300, heightPoints: 44)
        }
        XCTAssertEqual(AudioPartLevel.shownX(400, paneWidth: 300), 300, "a corner past the pane is held at its edge")
        guard case .fades(let fadeIn, let fadeOut)? = edit(.fadeOut, Self.beyond(-44)) else {
            return XCTFail("pulling the held fade-out corner 44 points in writes a fade-out")
        }
        XCTAssertEqual(fadeIn, 0)
        XCTAssertEqual(fadeOut, 1382, "the corner comes to the finger: 256 points is 2.56 s, 1.44 s before the part ends")
        let fadeStarts = TimelineTime.seconds(fromTicks: 2 * Self.bar - fadeOut, bpm: 120)
        XCTAssertEqual(fadeStarts, 2.56, accuracy: TimelineTime.seconds(fromTicks: 1, bpm: 120),
                       "the player starts the fade at the file second under the finger, not inside the file's last 0.38 s")
        XCTAssertNil(edit(.fadeOut, Self.beyond(10)), "pushed outward, a held corner moves on from where it is — and 0 stays 0")
        XCTAssertEqual(edit(.fadeIn, Self.beyond(44)), .fades(fadeInTicks: 422, fadeOutTicks: 0),
                       "a corner inside the pane follows the finger on the same scale: 44 points is 422 ticks")
    }

    // MARK: 2 — the level line follows the finger

    func testTheLevelLineFollowsTheFingerInTheFieldsSteps() throws {
        func edit(_ points: Double, from level: Float = 1, height: Double = 44) -> AudioPartLevel.Edit? {
            AudioPartLevel.edit(.level, points: points, lengths: Self.lengths, level: level,
                                startX: 100, endX: 292, paneWidth: 400, heightPoints: height)
        }
        XCTAssertEqual(AudioPartLevel.levelY(1, heightPoints: 44), 22, "unity sits half-way")
        XCTAssertEqual(AudioPartLevel.levelY(PartGain.range.upperBound, heightPoints: 44), 0, "the store's ceiling at the top")
        XCTAssertEqual(AudioPartLevel.levelY(0, heightPoints: 44), 44, "silence at the bottom")
        XCTAssertEqual(edit(Self.beyond(11)), .level(0.5), "a quarter of the strip down is half the range down")
        XCTAssertEqual(AudioPartLevel.levelY(0.5, heightPoints: 44), 33, "…and the line sits 11 points lower: under the finger")
        XCTAssertEqual(edit(Self.beyond(1)), .level(0.95), "the field's own steps: 0.01")
        XCTAssertEqual(edit(Self.beyond(-100)), .level(2), "held to the store's ceiling")
        XCTAssertEqual(edit(Self.beyond(100)), .level(0), "held to silence")
        XCTAssertNil(edit(0), "no movement, no write")
        XCTAssertNil(edit(AudioPartLevel.holdStillPoints), "a finger that drifts while it holds writes nothing")
        XCTAssertNil(edit(-AudioPartLevel.holdStillPoints, from: 1.3457),
                     "a Normalized level off the 0.01 grid is not rounded by a hold")
        XCTAssertEqual(edit(Self.beyond(-1), from: 1.3457), .level(1.39), "a real slide lands on the field's grid")
        XCTAssertNil(edit(Self.beyond(-5), from: 2), "already at the ceiling: nothing to write")
        XCTAssertNil(edit(.nan))
        XCTAssertNil(edit(Self.beyond(5), height: 0))
        XCTAssertNil(edit(Self.beyond(5), from: .nan))
    }

    // MARK: 3 — the write: the part bar's writers, one Undo step each

    private func apply(_ grip: AudioPartLevel.Grip, _ points: Double, _ regionID: UUID, _ timeline: TimelineStore) {
        AudioPartLevel.apply(grip, points: points, regionID: regionID, startX: 100, endX: 292, paneWidth: 400,
                             heightPoints: 44, timeline: timeline)
    }

    func testAFadeSlideChangesTheFadesAndNothingElse() throws {
        try withStore { timeline, part in
            apply(.fadeIn, Self.beyond(24), part.id, timeline)
            var expected = part
            expected.fadeInTicks = 480
            XCTAssertEqual(timeline.document.regions, [expected], """
                The fade slide changed something besides the fade-in. Start, length, offset, gain, \
                warp and pitch are not the fade grip's to move.
                """)
            XCTAssertTrue(timeline.canUndo, "one undo step")
            timeline.undo()
            XCTAssertEqual(timeline.document.regions, [part])
            XCTAssertFalse(timeline.canUndo, "it was ONE step")
        }
    }

    func testALevelSlideChangesTheLevelAndNothingElse() throws {
        try withStore { timeline, part in
            apply(.level, Self.beyond(11), part.id, timeline)
            var expected = part
            expected.gain = 0.5
            XCTAssertEqual(timeline.document.regions, [expected])
            timeline.undo()
            XCTAssertEqual(timeline.document.regions, [part], "one Undo puts the level back")
            XCTAssertFalse(timeline.canUndo)
        }
    }

    func testASlideThatMovesNothingLeavesNoUndoStep() throws {
        try withStore { timeline, part in
            apply(.fadeOut, 0, part.id, timeline)
            apply(.fadeOut, -AudioPartLevel.holdStillPoints, part.id, timeline)
            apply(.level, AudioPartLevel.holdStillPoints, part.id, timeline)
            apply(.level, Self.beyond(11), UUID(), timeline)
            XCTAssertEqual(timeline.document.regions, [part])
            XCTAssertFalse(timeline.canUndo, "nothing moved, nothing to undo")
        }
        let store = TimelineStore()
        let saved = store.document
        defer { store.replaceDocument(saved) }
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let notes = TimelineRegion(laneID: midi.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        store.replaceDocument(TimelineDocument(lanes: [midi], regions: [notes]))
        apply(.level, Self.beyond(11), notes.id, store)
        XCTAssertEqual(store.document.regions, [notes], "a MIDI part has no level the fields would offer")
        XCTAssertFalse(store.canUndo)
    }

// MARK: 4 — SOURCE: one writer per fact, no second field set

    func testTheStripWritesThroughThePartBarsOwnCalls() throws {
        let strip = try source(Self.stripPath)
        XCTAssertEqual(occurrences(of: "setRegionFades(", in: strip), 1, "one fade write")
        XCTAssertEqual(occurrences(of: "setRegionGain(", in: strip), 1, "one level write")
        let apply = try member("static func apply(_ grip: Grip", in: strip)
        for needle in ["timeline.setRegionFades(", "timeline.setRegionGain(",
                       "PartFades.lengths(of: regionID, in:", "PartGain.gain(of: regionID, in:"] {
            XCTAssertTrue(apply.contains(needle), "`apply` lost `\(needle)` — it asks the part as the store holds it")
        }
        let view = try member("struct AudioPartLevelStrip: View {", in: strip)
        XCTAssertEqual(occurrences(of: "AudioPartLevel.apply(", in: view), 1, "the release is the one write")
        let ended = try member(".onEnded { value in", in: view)
        XCTAssertTrue(ended.contains("AudioPartLevel.apply("), "…on release, never while the finger moves")
        XCTAssertTrue(view.contains("LongPressGesture(minimumDuration:"), "hold first, so the page still scrolls")
        XCTAssertTrue(view.contains("AudioPartEditor.handleFrames("), "the edge handles' touch-area rule (#416)")
        for field in ["EchoelValueField", "Slider(", "Stepper(", "TextField("] {
            XCTAssertFalse(strip.contains(field), """
                The strip carries `\(field)`. The part bar's Fade in, Fade out and Part level fields are the \
                numeric home; a second field set is a second truth about the same three numbers (#416).
                """)
        }
        XCTAssertTrue(strip.contains("PartGain.range"), "the level's range is the store's clamp, read from the bar")
        for typed in ["0...2)", "0...2.0", "0.0...2"] {
            XCTAssertFalse(strip.contains(typed), "…never typed a second time (`\(typed)`)")
        }
        XCTAssertTrue(view.contains("AudioPartEditor.partXs(of: subject.window, fileSeconds: fileSeconds, width: width)"),
                      "the strip measures on the part's own, uncut scale (review S1)")
        XCTAssertFalse(strip.contains("AudioPartEditor.span("),
                       "…never on the window the wave cuts at the file's end — a fade there sits where nothing fades")
        XCTAssertFalse(strip.contains("String(format:"), "the readout shows a number as the field does (review S4)")
        XCTAssertTrue(strip.contains("EchoelDecimalText.string(ScrubPrecision.gridded("),
                      "…the field's own rounding and the reader's decimal separator")
    }

    // MARK: 5 — SOURCE: the editor mounts it above the wave

    func testTheEditorMountsTheStripAboveTheWave() throws {
        let editor = try source(Self.editorPath)
        let pane = try member("private struct AudioPartEditorPane: View {", in: editor)
        XCTAssertEqual(occurrences(of: "AudioPartLevelStrip(", in: pane), 1, "the strip is on the pane")
        guard let strip = pane.range(of: "AudioPartLevelStrip("),
              let wave = pane.range(of: "AudioPartFileWave(") else {
            return XCTFail("ANCHOR MISSING: the strip or the wave in the pane (#408)")
        }
        XCTAssertLessThan(strip.lowerBound, wave.lowerBound, "the envelope sits directly above the sound it shapes")

        let picture = try member("private struct AudioPartFileWave: View {", in: editor)
        XCTAssertTrue(picture.contains("AudioPartEditor.partXs(of: window, fileSeconds: total, width: 1)"),
                      "the wave's fades are measured on the same uncut part as the strip's (review S1)")
        XCTAssertTrue(picture.contains("(centre - part.start) / (part.end - part.start)"))
        XCTAssertFalse(picture.contains("centre - span.lowerBound"),
                       "…never on the cut span — a part that outlasts its file would fade inside the file's last seconds")
    }

    // MARK: 6 — COUNTERWEIGHT: the numeric home stays

    func testThePartBarKeepsTheThreeFields() throws {
        let bar = try source(Self.barPath)
        XCTAssertTrue(bar.contains("PartFadeFields(regionID:"), "the fade fields stay mounted on the part bar")
        XCTAssertTrue(bar.contains("PartGainField(regionID:"), "the level field stays mounted on the part bar")
    }

    // MARK: - Helpers

    private func withStore(_ body: (TimelineStore, TimelineRegion) throws -> Void) throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lane = TimelineLane(name: "Take", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav", nativeDurationSeconds: 8, nativeBPM: 120)
        let part = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: Self.bar, lengthTicks: Self.bar,
                                  contentOffsetSeconds: 1.5, gain: 1, fadeInTicks: 240, fadeOutTicks: 480,
                                  transposeSemitones: 2)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [part]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        try body(timeline, part)
    }

    private struct AnchorMissing: Error { let reason: String }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#408)")
            throw AnchorMissing(reason: head)
        }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` (#408)")
        throw AnchorMissing(reason: head)
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // The tree is here, so a missing file is a move, not a missing checkout (#454).
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
