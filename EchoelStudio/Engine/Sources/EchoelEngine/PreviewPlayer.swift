import EchoelDSP
import Foundation
import Synchronization

/// Listening to a file in the media browser (Recovery 7): one decoded sample played once from its
/// start, on top of whatever the song plays, at a fixed level below unity. Not part of the song —
/// an export never hears it, the mixer never sees it.
///
/// Threading, as `EngineCore`'s snapshots: the main thread decodes the file (off the render thread,
/// before `play`), hands the take over through one atomic pointer and keeps every take alive until
/// the render thread has said it no longer plays it; the render thread never allocates and never
/// frees. A newer `play` replaces the take that sounds; `stop` fades it out over a few milliseconds
/// instead of cutting it mid-waveform.
public final class PreviewPlayer: @unchecked Sendable {
    /// The level a file is heard at: −6 dB, so a loud file over a playing song stays under the song.
    public static let level: Float = 0.5
    /// How long a start and a stop ramp, in seconds of the file: no click at either edge.
    public static let fadeSeconds: Double = 0.005

    private final class Take: Sendable {
        let buffer: SampleBuffer
        let number: UInt64
        init(_ buffer: SampleBuffer, number: UInt64) {
            self.buffer = buffer
            self.number = number
        }
    }

    // MARK: Shared

    private let pending = Atomic<UnsafeMutableRawPointer?>(nil)
    /// Takes up to this number are asked to stop.
    private let stopRequest = Atomic<UInt64>(0)
    /// The newest take the render thread has taken.
    private let acknowledged = Atomic<UInt64>(0)
    /// The newest take the render thread has let go of: played to its end, stopped, or replaced.
    private let released = Atomic<UInt64>(0)

    // MARK: Main thread

    private var held: [Take] = []
    private var count: UInt64 = 0

    // MARK: Render thread

    private var current: Take?
    private var elapsed: Int64 = 0
    /// Where the take ends in its own frames: its length, or a stop's fade-out.
    private var end: Double = 0
    private var stopping = false

    public init() {}

    deinit {
        // A take never taken was never retained by the pointer; `held` releases it.
        _ = pending.exchange(nil, ordering: .acquiringAndReleasing)
    }

    // MARK: - Main thread

    /// Plays `buffer` from its start, replacing what plays. Returns the take's number, which
    /// `isPlaying(_:)` answers for.
    @discardableResult
    public func play(_ buffer: SampleBuffer) -> UInt64 {
        count += 1
        let take = Take(buffer, number: count)
        held.append(take)
        if let unseen = pending.exchange(Unmanaged.passUnretained(take).toOpaque(), ordering: .acquiringAndReleasing) {
            // Never taken, and now it never can be.
            let skipped = Unmanaged<Take>.fromOpaque(unseen).takeUnretainedValue()
            held.removeAll { $0 === skipped }
        }
        prune()
        return take.number
    }

    /// Fades out what plays, and a take not yet started never starts.
    public func stop() {
        stopRequest.store(count, ordering: .releasing)
        prune()
    }

    /// Whether take `number` still sounds, or is about to: false once it ended, was stopped or was
    /// replaced. Cheap; a leaf view polls it.
    public func isPlaying(_ number: UInt64) -> Bool {
        prune()
        guard number > 0, number == count else { return false }
        return released.load(ordering: .acquiring) < number && stopRequest.load(ordering: .acquiring) < number
    }

    /// Whether any take sounds.
    public var isPlaying: Bool { isPlaying(count) }

    /// The takes the main thread still keeps alive — for the tests: it drops every take the render
    /// thread can no longer reach.
    public var heldTakes: Int {
        prune()
        return held.count
    }

    private func prune() {
        let done = released.load(ordering: .acquiring)
        let taken = acknowledged.load(ordering: .acquiring)
        // The render thread reaches the take it acknowledged until it releases it, and a newer one
        // waiting in `pending`; nothing older.
        held.removeAll { $0.number <= done || $0.number < taken }
    }

    // MARK: - Render thread

    /// Adds the take that sounds into `left` and `right` (`frames` each), at an output rate of
    /// `outputRate`. Render-thread safe: no allocation, no lock, no release of the last reference.
    public func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int,
                       outputRate: Double) {
        if let pointer = pending.exchange(nil, ordering: .acquiringAndReleasing) {
            let take = Unmanaged<Take>.fromOpaque(pointer).takeUnretainedValue()
            let replaced = current?.number
            current = take
            elapsed = 0
            end = Double(take.buffer.frameCount)
            stopping = false
            acknowledged.store(take.number, ordering: .releasing)
            if let replaced { released.store(replaced, ordering: .releasing) }
        }
        guard let take = current, frames > 0 else { return }
        let buffer = take.buffer
        guard outputRate.isFinite, outputRate > 0 else { return }
        let step = buffer.sampleRate / outputRate
        let fade = Self.fadeSeconds * buffer.sampleRate
        if !stopping, stopRequest.load(ordering: .acquiring) >= take.number {
            stopping = true
            end = Swift.min(end, Double(elapsed) * step + fade)
        }
        let envelope = RegionEnvelope(gain: Self.level)
        buffer.add(intoLeft: left, right: right, count: frames, elapsed: elapsed, step: step,
                   offset: 0, length: end, fade: fade, envelope: envelope)
        elapsed += Int64(frames)
        if Double(elapsed) * step >= end {
            current = nil
            released.store(take.number, ordering: .releasing)
        }
    }
}
