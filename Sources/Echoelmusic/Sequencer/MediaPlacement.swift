// MediaPlacement.swift
// Echoel — put a file that is ALREADY in the media library onto the song (Phase 3 / MA1, plan:
// `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`). Two doors, one decision: the library browser's
// "Place" (`perform`), and since MA2 Import Audio itself — a picked file whose BYTES are already
// in the library lands here through `AudioImport.landExisting` instead of being copied again.
//
//     asset (MediaLibrary.listAudio) → a clip already carries it?
//         yes → TimelineRegion on THAT clip → TimelineStore          (no copy, no slot)
//         no  → AudioImport.commit on the file where it already is  (a clip, no copy)
//
// ⭐ WHY REUSE IS THE POINT. Before this, the only way to use an imported file a second time was
// to pick it from Files again, which copied it again and spent a second of the eight `ClipStore`
// slots on the same sound. A region may share a clip (`TimelineRegion.duplicated()` has always
// done so), so a second part of the same file costs nothing but the region.
//
// ⭐ THE LANE AND THE ORDER ARE THE IMPORT'S (#416). The part lands where Import Audio would put
// it — `AudioImport.firstImportableAudioLane`, the engine's own `!isBio` predicate — at the end
// of that lane's content, spanning whole bars at the song tempo. Two doors that placed the same
// file in two different places would be two opinions about where a file goes.
//
// ⚠️ BUT A REUSED CLIP CAN CARRY A TEMPO THE IMPORT NEVER HAD, and then the TRACK decides warp
// (review of ae3faa1c5). Warp is a per-track switch (`AudioWarp.setWarp` over the eligible
// parts): on a track that reads `.on`, a new unwarped part of a 90 BPM loop would play at 90
// beside its warped sibling at 120 and flip the switch to "Mixed" behind the person's back. So
// a reuse on a `.on` track lands WARPED, spanning `AudioWarp.spanTicks(…warped: true…)` — the
// span the switch itself would give it. `.off`, `.mixed` and `.unavailable` place it unwarped,
// exactly as the import does; "Mixed" is the person's to resolve with one tap.
//
// ⛔ THE BROWSER NEVER DELETES A FILE, and the orphan path is where that could go wrong. It runs
// the import transaction with `importFile` = the file itself and `deleteManagedCopy` = nothing,
// because `AudioImport.commit` deletes "the copy it just made" on every failure — and here there
// is no copy: the URL IS the user's asset. Passing the production delete would erase a library
// file whenever a placement is refused (no audio track, a full grid). The guard drives this.
//
// ⚠️ WHAT AN ORPHAN PLACEMENT DOES NOT DO: tempo analysis. Import Audio runs `AudioTempoAnalysis`
// after the landing, off the main actor, and adopts a KNOWN tempo into the clip. A clip made here
// starts with `nativeBPM = 0` — unwarped, and the part's tempo row says "not set" and can be set
// by hand (S1). A reused clip keeps whatever tempo it already has.

import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Placing a library asset as a part on the song's audio track.
public enum MediaPlacement {

    /// What the pure plan decided.
    public enum Decision: Equatable, Sendable {
        /// A clip already carries the asset: this region plays it. No slot, no copy.
        case reuse(TimelineRegion)
        /// No clip carries it (for example after Open replaced the clip grid): the placement
        /// needs a new clip, made by the import transaction on the file where it is.
        case newClip
        case failure(AudioImport.Failure)
    }

    /// What a successful placement produced, so the browser can select it and say what happened.
    public struct Placed: Equatable, Sendable {
        public var region: TimelineRegion
        /// The clip the part plays, and the slot it sits in — what Import's `Landing` reports,
        /// so the import's de-dup branch (MA2) can report the same shape without a lookup.
        public var clip: Clip
        public var slotIndex: Int
        /// True when an existing clip was reused — no slot spent.
        public var reusedClip: Bool

        public var clipName: String { clip.name }

        public init(region: TimelineRegion, clip: Clip, slotIndex: Int, reusedClip: Bool) {
            self.region = region
            self.clip = clip
            self.slotIndex = slotIndex
            self.reusedClip = reusedClip
        }
    }

    // MARK: - Pure decisions

    /// The first AUDIO clip, in slot order, that carries this asset — the one a new part reuses.
    public static func carryingClip(_ key: MediaAsset.Key, in clips: [Clip]) -> Clip? {
        clips.first { $0.kind == .audio && MediaAsset.key(forRef: $0.mediaRef) == key }
    }

