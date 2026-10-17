import EchoelCore
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

    @ObservationIgnored private let library: ProjectLibrary
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var savedProject: Project?
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

    func refresh() {
        songs = (try? library.list()) ?? []
    }
}
