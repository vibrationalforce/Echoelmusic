// AISampleLibraryEngine.swift
// Echoelmusic - AI-Powered Sample Library Management
// Created by Claude (Phase 4) - December 2025

import Foundation
import Accelerate
import AVFoundation
import CoreML
import NaturalLanguage

// MARK: - Sample Metadata

/// Complete metadata for an audio sample
public struct SampleMetadata: Identifiable, Codable {
    public let id: UUID
    public var filename: String
    public var path: String
    public var duration: TimeInterval
    public var sampleRate: Int
    public var channels: Int
    public var bitDepth: Int
    public var fileSize: Int64

    // Auto-detected properties
    public var bpm: Float?
    public var key: MusicalKey?
    public var category: SampleCategory
    public var subcategory: String?
    public var tags: Set<String>
    public var mood: [String]
    public var energy: Float  // 0-1
    public var isLoop: Bool
    public var isOneShot: Bool
    public var loopPoints: (start: Int, end: Int)?

    // Audio features
    public var spectralCentroid: Float?
    public var brightness: Float?
    public var warmth: Float?
    public var punchiness: Float?
    public var rmsLevel: Float?
    public var peakLevel: Float?

    // AI embeddings for similarity search
    public var embedding: [Float]?

    // User data
    public var isFavorite: Bool = false
    public var rating: Int = 0  // 0-5
    public var userTags: Set<String> = []
    public var lastUsed: Date?
    public var useCount: Int = 0
    public var dateAdded: Date

    public init(path: String) {
        self.id = UUID()
        self.filename = URL(fileURLWithPath: path).lastPathComponent
        self.path = path
        self.duration = 0
        self.sampleRate = 44100
        self.channels = 2
        self.bitDepth = 16
        self.fileSize = 0
        self.category = .unknown
        self.tags = []
        self.mood = []
        self.energy = 0.5
        self.isLoop = false
        self.isOneShot = false
        self.dateAdded = Date()
    }
}

// MARK: - Sample Categories

public enum SampleCategory: String, Codable, CaseIterable {
    case drums = "Drums"
    case bass = "Bass"
    case synth = "Synth"
    case keys = "Keys"
    case guitar = "Guitar"
    case strings = "Strings"
    case brass = "Brass"
    case woodwinds = "Woodwinds"
    case vocals = "Vocals"
    case fx = "FX"
    case foley = "Foley"
    case ambience = "Ambience"
    case loops = "Loops"
    case oneShots = "One Shots"
    case unknown = "Unknown"

    var subcategories: [String] {
        switch self {
        case .drums:
            return ["Kicks", "Snares", "Hi-Hats", "Cymbals", "Toms", "Percussion", "Full Loops", "Fills", "808", "909", "Breakbeats"]
        case .bass:
            return ["Sub Bass", "808 Bass", "Synth Bass", "Acoustic Bass", "Electric Bass", "Plucks", "Wobbles"]
        case .synth:
            return ["Leads", "Pads", "Arps", "Plucks", "Chords", "Stabs", "Textures", "Atmospheres"]
        case .vocals:
            return ["Adlibs", "Chops", "Full Phrases", "Harmonies", "Chants", "Spoken Word", "Processed"]
        case .fx:
            return ["Risers", "Downlifters", "Impacts", "Sweeps", "Whooshes", "Glitches", "Transitions"]
        default:
            return []
        }
    }
}

// MARK: - Musical Key

public enum MusicalKey: String, Codable, CaseIterable {
    case cMajor = "C Major"
    case cMinor = "C Minor"
    case cSharpMajor = "C# Major"
    case cSharpMinor = "C# Minor"
    case dMajor = "D Major"
    case dMinor = "D Minor"
    case dSharpMajor = "D# Major"
    case dSharpMinor = "D# Minor"
    case eMajor = "E Major"
    case eMinor = "E Minor"
    case fMajor = "F Major"
    case fMinor = "F Minor"
    case fSharpMajor = "F# Major"
    case fSharpMinor = "F# Minor"
    case gMajor = "G Major"
    case gMinor = "G Minor"
    case gSharpMajor = "G# Major"
    case gSharpMinor = "G# Minor"
    case aMajor = "A Major"
    case aMinor = "A Minor"
    case aSharpMajor = "A# Major"
    case aSharpMinor = "A# Minor"
    case bMajor = "B Major"
    case bMinor = "B Minor"

