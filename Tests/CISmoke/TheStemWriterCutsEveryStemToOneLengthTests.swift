//
//  TheStemWriterCutsEveryStemToOneLengthTests.swift
//  Spatial S-A3c-1. ADR-008 §4–§5: one writer thread drains every stem ring to a 24-bit PCM file,
//  and every stem of a take starts at the same engine sample time and ends at the same one.
//  `StemFileWriter` is that writer; this guard pins the promises on real files.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–7) — the shipped ring and writer, real `AVAudioFile`s in a
//    temporary directory, read back and compared sample by sample. Nothing is mocked.
//  · NOT PINNED, and said so: that anything in the app constructs a writer — nothing does yet
//    (S-A3c-2). Built: yes · wired: no · device: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid a different file format or bit
//  depth — that is ADR-008 §4; change the ADR and this guard together.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `StemFileWriter` is created
//  by this commit (ONE absence, #486). The arithmetic of claims 1–3 and 5–6 (lengths, padding,
//  cut, silenced count) was transcribed in Python against the writer's loop: claim 1 is red
//  against a mutant that skips the padding, claim 2 against one that drains without the end cap,
//  claim 6 against one that does not sum `silencedFrames`. The file round trip (24-bit int,
//  sample values) has no transcription — its verdict is the CI run alone.
//
//  `Tests/CISmoke` is the blocking bundle.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
@testable import Echoelmusic

final class TheStemWriterCutsEveryStemToOneLengthTests: XCTestCase {

    private static let rate = 48_000.0
    private var directory = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StemWriter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Values on the 2^-8 grid inside ±0.5 survive a 24-bit integer round trip exactly.
    private func ramp(_ count: Int, from first: Int = 0) -> [Float] {
        (0..<count).map { Float(((first + $0) % 200) - 100) / 256 }
    }

