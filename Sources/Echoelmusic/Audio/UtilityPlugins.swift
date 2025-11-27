import Foundation
import Accelerate
import AVFoundation
import SwiftUI

/// Professional Utility Plugins
/// Essential tools for mixing, mastering, and analysis
///
/// Plugins:
/// 🚪 Gate - Noise gate with hysteresis
/// 📈 Expander - Upward/downward expansion
/// 📊 Spectrum Analyzer - Real-time FFT analyzer
/// 🎚️ Auto-Gain - Loudness normalization
/// ⚖️ Stereo Width - M/S width control
/// 🔍 Oscilloscope - Waveform visualization
/// 📉 Level Meter - Peak/RMS metering
@MainActor
class UtilityPlugins {

    // MARK: - Noise Gate

    /// Professional noise gate with look-ahead and hysteresis
    /// Removes noise during quiet passages
    class Gate: ObservableObject {
        @Published var threshold: Float = -40.0    // Threshold dB (-80 to 0)
        @Published var ratio: Float = 10.0         // Gate ratio (1-inf)
        @Published var attack: Float = 1.0         // Attack time ms (0.1-100)
        @Published var hold: Float = 10.0          // Hold time ms (0-1000)
        @Published var release: Float = 100.0      // Release time ms (10-1000)
        @Published var hysteresis: Float = 6.0     // Hysteresis dB (0-12)
        @Published var range: Float = -80.0        // Gate range dB (-80 to 0)

        private let sampleRate: Float
        private var envelope: Float = 0.0
        private var holdCounter: Int = 0
        private var isOpen: Bool = false

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            // Convert input to dB
            let inputLevel = 20.0 * log10(max(abs(input), 0.00001))

            // Determine if gate should be open or closed (with hysteresis)
            if isOpen {
                // Close gate if below threshold - hysteresis
                if inputLevel < threshold - hysteresis {
                    isOpen = false
                    holdCounter = 0
                } else {
                    // Reset hold counter if above threshold
                    holdCounter = Int(hold * sampleRate / 1000.0)
                }
            } else {
                // Open gate if above threshold
                if inputLevel > threshold {
                    isOpen = true
                    holdCounter = Int(hold * sampleRate / 1000.0)
                }
            }

            // Hold phase
            if holdCounter > 0 {
                holdCounter -= 1
                isOpen = true
            }

            // Calculate target gain
            let targetGain: Float = isOpen ? 1.0 : dbToLinear(range)

            // Envelope follower with attack/release
            if targetGain > envelope {
                // Attack
                let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * targetGain
            } else {
                // Release
                let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * targetGain
            }

            return input * envelope
        }

