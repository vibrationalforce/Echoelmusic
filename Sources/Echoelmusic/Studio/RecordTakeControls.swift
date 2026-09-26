// RecordTakeControls.swift
// Echoel — Phase 3 / Recording R1: record a MIDI take in the Workstation.
//
// ⭐ THE RECORDER WAS ALREADY BUILT AND WIRED; ONLY ITS DOOR WAS MISSING. `MIDIBusPublisher`
// tees every external note into `RecordController` on the main actor, BEFORE it publishes the
// event (so `controllerEvents` keeps its ONE consumer), and a stop commits each armed track's
// take as a new part: `ClipStore.setClip` + `TimelineStore.addRegion`, one Undo step per take.
// `RecordController.arm()` and `TimelineStore.toggleArm` had no caller. This file is that caller,
// and the ONLY one: `WorkstationView` must not name the controller (`TheWorkstationImportsAudioTests`).
//
// ⚠️ WHAT R1 IS NOT, so the surface does not read as more:
//   · MIDI only. There is no audio input (#1302); an audio track shows no Arm.
//   · The take starts at bar 1: Record starts the song from the top through the Workstation's ONE
//     start, because the recorder counts steps from Play. It ENDS where the song ends (a wrap would
//     otherwise land notes past the song — `RecordController.followSongEnd`) or at Stop.
//   · A song that cannot play yet (no part with content) cannot be recorded into: there is no clock
//     to record against. Said on screen, not hidden.
//   · Notes land on the sixteenth grid. While recording, the keyboard sounds its live voice; the
//     take then plays back on the track's own sound.
//
// Performance law: `isRecording` and `droppedTakes` change twice per take, never per step. No clock
// or bio read here; the leaf observes the document only for the arm flags.

import SwiftUI

/// The Record button beside Play. Arms nothing itself — it records the tracks already armed.
@MainActor
struct RecordTakeButton: View {
    @Environment(RecordController.self) private var recorder
    @Environment(TimelineStore.self) private var timeline

    /// The song is running (the Workstation's own `player.isPlaying`).
    let playing: Bool
    /// The Workstation's own answer to "can the song start" (`canPlay`, asked once there).
    let startable: Bool
    /// The Workstation's ONE start, from the top.
    let startSong: () -> Void
    /// The Workstation's Stop — it commits the take.
    let stopSong: () -> Void

    var body: some View {
        let recording = recorder.isRecording
        let armed = !RecordPlan.targets(in: timeline.document).isEmpty
        let state = RecordTake.state(recording: recording, playing: playing,
                                     armed: armed, startable: startable)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                switch state {
                case .recording:
                    stopSong()
                case .ready:
                    recorder.arm()
                    startSong()
                case .stopFirst, .armFirst, .songCannotPlay:
                    break
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: recording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(recording ? "Stop recording" : "Record")
                        .font(EchoelTheme.font(13, .semibold))
                }
                .foregroundStyle(recording ? EchoelTheme.onPrimary
                                           : (state == .ready ? EchoelTheme.text : EchoelTheme.dim))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(recording ? EchoelTheme.warning : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(state == .ready ? EchoelTheme.border : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state != .ready && state != .recording)
            .accessibilityLabel(recording ? "Stop recording" : "Record")
            .accessibilityHint(RecordTake.caption(state))

            Text(RecordTake.caption(state))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)   // the button's hint carries it
            if recorder.droppedTakes > 0 {
                Text(RecordTake.droppedSentence(recorder.droppedTakes))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Record-arm for the ONE open track, shown under its inspector. Offered only on a rack MIDI track
/// — the tracks a MIDI take can land on and play back from.
@MainActor
struct TrackArmToggle: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(RecordController.self) private var recorder
    @Environment(TimelineRegionPlayer.self) private var player

    let laneID: UUID

    var body: some View {
        let document = timeline.document
        if RecordTake.canArm(laneID, in: document, voiceCapacity: player.laneVoiceCapacity),
           let lane = document.lanes.first(where: { $0.id == laneID }) {
            Toggle(isOn: Binding(get: { lane.isArmed },
                                 set: { _ in timeline.toggleArm(id: laneID) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arm for recording").font(EchoelTheme.font(13))
                    Text("Record plays the song from bar 1 and records your MIDI keyboard onto this track.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(EchoelTheme.accent)
            .disabled(recorder.isRecording)   // a take's targets are fixed when it starts
            .padding(.horizontal, 10)
        }
    }
}

/// The door's decisions, pure.
enum RecordTake {

    enum State: Equatable, Sendable {
        case recording, ready, stopFirst, armFirst, songCannotPlay
    }

    /// Recording wins; then a running song must stop first (a take starts at bar 1); then a track
    /// must be armed; then the song must be able to run.
    nonisolated static func state(recording: Bool, playing: Bool, armed: Bool,
                                  startable: Bool) -> State {
        if recording { return .recording }
        if playing { return .stopFirst }
        if !armed { return .armFirst }
        if !startable { return .songCannotPlay }
        return .ready
    }

    nonisolated static func caption(_ state: State) -> String {
        switch state {
        case .recording:
            return "Recording from bar 1. Stop, or the song's end, adds the take as a new part."
        case .ready:
            return "Plays the song from bar 1 and records the armed tracks. Notes land on the sixteenth grid."
        case .stopFirst:
            return "Stop the song to record. A take starts at bar 1."
        case .armFirst:
            return "Arm a MIDI track to record onto it."
        case .songCannotPlay:
            return "Add a part with notes or audio first. Recording runs against the playing song."
        }
    }

    nonisolated static func droppedSentence(_ count: Int) -> String {
        count == 1 ? "1 take was not added: the part grid is full (8 parts)."
                   : "\(count) takes were not added: the part grid is full (8 parts)."
    }

    /// A rack MIDI track: its role is a lane synth (not the Echoel track, not bio, not audio, not
    /// past the rack's capacity) and its record source is MIDI input.
    nonisolated static func canArm(_ laneID: UUID, in document: TimelineDocument,
                                   voiceCapacity: Int) -> Bool {
        guard let lane = document.lanes.first(where: { $0.id == laneID }),
              lane.recordSource == .midiInput,
              case .laneSynth? = TrackMix.role(of: laneID, in: document, voiceCapacity: voiceCapacity)
        else { return false }
        return true
    }
}
