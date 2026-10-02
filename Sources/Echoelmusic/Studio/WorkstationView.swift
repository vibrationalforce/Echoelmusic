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
// it looks, and slice F re-states WHY, because the old reason was the chip: since slice 2b
// this view is mounted by `ArrangeStage` on the Piece stage, not reached through the studio's
// `dropdownContent`, and it HOSTS menus itself — `TrackInspectorView` (and inside it, since DAW
// shell S4a, `SongAutomationEditor`) and `MediaBrowserView` are constructed only under this
// body, and they carry `.menu` pickers and a
// `Menu` — so a high-frequency read added to this body would rebuild them at that rate and
// tear down any open one. The law is in `.claude/skills/swiftui-render-safety/SKILL.md`; the
// reason it applies HERE is that this body is the menu host's ancestor.
//
// ⭐ THE DOOR STILL COSTS ZERO PRESENTATION MODIFIERS ON THE ROOT, and since slice F
// (2026-10-02) for a different reason: the door is no longer a `StudioMenu` chip but the stage
// seam in `StageShell` — a stage switch, not a modal — so `EchoelStudioView.body`'s aggregate
// generic type is untouched and the black-screen law (10.76.34) is not approached. ⛔ Until
// slice F this said the door was "a `StudioMenu` case in the existing chip strip"; that chip
// had become a second way to this stage and is retired (founder 2026-10-01: one way per area).
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
// and says nothing about whether a note is heard. (1) From the Instrument stage, the seam's
// Piece reaches this surface in one tap, and the chip strip offers no second way here (slice F
// retired the Workstation chip). (2) The seam's Instrument brings the instrument back on the
// plate it showed — no stuck panel.
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
// button that does it, "Add Audio Track", sits BESIDE it (design slice 4; above it when the pair
// stacks at large text), so the instruction is obeyable in one tap.
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
// song plays the switch is unavailable, and VoiceOver says "Stop the piece to change warp". (27)
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
// is dimmed and VoiceOver says "Stop the piece to change pitch". (41) The first Play after
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
    /// DMMW Phase 1 · slice 3 — the one clock's own run flag, read so this plate's Play/Stop
    /// says what the persistent project header says (`ProjectTransport`). Cold: `isPlaying`
    /// flips on a start or a stop, never per step. The tempo is NOT read here (claim N).
    @Environment(Transport.self) private var transport
    /// MA4.2 — the durable media identities an import registers. Read only in the import
    /// handler, never in `body`.
    @Environment(MediaAssetStore.self) private var mediaAssets
    /// A SETTING, not a signal: it changes when the user changes the text size, never while a
    /// song plays, so reading it in `body` subscribes to nothing hot. `transportRow` stacks
    /// Play and the position readout on it (review of e1036b874, MED).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// A9: `.compact` on an iPhone in landscape — the plate's two-column switch.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Audio Import V1 — picker + result, both LOCAL to this leaf on the founder's
    /// instruction. Neither is persisted, neither is read by any other surface, and neither
    /// is hot: `importPresented` flips on a tap, `importNote` on a completed pick. Putting
    /// either in the permanent Studio root would have made the whole Studio rebuild on a
    /// file-picker dismissal, and `importNote` would have become a sixth thing the root
    /// carries between plate switches for no reason.
    @State private var importPresented = false
    @State private var importNote: String?
    /// DMMW Phase 1 — the outcome of the compose guide's own step, shown IN the guide (review of
    /// c672c2adf). View state only.
    @State private var guideNote: String?

    /// S2 — which file the ONE importer is asking for. One `.fileImporter` whose content type
    /// switches, never a second one: two importers on one view is the shape that can shadow a
    /// picker (#W1), and `TheWorkstationImportsAudioTests` pins the prefix of this one.
    /// Local and cold, like the two above — it changes on a tap.
    private enum ImportKind { case audio, midi }
    @State private var importKind: ImportKind = .audio
    /// DAW shell S2 (founder 2026-10-02, inbox E18): what the plate shows — the arrangement, the
    /// whole-piece mixer (`PieceMixerView`), the browser (the media library and the photo/video
    /// seeds) or the project (save, open, export). Written ONLY by the bottom switcher in
    /// `StageShell`; read here. A view choice, not part of the song — but persisted, so the piece
    /// reopens where it was left. COLD: a tap writes it, never a tick.
    /// ⛔ `@State private var plate: PlateView` stood here (B3, Arrange · Mix tiles in this view's
    /// own tab row). Two owners of "which plate" — the tiles here and the switcher there — would
    /// disagree, so the tiles left with this key's arrival.
    @AppStorage(StudioDefaultKeys.pieceView.key)
    private var pieceViewRaw = StudioDefaultKeys.pieceView.value.rawValue
    private var pieceView: PieceView { PieceView(rawValue: pieceViewRaw) ?? StudioDefaultKeys.pieceView.value }

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
        // Workstation redesign A3 (founder 2026-10-01, the tablet mockup): the plate scrolls, the
        // transport does NOT. It used to sit in the middle of this stack, so a song longer than
        // the screen scrolled its own Play out of reach. The scroll moved IN here from
        // `ArrangeStage` so the transport can be pinned beneath it with `.safeAreaInset` — no
        // overlay, no modal, and the stack below keeps every row it had except that one.
        // The stack is deliberately NOT re-indented under `ScrollView {`: a whitespace-only move of
        // ~150 lines would bury the one real change and shift every guard's context for nothing.
        ScrollView {
        VStack(alignment: .leading, spacing: 10) {
            // DMMW Phase 1 (founder 2026-09-29) — "show at once how to make a piece": the five
            // steps, read off the song (`ComposeGuide`); open, the card draws the step to do now
            // (founder 2026-10-01, "zu groß" — `ComposeGuide.shownSteps`); each is a door that
            // already exists below.
            // Its own leaf with no store reads; everything it shows is handed in from the cold
            // reads this body already makes (document, clip grid, `isPlaying`).
            // DAW shell S2: the guide stays FIRST and draws itself on the Arrange plate only
            // (`composeGuide`). Browse and Project are plates of their own; Arrange and Mixer share
            // the song's branch below. The stack is not re-indented under the new `if` (see A3).
            composeGuide
            if pieceView == .browse {
                browsePlate
            } else if pieceView == .project {
                projectPlate
            } else {
            if summary.isEmpty {
                emptyState
            } else if pieceView == .mixer {
                // B3 — the mixer stands INSTEAD of the arrangement and its track column, never
                // beside them: a strip's Mute and the track header's Mute are one fact, so they
                // are never on screen together (one control per fact on screen).
                songLine(summary)
                PieceMixerView(voiceCapacity: player.laneVoiceCapacity)
            } else {
                songLine(summary)
                // WA4 path 4 — the arrangement: every track's parts on the one shared scale,
                // a part selected by tapping it. Handed the document this body already read;
                // the canvas observes the selection and the clip grid (its note sketches, design
                // slice 11 — both cold), and the playhead is its own leaf.
                // (Replaces the WA4.5 per-row strips — one picture of the song, not two.)
                let arrangeRows = ArrangeCanvas.rows(summary)
                let open = WorkstationSelection.resolvedTrack(selection.trackID, in: timeline.document)
                // A9 (founder 2026-10-01, the tablet mockup): in landscape the arrangement and the
                // open track's head stand SIDE BY SIDE — canvas, part bar and editors on the left,
                // the track column on the right — instead of the head scrolling a screen below the
                // lane it names. Portrait stacks them exactly as before. `AnyLayout` keeps every
                // child's identity across a rotation, so the open track's chosen detail page (Track,
                // Part, Notes, Automation, Device) stays chosen — the measured reason this file gives
                // for the transport readout. Only with a drawn canvas: a song with no parts has
                // nothing to sit beside. ⚠️ Size class is an environment value, not hot state.
                // (The plan's third column — the visual — is the floating card over the plate.)
                let sideBySide = verticalSizeClass == .compact && !arrangeRows.isEmpty
                let columns = sideBySide
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                columns {
                if !arrangeRows.isEmpty {
                  VStack(alignment: .leading, spacing: 10) {
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
                    // ⛔ The selected part's notes (Phase 3 / M1) and the track's curve
                    // (Automation A1) stood HERE, each behind a switch of its own. DAW shell S4a
                    // (founder 2026-10-02, the approved shell) made them the Notes and Automation
                    // pages of the track's ONE detail area (`TrackInspectorView`, below or beside),
                    // so a part's editors sit on the same page control as its track and device.
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                }
                // ⛔ The ONE Undo/Redo (`SongHistoryRow`, WA4 path 7) stood HERE, under the note
                // grid — M6's review put it at "the closest place to the edit it takes back".
                // Head leaf 3 of the interface audit (2026-09-30) moved it into `ProjectHeader`:
                // this spot exists on the Piece stage only, and the Instrument stage writes the
                // composer's part into the same history with no Undo in reach. One control, one
                // address — the head, above both stages, always on screen.
                // A5 (founder 2026-10-01): the canvas gutter is the head of every track it draws,
                // so the list below keeps a card only for the OPEN track (its head: the facts and
                // the one Mute/Solo) and for tracks the canvas cannot draw (`listsCard`). Every
                // track still has exactly one head; nothing appears twice on the plate.
                VStack(alignment: .leading, spacing: 10) {
                if sideBySide && open == nil { trackColumnHint }
                ForEach(summary.lanes) { row in
                    if ArrangeCanvas.listsCard(row.id, open: open, canvasRows: arrangeRows) { laneRow(row) }
                    if open == row.id {
                        // The mixer and device facts of the ONE open track. Its own leaf, with
                        // its own store reads — this view still sends `timeline` nothing but
                        // `document`.
                        // DAW shell S4b: the arm, an audio track's pitch and its files' tempo are
                        // rows OF the open track's detail — Track page and Part page — instead of
                        // three loose rows under it. Built here (they read this view's transport
                        // and measuring state, exactly as before) and placed by the inspector.
                        TrackInspectorView(laneID: row.id) {
                            // Phase 3 / Recording R1 — record-arm, on a rack MIDI track only.
                            TrackArmToggle(laneID: row.id)
                            // An audio track's pitch belongs to its open head (A5) — under a card
                            // that is gone it would dangle.
                            if row.kind == .audio { pitchField(row) }
                        } part: {
                            if row.kind == .audio { partTempoRows(laneID: row.id) }
                        }
                        .id(row.id)
                    }
                }
                }
                .frame(minWidth: sideBySide ? 260 : 0, maxWidth: sideBySide ? 360 : CGFloat.infinity,
                       alignment: .leading)
                }
                if summary.orphanRegionCount > 0 { orphanLine(summary.orphanRegionCount) }
                if summary.automationLaneCount > 0 { automationLine(summary.automationLaneCount) }
            }
            // DAW shell S5: the Mixer ends in its master — after the track strips, and OUTSIDE the
            // empty-song branch above, because an empty song still plays the instrument and its
            // master level must stay reachable. Its own file; this body reads nothing hot for it.
            if pieceView == .mixer {
                MasterStripView()
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
            //
            // ⭐ A3: `transportRow` is no longer a row of this stack — it is the pinned bar under
            // the scroll (`transportBar`, at the end of `body`). Same row, same one start.

            // MARK: - The Session projection (WA4.2)
            //
            // The same song, launched live: parts and scenes loop on their track from the next
            // bar. Its own leaf, because launching reaches the player for members this file's
            // transport is not authorised to call (`TheWorkstationPlaysTheTimelineTests` B).
            // S2: it may START the song at a scene, through this file's own transport.
            if pieceView == .arrange {
                SessionLaunchView(playFrom: { tick, parts in startTimeline(fromTick: tick, launching: parts) })
            }

            // MARK: - The import door (Audio Import V1, founder 2026-09-22)
            //
            // ⭐ THE FIRST REACHABLE PRODUCER OF AN AUDIO-BEARING REGION. Until this row the
            // only path that could mint one was `RecordController` → `TakeRecorder` →
            // `AudioClipFactory`, and `arm()` had zero callers (#204/#527) — so
            // `AudioLanePlayer` walked `doc.audioLaneIDs` on every transport step and found
            // nothing, for four months, with the engine shipped and injected the whole time.
            // MARK: - The lane door (founder 2026-09-23, unblocking the #E3 hold)
            //
            // ⭐ IT COMES BEFORE IMPORT BECAUSE THAT IS THE ORDER OF THE SENTENCE the Import
            // door's refusal speaks: "add an audio track first". Until this row that sentence
            // named an action no production path could perform — `bootstrapIfNeeded`,
            // `addLane` and `addInstrumentTrack` each had zero callers outside
            // `Core/TimelineStore.swift`, so a fresh `TimelineDocument()` stayed `lanes: []`
            // forever and the import door was unreachable on a clean install.
            // ⭐ PAIRED WHILE THEY FIT (modes census 2026-09-26, design slice 4): five
            // full-width-stacked doors pushed the song itself below the fold on a phone. Each
            // track door now sits BESIDE its import, left to right in the old top-to-bottom
            // order, and stacks again at sizes where the pair does not fit. The refusals name
            // the doors by LABEL ("add an audio track first"), never by position, so moving
            // them beside each other changes no sentence.
            // ⭐ UX audit 2026-10-02, slice 4: the five doors stand ONLY on the empty plate — the
            // one that names them (`emptyState`, same `summary.isEmpty`). Once the piece has a
            // track they live in the tab row's "Add" menu (`addMenu`), which calls the same five
            // actions, so the song is no longer pushed down by five full-width buttons and the
            // doors and the menu are never on screen together. The one note line follows the
            // doors: here under them on the empty plate, under the Add tile in the pinned tab row
            // once the piece has a track (review of slice 4 — a refusal written a screen below
            // the tile that was tapped reads as a tap that did nothing).
            if summary.isEmpty {
                creationPair {
                    addTrackRow
                    importRow
                }
                // S2 — the MIDI pair, in the same order and for the same reason: the refusal
                // "add a MIDI track first" names the door beside Import MIDI.
                creationPair {
                    addMIDITrackRow
                    importMIDIRow
                }
                // Phase 3 / M1b — an EMPTY part for the note editor, so writing notes does not
                // need a MIDI file. Same lane and refusals as Import MIDI (`MIDIImport`).
                newMIDIPartRow
                if let note = importNote { importNoteLine(note) }
            }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(2)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { transportBar }
        .safeAreaInset(edge: .top, spacing: 0) { pieceTabs }
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
            guard !parts.isEmpty else { return }
            let summary = parts.joined(separator: " ")
            guard importNote == base else { return }
            importNote = base.map { $0 + " " + summary } ?? summary
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
            Text("Add Audio Track or Add MIDI Track to begin. A file you import becomes a part you can play, and a new MIDI part plays once it has notes.")
                .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        // One spoken sentence rather than two fragments — VoiceOver would otherwise read the
        // heading and the explanation as unrelated items.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No tracks yet. Add Audio Track or Add MIDI Track to begin. A file you import becomes a part you can play, and a new MIDI part plays once it has notes.")
    }

    private func songLine(_ summary: WorkstationSummary) -> some View {
        let tracks = summary.lanes.count
        let parts = summary.regionCount
        let bars = summary.lengthBars
        return HStack(spacing: 10) {
            // E4-24: the count is a number, the noun is a catalog key per grammatical number
            // (German: Spur/Spuren · Teil/Teile · Takt/Takte). Never a format key (#E4 law).
            Text("\(tracks) " + (tracks == 1 ? String(localized: "track") : String(localized: "tracks")))
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(parts) " + (parts == 1 ? String(localized: "part") : String(localized: "parts")))
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(bars) " + (bars == 1 ? String(localized: "bar") : String(localized: "bars")))
            Spacer(minLength: 0)
        }
        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Arrangement: ") + "\(tracks) " + String(localized: "tracks") + ", "
                            + "\(parts) " + String(localized: "parts") + ", "
                            + "\(bars) " + String(localized: "bars long"))
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
                .accessibilityHint(selected ? String(localized: "Closes this track's details")
                                            : String(localized: "Opens this track's details: its device, and its mixer and parts where it has them"))
            // ⚠️ OUTSIDE the combined element, on purpose: `.combine` on the row swallowed the
            // tuning banner's recovery button once (#621) — a control inside a merged element
            // loses its own focus and hint. The facts are ONE sentence; the switch is a switch.
            // B3c: a tap is a whole gesture — one write inside it, closed at once: ONE Undo step
                // (`TrackMix.tapStep` opens and closes it, so this view sends the store no message).
            if let role = muteSoloRole {
                headerSwitch("M", name: String(localized: "Mute"), on: row.isMuted, hint: TrackMix.muteHint(role)) {
                    TrackMix.tapStep(laneID: row.id, timeline: timeline) { TrackMix.flipMute(laneID: row.id, timeline: timeline) }
                }
                headerSwitch("S", name: String(localized: "Solo"), on: row.isSoloed, hint: TrackMix.soloHint(role)) {
                    TrackMix.tapStep(laneID: row.id, timeline: timeline) { TrackMix.flipSolo(laneID: row.id, timeline: timeline) }
                }
            }
            if row.kind == .audio { warpSwitch(laneID: row.id) }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        // Selection is never colour alone (Zug 4, 2026-09-30): the stroke also THICKENS, the
        // way a selected part does in `TrackPartsView` and on the arrange canvas — a reader
        // who cannot tell the green from the border still sees which row is open.
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(selected ? EchoelTheme.accent : EchoelTheme.border,
                          lineWidth: selected ? 2 : 1))
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
        .accessibilityValue(on ? String(localized: "On") : String(localized: "Off"))
        .accessibilityHint(hint)
    }

    private func laneFacts(_ row: WorkstationSummary.LaneRow, headerSwitches: Bool) -> some View {
        // A8 (founder 2026-10-01) — the header wears the SAME identity as the track's canvas
        // gutter (A1): one hue band and the instrument's symbol in that hue, from the one switch
        // `EchoelTheme.TrackHue`. The open card then reads as belonging to the ringed canvas row;
        // the hue never travels without the symbol and the name (never colour alone).
        let hue = EchoelTheme.TrackHue.of(kind: row.kind, instrument: row.instrument, isBio: row.isBio)
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(hue.color)
                .frame(width: 3)
                .frame(minHeight: 28)
            Image(systemName: EchoelTheme.TrackHue.symbol(kind: row.kind, instrument: row.instrument,
                                                          isBio: row.isBio))
                .foregroundStyle(hue.color)
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
                    .font(EchoelTheme.font(11, .semibold))
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
            // E4-43: the spoken value was a nested ternary of bare literals — a String, read verbatim on
            // a German phone. Two typed steps, each arm a catalog key; no `+` and no nesting in a ternary.
            let mixedValue: String = state == .mixed ? String(localized: "On for some parts") : String(localized: "Off")
            let warpValue: String = on ? String(localized: "On") : mixedValue
            Button {
                // Mixed → all on: the tap resolves the ambiguity toward the switch's name.
                AudioWarp.setWarp(!on, laneID: laneID, timeline: timeline,
                                  clipStore: clipStore, bpm: player.preflightTempo)
            } label: {
                Text(state == .mixed ? String(localized: "Warp · some") : String(localized: "Warp"))
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
            .accessibilityLabel("Warp to piece tempo")
            .accessibilityValue(warpValue)
            .accessibilityHint(playing
                ? String(localized: "Stop the piece to change warp")
                : String(localized: "Plays this track's parts at the piece's tempo instead of their recorded speed"))
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
                    ? String(localized: "Stop the piece to change pitch")
                    : String(localized: "Moves every part on this track up or down without changing its tempo"),
                standard: Double(TimelineLane.defaultTransposeSemitones))
            .disabled(playing)
            // S4b: no indent of its own — it sits inside the inspector's padding now.
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
        if row.isBio { text += String(localized: " · bio curve") }
        switch row.regionCount {
        case 0:  text += String(localized: " · no parts")
        case 1:  text += String(localized: " · 1 part")
        default: text += " · \(row.regionCount) " + String(localized: "parts")
        }
        if let first = row.firstTick, let last = row.lastTick, row.regionCount > 0 {
            // One spelling of the span, shared with the spoken form — an en dash here and the
            // word "to" there, but the same two bar numbers (#416).
            text += " · " + WorkstationSummary.barSpan(firstTick: first, lastTick: last,
                                                       joiner: "–")
        }
        if !row.playsOnTheTimeline && row.regionCount > 0 { text += String(localized: " · no engine yet") }
        return text
    }

    /// Only the states that are ON. A row of greyed-out "not muted, not soloed, not armed"
    /// badges would be three pieces of chrome saying nothing.
    /// Where the header draws Mute/Solo switches, their state is ON the switch; a tag beside
    /// it would say the same fact twice. A track without the switches keeps the tags — a stored
    /// mute on a bio lane is still a fact worth showing.
    private func stateTags(_ row: WorkstationSummary.LaneRow, headerSwitches: Bool) -> [String] {
        var tags: [String] = []
        if row.isMuted && !headerSwitches { tags.append(String(localized: "MUTE")) }
        if row.isSoloed && !headerSwitches { tags.append(String(localized: "SOLO")) }
        if row.isArmed { tags.append(String(localized: "ARM")) }
        return tags
    }

    private func orphanLine(_ count: Int) -> some View {
        Text("\(count) " + (count == 1 ? String(localized: "part belongs") : String(localized: "parts belong"))
             + String(localized: " to a track this piece no longer has."))
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(count) " + String(localized: "parts belong to a track this piece no longer has"))
    }

    /// A9: the landscape track column with no track open says how to fill it (rule 10 —
    /// an empty state offers the next step, not a recipe).
    private var trackColumnHint: some View {
        Text("Tap a track name to open it here")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    private func automationLine(_ count: Int) -> some View {
        Text("\(count) " + (count == 1 ? String(localized: "automated parameter") : String(localized: "automated parameters")))
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
    }

    /// DAW shell S2 — the BROWSE plate: the sounds (S6), the media library and the two seeds that
    /// shape the visual. Each is its own leaf with its own state; this view reads none of it.
    /// ⛔ These three stood at the foot of the arrangement's scroll, under the project row, grouped
    /// to keep the stack under ten children (#936). On their own plate they no longer push the
    /// song down, and the browser is one tap from anywhere (the switcher), as in every DAW.
    private var browsePlate: some View {
        VStack(alignment: .leading, spacing: 10) {
            // DAW shell S6 — the stored sounds, in store order; a tap gives the open synth
            // track that sound through the Device page's own seam (one Undo step). Its own leaf.
            SoundBrowserView()
            // Phase 3 / MA1 — the media library: the audio files already imported, and "Place"
            // to put one on the song again without Files, a second copy or a second clip slot.
            // Its own leaf: it lists the directory detached and writes through
            // `MediaPlacement`; this view reads none of its state.
            MediaBrowserView()
            // MS3 (founder order 2026-09-27) — a photo's colour, brightness and contrast shape
            // the live visual, with Undo. Its own leaf beside the library: it presents the
            // system photo picker itself (no modifier here) and this view reads none of its state.
            #if canImport(PhotosUI) && canImport(ImageIO)
            PhotoSeedCard()
            #endif
            // MV2: the same for a short video — brightness, colour and picture change shape the
            // visual, and its length is read in bars. Its own leaf; one shared Undo with the photo.
            #if canImport(PhotosUI) && canImport(AVFoundation)
            VideoSeedCard()
            #endif
        }
    }

    /// DAW shell S2 — the PROJECT plate: the song's settings, and the piece handed away as a MIDI
    /// file (`SongExportTab`, B4) or as audio (`PieceAudioExportTab`, UX audit 10b). Every
    /// control here acts in place; nothing adds a presentation modifier (both export tiles are
    /// `ShareLink` leaves). Save and Open left this plate with S3 — they are the ≡ menu's.
    /// ⭐ AT EVERY LEVEL (E19 „Nur im Detail"): the two export tiles stood behind
    /// `level.showsSongs` in the old tab row. A level hides FIELDS in the detail area, never a
    /// whole way to get the piece out of the app.
    private var projectPlate: some View {
        VStack(alignment: .leading, spacing: 10) {
            // DAW shell S1a (founder 2026-10-02, E18): the SONG's settings — Key · Scale · Tone
            // system · Note names · A4 · Tempo mode — first, as every DAW's project page does.
            // The row stood in the always-visible chrome until S1a; it is the same leaf (cold
            // `@AppStorage` reads, its one churny label in `SessionNamePreviewLeaf`), so moving
            // it adds no hot read here. Not clamped: the plate grows with the user's text size,
            // and the row scrolls sideways instead of overflowing.
            CompositionHeaderStrip()
            HStack(spacing: 6) {
                SongExportTab()
                // UX audit slice 10b: the whole piece as audio, beside the MIDI export.
                PieceAudioExportTab()
            }
        }
    }

    /// The arrangement's toolbar, pinned above the plate's scroll on the ARRANGE plate once the
    /// piece has a track: the one "Add" menu and the note line its actions write.
    /// ⛔ DAW SHELL S2 (founder 2026-10-02, inbox E18): this was the piece's TAB ROW — Arrange ·
    /// Mix · Export · WAV · Add (A7, B3, B4, slices 10b and 4). Arrange and Mix are entries of the
    /// bottom switcher now (`StageShell.shellSwitcher`), Export and WAV live on the Project plate.
    /// Two rows that both switch the plate would be two owners of one choice; the row keeps only
    /// what belongs to the arrangement itself. EVERY CONTROL HERE STILL ACTS IN PLACE: it posts no
    /// chrome door and never turns the stage.
    /// (Before slice 4 the creation doors stood full width under the song; on the empty plate they
    /// still do, named by `emptyState` — same predicate, so the menu and the doors never meet.)
    private var pieceTabs: some View {
        let hasTrack = !WorkstationSummary(document: timeline.document).isEmpty
        return Group {
            if pieceView == .arrange && hasTrack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        // UX audit slice 4: every way to add something, in one menu — once the piece
                        // has a track. Before that the empty plate shows the five doors itself (same
                        // predicate, `WorkstationSummary.isEmpty`), so the menu and the doors never
                        // stand together. At every level: the doors it replaces stand at every level.
                        addMenu
                        Spacer(minLength: 0)
                    }
                    // Review of slice 4: the Add menu's outcome is said under the Add tile, not a
                    // screen below it. Dismissible, because this row is pinned and a long import
                    // note would otherwise hold its height until the next action.
                    if let note = importNote {
                        pinnedNoteLine(note)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EchoelTheme.bg)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(EchoelTheme.border).frame(height: 1)
                }
            }
        }
    }

    /// The note line where the Add menu sits: the same text as `importNoteLine`, plus a way to
    /// clear it, since the pinned row keeps whatever height the note takes.
    private func pinnedNoteLine(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            importNoteLine(note)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                importNote = nil
            } label: {
                Image(systemName: "xmark")
                    .font(EchoelTheme.font(12, .semibold))
                    .foregroundStyle(EchoelTheme.dim)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
    }

    /// UX audit slice 4 — "Add": the five creation actions in one menu, so a piece with tracks
    /// shows its song instead of five full-width buttons. Each item calls the SAME function as
    /// its door on the empty plate (#416); the menu adds no action of its own, and its items keep
    /// the doors' words, which the refusals name ("add an audio track first").
    /// ⚠️ A `Menu`, not a modal: it adds nothing to a presentation chain (black-screen law), and
    /// the importer it opens is the one `.fileImporter` this view already has.
    private var addMenu: some View {
        Menu {
            Section {
                Button { addAudioTrack() } label: { Label("Add Audio Track", systemImage: "plus") }
                Button { openImporter(.audio) } label: { Label("Import Audio", systemImage: "square.and.arrow.down") }
            }
            Section {
                Button { addMIDITrack() } label: { Label("Add MIDI Track", systemImage: "plus") }
                Button { openImporter(.midi) } label: { Label("Import MIDI", systemImage: "pianokeys") }
                    .accessibilityLabel("Import MIDI file")
                Button { newMIDIPart() } label: { Label("New MIDI Part", systemImage: "square.grid.3x3") }
                    .accessibilityHint(MIDIImport.newPartHint)
            }
        } label: {
            EchoelIconTile(systemImage: "plus", title: "Add")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .accessibilityHint("Adds a track, imports an audio or MIDI file, or starts a new MIDI part")
    }

    /// A3 — `transportRow` pinned under the plate's scroll: a solid bar with a 1 px top border
    /// (Uncodixfy: no blur, no shadow), the plate's own side inset. Built once, in `body`'s
    /// `.safeAreaInset`, so the scroll's content ends above it instead of under it.
    private var transportBar: some View {
        transportRow
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoelTheme.bg)
            .overlay(alignment: .top) {
                Rectangle().fill(EchoelTheme.border).frame(height: 1)
            }
    }

    /// Play / Stop for the arrangement. ONE button, because there is one thing to say:
    /// the song is running or it is not. A separate greyed Stop beside a Play would be two
    /// claims where the state has one — the #305 lesson from the instrument's own row, where
    /// two controls carrying the same glyph meant different things. Since A3b that one button
    /// is the head's own (`ProjectPlayStopButton`), standing here while the piece is in front.
    private var transportRow: some View {
        // `canPlay` is the engine's own guard, asked here so the control matches it exactly.
        // `isPlaying` is the player's only hot-ish observable on this path and it changes
        // TWICE per take, not per step (`currentTick` is `@ObservationIgnored` precisely so
        // a reader like this one cannot subscribe to the ~8 Hz position).
        let playing = player.isPlaying
        // DMMW Phase 1 · slice 3 — ONE running truth. The button reads the one clock too, so it
        // says Stop while the instrument plays the music, exactly as the project header does;
        // `playing` (the song) still gates the song's own position, meter and caption.
        let running = ProjectTransport.isRunning(clockRunning: transport.isPlaying, songPlaying: playing)
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
        // ⭐ DESIGN SLICE C (founder 2026-10-01: "Viele Bereiche sind zu groß und füllen den
        // Bildschirm aus. Vermeide slop."): the bar is ONE row. Until this slice it stacked Play,
        // a caption, Record and Record's own caption — about 150 pt of a 667-pt phone, pinned
        // under an arrangement that had about 121 pt left. A sentence now stands under the row
        // ONLY when it says what no button can: that nothing can start yet, that the INSTRUMENT
        // is what Stop would end, or what blocks a recording (`RecordTakeNote`). A sentence that
        // restates a button ("Plays the piece's parts from the top.", "Playing from bar 9 …") is
        // no longer drawn: the button's word and its VoiceOver hint carry it, and the head shows
        // the position. ⚠️ So `transportCaption` is reached here ONLY for an unplayable piece;
        // its other branches stay pure and pinned (D1b) until the founder confirms the cut.
        // Review of e1036b874 (MED) still holds: at accessibility sizes the controls stack, and
        // `AnyLayout` (not a whole-row `ViewThatFits`) keeps each control's identity across it.
        let controls = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 4) {
          controls {
            // A3b (workstation redesign): the ONE Play / Stop — the head's own button, which the
            // head drops while this stage is in front (`ProjectPlayStopButton`, ProjectHeader.swift).
            // Same word, same spoken label, same resume of a held instrument, the same Stop for
            // everything, and the space bar with it. `running` and `startable` above still drive
            // the note line and the Record door; this view decides nothing about Play.
            ProjectPlayStopButton(source: "workstation")

            // Design slice 10 — the click, armed where the song is played. Its own leaf: this
            // view names no voice, and the leaf reads only the cold on/off.
            WorkstationClickToggle()

            // Phase 3 / Recording R1 — the MIDI take, started through THIS row's one start
            // (from the top) and stopped by the same Stop. A leaf in its own file: this view
            // names neither the recorder nor its controller. Slice C: in the row, not under it,
            // and it draws no caption of its own — its sentence is its hint, its blocker is
            // `RecordTakeNote` below.
            RecordTakeButton(playing: playing, startable: startable,
                             voiceCapacity: player.laneVoiceCapacity,
                             startSong: { startTimeline(fromTick: 0, launching: []); return player.isPlaying },
                             stopSong: { player.stop() })

            // Design slice 13 — the mix level while the piece plays (its own leaf: the level is
            // rewritten at 60 Hz, and this row names no engine), and design D1's position beside
            // it ONLY where the row has room. The head counts the same position on every stage
            // (`ProjectPositionReadout`), so on a phone in portrait the readout is the one that
            // yields: `layoutPriority(-1)` lets Play, Click and Record take their width first,
            // and `ViewThatFits` falls back to the meter alone. ONE construction of each leaf —
            // `meter` is the same value in both candidates.
            if playing {
                let meter = WorkstationMixMeter()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        meter
                        SongPositionReadout()
                    }
                    meter
                }
                .layoutPriority(-1)
            }
          }
            if !playing && (running || !startable) {
                Text(running
                     ? ProjectTransport.instrumentRunningCaption
                     : WorkstationSummary.transportCaption(playing: playing, startable: startable,
                                                           fromTick: player.startedFromTick))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)   // the button's own hint already carries this
            }
            // Slice C — what blocks a recording, and a recording the grid had no room for. Draws
            // nothing when Record is ready, running or recording (its word says it).
            RecordTakeNote(playing: playing, startable: startable,
                           voiceCapacity: player.laneVoiceCapacity)
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
    /// nothing — it always appends a track. Since slice 4 this button stands only on the empty
    /// plate; once a track exists the SAME action is "Add Audio Track" in the Add menu, so a
    /// second audio track stays one tap away (⛔ hiding it with no other way in would be a
    /// surface that lies by omission).
    ///
    /// ⚠️ ⛔ "NO RESULT LINE, DELIBERATELY" stood here: the new track appeared in the rows above.
    /// From the Add menu it is appended BELOW, often off screen, so `addAudioTrack()` now selects
    /// it and names it on the note line, as "Add MIDI Track" does. The `importNote = nil` first
    /// still matters: the note most likely on screen is "add an audio track first".
    private var addTrackRow: some View {
        Button {
            addAudioTrack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(EchoelTheme.font(13, .semibold))
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
        .accessibilityHint("Adds an empty audio track to the piece, ready for an import")
    }

    /// Two creation doors side by side while they fit, stacked otherwise — the
    /// `WorkstationProjectRow` shape (Save | Open). The HORIZONTAL candidate comes first:
    /// `ViewThatFits` takes the first that fits, by each candidate's ideal width, which grows
    /// with the text (`EchoelTheme.font` scales with Dynamic Type). None of these doors scales
    /// its text down; the claim that a `minimumScaleFactor` would make the row always "fit" is
    /// inherited from BioStripView and unmeasured (review of 60f1bd2ab), so it is kept out
    /// rather than argued. The two pairs decide independently: at an in-between size one can
    /// sit side by side while the other stacks.
    private func creationPair<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content()
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
    }

    /// "Import Audio" — one button on the empty plate; once the piece has a track, the same
    /// action is an item of the Add menu (UX audit slice 4, founder 2026-10-02: "Vermeide, dass
    /// es unübersichtlich ist"). ⛔ "no menu" stood here from Audio Import V1, whose instruction
    /// was a single action inside the existing plate — recorded in the founder inbox (E17). ⛔ This said "no browser — the surface this phase was told
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
            openImporter(.audio)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(EchoelTheme.font(13, .semibold))
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
        .accessibilityHint("Adds an audio file to the piece's audio track")
    }

    /// S2 — "Add MIDI Track": `addTrackRow`'s twin. The store is handed to
    /// `MIDIImport.addMIDITrack`, never messaged (claim F). It always appends.
    ///
    /// ⚠️ A MIDI TRACK IS WHERE THE INSTRUMENT'S COMPOSER WRITES, so this row changes more than
    /// the plate: the next Start mirrors the composed take onto this track (one clip slot),
    /// unless a user part already sits at its start — then the composer yields.
    private var addMIDITrackRow: some View {
        Button {
            addMIDITrack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(EchoelTheme.font(13, .semibold))
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
        .accessibilityHint("Adds an empty MIDI track to the piece, ready for an import")
    }

    /// S2 — "Import MIDI": the same importer as `importRow`, asked for a MIDI file. Never
    /// disabled, for `importRow`'s reason: every outcome is known only after the pick, and each
    /// one says what happened (`MIDIImport.Failure.userMessage`).
    private var importMIDIRow: some View {
        Button {
            openImporter(.midi)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pianokeys")
                    .font(EchoelTheme.font(13, .semibold))
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
        .accessibilityHint("Adds a MIDI file's notes to the piece's first MIDI track")
    }

    /// Phase 3 / M1b — "New MIDI Part": an empty part on the MIDI track, selected at once so the
    /// part bar and the track's Notes page open on it. The stores are handed to
    /// `MIDIImport.addEmptyPart`, never messaged (claim F); selecting reads only `document`.
    ///
    /// ⚠️ NEVER DISABLED, for `importMIDIRow`'s reason: a missing track or a full clip grid is
    /// known to the plan, and each refusal says so in words on the one note line.
    private var newMIDIPartRow: some View {
        Button {
            newMIDIPart()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3")
                    .font(EchoelTheme.font(13, .semibold))
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
        .accessibilityHint(MIDIImport.newPartHint)
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
                    .first { $0.id == landing.laneID }?.name ?? String(localized: "the MIDI track")
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
                    .first { $0.id == landing.laneID }?.name ?? String(localized: "the audio track")
                importNote = AudioImport.successNote(landing, laneName: laneName)
                learnContentDigest(of: landing)
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
                    tuningPending = AnalysisRequest(url: landing.managedURL, clipID: landing.clip.id)
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

    #if canImport(AVFoundation)
    /// MA4.4 — the content evidence of a record THIS landing created: its SHA-256, streamed in
    /// chunks off the main actor and added to that record, through `MediaContentDigest.learnMinted`
    /// (MA4.4d — the rule and the task live there, shared with the browser's Place).
    /// ⚠️ NOT THE ANALYSIS TASK (review of 66d37a8c5, M1): `.task(id: tuningPending)` is
    /// cancelled by the next import tap and by leaving the Workstation, and nothing would ever
    /// hash that file again — `learnMinted` starts its own bounded task, which survives both.
    /// ⭐ MA4.4c — THE QUESTION IS "WAS A RECORD MINTED", NOT "WAS THE FILE COPIED". A fresh copy
    /// and an orphan library file without a record both get a new record here, and both are
    /// hashed; an ADOPTED record is not (review L1: it may be a legacy record whose evidence
    /// predates its binding — a relink backfills it, not an import). Only `establishIdentity`
    /// knows which happened, so the door reads its answer (`mintedAssetRecord`) instead of
    /// inferring it from `reusedLibraryFile` — the inference was the gap the re-review of
    /// `292d2d4c8` found. The guard and the task are `MediaContentDigest.learnMinted` (MA4.4d).
    private func learnContentDigest(of landing: AudioImport.Landing) {
        #if canImport(CryptoKit)
        // MA4.4d: the rule and the task live in `learnMinted`, shared with the browser's Place.
        MediaContentDigest.learnMinted(recordID: landing.clip.mediaAssetID,
                                       minted: landing.mintedAssetRecord,
                                       from: landing.managedURL, into: mediaAssets)
        #endif
    }
    #endif

    /// "Would Play start the song?" — the engine's own `canPlay`, with the four inputs `play`
    /// hands it (see `transportRow`). ONE call site in this file, so the transport's Play and the
    /// part bar's Play (M10) can never disagree. Evaluated in the caller's `body`, so the reads
    /// subscribe whichever view asks — the part bar's leaf, and this root through `transportRow`
    /// (which already made exactly these cold reads before M10).
    private func songCanStart() -> Bool {
        Self.songCanStart(player: player, timeline: timeline, clipStore: clipStore)
    }

    /// DMMW Phase 1 · slice 3 — the same question for the persistent project header, which has
    /// no instance of this view. STILL the one `canPlay` call in this file: the instance form
    /// above only hands its environment over.
    static func songCanStart(player: TimelineRegionPlayer, timeline: TimelineStore,
                             clipStore: ClipStore) -> Bool {
        TimelineRegionPlayer.canPlay(
            timeline.document,
            clips: clipStore.filledClips,
            bpm: player.preflightTempo,
            resolveAudio: { player.audioLanes?.resolvedURL(forClipID: $0) })
    }

    /// "Add Audio Track" — the door's action and the Add menu's, one body (#416). The store is
    /// handed over, never messaged (claim F); `addTrackRow` says why the note is cleared.
    /// Review of slice 4: from the Add menu the new track is appended below, often off screen,
    /// so — like "Add MIDI Track" — it is selected and the note line names it. The sentence is
    /// `MIDIImport.addedTrackNote`, which names no kind; one sentence for both doors (#416).
    private func addAudioTrack() {
        importNote = nil
        AudioImport.addAudioTrack(timeline: timeline)
        if let added = timeline.document.lanes.last, added.kind == .audio, !added.isBio {
            selection.selectTrack(added.id)
            importNote = MIDIImport.addedTrackNote(laneName: added.name)
        }
    }

    /// "Import Audio" / "Import MIDI" — open the ONE importer for a kind. The doors' action and
    /// the Add menu's, one body (#416).
    private func openImporter(_ kind: ImportKind) {
        importNote = nil
        tuningPending = nil
        importKind = kind
        importPresented = true
    }

    /// "Add MIDI Track" — the row's action and the guide's step 1, one body (#416).
    private func addMIDITrack() {
        importNote = nil
        MIDIImport.addMIDITrack(timeline: timeline)
        // DMMW Phase 2 · slice 2: the new track is SELECTED, so its row is marked and its
        // details open under it — a tap that visibly made something. `addLane` appends, so the
        // last lane is the one just made; the kind check refuses anything else.
        if let added = timeline.document.lanes.last, added.kind == .midi, !added.isBio {
            selection.selectTrack(added.id)
            importNote = MIDIImport.addedTrackNote(laneName: added.name)
        }
    }

    /// "New MIDI Part" — the row's action and the guide's step 2, one body (#416). The stores
    /// are handed to `MIDIImport.addEmptyPart`, never messaged (claim F); the new part is
    /// selected so the part bar and the track's Notes page open on it; every outcome says what
    /// happened on the one note line.
    private func newMIDIPart() {
        importNote = nil
        tuningPending = nil
        // DMMW Phase 4: the part lands on the SELECTED track when a voice plays it there.
        // `laneVoiceCapacity` is cold (`@ObservationIgnored`, set once at app start).
        let selected = selection.trackID
        switch MIDIImport.addEmptyPart(clipStore: clipStore, timeline: timeline,
                                       selectedTrack: selected,
                                       voiceCapacity: player.laneVoiceCapacity) {
        case .success(let landing):
            selection.selectRegion(landing.region.id, in: timeline.document)
            // DMMW Phase 2: an empty part is made to be written into — its notes open at once.
            selection.setNotesOpen(true)
            let lanes = timeline.document.lanes
            let laneName = lanes.first { $0.id == landing.laneID }?.name ?? String(localized: "the MIDI track")
            // Said, never discovered: the selected track could not take the part.
            let missed = selected.flatMap { id in
                id == landing.laneID ? nil : lanes.first { $0.id == id }?.name
            }
            // Review of 324c8e9b3 (MED): Generate yields only to user parts on the ROLL lane
            // (`syncPrimaryRollClip`), so only a part there earns the "won't place over" sentence.
            importNote = MIDIImport.emptyPartNote(laneName: laneName,
                                                  atSongStart: landing.region.startTick == 0
                                                      && landing.laneID == timeline.document.rollLaneID,
                                                  notOnSelected: missed)
        case .failure(let failure):
            importNote = failure.userMessage
        }
    }

    // MARK: - The compose guide (DMMW Phase 1, founder 2026-09-29)

    /// The five steps, handed their facts and their actions. The facts are the cold reads this
    /// body already makes — the document, the clip grid, `isPlaying`, and the engine's own start
    /// guard through `songCanStart()` (the one question Play asks, #416). Nothing here is a new
    /// subscription and nothing is a new modal: Save is the chrome door the project row posts.
    private var composeGuide: some View {
        let clips = clipStore.filledClips
        // Review of 09d35f56e, MED-3: the guide's Play/Stop reads the SAME running truth as the
        // transport row and the header — anything on the one clock — so the plate never shows
        // Stop on one control and Play on the next while the instrument runs.
        let running = ProjectTransport.isRunning(clockRunning: transport.isPlaying,
                                                 songPlaying: player.isPlaying)
        let facts = ComposeGuide.facts(document: timeline.document, clips: clips,
                                       canPlay: songCanStart(), isPlaying: running)
        // DAW shell S2: "how to make a piece" belongs to the arrangement; on the Mixer, Browse and
        // Project plates the guide draws nothing — UNTIL the piece has no part. Then it draws on
        // every plate: "New piece" and Open only move the stage, never the plate (the switcher is
        // the plate's one writer), so a new piece begun from the Project plate would otherwise
        // land there with no guide and no creation door (review of 82b7a6a5a, MED). It stays the
        // plate's first child either way.
        return Group {
        if pieceView == .arrange || !facts.hasPart {
        ComposeGuideCard(facts: facts, note: guideNote) { step in
            // Review of c672c2adf (LOW): a refusal from step 2 (a full clip grid) was written to
            // the note line far below the guide, so the tap looked like nothing. The guide shows
            // its own step's outcome in the card; the lower line is left to the rows.
            guideNote = nil
            switch step {
            case .track:
                addMIDITrack()
                guideNote = importNote
                importNote = nil
            case .part:
                // Review of 324c8e9b3 (HIGH): the guide's track is the import's track — the one
                // `ComposeGuide` counts parts on. Point the ONE part action at it first, or a part
                // lands on a selected rack track, "Part" stays next and every tap spends a slot.
                if let guideTrack = MIDIImport.firstImportableMIDILane(in: timeline.document) {
                    selection.selectTrack(guideTrack.id)
                }
                newMIDIPart()
                guideNote = importNote
                importNote = nil
            case .notes:
                // DMMW Phase 2 · slice 1: "Write notes" OPENS the notes — no hidden "tap Notes".
                if let id = ComposeGuide.partToWrite(document: timeline.document, clips: clips) {
                    selection.selectRegion(id, in: timeline.document)
                    selection.setNotesOpen(true)
                    guideNote = ComposeGuide.notesOpenedNote
                }
            case .play:
                if running {
                    ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: "compose guide")
                } else {
                    startTimeline(fromTick: 0, launching: [])
                }
            case .save:
                NotificationCenter.default.post(name: .echoelChromeDoor, object: "save")
            }
        }
        }
        }
    }

    /// Start the arrangement on the ONE transport. Everything this hands over is already
    /// owned elsewhere: the document by `TimelineStore`, the clock by `PatternEngine` (the
    /// player calls `pattern.play(cause: .timelineRegion)` itself), the notes by
    /// `PianoRollModel`. Nothing is constructed here.
    /// `fromTick` and `launching` are REQUIRED (#431): Play passes 0 and no parts (the song from
    /// the top), the Session view a scene's bar and its parts (Phase 3 / S2) — the player floors
    /// the tick to the bar and lands the parts on it inside the same call (S2 review, MED-1).
    private func startTimeline(fromTick: Int, launching: [UUID]) {
        Self.startSong(player: player, timeline: timeline, clipStore: clipStore,
                       pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                       fromTick: fromTick, launching: launching)
    }

    /// DMMW Phase 1 · slice 3 — the song's ONE start, reachable by the persistent project header
    /// as well. It stays in THIS file (the one `player.play(` caller, claim A) and constructs
    /// nothing: every argument is an owner the caller already holds from the environment.
    /// The caption's start bar is the PLAYER's (`startedFromTick`, written inside `play`), so a
    /// start from any door names its own bar (review of 09d35f56e, MED-5).
    static func startSong(player: TimelineRegionPlayer, timeline: TimelineStore, clipStore: ClipStore,
                          pattern: PatternEngine, pianoRoll: PianoRollModel,
                          fromTick: Int, launching: [UUID]) {
        player.play(document: timeline.document,
                    clips: clipStore,
                    pattern: pattern,
                    pianoRoll: pianoRoll,
                    fromTick: fromTick,
                    launching: launching)
    }

}

// ⛔ `WorkstationProjectRow` STOOD HERE (WA4 Acceptance Test A → DAW shell S3, 2026-10-02). Its
// Save and Open posted the chrome doors the studio receives; the ≡ menu in `WorkspaceView.topBar`
// posts the same two now, on both stages, so the plate's twin went in the same commit (one door
// per area). The Project plate keeps the song's settings and the two export tiles.

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
            EchoelValueField(label: known ? String(localized: "Tempo") : String(localized: "Set tempo"),
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
        // S4b: on the Part page, inside the inspector's padding — no indent of its own.
        .padding(.vertical, 6)
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
        if measuring { return clip.name + String(localized: " · measuring tempo…") }
        if lockedByWarp { return clip.name + String(localized: " · turn Warp off to change its tempo") }
        return known ? clip.name : clip.name + String(localized: " · tempo not set — enter it to use Warp")
    }

    private func hint(known: Bool) -> String {
        if measuring { return String(localized: "The file's tempo is still being measured.") }
        if lockedByWarp { return String(localized: "Turn Warp off to change this file's tempo.") }
        return known
            ? String(localized: "This file's own tempo. Warp uses it to fit the file to the piece tempo.")
            : String(localized: "Not set. Starts at the piece tempo; enter the file's own tempo to enable Warp.")
    }

    @ViewBuilder
    private func octaveButton(_ glyph: String, target: Double?, spoken: LocalizedStringKey) -> some View {
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
            .accessibilityHint(String(localized: "Sets this file's tempo to ") + String(format: "%.1f", target) + String(localized: " BPM"))
        }
    }
}

