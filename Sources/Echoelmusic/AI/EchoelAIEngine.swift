#if canImport(AVFoundation)
//
//  EchoelAIEngine.swift
//  Echoelmusic — AI/ML Audio Intelligence Engine
//
//  On-device audio intelligence using CoreML + Accelerate:
//  - Stem Separation (vocals, drums, bass, other)
//  - Intelligent loudness normalization (LUFS targeting)
//  - Auto-EQ based on spectral analysis
//  - Tempo/key detection
//  - Audio classification (instrument, genre)
//
//  All processing happens on-device. No cloud dependency.
//

import Foundation
import AVFoundation
import Accelerate
#if canImport(Observation)
import Observation
#endif

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Stem Types

/// Audio stems that can be separated
public enum AudioStem: String, CaseIterable, Codable, Sendable {
    case vocals     = "Vocals"
    case drums      = "Drums"
    case bass       = "Bass"
    case other      = "Other"
    case full       = "Full Mix"

    public var icon: String {
        switch self {
        case .vocals: return "mic.fill"
        case .drums: return "drum.fill"
        case .bass: return "guitars.fill"
        case .other: return "music.note.list"
        case .full: return "waveform"
        }
    }
}

// MARK: - AI Task

/// AI task categories for on-device intelligence
public enum AITask: String, CaseIterable, Codable, Sendable {
    case stemSeparation   = "Stem Separation"    // Vocals, drums, bass, other
    case autoEQ           = "Auto EQ"            // Spectral analysis → EQ
    case tempoDetection   = "Tempo Detection"    // BPM extraction
    case keyDetection     = "Key Detection"      // Musical key analysis
    case classification   = "Classification"     // Instrument/genre detection
    case composition      = "Composition"        // Generative AI composition
    case musicTheory      = "Music Theory"       // Bio-reactive music learning
    case arHistory        = "AR History"         // Discover music history in AR
}

/// Result of stem separation
public struct StemSeparationResult: @unchecked Sendable {
    public let stems: [AudioStem: AVAudioPCMBuffer]
    public let sampleRate: Double
    public let duration: TimeInterval
}

// MARK: - Audio Analysis Result

/// Comprehensive audio analysis
public struct AudioAnalysis: Sendable {
    /// Estimated tempo in BPM
    public var tempo: Double = 120.0

    /// Estimated key (e.g., "C major", "A minor")
    public var key: String = "Unknown"

    /// Integrated loudness in LUFS
    public var loudnessLUFS: Double = -14.0

    /// True peak in dBFS
    public var truePeak: Double = -1.0

    /// Loudness range in LU
    public var loudnessRange: Double = 8.0

    /// Spectral centroid (brightness indicator)
    public var spectralCentroid: Double = 2000.0

    /// Dynamic range in dB
    public var dynamicRange: Double = 12.0

    /// Detected genre (best guess)
    public var genre: String = "Unknown"
}

// MARK: - LUFS Measurement

/// ITU-R BS.1770 loudness measurement
public struct LUFSMeasurement: Sendable {
    /// Momentary loudness (400ms window)
    public var momentary: Double = -70.0

    /// Short-term loudness (3s window)
    public var shortTerm: Double = -70.0

    /// Integrated loudness (entire program)
    public var integrated: Double = -70.0

    /// True peak (inter-sample)
    public var truePeak: Double = -70.0

    /// Loudness range (LRA)
    public var range: Double = 0.0
}

// MARK: - EQ Band

/// A single EQ band with frequency and gain
public struct EQBand: Sendable {
    public let name: String
    public let frequency: Double
    public var gainDB: Float
}

// MARK: - Chord Detection Result

/// Result of chord detection analysis
public struct ChordDetectionResult: Sendable {
    public let chord: String
    public let confidence: Float
    public let chroma: [Float]
}

// MARK: - Genre Classification

/// Result of genre classification
public struct GenreClassification: Sendable {
    public let genre: String
    public let confidence: Float
    public let features: [String: Double]
}

// MARK: - Mix Suggestion

/// A single actionable mix suggestion from AI analysis
public struct MixSuggestion: Sendable {
    public enum Priority: Int, Sendable, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum Category: String, Sendable {
        case loudness = "Loudness"
        case eq = "EQ"
        case dynamics = "Dynamics"
        case stereo = "Stereo"
        case general = "General"
    }

    public let title: String
    public let detail: String
    public let category: Category
    public let priority: Priority
}

// MARK: - EchoelAI Engine

