import Foundation
import CoreML
import Accelerate
import Combine

/// Enhanced ML Models für bio-reaktive Intelligenz
///
/// Dieses System erweitert die ML-Funktionen von Echoelmusic mit fortgeschrittenen
/// Machine Learning-Modellen für:
/// - Emotionserkennung aus Bio-Daten
/// - Musikstil-Erkennung und -Klassifizierung
/// - Intelligente Parametervorhersage
/// - Adaptive Recommendation Engine
/// - Pattern Recognition in HRV/Coherence
/// - Audio Feature Extraction
/// - User Behavior Prediction
///
@MainActor
@Observable
class EnhancedMLModels {

    // MARK: - Published Properties

    /// Erkannte Emotion
    var currentEmotion: Emotion = .neutral

    /// Erkannter Musikstil
    var detectedMusicStyle: MusicStyle = .unknown

    /// ML-Vorhersagen
    var predictions: MLPredictions = MLPredictions()

    /// Empfehlungen
    var recommendations: [Recommendation] = []

    // MARK: - Private Properties

    private var emotionClassifier: EmotionClassifier?
    private var styleClassifier: MusicStyleClassifier?
    private var parameterPredictor: ParameterPredictor?
    private var patternRecognizer: PatternRecognizer?
    private var audioFeatureExtractor: AudioFeatureExtractor?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Emotion

    enum Emotion: String, CaseIterable {
        case neutral = "Neutral"
        case happy = "Glücklich"
        case sad = "Traurig"
        case energetic = "Energetisch"
        case calm = "Ruhig"
        case anxious = "Ängstlich"
        case focused = "Fokussiert"
        case relaxed = "Entspannt"

        var color: (r: Float, g: Float, b: Float) {
            switch self {
            case .neutral: return (0.5, 0.5, 0.5)
            case .happy: return (1.0, 0.8, 0.2)
            case .sad: return (0.3, 0.3, 0.7)
            case .energetic: return (1.0, 0.2, 0.2)
            case .calm: return (0.2, 0.8, 0.6)
            case .anxious: return (0.8, 0.4, 0.0)
            case .focused: return (0.4, 0.6, 0.9)
            case .relaxed: return (0.5, 0.8, 0.5)
            }
        }

        var recommendedBPM: ClosedRange<Float> {
            switch self {
            case .neutral: return 80...100
            case .happy: return 110...130
            case .sad: return 60...80
            case .energetic: return 130...160
            case .calm: return 60...80
            case .anxious: return 70...90
            case .focused: return 90...110
            case .relaxed: return 60...75
            }
        }
    }

    // MARK: - Music Style

    enum MusicStyle: String, CaseIterable {
        case unknown = "Unbekannt"
        case classical = "Klassisch"
        case electronic = "Elektronisch"
        case rock = "Rock"
        case jazz = "Jazz"
        case ambient = "Ambient"
        case hiphop = "Hip-Hop"
        case world = "Weltmusik"
        case experimental = "Experimentell"

        var characteristics: StyleCharacteristics {
            switch self {
            case .unknown:
                return StyleCharacteristics(tempo: 120, complexity: 0.5, energy: 0.5)
            case .classical:
                return StyleCharacteristics(tempo: 90, complexity: 0.8, energy: 0.6)
            case .electronic:
                return StyleCharacteristics(tempo: 128, complexity: 0.6, energy: 0.8)
            case .rock:
                return StyleCharacteristics(tempo: 140, complexity: 0.5, energy: 0.9)
            case .jazz:
                return StyleCharacteristics(tempo: 120, complexity: 0.9, energy: 0.7)
            case .ambient:
                return StyleCharacteristics(tempo: 70, complexity: 0.4, energy: 0.3)
            case .hiphop:
                return StyleCharacteristics(tempo: 95, complexity: 0.6, energy: 0.7)
            case .world:
                return StyleCharacteristics(tempo: 110, complexity: 0.7, energy: 0.6)
            case .experimental:
                return StyleCharacteristics(tempo: 100, complexity: 1.0, energy: 0.5)
            }
        }
    }

