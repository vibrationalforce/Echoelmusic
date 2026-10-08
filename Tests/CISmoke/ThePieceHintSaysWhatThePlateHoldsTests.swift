// ThePieceHintSaysWhatThePlateHoldsTests.swift
// Echoel — GMMW P1-4. The bottom switcher's Piece entry told VoiceOver "Save, open and export the
// piece." Save and Open left the Piece plate with DAW shell S3 — they are the ≡ menu's — so two of
// the three verbs sent a listener to a plate that cannot do them. A false hint is a truth defect, not
// a taste call (#482: a door names what it reaches).
//
// WHAT IT PINS — the hint and the plate together, so neither can move alone:
// 1. END-TO-END: `ShellTab.project.spokenHint` names each thing the plate holds — the song's key,
//    scale, tuning and tempo mode (`CompositionHeaderStrip`), its light look (`PieceLightLookField`)
//    and the export as MIDI or audio (`SongExportTab`, `PieceAudioExportTab`) — and promises no Save
//    or Open.
// 2. SOURCE: `projectPlate` mounts exactly those four leaves, and none of them saves or opens.
// ⚠️ This forbids nothing (#364): if Save or Open ever returns to the plate, claim 1's message asks
// for the hint to say so in the same commit.
//
// Grading (§0, no Swift toolchain): on the parent (`347902b`) claim 1 is a REGRESSION — the hint
// there promises Save and Open and names none of the song's settings (red for its named reason);
// claim 2 is a COUNTERWEIGHT, green on both trees. Both were transcribed into Python and driven.
// NOT covered: what VoiceOver speaks on a device.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class ThePieceHintSaysWhatThePlateHoldsTests: XCTestCase {

    // MARK: 1 — the hint names what the plate holds, and nothing it does not

    func testTheHintNamesThePlatesContents() {
        let hint = ShellTab.project.spokenHint.lowercased()
        for word in ["key", "scale", "tuning", "tempo", "light look", "export", "midi", "audio"] {
            XCTAssertTrue(hint.contains(word), "the Piece hint does not name `\(word)` — the plate holds it")
        }
        for verb in ["save", "open"] {
            XCTAssertFalse(hint.contains(verb), """
                the Piece hint promises `\(verb)`. Save and Open are the ≡ menu's since DAW shell S3; if \
                one returns to the Piece plate, say so here in the same commit.
                """)
        }
    }

    // MARK: 2 — counterweight: the plate holds exactly those four leaves

    func testThePlateHoldsTheSettingsTheLookAndTheTwoExports() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = "Sources/Echoelmusic/Studio/WorkstationView.swift"
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        let code = SourceText.codeOnly(text)
        guard let start = code.range(of: "private var projectPlate: some View {") else {
            return XCTFail("ANCHOR MISSING: `projectPlate` (#454)")
        }
        var depth = 0
        var plate = ""
        for character in code[start.upperBound...] {
            if character == "{" { depth += 1 }
            if character == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            plate.append(character)
        }
        for leaf in ["CompositionHeaderStrip()", "PieceLightLookField()", "SongExportTab()", "PieceAudioExportTab()"] {
            XCTAssertEqual(plate.components(separatedBy: leaf).count - 1, 1, "the Piece plate mounts `\(leaf)` once")
        }
        for door in ["saveProject", "openProject", "fileImporter", "\"Save\"", "\"Open\""] {
            XCTAssertFalse(plate.contains(door), "the Piece plate holds `\(door)` — then the hint must name it (claim 1)")
        }
    }
}
#endif
