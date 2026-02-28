// ChromaticTuner.swift
// Echoelmusic
//
// Professional chromatic instrument tuner using autocorrelation
// pitch detection. Supports standard and custom tuning references.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Note Names

/// Musical note representation
public struct MusicalNote: Equatable, Sendable {
    public let name: String
    public let octave: Int
    public let midiNumber: Int
    public let frequency: Double

    /// Note names in chromatic order
    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Get note from frequency
    public static func fromFrequency(_ frequency: Double, referenceA4: Double = 440.0) -> MusicalNote {
        guard frequency > 0 else {
            return MusicalNote(name: "-", octave: 0, midiNumber: 0, frequency: 0)
        }

        // MIDI note number (A4 = 69)
        let midiFloat = 69.0 + 12.0 * log2(frequency / referenceA4)
        let midiNumber = Int(round(midiFloat))

        let noteIndex = ((midiNumber % 12) + 12) % 12
        let octave = (midiNumber / 12) - 1

        let name = noteNames[noteIndex]
        let exactFrequency = referenceA4 * pow(2.0, Double(midiNumber - 69) / 12.0)

        return MusicalNote(
            name: name,
            octave: octave,
            midiNumber: midiNumber,
            frequency: exactFrequency
        )
    }

    /// Full display name (e.g., "A4")
    public var displayName: String {
        return "\(name)\(octave)"
    }
}

// MARK: - Tuning Reference

/// Common tuning reference frequencies
public enum TuningReference: String, CaseIterable, Codable, Sendable {
    case standard440 = "A4 = 440 Hz"
    case baroque415 = "A4 = 415 Hz"
    case verdi432 = "A4 = 432 Hz"
    case concert442 = "A4 = 442 Hz"
    case concert443 = "A4 = 443 Hz"
    case scientific256 = "C4 = 256 Hz"
    case custom = "Custom"

    public var a4Frequency: Double {
        switch self {
        case .standard440: return 440.0
        case .baroque415: return 415.0
        case .verdi432: return 432.0
        case .concert442: return 442.0
        case .concert443: return 443.0
        case .scientific256: return 430.539 // A4 when C4=256
        case .custom: return 440.0 // placeholder — actual value from TuningManager.concertPitch
        }
    }
}

// MARK: - Tuner State

/// Current tuner reading
public struct TunerReading: Sendable {
    public let frequency: Double
    public let note: MusicalNote
    public let centsOffset: Double // -50 to +50
    public let confidence: Double  // 0 to 1
    public let amplitude: Double   // Signal level

    /// Is the note in tune (within threshold)?
    public func isInTune(threshold: Double = 5.0) -> Bool {
        return abs(centsOffset) <= threshold && confidence > 0.5
    }
}

// MARK: - Chromatic Tuner