    struct StyleCharacteristics {
        let tempo: Float
        let complexity: Float
        let energy: Float
    }

    // MARK: - ML Predictions

    struct MLPredictions {
        var emotionConfidence: Float = 0.0
        var styleConfidence: Float = 0.0
        var nextParameterValues: [String: Float] = [:]
        var predictedUserAction: UserAction = .none

        enum UserAction: String {
            case none = "Keine"
            case adjustFilter = "Filter anpassen"
            case changeKey = "Tonart wechseln"
            case addEffect = "Effekt hinzufügen"
            case changeInstrument = "Instrument wechseln"
            case exportTrack = "Track exportieren"
        }
    }

    // MARK: - Recommendation

    struct Recommendation {
        let id: UUID = UUID()
        let type: RecommendationType
        let title: String
        let description: String
        let confidence: Float
        let parameters: [String: Any]

        enum RecommendationType {
            case effect
            case instrument
            case scale
            case rhythm
            case parameter
            case preset
        }
    }

    // MARK: - Emotion Classifier

    class EmotionClassifier {
        private var trainingData: [EmotionTrainingData] = []

        struct EmotionTrainingData {
            let hrv: Float
            let coherence: Float
            let heartRate: Float
            let variability: Float
            let emotion: Emotion
        }

        struct EmotionFeatures {
            let hrv: Float
            let coherence: Float
            let heartRate: Float
            let variability: Float
            let hrvTrend: Float
            let coherenceTrend: Float
        }

        func classify(features: EmotionFeatures) -> (emotion: Emotion, confidence: Float) {
            // Regel-basierte Klassifizierung (kann später durch CoreML-Modell ersetzt werden)

            var scores: [Emotion: Float] = [:]

            // Energetic: High HR, High HRV
            scores[.energetic] = (features.heartRate > 90 ? 1.0 : 0.0) +
                                (features.hrv > 0.7 ? 1.0 : 0.0)

            // Calm: Low HR, High Coherence
            scores[.calm] = (features.heartRate < 70 ? 1.0 : 0.0) +
                           (features.coherence > 0.7 ? 1.0 : 0.0)

            // Anxious: High HR, Low HRV, Low Coherence
            scores[.anxious] = (features.heartRate > 90 ? 1.0 : 0.0) +
                              (features.hrv < 0.3 ? 1.0 : 0.0) +
                              (features.coherence < 0.3 ? 1.0 : 0.0)

            // Relaxed: Low HR, High HRV, High Coherence
            scores[.relaxed] = (features.heartRate < 70 ? 1.0 : 0.0) +
                              (features.hrv > 0.6 ? 1.0 : 0.0) +
                              (features.coherence > 0.6 ? 1.0 : 0.0)

            // Focused: Moderate HR, High Coherence, Stable HRV
            scores[.focused] = (features.heartRate > 70 && features.heartRate < 85 ? 1.0 : 0.0) +
                              (features.coherence > 0.6 ? 1.0 : 0.0) +
                              (abs(features.hrvTrend) < 0.1 ? 1.0 : 0.0)

            // Happy: Moderate-High HR, High Coherence
            scores[.happy] = (features.heartRate > 75 && features.heartRate < 95 ? 1.0 : 0.0) +
                            (features.coherence > 0.5 ? 1.0 : 0.0)

            // Sad: Low HR, Low Coherence, Low HRV
            scores[.sad] = (features.heartRate < 70 ? 1.0 : 0.0) +
                          (features.coherence < 0.4 ? 1.0 : 0.0) +
                          (features.hrv < 0.4 ? 1.0 : 0.0)

            // Finde höchsten Score
            let maxEmotion = scores.max { $0.value < $1.value }
            let emotion = maxEmotion?.key ?? .neutral
            let maxScore = maxEmotion?.value ?? 0.0
            let confidence = min(maxScore / 3.0, 1.0) // Normalisiere auf 0-1

            return (emotion, confidence)
        }

        func train(data: [EmotionTrainingData]) {
            trainingData.append(contentsOf: data)
            print("📚 Trained emotion classifier with \(trainingData.count) samples")
        }
    }

