//
//  TrackInspectorView.swift
//  Echoelmusic — Studio (WA4.1: select a track, see what plays it, mix it)
//
//  WHY THIS EXISTS. The WA4 journey is "see tracks → select a track → see its content/device →
//  mix". Until this file the Workstation listed tracks but could not select one, and the
//  per-track mixer API on `TimelineStore` (`setLaneLevel` · `setLanePan` · `toggleMute` ·
//  `toggleSolo` · `renameLane`) had NO production caller — while the players already honoured
//  every one of those fields live (`AudioLanePlayer.reconcileMix`, the rack slot sinks in
//  `TimelineRegionPlayer.refreshMixer`, and `rollSlotGain` → `PianoRollModel.mixGain`). The
//  engine half was done and doorless; this is the door.
//
//  ⭐ NO NEW TRUTH. The fields live on `TimelineLane`, which WA2 §O names the Track PRECURSOR
//  and WA3 §D the migration source (`track.<laneID>.mixer.*`). This view writes them through
//  the store's existing API, nothing else. Selection is view state — which row is open is not
//  song state and is never persisted.
//
//  ⚠️ ONLY WIRED CONTROLS ARE SHOWN (the #164/#227 "no control that does nothing" law), and
//  `TrackMix.controls` is where that is decided, once:
//  · the Echoel instrument's track (the first non-bio MIDI lane, the roll slot) has level and
//    mute/solo, but NO pan: `TimelineDocument.rollSlotPan` has no consumer, so a pan field
//    there would move a number and not the sound. When a consumer lands, flip `pan` there
//    and the guard that pins the missing consumer in the same commit.
//  · a bio lane carries a recorded curve and makes no sound — no mixer at all.
//  ⚠️ And one COUPLING that is stated rather than hidden: the Echoel track's level is the level
//  the Studio instrument plays at (`rollSlotGain` → `mixGain`, the one writer in
//  `EchoelmusicApp`). Muting it here silences the instrument, and the instrument's Start heals
//  a silenced roll slot (`healRollSlotNamingCause`). The hint says both.
//
//  Cold reads only: `timeline.document` changes on an edit. No playhead, no meter, no bio.
//

import SwiftUI

/// The pure half: what plays a track, and which mixer controls are honestly wired for it.
enum TrackMix {

    enum Role: Equatable, Sendable {
        /// The first non-bio MIDI lane — the one roll slot the Echoel instrument plays.
        case echoelInstrument
        /// Any other MIDI lane, played by a rack voice of this kind.
        case laneSynth(LaneVoiceKind)
        case audio
        /// A recorded bio curve. It makes no sound.
        case bio
        /// A kind no shipped engine plays on the timeline (video, visual).
        case unplayed
    }

    struct Controls: Equatable, Sendable {
        let role: Role
        let level: Bool
        let pan: Bool
        let muteSolo: Bool
    }

    /// Level is the lane fader, linear: 1 = unchanged, 0 = silent, 2 = +6 dB — the clamp
    /// `TimelineStore.setLaneLevel` and `TimelineDocument.effectiveGain` both apply.
    static let levelRange: ClosedRange<Double> = 0...2
    static let panRange: ClosedRange<Double> = -1...1

