// TheGenreSuggestsTheToneSystemTests.swift
// Echoel — G4: a genre may name the intonation it was written in, BLOCKING bundle.
//
// KIND: MIXED. Claims 1 and 5 are BEHAVIOUR over the roster; claims 2–4 are a SOURCE-TEXT SCAN.
//
// ⭐ WHY THE STRING ID IS THE WHOLE RISK, and why claim 1 exists even with an empty table.
// `TuningSystem.named(_:)` falls back to `library[0]` — 12-TET — for an id it does not know. So a
// typo in an arm of `suggestedToneSystemID` does not crash, does not warn, and does not sound
// wrong: it sounds exactly like a genre that was never given a tone system, which is the thing
// this property exists to fix. There is no compiler help here at all; a test is the only reader.
//
// ⚠️ CLAIM 1 IS VACUOUS TODAY and says so rather than reading as a pass (#806): every genre
// resolves to `nil`, so the sweep has nothing to resolve. It becomes load-bearing at G7, the
// first batch that names `meantone-quarter`. Claim 5 is NOT vacuous — it asserts the state the
// table is actually in, and would go red the day someone gave every offered genre a system,
// which is a real design change (a player who picks any genre then loses 12-TET silently).
//
// ⛔ WHAT THIS FILE DELIBERATELY DOES NOT ASSERT: that a suggested system keeps the twelve pitch
// classes distinct. That is `TheSuggestedToneSystemsDoNotCollapseTheScaleTests`, a different
// failure with a different repair — a WRONG id versus a RIGHT id that is wrong for a genre.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGenreSuggestsTheToneSystemTests: XCTestCase {

    private static let studioFile = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: - claim 1 (BEHAVIOUR) — every named system exists

    func testEverySuggestionResolvesInTheLibrary() {
        for style in MusicStyle.allCases {
            guard let id = style.suggestedToneSystemID else { continue }
            XCTAssertTrue(TuningSystem.library.contains { $0.id == id }, """
                \(style) suggests the tone system "\(id)", which is not in \
                `TuningSystem.library`. `TuningSystem.named(_:)` will hand back 12-TET and \
                nothing anywhere will say so — the genre will simply sound untuned, which is \
                indistinguishable from having no suggestion at all.
                """)
            XCTAssertEqual(TuningSystem.named(id).id, id,
                           "\(style)'s suggestion does not round-trip through `named(_:)`")
        }
    }

    // MARK: - claim 2 (SOURCE SCAN) — the hook is an `if let`, with no fallback

    func testTheGenreArmSuggestsWithoutResetting() throws {
        let code = try source(Self.studioFile)
        XCTAssertTrue(code.contains("if let suggested = style.suggestedToneSystemID {"), """
            The G4 hook is gone from the genre arm. A genre can then name an intonation that \
            nothing reads, which is the most expensive shape this repo knows: a table that \
            looks wired, a batch that authors values into it, and no sound.
            """)
        guard let hook = code.range(of: "if let suggested = style.suggestedToneSystemID {") else {
            throw AnchorMissing(reason: "the G4 hook is gone — re-anchor (#454)")
        }
        guard let armEnd = code.range(of: "applyArticulation()", range: hook.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "the genre arm lost `applyArticulation()` — re-anchor (#454)")
        }
        let arm = String(code[hook.lowerBound..<armEnd.lowerBound])
        XCTAssertFalse(arm.contains("\"edo12\""), """
            The genre arm falls back to 12-TET when a genre names no system. That makes the \
            genre Picker silently UNDO a deliberate choice from the tuning Picker — a worse \
            failure than never suggesting anything, and one a player cannot attribute.
            """)
        XCTAssertFalse(arm.contains("??"), """
            The genre arm's tone-system hook grew a `??`. Whatever the right-hand side is, it \
            runs for the genres that name nothing — i.e. for all of them today.
            """)
    }

    // MARK: - claim 3 (SOURCE SCAN) — exactly one reader, so a project restore cannot retune

    /// A count rather than a scan of `open(_:)`'s body, and deliberately so: the body is long and
    /// brace-matching it from text is the kind of parser that fails quietly. One reader in the
    /// whole file is a stronger statement and cannot be got wrong.
    func testNothingButTheUserEditReadsTheSuggestion() throws {
        let code = try source(Self.studioFile)
        XCTAssertEqual(code.components(separatedBy: "suggestedToneSystemID").count - 1, 1, """
            `suggestedToneSystemID` is read more than once in the Studio. The second reader is \
            almost certainly a project restore or a launch path — and there the genre would \
            overwrite the tuning the player SAVED, which is the one thing the "user interaction \
            only" contract above `handleCompositionEdit` exists to prevent.
            """)
    }

    // MARK: - claim 4 (SOURCE SCAN) — the contract the safety rests on is still stated

    func testTheUserInteractionContractStillStandsAboveTheHandler() throws {
        let code = try rawSource(Self.studioFile)
        guard let contract = code.range(of: "user interaction ONLY (Picker binding set / field commit)") else {
            throw AnchorMissing(reason: """
                the "user interaction ONLY" contract is gone from above `handleCompositionEdit`. \
                Every claim in this file about project restores rests on it; do not let this pass.
                """)
        }
        guard let handler = code.range(of: "private func handleCompositionEdit(_ field: String?) {") else {
            throw AnchorMissing(reason: "`handleCompositionEdit` is gone — re-anchor (#454)")
        }
        XCTAssertLessThan(code.distance(from: code.startIndex, to: contract.lowerBound),
                          code.distance(from: code.startIndex, to: handler.lowerBound), """
            The contract no longer sits above the handler it describes. It is the reason a \
            genre change may overwrite scale, patch and now tuning at all.
            """)
    }

    // MARK: - claim 5 (BEHAVIOUR, COUNTERWEIGHT) — not every genre takes the player's tuning

    /// Non-vacuous today (all genres are `nil`) and non-vacuous later: the day every offered
    /// genre names a system, 12-TET stops being reachable by choosing a genre, and a player who
    /// set a tuning by hand loses it on the next Picker touch. That is a design decision, not a
    /// batch detail, so it goes red here rather than being discovered on a device.
    func testAtLeastOneOfferedGenreLeavesTheTuningAlone() {
        XCTAssertTrue(MusicStyle.offered.contains { $0.suggestedToneSystemID == nil }, """
            Every offered genre now names a tone system. Choosing any genre then retunes the \
            instrument, and a player's own tuning choice survives nothing. If that is wanted, \
            it is a founder decision (§5-2) and this claim is what it has to be traded against.
            """)
    }

    // MARK: - source access (§0/§2)

    private struct AnchorMissing: Error { let reason: String }

    private func rawSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor, do not skip (#454)")
        }
        return text
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}
