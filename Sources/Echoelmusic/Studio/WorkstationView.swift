// WorkstationView.swift
// Echoel — #1436 founder Phase 3 (the surface) + #1437 founder Phase 4 (its transport)
// + Audio Import V1 (its first producer).
//
// WHAT THIS IS. A reachable window onto the canonical timeline state — the lanes and regions
// `TimelineStore` already owns and already persists — with ONE control: Play/Stop. It is a
// DMMW surface, not a product and not a rebuild of the arrangement UI #121 Slice 4 deleted.
//
// ⭐ READ-ONLY HAS NARROWED TWICE, AND EACH STEP IS ONE NAMED POWER. Phase 3 could only SHOW
// the song. #1437 added the power to START it. Audio Import V1 (founder 2026-09-22) adds the
// power to place ONE imported audio file on the audio track the song already has. #F1
// (2026-09-23) adds an empty audio track. #C1 ("WARP / NATIVE BPM: Approved", 2026-09-23)
// lets a track's parts follow the song tempo — which resizes a whole-file part to the bars
// its file covers, and nothing else. S1 (founder "all tasks", 2026-09-23) lets an imported
// FILE's own tempo be corrected — ×2, ÷2, or by hand — which is a property of the clip and
// is inaudible until Warp is on. #165 lets an audio track's parts play higher or lower in
// whole semitones (per track, while stopped). When this paragraph was written the surface could
// not move, trim, split, duplicate or delete a part, remove a track, author automation, or record;
// WA4 (arrange), Automation A1 and Recording R1 each added theirs since. ⛔ This sentence said "add or
// remove a track" from #F1 until #C1: the header of the file that holds the track button.
// Each power arrived on its own founder decision.
//
// ⛔ IT OWNS NOTHING AND MINTS NOTHING, WHICH THE IMPORT DOES NOT CHANGE. No second
// `TimelineDocument`, no `Arrangement`, no project store, no persistence file, no clock, no
// routing graph, no second player, no media store. It reads `TimelineStore.document`, projects
// it through `WorkstationSummary` (a pure function), and hands that same document to the ONE
// `TimelineRegionPlayer` the app constructs.
//
// ⚠️ AND THE IMPORT DOES NOT WRITE FROM HERE EITHER — IT HANDS THE OWNERS OVER. This file
// constructs no `Clip` and no `TimelineRegion`; it calls `AudioImport.perform` with the two
// stores and the picked URL, and that type — Foundation-only at its core, with its three
// impure steps injected — does the copy, the validation and the two writes. So the only
// message this view sends to `timeline` is still `document`, and that is a fact about where
// the transaction lives rather than a spelling that dodges a guard:
// `TheWorkstationImportsAudioTests` pins the transaction's ONE production call site here, and
// `TheWorkstationHasADoorTests` claim F says in as many words where the mutation moved.
//
// ⛔ "AND NO FILE PATH" STOOD IN THE LINE ABOVE, AND PHASE E MADE IT HALF FALSE. This file now
// holds one `URL` — the managed copy the detected-tuning analysis reads — but it still neither
// builds nor looks one up: `AudioImport.Landing` REPORTS it, because the transaction that made
// the copy is the only thing that knows which file it wrote.
//
// ⭐ AND THE FIRST DRAFT DID IT THE OTHER WAY, WHICH IS WHY THE DISTINCTION IS WORTH THE LINES.
// It called `MediaLibrary.resolveRef(landing.clip.mediaRef)` right here. That is forbidden by
// `TheWorkstationImportsAudioTests`, and the guard turned out to be right about the SUBSTANCE
// rather than merely the vocabulary: `resolveRef` performs up to five
// `FileManager.fileExists` probes, and this code path is the MAIN ACTOR. The rule survives in
// its strong form — the view constructs no model and looks up no file.
//
// ⚠️ THE CLOCK IS NOT HERE AND MUST NEVER BE. `PatternEngine` is the musical authority;
// `play(...)` joins it (`pattern.play(cause: .timelineRegion)`) rather than starting anything
// of its own, and Stop rides the same transport back out. There is no timer, no display link
// and no tick in this file, and a guard says so — a second clock is the Ω-level mistake this
// phase was most at risk of making.
//
// ⚠️ RENDER SAFETY (10.76.41/50). This is a COLD leaf, and #1437 kept it one ON PURPOSE.
// `body` reads exactly two things: `TimelineStore.document`, which changes on a user edit and
// never on a clock, and `TimelineRegionPlayer.isPlaying`, which changes TWICE per take. It
// does NOT read `currentTick` — the player marks that `@ObservationIgnored` precisely so a
// view cannot subscribe to the ~8 Hz song position, and a playhead readout here would undo
// that with one line. No audio meters, no buffer-rate state, no bio. That matters more than
// it looks: this view is reached through
// `dropdownContent`, which since #479 is evaluated in the ROOT body permanently, so a
// high-frequency read added here would rebuild the whole Studio at that rate and tear down
// any open `.menu` Picker. The law is in `.claude/skills/swiftui-render-safety/SKILL.md`;
// the reason it applies HERE is that this file sits on the always-evaluated path.
//
// ⭐ THE DOOR COSTS ZERO PRESENTATION MODIFIERS ON THE ROOT, which is the whole reason this
// shape was chosen over a `.sheet`. It is a `StudioMenu` case in the existing chip strip — the
// same idiom `soundPanel`, `mixerPanel` and the rest use — so the ROOT body's aggregate
// generic type is untouched and the black-screen law (10.76.34) is not approached.
//
// ⚠️ AND THE IMPORT'S `.fileImporter` DOES NOT CHANGE THAT, measured rather than assumed. It
// sits on THIS file's body, and `WorkstationView.body` returns an OPAQUE `some View`: the root
// sees one type token, never the leaf's modifier chain, so the aggregate type
// `EchoelStudioView.body` builds is unchanged. The budgeted count — the one CLAUDE.md's
// presentation paragraph carries and `python3 scripts/doctor.py --section D` prints — is
// scoped to `EchoelStudioView.swift` file-wide, so it does not move either. A `.fileImporter`
// added to the ROOT instead would have spent a slot under the 14 ceiling, and the founder's
// instruction to keep the picker state local to this view is exactly what avoids that.
// Exactly one modal is ever true here; never drive two at once (the tap-blocking layer).
//
// NEEDS-FOUNDER-VERIFY (#1436/#1437): the door AND its transport, on the device. None of
// this is a thing a gate can answer — a green `Build for Testing` proves the bundle compiles
// and says nothing about whether a note is heard. (1) The "Workstation" chip is there,
// between Field and Save/Export, and the strip scrolls far enough to reach it. (2) A tap
// swaps the plate, and tapping Sound afterwards brings the instrument back — no stuck panel.
// (3) On a fresh install the plate shows the empty state — and it stays empty until the
// user taps something. ⛔ THIS ITEM USED TO END "NOTHING in this build creates a
// `TimelineLane`", measured and true until 2026-09-23: `TimelineStore.migrate` is reached
// only through `bootstrapIfNeeded`, whose one caller was `ArrangeTimelineView` (deleted by
// #121 Slice 4), and `addLane` / `addInstrumentTrack` had no production caller either, so
// the seeded "MIDI 1"/"Audio 1" pair existed ONLY in a document a pre-Slice-4 build
// persisted. The founder lifted that hold: "Add Audio Track" below now calls
// `AudioImport.addAudioTrack`, which is `addLane`'s first production caller. The SEED is
// still unreachable — a fresh document has no "MIDI 1" — so the first track a new user sees
// is one they asked for. Play reads "Nothing to play yet" and does not respond. (4) With a MIDI part on the song: Play SOUNDS it, the button
// turns to Stop, Stop
// silences it, and a second Play after that starts it again — the stick is what a lifecycle
// bug looks like from outside. (5) The instrument's own ■ also stops it (one transport, not
// two). (6) VoiceOver reads each lane row as ONE sentence and announces Play/Stop with the
// hint, not as an unlabelled glyph.
//
// NEEDS-FOUNDER-VERIFY (Audio Import V1): the import door on the device. (7) "Import Audio"
// sits under the transport and tapping it opens the system picker filtered to audio. (8)
// Cancelling says NOTHING — a cancelled pick is not a failure. (9) Picking a real audio file
// adds a part to the audio track, the plate's part count rises, and the line underneath names
// the file and its bar span. (10) Play then SOUNDS that file at its recorded speed, and Stop
// silences it. (11) A second import appends AFTER the first rather than on top of it. (12)
// With no audio track the button still taps and says "add an audio track first" — and the
// button that does it is the row directly above, so the instruction is obeyable in one tap.
// ⛔ That sentence was demoted to a bare report on 2026-09-22 because it named an action no
// production path could perform, and RESTORED on 2026-09-23 when the founder approved the
// creator. Founder decision 4 is untouched: the import still never creates a lane by itself.
// (13) VoiceOver announces the button and reads the result line.
//
// NEEDS-FOUNDER-VERIFY (Add Audio Track, founder 2026-09-23): (14) On a FRESH install the
// plate shows the empty state and "Add Audio Track" is tappable; one tap makes a track row
// appear named "Audio 1", and the plate stops reading empty. (15) Import then succeeds onto
// it and Play sounds it — the whole point of the door is that chain. (16) A second tap adds
// "Audio 2" rather than doing nothing, and an import still lands on "Audio 1" (the FIRST
// importable lane, not the newest). (17) The refusal note from a pre-track Import tap
// disappears when the track is added, instead of sitting under the new track. (18) VoiceOver
// announces "Add audio track" with its hint, and the tap target is a full 44 pt.
//
// NEEDS-FOUNDER-VERIFY (#F3/#F4, detected key + concert pitch, 2026-09-23): the import note
// is the ONLY place this analysis reaches a human, so only a device run can say whether it
// reads as a suggestion or as a claim. (19) Import a clearly tonal piece: the note should
// end "Sounds like <key>, A4 ≈ <n> Hz." and the key should match what you hear — if it is
// confidently WRONG, `keyConfidenceFloor`/`keyMarginFloor` are set too low. (20) Import a
// drum loop or anything atonal: it must NOT name a key. Before #F3 it said "Sounds like C
// major", which was the iteration order talking. (21) Import something recorded off-pitch
// or heavily pitch-bent: it should say "concert pitch unclear" rather than inventing a
// Kammerton — `a4ConfidenceFloor` is the one that decides, and 0.5 is a judgement. (22) The
// opposite failure matters as much: if real music keeps coming back "unclear", the floors
// are too HIGH and the feature has been gated into uselessness. Say which way it errs.
//
// NEEDS-FOUNDER-VERIFY (#B2/#C1, detected tempo + warp, 2026-09-23): (23) Import a loop whose
// tempo you know: the note should end "Tempo ≈ <n> BPM …" within a BPM or two, or offer the
// right number as the "(or …)" alternative. (24) A "Warp" switch then appears on that track;
// with the song at a DIFFERENT tempo, turning it on and pressing Play should keep the loop in
// time with the bar grid and at its own pitch (stretched, not sped up), and the part's bar span
// should change to the loop's own length. (25) Off returns it to recorded speed. (26) While the
// song plays the switch is unavailable, and VoiceOver says "Stop the song to change warp". (27)
// A file whose note says "Tempo unclear." shows NO switch. If the switch appears for a file
// that plainly has no pulse, `TempoDetector.confidenceFloor` is too low.
//
// NEEDS-FOUNDER-VERIFY (S1, correcting a file's own tempo, 2026-09-23): (28) Import a loop the
// note reads at half speed (e.g. a 174 BPM loop read as "Tempo ≈ 87"). Under its track a row
// names the file with "Tempo 87.0 BPM" and ÷2 / ×2 below it. Tap ×2: the field reads 174.0.
// Turn Warp on with the song at another tempo: the loop plays at its true speed and its part
// spans TWICE as many bars as it did at 87. (29) With Warp on, the row is greyed and says
// "turn Warp off to change its tempo"; VoiceOver speaks that. (30) A file the note calls
// "Tempo unclear." shows "tempo not set" and no Warp switch; type its tempo on the pad and
// the switch appears. (31) Right after an import the row reads "measuring tempo…" and cannot
// be touched until the note finishes. (32) Dragging the field while Warp is off changes
// nothing you hear, even while the song plays; the value survives leaving the plate and a
// relaunch. (33) The number pad opens here, and Import Audio still opens its picker after it.
// (34) VoiceOver reads the field with its unit and hint and each ÷2 / ×2 as its own button;
// check at a large text size that nothing runs off the screen. (35) After an import the
// detected tempo is still adopted (S1-0 changed how the clip is found).
//
// NEEDS-FOUNDER-VERIFY (#165, audio track pitch, 2026-09-23): (36) An audio track with a part
// shows "Pitch 0 semitones"; an empty track and the bio lane show none. Only whole numbers
// from −24 to +24; the − key works; a typed 30 lands on 24. (37) Set +12, Play: the part sounds
// an octave up at the same speed and bar length; −12 an octave down; back to 0 sounds exactly
// as before. (38) Is a transposed part audibly LATE against the click or the other tracks?
// The pitch node adds a delay nothing compensates — say whether it matters. (39) Warp on, song
// at another tempo, Pitch +5: in time and a fourth higher. (40) While the song plays the field
// is dimmed and VoiceOver says "Stop the song to change pitch". (41) The first Play after
// leaving 0: any dropout or click in the running instrument (the chain attaches then)?
// (42) Sound at ±5 and ±12 on a voice and a drum loop — acceptable? The value survives a
// relaunch. (43) Open a project saved before this build: no audio track is unexpectedly shifted
// (an older build could store a per-track transpose that was silent until now).
//
// NEEDS-FOUNDER-VERIFY (S2, MIDI file import, 2026-09-23): (44) "Import MIDI" opens a picker
// showing MIDI files; "Import Audio" still opens its audio picker after a MIDI pick, and the
// reverse — the two share ONE importer whose type switches (#W1). (45) Fresh install: Add MIDI
// Track → Import MIDI → Play sounds the whole file, then loops; Stop silences it. (46) Import,
// then the instrument's Start, then Workstation Play: bar 1 is still the imported file, not a
// composed take (the composer now yields to a user part). (47) Long pads and dense chords: the
// one-bar hold, and a note repeated across a bar line merging into one — acceptable? (48) With
// the instrument RUNNING, Workstation Play for more than 45 s: its evolve reloads the shared
// roll, so the part is replaced until Stop. The note says "with the instrument stopped"; say
// whether that is enough or needs fixing. (49) After Workstation Stop, the instrument's Play and
// its MIDI export: what plays and what is exported (the roll still holds the imported bars)?
// (50) A second import appends after the first. (51) A drum-only file is refused with its own
// sentence; a 3 MB file is refused as too large. (52) VoiceOver reads both new rows; nothing
// runs off the screen at a large text size.

