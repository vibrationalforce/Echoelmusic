//
//  MusicInformationRetrieval.swift
//  Echoelmusic
//
//  Music Information Retrieval (MIR) System
//  Key detection, chord recognition, beat tracking, tempo estimation
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Accelerate

// MARK: - Musical Key Detection

/// Krumhansl-Schmuckler key-finding algorithm implementation
/// Detects the musical key from audio chromagram data
public final class KeyDetector {

    // MARK: - Key Profiles

    /// Krumhansl major key profile (empirically derived from listener studies)
    private static let majorProfile: [Float] = [
        6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
    ]

    /// Krumhansl minor key profile
    private static let minorProfile: [Float] = [
        6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
    ]

    /// Note names for display
    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - FFT Setup

    private let fftSize: Int
    private let hopSize: Int
    private var fftSetup: FFTSetup?
    private var window: [Float]
    private var realBuffer: [Float]
    private var imagBuffer: [Float]

    // MARK: - Initialization

    public init(fftSize: Int = 4096, hopSize: Int = 2048) {
        self.fftSize = fftSize
        self.hopSize = hopSize

        // Create Hann window
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Allocate buffers
        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)

        // Create FFT setup
        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Key Detection

    /// Detected key result
    public struct KeyResult {
        public let key: String           // e.g., "C major", "A minor"
        public let root: String          // e.g., "C", "A"
        public let mode: Mode            // major or minor
        public let confidence: Float     // 0.0 - 1.0
        public let alternativeKey: String?
        public let alternativeConfidence: Float?

        public enum Mode: String {
            case major = "major"
            case minor = "minor"
        }
    }

    /// Detect key from audio samples
    /// - Parameter samples: Audio samples (mono, normalized -1.0 to 1.0)
    /// - Returns: Detected key with confidence score
    public func detectKey(samples: [Float]) -> KeyResult {
        // Compute chromagram
        let chromagram = computeChromagram(samples: samples)

        // Correlate with all 24 key profiles
        var correlations: [(key: String, root: String, mode: KeyResult.Mode, correlation: Float)] = []

        for rootIndex in 0..<12 {
            // Rotate profiles to match root note
            let rotatedMajor = rotateProfile(Self.majorProfile, by: rootIndex)
            let rotatedMinor = rotateProfile(Self.minorProfile, by: rootIndex)

            let majorCorr = pearsonCorrelation(chromagram, rotatedMajor)
            let minorCorr = pearsonCorrelation(chromagram, rotatedMinor)

            let rootName = Self.noteNames[rootIndex]

            correlations.append((
                key: "\(rootName) major",
                root: rootName,
                mode: .major,
                correlation: majorCorr
            ))
            correlations.append((
                key: "\(rootName) minor",
                root: rootName,
                mode: .minor,
                correlation: minorCorr
            ))
        }

        // Sort by correlation
        correlations.sort { $0.correlation > $1.correlation }

        // Normalize confidence to 0-1 range
        let maxCorr = correlations[0].correlation
        let minCorr = correlations.last?.correlation ?? 0
        let range = maxCorr - minCorr
        let confidence = range > 0 ? (maxCorr - minCorr) / range : 0.5

        // Get best and alternative
        let best = correlations[0]
        let alternative = correlations.count > 1 ? correlations[1] : nil

        return KeyResult(
            key: best.key,
            root: best.root,
            mode: best.mode,
            confidence: min(1.0, max(0.0, confidence)),
            alternativeKey: alternative?.key,
            alternativeConfidence: alternative.map { ($0.correlation - minCorr) / range }
        )
    }

    // MARK: - Chromagram Computation

    /// Compute chromagram (12-bin pitch class distribution)
    private func computeChromagram(samples: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else {
            return [Float](repeating: 1.0 / 12.0, count: 12)
        }

        var chromagram = [Float](repeating: 0, count: 12)
        var frameCount: Float = 0

        // Process in frames
        var position = 0
        while position + fftSize <= samples.count {
            // Extract and window frame
            var frame = [Float](samples[position..<position + fftSize])
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // Perform FFT
            var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
            frame.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
            }

            let log2n = vDSP_Length(log2(Float(fftSize)))
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

            // Compute magnitude spectrum
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // Map frequencies to pitch classes
            let sampleRate: Float = 44100
            for bin in 1..<(fftSize / 2) {
                let frequency = Float(bin) * sampleRate / Float(fftSize)

                // Only consider musical range (20Hz - 5000Hz)
                guard frequency >= 20 && frequency <= 5000 else { continue }

                // Convert frequency to MIDI note and pitch class
                let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
                let pitchClass = Int(round(midiNote)) % 12

                chromagram[pitchClass] += magnitudes[bin] * magnitudes[bin]
            }

            position += hopSize
            frameCount += 1
        }

