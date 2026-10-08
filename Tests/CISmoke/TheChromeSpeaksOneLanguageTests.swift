// TheChromeSpeaksOneLanguageTests.swift
// ⭐ INVERTED 2026-10-02 (founder: "Nur Englisch" — the app speaks American English only). This file
// was `TheChromeSpeaksGermanTests` (decision E4, 2026-09-30) and every claim asked "does this word
// have a German unit?". The German units are removed from `Localizable.xcstrings` (they stay in git
// history, recoverable per key), and each claim now asks the inverse with the SAME reach: the word is
// still a catalog key looked up through `String(localized:)` / a `LocalizedStringKey`, its `en` unit
// is translated and equals the key, and the entry carries NO second language (`catalogued(_:in:)`).
// Nothing was deleted or loosened: a word that leaves the catalog is red exactly as before, and a
// `de` unit that comes back is now red too. The catalog infrastructure stays — a future second
// language is a founder decision, and it starts by re-adding units, not by re-wiring the chrome.
// The prose below is the E4 history and still says "German" where it describes how a claim was BUILT.
//
// Echoel — decision E4 of the interface audit (founder 2026-09-30, "Ja": the app speaks German,
// chrome first, ~40 words): every word of the stage seam and the head transport has a German
// unit in `Localizable.xcstrings`, and the code reaches the catalog for it. (The area row's ten
// words were the third family until the row was deleted, 2026-10-01 — they left the catalog
// with it.)
//
// KIND — two kinds, labelled per claim (Tests/CISmoke/CLAUDE.md §1):
//   · END-TO-END for the WORDS: the shipped enums and `ProjectTransport` are driven (they are
//     Foundation-only) and every word they return is looked up as a KEY in the catalog. In the
//     test host the locale is English, so `String(localized:)` returns the key itself — which is
//     exactly the string the catalog is keyed by. Whether iOS then shows the German is a DEVICE
//     PROBE (a German-language device), registered in `docs/dev/FOUNDER_INBOX.md` §2, not proven here.
//   · SOURCE-TEXT for the REACH: a word that an enum returns as a plain `"literal"` is spelled
//     VERBATIM by `Text(candidate.label)` — SwiftUI localises `Text("literal")`, never
//     `Text(someString)`. So the chrome files must return every user-visible literal
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
// and bare `sharp`/`flat` arms, 22 units missing — ONE finding). E4-48 added the part bar's Play/Stop (text, label,
// hint arm), the media browser's Preview/Stop and the FX preset list's two Unstar/Favorite labels (parent: ternaries of
// bare literals, 5 units missing — ONE finding). E4-49 added the Routing surface's Blackout button (text + label), the
// sound-reset „Armed“ value and the Music-colour row (text + spoken label, which interpolated `live`/`idle`) (parent:
// ternaries of bare literals and one interpolated label, 9 units missing — ONE finding). E4-50 added Live Colabo's Go
// Live/Stop label and invite sentence, and the bio strip's „Bio source:“ spoken label (parent: a bare ternary and two
// interpolated labels, 3 units missing — ONE finding). E4-51 added EchoelStudioView's eight interpolated spoken labels
// and the rendered export-failure sentence — Export/Import/Not-opened notes, play-surface sound, visual preset, look,
// Share, New name (parent: interpolated literals, 8 units missing — ONE finding). E4-52 added the visible interpolated
// lines — the two „Undo delete of“ labels, the part-slots-full note, the „by“ credit, the artist-name caption, Live
// Colabo's invite line and „Piece from“ (parent: interpolated literals, 7 units missing — ONE finding). E4-53 added the
// literal keys the catalog still lacked — the Routing card's two captions (their `\u{2014}` escapes spelled as the
// character, so the key can match), Live Colabo's words and the onboarding Start (parent: 13 units missing — ONE
// finding; OK · Studio · WAV FAILED · WAV … stay on `untranslatedPanelWords` on purpose). E4-54 added the three Studio
// captions built as `+` chains or around a derived clause — the Save hint, the buffer hint, the mood caption with
// `romanceSeventhClause` (parent: verbatim Strings, 8 units missing — ONE finding). E4-55 added the exporter's five
// failure reasons, the two concatenated Studio hints (Live Colabo door, click accent), the pad-shape caption's eleven
// segments and the narration-disclosure hint (parent: 23 units missing — ONE finding). E4-56 added the five import
// sentences of the Sequencer helpers (MIDIImport added-track / empty-part / success, MediaPlacement, AudioImport):
// interpolated Strings, now seams around the names and counts (parent: 20 units missing — ONE finding). E4-57 added the
// note-grid VoiceOver label (ClipNoteEdit.gridLabel) and the arrangement row's spoken line (ArrangementStrip.spoken)
// plus the picked-note line and the Notes switch title in the same helper file (parent: 10 units missing — ONE finding). E4-58
// added the EchoelAI narration (BioMusicDirector: three headings, two VoiceOver labels, the paragraph's clauses, prefix and
// engine tail), shown by LiveNarrationDisclosure (parent: 24 units missing — ONE finding). E4-59 added the audio-timing
// row's verdicts (RenderGapDetector screenLine / evidenceSuffix / screenCaption / screenText) and the detected-key
// sentence (AudioKeyAnalysis.summarise with TuningDetector.keyName) (parent: 21 units missing — ONE finding). E4-60 added
// the detected-tempo sentence (AudioTempoAnalysis.summarise) (parent: 4 units missing — ONE finding). E4-61 added the
// Workstation's transport caption, track-removal note and mix-meter spoken text (parent: 14 units missing — ONE finding). E4-62
// added the Record tile's action label, the busy status, the text-size caption, the keep-last copy and the bar-length
// label they all carry (`LoopBarLength.label`) (parent: 15 units missing — ONE finding). E4-63 added the new-MIDI-part
// hint, the Explore board sentence and its density words (parent: 11 units missing — ONE finding). E4-64 added the
// strap status ladder (PolarH10BioPublisher.statusLabel), the part editor's shared-notes hint and the touch surface's
// spoken terrain (parent: 14 units missing — ONE finding). E4-65 added the record-take captions (RecordTakeControls),
// the open refusal (SessionSaveOpen.refusal) and the relink reasons (MediaRelink.userMessage) (parent: 31 units
// missing — ONE finding). E4-66 added the scene-launch hints (SessionLaunchView.sceneBlock), the look-name fallback
// (LookBlendMap.name) and the value field's VoiceOver "Default" action (parent: 5 units missing — ONE finding). E4-67 added
// the media browser's state lines, relink note, preview refusals and the audio-track fallback (parent: 10 units missing —
// ONE finding). E4-68 added the two import doors' failure sentences (AudioImport.Failure / MIDIImport.Failure.userMessage)
// and the note editor's four refusals (ClipNoteEdit) (parent: 19 units missing — ONE finding). E4-69 added the FX
// character names and blurbs (GenreFX), the skill-level names and blurbs (SkillLevel) and the camera recovery words
// (CameraRPPGBioPublisher: `userHint` for the strip, `shortLabel` for the pill) (parent: 34 units missing — ONE finding).
// E4-70 added the Live Colabo status line (MultipeerSession.status), the open-piece refusal and save error (ProjectStore)
// and the two Bluetooth call-mode notes (AudioConfiguration RouteCodec.note) (parent: 16 units missing — ONE finding).
// E4-71 added the loudness-target names (LoudnessTarget.displayName, the Master picker) and the weather mixer's
// explanation lines (WeatherMood.Param.explanation; its `label` stays a bare KEY for `EchoelValueField`, claim 12)
// (parent: 13 units missing — ONE finding). E4-72 added the bio-source chooser labels (BioSourceOption.menuLabel —
// TheBioSourceChooserHasOneDefinitionTests counts each literal ONCE across definition + consumers, and a wrapped literal is
// still one), the track inspector's device names (TrackInspectorView.deviceName, the no-voice pair split around its
// capacity) and the four meter names VoiceOver speaks (VisualAnalysisMeter.spokenName) (parent: 15 units missing — ONE
// finding). E4-73 added the studio chips' VoiceOver full names (StudioMenu.fullName — SaveDoorNamingTests reads the
// `.export` LINE and asks for "save"/"loop", both still on it), the place row's status line, the Field arp rhythm blurbs
// and push notes, and the mood variation caption (its count stays `MoodProfile.variationSpread.count`, projected between
// keys) (parent: 25 units missing — ONE finding). E4-74 added the music-theory primer (MusicTheoryTopic title ·
// summary · detail, reachable through LearnLibrary.musicEntries; the footer stays bare — it has no reader) (parent:
// 27 units missing — ONE finding). E4-75 added the body-science sheet (BioScienceTopic title · summary · detail,
// reachable through LearnLibrary.bodyScienceEntries; the one \u{201C} escape became the literal glyph so the key can be
// a literal — TheScienceCardClaimsNoSweepTests pins sentences INSIDE the literals and survives) (parent: 15 units
// missing — ONE finding). E4-76 added the light-science sheet (LightScienceTopic title · summary · detail, reachable
// through LearnLibrary.lightEntries; the `.scope` paragraph keeps its 39 % as a bare operand between two keys because
// `%` cannot sit in a key — TheColourCopyNamesThePurpleLineTests claim 1 is re-anchored 1:1 on that seam) (parent: 16
// units missing — ONE finding). E4-77 added the automation row's hint (SongAutomationEdit.hint — its runtime guard
// compares under the test locale) and the value field's spoken gesture (EchoelValueField.accessibleHint;
// ADisabledParameterRowLooksDisabledTests counts the sentence once, and a wrapped one is still one) (parent: 5 units
// missing — ONE finding). Camera errors, the Learn announcement line and the theory footer stay bare: no reader, a
// door behind `cloudKitConfigured == false`, no reader. E4-78 added WorkstationSummary's spoken sentences (transport
// and click hints, the row description's fragments, the bar span's two words), TempoFollowLabel's four sentences plus
// the lock button's label, and the Field arp row's two accent notes — every guard on them compares at runtime under
// the test locale (parent: 24 units missing — ONE finding). E4-79 keyed the Routing surface's 28 toggle hints and
// notes (wireless MIDI, MPE layout and per-note expression, the MIDI 2.0 source, OSC control input, clinical HRV
// detail, the two disabled-button labels); the one sentence with a percent sign became a computed property with
// the `%` as a bare operand right after its key — TheRoutingCardDoesNotPromiseGestureTests re-anchored 1:1 on that
// line (parent: 29 units missing — ONE finding). E4-80 keyed EchoelStudioView's remaining ternaries and helper
// Strings: the export hint pair, the variation-board idle line, the weather line (a computed `weatherLine`, key or
// key + reading), the click-accent hint (one key instead of a `+` chain), the Routing door and the text-size buttons
// (both helpers now take `LocalizedStringKey`, zero call-site edits), the touch chip's "Same as music", the
// diagnostics empty line, the share refusal, the keep-last hint pair, the Health status pair and the picture-only
// start's two pairs (parent: 29 units missing — ONE finding). E4-81 keyed the track inspector's mute/solo hints,
// the scene launcher's guide line and part hint pair, the note editor's toggle label pair and grid hint pair, and
// gave four LocalizedStringKey positions their missing units (the two note actions, the Colabo stream hint, the FX
// search prompt) — the runtime guards on mute/solo compare under the test locale (parent: 16 units missing — ONE
// finding). E4-82 keyed the automation editor's toggle label pair and value-field hint, the automation strip's
// status pair and the part bar's start-bar hint; the curve canvas's hint and its two point actions were already
// keys and got their units (parent: 9 units missing — ONE finding). E4-83 keyed the Workstation's track-details
// hint pair and its three import fallbacks for a nameless track (`?? "the MIDI track"` ×2, `?? "the audio track"`),
// the Colabo invite's joining pair and the Studio caption's idle sentence (parent: 6 units missing — ONE finding).
// E4-84 keyed the three Live-heading literals of `LiveModOrigin.heading` (read by the FX sheet and the narration
// leaf), the degraded row's fallback sentence and the four note-name scheme labels of the Picker (parent: 8 units
// missing — ONE finding). E4-85 keyed the fifteen `TuningSystem.library` names the tone-system Picker renders through
// `Text(t.name)` (parent: 15 units missing — ONE finding). E4-86 keyed the five factory visual-preset blurbs and the
// two media-seed presets' names and blurbs — the strip speaks `preset.name + " visual preset — " + preset.blurb`
// (parent: 9 units missing — ONE finding). E4-87 keyed the twelve default `SignalPort` names and the ten
// `ConverterCatalog.default` names the Routing surface renders (parent: 22 units missing — ONE finding). E4-88
// split the tuning banner's headline into two keyed heads plus bare operands (parent: 2 units missing — ONE
// finding). E4-89 gave the three save alerts, the "Open piece" and "Recovery" navigation titles and the
// brand title "EchoelFX" their units and widened claim 10's walk to `.alert` / `.navigationTitle` /
// `.confirmationDialog` (parent: 6 units missing — ONE finding). E4-90 keyed the arrange canvas's spoken
// hearing states and part label and the header's place line (parent: 4 units missing — ONE finding). E4-91 keyed
// the note editor's spoken count and step announcement and the record row's unnamed-track fallback (parent: 3
// units missing — ONE finding). E4-92 keyed the value field's spoken units, the tempo field's spoken following
// value and the touch surface's VoiceOver label and hint (parent: 2 units missing — ONE finding). E4-93 keyed the
// value-field hints that were literal Strings (`EchoelValueField.hint` is a String, so a literal ships verbatim): the
// track inspector's instrument, level and pan hints and the Bar variation hint (parent: 5 units missing — ONE
// finding). E4-94 keyed the Mute/Solo switch names in the Workstation header and on the Perform plate, the
// Workstation row's detail fragments and its state tags (parent: 9 units missing — ONE finding). E4-95 keyed the instrument's piece notes (new piece, refused, library row, rename), the timbre-words
// hint and the spoken ", favorite" of the mood and sound rows (parent: 8 units missing — ONE finding). E4-96 keyed the onboarding consent toggle's VoiceOver hint, the last safety sentence that shipped
// verbatim (parent: 2 units missing — ONE finding). E4-97 keyed the bio-source short names (BioSourceOption.shortName),
// which the pill row renders and speaks beside the E4-72 menu labels (parent: 3 units missing — ONE finding). E4-98 looked the floating window's four corner actions up by their
// rawValue (one definition stays in SnapCorner; the key is the rawValue) (parent: 4 units missing — ONE finding). E4-99 keyed the routing surface's two light output names, which
// `NetworkOutputHeader` renders and speaks as a String (parent: 2 units missing — ONE finding). E4-100 drew the instrument's chip strip as catalog keys — the German
// help sentences named "Klang"/"Stimmung"/"Feld" while the chips still read English (parent: seam absent, 2 units missing —
// ONE finding). E4-101 looked up the field's six self-play motion names, which the Motion picker drew verbatim through
// `Text(String)` (parent: seams absent, 6 units missing — ONE finding). E4-102 looked up the Visual window's four meter names where the
// segmented picker draws them (parent: seam absent, 4 units missing — ONE finding). E4-103 keyed the one exporter reason
// E4-55 missed, the too-long message built in `tooLongMessage` (parent: seams absent, 4 units missing — ONE finding). E4-104 looked up the
// synth parameter names the routing card offers, in `ModDestinationKey.displayName` (parent: seam absent, 8 units
// missing — ONE finding). E4-105 looked up the automation names — the curve editor's title and picker and the
// status strip's rows — where `AutomationScale` and `SongAutomationEdit` build them (parent: seams absent, 6 units
// missing — ONE finding). E4-106 looked up the master panel's buffer-tier segments (parent: seam absent, 3 units
// missing — ONE finding). E4-107 keyed the three engine-failure sentences `AudioDegradedRow` shows (parent: seams
// absent, 4 units missing — ONE finding). E4-108 looked up the one Live Colabo status line `MultipeerSession` still
// built verbatim, the join request (parent: seam absent — ONE finding). E4-109 gave the two VoiceOver labels the
// scanner's own word-boundary bug had hidden their units (parent: 2 units missing — ONE finding). E4-110 keyed the
// visual window's two recording-fault badges and took „Poincaré plot“ and „WAV FAILED“ off `untranslatedPanelWords`,
// where E4-6 had filed them as spelled alike in every language — neither is (parent: seam absent, 2 units missing —
// ONE finding). E4-111 keyed the mood menu's „Custom“ label and looked up the master Tone picker's four names (parent:
// seams absent, 5 units missing — ONE finding). E4-112 looked up the Sound panel's spectral-shape and noise-colour
// names (parent: seams absent, 12 units missing — ONE finding). Claim 12
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

final class TheChromeSpeaksOneLanguageTests: XCTestCase {

    private static let chromeFiles = [
        "Sources/Echoelmusic/Studio/StudioStage.swift",
        "Sources/Echoelmusic/Studio/ProjectTransport.swift",
    ]

    /// The keys SwiftUI localises by content alone — `Text("Pause")`, `.accessibilityLabel("Guide")`.
    /// No code change carries them, so the counterweight is that each still occurs as such a literal.
    private static let literalKeys = ["Pause", "Guide", "Views", "Follows pulse", "Locked", "Demo", "Heart rate"]

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

    /// The ENGLISH unit of `key` — nil when the key is missing, its `en` unit is missing, or the
    /// entry still carries ANY other language. Since 2026-10-02 (founder: "Nur Englisch") the app
    /// speaks exactly one language, so a surviving `de` unit is as much a defect as a missing key:
    /// it would ship a German line to a German phone in an English-only app.
    private func catalogued(_ key: String, in strings: [String: Any]) -> (state: String, value: String)? {
        guard let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              Set(localizations.keys) == ["en"],
              let en = localizations["en"] as? [String: Any],
              let unit = en["stringUnit"] as? [String: Any],
              let state = unit["state"] as? String,
              let value = unit["value"] as? String else { return nil }
        return (state, value)
    }

    private func assertCatalogued(_ words: [String], _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let strings = try catalogStrings()
        XCTAssertFalse(words.isEmpty, "no \(what) to check — the enum lost its cases? (#454)", file: file, line: line)
        for word in words {
            guard let en = catalogued(word, in: strings) else {
                XCTFail("""
                    \(what) "\(word)" is not an English-only key in Localizable.xcstrings — either the key \
                    is missing (the chrome word left the catalog it is looked up in) or the entry still \
                    carries a second language. The app speaks one language since 2026-10-02 \
                    (StringCatalogIsHonestTests holds the set); the catalog, never this file, holds the words (#416).
                    """, file: file, line: line)
                continue
            }
            XCTAssertEqual(en.state, "translated", "\(what) \"\(word)\": a `new` unit ships nothing (xcstringstool skips it)", file: file, line: line)
            XCTAssertEqual(en.value, word, "\(what) \"\(word)\": the English unit is not the key it is looked up by", file: file, line: line)
        }
    }

