// PodcastStudioEngine.swift
// Echoelmusic - Professional Podcast & Voice Studio
// Created by Claude (Phase 4) - December 2025

import Foundation
import Accelerate
import AVFoundation
import Speech
import NaturalLanguage

// MARK: - Noise Profiles

/// Pre-defined noise profiles for removal
public enum NoiseProfile: String, CaseIterable, Codable {
    case roomTone = "Room Tone"
    case airConditioning = "Air Conditioning"
    case computerFan = "Computer Fan"
    case traffic = "Traffic"
    case hum50Hz = "50Hz Hum (EU)"
    case hum60Hz = "60Hz Hum (US)"
    case wind = "Wind"
    case keyboard = "Keyboard Clicks"
    case custom = "Custom (Learn)"

    var spectralShape: [Float] {
        switch self {
        case .roomTone:
            // Broadband low-frequency noise
            return generateNoiseProfile(lowCutoff: 20, highCutoff: 500, slope: -6)
        case .airConditioning:
            // Low frequency rumble with harmonics
            return generateNoiseProfile(lowCutoff: 50, highCutoff: 800, slope: -12)
        case .computerFan:
            // Mid-frequency with narrow peaks
            return generateNoiseProfile(lowCutoff: 200, highCutoff: 2000, slope: -6)
        case .traffic:
            // Low-mid broadband
            return generateNoiseProfile(lowCutoff: 30, highCutoff: 1500, slope: -9)
        case .hum50Hz:
            // 50Hz and harmonics
            return generateHumProfile(fundamental: 50, harmonics: 8)
        case .hum60Hz:
            // 60Hz and harmonics
            return generateHumProfile(fundamental: 60, harmonics: 8)
        case .wind:
            // Very low frequency
            return generateNoiseProfile(lowCutoff: 10, highCutoff: 300, slope: -18)
        case .keyboard:
            // Transient mid-high frequency
            return generateNoiseProfile(lowCutoff: 1000, highCutoff: 8000, slope: -3)
        case .custom:
            return [Float](repeating: 0, count: 2048)
        }
    }

    private func generateNoiseProfile(lowCutoff: Float, highCutoff: Float, slope: Float) -> [Float] {
        var profile = [Float](repeating: 0, count: 2048)
        let nyquist: Float = 24000

        for i in 0..<2048 {
            let freq = Float(i) * nyquist / 2048
            if freq >= lowCutoff && freq <= highCutoff {
                let normalizedFreq = (freq - lowCutoff) / (highCutoff - lowCutoff)
                profile[i] = 1.0 - normalizedFreq * abs(slope) / 20
            }
        }

        return profile
    }

    private func generateHumProfile(fundamental: Float, harmonics: Int) -> [Float] {
        var profile = [Float](repeating: 0, count: 2048)
        let nyquist: Float = 24000
        let binWidth = nyquist / 2048

        for h in 1...harmonics {
            let freq = fundamental * Float(h)
            let bin = Int(freq / binWidth)

            if bin < 2048 {
                // Narrow peak with some spread
                for offset in -2...2 {
                    let targetBin = bin + offset
                    if targetBin >= 0 && targetBin < 2048 {
                        let attenuation = 1.0 - Float(abs(offset)) * 0.3
                        profile[targetBin] = max(profile[targetBin], attenuation / Float(h))
                    }
                }
            }
        }

        return profile
    }
}

// MARK: - Spectral Noise Gate

/// FFT-based spectral noise reduction
public final class SpectralNoiseGate: @unchecked Sendable {

    private let fftSize = 4096
    private let hopSize = 1024

    private var noiseFloor: [Float]
    private var prevPhase: [Float]
    private var prevMagnitude: [Float]

    // Settings
    public var threshold: Float = 1.5  // Multiplier above noise floor
    public var reduction: Float = 0.8  // 0-1, amount of reduction
    public var attack: Float = 0.1     // Smoothing
    public var release: Float = 0.3

    // FFT setup
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length

