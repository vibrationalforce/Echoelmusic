// VideoImport.swift
// Echoel — One World P1 (founder 2026-10-15: "Video Spur fehlt"). The first reachable PRODUCER of
// a picture part: a picked video becomes an app-owned copy in `Media/Picture`, and that copy lands
// on the picture track the engine shows, through the clip and timeline stores that already persist.
//
//     picked file → MediaLibrary.importPictureVideo → measure the MANAGED COPY
//                 → Clip(kind: .video) → ClipStore → TimelineRegion → TimelineStore
//
// ⭐ THE SAME SHAPE AS `AudioImport`, ON PURPOSE (#416): one impure step (the copy), the placement
// pure (`plan`), the clip written BEFORE the region (playback resolves `clipID` through
// `ClipStore`), and a failed measurement deletes exactly the copy it made. The region spans the
// file in whole bars at the song's tempo (`AudioClipFactory.unwarpedRegion`); past the file's end
// the picture holds its last frame (`VideoLanePlan`).
//
// ⭐ `Media/Picture`, NOT `Media/Video`. The video card owns `Media/Video` and sweeps it when it
// appears (VV-3a): a picture part kept there would be deleted by the next card. The two homes keep
// the two owners apart, and `MediaLibrary.resolveRef` looks in both.
//
// ⚠️ THE LANE IS THE ENGINE'S OWN (#416): a part lands on `VideoLanePlayer.topLane`, the picture
// track that covers every track below it (One World M2: lower tracks show through its gaps).
//
// ⛔ WHAT THIS IS NOT: no de-duplication against the library, no durable asset record, no sound
// (the video's sound is the video card's "Use Its Sound" door), no cut detection. A video file
// that later disappears leaves its part in place and dark.

import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// The picture-file import transaction: managed copy → measured length → clip + region.
public enum VideoImport {

    /// What a camera take's landing produced, per lens — nil for a lens that wrote no file.
    public struct TakeLanding: Sendable, Equatable {
        public var rear: Result<Landing, Failure>?
        public var front: Result<Landing, Failure>?
    }

    public enum Failure: Error, Equatable, Sendable {
        case pickerFailed
        case copyFailed
        /// The copy has no readable picture, or no playable length.
        case unreadableVideo
        case noPictureLane
        case clipGridFull

        public var userMessage: String {
            switch self {
            case .pickerFailed:    return String(localized: "Couldn't open that file.")
            case .copyFailed:      return String(localized: "Couldn't copy that video into the library.")
            case .unreadableVideo: return String(localized: "That video could not be read — try another file.")
            case .noPictureLane:   return String(localized: "This piece has no video track — add a video track first.")
            case .clipGridFull:    return AudioImport.gridFullSentence
            }
        }
    }

    /// What a successful import produced.
    public struct Landing: Sendable, Equatable {
        public var clip: Clip
        public var region: TimelineRegion
        public var slotIndex: Int
        public var laneID: UUID
    }

    // MARK: - Pure decisions

    /// The lane a picture part lands on: the one the engine shows, or nil.
    public static func pictureLane(in document: TimelineDocument) -> TimelineLane? {
        guard let id = VideoLanePlayer.topLane(in: document) else { return nil }
        return document.lanes.first { $0.id == id }
    }

    /// "Add Video Track" — one tap appends one picture lane, through the ONE owner of lanes.
    /// It appends; it never "ensures" (a second picture track is legitimate — it is the angle
    /// below, showing through the top track's gaps, One World M2).
    @MainActor
    public static func addVideoTrack(timeline: TimelineStore) {
        timeline.addLane(kind: .video)
    }

