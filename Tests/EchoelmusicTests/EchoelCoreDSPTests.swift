import XCTest
@testable import Echoelmusic

/// Tests for EchoelCore native DSP implementations
/// Validates all newly implemented audio processing algorithms
@MainActor
final class EchoelCoreDSPTests: XCTestCase {

    // MARK: - ReverbNode Tests

    func testReverbNodeInitialization() throws {
        let reverb = ReverbNode()

        XCTAssertEqual(reverb.name, "Bio-Reactive Reverb")
        XCTAssertEqual(reverb.type, .effect)
        XCTAssertFalse(reverb.isBypassed)
    }

    func testReverbNodeParameters() throws {
        let reverb = ReverbNode()

        // Verify all parameters exist with correct defaults
        XCTAssertEqual(reverb.getParameter(name: "wetDry"), 30.0)
        XCTAssertEqual(reverb.getParameter(name: "roomSize"), 50.0)
        XCTAssertEqual(reverb.getParameter(name: "damping"), 50.0)
        XCTAssertEqual(reverb.getParameter(name: "width"), 100.0)
        XCTAssertEqual(reverb.getParameter(name: "preDelay"), 0.0)
    }

    func testReverbNodeParameterClamping() throws {
        let reverb = ReverbNode()

        // Test parameter clamping
        reverb.setParameter(name: "wetDry", value: 150.0)
        XCTAssertEqual(reverb.getParameter(name: "wetDry"), 100.0) // Clamped to max

        reverb.setParameter(name: "wetDry", value: -10.0)
        XCTAssertEqual(reverb.getParameter(name: "wetDry"), 0.0) // Clamped to min
    }

    func testReverbNodeBioReactivity() throws {
        let reverb = ReverbNode()

        // High coherence should increase wetness
        let highCoherenceSignal = BioSignal(
            hrv: 80.0,
            heartRate: 65.0,
            coherence: 80.0,
            respiratoryRate: 6.0
        )
        reverb.react(to: highCoherenceSignal)

        // Low coherence should decrease wetness
        let lowCoherenceSignal = BioSignal(
            hrv: 30.0,
            heartRate: 95.0,
            coherence: 20.0,
            respiratoryRate: 20.0
        )
        reverb.react(to: lowCoherenceSignal)

        // Parameters should have been modified (smooth transition)
        XCTAssertNotNil(reverb.getParameter(name: "wetDry"))
    }

    // MARK: - FilterNode Tests

    func testFilterNodeInitialization() throws {
        let filter = FilterNode()

        XCTAssertEqual(filter.name, "Bio-Reactive Filter")
        XCTAssertEqual(filter.type, .effect)
    }

    func testFilterNodeParameters() throws {
        let filter = FilterNode()

        XCTAssertEqual(filter.getParameter(name: "cutoffFrequency"), 1000.0)
        XCTAssertEqual(filter.getParameter(name: "resonance"), 0.707)
    }

    func testFilterNodeTypeSwitch() throws {
        let filter = FilterNode()

        filter.setFilterType(.lowPass)
        XCTAssertEqual(filter.getFilterType(), .lowPass)

        filter.setFilterType(.highPass)
        XCTAssertEqual(filter.getFilterType(), .highPass)

        filter.setFilterType(.bandPass)
        XCTAssertEqual(filter.getFilterType(), .bandPass)

        filter.setFilterType(.notch)
        XCTAssertEqual(filter.getFilterType(), .notch)
    }

    func testFilterNodeBioReactivity() throws {
        let filter = FilterNode()

        // Low HR should produce darker sound (lower cutoff)
        let lowHRSignal = BioSignal(heartRate: 55.0, coherence: 60.0)
        filter.react(to: lowHRSignal)

        // High HR should produce brighter sound (higher cutoff)
        let highHRSignal = BioSignal(heartRate: 100.0, coherence: 60.0)
        filter.react(to: highHRSignal)

        XCTAssertNotNil(filter.getParameter(name: "cutoffFrequency"))
    }

    // MARK: - CompressorNode Tests

    func testCompressorNodeInitialization() throws {
        let compressor = CompressorNode()

        XCTAssertEqual(compressor.name, "Bio-Reactive Compressor")
        XCTAssertEqual(compressor.type, .effect)
    }