    // MARK: - Music Style Classifier

    class MusicStyleClassifier {
        struct AudioFeatures {
            let tempo: Float
            let spectralCentroid: Float
            let spectralRolloff: Float
            let zeroCrossingRate: Float
            let mfcc: [Float] // Mel-Frequency Cepstral Coefficients
            let rhythmComplexity: Float
            let harmonicComplexity: Float
        }

        func classify(features: AudioFeatures) -> (style: MusicStyle, confidence: Float) {
            var scores: [MusicStyle: Float] = [:]

            // Classical: Moderate tempo, complex harmonics, low zero crossing
            scores[.classical] = (features.tempo > 70 && features.tempo < 120 ? 1.0 : 0.0) +
                                (features.harmonicComplexity > 0.7 ? 1.0 : 0.0) +
                                (features.zeroCrossingRate < 0.3 ? 1.0 : 0.0)

            // Electronic: Fast tempo, high spectral centroid, simple harmonics
            scores[.electronic] = (features.tempo > 120 ? 1.0 : 0.0) +
                                 (features.spectralCentroid > 0.6 ? 1.0 : 0.0) +
                                 (features.harmonicComplexity < 0.5 ? 0.5 : 0.0)

            // Rock: Fast tempo, high energy, moderate complexity
            scores[.rock] = (features.tempo > 120 && features.tempo < 160 ? 1.0 : 0.0) +
                           (features.spectralCentroid > 0.5 ? 1.0 : 0.0)

            // Jazz: Moderate tempo, very complex harmonics and rhythms
            scores[.jazz] = (features.tempo > 90 && features.tempo < 140 ? 1.0 : 0.0) +
                           (features.harmonicComplexity > 0.8 ? 1.0 : 0.0) +
                           (features.rhythmComplexity > 0.7 ? 1.0 : 0.0)

            // Ambient: Slow tempo, evolving textures, low rhythm complexity
            scores[.ambient] = (features.tempo < 80 ? 1.0 : 0.0) +
                              (features.rhythmComplexity < 0.3 ? 1.0 : 0.0) +
                              (features.spectralRolloff < 0.5 ? 1.0 : 0.0)

            // Hip-Hop: Moderate tempo, strong rhythm, repetitive
            scores[.hiphop] = (features.tempo > 80 && features.tempo < 110 ? 1.0 : 0.0) +
                             (features.rhythmComplexity > 0.5 ? 1.0 : 0.0)

            // World: Variable tempo, unique scales/rhythms
            scores[.world] = (features.harmonicComplexity > 0.6 ? 1.0 : 0.0)

            // Experimental: High complexity, unusual characteristics
            scores[.experimental] = (features.harmonicComplexity > 0.8 ? 1.0 : 0.0) +
                                   (features.rhythmComplexity > 0.8 ? 1.0 : 0.0)

            let maxStyle = scores.max { $0.value < $1.value }
            let style = maxStyle?.key ?? .unknown
            let maxScore = maxStyle?.value ?? 0.0
            let confidence = min(maxScore / 3.0, 1.0)

            return (style, confidence)
        }
    }

    // MARK: - Parameter Predictor

    class ParameterPredictor {
        private var history: [ParameterSnapshot] = []

        struct ParameterSnapshot {
            let timestamp: Date
            let emotion: Emotion
            let parameters: [String: Float]
        }

        func predict(currentEmotion: Emotion, history: [ParameterSnapshot]) -> [String: Float] {
            // Finde ähnliche emotionale Zustände in der Historie
            let similarSnapshots = history.filter { $0.emotion == currentEmotion }

            guard !similarSnapshots.isEmpty else {
                return defaultParametersFor(emotion: currentEmotion)
            }

            // Durchschnitt der Parameter in ähnlichen Zuständen
            var predictions: [String: Float] = [:]
            let allKeys = Set(similarSnapshots.flatMap { $0.parameters.keys })

            for key in allKeys {
                let values = similarSnapshots.compactMap { $0.parameters[key] }
                if !values.isEmpty {
                    predictions[key] = values.reduce(0, +) / Float(values.count)
                }
            }

            return predictions
        }

