// MIDIImport.swift
// Echoel — S2 (founder 2026-09-23, "all tasks"): a Standard MIDI File becomes ONE user-owned
// MIDI part on the Workstation's MIDI track, and plays through the region player that already
// runs. The `AudioImport` shape, one level simpler — there is no file copy:
//
//     picked file → bytes (≤ 2 MB) → MIDIFileImporter.channelNotes → Clip(kind: .midi,
//                 melody:) → ClipStore → TimelineRegion → TimelineStore
//
// ⭐ THE NOTES LIVE IN THE CLIP. A MIDI part has no `mediaRef` and no `MediaLibrary` copy —
// `Clip.melody` is the content, persisted with the clip grid. So nothing on disk can go missing
// behind the part, and the file the user picked is read once and released.
//
// ⭐ THE LANE IS THE ENGINE'S ROLL LANE, NOT A SECOND OPINION (#416). `TimelineRegionPlayer`
// plays exactly one MIDI lane through `PianoRollModel` — `TimelineDocument.rollLaneID`, the first
// non-bio MIDI lane. Landing anywhere else would place a part that plays only while the
// secondary-lane rack has capacity, which `canPlay` does not check. So the import lands where the
// engine certainly plays it, and `firstImportableMIDILane` IS `rollLaneID`.
// ⚠️ DMMW Phase 4 · slice 1: that holds for the FILE import. An EMPTY part ("New MIDI Part")
// lands on the SELECTED track when the engine certainly plays it there — the roll lane, or a
// rack-voiced MIDI lane (`emptyPartLane`, asking `MultiRollFanout.slot`, the player's rule) —
// and on the roll lane otherwise, saying so.
//
// ⭐ THE PART IS USER-OWNED (`composerOwned: false`, the `Clip.init` default, written out on
// purpose). `ClipStore.updateComposerMelody` refuses every clip that is not composer-owned, so
// the instrument's evolve can never rewrite the imported NOTES. What it CAN still do is SHADOW
// the part: `ensureComposerRegion` counts only composer regions, and a composer region appended
// over bar 0 wins every tick it covers (`TimelineScheduling.activeRegion`, the later region takes
// the tie). `userPartWouldBeShadowed` is the question the instrument now asks before it adds one.
//
// ⚠️ WHAT THE USER HEARS, AND ITS LIMITS — stated here and in the success note, never implied:
// · the part plays on the 16th-note grid at the SONG's tempo; the file's own tempo, time
//   signature, sustain pedal and program changes are not read;
// · a note longer than one bar is held for exactly one bar — the roll releases on
//   `endStep % 16`, so a longer note would otherwise be cut to its remainder;
// · channel 10 (General MIDI drums) is skipped — there is no drum voice any more (#166/#167);
// · the ONE shared piano roll plays it. With the instrument session RUNNING, its evolve reloads
//   that roll every 25–45 s, so the Workstation part is heard as intended with the instrument
//   STOPPED. That coupling predates this file (#1437); this file only makes it reachable with
//   the user's own notes, so the success note says so.
//
// ⚠️ THE ORDER OF THE TWO WRITES IS `AudioImport`'s AND FOR THE SAME REASON: clip first, region
// second — playback resolves `TimelineRegion.clipID` through `ClipStore`, so the failure mode of a
// half-written pair is a spare clip, never a region pointing at nothing.

import Foundation

/// The MIDI-file import transaction: bytes → user-owned MIDI clip + region on the roll lane.
public enum MIDIImport {

    // MARK: - Limits

    /// Largest file read, in bytes. A 512-bar arrangement is far below this; the cap exists so
    /// an arbitrary pick cannot pull an unbounded file onto the main actor.
    public static let maxFileBytes = 2 * 1024 * 1024
    /// Longest part, in bars. `RegionNoteWindow.barSlices` allocates one array per bar on every
    /// region load; ~300 bars is a ten-minute song.
    public static let maxBars = 512
    /// Most notes in one part. `ClipStore.persist()` re-encodes the whole grid on the main actor
    /// on every write, at roughly 180 B of JSON per note.
    public static let maxNotes = 8_192
    /// General MIDI channel 10, zero-based.
    public static let drumChannel = 9

    // MARK: - Value types

