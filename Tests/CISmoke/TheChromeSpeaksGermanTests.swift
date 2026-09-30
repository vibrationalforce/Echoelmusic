// TheChromeSpeaksGermanTests.swift
// Echoel — decision E4 of the interface audit (founder 2026-09-30, "Ja": the app speaks German,
// chrome first, ~40 words): every word of the stage seam, the area row and the head transport
// has a German unit in `Localizable.xcstrings`, and the code reaches the catalog for it.
//
// KIND — two kinds, labelled per claim (Tests/CISmoke/CLAUDE.md §1):
//   · END-TO-END for the WORDS: the shipped enums and `ProjectTransport` are driven (they are
//     Foundation-only) and every word they return is looked up as a KEY in the catalog. In the
//     test host the locale is English, so `String(localized:)` returns the key itself — which is
//     exactly the string the catalog is keyed by. Whether iOS then shows the German is a DEVICE
//     PROBE (a German-language device), registered in `docs/dev/FOUNDER_INBOX.md` §2, not proven here.
//   · SOURCE-TEXT for the REACH: a word that an enum returns as a plain `"literal"` is spelled
//     VERBATIM by `Text(candidate.label)` — SwiftUI localises `Text("literal")`, never
//     `Text(someString)`. So the three chrome files must return every user-visible literal
//     through `String(localized:)`. That is the half no runtime check in an English host can see.
//
// WHY THE CATALOG IS THE TRUTH AND NOT THIS FILE (#416). The German words live ONLY in
// `Localizable.xcstrings`; this guard never restates a translation. The one German word it does
// name comes from `docs/dev/GLOSSARY.md`'s own table (claim 5), so the glossary stays the single
// definition of "Stück".
//
// GRADING against the parent (§3). Claims 1, 2, 4 and 5 are FORWARD: the catalog keys they look
// up did not exist on the parent, so every one of them was red there for ONE reason — the
// absence of the 40 entries — counted once (#486). Claim 3 was red on the parent for its named
// reason (33 plain literals in the three files). The counterweights inside claims 1–4 (the enums
// still have their cases, the seven literal keys still occur as `Text("…")` in Sources, the
// catalog's en unit equals the key) are green on both trees. Transcribed in Python against both
// trees before the push; the Swift here is graded only by `Build for Testing` (§0).
// Claim 10 (E4-6 → E4-9) walks a listed family for `de` units and was red on each slice's parent for
// the ONE absence of that slice's units (#486). Claim 11 (E4-9) drives eight signature needles, the
// absent verbatim ternary in two files and nine units — on its parent all eight needles are absent,
// the ternary present and the nine units missing: ONE finding, the slice, not eighteen. E4-12 added
// the FX header's signature and its thirteen titles to claim 11 — on its parent the signature is
// `String` and ten units are missing: ONE finding. E4-13 added `EchoelPanel`'s three key-wrapped draw
// sites and seventeen panel words — on its parent the wraps are absent and fifteen units missing: ONE finding.
// E4-14 added the loudness readout's signature and four names (parent: `String`, four missing — ONE finding).
// E4-15 added the media label's key wrap and four titles (parent: verbatim, three missing — ONE finding).
// E4-16 added the selected-part bar: signature, three sentence heads, four localised labels, eighteen units
// (parent: all absent — ONE finding). E4-17 added the note editor: signature, seven heads, no verbatim label,
// three grid words, thirty-eight units (parent: all absent — ONE finding). E4-18 added the guide arrows, the
// instance line and the Save/Open doors: three signatures, two sentence seams, no verbatim sentence, fifteen units
// (parent: all absent, eight units missing — ONE finding). Claim 12
// (E4-10) drives four needles on `EchoelValueField` and walks every literal label app-wide: on its
// parent the needles are absent and the labels' units missing — again ONE finding.
//
// WHAT IT DOES NOT FORBID (#364): more chrome words, another language, a reworded sentence. A
// reworded sentence turns the OLD key into an orphan — `StringCatalogIsHonestTests` claim
// `testEveryKeyStillExistsAsALiteralInSources` catches that, not this file; this file catches the
// NEW sentence arriving without its German.

import XCTest
import Foundation
@testable import Echoelmusic

final class TheChromeSpeaksGermanTests: XCTestCase {

    private static let chromeFiles = [
        "Sources/Echoelmusic/Studio/StudioStage.swift",
        "Sources/Echoelmusic/Studio/StudioArea.swift",
        "Sources/Echoelmusic/Studio/ProjectTransport.swift",
    ]

    /// The keys SwiftUI localises by content alone — `Text("Pause")`, `.accessibilityLabel("Guide")`.
    /// No code change carries them, so the counterweight is that each still occurs as such a literal.
    private static let literalKeys = ["Pause", "Guide", "Stage", "Follows pulse", "Locked", "Demo", "Heart rate"]

