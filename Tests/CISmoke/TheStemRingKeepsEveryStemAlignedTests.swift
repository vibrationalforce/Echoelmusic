//
//  TheStemRingKeepsEveryStemAlignedTests.swift
//  Spatial S-A3a. ADR-008 (accepted 2026-10-04) captures every stem of an immersive master in
//  ONE realtime pass, aligned by the engine's sample time, as long as the master, with a gap
//  filled by silence and a loss counted instead of hidden. `StemCaptureRing` is the one ring a
//  stem goes through; this guard pins those four promises on the ring itself.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–7, 9–11) — the shipped ring, single-threaded: write as the
//    audio thread would, read as the writer thread would. Nothing is mocked.
//  · SOURCE-TEXT SCAN (claims 8, 12) — the producer path allocates nothing, takes no lock, logs
//    nothing, publishes its cursor only through `RetroRingCursor`, and CLAIMS before it fills;
//    the reader validates against the claim behind a barrier.
//  · CONCURRENT SMOKE (claim 13) — a real producer thread racing a real reader. Every frame the
//    reader keeps must be the frame written for that sample time; anything else came out as a
//    counted zero. This can catch a torn read; it cannot PROVE the absence of one (a scheduler
//    decides how often the race window opens). The proof half is the fence review written into
//    the ring's doc comment (audio-thread review 2026-10-04, finding H1) plus a device run.
//  · NOT PINNED, and said so: that anything writes a stem in the app — nothing does yet
//    (S-A3b/c). Built: yes · wired: no · device: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid a different overlap policy, a
//  different jump bound or a different minimum size — those are decisions; change ADR-008 and
//  this guard together.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `StemCaptureRing` is
//  created by S-A3a — so no assertion has a verdict there (ONE absence, #486). Claims 1–7 and
//  9–11 were transcribed in Python against the ring's arithmetic: claim 4 is red against a
//  mutant that drops the overrun count, claim 2 against one that shifts instead of filling,
//  claims 9–10 against one without the jump bound, claim 11 against one that wraps silently.
//  Claim 12 is red against the pre-review ring (no claim cursor). Claim 13 has NO transcription —
//  Python cannot reproduce arm64 reordering; its verdict is the CI run alone.
//
//  `Tests/CISmoke` is the blocking bundle.

#if canImport(AVFoundation)
import Foundation
import XCTest
@testable import Echoelmusic

final class TheStemRingKeepsEveryStemAlignedTests: XCTestCase {

    private static let ringFile = "Sources/Echoelmusic/Audio/StemCaptureRing.swift"