/// The `.task(id:)` key of an owed analysis: the managed copy to read AND the clip its tempo
/// belongs to, both taken from the import's `Landing` (S1-0). Equatable so a second import
/// restarts the task exactly when the pair changes.
private struct AnalysisRequest: Equatable {
    let url: URL
    let clipID: UUID
}

/// DMMW Phase 1 (founder 2026-09-29) — the compose guide: "Create a piece" and its five steps,
/// at the top of the Workstation, so the first thing the plate says is how a piece is made.
///
/// ⭐ OPEN, IT SHOWS THE STEP TO DO NOW (`ComposeGuide.shownSteps`) — and the line "Step n of 5"
/// beside its title (founder 2026-10-01: "Viele Bereiche sind zu groß … Vermeide slop"). ⛔ It
/// showed all five as bordered rows: ≈318 pt (estimate) on an empty piece on a 375×667 phone,
/// taller than the arrangement viewport below it, while four of the five were either done,
/// waiting, or a second address of a door the plate already has (Add MIDI Track, New MIDI Part,
/// Notes, the pinned bar's Play, Save in the project row). Every step stays reachable: each one
/// completing makes the next the shown one, and nothing the guide did is lost — it was never the
/// only door. A step before the next one that is WAITING keeps its row (its reason is the only
/// place that says why), and with no next step all five show, so "Every step is available
/// below." stays true.
///
/// ⭐ A LEAF WITH NO STORE READS. The facts arrive as a value (`ComposeGuide.Facts`) and every tap
/// is handed back to the Workstation, which runs the existing path — so this view cannot start,
/// write or select anything the Workstation's own doors could not.
///
/// ⚠️ ACTIVATION ONLY. Each step is a `Button`: VoiceOver focus reads it, a double-tap runs it —
/// exploring the list never adds a track or starts the song. Nothing here is a swipe gesture.
///
/// ⚠️ NO NESTED CARD (Uncodixfy): the steps are bordered doors in the house idiom, the header is a
/// plain disclosure line; there is no panel around them. The next step wears the accent border,
/// and its state is ALSO in words — the icon and colour are never the only carrier.
///
/// The fold is view state, never persisted. It is decided ONCE, when the card arrives
/// (`ComposeGuide.opensExpanded`), and after that only the player's own tap on the header folds
/// or opens it.
private struct ComposeGuideCard: View {
    let facts: ComposeGuide.Facts
    /// The outcome of the last step run from here (a refusal must be seen where it was tapped).
    let note: String?
    let perform: (ComposeGuide.Step) -> Void
    /// Set from the facts the card ARRIVES with, never re-derived (`State(initialValue:)` is read
    /// once per identity). ⛔ It folded itself once a part held notes (review of c672c2adf) —
    /// exactly when Play and Save become the next steps, so the two steps a finished part needs
    /// were hidden in the middle of the work. A3/A6 (founder 2026-10-01) answer that differently:
    /// a song that ALREADY has notes when the piece opens is not a beginner's empty plate, so the
    /// card arrives folded — the header line still names the next step, Play sits in the
    /// pinned transport bar, Save in the project row. Nothing folds while the player works.
    @State private var expanded: Bool

