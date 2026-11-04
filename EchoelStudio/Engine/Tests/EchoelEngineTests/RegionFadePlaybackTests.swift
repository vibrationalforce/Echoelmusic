import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

/// AUD-2: a region's fades and level, played sample-accurately by the same `EngineCore` the app
/// plays, exported as it plays, and without a click.
final class RegionFadePlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let centre = Float(0.5).squareRoot()

    private struct Song {
        var project: Project
        var track: TrackID
        var region: RegionID
        var samples: [MediaID: SampleBuffer]
    }

    /// One region of `buffer` at the song's start, 120 BPM.
    private func song(_ buffer: SampleBuffer) throws -> Song {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: buffer.frameCount, sampleRate: rate)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id, start: 0).apply(to: &project)
        return Song(project: project, track: track, region: region, samples: [media.id: buffer])
    }

    private func constant(_ value: Float, frames: Int, stereo: Bool = false) throws -> SampleBuffer {
        let side = [Float](repeating: value, count: frames)
        if stereo { return try XCTUnwrap(SampleBuffer(left: side, right: side.map { -$0 * 0.5 }, sampleRate: rate)) }
        return try XCTUnwrap(SampleBuffer(samples: side, sampleRate: rate))
    }

    private func sine(seconds: Double, stereo: Bool) throws -> SampleBuffer {
        let count = Int(seconds * rate)
        let left = (0..<count).map { (i: Int) -> Float in Float(0.5 * sin(2 * Double.pi * 220 * Double(i) / 48_000)) }
        guard stereo else { return try XCTUnwrap(SampleBuffer(samples: left, sampleRate: rate)) }
        let right = (0..<count).map { (i: Int) -> Float in Float(0.5 * sin(2 * Double.pi * 330 * Double(i) / 48_000)) }
        return try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: rate))
    }

    private func live(_ s: Song, frames: Int, block: Int = 256) -> (left: [Float], right: [Float]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: s.project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: s.project), project: s.project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, samples: s.samples))
        core.play()
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return (left, right)
    }

    private func set(_ s: inout Song, fadeIn: Int, fadeOut: Int, curves: (FadeCurve, FadeCurve) = (.linear, .linear),
                     gainDB: Double = 0) throws {
        try Command.setRegionFades(track: s.track, s.region, fadeIn: fadeIn, fadeOut: fadeOut,
                                   fadeInCurve: curves.0, fadeOutCurve: curves.1).apply(to: &s.project)
        try Command.setRegionGain(track: s.track, s.region, gainDB: gainDB).apply(to: &s.project)
    }

    func testAFadeInRisesAndAFadeOutFallsOnTheirOwnSamples() throws {
        var s = try song(try constant(0.5, frames: 48_000))
        try set(&s, fadeIn: 4_800, fadeOut: 9_600)
        let out = live(s, frames: 50_000).left
        let full = 0.5 * centre
        XCTAssertEqual(out[0], 0, accuracy: 1e-7)
        XCTAssertEqual(out[2_400], full * 0.5, accuracy: 1e-4, "halfway into the fade-in")
        XCTAssertEqual(out[4_800], full, accuracy: 1e-4)
        XCTAssertEqual(out[30_000], full, accuracy: 1e-4)
        XCTAssertEqual(out[48_000 - 4_800], full * 0.5, accuracy: 1e-4, "halfway into the fade-out")
        XCTAssertLessThan(abs(out[47_999]), full * 0.001)
        XCTAssertTrue(out[48_000...].allSatisfy { $0 == 0 })
    }

    func testEveryCurvePlaysAsTheSongDefinesIt() throws {
        for curve in FadeCurve.allCases {
            XCTAssertEqual(EngineSnapshot.shape(curve).level(0.3), curve.level(0.3), accuracy: 1e-12, "\(curve)")
            var s = try song(try constant(0.5, frames: 48_000))
            try set(&s, fadeIn: 9_600, fadeOut: 0, curves: (curve, .linear))
            let out = live(s, frames: 9_600).left
            XCTAssertEqual(out[2_400], Float(curve.level(0.25)) * 0.5 * centre, accuracy: 1e-4, "\(curve)")
        }
    }

    func testGainScalesBothSidesOfAStereoRegion() throws {
        var s = try song(try constant(0.5, frames: 24_000, stereo: true))
        try set(&s, fadeIn: 0, fadeOut: 0, gainDB: -6)
        let out = live(s, frames: 24_000)
        let g = Float(pow(10, -6.0 / 20))
        XCTAssertEqual(out.left[12_000], 0.5 * centre * g, accuracy: 1e-4)
        XCTAssertEqual(out.right[12_000], -0.25 * centre * g, accuracy: 1e-4)
        var faded = s
        try set(&faded, fadeIn: 2_000, fadeOut: 0, gainDB: -6)
        let rise = live(faded, frames: 2_000)
        XCTAssertEqual(rise.left[1_000], 0.5 * centre * g * 0.5, accuracy: 1e-4)
        XCTAssertEqual(rise.right[1_000], -0.25 * centre * g * 0.5, accuracy: 1e-4)
    }

    func testAPlainRegionPlaysExactlyAsBefore() throws {
        let s = try song(try sine(seconds: 0.5, stereo: true))
        var touched = s
        try set(&touched, fadeIn: 0, fadeOut: 0)
        XCTAssertEqual(touched.project, s.project, "no fade, 0 dB stores nothing")
        let a = live(s, frames: 26_000), b = live(touched, frames: 26_000)
        XCTAssertEqual(a.left, b.left)
        XCTAssertEqual(a.right, b.right)
    }

    func testTheExportIsWhatPlaysLive() throws {
        for stereo in [false, true] {
            var s = try song(try sine(seconds: 1, stereo: stereo))
            try set(&s, fadeIn: 12_000, fadeOut: 7_000, curves: (.sCurve, .equalPower), gainDB: 4)
            let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: s.samples)
            XCTAssertEqual(export.frameCount, 48_000)
            let played = live(s, frames: export.frameCount, block: 333)
            for i in stride(from: 0, to: export.frameCount, by: 1) {
                guard abs(export.left[i] - played.left[i]) <= 1e-6, abs(export.right[i] - played.right[i]) <= 1e-6 else {
                    XCTFail("stereo \(stereo): sample \(i) differs: \(export.left[i]) vs \(played.left[i])")
                    break
                }
            }
        }
    }

    func testFadesAndGainDoNotClick() throws {
        let smooth = ClickDetector.forSine(hertz: 330, amplitude: 0.5 * Float(pow(10, 6.0 / 20)))
        for stereo in [false, true] {
            for curve in FadeCurve.allCases {
                for (rise, fall) in [(0, 0), (1, 1), (40, 70), (4_800, 9_600)] {
                    var s = try song(try sine(seconds: 0.5, stereo: stereo))
                    try set(&s, fadeIn: rise, fadeOut: fall, curves: (curve, curve), gainDB: 6)
                    var out = live(s, frames: 30_000)
                    // Silence before, so the region's start is measured too.
                    out.left.insert(contentsOf: [Float](repeating: 0, count: 2_048), at: 0)
                    out.right.insert(contentsOf: [Float](repeating: 0, count: 2_048), at: 0)
                    let left = smooth.clicks(in: out.left), right = smooth.clicks(in: out.right)
                    XCTAssertEqual(left, [], "\(curve) \(rise)/\(fall) stereo \(stereo) left: \(left.prefix(3))")
                    XCTAssertEqual(right, [], "\(curve) \(rise)/\(fall) stereo \(stereo) right: \(right.prefix(3))")
                }
            }
        }
    }
}
