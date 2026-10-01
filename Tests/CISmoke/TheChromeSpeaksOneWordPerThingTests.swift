// TheChromeSpeaksOneWordPerThingTests.swift
// Echoel — interface audit 2026-09-30, rule 1: one word per thing, app-wide (COGA objective 3).
//
// WHAT THIS GUARDS. `docs/dev/GLOSSARY.md` is the ONE definition of the words the app
// wears — piece · track · part · scene · loop — and, per word, the synonyms that are STRUCK
// from visible text (project / session / song → piece; lane → track; clip / region / take →
// part; section → scene). This file READS that table (claim 1) and scans the CHROME files'
// visible string literals for any struck word (claim 2); it does not carry a second copy of
// the list (#416). Claim 3 pins the three head sentences a fresh install meets first
// end-to-end, through the same functions the header calls. Claim 4 proves the scanner can
// match at all, on planted lines — a parser that matches nothing is a finding, never a pass.
//
// WHY CHROME FIRST. Measured before the first slice: 24 visible literals in five chrome
// files carried a struck word ("song" ×16, "session" ×7, "lane" ×1); the panels carry an
// order of magnitude more, and several of those words have a second meaning there ("take"
// the verb, `AVAudioSession` in a log line, SwiftUI's `Section`). The audit's own answer was
// "Chrome zuerst (~40 Wörter), Panels danach". So the scope is a LIST of files, and a file is
// added to it in the same commit that cleans it — never by a bulk rename, which is how a
// second meaning gets renamed into nonsense.
//
// HOW "VISIBLE" IS DECIDED, and the accepted limits of a source-text scan:
//   · comment-stripped (`SourceText.codeOnly`), so a rationale that QUOTES a struck word
//     ("never say song") cannot fail the guard;
//   · `\( … )` interpolations removed, so `session.a4Hz` inside a literal is code, not a word;
//   · lines carrying `log.`, `os_log`, `breadcrumb`, `Logger`, `accessibilityIdentifier` or a
//     `source: "` provenance tag are skipped — those strings reach a log, not a person;
//   · literals are split on `"`; an ESCAPED quote inside a literal fragments it, which can
//     only MISS a word, never invent one. Accepted.
//   · word boundaries by tokenising on non-letters: "song's" → song; "songs" → song (a
//     trailing `s` is folded). "Session" in a type name inside a literal would count — and
//     should, because a person reads it.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 7d256511d (no local toolchain): claim 1 RED on the parent (the glossary file is born here);
// claim 2 RED on the parent for its named reason — the 24 literals above, ONE finding
// reported per file (#486); claim 3 RED on the parent (the three sentences said "song" and
// "session"); claim 4 GREEN on both — it exercises the scanner on planted lines and is the
// counterweight (#343) that keeps claim 2's "no violations" from being the silence of a
// scanner that reads nothing.
//
// ⭐ RATCHET 2 (2026-09-30, same day): `WorkstationView` — the piece stage itself, the HOME since
// the first audit slice — joins the list. Measured on 457343726 with this scanner: 18 visible
// hits ("song" ×14, "session" ×4), all renamed to the glossary word, plus ONE "lane" the scanner
// cannot see (a literal nested inside an interpolation, `\(count == 1 ? "lane" : "lanes")`) —
// reworded by hand to "automated parameter(s)", which is what an automation row is. The row's two
// doors now speak the instrument's own tile names ("Save this piece" / "Open a saved piece");
// `TheSongAloneCanBeSavedTests` pins those. Claim 2 is RED on the parent for WorkstationView
// by the 18 named hits; the eight earlier files stay green on both.
//
// ⭐ RATCHET 3 (2026-09-30): `SessionLaunchView` — the scene grid both stages mount (the piece
// stage and Perform). Measured with this scanner on 0b9d055ba: 12 hits ("song" ×11, "session" ×1).
// The grid's heading said "Session" — the struck word itself, as a title; it now says "Scenes",
// the glossary word for what its rows are. "Back to song" → "Back to the piece" (the label, its
// VoiceOver twin and the hint); `backToSongButton` and `songStart` are identifiers and stay.
// `TheSceneLaunchIsASwitchTests` pins the start hint by its new words.
//
// ⭐ RATCHET 4 (2026-09-30): `RecordTakeControls` — the Record door's captions. Measured on
// 08aa6601f: 10 hits ("song" ×5, "take" ×5). "take" here meant the RECORDING (the thing being
// written), which the glossary's "what the words are NOT" names "recording" — so the captions
// say "the recording" / "Recording starts at bar 1", and the block it becomes stays a PART.
// The type `RecordTake`, `droppedTakes` and the test names keep the word: identifiers.
// `TheMIDITakeIsRecordedFromTheWorkstationTests` pins the dropped sentence end to end by its
// new words.
//
// ⭐ RATCHET 5 (2026-09-30): `EchoelStudioView` — the instrument itself, 54 hits on 457343726, read
// in FOUR families over five commits because the same struck word meant different things in one
// file: song/project (the saved work) → piece; "session" (the piece · the sitting · AVAudioSession
// · the breathing view) → piece / a sentence that says what happens / "what iOS granted" /
// "Breathing guide"; "take" (the export recording · the generated loop · the touch voice) →
// "this recording" / "the instrument's music" / "Same as music"; and the rule-6 words: "Reset
// sound" → "Default sound" (the value's word IS the action's word — the confirm step stays),
// "back to factory" → "back to their defaults", the mastering meters' "Reset" → "Clear" (a meter
// is cleared, it has no default). Two false positives were reworded rather than allowed for:
// "Project: mirror to a screen" (the projector, not the noun) → "Show on a screen", and the launch
// breadcrumb's presence flag `"take"` → `"same"` (a diagnostic on the line before its `breadcrumb`
// marker). The scanner cannot tell a verb from a noun; keeping it that way keeps claim 4 honest.
//
// ⭐ RATCHET 6 (2026-09-30): `MediaBrowserView` — 6 hits: "song" ×4 → piece; "clip" ×2 were the
// library's own object shown to a person ("Relink points a clip at…" → "its parts"; "in a clip,
// no part yet" → "imported, not placed yet" — the state the row describes, not the type that holds it).
//
// ⭐ RATCHET 7 (2026-09-30): `LiveColaboView` — 6 hits, all "session", all meaning the PIECE that
// `colab.share(project:)` sends: "share your piece both ways", "Share this piece", "share pieces with
// you" ×2, "Piece from <peer>"; the invite's VoiceOver label now matches its visible text ("wants to
// join you"). The nearby sheet's name in the guard files ("NearbySession") is a code identifier.
//
// ⭐ RATCHET 8 (2026-09-30): `PatchbayView` — 6 hits. Five "session" were Apple's Network-MIDI *session*,
// a protocol word that collides with the struck one; to a person it is a CONNECTION ("connect to this
// iPhone over MIDI", "accepts a MIDI connection", "no incoming connection"), and the toggle is simply
// "Wireless MIDI". One "take effect" → "apply". The identifier `applyNetworkSessionPreference` keeps
// its name (code is not what a person reads).
//
// ⭐ RATCHET 9 (2026-09-30): `EchoelAppIntents` — 8 "session" in what Siri, Spotlight and the
// Shortcuts app SHOW and what a person SAYS. The intent starts `startBiofeedback()` and stops
// `stopEverything` — the instrument and the pulse reading, in the words the Stop button already uses.
// Titles "Start Echoelmusic" / "Stop Echoelmusic", short titles "Start playing" / "Stop playing",
// phrases "Start playing in …" / "Stop playing in …". Type names (`StartEchoelSessionIntent`) are
// code and stay; the web manifest's shortcut (docs/manifest.json) follows in the same commit.
//
// ⭐ RATCHET 10 (2026-09-30): `AlwaysOnBioChannel` — 5 hits in the bio-panel and sound-panel copy.
// "while a session runs" ×3 meant the SITTING → "while the instrument plays" (the sentence says what
// happens, the pattern of the second instrument-file family); "for the rest of this session" →
// "until you stop"; "take over the note" was a verb (scanner false positive) → "carry the note".
// TheAlwaysOnRowsSayWhoseBodyTests' shared tail and TheSoundPanelNamesItsActualDriverTests' prefix
// follow the sentence, as their own messages instruct.
//
// ⭐ RATCHET 11 (2026-09-30): `Sequencer/MediaRelink` — the first non-Studio file: its `userMessage`
// strings are shown verbatim by the media browser. "clip" ×3 → "part" (a person relinks the part they
// see; the shared clip is what changes underneath), "Stop the song" → "Stop the piece".
//
// ⭐ RATCHET 12 (2026-09-30): `Sequencer/MIDIImport` — refusal and success notes shown by the import
// door. "This project" → "This piece", "The clip grid is full" → "The part slots are full", "at the
// song tempo" ×2 → "at the piece's tempo", "Generate won't place its take" → "its music" (the
// instrument's generated loop, the third instrument-file family's word).
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheChromeSpeaksOneWordPerThingTests: XCTestCase {

    private static let glossary = "docs/dev/GLOSSARY.md"

    /// The chrome: what a fresh install sees before it opens any plate. Add a file here in the
    /// SAME commit that removes its struck words — the list is the ratchet.
    private static let chrome = [
        "Sources/Echoelmusic/Studio/ProjectHeader.swift",
        "Sources/Echoelmusic/Studio/ProjectTransport.swift",
        "Sources/Echoelmusic/Studio/HeaderMonitors.swift",
        "Sources/Echoelmusic/Studio/WorkspaceView.swift",
        "Sources/Echoelmusic/Studio/StageShell.swift",
        "Sources/Echoelmusic/Studio/GuideOverlay.swift",
        "Sources/Echoelmusic/Studio/WorkstationSummary.swift",
        "Sources/Echoelmusic/Studio/SongHistoryRow.swift",
        "Sources/Echoelmusic/Studio/ComposeGuide.swift",
        "Sources/Echoelmusic/Studio/WorkstationView.swift",
        "Sources/Echoelmusic/Studio/SessionLaunchView.swift",
        "Sources/Echoelmusic/Studio/RecordTakeControls.swift",
        "Sources/Echoelmusic/Studio/EchoelStudioView.swift",
        "Sources/Echoelmusic/Studio/MediaBrowserView.swift",
        "Sources/Echoelmusic/Studio/LiveColaboView.swift",
        "Sources/Echoelmusic/Studio/PatchbayView.swift",
        "Sources/Echoelmusic/Studio/EchoelAppIntents.swift",
        "Sources/Echoelmusic/Studio/AlwaysOnBioChannel.swift",
        "Sources/Echoelmusic/Sequencer/MediaRelink.swift",
        "Sources/Echoelmusic/Sequencer/MIDIImport.swift",
        // Ratchet 13 (2026-09-30): the Workstation's own surfaces — the area bar's spoken hints,
        // the Perform grid's three notes, the track inspector's three hints, the part bar's Play,
        // the position readout's label and the save-status hint. Thirteen struck words in twelve
        // visible literals (song / project / take / reset) say piece, music and default now.
        // (`StudioArea.swift` left this list on 2026-10-01: the area row and its type are deleted,
        // and a listed file that is not on disk makes `codeLines` skip the whole claim.)
        "Sources/Echoelmusic/Studio/PerformSessionView.swift",
        "Sources/Echoelmusic/Studio/TrackInspectorView.swift",
        "Sources/Echoelmusic/Studio/SelectedPartBar.swift",
        "Sources/Echoelmusic/Studio/SongPositionReadout.swift",
        "Sources/Echoelmusic/Studio/ProjectSaveStatusView.swift",
        // Ratchet 14 (2026-09-30): the last reachable eight — the automation editor's hints
        // (end of the piece), the safe-mode note, the theory primer, the note editor's shared
        // hint (these notes, not this clip), the Learn detail (generated music), the FX empty
        // note (start the instrument), the automation strip (part curves), the metric sheet.
        "Sources/Echoelmusic/Studio/SongAutomationEditor.swift",
        "Sources/Echoelmusic/Studio/SafeModeView.swift",
        "Sources/Echoelmusic/Studio/MusicTheoryPrimer.swift",
        "Sources/Echoelmusic/Studio/PartNoteEditor.swift",
        "Sources/Echoelmusic/Studio/LearnLibrary.swift",
        "Sources/Echoelmusic/Studio/EchoelFXView.swift",
        "Sources/Echoelmusic/Studio/AutomationStatusStrip.swift",
        "Sources/Echoelmusic/Studio/BioMetricInfo.swift",
        // Ratchet 15 (2026-09-30): beyond Studio — the sentences the model layer hands the
        // screen: the import refusals, the open-refusals, the placement status, the names a
        // recording and a nameless part or scene get, the automation layer label, the rack's
        // default-effect name. (Project, ArrangementStore and MultipeerSession were cleaned too
        // but stay OUTSIDE the list: their remaining hits are persisted file names, a protocol
        // key and multi-line log calls the harness filter cannot see.)
        "Sources/Echoelmusic/Sequencer/AudioImport.swift",
        "Sources/Echoelmusic/Core/SessionSaveOpen.swift",
        "Sources/Echoelmusic/Sequencer/MediaPlacement.swift",
        "Sources/Echoelmusic/Sequencer/TakeRecorder.swift",
        "Sources/Echoelmusic/Sequencer/Clip.swift",
        "Sources/Echoelmusic/Sequencer/Arrangement.swift",
        "Sources/Echoelmusic/Sequencer/AutomationStatus.swift",
        "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift",
        // Ratchet 16 (2026-09-30): the body's copy, the strap remedy, the weather hint, the
        // Clean blurb, the note editor's refusal, and the two glances outside the app — the
        // watch face and the widget (reading, not session; the instrument, not a session).
        // MultipeerSession's two status lines were rewritten too; the file stays outside
        // (protocol key, multi-line log).
        "Sources/Echoelmusic/Bio/BioSoundMapping.swift",
        "Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift",
        "Sources/Echoelmusic/Core/WeatherMood.swift",
        "Sources/Echoelmusic/Sequencer/GenreFX.swift",
        "Sources/Echoelmusic/Sequencer/ClipNoteEdit.swift",
        "Sources/EchoelmusicWatch/EchoelWatchApp.swift",
        "Sources/EchoelmusicWidgets/EchoelBioWidget.swift",
        // Ratchet 17 (2026-09-30), the last: the DOORLESS surfaces. The breathing guide
        // (the Session experiment nothing presents), the coherence practice (MeditationView,
        // whose flag nothing sets), the entrainment band names, and the agent's replies.
        // EchoelCommand.swift stays OUTSIDE: its visible text is rewritten too, but its raw
        // command ids (project.describeState) are protocol keys and would read as hits.
        "Sources/Echoelmusic/Studio/SessionView.swift",
        "Sources/Echoelmusic/Studio/MeditationView.swift",
        "Sources/Echoelmusic/DSP/EchoelEntrainment.swift",
        "Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift",
    ]

    /// A line whose strings reach a log or a test harness, not a person.
    private static let notVisibleMarkers = ["log.", "os_log", "breadcrumb", "Logger", "accessibilityIdentifier", "source: \""]

    // MARK: - claim 1 — the glossary file is the one definition, and it has the shape the scan reads

    func testTheGlossaryNamesTheOneWordAndItsStruckSynonyms() throws {
        let rows = try glossaryRows()
        let words = Set(rows.map { $0.word })
        for expected in ["piece", "track", "part", "scene", "loop"] {
            XCTAssertTrue(words.contains(expected), """
                `docs/dev/GLOSSARY.md` no longer has a row for "\(expected)". The table is the \
                ONE definition of the app's words (rule 1, one word per thing); the founder's \
                audit table names five, and this guard reads the file rather than carrying a \
                copy. Restore the row — or, if the word was retired on purpose, retire it here \
                in the same commit and say why in the file.
                """)
        }
        let struck = Set(rows.flatMap { $0.struck })
        for expected in ["project", "session", "song", "lane", "clip", "region", "take", "section"] {
            XCTAssertTrue(struck.contains(expected), """
                "\(expected)" is no longer listed as STRUCK in `docs/dev/GLOSSARY.md`. A word \
                that leaves the struck column is a word the chrome may say again, so this is a \
                vocabulary decision, not a table tidy-up — make it in the file with its reason.
                """)
        }
    }

    // MARK: - claim 2 — no struck word in a visible chrome string

    func testTheChromeSpeaksNoStruckWord() throws {
        let struck = Set(try glossaryRows().flatMap { $0.struck })
        XCTAssertFalse(struck.isEmpty, "the glossary yielded no struck words — the parser matched nothing (claim 1 says why)")
        var violations: [String] = []
        for file in Self.chrome {
            let lines = try codeLines(file)
            for (index, line) in lines.enumerated() {
                for hit in Self.struckWords(inCodeLine: line, struck: struck) {
                    violations.append("\(file.split(separator: "/").last ?? ""):\(index + 1) — \"\(hit.literal)\" says \"\(hit.word)\"")
                }
            }
        }
        XCTAssertTrue(violations.isEmpty, """
            A chrome string uses a word the glossary struck (rule 1, one word per thing — \
            `docs/dev/GLOSSARY.md`): the saved work is the PIECE (not song / project / \
            session), a row is a TRACK (not lane), a block is a PART (not clip / region / \
            take), a Perform row is a SCENE (not section). A beginner reading two words for one \
            thing has to guess whether they are two things. Say the glossary word, or — if the \
            sentence genuinely means something else (a verb, a system name) — reword it so the \
            struck word is not there. Found:
            \(violations.joined(separator: "\n"))
            """)
    }

    // MARK: - claim 3 — the three head sentences a fresh install meets, end to end

    func testTheHeadSaysPieceAndPulseReading() {
        XCTAssertEqual(ProjectTransport.buttonLabel(running: false, play: .startSong), "Play the piece",
                       "the one Play names the PIECE (rule 1); `TheProjectHeaderRunsOneTransportTests` pins the rest of the label set")
        XCTAssertEqual(ProjectTransport.statusWord(.playingSong), "Playing piece",
                       "the status word beside the transport names the piece, not a song")
        XCTAssertEqual(ProjectTransport.unsavedName, "Unsaved piece",
                       "the head's fallback name is a PIECE — it was \"Unsaved session\", a third word for the same thing")
        XCTAssertTrue(ProjectTransport.stopHint.contains("pulse reading"),
                      "the Stop's hint names the measurement by the strip's own word, \"pulse reading\", never \"pulse session\"")
        XCTAssertFalse(ProjectTransport.stopHint.lowercased().contains("session"),
                       "the Stop's hint may not say \"session\" at all — the piece, the instrument and the pulse reading are its three things")
    }

    // MARK: - claim 4 — the scanner can match (counterweight)

    func testTheScannerFindsAPlantedWordAndIgnoresCodeAndLogs() {
        let struck: Set<String> = ["song", "session", "lane"]
        let planted = Self.struckWords(inCodeLine: "            Text(\"Play the song's parts\")", struck: struck)
        XCTAssertEqual(planted.map(\.word), ["song"], "a visible literal with a possessive struck word must be found")
        let plural = Self.struckWords(inCodeLine: "label: \"Two lanes\"", struck: struck)
        XCTAssertEqual(plural.map(\.word), ["lane"], "a plural folds to its word")
        let interpolated = Self.struckWords(inCodeLine: "f.append(\"\\(session.a4Hz.rounded()) Hz\")", struck: struck)
        XCTAssertTrue(interpolated.isEmpty, "code inside an interpolation is not a word a person reads")
        let logged = Self.struckWords(inCodeLine: "log.log(.info, category: .audio, \"audio session up\")", struck: struck)
        XCTAssertTrue(logged.isEmpty, "a log line is not visible text")
        let provenance = Self.struckWords(inCodeLine: "ProjectTransport.stop(song: player, source: \"project session\")", struck: struck)
        XCTAssertTrue(provenance.isEmpty, "a `source:` provenance tag reaches the diag log, not a person")
        let clean = Self.struckWords(inCodeLine: "Text(\"Play the piece\")", struck: struck)
        XCTAssertTrue(clean.isEmpty, "the glossary word itself is never a hit")
    }

    // MARK: - The scan

    private struct Hit: Equatable { let word: String; let literal: String }

    /// Struck words in the visible literals of ONE comment-stripped code line.
    private static func struckWords(inCodeLine line: String, struck: Set<String>) -> [Hit] {
        for marker in notVisibleMarkers where line.contains(marker) { return [] }
        var hits: [Hit] = []
        for literal in visibleLiterals(inCodeLine: line) {
            let stripped = withoutInterpolations(literal)
            let tokens = stripped.lowercased().split { !$0.isLetter }.map(String.init)
            for token in tokens {
                let folded = token.hasSuffix("s") ? String(token.dropLast()) : token
                if struck.contains(token) { hits.append(Hit(word: token, literal: literal)) }
                else if struck.contains(folded) { hits.append(Hit(word: folded, literal: literal)) }
            }
        }
        return hits
    }

    /// The string literals of a line: the odd-indexed pieces between `"`. An escaped quote
    /// fragments a literal (accepted — it can only miss, never invent).
    private static func visibleLiterals(inCodeLine line: String) -> [String] {
        let pieces = line.components(separatedBy: "\"")
        guard pieces.count >= 3 else { return [] }
        var out: [String] = []
        var index = 1
        while index < pieces.count - 1 {
            out.append(pieces[index])
            index += 2
        }
        return out
    }

    /// The literal with every `\( … )` removed, parentheses balanced.
    private static func withoutInterpolations(_ literal: String) -> String {
        var out = ""
        var depth = 0
        var previousWasBackslash = false
        for character in literal {
            if depth > 0 {
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                continue
            }
            if previousWasBackslash && character == "(" {
                out.removeLast()
                depth = 1
                previousWasBackslash = false
                continue
            }
            previousWasBackslash = (character == "\\")
            out.append(character)
        }
        return out
    }

    // MARK: - Reading the glossary

    private struct Row { let word: String; let struck: [String] }

    /// The rows of the one-word table: `| word | Wort | struck | meaning |`, header and
    /// separator skipped; "—" in the struck column means none.
    private func glossaryRows() throws -> [Row] {
        let url = try repoRoot().appendingPathComponent(Self.glossary)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("`docs/dev/GLOSSARY.md` is missing — it is the ONE definition of the app's words (rule 1); the guard reads it, it does not carry a copy")
            return []
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        var rows: [Row] = []
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("|"), !line.hasPrefix("|---") else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            // leading and trailing empty cells from the outer bars
            guard cells.count == 6 else { continue }
            let word = cells[1].lowercased()
            if word == "word" { continue }
            let struck = cells[3] == "—" ? [] : cells[3].split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            rows.append(Row(word: word, struck: struck))
        }
        return rows
    }

    // MARK: - Reading the source

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("repository root not found from \(#filePath) — source scan skipped, not passed")
        }
        return url
    }

    /// Comment-stripped lines of `path` (line numbers preserved for the failure text).
    private func codeLines(_ relativePath: String) throws -> [String] {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — the chrome list names a file that moved; update the list, do not let the scan pass on nothing")
        }
        let code = SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
        return code.components(separatedBy: "\n")
    }
}