    /// A 24-bit round trip is exact on this grid in principle; the tolerance only absorbs a
    /// converter that rounds the last bit differently, never a misplaced or missing sample.
    private func assertSamples(_ actual: [Float], _ expected: [Float], _ message: String = "",
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "length — \(message)", file: file, line: line)
        for (index, (a, e)) in zip(actual, expected).enumerated() where abs(a - e) > 1e-5 {
            XCTFail("sample \(index): \(a) ≠ \(e) — \(message)", file: file, line: line)
            return
        }
    }

    private func write(_ ring: StemCaptureRing, _ values: [Float], at sampleTime: Int64) {
        values.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            ring.write(base, frameCount: buffer.count, sampleTime: sampleTime)
        }
    }

    private func stem(_ name: String, _ ring: StemCaptureRing) -> StemFileWriter.Stem {
        StemFileWriter.Stem(name: name, ring: ring, url: directory.appendingPathComponent("\(name).wav"))
    }

    private func readBack(_ name: String) throws -> (samples: [Float], bitDepth: Int?, rate: Double, channels: AVAudioChannelCount) {
        let file = try AVAudioFile(forReading: directory.appendingPathComponent("\(name).wav"))
        let frames = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: max(frames, 1)) else {
            XCTFail("no read buffer"); return ([], nil, 0, 0)
        }
        try file.read(into: buffer, frameCount: frames)
        var samples: [Float] = []
        if let channel = buffer.floatChannelData?[0] {
            samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        let depth = file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int
        return (samples, depth, file.fileFormat.sampleRate, file.fileFormat.channelCount)
    }

    // MARK: 1 — a short stem is filled with silence up to the common end, and the fill is counted

    func testAShortStemIsPaddedToTheCommonEnd() throws {
        let long = StemCaptureRing(capacityFrames: 1_024, startSampleTime: 1_000)
        let short = StemCaptureRing(capacityFrames: 1_024, startSampleTime: 1_000)
        write(long, ramp(300), at: 1_000)
        write(short, ramp(200, from: 7), at: 1_000)
        let writer = try StemFileWriter(stems: [stem("long", long), stem("short", short)], sampleRate: Self.rate)
        let reports = try writer.finish(endSampleTime: 1_300)
        XCTAssertEqual(reports.map(\.framesWritten), [300, 300], "every stem is exactly as long as the take")
        XCTAssertEqual(reports.map(\.paddedFrames), [0, 100], "the fill is counted, never hidden")
        let a = try readBack("long"), b = try readBack("short")
        XCTAssertEqual(a.samples.count, 300)
        XCTAssertEqual(b.samples.count, 300)
        assertSamples(a.samples, ramp(300))
        assertSamples(Array(b.samples.prefix(200)), ramp(200, from: 7))
        assertSamples(Array(b.samples.suffix(100)), [Float](repeating: 0, count: 100), "the tail is silence in place")
    }

    // MARK: 2 — a stem that holds more than the take is cut at the common end

    func testALongStemIsCutAtTheCommonEnd() throws {
        let ring = StemCaptureRing(capacityFrames: 1_024, startSampleTime: 0)
        write(ring, ramp(500), at: 0)
        let writer = try StemFileWriter(stems: [stem("cut", ring)], sampleRate: Self.rate, chunkFrames: 64)
        let reports = try writer.finish(endSampleTime: 300)
        XCTAssertEqual(reports.first?.framesWritten, 300, "a stem is never longer than the master")
        assertSamples(try readBack("cut").samples, ramp(300))
        XCTAssertEqual(ring.readSampleTime, 300, "the writer reads exactly to the end and no further")
    }

    // MARK: 3 — draining while the take runs gives the same file as draining at the end

    func testDrainingInPassesConcatenates() throws {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        let writer = try StemFileWriter(stems: [stem("passes", ring)], sampleRate: Self.rate, chunkFrames: 50)
        write(ring, ramp(100), at: 0)
        XCTAssertEqual(try writer.drainAvailable(), 100)
        write(ring, ramp(100, from: 100), at: 100)
        XCTAssertEqual(try writer.drainAvailable(), 100)
        XCTAssertEqual(try writer.drainAvailable(), 0, "nothing new, nothing written")
        _ = try writer.finish(endSampleTime: 200)
        assertSamples(try readBack("passes").samples, ramp(200))
    }

    // MARK: 4 — the files are mono, 24-bit integer PCM at the take's rate

    func testTheFilesAreMonoTwentyFourBitAtTheTakeRate() throws {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        write(ring, ramp(64), at: 0)
        _ = try StemFileWriter(stems: [stem("format", ring)], sampleRate: Self.rate).finish(endSampleTime: 64)
        let file = try readBack("format")
        XCTAssertEqual(file.bitDepth, StemFileWriter.fileBitDepth)
        XCTAssertEqual(StemFileWriter.fileBitDepth, 24, "ADR-008 §4: PCM 24 bit")
        XCTAssertEqual(file.rate, Self.rate)
        XCTAssertEqual(file.channels, 1, "one stem, one channel — a stereo voice is two stems")
    }

    // MARK: 5 — rings that do not share a zero point are refused; so is every misuse

    func testMisalignedRingsAndMisuseAreRefused() throws {
        let a = StemCaptureRing(capacityFrames: 256, startSampleTime: 0)
        let b = StemCaptureRing(capacityFrames: 256, startSampleTime: 1)
        XCTAssertThrowsError(try StemFileWriter(stems: [stem("a", a), stem("b", b)], sampleRate: Self.rate)) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .mismatchedStart, "a stem never starts a bit later")
        }
        XCTAssertThrowsError(try StemFileWriter(stems: [], sampleRate: Self.rate)) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .noStems)
        }
        XCTAssertThrowsError(try StemFileWriter(stems: [stem("nan", a)], sampleRate: .nan)) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .formatUnavailable)
        }
        let writer = try StemFileWriter(stems: [stem("once", a)], sampleRate: Self.rate)
        XCTAssertThrowsError(try writer.finish(endSampleTime: -1)) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .endBeforeStart)
        }
        _ = try writer.finish(endSampleTime: 0)
        XCTAssertThrowsError(try writer.finish(endSampleTime: 0)) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .alreadyFinished)
        }
        XCTAssertThrowsError(try writer.drainAvailable()) {
            XCTAssertEqual($0 as? StemFileWriter.WriterError, .alreadyFinished)
        }
    }

    // MARK: 6 — what the producer overwrote before the writer got there is counted, in place

    func testOverwrittenFramesAreCountedInTheReport() throws {
        let ring = StemCaptureRing(capacityFrames: 64, startSampleTime: 0)
        write(ring, ramp(200), at: 0)
        let reports = try StemFileWriter(stems: [stem("lost", ring)], sampleRate: Self.rate).finish(endSampleTime: 200)
        XCTAssertEqual(reports.first?.silencedFrames, 136, "200 written into a 64-frame ring: 136 overwritten")
        let samples = try readBack("lost").samples
        XCTAssertEqual(samples.count, 200, "the loss keeps the length")
        assertSamples(Array(samples.prefix(136)), [Float](repeating: 0, count: 136))
        assertSamples(Array(samples.suffix(64)), Array(ramp(200).suffix(64)))
    }

    // MARK: 7 — a refused jump in a ring reaches the report, so the exporter can abort

    func testARingDiscontinuityReachesTheReport() throws {
        let ring = StemCaptureRing(capacityFrames: 256, startSampleTime: 10_000)
        write(ring, ramp(64), at: 10_000)
        write(ring, ramp(64), at: 5_000)              // engine time ran backwards: refused, counted
        let reports = try StemFileWriter(stems: [stem("jump", ring)], sampleRate: Self.rate).finish(endSampleTime: 10_064)
        XCTAssertEqual(reports.first?.discontinuities, 1, "a jump the ring refused must reach the exporter")
        XCTAssertEqual(reports.first?.framesWritten, 64)
    }
}
#endif
