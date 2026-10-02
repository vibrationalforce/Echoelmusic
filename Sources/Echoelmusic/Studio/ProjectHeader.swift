// ProjectHeader.swift
// Echoel — DMMW Phase 1 · slice 3 (founder 2026-09-29): the persistent project header. Always
// on screen, above every area (Compose, Perform, later Visuals), so all of them serve the ONE
// canonical project: its name, where the player is working, the tempo, what is running — and
// one Play / Stop / Record over the one transport.
//
// ⭐ IT OWNS NOTHING AND CONSTRUCTS NO OWNER. Every value is read from the owner the app already
// injects (`ProjectStore`, `TimelineStore`, `WorkstationSelection`, `Transport`, the one
// `TimelineRegionPlayer`, `RecordController`, `EngineBus`). Play starts the song through the
// Workstation's ONE start (`WorkstationView.startSong`), Stop is `ProjectTransport.stop`, Record
// is the existing take door (`RecordTakeButton`) — so there is no second clock and no copy.
//
// ⭐ A3b (workstation redesign, founder 2026-10-01): THE HEAD CARRIES THE TRANSPORT ON THE
// INSTRUMENT STAGE ONLY. On the Piece stage the bar pinned under the arrangement
// (`WorkstationView.transportBar`) is the transport, and a second Play on the same screen is the
// founder's "zu viele Play Knöpfe" a fifth time. So the ONE Play / Stop is its own leaf,
// `ProjectPlayStopButton` (below): mounted HERE while the Instrument stage shows, and by the bar
// while the Piece stage shows — never both, because `StageShell` mounts the bar's stage only on
// the Piece stage and this header reads the same stage key. One definition, so one word, one
// spoken label, one resume of a held instrument, one Stop for everything and ONE space-bar key
// follow it to whichever stage is in front. The compact Record leaves with it (the bar carries
// the full one); the facts, the pill and Undo / Redo stay on both stages (the guide switch lives
// in the mark's ≡ menu since S1b-1).
//
// ⚠️ IT SITS IN THE ROOT (`WorkspaceView`), ABOVE EVERY MENU HOST, SO IT READS NOTHING HOT.
// Every flag below changes on a start, a stop, an edit or a tap. The two hot values are each read
// ONLY inside their own leaf: the tempo, which glides at up to ~20 Hz (`ProjectTempoReadout`), and
// the piece's position, which moves every transport step while it plays (`ProjectPositionReadout`,
// workstation redesign A4). Each rebuilds its one `Text` and never this header or anything below
// it (the 10.76.41/50 freeze law, and its ROOT rule).
//
// ⚠️ NO MODAL. Nothing here presents a sheet, alert or popover (the black-screen law); the
// header is one more child of the chrome `Group`, and inherits that group's ONE Dynamic Type
// clamp (`.accessibility1`) instead of setting its own.
//
// ⭐ THE PULSE PILL IS THE HEAD'S (interface audit 2026-09-30, "ein Kopf, der spricht", leaf 2;
// the audit doc's law: "Die Puls-Pille bleibt im Kopf … ‚Körper' bleibt im Kopf sichtbar"). It
// sat in the instrument's transport row since the founder's 2026-07-31 drawing — made when that
// plate was the app's home. Since slice 1 the Piece stage is the home, and there the body was
// nowhere on screen. `PulseMonitorMiniLive` is mounted HERE now, once, above both stages; its
// tap still posts the "bio" chrome door (which turns the Instrument stage, slice 2b-i) and its
// long-press still names the source. FREEZE: the pill reads the ~10 Hz publisher in ITS OWN
// body, exactly as it did in the studio row — this header constructs it and reads nothing of it.
// LAYOUT (founder 2026-10-01, "Viele Bereiche sind zu groß"): AT MOST TWO ROWS. One line while
// every ideal width fits (`ViewThatFits`, the #1027 idiom), else two rows with fixed places — the
// summary with the transport (Instrument stage) at its right, then the pill with Undo · Redo
// at its right; at accessibility sizes everything stacks. The pill is greedy (its trace flexes),
// so on its row it takes what the tools leave, and on one line it yields to nothing that has a
// floor.
//
// ⭐ THE ONE UNDO / REDO IS THE HEAD'S TOO (head leaf 3, same audit — its law for the head: "Name ·
// Abspielen / Stopp (mit Wort) · Aufnehmen · Tempo · Rückgängig · ⓘ Hilfe"). `SongHistoryRow`, the
// song's ONE history control (WA4 path 7), is mounted HERE, once, above both stages. It sat under
// the note grid in `WorkstationView` — M6's review put it there as "the closest place to the
// edit" — and measured 2026-09-30 that place exists on the PIECE stage only, while the Instrument
// stage writes the composer's part into the SAME history with no Undo in reach. Proximity lost to
// presence: a fixed place the player can always find, on a stage that otherwise had none. It
// reads two cold flags (`canUndo` / `canRedo`, flipped on an edit) in its own body.
//
// ⛔ THE ⓘ — THE GUIDE SWITCH (head leaf 4) — STOOD HERE AND MOVED TO THE MARK'S ≡ MENU (DAW
// shell S1b-1, founder 2026-10-02, inbox E18: the control bar starts with ≡). It is still ONE
// switch at ONE fixed place above both stages, still flipping the shared
// `StudioDefaultKeys.guideVisible` key (default ON) that `GuideOverlay` reads — only the address
// changed, and this header no longer reads the key at all. Its width went to the summary.