/// Professional chromatic tuner with autocorrelation pitch detection
@MainActor
public final class ChromaticTuner: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentReading: TunerReading?
    @Published public private(set) var detectedFrequency: Double = 0
    @Published public private(set) var detectedNote: MusicalNote?
    @Published public private(set) var centsOffset: Double = 0
    @Published public private(set) var signalLevel: Double = 0
    @Published public var tuningReference: TuningReference = .standard440
    @Published public var customA4: Double = 440.0

    /// History of readings for smoothing display
    @Published public private(set) var readingHistory: [TunerReading] = []

    // MARK: - Private Properties

    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.echoelmusic.tuner", qos: .userInteractive)

    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 4096
    private let minFrequency: Double = 27.5  // A0
    private let maxFrequency: Double = 4186  // C8
    private let amplitudeThreshold: Double = 0.01

    // Autocorrelation buffers
    private var analysisBuffer: [Float] = []
    private let maxHistorySize = 10

    // MARK: - Initialization

    public init(reference: TuningReference = .standard440) {
        self.tuningReference = reference
        self.customA4 = reference.a4Frequency
    }

    // MARK: - Public API

    /// Start the tuner
    public func start() throws {
        guard !isActive else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        try audioEngine.start()
        isActive = true
    }

    /// Stop the tuner
    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isActive = false
        currentReading = nil
        detectedFrequency = 0
        detectedNote = nil
        centsOffset = 0
        signalLevel = 0
    }

    /// Set tuning reference
    public func setReference(_ reference: TuningReference) {
        tuningReference = reference
        customA4 = reference.a4Frequency
    }

    /// Set custom A4 frequency
    public func setCustomA4(_ frequency: Double) {
        customA4 = max(400, min(500, frequency))
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard buffer.floatChannelData != nil else { return }

        // Copy data for analysis
        let samples = buffer.floatArray(channel: 0)

        analysisQueue.async { [weak self] in
            guard let self = self else { return }

            // Calculate amplitude
            var rms: Float = 0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
            let amplitude = Double(rms)

            // Only analyze if signal is above threshold
            guard amplitude > self.amplitudeThreshold else {
                Task { @MainActor in
                    self.signalLevel = amplitude
                    self.currentReading = nil
                }
                return
            }

            // Detect pitch using autocorrelation
            let frequency = self.detectPitch(samples: samples, sampleRate: self.sampleRate)

            guard frequency > self.minFrequency && frequency < self.maxFrequency else {
                Task { @MainActor in
                    self.signalLevel = amplitude
                }
                return
            }

            // Calculate note and cents
            let a4 = self.customA4
            let note = MusicalNote.fromFrequency(frequency, referenceA4: a4)
            let cents = 1200.0 * log2(frequency / note.frequency)

            // Confidence based on autocorrelation clarity
            let confidence = min(1.0, amplitude / 0.1)

            let reading = TunerReading(
                frequency: frequency,
                note: note,
                centsOffset: cents,
                confidence: confidence,
                amplitude: amplitude
            )

            Task { @MainActor in
                self.detectedFrequency = frequency
                self.detectedNote = note
                self.centsOffset = cents
                self.signalLevel = amplitude
                self.currentReading = reading

                // Update history
                self.readingHistory.append(reading)
                if self.readingHistory.count > self.maxHistorySize {
                    self.readingHistory.removeFirst()
                }
            }
        }
    }

    // MARK: - Pitch Detection (Autocorrelation)

    /// Detect fundamental frequency using autocorrelation
    private func detectPitch(samples: [Float], sampleRate: Double) -> Double {
        let n = samples.count

        // Window the signal
        var windowed = [Float](repeating: 0, count: n)
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // Compute autocorrelation using vDSP
        var autocorrelation = [Float](repeating: 0, count: n)
        vDSP_conv(windowed, 1, windowed, 1, &autocorrelation, 1, vDSP_Length(n), vDSP_Length(n))

        // Normalize
        if autocorrelation[0] > 0 {
            var normalizer = 1.0 / autocorrelation[0]
            vDSP_vsmul(autocorrelation, 1, &normalizer, &autocorrelation, 1, vDSP_Length(n))
        }

        // Find the first significant peak after the initial decline
        let minLag = Int(sampleRate / maxFrequency) // Highest frequency we care about
        let maxLag = Int(sampleRate / minFrequency) // Lowest frequency we care about

        guard maxLag < n else { return 0 }

        // Find where autocorrelation first goes below threshold
        var foundDip = false
        var searchStart = minLag

        for i in 1..<maxLag {
            if autocorrelation[i] < 0.1 {
                foundDip = true
                searchStart = i
                break
            }
        }

        guard foundDip else { return 0 }

        // Find peak after the dip
        var peakLag = searchStart
        var peakValue: Float = 0

        for i in searchStart..<min(maxLag, n) {
            if autocorrelation[i] > peakValue {
                peakValue = autocorrelation[i]
                peakLag = i
            }
        }

        // Peak must be significant
        guard peakValue > 0.2 else { return 0 }

        // Parabolic interpolation for sub-sample accuracy
        let refinedLag: Double
        if peakLag > 0 && peakLag < n - 1 {
            let alpha = Double(autocorrelation[peakLag - 1])
            let beta = Double(autocorrelation[peakLag])
            let gamma = Double(autocorrelation[peakLag + 1])

            let denominator = alpha - 2 * beta + gamma
            if abs(denominator) > 0.0001 {
                let p = 0.5 * (alpha - gamma) / denominator
                refinedLag = Double(peakLag) + p
            } else {
                refinedLag = Double(peakLag)
            }
        } else {
            refinedLag = Double(peakLag)
        }

        // Convert lag to frequency
        guard refinedLag > 0 else { return 0 }
        return sampleRate / refinedLag
    }

    deinit {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
}