        private func defaultParametersFor(emotion: Emotion) -> [String: Float] {
            switch emotion {
            case .energetic:
                return [
                    "filterCutoff": 8000,
                    "resonance": 0.7,
                    "reverbMix": 0.3,
                    "distortion": 0.4
                ]
            case .calm:
                return [
                    "filterCutoff": 2000,
                    "resonance": 0.3,
                    "reverbMix": 0.6,
                    "distortion": 0.0
                ]
            case .anxious:
                return [
                    "filterCutoff": 5000,
                    "resonance": 0.5,
                    "reverbMix": 0.2,
                    "distortion": 0.2
                ]
            default:
                return [
                    "filterCutoff": 5000,
                    "resonance": 0.5,
                    "reverbMix": 0.4,
                    "distortion": 0.1
                ]
            }
        }

        func addSnapshot(_ snapshot: ParameterSnapshot) {
            history.append(snapshot)

            // Behalte nur die letzten 1000 Snapshots
            if history.count > 1000 {
                history.removeFirst(history.count - 1000)
            }
        }
    }

    // MARK: - Pattern Recognizer

    class PatternRecognizer {
        func recognizePatterns(hrvData: [Float], coherenceData: [Float]) -> [RecognizedPattern] {
            var patterns: [RecognizedPattern] = []

            // Pattern 1: Coherence Building (aufsteigende Kohärenz)
            if isIncreasingTrend(coherenceData) {
                patterns.append(RecognizedPattern(
                    type: .coherenceBuilding,
                    confidence: calculateTrendStrength(coherenceData),
                    description: "Kohärenz steigt - gute Fortschritte!"
                ))
            }

            // Pattern 2: Stress Response (fallende HRV, steigende HR-Variabilität)
            if isDecreasingTrend(hrvData) {
                patterns.append(RecognizedPattern(
                    type: .stressResponse,
                    confidence: calculateTrendStrength(hrvData),
                    description: "Stressanzeichen erkannt - Entspannungsübung empfohlen"
                ))
            }

            // Pattern 3: Resonance Frequency (optimale Atemfrequenz)
            if let resonanceFreq = findResonanceFrequency(hrvData: hrvData) {
                patterns.append(RecognizedPattern(
                    type: .resonanceFrequency,
                    confidence: 0.9,
                    description: "Resonanzfrequenz erkannt bei \(String(format: "%.1f", resonanceFreq)) Atemzügen/min"
                ))
            }

            // Pattern 4: Flow State (hohe Kohärenz + stabile HRV)
            if isInFlowState(hrvData: hrvData, coherenceData: coherenceData) {
                patterns.append(RecognizedPattern(
                    type: .flowState,
                    confidence: 0.95,
                    description: "Flow-Zustand erkannt - optimale Performance!"
                ))
            }

            return patterns
        }

        private func isIncreasingTrend(_ data: [Float]) -> Bool {
            guard data.count > 5 else { return false }
            let recent = Array(data.suffix(10))
            let slope = calculateLinearRegressionSlope(recent)
            return slope > 0.01
        }

        private func isDecreasingTrend(_ data: [Float]) -> Bool {
            guard data.count > 5 else { return false }
            let recent = Array(data.suffix(10))
            let slope = calculateLinearRegressionSlope(recent)
            return slope < -0.01
        }

        private func calculateTrendStrength(_ data: [Float]) -> Float {
            let slope = abs(calculateLinearRegressionSlope(data))
            return min(slope * 10.0, 1.0)
        }

        private func calculateLinearRegressionSlope(_ data: [Float]) -> Float {
            guard data.count > 1 else { return 0.0 }

            let n = Float(data.count)
            let x = (0..<data.count).map { Float($0) }
            let y = data

            let sumX = x.reduce(0, +)
            let sumY = y.reduce(0, +)
            let sumXY = zip(x, y).map(*).reduce(0, +)
            let sumXX = x.map { $0 * $0 }.reduce(0, +)

            let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
            return slope
        }