import SwiftUI

@MainActor
struct ProjectHeader: View {
    @Environment(ProjectStore.self) private var projects
    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    @Environment(Transport.self) private var transport
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore
    @Environment(RecordController.self) private var recorder
    @Environment(EngineBus.self) private var bus
    /// ⚠️ READ ONLY INSIDE TAP HANDLERS, never in `body`: `beatPlayer.pattern` leads to the
    /// gliding tempo (the file header). `pianoRoll` is handed to the song's start, nothing else.
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll
    /// A SETTING, not a signal — it changes when the user changes the text size.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// A3b — which stage is in front, through the ONE key (#416). A SETTING written on a tap (the
    /// seam, a plate door, New piece, Safe Mode), never a tick, so reading it in `body` is cold.
    /// Read only: this header never turns the stage.
    @AppStorage(StudioDefaultKeys.stage.key)
    private var stageRaw = StudioDefaultKeys.stage.value.rawValue

    var body: some View {
        let document = timeline.document
        let songStartable = WorkstationView.songCanStart(player: player, timeline: timeline,
                                                         clipStore: clipStore)
        let facts = ProjectTransport.Facts(clockRunning: transport.isPlaying,
                                           songPlaying: player.isPlaying,
                                           recording: recorder.isRecording,
                                           sessionRunning: bus.instrumentRunning,
                                           songStartable: songStartable)
        let status = ProjectTransport.status(facts)
        let name = ProjectTransport.projectName(projects.currentProjectName)
        let place = ProjectTransport.place(document: document, trackID: selection.trackID,
                                           regionID: selection.regionID)
        // The facts flex, the pill flexes, the buttons have floors (Play · Record · Undo · Redo
        // on the Instrument stage; Undo · Redo on the Piece stage, A3b). One row while the ideal
        // widths fit (an iPad); else TWO rows, and that is the LAST candidate, so a phone can
        // never get a third: row 1 the summary with Play · Record, row 2 the pill with Undo · Redo. Every control keeps ONE place on both stages — on the Piece stage
        // row 1 is the summary alone and has the whole width. At
        // accessibility sizes everything stacks so nothing is squeezed out and the transport
        // stays one tap away.
        // ⛔ Until 2026-10-01 a third candidate put the pill and the history on rows of their
        // own, and a 375 pt phone ALWAYS took it on the Instrument stage: the summary's ideal
        // width beside Play · Record · ⓘ never fit, so `ViewThatFits` fell to the last shape —
        // ≈152 pt of head over a ≈25 pt instrument panel (measured, founder 2026-10-01). What
        // made two rows possible is the history's glyph form (`SongHistoryRow`) and ⓘ leaving the
        // transport for the history's side, so neither row carries more than two neighbours.
        // (⛔ `AnyLayout` stood here for the accessibility switch; it went
        // with the pill's arrival, because `ViewThatFits` already re-creates its candidate on a
        // fit change — a rotation — and one identity law for the whole row beats two. What that
        // costs: VoiceOver focus may leave the Play button on a rotation. What it buys: the
        // same Play, the same pill, the same Undo, in every shape.)
        let summaryView = summary(name: name, place: place, status: status)
            .frame(maxWidth: .infinity, alignment: .leading)
        // A3b: the transport pair only while the Instrument stage is in front (file header). A
        // `Group`, not a stack: on the Piece stage it is empty and adds no spacing beside the summary.
        // ⚠️ NOT named `transport`: the environment's `Transport` is `transport`, read above for the
        // facts, and a later local of the same name in this scope makes that read "use of local
        // variable before its declaration" — a compile error.
        let carriesTransport = (StudioStage(rawValue: stageRaw) ?? StudioDefaultKeys.stage.value).headCarriesTransport
        let transportPair = Group {
            if carriesTransport {
                ProjectPlayStopButton(source: "project header")
                RecordTakeButton(playing: player.isPlaying, startable: songStartable,
                                 voiceCapacity: player.laneVoiceCapacity,
                                 startSong: { startSong(); return player.isPlaying },
                                 stopSong: { stopAll() },
                                 compact: true)
            }
        }
        // Undo · Redo (`history`) — on both stages, at the right of the pill in every phone
        // shape. ⛔ `tools` (history + ⓘ) stood here; the ⓘ moved to the mark's ≡ menu (S1b-1),
        // and a one-child wrapper would be structure kept for a test (the #528 rule).
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    summaryView; pulsePill; history
                    HStack(spacing: 8) { transportPair }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { summaryView; transportPair; pulsePill; history }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) { summaryView; transportPair }
                        HStack(spacing: 8) { pulsePill; history }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 44)
        .background(EchoelTheme.bg)
        // A status change is SPOKEN, not only drawn: a VoiceOver user who tapped Stop in the
        // Workstation hears that everything stopped, wherever focus is.
        .onChange(of: status) { _, new in
            AccessibilityNotification.Announcement(ProjectTransport.statusWord(new)).post()
        }
    }

    /// Name, status, position, tempo, metre and place as ONE VoiceOver element: "My piece, Playing
    /// piece, Position in the piece Bar 3 · Beat 1, 120 BPM, Time signature 4/4, Keys · part at bar
    /// 3". Legible numbers first (the science-first display rule).
    ///
    /// A4 (workstation redesign, founder 2026-10-01, the tablet mockup's display): position · tempo ·
    /// metre read as ONE counter line, in the order every DAW's transport display uses. The KEY of
    /// that display is not repeated here: `CompositionHeaderStrip` shows it, as the control that
    /// sets it, at the top of the Project plate (DAW shell S1a moved it out of the chrome) — a
    /// second copy here would be a second statement of one fact (#416). The metre and the position are `fixedSize`, so it
    /// is the PLACE that yields when the row runs out of width, never a number.
    private func summary(name: String, place: String, status: ProjectTransport.Status) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
            HStack(spacing: 6) {
                // The status word is offered width before the place (it may wrap at its space,
                // "Playing / piece"); the place is the one child that yields to an ellipsis.
                Text(ProjectTransport.statusWord(status))
                    .font(EchoelTheme.font(11, .semibold))
                    .foregroundStyle(status == .stopped ? EchoelTheme.dim : EchoelTheme.text)
                    .layoutPriority(1)
                ProjectPositionReadout()
                ProjectTempoReadout()
                Text(verbatim: WorkstationSummary.meterText)
                    .font(EchoelTheme.font(11).monospacedDigit())
                    .foregroundStyle(EchoelTheme.text)
                    .fixedSize()
                    .accessibilityLabel("Time signature")
                    .accessibilityValue(WorkstationSummary.meterText)
                Text(place)
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// The head's pulse pill — the ONE mount in the app (`HeaderMonitors`, head leaf 2). Its own
    /// leaf: it reads the ~10 Hz camera publisher in ITS body; this header only constructs it
    /// (freeze law). Under `#if canImport(AVFoundation)` because the pill is — a platform without
    /// it gets no pill, and the row simply loses one child.
    @ViewBuilder
    private var pulsePill: some View {
        #if canImport(AVFoundation)
        PulseMonitorMiniLive()
        #endif
    }

    /// The head's Undo / Redo — the song's ONE history control (`SongHistoryRow`, head leaf 3),
    /// constructed once per shape: beside the pill in every phone and wide shape; on its own
    /// line in the accessibility stack. Its own leaf: it reads `canUndo` / `canRedo`
    /// (cold, flipped on an edit) in ITS body; this header reads nothing of it.
    private var history: some View {
        SongHistoryRow()
    }

    private func startSong() {
        WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,
                                  pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                                  fromTick: 0, launching: [])
    }

    private func stopAll() {
        ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: "project header")
    }
}

