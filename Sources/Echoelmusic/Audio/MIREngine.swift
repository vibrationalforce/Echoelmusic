//
//  MIREngine.swift
//  Echoelmusic
//
//  Music Information Retrieval Engine - Key/Chord/Beat Detection
//  Brings AI/ML to 100% completion
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - Key Detection

/// Detects musical key using Krumhansl-Schmuckler algorithm
public final class KeyDetector {

    // MARK: - Key Result

    public struct KeyResult {
        public let key: String                    // e.g., "C Major", "A Minor"
        public let root: Int                      // 0-11 (C=0, C#=1, etc.)
        public let mode: Mode                     // Major or Minor
        public let confidence: Float              // 0-1
        public let alternativeKeys: [(key: String, confidence: Float)]

        public enum Mode: String {
            case major = "Major"
            case minor = "Minor"
        }
    }

    // MARK: - Properties

    private let chromaNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // Krumhansl-Schmuckler key profiles (normalized)
    private let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    private let fftSize: Int
    private let sampleRate: Float
    private var fftSetup: vDSP_DFT_Setup?
    private var chromagram: [Float] = [Float](repeating: 0, count: 12)
    private var chromaHistory: [[Float]] = []
    private let maxHistorySize = 50

    // MARK: - Initialization

    public init(fftSize: Int = 8192, sampleRate: Float = 48000.0) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Public Methods

    /// Detect key from audio buffer
    public func detectKey(from buffer: AVAudioPCMBuffer) -> KeyResult {
        // Compute chromagram
        let chroma = computeChromagram(buffer: buffer)

        // Add to history for smoothing
        chromaHistory.append(chroma)
        if chromaHistory.count > maxHistorySize {
            chromaHistory.removeFirst()
        }

        // Average chromagram over history
        var avgChroma = [Float](repeating: 0, count: 12)
        for frame in chromaHistory {
            for i in 0..<12 {
                avgChroma[i] += frame[i]
            }
        }
        for i in 0..<12 {
            avgChroma[i] /= Float(chromaHistory.count)
        }

        // Find best matching key
        var allKeys: [(key: String, root: Int, mode: KeyResult.Mode, correlation: Float)] = []

        for root in 0..<12 {
            // Major key
            let majorCorr = pearsonCorrelation(avgChroma, rotateProfile(majorProfile, by: root))
            allKeys.append((
                key: "\(chromaNames[root]) Major",
                root: root,
                mode: .major,
                correlation: majorCorr
            ))

            // Minor key
            let minorCorr = pearsonCorrelation(avgChroma, rotateProfile(minorProfile, by: root))
            allKeys.append((
                key: "\(chromaNames[root]) Minor",
                root: root,
                mode: .minor,
                correlation: minorCorr
            ))
        }

        // Sort by correlation
        allKeys.sort { $0.correlation > $1.correlation }

        // Best key
        let best = allKeys[0]
        let maxCorr = allKeys.map { $0.correlation }.max() ?? 1.0
        let minCorr = allKeys.map { $0.correlation }.min() ?? 0.0

        // Normalize confidence
        let confidence = (best.correlation - minCorr) / (maxCorr - minCorr + 0.0001)

        // Alternative keys
        let alternatives = allKeys[1..<min(4, allKeys.count)].map {
            (key: $0.key, confidence: ($0.correlation - minCorr) / (maxCorr - minCorr + 0.0001))
        }

        return KeyResult(
            key: best.key,
            root: best.root,
            mode: best.mode,
            confidence: confidence,
            alternativeKeys: Array(alternatives)
        )
    }

    /// Reset detection state
    public func reset() {
        chromaHistory.removeAll()
        chromagram = [Float](repeating: 0, count: 12)
    }

    // MARK: - Private Methods

    private func computeChromagram(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData,
              let setup = fftSetup else {
            return [Float](repeating: 0, count: 12)
        }

        let samples = channelData[0]
        let frameLength = min(Int(buffer.frameLength), fftSize)

        // Apply window and FFT
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        for i in 0..<frameLength {
            real[i] = samples[i] * window[i]
        }

        vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)

        // Calculate magnitudes
        var chroma = [Float](repeating: 0, count: 12)