    public init() {
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        noiseFloor = [Float](repeating: 0, count: fftSize / 2)
        prevPhase = [Float](repeating: 0, count: fftSize / 2)
        prevMagnitude = [Float](repeating: 0, count: fftSize / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Learn noise profile from silent section
    public func learnNoiseProfile(from samples: [Float]) {
        guard samples.count >= fftSize else { return }

        var avgSpectrum = [Float](repeating: 0, count: fftSize / 2)
        var frameCount = 0

        // Average multiple frames
        for i in stride(from: 0, to: samples.count - fftSize, by: hopSize) {
            let frame = Array(samples[i..<i+fftSize])
            let spectrum = computeMagnitudeSpectrum(frame)

            for j in 0..<fftSize / 2 {
                avgSpectrum[j] += spectrum[j]
            }
            frameCount += 1
        }

        if frameCount > 0 {
            for j in 0..<fftSize / 2 {
                noiseFloor[j] = avgSpectrum[j] / Float(frameCount)
            }
        }
    }

    /// Set noise profile from preset
    public func setNoiseProfile(_ profile: NoiseProfile) {
        let shape = profile.spectralShape
        let scale: Float = 0.01  // Typical noise level

        for i in 0..<min(shape.count, fftSize / 2) {
            noiseFloor[i] = shape[i] * scale
        }
    }

    /// Process audio with spectral noise reduction
    public func process(samples: inout [Float]) {
        guard samples.count >= fftSize else { return }

        var output = [Float](repeating: 0, count: samples.count)
        var window = [Float](repeating: 0, count: fftSize)

        // Hann window
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Overlap-add processing
        var overlapBuffer = [Float](repeating: 0, count: samples.count + fftSize)

        for frameStart in stride(from: 0, to: samples.count - fftSize, by: hopSize) {
            // Extract and window frame
            var frame = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                frame[i] = samples[frameStart + i] * window[i]
            }

            // FFT
            var real = frame
            var imag = [Float](repeating: 0, count: fftSize)

            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }

            // Convert to magnitude/phase
            var magnitude = [Float](repeating: 0, count: fftSize / 2)
            var phase = [Float](repeating: 0, count: fftSize / 2)

            for i in 0..<fftSize / 2 {
                magnitude[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
                phase[i] = atan2(imag[i], real[i])
            }

            // Apply spectral gating
            for i in 0..<fftSize / 2 {
                let noiseThreshold = noiseFloor[i] * threshold

                if magnitude[i] < noiseThreshold {
                    // Below threshold - reduce
                    let reductionAmount = reduction * (1.0 - magnitude[i] / noiseThreshold)
                    magnitude[i] *= (1.0 - reductionAmount)
                }

                // Smooth with previous frame
                magnitude[i] = prevMagnitude[i] * release + magnitude[i] * (1 - release)
                prevMagnitude[i] = magnitude[i]
            }

            // Convert back to complex
            for i in 0..<fftSize / 2 {
                real[i] = magnitude[i] * cos(phase[i])
                imag[i] = magnitude[i] * sin(phase[i])
            }

            // Mirror for negative frequencies
            for i in fftSize/2..<fftSize {
                real[i] = real[fftSize - i]
                imag[i] = -imag[fftSize - i]
            }

            // IFFT
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
                }
            }

            // Scale and window
            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(fftSize))

            for i in 0..<fftSize {
                real[i] *= window[i]
            }

            // Overlap-add
            for i in 0..<fftSize {
                overlapBuffer[frameStart + i] += real[i]
            }
        }

        // Normalize overlap
        var hopScale = Float(fftSize) / Float(hopSize) / 2
        vDSP_vsdiv(overlapBuffer, 1, &hopScale, &overlapBuffer, 1, vDSP_Length(samples.count))

        // Copy to output
        for i in 0..<samples.count {
            samples[i] = overlapBuffer[i]
        }
    }

    private func computeMagnitudeSpectrum(_ frame: [Float]) -> [Float] {
        var real = frame
        var imag = [Float](repeating: 0, count: fftSize)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitude[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }

        return magnitude
    }
}