/// A3b (workstation redesign, founder 2026-10-01) — THE ONE Play / Stop, as a leaf of its own so it
/// can stand where the stage needs it: in the head while the Instrument stage is in front, in the
/// transport bar pinned under the arrangement while the Piece stage is (`WorkstationView`'s
/// `transportRow`). Never both: the head drops it on the Piece stage, and the bar's stage is not
/// mounted on the Instrument stage (`StageShell`). One definition, so the word, the spoken label,
/// the resume of a held instrument, the Stop for everything and the ONE space-bar shortcut
/// (`TheHeadPlayOwnsTheSpaceKeyTests`) are the same object on either stage — not two buttons kept
/// alike by hand.
///
/// ⚠️ IT READS ONLY COLD FLAGS, the ones the head read for it before (`ProjectTransport.Facts`):
/// each flips on a start, a stop, an edit or a tap, never per step. `beatPlayer` and `pianoRoll`
/// are touched ONLY in the tap handlers — `beatPlayer.pattern` leads to the gliding tempo. So
/// mounting it in the Workstation's bar adds no hot read to that root (10.76.41/50).
///
/// ⚠️ NO MODAL, and it constructs no owner — every value comes from the environment the app
/// already injects into both mounts.
@MainActor
struct ProjectPlayStopButton: View {
    /// Written to the crash log BEFORE the stop (the lifecycle-ladder law), so a log names WHICH
    /// mount was tapped — "project header" or "workstation" — not only that one was.
    let source: String

