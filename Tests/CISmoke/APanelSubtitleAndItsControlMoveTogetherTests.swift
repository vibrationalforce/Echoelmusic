// APanelSubtitleAndItsControlMoveTogetherTests.swift
// Echoel — the coupling law behind #620/UX#12, kept after BOTH of its instances were
// withdrawn (#1302, #1305). Renamed from `ThePanelSubtitlesNameTheirDeepFeaturesTests`
// because that name describes a procedure the code no longer takes (#374): no panel
// subtitle names a deep feature today, and a guard whose NAME asserts otherwise sends the
// next reader looking for one.
//
// THE LAW (#616/#620). A panel subtitle that names a deep control must use THE CONTROL'S
// OWN WORDS, and the two must move together — a rename, or a removal, touches both halves
// in one commit. A subtitle pointing at a control that does not exist is worse than no
// subtitle: it teaches a search that fails.
//
// WHY IT IS INVERTED RATHER THAN DELETED (#926). Both instances are gone — "Voice timbre"
// with the microphone (#1302) and "Follow the key" with the harmonizer (#1305) — and each
// time the subtitle token left in the SAME commit as its control, which is the pair doing
// exactly its job. But the COUNTER-QUESTION outlives the instances: *is there a subtitle
// naming a control that is not there?* This file now asks that as an EQUALITY rather than
// a presence, so it holds in both directions and in the empty case.
//
// #364 — IT FORBIDS NOTHING. Re-adding "Follow the key" with its toggle keeps this green;
// only HALF a re-add reds it, which is the entire point. Do not read the assertion as "the
// harmonizer may not come back".
//
// KIND (§1): SOURCE-TEXT SCAN. It proves where words sit, never that a subtitle renders or
// that a player finds anything — those stay device probes.
//
// GRADING (#433), transcribed (§0) against the parent and this tree: claim 1 is GREEN on
// BOTH (on the parent both halves were present, here both are absent — an equality holds
// at either end, which is what makes it a durable shape rather than a snapshot). It is
// therefore a COUNTERWEIGHT by construction, and that is stated rather than dressed up as
// a regression (#433's flattering direction). The two claims it replaces were FORWARD
// guards for #620 and are recorded in this header, not re-run.
//
// Stripper: delegates to `SourceText.codeOnly` (#453). PROPHYLAKTISCH here (0 of 1
// verdicts flips): neither needle occurs in a comment on either side today. It was
// measured TRAGEND for the retired pair, whose needle was quoted in a source comment —
// kept in this sentence so nobody re-derives the earlier measurement.

import Foundation
import XCTest

final class APanelSubtitleAndItsControlMoveTogetherTests: XCTestCase {

    private func codeLines(of relPath: String) throws -> [String] {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(relPath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// #620b (review W1): the first version required title and subtitle on ONE physical
    /// line — the exact shape #619b had just hardened another guard away from, and this
    /// very slice wrapped the soundPanel call. Joining the anchor line with its next two
    /// continuation lines follows the sturdier precedent
    /// (`WeatherIsAMoodRubricTests.testTheSaveExportSubtitleNamesTheCity`), so a legal
    /// reformat cannot red the token check (#364).
    private func declSlice(_ lines: [String], anchor: String) throws -> String {
        let hits = lines.indices.filter { lines[$0].contains(anchor) }
        XCTAssertEqual(hits.count, 1, """
            `\(anchor)` is no longer unique in its file — re-anchor before trusting the \
            subtitle check (#408).
            """)
        // #620b (review L1): a vanished decl is ONE absence — skip instead of failing a
        // second assertion over the same missing anchor (#486).
        guard let start = hits.first else {
            throw XCTSkip("anchor `\(anchor)` absent — reported by the count assertion above")
        }
        return lines[start ..< min(start + 3, lines.count)].joined(separator: " ")
    }

    // ⛔ #1302 (founder 2026-09-12, "Face und Audio Input komplett entfernen") retired the
    // FIRST pair: `testTheSoundSubtitleNamesTheVoiceTimbre` and its counterweight
    // `testTheVoiceTimbreRowStillExists`. ⛔ #1305 ("Kein … Autotune, Harmonizer,
    // granularsynthese") retired the SECOND: `testTheEffectsSubtitleNamesFollowTheKey` and
    // `testTheFollowTheKeyToggleStillExists`. Both times the subtitle token left in the same
    // commit as its control — the pair did its job twice and is retired, not re-anchored.

    /// The coupling, as an EQUALITY. Today both sides are false, so this is green because
    /// nothing dangles — not because nothing was checked.
    ///
    /// ⚠️ IT READS THE TOKEN OUT OF THE SUBTITLE'S OWN SLICE, not the whole file: the
    /// Effects panel's source comment DISCUSSES "Follow the key" at length (that is the
    /// tombstone three levels up), and a file-wide scan would therefore read the retraction
    /// as the claim. `SourceText.codeOnly` blanks that comment, and the slice narrows it
    /// again — belt and braces, because a future editor may write the token in code for an
    /// unrelated reason.
    func testTheEffectsSubtitleNamesNoToggleThatIsMissing() throws {
        let studio = try codeLines(of: "Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        let subtitle = try declSlice(studio, anchor: "panel(\"Effects\",")
        let subtitleNamesIt = subtitle.contains("Follow the key")

        let fx = try codeLines(of: "Sources/Echoelmusic/Studio/EchoelFXView.swift")
        let toggleExists = fx.contains { $0.contains("Toggle(\"Follow the key\"") }

        XCTAssertEqual(subtitleNamesIt, toggleExists, """
            The Effects panel's subtitle and the control it points at have drifted apart: \
            the subtitle names "Follow the key" = \(subtitleNamesIt), the toggle exists in \
            EchoelFXView = \(toggleExists). Whichever half is missing, ADD IT BACK OR TAKE \
            THE OTHER OUT IN THIS COMMIT (#616/#620). A subtitle that names a control two \
            levels down which is not there teaches a search that fails; a control nothing \
            above names is undiscoverable, which is the defect #620 was written for. \
            Both halves are FALSE today because #1305 removed the harmonizer and its \
            toggle, and took the subtitle token with it — that is the pair working, not a \
            hole. If the harmonizer returns, bring the subtitle token back with it.
            """)
    }
}
