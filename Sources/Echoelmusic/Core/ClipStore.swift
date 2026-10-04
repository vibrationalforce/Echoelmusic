// ClipStore.swift
// Echoel — the session grid of launchable clips. Holds a fixed set of slots,
// persisted as JSON in the App Group. The store is pure data.
// ⛔ "Capture/launch wiring … lives in the one-view Clips panel" stood here until #1109;
// that panel (`ClipView`) went with #121 Slice 4. Today the grid is filled by
// `TimelineStore.ensureComposerRegion` / `ensureUserMidiRegion` (composer-driven, one
// slot per lane) and read back by `TimelineRegionPlayer` / `ArrangementPlayer`; the
// hand-capture path (`TakeRecorder` via `RecordController`) is built but doorless (#204).

import Foundation
import Observation

@MainActor
@Observable
public final class ClipStore {

    /// How many cells the grid holds. B1 (2026-10-01) raised it from `legacySlotCount`; a shorter
    /// file or Session is PADDED at the end on read (`migratedGrid`), never re-seated — a region
    /// names its clip by id, the index only says where the clip sits. It is a BOUND, not the voice
    /// budget (that is per track, `LaneVoiceRack`): the grid rides whole in the Session envelope,
    /// is rewritten on every clip edit, and no production path clears a cell (`clear(at:)` has no
    /// caller) — so the ceiling moved, it did not go away. `nonisolated` so the import failures
    /// (nonisolated enums) can say the number (#416).
    public nonisolated static let slotCount = 64

    /// The size every build before B1 wrote and reads — those builds throw away any other count.
    public nonisolated static let legacySlotCount = 8

    /// The one migration from a stored grid to this build's grid. A grid of `slotCount` cells
    /// comes back unchanged; a SHORTER one is padded with empty cells at the END, so every clip
    /// keeps its cell; a LONGER one (a newer build's) is `nil` — truncating would drop clips a
    /// part still names. Pure; read by `init` and by `SessionSaveOpen`.
    public nonisolated static func migratedGrid(_ saved: [Clip?]) -> [Clip?]? {
        guard saved.count <= slotCount else { return nil }
        return saved + [Clip?](repeating: nil, count: slotCount - saved.count)
    }

    /// The grid as `persist` WRITES it: trailing empty cells past `legacySlotCount` are left off,
    /// never a filled one. Cells fill lowest-first and nothing clears one, so while at most eight
    /// clips exist the file is exactly the eight-cell file every earlier build reads — a rollback
    /// keeps them. Past eight, an earlier build still discards the file and its next clip write
    /// replaces it; that cost is real and is the founder's (FOUNDER_INBOX), not hidden here.
    nonisolated static func storedGrid(_ slots: [Clip?]) -> [Clip?] {
        let lastFilled = slots.lastIndex(where: { $0 != nil }) ?? -1
        return Array(slots.prefix(Swift.max(legacySlotCount, lastFilled + 1)))
    }

    /// Fixed grid of slots; `nil` = empty cell.
    public private(set) var slots: [Clip?]

    /// Counts USER writes of a clip's notes (`updateMelody` — the note editor and its Undo).
    /// The playing timeline reads it once per transport step and re-loads what it plays when
    /// it moved: a note edit changes the CLIP, not the song document, so the structure chase
    /// never sees it, and a part that spans the whole loop would keep its Play-time notes
    /// until Stop (Phase 3 / M1 review). NOT bumped by `updateComposerMelody` (the composer
    /// keeps its own delivery) and never observed — a view reading a counter churns.
    @ObservationIgnored public private(set) var userMelodyGeneration = 0

    @ObservationIgnored private let store = AppGroupStore(subdirectory: "Clips")
    @ObservationIgnored private static let fileName = "clips"

    public init() {
        // Element-tolerant, POSITIONALLY (see AppGroupStore.loadLossyArray). This grid is the
        // one store where a hole must be KEPT, not compacted: the index IS the slot, so
        // dropping a corrupt clip would shift every later one into the wrong cell — and since B1
        // the migration below would then PAD the shortened grid and keep it, re-seating every
        // later clip silently instead of refusing. `[Clip?]` already means
        // "nil = empty cell", so an unreadable clip degrades to exactly that: its own cell
        // empties, every other cell survives. Honest scope: `Clip.init(from:)` is `try?`-guarded
        // on every field, so a clip can only fail to decode if it is not a JSON object at all.
        // This is insurance against a non-object element, not a live everyday hazard.
        // B1: a file an older build wrote — or this build wrote through `storedGrid` — holds
        // FEWER cells; `migratedGrid` pads it at the end in memory. A file with MORE cells than
        // `slotCount` is a newer build's: it starts empty, and the next clip write replaces it.
        let saved = store.loadLossyArray(Clip?.self, name: Self.fileName)?.map { $0 ?? nil }
        if let saved, let grid = Self.migratedGrid(saved) {
            self.slots = grid
        } else {
            self.slots = Array(repeating: nil, count: Self.slotCount)
        }
    }

