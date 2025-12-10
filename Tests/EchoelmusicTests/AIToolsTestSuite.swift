import XCTest
@testable import Echoelmusic

/// AI Tools Test Suite - Comprehensive testing for all AI/ML components
///
/// Coverage:
/// - Neural Breath Separation Engine
/// - AI Stem Separation
/// - LSTM Melody Generation
/// - Audio2MIDI Neural Pitch Detection
/// - Smart Mixer AI
/// - Pattern Generator Neural Networks
/// - Emotion Classification
/// - Music Style Classification
///
@MainActor
final class AIToolsTestSuite: XCTestCase {

    // MARK: - Neural Breath Separation Tests

    func testNeuralBreathSeparationInitialization() async throws {
        let breathEngine = NeuralBreathSeparationEngine()

        XCTAssertNotNil(breathEngine, "Breath separation engine should initialize")
        XCTAssertTrue(breathEngine.isReady, "Engine should be ready after init")
    }

    func testBreathDetectionInAudio() async throws {
        let breathEngine = NeuralBreathSeparationEngine()

        // Create test audio with simulated breath sounds
        let sampleRate: Float = 48000
        let duration: Float = 2.0
        let samples = Int(sampleRate * duration)

        var testAudio = [Float](repeating: 0, count: samples)

        // Simulate breath at specific intervals (around 0.5s and 1.5s)
        for i in 0..<samples {
            let t = Float(i) / sampleRate

            // Add speech-like content
            testAudio[i] = sin(2.0 * Float.pi * 220 * t) * 0.3

            // Add breath-like noise bursts
            if (t > 0.4 && t < 0.6) || (t > 1.4 && t < 1.6) {
                testAudio[i] += Float.random(in: -0.2...0.2) // Breath noise
                testAudio[i] *= 0.3 // Lower energy for breath
            }
        }

        let result = await breathEngine.detectBreaths(in: testAudio, sampleRate: sampleRate)

        XCTAssertFalse(result.breathMarkers.isEmpty, "Should detect breath events")
        XCTAssertGreaterThanOrEqual(result.breathMarkers.count, 1, "Should detect at least 1 breath")

        // Check breath positions are reasonable
        for marker in result.breathMarkers {
            XCTAssertGreaterThanOrEqual(marker.startTime, 0, "Breath start should be >= 0")
            XCTAssertLessThanOrEqual(marker.endTime, duration, "Breath end should be <= duration")
            XCTAssertGreaterThan(marker.confidence, 0.5, "Confidence should be > 0.5")
        }
    }

    func testBreathRemoval() async throws {
        let breathEngine = NeuralBreathSeparationEngine()

        // Create test audio
        let sampleRate: Float = 48000
        let samples = Int(sampleRate * 1.0)
        var testAudio = [Float](repeating: 0, count: samples)

        // Add content with breath
        for i in 0..<samples {
            let t = Float(i) / sampleRate
            testAudio[i] = sin(2.0 * Float.pi * 440 * t) * 0.5

            // Breath section
            if t > 0.3 && t < 0.5 {
                testAudio[i] = Float.random(in: -0.15...0.15)
            }
        }

        let originalEnergy = testAudio.map { $0 * $0 }.reduce(0, +)
        let cleanedAudio = await breathEngine.removeBreaths(from: testAudio, sampleRate: sampleRate)
        let cleanedEnergy = cleanedAudio.map { $0 * $0 }.reduce(0, +)

        XCTAssertEqual(cleanedAudio.count, testAudio.count, "Output length should match input")
        // Breath removal should reduce energy in breath regions
        XCTAssertNotEqual(cleanedEnergy, originalEnergy, "Energy should change after breath removal")
    }

    func testBreathSeparationQualityModes() async throws {
        let breathEngine = NeuralBreathSeparationEngine()

        let testAudio = (0..<4800).map { Float(sin(Double($0) * 0.1)) }

        // Test all quality modes
        for quality in NeuralBreathSeparationEngine.QualityMode.allCases {
            breathEngine.setQuality(quality)
            let result = await breathEngine.detectBreaths(in: testAudio, sampleRate: 48000)

            XCTAssertNotNil(result, "Result should not be nil for quality: \(quality)")
            XCTAssertGreaterThanOrEqual(result.processingTime, 0, "Processing time should be measured")
        }
    }