        private func findResonanceFrequency(hrvData: [Float]) -> Float? {
            // Vereinfachte FFT zur Frequenzanalyse
            guard hrvData.count >= 64 else { return nil }

            let fftSize = 64
            var realPart = [Float](hrvData.prefix(fftSize))
            var imagPart = [Float](repeating: 0.0, count: fftSize)

            // Einfache FFT (in Produktion: vDSP verwenden)
            // Hier vereinfacht: Suche dominante Frequenz
            var maxPower: Float = 0.0
            var maxFreqIndex = 0

            for k in 0..<fftSize/2 {
                var power: Float = 0.0
                for n in 0..<fftSize {
                    let angle = -2.0 * Float.pi * Float(k * n) / Float(fftSize)
                    power += realPart[n] * cos(angle)
                }
                power = abs(power)

                if power > maxPower {
                    maxPower = power
                    maxFreqIndex = k
                }
            }

            // Konvertiere Index zu Atemfrequenz (Atemzüge/min)
            let breathsPerMin = Float(maxFreqIndex) * (60.0 / Float(fftSize))
            return breathsPerMin > 3.0 && breathsPerMin < 8.0 ? breathsPerMin : nil
        }

        private func isInFlowState(hrvData: [Float], coherenceData: [Float]) -> Bool {
            guard !hrvData.isEmpty && !coherenceData.isEmpty else { return false }

            let recentHRV = Array(hrvData.suffix(10))
            let recentCoherence = Array(coherenceData.suffix(10))

            let avgCoherence = recentCoherence.reduce(0, +) / Float(recentCoherence.count)
            let hrvVariance = calculateVariance(recentHRV)

            return avgCoherence > 0.7 && hrvVariance < 0.05
        }

        private func calculateVariance(_ data: [Float]) -> Float {
            guard data.count > 1 else { return 0.0 }
            let mean = data.reduce(0, +) / Float(data.count)
            let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Float(data.count)
            return variance
        }

        struct RecognizedPattern {
            let type: PatternType
            let confidence: Float
            let description: String

            enum PatternType {
                case coherenceBuilding
                case stressResponse
                case resonanceFrequency
                case flowState
                case fatigueOnset
                case recoveryPhase
            }
        }
    }

    // MARK: - Audio Feature Extractor

    class AudioFeatureExtractor {
        func extractFeatures(audioBuffer: [Float], sampleRate: Float) -> MusicStyleClassifier.AudioFeatures {
            // Tempo Estimation (vereinfacht)
            let tempo = estimateTempo(audioBuffer: audioBuffer, sampleRate: sampleRate)

            // Spectral Features
            let spectralCentroid = calculateSpectralCentroid(audioBuffer: audioBuffer)
            let spectralRolloff = calculateSpectralRolloff(audioBuffer: audioBuffer)
            let zeroCrossingRate = calculateZeroCrossingRate(audioBuffer: audioBuffer)

            // MFCC (vereinfacht - 13 Koeffizienten)
            let mfcc = calculateMFCC(audioBuffer: audioBuffer, coefficients: 13)

            // Complexity Metrics
            let rhythmComplexity = calculateRhythmComplexity(audioBuffer: audioBuffer)
            let harmonicComplexity = calculateHarmonicComplexity(audioBuffer: audioBuffer)

            return MusicStyleClassifier.AudioFeatures(
                tempo: tempo,
                spectralCentroid: spectralCentroid,
                spectralRolloff: spectralRolloff,
                zeroCrossingRate: zeroCrossingRate,
                mfcc: mfcc,
                rhythmComplexity: rhythmComplexity,
                harmonicComplexity: harmonicComplexity
            )
        }