    nonisolated static func role(of laneID: UUID, in document: TimelineDocument) -> Role? {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return nil }
        if lane.isBio { return .bio }
        switch lane.kind {
        case .audio:
            return .audio
        case .midi:
            // The same rule `rollSlotGain` uses to pick the roll lane (#416: one rule).
            let rollLane = document.lanes.first(where: { $0.kind == .midi && !$0.isBio })
            if rollLane?.id == laneID { return .echoelInstrument }
            return .laneSynth(lane.builtinInstrument?.voiceKind ?? .poly)
        case .video, .visual:
            return .unplayed
        }
    }

    nonisolated static func controls(of laneID: UUID, in document: TimelineDocument) -> Controls? {
        guard let role = role(of: laneID, in: document) else { return nil }
        switch role {
        case .echoelInstrument:
            return Controls(role: role, level: true, pan: false, muteSolo: true)
        case .laneSynth, .audio:
            return Controls(role: role, level: true, pan: true, muteSolo: true)
        case .bio, .unplayed:
            return Controls(role: role, level: false, pan: false, muteSolo: false)
        }
    }

    nonisolated static func deviceName(_ role: Role) -> String {
        switch role {
        case .echoelInstrument:   return "Echoel instrument"
        case .laneSynth(let kind): return kind.displayName
        case .audio:              return "Audio file player"
        case .bio:                return "Bio curve — no sound"
        case .unplayed:           return "No engine plays this track yet"
        }
    }

    // MARK: Writes — through the store's existing API, nothing else

    @MainActor
    static func setLevel(_ level: Double, laneID: UUID, timeline: TimelineStore) {
        timeline.setLaneLevel(id: laneID, Float(level))
    }

    @MainActor
    static func setPan(_ pan: Double, laneID: UUID, timeline: TimelineStore) {
        timeline.setLanePan(id: laneID, Float(pan))
    }

    @MainActor
    static func flipMute(laneID: UUID, timeline: TimelineStore) {
        timeline.toggleMute(id: laneID)
    }

    @MainActor
    static func flipSolo(laneID: UUID, timeline: TimelineStore) {
        timeline.toggleSolo(id: laneID)
    }

    /// Trimmed; an empty name is refused rather than stored (a track row with no name is a
    /// row nobody can point at). Returns whether the rename happened.
    @MainActor
    @discardableResult
    static func rename(_ name: String, laneID: UUID, timeline: TimelineStore) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        timeline.renameLane(id: laneID, to: trimmed)
        return true
    }
}

/// The selected track's inspector, shown under its row in the Workstation.
@MainActor
struct TrackInspectorView: View {

    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID
    /// The name being typed. Local and cold; committed on Return.
    @State private var nameDraft = ""

    var body: some View {
        let document = timeline.document
        if let lane = document.lanes.first(where: { $0.id == laneID }),
           let controls = TrackMix.controls(of: laneID, in: document) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Device")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    Text(TrackMix.deviceName(controls.role))
                        .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                }
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    TextField("Track name", text: $nameDraft)
                        .font(EchoelTheme.font(13))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            if !TrackMix.rename(nameDraft, laneID: laneID, timeline: timeline) {
                                nameDraft = lane.name
                            }
                        }
                        .accessibilityLabel("Track name")
                }

                if controls.level {
                    EchoelValueField(
                        label: "Level",
                        value: Binding(
                            get: { Double(timeline.document.lanes
                                .first(where: { $0.id == laneID })?.level ?? 1) },
                            set: { TrackMix.setLevel($0, laneID: laneID, timeline: timeline) }),
                        range: TrackMix.levelRange,
                        decimals: 2,
                        hint: controls.role == .echoelInstrument
                            ? "1.00 unchanged, 0 silent. This is also the level the Studio instrument plays at"
                            : "1.00 unchanged, 0 silent, 2.00 is +6 dB")
                }
                if controls.pan {
                    EchoelValueField(
                        label: "Pan",
                        value: Binding(
                            get: { Double(timeline.document.lanes
                                .first(where: { $0.id == laneID })?.pan ?? 0) },
                            set: { TrackMix.setPan($0, laneID: laneID, timeline: timeline) }),
                        range: TrackMix.panRange,
                        decimals: 2,
                        hint: "−1 left, 0 centre, 1 right")
                }
                if controls.muteSolo {
                    HStack(spacing: 8) {
                        stateButton("Mute", on: lane.isMuted,
                                    hint: controls.role == .echoelInstrument
                                        ? "Silences this track and the Studio instrument. Start un-mutes it"
                                        : "Silences this track") {
                            TrackMix.flipMute(laneID: laneID, timeline: timeline)
                        }
                        stateButton("Solo", on: lane.isSoloed,
                                    hint: "Plays only the soloed tracks") {
                            TrackMix.flipSolo(laneID: laneID, timeline: timeline)
                        }
                    }
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .padding(.leading, 26)
            .onAppear { nameDraft = lane.name }
        }
    }

    private func stateButton(_ title: String, on: Bool, hint: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)
                .padding(.horizontal, 14)
                .frame(minWidth: 64, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(on ? EchoelTheme.accent : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityHint(hint)
    }
}