    // MARK: - helpers

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/Echoelmusic").path) else {
            throw XCTSkip("source tree not present — this guard reads source text and skips rather than earning a green (#454)")
        }
        return root
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = try repoRoot().appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            throw XCTSkip("Localizable.xcstrings is not the JSON shape this guard reads — re-anchor (#454)")
        }
        return strings
    }

    /// The German unit of `key`, or nil when the key or its `de` unit is missing.
    private func german(_ key: String, in strings: [String: Any]) -> (state: String, value: String)? {
        guard let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let de = localizations["de"] as? [String: Any],
              let unit = de["stringUnit"] as? [String: Any],
              let state = unit["state"] as? String,
              let value = unit["value"] as? String else { return nil }
        return (state, value)
    }

    private func assertGerman(_ words: [String], _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let strings = try catalogStrings()
        XCTAssertFalse(words.isEmpty, "no \(what) to check — the enum lost its cases? (#454)", file: file, line: line)
        for word in words {
            guard let de = german(word, in: strings) else {
                XCTFail("""
                    \(what) "\(word)" has no German unit in Localizable.xcstrings. A chrome word without \
                    its `de` entry reverts to English for a German user while the words around it stay \
                    German (StringCatalogIsHonestTests names why that is worse than all-English). Add the \
                    key with a translated `de` unit — the catalog, never this file, holds the German (#416).
                    """, file: file, line: line)
                continue
            }
            XCTAssertEqual(de.state, "translated", "\(what) \"\(word)\": a `new` unit ships nothing (xcstringstool skips it)", file: file, line: line)
            XCTAssertFalse(de.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(what) \"\(word)\": empty German", file: file, line: line)
        }
    }

    private func codeOnly(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("\(relative) is not on disk — re-anchor this guard (#454)")
        }
        return SourceText.codeOnly(text)
    }

    // MARK: - claim 1 — END-TO-END: every stage and area word is a catalog key with a German unit

    func testEveryStageAndAreaWordHasAGermanUnit() throws {
        let stage = StudioStage.allCases.flatMap { [$0.label, $0.spokenHint] }
        let area = StudioArea.allCases.flatMap { [$0.label, $0.spokenHint] }
        XCTAssertEqual(StudioStage.allCases.count, 2, "counterweight: the seam still has its two stages")
        XCTAssertEqual(StudioArea.allCases.count, 5, "counterweight: the area row still has its five areas")
        try assertGerman(stage, "stage word")
        try assertGerman(area, "area word")
    }

    // MARK: - claim 2 — END-TO-END: every head-transport word and hint is a catalog key with a German unit

    func testEveryTransportWordHasAGermanUnit() throws {
        let statuses: [ProjectTransport.Status] = [.stopped, .paused, .playingInstrument, .playingSong, .recording]
        let plays: [ProjectTransport.PlayAction] = [.startSong, .startSongAndInstrument, .resumeInstrument, .unavailable]
        var words = statuses.map(ProjectTransport.statusWord)
        for running in [false, true] {
            words.append(ProjectTransport.buttonWord(running: running))
            for play in plays {
                words.append(ProjectTransport.buttonLabel(running: running, play: play))
                words.append(ProjectTransport.buttonHint(running: running, play: play))
            }
        }
        words += [ProjectTransport.stopHint, ProjectTransport.instrumentRunningCaption,
                  ProjectTransport.unsavedName, ProjectTransport.projectName(nil), ProjectTransport.projectName("  ")]
        // counterweight — the English words the sibling guard pins are unchanged in the English host
        XCTAssertEqual(ProjectTransport.statusWord(.playingSong), "Playing piece")
        XCTAssertEqual(ProjectTransport.buttonWord(running: true), "Stop")
        try assertGerman(Array(Set(words)).sorted(), "transport word")
    }

    // MARK: - claim 3 — SOURCE-TEXT: the three chrome files return no plain literal

    func testTheThreeChromeFilesReturnOnlyLocalizedLiterals() throws {
        // A `return "Piece"` is spelled verbatim by `Text(candidate.label)`; only
        // `return String(localized: "Piece")` reaches the catalog. Interpolated strings
        // (`return "\(lane.name) · …"`) are composed, not looked up, and are not this claim's.
        let plain = try NSRegularExpression(pattern: #"return "[A-Za-z][^"\\]*""#)
        let bareLet = try NSRegularExpression(pattern: #"static let (stopHint|instrumentRunningCaption|unsavedName) = ""#)
        var wrapped = 0
        for relative in Self.chromeFiles {
            let code = try codeOnly(relative)
            let range = NSRange(code.startIndex..., in: code)
            let offenders = plain.matches(in: code, range: range)
                .compactMap { Range($0.range, in: code) }.map { String(code[$0]) }
            XCTAssertEqual(offenders, [], """
                \(relative) returns a user-visible literal without `String(localized:)`. SwiftUI \
                localises `Text("literal")` by content but spells `Text(someString)` verbatim, so a \
                word this enum returns as a plain literal can never be German on the stage seam, the \
                area row or the head. Wrap it — and add its `de` unit to Localizable.xcstrings.
                """)
            XCTAssertEqual(bareLet.numberOfMatches(in: code, range: range), 0, "\(relative): a bare `static let … = \"` hint")
            wrapped += code.components(separatedBy: "String(localized:").count - 1
        }
        XCTAssertGreaterThanOrEqual(wrapped, 30, "counterweight: the three files still carry their ~33 localised words (measured 34 sites on 2026-09-30)")
    }

    // MARK: - claim 4 — the seven literal keys are translated AND still spelled as literals on screen

    func testTheLiteralChromeKeysAreTranslatedAndStillOnScreen() throws {
        try assertGerman(Self.literalKeys, "literal chrome key")
        // counterweight: SwiftUI can only find them if the literal is still written as `"…"`
        let root = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot walk Sources/Echoelmusic (#454)")
        }
        var haystack = ""; var files = 0
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            if let text = try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8) {
                haystack += SourceText.codeOnly(text); files += 1
            }
        }
        XCTAssertGreaterThan(files, 250, "the walk saw too few files to mean anything (#454)")
        for key in Self.literalKeys {
            XCTAssertTrue(haystack.contains("\"\(key)\""), """
                "\(key)" is a catalog key but no longer a literal in Sources — the German is an orphan. \
                Either the word was reworded (add the new key, retire this one) or it now travels as \
                a String variable, which SwiftUI spells verbatim (wrap it in String(localized:)).
                """)
        }
    }

    // MARK: - claim 6 — the head's Undo / Redo and the Record word travel as String PARAMETERS,
    // so their literals must be wrapped at the call site (E4-2); their German units exist

    func testTheUndoRedoAndRecordWordsReachTheCatalog() throws {
        let history = try codeOnly("Sources/Echoelmusic/Studio/SongHistoryRow.swift")
        XCTAssertTrue(history.contains("button(String(localized: \"Undo\")"), "the Undo title is a String parameter — only a wrapped literal reaches the catalog")
        XCTAssertTrue(history.contains("button(String(localized: \"Redo\")"), "the Redo title, same reason")
        XCTAssertFalse(history.contains("button(\"Undo\"") || history.contains("button(\"Redo\""), "a bare title literal is spelled verbatim by `Text(title)`")
        XCTAssertEqual(history.components(separatedBy: "label: String(localized: \"").count - 1, 2, "both spoken labels are wrapped")
        let record = try codeOnly("Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        let ternary = "recording ? String(localized: \"Stop recording\") : String(localized: \"Record\")"
        XCTAssertEqual(record.components(separatedBy: ternary).count - 1, 2, "the drawn word and the spoken label of the Record button both go through the catalog")
        XCTAssertFalse(record.contains("recording ? \"Stop recording\" : \"Record\""), "the bare ternary yields a String, which Text() spells verbatim")
        try assertGerman(["Undo", "Redo", "Record", "Stop recording", "Arm for recording",
                          "Undo the last change to the piece's parts, notes, automation or a relinked file",
                          "Redo the last undone change to the piece's parts, notes, automation or a relinked file"],
                         "head history / record word")
    }

    // MARK: - claim 7 — the pulse pill's word and the measurement screen's hint speak German (E4-3)

    func testEveryPulseCueWordHasAGermanUnit() throws {
        let cues: [PulseCue] = [.cameraDenied, .locked, .coverLens, .tooBright, .holdStill, .pressGently,
                                .finding, .noLight, .stalled(hasRhythmlessSignal: true), .stalled(hasRhythmlessSignal: false)]
        // counterweight — the English words the pill guards pin are unchanged in the English host
        XCTAssertEqual(PulseCue.noLight.shortLabel, "No light")
        XCTAssertEqual(PulseCue.stalled(hasRhythmlessSignal: true).shortLabel, "Unsteady")
        try assertGerman(Array(Set(cues.flatMap { [$0.shortLabel, $0.fullHint] })).sorted(), "pulse cue word")
        // SOURCE-TEXT — the two switches return no plain literal (a `? "…" : "…"` ternary included)
        let code = try codeOnly("Sources/Echoelmusic/Bio/PulseCue.swift")
        guard let start = code.range(of: "public var fullHint: String {"),
              let end = code.range(of: "public var isActionable: Bool {", range: start.upperBound..<code.endIndex) else {
            throw XCTSkip("PulseCue.fullHint / isActionable anchors moved — re-anchor (#454)")
        }
        let switches = String(code[start.lowerBound..<end.lowerBound])
        // `: "` also opens every `String(localized: "…")`, so that one label is excluded by lookbehind
        let bare = try NSRegularExpression(pattern: #"(return|\?|(?<!localized):) "[A-Za-z]"#)
        XCTAssertEqual(bare.numberOfMatches(in: switches, range: NSRange(switches.startIndex..., in: switches)), 0,
                       "a pulse-cue word returned as a plain literal is spelled verbatim by `Text(cue.shortLabel)` — wrap it")
        XCTAssertGreaterThanOrEqual(switches.components(separatedBy: "String(localized:").count - 1, 19,
                                    "counterweight: the two switches still carry their ~20 localised words")
    }

    // MARK: - claim 8 — the status ladders speak German: MIDI in/out, audio route, Apple Health (E4-4)

    func testEveryLadderWordCaptionAndSpokenSentenceHasAGermanUnit() throws {
        var texts: [String] = []
        for r in MIDIInRung.allCases { texts += [r.word, r.caption, r.line(source: ""), r.spoken(source: "")] }
        for r in MIDIOutRung.allCases { texts += [r.word, r.caption, r.line(destinations: 0), r.line(destinations: 1), r.spoken(destinations: 0)] }
        for r in AudioRouteRung.allCases { texts += [r.word, r.spoken(outputs: "")] }
        texts.append(AudioRouteRung.caption)
        for r in HealthSourceRung.allCases { texts += [r.word, r.line, r.caption, r.spoken] }
        // A line is `word + fragment`; a spoken sentence with an argument is `head + arg + tail`.
        // Each PIECE is the catalog key, so split the composed strings back into their pieces
        // and demand a German unit for every piece that carries a letter.
        var pieces = Set<String>()
        for t in texts {
            if let dot = t.range(of: " · ") {                       // word + " · rest"
                pieces.insert(String(t[..<dot.lowerBound])); pieces.insert(String(t[dot.lowerBound...]))
            } else { pieces.insert(t) }
        }
        // the argument-carrying sentences were built with an EMPTY argument: head + "" + tail
        pieces.remove("Connected to , no notes yet"); pieces.insert("Connected to "); pieces.insert(", no notes yet")
        pieces.remove("Playing from "); pieces.insert("Playing from ")
        pieces.remove("Playing over "); pieces.insert("Playing over ")
        pieces.remove("Call mode over , mono and band-limited"); pieces.insert("Call mode over "); pieces.insert(", mono and band-limited")
        pieces.remove("Off · nothing plays yet")
        // counterweights — the English host still reads the words the row guards pin
        XCTAssertEqual(AudioRouteRung.callMode.word, "Call mode")
        XCTAssertEqual(MIDIOutRung.on.line(destinations: 1), "On · source + 1 destination")
        XCTAssertTrue(HealthSourceRung.receiving.line.hasPrefix("Receiving · "))
        try assertGerman(pieces.filter { $0.rangeOfCharacter(from: .letters) != nil }.sorted(), "ladder text")
        // SOURCE-TEXT — no plain literal with a letter outside `String(localized: "…")` in the three
        // ladder files; `" · "` (a separator) and `"\(destinations)"` (a number) are the only bare ones
        for rel in ["Sources/Echoelmusic/Studio/MIDIStatusWord.swift",
                    "Sources/Echoelmusic/Studio/AudioRouteStatusWord.swift",
                    "Sources/Echoelmusic/Bio/HealthSourceStatus.swift"] {
            let code = try codeOnly(rel)
            let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
            var bare: [String] = []
            for m in literal.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                guard let whole = Range(m.range, in: code), let inner = Range(m.range(at: 1), in: code) else { continue }
                let body = String(code[inner]).replacingOccurrences(of: #"\\\(.*?\)"#, with: "", options: .regularExpression)
                guard body.rangeOfCharacter(from: .letters) != nil else { continue }
                let before = code[code.startIndex..<whole.lowerBound]
                if !before.hasSuffix("String(localized: ") { bare.append(String(code[whole])) }
            }
            XCTAssertEqual(bare, [], "\(rel): a ladder word returned as a plain literal is spelled verbatim by `Text(rung.word)` — wrap it")
            XCTAssertGreaterThanOrEqual(code.components(separatedBy: "String(localized:").count - 1, 8,
                                        "\(rel): counterweight — the ladder still carries its localised words")
        }
    }

    // MARK: - claim 9 — the Power row, the output tiles and the network word speak German (E4-5)

    func testThePowerRowOutputTilesAndNetworkWordHaveGermanUnits() throws {
        var pieces = Set<String>()
        for r in PowerRung.allCases {
            pieces.insert(r.word)
            for p in QualityPressure.allCases {
                // `.full` carries its own fragment; reduced/saving append `pressure.cause`, covered below
                let line = r.line(pressure: p)
                if r == .full, let dot = line.range(of: " · ") { pieces.insert(String(line[dot.lowerBound...])) }
                pieces.insert(r.caption(pressure: p))
                let spoken = r.spoken(pressure: p)
                if let comma = spoken.range(of: ", ") { pieces.insert(String(spoken[...comma.lowerBound]) + " ") } else { pieces.insert(spoken) }
                pieces.insert(p.cause); pieces.insert(p.remedy)
            }
        }
        // `.full.line` carries its own fragment, its spoken sentence has no argument
        pieces.remove("Power full, "); pieces.insert("Power full, detail and bio stream at full rate")
        for r in VisualMonitorRung.allCases { if let w = r.word { pieces.insert(w) }; pieces.insert(r.spoken) }
        for r in LightMonitorRung.allCases { if let w = r.word { pieces.insert(w) }; pieces.insert(r.spoken) }
        for s in [NetworkSendState.off, .sending, .openIdle] { pieces.insert(s.label) }  // not CaseIterable
        // counterweights — the English readings the row and tile guards pin
        XCTAssertEqual(PowerRung.reduced.spoken(pressure: .thermal), "Power reduced, the phone is hot")
        XCTAssertEqual(VisualMonitorRung.externalScreen.word, "Screen")
        XCTAssertEqual(NetworkSendState.openIdle.label, "open, nothing sent")
        try assertGerman(pieces.sorted(), "power / output / network text")
        // the German tile words fit the tile as the English ones must (`OutputStatusWord.maxLength`)
        let strings = try catalogStrings()
        for word in ["Screen", "Idle", "Off"] {
            let de = try XCTUnwrap(german(word, in: strings)).value
            XCTAssertLessThanOrEqual(de.count, OutputStatusWord.maxLength, "`\(de)` does not fit the 38/54 pt tile")
        }
        // SOURCE-TEXT — no bare letter-literal outside `String(localized: "…")` in the two word files
        for rel in ["Sources/Echoelmusic/Studio/PowerStatusWord.swift", "Sources/Echoelmusic/Studio/OutputStatusWord.swift"] {
            let code = try codeOnly(rel)
            let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
            var bare: [String] = []
            for m in literal.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                guard let whole = Range(m.range, in: code), let inner = Range(m.range(at: 1), in: code) else { continue }
                guard String(code[inner]).rangeOfCharacter(from: .letters) != nil else { continue }
                if !code[code.startIndex..<whole.lowerBound].hasSuffix("String(localized: ") { bare.append(String(code[whole])) }
            }
            XCTAssertEqual(bare, [], "\(rel): a word returned as a plain literal is spelled verbatim on the tile — wrap it")
        }
    }

    // MARK: - claim 10 — the panel texts of the reachable chrome files have German units (E4-6, catalog-only)

    /// SwiftUI looks a `Text("…")` / `Button("…")` / `.accessibilityLabel("…")` literal up by its
    /// own content, so these sites need no Sources change — only a catalog entry. This claim walks
    /// the family files with the same regex the slice measured with, and demands a German unit for
    /// every literal key that carries a letter, no interpolation, no `%` and no escape. Brand marks
    /// and technical tokens the app spells the same in every language are listed, not translated.
    /// A literal that is the LEFT half of a `+ "…"` continuation is `Text(String)` — spelled
    /// verbatim, no key — and is skipped (seven such seams exist; they need a sentence design). The
    /// walk reads code only: E4-7 added `EchoelStudioView`, whose comments quote `Button("literal")`.
    /// E4-9 added the five label helpers of that file to the alternation — legitimate only because
    /// claim 11 pins that they take a key (or look one up); a `String` helper would spell the literal.
    /// E4-12 added `effectSection`, the FX panel's stage header, on the same terms (claim 11 pins it).
    /// E4-13 added `panel`, the instrument's card builder — its TITLE only; the subtitle is the second
    /// argument and is driven by name in claim 11 (`EchoelPanel` wraps both in a key).
    /// E4-14 added `readout`, the loudness grid's cell — its LABEL; the unit argument is an EBU token.
    static let panelFamily: [String] = [
            "Sources/Echoelmusic/Studio/EchoelStudioView.swift",
            "Sources/Echoelmusic/Studio/PatchbayView.swift",
            "Sources/Echoelmusic/Studio/EchoelFXView.swift",
            "Sources/Echoelmusic/Studio/WorkstationView.swift",
            "Sources/Echoelmusic/Studio/WorkspaceView.swift",
            "Sources/Echoelmusic/Studio/TrackInspectorView.swift",
            "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift",
            "Sources/Echoelmusic/Studio/BioStripView.swift",
            "Sources/Echoelmusic/Studio/HeaderMonitors.swift",
            "Sources/Echoelmusic/Studio/SessionLaunchView.swift",
            "Sources/Echoelmusic/Studio/SongAutomationEditor.swift",
            "Sources/Echoelmusic/Studio/TrackPartsView.swift",
            "Sources/Echoelmusic/Studio/BodyTempoField.swift",
            "Sources/Echoelmusic/Studio/ProjectSaveStatusView.swift",
            "Sources/Echoelmusic/Studio/TuningStatusBanner.swift",
            "Sources/Echoelmusic/Studio/ProjectHeader.swift",
            "Sources/Echoelmusic/Studio/SongHistoryRow.swift",
            "Sources/Echoelmusic/Studio/SelectedPartBar.swift",
            "Sources/Echoelmusic/Studio/SongPositionReadout.swift",
            "Sources/Echoelmusic/Studio/WorkstationClickToggle.swift",
            "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift",
            "Sources/Echoelmusic/Studio/AutomationStatusStrip.swift",
            "Sources/Echoelmusic/Studio/WorkstationMixMeter.swift",
            "Sources/Echoelmusic/Studio/GuideOverlay.swift",
            "Sources/Echoelmusic/Studio/PartNoteEditor.swift",
            "Sources/Echoelmusic/Studio/MediaBrowserView.swift",
            "Sources/Echoelmusic/Studio/AudioDegradedRow.swift",
            "Sources/Echoelmusic/Studio/AlwaysOnBioRow.swift",
            "Sources/Echoelmusic/Studio/NetworkActivityDot.swift",
            "Sources/Echoelmusic/Studio/MoodPads.swift",
            "Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift",
            "Sources/Echoelmusic/Studio/PerformSessionView.swift",
            "Sources/Echoelmusic/Studio/EchoelNumberPad.swift",
            "Sources/Echoelmusic/Studio/BioMetricInfo.swift",
            "Sources/Echoelmusic/Studio/VisualAnalysisMeter.swift",
            "Sources/Echoelmusic/Studio/AnalysisPoincareView.swift",
            "Sources/Echoelmusic/Studio/AnalysisScopeView.swift",
            "Sources/Echoelmusic/Studio/AnalysisSpectrumView.swift",
            "Sources/Echoelmusic/Studio/SafeModeView.swift",
            "Sources/Echoelmusic/Studio/LearnView.swift",
    ]
    static let untranslatedPanelWords: Set<String> = ["BPM", "Create from Within", "Demo", "E", "ECHOEL", "Echoelmusic", "Genre", "OK", "Poincaré plot", "Studio", "Tempo", "WAV FAILED", "WAV …"]

    func testEveryPanelTextOfTheReachableChromeFilesHasAGermanUnit() throws {
        let root = try repoRoot()
        let strings = try catalogStrings()
        let literal = try NSRegularExpression(
            pattern: #"\b(?:Text|Button|Toggle|Label|Picker|Section|TextField|Menu|NavigationLink|Link|labeledRow|groupHeader|collapsibleGroupHeader|mixStripCard|weatherMixGroup|effectSection|panel|readout)\(\s*"((?:[^"\\]|\\.)*)"|\.accessibility(?:Label|Hint|Value)\(\s*"((?:[^"\\]|\\.)*)""#)
        var sites = 0, missing: [String] = [], seen = Set<String>()
        for rel in Self.panelFamily {
            let code = try codeOnly(rel)                                        // a `Button("literal")` quoted in a comment is not a site
            for m in literal.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                let r = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                guard let range = Range(r, in: code), let whole = Range(m.range, in: code) else { continue }
                let key = String(code[range])
                if key.contains("\\") || key.contains("%") || key.rangeOfCharacter(from: .letters) == nil { continue }
                let after = code[whole.upperBound...].prefix(80).drop(while: { $0.isWhitespace })
                if after.hasPrefix("+") { continue }                       // left half of a `+` seam, not a key
                if Self.untranslatedPanelWords.contains(key) { continue }
                sites += 1
                if seen.insert(key).inserted, german(key, in: strings) == nil { missing.append(key) }
            }
        }
        XCTAssertGreaterThan(sites, 400, "the walk found \(sites) literal-key sites — it did not read the family")
        XCTAssertEqual(missing, [], """
            \(missing.count) panel text(s) without a German unit in the catalog — add the `de` unit for each:
            \(missing.joined(separator: "\n"))
            """)
        // counterweight — a key with an interpolation is not a catalog key and is not demanded
        XCTAssertNil(german("Playing over \\(outputs)", in: strings))
    }

    // MARK: - claim 11 (E4-9) — the instrument's label helpers take a key, not a String

    /// SOURCE-TEXT SCAN. `groupHeader("Filter")`, `labeledRow("Shape")`, `mixStripCard("Bass")` and
    /// `weatherMixGroup("Sound")` used to take `String`, so the literal reached `Text(String)` and
    /// was spelled verbatim on a German phone while every `Text("…")` beside it was translated. They
    /// take `LocalizedStringKey` now, which is what lets claim 10 walk their call sites. Since E4-12 the
    /// FX panel's `effectSection("…")` header is on the same footing (thirteen stage titles).
    /// `collapsibleGroupHeader` keeps a `String` title because its hint interpolates it, and looks
    /// the key up itself — pinned here so a tidy-up cannot put `Text(title)` back.
    func testTheLabelHelpersTakeAKey() throws {
        let code = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for signature in ["private func groupHeader(_ t: LocalizedStringKey)",
                          "private func labeledRow<Content: View>(_ label: LocalizedStringKey,",
                          "private func mixStripCard<Content: View>(_ title: LocalizedStringKey,",
                          "private func weatherMixGroup(_ title: LocalizedStringKey, params:"] {
            XCTAssertTrue(code.contains(signature), """
                `\(signature)` is gone. A label helper that takes `String` spells its literal verbatim \
                on every phone — keep the key type, or move this needle with the rename.
                """)
        }
        XCTAssertTrue(code.contains("Text(LocalizedStringKey(title))"),
                      "collapsibleGroupHeader spells its String title verbatim again — wrap it in LocalizedStringKey")
        XCTAssertTrue(code.contains(".accessibilityLabel(LocalizedStringKey(title))"),
                      "collapsibleGroupHeader's VoiceOver label is the verbatim String again")
        XCTAssertTrue(code.contains("String(localized: \"Shown\")") && code.contains("String(localized: \"Hidden\")"),
                      "the collapsible header's Shown/Hidden value is not localised")
        // counterweight — the verbatim ternary is gone from BOTH files that had it (the fine-tune disclosure and
        // the collapsible header here, the media library's disclosure), not merely joined by a localised twin
        XCTAssertFalse(code.contains("? \"Shown\" : \"Hidden\""), "a verbatim Shown/Hidden ternary is back in the instrument")
        let media = try codeOnly("Sources/Echoelmusic/Studio/MediaBrowserView.swift")
        XCTAssertFalse(media.contains("? \"Shown\" : \"Hidden\""), "a verbatim Shown/Hidden ternary is back in the media library")
        XCTAssertTrue(media.contains("String(localized: \"Shown\")"), "the media library's disclosure value is not localised")
        try assertGerman(["Shows or hides the ", " controls", "Shown", "Hidden",
                          "Look", "Voice", "Self-play", "Sound", "Weather"], "collapsible/weather header words")
        // E4-12 — the FX panel's stage header takes a key too; its thirteen titles reach the catalog
        let fx = try codeOnly("Sources/Echoelmusic/Studio/EchoelFXView.swift")
        let fxDecl = try XCTUnwrap(fx.range(of: "private func effectSection<Content: View>("),
                                   "effectSection is gone from EchoelFXView — re-anchor this needle with the rename")
        // `..<` binds tighter than `??`, so the first spelling of this line handed an optional index to
        // the range and did not compile (BfT 6559 red on 9ec521096) — a prefix needs no arithmetic.
        let fxHead = String(fx[fxDecl.lowerBound...].prefix(160))
        XCTAssertTrue(fxHead.contains("_ title: LocalizedStringKey,"),
                      "effectSection takes a String title again — its thirteen stage names would spell verbatim")
        try assertGerman(["Filter", "Saturation", "Tape / VHS", "Bitcrush", "Reverb", "Stereo Width", "Delay",
                          "Chorus", "Flanger", "Phaser", "Tremolo", "Compressor", "Limiter"], "FX stage titles")
        // E4-13 — the shared card draws title AND subtitle as keys; the nine panels' words reach the catalog
        let card = try codeOnly("Sources/Echoelmusic/Studio/EchoelPanel.swift")
        for needle in ["Text(LocalizedStringKey(title))", "Text(LocalizedStringKey(subtitle))",
                       ".accessibilityLabel(LocalizedStringKey(title))"] {
            XCTAssertTrue(card.contains(needle), "EchoelPanel draws `\(needle)` verbatim again — the panel words below would then prove nothing")
        }
        XCTAssertFalse(card.contains("Text(title)") || card.contains("Text(subtitle)"),
                       "a verbatim `Text(String)` is back in EchoelPanel")
        try assertGerman(["Workstation", "Mix", "Tempo & variations", "Master", "Field", "Mood", "Sound & texture",
                          "Effects", "Save & Export",
                          "The arrangement is the Piece stage", "Level per part", "Tap · metronome · haptic beat · ideas",
                          "Master level · EBU R128 loudness", "Character of the composition",
                          "Shape the timbre — exact to 0.0001", "Production character",
                          "Set the loop length the Record tile uses · choose how much of the strip you see · see what can be kept · put your city in the name · the default sound"],
                         "panel titles and subtitles")
        // E4-14 — the loudness grid's readout label is a key; its four names reach the catalog (units stay EBU tokens)
        let grid = try codeOnly("Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift")
        XCTAssertTrue(grid.contains("private func readout(_ label: LocalizedStringKey, _ value: String, _ unit: String, _ color: Color)"),
                      "readout takes a String label again — Short-term / Integrated / True peak / Range would spell verbatim")
        try assertGerman(["Short-term", "Integrated", "True peak", "Range"], "loudness readout names")
        // E4-15 — the media cards' action label draws its title as a key; the three actions (+ Undo) reach the catalog
        let media = try codeOnly("Sources/Echoelmusic/Studio/MediaActionLabel.swift")
        XCTAssertTrue(media.contains("Text(LocalizedStringKey(title))") && !media.contains("Text(title)"),
                      "MediaActionLabel draws its title verbatim again — Choose Photo / Apply to Visuals / Choose Video would not translate")
        try assertGerman(["Choose Photo", "Apply to Visuals", "Choose Video", "Undo"], "media action titles")
        // E4-16 — the selected-part bar: titles as keys, every VoiceOver sentence localised at its caller
        let bar = try codeOnly("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertTrue(bar.contains("private func button(_ title: LocalizedStringKey, _ systemImage: String, enabled: Bool, showsTitle: Bool,"),
                      "the selected-part bar's button takes a String title again — its seven words would spell verbatim")
        for head in ["Trim the selected part so it starts at ", "Trim the selected part so it ends at ", "Split the selected part at "] {
            XCTAssertTrue(bar.contains("String(localized: \"\(head)\")"), "the sentence `\(head)…` is spelled verbatim again — its head is a key, the bar label is appended")
        }
        for label in ["Move the selected part one bar earlier", "Move the selected part one bar later",
                      "Copy the selected part to right after it", "Remove the selected part. Undo brings it back"] {
            XCTAssertTrue(bar.contains("label: String(localized: \"\(label)\")"), "the button label `\(label)` is passed verbatim again")
        }
        try assertGerman(["Earlier", "Later", "Trim start", "Trim end", "Split", "Copy", "Remove",
                          "Move the selected part one bar earlier", "Move the selected part one bar later",
                          "Copy the selected part to right after it", "Remove the selected part. Undo brings it back",
                          "The start cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays",
                          "Trim the selected part so it starts at ",
                          "The end cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays",
                          "Trim the selected part so it ends at ", "This part is too short to split",
                          "Splitting here would change which overlapping part plays", "Split the selected part at "],
                         "selected-part bar words")
        // E4-17 — the note editor: titles as keys; every VoiceOver sentence head + spoken scope + tail; the grid words
        let editor = try codeOnly("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        XCTAssertTrue(editor.contains("private func button(_ title: LocalizedStringKey, _ systemImage: String, enabled: Bool, label: String,"),
                      "the note editor's button takes a String title again — Fit / Quantize / Lower / Higher … would spell verbatim")
        for head in ["Move ", "Snap the starts of ", "Copy ", "Delete ", "Sets ", "the selected note", "every note in this part"] {
            XCTAssertTrue(editor.contains("String(localized: \"\(head)\")"), "the editor spells `\(head)…` verbatim again")
        }
        XCTAssertFalse(editor.contains("label: \"Move"), "a verbatim interpolated `Move …` label is back in the note editor")
        let gridWords = try codeOnly("Sources/Echoelmusic/Sequencer/ClipNoteEdit.swift")
        for word in ["sixteenth", "eighth", "quarter note"] {
            XCTAssertTrue(gridWords.contains("String(localized: \"\(word)\")"), "QuantizeGrid speaks `\(word)` verbatim again")
        }
        try assertGerman(["Fit", "−1 step", "+1 step", "Quantize",
                          "Lower", "Higher", "Deselect", "Show the octave below",
                          "Show the octave above", "Clear the note selection", "Move ", " down an octave",
                          " down a semitone", " up a semitone", " up an octave", " to the nearest notes of ",
                          " down one step of ", " up one step of ", "Snap the starts of ", " to the nearest ",
                          "Copy ", " to right after themselves, and select the copies", "Delete ", "Sets ",
                          " to one velocity", "All notes in this part", "every note in this part", "Selection not on screen — Lower / Higher to see it",
                          "no note — the selection is not on screen", "1 selected", " selected", "the selected note",
                          "the ", " selected notes", "sixteenth", "eighth",
                          "quarter note", "Duplicate", "Delete"],
                         "note editor words")
        // E4-18 — the guide's arrows, the Echoel instance line and the Workstation's Save/Open doors
        let guide = try codeOnly("Sources/Echoelmusic/Studio/GuideOverlay.swift")
        XCTAssertTrue(guide.contains("private func pageButton(_ symbol: String, label: LocalizedStringKey, disabled: Bool,"),
                      "the guide's page arrows take a String label again — VoiceOver would hear English on every phone")
        let instance = try codeOnly("Sources/Echoelmusic/Studio/EchoelInstanceLine.swift")
        XCTAssertTrue(instance.contains("private func fact(_ name: LocalizedStringKey, _ value: String)"),
                      "the instance line's fact name is a String again — Genre / FX would spell verbatim")
        XCTAssertTrue(instance.contains("String(localized: \"Echoel plays \")") && instance.contains("String(localized: \", FX character \")"),
                      "the instance line's VoiceOver sentence lost its localised head or middle")
        XCTAssertFalse(instance.contains("accessibilityLabel(\"Echoel plays"), "the verbatim interpolated instance sentence is back")
        let doors = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(doors.contains("private func door(_ title: LocalizedStringKey, systemImage: String, object: String, enabled: Bool,")
                      && doors.contains("spoken: LocalizedStringKey, hint: LocalizedStringKey) -> some View {"),
                      "the Workstation's Save/Open door takes String words again — title, spoken name or hint would spell verbatim")
        try assertGerman(["Previous guide card", "Next guide card", "Genre", "FX",
                          "Echoel plays ", ", FX character ", "Names the piece and saves it, with its tracks and parts", "Shows your saved pieces. Opening one replaces the piece here",
                          "Hide guide", "The Guide button in the head, the ⓘ, brings it back", "Guide", "Save",
                          "Open", "Save this piece", "Open a saved piece"],
                         "guide arrow, instance line and door words")
    }

    // MARK: - claim 12 (E4-10) — every value-field label has a German unit

    /// SOURCE-TEXT SCAN + END-TO-END on `WeatherMood.Param`. `EchoelValueField` draws `label` as a
    /// catalog KEY since E4-10 (three sites: the two `Text` branches and the VoiceOver label; the
    /// number pad's title is the localised String). That is what makes walking its literal labels
    /// meaningful: the direct `EchoelValueField(label: "…")` sites app-wide (a `cond ? "a" : "b"`
    /// label counts both arms), the instrument's `param`/`knob`/`moodKnob` pass-throughs and the FX
    /// panel's `field("…")` helper. The weather mixers reach the field through `param.label`, so
    /// those eight are driven on the enum itself.
    func testEveryValueFieldLabelHasAGermanUnit() throws {
        let root = try repoRoot()
        let strings = try catalogStrings()
        let field = try codeOnly("Sources/Echoelmusic/Studio/EchoelValueField.swift")
        XCTAssertTrue(field.contains("Text(LocalizedStringKey(label))"),
                      "EchoelValueField draws its label as a verbatim String again — the walk below would then prove nothing")
        XCTAssertTrue(field.contains(".accessibilityLabel(LocalizedStringKey(label))"),
                      "EchoelValueField's VoiceOver label is the verbatim String again")
        XCTAssertTrue(field.contains("EchoelNumberPad(title: String(localized: String.LocalizationValue(label))"),
                      "the number pad's title no longer follows the localised row label")
        XCTAssertFalse(field.contains("Text(label)"), "a verbatim `Text(label)` is back in EchoelValueField")

        let lit = #""((?:[^"\\]|\\.)*)""#
        let direct = try NSRegularExpression(pattern: #"\bEchoelValueField\(\s*label:\s*(?:[A-Za-z.]+\s*\?\s*)?"# + lit + #"(?:\s*:\s*"# + lit + #")?"#)
        let studioHelpers = try NSRegularExpression(pattern: #"\b(?:param|knob|moodKnob)\(\s*"# + lit)
        let fxHelper = try NSRegularExpression(pattern: #"\bfield\(\s*"# + lit)
        var sites = 0, missing: [String] = [], seen = Set<String>()
        func collect(_ regex: NSRegularExpression, in code: String) {
            for m in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                for g in 1..<m.numberOfRanges {
                    guard m.range(at: g).location != NSNotFound, let r = Range(m.range(at: g), in: code) else { continue }
                    let key = String(code[r])
                    if key.isEmpty || key.contains("\\") || key.contains("%") { continue }
                    sites += 1
                    if seen.insert(key).inserted, german(key, in: strings) == nil { missing.append(key) }
                }
            }
        }
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic")
        }
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            collect(direct, in: code)
            if url.lastPathComponent == "EchoelStudioView.swift" { collect(studioHelpers, in: code) }
            if url.lastPathComponent == "EchoelFXView.swift" { collect(fxHelper, in: code) }
        }
        XCTAssertGreaterThan(sites, 120, "the walk found \(sites) value-field label sites — it did not read the tree")
        XCTAssertEqual(missing, [], """
            \(missing.count) value-field label(s) without a German unit — add the `de` unit for each:
            \(missing.joined(separator: "\n"))
            """)
        for p in WeatherMood.Param.allCases {
            XCTAssertNotNil(german(p.label, in: strings), "weather mixer label \"\(p.label)\" has no German unit")
        }
    }

    // MARK: - claim 5 — the German for "Piece" is the glossary's word, read from the glossary

    func testTheGermanPieceIsTheGlossaryWord() throws {
        let glossary = try repoRoot().appendingPathComponent("docs/dev/GLOSSARY.md")
        guard let text = try? String(contentsOf: glossary, encoding: .utf8),
              let row = text.split(separator: "\n").first(where: { $0.hasPrefix("| piece |") }) else {
            throw XCTSkip("docs/dev/GLOSSARY.md has no `| piece |` row — re-anchor (#454)")
        }
        let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 2 else { throw XCTSkip("glossary row shape changed (#454)") }
        let wort = cells[1]
        let strings = try catalogStrings()
        for key in ["Piece", "Playing piece", "Unsaved piece", "Play the piece"] {
            guard let de = german(key, in: strings) else { XCTFail("\"\(key)\" has no German unit"); continue }
            XCTAssertTrue(de.value.contains(wort), """
                the German for "\(key)" is "\(de.value)" and does not carry the glossary word "\(wort)" \
                (docs/dev/GLOSSARY.md, row `piece`). One word per thing holds in German too.
                """)
        }
    }
}