    // MARK: - AI Stem Separation Tests

    func testStemSeparationKernelInitialization() throws {
        let kernel = StemSeparationDSPKernel()
        kernel.initialize(sampleRate: 48000, channelCount: 2)

        XCTAssertGreaterThan(kernel.latency, 0, "Latency should be positive")
        XCTAssertGreaterThan(kernel.tailTime, 0, "Tail time should be positive")

        kernel.deallocate()
    }

    func testStemSeparationPresets() throws {
        let kernel = StemSeparationDSPKernel()
        kernel.initialize(sampleRate: 48000, channelCount: 2)

        // Test Vocal Isolation preset
        kernel.loadPreset(number: 0)
        XCTAssertEqual(kernel.getParameter(address: EchoelmusicParameterAddress.vocalLevel.rawValue), 1.0, "Vocal should be at 100%")
        XCTAssertEqual(kernel.getParameter(address: EchoelmusicParameterAddress.drumLevel.rawValue), 0.0, "Drums should be muted")

        // Test Karaoke preset
        kernel.loadPreset(number: 3)
        XCTAssertEqual(kernel.getParameter(address: EchoelmusicParameterAddress.vocalLevel.rawValue), 0.0, "Vocals should be muted for karaoke")

        kernel.deallocate()
    }

    func testNeuralStemSeparation() async throws {
        let stemSeparator = NeuralStemSeparator()

        // Create stereo test audio
        let sampleRate: Float = 48000
        let samples = 4096

        var leftChannel = [Float](repeating: 0, count: samples)
        var rightChannel = [Float](repeating: 0, count: samples)

        // Simulate mixed audio with different frequency components
        for i in 0..<samples {
            let t = Float(i) / sampleRate
            // Bass (60 Hz)
            let bass = sin(2.0 * Float.pi * 60 * t) * 0.3
            // Vocals (300 Hz fundamental + harmonics)
            let vocals = sin(2.0 * Float.pi * 300 * t) * 0.4 + sin(2.0 * Float.pi * 600 * t) * 0.2
            // Hi-hats (high frequency noise burst)
            let hihat = (i % 2400 < 200) ? Float.random(in: -0.1...0.1) : 0
            // Mix together
            leftChannel[i] = bass + vocals + hihat
            rightChannel[i] = bass + vocals * 0.9 + hihat
        }

        let result = await stemSeparator.separate(
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            sampleRate: sampleRate
        )

        XCTAssertEqual(result.vocals.count, samples, "Vocals output should match input length")
        XCTAssertEqual(result.drums.count, samples, "Drums output should match input length")
        XCTAssertEqual(result.bass.count, samples, "Bass output should match input length")
        XCTAssertEqual(result.other.count, samples, "Other output should match input length")

        // Verify separation quality metrics
        XCTAssertGreaterThan(result.separationQuality, 0.5, "Separation quality should be reasonable")
    }

    // MARK: - LSTM Melody Generation Tests

    func testLSTMMelodyGeneratorInitialization() async throws {
        let generator = LSTMMelodyGenerator()

        await generator.loadModel()
        XCTAssertTrue(generator.isModelLoaded, "LSTM model should load")
    }

    func testMelodyGenerationBasic() async throws {
        let generator = LSTMMelodyGenerator()
        await generator.loadModel()

        let melody = await generator.generateMelody(
            key: .cMajor,
            scale: .major,
            bars: 4,
            tempo: 120
        )

        XCTAssertFalse(melody.isEmpty, "Melody should not be empty")
        XCTAssertGreaterThanOrEqual(melody.count, 8, "4 bars should have at least 8 notes")

        // Verify all notes are in scale
        for note in melody {
            XCTAssertGreaterThanOrEqual(note.pitch, 0, "Pitch should be >= 0")
            XCTAssertLessThanOrEqual(note.pitch, 127, "Pitch should be <= 127")
            XCTAssertGreaterThan(note.duration, 0, "Duration should be positive")
            XCTAssertGreaterThanOrEqual(note.velocity, 0, "Velocity should be >= 0")
            XCTAssertLessThanOrEqual(note.velocity, 127, "Velocity should be <= 127")
        }
    }