    /// Every way this can fail, each with its own sentence because each has a different repair.
    public enum Failure: Error, Equatable, Sendable {
        /// The system picker returned an error (cancelling is not a failure).
        case pickerFailed
        /// The file could not be read at all.
        case unreadableFile
        /// The file is larger than `maxFileBytes`.
        case fileTooLarge
        /// It read, but it is not a Standard MIDI File this parser accepts.
        case notAMIDIFile
        /// It parsed, and nothing on a melodic channel remains to play.
        case noMelodicNotes
        /// More than `maxBars` bars or `maxNotes` notes.
        case tooLong
        /// The song has no MIDI track. Never created behind the user's back — `addMIDITrack`
        /// is a separate, deliberate tap on the door paired with Import MIDI.
        case noMIDILane
        /// All eight `ClipStore` slots are taken. Fail, never overwrite.
        case clipGridFull

        /// The sentence the Workstation shows. Numbers are written through this type's own
        /// constants; the slot count is the literal "8", as in `AudioImport`, because
        /// `ClipStore.slotCount` is main-actor-isolated and this property is not.
        public var userMessage: String {
            switch self {
            case .pickerFailed:   return "Couldn't open that file."
            case .unreadableFile: return "Couldn't read that file."
            case .fileTooLarge:   return "That file is too large — a MIDI file can be up to 2 MB."
            case .notAMIDIFile:   return "That file isn't a standard MIDI file this app can read."
            case .noMelodicNotes: return "That MIDI file has no notes to play — drum channel 10 is skipped."
            case .tooLong:        return "That MIDI file is too long — a part holds up to \(MIDIImport.maxBars) bars and \(MIDIImport.maxNotes) notes."
            case .noMIDILane:     return "This piece has no MIDI track — add a MIDI track first."
            case .clipGridFull:   return "The part slots are full — all 8 are in use."
            }
        }
    }

    /// What a successful import produced — returned so the door can say what happened and a
    /// guard can assert on it without re-reading the stores.
    public struct Landing: Sendable, Equatable {
        public var clip: Clip
        public var region: TimelineRegion
        public var slotIndex: Int
        public var laneID: UUID
        /// Notes on channel 10 that were left out.
        public var skippedDrumNotes: Int
        /// Notes longer than a bar that now last exactly one bar.
        public var heldForOneBar: Int

        public init(clip: Clip, region: TimelineRegion, slotIndex: Int, laneID: UUID,
                    skippedDrumNotes: Int, heldForOneBar: Int) {
            self.clip = clip
            self.region = region
            self.slotIndex = slotIndex
            self.laneID = laneID
            self.skippedDrumNotes = skippedDrumNotes
            self.heldForOneBar = heldForOneBar
        }
    }

    // MARK: - Pure decisions

    /// The lane an import lands on: the engine's roll lane, or nil.
    public static func firstImportableMIDILane(in document: TimelineDocument) -> TimelineLane? {
        guard let id = document.rollLaneID else { return nil }
        return document.lanes.first { $0.id == id }
    }

    /// Create a MIDI track through the ONE owner — the `AudioImport.addAudioTrack` seam, for the
    /// same reason (`TheWorkstationHasADoorTests` claim F: the view sends the store nothing but
    /// `document`). It APPENDS; it does not "ensure".
    @MainActor
    public static func addMIDITrack(timeline: TimelineStore) {
        timeline.addLane(kind: .midi)
    }

    /// The sentence after "Add MIDI Track" (DMMW Phase 2 · slice 2): which track was made and
    /// where it is, since the tap selects it and opens its details in the track list.
    /// ⚠️ It promises NOTHING about where the next part goes: "New MIDI Part" lands on this track
    /// only when a voice plays it here (`emptyPartLane`), otherwise on the roll lane.
    public static func addedTrackNote(laneName: String) -> String {
        String(localized: "Added ") + laneName + String(localized: ". It is selected in the track list.")
    }

    // MARK: - The empty part (Phase 3 / M1b — "New MIDI Part")

    /// Bars in a part made by "New MIDI Part": four, the length most MIDI hosts give a new
    /// pattern. The grid scrolls, so this is a starting length, not a ceiling.
    public static let emptyPartBars = 4