#if canImport(SwiftUI)
import Foundation
import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@MainActor
struct WorkstationView: View {

    @Environment(TimelineStore.self) private var timeline
    /// The ONE player the app constructs (`EchoelmusicApp`, `@State`), reached through the
    /// environment. This view never MINTS one — a second player would be a second follow-state
    /// over one transport, and `TheWorkstationPlaysTheTimelineTests` claim F pins that.
    @Environment(TimelineRegionPlayer.self) private var player
    /// ⚠️ THE NEXT THREE ARE READ ONLY INSIDE THE TAP HANDLERS, never in `body`. Declaring an
    /// `@Environment` subscribes to nothing; READING a property in `body` does, and this file
    /// sits on the always-evaluated `dropdownContent` path (#479). `beatPlayer.pattern` in
    /// particular leads to the ~20 Hz transport — a body read of it would be the 10.76.41/50
    /// freeze with a different producer.
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll
    @Environment(ClipStore.self) private var clipStore
    /// MA4.2 — the durable media identities an import registers. Read only in the import
    /// handler, never in `body`.
    @Environment(MediaAssetStore.self) private var mediaAssets

    /// Audio Import V1 — picker + result, both LOCAL to this leaf on the founder's
    /// instruction. Neither is persisted, neither is read by any other surface, and neither
    /// is hot: `importPresented` flips on a tap, `importNote` on a completed pick. Putting
    /// either in the permanent Studio root would have made the whole Studio rebuild on a
    /// file-picker dismissal, and `importNote` would have become a sixth thing the root
    /// carries between plate switches for no reason.
    @State private var importPresented = false
    @State private var importNote: String?

