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
class EnhancedMLModels: ObservableObject {

    // MARK: - Published Properties

    /// Erkannte Emotion
    @Published var currentEmotion: Emotion = .neutral

    /// Erkannter Musikstil
    @Published var detectedMusicStyle: MusicStyle = .unknown

    /// ML-Vorhersagen
    @Published var predictions: MLPredictions = MLPredictions()

    /// Empfehlungen
    @Published var recommendations: [Recommendation] = []

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
            log.info("📚 Trained emotion classifier with \(trainingData.count) samples", category: .system)
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
            // Autocorrelation-based tempo estimation
            // Search for periodicity in 60-180 BPM range

            guard audioBuffer.count >= 8192 else { return 120.0 }

            // Calculate onset envelope (energy per frame)
            let frameSize = 512
            let hopSize = 256
            let numFrames = (audioBuffer.count - frameSize) / hopSize
            var onsetEnvelope = [Float](repeating: 0, count: numFrames)

            for frame in 0..<numFrames {
                let start = frame * hopSize
                var energy: Float = 0
                for i in 0..<frameSize {
                    if start + i < audioBuffer.count {
                        energy += audioBuffer[start + i] * audioBuffer[start + i]
                    }
                }
                onsetEnvelope[frame] = sqrt(energy / Float(frameSize))
            }

            // Differentiate to get onset detection function
            var onsetDiff = [Float](repeating: 0, count: onsetEnvelope.count)
            for i in 1..<onsetEnvelope.count {
                onsetDiff[i] = max(0, onsetEnvelope[i] - onsetEnvelope[i - 1])
            }

            // Autocorrelation to find periodicity
            let minLag = Int(60.0 / 180.0 * Float(sampleRate) / Float(hopSize))  // 180 BPM
            let maxLag = Int(60.0 / 60.0 * Float(sampleRate) / Float(hopSize))   // 60 BPM

            var maxCorrelation: Float = 0
            var bestLag = minLag

            for lag in minLag..<min(maxLag, onsetDiff.count / 2) {
                var correlation: Float = 0
                var count = 0
                for i in 0..<(onsetDiff.count - lag) {
                    correlation += onsetDiff[i] * onsetDiff[i + lag]
                    count += 1
                }
                if count > 0 {
                    correlation /= Float(count)
                }

                if correlation > maxCorrelation {
                    maxCorrelation = correlation
                    bestLag = lag
                }
            }

            // Convert lag to BPM
            let beatPeriodSamples = Float(bestLag * hopSize)
            let beatPeriodSeconds = beatPeriodSamples / sampleRate
            let bpm = 60.0 / beatPeriodSeconds

            // Clamp to reasonable range
            return max(60.0, min(180.0, bpm))
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
            // Calculate frequency where 85% of spectral energy is below
            let fftSize = 1024
            guard audioBuffer.count >= fftSize else { return 0.5 }

