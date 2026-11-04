import Foundation

/// The sample and media browser's list (Recovery 7): every file the open song holds, every file
/// the other songs of the library hold, and files picked into the browser that are in no song yet
/// — filtered by kind, searched by name, sorted. Local only: it reads what is on the device and
/// never asks a network.
///
/// It shows what is measured and nothing else. A file's length and rate come from the song that
/// holds it (`MediaFile`); a tempo only when a region of that file in its song states the tempo the
/// file was played at (`AudioRegion.nativeBPM`, the one tempo the format stores for a file). No
/// song stores a key for a file, so the browser shows none.
///
/// Placing a file is the existing commands (`commands(placing:on:in:)`), never a door of its own.
public enum MediaBrowser {
    /// What a file is, for the browser's filter.
    public enum Kind: String, CaseIterable, Sendable {
        case audio, video, image

        public var title: String {
            switch self {
            case .audio: "Audio"
            case .video: "Video"
            case .image: "Pictures"
            }
        }
    }

    /// Where a file the browser lists is.
    public enum Origin: Hashable, Sendable {
        /// In the open song: placing it adds nothing to the song but the placement.
        case song
        /// In another song of the library, named here: placing it copies it into the open song.
        case library(song: String)
        /// Picked into the browser and in no song: placing it copies it into the open song.
        case imported

        /// The order the browser groups by: the open song first.
        var rank: Int {
            switch self {
            case .song: 0
            case .library: 1
            case .imported: 2
            }
        }

        public var title: String {
            switch self {
            case .song: "This song"
            case .library(let song): song
            case .imported: "Imported"
            }
        }
    }

    public enum Sort: String, CaseIterable, Sendable {
        /// By name, numbers in order ("Kick 2" before "Kick 10").
        case name
        /// Longest first; a file with no measured length last.
        case duration
        /// The open song, then the library's songs, then imported files; by name inside each.
        case origin

        public var title: String {
            switch self {
            case .name: "Name"
            case .duration: "Length"
            case .origin: "Where"
            }
        }
    }

    public struct Item: Hashable, Sendable, Identifiable {
        /// Stable across a reload of the same files: the origin and the file.
        public let id: String
        public let name: String
        public let kind: Kind
        public let origin: Origin
        /// The file's id in the open song; nil for a file the open song does not hold.
        public let media: MediaID?
        /// Where the file is read from, for a file outside the open song (and for listening).
        public let location: URL?
        /// Seconds, as its song measured it; nil when nothing measured it.
        public let duration: Double?
        /// An audio file's sample rate; nil for a video, a picture, or an unmeasured file.
        public let sampleRate: Double?
        /// The tempo the file was played at, when its song states one for it; nil otherwise.
        public let tempo: Double?

        public init(id: String, name: String, kind: Kind, origin: Origin, media: MediaID? = nil, location: URL? = nil,
                    duration: Double? = nil, sampleRate: Double? = nil, tempo: Double? = nil) {
            self.id = id
            self.name = name
            self.kind = kind
            self.origin = origin
            self.media = media
            self.location = location
            self.duration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            self.sampleRate = sampleRate.flatMap { $0.isFinite && MediaFile.sampleRateRange.contains($0) ? $0 : nil }
            self.tempo = tempo.flatMap { $0.isFinite && AudioRegion.nativeBPMRange.contains($0) ? $0 : nil }
        }

        /// Whether it can be heard in the browser: an audio file.
        public var canListen: Bool { kind == .audio }
    }

    // MARK: - Listing

    /// The files of `project` as items of `origin`, in the song's order. `package` is the song's
    /// package, where a file outside the open song is read from; a stored path that would leave the
    /// package gives no location (`MediaFile.url(in:)`), and such a file from another song is not
    /// listed at all, since nothing could read it.
    public static func items(of project: Project, origin: Origin, package: URL?) -> [Item] {
        project.media.compactMap { file -> Item? in
            let location = package.flatMap { file.url(in: $0) }
            if origin != .song, location == nil { return nil }
            let kind: Kind = file.kind == .video ? .video : .audio
            let prefix: String
            switch origin {
            case .song: prefix = "song"
            case .library: prefix = "library:" + (package?.standardizedFileURL.path ?? "")
            case .imported: prefix = "imported"
            }
            return Item(id: "\(prefix)/\(file.id)", name: file.name, kind: kind, origin: origin,
                        media: origin == .song ? file.id : nil, location: location,
                        duration: file.hasUsableFormat ? file.duration : nil,
                        sampleRate: kind == .audio && file.hasUsableFormat ? file.sampleRate : nil,
                        tempo: kind == .audio ? tempo(of: file.id, in: project) : nil)
        }
    }

    /// The tempo `project` states for the file `media`: the native tempo its audio regions give,
    /// when every region that gives one gives the same. Nil when none gives one, or two disagree —
    /// a measurement the song does not hold is not made up here.
    public static func tempo(of media: MediaID, in project: Project) -> Double? {
        var found: Double?
        for track in project.tracks where track.kind == .audio {
            for region in track.regions where region.media == media {
                guard let bpm = region.nativeBPM, bpm.isFinite, AudioRegion.nativeBPMRange.contains(bpm) else { continue }
                if let found, found != bpm { return nil }
                found = bpm
            }
        }
        return found
    }

    // MARK: - Filter, search, sort

    /// The items of `kind` (all with nil) whose name holds every word of `query`, ignoring case and
    /// accents. A query of only spaces matches everything.
    public static func filtered(_ items: [Item], kind: Kind?, query: String) -> [Item] {
        let words = searchWords(query)
        return items.filter { item in
            if let kind, item.kind != kind { return false }
            return matches(item.name, words: words)
        }
    }

