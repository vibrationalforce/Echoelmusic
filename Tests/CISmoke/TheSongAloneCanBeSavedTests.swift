// TheSongAloneCanBeSavedTests.swift
// Echoel — WA4 Acceptance Test A: create → import → SAVE → reopen.
//
// WHAT THIS PINS. The Save tile was `.disabled(!hasComposed)`: a player who only imported audio
// into the Workstation — no composed take — could not save the song they had built, so
// Acceptance Test A broke at its third step. The Session carries the song since WA4-S3, so a
// song holding the USER's parts is worth a save on its own. The tile is now the
// `SaveSessionButton` leaf, enabled by `hasComposed || SessionSaveOpen.songHasUserParts(…)` —
// the SAME predicate the recovery slot uses (`autosaveTake`), asked, not restated (#416).
//
// 1. SOURCE: the leaf computes that one predicate, and the dim state tracks `.disabled` exactly
//    (a lit tile that eats the tap is the #482 lie). The leaf reads the song in its OWN body:
//    the root body hosts every `.menu` Picker and must not observe the document (freeze law).
// 2. SOURCE: the save still goes through `withSession`, and the Save message names the song —
//    a save that carries the song while its sentence says "the loop" under-claims (#495).
// 3. COUNTERWEIGHT: `songHasUserParts` still ignores the composer's own part (the #622 law —
//    never an empty take under a real name — holds for a plain launch). Its behaviour is driven
//    end to end in `TheSessionSaveOpensTheSameSongTests`; here the source keeps the gate on it.
//
// Grading (§0, no Swift toolchain in a web session): all claims driven in Python against this
// tree. On the parent (8820621fd) claims 1–2 are red by ABSENCE of `SaveSessionButton` and the
// new sentence — ONE absence (#486); they are FORWARD guards. Claim 3 is a COUNTERWEIGHT, green
// on both. NOT covered: that the tile lights up on the device after an import, and that the
// Open of a song-only project restores it audibly — device probes.
// NEEDS-FOUNDER-VERIFY: fresh launch, do NOT press Start → Workstation → Add Audio Track →
// Import Audio → the Save tile lights → Save → clear the song → Open the saved project → the
// track and the part come back and play.

import Foundation
import XCTest

final class TheSongAloneCanBeSavedTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sessionPath = "Sources/Echoelmusic/Core/SessionSaveOpen.swift"

    // MARK: 1 — the leaf asks the one predicate

    func testTheSaveTileIsEnabledByASongWithTheUsersParts() throws {
        let studio = try code(Self.studioPath)
        guard let start = studio.range(of: "private struct SaveSessionButton: View {"),
              let end = studio.range(of: "private struct KeepLastLoopButton: View {",
                                     range: start.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the SaveSessionButton leaf (#454)")
        }
        let leaf = String(studio[start.upperBound..<end.lowerBound])
        for needle in ["@Environment(TimelineStore.self) private var timeline",
                       "@Environment(ClipStore.self) private var clips",
                       "let canSave = hasComposed",
                       "|| SessionSaveOpen.songHasUserParts(timeline.document, clips: clips.filledClips)",
                       "enabled: canSave)", ".disabled(!canSave)",
                       ".accessibilityLabel(\"Save this session\")"] {
            XCTAssertTrue(leaf.contains(needle), "the Save leaf lost `\(needle)`")
        }
        XCTAssertEqual(studio.components(separatedBy: "SaveSessionButton(hasComposed: hasComposed)").count - 1, 1,
                       "the leaf is mounted once — in the quick action row")
        XCTAssertEqual(studio.components(separatedBy: ".accessibilityLabel(\"Save this session\")").count - 1, 1,
                       "one Save tile — a second, `hasComposed`-only copy beside the leaf would disagree with it")
    }

    // MARK: 2 — the save carries the song and says so

    func testTheSaveCarriesTheSongAndItsSentenceSaysSo() throws {
        let studio = try code(Self.studioPath)
        XCTAssertTrue(studio.contains("projects.save(withSession(currentProject()))"),
                      "Save must capture the song through `withSession` — an enabled tile that saves only the take is the lie")
        let raw = try text(Self.studioPath)
        XCTAssertTrue(raw.contains("sound and FX character, and the Workstation's song — its tracks and parts. "),
                      "the Save message must name the song it now carries (#495: under-claiming is still false)")
    }

    // MARK: 3 — counterweight: the composer's part is not the user's

    func testTheComposersOwnPartDoesNotEnableTheSave() throws {
        let session = try code(Self.sessionPath)
        XCTAssertTrue(session.contains("let composed = Set(clips.filter(\\.composerOwned).map(\\.id))"),
                      "songHasUserParts must still skip the composer's own clip — otherwise a plain launch enables Save on nothing (#622)")
        XCTAssertTrue(session.contains("known.contains($0.clipID) && !composed.contains($0.clipID)"),
                      "songHasUserParts must still require a part whose clip is known and not the composer's")
    }

    // MARK: helpers

    private func text(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return text
    }

    private func code(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try text(relativePath))
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }
}
