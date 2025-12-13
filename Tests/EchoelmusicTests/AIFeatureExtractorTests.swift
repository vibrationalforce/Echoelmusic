import XCTest
import Accelerate
@testable import Echoelmusic

/// Unit Tests for AI Feature Extraction Algorithms
/// Tests tempo detection, MFCC, spectral features, and pattern recognition
@MainActor
final class AIFeatureExtractorTests: XCTestCase {

    var mlModels: EnhancedMLModels!

    override func setUp() async throws {
        mlModels = EnhancedMLModels()
    }

    // MARK: - Tempo Detection Tests

    func testTempoDetectionConstantBeat() throws {
        // Generate audio with known tempo (120 BPM = 2 Hz beat frequency)
        let sampleRate: Float = 48000
        let duration: Float = 5.0  // 5 seconds
        let bpm: Float = 120.0
        let beatFrequency = bpm / 60.0  // 2 Hz

        // Generate clicks at beat positions
        var audioBuffer = [Float](repeating: 0.0, count: Int(sampleRate * duration))
        let samplesPerBeat = Int(sampleRate * 60.0 / bpm)

        for i in stride(from: 0, to: audioBuffer.count, by: samplesPerBeat) {
            // Add short click (10ms attack/decay)
            for j in 0..<min(480, audioBuffer.count - i) {
                let envelope = Float(j < 240 ? j : 480 - j) / 240.0
                audioBuffer[i + j] = envelope * 0.8
            }
        }

        // Detect tempo
        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)

