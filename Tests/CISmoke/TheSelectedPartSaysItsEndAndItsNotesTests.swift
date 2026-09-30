// TheSelectedPartSaysItsEndAndItsNotesTests.swift
// Echoel — modes census 2026-09-26, design slice 2: the selected part says where it ends and how
// many notes it holds.
//
// WHAT THIS PINS. The part bar read "Selected part · Bar 9 · 4 bars" — the END was left for the
// musician to add up — and the note count existed only inside the grid's VoiceOver label, behind
// a closed switch. Now the heading reads "… · to bar 12" and the switch reads "Notes · 32".
//
// 1. END-TO-END BEHAVIOUR (`TrackParts.spanTitle`, pure): the end bar comes from the Workstation's
//    one pair of bar rules; a part that stays inside one bar adds nothing.
// 2. END-TO-END BEHAVIOUR (`ClipNoteEdit.noteCount` / `notesSwitchTitle`, pure over a real `Clip`
//    and `TimelineRegion`): the count is the grid's own windowing — notes outside the part are
//    not counted — and nil wherever the grid would not open a clip.
// 3. SOURCE: the part bar shows `spanTitle`; the switch shows the count and speaks it as its
//    value. That the bar's body reads no clip is pinned ONCE, by
//    `TheSelectedPartIsCutWhereItIsHeardTests` (#416) — the end bar needs none.
//
// Grading (§0, no Swift toolchain): `spanTitle`, `noteCount` and `notesSwitchTitle` do not exist
// on the parent (`0f4a5e128`), so this file does not compile there — the claims naming them are
// FORWARD guards, one absence (#486). `Text("Selected part · \(title)")` and the no-`setClipNotes`
// check are COUNTERWEIGHTS (green there too). The spoken-count pin (review of 705f771fd, LOW-6)
// is a FORWARD guard of that repair. Claims 1-2 transcribed into Python and driven on the cases
// below; claim 3 transcribed against this tree: green.
// NOT covered: how the longer heading wraps at the largest text sizes — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → select a 4-bar part at bar 9 → the bar reads "Selected part
// · Bar 9 · 4 bars · to bar 12"; on a MIDI part the switch reads "Notes · N" with N the notes the
// grid then shows.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSelectedPartSaysItsEndAndItsNotesTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerBeat
    private static let partBar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    private func part(_ start: Int, _ length: Int) -> TrackParts.Part {
        TrackParts.Part(id: UUID(), startTick: start, lengthTicks: length)
    }

    // MARK: 1 — the end bar, pure

    func testTheHeadingNamesTheLastBarAPartReaches() {
        let four = part(8 * Self.bar, 4 * Self.bar)
        XCTAssertEqual(TrackParts.spanTitle(four), TrackParts.title(four) + " · to bar 12",
                       "bars 9, 10, 11, 12 — the end bar is inclusive, not the bar after")
        let one = part(8 * Self.bar, Self.bar)
        XCTAssertEqual(TrackParts.spanTitle(one), TrackParts.title(one), "a one-bar part has no span to name")
        let short = part(8 * Self.bar + Self.beat, 2 * Self.beat)
        XCTAssertEqual(TrackParts.spanTitle(short), TrackParts.title(short),
                       "a part that stays inside bar 9 adds nothing")
        XCTAssertTrue(TrackParts.spanTitle(part(8 * Self.bar + Self.beat, 4 * Self.bar)).hasSuffix(" · to bar 13"),
                      "an off-grid part that spills into bar 13 says so")
        XCTAssertTrue(TrackParts.spanTitle(part(8 * Self.bar, 4 * Self.bar + 1)).hasSuffix(" · to bar 13"),
                      "one tick into bar 13 is bar 13 — the lane summary's own end rule")
    }

    // MARK: 2 — the note count, pure over real values

    func testTheSwitchCountsTheNotesTheGridShows() {
        let region = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        let notes = [Note(pitch: 60, startStep: 0), Note(pitch: 64, startStep: 4),
                     Note(pitch: 67, startStep: 20)]   // step 20 = tick 2400: past a one-bar part
        let clip = Clip(name: "count", kind: .midi, melody: MelodyClip(notes: notes))
        XCTAssertEqual(ClipNoteEdit.noteCount(clip: clip, region: region), 2,
                       "the note outside the part is not the part's — the grid's own windowing")
        XCTAssertEqual(ClipNoteEdit.noteCount(clip: nil, region: region), nil)
        XCTAssertEqual(ClipNoteEdit.noteCount(clip: Clip(name: "audio", kind: .audio), region: region), nil,
                       "an audio part has no notes to count")
        XCTAssertEqual(ClipNoteEdit.notesSwitchTitle(count: 2), "Notes · 2")
        XCTAssertEqual(ClipNoteEdit.notesSwitchTitle(count: 0), "Notes · 0", "an empty part says so")
        XCTAssertEqual(ClipNoteEdit.notesSwitchTitle(count: nil), "Notes")
    }

    // MARK: 3 — the two surfaces use them

    func testTheBarAndTheSwitchShowThem() throws {
        let bar = try source(Self.partBar)
        XCTAssertTrue(bar.contains("let title = TrackParts.spanTitle(part)"), "the part bar's heading names the end bar")
        // E4-26: the heading's head is a catalog key; the claim (the bar SHOWS `spanTitle`) is unchanged.
        XCTAssertTrue(bar.contains("Text(String(localized: \"Selected part · \") + title)"))

        let editor = try source(Self.editor)
        guard let start = editor.range(of: "struct PartNoteEditor: View {"),
              let end = editor.range(of: "private struct PartNoteGrid: View {", range: start.upperBound..<editor.endIndex) else {
            return XCTFail("ANCHOR MISSING: `PartNoteEditor` before `PartNoteGrid` (#454)")
        }
        let switchView = String(editor[start.upperBound..<end.lowerBound])
        XCTAssertTrue(switchView.contains("ClipNoteEdit.noteCount(clip: clipStore.clip(id: region.clipID), region: region)"),
                      "the count is asked of the one windowing rule, on the part's own clip")
        XCTAssertTrue(switchView.contains("Text(ClipNoteEdit.notesSwitchTitle(count: count))"))
        XCTAssertTrue(switchView.contains("let spokenCount: String = count.map { $0 == 1 ? \"1 note\" : \"\\($0) notes\" } ?? \"\""),
                      "the spoken value is the count in words (review of 705f771fd, LOW-6: an empty value passed)")
        XCTAssertTrue(switchView.contains(".accessibilityValue(spokenCount)"), "VoiceOver hears the count too")
        XCTAssertFalse(switchView.contains("setClipNotes"), "the switch counts, it never edits")
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
