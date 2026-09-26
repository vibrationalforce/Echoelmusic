// AudioImport.swift
// Echoel — Audio Import V1 (founder 2026-09-22): the FIRST reachable producer of an
// audio-bearing region. A user picks a file, it becomes an app-owned copy, and that copy
// lands on the audio lane the song already has, through the clip and timeline stores that
// already persist and the playback chain that already runs.
//
//     picked file → MediaLibrary.importAudio → validate the MANAGED COPY
//                 → Clip(kind: .audio) → ClipStore → TimelineRegion → TimelineStore
//
// ⭐ WHAT THIS CLOSES, and it is a four-month-old, deliberately-recorded gap. `AudioLanePlayer`
// has been constructed by `EchoelmusicApp` and driven by `TimelineRegionPlayer` on every
// prime/step/stop since v191, `TimelineAudioSink` is injected into it, and `#1438` corrected
// `ClipKind.timelineEngineKinds` to `[.midi, .audio]` because the ENGINE was shipped. What was
// missing was never the engine — it was a PRODUCER. `AudioClipFactory` is the only thing that
// mints an audio-bearing clip, and its one caller was `TakeRecorder`, reached only from
// `RecordController.arm()`, which has zero callers (#204/#527). This file is the second caller,
// and unlike that chain it has a door.
//
// ⭐ THE SPLIT IS THE POINT: ONE impure step, everything else pure. `MediaLibrary`'s own header
// states the law this file follows — copying the picked file in is the single side effect; the
// placement math (`AudioClipFactory` + `TimelineDocument.nextStartTick`) stays pure and tested.
// So the transaction is written twice over: `commit(…)` takes the file copy, the measurement and
// the delete as INJECTED closures (the `AudioLanePlayer` `makeSink:`/`resolveURL:` idiom) and is
// Foundation-only, and `perform(…)` is the five-line AVFoundation adapter that supplies the real
// three. Every failure path, including the cleanup, is therefore driven by the blocking bundle
// without a device, a file picker or an audio file.
//
// ⛔ WHAT THIS SLICE IS NOT, stated here because each one is a thing a reader will look for.
// `Clip.id` remains the creative identity and `mediaRef` the file-location bridge. (⛔ "There is
// no `MediaAsset`" stood here; since MA1 `Core/MediaAsset` exists and READS that bridge — the
// same file is one asset wherever referenced — and `MediaPlacement` is a second caller of
// `commit`, with an identity copy and a no-op delete. Since MA2 `perform` asks the library first:
// a picked file whose BYTES are already there lands through `landExisting` — no second copy.
// ⛔ "There is no new store, no new persistence root" stood here; since MA4.2 a successful
// landing registers a `MediaAssetRecord` in `MediaAssetStore` — an app-library root of its own —
// and links the clip to it. That is a THIRD write, described below.) There is no new clock and
// no new playback engine. There is no audio INPUT, no recording, no sample instrument and no grain engine. There
// is no BPM estimate IN THE TRANSACTION (the landing carries `nativeBPM = 0`; since #B2 the
// Workstation door runs `AudioTempoAnalysis` AFTER the landing, off the main actor, and a
// KNOWN tempo is adopted through `ClipStore` — founder 2026-09-23 lifted decision 7), no
// AUTOMATIC lane creation (decision 4 — `addAudioTrack` was added 2026-09-23 and IS a lane
// creator, but nothing on the import path calls it; only a deliberate tap does), and no
// relink UI: a media file that later disappears leaves the clip and the region alone and
// blocks only its own playback (decision 5).
//
// ⚠️ THE ORDER OF THE TWO WRITES IS LOAD-BEARING AND THE PAIR IS NOT ATOMIC. `ClipStore` first,
// `TimelineStore` second, because playback resolves `TimelineRegion.clipID` THROUGH `ClipStore`
// (`AudioLanePlayer`'s injected `resolveURL` is `clipStore.clip(id:)` → `MediaLibrary.resolveRef`).
// A region persisted before its clip is a dangling pointer for as long as the gap lasts; a clip
// persisted before its region is an unreferenced slot, which is the harmless direction. Neither
// store exposes a transaction and both `persist()` fire-and-forget, so if the second write's disk
// write fails there is no rollback — the honest statement is that this is a two-write sequence
// ordered so the failure mode is a spare clip, NOT a cross-store transaction system.
// ⚠️ Since MA4.2 a THIRD write precedes both: the durable record (`MediaAssetStore.register`).
// A record persisted before its clip is an unreferenced record — the harmless direction again —
// and the clip carries its id only when the register succeeded, so a clip never names a record
// that was not written.
//
// ⚠️ THE LANE PREDICATE IS THE ENGINE'S OWN, NOT A SECOND OPINION (#416). Founder decision 4
// says "the first existing TimelineLane whose kind is .audio"; `TimelineDocument.audioLaneIDs` —
// what `AudioLanePlayer.prime`/`apply` actually walk — says `kind == .audio && !isBio`. Placing on
// a `.audio` lane marked `isBio` would persist a region the transport refuses to look at: a
// control that lies. The `!isBio` half is therefore not an addition to the decision, it is what
// makes the decision true.

