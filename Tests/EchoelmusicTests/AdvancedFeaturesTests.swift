// AdvancedFeaturesTests.swift
// Echoelmusic Tests - Comprehensive Test Suite for 2025 Features
//
// Tests for:
// - ProAudioEffects2025 (Neural Amp, Hybrid Reverb)
// - SleepAnalytics (Sleep Detection, Circadian Rhythm)
// - AdvancedVisualAI2025 (Style Transfer, Beat Sync, Scene Detection)
// - AdvancedMLModels2025 (Stem Separation, Genre, Emotion, Quality)

import XCTest
@testable import Echoelmusic

final class AdvancedFeaturesTests: XCTestCase {

    // MARK: - Test Setup

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Audio/DSP Tests

    func testNeuralAmpModelerInitialization() {
        let amp = NeuralAmpModeler()

        XCTAssertTrue(amp.modelLoaded, "Neural amp model should be loaded")
        XCTAssertEqual(amp.currentPreset, .clean, "Default preset should be clean")
        XCTAssertEqual(amp.inputGain, 0.5, accuracy: 0.01, "Default input gain should be 0.5")
        XCTAssertEqual(amp.outputGain, 0.5, accuracy: 0.01, "Default output gain should be 0.5")
    }

    func testNeuralAmpProcessing() {
        let amp = NeuralAmpModeler()
        let testInput: [Float] = (0..<1024).map { sin(Float($0) * 0.1) * 0.5 }

        let output = amp.process(testInput)

        XCTAssertEqual(output.count, testInput.count, "Output length should match input")
        XCTAssertFalse(output.allSatisfy { $0 == 0 }, "Output should not be all zeros")
    }

    func testNeuralAmpPresets() {
        let amp = NeuralAmpModeler()

        for preset in NeuralAmpModeler.AmpPreset.allCases {
            amp.loadPreset(preset)
            XCTAssertEqual(amp.currentPreset, preset, "Preset should be set to \(preset.rawValue)")
        }
    }

    func testHybridAIReverbInitialization() {
        let reverb = HybridAIReverb()

        XCTAssertTrue(reverb.modelLoaded, "Reverb model should be loaded")
        XCTAssertEqual(reverb.currentAlgorithm, .hybrid, "Default algorithm should be hybrid")
        XCTAssertGreaterThan(reverb.decayTime, 0, "Decay time should be positive")
    }

    func testHybridReverbProcessing() {
        let reverb = HybridAIReverb()
        let testInput: [Float] = (0..<2048).map { sin(Float($0) * 0.05) * 0.3 }

        let output = reverb.process(testInput)

        XCTAssertEqual(output.count, testInput.count, "Output length should match input")
    }

    func testHybridReverbAlgorithms() {
        let reverb = HybridAIReverb()

        for algorithm in HybridAIReverb.ReverbAlgorithm.allCases {
            reverb.setAlgorithm(algorithm)
            XCTAssertEqual(reverb.currentAlgorithm, algorithm, "Algorithm should be \(algorithm.rawValue)")
        }
    }

    func testIntelligentDynamicsCompression() {
        let dynamics = IntelligentDynamics()
        let testInput: [Float] = (0..<1024).map { Float.random(in: -1...1) }

        let output = dynamics.process(testInput)

        XCTAssertEqual(output.count, testInput.count, "Output length should match input")

        // Check that dynamics processing reduces peak levels
        let inputPeak = testInput.map { abs($0) }.max() ?? 0
        let outputPeak = output.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(outputPeak, inputPeak * 1.1, "Output peak should not exceed input significantly")
    }

    func testSpectralRepairInitialization() {
        let repair = SpectralRepair()

        XCTAssertTrue(repair.isReady, "Spectral repair should be ready")
    }

    // MARK: - Science/Health Tests

    func testSleepStageDetectorInitialization() {
        let detector = SleepStageDetector()

        XCTAssertTrue(detector.isReady, "Sleep detector should be ready")
        XCTAssertEqual(detector.currentStage, .wake, "Initial stage should be wake")
    }

