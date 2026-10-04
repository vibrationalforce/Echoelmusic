//
//  TheStemTapHandsOverWithoutFreeingOnTheAudioThreadTests.swift
//  Spatial S-A3b-1. ADR-008 §2 captures each generated voice inside its own render block. The
//  render block cannot own the ring it writes into — a reference released on the audio thread
//  can free memory there — so `StemTapPoint` is the seam: the owner arms a target, the render
//  copies into it at the block's engine sample time, and a swapped-out target stays alive until
//  the render has provably left every pass that could have loaded it.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–6) — the shipped tap point and ring, single-threaded,
//    through the same `AudioBufferList` + `AudioTimeStamp` seam an `AVAudioSourceNode` hands
//    its render block. Nothing is mocked.
//  · SOURCE-TEXT SCAN (claims 7, 9) — the capture path allocates nothing and brackets every
//    pass; the owner fences, stores the slot, fences, then reads the pass counter (claim 7); the
//    three generated voices call the tap after they wrote, on both render exits (claim 9, S-A3b-2).
//  · END-TO-END BEHAVIOUR also claims 8 (interleaved refusal) and 10 (a voice's tap starts
//    unarmed).
//  · NOT PINNED, and said so: a render pass that overlaps an owner swap. A unit test cannot hold
//    a render thread inside a pass; that half is the fence review written into the type's doc
//    comment. Nor that anything ARMS a voice's tap — nothing does yet (S-A3c), so the voices
//    call `capture` and it returns at the empty slot. Built: yes · wired: render seam only ·
//    device: no.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `StemTapPoint` is created
//  by this commit (ONE absence, #486). Claims 1–6 were transcribed in Python against the tap
//  point's logic; claim 3 is red against a mutant that writes a mono block to the left ring only,
//  claim 4 against one that guesses a time for an invalid stamp, claim 6 against one that drops
//  the retired target at once. Claim 7 is red against a mutant that loads the slot before it
//  bumps the pass counter, and against one whose owner reads the counter before it stores
//  the slot, and (since the review repair) against one that stores the slot before the release
//  fence. Claim 8 is red against the pre-repair capture (it wrote interleaved data). Claim 9 is
//  red on the pre-S-A3b-2 voices (no tap) and against mutants that capture before the voice
//  writes, on one exit only, or through `weakSelf`. Claim 10 cannot be red on any tree where it
//  compiles; it pins the default.
//
//  `Tests/CISmoke` is the blocking bundle.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
@testable import Echoelmusic

final class TheStemTapHandsOverWithoutFreeingOnTheAudioThreadTests: XCTestCase {

    private static let tapFile = "Sources/Echoelmusic/Audio/StemTapPoint.swift"