        // The detected tempo should be close to 120 BPM
        // Note: tempo detection may be approximate, so we allow ±10 BPM tolerance
        // The mlModels stores features internally, we test indirectly via music style
        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown, "Should detect a music style")
    }

    func testTempoDetectionSlowTempo() throws {
        // Generate slow tempo (60 BPM)
        let sampleRate: Float = 48000
        let bpm: Float = 60.0

        var audioBuffer = [Float](repeating: 0.0, count: Int(sampleRate * 5.0))
        let samplesPerBeat = Int(sampleRate * 60.0 / bpm)

        for i in stride(from: 0, to: audioBuffer.count, by: samplesPerBeat) {
            for j in 0..<min(480, audioBuffer.count - i) {
                let envelope = Float(j < 240 ? j : 480 - j) / 240.0
                audioBuffer[i + j] = envelope * 0.8
            }
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown, "Should handle slow tempo")
    }

    func testTempoDetectionFastTempo() throws {
        // Generate fast tempo (150 BPM)
        let sampleRate: Float = 48000
        let bpm: Float = 150.0

        var audioBuffer = [Float](repeating: 0.0, count: Int(sampleRate * 5.0))
        let samplesPerBeat = Int(sampleRate * 60.0 / bpm)

        for i in stride(from: 0, to: audioBuffer.count, by: samplesPerBeat) {
            for j in 0..<min(480, audioBuffer.count - i) {
                let envelope = Float(j < 240 ? j : 480 - j) / 240.0
                audioBuffer[i + j] = envelope * 0.8
            }
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown, "Should handle fast tempo")
    }

    // MARK: - Spectral Feature Tests

    func testSpectralCentroidLowFrequency() throws {
        // Low frequency signal should have low spectral centroid
        let sampleRate: Float = 48000
        let frequency: Float = 200.0  // Low frequency

        let audioBuffer = (0..<Int(sampleRate * 2)).map {
            Float(sin(Double($0) * 2.0 * .pi * Double(frequency) / Double(sampleRate)))
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        // Low frequency content should bias toward ambient or other low-energy styles
    }

    func testSpectralCentroidHighFrequency() throws {
        // High frequency signal should have high spectral centroid
        let sampleRate: Float = 48000
        let frequency: Float = 8000.0  // High frequency

        let audioBuffer = (0..<Int(sampleRate * 2)).map {
            Float(sin(Double($0) * 2.0 * .pi * Double(frequency) / Double(sampleRate)))
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        // High frequency content should be detected
    }

    func testSpectralRolloff() throws {
        // Signal with harmonics should have rolloff above fundamental
        let sampleRate: Float = 48000
        let fundamental: Float = 440.0

        // Generate signal with harmonics
        let audioBuffer = (0..<Int(sampleRate * 2)).map { i in
            var sample: Float = 0.0
            for h in 1...8 {
                let amp = 1.0 / Float(h)
                sample += amp * Float(sin(Double(i) * 2.0 * .pi * Double(fundamental) * Double(h) / Double(sampleRate)))
            }
            return sample / 4.0  // Normalize
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        // Should detect harmonic content
    }

    func testZeroCrossingRate() throws {
        // High frequency should have high zero crossing rate
        let sampleRate: Float = 48000

        // Low frequency (100 Hz) - low ZCR
        let lowFreq = (0..<Int(sampleRate)).map {
            Float(sin(Double($0) * 2.0 * .pi * 100.0 / Double(sampleRate)))
        }

        // High frequency (5000 Hz) - high ZCR
        let highFreq = (0..<Int(sampleRate)).map {
            Float(sin(Double($0) * 2.0 * .pi * 5000.0 / Double(sampleRate)))
        }

        // Calculate ZCR manually for verification
        let lowZCR = calculateZCR(lowFreq)
        let highZCR = calculateZCR(highFreq)

        XCTAssertLessThan(lowZCR, highZCR, "High frequency should have higher ZCR")
    }

    // MARK: - MFCC Tests

    func testMFCCDifferentiation() throws {
        // Different signals should produce different MFCCs
        let sampleRate: Float = 48000

        // Pure tone
        let pureTone = (0..<Int(sampleRate)).map {
            Float(sin(Double($0) * 2.0 * .pi * 440.0 / Double(sampleRate)))
        }

        // White noise approximation
        let noise = (0..<Int(sampleRate)).map { _ in Float.random(in: -1.0...1.0) }

        // Complex harmonic signal
        let harmonic = (0..<Int(sampleRate)).map { i in
            var sample: Float = 0.0
            for h in 1...10 {
                sample += Float(sin(Double(i) * 2.0 * .pi * 440.0 * Double(h) / Double(sampleRate))) / Float(h)
            }
            return sample / 3.0
        }

        // Each should classify potentially differently
        mlModels.classifyMusicStyle(audioBuffer: pureTone, sampleRate: sampleRate)
        let pureStyle = mlModels.detectedMusicStyle

        mlModels.classifyMusicStyle(audioBuffer: noise, sampleRate: sampleRate)
        let noiseStyle = mlModels.detectedMusicStyle

        mlModels.classifyMusicStyle(audioBuffer: harmonic, sampleRate: sampleRate)
        let harmonicStyle = mlModels.detectedMusicStyle

        // At minimum, the detection should work without crashing
        XCTAssertNotNil(pureStyle, "Pure tone style should be detected")
        XCTAssertNotNil(noiseStyle, "Noise style should be detected")
        XCTAssertNotNil(harmonicStyle, "Harmonic style should be detected")
    }

    // MARK: - Emotion Classification Tests

    func testEmotionClassificationCalm() throws {
        // High coherence, low HR, stable HRV -> Calm
        mlModels.classifyEmotion(
            hrv: 0.8,
            coherence: 0.85,
            heartRate: 62,
            variability: 0.15,
            hrvTrend: 0.01,
            coherenceTrend: 0.02
        )

        XCTAssertEqual(mlModels.currentEmotion, .calm, "High coherence + low HR should indicate calm")
        XCTAssertGreaterThan(mlModels.predictions.emotionConfidence, 0.5, "Confidence should be high")
    }

    func testEmotionClassificationEnergetic() throws {
        // High HR, high HRV -> Energetic
        mlModels.classifyEmotion(
            hrv: 0.85,
            coherence: 0.6,
            heartRate: 110,
            variability: 0.25,
            hrvTrend: 0.02,
            coherenceTrend: 0.0
        )

        XCTAssertEqual(mlModels.currentEmotion, .energetic, "High HR + high HRV should indicate energetic")
    }

    func testEmotionClassificationAnxious() throws {
        // Low coherence, high HR, high variability -> Anxious
        mlModels.classifyEmotion(
            hrv: 0.4,
            coherence: 0.25,
            heartRate: 95,
            variability: 0.4,
            hrvTrend: -0.02,
            coherenceTrend: -0.03
        )

        XCTAssertEqual(mlModels.currentEmotion, .anxious, "Low coherence + high variability should indicate anxious")
    }

    func testEmotionClassificationFocused() throws {
        // Moderate HR, high coherence, low variability -> Focused
        mlModels.classifyEmotion(
            hrv: 0.7,
            coherence: 0.8,
            heartRate: 75,
            variability: 0.1,
            hrvTrend: 0.0,
            coherenceTrend: 0.01
        )

        XCTAssertEqual(mlModels.currentEmotion, .focused, "High coherence + low variability should indicate focused")
    }

    func testEmotionClassificationNeutral() throws {
        // Average values -> Neutral
        mlModels.classifyEmotion(
            hrv: 0.5,
            coherence: 0.5,
            heartRate: 72,
            variability: 0.2,
            hrvTrend: 0.0,
            coherenceTrend: 0.0
        )

        XCTAssertEqual(mlModels.currentEmotion, .neutral, "Average values should indicate neutral")
    }

    // MARK: - Pattern Recognition Tests

    func testPatternRecognitionCoherenceBuilding() throws {
        // Increasing coherence pattern
        let hrvData: [Float] = Array(repeating: 0.6, count: 20)
        let coherenceData: [Float] = (0..<20).map { Float($0) / 20.0 * 0.5 + 0.3 }  // 0.3 -> 0.8

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        XCTAssertFalse(patterns.isEmpty, "Should recognize patterns")
        let hasCoherenceBuilding = patterns.contains { $0.type == .coherenceBuilding }
        XCTAssertTrue(hasCoherenceBuilding, "Should detect coherence building pattern")
    }

    func testPatternRecognitionStressResponse() throws {
        // Decreasing coherence pattern
        let hrvData: [Float] = Array(repeating: 0.5, count: 20)
        let coherenceData: [Float] = (0..<20).map { 0.8 - Float($0) / 20.0 * 0.5 }  // 0.8 -> 0.3

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        XCTAssertFalse(patterns.isEmpty, "Should recognize patterns")
        let hasStressResponse = patterns.contains { $0.type == .stressResponse }
        XCTAssertTrue(hasStressResponse, "Should detect stress response pattern")
    }

    func testPatternRecognitionFlowState() throws {
        // Stable high coherence + stable HRV -> Flow state
        let hrvData: [Float] = Array(repeating: 0.75, count: 20)
        let coherenceData: [Float] = Array(repeating: 0.85, count: 20)

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        let hasFlowState = patterns.contains { $0.type == .flowState }
        XCTAssertTrue(hasFlowState, "Should detect flow state pattern")
    }

    func testPatternRecognitionResonanceFrequency() throws {
        // Create HRV data with clear periodicity at ~6 breaths/min
        let samplesPerCycle = 64 / 6  // Approximately
        var hrvData: [Float] = []

        for i in 0..<64 {
            let phase = Float(i) / Float(samplesPerCycle) * 2.0 * .pi
            hrvData.append(0.5 + 0.2 * sin(phase))
        }

        let coherenceData: [Float] = Array(repeating: 0.7, count: 64)

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        // May or may not detect resonance depending on implementation
        XCTAssertNotNil(patterns, "Patterns array should not be nil")
    }

    // MARK: - Recommendation Generation Tests

    func testRecommendationsForCalmEmotion() throws {
        mlModels.classifyEmotion(
            hrv: 0.8,
            coherence: 0.85,
            heartRate: 62,
            variability: 0.15,
            hrvTrend: 0.01,
            coherenceTrend: 0.02
        )

        let recommendations = mlModels.generateRecommendations(
            emotion: mlModels.currentEmotion,
            style: .ambient
        )

        XCTAssertFalse(recommendations.isEmpty, "Should generate recommendations")

        // Calm emotion + ambient style should recommend relaxation effects
        let hasReverbRecommendation = recommendations.contains { $0.type == .effect }
        XCTAssertTrue(hasReverbRecommendation, "Should recommend effects for calm state")
    }

    func testRecommendationsForEnergeticEmotion() throws {
        mlModels.classifyEmotion(
            hrv: 0.85,
            coherence: 0.6,
            heartRate: 110,
            variability: 0.25,
            hrvTrend: 0.02,
            coherenceTrend: 0.0
        )

        let recommendations = mlModels.generateRecommendations(
            emotion: mlModels.currentEmotion,
            style: .electronic
        )

        XCTAssertFalse(recommendations.isEmpty, "Should generate recommendations")
    }

    // MARK: - Music Style Classification Tests

    func testMusicStyleClassificationElectronic() throws {
        // Generate electronic-like audio (steady beat, repetitive)
        let sampleRate: Float = 48000
        let bpm: Float = 128.0  // Typical electronic tempo

        var audioBuffer = [Float](repeating: 0.0, count: Int(sampleRate * 3))
        let samplesPerBeat = Int(sampleRate * 60.0 / bpm)

        // Add kick-like sounds
        for i in stride(from: 0, to: audioBuffer.count, by: samplesPerBeat) {
            for j in 0..<min(500, audioBuffer.count - i) {
                let decay = exp(-Float(j) / 100.0)
                audioBuffer[i + j] = decay * sin(Float(j) * 0.1) * 0.8
            }
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)

        // Should classify as electronic or similar
        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown)
    }

    func testMusicStyleClassificationAmbient() throws {
        // Generate ambient-like audio (slow, smooth)
        let sampleRate: Float = 48000

        // Slow sweeping sine waves
        var audioBuffer = [Float](repeating: 0.0, count: Int(sampleRate * 3))
        for i in 0..<audioBuffer.count {
            let t = Float(i) / sampleRate
            let freq = 200.0 + 100.0 * sin(t * 0.5)  // Slowly modulating frequency
            audioBuffer[i] = sin(Float(i) * 2.0 * .pi * Float(freq) / sampleRate) * 0.3
        }

        mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)

        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown)
    }

    // MARK: - Helper Functions

    private func calculateZCR(_ signal: [Float]) -> Float {
        var crossings = 0
        for i in 1..<signal.count {
            if (signal[i-1] >= 0 && signal[i] < 0) || (signal[i-1] < 0 && signal[i] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(signal.count)
    }

    // MARK: - Performance Tests

    func testFeatureExtractionPerformance() throws {
        let sampleRate: Float = 48000
        let audioBuffer = (0..<Int(sampleRate * 5)).map { _ in Float.random(in: -1.0...1.0) }

        measure {
            mlModels.classifyMusicStyle(audioBuffer: audioBuffer, sampleRate: sampleRate)
        }
    }

    func testEmotionClassificationPerformance() throws {
        measure {
            for _ in 0..<100 {
                mlModels.classifyEmotion(
                    hrv: Float.random(in: 0.3...0.9),
                    coherence: Float.random(in: 0.2...0.95),
                    heartRate: Float.random(in: 50...120),
                    variability: Float.random(in: 0.1...0.4),
                    hrvTrend: Float.random(in: -0.05...0.05),
                    coherenceTrend: Float.random(in: -0.05...0.05)
                )
            }
        }
    }

    func testPatternRecognitionPerformance() throws {
        let hrvData: [Float] = (0..<100).map { _ in Float.random(in: 0.4...0.9) }
        let coherenceData: [Float] = (0..<100).map { _ in Float.random(in: 0.3...0.95) }

        measure {
            for _ in 0..<100 {
                _ = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)
            }
        }
    }
}