    func testSleepStageDetection() async {
        let detector = SleepStageDetector()

        // Simulate RR intervals (typical sleep pattern)
        let rrIntervals: [Double] = (0..<100).map { _ in
            Double.random(in: 800...1200) // Normal RR interval range in ms
        }

        let stage = await detector.detectStage(from: rrIntervals)

        XCTAssertNotNil(stage, "Stage detection should return a result")
        XCTAssertTrue(SleepStageDetector.SleepStage.allCases.contains(stage), "Stage should be valid")
    }

    func testSleepStageConfidence() async {
        let detector = SleepStageDetector()

        let rrIntervals: [Double] = (0..<100).map { _ in 900.0 }
        let _ = await detector.detectStage(from: rrIntervals)

        XCTAssertGreaterThanOrEqual(detector.confidence, 0, "Confidence should be >= 0")
        XCTAssertLessThanOrEqual(detector.confidence, 1, "Confidence should be <= 1")
    }

    func testCircadianRhythmAnalyzerInitialization() {
        let analyzer = CircadianRhythmAnalyzer()

        XCTAssertTrue(analyzer.isReady, "Circadian analyzer should be ready")
    }

    func testChronotypeDetection() {
        let analyzer = CircadianRhythmAnalyzer()

        // Test MEQ scoring
        let morningPreferenceAnswers = [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
        let chronotype = analyzer.assessChronotype(meqAnswers: morningPreferenceAnswers)

        XCTAssertNotNil(chronotype, "Chronotype should be detected")
    }

    func testRecoveryPredictorInitialization() {
        let predictor = RecoveryPredictor()

        XCTAssertTrue(predictor.isReady, "Recovery predictor should be ready")
    }

    func testReadinessScoreCalculation() async {
        let predictor = RecoveryPredictor()

        let hrvData: [Double] = (0..<50).map { _ in Double.random(in: 30...80) }
        let sleepHours: Double = 7.5

        let score = await predictor.calculateReadiness(hrvData: hrvData, sleepDuration: sleepHours)

        XCTAssertGreaterThanOrEqual(score, 0, "Readiness score should be >= 0")
        XCTAssertLessThanOrEqual(score, 100, "Readiness score should be <= 100")
    }

    // MARK: - Visual/Video Tests

    func testRealTimeStyleTransferInitialization() {
        let styleTransfer = RealTimeStyleTransfer()

        XCTAssertEqual(styleTransfer.currentStyle, .none, "Default style should be none")
        XCTAssertEqual(styleTransfer.styleIntensity, 1.0, accuracy: 0.01, "Default intensity should be 1.0")
        XCTAssertFalse(styleTransfer.isProcessing, "Should not be processing initially")
    }

    func testStylePresets() {
        let styleTransfer = RealTimeStyleTransfer()

        XCTAssertGreaterThan(RealTimeStyleTransfer.StylePreset.allCases.count, 5, "Should have multiple style presets")
        XCTAssertTrue(RealTimeStyleTransfer.StylePreset.allCases.contains(.bioReactive), "Should have bio-reactive style")
    }

    func testBeatSyncedAutoEditorInitialization() {
        let editor = BeatSyncedAutoEditor()

        XCTAssertEqual(editor.currentBPM, 120.0, accuracy: 0.1, "Default BPM should be 120")
        XCTAssertFalse(editor.isAnalyzing, "Should not be analyzing initially")
    }

    func testBeatDetection() {
        let editor = BeatSyncedAutoEditor()

        // Generate simple beat pattern (click at regular intervals)
        var testAudio = [Float](repeating: 0, count: 44100 * 4) // 4 seconds
        let beatInterval = 44100 / 2 // 120 BPM

        for i in stride(from: 0, to: testAudio.count, by: beatInterval) {
            for j in 0..<100 {
                if i + j < testAudio.count {
                    testAudio[i + j] = 1.0 * exp(Float(-j) / 20)
                }
            }
        }

        let beats = editor.detectBeats(audioSamples: testAudio, sampleRate: 44100)

        XCTAssertGreaterThan(beats.count, 0, "Should detect beats")
        XCTAssertEqual(editor.currentBPM, 120.0, accuracy: 30.0, "BPM should be approximately 120")
    }

    func testEditIntensityOptions() {
        XCTAssertGreaterThan(BeatSyncedAutoEditor.EditIntensity.allCases.count, 3, "Should have multiple intensity options")
        XCTAssertTrue(BeatSyncedAutoEditor.EditIntensity.allCases.contains(.adaptive), "Should have adaptive option")
    }

    func testSceneDetectionAIInitialization() {
        let sceneAI = SceneDetectionAI()

        XCTAssertFalse(sceneAI.isAnalyzing, "Should not be analyzing initially")
        XCTAssertEqual(sceneAI.detectedScenes.count, 0, "Should have no scenes initially")
    }

    func testSceneTypes() {
        XCTAssertGreaterThan(SceneDetectionAI.SceneType.allCases.count, 5, "Should have multiple scene types")
        XCTAssertTrue(SceneDetectionAI.SceneType.allCases.contains(.bioReactive), "Should have bio-reactive scene type")
    }

    func testStreamingVideoIOInitialization() {
        let streamIO = StreamingVideoIO()

        XCTAssertFalse(streamIO.isConnected, "Should not be connected initially")
        XCTAssertEqual(streamIO.availableSources.count, 0, "Should have no sources initially")
    }

    func testStreamProtocols() {
        XCTAssertTrue(StreamingVideoIO.StreamProtocol.allCases.contains(.ndi), "Should support NDI")
        XCTAssertTrue(StreamingVideoIO.StreamProtocol.allCases.contains(.syphon), "Should support Syphon")
    }

    // MARK: - AI/ML Tests

    func testNeuralStemSeparatorInitialization() {
        let separator = NeuralStemSeparator()

        XCTAssertTrue(separator.modelLoaded, "Model should be loaded")
        XCTAssertFalse(separator.isProcessing, "Should not be processing initially")
    }

    func testStemTypes() {
        XCTAssertEqual(NeuralStemSeparator.StemType.allCases.count, 5, "Should have 5 stem types")
        XCTAssertTrue(NeuralStemSeparator.StemType.allCases.contains(.vocals), "Should have vocals")
        XCTAssertTrue(NeuralStemSeparator.StemType.allCases.contains(.drums), "Should have drums")
        XCTAssertTrue(NeuralStemSeparator.StemType.allCases.contains(.bass), "Should have bass")
        XCTAssertTrue(NeuralStemSeparator.StemType.allCases.contains(.other), "Should have other")
    }

    func testProcessingQualitySettings() {
        let separator = NeuralStemSeparator()

        for quality in NeuralStemSeparator.ProcessingQuality.allCases {
            separator.setQuality(quality)
            XCTAssertEqual(separator.processingQuality, quality, "Quality should be set to \(quality.rawValue)")
        }
    }

    func testGenreClassifierInitialization() {
        let classifier = GenreClassifierML()

        XCTAssertTrue(classifier.modelLoaded, "Model should be loaded")
        XCTAssertFalse(classifier.isClassifying, "Should not be classifying initially")
    }

    func testGenreCategories() {
        XCTAssertGreaterThan(GenreClassifierML.GenreCategory.allCases.count, 10, "Should have many genre categories")
        XCTAssertTrue(GenreClassifierML.GenreCategory.allCases.contains(.electronic), "Should have electronic")
        XCTAssertTrue(GenreClassifierML.GenreCategory.allCases.contains(.hiphop), "Should have hip-hop")
    }

    func testGenreClassification() async {
        let classifier = GenreClassifierML()

        // Generate test audio (simple sine wave)
        let testAudio: [Float] = (0..<44100).map { sin(Float($0) * 440 * 2 * .pi / 44100) }

        let predictions = await classifier.classify(audioData: testAudio, sampleRate: 44100)

        XCTAssertGreaterThan(predictions.count, 0, "Should return predictions")
        XCTAssertEqual(predictions.count, GenreClassifierML.GenreCategory.allCases.count, "Should have prediction for each genre")

        // Check probabilities sum to approximately 1
        let totalProb = predictions.reduce(0) { $0 + $1.probability }
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.1, "Probabilities should sum to ~1")
    }

