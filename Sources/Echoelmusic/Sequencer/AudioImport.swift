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
// There is no `MediaAsset` and no `AudioAsset`: `Clip.id` remains the creative identity and
// `mediaRef` remains the file-location bridge, so nothing here claims canonical source-media
// identity. There is no new store, no new persistence root, no new clock and no new playback
// engine. There is no audio INPUT, no recording, no sample instrument and no grain engine. There
// is no BPM estimate (founder decision 7 — `nativeBPM` stays 0, the clip never warps), no
// automatic lane creation (decision 4), and no relink UI: a media file that later disappears
// leaves the clip and the region alone and blocks only its own playback (decision 5).
//
// ⚠️ THE ORDER OF THE TWO WRITES IS LOAD-BEARING AND THE PAIR IS NOT ATOMIC. `ClipStore` first,
// `TimelineStore` second, because playback resolves `TimelineRegion.clipID` THROUGH `ClipStore`
// (`AudioLanePlayer`'s injected `resolveURL` is `clipStore.clip(id:)` → `MediaLibrary.resolveRef`).
// A region persisted before its clip is a dangling pointer for as long as the gap lasts; a clip
// persisted before its region is an unreferenced slot, which is the harmless direction. Neither
// store exposes a transaction and both `persist()` fire-and-forget, so if the second write's disk
// write fails there is no rollback — the honest statement is that this is a two-write sequence
// ordered so the failure mode is a spare clip, NOT a cross-store transaction system.
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
        /// The song has no audio track to place it on. Founder decision 4: fail, never create one.
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
            case .noAudioLane:     return "Add an audio track first."
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

        public init(clip: Clip, region: TimelineRegion, slotIndex: Int, laneID: UUID,
                    managedURL: URL) {
            self.clip = clip
            self.region = region
            self.slotIndex = slotIndex
            self.laneID = laneID
            self.managedURL = managedURL
        }
    }

    // MARK: - Pure decisions

    /// The first lane this import may land on, or nil. The predicate is `audioLaneIDs`' own —
    /// see the header for why `!isBio` is part of the founder's decision rather than beyond it.
    public static func firstImportableAudioLane(in document: TimelineDocument) -> TimelineLane? {
        document.lanes.first { $0.kind == .audio && !$0.isBio }
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
        return "Imported “\(landing.clip.name)” — \(bars) \(bars == 1 ? "bar" : "bars") on \(laneName)."
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

        // `nativeBPM` is NOT passed and therefore stays 0 — founder decision 7. A clip with an
        // unknown native tempo never warps (`StretchPlan.resolve` returns rate 1.0 while
        // `warpEnabled` is false), which is exactly "imported audio begins unwarped".
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
                                laneID: lane.id, managedURL: managed))
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
    @MainActor
    @discardableResult
    public static func commit(
        pickedURL: URL,
        clipStore: ClipStore,
        timeline: TimelineStore,
        bpm: Double,
        importFile: (URL) throws -> URL,
        measure: (URL) -> Measurement?,
        deleteManagedCopy: (URL) -> Void
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

        let decided = plan(managed: managed,
                           measurement: measure(managed),
                           document: timeline.document,
                           freeSlotIndex: clipStore.firstEmptySlotIndex,
                           bpm: bpm)

        switch decided {
        case .failure(let failure):
            return abort(failure)
        case .success(let landing):
            clipStore.setClip(at: landing.slotIndex, landing.clip)  // FIRST — playback
                                                                    // resolves clipID here
            timeline.addRegion(landing.region)                      // SECOND — the pointer,
                                                                    // once its target exists
            return .success(landing)
        }
    }

    #if canImport(AVFoundation)

    /// The production entry point: hold security-scoped access for the copy, then run the
    /// transaction with the real three steps.
    ///
    /// ⚠️ THE SCOPE WRAPS THE WHOLE CALL, not just the copy. `importFile` runs first inside
    /// `commit`, so a narrower scope would still be correct — but "acquire, do the work,
    /// release" has one exit path and cannot be re-ordered into a leak by a later edit.
    @MainActor
    @discardableResult
    public static func perform(pickedURL: URL,
                               clipStore: ClipStore,
                               timeline: TimelineStore,
                               bpm: Double) -> Result<Landing, Failure> {
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }
        return commit(pickedURL: pickedURL,
                      clipStore: clipStore,
                      timeline: timeline,
                      bpm: bpm,
                      importFile: { try MediaLibrary.importAudio(from: $0) },
                      measure: measureWithAVFoundation,
                      deleteManagedCopy: { try? FileManager.default.removeItem(at: $0) })
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
