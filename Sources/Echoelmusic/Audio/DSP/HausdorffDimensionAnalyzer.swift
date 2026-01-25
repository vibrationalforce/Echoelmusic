// HausdorffDimensionAnalyzer.swift
// Echoelmusic
//
// Hausdorff-Dimension Audio-Analyse für fraktale Signalcharakterisierung
// Box-Counting, Korrelations- und Spektral-Dimension
//
// Mathematischer Hintergrund:
// Die Hausdorff-Dimension ist ein Maß für die "Rauheit" oder fraktale Natur
// eines Signals. Für Audio-Signale ermöglicht sie die Quantifizierung von:
// - Signalkomplexität (höhere Dimension = komplexer)
// - Selbstähnlichkeit über verschiedene Zeitskalen
// - Textureigenschaften (glatt vs. rau)
//
// Referenzen:
// - Mandelbrot, B. (1982). The Fractal Geometry of Nature
// - Higuchi, T. (1988). Approach to an irregular time series
// - Katz, M. (1988). Fractals and the analysis of waveforms
//
// Created 2026-01-25

import Foundation
import Accelerate

// MARK: - Hausdorff Analysis Result

/// Ergebnis der Hausdorff-Dimension Analyse
public struct HausdorffAnalysisResult: Sendable, Equatable {
    /// Box-Counting Dimension (Minkowski-Bouligand)
    /// Typischer Bereich für Audio: 1.0 (Sinus) bis 2.0 (weißes Rauschen)
    public let boxCountingDimension: Float

    /// Korrelationsdimension (Grassberger-Procaccia)
    /// Misst die Dimension des Attraktors im Phasenraum
    public let correlationDimension: Float

    /// Higuchi Fraktale Dimension
    /// Effizient für Zeitreihen, Bereich: 1.0 - 2.0
    public let higuchiFractalDimension: Float

    /// Katz Fraktale Dimension
    /// Basiert auf Pfadlänge und Durchmesser
    public let katzFractalDimension: Float

    /// Spektrale Fraktale Dimension
    /// Aus dem Power-Spektrum abgeleitet (1/f Noise Charakteristik)
    public let spectralFractalDimension: Float

    /// Hurst Exponent (H)
    /// H < 0.5: Anti-persistent, H = 0.5: Random Walk, H > 0.5: Persistent
    public let hurstExponent: Float

    /// Komplexitäts-Score (0-1, normalisiert)
    /// Kombiniert alle Dimensionen zu einem einheitlichen Maß
    public let complexityScore: Float

    /// Multi-Skalen Entropie Array
    /// Entropie bei verschiedenen Zeitskalen
    public let multiScaleEntropy: [Float]

    /// Regressions-Güte (R²) für die Dimensionsberechnung
    public let rSquared: Float

    /// Anzahl der verwendeten Skalen
    public let scaleCount: Int

    /// Zeitstempel der Analyse
    public let timestamp: Date

    /// Standard-Ergebnis für leere/ungültige Eingaben
    public static let empty = HausdorffAnalysisResult(
        boxCountingDimension: 1.0,
        correlationDimension: 1.0,
        higuchiFractalDimension: 1.0,
        katzFractalDimension: 1.0,
        spectralFractalDimension: 1.0,
        hurstExponent: 0.5,
        complexityScore: 0.0,
        multiScaleEntropy: [],
        rSquared: 0.0,
        scaleCount: 0,
        timestamp: Date()
    )
}

// MARK: - Configuration

/// Konfiguration für die Hausdorff-Analyse
public struct HausdorffAnalyzerConfig: Sendable {
    /// Minimale Box-Größe (Samples)
    public let minBoxSize: Int

    /// Maximale Box-Größe (Samples)
    public let maxBoxSize: Int

    /// Anzahl der Skalen für Box-Counting
    public let scaleCount: Int

    /// Embedding-Dimension für Korrelationsdimension
    public let embeddingDimension: Int

    /// Zeitverzögerung für Phasenraum-Rekonstruktion
    public let timeDelay: Int

    /// Maximaler k-Wert für Higuchi
    public let higuchMaxK: Int

    /// FFT-Größe für Spektralanalyse
    public let fftSize: Int

    /// Standard-Konfiguration
    public static let `default` = HausdorffAnalyzerConfig(
        minBoxSize: 4,
        maxBoxSize: 256,
        scaleCount: 16,
        embeddingDimension: 10,
        timeDelay: 1,
        higuchMaxK: 10,
        fftSize: 2048
    )

