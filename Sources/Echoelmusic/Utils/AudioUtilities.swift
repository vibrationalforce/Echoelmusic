//
//  AudioUtilities.swift
//  Echoelmusic
//
//  Shared Audio Utilities
//  dB conversion, pan laws, frequency calculations, etc.
//

import Foundation
import Accelerate

struct AudioUtilities {

    // MARK: - dB Conversions

    /// Convert decibels to linear gain
    /// - Parameter dB: Decibels (-inf to +inf)
    /// - Returns: Linear gain (0.0 to inf)
    static func dBToLinear(_ dB: Float) -> Float {
        return pow(10.0, dB / 20.0)
    }

    /// Convert linear gain to decibels
    /// - Parameter linear: Linear gain (0.0 to inf)
    /// - Returns: Decibels (-inf to +inf), with floor at -96dB
    static func linearTodB(_ linear: Float) -> Float {
        return 20.0 * log10(max(linear, 1e-6))  // -96dB floor
    }

    /// Convert RMS to decibels with floor
    /// - Parameter rms: RMS value
    /// - Returns: dB value with -96dB floor
    static func rmsTodB(_ rms: Float) -> Float {
        return 20.0 * log10(max(rms, 1e-6))
    }

    // MARK: - Pan Laws

    /// Constant power pan law (sin/cos, -3dB center)
    /// - Parameter pan: -1.0 (left) to +1.0 (right), 0.0 = center
    /// - Returns: Tuple of (left gain, right gain)
    static func constantPowerPan(_ pan: Float) -> (left: Float, right: Float) {
        let panRadians = pan * Float.pi / 4.0  // -45° to +45°
        return (cos(panRadians), sin(panRadians))
    }

    /// Linear pan law (0dB center, -6dB sides)
    /// - Parameter pan: -1.0 (left) to +1.0 (right), 0.0 = center
    /// - Returns: Tuple of (left gain, right gain)
    static func linearPan(_ pan: Float) -> (left: Float, right: Float) {
        let leftGain = (1.0 - pan) / 2.0  // 0.0 to 1.0
        let rightGain = (1.0 + pan) / 2.0  // 0.0 to 1.0
        return (leftGain, rightGain)
    }

    // MARK: - Frequency Conversions

