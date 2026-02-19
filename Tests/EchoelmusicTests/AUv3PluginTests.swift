import XCTest
@testable import Echoelmusic

// NOTE: These tests verify the AUv3 kernel architecture and DSP algorithms.
// The actual AUv3 Audio Unit classes (EchoelmusicAudioUnit, etc.) are in the
// EchoelmusicAUv3 target and require AudioToolbox, so they cannot be tested
// via SPM. These tests exercise the underlying DSP algorithms and types that
// ARE available in the main Echoelmusic target.

/// AUv3 Architecture Tests — verifies plugin infrastructure integrity
final class AUv3PluginTests: XCTestCase {

    // MARK: - EchoelCore TheConsole Tests (analog emulations)

    @MainActor
    func testTheConsoleInitialization() {
        let console = EchoelWarmth.TheConsole()
        XCTAssertEqual(console.vibe, 50.0, "Default vibe should be 50")
        XCTAssertEqual(console.output, 50.0, "Default output should be 50")
        XCTAssertEqual(console.blend, 100.0, "Default blend should be 100")
        XCTAssertFalse(console.bypassed, "Console should not be bypassed by default")
    }

    @MainActor
    func testTheConsoleAllLegends() {
        let console = EchoelWarmth.TheConsole()
        let input: [Float] = [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, -0.3, -0.7]

        for legend in EchoelWarmth.TheConsole.Legend.allCases {
            console.legend = legend
            console.vibe = 50.0

            let output = console.process(input)
            XCTAssertEqual(output.count, input.count,
                           "\(legend.rawValue): Output count should match input count")

            // Verify no NaN or Inf values
            for (i, sample) in output.enumerated() {
                XCTAssertFalse(sample.isNaN, "\(legend.rawValue) produced NaN at sample \(i)")
                XCTAssertFalse(sample.isInfinite, "\(legend.rawValue) produced Inf at sample \(i)")
            }
        }
    }

    @MainActor
    func testTheConsoleSaturationIsNonLinear() {
        let console = EchoelWarmth.TheConsole()
        console.legend = .neve
        console.vibe = 80.0

        let input: [Float] = [0.5]
        let output = console.process(input)

        // Neve saturation should change the signal (not pass through unchanged)
        XCTAssertNotEqual(output[0], input[0],
                          "Neve saturation at vibe=80 should modify the signal")
    }

    @MainActor
    func testTheConsoleBypass() {
        let console = EchoelWarmth.TheConsole()
        console.bypassed = true

        let input: [Float] = [0.1, 0.5, -0.3]
        let output = console.process(input)

        XCTAssertEqual(output, input, "Bypassed console should pass through unchanged")
    }

    @MainActor
    func testTheConsoleSilenceInSilenceOut() {
        let console = EchoelWarmth.TheConsole()
        let silence: [Float] = [0.0, 0.0, 0.0, 0.0]

        for legend in EchoelWarmth.TheConsole.Legend.allCases {
            console.legend = legend
            let output = console.process(silence)
            for sample in output {
                XCTAssertEqual(sample, 0.0, accuracy: 1e-10,
                               "\(legend.rawValue): Silence in should produce silence out")
            }
        }
    }

    @MainActor
    func testTheConsoleVibeRange() {
        let console = EchoelWarmth.TheConsole()
        console.legend = .ssl
        let input: [Float] = [0.5]

        // Low vibe = subtle
        console.vibe = 10.0
        let lowOutput = console.process(input)[0]

        // High vibe = aggressive
        console.vibe = 90.0
        let highOutput = console.process(input)[0]

        // Higher vibe should result in more processing (different output)
        XCTAssertNotEqual(lowOutput, highOutput,
                          "Different vibe levels should produce different outputs")
    }

    // MARK: - EchoelSeed Tests (genetic sound evolution)

    @MainActor
    func testSoundDNARandomSeed() {
        let dna = EchoelSeed.SoundDNA.randomSeed()
        XCTAssertEqual(dna.genes.count, 16, "DNA should have 16 genes")
        XCTAssertEqual(dna.generation, 0, "Random seed should be generation 0")
    }

    @MainActor
    func testSoundDNABreeding() {
        let parent1 = EchoelSeed.SoundDNA.randomSeed()
        let parent2 = EchoelSeed.SoundDNA.randomSeed()
        let child = parent1.breed(with: parent2)

        XCTAssertEqual(child.genes.count, 16, "Child should have 16 genes")
        XCTAssertEqual(child.generation, 1, "Child should be generation 1")
    }

    @MainActor
    func testGardenAudioGeneration() {
        let garden = EchoelSeed.Garden()
        garden.frequency = 440.0
        garden.noteOn()

        let output = garden.grow(1024)
        XCTAssertEqual(output.count, 1024, "Output should have 1024 frames")

        // Should produce non-zero audio after noteOn
        let hasSignal = output.contains { $0 != 0.0 }
        XCTAssertTrue(hasSignal, "Garden should produce audio after noteOn")
    }

    // MARK: - EchoelPulse Tests (bio-reactive audio)

    @MainActor
    func testHeartSyncMapping() {
        let heartSync = EchoelPulse.HeartSync()
        let body = EchoelPulse.BodyMusic(
            heartRate: 80.0,
            hrv: 60.0,
            coherence: 75.0,
            breathRate: 12.0,
            breathPhase: 0.5
        )

        heartSync.sync(with: body)

        // Filter cutoff should increase with heart rate
        XCTAssertGreaterThan(heartSync.filterCutoff, 500.0,
                             "Filter cutoff should be above minimum at HR=80")
        // Reverb should increase with HRV
        XCTAssertGreaterThan(heartSync.reverbAmount, 0.1,
                             "Reverb should be above minimum at HRV=60")
        // Warmth should increase with coherence
        XCTAssertGreaterThan(heartSync.warmth, 0.0,
                             "Warmth should be above 0 at coherence=75")
    }

