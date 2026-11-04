import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelHost
import Foundation
import Observation
import UniformTypeIdentifiers

/// What the media browser reads from the device (Recovery 7): the files of the other songs in the
/// library and the files picked into the browser, both read off the main thread; and listening to
/// one of them through the engine's `PreviewPlayer`, decoded off the main and the render thread.
/// The open song's own files are not kept here — the browser reads them from the store, so an
/// edit shows at once. Local only: nothing here asks a network.
@MainActor
@Observable
final class MediaBrowserModel {
    /// The longest stretch of a file the browser decodes to listen to: half a minute is enough to
    /// judge a sound and costs at most a few megabytes, whatever the file's length.
    nonisolated static let listeningSeconds: Double = 30

    /// The files of the library's other songs and the imported ones, as last read.
    private(set) var items: [MediaBrowser.Item] = []
    private(set) var isLoading = false
    /// The item being heard, and the take the player knows it by.
    private(set) var listening: (id: String, take: UInt64)?
    /// Why the last action did nothing, in a sentence; nil when it worked.
    var message: String?

    /// What is known of an audio file's note.
    enum Pitch: Equatable {
        /// Not measured yet.
        case measuring
        /// Measured, and no note could be told: noise, a drum, a chord, a sweep.
        case none
        case note(SamplePitch.Reading)
    }

    /// The note of each audio item, by item id, as far as the index has come.
    private(set) var pitches: [String: Pitch] = [:]
    /// Every reading this run of the app has made, by file (path, size, date): the browser opens
    /// again without measuring again. The song stores none of it.
    private static var pitchCache: [String: SamplePitch.Reading?] = [:]
    @ObservationIgnored private var indexTask: Task<Void, Never>?
    @ObservationIgnored private var indexed: Set<String> = []

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var listenTask: Task<Void, Never>?