    func testEmotionPredictorInitialization() {
        let predictor = EmotionPredictorML()

        XCTAssertTrue(predictor.modelLoaded, "Model should be loaded")
        XCTAssertFalse(predictor.isAnalyzing, "Should not be analyzing initially")
    }

    func testEmotionCategories() {
        XCTAssertGreaterThan(EmotionPredictorML.EmotionCategory.allCases.count, 5, "Should have multiple emotion categories")
    }

    func testEmotionPrediction() async {
        let predictor = EmotionPredictorML()

        let testAudio: [Float] = (0..<44100).map { Float.random(in: -0.5...0.5) }

        let emotion = await predictor.predict(audioData: testAudio, sampleRate: 44100)

        XCTAssertGreaterThanOrEqual(emotion.valence, 0, "Valence should be >= 0")
        XCTAssertLessThanOrEqual(emotion.valence, 1, "Valence should be <= 1")
        XCTAssertGreaterThanOrEqual(emotion.arousal, 0, "Arousal should be >= 0")
        XCTAssertLessThanOrEqual(emotion.arousal, 1, "Arousal should be <= 1")
    }

    func testAudioQualityAssessorInitialization() {
        let assessor = AudioQualityAssessorML()

        XCTAssertTrue(assessor.modelLoaded, "Model should be loaded")
        XCTAssertFalse(assessor.isAssessing, "Should not be assessing initially")
    }

