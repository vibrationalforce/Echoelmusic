// MainThreadWatchdog.swift
// Echoel — GMMW SH-9. Does the main thread still answer, and if not, for how long?
//
// WHY THIS EXISTS. A frozen menu (10.76.48) and an iOS watchdog kill (0x8badf00d, SIGKILL) both
// end the diag log in silence: the signal handler never runs for a SIGKILL, and nothing on the
// main thread can write while the main thread is the thing that hangs. So the log could not tell
// "the main thread stopped answering for nine seconds and iOS killed it" from "the app was
// idle". This watcher stands OUTSIDE the main thread: a utility-queue timer sends a tiny block to
// the main queue every `pingSeconds` and notes when it ran. A block that has not run after
// `stallSeconds` is a stall, and the line is written WHILE the stall lasts — from the utility
// queue — so a log that ends in a stall says so.
//
// WHAT IT WRITES — transitions only, plus one summary line every `summarySeconds`:
//   main: watch on — ping 250 ms, stall at 1.0 s, launch
//   main: stalled — no answer for 1.0 s
//   main: still stalled — no answer for 2.0 s       (again at 4, 8, 16 … s: doubling, bounded)
//   main: recovered — answered after 9.3 s
//   main: 30 s — answered 119, worst 14 ms, stalls 0
//   main: watch off — background
// A stall shorter than one tick can only be seen on its answer; it still counts and writes ONE
// line (`… (not seen while it lasted)`), so the stall count never misses one.
//
// ⚠️ SCOPE, stated so a quiet log is not read as more than it is. It catches EXECUTOR FLOODS and
// long main-thread work — anything that keeps a block queued on the main queue from running
// (10.76.48: a `Task { @MainActor }` per camera frame starved the main executor; main-actor jobs
// and this block share that queue, FIFO). It does NOT catch body-rebuild churn (10.76.41/50): a
// view body rebuilt ten times a second answers every ping in a few milliseconds while it tears
// down an open menu. That class stays the ancestor-read law (`TheMenuHostReadsNoHotStateTests`).
// Apple's tools call 250 ms a hang; this watcher calls 1 s a STALL — the line is for a freeze a
// person notices, and anything shorter shows up as the summary's `worst`.
//
// ⚠️ ISOLATION. The owner is a plain `@unchecked Sendable` class, never `@MainActor`, and holds
// nothing `@Observable`: it publishes nothing to SwiftUI, so it can never become a hot read
// itself. All its state is confined to its own serial queue; the main-queue block only reads the
// clock and hops back. Every closure handed to Dispatch is spelled `@Sendable` (the build-2613
// trap: a closure formed on the main actor and called on a worker traps at its entry).
//
// LIFECYCLE. `start()` at `startup 4/4` (the studio only — Safe Mode and onboarding never reach
// it), `pause(reason:)` on `.background` (a suspended process would read as one long stall),
// `resume()` on `.active` (a no-op unless `start()` ran). Guard: `TheMainThreadIsWatchedTests`.

import Foundation

/// The pure half: what a run of pings and answers means, as diag-log lines. Times are seconds on
/// one monotonic clock; the caller owns the clock, so a test drives it without waiting.
struct MainThreadLatencyLedger: Sendable, Equatable {

    /// How often a tick runs and, when none is outstanding, a ping is sent.
    static let pingSeconds = 0.25
    /// A ping unanswered for this long is a stall. Later lines follow at 2×, 4×, 8× … of it.
    static let stallSeconds = 1.0
    /// One summary line per window, so a quiet log still shows the watch was alive.
    static let summarySeconds = 30.0
    static let linePrefix = "main: "

    private var outstandingID: Int?
    private var outstandingSentAt = 0.0
    private var nextID = 0
    /// Whether the outstanding ping has written a stall line, and the wait that writes the next.
    private var stalled = false
    private var nextStallLine = MainThreadLatencyLedger.stallSeconds
    private var windowStart: Double
    private var answeredInWindow = 0
    private var worstLagInWindow = 0.0
    private var stallsInWindow = 0

    init(startedAt now: Double) {
        windowStart = now.isFinite ? now : 0
    }

    /// One timer tick at `now`. Returns the id of a ping to send now (nil while one is still
    /// waiting — a stalled main queue is never handed a second block), and the lines to write.
    mutating func tick(at now: Double) -> (ping: Int?, lines: [String]) {
        guard now.isFinite else { return (nil, []) }
        var lines: [String] = []
        if outstandingID != nil {
            let waited = Swift.max(0, now - outstandingSentAt)
            if waited >= nextStallLine {
                if stalled {
                    lines.append(Self.linePrefix + "still stalled — no answer for \(Self.duration(waited))")
                } else {
                    stalled = true
                    stallsInWindow += 1
                    lines.append(Self.linePrefix + "stalled — no answer for \(Self.duration(waited))")
                }
                // A late tick may have skipped rungs; the next line waits for the next doubling
                // above what was just reported, never for one already passed. Terminates: the
                // wait is finite and the rung doubles.
                while waited >= nextStallLine { nextStallLine *= 2 }
            }
        }
        if now - windowStart >= Self.summarySeconds {
            var worst = worstLagInWindow
            if outstandingID != nil { worst = Swift.max(worst, now - outstandingSentAt) }
            lines.append(Self.linePrefix + "\(Int(Self.summarySeconds)) s — answered \(answeredInWindow), "
                         + "worst \(Self.duration(worst)), stalls \(stallsInWindow)")
            windowStart = now
            answeredInWindow = 0
            worstLagInWindow = 0
            stallsInWindow = 0
        }
        guard outstandingID == nil else { return (nil, lines) }
        nextID += 1
        outstandingID = nextID
        outstandingSentAt = now
        return (nextID, lines)
    }