    /// Everything the transaction decides, as a pure function of values. The order of the
    /// refusals is the audio import's: the file first, because that is what the person can act
    /// on with the file in hand.
    public static func plan(managed: URL,
                            durationSeconds: Double?,
                            document: TimelineDocument,
                            freeSlotIndex: Int?,
                            bpm: Double,
                            laneID: UUID,
                            startTick: Int?) -> Result<Landing, Failure> {
        guard let seconds = durationSeconds, seconds.isFinite, seconds > 0 else { return .failure(.unreadableVideo) }
        // The lane is named by ID, fixed when the landing began — an ordinal re-read after the
        // measurement could point at a different track (review 2026-10-15 finding 6).
        guard document.videoLaneIDs.contains(laneID),
              let lane = document.lanes.first(where: { $0.id == laneID }) else { return .failure(.noPictureLane) }
        guard let slot = freeSlotIndex else { return .failure(.clipGridFull) }
        let clip = Clip(name: managed.deletingPathExtension().lastPathComponent, kind: .video,
                        mediaRef: managed.path, nativeDurationSeconds: seconds)
        let region = AudioClipFactory.unwarpedRegion(forDurationSeconds: seconds, bpm: bpm,
                                                     laneID: lane.id, clipID: clip.id,
                                                     startTick: startTick ?? document.nextStartTick(inLane: lane.id))
        return .success(Landing(clip: clip, region: region, slotIndex: slot, laneID: lane.id))
    }

    /// The sentence the Workstation shows after a successful import.
    public static func successNote(_ landing: Landing, laneName: String) -> String {
        let bars = max(1, landing.region.lengthTicks / TimelineTime.ticksPerBar)
        let barWord: String = bars == 1 ? String(localized: "bar") : String(localized: "bars")
        return String(localized: "Imported “") + landing.clip.name + String(localized: "” — ")
            + "\(bars) " + barWord + String(localized: " on ") + laneName + "."
    }

    /// The sentence after a camera take lands. A refusal names its reason and, when the take was
    /// kept in the library (every refusal except a failed move), says so — the take was never
    /// deleted. Otherwise the success sentence of the rear part (or the front one).
    public static func takeNote(_ landing: TakeLanding, laneName: (UUID) -> String) -> String {
        let results = [landing.rear, landing.front].compactMap { $0 }
        for result in results {
            if case .failure(let failure) = result {
                guard failure != .copyFailed else {
                    return String(localized: "The take could not be saved.")
                }
                return failure.userMessage + " " + String(localized: "The take is kept on this phone.")
            }
        }
        for result in results {
            if case .success(let part) = result { return successNote(part, laneName: laneName(part.laneID)) }
        }
        return String(localized: "The take could not be saved.")
    }

    // MARK: - The transaction

    /// The writes, after the copy and the measurement: the clip FIRST, the region SECOND. On a
    /// refusal the managed copy is deleted and nothing is written.
    @MainActor
    @discardableResult
    public static func commit(managed: URL,
                              durationSeconds: Double?,
                              clipStore: ClipStore,
                              timeline: TimelineStore,
                              bpm: Double,
                              laneID: UUID,
                              startTick: Int?,
                              deleteManagedCopy: (URL) -> Void) -> Result<Landing, Failure> {
        switch plan(managed: managed, durationSeconds: durationSeconds, document: timeline.document,
                    freeSlotIndex: clipStore.firstEmptySlotIndex, bpm: bpm, laneID: laneID, startTick: startTick) {
        case .failure(let failure):
            deleteManagedCopy(managed)
            return .failure(failure)
        case .success(let landing):
            clipStore.setClip(at: landing.slotIndex, landing.clip)   // FIRST — playback resolves clipID here
            timeline.addRegion(landing.region)                       // SECOND — the pointer, once its target exists
            return .success(landing)
        }
    }

    #if canImport(AVFoundation)

