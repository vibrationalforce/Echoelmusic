import XCTest
@testable import EchoelDSP

final class DrumKitTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(_ kit: inout DrumKit, seconds: Float) -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(seconds * rate))
        var start = 0
        while start < buffer.count {
            let end = Swift.min(start + 256, buffer.count)
            buffer[start..<end].withUnsafeMutableBufferPointer { kit.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func peak(_ samples: [Float]) -> Float { samples.reduce(0) { Swift.max($0, Swift.abs($1)) } }

    func testEveryPieceSoundsStaysBoundedAndEndsInSilence() {
        let pitches: [UInt8] = [36, 38, 39, 45, 50, 42, 46, 49]
        for pitch in pitches {
            var kit = DrumKit(sampleRate: rate)
            kit.noteOn(pitch: pitch, velocity: 127)
            let hit = render(&kit, seconds: 0.1)
            XCTAssertGreaterThan(peak(hit), 0.05, "pitch \(pitch)")
            XCTAssertLessThan(peak(hit), 2, "pitch \(pitch)")
            XCTAssertTrue(hit.allSatisfy(\.isFinite), "pitch \(pitch)")
            _ = render(&kit, seconds: 8)
            XCTAssertEqual(kit.activeVoiceCount, 0, "pitch \(pitch) never stopped")
        }
    }

    func testANoteOutsideTheKitIsSilent() {
        var kit = DrumKit(sampleRate: rate)
        kit.noteOn(pitch: 60, velocity: 127)
        kit.noteOn(pitch: 36, velocity: 0)
        XCTAssertEqual(peak(render(&kit, seconds: 0.05)), 0)
        XCTAssertEqual(kit.activeVoiceCount, 0)
    }

    func testVelocitySetsTheLevel() {
        var soft = DrumKit(sampleRate: rate), hard = DrumKit(sampleRate: rate)
        soft.noteOn(pitch: 36, velocity: 40)
        hard.noteOn(pitch: 36, velocity: 127)
        XCTAssertLessThan(peak(render(&soft, seconds: 0.1)), peak(render(&hard, seconds: 0.1)) * 0.5)
    }

    func testAClosedHatChokesTheOpenHat() {
        var kit = DrumKit(sampleRate: rate)
        kit.noteOn(pitch: 46, velocity: 127)
        _ = render(&kit, seconds: 0.02)
        kit.noteOn(pitch: 42, velocity: 127)
        _ = render(&kit, seconds: 0.4)
        XCTAssertEqual(kit.activeVoiceCount, 0, "both hats are done well before the open hat's own 2-second tail")
    }

    func testTheKitIsDeterministicAndNoteOffDoesNotCutAHit() {
        var a = DrumKit(sampleRate: rate), b = DrumKit(sampleRate: rate)
        a.noteOn(pitch: 38, velocity: 110)
        b.noteOn(pitch: 38, velocity: 110)
        b.noteOff(pitch: 38)
        b.allNotesOff()
        XCTAssertEqual(render(&a, seconds: 0.2), render(&b, seconds: 0.2))
    }

    /// A tom hit again while it still rings starts the new hit without a step in the waveform —
    /// a roll does not click on every hit — whatever point of its cycle the old hit stood at
    /// (audit 2026-10-23).
    func testAReHitOfARingingTomDoesNotClick() {
        for pitch: UInt8 in [45, 50] {
            var largest: Float = 0
            for gap in 100...150 {
                var kit = DrumKit(sampleRate: rate)
                kit.noteOn(pitch: pitch, velocity: 127)
                let before = render(&kit, seconds: Float(gap) / 1_000)
                kit.noteOn(pitch: pitch, velocity: 127)
                let after = render(&kit, seconds: 0.01)
                guard let last = before.last, let first = after.first else {
                    XCTFail("nothing rendered")
                    continue
                }
                largest = Swift.max(largest, Swift.abs(first - last))
            }
            XCTAssertLessThan(largest, 0.05, "pitch \(pitch)")
        }
    }

    func testABadSampleRateFallsBack() {
        var kit = DrumKit(sampleRate: .nan)
        kit.noteOn(pitch: 36, velocity: 100)
        XCTAssertTrue(render(&kit, seconds: 0.05).allSatisfy(\.isFinite))
    }

    // MARK: - The kit's sound (EchoelTools A11)

    private func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return (samples.reduce(0) { $0 + Double($1) * Double($1) } / Double(samples.count)).squareRoot()
    }

    private func hit(_ pitch: UInt8, seconds: Float = 1, velocity: UInt8 = 100, _ setup: (inout DrumKit) -> Void = { _ in }) -> [Float] {
        var kit = DrumKit(sampleRate: rate)
        setup(&kit)
        kit.noteOn(pitch: pitch, velocity: velocity)
        return render(&kit, seconds: seconds)
    }

    /// Upward zero crossings after the first 5 ms (the kick's noise click sits there).
    private func crossings(_ samples: [Float]) -> Int {
        let tail = Array(samples.dropFirst(240))
        return zip(tail, tail.dropFirst()).reduce(0) { $0 + ($1.0 < 0 && $1.1 >= 0 ? 1 : 0) }
    }

    /// Every piece at its defaults plays as the kit did before it had a sound to set: the RMS of a
    /// one-second hit at velocity 100, measured on the kit of 2026-11-03 (tolerant of the last
    /// digits a platform's `sinf`/`expf` may round differently). Old songs sound the same.
    func testTheDefaultsPlayTheKitAsItAlwaysSounded() {
        let measured: [(UInt8, Double)] = [(36, 0.140278), (38, 0.032937), (39, 0.018108), (45, 0.131201),
                                           (50, 0.116315), (42, 0.037054), (46, 0.109382), (49, 0.175231)]
        for (pitch, expected) in measured {
            XCTAssertEqual(rms(hit(pitch)), expected, accuracy: expected * 1e-3, "pitch \(pitch)")
            let set = hit(pitch) { kit in
                for piece in DrumKit.Piece.allCases { kit.setSound(DrumKit.PieceSound(), for: piece) }
                kit.setKickGlide(1)
                kit.setHatModel(.noise)
                kit.setTomModel(.sine)
            }
            XCTAssertEqual(set, hit(pitch), "the defaults set explicitly change nothing, pitch \(pitch)")
        }
    }

    func testTuneMovesAPiecesPitchAnOctavePerTwelveSemitones() {
        for pitch: UInt8 in [36, 45, 50] {
            let flat: (inout DrumKit) -> Void = { $0.setKickGlide(0) }
            let base = crossings(hit(pitch, seconds: 0.5, flat))
            let piece = DrumKit.Piece.forPitch(pitch) ?? .kick
            let up = crossings(hit(pitch, seconds: 0.5) { kit in
                flat(&kit)
                kit.setSound(DrumKit.PieceSound(tune: 12), for: piece)
            })
            XCTAssertEqual(Double(up) / Double(Swift.max(base, 1)), 2, accuracy: 0.15, "pitch \(pitch)")
        }
        // A noise piece moves its filter: a hat tuned down is darker — more crossings are gone.
        let open = crossings(hit(46, seconds: 0.2))
        let down = crossings(hit(46, seconds: 0.2) { $0.setSound(DrumKit.PieceSound(tune: -24), for: .openHat) })
        XCTAssertLessThan(down, open)
    }

    func testDecayAndLevelShapeEachPieceAlone() {
        let short = hit(46, seconds: 2) { $0.setSound(DrumKit.PieceSound(decay: 0.25), for: .openHat) }
        let long = hit(46, seconds: 2) { $0.setSound(DrumKit.PieceSound(decay: 3), for: .openHat) }
        XCTAssertGreaterThan(rms(Array(long[24_000...])), 10 * rms(Array(short[24_000...])), "a longer decay rings longer")
        let half = hit(38) { $0.setSound(DrumKit.PieceSound(level: 0.5), for: .snare) }
        XCTAssertEqual(rms(half), rms(hit(38)) * 0.5, accuracy: 1e-6)
        // Another piece's sound leaves the snare alone.
        XCTAssertEqual(hit(38) { $0.setSound(DrumKit.PieceSound(tune: 7, decay: 3, level: 0.1), for: .kick) }, hit(38))
        let silent = hit(36) { $0.setSound(DrumKit.PieceSound(level: 0), for: .kick) }
        XCTAssertEqual(peak(silent), 0)
    }

    func testANonFiniteOrOutOfRangeSoundPlaysSafely() {
        var kit = DrumKit(sampleRate: rate)
        kit.setSound(DrumKit.PieceSound(tune: .nan, decay: .infinity, level: -3), for: .kick)
        XCTAssertEqual(kit.sound(of: .kick), DrumKit.PieceSound(tune: 0, decay: 1, level: 0))
        kit.setSound(DrumKit.PieceSound(tune: 99, decay: 0, level: 9), for: .snare)
        XCTAssertEqual(kit.sound(of: .snare), DrumKit.PieceSound(tune: 24, decay: 0.1, level: 1))
        kit.setKickGlide(.nan)
        kit.noteOn(pitch: 36, velocity: 127)
        kit.noteOn(pitch: 38, velocity: 127)
        XCTAssertTrue(render(&kit, seconds: 0.5).allSatisfy(\.isFinite))
    }

    /// The kick's glide is how far its pitch falls: none is a flat sine, four the long 808 dive.
    func testTheKickGlideSetsHowFarThePitchFalls() {
        let flat = crossings(hit(36, seconds: 0.105) { $0.setKickGlide(0) })
        let classic = crossings(hit(36, seconds: 0.105))
        let dive = crossings(hit(36, seconds: 0.105) { $0.setKickGlide(4) })
        XCTAssertLessThan(flat, classic)
        XCTAssertLessThan(classic, dive)
        // With no glide the 100 ms after the click run at the kick's own 48 Hz: four or five cycles.
        XCTAssertTrue((4...5).contains(flat), "\(flat)")
    }

    func testTheMetalHatsSoundStayBoundedAndStillChoke() {
        for pitch: UInt8 in [42, 46] {
            let metal = hit(pitch) { $0.setHatModel(.metal) }
            XCTAssertNotEqual(metal, hit(pitch), "the model changes the sound")
            XCTAssertGreaterThan(peak(metal), 0.05, "pitch \(pitch)")
            XCTAssertLessThan(peak(metal), 1.5, "pitch \(pitch)")
            XCTAssertTrue(metal.allSatisfy(\.isFinite))
            // Within a factor of two of the noise hat's level: switching models does not jump.
            let ratio = rms(metal) / rms(hit(pitch))
            XCTAssertTrue((0.5...2).contains(ratio), "pitch \(pitch): \(ratio)")
            // Deterministic: the oscillators start from the same phase on every hit.
            XCTAssertEqual(metal, hit(pitch) { $0.setHatModel(.metal) })
        }
        var kit = DrumKit(sampleRate: rate)
        kit.setHatModel(.metal)
        kit.noteOn(pitch: 46, velocity: 127)
        _ = render(&kit, seconds: 0.02)
        kit.noteOn(pitch: 42, velocity: 127)
        _ = render(&kit, seconds: 0.4)
        XCTAssertEqual(kit.activeVoiceCount, 0, "the closed hat still chokes the open one")
    }

    func testTheModalTomsRingBoundedEndAndReHitWithoutAClick() {
        for pitch: UInt8 in [45, 50] {
            let modal = hit(pitch, velocity: 127) { $0.setTomModel(.modal) }
            XCTAssertNotEqual(modal, hit(pitch, velocity: 127))
            XCTAssertGreaterThan(peak(modal), 0.1, "pitch \(pitch)")
            XCTAssertLessThan(peak(modal), 1.5, "pitch \(pitch)")
            XCTAssertEqual(modal.first ?? 1, 0, accuracy: 0.05, "a struck mode starts from zero")
            var kit = DrumKit(sampleRate: rate)
            kit.setTomModel(.modal)
            kit.noteOn(pitch: pitch, velocity: 127)
            _ = render(&kit, seconds: 8)
            XCTAssertEqual(kit.activeVoiceCount, 0, "pitch \(pitch) never stopped")
            var largest: Float = 0
            for gap in stride(from: 100, through: 150, by: 5) {
                var roll = DrumKit(sampleRate: rate)
                roll.setTomModel(.modal)
                roll.noteOn(pitch: pitch, velocity: 127)
                let before = render(&roll, seconds: Float(gap) / 1_000)
                roll.noteOn(pitch: pitch, velocity: 127)
                let after = render(&roll, seconds: 0.01)
                if let last = before.last, let first = after.first { largest = Swift.max(largest, Swift.abs(first - last)) }
            }
            XCTAssertLessThan(largest, 0.05, "pitch \(pitch)")
        }
    }

    /// A sound set while a piece rings waits for its next hit: nothing steps inside a hit.
    func testASoundChangeWaitsForTheNextHit() {
        var a = DrumKit(sampleRate: rate), b = DrumKit(sampleRate: rate)
        a.noteOn(pitch: 50, velocity: 120)
        b.noteOn(pitch: 50, velocity: 120)
        b.setSound(DrumKit.PieceSound(tune: 12, decay: 0.2, level: 0.3), for: .highTom)
        b.setTomModel(.modal)
        XCTAssertEqual(render(&a, seconds: 0.3), render(&b, seconds: 0.3))
    }
}
