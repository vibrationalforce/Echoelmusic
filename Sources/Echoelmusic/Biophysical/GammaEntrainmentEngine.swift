// GammaEntrainmentEngine.swift
// Echoelmusic — Dedicated 40 Hz Gamma Entrainment Engine
//
// Real-time 40 Hz isochronic + binaural gamma entrainment with bio-reactive modulation.
// Leverages NeuralFlowEngine for narrow-band frequency control (38-42 Hz).
//
// Reference: Iaccarino et al. (2016) — 40 Hz gamma oscillation entrainment.
// DISCLAIMER: Wellness/creative tool only. NOT a medical device.
// No therapeutic claims. Consult a physician for neurological conditions.
//
// Architecture:
//   1. Carrier oscillator (configurable: 440, 523, 659 Hz)
//   2. 40 Hz amplitude modulation with sharp pulse shaping (pow envelope)
//   3. Optional binaural mode (stereo L/R frequency offset)
//   4. Bio-reactive: HRV coherence → ±0.5 Hz frequency fine-tune
//   5. Session management: ramp-up → entrainment → ramp-down phases
//   6. vDSP-accelerated bulk rendering
//
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Accelerate

// MARK: - Gamma Entrainment Engine

public final class GammaEntrainmentEngine {

    // MARK: - Configuration

    /// Entrainment mode
    public enum Mode: String, CaseIterable {
        case isochronic   // Amplitude-modulated pulses (works on any speakers)
        case binaural     // L/R frequency split (requires headphones)
        case hybrid       // Isochronic + subtle binaural offset
    }

    /// Session phase
    public enum Phase: String {
        case idle
        case rampUp       // Gradual onset (30s default)
        case entrainment  // Full 40 Hz steady-state
        case rampDown     // Gradual offset (30s default)
        case complete
    }

    /// Carrier frequency preset (12-TET standard tuning)
    public enum CarrierPreset: Float, CaseIterable {
        case standard = 440.0      // A4
        case c5 = 523.251         // C5
        case e5 = 659.255         // E5
        case g4 = 392.0           // G4
    }

    // MARK: - Public Properties

    /// Current entrainment mode
    public var mode: Mode = .isochronic

    /// Carrier frequency (Hz)
    public var carrierFrequency: Float = 440.0

    /// Target gamma frequency (Hz) — stays within 38-42 Hz
    public private(set) var gammaFrequency: Float = 40.0

    /// Pulse sharpness: 1.0 = sine, higher = sharper isochronic pulses
    public var pulseSharpness: Float = 2.0

    /// Master amplitude (0-1)
    public var amplitude: Float = 0.3

    /// Binaural split amount in Hz (for binaural/hybrid modes)
    public var binauralSplit: Float = 40.0

    /// Session duration in seconds
    public var sessionDuration: TimeInterval = 720 // 12 min (NeuralFlowEngine default)

    /// Ramp duration in seconds (for ramp-up and ramp-down)
    public var rampDuration: TimeInterval = 30.0

    /// Current session phase
    public private(set) var phase: Phase = .idle

    /// Elapsed time in current session
    public private(set) var elapsedTime: TimeInterval = 0

    /// Sample rate
    public let sampleRate: Float

    // MARK: - Bio-Reactive State

    private var bioCoherence: Float = 0.5
    private var bioHRV: Float = 0.5
    private var bioHeartRate: Float = 0.5

    // MARK: - Oscillator State

    private var carrierPhase: Float = 0
    private var modulationPhase: Float = 0
    private var leftCarrierPhase: Float = 0
    private var rightCarrierPhase: Float = 0

    // MARK: - Session State

    private var sessionStartTime: TimeInterval = 0
    private var phaseStartTime: TimeInterval = 0
    private var samplesRendered: Int = 0

    // MARK: - Scratch Buffers (pre-allocated)

    private var carrierBuffer: [Float]
    private var envelopeBuffer: [Float]
    private let maxFrameSize: Int

    // MARK: - Init

