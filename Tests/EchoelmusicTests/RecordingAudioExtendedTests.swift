#if canImport(AVFoundation)
import XCTest
@testable import Echoelmusic

// MARK: - BPMSituation Tests

final class BPMSituationTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(BPMSituation.allCases.count, 12)
    }

    func testIdentifiable() {
        for situation in BPMSituation.allCases {
            XCTAssertEqual(situation.id, situation.rawValue)
        }
    }

    func testBPMRangesValid() {
        for situation in BPMSituation.allCases {
            let range = situation.bpmRange
            XCTAssertGreaterThanOrEqual(range.lowerBound, 40, "\(situation) lower bound < 40")
            XCTAssertLessThanOrEqual(range.upperBound, 200, "\(situation) upper bound > 200")
            XCTAssertLessThan(range.lowerBound, range.upperBound, "\(situation) empty range")
        }
    }

    func testRecommendedBPMInRange() {
        for situation in BPMSituation.allCases {
            let recommended = situation.recommendedBPM
            let range = situation.bpmRange
            XCTAssertTrue(range.contains(recommended),
                          "\(situation) recommended \(recommended) not in \(range)")
        }
    }

    func testBioInfluenceInRange() {
        for situation in BPMSituation.allCases {
            let influence = situation.recommendedBioInfluence
            XCTAssertGreaterThanOrEqual(influence, 0, "\(situation)")
            XCTAssertLessThanOrEqual(influence, 1, "\(situation)")
        }
    }

    func testHumanizeInRange() {
        for situation in BPMSituation.allCases {
            let humanize = situation.recommendedHumanize
            XCTAssertGreaterThanOrEqual(humanize, 0, "\(situation)")
            XCTAssertLessThanOrEqual(humanize, 1, "\(situation)")
        }
    }

    func testGermanNames() {
        for situation in BPMSituation.allCases {
            XCTAssertFalse(situation.nameDE.isEmpty, "\(situation) missing German name")
        }
    }

    func testSpecificBPMRanges() {
        XCTAssertEqual(BPMSituation.deepMeditation.bpmRange, 40...60)
        XCTAssertEqual(BPMSituation.house.bpmRange, 118...130)
        XCTAssertEqual(BPMSituation.techno.bpmRange, 125...150)
        XCTAssertEqual(BPMSituation.hiit.bpmRange, 140...180)
        XCTAssertEqual(BPMSituation.freeform.bpmRange, 40...200)
    }

    func testSpecificRecommendedBPMs() {
        XCTAssertEqual(BPMSituation.deepMeditation.recommendedBPM, 50)
        XCTAssertEqual(BPMSituation.house.recommendedBPM, 124)
        XCTAssertEqual(BPMSituation.techno.recommendedBPM, 135)
        XCTAssertEqual(BPMSituation.freeform.recommendedBPM, 120)
    }
}

// MARK: - BPMTransitionMode Tests

final class BPMTransitionModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(BPMTransitionMode.allCases.count, 4)
    }

    func testDurationsIncreasing() {
        let durations = BPMTransitionMode.allCases.map(\.duration)
        for i in 1..<durations.count {
            XCTAssertGreaterThanOrEqual(durations[i], durations[i - 1])
        }
    }

    func testInstantDurationIsZero() {
        XCTAssertEqual(BPMTransitionMode.instant.duration, 0)
    }

    func testSmoothDuration() {
        XCTAssertEqual(BPMTransitionMode.smooth.duration, 0.5)
    }

    func testGradualDuration() {
        XCTAssertEqual(BPMTransitionMode.gradual.duration, 5.0)
    }
}

// MARK: - BPMLockState Tests

final class BPMLockStateTests: XCTestCase {

    func testDefaults() {
        let state = BPMLockState()
        XCTAssertFalse(state.isLocked)
        XCTAssertEqual(state.lockedBPM, 120)
        XCTAssertTrue(state.allowHumanize)
        XCTAssertEqual(state.maxFluctuation, 2.0)
    }

    func testMutability() {
        var state = BPMLockState()
        state.isLocked = true
        state.lockedBPM = 140
        state.allowHumanize = false
        state.maxFluctuation = 1.0
        XCTAssertTrue(state.isLocked)
        XCTAssertEqual(state.lockedBPM, 140)
        XCTAssertFalse(state.allowHumanize)
        XCTAssertEqual(state.maxFluctuation, 1.0)
    }
}

// MARK: - BPMSnapshot Tests

