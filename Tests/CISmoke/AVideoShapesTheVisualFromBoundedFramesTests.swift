// AVideoShapesTheVisualFromBoundedFramesTests.swift
// MV2a (founder order 2026-09-27): a short video is read by AVFoundation in a bounded number of
// small frames (`VideoSeedReader`), and its `VideoSeed` is applied to the EXISTING visual path —
// the same six `visual.*` keys and the preset chip a photo writes — and can be taken back.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped, Foundation-only types (`VideoSeedLook`,
//     `VisualLookSnapshot`, `MediaSeedApplication`) against a private `UserDefaults` suite.
//   · Claim 3 is END-TO-END through AVFoundation: it WRITES a real 2-second movie (black, then a
//     hard cut to white) and reads it with the shipped `VideoSeedReader`.
//   · Claim 4 is a SOURCE-TEXT SCAN over the reader.
//   · DEVICE PROBE, open: a real phone video — HEVC, portrait, variable frame rate — reads in
//     reasonable time and its numbers look right to a person. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (0b1a2d8f3, §3): the file does not COMPILE there — it names
// `VideoSeedLook` and `VideoSeedReader`, which this commit creates — so no assertion has a verdict
// on the parent. All claims are FORWARD guards (one absence, #486). Claims 1, 2 and 4 are
// hand-transcribed in Python; claim 3 needs AVFoundation and is graded by the gate alone. Mutants
// driven, each red for its named reason: motion taken from the CURRENT look instead of the video
// (claim 1), detail passed through the preset's Float (claim 1, the exact-keep), an implausible
// seed applied anyway (claim 2), the zero tolerance removed from the reader (claim 4).

import Foundation
import XCTest
@testable import Echoelmusic
#if canImport(AVFoundation) && canImport(CoreVideo)
import AVFoundation
import CoreVideo
#endif

final class AVideoShapesTheVisualFromBoundedFramesTests: XCTestCase {

    private func freshDefaults() throws -> UserDefaults {
        let name = "echoel.tests.videoSeedLook.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return suite
    }

    private func seed(motion: Double = 0.5, brightness: Double = 0.5, hue: Double = 0.25,
                      coloured: Bool = true) -> VideoSeed {
        VideoSeed(version: VideoSeed.formatVersion, durationSeconds: 4, frameRate: 30,
                  brightness: brightness, hue: hue, saturation: 0.5, hasDominantColour: coloured,
                  motionEnergy: motion, transientTimes: [1], sampledFrames: 16)
    }

    private let look = VisualLookSnapshot(intensity: 1, detail: 37.3, motion: 0.9, spread: 0.83,
                                          hue: 0.1, saturation: 1.05, presetID: "vapor")

    // MARK: 1 — the video's picture change sets Motion; what it does not measure stays exactly

    func testTheVideoSetsMotionAndKeepsWhatItDoesNotMeasure() {
        let still = look.applying(seed(motion: 0))
        let busy = look.applying(seed(motion: 1))
        XCTAssertEqual(still.motion, VideoSeedLook.motionFloor, accuracy: 1e-6,
                       "a still clip slows the visual to the floor — it does not keep the old motion")
        XCTAssertGreaterThan(busy.motion, still.motion, "more picture change, more motion")
        XCTAssertLessThanOrEqual(busy.motion, 1.5, "inside the preset range")
        XCTAssertGreaterThan(still.motion, 0, "a still clip never freezes the visual")
        XCTAssertEqual(still.detail, 37.3, "detail is not measured for a video, so it is kept EXACTLY")
        XCTAssertEqual(still.spread, 0.83)
        XCTAssertLessThan(look.applying(seed(brightness: 0)).intensity, look.applying(seed(brightness: 1)).intensity)
        XCTAssertEqual(look.applying(seed(coloured: false)).hue, 0.1, "a grey video leaves the colour turn")
        XCTAssertEqual(look.applying(seed(hue: 0.25)).hue, 0.25, accuracy: 1e-6)
        XCTAssertEqual(still.presetID, "", "the result is no factory preset")
        let broken = look.applying(seed(motion: .nan, brightness: .infinity, hue: .nan))
        for v in [broken.intensity, broken.detail, broken.motion, broken.spread, broken.hue, broken.saturation] {
            XCTAssertTrue(v.isFinite, "a non-finite seed never reaches the renderer")
        }
    }

    // MARK: 2 — apply and undo are exact; an implausible stored seed applies nothing