    /// S2 — which file the ONE importer is asking for. One `.fileImporter` whose content type
    /// switches, never a second one: two importers on one view is the shape that can shadow a
    /// picker (#W1), and `TheWorkstationImportsAudioTests` pins the prefix of this one.
    /// Local and cold, like the two above — it changes on a tap.
    private enum ImportKind { case audio, midi }
    @State private var importKind: ImportKind = .audio

    /// The managed copy a tuning analysis is owed for, or nil. It is the `.task(id:)` key,
    /// which is why it holds the URL rather than a flag: a SECOND import must supersede the
    /// first, and SwiftUI restarts the task exactly when this value changes. A `Bool` would
    /// have had to be toggled off and on to re-fire, and the window between the two is a
    /// stale answer landing on a fresh note.
    ///
    /// ⚠️ LOCAL, LIKE THE OTHER TWO, AND NOT HOT — it changes once per completed import.
    ///
    /// ⛔ S1-0: THIS HELD ONLY THE URL, and the analysis then looked the clip up again by
    /// comparing `mediaRef` strings — a second opinion about clip content in the one view
    /// `TheWorkstationPlaysTheTimelineTests` forbids to inspect it. The `Landing` already
    /// reports the clip's id, so the key carries both and nothing is looked up.
    @State private var tuningPending: AnalysisRequest?

    /// S1 — the clip whose tempo analysis is still running, or nil. Its tempo row stays
    /// untouchable meanwhile: a stray swipe over a fresh "not set" row would otherwise author a
    /// tempo, and never-clobber would then refuse the detection that was about to land.
    /// Separate from `tuningPending` because that key stays set after the task ends.
    @State private var measuringClip: UUID?

    /// WA4 — the ONE owner of what is selected (`WorkstationSelection`, built once by the app).
    /// VIEW state, never song state: not part of the piece, never persisted. Cold — it changes
    /// on a tap. ⛔ `@State selectedTrack` stood here (WA4.1); a second surface that wanted
    /// the selection would have had to keep its own, and two selections disagree.
    @Environment(WorkstationSelection.self) private var selection