import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// The audio-file import transaction: managed copy → validated measurement → clip + region.
public enum AudioImport {

    // MARK: - Value types

    /// What a decoder reports about the MANAGED COPY. `durationSeconds` is COMPUTED rather
    /// than stored so the duration and the frames/rate it comes from can never disagree
    /// (#416) — a stored third number is a number that can rot against its own inputs.
    public struct Measurement: Sendable, Equatable {
        public var sampleRate: Double
        public var frameCount: Int64
        public var channelCount: Int

        public init(sampleRate: Double, frameCount: Int64, channelCount: Int) {
            self.sampleRate = sampleRate
            self.frameCount = frameCount
            self.channelCount = channelCount
        }

        /// Media length in seconds. 0 for any input `validate` would reject, so a caller that
        /// skipped validation still gets a neutral number rather than a NaN or a trap.
        public var durationSeconds: Double {
            guard sampleRate.isFinite, sampleRate > 0, frameCount > 0 else { return 0 }
            return Double(frameCount) / sampleRate
        }
    }

    /// Every way this can fail, each distinct because each has a different repair for the
    /// person holding the phone. No silent failure: `commit` returns one of these or a landing.
    public enum Failure: Error, Equatable, Sendable {
        /// The system picker returned an error (not a cancellation — cancelling is not a failure).
        case pickerFailed
        /// `MediaLibrary.importAudio` could not produce a managed copy (no container / disk).
        case copyFailed
        /// The managed copy would not open as audio at all.
        case unreadableAudio
        /// It opened, but its sample rate or channel count is not something to schedule.
        case invalidFormat
        /// It opened with a sane format and carries no playable length.
        case invalidDuration
        /// The song has no audio track to place it on. Founder decision 4: fail, never create
        /// one behind the user's back — `addAudioTrack` is a separate, deliberate tap.
        ///
        /// ⭐ THE SENTENCE INSTRUCTS AGAIN, AND ONLY BECAUSE THE INSTRUCTION CAN NOW BE OBEYED
        /// (founder 2026-09-23). ⛔ It was demoted to a bare report on 2026-09-22 for a reason
        /// that was measured and true at the time: `TimelineStore.init()` with no stored
        /// document builds `TimelineDocument()` — `lanes: []` — the one seed
        /// (`TimelineStore.migrate`) was reachable only through `bootstrapIfNeeded`, whose
        /// single caller (`ArrangeTimelineView`) went with #121 Slice 4, and `addLane` /
        /// `addInstrumentTrack` had zero production callers. So on a fresh install this was
        /// the only outcome the build could reach and no control could resolve it. That is
        /// what the founder unblocked: `AudioImport.addAudioTrack` now has a door in
        /// `WorkstationView`, one row above Import.
        ///
        /// ⚠️ THE TWO HALVES MUST MOVE TOGETHER, AND A GUARD MAKES THEM. Claim 18 of
        /// `TheWorkstationImportsAudioTests` is a BICONDITIONAL between this wording and
        /// whether any lane creator has a production caller — it goes red both ways, so
        /// deleting the door without demoting this sentence is caught, as is the reverse.
        case noAudioLane
        /// All eight `ClipStore` slots are taken. Founder decision 8: fail, never overwrite.
        case clipGridFull