    /// Look up a clip by its stable id (used by the Arrangement player to
    /// resolve a section's `clipID` into content to load).
    public func clip(id: UUID) -> Clip? {
        slots.compactMap { $0 }.first { $0.id == id }
    }

    /// Non-empty clips, in slot order — the palette an Arrangement section picks
    /// from.
    public var filledClips: [Clip] { slots.compactMap { $0 } }

    /// The first empty slot, or `nil` when the grid is full. The audio /
    /// video import path lands a fresh clip here; a full grid surfaces to the
    /// user as "clip grid full" rather than silently overwriting. Pure lookup.
    public var firstEmptySlotIndex: Int? { slots.firstIndex(where: { $0 == nil }) }

    public func setClip(at index: Int, _ clip: Clip) {
        guard slots.indices.contains(index) else { return }
        slots[index] = clip
        persist()
    }

    /// H11: replace a clip's MIDI content by clip id (the clip-scoped editor's
    /// write-back — the first content-level clip edit; all timeline edits so
    /// far only moved region tick-windows). Whole-value write (Clip/MelodyClip
    /// are value types) so the region player, which re-reads
    /// `clip(id:)?.melody?.notes` at region onsets, never sees a torn state —
    /// a mid-play save becomes audible at the next onset, like any DAW.
    /// Returns false (writing nothing) for an unknown id.
    @discardableResult
    public func updateMelody(id: UUID, notes: [Note]) -> Bool {
        guard let i = slots.firstIndex(where: { $0?.id == id }),
              slots[i]?.kind == .midi else { return false }   // melody is MIDI content only
        slots[i]?.melody = MelodyClip(notes: notes)
        persist()
        userMelodyGeneration &+= 1
        return true
    }

    /// Per-lane composition Slice A: the COMPOSER's write-back — like
    /// `updateMelody` (whole-value write, next-onset audibility) but hard-gated
    /// on `Clip.composerOwned`, so an automatic generate/evolve can rewrite ONLY
    /// clips the composer itself created for a lane's override take. A
    /// user-captured/imported clip (`composerOwned == false`) is refused —
    /// returns false, writes nothing (the never-clobber law). No-op (true,
    /// no persist) when the notes are already identical, so the ~30 s evolve
    /// tick doesn't spam App-Group persistence.
    @discardableResult
    public func updateComposerMelody(id: UUID, notes: [Note]) -> Bool {
        guard let i = slots.firstIndex(where: { $0?.id == id }),
              let clip = slots[i], clip.kind == .midi, clip.composerOwned
        else { return false }
        guard clip.melody?.notes != notes else { return true }   // unchanged → no persist
        slots[i]?.melody = MelodyClip(notes: notes)
        persist()
        return true
    }

    /// Automation-in-Spur L1 (Item 1): the clip-scoped automation editor's
    /// write-back — sets the parameter-automation lanes the clip carries
    /// (`Clip.automation`, clip-relative ticks). Whole-value write like
    /// `updateMelody` so the region player, which re-reads `clip(id:)?.automation`
    /// and calls `setClipAutomation` at region onsets, never sees a torn state —
    /// a mid-play save becomes audible at the next onset. Applies to ANY clip
    /// kind (automation plays whenever the clip plays, MIDI or audio). No-op
    /// (true, no persist) when the lanes are VALUE-equal to what the clip already
    /// holds — so a read-modify-write editor that mutates `clip.automation` in
    /// place (preserving lane/point `id`s) doesn't spam App-Group persistence on
    /// a gesture that lands on the same value. (A caller that reconstructs lanes
    /// with fresh `id`s each write defeats the skip — `AutomationLane`/`Point`
    /// equality includes `id` — and will persist every time; the S2 editor keeps
    /// ids stable.) Returns false (writing nothing) for an unknown id.
    @discardableResult
    public func setClipAutomation(id: UUID, lanes: [AutomationLane]) -> Bool {
        guard let i = slots.firstIndex(where: { $0?.id == id }),
              var clip = slots[i] else { return false }
        guard clip.automation != lanes else { return true }   // unchanged → no persist
        clip.automation = lanes
        slots[i] = clip
        persist()
        return true
    }

    /// #B2: an imported AUDIO clip adopts its DETECTED native tempo — the first production
    /// writer of `Clip.nativeBPM`, and the reason a region can warp at all. Whole-value write
    /// like its neighbours. The decision (never-clobber, `isKnown` only) is
    /// `AudioTempoAnalysis.adoptableNativeBPM`, pure and driven with plain values; this method
    /// adds only the lookup, the `.audio` gate and the persist. Returns false, writing nothing,
    /// for an unknown id, a MIDI clip, or a refused adoption.
    ///
    /// ⚠️ INAUDIBLE BY ITSELF. A region plays at rate 1.0 until the person turns warp ON for it
    /// (`StretchPlan.resolve` reads `warpEnabled` first), so adopting a tempo changes nothing
    /// the user hears. The session tempo is never touched.
    @discardableResult
    public func adoptDetectedNativeBPM(id: UUID, _ detected: DetectedTempo?) -> Bool {
        guard let i = slots.firstIndex(where: { $0?.id == id }),
              var clip = slots[i], clip.kind == .audio,
              let bpm = AudioTempoAnalysis.adoptableNativeBPM(current: clip.nativeBPM,
                                                               detected: detected)
        else { return false }
        clip.nativeBPM = bpm
        slots[i] = clip
        persist()
        return true
    }

