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
// ⚠️ THE LANE IS THE ENGINE'S OWN (#416): a part lands on `VideoLanePlayer.shownLane`, the one
// picture lane the engine shows — never on a lane it would not play.
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
        guard let id = VideoLanePlayer.shownLane(in: document) else { return nil }
        return document.lanes.first { $0.id == id }
    }

    /// The `ordinal`-th video track in document order — 0 is the one the engine shows. A camera
    /// take with both lenses lands its front take on video track 1 (One World M1).
    public static func videoLane(_ ordinal: Int, in document: TimelineDocument) -> TimelineLane? {
        if ordinal == 0 { return pictureLane(in: document) }
        let ids = document.videoLaneIDs
        guard ordinal > 0, ordinal < ids.count else { return nil }
        return document.lanes.first { $0.id == ids[ordinal] }
    }

    /// "Add Video Track" — one tap appends one picture lane, through the ONE owner of lanes.
    /// It appends; it never "ensures" (a second picture track is legitimate — it is simply not
    /// shown in v1, and the inspector says which one is).
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
                            videoLane ordinal: Int) -> Result<Landing, Failure> {
        guard let seconds = durationSeconds, seconds.isFinite, seconds > 0 else { return .failure(.unreadableVideo) }
        guard let lane = videoLane(ordinal, in: document) else { return .failure(.noPictureLane) }
        guard let slot = freeSlotIndex else { return .failure(.clipGridFull) }
        let clip = Clip(name: managed.deletingPathExtension().lastPathComponent, kind: .video,
                        mediaRef: managed.path, nativeDurationSeconds: seconds)
        let region = AudioClipFactory.unwarpedRegion(forDurationSeconds: seconds, bpm: bpm,
                                                     laneID: lane.id, clipID: clip.id,
                                                     startTick: document.nextStartTick(inLane: lane.id))
        return .success(Landing(clip: clip, region: region, slotIndex: slot, laneID: lane.id))
    }

    /// The sentence the Workstation shows after a successful import.
    public static func successNote(_ landing: Landing, laneName: String) -> String {
        let bars = max(1, landing.region.lengthTicks / TimelineTime.ticksPerBar)
        let barWord: String = bars == 1 ? String(localized: "bar") : String(localized: "bars")
        return String(localized: "Imported “") + landing.clip.name + String(localized: "” — ")
            + "\(bars) " + barWord + String(localized: " on ") + laneName + "."
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
                              videoLane ordinal: Int,
                              deleteManagedCopy: (URL) -> Void) -> Result<Landing, Failure> {
        switch plan(managed: managed, durationSeconds: durationSeconds, document: timeline.document,
                    freeSlotIndex: clipStore.firstEmptySlotIndex, bpm: bpm, videoLane: ordinal) {
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

    /// The production entry point: copy under security-scoped access, measure the COPY off the
    /// main actor (the async asset load), then write on the main actor. `bpm` is read by the
    /// caller at the tap, so a tempo glide during the measurement cannot move the part.
    @MainActor
    public static func perform(pickedURL: URL,
                               clipStore: ClipStore,
                               timeline: TimelineStore,
                               bpm: Double,
                               videoLane ordinal: Int) async -> Result<Landing, Failure> {
        // Refuse before copying when nothing can land, so a refused import leaves no file.
        guard videoLane(ordinal, in: timeline.document) != nil else { return .failure(.noPictureLane) }
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
                      bpm: bpm, videoLane: ordinal, deleteManagedCopy: { try? FileManager.default.removeItem(at: $0) })
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
