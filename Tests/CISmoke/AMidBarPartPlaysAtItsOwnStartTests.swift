// AMidBarPartPlaysAtItsOwnStartTests.swift
// Echoel — EP-8 (end-to-end audit of the MIDI flow, 2026-10-15). A part placed off the bar line —
// "Starts at beat 3" (EP-4), a one-beat move, a Repeat of a 6-beat part (EP-6a) — PLAYED WRONG.
// The roll and the rack pumps advance at GLOBAL bar lines, but the part's notes were sliced into
// bars counted from the PART's start (`barSlices`): loaded at its mid-bar onset, the part skipped
// its first half bar and every later bar sounded half a bar early. The code called it the M1b
// "known constraint"; the UI offered the placement anyway, and `SongMIDIExport` wrote the notes
// where they belong, so the WAV and the .mid of one song disagreed.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`RegionNoteWindow` + `LaneNotePump`, pure — the rack's real
//      scheduler): a 6-beat part at beat 3 of bar 1, loaded at its onset step the way the player
//      loads it, attacks its first note AT its start and its beat-3 note on the next bar line.
//      Counterweight: the old slicing, driven through the same pump, plays the beat-3 note at the
//      onset and never plays the first one — the defect, reproduced, so the fixture can tell.
//   2. A bar-aligned part is unchanged (phase 0 returns the old slices exactly), and the entry bar
//      counts SONG bars.
//   3. SOURCE-TEXT SCAN: the player slices on the song grid in both loaders, launched parts keep
//      their own timebase (`onSongGrid: false`), and no region-relative entry bar is left.
//
// ⚠️ HONEST GRADING (#433): claims 1–3 are FORWARD — `songBarSlices`/`songEntryBar` are new (one
// absence, #486); claim 1's counterweight is the parent's behaviour. Transcribed in Python on this
// geometry (1920 ticks per bar, 120 per step), no local toolchain (§0).
// NOT covered: the primary roll (`PianoRollModel.loadRegionArrangement`) is driven by the same
// slices and entry bar but not run here; the timing of the step clock itself.
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: a one-bar MIDI part with a note on beat 1, set
// Starts at beat 3, play from bar 1 — the note sounds on beat 3, not on beat 1 of the next bar).

import Foundation
import XCTest
@testable import Echoelmusic

final class AMidBarPartPlaysAtItsOwnStartTests: XCTestCase {

    private let bar = TimelineTime.ticksPerBar
    private let step = Note.ticksPerStep

    /// Drive a pump from the part's onset step through `steps` global steps; returns the global
    /// step (counted from the top of bar 1) of each attack, by pitch.
    private func attacks(bars: [[Note]], startBar: Int, onsetStep: Int, steps: Int) -> [Int: Int] {
        var pump = LaneNotePump()
        pump.load(bars: bars, startBar: startBar)
        var first: [Int: Int] = [:]
        for global in onsetStep..<(onsetStep + steps) {
            for event in pump.step(global % 16) where event.isOn && first[event.pitch] == nil {
                first[event.pitch] = global
            }
        }
        return first
    }

    // MARK: 1 — END-TO-END

    func testAPartAtBeatThreePlaysFromBeatThree() {
        let start = 2 * TimelineTime.ticksPerBeat                  // bar 1, beat 3 = step 8
        let length = 6 * TimelineTime.ticksPerBeat                 // ends on the bar-3 line
        let notes = [Note(pitch: 60, startStep: 0), Note(pitch: 64, startStep: 8)]   // part beats 1 and 3
        let windowed = RegionNoteWindow.windowed(notes: notes, offsetTicks: 0, lengthTicks: length)
        let onsetStep = start / step

        let slices = RegionNoteWindow.songBarSlices(
            notes: windowed, regionLengthTicks: length,
            phaseTicks: RegionNoteWindow.barPhaseTicks(regionStartTick: start))
        XCTAssertEqual(slices.count, 2, "beat 3 of bar 1 to the bar-3 line spans two song bars")
        let fixed = attacks(bars: slices,
                            startBar: RegionNoteWindow.songEntryBar(regionStartTick: start, at: start),
                            onsetStep: onsetStep, steps: 24)
        XCTAssertEqual(fixed[60], 8, "the part's first note sounds AT the part's start (beat 3)")
        XCTAssertEqual(fixed[64], 16, "its beat-3 note sounds two beats later — on the next bar line")

        // Counterweight: the pre-EP-8 slicing through the same pump.
        let old = attacks(bars: RegionNoteWindow.barSlices(notes: windowed, regionLengthTicks: length),
                          startBar: 0, onsetStep: onsetStep, steps: 24)
        XCTAssertEqual(old[64], 8, "premise: the old slices played beat 3 at the onset — half a bar early")
        XCTAssertNil(old[60], "premise: and skipped the part's first note")
    }

    // MARK: 2 — BAR-ALIGNED PARTS ARE UNCHANGED

    func testABarAlignedPartKeepsItsSlicesAndTheEntryBarCountsSongBars() {
        let notes = [Note(pitch: 60, startStep: 3), Note(pitch: 62, startStep: 20)]
        XCTAssertEqual(RegionNoteWindow.barPhaseTicks(regionStartTick: 3 * bar), 0)
        XCTAssertEqual(RegionNoteWindow.songBarSlices(notes: notes, regionLengthTicks: 2 * bar, phaseTicks: 0),
                       RegionNoteWindow.barSlices(notes: notes, regionLengthTicks: 2 * bar))
        XCTAssertEqual(RegionNoteWindow.barPhaseTicks(regionStartTick: bar + 960), 960)
        // A part from beat 3 of bar 1: at the bar-2 line it is in its SECOND slice, although only
        // half a bar of it has passed — the region-relative count said 0.
        XCTAssertEqual(RegionNoteWindow.songEntryBar(regionStartTick: 960, at: bar), 1)
        XCTAssertEqual((bar - 960) / bar, 0, "premise: the old region-relative count")
        XCTAssertEqual(RegionNoteWindow.songEntryBar(regionStartTick: 960, at: 960), 0)
        XCTAssertEqual(RegionNoteWindow.songEntryBar(regionStartTick: 5 * bar, at: 0), 0, "never negative")
    }

    // MARK: 3 — SOURCE

    func testThePlayerSlicesArrangementPartsOnTheSongGrid() throws {
        let player = try source("Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift")
        XCTAssertEqual(player.components(separatedBy: "RegionNoteWindow.songBarSlices(").count - 1, 2,
                       "both loaders — the roll's loadClip and the rack's windowedBars — slice on the song grid")
        XCTAssertFalse(player.contains("RegionNoteWindow.barSlices("),
                       "no loader may slice from the part's own start again")
        XCTAssertFalse(player.contains("tick - region.startTick) / TimelineTime.ticksPerBar"),
                       "no region-relative entry bar is left — it is one bar short past the next song bar line")
        XCTAssertEqual(player.components(separatedBy: "launchedStartBar(laneID: t.laneID, atTick: tick), step: step,\n                     onSongGrid: false)").count - 1, 1,
                       "a launched part on the roll keeps its own timebase")
        XCTAssertTrue(player.contains("onSongGrid ? RegionNoteWindow.barPhaseTicks(regionStartTick: region.startTick) : 0"))
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
