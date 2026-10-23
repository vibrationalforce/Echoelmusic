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

    /// The rates an audio file can have. A file claiming a rate outside it is refused: the
    /// arrangement turns frames into ticks through it, and an absurd rate overflows that sum.
    public static let sampleRateRange: ClosedRange<Double> = 1_000...768_000
    /// At most a day of audio at the highest rate.
    public static let maximumFrameCount = 768_000 * 60 * 60 * 24

    /// Frames and rate a song can lay out on its timeline.
    public var hasUsableFormat: Bool {
        frameCount > 0 && frameCount <= Self.maximumFrameCount
            && sampleRate.isFinite && Self.sampleRateRange.contains(sampleRate)
    }

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

/// Which of a song's audio files to decode when only so many bytes of decoded audio fit in
/// memory. A file is decoded whole, one mono `Float` per frame, so its cost is known from the
/// song before the file is read.
public struct MediaLoadPlan: Equatable, Sendable {
    /// What to decode, in this order.
    public var load: [MediaFile]
    /// What does not fit. The song still opens; whatever plays these files is silent.
    public var skipped: [MediaFile]
    /// The skipped files something in the song plays — a region, an audio clip, the sample of a
    /// track the sampler plays: what is heard as silence. The rest of `skipped` nothing plays now.
    public var silenced: [MediaFile]

    public init(load: [MediaFile] = [], skipped: [MediaFile] = [], silenced: [MediaFile] = []) {
        self.load = load
        self.skipped = skipped
        self.silenced = silenced
    }
}

extension Project {
    /// What one decoded frame of a song file takes in memory: a mono `Float`.
    public static let decodedBytesPerFrame = MemoryLayout<Float>.size

    /// What decoding `file` costs in memory, from the frame count the song stores.
    public static func decodedBytes(_ file: MediaFile) -> Int {
        Swift.min(Swift.max(0, file.frameCount), MediaFile.maximumFrameCount) * decodedBytesPerFrame
    }

    /// The files to decode within `budget` bytes. What the song plays comes first — the audio
    /// regions and audio clips track by track, then the samples of tracks the sampler plays —
    /// then the rest in the song's order (a sample kept for a track that plays another device, a
    /// file no region uses any more). A file that no longer fits is skipped, and a smaller one
    /// after it can still fit.
    public func mediaLoadPlan(budget: Int) -> MediaLoadPlan {
        let audible = audibleMedia
        let heard = Set(audible)
        var order: [MediaID] = []
        var seen = Set<MediaID>()
        for id in audible + media.map(\.id) {
            if seen.insert(id).inserted { order.append(id) }
        }
        let files = Dictionary(media.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var plan = MediaLoadPlan()
        var left = Swift.max(0, budget)
        for id in order {
            guard let file = files[id] else { continue }
            let cost = Self.decodedBytes(file)
            if cost <= left {
                left -= cost
                plan.load.append(file)
            } else {
                plan.skipped.append(file)
                if heard.contains(id) { plan.silenced.append(file) }
            }
        }
        return plan
    }

    /// The files the song plays, in the order a load plan takes them: the audio regions and audio
    /// clips track by track, then the samples of tracks the sampler plays. May repeat an id.
    public var audibleMedia: [MediaID] {
        let played: [MediaID] = tracks.flatMap { (track: Track) -> [MediaID] in
            track.regions.map(\.media) + track.clips.compactMap { $0.audio?.media }
        }
        let samples: [MediaID] = tracks.compactMap { (track: Track) -> MediaID? in
            track.instrument.device == .sampler ? track.instrument.sample : nil
        }
        return played + samples
    }

    /// What this song would leave silent within `budget` that `before` did not: a file it plays
    /// that no longer fits, or one it newly plays that does not fit. A change that places a new
    /// file is judged with the file placed — appended alone, nothing points at it yet and it would
    /// rank behind every file nothing plays (second night review, 2026-10-23).
    public func newlySilencedMedia(budget: Int, comparedTo before: Project) -> [MediaFile] {
        let was = Set(before.mediaLoadPlan(budget: budget).silenced.map(\.id))
        return mediaLoadPlan(budget: budget).silenced.filter { !was.contains($0.id) }
    }
}