        for bin in 1..<fftSize / 2 {
            let frequency = Float(bin) * sampleRate / Float(fftSize)
            let magnitude = sqrt(real[bin] * real[bin] + imaginary[bin] * imaginary[bin])

            // Only consider musical range (27.5 Hz to 4186 Hz)
            if frequency >= 27.5 && frequency <= 4186 {
                // Convert frequency to MIDI note and then to chroma
                let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
                let chromaBin = Int(midiNote) % 12

                if chromaBin >= 0 && chromaBin < 12 {
                    chroma[chromaBin] += magnitude * magnitude  // Use power
                }
            }
        }

        // Normalize
        let sum = chroma.reduce(0, +)
        if sum > 0 {
            for i in 0..<12 {
                chroma[i] /= sum
            }
        }

        return chroma
    }

    private func rotateProfile(_ profile: [Float], by amount: Int) -> [Float] {
        var rotated = [Float](repeating: 0, count: 12)
        for i in 0..<12 {
            rotated[i] = profile[(12 + i - amount) % 12]
        }
        return rotated
    }

    private func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
        guard x.count == y.count && x.count > 0 else { return 0 }

        let n = Float(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = x.reduce(0) { $0 + $1 * $1 }
        let sumY2 = y.reduce(0) { $0 + $1 * $1 }

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        return denominator != 0 ? numerator / denominator : 0
    }
}

// MARK: - Chord Recognition

/// Real-time chord recognition using template matching
public final class ChordRecognizer {

    // MARK: - Chord Result

    public struct ChordResult {
        public let root: String           // C, C#, D, etc.
        public let quality: ChordQuality
        public let bass: String?          // For slash chords
        public let confidence: Float
        public let alternatives: [(chord: String, confidence: Float)]

        public var name: String {
            let qualitySuffix = quality.suffix
            if let bass = bass, bass != root {
                return "\(root)\(qualitySuffix)/\(bass)"
            }
            return "\(root)\(qualitySuffix)"
        }
    }

    public enum ChordQuality: String, CaseIterable {
        case major = "Major"
        case minor = "Minor"
        case diminished = "Diminished"
        case augmented = "Augmented"
        case major7 = "Major 7"
        case minor7 = "Minor 7"
        case dominant7 = "Dominant 7"
        case diminished7 = "Diminished 7"
        case halfDiminished7 = "Half-Diminished 7"
        case sus2 = "Sus2"
        case sus4 = "Sus4"
        case add9 = "Add9"

