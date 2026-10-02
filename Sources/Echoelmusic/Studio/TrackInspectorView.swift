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
//  · the Sound row (Workstation redesign B2a) only on a POLY rack track — the one voice a lane
//    patch reaches (`LaneVoiceRack.applyPatch` → `voice(slot:)?.apply`, a documented no-op for
//    the other kinds). Not on the Echoel track: its patch sink swaps the instrument's own voice
//    (`rollPatchSink`); its sound is the Sound panel behind its device. A pick is ONE Undo step
//    (B2b): the row wraps it in `TimelineStore.editLanePatch(id:_:)`.
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
//  ⚠️ A typed name is committed on Return, when the field loses focus, when the inspector
//  closes, and when its page changes — a field that shows a name the song never stored is a
//  second truth on screen.
//
//  ⭐ A8 — ONE page at a time: a segmented control at the top picks Track (name · level ·
//  pan · remove), Part (the track's parts, only where `TrackParts.arrangeable`) or Device
//  (what plays the track · instrument · instance · style · effect). The choice lives on
//  `WorkstationSelection` — view state, cold (a tap), kept across a change of track, never
//  persisted. A track without the chosen page shows Track.
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
        /// B2a: the Sound row — a sound for the track's voice, on a POLY rack track only:
        /// `LaneVoiceRack.applyPatch` reaches `voice(slot:)?.apply`, the poly engine; the sub-bass,
        /// the body voice and the sampler take no patch. The same set as `effect` today, with its
        /// own reason, so a per-track chain on another kind does not drag this row along.
        let sound: Bool
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
                            genre: document.echoelGenre != nil, sound: false)
        case .laneSynth(let kind):
            // Review of 895cf025a (MED): `LaneVoiceRack.setPan` is a documented no-op for the
            // sub-bass and the sampler unit — a pan field there would move a number, not the sound.
            return Controls(role: role, level: true, pan: kind != .subBass && kind != .sampler,
                            muteSolo: true, effect: kind == .poly, genre: false,
                            sound: kind == .poly)
        case .audio:
            return Controls(role: role, level: true, pan: true, muteSolo: true, effect: false, genre: false,
                            sound: false)
        case .bio, .unplayed, .noVoice:
            return Controls(role: role, level: false, pan: false, muteSolo: false, effect: false, genre: false,
                            sound: false)
        }
    }

    /// A8 — the inspector's pages for a track. Track and Device on every track (each has a name
    /// and something — or nothing — that plays it); Part only where there are parts to arrange:
    /// `TrackParts.arrangeable`, the rule `TrackPartsView` hides itself by (#416), so the page
    /// is never an empty box.
    nonisolated static func inspectorPages(of laneID: UUID, in document: TimelineDocument) -> [TrackInspectorPage] {
        TrackParts.arrangeable(laneID, in: document) ? [.track, .part, .device] : [.track, .device]
    }

    nonisolated static func deviceName(_ role: Role) -> String {
        switch role {
        case .echoelInstrument:   return String(localized: "Echoel instrument")
        case .laneSynth(let kind): return voiceName(kind)
        case .audio:              return String(localized: "Audio file player")
        case .bio:                return String(localized: "Bio curve — no sound")
        case .unplayed:           return String(localized: "No engine plays this track yet")
        case .noVoice(let capacity):
            let limited: String = String(localized: "No voice — only the first ") + "\(capacity)" + String(localized: " extra MIDI tracks play")
            return capacity > 0 ? limited : String(localized: "No voice — extra MIDI tracks are off in this build")
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
        case .allowed:           return String(localized: "Removes this empty track. Undo cannot bring the track, or parts it held earlier, back.")
        case .hasParts(let n):
            // E4-61: the count is seamed between two catalog keys; the singular is its own key.
            let several: String = String(localized: "Remove its ") + "\(n)" + String(localized: " parts first to remove this track.")
            return n == 1 ? String(localized: "Remove its part first to remove this track.") : several
        case .uneditableParts:   return String(localized: "This track holds parts this version cannot edit, so it stays.")
        case .echoelTrack:       return String(localized: "The Echoel instrument plays this track, so it stays.")
        case .bio:               return String(localized: "This track holds a recorded bio curve, so it stays.")
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

    /// What the Level field says on a track with `role` — the Echoel track's level is also the
    /// Studio instrument's. ONE wording, read by the inspector and the piece mixer (B3).
    nonisolated static func levelHint(_ role: Role) -> String {
        role == .echoelInstrument
            ? String(localized: "1.00 unchanged, 0 silent. This is also the level the Studio instrument plays at; its Start lifts 0 back to 1.00")
            : String(localized: "1.00 unchanged, 0 silent, 2.00 is +6 dB")
    }

    /// What Mute says it does on a track with `role` — the coupling with the Studio instrument
    /// named where it exists. ONE wording, read by the track header (WA4 path 6).
    nonisolated static func muteHint(_ role: Role) -> String {
        role == .echoelInstrument
            ? String(localized: "Silences this track and the Studio instrument. Start un-mutes it")
            : String(localized: "Silences this track")
    }

    /// What Solo says it does: soloing any track but the Echoel one silences the instrument too
    /// (`effectiveGain` zeroes every unsoloed lane), and the instrument's Start clears it.
    nonisolated static func soloHint(_ role: Role) -> String {
        role == .echoelInstrument
            ? String(localized: "Plays only the soloed tracks")
            : String(localized: "Plays only the soloed tracks. This also silences the Studio instrument, whose Start clears the solo")
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
        String(localized: "The voice this track plays its parts with. EchoelBass and EchoelBodyVibe each play one track at a time, the higher one in the list; another track that picks one plays EchoelSynth. A track on EchoelBodyVibe cannot be armed to record MIDI")

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

    /// B2a — what the track's Sound row can hold: the voice's default (no lane patch), a sound
    /// from `PatchStore` by id, or the copy the piece keeps when no stored sound equals it (a
    /// sound saved by another install, or one edited in the Sound panel since it was chosen).
    enum SoundChoice: Hashable, Sendable {
        case standard
        case kept
        case library(UUID)
    }

    /// The lane's own patch when no stored sound equals it — the piece's copy, shown as the
    /// current value so a pick of something else is a choice, never a silent loss.
    nonisolated static func keptSound(of laneID: UUID, in document: TimelineDocument,
                                      library: [SynthPatch]) -> SynthPatch? {
        guard let patch = document.lanes.first(where: { $0.id == laneID })?.patch,
              !library.contains(patch) else { return nil }
        return patch
    }

    /// What the row shows as chosen. No lane patch is Default: the app's slot sink then plays the
    /// first stored sound (`patch ?? fallbackPatch` in `EchoelmusicApp`).
    nonisolated static func soundChoice(of laneID: UUID, in document: TimelineDocument,
                                        library: [SynthPatch]) -> SoundChoice {
        guard let patch = document.lanes.first(where: { $0.id == laneID })?.patch else { return .standard }
        if keptSound(of: laneID, in: document, library: library) != nil { return .kept }
        return .library(patch.id)
    }

    /// The pick's lane patch: nil for Default, a COPY of the stored sound for a pick (the piece
    /// carries its sound, as it carries its effect), and no write at all for the kept copy, an
    /// unknown id or what already plays — the field is structural, so a write re-primes every
    /// rack lane mid-playback for nothing audible. Records no undo step: the Sound row wraps this
    /// call in `editLanePatch(id:_:)` (B2b), so the funnel stays the bare path, as in B3b.
    @MainActor
    static func setSound(_ choice: SoundChoice, laneID: UUID, library: [SynthPatch], timeline: TimelineStore) {
        guard let lane = timeline.document.lanes.first(where: { $0.id == laneID }) else { return }
        let next: SynthPatch?
        switch choice {
        case .kept:
            return
        case .standard:
            next = nil
        case .library(let id):
            guard let patch = library.first(where: { $0.id == id }) else { return }
            next = patch
        }
        guard lane.patch != next else { return }
        timeline.setLanePatch(laneID, patch: next)
    }

    nonisolated static let soundHint =
        String(localized: "The sound EchoelSynth plays this track's parts with. Default plays the first of the Sounds. The piece keeps its own copy of the chosen sound")

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
    /// A8 — read for `inspectorPage` only: cold, it changes on a tap of the page control.
    @Environment(WorkstationSelection.self) private var selection
    /// B2a — read for the Sound row's menu only: cold, the stored sounds change on a save.
    @Environment(PatchStore.self) private var patchStore
    let laneID: UUID
    /// The name being typed. Local and cold; committed on Return, on focus loss and on close.
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let document = timeline.document
        if let lane = document.lanes.first(where: { $0.id == laneID }),
           let controls = TrackMix.controls(of: laneID, in: document,
                                            voiceCapacity: player.laneVoiceCapacity) {
            // A8 — the page this track's inspector draws: the one chosen on the selection owner,
            // or Track when this track has no such page (Part on a bio track).
            let pages = TrackMix.inspectorPages(of: laneID, in: document)
            let page = TrackInspectorPage.shown(selection.inspectorPage, offered: pages)
            VStack(alignment: .leading, spacing: 8) {
                // Segmented, not a `.menu`: no popover for a re-render to tear down. Three short
                // words, meant to fit the 260-pt landscape column (A9) — a device check, not a fact.
                Picker("Inspector", selection: Binding<TrackInspectorPage>(
                    get: { page },
                    set: { picked in
                        // The Name field may be about to leave the screen with a typed draft.
                        commitName()
                        selection.showInspectorPage(picked)
                    })) {
                    Text("Track").tag(TrackInspectorPage.track)
                    if pages.contains(.part) {
                        Text("Part").tag(TrackInspectorPage.part)
                    }
                    Text("Device").tag(TrackInspectorPage.device)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minHeight: 44)
                .accessibilityHint("Shows this track, its parts or the device that plays it")

                if page == .device {
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
                    // B2a — which stored sound this POLY rack track's voice plays (no row elsewhere).
                    if controls.sound {
                        soundRow
                    }
                    // What this Echoel is set to — genre and FX character, read-only, from the
                    // instrument's own keys (`EchoelInstanceLine`; the inspector owns no persistence).
                    if controls.role == .echoelInstrument {
                        EchoelInstanceLine()
                    }
                    // A8: Style and Effect are facts of the DEVICE, so they moved up from under Pan.
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
                }

                if page == .track {
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
                                // B3c: every finger sample runs inside the person's gesture; the
                                // field's commit closes it — ONE Undo step per drag (B3b's path).
                                set: { newLevel in
                                    timeline.editLaneMix(id: laneID) { TrackMix.setLevel(newLevel, laneID: laneID, timeline: timeline) }
                                }),
                            range: TrackMix.levelRange,
                            decimals: 2,
                            hint: TrackMix.levelHint(controls.role),
                            // `standard:` AFTER `hint:` — the memberwise initialiser demands declaration
                            // order (`EchoelValueField.hint` is declared above `standard`).
                            standard: Double(TimelineLane.defaultLevel),
                            onCommit: { timeline.commitLaneMix(id: laneID) })
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
                                set: { newPan in
                                    timeline.editLaneMix(id: laneID) { TrackMix.setPan(newPan, laneID: laneID, timeline: timeline) }
                                }),
                            range: TrackMix.panRange,
                            decimals: 2,
                            hint: String(localized: "−1 left, 0 centre, 1 right"),
                            standard: Double(TimelineLane.defaultPan),
                            onCommit: { timeline.commitLaneMix(id: laneID) })
                    }
                    // WA4 path 6 — Mute and Solo moved to the track HEADER (`WorkstationView.laneRow`):
                    // one control per fact on screen, reachable without opening this inspector.
                    if let removal = TrackMix.removal(of: laneID, in: document) {
                        removeRow(removal)
                    }
                }

                if page == .part {
                    // WA4.3 — the track's parts: a row selects its part; the part bar under the
                    // arrangement acts on it. Its own leaf; the page exists only where it has rows.
                    TrackPartsView(laneID: laneID)
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
    /// stage, where the studio is hidden); the way back is the switcher's "Arrange" (DAW shell S2).
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
        .accessibilityHint("Shows its sound controls in Instrument. Arrange brings you back")
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

    /// B2a — the track's sound, a NAMED choice (menu Picker, not a number): Default, the piece's
    /// own copy when no stored sound equals it, then every stored sound in `PatchStore` order
    /// (factory first, so "the first of the Sounds" is the slot sink's fallback). Cold reads of
    /// the song and the store; one store write per real change (`TrackMix.setSound`), and each real
    /// change is ONE Undo step (`editLanePatch`, B2b).
    private var soundRow: some View {
        HStack(spacing: 8) {
            Text("Sound")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .accessibilityHidden(true)   // the Picker speaks the label once
            Picker("Sound", selection: Binding<TrackMix.SoundChoice>(
                get: { TrackMix.soundChoice(of: laneID, in: timeline.document, library: patchStore.patches) },
                set: { choice in
                    timeline.editLanePatch(id: laneID) {
                        TrackMix.setSound(choice, laneID: laneID, library: patchStore.patches, timeline: timeline)
                    }
                })) {
                Text("Default").tag(TrackMix.SoundChoice.standard)
                if let kept = TrackMix.keptSound(of: laneID, in: timeline.document, library: patchStore.patches) {
                    Section("In this piece") {
                        Text(kept.name).tag(TrackMix.SoundChoice.kept)
                    }
                }
                Section("Sounds") {
                    ForEach(patchStore.patches) { patch in
                        Text(patch.name).tag(TrackMix.SoundChoice.library(patch.id))
                    }
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .frame(minHeight: 44)
            .accessibilityHint(TrackMix.soundHint)
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
            .accessibilityHint("Default is this voice's own sound. The track keeps its effect in the piece")
            Spacer(minLength: 0)
        }
    }

    /// EF2 — the Echoel instance's genre, the curated list grouped by shelf (the
    /// `MusicStyle.Subcategory` root). Since A2 (founder 2026-10-01) this is the ONE on-screen door
    /// and it reads "Style": the genre left the header and became a property of the device.
    /// Cold read of the song; the `?? StudioDefaultKeys.genre.value` is unreachable — the row is
    /// shown only when the instance holds a genre.
    private var echoelGenreRow: some View {
        HStack(spacing: 8) {
            Text("Style")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Style", selection: Binding<MusicStyle>(
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
            .accessibilityHint("The style the Echoel instrument composes in. The piece keeps it")
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
            .accessibilityHint("The Echoel instrument's effect. The piece keeps it")
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
