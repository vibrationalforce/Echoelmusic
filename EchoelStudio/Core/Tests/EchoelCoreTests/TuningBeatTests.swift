import Foundation
import XCTest
@testable import EchoelCore

/// The Moiré look's measure: the song's third as its tone system tunes it, as the beat of the
/// partials that coincide in the pure ratio. Numbers worked out from the formulas (C4 = 261.6256 Hz,
/// A4 = 440 Hz): a 12-equal major third beats 10.38 Hz on C and 17.46 Hz on A.
final class TuningBeatTests: XCTestCase {
    private func context(root: Int = 0, scale: Scale = .major, tuning: String = "edo12",
                         concertPitch: Double = 440) -> MusicalContext {
        var context = MusicalContext()
        context.root = root
        context.scale = scale
        context.tuning = tuning
        context.concertPitch = concertPitch
        return context
    }

    func testAPureThirdStandsStillAndAnEqualOneBeats() {
        let pure = TuningBeat.of(context(tuning: "just-major"))
        XCTAssertEqual(pure.semitones, 4)
        XCTAssertEqual(pure.p, 5)
        XCTAssertEqual(pure.q, 4)
        XCTAssertLessThan(pure.beatHz, 0.001, "just intonation: the partials coincide")
        XCTAssertLessThan(pure.driftHz, 0.001)

        let equalOnC = TuningBeat.of(context())
        XCTAssertEqual(equalOnC.beatHz, 10.382, accuracy: 0.01)
        let equalOnA = TuningBeat.of(context(root: 9))
        XCTAssertEqual(equalOnA.beatHz, 17.461, accuracy: 0.01)
        XCTAssertGreaterThan(equalOnC.driftHz, 1.9, "a fast beat drifts near the ceiling")
        XCTAssertLessThan(equalOnC.driftHz, TuningBeat.maximumDriftHz)
        XCTAssertLessThan(TuningBeat.maximumDriftHz, FieldPulse.maximumRateHz, "under the house flash ceiling")

        let meantone = TuningBeat.of(context(tuning: "meantone-quarter"))
        XCTAssertLessThan(meantone.beatHz, 0.05, "quarter-comma meantone keeps the third pure")
    }

    func testAMinorScaleIsJudgedByItsMinorThird() {
        let minor = TuningBeat.of(context(scale: .minor))
        XCTAssertEqual(minor.semitones, 3)
        XCTAssertEqual(minor.p, 6)
        XCTAssertEqual(minor.q, 5)
        XCTAssertGreaterThan(minor.beatHz, 1)
        // A system that plays semitone 4 as 6/5 is judged as the 6/5 it plays: just minor, major scale.
        let played = TuningBeat.of(context(scale: .major, tuning: "just-minor"))
        XCTAssertEqual(played.p, 6)
        XCTAssertEqual(played.q, 5)
        XCTAssertLessThan(played.beatHz, 0.001)
    }

    func testSystemsThatPlayTwelveEqualShowItsBeat() {
        let equal = TuningBeat.of(context())
        for tuning in ["edo24", "bohlen-pierce", "no-such-system"] {
            XCTAssertEqual(TuningBeat.of(context(tuning: tuning)).beatHz, equal.beatHz, accuracy: 1e-9, tuning)
        }
    }

    func testEveryKeyAndSystemDriftsFiniteAndInOrder() {
        for system in TuningSystem.library {
            for root in 0..<12 {
                for scale in Scale.allCases {
                    let beat = TuningBeat.of(context(root: root, scale: scale, tuning: system.id))
                    XCTAssertTrue(beat.beatHz.isFinite && beat.beatHz >= 0, "\(system.id) \(root) \(scale)")
                    XCTAssertTrue(beat.driftHz >= 0 && beat.driftHz <= TuningBeat.maximumDriftHz, "\(system.id)")
                }
            }
        }
        var previous = 0.0
        for beat in stride(from: 0.0, through: 40, by: 0.25) {
            let drift = TuningBeat.drift(beatHz: beat)
            XCTAssertGreaterThanOrEqual(drift, previous, "a faster beat never drifts slower")
            previous = drift
        }
        XCTAssertEqual(TuningBeat.drift(beatHz: .nan), 0)
        XCTAssertEqual(TuningBeat.drift(beatHz: -3), 0)
    }

    func testABadPitchOrRootStaysFinite() {
        for pitch in [Double.nan, .infinity, -440] {
            let beat = TuningBeat.of(context(concertPitch: pitch))
            XCTAssertTrue(beat.beatHz.isFinite)
            XCTAssertTrue(beat.driftHz.isFinite)
        }
        for root in [-13, 99] {
            XCTAssertTrue(TuningBeat.of(context(root: root)).beatHz.isFinite)
        }
    }

    func testTheFrameCarriesTheSongsBeat() {
        let frame = FieldFrame.at(tick: 0, signature: .common, context: context(tuning: "just-major"), level: 0,
                                  pulse: nil, hrv: nil, coherence: nil, isPlaying: false)
        XCTAssertLessThan(frame.tuningBeat.beatHz, 0.001)
        XCTAssertEqual(FieldFrame().tuningBeat, .unison)
        XCTAssertTrue(TuningBeat.of(context()).spoken.contains("major third 5 to 4"))
        XCTAssertTrue(TuningBeat.of(context(tuning: "just-major")).spoken.contains("stands still"))
        // Named by the ratio it is judged against: just minor plays the major scale's third as 6/5.
        XCTAssertTrue(TuningBeat.of(context(scale: .major, tuning: "just-minor")).spoken.hasPrefix("minor third 6 to 5"))
    }
}
