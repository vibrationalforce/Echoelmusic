import EchoelDSP
import Foundation
import Synchronization

/// The click's own sound (2026-11-19, founder: „Für Click sollen auch eigene samples auswählbar
/// sein“): a short sample the click plays instead of its sine burst, or nil for the built-in one.
/// The accented downbeat plays it at the click's level, the other beats 4.4 dB under it, as the
/// sine does.
///
/// Threading, as `PreviewPlayer`: the main thread decodes the file, hands the sound over through one
/// atomic pointer and keeps every sound alive until the render thread has said it took a newer
/// one; the render thread never allocates and never frees (it lets go of the old sound before it
/// acknowledges the new one, so the main thread's release is always the last).
public final class ClickSound: @unchecked Sendable {
    /// The longest stretch of a sample the click plays: a click is a tick, not a loop, and this
    /// stretch ends before the next beat up to 300 BPM.
    public static let maximumSeconds: Double = 0.2
    /// The click guard at both edges of the stretch, short enough to keep the attack.
    public static let edgeSeconds: Double = 0.0005
    /// The fade over the stretch's end, so a sample cut at `maximumSeconds` does not click.
    public static let fadeOutSeconds: Double = 0.01

    private final class Box: Sendable {
        let buffer: SampleBuffer?
        let number: UInt64
        init(_ buffer: SampleBuffer?, number: UInt64) {
            self.buffer = buffer
            self.number = number
        }
    }

    // MARK: Shared

    private let pending = Atomic<UnsafeMutableRawPointer?>(nil)
    /// The newest sound the render thread has taken.
    private let acknowledged = Atomic<UInt64>(0)

    // MARK: Main thread

    private var held: [Box] = []
    private var count: UInt64 = 0

    // MARK: Render thread

    private var current: Box?

    public init() {}

    deinit {
        // A sound never taken was never retained by the pointer; `held` releases it.
        _ = pending.exchange(nil, ordering: .acquiringAndReleasing)
    }

    // MARK: - Main thread

    /// The click plays `buffer` from the next chunk on; nil gives it its built-in sound back.
    public func set(_ buffer: SampleBuffer?) {
        count += 1
        let box = Box(buffer, number: count)
        held.append(box)
        if let unseen = pending.exchange(Unmanaged.passUnretained(box).toOpaque(), ordering: .acquiringAndReleasing) {
            // Never taken, and now it never can be.
            let skipped = Unmanaged<Box>.fromOpaque(unseen).takeUnretainedValue()
            held.removeAll { $0 === skipped }
        }
        prune()
    }

    /// The sounds the main thread still keeps alive — for the tests.
    public var heldSounds: Int {
        prune()
        return held.count
    }

    private func prune() {
        let taken = acknowledged.load(ordering: .acquiring)
        // The render thread reaches the sound it acknowledged and a newer one waiting; nothing older.
        held.removeAll { $0.number < taken }
    }

    // MARK: - Render thread

    /// Takes a sound the main thread handed over, once per chunk, before the click renders.
    public func drain() {
        guard let pointer = pending.exchange(nil, ordering: .acquiringAndReleasing) else { return }
        let box = Unmanaged<Box>.fromOpaque(pointer).takeUnretainedValue()
        current = box
        acknowledged.store(box.number, ordering: .releasing)
    }

    /// The sound the click plays now; nil is the built-in sine burst.
    public var sound: SampleBuffer? { current?.buffer }
}
