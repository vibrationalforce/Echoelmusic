import XCTest
@testable import EchoelEngine

/// A Launchpad that no longer gets our clock does not fall back to its own 120 BPM: its flashing
/// and pulsing keep "the last clock if no clock is provided" (Novation programmer's reference for
/// Launchpad X, Mini MK3 and Pro MK3), and a new tempo takes over only once its pulses have
/// reached the device. The light loop keeps the fastest tempo the device may hold from our clock,
/// and the pads animate only while that tempo keeps them at three a second or less.
final class LaunchpadRemembersTheLastClockTests: XCTestCase {
    /// The light loop: one look every 40 ms, or `every` when the main thread is late, with a render
    /// call between two looks unless the engine does not render.
    private struct Loop {
        var kept = Launchpad.KeptClock()
        var now: Duration = .zero
        var renders: UInt64 = 0

        mutating func run(for duration: Duration, every step: Duration = .milliseconds(40), chosen: Bool,
                          playing: Bool, song: Double, rendering: Bool = true) {
            let stop = now + duration
            repeat {
                now += step
                if rendering { renders += 1 }
                kept.look(clockChosen: chosen, transportRuns: playing, renderCount: renders, fastestBPM: song, now: now)
            } while now < stop
        }

        var animates: Bool { Launchpad.animates(keptClockBPM: kept.bpm) }
    }

    func testADeviceOurClockNeverReachedFlashesOnItsOwnTempo() {
        var loop = Loop()
        loop.run(for: .seconds(1), chosen: false, playing: true, song: 999)
        XCTAssertNil(loop.kept.bpm)
        XCTAssertTrue(loop.animates, "never clocked by us: the device flashes at its own 120 BPM")
    }

    func testAFastClockStaysKeptAfterItStops() {
        // Play a 200 BPM song with the clock, stop, open a 120 BPM song without playing it, turn
        // the clock off, press a pad: the device still runs the 200 it heard last.
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        XCTAssertEqual(loop.kept.bpm, 200)
        XCTAssertFalse(loop.animates)
        loop.run(for: .seconds(5), chosen: true, playing: false, song: 120)
        XCTAssertEqual(loop.kept.bpm, 200, "no pulse left while stopped, so nothing lowers it")
        loop.run(for: .seconds(5), chosen: false, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 200)
        XCTAssertFalse(loop.animates, "the device still runs 200 BPM: the pads stay steady")
    }

    func testASlowerClockLowersItOnlyOnceTheDeviceHadTimeToFollow() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        loop.run(for: .seconds(1), chosen: true, playing: false, song: 120)
        // Play: the first slower pulses leave, but the device still runs the 200 it kept.
        loop.run(for: .milliseconds(40), chosen: true, playing: true, song: 120)
        XCTAssertFalse(loop.animates, "a pad launched now must not flash on the device's 200 BPM")
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 200, "two seconds of the slower clock are not yet enough")
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 120)
        XCTAssertTrue(loop.animates)
        loop.run(for: .seconds(1), chosen: false, playing: true, song: 200)
        XCTAssertTrue(loop.animates, "the song's tempo does not reach a device the clock is not sent to")
    }

    func testABreakInTheSlowerClockStartsTheWaitAgain() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        loop.run(for: .milliseconds(40), chosen: true, playing: false, song: 120)
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 200, "two seconds, a stop, two seconds: never three without a break")
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 120)
    }

    func testALateLookStartsTheWaitAgain() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        // The main thread stalls for half a second: a break in the pulses could hide in it.
        loop.run(for: .milliseconds(500), every: .milliseconds(500), chosen: true, playing: true, song: 120)
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 200, "the wait started again after the late look")
        loop.run(for: .seconds(2), chosen: true, playing: true, song: 120)
        XCTAssertEqual(loop.kept.bpm, 120)
    }

    func testAFollowedClockThatMovesByAHundredthStillLowersIt() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        for step in 0..<10 {
            let tempo: Double = step % 2 == 0 ? 120.01 : 120
            loop.run(for: .milliseconds(500), chosen: true, playing: true, song: tempo)
        }
        XCTAssertEqual(loop.kept.bpm, 120.01, "the bound falls to the faster of the two")
        XCTAssertTrue(loop.animates)
    }

    func testAnEngineThatDoesNotRenderSendsNoPulse() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 200)
        loop.run(for: .seconds(10), chosen: true, playing: true, song: 120, rendering: false)
        XCTAssertEqual(loop.kept.bpm, 200, "the transport says it plays, but nothing renders")
    }

    func testAChosenClockCoversTheSongBeforeItRuns() {
        // Play brings the song's tempo, and a start and stop between two looks would go unseen.
        var fast = Loop()
        fast.run(for: .seconds(1), chosen: true, playing: false, song: 200)
        XCTAssertEqual(fast.kept.bpm, 200)
        XCTAssertFalse(fast.animates)
        var slow = Loop()
        slow.run(for: .seconds(1), chosen: true, playing: false, song: 120)
        XCTAssertTrue(slow.animates)
    }

    func testAnUnknownTempoCountsAsTooFast() {
        var loop = Loop()
        loop.run(for: .seconds(5), chosen: true, playing: true, song: .nan)
        XCTAssertFalse(loop.animates)
        loop.run(for: .seconds(1), chosen: false, playing: true, song: 120)
        XCTAssertFalse(loop.animates, "an unknown tempo stays kept after the clock is turned off")
        loop.run(for: .seconds(5), chosen: true, playing: true, song: 120)
        XCTAssertTrue(loop.animates, "a known, slower clock that ran long enough brings it back")
        XCTAssertFalse(Launchpad.animates(keptClockBPM: Launchpad.KeptClock(bpm: .nan).bpm))
    }
}
