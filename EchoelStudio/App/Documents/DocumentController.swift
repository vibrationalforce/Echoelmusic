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
    /// and returns its URL for the share sheet.
    func exportWAV() async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        defer { isExporting = false }
        let project = store.project
        let buffers = samples
        let name = ProjectLibrary.safeFileName(for: project.name)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        let url = folder.appendingPathComponent(name).appendingPathExtension("wav")
        let result: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            let render = OfflineRender.render(project, samples: buffers)
            let data = WAVFile.data(left: render.left, right: render.right, sampleRate: render.sampleRate)
            return Result {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            }
        }.value
        switch result {
        case .success:
            lastError = nil
            return url
        case .failure(let error):
            log.error("export failed — \(error.localizedDescription, privacy: .public)")
            lastError = "Could not export the song."
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
}
