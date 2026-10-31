import AVFoundation
import EchoelCore
import Foundation

/// Bringing a video into a song (wave W7): copy it into the song package, then measure the copy.
/// The picture is never decoded here and its sound is never played; the length is what the song
/// stores, in `MediaFile.videoTimeBase` units. Plain functions on no actor — callers run them off
/// the main thread, because copying a long video takes a while.
enum VideoFileImport {
    enum ImportError: LocalizedError {
        case unreadable
        case noPicture

        var errorDescription: String? {
            switch self {
            case .unreadable: "This file is not a video Echoel can read."
            case .noPicture: "This file holds no picture."
            }
        }
    }

    /// Copies `source` into the `Media` folder of the package at `package` under `id`, measures the
    /// copy and describes it for `media.add`. Nothing is left behind when the copy is unreadable.
    static func importFile(_ source: URL, into package: URL, id: MediaID = MediaID()) async throws -> MediaFile {
        let path = "\(MediaFile.directory)/\(id).\(fileExtension(of: source))"
        let name = displayName(of: source)
        guard let destination = MediaFile(id: id, name: name, path: path, frameCount: 1, sampleRate: 1).url(in: package) else {
            throw ImportError.unreadable
        }
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
        do {
            return try await describe(destination, id: id, name: name, path: path)
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }

    /// The song's description of the video at `url`: its length, measured from the file. A file
    /// without a picture track or without a finite length is refused.
    static func describe(_ url: URL, id: MediaID, name: String, path: String) async throws -> MediaFile {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty else {
            throw ImportError.noPicture
        }
        guard let duration = try? await asset.load(.duration),
              let length = MediaFile.videoLength(seconds: duration.seconds) else { throw ImportError.unreadable }
        return MediaFile(id: id, name: name, path: path, frameCount: length, sampleRate: MediaFile.videoTimeBase,
                         kind: .video)
    }

    /// The original extension when it is a short plain word, so the copy keeps its type hint.
    static func fileExtension(of url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let plain = !ext.isEmpty && ext.count <= 8 && ext.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return plain ? ext : "mov"
    }

    private static func displayName(of url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Video" : String(base.prefix(Names.maximumLength))
    }
}
