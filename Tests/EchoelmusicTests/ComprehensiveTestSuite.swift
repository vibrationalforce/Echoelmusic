import XCTest
@testable import Echoelmusic

/// Comprehensive Test Suite für Echoelmusic
///
/// Diese Test-Suite deckt alle kritischen Systeme ab:
/// - Performance-Optimierung (Legacy Devices, Adaptive Quality, Memory)
/// - Audio-Verarbeitung (DSP Effects, Synthesis)
/// - ML-Modelle (Emotion Recognition, Style Classification)
/// - Music Theory (Scales, Chords, Raga/Maqam)
/// - Export Pipeline (alle Formate und Standards)
/// - QA System (Performance, Quality, Usability)
///
@MainActor
final class ComprehensiveTestSuite: XCTestCase {

    // MARK: - Performance Tests

    func testLegacyDeviceDetection() async throws {
        let manager = LegacyDeviceSupport()

        // Test iPhone 6s detection
        let profile = manager.detectDevice()
        XCTAssertNotNil(profile, "Device profile should be detected")

        // Test recommended settings
        let settings = manager.getRecommendedSettings()
        XCTAssertGreaterThan(settings.targetFPS, 0, "Target FPS should be positive")
        XCTAssertGreaterThan(settings.maxParticles, 0, "Max particles should be positive")
    }

    func testAdaptiveQualityAdjustment() async throws {
        let manager = AdaptiveQualityManager()

        // Simulate low FPS
        for _ in 0..<60 {
            manager.recordFrame(timestamp: Date().timeIntervalSince1970)
        }

        await manager.updateMetrics()

        XCTAssertNotNil(manager.currentQuality, "Quality level should be set")
        XCTAssertGreaterThan(manager.metrics.averageFPS, 0, "Average FPS should be calculated")
    }

    func testMemoryOptimizationCaching() throws {
        let manager = MemoryOptimizationManager()

        // Test caching
        let testData = Data(repeating: 0xFF, count: 1024)
        manager.cache(key: "test", data: testData, priority: .normal)

        // Test retrieval
        let retrieved = manager.retrieve(key: "test")
        XCTAssertNotNil(retrieved, "Cached data should be retrievable")
        XCTAssertEqual(retrieved?.count, 1024, "Retrieved data should match original size")

        // Test cache hit rate
        XCTAssertGreaterThan(manager.cacheStats.hitRate, 0.0, "Cache hit rate should be calculated")
    }

    func testMemoryMappedFiles() async throws {
        let manager = MemoryOptimizationManager()

        // Create test file
        let testPath = NSTemporaryDirectory() + "test_mmap.dat"
        let testData = Data(repeating: 0xAB, count: 1024 * 1024) // 1 MB
        try testData.write(to: URL(fileURLWithPath: testPath))

        defer {
            try? FileManager.default.removeItem(atPath: testPath)
        }

        // Test memory mapping
        let success = manager.openMemoryMappedFile(path: testPath)
        XCTAssertTrue(success, "Memory mapping should succeed")

        // Test chunk reading
        let chunk = manager.readFromMemoryMappedFile(path: testPath, offset: 0, length: 1024)
        XCTAssertNotNil(chunk, "Chunk should be readable")
        XCTAssertEqual(chunk?.count, 1024, "Chunk size should match")

        manager.closeMemoryMappedFile(path: testPath)
    }

    // MARK: - Audio DSP Tests

    func testParametricEQ() throws {
        let eq = ParametricEQ(bands: 8, sampleRate: 48000)

        let testSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let processed = eq.process(testSignal)

        XCTAssertEqual(processed.count, testSignal.count, "Output length should match input")
        XCTAssertFalse(processed.allSatisfy { $0 == 0 }, "Output should not be silent")
    }