    /// Convert MIDI note number to frequency (Hz)
    /// - Parameter midiNote: MIDI note (0-127), 69 = A4 = 440Hz
    /// - Returns: Frequency in Hz
    static func midiNoteToFrequency(_ midiNote: UInt8) -> Float {
        return 440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0)
    }

    /// Convert frequency to MIDI note number
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: MIDI note (fractional, can be quantized)
    static func frequencyToMIDINote(_ frequency: Float) -> Float {
        return 69.0 + 12.0 * log2(frequency / 440.0)
    }

    /// Convert frequency to note name
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Note name (e.g., "A4", "C#3")
    static func frequencyToNoteName(_ frequency: Float) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let midiNote = frequencyToMIDINote(frequency)
        let noteIndex = Int(midiNote.rounded()) % 12
        let octave = Int(midiNote.rounded()) / 12 - 1
        return "\(noteNames[noteIndex])\(octave)"
    }

    // MARK: - Time Conversions

    /// Convert samples to seconds
    /// - Parameters:
    ///   - samples: Number of samples
    ///   - sampleRate: Sample rate (e.g., 48000)
    /// - Returns: Time in seconds
    static func samplesToSeconds(samples: Int64, sampleRate: Double) -> TimeInterval {
        return Double(samples) / sampleRate
    }

    /// Convert seconds to samples
    /// - Parameters:
    ///   - seconds: Time in seconds
    ///   - sampleRate: Sample rate (e.g., 48000)
    /// - Returns: Number of samples
    static func secondsToSamples(seconds: TimeInterval, sampleRate: Double) -> Int64 {
        return Int64(seconds * sampleRate)
    }

    /// Convert beats to samples (with tempo)
    /// - Parameters:
    ///   - beats: Musical beats
    ///   - tempo: Tempo in BPM
    ///   - sampleRate: Sample rate (e.g., 48000)
    /// - Returns: Number of samples
    static func beatsToSamples(beats: Double, tempo: Double, sampleRate: Double) -> Int64 {
        let seconds = (beats * 60.0) / tempo
        return Int64(seconds * sampleRate)
    }

    /// Convert samples to beats (with tempo)
    /// - Parameters:
    ///   - samples: Number of samples
    ///   - tempo: Tempo in BPM
    ///   - sampleRate: Sample rate (e.g., 48000)
    /// - Returns: Musical beats
    static func samplesToBeats(samples: Int64, tempo: Double, sampleRate: Double) -> Double {
        let seconds = Double(samples) / sampleRate
        return (seconds * tempo) / 60.0
    }

    // MARK: - Audio Processing Helpers

    /// Calculate RMS (Root Mean Square) of audio buffer using vDSP
    /// - Parameter buffer: Audio samples
    /// - Returns: RMS value
    static func calculateRMS(_ buffer: [Float]) -> Float {
        guard !buffer.isEmpty else { return 0.0 }

        var rms: Float = 0.0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(buffer.count))
        return rms
    }

    /// Calculate peak level of audio buffer using vDSP
    /// - Parameter buffer: Audio samples
    /// - Returns: Peak value (absolute)
    static func calculatePeak(_ buffer: [Float]) -> Float {
        guard !buffer.isEmpty else { return 0.0 }

        var peak: Float = 0.0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(buffer.count))
        return peak
    }

    /// Mix two audio buffers with gain control using vDSP
    /// - Parameters:
    ///   - buffer1: First buffer
    ///   - buffer2: Second buffer
    ///   - gain1: Gain for first buffer (linear)
    ///   - gain2: Gain for second buffer (linear)
    /// - Returns: Mixed buffer
    static func mixBuffers(_ buffer1: [Float], _ buffer2: [Float], gain1: Float = 1.0, gain2: Float = 1.0) -> [Float] {
        let count = min(buffer1.count, buffer2.count)
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0.0, count: count)

        // Apply gains and add
        var g1 = gain1
        var g2 = gain2
        vDSP_vsma(buffer1, 1, &g1, buffer2, 1, &result, 1, vDSP_Length(count))
        vDSP_vsmul(result, 1, &g2, &result, 1, vDSP_Length(count))

        return result
    }

    /// Apply gain to buffer using vDSP (in-place)
    /// - Parameters:
    ///   - buffer: Audio buffer (will be modified)
    ///   - gain: Linear gain to apply
    static func applyGain(buffer: inout [Float], gain: Float) {
        var gainValue = gain
        vDSP_vsmul(buffer, 1, &gainValue, &buffer, 1, vDSP_Length(buffer.count))
    }

    // MARK: - Validation

    /// Validate sample rate
    /// - Parameter sampleRate: Sample rate to validate
    /// - Returns: True if valid (typically 44100, 48000, 88200, 96000, 192000)
    static func isValidSampleRate(_ sampleRate: Double) -> Bool {
        let validRates: [Double] = [44100, 48000, 88200, 96000, 192000]
        return validRates.contains(sampleRate) || sampleRate > 0
    }

    /// Clamp MIDI note to valid range
    /// - Parameter note: MIDI note (can be out of range)
    /// - Returns: Clamped MIDI note (0-127)
    static func clampMIDINote(_ note: Int) -> UInt8 {
        return UInt8(max(0, min(127, note)))
    }

    /// Clamp MIDI velocity to valid range
    /// - Parameter velocity: Velocity (can be out of range)
    /// - Returns: Clamped velocity (1-127, 0 = note off)
    static func clampMIDIVelocity(_ velocity: Int, allowZero: Bool = false) -> UInt8 {
        let min = allowZero ? 0 : 1
        return UInt8(max(min, min(127, velocity)))
    }

    /// Clamp audio sample to -1.0...1.0 range (prevent clipping)
    /// - Parameter sample: Audio sample
    /// - Returns: Clamped sample
    static func clampSample(_ sample: Float) -> Float {
        return max(-1.0, min(1.0, sample))
    }

    // MARK: - Buffer Utilities

    /// Check if buffer size is power of 2 (optimal for FFT)
    /// - Parameter size: Buffer size
    /// - Returns: True if power of 2
    static func isPowerOfTwo(_ size: Int) -> Bool {
        return size > 0 && (size & (size - 1)) == 0
    }

    /// Get next power of 2 greater than or equal to value
    /// - Parameter value: Input value
    /// - Returns: Next power of 2
    static func nextPowerOfTwo(_ value: Int) -> Int {
        guard value > 0 else { return 1 }
        var v = value - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }

    // MARK: - Interpolation

    /// Linear interpolation between two values
    /// - Parameters:
    ///   - a: Start value
    ///   - b: End value
    ///   - t: Interpolation factor (0.0 to 1.0)
    /// - Returns: Interpolated value
    static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    /// Cubic interpolation (smoother than linear)
    /// - Parameters:
    ///   - y0: Point before a
    ///   - y1: Start point
    ///   - y2: End point
    ///   - y3: Point after b
    ///   - t: Interpolation factor (0.0 to 1.0)
    /// - Returns: Interpolated value
    static func cubicInterpolation(_ y0: Float, _ y1: Float, _ y2: Float, _ y3: Float, _ t: Float) -> Float {
        let t2 = t * t
        let a0 = y3 - y2 - y0 + y1
        let a1 = y0 - y1 - a0
        let a2 = y2 - y0
        let a3 = y1

        return a0 * t * t2 + a1 * t2 + a2 * t + a3
    }
}

// MARK: - Constants

extension AudioUtilities {
    /// Standard sample rates
    enum SampleRate: Double {
        case cd = 44100.0
        case standard = 48000.0
        case highQuality = 96000.0
        case ultraHighQuality = 192000.0
    }

    /// Standard buffer sizes (samples)
    enum BufferSize: Int {
        case ultraLow = 32      // <1ms latency
        case veryLow = 64       // ~1.3ms
        case low = 128          // ~2.7ms
        case balanced = 256     // ~5.3ms
        case safe = 512         // ~10.7ms
        case high = 1024        // ~21.3ms (at 48kHz)
        case veryHigh = 2048    // ~42.7ms
    }

    /// MIDI constants
    enum MIDI {
        static let noteOff: UInt8 = 0x80
        static let noteOn: UInt8 = 0x90
        static let controlChange: UInt8 = 0xB0
        static let programChange: UInt8 = 0xC0
        static let pitchBend: UInt8 = 0xE0

        static let minNote: UInt8 = 0
        static let maxNote: UInt8 = 127
        static let middleC: UInt8 = 60  // C4
        static let concertA: UInt8 = 69  // A4 = 440Hz
    }
}