    var body: some View {
        let summary = WorkstationSummary(document: timeline.document)
        VStack(alignment: .leading, spacing: 10) {
            if summary.isEmpty {
                emptyState
            } else {
                songLine(summary)
                // WA4 path 4 — the arrangement: every track's parts on the one shared scale,
                // a part selected by tapping it. Handed the document this body already read;
                // the canvas observes only the selection, and the playhead is its own leaf.
                // (Replaces the WA4.5 per-row strips — one picture of the song, not two.)
                let arrangeRows = ArrangeCanvas.rows(summary)
                if !arrangeRows.isEmpty {
                    ArrangeCanvasView(rows: arrangeRows, document: timeline.document,
                                      songTicks: ArrangementStrip.songTicks(summary))
                        .padding(.horizontal, 10)
                    // WA4 path 5 — the actions for the part selected on the canvas. Its own
                    // leaf: it reads the song tempo and the clip only inside Split.
                    // M10: Play from the selected part, one tap above its notes — started
                    // through THIS view's one start, asked by the same question as Play.
                    SelectedPartBar(playFrom: { startTimeline(fromTick: $0, launching: []) },
                                    songCanStart: { songCanStart() })
                        .padding(.horizontal, 10)
                    // Phase 3 / M1 — the selected MIDI part's notes, behind its own "Notes"
                    // switch. A leaf: it reads the clip grid, never the transport — the rack's
                    // capacity (M8) is handed in as a number, set once at start.
                    PartNoteEditor(voiceCapacity: player.laneVoiceCapacity)
                        .padding(.horizontal, 10)
                    // Phase 3 / Automation A1 — the selected track's curve, behind its own
                    // "Automation" switch, on the canvas's scale. A leaf with its own store
                    // write; this view still sends `timeline` nothing but `document`.
                    SongAutomationEditor(songTicks: ArrangementStrip.songTicks(summary))
                        .padding(.horizontal, 10)
                }
                // WA4 path 7 — the ONE Undo/Redo for the song's parts. Outside the canvas's
                // `if`, so removing the last part still leaves the way back on screen. ⛔ M6
                // moved it above the canvas and was reverted by its own review: with the
                // automation editor closed (its default), this spot is directly under the note
                // grid's own controls — the closest place to the edit it takes back.
                SongHistoryRow()
                    .padding(.horizontal, 10)
                ForEach(summary.lanes) { row in
                    laneRow(row)
                    if WorkstationSelection.resolvedTrack(selection.trackID,
                                                          in: timeline.document) == row.id {
                        // The mixer and device facts of the ONE open track. Its own leaf, with
                        // its own store reads — this view still sends `timeline` nothing but
                        // `document`.
                        TrackInspectorView(laneID: row.id)
                            .id(row.id)
                        // Phase 3 / Recording R1 — record-arm, on a rack MIDI track only.
                        TrackArmToggle(laneID: row.id)
                    }
                    if row.kind == .audio {
                        pitchField(row)
                        partTempoRows(laneID: row.id)
                    }
                }
                if summary.orphanRegionCount > 0 { orphanLine(summary.orphanRegionCount) }
                if summary.automationLaneCount > 0 { automationLine(summary.automationLaneCount) }
            }

            // MARK: - The timeline transport (#1437, founder Phase 4)
            //
            // ⭐ THIS IS THE ONE PRODUCTION CALLER of `TimelineRegionPlayer.play(…)`, and it
            // arrives with the guard that says so. Phase 3's claim H pinned "zero callers";
            // it is REPLACED, in the same commit, by the invariant that exactly this path
            // may call it — inverted deliberately rather than routed around, because a
            // guard that survives by aliasing is worse than no guard.
            //
            // ⚠️ THE CONTROL IS UNAVAILABLE WHEN THE ENGINE WOULD REFUSE. `canPlay` is the
            // engine's OWN guard (#416), not a second opinion, so the button can never offer
            // a start that silently does nothing — the "disabled decorative transport" this
            // surface was told not to grow.
            transportRow

            // MARK: - The Session projection (WA4.2)
            //
            // The same song, launched live: parts and scenes loop on their track from the next
            // bar. Its own leaf, because launching reaches the player for members this file's
            // transport is not authorised to call (`TheWorkstationPlaysTheTimelineTests` B).
            // S2: it may START the song at a scene, through this file's own transport.
            SessionLaunchView(playFrom: { tick, parts in startTimeline(fromTick: tick, launching: parts) })

            // MARK: - The import door (Audio Import V1, founder 2026-09-22)
            //
            // ⭐ THE FIRST REACHABLE PRODUCER OF AN AUDIO-BEARING REGION. Until this row the
            // only path that could mint one was `RecordController` → `TakeRecorder` →
            // `AudioClipFactory`, and `arm()` had zero callers (#204/#527) — so
            // `AudioLanePlayer` walked `doc.audioLaneIDs` on every transport step and found
            // nothing, for four months, with the engine shipped and injected the whole time.
            // MARK: - The lane door (founder 2026-09-23, unblocking the #E3 hold)
            //
            // ⭐ IT SITS ABOVE IMPORT BECAUSE THAT IS THE ORDER OF THE SENTENCE the refusal
            // one row down speaks: "add an audio track first". Until this row that sentence
            // named an action no production path could perform — `bootstrapIfNeeded`,
            // `addLane` and `addInstrumentTrack` each had zero callers outside
            // `Core/TimelineStore.swift`, so a fresh `TimelineDocument()` stayed `lanes: []`
            // forever and the import door was unreachable on a clean install.
            addTrackRow
            importRow
            // S2 — the MIDI pair, in the same order and for the same reason: the refusal
            // "add a MIDI track first" names the row directly above Import MIDI.
            addMIDITrackRow
            importMIDIRow
            // Phase 3 / M1b — an EMPTY part for the note editor, so writing notes does not
            // need a MIDI file. Same lane and refusals as Import MIDI (`MIDIImport`).
            newMIDIPartRow
            if let note = importNote { importNoteLine(note) }
            // Phase 3 / MA1 — the media library: the audio files already imported, and "Place"
            // to put one on the song again without Files, a second copy or a second clip slot.
            // Its own leaf: it lists the directory detached and writes through
            // `MediaPlacement`; this view reads none of its state.
            // ⚠️ GROUPED WITH THE PROJECT ROW so this `VStack` keeps ten direct children: past
            // ten, `ViewBuilder` resolves through the variadic pack (#936). `Group` is
            // layout-transparent — both rows still sit in this stack at its spacing.
            Group {
                MediaBrowserView()
                // WA4 Acceptance Test A inside the workspace: create → import → SAVE → reopen
                // without leaving the plate. The row owns no Studio state; it opens the Studio's
                // existing Save alert and Open sheet through the chrome door (no new modal).
                WorkstationProjectRow()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if canImport(UniformTypeIdentifiers)
        // ⚠️ ON THE LEAF, NEVER ON THE ROOT — see the header. `allowedContentTypes: [.audio]`
        // is the system's own conformance test, so a picker that offers a file at all has
        // already said it claims to be audio; `AudioImport` still measures the MANAGED COPY
        // afterwards, because "claims to be audio" and "decodes" are different facts.
        .fileImporter(isPresented: $importPresented,
                      allowedContentTypes: [importKind == .midi ? UTType.midi : UTType.audio],
                      allowsMultipleSelection: false) { result in
            // ⚠️ `.midi` conforms to `.audio`, so the AUDIO picker also lists `.mid` files;
            // picking one there is refused by `AudioImport` as audio it cannot read.
            if importKind == .midi { handleMIDIImport(result) } else { handleImport(result) }
        }
        #endif
        // MARK: - Detected tuning (Phase E)
        //
        // ⭐ THE ANALYSIS RUNS HERE AND NOWHERE ELSE, and the hop is the point.
        // `AudioKeyAnalysis.analyse` is seconds of YIN; `Task.detached` takes it off the
        // main actor so the plate stays live, and `.task(id:)` cancels a superseded run
        // rather than letting two answers race for one line.
        //
        // ⚠️ THE NOTE IS APPENDED ONLY IF IT IS STILL THE SAME NOTE. This file's own law is
        // that success and failure share ONE line so a stale success cannot sit under a
        // fresh failure; an async append is exactly the way to break that law by accident,
        // so the base text is captured before the hop and compared after it.
        //
        // ⚠️ THE KEY IS PROSE, NOT STATE. `SessionContext` remains the one owner of the
        // song's key; the user reads the sentence and decides.
        //
        // ⭐ THE TEMPO IS WRITTEN — TO THE CLIP, NEVER TO THE SESSION (#B2). A KNOWN native
        // tempo is adopted through `ClipStore.adoptDetectedNativeBPM` (never-clobber, see
        // `AudioTempoAnalysis.adoptableNativeBPM`), because warp needs it and nothing else
        // can supply it. It is inaudible until the person turns warp on for a region. The
        // clip is named by the id the import's `Landing` reported (S1-0); a clip deleted in
        // the meantime is simply not found by the store, and nothing is written.
        //
        // ⚠️ THE WRITE DOES NOT WAIT FOR THE NOTE. A newer import supersedes the SENTENCE,
        // not the fact: the older clip's tempo is still that clip's tempo.
        .task(id: tuningPending) {
            #if canImport(AVFoundation)
            guard let request = tuningPending else { return }
            let url = request.url
            let base = importNote
            let (tuning, tempo) = await Task.detached(priority: .utility) {
                (AudioKeyAnalysis.analyse(url: url), AudioTempoAnalysis.analyse(url: url))
            }.value
            clipStore.adoptDetectedNativeBPM(id: request.clipID, tempo)
            if measuringClip == request.clipID { measuringClip = nil }
            let parts = [AudioKeyAnalysis.summarise(tuning), AudioTempoAnalysis.summarise(tempo)]
                .compactMap { $0 }
            if !parts.isEmpty, importNote == base {
                let summary = parts.joined(separator: " ")
                importNote = base.map { $0 + " " + summary } ?? summary
            }
            // MA4.4 — the landed file's content evidence: its SHA-256, streamed in chunks off the
            // main actor and written to its durable record (only if it has none). Here, after the
            // analysis and inside the same cancellable task — never at launch, never as a scan.
            #if canImport(CryptoKit)
            if let assetID = request.assetID {
                await MediaContentDigest.learn(recordID: assetID, from: url, into: mediaAssets,
                                               hash: { try MediaContentDigest.sha256(fileAt: $0) })
            }
            #endif
            #endif
        }
    }

    // MARK: - Pieces

    /// ⛔ #W2 — THIS SAID "Takes you record or generate appear here as parts on a track." and
    /// both halves were false on the only document a new user has. Nothing records (#1302), and
    /// a generated take lands on the timeline only through `ensureComposerRegion`, which needs
    /// a MIDI lane — and at the time nothing in this build created one (the seed is
    /// unreachable; since S2 "Add MIDI Track" does, but the composer still writes only when the
    /// instrument runs, never onto an empty plate). So the empty plate promised a producer that
    /// could not run, beside a greyed Play. It now names the buttons that DO fill it, by their
    /// labels rather than by position (the #152 lesson: "below" is a claim about layout).
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No tracks yet")
                .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
            Text("Tap Add Audio Track, then Import Audio — or Add MIDI Track, then Import MIDI or New MIDI Part. A file becomes a part you can play; a new part plays once it has notes.")
                .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        // One spoken sentence rather than two fragments — VoiceOver would otherwise read the
        // heading and the explanation as unrelated items.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No tracks yet. Tap Add Audio Track, then Import Audio — or Add MIDI Track, then Import MIDI or New MIDI Part. A file becomes a part you can play; a new part plays once it has notes.")
    }

    private func songLine(_ summary: WorkstationSummary) -> some View {
        let tracks = summary.lanes.count
        let parts = summary.regionCount
        let bars = summary.lengthBars
        return HStack(spacing: 10) {
            Text("\(tracks) \(tracks == 1 ? "track" : "tracks")")
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(parts) \(parts == 1 ? "part" : "parts")")
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(bars) \(bars == 1 ? "bar" : "bars")")
            Spacer(minLength: 0)
        }
        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arrangement: \(tracks) tracks, \(parts) parts, \(bars) bars long")
    }

    private func laneRow(_ row: WorkstationSummary.LaneRow) -> some View {
        let selected = selection.trackID == row.id
        // WA4 path 6 — the header's Mute/Solo appear only where they are HEARD
        // (`TrackMix.controls`, the rule the inspector used). `laneVoiceCapacity` is cold.
        let controls = TrackMix.controls(of: row.id, in: timeline.document,
                                         voiceCapacity: player.laneVoiceCapacity)
        let muteSoloRole = controls.flatMap { $0.muteSolo ? $0.role : nil }
        return HStack(spacing: 8) {
            // WA4.1 — tapping the facts selects the track and opens its inspector; tapping the
            // open one closes it. The facts stay ONE spoken element (#1436); selection is a
            // trait on it, not a second control beside it.
            // The facts fill the row's height (44 pt with the 6 pt padding) so the whole row is
            // the tap target, not the ~31 pt of text (review of b2913f96b).
            laneFacts(row, headerSwitches: muteSoloRole != nil)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { selection.toggleTrack(row.id) }
                .accessibilityAction { selection.toggleTrack(row.id) }
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                // Only what every track has is promised; the mixer and the parts list appear
                // where the track has them (`TrackMix.controls`, `TrackParts.arrangeable`).
                .accessibilityHint(selected ? "Closes this track's details"
                                            : "Opens this track's details: its device, and its mixer and parts where it has them")
            // ⚠️ OUTSIDE the combined element, on purpose: `.combine` on the row swallowed the
            // tuning banner's recovery button once (#621) — a control inside a merged element
            // loses its own focus and hint. The facts are ONE sentence; the switch is a switch.
            if let role = muteSoloRole {
                headerSwitch("M", name: "Mute", on: row.isMuted, hint: TrackMix.muteHint(role)) {
                    TrackMix.flipMute(laneID: row.id, timeline: timeline)
                }
                headerSwitch("S", name: "Solo", on: row.isSoloed, hint: TrackMix.soloHint(role)) {
                    TrackMix.flipSolo(laneID: row.id, timeline: timeline)
                }
            }
            if row.kind == .audio { warpSwitch(laneID: row.id) }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(selected ? EchoelTheme.accent : EchoelTheme.border, lineWidth: 1))
    }

    /// One track-header switch (Mute or Solo). A letter on screen, the full word to VoiceOver;
    /// monochrome fill when on, never a coloured area behind a label (EchoelTheme).
    private func headerSwitch(_ letter: String, name: String, on: Bool, hint: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(letter)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(on ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        // Review of 33d5c0537 (LOW): the switch SHOWS "M"/"S" and is NAMED "Mute"/"Solo" — a
        // Voice Control user who says what they see ("tap M") must reach it too.
        .accessibilityInputLabels([name, letter])
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityHint(hint)
    }

    private func laneFacts(_ row: WorkstationSummary.LaneRow, headerSwitches: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.kind.systemImage)
                .foregroundStyle(EchoelTheme.dim)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
                    if let instrument = row.instrument {
                        Text(instrument.displayName)
                            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    }
                }
                Text(detailLine(row))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            }
            Spacer(minLength: 0)
            ForEach(stateTags(row, headerSwitches: headerSwitches), id: \.self) { tag in
                Text(tag)
                    .font(EchoelTheme.font(10, .semibold))
                    .foregroundStyle(EchoelTheme.dim)
                    .padding(.horizontal, 6).frame(minHeight: 20)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.fill))
            }
        }
        // The row is several fragments on screen and ONE fact to a listener (#1436): the
        // sentence is built once, in `WorkstationSummary`, so it cannot drift from the numbers
        // rendered beside it (#416).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WorkstationSummary.spokenDescription(of: row))
    }

    /// #C1 — "Warp": the audio track's parts follow the SONG tempo instead of their recorded
    /// speed. The whole decision is `AudioWarp` (which parts can warp, what each one spans);
    /// this view hands the two stores over and messages neither, the seam claim F names.
    ///
    /// ⚠️ NO SWITCH WHEN NOTHING CAN WARP. A part can only warp once its clip carries a KNOWN
    /// native tempo (#B2), so a track whose tempo stayed unclear shows nothing here rather
    /// than a control that can only refuse — the disabled-decorative shape this surface was
    /// told not to grow. The import note already says "Tempo unclear." for exactly that case.
    ///
    /// ⚠️ UNAVAILABLE WHILE THE SONG PLAYS, and that is the engine's rule, not a nicety: the
    /// player re-reads the document every step, and a warped part needs its warp chain
    /// attached at PRIME time — attaching mid-song pauses the whole engine (the
    /// `AudioLanePlayer.prime` "review HIGH 2" law). Stop, switch, Play.
    ///
    /// Cold reads only: `timeline.document` and `clipStore.filledClips` change on a user edit
    /// or a ~30 s evolve, `isPlaying` twice per take, `preflightTempo` is read in the tap.
    @ViewBuilder
    private func warpSwitch(laneID: UUID) -> some View {
        let state = AudioWarp.state(laneID: laneID, in: timeline.document,
                                    clips: clipStore.filledClips)
        if state != .unavailable {
            let on = state == .on
            let playing = player.isPlaying
            Button {
                // Mixed → all on: the tap resolves the ambiguity toward the switch's name.
                AudioWarp.setWarp(!on, laneID: laneID, timeline: timeline,
                                  clipStore: clipStore, bpm: player.preflightTempo)
            } label: {
                Text(state == .mixed ? "Warp · some" : "Warp")
                    .font(EchoelTheme.font(11, .semibold))
                    .foregroundStyle(on ? EchoelTheme.onPrimary
                                        : (playing ? EchoelTheme.dim : EchoelTheme.text))
                    .padding(.horizontal, 10)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(on ? EchoelTheme.accent : EchoelTheme.fill))
                    .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(playing)
            .accessibilityLabel("Warp to song tempo")
            .accessibilityValue(on ? "On" : (state == .mixed ? "On for some parts" : "Off"))
            .accessibilityHint(playing
                ? "Stop the song to change warp"
                : "Plays this track's parts at the song's tempo instead of their recorded speed")
        }
    }

    /// #165 — "Pitch": every part on this audio track, up or down in whole semitones, tempo
    /// unchanged. The decision is `AudioTranspose`; the write is the store's — this view hands
    /// `timeline` over and still sends it exactly one message, `document`. Declared AFTER
    /// `warpSwitch` for the same slice reason as `partTempoRows` below.
    ///
    /// ⚠️ UNAVAILABLE WHILE THE SONG PLAYS — the Warp switch's rule and reason: a pitched part
    /// needs the time-pitch chain attached at PRIME time. No field on a track with no parts,
    /// where it could only shift nothing, and none on the bio lane.
    ///
    /// Cold reads only: `timeline.document` changes on an edit, `isPlaying` twice per take.
    @ViewBuilder
    private func pitchField(_ row: WorkstationSummary.LaneRow) -> some View {
        if !row.isBio, row.regionCount > 0 {
            let laneID = row.id
            let playing = player.isPlaying
            EchoelValueField(
                label: "Pitch",
                value: Binding(
                    get: { Double(AudioTranspose.semitones(laneID: laneID, in: timeline.document)) },
                    set: { AudioTranspose.setPitch(AudioTranspose.semitones(fromField: $0),
                                                   laneID: laneID, timeline: timeline) }),
                range: AudioTranspose.fieldRange,
                unit: "semitones",
                decimals: 0,
                hint: playing
                    ? "Stop the song to change pitch"
                    : "Moves every part on this track up or down without changing its tempo")
            .disabled(playing)
            .padding(.leading, 36).padding(.trailing, 10)
        }
    }

    /// S1 — one row per imported FILE on this audio track, under the track row. The tempo is a
    /// property of the clip, not of the placement, so a file placed twice is one row. Declared
    /// AFTER `warpSwitch` on purpose: `TheWarpSwitchIsHonestTests` slices from `laneFacts` to
    /// `warpSwitch` and this must not sit inside that slice.
    ///
    /// Cold reads only — `timeline.document` and `clipStore.filledClips` change on an edit,
    /// `preflightTempo` is `@ObservationIgnored`. The drag-rate draft lives in the leaf.
    @ViewBuilder
    private func partTempoRows(laneID: UUID) -> some View {
        let document = timeline.document
        ForEach(AudioTempoCorrection.audioClips(onLane: laneID, in: document,
                                                clips: clipStore.filledClips)) { clip in
            PartTempoRow(clip: clip,
                         lockedByWarp: AudioTempoCorrection.isLockedByWarp(clip: clip, in: document),
                         measuring: measuringClip == clip.id,
                         songBPM: player.preflightTempo,
                         onSet: { correctTempo($0, clipID: clip.id) })
        }
    }

    /// Hands the decision to `AudioTempoCorrection` and the write to `ClipStore` — this view
    /// still sends `timeline` exactly one message, `document`.
    private func correctTempo(_ bpm: Double, clipID: UUID) {
        AudioTempoCorrection.setNativeBPM(bpm, clipID: clipID, in: timeline.document,
                                          clipStore: clipStore)
    }

    /// The printed half of the same facts `spokenDescription` says — short, because the row
    /// is 11 pt and the listener already has the long form.
    private func detailLine(_ row: WorkstationSummary.LaneRow) -> String {
        var text = row.kind.displayName
        if row.isBio { text += " · bio curve" }
        switch row.regionCount {
        case 0:  text += " · no parts"
        case 1:  text += " · 1 part"
        default: text += " · \(row.regionCount) parts"
        }
        if let first = row.firstTick, let last = row.lastTick, row.regionCount > 0 {
            // One spelling of the span, shared with the spoken form — an en dash here and the
            // word "to" there, but the same two bar numbers (#416).
            text += " · " + WorkstationSummary.barSpan(firstTick: first, lastTick: last,
                                                       joiner: "–")
        }
        if !row.playsOnTheTimeline && row.regionCount > 0 { text += " · no engine yet" }
        return text
    }

    /// Only the states that are ON. A row of greyed-out "not muted, not soloed, not armed"
    /// badges would be three pieces of chrome saying nothing.
    /// Where the header draws Mute/Solo switches, their state is ON the switch; a tag beside
    /// it would say the same fact twice. A track without the switches keeps the tags — a stored
    /// mute on a bio lane is still a fact worth showing.
    private func stateTags(_ row: WorkstationSummary.LaneRow, headerSwitches: Bool) -> [String] {
        var tags: [String] = []
        if row.isMuted && !headerSwitches { tags.append("MUTE") }
        if row.isSoloed && !headerSwitches { tags.append("SOLO") }
        if row.isArmed { tags.append("ARM") }
        return tags
    }

    private func orphanLine(_ count: Int) -> some View {
        Text("\(count) \(count == 1 ? "part belongs" : "parts belong") to a track this song no longer has.")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(count) parts belong to a track this song no longer has")
    }

    private func automationLine(_ count: Int) -> some View {
        Text("\(count) automation \(count == 1 ? "lane" : "lanes")")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
    }

    /// Play / Stop for the arrangement. ONE button, because there is one thing to say:
    /// the song is running or it is not. A separate greyed Stop beside a Play would be two
    /// claims where the state has one — the #305 lesson from the instrument's own row, where
    /// two controls carrying the same glyph meant different things.
    private var transportRow: some View {
        // `canPlay` is the engine's own guard, asked here so the control matches it exactly.
        // `isPlaying` is the player's only hot-ish observable on this path and it changes
        // TWICE per take, not per step (`currentTick` is `@ObservationIgnored` precisely so
        // a reader like this one cannot subscribe to the ~8 Hz position).
        let playing = player.isPlaying
        // ⚠️ THE CLIPS ARE PART OF THE QUESTION (#1438). A placed region is a POINTER; the
        // engine can only start if at least one of them resolves into content it would
        // execute, so the control must hand over the same clip values `play(...)` will.
        // Reading `filledClips` here also SUBSCRIBES this leaf to the clip grid, which is
        // wanted: the moment the composer writes notes into its clip, Play becomes
        // available without a second tap. It is not a hot read — `ClipStore.slots` is
        // written by generate/evolve (~30 s at most), never per transport step.
        // ⭐ TWO MORE ARGUMENTS SINCE #1439, AND NEITHER IS A HOT READ — that is the whole
        // reason they look like this. `preflightTempo` and `audioLanes` are both
        // `@ObservationIgnored` on the player, so this body subscribes to NOTHING new. The
        // obvious spellings would both be the 10.76.41/50 freeze: `beatPlayer.pattern.tempo`
        // is `@Observable` and glides at ~20 Hz, and so is `Transport.tempo`.
        // ⚠️ The resolver does `FileManager.fileExists` probes, in a `body`. Bounded on
        // purpose: `firstExecutableRegion` short-circuits, so a song whose first MIDI part
        // has notes never touches the filesystem, and an audio-first song probes only until
        // one region resolves. Do not "optimise" this into a cached set — a cache is a
        // second answer, and the whole point is that there is one (§2).
        // M10: asked through `songCanStart()`, the one call site — the part bar's Play asks it too.
        let startable = songCanStart()
        return VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Button {
                if playing { player.stop() } else { startTimeline(fromTick: 0, launching: []) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(playing ? "Stop" : "Play")
                        .font(EchoelTheme.font(13, .semibold))
                }
                // The armCard idiom, unchanged: accent + onPrimary while it is RUNNING,
                // fill + border while it is not. Dim only where the control is unavailable,
                // so "off" and "cannot" do not wear the same colour.
                .foregroundStyle(playing ? EchoelTheme.onPrimary
                                         : (startable ? EchoelTheme.text : EchoelTheme.dim))
                .padding(.horizontal, 14)
                .frame(minWidth: 92, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(playing ? EchoelTheme.accent : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(playing || !startable ? Color.clear : EchoelTheme.border,
                                  lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!playing && !startable)
            .accessibilityLabel(playing ? "Stop timeline" : "Play timeline")
            .accessibilityHint(WorkstationSummary.transportHint(playing: playing, startable: startable))

            Text(WorkstationSummary.transportCaption(playing: playing, startable: startable))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)   // the button's own hint already carries this
          }
            // Phase 3 / Recording R1 — the MIDI take, started through THIS row's one start
            // (from the top) and stopped by the same Stop. A leaf in its own file: this view
            // names neither the recorder nor its controller.
            RecordTakeButton(playing: playing, startable: startable,
                             voiceCapacity: player.laneVoiceCapacity,
                             startSong: { startTimeline(fromTick: 0, launching: []); return player.isPlaying },
                             stopSong: { player.stop() })
        }
        .padding(.top, 2)
    }

    /// "Add Audio Track" — the founder's minimal creator (2026-09-23). One tap appends one
    /// `TimelineLane(kind: .audio)` and nothing else: no arrangement edit, no clip, no
    /// region, no recording, no input.
    ///
    /// ⚠️ THE STORE IS HANDED OVER, NEVER MESSAGED — the same seam `handleImport` uses, and
    /// for the same reason. `TheWorkstationHasADoorTests` claim F pins that this file sends
    /// `timeline` exactly one message, `document`; the mutation belongs to
    /// `AudioImport.addAudioTrack`, where its own guard can own it. That is not a way around
    /// claim F, it is the repair claim F's own note prescribes.
    ///
    /// ⚠️ ALWAYS TAPPABLE, LIKE IMPORT AND UNLIKE PLAY. Play disables itself because the
    /// engine can answer "this would do nothing" BEFORE the tap; this action never can do
    /// nothing — it always appends a track. Hiding it once a track exists would make a
    /// SECOND audio track unreachable for no stated reason, which is a surface that lies by
    /// omission rather than by label.
    ///
    /// ⚠️ NO RESULT LINE, DELIBERATELY — but it CLEARS one. The outcome is the plate itself:
    /// the new track appears in the rows above within the same update, because `body` reads
    /// `timeline.document`, and a sentence saying "added a track" under a plate that already
    /// shows the track is a second truth about one event. The `importNote = nil` is the
    /// opposite case and is not decoration: the note most likely on screen when this button
    /// is tapped is "add an audio track first", and leaving that refusal standing underneath
    /// the track it just asked for would read as the tap having failed.
    private var addTrackRow: some View {
        Button {
            importNote = nil
            AudioImport.addAudioTrack(timeline: timeline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add Audio Track").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add audio track")
        .accessibilityHint("Adds an empty audio track to the song, ready for an import")
    }

    /// "Import Audio" — one button, no menu. The founder's instruction was a single action
    /// inside the existing plate. ⛔ This said "no browser — the surface this phase was told
    /// not to grow"; that was Audio Import V1's phase. The founder's Phase 3 order (2026-09-25)
    /// asks for the browser, and it is `MediaBrowserView`, a separate leaf below — this row
    /// still only picks a NEW file.
    ///
    /// ⚠️ IT IS NEVER DISABLED, deliberately, and that is the opposite of the transport's
    /// rule one row up. Play disables itself because the engine's own `canPlay` can answer
    /// "this would do nothing" BEFORE the tap. Import cannot: whether the pick succeeds,
    /// whether the file decodes, whether a slot is free at that moment — none of it is known
    /// until the user has chosen. A greyed-out Import would have to guess, and the honest
    /// alternative is what this row does: always tappable, and every outcome says what
    /// happened in words (`AudioImport.Failure.userMessage`).
    private var importRow: some View {
        Button {
            importNote = nil
            tuningPending = nil
            importKind = .audio
            importPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                Text("Import Audio").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import audio")
        .accessibilityHint("Adds an audio file to the song's audio track")
    }

    /// S2 — "Add MIDI Track": `addTrackRow`'s twin. The store is handed to
    /// `MIDIImport.addMIDITrack`, never messaged (claim F). It always appends.
    ///
    /// ⚠️ A MIDI TRACK IS WHERE THE INSTRUMENT'S COMPOSER WRITES, so this row changes more than
    /// the plate: the next Start mirrors the composed take onto this track (one clip slot),
    /// unless a user part already sits at its start — then the composer yields.
    private var addMIDITrackRow: some View {
        Button {
            importNote = nil
            MIDIImport.addMIDITrack(timeline: timeline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add MIDI Track").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add MIDI track")
        .accessibilityHint("Adds an empty MIDI track to the song, ready for an import")
    }

    /// S2 — "Import MIDI": the same importer as `importRow`, asked for a MIDI file. Never
    /// disabled, for `importRow`'s reason: every outcome is known only after the pick, and each
    /// one says what happened (`MIDIImport.Failure.userMessage`).
    private var importMIDIRow: some View {
        Button {
            importNote = nil
            tuningPending = nil
            importKind = .midi
            importPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pianokeys")
                    .font(.system(size: 13, weight: .semibold))
                Text("Import MIDI").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import MIDI file")
        .accessibilityHint("Adds a MIDI file's notes to the song's first MIDI track")
    }

    /// Phase 3 / M1b — "New MIDI Part": an empty part on the MIDI track, selected at once so the
    /// part bar and the note editor below the canvas open on it. The stores are handed to
    /// `MIDIImport.addEmptyPart`, never messaged (claim F); selecting reads only `document`.
    ///
    /// ⚠️ NEVER DISABLED, for `importMIDIRow`'s reason: a missing track or a full clip grid is
    /// known to the plan, and each refusal says so in words on the one note line.
    private var newMIDIPartRow: some View {
        Button {
            importNote = nil
            tuningPending = nil
            switch MIDIImport.addEmptyPart(clipStore: clipStore, timeline: timeline) {
            case .success(let landing):
                selection.selectRegion(landing.region.id, in: timeline.document)
                let laneName = timeline.document.lanes
                    .first { $0.id == landing.laneID }?.name ?? "the MIDI track"
                importNote = MIDIImport.emptyPartNote(laneName: laneName,
                                                      atSongStart: landing.region.startTick == 0)
            case .failure(let failure):
                importNote = failure.userMessage
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 13, weight: .semibold))
                Text("New MIDI Part").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New MIDI part")
        .accessibilityHint("Adds an empty four-bar part to the MIDI track Import MIDI uses, and selects it")
    }

    /// S2 — run the MIDI import and say what happened. `handleImport`'s shape without the
    /// analysis: cancelling says nothing, and everything that writes or reads the file lives in
    /// `MIDIImport` (this file still names no `Clip`, `TimelineRegion` or `FileManager`).
    private func handleMIDIImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            importNote = MIDIImport.Failure.pickerFailed.userMessage
        case .success(let urls):
            guard let url = urls.first else { return }
            switch MIDIImport.perform(pickedURL: url, clipStore: clipStore, timeline: timeline) {
            case .success(let landing):
                let laneName = timeline.document.lanes
                    .first { $0.id == landing.laneID }?.name ?? "the MIDI track"
                importNote = MIDIImport.successNote(landing, laneName: laneName)
            case .failure(let failure):
                importNote = failure.userMessage
            }
        }
    }

    /// The one line every outcome writes to. Success and failure share it on purpose: two
    /// separate slots would let a stale success sit under a fresh failure, which is the
    /// "control that lies" shape in its quietest form.
    private func importNoteLine(_ note: String) -> some View {
        Text(note)
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(note)
    }

    /// Run the import and say what happened.
    ///
    /// ⚠️ CANCELLING IS NOT A FAILURE, and the check is a SUPERSET under both readings of
    /// SwiftUI's contract — the same argument `EchoelStudioView`'s project importer writes
    /// out: whether Cancel arrives as `CocoaError.userCancelled` or never calls the
    /// completion has varied across iOS versions, and no device is available here to settle
    /// it. If cancellation is delivered we swallow it; if it is not, the guard is a no-op.
    /// The other direction would put "Couldn't open that file." on screen for a user who
    /// deliberately backed out.
    ///
    /// ⚠️ THE STORES ARE HANDED OVER, NOT MESSAGED. Everything that writes lives in
    /// `AudioImport`, which is why this file still sends `timeline` exactly one message
    /// (`document`) and names no `Clip`, `TimelineRegion` or `FileManager`.
    ///
    /// ⛔ THIS SENTENCE USED TO END "or path" — narrowed by Phase E, see the file header. The
    /// success branch reads the `URL` and the clip id off the `Landing` the transaction
    /// returns (the id since S1-0). It neither builds a path nor looks one up.
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            importNote = AudioImport.Failure.pickerFailed.userMessage
        case .success(let urls):
            guard let url = urls.first else { return }
            #if canImport(AVFoundation)
            // `preflightTempo` is the tempo the Play predicate already judges this song at —
            // `@ObservationIgnored`, mirrored from `PatternEngine`, and read in a tap handler
            // rather than in `body`. The placement needs a tempo to turn the file's measured
            // seconds into whole bars; it does NOT estimate the file's own tempo (decision 7).
            switch AudioImport.perform(pickedURL: url,
                                       clipStore: clipStore,
                                       timeline: timeline,
                                       assets: mediaAssets,
                                       bpm: player.preflightTempo) {
            case .success(let landing):
                let laneName = timeline.document.lanes
                    .first { $0.id == landing.laneID }?.name ?? "the audio track"
                importNote = AudioImport.successNote(landing, laneName: laneName)
                // ⚠️ THE URL COMES FROM THE TRANSACTION, NOT FROM A SECOND LOOKUP. A first
                // draft asked `MediaLibrary.resolveRef(landing.clip.mediaRef)` here, which
                // `TheWorkstationImportsAudioTests` forbids — and the guard was right on the
                // merits, not only on the spelling: `resolveRef` runs up to five
                // `fileExists` probes, and this is the MAIN ACTOR. `AudioImport` already
                // held the managed copy, so it reports it.
                // MA2 — a reused clip that already knows its tempo is not analysed again: the
                // never-clobber adoption would refuse the result anyway, and meanwhile its
                // tempo row would read "measuring…" and lock (review of 7b691faf8).
                if !(landing.reusedLibraryFile && landing.clip.nativeBPM > 0) {
                    tuningPending = AnalysisRequest(url: landing.managedURL, clipID: landing.clip.id,
                                                    assetID: landing.clip.mediaAssetID)
                    measuringClip = landing.clip.id
                }
            case .failure(let failure):
                importNote = failure.userMessage
            }
            #else
            importNote = AudioImport.Failure.unreadableAudio.userMessage
            #endif
        }
    }

    /// "Would Play start the song?" — the engine's own `canPlay`, with the four inputs `play`
    /// hands it (see `transportRow`). ONE call site in this file, so the transport's Play and the
    /// part bar's Play (M10) can never disagree. Evaluated in the caller's `body`, so the reads
    /// subscribe whichever view asks — the part bar's leaf, and this root through `transportRow`
    /// (which already made exactly these cold reads before M10).
    private func songCanStart() -> Bool {
        TimelineRegionPlayer.canPlay(
            timeline.document,
            clips: clipStore.filledClips,
            bpm: player.preflightTempo,
            resolveAudio: { player.audioLanes?.resolvedURL(forClipID: $0) })
    }

    /// Start the arrangement on the ONE transport. Everything this hands over is already
    /// owned elsewhere: the document by `TimelineStore`, the clock by `PatternEngine` (the
    /// player calls `pattern.play(cause: .timelineRegion)` itself), the notes by
    /// `PianoRollModel`. Nothing is constructed here.
    /// `fromTick` and `launching` are REQUIRED (#431): Play passes 0 and no parts (the song from
    /// the top), the Session view a scene's bar and its parts (Phase 3 / S2) — the player floors
    /// the tick to the bar and lands the parts on it inside the same call (S2 review, MED-1).
    private func startTimeline(fromTick: Int, launching: [UUID]) {
        player.play(document: timeline.document,
                    clips: clipStore,
                    pattern: beatPlayer.pattern,
                    pianoRoll: pianoRoll,
                    fromTick: fromTick,
                    launching: launching)
    }

}

