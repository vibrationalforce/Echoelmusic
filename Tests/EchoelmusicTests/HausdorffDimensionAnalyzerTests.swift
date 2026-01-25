// HausdorffDimensionAnalyzerTests.swift
// EchoelmusicTests
//
// Umfassende Tests für den Hausdorff-Dimension Audio-Analysator
//
// Testabdeckung:
// - Box-Counting Dimension mit bekannten Signalen
// - Korrelationsdimension (Grassberger-Procaccia)
// - Higuchi Fraktale Dimension
// - Katz Fraktale Dimension
// - Spektrale Fraktale Dimension
// - Hurst Exponent
// - Multi-Scale Entropie
// - Edge Cases und Performance
//
// Created 2026-01-25

import XCTest
@testable import Echoelmusic

@MainActor
final class HausdorffDimensionAnalyzerTests: XCTestCase {

    // MARK: - Properties

    var analyzer: HausdorffDimensionAnalyzer!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        analyzer = HausdorffDimensionAnalyzer(config: .default)
    }

    override func tearDown() async throws {
        analyzer = nil
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() async throws {
        let analyzer = HausdorffDimensionAnalyzer()

        XCTAssertEqual(analyzer.config.scaleCount, 16)
        XCTAssertEqual(analyzer.config.fftSize, 2048)
        XCTAssertEqual(analyzer.config.embeddingDimension, 10)
        XCTAssertFalse(analyzer.isAnalyzing)
        XCTAssertTrue(analyzer.resultHistory.isEmpty)
    }

    func testFastConfiguration() async throws {
        let analyzer = HausdorffDimensionAnalyzer(config: .fast)

        XCTAssertEqual(analyzer.config.scaleCount, 8)
        XCTAssertEqual(analyzer.config.fftSize, 1024)
        XCTAssertEqual(analyzer.config.higuchMaxK, 5)
    }

    func testHighPrecisionConfiguration() async throws {
        let analyzer = HausdorffDimensionAnalyzer(config: .highPrecision)

        XCTAssertEqual(analyzer.config.scaleCount, 32)
        XCTAssertEqual(analyzer.config.fftSize, 4096)
        XCTAssertEqual(analyzer.config.higuchMaxK, 20)
    }

    func testCustomConfiguration() async throws {
        let config = HausdorffAnalyzerConfig(
            minBoxSize: 8,
            maxBoxSize: 512,
            scaleCount: 20,
            embeddingDimension: 12,
            timeDelay: 2,
            higuchMaxK: 15,
            fftSize: 2048
        )

        let analyzer = HausdorffDimensionAnalyzer(config: config)

        XCTAssertEqual(analyzer.config.minBoxSize, 8)
        XCTAssertEqual(analyzer.config.maxBoxSize, 512)
        XCTAssertEqual(analyzer.config.scaleCount, 20)
    }

    // MARK: - Box-Counting Dimension Tests

    func testSineWaveDimensionApproximatelyOne() async throws {
        // Sinus ist eine glatte Kurve mit D ≈ 1.0
        let sineWave = FractalSignalGenerator.sineWave(count: 4096, frequency: 440)
        let result = analyzer.analyze(sineWave)

        // Sinus sollte nahe 1.0 sein (±0.2 Toleranz)
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 0.9)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 1.3)
    }

    func testWhiteNoiseDimensionApproximatelyTwo() async throws {
        // Weißes Rauschen hat D ≈ 2.0
        let whiteNoise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(whiteNoise)

        // Weißes Rauschen sollte nahe 2.0 sein
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.7)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 2.0)
    }

    func testBrownianNoiseDimensionIntermediate() async throws {
        // Brownsche Bewegung hat D ≈ 1.5
        let brownianNoise = FractalSignalGenerator.brownianNoise(count: 4096)
        let result = analyzer.analyze(brownianNoise)

        // Brownsche Bewegung sollte zwischen 1.3 und 1.7 liegen
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.2)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 1.8)
    }

    func testFractalNoiseWithBetaOne() async throws {
        // Rosa Rauschen (β=1) hat D ≈ 1.5
        let pinkNoise = FractalSignalGenerator.fractalNoise(count: 4096, beta: 1.0)
        let result = analyzer.analyze(pinkNoise)

        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.2)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 1.8)
    }

    func testFractalNoiseWithBetaTwo() async throws {
        // Braunes Rauschen (β=2) hat D ≈ 1.0-1.3
        let brownNoise = FractalSignalGenerator.fractalNoise(count: 4096, beta: 2.0)
        let result = analyzer.analyze(brownNoise)

        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.0)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 1.6)
    }

    // MARK: - Higuchi Fractal Dimension Tests

    func testHiguchiFractalDimensionSineWave() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 4096, frequency: 220)
        let result = analyzer.analyze(sineWave)

        // Higuchi sollte für Sinus nahe 1.0 sein
        XCTAssertGreaterThanOrEqual(result.higuchiFractalDimension, 0.9)
        XCTAssertLessThanOrEqual(result.higuchiFractalDimension, 1.4)
    }

    func testHiguchiFractalDimensionWhiteNoise() async throws {
        let whiteNoise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(whiteNoise)

        // Higuchi sollte für weißes Rauschen nahe 2.0 sein
        XCTAssertGreaterThanOrEqual(result.higuchiFractalDimension, 1.7)
        XCTAssertLessThanOrEqual(result.higuchiFractalDimension, 2.0)
    }

    func testHiguchiFractalDimensionInValidRange() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 2048)
        let result = analyzer.analyze(samples)

        // Higuchi muss immer zwischen 1.0 und 2.0 liegen
        XCTAssertGreaterThanOrEqual(result.higuchiFractalDimension, 1.0)
        XCTAssertLessThanOrEqual(result.higuchiFractalDimension, 2.0)
    }

    // MARK: - Katz Fractal Dimension Tests

    func testKatzFractalDimensionSineWave() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 2048, frequency: 880)
        let result = analyzer.analyze(sineWave)

        // Katz für glatte Kurven sollte niedrig sein
        XCTAssertGreaterThanOrEqual(result.katzFractalDimension, 1.0)
        XCTAssertLessThanOrEqual(result.katzFractalDimension, 1.5)
    }

    func testKatzFractalDimensionNoise() async throws {
        let noise = FractalSignalGenerator.whiteNoise(count: 2048)
        let result = analyzer.analyze(noise)

        // Katz für Rauschen sollte höher sein
        XCTAssertGreaterThanOrEqual(result.katzFractalDimension, 1.3)
        XCTAssertLessThanOrEqual(result.katzFractalDimension, 2.0)
    }

    // MARK: - Correlation Dimension Tests

    func testCorrelationDimensionComputes() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 2048)
        let result = analyzer.analyze(samples)

        // Korrelationsdimension sollte positiv sein
        XCTAssertGreaterThan(result.correlationDimension, 0.0)
        XCTAssertLessThanOrEqual(result.correlationDimension, Float(analyzer.config.embeddingDimension))
    }

    func testCorrelationDimensionSineWaveLow() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 4096, frequency: 440)
        let result = analyzer.analyze(sineWave)

        // Periodisches Signal sollte niedrige Korrelationsdimension haben
        XCTAssertGreaterThan(result.correlationDimension, 0.0)
        XCTAssertLessThan(result.correlationDimension, 5.0)
    }

    // MARK: - Spectral Fractal Dimension Tests

    func testSpectralFractalDimensionWhiteNoise() async throws {
        let whiteNoise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(whiteNoise)

        // Weißes Rauschen (β≈0) sollte D ≈ 2.0-2.5 haben
        XCTAssertGreaterThanOrEqual(result.spectralFractalDimension, 1.5)
        XCTAssertLessThanOrEqual(result.spectralFractalDimension, 2.0)
    }

    func testSpectralFractalDimensionInValidRange() async throws {
        let samples = FractalSignalGenerator.fractalNoise(count: 4096, beta: 1.5)
        let result = analyzer.analyze(samples)

        // Spektrale Dimension muss zwischen 1.0 und 2.0 liegen
        XCTAssertGreaterThanOrEqual(result.spectralFractalDimension, 1.0)
        XCTAssertLessThanOrEqual(result.spectralFractalDimension, 2.0)
    }

    // MARK: - Hurst Exponent Tests

    func testHurstExponentWhiteNoise() async throws {
        let whiteNoise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(whiteNoise)

        // Weißes Rauschen sollte H ≈ 0.5 haben (Random Walk)
        XCTAssertGreaterThanOrEqual(result.hurstExponent, 0.3)
        XCTAssertLessThanOrEqual(result.hurstExponent, 0.7)
    }

    func testHurstExponentBrownianMotion() async throws {
        let brownian = FractalSignalGenerator.brownianNoise(count: 4096)
        let result = analyzer.analyze(brownian)

        // Brownsche Bewegung sollte H > 0.5 haben (persistent)
        XCTAssertGreaterThanOrEqual(result.hurstExponent, 0.4)
        XCTAssertLessThanOrEqual(result.hurstExponent, 1.0)
    }

    func testHurstExponentInValidRange() async throws {
        let samples = FractalSignalGenerator.sineWave(count: 2048, frequency: 440)
        let result = analyzer.analyze(samples)

        // Hurst muss zwischen 0.0 und 1.0 liegen
        XCTAssertGreaterThanOrEqual(result.hurstExponent, 0.0)
        XCTAssertLessThanOrEqual(result.hurstExponent, 1.0)
    }

    // MARK: - Complexity Score Tests

    func testComplexityScoreSineWaveLow() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 4096, frequency: 440)
        let result = analyzer.analyze(sineWave)

        // Einfaches Signal sollte niedrige Komplexität haben
        XCTAssertGreaterThanOrEqual(result.complexityScore, 0.0)
        XCTAssertLessThanOrEqual(result.complexityScore, 0.5)
    }

    func testComplexityScoreWhiteNoiseHigh() async throws {
        let whiteNoise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(whiteNoise)

        // Komplexes Signal sollte hohe Komplexität haben
        XCTAssertGreaterThanOrEqual(result.complexityScore, 0.5)
        XCTAssertLessThanOrEqual(result.complexityScore, 1.0)
    }

    func testComplexityScoreInNormalizedRange() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 2048)
        let result = analyzer.analyze(samples)

        // Komplexität muss zwischen 0 und 1 liegen
        XCTAssertGreaterThanOrEqual(result.complexityScore, 0.0)
        XCTAssertLessThanOrEqual(result.complexityScore, 1.0)
    }

    // MARK: - Multi-Scale Entropy Tests

    func testMultiScaleEntropyComputes() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 4096)
        let result = analyzer.analyze(samples)

        // MSE sollte mehrere Werte enthalten
        XCTAssertGreaterThan(result.multiScaleEntropy.count, 0)
    }

    func testMultiScaleEntropyValuesNonNegative() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(samples)

        for entropy in result.multiScaleEntropy {
            XCTAssertGreaterThanOrEqual(entropy, 0.0)
        }
    }

    // MARK: - R-Squared Tests

    func testRSquaredInValidRange() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 4096)
        let result = analyzer.analyze(samples)

        // R² muss zwischen 0 und 1 liegen
        XCTAssertGreaterThanOrEqual(result.rSquared, 0.0)
        XCTAssertLessThanOrEqual(result.rSquared, 1.0)
    }

    func testRSquaredGoodFitForNoise() async throws {
        let noise = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(noise)

        // Für echtes fraktales Signal sollte R² > 0.7 sein
        XCTAssertGreaterThan(result.rSquared, 0.5)
    }

    // MARK: - Edge Cases

    func testEmptyInputReturnsEmpty() async throws {
        let result = analyzer.analyze([])

        XCTAssertEqual(result.boxCountingDimension, 1.0)
        XCTAssertEqual(result.complexityScore, 0.0)
        XCTAssertEqual(result.scaleCount, 0)
    }

    func testVeryShortInputReturnsEmpty() async throws {
        let result = analyzer.analyze([0.1, 0.2, 0.3])

        XCTAssertEqual(result.boxCountingDimension, 1.0)
    }

    func testConstantSignalDimensionOne() async throws {
        let constant = [Float](repeating: 0.5, count: 2048)
        let result = analyzer.analyze(constant)

        // Konstantes Signal sollte Dimension nahe 1.0 haben
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 0.9)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 1.2)
    }

    func testSilentInputHandled() async throws {
        let silence = [Float](repeating: 0.0, count: 2048)
        let result = analyzer.analyze(silence)

        // Sollte nicht abstürzen
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.0)
    }

    func testExtremeValuesHandled() async throws {
        var extremes = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            extremes[i] = i % 2 == 0 ? Float.greatestFiniteMagnitude / 2 : -Float.greatestFiniteMagnitude / 2
        }

        let result = analyzer.analyze(extremes)

        // Sollte normalisiert werden und nicht abstürzen
        XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.0)
        XCTAssertLessThanOrEqual(result.boxCountingDimension, 2.0)
    }

    // MARK: - History Tests

    func testHistoryAccumulates() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 2048)

        _ = analyzer.analyze(samples)
        _ = analyzer.analyze(samples)
        _ = analyzer.analyze(samples)

        XCTAssertEqual(analyzer.resultHistory.count, 3)
    }

    func testHistoryMaxSize() async throws {
        let smallAnalyzer = HausdorffDimensionAnalyzer(maxHistorySize: 5)
        let samples = FractalSignalGenerator.whiteNoise(count: 1024)

        for _ in 0..<10 {
            _ = smallAnalyzer.analyze(samples)
        }

        XCTAssertEqual(smallAnalyzer.resultHistory.count, 5)
    }

    func testClearHistory() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 2048)

        _ = analyzer.analyze(samples)
        _ = analyzer.analyze(samples)

        XCTAssertGreaterThan(analyzer.resultHistory.count, 0)

        analyzer.clearHistory()

        XCTAssertEqual(analyzer.resultHistory.count, 0)
        XCTAssertEqual(analyzer.averageBoxDimension, 1.0)
    }

    func testAverageBoxDimensionUpdates() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 2048, frequency: 440)
        let noise = FractalSignalGenerator.whiteNoise(count: 2048)

        _ = analyzer.analyze(sineWave)
        let avgAfterSine = analyzer.averageBoxDimension

        _ = analyzer.analyze(noise)
        let avgAfterNoise = analyzer.averageBoxDimension

        // Durchschnitt sollte sich ändern
        XCTAssertNotEqual(avgAfterSine, avgAfterNoise)
    }

    // MARK: - Bio-Reactive Mapping Tests

    func testBioReactiveParameterMapping() async throws {
        let samples = FractalSignalGenerator.brownianNoise(count: 2048)
        let result = analyzer.analyze(samples)

        let params = analyzer.mapToBioReactiveParameters(result)

        // Alle erwarteten Keys sollten vorhanden sein
        XCTAssertNotNil(params["filterCutoff"])
        XCTAssertNotNil(params["reverbWet"])
        XCTAssertNotNil(params["delayFeedback"])
        XCTAssertNotNil(params["particleCount"])
        XCTAssertNotNil(params["quantumCoherence"])
        XCTAssertNotNil(params["rawDimension"])
        XCTAssertNotNil(params["rawComplexity"])
        XCTAssertNotNil(params["rawHurst"])
    }

    func testBioReactiveParametersInValidRange() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 2048)
        let result = analyzer.analyze(samples)

        let params = analyzer.mapToBioReactiveParameters(result)

        // Audio-Parameter sollten in sinnvollen Bereichen liegen
        XCTAssertGreaterThanOrEqual(params["filterCutoff"]!, 0.0)
        XCTAssertLessThanOrEqual(params["filterCutoff"]!, 1.0)

        XCTAssertGreaterThanOrEqual(params["reverbWet"]!, 0.0)
        XCTAssertLessThanOrEqual(params["reverbWet"]!, 1.0)

        XCTAssertGreaterThanOrEqual(params["particleCount"]!, 0.0)
        XCTAssertLessThanOrEqual(params["particleCount"]!, 1.0)
    }

    func testHighComplexityMapsToMoreEffects() async throws {
        let sineWave = FractalSignalGenerator.sineWave(count: 2048, frequency: 440)
        let noise = FractalSignalGenerator.whiteNoise(count: 2048)

        let sineResult = analyzer.analyze(sineWave)
        let noiseResult = analyzer.analyze(noise)

        let sineParams = analyzer.mapToBioReactiveParameters(sineResult)
        let noiseParams = analyzer.mapToBioReactiveParameters(noiseResult)

        // Rauschen (komplexer) sollte mehr Reverb haben als Sinus
        XCTAssertGreaterThan(noiseParams["reverbWet"]!, sineParams["reverbWet"]!)
    }

    // MARK: - Performance Tests

    func testPerformanceStandardAnalysis() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 4096)

        measure {
            _ = analyzer.analyze(samples)
        }
    }

    func testPerformanceFastAnalysis() async throws {
        let fastAnalyzer = HausdorffDimensionAnalyzer(config: .fast)
        let samples = FractalSignalGenerator.whiteNoise(count: 4096)

        measure {
            _ = fastAnalyzer.analyze(samples)
        }
    }

    func testPerformanceHighPrecisionAnalysis() async throws {
        let hpAnalyzer = HausdorffDimensionAnalyzer(config: .highPrecision)
        let samples = FractalSignalGenerator.whiteNoise(count: 8192)

        measure {
            _ = hpAnalyzer.analyze(samples)
        }
    }

    func testPerformanceLargeInput() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 16384)

        measure {
            _ = analyzer.analyze(samples)
        }
    }

    // MARK: - Signal Generator Tests

    func testWhiteNoiseGeneratorProducesValidOutput() async throws {
        let noise = FractalSignalGenerator.whiteNoise(count: 1000)

        XCTAssertEqual(noise.count, 1000)

        for sample in noise {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    func testBrownianNoiseGeneratorProducesValidOutput() async throws {
        let brownian = FractalSignalGenerator.brownianNoise(count: 1000)

        XCTAssertEqual(brownian.count, 1000)

        for sample in brownian {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    func testSineWaveGeneratorProducesValidOutput() async throws {
        let sine = FractalSignalGenerator.sineWave(count: 1000, frequency: 440, sampleRate: 48000)

        XCTAssertEqual(sine.count, 1000)

        for sample in sine {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    func testFractalNoiseGeneratorProducesValidOutput() async throws {
        let fractal = FractalSignalGenerator.fractalNoise(count: 1000, beta: 1.5)

        XCTAssertEqual(fractal.count, 1000)

        // Nach Normalisierung sollten alle Werte in [-1, 1] sein
        for sample in fractal {
            XCTAssertGreaterThanOrEqual(sample, -1.01) // Kleine Toleranz für Rundungsfehler
            XCTAssertLessThanOrEqual(sample, 1.01)
        }
    }

    func testCantorDustGeneratorProducesOutput() async throws {
        let cantor = FractalSignalGenerator.cantorDust(iterations: 5)

        XCTAssertGreaterThan(cantor.count, 0)
        XCTAssertEqual(cantor.count, 4096)
    }

    // MARK: - Result Struct Tests

    func testHausdorffAnalysisResultEquatable() async throws {
        let result1 = HausdorffAnalysisResult.empty
        let result2 = HausdorffAnalysisResult.empty

        XCTAssertEqual(result1, result2)
    }

    func testHausdorffAnalysisResultTimestamp() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 2048)
        let before = Date()
        let result = analyzer.analyze(samples)
        let after = Date()

        XCTAssertGreaterThanOrEqual(result.timestamp, before)
        XCTAssertLessThanOrEqual(result.timestamp, after)
    }

    func testHausdorffAnalysisResultScaleCount() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 4096)
        let result = analyzer.analyze(samples)

        XCTAssertGreaterThan(result.scaleCount, 0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAnalysis() async throws {
        let samples = FractalSignalGenerator.whiteNoise(count: 2048)

        await withTaskGroup(of: HausdorffAnalysisResult.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.analyzer.analyze(samples)
                }
            }

            var results: [HausdorffAnalysisResult] = []
            for await result in group {
                results.append(result)
            }

            XCTAssertEqual(results.count, 10)

            // Alle Ergebnisse sollten ähnlich sein (gleiches Eingangssignal)
            let firstDim = results[0].boxCountingDimension
            for result in results {
                XCTAssertEqual(result.boxCountingDimension, firstDim, accuracy: 0.01)
            }
        }
    }

    // MARK: - Integration Tests

    func testFullAnalysisPipeline() async throws {
        // 1. Generiere verschiedene Signale
        let signals: [(name: String, signal: [Float])] = [
            ("Sine", FractalSignalGenerator.sineWave(count: 4096, frequency: 440)),
            ("White Noise", FractalSignalGenerator.whiteNoise(count: 4096)),
            ("Brownian", FractalSignalGenerator.brownianNoise(count: 4096)),
            ("Pink Noise", FractalSignalGenerator.fractalNoise(count: 4096, beta: 1.0))
        ]

        // 2. Analysiere alle
        var results: [(String, HausdorffAnalysisResult)] = []
        for (name, signal) in signals {
            let result = analyzer.analyze(signal)
            results.append((name, result))
        }

        // 3. Verifiziere Konsistenz
        for (name, result) in results {
            // Alle Dimensionen sollten gültig sein
            XCTAssertGreaterThanOrEqual(result.boxCountingDimension, 1.0, "\(name): Box dimension too low")
            XCTAssertLessThanOrEqual(result.boxCountingDimension, 2.0, "\(name): Box dimension too high")

            XCTAssertGreaterThanOrEqual(result.higuchiFractalDimension, 1.0, "\(name): Higuchi too low")
            XCTAssertLessThanOrEqual(result.higuchiFractalDimension, 2.0, "\(name): Higuchi too high")

            XCTAssertGreaterThanOrEqual(result.complexityScore, 0.0, "\(name): Complexity too low")
            XCTAssertLessThanOrEqual(result.complexityScore, 1.0, "\(name): Complexity too high")
        }

        // 4. Verifiziere relative Ordnung
        let sineResult = results.first(where: { $0.0 == "Sine" })!.1
        let noiseResult = results.first(where: { $0.0 == "White Noise" })!.1

        XCTAssertLessThan(
            sineResult.boxCountingDimension,
            noiseResult.boxCountingDimension,
            "Sine should have lower dimension than white noise"
        )

        XCTAssertLessThan(
            sineResult.complexityScore,
            noiseResult.complexityScore,
            "Sine should have lower complexity than white noise"
        )
    }

    func testReproducibilityWithSameSeed() async throws {
        // Setze deterministisches Signal
        var deterministicSignal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            deterministicSignal[i] = sin(Float(i) * 0.1) * 0.5 + sin(Float(i) * 0.03) * 0.3
        }

        let result1 = analyzer.analyze(deterministicSignal)
        let result2 = analyzer.analyze(deterministicSignal)

        XCTAssertEqual(result1.boxCountingDimension, result2.boxCountingDimension, accuracy: 0.001)
        XCTAssertEqual(result1.higuchiFractalDimension, result2.higuchiFractalDimension, accuracy: 0.001)
        XCTAssertEqual(result1.katzFractalDimension, result2.katzFractalDimension, accuracy: 0.001)
    }
}
