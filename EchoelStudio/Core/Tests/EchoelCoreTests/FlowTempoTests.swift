import XCTest
@testable import EchoelCore

/// The tempo invariant for Flow (W12; the root law's T1–T2): a heart rate never reaches the clock
/// directly, Fixed never reads it at all, and what Flow plays stays inside its bounds and glides.
final class FlowTempoTests: XCTestCase {
    /// Looks `seconds` long, four times a second, at the same pulse, with a bar line every
    /// `barEvery` seconds; returns the tempo after every look.
    private func play(_ flow: inout FlowTempo, seconds: Double, pulse: Double?, barEvery: Double = 2) -> [Double] {
        var played: [Double] = []
        let looks = Int((seconds / 0.25).rounded())
        let looksPerBar = Swift.max(1, Int((barEvery / 0.25).rounded()))
        for look in 1...Swift.max(1, looks) {
            flow.advance(seconds: 0.25, pulse: pulse)
            if look % looksPerBar == 0 { flow.bar() }
            played.append(flow.tempo ?? .nan)
        }
        return played
    }

    func testFixedNeverReadsThePulse() {
        var flow = FlowTempo()
        XCTAssertEqual(flow.lock, .fixed)
        for second in 0..<120 {
            flow.advance(seconds: 1, pulse: Double(50 + second))
            flow.bar()
        }
        XCTAssertNil(flow.tempo, "Fixed plays the song's own tempo")
        XCTAssertNil(flow.target)
        XCTAssertNil(flow.wanted)
        XCTAssertNil(flow.pulse)
        XCTAssertFalse(flow.isFollowing)
        XCTAssertNil(flow.close(), "closing a lock that is closed keeps nothing")
    }

    func testARawPulseNeverReachesTheClock() {
        var flow = FlowTempo()
        flow.open(at: 120)
        XCTAssertEqual(flow.tempo, 120, "Flow starts where the song plays")
        // The first seconds of a pulse are not trusted: the tempo holds.
        XCTAssertEqual(play(&flow, seconds: 4.5, pulse: 90), Array(repeating: 120.0, count: 18))
        XCTAssertNil(flow.wanted)
        // Trusted, it moves towards the pulse, a little per look and never to it at once.
        let moved = play(&flow, seconds: 20, pulse: 90)
        XCTAssertEqual(flow.wanted, 90)
        var previous = 120.0
        for tempo in moved {
            XCTAssertLessThanOrEqual(Swift.abs(tempo - previous),
                                     FlowTempo.stepPerBar / FlowTempo.glideSeconds * 0.25 + 1e-9)
            XCTAssertGreaterThan(tempo, 90, "nowhere near the pulse within twenty seconds")
            previous = tempo
        }
        XCTAssertLessThan(flow.tempo ?? 120, 120)
    }

    func testAnUnsteadyOrMissingPulseHoldsTheTempo() throws {
        var flow = FlowTempo()
        flow.open(at: 100)
        // Readings twenty apart are not steady.
        for second in 0..<30 {
            flow.advance(seconds: 1, pulse: second % 2 == 0 ? 60 : 80)
            flow.bar()
        }
        XCTAssertNil(flow.wanted)
        XCTAssertEqual(flow.tempo, 100)
        // A steady pulse moves it; when the pulse goes, the glide ends where it was going and holds.
        _ = play(&flow, seconds: 20, pulse: 110)
        XCTAssertTrue(flow.isFollowing)
        let target = try XCTUnwrap(flow.target)
        XCTAssertGreaterThan(target, 100)
        let after = play(&flow, seconds: 20, pulse: nil)
        XCTAssertFalse(flow.isFollowing)
        XCTAssertEqual(flow.target, target, "no step without a trusted pulse")
        XCTAssertEqual(after.last ?? 0, target, accuracy: 1e-9)
    }

    func testThePulseFoldsByOctavesIntoRangeNearTheTempoPlaying() {
        XCTAssertEqual(FlowTempo.fold(64, near: 120), 128)
        XCTAssertEqual(FlowTempo.fold(64, near: 70), 64)
        XCTAssertEqual(FlowTempo.fold(190, near: 120), 95)
        XCTAssertEqual(FlowTempo.fold(45, near: 100), 90)
        // Near an octave's edge the octave playing holds: 69 and 71 land in the same one.
        XCTAssertEqual(FlowTempo.fold(69, near: 130), 138)
        XCTAssertEqual(FlowTempo.fold(71, near: 130), 142)
        for tenth in 400...2_000 {
            let pulse = Double(tenth) / 10
            XCTAssertTrue(FlowTempo.range.contains(FlowTempo.fold(pulse, near: 120)), "\(pulse)")
            XCTAssertTrue(FlowTempo.range.contains(FlowTempo.fold(pulse, near: 300)), "\(pulse)")
        }
        XCTAssertEqual(FlowTempo.fold(.nan, near: 120), 120)
        XCTAssertEqual(FlowTempo.fold(-60, near: 120), 120)
    }

