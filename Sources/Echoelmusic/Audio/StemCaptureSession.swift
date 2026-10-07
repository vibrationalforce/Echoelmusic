#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Spatial S-A3c-2a (ADR-008 §2–§5, accepted 2026-10-04): the ONE owner of a stem take. It builds a
/// ring per stem, arms every voice's `StemTapPoint`, drains the rings to disk on a timer while the
/// take runs, and on `stop()` disarms, waits until no render pass can still hold a ring, drains
/// the rest and cuts every stem file to one length.
///
/// THE RULES (each one a decision, not a default):
/// · **One exclusive serial owner context.** Arming, disarming, the drain timer and `finish` all
///   run on the session's private serial queue. That is the owner context `StemTapPoint` and
///   `StemFileWriter` require — EXCLUSIVE, not a fixed thread: a serial queue guarantees that no
///   two owner calls overlap and that each happens-before the next, never which thread runs them.
///   Nothing here runs on the audio thread.
/// · **A tap has ONE session.** Taps are claimed for the life of a take (`tapBusy` for a second
///   session), and the same tap twice in one take is refused (`duplicateTap`) — two owners would
///   call the tap's owner side concurrently.
/// · **Everything is checked before anything is touched.** Duplicate taps and stem names that
///   collide as FILE names (`fileSafe`, case-folded — a mono "Pad L" beside a stereo "Pad") are
///   refused before the directory is created; every tap must then be free (not armed, nothing
///   retired) before any is armed. A refused take arms nothing and leaves no file behind.
/// · **Mono voices are armed MONO** (S-A3b-2 note L-g): a mono voice writes only buffer 0, and a
///   stereo target on a two-buffer fallback node would copy unwritten memory into the right ring.
///   A stereo source gets two stems, "<name> L" and "<name> R".
/// · **The take never ends while a render pass can hold a ring.** `stop()` waits for every tap to
///   be quiescent before the last drain; past `quiescenceTimeout` it throws. A ring is never freed
///   under a render on ANY path: a tap keeps its retired target alive until the next owner finds
///   it quiescent, so `abort()`, a failed `stop()` and `deinit` disarm without waiting.
/// · **Interruptions are LOUD.** `Outcome.isClean` is false on any lost frame, gap, refused jump,
///   invalid timestamp or interleaved block — the exporter must not ship such a take as a stem
///   set (ADR-008: ring overflow, interruption or route change abort, never silently). A take
///   that ends without an `Outcome` (thrown, aborted, dropped) deletes the files it opened.
///
/// ⚠️ THE OWNER KEEPS THE SESSION until `stop()` or `abort()` returns. Dropping a running session
/// is survivable — `deinit` disarms, deletes the files and frees the taps — but it is a lost take,
/// not a way to end one.
///
/// ⚠️ THE START TIME IS THE CALLER'S, and it must sit slightly AHEAD of the render timeline
/// (less than one ring): a block that straddles it is trimmed to it (counted as overlap, kept
/// silent), while a start the render has already passed leaves a head gap and an unclean take.
/// Whether a source node's render timestamp shares the engine's output timeline is UNVERIFIED
/// (ADR-008 §1) — the impulse test at G-D answers it.
///
/// ⚠️ THE END is the last frame any stem received; a stem that rendered less is padded with
/// silence to it and the fill is reported (`paddedFrames`), not treated as a failure — a voice
/// that was never attached is a silent stem, honestly.
///
/// ⚠️ LEVEL: stems are PRE-FADER (K2). Mixer level and mute are the exporter's (S-A3c-2b).
///
/// Built: yes. Wired: NO — nothing constructs a session yet (S-A3c-2b: flag, reader, door).
/// Device: no.
final class StemCaptureSession: @unchecked Sendable {

    enum Channels: Sendable { case mono, stereo }

    struct Source {
        let name: String
        let tap: StemTapPoint
        let channels: Channels
    }

    struct Outcome: Sendable {
        let stems: [StemFileWriter.StemReport]
        let files: [URL]
        /// Blocks the taps skipped during this take because the engine gave no valid time.
        let invalidTimeBlocks: Int64
        /// Blocks the taps refused during this take because a buffer was interleaved.
        let interleavedBlocks: Int64

        /// True only when every stem holds exactly what the voices rendered, in place.
        var isClean: Bool {
            invalidTimeBlocks == 0 && interleavedBlocks == 0 && stems.allSatisfy {
                $0.silencedFrames == 0 && $0.gapFrames == 0 && $0.discontinuities == 0
            }
        }
    }

    enum SessionError: Error, Equatable {
        case noSources
        case alreadyStarted
        case notRunning
        case tapBusy
        case duplicateTap
        case nameCollision
        case quiescenceTimeout
    }

    private enum State { case idle, running, ended }

    /// The taps every live session owns. Lock-protected; touched only at start and at teardown.
    fileprivate final class TapClaims: @unchecked Sendable {
        private let lock = NSLock()
        private var owned = Set<ObjectIdentifier>()

        func claim(_ ids: [ObjectIdentifier]) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard owned.isDisjoint(with: ids) else { return false }
            owned.formUnion(ids)
            return true
        }

