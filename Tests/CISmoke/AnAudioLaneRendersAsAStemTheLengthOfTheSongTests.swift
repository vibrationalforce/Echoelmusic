// AnAudioLaneRendersAsAStemTheLengthOfTheSongTests.swift
// LS-ST3b (2026-10-16, ADR-008 K1): `AudioLaneStemRenderer` writes one audio lane as a mono
// 24-bit stem, offline, from its files and the document. It starts at song tick 0, is exactly as
// long as the song, carries the part's gain and fades, and refuses — before writing — anything it
// cannot reproduce (warp, transpose, an enabled lane effect, a missing file, a foreign rate).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–4 are END-TO-END: real `AVAudioFile`s in a temporary directory, rendered by the
//     shipped renderer and read back sample by sample. Nothing is mocked.
//   · Claim 5 is a SOURCE-TEXT SCAN for the one refusal no fixture here builds (an enabled insert).
//   · NOT CLAIMED: that the stem lines up with the live mix on a device (G-D, a DEVICE PROBE), and
//     that anything in the app calls the renderer — nothing does yet. Built: yes · wired: no.
//
// EXPECTED VALUES: the fixture's samples sit on the 2^-9 grid inside ±0.5, so a 24-bit round trip
// is exact; at 120 BPM a bar is 2 s = 96 000 frames at 48 kHz. Fade levels are ASKED of the part's
// own `fadePlan` (#416), never restated. The arithmetic of claims 1–2 was transcribed in Python.
//
// HONEST GRADING against the parent (§3): `AudioLaneStemRenderer` does not exist there — the file
// does not COMPILE on the parent, so no assertion has a verdict there; every claim is a FORWARD
// guard (one absence, #486). The file round trip itself has no transcription; its verdict is CI.
// Mutants: the song-length pad dropped (1) · the source position ignored (1) · channels summed
// without averaging (2) · the part gain or fades dropped (3) · a refusal moved after the file is
// opened (4, the file would exist).

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: the renderer and `StemFileWriter` are internal.
@testable import Echoelmusic

final class AnAudioLaneRendersAsAStemTheLengthOfTheSongTests: XCTestCase {

    private static let rate = 48_000.0
    private static let bar = TimelineTime.ticksPerBar
    private static let bpm: Double = 120
    private var directory = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaneStem-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Exact in 24 bit: multiples of 2^-9 inside ±0.5.
    private static func ramp(_ index: Int) -> Float { Float((index % 200) - 100) / 512 }

    /// A float32 WAV with `channels` channels; channel `c` holds `value(c, frame)`.
    private func writeSource(_ name: String, frames: Int, channels: Int = 1, rate: Double = 48_000,
                             value: (Int, Int) -> Float) throws -> URL {
        let url = directory.appendingPathComponent("\(name).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else { throw XCTSkip("no PCM buffer for the fixture") }
        buffer.frameLength = AVAudioFrameCount(frames)
        for c in 0..<channels { for f in 0..<frames { data[c][f] = value(c, f) } }
        try file.write(from: buffer)
        return url
    }

    private func readBack(_ url: URL) throws -> (samples: [Float], bitDepth: Int?, channels: AVAudioChannelCount) {
        let file = try AVAudioFile(forReading: url)
        let frames = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: Swift.max(frames, 1)) else {
            XCTFail("no read buffer"); return ([], nil, 0)
        }
        try file.read(into: buffer, frameCount: frames)
        var samples: [Float] = []
        if let channel = buffer.floatChannelData?[0] {
            samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        return (samples, file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int, file.fileFormat.channelCount)
    }

    private func firstMismatch(_ actual: ArraySlice<Float>, _ expected: (Int) -> Float) -> Int? {
        for (offset, value) in actual.enumerated() where abs(value - expected(offset)) > 1e-5 { return offset }
        return nil
    }

    // MARK: 1 — the stem starts at tick 0, is as long as the song, and holds the part where it plays

    func testTheStemIsTheSongsLengthWithThePartInPlace() throws {
        let lane = TimelineLane(name: "Loop", kind: .audio)
        let other = TimelineLane(name: "Later", kind: .audio)
        let clip = UUID()
        let source = try writeSource("loop", frames: 3 * 48_000) { _, f in Self.ramp(f) }
        let part = TimelineRegion(laneID: lane.id, clipID: clip, startTick: Self.bar,
                                  lengthTicks: Self.bar, contentOffsetSeconds: 0.25)
        // Another lane's part sets the song's end at 3 bars, past this lane's last part.
        let tail = TimelineRegion(laneID: other.id, clipID: UUID(), startTick: 2 * Self.bar, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [lane, other], regions: [part, tail])
        let out = directory.appendingPathComponent("stem.wav")
        let report = try AudioLaneStemRenderer.render(document: doc, laneID: lane.id, bpm: Self.bpm,
                                                      sampleRate: Self.rate, to: out,
                                                      resolveURL: { $0 == clip ? source : nil })
        XCTAssertEqual(report, AudioLaneStemRenderer.Report(frames: 288_000, segmentsWritten: 1))
        let stem = try readBack(out)
        XCTAssertEqual(stem.samples.count, 288_000, "the stem is exactly as long as the song")
        XCTAssertEqual(stem.bitDepth, StemFileWriter.fileBitDepth)
        XCTAssertEqual(stem.channels, 1, "the stem is mono")
        XCTAssertNil(firstMismatch(stem.samples[0..<96_000], { _ in 0 }), "silence before the part")
        XCTAssertNil(firstMismatch(stem.samples[96_000..<192_000], { Self.ramp(12_000 + $0) }),
                     "the part plays its file from its offset (0.25 s = 12 000 frames)")
        XCTAssertNil(firstMismatch(stem.samples[192_000..<288_000], { _ in 0 }), "silence after it, to the song's end")
    }

    // MARK: 2 — a stereo source is folded to mono by averaging

    func testAStereoSourceIsAveragedToMono() throws {
        let lane = TimelineLane(name: "Loop", kind: .audio)
        let clip = UUID()
        let source = try writeSource("stereo", frames: 96_000, channels: 2) { c, f in c == 0 ? Self.ramp(f) : 0 }
        let part = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)
        let out = directory.appendingPathComponent("stem.wav")
        _ = try AudioLaneStemRenderer.render(document: TimelineDocument(lanes: [lane], regions: [part]),
                                             laneID: lane.id, bpm: Self.bpm, sampleRate: Self.rate, to: out,
                                             resolveURL: { $0 == clip ? source : nil })
        let stem = try readBack(out)
        XCTAssertEqual(stem.samples.count, 96_000)
        XCTAssertNil(firstMismatch(stem.samples[0..<96_000], { Self.ramp($0) / 2 }), "left plus silent right, halved")
    }

