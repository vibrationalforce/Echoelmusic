//
//  TheStemRingKeepsEveryStemAlignedTests.swift
//  Spatial S-A3a. ADR-008 (accepted 2026-10-04) captures every stem of an immersive master in
//  ONE realtime pass, aligned by the engine's sample time, as long as the master, with a gap
//  filled by silence and a loss counted instead of hidden. `StemCaptureRing` is the one ring a
//  stem goes through; this guard pins those four promises on the ring itself.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–7) — the shipped ring, single-threaded: write as the audio
//    thread would, read as the writer thread would. Nothing is mocked.
//  · SOURCE-TEXT SCAN (claim 8) — the producer path allocates nothing, takes no lock, logs
//    nothing, and publishes its cursor only through `RetroRingCursor`.
//  · NOT PINNED, and said so: the CONCURRENT behaviour (a write racing a read). A unit test
//    cannot schedule two threads deterministically; that half is the review of the fences
//    (the release in `write`, the acquire plus the explicit barrier in `read`) and a device run.
//    Nor that anything writes a stem in the app — nothing does yet (S-A3b/c).
//    Built: yes · wired: no · device: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid a different overlap policy or
//  a different minimum size — those are decisions; change ADR-008 and this guard together.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `StemCaptureRing` is
//  created by this commit — so no assertion has a verdict there (ONE absence, #486). Claims 1–7
//  were transcribed in Python against the ring's arithmetic; claim 4 is red against a mutant
//  that drops the overrun count, claim 2 against one that shifts instead of filling, claim 8
//  against a mutant whose `write` builds a `String`.
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
