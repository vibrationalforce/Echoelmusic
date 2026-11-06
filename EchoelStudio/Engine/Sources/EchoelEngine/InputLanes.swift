import Foundation

/// Where an interface input sits in the input callback's block, which comes as one buffer per
/// channel or as one buffer with every channel interleaved. Only numbers here, no Core Audio
/// type, so the choice that could swap a pair's sides is tested on every platform.
public enum InputLanes {
    /// One channel's place: the buffer, and the lane inside it (0 unless interleaved).
    public struct Lane: Equatable, Sendable {
        public let buffer: Int
        public let lane: Int

        public init(buffer: Int, lane: Int) {
            self.buffer = buffer
            self.lane = lane
        }
    }

    /// The place of input `channel` (0-based) in a block of `buffers` buffers, the first carrying
    /// `channelsPerBuffer` interleaved channels; nil when the block lacks it.
    public static func find(_ channel: Int, buffers: Int, channelsPerBuffer: Int) -> Lane? {
        guard channel >= 0, buffers > 0 else { return nil }
        if buffers > 1 { return channel < buffers ? Lane(buffer: channel, lane: 0) : nil }
        return channel < Swift.max(1, channelsPerBuffer) ? Lane(buffer: 0, lane: channel) : nil
    }

    /// The places a take records its two sides from: the left from `left`, the right from
    /// `right` — the same input for a mono take. An input the block lacks records the first, as
    /// a take on a missing input always has, in both sides; a right side the block lacks records
    /// the left, so a stereo frame is never half written. Nil for a block without buffers.
    public static func resolve(left: Int, right: Int, buffers: Int, channelsPerBuffer: Int) -> (left: Lane, right: Lane)? {
        guard buffers > 0 else { return nil }
        guard let first = find(left, buffers: buffers, channelsPerBuffer: channelsPerBuffer) else {
            let fallback = Lane(buffer: 0, lane: 0)
            return (fallback, fallback)
        }
        return (first, find(right, buffers: buffers, channelsPerBuffer: channelsPerBuffer) ?? first)
    }
}