// MARK: - Voice Enhancer

/// Enhances voice clarity and presence
public final class VoiceEnhancer: @unchecked Sendable {

    // EQ settings
    public var lowCut: Float = 80        // Hz
    public var presence: Float = 0.3      // 0-1, boost around 3-5kHz
    public var warmth: Float = 0.2        // 0-1, boost around 200-400Hz
    public var airiness: Float = 0.1      // 0-1, boost above 10kHz
    public var deEsser: Float = 0.5       // 0-1, sibilance reduction

    // Dynamics
    public var compression: Float = 0.3   // 0-1
    public var gating: Float = 0.2        // 0-1

    private let sampleRate: Float
    private var filterStates: [[Float]] = []

    // De-esser
    private var deEsserEnvelope: Float = 0

    // Compressor state
    private var compEnvelope: Float = 0
    private var gainReduction: Float = 0

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
        resetFilters()
    }

    private func resetFilters() {
        filterStates = [[Float]](repeating: [Float](repeating: 0, count: 4), count: 6)
    }

    public func process(samples: inout [Float]) {
        // High-pass filter (low cut)
        applyHighPass(samples: &samples, cutoff: lowCut, state: &filterStates[0])

        // Warmth (low-mid boost)
        if warmth > 0 {
            applyPeakEQ(samples: &samples, frequency: 300, q: 1.0, gainDB: warmth * 6, state: &filterStates[1])
        }

        // Presence (upper-mid boost)
        if presence > 0 {
            applyPeakEQ(samples: &samples, frequency: 4000, q: 1.5, gainDB: presence * 8, state: &filterStates[2])
        }

        // Airiness (high shelf)
        if airiness > 0 {
            applyHighShelf(samples: &samples, cutoff: 10000, gainDB: airiness * 6, state: &filterStates[3])
        }

        // De-esser
        if deEsser > 0 {
            applyDeEsser(samples: &samples)
        }

        // Compression
        if compression > 0 {
            applyCompression(samples: &samples)
        }

        // Noise gate
        if gating > 0 {
            applyGate(samples: &samples)
        }
    }

    private func applyHighPass(samples: inout [Float], cutoff: Float, state: inout [Float]) {
        let omega = 2 * Float.pi * cutoff / sampleRate
        let alpha = sin(omega) / (2 * 0.707)

        let a0 = 1 + alpha
        let b0 = ((1 + cos(omega)) / 2) / a0
        let b1 = (-(1 + cos(omega))) / a0
        let b2 = ((1 + cos(omega)) / 2) / a0
        let a1 = (-2 * cos(omega)) / a0
        let a2 = (1 - alpha) / a0

        for i in 0..<samples.count {
            let input = samples[i]
            let output = b0 * input + state[0]
            state[0] = b1 * input - a1 * output + state[1]
            state[1] = b2 * input - a2 * output
            samples[i] = output
        }
    }

    private func applyPeakEQ(samples: inout [Float], frequency: Float, q: Float, gainDB: Float, state: inout [Float]) {
        let a = pow(10, gainDB / 40)
        let omega = 2 * Float.pi * frequency / sampleRate
        let alpha = sin(omega) / (2 * q)

        let a0 = 1 + alpha / a
        let b0 = (1 + alpha * a) / a0
        let b1 = (-2 * cos(omega)) / a0
        let b2 = (1 - alpha * a) / a0
        let a1 = b1
        let a2 = (1 - alpha / a) / a0

        for i in 0..<samples.count {
            let input = samples[i]
            let output = b0 * input + state[0]
            state[0] = b1 * input - a1 * output + state[1]
            state[1] = b2 * input - a2 * output
            samples[i] = output
        }
    }

    private func applyHighShelf(samples: inout [Float], cutoff: Float, gainDB: Float, state: inout [Float]) {
        let a = pow(10, gainDB / 40)
        let omega = 2 * Float.pi * cutoff / sampleRate
        let cosOmega = cos(omega)
        let alpha = sin(omega) / 2 * sqrt(2)

        let a0 = (a + 1) - (a - 1) * cosOmega + 2 * sqrt(a) * alpha
        let b0 = (a * ((a + 1) + (a - 1) * cosOmega + 2 * sqrt(a) * alpha)) / a0
        let b1 = (-2 * a * ((a - 1) + (a + 1) * cosOmega)) / a0
        let b2 = (a * ((a + 1) + (a - 1) * cosOmega - 2 * sqrt(a) * alpha)) / a0
        let a1 = (2 * ((a - 1) - (a + 1) * cosOmega)) / a0
        let a2 = ((a + 1) - (a - 1) * cosOmega - 2 * sqrt(a) * alpha) / a0

        for i in 0..<samples.count {
            let input = samples[i]
            let output = b0 * input + state[0]
            state[0] = b1 * input - a1 * output + state[1]
            state[1] = b2 * input - a2 * output
            samples[i] = output
        }
    }

    private func applyDeEsser(samples: inout [Float]) {
        // Simple sibilance detection and reduction
        let attackTime: Float = 0.001
        let releaseTime: Float = 0.05
        let attackCoeff = exp(-1.0 / (sampleRate * attackTime))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseTime))

        // Bandpass filter state for sibilance detection (4-9 kHz)
        var bpState: [Float] = [0, 0, 0, 0]

        for i in 0..<samples.count {
            // Detect sibilance energy
            let input = samples[i]

            // Simple bandpass approximation
            let sibilance = abs(input) * (1 - abs(input - bpState[0]))
            bpState[0] = input

            // Envelope follower
            if sibilance > deEsserEnvelope {
                deEsserEnvelope = attackCoeff * deEsserEnvelope + (1 - attackCoeff) * sibilance
            } else {
                deEsserEnvelope = releaseCoeff * deEsserEnvelope + (1 - releaseCoeff) * sibilance
            }

            // Apply reduction when sibilance detected
            let threshold: Float = 0.1
            if deEsserEnvelope > threshold {
                let reduction = 1.0 - deEsser * (deEsserEnvelope - threshold) / (1 - threshold)
                samples[i] *= max(0.3, reduction)
            }
        }
    }

    private func applyCompression(samples: inout [Float]) {
        let threshold: Float = 0.3
        let ratio: Float = 1 + compression * 3  // 1:1 to 4:1
        let attackTime: Float = 0.01
        let releaseTime: Float = 0.1
        let makeupGain: Float = 1 + compression * 0.5

        let attackCoeff = exp(-1.0 / (sampleRate * attackTime))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseTime))

        for i in 0..<samples.count {
            let input = abs(samples[i])

            // Envelope follower
            if input > compEnvelope {
                compEnvelope = attackCoeff * compEnvelope + (1 - attackCoeff) * input
            } else {
                compEnvelope = releaseCoeff * compEnvelope + (1 - releaseCoeff) * input
            }

            // Calculate gain reduction
            if compEnvelope > threshold {
                let overThreshold = compEnvelope - threshold
                let compressed = threshold + overThreshold / ratio
                gainReduction = compressed / compEnvelope
            } else {
                gainReduction = 1.0
            }

            samples[i] *= gainReduction * makeupGain
        }
    }

    private func applyGate(samples: inout [Float]) {
        let threshold: Float = 0.01 + gating * 0.05
        let attackTime: Float = 0.001
        let releaseTime: Float = 0.05 + gating * 0.2

        let attackCoeff = exp(-1.0 / (sampleRate * attackTime))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseTime))

        var gateEnvelope: Float = 0
        var gateGain: Float = 1

        for i in 0..<samples.count {
            let input = abs(samples[i])

            // RMS-ish envelope
            gateEnvelope = gateEnvelope * 0.99 + input * 0.01

            // Gate logic
            if gateEnvelope > threshold {
                gateGain = min(1.0, gateGain + (1 - attackCoeff))
            } else {
                gateGain = max(0.0, gateGain * releaseCoeff)
            }

            samples[i] *= gateGain
        }
    }

    public func reset() {
        resetFilters()
        deEsserEnvelope = 0
        compEnvelope = 0
        gainReduction = 0
    }
}