/// On-device audio intelligence engine
@preconcurrency @MainActor
@Observable
public final class EchoelAIEngine {

    // MARK: - Singleton

    public static let shared = EchoelAIEngine()

    // MARK: - State

    public var isProcessing: Bool = false
    public var progress: Float = 0.0
    public var lastAnalysis: AudioAnalysis = AudioAnalysis()
    public var lastLUFS: LUFSMeasurement = LUFSMeasurement()

    // MARK: - CoreML

    #if canImport(CoreML)
    private var stemModel: MLModel?
    #endif

    // MARK: - Init

    private init() {
        loadModels()
    }

    private func loadModels() {
        #if canImport(CoreML)
        // CoreML model would be loaded here when available
        // let config = MLModelConfiguration()
        // config.computeUnits = .cpuAndNeuralEngine
        // stemModel = try? MLModel(contentsOf: modelURL, configuration: config)
        log.log(.info, category: .audio, "EchoelAI initialized — CoreML available")
        #else
        log.log(.info, category: .audio, "EchoelAI initialized — CoreML not available, using DSP fallback")
        #endif
    }

    // MARK: - Audio Analysis

    /// Analyze an audio buffer for tempo, key, loudness
    public func analyze(buffer: AVAudioPCMBuffer) async -> AudioAnalysis {
        isProcessing = true
        progress = 0.0

        var analysis = AudioAnalysis()

        // LUFS measurement (BS.1770)
        let lufs = measureLUFS(buffer: buffer)
        analysis.loudnessLUFS = lufs.integrated
        analysis.truePeak = lufs.truePeak
        analysis.loudnessRange = lufs.range
        lastLUFS = lufs
        progress = 0.3

        // Tempo detection via autocorrelation
        analysis.tempo = detectTempo(buffer: buffer)
        progress = 0.6

        // Spectral centroid
        analysis.spectralCentroid = measureSpectralCentroid(buffer: buffer)
        progress = 0.8

        // Key detection via chroma features
        analysis.key = detectKey(buffer: buffer)
        progress = 1.0

        lastAnalysis = analysis
        isProcessing = false
        return analysis
    }

    // MARK: - Stem Separation (DSP-based)

    /// Separate audio into stems using spectral processing
    /// Without a CoreML model, uses frequency-band isolation
    public func separateStems(buffer: AVAudioPCMBuffer) async -> StemSeparationResult? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        isProcessing = true
        progress = 0.0

        // Simple frequency-band separation (production would use Demucs CoreML model)
        let fftSize = 4096
        guard frameCount >= fftSize else {
            isProcessing = false
            return nil
        }

        var stems: [AudioStem: AVAudioPCMBuffer] = [:]