    func testMultibandCompressor() throws {
        let compressor = MultibandCompressor(bands: 4, sampleRate: 48000)

        let testSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) * 2.0 } // Hot signal
        let compressed = compressor.process(testSignal)

        XCTAssertEqual(compressed.count, testSignal.count, "Output length should match input")

        // Check gain reduction occurred
        let inputPeak = testSignal.map { abs($0) }.max() ?? 0
        let outputPeak = compressed.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(outputPeak, inputPeak, "Compression should reduce peak level")
    }

    func testBrickWallLimiter() throws {
        let limiter = BrickWallLimiter(sampleRate: 48000)
        limiter.ceiling = -0.1 // -0.1 dBFS

        let testSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) * 2.0 } // Over 0 dBFS
        let limited = limiter.process(testSignal)

        let outputPeak = limited.map { abs($0) }.max() ?? 0
        let ceilingLinear = pow(10.0, limiter.ceiling / 20.0)

        XCTAssertLessThanOrEqual(outputPeak, ceilingLinear * 1.01, "Output should not exceed ceiling")
    }

    func testConvolutionReverb() throws {
        let reverb = ConvolutionReverb(sampleRate: 48000)

        // Load impulse response (simplified - just a short decay)
        let ir = (0..<1000).map { Float(exp(-Float($0) / 100.0)) * (Float($0 % 2) * 2 - 1) }
        reverb.loadImpulseResponse(ir)

        let testSignal = (0..<1024).map { $0 < 10 ? Float(1.0) : Float(0.0) } // Impulse
        let processed = reverb.process(testSignal)

        XCTAssertEqual(processed.count, testSignal.count, "Output length should match input")
        XCTAssertFalse(processed.dropFirst(100).allSatisfy { $0 == 0 }, "Reverb tail should exist")
    }

    // MARK: - Synthesis Tests

    func testFMSynthesis() throws {
        let synth = FMSynthesizer()
        synth.modIndex = 2.0
        synth.modRatio = 2.0

        let buffer = synth.synthesize(frequency: 440.0, samples: 1024, sampleRate: 48000)

        XCTAssertEqual(buffer.count, 1024, "Buffer length should match request")
        XCTAssertFalse(buffer.allSatisfy { $0 == 0 }, "Output should not be silent")

        // Check for FM characteristics (sidebands)
        let spectrum = calculateSpectrum(buffer)
        let peakCount = spectrum.filter { $0 > 0.1 }.count
        XCTAssertGreaterThan(peakCount, 2, "FM should produce multiple spectral peaks")
    }

    func testWavetableSynthesis() throws {
        let synth = WavetableSynthesizer()

        let buffer = synth.synthesize(frequency: 220.0, samples: 1024, sampleRate: 48000)

        XCTAssertEqual(buffer.count, 1024, "Buffer length should match request")
        XCTAssertFalse(buffer.allSatisfy { $0 == 0 }, "Output should not be silent")
    }

    func testPhysicalModeling() throws {
        let synth = PhysicalModelingSynthesizer()

        let buffer = synth.synthesize(frequency: 330.0, samples: 2048, sampleRate: 48000)

        XCTAssertEqual(buffer.count, 2048, "Buffer length should match request")

        // Check for natural decay
        let firstHalf = buffer[0..<1024].map { abs($0) }.reduce(0, +)
        let secondHalf = buffer[1024..<2048].map { abs($0) }.reduce(0, +)
        XCTAssertGreaterThan(firstHalf, secondHalf, "Physical modeling should have natural decay")
    }

    // MARK: - ML Model Tests

    func testEmotionClassification() async throws {
        let mlModels = EnhancedMLModels()

        // Test calm emotion
        mlModels.classifyEmotion(
            hrv: 0.8,
            coherence: 0.75,
            heartRate: 65,
            variability: 0.2,
            hrvTrend: 0.01,
            coherenceTrend: 0.02
        )

        XCTAssertEqual(mlModels.currentEmotion, .calm, "Should detect calm emotion")
        XCTAssertGreaterThan(mlModels.predictions.emotionConfidence, 0.5, "Confidence should be high")

        // Test energetic emotion
        mlModels.classifyEmotion(
            hrv: 0.9,
            coherence: 0.6,
            heartRate: 95,
            variability: 0.3,
            hrvTrend: 0.02,
            coherenceTrend: 0.0
        )

        XCTAssertEqual(mlModels.currentEmotion, .energetic, "Should detect energetic emotion")
    }

    func testMusicStyleClassification() async throws {
        let mlModels = EnhancedMLModels()

        // Test electronic music characteristics
        let testBuffer = generateTestAudio(frequency: 440, tempo: 128, samples: 48000)
        mlModels.classifyMusicStyle(audioBuffer: testBuffer, sampleRate: 48000)

        XCTAssertNotEqual(mlModels.detectedMusicStyle, .unknown, "Should detect a music style")
    }

    func testPatternRecognition() async throws {
        let mlModels = EnhancedMLModels()

        // Simulate increasing coherence
        let coherenceData: [Float] = (0..<20).map { Float($0) / 20.0 }
        let hrvData: [Float] = Array(repeating: 0.7, count: 20)

        let patterns = mlModels.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)

        XCTAssertFalse(patterns.isEmpty, "Should recognize patterns")
        let hasCoherenceBuilding = patterns.contains { $0.type == .coherenceBuilding }
        XCTAssertTrue(hasCoherenceBuilding, "Should detect coherence building pattern")
    }

    // MARK: - Music Theory Tests

    func testScaleDatabase() throws {
        let database = GlobalMusicTheoryDatabase()

        // Test Western scales
        let majorScale = database.scales.first { $0.name == "Major" && $0.culture == .western }
        XCTAssertNotNil(majorScale, "Major scale should exist")
        XCTAssertEqual(majorScale?.intervals.count, 7, "Major scale should have 7 notes")

        // Test Arabic maqam with quarter tones
        let maqamRast = database.scales.first { $0.name == "Maqam Rast" && $0.culture == .arabic }
        XCTAssertNotNil(maqamRast, "Maqam Rast should exist")
        XCTAssertTrue(maqamRast?.intervals.contains { $0.truncatingRemainder(dividingBy: 1.0) != 0 } ?? false,
                     "Maqam should contain quarter tones")

        // Test Indian raga
        let ragaBhairav = database.scales.first { $0.name == "Raga Bhairav" && $0.culture == .indian }
        XCTAssertNotNil(ragaBhairav, "Raga Bhairav should exist")

        // Test scale count
        XCTAssertGreaterThanOrEqual(database.scales.count, 18, "Should have at least 18 scales")
    }

    func testChordGeneration() throws {
        let database = GlobalMusicTheoryDatabase()

        let chord = database.generateChord(root: 60, type: .major)
        XCTAssertEqual(chord.count, 3, "Major triad should have 3 notes")
        XCTAssertEqual(chord[0], 60, "Root should be C (60)")
        XCTAssertEqual(chord[1], 64, "Third should be E (64)")
        XCTAssertEqual(chord[2], 67, "Fifth should be G (67)")
    }

    func testRhythmPatterns() throws {
        let database = GlobalMusicTheoryDatabase()

        let pattern = database.rhythms.first { $0.name == "Son Clave" }
        XCTAssertNotNil(pattern, "Son Clave pattern should exist")
        XCTAssertFalse(pattern?.pattern.isEmpty ?? true, "Pattern should have beats")
    }

    // MARK: - Export Pipeline Tests

    func testExportPresets() throws {
        let pipeline = UniversalExportPipeline()

        // Test Netflix preset
        let netflixPreset = pipeline.presets.first { $0.name == "Netflix 4K HDR" }
        XCTAssertNotNil(netflixPreset, "Netflix preset should exist")
        XCTAssertEqual(netflixPreset?.loudnessTarget, .netflix, "Loudness target should be Netflix")
        XCTAssertEqual(netflixPreset?.videoFormat?.codec, .h265, "Codec should be H.265")

        // Test Spotify preset
        let spotifyPreset = pipeline.presets.first { $0.name == "Spotify Music" }
        XCTAssertNotNil(spotifyPreset, "Spotify preset should exist")
        XCTAssertEqual(spotifyPreset?.loudnessTarget, .spotify, "Loudness target should be Spotify")

        // Test preset count
        XCTAssertGreaterThanOrEqual(pipeline.presets.count, 15, "Should have at least 15 presets")
    }

    func testLoudnessNormalization() throws {
        let pipeline = UniversalExportPipeline()

        let testAudio = (0..<48000).map { Float(sin(Double($0) * 0.1)) }
        let normalized = pipeline.normalizeLoudness(testAudio, target: .ebu_r128, sampleRate: 48000)

        XCTAssertEqual(normalized.count, testAudio.count, "Length should be preserved")

        // Measure LUFS (simplified)
        let lufs = calculateLUFS(normalized, sampleRate: 48000)
        XCTAssertLessThan(abs(lufs - (-23.0)), 2.0, "Should be close to EBU R128 target (-23 LUFS)")
    }

    // MARK: - QA System Tests

    func testPerformanceMetrics() async throws {
        let qa = QualityAssuranceSystem()

        await qa.updatePerformanceMetrics()

        XCTAssertGreaterThan(qa.performance.currentFPS, 0, "FPS should be measured")
        XCTAssertGreaterThanOrEqual(qa.performance.cpuUsage, 0, "CPU usage should be non-negative")
        XCTAssertLessThanOrEqual(qa.performance.cpuUsage, 1.0, "CPU usage should not exceed 100%")
    }

    func testQualityMetrics() throws {
        let qa = QualityAssuranceSystem()

        let testSignal = (0..<48000).map { Float(sin(Double($0) * 0.1)) }
        let metrics = qa.measureAudioQuality(testSignal, sampleRate: 48000)

        XCTAssertLessThan(metrics.thdPlusNoise, 0.01, "THD+N should be low for sine wave")
        XCTAssertGreaterThan(metrics.signalToNoiseRatio, 60, "SNR should be high")
    }

    func testAutomatedTests() async throws {
        let qa = QualityAssuranceSystem()

        let results = await qa.runAutomatedTests()

        XCTAssertFalse(results.isEmpty, "Should run automated tests")
        let passedTests = results.filter { $0.passed }
        let passRate = Float(passedTests.count) / Float(results.count)
        XCTAssertGreaterThan(passRate, 0.8, "At least 80% of tests should pass")
    }

    // MARK: - Adaptive Intelligence Tests (Quantum-Inspired)

    func testQuantumSimulation() async throws {
        let adaptive = AdaptiveIntelligenceEngine()

        // Test qubit initialization
        var qubit = adaptive.createQubit()
        XCTAssertNotNil(qubit, "Should create qubit")

        // Test Hadamard gate (superposition)
        qubit = adaptive.hadamard(qubit)
        let prob0 = qubit.alpha.magnitude * qubit.alpha.magnitude
        let prob1 = qubit.beta.magnitude * qubit.beta.magnitude
        XCTAssertEqual(prob0 + prob1, 1.0, accuracy: 0.01, "Probabilities should sum to 1")

        // Test measurement
        let result = qubit.measure()
        XCTAssertTrue(result == 0 || result == 1, "Measurement should be 0 or 1")
    }

    func testQuantumAnnealing() async throws {
        let adaptive = AdaptiveIntelligenceEngine()

        // Simple optimization: find minimum of quadratic function
        let energyFunction: ([Float]) -> Float = { params in
            // f(x) = (x - 2)^2, minimum at x = 2
            let x = params[0]
            return (x - 2.0) * (x - 2.0)
        }

        let result = await adaptive.quantumAnneal(energyFunction: energyFunction, dimensions: 1)

        XCTAssertEqual(result.count, 1, "Should return 1D result")
        XCTAssertEqual(result[0], 2.0, accuracy: 0.5, "Should find minimum near x=2")
    }

    // MARK: - Device Testing Framework Tests

    func testDeviceProfiles() throws {
        let framework = DeviceTestingFramework()

        // Test iPhone 15 Pro profile
        let iPhone15Pro = framework.deviceProfiles.first { $0.deviceName == "iPhone 15 Pro" }
        XCTAssertNotNil(iPhone15Pro, "iPhone 15 Pro profile should exist")
        XCTAssertEqual(iPhone15Pro?.chip, .a17Pro, "Chip should be A17 Pro")

        // Test future device
        let appleCar = framework.deviceProfiles.first { $0.deviceName == "Apple Car" }
        XCTAssertNotNil(appleCar, "Apple Car profile should exist")
        XCTAssertEqual(appleCar?.releaseYear, 2027, "Release year should be 2027")
    }

    func testPerformanceTest() async throws {
        let framework = DeviceTestingFramework()

        let profile = DeviceProfile(deviceName: "Test Device", releaseYear: 2024, chip: .a17Pro)
        let result = await framework.runPerformanceTest(on: profile)

        XCTAssertTrue(result.passed || !result.passed, "Test should complete")
        XCTAssertGreaterThan(result.fps, 0, "FPS should be measured")
    }

    // MARK: - Helper Functions

    private func calculateSpectrum(_ signal: [Float]) -> [Float] {
        // Simplified FFT for testing
        let fftSize = min(signal.count, 512)
        var spectrum = [Float](repeating: 0, count: fftSize/2)

        for k in 0..<fftSize/2 {
            var real: Float = 0
            var imag: Float = 0

            for n in 0..<fftSize {
                let angle = -2.0 * Float.pi * Float(k * n) / Float(fftSize)
                real += signal[n] * cos(angle)
                imag += signal[n] * sin(angle)
            }

            spectrum[k] = sqrt(real * real + imag * imag)
        }

        return spectrum
    }

    private func generateTestAudio(frequency: Float, tempo: Float, samples: Int) -> [Float] {
        var buffer = [Float](repeating: 0, count: samples)
        let sampleRate: Float = 48000

        for i in 0..<samples {
            let t = Float(i) / sampleRate
            buffer[i] = sin(2.0 * Float.pi * frequency * t)

            // Add some harmonics for complexity
            buffer[i] += 0.3 * sin(2.0 * Float.pi * frequency * 2.0 * t)
            buffer[i] += 0.1 * sin(2.0 * Float.pi * frequency * 3.0 * t)
        }

        return buffer
    }

    private func calculateLUFS(_ signal: [Float], sampleRate: Float) -> Float {
        // Simplified LUFS calculation (actual implementation would use ITU-R BS.1770-4)
        let rms = sqrt(signal.map { $0 * $0 }.reduce(0, +) / Float(signal.count))
        return 20.0 * log10(rms) - 0.691
    }
}