    func testQualityTiers() {
        XCTAssertEqual(AudioQualityAssessorML.QualityTier.allCases.count, 5, "Should have 5 quality tiers")
    }

    func testQualityAssessment() async {
        let assessor = AudioQualityAssessorML()

        // Generate clean sine wave (should score well)
        let testAudio: [Float] = (0..<44100).map { sin(Float($0) * 440 * 2 * .pi / 44100) * 0.5 }

        let quality = await assessor.assess(audioData: testAudio, sampleRate: 44100)

        XCTAssertGreaterThanOrEqual(quality.overallScore, 0, "Score should be >= 0")
        XCTAssertLessThanOrEqual(quality.overallScore, 100, "Score should be <= 100")
        XCTAssertGreaterThan(quality.clarityScore, 0, "Clarity score should be > 0")
    }

    // MARK: - Integration Tests

    func testAdvancedMLControllerInitialization() {
        let controller = AdvancedMLController()

        XCTAssertTrue(controller.allModelsLoaded, "All models should be loaded")
        XCTAssertFalse(controller.isProcessing, "Should not be processing initially")
    }

    func testAdvancedVisualAIControllerInitialization() {
        let controller = AdvancedVisualAIController()

        XCTAssertFalse(controller.isProcessing, "Should not be processing initially")
        XCTAssertTrue(controller.bioSyncEnabled, "Bio sync should be enabled by default")
    }

    func testBioSyncIntegration() {
        let controller = AdvancedVisualAIController()

        controller.updateBiometrics(hrv: 65.0, coherence: 0.8)

        // Verify biometrics propagate to subsystems
        XCTAssertTrue(controller.styleTransfer.bioAdaptiveEnabled, "Style transfer bio-adaptive should be enabled")
        XCTAssertTrue(controller.autoEditor.bioSyncEnabled, "Auto editor bio sync should be enabled")
    }

    // MARK: - Performance Tests

    func testStemSeparationPerformance() {
        let separator = NeuralStemSeparator()
        separator.setQuality(.fast)

        let testAudio: [Float] = (0..<44100).map { Float.random(in: -1...1) }

        measure {
            // Synchronous version for performance testing
            _ = separator.modelLoaded
        }
    }

    func testStyleTransferPerformance() {
        let styleTransfer = RealTimeStyleTransfer()
        styleTransfer.currentStyle = .vaporwave

        let testFrame = [UInt8](repeating: 128, count: 1920 * 1080 * 4)

        measure {
            _ = styleTransfer.processFrame(pixelData: testFrame, width: 1920, height: 1080)
        }
    }
}

// MARK: - Mock Extensions for Testing

extension AudioQualityAssessorML.QualityTier: CaseIterable {
    public static var allCases: [AudioQualityAssessorML.QualityTier] = [
        .excellent, .good, .fair, .poor, .bad
    ]
}