    /// Where files picked into the browser stay until the musician removes them: the app's own
    /// support folder, never a song package.
    nonisolated static var importFolder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Browser Imports", isDirectory: true)
    }

    // MARK: - Reading

    /// Reads the library's songs other than `current` and the imported files, off the main thread.
    func reload(songs: [ProjectLibrary.Entry], current: URL?) {
        loadTask?.cancel()
        isLoading = true
        let open = current?.standardizedFileURL.path
        let packages = songs.filter { $0.url.standardizedFileURL.path != open }.map { (url: $0.url, name: $0.name) }
        let folder = Self.importFolder
        loadTask = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) { () -> [MediaBrowser.Item] in
                var all: [MediaBrowser.Item] = []
                for package in packages {
                    if Task.isCancelled { return all }
                    let document = package.url.appendingPathComponent(ProjectLibrary.documentName)
                    guard let data = try? Data(contentsOf: document), let project = try? ProjectCodec.decode(data) else { continue }
                    all += MediaBrowser.items(of: project, origin: .library(song: package.name), package: package.url)
                }
                if let folder { all += await Self.importedItems(in: folder) }
                return all
            }.value
            guard let self, !Task.isCancelled else { return }
            self.items = found
            self.isLoading = false
        }
    }

    /// The files in the import folder that are a sound, a video or a picture, measured from their
    /// headers. A file nothing can read is listed without a length, never with one made up.
    nonisolated private static func importedItems(in folder: URL) async -> [MediaBrowser.Item] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        var items: [MediaBrowser.Item] = []
        for url in urls {
            guard let kind = kind(of: url) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            var duration: Double?
            var rate: Double?
            switch kind {
            case .audio:
                if let header = try? AudioFileImport.header(of: url), header.sampleRate > 0 {
                    duration = Double(header.frameCount) / header.sampleRate
                    rate = header.sampleRate
                }
            case .video:
                if let file = try? await VideoFileImport.describe(url, id: MediaID(), name: name, path: "Media/x") {
                    duration = file.duration
                }
            case .image:
                break
            }
            items.append(MediaBrowser.Item(id: "imported/\(url.lastPathComponent)", name: name, kind: kind,
                                           origin: .imported, location: url, duration: duration, sampleRate: rate))
        }
        return items
    }

    /// What a file is by its type: a sound, a video, a picture, or nothing the browser lists.
    nonisolated static func kind(of url: URL) -> MediaBrowser.Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .image) { return .image }
        return nil
    }

    // MARK: - Measuring the note

    /// One file to measure: the item, where it is, and its decoded buffer when the song holds one.
    struct PitchJob: Sendable {
        let id: String
        let url: URL?
        let loaded: SampleBuffer?
    }

    /// Measures the note of every audio file in `jobs` not measured yet, one after the other, off
    /// the main thread, and shows each as it comes. A file measured before — in this browser or an
    /// earlier one — is taken from the cache.
    func index(_ jobs: [PitchJob]) {
        let fresh = jobs.filter { !indexed.contains($0.id) }
        guard !fresh.isEmpty else { return }
        for job in fresh {
            indexed.insert(job.id)
            pitches[job.id] = .measuring
        }
        let previous = indexTask
        indexTask = Task { [weak self] in
            await previous?.value
            for job in fresh {
                guard !Task.isCancelled else { return }
                let known = MediaBrowserModel.pitchCache
                let result = await Task.detached(priority: .utility) { () -> (key: String?, reading: SamplePitch.Reading?) in
                    let key = job.url.flatMap { MediaBrowserModel.fileKey($0) }
                    if let key, let hit = known[key] { return (key, hit) }
                    let buffer = job.loaded ?? job.url.flatMap {
                        MediaBrowserModel.decodeOpening(of: $0, seconds: SamplePitch.analysedSeconds)
                    }
                    return (key, buffer.flatMap { SamplePitch.reading(of: $0) })
                }.value
                guard let self else { return }
                if let key = result.key { MediaBrowserModel.pitchCache[key] = .some(result.reading) }
                self.pitches[job.id] = result.reading.map { .note($0) } ?? Pitch.none
            }
        }
    }

    /// A file's identity for the cache: its path, size and date, so a changed file is measured again.
    nonisolated static func fileKey(_ url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        let date = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(url.standardizedFileURL.path)|\(size)|\(date)"
    }

    // MARK: - Importing into the browser

    /// Copies a picked file (the picker's own copy) into the import folder, then reads it.
    func importFile(_ source: URL, songs: [ProjectLibrary.Entry], current: URL?) {
        guard let folder = Self.importFolder else {
            message = "There is no place on this device to keep the file."
            return
        }
        guard Self.kind(of: source) != nil else {
            message = "This file is not a sound, a video or a picture."
            return
        }
        Task { [weak self] in
            let copied = await Task.detached(priority: .userInitiated) { () -> Bool in
                let fm = FileManager.default
                do {
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    try fm.copyItem(at: source, to: Self.freeName(for: source, in: folder))
                    return true
                } catch {
                    return false
                }
            }.value
            guard let self else { return }
            if copied {
                self.message = nil
                self.reload(songs: songs, current: current)
            } else {
                self.message = "Could not keep the file. Try again."
            }
        }
    }

    /// `source`'s name in `folder`, numbered when it is taken: "Kick.wav", "Kick 2.wav".
    nonisolated static func freeName(for source: URL, in folder: URL) -> URL {
        let ext = source.pathExtension
        let stem = source.deletingPathExtension().lastPathComponent
        let base = stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "File" : String(stem.prefix(Names.maximumLength))
        func named(_ text: String) -> URL {
            let url = folder.appendingPathComponent(text)
            return ext.isEmpty ? url : url.appendingPathExtension(ext)
        }
        var candidate = named(base)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = named("\(base) \(number)")
            number += 1
        }
        return candidate
    }

    /// Takes an imported file out of the browser: only its own copy, never a song's file.
    func remove(_ item: MediaBrowser.Item, songs: [ProjectLibrary.Entry], current: URL?) {
        guard item.origin == .imported, let url = item.location, let folder = Self.importFolder,
              url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path else { return }
        try? FileManager.default.removeItem(at: url)
        reload(songs: songs, current: current)
    }

    // MARK: - Listening

    /// Plays `item` through `player`: the decoded buffer the song already holds, or the first half
    /// minute of the file at `url`, decoded off the main thread first. A file already heard stops.
    func listen(_ item: MediaBrowser.Item, url: URL?, loaded: SampleBuffer?, player: PreviewPlayer) {
        if listening?.id == item.id, let take = listening?.take, player.isPlaying(take) {
            stopListening(player)
            return
        }
        listenTask?.cancel()
        guard item.canListen else { return }
        if let loaded {
            listening = (item.id, player.play(loaded))
            message = nil
            return
        }
        guard let url else {
            message = "This file is not on the device."
            return
        }
        player.stop()
        listening = nil
        let id = item.id
        listenTask = Task { [weak self] in
            let decoded = await Task.detached(priority: .userInitiated) { () -> SampleBuffer? in
                Self.decodeOpening(of: url, seconds: MediaBrowserModel.listeningSeconds)
            }.value
            guard let self, !Task.isCancelled else { return }
            guard let decoded else {
                self.message = "This file could not be read."
                return
            }
            self.listening = (id, player.play(decoded))
            self.message = nil
        }
    }

    func stopListening(_ player: PreviewPlayer) {
        listenTask?.cancel()
        player.stop()
        listening = nil
    }

    /// The first `seconds` of the file at `url`, both sides kept; nil when it is unreadable or the
    /// memory is not there.
    nonisolated private static func decodeOpening(of url: URL, seconds: Double) -> SampleBuffer? {
        guard let reader = try? SampleFile.Reader(url, maximumSeconds: .infinity) else { return nil }
        let room = Swift.min(reader.frameCount, Int((seconds * reader.sampleRate).rounded(.up)))
        guard room > 0 else { return nil }
        return try? SampleBuffer(capacity: room, channels: reader.keptChannels, sampleRate: reader.sampleRate,
                                 fill: { try reader.read(sidesInto: $0) })
    }
}