        /// The sentence the Workstation shows. One home for the wording so the surface cannot
        /// drift from the failure it is describing, and so a guard can drive it.
        public var userMessage: String {
            switch self {
            case .pickerFailed:    return "Couldn't open that file."
            case .copyFailed:      return "Couldn't copy that file into the app."
            case .unreadableAudio: return "That file isn't audio this app can read."
            case .invalidFormat:   return "That audio has no usable sample rate or channels."
            case .invalidDuration: return "That audio has no playable length."
            case .noAudioLane:     return "This project has no audio track — add an audio track first."
            case .clipGridFull:    return "The clip grid is full — all 8 slots are in use."
            }
        }
    }

    /// What a successful import produced. Returned rather than only persisted so the caller can
    /// say what happened, and so the blocking bundle can assert on it without re-reading stores.
    public struct Landing: Sendable, Equatable {
        public var clip: Clip
        public var region: TimelineRegion
        public var slotIndex: Int
        public var laneID: UUID

        /// The MANAGED COPY this import created, as a URL.
        ///
        /// ⭐ IT IS REPORTED HERE BECAUSE THE TRANSACTION IS THE ONLY THING THAT KNOWS IT,
        /// and a caller that wants to READ what was just imported must not go looking for it
        /// again. `clip.mediaRef` carries the same location as a string, so the obvious
        /// alternative is `MediaLibrary.resolveRef(landing.clip.mediaRef)` at the call site —
        /// and that is worse in two ways that only show up when measured: `resolveRef`
        /// performs up to five `FileManager.fileExists` probes, which on the import path runs
        /// them on the MAIN ACTOR; and it re-derives a fact this function already had in
        /// hand, so a caller could disagree with the transaction about which file was
        /// written. `TheWorkstationImportsAudioTests` forbids the door from naming
        /// `MediaLibrary.` for exactly that reason, and this field is why it does not need to.
        public var managedURL: URL

        /// True when the picked file's bytes were ALREADY in the library (MA2): no copy was
        /// made, and `managedURL` is that existing file. Required, never defaulted — a
        /// defaulted flag that no call site writes appears in no diff (#431).
        public var reusedLibraryFile: Bool

        public init(clip: Clip, region: TimelineRegion, slotIndex: Int, laneID: UUID,
                    managedURL: URL, reusedLibraryFile: Bool) {
            self.clip = clip
            self.region = region
            self.slotIndex = slotIndex
            self.laneID = laneID
            self.managedURL = managedURL
            self.reusedLibraryFile = reusedLibraryFile
        }
    }

    // MARK: - Pure decisions

    /// The first lane this import may land on, or nil. The predicate is `audioLaneIDs`' own —
    /// see the header for why `!isBio` is part of the founder's decision rather than beyond it.
    public static func firstImportableAudioLane(in document: TimelineDocument) -> TimelineLane? {
        document.lanes.first { $0.kind == .audio && !$0.isBio }
    }

    /// Create the audio track this import needs, through the ONE owner. Founder 2026-09-23,
    /// resolving the hold #E3 recorded: *"mutation must go through the existing TimelineStore
    /// owner … create exactly a `TimelineLane(kind: .audio)`"*, and no more than that.
    ///
    /// ⭐ IT LIVES HERE RATHER THAN IN THE VIEW, AND THAT IS THE EXISTING SEAM, NOT A DETOUR.
    /// `TheWorkstationHasADoorTests` claim F pins that `WorkstationView` sends `timeline`
    /// nothing but `document`, and that claim's own note says the repair for a surface that
    /// must cause a write is to hand the store to a helper, whose OWN guard then owns the
    /// mutation. That is already how `perform` works, so the door adds no new shape. It also
    /// puts the creator beside `firstImportableAudioLane` — the predicate that decides what an
    /// importable lane IS (#416). A creator that drifted from that predicate (`isBio: true`, a
    /// `.midi` kind) would mint a track the import then refuses, which is the quietest way to
    /// build a control that lies.
    ///
    /// ⚠️ IT RETURNS NOTHING, because `TimelineStore.addLane` returns nothing and widening it
    /// was explicitly not this slice's to do. Nothing here needs the identity: the import
    /// picks its lane with `firstImportableAudioLane`, exactly as it did before this door
    /// existed. A caller that ever needs the new lane's id is the moment to change `addLane`,
    /// not before.
    ///
    /// ⚠️ IT APPENDS, IT DOES NOT "ENSURE". A second audio track is a legitimate thing to
    /// want, and a creator that silently no-ops when one already exists is the #164/#227
    /// lying control in its quietest form: a label that promises a track and sometimes gives
    /// none, with nothing on screen to say which happened.
    @MainActor
    public static func addAudioTrack(timeline: TimelineStore) {
        timeline.addLane(kind: .audio)
    }

