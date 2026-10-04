#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// The rings one generated voice's stem goes into: left always, right for a stereo voice.
/// Immutable after construction, so the render thread can never see half of a pair change.
final class StemTapTarget: @unchecked Sendable {
    let left: StemCaptureRing
    let right: StemCaptureRing?

    init(left: StemCaptureRing, right: StemCaptureRing?) {
        self.left = left
        self.right = right
    }
}

/// Spatial S-A3b-1 (ADR-008 §2, accepted 2026-10-04): the seam where a generated voice's render
/// block hands its finished output to a stem ring — and the hand-over of WHICH ring, from the
/// owner to the audio thread, without a lock and without freeing anything on the audio thread.
///
/// WHAT THE RENDER SIDE DOES (`capture`): load the armed target, copy this block's output into
/// its ring(s) at the block's ENGINE SAMPLE TIME, done. Called once per render block, after the
/// voice has filled its output buffers — silent blocks included, so a stem is silence where the
/// voice was silent rather than a gap the ring has to fill.
///
/// ⭐ THE HAND-OVER — why a pass counter. The owner swaps the target pointer; the render may be
/// mid-capture with the OLD one. Freeing the old target then is a use-after-free on the audio
/// thread. So the render brackets every capture with a pass counter (odd = inside), and the
/// owner, after clearing or swapping the slot, keeps the old target RETIRED until the counter
/// shows the render has left any pass that could have loaded it. The two sides are the classic
/// store→load pattern: render stores "odd", full fence, loads the slot; owner stores the slot,
/// full fence, loads the counter. With a full fence on BOTH sides at least one of them sees the
/// other's store — the owner sees "odd", or the render sees the new slot. Never neither.
///
/// ⚠️ AUDIO THREAD (`capture`): no allocation, no lock, no I/O, no GCD, no String. Two fences
/// per block when armed or not (one store pair, constant cost). The target is reached through
/// `Unmanaged._withUnsafeGuaranteedRef` so the render thread never owns a reference and never
/// releases one; property access on the rings may still emit retain/release at `-Onone` — an
/// atomic increment, not a lock, the same traffic `weakSelf.value` already costs every voice.
///
/// ⚠️ LIFETIME: the tap point is owned by its voice and outlives the voice's source node; its
/// `deinit` frees cells the render reads, so it must never run while a render block can call it.
///
/// ⚠️ ONE OWNER THREAD: `arm`, `disarm` and `releaseRetiredIfQuiescent` must be called from ONE
/// thread (the capture session's — S-A3c). They are not safe against each other.
///
/// ⚠️ A SAMPLE TIME THE ENGINE DID NOT VALIDATE IS NOT GUESSED. A block whose timestamp lacks
/// `.sampleTimeValid`, or carries a non-finite / out-of-range value, is skipped and counted in
/// `invalidTimeBlocks` — the ring then sees a gap and fills silence, and the exporter has the
/// count to abort on (ADR-008: discontinuities break loudly). `Int64(Double)` traps on NaN, so
/// the range check comes first.
///
/// Built: yes. Wired: NO — no voice calls `capture` yet (S-A3b-2) and nothing arms it (S-A3c).
/// Device: no — whether an `AVAudioSourceNode` timestamp shares a sample timeline with a tap's
/// `when.sampleTime` is UNVERIFIED (ADR-008 §1); the impulse test at G-D answers it.
final class StemTapPoint: @unchecked Sendable {

    private let slot: UnsafeMutablePointer<UnsafeMutableRawPointer?>
    private let passCounter: UnsafeMutablePointer<UInt64>
    private let invalidTimeCounter: UnsafeMutablePointer<Int64>
    private let interleavedCounter: UnsafeMutablePointer<Int64>

    /// Owner-thread only: the strong reference that keeps the armed target alive.
    private var armed: StemTapTarget?
    /// Owner-thread only: a target the render may still hold, and the pass it may hold it in.
    private var retired: StemTapTarget?
    private var retiredPass: UInt64 = 0

    init() {
        slot = .allocate(capacity: 1)
        slot.initialize(to: nil)
        passCounter = .allocate(capacity: 1)
        passCounter.initialize(to: 0)
        invalidTimeCounter = .allocate(capacity: 1)
        invalidTimeCounter.initialize(to: 0)
        interleavedCounter = .allocate(capacity: 1)
        interleavedCounter.initialize(to: 0)
    }

    deinit {
        slot.deallocate()
        passCounter.deallocate()
        invalidTimeCounter.deallocate()
        interleavedCounter.deallocate()
    }

