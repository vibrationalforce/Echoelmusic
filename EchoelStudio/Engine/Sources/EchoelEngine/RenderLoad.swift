import Foundation
import Synchronization

/// How hard the render callback works and whether its sample time runs on whole — measured, not
/// estimated. Two of the three clocks a live engine must keep: the compute clock (the time the
/// engine's own render took against the time its frames allow — a lower bound on the whole
/// cycle, which also runs the mixer, the output unit and the system) and the delivery clock (the
/// engine's render sample time runs on without a jump). A count of no jumps does not prove no
/// dropout: whether the hardware's losses show in that sample time is a device question. The render thread records each callback with atomic counters only — no
/// lock, no allocation; the main thread takes a reading and starts the next window.
public final class RenderLoad: @unchecked Sendable {
    /// One window of callbacks: how many there were, how many used more than half, three quarters
    /// and all of the time their frames allow, the largest share any used, and how often the
    /// render's sample time jumped (a gap or a repeat).
    public struct Reading: Equatable, Sendable {
        public var callbacks = 0
        public var overHalf = 0
        public var overThreeQuarters = 0
        public var overBudget = 0
        public var discontinuities = 0
        /// The largest share of its budget one callback used, 0 … (1 is the whole budget).
        public var peak = 0.0
        /// Callbacks whose whole output was exactly zero while the transport played: a song that
        /// is meant to sound and a run of these is a dropout the sample time cannot show. Empty
        /// bars count too, so it is a number to compare against the song, not trouble by itself.
        public var silent = 0

        public init() {}

        /// Whether the window holds a callback that missed its time or a gap in the samples.
        public var isTroubled: Bool { overBudget > 0 || discontinuities > 0 }
    }

    private let callbacks = Atomic<Int>(0)
    private let overHalf = Atomic<Int>(0)
    private let overThreeQuarters = Atomic<Int>(0)
    private let overBudget = Atomic<Int>(0)
    private let discontinuities = Atomic<Int>(0)
    private let silent = Atomic<Int>(0)
    /// The peak share in thousandths of the budget.
    private let peakPermille = Atomic<Int>(0)
    /// Render thread only: the sample time the next callback should start at, or −1.
    private var expectedSample = -1.0
    /// Set on the main thread when the graph is rebuilt: its sample time starts afresh.
    private let restarted = Atomic<Bool>(false)

    public init() {}

    /// Render thread: one callback of `frames` at `sampleRate` that took `seconds`, starting at
    /// the output's `sampleTime` when the device reported one. Non-finite or empty input counts
    /// nothing.
    public func record(seconds: Double, frames: Int, sampleRate: Double, sampleTime: Double?) {
        guard frames > 0, sampleRate.isFinite, sampleRate > 0, seconds.isFinite, seconds >= 0 else { return }
        let share = seconds * sampleRate / Double(frames)
        callbacks.add(1, ordering: .relaxed)
        if share > 0.5 { overHalf.add(1, ordering: .relaxed) }
        if share > 0.75 { overThreeQuarters.add(1, ordering: .relaxed) }
        if share > 1 { overBudget.add(1, ordering: .relaxed) }
        let permille = Int(Swift.min(share, 1_000_000) * 1_000)
        var seen = peakPermille.load(ordering: .relaxed)
        while permille > seen {
            let (exchanged, now) = peakPermille.compareExchange(expected: seen, desired: permille, ordering: .relaxed)
            if exchanged { break }
            seen = now
        }
        if restarted.exchange(false, ordering: .acquiring) { expectedSample = -1 }
        if let sampleTime, sampleTime.isFinite {
            if expectedSample >= 0, Swift.abs(sampleTime - expectedSample) > 0.5 {
                discontinuities.add(1, ordering: .relaxed)
            }
            expectedSample = sampleTime + Double(frames)
        } else {
            expectedSample = -1
        }
    }

    /// Render thread: the `count` channels of one callback's `frames` as they go to the output.
    /// While `playing`, a callback whose every sample is exactly zero is counted silent — one
    /// atomic add; the scan stops at the first sample that is not. Stopped, nothing is counted:
    /// a paused engine is meant to be silent.
    public func recordOutput(_ channels: UnsafePointer<UnsafeMutablePointer<Float>>, count: Int, frames: Int,
                             playing: Bool) {
        guard playing, count > 0, frames > 0 else { return }
        for c in 0..<count {
            let channel = channels[c]
            for i in 0..<frames where channel[i] != 0 { return }
        }
        silent.add(1, ordering: .relaxed)
    }

    /// Main thread: a rebuilt graph's sample time starts afresh, so its first callback is no jump.
    public func restart() {
        restarted.store(true, ordering: .releasing)
    }

    /// Main thread: the window since the last reading, and a fresh one begins. Each counter is
    /// taken on its own, so a callback recorded while the reading is taken can land in this window
    /// for one counter and the next for another — never in neither. The count of callbacks is
    /// taken last, so a window never shows a share of a callback it does not count.
    public func take() -> Reading {
        var reading = Reading()
        reading.overHalf = overHalf.exchange(0, ordering: .relaxed)
        reading.overThreeQuarters = overThreeQuarters.exchange(0, ordering: .relaxed)
        reading.overBudget = overBudget.exchange(0, ordering: .relaxed)
        reading.discontinuities = discontinuities.exchange(0, ordering: .relaxed)
        reading.peak = Double(peakPermille.exchange(0, ordering: .relaxed)) / 1_000
        reading.silent = silent.exchange(0, ordering: .relaxed)
        reading.callbacks = callbacks.exchange(0, ordering: .relaxed)
        return reading
    }
}