    /// S1 — the AUTHORED writer of `Clip.nativeBPM`: the Workstation's ×2 / ÷2 and the
    /// hand-entered tempo. Unlike the detection writer above it OVERRIDES — that is its
    /// purpose. The warp lock is decided by its one caller, `AudioTempoCorrection.setNativeBPM`;
    /// the value is clamped by `AudioTempoCorrection.accepted` (the one range, #416). Returns
    /// false, writing nothing, for an unknown id, a MIDI clip, or a non-positive proposal; an
    /// unchanged value returns true without persisting.
    ///
    /// ⚠️ INAUDIBLE BY ITSELF, like the detection writer: a region plays at rate 1.0 until warp
    /// is on for it. No provenance flag is kept — a detection that finishes later is refused by
    /// never-clobber, so the authored value cannot be replaced behind the user's back.
    @discardableResult
    public func setAuthoredNativeBPM(id: UUID, _ proposed: Double) -> Bool {
        guard let i = slots.firstIndex(where: { $0?.id == id }),
              var clip = slots[i], clip.kind == .audio,
              let bpm = AudioTempoCorrection.accepted(proposed)
        else { return false }
        guard clip.nativeBPM != bpm else { return true }
        clip.nativeBPM = bpm
        slots[i] = clip
        persist()
        return true
    }

    /// B2b — the ONE writer that points an existing AUDIO clip at another file (a relink,
    /// `MediaRelink.relink`). It writes the file reference and the length measured from that
    /// file, and nothing else: the id every region points at, the name, the tempo and the
    /// automation stay. Returns false, writing nothing, for an unknown id, a non-audio clip, an
    /// empty reference or a length that is not a positive finite number. A nil length is taken
    /// only to RESTORE a clip that never learned its length (Undo of a relink,
    /// `TimelineStore.relinkClipSource`).
    ///
    /// ⚠️ `mediaAssetID` is written too, and it is REQUIRED (#431): a relink that moved the file
    /// but kept the link would leave the clip playing file B while naming the durable record of
    /// file A (MA4.2 review). The relink keeps the link only when it MOVED that record to the
    /// new file (MA4.5, `TimelineStore.relinkClipSource`); otherwise it writes nil, and Undo writes
    /// the old link back either way.
    @discardableResult
    public func relinkAudio(id: UUID, mediaRef: String, nativeDurationSeconds: Double?,
                            mediaAssetID: UUID?) -> Bool {
        if let seconds = nativeDurationSeconds {
            guard seconds.isFinite, seconds > 0 else { return false }
        }
        guard !mediaRef.isEmpty,
              let i = slots.firstIndex(where: { $0?.id == id }),
              var clip = slots[i], clip.kind == .audio
        else { return false }
        clip.mediaRef = mediaRef
        clip.nativeDurationSeconds = nativeDurationSeconds
        clip.mediaAssetID = mediaAssetID
        slots[i] = clip
        persist()
        return true
    }

    public func rename(at index: Int, to name: String) {
        guard slots.indices.contains(index), var clip = slots[index] else { return }
        clip.name = name
        slots[index] = clip
        persist()
    }

    /// Replace the whole grid with a restored one — the Session OPEN path (WA4-S1). Returns
    /// false and changes NOTHING unless the grid has exactly `slotCount` cells: the index IS
    /// the slot a region's clip lives in, so padding or truncating would silently re-seat
    /// clips. An OLDER, shorter grid is padded BEFORE it gets here, by the one migration
    /// (`migratedGrid`, read by `init` and `SessionSaveOpen`) — never inside this function.
    @discardableResult
    public func replaceSlots(_ replacement: [Clip?]) -> Bool {
        guard replacement.count == Self.slotCount else { return false }
        slots = replacement
        persist()
        return true
    }

    public func clear(at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = nil
        persist()
    }

    /// Restructure A1, step 3 — true while the LAST write of the clip grid did not reach the
    /// disk. The outcome used to be dropped, so a failed write looked saved until relaunch.
    /// Written only when the outcome changes (cold for its one reader, `WorkingCopyStatusView`);
    /// the next successful write clears it.
    public private(set) var gridNotWritten = false

    /// "Write again" — writes the current grid once more. Returns whether it reached the disk.
    @discardableResult
    public func retryWrite() -> Bool {
        persist()
        return !gridNotWritten
    }

    private func persist() {
        let written = store.save(Self.storedGrid(slots), name: Self.fileName)
        if gridNotWritten == written { gridNotWritten = !written }
    }
}