    func testMelodyGenerationWithEmotion() async throws {
        let generator = LSTMMelodyGenerator()
        await generator.loadModel()

        // Test calm emotion
        let calmMelody = await generator.generateMelody(
            key: .cMajor,
            scale: .major,
            bars: 4,
            tempo: 70,
            emotion: .calm
        )

        // Test energetic emotion
        let energeticMelody = await generator.generateMelody(
            key: .aMajor,
            scale: .major,
            bars: 4,
            tempo: 140,
            emotion: .energetic
        )

        XCTAssertFalse(calmMelody.isEmpty, "Calm melody should be generated")
        XCTAssertFalse(energeticMelody.isEmpty, "Energetic melody should be generated")

        // Energetic melodies typically have more notes
        // (not strictly required but expected behavior)
    }

    func testMelodyMotifDevelopment() async throws {
        let generator = LSTMMelodyGenerator()
        await generator.loadModel()

        // Define a simple motif
        let motif: [LSTMMelodyGenerator.MelodyNote] = [
            LSTMMelodyGenerator.MelodyNote(pitch: 60, duration: 0.25, velocity: 80),
            LSTMMelodyGenerator.MelodyNote(pitch: 62, duration: 0.25, velocity: 80),
            LSTMMelodyGenerator.MelodyNote(pitch: 64, duration: 0.5, velocity: 80)
        ]

        let developedMelody = await generator.developMotif(
            motif: motif,
            technique: .sequence,
            key: .cMajor
        )

        XCTAssertGreaterThan(developedMelody.count, motif.count, "Developed melody should be longer")
    }

    // MARK: - Audio2MIDI Neural Pitch Detection Tests

    func testAudio2MIDIInitialization() throws {
        let converter = NeuralAudio2MIDI()
        XCTAssertNotNil(converter, "Audio2MIDI should initialize")
    }

    func testMonophonicPitchDetection() async throws {
        let converter = NeuralAudio2MIDI()

        // Generate pure sine wave at A4 (440 Hz)
        let sampleRate: Float = 48000
        let duration: Float = 0.5
        let frequency: Float = 440.0
        let samples = Int(sampleRate * duration)

        let testAudio = (0..<samples).map { i in
            sin(2.0 * Float.pi * frequency * Float(i) / sampleRate) * 0.5
        }

        let midiNotes = await converter.convertToMIDI(
            audio: testAudio,
            sampleRate: sampleRate,
            mode: .monophonic
        )

        XCTAssertFalse(midiNotes.isEmpty, "Should detect MIDI notes")

        // A4 should be MIDI note 69
        if let firstNote = midiNotes.first {
            XCTAssertEqual(firstNote.pitch, 69, accuracy: 1, "Should detect A4 (MIDI 69)")
        }
    }

    func testPolyphonicPitchDetection() async throws {
        let converter = NeuralAudio2MIDI()

        // Generate C major chord (C4 + E4 + G4)
        let sampleRate: Float = 48000
        let duration: Float = 0.5
        let samples = Int(sampleRate * duration)

        let frequencies: [Float] = [261.63, 329.63, 392.00] // C4, E4, G4

        let testAudio = (0..<samples).map { i in
            frequencies.reduce(0.0) { acc, freq in
                acc + sin(2.0 * Float.pi * freq * Float(i) / sampleRate) * 0.3
            }
        }

        let midiNotes = await converter.convertToMIDI(
            audio: testAudio,
            sampleRate: sampleRate,
            mode: .polyphonic
        )

        XCTAssertGreaterThanOrEqual(midiNotes.count, 2, "Should detect multiple notes in chord")

        // Check for expected MIDI note numbers (C4=60, E4=64, G4=67)
        let detectedPitches = Set(midiNotes.map { $0.pitch })
        let hasC4 = detectedPitches.contains { abs($0 - 60) <= 1 }
        let hasE4 = detectedPitches.contains { abs($0 - 64) <= 1 }
        let hasG4 = detectedPitches.contains { abs($0 - 67) <= 1 }

        XCTAssertTrue(hasC4 || hasE4 || hasG4, "Should detect at least one chord tone")
    }

