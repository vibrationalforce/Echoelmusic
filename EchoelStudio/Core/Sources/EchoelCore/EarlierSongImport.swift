import Foundation

/// The one-time import of the earlier app's songs, across launches that may end in the middle of
/// it (review 2026-10-21). A run starts only once a launch is confirmed healthy and pauses between
/// two songs when the app leaves the foreground, so the app is rarely ended while one is under
/// way; a run that was under way when the app ended anyway is found by its own mark, whatever
/// ended the app. The app keeps the values in its defaults and does the reading and writing; this
/// type only decides.
///
/// Finding no song this app can read never finishes it. A build without the App Group cannot
/// see the earlier app's container and finds nothing; the songs may become readable with a later
/// build, and looking costs a few file reads.
public struct EarlierSongImport: Equatable, Sendable {
    /// Runs in a row that bring no song over before the import stops for good.
    public static var attemptLimit: Int { 3 }

    public private(set) var isFinished: Bool
    /// The places brought over or left out, by place in the earlier app's files (which are never
    /// changed, so the places hold): a later run passes them.
    public private(set) var done: Set<Int>
    /// Runs in a row that brought no song over, counted as each run begins, so a run the app ends
    /// counts too. A run that brings a song over, or finds none to bring, starts the count anew.
    public private(set) var attempts: Int
    /// A run began and has neither ended nor paused.
    public private(set) var isRunning: Bool
    /// The song the running run is reading or writing; nil while it reads the earlier app's files
    /// and between two songs.
    public private(set) var current: Int?
    /// A place a run ended on once already: ending on it again leaves it out.
    public private(set) var suspect: Int?
    private var failures = 0

    public init(isFinished: Bool = false, done: [Int] = [], attempts: Int = 0, isRunning: Bool = false,
                current: Int? = nil, suspect: Int? = nil) {
        self.isFinished = isFinished
        self.done = Set(done.filter { $0 >= 0 })
        self.attempts = Swift.max(0, attempts)
        self.isRunning = isRunning
        self.current = current.flatMap { $0 >= 0 ? $0 : nil }
        self.suspect = suspect.flatMap { $0 >= 0 ? $0 : nil }
    }

    /// What becomes of a run the app ended in the middle of.
    public enum Interruption: Equatable, Sendable {
        /// It goes on at the next run, past what it brought over. The app also ends when it is
        /// swiped away or the system needs its memory, so an end is tried again.
        case resumes
        /// The song under way had ended a run before, so it may be what ends the app: it is left
        /// out, and the others follow.
        case leftOut
        /// It does not run again: `attemptLimit` runs in a row ended or failed without bringing a
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
        return true
    }

    /// The run read the earlier app's files: `count` places in the first location that holds a
    /// song this app can read, or 0 when none does. Returns the places to bring over, in order;
    /// when it is empty the run has ended.
    public mutating func found(_ count: Int) -> [Int] {
        guard isRunning else { return [] }
        guard count > 0 else {
            // Looking and finding nothing is not a failed run.
            attempts = 0
            isRunning = false
            return []
        }
        let places = (0..<count).filter { !done.contains($0) }
        if places.isEmpty { finish() }
        return places
    }

    /// The place read and converted next: a run that ends now ended on it.
    public mutating func willBring(_ place: Int) {
        guard isRunning, place >= 0 else { return }
        current = place
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

    public mutating func brought(_ place: Int, _ outcome: Outcome) {
        guard isRunning else { return }
        if current == place { current = nil }
        if suspect == place { suspect = nil }
        switch outcome {
        case .written:
            done.insert(place)
            attempts = 0
        case .unreadable:
            done.insert(place)
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

    /// The run went through its places. It is finished when nothing failed, or after
    /// `attemptLimit` runs in a row that brought no song over; otherwise a failure is tried again
    /// at the next run.
    public mutating func runEnded() {
        guard isRunning else { return }
        isRunning = false
        current = nil
        if failures == 0 || attempts >= Self.attemptLimit { finish() }
    }

    private mutating func finish() {
        isFinished = true
        isRunning = false
        done = []
        attempts = 0
        current = nil
        suspect = nil
        failures = 0
    }
}
