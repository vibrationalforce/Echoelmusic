import EchoelCore
import Foundation
import EchoelDSP
import XCTest
@testable import EchoelEngine

/// AUD-2 warp: a region follows the song's tempo with its pitch, stretched off the render thread,
/// exported as it plays, without a click.
final class RegionWarpPlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let centre = Float(0.5).squareRoot()

    private struct Song {
        var project: Project
        var track: TrackID
        var region: RegionID
        var samples: [MediaID: SampleBuffer]
    }

    private func sine(hertz: Double, seconds: Double, stereo: Bool = false) throws -> SampleBuffer {
        let count = Int(seconds * rate)
        let left = (0..<count).map { (i: Int) -> Float in Float(0.5 * sin(2 * Double.pi * hertz * Double(i) / 48_000)) }
        guard stereo else { return try XCTUnwrap(SampleBuffer(samples: left, sampleRate: rate)) }
        let right = (0..<count).map { (i: Int) -> Float in Float(0.3 * sin(2 * Double.pi * hertz * 1.5 * Double(i) / 48_000)) }
        return try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: rate))
    }

    /// One region of `buffer` at the song's start, warped from `native` BPM.
    private func song(_ buffer: SampleBuffer, tempo: Double, native: Double, changes: [TempoChange] = []) throws -> Song {
        var project = Project(tempo: tempo)
        project.tempoChanges = changes
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: buffer.frameCount, sampleRate: rate)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id, start: 0).apply(to: &project)
        try Command.setRegionWarp(track: track, region, nativeBPM: native, followsTempo: true).apply(to: &project)
        return Song(project: project, track: track, region: region, samples: [media.id: buffer])
    }

    private func live(_ s: Song, frames: Int, warped: [RegionWarp.Key: SampleBuffer], block: Int = 256) -> (left: [Float], right: [Float]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: s.project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: s.project), project: s.project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, samples: s.samples, warped: warped))
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

    /// Cycles per second in `signal[range]`, from its rising zero crossings.
    private func frequency(_ signal: [Float], in range: Range<Int>) -> Double {
        var crossings: [Double] = []
        for i in range.dropFirst() where signal[i - 1] < 0 && signal[i] >= 0 {
            let a = Double(signal[i - 1]), b = Double(signal[i])
            crossings.append(Double(i - 1) + a / (a - b))
        }
        guard let first = crossings.first, let last = crossings.last, crossings.count > 2 else { return 0 }
        return Double(crossings.count - 1) / ((last - first) / rate)
    }

    func testAWarpedRegionFollowsTheTempoAndKeepsItsPitch() throws {
        // One second recorded at 120 BPM is two beats: at 80 BPM it lasts 1.5 s, at 150 BPM 0.8 s.
        for tempo in [80.0, 150] {
            let s = try song(try sine(hertz: 440, seconds: 1), tempo: tempo, native: 120)
            let warped = RegionWarp.prepare(s.project, samples: s.samples)
            XCTAssertEqual(warped.count, 1)
            let expected = Int(2 * 60 / tempo * rate)
            let out = live(s, frames: expected + 4_800, warped: warped).left
            let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
            XCTAssertEqual(Double(sounding), Double(expected), accuracy: 64, "ends on its second beat at \(tempo) BPM")
            XCTAssertTrue(out[(expected + 1)...].allSatisfy { $0 == 0 })
            XCTAssertEqual(frequency(out, in: 4_800..<(expected - 4_800)), 440, accuracy: 2, "pitch unchanged at \(tempo) BPM")
        }
    }

    func testTheStretchIsMadeOffTheRenderThreadAndAMissingOneIsSilent() throws {
        let s = try song(try sine(hertz: 440, seconds: 1), tempo: 90, native: 120)
        let out = live(s, frames: 24_000, warped: [:]).left
        XCTAssertTrue(out.allSatisfy { $0 == 0 }, "never played at the wrong speed while its stretch is made")
        // A moved region at a steady tempo keeps its stretch: the key does not hold its place.
        var moved = s
        try Command.moveRegion(track: s.track, s.region, start: 3_840).apply(to: &moved.project)
        let a = try XCTUnwrap(RegionWarp.pending(in: s.project, samples: s.samples).first?.0)
        let b = try XCTUnwrap(RegionWarp.pending(in: moved.project, samples: moved.samples).first?.0)
        XCTAssertEqual(a, b)
    }

    func testARampedTempoStretchesTheRegionAsItRamps() throws {
        // 120 → 60 BPM over the region's four beats: it ends where the song puts its fourth beat.
        let ramp = [TempoChange(tick: 4 * 960, bpm: 60, curve: .linear)]
        let s = try song(try sine(hertz: 440, seconds: 2), tempo: 120, native: 120, changes: ramp)
        let warped = RegionWarp.prepare(s.project, samples: s.samples)
        let region = try XCTUnwrap(s.project.track(s.track)?.regions.first)
        let stop = try XCTUnwrap(Arranging.end(of: region, in: s.project))
        XCTAssertEqual(stop, 4 * 960)
        let expected = Int((s.project.tempoMap.seconds(at: stop) * rate).rounded())
        let out = live(s, frames: expected + 4_800, warped: warped).left
        let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
        XCTAssertEqual(Double(sounding), Double(expected), accuracy: 64)
        XCTAssertEqual(frequency(out, in: 9_600..<(expected - 9_600)), 440, accuracy: 3, "pitch unchanged through the ramp")
    }

    func testTheExportIsWhatPlaysLive() throws {
        for stereo in [false, true] {
            var s = try song(try sine(hertz: 330, seconds: 1, stereo: stereo), tempo: 100, native: 120)
            try Command.setRegionFades(track: s.track, s.region, fadeIn: 4_800, fadeOut: 4_800,
                                       fadeInCurve: .sCurve, fadeOutCurve: .equalPower).apply(to: &s.project)
            let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: s.samples)
            XCTAssertEqual(export.frameCount, Int(2 * 60 / 100.0 * rate), "the export runs to the warped end")
            XCTAssertEqual(OfflineRender.fixedFrameCount(s.project, sampleRate: rate, tailSeconds: 0, samples: s.samples),
                           Int64(export.frameCount), "known before anything renders")
            let played = live(s, frames: export.frameCount, warped: RegionWarp.prepare(s.project, samples: s.samples), block: 300)
            for i in 0..<export.frameCount {
                guard abs(export.left[i] - played.left[i]) <= 1e-6, abs(export.right[i] - played.right[i]) <= 1e-6 else {
                    XCTFail("stereo \(stereo): sample \(i) differs")
                    break
                }
            }
        }
    }

    func testAWarpedRegionDoesNotClick() throws {
        let smooth = ClickDetector.forSine(hertz: 330 * 1.5, amplitude: 0.5)
        for (tempo, native) in [(96.0, 120.0), (150, 120), (120, 120)] {
            for stereo in [false, true] {
                let s = try song(try sine(hertz: 330, seconds: 1, stereo: stereo), tempo: tempo, native: native)
                var out = live(s, frames: Int(2 * 60 / tempo * rate) + 2_048, warped: RegionWarp.prepare(s.project, samples: s.samples))
                out.left.insert(contentsOf: [Float](repeating: 0, count: 2_048), at: 0)
                out.right.insert(contentsOf: [Float](repeating: 0, count: 2_048), at: 0)
                let left = smooth.clicks(in: out.left), right = smooth.clicks(in: out.right)
                XCTAssertEqual(left, [], "\(tempo)/\(native) stereo \(stereo): \(left.prefix(3))")
                XCTAssertEqual(right, [], "\(tempo)/\(native) stereo \(stereo): \(right.prefix(3))")
            }
        }
    }

    // MARK: - Warp modes (W-3)

    /// `seconds` of silence with a one-sample click of 0.9 on every beat of `bpm`, over an optional
    /// quiet sine.
    private func clickTrain(bpm: Double, seconds: Double, under hertz: Double? = nil) throws -> SampleBuffer {
        let count = Int(seconds * rate)
        var samples = [Float](repeating: 0, count: count)
        if let hertz {
            for i in 0..<count { samples[i] = Float(0.1 * sin(2 * Double.pi * hertz * Double(i) / 48_000)) }
        }
        let beat = Int((60 / bpm * rate).rounded())
        var at = 0
        while at < count {
            samples[at] = 0.9
            at += beat
        }
        return try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate))
    }

    func testBeatsKeepsEveryHitOnItsBeatAndPlaysItOnce() throws {
        // Eight clicks at 120 BPM played at 90: a beat is 0.5 s in the file and 2/3 s in the song.
        var s = try song(try clickTrain(bpm: 120, seconds: 4), tempo: 90, native: 120)
        try Command.setRegionWarpMode(track: s.track, s.region, mode: .beats).apply(to: &s.project)
        let warped = RegionWarp.prepare(s.project, samples: s.samples)
        XCTAssertEqual(warped.count, 1)
        let beat = 60 / 90.0 * rate
        let out = live(s, frames: Int(8 * beat) + 4_800, warped: warped).left
        let peaks = out.indices.filter { abs(out[$0]) > 0.3 }
        XCTAssertEqual(peaks.count, 8, "every click once, none doubled: \(peaks)")
        for (k, peak) in peaks.enumerated() {
            XCTAssertEqual(Double(peak), Double(k) * beat, accuracy: rate / 1_000, "click \(k) within 1 ms of its beat")
        }
        let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
        XCTAssertLessThanOrEqual(Double(sounding), 8 * beat + 64, "ends on its eighth beat")
    }

    func testRePitchChangesTempoAndPitchTogether() throws {
        // 120 to 150 BPM: a quarter faster, so 330 Hz sounds at 412.5 Hz, and one second lasts 0.8 s.
        var s = try song(try sine(hertz: 330, seconds: 1), tempo: 150, native: 120)
        try Command.setRegionWarpMode(track: s.track, s.region, mode: .rePitch).apply(to: &s.project)
        let expected = Int(2 * 60 / 150.0 * rate)
        let out = live(s, frames: expected + 4_800, warped: RegionWarp.prepare(s.project, samples: s.samples)).left
        let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
        XCTAssertEqual(Double(sounding), Double(expected), accuracy: 64, "ends on its second beat")
        XCTAssertEqual(frequency(out, in: 2_400..<(expected - 2_400)), 412.5, accuracy: 1)
    }

    func testEveryWarpModeExportsWhatPlaysLive() throws {
        for mode in WarpMode.allCases {
            var s = try song(try clickTrain(bpm: 120, seconds: 2, under: 220), tempo: 100, native: 120)
            try Command.setRegionWarpMode(track: s.track, s.region, mode: mode).apply(to: &s.project)
            let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: s.samples)
            XCTAssertEqual(export.frameCount, Int(4 * 60 / 100.0 * rate), "\(mode): the export runs to the warped end")
            let played = live(s, frames: export.frameCount, warped: RegionWarp.prepare(s.project, samples: s.samples), block: 300)
            var worst: Float = 0
            for i in 0..<export.frameCount {
                worst = Swift.max(worst, abs(export.left[i] - played.left[i]), abs(export.right[i] - played.right[i]))
            }
            XCTAssertLessThanOrEqual(worst, 1e-6, "\(mode)")
            XCTAssertGreaterThan(export.left.map { abs($0) }.max() ?? 0, 0.3, "\(mode) sounds")
        }
    }

    func testAnUnknownWarpModePlaysExactlyAsTones() throws {
        let s = try song(try clickTrain(bpm: 120, seconds: 2, under: 220), tempo: 90, native: 120)
        var unknown = s
        let index = try XCTUnwrap(unknown.project.trackIndex(s.track))
        let region = unknown.project.tracks[index].regions[0]
        var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(region)) as? [String: Any])
        stored["warpMode"] = "complexPro"
        unknown.project.tracks[index].regions[0] = try JSONDecoder().decode(AudioRegion.self,
                                                                             from: JSONSerialization.data(withJSONObject: stored))
        let a = RegionWarp.prepare(s.project, samples: s.samples)
        let b = RegionWarp.prepare(unknown.project, samples: unknown.samples)
        XCTAssertEqual(Set(a.keys), Set(b.keys), "the same stretch")
        let tones = live(s, frames: 120_000, warped: a).left
        let other = live(unknown, frames: 120_000, warped: b).left
        XCTAssertEqual(tones, other)
    }

    // MARK: - Transpose (W-4)

    /// One region of `buffer` at the song's start, at the file's own speed.
    private func plainSong(_ buffer: SampleBuffer, tempo: Double) throws -> Song {
        var project = Project(tempo: tempo)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: buffer.frameCount, sampleRate: rate)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id, start: 0).apply(to: &project)
        return Song(project: project, track: track, region: region, samples: [media.id: buffer])
    }

    func testAnOctaveUpDoublesThePitchAndKeepsTheLength() throws {
        // At the file's own speed, and warped at the song's own tempo: one second, two beats at 120.
        let unwarped = try plainSong(try sine(hertz: 440, seconds: 1), tempo: 120)
        let warped = try song(try sine(hertz: 440, seconds: 1), tempo: 120, native: 120)
        for var s in [unwarped, warped] {
            try Command.setRegionTranspose(track: s.track, s.region, cents: 1_200).apply(to: &s.project)
            let stretches = RegionWarp.prepare(s.project, samples: s.samples)
            XCTAssertEqual(stretches.count, 1)
            let out = live(s, frames: 48_000 + 4_800, warped: stretches).left
            let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
            XCTAssertEqual(Double(sounding), 48_000, accuracy: 64, "the beat length is unchanged")
            XCTAssertEqual(frequency(out, in: 4_800..<43_200), 880, accuracy: 1)
        }
    }

    func testMinusSevenHundredCentsOnAWarpedRegionKeepsItsEnd() throws {
        var s = try song(try sine(hertz: 440, seconds: 1), tempo: 90, native: 120)
        let before = try XCTUnwrap(Arranging.end(of: try XCTUnwrap(s.project.track(s.track)?.regions.first), in: s.project))
        try Command.setRegionTranspose(track: s.track, s.region, cents: -700).apply(to: &s.project)
        let region = try XCTUnwrap(s.project.track(s.track)?.regions.first)
        XCTAssertEqual(Arranging.end(of: region, in: s.project), before)
        let expected = Int(2 * 60 / 90.0 * rate)
        let out = live(s, frames: expected + 4_800, warped: RegionWarp.prepare(s.project, samples: s.samples)).left
        let sounding = out.lastIndex { abs($0) > 1e-4 } ?? 0
        XCTAssertEqual(Double(sounding), Double(expected), accuracy: 64, "ends on its second beat")
        XCTAssertEqual(frequency(out, in: 4_800..<(expected - 4_800)), 440 * pow(2, -7.0 / 12), accuracy: 1)
    }

    func testATransposedRegionExportsWhatPlaysLiveInEveryMode() throws {
        var songs: [Song] = [try plainSong(try clickTrain(bpm: 120, seconds: 2, under: 220), tempo: 100)]
        for mode in WarpMode.allCases {
            var s = try song(try clickTrain(bpm: 120, seconds: 2, under: 220), tempo: 100, native: 120)
            try Command.setRegionWarpMode(track: s.track, s.region, mode: mode).apply(to: &s.project)
            songs.append(s)
        }
        for (index, element) in songs.enumerated() {
            var s = element
            try Command.setRegionTranspose(track: s.track, s.region, cents: 300).apply(to: &s.project)
            let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: s.samples)
            XCTAssertEqual(OfflineRender.fixedFrameCount(s.project, sampleRate: rate, tailSeconds: 0, samples: s.samples),
                           Int64(export.frameCount), "song \(index): known before anything renders")
            let played = live(s, frames: export.frameCount, warped: RegionWarp.prepare(s.project, samples: s.samples), block: 300)
            var worst: Float = 0
            for i in 0..<export.frameCount {
                worst = Swift.max(worst, abs(export.left[i] - played.left[i]), abs(export.right[i] - played.right[i]))
            }
            XCTAssertLessThanOrEqual(worst, 1e-6, "song \(index)")
            XCTAssertGreaterThan(export.left.map { abs($0) }.max() ?? 0, 0.1, "song \(index) sounds")
        }
    }

    func testATranspositionUpIsHeldToTheSameLimitAsTheRegion() throws {
        // One second: 48,000 frames. An octave up stretches it to twice that before it is read
        // back, so a limit between the two refuses the octave up and still renders the rest.
        var s = try plainSong(try sine(hertz: 440, seconds: 1), tempo: 120)
        let limit = 60_000
        try Command.setRegionTranspose(track: s.track, s.region, cents: 1_200).apply(to: &s.project)
        let up = try XCTUnwrap(s.project.track(s.track)?.regions.first)
        let buffer = try XCTUnwrap(s.samples[up.media])
        XCTAssertNil(RegionWarp.render(up, in: s.project, buffer: buffer, limit: limit), "twice the region passes the limit")
        XCTAssertEqual(RegionWarp.render(up, in: s.project, buffer: buffer)?.frameCount, 48_000)
        try Command.setRegionTranspose(track: s.track, s.region, cents: -1_200).apply(to: &s.project)
        let down = try XCTUnwrap(s.project.track(s.track)?.regions.first)
        XCTAssertEqual(RegionWarp.render(down, in: s.project, buffer: buffer, limit: limit)?.frameCount, 48_000)
    }

    func testACancelledStretchStopsAndMakesNothing() throws {
        var songs: [Song] = [try plainSong(try sine(hertz: 330, seconds: 1), tempo: 100)]
        for mode in WarpMode.allCases {
            var s = try song(try sine(hertz: 330, seconds: 1), tempo: 100, native: 120)
            try Command.setRegionWarpMode(track: s.track, s.region, mode: mode).apply(to: &s.project)
            songs.append(s)
        }
        for (index, element) in songs.enumerated() {
            var s = element
            try Command.setRegionTranspose(track: s.track, s.region, cents: 700).apply(to: &s.project)
            let region = try XCTUnwrap(s.project.track(s.track)?.regions.first)
            let buffer = try XCTUnwrap(s.samples[region.media])
            XCTAssertNil(RegionWarp.render(region, in: s.project, buffer: buffer, isCancelled: { true }), "song \(index)")
            XCTAssertNotNil(RegionWarp.render(region, in: s.project, buffer: buffer, isCancelled: { false }), "song \(index)")
        }
    }

    func testTransposeZeroIsTheSongAsBefore() throws {
        for warp in [false, true] {
            let tone = try sine(hertz: 330, seconds: 1)
            let original: Song
            if warp {
                original = try song(tone, tempo: 100, native: 120)
            } else {
                original = try plainSong(tone, tempo: 100)
            }
            var s = original
            try Command.setRegionTranspose(track: s.track, s.region, cents: 300).apply(to: &s.project)
            try Command.setRegionTranspose(track: s.track, s.region, cents: 0).apply(to: &s.project)
            XCTAssertEqual(s.project, original.project)
            let a = RegionWarp.prepare(original.project, samples: original.samples)
            let b = RegionWarp.prepare(s.project, samples: s.samples)
            XCTAssertEqual(Set(a.keys), Set(b.keys))
            XCTAssertEqual(a.isEmpty, !warp, "a plain region still plays its file as it is")
            XCTAssertEqual(live(original, frames: 60_000, warped: a).left, live(s, frames: 60_000, warped: b).left)
        }
    }
}
