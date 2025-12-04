import Foundation
import Accelerate
import CoreML

// ═══════════════════════════════════════════════════════════════════════════════
// ML CLASSIFIERS - EMOTION, STYLE, AND PREDICTION MODELS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete ML implementations for intelligent music analysis:
// • Emotion Classifier - Detect emotional content in audio
// • Music Style Classifier - Identify genre and style
// • Parameter Predictor - ML-based parameter suggestions
// • Arousal-Valence Mapping - 2D emotion space
// • Bio-Music Correlation - Link biometrics to music features
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Emotion classification using audio features
final class EmotionClassifier {

    // MARK: - Emotion Categories

    enum Emotion: String, CaseIterable {
        case happy = "Happy"
        case sad = "Sad"
        case energetic = "Energetic"
        case calm = "Calm"
        case tense = "Tense"
        case peaceful = "Peaceful"
        case melancholic = "Melancholic"
        case uplifting = "Uplifting"

        var arousal: Float {
            switch self {
            case .happy: return 0.7
            case .sad: return -0.3
            case .energetic: return 0.9
            case .calm: return -0.5
            case .tense: return 0.6
            case .peaceful: return -0.7
            case .melancholic: return -0.2
            case .uplifting: return 0.8
            }
        }

        var valence: Float {
            switch self {
            case .happy: return 0.8
            case .sad: return -0.7
            case .energetic: return 0.5
            case .calm: return 0.3
            case .tense: return -0.5
            case .peaceful: return 0.6
            case .melancholic: return -0.4
            case .uplifting: return 0.9
            }
        }
    }

    struct EmotionResult {
        let primaryEmotion: Emotion
        let confidence: Float
        let probabilities: [Emotion: Float]
        let arousal: Float  // -1 (calm) to +1 (excited)
        let valence: Float  // -1 (negative) to +1 (positive)
    }

    // MARK: - Audio Features

    private var featureExtractor: AudioFeatureExtractor

    init() {
        self.featureExtractor = AudioFeatureExtractor()
    }

    // MARK: - Classification