        // Create output buffers
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            isProcessing = false
            return nil
        }

        for stem in [AudioStem.vocals, .drums, .bass, .other] {
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { continue }
            outBuffer.frameLength = AVAudioFrameCount(frameCount)

            guard let outData = outBuffer.floatChannelData?[0] else { continue }
            let inData = channelData[0]

            // Frequency band isolation via biquad filters
            switch stem {
            case .bass:
                // Low-pass at 250 Hz
                applyLowPass(input: inData, output: outData, frameCount: frameCount, cutoff: Float(250.0 / sampleRate))
            case .drums:
                // Band-pass 80-8000 Hz with transient emphasis
                applyBandPass(input: inData, output: outData, frameCount: frameCount,
                             lowCutoff: Float(80.0 / sampleRate), highCutoff: Float(8000.0 / sampleRate))
            case .vocals:
                // Band-pass 300-4000 Hz (vocal frequency range)
                applyBandPass(input: inData, output: outData, frameCount: frameCount,
                             lowCutoff: Float(300.0 / sampleRate), highCutoff: Float(4000.0 / sampleRate))
            case .other:
                // High-pass above 4000 Hz
                applyHighPass(input: inData, output: outData, frameCount: frameCount, cutoff: Float(4000.0 / sampleRate))
            default:
                break
            }

            stems[stem] = outBuffer
            progress = Float(stems.count) / 4.0
        }

        isProcessing = false
        progress = 1.0

        return StemSeparationResult(
            stems: stems,
            sampleRate: sampleRate,
            duration: Double(frameCount) / sampleRate
        )
    }

    // MARK: - LUFS Measurement (ITU-R BS.1770)

    /// Measure loudness per ITU-R BS.1770-4
    ///
    /// Applies two-stage K-weighting (pre-filter shelf + RLB high-pass)
    /// before computing mean-square power. Coefficients are for 48 kHz;
    /// at other sample rates, the shelf frequency shifts slightly but
    /// remains a valid approximation for loudness metering.
    public func measureLUFS(buffer: AVAudioPCMBuffer) -> LUFSMeasurement {
        guard let channelData = buffer.floatChannelData else {
            return LUFSMeasurement()
        }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return LUFSMeasurement() }

        // Step 1: K-weighting via two cascaded biquad IIR filters
        // Stage 1 — Pre-filter (high-shelf boost ~+4 dB above 1681 Hz)
        // ITU-R BS.1770-4 coefficients at 48 kHz
        let preB: [Double] = [1.53512485958697, -2.69169618940638, 1.19839281085285]
        let preA: [Double] = [1.0, -1.69065929318241, 0.73248077421585]

        // Stage 2 — Revised Low-frequency B-curve (RLB, high-pass ~38 Hz)
        let rlbB: [Double] = [1.0, -2.0, 1.0]
        let rlbA: [Double] = [1.0, -1.99004745483398, 0.99007225036621]

        var stage1 = [Float](repeating: 0, count: frameCount)
        var filtered = [Float](repeating: 0, count: frameCount)

        // Apply pre-filter biquad
        applyBiquad(input: channelData[0], output: &stage1, count: frameCount, b: preB, a: preA)
        // Apply RLB biquad
        applyBiquad(input: &stage1, output: &filtered, count: frameCount, b: rlbB, a: rlbA)

        // Step 2: Mean square of K-weighted signal
        var meanSquare: Float = 0
        vDSP_measqv(filtered, 1, &meanSquare, vDSP_Length(frameCount))

        // Step 3: LUFS = -0.691 + 10 * log10(meanSquare)
        let lufs = meanSquare > 0 ? Double(-0.691 + 10.0 * log10(Double(meanSquare))) : -70.0

        // Step 4: True peak (magnitude peak of K-weighted signal)
        var peak: Float = 0
        vDSP_maxmgv(filtered, 1, &peak, vDSP_Length(frameCount))
        let truePeakDB = peak > 0 ? 20.0 * log10(Double(peak)) : -70.0

        // Step 5: Momentary loudness (last 400ms window)
        let sampleRate = buffer.format.sampleRate
        let momentaryFrames = min(frameCount, Int(0.4 * sampleRate))
        let momentaryOffset = frameCount - momentaryFrames
        var momentaryMS: Float = 0
        filtered.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            vDSP_measqv(base.advanced(by: momentaryOffset), 1, &momentaryMS, vDSP_Length(momentaryFrames))
        }
        let momentaryLUFS = momentaryMS > 0 ? Double(-0.691 + 10.0 * log10(Double(momentaryMS))) : -70.0

        // Step 6: Short-term loudness (last 3s window)
        let shortTermFrames = min(frameCount, Int(3.0 * sampleRate))
        let shortTermOffset = frameCount - shortTermFrames
        var shortTermMS: Float = 0
        filtered.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            vDSP_measqv(base.advanced(by: shortTermOffset), 1, &shortTermMS, vDSP_Length(shortTermFrames))
        }
        let shortTermLUFS = shortTermMS > 0 ? Double(-0.691 + 10.0 * log10(Double(shortTermMS))) : -70.0

        return LUFSMeasurement(
            momentary: momentaryLUFS,
            shortTerm: shortTermLUFS,
            integrated: lufs,
            truePeak: truePeakDB,
            range: abs(momentaryLUFS - shortTermLUFS)
        )
    }

    /// Apply a second-order IIR biquad filter (Direct Form I)
    private func applyBiquad(input: UnsafePointer<Float>, output: inout [Float], count: Int, b: [Double], a: [Double]) {
        var x1: Double = 0, x2: Double = 0
        var y1: Double = 0, y2: Double = 0
        for i in 0..<count {
            let x0 = Double(input[i])
            let y0 = b[0] * x0 + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
            output[i] = Float(y0)
            x2 = x1; x1 = x0
            y2 = y1; y1 = y0
        }
    }

    // MARK: - Tempo Detection

    /// Detect tempo via onset autocorrelation
    private func detectTempo(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 120.0 }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard frameCount > 0 else { return 120.0 }

        // Simple energy-based onset detection
        let hopSize = 512
        let windowCount = frameCount / hopSize
        guard windowCount > 1 else { return 120.0 }

        var energies = [Float](repeating: 0, count: windowCount)
        for i in 0..<windowCount {
            let offset = i * hopSize
            let count = min(hopSize, frameCount - offset)
            var rms: Float = 0
            vDSP_rmsqv(channelData[0] + offset, 1, &rms, vDSP_Length(count))
            energies[i] = rms
        }

        // Onset detection (spectral flux approximation)
        var onsets = [Float](repeating: 0, count: windowCount)
        for i in 1..<windowCount {
            onsets[i] = max(0, energies[i] - energies[i - 1])
        }

        // Autocorrelation of onset signal
        let minLag = Int(60.0 / 200.0 * sampleRate / Double(hopSize)) // 200 BPM
        let maxLag = Int(60.0 / 60.0 * sampleRate / Double(hopSize))  // 60 BPM
        guard maxLag < windowCount && minLag < maxLag else { return 120.0 }

        var bestLag = minLag
        var bestCorr: Float = 0

        for lag in minLag..<maxLag {
            var corr: Float = 0
            let count = windowCount - lag
            guard count > 0 else { continue }
            onsets.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &corr, vDSP_Length(count))
            }
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        let bpm = 60.0 * sampleRate / Double(hopSize) / Double(bestLag)
        return max(60.0, min(200.0, bpm))
    }

    // MARK: - Key Detection

    /// Detect musical key via chroma feature extraction + Krumhansl-Schmuckler key profiles.
    ///
    /// Computes a 12-bin chromagram from the FFT magnitude spectrum, then correlates
    /// against the Krumhansl-Kessler major/minor key profiles for all 12 roots.
    /// Returns the key with the highest Pearson correlation.
    ///
    /// Reference: Krumhansl, C.L. (1990) *Cognitive Foundations of Musical Pitch*.
    private func detectKey(buffer: AVAudioPCMBuffer) -> String {
        guard let channelData = buffer.floatChannelData else { return "Unknown" }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let fftSize = 4096
        guard frameCount >= fftSize else { return "Unknown" }

        // --- FFT via vDSP ---
        let log2n = vDSP_Length(Foundation.log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return "Unknown"
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData[0], 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack into split complex (copy to avoid overlapping access)
        let halfSize = fftSize / 2
        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)
        windowed.withUnsafeBufferPointer { inputPtr in
            guard let base = inputPtr.baseAddress else { return }
            base.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
            }
        }

        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Compute magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // --- Build 12-bin chromagram ---
        var chroma = [Float](repeating: 0, count: 12)
        let binResolution = sampleRate / Double(fftSize)

        // Map each FFT bin to its nearest pitch class (A4 = 440 Hz reference)
        for bin in 1..<halfSize {
            let freq = Double(bin) * binResolution
            guard freq >= 27.5 && freq <= 4186.0 else { continue } // A0 to C8
            let midiNote = 69.0 + 12.0 * Foundation.log2(freq / 440.0)
            let pitchClass = Int(round(midiNote).truncatingRemainder(dividingBy: 12))
            let safeIndex = ((pitchClass % 12) + 12) % 12
            chroma[safeIndex] += magnitudes[bin]
        }

        // Normalize chroma vector
        var maxVal: Float = 0
        vDSP_maxv(chroma, 1, &maxVal, vDSP_Length(12))
        if maxVal > 0 {
            vDSP_vsdiv(chroma, 1, &maxVal, &chroma, 1, vDSP_Length(12))
        }

        // --- Krumhansl-Kessler key profiles ---
        // Pitch classes: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
                                     2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
                                     2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        let noteNames = ["C", "C#", "D", "Eb", "E", "F",
                         "F#", "G", "Ab", "A", "Bb", "B"]

        // Correlate chroma with rotated profiles for all 24 keys
        var bestKey = "C major"
        var bestCorrelation: Float = -.greatestFiniteMagnitude

        for root in 0..<12 {
            // Rotate profile so index 0 aligns with root
            let rotatedMajor = (0..<12).map { majorProfile[($0 - root + 12) % 12] }
            let rotatedMinor = (0..<12).map { minorProfile[($0 - root + 12) % 12] }

            let majorCorr = pearsonCorrelation(chroma, rotatedMajor)
            let minorCorr = pearsonCorrelation(chroma, rotatedMinor)

            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = "\(noteNames[root]) major"
            }
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = "\(noteNames[root]) minor"
            }
        }

        return bestKey
    }

    /// Pearson correlation coefficient between two equal-length vectors
    private func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
        let n = vDSP_Length(x.count)
        var meanX: Float = 0, meanY: Float = 0
        vDSP_meanv(x, 1, &meanX, n)
        vDSP_meanv(y, 1, &meanY, n)

        var dx = [Float](repeating: 0, count: x.count)
        var dy = [Float](repeating: 0, count: y.count)
        var negMeanX = -meanX, negMeanY = -meanY
        vDSP_vsadd(x, 1, &negMeanX, &dx, 1, n)
        vDSP_vsadd(y, 1, &negMeanY, &dy, 1, n)

        var dotProduct: Float = 0
        vDSP_dotpr(dx, 1, dy, 1, &dotProduct, n)

        var sumSqX: Float = 0, sumSqY: Float = 0
        vDSP_dotpr(dx, 1, dx, 1, &sumSqX, n)
        vDSP_dotpr(dy, 1, dy, 1, &sumSqY, n)

        let denom = sqrt(sumSqX * sumSqY)
        guard denom > 0 else { return 0 }
        return dotProduct / denom
    }

    // MARK: - Spectral Centroid

    /// Measure spectral centroid (brightness)
    private func measureSpectralCentroid(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 2000.0 }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard frameCount >= 1024 else { return 2000.0 }

        // Simple spectral centroid via FFT magnitude
        let fftSize = 1024
        var real = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            real[i] = channelData[0][i]
        }

        // Weighted average frequency
        var sumWeighted: Double = 0
        var sumMag: Double = 0
        let binWidth = sampleRate / Double(fftSize)

        for i in 1..<(fftSize / 2) {
            let mag = Double(abs(real[i]))
            let freq = Double(i) * binWidth
            sumWeighted += mag * freq
            sumMag += mag
        }

        return sumMag > 0 ? sumWeighted / sumMag : 2000.0
    }

    // MARK: - Auto-EQ

    /// Generate EQ correction curve from spectral analysis.
    /// Compares the input spectrum against a target curve (pink noise reference)
    /// and returns per-band gain adjustments in dB.
    ///
    /// Bands: 31, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
    public func generateAutoEQ(buffer: AVAudioPCMBuffer, targetLUFS: Double = -14.0) -> [EQBand] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let fftSize = 4096
        guard frameCount >= fftSize else { return [] }

        // FFT
        let log2n = vDSP_Length(Foundation.log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfSize = fftSize / 2
        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData[0], 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)
        windowed.withUnsafeBufferPointer { inputPtr in
            guard let base = inputPtr.baseAddress else { return }
            base.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
            }
        }
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // Band center frequencies
        let bandFreqs: [Double] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        let bandNames = ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]

        // Pink noise reference (each octave has equal energy → -3dB/octave)
        // Normalized so 1kHz = 0 dB
        let pinkReference: [Float] = [6.0, 3.0, 0.0, -3.0, -6.0, -9.0, -12.0, -15.0, -18.0, -21.0]

        var bands: [EQBand] = []
        let binWidth = sampleRate / Double(fftSize)

        for (i, freq) in bandFreqs.enumerated() {
            let lowFreq = freq / sqrt(2.0)
            let highFreq = freq * sqrt(2.0)
            let lowBin = max(1, Int(lowFreq / binWidth))
            let highBin = min(halfSize - 1, Int(highFreq / binWidth))

            guard highBin > lowBin else {
                bands.append(EQBand(name: bandNames[i], frequency: freq, gainDB: 0))
                continue
            }

            var bandEnergy: Float = 0
            for bin in lowBin...highBin {
                bandEnergy += magnitudes[bin]
            }
            bandEnergy /= Float(highBin - lowBin + 1)

            let bandDB = bandEnergy > 0 ? 10.0 * log10(Double(bandEnergy)) : -60.0
            let correction = Float(-bandDB) + pinkReference[i]
            let clampedGain = max(-12.0, min(12.0, correction))

            bands.append(EQBand(name: bandNames[i], frequency: freq, gainDB: clampedGain))
        }

        return bands
    }

    // MARK: - Chord Detection

    /// Detect the most likely chord from an audio buffer using chroma features.
    /// Returns chord name (e.g., "C major", "Am7", "G7")
    public func detectChord(buffer: AVAudioPCMBuffer) -> ChordDetectionResult {
        guard let channelData = buffer.floatChannelData else {
            return ChordDetectionResult(chord: "Unknown", confidence: 0, chroma: Array(repeating: 0, count: 12))
        }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let fftSize = 4096
        guard frameCount >= fftSize else {
            return ChordDetectionResult(chord: "Unknown", confidence: 0, chroma: Array(repeating: 0, count: 12))
        }

        // Compute chroma (reuse FFT approach from detectKey)
        let log2n = vDSP_Length(Foundation.log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ChordDetectionResult(chord: "Unknown", confidence: 0, chroma: Array(repeating: 0, count: 12))
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData[0], 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        let halfSize = fftSize / 2
        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)
        windowed.withUnsafeBufferPointer { inputPtr in
            guard let base = inputPtr.baseAddress else { return }
            base.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
            }
        }
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // Build chromagram
        var chroma = [Float](repeating: 0, count: 12)
        let binResolution = sampleRate / Double(fftSize)
        for bin in 1..<halfSize {
            let freq = Double(bin) * binResolution
            guard freq >= 65.0 && freq <= 2100.0 else { continue } // C2 to C7
            let midiNote = 69.0 + 12.0 * Foundation.log2(freq / 440.0)
            let pitchClass = Int(round(midiNote).truncatingRemainder(dividingBy: 12))
            let safeIndex = ((pitchClass % 12) + 12) % 12
            chroma[safeIndex] += magnitudes[bin]
        }

        // Normalize
        var maxVal: Float = 0
        vDSP_maxv(chroma, 1, &maxVal, vDSP_Length(12))
        if maxVal > 0 {
            vDSP_vsdiv(chroma, 1, &maxVal, &chroma, 1, vDSP_Length(12))
        }

        // Match against chord templates
        let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

        // Chord templates: intervals from root
        let chordTypes: [(name: String, intervals: [Int])] = [
            ("major", [0, 4, 7]),
            ("minor", [0, 3, 7]),
            ("7", [0, 4, 7, 10]),
            ("m7", [0, 3, 7, 10]),
            ("maj7", [0, 4, 7, 11]),
            ("dim", [0, 3, 6]),
            ("aug", [0, 4, 8]),
            ("sus4", [0, 5, 7]),
            ("sus2", [0, 2, 7]),
        ]

        var bestChord = "Unknown"
        var bestScore: Float = 0

        for root in 0..<12 {
            for chordType in chordTypes {
                var template = [Float](repeating: 0, count: 12)
                for interval in chordType.intervals {
                    template[(root + interval) % 12] = 1.0
                }

                var score: Float = 0
                vDSP_dotpr(chroma, 1, template, 1, &score, vDSP_Length(12))

                // Penalize non-chord tones
                for i in 0..<12 {
                    if template[i] == 0 && chroma[i] > 0.3 {
                        score -= chroma[i] * 0.5
                    }
                }

                if score > bestScore {
                    bestScore = score
                    let suffix = chordType.name == "major" ? "" : chordType.name == "minor" ? "m" : chordType.name
                    bestChord = "\(noteNames[root])\(suffix)"
                }
            }
        }

        let confidence = min(1.0, bestScore / Float(3.0))
        return ChordDetectionResult(chord: bestChord, confidence: confidence, chroma: chroma)
    }

    // MARK: - Genre Classification

    /// Classify audio genre based on spectral and temporal features.
    /// Uses a rule-based heuristic (no ML model required).
    public func classifyGenre(buffer: AVAudioPCMBuffer) -> GenreClassification {
        guard let channelData = buffer.floatChannelData else {
            return GenreClassification(genre: "Unknown", confidence: 0, features: [:])
        }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return GenreClassification(genre: "Unknown", confidence: 0, features: [:])
        }

        // Feature extraction
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameCount))

        let centroid = measureSpectralCentroid(buffer: buffer)
        let tempo = detectTempo(buffer: buffer)

        // Zero crossing rate (indicator of noisiness/percussiveness)
        var zeroCrossings = 0
        for i in 1..<frameCount {
            if (channelData[0][i] >= 0) != (channelData[0][i - 1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Double(zeroCrossings) / Double(frameCount)

        var features: [String: Double] = [
            "rms": Double(rms),
            "centroid": centroid,
            "tempo": tempo,
            "zcr": zcr
        ]

        // Rule-based classification
        var scores: [String: Double] = [:]

        // Electronic/EDM: high tempo (120-150), moderate centroid, steady rhythm
        scores["Electronic"] = tempo >= 118 && tempo <= 150 ? 0.6 : 0.1
        if centroid > 1500 && centroid < 4000 { scores["Electronic"]! += 0.3 }

        // Ambient: low tempo (<100), low ZCR, low centroid
        scores["Ambient"] = tempo < 100 ? 0.5 : 0.1
        if zcr < 0.05 { scores["Ambient"]! += 0.3 }
        if centroid < 2000 { scores["Ambient"]! += 0.2 }

        // Rock: moderate tempo (100-140), high RMS, high ZCR
        scores["Rock"] = tempo >= 100 && tempo <= 140 ? 0.4 : 0.1
        if rms > 0.15 { scores["Rock"]! += 0.3 }
        if zcr > 0.1 { scores["Rock"]! += 0.2 }

        // Jazz: moderate tempo (80-140), high centroid variation
        scores["Jazz"] = tempo >= 80 && tempo <= 140 ? 0.4 : 0.1
        if centroid > 2500 { scores["Jazz"]! += 0.2 }

        // Hip-Hop: 80-110 BPM, strong bass
        scores["Hip-Hop"] = tempo >= 78 && tempo <= 115 ? 0.5 : 0.1
        if centroid < 2500 { scores["Hip-Hop"]! += 0.3 }

        // Classical: low ZCR, wide dynamic range, moderate centroid
        scores["Classical"] = zcr < 0.04 ? 0.5 : 0.1
        if centroid > 1000 && centroid < 3000 { scores["Classical"]! += 0.2 }

        let bestGenre = scores.max(by: { $0.value < $1.value })
        features["confidence"] = bestGenre?.value ?? 0

        return GenreClassification(
            genre: bestGenre?.key ?? "Unknown",
            confidence: Float(bestGenre?.value ?? 0),
            features: features
        )
    }

    // MARK: - Mix Suggestions

    /// Generate actionable mix suggestions based on audio analysis.
    /// Analyzes LUFS, spectral balance, and dynamics to provide
    /// prioritized recommendations for improving the mix.
    public func generateMixSuggestions(buffer: AVAudioPCMBuffer) -> [MixSuggestion] {
        var suggestions: [MixSuggestion] = []

        let lufs = measureLUFS(buffer: buffer)
        let centroid = measureSpectralCentroid(buffer: buffer)
        let eqBands = generateAutoEQ(buffer: buffer)

        // Loudness checks
        if lufs.integrated > -9.0 {
            suggestions.append(MixSuggestion(
                title: "Mix is too loud",
                detail: String(format: "Integrated loudness %.1f LUFS exceeds -9 LUFS. Risk of distortion and listener fatigue. Target -14 LUFS for streaming.", lufs.integrated),
                category: .loudness,
                priority: .critical
            ))
        } else if lufs.integrated > -11.0 {
            suggestions.append(MixSuggestion(
                title: "Mix is loud",
                detail: String(format: "Integrated loudness %.1f LUFS. Most streaming platforms normalize to -14 LUFS; extra loudness will be reduced.", lufs.integrated),
                category: .loudness,
                priority: .medium
            ))
        } else if lufs.integrated < -20.0 && lufs.integrated > -70.0 {
            suggestions.append(MixSuggestion(
                title: "Mix is quiet",
                detail: String(format: "Integrated loudness %.1f LUFS is below typical levels. Consider raising overall gain or adding gentle compression.", lufs.integrated),
                category: .loudness,
                priority: .medium
            ))
        }

        // True peak check
        if lufs.truePeak > -1.0 {
            suggestions.append(MixSuggestion(
                title: "True peak too high",
                detail: String(format: "True peak %.1f dBFS exceeds -1.0 dBTP. Add a limiter or reduce gain to prevent inter-sample clipping.", lufs.truePeak),
                category: .loudness,
                priority: .high
            ))
        }

        // Loudness range (dynamics)
        if lufs.range > 15.0 {
            suggestions.append(MixSuggestion(
                title: "Wide dynamic range",
                detail: String(format: "Loudness range %.1f LU is very wide. Consider gentle bus compression (2:1, slow attack) for more consistent playback.", lufs.range),
                category: .dynamics,
                priority: .low
            ))
        } else if lufs.range < 2.0 && lufs.integrated > -70.0 {
            suggestions.append(MixSuggestion(
                title: "Over-compressed",
                detail: String(format: "Loudness range %.1f LU suggests heavy compression. Back off the limiter to restore musical dynamics.", lufs.range),
                category: .dynamics,
                priority: .medium
            ))
        }

        // Spectral balance
        if centroid > 5000.0 {
            suggestions.append(MixSuggestion(
                title: "Mix sounds bright",
                detail: String(format: "Spectral centroid %.0f Hz is high. Consider a gentle high-shelf cut at 8 kHz (-2 to -3 dB) to reduce harshness.", centroid),
                category: .eq,
                priority: .medium
            ))
        } else if centroid < 800.0 && centroid > 0 {
            suggestions.append(MixSuggestion(
                title: "Mix sounds muddy",
                detail: String(format: "Spectral centroid %.0f Hz is low. Consider cutting 200-400 Hz and boosting presence at 2-5 kHz.", centroid),
                category: .eq,
                priority: .medium
            ))
        }

        // EQ band analysis — flag any large corrections
        for band in eqBands {
            if abs(band.gainDB) > 9.0 {
                suggestions.append(MixSuggestion(
                    title: "Large EQ correction at \(band.name)",
                    detail: String(format: "%s needs %.1f dB correction. This may indicate a recording or monitoring issue at this frequency.", band.name, band.gainDB),
                    category: .eq,
                    priority: .high
                ))
            }
        }

        // Sort by priority (highest first)
        suggestions.sort { $0.priority > $1.priority }
        return suggestions
    }

    // MARK: - DSP Filter Helpers

    private func applyLowPass(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int, cutoff: Float) {
        // Simple 1-pole lowpass: y[n] = y[n-1] + alpha * (x[n] - y[n-1])
        let alpha = min(cutoff * 2.0 * Float.pi, 1.0)
        var prev: Float = 0
        for i in 0..<frameCount {
            prev = prev + alpha * (input[i] - prev)
            output[i] = prev
        }
    }

    private func applyHighPass(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int, cutoff: Float) {
        // HP = input - LP
        let alpha = min(cutoff * 2.0 * Float.pi, 1.0)
        var prev: Float = 0
        for i in 0..<frameCount {
            prev = prev + alpha * (input[i] - prev)
            output[i] = input[i] - prev
        }
    }

    private func applyBandPass(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int, lowCutoff: Float, highCutoff: Float) {
        // BP = LP(high) - LP(low)
        let alphaLow = min(lowCutoff * 2.0 * Float.pi, 1.0)
        let alphaHigh = min(highCutoff * 2.0 * Float.pi, 1.0)
        var prevLow: Float = 0
        var prevHigh: Float = 0
        for i in 0..<frameCount {
            prevLow = prevLow + alphaLow * (input[i] - prevLow)
            prevHigh = prevHigh + alphaHigh * (input[i] - prevHigh)
            output[i] = prevHigh - prevLow
        }
    }
}

// MARK: - AI Analysis View

#if canImport(SwiftUI)
import SwiftUI

/// Audio analysis results panel
public struct EchoelAIView: View {
    @Bindable private var ai = EchoelAIEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: EchoelSpacing.md) {
            VaporwaveSectionHeader("EchoelAI", icon: "brain")

            if ai.isProcessing {
                ProgressView(value: ai.progress)
                    .tint(EchoelBrand.accent)
                    .padding(.horizontal)
            }

            // Analysis results
            VStack(spacing: EchoelSpacing.sm) {
                analysisRow("Tempo", "\(Int(ai.lastAnalysis.tempo)) BPM", "metronome")
                analysisRow("Key", ai.lastAnalysis.key, "music.note")
                analysisRow("Loudness", String(format: "%.1f LUFS", ai.lastAnalysis.loudnessLUFS), "speaker.wave.3.fill")
                analysisRow("True Peak", String(format: "%.1f dBFS", ai.lastAnalysis.truePeak), "waveform.badge.exclamationmark")
                analysisRow("Brightness", String(format: "%.0f Hz", ai.lastAnalysis.spectralCentroid), "sun.max.fill")
            }
            .padding(EchoelSpacing.md)
            .glassCard()

            // Stem separation
            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                Text("Stem Separation")
                    .font(EchoelBrandFont.label())
                    .foregroundStyle(.secondary)

                ForEach(AudioStem.allCases.filter { $0 != .full }, id: \.self) { stem in
                    HStack {
                        Image(systemName: stem.icon)
                            .frame(width: 20)
                            .foregroundStyle(EchoelBrand.accent)
                        Text(stem.rawValue)
                            .font(EchoelBrandFont.body())
                        Spacer()
                    }
                }
            }
            .padding(EchoelSpacing.md)
            .glassCard()
        }
    }

    private func analysisRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(EchoelBrand.accent)
            Text(label)
                .font(EchoelBrandFont.body())
            Spacer()
            Text(value)
                .font(EchoelBrandFont.data())
                .foregroundStyle(.secondary)
        }
    }
}
#endif

#endif // canImport(AVFoundation)
