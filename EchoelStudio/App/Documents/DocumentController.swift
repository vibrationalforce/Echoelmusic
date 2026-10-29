import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelKernels
import Foundation
import Observation
import os
#if canImport(UIKit)
import UIKit
#endif

/// Which song is open and where it lives. Saves automatically: a short pause after the last
/// edit, and at once when the app leaves the foreground. There is no Save button to forget.
@MainActor
@Observable
final class DocumentController {
    private(set) var currentURL: URL?
    private(set) var songs: [ProjectLibrary.Entry] = []
    private(set) var lastError: String?
    /// The open song has changes that could not be written. Its own line, which only a write
    /// clears: an export or an open that went well says nothing about the song on disk, and
    /// clearing this with `lastError` hid the one message about losing work (review 2026-10-22).
    private(set) var saveError: String?
    private(set) var isExporting = false
    /// Which step of a running export is under way, for the status line; nil when it has only one.
    private(set) var exportProgress: String?
    /// How loud the open song's last WAV export came out, for the status line; nil before one.
    private(set) var lastExportLoudness: (integrated: Double, truePeak: Double)?
    /// The export just finished and nothing has played since. Then its loudness shows under a
    /// standing error or notice; an older one only when nothing else stands, so a message never
    /// hides the result of the export the user just made (review 2026-10-21).
    private(set) var lastExportIsNews = false
    /// What this launch has to say about the last one — a held song, a song that did not open;
    /// what became of the import is `earlierSongsWarning`. Its own line under the messages, so
    /// clearing one does not take it along and it hides nothing raised later. Play and opening
    /// another song clear it (review 2026-10-21).
    private(set) var launchNote: String?
    /// The import of the earlier app's songs brought some over in this launch. Its own line, in
    /// the quiet colour: it is news, not a warning, and no message hides it. Play and opening
    /// another song clear it (review 2026-10-21).
    private(set) var earlierSongsNote: String?
    /// Earlier songs that could not be saved, could not be read, or were left out, and whether
    /// they are tried again: a warning, so it stands in the record colour, beside the news and not
    /// inside it. It stays true after a Play or another song, so only the musician hides it
    /// (`hideEarlierSongsWarning`) — or, for the songs a run could not save, a later run that
    /// brings everything over (round 4, C4).
    var earlierSongsWarning: String? {
        var lines = importLaunchWarning.map { [$0] } ?? []
        if importLeftOut > 0 {
            lines.append(importLeftOut == 1
                ? "One earlier song could not be read, so it is left out."
                : "\(importLeftOut) earlier songs could not be read, so they are left out.")
        }
        if !importUnsaved.isEmpty {
            let shown = importUnsaved.prefix(3).map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
            let more = importUnsaved.count > 3 ? " and \(importUnsaved.count - 3) more" : ""
            let songs = importUnsaved.count == 1 ? "The earlier song \(shown) could" : "The earlier songs \(shown)\(more) could"
            lines.append("\(songs) not be saved here; Echoel tries again \(importRetriesOnReturn ? "once Echoel is back in front" : "at the next start").")
        }
        return lines.isEmpty ? nil : (lines + [Self.earlierFilesKept]).joined(separator: " ")
    }
    /// What became of a run the last launch ended in the middle of: a song left out, or the
    /// import given up. No later run makes it untrue.
    private var importLaunchWarning: String?
    /// Songs the runs of this launch could not read. Each is left out for good, so no later run
    /// takes the count back (review 2026-10-22).
    private var importLeftOut = 0
    /// The names of the songs that could not be saved, as of the last run that went through every
    /// place; a paused run adds to them, since it may not have reached the others.
    private var importUnsaved: [String] = []
    /// The last run paused, so the unsaved songs are tried again once the app is back in front.
    private var importRetriesOnReturn = false
    private(set) var isImporting = false
    /// Changes whenever `samples` does; observe this, not the buffers.
    private(set) var mediaRevision = 0

    /// The open song's audio files, decoded, for the engine and the export. A file that is
    /// missing or unreadable is simply absent, and its track stays silent.
    @ObservationIgnored private(set) var samples: [MediaID: SampleBuffer] = [:]
    /// The open song's audio files that were not loaded, and why: an export names them for what
    /// they are, not as missing.
    @ObservationIgnored private var unfitMedia: [MediaID: NotLoaded] = [:]

    /// Why an audio file of the open song was not loaded. A file the free memory could not take
    /// at the open is not a song too large for the device: said as the song being too large, it
    /// steered the musician to delete audio the next open loads (seventh night review, 2026-10-23).
    private enum NotLoaded {
        /// Past the song's memory budget (`AudioFileImport.songBudgetBytes`).
        case overBudget
        /// The memory was not free when the file was loaded — at the open, or for a take.
        case noFreeMemory
    }

