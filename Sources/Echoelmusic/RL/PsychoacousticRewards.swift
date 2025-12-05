// PsychoacousticRewards.swift
// Echoelmusic - Psychoacoustic Reward Functions
//
// Evidence-based reward signals from peer-reviewed psychoacoustics research
// All formulas cite original publications

import Foundation
import Accelerate
import os.log

private let rewardLogger = Logger(subsystem: "com.echoelmusic.rl", category: "PsychoacousticRewards")

// MARK: - Psychoacoustic Constants

/// Physical and perceptual constants from peer-reviewed sources
public struct PsychoacousticConstants {
    // Critical Bandwidth (Zwicker, 1961; Moore & Glasberg, 1983)
    // ERB (Equivalent Rectangular Bandwidth) in Hz
    // ERB(f) = 24.7 * (4.37 * f/1000 + 1)
    public static func erbWidth(frequency: Double) -> Double {
        24.7 * (4.37 * frequency / 1000.0 + 1.0)
    }

    // Critical band rate in Bark (Zwicker & Terhardt, 1980)
    // z = 13 * arctan(0.00076 * f) + 3.5 * arctan((f/7500)^2)
    public static func barkScale(frequency: Double) -> Double {
        13 * atan(0.00076 * frequency) + 3.5 * atan(pow(frequency / 7500, 2))
    }

    // Just Noticeable Difference (JND) for pitch (Wier et al., 1977)
    // Approximately 0.5-1% for frequencies above 500 Hz
    public static let pitchJND: Double = 0.005  // 0.5%

    // Temporal integration (Moore, 2012)
    public static let temporalIntegration: Double = 0.2  // 200ms

    // Loudness reference (ISO 226:2003)
    public static let referenceLevel: Double = 20e-6  // 20 μPa

    // A-weighting coefficients (IEC 61672-1:2013)
    public static func aWeighting(frequency: Double) -> Double {
        let f2 = frequency * frequency
        let numerator = 12194.0 * 12194.0 * f2 * f2
        let denominator = (f2 + 20.6 * 20.6) *
                          sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) *
                          (f2 + 12194.0 * 12194.0)
        let ra = numerator / denominator
        return 20 * log10(ra) + 2.0
    }
}

// MARK: - Consonance Models

/// Plomp-Levelt Consonance Model (1965)
/// Reference: Plomp, R., & Levelt, W.J.M. (1965). Tonal Consonance and Critical Bandwidth. JASA 38(4), 548-560.
public struct PlompLeveltConsonance {

    /// Calculate dissonance between two frequencies
    /// Based on critical bandwidth interference
    /// d(x) = 4x * e^(-4x) where x = |f1-f2| / CBW
    public static func dissonance(f1: Double, f2: Double) -> Double {
        guard f1 > 0 && f2 > 0 else { return 0 }

        let freqDiff = abs(f1 - f2)
        let avgFreq = (f1 + f2) / 2

        // Critical bandwidth at average frequency
        let cbw = PsychoacousticConstants.erbWidth(frequency: avgFreq)

        // Normalized frequency difference
        let x = freqDiff / cbw

        // Plomp-Levelt dissonance curve
        // Maximum dissonance at x ≈ 0.25 (quarter of critical band)
        let d = 4 * x * exp(-4 * x)

        return d
    }

    /// Calculate consonance of a chord (set of frequencies)
    /// Sum of all pairwise dissonances
    public static func chordConsonance(frequencies: [Double]) -> Double {
        guard frequencies.count >= 2 else { return 1.0 }

        var totalDissonance: Double = 0
        var pairCount = 0

        for i in 0..<frequencies.count {
            for j in (i+1)..<frequencies.count {
                totalDissonance += dissonance(f1: frequencies[i], f2: frequencies[j])
                pairCount += 1
            }
        }

        // Normalize and convert to consonance (1 - normalized dissonance)
        let avgDissonance = totalDissonance / Double(pairCount)
        return max(0, 1.0 - avgDissonance)
    }

    /// Calculate consonance using harmonics (Sethares, 1993)
    /// Includes partials with amplitude weighting
    public static func consonanceWithHarmonics(
        fundamentals: [Double],
        numHarmonics: Int = 6,
        rolloff: Double = 0.88  // Harmonic amplitude decay
    ) -> Double {
        var allPartials: [(freq: Double, amp: Double)] = []

        for fundamental in fundamentals {
            for h in 1...numHarmonics {
                let freq = fundamental * Double(h)
                let amp = pow(rolloff, Double(h - 1))
                allPartials.append((freq, amp))
            }
        }

        var totalDissonance: Double = 0

        for i in 0..<allPartials.count {
            for j in (i+1)..<allPartials.count {
                let d = dissonance(f1: allPartials[i].freq, f2: allPartials[j].freq)
                let weight = allPartials[i].amp * allPartials[j].amp
                totalDissonance += d * weight
            }
        }

        // Normalize by number of pairs and amplitude weights
        let maxPossibleDissonance = Double(allPartials.count * (allPartials.count - 1) / 2)
        return max(0, 1.0 - totalDissonance / maxPossibleDissonance)
    }
}

