import EchoelCore
import EchoelDSP
import EchoelKernels
import XCTest
@testable import EchoelEngine

/// A gain on both channels, in pure Swift.
private final class Gain: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    private let factor: Float

    init(_ factor: Float, sampleRate: Double) {
        self.factor = factor
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        for i in 0..<frames {
            left[i] *= factor
            right[i] *= factor
        }
    }
}

final class RegionBakeTests: XCTestCase {
    private let rate = 48_000.0
    private let file: [Float] = (0..<6_000).map { (index: Int) -> Float in
        Float(0.5 * sin(2 * Double.pi * 330 * Double(index) / 48_000))
    }

    /// A song with the region to bake (one bar in, the file from frame 100 for 2 000 frames) on a
    /// track turned down and panned hard left, plus a second audio track that plays alongside.
    private func song() throws -> (Project, TrackID, RegionID, [MediaID: SampleBuffer]) {
        var project = Project(tempo: 120)
        let track = TrackID(), other = TrackID(), region = RegionID()
        let media = MediaFile(name: "Voice", path: "Media/voice.wav", frameCount: file.count, sampleRate: rate)
        try Command.addTrack(id: track, name: "Voice", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: other, name: "Other", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        let bar = MusicalTime.ticksPerBar(.common)
        try Command.placeAudio(track: track, id: region, media: media.id, start: bar).apply(to: &project)
        try Command.trimRegion(track: track, region, offset: 100, length: 2_000).apply(to: &project)
        try Command.placeAudio(track: other, id: RegionID(), media: media.id, start: bar).apply(to: &project)
        guard let index = project.tracks.firstIndex(where: { $0.id == track }) else { throw CommandError.unknownTrack(track) }
        project.tracks[index].mixer.volumeDB = -12
        project.tracks[index].mixer.pan = -1
        let buffer = try XCTUnwrap(SampleBuffer(samples: file, sampleRate: rate))
        return (project, track, region, [media.id: buffer])
    }

    func testWithoutEffectsTheBakeIsTheRegionItselfWithoutFaderPanOrOtherTracks() throws {
        let (project, track, region, samples) = try song()
        let frames = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                     samples: samples, effects: []))
        XCTAssertGreaterThanOrEqual(frames.count, 2_000)
        XCTAssertLessThan(frames.dropFirst(2_000).map { abs($0) }.max() ?? 0, 1e-6, "nothing after the region")
        // The engine fades a region's first and last 64 frames, in playback and in the bake alike.
        for i in stride(from: 64, to: 2_000 - 64, by: 97) {
            XCTAssertEqual(frames[i], file[100 + i], accuracy: 1e-4, "frame \(i)")
        }
    }

    func testTheInsertsAreBakedInAndTwoBakesAgree() throws {
        let (project, track, region, samples) = try song()
        let first = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                    samples: samples, effects: [Gain(0.5, sampleRate: rate)]))
        let second = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                     samples: samples, effects: [Gain(0.5, sampleRate: rate)]))
        XCTAssertEqual(first, second, "a bake is deterministic")
        for i in stride(from: 64, to: 2_000 - 64, by: 101) {
            XCTAssertEqual(first[i], file[100 + i] * 0.5, accuracy: 1e-4, "frame \(i)")
        }
    }

    func testTheCutSongHoldsOnlyTheRegionOnAPlainTrack() throws {
        let (project, track, region, _) = try song()
        let cut = try XCTUnwrap(RegionBake.project(project, track: track, region: region))
        XCTAssertEqual(cut.tracks.map(\.id), [track])
        XCTAssertEqual(cut.tracks.first?.regions.map(\.id), [region])
        XCTAssertEqual(cut.tracks.first?.mixer, MixerStrip())
        XCTAssertTrue(cut.modRoutes.isEmpty, "the body never reaches a bake")
        XCTAssertNil(RegionBake.project(project, track: track, region: RegionID()))
        XCTAssertNil(RegionBake.project(project, track: TrackID(), region: region))
    }
}
