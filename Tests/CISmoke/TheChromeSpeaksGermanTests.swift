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
// (parent: all absent, eight units missing — ONE finding). E4-19 added the Routing MIDI label's signature, the
// guide counter's two seams and the eight Scale-family headers (parent: all absent, eleven units missing — ONE finding).
// E4-20 added the 23 Genre shelf headers (parent: 0/23 localised, 22 units missing — ONE finding). E4-21 added the
// 57 scale display names plus the shortName counterweight (parent: 0/57, 57 units missing — ONE finding). E4-22 added
// the icon tile's key wrap, the Record tile's four state titles and the two spoken accidentals (parent: all verbatim,
// six units missing — ONE finding). E4-23 added the eight Learn cards (guide + safety), the six Learn headings and the
// bio disclaimer as one-literal keys (parent: 0/8 titles, `+` chains present, 31 units missing — ONE finding). E4-24 added
// the Piece stage's counted sentences (tracks/parts/bars, orphans, automated parameters), the file-tempo row and the
// root chrome's position/file/piece readouts as noun keys and seams (parent: all verbatim, 29 units missing — ONE finding).
// E4-25 added the bar/beat vocabulary of the three model helpers (SessionGrid.label · TrackParts.title/spanTitle/lengthText ·
// SongAutomationEdit.countLabel) as keys beside the numbers, English byte-identical (parent: all verbatim, 8 units missing —
// ONE finding). E4-26 added the frames around that vocabulary — the part bar's heading, the parts row's spoken label, the
// curve editor's point line, Remove label and spoken summary (parent: all interpolated, 5 units missing — ONE finding). E4-27
// added the position readout (Bar n · Beat b), the arrange canvas's landing announcement and the Session launch surface
// (parent: all verbatim, 10 units missing — ONE finding). E4-28 added the automation status strip, the layer words and
// the number pad's Range/Confirm/Default (parent: all verbatim, 12 units missing — ONE finding). E4-29 added the media library's relink note, files line, Relink/Place/Preview
// labels and hint, missing/no-match/usage words, and the routing surface's network target, connection count and route
// label/value (parent: all interpolated or verbatim, 23 units missing — ONE finding). E4-30 added the Compose guide — five step titles, details,
// waiting reasons, the notes-opened note, the spoken states and row, the header's next line (parent: all verbatim,
// 27 units missing — ONE finding). E4-31 added the bio info sheet (metric titles, unit, summaries, details, origin
// notes, demo prefix, percentage and modulation sentences) and the sound map's twelve strings (parent: all verbatim,
// 35 units missing — ONE finding). E4-32 added the pulse pill's spoken value and the Live Colabo peer row's spoken
// line — demo prefix as a key, " beats per minute", ", coherence ", "no pulse yet", "not available", "No pulse lock"
// (parent: all interpolated or verbatim, 6 units missing — ONE finding). E4-33 added the last two demo-prefix
// sentences — the always-on channel row's three paths and the FX contribution row's two (parent: all interpolated,
// 9 units missing — ONE finding). E4-34 added the always-on channel names, channel words and Sound-panel row names
// (parent: all verbatim, 8 units missing — ONE finding). E4-35 added the FX route names — thirteen targets, seven
// carriers, six matrix sources (parent: all verbatim, 15 units missing — ONE finding). E4-36 added the pulse ladder's
// four rung words and four spoken sentences (parent: all verbatim, 8 units missing — ONE finding). E4-37 added the long
// always-on / Bio-panel sentences of AlwaysOnBioChannel — demo subject, FX footer, Bio-panel claim, Sound-panel line and
// empty states, breath-voice and Auto hints and captions (parent: all verbatim or interpolated, 32 units missing — ONE finding).
// E4-38 added the bio strip's banner, driving-dot states, source tag and camera captions, and the two mood pads' titles,
// axis captions and spoken label/value/actions (parent: verbatim, interpolated or unit-less, 20 units missing — ONE finding).
// E4-39 added the visual window bar's spoken labels, the window-size words, the WAV gap and the header's monitor button
// and note-name hint (parent: ternaries and a `+` chain of literals, 17 units missing — ONE finding). E4-40 added the Perform
// plate's four sentences and disclosure value, and the FX panel's Morph label, four conditional footers/headers, dropout note
// and neutral-0.50 footer (parent: stored statics, ternaries and `+` chains, 20 units missing — ONE finding). E4-41 added the
// photo card — PhotoSeedText's sentences, colour, change and field names, the percent lines, the spoken disclosure value and
// Undo label/hint via `MediaLookUndo.spokenMedium` (parent: stored, interpolated or ternary literals, 23 units missing — ONE finding).
// E4-42 added the video card — VideoSeedText's unreadable/reading/length/cuts/bars/sound and field names, the card's lines,
// heading, Apply fallback and spoken disclosure value / Undo label (parent: the same four shapes, 22 units missing — ONE finding).
// E4-43 added the Workstation's remaining ternaries — Mute/Solo value, Warp text/value/hint, Pitch hint, Play/Stop word and label,
// tempo-field label, Compose-guide disclosure value/hint (parent: ternaries of bare literals, 10 units missing — ONE finding).
// E4-44 added the three On/Off siblings — Perform mix switch, header Guide button, Workstation click toggle (parent: a bare
// `? "On" : "Off"` ternary in each, no units missing — ONE finding).
// E4-45 added the blocked-Apply sentence — `MediaLookUndo.applyBlockedReason` as seams around `spokenMedium`, which moved
// into the owner (parent: an interpolated identifier in the spoken sentence, 2 units missing — ONE finding).
// E4-46 added EchoelStudioView's remaining sites — Explore/New, the variation row's spoken label, the visual-window button,
// the preset hint, the look chip's value/hint, the favourite labels, „Default sound“ (parent: ternaries and interpolated
// labels of bare literals, 20 units missing — ONE finding). E4-47 added the four analysis readouts — the spectrum's spoken
// form, the scope's Silent/Peak pair, the wavefront's three sentences, the Poincaré lines (parent: interpolated literals
// and bare `sharp`/`flat` arms, 22 units missing — ONE finding). Claim 12
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
    static let untranslatedPanelWords: Set<String> = ["BPM", "Create from Within", "Demo", "E", "ECHOEL", "Echoelmusic", "OK", "Poincaré plot", "Studio", "Tempo", "WAV FAILED", "WAV …"]

    func testEveryPanelTextOfTheReachableChromeFilesHasAGermanUnit() throws {
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
    // @MainActor because the runtime counterweights call statics on @MainActor Views
    // (`FloatingVisualWindow.wavAccessibilityValue`, `PerformSessionView.sectionTitle`) — the bundle's
    // convention for that call shape; Build for Testing 6577 on 9d46d79f5 was red without it.
    @MainActor func testTheLabelHelpersTakeAKey() throws {
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
        // `mediaLabel`, not `media` — that name is already bound to the media library eleven lines up, and the
        // redeclaration did not compile (BfT 6561 red on 4d53fd149)
        let mediaLabel = try codeOnly("Sources/Echoelmusic/Studio/MediaActionLabel.swift")
        XCTAssertTrue(mediaLabel.contains("Text(LocalizedStringKey(title))") && !mediaLabel.contains("Text(title)"),
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
        // E4-19 — the Routing MIDI status label, the guide's card counter, the Scale picker's family headers
        let routing = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        XCTAssertTrue(routing.contains("private func statusLine(label: LocalizedStringKey, line: String, caption: String, spoken: String)"),
                      "the Routing status line takes a String label again — MIDI in / MIDI out would spell verbatim")
        XCTAssertTrue(guide.contains("String(localized: \", card \")") && guide.contains("String(localized: \" of \")"),
                      "the guide's card counter lost a localised seam")
        XCTAssertFalse(guide.contains("card \\(index"), "the verbatim interpolated card counter is back in the guide")
        let families = try codeOnly("Sources/Echoelmusic/Sequencer/MusicalKey.swift")
        for title in ["Modes", "Minor & Altered", "Pentatonic & Blues", "Symmetric", "European Folk", "Maqām & Near East", "East & Southeast Asia", "Hindustani & Carnatic"] {
            XCTAssertTrue(families.contains("return String(localized: \"\(title)\")"), "`Scale.Family.title` spells `\(title)` verbatim again")
        }
        try assertGerman(["MIDI in", ", card ", " of ", "Modes",
                          "Minor & Altered", "Pentatonic & Blues", "Symmetric", "European Folk",
                          "Maqām & Near East", "East & Southeast Asia", "Hindustani & Carnatic", "MIDI out"],
                         "routing label, guide counter and scale family words")
        // E4-20 — the Genre picker's 23 shelf headers (`Subcategory.title`) go through String(localized:)
        let shelves = try codeOnly("Sources/Echoelmusic/Sequencer/MusicStyle.swift")
        let shelfTitles = ["Still Pads", "Moving Ambient", "Cinematic Atmospheres", "Techno",
                          "House", "Trance", "Synth & Electro", "Rock",
                          "Punk", "Metal", "Jazz", "Soul",
                          "Hip-Hop", "R&B & Pop", "Caribbean", "Classical & Romantic",
                          "Gospel & Spiritual", "Near East & C. Asia", "Latin America", "Lo-Fi & Hazy",
                          "Dub & Echo", "Dark Synth Scenes", "European Folk"]
        for title in shelfTitles {
            XCTAssertTrue(shelves.contains("return String(localized: \"\(title)\")"), "`Subcategory.title` spells `\(title)` verbatim again")
        }
        try assertGerman(shelfTitles, "genre shelf headers")
        // E4-21 — the 57 scale display names go through String(localized:); the SHORT name (share filenames) does not
        let scaleNames = ["Major", "Minor", "Dorian", "Phrygian", "Lydian",
                          "Mixolydian", "Pentatonic Major", "Pentatonic Minor", "Harmonic Minor", "Chromatic",
                          "Locrian", "Melodic Minor", "Lydian Dominant", "Altered", "Bebop Dominant",
                          "Blues Minor", "Blues Major", "Whole Tone", "Diminished (W–H)", "Diminished (H–W)",
                          "Phrygian Dominant", "Harmonic Major", "Hungarian Minor", "Double Harmonic", "Neapolitan Minor",
                          "Neapolitan Major", "Romanian Minor", "Persian", "Hirajoshi", "Iwato",
                          "Insen", "Yo", "In (Sakura)", "Egyptian", "Pelog",
                          "Enigmatic", "Prometheus", "Augmented", "Tritone", "Hungarian Major",
                          "Bebop Major", "Major Locrian", "Lydian Augmented", "Spanish 8-Tone", "Kumoi",
                          "Messiaen 3", "Messiaen 4", "Messiaen 5", "Messiaen 6", "Messiaen 7",
                          "Marwa", "Purvi", "Todi (Hindustani)", "Malkauns", "Charukeshi",
                          "Hamsadhwani", "Shanmukhapriya"]
        for name in scaleNames {
            XCTAssertTrue(families.contains("return String(localized: \"\(name)\")"), "`Scale.displayName` spells `\(name)` verbatim again")
        }
        XCTAssertTrue(families.contains("return \"maj\"") && families.contains("return \"harm\""),
                      "`Scale.shortName` is no longer a plain literal — it is the key half of every share filename and must read the same on every device")
        try assertGerman(scaleNames, "scale display names")
        // E4-22 — the icon tile draws its word as a key; the Record tile's state title and the spoken accidentals are keys
        let tile = try codeOnly("Sources/Echoelmusic/Studio/EchoelIconTile.swift")
        XCTAssertTrue(tile.contains("Text(LocalizedStringKey(title))") && !tile.contains("Text(title)"),
                      "EchoelIconTile draws its word verbatim again — Save / Open / Learn would not translate")
        XCTAssertTrue(code.contains("String(localized: \"Writing\")") && !code.contains("? \"Stop\" : \"Recording\""),
                      "the Record tile's state title spells Stop / Recording / Writing verbatim again")
        let notes = try codeOnly("Sources/Echoelmusic/Sequencer/NoteNaming.swift")
        XCTAssertTrue(notes.contains("with: String(localized: \" sharp\")") && notes.contains("with: String(localized: \" flat\")"),
                      "`spokenName` expands ♯/♭ to a verbatim English word again")
        try assertGerman(["MIDI", "Open", "Live Colabo", "Learn", "Save", "Keep last", "Stop", "Recording", "Writing", "Record", " sharp", " flat"], "icon tile, record tile and accidental words")
        // E4-23 — the Learn/guide cards (six guide + two safety entries), the six Learn headings and the bio
        // disclaimer are catalog keys: ONE `String(localized:)` literal per field, no `+` chain. The detail keys
        // are read back at RUNTIME (en unit == key in the simulator) so no 900-character literal lives here.
        let learn = try codeOnly("Sources/Echoelmusic/Studio/LearnLibrary.swift")
        XCTAssertEqual(learn.components(separatedBy: "title: String(localized: \"").count - 1, 8, "a Learn card title is a verbatim String again")
        XCTAssertEqual(learn.components(separatedBy: "summary: String(localized: \"").count - 1, 8, "a Learn card summary is a verbatim String again")
        XCTAssertEqual(learn.components(separatedBy: "detail: String(localized: \"").count - 1, 7, "a Learn card detail is a verbatim String or a `+` chain again")
        XCTAssertTrue(learn.contains("detail: BioMetric.disclaimer + String(localized: \" Bio readings are most accurate"), "the scope card lost its localised tail seam")
        XCTAssertFalse(learn.contains("\"\n                    + \""), "a Learn card detail is a `+` chain again — a seam splits the catalog key")
        for heading in ["Start Here", "Your Body", "Body Science", "Music Theory", "Light & Colour", "Safety & Scope"] {
            XCTAssertTrue(learn.contains("return String(localized: \"\(heading)\")"), "`LearnSection.title` spells `\(heading)` verbatim again")
        }
        let metricInfo = try codeOnly("Sources/Echoelmusic/Studio/BioMetricInfo.swift")
        XCTAssertTrue(metricInfo.contains("public static let disclaimer = String(localized: \"For music and self-observation only"), "`BioMetric.disclaimer` is a verbatim String again")
        let cards = LearnLibrary.guideEntries + LearnLibrary.safetyEntries
        XCTAssertEqual(cards.count, 8, "the guide + safety card set changed size — re-derive this block")
        // ⛔ 8cbbda285 read `strings` here without declaring it — claim 11 never loads the catalog itself
        // (only `assertGerman` does), so Build for Testing 6565 was red on `cannot find 'strings' in scope`.
        let strings = try catalogStrings()
        for card in cards {
            XCTAssertNotNil(german(card.title, in: strings), "no German unit for the Learn card title `\(card.title)`")
            XCTAssertNotNil(german(card.summary, in: strings), "no German unit for the Learn card summary of `\(card.id)`")
            if card.id != "safety.scope" {   // its detail is the disclaimer + a tail seam, pinned separately below
                XCTAssertNotNil(german(card.detail, in: strings), "no German unit for the Learn card detail of `\(card.id)`")
            }
        }
        try assertGerman(["Start Here", "Your Body", "Body Science", "Music Theory", "Light & Colour", "Safety & Scope", "For music and self-observation only — not a medical device and not for diagnosis. Readings are approximate; don’t use them for health decisions.", " Bio readings are most accurate from a chest strap; wrist and camera are estimates. Breathing guides are optional and never forced."], "Learn headings, disclaimer and scope tail")

        // E4-24 — the Piece stage's counted sentences and the root chrome's position/file/piece readouts.
        // A count is a NUMBER next to a catalog NOUN per grammatical number (Spur/Spuren · Teil/Teile ·
        // Takt/Takte); a sentence with a moving middle is a head seam + the value + a tail seam. Never a
        // format key: `"\(n) tracks"` would be the runtime key `%lld tracks`, which no catalog carries.
        let piece = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        for seam in ["(tracks == 1 ? String(localized: \"track\") : String(localized: \"tracks\"))",
                     "(parts == 1 ? String(localized: \"part\") : String(localized: \"parts\"))",
                     "(bars == 1 ? String(localized: \"bar\") : String(localized: \"bars\"))",
                     "String(localized: \"Arrangement: \") + \"\\(tracks) \"",
                     "(count == 1 ? String(localized: \"part belongs\") : String(localized: \"parts belong\"))",
                     "+ String(localized: \" to a track this piece no longer has.\")",
                     "(count == 1 ? String(localized: \"automated parameter\") : String(localized: \"automated parameters\"))",
                     "clip.name + String(localized: \" · measuring tempo…\")",
                     "return String(localized: \"The file's tempo is still being measured.\")",
                     "spoken: LocalizedStringKey) -> some View",
                     "String(localized: \"Sets this file's tempo to \") + String(format: \"%.1f\", target) + String(localized: \" BPM\")"] {
            XCTAssertTrue(piece.contains(seam), "WorkstationView lost the E4-24 seam `\(seam)`")
        }
        for verbatim in ["Text(\"\\(tracks) \\(tracks == 1", "Text(\"\\(count) automated", "parts belong\") to a track",
                         "return \"\\(clip.name) · measuring", "return \"The file's tempo", "spoken: String) -> some View",
                         "accessibilityHint(\"Sets this file's tempo"] {
            XCTAssertFalse(piece.contains(verbatim), "WorkstationView speaks a counted or file-tempo sentence verbatim again: `\(verbatim)`")
        }
        let rootChrome = try codeOnly("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        for seam in ["String(localized: \"Bar \") + \"\\(barInLoop + 1)\" + String(localized: \" of \")",
                     "Text(String(localized: \"File: \") + session.sessionName(bpm: transport.tempo))",
                     ".accessibilityLabel(String(localized: \"Piece: \") + readableFields.joined(separator: \", \"))"] {
            XCTAssertTrue(rootChrome.contains(seam), "WorkspaceView lost the E4-24 seam `\(seam)`")
        }
        for verbatim in ["accessibilityValue(\"Bar \\(barInLoop", "Text(\"File: \\(", "accessibilityLabel(\"Piece: \\("] {
            XCTAssertFalse(rootChrome.contains(verbatim), "WorkspaceView speaks a readout verbatim again: `\(verbatim)`")
        }
        // COUNTERWEIGHT: `Text("loop \(barInLoop + 1)/\(bars)")` stays verbatim on purpose — "Loop" is the
        // German word too, and `TheBarCountHasACarrierTests` pins that exact carrier (#490).
        XCTAssertTrue(rootChrome.contains("Text(\"loop \\(barInLoop + 1)/\\(bars)\")"), "the loop carrier moved — re-anchor TheBarCountHasACarrierTests first")
        try assertGerman(["track", "tracks", "part", "parts", "bar", "bars", "Arrangement: ", "bars long",
                          "part belongs", "parts belong", " to a track this piece no longer has.",
                          "parts belong to a track this piece no longer has", "automated parameter", "automated parameters",
                          " · measuring tempo…", " · turn Warp off to change its tempo", " · tempo not set — enter it to use Warp",
                          "The file's tempo is still being measured.", "Turn Warp off to change this file's tempo.",
                          "This file's own tempo. Warp uses it to fit the file to the piece tempo.",
                          "Not set. Starts at the piece tempo; enter the file's own tempo to enable Warp.",
                          "Halve tempo", "Double tempo", "Sets this file's tempo to ", " BPM",
                          "Bar ", " of ", ", beat ", "File: ", "Piece: "], "Piece-stage counts and root readouts")

        // E4-25 — the bar/beat VOCABULARY lives in three model helpers, and every part title, scene label and
        // automation count is composed from them: `SessionGrid.label` (Bar n / Bar n beat b), `TrackParts.title`,
        // `spanTitle` and `lengthText` (n bars / n beats / to bar n), `SongAutomationEdit.countLabel` (n points,
        // and 1 after the end). Each word is a catalog key beside the number; the English is byte-identical, which
        // the RUNTIME pins in TheSessionLaunchesWhatTheSongPlaysTests / TheTrackPartsAreArrangedThroughTheStoreTests /
        // TheSongAutomationIsDrawnThroughOneWriterTests keep proving ("Bar 5", "1 bar", "0.31 bars", "1 point").
        let sessionGrid = try codeOnly("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        XCTAssertTrue(sessionGrid.contains("guard inBar != 0 else { return String(localized: \"Bar \") + \"\\(bar)\" }"), "`SessionGrid.label` spells Bar verbatim again")
        XCTAssertTrue(sessionGrid.contains("String(localized: \"Bar \") + \"\\(bar)\" + String(localized: \" beat \")"), "`SessionGrid.label` lost the beat seam")
        XCTAssertFalse(sessionGrid.contains("return \"Bar \\(bar)"), "`SessionGrid.label` returns a verbatim `Bar n` again")
        let partsFile = try codeOnly("Sources/Echoelmusic/Studio/TrackPartsView.swift")
        for seam in ["SessionGrid.label(forTick: part.startTick) + \" · \" + lengthText(part.lengthTicks)",
                     "title(part) + String(localized: \" · to bar \") + \"\\(to)\"",
                     "n == 1 ? String(localized: \"1 bar\") : \"\\(n) \" + String(localized: \"bars\")",
                     "n == 1 ? String(localized: \"1 beat\") : \"\\(n) \" + String(localized: \"beats\")",
                     "String(format: \"%.2f\", Double(ticks) / Double(bar)) + \" \" + String(localized: \"bars\")"] {
            XCTAssertTrue(partsFile.contains(seam), "TrackParts lost the E4-25 seam `\(seam)`")
        }
        for verbatim in ["\"1 bar\" : \"\\(n) bars\"", "\"1 beat\" : \"\\(n) beats\"", "· to bar \\(to)\"", "\"%.2f bars\""] {
            XCTAssertFalse(partsFile.contains(verbatim), "TrackParts spells a length verbatim again: `\(verbatim)`")
        }
        let automation = try codeOnly("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        XCTAssertTrue(automation.contains("count == 1 ? String(localized: \"1 point\") : \"\\(count) \" + String(localized: \"points\")"), "`countLabel` spells points verbatim again")
        XCTAssertTrue(automation.contains("base + String(localized: \", and 1 after the end of the piece\")"), "`countLabel` lost its past-the-end seam")
        XCTAssertFalse(automation.contains("\"1 point\" : \"\\(count) points\""), "`countLabel` is a verbatim String again")
        // RUNTIME COUNTERWEIGHT: in the test bundle's English the composed words are unchanged — a catalog key that
        // altered the English would be a copy change hiding in a localisation slice.
        XCTAssertEqual(SessionGrid.label(forTick: TimelineTime.ticksPerBar + 2 * TimelineTime.ticksPerBeat), "Bar 2 beat 3")
        XCTAssertEqual(TrackParts.lengthText(2 * TimelineTime.ticksPerBeat), "2 beats")
        XCTAssertEqual(SongAutomationEdit.countLabel(inSongPoints: 3, continuesPastEnd: true), "3 points, and 1 after the end of the piece")
        try assertGerman(["Bar ", " beat ", " · to bar ", "1 bar", "bars", "1 beat", "beats", "1 point", "points",
                          ", and 1 after the end of the piece"], "bar/beat vocabulary of the model helpers")

        // E4-26 — the views that FRAME the composed bar words: the part bar's heading, the parts row's spoken
        // label, the automation editor's picked-point line, its Remove label and the curve's spoken summary. Each
        // is a head seam (or a middle seam) around the E4-25 vocabulary, never a format key.
        let partBar = try codeOnly("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertTrue(partBar.contains("Text(String(localized: \"Selected part · \") + title)"), "the part bar's heading is verbatim again")
        XCTAssertFalse(partBar.contains("Text(\"Selected part · \\(title)\")"), "the part bar interpolates its heading again")
        let partsRow = try codeOnly("Sources/Echoelmusic/Studio/TrackPartsView.swift")
        XCTAssertTrue(partsRow.contains(".accessibilityLabel(String(localized: \"Part at \") + title)"), "the parts row's spoken label is verbatim again")
        XCTAssertFalse(partsRow.contains("accessibilityLabel(\"Part at \\(title)\")"), "the parts row interpolates its spoken label again")
        let curveEditor = try codeOnly("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        for seam in ["Text(String(localized: \"Point at \") + SessionGrid.label(forTick: point.tick))",
                     ".accessibilityLabel(String(localized: \"Remove the point at \") + SessionGrid.label(forTick: point.tick))",
                     ".accessibilityLabel(title + String(localized: \" automation: \") + pointCountLabel)"] {
            XCTAssertTrue(curveEditor.contains(seam), "SongAutomationEditor lost the E4-26 seam `\(seam)`")
        }
        for verbatim in ["Text(\"Point at \\(", "accessibilityLabel(\"Remove the point at \\(", "accessibilityLabel(\"\\(title) automation: \\("] {
            XCTAssertFalse(curveEditor.contains(verbatim), "SongAutomationEditor interpolates a sentence again: `\(verbatim)`")
        }
        try assertGerman(["Selected part · ", "Part at ", "Point at ", "Remove the point at ", " automation: "], "part bar, parts row and curve editor frames")

        // E4-27 — the last bar-word producers: the transport's position readout (`WorkstationSummary.positionText`,
        // Bar n · Beat b), the arrange canvas's landing announcement, and the Session launch surface (scene/part
        // labels, the launched-part Stop, the overflow line, the three cell words and the two spoken fallbacks).
        let summary = try codeOnly("Sources/Echoelmusic/Studio/WorkstationSummary.swift")
        XCTAssertTrue(summary.contains("String(localized: \"Bar \") + \"\\(barNumber(forTick: t))\" + String(localized: \" · Beat \") + \"\\(beat)\""), "`positionText` spells Bar/Beat verbatim again")
        XCTAssertFalse(summary.contains("\"Bar \\(barNumber(forTick: t)) · Beat"), "`positionText` is a verbatim String again")
        let canvas = try codeOnly("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        XCTAssertTrue(canvas.contains("Announcement(String(localized: \"Part at \") + SessionGrid.label(forTick: target))"), "the landing announcement spells Part at verbatim again")
        XCTAssertFalse(canvas.contains("Announcement(\"Part at \" +"), "the landing announcement is verbatim again")
        let launch = try codeOnly("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        for seam in ["case .queued:   return String(localized: \"Queued\")",
                     "case .playing:  return String(localized: \"Playing\")",
                     "case .stopping: return String(localized: \"Stopping\")",
                     "+ String(localized: \" later scenes are not shown.\")",
                     ".accessibilityLabel(String(localized: \"Launch scene at \") + title)",
                     "?? String(localized: \"Not the current scene\")",
                     ".accessibilityLabel(track.name + String(localized: \", part at \") + title)",
                     "?? String(localized: \"Not launched\")",
                     "Text(String(localized: \"Stop \") + track.name)",
                     ".accessibilityLabel(String(localized: \"Stop the launched part on \") + track.name)"] {
            XCTAssertTrue(launch.contains(seam), "SessionLaunchView lost the E4-27 seam `\(seam)`")
        }
        for verbatim in ["return \"Queued\"", "Text(\"\\(scenes.count - SessionGrid.sceneLimit) later scenes", "accessibilityLabel(\"Launch scene at \\(",
                         "?? \"Not the current scene\"", "accessibilityLabel(\"\\(track.name), part at", "?? \"Not launched\"",
                         "Text(\"Stop \\(track.name)\")", "accessibilityLabel(\"Stop the launched part on \\("] {
            XCTAssertFalse(launch.contains(verbatim), "SessionLaunchView speaks a launch sentence verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHT: the bundle's English is unchanged (the position pins keep proving `Bar 1 · Beat 1`).
        XCTAssertEqual(WorkstationSummary.positionText(forTick: TimelineTime.ticksPerBar + TimelineTime.ticksPerBeat), "Bar 2 · Beat 2")
        XCTAssertEqual(SessionGrid.word(.playing), "Playing")
        try assertGerman(["Bar ", " · Beat ", "Part at ", "Queued", "Playing", "Stopping", " later scenes are not shown.",
                          "Launch scene at ", "Not the current scene", ", part at ", "Not launched", "Stop ",
                          "Stop the launched part on "], "position readout, landing announcement and Session launch")

        // E4-28 — the automation status strip (point count, the three stop notes, the spoken sentence), the layer
        // words it composes from (`AutomationStatus.Layer.label`: Global · Part · Arrangement) and the number pad's
        // Range line, Confirm label and Default key. Noun per grammatical number, head/middle seams; never a format key.
        let strip = try codeOnly("Sources/Echoelmusic/Studio/AutomationStatusStrip.swift")
        for seam in ["Text(pointCountText)",
                     "row.pointCount == 1 ? String(localized: \"1 point\") : \"\\(row.pointCount) \" + String(localized: \"points\")",
                     "if !row.isBound { return String(localized: \"no effect\") }",
                     "if row.isOverridden { return String(localized: \"overridden\") }",
                     "if !row.isActive { return String(localized: \"off\") }",
                     "row.displayName + \", \" + row.layer.label + String(localized: \" automation, \") + spanText",
                     "parts.append(String(localized: \"no effect, nothing is connected to this parameter\"))",
                     "parts.append(String(localized: \"overridden by a later layer\"))",
                     "parts.append(String(localized: \"switched off\"))"] {
            XCTAssertTrue(strip.contains(seam), "AutomationStatusStrip lost the E4-28 seam `\(seam)`")
        }
        for verbatim in ["point\\(row.pointCount == 1", "return \"no effect\"", "return \"overridden\"", "return \"off\"",
                         "automation, \\(spanText)", "parts.append(\"no effect", "parts.append(\"overridden", "parts.append(\"switched off\")"] {
            XCTAssertFalse(strip.contains(verbatim), "AutomationStatusStrip speaks a status verbatim again: `\(verbatim)`")
        }
        let layers = try codeOnly("Sources/Echoelmusic/Sequencer/AutomationStatus.swift")
        for word in ["Global", "Part", "Arrangement"] {
            XCTAssertTrue(layers.contains("return String(localized: \"\(word)\")"), "`AutomationStatus.Layer.label` spells `\(word)` verbatim again")
        }
        let pad = try codeOnly("Sources/Echoelmusic/Studio/EchoelNumberPad.swift")
        // (Compile Check 3106: the Range line and the Default label are typed steps now — same seams, one per line)
        for seam in ["Text(rangeText)", "return String(localized: \"Range \") + bounds + suffix",
                     ".accessibilityLabel(String(localized: \"Confirm \") + title)",
                     "Label(String(localized: \"Default \") + text, systemImage: \"arrow.counterclockwise\")",
                     "let spoken: String = String(localized: \"Default \") + text + spokenUnit", ".accessibilityLabel(spoken)"] {
            XCTAssertTrue(pad.contains(seam), "EchoelNumberPad lost the E4-28 seam `\(seam)`")
        }
        for verbatim in ["Text(\"Range \\(", "accessibilityLabel(\"Confirm \\(", "Label(\"Default \\(text)\"", "accessibilityLabel(\"Default \\(text)"] {
            XCTAssertFalse(pad.contains(verbatim), "EchoelNumberPad interpolates a key again: `\(verbatim)`")
        }
        XCTAssertEqual(AutomationStatusRow.Layer.clip.label, "Part")   // RUNTIME COUNTERWEIGHT: the bundle's English is unchanged
        try assertGerman(["no effect", "overridden", "off", "1 point", "points", " automation, ",
                          "no effect, nothing is connected to this parameter", "overridden by a later layer", "switched off",
                          "Global", "Part", "Arrangement", "Range ", "Confirm ", "Default "], "automation strip, layer words and number pad")

        // E4-29 — the media library (relink note, "n of N files" line, Relink/Place/Preview labels, the preview hint,
        // the missing-file and no-match sentences, the usage words per grammatical number) and the routing surface
        // (network-target label, connection count, route label and its three spoken states). Head/middle seams beside
        // the moving value, a catalog noun per grammatical number; never a format key. The neutral joins (size · use,
        // "name, size, use") carry no key at all — a seam is added only where a WORD moves.
        let library = try codeOnly("Sources/Echoelmusic/Studio/MediaBrowserView.swift")
        for seam in ["note = String(localized: \"Relinked \") + quoted + String(localized: \" to \") + target",
                     "line(shownCount + String(localized: \" of \") + total + String(localized: \" files\"))",
                     ".accessibilityLabel(String(localized: \"Relink \") + item.clipName)",
                     "case 0:  parts = String(localized: \"no part\")",
                     "case 1:  parts = String(localized: \"1 part\")",
                     "default: parts = \"\\(item.partCount) \" + String(localized: \"parts\")",
                     "return item.clipName + String(localized: \" — expects \") + item.fileName + \" · \" + parts",
                     "return String(localized: \"No file name contains \") + quoted",
                     "Text(size + \" · \" + use)",
                     "let spoken: String = asset.displayName + \", \" + size + \", \" + use",
                     ".accessibilityLabel(String(localized: \"Place \") + asset.displayName)",
                     "playing ? String(localized: \"Stop preview\") : String(localized: \"Preview \") + asset.displayName",
                     "String(localized: \"Plays its first \") + seconds + String(localized: \" seconds\")",
                     "usage.clipIDs.isEmpty ? String(localized: \"not in the piece\") : String(localized: \"imported, not placed yet\")",
                     "case 1:  return String(localized: \"in 1 part\")",
                     "default: return String(localized: \"in \") + \"\\(usage.partCount)\" + String(localized: \" parts\")"] {
            XCTAssertTrue(library.contains(seam), "MediaBrowserView lost the E4-29 seam `\(seam)`")
        }
        for verbatim in ["note = \"Relinked ", "line(\"\\(shown.count) of ", "accessibilityLabel(\"Relink \\(", "parts = \"no part\"", "parts = \"1 part\"",
                         "parts = \"\\(item.partCount) parts\"", "— expects \\(item.fileName)", "\"No file name contains \\u{201C}\\(",
                         "Text(\"\\(size) · \\(use)\")", "accessibilityLabel(\"\\(asset.displayName), ", "accessibilityLabel(\"Place \\(",
                         "? \"Stop preview\" :", "\"Preview \\(asset.displayName)\"", "\"Plays its first \\(", "? \"not in the piece\" :",
                         "return \"in 1 part\"", "return \"in \\(usage.partCount) parts\""] {
            XCTAssertFalse(library.contains(verbatim), "MediaBrowserView interpolates or spells a visible word verbatim again: `\(verbatim)`")
        }
        let patchbay = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        for seam in [".accessibilityLabel(name + String(localized: \" — network target\"))",
                     "Text(\"\\(router.graph.routes.count) \" + String(localized: \"connections\"))",
                     ".accessibilityLabel(src.name + String(localized: \" to \") + dst.name)",
                     ".accessibilityValue(connected ? String(localized: \"connected\") : (compatible ? String(localized: \"not connected\") : String(localized: \"incompatible\")))"] {
            XCTAssertTrue(patchbay.contains(seam), "PatchbayView lost the E4-29 seam `\(seam)`")
        }
        for verbatim in ["accessibilityLabel(\"\\(name) — network target\")", "Text(\"\\(router.graph.routes.count) connections\")",
                         "accessibilityLabel(\"\\(src.name) to \\(dst.name)\")", "connected ? \"connected\" :"] {
            XCTAssertFalse(patchbay.contains(verbatim), "PatchbayView interpolates a key again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English is unchanged — the words the other guards pin still come out
        XCTAssertEqual(MediaBrowserView.usageText(.unused), "not in the piece")
        XCTAssertEqual(MediaBrowserView.noMatchText("snare"), "No file name contains \u{201C}snare\u{201D}.")
        try assertGerman(["Relinked ", " to ", " files", "Relink ", " — expects ", "no part", "1 part", "No file name contains ",
                          "Place ", "Stop preview", "Preview ", "Plays its first ", " seconds", "not in the piece",
                          "imported, not placed yet", "in 1 part", "in ", " parts", " — network target", "connections",
                          "connected", "not connected", "incompatible"], "media library and routing surface")

        // E4-30 — the Compose guide: five step titles, their detail lines, the waiting reasons, the note after
        // "Write notes", the five spoken states, the spoken row ("Step n of N, title, state" as typed seams), the
        // header's next line and its spoken form. Every runtime guard on these words (ThePlateShowsHowAPieceIsMade,
        // WriteNotesOpensTheNoteEditor) keeps passing under the bundle's en locale — English is byte-identical.
        let composeGuide = try codeOnly("Sources/Echoelmusic/Studio/ComposeGuide.swift")
        for seam in ["case .track: return String(localized: \"Add a MIDI track\")",
                     "case .part:  return String(localized: \"Add a part\")",
                     "case .notes: return String(localized: \"Write notes\")",
                     "facts.isPlaying ? String(localized: \"Stop all playback\") : String(localized: \"Play the piece\")",
                     "case .save:  return String(localized: \"Save the piece\")",
                     "String(localized: \"Your piece has its MIDI track.\")",
                     "String(localized: \"An instrument track for the notes of your piece.\")",
                     "String(localized: \"Adds another empty four-bar part after the last one.\")",
                     "String(localized: \"An empty four-bar part on that track.\")",
                     "String(localized: \"Opens the part's notes under the arrangement.\")",
                     "String(localized: \"Stops the piece, the instrument and the pulse reading.\")",
                     "String(localized: \"Plays the piece from the top.\")",
                     "String(localized: \"Names the piece and saves it. Library opens it again.\")",
                     "String(localized: \"The part's notes are open under the arrangement. Tap a cell to write a note.\")",
                     "String(localized: \"Add a MIDI track first.\")", "String(localized: \"Add a part first.\")",
                     "String(localized: \"Nothing in the piece can play yet — no part with notes is heard.\")",
                     "String(localized: \"Write notes into a part first.\")", "String(localized: \"Add a part with notes first.\")",
                     "step == .play ? String(localized: \"playing\") : String(localized: \"done\")",
                     "status = String(localized: \"next step\")", "status = String(localized: \"available\")",
                     "status = String(localized: \"not yet available\")",
                     "let position: String = String(localized: \"Step \") + number + String(localized: \" of \") + total",
                     "let rest: String = title(step, facts) + \", \" + status",
                     "return position + \", \" + rest",
                     "return String(localized: \"Every step is available below.\")",
                     "return String(localized: \"Next: \") + title(next, facts)",
                     "String(localized: \"Create a piece. \") + headerDetail(facts)"] {
            XCTAssertTrue(composeGuide.contains(seam), "ComposeGuide lost the E4-30 seam `\(seam)`")
        }
        for verbatim in ["return \"Add a MIDI track\"", "return \"Add a part\"", "return \"Write notes\"", "? \"Stop all playback\" :",
                         "return \"Save the piece\"", "? \"Your piece has", "  : \"An instrument track", "? \"Adds another empty",
                         "  : \"An empty four-bar", "return \"Opens the part", "? \"Stops the piece", "  : \"Plays the piece",
                         "return \"Names the piece", "notesOpenedNote = \"", "return \"Add a MIDI track first.\"", "return \"Add a part first.\"",
                         "return \"Nothing in the piece", "? \"Write notes into", "first.\" : \"Add a part with notes", "? \"playing\" : \"done\"",
                         "status = \"next step\"", "status = \"available\"", "status = \"not yet available\"",
                         "return \"Step \\(step.rawValue) of", "return \"Every step is available below.\"", "return \"Next: \\(", "\"Create a piece. \\("] {
            XCTAssertFalse(composeGuide.contains(verbatim), "ComposeGuide spells a step word verbatim again: `\(verbatim)`")
        }
        let composeCard = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(composeCard.contains("Text(\"\\(step.rawValue). \" + ComposeGuide.title(step, facts))"),
                      "the step row's number+title join is not the neutral concatenation any more")
        XCTAssertFalse(composeCard.contains("Text(\"\\(step.rawValue). \\(ComposeGuide.title(step, facts))\")"),
                       "the step row interpolates the title into one literal again")
        // RUNTIME COUNTERWEIGHT: the bundle's English is unchanged
        XCTAssertTrue(ComposeGuide.notesOpenedNote.hasPrefix("The part's notes are open under the arrangement."))
        try assertGerman(["Add a MIDI track", "Add a part", "Write notes", "Stop all playback", "Play the piece", "Save the piece",
                          "Your piece has its MIDI track.", "An instrument track for the notes of your piece.",
                          "Adds another empty four-bar part after the last one.", "An empty four-bar part on that track.",
                          "Opens the part's notes under the arrangement.", "Stops the piece, the instrument and the pulse reading.",
                          "Plays the piece from the top.", "Names the piece and saves it. Library opens it again.",
                          "The part's notes are open under the arrangement. Tap a cell to write a note.",
                          "Add a MIDI track first.", "Add a part first.", "Nothing in the piece can play yet — no part with notes is heard.",
                          "Write notes into a part first.", "Add a part with notes first.", "playing", "done", "next step", "available",
                          "not yet available", "Step ", " of ", "Every step is available below.", "Next: ", "Create a piece. "], "Compose guide")

        // E4-31 — the bio info sheet: four metric titles (RMSSD · SDNN · pNN50 stay verbatim — acronyms, not words),
        // the breaths/min unit, seven summaries, seven details, the two origin notes, the demo PREFIX (one spelling,
        // one key — #416/#634b), the percentage sentence and the modulation row's spoken sentence as typed seams;
        // and `BioSoundMapping.all`'s twelve source/target/direction strings. Every runtime guard on these words keeps
        // passing under en (TheMetricSheetRowsSayWhoseBody, TheGuideTableMatchesTheAuditedWrites, TheTempoModeSpeaks…).
        let bioSheet = try codeOnly("Sources/Echoelmusic/Studio/BioMetricInfo.swift")
        for seam in ["case .heartRate: return String(localized: \"Heart Rate\")",
                     "case .hrv:       return String(localized: \"Heart-Rate Variability\")",
                     "case .coherence: return String(localized: \"Coherence\")",
                     "case .breath:    return String(localized: \"Breathing Rate\")",
                     "case .breath:    return String(localized: \"breaths/min\")",
                     "return String(localized: \"How fast your heart is beating right now.\")",
                     "return String(localized: \"Breaths per minute.\")",
                     "return String(localized: \"Beats per minute. It rises with effort",
                     "return String(localized: \"Your breathing rate. Slow breathing",
                     "guard let frame else { return String(localized: \"read your pulse to see it move\") }",
                     "return frame.source.isSynthetic ? String(localized: \"demo values, not your body\") : nil",
                     "let head: String = metric.title + \". \" + metric.detail",
                     "return head + \". \" + BioMetric.disclaimer",
                     ".accessibilityLabel(spokenSummary)",
                     ".accessibilityLabel(m.title + \". \" + m.detail)",
                     "let origin: String = synthetic ? String(localized: \"Simulated demo, \") : \"\"",
                     "let measuredTail: String = String(localized: \" Currently \") + percent + String(localized: \" percent.\")",
                     "let measured: String = percent.isEmpty ? \"\" : measuredTail",
                     "let route: String = m.source + String(localized: \" shapes \") + m.target",
                     "let tail: String = \". \" + m.direction + \".\" + measured",
                     ".accessibilityLabel(origin + route + tail)"] {
            XCTAssertTrue(bioSheet.contains(seam), "BioMetricInfo lost the E4-31 seam `\(seam)`")
        }
        for verbatim in ["return \"Heart Rate\"", "return \"Heart-Rate Variability\"", "return \"Coherence\"", "return \"Breathing Rate\"",
                         "return \"breaths/min\"", "return \"How fast your heart", "return \"Breaths per minute.\"", "return \"Beats per minute.",
                         "return \"Your breathing rate.", "return \"read your pulse", "? \"demo values, not your body\"",
                         "accessibilityLabel(\"\\(metric.title). ", "accessibilityLabel(\"\\(m.title). ", "? \"Simulated demo, \" :",
                         "\" Currently \\(", "\\(m.source) shapes \\(m.target)"] {
            XCTAssertFalse(bioSheet.contains(verbatim), "BioMetricInfo spells or interpolates a visible word verbatim again: `\(verbatim)`")
        }
        XCTAssertEqual(bioSheet.components(separatedBy: "return String(localized: \"").count - 1, 20,
                       "BioMetric's title/unit/summary/detail/originNote keys: 4 + 1 + 7 + 7 + 1 = 20 `return String(localized:` sites — re-derive if a metric was added")
        let soundMap = try codeOnly("Sources/Echoelmusic/Bio/BioSoundMapping.swift")
        for seam in ["source: String(localized: \"Heart rate\")", "target: String(localized: \"Vibrato & tone brightness\")",
                     "source: String(localized: \"Heart-rate variability\")", "target: String(localized: \"Overtone brightness\")",
                     "source: String(localized: \"Coherence\")", "target: String(localized: \"Filter brightness & harmonics\")",
                     "source: String(localized: \"Breath\")", "target: String(localized: \"Swell\")",
                     "direction: String(localized: \"the sound swells and settles once with each breath\")"] {
            XCTAssertTrue(soundMap.contains(seam), "BioSoundMapping lost the E4-31 seam `\(seam)`")
        }
        XCTAssertEqual(soundMap.components(separatedBy: "direction: String(localized: \"").count - 1, 4, "every guide row's direction phrase is a catalog key")
        for verbatim in ["source: \"", "target: \"", "direction: \""] {
            XCTAssertFalse(soundMap.contains(verbatim), "a BioSoundMapping row spells `\(verbatim)…` verbatim again")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English is unchanged
        XCTAssertEqual(BioMetric.heartRate.title, "Heart Rate")
        XCTAssertEqual(BioSoundMapping.all.first?.source, "Heart rate")
        try assertGerman(["Heart Rate", "Heart-Rate Variability", "Coherence", "Breathing Rate", "breaths/min",
                          "How fast your heart is beating right now.", "Breaths per minute.", "read your pulse to see it move",
                          "demo values, not your body", "Simulated demo, ", " Currently ", " percent.", " shapes ",
                          "Heart rate", "Vibrato & tone brightness", "Heart-rate variability", "Overtone brightness",
                          "Filter brightness & harmonics", "Breath", "Swell",
                          "the sound swells and settles once with each breath"], "bio info sheet and sound map")
        for (metric, prefix) in [(BioMetric.heartRate, "Beats per minute."), (.hrv, "The tiny differences"), (.rmssd, "Root mean square"),
                                 (.sdnn, "Standard deviation"), (.pnn50, "The percentage of consecutive"), (.coherence, "How much of your heart-rate"),
                                 (.breath, "Your breathing rate.")] {
            XCTAssertTrue(metric.detail.hasPrefix(prefix), "`BioMetric.\(metric.rawValue).detail` no longer begins as the catalog key does")
            XCTAssertNotNil(german(metric.detail, in: strings), "no German unit for the detail of `\(metric.rawValue)`")
            XCTAssertNotNil(german(metric.summary, in: strings), "no German unit for the summary of `\(metric.rawValue)`")
        }

        // E4-32 — the pulse pill's spoken value (HeaderMonitors.accessibilityText) and the Live Colabo peer row's
        // spoken line: the demo PREFIX keeps its one spelling as a key (#416/#634b) and still leads (#627/#629), the
        // number still goes through `EchoelDecimalText` (#1321), and the English seams — " beats per minute",
        // ", coherence ", "no pulse yet", "not available", "No pulse lock" — are catalog keys. Both re-anchored guards
        // (ThePulseSpeaksItsStatusInWords, ThePeerSeesWhetherItIsABody, TheWireCannotTrapTheApp) pin the new spelling;
        // TheDemoSourceIsMarkedWhereItRenders keeps its `let prefix = synthetic ?` and both `return "\(prefix)` pins.
        let pill = try codeOnly("Sources/Echoelmusic/Studio/HeaderMonitors.swift")
        for seam in ["return ladder?.spoken ?? String(localized: \"No pulse lock\")",
                     "let prefix = synthetic ? String(localized: \"Simulated demo, \") : \"\"",
                     "let tail: String = String(localized: \" beats per minute, coherence \") + EchoelDecimalText.string(coh, decimals: 2)",
                     "return \"\\(prefix)\\(Int(bpm))\" + tail",
                     "return \"\\(prefix)\\(Int(bpm))\" + String(localized: \" beats per minute\")"] {
            XCTAssertTrue(pill.contains(seam), "HeaderMonitors lost the E4-32 seam `\(seam)`")
        }
        for verbatim in ["?? \"No pulse lock\"", "synthetic ? \"Simulated demo, \"", ") beats per minute, coherence \\(", "\\(Int(bpm)) beats per minute\""] {
            XCTAssertFalse(pill.contains(verbatim), "HeaderMonitors spells or interpolates a spoken word verbatim again: `\(verbatim)`")
        }
        let peer = try codeOnly("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        for seam in [".accessibilityLabel(spokenBioLine(name: name, bpm: bpm, coherence: coherence, synthetic: synthetic))",
                     "let origin: String = synthetic == true ? String(localized: \"Simulated demo, \") : \"\"",
                     "let beats: String = EchoelDecimalText.string(bpm, decimals: 0) + String(localized: \" beats per minute\")",
                     "let pulse: String = bpm > 0 ? beats : String(localized: \"no pulse yet\")",
                     "EchoelDecimalText.string(coherence, decimals: 2) : String(localized: \"not available\")",
                     "let head: String = origin + name + \": \" + pulse",
                     "return head + String(localized: \", coherence \") + coherenceText"] {
            XCTAssertTrue(peer.contains(seam), "LiveColaboView lost the E4-32 seam `\(seam)`")
        }
        for verbatim in ["\"Simulated demo, \" : \"\")", ") beats per minute\" : \"no pulse yet\"", ", coherence \\(coherence > 0"] {
            XCTAssertFalse(peer.contains(verbatim), "LiveColaboView interpolates the peer sentence verbatim again: `\(verbatim)`")
        }
        try assertGerman(["No pulse lock", "Simulated demo, ", " beats per minute, coherence ", " beats per minute",
                          "no pulse yet", "not available", ", coherence "], "pulse pill and peer row")

        // E4-33 — the last two demo-prefix sentences: the always-on channel row (three return paths — unmeasured,
        // measured, held) and the FX bio-mod contribution row (two — unmeasured, measured). The prefix keeps its one
        // spelling as a key and still leads on every path (TheAlwaysOnRowsSayWhoseBody counts three `return origin`/
        // `origin +` lines, TheFXRoutesSayWhoseBody two `return origin` lines — both untouched); "no longer arriving"
        // stays inside its key for AHeldReadingSaysSo. Subjects (`channel.name`, `carrierName`) are typed steps.
        let bioRow = try codeOnly("Sources/Echoelmusic/Studio/AlwaysOnBioRow.swift")
        for seam in ["let origin = reading.isSynthetic ? String(localized: \"Simulated demo, \") : \"\"",
                     "let unmeasured: String = channel.name + String(localized: \", not measured, shaping \") + channel.shapes",
                     "return origin + unmeasured + String(localized: \" at the neutral value\")",
                     "let live: String = channel.name + String(localized: \" at \") + \"\\(percent)\"",
                     "return origin + live + String(localized: \" percent, shaping \") + channel.shapes",
                     "let held: String = channel.name + String(localized: \" held at \") + \"\\(percent)\"",
                     "return origin + held + String(localized: \" percent, no longer arriving, still shaping \") + channel.shapes"] {
            XCTAssertTrue(bioRow.contains(seam), "AlwaysOnBioRow lost the E4-33 seam `\(seam)`")
        }
        for verbatim in ["isSynthetic ? \"Simulated demo, \"", ", not measured, shaping \\(", ") percent, shaping \\(", ") held at \\(", "\"still shaping \\("] {
            XCTAssertFalse(bioRow.contains(verbatim), "AlwaysOnBioRow interpolates a spoken sentence verbatim again: `\(verbatim)`")
        }
        let fxRow = try codeOnly("Sources/Echoelmusic/Studio/EchoelFXView.swift")
        for seam in ["let origin = contribution.synthetic ? String(localized: \"Simulated demo, \") : \"\"",
                     "let route: String = contribution.carrierName + String(localized: \" to \") + contribution.targetName",
                     "return origin + route + String(localized: \", not measured\")",
                     "let moving: String = contribution.carrierName + String(localized: \" moving \") + contribution.targetName",
                     "let amount: String = \", \" + \"\\(Int((contribution.signal01 * 100).rounded()))\" + String(localized: \" percent\")",
                     "return origin + moving + amount"] {
            XCTAssertTrue(fxRow.contains(seam), "EchoelFXView lost the E4-33 seam `\(seam)`")
        }
        for verbatim in ["contribution.synthetic ? \"Simulated demo, \"", ") to \\(contribution.targetName), not measured", ") moving \\(contribution.targetName), ", ".rounded())) percent\""] {
            XCTAssertFalse(fxRow.contains(verbatim), "EchoelFXView interpolates the contribution sentence verbatim again: `\(verbatim)`")
        }
        try assertGerman(["Simulated demo, ", ", not measured, shaping ", " at the neutral value", " at ", " percent, shaping ",
                          " held at ", " percent, no longer arriving, still shaping ", " to ", " moving ", ", not measured", " percent"],
                         "always-on row and FX contribution row")

        // E4-34 — the SUBJECTS of the always-on sentences: `AlwaysOnBioChannel.name` (four; drawn by `Text(channel.name)`
        // and spoken by the row), `BioShapedParameter.channelWord` (six; joined into `shapes`, the row's object) and
        // `soundPanelRows` (the Sound panel's field labels — the same keys the value fields draw, so the sentence and
        // the fields agree in every language). Runtime English byte-identical: TheBodyShapedRowsAreNamedOnce's expected
        // `shapes`, TheAlwaysOnChannelsAreShown's `contains`, TheGuideTableMatchesTheAuditedWrites' channelWord scan and
        // TheSoundPanelNamesItsActualDriver's row loop all keep passing under en; DisabledReverbIsNotClaimedLive still
        // finds all three member declarations.
        let bioChannel = try codeOnly("Sources/Echoelmusic/Studio/AlwaysOnBioChannel.swift")
        for seam in ["case .coherence:   return String(localized: \"Coherence\")",
                     "case .hrv:         return String(localized: \"HRV\")",
                     "case .heartRate:   return String(localized: \"Heart rate\")",
                     "case .breathPhase: return String(localized: \"Breath phase\")",
                     "case .brightness:   return String(localized: \"brightness\")",
                     "case .harmonicity:  return String(localized: \"harmonicity\")",
                     "case .noiseLevel:   return String(localized: \"noise\")",
                     "case .filterCutoff: return String(localized: \"filter\")",
                     "case .vibrato:      return String(localized: \"vibrato\")",
                     "case .amplitude:    return String(localized: \"level\")",
                     "case .brightness:   return [String(localized: \"Brightness\")]",
                     "case .vibrato:      return [String(localized: \"Vibrato depth\"), String(localized: \"Vibrato rate\")]"] {
            XCTAssertTrue(bioChannel.contains(seam), "AlwaysOnBioChannel lost the E4-34 seam `\(seam)`")
        }
        for verbatim in ["return \"Coherence\"", "return \"HRV\"", "return \"Heart rate\"", "return \"Breath phase\"",
                         "return \"brightness\"", "return \"harmonicity\"", "return \"noise\"", "return \"filter\"", "return \"vibrato\"", "return \"level\"",
                         "return [\"Brightness\"]", "return [\"Harmonics\"]", "return [\"Noise\"]", "return [\"Cutoff\"]", "return [\"Vibrato depth\", "] {
            XCTAssertFalse(bioChannel.contains(verbatim), "AlwaysOnBioChannel spells a channel name verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English is unchanged, and the joined object still reads as before
        XCTAssertEqual(AlwaysOnBioChannel.heartRate.name, "Heart rate")
        XCTAssertEqual(AlwaysOnBioChannel.coherence.shapes, "filter · brightness · harmonicity · noise")
        XCTAssertEqual(BioShapedParameter.vibrato.soundPanelRows, ["Vibrato depth", "Vibrato rate"])
        try assertGerman(["Coherence", "HRV", "Heart rate", "Breath phase", "brightness", "harmonicity", "noise", "filter", "vibrato", "level",
                          "Brightness", "Harmonics", "Noise", "Cutoff", "Vibrato depth", "Vibrato rate"], "always-on channel names")

        // E4-35 — the FX route names: `FXModTarget.displayName` (thirteen targets, the Effects routing pickers and the
        // contribution row's `targetName`), `FXModCarrier.displayName` (LFO + six body channels, the carrier picker and
        // `carrierName`) and `ModSource.displayName` (the body→parameter matrix card). Neither file is in the AUv3 target.
        // The `rawValue`s that persist routes are untouched; runtime English byte-identical (BioModContributionTests'
        // "Reverb Mix" keeps passing).
        let fxMod = try codeOnly("Sources/Echoelmusic/Core/FXModulation.swift")
        for seam in ["case .filterCutoff:    return String(localized: \"Filter Cutoff\")",
                     "case .reverbMix:       return String(localized: \"Reverb Mix\")",
                     "case .stereoWidth:     return String(localized: \"Stereo Width\")",
                     "case .lfo: return String(localized: \"LFO\")",
                     "case .breathRate:  return String(localized: \"Breath rate\")",
                     "case .motion:      return String(localized: \"Motion\")"] {
            XCTAssertTrue(fxMod.contains(seam), "FXModulation lost the E4-35 seam `\(seam)`")
        }
        XCTAssertEqual(fxMod.components(separatedBy: "return String(localized: \"").count - 1, 20,
                       "FXModTarget (13) + FXModCarrier (7) display names — 20 `return String(localized:` sites; re-derive if a target or carrier was added")
        for verbatim in ["return \"Filter Cutoff\"", "return \"Reverb Mix\"", "return \"LFO\"", "return \"Heart rate\"", "return \"Motion\""] {
            XCTAssertFalse(fxMod.contains(verbatim), "FXModulation spells a route name verbatim again: `\(verbatim)`")
        }
        let modSource = try codeOnly("Sources/Echoelmusic/Core/ModulationMatrix.swift")
        for seam in ["case .heartRate:   return String(localized: \"Heartbeat\")", "case .breathPhase: return String(localized: \"Breath\")",
                     "case .coherence:   return String(localized: \"Coherence\")"] {
            XCTAssertTrue(modSource.contains(seam), "ModulationMatrix lost the E4-35 seam `\(seam)`")
        }
        XCTAssertFalse(modSource.contains("return \"Heartbeat\""), "ModSource.displayName spells Heartbeat verbatim again")
        XCTAssertEqual(FXModTarget.reverbMix.displayName, "Reverb Mix")
        XCTAssertEqual(FXModCarrier.bio(.heartRate).displayName, "Heart rate")
        XCTAssertEqual(ModSource.heartRate.displayName, "Heartbeat")
        try assertGerman(["Filter Cutoff", "Filter Resonance", "Saturation Drive", "Chorus Mix", "Flanger Mix", "Phaser Mix", "Tremolo Depth",
                          "Delay Mix", "Delay Feedback", "Reverb Mix", "Reverb Size", "Bitcrush Mix", "Stereo Width",
                          "LFO", "Heart rate", "HRV", "Breath rate", "Breath", "Coherence", "Motion", "Heartbeat"], "FX route names")

        // E4-36 — the pulse ladder (Bio/PulseLadder.swift): the four rung words the pill draws with `Text(ladder.word)`
        // and the four spoken sentences `accessibilityText` falls back to. Claim 8 covers the MIDI/audio-route/Health
        // ladders and never reached this one. The German words respect the pill's ≤ 12-character slot law
        // (AStalledAcquisitionSaysSo): Suche · Fast da · Gefunden · Verloren.
        let ladderFile = try codeOnly("Sources/Echoelmusic/Bio/PulseLadder.swift")
        for seam in ["case .searching: return String(localized: \"Searching\")", "case .nearly:    return String(localized: \"Almost\")",
                     "case .found:     return String(localized: \"Found\")", "case .lost:      return String(localized: \"Lost\")",
                     "case .searching: return String(localized: \"Searching for your pulse\")",
                     "case .nearly:    return String(localized: \"Almost there — keep your finger still\")",
                     "case .found:     return String(localized: \"Pulse found\")",
                     "case .lost:      return String(localized: \"Pulse lost — keep your finger still\")"] {
            XCTAssertTrue(ladderFile.contains(seam), "PulseLadder lost the E4-36 seam `\(seam)`")
        }
        for verbatim in ["return \"Searching\"", "return \"Almost\"", "return \"Found\"", "return \"Lost\"", "return \"Pulse found\"", "return \"Searching for your pulse\""] {
            XCTAssertFalse(ladderFile.contains(verbatim), "PulseLadder spells a rung verbatim again: `\(verbatim)`")
        }
        XCTAssertEqual(PulseLadderStep.searching.word, "Searching")
        XCTAssertEqual(PulseLadderStep.lost.spoken, "Pulse lost — keep your finger still")
        for step in PulseLadderStep.allCases {
            XCTAssertLessThanOrEqual(german(step.word, in: strings)?.value.count ?? 99, 12, "the German rung word for `\(step)` overflows the pill's value slot")
        }
        try assertGerman(["Searching", "Almost", "Found", "Lost", "Searching for your pulse", "Almost there — keep your finger still",
                          "Pulse found", "Pulse lost — keep your finger still"], "pulse ladder")

        // E4-37 — the long sentences of AlwaysOnBioChannel: the demo subject (ONE spelling, now a computed key —
        // OneSpellingOfTheDemoSubject's runtime and source claims keep passing), the FX footer and Bio-panel
        // always-on sentences, the Sound panel's "also shapes this sound" line and its two empty states, and the
        // breath-voice / Auto hints and captions (BioPanelRowCopy). Every seam a key, every conditional opening a
        // typed step; the English concatenations are byte-identical (the runtime counterweights below), so
        // TheBioPanelRowsSayWhoseBody, TheSoundPanelNamesItsActualDriver, TheBodyShapedRowsAreNamedOnce,
        // TheAlwaysOnBioPathIsNamed and TheChromeSpeaksOneWordPerThing keep every needle.
        let bioCopy = try codeOnly("Sources/Echoelmusic/Studio/AlwaysOnBioChannel.swift")
        for seam in ["public static var demoSubject: String { String(localized: \"the simulated demo source, not your body\") }",
                     "let demoOpening: String = String(localized: \"four channels from \") + BioProvenanceCopy.demoSubject + String(localized: \", shape \")",
                     "let opening: String = synthetic ? demoOpening : String(localized: \"four body channels shape \")",
                     "return String(localized: \"Separately from these routes, \") + opening + claim",
                     "let opening: String = synthetic ? demoOpening : String(localized: \"Four body channels shape \")",
                     ": String(localized: \"Your body\")",
                     "? String(localized: \"The simulated demo source is not shaping any control on this panel right now.\")",
                     "let head: String = subject + String(localized: \" also shapes this sound while the instrument plays: \") + list",
                     "synthetic ? BioProvenanceCopy.demoSubject : String(localized: \"your body\")",
                     "return String(localized: \"Sounds a held tone whose colour follows \") + subject(synthetic: frame.source.isSynthetic)",
                     "case false: head = String(localized: \"A held tone whose colour follows your heart and coherence.\")",
                     "return head + String(localized: \" Your inhale opens it, your exhale closes it.\")",
                     "return String(localized: \"Slowly steers the mood dials toward your measured body state\")",
                     "let head: String = frame.source.isSynthetic",
                     "return head + String(localized: \" — over bars, not beats. Your own edits keep priority"] {
            XCTAssertTrue(bioCopy.contains(seam), "AlwaysOnBioChannel lost the E4-37 seam `\(seam)`")
        }
        for verbatim in ["static let demoSubject", "? \"four channels from \"", "return \"Separately from these routes, \"", "? \"Four channels from \"",
                         "            : \"Your body\"", "BioProvenanceCopy.demoSubject : \"your body\"", "+ \" and \" +", "\\(subject) also shapes", "head = \"A held tone",
                         "return \"Needs a running bio source", "return \"Slowly steers", "? \"Gently steers", "return head + \" — over bars"] {
            XCTAssertFalse(bioCopy.contains(verbatim), "AlwaysOnBioChannel spells or interpolates a sentence verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English concatenations are unchanged
        XCTAssertEqual(BioProvenanceCopy.demoSubject, "the simulated demo source, not your body")
        XCTAssertTrue(BioProvenanceCopy.demoSubjectSentenceInitial.hasPrefix("The simulated demo source"))
        XCTAssertEqual(AlwaysOnBioChannel.alwaysOnSentence(synthetic: false),
                       "Separately from these routes, four body channels shape the instrument's own timbre while the instrument plays: coherence, HRV, heart rate and breath phase. Routes here add effect parameters on top.")
        XCTAssertTrue(AlwaysOnBioChannel.bioPanelSentence(synthetic: true).hasPrefix("Four channels from the simulated demo source, not your body, shape the instrument's own timbre"))
        XCTAssertTrue(BioShapedParameter.soundPanelSentence(synthetic: false).hasPrefix("Your body also shapes this sound while the instrument plays: "))
        XCTAssertTrue(BioShapedParameter.soundPanelSentence(synthetic: false).hasSuffix(" move around the values you set here. Open Bio to watch the four channels doing it."))
        XCTAssertEqual(BioPanelRowCopy.autoModeHint(for: nil), "Needs a running bio source before it can steer anything")
        XCTAssertTrue(BioPanelRowCopy.autoModeCaption(for: nil).hasPrefix("Needs a running bio source — choose one"))
        try assertGerman(Array(Set(["the simulated demo source, not your body", "four channels from ", ", shape ", "four body channels shape ",
                                    "Separately from these routes, ", "Four channels from ", "Four body channels shape ", "Your body", "your body", " and ",
                                    "The simulated demo source is not shaping any control on this panel right now.",
                                    "Your body is not shaping any control on this panel right now.",
                                    " also shapes this sound while the instrument plays: ",
                                    " move around the values you set here. Open Bio to watch the four channels doing it.",
                                    "Sounds a held tone. Nothing is measured yet, so its colour will not move", "Sounds a held tone whose colour follows ",
                                    "A held tone whose colour follows your heart and coherence.", "A held tone whose colour follows the heart and coherence of ",
                                    " Your inhale opens it, your exhale closes it.", " Its simulated inhale opens it, its exhale closes it.",
                                    "Needs a running bio source before it can steer anything", "Slowly steers the mood dials toward your measured body state",
                                    "Slowly steers the mood dials toward the measured state of ",
                                    "Needs a running bio source — choose one with the Bio source control above.",
                                    ", when that reading is clearly settled or clearly driving"])).sorted(), "always-on and Bio-panel sentences")

        // E4-38 — the bio strip and the two mood pads. BioStripView: the lock banner (`banner(_ text: String …)`,
        // whose signature CoachingTextScales pins), the driving dot's three spoken states (a ternary of bare
        // literals is a `String`), the source tag's "No signal", and the camera caption's three
        // `LocalizedStringKey` values that had no unit. MoodPads: title and axis captions were `String`
        // arguments (`Text(title)` is verbatim), and the pad's spoken label/value/action names were
        // interpolated literals — format keys no catalog unit can carry — now seams around the caption
        // halves, split on the same " · " the German values keep (pinned below).
        let bioStrip = try codeOnly("Sources/Echoelmusic/Studio/BioStripView.swift")
        for seam in ["banner(String(localized: \"Pulse detected — you can let go & play\"),",
                     ".accessibilityLabel(drivingLabel)",
                     "let live: String = hasLiveSignal ? String(localized: \"Body signal live, not driving yet\") : String(localized: \"No live body signal\")",
                     "return driving ? String(localized: \"Your body is driving the sound\") : live",
                     "return String(localized: \"No signal\")",
                     "let caption: LocalizedStringKey = camera"] {
            XCTAssertTrue(bioStrip.contains(seam), "BioStripView lost the E4-38 seam `\(seam)`")
        }
        for verbatim in ["banner(\"Pulse detected", "? \"Your body is driving the sound\"", "return \"No signal\""] {
            XCTAssertFalse(bioStrip.contains(verbatim), "BioStripView spells a strip word verbatim again: `\(verbatim)`")
        }
        let pads = try codeOnly("Sources/Echoelmusic/Studio/MoodPads.swift")
        for seam in ["MoodXYPad(title: String(localized: \"Sound\"),", "xCaption: String(localized: \"dark · bright\"),", "yCaption: String(localized: \"still · moving\"),",
                     "MoodXYPad(title: String(localized: \"Visual\"),", "xCaption: String(localized: \"natural · spectrum\"),", "yCaption: String(localized: \"calm · energy\"),",
                     ".accessibilityLabel(title + String(localized: \" mood pad\"))", ".accessibilityValue(spokenValue)",
                     "private func more(_ word: String?, fallback: String) -> String { String(localized: \"More \") + (word ?? fallback) }",
                     "let across: String = \"\\(Int(x * 100))\" + String(localized: \" percent across (\") + xCaption + \")\"",
                     "named: more(xWords.last, fallback: String(localized: \"right\"))"] {
            XCTAssertTrue(pads.contains(seam), "MoodPads lost the E4-38 seam `\(seam)`")
        }
        for verbatim in ["title: \"Sound\"", "xCaption: \"dark · bright\"", "title: \"Visual\"", "\\(title) mood pad", "percent across (\\(xCaption))", "named: \"More \\("] {
            XCTAssertFalse(pads.contains(verbatim), "MoodPads interpolates or spells a pad word verbatim again: `\(verbatim)`")
        }
        // the actions split the caption on " · " — every German caption must keep exactly one
        for caption in ["dark · bright", "still · moving", "natural · spectrum", "calm · energy"] {
            XCTAssertEqual(german(caption, in: strings)?.value.components(separatedBy: " · ").count, 2, "the German `\(caption)` must split into two words on ` · `")
        }
        try assertGerman(["Pulse detected — you can let go & play", "Your body is driving the sound", "Body signal live, not driving yet", "No live body signal",
                          "No signal", "Reading…", "Cover camera", "Connecting…", "Sound", "Visual", "dark · bright", "still · moving",
                          "natural · spectrum", "calm · energy", " mood pad", " percent across (", " percent up (", "More ", "right", "left", "up", "down"],
                         "bio strip and mood pads")

        // E4-39 — the floating visual window's bar and the header's monitor button: every ternary of two bare
        // literals in an `.accessibilityLabel` is a `String` (VoiceOver read it verbatim on a German phone) and
        // now holds two keys; `WindowSize.label` (the resize button's spoken value) returns keys; the WAV
        // button's spoken gap is seams around a locale-aware number instead of a `String(format:)` key; the
        // note-name hint was a `+` chain of three literals and is ONE literal, i.e. a key. TheWayOutSurvives
        // Rotation (`"Exit fullscreen"` before `"Hide visual"`), TheFloatingWindowMovesWithoutADrag (the drag label
        // on exactly one line) and TheCaptureTapDoesNotTouchTheDisk (`seconds lost`) keep their needles.
        let floating = try codeOnly("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        for seam in ["case .fullscreen: return String(localized: \"Fullscreen\")",
                     ".accessibilityLabel(wavRecording ? String(localized: \"Stop WAV audio recording\") : String(localized: \"Record lossless WAV audio\"))",
                     "if failed { return String(localized: \"Writing to disk failed\") }",
                     "return String(localized: \"Recording, \") + EchoelDecimalText.string(droppedSeconds, decimals: 1) + String(localized: \" seconds lost\")",
                     ": String(localized: \"Echoelmusic — drag to move the visual\"))",
                     ".accessibilityLabel(touchShowGrid ? String(localized: \"Hide note grid\") : String(localized: \"Show note grid\"))",
                     ".accessibilityLabel(windowSize.isFullscreen ? String(localized: \"Exit fullscreen\") : String(localized: \"Resize visual\"))"] {
            XCTAssertTrue(floating.contains(seam), "FloatingVisualWindow lost the E4-39 seam `\(seam)`")
        }
        for verbatim in ["return \"Fullscreen\"", "? \"Stop WAV audio recording\"", "return \"Writing to disk failed\"", "String(format: \"Recording, %.1f seconds lost\"",
                         "                    : \"Echoelmusic — drag to move the visual\")", "? \"Hide note grid\"", "? \"Exit fullscreen\""] {
            XCTAssertFalse(floating.contains(verbatim), "FloatingVisualWindow spells a spoken label verbatim again: `\(verbatim)`")
        }
        let workspace = try codeOnly("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(workspace.contains(".accessibilityLabel(floatingVisualVisible ? String(localized: \"Hide floating visual\") : String(localized: \"Show floating visual\"))"),
                      "WorkspaceView lost the E4-39 monitor-button seam")
        XCTAssertTrue(workspace.contains(".accessibilityHint(\"Chooses how the twelve notes are spelled — international A B C, German A H C, solfège Do Re Mi, or Indian sargam Sa Re Ga\")"),
                      "WorkspaceView's note-name hint is no longer ONE literal key")
        XCTAssertFalse(workspace.contains("? \"Hide floating visual\""), "WorkspaceView spells the monitor label verbatim again")
        XCTAssertFalse(workspace.contains("+ \"international A B C"), "WorkspaceView's note-name hint is a `+` chain of literals again (a String, not a key)")
        // RUNTIME COUNTERWEIGHTS: the bundle's English output is unchanged
        XCTAssertEqual(FloatingVisualWindow.wavAccessibilityValue(recording: true, failed: false, droppedSeconds: 1.5), "Recording, 1.5 seconds lost")
        XCTAssertEqual(FloatingVisualWindow.WindowSize.fullscreen.label, "Fullscreen")
        try assertGerman(["Small", "Medium", "Large", "Fullscreen", "Stop WAV audio recording", "Record lossless WAV audio", "Writing to disk failed",
                          "Recording, ", " seconds lost", "Echoelmusic — drag to move the visual", "Hide note grid", "Show note grid", "Exit fullscreen",
                          "Resize visual", "Hide floating visual", "Show floating visual",
                          "Chooses how the twelve notes are spelled — international A B C, German A H C, solfège Do Re Mi, or Indian sargam Sa Re Ga"],
                         "visual window bar and header monitor")

        // E4-40 — the Perform plate and the FX panel's prose. PerformSessionView: the four `static let` sentences
        // (`Text(Self.x)` is verbatim) are computed keys, and the disclosure value says Expanded/Collapsed like its
        // three sibling controls (one word per thing; "Open" is already the catalog's door verb). EchoelFXView: the
        // Morph label (`Label(String)`), the four `Text(flag ? "A" : "B")` footers and headers (a ternary of literals
        // is a String), the dropout note (a `+` chain, now ONE literal on one line so ADropoutSaysWhichHalfLetGo's
        // extractor still reads it — its anchor moved 1:1) and the neutral-0.50 footer. TheFXHeadersSayWhoseBody,
        // AHeldReadingSaysSo and PerformIsASecondViewOfTheSameSession keep every needle (runtime English unchanged).
        let perform = try codeOnly("Sources/Echoelmusic/Studio/PerformSessionView.swift")
        for seam in ["static var sectionTitle: String { String(localized: \"Scenes and tracks\") }",
                     "static var sectionHint: String { String(localized: \"Shows the piece's scenes to launch on the bar,",
                     "static var emptyNote: String { String(localized: \"Nothing to launch yet.",
                     "static var instrumentRunningNote: String { String(localized: \"The Echoel is playing.",
                     ".accessibilityValue(isOpen ? String(localized: \"Expanded\") : String(localized: \"Collapsed\"))"] {
            XCTAssertTrue(perform.contains(seam), "PerformSessionView lost the E4-40 seam `\(seam)`")
        }
        for verbatim in ["static let sectionTitle", "static let sectionHint", "static let emptyNote", "static let instrumentRunningNote", "? \"Open\" : \"Closed\""] {
            XCTAssertFalse(perform.contains(verbatim), "PerformSessionView stores or spells a sentence verbatim again: `\(verbatim)`")
        }
        let fxPanel = try codeOnly("Sources/Echoelmusic/Studio/EchoelFXView.swift")
        for seam in ["Label(morphTarget.map { String(localized: \"Morph → \") + $0.name } ?? String(localized: \"Morph toward a preset…\"),",
                     "? String(localized: \"Blend the current sound continuously toward any preset with the Morph control — for live transitions.\")",
                     ": String(localized: \"0 = current sound · 1 = the target preset. Every parameter glides between them.\"))",
                     "? String(localized: \"Let the body shape the effects: e.g. coherence → reverb, breath → filter, heart rate → tremolo. Add a route to begin.\")",
                     ": String(localized: \"Each route moves its parameter around your set value at ~30 Hz. The targeted stage turns on automatically.\"))",
                     "? String(localized: \"No routes yet, so no effect parameter is moving. Add one above.\")",
                     ": String(localized: \"Start the instrument to watch the body move these parameters.\"))",
                     "? String(localized: \"Always on — simulated demo → timbre\")",
                     ": String(localized: \"Always on — body → timbre\"))",
                     "static var stopsArrivingNote: String { String(localized: \"When a channel stops arriving, its routes here release:",
                     "Text(\"A channel with no reading hands the engine a neutral 0.50 on purpose, so the instrument keeps playing its patch"] {
            XCTAssertTrue(fxPanel.contains(seam), "EchoelFXView lost the E4-40 seam `\(seam)`")
        }
        for verbatim in ["\"Morph → \\(", "                 ? \"Blend the current sound", "                 : \"0 = current sound", "                 ? \"Let the body shape",
                         "                     : \"Start the instrument", "                 : \"Always on — body → timbre\"", "static let stopsArrivingNote",
                         "+ \"instrument keeps playing its patch"] {
            XCTAssertFalse(fxPanel.contains(verbatim), "EchoelFXView interpolates, chains or spells a sentence verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English statics are unchanged
        XCTAssertEqual(PerformSessionView.sectionTitle, "Scenes and tracks")
        XCTAssertTrue(PerformSessionView.emptyNote.hasPrefix("Nothing to launch yet. Parts you write in Compose,"))
        try assertGerman(["Scenes and tracks", "Expanded", "Collapsed", "Save preset", "Rename preset", "Morph → ", "Morph toward a preset…",
                          "Always on — simulated demo → timbre", "Always on — body → timbre",
                          "Shows the piece's scenes to launch on the bar, and Mute and Solo for its tracks. While the Echoel plays on its own, stop it in the header to launch a scene.",
                          "Nothing to launch yet. Parts you write in Compose, and the Echoel's generated music, appear here as scenes to launch on the bar.",
                          "The Echoel is playing. Stop it in the header to launch a scene — the piece then starts on the scene's bar.",
                          "Blend the current sound continuously toward any preset with the Morph control — for live transitions.",
                          "0 = current sound · 1 = the target preset. Every parameter glides between them.",
                          "Let the body shape the effects: e.g. coherence → reverb, breath → filter, heart rate → tremolo. Add a route to begin.",
                          "Each route moves its parameter around your set value at ~30 Hz. The targeted stage turns on automatically.",
                          "No routes yet, so no effect parameter is moving. Add one above.", "Start the instrument to watch the body move these parameters.",
                          "When a channel stops arriving, its routes here release: the row shows a dash and the parameter returns to the value you set. The timbre channels below do the opposite — they stay on the last reading and say held. Both are deliberate, so a dropout changes the effects and not the instrument's own voice.",
                          "A channel with no reading hands the engine a neutral 0.50 on purpose, so the instrument keeps playing its patch instead of jumping to the bottom of the scale. A channel marked held is the last measurement: the engine still has it, the signal has stopped arriving."],
                         "Perform plate and FX prose")

        // E4-41 — the photo card. `PhotoSeedText`: the two stored sentences are computed keys, `colour`, `change`
        // and the four field names go through seams (APhotoIsReadSmallAndOffTheStage pins the English at runtime:
        // "Main colour: hue 180°", "46 %", "→"); the card: the three percent lines (`Text("Brightness \(…)")` was a
        // format key), the Applied/With-this-photo heading, the Apply hint's fallback, and the spoken disclosure
        // value / Undo label / Undo hint (interpolated `undo.medium`, an identifier — now `spokenMedium`, a key).
        // TheMediaLookHasOneWriter keeps `undo.medium == MediaLookUndo.photoMedium` and `.accessibilityHint(undo.
        // applyBlockedReason ??`; "My Preset"-class identifiers (`photoMedium`) stay what they are.
        let photoCard = try codeOnly("Sources/Echoelmusic/Studio/PhotoSeedCard.swift")
        for seam in ["static var unreadable: String { String(localized: \"This photo could not be read. Try another photo.\") }",
                     "static var reading: String { String(localized: \"Reading the photo…\") }",
                     "return String(localized: \"Main colour: hue \") + \"\\(Int((seed.hue * 360).rounded()) % 360)\" + \"°\"",
                     "if from == to { return head + String(localized: \", unchanged\") }",
                     "change(String(localized: \"Intensity\"), before.intensity, after.intensity)",
                     ".accessibilityValue(disclosureValue(undo))",
                     "let state: String = isOpen ? String(localized: \"Expanded\") : String(localized: \"Collapsed\")",
                     "return applied ? state + String(localized: \", look applied\") : state",
                     "return String(localized: \"Undo \") + undo.spokenMedium + String(localized: \" look\")",
                     "let medium: String = undo.medium.isEmpty ? String(localized: \"photo\") : undo.spokenMedium",
                     "Text(String(localized: \"Brightness\") + \" \" + PhotoSeedText.percent(seed.brightness))",
                     "Text(isLive ? String(localized: \"Applied:\") : String(localized: \"With this photo:\"))",
                     "?? String(localized: \"Sets the visuals' intensity, detail, hue and saturation from the photo\")"] {
            // (E4-45 moved the `spokenMedium` body — `medium == Self.videoMedium ? …` — into MediaLookUndo; the E4-45 block pins it there.)
            XCTAssertTrue(photoCard.contains(seam), "PhotoSeedCard lost the E4-41 seam `\(seam)`")
        }
        for verbatim in ["static let unreadable", "static let reading", "return \"Main colour: hue", "\\(name) \\(from), unchanged", "change(\"Intensity\"",
                         "? \"Expanded\" : \"Collapsed\"", "\"Undo \\(undo.medium) look\"", "Text(\"Brightness \\(", "? \"Applied:\"",
                         "before the \\(undo.medium"] {
            XCTAssertFalse(photoCard.contains(verbatim), "PhotoSeedCard interpolates, stores or spells a sentence verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS: the bundle's English is unchanged (the photo guard pins the rest)
        XCTAssertEqual(PhotoSeedText.change("Hue", 0.5, 0.5), "Hue 0.50, unchanged")
        XCTAssertTrue(PhotoSeedText.unreadable.hasPrefix("This photo could not be read."))
        try assertGerman(["This photo could not be read. Try another photo.", "Reading the photo…", "No main colour", "Main colour: hue ", ", unchanged",
                          "Intensity", "Detail", "Hue", "Saturation", "Brightness", "Contrast", ", look applied", "· look applied", "Photo to Visuals",
                          "Choose a photo; its colour, brightness and contrast can shape the visuals", "Choose photo",
                          "Opens your photos. Nothing is changed until you apply it.", "Applied:", "With this photo:",
                          "Hue rotates the visual's own colours; it does not paint them the photo's colour.", "Apply to visuals",
                          "Sets the visuals' intensity, detail, hue and saturation from the photo", "Undo ", " look", "photo", "video",
                          "Puts the visuals back the way they were before the ", ". A value you changed since stays."],
                         "photo card")

        // E4-42 — the video card, the photo card's twin. `VideoSeedText`: the unreadable sentence is seams around
        // the minute number ("… up to 10 minutes …" byte-identical, AVideoCardSaysWhatWasMeasured pins it), `reading`
        // a computed key, `length`/`cuts`/`bars` count-beside-noun with typed steps (the same guard pins "1 cut or
        // flash: 2.0 s", "About 1 bar of 4/4 at 120 BPM"), `sound` two keys, the field names keys; the card: the
        // Movement/Brightness lines (format keys before), the hue line as a typed step before its ternary, the
        // heading, the Apply fallback, and the spoken disclosure value / Undo label over `spokenMedium`.
        let videoCard = try codeOnly("Sources/Echoelmusic/Studio/VideoSeedCard.swift")
        for seam in ["return String(localized: \"This video could not be read. Videos up to \") + \"\\(minutes)\" + String(localized: \" minutes can be used; try another one.\")",
                     "static var reading: String { String(localized: \"Reading the video…\") }",
                     "let head: String = String(localized: \"Length \") + seconds(seed.durationSeconds)",
                     "guard !times.isEmpty else { return String(localized: \"No cuts or flashes\") }",
                     "let overflow: String = String(localized: \" and \") + \"\\(times.count - 5)\" + String(localized: \" more\")",
                     "let noun: String = times.count == 1 ? String(localized: \"cut or flash\") : String(localized: \"cuts or flashes\")",
                     "let noun: String = bars == 1 ? String(localized: \"bar\") : String(localized: \"bars\")",
                     "return head + String(localized: \" of 4/4 at \") + \"\\(Int(bpm.rounded()))\" + \" BPM\"",
                     "hasAudio ? String(localized: \"It has sound. The sound is not used yet.\") : String(localized: \"No sound.\")",
                     "PhotoSeedText.change(String(localized: \"Motion\"), before.motion, after.motion)",
                     ".accessibilityValue(disclosureValue(undo))",
                     "let applied: Bool = undo.pending != nil && undo.medium == MediaLookUndo.videoMedium",
                     "return String(localized: \"Undo \") + undo.spokenMedium + String(localized: \" look\")",
                     "Text(String(localized: \"Movement\") + \" \" + PhotoSeedText.percent(seed.motionEnergy))",
                     "let hueLine: String = String(localized: \"Main colour: hue \") + \"\\(Int((seed.hue * 360).rounded()) % 360)\" + \"°\"",
                     "Text(seed.hasDominantColour ? hueLine : String(localized: \"No main colour\"))",
                     "Text(isLive ? String(localized: \"Applied:\") : String(localized: \"With this video:\"))",
                     "?? String(localized: \"Sets the visuals' intensity, movement, hue and saturation from the video\")"] {
            XCTAssertTrue(videoCard.contains(seam), "VideoSeedCard lost the E4-42 seam `\(seam)`")
        }
        for verbatim in ["static let reading", "return \"This video could not be read", "return \"Length \\(", "return \"No cuts or flashes\"", "? \" and \\(",
                         "? \"cut or flash\"", "? \"bar\" : \"bars\"", "return \"About \\(", "? \"It has sound.", "change(\"Intensity\"", "? \"Expanded\" : \"Collapsed\"",
                         "Text(\"Movement \\(", "                 ? \"Main colour: hue \\(", "? \"Applied:\"", "\"Undo \\(undo.medium) look\""] {
            XCTAssertFalse(videoCard.contains(verbatim), "VideoSeedCard interpolates, stores or spells a sentence verbatim again: `\(verbatim)`")
        }
        // RUNTIME COUNTERWEIGHTS beside the video guard's own: the bundle's English is unchanged
        XCTAssertEqual(VideoSeedText.cuts([1, 2, 3, 4, 5, 6, 7]), "7 cuts or flashes: 1.0 s, 2.0 s, 3.0 s, 4.0 s, 5.0 s and 2 more")
        XCTAssertTrue(VideoSeedText.unreadable.hasPrefix("This video could not be read. Videos up to "))
        try assertGerman(["This video could not be read. Videos up to ", " minutes can be used; try another one.", "Reading the video…", "Length ", " fps",
                          "No cuts or flashes", " more", "cut or flash", "cuts or flashes", "Length in bars: unknown", "About ", " of 4/4 at ",
                          "It has sound. The sound is not used yet.", "No sound.", "Motion", "Movement", "Video to Visuals",
                          "Choose a short video; its brightness, colour and movement can shape the visuals", "Choose video",
                          "Opens your videos. Nothing is changed until you apply it.", "With this video:",
                          "Movement is how much the picture changes; it sets how fast the visual moves.",
                          "Sets the visuals' intensity, movement, hue and saturation from the video",
                          "Puts the visuals back the way they were before. A value you changed since stays."],
                         "video card")

        // E4-43 — the Workstation's remaining ternaries. Mute/Solo value, the Warp switch (text, spoken value as
        // two typed steps, hint), the Pitch field's hint, the plate's Play/Stop word and label, the imported-tempo
        // field's label, and the Compose guide's disclosure value/hint were ternaries of bare literals — Strings,
        // read verbatim. Each arm is a catalog key; the one guard that pinned the Play/Stop label as source text
        // (TheWorkstationPlaysTheTimelineTests) follows the spelling, same claim.
        let workstation = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        for seam in [".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))",
                     "let mixedValue: String = state == .mixed ? String(localized: \"On for some parts\") : String(localized: \"Off\")",
                     "let warpValue: String = on ? String(localized: \"On\") : mixedValue",
                     "Text(state == .mixed ? String(localized: \"Warp · some\") : String(localized: \"Warp\"))",
                     ".accessibilityValue(warpValue)",
                     "? String(localized: \"Stop the piece to change warp\")",
                     "? String(localized: \"Stop the piece to change pitch\")",
                     "Text(running ? String(localized: \"Stop\") : String(localized: \"Play\"))",
                     ".accessibilityLabel(running ? String(localized: \"Stop all playback\") : String(localized: \"Play timeline\"))",
                     "EchoelValueField(label: known ? String(localized: \"Tempo\") : String(localized: \"Set tempo\"),",
                     ".accessibilityValue(expanded ? String(localized: \"Expanded\") : String(localized: \"Collapsed\"))",
                     ".accessibilityHint(expanded ? String(localized: \"Hides the steps\") : String(localized: \"Shows the steps\"))"] {
            XCTAssertTrue(workstation.contains(seam), "WorkstationView lost the E4-43 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(on ? \"On\" : \"Off\")", "Text(state == .mixed ? \"Warp · some\" : \"Warp\")",
                         "\"On for some parts\" : \"Off\"", "                ? \"Stop the piece to change warp\"",
                         "                    ? \"Stop the piece to change pitch\"", "Text(running ? \"Stop\" : \"Play\")",
                         ".accessibilityLabel(running ? \"Stop all playback\" : \"Play timeline\")", "label: known ? \"Tempo\" : \"Set tempo\",",
                         ".accessibilityValue(expanded ? \"Expanded\" : \"Collapsed\")", ".accessibilityHint(expanded ? \"Hides the steps\" : \"Shows the steps\")"] {
            XCTAssertFalse(workstation.contains(verbatim), "WorkstationView spells a ternary of bare literals again: `\(verbatim)`")
        }
        try assertGerman(["On", "Off", "Warp", "Warp · some", "On for some parts", "Stop the piece to change warp",
                          "Plays this track's parts at the piece's tempo instead of their recorded speed", "Stop the piece to change pitch",
                          "Moves every part on this track up or down without changing its tempo", "Stop", "Play", "Stop all playback",
                          "Play timeline", "Tempo", "Set tempo", "Expanded", "Collapsed", "Hides the steps", "Shows the steps"],
                         "Workstation ternaries")

        // E4-44 — the three On/Off siblings of the E4-43 header switch: the Perform mix switch, the project header's
        // Guide button and the Workstation click toggle each spoke `on ? "On" : "Off"` — a String, read verbatim.
        // Both arms are the catalog's On/Off keys (no new units); the three guards that pinned the old spelling as
        // source text (PerformIsASecondViewOfTheSameSession, TheGuideHasADoor, TheWorkstationArmsTheClick) follow it.
        let mixSwitch = try codeOnly("Sources/Echoelmusic/Studio/PerformSessionView.swift")
        for seam in [".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))"] {
            XCTAssertTrue(mixSwitch.contains(seam), "PerformSessionView lost the E4-44 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(on ? \"On\" : \"Off\")"] {
            XCTAssertFalse(mixSwitch.contains(verbatim), "PerformSessionView speaks a bare On/Off again: `\(verbatim)`")
        }
        let headerGuide = try codeOnly("Sources/Echoelmusic/Studio/ProjectHeader.swift")
        for seam in [".accessibilityValue(guideVisible ? String(localized: \"On\") : String(localized: \"Off\"))"] {
            XCTAssertTrue(headerGuide.contains(seam), "ProjectHeader lost the E4-44 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(guideVisible ? \"On\" : \"Off\")"] {
            XCTAssertFalse(headerGuide.contains(verbatim), "ProjectHeader speaks a bare On/Off again: `\(verbatim)`")
        }
        let clickLeaf = try codeOnly("Sources/Echoelmusic/Studio/WorkstationClickToggle.swift")
        for seam in [".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))"] {
            XCTAssertTrue(clickLeaf.contains(seam), "WorkstationClickToggle lost the E4-44 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(on ? \"On\" : \"Off\")"] {
            XCTAssertFalse(clickLeaf.contains(verbatim), "WorkstationClickToggle speaks a bare On/Off again: `\(verbatim)`")
        }
        try assertGerman(["On", "Off"], "On/Off siblings")

        // E4-45 — the blocked-Apply sentence. `MediaLookUndo.applyBlockedReason` interpolated the compared identifier
        // (`"A \(medium) look is applied. …"`) — a String, read verbatim and naming "photo"/"video" in English. It is
        // now seams around `spokenMedium`, which moved from the photo card's PhotosUI-guarded extension into the
        // Foundation-only owner (one home for the spoken word, E4-41's rule). TheMediaLookHasOneWriterTests pins the
        // English end-to-end, so the bundle's sentence is byte-identical; this block pins the SHAPE.
        let lookOwner = try codeOnly("Sources/Echoelmusic/Studio/MediaLookUndo.swift")
        for seam in ["var spokenMedium: String {",
                     "medium == Self.videoMedium ? String(localized: \"video\") : String(localized: \"photo\")",
                     "return String(localized: \"A \") + spokenMedium + String(localized: \" look is applied. Undo it first to apply this one.\")"] {
            XCTAssertTrue(lookOwner.contains(seam), "MediaLookUndo lost the E4-45 seam `\(seam)`")
        }
        for verbatim in ["medium) look is applied"] {
            XCTAssertFalse(lookOwner.contains(verbatim), "MediaLookUndo interpolates the compared identifier into the spoken sentence again: `\(verbatim)`")
        }
        let photoCardTail = try codeOnly("Sources/Echoelmusic/Studio/PhotoSeedCard.swift")
        for verbatim in ["extension MediaLookUndo {"] {
            XCTAssertFalse(photoCardTail.contains(verbatim), "the spoken medium has a second home in the photo card again: `\(verbatim)`")
        }
        try assertGerman(["A ", " look is applied. Undo it first to apply this one.", "photo", "video"], "blocked-Apply sentence")

        // E4-46 — EchoelStudioView's remaining ternaries and two interpolated spoken labels: the Explore/New button
        // (text + label), the variation row's spoken label (rank, match, playing — typed steps), the visual-window
        // button (text + label), the visual-preset hint, the look chip's spoken value (position) and hint, the two
        // favourite menu labels, and the „Default sound“ pair. Each arm or seam is a catalog key.
        let studioSites = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["Text(mazeBoard == nil ? String(localized: \"Explore\") : String(localized: \"New\"))",
                     ".accessibilityLabel(mazeBoard == nil ? String(localized: \"Explore variations\") : String(localized: \"Explore new variations\"))",
                     "let variationHead: String = String(localized: \"Variation \") + \"\\(rank + 1)\" + \", \"",
                     "let playingSuffix: String = isOn ? String(localized: \", playing\") : \"\"",
                     "let variationLabel: String = variationHead + \"\\(pct)\" + String(localized: \" percent match\") + playingSuffix",
                     ".accessibilityLabel(variationLabel)",
                     "Text(floatingVisualVisible ? String(localized: \"Hide visual window\") : String(localized: \"Show visual window\"))",
                     ".accessibilityLabel(floatingVisualVisible ? String(localized: \"Hide the floating visual window\") : String(localized: \"Show the floating visual window\"))",
                     ".accessibilityHint(selected ? String(localized: \"Double tap to clear\") : String(localized: \"Double tap to apply\"))",
                     "let positionText: String = String(localized: \"in the slider, position \") + \"\\((pos ?? 0) + 1)\"",
                     "let sliderValue: String = on ? positionText : String(localized: \"not in the slider\")",
                     ".accessibilityValue(sliderValue)",
                     ".accessibilityHint(on ? String(localized: \"Double tap to remove from the slider\") : String(localized: \"Double tap to add to the slider\"))",
                     "Label(isFav ? String(localized: \"Unfavorite\") : String(localized: \"Favorite\"), systemImage: isFav ? \"star.slash\" : \"star\")",
                     "Text(soundResetArmed ? String(localized: \"Tap again for the default sound\") : String(localized: \"Default sound\"))"] {
            XCTAssertTrue(studioSites.contains(seam), "EchoelStudioView lost the E4-46 seam `\(seam)`")
        }
        for verbatim in ["Text(mazeBoard == nil ? \"Explore\" : \"New\")", "? \"Explore variations\" :", "percent match\\(isOn ?",
                         "? \"Hide visual window\" :", "? \"Hide the floating visual window\" :", "? \"Double tap to clear\" :",
                         "? \"in the slider, position \\(", "? \"Double tap to remove from the slider\" :", "Label(isFav ? \"Unfavorite\" : \"Favorite\"",
                         "? \"Tap again for the default sound\" :"] {
            XCTAssertFalse(studioSites.contains(verbatim), "EchoelStudioView spells a ternary or interpolated label of bare literals again: `\(verbatim)`")
        }
        try assertGerman(["Explore", "New", "Explore variations", "Explore new variations", "Variation ", ", playing", " percent match",
                          "Hide visual window", "Show visual window", "Hide the floating visual window", "Show the floating visual window",
                          "Double tap to clear", "Double tap to apply", "in the slider, position ", "not in the slider",
                          "Double tap to remove from the slider", "Double tap to add to the slider", "Unfavorite", "Favorite",
                          "Tap again for the default sound", "Default sound"],
                         "Studio sites")

        // E4-47 — the four analysis views' readouts. Spectrum: the spoken form interpolated the number and the note into
        // one literal with "sharp"/"flat" arms; Scope: the Silent/Peak pair (printed + spoken); Wavefront: three sentences
        // around the ring count and the centroid; Poincaré: the camera-off, waiting, refusal and SD1/SD2 lines. Each is
        // now typed steps of catalog keys around the numbers (≤ 4 operands per step); the units `Hz`, `ct`, `dBTP`, `ms`
        // and the printed `·` separator stay verbatim. AnalysisViewsSpeakTheirNumbersTests was re-anchored in the same
        // commit from `spoken = "` to `spoken = ` — a broader filter over the same two negatives.
        let spectrumReadout = try codeOnly("Sources/Echoelmusic/Studio/AnalysisSpectrumView.swift")
        for seam in ["let quiet = String(localized: \"No dominant tone\")",
                     "return (\"\\(hz) Hz\", String(localized: \"Loudest tone \") + hz + String(localized: \" hertz\"))",
                     "let tone: String = String(localized: \"Loudest tone \") + hz + String(localized: \" hertz, \") + \"\\(name)\\(octave)\"",
                     "spoken = tone + String(localized: \", in tune\")",
                     "let direction: String = cents > 0 ? String(localized: \" cents sharp\") : String(localized: \" cents flat\")",
                     "spoken = tone + \", \" + \"\\(abs(cents))\" + direction"] {
            XCTAssertTrue(spectrumReadout.contains(seam), "AnalysisSpectrumView lost the E4-47 seam `\(seam)`")
        }
        for verbatim in ["spoken = \"Loudest tone", "cents > 0 ? \"sharp\" : \"flat\"", "(\"No dominant tone\", \"No dominant tone\")"] {
            XCTAssertFalse(spectrumReadout.contains(verbatim), "AnalysisSpectrumView speaks an interpolated literal again: `\(verbatim)`")
        }
        let scopeReadout = try codeOnly("Sources/Echoelmusic/Studio/AnalysisScopeView.swift")
        for seam in ["let peakShown: String = String(localized: \"Peak \") + value + \" dBTP\"",
                     "let shown: String = silent ? String(localized: \"Silent\") : peakShown",
                     "let peakSpoken: String = String(localized: \"Peak \") + value + String(localized: \" decibels true peak\")",
                     "let spoken: String = silent ? String(localized: \"Silent\") : peakSpoken",
                     "return Text(shown)", ".accessibilityLabel(spoken)"] {
            XCTAssertTrue(scopeReadout.contains(seam), "AnalysisScopeView lost the E4-47 seam `\(seam)`")
        }
        for verbatim in ["Text(silent ? \"Silent\" :", "? \"Silent\"", "\"Peak \\(value)"] {
            XCTAssertFalse(scopeReadout.contains(verbatim), "AnalysisScopeView spells the Silent/Peak pair as bare literals again: `\(verbatim)`")
        }
        let wavefrontReadout = try codeOnly("Sources/Echoelmusic/Studio/AnalysisWavefrontView.swift")
        for seam in ["return String(localized: \"Wavefront field. Silent. Nothing is sounding, so no wave is leaving the centre.\")",
                     "let several: String = \"\\(rings)\" + String(localized: \" wavefronts are\")",
                     "let subject: String = rings == 1 ? String(localized: \"One wavefront is\") : several",
                     "let field: String = String(localized: \"Wavefront field. \") + subject",
                     "return field + String(localized: \" spreading outward.\")",
                     "return field + String(localized: \" spreading outward, the newest centred near \") + \"\\(hertz)\" + String(localized: \" hertz.\")"] {
            XCTAssertTrue(wavefrontReadout.contains(seam), "AnalysisWavefrontView lost the E4-47 seam `\(seam)`")
        }
        for verbatim in ["return \"Wavefront field.", "? \"One wavefront is\" :"] {
            XCTAssertFalse(wavefrontReadout.contains(verbatim), "AnalysisWavefrontView speaks an interpolated literal again: `\(verbatim)`")
        }
        let poincareReadout = try codeOnly("Sources/Echoelmusic/Studio/AnalysisPoincareView.swift")
        for seam in ["return String(localized: \"Camera pulse is off. This plot reads the camera pulse only.\")",
                     "return String(localized: \"Waiting for beats\")",
                     "return \"SD1 — · SD2 — · \" + String(localized: \"only \") + \"\\(clean)%\" + String(localized: \" of beats usable\")",
                     "return \"SD1 \\(sd1) ms · SD2 \\(sd2) ms · \\(d.pairs)\" + String(localized: \" beat pairs\")"] {
            XCTAssertTrue(poincareReadout.contains(seam), "AnalysisPoincareView lost the E4-47 seam `\(seam)`")
        }
        for verbatim in ["return \"Waiting for beats\"", "return \"Camera pulse is off.", "% of beats usable", "\\(d.pairs) beat pairs"] {
            XCTAssertFalse(poincareReadout.contains(verbatim), "AnalysisPoincareView speaks a bare literal again: `\(verbatim)`")
        }
        try assertGerman(["No dominant tone", "Loudest tone ", " hertz", " hertz, ", ", in tune", " cents sharp", " cents flat",
                          "Silent", "Peak ", " decibels true peak",
                          "Wavefront field. Silent. Nothing is sounding, so no wave is leaving the centre.", " wavefronts are",
                          "One wavefront is", "Wavefront field. ", " spreading outward.", " spreading outward, the newest centred near ", " hertz.",
                          "Camera pulse is off. This plot reads the camera pulse only.", "Waiting for beats", "only ", " of beats usable", " beat pairs"],
                         "Analysis readouts")
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