        private func estimateTempo(audioBuffer: [Float], sampleRate: Float) -> Float {
            // Tempo estimation via onset detection + autocorrelation
            let hopSize = 512
            let windowSize = 1024
            guard audioBuffer.count >= windowSize * 2 else { return 120.0 }

            // 1. Calculate onset strength envelope
            var onsetStrength: [Float] = []
            var prevSpectralFlux: Float = 0

            for i in stride(from: 0, to: audioBuffer.count - windowSize, by: hopSize) {
                let frame = Array(audioBuffer[i..<i+windowSize])
                let energy = frame.reduce(0) { $0 + $1 * $1 }

                // Simple spectral flux (energy difference)
                let flux = max(0, energy - prevSpectralFlux)
                onsetStrength.append(flux)
                prevSpectralFlux = energy
            }

            guard onsetStrength.count > 100 else { return 120.0 }

            // 2. Autocorrelation to find periodicity
            let minLag = Int(60.0 / 200.0 * sampleRate / Float(hopSize))  // 200 BPM
            let maxLag = Int(60.0 / 60.0 * sampleRate / Float(hopSize))   // 60 BPM

            var bestCorr: Float = 0
            var bestLag = minLag

            for lag in minLag..<min(maxLag, onsetStrength.count / 2) {
                var correlation: Float = 0
                for i in 0..<(onsetStrength.count - lag) {
                    correlation += onsetStrength[i] * onsetStrength[i + lag]
                }

                if correlation > bestCorr {
                    bestCorr = correlation
                    bestLag = lag
                }
            }

            // Convert lag to BPM
            let tempo = 60.0 * sampleRate / Float(hopSize * bestLag)
            return max(60, min(200, tempo))  // Clamp to reasonable range
        }

        private func calculateSpectralCentroid(audioBuffer: [Float]) -> Float {
            let fftSize = 1024
            guard audioBuffer.count >= fftSize else { return 0.5 }

            // Vereinfachte FFT
            var sum: Float = 0.0
            var weightedSum: Float = 0.0

            for i in 0..<fftSize {
                let magnitude = abs(audioBuffer[i])
                sum += magnitude
                weightedSum += Float(i) * magnitude
            }

            return sum > 0 ? (weightedSum / sum) / Float(fftSize) : 0.5
        }

        private func calculateSpectralRolloff(audioBuffer: [Float]) -> Float {
            // Frequency below which 85% of spectral energy is contained
            let fftSize = 1024
            guard audioBuffer.count >= fftSize else { return 0.5 }

            // Calculate magnitude spectrum (simplified DFT)
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            for k in 0..<(fftSize / 2) {
                var sumReal: Float = 0
                var sumImag: Float = 0
                let omega = 2.0 * Float.pi * Float(k) / Float(fftSize)

                for n in 0..<fftSize {
                    let sample = audioBuffer[n]
                    sumReal += sample * cos(omega * Float(n))
                    sumImag += sample * sin(omega * Float(n))
                }

                magnitudes[k] = sqrt(sumReal * sumReal + sumImag * sumImag)
            }

            // Calculate total energy
            let totalEnergy = magnitudes.reduce(0) { $0 + $1 * $1 }
            let threshold = totalEnergy * 0.85

            // Find rolloff point
            var cumulativeEnergy: Float = 0
            for k in 0..<magnitudes.count {
                cumulativeEnergy += magnitudes[k] * magnitudes[k]
                if cumulativeEnergy >= threshold {
                    return Float(k) / Float(magnitudes.count)
                }
            }

            return 1.0
        }

        private func calculateZeroCrossingRate(audioBuffer: [Float]) -> Float {
            var crossings = 0
            for i in 1..<audioBuffer.count {
                if (audioBuffer[i] >= 0 && audioBuffer[i-1] < 0) ||
                   (audioBuffer[i] < 0 && audioBuffer[i-1] >= 0) {
                    crossings += 1
                }
            }
            return Float(crossings) / Float(audioBuffer.count)
        }