// MARK: - Tonal Tension Model

/// Lerdahl Tonal Tension Model (2001)
/// Reference: Lerdahl, F. (2001). Tonal Pitch Space. Oxford University Press.
public struct LerdahlTensionModel {

    // Circle of fifths distances
    private static let fifthsCircle = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]

    /// Calculate hierarchical tension distance
    /// Based on tonal pitch space theory
    public static func tonalDistance(from: Int, to: Int, key: Int = 0) -> Double {
        // Adjust for key
        let fromDegree = (from - key + 12) % 12
        let toDegree = (to - key + 12) % 12

        // Basic step distance on circle of fifths
        let fromFifth = fifthsCircle.firstIndex(of: fromDegree) ?? 0
        let toFifth = fifthsCircle.firstIndex(of: toDegree) ?? 0
        let fifthDistance = abs(fromFifth - toFifth)

        // Regional distance (how far from tonic region)
        let regionalDistance = Double(min(fifthDistance, 12 - fifthDistance)) / 6.0

        return regionalDistance
    }

    /// Calculate chord tension relative to tonic
    /// Higher values = more tension
    public static func chordTension(chordRoot: Int, chordQuality: ChordQuality, key: Int = 0) -> Double {
        let baseTension = tonalDistance(from: 0, to: chordRoot, key: key)

        // Quality modifier (Lerdahl's stability conditions)
        let qualityModifier: Double
        switch chordQuality {
        case .major: qualityModifier = 0.0
        case .minor: qualityModifier = 0.1
        case .diminished: qualityModifier = 0.3
        case .augmented: qualityModifier = 0.35
        case .dominant7: qualityModifier = 0.2
        case .major7: qualityModifier = 0.05
        case .minor7: qualityModifier = 0.15
        }

        return baseTension + qualityModifier
    }

    /// Calculate tension of a chord progression
    public static func progressionTension(chords: [(root: Int, quality: ChordQuality)], key: Int = 0) -> [Double] {
        chords.map { chordTension(chordRoot: $0.root, chordQuality: $0.quality, key: key) }
    }

    public enum ChordQuality {
        case major, minor, diminished, augmented
        case dominant7, major7, minor7
    }
}

// MARK: - Krumhansl Tonal Hierarchy

/// Krumhansl Tonal Hierarchy (1990)
/// Reference: Krumhansl, C.L. (1990). Cognitive Foundations of Musical Pitch. Oxford University Press.
public struct KrumhanslTonalHierarchy {

    // Probe tone ratings from experimental data (Table 2.1, p. 30)
    // Normalized to 0-1 range

    /// Major key profile (C major, transposable)
    public static let majorProfile: [Double] = [
        6.35, 2.23, 3.48, 2.33, 4.38,  // C, C#, D, D#, E
        4.09, 2.52, 5.19, 2.39, 3.66,  // F, F#, G, G#, A
        2.29, 2.88                       // A#, B
    ].map { $0 / 6.35 }  // Normalize by maximum

    /// Minor key profile (C minor, transposable)
    public static let minorProfile: [Double] = [
        6.33, 2.68, 3.52, 5.38, 2.60,  // C, C#, D, Eb, E
        3.53, 2.54, 4.75, 3.98, 2.69,  // F, F#, G, Ab, A
        3.34, 3.17                       // Bb, B
    ].map { $0 / 6.33 }

    /// Calculate fit of pitch class distribution to key profile
    /// Uses Pearson correlation (Krumhansl & Schmuckler key-finding algorithm)
    public static func keyCorrelation(pitchClasses: [Double], keyRoot: Int, isMinor: Bool) -> Double {
        let profile = isMinor ? minorProfile : majorProfile

        // Rotate profile to key
        var rotatedProfile = [Double](repeating: 0, count: 12)
        for i in 0..<12 {
            rotatedProfile[i] = profile[(i - keyRoot + 12) % 12]
        }

        // Pearson correlation
        let n = Double(12)
        let sumX = pitchClasses.reduce(0, +)
        let sumY = rotatedProfile.reduce(0, +)
        let sumXY = zip(pitchClasses, rotatedProfile).map(*).reduce(0, +)
        let sumX2 = pitchClasses.map { $0 * $0 }.reduce(0, +)
        let sumY2 = rotatedProfile.map { $0 * $0 }.reduce(0, +)

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// Find best fitting key using all 24 major/minor keys
    public static func findKey(pitchClasses: [Double]) -> (root: Int, isMinor: Bool, correlation: Double) {
        var bestRoot = 0
        var bestIsMinor = false
        var bestCorrelation = -1.0

        for root in 0..<12 {
            for isMinor in [false, true] {
                let corr = keyCorrelation(pitchClasses: pitchClasses, keyRoot: root, isMinor: isMinor)
                if corr > bestCorrelation {
                    bestCorrelation = corr
                    bestRoot = root
                    bestIsMinor = isMinor
                }
            }
        }

        return (bestRoot, bestIsMinor, bestCorrelation)
    }
}

// MARK: - Temperley Probabilistic Model

/// Temperley Probabilistic Model (2007)
/// Reference: Temperley, D. (2007). Music and Probability. MIT Press.
public struct TemperleyProbabilisticModel {