// MARK: - Auto Leveler

/// Automatic volume leveling for consistent loudness
public final class AutoLeveler: @unchecked Sendable {

    public var targetLUFS: Float = -16.0
    public var maxGain: Float = 12.0  // dB
    public var minGain: Float = -6.0  // dB

    private let windowSize: Int
    private var rmsHistory: [Float] = []
    private var currentGain: Float = 0

    public init(sampleRate: Float = 48000, windowMs: Float = 400) {
        self.windowSize = Int(sampleRate * windowMs / 1000)
    }

    public func process(samples: inout [Float]) {
        // Calculate RMS
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Convert to LUFS approximation
        let lufs = rms > 0 ? 20 * log10(rms) - 10 : -70

        // Calculate needed gain
        var targetGain = targetLUFS - lufs
        targetGain = max(minGain, min(maxGain, targetGain))

        // Smooth gain changes
        let smoothing: Float = 0.1
        currentGain = currentGain * (1 - smoothing) + targetGain * smoothing

        // Apply gain
        let gainLinear = pow(10, currentGain / 20)
        var gain = gainLinear
        vDSP_vsmul(samples, 1, &gain, &samples, 1, vDSP_Length(samples.count))
    }

    public func reset() {
        rmsHistory = []
        currentGain = 0
    }
}