final class BPMSnapshotTests: XCTestCase {

    func testInit() {
        let snapshot = BPMSnapshot(
            currentBPM: 120,
            targetBPM: 130,
            bioInfluence: 0.5,
            humanize: 0.2,
            situation: .house,
            isLocked: false,
            isTransitioning: true
        )
        XCTAssertEqual(snapshot.currentBPM, 120)
        XCTAssertEqual(snapshot.targetBPM, 130)
        XCTAssertEqual(snapshot.bioInfluence, 0.5)
        XCTAssertEqual(snapshot.humanize, 0.2)
        XCTAssertEqual(snapshot.situation, .house)
        XCTAssertFalse(snapshot.isLocked)
        XCTAssertTrue(snapshot.isTransitioning)
    }
}

// MARK: - MetronomeSound Tests

final class MetronomeSoundTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(MetronomeSound.allCases.count, 7)
    }

    func testDownbeatFrequenciesPositive() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThan(sound.downbeatFrequency, 0, "\(sound)")
        }
    }

    func testUpbeatFrequenciesPositive() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThan(sound.upbeatFrequency, 0, "\(sound)")
        }
    }

    func testDownbeatHigherThanUpbeat() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThan(sound.downbeatFrequency, sound.upbeatFrequency,
                                 "\(sound) downbeat should be higher pitch than upbeat")
        }
    }

    func testCodable() throws {
        for sound in MetronomeSound.allCases {
            let data = try JSONEncoder().encode(sound)
            let decoded = try JSONDecoder().decode(MetronomeSound.self, from: data)
            XCTAssertEqual(decoded, sound)
        }
    }

    func testRawValues() {
        XCTAssertEqual(MetronomeSound.woodBlock.rawValue, "Wood Block")
        XCTAssertEqual(MetronomeSound.rimshot.rawValue, "Rimshot")
        XCTAssertEqual(MetronomeSound.cowbell.rawValue, "Cowbell")
    }
}

// MARK: - MetronomeSubdivision Tests

final class MetronomeSubdivisionTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(MetronomeSubdivision.allCases.count, 5)
    }

    func testClicksPerBeat() {
        XCTAssertEqual(MetronomeSubdivision.none.clicksPerBeat, 1)
        XCTAssertEqual(MetronomeSubdivision.eighth.clicksPerBeat, 2)
        XCTAssertEqual(MetronomeSubdivision.triplet.clicksPerBeat, 3)
        XCTAssertEqual(MetronomeSubdivision.sixteenth.clicksPerBeat, 4)
        XCTAssertEqual(MetronomeSubdivision.swing.clicksPerBeat, 2)
    }

    func testTimingRatiosCount() {
        for sub in MetronomeSubdivision.allCases {
            XCTAssertEqual(sub.timingRatios.count, sub.clicksPerBeat, "\(sub)")
        }
    }

    func testTimingRatiosStartAtZero() {
        for sub in MetronomeSubdivision.allCases {
            XCTAssertEqual(sub.timingRatios.first, 0.0, "\(sub) should start at 0")
        }
    }

    func testTimingRatiosInRange() {
        for sub in MetronomeSubdivision.allCases {
            for ratio in sub.timingRatios {
                XCTAssertGreaterThanOrEqual(ratio, 0.0, "\(sub)")
                XCTAssertLessThan(ratio, 1.0, "\(sub)")
            }
        }
    }

    func testTimingRatiosSorted() {
        for sub in MetronomeSubdivision.allCases {
            let ratios = sub.timingRatios
            for i in 1..<ratios.count {
                XCTAssertGreaterThan(ratios[i], ratios[i - 1], "\(sub) ratios not sorted")
            }
        }
    }

    func testSwingFeel() {
        let swing = MetronomeSubdivision.swing
        XCTAssertEqual(swing.timingRatios.count, 2)
        XCTAssertEqual(swing.timingRatios[0], 0.0)
        XCTAssertEqual(swing.timingRatios[1], 0.67, accuracy: 0.01)
    }

    func testCodable() throws {
        for sub in MetronomeSubdivision.allCases {
            let data = try JSONEncoder().encode(sub)
            let decoded = try JSONDecoder().decode(MetronomeSubdivision.self, from: data)
            XCTAssertEqual(decoded, sub)
        }
    }
}

// MARK: - CountInMode Tests

