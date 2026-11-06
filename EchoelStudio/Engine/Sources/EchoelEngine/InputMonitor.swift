import Foundation
import Synchronization

/// Carries the interface's inputs from the input callback to the render thread, one ring per
/// channel, so a track can play what comes in through its own strip. The input and the output
/// run on separate callbacks with their own clocks: the reader keeps at most `slack` samples
/// waiting and throws the rest away, so the delay never grows, and plays silence for what has
/// not arrived yet. No locks, no allocation after `init`.
///
/// The two sides of a stereo pair are read as a group (`read(group:into:stride:frames:)`): each
/// ring gives up and plays the same count. It is lined up again at every read that falls between
/// two blocks of the input callback (`writeBlock(_:)`): a no-op while it is lined up, and the repair
/// when a block reached one side and not the other (a ring that overflowed, a snapshot the render
/// never took). Inside a block the left could already hold a block the right has not got yet, so
/// there it only plays what both hold.
public final class InputMonitor: @unchecked Sendable {
    /// Inputs that can be monitored; a track on a higher input records but is not heard.
    public static let channelLimit = 16
    /// Samples a monitored input may lag behind the output before the excess is dropped.
    public static let slack = 512

    private let rings: [AudioRing]
    private let wanted = Atomic<UInt32>(0)
    /// Odd while the input callback writes a block (a sequence lock): the render thread lines a
    /// group up only when it read every ring's count between two blocks.
    private let blocks = Atomic<Int>(0)
    /// Render thread only: the group each ring was last lined up in, 0 when it was read alone.
    private let linedUp: UnsafeMutablePointer<UInt32>
    /// Render thread only: each ring's count, taken between two blocks while lining up.
    private let counts: UnsafeMutablePointer<Int>

    public init(capacity: Int = 8_192) {
        rings = (0..<Self.channelLimit).map { _ in AudioRing(capacity: capacity) }
        linedUp = .allocate(capacity: Self.channelLimit)
        linedUp.initialize(repeating: 0, count: Self.channelLimit)
        counts = .allocate(capacity: Self.channelLimit)
        counts.initialize(repeating: 0, count: Self.channelLimit)
    }

    deinit {
        linedUp.deallocate()
        counts.deallocate()
    }

    /// Main thread: the inputs a snapshot plays, so the input callback copies only those.
    public func want(_ channels: some Sequence<Int>) {
        var mask: UInt32 = 0
        for channel in channels where (0..<Self.channelLimit).contains(channel) { mask |= 1 << UInt32(channel) }
        wanted.store(mask, ordering: .releasing)
    }

    /// Input callback: whether `channel` is played by anything.
    public func isWanted(_ channel: Int) -> Bool {
        guard (0..<Self.channelLimit).contains(channel) else { return false }
        return wanted.load(ordering: .acquiring) & (1 << UInt32(channel)) != 0
    }

    /// Input callback: samples of one input as they arrived.
    public func write(channel: Int, _ samples: UnsafePointer<Float>, count: Int) {
        guard isWanted(channel) else { return }
        rings[channel].write(samples, count: count)
    }

    /// Input callback: one block of every input, written by `body` through `write(channel:_:count:)`.
    /// A group is lined up only between two blocks, never inside one.
    public func writeBlock(_ body: () -> Void) {
        blocks.add(1, ordering: .acquiringAndReleasing)
        body()
        blocks.add(1, ordering: .releasing)
    }

    /// Render thread: the next `frames` samples of `channel` into `destination`; what has not
    /// arrived is silence. Returns how many were real. A ring read alone is no longer lined up
    /// with any other.
    @discardableResult
    public func read(channel: Int, into destination: UnsafeMutablePointer<Float>, frames: Int) -> Int {
        guard frames > 0 else { return 0 }
        guard (0..<Self.channelLimit).contains(channel) else {
            destination.update(repeating: 0, count: frames)
            return 0
        }
        linedUp[channel] = 0
        let ring = rings[channel]
        let excess = ring.available - frames - Self.slack
        if excess > 0 { ring.discard(excess) }
        let got = ring.read(into: destination, count: frames)
        if got < frames { (destination + got).update(repeating: 0, count: frames - got) }
        return got
    }

    /// Render thread: the next `frames` samples of every input in `group` (a bit per input), each
    /// to `destination + input * stride`. The inputs of a group give up and play the same count —
    /// what all of them hold — so they stay lined up sample for sample; what has not arrived on
    /// every one is silence on all. Between two blocks the group is lined up first, from what each
    /// ring holds; inside a block a group that was lined up plays on, and one that never was stays
    /// silent for this chunk. An input the interface never delivers keeps its whole group silent.
    /// Groups read in one chunk must not share an input. Returns how many were real.
    @discardableResult
    public func read(group: UInt32, into destination: UnsafeMutablePointer<Float>, stride: Int, frames: Int) -> Int {
        let group = group & (UInt32.max >> UInt32(32 - Self.channelLimit))
        guard frames > 0, stride >= frames, group != 0 else { return 0 }
        guard group.nonzeroBitCount > 1 else {
            let channel = group.trailingZeroBitCount
            return read(channel: channel, into: destination + channel * stride, frames: frames)
        }
        var lined = true
        for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
            lined = lined && linedUp[channel] == group
        }
        guard lineUp(group) || lined else {
            for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
                (destination + channel * stride).update(repeating: 0, count: frames)
            }
            return 0
        }
        var held = Int.max
        for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
            held = Swift.min(held, rings[channel].available)
        }
        let excess = held - frames - Self.slack
        let got = Swift.min(frames, held)
        for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
            let ring = rings[channel], into = destination + channel * stride
            if excess > 0 { ring.discard(excess) }
            // Every ring holds at least `held`: the input callback only ever adds.
            let copied = ring.read(into: into, count: got)
            if copied < frames { (into + copied).update(repeating: 0, count: frames - copied) }
        }
        return got
    }

    /// Lines the rings of `group` up on their newest samples, from counts taken between two blocks
    /// of the input callback: each gives up what it holds beyond the one that holds least — the
    /// rest of an earlier monitor on that input, or a block one side lost. False, and nothing
    /// given up, inside a block.
    private func lineUp(_ group: UInt32) -> Bool {
        let before = blocks.load(ordering: .acquiring)
        guard before & 1 == 0 else { return false }
        var fewest = Int.max
        for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
            counts[channel] = rings[channel].available
            fewest = Swift.min(fewest, counts[channel])
        }
        guard blocks.load(ordering: .acquiring) == before else { return false }
        for channel in 0..<Self.channelLimit where group & (1 << UInt32(channel)) != 0 {
            rings[channel].discard(counts[channel] - fewest)
            linedUp[channel] = group
        }
        return true
    }
}
