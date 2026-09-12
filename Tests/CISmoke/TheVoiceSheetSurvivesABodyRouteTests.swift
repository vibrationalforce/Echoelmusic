// TheVoiceSheetSurvivesABodyRouteTests.swift
// Echoel — #1274 (A3 of the founder's 2026-09-11 ask: „Weiterverarbeitung in
// granularsynthese, Harmonizer und Visuals"). All three onward paths were already built —
// harmonizer #841, granular #849, input→picture #1248 — and #1249/#1250 then gave the BODY a
// route to three of the voice parameters plus the autotune amount. This slice is what that
// combination cost and nobody had measured: six hot `@Observable` reads sitting in
// `monitoringSection`'s own body, three lines from two `.pickerStyle(.menu)` pickers.
//
// THE LAW (10.76.41 / 10.76.48 / 10.76.50, four device reports): a high-frequency read in ANY
// body that hosts a `.menu` Picker rebuilds that body and tears the open popover down while
// the finger is in it — the founder's „kann plötzlich nicht mehr auswählen". The repair shape
// is always the same: the read goes into its own leaf `View` (`BioStripView`,
// `PulseMonitorMiniLive`, `MasterVolumeField`), and the menu's host stays still.
//
// WHAT IS HOT HERE, and it is not a guess: `voiceHarmonyMix`, `voiceGranularMix`,
// `voiceGranularPitch` and `voiceTuneStrength` are registered modulation destinations
// (`EchoelmusicApp`), applied on every deduped bus frame — about once a second — as soon as a
// route exists; `voiceHarmonyInterval1/2` are rewritten per sung note by `updateHarmonyInKey`
// while "Harmony in key" is on; `voiceTuneRetune` is read by the same character lookup as
// `voiceTuneStrength`, so it shares the body either way.
//
// ⚠️ IT HAD NOT BITTEN YET, because the routes are one day old (#1250, 2026-09-11). That is
// the reason to pin it now rather than a reason not to: the mechanism is one this repo has
// already paid for four times, and the next payment would be a device session.
//
// SOURCE-TEXT SCAN (§1): no SwiftUI render in a test host — what is pinned is WHERE each read
// lives, which is the whole of the law.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`bd168cc`) and this tree: claims 1,
// 2 and 3 RED on the parent (every hot read sat in `monitoringSection` there), claims 4 and 5
// GREEN on both (counterweights — they must be, or they are not counterweights). All five
// GREEN here. Claims 1–3 TRAGEND (3 of 5 verdicts flip); 4–5 PROPHYLAKTISCH.

import Foundation
import XCTest

final class TheVoiceSheetSurvivesABodyRouteTests: XCTestCase {

    private static let sheet = "Sources/Echoelmusic/Studio/AudioInputPickerView.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    /// The six parameters a body route or the key-follower can rewrite under the user's
    /// finger, plus the two live readouts that share the sheet.
    private static let hot = ["voiceHarmonyMix", "voiceGranularMix", "voiceGranularPitch",
                              "voiceGranularGrainMs", "voiceTuneStrength", "voiceTuneRetune",
                              "voiceHarmonyInterval1", "voiceHarmonyInterval2",
                              "monitorGateCeiling", "feedbackGuardActive"]

    /// The leaves that are allowed to read them. Named, not inferred: "any struct" would let
    /// a future section body that happens to be a struct member pass.
    /// ⚠️ `FeedbackGuardStatusRow` is on this list and predates the slice: it reads
    /// `feedbackGuardActive` and has been a leaf since it was written — found by DRIVING the
    /// transcription, which went red on a correct tree with a name I had not thought to look
    /// for. A hand-written allow-list is exactly the kind that misses the case that already
    /// obeys the law (#453 → #477).
    private static let leaves = ["VoiceTuneCharacterControls", "VoiceHarmonyIntervalPickers",
                                 "VoiceHarmonyMixField", "VoiceGranularFields",
                                 "FeedbackGateLine", "FeedbackGuardStatusRow"]

    /// Claim 1 — the section body reads nothing hot. This is the claim that would have been
    /// red the day #1250 landed, if it had existed.
    func testTheMonitoringSectionBodyReadsNothingHot() throws {
        let code = SourceText.codeOnly(try text(Self.sheet))
        let body = try Self.section(code)
        for name in Self.hot {
            XCTAssertFalse(body.contains(name), """
                `monitoringSection`'s body reads `\(name)`. A body route (or the key follower) \
                rewrites it while the sheet is open, so the whole section rebuilds — and it \
                hosts two `.pickerStyle(.menu)` pickers, which lose their open popover on \
                every rebuild. Put the read in its own leaf `View` (10.76.41/50, #1274).
                """)
        }
    }

