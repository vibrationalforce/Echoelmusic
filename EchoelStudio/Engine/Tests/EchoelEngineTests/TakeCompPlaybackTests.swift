import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelEngine

/// Recovery 4: a comp of audio takes, played by the same `EngineCore` the app plays — the chosen
/// take over each stretch, a crossfade at each cut that does not click, and the export holding
/// exactly what plays live at any block size.
final class TakeCompPlaybackTests: XCTestCase {
    private let rate = 48_000.0

    private struct Song {
        var project: Project
        var track: TrackID
        var group: TakeGroupID
        var a: RegionID
        var b: RegionID
        var samples: [MediaID: SampleBuffer]
    }

    /// Two one-bar takes (two seconds at 120 BPM) over each other, folded as recording folds them.
    private func song(_ first: SampleBuffer, _ second: SampleBuffer) throws -> Song {
        var project = Project(tempo: 120)
        let track = TrackID(), a = RegionID(), b = RegionID(), group = TakeGroupID()
        let one = MediaFile(name: "Take 1", path: "Media/one.wav", frameCount: first.frameCount, sampleRate: rate)
        let two = MediaFile(name: "Take 2", path: "Media/two.wav", frameCount: second.frameCount, sampleRate: rate)
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(one).apply(to: &project)
        try Command.addMedia(two).apply(to: &project)
        try Command.placeAudio(track: track, id: a, media: one.id, start: 0).apply(to: &project)
        try Command.placeAudio(track: track, id: b, media: two.id, start: 0).apply(to: &project)
        try Command.foldTake(track: track, take: b.rawValue, group: group).apply(to: &project)
        return Song(project: project, track: track, group: group, a: a, b: b, samples: [one.id: first, two.id: second])
    }

    private func constant(_ value: Float) throws -> SampleBuffer {
        try XCTUnwrap(SampleBuffer(samples: [Float](repeating: value, count: 96_000), sampleRate: rate))
    }

    private func sine(_ hertz: Double) throws -> SampleBuffer {
        let samples = (0..<96_000).map { (i: Int) -> Float in Float(0.4 * sin(2 * Double.pi * hertz * Double(i) / 48_000)) }
        return try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate))
    }

    private func live(_ s: Song, frames: Int, block: Int) -> [Float] {
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
        return left
    }

    func testEachStretchPlaysTheTakeTheCompChooses() throws {
        var s = try song(try constant(0.5), try constant(-0.25))
        try Command.compTake(track: s.track, group: s.group, take: s.a.rawValue, start: 0, end: 1_920).apply(to: &s.project)
        let out = live(s, frames: 96_000, block: 256)
        let centre = Float(0.5).squareRoot()
        XCTAssertEqual(out[10_000], 0.5 * centre, accuracy: 1e-5, "take 1 over the first half")
        XCTAssertEqual(out[80_000], -0.25 * centre, accuracy: 1e-5, "take 2 over the second, alone")
    }

    /// Two takes of opposite sign: a hard cut would jump by the whole difference in one sample.
    /// The crossfade moves across 500 frames instead, and never further than a smooth curve does.
    func testACutBetweenTwoTakesDoesNotClick() throws {
        var s = try song(try constant(0.5), try constant(-0.5))
        try Command.compTake(track: s.track, group: s.group, take: s.a.rawValue, start: 0, end: 1_920).apply(to: &s.project)
        let out = live(s, frames: 96_000, block: 256)
        var largest: Float = 0
        for i in 1..<out.count { largest = Swift.max(largest, abs(out[i] - out[i - 1])) }
        XCTAssertLessThan(largest, 0.01, "no step anywhere — a hard cut would be \(Float(0.5).squareRoot())")
        XCTAssertLessThan(out[48_000 - 100], 0.5 * Float(0.5).squareRoot() - 0.001, "already moving before the cut")
    }

    func testLiveAndExportAreBitIdenticalAtEveryBlockSize() throws {
        var s = try song(try sine(220), try sine(330))
        try Command.compTake(track: s.track, group: s.group, take: s.a.rawValue, start: 960, end: 1_500).apply(to: &s.project)
        try Command.compTake(track: s.track, group: s.group, take: s.a.rawValue, start: 2_880, end: 3_840).apply(to: &s.project)
        let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: s.samples,
                                          frameCount: 96_000)
        XCTAssertGreaterThan(export.left.map(abs).max() ?? 0, 0.1, "the comp sounds")
        for block in [64, 256, 4_096] {
            let played = live(s, frames: 96_000, block: block)
            XCTAssertEqual(played, export.left, "block \(block): live is the export, sample for sample")
        }
    }

    func testAPlainSongPlaysAsBefore() throws {
        var s = try song(try sine(220), try sine(330))
        let before = live(s, frames: 96_000, block: 256)
        try Command.removeTakeGroup(track: s.track, s.group).apply(to: &s.project)
        let unfolded = live(s, frames: 96_000, block: 256)
        XCTAssertNotEqual(before, unfolded, "unfolded, both takes sound together")
        var plain = s.project
        plain.tracks[0].regions.removeAll { $0.id == s.a }
        s.project = plain
        XCTAssertEqual(live(s, frames: 96_000, block: 256), before,
                       "the folder's newest take over its whole span is that take played alone")
    }
}