        private func dbToLinear(_ db: Float) -> Float {
            return pow(10.0, db / 20.0)
        }
    }

    // MARK: - Expander

    /// Dynamic range expander
    /// Increases dynamic range (opposite of compressor)
    class Expander: ObservableObject {
        @Published var threshold: Float = -40.0    // Threshold dB (-80 to 0)
        @Published var ratio: Float = 2.0          // Expansion ratio (1-10)
        @Published var attack: Float = 10.0        // Attack time ms (0.1-100)
        @Published var release: Float = 100.0      // Release time ms (10-1000)
        @Published var knee: Float = 6.0           // Knee width dB (0-12)
        @Published var makeupGain: Float = 0.0     // Makeup gain dB (-20 to +20)
        @Published var mode: Mode = .downward

        enum Mode: String, CaseIterable {
            case downward = "Downward"  // Reduces gain below threshold
            case upward = "Upward"      // Increases gain below threshold
        }

        private let sampleRate: Float
        private var envelope: Float = 0.0

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            // Calculate input level in dB
            let inputLevel = 20.0 * log10(max(abs(input), 0.00001))

            // Calculate gain reduction
            var gainReduction: Float = 0.0

            if mode == .downward {
                // Downward expansion (reduce gain below threshold)
                if inputLevel < threshold {
                    if inputLevel > threshold - knee {
                        // Soft knee
                        let delta = threshold - inputLevel
                        gainReduction = delta * (ratio - 1.0) * (delta / (2.0 * knee))
                    } else {
                        // Hard expansion
                        gainReduction = (threshold - inputLevel) * (ratio - 1.0)
                    }
                }
            } else {
                // Upward expansion (increase gain above threshold)
                if inputLevel > threshold {
                    gainReduction = -(inputLevel - threshold) * (ratio - 1.0)
                }
            }

            // Convert gain reduction to linear
            let targetGain = pow(10.0, -gainReduction / 20.0)

            // Envelope follower
            if targetGain < envelope {
                // Attack (faster)
                let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * targetGain
            } else {
                // Release (slower)
                let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * targetGain
            }

            // Apply gain and makeup gain
            let makeupLinear = pow(10.0, makeupGain / 20.0)
            return input * envelope * makeupLinear
        }
    }

    // MARK: - Spectrum Analyzer

    /// Real-time FFT spectrum analyzer
    /// Visualizes frequency content
    class SpectrumAnalyzer: ObservableObject {
        @Published var magnitudes: [Float] = []
        @Published var fftSize: Int = 2048
        @Published var smoothing: Float = 0.7      // Smoothing factor (0-1)
        @Published var minFreq: Float = 20.0       // Minimum frequency Hz
        @Published var maxFreq: Float = 20000.0    // Maximum frequency Hz
        @Published var minDB: Float = -80.0        // Minimum dB display
        @Published var maxDB: Float = 0.0          // Maximum dB display

        private let sampleRate: Float
        private var fftSetup: vDSP_DFT_Setup?
        private var realParts: [Float]
        private var imagParts: [Float]
        private var inputBuffer: [Float]
        private var smoothedMagnitudes: [Float]

        init(sampleRate: Float = 48000, fftSize: Int = 2048) {
            self.sampleRate = sampleRate
            self.fftSize = fftSize
            self.realParts = [Float](repeating: 0, count: fftSize)
            self.imagParts = [Float](repeating: 0, count: fftSize)
            self.inputBuffer = [Float](repeating: 0, count: fftSize)
            self.smoothedMagnitudes = [Float](repeating: 0, count: fftSize / 2)

            // Create FFT setup
            self.fftSetup = vDSP_DFT_zop_CreateSetup(
                nil,
                vDSP_Length(fftSize),
                vDSP_DFT_Direction.FORWARD
            )
        }

        func process(_ input: Float) {
            // Shift buffer and add new sample
            inputBuffer.removeFirst()
            inputBuffer.append(input)

            // Copy to FFT buffers
            for i in 0..<fftSize {
                realParts[i] = inputBuffer[i]
                imagParts[i] = 0
            }

            // Apply Hann window
            var window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(realParts, 1, window, 1, &realParts, 1, vDSP_Length(fftSize))

            // Perform FFT
            guard let setup = fftSetup else { return }
            vDSP_DFT_Execute(setup, &realParts, &imagParts, &realParts, &imagParts)

            // Calculate magnitudes
            var newMagnitudes = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<(fftSize / 2) {
                let magnitude = sqrt(realParts[i] * realParts[i] + imagParts[i] * imagParts[i])
                let db = 20.0 * log10(max(magnitude / Float(fftSize), 0.00001))

                // Smooth magnitudes
                smoothedMagnitudes[i] = smoothedMagnitudes[i] * smoothing + db * (1.0 - smoothing)
                newMagnitudes[i] = smoothedMagnitudes[i]
            }

            DispatchQueue.main.async { [weak self] in
                self?.magnitudes = newMagnitudes
            }
        }

        func frequencyForBin(_ bin: Int) -> Float {
            return Float(bin) * sampleRate / Float(fftSize)
        }

        deinit {
            if let setup = fftSetup {
                vDSP_DFT_DestroySetup(setup)
            }
        }
    }

    // MARK: - Auto-Gain

    /// Automatic gain control / loudness normalization
    /// Maintains consistent output level
    class AutoGain: ObservableObject {
        @Published var targetLevel: Float = -20.0   // Target level dB (-40 to 0)
        @Published var speed: Float = 0.5            // Response speed (0-1)
        @Published var maxGain: Float = 20.0         // Max gain dB (0-40)
        @Published var maxAttenuation: Float = -20.0 // Max attenuation dB (-40 to 0)

        private let sampleRate: Float
        private var currentGain: Float = 1.0
        private var rmsAccumulator: Float = 0.0
        private var sampleCounter: Int = 0
        private let windowSize: Int = 4800  // 100ms at 48kHz

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(_ input: Float) -> Float {
            // Accumulate RMS
            rmsAccumulator += input * input
            sampleCounter += 1

            // Calculate RMS every windowSize samples
            if sampleCounter >= windowSize {
                let rms = sqrt(rmsAccumulator / Float(sampleCounter))
                let rmsDB = 20.0 * log10(max(rms, 0.00001))

                // Calculate required gain
                let gainDB = targetLevel - rmsDB
                let clampedGainDB = min(max(gainDB, maxAttenuation), maxGain)
                let targetGain = pow(10.0, clampedGainDB / 20.0)

                // Smooth gain changes
                let coefficient = 1.0 - speed
                currentGain = currentGain * coefficient + targetGain * (1.0 - coefficient)

                // Reset accumulators
                rmsAccumulator = 0.0
                sampleCounter = 0
            }

            return input * currentGain
        }
    }

    // MARK: - Stereo Width Control

    /// M/S (Mid/Side) stereo width control
    /// Adjust stereo image width
    class StereoWidth: ObservableObject {
        @Published var width: Float = 1.0           // Width (0-2, 1=normal)
        @Published var monoBelow: Float = 0.0       // Mono below this frequency Hz (0=off)
        @Published var phase: Float = 0.0           // Phase rotation degrees (-180 to +180)

        private let sampleRate: Float
        private var lpFilterL: OnePoleLowpass = OnePoleLowpass()
        private var lpFilterR: OnePoleLowpass = OnePoleLowpass()
        private var hpFilterL: OnePoleHighpass = OnePoleHighpass()
        private var hpFilterR: OnePoleHighpass = OnePoleHighpass()

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(left: Float, right: Float) -> (left: Float, right: Float) {
            var l = left
            var r = right

            // M/S encoding
            let mid = (l + r) * 0.5
            let side = (l - r) * 0.5

            // Apply width
            let wideSide = side * width

            // M/S decoding
            var outL = mid + wideSide
            var outR = mid - wideSide

            // Mono low frequencies if enabled
            if monoBelow > 0 {
                let lowL = lpFilterL.process(l, cutoff: monoBelow, sampleRate: sampleRate)
                let lowR = lpFilterR.process(r, cutoff: monoBelow, sampleRate: sampleRate)
                let lowMono = (lowL + lowR) * 0.5

                let highL = hpFilterL.process(outL, cutoff: monoBelow, sampleRate: sampleRate)
                let highR = hpFilterR.process(outR, cutoff: monoBelow, sampleRate: sampleRate)

                outL = lowMono + highL
                outR = lowMono + highR
            }

            // Phase rotation (if needed)
            if abs(phase) > 0.1 {
                let phaseRad = phase * Float.pi / 180.0
                let cosPhase = cos(phaseRad)
                let sinPhase = sin(phaseRad)

                let rotatedL = outL * cosPhase - outR * sinPhase
                let rotatedR = outL * sinPhase + outR * cosPhase

                outL = rotatedL
                outR = rotatedR
            }

            return (outL, outR)
        }
    }

    // MARK: - Level Meter

    /// Peak and RMS level metering
    /// VU-meter style display data
    class LevelMeter: ObservableObject {
        @Published var peakL: Float = -80.0
        @Published var peakR: Float = -80.0
        @Published var rmsL: Float = -80.0
        @Published var rmsR: Float = -80.0

        private let sampleRate: Float
        private var peakHoldCounterL: Int = 0
        private var peakHoldCounterR: Int = 0
        private let peakHoldTime: Int = 24000  // 500ms at 48kHz
        private var rmsAccumulatorL: Float = 0.0
        private var rmsAccumulatorR: Float = 0.0
        private var rmsCounter: Int = 0
        private let rmsWindow: Int = 4800  // 100ms at 48kHz

        init(sampleRate: Float = 48000) {
            self.sampleRate = sampleRate
        }

        func process(left: Float, right: Float) {
            // Peak detection
            let peakLevelL = 20.0 * log10(max(abs(left), 0.00001))
            let peakLevelR = 20.0 * log10(max(abs(right), 0.00001))

            if peakLevelL > peakL {
                peakL = peakLevelL
                peakHoldCounterL = peakHoldTime
            }

            if peakLevelR > peakR {
                peakR = peakLevelR
                peakHoldCounterR = peakHoldTime
            }

            // Peak decay
            if peakHoldCounterL > 0 {
                peakHoldCounterL -= 1
            } else {
                peakL -= 0.5  // Decay at 0.5dB per sample
                peakL = max(peakL, -80.0)
            }

            if peakHoldCounterR > 0 {
                peakHoldCounterR -= 1
            } else {
                peakR -= 0.5
                peakR = max(peakR, -80.0)
            }

            // RMS accumulation
            rmsAccumulatorL += left * left
            rmsAccumulatorR += right * right
            rmsCounter += 1

            // Calculate RMS every window
            if rmsCounter >= rmsWindow {
                let rmsValueL = sqrt(rmsAccumulatorL / Float(rmsCounter))
                let rmsValueR = sqrt(rmsAccumulatorR / Float(rmsCounter))

                rmsL = 20.0 * log10(max(rmsValueL, 0.00001))
                rmsR = 20.0 * log10(max(rmsValueR, 0.00001))

                rmsAccumulatorL = 0.0
                rmsAccumulatorR = 0.0
                rmsCounter = 0
            }
        }
    }

    // MARK: - Helper Filters (for StereoWidth)

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
