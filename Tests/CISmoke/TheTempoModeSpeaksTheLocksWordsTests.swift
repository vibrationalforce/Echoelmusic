// TheTempoModeSpeaksTheLocksWordsTests.swift
// Echoel — interface audit 2026-09-30, rule 1 ("Ein Wort pro Sache"), the tempo-mode words.
//
// WHAT THIS GUARDS. The tempo has ONE truth, the BPM lock, and the app said it in THREE
// vocabularies: the head-strip picker said "Flow" / "Loop", `BodyTempoField` said "Tempo,
// following" / "Tempo locked", and the pulse info said "in Flow mode … in Loop mode". "Flow"
// told a beginner nothing, and "Loop" is the glossary's word for the REPEAT RANGE — one word,
// two things, the exact defect rule 1 names. Since this slice the picker wears the lock's own
// words — "Follows pulse" / "Locked" — under the caption "Tempo"; the save door says "tempo
// mode (following or locked)"; the tap hint stops naming a second mode ("This locks the
// tempo." — the lock IS the mode); the pulse info and the website say the same. `flow` is a
// STRUCK word in `docs/dev/GLOSSARY.md`, so `TheChromeSpeaksOneWordPerThingTests` now catches
// a "Flow" anywhere in the chrome; this file pins the POSITIVE side and the survivors.
//
// ⚠️ WHAT MUST NOT CHANGE, and why it is a claim here: `ComposerMode.flowFree` /
// `.studioLocked` are PERSISTED rawValues (`modeRaw` travels with every saved piece since
// #493/#494). Renaming the words a person reads is free; renaming the cases would orphan every
// saved piece. Claim 4 pins the cases and `init(locked:)` so a "finish the rename" sweep cannot
// reach them.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN. Nothing here renders the picker; that "Follows pulse" fits the
// strip's menu picker on a portrait phone is a founder look. The German column of the glossary
// is the string catalog's future, not a claim.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// f3df634a4 (no local toolchain): claims 1–3 RED on the parent for their named reasons (the
// glossary row, the picker words, the four prose sites and the website line all carry "Flow"
// there); claim 4 GREEN on both — the counterweight (#343): the enum cases, the initialiser
// and `BodyTempoField`'s two sentences are unchanged.
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTempoModeSpeaksTheLocksWordsTests: XCTestCase {

    private static let glossary = "docs/dev/GLOSSARY.md"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let info = "Sources/Echoelmusic/Studio/BioMetricInfo.swift"
    private static let composer = "Sources/Echoelmusic/Sequencer/BioComposer.swift"
    private static let tempoField = "Sources/Echoelmusic/Studio/BodyTempoField.swift"
    private static let overview = "docs/overview.html"

    // MARK: - claim 1 — the glossary names the tempo mode and strikes "flow"

    func testTheGlossaryNamesTheTempoModeAndStrikesFlow() throws {
        let text = try raw(Self.glossary)
        let rows = text.components(separatedBy: "\n").filter { $0.hasPrefix("| tempo mode |") }
        XCTAssertEqual(rows.count, 1, "the glossary has exactly one `tempo mode` row — it is the ONE definition (#416)")
        let row = rows.first ?? ""
        let cells = row.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertTrue(cells.count >= 5 && cells[3].lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains("flow"), """
            `flow` is not struck in the tempo-mode row. The chrome guard READS that column; without \
            it a "Flow" can come back into the head unnoticed.
            """)
        XCTAssertTrue(row.contains("\"Follows pulse\"") && row.contains("\"Locked\""), "the row states the two words a person reads")
        XCTAssertFalse(text.contains("OPEN: the tempo MODE"), "the loop row's OPEN note is closed by this slice — a note that outlives its slice invites a second one")
    }

    // MARK: - claim 2 — the head-strip picker wears the lock's words

    func testTheHeadPickerSaysFollowsPulseOrLocked() throws {
        let code = try source(Self.workspace)
        let picker = slice(code, from: "labeled(\"Tempo\") {", to: "\n                }\n")
        XCTAssertFalse(picker.isEmpty, "the head strip lost its `labeled(\"Tempo\")` block — the tempo-mode choice")
        XCTAssertTrue(picker.contains("Picker(\"Tempo\", selection: modeBinding)"), "the picker is titled Tempo and binds the ONE lock (`modeBinding`)")
        XCTAssertTrue(picker.contains("Text(\"Follows pulse\").tag(false)"), "the unlocked state reads \"Follows pulse\" — the field's own \"Tempo, following\", in the picker's shape")
        XCTAssertTrue(picker.contains("Text(\"Locked\").tag(true)"), "the locked state reads \"Locked\" — the field's own word and the lock icon's")
        XCTAssertTrue(picker.contains(".accessibilityLabel(\"Tempo: follows your pulse, or locked at one number\")"), "VoiceOver hears the same two words")
        XCTAssertFalse(picker.contains("\"Flow\"") || picker.contains("\"Loop\""), "neither struck word is in the picker")
        XCTAssertFalse(code.contains("labeled(\"Mode\")"), "the caption \"Mode\" is gone — the thing is the tempo, and the caption says so")
    }

    // MARK: - claim 3 — no visible sentence names a Flow or a Loop MODE any more

    func testNoVisibleSentenceNamesAFlowOrLoopMode() throws {
        let needles = ["Flow mode", "Loop mode", "Flow/Loop", "mode to Loop", "in Flow mode", "in Loop mode"]
        for rel in [Self.studio, Self.info, Self.workspace] {
            let code = try source(rel)
            for needle in needles {
                XCTAssertFalse(code.contains(needle), "\(rel) still says \"\(needle)\" in a code line — the tempo mode has the lock's words now")
            }
        }
        let studio = try source(Self.studio)
        XCTAssertTrue(studio.contains("tempo, tempo mode (following or locked), mood, "), "the Save door names the axis as \"tempo mode (following or locked)\" — `TheSavePromiseMatchesTheSaveTests` pins the run around it")
        XCTAssertTrue(studio.contains(".accessibilityHint(\"Tap in time to set the tempo. This locks the tempo.\")"), """
            The tap hint no longer ends at "This locks the tempo." — it used to add "and sets the \
            mode to Loop", i.e. two truths for one act; the lock IS the mode.
            """)
        let info = try source(Self.info)
        XCTAssertTrue(info.contains("while the tempo follows your pulse, the tempo itself (a locked tempo stays where you set it)"), "the heart-rate info says following / locked, not Flow / Loop")
        let page = try raw(Self.overview)
        XCTAssertFalse(page.contains("Flow mode") || page.contains("Loop mode"), "docs/overview.html repeats the app's words — it said \"in Flow mode … in Loop mode\" until this slice")
        XCTAssertTrue(page.contains("Tempo follows your pulse until you lock it"), "the website's heart-rate row says following / lock")
    }

    // MARK: - claim 4 — counterweights: persisted cases and the field's own sentences survive

    func testThePersistedCasesAndTheFieldsWordsAreUnchanged() throws {
        let composer = try source(Self.composer)
        XCTAssertTrue(composer.contains("case studioLocked") && composer.contains("case flowFree"), """
            `ComposerMode`'s cases changed. They are persisted rawValues (`modeRaw` on every saved \
            piece since #493/#494); the rename is for the words a person READS, never for these.
            """)
        XCTAssertTrue(composer.contains("public init(locked: Bool) {"), "the mode is still derived from the ONE lock")
        let field = try source(Self.tempoField)
        XCTAssertTrue(field.contains("\"Tempo locked — tap to let your body drive it again\""), "the field's locked sentence is the vocabulary the picker joined — it stays")
        XCTAssertTrue(field.contains(".accessibilityLabel(\"Tempo, locked\")"), "and its spoken label")
    }

    // MARK: - Reading the source

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func raw(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            XCTFail("\(relativePath) is absent — the definition file, not a source tree; this must not skip")
            return ""
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — rewrite this guard with the move, do not let it pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func slice(_ code: String, from: String, to: String) -> String {
        guard let start = code.range(of: from) else { return "" }
        guard let end = code.range(of: to, range: start.upperBound..<code.endIndex) else { return "" }
        return String(code[start.lowerBound..<end.lowerBound])
    }
}
