// VideoSound.swift
// Echoel — Restructure E12-1 (founder 2026-10-04: „Beats aus Samples und Video als musikalisches
// Material gehören bereits zum DMMW-Ziel. Plane dafür jeweils den kleinsten vollständigen
// Nutzerweg."). A picked video's SOUND becomes an audio file the import can take.
//
// ⭐ IT WRITES ONE FILE AND DECIDES NOTHING. The sound track is exported as AAC into a fresh
// temporary folder; the caller hands that file to the ONE import door (`WorkstationView`'s
// `importAudioFile` → `AudioImport.perform`), which copies it into `Media/Audio`, places it on the
// first audio track, and starts the same tempo and key analysis as any imported file. So a video's
// sound and a file from Files are the same thing from the library on — one transaction, one
// census (`TheWorkstationImportsAudioTests` claim 16 still finds exactly ONE caller).
//
// ⚠️ THE FOLDER IS THE CALLER'S TO REMOVE (`discard`), after the import copied the file. The
// export never writes into the library itself: a half-written file there would read as a sound
// the person owns.
//
// ⚠️ NO PICTURE IS ENCODED. The preset is the audio-only `AVAssetExportPresetAppleM4A`, and the
// container is `.m4a` — #1304 removed video capture and export, and this file keeps it removed
// (`TheShareReadyClipIsNotSoldAnywhereTests` claim 4 counts the video writer inputs).

import Foundation

/// An audio excerpt on the source video's timeline. Invalid input is refused, never
/// silently widened to the whole recording. The source file remains unchanged.
struct VideoSoundRange: Equatable, Sendable {
    let startSeconds: Double
    let endSeconds: Double

    init?(startSeconds: Double, endSeconds: Double, durationSeconds: Double) {
        guard durationSeconds.isFinite, durationSeconds > 0,
              startSeconds.isFinite, endSeconds.isFinite,
              startSeconds >= 0, endSeconds > startSeconds,
              endSeconds <= durationSeconds else { return nil }
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}

#if canImport(AVFoundation)
import AVFoundation

/// The video's sound as an audio file, for the import door.
enum VideoSound {

    /// The base name the sound file carries into the library: "<video name> sound". A video whose
    /// name is empty after trimming is "Video sound". `MediaLibrary` sanitises and de-duplicates
    /// the name when it copies the file in, so no filesystem rule is restated here (#416).
    static func soundFileBase(videoName: String) -> String {
        let name = videoName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Video sound" : name + " sound"
    }

    /// Exports the sound track of `video` as `<base>.m4a` into a new temporary folder.
    /// nil when the video has no sound track, the export fails, or the task was cancelled —
    /// in every nil case nothing is left on disk.
    /// `selection` uses source seconds. nil retains the existing whole-sound import.
    static func extract(from video: URL, named base: String,
                        selection: VideoSoundRange? = nil) async -> URL? {
        let asset = AVURLAsset(url: video)
        guard let tracks = try? await asset.loadTracks(withMediaType: .audio), !tracks.isEmpty,
              !Task.isCancelled,
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        else { return nil }
        if let selection {
            guard let duration = try? await asset.load(.duration), !Task.isCancelled,
                  VideoSoundRange(startSeconds: selection.startSeconds,
                                  endSeconds: selection.endSeconds,
                                  durationSeconds: duration.seconds) != nil else { return nil }
            let start = CMTime(seconds: selection.startSeconds, preferredTimescale: 1_000_000)
            // Rounding to our time scale must not put an end at the file boundary past it.
            let end = CMTimeMinimum(duration, CMTime(seconds: selection.endSeconds,
                                                     preferredTimescale: 1_000_000))
            let range = CMTimeRange(start: start, end: end)
            guard range.isValid, range.duration.isNumeric, range.duration.value > 0 else { return nil }
            session.timeRange = range
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-video-sound-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let out = folder.appendingPathComponent(base).appendingPathExtension("m4a")
        do {
            try await session.export(to: out, as: .m4a)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        guard !Task.isCancelled else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        return out
    }

    /// Removes the temporary folder `extract` made for `file`. Only that folder: a file that is
    /// not inside an `echoel-video-sound-` folder is left alone.
    static func discard(_ file: URL) {
        let folder = file.deletingLastPathComponent()
        guard folder.lastPathComponent.hasPrefix("echoel-video-sound-") else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// Removes what a killed app left behind in `directory`: a kept video copy (`echoel-video-…`,
    /// `PickedVideoFile`) or an interrupted export (`echoel-video-sound-…`). `onDisappear` does not
    /// run when the app is killed, and a video copy can be gigabytes (E12-1 review, MED).
    /// Only entries created BEFORE `cutoff` go: the video card calls this when it appears, and a
    /// pick made in the same moment must not lose its fresh copy. Anything else in the folder
    /// is left alone. Returns how many entries were removed. `async` and nonisolated like
    /// `extract`, so the listing leaves the main actor without a detached task.
    @discardableResult
    static func sweepLeftovers(in directory: URL = FileManager.default.temporaryDirectory,
                               createdBefore cutoff: Date) async -> Int {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: [.creationDateKey])
        else { return 0 }
        var removed = 0
        for entry in entries where entry.lastPathComponent.hasPrefix("echoel-video-") {
            guard let created = try? entry.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  created < cutoff
            else { continue }
            if (try? fm.removeItem(at: entry)) != nil { removed += 1 }
        }
        return removed
    }
}
#endif
