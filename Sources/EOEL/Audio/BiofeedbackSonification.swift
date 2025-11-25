//
//  BiofeedbackSonification.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  REAL-TIME BIOFEEDBACK → AUDIO SONIFICATION
//  Translates physiological data (HRV, heart rate, coherence) to audible frequencies
//
//  **Scientific Basis:**
//  - Sonification increases biofeedback awareness (van der Zwaag et al. 2011)
//  - Multi-modal feedback (visual + audio) improves learning (Prpa et al. 2018)
//  - Frequency mapping enables intuitive physiological monitoring
//

import Foundation
import AVFoundation
import Combine

// MARK: - Biofeedback Sonification Manager

/// Real-time sonification of biofeedback data
///
/// **Mapping Strategies:**
/// 1. Parameter Mapping: HRV → Pitch, HR → Tempo, Coherence → Harmony
/// 2. Frequency Translation: 0.04-0.4 Hz (HRV) → 40-400 Hz (audible)
/// 3. Musical Mapping: Physiological states → Musical scales/modes
@MainActor
class BiofeedbackSonificationManager: ObservableObject {
    static let shared = BiofeedbackSonificationManager()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = true
    @Published var sonificationMode: SonificationMode = .musical
    @Published var volume: Float = 0.5

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private let hrvOscillator = AVAudioPlayerNode()
    private let heartbeatOscillator = AVAudioPlayerNode()
    private let coherenceTone = AVAudioPlayerNode()
    private let mixer = AVAudioMixerNode()

    // Audio format
    private let sampleRate: Double = 44100.0
    private let bufferSize: AVAudioFrameCount = 4410  // 100ms at 44.1kHz

    // MARK: - Sonification Modes

    enum SonificationMode {
        case direct         // Direct frequency translation (HRV freq × 1000)
        case musical        // Musical scale mapping (physiological → musical intervals)
        case parametric     // Parameter mapping (HRV → pitch, HR → tempo, etc.)
        case ambient        // Ambient soundscape (subtle, non-intrusive)
        case heartbeat      // Realistic heartbeat sound + modulation

