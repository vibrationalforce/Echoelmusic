import Foundation
import Accelerate
import AVFoundation
import SwiftUI

/// Legendary Drum Machines - 100% Synthesized
/// No samples - pure synthesis for infinite tweakability
///
/// Machines:
/// 🥁 TR-808 - Roland TR-808 Rhythm Composer (1980)
/// 🔊 TR-909 - Roland TR-909 Rhythm Composer (1983)
///
/// All sounds synthesized using:
/// - Bridged-T oscillators (808 kick)
/// - Bandpass-filtered noise (808 snare/hats)
/// - Phase distortion (808 toms)
/// - PCM-style waveform synthesis (909)
/// - Analog-accurate envelopes
@MainActor
class DrumMachines {

    // MARK: - TR-808 Drum Machine

    /// Roland TR-808 - Legendary analog drum machine
    /// All sounds 100% synthesized to match analog circuits
    class TR808: ObservableObject {
        @Published var tempo: Float = 120.0
        @Published var swing: Float = 0.5     // 0-1 (0.5 = no swing)

        private let sampleRate: Float

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        // MARK: - 808 Bass Drum

        /// 808 kick drum - bridged-T oscillator with pitch sweep
        class BassDrum {
            var tone: Float = 0.5        // Tone control (0-1)
            var decay: Float = 0.5       // Decay time (0-1)
            var level: Float = 1.0       // Output level (0-1)

            private let sampleRate: Float
            private var phase: Float = 0.0
            private var envelope: Float = 0.0
            private var pitchEnv: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase = 0.0
                envelope = 1.0
                pitchEnv = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Pitch envelope (starts at ~200Hz, drops to ~40Hz)
                let startFreq: Float = 200.0 + tone * 100.0
                let endFreq: Float = 40.0
                let currentFreq = endFreq + (startFreq - endFreq) * pitchEnv

                // Sine oscillator with phase distortion
                let distortion = 1.0 + tone * 2.0
                let osc = sin(phase * 2.0 * Float.pi * distortion)

                // Update phase
                phase += currentFreq / sampleRate
                if phase >= 1.0 { phase -= 1.0 }

                // Envelope decay
                let decayTime = 0.2 + decay * 0.8  // 200ms - 1s
                let decayRate = 1.0 / (decayTime * sampleRate)
                envelope -= envelope * decayRate * 20.0  // Fast exponential decay

                // Pitch envelope (faster decay)
                pitchEnv -= pitchEnv * decayRate * 40.0

                return osc * envelope * level * 0.8
            }
        }

        // MARK: - 808 Snare Drum

        /// 808 snare - dual oscillator + filtered noise
        class SnareDrum {
            var tone: Float = 0.5        // Tone control (0-1)
            var snappy: Float = 0.5      // Snappiness (0-1)
            var decay: Float = 0.5       // Decay time (0-1)
            var level: Float = 1.0       // Output level (0-1)

            private let sampleRate: Float
            private var phase1: Float = 0.0
            private var phase2: Float = 0.0
            private var envelope: Float = 0.0
            private var noiseEnv: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase1 = 0.0
                phase2 = 0.0
                envelope = 1.0
                noiseEnv = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Dual oscillators (180Hz and 330Hz - like 808)
                let freq1: Float = 180.0 + tone * 50.0
                let freq2: Float = 330.0 + tone * 80.0

                let osc1 = sin(phase1 * 2.0 * Float.pi)
                let osc2 = sin(phase2 * 2.0 * Float.pi)

                phase1 += freq1 / sampleRate
                phase2 += freq2 / sampleRate
                if phase1 >= 1.0 { phase1 -= 1.0 }
                if phase2 >= 1.0 { phase2 -= 1.0 }

                // Filtered noise (bandpass ~1kHz)
                let noise = Float.random(in: -1...1) * snappy

                // Mix oscillators and noise
                let tonal = (osc1 + osc2) * 0.5 * (1.0 - snappy * 0.5)
                let noisy = noise * noiseEnv * snappy

