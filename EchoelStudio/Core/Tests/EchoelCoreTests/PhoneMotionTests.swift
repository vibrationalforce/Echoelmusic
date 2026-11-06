import XCTest
@testable import EchoelCore

/// The phone as a body source (Recovery 9): each channel normalized to 0 … 1, smoothed, absent
/// rather than guessed, and still means no energy.
final class PhoneMotionTests: XCTestCase {
    private let step = 1.0 / 60

    private func reading(at seconds: Double, roll: Double = 0, pitch: Double = 0, yawRate: Double = 0,
                         acceleration: (Double, Double, Double) = (0, 0, 0)) -> PhoneMotion.Reading {
        PhoneMotion.Reading(seconds: seconds, roll: roll, pitch: pitch, yawRate: yawRate,
                            accelerationX: acceleration.0, accelerationY: acceleration.1, accelerationZ: acceleration.2)
    }

    func testEveryChannelIsAbsentBeforeTheFirstSample() {
        let motion = PhoneMotion()
        XCTAssertEqual(motion.values, .absent)
        for source in PhoneMotion.sources { XCTAssertNil(motion.values.value(for: source), source.rawValue) }
        XCTAssertNil(motion.values.value(for: .heartRate), "the phone feeds only its own four")
    }

    func testTheNormalizationSpansZeroToOne() throws {
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.tilt(0)), 0.5, accuracy: 1e-12, "flat is the middle")
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.tilt(.pi / 2)), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.tilt(-.pi / 2)), 0, accuracy: 1e-12)
        // No seam where the attitude wraps at ±180°.
        let justBefore = try XCTUnwrap(PhoneMotion.tilt(.pi - 1e-6))
        let justAfter = try XCTUnwrap(PhoneMotion.tilt(-.pi + 1e-6))
        XCTAssertEqual(justBefore, justAfter, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.rotation(0)), 0.5, accuracy: 1e-12, "at rest the middle")
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.rotation(PhoneMotion.fullRotationRadiansPerSecond)), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.rotation(-10 * PhoneMotion.fullRotationRadiansPerSecond)), 0,
                       "a spin past the full swing stays at the end")
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.energy(0, 0, PhoneMotion.fullEnergyG)), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(PhoneMotion.energy(3, 4, 0)), 1, "a hard shake stays at the top")
        for value in [PhoneMotion.tilt(2.3), PhoneMotion.rotation(1.1), PhoneMotion.energy(0.2, -0.1, 0.3)] {
            let unwrapped = try XCTUnwrap(value)
            XCTAssertTrue((0...1).contains(unwrapped), "\(unwrapped)")
        }
    }

    /// Gravity removed: a phone lying still — sensor noise of a few thousandths of a g — moves nothing.
    func testAStillPhoneHasNoEnergy() throws {
        var motion = PhoneMotion()
        for index in 0..<120 {
            let noise = (index % 2 == 0 ? 1.0 : -1.0) * 0.004
            motion.take(reading(at: Double(index) * step, acceleration: (noise, -noise, noise)))
        }
        XCTAssertEqual(try XCTUnwrap(motion.values.energy), 0, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(motion.values.tiltX), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(motion.values.rotation), 0.5, accuracy: 1e-12)
        XCTAssertEqual(PhoneMotion.energy(0, 0, 0), 0)
    }

    /// The first sample lands at once; after that each channel glides by the time that passed,
    /// reaching ~63 % of a step within one time constant, and never jumps past its target.
    func testTheSmoothingGlidesByElapsedTime() throws {
        var motion = PhoneMotion()
        motion.take(reading(at: 0))
        XCTAssertEqual(try XCTUnwrap(motion.values.energy), 0)
        var time = 0.0
        var previous = 0.0
        while time < PhoneMotion.energySmoothingSeconds - step / 2 {
            time += step
            motion.take(reading(at: time, acceleration: (0, 0, PhoneMotion.fullEnergyG)))
            let energy = try XCTUnwrap(motion.values.energy)
            XCTAssertGreaterThan(energy, previous, "it rises every sample")
            XCTAssertLessThan(energy, 1, "and never overshoots")
            previous = energy
        }
        XCTAssertEqual(previous, 1 - exp(-time / PhoneMotion.energySmoothingSeconds), accuracy: 1e-9)
        // The same glide in two samples of 1/30 s or four of 1/60 s ends in the same place.
        var coarse = PhoneMotion(), fine = PhoneMotion()
        coarse.take(reading(at: 0))
        fine.take(reading(at: 0))
        for index in 1...2 { coarse.take(reading(at: Double(index) / 30, roll: .pi / 2)) }
        for index in 1...4 { fine.take(reading(at: Double(index) / 60, roll: .pi / 2)) }
        XCTAssertEqual(try XCTUnwrap(coarse.values.tiltX), try XCTUnwrap(fine.values.tiltX), accuracy: 1e-12)
    }

    func testAGapStartsAfreshInsteadOfGliding() throws {
        var motion = PhoneMotion()
        motion.take(reading(at: 0, roll: -.pi / 2))
        motion.take(reading(at: PhoneMotion.maximumGapSeconds + 0.1, roll: .pi / 2))
        XCTAssertEqual(try XCTUnwrap(motion.values.tiltX), 1, accuracy: 1e-12)
    }

    func testADuplicateOrOlderSampleMovesNothing() throws {
        var motion = PhoneMotion()
        motion.take(reading(at: 1, pitch: 0))
        let before = motion.values
        motion.take(reading(at: 1, pitch: .pi / 2))
        motion.take(reading(at: 0.5, pitch: .pi / 2))
        XCTAssertEqual(motion.values, before)
    }

    /// A non-finite number empties its own channel and leaves the others measured; a non-finite
    /// time empties them all. Nothing NaN ever comes out.
    func testNonFiniteInputsAreAbsentNeverNaN() throws {
        var motion = PhoneMotion()
        motion.take(reading(at: 0, roll: 0.3, pitch: 0.2, yawRate: 0.5, acceleration: (0.5, 0, 0)))
        motion.take(reading(at: step, roll: .nan, pitch: 0.2, yawRate: .infinity, acceleration: (0.5, .nan, 0)))
        XCTAssertNil(motion.values.tiltX)
        XCTAssertNil(motion.values.rotation)
        XCTAssertNil(motion.values.energy)
        let pitch = try XCTUnwrap(motion.values.tiltY, "the finite channel stays measured")
        XCTAssertTrue(pitch.isFinite)
        // The channel comes back with the next finite sample, at its value rather than a glide from nothing.
        motion.take(reading(at: 2 * step, roll: .pi / 2, pitch: 0.2))
        XCTAssertEqual(try XCTUnwrap(motion.values.tiltX), 1, accuracy: 1e-12)
        motion.take(reading(at: .nan))
        XCTAssertEqual(motion.values, .absent)
        XCTAssertNil(PhoneMotion.energy(.greatestFiniteMagnitude, .greatestFiniteMagnitude, 0),
                     "an overflowing length is absent, not infinite")
    }

    func testResetLeavesEveryChannelAbsent() {
        var motion = PhoneMotion()
        motion.take(reading(at: 0, roll: 0.4))
        motion.reset()
        XCTAssertEqual(motion.values, .absent)
        motion.take(reading(at: 0, roll: .pi / 2))
        XCTAssertEqual(motion.values.tiltX ?? -1, 1, accuracy: 1e-12, "after a reset the clock may start again")
    }

    /// The four sources follow the MIDI controller in the list, in this order, where they were added
    /// at its end (only the Weave's bar value came after them) — the engine finds a live value by its place.
    func testTheFourSourcesFollowTheMIDIControllerInOrder() throws {
        let all = ModulationSource.allCases
        let first = try XCTUnwrap(all.firstIndex(of: .midiCC1)) + 1
        XCTAssertEqual(Array(all[first..<(first + 4)]), PhoneMotion.sources)
        XCTAssertEqual(Array(all.suffix(from: first + 4)), [.weave1])
    }
}