    /// Schnelle Analyse (geringere Genauigkeit)
    public static let fast = HausdorffAnalyzerConfig(
        minBoxSize: 8,
        maxBoxSize: 128,
        scaleCount: 8,
        embeddingDimension: 5,
        timeDelay: 1,
        higuchMaxK: 5,
        fftSize: 1024
    )

    /// Hochpräzise Analyse (höherer Rechenaufwand)
    public static let highPrecision = HausdorffAnalyzerConfig(
        minBoxSize: 2,
        maxBoxSize: 512,
        scaleCount: 32,
        embeddingDimension: 15,
        timeDelay: 1,
        higuchMaxK: 20,
        fftSize: 4096
    )

    public init(
        minBoxSize: Int = 4,
        maxBoxSize: Int = 256,
        scaleCount: Int = 16,
        embeddingDimension: Int = 10,
        timeDelay: Int = 1,
        higuchMaxK: Int = 10,
        fftSize: Int = 2048
    ) {
        self.minBoxSize = max(2, minBoxSize)
        self.maxBoxSize = max(minBoxSize * 2, maxBoxSize)
        self.scaleCount = max(4, scaleCount)
        self.embeddingDimension = max(2, embeddingDimension)
        self.timeDelay = max(1, timeDelay)
        self.higuchMaxK = max(2, higuchMaxK)
        self.fftSize = fftSize
    }
}

// MARK: - Hausdorff Dimension Analyzer

/// Hausdorff-Dimension Audio-Analysator
///
/// Berechnet verschiedene fraktale Dimensionen für Audio-Signale:
/// - Box-Counting (Minkowski-Bouligand) Dimension
/// - Korrelationsdimension (Grassberger-Procaccia)
/// - Higuchi Fraktale Dimension
/// - Katz Fraktale Dimension
/// - Spektrale Fraktale Dimension
/// - Hurst Exponent
///
/// Verwendung:
/// ```swift
/// let analyzer = HausdorffDimensionAnalyzer()
/// let result = analyzer.analyze(audioBuffer)
/// print("Box-Counting Dimension: \(result.boxCountingDimension)")
/// print("Komplexität: \(result.complexityScore)")
/// ```
@MainActor
public final class HausdorffDimensionAnalyzer: ObservableObject {

    // MARK: - Published Properties

    /// Aktuelles Analyse-Ergebnis
    @Published public private(set) var currentResult: HausdorffAnalysisResult = .empty

    /// Verlauf der Analyse-Ergebnisse (Rolling Window)
    @Published public private(set) var resultHistory: [HausdorffAnalysisResult] = []

    /// Durchschnittliche Dimension über Zeit
    @Published public private(set) var averageBoxDimension: Float = 1.0

    /// Ist die Analyse aktiv?
    @Published public private(set) var isAnalyzing: Bool = false

    // MARK: - Configuration

    /// Aktuelle Konfiguration
    public let config: HausdorffAnalyzerConfig

    /// Maximale Größe des Verlaufs
    public let maxHistorySize: Int

    // MARK: - Pre-allocated Buffers (Real-time Safe)

    private var workBuffer: [Float]
    private var scaleArray: [Float]
    private var countArray: [Float]
    private var logScaleArray: [Float]
    private var logCountArray: [Float]
    private var fftRealBuffer: [Float]
    private var fftImagBuffer: [Float]
    private var powerSpectrum: [Float]
    private var entropyBuffer: [Float]
    private var distanceMatrix: [[Float]]