/// WA4 Acceptance Test A inside the workspace — Save and Open for the song, on the plate where
/// the song is built. Until this row both doors sat only on the instrument plate
/// (`quickActionRow` / `quickDoorRow`), so the test's middle steps meant leaving the Workstation.
///
/// ⭐ IT OWNS NO STUDIO STATE, AND THAT DECIDES THE SHAPE. The Save alert (`showSaveDialog`) and
/// the Open sheet (`showOpen`) are the Studio's, on its existing modal chain; this leaf posts the
/// chrome door (`"save"` / `"open"`) and the Studio's receiver raises them — the
/// `TrackInspectorView.openDeviceButton` shape. No new modal, so the black-screen budget is
/// untouched, and the Save still goes through `saveProject()` → `withSession`, the ONE capture.
///
/// ⚠️ Enabled by the same FACTS as the Studio's tiles, not by the same VALUE: Save by a composed
/// take or a song holding the user's parts (`SessionSaveOpen.songHasUserParts`, asked — the one
/// predicate); Open by a non-empty library. The take half reads `pianoRoll.notes` because the
/// Studio's `hasComposed` is view-private `@State`. The two can disagree for up to one bar right
/// after a first Generate (the Studio arms `hasComposed` before the roll's next bar writes the
/// notes) — the Workstation's Save lights one bar later, never earlier (review of dc55c2d6e).
/// ⚠️ The reads sit in this leaf's own body, and `pianoRoll.notes` is written at every bar
/// boundary while a multi-bar arrangement plays, so this row rebuilds at BAR rate. That is safe
/// because it is its own leaf and hosts no `.menu` Picker; it must stay that way.
private struct WorkstationProjectRow: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clips
    @Environment(PianoRollModel.self) private var pianoRoll
    @Environment(ProjectStore.self) private var projects

    var body: some View {
        let canSave = !pianoRoll.notes.isEmpty
            || SessionSaveOpen.songHasUserParts(timeline.document, clips: clips.filledClips)
        let canOpen = !projects.projects.isEmpty
        HStack(spacing: 8) {
            door("Save", systemImage: "tray.and.arrow.down", object: "save", enabled: canSave,
                 spoken: "Save this session",
                 hint: "Names the session and saves it, with the song on this plate")
            door("Open", systemImage: "tray.and.arrow.up", object: "open", enabled: canOpen,
                 spoken: "Open a saved session",
                 hint: "Shows your saved sessions. Opening one replaces the song on this plate")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }

    private func door(_ title: String, systemImage: String, object: String, enabled: Bool,
                      spoken: String, hint: String) -> some View {
        Button {
            NotificationCenter.default.post(name: .echoelChromeDoor, object: object)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title).font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(spoken)
        .accessibilityHint(hint)
    }
}

