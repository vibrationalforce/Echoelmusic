// APartCarriesItsOwnPitchTests.swift
// Echoel — an audio part carries its own pitch (GMMW AE-10a, founder 2026-10-08: "Die klassische
// DAW Audio Editing View fehlt mir noch.").
//
// WHY: the audio path had one pitch per TRACK (`TimelineLane.transposeSemitones`, #165), so the
// same loop could not sit at +0 in the verse and +5 in the chorus without a second track. Every
// DAW's audio editor transposes the PART. AE-10a is the MODEL half: the stored field, its range,
// what split, duplicate and Join do with it, and the store's one writer. The player sums it with
// the track's pitch in AE-10b and the part bar's field is the door from AE-10c — so nothing here
// claims a part's pitch is HEARD.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — the initializer holds the pitch to the audio path's range, asked from
//    `AudioTranspose.semitoneRange` rather than restated (#416), at both ends and at `Int.min`/
//    `Int.max`; a new part has none.
// 2. END-TO-END — split and duplicate carry the pitch, Join of a clean split gives the part back
//    EXACTLY, and Join refuses halves at different pitches (they would join at one of them).
// 3. END-TO-END on the real store — one set is ONE undo step; an unchanged, unknown or
//    clamped-to-unchanged value records nothing; a value past the range is stored at its edge.
// 4. END-TO-END — the part bar offers a pitch only for a part on an AUDIO track (the one kind
//    whose player plays it), shown held to the range; MIDI, bio and a gone part get none (#164).
// 5. SOURCE-TEXT SCAN (AE-10c) — the bar mounts the field under that question; the leaf writes
//    once, on commit, through the store's one writer and the field's one conversion; it is off
//    while the piece plays and reads `isPlaying` in its own body; the draft follows the store.
// The decoder half (a legacy part opens at 0, a foreign value opens held to the range, a round
// trip keeps it) is `ARegionSurvivesAFieldItDoesNotKnowTests` claims 1 and 4, not repeated here.
// The player half (track + part) is `ATransposedTrackPlaysThroughThePitchChainTests` 11–13.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `transposeSemitones` on a
// REGION and `setRegionTranspose`, which this commit creates, so it does NOT COMPILE against the
// parent — no assertion has a verdict there (one absence, #486). All three claims are FORWARD
// guards, transcribed in Python against the work tree's arithmetic. Whether a part's pitch
// SOUNDS right is AE-10b's device probe and open.
// Claims 4–5 (AE-10c) are FORWARD too — `PartPitch` and `PartPitchField` are created by that
// commit; claim 5's 14 verdicts were driven in Python: all green on the worktree, all red on its
// parent `3cd569f` by anchor absence (one absence, #486). Stripper `SourceText.codeOnly`:
// PROPHYLAKTISCH — 0 of the 14 flip between raw and stripped text on either tree.
// Whether the field reads well, and the probe in its doc, are device questions.

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class APartCarriesItsOwnPitchTests: XCTestCase {

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    // MARK: 1 — the range is the audio path's, asked, not restated

    func testThePitchIsHeldToTheRangeTheAudioPathPlays() {
        let range = AudioTranspose.semitoneRange
        XCTAssertLessThan(range.lowerBound, 0, "the range has a downward half — a scan over it means something")
        XCTAssertGreaterThan(range.upperBound, 0, "and an upward half")
        func pitch(_ semitones: Int) -> Int {
            TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 960,
                           transposeSemitones: semitones).transposeSemitones
        }
        XCTAssertEqual(TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 960)
                        .transposeSemitones, 0, "a new part has no pitch of its own")
        XCTAssertEqual(pitch(7), 7, "a pitch inside the range is kept")
        XCTAssertEqual(pitch(range.upperBound), range.upperBound, "the top edge is inside")
        XCTAssertEqual(pitch(range.lowerBound), range.lowerBound, "the bottom edge is inside")
        XCTAssertEqual(pitch(range.upperBound + 1), range.upperBound, "one past the top is held to it")
        XCTAssertEqual(pitch(range.lowerBound - 1), range.lowerBound, "one past the bottom is held to it")
        XCTAssertEqual(pitch(Int.max), range.upperBound, "Int.max is held, not trapped on")
        XCTAssertEqual(pitch(Int.min), range.lowerBound, "Int.min is held, not trapped on")
    }

    // MARK: 2 — split and duplicate carry it; Join refuses a mismatch

    func testSplitAndDuplicateCarryThePitchAndJoinRefusesAMismatch() {
        let part = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                  transposeSemitones: 5)
        guard let (left, right) = part.split(at: 3_840, bpm: 120) else {
            return XCTFail("a part did not split at its middle")
        }
        XCTAssertEqual([left.transposeSemitones, right.transposeSemitones], [5, 5],
                       "both pieces of a split keep the part's pitch")
        XCTAssertTrue(left.abuts(right, bpm: 120), "a clean split always rejoins")
        XCTAssertEqual(left.merged(with: right), part, "Join of a clean split is the part again, pitch and all")
        XCTAssertEqual(part.duplicated().transposeSemitones, 5, "a duplicate keeps the pitch")

        var higher = right
        higher.transposeSemitones = 7
        XCTAssertFalse(left.abuts(higher, bpm: 120), "halves at different pitches would join at one of them — Join refuses")

        // Counterweight (#343): a part without a pitch splits and rejoins exactly as before AE-10a.
        let plain = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680)
        guard let (a, b) = plain.split(at: 1_000, bpm: 120) else { return XCTFail("a plain part did not split") }
        XCTAssertTrue(a.abuts(b, bpm: 120))
        XCTAssertEqual(a.merged(with: b), plain)
    }

    // MARK: 3 — the store: one step, nothing recorded for nothing, held to the range

    func testOneSetIsOneUndoStepAndStoresWhatThePathCanPlay() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        func stored() -> Int? {
            timeline.document.regions.first { $0.id == part.id }?.transposeSemitones
        }
        let top = AudioTranspose.semitoneRange.upperBound

        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")
        timeline.setRegionTranspose(id: part.id, 7)
        XCTAssertEqual(stored(), 7)
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(stored(), 0, "ONE undo step takes the pitch back")
        XCTAssertFalse(timeline.canUndo, "and it was exactly one")

        timeline.setRegionTranspose(id: part.id, 0)
        XCTAssertFalse(timeline.canUndo, "an unchanged pitch records nothing")
        timeline.setRegionTranspose(id: UUID(), 7)
        XCTAssertFalse(timeline.canUndo, "a part that is gone records nothing")

        timeline.setRegionTranspose(id: part.id, Int.max)
        XCTAssertEqual(stored(), top, "a pitch past the range is stored at its edge — what the path can play")
        timeline.setRegionTranspose(id: part.id, top + 12)
        timeline.undo()
        XCTAssertEqual(stored(), 0, "a value that clamps to the stored one recorded no second step")
        XCTAssertFalse(timeline.canUndo)
    }

    // MARK: 4 — the bar offers a pitch only where the player plays one

    func testOnlyAPartOnAnAudioTrackIsOfferedAPitch() {
        let top = AudioTranspose.semitoneRange.upperBound
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let pitched = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 960,
                                     transposeSemitones: -3)
        var wild = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 960, lengthTicks: 960)
        wild.transposeSemitones = Int.max
        let keys = TimelineRegion(laneID: midi.id, clipID: UUID(), startTick: 0, lengthTicks: 960,
                                  transposeSemitones: 5)
        let body = TimelineRegion(laneID: bio.id, clipID: UUID(), startTick: 0, lengthTicks: 960,
                                  transposeSemitones: 5)
        let doc = TimelineDocument(lanes: [audio, midi, bio], regions: [pitched, wild, keys, body])
        XCTAssertEqual(PartPitch.semitones(of: pitched.id, in: doc), -3, "an audio part shows its own pitch")
        XCTAssertEqual(PartPitch.semitones(of: wild.id, in: doc), top, "and shows it held to what the store keeps")
        XCTAssertNil(PartPitch.semitones(of: keys.id, in: doc), "a MIDI part's pitch is moved in the note editor — no field (#164)")
        XCTAssertNil(PartPitch.semitones(of: body.id, in: doc), "a bio track plays no audio pitch — no field")
        XCTAssertNil(PartPitch.semitones(of: UUID(), in: doc), "a part that is gone has no field")
    }

    // MARK: 5 — the field: mounted under that question, one write on commit, off while playing

    func testTheFieldWritesOnceOnCommitAndIsOffWhilePlaying() throws {
        let bar = try source("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertEqual(occurrences(of: "PartPitchField(regionID: regionID, semitones: pitch)", in: bar), 1,
                       "the bar mounts the field once")
        let mount = try XCTUnwrap(bar.range(of: "if let pitch = PartPitch.semitones(of: regionID, in: document) {"),
                                  "ANCHOR MISSING: the bar no longer asks `PartPitch.semitones(of:in:)` before the field")
        let field = try XCTUnwrap(bar.range(of: "PartPitchField(regionID: regionID, semitones: pitch)"))
        XCTAssertLessThan(mount.lowerBound, field.lowerBound, "the field sits under the audio-only question")
        XCTAssertEqual(occurrences(of: "setRegionTranspose(", in: bar), 1, "one write site in the bar")

        let leaf = try XCTUnwrap(bracedBody(after: "private struct PartPitchField: View {", in: bar),
                                 "ANCHOR MISSING: PartPitchField")
        let commit = try XCTUnwrap(bracedBody(after: "private func commitPitch() {", in: leaf),
                                   "ANCHOR MISSING: commitPitch")
        XCTAssertTrue(commit.contains("timeline.setRegionTranspose(id: regionID, AudioTranspose.semitones(fromField: value))"),
                      "the release writes through the store's one writer and the field's one conversion")
        XCTAssertTrue(commit.contains("draft = nil"), "a commit clears its draft")
        let render = try XCTUnwrap(bracedBody(after: "var body: some View {", in: leaf), "ANCHOR MISSING: the leaf's body")
        XCTAssertFalse(render.contains("setRegionTranspose("), "the drag never writes — only the commit does")
        for needle in ["let playing = player.isPlaying", ".disabled(playing)", "range: AudioTranspose.fieldRange",
                       "decimals: 0", "onCommit: { commitPitch() }", ".onChange(of: semitones) { _, _ in draft = nil }"] {
            XCTAssertTrue(render.contains(needle), "PartPitchField lost `\(needle)`")
        }
        for banned in ["Slider(", "Stepper("] {
            XCTAssertFalse(leaf.contains(banned), "a numeric parameter is an `EchoelValueField`, never a raw `\(banned)`")
        }
    }

    // MARK: - Source helpers

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present under \(dir.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The brace-matched body that opens at the end of `head` (which must end in `{`), or nil.
    private func bracedBody(after head: String, in text: String) -> String? {
        guard head.hasSuffix("{"), let start = text.range(of: head) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
