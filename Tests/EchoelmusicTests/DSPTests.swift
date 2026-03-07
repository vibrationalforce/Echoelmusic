#if canImport(AVFoundation)
// DSPTests.swift
// Echoelmusic — Phase 2 Test Coverage: DSP Engine Tests
//
// Tests for EchoelDDSP, EchoelCore (TheConsole, Garden, HeartSync, EchoelPunish, EchoelTime, EchoelMorph),
// CrossfadeCurve, and bio-reactive parameter mappings.

import XCTest
@testable import Echoelmusic

// MARK: - EchoelDDSP Tests

final class EchoelDDSPTests: XCTestCase {

    func testInitialization() {
        let ddsp = EchoelDDSP(harmonicCount: 32, noiseBandCount: 33, sampleRate: 48000, frameSize: 256)
        XCTAssertEqual(ddsp.harmonicCount, 32)
        XCTAssertEqual(ddsp.noiseBandCount, 33)
        XCTAssertEqual(ddsp.sampleRate, 48000)
        XCTAssertEqual(ddsp.frameSize, 256)
    }

    func testDefaultParameters() {
        let ddsp = EchoelDDSP()
        XCTAssertEqual(ddsp.harmonicCount, 64)
        XCTAssertEqual(ddsp.frequency, 220.0)
        XCTAssertEqual(ddsp.harmonicLevel, 0.8, accuracy: 0.01)
        XCTAssertEqual(ddsp.harmonicity, 0.7, accuracy: 0.01)
        XCTAssertEqual(ddsp.noiseLevel, 0.3, accuracy: 0.01)
        XCTAssertEqual(ddsp.amplitude, 0.8, accuracy: 0.01)
    }

    func testHarmonicAmplitudesCount() {
        let ddsp = EchoelDDSP(harmonicCount: 16)
        XCTAssertEqual(ddsp.harmonicAmplitudes.count, 16)
    }

    func testNoiseMagnitudesCount() {
        let ddsp = EchoelDDSP(noiseBandCount: 33)
        XCTAssertEqual(ddsp.noiseMagnitudes.count, 33)
    }

    func testNoiseColorCases() {
        let cases = EchoelDDSP.NoiseColor.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.white))
        XCTAssertTrue(cases.contains(.pink))
        XCTAssertTrue(cases.contains(.brown))
        XCTAssertTrue(cases.contains(.blue))
        XCTAssertTrue(cases.contains(.violet))
    }

    func testSpectralShapeCases() {
        let cases = EchoelDDSP.SpectralShape.allCases
        XCTAssertEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.natural))
        XCTAssertTrue(cases.contains(.bright))
        XCTAssertTrue(cases.contains(.dark))
        XCTAssertTrue(cases.contains(.formant))
        XCTAssertTrue(cases.contains(.metallic))
        XCTAssertTrue(cases.contains(.hollow))
        XCTAssertTrue(cases.contains(.bell))
        XCTAssertTrue(cases.contains(.flat))
    }

    func testEnvelopeCurveCases() {
        let cases = EchoelDDSP.EnvelopeCurve.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.linear))
        XCTAssertTrue(cases.contains(.exponential))
        XCTAssertTrue(cases.contains(.logarithmic))
    }

    func testFrequencyRange() {
        let ddsp = EchoelDDSP()
        ddsp.frequency = 440.0
        XCTAssertEqual(ddsp.frequency, 440.0)

        ddsp.frequency = 20.0
        XCTAssertEqual(ddsp.frequency, 20.0)

        ddsp.frequency = 20000.0
        XCTAssertEqual(ddsp.frequency, 20000.0)
    }

    func testADSRParameters() {
        let ddsp = EchoelDDSP()
        ddsp.attack = 0.05
        ddsp.decay = 0.2
        ddsp.sustain = 0.6
        ddsp.release = 0.5

        XCTAssertEqual(ddsp.attack, 0.05, accuracy: 0.001)
        XCTAssertEqual(ddsp.decay, 0.2, accuracy: 0.001)
        XCTAssertEqual(ddsp.sustain, 0.6, accuracy: 0.001)
        XCTAssertEqual(ddsp.release, 0.5, accuracy: 0.001)
    }

    func testVibratoParameters() {
        let ddsp = EchoelDDSP()
        ddsp.vibratoRate = 5.5
        ddsp.vibratoDepth = 0.3

        XCTAssertEqual(ddsp.vibratoRate, 5.5, accuracy: 0.01)
        XCTAssertEqual(ddsp.vibratoDepth, 0.3, accuracy: 0.01)
    }

    func testSpectralMorphing() {
        let ddsp = EchoelDDSP()
        XCTAssertNil(ddsp.morphTarget)
        XCTAssertEqual(ddsp.morphPosition, 0)

        ddsp.morphTarget = .metallic
        ddsp.morphPosition = 0.5
        XCTAssertEqual(ddsp.morphTarget, .metallic)
        XCTAssertEqual(ddsp.morphPosition, 0.5, accuracy: 0.01)
    }

    func testTimbreTransfer() {
        let ddsp = EchoelDDSP()
        XCTAssertNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 0)

        let profile: [Float] = Array(repeating: 0.5, count: 64)
        ddsp.timbreProfile = profile
        ddsp.timbreBlend = 0.7
        XCTAssertNotNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 0.7, accuracy: 0.01)
    }

    func testReverbParameters() {
        let ddsp = EchoelDDSP()
        XCTAssertEqual(ddsp.reverbMix, 0.0, accuracy: 0.001)
        ddsp.reverbMix = 0.4
        ddsp.reverbDecay = 2.5
        XCTAssertEqual(ddsp.reverbMix, 0.4, accuracy: 0.01)
        XCTAssertEqual(ddsp.reverbDecay, 2.5, accuracy: 0.01)
    }
}