        var description: String {
            switch self {
            case .direct:
                return "Direct frequency multiplication (0.1 Hz → 100 Hz)"
            case .musical:
                return "Musical scale mapping (physiological states → harmonious tones)"
            case .parametric:
                return "Multi-parameter mapping (HRV → pitch, HR → tempo, Coherence → harmony)"
            case .ambient:
                return "Subtle ambient soundscape (non-intrusive background)"
            case .heartbeat:
                return "Realistic heartbeat with biofeedback modulation"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // Attach nodes
        audioEngine.attach(hrvOscillator)
        audioEngine.attach(heartbeatOscillator)
        audioEngine.attach(coherenceTone)
        audioEngine.attach(mixer)

        // Connect nodes
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        audioEngine.connect(hrvOscillator, to: mixer, format: format)
        audioEngine.connect(heartbeatOscillator, to: mixer, format: format)
        audioEngine.connect(coherenceTone, to: mixer, format: format)
        audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: format)

        // Set initial volume
        mixer.volume = volume

        do {
            try audioEngine.start()
            print("🎵 Biofeedback sonification engine started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    // MARK: - Sonification Methods

    /// Sonify HRV frequency (0.04-0.4 Hz → audible range)
    ///
    /// **Direct Translation:**
    /// - 0.04 Hz (LF lower) × 1000 = 40 Hz (sub-bass)
    /// - 0.1 Hz (resonant freq) × 1000 = 100 Hz (bass)
    /// - 0.4 Hz (HF upper) × 1000 = 400 Hz (low-mid)
    ///
    /// **Musical Translation:**
    /// - VLF (0.003-0.04 Hz) → C2 (65 Hz) - Root note
    /// - LF (0.04-0.15 Hz) → G2 (98 Hz) - Perfect 5th
    /// - HF (0.15-0.4 Hz) → C3 (130 Hz) - Octave
    func sonifyHRV(frequency: Double, power: Double) {
        guard isEnabled else { return }

        let audibleFrequency: Double

        switch sonificationMode {
        case .direct:
            // Direct frequency multiplication (×1000)
            audibleFrequency = frequency * 1000.0
            // 0.1 Hz → 100 Hz (bass frequency)

        case .musical:
            // Map to musical scale
            audibleFrequency = mapHRVToMusicalScale(hrvFrequency: frequency)

        case .parametric:
            // Use HRV power to modulate pitch around base frequency
            let basePitch = 220.0  // A3
            let modulation = (power - 0.5) * 100.0  // ±50 Hz modulation
            audibleFrequency = basePitch + modulation

        case .ambient:
            // Soft ambient tone (low volume)
            audibleFrequency = frequency * 500.0  // Softer mapping
            // 0.1 Hz → 50 Hz (very low, felt more than heard)

        case .heartbeat:
            // No direct HRV tone in heartbeat mode
            return
        }

        // Generate audio buffer
        let buffer = generateSineWave(
            frequency: audibleFrequency,
            amplitude: Float(power) * volume,
            duration: 0.1
        )

        // Schedule playback
        hrvOscillator.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        if !hrvOscillator.isPlaying {
            hrvOscillator.play()
        }
    }

    /// Sonify heart rate (60-180 BPM → tempo and pitch)
    ///
    /// **Mapping:**
    /// - 60 BPM → 1 Hz → 60 Hz (sub-bass) or 120 Hz (bass)
    /// - 120 BPM → 2 Hz → 120 Hz (bass) or 240 Hz (low-mid)
    /// - Tempo: Actual heartbeat rhythm
    func sonifyHeartRate(bpm: Double) {
        guard isEnabled else { return }

        switch sonificationMode {
        case .direct:
            // Heart rate in Hz
            let hrFrequency = bpm / 60.0  // BPM → Hz
            let audibleFrequency = hrFrequency * 100.0  // ×100 to make audible
            // 70 BPM → 1.17 Hz → 117 Hz

            let buffer = generateSineWave(
                frequency: audibleFrequency,
                amplitude: 0.3 * volume,
                duration: 60.0 / bpm  // Duration of one heartbeat
            )

            heartbeatOscillator.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        case .musical:
            // Map heart rate to musical pitch
            let pitch = mapHeartRateToMusicalScale(bpm: bpm)

            let buffer = generateSineWave(
                frequency: pitch,
                amplitude: 0.3 * volume,
                duration: 60.0 / bpm
            )

            heartbeatOscillator.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        case .parametric:
            // Use HR to control tempo of background pulse
            scheduleHeartbeatPulse(bpm: bpm)

        case .ambient:
            // Very subtle pulse at heart rate
            let buffer = generatePulse(
                frequency: bpm / 60.0,
                amplitude: 0.1 * volume,
                duration: 0.1
            )

            heartbeatOscillator.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        case .heartbeat:
            // Realistic heartbeat sound
            generateRealisticHeartbeat(bpm: bpm)
        }

        if !heartbeatOscillator.isPlaying {
            heartbeatOscillator.play()
        }
    }

    /// Sonify coherence score (0-100 → harmony/consonance)
    ///
    /// **Mapping:**
    /// - Low coherence (0-40) → Dissonant intervals (minor 2nd, tritone)
    /// - Medium coherence (40-60) → Neutral intervals (major 3rd, perfect 4th)
    /// - High coherence (60-100) → Consonant intervals (perfect 5th, octave)
    func sonifyCoherence(score: Double) {
        guard isEnabled else { return }

        let baseFrequency = 440.0  // A4

        let interval: Double
        if score >= 60.0 {
            // High coherence → Perfect 5th (ratio 3:2)
            interval = 1.5
        } else if score >= 40.0 {
            // Medium coherence → Major 3rd (ratio 5:4)
            interval = 1.25
        } else {
            // Low coherence → Minor 2nd (ratio 16:15)
            interval = 1.067
        }

        let harmonicFrequency = baseFrequency * interval

        // Generate harmonious tone
        let buffer = generateHarmonicTone(
            fundamental: baseFrequency,
            harmonic: harmonicFrequency,
            amplitude: 0.2 * volume,
            duration: 2.0
        )

        coherenceTone.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        if !coherenceTone.isPlaying {
            coherenceTone.play()
        }
    }

    /// Sonify complete biofeedback state (HRV, HR, Coherence → multi-parameter audio)
    func sonifyBiofeedbackState(hrv: Double, heartRate: Double, coherence: Double) {
        // HRV → Pitch modulation
        sonifyHRV(frequency: 0.1, power: hrv / 100.0)

        // Heart Rate → Rhythm/tempo
        sonifyHeartRate(bpm: heartRate)

        // Coherence → Harmony
        sonifyCoherence(score: coherence)
    }

    // MARK: - Musical Mapping

    private func mapHRVToMusicalScale(hrvFrequency: Double) -> Double {
        // Map HRV bands to musical scale (C major pentatonic)
        // VLF → C2 (65 Hz)
        // LF → G2 (98 Hz)
        // HF → C3 (130 Hz)

        if hrvFrequency < 0.04 {
            // VLF → C2
            return 65.41  // C2
        } else if hrvFrequency < 0.15 {
            // LF → G2
            return 98.00  // G2
        } else {
            // HF → C3
            return 130.81  // C3
        }
    }

    private func mapHeartRateToMusicalScale(bpm: Double) -> Double {
        // Map heart rate to musical pitch (pentatonic scale)
        // 60 BPM → C3 (130 Hz)
        // 80 BPM → E3 (165 Hz)
        // 100 BPM → G3 (196 Hz)
        // 120 BPM → C4 (261 Hz)

        let normalizedBPM = (bpm - 60.0) / 60.0  // 0-1 for 60-120 BPM
        let clampedBPM = max(0.0, min(1.0, normalizedBPM))

        // Pentatonic scale: C, D, E, G, A
        let scale: [Double] = [130.81, 146.83, 164.81, 196.00, 220.00]
        let index = Int(clampedBPM * Double(scale.count - 1))

        return scale[index]
    }

    // MARK: - Audio Generation

    private func generateSineWave(
        frequency: Double,
        amplitude: Float,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        let angularFrequency = 2.0 * Float.pi * Float(frequency)
        let sampleRateFloat = Float(sampleRate)

        for frame in 0..<Int(frameCount) {
            let time = Float(frame) / sampleRateFloat
            let sample = amplitude * sin(angularFrequency * time)

            leftChannel[frame] = sample
            rightChannel[frame] = sample
        }

        return buffer
    }

    private func generatePulse(
        frequency: Double,
        amplitude: Float,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate short pulse with attack and decay
        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(frameCount)
            let envelope = sin(Float.pi * t)  // Smooth attack-decay envelope
            let sample = amplitude * envelope

            leftChannel[frame] = sample
            rightChannel[frame] = sample
        }

        return buffer
    }

    private func generateHarmonicTone(
        fundamental: Double,
        harmonic: Double,
        amplitude: Float,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        let angularFreq1 = 2.0 * Float.pi * Float(fundamental)
        let angularFreq2 = 2.0 * Float.pi * Float(harmonic)
        let sampleRateFloat = Float(sampleRate)

        for frame in 0..<Int(frameCount) {
            let time = Float(frame) / sampleRateFloat

            // Mix fundamental and harmonic
            let wave1 = sin(angularFreq1 * time)
            let wave2 = sin(angularFreq2 * time) * 0.5  // Harmonic at half amplitude

            let sample = amplitude * (wave1 + wave2) / 1.5

            leftChannel[frame] = sample
            rightChannel[frame] = sample
        }

        return buffer
    }

    private func generateRealisticHeartbeat(bpm: Double) {
        // Generate realistic heartbeat sound (lub-dub)
        // "Lub" = lower frequency (~40-60 Hz)
        // "Dub" = higher frequency (~80-120 Hz)

        let beatDuration = 60.0 / bpm
        let lubDuration = beatDuration * 0.15  // 15% of cycle
        let dubDuration = beatDuration * 0.10  // 10% of cycle

        // "Lub" sound (S1 - closure of mitral and tricuspid valves)
        let lubBuffer = generatePulse(
            frequency: 50.0,
            amplitude: 0.4 * volume,
            duration: lubDuration
        )

        // "Dub" sound (S2 - closure of aortic and pulmonary valves)
        let dubBuffer = generatePulse(
            frequency: 100.0,
            amplitude: 0.3 * volume,
            duration: dubDuration
        )

        // Schedule lub-dub pattern
        heartbeatOscillator.scheduleBuffer(lubBuffer, at: nil, options: [], completionHandler: nil)

        // Schedule "dub" slightly after "lub"
        let dubDelay = AVAudioTime(sampleTime: AVAudioFramePosition(sampleRate * lubDuration * 1.2), atRate: sampleRate)
        heartbeatOscillator.scheduleBuffer(dubBuffer, at: dubDelay, options: [], completionHandler: nil)
    }

    private func scheduleHeartbeatPulse(bpm: Double) {
        // Schedule periodic pulses at heart rate
        let interval = 60.0 / bpm

        let buffer = generatePulse(
            frequency: 440.0,  // A4 reference
            amplitude: 0.2 * volume,
            duration: 0.05  // 50ms pulse
        )

        heartbeatOscillator.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - Control

    func start() {
        isEnabled = true
        print("🎵 Biofeedback sonification started")
    }

    func stop() {
        isEnabled = false
        hrvOscillator.stop()
        heartbeatOscillator.stop()
        coherenceTone.stop()
        print("🔇 Biofeedback sonification stopped")
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        mixer.volume = volume
    }

    func setMode(_ mode: SonificationMode) {
        sonificationMode = mode
        print("🎵 Sonification mode: \(mode.description)")
    }
}

// MARK: - SwiftUI Integration

extension BiofeedbackSonificationManager {
    /// Update sonification from biofeedback state
    func updateFromBiofeedback(
        hrv: Double,
        heartRate: Double,
        coherence: Double,
        hrvFrequency: Double = 0.1
    ) {
        guard isEnabled else { return }

        sonifyBiofeedbackState(
            hrv: hrv,
            heartRate: heartRate,
            coherence: coherence
        )
    }
}

// MARK: - Debug

#if DEBUG
extension BiofeedbackSonificationManager {
    func testSonification() {
        print("🧪 Testing biofeedback sonification...")

        // Test HRV sonification
        sonifyHRV(frequency: 0.1, power: 0.8)
        print("  HRV: 0.1 Hz (resonant frequency)")

        // Test heart rate sonification
        sonifyHeartRate(bpm: 70.0)
        print("  Heart rate: 70 BPM")

        // Test coherence sonification
        sonifyCoherence(score: 75.0)
        print("  Coherence: 75 (High)")

        print("✅ Sonification test complete")
    }
}
#endif
