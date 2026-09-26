// MediaRelink.swift
// Echoel — point a clip whose file is MISSING at a file in the media library (Phase 3 / B2b; plan
// `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`, founder media law 2026-09-26: "missing media keeps
// its creative structure … relink stays possible").
//
//     "Missing on this device" row → Relink → a library file
//         → the clip's `mediaRef` (and its measured length) now name that file
//         → every part that plays the clip plays it again; nothing else about the song moves
//
// ⭐ THE CLIP IS THE CREATIVE USE, THE FILE IS THE SOURCE — AND ONLY THE SOURCE CHANGES. The clip
// keeps its id (every region points at it), its name, its tempo (`nativeBPM`), its automation;
// no region is written. That is the whole reason a relink exists instead of "Place it again":
// placing makes a NEW part and leaves the silent ones where they were.
//
// ⚠️ SAME RECORDING ONLY. A clip that knows its length refuses a file of another length
// (`sameLength`). A relink to a different sound would keep the old tempo and the old part
// lengths, so the song would play a different file warped and cut for the one that is gone —
// silently. A different sound is a new part: Place it. A clip that never learned its length
// takes the file's.
//
// ⚠️ NOT AN UNDO STEP. `TimelineStore`'s history holds the SONG (regions, lanes); a clip's file is
// clip state, like its tempo (`setAuthoredNativeBPM`) — a relink is undone by relinking again.
//
// ⛔ NEVER A FILE OPERATION. Nothing here copies, moves or deletes; the chosen file is used where
// it already is in the library, as `MediaPlacement`'s orphan path uses it.

import Foundation

/// Relinking a missing clip to a library file.
public enum MediaRelink {

    /// Why a relink was refused. Nothing is written in any of these cases.
    public enum Refusal: Error, Equatable, Sendable {
        /// No clip with that id, or it is not an audio clip.
        case noAudioClip
        /// The library file vanished between the listing and the tap.
        case fileGone
        /// The file could not be measured as audio.
        case unreadable
        /// The clip knows its length and the file is another recording.
        case differentLength(expected: Double, found: Double)

        /// The words the browser shows.
        public var userMessage: String {
            switch self {
            case .noAudioClip:
                return "That clip can't be relinked."
            case .fileGone:
                return "That file is no longer in the library."
            case .unreadable:
                return "That file isn't audio this app can read."
            case .differentLength(let expected, let found):
                return String(format: "That file is %.1f s long and the clip's file was %.1f s. "
                              + "Relink only to the same recording — Place it as a new part instead.",
                              found, expected)
            }
        }
    }

    /// Two lengths that belong to one recording. A re-export or a format change moves the end by
    /// a few milliseconds, so the tolerance is 50 ms or 1 % of the longer length, whichever is
    /// larger — a different take of a loop differs by far more.
    public static func sameLength(_ a: Double, _ b: Double) -> Bool {
        guard a.isFinite, b.isFinite else { return false }
        return abs(a - b) <= Swift.max(0.05, 0.01 * Swift.max(a, b))
    }

    /// The pure decision: the length the clip will record, or why not.
    public static func decide(_ clip: Clip, measuredSeconds: Double?) -> Result<Double, Refusal> {
        guard clip.kind == .audio else { return .failure(.noAudioClip) }
        guard let found = measuredSeconds, found.isFinite, found > 0 else {
            return .failure(.unreadable)
        }
        if let expected = clip.nativeDurationSeconds, expected.isFinite, expected > 0,
           !sameLength(expected, found) {
            return .failure(.differentLength(expected: expected, found: found))
        }
        return .success(found)
    }

    /// Relink `clipID` to `asset`, through the one clip writer. `measure` and `fileExists` are
    /// injected so the blocking bundle can drive the whole path on paths that exist only as
    /// strings; production passes the real ones (`MediaBrowserView`).
    @MainActor
    public static func relink(_ clipID: UUID,
                              to asset: MediaAsset,
                              clipStore: ClipStore,
                              fileExists: (String) -> Bool,
                              measure: (URL) -> AudioImport.Measurement?) -> Result<Double, Refusal> {
        guard let clip = clipStore.clip(id: clipID) else { return .failure(.noAudioClip) }
        guard clip.kind == .audio else { return .failure(.noAudioClip) }
        // The list is a snapshot: the file must still be there before anything is measured.
        guard fileExists(asset.url.path) else { return .failure(.fileGone) }
        let decision = decide(clip, measuredSeconds: measure(asset.url)?.durationSeconds)
        guard case .success(let seconds) = decision else { return decision }
        guard clipStore.relinkAudio(id: clipID, mediaRef: asset.url.path,
                                    nativeDurationSeconds: seconds) else {
            return .failure(.noAudioClip)
        }
        return .success(seconds)
    }

    #if canImport(AVFoundation)

    /// The production entry point — the browser's Relink: the real existence check and the
    /// import's own measurement (one header read of the chosen file, on the tap).
    @MainActor
    public static func perform(_ clipID: UUID, to asset: MediaAsset,
                               clipStore: ClipStore) -> Result<Double, Refusal> {
        relink(clipID, to: asset, clipStore: clipStore,
               fileExists: { FileManager.default.fileExists(atPath: $0) },
               measure: AudioImport.measureWithAVFoundation)
    }

    #endif
}