            // Calculate magnitude spectrum using simple DFT
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)

            for k in 0..<(fftSize / 2) {
                var real: Float = 0
                var imag: Float = 0
                for n in 0..<fftSize {
                    let angle = -2.0 * Float.pi * Float(k * n) / Float(fftSize)
                    real += audioBuffer[n] * cos(angle)
                    imag += audioBuffer[n] * sin(angle)
                }
                magnitudes[k] = sqrt(real * real + imag * imag)
            }

            // Calculate total energy
            let totalEnergy = magnitudes.reduce(0) { $0 + $1 * $1 }
            guard totalEnergy > 0 else { return 0.5 }

            // Find 85% rolloff point
            let threshold = totalEnergy * 0.85
            var cumulativeEnergy: Float = 0
            var rolloffBin = magnitudes.count - 1

            for i in 0..<magnitudes.count {
                cumulativeEnergy += magnitudes[i] * magnitudes[i]
                if cumulativeEnergy >= threshold {
                    rolloffBin = i
                    break
                }
            }

            // Normalize to 0-1 range
            return Float(rolloffBin) / Float(magnitudes.count)
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
            // Mel-Frequency Cepstral Coefficients calculation
            let fftSize = 512
            let numFilters = 26
            let sampleRate: Float = 44100.0

            guard audioBuffer.count >= fftSize else {
                return [Float](repeating: 0.0, count: coefficients)
            }

            // Step 1: Apply Hamming window and calculate power spectrum
            var windowedSignal = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                let window = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(fftSize - 1))
                windowedSignal[i] = audioBuffer[i] * window
            }

            // Calculate power spectrum via DFT
            var powerSpectrum = [Float](repeating: 0, count: fftSize / 2 + 1)
            for k in 0...(fftSize / 2) {
                var real: Float = 0
                var imag: Float = 0
                for n in 0..<fftSize {
                    let angle = -2.0 * Float.pi * Float(k * n) / Float(fftSize)
                    real += windowedSignal[n] * cos(angle)
                    imag += windowedSignal[n] * sin(angle)
                }
                powerSpectrum[k] = (real * real + imag * imag) / Float(fftSize)
            }

            // Step 2: Apply Mel filterbank
            // Convert Hz to Mel: mel = 2595 * log10(1 + f/700)
            func hzToMel(_ hz: Float) -> Float {
                return 2595.0 * log10(1.0 + hz / 700.0)
            }
            func melToHz(_ mel: Float) -> Float {
                return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
            }

            let lowFreq: Float = 0.0
            let highFreq = sampleRate / 2.0
            let lowMel = hzToMel(lowFreq)
            let highMel = hzToMel(highFreq)

            // Create mel filter center frequencies
            var melPoints = [Float](repeating: 0, count: numFilters + 2)
            let melStep = (highMel - lowMel) / Float(numFilters + 1)
            for i in 0..<(numFilters + 2) {
                melPoints[i] = lowMel + Float(i) * melStep
            }

            // Convert back to Hz and then to FFT bin indices
            var binPoints = [Int](repeating: 0, count: numFilters + 2)
            for i in 0..<(numFilters + 2) {
                let hz = melToHz(melPoints[i])
                binPoints[i] = Int(floor((Float(fftSize) + 1.0) * hz / sampleRate))
            }

            // Apply mel filters
            var filterOutput = [Float](repeating: 0, count: numFilters)
            for m in 0..<numFilters {
                let leftBin = binPoints[m]
                let centerBin = binPoints[m + 1]
                let rightBin = binPoints[m + 2]

                // Triangular filter
                for k in leftBin..<centerBin {
                    if k < powerSpectrum.count && centerBin > leftBin {
                        let weight = Float(k - leftBin) / Float(centerBin - leftBin)
                        filterOutput[m] += powerSpectrum[k] * weight
                    }
                }
                for k in centerBin..<rightBin {
                    if k < powerSpectrum.count && rightBin > centerBin {
                        let weight = Float(rightBin - k) / Float(rightBin - centerBin)
                        filterOutput[m] += powerSpectrum[k] * weight
                    }
                }

                // Apply log compression
                filterOutput[m] = Darwin.log(max(filterOutput[m], 1e-10))
            }

            // Step 3: DCT to get MFCCs
            var mfcc = [Float](repeating: 0, count: coefficients)
            for k in 0..<coefficients {
                for n in 0..<numFilters {
                    let angle = Float.pi * Float(k) * (Float(n) + 0.5) / Float(numFilters)
                    mfcc[k] += filterOutput[n] * cos(angle)
                }
                // Normalize
                mfcc[k] *= sqrt(2.0 / Float(numFilters))
            }

            return mfcc
        }

        private func calculateRhythmComplexity(audioBuffer: [Float]) -> Float {
            // Measure variability of onset intervals (inter-onset intervals)
            // High variability = complex rhythm, low = simple rhythm

            let frameSize = 512
            let hopSize = 256
            guard audioBuffer.count >= frameSize * 4 else { return 0.5 }

            let numFrames = (audioBuffer.count - frameSize) / hopSize

            // Calculate onset detection function (spectral flux)
            var onsetFunction = [Float](repeating: 0, count: numFrames)
            var prevSpectrum = [Float](repeating: 0, count: frameSize / 2)

            for frame in 0..<numFrames {
                let start = frame * hopSize
                var currentSpectrum = [Float](repeating: 0, count: frameSize / 2)

                // Simple magnitude spectrum
                for k in 0..<(frameSize / 2) {
                    var magnitude: Float = 0
                    for n in 0..<frameSize {
                        if start + n < audioBuffer.count {
                            let angle = -2.0 * Float.pi * Float(k * n) / Float(frameSize)
                            magnitude += audioBuffer[start + n] * cos(angle)
                        }
                    }
                    currentSpectrum[k] = abs(magnitude)
                }

                // Spectral flux (positive differences only)
                var flux: Float = 0
                for k in 0..<(frameSize / 2) {
                    let diff = currentSpectrum[k] - prevSpectrum[k]
                    if diff > 0 { flux += diff }
                }
                onsetFunction[frame] = flux
                prevSpectrum = currentSpectrum
            }

            // Find onset peaks (simple threshold)
            var onsets: [Int] = []
            let threshold = onsetFunction.reduce(0, +) / Float(onsetFunction.count) * 1.5

            for i in 1..<(onsetFunction.count - 1) {
                if onsetFunction[i] > threshold &&
                   onsetFunction[i] > onsetFunction[i - 1] &&
                   onsetFunction[i] > onsetFunction[i + 1] {
                    onsets.append(i)
                }
            }

            guard onsets.count > 2 else { return 0.5 }

            // Calculate inter-onset intervals
            var intervals = [Float]()
            for i in 1..<onsets.count {
                intervals.append(Float(onsets[i] - onsets[i - 1]))
            }

            // Calculate coefficient of variation (stddev / mean)
            let mean = intervals.reduce(0, +) / Float(intervals.count)
            guard mean > 0 else { return 0.5 }

            let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Float(intervals.count)
            let stddev = sqrt(variance)
            let cv = stddev / mean

            // Normalize to 0-1 range (CV > 1 means high complexity)
            return min(cv, 1.0)
        }

        private func calculateHarmonicComplexity(audioBuffer: [Float]) -> Float {
            // Count number of significant spectral peaks relative to total
            // More peaks = more complex harmonic content

            let fftSize = 1024
            guard audioBuffer.count >= fftSize else { return 0.5 }

            // Calculate magnitude spectrum
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)

            for k in 0..<(fftSize / 2) {
                var real: Float = 0
                var imag: Float = 0
                for n in 0..<fftSize {
                    let angle = -2.0 * Float.pi * Float(k * n) / Float(fftSize)
                    real += audioBuffer[n] * cos(angle)
                    imag += audioBuffer[n] * sin(angle)
                }
                magnitudes[k] = sqrt(real * real + imag * imag)
            }

            // Find maximum magnitude for threshold
            let maxMag = magnitudes.max() ?? 1.0
            guard maxMag > 0 else { return 0.5 }

            // Threshold at -20dB from peak
            let threshold = maxMag * 0.1  // -20dB

            // Count spectral peaks above threshold
            var peakCount = 0
            for i in 1..<(magnitudes.count - 1) {
                if magnitudes[i] > threshold &&
                   magnitudes[i] > magnitudes[i - 1] &&
                   magnitudes[i] > magnitudes[i + 1] {
                    peakCount += 1
                }
            }

            // Normalize: simple sine = 1 peak, complex = many peaks
            // Consider 1-5 peaks simple (0-0.3), 5-15 moderate (0.3-0.7), 15+ complex (0.7-1.0)
            if peakCount <= 5 {
                return Float(peakCount) / 5.0 * 0.3
            } else if peakCount <= 15 {
                return 0.3 + Float(peakCount - 5) / 10.0 * 0.4
            } else {
                return min(0.7 + Float(peakCount - 15) / 30.0 * 0.3, 1.0)
            }
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

        log.info("🎭 Emotion: \(currentEmotion.rawValue) (Confidence: \(String(format: "%.2f", predictions.emotionConfidence)))", category: .system)
    }

    func classifyMusicStyle(audioBuffer: [Float], sampleRate: Float) {
        guard let extractor = audioFeatureExtractor else { return }

        let features = extractor.extractFeatures(audioBuffer: audioBuffer, sampleRate: sampleRate)
        let result = styleClassifier?.classify(features: features)

        detectedMusicStyle = result?.style ?? .unknown
        predictions.styleConfidence = result?.confidence ?? 0.0

        log.info("🎵 Music Style: \(detectedMusicStyle.rawValue) (Confidence: \(String(format: "%.2f", predictions.styleConfidence)))", category: .system)
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