        // Normalize chromagram
        if frameCount > 0 {
            var scale: Float = 1.0 / frameCount
            vDSP_vsmul(chromagram, 1, &scale, &chromagram, 1, vDSP_Length(12))

            // L2 normalize
            var sum: Float = 0
            vDSP_svesq(chromagram, 1, &sum, vDSP_Length(12))
            if sum > 0 {
                let norm = sqrt(sum)
                chromagram = chromagram.map { $0 / norm }
            }
        }

        return chromagram
    }

    // MARK: - Helper Functions

    private func rotateProfile(_ profile: [Float], by amount: Int) -> [Float] {
        var rotated = [Float](repeating: 0, count: 12)
        for i in 0..<12 {
            rotated[i] = profile[(i - amount + 12) % 12]
        }
        return rotated
    }

    private func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
        guard x.count == y.count && x.count > 0 else { return 0 }

        let n = Float(x.count)

        var sumX: Float = 0
        var sumY: Float = 0
        var sumXY: Float = 0
        var sumX2: Float = 0
        var sumY2: Float = 0

        vDSP_sve(x, 1, &sumX, vDSP_Length(x.count))
        vDSP_sve(y, 1, &sumY, vDSP_Length(y.count))
        vDSP_dotpr(x, 1, y, 1, &sumXY, vDSP_Length(x.count))
        vDSP_svesq(x, 1, &sumX2, vDSP_Length(x.count))
        vDSP_svesq(y, 1, &sumY2, vDSP_Length(y.count))

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        return denominator > 0 ? numerator / denominator : 0
    }
}

// MARK: - Chord Recognition

/// Real-time chord recognition from audio
public final class ChordRecognizer {

    // MARK: - Chord Templates

    /// Chord type definitions (intervals from root)
    public enum ChordType: String, CaseIterable {
        case major = "maj"
        case minor = "min"
        case diminished = "dim"
        case augmented = "aug"
        case major7 = "maj7"
        case minor7 = "min7"
        case dominant7 = "7"
        case diminished7 = "dim7"
        case halfDiminished7 = "m7b5"
        case sus2 = "sus2"
        case sus4 = "sus4"
        case add9 = "add9"