// MARK: - EchoelCore Tests

final class EchoelCoreConstantsTests: XCTestCase {

    func testVersion() {
        XCTAssertFalse(EchoelCore.version.isEmpty)
    }

    func testDefaultSampleRate() {
        XCTAssertEqual(EchoelCore.defaultSampleRate, 48000)
    }

    func testIdentifier() {
        XCTAssertEqual(EchoelCore.identifier, "com.echoelmusic.core")
    }
}

// MARK: - TheConsole Tests

@MainActor
final class TheConsoleTests: XCTestCase {

    func testInitialization() {
        let console = EchoelWarmth.TheConsole()
        XCTAssertEqual(console.vibe, 50.0)
        XCTAssertEqual(console.legend, .neve)
        XCTAssertEqual(console.output, 50.0)
        XCTAssertEqual(console.blend, 100.0)
        XCTAssertFalse(console.bypassed)
    }

    func testBypassReturnsInput() {
        let console = EchoelWarmth.TheConsole()
        console.bypassed = true
        let input: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let output = console.process(input)
        XCTAssertEqual(output, input)
    }

    func testProcessDoesNotClip() {
        let console = EchoelWarmth.TheConsole()
        console.vibe = 100.0
        let input: [Float] = Array(repeating: 0.9, count: 256)

        for legend in EchoelWarmth.TheConsole.Legend.allCases {
            console.legend = legend
            let output = console.process(input)
            XCTAssertEqual(output.count, input.count, "Legend \(legend) changed output count")
            // Ensure no NaN or Inf
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(legend)")
                XCTAssertFalse(sample.isInfinite, "Inf in \(legend)")
            }
        }
    }

    func testAllLegends() {
        let allLegends = EchoelWarmth.TheConsole.Legend.allCases
        XCTAssertEqual(allLegends.count, 8)
        // Verify all have emoji and vibe strings
        for legend in allLegends {
            XCTAssertFalse(legend.emoji.isEmpty)
            XCTAssertFalse(legend.vibe.isEmpty)
        }
    }

    func testSilentInputProducesSilentOutput() {
        let console = EchoelWarmth.TheConsole()
        let input: [Float] = Array(repeating: 0.0, count: 128)
        let output = console.process(input)
        for sample in output {
            XCTAssertEqual(sample, 0.0, accuracy: 0.001)
        }
    }

    func testOutputCountMatchesInput() {
        let console = EchoelWarmth.TheConsole()
        for size in [1, 64, 256, 1024] {
            let input = [Float](repeating: 0.5, count: size)
            let output = console.process(input)
            XCTAssertEqual(output.count, size)
        }
    }
}

// MARK: - SoundDNA Tests

final class SoundDNATests: XCTestCase {

    func testRandomSeed() {
        let dna = EchoelSeed.SoundDNA.randomSeed()
        XCTAssertEqual(dna.genes.count, 16)
        XCTAssertEqual(dna.generation, 0)
        for gene in dna.genes {
            XCTAssertGreaterThanOrEqual(gene, 0)
            XCTAssertLessThanOrEqual(gene, 1)
        }
    }