final class CountInModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(CountInMode.allCases.count, 4)
    }

    func testBars() {
        XCTAssertEqual(CountInMode.off.bars, 0)
        XCTAssertEqual(CountInMode.oneBar.bars, 1)
        XCTAssertEqual(CountInMode.twoBars.bars, 2)
        XCTAssertEqual(CountInMode.fourBars.bars, 4)
    }

    func testCodable() throws {
        for mode in CountInMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(CountInMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}

// MARK: - MetronomeConfiguration Tests

final class MetronomeConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = MetronomeConfiguration()
        XCTAssertEqual(config.sound, .click)
        XCTAssertEqual(config.subdivision, .none)
        XCTAssertEqual(config.countIn, .oneBar)
        XCTAssertEqual(config.volume, 0.7, accuracy: 0.001)
        XCTAssertTrue(config.accentDownbeat)
        XCTAssertFalse(config.muteDuringPlayback)
        XCTAssertTrue(config.flashOnBeat)
        XCTAssertTrue(config.hapticOnBeat)
        XCTAssertEqual(config.panPosition, 0.0)
    }

    func testCustomInit() {
        let config = MetronomeConfiguration(
            sound: .cowbell,
            subdivision: .triplet,
            countIn: .fourBars,
            volume: 0.5,
            accentDownbeat: false,
            muteDuringPlayback: true,
            flashOnBeat: false,
            hapticOnBeat: false,
            panPosition: -0.5
        )
        XCTAssertEqual(config.sound, .cowbell)
        XCTAssertEqual(config.subdivision, .triplet)
        XCTAssertEqual(config.countIn, .fourBars)
        XCTAssertEqual(config.volume, 0.5)
        XCTAssertFalse(config.accentDownbeat)
        XCTAssertTrue(config.muteDuringPlayback)
    }

    func testCodable() throws {
        let config = MetronomeConfiguration(sound: .rimshot, subdivision: .sixteenth)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MetronomeConfiguration.self, from: data)
        XCTAssertEqual(decoded.sound, .rimshot)
        XCTAssertEqual(decoded.subdivision, .sixteenth)
        XCTAssertEqual(decoded.volume, config.volume)
    }
}

// MARK: - MusicalNote Tests

final class MusicalNoteTests: XCTestCase {

    func testNoteNames() {
        XCTAssertEqual(MusicalNote.noteNames.count, 12)
        XCTAssertEqual(MusicalNote.noteNames.first, "C")
        XCTAssertEqual(MusicalNote.noteNames.last, "B")
    }

    func testA4FromFrequency() {
        let note = MusicalNote.fromFrequency(440.0)
        XCTAssertEqual(note.name, "A")
        XCTAssertEqual(note.octave, 4)
        XCTAssertEqual(note.midiNumber, 69)
        XCTAssertEqual(note.frequency, 440.0, accuracy: 0.01)
    }

    func testMiddleCFromFrequency() {
        let note = MusicalNote.fromFrequency(261.63)
        XCTAssertEqual(note.name, "C")
        XCTAssertEqual(note.octave, 4)
        XCTAssertEqual(note.midiNumber, 60)
    }

    func testA5FromFrequency() {
        let note = MusicalNote.fromFrequency(880.0)
        XCTAssertEqual(note.name, "A")
        XCTAssertEqual(note.octave, 5)
        XCTAssertEqual(note.midiNumber, 81)
    }

    func testZeroFrequency() {
        let note = MusicalNote.fromFrequency(0)
        XCTAssertEqual(note.name, "-")
        XCTAssertEqual(note.frequency, 0)
    }

    func testNegativeFrequency() {
        let note = MusicalNote.fromFrequency(-100)
        XCTAssertEqual(note.name, "-")
    }

    func testDisplayName() {
        let note = MusicalNote.fromFrequency(440.0)
        XCTAssertEqual(note.displayName, "A4")
    }

    func testCustomReference() {
        let note = MusicalNote.fromFrequency(432.0, referenceA4: 432.0)
        XCTAssertEqual(note.name, "A")
        XCTAssertEqual(note.octave, 4)
    }

    func testEquatable() {
        let a = MusicalNote.fromFrequency(440.0)
        let b = MusicalNote.fromFrequency(440.0)
        XCTAssertEqual(a, b)
    }
}

// MARK: - TuningReference Tests