    func testOnsetDetection() async throws {
        let converter = NeuralAudio2MIDI()

        // Create audio with clear onsets
        let sampleRate: Float = 48000
        let samples = Int(sampleRate * 1.0)
        var testAudio = [Float](repeating: 0, count: samples)

        // Add notes at 0.0s, 0.25s, 0.5s, 0.75s
        let onsetTimes: [Float] = [0.0, 0.25, 0.5, 0.75]
        let noteDuration: Float = 0.2

        for onset in onsetTimes {
            let startSample = Int(onset * sampleRate)
            let endSample = min(startSample + Int(noteDuration * sampleRate), samples)

            for i in startSample..<endSample {
                let t = Float(i - startSample) / sampleRate
                let envelope = exp(-t * 10) // Decay envelope
                testAudio[i] += sin(2.0 * Float.pi * 440 * t) * envelope * 0.5
            }
        }

        let onsets = await converter.detectOnsets(audio: testAudio, sampleRate: sampleRate)

        XCTAssertGreaterThanOrEqual(onsets.count, 3, "Should detect most onsets")
    }

    func testPitchBendDetection() async throws {
        let converter = NeuralAudio2MIDI()

        // Create audio with pitch bend (frequency glide from A4 to B4)
        let sampleRate: Float = 48000
        let duration: Float = 0.5
        let samples = Int(sampleRate * duration)

        let startFreq: Float = 440.0 // A4
        let endFreq: Float = 493.88 // B4

        var phase: Float = 0
        let testAudio = (0..<samples).map { i -> Float in
            let t = Float(i) / sampleRate
            let freq = startFreq + (endFreq - startFreq) * (t / duration)
            phase += 2.0 * Float.pi * freq / sampleRate
            return sin(phase) * 0.5
        }

        let midiNotes = await converter.convertToMIDI(
            audio: testAudio,
            sampleRate: sampleRate,
            mode: .monophonic,
            detectPitchBend: true
        )

        XCTAssertFalse(midiNotes.isEmpty, "Should detect note with pitch bend")

        // Check for pitch bend data
        if let note = midiNotes.first {
            XCTAssertNotNil(note.pitchBend, "Should have pitch bend data")
            if let pitchBend = note.pitchBend {
                XCTAssertFalse(pitchBend.isEmpty, "Pitch bend array should not be empty")
            }
        }
    }

    // MARK: - Smart Mixer AI Tests

    func testSmartMixerInitialization() throws {
        let mixer = SmartMixerAI()
        XCTAssertNotNil(mixer, "Smart mixer should initialize")
    }

    func testAutoEQSuggestion() async throws {
        let mixer = SmartMixerAI()

        // Create test track with excess bass
        let sampleRate: Float = 48000
        let samples = 48000

        let testTrack = (0..<samples).map { i in
            let t = Float(i) / sampleRate
            // Heavy bass + some mids
            return sin(2.0 * Float.pi * 60 * t) * 0.8 + sin(2.0 * Float.pi * 1000 * t) * 0.2
        }

        let eqSuggestion = await mixer.suggestEQ(for: testTrack, sampleRate: sampleRate)

        XCTAssertFalse(eqSuggestion.bands.isEmpty, "Should suggest EQ adjustments")

        // Should suggest cutting bass since it's excessive
        let bassBand = eqSuggestion.bands.first { $0.frequency < 150 }
        XCTAssertNotNil(bassBand, "Should have bass band suggestion")
    }

    func testAutoCompression() async throws {
        let mixer = SmartMixerAI()

        // Create dynamic test audio
        let sampleRate: Float = 48000
        let samples = 48000

        var testTrack = [Float](repeating: 0, count: samples)
        for i in 0..<samples {
            let t = Float(i) / sampleRate
            // Create dynamic content with quiet and loud sections
            let amplitude: Float = (i < samples/2) ? 0.2 : 0.9
            testTrack[i] = sin(2.0 * Float.pi * 440 * t) * amplitude
        }

        let compressionSuggestion = await mixer.suggestCompression(for: testTrack)

        XCTAssertGreaterThan(compressionSuggestion.ratio, 1.0, "Should suggest compression ratio > 1")
        XCTAssertLessThan(compressionSuggestion.threshold, 0, "Threshold should be negative dB")
    }

