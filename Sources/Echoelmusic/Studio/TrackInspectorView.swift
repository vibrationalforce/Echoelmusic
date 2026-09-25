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
//  · an extra MIDI lane past the lane rack's capacity has no voice (`MultiRollFanout.slot`
//    returns nil) — no mixer either, and the device row says why (review of b2913f96b).
//  ⚠️ And the COUPLINGS with the Studio instrument are stated rather than hidden (review of
//  b2913f96b): the Echoel track's level is the level the instrument plays at (`rollSlotGain` →
//  `mixGain`, the one writer in `EchoelmusicApp`), so muting it or pulling it to 0 silences
//  the instrument; soloing ANY other track does too (`effectiveGain` zeroes every unsoloed
//  lane); and the instrument's Start heals all three (`unsilenceRollSlot`: unmute, a zeroed
//  fader back to 1.00, every other solo cleared). Each hint names the coupling it carries.
//
//  ⚠️ A typed name is committed on Return, when the field loses focus, and when the inspector
//  closes — a field that shows a name the song never stored is a second truth on screen.
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
        /// Another MIDI lane with NO rack voice: the rack plays only the first `capacity`
        /// additional MIDI lanes (`MultiRollFanout.slot`), the rest stay silent.
        case noVoice(capacity: Int)
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

    /// `voiceCapacity` is `TimelineRegionPlayer.laneVoiceCapacity` — required, never defaulted
    /// (#431): a forgotten call site must not quietly assume a voice exists.
    nonisolated static func role(of laneID: UUID, in document: TimelineDocument,
                                 voiceCapacity: Int) -> Role? {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return nil }
        if lane.isBio { return .bio }
        switch lane.kind {
        case .audio:
            return .audio
        case .midi:
            // The player's own roll-lane rule (#416: one rule, `rollSlotGain` reads it too).
            if document.rollLaneID == laneID { return .echoelInstrument }
            // The player's own slot rule: a lane past the rack's capacity has no voice.
            guard MultiRollFanout.slot(forLaneID: laneID, in: document,
                                       rollLane: document.rollLaneID,
                                       capacity: voiceCapacity) != nil else {
                return .noVoice(capacity: voiceCapacity)
            }
            return .laneSynth(lane.builtinInstrument?.voiceKind ?? .poly)
        case .video, .visual:
            return .unplayed
        }
    }

    nonisolated static func controls(of laneID: UUID, in document: TimelineDocument,
                                     voiceCapacity: Int) -> Controls? {
        guard let role = role(of: laneID, in: document, voiceCapacity: voiceCapacity) else { return nil }
        switch role {
        case .echoelInstrument:
            return Controls(role: role, level: true, pan: false, muteSolo: true)
        case .laneSynth, .audio:
            return Controls(role: role, level: true, pan: true, muteSolo: true)
        case .bio, .unplayed, .noVoice:
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
        case .noVoice(let capacity):
            return capacity > 0
                ? "No voice — only the first \(capacity) extra MIDI tracks play"
                : "No voice — extra MIDI tracks are off in this build"
        }
    }

    /// Whether a track may be removed, and if not, why (WA4 "remove track").
    enum Removal: Equatable, Sendable {
        case allowed
        /// It still holds parts; the store only removes an EMPTY lane, and a part removal is
        /// undoable where a lane removal is not — so the parts go first, one undo step each.
        case hasParts(Int)
        /// It holds parts this build has no editor for (a video or visual lane from an older
        /// project), so there is no way to empty it — say so rather than ask for the impossible.
        case uneditableParts(Int)
        /// The Echoel instrument plays this track. Removing it would silently hand the
        /// instrument (and its level) to the next MIDI track.
        case echoelTrack
        /// A recorded bio curve lives here.
        case bio
    }

    nonisolated static func removal(of laneID: UUID, in document: TimelineDocument) -> Removal? {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return nil }
        if lane.isBio { return .bio }
        if document.rollLaneID == laneID { return .echoelTrack }
        let parts = document.regions.filter { $0.laneID == laneID }.count
        guard parts > 0 else { return .allowed }
        return TrackParts.arrangeable(laneID, in: document) ? .hasParts(parts) : .uneditableParts(parts)
    }

    nonisolated static func removalNote(_ removal: Removal) -> String {
        switch removal {
        case .allowed:           return "Removes this empty track. Undo cannot bring the track, or parts it held earlier, back."
        case .hasParts(let n):   return n == 1 ? "Remove its part first to remove this track."
                                               : "Remove its \(n) parts first to remove this track."
        case .uneditableParts:   return "This track holds parts this version cannot edit, so it stays."
        case .echoelTrack:       return "The Echoel instrument plays this track, so it stays."
        case .bio:               return "This track holds a recorded bio curve, so it stays."
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

    /// Only an EMPTY, non-Echoel, non-bio track; the store refuses a lane with parts anyway.
    @MainActor
    static func removeTrack(laneID: UUID, timeline: TimelineStore) {
        guard removal(of: laneID, in: timeline.document) == .allowed else { return }
        timeline.removeLaneIfEmpty(id: laneID)
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
    /// Read for `laneVoiceCapacity` only — a cold, unobserved number set once at start.
    @Environment(TimelineRegionPlayer.self) private var player
    let laneID: UUID
    /// The name being typed. Local and cold; committed on Return, on focus loss and on close.
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let document = timeline.document
        if let lane = document.lanes.first(where: { $0.id == laneID }),
           let controls = TrackMix.controls(of: laneID, in: document,
                                            voiceCapacity: player.laneVoiceCapacity) {
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
                        .focused($nameFocused)
                        .onSubmit { commitName() }
                        .onChange(of: nameFocused) { _, focused in
                            if !focused { commitName() }
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
                            ? "1.00 unchanged, 0 silent. This is also the level the Studio instrument plays at; its Start lifts 0 back to 1.00"
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
                                    hint: controls.role == .echoelInstrument
                                        ? "Plays only the soloed tracks"
                                        : "Plays only the soloed tracks. This also silences the Studio instrument, whose Start clears the solo") {
                            TrackMix.flipSolo(laneID: laneID, timeline: timeline)
                        }
                    }
                }
                // WA4.3 — the track's parts: move, copy, remove, and the part-edit Undo/Redo.
                // Its own leaf; it hides itself on a track with nothing to arrange.
                TrackPartsView(laneID: laneID)
                if let removal = TrackMix.removal(of: laneID, in: document) {
                    removeRow(removal)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .padding(.leading, 26)
            .onAppear { nameDraft = lane.name }
            .onDisappear { commitName() }
        }
    }

    /// Store the typed name if it changed; otherwise, or when it is refused, show the stored one.
    private func commitName() {
        guard let stored = timeline.document.lanes.first(where: { $0.id == laneID })?.name else { return }
        let typed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if typed == stored { return }
        if !TrackMix.rename(nameDraft, laneID: laneID, timeline: timeline) {
            nameDraft = stored
        }
    }

    private func removeRow(_ removal: TrackMix.Removal) -> some View {
        let allowed = removal == .allowed
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                TrackMix.removeTrack(laneID: laneID, timeline: timeline)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle").font(.system(size: 12, weight: .semibold))
                    Text("Remove track").font(EchoelTheme.font(12, .semibold))
                }
                .foregroundStyle(allowed ? EchoelTheme.text : EchoelTheme.dim)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!allowed)
            .accessibilityHint(TrackMix.removalNote(removal))
            Text(TrackMix.removalNote(removal))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
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
                // Monochrome primary fill, never a green area behind a label (EchoelTheme).
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(on ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityHint(hint)
    }
}
