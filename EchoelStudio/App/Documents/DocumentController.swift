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
    /// How loud the open song's last WAV export came out, for the status line; nil before one.
    private(set) var lastExportLoudness: (integrated: Double, truePeak: Double)?
    /// The export just finished and nothing has played since. Then its loudness shows under a
    /// standing error or notice; an older one only when nothing else stands, so a message never
    /// hides the result of the export the user just made (review 2026-10-21).
    private(set) var lastExportIsNews = false
    /// What this launch has to say about the last one — a held song, an import given up, a song
    /// that did not open. Its own line under the messages: an autosave clears `lastError` and
    /// must not take this with it, and it hides nothing raised later. Play and opening another
    /// song clear it (review 2026-10-21).
    private(set) var launchNote: String?
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
    /// The open song is the starter a launch opened and has not been written yet, so nothing on
    /// disk holds its name.
    @ObservationIgnored private var isUnwritten = false
    /// The unwritten starter's package folder exists because an import or a take made it.
    @ObservationIgnored private var starterMadeFolder = false
    /// Counts song switches, so an export that finishes after another song opened does not
    /// report its loudness as that song's.
    @ObservationIgnored private var songsOpened = 0
    @ObservationIgnored private var mediaLoad: Task<Void, Never>?
    @ObservationIgnored private var isRestored = false
    @ObservationIgnored private var pendingIncoming: URL?
    @ObservationIgnored private var launch = LaunchRecord()
    @ObservationIgnored private var quarantine = SongQuarantine()
    @ObservationIgnored private var launchBegan: ContinuousClock.Instant?
    @ObservationIgnored private var launchCheck: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "documents")
    /// Runs before another song replaces the open one. The app sets it to write the plugins'
    /// current settings into the song, which they keep to themselves until asked; without it a
    /// built-in effect's tweaks since the app last left the foreground were lost on a switch.
    @ObservationIgnored var beforeLeavingSong: (() -> Void)?

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

    /// Opens the most recent song that opens, or starts a new one when there is none — or the
    /// song the app was opened with, when one came before this. When the last launch ended before
    /// it was confirmed healthy, a new song starts instead, and the song that launch was opening
    /// is held: no launch opens it by itself until it is chosen, so a song that kills the app at
    /// open cannot do it again on every second launch (ultra-audit R4, review 2026-10-20).
    func restore() {
        // Once per launch: a second window on iPad runs its own `.task` and must not reopen a song
        // or count a second launch.
        guard !isRestored else { return }
        let (previousDied, suspect) = beginLaunch()
        // The import is skipped once after such a launch, in case it was what died. When it was
        // running then, what happens to it next is said in the status line (review 2026-10-21).
        let importNote: String? = previousDied && UserDefaults.standard.bool(forKey: Self.importRunningKey)
            ? importAfterDeath() : nil
        if !previousDied { importEarlierSongs() }
        refresh()
        isRestored = true
        if let incoming = pendingIncoming {
            pendingIncoming = nil
            if open(incoming) {
                if let importNote { launchNote = "Echoel stopped last time while importing your earlier songs. " + importNote }
                return
            }
        }
        if previousDied {
            log.error("the last launch did not finish — starting a new song")
            startSong(writing: false)
            // Short enough for the status line: about three lines of caption on a phone in portrait.
            if let importNote {
                launchNote = "Echoel stopped last time while importing your earlier songs, so this is a new song. " + importNote
            } else {
                launchNote = suspect.map {
                    "Echoel did not finish starting last time, so this is a new song; \(Self.songName($0)) was open then and waits until you choose it."
                } ?? "Echoel did not finish starting last time, so this is a new song. Your songs are in the list."
            }
            return
        }
        // A song that does not open keeps its place and its name is shown; the newest song that
        // opens comes up instead, so a new empty song never becomes the newest over it (R8). A
        // held song is passed over the same way, and named.
        var unopened: (name: String, newer: Bool)?
        var held: String?
        for song in songs {
            if quarantine.holds(song.url.lastPathComponent) {
                if held == nil { held = song.url.deletingPathExtension().lastPathComponent }
                continue
            }
            do {
                try open(throwing: song.url)
                break
            } catch {
                if unopened == nil {
                    unopened = (name: song.url.deletingPathExtension().lastPathComponent, newer: Self.isNewer(error))
                }
            }
        }
        if currentURL == nil { startSong(writing: false) }
        if let unopened {
            launchNote = unopened.newer
                ? "\(unopened.name) was saved by a newer Echoel. It stays in your songs; update the app to open it."
                : "\(unopened.name) could not be opened. It stays in your songs."
        } else if let held {
            launchNote = "\(held) was open when Echoel stopped, so it does not open by itself. Choose it in your songs to open it."
        }
    }

    private static func songName(_ file: String) -> String {
        (file as NSString).deletingPathExtension
    }

    /// Called when the app goes to the background: a launch that got this far counts as healthy.
    func sceneLeft() {
        confirmLaunch(leaving: true)
    }

    private static let launchPendingKey = "studio.launch.pending"
    private static let launchOpeningKey = "studio.launch.opening"
    private static let launchHeldKey = "studio.launch.held"

    /// Whether the previous launch died, and the song it was opening then, which is now held.
    private func beginLaunch() -> (died: Bool, suspect: String?) {
        let defaults = UserDefaults.standard
        launch = LaunchRecord(isPending: defaults.bool(forKey: Self.launchPendingKey))
        quarantine = SongQuarantine(opening: defaults.string(forKey: Self.launchOpeningKey),
                                    held: defaults.stringArray(forKey: Self.launchHeldKey) ?? [])
        let previousDied = launch.begin()
        let suspect = quarantine.launchBegan(previousDied: previousDied)
        defaults.set(launch.isPending, forKey: Self.launchPendingKey)
        keepQuarantine()
        launchBegan = .now
        launchCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(LaunchRecord.steadySeconds))
            guard !Task.isCancelled else { return }
            self?.confirmLaunch(leaving: false)
        }
        return (previousDied, suspect)
    }

    private func keepQuarantine() {
        let defaults = UserDefaults.standard
        defaults.set(quarantine.opening, forKey: Self.launchOpeningKey)
        defaults.set(quarantine.held, forKey: Self.launchHeldKey)
    }

    /// Before a song is read while the launch is not confirmed: if the launch dies now, the next
    /// one knows which song it was. Nil for a new song.
    private func noteOpening(_ name: String?) {
        guard launch.isPending else { return }
        quarantine.willOpen(name)
        keepQuarantine()
    }

    /// A new song was just written under a held song's name — the held one was deleted, and
    /// `newURL` gave its name out again. The hold was for the song that crashed, not for the name.
    private func releaseHold(on url: URL) {
        guard quarantine.holds(url.lastPathComponent) else { return }
        quarantine.chosen(url.lastPathComponent)
        keepQuarantine()
    }

    private func confirmLaunch(leaving: Bool) {
        guard let began = launchBegan else { return }
        let elapsed = began.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18
        guard launch.confirm(after: seconds, leaving: leaving) else { return }
        UserDefaults.standard.set(false, forKey: Self.launchPendingKey)
        quarantine.launchConfirmed()
        keepQuarantine()
        launchCheck?.cancel()
        launchCheck = nil
    }

    private static func isNewer(_ error: Error) -> Bool {
        if case ProjectCodec.DecodeError.newerFormat = error { return true }
        return false
    }

    /// A song handed to the app — tapped in Files, sent by AirDrop, shared from another app. It
    /// joins the library first (`ProjectLibrary.adopt`; one already there opens in place), so the
    /// library stays the one place a song is saved. Arriving before `restore`, it waits for it.
    func openIncoming(_ url: URL) {
        guard url.isFileURL else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            // The song that came in may take the unwritten starter's name; the starter moves to
            // another before anything is written (`starterKeepsItsOwnPackage`).
            let local = try library.adopt(url)
            refresh()
            if isRestored { open(local) } else { pendingIncoming = local }
        } catch {
            log.error("incoming song refused — \(error.localizedDescription, privacy: .public)")
            lastError = "Could not open \(url.deletingPathExtension().lastPathComponent)."
        }
    }

    func newSong() {
        startSong(writing: true)
    }

    /// A new song from the starter. `writing: false` keeps it off the disk until its first edit:
    /// the starter the launch opens in place of a song must not become the newest song over the
    /// user's — after a false alarm the next healthy launch would open it instead (R8).
    private func startSong(writing: Bool) {
        beforeLeavingSong?()
        saveNow()
        noteOpening(nil)
        let project = Project.starter()
        store.open(project)
        currentURL = library.newURL(for: project.name)
        anotherSongOpened()
        savedProject = writing ? nil : project
        isUnwritten = !writing
        starterMadeFolder = false
        saveNow()
        loadMedia(of: project)
    }

    /// A song chosen by hand, or handed to the app. A held song opens again at launch from now on.
    @discardableResult
    func open(_ url: URL) -> Bool {
        do {
            try open(throwing: url)
            if quarantine.holds(url.lastPathComponent) {
                quarantine.chosen(url.lastPathComponent)
                keepQuarantine()
            }
            return true
        } catch {
            lastError = Self.isNewer(error)
                ? "\(url.deletingPathExtension().lastPathComponent) was saved by a newer Echoel. Update the app to open it."
                : "Could not open \(url.deletingPathExtension().lastPathComponent)."
            return false
        }
    }

    private func open(throwing url: URL) throws {
        beforeLeavingSong?()
        saveNow()
        noteOpening(url.lastPathComponent)
        do {
            let project = try library.read(url)
            store.open(project)
            currentURL = url
            anotherSongOpened()
            savedProject = project
            isUnwritten = false
            starterMadeFolder = false
            lastError = nil
            loadMedia(of: project)
        } catch {
            log.error("open failed — \(error.localizedDescription, privacy: .public)")
            throw error
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

    /// The unwritten starter's name was free when it was picked, and a song may have arrived
    /// under it since: by AirDrop, or copied in with the Files app, which sees no clash while
    /// nothing is on disk. Before anything writes into the starter's package, the starter moves to
    /// a free name, instead of writing over that song's document (review 2026-10-21).
    /// A folder the starter did not make counts as taken too: a copy still under way has its
    /// folder before its document (review 2026-10-21).
    private func starterKeepsItsOwnPackage() {
        guard isUnwritten, let url = currentURL else { return }
        let fm = FileManager.default
        let taken = fm.fileExists(atPath: url.appendingPathComponent(ProjectLibrary.documentName).path)
            || (!starterMadeFolder && fm.fileExists(atPath: url.path))
        guard taken else { return }
        currentURL = library.newURL(for: store.project.name)
        starterMadeFolder = false
        log.info("the starter's name was taken meanwhile; it moves to another")
    }

    /// Writes the open song now if it changed since the last write.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard currentURL != nil, store.project != savedProject else { return }
        starterKeepsItsOwnPackage()
        guard let url = currentURL else { return }
        let project = store.project
        let isNew = !FileManager.default.fileExists(atPath: url.appendingPathComponent(ProjectLibrary.documentName).path)
        do {
            try library.write(project, to: url)
            savedProject = project
            isUnwritten = false
            lastError = nil
            if isNew { releaseHold(on: url) }
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
        let exportedSong = songsOpened
        try? store.absorb(plugins.captureCommands(for: store.project))
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
            if exportedSong == songsOpened {
                lastExportLoudness = (meter.integratedLoudness, meter.truePeak)
                lastExportIsNews = true
            }
            lastError = offline.missing.isEmpty ? nil
                : "Exported without \(offline.missing.joined(separator: ", ")): not available on this device."
            return url
        case .failure(let error):
            log.error("export failed — \(error.localizedDescription, privacy: .public)")
            // The loudness of an earlier export must not stand under this failure as its result.
            lastExportIsNews = false
            lastError = error as? WAVWriter.WriteError == .tooLong
                ? "The song is longer than a WAV file can hold (about six hours)."
                : "Could not export the song."
            return nil
        }
    }

    /// Play started a fresh status line: the launch note goes, and the last export's loudness is
    /// no longer news.
    func playStarted() {
        launchNote = nil
        lastExportIsNews = false
    }

    /// Another song is open: the loudness line and the launch note spoke of the one before it.
    private func anotherSongOpened() {
        songsOpened &+= 1
        launchNote = nil
        lastExportLoudness = nil
        lastExportIsNews = false
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
        starterKeepsItsOwnPackage()
        guard !isImporting, let package = currentURL else { return nil }
        if isUnwritten { starterMadeFolder = true }   // the import below makes it
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
        starterKeepsItsOwnPackage()
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
        if isUnwritten { starterMadeFolder = true }
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

    /// Once per install, on the first launch that can read them: the songs the earlier Echoelmusic
    /// app left in its App Group container — the one it had open and every one in its library —
    /// become songs here. Its files are only read, never changed or removed, and a song deleted
    /// here does not come back.
    private func importEarlierSongs() {
        guard !UserDefaults.standard.bool(forKey: Self.importedKey) else { return }
        // Written before, cleared after: a launch that dies inside the import leaves it set.
        UserDefaults.standard.set(true, forKey: Self.importRunningKey)
        let destination = library
        let logger = log
        Task { [weak self] in
            // Off the main thread: reading and converting a long library at launch must not hold
            // it, or the system ends the app and the import counts as what died (review 2026-10-21).
            let written = await Task.detached(priority: .utility) {
                DocumentController.runImport(into: destination, log: logger)
            }.value
            guard let self else { return }
            for url in written { self.releaseHold(on: url) }
            self.refresh()
            if !written.isEmpty, self.launchNote == nil {
                self.launchNote = written.count == 1
                    ? "One song from the earlier Echoelmusic is now in your songs."
                    : "\(written.count) songs from the earlier Echoelmusic are now in your songs."
            }
        }
    }

    /// Brings over the songs not written yet and returns where they went. Each one is recorded the
    /// moment it is written, and the one under way is noted before it is read, so a launch that
    /// ends in the middle loses nothing already brought over and knows which song it was on.
    nonisolated private static func runImport(into library: ProjectLibrary, log: Logger) -> [URL] {
        let defaults = UserDefaults.standard
        defer {
            defaults.removeObject(forKey: importCurrentKey)
            defaults.removeObject(forKey: importRunningKey)
        }
        // Nothing found is not done: without the App Group the earlier app's container is out of
        // reach, and a later build that has it must still look.
        guard let songs = earlierBases().lazy.compactMap({ earlierSongs(in: $0, defaults: defaults) })
            .first(where: { $0.count > 0 }) else { return [] }
        // Every run counts, also one that dies: a song that ends the app cannot make every
        // second launch die for ever.
        let attempts = defaults.integer(forKey: importAttemptsKey) + 1
        defaults.set(attempts, forKey: importAttemptsKey)
        guard attempts <= importAttemptLimit else {
            log.error("the import of earlier songs stopped after \(importAttemptLimit, privacy: .public) runs")
            finishImport(defaults)
            return []
        }
        // The songs already written by an earlier run, by their place in the earlier app's files
        // (which are never changed, so the places hold): a retry never writes one twice.
        var done = Set(defaults.array(forKey: importedRowsKey) as? [Int] ?? [])
        var failed = 0
        var written: [URL] = []
        for index in 0..<songs.count where !done.contains(index) {
            defaults.set(index, forKey: importCurrentKey)
            // An unreadable song is left out, as the earlier app's own reader would.
            if let project = songs.project(at: index) {
                do {
                    let url = try reservePackage(for: project.name, in: library)
                    do {
                        try library.write(project, to: url)
                    } catch {
                        try? FileManager.default.removeItem(at: url)
                        throw error
                    }
                    written.append(url)
                } catch {
                    failed += 1
                    log.error("import of an earlier song failed — \(error.localizedDescription, privacy: .public)")
                    continue
                }
            }
            done.insert(index)
            defaults.set(done.sorted(), forKey: importedRowsKey)
        }
        log.info("imported \(written.count, privacy: .public) song(s) from the earlier app, \(failed, privacy: .public) failed")
        // A failure (a full disk, a locked container) is retried on the next launches, a few times.
        if LegacySong.importIsFinished(foundSongs: true, failures: failed, attempts: attempts,
                                       attemptLimit: importAttemptLimit) {
            finishImport(defaults)
        }
        return written
    }

    /// A free package for an imported song, made here and now. Made at once, not only named: the
    /// open song may be the starter, which takes its own name only on its first save — it then
    /// sees this folder and moves, instead of the two writing into one package.
    nonisolated private static func reservePackage(for name: String, in library: ProjectLibrary) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: library.directory, withIntermediateDirectories: true)
        var url = library.newURL(for: name)
        for _ in 0..<100 {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: false)
                return url
            } catch {
                guard fm.fileExists(atPath: url.path) else { throw error }
                url = library.newURL(for: name)
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }

    nonisolated private static func finishImport(_ defaults: UserDefaults) {
        defaults.set(true, forKey: importedKey)
        defaults.removeObject(forKey: importedRowsKey)
        defaults.removeObject(forKey: importAttemptsKey)
        defaults.removeObject(forKey: importSuspectKey)
        defaults.removeObject(forKey: importCurrentKey)
    }

    /// `.v2` since 2026-10-19: builds 10004–10006 ran without the App Group, found nothing and
    /// still marked the import done under the old name, so a device that ran them would never
    /// import once the group is back. The new name lets every such device look once more.
    nonisolated private static let importedKey = "studio.importedEarlierSongs.v2"
    /// The places written, by row of the earlier app's files (a new name since 2026-10-21: the
    /// old one counted only the songs that could be read, so its places could shift).
    nonisolated private static let importedRowsKey = "studio.importedEarlierSongRows"
    nonisolated private static let importAttemptsKey = "studio.earlierSongImportAttempts"
    nonisolated private static let importAttemptLimit = 3
    nonisolated private static let importRunningKey = "studio.earlierSongImportRunning"
    /// The row being brought over right now.
    nonisolated private static let importCurrentKey = "studio.earlierSongImportCurrent"
    /// The row a launch died on once already: dying on it again leaves it out.
    nonisolated private static let importSuspectKey = "studio.earlierSongImportSuspect"

    private static let importGivenUp = "It will not run again; what it brought over is in your songs."

    /// The import was running when the last launch died; returns the status line's end. It goes
    /// on at the next start, past what it wrote. A song under way when a launch died a second time
    /// is left out, since it may be what died; one under way only once is tried again, because a
    /// launch also ends when the app is swiped away. A launch that died before any song was under
    /// way — while the earlier app's files were read — gives the import up: tried again, it would
    /// end every second launch. The earlier app's files are only ever read, so nothing of them is lost.
    private func importAfterDeath() -> String {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.importRunningKey)
        // Its last run died: there is no next one to promise.
        guard let underway = defaults.object(forKey: Self.importCurrentKey) as? Int,
              defaults.integer(forKey: Self.importAttemptsKey) < Self.importAttemptLimit else {
            log.error("the import of earlier songs died while reading them, or on its last run — not trying it again")
            Self.finishImport(defaults)
            return Self.importGivenUp
        }
        defaults.removeObject(forKey: Self.importCurrentKey)
        guard defaults.object(forKey: Self.importSuspectKey) as? Int == underway else {
            defaults.set(underway, forKey: Self.importSuspectKey)
            return "It goes on at the next start; what it brought over is in your songs."
        }
        log.error("the import of earlier songs died twice on the same song — leaving it out")
        var done = Set(defaults.array(forKey: Self.importedRowsKey) as? [Int] ?? [])
        done.insert(underway)
        defaults.set(done.sorted(), forKey: Self.importedRowsKey)
        defaults.removeObject(forKey: Self.importSuspectKey)
        return "The song it was bringing over then is left out; the others follow at the next start."
    }

    /// Where the earlier app wrote: its App Group container, or Application Support when the
    /// container was unavailable.
    nonisolated static func earlierBases() -> [URL] {
        let fm = FileManager.default
        return [fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.echoelmusic"),
                fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first].compactMap { $0 }
    }

    /// The open song (`Timeline/timeline.json` + `Clips/clips.json`) and the library
    /// (`Echoel/projects.json.json`, the earlier store appended `.json` to a name ending in it),
    /// read but not converted, or nil when this base holds neither.
    nonisolated static func earlierSongs(in base: URL, defaults: UserDefaults) -> EarlierSongs? {
        let timeline = try? Data(contentsOf: base.appendingPathComponent("Timeline/timeline.json"))
        let library = try? Data(contentsOf: base.appendingPathComponent("Echoel/projects.json.json"))
        guard timeline != nil || library != nil else { return nil }
        let clips = (try? Data(contentsOf: base.appendingPathComponent("Clips/clips.json"))) ?? Data("[]".utf8)
        // The earlier app kept no song tempo; its locked tempo is the one the song was made at.
        let tempo = defaults.bool(forKey: "studio.lockBPM") ? defaults.double(forKey: "studio.lockedBPM") : Tempo.defaultBPM
        return EarlierSongs(timeline: timeline, clips: clips, tempo: tempo > 0 ? tempo : Tempo.defaultBPM,
                            library: library.map(LegacySong.libraryRows) ?? LegacySong.libraryRows(Data()))
    }
}

/// The earlier app's songs, read but not converted: its open song first, then its library, each
/// in a fixed place, so the import can bring them over one at a time.
struct EarlierSongs: Sendable {
    let timeline: Data?
    let clips: Data
    let tempo: Double
    let library: LegacySong.Library

    var count: Int { (timeline == nil ? 0 : 1) + library.count }

    /// The song in place `index`, or nil when it cannot be read.
    func project(at index: Int) -> Project? {
        guard let timeline else { return library.project(at: index) }
        guard index == 0 else { return library.project(at: index - 1) }
        return try? LegacySong.project(timeline: timeline, clips: clips, tempo: tempo, name: "Earlier Song")
    }
}
