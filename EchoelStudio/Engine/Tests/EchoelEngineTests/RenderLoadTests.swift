import XCTest
@testable import EchoelEngine

final class RenderLoadTests: XCTestCase {
    private let rate = 48_000.0

    /// A 256-frame callback at 48 kHz has 5.33 ms; each share is counted against that.
    func testEachCallbackIsMeasuredAgainstTheTimeItsFramesAllow() {
        let load = RenderLoad()
        let budget = 256 / rate
        load.record(seconds: budget * 0.2, frames: 256, sampleRate: rate, sampleTime: 0)
        load.record(seconds: budget * 0.6, frames: 256, sampleRate: rate, sampleTime: 256)
        load.record(seconds: budget * 0.8, frames: 256, sampleRate: rate, sampleTime: 512)
        load.record(seconds: budget * 1.3, frames: 256, sampleRate: rate, sampleTime: 768)
        let reading = load.take()
        XCTAssertEqual(reading.callbacks, 4)
        XCTAssertEqual(reading.overHalf, 3)
        XCTAssertEqual(reading.overThreeQuarters, 2)
        XCTAssertEqual(reading.overBudget, 1)
        XCTAssertEqual(reading.peak, 1.3, accuracy: 0.002)
        XCTAssertEqual(reading.discontinuities, 0, "the sample time ran on whole")
        XCTAssertTrue(reading.isTroubled)
        XCTAssertEqual(load.take(), RenderLoad.Reading(), "a reading starts the next window")
    }

    func testAGapOrARepeatInTheSampleTimeIsCounted() {
        let load = RenderLoad()
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 0)
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 256)
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 1_024)   // 512 samples lost
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 1_024)   // the same block again
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: nil)     // no time reported
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 9_000)   // starts afresh, no gap
        let reading = load.take()
        XCTAssertEqual(reading.discontinuities, 2)
        XCTAssertTrue(reading.isTroubled)
    }

    /// A rebuilt graph's sample time starts again from its own origin: no jump is counted there.
    func testARestartedGraphIsNoGap() {
        let load = RenderLoad()
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 50_000)
        load.restart()
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 0)
        load.record(seconds: 0, frames: 256, sampleRate: rate, sampleTime: 256)
        XCTAssertEqual(load.take().discontinuities, 0)
    }

    func testNonsenseCountsNothing() {
        let load = RenderLoad()
        load.record(seconds: .nan, frames: 256, sampleRate: rate, sampleTime: 0)
        load.record(seconds: 0.001, frames: 0, sampleRate: rate, sampleTime: 0)
        load.record(seconds: 0.001, frames: 256, sampleRate: 0, sampleTime: 0)
        load.record(seconds: -1, frames: 256, sampleRate: rate, sampleTime: 0)
        XCTAssertEqual(load.take(), RenderLoad.Reading())
        XCTAssertFalse(RenderLoad.Reading().isTroubled)
    }

    /// A callback whose output is exactly zero while the transport plays counts once; one that
    /// carries a single quiet sample anywhere does not, and stopped nothing counts.
    func testASilentCallbackWhilePlayingIsCounted() {
        let load = RenderLoad()
        let frames = 256
        let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let channels = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: 2)
        defer {
            left.deallocate()
            right.deallocate()
            channels.deallocate()
        }
        channels[0] = left
        channels[1] = right
        left.update(repeating: 0, count: frames)
        right.update(repeating: 0, count: frames)
        load.recordOutput(channels, count: 2, frames: frames, playing: true)     // silent
        load.recordOutput(channels, count: 2, frames: frames, playing: false)    // stopped: meant to be
        right[frames - 1] = 1e-7
        load.recordOutput(channels, count: 2, frames: frames, playing: true)     // one sample sounds
        right[frames - 1] = -0.0
        load.recordOutput(channels, count: 2, frames: frames, playing: true)     // minus zero is zero
        load.recordOutput(channels, count: 0, frames: frames, playing: true)     // nothing to look at
        load.recordOutput(channels, count: 2, frames: 0, playing: true)
        let reading = load.take()
        XCTAssertEqual(reading.silent, 2)
        XCTAssertFalse(reading.isTroubled, "an empty bar is silent on purpose")
        XCTAssertEqual(load.take().silent, 0, "a reading starts the next window")
    }

    /// The silence count asks the transport, which `play`, `pause` and `stop` set.
    func testTheTransportSaysWhetherItPlays() {
        let core = EngineCore(sampleRate: rate)
        XCTAssertFalse(core.transportPlays)
        core.play()
        XCTAssertTrue(core.transportPlays)
        core.pause()
        XCTAssertFalse(core.transportPlays)
        core.play()
        core.stop()
        XCTAssertFalse(core.transportPlays)
    }
}
