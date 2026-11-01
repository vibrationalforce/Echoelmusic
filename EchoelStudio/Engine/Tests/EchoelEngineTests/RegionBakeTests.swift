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

/// Different gains on the two sides: a wide effect, in pure Swift.
private final class Spread: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        for i in 0..<frames {
            left[i] *= 0.8
            right[i] *= -0.3
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
        let baked = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                    samples: samples, effects: []))
        XCTAssertEqual(baked.channelCount, 1, "a mono file bakes mono")
        let frames = baked.left
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
        XCTAssertEqual(first.channelCount, 1, "an effect that treats both sides alike keeps a mono bake mono")
        for i in stride(from: 64, to: 2_000 - 64, by: 101) {
            XCTAssertEqual(first.left[i], file[100 + i] * 0.5, accuracy: 1e-4, "frame \(i)")
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

    // MARK: - Stereo (W17)

    private let long = 60_000

    /// One audio track at −6 dB, panned 0.3, holding one region of a `long`-frame file a bar in.
    private func wideSong(left: [Float], right: [Float]) throws -> (Project, TrackID, RegionID, MediaFile, [MediaID: SampleBuffer]) {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Pad", path: "Media/pad.wav", frameCount: left.count, sampleRate: rate)
        try Command.addTrack(id: track, name: "Pad", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id,
                               start: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        try Command.setVolume(.track(track), db: -6).apply(to: &project)
        try Command.setPan(.track(track), pan: 0.3).apply(to: &project)
        let buffer = try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: rate))
        return (project, track, region, media, [media.id: buffer])
    }

    private func sine(_ hertz: Double, _ level: Double) -> [Float] {
        (0..<long).map { (index: Int) -> Float in Float(level * sin(2 * Double.pi * hertz * Double(index) / 48_000)) }
    }

    /// The song with the bake swapped in the way the app does it: the baked file on a new track at
    /// the original's fader and pan, without inserts, and the original region gone.
    private func swapped(_ project: Project, track: TrackID, region: RegionID, baked: RegionBake.Baked,
                         samples: [MediaID: SampleBuffer]) throws -> (Project, [MediaID: SampleBuffer]) {
        var song = project
        let original = try XCTUnwrap(project.track(track))
        let start = try XCTUnwrap(original.regions.first { $0.id == region }?.start)
        let media = MediaFile(name: "Pad (baked)", path: "Media/baked.wav", frameCount: baked.frameCount, sampleRate: rate)
        let bakedTrack = TrackID()
        try Command.addTrack(id: bakedTrack, name: "Pad Baked", kind: .audio, index: nil).apply(to: &song)
        try Command.setVolume(.track(bakedTrack), db: original.mixer.volumeDB).apply(to: &song)
        try Command.setPan(.track(bakedTrack), pan: original.mixer.pan).apply(to: &song)
        try Command.addMedia(media).apply(to: &song)
        try Command.placeAudio(track: bakedTrack, id: RegionID(), media: media.id, start: start).apply(to: &song)
        try Command.removeRegion(track: track, region).apply(to: &song)
        let buffer = try XCTUnwrap(SampleBuffer(left: baked.left, right: baked.right ?? baked.left, sampleRate: rate))
        var all = samples
        all[media.id] = buffer
        return (song, all)
    }

    private func loudness(_ result: OfflineRender.Result) -> Double {
        var meter = LoudnessMeter(sampleRate: result.sampleRate)
        result.left.withUnsafeBufferPointer { l in
            result.right.withUnsafeBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                meter.process(left: lp, right: rp, count: Swift.min(l.count, r.count))
            }
        }
        return meter.integratedLoudness
    }

    /// A wide effect bakes both sides, and the baked region plays as the original did through its
    /// inserts: the two mixes null, side by side, outside the region's edge fades, at the same
    /// loudness.
    func testAWideEffectBakesBothSidesAndTheBakedRegionPlaysAsTheOriginalDid() throws {
        let sound = sine(330, 0.5)
        let (project, track, region, _, samples) = try wideSong(left: sound, right: sound)
        XCTAssertEqual(samples.values.first?.channelCount, 1, "the source is mono")
        let baked = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                    samples: samples, effects: [Spread(sampleRate: rate)]))
        XCTAssertEqual(baked.channelCount, 2, "the effect made it wide, and the bake keeps it wide")
        XCTAssertEqual(baked.frameCount, long)

        let before = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: samples,
                                          effects: [track: [Spread(sampleRate: rate)]])
        let (song, all) = try swapped(project, track: track, region: region, baked: baked, samples: samples)
        let after = OfflineRender.render(song, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: all)
        XCTAssertEqual(after.frameCount, before.frameCount)
        let start = 2 * 48_000   // a bar of 4/4 at 120 BPM
        var apart: Float = 0
        for i in (start + 64)..<(start + long - 64) {
            apart = Swift.max(apart, abs(after.left[i] - before.left[i]), abs(after.right[i] - before.right[i]))
        }
        XCTAssertLessThan(apart, 1e-5, "the baked region nulls against the original, side by side")
        XCTAssertGreaterThan(before.right.map { abs($0) }.max() ?? 0, 0.05, "the right side carries sound")
        XCTAssertEqual(loudness(after), loudness(before), accuracy: 0.01, "the loudness stays")
    }

    /// A stereo file bakes both sides as they are, the centre pan's gain taken back out of each.
    func testAStereoFileBakesBothSidesAsTheyAre() throws {
        let (project, track, region, _, samples) = try wideSong(left: sine(330, 0.5), right: sine(550, 0.25))
        let baked = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                    samples: samples, effects: []))
        XCTAssertEqual(baked.channelCount, 2)
        let right = try XCTUnwrap(baked.right)
        let left = sine(330, 0.5), expected = sine(550, 0.25)
        for i in stride(from: 64, to: long - 64, by: 97) {
            XCTAssertEqual(baked.left[i], left[i], accuracy: 1e-5, "left \(i)")
            XCTAssertEqual(right[i], expected[i], accuracy: 1e-5, "right \(i)")
        }
    }
}