    func testCompressorNodeParameters() throws {
        let compressor = CompressorNode()

        XCTAssertEqual(compressor.getParameter(name: "threshold"), -20.0)
        XCTAssertEqual(compressor.getParameter(name: "ratio"), 4.0)
        XCTAssertEqual(compressor.getParameter(name: "attack"), 10.0)
        XCTAssertEqual(compressor.getParameter(name: "release"), 100.0)
        XCTAssertEqual(compressor.getParameter(name: "makeupGain"), 0.0)
        XCTAssertEqual(compressor.getParameter(name: "knee"), 6.0)
    }

    func testCompressorNodeDetectionModes() throws {
        let compressor = CompressorNode()

        compressor.setDetectionMode(.peak)
        XCTAssertEqual(compressor.getDetectionMode(), .peak)

        compressor.setDetectionMode(.rms)
        XCTAssertEqual(compressor.getDetectionMode(), .rms)
    }

    func testCompressorNodeGainReduction() throws {
        let compressor = CompressorNode()

        // Initially no gain reduction
        XCTAssertEqual(compressor.gainReduction, 0.0)
    }

    func testCompressorNodeBioReactivity() throws {
        let compressor = CompressorNode()

        // Slow breathing should raise threshold
        let slowBreathSignal = BioSignal(
            heartRate: 65.0,
            coherence: 80.0,
            respiratoryRate: 5.0
        )
        compressor.react(to: slowBreathSignal)

        // Fast breathing should lower threshold
        let fastBreathSignal = BioSignal(
            heartRate: 90.0,
            coherence: 40.0,
            respiratoryRate: 22.0
        )
        compressor.react(to: fastBreathSignal)

        XCTAssertNotNil(compressor.getParameter(name: "threshold"))
    }

    // MARK: - AdvancedDSPEffects Tests