    @ObservationIgnored private let library: ProjectLibrary
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    /// When the oldest change the disk does not hold yet arrived (`autosaveLongest`).
    @ObservationIgnored private var firstUnsavedChange: ContinuousClock.Instant?
    @ObservationIgnored private var savedProject: Project?
    /// The open song is the starter a launch opened and has not been written yet, so nothing on
    /// disk holds its name.
    @ObservationIgnored private var isUnwritten = false
    /// The package folder at `currentURL` exists because an import or a take made it, while
    /// nothing of the open song is written there yet: the unwritten starter's, or the free name a
    /// song waits at (`awaitsFirstWriteAtFreeName`). Any other folder there is another song's — a
    /// copy still under way has its folder before its document (fourth night review, 2026-10-23).
    @ObservationIgnored private var starterMadeFolder = false
    /// The open song's package as the disk knows it, taken when it is read or written, so a
    /// rename in the Files app while it is open is followed (`followMovedPackage`).
    @ObservationIgnored private var packageIdentity: ProjectLibrary.PackageIdentity?
    /// The name the open song had when its package was found gone and another song's under that
    /// name, until a write tells the musician (second night review, 2026-10-23).
    @ObservationIgnored private var nameTakenFrom: String?
    /// The identity the open song's package had before its name was taken, so the package is
    /// recognised if it comes back into the library while the song waits at a free name.
    @ObservationIgnored private var formerIdentity: ProjectLibrary.PackageIdentity?
    /// The name that package followed (`fileName`) when the song left it: a rename while the song
    /// waits at a free name moves only the free name, so the package that comes back still takes
    /// the song's name at the next write (sixth night review, 2026-10-23).
    @ObservationIgnored private var formerFileName = SongFileName()
    /// The free-name folder a take or an import of the open song still writes into, after the
    /// song's own package came back and everything else there moved in (`gather`): its last files
    /// move in when that work lands (`settleLeftBehind`).
    @ObservationIgnored private var leftBehind: URL?
    /// The import copying into the package right now, so a gather leaves its file to the import.
    @ObservationIgnored private var importingMedia: MediaID?
    /// The open song was sent to a free name and is not written there yet, so nothing at its path
    /// is its own but a folder a take or an import made: a song that arrived there meanwhile —
    /// received, brought back by the earlier-songs import, renamed to that name in Files — is
    /// another song, never written over (third night review, 2026-10-23).
    private var awaitsFirstWriteAtFreeName: Bool { !isUnwritten && packageIdentity == nil && nameTakenFrom != nil }
    /// Counts song switches, so an export that finishes after another song opened does not
    /// report its loudness as that song's, and a sheet opened for one song closes when another
    /// opens.
    private(set) var songsOpened = 0
    @ObservationIgnored private var mediaLoad: Task<Void, Never>?
    /// The open song's audio files are being decoded from its package.
    private var isLoadingMedia = false
    /// The takes being written into the package, each from `newTakeTarget` until it is committed
    /// or given up (`takeAbandoned`). One per take: a take that ends while the next one starts
    /// must not free the package from under the other (review 006, round 1).
    private var takesInFlight: Set<MediaID> = []
    /// Who waits for the last take in flight to land (`takesSettled`).
    @ObservationIgnored private var takeWaiters: [CheckedContinuation<Void, Never>] = []
    /// The name the package follows: a renamed song moves its package to match, once nothing
    /// reads or writes into it.
    @ObservationIgnored private var fileName = SongFileName()
    /// The line a failed move added to `lastError`. The move is tried again at every write; the
    /// line is said once, and goes as soon as nothing is owed any more.
    @ObservationIgnored private var failedMoveLine: String?
    @ObservationIgnored private var isRestored = false
    @ObservationIgnored private var pendingIncoming: URL?
    @ObservationIgnored private var launch = LaunchRecord()
    @ObservationIgnored private var quarantine = SongQuarantine()
    @ObservationIgnored private var launchBegan: ContinuousClock.Instant?
    @ObservationIgnored private var launchCheck: Task<Void, Never>?
    /// Confirms the launch once the app has left the foreground, or stopped being active, and the
    /// song open then is loaded.
    @ObservationIgnored private var launchLeave: Task<Void, Never>?
    /// The run of the earlier songs' import in flight; leaving the foreground cancels it, and it
    /// then pauses between two songs.
    @ObservationIgnored private var importRun: Task<Void, Never>?
    /// The wait before a paused or not yet started import starts once the app is back in front.
    @ObservationIgnored private var importWait: Task<Void, Never>?
    /// A run of the import ended (not paused) in this process; the next one is at the next start.
    @ObservationIgnored private var importRanThisLaunch = false
    /// Songs the import brought over in this process, for the status line.
    @ObservationIgnored private var earlierSongsWritten = 0
    /// The app is in the background: from `sceneLeft` until `sceneEntered`. A launch starts in
    /// front, so this starts false.
    @ObservationIgnored private var isInBackground = false
    /// The app is in front but not active — the app switcher, Control Center, a call coming in:
    /// from `sceneInactive` until `sceneEntered`. The app switcher is where an app is swiped away.
    @ObservationIgnored private var isInactive = false
    #if canImport(UIKit)
    /// Background time asked for while a run on its way out reaches its pause point.
    @ObservationIgnored private var importBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    /// Background time asked for while a launch that left waits for its song to load: a suspended
    /// app stops decoding, and one the system then ends would be taken for a crash.
    @ObservationIgnored private var launchBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "documents")
    /// Runs before another song replaces the open one. The app sets it to write the plugins'
    /// current settings into the song, which they keep to themselves until asked; without it a
    /// built-in effect's tweaks since the app last left the foreground were lost on a switch.
    @ObservationIgnored var beforeLeavingSong: (() -> Void)?

    /// Quiet time after an edit before the song is written.
    static let autosaveDelay: Duration = .seconds(2)
    /// The longest a change waits for the pause: a control the music keeps moving — a mapped
    /// knob, an expression pedal, an automation pass — never leaves two quiet seconds, and a
    /// crash or a memory kill then lost the whole session (audit 2026-10-23).
    static let autosaveLongest: Duration = .seconds(10)

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
        // Whatever ended the app, a run of the import that was under way then is found by its own
        // mark, and what becomes of it is said in the status line. The import itself starts only
        // once this launch is confirmed (`confirmLaunch`), so it can never be what a launch that
        // dies early was doing (review 2026-10-21).
        importLaunchWarning = earlierImportLaunchBegan()
        refresh()
        isRestored = true
        // Set last, since opening a song clears it. Short enough for the status line: about three
        // lines of caption on a phone in portrait.
        var note: String?
        defer { launchNote = note }
        if let incoming = pendingIncoming {
            pendingIncoming = nil
            if open(incoming) { return }
        }
        if previousDied {
            log.error("the last launch did not finish — starting a new song")
            startSong(writing: false)
            note = suspect.map {
                "Echoel did not finish starting last time, so this is a new song; \(Self.songName($0)) was open then and waits until you choose it."
            } ?? "Echoel did not finish starting last time, so this is a new song. Your songs are in the list."
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
        // A first install has no song at all: it opens Four Tracks (keys, bass, lead, drums on
        // sounds), so the first touch plays something. When songs exist but none opens, the
        // empty starter stands in, as after a launch that did not finish.
        if currentURL == nil { startSong(writing: false, from: songs.isEmpty ? .fourTracks : .empty) }
        if let unopened {
            note = unopened.newer
                ? "\(unopened.name) was saved by a newer Echoel. It stays in your songs; update the app to open it."
                : "\(unopened.name) could not be opened. It stays in your songs."
        } else if let held {
            note = "\(held) was open when Echoel stopped, so it does not open by itself. Choose it in your songs to open it."
        }
    }

    private static func songName(_ file: String) -> String {
        (file as NSString).deletingPathExtension
    }

    /// Called when the app goes to the background: a launch that got this far counts as healthy
    /// once the song it opened has finished loading, the last thing that could still end it.
    func sceneLeft() {
        isInBackground = true
        importWait?.cancel()
        importWait = nil
        if let run = importRun {
            // The run stops at its next pause point, between two songs; until then it is under
            // way, and a system that suspends and ends the app there would count against the
            // song. Background time lets it get there (review 2026-10-21).
            beginImportBackgroundTime()
            run.cancel()
        }
        confirmLaunchOnceLoaded(inBackground: true)
    }

    /// A launch that leaves, or stops being active, counts as healthy once the song open then has
    /// loaded its media. Another song opened in the meantime has a decode of its own that can
    /// still end the app, so the wait follows the song that is open (review 2026-10-22). In the
    /// background the wait has background time: a suspended app stops decoding.
    private func confirmLaunchOnceLoaded(inBackground: Bool) {
        guard launch.isPending else { return }
        if inBackground { beginLaunchBackgroundTime() }
        launchLeave?.cancel()
        launchLeave = Task { [weak self] in
            while let song = self?.songsOpened {
                await self?.mediaLoaded(for: song)
                guard !Task.isCancelled else { return }
                if self?.songsOpened == song { break }
            }
            self?.confirmLaunch(leaving: true)
            self?.endLaunchBackgroundTime()
        }
    }

    /// Called when the app comes to the foreground. A launch confirmed by leaving did not start
    /// the import, and a run that paused on the way out has not finished: either starts once the
    /// app has stayed in front for the steady time, as on a fresh launch (review 2026-10-21). A run
    /// still on its way to its pause point arms the wait itself when it gets there.
    func sceneEntered() {
        isInBackground = false
        isInactive = false
        followMovedPackage()
        armImportWait()
    }

    /// Called when the app stops being active while it is still in front. A run of the import
    /// pauses here, between two songs, and goes on once the app is active again: in the app
    /// switcher a swipe ends the app with no move to the background first, and two such ends on
    /// the same song left a healthy song out (round 4 measurement). `fromActive` is false on the
    /// way into the app (a launch, a return from the background), which is no leave.
    func sceneInactive(fromActive: Bool) {
        isInactive = true
        importWait?.cancel()
        importWait = nil
        importRun?.cancel()
        // The same swipe ends a launch that never reached the background, so leaving the active
        // app confirms it too, on the same terms as a leave (review 2026-10-22).
        if fromActive { confirmLaunchOnceLoaded(inBackground: false) }
    }

    private func armImportWait() {
        guard isRestored, !isInBackground, !isInactive, !launch.isPending, importRun == nil,
              !importRanThisLaunch else { return }
        importWait?.cancel()
        importWait = Task { [weak self] in
            try? await Task.sleep(for: .seconds(LaunchRecord.steadySeconds))
            guard !Task.isCancelled else { return }
            self?.importEarlierSongs()
        }
    }

    private func beginImportBackgroundTime() {
        #if canImport(UIKit)
        guard importBackgroundTask == .invalid else { return }
        // The system calls the handler on the main thread and ends the app unless it ends the task
        // before returning, so it ends it in place rather than in a later task.
        importBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Earlier songs") { [weak self] in
            MainActor.assumeIsolated { self?.endImportBackgroundTime() }
        }
        #endif
    }

    private func endImportBackgroundTime() {
        #if canImport(UIKit)
        guard importBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(importBackgroundTask)
        importBackgroundTask = .invalid
        #endif
    }

    private func beginLaunchBackgroundTime() {
        #if canImport(UIKit)
        guard launchBackgroundTask == .invalid else { return }
        launchBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Launch check") { [weak self] in
            MainActor.assumeIsolated { self?.endLaunchBackgroundTime() }
        }
        #endif
    }

    private func endLaunchBackgroundTime() {
        #if canImport(UIKit)
        guard launchBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(launchBackgroundTask)
        launchBackgroundTask = .invalid
        #endif
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
        launchLeave?.cancel()
        launchLeave = nil
        endLaunchBackgroundTime()
        // Only in the foreground: a run started on the way to the background, or in it (the audio
        // background mode keeps a playing app alive past ten seconds), is suspended in the middle,
        // and one the system then ends would count against the song it was on. Otherwise it waits
        // for `sceneEntered` — or, when the app came back before the song finished loading and
        // `sceneEntered` found the launch still pending, it starts its own wait here.
        if !isInBackground {
            if leaving { armImportWait() } else { importEarlierSongs() }
        }
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
            log.error("incoming song refused — \(error.localizedDescription, privacy: .private)")
            let name = url.deletingPathExtension().lastPathComponent
            // As a song chosen from the library says it (`open(_:)`).
            lastError = Self.isNewer(error)
                ? "\(name) was saved by a newer Echoel. Update the app to open it."
                : "Could not open \(name)."
        }
    }

    func newSong(_ starter: StarterProject) {
        startSong(writing: true, from: starter)
    }

    /// A new song from a starter. `writing: false` keeps it off the disk until its first edit:
    /// the starter the launch opens in place of a song must not become the newest song over the
    /// user's — after a false alarm the next healthy launch would open it instead (R8). A first
    /// install opens Four Tracks; every other launch that finds no song to open, the empty one.
    private func startSong(writing: Bool, from starter: StarterProject = .empty) {
        guard mayLeaveSong(for: nil) else { return }
        noteOpening(nil)
        let project = Project.starter(starter)
        store.open(project)
        fileName.opened(named: project.name)
        moveSettled()
        currentURL = library.newURL(for: project.name)
        anotherSongOpened()
        savedProject = writing ? nil : project
        isUnwritten = !writing
        starterMadeFolder = false
        if !saveNow(), let url = currentURL {
            // Nothing is lost yet: the starter waits off the disk as at launch, and its first change
            // tries again. Left as a failed write it could never make way for another song, though
            // it held nothing to lose (review 2026-10-22).
            savedProject = project
            isUnwritten = true
            starterMadeFolder = FileManager.default.fileExists(atPath: url.path)
            saveError = nil
        }
        loadMedia(of: project)
    }

    /// A song chosen by hand, or handed to the app. A held song opens again at launch from now on.
    @discardableResult
    func open(_ url: URL) -> Bool {
        do {
            let opened = try open(throwing: url)
            if quarantine.holds(opened.lastPathComponent) {
                quarantine.chosen(opened.lastPathComponent)
                keepQuarantine()
            }
            return true
        } catch is UnsavedSong {
            return false
        } catch {
            lastError = Self.isNewer(error)
                ? "\(url.deletingPathExtension().lastPathComponent) was saved by a newer Echoel. Update the app to open it."
                : "Could not open \(url.deletingPathExtension().lastPathComponent)."
            return false
        }
    }

    /// Opens the song at `chosen` and returns where it was read: the open song chosen again is read
    /// where its package is after the save before it, which may just have moved it to its name
    /// (review 006 round 3).
    @discardableResult
    private func open(throwing chosen: URL) throws -> URL {
        let isOpenSong = !isUnwritten && !awaitsFirstWriteAtFreeName
            && currentURL?.standardizedFileURL.path == chosen.standardizedFileURL.path
        guard mayLeaveSong(for: chosen.deletingPathExtension().lastPathComponent) else { throw UnsavedSong() }
        let url = isOpenSong ? (currentURL ?? chosen) : chosen
        noteOpening(url.lastPathComponent)
        do {
            let found = try library.readRecovering(url)
            let project = found.project
            // The open song chosen again is read afresh and keeps its lines (review 2026-10-21). The
            // unwritten starter's URL is only a free name, and a song that arrived under it is another.
            let another = isUnwritten || awaitsFirstWriteAtFreeName
                || currentURL.map { $0.standardizedFileURL.path != url.standardizedFileURL.path } ?? true
            store.open(project)
            // The open song read again keeps a move it still owes: its document already carries
            // the new name, so taking that as the name it opened with would drop the move.
            if another {
                fileName.opened(named: project.name)
                moveSettled()
                // A package under a name in between was left by a change of case that did not
                // finish; no one chose that name, so the next write gives it the song's own.
                if ProjectLibrary.isBetweenStem(url.deletingPathExtension().lastPathComponent) { fileName.stranded() }
            }
            currentURL = url
            if another { anotherSongOpened() }
            packageIdentity = ProjectLibrary.identity(of: url)
            // A song read from the copy one save back is not what is on disk: nothing counts as
            // written, so the next save puts it back over the damaged document.
            savedProject = found.fromPrevious ? nil : project
            isUnwritten = false
            starterMadeFolder = false
            // A move the open song still owes is still true; another song's went with `moveSettled`.
            lastError = failedMoveLine
            if found.fromPrevious {
                let name = url.deletingPathExtension().lastPathComponent
                log.error("the document did not open — opened the copy one save back")
                lastError = [failedMoveLine, "\(name) was damaged on disk, so Echoel opened it as it was one save earlier."]
                    .compactMap { $0 }.joined(separator: " ")
            }
            loadMedia(of: project)
            return url
        } catch {
            log.error("open failed — \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    /// The open song could not be written, so it did not make way for another.
    private struct UnsavedSong: Error {}

    /// Before another song replaces the open one, which is written first. When that fails it
    /// stays open: opening the next one went on regardless and dropped every change since the
    /// last write without a word (review 2026-10-22). Reopening the same song reads it from the
    /// disk, so it waits too. `next` is the song asked for, nil for a new one; the line names
    /// both, since a song that just arrived from Files would otherwise read as "this song".
    private func mayLeaveSong(for next: String?) -> Bool {
        beforeLeavingSong?()
        guard saveNow() else {
            let open = currentURL?.deletingPathExtension().lastPathComponent ?? "the open song"
            if next == open {
                saveError = "Could not save \(open). Your changes are still open."
            } else {
                saveError = "Could not save \(open), so \(next ?? "no new song") \(next == nil ? "was started" : "did not open"). \(open) stays open with your changes."
            }
            return false
        }
        return true
    }

    /// Called on every project change: writes after a short pause.
    func projectChanged() {
        pendingSave?.cancel()
        let now = ContinuousClock.now
        let oldest = firstUnsavedChange ?? now
        firstUnsavedChange = oldest
        if oldest.duration(to: now) >= Self.autosaveLongest {
            saveNow()
            return
        }
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

    /// Writes the open song now if it changed since the last write. False when it could not.
    @discardableResult
    func saveNow() -> Bool {
        pendingSave?.cancel()
        pendingSave = nil
        // A write that fails starts the wait again too, so a failing disk is tried every
        // `autosaveLongest`, not at every change.
        firstUnsavedChange = nil
        // Before the check below: a rename written while the package was busy still has to move
        // it, though nothing is left to write; and audio still at a free name moves in.
        followRenamedSong()
        settleLeftBehind()
        guard currentURL != nil, store.project != savedProject else {
            // Undo back to the written state leaves nothing unsaved.
            saveError = nil
            return true
        }
        starterKeepsItsOwnPackage()
        let gone = followMovedPackage() ?? nameTakenFrom
        guard let url = currentURL else { return true }
        let project = store.project
        let isNew = !FileManager.default.fileExists(atPath: url.appendingPathComponent(ProjectLibrary.documentName).path)
        let folderWasThere = FileManager.default.fileExists(atPath: url.path)
        do {
            try library.write(project, to: url)
            packageIdentity = ProjectLibrary.identity(of: url)
            if let gone {
                // Written again so the changes are kept; the line says what the package took along.
                lastError = project.media.isEmpty
                    ? "\(gone) was moved or deleted in the Files app, so Echoel saved it again with your changes."
                    : "\(gone) was moved or deleted in the Files app with its audio files. Echoel saved it again with your changes, without that audio."
                if nameTakenFrom != nil {
                    lastError = (lastError ?? "") + " Another song has that name now, so this one is \(url.deletingPathExtension().lastPathComponent)."
                }
                nameTakenFrom = nil
                formerIdentity = nil
            }
            savedProject = project
            isUnwritten = false
            // Only its own line: a write says nothing about an export or an import, and clearing
            // `lastError` here took "Exported without …" away two seconds after the export's own
            // plugin capture changed the song (review 2026-10-22).
            saveError = nil
            if isNew { releaseHold(on: url) }
            refresh()
            return true
        } catch {
            log.error("save failed — \(error.localizedDescription, privacy: .private)")
            saveError = "Could not save. Your changes are still open."
            // The write makes the folder before it writes the document, so a failed first write
            // leaves the song's own folder there: the next try writes into it, instead of taking
            // it for another song's and leaving one empty package per try (fifth night review).
            if !folderWasThere, isUnwritten || awaitsFirstWriteAtFreeName,
               FileManager.default.fileExists(atPath: url.path) {
                starterMadeFolder = true
            }
            return false
        }
    }

    /// Renames the open song — one undo step, written at once — and its package takes the new
    /// name. The door checks the name: trimmed, not empty, not too long. An Undo or a Redo of the
    /// rename moves the package again with the next write.
    func renameSong(to name: String) {
        // The same name again would be an undo step that changes nothing.
        guard name.trimmingCharacters(in: .whitespacesAndNewlines) != store.project.name else { return }
        do {
            try store.perform([.renameProject(name: name)], title: "Rename Song")
        } catch {
            lastError = "Could not rename the song."
            return
        }
        saveNow()
    }

    /// Something reads or writes into the package right now. Moving it under that work would lose
    /// what it writes, or leave it reading from a folder that is gone. The Rename door waits for
    /// it too, so a rename moves at once; only an Undo or a Redo of one can wait.
    var packageIsBusy: Bool { isImporting || isExporting || isLoadingMedia || !takesInFlight.isEmpty }

    /// The open song's name changed, so its package takes the new name — at once, or when the
    /// work on the package ends. A move that fails leaves the package where it is, says so once,
    /// and is tried again at the next write.
    private func followRenamedSong() {
        let name = store.project.name
        // Nothing owed — the move went through, or an Undo took the name back.
        guard fileName.isDue(for: name) else {
            moveSettled()
            return
        }
        guard fileName.shouldMove(for: name, busy: packageIsBusy), let url = currentURL else { return }
        if (isUnwritten || awaitsFirstWriteAtFreeName)
            && (!starterMadeFolder || !FileManager.default.fileExists(atPath: url.path)) {
            // Nothing on disk is the song's yet — the starter's, or a song waiting at a free name —
            // so there is nothing to move: it only takes another free name. A folder there that it
            // did not make is another song's, and is never renamed (fifth night review, 2026-10-23).
            fileName.followed(name)
            currentURL = library.newURL(for: name)
            starterMadeFolder = false
            return
        }
        do {
            let moved = try library.rename(url, to: name)
            fileName.followed(name)
            if moved != url { packageMoved(from: url, to: moved) }
            moveSettled()
        } catch let stranded as ProjectLibrary.RenameStranded {
            // A change of case failed half way and could not go back: the package is under the
            // name in between. The song follows it there, rather than the next write making a
            // second package, without the audio, under the old name. The next write tries again.
            // It follows no name there, so an Undo back to the old name still moves it home.
            fileName.stranded()
            packageMoved(from: url, to: stranded.url)
            moveFailed(stranded.underlying, fileNow: stranded.url)
        } catch {
            moveFailed(error, fileNow: url)
        }
    }

    /// The open, written song's package is no longer where the app left it: renamed or moved in
    /// the Files app while it was open, or deleted there. A rename inside the library is followed,
    /// so the next write lands in the package with the media instead of creating a second one
    /// under the old name with nothing but the document — which the next launch then opened as
    /// the newest song, its audio silent (audit 2026-10-23). Returns the song's old file name when
    /// the package is nowhere in the library, so the write that follows creates it again and says so.
    /// A package at the old path that is not the open song's — another song renamed to its name —
    /// is never written over: the open song is written again under a free name (review 2026-10-23).
    @discardableResult
    private func followMovedPackage() -> String? {
        guard !isUnwritten, let url = currentURL else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        if awaitsFirstWriteAtFreeName {
            // The song's own package back in the library, under whatever name — moved back in
            // Files: the song follows it and is written there with its audio again (fourth night
            // review, 2026-10-23: it was split off as a new song without its media). What a take
            // or an import wrote at the free name meanwhile goes along at once, where the song is
            // now; a file still being written moves when it lands (fifth and sixth night reviews).
            if let formerIdentity, let back = library.package(formerIdentity) {
                log.info("the open song's package came back into the library; it follows")
                packageIdentity = formerIdentity
                nameTakenFrom = nil
                self.formerIdentity = nil
                fileName = formerFileName
                let made = starterMadeFolder && back != url
                starterMadeFolder = false
                if back != url { packageMoved(from: url, to: back) }
                if made { gather(from: url) }
                return nil
            }
            // No identity of its own there yet: a document at the free name is another song's, and
            // so is a folder no take or import of this song made.
            let files = FileManager.default
            let arrived = files.fileExists(atPath: url.appendingPathComponent(ProjectLibrary.documentName).path)
                || (!starterMadeFolder && files.fileExists(atPath: url.path))
            guard arrived else { return nameTakenFrom }
            log.info("another song arrived at the open song's free name; it moves on to the next")
            starterMadeFolder = false
            packageMoved(from: url, to: library.newURL(for: nameTakenFrom ?? name))
            return nameTakenFrom
        }
        switch library.whereabouts(of: url, identity: packageIdentity) {
        case .inPlace:
            return nil
        case .renamed(let moved):
            log.info("the open song's package was renamed outside; it follows")
            packageMoved(from: url, to: moved)
            return nil
        case .nameTaken(let free):
            log.info("another song took the open song's name outside; it is written under a free one")
            packageMoved(from: url, to: free)
            // The song's own package is gone and the free name has never held it: the next write
            // is a first write. What happened is owed to the status line until a write says it,
            // whichever caller found it (second night review, 2026-10-23).
            formerIdentity = packageIdentity
            formerFileName = fileName
            packageIdentity = nil
            nameTakenFrom = name
            starterMadeFolder = false
            return name
        case .gone:
            return name
        }
    }

    /// Moves the audio a take or an import of the open song wrote into `folder` — the free name it
    /// waited at — into the package it writes to now, at once, so neither a song switch nor the
    /// app's end can leave it behind (sixth night review, 2026-10-23: deferred, it went missing,
    /// or into a package path that was stale by then). A take or an import still writing there is
    /// left to move its own file when it lands (`bring`, `settleLeftBehind`). A file that cannot
    /// move stays, and the line says where; the folder goes only when nothing is left in it.
    private func gather(from folder: URL) {
        guard let here = currentURL, folder != here else { return }
        let fm = FileManager.default
        // A document there is another song's that arrived since: nothing in it is touched.
        guard !fm.fileExists(atPath: folder.appendingPathComponent(ProjectLibrary.documentName).path) else { return }
        let media = folder.appendingPathComponent(MediaFile.directory)
        let names = (try? fm.contentsOfDirectory(atPath: media.path)) ?? []
        var writing = Set(takesInFlight.map { "\($0)" })
        if let importingMedia { writing.insert("\(importingMedia)") }
        var stayed = 0
        // An import or a take still under way may write here though its file is not there yet —
        // the copy starts a hop later — so the folder waits for it to land instead of going while
        // the import is about to write into it (seventh night review, 2026-10-23).
        var waiting = importingMedia != nil || !takesInFlight.isEmpty
        for name in names {
            if writing.contains((name as NSString).deletingPathExtension) {
                waiting = true
                continue
            }
            let target = here.appendingPathComponent(MediaFile.directory).appendingPathComponent(name)
            if !bring(media.appendingPathComponent(name), to: target, into: here) { stayed += 1 }
        }
        if stayed > 0 {
            let line = "\(stayed == 1 ? "An audio file" : "\(stayed) audio files") of this song stayed in the folder \(folder.deletingPathExtension().lastPathComponent) in the Files app."
            lastError = lastError.map { "\($0) \(line)" } ?? line
            return
        }
        if waiting {
            leftBehind = folder
            return
        }
        // Only empty folders go: a remove of a folder that still holds anything would take it along.
        if (try? fm.contentsOfDirectory(atPath: media.path))?.isEmpty == true { try? fm.removeItem(at: media) }
        if (try? fm.contentsOfDirectory(atPath: folder.path))?.isEmpty == true { try? fm.removeItem(at: folder) }
    }

    /// A take or an import that wrote into `leftBehind` has landed: what is left there moves in,
    /// where the song is now, and the folder goes.
    private func settleLeftBehind() {
        guard let folder = leftBehind, !isImporting, takesInFlight.isEmpty else { return }
        leftBehind = nil
        followMovedPackage()
        gather(from: folder)
    }

    /// Moves the audio file at `source` to `target` in the package at `here`, unless it is there
    /// already. True when it is at `target` now. A package folder this makes for a song not yet
    /// written there is the song's own (`starterMadeFolder`).
    private func bring(_ source: URL, to target: URL, into here: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path) { return true }
        guard source != target, fm.fileExists(atPath: source.path) else { return false }
        let makes = !fm.fileExists(atPath: here.path)
        do {
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if makes, isUnwritten || awaitsFirstWriteAtFreeName { starterMadeFolder = true }
            try fm.moveItem(at: source, to: target)
            return true
        } catch {
            let failure = error as NSError
            log.error("media move failed — \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
            return false
        }
    }

    /// The open song's package is at `moved` now.
    private func packageMoved(from url: URL, to moved: URL) {
        currentURL = moved
        // A launch that dies now holds the song by the name it has now.
        if quarantine.opening == url.lastPathComponent { noteOpening(moved.lastPathComponent) }
        // The name may be a held song's that was deleted in Files; the hold was for that song.
        releaseHold(on: moved)
        refresh()
    }

    /// The package could not take the song's name; it is at `url` now, under the name it had or
    /// under the one in between a change of case.
    private func moveFailed(_ error: Error, fileNow url: URL) {
        // Domain and code only: the description spells both song names.
        let failure = error as NSError
        log.error("rename move failed — \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
        // One sentence, true in every state that gets here: after a rename, after an Undo back to
        // the old name, and for a song that opened from a name in between, where nobody renamed
        // anything (review 007 round 1). It names where the file is, so it changes only with that,
        // and says what lags behind, the file, so it never reads as a failed save (round 2).
        let file = url.deletingPathExtension().lastPathComponent
        let line = "Only the file lags behind: in the Files app the song is called \(file) for now, and Echoel tries to rename the file when it next saves."
        // Said once; a later failure that left the file somewhere else says where it is now.
        guard line != failedMoveLine else { return }
        moveSettled()
        failedMoveLine = line
        // Beside, not over, what the work just finished said (an export's "Exported without …").
        lastError = lastError.map { "\($0) \(line)" } ?? line
    }

    /// Nothing is owed for the file name any more, so the line a failed move added is no longer
    /// true and goes; whatever else the status line says stays.
    private func moveSettled() {
        guard let line = failedMoveLine else { return }
        failedMoveLine = nil
        guard let shown = lastError, shown.contains(line) else { return }
        let rest = shown.replacingOccurrences(of: line, with: "").trimmingCharacters(in: .whitespaces)
        lastError = rest.isEmpty ? nil : rest
    }

    /// Renders the open song to a 24-bit WAV in a temporary folder, off the main thread,
    /// and returns its URL for the share sheet. Plugins play from fresh copies loaded with the
    /// settings they have right now; one that cannot load is named in `lastError` and left out.
    /// When another song opens before the file is handed out, the export stops and says so.
    func exportWAV(plugins: PluginHost) async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        defer {
            isExporting = false
            followRenamedSong()
        }
        let rate = 48_000.0
        let exportedSong = songsOpened
        let songName = openSongName
        // The song's audio files decode after it opens. A render before they arrive left its
        // sampler and audio parts silent, with no word about it (review 2026-10-19).
        await mediaLoaded(for: exportedSong)
        guard exportedSong == songsOpened else { return exportStopped(songName) }
        plugins.store(into: store)
        // The song and its audio are taken together, with no wait between them: a song opened
        // while the plugins load must not lend this one its buffers (review 2026-10-22).
        let project = store.project
        let buffers = samples
        let unread = Self.unreadMedia(in: project, buffers: buffers, notLoaded: unfitMedia)
        let offline = await plugins.offlineUnits(for: project, sampleRate: rate)
        let name = ProjectLibrary.safeFileName(for: songName)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        let url = folder.appendingPathComponent(name).appendingPathExtension("wav")
        // Block by block into the file: a long song never sits in memory whole.
        // Measured on the way, as the file receives it (BS.1770 / EBU R 128).
        let result: Result<(meter: LoudnessMeter, frames: Int), Error> = await Task.detached(priority: .userInitiated) {
            Result {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let writer = try WAVWriter(url: url, sampleRate: rate)
                var meter = LoudnessMeter(sampleRate: rate)
                let frames: Int
                do {
                    frames = try OfflineRender.render(project, sampleRate: rate, samples: buffers, units: offline.units,
                                                 effects: offline.chains.mapValues { $0 as [any HostedProcessor] },
                                                 masterEffects: offline.masterChain) { left, right, count in
                        try writer.append(left: left, right: right, count: count)
                        meter.process(left: left, right: right, count: count)
                    }.frameCount
                    guard offline.renderFailures == 0 else { throw PluginRenderFailed() }
                    try writer.finish()
                } catch {
                    try? FileManager.default.removeItem(at: url)
                    throw error
                }
                return (meter, frames)
            }
        }.value
        // The file is the earlier song's; shared from the next one's screen it would pass for that
        // one, and its loudness and missing plugins are not that song's news.
        guard exportedSong == songsOpened else {
            if case .success = result { try? FileManager.default.removeItem(at: url) }
            return exportStopped(songName)
        }
        switch result {
        case .success(let rendered) where rendered.frames == 0:
            try? FileManager.default.removeItem(at: url)
            lastExportIsNews = false
            lastError = Self.nothingToExport(audio: unread)
            return nil
        case .success(let rendered):
            lastExportLoudness = (rendered.meter.integratedLoudness, rendered.meter.truePeak)
            lastExportIsNews = true
            lastError = Self.exportedWithout(plugins: offline.missing, audio: unread)
            return url
        case .failure(let error):
            log.error("export failed — \(error.localizedDescription, privacy: .private)")
            // The loudness of an earlier export must not stand under this failure as its result.
            lastExportIsNews = false
            lastError = error is PluginRenderFailed
                ? "A plugin stopped rendering during the export, so the file would have had gaps. Nothing was saved."
                : error as? WAVWriter.WriteError == .tooLong
                ? "The song is longer than a WAV file can hold (about four hours at 24-bit, 48 kHz)."
                : "Could not export the song."
            return nil
        }
    }

    /// Renders each stem of the open song (`OfflineRender.stems`) to a 24-bit WAV in one folder
    /// named after the song, every file at the mix's length so they line up at bar 1 in any DAW,
    /// with the song's MIDI file beside them when the arrangement plays a note. Returns the folder
    /// for the share sheet. The stems leave out the master's inserts: they add up to the mix
    /// before those. Each render loads its plugins afresh, so no stem starts with a tail an
    /// earlier render left in an effect.
    func exportStems(plugins: PluginHost) async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        defer {
            isExporting = false
            exportProgress = nil
            followRenamedSong()
        }
        let rate = 48_000.0
        let exportedSong = songsOpened
        let songName = openSongName
        await mediaLoaded(for: exportedSong)
        guard exportedSong == songsOpened else { return exportStopped(songName) }
        plugins.store(into: store)
        let project = store.project
        let buffers = samples
        let unread = Self.unreadMedia(in: project, buffers: buffers, notLoaded: unfitMedia)
        let stems = OfflineRender.stems(of: project, samples: buffers)
        guard !stems.isEmpty else {
            lastExportIsNews = false
            lastError = unread.isEmpty
                ? "No track that plays is heard in the mix: unmute one to export its stem."
                : Self.nothingToExport(audio: unread)
            return nil
        }
        // A stem left by an earlier export of a track that is gone must not ride along.
        let name = ProjectLibrary.safeFileName(for: songName)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(name + " Stems", isDirectory: true)
        exportProgress = "Measuring the song…"
        let measuring = await plugins.offlineUnits(for: project, sampleRate: rate)
        guard exportedSong == songsOpened else { return exportStopped(songName) }
        // The mix's length as the stems sum to it: without the master's inserts.
        let measured: Result<Int, Error> = await Task.detached(priority: .userInitiated) {
            Result {
                let files = FileManager.default
                if files.fileExists(atPath: folder.path) { try files.removeItem(at: folder) }
                try files.createDirectory(at: folder, withIntermediateDirectories: true)
                return OfflineRender.render(project, sampleRate: rate, samples: buffers, units: measuring.units,
                                            effects: measuring.chains.mapValues { $0 as [any HostedProcessor] }) { _, _, _ in }
                    .frameCount
            }
        }.value
        var outcome = measured.map { _ in () }
        // A plugin that loads for one render and not the next is missing from some stems: named.
        var missing = measuring.missing
        if case .success(0) = measured, exportedSong == songsOpened {
            try? FileManager.default.removeItem(at: folder)
            lastExportIsNews = false
            lastError = Self.nothingToExport(audio: unread)
            return nil
        }
        if case .success(let length) = measured {
            for (index, stem) in stems.enumerated() {
                exportProgress = "Exporting stem \(index + 1) of \(stems.count)…"
                let offline = await plugins.offlineUnits(for: project, sampleRate: rate)
                guard exportedSong == songsOpened else { break }
                for plugin in offline.missing where !missing.contains(plugin) { missing.append(plugin) }
                let url = folder.appendingPathComponent(stem.name).appendingPathExtension("wav")
                outcome = await Task.detached(priority: .userInitiated) {
                    Result {
                        try Self.writeStem(project, isolating: stem.track, frameCount: length, sampleRate: rate,
                                           samples: buffers, offline: offline, to: url)
                    }
                }.value
                if case .failure = outcome { break }
            }
            if case .success = outcome, exportedSong == songsOpened, project.arrangementHasEvents {
                let file = folder.appendingPathComponent(name).appendingPathExtension("mid")
                outcome = Result { try MIDIFile.data(for: project).write(to: file, options: .atomic) }
            }
        }
        // Half a set of stems is no export: what was written goes, whatever stopped it.
        guard exportedSong == songsOpened, case .success = outcome else {
            try? FileManager.default.removeItem(at: folder)
            guard exportedSong == songsOpened else { return exportStopped(songName) }
            if case .failure(let error) = outcome {
                log.error("stem export failed — \(error.localizedDescription, privacy: .private)")
                lastExportIsNews = false
                lastError = error is PluginRenderFailed
                    ? "A plugin stopped rendering during the export, so the stems would have had gaps. Nothing was saved."
                    : error as? WAVWriter.WriteError == .tooLong
                    ? "The song is longer than a WAV file can hold (about four hours at 24-bit, 48 kHz)."
                    : "Could not export the stems."
            }
            return nil
        }
        // A set of stems has no one loudness: the line under the transport spoke of an earlier
        // file, and "Last export" would now name the wrong one.
        lastExportLoudness = nil
        lastExportIsNews = false
        var notes = [Self.exportedWithout(plugins: missing, audio: unread)].compactMap { $0 }
        if project.masterInserts.contains(where: { !$0.isBypassed }) {
            notes.append("The stems leave out the master effects: together they are the mix before those.")
        }
        lastError = notes.isEmpty ? nil : notes.joined(separator: " ")
        return folder
    }

    /// One stem into `url`, block by block, at `frameCount` frames. Off the main thread; a file
    /// that fails half-written is left for the caller, which removes the whole folder.
    private nonisolated static func writeStem(_ project: Project, isolating track: TrackID, frameCount: Int,
                                              sampleRate: Double, samples: [MediaID: SampleBuffer],
                                              offline: OfflineUnits, to url: URL) throws {
        let writer = try WAVWriter(url: url, sampleRate: sampleRate)
        _ = try OfflineRender.render(project, sampleRate: sampleRate, samples: samples, units: offline.units,
                                     effects: offline.chains.mapValues { $0 as [any HostedProcessor] },
                                     isolating: track, frameCount: frameCount) { left, right, count in
            try writer.append(left: left, right: right, count: count)
        }
        guard offline.renderFailures == 0 else { throw PluginRenderFailed() }
        try writer.finish()
    }

    /// A finished take, decoded — or, when the free memory could not take it, its length and rate
    /// from the file's header, so it joins the song unloaded.
    private enum TakeAudio: Sendable {
        case decoded(SampleBuffer)
        case unloaded(frameCount: Int, sampleRate: Double)
    }

    /// The audio files an export renders as silence, by name, and why.
    private struct UnheardAudio {
        /// Missing from the song package or not decodable.
        var missing: [String] = []
        /// Left out by the song's memory plan on this device.
        var unfit: [String] = []
        /// Not loaded because the memory was not free when the song opened.
        var noFreeMemory: [String] = []
        var isEmpty: Bool { missing.isEmpty && unfit.isEmpty && noFreeMemory.isEmpty }
    }

    /// Why a file is left out when the song holds more audio than the device keeps.
    private static let overBudget = "The song holds more audio than Echoel can keep in memory on this device."
    /// Why a file is left out when the memory was not free to load it.
    private static let noFreeMemory = "There was not enough free memory; Echoel tries again the next time the song opens."

    /// The audio files the arrangement plays that did not decode, by name: they render as
    /// silence, and the export says which and why. Only what it plays — a region, a placed audio
    /// clip, a sampler's sample; a file left in the song by a deleted region, or played only in
    /// the session, is not in the file (review 2026-10-22).
    private static func unreadMedia(in project: Project, buffers: [MediaID: SampleBuffer],
                                    notLoaded: [MediaID: NotLoaded]) -> UnheardAudio {
        let played = Set(project.tracks.flatMap { track -> [MediaID] in
            let placed = Set(track.placements.map(\.clip))
            var media = track.regions.map(\.media)
            media += track.clips.filter { placed.contains($0.id) }.compactMap { $0.audio?.media }
            if track.instrument.device == .sampler, let sample = track.instrument.sample { media.append(sample) }
            return media
        })
        var unheard = UnheardAudio()
        for file in project.media where played.contains(file.id) && buffers[file.id] == nil {
            switch notLoaded[file.id] {
            case .overBudget: unheard.unfit.append(file.name)
            case .noFreeMemory: unheard.noFreeMemory.append(file.name)
            case nil: unheard.missing.append(file.name)
            }
        }
        return unheard
    }

    /// The line naming what an export was made without, or nil when it lacks nothing.
    private static func exportedWithout(plugins missing: [String], audio unread: UnheardAudio) -> String? {
        var without: [String] = []
        if !missing.isEmpty {
            without.append("Exported without \(missing.joined(separator: ", ")): not available on this device.")
        }
        if !unread.missing.isEmpty {
            without.append("Exported without \(audioFiles(unread.missing)): missing or unreadable in the song.")
        }
        if !unread.unfit.isEmpty {
            without.append("Exported without \(audioFiles(unread.unfit)), not loaded: \(overBudget)")
        }
        if !unread.noFreeMemory.isEmpty {
            without.append("Exported without \(audioFiles(unread.noFreeMemory)), not loaded: \(noFreeMemory)")
        }
        return without.isEmpty ? nil : without.joined(separator: " ")
    }

    /// The render came out empty, so there is no file: an audio file that did not decode or did
    /// not fit, or a region that starts past the end of its file. An empty WAV is no export
    /// (review 2026-10-22).
    private static func nothingToExport(audio unread: UnheardAudio) -> String {
        var why: [String] = []
        if !unread.missing.isEmpty {
            let verb = unread.missing.count == 1 ? "is" : "are"
            why.append("\(audioFiles(unread.missing)) \(verb) missing or unreadable in the song.")
        }
        if !unread.unfit.isEmpty {
            let verb = unread.unfit.count == 1 ? "is" : "are"
            why.append("\(audioFiles(unread.unfit)) \(verb) not loaded. \(overBudget)")
        }
        if !unread.noFreeMemory.isEmpty {
            let verb = unread.noFreeMemory.count == 1 ? "is" : "are"
            why.append("\(audioFiles(unread.noFreeMemory)) \(verb) not loaded. \(noFreeMemory)")
        }
        return why.isEmpty
            ? "Nothing to export: what the arrangement holds renders no sound."
            : "Nothing to export: " + why.joined(separator: " ")
    }

    /// "the audio file “A”", or up to three names and how many more.
    private static func audioFiles(_ names: [String]) -> String {
        let shown = names.prefix(3).map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
        let more = names.count > 3 ? " and \(names.count - 3) more" : ""
        return "the audio \(names.count == 1 ? "file" : "files") \(shown)\(more)"
    }

    /// Returns once the open song's audio files are decoded, also when reopening it started
    /// another load meanwhile — or at once when another song opened, whose audio the export
    /// would only wait for to throw away.
    private func mediaLoaded(for song: Int) async {
        while let load = mediaLoad, songsOpened == song {
            await load.value
            if mediaLoad == load { return }
        }
    }

    private func exportStopped(_ song: String) -> URL? {
        log.info("export stopped — another song was opened")
        lastExportIsNews = false
        lastError = "The export of \(song) stopped: you opened or started another song."
        return nil
    }

    /// Play started a fresh status line: the last message and the launch note go, and the last
    /// export's loudness is no longer news. A write no longer clears the message (review
    /// 2026-10-22), so this is where an outcome the user has moved past goes.
    func playStarted() {
        lastError = nil
        launchNote = nil
        earlierSongsNote = nil
        lastExportIsNews = false
    }

    /// The musician read the warning about earlier songs and hides it.
    func hideEarlierSongsWarning() {
        importLaunchWarning = nil
        importLeftOut = 0
        importUnsaved = []
    }

    /// Another song is open: the loudness line and the launch note spoke of the one before it.
    private func anotherSongOpened() {
        songsOpened &+= 1
        packageIdentity = nil
        nameTakenFrom = nil
        formerIdentity = nil
        leftBehind = nil
        launchNote = nil
        earlierSongsNote = nil
        lastExportLoudness = nil
        lastExportIsNews = false
    }

    /// The open song as the status lines and the exported files name it: by its file name. Every
    /// new song is called "New Song" inside, so the project's own name says nothing about which
    /// one (review 2026-10-22); two exports of two songs would both arrive as "New Song.wav".
    private var openSongName: String {
        currentURL?.deletingPathExtension().lastPathComponent ?? store.project.name
    }

    /// The open song's title on screen (`ProjectLibrary.title`).
    var songTitle: String {
        ProjectLibrary.title(name: store.project.name, stem: currentURL?.deletingPathExtension().lastPathComponent)
    }

    /// Writes a clean copy of the open song as a package in a temporary folder and returns it for
    /// the share sheet: the song as it stands, with the plugins' settings as they are now, and the
    /// audio files it uses — not a take being recorded or a file it let go. A file it uses that is
    /// gone is named; the copy goes without it.
    func shareSong(plugins: PluginHost) async -> URL? {
        guard !isExporting else { return nil }
        isExporting = true
        exportProgress = "Preparing the song…"
        defer {
            isExporting = false
            exportProgress = nil
            followRenamedSong()
        }
        let sharedSong = songsOpened
        let songName = openSongName
        plugins.store(into: store)
        let project = store.project
        followMovedPackage()
        let package = currentURL
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(ProjectLibrary.safeFileName(for: songName))
            .appendingPathExtension(ProjectLibrary.fileExtension)
        let result: Result<[String], Error> = await Task.detached(priority: .userInitiated) {
            Result { try ProjectLibrary.shareableCopy(of: project, mediaIn: package, at: target) }
        }.value
        guard sharedSong == songsOpened else {
            // The copy of the earlier song is shared with nobody; it does not stay behind.
            if case .success = result { try? FileManager.default.removeItem(at: target) }
            return exportStopped(songName)
        }
        switch result {
        case .success(let missing):
            lastExportIsNews = false
            lastError = missing.isEmpty ? nil : "Shared without \(Self.audioFiles(missing)): missing from the song."
            return target
        case .failure(let error):
            log.error("share copy failed — \(error.localizedDescription, privacy: .private)")
            lastExportIsNews = false
            lastError = "Could not prepare \(songName) for sharing."
            return nil
        }
    }

    /// Writes the open song's notes as a Standard MIDI File in a temporary folder and returns its
    /// URL for the share sheet. Small and quick, so it runs here.
    func exportMIDI() -> URL? {
        let project = store.project
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        let url = folder.appendingPathComponent(ProjectLibrary.safeFileName(for: openSongName)).appendingPathExtension("mid")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try MIDIFile.data(for: project).write(to: url, options: .atomic)
            lastError = nil
            return url
        } catch {
            log.error("MIDI export failed — \(error.localizedDescription, privacy: .private)")
            lastError = "Could not export the MIDI file."
            return nil
        }
    }

    /// Copies an audio file into the song and makes it `track`'s sample, switching the track
    /// to the sampler — one undo step.
    func importAudio(_ source: URL, onto track: TrackID) async {
        guard let imported = await importMedia(source, placing: { file in
            [.addMedia(file), .setInstrumentDevice(track, .sampler), .setInstrumentSample(track, file.id)]
        }) else { return }
        perform(imported.commands, title: "Import \(imported.file.name)")
        dropBufferUnlessHeld(imported.file.id)
    }

    /// Copies an audio file into the song and places all of it on an audio track at `start` —
    /// one undo step.
    func importAudio(_ source: URL, placingOn track: TrackID, at start: Tick) async {
        guard let imported = await importMedia(source, placing: { file in
            [.addMedia(file), .placeAudio(track: track, id: RegionID(), media: file.id, start: start)]
        }) else { return }
        perform(imported.commands, title: "Import \(imported.file.name)")
        dropBufferUnlessHeld(imported.file.id)
    }

    /// Copies an audio file into the song as a session clip of an audio track, looping over the
    /// nearest whole number of bars, in a scene's slot — one undo step.
    func importAudioClip(_ source: URL, onto track: TrackID, scene: SceneID) async {
        guard let imported = await importMedia(source, placing: { file in
            let project = store.project
            let length = Arranging.loopLength(seconds: Double(file.frameCount) / file.sampleRate, bpm: project.tempo,
                                              signature: project.timeSignature)
            let clip = ClipID()
            return [.addMedia(file),
                    .createAudioClip(track: track, id: clip, name: file.name, length: length,
                                     audio: ClipAudio(media: file.id, length: file.frameCount)),
                    .setSlot(track: track, scene: scene, clip: clip)]
        }) else { return }
        perform(imported.commands, title: "Import \(imported.file.name)")
        dropBufferUnlessHeld(imported.file.id)
    }

    /// Copies and decodes a file off the main thread and keeps its buffer, returning the file and
    /// the commands `placing` makes of it, for one undo step. Nil, with `lastError` set, when it
    /// cannot be read, when placing it would leave something the song plays silent at the next
    /// open — or when another song was opened meanwhile.
    private func importMedia(_ source: URL, placing: (MediaFile) -> [Command]) async
        -> (file: MediaFile, commands: [Command])? {
        starterKeepsItsOwnPackage()
        if isImporting {
            // A second file picked while the first decodes: said, not dropped without a word.
            lastError = "Another file is still importing. Try again when it is in."
            return nil
        }
        followMovedPackage()
        guard let package = currentURL else { return nil }
        let song = songsOpened
        if isUnwritten || awaitsFirstWriteAtFreeName { starterMadeFolder = true }   // the import below makes it
        let id = MediaID()
        isImporting = true
        importingMedia = id
        defer {
            isImporting = false
            importingMedia = nil
            followRenamedSong()
            settleLeftBehind()
        }
        let result: Result<AudioFileImport.Imported, Error> = await Task.detached(priority: .userInitiated) {
            // A file picked outside the app is readable only inside this scope.
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            return Result { try AudioFileImport.importFile(source, into: package, id: id) }
        }.value
        // Another song opened meanwhile drops the import; the same song followed to a new name in
        // Files keeps it — its copy moved with the package (second night review, 2026-10-23). A
        // rename during the decode is followed here, before the copy is looked for: with Files
        // beside Echoel nothing else follows it, and the copy is at the new name (fourth night review).
        guard songsOpened == song else { return nil }
        followMovedPackage()
        guard let here = currentURL else { return nil }
        switch result {
        case .success(let imported):
            // Kept only when its copy is in the package the song writes to now. A package renamed
            // in Files took the copy along; a copy left at the old path — the song sent to a free
            // name, or back to its own package — is this import's alone, even inside another song's
            // package, and moves to where the song writes now, or the song would play it this
            // session and miss it at the next open (third and fifth night reviews, 2026-10-23).
            guard let copy = imported.file.url(in: here), let left = imported.file.url(in: package),
                  bring(left, to: copy, into: here) else {
                if let stray = imported.file.url(in: package) { try? FileManager.default.removeItem(at: stray) }
                lastError = "The song was moved or deleted in the Files app while the file was importing. Import it again."
                return nil
            }
            // A file that does not fit in memory beside the song's audio is not added: the next
            // open would leave it, or audio the song plays, silent (R9). Judged with the file
            // placed — appended alone it would rank behind every file nothing plays any more
            // (second night review, 2026-10-23). A command that fails here fails in `perform` too.
            let commands = placing(imported.file)
            var grown = store.project
            for command in commands { try? command.apply(to: &grown) }
            if !grown.newlySilencedMedia(budget: AudioFileImport.songBudgetBytes, comparedTo: store.project).isEmpty {
                try? FileManager.default.removeItem(at: copy)
                lastError = "This file does not fit: the song already holds as much audio as Echoel can keep in memory on this device."
                return nil
            }
            samples[imported.file.id] = imported.buffer
            mediaRevision += 1
            return (file: imported.file, commands: commands)
        case .failure(let error):
            log.error("import failed — \(error.localizedDescription, privacy: .private)")
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
        // A package renamed in Files while both apps stay in front is followed here too, or the
        // take would make the old name again beside it (review 2026-10-23).
        followMovedPackage()
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
        if isUnwritten || awaitsFirstWriteAtFreeName { starterMadeFolder = true }
        takesInFlight.insert(id)
        return TakeTarget(id: id, path: path, url: url)
    }

    /// The take `newTakeTarget` made room for at `target` did not come to be: it could not
    /// start, or ended with nothing. Another take in flight keeps the package busy.
    func takeAbandoned(_ target: TakeTarget) {
        takeLanded(target.id)
        followRenamedSong()
    }

    /// Returns once no take is being recorded into the open song or committed to it. Another
    /// song must not replace this one before: the take would land on a song that does not hold
    /// its track, and its file would stay behind in this one's Media folder (audit 2026-10-23).
    func takesSettled() async {
        while !takesInFlight.isEmpty {
            await withCheckedContinuation { takeWaiters.append($0) }
        }
    }

    private func takeLanded(_ id: MediaID) {
        takesInFlight.remove(id)
        guard takesInFlight.isEmpty else { return }
        settleLeftBehind()
        let waiting = takeWaiters
        takeWaiters = []
        for waiter in waiting { waiter.resume() }
    }

    /// Turns a finished take into a region on `track`, lined up with the beat it was played to —
    /// one undo step. The take is decoded off the main thread like an imported file.
    /// `tempoMap` is the one the take was heard against — an external clock's while following one.
    func commitTake(_ take: RecordedTake, target: TakeTarget, onto track: TrackID, tempoMap: TempoMap) async {
        defer {
            takeLanded(target.id)
            followRenamedSong()
        }
        // The take is read where its package is now: renamed in Files since the take began, the
        // package took the file along (second night review, 2026-10-23). Recording changes
        // nothing in the song, so no save has followed the rename yet; follow it here, as
        // `newTakeTarget` does (third night review). A package that did not take it — the song
        // sent to a free name, or back to its own package, while the take ran — gets it moved in;
        // a take that cannot move is read where it was written (fifth night review).
        followMovedPackage()
        let song = songsOpened
        var source = take.url
        // A take that could not move in plays now, and the line says where it is: the next open
        // looks for it in the package (sixth night review, 2026-10-23).
        var strandedIn: String?
        if let here = currentURL,
           let there = MediaFile(id: target.id, name: "Take", path: target.path, frameCount: 1, sampleRate: 1).url(in: here) {
            if bring(take.url, to: there, into: here) {
                source = there
            } else if there != take.url {
                strandedIn = take.url.deletingLastPathComponent().deletingLastPathComponent()
                    .deletingPathExtension().lastPathComponent
            }
        }
        // A take the free memory cannot load now is still the musician's recording: it joins the
        // song at its recorded length, silent until the next open loads it. Dropped here, its file
        // stayed in the package with nothing pointing to it (seventh night review, 2026-10-23).
        let result: Result<TakeAudio, Error> = await Task.detached(priority: .userInitiated) { () -> Result<TakeAudio, Error> in
            Result { () throws -> TakeAudio in
                do {
                    return TakeAudio.decoded(try AudioFileImport.decode(source))
                } catch AudioFileImport.ImportError.noMemory {
                    let header = try AudioFileImport.header(of: source)
                    return TakeAudio.unloaded(frameCount: header.frameCount, sampleRate: header.sampleRate)
                }
            }
        }.value
        // Another song opened meanwhile drops the take; the same song followed keeps it.
        guard songsOpened == song else { return }
        let buffer: SampleBuffer?
        let frameCount: Int
        let sampleRate: Double
        switch result {
        case .success(.decoded(let decoded)):
            buffer = decoded
            frameCount = decoded.frameCount
            sampleRate = decoded.sampleRate
        case .success(.unloaded(let count, let rate)):
            buffer = nil
            frameCount = count
            sampleRate = rate
        case .failure(let error):
            log.error("take unreadable — \(error.localizedDescription, privacy: .private)")
            lastError = (error as? LocalizedError)?.errorDescription ?? "The take could not be read."
            return
        }
        let time = TimeConversion(tempoMap: tempoMap, sampleRate: take.sampleRate)
        let placement = RecordingPlacement.place(startSample: take.startSample, latency: take.latency, time: time)
        guard frameCount > placement.offset else {
            try? FileManager.default.removeItem(at: source)
            return
        }
        if let buffer { samples[target.id] = buffer }
        mediaRevision += 1
        let number = store.project.media.filter { $0.name.hasPrefix("Take ") }.count + 1
        let file = MediaFile(id: target.id, name: "Take \(number)", path: target.path,
                             frameCount: frameCount, sampleRate: sampleRate)
        let region = RegionID()
        var commands: [Command] = [
            .addMedia(file),
            .placeAudio(track: track, id: region, media: file.id, start: placement.start),
        ]
        if placement.offset > 0 {
            commands.append(.trimRegion(track: track, region, offset: placement.offset,
                                        length: frameCount - placement.offset))
        }
        // A take is never refused, but one that takes the song past its memory budget is said, by
        // the files the song plays that the next open would leave silent (R9) — which, not how
        // many: a take can push one out while a leftover drops back in (second night review).
        let before = store.project
        perform(commands, title: "Record Take")
        let committed = store.project.media.contains { $0.id == file.id }
        dropBufferUnlessHeld(file.id)
        if let strandedIn {
            let line = "The take could not be moved into the song and stays in the folder \(strandedIn) in the Files app; it is missing the next time the song opens."
            lastError = lastError.map { "\($0) \(line)" } ?? line
        }
        let silenced = store.project.newlySilencedMedia(budget: AudioFileImport.songBudgetBytes, comparedTo: before)
        if buffer == nil, committed {
            // Silent now is always said; the retry only where the next open makes one. A take past
            // the budget is skipped by the next open's plan and named so in an export; a stranded
            // one is missing there, as its own line says. Never for a take the song refused (eighth
            // and ninth night reviews, 2026-10-23).
            let pastBudget = silenced.contains { $0.id == file.id }
            if strandedIn == nil { unfitMedia[target.id] = pastBudget ? .overBudget : .noFreeMemory }
            let retry = strandedIn == nil && !pastBudget ? " \(Self.noFreeMemory)" : ""
            let line = "\(file.name) is in the song but not loaded, so silent.\(retry)"
            lastError = lastError.map { "\($0) \(line)" } ?? line
        }
        if !silenced.isEmpty {
            let line = "The song now holds more audio than Echoel can keep in memory on this device; the next time it opens, \(Self.audioFiles(silenced.map(\.name))) \(silenced.count == 1 ? "stays" : "stay") silent."
            lastError = lastError.map { "\($0) \(line)" } ?? line
        }
    }

    /// A file the song refused — its track deleted while the file was read — keeps no buffer:
    /// nothing plays it, and no memory budget counts it. Kept, it stayed until the next open
    /// (ninth night review, 2026-10-23).
    private func dropBufferUnlessHeld(_ id: MediaID) {
        guard !store.project.media.contains(where: { $0.id == id }) else { return }
        guard samples.removeValue(forKey: id) != nil else { return }
        mediaRevision += 1
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

    /// Decodes the audio files of the song just opened, off the main thread, as many as fit in
    /// `AudioFileImport.songBudgetBytes` — what the song plays first (`Project.mediaLoadPlan`).
    /// The rest stay silent and the status line names them. The previous song's buffers are
    /// dropped at once; the engine's snapshot keeps any it still plays.
    private func loadMedia(of project: Project) {
        mediaLoad?.cancel()
        // An export waits for this; a song without media leaves nothing to wait for.
        mediaLoad = nil
        isLoadingMedia = false
        samples = [:]
        unfitMedia = [:]
        mediaRevision += 1
        guard let package = currentURL, !project.media.isEmpty else { return }
        let files = project.media
        let budget = AudioFileImport.songBudgetBytes
        let plan = project.mediaLoadPlan(budget: budget)
        let song = songsOpened
        // Only what the song plays is named as silent; a leftover nothing plays is not loaded and
        // not said, as the export says it (second night review, 2026-10-23).
        let audible = Set(project.audibleMedia)
        isLoadingMedia = true
        mediaLoad = Task { [weak self] in
            // Another song opening cancels this, and the decode stops after the file it is on: a
            // song switch must not wait for the last song's audio (review 2026-10-22).
            let work = Task.detached(priority: .userInitiated) { () -> (decoded: [MediaID: SampleBuffer], unfit: [MediaFile], short: [MediaFile]) in
                var decoded: [MediaID: SampleBuffer] = [:]
                var unfit = plan.skipped
                var short: [MediaFile] = []
                var used = 0
                for file in plan.load {
                    if Task.isCancelled { break }
                    guard let url = file.url(in: package) else { continue }
                    // The plan trusts the length the song states; the read is limited to the room
                    // left, so a file longer than stated is refused before it is decoded and the
                    // budget holds for a song from anywhere. The room is checked against the file's
                    // header, because the buffer is allocated at that size before it is filled: a
                    // file whose header promises more than it holds (a truncated recording) can be
                    // refused here near the budget though the plan, which counts what it plays, let
                    // it in — and is then named as not loaded, never silent without a word (sixth
                    // night review, 2026-10-23: known, rare, and safer than allocating past the budget).
                    let room = Swift.max(0, budget - used) / Project.decodedBytesPerFrame
                    let buffer: SampleBuffer
                    do {
                        buffer = try AudioFileImport.decode(url, maximumSeconds: .infinity, maximumFrames: room)
                    } catch AudioFileImport.ImportError.tooLong {
                        // Past the room: named as not loaded, the song too large.
                        unfit.append(file)
                        continue
                    } catch AudioFileImport.ImportError.noMemory {
                        // Past the memory free right now: named as not loaded, for that reason.
                        short.append(file)
                        continue
                    } catch {
                        continue
                    }
                    // What the buffer holds — what it plays, unless its block could not shrink
                    // (fourth and fifth night reviews, 2026-10-23).
                    used += buffer.heldFrames * Project.decodedBytesPerFrame
                    decoded[file.id] = buffer
                }
                return (decoded: decoded, unfit: unfit, short: short)
            }
            let loaded = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            // Not cancelled, this is still the song's load: another song's load cancels it first.
            guard let self, !Task.isCancelled else { return }
            self.isLoadingMedia = false
            // The same song followed to a new name in Files keeps what was decoded.
            guard self.songsOpened == song else { return }
            let missing = files.count - loaded.decoded.count - loaded.unfit.count - loaded.short.count
            if missing > 0 { self.log.error("media: \(missing, privacy: .public) file(s) missing or unreadable") }
            if !loaded.unfit.isEmpty {
                self.log.error("media: \(loaded.unfit.count, privacy: .public) file(s) past the song's memory budget")
            }
            if !loaded.short.isEmpty {
                self.log.error("media: \(loaded.short.count, privacy: .public) file(s) refused for want of free memory")
            }
            // Beside, not over, what the open said (a move the song still owes).
            for (left, why) in [(loaded.unfit, DocumentController.overBudget), (loaded.short, DocumentController.noFreeMemory)] {
                let silent = left.filter { audible.contains($0.id) }
                guard !silent.isEmpty else { continue }
                let line = "Not loaded, so silent: \(DocumentController.audioFiles(silent.map(\.name))). \(why)"
                self.lastError = self.lastError.map { "\($0) \(line)" } ?? line
            }
            var notLoaded: [MediaID: NotLoaded] = [:]
            for file in loaded.unfit { notLoaded[file.id] = .overBudget }
            for file in loaded.short { notLoaded[file.id] = .noFreeMemory }
            // Merged, not replaced: a take committed while this load ran keeps its mark (eighth
            // night review, 2026-10-23), as `samples` keeps its buffer below.
            self.unfitMedia.merge(notLoaded) { _, loaded in loaded }
            self.samples.merge(loaded.decoded) { current, _ in current }
            self.mediaRevision += 1
            self.followRenamedSong()
        }
    }

    func refresh() {
        songs = (try? library.list()) ?? []
    }

    // MARK: - Songs of the earlier app

    /// Once per install, when a launch that can read them is confirmed healthy in the foreground:
    /// the songs the earlier Echoelmusic app left in its App Group container and in Application
    /// Support — the one it had open and every one in its library — become songs here. Its files
    /// are only read, never changed or removed, and a song deleted here does not come back.
    private func importEarlierSongs() {
        guard isRestored, !isInBackground, !isInactive, importRun == nil, !importRanThisLaunch,
              !UserDefaults.standard.bool(forKey: Self.importedKey) else { return }
        importWait?.cancel()
        importWait = nil
        let destination = library
        let logger = log
        importRun = Task { [weak self] in
            // Off the main thread: reading and converting a long library must not hold it, or the
            // system ends the app in the middle (review 2026-10-21).
            let work = Task.detached(priority: .utility) {
                DocumentController.runImport(into: destination, log: logger)
            }
            let run = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            guard let self else { return }
            self.importRun = nil
            self.endImportBackgroundTime()
            self.refresh()
            for url in run.written { self.releaseHold(on: url) }
            self.earlierSongsWritten += run.written.count
            if !run.written.isEmpty {
                self.earlierSongsNote = self.earlierSongsWritten == 1
                    ? "One song from the earlier Echoelmusic is now in your songs."
                    : "\(self.earlierSongsWritten) songs from the earlier Echoelmusic are now in your songs."
            }
            self.importLeftOut += run.unreadable
            if run.paused {
                // It may not have reached the songs an earlier run could not save: theirs stand.
                for name in run.failed where !self.importUnsaved.contains(name) { self.importUnsaved.append(name) }
            } else {
                // It went through every place: what it could not save is what is left unsaved.
                self.importUnsaved = run.failed
            }
            self.importRetriesOnReturn = run.paused
            if run.paused {
                // Back in front before the run reached its pause point: `sceneEntered` found it
                // still under way, so the wait is armed here.
                self.armImportWait()
            } else {
                self.importRanThisLaunch = true
            }
        }
    }

    /// One run: brings over the songs not written yet and returns where they went. Every step is
    /// kept the moment it happens (`EarlierSongImport` decides), so a run the app ends in the
    /// middle loses nothing already brought over and the next launch knows which song it was on.
    nonisolated private static func runImport(into library: ProjectLibrary, log: Logger) -> EarlierImportRun {
        let defaults = UserDefaults.standard
        var state = loadImport(defaults)
        var run = EarlierImportRun()
        let began = state.runBegan()
        keep(state, defaults)
        guard began else {
            run.finished = state.isFinished
            return run
        }
        // Every place the earlier app wrote to, each song once by its key, read but not converted:
        // a song is converted only once it is marked as under way, so one that ends the app while
        // it converts is the one left out (review 2026-10-22).
        let earlier = earlierPlaces(defaults: defaults)
        var keys: [String] = []
        if Task.isCancelled {
            run.paused = true
        } else {
            keys = state.found(earlier.keys, sawEverything: earlier.sawEverything)
        }
        keep(state, defaults)
        var written: [URL] = []
        var failed: [String] = []
        var unreadable = 0
        for key in keys {
            // Leaving the foreground pauses the run here, between two songs: a run suspended with a
            // song under way, then ended by the system, would count against that song.
            if Task.isCancelled {
                run.paused = true
                break
            }
            state.willBring(key)
            keep(state, defaults)
            if let project = earlier.project(key) {
                do {
                    written.append(try bring(project, key: key, into: library, defaults))
                    state.brought(key, .written)
                } catch {
                    failed.append(project.name)
                    log.error("import of an earlier song failed — \(error.localizedDescription, privacy: .private)")
                    state.brought(key, .failed)
                }
            } else {
                unreadable += 1
                state.brought(key, .unreadable)
            }
            keep(state, defaults)
            // Only now, with the mark kept, is the package no longer the song under way.
            clearReservation(defaults)
        }
        if run.paused { state.runPaused() } else { state.runEnded() }
        keep(state, defaults)
        log.info("imported \(written.count, privacy: .public) song(s) from the earlier app, \(failed.count, privacy: .public) failed, \(unreadable, privacy: .public) unreadable\(run.paused ? ", paused" : "", privacy: .public)")
        run.written = written
        run.failed = failed
        run.unreadable = unreadable
        run.finished = state.isFinished
        return run
    }

    /// Writes one song into a package of its own. The package and the song's key are noted while
    /// the package is still empty, and stay noted until the run has kept the song's mark: an app
    /// ended in between leaves a package the next launch can tell apart — written, so the song is
    /// marked instead of brought again as "Name 2" (round 4 measurement), or not, so it goes.
    nonisolated private static func bring(_ project: Project, key: String, into library: ProjectLibrary,
                                          _ defaults: UserDefaults) throws -> URL {
        let url = try reservePackage(for: project.name, in: library)
        defaults.set(url.lastPathComponent, forKey: importReservedKey)
        defaults.set(key, forKey: importReservedSongKey)
        do {
            try library.write(project, to: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            clearReservation(defaults)
            throw error
        }
        return url
    }

    nonisolated private static func clearReservation(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: importReservedKey)
        defaults.removeObject(forKey: importReservedSongKey)
    }

    /// At launch, before the run that was under way is judged: the package it had made for the
    /// song under way when the app ended. Holding the song's document, the song came over and is
    /// marked so — it is neither brought again nor called left out. Without one it is removed,
    /// since only the import made it. `ProjectLibrary.write` replaces the document atomically, so
    /// one that is there is whole.
    nonisolated private static func settleReservedPackage(_ state: inout EarlierSongImport, in library: ProjectLibrary,
                                                          _ defaults: UserDefaults) {
        guard let name = defaults.string(forKey: importReservedKey) else { return }
        let key = defaults.string(forKey: importReservedSongKey)
        clearReservation(defaults)
        guard !name.contains("/"), (name as NSString).pathExtension == ProjectLibrary.fileExtension else { return }
        let url = library.directory.appendingPathComponent(name, isDirectory: true)
        if FileManager.default.fileExists(atPath: url.appendingPathComponent(ProjectLibrary.documentName).path) {
            if let key { state.brought(key, .written) }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// A free package for an imported song, made here and now. Made at once, not only named: the
    /// open song may be the starter, which takes its own name only on its first save — it then
    /// sees this folder and moves, instead of the two writing into one package. Not closed: a song
    /// started by hand picks its free name on the main thread and creates its folder an instant
    /// later, so a song of the same name brought over in that instant could pick the same one
    /// (review 2026-10-21; kept, since it needs both the same name and the same microseconds).
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

    nonisolated private static func loadImport(_ defaults: UserDefaults) -> EarlierSongImport {
        EarlierSongImport(isFinished: defaults.bool(forKey: importedKey),
                          done: defaults.stringArray(forKey: importedSongsKey) ?? [],
                          attempts: defaults.integer(forKey: importAttemptsKey),
                          isRunning: defaults.bool(forKey: importRunningKey),
                          current: defaults.string(forKey: importCurrentKey),
                          suspect: defaults.string(forKey: importSuspectKey))
    }

    nonisolated private static func keep(_ state: EarlierSongImport, _ defaults: UserDefaults) {
        defaults.set(state.isFinished, forKey: importedKey)
        defaults.set(state.done.sorted(), forKey: importedSongsKey)
        defaults.set(state.attempts, forKey: importAttemptsKey)
        for (value, key) in [(state.current, importCurrentKey), (state.suspect, importSuspectKey)] {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.set(state.isRunning, forKey: importRunningKey)
    }

    /// `.v2` since 2026-10-19: builds 10004–10006 ran without the App Group, found nothing and
    /// still marked the import done under the old name, so a device that ran them would never
    /// import once the group is back. The new name lets every such device look once more.
    nonisolated private static let importedKey = "studio.importedEarlierSongs.v2"
    /// The songs brought over or left out, by key. Rows of the earlier app's files were kept
    /// under another name until 2026-10-22; no build that shipped wrote either.
    nonisolated private static let importedSongsKey = "studio.importedEarlierSongKeys"
    nonisolated private static let importAttemptsKey = "studio.earlierSongImportAttempts"
    nonisolated private static let importRunningKey = "studio.earlierSongImportRunning"
    /// The song being brought over right now, by key.
    nonisolated private static let importCurrentKey = "studio.earlierSongImportCurrent"
    /// The song a run ended on once already: ending on it again leaves it out.
    nonisolated private static let importSuspectKey = "studio.earlierSongImportSuspect"
    /// The package made for the song under way, until the run has kept that song's mark.
    nonisolated private static let importReservedKey = "studio.earlierSongImportReserved"
    /// The key of the song that package is for.
    nonisolated private static let importReservedSongKey = "studio.earlierSongImportReservedSong"

    /// At every launch, before anything runs: when a run of the import was under way as the app
    /// last ended — a crash, or swiped away — what becomes of it, for the status line.
    private func earlierImportLaunchBegan() -> String? {
        let defaults = UserDefaults.standard
        var state = Self.loadImport(defaults)
        Self.settleReservedPackage(&state, in: library, defaults)
        let interruption = state.launchBegan()
        Self.keep(state, defaults)
        guard let interruption else { return nil }
        switch interruption {
        case .resumes:
            // Swiped away, or ended by the system: it simply goes on, and the status line says so
            // when songs arrive.
            log.info("a run of the import of earlier songs was interrupted — it goes on")
            return nil
        case .leftOut:
            log.error("the import of earlier songs ended twice on the same song — leaving it out")
            return "Echoel ended twice while bringing the same earlier song over, so that song is left out; the others come over as usual."
        case .givenUp:
            log.error("the import of earlier songs ended \(EarlierSongImport.attemptLimit, privacy: .public) runs in a row — not running it again")
            return "Bringing your earlier songs over did not finish after several tries, so Echoel stops trying. Any it brought over are in your songs."
        }
    }

    /// The import only ever reads the earlier app's files; a song left out here is still there.
    nonisolated private static let earlierFilesKept = "The earlier app's files are not changed."

    /// The earlier app's songs in every place it wrote to — its App Group container, and
    /// Application Support, where it wrote while the container was unavailable — each once, by
    /// key. Both are read: songs saved in either are the user's, and a song in both comes over
    /// once (review 2026-10-22).
    nonisolated private static func earlierPlaces(defaults: UserDefaults) -> EarlierPlaces {
        let fm = FileManager.default
        let container = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.echoelmusic")
        var places = EarlierPlaces(sawEverything: container != nil)
        for base in [container, fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first].compactMap({ $0 }) {
            let read = earlierSongs(in: base, defaults: defaults)
            if !read.complete { places.sawEverything = false }
            guard let songs = read.songs else { continue }
            for index in 0..<songs.count {
                guard let key = songs.key(at: index), places.at[key] == nil else { continue }
                places.keys.append(key)
                places.at[key] = (songs, index)
            }
        }
        return places
    }

    /// The open song (`Timeline/timeline.json` + `Clips/clips.json`) and the library
    /// (`Echoel/projects.json.json`, the earlier store appended `.json` to a name ending in it),
    /// read but not converted; nil when this base holds neither. `complete` is false when a file
    /// is there and could not be read: that is not a missing file, and the import must not finish
    /// on it (review 2026-10-22).
    nonisolated private static func earlierSongs(in base: URL, defaults: UserDefaults) -> (songs: LegacySong.Songs?, complete: Bool) {
        var complete = true
        var unreadable: Set<String> = []
        func read(_ path: String) -> Data? {
            let url = base.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url) else {
                complete = false
                unreadable.insert(path)
                return nil
            }
            return data
        }
        let clipsPath = "Clips/clips.json"
        let clipsFile = read(clipsPath)
        // The open song's notes are in the clips file. While it is there and cannot be read, the
        // open song waits: converted without them it would come over as an empty shell, and again,
        // whole, under another key once the file reads (review 2026-10-22).
        let timeline = unreadable.contains(clipsPath) ? nil : read("Timeline/timeline.json")
        let library = read("Echoel/projects.json.json")
        guard timeline != nil || library != nil else { return (nil, complete) }
        let clips = clipsFile ?? Data("[]".utf8)
        // The earlier app kept no song tempo; its locked tempo is the one the song was made at.
        let tempo = defaults.bool(forKey: "studio.lockBPM") ? defaults.double(forKey: "studio.lockedBPM") : Tempo.defaultBPM
        return (LegacySong.Songs(timeline: timeline, clips: clips, tempo: tempo > 0 ? tempo : Tempo.defaultBPM,
                                 library: library.map(LegacySong.libraryRows) ?? LegacySong.libraryRows(Data())), complete)
    }
}

/// The earlier app's songs found by one run, read but not converted.
private struct EarlierPlaces {
    /// Every song's key, in the order of the places and the files, each once.
    var keys: [String] = []
    /// Where each key's song is.
    var at: [String: (songs: LegacySong.Songs, index: Int)] = [:]
    /// The App Group container was there and every file in both places that exists could be read:
    /// only then may the import finish.
    var sawEverything: Bool

    func project(_ key: String) -> Project? {
        at[key].flatMap { $0.songs.project(at: $0.index) }
    }
}

/// What one run of the import of earlier songs did.
private struct EarlierImportRun: Sendable {
    var written: [URL] = []
    /// The names of the songs it read and could not write.
    var failed: [String] = []
    /// Songs it could not read: they are left out.
    var unreadable = 0
    /// It stopped between two songs because the app left the foreground.
    var paused = false
    /// The import is finished: nothing is left to bring over, or it was given up.
    var finished = false
}