        private func calculateMFCC(audioBuffer: [Float], coefficients: Int) -> [Float] {
            // MFCC: Mel-Frequency Cepstral Coefficients
            let fftSize = 1024
            let numMelBands = 26
            guard audioBuffer.count >= fftSize else {
                return [Float](repeating: 0.5, count: coefficients)
            }

            // 1. Calculate power spectrum
            var powerSpectrum = [Float](repeating: 0, count: fftSize / 2)
            for k in 0..<(fftSize / 2) {
                var sumReal: Float = 0
                var sumImag: Float = 0
                let omega = 2.0 * Float.pi * Float(k) / Float(fftSize)

                for n in 0..<fftSize {
                    let sample = audioBuffer[n]
                    sumReal += sample * cos(omega * Float(n))
                    sumImag += sample * sin(omega * Float(n))
                }

                powerSpectrum[k] = (sumReal * sumReal + sumImag * sumImag) / Float(fftSize)
            }

            // 2. Apply Mel filterbank (triangular filters on Mel scale)
            var melEnergies = [Float](repeating: 0, count: numMelBands)
            let melMin: Float = 0
            let melMax: Float = 2595.0 * log10(1.0 + 22050.0 / 700.0)

            for m in 0..<numMelBands {
                let melCenter = melMin + Float(m + 1) * (melMax - melMin) / Float(numMelBands + 1)
                let freqCenter = 700.0 * (pow(10.0, melCenter / 2595.0) - 1.0)
                let binCenter = Int(freqCenter * Float(fftSize) / 44100.0)

                // Triangular filter
                let bandwidth = Int(Float(fftSize) / Float(numMelBands))
                let binStart = max(0, binCenter - bandwidth / 2)
                let binEnd = min(fftSize / 2, binCenter + bandwidth / 2)

                for k in binStart..<binEnd {
                    let weight = 1.0 - abs(Float(k - binCenter)) / Float(bandwidth / 2)
                    melEnergies[m] += powerSpectrum[k] * max(0, weight)
                }

                // Log compression
                melEnergies[m] = log(melEnergies[m] + 1e-10)
            }

            // 3. DCT to get MFCCs
            var mfcc = [Float](repeating: 0, count: coefficients)
            for i in 0..<coefficients {
                for j in 0..<numMelBands {
                    mfcc[i] += melEnergies[j] * cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(numMelBands))
                }
                mfcc[i] *= sqrt(2.0 / Float(numMelBands))
            }

            return mfcc
        }

        private func calculateRhythmComplexity(audioBuffer: [Float]) -> Float {
            // Rhythm complexity via variability of inter-onset intervals
            let hopSize = 512
            let windowSize = 1024
            guard audioBuffer.count >= windowSize * 4 else { return 0.5 }

            // Detect onsets via spectral flux
            var onsetTimes: [Int] = []
            var prevEnergy: Float = 0
            let threshold: Float = 0.1

            for i in stride(from: 0, to: audioBuffer.count - windowSize, by: hopSize) {
                let frame = Array(audioBuffer[i..<i+windowSize])
                let energy = frame.reduce(0) { $0 + $1 * $1 } / Float(windowSize)

                // Peak detection
                if energy > prevEnergy + threshold && energy > 0.01 {
                    onsetTimes.append(i)
                }
                prevEnergy = energy
            }

            guard onsetTimes.count > 2 else { return 0.5 }

            // Calculate inter-onset intervals
            var intervals: [Int] = []
            for i in 1..<onsetTimes.count {
                intervals.append(onsetTimes[i] - onsetTimes[i-1])
            }

            // Calculate coefficient of variation (std / mean)
            let mean = Float(intervals.reduce(0, +)) / Float(intervals.count)
            let variance = intervals.reduce(Float(0)) { $0 + pow(Float($1) - mean, 2) } / Float(intervals.count)
            let std = sqrt(variance)

            // Normalize to 0-1 range (higher = more complex)
            let cv = mean > 0 ? std / mean : 0
            return min(1.0, cv)
        }

