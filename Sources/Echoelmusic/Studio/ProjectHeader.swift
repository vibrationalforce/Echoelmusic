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
// ⚠️ IT SITS IN THE ROOT (`WorkspaceView`), ABOVE EVERY MENU HOST, SO IT READS NOTHING HOT.
// Every flag below changes on a start, a stop, an edit or a tap. The one hot value — the tempo,
// which glides at up to ~20 Hz — is read ONLY inside `ProjectTempoReadout`, its own leaf, so the
// glide rebuilds that one `Text` and never this header or anything below it (the 10.76.41/50
// freeze law, and its ROOT rule).
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
// LAYOUT: the summary, the pill, the history and the buttons share one row while their ideal
// widths fit (`ViewThatFits`, the #1027 idiom), else the pill and the history take a second line;
// at accessibility sizes everything stacks. The pill is greedy (its trace flexes), so on its own
// line it fills the width, and on one line it yields to nothing that has a floor.
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
// ⭐ AND THE ⓘ — THE GUIDE SWITCH (head leaf 4; the doc: "Hilfe an einem festen Ort (ⓘ im Kopf),
// für neue Nutzer an"). It flips the shared `StudioDefaultKeys.guideVisible` key that
// `GuideOverlay` (the top layer of `WorkspaceView`, above both stages) reads. Measured before
// building: the guide's ONE switch was a Toggle in the instrument's Save & Export plate — the
// hidden stage — and the key defaulted to OFF, so a fresh install had a launch teaching it could
// neither see nor find. The switch MOVED here (one address) and the default is ON (the key, in
// Core). The key is a SETTING, written on a tap — not hot state.

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
    /// The guide's on/off (head leaf 4) — the ONE shared key, declared in Core (H15-KEYSTORE),
    /// read by `GuideOverlay` and flipped by the ⓘ below. Written on a tap, never on a tick.
    @AppStorage(StudioDefaultKeys.guideVisible.key)
    private var guideVisible = StudioDefaultKeys.guideVisible.value

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
        let running = ProjectTransport.isRunning(facts)
        let play = ProjectTransport.playAction(facts)
        let name = ProjectTransport.projectName(projects.currentProjectName)
        let place = ProjectTransport.place(document: document, trackID: selection.trackID,
                                           regionID: selection.regionID)
        // The facts flex, the pill flexes, the five buttons (Play · Record · ⓘ · Undo · Redo)
        // have floors. One row while the ideal widths fit (a phone in landscape, an iPad); else two
        // lines — the summary with the transport over the pill with the history; else three,
        // the pill and the history each on their own — the #1027 idiom, `ViewThatFits`; at
        // accessibility sizes everything stacks so nothing is squeezed out and the transport
        // stays one tap away. (⛔ `AnyLayout` stood here for the accessibility switch; it went
        // with the pill's arrival, because `ViewThatFits` already re-creates its candidate on a
        // fit change — a rotation — and one identity law for the whole row beats two. What that
        // costs: VoiceOver focus may leave the Play button on a rotation. What it buys: the
        // same Play, the same pill, the same Undo, in every shape.)
        let summaryView = summary(name: name, place: place, status: status)
            .frame(maxWidth: .infinity, alignment: .leading)
        let controls = HStack(spacing: 8) {
            playStopButton(running: running, play: play)
            RecordTakeButton(playing: player.isPlaying, startable: songStartable,
                             voiceCapacity: player.laneVoiceCapacity,
                             startSong: { startSong(); return player.isPlaying },
                             stopSong: { stopAll() },
                             compact: true)
            guideButton
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { summaryView; pulsePill; history; controls }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { summaryView; pulsePill; history; controls }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) { summaryView; controls }
                        HStack(spacing: 10) { pulsePill; history }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) { summaryView; controls }
                        pulsePill
                        history
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

    /// Name, status, tempo and place as ONE VoiceOver element: "My song, Playing song, 120 BPM,
    /// Keys · part at bar 3". Legible numbers first (the science-first display rule).
    private func summary(name: String, place: String, status: ProjectTransport.Status) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
            HStack(spacing: 6) {
                Text(ProjectTransport.statusWord(status))
                    .font(EchoelTheme.font(11, .semibold))
                    .foregroundStyle(status == .stopped ? EchoelTheme.dim : EchoelTheme.text)
                ProjectTempoReadout()
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

    /// ⓘ — the guide switch (head leaf 4). Flips the shared key `GuideOverlay` reads; filled
    /// while the cards are showing (the `M`/`S` switch grammar of the track rows). A glyph on
    /// purpose: the audit doc names it "ⓘ im Kopf", and it is the one control here whose state
    /// is visible elsewhere on the screen — the card itself. Spoken as label · value · hint.
    private var guideButton: some View {
        Button { guideVisible.toggle() } label: {
            Image(systemName: "info.circle")
                .font(EchoelTheme.font(15, .semibold))
                .foregroundStyle(guideVisible ? EchoelTheme.onPrimary : EchoelTheme.text)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(guideVisible ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(guideVisible ? Color.clear : EchoelTheme.borderStrong,
                                  lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Guide")
        .accessibilityValue(guideVisible ? "On" : "Off")
        .accessibilityAddTraits(guideVisible ? .isSelected : [])
        .accessibilityHint("Shows or hides the cards that walk you through playing and understanding the app")
    }

    /// The head's Undo / Redo — the song's ONE history control (`SongHistoryRow`, head leaf 3),
    /// constructed once and spelled into every shape. Its own leaf: it reads `canUndo` /
    /// `canRedo` (cold, flipped on an edit) in ITS body; this header reads nothing of it.
    private var history: some View {
        SongHistoryRow()
    }

    /// The ONE Play / Stop. While anything runs it is Stop — for everything. Stopped, it plays
    /// what the project can play: the song, or a held session's music.
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
        .accessibilityLabel(ProjectTransport.buttonLabel(running: running, play: play))
        .accessibilityHint(ProjectTransport.buttonHint(running: running, play: play))
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
            .accessibilityLabel("\(bpm) BPM")
    }
}
