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
        /// is a separate, deliberate tap, one row above Import MIDI.
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
            case .noMIDILane:     return "This project has no MIDI track — add a MIDI track first."
            case .clipGridFull:   return "The clip grid is full — all 8 slots are in use."
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
        let barWord: String = bars == 1 ? "bar" : "bars"
        let noteWord: String = count == 1 ? "note" : "notes"
        var note = "Imported “\(landing.clip.name)” — \(bars) \(barWord), \(count) \(noteWord) on \(laneName)."
        note += " Plays at the song tempo on the 16th-note grid, with the instrument stopped."
        if landing.heldForOneBar > 0 { note += " Notes longer than a bar are held for one bar." }
        if landing.skippedDrumNotes > 0 { note += " \(landing.skippedDrumNotes) drum notes skipped." }
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