    var camelotCode: String {
        switch self {
        case .cMajor: return "8B"
        case .cMinor: return "5A"
        case .cSharpMajor: return "3B"
        case .cSharpMinor: return "12A"
        case .dMajor: return "10B"
        case .dMinor: return "7A"
        case .dSharpMajor: return "5B"
        case .dSharpMinor: return "2A"
        case .eMajor: return "12B"
        case .eMinor: return "9A"
        case .fMajor: return "7B"
        case .fMinor: return "4A"
        case .fSharpMajor: return "2B"
        case .fSharpMinor: return "11A"
        case .gMajor: return "9B"
        case .gMinor: return "6A"
        case .gSharpMajor: return "4B"
        case .gSharpMinor: return "1A"
        case .aMajor: return "11B"
        case .aMinor: return "8A"
        case .aSharpMajor: return "6B"
        case .aSharpMinor: return "3A"
        case .bMajor: return "1B"
        case .bMinor: return "10A"
        }
    }

    /// Compatible keys for mixing
    var compatibleKeys: [MusicalKey] {
        // Camelot wheel: same, +1, -1, parallel major/minor
        let camelot = camelotCode
        let number = Int(camelot.dropLast()) ?? 1
        let letter = camelot.last ?? "B"

        let adjacent = [(number - 1 + 12) % 12 + 1, number, (number % 12) + 1]
        let parallel = letter == "A" ? "B" : "A"

        return MusicalKey.allCases.filter { key in
            let keyCode = key.camelotCode
            let keyNum = Int(keyCode.dropLast()) ?? 1
            let keyLetter = keyCode.last ?? "B"

            return (adjacent.contains(keyNum) && keyLetter == letter) ||
                   (keyNum == number && String(keyLetter) == parallel)
        }
    }
}

// MARK: - Audio Analyzer

/// Analyzes audio files to extract features
public final class AudioAnalyzer: @unchecked Sendable {

    private let fftSize = 4096
    private let hopSize = 512

    public init() {}

    /// Analyze an audio file
    public func analyze(url: URL) async throws -> SampleMetadata {
        var metadata = SampleMetadata(path: url.path)

        // Load audio file
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AnalyzerError.bufferCreationFailed
        }

        try file.read(into: buffer)