    /// Claim 2 — the two `.menu` pickers moved WITH their reads. Leaving them in the section
    /// while the fields moved out would look like the repair and keep the defect: the pickers
    /// themselves read `voiceHarmonyInterval1/2`, which the key follower rewrites per note.
    func testTheMenuPickersLiveInTheirOwnLeaf() throws {
        let code = SourceText.codeOnly(try text(Self.sheet))
        let body = try Self.section(code)
        XCTAssertFalse(body.contains(".pickerStyle(.menu)"), """
            a `.menu` Picker is back in `monitoringSection`'s body. Even with every field \
            moved out, that body still rebuilds whenever SwiftUI invalidates the sheet — the \
            pickers belong with the values they read (#1274).
            """)
        let leaf = try Self.declaration("VoiceHarmonyIntervalPickers", in: code)
        XCTAssertEqual(leaf.components(separatedBy: ".pickerStyle(.menu)").count - 1, 2,
                       "the two harmony interval pickers are no longer both in their leaf (#1274)")
        XCTAssertTrue(body.contains("VoiceHarmonyIntervalPickers()"),
                      "the interval pickers are no longer mounted by the section — the control vanished rather than moved (#1274)")
    }

    /// Claim 3 — every hot read in this file sits inside one of the named leaves. Claim 1 only
    /// clears ONE body; this one catches the read that moves into a different non-leaf member
    /// of the same file, which is the same defect one anchor over.
    func testEveryHotReadInThisFileIsInsideALeaf() throws {
        let code = SourceText.codeOnly(try text(Self.sheet))
        var current = "<file scope>"
        for line in code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let name = Self.topLevelName(line) { current = name }
            for hot in Self.hot where line.contains(hot) {
                XCTAssertTrue(Self.leaves.contains(current), """
                    `\(hot)` is read inside `\(current)`, which is not one of this file's leaf \
                    views. A hot read outside a leaf registers its whole enclosing view as an \
                    observer at the rate the value changes (#1274):
                    \(line.trimmingCharacters(in: .whitespaces))
                    """)
            }
        }
    }

    /// Claim 4 — COUNTERWEIGHT, green on both trees: the routes this defends against are real.
    /// If the four destinations ever leave `EchoelmusicApp`, the "hot" premise weakens and
    /// this file should be re-argued rather than silently kept.
    func testTheVoiceDestinationsAreStillRegistered() throws {
        let app = SourceText.codeOnly(try text(Self.app))
        for key in ["ModDestinationKey.voiceHarmonyMix", "ModDestinationKey.voiceGranularMix",
                    "ModDestinationKey.voiceGranularPitch", "ModDestinationKey.voiceTuneStrength"] {
            XCTAssertTrue(app.contains("modulationEngine.register(\(key))"), """
                `\(key)` is no longer registered. Either the body can no longer reach the voice \
                stage — in which case the founder's „Weiterverarbeitung" ask regressed — or the \
                registration moved and this counterweight needs re-anchoring (#1249/#1274).
                """)
        }
    }

    /// Claim 5 — COUNTERWEIGHT, green on both trees: the extraction moved controls, it did not
    /// delete any. Five value fields, three pickers, and the two stage toggles still exist
    /// SOMEWHERE in this file. A refactor that quietly loses a control is the cheapest way to
    /// turn this whole guard green for the wrong reason.
    func testNoControlWasLostInTheMove() throws {
        let code = SourceText.codeOnly(try text(Self.sheet))
        for label in ["label: \"Amount\"", "label: \"Tune\"", "label: \"Grain\"",
                      "label: \"Pitch\"", "label: \"Monitor level\""] {
            XCTAssertTrue(code.contains(label), "the `\(label)` field is gone from the input sheet (#1274)")
        }
        XCTAssertEqual(code.components(separatedBy: "label: \"Mix\"").count - 1, 2,
                       "the two Mix fields (harmony, granular) are no longer both present (#1274)")
        XCTAssertEqual(code.components(separatedBy: ".pickerStyle(.menu)").count - 1, 2,
                       "the harmony interval pickers changed in number (#1274)")
        XCTAssertTrue(code.contains("setVoiceHarmony($0)") && code.contains("setVoiceGranular($0)"),
                      "a stage toggle is gone — the singer can no longer switch the stage on (#841/#849)")
    }

    // MARK: - helpers

    /// `monitoringSection`'s own body: from its declaration to the first top-level `private
    /// struct` that follows it in the file.
    private static func section(_ code: String) throws -> String {
        let marker = "private var monitoringSection"
        let hits = code.components(separatedBy: marker).count - 1
        guard hits == 1, let start = code.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let end = code.range(of: "\nprivate struct ", range: start.upperBound..<code.endIndex) else {
            throw XCTSkip("no leaf struct follows `monitoringSection` — this file's shape changed (#408)")
        }
        return String(code[start.upperBound..<end.lowerBound])
    }

    private static func declaration(_ name: String, in code: String) throws -> String {
        let marker = "private struct \(name): View"
        guard let start = code.range(of: marker) else {
            throw XCTSkip("leaf `\(name)` is gone — re-anchor (§4)")
        }
        let rest = code[start.upperBound...]
        let end = rest.range(of: "\nprivate struct ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// The name of a top-level declaration, or nil. Scoped to column 0 so a nested type
    /// cannot rename the enclosing scope.
    private static func topLevelName(_ line: String) -> String? {
        guard line.first == "s" || line.hasPrefix("private ") || line.hasPrefix("final ")
                || line.hasPrefix("extension ") || line.hasPrefix("struct ") else { return nil }
        for keyword in ["private struct ", "struct ", "final class ", "extension ", "private final class "] {
            guard let r = line.range(of: keyword), r.lowerBound == line.startIndex else { continue }
            let rest = line[r.upperBound...]
            let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !name.isEmpty { return String(name) }
        }
        return nil
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
