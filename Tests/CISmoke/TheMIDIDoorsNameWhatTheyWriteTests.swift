// TheMIDIDoorsNameWhatTheyWriteTests.swift
// Ultraplan-C1 (2026-10-16): three doors write a MIDI file, and two of them said only "MIDI" and
// "Export" — the difference (the instrument's TAKE vs the whole SONG) lived in their VoiceOver
// hints alone. The take door now reads "Instrument .mid" (the glossary strikes "take": the block is a part, the instrument's output is its music); the song's "Export" on Piece and the part bar's
// "Share as MIDI" already said their scope and stay (the song door's word is quoted by the Learn
// path card and pinned by `TheGuideNamesOnlyRealControlsTests`, so it is not renamed here).
//
// WHAT KIND OF GREEN THIS IS (§1): SOURCE-TEXT SCANS over three Views with private members, plus
// the string catalog. DEVICE PROBE, open: the tile title fits at the largest type size.
//
// HONEST GRADING against the parent (§3): claim 1 is RED there for its named reason (the tile
// reads "MIDI"); claim 2 is two COUNTERWEIGHTS, green on both trees; claim 3 is red there by
// ABSENCE of the new keys. Mutants: the title back to "MIDI" (1) · a visible title without a
// Voice Control name (1, WCAG 2.5.3) · the song door renamed without its guide quote (2).

import Foundation
import XCTest

final class TheMIDIDoorsNameWhatTheyWriteTests: XCTestCase {

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    // MARK: 1 — the take door says "Instrument .mid", and answers to it

    func testTheTakeDoorNamesTheTake() throws {
        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        guard let door = studio.range(of: "Button { exportMIDI() } label: {") else {
            return XCTFail("the take's MIDI door moved — re-anchor")
        }
        let tile = String(studio[door.upperBound...].prefix(900))
        XCTAssertTrue(tile.contains("EchoelIconTile(systemImage: \"pianokeys\", title: \"Instrument .mid\", expands: true,"),
                      "the take door's title names its scope")
        XCTAssertTrue(tile.contains(".accessibilityLabel(\"Export the instrument's music as MIDI for your DAW\")"))
        XCTAssertTrue(tile.contains(".accessibilityInputLabels([String(localized: \"Instrument .mid\")])"),
                      "Voice Control answers to the word on the tile (WCAG 2.5.3)")
        XCTAssertFalse(studio.contains("title: \"MIDI\""), "no MIDI door says only \"MIDI\"")
    }

    // MARK: 2 — the song and part doors keep the words that already say their scope

    func testTheSongAndPartDoorsKeepTheirScope() throws {
        let song = try code("Sources/Echoelmusic/Studio/SongExportTab.swift")
        XCTAssertTrue(song.contains("title: \"Export\""), "Piece's song door, quoted by the Learn path card")
        XCTAssertTrue(song.contains("Shares the piece as a MIDI file"), "and its hint says it is the piece")
        let part = try code("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertTrue(part.contains("Text(\"Share as MIDI\")"), "the part bar's door")
        XCTAssertTrue(part.contains("Share this part as a MIDI file"), "and its label says it is the part")
    }

    // MARK: 3 — the new words are catalogued, the old label is gone from the catalog

    func testTheTakeDoorsWordsAreCatalogued() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings"))
        let catalog = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for key in ["Instrument .mid", "Export the instrument's music as MIDI for your DAW"] {
            XCTAssertNotNil(strings[key], "`\(key)` is not in the catalog")
        }
        XCTAssertNil(strings["Export MIDI for your DAW"], "the retired label left the catalog with its literal")
    }
}