    @Environment(TimelineStore.self) private var timeline
    @Environment(Transport.self) private var transport
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore
    @Environment(RecordController.self) private var recorder
    @Environment(EngineBus.self) private var bus
    /// ⚠️ READ ONLY INSIDE TAP HANDLERS, never in `body` (see above).
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll

    var body: some View {
        let facts = ProjectTransport.Facts(clockRunning: transport.isPlaying,
                                           songPlaying: player.isPlaying,
                                           recording: recorder.isRecording,
                                           sessionRunning: bus.instrumentRunning,
                                           songStartable: WorkstationView.songCanStart(
                                               player: player, timeline: timeline, clipStore: clipStore))
        playStopButton(running: ProjectTransport.isRunning(facts), play: ProjectTransport.playAction(facts))
    }

    /// The ONE Play / Stop. While anything runs it is Stop — for everything. Stopped, it plays
    /// what the project can play: the song, or a held session's music. (Moved here from
    /// `ProjectHeader` by A3b, unchanged — the type above says why.)
    ///
    /// It wears its WORD beside the glyph (`ProjectTransport.buttonWord`, interface audit
    /// 2026-09-30): the header is the first control a fresh install meets, and a lone triangle is
    /// a guess for a beginner. The word is `fixedSize` so the HStack never truncates a four-letter
    /// word to "Pl…" while the summary beside it — which owns `lineLimit` + `truncationMode` —
    /// gives way instead; the button grows with Dynamic Type (no fixed height, #353).
    private func playStopButton(running: Bool, play: ProjectTransport.PlayAction) -> some View {
        let available = running || play != .unavailable
        return Button {
            if running {
                stopAll()
            } else {
                switch play {
                case .startSong, .startSongAndInstrument: startSong()
                case .resumeInstrument: ProjectTransport.resumeInstrument(pattern: beatPlayer.pattern)
                case .unavailable:      break
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: running ? "stop.fill" : "play.fill")
                    .font(EchoelTheme.font(15, .semibold))
                Text(ProjectTransport.buttonWord(running: running))
                    .font(EchoelTheme.font(13, .semibold))
                    .fixedSize()
            }
            .foregroundStyle(running ? EchoelTheme.onPrimary
                                     : (available ? EchoelTheme.text : EchoelTheme.dim))
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .fill(running ? EchoelTheme.accent : EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(running || !available ? Color.clear : EchoelTheme.borderStrong,
                              lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        // THE SPACE BAR IS THIS BUTTON (interface audit 2026-09-30, Zug 2 "Ein Kopf, der spricht
        // und hört"). A hardware keyboard — iPad, Mac, a stage laptop over a cable — plays and
        // stops the ONE transport with the key every DAW gives it, and it can only ever reach
        // THIS button: the guard `TheHeadPlayOwnsTheSpaceKeyTests` allows exactly one
        // `.keyboardShortcut(.space` in `Sources/` (a second one on the Workstation's Play would
        // be the two-transports confusion `OneStartControlTests` names). Since A3b this one
        // button is ALSO what the Piece stage's transport bar shows, so the key follows it there —
        // still one shortcut, on one object, mounted once per stage. Bare space, no
        // modifiers — ⌘-space is the system's. `.disabled` above still governs it: an
        // unavailable Play swallows the key, so nothing starts that the tap could not start.
        // Text input keeps its own spaces — an unmodified key command is not delivered while a
        // text field is first responder (UIKit, iOS 15+) — NEEDS-FOUNDER-VERIFY with a keyboard:
        // space in the piece-name field types a space and does not start playback.
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityLabel(ProjectTransport.buttonLabel(running: running, play: play))
        .accessibilityHint(ProjectTransport.buttonHint(running: running, play: play))
    }

    private func startSong() {
        WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,
                                  pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                                  fromTick: 0, launching: [])
    }

    private func stopAll() {
        ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: source)
    }
}

/// The tempo, in its OWN leaf: `PatternEngine.tempo` glides at up to ~20 Hz, and this is the only
/// view that subscribes to it here. Whole BPM on screen — a glide's decimals would flicker.
@MainActor
private struct ProjectTempoReadout: View {
    @Environment(BeatPlayer.self) private var beatPlayer

