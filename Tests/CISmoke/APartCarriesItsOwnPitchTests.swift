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
// The decoder half (a legacy part opens at 0, a foreign value opens held to the range, a round
// trip keeps it) is `ARegionSurvivesAFieldItDoesNotKnowTests` claims 1 and 4, not repeated here.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `transposeSemitones` on a
// REGION and `setRegionTranspose`, which this commit creates, so it does NOT COMPILE against the
// parent — no assertion has a verdict there (one absence, #486). All three claims are FORWARD
// guards, transcribed in Python against the work tree's arithmetic. Whether a part's pitch
// SOUNDS right is AE-10b's device probe and open.

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
}