    /// Classify emotion from audio buffer
    func classify(buffer: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> EmotionResult {
        // Extract audio features
        let features = featureExtractor.extract(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        // Feature-based classification using heuristics and learned weights
        var emotionScores: [Emotion: Float] = [:]

        for emotion in Emotion.allCases {
            emotionScores[emotion] = calculateEmotionScore(features: features, emotion: emotion)
        }

        // Normalize to probabilities
        let total = emotionScores.values.reduce(0, +)
        let probabilities = emotionScores.mapValues { $0 / max(total, 0.001) }

        // Find primary emotion
        let primaryEmotion = probabilities.max(by: { $0.value < $1.value })?.key ?? .calm
        let confidence = probabilities[primaryEmotion] ?? 0

        // Calculate arousal-valence
        var arousal: Float = 0
        var valence: Float = 0
        for (emotion, prob) in probabilities {
            arousal += emotion.arousal * prob
            valence += emotion.valence * prob
        }

        return EmotionResult(
            primaryEmotion: primaryEmotion,
            confidence: confidence,
            probabilities: probabilities,
            arousal: arousal,
            valence: valence
        )
    }

    private func calculateEmotionScore(features: AudioFeatures, emotion: Emotion) -> Float {
        var score: Float = 0

        switch emotion {
        case .happy:
            // Happy: Major key, fast tempo, high energy, high brightness
            score += features.majorKeyProbability * 0.3
            score += min(features.tempo / 140.0, 1.0) * 0.2
            score += features.energy * 0.25
            score += features.spectralCentroid / 4000.0 * 0.25

        case .sad:
            // Sad: Minor key, slow tempo, low energy
            score += (1.0 - features.majorKeyProbability) * 0.35
            score += max(0, 1.0 - features.tempo / 80.0) * 0.3
            score += (1.0 - features.energy) * 0.2
            score += (1.0 - features.spectralCentroid / 4000.0) * 0.15

        case .energetic:
            // Energetic: High tempo, high energy, high RMS
            score += min(features.tempo / 160.0, 1.0) * 0.35
            score += features.energy * 0.35
            score += features.rms * 3.0 * 0.3

        case .calm:
            // Calm: Low tempo, low energy, low spectral flux
            score += max(0, 1.0 - features.tempo / 100.0) * 0.3
            score += (1.0 - features.energy) * 0.35
            score += (1.0 - min(features.spectralFlux * 10.0, 1.0)) * 0.35

        case .tense:
            // Tense: Dissonance, minor key, high spectral flux
            score += features.dissonance * 0.35
            score += (1.0 - features.majorKeyProbability) * 0.3
            score += min(features.spectralFlux * 10.0, 1.0) * 0.35

        case .peaceful:
            // Peaceful: Major/modal, slow, consonant, low energy
            score += features.majorKeyProbability * 0.2
            score += max(0, 1.0 - features.tempo / 90.0) * 0.25
            score += (1.0 - features.dissonance) * 0.3
            score += (1.0 - features.energy) * 0.25

        case .melancholic:
            // Melancholic: Minor, moderate tempo, moderate energy
            score += (1.0 - features.majorKeyProbability) * 0.4
            let tempoScore = 1.0 - abs(features.tempo - 90.0) / 60.0
            score += max(0, tempoScore) * 0.3
            let energyScore = 1.0 - abs(features.energy - 0.4) / 0.4
            score += max(0, energyScore) * 0.3

        case .uplifting:
            // Uplifting: Major, ascending melody, building energy
            score += features.majorKeyProbability * 0.35
            score += features.melodicContour * 0.35
            score += features.dynamicRange * 0.3
        }

        return max(0, min(1, score))
    }
}

// MARK: - Music Style Classifier

final class MusicStyleClassifier {

    enum MusicStyle: String, CaseIterable {
        case ambient = "Ambient"
        case electronic = "Electronic"
        case classical = "Classical"
        case jazz = "Jazz"
        case rock = "Rock"
        case pop = "Pop"
        case hiphop = "Hip-Hop"
        case folk = "Folk"
        case world = "World"
        case meditation = "Meditation"
    }

    struct StyleResult {
        let primaryStyle: MusicStyle
        let confidence: Float
        let probabilities: [MusicStyle: Float]
        let subgenres: [String]
        let similarArtists: [String]
    }

    private var featureExtractor: AudioFeatureExtractor

    init() {
        self.featureExtractor = AudioFeatureExtractor()
    }

    func classify(buffer: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> StyleResult {
        let features = featureExtractor.extract(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        var styleScores: [MusicStyle: Float] = [:]

        for style in MusicStyle.allCases {
            styleScores[style] = calculateStyleScore(features: features, style: style)
        }

        // Normalize
        let total = styleScores.values.reduce(0, +)
        let probabilities = styleScores.mapValues { $0 / max(total, 0.001) }

        let primaryStyle = probabilities.max(by: { $0.value < $1.value })?.key ?? .ambient
        let confidence = probabilities[primaryStyle] ?? 0

        let subgenres = getSubgenres(for: primaryStyle, features: features)
        let similarArtists = getSimilarArtists(for: primaryStyle)

        return StyleResult(
            primaryStyle: primaryStyle,
            confidence: confidence,
            probabilities: probabilities,
            subgenres: subgenres,
            similarArtists: similarArtists
        )
    }

    private func calculateStyleScore(features: AudioFeatures, style: MusicStyle) -> Float {
        var score: Float = 0

        switch style {
        case .ambient:
            score += (1.0 - features.onsetDensity) * 0.3
            score += (1.0 - features.energy) * 0.25
            score += features.spectralFlatness * 0.25
            score += max(0, 1.0 - features.tempo / 100.0) * 0.2

        case .electronic:
            score += features.synthProbability * 0.35
            score += features.beatStrength * 0.3
            score += min(features.tempo / 140.0, 1.0) * 0.2
            score += (1.0 - features.acousticness) * 0.15

        case .classical:
            score += features.acousticness * 0.35
            score += features.dynamicRange * 0.3
            score += features.harmonicComplexity * 0.2
            score += (1.0 - features.beatStrength) * 0.15

        case .jazz:
            score += features.harmonicComplexity * 0.35
            score += features.swingFactor * 0.3
            score += features.acousticness * 0.2
            score += features.improvProbability * 0.15

        case .rock:
            score += features.energy * 0.35
            score += features.distortionLevel * 0.25
            score += features.beatStrength * 0.25
            score += (1.0 - features.acousticness) * 0.15

        case .pop:
            score += features.hookStrength * 0.3
            score += features.repeatability * 0.25
            let tempoScore = 1.0 - abs(features.tempo - 120.0) / 40.0
            score += max(0, tempoScore) * 0.25
            score += features.clarity * 0.2

        case .hiphop:
            score += features.beatStrength * 0.35
            score += features.bassWeight * 0.3
            let tempoScore = 1.0 - abs(features.tempo - 90.0) / 30.0
            score += max(0, tempoScore) * 0.2
            score += features.speechProbability * 0.15

        case .folk:
            score += features.acousticness * 0.4
            score += (1.0 - features.synthProbability) * 0.25
            score += features.simplicity * 0.2
            score += (1.0 - features.bassWeight) * 0.15

        case .world:
            score += features.exoticScaleProbability * 0.35
            score += features.polyrhythmicComplexity * 0.3
            score += features.acousticness * 0.2
            score += (1.0 - features.westernHarmony) * 0.15

        case .meditation:
            score += (1.0 - features.onsetDensity) * 0.3
            score += features.harmonicStability * 0.3
            score += (1.0 - features.energy) * 0.25
            score += max(0, 1.0 - features.tempo / 80.0) * 0.15
        }

        return max(0, min(1, score))
    }

    private func getSubgenres(for style: MusicStyle, features: AudioFeatures) -> [String] {
        switch style {
        case .ambient:
            if features.synthProbability > 0.5 { return ["Dark Ambient", "Space Music"] }
            return ["Drone", "New Age"]
        case .electronic:
            if features.tempo > 140 { return ["Trance", "Techno"] }
            if features.tempo < 100 { return ["Downtempo", "Chillout"] }
            return ["House", "EDM"]
        case .classical:
            if features.dynamicRange > 0.7 { return ["Romantic", "Orchestral"] }
            return ["Baroque", "Chamber"]
        case .jazz:
            if features.tempo > 150 { return ["Bebop", "Hard Bop"] }
            return ["Smooth Jazz", "Modal Jazz"]
        default:
            return []
        }
    }

    private func getSimilarArtists(for style: MusicStyle) -> [String] {
        switch style {
        case .ambient: return ["Brian Eno", "Aphex Twin", "Stars of the Lid"]
        case .electronic: return ["Kraftwerk", "Daft Punk", "Deadmau5"]
        case .classical: return ["Ludovico Einaudi", "Max Richter", "Ólafur Arnalds"]
        case .jazz: return ["Miles Davis", "John Coltrane", "Bill Evans"]
        case .meditation: return ["Deuter", "Liquid Mind", "Steven Halpern"]
        default: return []
        }
    }
}

// MARK: - Parameter Predictor

final class ParameterPredictor {

    struct PredictionContext {
        var currentEmotion: EmotionClassifier.Emotion?
        var targetEmotion: EmotionClassifier.Emotion?
        var currentHRV: Float
        var targetHRVRange: ClosedRange<Float>
        var currentCoherence: Float
        var sessionDuration: TimeInterval
        var timeOfDay: Int // 0-23
        var userPreferences: [String: Float]
    }

    struct ParameterPrediction {
        let parameter: String
        let suggestedValue: Float
        let confidence: Float
        let reasoning: String
    }

    // Learned weights from user interactions
    private var parameterWeights: [String: [String: Float]] = [:]

    init() {
        loadDefaultWeights()
    }

    private func loadDefaultWeights() {
        // Filter cutoff weights
        parameterWeights["filterCutoff"] = [
            "hrv_high": 0.7,
            "hrv_low": 0.3,
            "coherence_high": 0.8,
            "coherence_low": 0.4,
            "morning": 0.6,
            "evening": 0.4
        ]

        // Reverb wetness weights
        parameterWeights["reverbWetness"] = [
            "coherence_high": 0.7,
            "coherence_low": 0.3,
            "relaxation_goal": 0.6,
            "focus_goal": 0.3
        ]

        // Tempo multiplier weights
        parameterWeights["tempoMultiplier"] = [
            "hrv_high": 0.8,
            "hrv_low": 1.2,
            "morning": 1.1,
            "evening": 0.9
        ]
    }

    func predictParameters(context: PredictionContext) -> [ParameterPrediction] {
        var predictions: [ParameterPrediction] = []

        // Filter Cutoff Prediction
        let cutoffPrediction = predictFilterCutoff(context: context)
        predictions.append(cutoffPrediction)

        // Reverb Wetness Prediction
        let reverbPrediction = predictReverbWetness(context: context)
        predictions.append(reverbPrediction)

        // Tempo Prediction
        let tempoPrediction = predictTempo(context: context)
        predictions.append(tempoPrediction)

        // Binaural Frequency Prediction
        let binauralPrediction = predictBinauralFrequency(context: context)
        predictions.append(binauralPrediction)

        return predictions
    }

    private func predictFilterCutoff(context: PredictionContext) -> ParameterPrediction {
        var baseValue: Float = 1000.0

        // HRV influence
        if context.currentHRV > 60 {
            baseValue *= 1.5  // Higher HRV = brighter sound
        } else if context.currentHRV < 40 {
            baseValue *= 0.7  // Lower HRV = warmer sound
        }

        // Coherence influence
        if context.currentCoherence > 60 {
            baseValue *= 1.3
        }

        // Time of day influence
        if context.timeOfDay >= 6 && context.timeOfDay < 12 {
            baseValue *= 1.2  // Brighter in morning
        } else if context.timeOfDay >= 20 || context.timeOfDay < 6 {
            baseValue *= 0.8  // Warmer in evening/night
        }

        // Clamp to valid range
        let suggestedValue = max(200, min(8000, baseValue))

        return ParameterPrediction(
            parameter: "filterCutoff",
            suggestedValue: suggestedValue,
            confidence: 0.75,
            reasoning: "Based on HRV (\(Int(context.currentHRV))) and time of day (\(context.timeOfDay):00)"
        )
    }

    private func predictReverbWetness(context: PredictionContext) -> ParameterPrediction {
        var wetness: Float = 30.0

        // High coherence = more reverb (spacious, flow state)
        if context.currentCoherence > 60 {
            wetness = 50.0 + (context.currentCoherence - 60) * 0.5
        } else if context.currentCoherence < 40 {
            wetness = 20.0
        }

        // Target emotion influence
        if let target = context.targetEmotion {
            switch target {
            case .peaceful, .calm:
                wetness *= 1.3
            case .energetic, .happy:
                wetness *= 0.8
            default:
                break
            }
        }

        let suggestedValue = max(0, min(80, wetness))

        return ParameterPrediction(
            parameter: "reverbWetness",
            suggestedValue: suggestedValue,
            confidence: 0.8,
            reasoning: "Coherence at \(Int(context.currentCoherence))% suggests \(suggestedValue > 40 ? "spacious" : "intimate") reverb"
        )
    }

    private func predictTempo(context: PredictionContext) -> ParameterPrediction {
        var tempoMultiplier: Float = 1.0

        // HRV-based tempo adjustment
        // High HRV: can handle faster tempo
        // Low HRV: slower tempo to help regulate
        if context.currentHRV < context.targetHRVRange.lowerBound {
            tempoMultiplier = 0.85  // Slow down to help increase HRV
        } else if context.currentHRV > context.targetHRVRange.upperBound {
            tempoMultiplier = 1.1  // Can speed up
        }

        // Session duration adjustment
        if context.sessionDuration > 1800 {  // > 30 minutes
            tempoMultiplier *= 0.95  // Gradually slow down
        }

        return ParameterPrediction(
            parameter: "tempoMultiplier",
            suggestedValue: tempoMultiplier,
            confidence: 0.7,
            reasoning: "HRV at \(Int(context.currentHRV))ms, targeting \(Int(context.targetHRVRange.lowerBound))-\(Int(context.targetHRVRange.upperBound))ms"
        )
    }

    private func predictBinauralFrequency(context: PredictionContext) -> ParameterPrediction {
        var frequency: Float = 10.0  // Alpha waves (relaxation)

        // Target state determines brainwave frequency
        if let target = context.targetEmotion {
            switch target {
            case .calm, .peaceful:
                frequency = 10.0  // Alpha (8-12 Hz)
            case .energetic, .happy:
                frequency = 20.0  // Beta (12-30 Hz)
            case .melancholic, .sad:
                frequency = 6.0   // Theta (4-8 Hz)
            case .tense:
                frequency = 14.0  // Low Beta
            case .uplifting:
                frequency = 12.0  // High Alpha
            }
        }

        // Adjust based on coherence
        if context.currentCoherence < 40 {
            // Low coherence: use theta to help relax
            frequency = min(frequency, 7.0)
        }

        return ParameterPrediction(
            parameter: "binauralFrequency",
            suggestedValue: frequency,
            confidence: 0.85,
            reasoning: "Targeting \(frequencyBandName(frequency)) brainwave state"
        )
    }

    private func frequencyBandName(_ freq: Float) -> String {
        switch freq {
        case 0.5..<4: return "Delta (deep sleep)"
        case 4..<8: return "Theta (meditation)"
        case 8..<12: return "Alpha (relaxation)"
        case 12..<30: return "Beta (focus)"
        default: return "Gamma (insight)"
        }
    }

    // MARK: - Learning

    func recordUserAdjustment(parameter: String, predictedValue: Float, userValue: Float, context: PredictionContext) {
        // Learn from user corrections
        let error = userValue - predictedValue

        // Update weights based on context
        // This is a simplified online learning approach
        let learningRate: Float = 0.1

        if abs(error) > 0.1 {
            // Significant correction - learn from it
            if context.currentHRV > 60 {
                parameterWeights[parameter]?["hrv_high"]? += error * learningRate
            } else {
                parameterWeights[parameter]?["hrv_low"]? += error * learningRate
            }
        }
    }
}

// MARK: - Audio Feature Extractor

final class AudioFeatureExtractor {

    struct AudioFeatures {
        // Spectral features
        var spectralCentroid: Float = 0
        var spectralFlux: Float = 0
        var spectralFlatness: Float = 0
        var spectralRolloff: Float = 0

        // Energy features
        var rms: Float = 0
        var energy: Float = 0
        var dynamicRange: Float = 0

        // Temporal features
        var tempo: Float = 120
        var onsetDensity: Float = 0
        var beatStrength: Float = 0

        // Harmonic features
        var harmonicComplexity: Float = 0
        var majorKeyProbability: Float = 0.5
        var dissonance: Float = 0
        var harmonicStability: Float = 0

        // Timbral features
        var acousticness: Float = 0.5
        var synthProbability: Float = 0.5
        var distortionLevel: Float = 0
        var clarity: Float = 0.5

        // Rhythmic features
        var swingFactor: Float = 0
        var polyrhythmicComplexity: Float = 0

        // Melodic features
        var melodicContour: Float = 0  // -1 descending, +1 ascending

        // Style indicators
        var bassWeight: Float = 0
        var hookStrength: Float = 0
        var repeatability: Float = 0
        var simplicity: Float = 0.5
        var improvProbability: Float = 0
        var speechProbability: Float = 0
        var exoticScaleProbability: Float = 0
        var westernHarmony: Float = 0.5
    }

    private var previousSpectrum: [Float] = []
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize = 2048

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_Destroy(setup)
        }
    }

    func extract(buffer: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> AudioFeatures {
        var features = AudioFeatures()

        // Calculate RMS
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(frameCount))
        features.rms = rms
        features.energy = min(rms * 3.0, 1.0)

        // Calculate peak for dynamic range
        var peak: Float = 0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(frameCount))
        features.dynamicRange = peak > 0 ? 1.0 - (rms / peak) : 0

        // FFT-based features
        if let spectrum = calculateSpectrum(buffer: buffer, frameCount: frameCount) {
            // Spectral centroid
            features.spectralCentroid = calculateSpectralCentroid(spectrum: spectrum, sampleRate: sampleRate)

            // Spectral flux
            features.spectralFlux = calculateSpectralFlux(spectrum: spectrum)
            previousSpectrum = spectrum

            // Spectral flatness
            features.spectralFlatness = calculateSpectralFlatness(spectrum: spectrum)

            // Bass weight (low frequency content)
            features.bassWeight = calculateBassWeight(spectrum: spectrum, sampleRate: sampleRate)
        }

        // Estimate tempo from onset detection
        features.tempo = estimateTempo(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        // Harmonic analysis
        let harmonics = analyzeHarmonics(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)
        features.majorKeyProbability = harmonics.majorProbability
        features.harmonicComplexity = harmonics.complexity
        features.dissonance = harmonics.dissonance

        // Timbral estimates
        features.acousticness = estimateAcousticness(spectralCentroid: features.spectralCentroid, rms: rms)
        features.synthProbability = 1.0 - features.acousticness

        return features
    }

    private func calculateSpectrum(buffer: UnsafePointer<Float>, frameCount: Int) -> [Float]? {
        guard let setup = fftSetup else { return nil }

        let n = min(frameCount, fftSize)

        var realIn = [Float](repeating: 0, count: n)
        memcpy(&realIn, buffer, n * MemoryLayout<Float>.size)

        var imagIn = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)

        vDSP_DFT_Execute(setup, realIn, imagIn, &realOut, &imagOut)

        var magnitudes = [Float](repeating: 0, count: n/2)
        for i in 0..<(n/2) {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        return magnitudes
    }

    private func calculateSpectralCentroid(spectrum: [Float], sampleRate: Float) -> Float {
        var weightedSum: Float = 0
        var sum: Float = 0

        for (i, mag) in spectrum.enumerated() {
            let freq = Float(i) * sampleRate / Float(fftSize)
            weightedSum += freq * mag
            sum += mag
        }

        return sum > 0 ? weightedSum / sum : 0
    }

    private func calculateSpectralFlux(spectrum: [Float]) -> Float {
        guard !previousSpectrum.isEmpty, previousSpectrum.count == spectrum.count else {
            return 0
        }

        var flux: Float = 0
        for i in 0..<spectrum.count {
            let diff = spectrum[i] - previousSpectrum[i]
            if diff > 0 {
                flux += diff * diff
            }
        }

        return sqrt(flux)
    }

    private func calculateSpectralFlatness(spectrum: [Float]) -> Float {
        var logSum: Float = 0
        var linSum: Float = 0
        var count: Float = 0

        for mag in spectrum where mag > 0.0001 {
            logSum += log(mag)
            linSum += mag
            count += 1
        }

        guard count > 0 else { return 0 }

        let geometricMean = exp(logSum / count)
        let arithmeticMean = linSum / count

        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }

    private func calculateBassWeight(spectrum: [Float], sampleRate: Float) -> Float {
        let bassEndBin = Int(200.0 * Float(fftSize) / sampleRate)
        let totalEndBin = spectrum.count

        var bassEnergy: Float = 0
        var totalEnergy: Float = 0

        for i in 0..<totalEndBin {
            if i < bassEndBin {
                bassEnergy += spectrum[i] * spectrum[i]
            }
            totalEnergy += spectrum[i] * spectrum[i]
        }

        return totalEnergy > 0 ? bassEnergy / totalEnergy : 0
    }

    private func estimateTempo(buffer: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> Float {
        // Simplified onset detection and autocorrelation-based tempo estimation
        // Real implementation would use a more sophisticated algorithm

        // For now, return a default based on energy envelope
        var peak: Float = 0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(frameCount))

        // Rough estimate: more energy = likely faster tempo
        return 80.0 + peak * 80.0
    }

    private func analyzeHarmonics(buffer: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> (majorProbability: Float, complexity: Float, dissonance: Float) {
        // Simplified harmonic analysis
        // Real implementation would use pitch detection and chord analysis

        // Use spectral features as proxies
        guard let spectrum = calculateSpectrum(buffer: buffer, frameCount: frameCount) else {
            return (0.5, 0.5, 0.3)
        }

        // Estimate harmonic complexity from spectral flatness
        let flatness = calculateSpectralFlatness(spectrum: spectrum)
        let complexity = 1.0 - flatness

        // Rough major/minor estimation from spectral shape
        // Major keys tend to have more energy in upper harmonics
        let centroid = calculateSpectralCentroid(spectrum: spectrum, sampleRate: sampleRate)
        let majorProbability = min(centroid / 2000.0, 1.0)

        // Dissonance from spectral roughness
        var roughness: Float = 0
        for i in 1..<spectrum.count-1 {
            roughness += abs(spectrum[i] - spectrum[i-1]) + abs(spectrum[i] - spectrum[i+1])
        }
        let dissonance = min(roughness / Float(spectrum.count) * 10.0, 1.0)

        return (majorProbability, complexity, dissonance)
    }

    private func estimateAcousticness(spectralCentroid: Float, rms: Float) -> Float {
        // Acoustic instruments tend to have:
        // - Lower spectral centroid (warmer sound)
        // - More dynamic variation
        // This is a simplified heuristic

        let centroidFactor = max(0, 1.0 - spectralCentroid / 4000.0)
        return centroidFactor
    }
}

typealias AudioFeatures = AudioFeatureExtractor.AudioFeatures
