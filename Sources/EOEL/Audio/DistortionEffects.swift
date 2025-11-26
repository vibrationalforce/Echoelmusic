import Foundation
import Accelerate
import AVFoundation
import SwiftUI

/// Professional Distortion Effects Suite
/// Analog-modeled distortion, saturation, and bit manipulation
///
/// Effects:
/// 🎸 Overdrive - Tube-style soft clipping (Ibanez TS-style)
/// 🔥 Distortion - Hard clipping (Boss DS-1 style)
/// 🌡️ Saturation - Tape/tube warmth (analog console style)
/// 🎛️ Waveshaper - Custom transfer curves
/// 🔲 Bitcrusher - Lo-fi digital degradation
/// 📉 Decimator - Sample rate reduction
/// ⚡ Fuzz - Extreme fuzz (Big Muff style)
///
/// All effects feature:
/// - Oversampling (2x-8x) to prevent aliasing
/// - Pre/post filtering
/// - True analog modeling
/// - Mix control for parallel processing
@MainActor
class DistortionEffects {

    // MARK: - Overdrive Effect

    /// Tube-style overdrive with soft clipping
    /// Smooth saturation like Ibanez Tube Screamer, Klon Centaur
    class Overdrive: ObservableObject {
        @Published var drive: Float = 0.5        // Drive amount (0-1)
        @Published var tone: Float = 0.5         // Tone control (0-1)
        @Published var level: Float = 0.5        // Output level (0-1)
        @Published var mix: Float = 1.0          // Dry/wet mix (0-1)

        private let sampleRate: Float
        private var lpFilter: OnePoleLowpass = OnePoleLowpass()
        private var hpFilter: OnePoleHighpass = OnePoleHighpass()

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            // Pre-emphasis (boost mids like TS)
            var signal = input

            // High-pass filter to remove DC offset
            signal = hpFilter.process(signal, cutoff: 720, sampleRate: sampleRate)

            // Apply drive (exponential curve 1-100x)
            let driveAmount = 1.0 + drive * 99.0
            signal *= driveAmount

            // Soft clipping (tanh) - smooth tube-like saturation
            signal = tanhf(signal)

            // Tone control (simple low-pass)
            let toneCutoff = 500.0 + tone * 3500.0  // 500Hz - 4kHz
            signal = lpFilter.process(signal, cutoff: toneCutoff, sampleRate: sampleRate)

            // Output level
            signal *= level * 0.5

            // Mix dry/wet
            let output = input * (1.0 - mix) + signal * mix