    func testBreeding() {
        let parent1 = EchoelSeed.SoundDNA.randomSeed()
        let parent2 = EchoelSeed.SoundDNA.randomSeed()
        let child = parent1.breed(with: parent2)

        XCTAssertEqual(child.genes.count, 16)
        XCTAssertEqual(child.generation, 1)
        // Blended traits should be between parents
        XCTAssertEqual(child.attack, (parent1.attack + parent2.attack) / 2, accuracy: 0.01)
        XCTAssertEqual(child.decay, (parent1.decay + parent2.decay) / 2, accuracy: 0.01)
    }

    func testMultiGenerationBreeding() {
        var dna = EchoelSeed.SoundDNA.randomSeed()
        for gen in 1...5 {
            let partner = EchoelSeed.SoundDNA.randomSeed()
            dna = dna.breed(with: partner)
            XCTAssertEqual(dna.generation, gen)
        }
    }

    func testCodable() throws {
        let original = EchoelSeed.SoundDNA.randomSeed()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSeed.SoundDNA.self, from: encoded)
        XCTAssertEqual(original.genes, decoded.genes)
        XCTAssertEqual(original.generation, decoded.generation)
    }
}

// MARK: - Garden Tests

@MainActor
final class GardenTests: XCTestCase {

    func testInit() {
        let garden = EchoelSeed.Garden()
        XCTAssertEqual(garden.frequency, 440.0)
        XCTAssertEqual(garden.volume, 0.8, accuracy: 0.01)
        XCTAssertEqual(garden.dna.genes.count, 16)
    }

    func testPlantSeed() {
        let garden = EchoelSeed.Garden()
        let oldDNA = garden.dna
        garden.plantSeed()
        // DNA should change (probabilistically, genes differ)
        // Just verify it doesn't crash and genes count stays 16
        XCTAssertEqual(garden.dna.genes.count, 16)
        XCTAssertEqual(garden.dna.generation, 0)
    }

    func testMutate() {
        let garden = EchoelSeed.Garden()
        let initialGen = garden.dna.generation
        garden.mutate(chaos: 1.0) // 100% mutation
        XCTAssertEqual(garden.dna.generation, initialGen + 1)
    }

    func testGrowOutput() {
        let garden = EchoelSeed.Garden()
        garden.noteOn()
        let output = garden.grow(256)
        XCTAssertEqual(output.count, 256)
        // After noteOn, envelope should produce non-zero output
        let hasNonZero = output.contains { $0 != 0 }
        XCTAssertTrue(hasNonZero)
    }

    func testGrowSilentBeforeNoteOn() {
        let garden = EchoelSeed.Garden()
        let output = garden.grow(128)
        XCTAssertEqual(output.count, 128)
        // Before noteOn, envelope is 0
        for sample in output {
            XCTAssertEqual(sample, 0, accuracy: 0.001)
        }
    }

    func testNoNaNInOutput() {
        let garden = EchoelSeed.Garden()
        garden.noteOn()
        let output = garden.grow(1024)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }
}

// MARK: - HeartSync / EchoelPulse Tests

@MainActor
final class HeartSyncTests: XCTestCase {

    func testDefaultState() {
        let sync = EchoelPulse.HeartSync()
        XCTAssertEqual(sync.body.heartRate, 70.0)
        XCTAssertEqual(sync.body.coherence, 50.0)
    }

    func testSyncMapsParameters() {
        let sync = EchoelPulse.HeartSync()
        let body = EchoelPulse.BodyMusic(
            heartRate: 90.0,
            hrv: 60.0,
            coherence: 80.0,
            breathRate: 8.0,
            breathPhase: 0.5
        )
        sync.sync(with: body)

        // Filter should be brighter with higher HR
        XCTAssertGreaterThan(sync.filterCutoff, 500.0)
        // Reverb should increase with HRV
        XCTAssertGreaterThan(sync.reverbAmount, 0.1)
        // Warmth from coherence
        XCTAssertGreaterThan(sync.warmth, 0)
        // Delay from breathing
        XCTAssertGreaterThan(sync.delayTime, 200.0)
    }

    func testSyncEdgeCaseLowHR() {
        let sync = EchoelPulse.HeartSync()
        let body = EchoelPulse.BodyMusic(heartRate: 40.0, hrv: 10.0, coherence: 0.0, breathRate: 20.0, breathPhase: 0.0)
        sync.sync(with: body)
        XCTAssertGreaterThanOrEqual(sync.filterCutoff, 500.0)
        XCTAssertGreaterThanOrEqual(sync.reverbAmount, 0.1)
        XCTAssertGreaterThanOrEqual(sync.warmth, 0)
    }

