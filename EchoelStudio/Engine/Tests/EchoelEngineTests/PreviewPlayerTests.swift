import EchoelCore
import EchoelDSP
import EchoelEngine
import XCTest

final class PreviewPlayerTests: XCTestCase {
    private let rate = 48_000.0

    private func constant(_ frames: Int, value: Float = 1, rate: Double = 48_000) throws -> SampleBuffer {
        try XCTUnwrap(SampleBuffer(samples: [Float](repeating: value, count: frames), sampleRate: rate))
    }

    /// Renders `frames` in blocks of `block` and returns the left side.
    private func render(_ player: PreviewPlayer, frames: Int, block: Int = 256) -> [Float] {
        var out: [Float] = []
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var done = 0
        while done < frames {
            let n = Swift.min(block, frames - done)
            for i in 0..<block {
                left[i] = 0
                right[i] = 0
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    if let lb = l.baseAddress, let rb = r.baseAddress {
                        player.render(left: lb, right: rb, frames: n, outputRate: rate)
                    }
                }
            }
            out.append(contentsOf: left[0..<n])
            done += n
        }
        return out
    }

    func testAFileIsHeardOnceAtTheBrowserLevelAndThenEnds() throws {
        let player = PreviewPlayer()
        let take = player.play(try constant(4_800))
        XCTAssertTrue(player.isPlaying(take))
        let out = render(player, frames: 9_600)
        XCTAssertEqual(out[2_400], PreviewPlayer.level, accuracy: 1e-5, "the middle plays at the browser's level")
        XCTAssertLessThan(abs(out[0]), 0.01, "the start ramps from silence")
        XCTAssertEqual(out[6_000], 0, "after its end nothing sounds")
        XCTAssertFalse(player.isPlaying(take))
        XCTAssertEqual(player.heldTakes, 0, "a take that ended is let go")
    }

    func testStopFadesOutInsteadOfCutting() throws {
        let player = PreviewPlayer()
        let take = player.play(try constant(48_000))
        let before = render(player, frames: 1_024)
        XCTAssertEqual(before[1_000], PreviewPlayer.level, accuracy: 1e-5)
        player.stop()
        XCTAssertFalse(player.isPlaying(take), "a stopped take no longer counts as playing")
        let after = render(player, frames: 1_024)
        XCTAssertGreaterThan(after[0], 0, "the stop ramps down, it does not jump to silence")
        let fadeFrames = Int(PreviewPlayer.fadeSeconds * rate)
        XCTAssertEqual(after[fadeFrames + 8], 0, "and is silent after the ramp")
        for i in 1..<fadeFrames { XCTAssertLessThanOrEqual(after[i], after[i - 1] + 1e-6) }
        XCTAssertEqual(player.heldTakes, 0)
    }

    func testANewFileReplacesTheOneThatPlays() throws {
        let player = PreviewPlayer()
        let first = player.play(try constant(48_000, value: 1))
        _ = render(player, frames: 512)
        let second = player.play(try constant(48_000, value: -1))
        XCTAssertFalse(player.isPlaying(first))
        XCTAssertTrue(player.isPlaying(second))
        let out = render(player, frames: 2_048)
        XCTAssertEqual(out[2_000], -PreviewPlayer.level, accuracy: 1e-5, "only the new file sounds")
        XCTAssertEqual(player.heldTakes, 1, "the replaced take is let go, the one that plays is kept")
    }

    func testATakeNeverStartedIsDroppedWhenAnotherComes() throws {
        let player = PreviewPlayer()
        player.play(try constant(100))
        player.play(try constant(100))
        let third = player.play(try constant(100))
        XCTAssertEqual(player.heldTakes, 1, "only the newest pending take is kept")
        _ = render(player, frames: 512)
        XCTAssertFalse(player.isPlaying(third))
        XCTAssertEqual(player.heldTakes, 0)
    }

    func testAFileAtAnotherRatePlaysAtItsOwnSpeed() throws {
        let player = PreviewPlayer()
        // 24 000 frames at 24 kHz are one second: 48 000 output frames.
        player.play(try constant(24_000, rate: 24_000))
        let out = render(player, frames: 50_000)
        XCTAssertEqual(out[47_000], PreviewPlayer.level, accuracy: 1e-5)
        XCTAssertEqual(out[48_500], 0)
    }

    func testNothingPlaysWithoutATakeOrAtAnUnusableRate() throws {
        let player = PreviewPlayer()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(render(player, frames: 256).max(), 0)
        player.play(try constant(4_800))
        var left = [Float](repeating: 0, count: 64)
        var right = [Float](repeating: 0, count: 64)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                if let lb = l.baseAddress, let rb = r.baseAddress {
                    player.render(left: lb, right: rb, frames: 64, outputRate: .nan)
                }
            }
        }
        XCTAssertEqual(left.max(), 0, "a rate that is not a number adds nothing")
    }

    func testTheListeningLevelIsItsOwnAndClamped() throws {
        let player = PreviewPlayer()
        XCTAssertEqual(player.gain, PreviewPlayer.level)
        player.setLevel(decibels: -20)
        XCTAssertEqual(player.gain, 0.1, accuracy: 1e-5)
        player.play(try constant(4_800))
        let out = render(player, frames: 4_096)
        XCTAssertEqual(out[2_400], 0.1, accuracy: 1e-5, "the file plays at the listening level")
        player.setLevel(decibels: 12)
        XCTAssertEqual(player.gain, 1, accuracy: 1e-6, "never above unity")
        player.setLevel(decibels: -200)
        XCTAssertEqual(player.gain, Float(pow(10, -40.0 / 20)), accuracy: 1e-6)
        player.setLevel(decibels: .nan)
        XCTAssertEqual(player.gain, Float(pow(10, -40.0 / 20)), accuracy: 1e-6, "a value that is not a number is ignored")
    }

    func testTheCuePairIsUsedOnlyWhereTheOutputHasIt() {
        XCTAssertEqual(PreviewPlayer.firstChannel(cue: false, channelCount: 8), 0)
        XCTAssertEqual(PreviewPlayer.firstChannel(cue: true, channelCount: 2), 0, "a stereo output keeps the main pair")
        XCTAssertEqual(PreviewPlayer.firstChannel(cue: true, channelCount: 3), 0)
        XCTAssertEqual(PreviewPlayer.firstChannel(cue: true, channelCount: 4), 2, "outputs 3/4")
        let player = PreviewPlayer()
        player.setCueOutput(true)
        XCTAssertTrue(player.sendsToCue)
        XCTAssertEqual(player.firstChannel(channelCount: 6), 2)
    }

    /// The export renders the song alone: a file being listened to, at any level, changes no sample.
    func testListeningDoesNotChangeTheExport() throws {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 3_840).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 960)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        let before = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5)
        let player = PreviewPlayer()
        player.setLevel(decibels: 0)
        player.play(try constant(96_000))
        _ = render(player, frames: 1_024)
        let during = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(during.left, before.left)
        XCTAssertEqual(during.right, before.right)
    }
}