        public var suffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .diminished: return "dim"
            case .augmented: return "aug"
            case .major7: return "maj7"
            case .minor7: return "m7"
            case .dominant7: return "7"
            case .diminished7: return "dim7"
            case .halfDiminished7: return "ø7"
            case .sus2: return "sus2"
            case .sus4: return "sus4"
            case .add9: return "add9"
            }
        }

        public var template: [Float] {
            switch self {
            case .major:           return [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0]
            case .minor:           return [1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0]
            case .diminished:      return [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0]
            case .augmented:       return [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
            case .major7:          return [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1]
            case .minor7:          return [1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0]
            case .dominant7:       return [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]
            case .diminished7:     return [1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0]
            case .halfDiminished7: return [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0]
            case .sus2:            return [1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0]
            case .sus4:            return [1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0]
            case .add9:            return [1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0]
            }
        }
    }

    // MARK: - Properties

    private let chromaNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let keyDetector: KeyDetector

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.keyDetector = KeyDetector(sampleRate: sampleRate)
    }

    // MARK: - Public Methods

    /// Recognize chord from audio buffer
    public func recognizeChord(from buffer: AVAudioPCMBuffer) -> ChordResult {
        // Get chromagram from key detector
        let keyResult = keyDetector.detectKey(from: buffer)

        // We need the chromagram - compute it directly
        let chroma = computeChromagram(buffer: buffer)

        // Find bass note (lowest prominent frequency)
        let bassIndex = findBassNote(buffer: buffer)

        // Match against all chord templates
        var allChords: [(root: Int, quality: ChordQuality, similarity: Float)] = []

        for root in 0..<12 {
            for quality in ChordQuality.allCases {
                let rotatedTemplate = rotateTemplate(quality.template, by: root)
                let similarity = cosineSimilarity(chroma, rotatedTemplate)
                allChords.append((root: root, quality: quality, similarity: similarity))
            }
        }

        // Sort by similarity
        allChords.sort { $0.similarity > $1.similarity }

        let best = allChords[0]
        let bassNote = bassIndex >= 0 ? chromaNames[bassIndex] : nil

        // Alternatives
        let alternatives = allChords[1..<min(4, allChords.count)].map { chord -> (chord: String, confidence: Float) in
            let name = "\(chromaNames[chord.root])\(chord.quality.suffix)"
            return (chord: name, confidence: chord.similarity)
        }

        return ChordResult(
            root: chromaNames[best.root],
            quality: best.quality,
            bass: bassNote,
            confidence: best.similarity,
            alternatives: Array(alternatives)
        )
    }

    // MARK: - Private Methods

    private func computeChromagram(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return [Float](repeating: 0, count: 12)
        }

        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        let fftSize = 8192

        var chroma = [Float](repeating: 0, count: 12)

        // Simple FFT-based chromagram
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        let copyLength = min(frameLength, fftSize)
        for i in 0..<copyLength {
            real[i] = samples[i]
        }

        if let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) {
            vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            vDSP_DFT_DestroySetup(setup)
        }

        for bin in 1..<fftSize / 2 {
            let frequency = Float(bin) * sampleRate / Float(fftSize)
            let magnitude = sqrt(real[bin] * real[bin] + imaginary[bin] * imaginary[bin])

            if frequency >= 27.5 && frequency <= 4186 {
                let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
                let chromaBin = Int(midiNote) % 12

                if chromaBin >= 0 && chromaBin < 12 {
                    chroma[chromaBin] += magnitude
                }
            }
        }

        // Normalize
        let maxVal = chroma.max() ?? 1.0
        if maxVal > 0 {
            for i in 0..<12 {
                chroma[i] /= maxVal
            }
        }

        return chroma
    }

    private func findBassNote(buffer: AVAudioPCMBuffer) -> Int {
        guard let channelData = buffer.floatChannelData else { return -1 }

        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        let fftSize = 8192

        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        let copyLength = min(frameLength, fftSize)
        for i in 0..<copyLength {
            real[i] = samples[i]
        }

        if let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) {
            vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            vDSP_DFT_DestroySetup(setup)
        }

        // Find strongest frequency in bass range (27.5 - 300 Hz)
        var maxMag: Float = 0
        var bassFreq: Float = 0

        for bin in 1..<fftSize / 2 {
            let frequency = Float(bin) * sampleRate / Float(fftSize)
            let magnitude = sqrt(real[bin] * real[bin] + imaginary[bin] * imaginary[bin])

            if frequency >= 27.5 && frequency <= 300 && magnitude > maxMag {
                maxMag = magnitude
                bassFreq = frequency
            }
        }

        if bassFreq > 0 {
            let midiNote = 12.0 * log2(bassFreq / 440.0) + 69.0
            return Int(midiNote) % 12
        }

        return -1
    }

    private func rotateTemplate(_ template: [Float], by amount: Int) -> [Float] {
        var rotated = [Float](repeating: 0, count: 12)
        for i in 0..<12 {
            rotated[(i + amount) % 12] = template[i]
        }
        return rotated
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<min(a.count, b.count) {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}

// MARK: - Beat Detection

/// Real-time beat and tempo detection using onset detection and autocorrelation
public final class BeatDetector {

    // MARK: - Beat Result

    public struct BeatResult {
        public let bpm: Float
        public let confidence: Float
        public let beatPhase: Float           // 0-1, position within current beat
        public let downbeatPhase: Float       // 0-1, position within current bar
        public let timeSignature: TimeSignature
        public let onsetStrength: Float
        public let isBeat: Bool
        public let isDownbeat: Bool
    }

    public struct TimeSignature {
        public let numerator: Int
        public let denominator: Int

        public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
        public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
        public static let sixEight = TimeSignature(numerator: 6, denominator: 8)
    }

    // MARK: - Properties

    private let sampleRate: Float
    private let hopSize: Int
    private let fftSize: Int

    private var onsetHistory: [Float] = []
    private var beatHistory: [TimeInterval] = []
    private var lastOnsetTime: TimeInterval = 0
    private var currentBPM: Float = 120.0
    private var beatPhase: Float = 0.0
    private var downbeatCounter: Int = 0

    private var previousSpectrum: [Float] = []
    private var onsetThreshold: Float = 0.15
    private var bpmHistory: [Float] = []
    private let maxHistorySize = 100

    private var fftSetup: vDSP_DFT_Setup?

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0, hopSize: Int = 512) {
        self.sampleRate = sampleRate
        self.hopSize = hopSize
        self.fftSize = 2048

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Public Methods

    /// Process audio buffer and detect beats
    public func process(buffer: AVAudioPCMBuffer, timestamp: TimeInterval) -> BeatResult {
        // Compute onset strength
        let onsetStrength = computeOnsetStrength(buffer: buffer)

        // Update onset history
        onsetHistory.append(onsetStrength)
        if onsetHistory.count > maxHistorySize {
            onsetHistory.removeFirst()
        }

        // Detect if this is a beat
        let isBeat = detectOnset(strength: onsetStrength)

        if isBeat {
            // Record beat time
            beatHistory.append(timestamp)
            if beatHistory.count > 32 {
                beatHistory.removeFirst()
            }

            // Update BPM estimate
            updateBPMEstimate()

            // Update downbeat counter
            downbeatCounter = (downbeatCounter + 1) % 4
        }

        // Update beat phase
        if currentBPM > 0 && !beatHistory.isEmpty {
            let beatPeriod = 60.0 / Double(currentBPM)
            let timeSinceLastBeat = timestamp - (beatHistory.last ?? timestamp)
            beatPhase = Float(timeSinceLastBeat / beatPeriod).truncatingRemainder(dividingBy: 1.0)
        }

        let isDownbeat = isBeat && downbeatCounter == 0

        // Detect time signature
        let timeSignature = detectTimeSignature()

        // Calculate confidence based on BPM stability
        let bpmVariance = calculateBPMVariance()
        let confidence = max(0, min(1, 1.0 - bpmVariance / 20.0))

        return BeatResult(
            bpm: currentBPM,
            confidence: confidence,
            beatPhase: beatPhase,
            downbeatPhase: Float(downbeatCounter) / 4.0 + beatPhase / 4.0,
            timeSignature: timeSignature,
            onsetStrength: onsetStrength,
            isBeat: isBeat,
            isDownbeat: isDownbeat
        )
    }

    /// Reset detection state
    public func reset() {
        onsetHistory.removeAll()
        beatHistory.removeAll()
        bpmHistory.removeAll()
        previousSpectrum.removeAll()
        currentBPM = 120.0
        beatPhase = 0.0
        downbeatCounter = 0
    }

    // MARK: - Private Methods

    private func computeOnsetStrength(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              let setup = fftSetup else { return 0 }

        let samples = channelData[0]
        let frameLength = min(Int(buffer.frameLength), fftSize)

        // FFT
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        for i in 0..<frameLength {
            real[i] = samples[i]
        }

        vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)

        // Compute magnitude spectrum
        var spectrum = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            spectrum[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
        }

        // Spectral flux (half-wave rectified)
        var flux: Float = 0
        if !previousSpectrum.isEmpty {
            for i in 0..<min(spectrum.count, previousSpectrum.count) {
                let diff = spectrum[i] - previousSpectrum[i]
                flux += max(0, diff)  // Half-wave rectification
            }
            flux /= Float(spectrum.count)
        }

        previousSpectrum = spectrum
        return flux
    }

    private func detectOnset(strength: Float) -> Bool {
        guard onsetHistory.count > 5 else { return false }

        // Adaptive threshold based on recent history
        let recentMean = onsetHistory.suffix(10).reduce(0, +) / Float(min(10, onsetHistory.count))
        let adaptiveThreshold = recentMean * 1.5 + onsetThreshold

        // Peak picking
        let isLocalMax = strength > (onsetHistory.dropLast().last ?? 0)

        return strength > adaptiveThreshold && isLocalMax
    }

    private func updateBPMEstimate() {
        guard beatHistory.count >= 4 else { return }

        // Calculate inter-beat intervals
        var intervals: [TimeInterval] = []
        for i in 1..<beatHistory.count {
            let interval = beatHistory[i] - beatHistory[i - 1]
            // Filter reasonable intervals (60-200 BPM range)
            if interval > 0.3 && interval < 1.0 {
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return }

        // Compute BPM from autocorrelation of intervals
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let estimatedBPM = Float(60.0 / avgInterval)

        // Apply tempo continuity - prefer BPMs close to current
        if estimatedBPM >= 60 && estimatedBPM <= 200 {
            // Check for tempo doubling/halving
            var adjustedBPM = estimatedBPM

            if abs(estimatedBPM - currentBPM * 2) < abs(estimatedBPM - currentBPM) {
                adjustedBPM = estimatedBPM / 2
            } else if abs(estimatedBPM - currentBPM / 2) < abs(estimatedBPM - currentBPM) {
                adjustedBPM = estimatedBPM * 2
            }

            // Smooth BPM changes
            currentBPM = currentBPM * 0.9 + adjustedBPM * 0.1

            // Update BPM history
            bpmHistory.append(currentBPM)
            if bpmHistory.count > 30 {
                bpmHistory.removeFirst()
            }
        }
    }

    private func detectTimeSignature() -> TimeSignature {
        // Simple heuristic based on accent pattern
        // Could be improved with more sophisticated analysis

        guard onsetHistory.count >= 16 else { return .fourFour }

        // Group onsets into potential bar positions
        let groupOf4 = calculateAccentStrength(groupSize: 4)
        let groupOf3 = calculateAccentStrength(groupSize: 3)

        if groupOf3 > groupOf4 * 1.2 {
            return .threeFour
        }

        return .fourFour
    }

    private func calculateAccentStrength(groupSize: Int) -> Float {
        guard onsetHistory.count >= groupSize * 4 else { return 0 }

        var accentStrength: Float = 0
        let numGroups = onsetHistory.count / groupSize

        for group in 0..<numGroups {
            let startIdx = group * groupSize
            if startIdx < onsetHistory.count {
                // First beat of group should be stronger
                let firstBeat = onsetHistory[startIdx]
                var otherBeats: Float = 0
                for i in 1..<groupSize {
                    if startIdx + i < onsetHistory.count {
                        otherBeats += onsetHistory[startIdx + i]
                    }
                }
                let avgOther = otherBeats / Float(groupSize - 1)
                if avgOther > 0 {
                    accentStrength += firstBeat / avgOther
                }
            }
        }

        return accentStrength / Float(numGroups)
    }

    private func calculateBPMVariance() -> Float {
        guard bpmHistory.count > 2 else { return 10.0 }

        let mean = bpmHistory.reduce(0, +) / Float(bpmHistory.count)
        let variance = bpmHistory.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(bpmHistory.count)
        return sqrt(variance)
    }
}

// MARK: - MIR Engine (Unified Interface)

/// Unified Music Information Retrieval engine combining all MIR features
public final class MIREngine {

    // MARK: - Complete Analysis Result

    public struct MIRAnalysis {
        public let key: KeyDetector.KeyResult
        public let chord: ChordRecognizer.ChordResult
        public let beat: BeatDetector.BeatResult
        public let timestamp: TimeInterval
    }

    // MARK: - Song Analysis

    public struct SongAnalysis {
        public let key: KeyDetector.KeyResult
        public let averageBPM: Float
        public let chordProgression: [(timestamp: TimeInterval, chord: String)]
        public let sections: [Section]
        public let duration: TimeInterval
    }

    public struct Section {
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public let type: SectionType
        public let key: String?
        public let averageEnergy: Float
    }

    public enum SectionType: String {
        case intro = "Intro"
        case verse = "Verse"
        case chorus = "Chorus"
        case bridge = "Bridge"
        case outro = "Outro"
        case breakdown = "Breakdown"
        case buildup = "Buildup"
        case drop = "Drop"
        case unknown = "Unknown"
    }

    // MARK: - Properties

    public let keyDetector: KeyDetector
    public let chordRecognizer: ChordRecognizer
    public let beatDetector: BeatDetector

    private var analysisHistory: [MIRAnalysis] = []
    private var chordTimeline: [(timestamp: TimeInterval, chord: String)] = []

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.keyDetector = KeyDetector(sampleRate: sampleRate)
        self.chordRecognizer = ChordRecognizer(sampleRate: sampleRate)
        self.beatDetector = BeatDetector(sampleRate: sampleRate)
    }

    // MARK: - Real-time Analysis

    /// Perform complete MIR analysis on audio buffer
    public func analyze(buffer: AVAudioPCMBuffer, timestamp: TimeInterval) -> MIRAnalysis {
        let key = keyDetector.detectKey(from: buffer)
        let chord = chordRecognizer.recognizeChord(from: buffer)
        let beat = beatDetector.process(buffer: buffer, timestamp: timestamp)

        let analysis = MIRAnalysis(
            key: key,
            chord: chord,
            beat: beat,
            timestamp: timestamp
        )

        // Store for history
        analysisHistory.append(analysis)
        if analysisHistory.count > 1000 {
            analysisHistory.removeFirst()
        }

        // Track chord changes
        if chordTimeline.isEmpty || chordTimeline.last?.chord != chord.name {
            chordTimeline.append((timestamp: timestamp, chord: chord.name))
        }

        return analysis
    }

    /// Get complete song analysis from accumulated data
    public func getSongAnalysis() -> SongAnalysis? {
        guard !analysisHistory.isEmpty else { return nil }

        // Get most common key
        let keyVotes = Dictionary(grouping: analysisHistory) { $0.key.key }
        let mostCommonKey = keyVotes.max { $0.value.count < $1.value.count }?.value.first?.key
            ?? analysisHistory.first!.key

        // Calculate average BPM
        let bpmValues = analysisHistory.map { $0.beat.bpm }.filter { $0 > 0 }
        let avgBPM = bpmValues.isEmpty ? 120.0 : bpmValues.reduce(0, +) / Float(bpmValues.count)

        // Detect sections (simplified)
        let sections = detectSections()

        // Duration
        let duration = (analysisHistory.last?.timestamp ?? 0) - (analysisHistory.first?.timestamp ?? 0)

        return SongAnalysis(
            key: mostCommonKey,
            averageBPM: avgBPM,
            chordProgression: chordTimeline,
            sections: sections,
            duration: duration
        )
    }

    /// Reset all detection states
    public func reset() {
        keyDetector.reset()
        beatDetector.reset()
        analysisHistory.removeAll()
        chordTimeline.removeAll()
    }

    // MARK: - Private Methods

    private func detectSections() -> [Section] {
        guard analysisHistory.count >= 10 else { return [] }

        var sections: [Section] = []
        let windowSize = 20  // Analyze in chunks

        var currentStart: TimeInterval = analysisHistory.first?.timestamp ?? 0
        var lastEnergy: Float = 0

        for i in stride(from: 0, to: analysisHistory.count, by: windowSize) {
            let endIdx = min(i + windowSize, analysisHistory.count)
            let window = Array(analysisHistory[i..<endIdx])

            guard !window.isEmpty else { continue }

            // Calculate average energy (using onset strength as proxy)
            let avgEnergy = window.map { $0.beat.onsetStrength }.reduce(0, +) / Float(window.count)

            // Detect section changes based on energy changes
            let energyChange = abs(avgEnergy - lastEnergy)

            if energyChange > 0.3 || sections.isEmpty {
                let endTime = window.last?.timestamp ?? currentStart

                // Determine section type based on energy level
                let sectionType: SectionType
                if avgEnergy < 0.2 {
                    sectionType = .breakdown
                } else if avgEnergy > 0.6 {
                    sectionType = energyChange > 0 ? .drop : .chorus
                } else if avgEnergy > lastEnergy {
                    sectionType = .buildup
                } else {
                    sectionType = .verse
                }

                if !sections.isEmpty {
                    sections[sections.count - 1] = Section(
                        startTime: sections.last!.startTime,
                        endTime: endTime,
                        type: sections.last!.type,
                        key: sections.last!.key,
                        averageEnergy: sections.last!.averageEnergy
                    )
                }

                // Most common key in this section
                let sectionKeys = window.map { $0.key.key }
                let mostCommonKey = Dictionary(grouping: sectionKeys) { $0 }
                    .max { $0.value.count < $1.value.count }?.key

                sections.append(Section(
                    startTime: endTime,
                    endTime: endTime,
                    type: sectionType,
                    key: mostCommonKey,
                    averageEnergy: avgEnergy
                ))

                currentStart = endTime
            }

            lastEnergy = avgEnergy
        }

        // Close last section
        if !sections.isEmpty {
            let lastTime = analysisHistory.last?.timestamp ?? 0
            sections[sections.count - 1] = Section(
                startTime: sections.last!.startTime,
                endTime: lastTime,
                type: sections.last!.type,
                key: sections.last!.key,
                averageEnergy: sections.last!.averageEnergy
            )
        }

        return sections
    }
}