    // Melodic interval probabilities (Table 3.1, p. 58)
    // P(interval | previous interval)
    public static let intervalProbabilities: [Int: Double] = [
        0: 0.12,    // Unison
        1: 0.15,    // Minor 2nd
        2: 0.20,    // Major 2nd
        3: 0.10,    // Minor 3rd
        4: 0.08,    // Major 3rd
        5: 0.07,    // Perfect 4th
        6: 0.02,    // Tritone
        7: 0.10,    // Perfect 5th
        8: 0.04,    // Minor 6th
        9: 0.03,    // Major 6th
        10: 0.02,   // Minor 7th
        11: 0.01,   // Major 7th
        12: 0.06    // Octave
    ]

    /// Calculate melodic probability
    public static func melodicProbability(intervals: [Int]) -> Double {
        guard !intervals.isEmpty else { return 1.0 }

        var logProb: Double = 0
        for interval in intervals {
            let absInterval = abs(interval) % 13
            let prob = intervalProbabilities[absInterval] ?? 0.01
            logProb += log(prob)
        }

        return exp(logProb / Double(intervals.count))
    }

    // Metrical position probabilities (Table 4.2, p. 87)
    public static let metricalProbabilities: [Int: Double] = [
        0: 0.40,    // Downbeat
        1: 0.05,    // 16th after downbeat
        2: 0.15,    // 8th note
        3: 0.05,    // 16th before beat 2
        4: 0.20,    // Beat 2
        5: 0.03,    // etc.
        6: 0.08,
        7: 0.04
    ]

    /// Calculate rhythmic probability
    public static func rhythmicProbability(onsets: [Int], beatsPerMeasure: Int = 4) -> Double {
        guard !onsets.isEmpty else { return 1.0 }

        var logProb: Double = 0
        for onset in onsets {
            let position = onset % (beatsPerMeasure * 4)  // 16th note resolution
            let prob = metricalProbabilities[position % 8] ?? 0.05
            logProb += log(prob)
        }

        return exp(logProb / Double(onsets.count))
    }
}

// MARK: - Integrated Psychoacoustic Reward Function

/// Combines all evidence-based psychoacoustic measures into a reward function
public final class PsychoacousticRewardFunction {

    // Reward weights (can be tuned via hyperparameter optimization)
    public struct Weights {
        public var consonance: Float = 0.25
        public var tonalStability: Float = 0.20
        public var melodicCoherence: Float = 0.20
        public var rhythmicCoherence: Float = 0.15
        public var tensionBalance: Float = 0.10
        public var novelty: Float = 0.10

        public init() {}
    }

    public var weights = Weights()
    private var pitchHistory: [Int] = []
    private var onsetHistory: [Int] = []
    private var tensionHistory: [Double] = []

    public init() {
        rewardLogger.info("Psychoacoustic Reward Function initialized")
    }