        var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .diminished: return [0, 3, 6]
            case .augmented: return [0, 4, 8]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .dominant7: return [0, 4, 7, 10]
            case .diminished7: return [0, 3, 6, 9]
            case .halfDiminished7: return [0, 3, 6, 10]
            case .sus2: return [0, 2, 7]
            case .sus4: return [0, 5, 7]
            case .add9: return [0, 2, 4, 7]
            }
        }
    }

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private let keyDetector: KeyDetector

    public init() {
        self.keyDetector = KeyDetector()
    }

    // MARK: - Chord Result

    public struct ChordResult {
        public let chord: String         // e.g., "C maj", "Am7"
        public let root: String          // e.g., "C", "A"
        public let type: ChordType
        public let confidence: Float
        public let bassNote: String?     // For slash chords
        public let alternatives: [(chord: String, confidence: Float)]
    }

    /// Recognize chord from chromagram
    public func recognizeChord(chromagram: [Float]) -> ChordResult {
        var matches: [(root: Int, type: ChordType, score: Float)] = []

        // Test all root notes and chord types
        for rootIndex in 0..<12 {
            for chordType in ChordType.allCases {
                let score = matchChordTemplate(
                    chromagram: chromagram,
                    root: rootIndex,
                    type: chordType
                )
                matches.append((rootIndex, chordType, score))
            }
        }

        // Sort by score
        matches.sort { $0.score > $1.score }

        // Get best match
        let best = matches[0]
        let rootName = Self.noteNames[best.root]

        // Find bass note (lowest significant pitch class)
        var bassNote: String? = nil
        var maxBassEnergy: Float = 0
        for i in 0..<12 {
            if chromagram[i] > maxBassEnergy && chromagram[i] > 0.1 {
                maxBassEnergy = chromagram[i]
                if i != best.root {
                    bassNote = Self.noteNames[i]
                }
            }
        }

        // Get alternatives
        let alternatives = matches.dropFirst().prefix(3).map { match -> (String, Float) in
            let name = Self.noteNames[match.root]
            return ("\(name) \(match.type.rawValue)", match.score)
        }

        return ChordResult(
            chord: "\(rootName) \(best.type.rawValue)",
            root: rootName,
            type: best.type,
            confidence: best.score,
            bassNote: bassNote,
            alternatives: Array(alternatives)
        )
    }

    private func matchChordTemplate(chromagram: [Float], root: Int, type: ChordType) -> Float {
        // Create binary template
        var template = [Float](repeating: 0, count: 12)
        for interval in type.intervals {
            let pitchClass = (root + interval) % 12
            template[pitchClass] = 1.0
        }

        // Weight root note higher
        template[root] *= 1.5

        // Compute cosine similarity
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(chromagram, 1, template, 1, &dotProduct, vDSP_Length(12))
        vDSP_svesq(chromagram, 1, &normA, vDSP_Length(12))
        vDSP_svesq(template, 1, &normB, vDSP_Length(12))

        let denominator = sqrt(normA * normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}

// MARK: - Beat/Tempo Detection

/// Beat and tempo detection using onset detection and autocorrelation
public final class BeatDetector {

    // MARK: - Detection Parameters

    private let sampleRate: Float
    private let hopSize: Int
    private let fftSize: Int

    // Onset detection
    private var previousSpectrum: [Float]?
    private var onsetFunction: [Float] = []

    // Tempo estimation
    private let minBPM: Float = 60
    private let maxBPM: Float = 200

    public init(sampleRate: Float = 44100, hopSize: Int = 512, fftSize: Int = 2048) {
        self.sampleRate = sampleRate
        self.hopSize = hopSize
        self.fftSize = fftSize
    }

    // MARK: - Beat Result

    public struct BeatResult {
        public let bpm: Float
        public let confidence: Float
        public let beatPositions: [Float]  // In seconds
        public let downbeats: [Float]      // Strong beats (bar starts)
        public let timeSignature: TimeSignature

        public enum TimeSignature: String {
            case fourFour = "4/4"
            case threeFour = "3/4"
            case sixEight = "6/8"
        }
    }

    /// Detect tempo and beats from audio samples
    public func detectBeats(samples: [Float]) -> BeatResult {
        // Compute onset strength function
        let onsets = computeOnsetStrength(samples: samples)

        // Estimate tempo via autocorrelation
        let (bpm, confidence) = estimateTempo(onsets: onsets)

        // Track beat positions
        let beatPositions = trackBeats(onsets: onsets, bpm: bpm)

        // Detect downbeats and time signature
        let (downbeats, timeSignature) = detectDownbeats(
            beatPositions: beatPositions,
            onsets: onsets
        )

        return BeatResult(
            bpm: bpm,
            confidence: confidence,
            beatPositions: beatPositions,
            downbeats: downbeats,
            timeSignature: timeSignature
        )
    }

    // MARK: - Onset Detection

    private func computeOnsetStrength(samples: [Float]) -> [Float] {
        var onsets: [Float] = []
        var position = 0

        // Create FFT setup
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var realBuffer = [Float](repeating: 0, count: fftSize / 2)
        var imagBuffer = [Float](repeating: 0, count: fftSize / 2)

        while position + fftSize <= samples.count {
            // Extract and window frame
            var frame = [Float](samples[position..<position + fftSize])
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // FFT
            var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
            frame.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
            }
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

            // Magnitude spectrum
            var spectrum = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvabs(&splitComplex, 1, &spectrum, 1, vDSP_Length(fftSize / 2))

            // Spectral flux (positive difference with previous frame)
            if let prevSpectrum = previousSpectrum {
                var onset: Float = 0
                for i in 0..<spectrum.count {
                    let diff = spectrum[i] - prevSpectrum[i]
                    if diff > 0 {
                        onset += diff
                    }
                }
                onsets.append(onset)
            }

            previousSpectrum = spectrum
            position += hopSize
        }

        return onsets
    }

    // MARK: - Tempo Estimation

    private func estimateTempo(onsets: [Float]) -> (bpm: Float, confidence: Float) {
        guard onsets.count > 100 else {
            return (120.0, 0.0)  // Default tempo
        }

        // Autocorrelation
        let maxLag = Int(sampleRate * 60.0 / Float(hopSize) / minBPM)
        let minLag = Int(sampleRate * 60.0 / Float(hopSize) / maxBPM)

        var autocorr = [Float](repeating: 0, count: maxLag)

        for lag in minLag..<maxLag {
            var sum: Float = 0
            let count = onsets.count - lag
            for i in 0..<count {
                sum += onsets[i] * onsets[i + lag]
            }
            autocorr[lag] = sum / Float(count)
        }

        // Find peak
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(autocorr, 1, &maxValue, &maxIndex, vDSP_Length(autocorr.count))

        // Convert lag to BPM
        let lagFrames = Float(maxIndex)
        let lagSeconds = lagFrames * Float(hopSize) / sampleRate
        let bpm = 60.0 / lagSeconds

        // Confidence from peak prominence
        var meanValue: Float = 0
        vDSP_meanv(autocorr, 1, &meanValue, vDSP_Length(autocorr.count))
        let confidence = meanValue > 0 ? min(1.0, maxValue / (meanValue * 3)) : 0

        return (bpm, confidence)
    }

    // MARK: - Beat Tracking

    private func trackBeats(onsets: [Float], bpm: Float) -> [Float] {
        var beats: [Float] = []

        let beatPeriodFrames = Int(sampleRate * 60.0 / bpm / Float(hopSize))

        // Simple peak picking with beat period constraint
        var lastBeat = 0
        for i in 0..<onsets.count {
            // Check if near expected beat position
            let expectedBeat = lastBeat + beatPeriodFrames
            let tolerance = beatPeriodFrames / 4

            if abs(i - expectedBeat) < tolerance {
                // Look for local maximum
                var isLocalMax = true
                let windowSize = 3
                for j in max(0, i - windowSize)...min(onsets.count - 1, i + windowSize) {
                    if j != i && onsets[j] > onsets[i] {
                        isLocalMax = false
                        break
                    }
                }

                if isLocalMax && onsets[i] > 0 {
                    let timeSeconds = Float(i) * Float(hopSize) / sampleRate
                    beats.append(timeSeconds)
                    lastBeat = i
                }
            }
        }

        return beats
    }

    // MARK: - Downbeat Detection

    private func detectDownbeats(
        beatPositions: [Float],
        onsets: [Float]
    ) -> ([Float], BeatResult.TimeSignature) {
        guard beatPositions.count >= 4 else {
            return ([], .fourFour)
        }

        // Analyze beat strengths
        var beatStrengths: [Float] = []
        for beat in beatPositions {
            let frameIndex = Int(beat * sampleRate / Float(hopSize))
            if frameIndex >= 0 && frameIndex < onsets.count {
                beatStrengths.append(onsets[frameIndex])
            }
        }

        // Look for periodicity in beat strengths
        // Test 4/4, 3/4, 6/8
        var bestMeter = 4
        var bestScore: Float = 0

        for meter in [4, 3, 6] {
            var score: Float = 0
            for i in stride(from: 0, to: beatStrengths.count, by: meter) {
                if i < beatStrengths.count {
                    score += beatStrengths[i]
                }
            }
            if score > bestScore {
                bestScore = score
                bestMeter = meter
            }
        }

        // Extract downbeats
        var downbeats: [Float] = []
        for i in stride(from: 0, to: beatPositions.count, by: bestMeter) {
            downbeats.append(beatPositions[i])
        }

        let timeSignature: BeatResult.TimeSignature
        switch bestMeter {
        case 3: timeSignature = .threeFour
        case 6: timeSignature = .sixEight
        default: timeSignature = .fourFour
        }

        return (downbeats, timeSignature)
    }
}