    /// nil when the measurement describes something schedulable; the failure otherwise.
    ///
    /// ⚠️ FORMAT AND LENGTH ARE SEPARATE ANSWERS on purpose: "no usable sample rate" and "no
    /// playable length" send the user to different files, and collapsing them into one
    /// "invalid audio" would be the silent-failure class this slice was written to remove.
    public static func validate(_ measurement: Measurement) -> Failure? {
        guard measurement.sampleRate.isFinite, measurement.sampleRate > 0,
              measurement.channelCount > 0 else { return .invalidFormat }
        guard measurement.frameCount > 0,
              measurement.durationSeconds.isFinite,
              measurement.durationSeconds > 0 else { return .invalidDuration }
        return nil
    }

    /// The sentence the Workstation shows after a successful import. Names the file, the span
    /// and the track, because those are the three things that decide whether the user looks at
    /// the plate and recognises what they just did.
    public static func successNote(_ landing: Landing, laneName: String) -> String {
        let bars = max(1, landing.region.lengthTicks / TimelineTime.ticksPerBar)
        let span = "\(bars) \(bars == 1 ? "bar" : "bars")"
        return landing.reusedLibraryFile
            ? "“\(landing.clip.name)” is already in the library — placed \(span) on \(laneName), no second copy."
            : "Imported “\(landing.clip.name)” — \(span) on \(laneName)."
    }

    // MARK: - The pure plan

    /// EVERYTHING THE TRANSACTION DECIDES, as a pure function of values — the managed copy's
    /// URL, what a decoder said about it, the song, whether a slot is free, and the tempo.
    /// Returns the clip, the region, the slot and the lane, or the first reason it cannot.
    ///
    /// ⭐ WHY THE DECISION IS SPLIT OUT FROM THE WRITES. The blocking bundle cannot safely
    /// construct `ClipStore`/`TimelineStore`: both persist into the App Group on every write,
    /// so a test that exercised the success path would leave clips and a track in the running
    /// app's own saved state. Every guard in `TheWorkstationPlaysTheTimelineTests` drives pure
    /// statics over `TimelineDocument`/`[Clip]` values for exactly that reason. This function
    /// is that seam: the rejections, the placement, the bar span and the unwarped defaults are
    /// all decided here and all drivable, and `commit` is left holding two store calls and a
    /// delete.
    ///
    /// ⚠️ THE ORDER OF THE REJECTIONS IS THE FOUNDER'S, and it is observable: a file that is
    /// both unreadable AND destined for a song with no audio lane reports UNREADABLE, because
    /// that is the one the user can act on with the file in their hand.
    public static func plan(managed: URL,
                            measurement: Measurement?,
                            document: TimelineDocument,
                            freeSlotIndex: Int?,
                            bpm: Double) -> Result<Landing, Failure> {
        guard let measurement else { return .failure(.unreadableAudio) }
        if let invalid = validate(measurement) { return .failure(invalid) }
        guard let lane = firstImportableAudioLane(in: document) else { return .failure(.noAudioLane) }
        guard let slot = freeSlotIndex else { return .failure(.clipGridFull) }

        // `nativeBPM` is NOT passed and therefore stays 0 HERE. This transaction is synchronous
        // and `@MainActor`; the tempo analysis is seconds of work and runs afterwards, off the
        // main actor, from the door (#B2). Imported audio still begins UNWARPED either way:
        // `warpEnabled` is false, so `StretchPlan.resolve` returns rate 1.0.
        let clip = AudioClipFactory.clip(
            name: managed.deletingPathExtension().lastPathComponent,
            mediaRef: managed.path,
            nativeDurationSeconds: measurement.durationSeconds)

        let region = AudioClipFactory.unwarpedRegion(
            forDurationSeconds: measurement.durationSeconds,
            bpm: bpm,
            laneID: lane.id,
            clipID: clip.id,
            startTick: document.nextStartTick(inLane: lane.id))

        return .success(Landing(clip: clip, region: region, slotIndex: slot,
                                laneID: lane.id, managedURL: managed, reusedLibraryFile: false))
    }