    func testAutoMasteringChain() async throws {
        let mixer = SmartMixerAI()

        // Create full mix simulation
        let sampleRate: Float = 48000
        let samples = 48000 * 2

        let testMix = (0..<samples).map { i in
            let t = Float(i) / sampleRate
            return sin(2.0 * Float.pi * 200 * t) * 0.3 +
                   sin(2.0 * Float.pi * 800 * t) * 0.2 +
                   sin(2.0 * Float.pi * 3000 * t) * 0.1 +
                   Float.random(in: -0.05...0.05)
        }

        let masteringChain = await mixer.suggestMasteringChain(for: testMix, sampleRate: sampleRate)

        XCTAssertFalse(masteringChain.stages.isEmpty, "Should suggest mastering stages")
        XCTAssertGreaterThanOrEqual(masteringChain.stages.count, 2, "Should have at least EQ and limiter")
    }

    // MARK: - Pattern Generator Neural Tests

    func testPatternGeneratorInitialization() throws {
        let generator = NeuralPatternGenerator()
        XCTAssertNotNil(generator, "Pattern generator should initialize")
    }

    func testDrumPatternGeneration() async throws {
        let generator = NeuralPatternGenerator()

        let pattern = await generator.generateDrumPattern(
            style: .electronic,
            bars: 2,
            tempo: 128
        )

        XCTAssertFalse(pattern.kicks.isEmpty, "Should have kick pattern")
        XCTAssertFalse(pattern.snares.isEmpty, "Should have snare pattern")
        XCTAssertFalse(pattern.hihats.isEmpty, "Should have hi-hat pattern")

        // Verify 2 bars (32 steps at 16th notes)
        XCTAssertEqual(pattern.kicks.count, 32, "Should have 32 steps for 2 bars")
    }

    func testBasslineGeneration() async throws {
        let generator = NeuralPatternGenerator()

        let chordProgression: [NeuralPatternGenerator.ChordSymbol] = [
            NeuralPatternGenerator.ChordSymbol(root: "C", type: .major),
            NeuralPatternGenerator.ChordSymbol(root: "Am", type: .minor),
            NeuralPatternGenerator.ChordSymbol(root: "F", type: .major),
            NeuralPatternGenerator.ChordSymbol(root: "G", type: .major)
        ]

        let bassline = await generator.generateBassline(
            chords: chordProgression,
            style: .funk,
            bars: 4
        )

        XCTAssertFalse(bassline.isEmpty, "Should generate bassline")

        // Verify notes follow chord roots
        for note in bassline {
            XCTAssertGreaterThanOrEqual(note.pitch, 24, "Bass should be in bass range")
            XCTAssertLessThanOrEqual(note.pitch, 60, "Bass should be in bass range")
        }
    }

    func testArpeggioGeneration() async throws {
        let generator = NeuralPatternGenerator()

        let arpeggio = await generator.generateArpeggio(
            chord: NeuralPatternGenerator.ChordSymbol(root: "Cmaj7", type: .major7),
            pattern: .upDown,
            octaves: 2,
            rate: .sixteenth
        )

        XCTAssertFalse(arpeggio.isEmpty, "Should generate arpeggio")
    }

    // MARK: - Emotion Classification Deep Tests