final class TuningReferenceTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(TuningReference.allCases.count, 7)
    }

    func testStandard440() {
        XCTAssertEqual(TuningReference.standard440.a4Frequency, 440.0)
    }

    func testBaroque415() {
        XCTAssertEqual(TuningReference.baroque415.a4Frequency, 415.0)
    }

    func testVerdi432() {
        XCTAssertEqual(TuningReference.verdi432.a4Frequency, 432.0)
    }

    func testAllFrequenciesPositive() {
        for ref in TuningReference.allCases {
            XCTAssertGreaterThan(ref.a4Frequency, 0, "\(ref)")
        }
    }

    func testAllFrequenciesInReasonableRange() {
        for ref in TuningReference.allCases {
            XCTAssertGreaterThan(ref.a4Frequency, 400, "\(ref)")
            XCTAssertLessThan(ref.a4Frequency, 450, "\(ref)")
        }
    }

    func testCodable() throws {
        for ref in TuningReference.allCases {
            let data = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(TuningReference.self, from: data)
            XCTAssertEqual(decoded, ref)
        }
    }
}

// MARK: - TunerReading Tests

final class TunerReadingTests: XCTestCase {

    func testInTuneWithinThreshold() {
        let reading = TunerReading(frequency: 440.0, note: .fromFrequency(440.0),
                                    centsOffset: 3.0, confidence: 0.8, amplitude: 0.5)
        XCTAssertTrue(reading.isInTune())
    }

    func testOutOfTune() {
        let reading = TunerReading(frequency: 445.0, note: .fromFrequency(445.0),
                                    centsOffset: 20.0, confidence: 0.8, amplitude: 0.5)
        XCTAssertFalse(reading.isInTune())
    }

    func testLowConfidence() {
        let reading = TunerReading(frequency: 440.0, note: .fromFrequency(440.0),
                                    centsOffset: 1.0, confidence: 0.3, amplitude: 0.5)
        XCTAssertFalse(reading.isInTune())
    }

    func testCustomThreshold() {
        let reading = TunerReading(frequency: 440.0, note: .fromFrequency(440.0),
                                    centsOffset: 8.0, confidence: 0.8, amplitude: 0.5)
        XCTAssertFalse(reading.isInTune(threshold: 5.0))
        XCTAssertTrue(reading.isInTune(threshold: 10.0))
    }
}

// MARK: - CrossfadeCurve Tests

final class CrossfadeCurveTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(CrossfadeCurve.allCases.count, 6)
    }

    func testFadeInStartsAtZero() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeInGain(at: 0.0), 0.0, accuracy: 0.001, "\(curve)")
        }
    }

    func testFadeInEndsAtOne() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeInGain(at: 1.0), 1.0, accuracy: 0.001, "\(curve)")
        }
    }

    func testFadeOutStartsAtOne() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeOutGain(at: 0.0), 1.0, accuracy: 0.001, "\(curve)")
        }
    }

    func testFadeOutEndsAtZero() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeOutGain(at: 1.0), 0.0, accuracy: 0.001, "\(curve)")
        }
    }

    func testMonotonicity() {
        // Fade-in should be monotonically non-decreasing
        for curve in CrossfadeCurve.allCases {
            var prev: Float = -1
            for i in 0...10 {
                let t = Float(i) / 10.0
                let gain = curve.fadeInGain(at: t)
                XCTAssertGreaterThanOrEqual(gain, prev, "\(curve) at \(t)")
                prev = gain
            }
        }
    }

    func testEqualPowerCrosspoint() {
        // At midpoint, equal power should preserve total energy
        let curve = CrossfadeCurve.equalPower
        let fadeIn = curve.fadeInGain(at: 0.5)
        let fadeOut = curve.fadeOutGain(at: 0.5)
        // Equal power: sin²(θ) + cos²(θ) = 1
        let totalPower = fadeIn * fadeIn + fadeOut * fadeOut
        XCTAssertEqual(totalPower, 1.0, accuracy: 0.01)
    }

    func testClampingBelowZero() {
        for curve in CrossfadeCurve.allCases {
            let gain = curve.fadeInGain(at: -0.5)
            XCTAssertEqual(gain, 0.0, accuracy: 0.001, "\(curve) should clamp negative input")
        }
    }

    func testClampingAboveOne() {
        for curve in CrossfadeCurve.allCases {
            let gain = curve.fadeInGain(at: 1.5)
            XCTAssertEqual(gain, 1.0, accuracy: 0.001, "\(curve) should clamp input > 1")
        }
    }

    func testCodable() throws {
        for curve in CrossfadeCurve.allCases {
            let data = try JSONEncoder().encode(curve)
            let decoded = try JSONDecoder().decode(CrossfadeCurve.self, from: data)
            XCTAssertEqual(decoded, curve)
        }
    }
}

