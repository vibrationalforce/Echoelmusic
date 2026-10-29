import XCTest
@testable import EchoelCore

final class FieldTests: XCTestCase {
    func testThePhasesFollowThePlayheadAndRestWhenStopped() {
        let beat = Double(MusicalTime.ticksPerQuarter)
        let playing = FieldFrame.at(tick: beat * 5.5, signature: .common, context: MusicalContext(), level: 0.5,
                                    pulse: nil, hrv: nil, coherence: nil, isPlaying: true)
        XCTAssertEqual(playing.beatPhase, 0.5, accuracy: 1e-12)
        XCTAssertEqual(playing.barPhase, 1.5 / 4, accuracy: 1e-12, "beat 6 of a 4/4 bar is half-way through its second beat")
        let stopped = FieldFrame.at(tick: beat * 5.5, signature: .common, context: MusicalContext(), level: 0.5,
                                    pulse: nil, hrv: nil, coherence: nil, isPlaying: false)
        XCTAssertEqual(stopped.beatPhase, 0)
        XCTAssertEqual(stopped.barPhase, 0)
    }

    func testRelatedKeysSitCloseOnTheCircleOfFifths() {
        XCTAssertEqual(FieldFrame.keyHue(root: 0), 0)
        XCTAssertEqual(FieldFrame.keyHue(root: 7), 1.0 / 12, accuracy: 1e-12, "G is one fifth from C")
        XCTAssertEqual(FieldFrame.keyHue(root: 2), 2.0 / 12, accuracy: 1e-12, "D is two")
        XCTAssertEqual(FieldFrame.keyHue(root: 5), 11.0 / 12, accuracy: 1e-12, "F is one fifth below")
        XCTAssertEqual(FieldFrame.keyHue(root: -1), FieldFrame.keyHue(root: 11))
    }

    /// The picture never invents a body: a reading outside 0 … 1 or not finite is absent.
    func testAnUnmeasuredOrBadBodyReadingIsAbsent() {
        let frame = FieldFrame(level: 7, pulse: 1.5, hrv: .nan, coherence: 0.4)
        XCTAssertEqual(frame.level, 1)
        XCTAssertNil(frame.pulse)
        XCTAssertNil(frame.hrv)
        XCTAssertEqual(frame.coherence, 0.4)
    }

    /// Asked to strobe at 10 Hz, the guard lets through no more than three flashes a second.
    func testNoMoreThanThreeFlashesASecond() {
        var limit = FlashLimit()
        let frameSeconds = 1.0 / 60
        var shown: [Double] = []
        for frame in 0..<600 {
            let strobe = (frame / 3) % 2 == 0 ? 1.0 : 0.0  // 10 Hz at 60 frames a second
            shown.append(limit.next(towards: strobe, after: frameSeconds))
        }
        // Count full swings of at least one flash step, rise then fall.
        var flashes = 0, anchor = shown[0], rising = true
        for value in shown {
            if rising, value - anchor >= FlashLimit.flashStep { rising = false; anchor = value }
            else if !rising, anchor - value >= FlashLimit.flashStep { rising = true; anchor = value; flashes += 1 }
            if rising { anchor = Swift.min(anchor, value) } else { anchor = Swift.max(anchor, value) }
        }
        XCTAssertLessThanOrEqual(Double(flashes) / 10, FlashLimit.flashesPerSecond)
    }

    func testTheGuardStillReachesASlowTarget() {
        var limit = FlashLimit()
        for _ in 0..<120 { _ = limit.next(towards: 0.5, after: 1.0 / 60) }
        XCTAssertEqual(limit.value, 0.5, accuracy: 1e-9, "a gentle change arrives within two seconds")
        XCTAssertEqual(limit.next(towards: .nan, after: 1), 0.5, "a bad target changes nothing")
    }

    /// The tonic the Metal picture is coloured with: the key's root in the octave of middle C.
    func testTheTonicFollowsTheKeyAndTheConcertPitch() {
        XCTAssertEqual(FieldFrame.tonicHz(of: MusicalContext()), 261.6256, accuracy: 1e-3, "C at A = 440")
        XCTAssertEqual(FieldFrame.tonicHz(of: MusicalContext(root: 9)), 440, accuracy: 1e-9, "A is the concert pitch itself")
        XCTAssertEqual(FieldFrame.tonicHz(of: MusicalContext(root: 9, concertPitch: 442)), 442, accuracy: 1e-9)
        XCTAssertEqual(FieldFrame.tonicHz(of: MusicalContext(root: 7)), 391.9954, accuracy: 1e-3, "G")
        XCTAssertEqual(FieldFrame(tonicHz: .infinity).tonicHz, FieldFrame.middleC, "a bad pitch keeps middle C")
        XCTAssertEqual(FieldFrame(tonicHz: 5).tonicHz, FieldFrame.middleC, "an inaudible pitch too")
        let frame = FieldFrame.at(tick: 0, signature: .common, context: MusicalContext(root: 2), level: 0,
                                  pulse: nil, hrv: nil, coherence: nil, isPlaying: false, breath: 0.3)
        XCTAssertEqual(frame.tonicHz, 293.6648, accuracy: 1e-3, "D")
        XCTAssertEqual(frame.breath, 0.3)
        XCTAssertNil(FieldFrame(breath: 1.5).breath, "a breath outside 0 … 1 is absent")
    }