        // Basic metadata
        metadata.duration = Double(frameCount) / format.sampleRate
        metadata.sampleRate = Int(format.sampleRate)
        metadata.channels = Int(format.channelCount)
        metadata.bitDepth = 32  // Float processing format

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            metadata.fileSize = attrs[.size] as? Int64 ?? 0
        }

        // Extract mono samples for analysis
        let samples = extractMonoSamples(buffer: buffer)

        // Analyze features
        metadata.bpm = detectBPM(samples: samples, sampleRate: Float(format.sampleRate))
        metadata.key = detectKey(samples: samples, sampleRate: Float(format.sampleRate))
        metadata.isLoop = detectLoop(samples: samples)
        metadata.isOneShot = !metadata.isLoop && metadata.duration < 2.0

        // Audio features
        let features = extractAudioFeatures(samples: samples, sampleRate: Float(format.sampleRate))
        metadata.spectralCentroid = features.spectralCentroid
        metadata.brightness = features.brightness
        metadata.warmth = features.warmth
        metadata.punchiness = features.punchiness
        metadata.rmsLevel = features.rms
        metadata.peakLevel = features.peak
        metadata.energy = features.energy

        // Auto-categorize
        metadata.category = categorize(metadata: metadata, features: features)
        metadata.tags = generateTags(metadata: metadata, features: features)
        metadata.mood = detectMood(features: features)

        // Generate embedding for similarity search
        metadata.embedding = generateEmbedding(features: features)

        return metadata
    }

    private func extractMonoSamples(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var mono = [Float](repeating: 0, count: frameCount)

        if channelCount == 1 {
            for i in 0..<frameCount {
                mono[i] = channelData[0][i]
            }
        } else {
            // Mix to mono
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                mono[i] = sum / Float(channelCount)
            }
        }

        return mono
    }

    // MARK: - BPM Detection

    private func detectBPM(samples: [Float], sampleRate: Float) -> Float? {
        guard samples.count > Int(sampleRate) else { return nil }

        // Onset detection via spectral flux
        let onsets = detectOnsets(samples: samples, sampleRate: sampleRate)
        guard onsets.count > 2 else { return nil }

        // Calculate inter-onset intervals
        var intervals: [Float] = []
        for i in 1..<onsets.count {
            let interval = Float(onsets[i] - onsets[i-1]) / sampleRate
            if interval > 0.1 && interval < 2.0 {  // 30-600 BPM range
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // Autocorrelation to find dominant tempo
        let minLag = Int(sampleRate * 0.25)  // 240 BPM
        let maxLag = Int(sampleRate * 1.0)   // 60 BPM

        var bestCorr: Float = 0
        var bestLag = minLag

        let onsetSignal = createOnsetSignal(onsets: onsets, length: samples.count)

        for lag in minLag..<min(maxLag, onsetSignal.count / 2) {
            var corr: Float = 0
            var count = 0

            for i in 0..<onsetSignal.count - lag {
                corr += onsetSignal[i] * onsetSignal[i + lag]
                count += 1
            }

            corr /= Float(count)

            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        let bpm = 60.0 * sampleRate / Float(bestLag)

        // Snap to common tempos
        return snapToCommonTempo(bpm)
    }

    private func detectOnsets(samples: [Float], sampleRate: Float) -> [Int] {
        var onsets: [Int] = []
        let windowSize = 1024
        let hopSize = 256

        var prevSpectrum = [Float](repeating: 0, count: windowSize / 2)
        var flux: [Float] = []

        for i in stride(from: 0, to: samples.count - windowSize, by: hopSize) {
            let window = Array(samples[i..<i+windowSize])
            let spectrum = computeMagnitudeSpectrum(window)

            // Spectral flux (positive differences only)
            var frameFlux: Float = 0
            for j in 0..<spectrum.count {
                let diff = spectrum[j] - prevSpectrum[j]
                if diff > 0 {
                    frameFlux += diff * diff
                }
            }
            flux.append(sqrt(frameFlux))
            prevSpectrum = spectrum
        }

        // Peak picking
        let threshold = flux.reduce(0, +) / Float(flux.count) * 1.5

        for i in 1..<flux.count - 1 {
            if flux[i] > threshold && flux[i] > flux[i-1] && flux[i] > flux[i+1] {
                onsets.append(i * hopSize)
            }
        }

        return onsets
    }

    private func createOnsetSignal(onsets: [Int], length: Int) -> [Float] {
        var signal = [Float](repeating: 0, count: length)
        for onset in onsets where onset < length {
            signal[onset] = 1.0
        }
        return signal
    }

    private func snapToCommonTempo(_ bpm: Float) -> Float {
        // Common tempos
        let tempos: [Float] = [60, 70, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 128, 130, 135, 140, 145, 150, 160, 170, 174, 175, 180]

        var closest = tempos[0]
        var minDiff = abs(bpm - closest)

        for tempo in tempos {
            // Also check half and double time
            for factor: Float in [0.5, 1.0, 2.0] {
                let adjusted = tempo * factor
                let diff = abs(bpm - adjusted)
                if diff < minDiff {
                    minDiff = diff
                    closest = adjusted
                }
            }
        }

        return minDiff < 5 ? closest : round(bpm)
    }

    // MARK: - Key Detection

    private func detectKey(samples: [Float], sampleRate: Float) -> MusicalKey? {
        // Compute chromagram
        let chromagram = computeChromagram(samples: samples, sampleRate: sampleRate)

        // Krumhansl-Schmuckler key profiles
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        var bestKey: MusicalKey?
        var bestCorr: Float = -1

        let keyNames: [MusicalKey] = [.cMajor, .cSharpMajor, .dMajor, .dSharpMajor, .eMajor, .fMajor,
                                       .fSharpMajor, .gMajor, .gSharpMajor, .aMajor, .aSharpMajor, .bMajor]
        let minorKeyNames: [MusicalKey] = [.cMinor, .cSharpMinor, .dMinor, .dSharpMinor, .eMinor, .fMinor,
                                            .fSharpMinor, .gMinor, .gSharpMinor, .aMinor, .aSharpMinor, .bMinor]

        // Test all major keys
        for i in 0..<12 {
            let rotatedProfile = rotateProfile(majorProfile, by: i)
            let corr = pearsonCorrelation(chromagram, rotatedProfile)

            if corr > bestCorr {
                bestCorr = corr
                bestKey = keyNames[i]
            }
        }

        // Test all minor keys
        for i in 0..<12 {
            let rotatedProfile = rotateProfile(minorProfile, by: i)
            let corr = pearsonCorrelation(chromagram, rotatedProfile)

            if corr > bestCorr {
                bestCorr = corr
                bestKey = minorKeyNames[i]
            }
        }

        return bestCorr > 0.5 ? bestKey : nil
    }

    private func computeChromagram(samples: [Float], sampleRate: Float) -> [Float] {
        var chroma = [Float](repeating: 0, count: 12)
        let windowSize = 4096

        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize / 2) {
            let window = Array(samples[i..<i+windowSize])
            let spectrum = computeMagnitudeSpectrum(window)

            // Map spectrum bins to chroma
            for bin in 1..<spectrum.count {
                let freq = Float(bin) * sampleRate / Float(windowSize)
                if freq > 20 && freq < 5000 {
                    let note = 12 * log2(freq / 440.0) + 69  // MIDI note
                    let chromaIndex = Int(note.truncatingRemainder(dividingBy: 12))
                    if chromaIndex >= 0 && chromaIndex < 12 {
                        chroma[chromaIndex] += spectrum[bin]
                    }
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
            rotated[i] = profile[(i - amount + 12) % 12]
        }
        return rotated
    }

    private func pearsonCorrelation(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count && a.count > 0 else { return 0 }

        let n = Float(a.count)
        let sumA = a.reduce(0, +)
        let sumB = b.reduce(0, +)
        let sumAB = zip(a, b).map(*).reduce(0, +)
        let sumA2 = a.map { $0 * $0 }.reduce(0, +)
        let sumB2 = b.map { $0 * $0 }.reduce(0, +)

        let num = n * sumAB - sumA * sumB
        let den = sqrt((n * sumA2 - sumA * sumA) * (n * sumB2 - sumB * sumB))

        return den > 0 ? num / den : 0
    }

    // MARK: - Loop Detection

    private func detectLoop(samples: [Float]) -> Bool {
        guard samples.count > 4096 else { return false }

        // Compare start and end
        let compareLength = min(2048, samples.count / 4)
        let start = Array(samples.prefix(compareLength))
        let end = Array(samples.suffix(compareLength))

        // Cross-correlation
        var maxCorr: Float = 0
        for offset in -100...100 {
            var corr: Float = 0
            var count = 0

            for i in 0..<compareLength {
                let endIndex = i + offset
                if endIndex >= 0 && endIndex < compareLength {
                    corr += start[i] * end[endIndex]
                    count += 1
                }
            }

            if count > 0 {
                corr /= Float(count)
                maxCorr = max(maxCorr, abs(corr))
            }
        }

        // Normalize
        var startRMS: Float = 0
        var endRMS: Float = 0
        vDSP_rmsqv(start, 1, &startRMS, vDSP_Length(compareLength))
        vDSP_rmsqv(end, 1, &endRMS, vDSP_Length(compareLength))

        if startRMS > 0 && endRMS > 0 {
            maxCorr /= (startRMS * endRMS)
        }

        return maxCorr > 0.7
    }

    // MARK: - Audio Features

    struct AudioFeatures {
        var spectralCentroid: Float = 0
        var brightness: Float = 0
        var warmth: Float = 0
        var punchiness: Float = 0
        var rms: Float = 0
        var peak: Float = 0
        var energy: Float = 0
        var zeroCrossings: Float = 0
        var mfcc: [Float] = []
    }

    private func extractAudioFeatures(samples: [Float], sampleRate: Float) -> AudioFeatures {
        var features = AudioFeatures()

        // RMS and peak
        vDSP_rmsqv(samples, 1, &features.rms, vDSP_Length(samples.count))
        vDSP_maxmgv(samples, 1, &features.peak, vDSP_Length(samples.count))

        // Spectral centroid
        let spectrum = computeMagnitudeSpectrum(samples)
        var weightedSum: Float = 0
        var totalMag: Float = 0

        for i in 0..<spectrum.count {
            let freq = Float(i) * sampleRate / Float(spectrum.count * 2)
            weightedSum += freq * spectrum[i]
            totalMag += spectrum[i]
        }

        features.spectralCentroid = totalMag > 0 ? weightedSum / totalMag : 0

        // Brightness (high frequency energy ratio)
        let cutoffBin = Int(5000.0 / (sampleRate / Float(spectrum.count * 2)))
        var highEnergy: Float = 0
        var totalEnergy: Float = 0

        for i in 0..<spectrum.count {
            totalEnergy += spectrum[i] * spectrum[i]
            if i > cutoffBin {
                highEnergy += spectrum[i] * spectrum[i]
            }
        }

        features.brightness = totalEnergy > 0 ? highEnergy / totalEnergy : 0

        // Warmth (low frequency energy ratio)
        let lowCutoffBin = Int(500.0 / (sampleRate / Float(spectrum.count * 2)))
        var lowEnergy: Float = 0

        for i in 0..<min(lowCutoffBin, spectrum.count) {
            lowEnergy += spectrum[i] * spectrum[i]
        }

        features.warmth = totalEnergy > 0 ? lowEnergy / totalEnergy : 0

        // Punchiness (transient strength)
        features.punchiness = detectPunchiness(samples: samples)

        // Energy (normalized RMS)
        features.energy = min(1.0, features.rms * 3)  // Scale for typical audio

        // Zero crossings (texture indicator)
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        features.zeroCrossings = Float(crossings) / Float(samples.count) * sampleRate

        return features
    }

    private func detectPunchiness(samples: [Float]) -> Float {
        let windowSize = 512
        var maxAttack: Float = 0

        for i in stride(from: 0, to: min(samples.count - windowSize, 4410), by: 64) {  // First 100ms
            let window = Array(samples[i..<i+windowSize])

            // Calculate envelope slope
            var prevRMS: Float = 0
            vDSP_rmsqv(Array(window.prefix(64)), 1, &prevRMS, 64)

            var currRMS: Float = 0
            vDSP_rmsqv(Array(window.suffix(64)), 1, &currRMS, 64)

            let attack = currRMS - prevRMS
            maxAttack = max(maxAttack, attack)
        }

        return min(1.0, maxAttack * 10)
    }

    private func computeMagnitudeSpectrum(_ samples: [Float]) -> [Float] {
        let fftSize = samples.count
        guard fftSize > 0 && (fftSize & (fftSize - 1)) == 0 else {
            // Pad to power of 2
            let nextPow2 = 1 << Int(ceil(log2(Double(samples.count))))
            var padded = samples
            padded.append(contentsOf: [Float](repeating: 0, count: nextPow2 - samples.count))
            return computeMagnitudeSpectrum(padded)
        }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: fftSize / 2)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = samples
        var imag = [Float](repeating: 0, count: fftSize)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Magnitude
        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitude[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }

        return magnitude
    }

    // MARK: - Categorization

    private func categorize(metadata: SampleMetadata, features: AudioFeatures) -> SampleCategory {
        // Rule-based categorization based on audio features

        // Check filename first
        let lowercaseName = metadata.filename.lowercased()

        if lowercaseName.contains("kick") || lowercaseName.contains("bd") {
            return .drums
        }
        if lowercaseName.contains("snare") || lowercaseName.contains("sd") {
            return .drums
        }
        if lowercaseName.contains("hat") || lowercaseName.contains("hh") {
            return .drums
        }
        if lowercaseName.contains("bass") {
            return .bass
        }
        if lowercaseName.contains("synth") || lowercaseName.contains("lead") || lowercaseName.contains("pad") {
            return .synth
        }
        if lowercaseName.contains("vocal") || lowercaseName.contains("vox") {
            return .vocals
        }
        if lowercaseName.contains("fx") || lowercaseName.contains("riser") || lowercaseName.contains("impact") {
            return .fx
        }
        if lowercaseName.contains("loop") {
            return .loops
        }

        // Feature-based categorization
        if features.warmth > 0.6 && metadata.duration < 1.0 && features.punchiness > 0.5 {
            return .drums  // Likely a kick
        }

        if features.brightness > 0.5 && features.punchiness > 0.7 && metadata.duration < 0.5 {
            return .drums  // Likely a snare or hi-hat
        }

        if features.warmth > 0.7 && features.brightness < 0.3 {
            return .bass
        }

        if metadata.duration > 2.0 && metadata.isLoop {
            return .loops
        }

        if metadata.duration < 2.0 && !metadata.isLoop {
            return .oneShots
        }

        return .unknown
    }

    private func generateTags(metadata: SampleMetadata, features: AudioFeatures) -> Set<String> {
        var tags = Set<String>()

        // Texture tags
        if features.brightness > 0.6 { tags.insert("bright") }
        if features.brightness < 0.3 { tags.insert("dark") }
        if features.warmth > 0.6 { tags.insert("warm") }
        if features.punchiness > 0.7 { tags.insert("punchy") }
        if features.energy > 0.7 { tags.insert("energetic") }
        if features.energy < 0.3 { tags.insert("soft") }

        // Duration tags
        if metadata.duration < 0.2 { tags.insert("short") }
        if metadata.duration > 4.0 { tags.insert("long") }

        // Type tags
        if metadata.isLoop { tags.insert("loop") }
        if metadata.isOneShot { tags.insert("one-shot") }

        // BPM tags
        if let bpm = metadata.bpm {
            if bpm < 100 { tags.insert("slow") }
            else if bpm > 140 { tags.insert("fast") }

            // Genre-typical tempos
            if bpm >= 70 && bpm <= 90 { tags.insert("hip-hop-tempo") }
            if bpm >= 120 && bpm <= 130 { tags.insert("house-tempo") }
            if bpm >= 140 && bpm <= 150 { tags.insert("dubstep-tempo") }
            if bpm >= 170 && bpm <= 180 { tags.insert("dnb-tempo") }
        }

        // Key tags
        if let key = metadata.key {
            tags.insert(key.rawValue.contains("Minor") ? "minor" : "major")
        }

        return tags
    }

    private func detectMood(features: AudioFeatures) -> [String] {
        var moods: [String] = []

        if features.brightness > 0.6 && features.energy > 0.6 {
            moods.append("happy")
            moods.append("uplifting")
        }

        if features.brightness < 0.4 && features.warmth > 0.5 {
            moods.append("dark")
            moods.append("moody")
        }

        if features.energy < 0.3 {
            moods.append("chill")
            moods.append("ambient")
        }

        if features.energy > 0.8 && features.punchiness > 0.6 {
            moods.append("aggressive")
            moods.append("intense")
        }

        return moods
    }

    // MARK: - Embedding Generation

    private func generateEmbedding(features: AudioFeatures) -> [Float] {
        // 32-dimensional embedding for similarity search
        var embedding = [Float](repeating: 0, count: 32)

        embedding[0] = features.spectralCentroid / 10000  // Normalized
        embedding[1] = features.brightness
        embedding[2] = features.warmth
        embedding[3] = features.punchiness
        embedding[4] = features.rms
        embedding[5] = features.energy
        embedding[6] = features.zeroCrossings / 20000

        // Add some random but deterministic variation based on features
        for i in 7..<32 {
            let seed = features.spectralCentroid + Float(i) * features.brightness
            embedding[i] = sin(seed * Float(i)) * 0.5 + 0.5
        }

        return embedding
    }
}

// MARK: - Similarity Search

/// Fast similarity search using embeddings
public actor SimilaritySearch {

    private var embeddings: [(id: UUID, embedding: [Float])] = []

    public func index(samples: [SampleMetadata]) {
        embeddings = samples.compactMap { sample in
            guard let embedding = sample.embedding else { return nil }
            return (id: sample.id, embedding: embedding)
        }
    }

    public func findSimilar(to sample: SampleMetadata, limit: Int = 10) -> [UUID] {
        guard let queryEmbedding = sample.embedding else { return [] }

        let similarities = embeddings.map { (id, embedding) -> (UUID, Float) in
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            return (id, similarity)
        }

        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .filter { $0.0 != sample.id }
            .map { $0.0 }
    }

    public func findSimilar(toEmbedding embedding: [Float], limit: Int = 10) -> [UUID] {
        let similarities = embeddings.map { (id, emb) -> (UUID, Float) in
            let similarity = cosineSimilarity(embedding, emb)
            return (id, similarity)
        }

        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count && a.count > 0 else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dotProduct / denom : 0
    }
}

// MARK: - Sample Library Engine

/// Main AI-powered sample library engine
public actor AISampleLibraryEngine {

    public static let shared = AISampleLibraryEngine()

    private let analyzer = AudioAnalyzer()
    private let similaritySearch = SimilaritySearch()

    private var samples: [UUID: SampleMetadata] = [:]
    private var libraryPath: URL?

    // Search indexes
    private var categoryIndex: [SampleCategory: Set<UUID>] = [:]
    private var tagIndex: [String: Set<UUID>] = [:]
    private var bpmIndex: [Int: Set<UUID>] = [:]  // Rounded BPM
    private var keyIndex: [MusicalKey: Set<UUID>] = [:]

    private init() {}

    // MARK: - Library Management

    public func setLibraryPath(_ path: URL) {
        libraryPath = path
    }

    public func scanLibrary(progressHandler: ((Float, String) -> Void)? = nil) async throws {
        guard let path = libraryPath else { throw LibraryError.noLibraryPath }

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.isRegularFileKey])

        var audioFiles: [URL] = []
        let supportedExtensions = ["wav", "aif", "aiff", "mp3", "m4a", "flac", "ogg"]

        while let fileURL = enumerator?.nextObject() as? URL {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                audioFiles.append(fileURL)
            }
        }

        progressHandler?(0, "Found \(audioFiles.count) audio files")

        // Analyze files
        for (index, fileURL) in audioFiles.enumerated() {
            let progress = Float(index + 1) / Float(audioFiles.count)
            progressHandler?(progress, "Analyzing: \(fileURL.lastPathComponent)")

            do {
                let metadata = try await analyzer.analyze(url: fileURL)
                await addSample(metadata)
            } catch {
                print("Failed to analyze \(fileURL.lastPathComponent): \(error)")
            }
        }

        // Build similarity index
        await similaritySearch.index(samples: Array(samples.values))

        progressHandler?(1.0, "Scan complete: \(samples.count) samples indexed")
    }

    public func addSample(_ metadata: SampleMetadata) async {
        samples[metadata.id] = metadata

        // Update indexes
        categoryIndex[metadata.category, default: []].insert(metadata.id)

        for tag in metadata.tags {
            tagIndex[tag.lowercased(), default: []].insert(metadata.id)
        }

        if let bpm = metadata.bpm {
            let roundedBPM = Int(round(bpm))
            bpmIndex[roundedBPM, default: []].insert(metadata.id)
        }

        if let key = metadata.key {
            keyIndex[key, default: []].insert(metadata.id)
        }
    }

    public func getSample(id: UUID) -> SampleMetadata? {
        samples[id]
    }

    public func getAllSamples() -> [SampleMetadata] {
        Array(samples.values)
    }

    // MARK: - Search

    public func search(query: String) -> [SampleMetadata] {
        let lowercaseQuery = query.lowercased()
        var matchingIds = Set<UUID>()

        // Search by filename
        for (id, sample) in samples {
            if sample.filename.lowercased().contains(lowercaseQuery) {
                matchingIds.insert(id)
            }
        }

        // Search by tags
        for (tag, ids) in tagIndex {
            if tag.contains(lowercaseQuery) {
                matchingIds.formUnion(ids)
            }
        }

        // Search by category
        for category in SampleCategory.allCases {
            if category.rawValue.lowercased().contains(lowercaseQuery) {
                matchingIds.formUnion(categoryIndex[category] ?? [])
            }
        }

        return matchingIds.compactMap { samples[$0] }
    }

    public func searchByCategory(_ category: SampleCategory) -> [SampleMetadata] {
        let ids = categoryIndex[category] ?? []
        return ids.compactMap { samples[$0] }
    }

    public func searchByBPM(min: Float, max: Float) -> [SampleMetadata] {
        var matchingIds = Set<UUID>()

        for bpm in Int(min)...Int(max) {
            matchingIds.formUnion(bpmIndex[bpm] ?? [])
        }

        return matchingIds.compactMap { samples[$0] }
    }

    public func searchByKey(_ key: MusicalKey, includeCompatible: Bool = true) -> [SampleMetadata] {
        var matchingIds = keyIndex[key] ?? Set()

        if includeCompatible {
            for compatibleKey in key.compatibleKeys {
                matchingIds.formUnion(keyIndex[compatibleKey] ?? [])
            }
        }

        return matchingIds.compactMap { samples[$0] }
    }

    public func searchByTags(_ tags: [String]) -> [SampleMetadata] {
        guard !tags.isEmpty else { return [] }

        var matchingIds: Set<UUID>?

        for tag in tags {
            let tagIds = tagIndex[tag.lowercased()] ?? []

            if matchingIds == nil {
                matchingIds = tagIds
            } else {
                matchingIds = matchingIds?.intersection(tagIds)
            }
        }

        return (matchingIds ?? []).compactMap { samples[$0] }
    }

    // MARK: - Similarity

    public func findSimilar(to sampleId: UUID, limit: Int = 10) async -> [SampleMetadata] {
        guard let sample = samples[sampleId] else { return [] }

        let similarIds = await similaritySearch.findSimilar(to: sample, limit: limit)
        return similarIds.compactMap { samples[$0] }
    }

    // MARK: - Favorites & User Data

    public func toggleFavorite(id: UUID) {
        samples[id]?.isFavorite.toggle()
    }

    public func setRating(id: UUID, rating: Int) {
        samples[id]?.rating = max(0, min(5, rating))
    }

    public func addUserTag(id: UUID, tag: String) {
        samples[id]?.userTags.insert(tag)
        tagIndex[tag.lowercased(), default: []].insert(id)
    }

    public func recordUsage(id: UUID) {
        samples[id]?.useCount += 1
        samples[id]?.lastUsed = Date()
    }

    public func getFavorites() -> [SampleMetadata] {
        samples.values.filter { $0.isFavorite }
    }

    public func getRecentlyUsed(limit: Int = 20) -> [SampleMetadata] {
        samples.values
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    public func getMostUsed(limit: Int = 20) -> [SampleMetadata] {
        samples.values
            .sorted { $0.useCount > $1.useCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Persistence

    public func save() async throws {
        guard let path = libraryPath else { throw LibraryError.noLibraryPath }

        let indexURL = path.appendingPathComponent(".echoelmusic_index.json")
        let data = try JSONEncoder().encode(Array(samples.values))
        try data.write(to: indexURL)
    }

    public func load() async throws {
        guard let path = libraryPath else { throw LibraryError.noLibraryPath }

        let indexURL = path.appendingPathComponent(".echoelmusic_index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }

        let data = try Data(contentsOf: indexURL)
        let loadedSamples = try JSONDecoder().decode([SampleMetadata].self, from: data)

        for sample in loadedSamples {
            await addSample(sample)
        }

        await similaritySearch.index(samples: loadedSamples)
    }
}

// MARK: - Errors

public enum AnalyzerError: Error {
    case bufferCreationFailed
    case fileReadFailed
}

public enum LibraryError: Error {
    case noLibraryPath
    case saveFailed
    case loadFailed
}
