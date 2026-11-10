import XCTest
@testable import EchoelCore

/// The Field's motion, frame by frame: the same frames give the same pictures, the first frame
/// shows the song as it is, a still picture holds, and no clock or brightness outruns its ceiling.
final class FieldMotionTests: XCTestCase {
    private func song(_ index: Int) -> FieldFrame {
        FieldFrame(beatPhase: Double(index % 30) / 30, barPhase: Double(index % 120) / 120, tonicHz: 293.66,
                   level: Double(index % 7) / 7, pulse: 0.3, coherence: 0.6, breath: Double(index % 11) / 11,
                   isPlaying: true)
    }

    /// Two runs over the same frames at the same steps are the same film, number for number.
    func testTheSameFramesGiveTheSamePictures() {
        var first = FieldMotion()
        var second = FieldMotion()
        var one: [FieldMotion.Shown] = []
        var two: [FieldMotion.Shown] = []
        for index in 0..<300 {
            one.append(first.step(song(index), after: 1.0 / 30, still: false, patternScale: 1))
        }
        for index in 0..<300 {
            two.append(second.step(song(index), after: 1.0 / 30, still: false, patternScale: 1))
        }
        XCTAssertEqual(one, two)
        XCTAssertNotEqual(one[10], one[11], "and the picture does move")
    }

    /// The first frame shows the song and the body as they are, with no glide from defaults.
    func testTheFirstFrameShowsTheSongAsItIs() {
        var motion = FieldMotion()
        let frame = FieldFrame(tonicHz: 440, level: 0.5, coherence: 0.8, breath: 0.2, isPlaying: false)
        let shown = motion.step(frame, after: 1.0 / 60, still: false, patternScale: 0.7)
        XCTAssertEqual(shown.toneHz, 440, accuracy: 1e-12)
        XCTAssertEqual(shown.coherence, 0.8, accuracy: 1e-12)
        XCTAssertEqual(shown.breath, 0.2, accuracy: 1e-12)
        XCTAssertEqual(shown.levelLight, 0.5, accuracy: 1e-12)
        XCTAssertEqual(shown.centreLight, 0.5, accuracy: 1e-12, "no pulse: the centre follows the level")
        XCTAssertEqual(shown.density, FieldMotion.ringDensity * 0.7, accuracy: 1e-9)
        XCTAssertEqual(shown.beatLight, 0, "stopped: no beat ring")
        XCTAssertTrue(shown.hasCoherence)
        XCTAssertFalse(shown.hasPulse)
    }

    /// Reduce Motion, or a device at its lowest detail: the beat ring rests and nothing drifts —
    /// even with the song playing and a pulse measured.
    func testAStillPictureHoldsItsPhases() {
        var motion = FieldMotion()
        var last = FieldMotion.Shown()
        for index in 0..<120 {
            let frame = FieldFrame(beatPhase: Double(index % 30) / 30, barPhase: Double(index % 60) / 60, pulse: 0.5,
                                   isPlaying: true)
            last = motion.step(frame, after: 1.0 / 60, still: true, patternScale: 1)
            XCTAssertEqual(last.beatPhase, 0)
            XCTAssertEqual(last.fieldPhase, 0)
            XCTAssertEqual(last.pulsePhase, 0)
            XCTAssertEqual(last.beatLight, 0)
        }
        XCTAssertTrue(last.hasPulse, "the pulse is still measured; it only does not move the picture")
    }

    /// A song far faster than the eye may follow, a strobing level: the field drifts at most
    /// `FieldPulse.maximumRateHz` turns a second and no brightness moves faster than the flash guard.
    func testNoClockOrBrightnessOutrunsItsCeiling() {
        var motion = FieldMotion()
        var previous: FieldMotion.Shown?
        let seconds = 1.0 / 60
        for index in 0..<240 {
            let frame = FieldFrame(beatPhase: index % 2 == 0 ? 0 : 0.5, barPhase: Double(index % 4) / 4 + 0.1,
                                   level: index % 2 == 0 ? 1 : 0, pulse: 1, isPlaying: true)
            let shown = motion.step(frame, after: seconds, still: false, patternScale: 1)
            if let previous {
                var turn = shown.fieldPhase - previous.fieldPhase
                if turn < 0 { turn += 1 }
                XCTAssertLessThanOrEqual(turn, FieldPulse.maximumRateHz * seconds + 1e-9)
                XCTAssertLessThanOrEqual(abs(shown.beatLight - previous.beatLight), FlashLimit.maximumRate * seconds + 1e-9)
                XCTAssertLessThanOrEqual(abs(shown.levelLight - previous.levelLight), FlashLimit.maximumRate * seconds + 1e-9)
                XCTAssertLessThanOrEqual(abs(shown.centreLight - previous.centreLight), FlashLimit.maximumRate * seconds + 1e-9)
            }
            previous = shown
        }
    }

    /// The body is shown only where it is measured; without a pulse the heartbeat clock stops at once.
    func testTheBodyIsShownOnlyWhereItIsMeasured() {
        var motion = FieldMotion()
        let measured = motion.step(FieldFrame(pulse: 0.4, coherence: 0.7), after: 1.0 / 60, still: false, patternScale: 1)
        XCTAssertTrue(measured.hasPulse)
        XCTAssertTrue(measured.hasCoherence)
        XCTAssertGreaterThan(measured.pulsePhase, 0)
        let absent = motion.step(FieldFrame(), after: 1.0 / 60, still: false, patternScale: 1)
        XCTAssertFalse(absent.hasPulse)
        XCTAssertFalse(absent.hasCoherence)
        XCTAssertEqual(absent.pulsePhase, measured.pulsePhase, "no pulse, no heartbeat")
    }

    /// The live stream's picture (wave W14) is drawn from the frame as it may leave the device
    /// (`FieldFrame.leavingDevice`): a pulse that must stay on it — Apple Health's — is no heartbeat
    /// there, and the centre rests on the level as with no body source, while the window on the
    /// device keeps beating. A pulse that may leave (a strap, the camera) is the same frame in both.
    func testAPulseThatMustStayOnTheDeviceMovesNoPictureThatLeaves() {
        let onDevice = FieldFrame(level: 0.2, pulse: 0.5, isPlaying: true)
        let streamed = onDevice.leavingDevice { (_: ModulationSource) -> Double? in nil }
        var window = FieldMotion()
        var stream = FieldMotion()
        var seen = FieldMotion.Shown()
        var sent = FieldMotion.Shown()
        for _ in 0..<60 {
            seen = window.step(onDevice, after: 1.0 / 60, still: false, patternScale: 1)
            sent = stream.step(streamed, after: 1.0 / 60, still: false, patternScale: 1)
            XCTAssertEqual(sent.pulsePhase, 0, "no heartbeat clock in the picture that leaves")
            XCTAssertFalse(sent.hasPulse)
        }
        XCTAssertTrue(seen.hasPulse, "the window on the device still shows the pulse")
        XCTAssertGreaterThan(seen.pulsePhase, 0)
        XCTAssertEqual(seen.centreLight, 0.5, accuracy: 1e-9, "its centre on the pulse")
        XCTAssertEqual(sent.centreLight, 0.2, accuracy: 1e-9, "the stream's on the level")
        let shared = onDevice.leavingDevice { (source: ModulationSource) -> Double? in
            source == .heartRate ? 0.5 : nil
        }
        XCTAssertEqual(shared, onDevice, "a pulse that may leave: the same frame, so the same picture")
    }
}
