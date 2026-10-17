import Foundation
import Synchronization

/// Carries the interface's inputs from the input callback to the render thread, one ring per
/// channel, so a track can play what comes in through its own strip. The input and the output
/// run on separate callbacks with their own clocks: the reader keeps at most `slack` samples
/// waiting and throws the rest away, so the delay never grows, and plays silence for what has
/// not arrived yet. No locks, no allocation after `init`.
public final class InputMonitor: @unchecked Sendable {
    /// Inputs that can be monitored; a track on a higher input records but is not heard.
    public static let channelLimit = 16
    /// Samples a monitored input may lag behind the output before the excess is dropped.
    public static let slack = 512

    private let rings: [AudioRing]
    private let wanted = Atomic<UInt32>(0)

    public init(capacity: Int = 8_192) {
        rings = (0..<Self.channelLimit).map { _ in AudioRing(capacity: capacity) }
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

    /// Render thread: the next `frames` samples of `channel` into `destination`; what has not
    /// arrived is silence. Returns how many were real.
    @discardableResult
    public func read(channel: Int, into destination: UnsafeMutablePointer<Float>, frames: Int) -> Int {
        guard frames > 0 else { return 0 }
        guard (0..<Self.channelLimit).contains(channel) else {
            destination.update(repeating: 0, count: frames)
            return 0
        }
        let ring = rings[channel]
        let excess = ring.available - frames - Self.slack
        if excess > 0 { ring.discard(excess) }
        let got = ring.read(into: destination, count: frames)
        if got < frames { (destination + got).update(repeating: 0, count: frames - got) }
        return got
    }
}