// MARK: - Speech Transcription

/// Speech-to-text transcription engine
public actor TranscriptionEngine {

    public struct TranscriptSegment: Identifiable, Codable {
        public let id: UUID
        public var text: String
        public var startTime: TimeInterval
        public var endTime: TimeInterval
        public var confidence: Float
        public var speaker: String?

        public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float) {
            self.id = UUID()
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
            self.confidence = confidence
        }
    }

    public struct Transcript: Codable {
        public var segments: [TranscriptSegment]
        public var fullText: String
        public var duration: TimeInterval
        public var language: String
        public var wordCount: Int

        public func srt() -> String {
            var output = ""
            for (index, segment) in segments.enumerated() {
                output += "\(index + 1)\n"
                output += "\(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))\n"
                output += "\(segment.text)\n\n"
            }
            return output
        }

        public func vtt() -> String {
            var output = "WEBVTT\n\n"
            for segment in segments {
                output += "\(formatVTTTime(segment.startTime)) --> \(formatVTTTime(segment.endTime))\n"
                output += "\(segment.text)\n\n"
            }
            return output
        }

        private func formatSRTTime(_ time: TimeInterval) -> String {
            let hours = Int(time) / 3600
            let minutes = (Int(time) % 3600) / 60
            let seconds = Int(time) % 60
            let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
            return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
        }

        private func formatVTTTime(_ time: TimeInterval) -> String {
            let hours = Int(time) / 3600
            let minutes = (Int(time) % 3600) / 60
            let seconds = Int(time) % 60
            let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        }
    }

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    /// Request authorization for speech recognition
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe audio file
    public func transcribe(url: URL, progressHandler: ((Float) -> Void)? = nil) async throws -> Transcript {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // Get audio duration
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result, result.isFinal else { return }

                // Convert to our transcript format
                var segments: [TranscriptSegment] = []

                for segment in result.bestTranscription.segments {
                    let seg = TranscriptSegment(
                        text: segment.substring,
                        startTime: segment.timestamp,
                        endTime: segment.timestamp + segment.duration,
                        confidence: segment.confidence
                    )
                    segments.append(seg)
                }

                let transcript = Transcript(
                    segments: segments,
                    fullText: result.bestTranscription.formattedString,
                    duration: duration,
                    language: recognizer.locale.identifier,
                    wordCount: result.bestTranscription.formattedString.split(separator: " ").count
                )

                continuation.resume(returning: transcript)
            }
        }
    }

    /// Cancel ongoing transcription
    public func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - Chapter Marker

