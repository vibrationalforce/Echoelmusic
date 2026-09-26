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
//   · A take is a new part OVER the track from bar 1: where it overlaps an older part, the take is
//     what plays (`TimelineScheduling.activeRegion`); Undo brings the older one back. Said on screen.
//   · A song that cannot play yet (no part with content) cannot be recorded into: there is no clock
//     to record against. Said on screen, not hidden.
//   · While recording, the keyboard sounds its live voice (mono); the take then plays back on the
//     track's own sound.
//
// R1 review repairs (433f13f26): a transport that is ALREADY running (the instrument's Play or the
// header ▶ start the shared pattern without the region player) must stop first — joining it would
// anchor the take at the instrument's bar, not bar 1. A lane armed where this door cannot arm it
// (a stale flag from an older document) blocks Record by name and shows its switch so it can be
// disarmed. A clip grid with no room is said BEFORE the performance, not after. Record arms, then
// starts; a refused start cancels the arm so nothing is left recording.
//
// Performance law: `isRecording`, `droppedTakes` and `Transport.isPlaying` change a few times per
// take, never per step. No clock or bio read here; the document and clip grid are cold.

import SwiftUI

/// The Record button beside Play. Arms nothing itself — it records the tracks already armed.
@MainActor
struct RecordTakeButton: View {
    @Environment(RecordController.self) private var recorder
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(Transport.self) private var transport

    /// The song is running (the Workstation's own `player.isPlaying`).
    let playing: Bool
    /// The Workstation's own answer to "can the song start" (`canPlay`, asked once there).
    let startable: Bool
    /// `TimelineRegionPlayer.laneVoiceCapacity`, passed down — the door never reaches the player.
    let voiceCapacity: Int
    /// The Workstation's ONE start, from the top. Returns whether the song is now playing.
    let startSong: () -> Bool
    /// The Workstation's Stop — it commits the take.
    let stopSong: () -> Void

    var body: some View {
        let recording = recorder.isRecording
        let plan = RecordTake.plan(in: timeline.document, voiceCapacity: voiceCapacity)
        let freeSlots = clipStore.slots.filter { $0 == nil }.count
        let state = RecordTake.state(recording: recording,
                                     running: playing || transport.isPlaying,
                                     plan: plan, freeSlots: freeSlots, startable: startable)
        let caption = RecordTake.caption(state, gridSize: clipStore.slots.count)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                switch state {
                case .recording:
                    stopSong()
                case .ready:
                    recorder.arm()
                    // A refused start (the player's own guard) must not leave an armed recorder
                    // that the NEXT start from any surface would record into.
                    if !startSong() { recorder.cancel() }
                case .stopFirst, .armFirst, .foreignArm, .gridFull, .songCannotPlay:
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
            .accessibilityHint(caption)

            Text(caption)
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)   // the button's hint carries it
            if recorder.droppedTakes > 0 {
                Text(RecordTake.droppedSentence(recorder.droppedTakes, gridSize: clipStore.slots.count))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Record-arm for the ONE open track, shown under its inspector. Offered on a rack MIDI track —
/// the tracks a MIDI take can land on and play back from — and on ANY track that is already armed,
/// so a stale arm from an older document can always be switched off.
@MainActor
struct TrackArmToggle: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(RecordController.self) private var recorder
    @Environment(TimelineRegionPlayer.self) private var player

    let laneID: UUID

    var body: some View {
        let document = timeline.document
        let armable = RecordTake.canArm(laneID, in: document, voiceCapacity: player.laneVoiceCapacity)
        if let lane = document.lanes.first(where: { $0.id == laneID }), armable || lane.isArmed {
            Toggle(isOn: Binding(get: { lane.isArmed },
                                 set: { on in
                                     // Arming only where a take can land; disarming always.
                                     guard on != lane.isArmed, armable || !on else { return }
                                     timeline.toggleArm(id: laneID)
                                 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arm for recording").font(EchoelTheme.font(13))
                    Text(RecordTake.armSubtitle(armable: armable))
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
        case recording, ready, stopFirst, armFirst, foreignArm(String), gridFull, songCannotPlay
    }

    /// What Record would capture: the armed lanes this door can arm, and the NAMES of armed
    /// lanes it cannot (a stale arm the recorder would still capture — `RecordPlan.targets`).
    struct Plan: Equatable, Sendable {
        var armable: [UUID]
        var foreign: [String]
    }

    nonisolated static func plan(in document: TimelineDocument, voiceCapacity: Int) -> Plan {
        var plan = Plan(armable: [], foreign: [])
        for target in RecordPlan.targets(in: document) {
            if canArm(target.laneID, in: document, voiceCapacity: voiceCapacity) {
                plan.armable.append(target.laneID)
            } else {
                let name = document.lanes.first { $0.id == target.laneID }?.name ?? "A track"
                plan.foreign.append(name)
            }
        }
        return plan
    }

    /// Recording wins; then a running transport must stop first (a take starts at bar 1, and the
    /// recorder counts from Play); then a track must be armed; then no track the door cannot arm
    /// may be armed (it would be recorded unseen); then the grid needs a slot per take; then the
    /// song must be able to run.
    nonisolated static func state(recording: Bool, running: Bool, plan: Plan,
                                  freeSlots: Int, startable: Bool) -> State {
        if recording { return .recording }
        if running { return .stopFirst }
        if plan.armable.isEmpty && plan.foreign.isEmpty { return .armFirst }
        if let name = plan.foreign.first { return .foreignArm(name) }
        if freeSlots < plan.armable.count { return .gridFull }
        if !startable { return .songCannotPlay }
        return .ready
    }

    nonisolated static func caption(_ state: State, gridSize: Int) -> String {
        switch state {
        case .recording:
            return "Recording from bar 1. Stop, or the song's end, adds the take as a new part over the track."
        case .ready:
            return "Plays the song from bar 1 and records the armed tracks where you play. "
                + "The take plays instead of the parts under it; Undo brings them back."
        case .stopFirst:
            return "Stop the music to record. A take starts at bar 1."
        case .armFirst:
            return "Arm a MIDI track to record onto it."
        case .foreignArm(let name):
            return "\"\(name)\" is armed but cannot record here. Open it and switch Arm off first."
        case .gridFull:
            return "The part grid is full (\(gridSize) parts). Remove a part to make room for the take."
        case .songCannotPlay:
            return "Add a part with notes or audio first. Recording runs against the playing song."
        }
    }

    nonisolated static func armSubtitle(armable: Bool) -> String {
        armable
            ? "Record plays the song from bar 1 and records your MIDI keyboard onto this track. "
                + "Every armed track gets the same notes."
            : "This track cannot record here. Switch Arm off so Record can run."
    }

    nonisolated static func droppedSentence(_ count: Int, gridSize: Int) -> String {
        count == 1 ? "1 take was not added: the part grid is full (\(gridSize) parts)."
                   : "\(count) takes were not added: the part grid is full (\(gridSize) parts)."
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