/// S1 — one imported file's own tempo: a number field, and ÷2 / ×2 on their own line.
///
/// ⚠️ THE BUTTONS DO NOT SHARE THE FIELD'S LINE. A labelled field pins its box to a
/// Dynamic-Type-scaled width that does not compress; a field plus two 44 pt buttons in one
/// `HStack` overflows a portrait phone at larger text sizes (#1026/#1027, which the founder
/// rejected twice).
///
/// ⚠️ THE DRAFT IS CLEARED WHENEVER THE STORED TEMPO MOVES. A cancelled drag or one that ends
/// where it began fires no `onCommit`, so without the reset the field would keep showing a
/// stale draft after a ×2 or a late detection.
private struct PartTempoRow: View {
    let clip: Clip
    let lockedByWarp: Bool
    let measuring: Bool
    let songBPM: Double
    let onSet: (Double) -> Void

    @State private var draft: Double? = nil
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let known = clip.nativeBPM > 0
        VStack(alignment: .leading, spacing: 4) {
            Text(caption(known: known))
                .font(EchoelTheme.font(11))
                .foregroundStyle(EchoelTheme.dim)
            EchoelValueField(label: known ? "Tempo" : "Set tempo",
                             value: Binding(get: { shownValue }, set: { draft = $0 }),
                             range: AudioTempoCorrection.bounds,
                             unit: "BPM",
                             decimals: 1,
                             hint: hint(known: known),
                             onCommit: { commitDraft() })
            if known {
                HStack(spacing: 8) {
                    octaveButton("÷2", target: AudioTempoCorrection.halved(clip.nativeBPM),
                                 spoken: "Halve tempo")
                    octaveButton("×2", target: AudioTempoCorrection.doubled(clip.nativeBPM),
                                 spoken: "Double tempo")
                    Spacer(minLength: 0)
                }
            }
        }
        .disabled(lockedByWarp || measuring)
        .padding(.vertical, 6)
        .padding(.leading, 36).padding(.trailing, 10)
        .onChange(of: clip.nativeBPM) { _, _ in draft = nil }
    }

    private var shownValue: Double {
        draft ?? AudioTempoCorrection.startingValue(nativeBPM: clip.nativeBPM, songBPM: songBPM)
    }

    private func commitDraft() {
        guard let value = draft else { return }
        draft = nil
        onSet(value)
    }

    private func caption(known: Bool) -> String {
        if measuring { return "\(clip.name) · measuring tempo…" }
        if lockedByWarp { return "\(clip.name) · turn Warp off to change its tempo" }
        return known ? clip.name : "\(clip.name) · tempo not set — enter it to use Warp"
    }

    private func hint(known: Bool) -> String {
        if measuring { return "The file's tempo is still being measured." }
        if lockedByWarp { return "Turn Warp off to change this file's tempo." }
        return known
            ? "This file's own tempo. Warp uses it to fit the file to the song tempo."
            : "Not set. Starts at the song tempo; enter the file's own tempo to enable Warp."
    }

    @ViewBuilder
    private func octaveButton(_ glyph: String, target: Double?, spoken: String) -> some View {
        if let target {
            Button {
                draft = nil
                onSet(target)
            } label: {
                Text(glyph)
                    .font(EchoelTheme.font(12, .semibold))
                    .foregroundStyle(isEnabled ? EchoelTheme.text : EchoelTheme.dim)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.fill))
                    .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .strokeBorder(EchoelTheme.border, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken)
            .accessibilityHint("Sets this file's tempo to \(String(format: "%.1f", target)) BPM")
        }
    }
}

/// The `.task(id:)` key of an owed analysis: the managed copy to read AND the clip its tempo
/// belongs to, both taken from the import's `Landing` (S1-0). Equatable so a second import
/// restarts the task exactly when the pair changes.
private struct AnalysisRequest: Equatable {
    let url: URL
    let clipID: UUID
    /// The durable record the landing linked (MA4.4 learns its digest after the analysis).
    let assetID: UUID?
}

#endif