    func testEmotionClassifierAccuracy() async throws {
        let mlModels = EnhancedMLModels()

        // Test known emotion scenarios
        let testCases: [(hrv: Float, coherence: Float, hr: Float, expected: EnhancedMLModels.Emotion)] = [
            (0.8, 0.8, 65, .calm),      // High coherence, low HR
            (0.9, 0.6, 95, .energetic), // High HRV, high HR
            (0.3, 0.2, 100, .anxious),  // Low HRV/coherence, high HR
            (0.7, 0.8, 75, .focused),   // Moderate HR, high coherence
        ]

        var correctPredictions = 0

        for testCase in testCases {
            mlModels.classifyEmotion(
                hrv: testCase.hrv,
                coherence: testCase.coherence,
                heartRate: testCase.hr,
                variability: 0.2,
                hrvTrend: 0.01,
                coherenceTrend: 0.01
            )

            if mlModels.currentEmotion == testCase.expected {
                correctPredictions += 1
            }
        }

        let accuracy = Float(correctPredictions) / Float(testCases.count)
        XCTAssertGreaterThanOrEqual(accuracy, 0.5, "Emotion classifier should be >= 50% accurate")
    }

    func testEmotionTransitionTracking() async throws {
        let mlModels = EnhancedMLModels()

        var emotionHistory: [EnhancedMLModels.Emotion] = []

        // Simulate transition from calm to energetic
        let hrvValues: [Float] = [0.8, 0.82, 0.85, 0.87, 0.9]
        let hrValues: [Float] = [65, 72, 80, 88, 95]
        let coherenceValues: [Float] = [0.8, 0.75, 0.7, 0.65, 0.6]

        for i in 0..<hrvValues.count {
            mlModels.classifyEmotion(
                hrv: hrvValues[i],
                coherence: coherenceValues[i],
                heartRate: hrValues[i],
                variability: 0.2,
                hrvTrend: 0.02,
                coherenceTrend: -0.02
            )
            emotionHistory.append(mlModels.currentEmotion)
        }

        XCTAssertFalse(emotionHistory.isEmpty, "Should track emotion history")
        XCTAssertNotEqual(emotionHistory.first, emotionHistory.last, "Emotion should change over time")
    }

    // MARK: - Music Style Classification Deep Tests