    // MARK: - FFT Setup

    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]

    // MARK: - Initialization

    /// Initialisiert den Hausdorff-Dimension Analysator
    /// - Parameters:
    ///   - config: Konfiguration für die Analyse
    ///   - maxHistorySize: Maximale Anzahl gespeicherter Ergebnisse
    public init(
        config: HausdorffAnalyzerConfig = .default,
        maxHistorySize: Int = 100
    ) {
        self.config = config
        self.maxHistorySize = maxHistorySize

        // Pre-allocate buffers
        self.workBuffer = [Float](repeating: 0, count: config.fftSize)
        self.scaleArray = [Float](repeating: 0, count: config.scaleCount)
        self.countArray = [Float](repeating: 0, count: config.scaleCount)
        self.logScaleArray = [Float](repeating: 0, count: config.scaleCount)
        self.logCountArray = [Float](repeating: 0, count: config.scaleCount)
        self.fftRealBuffer = [Float](repeating: 0, count: config.fftSize)
        self.fftImagBuffer = [Float](repeating: 0, count: config.fftSize)
        self.powerSpectrum = [Float](repeating: 0, count: config.fftSize / 2)
        self.entropyBuffer = [Float](repeating: 0, count: 20)

        // Distance matrix for correlation dimension
        let matrixSize = min(1000, config.fftSize / config.embeddingDimension)
        self.distanceMatrix = [[Float]](
            repeating: [Float](repeating: 0, count: matrixSize),
            count: matrixSize
        )

        // Create Hann window
        self.window = [Float](repeating: 0, count: config.fftSize)
        vDSP_hann_window(&window, vDSP_Length(config.fftSize), Int32(vDSP_HANN_NORM))

        // Setup FFT
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(config.fftSize),
            .FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Public Analysis Methods

    /// Analysiert einen Audio-Buffer und berechnet alle fraktalen Dimensionen
    /// - Parameter samples: Audio-Samples als Float-Array
    /// - Returns: Hausdorff-Analyse-Ergebnis
    public func analyze(_ samples: [Float]) -> HausdorffAnalysisResult {
        guard samples.count >= config.minBoxSize * 4 else {
            return .empty
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Normalisiere Samples auf [-1, 1]
        let normalizedSamples = normalizeSamples(samples)

        // Berechne alle Dimensionen
        let (boxDim, boxR2) = calculateBoxCountingDimension(normalizedSamples)
        let corrDim = calculateCorrelationDimension(normalizedSamples)
        let higuchiDim = calculateHiguchiFractalDimension(normalizedSamples)
        let katzDim = calculateKatzFractalDimension(normalizedSamples)
        let spectralDim = calculateSpectralFractalDimension(normalizedSamples)
        let hurst = calculateHurstExponent(normalizedSamples)
        let mse = calculateMultiScaleEntropy(normalizedSamples)

        // Berechne Komplexitäts-Score
        let complexity = calculateComplexityScore(
            boxDim: boxDim,
            corrDim: corrDim,
            higuchiDim: higuchiDim,
            hurst: hurst
        )

        let result = HausdorffAnalysisResult(
            boxCountingDimension: boxDim,
            correlationDimension: corrDim,
            higuchiFractalDimension: higuchiDim,
            katzFractalDimension: katzDim,
            spectralFractalDimension: spectralDim,
            hurstExponent: hurst,
            complexityScore: complexity,
            multiScaleEntropy: mse,
            rSquared: boxR2,
            scaleCount: config.scaleCount,
            timestamp: Date()
        )

        // Update state
        currentResult = result
        addToHistory(result)
        updateAverages()

        return result
    }

    /// Analysiert einen Audio-Buffer (AVAudioPCMBuffer)
    /// - Parameter buffer: AVAudioPCMBuffer mit Audio-Daten
    /// - Returns: Hausdorff-Analyse-Ergebnis
    public func analyze(buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> HausdorffAnalysisResult {
        let samples = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
        return analyze(samples)
    }

    /// Löscht den Verlauf
    public func clearHistory() {
        resultHistory.removeAll()
        averageBoxDimension = 1.0
    }

    // MARK: - Box-Counting Dimension

    /// Berechnet die Box-Counting (Minkowski-Bouligand) Dimension
    ///
    /// Algorithmus:
    /// 1. Teile den 2D-Raum (Zeit × Amplitude) in Boxen der Größe ε
    /// 2. Zähle die Anzahl N(ε) der Boxen, die das Signal schneiden
    /// 3. Wiederhole für verschiedene ε
    /// 4. D = -lim(log N(ε) / log ε) als ε → 0
    ///
    /// - Parameter samples: Normalisierte Audio-Samples
    /// - Returns: (Dimension, R²-Güte)
    private func calculateBoxCountingDimension(_ samples: [Float]) -> (Float, Float) {
        let n = samples.count
        guard n >= config.minBoxSize * 2 else { return (1.0, 0.0) }

        // Generiere logarithmisch verteilte Skalen
        let logMin = log(Float(config.minBoxSize))
        let logMax = log(Float(min(config.maxBoxSize, n / 2)))
        let logStep = (logMax - logMin) / Float(config.scaleCount - 1)

        var validScales = 0

        for i in 0..<config.scaleCount {
            let boxSize = Int(exp(logMin + Float(i) * logStep))
            guard boxSize >= 2 && boxSize < n else { continue }

            // Zähle Boxen, die das Signal schneiden
            var boxCount = 0
            var usedBoxes = Set<Int>()

            // Quantisiere Amplitude in Boxen
            let amplitudeBoxes = Int(ceil(2.0 / (Float(boxSize) / Float(n))))

            for j in stride(from: 0, to: n - 1, by: max(1, boxSize / 4)) {
                let timeBox = j / boxSize
                let ampValue = (samples[j] + 1.0) / 2.0 // Normalisiere auf [0, 1]
                let ampBox = Int(ampValue * Float(amplitudeBoxes))
                let boxId = timeBox * (amplitudeBoxes + 1) + ampBox
                usedBoxes.insert(boxId)
            }

            boxCount = usedBoxes.count

            if boxCount > 0 {
                scaleArray[validScales] = Float(boxSize)
                countArray[validScales] = Float(boxCount)
                logScaleArray[validScales] = log(Float(boxSize))
                logCountArray[validScales] = log(Float(boxCount))
                validScales += 1
            }
        }

        guard validScales >= 4 else { return (1.0, 0.0) }

        // Lineare Regression: log(N) = -D * log(ε) + c
        let (slope, _, rSquared) = linearRegression(
            x: Array(logScaleArray[0..<validScales]),
            y: Array(logCountArray[0..<validScales])
        )

        // Dimension ist der negative Slope
        let dimension = max(1.0, min(2.0, -slope))

        return (dimension, rSquared)
    }

    // MARK: - Correlation Dimension (Grassberger-Procaccia)

    /// Berechnet die Korrelationsdimension mittels Grassberger-Procaccia Algorithmus
    ///
    /// Algorithmus:
    /// 1. Rekonstruiere Phasenraum mit Embedding
    /// 2. Berechne Korrelationsintegral C(r)
    /// 3. D_2 = lim(log C(r) / log r) als r → 0
    ///
    /// - Parameter samples: Normalisierte Audio-Samples
    /// - Returns: Korrelationsdimension
    private func calculateCorrelationDimension(_ samples: [Float]) -> Float {
        let n = samples.count
        let m = config.embeddingDimension
        let tau = config.timeDelay

        // Anzahl der Vektoren im Phasenraum
        let numVectors = min(500, n - (m - 1) * tau)
        guard numVectors >= 50 else { return 1.0 }

        // Erstelle Embedded Vectors
        var vectors: [[Float]] = []
        let step = max(1, (n - (m - 1) * tau) / numVectors)

        for i in stride(from: 0, to: n - (m - 1) * tau, by: step) {
            if vectors.count >= numVectors { break }
            var vector = [Float](repeating: 0, count: m)
            for j in 0..<m {
                vector[j] = samples[i + j * tau]
            }
            vectors.append(vector)
        }

        let actualVectors = vectors.count
        guard actualVectors >= 20 else { return 1.0 }

        // Berechne alle paarweisen Distanzen
        var distances: [Float] = []
        distances.reserveCapacity(actualVectors * (actualVectors - 1) / 2)

        for i in 0..<actualVectors {
            for j in (i + 1)..<actualVectors {
                var dist: Float = 0
                for k in 0..<m {
                    let diff = vectors[i][k] - vectors[j][k]
                    dist += diff * diff
                }
                distances.append(sqrt(dist))
            }
        }

        guard !distances.isEmpty else { return 1.0 }

        // Sortiere Distanzen
        distances.sort()

        // Berechne Korrelationsintegral für verschiedene Radien
        let numRadii = 10
        var logR: [Float] = []
        var logC: [Float] = []

        let minDist = max(distances[0], 1e-6)
        let maxDist = distances[distances.count - 1]
        let logRange = log(maxDist / minDist)

        for i in 0..<numRadii {
            let r = minDist * exp(Float(i) * logRange / Float(numRadii - 1))

            // Zähle Paare mit Distanz < r
            var count = 0
            for d in distances {
                if d < r { count += 1 }
                else { break }
            }

            if count > 0 {
                let correlation = 2.0 * Float(count) / Float(actualVectors * (actualVectors - 1))
                logR.append(log(r))
                logC.append(log(correlation))
            }
        }

        guard logR.count >= 4 else { return 1.0 }

        // Lineare Regression im mittleren Bereich
        let startIdx = logR.count / 4
        let endIdx = 3 * logR.count / 4

        let (slope, _, _) = linearRegression(
            x: Array(logR[startIdx..<endIdx]),
            y: Array(logC[startIdx..<endIdx])
        )

        return max(0.5, min(Float(m), slope))
    }

    // MARK: - Higuchi Fractal Dimension

    /// Berechnet die Higuchi Fraktale Dimension
    ///
    /// Referenz: Higuchi, T. (1988). Approach to an irregular time series
    ///
    /// Algorithmus:
    /// 1. Konstruiere k neue Zeitreihen X_k^m
    /// 2. Berechne Länge L(k) für jedes k
    /// 3. D = slope von log(L(k)) vs log(1/k)
    ///
    /// - Parameter samples: Audio-Samples
    /// - Returns: Higuchi Fraktale Dimension (1.0 - 2.0)
    private func calculateHiguchiFractalDimension(_ samples: [Float]) -> Float {
        let n = samples.count
        let kMax = min(config.higuchMaxK, n / 4)
        guard kMax >= 2 else { return 1.0 }

        var logK: [Float] = []
        var logL: [Float] = []

        for k in 1...kMax {
            var lengthSum: Float = 0

            for m in 1...k {
                var length: Float = 0
                let numPoints = (n - m) / k

                guard numPoints >= 1 else { continue }

                for i in 1..<numPoints {
                    let idx1 = m + i * k - 1
                    let idx2 = m + (i - 1) * k - 1

                    if idx1 < n && idx2 < n && idx2 >= 0 {
                        length += abs(samples[idx1] - samples[idx2])
                    }
                }

                // Normalisiere Länge
                let normFactor = Float(n - 1) / (Float(k) * Float(numPoints) * Float(k))
                lengthSum += length * normFactor
            }

            let avgLength = lengthSum / Float(k)

            if avgLength > 0 {
                logK.append(log(Float(k)))
                logL.append(log(avgLength))
            }
        }

        guard logK.count >= 3 else { return 1.0 }

        // Lineare Regression
        let (slope, _, _) = linearRegression(x: logK, y: logL)

        return max(1.0, min(2.0, -slope))
    }

    // MARK: - Katz Fractal Dimension

    /// Berechnet die Katz Fraktale Dimension
    ///
    /// Referenz: Katz, M. (1988). Fractals and the analysis of waveforms
    ///
    /// D = log(L) / log(d)
    /// wobei L = Gesamtpfadlänge, d = maximaler Abstand vom Start
    ///
    /// - Parameter samples: Audio-Samples
    /// - Returns: Katz Fraktale Dimension
    private func calculateKatzFractalDimension(_ samples: [Float]) -> Float {
        let n = samples.count
        guard n >= 10 else { return 1.0 }

        // Berechne Pfadlänge
        var pathLength: Float = 0
        for i in 1..<n {
            let dx: Float = 1.0 / Float(n) // Normalisierte Zeit
            let dy = samples[i] - samples[i - 1]
            pathLength += sqrt(dx * dx + dy * dy)
        }

        // Berechne maximalen Abstand vom Startpunkt
        var maxDistance: Float = 0
        let startValue = samples[0]
        for i in 1..<n {
            let dx = Float(i) / Float(n)
            let dy = samples[i] - startValue
            let distance = sqrt(dx * dx + dy * dy)
            maxDistance = max(maxDistance, distance)
        }

        guard maxDistance > 0 && pathLength > maxDistance else { return 1.0 }

        // Katz Dimension
        let dimension = log(pathLength) / log(maxDistance)

        return max(1.0, min(2.0, dimension))
    }

    // MARK: - Spectral Fractal Dimension

    /// Berechnet die Spektrale Fraktale Dimension aus dem Power-Spektrum
    ///
    /// Für 1/f^β Rauschen gilt: D = (5 - β) / 2
    /// - β = 0: Weißes Rauschen (D ≈ 2.0)
    /// - β = 1: Rosa Rauschen (D ≈ 1.5)
    /// - β = 2: Braunes Rauschen (D ≈ 1.0)
    ///
    /// - Parameter samples: Audio-Samples
    /// - Returns: Spektrale Fraktale Dimension
    private func calculateSpectralFractalDimension(_ samples: [Float]) -> Float {
        guard let setup = fftSetup else { return 1.5 }

        let n = min(samples.count, config.fftSize)
        guard n >= 256 else { return 1.5 }

        // Kopiere und fenstere Samples
        for i in 0..<n {
            fftRealBuffer[i] = samples[i] * window[i]
            fftImagBuffer[i] = 0
        }

        // Zero-padding falls nötig
        for i in n..<config.fftSize {
            fftRealBuffer[i] = 0
            fftImagBuffer[i] = 0
        }

        // FFT ausführen
        vDSP_DFT_Execute(setup, fftRealBuffer, fftImagBuffer, &fftRealBuffer, &fftImagBuffer)

        // Power-Spektrum berechnen
        let halfSize = config.fftSize / 2
        for i in 0..<halfSize {
            let real = fftRealBuffer[i]
            let imag = fftImagBuffer[i]
            powerSpectrum[i] = real * real + imag * imag
        }

        // Log-Log Regression für 1/f^β Fitting
        var logF: [Float] = []
        var logP: [Float] = []

        // Ignoriere DC und sehr hohe Frequenzen
        let startBin = 2
        let endBin = halfSize / 2

        for i in startBin..<endBin {
            if powerSpectrum[i] > 1e-10 {
                logF.append(log(Float(i)))
                logP.append(log(powerSpectrum[i]))
            }
        }

        guard logF.count >= 10 else { return 1.5 }

        // Lineare Regression
        let (beta, _, _) = linearRegression(x: logF, y: logP)

        // D = (5 - β) / 2, wobei β negativ ist (fallende Spektraldichte)
        let dimension = (5.0 + beta) / 2.0

        return max(1.0, min(2.0, dimension))
    }

    // MARK: - Hurst Exponent

    /// Berechnet den Hurst Exponent mittels R/S Analyse
    ///
    /// - H < 0.5: Anti-persistent (mean-reverting)
    /// - H = 0.5: Random Walk (Brownian motion)
    /// - H > 0.5: Persistent (trending)
    ///
    /// - Parameter samples: Audio-Samples
    /// - Returns: Hurst Exponent (0.0 - 1.0)
    private func calculateHurstExponent(_ samples: [Float]) -> Float {
        let n = samples.count
        guard n >= 64 else { return 0.5 }

        var logN: [Float] = []
        var logRS: [Float] = []

        // Verschiedene Teilungsgrößen
        var size = 8
        while size <= n / 4 {
            let numSubseries = n / size
            guard numSubseries >= 2 else { break }

            var rsSum: Float = 0
            var rsCount = 0

            for i in 0..<numSubseries {
                let start = i * size
                let end = min(start + size, n)
                let subLength = end - start

                guard subLength >= 4 else { continue }

                // Mittelwert der Teilserie
                var sum: Float = 0
                for j in start..<end {
                    sum += samples[j]
                }
                let mean = sum / Float(subLength)

                // Kumulative Abweichung vom Mittelwert
                var cumDev: [Float] = [Float](repeating: 0, count: subLength)
                var cumSum: Float = 0
                for j in 0..<subLength {
                    cumSum += samples[start + j] - mean
                    cumDev[j] = cumSum
                }

                // Range R
                var minDev: Float = .infinity
                var maxDev: Float = -.infinity
                for dev in cumDev {
                    minDev = min(minDev, dev)
                    maxDev = max(maxDev, dev)
                }
                let range = maxDev - minDev

                // Standardabweichung S
                var variance: Float = 0
                for j in start..<end {
                    let diff = samples[j] - mean
                    variance += diff * diff
                }
                let stdDev = sqrt(variance / Float(subLength))

                if stdDev > 1e-10 {
                    rsSum += range / stdDev
                    rsCount += 1
                }
            }

            if rsCount > 0 {
                let avgRS = rsSum / Float(rsCount)
                logN.append(log(Float(size)))
                logRS.append(log(avgRS))
            }

            size *= 2
        }

        guard logN.count >= 3 else { return 0.5 }

        // Lineare Regression
        let (slope, _, _) = linearRegression(x: logN, y: logRS)

        return max(0.0, min(1.0, slope))
    }

    // MARK: - Multi-Scale Entropy

    /// Berechnet Multi-Scale Entropie
    ///
    /// - Parameter samples: Audio-Samples
    /// - Returns: Array von Entropie-Werten bei verschiedenen Skalen
    private func calculateMultiScaleEntropy(_ samples: [Float]) -> [Float] {
        let maxScale = min(20, samples.count / 50)
        guard maxScale >= 2 else { return [] }

        var entropies: [Float] = []

        for scale in 1...maxScale {
            // Coarse-grain die Zeitreihe
            let coarseLength = samples.count / scale
            guard coarseLength >= 20 else { break }

            var coarse = [Float](repeating: 0, count: coarseLength)
            for i in 0..<coarseLength {
                var sum: Float = 0
                for j in 0..<scale {
                    sum += samples[i * scale + j]
                }
                coarse[i] = sum / Float(scale)
            }

            // Berechne Sample Entropy
            let entropy = calculateSampleEntropy(coarse, m: 2, r: 0.2)
            entropies.append(entropy)
        }

        return entropies
    }

    /// Berechnet Sample Entropy (SampEn)
    private func calculateSampleEntropy(_ data: [Float], m: Int, r: Float) -> Float {
        let n = data.count
        guard n > m + 1 else { return 0 }

        // Standardabweichung für Toleranz
        var sum: Float = 0
        var sumSq: Float = 0
        for val in data {
            sum += val
            sumSq += val * val
        }
        let mean = sum / Float(n)
        let stdDev = sqrt(sumSq / Float(n) - mean * mean)
        let tolerance = r * stdDev

        // Zähle ähnliche Muster
        var countM = 0
        var countM1 = 0

        for i in 0..<(n - m) {
            for j in (i + 1)..<(n - m) {
                // Prüfe m-Länge Muster
                var matchM = true
                for k in 0..<m {
                    if abs(data[i + k] - data[j + k]) > tolerance {
                        matchM = false
                        break
                    }
                }

                if matchM {
                    countM += 1

                    // Prüfe (m+1)-Länge Muster
                    if i + m < n && j + m < n {
                        if abs(data[i + m] - data[j + m]) <= tolerance {
                            countM1 += 1
                        }
                    }
                }
            }
        }

        guard countM > 0 && countM1 > 0 else { return 0 }

        return -log(Float(countM1) / Float(countM))
    }

    // MARK: - Complexity Score

    /// Berechnet einen normalisierten Komplexitäts-Score
    private func calculateComplexityScore(
        boxDim: Float,
        corrDim: Float,
        higuchiDim: Float,
        hurst: Float
    ) -> Float {
        // Normalisiere Box-Dimension (1.0-2.0) auf (0-1)
        let boxNorm = (boxDim - 1.0)

        // Higuchi ebenfalls (1.0-2.0) auf (0-1)
        let higuchiNorm = (higuchiDim - 1.0)

        // Korrelationsdimension normalisieren (typisch 0.5-10)
        let corrNorm = min(1.0, corrDim / 5.0)

        // Hurst: 0.5 ist maximal chaotisch
        let hurstComplexity = 1.0 - abs(hurst - 0.5) * 2.0

        // Gewichteter Durchschnitt
        let complexity = (
            0.35 * boxNorm +
            0.25 * higuchiNorm +
            0.20 * corrNorm +
            0.20 * hurstComplexity
        )

        return max(0.0, min(1.0, complexity))
    }

    // MARK: - Helper Methods

    /// Normalisiert Samples auf [-1, 1]
    private func normalizeSamples(_ samples: [Float]) -> [Float] {
        var maxAbs: Float = 0
        vDSP_maxmgv(samples, 1, &maxAbs, vDSP_Length(samples.count))

        guard maxAbs > 0 else { return samples }

        var normalized = samples
        var scale = 1.0 / maxAbs
        vDSP_vsmul(samples, 1, &scale, &normalized, 1, vDSP_Length(samples.count))

        return normalized
    }

    /// Lineare Regression: y = slope * x + intercept
    private func linearRegression(x: [Float], y: [Float]) -> (slope: Float, intercept: Float, rSquared: Float) {
        let n = Float(x.count)
        guard n >= 2 else { return (0, 0, 0) }

        var sumX: Float = 0
        var sumY: Float = 0
        var sumXY: Float = 0
        var sumX2: Float = 0
        var sumY2: Float = 0

        for i in 0..<x.count {
            sumX += x[i]
            sumY += y[i]
            sumXY += x[i] * y[i]
            sumX2 += x[i] * x[i]
            sumY2 += y[i] * y[i]
        }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return (0, 0, 0) }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // R² Berechnung
        let meanY = sumY / n
        var ssTotal: Float = 0
        var ssResidual: Float = 0

        for i in 0..<x.count {
            let predicted = slope * x[i] + intercept
            ssTotal += (y[i] - meanY) * (y[i] - meanY)
            ssResidual += (y[i] - predicted) * (y[i] - predicted)
        }

        let rSquared = ssTotal > 0 ? 1.0 - (ssResidual / ssTotal) : 0.0

        return (slope, intercept, max(0, min(1, rSquared)))
    }

    /// Fügt Ergebnis zum Verlauf hinzu
    private func addToHistory(_ result: HausdorffAnalysisResult) {
        resultHistory.append(result)
        if resultHistory.count > maxHistorySize {
            resultHistory.removeFirst()
        }
    }

    /// Aktualisiert Durchschnittswerte
    private func updateAverages() {
        guard !resultHistory.isEmpty else { return }

        var sum: Float = 0
        for result in resultHistory {
            sum += result.boxCountingDimension
        }
        averageBoxDimension = sum / Float(resultHistory.count)
    }
}

// MARK: - Bio-Reactive Extension

extension HausdorffDimensionAnalyzer {

    /// Mappt Hausdorff-Dimension auf Bio-Reactive Parameter
    ///
    /// - Hohe Komplexität (D → 2.0): Mehr Reverb, offenere Filter
    /// - Niedrige Komplexität (D → 1.0): Weniger Effekte, klarerer Sound
    ///
    /// - Parameter result: Hausdorff-Analyse-Ergebnis
    /// - Returns: Bio-Reactive Parameter Dictionary
    public func mapToBioReactiveParameters(_ result: HausdorffAnalysisResult) -> [String: Float] {
        let complexity = result.complexityScore
        let dimension = result.boxCountingDimension
        let hurst = result.hurstExponent

        return [
            // Audio-Parameter
            "filterCutoff": 0.3 + complexity * 0.6,        // Komplexer = offenere Filter
            "reverbWet": complexity * 0.4,                  // Komplexer = mehr Reverb
            "delayFeedback": complexity * 0.3,              // Komplexer = mehr Delay
            "granularDensity": dimension - 1.0,             // Dimension direkt
            "lfoRate": 0.5 + (hurst - 0.5) * 0.5,          // Hurst moduliert LFO

            // Visual-Parameter
            "particleCount": complexity,                    // Komplexer = mehr Partikel
            "fractalIterations": dimension,                 // Dimension = Fraktal-Detail
            "colorComplexity": complexity,                  // Farbkomplexität
            "motionSpeed": 0.5 + (hurst - 0.5) * 0.3,      // Hurst = Bewegung

            // Quantum-Parameter
            "quantumCoherence": 1.0 - complexity,           // Invers zur Komplexität
            "entanglementStrength": dimension - 1.0,        // Dimension-basiert

            // Raw Values für Custom Mapping
            "rawDimension": dimension,
            "rawComplexity": complexity,
            "rawHurst": hurst,
            "rawCorrelation": result.correlationDimension
        ]
    }
}

// MARK: - Signal Generator for Testing

/// Generiert Test-Signale mit bekannter fraktaler Dimension
public struct FractalSignalGenerator {

    /// Generiert weißes Rauschen (D ≈ 2.0)
    public static func whiteNoise(count: Int) -> [Float] {
        return (0..<count).map { _ in Float.random(in: -1...1) }
    }

    /// Generiert Brownsche Bewegung (D ≈ 1.5)
    public static func brownianNoise(count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        var value: Float = 0

        for i in 0..<count {
            value += Float.random(in: -0.1...0.1)
            value = max(-1, min(1, value))
            samples[i] = value
        }

        return samples
    }

    /// Generiert Sinus (D ≈ 1.0)
    public static func sineWave(count: Int, frequency: Float = 440, sampleRate: Float = 48000) -> [Float] {
        return (0..<count).map { i in
            sin(2 * .pi * frequency * Float(i) / sampleRate)
        }
    }

    /// Generiert fraktales Rauschen mit spezifischer Dimension
    /// - Parameter beta: Spektrale Steigung (0 = weiß, 1 = rosa, 2 = braun)
    public static func fractalNoise(count: Int, beta: Float) -> [Float] {
        // Generiere im Frequenzbereich
        let fftSize = count
        var real = [Float](repeating: 0, count: fftSize)
        var imag = [Float](repeating: 0, count: fftSize)

        for i in 1..<(fftSize / 2) {
            let magnitude = pow(Float(i), -beta / 2)
            let phase = Float.random(in: 0...(2 * .pi))
            real[i] = magnitude * cos(phase)
            imag[i] = magnitude * sin(phase)
            // Symmetrie für reelles Ausgangssignal
            real[fftSize - i] = real[i]
            imag[fftSize - i] = -imag[i]
        }

        // Inverse FFT (simplified)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<count {
            var sum: Float = 0
            for k in 0..<fftSize {
                let angle = 2 * .pi * Float(k * n) / Float(fftSize)
                sum += real[k] * cos(angle) - imag[k] * sin(angle)
            }
            samples[n] = sum / Float(fftSize)
        }

        // Normalisiere
        var maxAbs: Float = 0
        vDSP_maxmgv(samples, 1, &maxAbs, vDSP_Length(count))
        if maxAbs > 0 {
            var scale = 1.0 / maxAbs
            vDSP_vsmul(samples, 1, &scale, &samples, 1, vDSP_Length(count))
        }

        return samples
    }

    /// Generiert Cantor-Staub-ähnliches Signal (D ≈ log(2)/log(3) ≈ 0.63)
    public static func cantorDust(iterations: Int) -> [Float] {
        var signal: [Float] = [1.0]

        for _ in 0..<iterations {
            var newSignal: [Float] = []
            for value in signal {
                newSignal.append(value)
                newSignal.append(0)
                newSignal.append(value)
            }
            signal = newSignal
        }

        // Auf Audio-Länge skalieren
        let targetLength = 4096
        var result = [Float](repeating: 0, count: targetLength)
        let scale = Float(signal.count) / Float(targetLength)

        for i in 0..<targetLength {
            let srcIdx = min(Int(Float(i) * scale), signal.count - 1)
            result[i] = signal[srcIdx] * 2 - 1 // Auf [-1, 1] skalieren
        }

        return result
    }
}