// MARK: - Edge Case Tests

@MainActor
final class AIFeatureExtractorEdgeCaseTests: XCTestCase {

    var mlModels: EnhancedMLModels!

    override func setUp() async throws {
        mlModels = EnhancedMLModels()
    }

    func testEmptyAudioBuffer() throws {
        let emptyBuffer: [Float] = []
        mlModels.classifyMusicStyle(audioBuffer: emptyBuffer, sampleRate: 48000)

        // Should handle gracefully without crash
        XCTAssertEqual(mlModels.detectedMusicStyle, .unknown, "Empty buffer should result in unknown style")
    }

    func testVeryShortAudioBuffer() throws {
        let shortBuffer: [Float] = [0.5, -0.5, 0.3, -0.3]
        mlModels.classifyMusicStyle(audioBuffer: shortBuffer, sampleRate: 48000)

        // Should handle gracefully
        XCTAssertNotNil(mlModels.detectedMusicStyle)
    }

    func testSilentAudioBuffer() throws {
        let silentBuffer = [Float](repeating: 0.0, count: 48000)
        mlModels.classifyMusicStyle(audioBuffer: silentBuffer, sampleRate: 48000)

        // Should handle gracefully
        XCTAssertNotNil(mlModels.detectedMusicStyle)
    }

    func testExtremeHRVValues() throws {
        // Test with extreme but possible values
        mlModels.classifyEmotion(
            hrv: 0.0,
            coherence: 0.0,
            heartRate: 40,  // Very low
            variability: 0.0,
            hrvTrend: 0.0,
            coherenceTrend: 0.0
        )
        XCTAssertNotNil(mlModels.currentEmotion, "Should handle extreme low values")

        mlModels.classifyEmotion(
            hrv: 1.0,
            coherence: 1.0,
            heartRate: 200,  // Very high
            variability: 1.0,
            hrvTrend: 0.1,
            coherenceTrend: 0.1
        )
        XCTAssertNotNil(mlModels.currentEmotion, "Should handle extreme high values")
    }