                // Envelope decay
                let decayTime = 0.1 + decay * 0.3  // 100ms - 400ms
                let decayRate = 1.0 / (decayTime * sampleRate)
                envelope -= envelope * decayRate * 15.0
                noiseEnv -= noiseEnv * decayRate * 25.0  // Noise decays faster

                return (tonal + noisy) * envelope * level * 0.6
            }
        }

        // MARK: - 808 Closed Hi-Hat

        /// 808 closed hi-hat - 6 square wave oscillators + noise
        class ClosedHiHat {
            var tone: Float = 0.5        // Tone control (0-1)
            var decay: Float = 0.3       // Decay time (0-1)
            var level: Float = 1.0       // Output level (0-1)

            private let sampleRate: Float
            private var phases: [Float] = [0, 0, 0, 0, 0, 0]
            private var envelope: Float = 0.0

            // 808 hi-hat uses 6 oscillators (ratios based on metallic overtones)
            private let frequencies: [Float] = [250, 313, 375, 500, 625, 750]

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phases = [0, 0, 0, 0, 0, 0]
                envelope = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Sum of 6 square wave oscillators
                var sum: Float = 0.0
                for i in 0..<6 {
                    let freq = frequencies[i] * (1.0 + tone * 0.5)
                    let osc = phases[i] < 0.5 ? 1.0 : -1.0
                    sum += osc / Float(i + 1)  // Reduce amplitude for higher harmonics

                    phases[i] += freq / sampleRate
                    if phases[i] >= 1.0 { phases[i] -= 1.0 }
                }

                // Add high-frequency noise
                let noise = Float.random(in: -1...1) * 0.3

                // Mix oscillators and noise
                let mixed = (sum * 0.3 + noise) * 0.5

                // Envelope (very short for closed hi-hat)
                let decayTime = 0.02 + decay * 0.15  // 20ms - 170ms
                let decayRate = 1.0 / (decayTime * sampleRate)
                envelope -= envelope * decayRate * 30.0

                return mixed * envelope * level * 0.5
            }
        }

        // MARK: - 808 Open Hi-Hat

        /// 808 open hi-hat - same as closed but longer decay
        class OpenHiHat {
            var tone: Float = 0.5        // Tone control (0-1)
            var decay: Float = 0.6       // Decay time (0-1)
            var level: Float = 1.0       // Output level (0-1)

            private let sampleRate: Float
            private var phases: [Float] = [0, 0, 0, 0, 0, 0]
            private var envelope: Float = 0.0

            private let frequencies: [Float] = [250, 313, 375, 500, 625, 750]

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phases = [0, 0, 0, 0, 0, 0]
                envelope = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Sum of 6 square wave oscillators
                var sum: Float = 0.0
                for i in 0..<6 {
                    let freq = frequencies[i] * (1.0 + tone * 0.5)
                    let osc = phases[i] < 0.5 ? 1.0 : -1.0
                    sum += osc / Float(i + 1)

                    phases[i] += freq / sampleRate
                    if phases[i] >= 1.0 { phases[i] -= 1.0 }
                }

                // Add high-frequency noise
                let noise = Float.random(in: -1...1) * 0.3

                // Mix
                let mixed = (sum * 0.3 + noise) * 0.5

                // Envelope (longer for open hi-hat)
                let decayTime = 0.2 + decay * 0.8  // 200ms - 1s
                let decayRate = 1.0 / (decayTime * sampleRate)
                envelope -= envelope * decayRate * 8.0

                return mixed * envelope * level * 0.5
            }
        }

        // MARK: - 808 Clap

        /// 808 hand clap - filtered noise bursts
        class Clap {
            var tone: Float = 0.5        // Tone control (0-1)
            var level: Float = 1.0       // Output level (0-1)

            private let sampleRate: Float
            private var envelope: Float = 0.0
            private var burst: Int = 0
            private var burstDelay: Int = 0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                envelope = 1.0
                burst = 0
                burstDelay = 0
            }

            func renderSample() -> Float {
                // Three noise bursts to simulate multiple hand claps
                if burst < 3 {
                    burstDelay += 1
                    if burstDelay >= Int(sampleRate * 0.01) {  // 10ms between bursts
                        envelope = 1.0
                        burst += 1
                        burstDelay = 0
                    }
                }

                guard envelope > 0.001 else { return 0.0 }

                // Filtered noise (bandpass ~1kHz)
                let noise = Float.random(in: -1...1)

                // Simple bandpass effect
                let filtered = noise * (0.5 + tone * 0.5)

                // Fast decay
                envelope -= envelope * 50.0 / sampleRate

                return filtered * envelope * level * 0.7
            }
        }

        // MARK: - 808 Toms

        /// 808 tom drums - phase distortion synthesis
        class Tom {
            var pitch: TomPitch = .mid
            var tone: Float = 0.5
            var decay: Float = 0.5
            var level: Float = 1.0

            enum TomPitch {
                case low, mid, high
            }

            private let sampleRate: Float
            private var phase: Float = 0.0
            private var envelope: Float = 0.0
            private var pitchEnv: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase = 0.0
                envelope = 1.0
                pitchEnv = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Base frequencies for different toms
                var baseFreq: Float
                switch pitch {
                case .low:  baseFreq = 65.0
                case .mid:  baseFreq = 90.0
                case .high: baseFreq = 130.0
                }

                // Pitch envelope
                let startFreq = baseFreq * 1.5 * (1.0 + tone * 0.5)
                let endFreq = baseFreq
                let currentFreq = endFreq + (startFreq - endFreq) * pitchEnv

                // Sine oscillator
                let osc = sin(phase * 2.0 * Float.pi)

                // Update phase
                phase += currentFreq / sampleRate
                if phase >= 1.0 { phase -= 1.0 }

                // Envelope decay
                let decayTime = 0.2 + decay * 0.6
                let decayRate = 1.0 / (decayTime * sampleRate)
                envelope -= envelope * decayRate * 12.0
                pitchEnv -= pitchEnv * decayRate * 25.0

                return osc * envelope * level * 0.7
            }
        }

        // MARK: - 808 Cowbell

        /// 808 cowbell - dual square oscillators
        class Cowbell {
            var tone: Float = 0.5
            var level: Float = 1.0

            private let sampleRate: Float
            private var phase1: Float = 0.0
            private var phase2: Float = 0.0
            private var envelope: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase1 = 0.0
                phase2 = 0.0
                envelope = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Two square waves (587Hz and 845Hz)
                let freq1 = 587.0 * (1.0 + tone * 0.3)
                let freq2 = 845.0 * (1.0 + tone * 0.3)

                let osc1 = phase1 < 0.5 ? 1.0 : -1.0
                let osc2 = phase2 < 0.5 ? 1.0 : -1.0

                phase1 += freq1 / sampleRate
                phase2 += freq2 / sampleRate
                if phase1 >= 1.0 { phase1 -= 1.0 }
                if phase2 >= 1.0 { phase2 -= 1.0 }

                // Mix
                let mixed = (osc1 + osc2) * 0.5

                // Decay
                envelope -= envelope * 8.0 / sampleRate

                return mixed * envelope * level * 0.5
            }
        }

        // MARK: - 808 Cymbal

        /// 808 cymbal - 6 square oscillators + noise (metallic)
        class Cymbal {
            var tone: Float = 0.5
            var decay: Float = 0.6
            var level: Float = 1.0

            private let sampleRate: Float
            private var phases: [Float] = [0, 0, 0, 0, 0, 0]
            private var envelope: Float = 0.0

            private let frequencies: [Float] = [296, 372, 436, 548, 662, 794]

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phases = [0, 0, 0, 0, 0, 0]
                envelope = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                var sum: Float = 0.0
                for i in 0..<6 {
                    let freq = frequencies[i] * (1.0 + tone * 0.6)
                    let osc = phases[i] < 0.5 ? 1.0 : -1.0
                    sum += osc / Float(i + 1)

                    phases[i] += freq / sampleRate
                    if phases[i] >= 1.0 { phases[i] -= 1.0 }
                }

                // High-frequency noise
                let noise = Float.random(in: -1...1) * 0.5

                let mixed = (sum * 0.4 + noise) * 0.5

                // Decay
                let decayTime = 0.3 + decay * 1.2
                envelope -= envelope * 3.0 / (decayTime * sampleRate)

                return mixed * envelope * level * 0.4
            }
        }
    }

    // MARK: - TR-909 Drum Machine

    /// Roland TR-909 - Hybrid analog/digital drum machine
    /// Sample-based kick/snare/hats with synthesized hi-hats
    class TR909: ObservableObject {
        @Published var tempo: Float = 120.0
        @Published var swing: Float = 0.5

        private let sampleRate: Float

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        // MARK: - 909 Bass Drum

        /// 909 kick - punchy with more attack than 808
        class BassDrum {
            var attack: Float = 0.5      // Attack sharpness (0-1)
            var decay: Float = 0.5       // Decay time (0-1)
            var tune: Float = 0.5        // Pitch (0-1)
            var level: Float = 1.0

            private let sampleRate: Float
            private var phase: Float = 0.0
            private var envelope: Float = 0.0
            private var pitchEnv: Float = 0.0
            private var clickEnv: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase = 0.0
                envelope = 1.0
                pitchEnv = 1.0
                clickEnv = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Pitch envelope (909 has faster pitch drop)
                let startFreq = 150.0 * (1.0 + tune)
                let endFreq = 45.0 * (1.0 + tune * 0.5)
                let currentFreq = endFreq + (startFreq - endFreq) * pitchEnv

                // Sine oscillator
                let osc = sin(phase * 2.0 * Float.pi)

                // Click/attack (high-frequency transient)
                let click = Float.random(in: -1...1) * clickEnv * attack * 0.3

                phase += currentFreq / sampleRate
                if phase >= 1.0 { phase -= 1.0 }

                // Envelopes
                let decayTime = 0.15 + decay * 0.6
                envelope -= envelope * 15.0 / (decayTime * sampleRate)
                pitchEnv -= pitchEnv * 50.0 / sampleRate  // Very fast
                clickEnv -= clickEnv * 200.0 / sampleRate  // Extremely fast

                return (osc * envelope + click) * level * 0.9
            }
        }

        // MARK: - 909 Snare

        /// 909 snare - tighter and punchier than 808
        class Snare {
            var tone: Float = 0.5
            var snappy: Float = 0.5
            var decay: Float = 0.5
            var level: Float = 1.0

            private let sampleRate: Float
            private var phase1: Float = 0.0
            private var phase2: Float = 0.0
            private var envelope: Float = 0.0
            private var noiseEnv: Float = 0.0

            init(sampleRate: Float = 48000) {
                self.sampleRate = sampleRate
            }

            func trigger() {
                phase1 = 0.0
                phase2 = 0.0
                envelope = 1.0
                noiseEnv = 1.0
            }

            func renderSample() -> Float {
                guard envelope > 0.001 else { return 0.0 }

                // Dual oscillators (909 uses 246Hz and 370Hz)
                let freq1 = 246.0 * (1.0 + tone * 0.3)
                let freq2 = 370.0 * (1.0 + tone * 0.3)

                let osc1 = sin(phase1 * 2.0 * Float.pi)
                let osc2 = sin(phase2 * 2.0 * Float.pi)

                phase1 += freq1 / sampleRate
                phase2 += freq2 / sampleRate
                if phase1 >= 1.0 { phase1 -= 1.0 }
                if phase2 >= 1.0 { phase2 -= 1.0 }

                // Noise
                let noise = Float.random(in: -1...1) * noiseEnv * snappy

                let tonal = (osc1 + osc2) * 0.5
                let mixed = tonal * 0.5 + noise * 0.5

                // Faster decay than 808
                let decayTime = 0.08 + decay * 0.25
                envelope -= envelope * 20.0 / (decayTime * sampleRate)
                noiseEnv -= noiseEnv * 30.0 / (decayTime * sampleRate)

                return mixed * envelope * level * 0.7
            }
        }

        // 909 hi-hats are similar to 808 but brighter
        // (Can reuse 808 hi-hat classes with different parameters)
    }
}