    private func codeOnly(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("\(relative) is not on disk — re-anchor this guard (#454)")
        }
        return SourceText.codeOnly(text)
    }

    // MARK: - claim 1 — END-TO-END: every stage word is a catalog key with a German unit

    func testEveryStageWordIsCatalogued() throws {
        let stage = StudioStage.allCases.flatMap { [$0.label, $0.spokenHint] }
        XCTAssertEqual(StudioStage.allCases.count, 2, "counterweight: the workspace still has its two stages")
        try assertCatalogued(stage, "stage word")
        // DAW shell S2 (2026-10-02): the bottom switcher's five words and spoken hints — the same file,
        // the same rule. ("Stage", the retired seam's VoiceOver label, left `literalKeys` for "Views".)
        let shell = ShellTab.allCases.flatMap { [$0.label, $0.spokenHint] }
        XCTAssertEqual(ShellTab.allCases.count, 5, "counterweight: the switcher still has its five entries")
        try assertCatalogued(shell, "switcher word")
        XCTAssertNil(try catalogStrings()["Stage"], "the catalog still carries the retired seam's label `Stage` — an orphan")
    }

    // MARK: - claim 2 — END-TO-END: every head-transport word and hint is a catalog key with a German unit

    func testEveryTransportWordIsCatalogued() throws {
        let statuses: [ProjectTransport.Status] = [.stopped, .paused, .playingInstrument, .playingSong, .recording]
        let plays: [ProjectTransport.PlayAction] = [.startSong, .startSongAndInstrument, .resumeInstrument,
                                                   .startInstrument, .unavailable]
        var words = statuses.map(ProjectTransport.statusWord)
        for running in [false, true] {
            words.append(ProjectTransport.buttonWord(running: running))
            for play in plays {
                words.append(ProjectTransport.buttonLabel(running: running, play: play))
                words.append(ProjectTransport.buttonHint(running: running, play: play, fromTick: 0))
            }
        }
        words += [ProjectTransport.stopHint, ProjectTransport.instrumentRunningCaption,
                  ProjectTransport.unsavedName, ProjectTransport.projectName(nil), ProjectTransport.projectName("  ")]
        // GMMW AE-7: past bar 1 the hint is seamed around the bar number — each piece is a key.
        words += ["Plays the piece from bar ", " on the shared transport.",
                  ". The instrument's held music comes back with it."]
        // counterweight — the English words the sibling guard pins are unchanged in the English host
        XCTAssertEqual(ProjectTransport.statusWord(.playingSong), "Playing piece")
        XCTAssertEqual(ProjectTransport.buttonWord(running: true), "Stop")
        try assertCatalogued(Array(Set(words)).sorted(), "transport word")
    }

    // MARK: - claim 3 — SOURCE-TEXT: the chrome files return no plain literal

    func testTheChromeFilesReturnOnlyLocalizedLiterals() throws {
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
                word this enum returns as a plain literal can never be German on the stage seam or \
                the head. Wrap it — and add its `de` unit to Localizable.xcstrings.
                """)
            XCTAssertEqual(bareLet.numberOfMatches(in: code, range: range), 0, "\(relative): a bare `static let … = \"` hint")
            wrapped += code.components(separatedBy: "String(localized:").count - 1
        }
        XCTAssertGreaterThanOrEqual(wrapped, 22, "counterweight: the two files still carry their localised words (measured 25 sites on 2026-10-01: StudioStage 4 + ProjectTransport 21; the area row's 10 left with it)")
    }

    // MARK: - claim 4 — the seven literal keys are translated AND still spelled as literals on screen

    func testTheLiteralChromeKeysAreTranslatedAndStillOnScreen() throws {
        try assertCatalogued(Self.literalKeys, "literal chrome key")
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
        try assertCatalogued(["Undo", "Redo", "Record", "Stop recording", "Arm for recording",
                          "Undo the last change to the piece's parts, notes, automation, mix or a relinked file",
                          "Redo the last undone change to the piece's parts, notes, automation, mix or a relinked file"],
                         "head history / record word")
    }

    // MARK: - claim 7 — the pulse pill's word and the measurement screen's hint speak German (E4-3)

    func testEveryPulseCueWordIsCatalogued() throws {
        let cues: [PulseCue] = [.cameraDenied, .locked, .coverLens, .tooBright, .holdStill, .pressGently,
                                .finding, .noLight, .stalled(hasRhythmlessSignal: true), .stalled(hasRhythmlessSignal: false)]
        // counterweight — the English words the pill guards pin are unchanged in the English host
        XCTAssertEqual(PulseCue.noLight.shortLabel, "No light")
        XCTAssertEqual(PulseCue.stalled(hasRhythmlessSignal: true).shortLabel, "Unsteady")
        try assertCatalogued(Array(Set(cues.flatMap { [$0.shortLabel, $0.fullHint] })).sorted(), "pulse cue word")
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

    func testEveryLadderWordCaptionAndSpokenSentenceIsCatalogued() throws {
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
        try assertCatalogued(pieces.filter { $0.rangeOfCharacter(from: .letters) != nil }.sorted(), "ladder text")
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

    func testThePowerRowOutputTilesAndNetworkWordAreCatalogued() throws {
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
        try assertCatalogued(pieces.sorted(), "power / output / network text")
        // the tile words fit the tile (`OutputStatusWord.maxLength`)
        let strings = try catalogStrings()
        for word in ["Screen", "Idle", "Off"] {
            let de = try XCTUnwrap(catalogued(word, in: strings)).value
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
            "Sources/Echoelmusic/Studio/ArrangeTimeZoom.swift",
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
            "Sources/Echoelmusic/Studio/MasterStripView.swift",
            "Sources/Echoelmusic/Studio/SoundBrowserView.swift",
            "Sources/Echoelmusic/Studio/TrackSpaceRows.swift",
            "Sources/Echoelmusic/Studio/WorkingCopyStatusView.swift",
            "Sources/Echoelmusic/Studio/TrackSampleRow.swift",
    ]
    static let untranslatedPanelWords: Set<String> = ["BPM", "Create from Within", "Demo", "E", "ECHOEL", "Echoelmusic", "OK", "Studio", "Tempo", "WAV …"]

    func testEveryPanelTextOfTheReachableChromeFilesIsCatalogued() throws {
        let strings = try catalogStrings()
        // E4-89: `.alert("…")`, `.navigationTitle("…")` and `.confirmationDialog("…")` titles are key sites too. The
        // walk did not list them, so five titles (three save alerts, "Open piece", "Recovery") shipped English while
        // every `Text` beside them was German — a blind spot of this regex, not of the catalog.
        let literal = try NSRegularExpression(
            pattern: #"\b(?:Text|Button|Toggle|Label|Picker|Section|TextField|Menu|NavigationLink|Link|labeledRow|groupHeader|collapsibleGroupHeader|mixStripCard|weatherMixGroup|effectSection|panel|readout|alert|navigationTitle|confirmationDialog)\(\s*"((?:[^"\\]|\\.)*)"|\.accessibility(?:Label|Hint|Value)\(\s*"((?:[^"\\]|\\.)*)""#)
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
                if seen.insert(key).inserted, catalogued(key, in: strings) == nil { missing.append(key) }
            }
        }
        XCTAssertGreaterThan(sites, 400, "the walk found \(sites) literal-key sites — it did not read the family")
        XCTAssertEqual(missing, [], """
            \(missing.count) panel text(s) not English-only in the catalog — add the key (en unit only) for each:
            \(missing.joined(separator: "\n"))
            """)
        // counterweight — a key with an interpolation is not a catalog key and is not demanded
        XCTAssertNil(catalogued("Playing over \\(outputs)", in: strings))
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
        try assertCatalogued(["Shows or hides the ", " controls", "Shown", "Hidden",
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
        try assertCatalogued(["Filter", "Saturation", "Tape / VHS", "Bitcrush", "Reverb", "Stereo Width", "Delay",
                          "Chorus", "Flanger", "Phaser", "Tremolo", "Compressor", "Limiter"], "FX stage titles")
        // E4-13 — the shared card draws title AND subtitle as keys; the panels' words (eight since slice F) reach the catalog
        let card = try codeOnly("Sources/Echoelmusic/Studio/EchoelPanel.swift")
        for needle in ["Text(LocalizedStringKey(title))", "Text(LocalizedStringKey(subtitle))",
                       ".accessibilityLabel(LocalizedStringKey(title))"] {
            XCTAssertTrue(card.contains(needle), "EchoelPanel draws `\(needle)` verbatim again — the panel words below would then prove nothing")
        }
        XCTAssertFalse(card.contains("Text(title)") || card.contains("Text(subtitle)"),
                       "a verbatim `Text(String)` is back in EchoelPanel")
        // Slice F (2026-10-02) retired the Workstation plate: its title "Workstation" and subtitle "The arrangement is
        // the Piece stage" left this list together with their catalog keys (StringCatalogIsHonestTests' orphan rule).
        try assertCatalogued(["Mix", "Tempo & variations", "Master", "Field", "Mood", "Sound & texture",
                          "Effects", "Save & Export",
                          "Level per part", "Tap · metronome · haptic beat · ideas",
                          "Loudness target · tone · audio output", "Character of the composition",
                          "Shape the timbre — exact to 0.0001", "Production character",
                          "Set the loop length the Record tile uses · choose how much of the strip you see · see what can be kept · put your city in the name · the default sound"],
                         "panel titles and subtitles")
        // E4-14 — the loudness grid's readout label is a key; its four names reach the catalog (units stay EBU tokens)
        let grid = try codeOnly("Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift")
        XCTAssertTrue(grid.contains("private func readout(_ label: LocalizedStringKey, _ value: String, _ unit: String, _ color: Color)"),
                      "readout takes a String label again — Short-term / Integrated / True peak / Range would spell verbatim")
        try assertCatalogued(["Short-term", "Integrated", "True peak", "Range"], "loudness readout names")
        // E4-15 — the media cards' action label draws its title as a key; the three actions (+ Undo) reach the catalog
        // `mediaLabel`, not `media` — that name is already bound to the media library eleven lines up, and the
        // redeclaration did not compile (BfT 6561 red on 4d53fd149)
        let mediaLabel = try codeOnly("Sources/Echoelmusic/Studio/MediaActionLabel.swift")
        XCTAssertTrue(mediaLabel.contains("Text(LocalizedStringKey(title))") && !mediaLabel.contains("Text(title)"),
                      "MediaActionLabel draws its title verbatim again — Choose Photo / Apply to Visuals / Choose Video would not translate")
        try assertCatalogued(["Choose Photo", "Apply to Visuals", "Choose Video", "Undo"], "media action titles")
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
        try assertCatalogued(["Earlier", "Later", "Trim start", "Trim end", "Split", "Copy", "Remove",
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
        try assertCatalogued(["Fit", "−1 step", "+1 step", "Quantize",
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
        // ⛔ DAW shell S3 (2026-10-02): the Workstation's Save/Open row and its `door(` helper are deleted — Save
        // and Open are entries of the ≡ menu. The law moves with them: each entry is a `Label` whose title is a
        // LITERAL (a catalogue key), never a `String` variable or `Label(verbatim:)`.
        let doors = try codeOnly("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        for entry in ["Label(\"Open\", systemImage:", "Label(\"Save\", systemImage:", "Label(\"Live Colabo\", systemImage:",
                      "Label(\"Learn\", systemImage:", "Label(\"Guide\", systemImage:"] {
            XCTAssertTrue(doors.contains(entry), "the ≡ menu lost the keyed entry `\(entry)` — its word would no longer come from the catalogue")
        }
        XCTAssertFalse(doors.contains("Label(verbatim:"), "a ≡ menu entry spells its word verbatim")
        try assertCatalogued(["Previous guide card", "Next guide card", "Genre", "FX",
                          "Echoel plays ", ", FX character ",
                          "Hide guide", "Guide, in the logo menu at the top left, brings it back", "Guide", "Save",
                          "Open", "Live Colabo", "Learn"],
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
        try assertCatalogued(["MIDI in", ", card ", " of ", "Modes",
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
        try assertCatalogued(shelfTitles, "genre shelf headers")
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
        try assertCatalogued(scaleNames, "scale display names")
        // E4-22 — the icon tile draws its word as a key; the Record tile's state title and the spoken accidentals are keys
        let tile = try codeOnly("Sources/Echoelmusic/Studio/EchoelIconTile.swift")
        XCTAssertTrue(tile.contains("Text(LocalizedStringKey(title))") && !tile.contains("Text(title)"),
                      "EchoelIconTile draws its word verbatim again — Save / Open / Learn would not translate")
        XCTAssertTrue(code.contains("String(localized: \"Writing\")") && !code.contains("? \"Stop\" : \"Recording\""),
                      "the Record tile's state title spells Stop / Recording / Writing verbatim again")
        let notes = try codeOnly("Sources/Echoelmusic/Sequencer/NoteNaming.swift")
        XCTAssertTrue(notes.contains("with: String(localized: \" sharp\")") && notes.contains("with: String(localized: \" flat\")"),
                      "`spokenName` expands ♯/♭ to a verbatim English word again")
        try assertCatalogued(["MIDI", "Open", "Live Colabo", "Learn", "Save", "Keep last", "Stop", "Recording", "Writing", "Record", " sharp", " flat"], "icon tile, record tile and accidental words")
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
            XCTAssertNotNil(catalogued(card.title, in: strings), "no English-only catalog unit for the Learn card title `\(card.title)`")
            XCTAssertNotNil(catalogued(card.summary, in: strings), "no English-only catalog unit for the Learn card summary of `\(card.id)`")
            if card.id != "safety.scope" {   // its detail is the disclaimer + a tail seam, pinned separately below
                XCTAssertNotNil(catalogued(card.detail, in: strings), "no English-only catalog unit for the Learn card detail of `\(card.id)`")
            }
        }
        try assertCatalogued(["Start Here", "Your Body", "Body Science", "Music Theory", "Light & Colour", "Safety & Scope", "For music and self-observation only — not a medical device and not for diagnosis. Readings are approximate; don’t use them for health decisions.", " Bio readings are most accurate from a chest strap; wrist and camera are estimates. Breathing guides are optional and never forced."], "Learn headings, disclaimer and scope tail")

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
        try assertCatalogued(["track", "tracks", "part", "parts", "bar", "bars", "Arrangement: ", "bars long",
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
        try assertCatalogued(["Bar ", " beat ", " · to bar ", "1 bar", "bars", "1 beat", "beats", "1 point", "points",
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
        try assertCatalogued(["Selected part · ", "Part at ", "Point at ", "Remove the point at ", " automation: "], "part bar, parts row and curve editor frames")

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
        try assertCatalogued(["Bar ", " · Beat ", "Part at ", "Queued", "Playing", "Stopping", " later scenes are not shown.",
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
        try assertCatalogued(["no effect", "overridden", "off", "1 point", "points", " automation, ",
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
        try assertCatalogued(["Relinked ", " to ", " files", "Relink ", " — expects ", "no part", "1 part", "No file name contains ",
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
                     "String(localized: \"Opens the part's notes on its track's Notes page.\")",
                     "String(localized: \"Stops the piece, the instrument and the pulse reading.\")",
                     "String(localized: \"Plays the piece from the top.\")",
                     "String(localized: \"Names the piece and saves it. Open brings it back.\")",
                     "String(localized: \"The part's notes are open on the track's Notes page. Tap a cell to write a note.\")",
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
        XCTAssertTrue(ComposeGuide.notesOpenedNote.hasPrefix("The part's notes are open on the track's Notes page."))
        try assertCatalogued(["Add a MIDI track", "Add a part", "Write notes", "Stop all playback", "Play the piece", "Save the piece",
                          "Your piece has its MIDI track.", "An instrument track for the notes of your piece.",
                          "Adds another empty four-bar part after the last one.", "An empty four-bar part on that track.",
                          "Opens the part's notes on its track's Notes page.", "Stops the piece, the instrument and the pulse reading.",
                          "Plays the piece from the top.", "Names the piece and saves it. Open brings it back.",
                          "The part's notes are open on the track's Notes page. Tap a cell to write a note.",
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
        try assertCatalogued(["Heart Rate", "Heart-Rate Variability", "Coherence", "Breathing Rate", "breaths/min",
                          "How fast your heart is beating right now.", "Breaths per minute.", "read your pulse to see it move",
                          "demo values, not your body", "Simulated demo, ", " Currently ", " percent.", " shapes ",
                          "Heart rate", "Vibrato & tone brightness", "Heart-rate variability", "Overtone brightness",
                          "Filter brightness & harmonics", "Breath", "Swell",
                          "the sound swells and settles once with each breath"], "bio info sheet and sound map")
        for (metric, prefix) in [(BioMetric.heartRate, "Beats per minute."), (.hrv, "The tiny differences"), (.rmssd, "Root mean square"),
                                 (.sdnn, "Standard deviation"), (.pnn50, "The percentage of consecutive"), (.coherence, "How much of your heart-rate"),
                                 (.breath, "Your breathing rate.")] {
            XCTAssertTrue(metric.detail.hasPrefix(prefix), "`BioMetric.\(metric.rawValue).detail` no longer begins as the catalog key does")
            XCTAssertNotNil(catalogued(metric.detail, in: strings), "no English-only catalog unit for the detail of `\(metric.rawValue)`")
            XCTAssertNotNil(catalogued(metric.summary, in: strings), "no English-only catalog unit for the summary of `\(metric.rawValue)`")
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
        try assertCatalogued(["No pulse lock", "Simulated demo, ", " beats per minute, coherence ", " beats per minute",
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
        try assertCatalogued(["Simulated demo, ", ", not measured, shaping ", " at the neutral value", " at ", " percent, shaping ",
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
        try assertCatalogued(["Coherence", "HRV", "Heart rate", "Breath phase", "brightness", "harmonicity", "noise", "filter", "vibrato", "level",
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
        XCTAssertEqual(fxMod.components(separatedBy: "return String(localized: \"").count - 1, 23,
                       "FXModTarget (13) + FXModCarrier (7) display names + LiveModOrigin.heading (3, E4-84) — 23 `return String(localized:` sites; re-derive if a target, carrier or origin was added")
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
        try assertCatalogued(["Filter Cutoff", "Filter Resonance", "Saturation Drive", "Chorus Mix", "Flanger Mix", "Phaser Mix", "Tremolo Depth",
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
            XCTAssertLessThanOrEqual(catalogued(step.word, in: strings)?.value.count ?? 99, 12, "the rung word for `\(step)` overflows the pill's value slot")
        }
        try assertCatalogued(["Searching", "Almost", "Found", "Lost", "Searching for your pulse", "Almost there — keep your finger still",
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
        try assertCatalogued(Array(Set(["the simulated demo source, not your body", "four channels from ", ", shape ", "four body channels shape ",
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
        // the actions split the caption on " · " — every caption must keep exactly one
        for caption in ["dark · bright", "still · moving", "natural · spectrum", "calm · energy"] {
            XCTAssertEqual(catalogued(caption, in: strings)?.value.components(separatedBy: " · ").count, 2, "`\(caption)` must split into two words on ` · `")
        }
        try assertCatalogued(["Pulse detected — you can let go & play", "Your body is driving the sound", "Body signal live, not driving yet", "No live body signal",
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
        try assertCatalogued(["Small", "Medium", "Large", "Fullscreen", "Stop WAV audio recording", "Record lossless WAV audio", "Writing to disk failed",
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
        XCTAssertTrue(PerformSessionView.emptyNote.hasPrefix("Nothing to launch yet. Parts you write in Arrange,"))
        try assertCatalogued(["Scenes and tracks", "Expanded", "Collapsed", "Save preset", "Rename preset", "Morph → ", "Morph toward a preset…",
                          "Always on — simulated demo → timbre", "Always on — body → timbre",
                          "Shows the piece's scenes to launch on the bar, and Mute and Solo for its tracks. While the Echoel plays on its own, stop it in the header to launch a scene.",
                          "Nothing to launch yet. Parts you write in Arrange, and the Echoel's generated music, appear here as scenes to launch on the bar.",
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
        try assertCatalogued(["This photo could not be read. Try another photo.", "Reading the photo…", "No main colour", "Main colour: hue ", ", unchanged",
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
                     // E12-1 (founder 2026-10-04): the two-key ternary became four states — the sound is used now.
                     "case .none:     return String(localized: \"No sound.\")",
                     "case .usable:   return String(localized: \"It has sound. Use Its Sound places it as a part on the first audio track.\")",
                     "case .placed:   return String(localized: \"Its sound is in the piece and in your library.\")",
                     "case .released: return String(localized: \"It has sound. Choose the video again to use it.\")",
                     "static var extractingSound: String { String(localized: \"Reading the sound…\") }",
                     "static var soundUnreadable: String { String(localized: \"This video's sound could not be read.\") }",
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
        try assertCatalogued(["This video could not be read. Videos up to ", " minutes can be used; try another one.", "Reading the video…", "Length ", " fps",
                          "No cuts or flashes", " more", "cut or flash", "cuts or flashes", "Length in bars: unknown", "About ", " of 4/4 at ",
                          "No sound.", "It has sound. Use Its Sound places it as a part on the first audio track.",
                          "Its sound is in the piece and in your library.", "It has sound. Choose the video again to use it.",
                          "Reading the sound…", "This video's sound could not be read.", "Use Its Sound", "Use its sound",
                          "Places the video's sound as a part on the first audio track and adds it to your library", "Motion", "Movement", "Video to Visuals",
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
        try assertCatalogued(["On", "Off", "Warp", "Warp · some", "On for some parts", "Stop the piece to change warp",
                          "Plays this track's parts at the piece's tempo instead of their recorded speed", "Stop the piece to change pitch",
                          "Moves every part on this track up or down without changing its tempo", "Stop", "Play", "Stop all playback",
                          "Tempo", "Set tempo", "Expanded", "Collapsed", "Hides the steps", "Shows the steps"],
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
        // DAW shell S1b-1 (2026-10-02): the head's Guide BUTTON is gone — the switch is a `Toggle` in the logo's
        // ≡ menu, and a Toggle speaks its own state, so no On/Off seam exists to keep. What survives is the law
        // this block was for: no verbatim On/Off for the guide, anywhere it now lives, and no stray head copy.
        let headerGuide = try codeOnly("Sources/Echoelmusic/Studio/ProjectHeader.swift")
        XCTAssertFalse(headerGuide.contains("guideVisible"), "ProjectHeader carries a guide switch again — S1b-1 moved it to the ≡ menu")
        let menuGuide = try codeOnly("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(menuGuide.contains("Toggle(isOn: $guideVisible)"), "the logo's ≡ menu lost its Guide Toggle")
        for verbatim in [".accessibilityValue(guideVisible ? \"On\" : \"Off\")", "guideVisible ? \"On\""] {
            XCTAssertFalse(menuGuide.contains(verbatim), "WorkspaceView speaks a bare On/Off for the guide: `\(verbatim)`")
        }
        try assertCatalogued(["Menu", "Open, save, Live Colabo, Learn and the guide"], "the logo menu's VoiceOver name and hint")
        let clickLeaf = try codeOnly("Sources/Echoelmusic/Studio/WorkstationClickToggle.swift")
        for seam in [".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))"] {
            XCTAssertTrue(clickLeaf.contains(seam), "WorkstationClickToggle lost the E4-44 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(on ? \"On\" : \"Off\")"] {
            XCTAssertFalse(clickLeaf.contains(verbatim), "WorkstationClickToggle speaks a bare On/Off again: `\(verbatim)`")
        }
        try assertCatalogued(["On", "Off"], "On/Off siblings")

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
        try assertCatalogued(["A ", " look is applied. Undo it first to apply this one.", "photo", "video"], "blocked-Apply sentence")

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
        try assertCatalogued(["Explore", "New", "Explore variations", "Explore new variations", "Variation ", ", playing", " percent match",
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
        try assertCatalogued(["No dominant tone", "Loudest tone ", " hertz", " hertz, ", ", in tune", " cents sharp", " cents flat",
                          "Silent", "Peak ", " decibels true peak",
                          "Wavefront field. Silent. Nothing is sounding, so no wave is leaving the centre.", " wavefronts are",
                          "One wavefront is", "Wavefront field. ", " spreading outward.", " spreading outward, the newest centred near ", " hertz.",
                          "Camera pulse is off. This plot reads the camera pulse only.", "Waiting for beats", "only ", " of beats usable", " beat pairs"],
                         "Analysis readouts")

        // E4-48 — three more ternaries of bare literals, each arm now a catalog key: the selected part's Play/Stop
        // button (text + spoken label, and the literal hint arm beside `WorkstationSummary.transportHint`), the media
        // browser's Preview/Stop button, and the FX preset list's two Unstar/Favorite labels (context menu + swipe).
        let partPlay = try codeOnly("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        for seam in ["Text(playing ? String(localized: \"Stop\") : String(localized: \"Play from here\"))",
                     ".accessibilityLabel(playing ? String(localized: \"Stop all playback\") : String(localized: \"Play the piece from the selected part\"))",
                     "? String(localized: \"Plays the arrangement from this part's bar on the shared transport.\")"] {
            XCTAssertTrue(partPlay.contains(seam), "SelectedPartBar lost the E4-48 seam `\(seam)`")
        }
        for verbatim in ["Text(playing ? \"Stop\" : \"Play from here\")", "? \"Stop all playback\" :", "? \"Plays the arrangement from this part's bar"] {
            XCTAssertFalse(partPlay.contains(verbatim), "SelectedPartBar spells a ternary of bare literals again: `\(verbatim)`")
        }
        let previewButton = try codeOnly("Sources/Echoelmusic/Studio/MediaBrowserView.swift")
        for seam in ["Text(playing ? String(localized: \"Stop\") : String(localized: \"Preview\"))"] {
            XCTAssertTrue(previewButton.contains(seam), "MediaBrowserView lost the E4-48 seam `\(seam)`")
        }
        for verbatim in ["Text(playing ? \"Stop\" : \"Preview\")"] {
            XCTAssertFalse(previewButton.contains(verbatim), "MediaBrowserView spells a ternary of bare literals again: `\(verbatim)`")
        }
        let fxFavourite = try codeOnly("Sources/Echoelmusic/Studio/EchoelFXView.swift")
        for seam in ["Label(presetStore.isFavorite(id: preset.id) ? String(localized: \"Unstar\") : String(localized: \"Favorite\"),"] {
            XCTAssertTrue(fxFavourite.contains(seam), "EchoelFXView lost the E4-48 seam `\(seam)`")
        }
        for verbatim in ["? \"Unstar\" : \"Favorite\""] {
            XCTAssertFalse(fxFavourite.contains(verbatim), "EchoelFXView spells the favourite ternary with bare literals again: `\(verbatim)`")
        }
        try assertCatalogued(["Stop", "Play from here", "Stop all playback", "Play the piece from the selected part",
                          "Plays the arrangement from this part's bar on the shared transport.", "Preview", "Unstar", "Favorite"],
                         "Part bar, preview and favourite sites")

        // E4-49 — the Routing surface's Blackout button (text + spoken label), the sound-reset „Armed“ value (a VALUE
        // change is what VoiceOver re-announces on a focused control), and the Music-colour row: its text ternary and
        // its spoken label, which interpolated `live`/`idle` into a literal — now two whole-sentence arms.
        let lightBlackout = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        for seam in ["Text(artNet.blackout ? String(localized: \"Blackout ON\") : String(localized: \"Blackout\"))",
                     ".accessibilityLabel(artNet.blackout ? String(localized: \"Blackout active — turn the light back on\") : String(localized: \"Blackout — black out the light immediately\"))"] {
            XCTAssertTrue(lightBlackout.contains(seam), "PatchbayView lost the E4-49 seam `\(seam)`")
        }
        for verbatim in ["Text(artNet.blackout ? \"Blackout ON\" : \"Blackout\")", "? \"Blackout active — turn the light back on\" :"] {
            XCTAssertFalse(lightBlackout.contains(verbatim), "PatchbayView spells the Blackout ternary with bare literals again: `\(verbatim)`")
        }
        let studioArmed = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in [".accessibilityValue(soundResetArmed ? String(localized: \"Armed\") : \"\")",
                     "Text(sounding ? String(localized: \"Live chord, mapped by pitch\") : String(localized: \"Plays when the music is sounding\"))",
                     ".accessibilityLabel(sounding ? String(localized: \"Music colour, live\") : String(localized: \"Music colour, idle\"))"] {
            XCTAssertTrue(studioArmed.contains(seam), "EchoelStudioView lost the E4-49 seam `\(seam)`")
        }
        for verbatim in [".accessibilityValue(soundResetArmed ? \"Armed\" : \"\")", "? \"Live chord, mapped by pitch\" :", "Music colour, \\(sounding ?"] {
            XCTAssertFalse(studioArmed.contains(verbatim), "EchoelStudioView spells a bare arm or an interpolated label again: `\(verbatim)`")
        }
        try assertCatalogued(["Blackout ON", "Blackout", "Blackout active — turn the light back on", "Blackout — black out the light immediately",
                          "Armed", "Live chord, mapped by pitch", "Plays when the music is sounding", "Music colour, live", "Music colour, idle"],
                         "Blackout, Armed and Music-colour sites")

        // E4-50 — Live Colabo's Go Live/Stop label (a bare ternary) and its invite sentence, and the bio strip's live
        // tag spoken label — both interpolated a name or a value into one literal; now a seam of a catalog key beside
        // the value. PartNoteEditor's `mixed ? "Velocity (avg)" : "Velocity"` is NOT here on purpose: `EchoelValueField`
        // reads its `label` as a key (`Text(LocalizedStringKey(label))`, E4-10), and both arms are catalog keys already.
        let colabLive = try codeOnly("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        for seam in ["Label(colab.isLive ? String(localized: \"Stop\") : String(localized: \"Go Live (nearby)\"),",
                     ".accessibilityLabel(invite.peerName + String(localized: \" wants to join you\"))"] {
            XCTAssertTrue(colabLive.contains(seam), "LiveColaboView lost the E4-50 seam `\(seam)`")
        }
        for verbatim in ["Label(colab.isLive ? \"Stop\" : \"Go Live (nearby)\",", "peerName) wants to join you"] {
            XCTAssertFalse(colabLive.contains(verbatim), "LiveColaboView speaks a bare arm or an interpolated label again: `\(verbatim)`")
        }
        let bioTag = try codeOnly("Sources/Echoelmusic/Studio/BioStripView.swift")
        for seam in [".accessibilityLabel(String(localized: \"Bio source: \") + sourceText)"] {
            XCTAssertTrue(bioTag.contains(seam), "BioStripView lost the E4-50 seam `\(seam)`")
        }
        for verbatim in [".accessibilityLabel(\"Bio source: \\(sourceText)\")"] {
            XCTAssertFalse(bioTag.contains(verbatim), "BioStripView interpolates the source into a literal again: `\(verbatim)`")
        }
        try assertCatalogued(["Stop", "Go Live (nearby)", " wants to join you", "Bio source: "], "Live Colabo and bio-tag sites")

        // E4-51 — EchoelStudioView's eight interpolated spoken labels and the rendered export-failure sentence: each was
        // one literal with a name or a note inside; now a catalog key seamed beside the value, the value verbatim.
        // TheExportFailureSpeaksAtTheButtonTests pins the export block and was re-anchored 1:1 in the same commit.
        let studioSpoken = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["Text(reason + String(localized: \". Nothing was saved.\"))",
                     ".accessibilityLabel(String(localized: \"Export failed. \") + reason + String(localized: \". Nothing was saved.\"))",
                     ".accessibilityLabel(name + String(localized: \" play-surface sound\"))",
                     ".accessibilityLabel(preset.name + String(localized: \" visual preset — \") + preset.blurb)",
                     ".accessibilityLabel(look.name + String(localized: \" look\"))",
                     ".accessibilityLabel(String(localized: \"Import failed. \") + importNote)",
                     ".accessibilityLabel(String(localized: \"Not opened. \") + openNote)",
                     ".accessibilityLabel(String(localized: \"Share \") + p.name)",
                     ".accessibilityLabel(String(localized: \"New name for \") + currentName)"] {
            XCTAssertTrue(studioSpoken.contains(seam), "EchoelStudioView lost the E4-51 seam `\(seam)`")
        }
        for verbatim in ["Text(\"\\(reason). Nothing was saved.\")", ".accessibilityLabel(\"Export failed. \\(reason)", "\\(name) play-surface sound\"",
                         "\\(preset.name) visual preset — ", "\\(look.name) look\"", ".accessibilityLabel(\"Import failed. \\(importNote)\")",
                         ".accessibilityLabel(\"Not opened. \\(openNote)\")", ".accessibilityLabel(\"Share \\(p.name)\")", ".accessibilityLabel(\"New name for \\(currentName)\")"] {
            XCTAssertFalse(studioSpoken.contains(verbatim), "EchoelStudioView interpolates a value into a spoken literal again: `\(verbatim)`")
        }
        try assertCatalogued(["Export failed. ", ". Nothing was saved.", " play-surface sound", " visual preset — ", " look",
                          "Import failed. ", "Not opened. ", "Share ", "New name for "], "Studio spoken labels")

        // E4-52 — the VISIBLE interpolated lines (`Text("… \\(value) …")`, read as a format key the catalog cannot carry
        // under the honesty rule): the two „Undo delete of“ labels, the part-slots-full note, the „by“ credit, the
        // artist-name caption, Live Colabo's invite line and „Piece from“ — each a catalog key seamed beside the value.
        let studioLines = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["Label(String(localized: \"Undo delete of \") + d.mood.name, systemImage: \"arrow.uturn.backward\")",
                     "Label(String(localized: \"Undo delete of \") + d.patch.name, systemImage: \"arrow.uturn.backward\")",
                     "Text(String(localized: \"Internal part slots are full (\") + \"\\(ClipStore.slotCount)\" + String(localized: \") — the instrument's music still plays and still exports.\"))",
                     "Text(String(localized: \"by \") + credit)",
                     "Without a name they are stamped \") + SessionContext.unnamedArtist + \".\")"] {
            XCTAssertTrue(studioLines.contains(seam), "EchoelStudioView lost the E4-52 seam `\(seam)`")
        }
        for verbatim in ["Label(\"Undo delete of \\(", "Text(\"Internal part slots are full (\\(", "Text(\"by \\(credit)\")", "stamped \\(SessionContext.unnamedArtist).\")"] {
            XCTAssertFalse(studioLines.contains(verbatim), "EchoelStudioView interpolates a value into a visible literal again: `\(verbatim)`")
        }
        let colabLines = try codeOnly("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        for seam in ["Text(invite.peerName + String(localized: \" wants to join\"))", "Text(String(localized: \"Piece from \") + from)"] {
            XCTAssertTrue(colabLines.contains(seam), "LiveColaboView lost the E4-52 seam `\(seam)`")
        }
        for verbatim in ["Text(\"\\(invite.peerName) wants to join\")", "Text(\"Piece from \\(from)\")"] {
            XCTAssertFalse(colabLines.contains(verbatim), "LiveColaboView interpolates a value into a visible literal again: `\(verbatim)`")
        }
        try assertCatalogued(["Undo delete of ", "Internal part slots are full (", ") — the instrument's music still plays and still exports.", "by ",
                          "Stamped on pieces you save, and used in piece and export file names. Shown to nearby devices while Live Colabo is on. Without a name they are stamped ",
                          " wants to join", "Piece from "], "visible interpolated lines")

        // E4-53 — the literal keys the catalog still lacked, measured by a scan of every LocalizedStringKey-taking
        // call under reachable Sources: these looked up a key that had no `de` unit, so they fell back to English
        // one line at a time. No code changed except the Routing card's two captions, whose `\\u{2014}` escapes are now
        // the character itself — a catalog key is the RESOLVED text, and the honesty rule matches the raw literal.
        let routingCaptions = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        for seam in ["of the instrument — the tempo, or any sound parameter automation can reach.",
                     "while it is enabled — the body sets the value"] {
            XCTAssertTrue(routingCaptions.contains(seam), "PatchbayView lost the E4-53 caption text `\(seam)`")
        }
        for verbatim in ["instrument \\u{2014} the tempo", "enabled \\u{2014} the body"] {
            XCTAssertFalse(routingCaptions.contains(verbatim), "PatchbayView spells the caption's dash as an escape again, so its key cannot match: `\(verbatim)`")
        }
        try assertCatalogued(["No routes yet. A route lets one measured channel of your body move one parameter of the instrument — the tempo, or any sound parameter automation can reach.",
                          "Start",
                          "Two Echoelmusic devices on the same Wi-Fi find each other here. Go live, connect, and share your piece both ways — a starting point to jam from together.",
                          "Share this piece", "Nearby", "Searching…", "Invite", "Share my pulse (live)",
                          "Each person's own numbers, side by side — nothing is combined into a shared score.", "Accept", "Decline", "Load"],
                         "literal keys the catalog lacked")

        // E4-54 — three Studio captions that were verbatim Strings: the Save hint and the buffer hint were `Text("a" + "b")`
        // chains (a String, never a key), the mood caption interpolated the derived `romanceSeventhClause`. Each literal is
        // now its own key; the clause seams keys around its two counts and never writes a digit (MoodKnobsSayWhatTheyDoTests,
        // re-anchored 1:1 in the same commit, still forbids a literal roster size).
        let studioCaptions = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["does not already have one \") + Self.romanceSeventhClause + \".\")",
                     "let head: String = \"(\" + \"\\(plain)\" + String(localized: \" of the \")",
                     "return head + \"\\(offered.count)\" + String(localized: \" offered)\")",
                     "Text(String(localized: \"Saves the composed loop, if there is one, with its genre, key, tuning, tempo, tempo mode (following or locked), mood, \")",
                     "+ String(localized: \"sound and FX character, and the piece — its tracks and parts. \")",
                     "+ String(localized: \"Your mixer levels and hand-dialled FX stay with the instrument.\"))",
                     "Text(String(localized: \"Smaller buffers respond sooner and cost more CPU. iOS may refuse a tier — \")",
                     "+ String(localized: \"hardest on Bluetooth — so the row shows what iOS granted.\"))"] {
            XCTAssertTrue(studioCaptions.contains(seam), "EchoelStudioView lost the E4-54 seam `\(seam)`")
        }
        for verbatim in ["does not already have one \\(Self.romanceSeventhClause).\")", "return \"(\\(plain) of the \\(offered.count) offered)\"",
                         "Text(\"Saves the composed loop", "+ \"sound and FX character", "Text(\"Smaller buffers respond sooner and cost more CPU. iOS may refuse", "+ \"hardest on Bluetooth"] {
            XCTAssertFalse(studioCaptions.contains(verbatim), "EchoelStudioView builds a caption as a verbatim String again: `\(verbatim)`")
        }
        try assertCatalogued(["Friendly ↔ scary (tension) · sparse ↔ busy (liveliness) · odd leaps (weird). Blends with your live signal. Darkness and Romance switch rather than fade: above 0.60 Darkness drops the voicing an octave, and above 0.50 Romance adds the 7th to genres whose chord does not already have one ",
                          " of the ", " offered)",
                          "Saves the composed loop, if there is one, with its genre, key, tuning, tempo, tempo mode (following or locked), mood, ",
                          "sound and FX character, and the piece — its tracks and parts. ", "Your mixer levels and hand-dialled FX stay with the instrument.",
                          "Smaller buffers respond sooner and cost more CPU. iOS may refuse a tier — ", "hardest on Bluetooth — so the row shows what iOS granted."],
                         "Studio captions")

        // E4-55 — the exporter's failure reasons were verbatim Strings handed to `.failed(_:)`; the Studio seamed its
        // suffix around them (E4-51) but the reason itself stayed English. The two Studio hints and the narration hint
        // were `+` chains of literals, and `padShapeCaption` built a `[String]` of them — none is a key. Every segment
        // is a key now, joined by `+` (≤ 4 operands per step). ⛔ The Live Colabo tile's three-segment hint stood in
        // this list until DAW shell S3 deleted the tile; Live Colabo is a ≡ menu entry now, spoken by its `Label`
        // title (pinned in the E4-18 block) — the verbatim ban below still names its old opening.
        let exporterReasons = try codeOnly("Sources/Echoelmusic/Audio/LoopExporter.swift")
        for seam in [".failed(String(localized: \"Recording could not be written to disk\"))",
                     ".failed(String(localized: \"Invalid loop length\"))",
                     ".failed(String(localized: \"Capture failed\"))",
                     ".failed(String(localized: \"The capture buffer is empty\"))",
                     ".failed(String(localized: \"Export failed\"))"] {
            XCTAssertTrue(exporterReasons.contains(seam), "LoopExporter lost the E4-55 seam `\(seam)`")
        }
        for verbatim in [".failed(\"Recording could not be written to disk\")", ".failed(\"Invalid loop length\")", ".failed(\"Capture failed\")",
                         ".failed(\"The capture buffer is empty\")", ".failed(\"Export failed\")"] {
            XCTAssertFalse(exporterReasons.contains(verbatim), "LoopExporter hands a verbatim reason to `.failed` again: `\(verbatim)`")
        }
        let studioHints = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in [".accessibilityHint(String(localized: \"Sounds the first of every N beats higher and louder — the \")",
                     "+ String(localized: \"click's own accent, not the piece's meter\"))",
                     "return String(localized: \"Pick a pad rhythm above to shape the chord. On Genre the style writes its own \")",
                     "+ String(localized: \"articulation and these three do not run.\")",
                     "var parts = [String(localized: \"Chord length is scaled by the rhythm — short shapes stay short at 1.00.\")]",
                     "parts.append(String(localized: \"This rhythm accents gently by design, so Accent moves less than on \")",
                     "+ String(localized: \"Driving or Dynamic.\"))",
                     "parts.append(String(localized: \"Variation rides the accent here, so at Accent 0.00 the contour stays \")",
                     "+ String(localized: \"flat and only the note length still breathes.\"))",
                     "parts.append(String(localized: \"Variation breathes the note length here — Driving keeps its straight \")",
                     "+ String(localized: \"grid whatever you set.\"))",
                     "parts.append(String(localized: \"Variation changes which cells sound from bar to bar, and breathes the \")",
                     "+ String(localized: \"note length.\"))"] {
            XCTAssertTrue(studioHints.contains(seam), "EchoelStudioView lost the E4-55 seam `\(seam)`")
        }
        for verbatim in [".accessibilityHint(\"Opens the nearby-devices sheet", ".accessibilityHint(\"Sounds the first of every N beats",
                         "return \"Pick a pad rhythm above", "var parts = [\"Chord length", "parts.append(\"This rhythm accents",
                         "parts.append(\"Variation rides", "parts.append(\"Variation breathes", "parts.append(\"Variation changes"] {
            XCTAssertFalse(studioHints.contains(verbatim), "EchoelStudioView builds a hint or caption from verbatim Strings again: `\(verbatim)`")
        }
        let narrationHint = try codeOnly("Sources/Echoelmusic/Studio/LiveNarrationDisclosure.swift")
        for seam in [".accessibilityHint(String(localized: \"Shows or hides the plain-language description of what is \")",
                     "+ String(localized: \"shaping the music\"))"] {
            XCTAssertTrue(narrationHint.contains(seam), "LiveNarrationDisclosure lost the E4-55 seam `\(seam)`")
        }
        XCTAssertFalse(narrationHint.contains(".accessibilityHint(\"Shows or hides the plain-language"),
                       "LiveNarrationDisclosure builds its hint from verbatim Strings again")
        try assertCatalogued(["Recording could not be written to disk", "Invalid loop length", "Capture failed", "The capture buffer is empty", "Export failed",
                          "Sounds the first of every N beats higher and louder — the ", "click's own accent, not the piece's meter",
                          "Pick a pad rhythm above to shape the chord. On Genre the style writes its own ", "articulation and these three do not run.",
                          "Chord length is scaled by the rhythm — short shapes stay short at 1.00.",
                          "This rhythm accents gently by design, so Accent moves less than on ", "Driving or Dynamic.",
                          "Variation rides the accent here, so at Accent 0.00 the contour stays ", "flat and only the note length still breathes.",
                          "Variation breathes the note length here — Driving keeps its straight ", "grid whatever you set.",
                          "Variation changes which cells sound from bar to bar, and breathes the ", "note length.",
                          "Shows or hides the plain-language description of what is ", "shaping the music"],
                         "exporter reasons, Studio hints, pad-shape caption, narration hint")

        // E4-56 — the import sentences are built by pure Sequencer helpers and shown on the Workstation plate and in the
        // media browser; they interpolated names and counts into one English literal. Each fragment is a key now,
        // seamed around the name and the count (≤ 4 operands per step); "bar"/"bars" are reused keys. The runtime
        // guards (ANewPartLandsOnTheChosenTrackTests, TheWorkstationImportsMIDITests, TheImportReusesAnIdenticalLibraryFileTests,
        // AddingAMIDITrackSelectsItTests) read the English assembly unchanged under the test locale.
        let midiNotes = try codeOnly("Sources/Echoelmusic/Sequencer/MIDIImport.swift")
        for seam in ["String(localized: \"Added \") + laneName + String(localized: \". It is selected in the track list.\")",
                     "let landed: String = String(localized: \"Added an empty \") + \"\\(emptyPartBars)\" + String(localized: \"-bar part on \") + laneName",
                     "+ String(localized: \" — once it has notes, it plays at the piece's tempo, with the instrument stopped.\")",
                     "let moved: String = \" \" + selected + String(localized: \" cannot play a MIDI part, so it went on \")",
                     "note += String(localized: \" Generate won't place its music over this part.\")",
                     "let barWord: String = bars == 1 ? String(localized: \"bar\") : String(localized: \"bars\")",
                     "let noteWord: String = count == 1 ? String(localized: \"note\") : String(localized: \"notes\")",
                     "let head: String = String(localized: \"Imported “\") + landing.clip.name + String(localized: \"” — \")",
                     "let landed: String = noteWord + String(localized: \" on \") + laneName + \".\"",
                     "note += String(localized: \" Plays at the piece's tempo on the 16th-note grid, with the instrument stopped.\")",
                     "note += String(localized: \" Notes longer than a bar are held for one bar.\")",
                     "+ String(localized: \" drum notes skipped.\")"] {
            XCTAssertTrue(midiNotes.contains(seam), "MIDIImport lost the E4-56 seam `\(seam)`")
        }
        for verbatim in ["\"Added \\(laneName). It is selected in the track list.\"", "var note = \"Added an empty \\(emptyPartBars)-bar part on",
                         "let barWord: String = bars == 1 ? \"bar\" : \"bars\"", "var note = \"Imported “\\(landing.clip.name)”"] {
            XCTAssertFalse(midiNotes.contains(verbatim), "MIDIImport interpolates an English sentence again: `\(verbatim)`")
        }
        let mediaNote = try codeOnly("Sources/Echoelmusic/Sequencer/MediaPlacement.swift")
        for seam in ["let head: String = String(localized: \"Placed “\") + placed.clipName + String(localized: \"” — \")",
                     "let landed: String = \"\\(bars) \" + barWord + String(localized: \" on \") + laneName",
                     "? String(localized: \", playing the part it already has.\")",
                     ": String(localized: \", as a new part.\")"] {
            XCTAssertTrue(mediaNote.contains(seam), "MediaPlacement lost the E4-56 seam `\(seam)`")
        }
        for verbatim in ["let span = \"\\(bars) \\(bars == 1 ? \"bar\" : \"bars\")\"", "? \"Placed “\\(placed.clipName)”"] {
            XCTAssertFalse(mediaNote.contains(verbatim), "MediaPlacement interpolates an English sentence again: `\(verbatim)`")
        }
        let audioNote = try codeOnly("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        for seam in ["let landed: String = \"\\(bars) \" + barWord + String(localized: \" on \") + laneName",
                     "let head: String = \"“\" + landing.clip.name + String(localized: \"” is already in the library — placed \")",
                     "return head + landed + String(localized: \", no second copy.\")",
                     "let head: String = String(localized: \"Imported “\") + landing.clip.name + String(localized: \"” — \")"] {
            XCTAssertTrue(audioNote.contains(seam), "AudioImport lost the E4-56 seam `\(seam)`")
        }
        for verbatim in ["let span = \"\\(bars) \\(bars == 1 ? \"bar\" : \"bars\")\"", ": \"Imported “\\(landing.clip.name)”"] {
            XCTAssertFalse(audioNote.contains(verbatim), "AudioImport interpolates an English sentence again: `\(verbatim)`")
        }
        try assertCatalogued(["Added ", ". It is selected in the track list.", "Added an empty ", "-bar part on ",
                          ". Its notes are open on the track's Notes page",
                          " — once it has notes, it plays at the piece's tempo, with the instrument stopped.",
                          " cannot play a MIDI part, so it went on ", " Generate won't place its music over this part.",
                          "bar", "bars", "note", "notes", "Imported “", "” — ", " on ",
                          " Plays at the piece's tempo on the 16th-note grid, with the instrument stopped.",
                          " Notes longer than a bar are held for one bar.", " drum notes skipped.",
                          "Placed “", ", playing the part it already has.", ", as a new part.",
                          "” is already in the library — placed ", ", no second copy."],
                         "import sentences")

        // E4-57 — two more spoken lines built by pure helpers: the note grid's VoiceOver label and the arrangement row's
        // "Parts at …" — plus, in the same helper file, the picked-note line ("E4 · bar 2, beat 2 · 2 sixteenths") and the
        // Notes switch title ("Notes · 32"). All four are pinned at runtime with exact English (ThePartNoteGridSpeaksTests,
        // TheSongIsSeenOnOneScaleTests, TheNoteGridSpeaksTheReadersNoteNamesTests, TheSelectedPartSaysItsEndAndItsNotesTests),
        // which the seams reproduce under the test locale; " of ", " selected", " more", ", beat ", "note"/"notes" are reused keys.
        let noteGrid = try codeOnly("Sources/Echoelmusic/Sequencer/ClipNoteEdit.swift")
        for seam in ["let noteWord: String = total == 1 ? String(localized: \"note\") : String(localized: \"notes\")",
                     "let windowed: String = \"\\(shown)\" + String(localized: \" of \") + counted + String(localized: \" shown\")",
                     "let picks: String = \", \" + \"\\(picked)\" + String(localized: \" selected\")",
                     "return String(localized: \"Note grid: \") + notes + picks",
                     "let plural: String = \"\\(steps) \" + String(localized: \"sixteenths\")",
                     "let length: String = steps == 1 ? String(localized: \"1 sixteenth\") : plural",
                     "let place: String = String(localized: \" · bar \") + \"\\(bar)\" + String(localized: \", beat \") + \"\\(beat)\"",
                     "return name + place + \" · \" + length",
                     "guard let count else { return String(localized: \"Notes\") }",
                     "return String(localized: \"Notes · \") + \"\\(count)\""] {
            XCTAssertTrue(noteGrid.contains(seam), "ClipNoteEdit lost the E4-57 seam `\(seam)`")
        }
        for verbatim in ["return \"Note grid: \\(notes), \\(picked) selected\"", "let length = steps == 1 ? \"1 sixteenth\"",
                         "return \"\\(name) · bar \\(bar), beat \\(beat) · \\(length)\"", "return \"Notes · \\(count)\""] {
            XCTAssertFalse(noteGrid.contains(verbatim), "ClipNoteEdit interpolates a spoken line into one English literal again: `\(verbatim)`")
        }
        let stripSpoken = try codeOnly("Sources/Echoelmusic/Studio/ArrangementStripView.swift")
        for seam in ["guard !parts.isEmpty else { return String(localized: \"No parts\") }",
                     "let head: String = String(localized: \"Parts at \") + list",
                     "let tail: String = String(localized: \", and \") + \"\\(rest)\" + String(localized: \" more\")"] {
            XCTAssertTrue(stripSpoken.contains(seam), "ArrangementStripView lost the E4-57 seam `\(seam)`")
        }
        for verbatim in ["return \"No parts\"", "? \"Parts at \\(list), and \\(rest) more\""] {
            XCTAssertFalse(stripSpoken.contains(verbatim), "ArrangementStripView speaks a verbatim English line again: `\(verbatim)`")
        }
        try assertCatalogued(["note", "notes", " of ", " shown", " selected", "Note grid: ", "No parts", "Parts at ", ", and ", " more",
                          "1 sixteenth", "sixteenths", " · bar ", ", beat ", "Notes", "Notes · "],
                         "note grid, picked note, Notes switch and arrangement row")

        // E4-58 — the narration paragraph `BioExplanation.text(for:tempo:)` and the heading / VoiceOver label of its driver
        // were one English assembly; LiveNarrationDisclosure shows them. Every clause is a key now; the pace and breath
        // adjectives ride inside their clause keys (one key per state value) so German can inflect them. The runtime
        // guards (TheNarrationCannotClaimABodyItDidNotReadTests, TheNarrationHeadingNamesItsDriverTests,
        // BioMusicDirectorTests) read the English assembly unchanged under the test locale — prefix, "no pulse measured
        // yet", "from your live signal", "morphs in at the bar line" and the fabricated-word absences all hold.
        let narration = try codeOnly("Sources/Echoelmusic/Sequencer/BioMusicDirector.swift")
        for seam in ["case .body:            return String(localized: \"What your body is doing to the sound\")",
                     "case .simulatedDemo:   return String(localized: \"What the simulated demo source is doing to the sound\")",
                     "case .nothingMeasured: return String(localized: \"What is shaping the sound\")",
                     "case .body, .nothingMeasured: return String(localized: \"Live narration\")",
                     "case .simulatedDemo:          return String(localized: \"Simulated demo, live narration\")",
                     "case \"low\":  setsA = String(localized: \" BPM sets a calm \")",
                     "case \"high\": setsA = String(localized: \" BPM sets a driving \")",
                     "default:     setsA = String(localized: \" BPM sets a flowing \")",
                     "let head: String = String(localized: \"heart rate \") + \"\\(hr)\" + setsA",
                     "clauses.append(head + \"\\(bpm)\" + String(localized: \" BPM tempo\"))",
                     "clauses.append(String(localized: \"tempo holds at \") + \"\\(bpm)\" + String(localized: \" BPM; no pulse measured yet\"))",
                     "clauses.append(String(localized: \"high coherence opens the filter for a brighter, fuller tone\"))",
                     "clauses.append(String(localized: \"moderate coherence holds a balanced tone\"))",
                     "clauses.append(String(localized: \"an unsteady signal keeps the filter lower for a darker, softer tone\"))",
                     "case \"slow\": clauses.append(String(localized: \"slow breathing shapes the swell\"))",
                     "case \"fast\": clauses.append(String(localized: \"fast breathing shapes the swell\"))",
                     "default:     clauses.append(String(localized: \"relaxed breathing shapes the swell\"))",
                     "let signal: String = synthetic ? String(localized: \" from the demo signal,\") : String(localized: \" from your live signal,\")",
                     "let lead: String = synthetic ? String(localized: \"EchoelAI (demo signal) — \") : String(localized: \"EchoelAI — \")",
                     "let engine: String = String(localized: \". Each phrase re-seeds the chords, opening pitch and dynamics\") + source",
                     "+ String(localized: \" then morphs in at the bar line, so it never repeats and never cuts.\")",
                     "return lead + clauses.joined(separator: \"; \") + engine"] {
            XCTAssertTrue(narration.contains(seam), "BioMusicDirector lost the E4-58 seam `\(seam)`")
        }
        for verbatim in ["return \"What your body is doing to the sound\"", "return \"Live narration\"",
                         "let pace = arousal == \"low\" ? \"calm\"", "clauses.append(\"heart rate \\(hr) BPM sets a",
                         "clauses.append(\"tempo holds at \\(bpm) BPM; no pulse measured yet\")",
                         "clauses.append(\"high coherence opens the filter", "clauses.append(\"\\(breath) breathing shapes the swell\")",
                         "let signal = synthetic ? \" from the demo signal,\"", "return (synthetic ? \"EchoelAI (demo signal) — \" : \"EchoelAI — \")"] {
            XCTAssertFalse(narration.contains(verbatim), "BioMusicDirector narrates in a verbatim English literal again: `\(verbatim)`")
        }
        try assertCatalogued(["What your body is doing to the sound", "What the simulated demo source is doing to the sound", "What is shaping the sound",
                          "Live narration", "Simulated demo, live narration",
                          " BPM sets a calm ", " BPM sets a driving ", " BPM sets a flowing ", "heart rate ", " BPM tempo",
                          "tempo holds at ", " BPM; no pulse measured yet",
                          "high coherence opens the filter for a brighter, fuller tone", "moderate coherence holds a balanced tone",
                          "an unsteady signal keeps the filter lower for a darker, softer tone",
                          "slow breathing shapes the swell", "fast breathing shapes the swell", "relaxed breathing shapes the swell",
                          " from the demo signal,", " from your live signal,", "EchoelAI (demo signal) — ", "EchoelAI — ",
                          ". Each phrase re-seeds the chords, opening pitch and dynamics",
                          " then morphs in at the bar line, so it never repeats and never cuts."],
                         "EchoelAI narration")

        // E4-59 — the audio-timing row (Studio master panel) and the Workstation's detected-key sentence were formatted
        // English: `String(format:)` with words around `%.0f`, and interpolated phrases. A catalog key never carries a
        // `%`, so each number keeps its own `String(format:)` and the words become keys seamed around it — every digit
        // is byte-identical, which is what TimingVerdictReachesTheScreenTests' exact `XCTAssertEqual` needs.
        let timingRow = try codeOnly("Sources/Echoelmusic/Audio/RenderGapDetector.swift")
        for seam in ["let blind: String = String(localized: \"Not measured in the last \") + String(format: \"%.0f\", seconds) + String(localized: \" s\")",
                     "return seconds > 0 ? blind : String(localized: \"Not measured yet\")",
                     "let windowed: String = String(localized: \"Nothing late in the last \") + String(format: \"%.0f\", seconds) + String(localized: \" s\")",
                     "return seconds > 0 ? windowed + evidence : String(localized: \"Nothing late so far\") + evidence",
                     "let lateHead: String = \"\\(glitchCount)\" + String(localized: \" late in \") + String(format: \"%.0f\", seconds)",
                     "return lateHead + String(localized: \" s\") + evidence",
                     "let worst: String = String(localized: \" s · worst \") + String(format: \"%.1f\", ms) + String(localized: \" ms behind\")",
                     "let only: String = String(localized: \" · only \") + String(format: \"%.0f\", measuredSeconds) + String(localized: \" s of it measured\")",
                     "return measuredSeconds < 1 ? String(localized: \" · under 1 s of it measured\") : only",
                     "String(localized: \"Timing only. A click while the audio is on time is not counted here.\")",
                     "return isRunning ? String(localized: \"Measuring…\") : String(localized: \"Not measured\")",
                     "let stale: String = line + String(localized: \" · measured before the stop\")"] {
            XCTAssertTrue(timingRow.contains(seam), "RenderGapDetector lost the E4-59 seam `\(seam)`")
        }
        for verbatim in ["String(format: \"Not measured in the last %.0f s\"", "String(format: \"Nothing late in the last %.0f s\"",
                         "String(format: \"%ld late in %.0f s\"", "String(format: \" · only %.0f s of it measured\"",
                         "return isRunning ? \"Measuring…\" : \"Not measured\"", "\"\\(line) · measured before the stop\""] {
            XCTAssertFalse(timingRow.contains(verbatim), "RenderGapDetector formats words into a verbatim English line again: `\(verbatim)`")
        }
        let keySentence = try codeOnly("Sources/Echoelmusic/Sequencer/AudioKeyAnalysis.swift")
        for seam in ["keyPhrase = String(localized: \"Key unclear — little tonal centre\")",
                     "keyPhrase = String(localized: \"Key ambiguous — two keys fit equally well\")",
                     "keyPhrase = String(localized: \"Sounds like \") + tuning.keyName",
                     "a4Phrase = String(localized: \"concert pitch unclear\")",
                     "return keyPhrase + \", \" + a4Phrase + \".\""] {
            XCTAssertTrue(keySentence.contains(seam), "AudioKeyAnalysis lost the E4-59 seam `\(seam)`")
        }
        XCTAssertFalse(keySentence.contains("keyPhrase = \"Sounds like \\(tuning.keyName)\""), "AudioKeyAnalysis interpolates the key sentence again")
        let keyMode = try codeOnly("Sources/Echoelmusic/Core/TuningDetector.swift")
        XCTAssertTrue(keyMode.contains("let mode: String = isMinor ? String(localized: \"minor\") : String(localized: \"major\")"),
                      "TuningDetector lost the E4-59 seam on minor/major")
        XCTAssertFalse(keyMode.contains("isMinor ? \"minor\" : \"major\""), "TuningDetector spells minor/major verbatim again")
        try assertCatalogued(["Not measured in the last ", " s", "Not measured yet", "Nothing late in the last ", "Nothing late so far",
                          " late in ", " s · worst ", " ms behind", " · only ", " s of it measured", " · under 1 s of it measured",
                          "Timing only. A click while the audio is on time is not counted here.", "Measuring…", "Not measured",
                          " · measured before the stop", "Key unclear — little tonal centre", "Key ambiguous — two keys fit equally well",
                          "Sounds like ", "concert pitch unclear", "minor", "major"],
                         "audio-timing row and detected key")

        // E4-60 — the Workstation's detected-tempo sentence, the sibling of the key sentence above: the words become keys
        // seamed around the two `String(format: "%.1f")` numbers; "Tempo ≈ " and " BPM" stay verbatim (no language).
        let tempoSentence = try codeOnly("Sources/Echoelmusic/Sequencer/AudioTempoAnalysis.swift")
        for seam in ["guard tempo.isKnown else { return String(localized: \"Tempo unclear.\") }",
                     "let head: String = \"Tempo ≈ \" + bpm + \" BPM\"",
                     "let loop: String = String(localized: \", a \") + \"\\(bars)\" + String(localized: \"-bar loop (or \")",
                     "return head + loop + alternative + \").\"",
                     "return head + String(localized: \" (or \") + alternative + \").\""] {
            XCTAssertTrue(tempoSentence.contains(seam), "AudioTempoAnalysis lost the E4-60 seam `\(seam)`")
        }
        for verbatim in ["return \"Tempo unclear.\"", "return \"Tempo ≈ \\(bpm) BPM, a \\(bars)-bar loop (or \\(alternative)).\"",
                         "return \"Tempo ≈ \\(bpm) BPM (or \\(alternative)).\""] {
            XCTAssertFalse(tempoSentence.contains(verbatim), "AudioTempoAnalysis interpolates the tempo sentence again: `\(verbatim)`")
        }
        try assertCatalogued(["Tempo unclear.", ", a ", "-bar loop (or ", " (or "], "detected tempo")

        // E4-61 — the Workstation's three remaining caption/spoken producers: the transport caption
        // (WorkstationSummary.transportCaption), the track-removal note (TrackMix.removalNote) and the mix-meter spoken
        // text (MixLevelMeter.spokenText). Numbers are seamed between keys; the four runtime guards that compare the
        // ASSEMBLED English (TheProjectHeaderRunsOneTransportTests, TheSongPositionIsReadAsANumberTests,
        // OnlyAnEmptyTrackCanBeRemovedTests, TheWorkstationShowsTheMixLevelTests) read it unchanged under the test locale.
        let transportCaption = try codeOnly("Sources/Echoelmusic/Studio/WorkstationSummary.swift")
        for seam in ["let fromBar: String = String(localized: \"Playing from bar \") + \"\\(bar)\" + String(localized: \" on the shared transport.\")",
                     "return bar > 1 ? fromBar : String(localized: \"Playing from the top on the shared transport.\")",
                     "if startable { return String(localized: \"Plays the piece's parts from the top.\") }",
                     "return String(localized: \"Nothing to play yet.\")"] {
            XCTAssertTrue(transportCaption.contains(seam), "WorkstationSummary lost the E4-61 seam `\(seam)`")
        }
        for verbatim in ["return bar > 1 ? \"Playing from bar \\(bar) on the shared transport.\"", "return \"Nothing to play yet.\""] {
            XCTAssertFalse(transportCaption.contains(verbatim), "WorkstationSummary interpolates the transport caption again: `\(verbatim)`")
        }
        let removalNote = try codeOnly("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        for seam in ["let several: String = String(localized: \"Remove its \") + \"\\(n)\" + String(localized: \" parts first to remove this track.\")",
                     "return n == 1 ? String(localized: \"Remove its part first to remove this track.\") : several",
                     "case .bio:               return String(localized: \"This track holds a recorded bio curve, so it stays.\")"] {
            XCTAssertTrue(removalNote.contains(seam), "TrackInspectorView lost the E4-61 seam `\(seam)`")
        }
        for verbatim in [": \"Remove its \\(n) parts first to remove this track.\"", "return \"This track holds a recorded bio curve, so it stays.\""] {
            XCTAssertFalse(removalNote.contains(verbatim), "TrackInspectorView interpolates the removal note again: `\(verbatim)`")
        }
        let mixSpoken = try codeOnly("Sources/Echoelmusic/Studio/WorkstationMixMeter.swift")
        for seam in ["let leftHalf: String = String(localized: \"Left \") + \"\\(percent(left))\" + String(localized: \" percent, right \")",
                     "return leftHalf + \"\\(percent(right))\" + String(localized: \" percent\")"] {
            XCTAssertTrue(mixSpoken.contains(seam), "WorkstationMixMeter lost the E4-61 seam `\(seam)`")
        }
        for verbatim in ["\"Left \\(percent(left)) percent, right \\(percent(right)) percent\""] {
            XCTAssertFalse(mixSpoken.contains(verbatim), "WorkstationMixMeter interpolates the spoken text again: `\(verbatim)`")
        }
        try assertCatalogued(["Playing from bar ", " on the shared transport.", "Playing from the top on the shared transport.",
                          "Plays the piece's parts from the top.", "Nothing to play yet.",
                          "Removes this empty track. Undo cannot bring the track, or parts it held earlier, back.",
                          "Remove its part first to remove this track.", "Remove its ", " parts first to remove this track.",
                          "This track holds parts this version cannot edit, so it stays.",
                          "The Echoel instrument plays this track, so it stays.",
                          "This track holds a recorded bio curve, so it stays.",
                          "Left ", " percent, right ", " percent"], "transport caption, removal note and mix-meter spoken text")

        // E4-62 — the instrument plate's remaining producers: `exportLabel` (the Record tile's action text, read by
        // TheBarCountHasACarrierTests as source needles that survive the wrapping), `busyStatusLabel`, the text-size
        // caption (TheTextSizeHasButtonsTests keeps its two needles) and `KeepLastCopy.title` — plus `LoopBarLength
        // .label`, the "8 bars" every one of them carried in English. Numbers and labels are seamed between keys.
        let studioExport = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["return String(localized: \"Record \") + loopBars.label + String(localized: \" → send\")",
                     "case .rendering: return String(localized: \"Writing .wav…\")",
                     "let level: String = String(localized: \"Level \") + \"\\(step + 1)\" + String(localized: \" of \") + \"\\(StudioZoom.ladder.count)\"",
                     "return level + String(localized: \". A pinch zooms the arrangement's time, not the text. \") + scope",
                     "let played: String = String(localized: \"Keep last \") + bars.label + String(localized: \" (just played)\")",
                     "return String(localized: \"Keep last: \") + keepable.label + String(localized: \" or fewer at this tempo\")"] {
            XCTAssertTrue(studioExport.contains(seam), "EchoelStudioView lost the E4-62 seam `\(seam)`")
        }
        for verbatim in ["return \"Record \\(loopBars.label) → send\"",
                         "return \"Level \\(step + 1) of \\(StudioZoom.ladder.count). A pinch zooms the arrangement's time, not the text. \" + scope",
                         "return hasComposed ? \"Keep last \\(bars.label) (just played)\"",
                         "return \"Keep last: \\(keepable.label) or fewer at this tempo\""] {
            XCTAssertFalse(studioExport.contains(verbatim), "EchoelStudioView interpolates a plate label again: `\(verbatim)`")
        }
        let loopBarWord = try codeOnly("Sources/Echoelmusic/Sequencer/LoopCutter.swift")
        for seam in ["let several: String = \"\\(rawValue) \" + String(localized: \"bars\")",
                     "return rawValue == 1 ? String(localized: \"1 bar\") : several"] {
            XCTAssertTrue(loopBarWord.contains(seam), "LoopBarLength.label lost the E4-62 seam `\(seam)`")
        }
        for verbatim in ["rawValue == 1 ? \"1 bar\" : \"\\(rawValue) bars\""] {
            XCTAssertFalse(loopBarWord.contains(verbatim), "LoopBarLength.label interpolates the bar word again: `\(verbatim)`")
        }
        try assertCatalogued(["Stop and discard this recording", "Recording loop…", "Writing .wav…", "Record ", " → send",
                          "Sizes the piece and the instrument; the head follows the system size.",
                          "Default — follows the system text size. ", "Level ", " of ",
                          ". A pinch zooms the arrangement's time, not the text. ",
                          "Keep last ", " (just played)", " — once something has played",
                          "Keep last: unavailable — use the Record tile instead", "Keep last: ", " or fewer at this tempo",
                          "1 bar", "bars"], "plate labels and the bar-length label")

        // E4-63 — the new-MIDI-part hint (`MIDIImport.newPartHint`, a `static let` that keeps its declaration; the
        // ANewPartLandsOnTheChosenTrackTests needles read it at runtime), the Explore board sentence
        // (`BioVariationMaze.boardSentence`; TheVariationCardSaysWhoseTargetTests and OneSpellingOfTheDemoSubjectTests
        // compare the ASSEMBLED English, which the test locale keeps) and the density words it is handed (`densityWord`).
        let partHint = try codeOnly("Sources/Echoelmusic/Sequencer/MIDIImport.swift")
        for seam in ["public static let newPartHint: String = String(localized: \"Adds an empty \") + \"\\(emptyPartBars)\"",
                     "+ String(localized: \"-bar part to the selected MIDI track when it has a voice, otherwise to the first MIDI track, and selects it\")"] {
            XCTAssertTrue(partHint.contains(seam), "MIDIImport lost the E4-63 seam `\(seam)`")
        }
        for verbatim in ["public static let newPartHint = \"Adds an empty \\(emptyPartBars)-bar part"] {
            XCTAssertFalse(partHint.contains(verbatim), "MIDIImport interpolates the new-part hint again: `\(verbatim)`")
        }
        let boardSentence = try codeOnly("Sources/Echoelmusic/Sequencer/BioVariationMaze.swift")
        for seam in ["return String(localized: \"Ideas from your pulse — tap to keep. Your body wants \") + density + \".\"",
                     "let head: String = String(localized: \"Ideas from \") + BioProvenanceCopy.demoSubject + String(localized: \" — tap to keep. \")",
                     "return head + String(localized: \"The demo asks for \") + density + \".\"",
                     "return String(localized: \"No pulse was measured, so these are ranked against the engine's own target — tap to keep. They aim for \") + density + \".\""] {
            XCTAssertTrue(boardSentence.contains(seam), "BioVariationMaze lost the E4-63 seam `\(seam)`")
        }
        for verbatim in ["return \"Ideas from your pulse — tap to keep. Your body wants \\(density).\"",
                         "+ \"The demo asks for \\(density).\"",
                         "+ \"target — tap to keep. They aim for \\(density).\""] {
            XCTAssertFalse(boardSentence.contains(verbatim), "BioVariationMaze interpolates the board sentence again: `\(verbatim)`")
        }
        let mazeDensity = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["case ..<0.5:  return String(localized: \"a calm groove\")",
                     "default:      return String(localized: \"something dense\")"] {
            XCTAssertTrue(mazeDensity.contains(seam), "densityWord lost the E4-63 seam `\(seam)`")
        }
        for verbatim in ["return \"a calm groove\"", "return \"something sparse\""] {
            XCTAssertFalse(mazeDensity.contains(verbatim), "densityWord returns a literal again: `\(verbatim)`")
        }
        try assertCatalogued(["Adds an empty ",
                          "-bar part to the selected MIDI track when it has a voice, otherwise to the first MIDI track, and selects it",
                          "Ideas from your pulse — tap to keep. Your body wants ", "Ideas from ", " — tap to keep. ", "The demo asks for ",
                          "No pulse was measured, so these are ranked against the engine's own target — tap to keep. They aim for ",
                          "something sparse", "a calm groove", "a full groove", "something dense"], "new-part hint and Explore board")

        // E4-64 — the strap status ladder (`PolarH10BioPublisher.statusLabel`, read by the header's pulse pill;
        // PolarH10BioPublisherTests compares the short labels at runtime under the test locale), the part editor's
        // shared-notes hint and the touch surface's spoken terrain (TheGridLabelFitsItsCellTests keeps its fragment).
        let strapStatus = try codeOnly("Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift")
        for seam in ["let name = deviceName.isEmpty ? String(localized: \"Strap\") : deviceName",
                     "return (String(localized: \"Connecting…\"), String(localized: \"Connecting to \") + name)",
                     "let waiting: String = name + String(localized: \" connected — waiting for heart rate\")",
                     "return (String(localized: \"No strap\"), String(localized: \"No strap found — moisten the electrodes, refasten the strap, and pick Bluetooth again\"))"] {
            XCTAssertTrue(strapStatus.contains(seam), "PolarH10BioPublisher lost the E4-64 seam `\(seam)`")
        }
        for verbatim in ["return (\"Scanning…\", \"Searching for a Bluetooth heart-rate strap\")",
                         "return (\"Connecting…\", \"Connecting to \\(name)\")",
                         "(\"\\(name)…\", \"\\(name) connected — waiting for heart rate\")"] {
            XCTAssertFalse(strapStatus.contains(verbatim), "PolarH10BioPublisher interpolates the strap status again: `\(verbatim)`")
        }
        let partEditorHint = try codeOnly("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        for seam in ["let heard = String(localized: \"A change plays the next time the playhead reaches it.\")",
                     "return String(localized: \"These notes play in \") + \"\\(parts)\" + String(localized: \" parts — a change edits all of them. \") + heard"] {
            XCTAssertTrue(partEditorHint.contains(seam), "PartNoteEditor lost the E4-64 seam `\(seam)`")
        }
        for verbatim in ["return \"These notes play in \\(parts) parts — a change edits all of them. \" + heard"] {
            XCTAssertFalse(partEditorHint.contains(verbatim), "PartNoteEditor interpolates the shared-notes hint again: `\(verbatim)`")
        }
        let touchSpoken = try codeOnly("Sources/Echoelmusic/Studio/TouchInstrumentView.swift")
        for seam in ["let spokenRoot: String = String(localized: \"Root \") + rootName + \", \" + \"\\(key.degreesPerOctave)\"",
                     "accessibilityValue = spokenRoot + String(localized: \" notes per octave, three octave rows, low at the bottom\")"] {
            XCTAssertTrue(touchSpoken.contains(seam), "TouchInstrumentView lost the E4-64 seam `\(seam)`")
        }
        for verbatim in ["accessibilityValue = \"Root \\(rootName), \\(key.degreesPerOctave) notes per octave, three octave rows, low at the bottom\""] {
            XCTAssertFalse(touchSpoken.contains(verbatim), "TouchInstrumentView interpolates the spoken terrain again: `\(verbatim)`")
        }
        try assertCatalogued(["Strap", "Scanning…", "Searching for a Bluetooth heart-rate strap", "Connecting…", "Connecting to ",
                          " connected — waiting for heart rate", "BT off",
                          "Bluetooth is off or access is denied — enable it in Settings", "No strap",
                          "No strap found — moisten the electrodes, refasten the strap, and pick Bluetooth again",
                          "A change plays the next time the playhead reaches it.", "These notes play in ",
                          " parts — a change edits all of them. ", "Root ",
                          " notes per octave, three octave rows, low at the bottom"], "strap status, part-editor hint and touch terrain")

        // E4-65 — three sentence families the rest-scan found: the record-take captions, arm subtitle and dropped
        // sentence (RecordTakeControls), the Open refusal (SessionSaveOpen.refusal) and the relink reasons
        // (MediaRelink.userMessage, whose two durations keep `String(format: "%.1f")` between keys). The quoted
        // names stay verbatim; the fragments other guards pin ("Recording starts at bar 1", "instead of the parts
        // under it", "Stop the piece to relink a file.") sit whole inside their keys.
        let takeCaption = try codeOnly("Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        for seam in ["return String(localized: \"Stop the music to record. Recording starts at bar 1.\")",
                     "return \"\\\"\\(name)\\\"\" + String(localized: \" is armed but cannot record here. Open it and switch Arm off first.\")",
                     "return String(localized: \"The part grid is full (\") + \"\\(gridSize)\" + String(localized: \" parts). Remove a part to make room for the recording.\")",
                     "let many: String = \"\\(count)\" + String(localized: \" recordings were not added: the part grid is full (\") + \"\\(gridSize)\" + String(localized: \" parts).\")"] {
            XCTAssertTrue(takeCaption.contains(seam), "RecordTakeControls lost the E4-65 seam `\(seam)`")
        }
        for verbatim in ["return \"Stop the music to record. Recording starts at bar 1.\"",
                         "return \"The part grid is full (\\(gridSize) parts).",
                         ": \"\\(count) recordings were not added:"] {
            XCTAssertFalse(takeCaption.contains(verbatim), "RecordTakeControls spells a caption verbatim again: `\(verbatim)`")
        }
        let openRefusal = try codeOnly("Sources/Echoelmusic/Core/SessionSaveOpen.swift")
        for seam in ["let head: String = \"“\\(project.name)”\" + String(localized: \" was saved with a part grid of \") + \"\\(session.content.clipSlots.count)\"",
                     "return head + String(localized: \"). Update Echoel to open it. Nothing was changed.\")",
                     "return \"“\\(project.name)”\" + String(localized: \"'s piece could not be read by this version of Echoel. \")"] {
            XCTAssertTrue(openRefusal.contains(seam), "SessionSaveOpen lost the E4-65 seam `\(seam)`")
        }
        for verbatim in ["return \"“\\(project.name)” was saved with a part grid of \"", "+ \"Nothing was changed.\""] {
            XCTAssertFalse(openRefusal.contains(verbatim), "SessionSaveOpen spells the refusal verbatim again: `\(verbatim)`")
        }
        let relinkReason = try codeOnly("Sources/Echoelmusic/Sequencer/MediaRelink.swift")
        for seam in ["return String(localized: \"That part can't be relinked.\")",
                     "let lengths: String = String(localized: \"That file is \") + String(format: \"%.1f\", found)",
                     "return lengths + String(localized: \" s. Relink only to the same length — Place a different sound as a new part.\")",
                     "return String(localized: \"Stop the piece to relink a file.\")"] {
            XCTAssertTrue(relinkReason.contains(seam), "MediaRelink lost the E4-65 seam `\(seam)`")
        }
        for verbatim in ["return String(format: \"That file is %.1f s long", "return \"Stop the piece to relink a file.\""] {
            XCTAssertFalse(relinkReason.contains(verbatim), "MediaRelink spells a reason verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Recording from bar 1. Stop, or the piece's end, adds the recording as a new part over the track.",
                          "Plays the piece from bar 1 and records the armed tracks where you play. ",
                          "The recording plays instead of the parts under it; Undo brings them back.",
                          "Stop the music to record. Recording starts at bar 1.",
                          "Arm a MIDI track to record onto it.",
                          " is armed but cannot record here. Open it and switch Arm off first.",
                          "The part grid is full (",
                          " parts). Remove a part to make room for the recording.",
                          "Add a part with notes or audio first. Recording runs against the playing piece.",
                          "Record plays the piece from bar 1 and records your MIDI keyboard onto this track. ",
                          "Every armed track gets the same notes.",
                          "This track cannot record here. Switch Arm off so Record can run.",
                          "1 recording was not added: the part grid is full (",
                          " recordings were not added: the part grid is full (",
                          " parts).",
                          " was saved with a part grid of ",
                          " cells; this version has ",
                          ". Nothing was changed.",
                          " was saved by a newer version of Echoel (piece format ",
                          "). Update Echoel to open it. Nothing was changed.",
                          "'s piece could not be read by this version of Echoel. ",
                          "Nothing was changed.",
                          "That part can't be relinked.",
                          "That file is no longer in the library.",
                          "That file isn't audio this app can read.",
                          "That file is ",
                          " s long and the part's file was ",
                          " s. Relink only to the same length — Place a different sound as a new part.",
                          "That file's content differs from the part's source. ",
                          "Place a different sound as a new part.",
                          "Stop the piece to relink a file."], "record-take captions, open refusal and relink reasons")

        // E4-66 — the scene block's two spoken hints (TheSceneLaunchIsASwitchTests re-anchored 1:1 on the start hint's
        // seam), the look-name fallback every look readout can show, and the value field's VoiceOver "Default" action
        // (TheValueFieldOffersItsDefaultTests keeps both of its needles inside the action block).
        let sceneHints = try codeOnly("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        for seam in ["let loopHint: String = String(localized: \"From the next bar, loops every part listed at \") + title",
                     "let startHint: String = String(localized: \"Starts the piece at the start of \") + songStart",
                     ".accessibilityHint(playing ? loopHint : startHint)"] {
            XCTAssertTrue(sceneHints.contains(seam), "SessionLaunchView lost the E4-66 seam `\(seam)`")
        }
        for verbatim in ["? \"From the next bar, loops every part listed at \\(title)", ": \"Starts the piece at the start of \\(songStart)"] {
            XCTAssertFalse(sceneHints.contains(verbatim), "SessionLaunchView interpolates a scene hint again: `\(verbatim)`")
        }
        let lookName = try codeOnly("Sources/Echoelmusic/Studio/LookBlendMap.swift")
        XCTAssertTrue(lookName.contains("?? (String(localized: \"Look \") + \"\\(index)\")"), "LookBlendMap lost the E4-66 seam on the look-name fallback")
        for verbatim in ["?? \"Look \\(index)\""] {
            XCTAssertFalse(lookName.contains(verbatim), "LookBlendMap interpolates the look-name fallback again: `\(verbatim)`")
        }
        let fieldDefault = try codeOnly("Sources/Echoelmusic/Studio/EchoelValueField.swift")
        XCTAssertTrue(fieldDefault.contains("Button(String(localized: \"Default \") + EchoelDecimalText.string(Double(standard), decimals: decimals)) {"),
                      "EchoelValueField lost the E4-66 seam on the VoiceOver Default action")
        for verbatim in ["Button(\"Default \\(EchoelDecimalText"] {
            XCTAssertFalse(fieldDefault.contains(verbatim), "EchoelValueField interpolates the Default action again: `\(verbatim)`")
        }
        try assertCatalogued(["From the next bar, loops every part listed at ", " and returns every other launched track to the piece",
                          "Starts the piece at the start of ", " and loops every part listed at ", "Look ", "Default "],
                         "scene hints, look name and the Default action")

        // E4-67 — the media browser's remaining bare producers: the three state lines `line(…)` renders (a String
        // parameter, so a literal there never reached the catalog), the relink caption pair, the "still checking" note,
        // the three preview refusals (TheMediaLibraryIsBrowsedAndPlacedTests compares them at runtime under the test
        // locale) and the audio-track fallback in the placed sentence.
        let libraryLines = try codeOnly("Sources/Echoelmusic/Studio/MediaBrowserView.swift")
        for seam in ["line(String(localized: \"Reading the library…\"))",
                     "? String(localized: \"Their parts stay in the piece. Relink offers the library's files once one is there.\")",
                     "note = String(localized: \"A relink is still checking its file.\")",
                     "if songPlaying { return String(localized: \"Stop the piece to preview a file.\") }",
                     "?.name ?? String(localized: \"the audio track\")"] {
            XCTAssertTrue(libraryLines.contains(seam), "MediaBrowserView lost the E4-67 seam `\(seam)`")
        }
        for verbatim in ["line(\"Reading the library…\")", "note = \"A relink is still checking its file.\"",
                         "return \"Stop the piece to preview a file.\"", "?? \"the audio track\""] {
            XCTAssertFalse(libraryLines.contains(verbatim), "MediaBrowserView spells a line verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Reading the library…", "Couldn't read the media library.",
                          "No imported audio yet — Import Audio copies a file here.",
                          "Their parts stay in the piece. Relink offers the library's files once one is there.",
                          "Their parts stay in the piece. Relink points its parts at a library file of the same length.",
                          "A relink is still checking its file.", "Stop the piece to preview a file.",
                          "Stop the instrument's loop to preview a file.", "Sound is off right now, so a preview can't play.",
                          "the audio track"], "media browser lines")

        // E4-68 — the two import doors' failure sentences and the note editor's refusals. `userMessage` is read by
        // WorkstationView's `importNote` and the media browser; the four import guards compare it at runtime under the
        // test locale (equality on the key, `contains` on a fragment, a Set for uniqueness), so none needed a re-anchor.
        // `.tooLong` keeps its two constants between three keys (`MIDIImport.maxBars` / `maxNotes`).
        let importFailures = try codeOnly("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        let midiFailures = try codeOnly("Sources/Echoelmusic/Sequencer/MIDIImport.swift")
        let noteRefusals = try codeOnly("Sources/Echoelmusic/Sequencer/ClipNoteEdit.swift")
        for seam in ["case .pickerFailed:    return String(localized: \"Couldn't open that file.\")",
                     "case .noAudioLane:     return String(localized: \"This piece has no audio track — add an audio track first.\")"] {
            XCTAssertTrue(importFailures.contains(seam), "AudioImport lost the E4-68 seam `\(seam)`")
        }
        for seam in ["case .notAMIDIFile:   return String(localized: \"That file isn't a standard MIDI file this app can read.\")",
                     "String(localized: \"That MIDI file is too long — a part holds up to \") + \"\\(MIDIImport.maxBars)\"",
                     "String(localized: \" bars and \") + \"\\(MIDIImport.maxNotes)\" + String(localized: \" notes.\")"] {
            XCTAssertTrue(midiFailures.contains(seam), "MIDIImport lost the E4-68 seam `\(seam)`")
        }
        for seam in ["case .missing: return String(localized: \"This part's notes are missing from the part grid.\")",
                     "return String(localized: \"The composer rewrites this part as it evolves, so its notes are shown, not edited.\")"] {
            XCTAssertTrue(noteRefusals.contains(seam), "ClipNoteEdit lost the E4-68 seam `\(seam)`")
        }
        XCTAssertFalse(importFailures.contains("return \"Couldn't open that file.\""), "AudioImport spells a failure verbatim again")
        XCTAssertFalse(midiFailures.contains("return \"That MIDI file is too long — a part holds up to \\(MIDIImport.maxBars) bars"),
                       "MIDIImport spells the too-long failure verbatim again")
        XCTAssertFalse(noteRefusals.contains("case .missing: return \"This part's notes are missing"),
                       "ClipNoteEdit spells a refusal verbatim again")
        try assertCatalogued(["Couldn't open that file.", "Couldn't copy that file into the app.",
                          "That file isn't audio this app can read.", "That audio has no usable sample rate or channels.",
                          "That audio has no playable length.", "This piece has no audio track — add an audio track first.",
                          "The part grid is full — all ", " slots are in use.", "Couldn't read that file.",
                          "That file is too large — a MIDI file can be up to 2 MB.",
                          "That file isn't a standard MIDI file this app can read.",
                          "That MIDI file has no notes to play — drum channel 10 is skipped.",
                          "That MIDI file is too long — a part holds up to ", " bars and ", " notes.",
                          "This piece has no MIDI track — add a MIDI track first.",
                          "This part's notes are missing from the part grid.", "This is an audio part — it has no notes to edit.",
                          "The composer rewrites this part as it evolves, so its notes are shown, not edited.",
                          "This part was saved by an older build; its notes cannot be shown or edited here."],
                         "import failures and note-editor refusals")

        // E4-69 — three enum producers whose `displayName`/`blurb`/`userHint`/`shortLabel` reach a Picker row, the
        // FX-character caption, the skill picker and the pulse pill. TheStalledPillSaysWhySilentTests compares
        // `shortLabel` at runtime under the test locale; the camera pill keeps its short German ("Pausiert").
        let fxCharacters = try codeOnly("Sources/Echoelmusic/Sequencer/GenreFX.swift")
        let skillLevels = try codeOnly("Sources/Echoelmusic/Core/SkillLevel.swift")
        let cameraStates = try codeOnly("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift")
        for seam in ["case .auto:       return String(localized: \"Auto (genre)\")",
                     "case .hall:       return String(localized: \"Large, lush concert hall — long, bright reverb tail\")"] {
            XCTAssertTrue(fxCharacters.contains(seam), "GenreFX lost the E4-69 seam `\(seam)`")
        }
        for seam in ["case .beginner: return String(localized: \"Beginner\")",
                     "case .pro:      return String(localized: \"Adds Master — the whole strip.\")"] {
            XCTAssertTrue(skillLevels.contains(seam), "SkillLevel lost the E4-69 seam `\(seam)`")
        }
        for seam in ["case .cooling:     return String(localized: \"Device cooling down — pulse holds for a moment\")",
                     "case .interrupted: return String(localized: \"Camera paused\")"] {
            XCTAssertTrue(cameraStates.contains(seam), "CameraRPPGBioPublisher lost the E4-69 seam `\(seam)`")
        }
        XCTAssertFalse(fxCharacters.contains("return \"Auto (genre)\""), "GenreFX spells a character name verbatim again")
        XCTAssertFalse(skillLevels.contains("case .beginner: return \"Beginner\""), "SkillLevel spells a level verbatim again")
        XCTAssertFalse(cameraStates.contains("return \"Camera recovering…\""), "the camera spells a recovery word verbatim again")
        try assertCatalogued(["Auto (genre)", "Clean (dry)", "Underwater", "Telephone", "Cassette", "Vinyl", "Dream", "Megaphone",
                          "Blurry", "Room", "Hall", "Use the genre's own effect space", "No effects — a dry signal",
                          "Submerged: deep low-pass + watery chorus + tape wobble", "Narrow band-pass — old-phone / lo-fi vocal",
                          "Warm tape: gentle low-pass + wow & flutter", "Dusty record: softened highs, subtle width",
                          "Wide and bright: lush chorus + long ping-pong", "Barking band-pass + saturated slap",
                          "Soft-focus wash: low-pass + deep chorus + smeared echo",
                          "Tight, natural room — adds depth without washing out",
                          "Large, lush concert hall — long, bright reverb tail", "Beginner", "Producer", "Pro",
                          "Just the essentials — Sound, Mood, Save & Export.", "Adds FX, Mix, Tempo and Field.",
                          "Adds Master — the whole strip.", "Camera recovering…", "Device cooling down — pulse holds for a moment",
                          "Camera paused by iOS — waiting to resume", "Recovering", "Cooling", "Camera paused"],
                         "FX characters, skill levels and camera recovery words")

        // E4-70 — the Live Colabo status line (LiveColaboView renders `colab.status`; the three interpolations become
        // key + name), the open-piece refusal that EchoelStudioView's Open door shows (TheImportDoorReportsWhatItCannotRead-
        // Tests compares it at runtime under the test locale), the save-error banner, and the two call-mode notes under
        // the audio route row (TheCodecNoteNamesNoInputTests reads the words at runtime; TheShareDoorReportsWhatItCannot-
        // SendTests keeps its two needles, both inside the new keys).
        let peerStatus = try codeOnly("Sources/Echoelmusic/Sync/MultipeerSession.swift")
        let storeNotes = try codeOnly("Sources/Echoelmusic/Core/ProjectStore.swift")
        let routeNotes = try codeOnly("Sources/Echoelmusic/Audio/AudioConfiguration.swift")
        for seam in ["status = String(localized: \"Looking for nearby Echoelmusic…\")",
                     "status = String(localized: \"Shared with \") + \"\\(peers.count)\" + noun",
                     "status = String(localized: \"Piece received from \") + payload.senderName"] {
            XCTAssertTrue(peerStatus.contains(seam), "MultipeerSession lost the E4-70 seam `\(seam)`")
        }
        for seam in ["return String(localized: \"The file was read, but could not be saved. Retry the pending save.\")",
                     "return field.isEmpty ? String(localized: \"That file isn't an Echoel piece.\") : unreadable"] {
            XCTAssertTrue(storeNotes.contains(seam), "ProjectStore lost the E4-70 seam `\(seam)`")
        }
        XCTAssertTrue(routeNotes.contains("return String(localized: \"This looks like Bluetooth call mode (mono, band-limited). Echoel only plays out; a cable keeps full bandwidth.\")"),
                      "AudioConfiguration lost the E4-70 seam on the inferred call-mode note")
        XCTAssertFalse(peerStatus.contains("status = \"Share failed\""), "MultipeerSession spells a status verbatim again")
        XCTAssertFalse(storeNotes.contains("? \"That file isn't an Echoel piece.\""), "ProjectStore spells the refusal verbatim again")
        XCTAssertFalse(routeNotes.contains("return \"Bluetooth is in call mode: mono and band-limited — the music too. Echoel \""),
                       "AudioConfiguration spells the call-mode note verbatim again")
        try assertCatalogued(["Looking for nearby Echoelmusic…", "Off", "Inviting ", "This piece can't be encoded — not shared",
                          "No peers connected", " peer", " peers", "Shared with ", "Share failed", "Joining ", "Connected to ",
                          "Piece received from ", "The file was read, but could not be saved. Retry the pending save.",
                          "Couldn't read that file.", "That file isn't a readable Echoel piece — ", "That file isn't an Echoel piece.",
                          "Could not save this piece. Your changes are still here. Free device storage or retry.",
                          "Bluetooth is in call mode: mono and band-limited — the music too. Echoel only plays out, so another app holds the call; end it, or use a cable, for full bandwidth.",
                          "This looks like Bluetooth call mode (mono, band-limited). Echoel only plays out; a cable keeps full bandwidth."],
                         "peer status, open refusal and call-mode notes")

        // E4-71 — the loudness-target picker names and the weather mixer's explanation line under each value field.
        // `WeatherMood.Param.label` is deliberately NOT wrapped: `EchoelValueField(label:)` draws it as a catalog KEY
        // (claim 12 walks those); `explanation` is rendered by `Text(param.explanation)`, a String, so it is wrapped.
        let loudnessTargets = try codeOnly("Sources/Echoelmusic/Core/LoudnessTarget.swift")
        let weatherLines = try codeOnly("Sources/Echoelmusic/Core/WeatherMood.swift")
        for seam in ["case .off:          return String(localized: \"No target\")",
                     "case .cinema:       return String(localized: \"Cinema (−24)\")"] {
            XCTAssertTrue(loudnessTargets.contains(seam), "LoudnessTarget lost the E4-71 seam `\(seam)`")
        }
        for seam in ["case .structure:  return String(localized: \"Same sky keeps the same harmonic skeleton each time you play.\")",
                     "case .movement:   return String(localized: \"Wind sets the image in motion.\")",
                     "case .structure:  return \"Structure\""] {
            XCTAssertTrue(weatherLines.contains(seam), "WeatherMood lost the E4-71 seam `\(seam)` (the label stays a bare key)")
        }
        XCTAssertFalse(loudnessTargets.contains("return \"No target\""), "LoudnessTarget spells a target verbatim again")
        XCTAssertFalse(weatherLines.contains("return \"Wind sets the image in motion.\""), "WeatherMood spells an explanation verbatim again")
        try assertCatalogued(["No target", "Streaming (−14)", "Podcast (−16)", "Broadcast (−23)", "Cinema (−24)",
                          "Same sky keeps the same harmonic skeleton each time you play.",
                          "Warm weather brightens the tone, cold darkens it.",
                          "Wind and storms make the music busier, calm keeps it still.",
                          "Storms add tension; a clear sky stays consonant.",
                          "Shifts the colour toward the sky (rain → blue, sun → gold).",
                          "Dull weather drains colour; clear skies deepen it.",
                          "Sun and storms make the image glow; fog dims it.", "Wind sets the image in motion."],
                         "loudness targets and weather explanations")

        // E4-72 — the chooser labels (Label(option.menuLabel, …) in the pill menu and the bio panel), the inspector's
        // device names (`deviceName(_:)`; the agent guards compare the bio one at runtime under the test locale) and the
        // meter names VoiceOver speaks. `TrackInstrument.subtitle` is NOT wrapped: it has no reader (measured E4-72).
        let sourceLabels = try codeOnly("Sources/Echoelmusic/Studio/BioSourceOption.swift")
        let deviceNames = try codeOnly("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        let meterNames = try codeOnly("Sources/Echoelmusic/Studio/VisualAnalysisMeter.swift")
        for seam in ["case .camera: return String(localized: \"Play with camera light\")",
                     "case .health: return String(localized: \"Play with Apple Health — your Watch, at its own pace\")"] {
            XCTAssertTrue(sourceLabels.contains(seam), "BioSourceOption lost the E4-72 seam `\(seam)`")
        }
        for seam in ["case .echoelInstrument:   return String(localized: \"Echoel instrument\")",
                     "return capacity > 0 ? limited : String(localized: \"No voice — extra MIDI tracks are off in this build\")"] {
            XCTAssertTrue(deviceNames.contains(seam), "TrackInspectorView lost the E4-72 seam `\(seam)`")
        }
        for seam in ["case .wavefront: return String(localized: \"Wavefront field of the master output\")",
                     "case .pulse:     return String(localized: \"Pulse interval plot from the camera\")"] {
            XCTAssertTrue(meterNames.contains(seam), "VisualAnalysisMeter lost the E4-72 seam `\(seam)`")
        }
        XCTAssertFalse(sourceLabels.contains("case .camera: return \"Play with camera light\""), "BioSourceOption spells a label verbatim again")
        XCTAssertFalse(deviceNames.contains("? \"No voice — only the first \\(capacity) extra MIDI tracks play\""),
                       "TrackInspectorView spells the no-voice line verbatim again")
        XCTAssertFalse(meterNames.contains("case .wavefront: return \"Wavefront field of the master output\""),
                       "VisualAnalysisMeter spells a meter name verbatim again")
        try assertCatalogued(["Play with camera light", "Play with a Bluetooth strap — scans for one", "Play with the simulation",
                          "Play with Apple Health — your Watch, at its own pace", "Echoel instrument", "Audio file player",
                          "Bio curve — no sound", "No engine plays this track yet", "No voice — only the first ",
                          " extra MIDI tracks play", "No voice — extra MIDI tracks are off in this build",
                          "Wavefront field of the master output", "Spectrum of the master output",
                          "Oscilloscope of the master output", "Pulse interval plot from the camera"],
                         "source chooser, device names and meter names")

        // E4-73 — the studio file's remaining bare producers: the chip full names (`.accessibilityLabel(menu.fullName)`),
        // `placeStatusLine` (two interpolations become key + place + key), the eight rhythm sentences under the Field arp
        // row, and `moodVariationCaption` (TheGenrePresetIsACentreNotAPointTests reads its first 900 characters for the
        // projected count — `let moved` and both keys sit inside that window).
        let studioNames = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["case .bio:         return String(localized: \"Bio — pulse, HRV, coherence, source\")",
                     "case .effects:     return String(localized: \"Effects\")",
                     "return String(localized: \"In the name: \") + manual + String(localized: \" (manual)\")",
                     "return String(localized: \"Looking up your city…\")",
                     "return String(localized: \"Fewer notes than Density asks for, only on the beats, held long. Wide.\")",
                     "let others: String = String(localized: \"Bar 1 plays the genre preset; the other \") + \"\\(loopBars.rawValue - 1)\""] {
            XCTAssertTrue(studioNames.contains(seam), "EchoelStudioView lost the E4-73 seam `\(seam)`")
        }
        for verbatim in ["return \"In the name: \\(manual) (manual)\"",
                         "case .bio:         return \"Bio — pulse, HRV, coherence, source\"",
                         "return \"Fewer notes than Density asks for, only on the beats, held long. Wide.\""] {
            XCTAssertFalse(studioNames.contains(verbatim), "EchoelStudioView spells a studio sentence verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Bio — pulse, HRV, coherence, source",
                          "Tempo and variations — tap tempo, metronome, haptic beat, variation ideas",
                          "Sound and texture, plus the piece's scenes and tracks", "Mix — level per part", "Effects", "Master",
                          "Mood — character, and the weather that colours it",
                          "Save and export settings — loop length, place in the name, default sound, diagnostics",
                          "Field — the visual surface you play with your fingers",
                          "In the name: ", " (manual)", "Adds your city to the name — never stored by Echoel. Or type one above.",
                          "Location is off for Echoel in Settings — type a place above instead.", "Looking up your city…",
                          "Flowing already sits a hair behind on every note, and Laid back adds to it — the two together stop at the row's own ceiling, so above about 0.40 the timing no longer changes.",
                          "Syncopated already leans back on its off-beats, and Laid back adds to it — on those notes the two together stop at the row's ceiling, so above about 0.33 they no longer move.",
                          "Straight and short, hard on the beat — machine time, with air between the notes for the pulse to be felt.",
                          "Even and long with almost no accent, and the figure rotates a little every bar so it repeats without being repetitive.",
                          "The same notes as Driving but longer, and the level contour moves — the bar breathes. This is where Evolve does the most.",
                          "Fewer notes than Density asks for, only on the beats, held long. Wide.",
                          "Prefers the cells between the beats and accents them, inverting the weight — the off-beats are the loud ones, and they land a touch late.",
                          "Long and level, filling the cell and sitting a hair behind the beat — it stays under everything else instead of competing with it.",
                          "Variation needs more than one bar — bar 1 is always the genre preset, and there is no rest of the loop to vary. Raise Loop length to use it.",
                          "Bar 1 plays the genre preset; the other ", " bars read it slightly differently. ",
                          " performance dials drift — register, dissonance and chord colour hold, so the genre still sounds like itself at 1.00."],
                         "studio full names, place line, rhythm blurbs and variation caption")

        // E4-74 — the music-theory primer: nine titles, nine one-line summaries, nine paragraphs. LearnLibrary projects
        // them into LearnEntry rows, so they are the Learn sheet's music section. `MusicTheoryTopic.footer` has no
        // reader in Sources/ and stays as it is.
        let theoryPrimer = try codeOnly("Sources/Echoelmusic/Studio/MusicTheoryPrimer.swift")
        for seam in ["case .interval:    return String(localized: \"Interval\")",
                     "case .scale:       return String(localized: \"Scale & Mode\")",
                     "case .cadence:     return String(localized: \"A chord move that ends or pauses a phrase.\")",
                     "return String(localized: \"Beats per minute. Slow tempos feel calm, fast ones energetic. In Echoelmusic tempo can follow your heart rate or be locked to an exact BPM for export.\")"] {
            XCTAssertTrue(theoryPrimer.contains(seam), "MusicTheoryPrimer lost the E4-74 seam `\(seam)`")
        }
        for verbatim in ["case .interval:    return \"Interval\"",
                         "case .cadence:     return \"A chord move that ends or pauses a phrase.\""] {
            XCTAssertFalse(theoryPrimer.contains(verbatim), "MusicTheoryPrimer spells a primer line verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Interval", "Scale & Mode", "Chord", "Chord Progression", "Cadence", "Key", "Tempo", "Swing", "Dynamics",
                          "The distance in pitch between two notes.", "The set of pitches a piece draws from.",
                          "Several notes sounding together.", "The order chords move through over time.",
                          "A chord move that ends or pauses a phrase.", "The home note and scale a piece centres on.",
                          "How fast the music goes, in beats per minute.", "Shifting off-beats later for a rolling feel.",
                          "How loud or soft the music is, moment to moment.",
                          "Measured in semitones (the smallest step on a keyboard). Small intervals feel close and smooth; wider ones feel like leaps. Echoelmusic builds melodies by choosing intervals that stay inside your key.",
                          "A ladder of pitches — major sounds bright, minor sounds darker, the modes (Dorian, Phrygian…) each have their own colour. Echoelmusic keeps every generated note on the chosen scale so nothing sounds wrong.",
                          "Usually three or more notes stacked in thirds (a triad). Major and minor triads are the basic colours; sevenths add tension. The body's coherence opens Echoelmusic toward more consonant, settled chords.",
                          "Chords don't sit still — they move, creating pull and release. Common moves (like I–V–vi–IV) feel satisfying because each chord sets up the next. Echoelmusic rotates progressions so a loop doesn't repeat the same change.",
                          "The punctuation of harmony: a strong V→I lands like a full stop, while other cadences leave a phrase hanging. Echoelmusic resolves a loop with a turnaround cadence so it feels finished, not cut off.",
                          "A piece's centre of gravity — its home note plus the scale around it (e.g. C minor). Everything is heard in relation to home. Echoelmusic locks the music to one key (with your concert pitch, default A440) so your WAV and MIDI exports drop into your DAW already in tune.",
                          "Beats per minute. Slow tempos feel calm, fast ones energetic. In Echoelmusic tempo can follow your heart rate or be locked to an exact BPM for export.",
                          "Straight rhythms place notes evenly; swing pushes every other note slightly late, giving jazz, hip-hop and house their groove. Echoelmusic's swing amount is adjustable per piece.",
                          "The loud-and-soft shape of a performance. Accents on strong beats and gentle swells make a line feel human rather than mechanical — Echoelmusic adds these with its phrasing and humanize controls."],
                         "music-theory primer")

        // E4-75 — the body-science sheet: five titles, five gists, five paragraphs. LearnLibrary projects them into
        // the Learn sheet's body-science section. The citation sentences TheScienceCardClaimsNoSweepTests pins live
        // INSIDE the literals and are untouched; only the escape `\u{201C}` became its glyph, so the key is a literal.
        let bodyScience = try codeOnly("Sources/Echoelmusic/Studio/BioScienceInfo.swift")
        for seam in ["case .resonanceFrequency: return String(localized: \"Resonance breathing (~6 breaths/min)\")",
                     "case .scope:              return String(localized: \"Science for self-observation, not diagnosis.\")",
                     "return String(localized: \"Heart-rate variability (HRV) is the beat-to-beat change in your heart rate; more variation at rest generally reflects an adaptable system. “Coherence” here is a specific, measurable thing: a smooth, single-peak rhythm in the heart rate near 0.1 Hz. Echoelmusic computes it in the frequency domain (a Lomb-Scargle periodogram for the unevenly-timed heartbeats, with Welch averaging) — a standard signal-processing approach, not a score of worth. It is a number to observe, nothing more. (Source: peer-reviewed HRV signal-processing methods.)\")"] {
            XCTAssertTrue(bodyScience.contains(seam), "BioScienceInfo lost the E4-75 seam `\(seam)`")
        }
        for verbatim in ["case .resonanceFrequency: return \"Resonance breathing (~6 breaths/min)\"",
                         "\\u{201C}Coherence\\u{201D} here"] {
            XCTAssertFalse(bodyScience.contains(verbatim), "BioScienceInfo spells a body-science line verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Resonance breathing (~6 breaths/min)", "Heart-rate variability & coherence", "The baroreflex loop",
                          "What the research measures", "What this is — and is not",
                          "The pace where breath and heartbeat couple most.", "A smooth, single-peak heart rhythm you can watch.",
                          "The blood-pressure loop that links the two.", "What controlled studies actually reported.",
                          "Science for self-observation, not diagnosis.",
                          "Breathing at roughly six breaths per minute (about 0.1 Hz) is the pace at which breathing-driven and blood-pressure-driven influences on heart rate line up, so heart-rate swings grow largest. The exact best pace is individual — usually between 4.5 and 7 breaths per minute — Echoelmusic paces one steady rate near the middle of that range and shows your HRV and coherence live while you follow it, so you can watch how your own body responds. It does not run the clinical sweep that finds your personal resonance frequency for you (that is the Lehrer & Vaschillo protocol). It paces and measures; it prescribes nothing. (Source: peer-reviewed HRV-biofeedback literature, Lehrer & Vaschillo.)",
                          "Heart-rate variability (HRV) is the beat-to-beat change in your heart rate; more variation at rest generally reflects an adaptable system. “Coherence” here is a specific, measurable thing: a smooth, single-peak rhythm in the heart rate near 0.1 Hz. Echoelmusic computes it in the frequency domain (a Lomb-Scargle periodogram for the unevenly-timed heartbeats, with Welch averaging) — a standard signal-processing approach, not a score of worth. It is a number to observe, nothing more. (Source: peer-reviewed HRV signal-processing methods.)",
                          "The baroreflex is the body's fast blood-pressure feedback loop: sensors in the arteries adjust heart rate to keep pressure steady. Breathing near your resonance pace pushes this loop into a large, regular heart-rate swing in step with each breath — that is the physiology the whole biofeedback loop rests on. Echoelmusic lets you watch it happen. (Source: cardiovascular-physiology reviews.)",
                          "In a 2017 meta-analysis (Goessl, Curtiss & Hofmann, Psychological Medicine), HRV biofeedback was associated with reduced self-reported stress and anxiety across the controlled studies reviewed. That is what those studies measured — self-reported states — and Echoelmusic simply shows you the same live signal to observe. Echoelmusic makes no claim that using it produces these outcomes; nothing here is prescribed, and it is not a substitute for professional care. (Source: Goessl, Curtiss & Hofmann, 2017, Psychological Medicine 47:2578–2586.)",
                          "Echoelmusic measures and explains your heart rhythm and breath honestly so you can observe how they couple, and so your body can drive the music and visuals. It is for self-observation and creative expression. It is NOT a medical device, diagnoses nothing, treats no condition, makes no wellness or health claim, and is not a substitute for professional care. Chest-strap readings are most accurate; wrist and camera are estimates. If you are exploring breathing or heart rhythm for a health reason, talk to a qualified clinician."],
                         "body-science sheet")

        // E4-76 — the light-science sheet: five titles, five gists, five paragraphs. The `.scope` paragraph carries the
        // seam share "39 %" as a bare operand between two keys (String(localized:) reads a key as a format string, so
        // `%` may not enter the catalog); TheColourCopyNamesThePurpleLineTests pins that seam.
        let lightScience = try codeOnly("Sources/Echoelmusic/Studio/LightScienceInfo.swift")
        for seam in ["case .circadianBlue:    return String(localized: \"Blue light & the body clock (~480 nm)\")",
                     "case .scope:            return String(localized: \"Science for self-observation, not therapy.\")",
                     "deep red meets deep violet. About \") + \"39 %\" + String(localized: \" of each octave lands on that seam, and there the colour is an honest red-to-violet mix"] {
            XCTAssertTrue(lightScience.contains(seam), "LightScienceInfo lost the E4-76 seam `\(seam)`")
        }
        for verbatim in ["case .circadianBlue:    return \"Blue light & the body clock (~480 nm)\"",
                         "deep violet. About 39 % of each octave"] {
            XCTAssertFalse(lightScience.contains(verbatim), "LightScienceInfo spells a light-science line verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Blue light & the body clock (~480 nm)", "Green light (~525 nm)", "Red & near-infrared (~620–850 nm)",
                          "Colour & emotion", "What Echoelmusic’s light is — and is not",
                          "The wavelength your inner clock reads most.", "Where daytime vision is most sensitive.",
                          "The long-wave red end — and the band just past sight.", "Shared, learned colour associations.",
                          "Science for self-observation, not therapy.",
                          "Short-wavelength blue light, peaking around 480 nm, is the main signal that sets the human body clock. It is sensed by melanopsin in a special class of retinal cells (ipRGCs) wired straight to the brain’s master clock (the suprachiasmatic nucleus). Morning blue light tends to raise alertness; blue light late at night tends to delay the clock. Echoelmusic can map and explain this wavelength — it does not prescribe it. (Source: peer-reviewed circadian/blue-light reviews, PMC/NIH.)",
                          "Green light around 525 nm sits near the peak of daytime (cone) vision, so it reads as very bright while only weakly driving the melanopsin clock signal compared with blue. That distinct response is why green is studied separately from blue in light science. Echoelmusic represents it accurately as a wavelength; it makes no health claim. (Source: peer-reviewed light-physiology reviews.)",
                          "Red light (~620–700 nm) is the longest wavelength the human eye still sees; near-infrared (~700–850 nm) lies just beyond it — invisible to us, though many camera sensors still register it. As the low-frequency end of the visible spectrum, these long waves scatter less in air than short blue waves, which is part of why low sun and distant lamps read as red. Echoelmusic renders this warm end from your actual tuning through the CIE 1931 colour-matching functions and can drive it to Art-Net / sACN fixtures. A tone whose transposed wavelength runs past the deep-red edge does not go dark: the colour mapping closes over the CIE purple line and continues into violet, so every tone keeps a colour. The wavelength readout still shows the honest number. Honest colour for creative expression and self-observation — not a medical device, and it makes no health claim. (Source: standard optics and CIE 1931 colour science.)",
                          "Across 130+ studies from 60+ countries, people share systematic colour–emotion associations: red with high arousal and energy, blue and green with calm and low arousal, bright colours with positive feeling. These are learned, perceptual associations after the brain processes the image — not direct effects on cells. Echoelmusic uses them as an honest aesthetic mapping for its visuals and light. (Source: global colour–emotion meta-analysis, 1895–2022.)",
                          "Echoelmusic maps and explains light by real wavelength so your music and body can drive colour, visuals and DMX/Art-Net fixtures honestly. Tone colours use octave transposition — doubling a tone's frequency until it reaches the visible band; Echoelmusic computes it continuously from your actual tuning and renders the colour through the CIE 1931 colour-matching functions, closed over the CIE purple line where deep red meets deep violet. About ",
                          " of each octave lands on that seam, and there the colour is an honest red-to-violet mix rather than one single wavelength — that is how the mapping gives every tone a colour instead of leaving a gap. The transposition is exact mathematics and an artistic convention: sound and light are different physical phenomena, so no health or cosmic effect is implied. This is for creative expression and self-observation. It is NOT light therapy, makes no medical or wellness claim, diagnoses nothing, and treats no condition. If you are exploring light for health reasons, talk to a qualified clinician."],
                         "light-science sheet")

        // E4-77 — the last two reachable sentences: the automation row's hint (four units; the past-end suffix is a
        // typed ternary of key and empty string, the empty-row pair a typed ternary of two keys) and the value field's
        // spoken gesture. SongAutomationEdit.hint stays `nonisolated static`.
        let automationHint = try codeOnly("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        for seam in ["let past: String = continuesPastEnd ? String(localized: \" The curve runs on to a point after the end of the piece.\") : \"\"",
                     "return String(localized: \"Tap a point to pick it. Press and hold a point, then slide to move it.\") + past"] {
            XCTAssertTrue(automationHint.contains(seam), "SongAutomationEditor lost the E4-77 seam `\(seam)`")
        }
        XCTAssertFalse(automationHint.contains("return \"Tap a point to pick it. Press and hold a point, then slide to move it.\" + past"),
                       "SongAutomationEditor spells the row hint verbatim again")
        let fieldGesture = try codeOnly("Sources/Echoelmusic/Studio/EchoelValueField.swift")
        XCTAssertTrue(fieldGesture.contains("let gesture: String = String(localized: \"Swipe up or down to adjust, or double-tap to type\")"),
                      "EchoelValueField lost the E4-77 gesture seam")
        XCTAssertFalse(fieldGesture.contains("let gesture = \"Swipe up or down to adjust, or double-tap to type\""),
                       "EchoelValueField spells the gesture verbatim again")
        try assertCatalogued([" The curve runs on to a point after the end of the piece.", "Tap the row to add a point in the piece.",
                          "Tap the row to add the first point.",
                          "Tap a point to pick it. Press and hold a point, then slide to move it.",
                          "Swipe up or down to adjust, or double-tap to type"],
                         "automation hint and value-field gesture")

        // E4-78 — the wide scan's first slice: WorkstationSummary (transport/click hints, the row description's
        // fragments and the bar span — the span's joiner is the shared key " to ", so a German row says "Takte 1 zu 5"
        // until the founder picks a span word), TempoFollowLabel + the lock button, and the two accent notes under the
        // Field arp row. TheWorkstationHasADoorTests, TheWorkstationPlaysTheTimelineTests, TheWorkstationArmsTheClickTests
        // and TheSpokenTempoSaysWhoseBodyTests drive these at runtime under the test locale.
        let summarySpoken = try codeOnly("Sources/Echoelmusic/Studio/WorkstationSummary.swift")
        for seam in ["let one: String = String(localized: \"bar \") + \"\\(from)\"",
                     "if startable { return String(localized: \"Plays the arrangement from the top on the shared transport.\") }",
                     "on ? String(localized: \"Turns the click off.\")",
                     "if row.isArmed { parts.append(String(localized: \"armed to record\")) }"] {
            XCTAssertTrue(summarySpoken.contains(seam), "WorkstationSummary lost the E4-78 seam `\(seam)`")
        }
        XCTAssertFalse(summarySpoken.contains("if row.isArmed { parts.append(\"armed to record\") }"),
                       "WorkstationSummary spells a spoken fragment verbatim again")
        let tempoSpoken = try codeOnly("Sources/Echoelmusic/Studio/BodyTempoField.swift")
        for seam in ["return String(localized: \"Tempo, following \") + BioPanelRowCopy.subject(synthetic: frame.source.isSynthetic)",
                     ": String(localized: \"Tempo locked — tap to let your body drive it again\")",
                     ": String(localized: \"Lock tempo at this value\"))"] {
            XCTAssertTrue(tempoSpoken.contains(seam), "BodyTempoField lost the E4-78 seam `\(seam)`")
        }
        XCTAssertFalse(tempoSpoken.contains("return \"Tempo, following \" + BioPanelRowCopy"),
                       "BodyTempoField spells the following label verbatim again")
        let accentNotes = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(accentNotes.contains("return fieldArpRhythmLabel(fieldArpCharacter) + String(localized: \" is nearly level by design"),
                      "EchoelStudioView lost the E4-78 accent seam")
        XCTAssertFalse(accentNotes.contains("return \"On Dynamic, Evolve moves the accent"),
                       "EchoelStudioView spells the Dynamic note verbatim again")
        try assertCatalogued(["Plays the arrangement from the top on the shared transport.",
                          "Unavailable: this piece has no parts on a track that plays.", "Turns the click off.",
                          "Plays a steady click at the current tempo, on the piece's beats while it plays.",
                          "bar ", "bars ", "bio automation track", "no parts", "1 part", "parts", " to ", "muted", "soloed",
                          "armed to record", "no timeline engine plays this kind yet",
                          "Tempo, following — no reading is arriving", "Tempo, following ",
                          "Tempo locked — tap to let it follow again",
                          "Tempo locked — tap to let the simulated demo source drive it again",
                          "Tempo locked — tap to let your body drive it again", "Lock tempo at this value",
                          " is nearly level by design — Accent barely cuts here. Dynamic or Driving give a strong one.",
                          "On Dynamic, Evolve moves the accent — with Accent at 0 the contour stays flat and only the note length still breathes."],
                         "workstation spoken sentences, tempo label and accent notes")

        // E4-79 — the Routing surface (PatchbayView): every `cond ? "…" : "…"` inside Text / accessibilityHint /
        // accessibilityLabel was a String, not a key. Each branch is now its own `String(localized:)`; the clinical
        // ON note carries a `%`, so it lives in `clinicalDetailOnNote` with the sign as a bare operand (a key is read as
        // a format string). TheRoutingCardDoesNotPromiseGestureTests pins "pNN50 as a percentage ride the OSC stream"
        // as a substring (survives the wrap) and the percent line 1:1 (re-anchored in this slice).
        let patchbayToggles = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        for seam in [": String(localized: \"Off. No wireless MIDI in either direction.\")",
                     ": String(localized: \"Off. Every note is sent on channel 1.\")",
                     ": String(localized: \"Unavailable while MPE note layout is off, because per-note expression needs one channel per note.\")",
                     ": String(localized: \"Off. Only the MIDI 1.0 source is offered to hosts.\")",
                     ": String(localized: \"Off. No socket is open; Echoel sends only.\")",
                     "? clinicalDetailOnNote",
                     "let scale: String = String(localized: \"On: /echoelmusic/bio/heart/rmssd and /sdnn (milliseconds) and /pnn50 (0–100 \") + \"%\"",
                     ": String(localized: \"Clear all routes\")"] {
            XCTAssertTrue(patchbayToggles.contains(seam), "PatchbayView lost the E4-79 seam `\(seam)`")
        }
        for verbatim in ["                    ? \"On. Notes are spread across the MPE member channels, so a rig can bend and press each note on its own.\"",
                         "? \"Smart patch — no suggestions available\"",
                         "(0–100 %) are sent as well"] {
            XCTAssertFalse(patchbayToggles.contains(verbatim), "PatchbayView spells a routing hint verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["On. Any device on your local network can connect to this iPhone over MIDI, and this iPhone can send MIDI out over the network.",
                          "Off. No wireless MIDI in either direction.",
                          "Off. Every note is sent on channel 1.", "Off. Notes are sent without per-note expression.",
                          "Unavailable while MPE note layout is off, because per-note expression needs one channel per note.",
                          "Off. Only the MIDI 1.0 source is offered to hosts.", "Off. No socket is open; Echoel sends only.",
                          "On. rMSSD and SDNN in milliseconds and pNN50 as a percentage ride the OSC stream alongside the musical controls.",
                          "On: /echoelmusic/bio/heart/rmssd and /sdnn (milliseconds) and /pnn50 (0–100 ",
                          ") are sent as well. Use this for analysis in TouchDesigner, Max or a research patch — turn it off on a network you do not control.",
                          "Smart patch — no suggestions available", "Smart patch", "Clear — no routes to clear", "Clear all routes"],
                         "routing toggle hints and notes")

        // E4-80 — EchoelStudioView's remaining ternaries and helper Strings. Where a helper only forwarded a String
        // into `Label` / `accessibilityLabel` / `accessibilityHint`, its parameter became a `LocalizedStringKey` and
        // the call sites stayed byte-identical (the E4-9 move); where a `+` chain sat inside a ternary (weather) the
        // sentence moved into a computed property with two typed returns (E4-28).
        let studioToggles = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["? String(localized: \"Stops this recording and discards it. Nothing is saved.\")",
                     "private var weatherLine: String {",
                     "Text(weatherLine)",
                     "touchPatchChip(name: String(localized: \"Same as music\"), selected: touchPatchID.isEmpty)",
                     "Text(text.isEmpty ? String(localized: \"No diagnostics recorded.\") : text)",
                     "private func sizeButton(_ word: LocalizedStringKey, systemImage: String, spoken: LocalizedStringKey, hint: LocalizedStringKey,",
                     ": String(localized: \"Off by default. Heart and breathing measurements only.\")",
                     "? String(localized: \"Running — the picture already follows your body.\")"] {
            XCTAssertTrue(studioToggles.contains(seam), "EchoelStudioView lost the E4-80 seam `\(seam)`")
        }
        // ⭐ SLICE G (2026-10-02): `masterDoorButton` was an E4-80 seam (its `title`/`hint` took a
        // `LocalizedStringKey`); slice G deleted it with the master panel's Routing door. The seam
        // is not dropped, it is INVERTED — the helper must stay gone — and Routing's one door, the
        // head's light tile, carries the catalog key that the deleted hint carried (below, and the
        // tile's line in `HeaderMonitors`).
        XCTAssertFalse(studioToggles.contains("func masterDoorButton("),
                       "EchoelStudioView declares `masterDoorButton` again — slice G deleted it with the master panel's Routing door")
        let routingDoor = try codeOnly("Sources/Echoelmusic/Studio/HeaderMonitors.swift")
        XCTAssertTrue(routingDoor.contains(".accessibilityHint(\"Opens Routing: MIDI pairing, the MIDI out switches, the OSC, Art-Net, sACN and spatial-audio targets, and the light master.\")"),
                      "HeaderMonitors lost the light tile's Routing hint — Routing's one door since slice G speaks it as a catalog key")
        for verbatim in ["                ? \"Stops this recording and discards it. Nothing is saved.\"",
                         "    private func sizeButton(_ word: String, systemImage: String, spoken: String, hint: String,",
                         "                 ? \"Running — the picture already follows your body.\""] {
            XCTAssertFalse(studioToggles.contains(verbatim), "EchoelStudioView spells a studio sentence verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Stops this recording and discards it. Nothing is saved.", "Records one loop and exports a WAV to share",
                          "Variations of the same groove — your body curates, you pick.", "Sky reading arrives at Start.", "Now: ",
                          "How often the click accents. This is the click's own bar only — it does not change the piece's meter",
                          "Routing", "Opens Routing: MIDI pairing, the MIDI out switches, the OSC, Art-Net, sACN and spatial-audio targets, and the light master.",
                          "Same as music", "No diagnostics recorded.",
                          "Smaller", "Larger", "Default", "Smaller text", "One step smaller.", "Larger text", "One step larger.",
                          "Default text size", "Follows the system text size.",
                          "Keeps the last bars you just heard as a WAV loop, without replaying them",
                          "Waiting for permission in Health.", "Off by default. Heart and breathing measurements only.",
                          "Running — the picture already follows your body."],
                         "studio toggles, doors and text-size buttons")

        // E4-81 — three surfaces whose ternaries were Strings: the track inspector (`TrackMix.muteHint/soloHint`,
        // driven at runtime by TheTrackHeaderMutesAndSolosTests under the test locale), the scene launcher's guide
        // line and part hint, the note editor's toggle label and grid hint. The two `.accessibilityAction(named:)`
        // literals, the Colabo stream hint and the FX search prompt were already keys (LocalizedStringKey position)
        // and only lacked a unit — ThePartNoteGridSpeaksTests pins the action lines verbatim, so they stay verbatim.
        let inspectorHints = try codeOnly("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        for seam in ["? String(localized: \"Silences this track and the Studio instrument. Start un-mutes it\")",
                     ": String(localized: \"Silences this track\")",
                     "? String(localized: \"Plays only the soloed tracks\")"] {
            XCTAssertTrue(inspectorHints.contains(seam), "TrackInspectorView lost the E4-81 seam `\(seam)`")
        }
        XCTAssertFalse(inspectorHints.contains("            : \"Silences this track\""), "TrackInspectorView spells the mute hint verbatim again")
        let launchHints = try codeOnly("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        for seam in [": String(localized: \"Launch a scene to start the piece at its bar and loop it, or press Play for the piece as arranged.\")",
                     "? String(localized: \"Already looping. Stop the track to hand it back to the piece\")",
                     ": String(localized: \"Loops this part on its track from the next bar\")"] {
            XCTAssertTrue(launchHints.contains(seam), "SessionLaunchView lost the E4-81 seam `\(seam)`")
        }
        XCTAssertFalse(launchHints.contains("                           : \"Loops this part on its track from the next bar\")"),
                       "SessionLaunchView spells the part hint verbatim again")
        let noteGridHints = try codeOnly("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        // DAW shell S4a: the editor's open/close switch is gone (the Notes page of the track's detail
        // is the open grid), and with it the toggle-label pair E4-81 made into two keys. Its absence is
        // pinned here; the count the heading speaks keeps its E4-91 seam below.
        XCTAssertFalse(noteGridHints.contains("Hide the selected part's notes"), "the note editor grew a switch again")
        for seam in [": String(localized: \"Shown, not edited\")",
                     ".accessibilityAction(named: \"Select next note\") {"] {
            XCTAssertTrue(noteGridHints.contains(seam), "PartNoteEditor lost the E4-81 seam `\(seam)`")
        }
        XCTAssertFalse(noteGridHints.contains("                                : \"Shown, not edited\")"), "PartNoteEditor spells the grid hint verbatim again")
        try assertCatalogued(["Silences this track and the Studio instrument. Start un-mutes it", "Silences this track",
                          "Plays only the soloed tracks",
                          "Plays only the soloed tracks. This also silences the Studio instrument, whose Start clears the solo",
                          "Launch a scene to start the piece at its bar and loop it, or press Play for the piece as arranged.",
                          "Already looping. Stop the track to hand it back to the piece", "Loops this part on its track from the next bar",
                          "Shown, not edited",
                          "Select next note", "Select previous note", "Search presets & tags",
                          "Streams your heart rate and coherence to connected peers while this screen is open. Everyone sees their own numbers side by side."],
                         "inspector, launcher and note-editor hints")

        // E4-82 — the automation editor (toggle label pair as two keys; the value field's `hint:` is a String), the
        // automation strip's status pair and the part bar's start-bar hint. The curve canvas's `.accessibilityHint("…")`
        // and its two `.accessibilityAction(named:)` literals are LocalizedStringKey positions — units only.
        let automationHints = try codeOnly("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        // DAW shell S4a: the toggle and its label pair went — the Automation page of the track's
        // detail is the open row. Its absence is pinned; the two other E4-82 seams stand.
        XCTAssertFalse(automationHints.contains("Hide the selected track's automation"),
                       "the automation editor grew a switch again")
        for seam in ["hint: String(localized: \"Sets the picked point's value\"),",
                     ".accessibilityAction(named: \"Pick next point\") { onStep(1) }"] {
            XCTAssertTrue(automationHints.contains(seam), "SongAutomationEditor lost the E4-82 seam `\(seam)`")
        }
        XCTAssertFalse(automationHints.contains("                                           : \"Show the selected track's automation\")"),
                       "SongAutomationEditor spells the toggle label verbatim again")
        let stripStatus = try codeOnly("Sources/Echoelmusic/Studio/AutomationStatusStrip.swift")
        XCTAssertTrue(stripStatus.contains("? String(localized: \"Global curves move these parameters while the transport runs.\")"),
                      "AutomationStatusStrip lost the E4-82 seam")
        XCTAssertFalse(stripStatus.contains("                 ? \"Global curves move these parameters while the transport runs.\""),
                       "AutomationStatusStrip spells the status line verbatim again")
        let partBarHint = try codeOnly("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertTrue(partBarHint.contains("hint: String(localized: \"Moves the part to start on this bar; its place within the bar is kept.\"),"),
                      "SelectedPartBar lost the E4-82 seam")
        try assertCatalogued(["Sets the picked point's value",
                          "Pick next point", "Pick previous point",
                          "Double-tap adds or picks the point in the middle of the piece. Use the actions to pick another point; its value and Remove follow below.",
                          "Global curves move these parameters while the transport runs.",
                          "Off by default. Part and arrangement curves still play; this switch is for the global curves.",
                          "Moves the part to start on this bar; its place within the bar is kept."],
                         "automation editor, strip and part bar hints")

        // E4-83 — the Workstation's track-details hint pair and the three `?? "…"` fallbacks the import notes read
        // when a track has no name (the note itself is already assembled from keys), the Colabo invite's joining
        // pair, and the Studio caption's idle sentence (a `Text(cond ? "…" : caption.text)`, so the literal was a
        // String). No other guard pins these lines.
        let workstationFragments = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        for seam in [".accessibilityHint(selected ? String(localized: \"Closes this track's details\")",
                     "?? String(localized: \"the MIDI track\")",
                     "?? String(localized: \"the audio track\")"] {
            XCTAssertTrue(workstationFragments.contains(seam), "WorkstationView lost the E4-83 seam `\(seam)`")
        }
        XCTAssertFalse(workstationFragments.contains("?? \"the MIDI track\""), "WorkstationView spells a nameless-track fallback verbatim again")
        let colaboInvite = try codeOnly("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        XCTAssertTrue(colaboInvite.contains(": String(localized: \"Joining lets them share pieces with you.\")"), "LiveColaboView lost the E4-83 seam")
        XCTAssertFalse(colaboInvite.contains("                 : \"Joining lets them share pieces with you.\")"), "LiveColaboView spells the joining line verbatim again")
        let captionIdle = try codeOnly("Sources/Echoelmusic/Studio/StudioCaptionView.swift")
        XCTAssertTrue(captionIdle.contains("? String(localized: \"Every control shapes the music as it plays.\")"), "StudioCaptionView lost the E4-83 seam")
        try assertCatalogued(["Closes this track's details",
                          "Opens this track's details: its device, and its mixer and parts where it has them",
                          "the MIDI track", "the audio track",
                          "Joining lets them share pieces with you — and see your live pulse while sharing is on.",
                          "Joining lets them share pieces with you.", "Every control shapes the music as it plays."],
                         "workstation fragments, Colabo invite and caption idle line")

        // E4-84 — `LiveModOrigin.heading` (Core/FXModulation): three literals behind one `switch`, rendered by
        // `Text(modulator.liveOrigin.heading)` in the FX sheet and `Text(caption.driver.heading)` in the narration
        // leaf — a computed String, so a bare literal never reached the catalog. TheFXHeadersSayWhoseBodyTests pins
        // the English by VALUE (`XCTAssertEqual(…heading, "Live — …")`), which still holds: the test bundle runs
        // under en, where the unit's value is the key. Plus the degraded row's `?? "…"` fallback (the engine's own
        // sentence stays English — it is a cause string, not copy) and the four `NoteNaming.displayName` labels the
        // Picker renders through `Text(n.displayName)`.
        let fxOrigin = try codeOnly("Sources/Echoelmusic/Core/FXModulation.swift")
        for seam in ["case .noRoutes, .body: return String(localized: \"Live — body → sound\")",
                     "case .lfoOnly:         return String(localized: \"Live — LFO → sound\")",
                     "case .simulatedDemo:   return String(localized: \"Live — simulated demo → sound\")"] {
            XCTAssertTrue(fxOrigin.contains(seam), "FXModulation lost the E4-84 seam `\(seam)`")
        }
        XCTAssertFalse(fxOrigin.contains("        case .lfoOnly:         return \"Live — LFO → sound\""), "FXModulation spells a Live heading verbatim again")
        let degradedRow = try codeOnly("Sources/Echoelmusic/Studio/AudioDegradedRow.swift")
        XCTAssertTrue(degradedRow.contains("?? String(localized: \"Audio stopped and could not restart.\")"), "AudioDegradedRow lost the E4-84 seam")
        XCTAssertFalse(degradedRow.contains("?? \"Audio stopped and could not restart.\""), "AudioDegradedRow spells its fallback verbatim again")
        let noteSchemes = try codeOnly("Sources/Echoelmusic/Sequencer/NoteNaming.swift")
        for seam in ["case .english: return String(localized: \"A B C (International)\")",
                     "case .german:  return String(localized: \"A H C (Deutsch)\")",
                     "case .solfege: return String(localized: \"Do Re Mi (Solfège)\")",
                     "case .sargam:  return String(localized: \"Sa Re Ga (Sargam)\")"] {
            XCTAssertTrue(noteSchemes.contains(seam), "NoteNaming lost the E4-84 seam `\(seam)`")
        }
        XCTAssertFalse(noteSchemes.contains("        case .german:  return \"A H C (Deutsch)\""), "NoteNaming spells a scheme label verbatim again")
        try assertCatalogued(["Live — body → sound", "Live — LFO → sound", "Live — simulated demo → sound",
                          "Audio stopped and could not restart.",
                          "A B C (International)", "A H C (Deutsch)", "Do Re Mi (Solfège)", "Sa Re Ga (Sargam)"],
                         "FX Live headings, degraded fallback and note-name schemes")

        // E4-85 — `TuningSystem.library` (Sequencer/MicrotonalTuning): fifteen `name:` literals in a `static let`,
        // rendered by `Text(t.name)` in the WorkspaceView tone-system Picker and spoken through the tuning banner's
        // title. The `id`s persist (`toneSystemID`), the names never do — `TuningSystem.named(_:)` resolves by id, and
        // MicrotonalTuningTests pins ids and cents, never a name. Proper names (Ḥijāz, Sléndro) stay identical in de.
        let toneSystems = try codeOnly("Sources/Echoelmusic/Sequencer/MicrotonalTuning.swift")
        for seam in [".equal(12, id: \"edo12\", name: String(localized: \"12-TET (standard)\"))",
                     "TuningSystem(id: \"just-major\", name: String(localized: \"Just Intonation — Major\"),",
                     "TuningSystem(id: \"maqam-rast\", name: String(localized: \"Maqām Rāst (24-TET theoretic)\"),",
                     "TuningSystem(id: \"bohlen-pierce\", name: String(localized: \"Bohlen–Pierce (non-octave)\"),"] {
            XCTAssertTrue(toneSystems.contains(seam), "MicrotonalTuning lost the E4-85 seam `\(seam)`")
        }
        XCTAssertEqual(toneSystems.components(separatedBy: "name: String(localized: \"").count - 1, 15,
                       "TuningSystem.library carries 15 keyed names (4 equal temperaments + 4 just + 6 world + Bohlen–Pierce); re-derive if a system was added")
        XCTAssertFalse(toneSystems.contains("        .equal(12, id: \"edo12\", name: \"12-TET (standard)\"),"), "MicrotonalTuning spells a tone-system name verbatim again")
        try assertCatalogued(["12-TET (standard)", "24-TET (quarter tones)", "19-TET", "31-TET",
                          "Just Intonation — Major", "Just Intonation — Minor", "Pythagorean (diatonic)",
                          "1/4-comma Meantone (chromatic)", "Maqām Rāst (24-TET theoretic)", "Maqām Bayātī (24-TET theoretic)",
                          "Maqām Ḥijāz", "Gamelan Sléndro (≈5-EDO)", "Gamelan Pélog (representative)",
                          "Hirajōshi (Japanese pentatonic)", "Bohlen–Pierce (non-octave)"],
                         "tone-system names")

        // E4-86 — `VisualPreset.factory` blurbs (Studio/VisualPreset) and the two media-seed presets (Studio/
        // MediaSeedLook, `name: "From photo"` / `"From video"` plus their blurbs). The strip renders `Text(preset.name)`
        // and speaks `.accessibilityLabel(preset.name + String(localized: " visual preset — ") + preset.blurb)` (pinned
        // above, E4-41), so every blurb reaches VoiceOver. The five factory NAMES (Aura · Vapor · Bloom · Pulse ·
        // Zentrifuge) are proper names and stay bare — VisualPresetTests pins `first?.name == "Aura"`. `VisualPreset`
        // is not Codable; nothing persists a blurb.
        let visualBlurbs = try codeOnly("Sources/Echoelmusic/Studio/VisualPreset.swift")
        for seam in ["blurb: String(localized: \"soft, sparse, slow aura\")",
                     "blurb: String(localized: \"dreamy nostalgic vaporwave glow\")",
                     "blurb: String(localized: \"maximal — dense, fast, centrifugal\")"] {
            XCTAssertTrue(visualBlurbs.contains(seam), "VisualPreset lost the E4-86 seam `\(seam)`")
        }
        XCTAssertEqual(visualBlurbs.components(separatedBy: "blurb: String(localized: \"").count - 1, 5,
                       "VisualPreset.factory carries 5 keyed blurbs; re-derive if a preset was added")
        XCTAssertFalse(visualBlurbs.contains("                     spread: 1.35, blurb: \"soft, sparse, slow aura\"),"), "VisualPreset spells a blurb verbatim again")
        let seedLooks = try codeOnly("Sources/Echoelmusic/Studio/MediaSeedLook.swift")
        for seam in ["return VisualPreset(id: \"\", name: String(localized: \"From photo\"),",
                     "return VisualPreset(id: \"\", name: String(localized: \"From video\"),",
                     "blurb: String(localized: \"colour, brightness and contrast of a photo\")",
                     "blurb: String(localized: \"brightness, colour and picture change of a video\")"] {
            XCTAssertTrue(seedLooks.contains(seam), "MediaSeedLook lost the E4-86 seam `\(seam)`")
        }
        XCTAssertFalse(seedLooks.contains("        return VisualPreset(id: \"\", name: \"From photo\","), "MediaSeedLook spells a seed preset name verbatim again")
        try assertCatalogued(["soft, sparse, slow aura", "dreamy nostalgic vaporwave glow", "blossoming mid-density",
                          "heartbeat-forward", "maximal — dense, fast, centrifugal",
                          "From photo", "From video",
                          "colour, brightness and contrast of a photo", "brightness, colour and picture change of a video"],
                         "visual-preset blurbs and media-seed presets")

        // E4-87 — the Routing surface's port and converter names: `SignalRouter.defaultGraph` (Core/SignalRouter,
        // twelve `SignalPort(… name:)` literals) and `ConverterCatalog.default` (Core/SignalRouting, ten
        // `SignalConverter(… name:)` literals), rendered by `Text(src.name)` / `Text(dst.name)` and the converter chip
        // in PatchbayView. Only `graph.routes` persists (`SignalRouter.save()`); ports and converters are rebuilt from
        // code, so a keyed name reaches every install. The `id: "midi.in"` line keeps saying no "MPE"
        // (TheMPEInputHasNoZonesTests reads that LINE). Technical labels (MIDI In · OSC Out · Bio → MIDI CC) keep
        // identical German units on purpose.
        let routingPorts = try codeOnly("Sources/Echoelmusic/Core/SignalRouter.swift")
        for seam in ["SignalPort(id: \"bus.bio\",     name: String(localized: \"Body (bio)\"),",
                     "SignalPort(id: \"midi.in\",     name: String(localized: \"MIDI In\"),",
                     "SignalPort(id: \"blehrs.in\",   name: String(localized: \"Heart strap (BLE)\"),",
                     "SignalPort(id: \"adm.out\",     name: String(localized: \"ADM-OSC (spatial)\"),"] {
            XCTAssertTrue(routingPorts.contains(seam), "SignalRouter lost the E4-87 seam `\(seam)`")
        }
        XCTAssertEqual(routingPorts.components(separatedBy: "name: String(localized: \"").count - 1, 12,
                       "SignalRouter.defaultGraph carries 12 keyed port names; re-derive if a port was added")
        XCTAssertFalse(routingPorts.contains("            SignalPort(id: \"bus.bio\",     name: \"Body (bio)\","), "SignalRouter spells a port name verbatim again")
        let routingConverters = try codeOnly("Sources/Echoelmusic/Core/SignalRouting.swift")
        for seam in ["SignalConverter(id: \"bio→cc\",       name: String(localized: \"Bio → MIDI CC\"),",
                     "SignalConverter(id: \"music→light\",  name: String(localized: \"Pitch/Chord → Colour\"),",
                     "SignalConverter(id: \"macro→spatial\",name: String(localized: \"Macro → Spatial\"),"] {
            XCTAssertTrue(routingConverters.contains(seam), "SignalRouting lost the E4-87 seam `\(seam)`")
        }
        XCTAssertEqual(routingConverters.components(separatedBy: "name: String(localized: \"").count - 1, 10,
                       "ConverterCatalog.default carries 10 keyed converter names; re-derive if a converter was added")
        XCTAssertFalse(routingConverters.contains("        SignalConverter(id: \"bio→cc\",       name: \"Bio → MIDI CC\","), "SignalRouting spells a converter name verbatim again")
        try assertCatalogued(["Body (bio)", "Music", "MIDI In", "Heart strap (BLE)", "MIDI / MPE Out", "OSC Out",
                          "ADM-OSC (spatial)", "Art-Net (light)", "sACN (light)", "Audio master",
                          "Broadcast (RTMP)", "Broadcast (SRT)",
                          "Bio → MIDI CC", "Bio → Light", "Bio → Spatial object", "Bio → Macro",
                          "Pitch/Chord → Colour", "Pitch → Position", "Music → MIDI CC",
                          "Macro → MIDI CC", "Macro → Light", "Macro → Spatial"],
                         "routing port and converter names")

        // E4-88 — `TuningStatusText.title` (Studio/TuningStatusBanner): the banner renders `Text(title)`, a String, so
        // the three interpolated headlines never reached the catalog. The heads are keys now; the system name (keyed in
        // E4-85), the `EchoelDecimalText` Hz (DetunedInstrumentSaysSoTests pins that call) and the bare ", A4 = " /
        // " Hz" are operands, so no key carries a `%@`. The English is byte-identical — nothing compares it at runtime.
        let tuningBanner = try codeOnly("Sources/Echoelmusic/Studio/TuningStatusBanner.swift")
        for seam in ["let lead: String = String(localized: \"Non-standard tuning: \") + systemName",
                     "case (true, false):  return String(localized: \"Non-standard tuning: \") + systemName",
                     "let pitch: String = String(localized: \"Non-standard concert pitch: A4 = \") + hz"] {
            XCTAssertTrue(tuningBanner.contains(seam), "TuningStatusBanner lost the E4-88 seam `\(seam)`")
        }
        XCTAssertFalse(tuningBanner.contains("        case (false, true):  return \"Non-standard concert pitch: A4 = "), "TuningStatusBanner interpolates its headline into one literal again")
        try assertCatalogued(["Non-standard tuning: ", "Non-standard concert pitch: A4 = "], "tuning banner headline")

        // E4-89 — modifier titles. `.alert("Save piece")`, `.alert("Save mood")`, `.alert("Save sound")`,
        // `.navigationTitle("Open piece")` (EchoelStudioView), `.navigationTitle("Recovery")` (SafeModeView) and
        // `.navigationTitle("EchoelFX")` (EchoelFXView, a brand name with an identical unit) were already keys; they had
        // no `de` unit because claim 10's walk only listed view constructors. The sources are unchanged — the seams
        // below pin the sites the units serve; claim 10 now walks these modifiers for the whole panel family.
        let modifierTitles = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in [".alert(\"Save piece\", isPresented: $showSaveDialog)",
                     ".alert(\"Save mood\", isPresented: $showSaveMoodAs)",
                     ".alert(\"Save sound\", isPresented: $showSavePatchAs)",
                     ".navigationTitle(\"Open piece\")"] {
            XCTAssertTrue(modifierTitles.contains(seam), "EchoelStudioView lost the E4-89 site `\(seam)`")
        }
        let recoveryTitle = try codeOnly("Sources/Echoelmusic/Studio/SafeModeView.swift")
        XCTAssertTrue(recoveryTitle.contains(".navigationTitle(\"Recovery\")"), "SafeModeView lost the E4-89 site")
        try assertCatalogued(["Save piece", "Save mood", "Save sound", "Open piece", "Recovery", "EchoelFX"],
                         "modifier titles")

        // E4-90 — the arrange canvas speaks a track as name + hearing state (`ArrangeCanvas.spokenState`) and each
        // part as that + ", part at " + the bar; the header's place line reads "<track> · part at bar <n>". All three
        // were String positions (an accessibility label, a `label:` argument, a returned String), so the English
        // shipped verbatim. The fragments are keys now; the names and the bar number are operands.
        let hearingCanvas = try codeOnly("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        for seam in ["case .muted:          return String(localized: \", muted\")",
                     "case .soloed:         return String(localized: \", soloed\")",
                     "case .silencedBySolo: return String(localized: \", silent while another track is soloed\")",
                     "label: spokenName + String(localized: \", part at \") + SessionGrid.label(forTick: start),"] {
            XCTAssertTrue(hearingCanvas.contains(seam), "ArrangeCanvasView lost the E4-90 seam `\(seam)`")
        }
        XCTAssertFalse(hearingCanvas.contains("label: \"\\(spokenName), part at \""), "the canvas part label is one verbatim literal again")
        let headerPlace = try codeOnly("Sources/Echoelmusic/Studio/ProjectTransport.swift")
        XCTAssertTrue(headerPlace.contains("return lane.name + String(localized: \" · part at bar \") + \"\\(bar)\""), "the header's place line lost its E4-90 key")
        XCTAssertFalse(headerPlace.contains("return \"\\(lane.name) · part at bar"), "the header's place line is one verbatim literal again")
        // RUNTIME COUNTERWEIGHT: the bundle's English is unchanged.
        XCTAssertEqual(ArrangeCanvas.spokenState(.muted), ", muted")
        try assertCatalogued([", muted", ", soloed", ", silent while another track is soloed", " · part at bar ", ", part at "],
                         "canvas hearing and place fragments")

        // E4-91 — the note editor's switch (since S4a its heading) speaks its count as `.accessibilityValue(spokenCount)` and a stepped pick
        // is announced as "<note> at step <n>, selected"; the record row names a track without a name "A track" in the
        // foreign-arm sentence. All three were String positions. The words are keys now (the count reuses the grid
        // label's "note"/"notes"); the note name and the numbers are operands.
        let noteCountEditor = try codeOnly("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        for seam in ["let word: String = n == 1 ? String(localized: \"note\") : String(localized: \"notes\")",
                     "let named: String = TuningReference.noteName(forMIDINote: note.pitch) + String(localized: \" at step \") + \"\\(step)\"",
                     "AccessibilityNotification.Announcement(named + String(localized: \", selected\")).post()"] {
            XCTAssertTrue(noteCountEditor.contains(seam), "PartNoteEditor lost the E4-91 seam `\(seam)`")
        }
        for verbatim in ["$0 == 1 ? \"1 note\" :", "at step \\(step), selected\""] {
            XCTAssertFalse(noteCountEditor.contains(verbatim), "PartNoteEditor speaks a count or a pick verbatim again: `\(verbatim)`")
        }
        let foreignTrack = try codeOnly("Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        for seam in ["?.name ?? String(localized: \"A track\")"] {
            XCTAssertTrue(foreignTrack.contains(seam), "RecordTakeControls lost the E4-91 seam `\(seam)`")
        }
        for verbatim in ["?.name ?? \"A track\""] {
            XCTAssertFalse(foreignTrack.contains(verbatim), "RecordTakeControls names an unnamed track verbatim again")
        }
        try assertCatalogued([" at step ", ", selected", "A track", "note", "notes"], "note count, step pick and unnamed track")

        // E4-92 — `EchoelValueField.accessibleValue` spoke "<n> hertz / seconds / beats per minute" as interpolated
        // Strings, `BodyTempoField.followingSpoken` the same for the following tempo, and the touch surface (a UIKit
        // view) set its `accessibilityLabel` / `accessibilityHint` to plain Strings. The words are keys now; the
        // number stays the operand, formatted once (TempoReadsAsAMeasurementTests counts exactly two
        // `followingValue` formattings — the spoken line still holds one). The unit keys already had German units.
        let spokenUnits = try codeOnly("Sources/Echoelmusic/Studio/EchoelValueField.swift")
        for seam in ["case \"Hz\":  return n + String(localized: \" hertz\")",
                     "case \"s\":   return n + String(localized: \" seconds\")",
                     "case \"BPM\": return n + String(localized: \" beats per minute\")"] {
            XCTAssertTrue(spokenUnits.contains(seam), "EchoelValueField lost the E4-92 seam `\(seam)`")
        }
        for verbatim in ["return \"\\(n) hertz\"", "return \"\\(n) seconds\"", "return \"\\(n) beats per minute\""] {
            XCTAssertFalse(spokenUnits.contains(verbatim), "EchoelValueField speaks a unit verbatim again: `\(verbatim)`")
        }
        let followingTempo = try codeOnly("Sources/Echoelmusic/Studio/BodyTempoField.swift")
        for seam in ["EchoelDecimalText.string(followingValue, decimals: 1) + String(localized: \" beats per minute\")"] {
            XCTAssertTrue(followingTempo.contains(seam), "BodyTempoField lost the E4-92 seam `\(seam)`")
        }
        for verbatim in [", decimals: 1)) beats per minute\""] {
            XCTAssertFalse(followingTempo.contains(verbatim), "BodyTempoField speaks the following tempo verbatim again")
        }
        let fieldSurface = try codeOnly("Sources/Echoelmusic/Studio/TouchInstrumentView.swift")
        for seam in ["accessibilityLabel = String(localized: \"Field play surface\")",
                     "accessibilityHint = String(localized: \"Touch and slide to play notes in the current key\")"] {
            XCTAssertTrue(fieldSurface.contains(seam), "TouchInstrumentView lost the E4-92 seam `\(seam)`")
        }
        for verbatim in ["accessibilityLabel = \"Field play surface\"", "accessibilityHint = \"Touch and slide"] {
            XCTAssertFalse(fieldSurface.contains(verbatim), "TouchInstrumentView sets a VoiceOver string verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Field play surface", "Touch and slide to play notes in the current key",
                          " hertz", " seconds", " beats per minute"], "spoken units and the touch surface")

        // E4-93 — `EchoelValueField.hint` is a `String`, so a literal passed to it is NOT a catalog key and shipped
        // English in every locale. The track inspector's instrument hint (a `static let` the menu reads), both arms of
        // the level hint and the pan hint, and the Bar variation hint go through `String(localized:)` now. The runtime
        // English is unchanged (TheTrackChoosesItsInstrumentTests reads `TrackMix.instrumentHint`).
        let inspectorFieldHints = try codeOnly("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        for seam in ["String(localized: \"The voice this track plays its parts with. ",
                     "? String(localized: \"1.00 unchanged, 0 silent. This is also the level",
                     ": String(localized: \"1.00 unchanged, 0 silent, 2.00 is +6 dB\")",
                     "hint: String(localized: \"−1 left, 0 centre, 1 right\")"] {
            XCTAssertTrue(inspectorFieldHints.contains(seam), "TrackInspectorView lost the E4-93 seam `\(seam)`")
        }
        for verbatim in ["instrumentHint =\n        \"The voice", "? \"1.00 unchanged", "\"1.00 unchanged, 0 silent, 2.00 is +6 dB\",",
                         "hint: \"−1 left"] {
            XCTAssertFalse(inspectorFieldHints.contains(verbatim), "TrackInspectorView passes a hint verbatim again: `\(verbatim)`")
        }
        let variationHint = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["hint: String(localized: \"How far each bar of the loop may drift from the genre preset\")"] {
            XCTAssertTrue(variationHint.contains(seam), "EchoelStudioView lost the E4-93 seam `\(seam)`")
        }
        for verbatim in ["hint: \"How far each bar"] {
            XCTAssertFalse(variationHint.contains(verbatim), "EchoelStudioView passes the Bar variation hint verbatim again")
        }
        XCTAssertTrue(TrackMix.instrumentHint.hasPrefix("The voice this track plays its parts with."),
                      "the instrument hint must still read its English source under the test locale")
        try assertCatalogued(["The voice this track plays its parts with. EchoelBass and EchoelBodyVibe each play one track at a time, the higher one in the list; another track that picks one plays EchoelSynth. A track on EchoelBodyVibe cannot be armed to record MIDI",
                          "1.00 unchanged, 0 silent. This is also the level the Studio instrument plays at; its Start lifts 0 back to 1.00",
                          "1.00 unchanged, 0 silent, 2.00 is +6 dB", "−1 left, 0 centre, 1 right",
                          "How far each bar of the loop may drift from the genre preset"], "value-field hints")

        // E4-94 — `headerSwitch(_:name:…)` and `mixSwitch(_:track:…)` take the switch name as a `String` (it feeds
        // `accessibilityLabel`, the Voice Control input labels and, on the Perform plate, the visible word), so the
        // literal "Mute" / "Solo" shipped English. The Workstation row's printed detail line and its MUTE / SOLO / ARM
        // tags were String appends of the same kind. The letters M and S stay — they are the DAW convention, not words.
        let rowWords = try codeOnly("Sources/Echoelmusic/Studio/WorkstationView.swift")
        for seam in ["headerSwitch(\"M\", name: String(localized: \"Mute\"), on:",
                     "headerSwitch(\"S\", name: String(localized: \"Solo\"), on:",
                     "text += String(localized: \" · bio curve\")", "text += String(localized: \" · no parts\")",
                     "text += String(localized: \" · 1 part\")", "regionCount) \" + String(localized: \"parts\")",
                     "text += String(localized: \" · no engine yet\")",
                     "tags.append(String(localized: \"MUTE\"))", "tags.append(String(localized: \"SOLO\"))",
                     "tags.append(String(localized: \"ARM\"))"] {
            XCTAssertTrue(rowWords.contains(seam), "WorkstationView lost the E4-94 seam `\(seam)`")
        }
        for verbatim in ["name: \"Mute\"", "name: \"Solo\"", "text += \" · bio curve\"", "text += \" · no parts\"",
                         "text += \" · 1 part\"", "regionCount) parts\"", "text += \" · no engine yet\"",
                         "tags.append(\"MUTE\")", "tags.append(\"SOLO\")", "tags.append(\"ARM\")"] {
            XCTAssertFalse(rowWords.contains(verbatim), "WorkstationView writes a row word verbatim again: `\(verbatim)`")
        }
        let plateSwitches = try codeOnly("Sources/Echoelmusic/Studio/PerformSessionView.swift")
        for seam in ["mixSwitch(String(localized: \"Mute\"), track: row.name,",
                     "mixSwitch(String(localized: \"Solo\"), track: row.name,"] {
            XCTAssertTrue(plateSwitches.contains(seam), "PerformSessionView lost the E4-94 seam `\(seam)`")
        }
        for verbatim in ["mixSwitch(\"Mute\"", "mixSwitch(\"Solo\""] {
            XCTAssertFalse(plateSwitches.contains(verbatim), "PerformSessionView names a switch verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Mute", "Solo", " · bio curve", " · no parts", " · 1 part", "parts", " · no engine yet",
                          "MUTE", "SOLO", "ARM"], "track switches, row details and state tags")

        // E4-95 — four `static let` sentences of the instrument (`newPieceNote`, `newPieceRefusedNote`, `libraryRowHint`,
        // `saveHint`) were String literals read by `Text(_:)` / `.accessibilityHint(_:)`, i.e. verbatim. The timbre-words
        // hint keeps "very" / "slightly" verbatim (they are what `SoundPrompt` parses) and keys the sentence around them —
        // a key may not carry a `"` because StringCatalogIsHonestTests finds every key as a quoted literal. The mood and
        // sound rows spoke "<name>, favorite" by interpolation; one free helper speaks it now.
        let pieceNotes = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["static let newPieceNote = String(localized: \"Starts an empty piece",
                     "static let newPieceRefusedNote = String(localized: \"Couldn't start a new piece.",
                     "static let libraryRowHint = String(localized: \"Opens this piece in place of the one you have now.\")",
                     "static let saveHint = String(localized: \"Renames this piece.",
                     "let lead: String = String(localized: \"Words like warm",
                     "let tail: String = String(localized: \"scale the next word.\")",
                     "return String(localized: \"Shapes: \") + terms.joined(",
                     "return name + String(localized: \", favorite\")",
                     "accessibilityValue(spokenPresetName(moodPresetName,",
                     "accessibilityValue(spokenPresetName(currentPatch.name,"] {
            XCTAssertTrue(pieceNotes.contains(seam), "EchoelStudioView lost the E4-95 seam `\(seam)`")
        }
        for verbatim in ["static let newPieceNote = \"", "static let newPieceRefusedNote = \"", "static let libraryRowHint = \"",
                         "static let saveHint = \"", "return \"Words like warm", "return \"Shapes: \"", "), favorite\""] {
            XCTAssertFalse(pieceNotes.contains(verbatim), "EchoelStudioView writes a piece note verbatim again: `\(verbatim)`")
        }
        XCTAssertTrue(EchoelStudioView.newPieceRefusedNote.contains("unchanged"),
                      "counterweight: the refused note still reads its English source under the test locale")
        try assertCatalogued(["Starts an empty piece and shows the piece stage. A piece with parts or a composed loop is kept in Autosave first; tracks with no parts yet are not. The instrument keeps its sound.",
                          "Couldn't start a new piece. Your piece is unchanged.",
                          "Opens this piece in place of the one you have now.",
                          "Renames this piece. Its place in the list and its saved time stay.",
                          "Words like warm · bright · plucky · pad · evolving · huge shape the timbre from where it is now. ",
                          "scale the next word.", "Shapes: ", ", favorite"], "piece notes, timbre words and favourites")

        // E4-96 — `OnboardingView.consentHint` was a `+` chain of three String literals passed to
        // `.accessibilityHint(_:)`'s `StringProtocol` overload, i.e. English in every locale — on the screen that carries
        // the mandated safety notice. It is two catalog fragments now, still bound to a `String` property.
        let consent = try codeOnly("Sources/Echoelmusic/Views/OnboardingView.swift")
        for seam in ["private static let consentHint: String =",
                     "String(localized: \"Confirms you have read the safety and privacy notice above: \")",
                     "+ String(localized: \"for self-observation, not medical diagnosis; not while driving or under the influence; visuals capped at 3 hertz.\")",
                     ".accessibilityHint(Self.consentHint)"] {
            XCTAssertTrue(consent.contains(seam), "OnboardingView lost the E4-96 seam `\(seam)`")
        }
        for verbatim in ["\"Confirms you have read the safety and privacy notice above: for self-observation, \"",
                         "+ \"not medical diagnosis; not while driving", "+ \"at 3 hertz.\""] {
            XCTAssertFalse(consent.contains(verbatim), "OnboardingView speaks the consent hint verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Confirms you have read the safety and privacy notice above: ",
                          "for self-observation, not medical diagnosis; not while driving or under the influence; visuals capped at 3 hertz."],
                         "onboarding consent hint")

        // E4-97 — `BioSourceOption.shortName` is the source row's current value: `Text(current.shortName)` and
        // `.accessibilityValue(current.shortName)`, both `StringProtocol` overloads. E4-72 keyed `menuLabel` in the same
        // file and left this switch bare, so the row read "Camera light" under a German menu.
        let sourceShortNames = try codeOnly("Sources/Echoelmusic/Studio/BioSourceOption.swift")
        for seam in ["case .camera: return String(localized: \"Camera light\")",
                     "case .ble:    return String(localized: \"Bluetooth strap\")",
                     "case .sim:    return String(localized: \"Simulation\")",
                     "case .health: return String(localized: \"Apple Health\")"] {
            XCTAssertTrue(sourceShortNames.contains(seam), "BioSourceOption lost the E4-97 seam `\(seam)`")
        }
        for verbatim in ["case .camera: return \"Camera light\"", "case .ble:    return \"Bluetooth strap\"",
                         "case .sim:    return \"Simulation\""] {
            XCTAssertFalse(sourceShortNames.contains(verbatim), "BioSourceOption spells a short name verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["Camera light", "Bluetooth strap", "Simulation", "Apple Health"], "bio-source short names")

        // E4-98 — the floating window's VoiceOver rotor actions were `Button(corner.rawValue)`, a bare String, so the
        // StringProtocol overload shipped "Move to top left" etc. in every locale. The names keep their ONE definition as
        // `SnapCorner` rawValues (TheFloatingWindowMovesWithoutADragTests); the view looks each one up as a catalog key.
        let cornerActions = try codeOnly("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        XCTAssertTrue(cornerActions.contains("Button(String(localized: String.LocalizationValue(corner.rawValue))) {"),
                      "FloatingVisualWindow lost the E4-98 seam: the corner actions no longer look their name up")
        XCTAssertFalse(cornerActions.contains("Button(corner.rawValue) {"),
                       "FloatingVisualWindow speaks the corner actions verbatim again")
        try assertCatalogued(FloatingVisualLayout.SnapCorner.allCases.map(\.rawValue), "floating-window corner actions")

        // E4-99 — `PatchbayView.outputRow(_ name: String, …)` hands `name` to `NetworkOutputHeader`, which renders it with
        // `Text(name)` and speaks it with `.accessibilityLabel(name)` — both StringProtocol overloads. The two light rows now
        // pass a lookup. "OSC" and "ADM-OSC" stay bare on purpose: protocol names, identical in German.
        let outputNames = try codeOnly("Sources/Echoelmusic/Studio/PatchbayView.swift")
        for seam in ["outputRow(String(localized: \"sACN · Light\"), sender: sacn,",
                     "outputRow(String(localized: \"Art-Net · Light\"), sender: artNet,"] {
            XCTAssertTrue(outputNames.contains(seam), "PatchbayView lost the E4-99 seam `\(seam)`")
        }
        for verbatim in ["outputRow(\"sACN · Light\"", "outputRow(\"Art-Net · Light\""] {
            XCTAssertFalse(outputNames.contains(verbatim), "PatchbayView names a light output verbatim again: `\(verbatim)`")
        }
        try assertCatalogued(["sACN · Light", "Art-Net · Light"], "routing light output names")

        // E4-100 — `menuChip` drew `Text(menu.label)`, a String, so the chips (nine since slice F) read English under German help text that
        // already names them in German (E4-69). The `label` switch keeps its bare literals on purpose:
        // TheDeployNoteNamesRealDoorsTests parses them as the shipped English names. The KEY is looked up where it is drawn.
        let chipStrip = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(chipStrip.contains("Text(LocalizedStringKey(menu.label))"),
                      "EchoelStudioView lost the E4-100 seam: the chip strip draws its label as a String again")
        XCTAssertFalse(chipStrip.contains("Text(menu.label)"), "EchoelStudioView draws a chip label verbatim again")
        try assertCatalogued(["Bio", "Tempo", "Sound", "Mix", "FX", "Master", "Mood", "Save/Export", "Field"],
                         "instrument chip labels")
        // Slice F — the Workstation chip, its plate and its spoken name are retired, and so are their catalog
        // entries: a German unit nobody looks up is the orphan StringCatalogIsHonestTests forbids, and keeping one
        // "for later" is how a retired door stays translated while nothing opens it.
        let retiredStrings = try catalogStrings()
        for key in ["Workstation", "The arrangement is the Piece stage",
                    "Tracks, parts and scenes live on the Piece stage, above the instrument.", "Show the piece",
                    "Adds FX, Mix, Tempo, Field and the Workstation."] {
            XCTAssertNil(retiredStrings[key], "the catalog still carries `\(key)` — slice F retired the surface that drew it")
        }
        XCTAssertNil(retiredStrings.keys.first(where: { $0.hasPrefix("Workstation — the arrangement") }),
                     "the catalog still carries the retired Workstation chip's spoken name")
        XCTAssertNotNil(catalogued("Adds FX, Mix, Tempo and Field.", in: retiredStrings),
                        "counterweight: the Producer blurb that replaced the retired one is in the catalog with its English unit only")

        // E4-101 — `fieldMotionLabel` returned bare literals and the Motion picker drew them through `Text(String)`, so a
        // German field read "Rise"/"Pendulum"/"Hold" under a German "Bewegung" heading. The lookup sits in the helper;
        // `FieldAutoPlay.Motion` rawValues are persisted and untouched. "Drift" and "Arp" keep their word in German.
        let motionNames = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["case .rise:     return String(localized: \"Rise\")",
                     "case .pendulum: return String(localized: \"Pendulum\")",
                     "case .hold:     return String(localized: \"Hold\")"] {
            XCTAssertTrue(motionNames.contains(seam), "EchoelStudioView lost the E4-101 seam: \(seam)")
        }
        for verbatim in ["case .rise:     return \"Rise\"",
                         "case .pendulum: return \"Pendulum\"",
                         "case .hold:     return \"Hold\""] {
            XCTAssertFalse(motionNames.contains(verbatim), "EchoelStudioView returns a motion name verbatim again: \(verbatim)")
        }
        try assertCatalogued(["Rise", "Fall", "Pendulum", "Drift", "Hold", "Arp"], "field self-play motion names")

        // E4-102 — the meter picker drew `m.label` as a String, so the four segments read English beside the German
        // "Bild" button in the same header. `label` keeps its English values: TheMetersLiveInTheVisualWindowTests
        // asserts `pulse.label == "Pulse"` at runtime. The key is looked up at the one place that draws it.
        let meterPicker = try codeOnly("Sources/Echoelmusic/Studio/VisualAnalysisMeter.swift")
        XCTAssertTrue(meterPicker.contains("Text(LocalizedStringKey(m.label))"),
                      "VisualAnalysisMeter lost the E4-102 seam: the meter picker draws its label as a String again")
        XCTAssertFalse(meterPicker.contains("Text(m.label)"), "VisualAnalysisMeter draws a meter label verbatim again")
        try assertCatalogued(["Waves", "Spectrum", "Scope", "Pulse"], "visual window meter names")

        // E4-103 — `LoopExporter.tooLongMessage` built the "too long for the capture buffer" reason as one interpolated
        // String, so E4-55's `.failed(String(localized:))` sweep never saw it and the export row read English. The bar
        // count and `LoopBarLength.label` (already keyed, E4-62) stay operands; the English wording is unchanged.
        let tooLongReason = try codeOnly("Sources/Echoelmusic/Audio/LoopExporter.swift")
        for seam in ["String(localized: \"bars is longer than the 30 s capture buffer\")",
                     "String(localized: \" — use Record instead\")",
                     "String(localized: \" at this tempo — keep \")",
                     "String(localized: \" or fewer, or use Record instead\")"] {
            XCTAssertTrue(tooLongReason.contains(seam), "LoopExporter lost the E4-103 seam: \(seam)")
        }
        for verbatim in ["capture buffer — use Record instead", "capture buffer at this tempo"] {
            XCTAssertFalse(tooLongReason.contains(verbatim), "LoopExporter builds the too-long reason verbatim again: \(verbatim)")
        }
        try assertCatalogued(["bars is longer than the 30 s capture buffer", " — use Record instead", " at this tempo — keep ",
                          " or fewer, or use Record instead"], "exporter too-long reason")

        // E4-104 — the "Body → parameter" card draws `ModDestinationKey.displayName` as a plain String (its Add-route
        // Button and the destination Picker row), so every synth parameter read English. The registry descriptor keeps
        // its English literal — persisted and searched — and the lookup happens at the one function both sites call.
        let routeTargets = try codeOnly("Sources/Echoelmusic/Core/ModulationEngine.swift")
        for seam in ["return String(localized: String.LocalizationValue(d.displayName))"] {
            XCTAssertTrue(routeTargets.contains(seam), "ModDestinationKey lost the E4-104 seam: \(seam)")
        }
        for verbatim in ["            return d.displayName\n"] {
            XCTAssertFalse(routeTargets.contains(verbatim), "ModDestinationKey returns the English descriptor name verbatim again")
        }
        try assertCatalogued(["Warmth drive", "Envelope attack", "Envelope decay", "Envelope sustain", "Envelope release",
                          "Amplitude", "Harmonicity", "Noise level", "Vibrato depth", "Vibrato rate", "Brightness"],
                         "routing card parameter names")

        // E4-105 — the automation names were drawn as plain Strings: the curve editor's title (`Text(title)`), its parameter
        // picker rows, and the status strip's `Text(row.displayName)`, all fed by `AutomationScale` or the descriptor. The
        // lookup now happens where the name is built; the enum and the registry keep their English literals.
        let automationNames = try codeOnly("Sources/Echoelmusic/Sequencer/AutomationStatus.swift")
            + codeOnly("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        for seam in ["displayName: String(localized: String.LocalizationValue(target.displayName))",
                     "displayName: String(localized: String.LocalizationValue(descriptor.displayName))",
                     "String(localized: String.LocalizationValue(d.displayName))",
                     "?? String(localized: \"Track\")",
                     "let title = descriptor.map(SongAutomationEdit.name) ?? base",
                     "SongAutomationEdit.name(d) + String(localized: \" · curve\")"] {
            XCTAssertTrue(automationNames.contains(seam), "the automation names lost the E4-105 seam: \(seam)")
        }
        for verbatim in ["self.init(displayName: target.displayName,", "self.init(displayName: descriptor.displayName,",
                         "let title = descriptor?.displayName ?? base", "· \\(d.displayName)\"", "\\(d.displayName) · curve"] {
            XCTAssertFalse(automationNames.contains(verbatim), "an automation name is drawn verbatim again: \(verbatim)")
        }
        try assertCatalogued(["Master Level", "Oscillator frequency", "Filter cutoff", "Look intensity", "Track", " · curve"],
                         "automation names")

        // E4-106 — the "Audio latency" segmented picker drew `mode.shortName` as a plain String, so the three tiers read
        // "Ultra / Low / Normal" on a German phone. `shortName` keeps its bare literals: the refusal breadcrumb writes
        // them into the exported diag log, which stays English.
        let latencyTiers = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["Text(LocalizedStringKey(mode.shortName)).tag(Optional(mode))"] {
            XCTAssertTrue(latencyTiers.contains(seam), "the buffer-tier picker lost the E4-106 seam: \(seam)")
        }
        for verbatim in ["Text(mode.shortName).tag(Optional(mode))"] {
            XCTAssertFalse(latencyTiers.contains(verbatim), "the buffer-tier picker draws its names verbatim again")
        }
        try assertCatalogued(["Ultra", "Low", "Normal"], "buffer tier names")

        // E4-107 — `AudioDegradedRow` renders `lastAudioError` verbatim, and the engine built all three failure
        // sentences as interpolated English. The fixed parts are catalog lookups now; the diag `reason`/`context`
        // token and the system's own `localizedDescription` stay operands.
        let engineFailure = try codeOnly("Sources/Echoelmusic/Audio/AudioEngine.swift")
        for seam in ["lastAudioError = String(localized: \"Audio stopped (\") + reason",
                     "+ String(localized: \") and auto-recovery gave up.\")",
                     "lastAudioError = String(localized: \"Audio engine could not start: \")",
                     "lastAudioError = String(localized: \"Audio stopped (\") + context",
                     "+ String(localized: \") and could not restart: \") + error.localizedDescription"] {
            XCTAssertTrue(engineFailure.contains(seam), "the engine failure sentences lost the E4-107 seam: \(seam)")
        }
        for verbatim in ["lastAudioError = \"Audio stopped (", "lastAudioError = \"Audio engine could not start"] {
            XCTAssertFalse(engineFailure.contains(verbatim), "an engine failure sentence is built verbatim again: \(verbatim)")
        }
        try assertCatalogued(["Audio stopped (", ") and auto-recovery gave up.", "Audio engine could not start: ",
                          ") and could not restart: "], "engine failure sentences")

        // E4-108 — `LiveColaboView` renders `colab.status` verbatim; every status line was a catalog lookup but
        // the join request, built by interpolation. It takes the invitation card's key now.
        let colabStatus = try codeOnly("Sources/Echoelmusic/Sync/MultipeerSession.swift")
        for seam in ["status = name + String(localized: \" wants to join\")"] {
            XCTAssertTrue(colabStatus.contains(seam), "the Live Colabo status lost the E4-108 seam: \(seam)")
        }
        for verbatim in ["status = \"\\(name) wants to join\""] {
            XCTAssertFalse(colabStatus.contains(verbatim), "the join status is built verbatim again")
        }
        try assertCatalogued([" wants to join"], "Live Colabo join status")

        // E4-109 — two `.accessibilityLabel("…")` literals were already keys, but their units were never written:
        // the scan that looked for them anchored `\b` before `.accessibilityLabel`, which cannot match after a
        // space, so every modifier literal went unseen. VoiceOver read the Poincaré plot and the dismiss cross
        // in English.
        let poincareLabel = try codeOnly("Sources/Echoelmusic/Studio/AnalysisPoincareView.swift")
        for seam in [".accessibilityLabel(\"Poincaré plot\")"] {
            XCTAssertTrue(poincareLabel.contains(seam), "the Poincaré plot lost its E4-109 label key: \(seam)")
        }
        let incomingCard = try codeOnly("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        for seam in [".accessibilityLabel(\"Dismiss\")"] {
            XCTAssertTrue(incomingCard.contains(seam), "the incoming-piece card lost its E4-109 label key: \(seam)")
        }
        try assertCatalogued(["Poincaré plot", "Dismiss"], "VoiceOver labels on modifier literals")

        // E4-110 — the visual window's recording badge tells the performer the take broke ("WAV FAILED") or has a
        // hole ("WAV GAP 1.2s"). Both are words, not tokens: the first is a key and lacked its unit, the second was
        // interpolated. Claim 10 now walks "WAV FAILED" too, since it left the untranslated set.
        let wavBadge = try codeOnly("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        for seam in ["Text(\"WAV FAILED\")", "Text(String(localized: \"WAV GAP \")"] {
            XCTAssertTrue(wavBadge.contains(seam), "the recording badge lost its E4-110 seam: \(seam)")
        }
        for verbatim in ["Text(\"WAV GAP \\("] {
            XCTAssertFalse(wavBadge.contains(verbatim), "the gap badge is interpolated again")
        }
        try assertCatalogued(["WAV FAILED", "WAV GAP "], "recording fault badges")

        // E4-111 — two `Text(String)` sites in the instrument: the mood menu shows `moodPresetName`, which starts
        // and resets to "Custom", and the master Tone picker drew `AutoMixChain.Preset.displayName` verbatim. The
        // sentinel is a lookup now and the picker looks its names up; the raw values stay persistence tokens.
        let masterTone = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["@State private var moodPresetName = String(localized: \"Custom\")",
                     "moodPresetName = String(localized: \"Custom\")",
                     "Text(LocalizedStringKey(p.displayName)).tag(p.rawValue)"] {
            XCTAssertTrue(masterTone.contains(seam), "the mood menu or Tone picker lost its E4-111 seam: \(seam)")
        }
        for verbatim in ["moodPresetName = \"Custom\"", "Text(p.displayName).tag(p.rawValue)"] {
            XCTAssertFalse(masterTone.contains(verbatim), "a mood or Tone name is drawn verbatim again: \(verbatim)")
        }
        try assertCatalogued(["Custom"] + AutoMixChain.Preset.allCases.map(\.displayName), "mood default and Tone names")

        // E4-112 — the Sound panel's two named timbre pickers drew `EchoelDDSP.SpectralShape` and `NoiseColor` raw
        // values verbatim. They look the names up at the render site now; the raw values stay the patch tokens.
        let timbreNames = try codeOnly("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for seam in ["Text(LocalizedStringKey(shape.rawValue)).tag(shape.rawValue)",
                     "Text(LocalizedStringKey(colour.rawValue)).tag(colour.rawValue)"] {
            XCTAssertTrue(timbreNames.contains(seam), "a timbre picker lost its E4-112 seam: \(seam)")
        }
        for verbatim in ["Text(shape.rawValue)", "Text(colour.rawValue)"] {
            XCTAssertFalse(timbreNames.contains(verbatim), "a timbre name is drawn verbatim again: \(verbatim)")
        }
        try assertCatalogued(EchoelDDSP.SpectralShape.allCases.map(\.rawValue)
                         + EchoelDDSP.NoiseColor.allCases.map(\.rawValue), "spectral shape and noise colour names")
    }

    // MARK: - claim 12 (E4-10) — every value-field label has a German unit

    /// SOURCE-TEXT SCAN + END-TO-END on `WeatherMood.Param`. `EchoelValueField` draws `label` as a
    /// catalog KEY since E4-10 (three sites: the two `Text` branches and the VoiceOver label; the
    /// number pad's title is the localised String). That is what makes walking its literal labels
    /// meaningful: the direct `EchoelValueField(label: "…")` sites app-wide (a `cond ? "a" : "b"`
    /// label counts both arms), the instrument's `param`/`knob`/`moodKnob` pass-throughs and the FX
    /// panel's `field("…")` helper. The weather mixers reach the field through `param.label`, so
    /// those eight are driven on the enum itself.
    func testEveryValueFieldLabelIsCatalogued() throws {
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
                    if seen.insert(key).inserted, catalogued(key, in: strings) == nil { missing.append(key) }
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
            \(missing.count) value-field label(s) not English-only in the catalog — add the key (en unit only) for each:
            \(missing.joined(separator: "\n"))
            """)
        for p in WeatherMood.Param.allCases {
            XCTAssertNotNil(catalogued(p.label, in: strings), "weather mixer label \"\(p.label)\" is not an English-only catalog key")
        }
    }

    // MARK: - claim 5 — the chrome's "Piece" is the glossary's word, read from the glossary

    func testTheEnglishPieceIsTheGlossaryWord() throws {
        let glossary = try repoRoot().appendingPathComponent("docs/dev/GLOSSARY.md")
        guard let text = try? String(contentsOf: glossary, encoding: .utf8),
              let row = text.split(separator: "\n").first(where: { $0.hasPrefix("| piece |") }) else {
            throw XCTSkip("docs/dev/GLOSSARY.md has no `| piece |` row — re-anchor (#454)")
        }
        let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 2 else { throw XCTSkip("glossary row shape changed (#454)") }
        let word = cells[0].lowercased()
        XCTAssertEqual(word, "piece", "the glossary's first column is the English chrome word")
        let strings = try catalogStrings()
        for key in ["Piece", "Playing piece", "Unsaved piece", "Play the piece"] {
            guard let en = catalogued(key, in: strings) else { XCTFail("\"\(key)\" is not an English-only catalog key"); continue }
            XCTAssertTrue(en.value.lowercased().contains(word), """
                the chrome's "\(key)" reads "\(en.value)" and does not carry the glossary word "\(word)" \
                (docs/dev/GLOSSARY.md, row `piece`). One word per thing.
                """)
        }
    }
}