    var body: some View {
        // A non-finite tempo would trap `Int(_:)` (the NaN law); the clock clamps, this reads.
        let tempo = beatPlayer.pattern.tempo
        let bpm = tempo.isFinite ? Int(tempo.rounded()) : 0
        Text("\(bpm) BPM")
            .font(EchoelTheme.font(11).monospacedDigit())
            .foregroundStyle(EchoelTheme.text)
            // A number never wraps or yields (the summary's law, beside the counter and the metre).
            .fixedSize()
            .accessibilityLabel("\(bpm) BPM")
    }
}

/// A4 (workstation redesign, founder 2026-10-01) — the piece's position as the counter a DAW's
/// transport display shows: "12.3.2", bar · beat · sixteenth, one-based. Its OWN leaf, for the
/// reason the tempo above has one: the position moves every transport step while the piece plays.
/// `TimelineRegionPlayer.currentTick` is `@ObservationIgnored`, so a body read would neither
/// subscribe nor update — a frozen number — and making it observable would rebuild this whole
/// header at the step rate (the 10.76.41/50 freeze law, ROOT rule). So the leaf redraws ITSELF
/// with a `TimelineView` at 15 Hz, the idiom of `SongPositionReadout` and the arrange playhead,
/// paused while the piece is stopped. It is a REDRAW, not a clock: it reads the one player's
/// position and schedules nothing.
///
/// ⚠️ STOPPED IT READS "1.1.1", AND THAT IS A FACT, NOT A PLACEHOLDER: both Plays that start the
/// whole piece — this header's and the plate's — start from the top (`fromTick: 0`). The part
/// bar's Play starts at a part; while that plays, THIS counter is where its bar shows (design
/// slice C took the plate's "Playing from bar …" line away). Stopped, the head does not guess it.
/// ⚠️ IT KEEPS ONE WIDTH. It never disappears (a counter that came only while playing would
/// re-flow the head on every Play), and a hidden three-digit template reserves the width of bar
/// 100, so reaching bar 10 or bar 100 mid-play cannot widen the summary and make the row's
/// `ViewThatFits` jump to another shape. Past bar 999 it grows — over half an hour at 120 BPM.
///
/// The digits come from `WorkstationSummary.counterText(forTick:)`, the one bar-number rule
/// (#416); VoiceOver hears `positionText` ("Bar 12 · Beat 3"), the sentence the plate's readout
/// already speaks, never three bare numbers.
///
/// ⚠️ THE TOP BAR'S `TransportPositionView` IS ALSO "b.b.s" — the instrument LOOP's position,
/// folded to the loop length. While the piece plays both move and name different bars. Which of
/// the two keeps that form is a founder question (docs/dev/FOUNDER_INBOX.md), not this leaf's call.
@MainActor
private struct ProjectPositionReadout: View {
    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            let tick = playing ? player.currentTick : 0
            ZStack(alignment: .leading) {
                Text(verbatim: "888.4.4")
                    .hidden()
                    .accessibilityHidden(true)
                Text(verbatim: WorkstationSummary.counterText(forTick: tick))
                    .foregroundStyle(playing ? EchoelTheme.accent : EchoelTheme.dim)
            }
            .font(EchoelTheme.font(11, .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position in the piece")
            .accessibilityValue(WorkstationSummary.positionText(forTick: tick))
        }
    }
}