        func release(_ ids: [ObjectIdentifier]) {
            lock.lock(); defer { lock.unlock() }
            owned.subtract(ids)
        }
    }

    private static let claims = TapClaims()

    private let sources: [Source]
    private let directory: URL
    private let sampleRate: Double
    private let ringFrames: Int
    private let drainInterval: TimeInterval?
    private let quiescenceTimeout: TimeInterval
    private let queue = DispatchQueue(label: "com.echoelmusic.stem-capture")

    // Queue-confined (and touched by `deinit` only once no other reference exists).
    private var state = State.idle
    private var claimed: [ObjectIdentifier] = []
    private var armedTaps: [StemTapPoint] = []
    private var targets: [StemTapTarget] = []
    private var writer: StemFileWriter?
    private var stemURLs: [URL] = []
    private var timer: DispatchSourceTimer?
    private var drainError: Error?
    private var invalidBaseline: [Int64] = []
    private var interleavedBaseline: [Int64] = []

    /// `ringFrames` defaults to ~2 s at `sampleRate` (ADR-008 sizing). The drain interval is held
    /// to a quarter of the ring so a timely writer never falls a ring behind — but never below
    /// 5 ms, so a ring shorter than 20 ms gets NO such guarantee from the timer: size the ring,
    /// not the interval. `drainInterval: nil` runs no timer — the owner then drains with
    /// `drainNow()` from a poll it already has.
    init(sources: [Source], directory: URL, sampleRate: Double, ringFrames: Int? = nil,
         drainInterval: TimeInterval? = 0.25, quiescenceTimeout: TimeInterval = 1.0) {
        self.sources = sources
        self.directory = directory
        self.sampleRate = sampleRate
        let defaultFrames = sampleRate.isFinite && sampleRate > 0 ? Int(min(sampleRate * 2, Double(StemCaptureRing.maximumCapacityFrames))) : 0
        self.ringFrames = max(ringFrames ?? defaultFrames, StemCaptureRing.minimumCapacityFrames)
        let ringSeconds = sampleRate.isFinite && sampleRate > 0 ? Double(self.ringFrames) / sampleRate : 0
        self.drainInterval = drainInterval.map { max(0.005, min($0, ringSeconds / 4)) }
        self.quiescenceTimeout = max(0, quiescenceTimeout)
    }

    deinit {
        // The last reference is gone, so nothing else can reach this session: `deinit` IS the
        // exclusive owner context here (the timer holds the session weakly).
        if state == .running || !claimed.isEmpty { tearDown(removingFiles: true) }
    }

    // MARK: Start

    /// Builds the rings, opens the stem files and arms every tap at `startSampleTime`.
    func start(atSampleTime startSampleTime: Int64) throws {
        try queue.sync { try startOnQueue(startSampleTime) }
    }

    /// One stem name per ring, in source order — the names the files will carry.
    private var stemNames: [[String]] {
        sources.map { source in
            let name = Self.fileSafe(source.name)
            switch source.channels {
            case .mono: return [name]
            case .stereo: return [name + " L", name + " R"]
            }
        }
    }

    private func startOnQueue(_ start: Int64) throws {
        guard state == .idle else { throw SessionError.alreadyStarted }
        guard !sources.isEmpty else { throw SessionError.noSources }
        let ids = sources.map { ObjectIdentifier($0.tap) }
        guard Set(ids).count == ids.count else { throw SessionError.duplicateTap }
        let names = stemNames
        let flatNames = names.flatMap { $0 }
        guard Set(flatNames.map { $0.lowercased() }).count == flatNames.count else {
            throw SessionError.nameCollision
        }
        guard Self.claims.claim(ids) else { throw SessionError.tapBusy }
        claimed = ids

        do {
            // This session is now each tap's owner: a target an EARLIER owner retired may be
            // released here, once no render pass can hold it.
            guard sources.allSatisfy({ $0.tap.releaseRetiredIfQuiescent() && !$0.tap.isArmed }) else {
                throw SessionError.tapBusy
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            var stems: [StemFileWriter.Stem] = []
            var builtTargets: [StemTapTarget] = []
            for (source, stemName) in zip(sources, names) {
                let left = StemCaptureRing(capacityFrames: ringFrames, startSampleTime: start)
                stems.append(stem(stemName[0], left))
                switch source.channels {
                case .mono:
                    builtTargets.append(StemTapTarget(left: left, right: nil))
                case .stereo:
                    let right = StemCaptureRing(capacityFrames: ringFrames, startSampleTime: start)
                    stems.append(stem(stemName[1], right))
                    builtTargets.append(StemTapTarget(left: left, right: right))
                }
            }
            stemURLs = stems.map(\.url)                     // set first: a failed open is cleaned up
            writer = try StemFileWriter(stems: stems, sampleRate: sampleRate)
            targets = builtTargets
            invalidBaseline = sources.map(\.tap.invalidTimeBlocks)
            interleavedBaseline = sources.map(\.tap.interleavedBlocks)
            for (source, target) in zip(sources, builtTargets) {
                guard source.tap.arm(target) else { throw SessionError.tapBusy }
                armedTaps.append(source.tap)
            }
        } catch {
            tearDown(removingFiles: true)                   // the session stays idle: a retry may start
            throw error
        }
        state = .running

        guard let drainInterval else { return }
        let tick = DispatchSource.makeTimerSource(queue: queue)
        tick.schedule(deadline: .now() + drainInterval, repeating: drainInterval)
        tick.setEventHandler { [weak self] in self?.drainTick() }
        tick.resume()
        timer = tick
    }

    private func stem(_ name: String, _ ring: StemCaptureRing) -> StemFileWriter.Stem {
        StemFileWriter.Stem(name: name, ring: ring, url: directory.appendingPathComponent(name + ".wav"))
    }

    // MARK: Running

    private func drainTick() {
        guard state == .running, drainError == nil, let writer else { return }
        do {
            try writer.drainAvailable()
        } catch {
            drainError = error                               // stop() reports it; keep the taps armed until then
            timer?.cancel()
            timer = nil
        }
    }

    /// Drains what the voices have published so far, now, instead of waiting for the timer.
    @discardableResult
    func drainNow() throws -> Int64 {
        try queue.sync {
            guard state == .running, let writer else { throw SessionError.notRunning }
            if let drainError { throw drainError }
            return try writer.drainAvailable()
        }
    }

    // MARK: Stop

    /// Ends the take: disarms every tap, waits until no render pass can hold a ring, writes the
    /// rest and closes every stem file at one common length. Runs on the session queue; the
    /// caller's thread is free while it waits. A throw leaves no stem files behind.
    func stop() async throws -> Outcome {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Outcome, Error>) in
            queue.async {
                continuation.resume(with: Swift.Result { try self.stopOnQueue() })
            }
        }
    }

    private func stopOnQueue() throws -> Outcome {
        guard state == .running, let writer else { throw SessionError.notRunning }
        state = .ended
        timer?.cancel()
        timer = nil
        do {
            guard disarmAndSettle(until: Date().addingTimeInterval(quiescenceTimeout)) else {
                throw SessionError.quiescenceTimeout          // the taps keep the rings alive
            }
            if let drainError { throw drainError }

            try writer.drainAvailable()
            let end = targets.reduce(writer.startSampleTime) { latest, target in
                max(latest, target.left.readSampleTime, target.right?.readSampleTime ?? latest)
            }
            let reports = try writer.finish(endSampleTime: end)
            var invalid: Int64 = 0
            var interleaved: Int64 = 0
            for index in sources.indices {
                invalid += sources[index].tap.invalidTimeBlocks - invalidBaseline[index]
                interleaved += sources[index].tap.interleavedBlocks - interleavedBaseline[index]
            }
            let outcome = Outcome(stems: reports, files: stemURLs,
                                  invalidTimeBlocks: invalid, interleavedBlocks: interleaved)
            tearDown(removingFiles: false)
            return outcome
        } catch {
            tearDown(removingFiles: true)
            throw error
        }
    }

    // MARK: Abort

    /// Ends the take WITHOUT a stem set: disarms every tap, deletes the files this take opened and
    /// frees the taps for the next take. It does not wait — a render pass still inside a ring keeps
    /// it alive through its tap, and the next owner releases it once quiescent.
    func abort() {
        queue.sync {
            guard state == .running else { return }
            state = .ended
            tearDown(removingFiles: true)
        }
    }

    // MARK: Teardown

    /// Disarms every tap this session armed and waits — until `deadline` — for no render pass to
    /// hold a ring. Each `disarm` is checked: it refuses only while an earlier retired target is
    /// not quiescent, and then the loop waits for that pass to leave.
    private func disarmAndSettle(until deadline: Date) -> Bool {
        for tap in armedTaps {
            while !tap.disarm() {
                guard Date() < deadline else { return false }
                Thread.sleep(forTimeInterval: 0.0005)
            }
        }
        while !armedTaps.allSatisfy({ $0.releaseRetiredIfQuiescent() }) {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: 0.0005)
        }
        armedTaps = []
        return true
    }

    /// The one cleanup every ending shares. Never frees a ring a render can hold: a tap that is
    /// not yet quiescent keeps its retired target, and the next owner releases it.
    private func tearDown(removingFiles: Bool) {
        timer?.cancel()
        timer = nil
        _ = disarmAndSettle(until: .distantPast)            // disarm now; one release attempt, no wait
        armedTaps = []
        writer = nil                                        // closes the files before they are removed
        targets = []
        if removingFiles {
            for url in stemURLs { try? FileManager.default.removeItem(at: url) }
        }
        stemURLs = []
        Self.claims.release(claimed)
        claimed = []
    }

    /// A stem name as a file name: path and reserved characters become dashes.
    static func fileSafe(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .filter { !$0.isEmpty }.joined(separator: "-")
        return cleaned.isEmpty ? "Stem" : cleaned
    }
}
#endif
