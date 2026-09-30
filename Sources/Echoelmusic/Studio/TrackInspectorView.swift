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
//  · the Effect row (Phase 3 / DC1, the track's `DeviceChain`) only on a POLY rack track —
//    the one voice with its own FX chain. On the Echoel track (EF1) it sets the song's Echoel
//    INSTANCE (`DeviceChain.instrument`), shown only once the song holds a readable one — a row
//    that guessed the value would be a second truth on screen.
//  ⚠️ And the COUPLINGS with the Studio instrument are stated rather than hidden (review of
//  b2913f96b): the Echoel track's level is the level the instrument plays at (`rollSlotGain` →
//  `mixGain`, the one writer in `EchoelmusicApp`), so muting it or pulling it to 0 silences
//  the instrument; soloing ANY other track does too (`effectiveGain` zeroes every unsoloed
//  lane); and the instrument's Start heals all three (`unsilenceRollSlot`: unmute, a zeroed
//  fader back to 1.00, every other solo cleared). Each hint names the coupling it carries.
//  ⚠️ Mute and Solo are no longer drawn HERE (WA4 path 6): they sit in the track header in
//  `WorkstationView.laneRow`, gated on the same `controls.muteSolo` and speaking the same
//  `muteHint`/`soloHint`. The writes stay in `TrackMix` in this file — one door per fact.
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
        /// Phase 3 / DC1: an effect insert (`DeviceChain`) sounds only on a POLY rack voice —
        /// the one kind with its own `EchoelFXChain`. EF1: on the Echoel track the row sets the
        /// song's Echoel instance, and exists only while the song holds a readable one
        /// (`TimelineDocument.echoelFXCharacter`). Sub, sampler, bio and audio tracks have no
        /// per-track chain yet, so the row would move a name and not the sound.
        let effect: Bool
        /// Phase 3 / EF2: the Echoel track's Genre row — only while the song holds the instance's
        /// genre (`TimelineDocument.echoelGenre`), for the same reason as the Echoel Effect row.
        let genre: Bool
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
            return Controls(role: role, level: true, pan: false, muteSolo: true,
                            effect: document.echoelFXCharacter != nil,
                            genre: document.echoelGenre != nil)
        case .laneSynth(let kind):
            // Review of 895cf025a (MED): `LaneVoiceRack.setPan` is a documented no-op for the
            // sub-bass and the sampler unit — a pan field there would move a number, not the sound.
            return Controls(role: role, level: true, pan: kind != .subBass && kind != .sampler,
                            muteSolo: true, effect: kind == .poly, genre: false)
        case .audio:
            return Controls(role: role, level: true, pan: true, muteSolo: true, effect: false, genre: false)
        case .bio, .unplayed, .noVoice:
            return Controls(role: role, level: false, pan: false, muteSolo: false, effect: false, genre: false)
        }
    }

    nonisolated static func deviceName(_ role: Role) -> String {
        switch role {
        case .echoelInstrument:   return "Echoel instrument"
        case .laneSynth(let kind): return voiceName(kind)
        case .audio:              return "Audio file player"
        case .bio:                return "Bio curve — no sound"
        case .unplayed:           return "No engine plays this track yet"
        case .noVoice(let capacity):
            return capacity > 0
                ? "No voice — only the first \(capacity) extra MIDI tracks play"
                : "No voice — extra MIDI tracks are off in this build"
        }
    }

    /// A rack voice by the name the Instrument row gives it — ONE name per voice on one screen
    /// (review of 895cf025a, MED: the Device row said "Sub bass" above "Instrument EchoelBass").
    nonisolated static func voiceName(_ kind: LaneVoiceKind) -> String {
        switch kind {
        case .poly:     return TrackInstrument.polySynth.displayName
        case .subBass:  return TrackInstrument.subBass.displayName
        case .bioVoice: return TrackInstrument.bioVoice.displayName
        case .sampler:  return TrackInstrument.sampler.displayName
        case .drums:    return kind.displayName
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

    /// The track level as a mixing engineer reads it — "−6.0 dB", "+6.0 dB", "0.0 dB", and
    /// "−∞ dB" for silence (design slice 8, the mockup's dB fader). The field stays linear
    /// (0…2, `levelRange`); this is a static reading of the stored gain, never a meter.
    /// A non-finite or non-positive level is silence, not a number.
    nonisolated static func decibelText(_ level: Double) -> String {
        guard level.isFinite, level > 0 else { return "−∞ dB" }
        let db = (20 * log10(level) * 10).rounded() / 10
        if db == 0 { return "0.0 dB" }
        return (db > 0 ? "+" : "−") + String(format: "%.1f", abs(db)) + " dB"
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

    /// What Mute says it does on a track with `role` — the coupling with the Studio instrument
    /// named where it exists. ONE wording, read by the track header (WA4 path 6).
    nonisolated static func muteHint(_ role: Role) -> String {
        role == .echoelInstrument
            ? "Silences this track and the Studio instrument. Start un-mutes it"
            : "Silences this track"
    }

    /// What Solo says it does: soloing any track but the Echoel one silences the instrument too
    /// (`effectiveGain` zeroes every unsoloed lane), and the instrument's Start clears it.
    nonisolated static func soloHint(_ role: Role) -> String {
        role == .echoelInstrument
            ? "Plays only the soloed tracks"
            : "Plays only the soloed tracks. This also silences the Studio instrument, whose Start clears the solo"
    }

    /// DMMW Phase 4 · slice 2 — the instruments a track can be switched to: exactly the kinds
    /// the lane rack binds on a SECONDARY slot (`LaneVoiceRack.setKind` → `KindVoiceAllocator`),
    /// so only on a `.laneSynth` track. NOT on the Echoel track: its kind sink swaps the
    /// generative instrument's own voice (`rollKindSink`), which would replace the instrument
    /// rather than choose a track's sound. The sampler is left out — it needs a sample before it
    /// makes a sound, and this row assigns none. A legacy choice (EchoelDrums, EchoelBreak,
    /// EchoelSampler) is kept as the current value by the row, never offered anew.
    nonisolated static func instrumentChoices(_ role: Role) -> [TrackInstrument] {
        guard case .laneSynth = role else { return [] }
        return [.polySynth, .subBass, .bioVoice]
    }

    /// What the row shows as chosen: the lane's instrument, or EchoelSynth — the voice a lane
    /// without one plays (`builtinInstrument?.voiceKind ?? .poly`, the player's own fallback).
    nonisolated static func currentInstrument(of laneID: UUID, in document: TimelineDocument) -> TrackInstrument {
        document.lanes.first(where: { $0.id == laneID })?.builtinInstrument ?? .polySynth
    }

    /// The Picker's entries: the choices, plus a legacy current value so the menu can show it.
    nonisolated static func instrumentMenu(_ role: Role, current: TrackInstrument) -> [TrackInstrument] {
        let choices = instrumentChoices(role)
        guard !choices.isEmpty, !choices.contains(current) else { return choices }
        return [current] + choices
    }

    /// The rack holds ONE sub-bass and ONE body voice (`LaneVoiceRack.attachAll`); a further track
    /// that picks either plays the synth instead (`KindVoiceAllocator`: never silence), and the
    /// allocator serves the tracks in list order, so the higher track wins. EchoelBodyVibe's
    /// record source is the body (`TrackInstrument.recordSource`), and `RecordTake.canArm` arms
    /// MIDI input only — so its track cannot be armed (review of 895cf025a, MED).
    nonisolated static let instrumentHint =
        "The voice this track plays its parts with. EchoelBass and EchoelBodyVibe each play one track at a time, the higher one in the list; another track that picks one plays EchoelSynth. A track on EchoelBodyVibe cannot be armed to record MIDI"

    /// One store write through the lane's existing writer (`setBuiltinInstrument`) — the field
    /// the player already reads when a part loads (`MultiRollFanout.voiceKind`).
    @MainActor
    static func setInstrument(_ instrument: TrackInstrument, laneID: UUID, timeline: TimelineStore) {
        // A pick of what already plays is not an edit: the field is structural, and a write would
        // flush and re-prime every rack lane mid-playback for nothing audible (review LOW).
        guard instrument != currentInstrument(of: laneID, in: timeline.document) else { return }
        timeline.setBuiltinInstrument(id: laneID, instrument)
    }

    /// The effects a track can carry: every character with its OWN preset. `.auto` is not one —
    /// it means "the genre's effect", and a track does not own the genre (`soundingCharacter`).
    nonisolated static var effectChoices: [FXCharacter] {
        FXCharacter.allCases.filter { $0 != .auto && $0.preset != nil }
    }

    /// One bounded commit, one persist — the store is the one writer (`setLaneEffect`).
    @MainActor
    static func setEffect(_ character: FXCharacter?, laneID: UUID, timeline: TimelineStore) {
        timeline.setLaneEffect(laneID, character: character)
    }

    /// EF1 — the Echoel track's effect: every character, `.auto` ("the genre's effect") first,
    /// because the Echoel instrument DOES own a genre.
    nonisolated static var echoelEffectChoices: [FXCharacter] { FXCharacter.allCases }

    /// EF1 — one store write (`setEchoelFXCharacter`, the instance's one writer), then the
    /// instrument's own funnel, so the Studio adopts and SOUNDS it (`adoptEchoelFXFromSong`).
    /// This leaf reaches into none of the Studio's state.
    @MainActor
    static func setEchoelEffect(_ character: FXCharacter, timeline: TimelineStore) {
        timeline.setEchoelFXCharacter(character)
        NotificationCenter.default.post(name: .echoelCompositionEdited, object: "fxCharacter")
    }

    /// EF1 (review of 6d68bea64, M3) — the Echoel track opened on a song whose roll lane holds NO
    /// instrument yet (its first MIDI track was added after launch, e.g. by a MIDI import) asks
    /// the instrument to state its instance: the Studio's adoption imports the working copy, and
    /// the Effect row appears. Only when the slot is EMPTY — a later build's instance is kept and
    /// the row stays hidden (the store refuses to rewrite it). Posting changes nothing but that
    /// one missing fact: the adoption does not recompose.
    /// EF2: the same for each FACT the instance lacks — a song written by EF1 carries the FX
    /// character and no genre — so each missing fact is imported once. "Missing" means "reads as
    /// nil": a v1 field naming a value this build does not know is replaced too, exactly as the
    /// launch adoption replaces it (review LOW-3).
    @MainActor
    static func requestEchoelInstanceIfMissing(laneID: UUID, timeline: TimelineStore, voiceCapacity: Int) {
        let document = timeline.document
        guard role(of: laneID, in: document, voiceCapacity: voiceCapacity) == .echoelInstrument else { return }
        let instrument = document.lanes.first(where: { $0.id == laneID })?.deviceChain?.instrument
        // Writable = an empty slot, or an Echoel instance this build reads.
        guard instrument == nil || instrument?.echoelFields != nil else { return }
        if document.echoelFXCharacter == nil {
            NotificationCenter.default.post(name: .echoelCompositionEdited, object: "fxCharacter")
        }
        if document.echoelGenre == nil {
            NotificationCenter.default.post(name: .echoelCompositionEdited, object: "echoelGenre")
        }
    }

    /// EF2 — the Echoel's genre from its track: one store write, then the instrument's own
    /// `"echoelGenre"` edit, which adopts it with the full genre semantics (scale, timbre, echo
    /// division, recompose). The choices are the instrument's own curated list.
    @MainActor
    static func pickEchoelGenre(_ genre: MusicStyle, timeline: TimelineStore) {
        timeline.setEchoelGenre(genre)
        NotificationCenter.default.post(name: .echoelCompositionEdited, object: "echoelGenre")
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
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Device")
                            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        Text(TrackMix.deviceName(controls.role))
                            .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                    }
                    .accessibilityElement(children: .combine)
                    // WA4 path 9 — the Echoel track's device opens the instrument's own editor.
                    // OUTSIDE the combined element (#621), and only on the track the
                    // instrument plays: a rack voice or an audio player has no such editor.
                    if controls.role == .echoelInstrument {
                        Spacer(minLength: 0)
                        openDeviceButton
                    }
                }
                // Phase 4 · slice 2 — which instrument this rack track plays (empty elsewhere).
                let instruments = TrackMix.instrumentMenu(
                    controls.role, current: TrackMix.currentInstrument(of: laneID, in: document))
                if !instruments.isEmpty {
                    instrumentRow(instruments)
                }
                // What this Echoel is set to — genre and FX character, read-only, from the
                // instrument's own keys (`EchoelInstanceLine`; the inspector owns no persistence).
                if controls.role == .echoelInstrument {
                    EchoelInstanceLine()
                }

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
                    let level = Double(timeline.document.lanes.first(where: { $0.id == laneID })?.level ?? TimelineLane.defaultLevel)
                    EchoelValueField(
                        label: "Level",
                        value: Binding(
                            get: { Double(timeline.document.lanes
                                .first(where: { $0.id == laneID })?.level ?? TimelineLane.defaultLevel) },
                            set: { TrackMix.setLevel($0, laneID: laneID, timeline: timeline) }),
                        range: TrackMix.levelRange,
                        decimals: 2,
                        standard: Double(TimelineLane.defaultLevel),
                        hint: controls.role == .echoelInstrument
                            ? "1.00 unchanged, 0 silent. This is also the level the Studio instrument plays at; its Start lifts 0 back to 1.00"
                            : "1.00 unchanged, 0 silent, 2.00 is +6 dB")
                    // Design slice 8: the same stored gain, read in decibels. Cold — the level
                    // moves on an edit, never on a clock.
                    Text(TrackMix.decibelText(level))
                        .font(EchoelTheme.font(11).monospacedDigit())
                        .foregroundStyle(EchoelTheme.dim)
                        .accessibilityLabel("Level in decibels")
                        .accessibilityValue(TrackMix.decibelText(level))
                }
                if controls.pan {
                    EchoelValueField(
                        label: "Pan",
                        value: Binding(
                            get: { Double(timeline.document.lanes
                                .first(where: { $0.id == laneID })?.pan ?? TimelineLane.defaultPan) },
                            set: { TrackMix.setPan($0, laneID: laneID, timeline: timeline) }),
                        range: TrackMix.panRange,
                        decimals: 2,
                        standard: Double(TimelineLane.defaultPan),
                        hint: "−1 left, 0 centre, 1 right")
                }
                if controls.genre {
                    echoelGenreRow
                }
                if controls.effect {
                    if controls.role == .echoelInstrument {
                        echoelEffectRow
                    } else {
                        effectRow
                    }
                }
                // WA4 path 6 — Mute and Solo moved to the track HEADER (`WorkstationView.laneRow`):
                // one control per fact on screen, reachable without opening this inspector.
                // WA4.3 — the track's parts: move, copy, remove, and the part-edit Undo/Redo.
                // Its own leaf; it hides itself on a track with nothing to arrange.
                TrackPartsView(laneID: laneID)
                if let removal = TrackMix.removal(of: laneID, in: document) {
                    removeRow(removal)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .padding(.leading, 26)
            .onAppear {
                nameDraft = lane.name
                TrackMix.requestEchoelInstanceIfMissing(laneID: laneID, timeline: timeline,
                                                        voiceCapacity: player.laneVoiceCapacity)
            }
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

    /// Opens the Echoel instrument's sound controls — the Sound plate, which IS the device's
    /// editor (patch, presets, tone). It posts the existing chrome door rather than reaching
    /// into the Studio's state: this view is a leaf of the arrangement and owns none of it.
    /// Since slice 2b the receiver also turns the Instrument STAGE (this leaf lives on the Piece
    /// stage, where the studio is hidden); the way back is the seam's "Piece".
    private var openDeviceButton: some View {
        Button {
            NotificationCenter.default.post(name: .echoelChromeDoor, object: "sound")
        } label: {
            Text("Open")
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open the Echoel instrument")
        .accessibilityHint("Shows its sound controls on the Instrument stage. Piece brings you back")
    }

    /// Phase 4 · slice 2 — the track's instrument, a NAMED choice (menu Picker, not a number).
    /// Cold read of the song, one store write per choice.
    private func instrumentRow(_ instruments: [TrackInstrument]) -> some View {
        HStack(spacing: 8) {
            Text("Instrument")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .accessibilityHidden(true)   // the Picker speaks the label once (review LOW)
            Picker("Instrument", selection: Binding<TrackInstrument>(
                get: { TrackMix.currentInstrument(of: laneID, in: timeline.document) },
                set: { TrackMix.setInstrument($0, laneID: laneID, timeline: timeline) })) {
                ForEach(instruments, id: \.self) { instrument in
                    Text(instrument.displayName).tag(instrument)
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .frame(minHeight: 44)
            .accessibilityHint(TrackMix.instrumentHint)
            Spacer(minLength: 0)
        }
    }

    /// DC1 — the track's effect insert, a NAMED choice, so a menu Picker (the `EchoelValueField`
    /// law is for numbers). "Default" is the voice's shipped sound, not dry — "Clean (dry)" is dry.
    /// Cold read of `timeline.document`, one store write per choice.
    private var effectRow: some View {
        HStack(spacing: 8) {
            Text("Effect")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Effect", selection: Binding<FXCharacter?>(
                get: { timeline.document.lanes.first(where: { $0.id == laneID })?
                    .deviceChain?.soundingCharacter },
                set: { TrackMix.setEffect($0, laneID: laneID, timeline: timeline) })) {
                Text("Default").tag(FXCharacter?.none)
                ForEach(TrackMix.effectChoices) { character in
                    Text(character.displayName).tag(Optional(character))
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .accessibilityHint("Default is this voice's own sound. The track keeps its effect in the song")
            Spacer(minLength: 0)
        }
    }

    /// EF2 — the Echoel instance's genre, the header's curated list grouped by shelf (the same
    /// `MusicStyle.Subcategory` root, so a genre the header offers is offered here and no other).
    /// Cold read of the song; the `?? StudioDefaultKeys.genre.value` is unreachable — the row is
    /// shown only when the instance holds a genre.
    private var echoelGenreRow: some View {
        HStack(spacing: 8) {
            Text("Genre")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Genre", selection: Binding<MusicStyle>(
                get: { timeline.document.echoelGenre ?? StudioDefaultKeys.genre.value },
                set: { TrackMix.pickEchoelGenre($0, timeline: timeline) })) {
                ForEach(MusicStyle.Subcategory.allCases) { shelf in
                    if !shelf.offeredGenres.isEmpty {
                        Section(shelf.title) {
                            ForEach(shelf.offeredGenres) { s in Text(s.displayName).tag(s) }
                        }
                    }
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .accessibilityHint("The genre the Echoel instrument composes in. The song keeps it")
            Spacer(minLength: 0)
        }
    }

    /// EF1 — the Echoel instance's effect, a NAMED choice (menu Picker). Reads the song's
    /// instance, cold; the `?? .auto` is unreachable — the row is shown only when it exists.
    private var echoelEffectRow: some View {
        HStack(spacing: 8) {
            Text("Effect")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Effect", selection: Binding<FXCharacter>(
                get: { timeline.document.echoelFXCharacter ?? .auto },
                set: { TrackMix.setEchoelEffect($0, timeline: timeline) })) {
                ForEach(TrackMix.echoelEffectChoices) { character in
                    Text(character.displayName).tag(character)
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .accessibilityHint("The Echoel instrument's effect. The song keeps it")
            Spacer(minLength: 0)
        }
    }

    private func removeRow(_ removal: TrackMix.Removal) -> some View {
        let allowed = removal == .allowed
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                TrackMix.removeTrack(laneID: laneID, timeline: timeline)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle").font(EchoelTheme.font(12, .semibold))
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
}
