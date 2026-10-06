// Video sound excerpt — founder video/visual request, 2026-10-06.
// BEHAVIOUR: validates source ranges and exports a measured excerpt through the real
// AVFoundation path. A three-tone audio fixture represents the video's audio track;
// length AND spectrum distinguish the selected middle from a same-length wrong offset.
// COUNTERWEIGHTS: nil selection still exports the whole source; stale bounds are refused;
// the original bytes survive. This is not a video-picture or UI/device test.
// No local Swift toolchain: native execution is pending CI. The new API is absent on the
// parent, so these new tests have no executable parent verdict. Dropping session.timeRange
// must fail duration; replacing the start with zero must fail the frequency comparison.

import Foundation
import XCTest
@testable import Echoelmusic
#if canImport(AVFoundation)
import AVFoundation
#endif

final class AVideoSoundExcerptUsesTheSelectedRangeTests: XCTestCase {
    func testOnlyFiniteNonemptyRangesInsideTheSourceAreAccepted() throws {
        let middle = try XCTUnwrap(VideoSoundRange(startSeconds: 1.2, endSeconds: 1.8,
                                                  durationSeconds: 3))
        XCTAssertEqual(middle.startSeconds, 1.2)
        XCTAssertEqual(middle.endSeconds, 1.8)
        XCTAssertNotNil(VideoSoundRange(startSeconds: 0, endSeconds: 3, durationSeconds: 3))
        for (start, end, duration) in [
            (-1.0, 1.0, 3.0), (1, 1, 3), (2, 1, 3), (0, 4, 3),
            (0, 1, 0), (Double.nan, 1, 3), (0, Double.infinity, 3),
            (0, 1, Double.infinity), (0, 1, Double.nan)
        ] {
            XCTAssertNil(VideoSoundRange(startSeconds: start, endSeconds: end,
                                         durationSeconds: duration))
        }
    }

    #if canImport(AVFoundation)
    func testTheExportContainsTheChosenMiddleAndPreservesTheSource() async throws {
        let input = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-excerpt-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: input) }
        try writeThreeTones(to: input)
        let original = try Data(contentsOf: input)
        let selection = try XCTUnwrap(VideoSoundRange(startSeconds: 1.2, endSeconds: 1.8,
                                                     durationSeconds: 3))
        let result = await VideoSound.extract(from: input, named: "middle", selection: selection)
        let excerpt = try XCTUnwrap(result)
        defer { VideoSound.discard(excerpt) }
        let measured = try measure(excerpt)
        XCTAssertEqual(measured.duration, 0.6, accuracy: 0.05, "AAC padding is not a whole-source export")
        XCTAssertGreaterThan(measured.middle, 0.1, "the selected tone must actually be audible")
        XCTAssertGreaterThan(measured.middle, 15 * measured.first,
                             "a short export from zero has the right length but the wrong content")
        XCTAssertGreaterThan(measured.middle, 15 * measured.last)
        XCTAssertEqual(try Data(contentsOf: input), original, "the source is never edited in place")

        let wholeResult = await VideoSound.extract(from: input, named: "whole")
        let whole = try XCTUnwrap(wholeResult)
        defer { VideoSound.discard(whole) }
        XCTAssertEqual(try measure(whole).duration, 3, accuracy: 0.05,
                       "existing callers without a selection retain the whole sound")

        let stale = try XCTUnwrap(VideoSoundRange(startSeconds: 2, endSeconds: 4, durationSeconds: 5))
        let refused = await VideoSound.extract(from: input, named: "stale", selection: stale)
        XCTAssertNil(refused, "bounds are revalidated against the actual file before export")
    }

    private func writeThreeTones(to url: URL) throws {
        let rate = 48_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let count = 144_000
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format,
                                                   frameCapacity: AVAudioFrameCount(count)))
        buffer.frameLength = AVAudioFrameCount(count)
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        for i in 0..<count {
            let frequency = [440.0, 880.0, 1_760.0][i / 48_000]
            channel[i] = Float(0.4 * sin(2 * Double.pi * frequency * Double(i) / rate))
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func measure(_ url: URL) throws -> (duration: Double, first: Double,
                                               middle: Double, last: Double) {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        let count = Int(buffer.frameLength)
        let window = Int(rate / 10)
        guard count >= window else {
            XCTFail("an excerpt contains too few samples to measure")
            return (Double(count) / rate, 0, 0, 0)
        }
        let start = (count - window) / 2
        func amplitude(at frequency: Double) -> Double {
            var real = 0.0, imaginary = 0.0
            for i in 0..<window {
                let angle = 2 * Double.pi * frequency * Double(i) / rate
                let value = Double(channel[start + i])
                real += value * cos(angle)
                imaginary += value * sin(angle)
            }
            return 2 * sqrt(real * real + imaginary * imaginary) / Double(window)
        }
        return (Double(count) / rate, amplitude(at: 440), amplitude(at: 880), amplitude(at: 1_760))
    }
    #endif
}