    /// Whether `name` holds every word of `query`, ignoring case and accents.
    public static func matches(_ name: String, query: String) -> Bool {
        matches(name, words: searchWords(query))
    }

    /// The items in `sort`'s order. Ties go by name, then by id, so the order never depends on the
    /// order the items came in.
    public static func sorted(_ items: [Item], by sort: Sort) -> [Item] {
        items.sorted { a, b in
            switch sort {
            case .name:
                break
            case .duration:
                switch (a.duration, b.duration) {
                case let (x?, y?) where x != y: return x > y
                case (.some, nil): return true
                case (nil, .some): return false
                default: break
                }
            case .origin:
                if a.origin.rank != b.origin.rank { return a.origin.rank < b.origin.rank }
                let order = compareNames(a.origin.title, b.origin.title)
                if order != .orderedSame { return order == .orderedAscending }
            }
            let order = compareNames(a.name, b.name)
            if order != .orderedSame { return order == .orderedAscending }
            return a.id < b.id
        }
    }

    /// Filter, search and sort in one: what the browser shows.
    public static func shown(_ items: [Item], kind: Kind?, query: String, sort: Sort) -> [Item] {
        sorted(filtered(items, kind: kind, query: query), by: sort)
    }

    /// How many of `items` are of each kind, for the filter's labels.
    public static func counts(_ items: [Item]) -> [Kind: Int] {
        var counts: [Kind: Int] = [:]
        for item in items { counts[item.kind, default: 0] += 1 }
        return counts
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func searchWords(_ query: String) -> [String] {
        fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func matches(_ name: String, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let folded = fold(name)
        return words.allSatisfy { folded.contains($0) }
    }

    private static func compareNames(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
    }

    // MARK: - Placing a file of the open song

    /// Where a file can go.
    public enum Destination: Hashable, Sendable {
        /// An audio region on an audio track, starting at a tick.
        case track(TrackID, at: Tick)
        /// The sample of an instrument track, which then plays the sampler.
        case sampler(TrackID)
        /// The wavetable of an instrument track, which then plays the synth's Wavetable engine.
        case wavetable(TrackID)
        /// A video region at a tick, on a video track — or on a new one with nil.
        case video(TrackID?, at: Tick)
    }

    /// The places a file of `kind` can go in `project`, at `tick` where a place has a time: every
    /// audio track, then every instrument track's sampler and wavetable, for a sound; every video
    /// track and a new one, for a video; nowhere, for a picture, since a song holds none.
    public static func destinations(for kind: Kind, in project: Project, at tick: Tick) -> [Destination] {
        let start = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        switch kind {
        case .audio:
            let audio = project.tracks.filter { $0.kind == .audio }.map { Destination.track($0.id, at: start) }
            let instruments = project.tracks.filter { $0.kind == .instrument }
            return audio + instruments.map { .sampler($0.id) } + instruments.map { .wavetable($0.id) }
        case .video:
            return project.tracks.filter { $0.kind == .video }.map { .video($0.id, at: start) } + [.video(nil, at: start)]
        case .image:
            return []
        }
    }

    public enum PlacementError: Error, Equatable {
        /// The open song holds no file of this id.
        case notInSong
        /// The file is of a kind the destination does not take (a video into the sampler, a sound
        /// onto a video track).
        case wrongKind
        /// The destination track is not in the song, or not of the kind the destination needs.
        case noSuchTrack
    }

    /// The commands that put the open song's file `media` at `destination` — the same commands the
    /// imports send, without the `addMedia`, since the file is in the song already. One undo step
    /// when performed together. `newTrack` is the id a new video track takes.
    public static func commands(placing media: MediaID, on destination: Destination, in project: Project,
                                region: RegionID = RegionID(), newTrack: TrackID = TrackID()) throws -> [Command] {
        guard let file = project.mediaFile(media) else { throw PlacementError.notInSong }
        func track(_ id: TrackID, _ kind: TrackKind) throws {
            guard project.track(id)?.kind == kind else { throw PlacementError.noSuchTrack }
        }
        switch destination {
        case let .track(id, start):
            guard file.kind == .audio else { throw PlacementError.wrongKind }
            try track(id, .audio)
            return [.placeAudio(track: id, id: region, media: media, start: start)]
        case .sampler(let id):
            guard file.kind == .audio else { throw PlacementError.wrongKind }
            try track(id, .instrument)
            return [.setInstrumentDevice(id, .sampler), .setInstrumentSample(id, media)]
        case .wavetable(let id):
            guard file.kind == .audio else { throw PlacementError.wrongKind }
            try track(id, .instrument)
            return [.setInstrumentDevice(id, .synth),
                    .setInstrumentWavetable(id, WavetableSource(media: media, frames: WavetableSource.frames(for: file))),
                    .setInstrumentParameter(id, key: SynthParameter.engine.key.rawValue,
                                            value: Double(WavetableSource.engineIndex))]
        case let .video(id, start):
            guard file.kind == .video else { throw PlacementError.wrongKind }
            var commands: [Command] = []
            let target: TrackID
            if let id {
                try track(id, .video)
                target = id
            } else {
                target = newTrack
                let count = project.tracks.filter { $0.kind == .video }.count + 1
                commands.append(.addTrack(id: target, name: "Video \(count)", kind: .video, index: nil))
            }
            commands.append(.placeVideo(track: target, id: region, media: media, start: start))
            return commands
        }
    }
}