    /// Runs one capture through a real `AudioBufferList` with one buffer per channel.
    private func capture(_ tap: StemTapPoint, _ channels: [[Float]],
                         at sampleTime: Double, valid: Bool = true, channelsPerBuffer: UInt32 = 1) {
        let frames = channels.first?.count ?? 0
        let abl = AudioBufferList.allocate(maximumBuffers: channels.count)
        var storage: [UnsafeMutablePointer<Float>] = []
        for (i, channel) in channels.enumerated() {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: max(frames, 1))
            data.initialize(from: channel, count: frames)
            storage.append(data)
            abl[i] = AudioBuffer(mNumberChannels: channelsPerBuffer,
                                 mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                                 mData: UnsafeMutableRawPointer(data))
        }
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = sampleTime
        stamp.mFlags = valid ? .sampleTimeValid : []
        withUnsafePointer(to: &stamp) { tap.capture(abl.unsafeMutablePointer, frameCount: frames, timestamp: $0) }
        for data in storage { data.deallocate() }
        free(abl.unsafeMutablePointer)
    }

    private func drain(_ ring: StemCaptureRing) -> ([Float], StemCaptureRing.Read) {
        var out = [Float](repeating: -1, count: 4_096)
        let result = out.withUnsafeMutableBufferPointer { buffer -> StemCaptureRing.Read in
            guard let base = buffer.baseAddress else {
                return StemCaptureRing.Read(startSampleTime: 0, frames: 0, silencedFrames: 0)
            }
            return ring.read(into: base, maxFrames: buffer.count)
        }
        return (Array(out.prefix(result.frames)), result)
    }

    private func ramp(_ count: Int, from first: Int = 1) -> [Float] {
        (0..<count).map { Float(first + $0) }
    }

    // MARK: 1 — a disarmed tap writes nothing

    func testADisarmedTapWritesNothing() {
        let tap = StemTapPoint()
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        capture(tap, [ramp(64)], at: 0)                    // never armed: a pass with no slot
        XCTAssertTrue(tap.arm(StemTapTarget(left: ring, right: nil)))
        XCTAssertTrue(tap.disarm())
        capture(tap, [ramp(64)], at: 0)                    // armed once, now disarmed
        XCTAssertFalse(tap.isArmed)
        XCTAssertEqual(drain(ring).1.frames, 0, """
            After `disarm` the render must find an empty slot — a disarmed tap that still writes \
            keeps a take's ring growing after the take has ended.
            """)
    }

    // MARK: 2 — an armed stereo tap writes each channel at the block's engine sample time

    func testAStereoBlockLandsAtItsSampleTime() {
        let tap = StemTapPoint()
        let left = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        let right = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        XCTAssertTrue(tap.arm(StemTapTarget(left: left, right: right)))
        capture(tap, [ramp(64), ramp(64, from: 500)], at: 1_000)
        capture(tap, [ramp(64, from: 65), ramp(64, from: 564)], at: 1_064)
        let (l, lr) = drain(left)
        let (r, rr) = drain(right)
        XCTAssertEqual(lr, StemCaptureRing.Read(startSampleTime: 1_000, frames: 128, silencedFrames: 0))
        XCTAssertEqual(l, ramp(128), "the left buffer is the left stem")
        XCTAssertEqual(rr.frames, 128)
        XCTAssertEqual(r, ramp(128, from: 500), "the right buffer is the right stem — never the left twice")
    }

    // MARK: 3 — a mono block feeds both rings of a stereo target

    func testAMonoBlockFeedsBothRings() {
        let tap = StemTapPoint()
        let left = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        let right = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        tap.arm(StemTapTarget(left: left, right: right))
        capture(tap, [ramp(32)], at: 0)
        XCTAssertEqual(drain(left).0, ramp(32))
        XCTAssertEqual(drain(right).0, ramp(32), """
            A mono voice armed with a stereo pair must fill BOTH — otherwise the right stem is a \
            gap of silence the length of the take, and the bed sums to a one-sided image.
            """)
    }

    // MARK: 4 — a sample time the engine did not validate is counted, never guessed

    func testAnInvalidSampleTimeIsCountedNeverGuessed() {
        let tap = StemTapPoint()
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        tap.arm(StemTapTarget(left: ring, right: nil))
        capture(tap, [ramp(16)], at: 0, valid: false)
        capture(tap, [ramp(16)], at: .nan)
        capture(tap, [ramp(16)], at: .infinity)
        capture(tap, [ramp(16)], at: 1.0e19)
        XCTAssertEqual(tap.invalidTimeBlocks, 4, """
            A block without a valid engine sample time cannot be aligned. Writing it at a guessed \
            time shifts the stem against the master; `Int64(Double)` of NaN traps on the audio \
            thread. Count it, write nothing — the exporter aborts on a non-zero count.
            """)
        XCTAssertEqual(drain(ring).1.frames, 0, "nothing was written for an unaligned block")
    }

    // MARK: 5 — the frame count never exceeds the buffer the render block was handed

    func testTheFrameCountIsClampedToTheBuffer() {
        let tap = StemTapPoint()
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        tap.arm(StemTapTarget(left: ring, right: nil))
        let frames = 16
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        data.initialize(repeating: 0.5, count: frames)
        let abl = AudioBufferList.allocate(maximumBuffers: 1)
        abl[0] = AudioBuffer(mNumberChannels: 1,
                             mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                             mData: UnsafeMutableRawPointer(data))
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = 0
        stamp.mFlags = .sampleTimeValid
        withUnsafePointer(to: &stamp) { tap.capture(abl.unsafeMutablePointer, frameCount: 4_096, timestamp: $0) }
        data.deallocate()
        free(abl.unsafeMutablePointer)
        XCTAssertEqual(drain(ring).1.frames, frames, """
            A frame count larger than the buffer's byte size would read past the buffer on the \
            audio thread. The byte size is the bound.
            """)
    }

    // MARK: 6 — a swapped-out target is retired, and released only once the render is quiet

    func testASwappedOutTargetIsRetiredUntilTheRenderIsQuiet() {
        let tap = StemTapPoint()
        let first = StemTapTarget(left: StemCaptureRing(capacityFrames: 64, startSampleTime: 0), right: nil)
        XCTAssertTrue(tap.arm(first))
        capture(tap, [ramp(8)], at: 0)              // a completed pass: the counter is even again
        XCTAssertTrue(tap.disarm())
        XCTAssertTrue(tap.hasRetiredTarget, "a disarmed target is RETIRED first, never dropped on the spot")
        XCTAssertTrue(tap.releaseRetiredIfQuiescent(), "no pass was in flight at the swap, so it is safe")
        XCTAssertFalse(tap.hasRetiredTarget)
        XCTAssertFalse(tap.isArmed)
        capture(tap, [ramp(8)], at: 8)              // a disarmed pass touches nothing
        XCTAssertEqual(tap.invalidTimeBlocks, 0)
    }

    // MARK: 7 — the capture path brackets every pass and allocates nothing

    func testTheCapturePathBracketsEveryPassAndAllocatesNothing() throws {
        let code = SourceText.codeOnly(try text(Self.tapFile))
        guard let swap = code.range(of: "private func swapSlot("),
              let begin = code.range(of: "func capture(", range: swap.upperBound..<code.endIndex) else {
            return XCTFail("the capture / swap anchors moved — re-anchor this guard")
        }
        let render = String(code[begin.lowerBound...])
        XCTAssertGreaterThan(render.count, 600, "the capture slice is almost empty — the scan is blind")
        for needle in ["Array(", ".append(", "allocate(", "String(", "\\(", "DispatchQueue", "NSLock",
                       "os_log", "log.log", "print(", "Task", "await", "@objc", "passRetained",
                       "takeRetainedValue", "takeUnretainedValue"] {
            XCTAssertFalse(render.contains(needle), """
                The stem capture runs on the audio thread and contains `\(needle)`. No allocation, \
                no lock, no ObjC, no I/O, no GCD, and no reference the render thread would own.
                """)
        }
        guard let bump = render.range(of: "passCounter.pointee &+= 1"),
              let fence = render.range(of: "OSMemoryBarrier()", range: bump.upperBound..<render.endIndex),
              let load = render.range(of: "slot.pointee") else {
            return XCTFail("the render must bump the pass counter, fence, and only then load the slot")
        }
        XCTAssertLessThan(fence.lowerBound, load.lowerBound, "pass store → fence → slot load")
        XCTAssertTrue(render.contains("_withUnsafeGuaranteedRef"),
                      "the render reaches the target without owning a reference")

        // The owner slice ENDS at the render side — otherwise the render's own counter access
        // would satisfy the "pass load after the fence" needle for an owner that never reads it.
        let owner = String(code[swap.lowerBound..<begin.lowerBound])
        guard let store = owner.range(of: "slot.pointee = raw"),
              let releaseFence = owner.range(of: "OSMemoryBarrier()"),
              let ownerFence = owner.range(of: "OSMemoryBarrier()", range: store.upperBound..<owner.endIndex),
              let passLoad = owner.range(of: "passCounter.pointee", range: store.upperBound..<owner.endIndex) else {
            return XCTFail("the owner must store the slot, fence, and only then read the pass counter")
        }
        XCTAssertLessThan(ownerFence.lowerBound, passLoad.lowerBound, "slot store → fence → pass load")
        XCTAssertLessThan(releaseFence.lowerBound, store.lowerBound, """
            The owner must fence BEFORE it publishes the target pointer (audio-thread review \
            2026-10-04, H2): without it the render can load the pointer before the stores that \
            built the target and its rings are visible on arm64.
            """)
    }

    // MARK: 8 — an interleaved buffer is refused and counted, never written as one stem

    func testAnInterleavedBufferIsRefusedAndCounted() {
        let tap = StemTapPoint()
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        XCTAssertTrue(tap.arm(StemTapTarget(left: ring, right: nil)))
        capture(tap, [ramp(64)], at: 0, channelsPerBuffer: 2)
        XCTAssertEqual(tap.interleavedBlocks, 1, "an interleaved block is counted — the exporter aborts on it")
        XCTAssertEqual(drain(ring).1.frames, 0, """
            A two-channel buffer holds L and R alternately. Writing it into one ring puts both \
            channels into one stem at the wrong rate — the ring must not see it at all.
            """)
        capture(tap, [ramp(64)], at: 0)
        XCTAssertEqual(drain(ring).0, ramp(64), "a non-interleaved block right after still lands")
    }

    // MARK: 9 — every generated voice hands its finished block to its tap, silent blocks too

    /// S-A3b-2: the three generated voices. The tap call must come AFTER the voice wrote the
    /// buffer (otherwise the stem is the PREVIOUS block's leftovers), on BOTH exits of the render
    /// block (a voice released mid-take still writes silence, never a gap), with the block's own
    /// timestamp, and through a local `tap` the closure owns — never through `weakSelf`, which
    /// would make the stem vanish the moment the voice does.
    func testEveryGeneratedVoiceHandsItsBlockToTheTap() throws {
        for file in ["Sources/Echoelmusic/Tools/PolySynthVoice.swift",
                     "Sources/Echoelmusic/Tools/SubBassVoice.swift",
                     "Sources/Echoelmusic/Tools/BioReactiveSynthVoice.swift"] {
            let code = SourceText.codeOnly(try text(file))
            XCTAssertTrue(code.contains("nonisolated let stemTap = StemTapPoint()"), "\(file): the voice owns a tap point")
            guard let make = code.range(of: "private func makeSourceNode()"),
                  let end = code.range(of: "AVAudioSourceNode(format:", range: make.upperBound..<code.endIndex) else {
                XCTFail("\(file): makeSourceNode moved — re-anchor this guard"); continue
            }
            let body = String(code[make.upperBound..<end.lowerBound])
            XCTAssertTrue(body.contains("let tap = stemTap"), "\(file): the closure captures the tap, not the voice")
            XCTAssertTrue(body.contains("{ _, timestamp, frameCount, audioBufferList in"),
                          "\(file): the render block reads the engine's timestamp")
            let call = "tap.capture(audioBufferList, frameCount: Int(frameCount), timestamp: timestamp)"
            XCTAssertEqual(body.components(separatedBy: call).count - 1, 2,
                           "\(file): both exits of the render block capture — the live one and the silent one")
            for writer in [".silence(audioBufferList:", "renderOnAudioThread(frameCount:"] {
                guard let w = body.range(of: writer),
                      let c = body.range(of: call, range: w.upperBound..<body.endIndex) else {
                    XCTFail("\(file): `\(writer)` is not followed by the capture"); continue
                }
                XCTAssertLessThan(w.lowerBound, c.lowerBound, "\(file): the voice writes, THEN the tap copies")
            }
        }
    }

    // MARK: 10 — a voice's tap starts unarmed: nothing is captured until a session arms it

    @MainActor
    func testAVoiceTapStartsUnarmed() {
        let voice = BioReactiveSynthVoice()
        XCTAssertFalse(voice.stemTap.isArmed, "no capture session, no capture — the default costs nothing")
        XCTAssertFalse(voice.stemTap.hasRetiredTarget)
        XCTAssertEqual(voice.stemTap.invalidTimeBlocks, 0)
    }

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
#endif