    /// The production entry point for a PICKED file: copy it under security-scoped access, measure
    /// the copy off the main actor (the async asset load), then write on the main actor. `bpm` is
    /// read by the caller at the tap, so a tempo glide during the measurement cannot move the part.
    /// A refused landing deletes the copy it made — never the person's file.
    @MainActor
    public static func perform(pickedURL: URL,
                               clipStore: ClipStore,
                               timeline: TimelineStore,
                               bpm: Double,
                               laneID: UUID,
                               startTick: Int?) async -> Result<Landing, Failure> {
        // Refuse before copying when nothing can land, so a refused import leaves no file.
        guard timeline.document.videoLaneIDs.contains(laneID) else { return .failure(.noPictureLane) }
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        let managed: URL
        do {
            managed = try MediaLibrary.importPictureVideo(from: pickedURL)
        } catch {
            if scoped { pickedURL.stopAccessingSecurityScopedResource() }
            return .failure(.copyFailed)
        }
        if scoped { pickedURL.stopAccessingSecurityScopedResource() }
        let seconds = await measuredSeconds(managed)
        return commit(managed: managed, durationSeconds: seconds, clipStore: clipStore, timeline: timeline,
                      bpm: bpm, laneID: laneID, startTick: startTick,
                      deleteManagedCopy: { url in try? FileManager.default.removeItem(at: url) })
    }

    /// The production entry point for a CAMERA TAKE (One World C1/M1; review 2026-10-15 B2 + B3).
    /// 1. KEEP FIRST: every file is moved into `Media/Picture` before any lane is checked, so a take
    ///    the piece refuses still lives in the app's own library — never in the temporary folder.
    /// 2. MEASURE both kept files (the only `await`).
    /// 3. LAND IN ONE STEP: after the last `await`, on the main actor with no suspension in
    ///    between, ONE start is read — the later of the two tracks' ends, as they are NOW — and
    ///    both parts are written at it. Nothing can land between the read and the writes, so the
    ///    two angles share a position and never overlap a part that arrived during the measuring.
    /// A refused lens keeps its file; a take is never deleted.
    @MainActor
    public static func performTake(rear: URL?,
                                   front: URL?,
                                   clipStore: ClipStore,
                                   timeline: TimelineStore,
                                   bpm: Double,
                                   rearLane: UUID,
                                   frontLane: UUID?) async -> TakeLanding {
        let rearKept = rear.map(keepTake)
        let frontKept = front.map(keepTake)
        let rearSeconds = await measuredSeconds(of: rearKept)
        let frontSeconds = await measuredSeconds(of: frontKept)
        // ⚠️ No `await` below this line — the start and both writes are one step.
        var lanes: [UUID] = []
        if rearKept != nil { lanes.append(rearLane) }
        if frontKept != nil, let frontLane { lanes.append(frontLane) }
        let start = lanes.filter { timeline.document.videoLaneIDs.contains($0) }
            .map { timeline.document.nextStartTick(inLane: $0) }
            .max()
        func land(_ kept: Result<URL, Failure>?, seconds: Double?, lane: UUID?) -> Result<Landing, Failure>? {
            guard let kept else { return nil }
            switch kept {
            case .failure(let failure):
                return .failure(failure)
            case .success(let managed):
                guard let lane else { return .failure(.noPictureLane) }
                return commit(managed: managed, durationSeconds: seconds, clipStore: clipStore, timeline: timeline,
                              bpm: bpm, laneID: lane, startTick: start,
                              deleteManagedCopy: { _ in })   // a take is never deleted
            }
        }
        return TakeLanding(rear: land(rearKept, seconds: rearSeconds, lane: rearLane),
                           front: land(frontKept, seconds: frontSeconds, lane: frontLane))
    }

    /// Move one take file into the library.
    private static func keepTake(_ url: URL) -> Result<URL, Failure> {
        do {
            return .success(try MediaLibrary.takePictureVideo(from: url))
        } catch {
            return .failure(.copyFailed)
        }
    }

    private static func measuredSeconds(of kept: Result<URL, Failure>?) async -> Double? {
        guard case .success(let url)? = kept else { return nil }
        return await measuredSeconds(url)
    }

    /// The copy's length in seconds — nil when it has no video track or no finite length.
    nonisolated static func measuredSeconds(_ url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty,
              let duration = try? await asset.load(.duration) else { return nil }
        let seconds = duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    #endif
}