    // MARK: - The heartbeat clock

    func testTheHeartRateComesBackFromItsNormalizedForm() throws {
        XCTAssertEqual(try XCTUnwrap(FieldPulse.beatsPerMinute(pulse: 0)), 40)
        XCTAssertEqual(try XCTUnwrap(FieldPulse.beatsPerMinute(pulse: 1)), 200)
        XCTAssertEqual(try XCTUnwrap(FieldPulse.beatsPerMinute(pulse: 0.125)), 60, accuracy: 1e-9)
        XCTAssertNil(FieldPulse.beatsPerMinute(pulse: nil))
        XCTAssertNil(FieldPulse.beatsPerMinute(pulse: .nan))
        XCTAssertNil(FieldPulse.beatsPerMinute(pulse: 1.2), "a reading outside the channel is no reading")
    }

    /// The picture pulses with the heart, bounded, never above the ceiling, and not at all with no
    /// pulse or under Reduce Motion.
    func testThePulseRateIsBoundedAndNeverAboveTheCeiling() {
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: 60, reduceMotion: false), 1)
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: 120, reduceMotion: false), 2)
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: 200, reduceMotion: false), 2, "a racing heart holds the picture at 2 Hz")
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: 20, reduceMotion: false), 0.5)
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: 60, reduceMotion: true), 0, "Reduce Motion: a still picture")
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: nil, reduceMotion: false), 0, "no pulse, no heartbeat")
        XCTAssertEqual(FieldPulse.rate(beatsPerMinute: .nan, reduceMotion: false), 0)
        for bpm in stride(from: 0.0, through: 400, by: 7) {
            XCTAssertLessThanOrEqual(FieldPulse.rate(beatsPerMinute: bpm, reduceMotion: false), FieldPulse.maximumRateHz)
        }
    }

    /// Asked for 10 Hz, the clock advances no more than the ceiling allows; asked to stop, it stops now.
    func testThePhaseNeverAdvancesFasterThanTheCeiling() {
        var pulse = FieldPulse()
        let frameSeconds = 1.0 / 60
        var turns = 0.0, last = pulse.phase
        for _ in 0..<600 {
            let next = pulse.advance(towards: 10, after: frameSeconds)
            var step = next - last
            if step < 0 { step += 1 }
            turns += step
            last = next
        }
        XCTAssertLessThanOrEqual(turns / 10, FieldPulse.maximumRateHz + 1e-9, "turns a second")
        XCTAssertEqual(pulse.rateHz, FieldPulse.maximumRateHz, accuracy: 1e-9)
        // The rate slews: from 0 to 2.5 Hz takes 5 s at 0.5 Hz/s, so after one second it is 0.5.
        var fresh = FieldPulse()
        for _ in 0..<60 { fresh.advance(towards: 2.5, after: frameSeconds) }
        XCTAssertEqual(fresh.rateHz, 0.5, accuracy: 1e-6)
        // A stop is immediate: the phase holds from this frame on.
        let held = fresh.advance(towards: 0, after: frameSeconds)
        XCTAssertEqual(fresh.rateHz, 0)
        XCTAssertEqual(fresh.advance(towards: 0, after: frameSeconds), held)
        XCTAssertEqual(fresh.advance(towards: .nan, after: frameSeconds), held, "a bad target is a stop")
        XCTAssertEqual(fresh.advance(towards: 1, after: 0), held, "no time, no step")
    }

    /// The field drifts with the song's bar: a wrap is a step forward, and a song faster than the
    /// eye may follow is capped, never strobed.
    func testTheSongPhaseFollowsTheBarAndIsCapped() {
        let frameSeconds = 1.0 / 60
        XCTAssertEqual(FieldPulse.songPhase(0.2, barPhase: 0.26, previousBarPhase: 0.25, after: frameSeconds), 0.21, accuracy: 1e-12)
        XCTAssertEqual(FieldPulse.songPhase(0.97, barPhase: 0.02, previousBarPhase: 0.99, after: frameSeconds), 0, accuracy: 1e-12,
                       "the bar wrapped: +0.03, and the phase wraps with it")
        XCTAssertEqual(FieldPulse.songPhase(0.5, barPhase: 0.7, previousBarPhase: nil, after: frameSeconds), 0.5, "no previous frame, no step")
        // A bar that passes in a tenth of a second asks for 10 turns a second; the picture gets 2.5.
        var phase = 0.0, bar = 0.0, turns = 0.0
        for _ in 0..<600 {
            let previous = bar
            bar = (bar + 10 * frameSeconds).truncatingRemainder(dividingBy: 1)
            let next = FieldPulse.songPhase(phase, barPhase: bar, previousBarPhase: previous, after: frameSeconds)
            var step = next - phase
            if step < 0 { step += 1 }
            turns += step
            phase = next
        }
        XCTAssertEqual(turns / 10, FieldPulse.maximumRateHz, accuracy: 1e-6, "turns a second, capped")
        XCTAssertEqual(FieldPulse.songPhase(0.5, barPhase: 0.4, previousBarPhase: 0.4, after: frameSeconds), 0.5, "a stopped song holds")
    }

    /// The shader's constants are the Swift constants: the folded field lands under three flashes
    /// a second, the heartbeat bloom's swing under the general-flash threshold.
    func testTheShaderConstantsKeepTheFlashLaw() throws {
        XCTAssertEqual(try XCTUnwrap(Double(FieldPulse.foldDampingLiteral)), FieldPulse.foldDamping)
        XCTAssertEqual(try XCTUnwrap(Double(FieldPulse.bloomSwingLiteral)), FieldPulse.bloomSwing)
        XCTAssertEqual(try XCTUnwrap(Double(FieldPulse.ambientLiteral)), FieldPulse.ambient)
        let floor = try XCTUnwrap(Double(FieldPulse.restGlowFloorLiteral)), span = try XCTUnwrap(Double(FieldPulse.restGlowSpanLiteral))
        XCTAssertEqual(floor + span, FieldPulse.restGlowCeiling, accuracy: 1e-12)
        // A squared wave flashes twice per cycle: 2 × damping × ceiling must stay under the law.
        XCTAssertLessThanOrEqual(2 * FieldPulse.foldDamping * FieldPulse.maximumRateHz, FlashLimit.flashesPerSecond)
        XCTAssertLessThan(FieldPulse.maximumRateHz, FlashLimit.flashesPerSecond, "the house ceiling leaves room under WCAG")
        // The bloom brightens with every heartbeat at the heart's rate; its swing must not count as a flash.
        let swing = FieldPulse.bloomSwing * FieldPulse.restGlowCeiling * (1 - FieldPulse.ambient)
        XCTAssertLessThan(swing, FlashLimit.generalFlashThreshold)
    }

    // MARK: - Detail, never frame rate

    func testTheDetailLevelFollowsHeatAndPowerAndTheFrameRateStaysPinned() {
        func level(_ thermal: FieldDetail.Thermal = .nominal, lowPower: Bool = false, battery: Double = -1,
                   charging: Bool = false, fps: Double = 0) -> FieldDetail.Level {
            FieldDetail.level(thermal: thermal, lowPower: lowPower, batteryLevel: battery, charging: charging,
                              measuredFrameRate: fps)
        }
        XCTAssertEqual(level(), .full)
        XCTAssertEqual(level(.fair), .full)
        XCTAssertEqual(level(.serious), .low)
        XCTAssertEqual(level(.critical), .minimal)
        XCTAssertEqual(level(lowPower: true), .low)
        XCTAssertEqual(level(battery: 0.15), .low)
        XCTAssertEqual(level(battery: 0.05), .minimal)
        XCTAssertEqual(level(battery: 0.05, charging: true), .full, "plugged in, the battery is no reason")
        XCTAssertEqual(level(battery: 0.5), .full)
        XCTAssertEqual(level(fps: 59), .full)
        XCTAssertEqual(level(fps: 30), .low, "a device that cannot hold 60 sheds detail once")
        XCTAssertEqual(level(.serious, fps: 30), .minimal)
        XCTAssertEqual(level(.critical, fps: 30), .minimal, "and never below the floor")
        XCTAssertEqual(level(fps: .nan), .full)

        XCTAssertEqual(FieldDetail.frameRate, 60)
        XCTAssertEqual(FieldDetail(level: .full).resolutionScale, 1)
        XCTAssertEqual(FieldDetail(level: .low).resolutionScale, 0.7)
        XCTAssertEqual(FieldDetail(level: .minimal).resolutionScale, 0.5)
        XCTAssertTrue(FieldDetail(level: .minimal).isStill)
        XCTAssertFalse(FieldDetail(level: .low).isStill)
        for level in FieldDetail.Level.allCases {
            let detail = FieldDetail(level: level)
            XCTAssertTrue((0.5...1).contains(detail.resolutionScale))
            XCTAssertEqual(detail.patternScale, detail.resolutionScale)
        }
    }
}