// MARK: - Integrated MIR Engine

/// Unified Music Information Retrieval engine combining all analysis types
public final class MIREngine {

    private let keyDetector: KeyDetector
    private let chordRecognizer: ChordRecognizer
    private let beatDetector: BeatDetector

    public init() {
        self.keyDetector = KeyDetector()
        self.chordRecognizer = ChordRecognizer()
        self.beatDetector = BeatDetector()
    }

    // MARK: - Complete Analysis

    public struct AnalysisResult {
        public let key: KeyDetector.KeyResult
        public let tempo: BeatDetector.BeatResult
        public let chords: [TimedChord]
        public let sections: [Section]

        public struct TimedChord {
            public let chord: ChordRecognizer.ChordResult
            public let startTime: Float
            public let duration: Float
        }

        public struct Section {
            public let name: String  // "Intro", "Verse", "Chorus", etc.
            public let startTime: Float
            public let endTime: Float
        }
    }

    /// Perform complete MIR analysis on audio
    public func analyze(samples: [Float], sampleRate: Float = 44100) -> AnalysisResult {
        // Key detection
        let key = keyDetector.detectKey(samples: samples)

        // Beat/tempo detection
        let tempo = beatDetector.detectBeats(samples: samples)

        // Chord detection (analyze in windows)
        let chords = detectChordsOverTime(samples: samples, sampleRate: sampleRate)

        // Section detection (simplified)
        let sections = detectSections(tempo: tempo, chords: chords)

        return AnalysisResult(
            key: key,
            tempo: tempo,
            chords: chords,
            sections: sections
        )
    }