    func testProcessOutput() {
        let sync = EchoelPulse.HeartSync()
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = sync.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testProcessWithHighCoherence() {
        let sync = EchoelPulse.HeartSync()
        sync.sync(with: EchoelPulse.BodyMusic(heartRate: 70, hrv: 50, coherence: 100, breathRate: 6, breathPhase: 0.5))
        let input: [Float] = [0.3, -0.3, 0.6, -0.6]
        let output = sync.process(input)
        XCTAssertEqual(output.count, 4)
        // With warmth applied, values should be softened (tanh)
        XCTAssertGreaterThan(sync.warmth, 0)
    }

    func testBodyMusicInit() {
        let body = EchoelPulse.BodyMusic()
        XCTAssertEqual(body.heartRate, 70.0)
        XCTAssertEqual(body.hrv, 50.0)
        XCTAssertEqual(body.coherence, 50.0)
        XCTAssertEqual(body.breathRate, 12.0)
        XCTAssertEqual(body.breathPhase, 0.0)
    }
}

// MARK: - EchoelPunish Tests

@MainActor
final class EchoelPunishTests: XCTestCase {

    func testInit() {
        let punish = EchoelVibe.EchoelPunish()
        XCTAssertEqual(punish.drive, 50.0)
        XCTAssertEqual(punish.flavor, .warm)
        XCTAssertFalse(punish.punish)
        XCTAssertEqual(punish.blend, 100.0)
    }

    func testAllFlavorsProcess() {
        let punish = EchoelVibe.EchoelPunish()
        punish.drive = 80.0
        let input: [Float] = [0.3, -0.5, 0.7, -0.2, 0.0, 1.0, -1.0]

        for flavor in EchoelVibe.SaturationFlavor.allCases {
            punish.flavor = flavor
            let output = punish.process(input)
            XCTAssertEqual(output.count, input.count, "Flavor \(flavor) changed output count")
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(flavor)")
                XCTAssertFalse(sample.isInfinite, "Inf in \(flavor)")
            }
        }
    }

    func testPunishButtonIncreasesDistortion() {
        let punish = EchoelVibe.EchoelPunish()
        punish.drive = 70.0
        punish.blend = 100.0
        let input: [Float] = [0.5, 0.5, 0.5, 0.5]

        punish.punish = false
        let normalOutput = punish.process(input)

        punish.punish = true
        let punishedOutput = punish.process(input)

        // Punished should differ from normal
        var differs = false
        for i in 0..<input.count {
            if abs(normalOutput[i] - punishedOutput[i]) > 0.001 {
                differs = true
                break
            }
        }
        XCTAssertTrue(differs, "Punish button should change output")
    }

    func testSaturationFlavorEmojis() {
        for flavor in EchoelVibe.SaturationFlavor.allCases {
            XCTAssertFalse(flavor.emoji.isEmpty)
        }
        XCTAssertEqual(EchoelVibe.SaturationFlavor.allCases.count, 5)
    }

    func testZeroDrive() {
        let punish = EchoelVibe.EchoelPunish()
        punish.drive = 0.0
        punish.blend = 100.0
        let input: [Float] = [0.3, -0.3]
        let output = punish.process(input)
        // With zero drive, output should be close to input
        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i], accuracy: 0.15)
        }
    }
}

// MARK: - EchoelTime (Delay) Tests

@MainActor
final class EchoelTimeTests: XCTestCase {

    func testInit() {
        let delay = EchoelVibe.EchoelTime()
        XCTAssertEqual(delay.time, 500.0)
        XCTAssertEqual(delay.feedback, 40.0)
        XCTAssertEqual(delay.style, .tape)
        XCTAssertEqual(delay.blend, 30.0)
    }

    func testProcessOutputSize() {
        let delay = EchoelVibe.EchoelTime()
        let input = [Float](repeating: 0.3, count: 512)
        let output = delay.process(input)
        XCTAssertEqual(output.count, 512)
    }

    func testAllStyles() {
        let delay = EchoelVibe.EchoelTime()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        for style in EchoelVibe.EchoStyle.allCases {
            delay.style = style
            let output = delay.process(input)
            XCTAssertEqual(output.count, input.count)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(style)")
                XCTAssertFalse(sample.isInfinite, "Inf in \(style)")
            }
        }
    }

    func testEchoStyleEmojis() {
        for style in EchoelVibe.EchoStyle.allCases {
            XCTAssertFalse(style.emoji.isEmpty)
        }
        XCTAssertEqual(EchoelVibe.EchoStyle.allCases.count, 5)
    }

    func testDrySignalAtZeroBlend() {
        let delay = EchoelVibe.EchoelTime()
        delay.blend = 0.0
        let input: [Float] = [0.5, -0.5, 0.3, -0.3]
        let output = delay.process(input)
        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i], accuracy: 0.001)
        }
    }
}

