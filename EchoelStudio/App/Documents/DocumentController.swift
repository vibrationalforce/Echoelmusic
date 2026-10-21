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
    /// The open song is the starter a launch opened and has not been written yet, so nothing on
    /// disk holds its name.
    @ObservationIgnored private var isUnwritten = false
    /// The unwritten starter's package folder exists because an import or a take made it.
    @ObservationIgnored private var starterMadeFolder = false
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
        // running then, it is given up: tried again, it would kill every second launch. Said in
        // the status line, since nothing in the app starts it again (review 2026-10-21).
        let gaveUpImport = previousDied && UserDefaults.standard.bool(forKey: Self.importRunningKey)
        if gaveUpImport { giveUpImport() }
        if !previousDied { importEarlierSongs() }
        refresh()
        isRestored = true
        if let incoming = pendingIncoming {
            pendingIncoming = nil
            if open(incoming) {
                if gaveUpImport { lastError = "Echoel stopped last time while importing your earlier songs. " + Self.importGivenUp }
                return
            }
        }
        if previousDied {
            log.error("the last launch did not finish — starting a new song")
            startSong(writing: false)
            // Short enough for the status line: about three lines of caption on a phone in portrait.
            if gaveUpImport {
                lastError = "Echoel stopped last time while importing your earlier songs, so this is a new song. " + Self.importGivenUp
            } else {
                lastError = suspect.map {
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
            lastError = unopened.newer
                ? "\(unopened.name) was saved by a newer Echoel. It stays in your songs; update the app to open it."
                : "\(unopened.name) could not be opened. It stays in your songs."
        } else if let held {
            lastError = "\(held) was open when Echoel stopped, so it does not open by itself. Choose it in your songs to open it."
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
            // Only a failed save's own message goes: a launch message (a held song, a given-up
            // import) must outlive the first autosave after it (review 2026-10-21).
            if lastError == Self.saveFailed { lastError = nil }
            if isNew { releaseHold(on: url) }
            refresh()
        } catch {
            log.error("save failed — \(error.localizedDescription, privacy: .public)")
            lastError = Self.saveFailed
        }
    }

    private static let saveFailed = "Could not save. Your changes are still open."

    /// Renders the open song to a 24-bit WAV in a temporary folder, off the main thread,
    /// and returns its URL for the share sheet. Plugins play from fresh copies loaded with the
    /// settings they have right now; one that cannot load is named in `lastError` and left out.
    func exportWAV(plugins: PluginHost) async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        defer { isExporting = false }
        let rate = 48_000.0
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
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.importedKey) else { return }
        // Written before, cleared after: a launch that dies inside the import leaves it set.
        defaults.set(true, forKey: Self.importRunningKey)
        defer { defaults.removeObject(forKey: Self.importRunningKey) }
        let found = Self.earlierBases().lazy.compactMap { Self.earlierSongs(in: $0, defaults: defaults) }.first { !$0.isEmpty }
        let songs = found ?? []
        // The songs already written by an earlier attempt, by their place in the earlier app's
        // list (its files are never changed, so the order holds): a retry never writes one twice.
        var done = Set(defaults.array(forKey: Self.importedIndicesKey) as? [Int] ?? [])
        var failed = 0
        for (index, project) in songs.enumerated() where !done.contains(index) {
            do {
                let url = library.newURL(for: project.name)
                try library.write(project, to: url)
                releaseHold(on: url)
                done.insert(index)
            } catch {
                failed += 1
                log.error("import of an earlier song failed — \(error.localizedDescription, privacy: .public)")
            }
        }
        if found != nil {
            log.info("imported \(done.count, privacy: .public) of \(songs.count, privacy: .public) song(s) from the earlier app")
        }
        // A failure (a full disk, a locked container) is retried on the next launches, a few times.
        // Nothing found is not done: without the App Group the earlier app's container is out of
        // reach, and a later build that has it must still look.
        let attempts = defaults.integer(forKey: Self.importAttemptsKey) + 1
        if LegacySong.importIsFinished(foundSongs: found != nil, failures: failed, attempts: attempts,
                                       attemptLimit: Self.importAttemptLimit) {
            defaults.set(true, forKey: Self.importedKey)
            defaults.removeObject(forKey: Self.importedIndicesKey)
            defaults.removeObject(forKey: Self.importAttemptsKey)
        } else if found != nil {
            defaults.set(done.sorted(), forKey: Self.importedIndicesKey)
            defaults.set(attempts, forKey: Self.importAttemptsKey)
        }
    }

    /// `.v2` since 2026-10-19: builds 10004–10006 ran without the App Group, found nothing and
    /// still marked the import done under the old name, so a device that ran them would never
    /// import once the group is back. The new name lets every such device look once more.
    private static let importedKey = "studio.importedEarlierSongs.v2"
    private static let importedIndicesKey = "studio.importedEarlierSongIndices"
    private static let importAttemptsKey = "studio.earlierSongImportAttempts"
    private static let importAttemptLimit = 3
    private static let importRunningKey = "studio.earlierSongImportRunning"

    private static let importGivenUp = "It will not run again; what it brought over is in your songs."

    /// The import was running when a launch died: it is not tried again. The earlier app's files
    /// are only ever read, so nothing of them is lost.
    private func giveUpImport() {
        log.error("the import of earlier songs was running when the last launch died — not trying it again")
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.importedKey)
        defaults.removeObject(forKey: Self.importedIndicesKey)
        defaults.removeObject(forKey: Self.importAttemptsKey)
        defaults.removeObject(forKey: Self.importRunningKey)
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