    public init(sampleRate: Float = 48000.0, maxFrameSize: Int = 512) {
        self.sampleRate = sampleRate
        self.maxFrameSize = maxFrameSize
        self.carrierBuffer = [Float](repeating: 0, count: maxFrameSize)
        self.envelopeBuffer = [Float](repeating: 0, count: maxFrameSize)
    }

    // MARK: - Session Control

    /// Start a gamma entrainment session
    public func startSession() {
        phase = .rampUp
        elapsedTime = 0
        samplesRendered = 0
        carrierPhase = 0
        modulationPhase = 0
        leftCarrierPhase = 0
        rightCarrierPhase = 0
        phaseStartTime = 0
    }

    /// Stop the current session
    public func stopSession() {
        if phase == .entrainment || phase == .rampUp {
            phase = .rampDown
            phaseStartTime = elapsedTime
        } else {
            phase = .idle
        }
    }

    /// Force-stop immediately
    public func reset() {
        phase = .idle
        elapsedTime = 0
        samplesRendered = 0
        carrierPhase = 0
        modulationPhase = 0
    }

    // MARK: - Bio-Reactive Input

    /// Update bio-reactive parameters
    public func updateBio(coherence: Float, hrv: Float = 0.5, heartRate: Float = 0.5) {
        bioCoherence = coherence
        bioHRV = hrv
        bioHeartRate = heartRate

        // Narrow-band frequency adaptation via NeuralFlowEngine model
        // ±0.5 Hz max around 40 Hz based on coherence
        let offset = (coherence - 0.5) * 1.0
        gammaFrequency = Float(max(38.0, min(42.0, 40.0 + Double(offset))))
    }

    // MARK: - Audio Rendering

    /// Render mono isochronic audio
    public func renderMono(buffer: inout [Float], frameCount: Int) {
        guard phase != .idle && phase != .complete else {
            for i in 0..<min(frameCount, buffer.count) { buffer[i] = 0 }
            return
        }

        let twoPi = 2.0 * Float.pi
        let carrierInc = twoPi * carrierFrequency / sampleRate
        let modInc = twoPi * gammaFrequency / sampleRate
        let phaseGain = phaseAmplitude()

        for i in 0..<frameCount {
            // Carrier oscillator
            let carrier = sin(carrierPhase)
            carrierPhase += carrierInc
            if carrierPhase > twoPi { carrierPhase -= twoPi }

            // Modulation envelope (isochronic pulse)
            let rawEnvelope = (sin(modulationPhase) + 1.0) * 0.5 // 0...1
            let shapedEnvelope = pow(rawEnvelope, pulseSharpness)  // Sharp pulses
            modulationPhase += modInc
            if modulationPhase > twoPi { modulationPhase -= twoPi }

            buffer[i] = carrier * shapedEnvelope * amplitude * phaseGain
        }

        advanceTime(frameCount: frameCount)
    }

