// TheSamplerKeepsAStereoSampleStereoTests.swift
// SS2 (2026-10-16, live-set audit "Sampler stereo"): `SamplerVoice` folded every file to mono at
// load. A stereo loop on a Sampler track lost its image. Now a file with two or more channels
// keeps two, the node is two-channel, and a mono file renders the same signal to both sides.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END: a real WAV loaded by the shipped `loadSample`, rendered by the
//     render the source node runs (`_testRender`), read sample by sample.
//   · Claim 4 is a SOURCE-TEXT SCAN: the node is built two-channel and the right channel has its
//     own filter state.
//   · NOT CLAIMED (DEVICE PROBE): whether a MONO sample at centre is as loud as before. The node
//     used to be mono and the mixer up-mixed it; now the voice writes the signal to both channels,
//     as the stereo synth already does. Whether Apple's mixer up-mix was unity or −3 dB is not
//     measurable here. NEEDS-FOUNDER-VERIFY: a Sampler track with a mono hit, before/after this
//     build, same fader — same loudness?
//
// EXPECTED VALUES: constant-valued fixtures (0.5 / −0.25) so linear interpolation at rate 1 is
// exact; the first 256 frames of a 4 800-frame file sit outside the 512-frame release ramp, the
// attack is 0 and the gain 1, so every rendered sample equals the file's.
//
// HONEST GRADING against the parent (§3): claims 1 and 3 are REGRESSIONS — the parent loads the
// stereo file as mono ((0.5 + −0.25) / 2 = 0.125 on BOTH sides, and only the first buffer is
// written: the right buffer stays 0). Claim 2 is a COUNTERWEIGHT (mono stays mono on the first
// buffer on both trees; the right-buffer half is new). Claim 4's node-format needle is a
// REGRESSION, the `insertFXRight` needle a FORWARD guard. Mutants: the converter kept at one
// channel (1, 3) · right read from the left channel (1) · the one-buffer fold dropped (3).

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `_testRender` is an internal test hook.
@testable import Echoelmusic

final class TheSamplerKeepsAStereoSampleStereoTests: XCTestCase {

    private static let frames = 256
    private var urls: [URL] = []

    override func tearDown() {
        for url in urls { try? FileManager.default.removeItem(at: url) }
        urls = []
        super.tearDown()
    }

    /// A 48 kHz float WAV, 4 800 frames, channel `c` constant at `values[c]`.
    private func writeWAV(_ values: [Float]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ss2-\(UUID().uuidString).wav")
        urls.append(url)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: values.count,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = 4_800
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else { throw XCTSkip("no PCM buffer for the fixture") }
        buffer.frameLength = AVAudioFrameCount(frames)
        for c in values.indices { for f in 0..<frames { data[c][f] = values[c] } }
        try file.write(from: buffer)
        return url
    }

    /// Renders one block into `bufferCount` planar buffers and returns them.
    private func render(_ voice: SamplerVoice, bufferCount: Int) -> [[Float]] {
        let frames = Self.frames
        let list = AudioBufferList.allocate(maximumBuffers: bufferCount)
        defer { free(list.unsafeMutablePointer) }
        var storage: [UnsafeMutablePointer<Float>] = []
        for i in 0..<bufferCount {
            let channel = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            channel.initialize(repeating: 9, count: frames)   // not zero: an unwritten buffer shows
            storage.append(channel)
            list[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                                  mData: UnsafeMutableRawPointer(channel))
        }
        defer { for channel in storage { channel.deallocate() } }
        voice._testRender(frameCount: frames, audioBufferList: list.unsafeMutablePointer)
        return storage.map { Array(UnsafeBufferPointer(start: $0, count: frames)) }
    }

    private func loaded(_ values: [Float]) throws -> SamplerVoice {
        let voice = SamplerVoice()
        try voice.loadSample(from: try writeWAV(values))
        voice.fire()
        return voice
    }

    // MARK: 1 — a stereo file plays left on the left, right on the right

    func testAStereoSampleKeepsBothSides() throws {
        let out = render(try loaded([0.5, -0.25]), bufferCount: 2)
        XCTAssertEqual(out[0], [Float](repeating: 0.5, count: Self.frames), "the left channel is the file's left")
        XCTAssertEqual(out[1], [Float](repeating: -0.25, count: Self.frames), "the right channel is the file's right")
    }

    // MARK: 2 — counterweight: a mono file is the same signal on both sides

    func testAMonoSampleIsTheSameOnBothSides() throws {
        let out = render(try loaded([0.5]), bufferCount: 2)
        XCTAssertEqual(out[0], [Float](repeating: 0.5, count: Self.frames))
        XCTAssertEqual(out[1], out[0], "a mono sample writes one signal to both channels")
    }

    // MARK: 3 — with one buffer (the test hook's old shape) a stereo sample folds to its average

    func testOneBufferFoldsAStereoSampleToItsAverage() throws {
        let out = render(try loaded([0.5, -0.25]), bufferCount: 1)
        XCTAssertEqual(out[0], [Float](repeating: 0.125, count: Self.frames))
        let mono = render(try loaded([0.5]), bufferCount: 1)
        XCTAssertEqual(mono[0], [Float](repeating: 0.5, count: Self.frames), "COUNTERWEIGHT: mono is untouched")
    }

    // MARK: 4 — the node is two-channel and each side has its own filter

    func testTheNodeIsTwoChannelAndEachSideHasItsOwnFilter() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Sequencer/SamplerVoice.swift"), encoding: .utf8))
        XCTAssertTrue(code.contains("standardFormatWithSampleRate: Self.sampleRate, channels: 2"),
                      "the node is two-channel, or a stereo sample cannot leave it stereo")
        XCTAssertTrue(code.contains("right[i] = insertFXRight.process(right[i])"),
                      "the right channel runs through its own filter state — one biquad cannot carry two signals")
        XCTAssertTrue(code.contains("insertFXRight.reset()"), "a new hit starts both filters clean")
    }
}
#endif