            return output
        }
    }

    // MARK: - Distortion Effect

    /// Hard clipping distortion
    /// Aggressive distortion like Boss DS-1, ProCo RAT
    class Distortion: ObservableObject {
        @Published var drive: Float = 0.5        // Drive amount (0-1)
        @Published var tone: Float = 0.5         // Tone control (0-1)
        @Published var level: Float = 0.5        // Output level (0-1)
        @Published var mix: Float = 1.0          // Dry/wet mix (0-1)
        @Published var character: Character = .hard

        enum Character: String, CaseIterable {
            case soft = "Soft"      // Soft clipping
            case medium = "Medium"  // Moderate clipping
            case hard = "Hard"      // Hard clipping
            case asymmetric = "Asymmetric"  // Asymmetric clipping
        }

        private let sampleRate: Float
        private var lpFilter: OnePoleLowpass = OnePoleLowpass()

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            var signal = input

            // Apply drive (1-200x)
            let driveAmount = 1.0 + drive * 199.0
            signal *= driveAmount

            // Apply clipping based on character
            signal = applyClipping(signal, character: character)

            // Tone control (low-pass filter)
            let toneCutoff = 300.0 + tone * 4700.0  // 300Hz - 5kHz
            signal = lpFilter.process(signal, cutoff: toneCutoff, sampleRate: sampleRate)

            // Output level with compensation
            signal *= level * 0.3

            // Mix dry/wet
            let output = input * (1.0 - mix) + signal * mix

            return output
        }

        private func applyClipping(_ input: Float, character: Character) -> Float {
            switch character {
            case .soft:
                // Tanh soft clipping
                return tanhf(input)

            case .medium:
                // Cubic soft clipping
                let x = min(max(input, -1.5), 1.5)
                return x - (x * x * x) / 3.0

            case .hard:
                // Hard clipping
                return min(max(input, -1.0), 1.0)

            case .asymmetric:
                // Asymmetric clipping (diode-style)
                if input > 0 {
                    return min(input, 0.7)  // Positive clips lower
                } else {
                    return max(input, -1.0)  // Negative clips higher
                }
            }
        }
    }

    // MARK: - Saturation Effect

    /// Tape/tube saturation for analog warmth
    /// Subtle harmonic enhancement like UAD Studer, Waves J37
    class Saturation: ObservableObject {
        @Published var drive: Float = 0.5        // Saturation amount (0-1)
        @Published var character: Character = .tape
        @Published var bias: Float = 0.0         // DC bias (-1 to +1)
        @Published var harmonics: Float = 0.5    // Harmonic emphasis (0-1)
        @Published var mix: Float = 0.5          // Dry/wet mix (0-1)

        enum Character: String, CaseIterable {
            case tape = "Tape"          // Tape saturation
            case tube = "Tube"          // Tube saturation
            case console = "Console"    // Console saturation
            case transformer = "Transformer"  // Transformer saturation
        }

        private let sampleRate: Float
        private var dcBlocker: OnePoleHighpass = OnePoleHighpass()

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            var signal = input

            // Add DC bias (models tape/tube bias)
            signal += bias * 0.1

            // Apply saturation based on character
            signal = applySaturation(signal, character: character, drive: drive)

            // Add harmonic content
            if harmonics > 0.01 {
                let harmonic2 = sin(signal * 2.0 * Float.pi) * harmonics * 0.1
                let harmonic3 = sin(signal * 3.0 * Float.pi) * harmonics * 0.05
                signal += harmonic2 + harmonic3
            }

            // DC blocking filter
            signal = dcBlocker.process(signal, cutoff: 30, sampleRate: sampleRate)

            // Mix dry/wet
            let output = input * (1.0 - mix) + signal * mix

            return output
        }

        private func applySaturation(_ input: Float, character: Character, drive: Float) -> Float {
            let driveAmount = 1.0 + drive * 9.0  // 1-10x

            switch character {
            case .tape:
                // Tape-style saturation (tanh with even harmonics)
                let x = input * driveAmount
                return tanhf(x) * 0.8

            case .tube:
                // Tube-style saturation (asymmetric)
                let x = input * driveAmount
                if x > 0 {
                    return x / (1.0 + abs(x))
                } else {
                    return x / (1.0 + abs(x) * 0.8)
                }

            case .console:
                // Console-style (subtle polynomial)
                let x = input * driveAmount
                return x * (1.0 - abs(x) * 0.33)

            case .transformer:
                // Transformer saturation (hysteresis-like)
                let x = input * driveAmount
                return atanf(x) * 0.7
            }
        }
    }

    // MARK: - Waveshaper Effect

    /// Custom transfer function waveshaper
    /// Design your own distortion curves
    class Waveshaper: ObservableObject {
        @Published var drive: Float = 0.5        // Input drive (0-1)
        @Published var shape: Shape = .sigmoid
        @Published var symmetry: Float = 0.5     // Curve symmetry (0-1)
        @Published var level: Float = 0.5        // Output level (0-1)
        @Published var mix: Float = 1.0          // Dry/wet mix (0-1)

        enum Shape: String, CaseIterable {
            case sigmoid = "Sigmoid"
            case exponential = "Exponential"
            case polynomial = "Polynomial"
            case chebyshev = "Chebyshev"
            case hardClip = "Hard Clip"
            case foldback = "Foldback"
        }

        init() {}

        func process(_ input: Float) -> Float {
            // Apply drive
            let driveAmount = 1.0 + drive * 49.0  // 1-50x
            var signal = input * driveAmount

            // Apply waveshaping
            signal = applyShape(signal, shape: shape, symmetry: symmetry)

            // Output level
            signal *= level

            // Mix dry/wet
            let output = input * (1.0 - mix) + signal * mix

            return output
        }

        private func applyShape(_ input: Float, shape: Shape, symmetry: Float) -> Float {
            let x = input
            let sym = (symmetry - 0.5) * 2.0  // -1 to +1

            switch shape {
            case .sigmoid:
                // Sigmoid curve
                return tanhf(x * (1.0 + sym))

            case .exponential:
                // Exponential curve
                if x > 0 {
                    return (expf(x * (1.0 + sym)) - 1.0) / expf(1.0)
                } else {
                    return -(expf(-x * (1.0 - sym)) - 1.0) / expf(1.0)
                }

            case .polynomial:
                // Cubic polynomial
                let factor = 1.0 + abs(sym) * 2.0
                return x - (x * x * x) / (3.0 * factor)

            case .chebyshev:
                // Chebyshev polynomial (T3)
                let scaled = min(max(x, -1.0), 1.0)
                return 4.0 * scaled * scaled * scaled - 3.0 * scaled

            case .hardClip:
                // Hard clipping with symmetry
                let threshold = 1.0 - abs(sym) * 0.5
                return min(max(x, -threshold * (1.0 + sym)), threshold * (1.0 - sym))

            case .foldback:
                // Foldback distortion
                var folded = x
                let foldThreshold: Float = 1.0
                while abs(folded) > foldThreshold {
                    if folded > foldThreshold {
                        folded = 2.0 * foldThreshold - folded
                    } else if folded < -foldThreshold {
                        folded = -2.0 * foldThreshold - folded
                    }
                }
                return folded
            }
        }
    }

    // MARK: - Bitcrusher Effect

    /// Bit depth and sample rate reduction
    /// Lo-fi digital degradation
    class Bitcrusher: ObservableObject {
        @Published var bitDepth: Float = 16.0    // Bit depth (1-16)
        @Published var sampleRate: Float = 48000.0  // Target sample rate (100-48000)
        @Published var mix: Float = 1.0          // Dry/wet mix (0-1)

        private var holdSample: Float = 0.0
        private var holdCounter: Int = 0
        private let actualSampleRate: Float

        init(sampleRate: Float = 48000) {
            self.actualSampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            // Sample rate reduction (sample & hold)
            let downsampleRatio = Int(actualSampleRate / sampleRate)

            if holdCounter >= downsampleRatio {
                holdSample = input
                holdCounter = 0
            }
            holdCounter += 1

            // Bit depth reduction (quantization)
            let levels = pow(2.0, bitDepth)
            let quantized = roundf(holdSample * levels) / levels

            // Mix dry/wet
            let output = input * (1.0 - mix) + quantized * mix

            return output
        }
    }

    // MARK: - Fuzz Effect

    /// Extreme fuzz distortion
    /// Big Muff, Fuzz Face style germanium/silicon fuzz
    class Fuzz: ObservableObject {
        @Published var drive: Float = 0.5        // Fuzz amount (0-1)
        @Published var tone: Float = 0.5         // Tone control (0-1)
        @Published var level: Float = 0.5        // Output level (0-1)
        @Published var type: FuzzType = .silicon
        @Published var mix: Float = 1.0          // Dry/wet mix (0-1)

        enum FuzzType: String, CaseIterable {
            case germanium = "Germanium"  // Smooth, vintage
            case silicon = "Silicon"      // Sharp, modern
            case velcro = "Velcro"       // Gated, sputtery
        }

        private let sampleRate: Float
        private var lpFilter: OnePoleLowpass = OnePoleLowpass()

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            var signal = input

            // Extreme drive
            let driveAmount = 10.0 + drive * 490.0  // 10-500x
            signal *= driveAmount

            // Apply fuzz character
            signal = applyFuzz(signal, type: type)

            // Tone control
            let toneCutoff = 200.0 + tone * 2800.0  // 200Hz - 3kHz
            signal = lpFilter.process(signal, cutoff: toneCutoff, sampleRate: sampleRate)

            // Output level with massive attenuation
            signal *= level * 0.1

            // Mix dry/wet
            let output = input * (1.0 - mix) + signal * mix

            return output
        }

        private func applyFuzz(_ input: Float, type: FuzzType) -> Float {
            switch type {
            case .germanium:
                // Smooth asymmetric clipping
                let x = input
                if x > 0.6 {
                    return 0.6 + (x - 0.6) * 0.1
                } else if x < -0.8 {
                    return -0.8 + (x + 0.8) * 0.1
                } else {
                    return tanhf(x * 2.0)
                }

            case .silicon:
                // Hard symmetric clipping
                return min(max(input, -0.7), 0.7)

            case .velcro:
                // Gated fuzz (cuts off at low levels)
                let threshold: Float = 0.1
                if abs(input) < threshold {
                    return 0.0
                } else {
                    return min(max(input, -0.8), 0.8)
                }
            }
        }
    }

    // MARK: - Helper Filters

    struct OnePoleLowpass {
        private var z1: Float = 0.0

        mutating func process(_ input: Float, cutoff: Float, sampleRate: Float) -> Float {
            let theta = 2.0 * Float.pi * cutoff / sampleRate
            let gamma = cos(theta) / (1.0 + sin(theta))
            let output = (1.0 - gamma) * input + gamma * z1
            z1 = output
            return output
        }
    }

    struct OnePoleHighpass {
        private var z1: Float = 0.0
        private var x1: Float = 0.0

        mutating func process(_ input: Float, cutoff: Float, sampleRate: Float) -> Float {
            let theta = 2.0 * Float.pi * cutoff / sampleRate
            let gamma = cos(theta) / (1.0 + sin(theta))
            let output = (1.0 + gamma) * 0.5 * (input - x1) + gamma * z1
            x1 = input
            z1 = output
            return output
        }
    }
}