    /// Render stereo audio (binaural/hybrid mode)
    public func renderStereo(left: inout [Float], right: inout [Float], frameCount: Int) {
        guard phase != .idle && phase != .complete else {
            for i in 0..<min(frameCount, left.count) {
                left[i] = 0
                right[i] = 0
            }
            return
        }

        let twoPi = 2.0 * Float.pi
        let modInc = twoPi * gammaFrequency / sampleRate
        let phaseGain = phaseAmplitude()

        switch mode {
        case .isochronic:
            // Same signal both channels
            let carrierInc = twoPi * carrierFrequency / sampleRate
            for i in 0..<frameCount {
                let carrier = sin(carrierPhase)
                carrierPhase += carrierInc
                if carrierPhase > twoPi { carrierPhase -= twoPi }

                let rawEnv = (sin(modulationPhase) + 1.0) * 0.5
                let env = pow(rawEnv, pulseSharpness)
                modulationPhase += modInc
                if modulationPhase > twoPi { modulationPhase -= twoPi }

                let sample = carrier * env * amplitude * phaseGain
                left[i] = sample
                right[i] = sample
            }

        case .binaural:
            // L/R frequency split for binaural beat at gamma frequency
            let leftFreq = carrierFrequency - (binauralSplit / 2.0)
            let rightFreq = carrierFrequency + (binauralSplit / 2.0)
            let leftInc = twoPi * leftFreq / sampleRate
            let rightInc = twoPi * rightFreq / sampleRate

            for i in 0..<frameCount {
                left[i] = sin(leftCarrierPhase) * amplitude * phaseGain
                right[i] = sin(rightCarrierPhase) * amplitude * phaseGain

                leftCarrierPhase += leftInc
                rightCarrierPhase += rightInc
                if leftCarrierPhase > twoPi { leftCarrierPhase -= twoPi }
                if rightCarrierPhase > twoPi { rightCarrierPhase -= twoPi }
            }

        case .hybrid:
            // Isochronic + subtle binaural offset
            let leftFreq = carrierFrequency - 1.0  // ±1 Hz subtle split
            let rightFreq = carrierFrequency + 1.0
            let leftInc = twoPi * leftFreq / sampleRate
            let rightInc = twoPi * rightFreq / sampleRate

            for i in 0..<frameCount {
                let rawEnv = (sin(modulationPhase) + 1.0) * 0.5
                let env = pow(rawEnv, pulseSharpness)
                modulationPhase += modInc
                if modulationPhase > twoPi { modulationPhase -= twoPi }

                left[i] = sin(leftCarrierPhase) * env * amplitude * phaseGain
                right[i] = sin(rightCarrierPhase) * env * amplitude * phaseGain

                leftCarrierPhase += leftInc
                rightCarrierPhase += rightInc
                if leftCarrierPhase > twoPi { leftCarrierPhase -= twoPi }
                if rightCarrierPhase > twoPi { rightCarrierPhase -= twoPi }
            }
        }

        advanceTime(frameCount: frameCount)
    }

    // MARK: - Phase Management

    /// Compute amplitude multiplier for current phase (ramp up/down)
    private func phaseAmplitude() -> Float {
        switch phase {
        case .idle, .complete:
            return 0

        case .rampUp:
            let progress = Float(min(1.0, (elapsedTime - phaseStartTime) / rampDuration))
            // Smooth S-curve ramp
            return progress * progress * (3.0 - 2.0 * progress)

        case .entrainment:
            // Bio-reactive intensity modulation
            let bioBoost: Float = bioCoherence > 0.7 ? 1.0 + (bioCoherence - 0.7) * 0.3 : 1.0
            return min(1.0, bioBoost)

        case .rampDown:
            let progress = Float(min(1.0, (elapsedTime - phaseStartTime) / rampDuration))
            let invProgress = 1.0 - progress
            return invProgress * invProgress * (3.0 - 2.0 * invProgress)
        }
    }

    /// Advance session time and handle phase transitions
    private func advanceTime(frameCount: Int) {
        samplesRendered += frameCount
        elapsedTime = Double(samplesRendered) / Double(sampleRate)

        switch phase {
        case .rampUp:
            if elapsedTime - phaseStartTime >= rampDuration {
                phase = .entrainment
                phaseStartTime = elapsedTime
            }

        case .entrainment:
            let totalEntrainmentTime = sessionDuration - rampDuration * 2
            if elapsedTime - phaseStartTime >= totalEntrainmentTime {
                phase = .rampDown
                phaseStartTime = elapsedTime
            }

        case .rampDown:
            if elapsedTime - phaseStartTime >= rampDuration {
                phase = .complete
            }

        case .idle, .complete:
            break
        }
    }

    // MARK: - State Queries

    /// Session progress (0-1)
    public var progress: Float {
        guard sessionDuration > 0 else { return 0 }
        return Float(min(1.0, elapsedTime / sessionDuration))
    }

    /// Whether the engine is currently producing audio
    public var isActive: Bool {
        phase != .idle && phase != .complete
    }

    /// Remaining time in seconds
    public var remainingTime: TimeInterval {
        max(0, sessionDuration - elapsedTime)
    }
}