    /// The main queue ran ping `id` at `time`. An answer to any other id (one sent before a
    /// pause) changes nothing.
    mutating func answer(_ id: Int, at time: Double) -> [String] {
        guard id == outstandingID, time.isFinite else { return [] }
        let lag = Swift.max(0, time - outstandingSentAt)
        outstandingID = nil
        answeredInWindow += 1
        worstLagInWindow = Swift.max(worstLagInWindow, lag)
        let wasStalled = stalled
        stalled = false
        nextStallLine = Self.stallSeconds
        if wasStalled {
            return [Self.linePrefix + "recovered — answered after \(Self.duration(lag))"]
        }
        guard lag >= Self.stallSeconds else { return [] }
        stallsInWindow += 1
        return [Self.linePrefix + "recovered — answered after \(Self.duration(lag)) (not seen while it lasted)"]
    }

    /// Whole milliseconds below a second, tenths of a second from there on.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "?" }
        let milliseconds = (Swift.max(0, seconds) * 1000).rounded()
        if milliseconds < 1000 { return "\(Int(milliseconds)) ms" }
        return String(format: "%.1f s", seconds)
    }
}

/// The impure half: the timer, the main-queue ping, and the diag-log sink.
final class MainThreadWatchdog: @unchecked Sendable {

    static let shared = MainThreadWatchdog()

    private let queue = DispatchQueue(label: "com.echoelmusic.main-watchdog", qos: .utility)
    // Confined to `queue`.
    private var timer: DispatchSourceTimer?
    private var ledger: MainThreadLatencyLedger?
    private var armed = false
    /// Bumped by every `run`: an answer to a ping sent before a pause belongs to no ledger.
    private var generation = 0

    private init() {}

    /// Arm the watch and run it. Called once, at `startup 4/4`.
    func start() {
        queue.async { @Sendable in
            self.armed = true
            self.run(reason: "launch")
        }
    }

    /// Stop the timer (an answer still in flight is ignored). The watch stays armed.
    func pause(reason: String) {
        queue.async { @Sendable in
            guard let timer = self.timer else { return }
            timer.cancel()
            self.timer = nil
            self.ledger = nil
            EchoelCrashLog.breadcrumb(MainThreadLatencyLedger.linePrefix + "watch off — \(reason)")
        }
    }

    /// Run again after a pause — only if `start()` armed the watch.
    func resume() {
        queue.async { @Sendable in
            guard self.armed else { return }
            self.run(reason: "foreground")
        }
    }

    // MARK: - Queue only

    private func run(reason: String) {
        guard timer == nil else { return }
        generation += 1
        ledger = MainThreadLatencyLedger(startedAt: Self.now())
        EchoelCrashLog.breadcrumb(MainThreadLatencyLedger.linePrefix
            + "watch on — ping \(MainThreadLatencyLedger.duration(MainThreadLatencyLedger.pingSeconds)), "
            + "stall at \(MainThreadLatencyLedger.duration(MainThreadLatencyLedger.stallSeconds)), \(reason)")
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + MainThreadLatencyLedger.pingSeconds,
                        repeating: MainThreadLatencyLedger.pingSeconds,
                        leeway: .milliseconds(50))
        source.setEventHandler { @Sendable [weak self] in self?.tick() }
        timer = source
        source.resume()
    }

    private func tick() {
        guard var current = ledger else { return }
        let (ping, lines) = current.tick(at: Self.now())
        ledger = current
        for line in lines { EchoelCrashLog.breadcrumb(line) }
        guard let id = ping else { return }
        let sentIn = generation
        DispatchQueue.main.async { @Sendable in
            let answeredAt = Self.now()
            self.queue.async { @Sendable in self.answer(id, at: answeredAt, generation: sentIn) }
        }
    }

    private func answer(_ id: Int, at time: Double, generation sentIn: Int) {
        guard sentIn == generation, var current = ledger else { return }
        let lines = current.answer(id, at: time)
        ledger = current
        for line in lines { EchoelCrashLog.breadcrumb(line) }
    }

    /// Seconds on the monotonic uptime clock (it stops while the device sleeps; the watch is
    /// paused before that can matter).
    private static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }
}