// MARK: - CrossfadeRegion Tests

final class CrossfadeRegionTests: XCTestCase {

    func testInit() {
        let region = CrossfadeRegion(startSample: 1000, lengthInSamples: 4800)
        XCTAssertEqual(region.startSample, 1000)
        XCTAssertEqual(region.lengthInSamples, 4800)
        XCTAssertEqual(region.curve, .equalPower) // default
        XCTAssertTrue(region.isSymmetric) // default
    }

    func testDuration() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 48000)
        XCTAssertEqual(region.duration(sampleRate: 48000), 1.0, accuracy: 0.001)
    }

    func testDurationAtDifferentSampleRate() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 44100)
        XCTAssertEqual(region.duration(sampleRate: 44100), 1.0, accuracy: 0.001)
    }

    func testCustomCurve() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 1000,
                                     curve: .sCurve, isSymmetric: false)
        XCTAssertEqual(region.curve, .sCurve)
        XCTAssertFalse(region.isSymmetric)
    }

    func testCodable() throws {
        let region = CrossfadeRegion(startSample: 500, lengthInSamples: 2000,
                                     curve: .logarithmic, isSymmetric: false)
        let data = try JSONEncoder().encode(region)
        let decoded = try JSONDecoder().decode(CrossfadeRegion.self, from: data)
        XCTAssertEqual(decoded.startSample, 500)
        XCTAssertEqual(decoded.lengthInSamples, 2000)
        XCTAssertEqual(decoded.curve, .logarithmic)
        XCTAssertFalse(decoded.isSymmetric)
    }

    func testIdentifiable() {
        let a = CrossfadeRegion(startSample: 0, lengthInSamples: 100)
        let b = CrossfadeRegion(startSample: 0, lengthInSamples: 100)
        XCTAssertNotEqual(a.id, b.id) // Unique UUIDs
    }
}

// MARK: - CrossfadeEngine Tests

final class CrossfadeEngineTests: XCTestCase {

    func testInit() {
        let engine = CrossfadeEngine(sampleRate: 48000)
        XCTAssertNotNil(engine)
    }

    func testDefaultSampleRate() {
        let engine = CrossfadeEngine()
        XCTAssertNotNil(engine)
    }

    func testMillisecondsToSamples() {
        let engine = CrossfadeEngine(sampleRate: 48000)
        XCTAssertEqual(engine.millisecondsToSamples(1000), 48000)
        XCTAssertEqual(engine.millisecondsToSamples(500), 24000)
        XCTAssertEqual(engine.millisecondsToSamples(0), 0)
    }

    func testSamplesToMilliseconds() {
        let engine = CrossfadeEngine(sampleRate: 48000)
        XCTAssertEqual(engine.samplesToMilliseconds(48000), 1000.0, accuracy: 0.001)
        XCTAssertEqual(engine.samplesToMilliseconds(24000), 500.0, accuracy: 0.001)
    }

    func testGenerateGainTable() {
        let engine = CrossfadeEngine()
        let (fadeIn, fadeOut) = engine.generateGainTable(length: 100, curve: .linear)
        XCTAssertEqual(fadeIn.count, 100)
        XCTAssertEqual(fadeOut.count, 100)
        XCTAssertEqual(fadeIn.first!, 0.0, accuracy: 0.01)
        XCTAssertEqual(fadeOut.first!, 1.0, accuracy: 0.01)
    }

    func testGenerateGainTableAllCurves() {
        let engine = CrossfadeEngine()
        for curve in CrossfadeCurve.allCases {
            let (fadeIn, fadeOut) = engine.generateGainTable(length: 50, curve: curve)
            XCTAssertEqual(fadeIn.count, 50, "\(curve)")
            XCTAssertEqual(fadeOut.count, 50, "\(curve)")
        }
    }
}

// MARK: - EqualPowerPan Tests

final class EqualPowerPanTests: XCTestCase {

    func testCenterPan() {
        let (gainL, gainR) = equalPowerPan(pan: 0.0, volume: 1.0)
        XCTAssertEqual(gainL, gainR, accuracy: 0.001)
        // At center: each should be ~0.707 (-3dB)
        XCTAssertEqual(gainL, 0.707, accuracy: 0.01)
    }