    /// Blocks skipped because the engine gave no valid sample time. Non-zero = abort the take.
    var invalidTimeBlocks: Int64 { invalidTimeCounter.pointee }
    /// Blocks refused because a buffer carried more than one channel (interleaved). The ring is
    /// mono per channel; writing interleaved data would put L and R alternately into one stem.
    var interleavedBlocks: Int64 { interleavedCounter.pointee }
    /// True while a target is armed.
    var isArmed: Bool { armed != nil }
    /// True while a swapped-out target is still held back from release.
    var hasRetiredTarget: Bool { retired != nil }

    // MARK: Owner side

    /// Arms `target`. Refused (false) while an earlier target is still retired and the render
    /// may hold it — call `releaseRetiredIfQuiescent()` and retry. The owner keeps a strong
    /// reference until the target is retired AND quiescent.
    @discardableResult
    func arm(_ target: StemTapTarget) -> Bool {
        guard releaseRetiredIfQuiescent() else { return false }
        let previous = armed
        armed = target
        swapSlot(to: Unmanaged.passUnretained(target).toOpaque(), retiring: previous)
        return true
    }

    /// Disarms. Refused (false) while an earlier retired target is not yet quiescent.
    ///
    /// ⚠️ `true` does NOT mean the producer is finished: a render pass that loaded the slot before
    /// the swap may still be writing its last block. The take ends — and the final drain may run
    /// — only once `releaseRetiredIfQuiescent()` returns true with `hasRetiredTarget == false`.
    @discardableResult
    func disarm() -> Bool {
        guard releaseRetiredIfQuiescent() else { return false }
        let previous = armed
        armed = nil
        swapSlot(to: nil, retiring: previous)
        return true
    }

    /// Drops the retired target once the render cannot hold it. True when nothing is retired
    /// any more.
    @discardableResult
    func releaseRetiredIfQuiescent() -> Bool {
        guard retired != nil else { return true }
        OSMemoryBarrier()
        let now = passCounter.pointee
        OSMemoryBarrier()                       // acquire: the render's ring accesses happen-before the release
        // Even at the swap: the render was outside a pass, and any later pass loads the new slot.
        // Odd at the swap: the render was inside ONE pass; once the counter moved, it left it.
        guard retiredPass & 1 == 0 || now != retiredPass else { return false }
        retired = nil
        return true
    }

    private func swapSlot(to raw: UnsafeMutableRawPointer?, retiring previous: StemTapTarget?) {
        OSMemoryBarrier()                       // release: the target's and its rings' init BEFORE the slot
        slot.pointee = raw
        OSMemoryBarrier()                       // the slot store BEFORE the pass load
        let pass = passCounter.pointee
        if let previous {
            retired = previous
            retiredPass = pass
        }
    }

    // MARK: Render side — the audio thread

    /// Copies the block the voice just rendered into the armed rings at the block's engine
    /// sample time. A mono block feeds both rings of a stereo target. RT-SAFE (see type doc).
    func capture(_ audioBufferList: UnsafeMutablePointer<AudioBufferList>,
                 frameCount: Int,
                 timestamp: UnsafePointer<AudioTimeStamp>) {
        passCounter.pointee &+= 1                // odd: inside a pass
        OSMemoryBarrier()                        // the pass store BEFORE the slot load
        defer {
            OSMemoryBarrier()                    // every ring access BEFORE the pass leaves
            passCounter.pointee &+= 1            // even: outside again
        }
        guard let raw = slot.pointee, frameCount > 0 else { return }

        let stamp = timestamp.pointee
        let rawTime = stamp.mSampleTime
        guard stamp.mFlags.contains(.sampleTimeValid), rawTime.isFinite,
              rawTime > -9.0e18, rawTime < 9.0e18 else {
            invalidTimeCounter.pointee &+= 1
            return
        }
        let sampleTime = Int64(rawTime.rounded())

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard buffers.count > 0, let first = buffers[0].mData else { return }
        for index in 0..<min(buffers.count, 2) where buffers[index].mNumberChannels > 1 {
            interleavedCounter.pointee &+= 1
            return
        }
        let firstFrames = Int(buffers[0].mDataByteSize) / MemoryLayout<Float>.size
        var frames = min(frameCount, firstFrames)
        let left = UnsafePointer(first.assumingMemoryBound(to: Float.self))
        var right = left
        if buffers.count > 1, let second = buffers[1].mData {
            frames = min(frames, Int(buffers[1].mDataByteSize) / MemoryLayout<Float>.size)
            right = UnsafePointer(second.assumingMemoryBound(to: Float.self))
        }
        guard frames > 0 else { return }

        Unmanaged<StemTapTarget>.fromOpaque(raw)._withUnsafeGuaranteedRef { target in
            target.left.write(left, frameCount: frames, sampleTime: sampleTime)
            target.right?.write(right, frameCount: frames, sampleTime: sampleTime)
        }
    }
}
#endif