/// Creates chapter markers for podcasts
public struct ChapterMarker: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var startTime: TimeInterval
    public var endTime: TimeInterval?
    public var imageURL: URL?
    public var url: URL?  // Link for chapter

    public init(title: String, startTime: TimeInterval) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
    }
}

public actor ChapterManager {

    private var chapters: [ChapterMarker] = []

    public func addChapter(_ chapter: ChapterMarker) {
        chapters.append(chapter)
        chapters.sort { $0.startTime < $1.startTime }

        // Update end times
        for i in 0..<chapters.count - 1 {
            chapters[i].endTime = chapters[i + 1].startTime
        }
    }

    public func removeChapter(id: UUID) {
        chapters.removeAll { $0.id == id }
    }

    public func getChapters() -> [ChapterMarker] {
        chapters
    }

    /// Auto-detect chapters from transcript using topic changes
    public func autoDetectChapters(from transcript: TranscriptionEngine.Transcript, minDuration: TimeInterval = 60) -> [ChapterMarker] {
        var detectedChapters: [ChapterMarker] = []

        // Simple topic detection using keyword changes
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        var currentTopicStart: TimeInterval = 0
        var currentKeywords: Set<String> = []

        for segment in transcript.segments {
            tagger.string = segment.text

            var segmentKeywords: Set<String> = []

            tagger.enumerateTags(in: segment.text.startIndex..<segment.text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
                if let tag = tag, tag == .noun || tag == .verb {
                    let word = String(segment.text[range]).lowercased()
                    if word.count > 3 {
                        segmentKeywords.insert(word)
                    }
                }
                return true
            }

            // Check for topic change
            let overlap = currentKeywords.intersection(segmentKeywords)
            let similarity = currentKeywords.isEmpty ? 0 : Float(overlap.count) / Float(currentKeywords.count)

            if similarity < 0.3 && segment.startTime - currentTopicStart > minDuration {
                // Topic change detected
                let title = generateChapterTitle(from: segment.text)
                var chapter = ChapterMarker(title: title, startTime: segment.startTime)
                chapter.endTime = nil
                detectedChapters.append(chapter)

                currentTopicStart = segment.startTime
                currentKeywords = segmentKeywords
            } else {
                currentKeywords.formUnion(segmentKeywords)
            }
        }

        return detectedChapters
    }

    private func generateChapterTitle(from text: String) -> String {
        // Take first few significant words
        let words = text.split(separator: " ")
        let titleWords = words.prefix(5).joined(separator: " ")
        return titleWords.isEmpty ? "Chapter" : String(titleWords)
    }

    /// Export chapters to podcast-compatible format
    public func exportPodcastChapters() -> [[String: Any]] {
        chapters.map { chapter in
            var dict: [String: Any] = [
                "title": chapter.title,
                "startTime": chapter.startTime * 1000  // Milliseconds
            ]
            if let endTime = chapter.endTime {
                dict["endTime"] = endTime * 1000
            }
            if let imageURL = chapter.imageURL {
                dict["img"] = imageURL.absoluteString
            }
            if let url = chapter.url {
                dict["url"] = url.absoluteString
            }
            return dict
        }
    }
}

// MARK: - Podcast Studio Engine