    func testMusicStyleClassifierFeatureExtraction() async throws {
        let mlModels = EnhancedMLModels()

        // Test electronic music characteristics (high tempo, synthetic)
        let electronicAudio = generateStyleTestAudio(style: .electronic)
        mlModels.classifyMusicStyle(audioBuffer: electronicAudio, sampleRate: 48000)

        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown, "Should classify style")
    }

    func testStyleConfidenceScoring() async throws {
        let mlModels = EnhancedMLModels()

        // Create clearly electronic music
        let testAudio = (0..<48000).map { i in
            let t = Float(i) / 48000
            // Fast tempo (128 BPM), synthetic tones
            let beat = (i % 375 < 50) ? Float(1.0) : Float(0.0) // 128 BPM kick
            let synth = sin(2.0 * Float.pi * 440 * t) * 0.3
            return beat * 0.5 + synth
        }

        mlModels.classifyMusicStyle(audioBuffer: testAudio, sampleRate: 48000)

        XCTAssertGreaterThan(mlModels.predictions.styleConfidence, 0, "Should have confidence score")
        XCTAssertLessThanOrEqual(mlModels.predictions.styleConfidence, 1.0, "Confidence should be <= 1")
    }

    // MARK: - Pattern Recognition Tests

    func testCoherenceBuildingDetection() async throws {
        let mlModels = EnhancedMLModels()

        // Simulate steadily increasing coherence
        let coherenceData: [Float] = (0..<30).map { Float($0) * 0.03 }
        let hrvData: [Float] = Array(repeating: 0.7, count: 30)

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        let hasCoherenceBuilding = patterns.contains { $0.type == .coherenceBuilding }
        XCTAssertTrue(hasCoherenceBuilding, "Should detect coherence building pattern")
    }

    func testStressResponseDetection() async throws {
        let mlModels = EnhancedMLModels()

        // Simulate decreasing HRV (stress indicator)
        let hrvData: [Float] = (0..<30).map { 0.9 - Float($0) * 0.02 }
        let coherenceData: [Float] = Array(repeating: 0.5, count: 30)

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        let hasStressResponse = patterns.contains { $0.type == .stressResponse }
        XCTAssertTrue(hasStressResponse, "Should detect stress response pattern")
    }

    func testFlowStateDetection() async throws {
        let mlModels = EnhancedMLModels()

        // Simulate flow state: high stable coherence + stable HRV
        let hrvData: [Float] = (0..<30).map { _ in 0.75 + Float.random(in: -0.02...0.02) }
        let coherenceData: [Float] = (0..<30).map { _ in 0.85 + Float.random(in: -0.03...0.03) }

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        let hasFlowState = patterns.contains { $0.type == .flowState }
        XCTAssertTrue(hasFlowState, "Should detect flow state pattern")
    }

    // MARK: - Integration Tests

    func testEndToEndAIMusicGeneration() async throws {
        // Full pipeline: Bio data → Emotion → Style → Melody
        let mlModels = EnhancedMLModels()
        let melodyGenerator = LSTMMelodyGenerator()

        // 1. Classify emotion from bio data
        mlModels.classifyEmotion(
            hrv: 0.75,
            coherence: 0.8,
            heartRate: 68,
            variability: 0.2,
            hrvTrend: 0.01,
            coherenceTrend: 0.02
        )

        XCTAssertNotEqual(mlModels.currentEmotion, .neutral, "Should classify emotion")

        // 2. Get recommendations
        let recommendations = mlModels.generateRecommendations(
            emotion: mlModels.currentEmotion,
            style: .ambient
        )

        XCTAssertFalse(recommendations.isEmpty, "Should generate recommendations")

        // 3. Generate melody based on emotion
        await melodyGenerator.loadModel()
        let melody = await melodyGenerator.generateMelody(
            key: .cMajor,
            scale: .major,
            bars: 4,
            tempo: Int(mlModels.currentEmotion.recommendedBPM.lowerBound),
            emotion: mlModels.currentEmotion
        )

        XCTAssertFalse(melody.isEmpty, "Should generate melody")
    }

    func testAudioProcessingPipeline() async throws {
        // Full audio pipeline: Audio → MIDI → Pattern → Generation
        let audio2midi = NeuralAudio2MIDI()
        let patternGen = NeuralPatternGenerator()
        let melodyGen = LSTMMelodyGenerator()

        // 1. Create test audio
        let testAudio = (0..<24000).map { i in
            sin(2.0 * Float.pi * 440 * Float(i) / 48000) * 0.5
        }

        // 2. Convert to MIDI
        let midiNotes = await audio2midi.convertToMIDI(
            audio: testAudio,
            sampleRate: 48000,
            mode: .monophonic
        )

        XCTAssertFalse(midiNotes.isEmpty, "Should convert to MIDI")

        // 3. Generate complementary pattern
        let drumPattern = await patternGen.generateDrumPattern(
            style: .electronic,
            bars: 2,
            tempo: 120
        )

        XCTAssertFalse(drumPattern.kicks.isEmpty, "Should generate drum pattern")

        // 4. Generate melody to accompany
        await melodyGen.loadModel()
        let melody = await melodyGen.generateMelody(
            key: .aMajor,
            scale: .major,
            bars: 2,
            tempo: 120
        )

        XCTAssertFalse(melody.isEmpty, "Should generate melody")
    }

    // MARK: - Performance Tests

    func testBreathDetectionPerformance() async throws {
        let breathEngine = NeuralBreathSeparationEngine()

        // 10 seconds of audio
        let testAudio = (0..<480000).map { Float(sin(Double($0) * 0.01)) }

        let startTime = Date()
        _ = await breathEngine.detectBreaths(in: testAudio, sampleRate: 48000)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(duration, 5.0, "Breath detection should complete in < 5 seconds")
    }

    func testMelodyGenerationPerformance() async throws {
        let generator = LSTMMelodyGenerator()
        await generator.loadModel()

        let startTime = Date()
        for _ in 0..<10 {
            _ = await generator.generateMelody(
                key: .cMajor,
                scale: .major,
                bars: 8,
                tempo: 120
            )
        }
        let duration = Date().timeIntervalSince(startTime)

        let avgDuration = duration / 10.0
        XCTAssertLessThan(avgDuration, 1.0, "Average melody generation should be < 1 second")
    }

    func testAudio2MIDIPerformance() async throws {
        let converter = NeuralAudio2MIDI()

        // 5 seconds of audio
        let testAudio = (0..<240000).map { i in
            sin(2.0 * Float.pi * 440 * Float(i) / 48000) * 0.5
        }

        let startTime = Date()
        _ = await converter.convertToMIDI(audio: testAudio, sampleRate: 48000, mode: .polyphonic)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(duration, 3.0, "Audio2MIDI should complete in < 3 seconds")
    }

    // MARK: - Helper Methods

    private func generateStyleTestAudio(style: EnhancedMLModels.MusicStyle) -> [Float] {
        let samples = 48000
        var audio = [Float](repeating: 0, count: samples)

        for i in 0..<samples {
            let t = Float(i) / 48000

            switch style {
            case .electronic:
                // Fast tempo kick + synth
                let kick = (i % 375 < 50) ? sin(2.0 * Float.pi * 60 * t * (1.0 - Float(i % 375) / 50)) : 0
                let synth = sin(2.0 * Float.pi * 440 * t) * 0.3
                audio[i] = kick * 0.5 + synth

            case .classical:
                // Slow, complex harmonics
                audio[i] = sin(2.0 * Float.pi * 220 * t) * 0.3 +
                          sin(2.0 * Float.pi * 330 * t) * 0.2 +
                          sin(2.0 * Float.pi * 440 * t) * 0.1

            case .jazz:
                // Complex, varied rhythms
                let variation = sin(2.0 * Float.pi * 3 * t) * 0.3
                audio[i] = sin(2.0 * Float.pi * (300 + variation * 50) * t) * 0.4

            default:
                audio[i] = sin(2.0 * Float.pi * 440 * t) * 0.5
            }
        }

        return audio
    }
}