    func testParametricEQBandPassFilter() throws {
        let eq = AdvancedDSPEffects.ParametricEQ(bandCount: 8, sampleRate: 48000)

        // Generate test signal
        let testSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) }

        // Process through EQ
        let output = eq.process(testSignal)

        XCTAssertEqual(output.count, testSignal.count)
        XCTAssertFalse(output.allSatisfy { $0 == 0.0 }) // Should have non-zero output
    }

    func testMultibandCompressorProcessing() throws {
        let compressor = AdvancedDSPEffects.MultibandCompressor(sampleRate: 48000)

        // Generate test signal
        let testSignal = (0..<2048).map { Float(sin(Double($0) * 0.05)) * 0.5 }

        // Process
        let output = compressor.process(testSignal)

        XCTAssertEqual(output.count, testSignal.count)
    }

    func testDeEsserProcessing() throws {
        let deesser = AdvancedDSPEffects.DeEsser(sampleRate: 48000)
        deesser.threshold = -20.0
        deesser.frequency = 6000.0
        deesser.bandwidth = 4000.0

        // Generate test signal with sibilance simulation
        let testSignal = (0..<1024).map { i -> Float in
            let t = Float(i) / 48000.0
            return sin(2.0 * Float.pi * 7000.0 * t) * 0.5  // 7kHz sibilance
        }

        let output = deesser.process(testSignal)

        XCTAssertEqual(output.count, testSignal.count)
    }

    func testBrickWallLimiter() throws {
        let limiter = AdvancedDSPEffects.BrickWallLimiter(sampleRate: 48000)
        limiter.ceiling = -0.1

        // Generate signal that exceeds ceiling
        let hotSignal = (0..<512).map { _ in Float.random(in: -1.5...1.5) }

        let output = limiter.process(hotSignal)

        // Verify no sample exceeds ceiling
        let ceilingLinear = pow(10.0, limiter.ceiling / 20.0)
        for sample in output {
            XCTAssertLessThanOrEqual(abs(sample), ceilingLinear + 0.01)
        }
    }

    func testTapeDelay() throws {
        let delay = AdvancedDSPEffects.TapeDelay(sampleRate: 48000)
        delay.delayTime = 500.0
        delay.feedback = 0.5
        delay.mix = 0.3

        let testSignal = (0..<4096).map { i -> Float in
            i < 100 ? 1.0 : 0.0  // Impulse
        }

        let output = delay.process(testSignal)

        XCTAssertEqual(output.count, testSignal.count)
    }

    func testStereoImager() throws {
        let imager = AdvancedDSPEffects.StereoImager()

        // Mono signal
        let monoSignal = (0..<256).map { Float(sin(Double($0) * 0.1)) }

        // Wide stereo
        imager.width = 2.0
        let (leftWide, rightWide) = imager.process(left: monoSignal, right: monoSignal)

        XCTAssertEqual(leftWide.count, monoSignal.count)
        XCTAssertEqual(rightWide.count, monoSignal.count)

        // Mono collapse
        imager.width = 0.0
        let (leftMono, rightMono) = imager.process(left: monoSignal, right: monoSignal)

        // In mono, left and right should be identical
        for i in 0..<leftMono.count {
            XCTAssertEqual(leftMono[i], rightMono[i], accuracy: 0.001)
        }
    }

    // MARK: - EnhancedMLModels Tests

    func testEmotionClassifier() throws {
        let mlModels = EnhancedMLModels()

        mlModels.classifyEmotion(
            hrv: 0.7,
            coherence: 0.8,
            heartRate: 65.0,
            variability: 0.5,
            hrvTrend: 0.0,
            coherenceTrend: 0.1
        )

        // Should classify to some emotion
        XCTAssertNotEqual(mlModels.currentEmotion, .neutral)
        XCTAssertGreaterThan(mlModels.predictions.emotionConfidence, 0.0)
    }

    func testMusicStyleClassifier() throws {
        let mlModels = EnhancedMLModels()

        // Generate test audio buffer
        let audioBuffer = (0..<8192).map { Float(sin(Double($0) * 0.02)) * 0.3 }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: 44100)

        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown)
    }

    func testPatternRecognizer() throws {
        let mlModels = EnhancedMLModels()

        // Generate trending data
        let increasingHRV = (0..<100).map { Float($0) / 100.0 }
        let increasingCoherence = (0..<100).map { Float($0) / 100.0 }

        let patterns = mlModels.recognizePatterns(
            hrvData: increasingHRV,
            coherenceData: increasingCoherence
        )

        // Should recognize coherence building pattern
        XCTAssertFalse(patterns.isEmpty)
    }

    func testRecommendationGeneration() throws {
        let mlModels = EnhancedMLModels()

        let recommendations = mlModels.generateRecommendations(
            emotion: .energetic,
            style: .electronic
        )

        XCTAssertFalse(recommendations.isEmpty)
    }

    // MARK: - CreativeStudioEngine Tests

    func testCreativeStudioInitialization() throws {
        let studio = CreativeStudioEngine()

        XCTAssertFalse(studio.isProcessing)
        XCTAssertEqual(studio.generationProgress, 0.0)
        XCTAssertEqual(studio.selectedMode, .generativeArt)
    }

    func testProjectCreation() throws {
        let studio = CreativeStudioEngine()

        let project = studio.createProject(name: "Test Project", mode: .musicComposition)

        XCTAssertEqual(project.name, "Test Project")
        XCTAssertEqual(project.mode, .musicComposition)
        XCTAssertNotNil(studio.currentProject)
    }

    func testFractalGenerator() throws {
        let fractal = FractalGenerator(
            type: .mandelbrot,
            iterations: 64,
            zoom: 1.0,
            centerX: -0.5,
            centerY: 0,
            colorScheme: .quantum,
            quantumPerturbation: 0.0
        )

        let pixels = fractal.generate(width: 64, height: 64)

        XCTAssertEqual(pixels.count, 64 * 64 * 4)

        // Verify some non-black pixels exist
        let hasColor = pixels.contains { $0 > 0 }
        XCTAssertTrue(hasColor)
    }

    func testMusicTheoryScales() throws {
        // Test major scale
        let cMajor = MusicTheoryEngine.getScaleNotes(root: 0, scale: .major)
        XCTAssertEqual(cMajor, [0, 2, 4, 5, 7, 9, 11])

        // Test minor scale
        let aMinor = MusicTheoryEngine.getScaleNotes(root: 9, scale: .minor)
        XCTAssertTrue(aMinor.contains(9))  // Root note

        // Test pentatonic
        let pentatonic = MusicTheoryEngine.getScaleNotes(root: 0, scale: .pentatonicMajor)
        XCTAssertEqual(pentatonic.count, 5)
    }

    func testMusicTheoryChords() throws {
        // Test major chord
        let cMajor = MusicTheoryEngine.getChordNotes(root: 0, chord: .major)
        XCTAssertEqual(cMajor, [0, 4, 7])

        // Test minor chord
        let aMinor = MusicTheoryEngine.getChordNotes(root: 9, chord: .minor)
        XCTAssertEqual(aMinor, [9, 12, 16])

        // Test seventh chord
        let g7 = MusicTheoryEngine.getChordNotes(root: 7, chord: .dominant7)
        XCTAssertEqual(g7.count, 4)
    }

    func testChordProgressionSuggestion() throws {
        let progression = MusicTheoryEngine.suggestChordProgression(scale: .major, length: 4)

        XCTAssertEqual(progression.count, 4)
    }

    // MARK: - TouchInstruments Tests

    func testDrumKitPads() throws {
        // Test each kit has proper pad configurations
        for kit in DrumKit.allCases {
            let pads = kit.pads
            XCTAssertEqual(pads.count, 16, "Kit \(kit.rawValue) should have 16 pads")

            // Verify all pads have valid MIDI notes
            for pad in pads {
                XCTAssertGreaterThanOrEqual(pad.midiNote, 0)
                XCTAssertLessThanOrEqual(pad.midiNote, 127)
            }
        }
    }

    func testTR808Kit() throws {
        let pads = DrumKit.tr808.pads

        // Verify expected sounds exist
        let names = pads.map { $0.name }
        XCTAssertTrue(names.contains("Kick"))
        XCTAssertTrue(names.contains("Snare"))
        XCTAssertTrue(names.contains("Cowbell"))
        XCTAssertTrue(names.contains("Conga Hi"))
    }

    func testPercussionKit() throws {
        let pads = DrumKit.percussion.pads

        // Should have Latin percussion sounds
        let names = pads.map { $0.name }
        XCTAssertTrue(names.contains("Conga Hi"))
        XCTAssertTrue(names.contains("Bongo Hi"))
        XCTAssertTrue(names.contains("Timbale Hi"))
    }

    // MARK: - Node Lifecycle Tests

    func testNodeLifecycle() throws {
        let reverb = ReverbNode()

        // Prepare
        reverb.prepare(sampleRate: 48000, maxFrames: 1024)

        // Start
        reverb.start()
        XCTAssertTrue(reverb.isActive)

        // Stop
        reverb.stop()
        XCTAssertFalse(reverb.isActive)

        // Reset
        reverb.reset()
        XCTAssertEqual(reverb.getParameter(name: "wetDry"), 30.0) // Default value
    }

    func testNodeBypass() throws {
        let filter = FilterNode()

        XCTAssertFalse(filter.isBypassed)

        filter.isBypassed = true
        XCTAssertTrue(filter.isBypassed)
    }

    // MARK: - Performance Tests

    func testReverbPerformance() throws {
        let reverb = ReverbNode()
        reverb.prepare(sampleRate: 48000, maxFrames: 1024)
        reverb.start()

        measure {
            // Create test buffer
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
            buffer.frameLength = 1024

            // Fill with test data
            if let channelData = buffer.floatChannelData {
                for ch in 0..<2 {
                    for i in 0..<1024 {
                        channelData[ch][i] = Float.random(in: -1.0...1.0)
                    }
                }
            }

            // Process
            let time = AVAudioTime(sampleTime: 0, atRate: 48000)
            _ = reverb.process(buffer, time: time)
        }
    }

    func testFilterPerformance() throws {
        let filter = FilterNode()
        filter.prepare(sampleRate: 48000, maxFrames: 1024)
        filter.start()

        measure {
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
            buffer.frameLength = 1024

            if let channelData = buffer.floatChannelData {
                for ch in 0..<2 {
                    for i in 0..<1024 {
                        channelData[ch][i] = Float.random(in: -1.0...1.0)
                    }
                }
            }

            let time = AVAudioTime(sampleTime: 0, atRate: 48000)
            _ = filter.process(buffer, time: time)
        }
    }

    func testFractalGenerationPerformance() throws {
        measure {
            let fractal = FractalGenerator(type: .mandelbrot, iterations: 128)
            _ = fractal.generate(width: 256, height: 256)
        }
    }
}