    @MainActor
    func testHeartSyncProcessing() {
        let heartSync = EchoelPulse.HeartSync()
        heartSync.sync(with: EchoelPulse.BodyMusic(
            heartRate: 70, hrv: 50, coherence: 80, breathRate: 12, breathPhase: 0.5
        ))

        let input: [Float] = [0.5, -0.5, 0.3, -0.3]
        let output = heartSync.process(input)

        XCTAssertEqual(output.count, input.count)
        // With coherence=80, warmth should modify the signal
        XCTAssertNotEqual(output[0], input[0],
                          "HeartSync processing should modify signal with warmth > 0")
    }

    // MARK: - EchoelVibe Tests (creative effects)

    @MainActor
    func testEchoelPunishSaturation() {
        let punish = EchoelVibe.EchoelPunish()
        punish.drive = 70.0
        punish.flavor = .aggressive

        let input: [Float] = [0.5, -0.5, 0.8, -0.8]
        let output = punish.process(input)

        XCTAssertEqual(output.count, input.count)
        // Aggressive saturation should compress peaks
        XCTAssertLessThan(abs(output[2]), abs(input[2]),
                          "Aggressive saturation should compress 0.8 peak")
    }

    @MainActor
    func testEchoelPunishAllFlavors() {
        let punish = EchoelVibe.EchoelPunish()
        punish.drive = 50.0
        let input: [Float] = [0.3, 0.5, 0.7]

        for flavor in EchoelVibe.SaturationFlavor.allCases {
            punish.flavor = flavor
            let output = punish.process(input)
            XCTAssertEqual(output.count, input.count)

            for sample in output {
                XCTAssertFalse(sample.isNaN, "\(flavor.rawValue) produced NaN")
                XCTAssertFalse(sample.isInfinite, "\(flavor.rawValue) produced Inf")
            }
        }
    }

    @MainActor
    func testEchoelTimDelay() {
        let echoelTime = EchoelVibe.EchoelTime()
        echoelTime.time = 100.0    // 100ms
        echoelTime.feedback = 30.0
        echoelTime.blend = 50.0

        // First, process an impulse
        var impulse = [Float](repeating: 0, count: 4800) // 100ms at 48kHz
        impulse[0] = 1.0
        let output = echoelTime.process(impulse)

        XCTAssertEqual(output.count, impulse.count)
        // At blend=50%, the dry signal at frame 0 should be attenuated
        XCTAssertLessThan(abs(output[0]), 1.0,
                          "Dry signal should be attenuated at 50% blend")
    }

    @MainActor
    func testEchoelMorphPitchShift() {
        let morph = EchoelVibe.EchoelMorph()
        morph.pitch = 12.0  // +1 octave
        morph.blend = 100.0

        let input: [Float] = Array(0..<256).map { Float(sin(Double($0) * 0.1)) }
        let output = morph.process(input)

        XCTAssertEqual(output.count, input.count)
        // With pitch shift active, output should differ from input
        XCTAssertNotEqual(output[128], input[128],
                          "Pitch shifted output should differ from input")
    }

    // MARK: - Binaural Beat Generator Tests

    @MainActor
    func testBinauralBeatGeneratorInitialization() {
        let generator = BinauralBeatGenerator()
        XCTAssertEqual(generator.carrierFrequency, 432.0, "Default carrier should be 432 Hz")
        XCTAssertEqual(generator.beatFrequency, 10.0, "Default beat should be 10 Hz (Alpha)")
        XCTAssertFalse(generator.isPlaying, "Should not be playing initially")
    }

    @MainActor
    func testBinauralBeatConfiguration() {
        let generator = BinauralBeatGenerator()
        generator.configure(carrier: 440.0, beat: 6.0, amplitude: 0.5)

        XCTAssertEqual(generator.carrierFrequency, 440.0)
        XCTAssertEqual(generator.beatFrequency, 6.0)
    }

    @MainActor
    func testBinauralBeatBrainwavePresets() {
        let generator = BinauralBeatGenerator()

        generator.configure(state: .delta)
        XCTAssertEqual(generator.beatFrequency, 2.0, "Delta should be 2 Hz")

        generator.configure(state: .theta)
        XCTAssertEqual(generator.beatFrequency, 6.0, "Theta should be 6 Hz")

        generator.configure(state: .alpha)
        XCTAssertEqual(generator.beatFrequency, 10.0, "Alpha should be 10 Hz")

        generator.configure(state: .beta)
        XCTAssertEqual(generator.beatFrequency, 20.0, "Beta should be 20 Hz")

        generator.configure(state: .gamma)
        XCTAssertEqual(generator.beatFrequency, 40.0, "Gamma should be 40 Hz")
    }

    @MainActor
    func testBinauralBeatHRVMapping() {
        let generator = BinauralBeatGenerator()

        generator.setBeatFrequencyFromHRV(coherence: 20)
        XCTAssertEqual(generator.beatFrequency, 10.0, "Low coherence → Alpha (10 Hz)")

        generator.setBeatFrequencyFromHRV(coherence: 50)
        XCTAssertEqual(generator.beatFrequency, 15.0, "Medium coherence → 15 Hz")

        generator.setBeatFrequencyFromHRV(coherence: 80)
        XCTAssertEqual(generator.beatFrequency, 20.0, "High coherence → Beta (20 Hz)")
    }

    // MARK: - Plugin Identity Tests

    func testEchoelCoreVersion() {
        XCTAssertFalse(EchoelCore.version.isEmpty, "EchoelCore version should not be empty")
        XCTAssertFalse(EchoelCore.identifier.isEmpty, "EchoelCore identifier should not be empty")
    }
}