    // MARK: 3 — the part's gain and fades are in the stem, asked of the part's own fade plan

    func testThePartsGainAndFadesAreInTheStem() throws {
        let lane = TimelineLane(name: "Loop", kind: .audio)
        let clip = UUID()
        let source = try writeSource("flat", frames: 96_000) { _, _ in 0.25 }
        let part = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar,
                                  gain: 0.5, fadeInTicks: 480, fadeOutTicks: 480)
        guard let fades = AudioRegionPlayback.fadePlan(for: part, bpm: Self.bpm, stretchRate: 1) else {
            return XCTFail("premise: the part has fades")
        }
        let out = directory.appendingPathComponent("stem.wav")
        _ = try AudioLaneStemRenderer.render(document: TimelineDocument(lanes: [lane], regions: [part]),
                                             laneID: lane.id, bpm: Self.bpm, sampleRate: Self.rate, to: out,
                                             resolveURL: { $0 == clip ? source : nil })
        let stem = try readBack(out)
        XCTAssertEqual(stem.samples.count, 96_000)
        for frame in [0, 6_000, 12_000, 48_000, 90_000, 95_999] {
            let expected = 0.25 * 0.5 * Float(fades.gain(atMediaSeconds: Double(frame) / Self.rate))
            XCTAssertEqual(stem.samples[frame], expected, accuracy: 1e-5, "frame \(frame)")
        }
        XCTAssertEqual(stem.samples[48_000], 0.125, accuracy: 1e-5, "premise: the middle is at the part's gain")
    }

    // MARK: 4 — what it cannot reproduce it refuses, before the file exists

    func testWhatItCannotReproduceItRefusesBeforeWriting() throws {
        let lane = TimelineLane(name: "Loop", kind: .audio)
        let clip = UUID()
        let source = try writeSource("loop", frames: 96_000) { _, f in Self.ramp(f) }
        let foreign = try writeSource("foreign", frames: 88_200, rate: 44_100) { _, f in Self.ramp(f) }
        let out = directory.appendingPathComponent("refused.wav")
        func attempt(_ part: TimelineRegion, resolve: @escaping (UUID) -> URL?,
                     native: @escaping (UUID) -> Double = { _ in 0 }) -> AudioLaneStemRenderer.Refusal? {
            do {
                _ = try AudioLaneStemRenderer.render(document: TimelineDocument(lanes: [lane], regions: [part]),
                                                     laneID: lane.id, bpm: Self.bpm, sampleRate: Self.rate,
                                                     to: out, resolveURL: resolve, nativeBPM: native)
                return nil
            } catch let refusal as AudioLaneStemRenderer.Refusal {
                return refusal
            } catch {
                XCTFail("unexpected error \(error)")
                return nil
            }
        }
        let warped = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar, warpEnabled: true)
        XCTAssertEqual(attempt(warped, resolve: { _ in source }, native: { _ in 60 }), .warped(regionID: warped.id))
        let transposed = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar,
                                        transposeSemitones: 3)
        XCTAssertEqual(attempt(transposed, resolve: { _ in source }), .transposed(regionID: transposed.id))
        let plain = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)
        XCTAssertEqual(attempt(plain, resolve: { _ in nil }), .unresolved(clipID: clip))
        XCTAssertEqual(attempt(plain, resolve: { _ in foreign }), .sampleRateMismatch(clipID: clip, fileRate: 44_100))
        let notAudio = TimelineLane(name: "Keys", kind: .midi)
        XCTAssertThrowsError(try AudioLaneStemRenderer.render(
            document: TimelineDocument(lanes: [notAudio], regions: []), laneID: notAudio.id, bpm: Self.bpm,
            sampleRate: Self.rate, to: out, resolveURL: { _ in source })) { error in
            XCTAssertEqual(error as? AudioLaneStemRenderer.Refusal, .noSuchAudioLane,
                           "a silent stem for a lane that is not an audio lane would read as a real one")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.path), "a refusal wrote a file")
        XCTAssertNil(attempt(plain, resolve: { _ in source }), "COUNTERWEIGHT: the plain part renders")
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }

    // MARK: 5 — an enabled lane effect is refused (no fixture builds one here)

    func testAnEnabledLaneEffectIsRefused() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Audio/AudioLaneStemRenderer.swift"), encoding: .utf8))
        XCTAssertTrue(code.contains(".contains(where: { $0.isEnabled }) == true {\n            throw Refusal.laneHasEffects"))
        XCTAssertTrue(code.contains("StemFileWriter.fileSettings(sampleRate: sampleRate)"),
                      "the stem is written in the stem writer's one format")
    }
}
#endif