    func testAVideoLookCanBeTakenBackAndABrokenSeedWritesNothing() throws {
        let defaults = try freshDefaults()
        look.write(to: defaults)
        let applied = try XCTUnwrap(MediaSeedApplication.apply(seed(motion: 1), to: defaults))
        XCTAssertEqual(applied.before, look)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after)
        applied.undo(on: defaults)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look, "undo puts back exactly what was there")

        var wrong = seed(); wrong.motionEnergy = 3
        XCTAssertFalse(wrong.isPlausible)
        XCTAssertNil(MediaSeedApplication.apply(wrong, to: defaults))
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look, "a refused seed changed nothing")
    }

    // MARK: 3 — a real movie is read small, and the cut is where it is

    #if canImport(AVFoundation) && canImport(CoreVideo)
    /// Writes a `frames`-frame movie at `fps`, every frame one grey level.
    private func writeMovie(frames: Int, fps: Int32, side: Int, level: (Int) -> UInt8) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-video-test-\(UUID().uuidString).mov")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                       AVVideoWidthKey: side, AVVideoHeightKey: side]
        let input = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: side,
                                         kCVPixelBufferHeightKey as String: side]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                           sourcePixelBufferAttributes: attributes)
        XCTAssertTrue(writer.canAdd(input))
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var created: CVPixelBuffer?
            CVPixelBufferCreate(nil, side, side, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &created)
            let buffer = try XCTUnwrap(created)
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(level(i)), CVPixelBufferGetBytesPerRow(buffer) * side)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "the fixture movie was written")
        return url
    }

    func testAMovieIsReadInBoundedFramesAndTheCutIsFound() async throws {
        // 20 frames at 10 fps: black for one second, then a hard cut to white.
        let url = try await writeMovie(frames: 20, fps: 10, side: 128) { $0 < 10 ? 0 : 255 }
        let maybeRead = await VideoSeedReader.read(url: url)
        let read = try XCTUnwrap(maybeRead, "a plain H.264 movie reads")
        let seed = read.seed
        XCTAssertTrue(seed.isPlausible)
        XCTAssertEqual(seed.durationSeconds, 2, accuracy: 0.15)
        XCTAssertTrue((5...20).contains(seed.frameRate), "the file's own rate, about 10 fps — got \(seed.frameRate)")
        XCTAssertLessThanOrEqual(seed.sampledFrames, VideoSeedReader.sampleCount, "the work is bounded")
        XCTAssertLessThanOrEqual(VideoSeedReader.sampleCount, VideoSeedAnalysis.maxSamples)
        XCTAssertEqual(seed.transientTimes.count, 1, "one cut, one transient — got \(seed.transientTimes)")
        if let cut = seed.transientTimes.first {
            XCTAssertTrue((1.0...1.25).contains(cut),
                          "the cut is found at the first sample after 1 s, not at a keyframe elsewhere — got \(cut)")
        }
        XCTAssertGreaterThan(seed.motionEnergy, 0)
        XCTAssertFalse(seed.hasDominantColour, "grey frames have no colour")
        XCTAssertLessThanOrEqual(max(read.proxy.width, read.proxy.height), VideoSeedReader.maxFrameSide)
        XCTAssertFalse(read.hasAudioTrack, "the fixture has no sound")
    }

    func testAFileThatIsNoVideoGivesNoSeed() async throws {
        let garbage = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-video-test-\(UUID().uuidString).mov")
        try Data("this is not a video".utf8).write(to: garbage)
        addTeardownBlock { try? FileManager.default.removeItem(at: garbage) }
        let fromGarbage = await VideoSeedReader.read(url: garbage)
        XCTAssertNil(fromGarbage, "unreadable media → no seed, nothing applied")
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-video-missing-\(UUID().uuidString).mov")
        let fromMissing = await VideoSeedReader.read(url: missing)
        XCTAssertNil(fromMissing)
    }
    #endif

    // MARK: 4 — the reader asks for the frame it means, bounded, cancellable, and never for sound

    func testTheReaderDecodesTheRequestedFrameAndNothingElse() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Studio/VideoSeedReader.swift"), encoding: .utf8))
        XCTAssertTrue(code.contains("requestedTimeToleranceBefore = .zero"),
                      "without it the generator returns the nearest KEYFRAME and a cut lands elsewhere")
        XCTAssertTrue(code.contains("requestedTimeToleranceAfter = .zero"))
        XCTAssertTrue(code.contains("generator.maximumSize"), "frames are decoded small")
        XCTAssertTrue(code.contains("if Task.isCancelled { return nil }"), "a newer pick stops an older read")
        XCTAssertTrue(code.contains("VideoSeedAnalysis.maxDurationSeconds"), "a long video is refused before decoding")
        for absent in ["AVAssetReader(", "AVAssetWriter", "AudioEngine", "EngineBus", "PatternEngine", "DispatchQueue"] {
            XCTAssertFalse(code.contains(absent), "the reader names `\(absent)`")
        }
    }
}