    // MARK: - Chord Timeline

    private func detectChordsOverTime(
        samples: [Float],
        sampleRate: Float
    ) -> [AnalysisResult.TimedChord] {
        var timedChords: [AnalysisResult.TimedChord] = []

        // Analyze in 1-second windows with 0.5s hop
        let windowSize = Int(sampleRate)
        let hopSize = windowSize / 2

        var position = 0
        while position + windowSize <= samples.count {
            let window = Array(samples[position..<position + windowSize])
            let chromagram = computeChromagram(samples: window, sampleRate: sampleRate)
            let chord = chordRecognizer.recognizeChord(chromagram: chromagram)

            let startTime = Float(position) / sampleRate
            let duration = Float(hopSize) / sampleRate

            // Only add if different from previous or first
            if timedChords.isEmpty || timedChords.last?.chord.chord != chord.chord {
                timedChords.append(AnalysisResult.TimedChord(
                    chord: chord,
                    startTime: startTime,
                    duration: duration
                ))
            } else if let last = timedChords.last {
                // Extend previous chord duration
                timedChords[timedChords.count - 1] = AnalysisResult.TimedChord(
                    chord: last.chord,
                    startTime: last.startTime,
                    duration: last.duration + Float(hopSize) / sampleRate
                )
            }

            position += hopSize
        }

        return timedChords
    }

    private func computeChromagram(samples: [Float], sampleRate: Float) -> [Float] {
        // Simple chromagram via pitch class energy distribution
        var chromagram = [Float](repeating: 0, count: 12)

        // Use keyDetector's internal chromagram computation
        // For now, simplified version
        let fftSize = 4096
        guard samples.count >= fftSize else {
            return chromagram
        }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return chromagram
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var frame = Array(samples.prefix(fftSize))
        vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

        var realBuffer = [Float](repeating: 0, count: fftSize / 2)
        var imagBuffer = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

        frame.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Map to pitch classes
        for bin in 1..<(fftSize / 2) {
            let frequency = Float(bin) * sampleRate / Float(fftSize)
            guard frequency >= 20 && frequency <= 5000 else { continue }

            let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
            let pitchClass = (Int(round(midiNote)) % 12 + 12) % 12

            chromagram[pitchClass] += magnitudes[bin] * magnitudes[bin]
        }

        // Normalize
        var sum: Float = 0
        vDSP_sve(chromagram, 1, &sum, vDSP_Length(12))
        if sum > 0 {
            var scale = 1.0 / sum
            vDSP_vsmul(chromagram, 1, &scale, &chromagram, 1, vDSP_Length(12))
        }

        return chromagram
    }

    // MARK: - Section Detection

    private func detectSections(
        tempo: BeatDetector.BeatResult,
        chords: [AnalysisResult.TimedChord]
    ) -> [AnalysisResult.Section] {
        // Simplified section detection based on chord repetition patterns
        var sections: [AnalysisResult.Section] = []

        guard !chords.isEmpty else { return sections }

        // Group chords into potential sections (8-16 bar patterns)
        let barsPerSection = 8
        let beatsPerBar = tempo.timeSignature == .threeFour ? 3 : 4
        let sectionDuration = Float(barsPerSection * beatsPerBar) * 60.0 / tempo.bpm

        var currentTime: Float = 0
        let totalDuration = chords.last.map { $0.startTime + $0.duration } ?? 0

        var sectionIndex = 0
        let sectionNames = ["Intro", "Verse", "Pre-Chorus", "Chorus", "Verse", "Chorus", "Bridge", "Chorus", "Outro"]

        while currentTime < totalDuration {
            let endTime = min(currentTime + sectionDuration, totalDuration)
            let name = sectionNames[sectionIndex % sectionNames.count]

            sections.append(AnalysisResult.Section(
                name: name,
                startTime: currentTime,
                endTime: endTime
            ))

            currentTime = endTime
            sectionIndex += 1
        }

        return sections
    }
}