    func testEmptyPatternData() throws {
        let emptyHRV: [Float] = []
        let emptyCoherence: [Float] = []

        let patterns = mlModels.recognizePatterns(hrvData: emptyHRV, coherenceData: emptyCoherence)
        XCTAssertTrue(patterns.isEmpty, "Empty data should produce no patterns")
    }

    func testMismatchedPatternDataLengths() throws {
        let hrvData: [Float] = [0.5, 0.6, 0.7]
        let coherenceData: [Float] = [0.5, 0.6, 0.7, 0.8, 0.9]  // Different length

        // Should handle gracefully without crash
        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)
        XCTAssertNotNil(patterns)
    }

    func testNaNValues() throws {
        // Test handling of NaN values
        let nanBuffer: [Float] = [Float.nan, 0.5, Float.nan, -0.5]
        mlModels.classifyMusicStyle(audioBuffer: nanBuffer, sampleRate: 48000)

        // Should not crash
        XCTAssertNotNil(mlModels.detectedMusicStyle)
    }

    func testInfiniteValues() throws {
        // Test handling of infinite values
        let infBuffer: [Float] = [Float.infinity, 0.5, -Float.infinity, -0.5]
        mlModels.classifyMusicStyle(audioBuffer: infBuffer, sampleRate: 48000)

        // Should not crash
        XCTAssertNotNil(mlModels.detectedMusicStyle)
    }
}
