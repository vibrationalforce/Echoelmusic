import EchoelCore
import EchoelDSP
import EchoelEngine
import Foundation
import Observation
import os

/// Which song is open and where it lives. Saves automatically: a short pause after the last
/// edit, and at once when the app leaves the foreground. There is no Save button to forget.
@MainActor
@Observable
final class DocumentController {
    private(set) var currentURL: URL?
    private(set) var songs: [ProjectLibrary.Entry] = []
    private(set) var lastError: String?
    private(set) var isExporting = false
    /// How loud the last WAV export came out, for the status line; nil before one.
    private(set) var lastExportLoudness: (integrated: Double, truePeak: Double)?
    private(set) var isImporting = false
    /// Changes whenever `samples` does; observe this, not the buffers.
    private(set) var mediaRevision = 0

    /// The open song's audio files, decoded, for the engine and the export. A file that is
    /// missing or unreadable is simply absent, and its track stays silent.
    @ObservationIgnored private(set) var samples: [MediaID: SampleBuffer] = [:]

    @ObservationIgnored private let library: ProjectLibrary
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var savedProject: Project?
    @ObservationIgnored private var mediaLoad: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "documents")

    /// Quiet time after an edit before the song is written.
    static let autosaveDelay: Duration = .seconds(2)

    init(store: ProjectStore, directory: URL = DocumentController.defaultDirectory) {
        self.store = store
        library = ProjectLibrary(directory: directory)
    }

    /// The app's Documents folder, which the Files app shows under the app's name.
    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Opens the most recent song, or starts a new one when there is none.
    func restore() {
        importEarlierSongs()
        refresh()
        if let latest = songs.first, open(latest.url) { return }
        newSong()
    }

    func newSong() {
        saveNow()
        let project = Project.starter()
        store.open(project)
        currentURL = library.newURL(for: project.name)
        savedProject = nil
        saveNow()
        loadMedia(of: project)
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        saveNow()
        do {
            let project = try library.read(url)
            store.open(project)
            currentURL = url
            savedProject = project
            lastError = nil
            loadMedia(of: project)
            return true
        } catch {
            log.error("open failed — \(error.localizedDescription, privacy: .public)")
            lastError = "Could not open \(url.deletingPathExtension().lastPathComponent)."
            return false
        }
    }

    /// Called on every project change: writes after a short pause.
    func projectChanged() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes the open song now if it changed since the last write.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let url = currentURL, store.project != savedProject else { return }
        let project = store.project
        do {
            try library.write(project, to: url)
            savedProject = project
            lastError = nil
            refresh()
        } catch {
            log.error("save failed — \(error.localizedDescription, privacy: .public)")
            lastError = "Could not save. Your changes are still open."
        }
    }

    /// Renders the open song to a 24-bit WAV in a temporary folder, off the main thread,
    /// and returns its URL for the share sheet. Plugins play from fresh copies loaded with the
    /// settings they have right now; one that cannot load is named in `lastError` and left out.
    func exportWAV(plugins: PluginHost) async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        defer { isExporting = false }
        let rate = 48_000.0
        try? store.perform(plugins.captureCommands(for: store.project), title: "Plugin Settings")
        let project = store.project
        let offline = await plugins.offlineUnits(for: project, sampleRate: rate)
        let buffers = samples
        let name = ProjectLibrary.safeFileName(for: project.name)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        let url = folder.appendingPathComponent(name).appendingPathExtension("wav")
        // Block by block into the file: a long song never sits in memory whole.
        // Measured on the way, as the file receives it (BS.1770 / EBU R 128).
        let result: Result<LoudnessMeter, Error> = await Task.detached(priority: .userInitiated) {
            Result {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let writer = try WAVWriter(url: url, sampleRate: rate)
                var meter = LoudnessMeter(sampleRate: rate)
                do {
                    _ = try OfflineRender.render(project, sampleRate: rate, samples: buffers, units: offline.units,
                                                 effects: offline.chains, masterEffects: offline.masterChain) { left, right, count in
                        try writer.append(left: left, right: right, count: count)
                        meter.process(left: left, right: right, count: count)
                    }
                    try writer.finish()
                } catch {
                    try? FileManager.default.removeItem(at: url)
                    throw error
                }
                return meter
            }
        }.value
        switch result {
        case .success(let meter):
            lastExportLoudness = (meter.integratedLoudness, meter.truePeak)
            lastError = offline.missing.isEmpty ? nil
                : "Exported without \(offline.missing.joined(separator: ", ")): not available on this device."
            return url
        case .failure(let error):
            log.error("export failed — \(error.localizedDescription, privacy: .public)")
            lastError = error as? WAVWriter.WriteError == .tooLong
                ? "The song is longer than a WAV file can hold (about six hours)."
                : "Could not export the song."
            return nil
        }
    }

    /// Writes the open song's notes as a Standard MIDI File in a temporary folder and returns its
    /// URL for the share sheet. Small and quick, so it runs here.
    func exportMIDI() -> URL? {
        let project = store.project
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        let url = folder.appendingPathComponent(ProjectLibrary.safeFileName(for: project.name)).appendingPathExtension("mid")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try MIDIFile.data(for: project).write(to: url, options: .atomic)
            lastError = nil
            return url
        } catch {
            log.error("MIDI export failed — \(error.localizedDescription, privacy: .public)")
            lastError = "Could not export the MIDI file."
            return nil
        }
    }

    /// Copies an audio file into the song and makes it `track`'s sample, switching the track
    /// to the sampler — one undo step.
    func importAudio(_ source: URL, onto track: TrackID) async {
        guard let file = await importMedia(source) else { return }
        perform([.addMedia(file), .setInstrumentDevice(track, .sampler), .setInstrumentSample(track, file.id)],
                title: "Import \(file.name)")
    }

    /// Copies an audio file into the song and places all of it on an audio track at `start` —
    /// one undo step.
    func importAudio(_ source: URL, placingOn track: TrackID, at start: Tick) async {
        guard let file = await importMedia(source) else { return }
        perform([.addMedia(file), .placeAudio(track: track, id: RegionID(), media: file.id, start: start)],
                title: "Import \(file.name)")
    }

    /// Copies an audio file into the song as a session clip of an audio track, looping over the
    /// nearest whole number of bars, in a scene's slot — one undo step.
    func importAudioClip(_ source: URL, onto track: TrackID, scene: SceneID) async {
        guard let file = await importMedia(source) else { return }
        let project = store.project
        let length = Arranging.loopLength(seconds: Double(file.frameCount) / file.sampleRate, bpm: project.tempo,
                                          signature: project.timeSignature)
        let clip = ClipID()
        perform([.addMedia(file),
                 .createAudioClip(track: track, id: clip, name: file.name, length: length,
                                  audio: ClipAudio(media: file.id, length: file.frameCount)),
                 .setSlot(track: track, scene: scene, clip: clip)],
                title: "Import \(file.name)")
    }

    /// Copies and decodes a file off the main thread and keeps its buffer, returning the file
    /// ready for `media.add`. Nil, with `lastError` set, when it cannot be read — or when
    /// another song was opened meanwhile.
    private func importMedia(_ source: URL) async -> MediaFile? {
        guard !isImporting, let package = currentURL else { return nil }
        isImporting = true
        defer { isImporting = false }
        let result: Result<AudioFileImport.Imported, Error> = await Task.detached(priority: .userInitiated) {
            // A file picked outside the app is readable only inside this scope.
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            return Result { try AudioFileImport.importFile(source, into: package) }
        }.value
        guard currentURL == package else { return nil }
        switch result {
        case .success(let imported):
            samples[imported.file.id] = imported.buffer
            mediaRevision += 1
            return imported.file
        case .failure(let error):
            log.error("import failed — \(error.localizedDescription, privacy: .public)")
            lastError = (error as? LocalizedError)?.errorDescription ?? "Could not import the file."
            return nil
        }
    }

    /// Where the next take is written: a fresh file in the open song's Media folder.
    struct TakeTarget: Sendable {
        let id: MediaID
        let path: String
        let url: URL
    }

    func newTakeTarget() -> TakeTarget? {
        guard let package = currentURL else { return nil }
        let id = MediaID()
        let path = "\(MediaFile.directory)/\(id).caf"
        guard let url = MediaFile(id: id, name: "Take", path: path, frameCount: 1, sampleRate: 1).url(in: package) else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            lastError = "Could not prepare the song's Media folder."
            return nil
        }
        return TakeTarget(id: id, path: path, url: url)
    }

    /// Turns a finished take into a region on `track`, lined up with the beat it was played to —
    /// one undo step. The take is decoded off the main thread like an imported file.
    /// `tempoMap` is the one the take was heard against — an external clock's while following one.
    func commitTake(_ take: RecordedTake, target: TakeTarget, onto track: TrackID, tempoMap: TempoMap) async {
        let package = currentURL
        let result: Result<SampleBuffer, Error> = await Task.detached(priority: .userInitiated) {
            Result { try AudioFileImport.decode(take.url) }
        }.value
        guard currentURL == package else { return }
        let buffer: SampleBuffer
        switch result {
        case .success(let decoded): buffer = decoded
        case .failure(let error):
            log.error("take unreadable — \(error.localizedDescription, privacy: .public)")
            lastError = (error as? LocalizedError)?.errorDescription ?? "The take could not be read."
            return
        }
        let time = TimeConversion(tempoMap: tempoMap, sampleRate: take.sampleRate)
        let placement = RecordingPlacement.place(startSample: take.startSample, latency: take.latency, time: time)
        guard buffer.frameCount > placement.offset else {
            try? FileManager.default.removeItem(at: take.url)
            return
        }
        samples[target.id] = buffer
        mediaRevision += 1
        let number = store.project.media.filter { $0.name.hasPrefix("Take ") }.count + 1
        let file = MediaFile(id: target.id, name: "Take \(number)", path: target.path,
                             frameCount: buffer.frameCount, sampleRate: buffer.sampleRate)
        let region = RegionID()
        var commands: [Command] = [
            .addMedia(file),
            .placeAudio(track: track, id: region, media: file.id, start: placement.start),
        ]
        if placement.offset > 0 {
            commands.append(.trimRegion(track: track, region, offset: placement.offset,
                                        length: buffer.frameCount - placement.offset))
        }
        perform(commands, title: "Record Take")
    }

    private func perform(_ commands: [Command], title: String) {
        do {
            try store.perform(commands, title: title)
            lastError = nil
        } catch {
            log.error("import rejected — \(String(describing: error), privacy: .public)")
            lastError = "Could not add the file to the song."
        }
    }

    /// Decodes every audio file of the song just opened, off the main thread. The previous
    /// song's buffers are dropped at once; the engine's snapshot keeps any it still plays.
    private func loadMedia(of project: Project) {
        mediaLoad?.cancel()
        samples = [:]
        mediaRevision += 1
        guard let package = currentURL, !project.media.isEmpty else { return }
        let files = project.media
        mediaLoad = Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                var decoded: [MediaID: SampleBuffer] = [:]
                for file in files {
                    guard let url = file.url(in: package),
                          let buffer = try? AudioFileImport.decode(url) else { continue }
                    decoded[file.id] = buffer
                }
                return decoded
            }.value
            guard let self, !Task.isCancelled, self.currentURL == package else { return }
            let missing = files.count - loaded.count
            if missing > 0 { self.log.error("media: \(missing, privacy: .public) file(s) missing or unreadable") }
            self.samples.merge(loaded) { current, _ in current }
            self.mediaRevision += 1
        }
    }

    func refresh() {
        songs = (try? library.list()) ?? []
    }

    // MARK: - Songs of the earlier app

    /// Once per install: the songs the earlier Echoelmusic app left in its App Group container —
    /// the one it had open and every one in its library — become songs here. Its files are only
    /// read, never changed or removed, and a song deleted here does not come back.
    private func importEarlierSongs() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.importedKey) else { return }
        let found = Self.earlierBases().lazy.compactMap { Self.earlierSongs(in: $0, defaults: defaults) }.first { !$0.isEmpty }
        var written = 0
        for project in found ?? [] {
            do {
                try library.write(project, to: library.newURL(for: project.name))
                written += 1
            } catch {
                log.error("import of an earlier song failed — \(error.localizedDescription, privacy: .public)")
            }
        }
        log.info("imported \(written, privacy: .public) song(s) from the earlier app")
        defaults.set(true, forKey: Self.importedKey)
    }

    private static let importedKey = "studio.importedEarlierSongs"

    /// Where the earlier app wrote: its App Group container, or Application Support when the
    /// container was unavailable.
    nonisolated static func earlierBases() -> [URL] {
        let fm = FileManager.default
        return [fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.echoelmusic"),
                fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first].compactMap { $0 }
    }

    /// The open song (`Timeline/timeline.json` + `Clips/clips.json`) and the library
    /// (`Echoel/projects.json.json`, the earlier store appended `.json` to a name ending in it),
    /// or nil when this base holds neither.
    nonisolated static func earlierSongs(in base: URL, defaults: UserDefaults) -> [Project]? {
        let timeline = try? Data(contentsOf: base.appendingPathComponent("Timeline/timeline.json"))
        let library = try? Data(contentsOf: base.appendingPathComponent("Echoel/projects.json.json"))
        guard timeline != nil || library != nil else { return nil }
        var songs: [Project] = []
        if let timeline {
            let clips = (try? Data(contentsOf: base.appendingPathComponent("Clips/clips.json"))) ?? Data("[]".utf8)
            // The earlier app kept no song tempo; its locked tempo is the one the song was made at.
            let tempo = defaults.bool(forKey: "studio.lockBPM") ? defaults.double(forKey: "studio.lockedBPM") : Tempo.defaultBPM
            if let song = try? LegacySong.project(timeline: timeline, clips: clips, tempo: tempo > 0 ? tempo : Tempo.defaultBPM,
                                                  name: "Earlier Song") {
                songs.append(song)
            }
        }
        if let library { songs += LegacySong.library(library) }
        return songs
    }
}