/// Main podcast studio engine
public actor PodcastStudioEngine {

    public static let shared = PodcastStudioEngine()

    // Processing components
    private let noiseGate = SpectralNoiseGate()
    private let voiceEnhancer: VoiceEnhancer
    private let autoLeveler = AutoLeveler()
    private let transcriptionEngine: TranscriptionEngine
    private let chapterManager = ChapterManager()

    // Settings
    public var noiseReduction: Float = 0.5
    public var voiceEnhancement: Float = 0.5
    public var autoLevel: Bool = true
    public var targetLoudness: Float = -16.0

    private init() {
        voiceEnhancer = VoiceEnhancer()
        transcriptionEngine = TranscriptionEngine()
    }

    // MARK: - Configuration

    public func setNoiseProfile(_ profile: NoiseProfile) {
        noiseGate.setNoiseProfile(profile)
    }

    public func learnNoiseFromSilence(_ samples: [Float]) {
        noiseGate.learnNoiseProfile(from: samples)
    }

    public func configureVoiceEnhancer(
        lowCut: Float = 80,
        presence: Float = 0.3,
        warmth: Float = 0.2,
        compression: Float = 0.3
    ) {
        voiceEnhancer.lowCut = lowCut
        voiceEnhancer.presence = presence * voiceEnhancement
        voiceEnhancer.warmth = warmth * voiceEnhancement
        voiceEnhancer.compression = compression * voiceEnhancement
    }

    // MARK: - Processing

    public func process(samples: inout [Float]) async {
        // Noise reduction
        if noiseReduction > 0 {
            noiseGate.reduction = noiseReduction
            noiseGate.process(samples: &samples)
        }

        // Voice enhancement
        if voiceEnhancement > 0 {
            voiceEnhancer.process(samples: &samples)
        }

        // Auto-leveling
        if autoLevel {
            autoLeveler.targetLUFS = targetLoudness
            autoLeveler.process(samples: &samples)
        }
    }

    /// Process entire audio file
    public func processFile(input: URL, output: URL, progressHandler: ((Float, String) -> Void)? = nil) async throws {
        progressHandler?(0, "Loading audio file...")

        // Load audio
        let inputFile = try AVAudioFile(forReading: input)
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw PodcastError.bufferCreationFailed
        }

        try inputFile.read(into: buffer)

        // Extract samples
        guard let channelData = buffer.floatChannelData else {
            throw PodcastError.invalidAudio
        }

        var samples = [Float](repeating: 0, count: Int(frameCount))
        for i in 0..<Int(frameCount) {
            samples[i] = channelData[0][i]
        }

        progressHandler?(0.2, "Reducing noise...")

        // Process
        await process(samples: &samples)

        progressHandler?(0.8, "Saving processed audio...")

        // Write output
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false)!

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            throw PodcastError.bufferCreationFailed
        }

        outputBuffer.frameLength = frameCount
        if let outputData = outputBuffer.floatChannelData {
            for i in 0..<Int(frameCount) {
                outputData[0][i] = samples[i]
            }
        }

        let outputFile = try AVAudioFile(forWriting: output, settings: outputFormat.settings)
        try outputFile.write(from: outputBuffer)

        progressHandler?(1.0, "Processing complete!")
    }

    // MARK: - Transcription

    public func transcribe(url: URL, progressHandler: ((Float) -> Void)? = nil) async throws -> TranscriptionEngine.Transcript {
        try await transcriptionEngine.transcribe(url: url, progressHandler: progressHandler)
    }

    public func requestTranscriptionAuthorization() async -> Bool {
        await transcriptionEngine.requestAuthorization()
    }

    // MARK: - Chapters

    public func addChapter(_ chapter: ChapterMarker) async {
        await chapterManager.addChapter(chapter)
    }

    public func getChapters() async -> [ChapterMarker] {
        await chapterManager.getChapters()
    }

    public func autoDetectChapters(from transcript: TranscriptionEngine.Transcript) async -> [ChapterMarker] {
        await chapterManager.autoDetectChapters(from: transcript)
    }

    // MARK: - Export

    public func exportWithMetadata(
        audioURL: URL,
        outputURL: URL,
        title: String,
        artist: String,
        artwork: Data? = nil
    ) async throws {
        // Copy audio file with metadata
        let asset = AVURLAsset(url: audioURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw PodcastError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Add metadata
        var metadata: [AVMetadataItem] = []

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        metadata.append(titleItem)

        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = artist as NSString
        metadata.append(artistItem)

        if let artworkData = artwork {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.value = artworkData as NSData
            metadata.append(artworkItem)
        }

        exportSession.metadata = metadata

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }
    }
}

// MARK: - Errors

public enum TranscriptionError: Error {
    case recognizerUnavailable
    case authorizationDenied
    case transcriptionFailed
}

public enum PodcastError: Error {
    case bufferCreationFailed
    case invalidAudio
    case exportFailed
}