        private func calculateHarmonicComplexity(audioBuffer: [Float]) -> Float {
            // Harmonic complexity via spectral flatness and peak count
            let fftSize = 1024
            guard audioBuffer.count >= fftSize else { return 0.5 }

            // Calculate magnitude spectrum
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            for k in 0..<(fftSize / 2) {
                var sumReal: Float = 0
                var sumImag: Float = 0
                let omega = 2.0 * Float.pi * Float(k) / Float(fftSize)

                for n in 0..<fftSize {
                    sumReal += audioBuffer[n] * cos(omega * Float(n))
                    sumImag += audioBuffer[n] * sin(omega * Float(n))
                }

                magnitudes[k] = sqrt(sumReal * sumReal + sumImag * sumImag)
            }

            // Count significant peaks (local maxima above threshold)
            let maxMag = magnitudes.max() ?? 1
            let threshold = maxMag * 0.1
            var peakCount = 0

            for i in 1..<(magnitudes.count - 1) {
                if magnitudes[i] > magnitudes[i-1] &&
                   magnitudes[i] > magnitudes[i+1] &&
                   magnitudes[i] > threshold {
                    peakCount += 1
                }
            }

            // Normalize: more peaks = more harmonic complexity
            // Typical music has 5-50 significant peaks
            return min(1.0, Float(peakCount) / 50.0)
        }
    }

    // MARK: - Initialization

    init() {
        emotionClassifier = EmotionClassifier()
        styleClassifier = MusicStyleClassifier()
        parameterPredictor = ParameterPredictor()
        patternRecognizer = PatternRecognizer()
        audioFeatureExtractor = AudioFeatureExtractor()
    }

    // MARK: - Public Methods

    func classifyEmotion(hrv: Float, coherence: Float, heartRate: Float, variability: Float,
                        hrvTrend: Float, coherenceTrend: Float) {
        let features = EmotionClassifier.EmotionFeatures(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            variability: variability,
            hrvTrend: hrvTrend,
            coherenceTrend: coherenceTrend
        )

        let result = emotionClassifier?.classify(features: features)
        currentEmotion = result?.emotion ?? .neutral
        predictions.emotionConfidence = result?.confidence ?? 0.0

        print("🎭 Emotion: \(currentEmotion.rawValue) (Confidence: \(String(format: "%.2f", predictions.emotionConfidence)))")
    }

    func classifyMusicStyle(audioBuffer: [Float], sampleRate: Float) {
        guard let extractor = audioFeatureExtractor else { return }

        let features = extractor.extractFeatures(audioBuffer: audioBuffer, sampleRate: sampleRate)
        let result = styleClassifier?.classify(features: features)

        detectedMusicStyle = result?.style ?? .unknown
        predictions.styleConfidence = result?.confidence ?? 0.0

        print("🎵 Music Style: \(detectedMusicStyle.rawValue) (Confidence: \(String(format: "%.2f", predictions.styleConfidence)))")
    }

    func generateRecommendations(emotion: Emotion, style: MusicStyle) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Emotionsbasierte Empfehlungen
        switch emotion {
        case .energetic:
            recommendations.append(Recommendation(
                type: .effect,
                title: "Distortion hinzufügen",
                description: "Für mehr Energie und Durchsetzungskraft",
                confidence: 0.8,
                parameters: ["amount": 0.4]
            ))

        case .calm:
            recommendations.append(Recommendation(
                type: .effect,
                title: "Reverb erhöhen",
                description: "Für mehr Raum und Ruhe",
                confidence: 0.85,
                parameters: ["mix": 0.6, "size": 0.8]
            ))

        case .anxious:
            recommendations.append(Recommendation(
                type: .scale,
                title: "Moll-Tonart wechseln",
                description: "Für emotionale Tiefe",
                confidence: 0.7,
                parameters: ["scale": "Natural Minor"]
            ))

        default:
            break
        }

        // Stilbasierte Empfehlungen
        switch style {
        case .electronic:
            recommendations.append(Recommendation(
                type: .instrument,
                title: "FM-Synthesizer verwenden",
                description: "Typisch für elektronische Musik",
                confidence: 0.9,
                parameters: ["modIndex": 2.0, "modRatio": 2.0]
            ))

        case .jazz:
            recommendations.append(Recommendation(
                type: .scale,
                title: "Bebop-Skala probieren",
                description: "Authentischer Jazz-Sound",
                confidence: 0.85,
                parameters: ["scale": "Bebop Dominant"]
            ))

        default:
            break
        }

        self.recommendations = recommendations
        return recommendations
    }

    func recognizePatterns(hrvData: [Float], coherenceData: [Float]) -> [PatternRecognizer.RecognizedPattern] {
        guard let recognizer = patternRecognizer else { return [] }
        return recognizer.recognizePatterns(hrvData: hrvData, coherenceData: coherenceData)
    }
}