// MARK: - EchoelMorph Tests

@MainActor
final class EchoelMorphTests: XCTestCase {

    func testInit() {
        let morph = EchoelVibe.EchoelMorph()
        XCTAssertEqual(morph.pitch, 0.0)
        XCTAssertEqual(morph.formant, 0.0)
        XCTAssertFalse(morph.robot)
        XCTAssertEqual(morph.blend, 100.0)
    }

    func testProcessOutput() {
        let morph = EchoelVibe.EchoelMorph()
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = morph.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testRobotMode() {
        let morph = EchoelVibe.EchoelMorph()
        morph.robot = true
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = morph.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testPitchShift() {
        let morph = EchoelVibe.EchoelMorph()
        morph.pitch = 12.0 // One octave up
        let input: [Float] = (0..<256).map { sin(Float($0) * 0.1) }
        let output = morph.process(input)
        XCTAssertEqual(output.count, input.count)
    }
}

// MARK: - CrossfadeCurve Tests

final class CrossfadeCurveTests: XCTestCase {

    func testAllCurvesAtBoundaries() {
        for curve in CrossfadeCurve.allCases {
            // At position 0: fadeIn = 0, fadeOut = 1
            XCTAssertEqual(curve.fadeInGain(at: 0), 0.0, accuracy: 0.001, "\(curve) fadeIn at 0")
            XCTAssertEqual(curve.fadeOutGain(at: 0), 1.0, accuracy: 0.001, "\(curve) fadeOut at 0")

            // At position 1: fadeIn = 1, fadeOut = 0
            XCTAssertEqual(curve.fadeInGain(at: 1), 1.0, accuracy: 0.001, "\(curve) fadeIn at 1")
            XCTAssertEqual(curve.fadeOutGain(at: 1), 0.0, accuracy: 0.001, "\(curve) fadeOut at 1")
        }
    }

    func testEqualPowerConstantEnergy() {
        let curve = CrossfadeCurve.equalPower
        // At midpoint, sum of squares should be ~1 (constant power)
        let fadeIn = curve.fadeInGain(at: 0.5)
        let fadeOut = curve.fadeOutGain(at: 0.5)
        let sumOfSquares = fadeIn * fadeIn + fadeOut * fadeOut
        XCTAssertEqual(sumOfSquares, 1.0, accuracy: 0.01)
    }

    func testLinearMidpoint() {
        let curve = CrossfadeCurve.linear
        XCTAssertEqual(curve.fadeInGain(at: 0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.fadeOutGain(at: 0.5), 0.5, accuracy: 0.001)
    }

    func testSCurveSmoothMidpoint() {
        let curve = CrossfadeCurve.sCurve
        let mid = curve.fadeInGain(at: 0.5)
        XCTAssertEqual(mid, 0.5, accuracy: 0.001)
    }

    func testMonotonicity() {
        // Fade in should be monotonically increasing
        for curve in CrossfadeCurve.allCases {
            var prev: Float = -1
            for i in stride(from: 0.0, through: 1.0, by: 0.05) {
                let val = curve.fadeInGain(at: Float(i))
                XCTAssertGreaterThanOrEqual(val, prev - 0.001, "\(curve) fadeIn not monotonic at \(i)")
                prev = val
            }
        }
    }

    func testClampsBeyondRange() {
        let curve = CrossfadeCurve.linear
        // Positions outside [0, 1] should clamp
        XCTAssertEqual(curve.fadeInGain(at: -0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.fadeInGain(at: 1.5), 1.0, accuracy: 0.001)
    }

    func testAllCasesCount() {
        XCTAssertEqual(CrossfadeCurve.allCases.count, 6)
    }

    func testCodable() throws {
        let original = CrossfadeCurve.equalPower
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CrossfadeCurve.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CrossfadeRegion Tests

final class CrossfadeRegionTests: XCTestCase {

    func testDuration() {
        let region = CrossfadeRegion(
            id: UUID(),
            startSample: 0,
            lengthInSamples: 48000,
            curve: .equalPower,
            isSymmetric: true
        )
        XCTAssertEqual(region.duration(sampleRate: 48000.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(region.duration(sampleRate: 44100.0), 48000.0 / 44100.0, accuracy: 0.001)
    }
}
#endif
