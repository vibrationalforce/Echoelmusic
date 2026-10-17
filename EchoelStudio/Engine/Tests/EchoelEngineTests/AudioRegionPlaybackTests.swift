import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

final class AudioRegionPlaybackTests: XCTestCase {
    private let rate = 48_000.0
    /// One beat at 120 BPM, in output samples.
    private let beat = 24_000

    private struct Song {
        var project: Project
        var track: TrackID
        var region: RegionID
        var media: MediaFile
    }

    /// One audio track holding one region of a file `frames` long, recorded at `fileRate`,
    /// placed one beat into the song.
    private func song(frames: Int, fileRate: Double) throws -> Song {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: frames, sampleRate: fileRate)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id, start: MusicalTime.ticksPerQuarter).apply(to: &project)
        return Song(project: project, track: track, region: region, media: media)
    }

    private func playing(_ project: Project, samples: [MediaID: SampleBuffer]) -> EngineCore {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, samples: samples))
        engine.play()
        return engine
    }

    private func render(_ engine: EngineCore, frames: Int, block: Int = 256) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    engine.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return left
    }

    /// The centre-pan gain of one channel.
    private let centre = Float(0.5).squareRoot()

    func testARegionStartsOnItsBeatPlaysAtTheFilesOwnSpeedAndEnds() throws {
        // 4,800 frames at 24 kHz is 0.2 s, so 9,600 output samples at 48 kHz.
        let s = try song(frames: 4_800, fileRate: 24_000)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 4_800), sampleRate: 24_000))
        let out = render(playing(s.project, samples: [s.media.id: buffer]), frames: 2 * beat)

        XCTAssertTrue(out[..<beat].allSatisfy { $0 == 0 }, "silent before the region")
        XCTAssertEqual(out[beat], 0, accuracy: 1e-6, "the region fades in from silence")
        XCTAssertEqual(out[beat + 4_800], 0.5 * centre, accuracy: 1e-4)
        XCTAssertTrue(out[(beat + 9_600)...].allSatisfy { $0 == 0 }, "silent once the file has played")
    }

    func testATrimPlaysOnlyThePartItChose() throws {
        var s = try song(frames: 9_600, fileRate: rate)
        let samples = Array(repeating: Float(0.25), count: 4_800) + Array(repeating: Float(0.75), count: 4_800)
        let buffer = try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate))
        try Command.trimRegion(track: s.track, s.region, offset: 4_800, length: 2_400).apply(to: &s.project)
        let out = render(playing(s.project, samples: [s.media.id: buffer]), frames: 2 * beat)

        XCTAssertEqual(out[beat + 1_200], 0.75 * centre, accuracy: 1e-4, "starts at the chosen frame")
        XCTAssertTrue(out[(beat + 2_400)...].allSatisfy { $0 == 0 }, "stops after the chosen length")
    }

    func testMuteSilencesAndAMissingFileIsSilent() throws {
        var s = try song(frames: 4_800, fileRate: rate)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 4_800), sampleRate: rate))
        XCTAssertTrue(render(playing(s.project, samples: [:]), frames: 2 * beat).allSatisfy { $0 == 0 })
        try Command.setMute(s.track, true).apply(to: &s.project)
        XCTAssertTrue(render(playing(s.project, samples: [s.media.id: buffer]), frames: 2 * beat).allSatisfy { $0 == 0 })
    }

    func testTheOutputDoesNotDependOnTheBlockSize() throws {
        let s = try song(frames: 7_000, fileRate: 44_100)
        let ramp = (0..<7_000).map { Float($0) / 7_000 }
        let buffer = try XCTUnwrap(SampleBuffer(samples: ramp, sampleRate: 44_100))
        let small = render(playing(s.project, samples: [s.media.id: buffer]), frames: 2 * beat, block: 64)
        let large = render(playing(s.project, samples: [s.media.id: buffer]), frames: 2 * beat, block: 4_000)
        XCTAssertEqual(small, large)
    }

    func testTheExportRunsToTheEndOfTheLastRegion() throws {
        let s = try song(frames: 4_800, fileRate: rate)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 4_800), sampleRate: rate))
        let result = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, samples: [s.media.id: buffer])
        XCTAssertEqual(result.frameCount, beat + 4_800)
        XCTAssertGreaterThan(result.peak, 0.3)
    }
}