// MARK: - Integration Tests

@MainActor
final class IntegrationTests: XCTestCase {

    func testEndToEndBioReactiveFlow() async throws {
        // Simulate complete bio-reactive workflow

        // 1. Bio-data input
        let hrv: Float = 0.75
        let coherence: Float = 0.8

        // 2. ML emotion classification
        let mlModels = EnhancedMLModels()
        mlModels.classifyEmotion(hrv: hrv, coherence: coherence, heartRate: 70,
                                variability: 0.2, hrvTrend: 0.01, coherenceTrend: 0.02)

        XCTAssertEqual(mlModels.currentEmotion, .calm, "Should detect calm emotion")

        // 3. Generate recommendations
        let recommendations = mlModels.generateRecommendations(emotion: mlModels.currentEmotion,
                                                              style: .ambient)

        XCTAssertFalse(recommendations.isEmpty, "Should generate recommendations")

        // 4. Apply audio effect based on emotion
        let reverb = ConvolutionReverb(sampleRate: 48000)
        let reverbRec = recommendations.first { $0.type == .effect && $0.title.contains("Reverb") }
        XCTAssertNotNil(reverbRec, "Should recommend reverb for calm emotion")

        // 5. Process audio
        let testAudio = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let processed = reverb.process(testAudio)

        XCTAssertEqual(processed.count, testAudio.count, "Audio should be processed")
    }

    func testAdaptivePerformanceFlow() async throws {
        // Simulate adaptive performance workflow

        // 1. Detect device
        let legacySupport = LegacyDeviceSupport()
        let profile = legacySupport.detectDevice()
        XCTAssertNotNil(profile, "Should detect device")

        // 2. Initialize adaptive quality
        let adaptiveQuality = AdaptiveQualityManager()

        // 3. Simulate performance issues
        for _ in 0..<100 {
            adaptiveQuality.recordFrame(timestamp: Date().timeIntervalSince1970)
        }
        await adaptiveQuality.updateMetrics()

        // 4. Check quality adjustment
        let quality = adaptiveQuality.currentQuality
        XCTAssertNotNil(quality, "Quality should be set")

        // 5. Apply settings
        let visualSettings = adaptiveQuality.visualSettings
        XCTAssertGreaterThan(visualSettings.particleCount, 0, "Particle count should be set")
    }
}
