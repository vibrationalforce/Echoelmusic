import Foundation

/// The one-time import of the earlier app's songs, across launches that may end in the middle of
/// it (review 2026-10-21). A run starts only once a launch is confirmed healthy and pauses between
/// two songs when the app leaves the foreground, so the app is rarely ended while one is under
/// way; a run that was under way when the app ended anyway is found by its own mark, whatever
/// ended the app. The app keeps the values in its defaults and does the reading and writing; this
/// type only decides.
///
/// A song is named by its key (`LegacySong.Songs.key(at:)`), a digest of what the earlier app
/// wrote for it, not by where it sits: the earlier app put every newly saved song first, so a
/// number named another song once it ran again, and a file that could not be read moved every
/// song after it (review 2026-10-22).
///
/// Finding no song never finishes it, and neither does a run that could not see everything: a
/// build without the App Group cannot see the earlier app's container, and a file that exists
/// but cannot be read now may be readable at the next start. Looking costs a few file reads.
public struct EarlierSongImport: Equatable, Sendable {
    /// Runs in a row the app ended in the middle of before the import stops for good: trying
    /// again could end every launch.
    public static var attemptLimit: Int { 3 }

    public private(set) var isFinished: Bool
    /// The songs brought over or left out, by key: a later run passes them.
    public private(set) var done: Set<String>
    /// Runs in a row that did not end, counted as each run begins, so a run the app ends counts.
    /// A run that ends, or brings a song over, starts the count anew. Songs that could not be
    /// written do not count: a full disk is tried again at the next start, as long as it lasts,
    /// and space freed later still brings them over (review 2026-10-22).
    public private(set) var attempts: Int
    /// A run began and has neither ended nor paused.
    public private(set) var isRunning: Bool
    /// The song the running run is reading or writing; nil while it reads the earlier app's files
    /// and between two songs.
    public private(set) var current: String?
    /// A song a run ended on once already: ending on it again leaves it out.
    public private(set) var suspect: String?
    private var failures = 0
    /// The running run saw every place the earlier app writes to, so it may finish.
    private var sawEverything = false

    public init(isFinished: Bool = false, done: [String] = [], attempts: Int = 0, isRunning: Bool = false,
                current: String? = nil, suspect: String? = nil) {
        self.isFinished = isFinished
        self.done = Set(done.filter { !$0.isEmpty })
        self.attempts = Swift.max(0, attempts)
        self.isRunning = isRunning
        self.current = current.flatMap { $0.isEmpty ? nil : $0 }
        self.suspect = suspect.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// What becomes of a run the app ended in the middle of.
    public enum Interruption: Equatable, Sendable {
        /// It goes on at the next run, past what it brought over. The app also ends when it is
        /// swiped away or the system needs its memory, so an end is tried again.
        case resumes
        /// The song under way had ended a run before, so it may be what ends the app: it is left
        /// out, and the others follow.
        case leftOut
        /// It does not run again: the app ended `attemptLimit` runs in a row before they brought a
        /// song over. Tried again, it could end every launch. The earlier app's files are only ever
        /// read, so nothing of them is lost.
        case givenUp
    }

    /// At the start of every launch, before anything runs. Says what becomes of the import when a
    /// run was under way as the app last ended; nil when none was.
    public mutating func launchBegan() -> Interruption? {
        guard isRunning else { return nil }
        isRunning = false
        defer { current = nil }
        guard !isFinished else { return nil }
        guard attempts < Self.attemptLimit else {
            finish()
            return .givenUp
        }
        guard let underway = current else { return .resumes }
        guard suspect == underway else {
            suspect = underway
            return .resumes
        }
        done.insert(underway)
        suspect = nil
        return .leftOut
    }

    /// A run starts and counts. False when there is nothing to do: the import is finished, or a
    /// run is already under way.
    public mutating func runBegan() -> Bool {
        guard !isFinished, !isRunning else { return false }
        attempts += 1
        guard attempts <= Self.attemptLimit else {
            finish()
            return false
        }
        isRunning = true
        current = nil
        failures = 0
        sawEverything = false
        return true
    }

    /// The run read the earlier app's files: the key of every song in every place it wrote to,
    /// in order, and whether it could see all of them. Returns the songs to bring over, each once;
    /// when it is empty the run has ended.
    public mutating func found(_ keys: [String], sawEverything: Bool) -> [String] {
        guard isRunning else { return [] }
        var seen = Set<String>()
        let open = keys.filter { !$0.isEmpty && !done.contains($0) && seen.insert($0).inserted }
        guard open.isEmpty else {
            self.sawEverything = sawEverything
            return open
        }
        if sawEverything, !keys.isEmpty {
            finish()
        } else {
            // Looking and finding nothing, or nothing new in a part of the places, is not a failed
            // run and does not finish the import.
            attempts = 0
            isRunning = false
        }
        return []
    }

    /// The song read and converted next: a run that ends now ended on it.
    public mutating func willBring(_ key: String) {
        guard isRunning, !key.isEmpty else { return }
        current = key
    }

    /// What came of one place.
    public enum Outcome: Equatable, Sendable {
        /// Written into the library.
        case written
        /// It cannot be read here; it is left out, as the earlier app's own reader would.
        case unreadable
        /// Reading it worked and writing it did not (a full disk, a locked folder): it is tried
        /// again at a later run.
        case failed
    }

    public mutating func brought(_ key: String, _ outcome: Outcome) {
        guard isRunning, !key.isEmpty else { return }
        if current == key { current = nil }
        if suspect == key { suspect = nil }
        switch outcome {
        case .written:
            done.insert(key)
            attempts = 0
        case .unreadable:
            done.insert(key)
        case .failed:
            failures += 1
        }
    }

    /// The run stops between two songs because the app leaves the foreground; the next run goes
    /// on where it stopped. A pause is not a failed run, so it does not count.
    public mutating func runPaused() {
        guard isRunning else { return }
        isRunning = false
        current = nil
        attempts = Swift.max(0, attempts - 1)
    }

    /// The run went through its songs without the app ending, so the count starts anew. It is
    /// finished when nothing failed and it saw every place; a song that could not be written is
    /// tried again at the next start.
    public mutating func runEnded() {
        guard isRunning else { return }
        isRunning = false
        current = nil
        attempts = 0
        if failures == 0, sawEverything { finish() }
    }

    private mutating func finish() {
        isFinished = true
        isRunning = false
        done = []
        attempts = 0
        current = nil
        suspect = nil
        failures = 0
        sawEverything = false
    }
}