    func testHardLeft() {
        let (gainL, gainR) = equalPowerPan(pan: -1.0, volume: 1.0)
        XCTAssertEqual(gainL, 1.0, accuracy: 0.001)
        XCTAssertEqual(gainR, 0.0, accuracy: 0.001)
    }

    func testHardRight() {
        let (gainL, gainR) = equalPowerPan(pan: 1.0, volume: 1.0)
        XCTAssertEqual(gainL, 0.0, accuracy: 0.001)
        XCTAssertEqual(gainR, 1.0, accuracy: 0.001)
    }

    func testVolumeScaling() {
        let (gainL, gainR) = equalPowerPan(pan: 0.0, volume: 0.5)
        let (fullL, fullR) = equalPowerPan(pan: 0.0, volume: 1.0)
        XCTAssertEqual(gainL, fullL * 0.5, accuracy: 0.001)
        XCTAssertEqual(gainR, fullR * 0.5, accuracy: 0.001)
    }

    func testZeroVolume() {
        let (gainL, gainR) = equalPowerPan(pan: 0.5, volume: 0.0)
        XCTAssertEqual(gainL, 0.0, accuracy: 0.001)
        XCTAssertEqual(gainR, 0.0, accuracy: 0.001)
    }

    func testEnergyConservation() {
        // Total power should be constant across pan positions
        for panInt in stride(from: -10, through: 10, by: 1) {
            let pan = Float(panInt) / 10.0
            let (gainL, gainR) = equalPowerPan(pan: pan, volume: 1.0)
            let totalPower = gainL * gainL + gainR * gainR
            XCTAssertEqual(totalPower, 1.0, accuracy: 0.01, "pan=\(pan)")
        }
    }
}

// MARK: - TrackFreezeState Tests

final class TrackFreezeStateTests: XCTestCase {

    func testAllStates() {
        let states: [TrackFreezeState] = [.unfrozen, .freezing, .frozen, .unfreezing]
        XCTAssertEqual(states.count, 4)
    }

    func testCodable() throws {
        for state in [TrackFreezeState.unfrozen, .freezing, .frozen, .unfreezing] {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TrackFreezeState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testRawValues() {
        XCTAssertEqual(TrackFreezeState.unfrozen.rawValue, "unfrozen")
        XCTAssertEqual(TrackFreezeState.frozen.rawValue, "frozen")
        XCTAssertEqual(TrackFreezeState.freezing.rawValue, "freezing")
        XCTAssertEqual(TrackFreezeState.unfreezing.rawValue, "unfreezing")
    }
}

// MARK: - FreezeConfiguration Tests

final class FreezeConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = FreezeConfiguration()
        XCTAssertEqual(config.sampleRate, 48000)
        XCTAssertEqual(config.bitDepth, 24)
        XCTAssertFalse(config.includeSends)
        XCTAssertTrue(config.includeAutomation)
        XCTAssertEqual(config.tailLength, 2.0)
        XCTAssertFalse(config.normalize)
    }

    func testCustomInit() {
        let config = FreezeConfiguration(
            sampleRate: 96000,
            bitDepth: 32,
            includeSends: true,
            includeAutomation: false,
            tailLength: 5.0,
            normalize: true
        )
        XCTAssertEqual(config.sampleRate, 96000)
        XCTAssertEqual(config.bitDepth, 32)
        XCTAssertTrue(config.includeSends)
        XCTAssertFalse(config.includeAutomation)
        XCTAssertEqual(config.tailLength, 5.0)
        XCTAssertTrue(config.normalize)
    }

    func testCodable() throws {
        let config = FreezeConfiguration(sampleRate: 96000, bitDepth: 32, normalize: true)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FreezeConfiguration.self, from: data)
        XCTAssertEqual(decoded.sampleRate, config.sampleRate)
        XCTAssertEqual(decoded.bitDepth, config.bitDepth)
        XCTAssertEqual(decoded.normalize, config.normalize)
    }
}

// MARK: - FreezeError Tests

final class FreezeErrorTests: XCTestCase {

    func testErrorDescriptions() {
        let errors: [FreezeError] = [
            .trackNotFound,
            .noAudioToFreeze,
            .renderingFailed("test"),
            .fileWriteFailed,
            .alreadyFrozen,
            .notFrozen
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error)")
        }
    }

    func testRenderingFailedIncludesReason() {
        let error = FreezeError.renderingFailed("buffer overflow")
        XCTAssertTrue(error.errorDescription!.contains("buffer overflow"))
    }
}

#endif