    func testTheTargetStepsAtMostTwoPerBarAndTheTempoGlidesThereInTwoSeconds() {
        var flow = FlowTempo()
        flow.open(at: 100)
        _ = play(&flow, seconds: 6, pulse: 120, barEvery: 1_000)
        XCTAssertEqual(flow.wanted, 120)
        XCTAssertEqual(flow.target, 100, "no bar line, no step")
        flow.bar()
        XCTAssertEqual(flow.target, 102)
        XCTAssertEqual(flow.tempo, 100, "the glide starts where the tempo is")
        flow.advance(seconds: 1, pulse: 120)
        XCTAssertEqual(flow.tempo ?? 0, 101, accuracy: 1e-9)
        flow.advance(seconds: 1, pulse: 120)
        XCTAssertEqual(flow.tempo ?? 0, 102, accuracy: 1e-9)
        flow.advance(seconds: 5, pulse: 120)
        XCTAssertEqual(flow.tempo ?? 0, 102, accuracy: 1e-9, "it arrives and stays until the next bar line")
        // Bar after bar it walks the rest of the way, and stops at the pulse.
        for _ in 0..<20 {
            flow.bar()
            flow.advance(seconds: 2, pulse: 120)
        }
        XCTAssertEqual(flow.tempo ?? 0, 120, accuracy: 1e-9)
        XCTAssertEqual(flow.target, 120)
    }

    func testASongFarOutsideTheRangeComesIntoItAStepAtATime() throws {
        var flow = FlowTempo()
        flow.open(at: 300)
        let played = play(&flow, seconds: 400, pulse: 70)
        // 70 folds to 140, the octave nearest 300 that the range holds.
        XCTAssertEqual(flow.wanted, 140)
        XCTAssertEqual(flow.tempo ?? 0, 140, accuracy: 1e-9)
        for tempo in played { XCTAssertTrue((140...300).contains(tempo), "\(tempo)") }
        // Nonsense in is nothing out.
        var odd = FlowTempo()
        odd.open(at: .nan)
        XCTAssertEqual(odd.tempo, Tempo.defaultBPM)
        odd.advance(seconds: .infinity, pulse: 70)
        odd.advance(seconds: -1, pulse: 70)
        for _ in 0..<40 {
            odd.advance(seconds: 1, pulse: .nan)
            odd.advance(seconds: 1, pulse: -60)
            odd.bar()
        }
        XCTAssertEqual(odd.tempo, Tempo.defaultBPM)
        XCTAssertNil(odd.wanted)
    }

    func testClosingTheLockKeepsWhereFlowGotToTheWholeBeat() throws {
        var flow = FlowTempo()
        flow.open(at: 100)
        _ = play(&flow, seconds: 6, pulse: 120, barEvery: 1_000)
        flow.bar()
        flow.advance(seconds: 1.25, pulse: 120)
        XCTAssertEqual(flow.tempo ?? 0, 101.25, accuracy: 1e-9)
        XCTAssertEqual(flow.close(), 101)
        XCTAssertEqual(flow.lock, .fixed)
        XCTAssertNil(flow.tempo)
        XCTAssertEqual(FlowTempo.kept(101.5), 102)
        XCTAssertEqual(FlowTempo.kept(5_000), Tempo.range.upperBound)
        XCTAssertEqual(FlowTempo.kept(.nan), Tempo.defaultBPM)
        // Opened again, Flow starts over: the trust is earned anew.
        flow.open(at: 101)
        XCTAssertFalse(flow.isFollowing)
        XCTAssertEqual(flow.tempo, 101)
    }

    /// What a view shows of Flow — whether it follows, the tempo to a tenth — changes only when the
    /// trust or the tempo does: a steady pulse at a tempo already there redraws nothing, look after
    /// look (Law 6).
    func testWhatAViewShowsChangesOnlyWhenTheTrustOrTheTempoDoes() {
        var flow = FlowTempo()
        flow.open(at: 128)
        var last = (flow.isFollowing, flow.shownTempo)
        var changes = 0
        for look in 1...240 {
            flow.advance(seconds: 0.25, pulse: 64)
            if look % 8 == 0 { flow.bar() }
            let now = (flow.isFollowing, flow.shownTempo)
            if now != last { changes += 1 }
            last = now
        }
        XCTAssertTrue(flow.isFollowing)
        XCTAssertEqual(flow.shownTempo, 128, "64 folds onto the 128 already playing")
        XCTAssertEqual(changes, 1, "once, when the pulse came to be trusted")
    }

    func testExactlyOneSourceSetsThePaceAndAFollowedClockWinsOverFlow() {
        XCTAssertEqual(TempoSource.current(followsJam: false, followsMIDIClock: false, flows: false), .song)
        XCTAssertEqual(TempoSource.current(followsJam: false, followsMIDIClock: false, flows: true), .flow)
        XCTAssertEqual(TempoSource.current(followsJam: false, followsMIDIClock: true, flows: true), .midiClock)
        XCTAssertEqual(TempoSource.current(followsJam: true, followsMIDIClock: false, flows: true), .jam)
        XCTAssertEqual(TempoSource.current(followsJam: true, followsMIDIClock: true, flows: false), .jam)
    }
}