    /// Everything a placement decides, as a pure function of values.
    ///
    /// `measuredSeconds` is asked only when the reused clip does not know its own length (a clip
    /// written before `nativeDurationSeconds` existed): nil there means the file could not be
    /// read, a non-positive or non-finite value that it has no playable length. The lane is
    /// checked FIRST — "add an audio track first" is the refusal the person can act on without
    /// knowing anything about clips.
    public static func plan(_ key: MediaAsset.Key,
                            clips: [Clip],
                            document: TimelineDocument,
                            bpm: Double,
                            measuredSeconds: Double?) -> Decision {
        guard let lane = AudioImport.firstImportableAudioLane(in: document) else {
            return .failure(.noAudioLane)
        }
        guard let clip = carryingClip(key, in: clips) else { return .newClip }

        let known = clip.nativeDurationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let seconds: Double
        if let known {
            seconds = known
        } else {
            guard let measuredSeconds else { return .failure(.unreadableAudio) }
            guard measuredSeconds.isFinite, measuredSeconds > 0 else {
                return .failure(.invalidDuration)
            }
            seconds = measuredSeconds
        }

        var region = AudioClipFactory.unwarpedRegion(
            forDurationSeconds: seconds,
            bpm: bpm,
            laneID: lane.id,
            clipID: clip.id,
            startTick: document.nextStartTick(inLane: lane.id))
        if clip.nativeBPM.isFinite, clip.nativeBPM > 0,
           AudioWarp.state(laneID: lane.id, in: document, clips: clips) == .on {
            region.lengthTicks = AudioWarp.spanTicks(for: region, clip: clip, warped: true, bpm: bpm)
            region.warpEnabled = true
        }
        return .reuse(region)
    }

    /// The sentence the browser shows after a placement.
    public static func successNote(_ placed: Placed, laneName: String) -> String {
        let bars = max(1, placed.region.lengthTicks / TimelineTime.ticksPerBar)
        let span = "\(bars) \(bars == 1 ? "bar" : "bars")"
        return placed.reusedClip
            ? "Placed “\(placed.clipName)” — \(span) on \(laneName), playing the clip it already has."
            : "Placed “\(placed.clipName)” — \(span) on \(laneName), as a new clip."
    }

    // MARK: - The one writer

    /// Place `asset`, through the two stores that already own clips and parts. `measure` is
    /// injected so the whole path — including the no-delete promise — is drivable without a
    /// decoder; production passes `AudioImport.measureWithAVFoundation` (see `perform`).
    ///
    /// Reuse is ONE `TimelineStore.addRegion`, so ONE Undo takes the part away and leaves the
    /// clip (which other parts may play) alone. A new clip goes through `AudioImport.commit`,
    /// clip first and region second, for the reason that file's header gives.
    @MainActor
    public static func place(_ asset: MediaAsset,
                             clipStore: ClipStore,
                             timeline: TimelineStore,
                             bpm: Double,
                             measure: (URL) -> AudioImport.Measurement?) -> Result<Placed, AudioImport.Failure> {
        let clips = clipStore.slots.compactMap { $0 }
        // Measure only when the plan will reach the length question: a clip that does not know
        // its length, on a song that HAS an audio track — opening a file for a refusal the lane
        // check gives anyway is main-actor I/O for nothing.
        let hasLane = AudioImport.firstImportableAudioLane(in: timeline.document) != nil
        let needsMeasure = hasLane && (carryingClip(asset.key, in: clips).map { clip in
            !(clip.nativeDurationSeconds.map { $0.isFinite && $0 > 0 } ?? false)
        } ?? false)
        let measured = needsMeasure ? measure(asset.url)?.durationSeconds : nil

        switch plan(asset.key, clips: clips, document: timeline.document, bpm: bpm,
                    measuredSeconds: measured) {
        case .failure(let failure):
            return .failure(failure)
        case .reuse(let region):
            // The slot is found BEFORE the write, so a region is never added for a clip this
            // function then cannot report. `plan` took the clip from these slots, so the
            // refusal below is unreachable today; it is a refusal, not a trap.
            guard let slot = clipStore.slots.firstIndex(where: { $0?.id == region.clipID }),
                  let clip = clipStore.slots[slot] else {
                return .failure(.unreadableAudio)
            }
            timeline.addRegion(region)
            return .success(Placed(region: region, clip: clip, slotIndex: slot, reusedClip: true))
        case .newClip:
            let result = AudioImport.commit(pickedURL: asset.url,
                                            clipStore: clipStore,
                                            timeline: timeline,
                                            bpm: bpm,
                                            importFile: { $0 },
                                            measure: measure,
                                            deleteManagedCopy: { _ in },
                                            // MA4.3: a library file may already have a record;
                                            // linking it (reuse, else adopt) is its own slice.
                                            assets: nil)
            return result.map {
                Placed(region: $0.region, clip: $0.clip, slotIndex: $0.slotIndex, reusedClip: false)
            }
        }
    }

    #if canImport(AVFoundation)

    /// The production entry point — the browser's "Place".
    ///
    /// ⚠️ THE FILE MUST STILL BE THERE. The list is a snapshot; a reuse with a known length
    /// never opens the file, so without this one stat a vanished file would be "placed" as a
    /// silent part and reported as a success. It is checked HERE, not in `place`, so the
    /// blocking bundle can drive `place` on paths that exist only as strings.
    @MainActor
    public static func perform(_ asset: MediaAsset,
                               clipStore: ClipStore,
                               timeline: TimelineStore,
                               bpm: Double) -> Result<Placed, AudioImport.Failure> {
        guard FileManager.default.fileExists(atPath: asset.url.path) else {
            return .failure(.unreadableAudio)
        }
        return place(asset, clipStore: clipStore, timeline: timeline, bpm: bpm,
                     measure: AudioImport.measureWithAVFoundation)
    }

    #endif
}