    // MARK: - MA4.2: the import establishes identity

    /// The durable record a fresh import establishes for its managed copy — pure, so the blocking
    /// bundle can check every field. The evidence is what the import ALREADY measured (rate,
    /// frames, channels) plus the copy's size; the content digest is left nil, because hashing
    /// reads the whole file and belongs off the main actor (MA4.4), never in this transaction.
    public static func assetRecord(managed: URL, originalName: String, measurement: Measurement,
                                   byteSize: Int64, importedAt: Date) -> MediaAssetRecord {
        MediaAssetRecord(kind: .audio,
                         fileName: managed.lastPathComponent,
                         originalName: originalName.isEmpty ? managed.lastPathComponent : originalName,
                         importedAt: importedAt,
                         evidence: MediaAssetRecord.Evidence(byteSize: byteSize,
                                                             sampleRate: measurement.sampleRate,
                                                             frameCount: measurement.frameCount,
                                                             channelCount: measurement.channelCount))
    }

    /// How a landing establishes the durable identity of its file (MA4.3). Explicit at every
    /// call site, because the two library cases need OPPOSITE answers to the same question.
    public enum AssetIdentity {
        /// No registry: the pre-MA4.2 transaction. The clip plays by `mediaRef` and carries no
        /// link — written out by the callers that mean it (tests that do not exercise identity).
        case unlinked
        /// A FRESH COPY of a picked file: new bytes, so ALWAYS a new record. A record that
        /// happens to be bound to the same name (its file deleted, the name reused) is another
        /// source and is never adopted.
        case freshCopy(MediaAssetStore)
        /// A file ALREADY IN THE LIBRARY (the browser's Place, the import's de-dup landing): the
        /// record bound to its name is its identity unless the file's own measurement
        /// CONTRADICTS it; without one, a record is adopted for it now, so the library file gets
        /// exactly one identity instead of one per placement.
        case libraryFile(MediaAssetStore)
    }

    /// The record id a landed clip links to, registering or adopting as `identity` says. nil
    /// when there is no registry or the register was refused — the clip then plays by
    /// `mediaRef`, exactly as before MA4.2.
    ///
    /// ⚠️ THE BINDING IS THE EVIDENCE for a library file, NOT the length. The record names this
    /// very file in the managed home, so it is the file's identity; the measurement can only
    /// REFUTE that (another length or another digest means the file was replaced behind the
    /// record's back — `MediaAssetRecord.isContradicted`). A compatible length is never used to
    /// claim identity for a file under ANOTHER name (founder 2026-09-26).
    @MainActor
    static func establishIdentity(_ identity: AssetIdentity, managed: URL, pickedName: String,
                                  measurement: Measurement, byteSize: Int64,
                                  importedAt: Date) -> UUID? {
        let registry: MediaAssetStore
        let isLibraryFile: Bool
        switch identity {
        case .unlinked: return nil
        case .freshCopy(let store): registry = store; isLibraryFile = false
        case .libraryFile(let store): registry = store; isLibraryFile = true
        }
        // An adopted record's provenance is the file's own name: the name it was picked under
        // was never recorded (it was imported before MA4.2), and nothing here invents one.
        let candidate = assetRecord(managed: managed,
                                    originalName: isLibraryFile ? managed.lastPathComponent : pickedName,
                                    measurement: measurement, byteSize: byteSize,
                                    importedAt: importedAt)
        if isLibraryFile,
           let existing = registry.record(boundTo: MediaAsset.Key(kind: .audio,
                                                                  fileName: managed.lastPathComponent)),
           !existing.isContradicted(by: candidate.evidence) {
            return existing.id
        }
        return registry.register(candidate) ? candidate.id : nil
    }

    // MARK: - The transaction