    private func write(_ ring: StemCaptureRing, _ values: [Float], at sampleTime: Int64) {
        values.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            ring.write(base, frameCount: buffer.count, sampleTime: sampleTime)
        }
    }

    private func read(_ ring: StemCaptureRing, max: Int) -> ([Float], StemCaptureRing.Read) {
        var out = [Float](repeating: -1, count: max)
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

    // MARK: 1 — contiguous blocks read back exactly, from the take's start time

    func testContiguousBlocksReadBackExactly() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        let audio = ramp(192)
        write(ring, Array(audio[0..<64]), at: 1_000)
        write(ring, Array(audio[64..<128]), at: 1_064)
        write(ring, Array(audio[128..<192]), at: 1_128)
        let (frames, result) = read(ring, max: 1_000)
        XCTAssertEqual(result, StemCaptureRing.Read(startSampleTime: 1_000, frames: 192, silencedFrames: 0))
        XCTAssertEqual(frames, audio, "what the audio thread wrote is what the writer reads")
        XCTAssertEqual(ring.readSampleTime, 1_192)
    }

    // MARK: 2 — a late block gets silence in front of it, never a shift

    func testAGapIsSilenceNeverAShift() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        write(ring, ramp(64), at: 1_000)
        write(ring, ramp(64, from: 500), at: 1_100)
        let (frames, result) = read(ring, max: 1_000)
        XCTAssertEqual(result.frames, 164, "the stem covers every sample from start to the last write")
        XCTAssertEqual(Array(frames[64..<100]), [Float](repeating: 0, count: 36), """
            A gap is silence IN PLACE (ADR-008 §5). Moving the late block forward would put every \
            later sample of this stem early against the master and the other stems.
            """)
        XCTAssertEqual(Array(frames[100..<164]), ramp(64, from: 500))
        XCTAssertEqual(ring.gapFrames, 36)
        XCTAssertEqual(result.silencedFrames, 0, "a gap is not a loss")
    }

    // MARK: 3 — time already written keeps its first write

    func testAnOverlapKeepsTheFirstWrite() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        write(ring, [Float](repeating: 1, count: 64), at: 1_000)
        write(ring, [Float](repeating: 2, count: 64), at: 1_032)
        let (frames, result) = read(ring, max: 1_000)
        XCTAssertEqual(result.frames, 96)
        XCTAssertEqual(Array(frames[0..<64]), [Float](repeating: 1, count: 64), "the first write stands")
        XCTAssertEqual(Array(frames[64..<96]), [Float](repeating: 2, count: 32), "only the new time is appended")
        XCTAssertEqual(ring.overlapFrames, 32, "the duplicate frames are counted, not hidden")
    }

    // MARK: 4 — an overrun is counted and keeps the length; it is never silent

    func testAnOverrunIsCountedNeverSilent() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 1_000)
        let audio = ramp(600)
        for block in 0..<6 {
            write(ring, Array(audio[(block * 100)..<(block * 100 + 100)]), at: 1_000 + Int64(block * 100))
        }
        let (frames, result) = read(ring, max: 10_000)
        XCTAssertEqual(result.frames, 600, "the stem keeps its full length — alignment survives a loss")
        XCTAssertEqual(result.silencedFrames, 344, "600 written into a 256-frame ring: 344 were overwritten")
        XCTAssertEqual(ring.lostFrames, 344, """
            A loss must be COUNTED (ADR-008: a tap block is no realtime guarantee). A writer that \
            falls behind and says nothing is the lying-control class.
            """)
        XCTAssertEqual(Array(frames[0..<344]), [Float](repeating: 0, count: 344), "lost frames are zeros in place")
        XCTAssertEqual(Array(frames[344..<600]), Array(audio[344..<600]), "the newest ring is intact")
    }

    // MARK: 5 — reading in slices gives the same stem as reading at once

    func testChunkedReadsConcatenate() {
        let ring = StemCaptureRing(capacityFrames: 512, startSampleTime: 0)
        let audio = ramp(300)
        write(ring, Array(audio[0..<37]), at: 0)
        write(ring, Array(audio[37..<138]), at: 37)
        write(ring, Array(audio[138..<300]), at: 138)
        var collected: [Float] = []
        var expectedStart: Int64 = 0
        while true {
            let (frames, result) = read(ring, max: 50)
            if result.frames == 0 { break }
            XCTAssertEqual(result.startSampleTime, expectedStart, "each slice starts where the last ended")
            expectedStart += Int64(result.frames)
            collected += frames
        }
        XCTAssertEqual(collected, audio)
    }

    // MARK: 6 — the capacity is a power of two, never below the minimum

    func testTheCapacityIsAPowerOfTwo() {
        XCTAssertEqual(StemCaptureRing(capacityFrames: 1_000, startSampleTime: 0).capacityFrames, 1_024)
        XCTAssertEqual(StemCaptureRing(capacityFrames: 64, startSampleTime: 0).capacityFrames, 64)
        XCTAssertEqual(StemCaptureRing(capacityFrames: 65, startSampleTime: 0).capacityFrames, 128)
        XCTAssertEqual(StemCaptureRing(capacityFrames: 0, startSampleTime: 0).capacityFrames,
                       StemCaptureRing.minimumCapacityFrames)
        XCTAssertEqual(StemCaptureRing(capacityFrames: -5, startSampleTime: 0).capacityFrames,
                       StemCaptureRing.minimumCapacityFrames)
        XCTAssertEqual(StemCaptureRing.maximumCapacityFrames, 1 << 22)
        XCTAssertEqual(StemCaptureRing(capacityFrames: Int.max, startSampleTime: 0).capacityFrames,
                       StemCaptureRing.maximumCapacityFrames, """
            A request above the ceiling is CLAMPED. Rounding `Int.max` up to a power of two either \
            loops forever or allocates the address space.
            """)
    }

    // MARK: 7 — one block longer than the ring keeps its newest ring and counts the rest

    func testABlockLongerThanTheRingKeepsTheNewest() {
        let ring = StemCaptureRing(capacityFrames: 64, startSampleTime: 0)
        let audio = ramp(200)
        write(ring, audio, at: 0)
        let (frames, result) = read(ring, max: 1_000)
        XCTAssertEqual(result.frames, 200)
        XCTAssertEqual(result.silencedFrames, 136)
        XCTAssertEqual(Array(frames[136..<200]), Array(audio[136..<200]))
    }

    // MARK: 8 — the producer path is realtime-safe and publishes only through the accessor

    func testTheWritePathIsRealtimeSafe() throws {
        let code = SourceText.codeOnly(try text(Self.ringFile))
        guard let begin = code.range(of: "func write("),
              let end = code.range(of: "func read(", range: begin.upperBound..<code.endIndex) else {
            return XCTFail("the producer path `write(` … `read(` is not where this guard looks — re-anchor it")
        }
        let producer = String(code[begin.lowerBound..<end.lowerBound])
        XCTAssertGreaterThan(producer.count, 500, "the producer slice is almost empty — the scan is blind")
        for needle in ["Array(", ".append(", "allocate(", "String(", "\\(", "DispatchQueue", "NSLock",
                       "os_log", "log.log", "print(", "Task", "await", "@objc"] {
            XCTAssertFalse(producer.contains(needle), """
                The stem producer runs on the audio thread and contains `\(needle)`. No allocation, \
                no lock, no ObjC, no I/O, no GCD there (CLAUDE.md, the audio-thread law).
                """)
        }
        XCTAssertTrue(producer.contains("RetroRingCursor.publish(writeCursor"),
                      "the producer publishes its cursor through the release accessor")
        XCTAssertFalse(code.contains("writeCursor.pointee ="), """
            The write cursor is stored only through `RetroRingCursor.publish` — a plain store can \
            become visible before the samples it covers on arm64 (#1413b/#1429).
            """)
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"], "the ring is Foundation-only")
    }

    // MARK: 9 — engine time running backwards by more than a ring is a discontinuity, not an overlap

    func testABackwardJumpIsALoudDiscontinuity() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 10_000)
        write(ring, ramp(64), at: 10_000)
        write(ring, ramp(64, from: 900), at: 10_000 - 1_000)   // an engine restart reset the clock
        XCTAssertEqual(ring.discontinuities, 1, """
            Engine time ran 1 000 frames BACK — four rings. Trimming that as an overlap hides a \
            restart; the export must be able to abort (ADR-008: discontinuities break loudly).
            """)
        XCTAssertEqual(ring.overlapFrames, 0, "a discontinuity is not an overlap")
        write(ring, ramp(64, from: 65), at: 10_064)
        let (frames, result) = read(ring, max: 1_000)
        XCTAssertEqual(result.frames, 128, "the refused block moved nothing")
        XCTAssertEqual(frames, ramp(128))
    }

    // MARK: 10 — a forward leap of more than a ring is a discontinuity, not a gap

    func testAForwardLeapIsALoudDiscontinuity() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        write(ring, ramp(64), at: 0)
        write(ring, ramp(64), at: 64 + 257)                     // one frame past a ring of silence
        XCTAssertEqual(ring.discontinuities, 1, """
            A leap past one ring cannot be filled in place — the zeros would overwrite audio the \
            writer has not read. Filling a CLIPPED gap silently shortens the stem against the master.
            """)
        XCTAssertEqual(ring.gapFrames, 0)
        write(ring, ramp(64, from: 500), at: 64 + 256)          // exactly one ring: still a gap
        XCTAssertEqual(ring.discontinuities, 1)
        XCTAssertEqual(ring.gapFrames, 256, "a gap of exactly one ring is the largest that is filled")
    }

    // MARK: 11 — a sample time at the edge of Int64 is counted, never a trap on the audio thread

    func testInt64EdgesAreCountedNeverATrap() {
        let late = StemCaptureRing(capacityFrames: 64, startSampleTime: Int64.max - 10)
        write(late, ramp(32), at: Int64.max - 10)               // end would overflow
        XCTAssertEqual(late.discontinuities, 1, "an end past Int64.max is refused and counted")
        let (_, nothing) = read(late, max: 100)
        XCTAssertEqual(nothing.frames, 0)

        let early = StemCaptureRing(capacityFrames: 64, startSampleTime: Int64.max - 10)
        write(early, ramp(8), at: Int64.min)                    // the subtraction itself overflows
        XCTAssertEqual(early.discontinuities, 1, """
            `Int64.min - (Int64.max - 10)` overflows. Plain `-` traps — on the audio thread that is \
            a crash mid-performance; the ring must count it instead.
            """)
    }

    // MARK: 12 — the producer CLAIMS before it overwrites; the reader validates against the claim

    func testTheProducerClaimsBeforeItOverwrites() throws {
        let code = SourceText.codeOnly(try text(Self.ringFile))
        guard let begin = code.range(of: "func write("),
              let end = code.range(of: "private func fill(", range: begin.upperBound..<code.endIndex),
              let readBegin = code.range(of: "func read(") else {
            return XCTFail("the producer/consumer anchors moved — re-anchor this guard")
        }
        let producer = String(code[begin.lowerBound..<end.lowerBound])
        let consumer = String(code[readBegin.lowerBound..<code.endIndex])
        guard let claim = producer.range(of: "claimCursor.pointee = end"),
              let fence = producer.range(of: "OSMemoryBarrier()", range: claim.upperBound..<producer.endIndex),
              let firstFill = producer.range(of: "fill(from:") else {
            return XCTFail("""
                The producer must store the CLAIM, then fence, then touch a slot (audio-thread \
                review 2026-10-04, H1). Without it a reader one ring behind copies half-overwritten \
                slots, re-loads an unchanged write cursor, and keeps them as audio.
                """)
        }
        XCTAssertLessThan(fence.lowerBound, firstFill.lowerBound, "claim → fence → fill, in that order")
        guard let readFence = consumer.range(of: "OSMemoryBarrier()"),
              let claimLoad = consumer.range(of: "claimCursor.pointee") else {
            return XCTFail("the reader must validate its copy against the claim, behind a fence")
        }
        XCTAssertLessThan(readFence.lowerBound, claimLoad.lowerBound, """
            The slot loads must complete before the claim is read — arm64 reorders load-load.
            """)
        for needle in [".subtractingReportingOverflow(", ".addingReportingOverflow("] {
            XCTAssertTrue(producer.contains(needle), "the producer does checked arithmetic: `\(needle)`")
        }
    }

    // MARK: 13 — a real producer thread against a real reader keeps every kept frame true

    func testAConcurrentReaderKeepsOnlyTrueFrames() {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        let blocks = 4_000
        let blockFrames = 64
        // The value IS the sample time (mod 2^15, +1 so it is never zero) — a torn frame cannot
        // pass for a true one, and a counted zero cannot pass for audio.
        let producerDone = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async(group: producerDone) {
            var block = [Float](repeating: 0, count: blockFrames)
            for b in 0..<blocks {
                let t0 = Int64(b * blockFrames)
                for i in 0..<blockFrames { block[i] = Float(((t0 + Int64(i)) & 0x7FFF) + 1) }
                block.withUnsafeBufferPointer { buffer in
                    guard let base = buffer.baseAddress else { return }
                    ring.write(base, frameCount: blockFrames, sampleTime: t0)
                }
            }
        }
        var out = [Float](repeating: 0, count: 100)
        var total = 0
        var silencedTotal = 0
        var wrong = 0
        var finished = false
        while true {
            if !finished { finished = producerDone.wait(timeout: .now()) == .success }
            let result = out.withUnsafeMutableBufferPointer { buffer -> StemCaptureRing.Read in
                guard let base = buffer.baseAddress else {
                    return StemCaptureRing.Read(startSampleTime: 0, frames: 0, silencedFrames: 0)
                }
                return ring.read(into: base, maxFrames: buffer.count)
            }
            if result.frames == 0 {
                if finished { break }
                continue
            }
            for i in 0..<result.frames {
                let t = result.startSampleTime + Int64(i)
                let expected: Float = i < result.silencedFrames ? 0 : Float((t & 0x7FFF) + 1)
                if out[i] != expected { wrong += 1 }
            }
            total += result.frames
            silencedTotal += result.silencedFrames
        }
        XCTAssertEqual(wrong, 0, """
            \(wrong) kept frames held a value that was never written for their sample time — a \
            torn read the claim cursor exists to catch (H1). A lost frame must come out as a \
            counted zero, never as someone else's audio.
            """)
        XCTAssertEqual(total, blocks * blockFrames, "the stem is exactly as long as what was written")
        XCTAssertEqual(Int64(silencedTotal), ring.lostFrames, "every silenced frame is counted")
        XCTAssertEqual(ring.discontinuities, 0)
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
