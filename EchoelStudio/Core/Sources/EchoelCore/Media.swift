import Foundation

/// What a song file holds (format 4). Stored by name; a name this build does not know refuses the
/// song, because what a file is decides which track may play it.
public enum MediaKind: String, Codable, Sendable, CaseIterable {
    /// Sound: decoded and played by audio regions, audio clips and the sampler.
    case audio
    /// A picture (with or without its own sound, which Echoel does not play): shown by the
    /// regions of a video track, never decoded as audio.
    case video
}

/// An audio or video file that belongs to the song. The file itself is copied into the song's
/// package (`<song>.echoel/Media/…`) when it is imported, so a song moved, shared or backed up
/// keeps its sounds and pictures; the document stores only the path inside the package and what
/// it measured.
public struct MediaFile: Codable, Equatable, Sendable, Identifiable {
    public var id: MediaID
    /// What the musician sees, usually the original file name without extension.
    public var name: String
    /// Path relative to the song package, e.g. `Media/3F2A….wav`. Never absolute, never `..`.
    public var path: String
    /// An audio file's length in its frames. A video's length in units of `sampleRate` per second
    /// — Echoel measures a video at `videoTimeBase` — so a region cuts audio and picture alike.
    public var frameCount: Int
    public var sampleRate: Double
    /// Stored only for a video; absent is audio, as every file before format 4 is.
    public var kind: MediaKind

    public init(id: MediaID = MediaID(), name: String, path: String, frameCount: Int, sampleRate: Double,
                kind: MediaKind = .audio) {
        self.id = id
        self.name = name
        self.path = path
        self.frameCount = frameCount
        self.sampleRate = sampleRate
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case id, name, path, frameCount, sampleRate, kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MediaID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        frameCount = try c.decode(Int.self, forKey: .frameCount)
        sampleRate = try c.decode(Double.self, forKey: .sampleRate)
        kind = try c.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .audio
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(path, forKey: .path)
        try c.encode(frameCount, forKey: .frameCount)
        try c.encode(sampleRate, forKey: .sampleRate)
        // An audio file writes what it wrote before format 4, so its bytes do not change.
        if kind != .audio { try c.encode(kind, forKey: .kind) }
    }

    /// The units per second a video's length is measured in: fine enough for any frame rate, and
    /// the rate the song's mix is rendered at, so a cut lands on the same sample in both.
    public static let videoTimeBase: Double = 48_000

    /// The measurement of a video `seconds` long, nil when the length is not a usable one.
    public static func videoLength(seconds: Double) -> Int? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let units = (seconds * videoTimeBase).rounded()
        guard units >= 1, units <= Double(maximumFrameCount) else { return nil }
        return Int(units)
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
    /// regions and the audio clips in a slot track by track, then the samples of tracks the
    /// sampler plays (`audibleMedia`) —
    /// then the rest in the song's order (a sample kept for a track that plays another device, a
    /// file no region uses any more). A file that no longer fits is skipped, and a smaller one
    /// after it can still fit.
    public func mediaLoadPlan(budget: Int) -> MediaLoadPlan {
        let audible = audibleMedia
        let heard = Set(audible)
        var order: [MediaID] = []
        var seen = Set<MediaID>()
        // A video is shown, never decoded: it costs no audio memory and is never loaded here.
        for id in audible + media.filter({ $0.kind == .audio }).map(\.id) {
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

    /// The files the song plays, in the order a load plan takes them: the audio regions and the
    /// audio clips in a slot or placed, track by track, then the samples of tracks the sampler
    /// plays. A video track's regions are pictures, not sound, and are not among them. A clip in no slot plays nowhere, so it is a leftover too (second night review,
    /// 2026-10-23). May repeat an id.
    public var audibleMedia: [MediaID] {
        let played: [MediaID] = tracks.filter { $0.kind == .audio }.flatMap { (track: Track) -> [MediaID] in
            let used = Set(track.slots.map(\.clip) + track.placements.map(\.clip))
            return track.regions.map(\.media) + track.clips.filter { used.contains($0.id) }.compactMap { $0.audio?.media }
        }
        let samples: [MediaID] = tracks.compactMap { (track: Track) -> MediaID? in
            track.instrument.device == .sampler ? track.instrument.sample : nil
        }
        return played + samples
    }

    /// Of the decoded files in `loaded`, the ones nothing in the song plays — a sample kept for a
    /// track that plays another device, a file no region or placed clip uses any more — in a
    /// stable order. Under memory pressure these go first: dropping them silences nothing.
    public func releasableMedia(among loaded: some Sequence<MediaID>) -> [MediaID] {
        let heard = Set(audibleMedia)
        return Set(loaded).subtracting(heard).sorted { $0.description < $1.description }
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