    /// The whole import, with its three impure steps INJECTED so every path — including the
    /// cleanup — is drivable without AVFoundation, a picker or a real file.
    ///
    /// The sequence is the founder's, in their order: copy, validate the COPY, then verify the
    /// lane and the slot. Checking the lane first would avoid a pointless copy, and the founder
    /// wrote the cleanup contract the other way round ("delete the newly copied file if
    /// import/validation/lane/capacity fails"), which only has meaning if the copy precedes
    /// those checks. It is also the more honest order: the state of the stores can change
    /// between a check and a commit, so the copy is deleted on the answer rather than on a
    /// prediction of it.
    ///
    /// ⚠️ `deleteManagedCopy` IS ONLY EVER CALLED ON THE URL `importFile` JUST RETURNED.
    /// `MediaLibrary.importAudio` picks a collision-free name and copies into it, so that file
    /// is definitely owned by this failed operation. Nothing here scans for orphans, and it must
    /// not start to: a generic sweep over `Media/Audio` would delete media belonging to clips
    /// this build cannot see, which is the #527 hazard exactly.
    ///
    /// ⚠️ AFTER `setClip` THERE IS NO ROLLBACK, and that is stated rather than faked — see the
    /// header. The two writes are ordered so a half-written pair is a spare clip, never a
    /// region pointing at nothing.
    ///
    /// ⭐ MA4.2/MA4.3 — `assets` IS REQUIRED, NEVER DEFAULTED (#431): the landing establishes the
    /// file's durable record FIRST (`establishIdentity` — a fresh copy registers a new one, a
    /// library file adopts the record bound to it) and the clip carries its id (`mediaAssetID`).
    /// Identity before use: a crash between the two leaves a record for a file that exists, never
    /// a clip naming a record that does not. `.unlinked` is written out by the callers that mean
    /// it — the tests that do not exercise identity.
    @MainActor
    @discardableResult
    public static func commit(
        pickedURL: URL,
        clipStore: ClipStore,
        timeline: TimelineStore,
        bpm: Double,
        importFile: (URL) throws -> URL,
        measure: (URL) -> Measurement?,
        deleteManagedCopy: (URL) -> Void,
        assets: AssetIdentity
    ) -> Result<Landing, Failure> {

        let managed: URL
        do {
            managed = try importFile(pickedURL)
        } catch {
            return .failure(.copyFailed)
        }

        func abort(_ failure: Failure) -> Result<Landing, Failure> {
            deleteManagedCopy(managed)
            return .failure(failure)
        }

        let measured = measure(managed)
        let decided = plan(managed: managed,
                           measurement: measured,
                           document: timeline.document,
                           freeSlotIndex: clipStore.firstEmptySlotIndex,
                           bpm: bpm)

        switch decided {
        case .failure(let failure):
            return abort(failure)
        case .success(let landing):
            // MA4.2 — identity before use: the record is registered before the clip that
            // names it is written.
            var landed = landing
            if let measured {
                // The file's size: one metadata read, no content read. Unknown reads as 0.
                let size = (try? managed.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                landed.clip.mediaAssetID = establishIdentity(assets, managed: managed,
                                                             pickedName: pickedURL.lastPathComponent,
                                                             measurement: measured,
                                                             byteSize: Int64(size),
                                                             importedAt: Date())
            }
            clipStore.setClip(at: landed.slotIndex, landed.clip)    // FIRST — playback
                                                                    // resolves clipID here
            timeline.addRegion(landed.region)                       // SECOND — the pointer,
                                                                    // once its target exists
            return .success(landed)
        }
    }

    // MARK: - MA2: the same bytes are already in the library

    /// Which of several identical library files an import reuses: the first one a clip already
    /// plays (so the new part spends no slot), else the first in the browser's order. Libraries
    /// written before MA2 can hold the same sound twice; this keeps a third import from
    /// choosing the copy nothing uses.
    public static func preferredExisting(_ matches: [MediaAsset], clips: [Clip]) -> MediaAsset? {
        matches.first { MediaPlacement.carryingClip($0.key, in: clips) != nil } ?? matches.first
    }

    /// Land an import whose bytes are already in the library, through the library's own
    /// placement (`MediaPlacement.place`) — so this is the same decision "Place" makes, not a
    /// second opinion about where a file goes (#416): a clip that carries the asset gets ONE new
    /// region (no slot), an orphan becomes one clip AT the existing file (no copy).
    ///
    /// ⛔ THIS BRANCH NEVER DELETES. There is no copy to clean up, and the file it would reach
    /// is the user's asset — `place` hands `commit` an identity copy and a no-op delete.
    ///
    /// MA4.3: `assets` goes to the placement, so an orphan landing links the library file's own
    /// record (adopting one if it has none); a reused clip is left as it is.
    @MainActor
    public static func landExisting(_ asset: MediaAsset,
                                    clipStore: ClipStore,
                                    timeline: TimelineStore,
                                    bpm: Double,
                                    measure: (URL) -> Measurement?,
                                    assets: MediaAssetStore?) -> Result<Landing, Failure> {
        MediaPlacement.place(asset, clipStore: clipStore, timeline: timeline, bpm: bpm,
                             measure: measure, assets: assets).map { placed in
            Landing(clip: placed.clip, region: placed.region, slotIndex: placed.slotIndex,
                    laneID: placed.region.laneID, managedURL: asset.url, reusedLibraryFile: true)
        }
    }

    #if canImport(AVFoundation)

    /// The production entry point: hold security-scoped access for the library compare (MA2)
    /// and the copy, then either land the existing file or run the transaction with the real
    /// three steps.
    ///
    /// ⚠️ NO AUDIO TRACK → NO COMPARE. Without a lane the de-dup branch would refuse with
    /// `.noAudioLane` before it ever measured, while the copy path reports `.unreadableAudio`
    /// first — the founder's order (see `plan`). Skipping the compare keeps that order and
    /// spends no read on an import that cannot land.
    ///
    /// ⚠️ THE SCOPE WRAPS THE WHOLE CALL, not just the copy. `importFile` runs first inside
    /// `commit`, so a narrower scope would still be correct — but "acquire, do the work,
    /// release" has one exit path and cannot be re-ordered into a leak by a later edit.
    ///
    /// ⚠️ THE TWO BRANCHES ESTABLISH IDENTITY DIFFERENTLY (MA4.3). The copy path registers a NEW
    /// record for the new bytes; the de-dup branch (`landExisting`) lands a file that is already
    /// in the library, so an orphan landing links that file's own record, and a reused clip is
    /// not rewritten — a clip written before MA4.2 keeps playing by `mediaRef`, unlinked.
    @MainActor
    @discardableResult
    public static func perform(pickedURL: URL,
                               clipStore: ClipStore,
                               timeline: TimelineStore,
                               assets: MediaAssetStore,
                               bpm: Double) -> Result<Landing, Failure> {
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }
        // MA2 — the same bytes already in the library are the same sound: reuse, do not copy.
        // Inside the scope, because the compare reads the picked file.
        let matches = firstImportableAudioLane(in: timeline.document) == nil
            ? [] : MediaLibrary.existingAudio(matching: pickedURL)
        if let existing = preferredExisting(matches, clips: clipStore.slots.compactMap { $0 }) {
            return landExisting(existing, clipStore: clipStore, timeline: timeline, bpm: bpm,
                                measure: measureWithAVFoundation, assets: assets)
        }
        return commit(pickedURL: pickedURL,
                      clipStore: clipStore,
                      timeline: timeline,
                      bpm: bpm,
                      importFile: { try MediaLibrary.importAudio(from: $0) },
                      measure: measureWithAVFoundation,
                      deleteManagedCopy: { try? FileManager.default.removeItem(at: $0) },
                      assets: .freshCopy(assets))
    }

    /// Open the managed copy and report what it is. nil ⇒ it is not audio this build can read.
    ///
    /// ⚠️ IT READS `processingFormat`, NOT `fileFormat`. The processing format is what the
    /// engine would actually schedule; a file whose on-disk format is exotic but which
    /// `AVAudioFile` can present is playable, and judging it by the on-disk format would refuse
    /// files the sink would happily play.
    static func measureWithAVFoundation(_ url: URL) -> Measurement? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        return Measurement(sampleRate: format.sampleRate,
                           frameCount: file.length,
                           channelCount: Int(format.channelCount))
    }

    #endif
}