    init(facts: ComposeGuide.Facts, note: String?, perform: @escaping (ComposeGuide.Step) -> Void) {
        self.facts = facts
        self.note = note
        self.perform = perform
        _expanded = State(initialValue: ComposeGuide.opensExpanded(facts))
    }

    var body: some View {
        let next = ComposeGuide.nextStep(facts)
        let shown = ComposeGuide.shownSteps(facts)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                expanded.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(EchoelTheme.font(11, .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Create a piece")
                                .font(EchoelTheme.font(13, .semibold))
                                .foregroundStyle(EchoelTheme.text)
                            if let next {
                                Text(ComposeGuide.stepPosition(next))
                                    .font(EchoelTheme.font(11))
                                    .foregroundStyle(EchoelTheme.dim)
                            }
                        }
                        // Open, the shown step's own row names it — the header does not say it twice.
                        if !expanded {
                            Text(ComposeGuide.headerDetail(facts))
                                .font(EchoelTheme.font(12))
                                .foregroundStyle(EchoelTheme.dim)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(EchoelTheme.text)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ComposeGuide.headerLabel(facts))
            .accessibilityValue(expanded ? String(localized: "Expanded") : String(localized: "Collapsed"))
            .accessibilityHint(expanded ? String(localized: "Hides the steps") : String(localized: "Shows the steps"))

            if expanded {
                ForEach(shown) { step in
                    stepRow(step)
                }
                if let note {
                    Text(note)
                        .font(EchoelTheme.font(11))
                        .foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(note)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(_ step: ComposeGuide.Step) -> some View {
        let state = ComposeGuide.state(of: step, facts)
        return Button {
            perform(step)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: Self.symbol(state))
                    .font(EchoelTheme.font(13, .semibold))
                    // Accent only for the ONE step to do now (an active state, the token's use);
                    // a done tick is plain text colour (review of c672c2adf).
                    .foregroundStyle(state == .next ? EchoelTheme.accent
                                                    : (state == .done ? EchoelTheme.text : EchoelTheme.dim))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(step.rawValue). " + ComposeGuide.title(step, facts))
                        .font(EchoelTheme.font(13, .semibold))
                        .foregroundStyle(state == .waiting ? EchoelTheme.dim : EchoelTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ComposeGuide.detail(step, facts))
                        .font(EchoelTheme.font(12))
                        .foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(state == .next ? EchoelTheme.accent : EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ComposeGuide.isActionable(step, facts))
        .accessibilityLabel(ComposeGuide.spokenLabel(step, facts))
        .accessibilityHint(ComposeGuide.detail(step, facts))
    }

    private static func symbol(_ state: ComposeGuide.State) -> String {
        switch state {
        case .done:    return "checkmark.circle.fill"
        case .next:    return "arrow.right.circle.fill"
        case .ready:   return "circle"
        case .waiting: return "circle.dashed"
        }
    }
}

#endif