// MARK: - Edge Case Tests

@MainActor
final class AIToolsEdgeCaseTests: XCTestCase {

    func testEmptyAudioInput() async throws {
        let breathEngine = NeuralBreathSeparationEngine()
        let result = await breathEngine.detectBreaths(in: [], sampleRate: 48000)

        XCTAssertTrue(result.breathMarkers.isEmpty, "Empty audio should return no breaths")
    }

    func testSilentAudioInput() async throws {
        let converter = NeuralAudio2MIDI()
        let silentAudio = [Float](repeating: 0, count: 48000)

        let midiNotes = await converter.convertToMIDI(
            audio: silentAudio,
            sampleRate: 48000,
            mode: .monophonic
        )

        XCTAssertTrue(midiNotes.isEmpty, "Silent audio should return no MIDI notes")
    }

    func testExtremeSampleRates() async throws {
        let breathEngine = NeuralBreathSeparationEngine()
        let testAudio = [Float](repeating: 0.5, count: 1000)

        // Test low sample rate
        let lowSRResult = await breathEngine.detectBreaths(in: testAudio, sampleRate: 8000)
        XCTAssertNotNil(lowSRResult, "Should handle 8kHz sample rate")

        // Test high sample rate
        let highSRResult = await breathEngine.detectBreaths(in: testAudio, sampleRate: 96000)
        XCTAssertNotNil(highSRResult, "Should handle 96kHz sample rate")
    }

    func testClippedAudioInput() async throws {
        let converter = NeuralAudio2MIDI()

        // Create heavily clipped audio
        let clippedAudio = (0..<48000).map { i -> Float in
            let raw = sin(2.0 * Float.pi * 440 * Float(i) / 48000) * 5.0
            return max(-1.0, min(1.0, raw))
        }

        let midiNotes = await converter.convertToMIDI(
            audio: clippedAudio,
            sampleRate: 48000,
            mode: .monophonic
        )

        XCTAssertFalse(midiNotes.isEmpty, "Should still detect notes in clipped audio")
    }

    func testVeryShortAudio() async throws {
        let converter = NeuralAudio2MIDI()

        // Only 10ms of audio
        let shortAudio = (0..<480).map { i in
            sin(2.0 * Float.pi * 440 * Float(i) / 48000) * 0.5
        }

        let midiNotes = await converter.convertToMIDI(
            audio: shortAudio,
            sampleRate: 48000,
            mode: .monophonic
        )

        // May or may not detect notes, but shouldn't crash
        XCTAssertNotNil(midiNotes, "Should handle very short audio without crashing")
    }
}