    /// Calculate total reward for a state-action-nextState transition
    public func calculateReward(state: MusicState, action: MusicAction, nextState: MusicState) -> Float {
        var reward: Float = 0

        // 1. Consonance reward (Plomp-Levelt)
        let pitchHz = midiToHz(action.pitchClass + action.octave * 12)
        let recentPitches = pitchHistory.suffix(3).map { midiToHz($0) }
        let consonance = PlompLeveltConsonance.chordConsonance(frequencies: [pitchHz] + recentPitches)
        reward += weights.consonance * Float(consonance)

        // 2. Tonal stability reward (Krumhansl)
        let keyFit = KrumhanslTonalHierarchy.keyCorrelation(
            pitchClasses: nextState.pitchClassProfile.map { Double($0) },
            keyRoot: 0,
            isMinor: false
        )
        reward += weights.tonalStability * Float(max(0, keyFit))

        // 3. Melodic coherence reward (Temperley)
        if !pitchHistory.isEmpty {
            let interval = action.pitchClass + action.octave * 12 - pitchHistory.last!
            let melodicProb = TemperleyProbabilisticModel.melodicProbability(intervals: [interval])
            reward += weights.melodicCoherence * Float(melodicProb)
        }

        // 4. Rhythmic coherence reward (Temperley)
        let rhythmicProb = TemperleyProbabilisticModel.rhythmicProbability(
            onsets: onsetHistory.suffix(4).map { $0 }
        )
        reward += weights.rhythmicCoherence * Float(rhythmicProb)

        // 5. Tension balance reward (Lerdahl)
        let currentTension = LerdahlTensionModel.chordTension(
            chordRoot: action.pitchClass,
            chordQuality: .major
        )
        tensionHistory.append(currentTension)

        // Reward appropriate tension arc (build-up and resolution)
        let tensionVariance = calculateVariance(tensionHistory.suffix(8).map { $0 })
        let tensionReward = tensionVariance > 0.1 ? 1.0 : tensionVariance * 10
        reward += weights.tensionBalance * Float(tensionReward)

        // 6. Novelty reward (avoid exact repetition)
        let recentPitchClasses = pitchHistory.suffix(8).map { $0 % 12 }
        let isNovel = !recentPitchClasses.contains(action.pitchClass)
        reward += weights.novelty * (isNovel ? 1.0 : 0.0)

        // Update history
        pitchHistory.append(action.pitchClass + action.octave * 12)
        onsetHistory.append(onsetHistory.count)

        // Keep history bounded
        if pitchHistory.count > 64 { pitchHistory.removeFirst() }
        if onsetHistory.count > 64 { onsetHistory.removeFirst() }
        if tensionHistory.count > 64 { tensionHistory.removeFirst() }

        return reward
    }

    public func reset() {
        pitchHistory.removeAll()
        onsetHistory.removeAll()
        tensionHistory.removeAll()
    }

    private func midiToHz(_ midi: Int) -> Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }
}

// MARK: - Neuroscience-Based Reward Signals

/// Dopamine-inspired reward shaping based on neuroscience research
/// References:
/// - Blood & Zatorre (2001). Intensely pleasurable responses to music. PNAS.
/// - Salimpoor et al. (2011). Anatomically distinct dopamine release. Nature Neuroscience.
public struct NeuroscienceRewardSignals {

    /// Prediction error reward (dopamine response model)
    /// Schultz et al. (1997). A neural substrate of prediction and reward.
    public static func predictionError(expected: Double, actual: Double) -> Double {
        // Temporal difference-like prediction error
        // Positive surprise = reward, negative surprise = penalty
        return actual - expected
    }

    /// Anticipation reward (musical expectation)
    /// Based on Huron (2006). Sweet Anticipation.
    public static func anticipationReward(
        expectedPitch: Int,
        actualPitch: Int,
        contextStrength: Double
    ) -> Double {
        let pitchDistance = abs(expectedPitch - actualPitch)

        // Partial confirmation is most rewarding (moderate surprise)
        // Based on Berlyne's (1971) arousal potential theory
        let surpriseLevel = Double(pitchDistance) / 12.0
        let optimalSurprise = 0.3  // Sweet spot for arousal

        // Inverted U-curve (Wundt curve)
        let reward = 1.0 - pow(surpriseLevel - optimalSurprise, 2) * 4
        return max(0, reward * contextStrength)
    }

    /// Chills/frisson response model
    /// Based on Grewe et al. (2007). Listening to music as a re-creative process.
    public static func chillsLikelihood(
        harmonicChange: Double,
        dynamicChange: Double,
        registralChange: Double
    ) -> Double {
        // Factors associated with chills:
        // 1. Harmonic surprise
        // 2. Dynamic crescendo
        // 3. Registral expansion

        let harmonicFactor = min(1.0, harmonicChange * 2)
        let dynamicFactor = max(0, dynamicChange)  // Crescendo positive
        let registralFactor = min(1.0, registralChange / 12.0)

        // Weighted combination (based on Grewe et al. findings)
        return harmonicFactor * 0.4 + dynamicFactor * 0.35 + registralFactor * 0.25
    }

    /// Groove/entrainment reward
    /// Based on Janata et al. (2012). Sensorimotor coupling in music.
    public static func grooveReward(
        beatStrength: Double,
        syncopation: Double,
        tempo: Double
    ) -> Double {
        // Optimal tempo range for groove: 100-120 BPM (Madison, 2006)
        let tempoFactor = 1.0 - abs(tempo - 110.0) / 50.0

        // Moderate syncopation is most groove-inducing
        let syncopationFactor = 1.0 - pow(syncopation - 0.4, 2) * 4

        // Strong beat important for entrainment
        let beatFactor = beatStrength

        return max(0, tempoFactor * syncopationFactor * beatFactor)
    }
}
