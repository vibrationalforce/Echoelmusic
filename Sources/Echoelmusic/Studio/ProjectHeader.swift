// ProjectHeader.swift
// Echoel — DMMW Phase 1 · slice 3 (founder 2026-09-29): the persistent project header. Always
// on screen, above every area (Compose, Perform, later Visuals), so all of them serve the ONE
// canonical project: its name, where the player is working, the tempo, what is running — and
// one Play / Stop / Record over the one transport.
//
// ⭐ IT OWNS NOTHING AND CONSTRUCTS NOTHING. Every value is read from the owner the app already
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
        // At accessibility sizes the facts and the controls stack, so neither is squeezed out
        // and the transport stays one tap away. `AnyLayout` keeps each child's identity across
        // the switch — ONE Play button, in either arrangement (the Workstation's own idiom).
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            summary(name: name, place: place, status: status)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                playStopButton(running: running, play: play)
                RecordTakeButton(playing: player.isPlaying, startable: songStartable,
                                 voiceCapacity: player.laneVoiceCapacity,
                                 startSong: { startSong(); return player.isPlaying },
                                 stopSong: { stopAll() },
                                 compact: true)
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

    /// The ONE Play / Stop. While anything runs it is Stop — for everything. Stopped, it plays
    /// what the project can play: the song, or a held session's music.
    private func playStopButton(running: Bool, play: ProjectTransport.PlayAction) -> some View {
        let available = running || play != .unavailable
        return Button {
            if running {
                stopAll()
            } else {
                switch play {
                case .startSong:        startSong()
                case .resumeInstrument: ProjectTransport.resumeInstrument(pattern: beatPlayer.pattern)
                case .unavailable:      break
                }
            }
        } label: {
            Image(systemName: running ? "stop.fill" : "play.fill")
                .font(EchoelTheme.font(15, .semibold))
                .foregroundStyle(running ? EchoelTheme.onPrimary
                                         : (available ? EchoelTheme.text : EchoelTheme.dim))
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