    /// An EMPTY part for the user's own notes — the import's decision without a file: the lane
    /// `emptyPartLane` picks (the roll lane unless a voiced track is selected), the same refusals, the same
    /// ownership (`composerOwned: false`, so evolve never rewrites what the user writes into it).
    ///
    /// ⭐ WHY IT EXISTS: until this row the note editor (`PartNoteEditor`) could only open a part
    /// that a MIDI FILE had made, so on a fresh install it had nothing to edit.
    ///
    /// ⭐ AN ORPHANED EMPTY USER CLIP IS REUSED, for the reason `ensureComposerRegion` reuses its
    /// own: nothing clears a slot, and an Undo removes the region but leaves the clip, so every
    /// New → Undo would otherwise spend one of the eight slots for good. Only a user-owned MIDI
    /// clip that NO region plays and that carries NOTHING qualifies — `Clip.isEmpty` (no notes,
    /// no drum steps) and no automation: an older build's drum pattern or bio-take automation
    /// would otherwise ride along into a part the editor shows as empty (M1b review). A reused
    /// clip is rebuilt from scratch and keeps only its id and colour. The Redo that could bring
    /// its old part back is cleared by the new part's own undo step (`TimelineStore.pushUndo`).
    /// ⚠️ The rename is not in the undo history (clip slots sit outside it): an Undo that brings
    /// the clip's OLD part back shows it under the new name. Cosmetic, and recorded here.
    ///
    /// ⚠️ IT STARTS ON A BAR: after the lane's last part, rounded up to the next barline, so the
    /// grid's first column is a downbeat even when a trimmed part ends mid-bar.
    ///
    /// ⭐ DMMW Phase 4 · slice 1 (founder 2026-09-29, "Instrument/Spur → Part"): it lands on the
    /// SELECTED track when the engine certainly plays a part there (`emptyPartLane`), not
    /// always on the roll lane — "Add MIDI Track" then "New MIDI Part" writes onto the track
    /// the player just made. `selectedTrack` and `voiceCapacity` are required (#431).
    public static func planEmptyPart(document: TimelineDocument,
                                     slots: [Clip?],
                                     selectedTrack: UUID?,
                                     voiceCapacity: Int) -> Result<Landing, Failure> {
        guard let lane = emptyPartLane(in: document, selectedTrack: selectedTrack,
                                       voiceCapacity: voiceCapacity) else { return .failure(.noMIDILane) }
        let name = "MIDI · \(lane.name)"
        let played = Set(document.regions.map(\.clipID))
        let clip: Clip
        let slot: Int
        if let reuse = slots.firstIndex(where: { candidate in
               guard let c = candidate else { return false }
               return c.kind == .midi && !c.composerOwned && c.isEmpty && c.automation.isEmpty
                   && !played.contains(c.id)
           }),
           let old = slots[reuse] {
            clip = Clip(id: old.id, name: name, colorIndex: old.colorIndex, kind: .midi,
                        melody: MelodyClip(notes: []), composerOwned: false)
            slot = reuse
        } else if let free = slots.firstIndex(where: { $0 == nil }) {
            clip = Clip(name: name, colorIndex: free, kind: .midi,
                        melody: MelodyClip(notes: []), composerOwned: false)
            slot = free
        } else {
            return .failure(.clipGridFull)
        }
        let bar = TimelineTime.ticksPerBar
        let end = document.nextStartTick(inLane: lane.id)
        let start = ((Swift.max(0, end) + bar - 1) / bar) * bar
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id,
                                    startTick: start, lengthTicks: emptyPartBars * bar)
        return .success(Landing(clip: clip, region: region, slotIndex: slot, laneID: lane.id,
                                skippedDrumNotes: 0, heldForOneBar: 0))
    }

    /// The "New MIDI Part" row's spoken hint — the SAME rule `emptyPartLane` implements, in
    /// one place beside it (#416), so the words cannot name a lane rule the code does not follow.
    public static let newPartHint: String = String(localized: "Adds an empty ") + "\(emptyPartBars)"
        + String(localized: "-bar part to the selected MIDI track when it has a voice, otherwise to the first MIDI track, and selects it")

    /// The lane a NEW empty part lands on: the selected track when a part there is certainly
    /// played — the roll lane, or a non-bio MIDI lane holding a rack voice (`MultiRollFanout
    /// .slot`, the player's own rule, #416; `canPlay` does not check rack capacity, so a part
    /// on a voiceless lane would start a clock over silence) — otherwise the roll lane.
    /// `voiceCapacity` is `TimelineRegionPlayer.laneVoiceCapacity`.
    public static func emptyPartLane(in document: TimelineDocument, selectedTrack: UUID?,
                                     voiceCapacity: Int) -> TimelineLane? {
        if let id = selectedTrack,
           let lane = document.lanes.first(where: { $0.id == id }),
           lane.kind == .midi, !lane.isBio,
           id == document.rollLaneID
            || MultiRollFanout.slot(forLaneID: id, in: document, rollLane: document.rollLaneID,
                                    capacity: voiceCapacity) != nil {
            return lane
        }
        return firstImportableMIDILane(in: document)
    }

    /// The sentence after "New MIDI Part": where it landed, how to write into it, and what it
    /// does NOT do yet. `notOnSelected` names the selected track when the part could NOT land
    /// there (no voice plays it), so the move to another track is said, never discovered. An empty part plays nothing (`canPlay` refuses a song of empty parts), and
    /// a user part at the song's start makes the instrument's Generate yield
    /// (`userPartWouldBeShadowed` counts it, empty or not) — both said, neither left for the ear.
    public static func emptyPartNote(laneName: String, atSongStart: Bool,
                                     notOnSelected: String?) -> String {
        // E4-56: seams of catalog keys (≤ 4 operands per step); the counts and names are never literals.
        let landed: String = String(localized: "Added an empty ") + "\(emptyPartBars)" + String(localized: "-bar part on ") + laneName
        var note: String = landed + String(localized: ". Its notes are open under the arrangement")
            + String(localized: " — once it has notes, it plays at the piece's tempo, with the instrument stopped.")
        if let selected = notOnSelected {
            let moved: String = " " + selected + String(localized: " cannot play a MIDI part, so it went on ")
            note += moved + laneName + "."
        }
        if atSongStart { note += String(localized: " Generate won't place its music over this part.") }
        return note
    }

    /// Plan, then write — clip FIRST, region SECOND, `commit`'s order and reason. ONE undo step
    /// (the region add); nothing is written on a refusal.
    @MainActor
    @discardableResult
    public static func addEmptyPart(clipStore: ClipStore,
                                    timeline: TimelineStore,
                                    selectedTrack: UUID?,
                                    voiceCapacity: Int) -> Result<Landing, Failure> {
        switch planEmptyPart(document: timeline.document, slots: clipStore.slots,
                             selectedTrack: selectedTrack, voiceCapacity: voiceCapacity) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let landing):
            clipStore.setClip(at: landing.slotIndex, landing.clip)  // FIRST
            timeline.addRegion(landing.region)                      // SECOND
            return .success(landing)
        }
    }

    /// True when a NEW composer region over `[0, windowTicks)` on this lane would shadow a user
    /// part — i.e. a region starts inside that window and its clip EXISTS and is not
    /// composer-owned. A region whose clip is missing is inaudible, so it has nothing to shadow
    /// and does not count (counting it would suppress the composer forever for no one).
    public static func userPartWouldBeShadowed(onLane laneID: UUID, in document: TimelineDocument,
                                               clips: [Clip], windowTicks: Int) -> Bool {
        let userClipIDs = Set(clips.filter { !$0.composerOwned }.map(\.id))
        return document.regions(in: laneID).contains {
            $0.startTick < windowTicks && userClipIDs.contains($0.clipID)
        }
    }

    /// Everything the import decides, as a pure function of values. The file answers first
    /// (the repair the user can make with the file in hand), then the lane, then the slot —
    /// `AudioImport.plan`'s order.
    public static func plan(name: String, bytes: [UInt8]?, document: TimelineDocument,
                            freeSlotIndex: Int?) -> Result<Landing, Failure> {
        guard let bytes else { return .failure(.unreadableFile) }
        guard bytes.count <= maxFileBytes else { return .failure(.fileTooLarge) }
        let parsed: [(channel: Int, note: Note)]
        do {
            parsed = try MIDIFileImporter.channelNotes(from: bytes)
        } catch {
            return .failure(.notAMIDIFile)
        }

        var drums = 0
        var held = 0
        var notes: [Note] = []
        notes.reserveCapacity(parsed.count)
        for pair in parsed {
            if pair.channel == drumChannel { drums += 1; continue }
            var note = pair.note
            if note.lengthTicks > TimelineTime.ticksPerBar {
                note.lengthTicks = TimelineTime.ticksPerBar
                held += 1
            }
            notes.append(note)
        }
        notes.sort { ($0.startTick, $0.pitch) < ($1.startTick, $1.pitch) }
        guard let lastEnd = notes.map(\.endTick).max() else { return .failure(.noMelodicNotes) }

        let bars = Swift.max(1, (lastEnd + TimelineTime.ticksPerBar - 1) / TimelineTime.ticksPerBar)
        guard notes.count <= maxNotes, bars <= maxBars else { return .failure(.tooLong) }
        guard let lane = firstImportableMIDILane(in: document) else { return .failure(.noMIDILane) }
        guard let slot = freeSlotIndex else { return .failure(.clipGridFull) }

        let clip = Clip(name: name, colorIndex: slot, kind: .midi,
                        melody: MelodyClip(notes: notes), composerOwned: false)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id,
                                    startTick: document.nextStartTick(inLane: lane.id),
                                    lengthTicks: bars * TimelineTime.ticksPerBar)
        return .success(Landing(clip: clip, region: region, slotIndex: slot, laneID: lane.id,
                                skippedDrumNotes: drums, heldForOneBar: held))
    }

    /// The sentence shown after a successful import: what landed, where, and the limits the
    /// user will hear — none of them is left for the ear to discover.
    public static func successNote(_ landing: Landing, laneName: String) -> String {
        let bars = Swift.max(1, landing.region.lengthTicks / TimelineTime.ticksPerBar)
        let count = landing.clip.melody?.notes.count ?? 0
        let barWord: String = bars == 1 ? String(localized: "bar") : String(localized: "bars")
        let noteWord: String = count == 1 ? String(localized: "note") : String(localized: "notes")
        let head: String = String(localized: "Imported “") + landing.clip.name + String(localized: "” — ")
        let span: String = "\(bars) " + barWord + ", " + "\(count) "
        let landed: String = noteWord + String(localized: " on ") + laneName + "."
        var note: String = head + span + landed
        note += String(localized: " Plays at the piece's tempo on the 16th-note grid, with the instrument stopped.")
        if landing.heldForOneBar > 0 { note += String(localized: " Notes longer than a bar are held for one bar.") }
        if landing.skippedDrumNotes > 0 { note += " " + "\(landing.skippedDrumNotes)" + String(localized: " drum notes skipped.") }
        return note
    }

    // MARK: - The transaction

    /// Plan, then write — clip FIRST, region SECOND (see the header). Nothing is written on a
    /// refusal.
    @MainActor
    @discardableResult
    public static func commit(name: String, bytes: [UInt8]?, clipStore: ClipStore,
                              timeline: TimelineStore) -> Result<Landing, Failure> {
        let decided = plan(name: name, bytes: bytes, document: timeline.document,
                           freeSlotIndex: clipStore.firstEmptySlotIndex)
        switch decided {
        case .failure(let failure):
            return .failure(failure)
        case .success(let landing):
            clipStore.setClip(at: landing.slotIndex, landing.clip)  // FIRST — playback
                                                                    // resolves clipID here
            timeline.addRegion(landing.region)                      // SECOND — the pointer
            return .success(landing)
        }
    }

    /// The production entry point: hold security-scoped access, read at most `maxFileBytes`
    /// (the size is checked on what was READ, so an unknown file size cannot skip the cap), then
    /// commit.
    @MainActor
    @discardableResult
    public static func perform(pickedURL: URL, clipStore: ClipStore,
                               timeline: TimelineStore) -> Result<Landing, Failure> {
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }
        if let size = try? pickedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > maxFileBytes {
            return .failure(.fileTooLarge)                          // refuse before reading
        }
        let bytes = (try? Data(contentsOf: pickedURL)).map { [UInt8]($0) }
        return commit(name: pickedURL.deletingPathExtension().lastPathComponent,
                      bytes: bytes, clipStore: clipStore, timeline: timeline)
    }
}
