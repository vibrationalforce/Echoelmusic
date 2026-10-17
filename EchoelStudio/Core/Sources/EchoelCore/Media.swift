import Foundation

/// An audio file that belongs to the song. The file itself is copied into the song's package
/// (`<song>.echoel/Media/…`) when it is imported, so a song moved, shared or backed up keeps
/// its sounds; the document stores only the path inside the package and what it measured.
public struct MediaFile: Codable, Equatable, Sendable, Identifiable {
    public var id: MediaID
    /// What the musician sees, usually the original file name without extension.
    public var name: String
    /// Path relative to the song package, e.g. `Media/3F2A….wav`. Never absolute, never `..`.
    public var path: String
    public var frameCount: Int
    public var sampleRate: Double

    public init(id: MediaID = MediaID(), name: String, path: String, frameCount: Int, sampleRate: Double) {
        self.id = id
        self.name = name
        self.path = path
        self.frameCount = frameCount
        self.sampleRate = sampleRate
    }

    /// The folder inside a song package that holds its media.
    public static let directory = "Media"

    /// Duration in seconds; 0 when the measurement is unusable.
    public var duration: Double {
        sampleRate > 0 && sampleRate.isFinite ? Double(frameCount) / sampleRate : 0
    }

    /// A relative path with no parent steps and no empty segment, inside `Media/`.
    public static func isSafePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.first == Substring(directory) else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

extension MediaFile {
    /// Where the file lives inside the song package at `package`, or nil when the stored path
    /// would leave the package. A song file read from disk was never checked by `media.add`,
    /// so a reader resolves through this, never by appending the path itself.
    public func url(in package: URL) -> URL? {
        guard Self.isSafePath(path) else { return nil }
        return path.split(separator: "/").reduce(package) { $0.appendingPathComponent(String($1)) }
    }
}

extension Project {
    public func mediaFile(_ id: MediaID) -> MediaFile? {
        media.first { $0.id == id }
    }
}
