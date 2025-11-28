//
//  FrequencyToVisualMapper.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  SCIENTIFIC FREQUENCY-TO-VISUAL SPECTRUM MAPPING
//  Translates HRV, EEG, Audio frequencies to visible light spectrum
//
//  **Scientific Basis:**
//  - Octave relationships (frequency doubling = color cycling)
//  - Logarithmic perception (Weber-Fechner law)
//  - Spectral mapping (CIE 1931 color space)
//

import Foundation
import SwiftUI
import Accelerate

// MARK: - Frequency to Visual Mapper

/// Ultra-precise frequency-to-color mapping system
///
/// **Frequency Ranges:**
/// - HRV: 0.04 - 0.4 Hz (25s - 2.5s period) - Cardiac autonomic activity
/// - EEG: 0.5 - 100 Hz (Delta, Theta, Alpha, Beta, Gamma) - Brainwaves
/// - Audio: 20 - 20,000 Hz - Audible sound
/// - Visible Light: 400 - 700 nm (430 - 750 THz) - Electromagnetic spectrum
///
/// **Mapping Strategy:**
/// 1. Logarithmic scaling (human perception)
/// 2. Octave cycling (musical/harmonic relationships)
/// 3. Spectral interpolation (CIE color matching functions)
@MainActor
class FrequencyToVisualMapper: ObservableObject {
    static let shared = FrequencyToVisualMapper()

    // MARK: - Frequency Ranges

    /// HRV frequency bands per Task Force (1996)
    enum HRVBand {
        case veryLowFrequency  // VLF: 0.003 - 0.04 Hz (thermoregulation, hormones)
        case lowFrequency      // LF:  0.04 - 0.15 Hz (sympathetic + parasympathetic)
        case highFrequency     // HF:  0.15 - 0.4 Hz (parasympathetic, respiratory)

        var range: ClosedRange<Double> {
            switch self {
            case .veryLowFrequency: return 0.003...0.04
            case .lowFrequency: return 0.04...0.15
            case .highFrequency: return 0.15...0.4
            }
        }

        var color: Color {
            switch self {
            case .veryLowFrequency: return .purple   // Deep, slow (sympathetic dominance)
            case .lowFrequency: return .blue         // Balanced (autonomic balance)
            case .highFrequency: return .green       // High, fast (parasympathetic dominance)
            }
        }

        var name: String {
            switch self {
            case .veryLowFrequency: return "VLF (Very Low Frequency)"
            case .lowFrequency: return "LF (Low Frequency)"
            case .highFrequency: return "HF (High Frequency)"
            }
        }
    }

    /// EEG brainwave bands
    enum EEGBand {
        case delta    // 0.5 - 4 Hz (deep sleep, unconscious)
        case theta    // 4 - 8 Hz (meditation, creativity, REM sleep)
        case alpha    // 8 - 13 Hz (relaxed, calm, present)
        case beta     // 13 - 30 Hz (alert, focused, active thinking)
        case gamma    // 30 - 100 Hz (peak concentration, binding)

        var range: ClosedRange<Double> {
            switch self {
            case .delta: return 0.5...4.0
            case .theta: return 4.0...8.0
            case .alpha: return 8.0...13.0
            case .beta: return 13.0...30.0
            case .gamma: return 30.0...100.0
            }
        }

        var color: Color {
            switch self {
            case .delta: return Color(red: 0.4, green: 0.0, blue: 0.6)  // Deep purple
            case .theta: return Color(red: 0.0, green: 0.4, blue: 0.8)  // Blue
            case .alpha: return Color(red: 0.0, green: 0.8, blue: 0.5)  // Cyan-green
            case .beta: return Color(red: 1.0, green: 0.8, blue: 0.0)   // Yellow-orange
            case .gamma: return Color(red: 1.0, green: 0.2, blue: 0.0)  // Red-orange
            }
        }

        var name: String {
            switch self {
            case .delta: return "Delta (Deep Sleep)"
            case .theta: return "Theta (Meditation)"
            case .alpha: return "Alpha (Relaxation)"
            case .beta: return "Beta (Focus)"
            case .gamma: return "Gamma (Peak Concentration)"
            }
        }

        var description: String {
            switch self {
            case .delta: return "Deep dreamless sleep, healing, regeneration"
            case .theta: return "Deep meditation, creativity, REM sleep, memory consolidation"
            case .alpha: return "Relaxed awareness, calm, present moment, flow state"
            case .beta: return "Active thinking, problem solving, focus, alertness"
            case .gamma: return "Peak concentration, information processing, memory binding"
            }
        }
    }

    // MARK: - Mapping Algorithms

    /// Map HRV frequency (0.04-0.4 Hz) to visible spectrum
    func mapHRVToColor(frequency: Double) -> Color {
        // Clamp to HRV range
        let clampedFreq = max(0.04, min(0.4, frequency))

        // Determine band
        if HRVBand.highFrequency.range.contains(clampedFreq) {
            // HF: 0.15-0.4 Hz → Green (parasympathetic)
            let t = (clampedFreq - 0.15) / (0.4 - 0.15)  // 0-1
            return Color(
                red: 0.0,
                green: 0.5 + t * 0.5,  // 0.5-1.0
                blue: 0.3 - t * 0.3    // 0.3-0.0
            )
        } else if HRVBand.lowFrequency.range.contains(clampedFreq) {
            // LF: 0.04-0.15 Hz → Blue (balanced)
            let t = (clampedFreq - 0.04) / (0.15 - 0.04)  // 0-1
            return Color(
                red: 0.3 - t * 0.3,    // 0.3-0.0
                green: 0.3 + t * 0.2,  // 0.3-0.5
                blue: 0.7 + t * 0.3    // 0.7-1.0
            )
        } else {
            // VLF: 0.003-0.04 Hz → Purple (sympathetic)
            let t = (clampedFreq - 0.003) / (0.04 - 0.003)  // 0-1
            return Color(
                red: 0.4 + t * 0.1,    // 0.4-0.5
                green: 0.0,
                blue: 0.6 + t * 0.1    // 0.6-0.7
            )
        }
    }

    /// Map EEG frequency (0.5-100 Hz) to visible spectrum
    func mapEEGToColor(frequency: Double) -> Color {
        // Clamp to EEG range
        let clampedFreq = max(0.5, min(100.0, frequency))

        // Determine band
        if EEGBand.gamma.range.contains(clampedFreq) {
            // Gamma: 30-100 Hz → Red-Orange
            let t = (clampedFreq - 30.0) / (100.0 - 30.0)
            return Color(
                red: 1.0,
                green: 0.2 + t * 0.3,  // 0.2-0.5
                blue: 0.0
            )
        } else if EEGBand.beta.range.contains(clampedFreq) {
            // Beta: 13-30 Hz → Yellow-Orange
            let t = (clampedFreq - 13.0) / (30.0 - 13.0)
            return Color(
                red: 1.0,
                green: 0.8 - t * 0.6,  // 0.8-0.2
                blue: 0.0
            )
        } else if EEGBand.alpha.range.contains(clampedFreq) {
            // Alpha: 8-13 Hz → Green-Cyan
            let t = (clampedFreq - 8.0) / (13.0 - 8.0)
            return Color(
                red: 0.0,
                green: 0.8,
                blue: 0.5 - t * 0.5    // 0.5-0.0
            )
        } else if EEGBand.theta.range.contains(clampedFreq) {
            // Theta: 4-8 Hz → Blue
            let t = (clampedFreq - 4.0) / (8.0 - 4.0)
            return Color(
                red: 0.0,
                green: 0.4 + t * 0.4,  // 0.4-0.8
                blue: 0.8
            )
        } else {
            // Delta: 0.5-4 Hz → Purple
            let t = (clampedFreq - 0.5) / (4.0 - 0.5)
            return Color(
                red: 0.4,
                green: 0.0,
                blue: 0.6 + t * 0.2    // 0.6-0.8
            )
        }
    }

    /// Map audio frequency (20-20,000 Hz) to visible spectrum
    ///
    /// **Strategy:** Octave cycling (doubling frequency = same color)
    /// - Maps 20 Hz to red (lowest)
    /// - Each octave cycles through spectrum
    /// - 20,000 Hz maps to violet (highest)
    func mapAudioToColor(frequency: Double) -> Color {
        // Clamp to audible range
        let clampedFreq = max(20.0, min(20000.0, frequency))

        // Use logarithmic scale (octaves)
        // log2(20000/20) = log2(1000) ≈ 9.97 octaves
        let octaves = log2(clampedFreq / 20.0)
        let totalOctaves = log2(20000.0 / 20.0)

        // Normalize to 0-1
        let t = octaves / totalOctaves

        // Map to visible spectrum (red → violet)
        return spectralColor(wavelength: 700.0 - t * 300.0)  // 700nm (red) → 400nm (violet)
    }

    /// Map audio frequency using musical octave cycling
    ///
    /// **Strategy:** Same note in different octaves = same hue
    /// - C = Red
    /// - D = Orange
    /// - E = Yellow
    /// - F = Green
    /// - G = Cyan
    /// - A = Blue
    /// - B = Violet
    func mapAudioToMusicalColor(frequency: Double) -> Color {
        // Clamp to audible range
        let clampedFreq = max(20.0, min(20000.0, frequency))

        // Calculate MIDI note (A4 = 440 Hz = note 69)
        let midiNote = 69.0 + 12.0 * log2(clampedFreq / 440.0)
        let noteInOctave = Int(midiNote) % 12

        // Map note to hue (0-1)
        let hue = Double(noteInOctave) / 12.0

        // Calculate brightness based on octave
        let octave = Int(midiNote) / 12
        let brightness = 0.5 + Double(octave % 3) * 0.15  // Cycle brightness every 3 octaves

        return Color(hue: hue, saturation: 0.9, brightness: brightness)
    }

    // MARK: - Spectral Color (CIE 1931)

    /// Convert wavelength (nm) to RGB color using CIE 1931 approximation
    ///
    /// **Scientific Basis:**
    /// - Visible spectrum: 380-780 nm
    /// - Red: 625-780 nm
    /// - Orange: 590-625 nm
    /// - Yellow: 565-590 nm
    /// - Green: 500-565 nm
    /// - Cyan: 485-500 nm
    /// - Blue: 450-485 nm
    /// - Violet: 380-450 nm
    private func spectralColor(wavelength: Double) -> Color {
        // Clamp to visible spectrum
        let lambda = max(380.0, min(780.0, wavelength))

        var r: Double = 0.0
        var g: Double = 0.0
        var b: Double = 0.0

        // CIE 1931 approximation
        if lambda >= 380 && lambda < 440 {
            r = -(lambda - 440) / (440 - 380)
            b = 1.0
        } else if lambda >= 440 && lambda < 490 {
            g = (lambda - 440) / (490 - 440)
            b = 1.0
        } else if lambda >= 490 && lambda < 510 {
            g = 1.0
            b = -(lambda - 510) / (510 - 490)
        } else if lambda >= 510 && lambda < 580 {
            r = (lambda - 510) / (580 - 510)
            g = 1.0
        } else if lambda >= 580 && lambda < 645 {
            r = 1.0
            g = -(lambda - 645) / (645 - 580)
        } else if lambda >= 645 && lambda <= 780 {
            r = 1.0
        }

        // Apply intensity correction (eye sensitivity)
        let factor: Double
        if lambda >= 380 && lambda < 420 {
            factor = 0.3 + 0.7 * (lambda - 380) / (420 - 380)
        } else if lambda >= 420 && lambda < 700 {
            factor = 1.0
        } else if lambda >= 700 && lambda <= 780 {
            factor = 0.3 + 0.7 * (780 - lambda) / (780 - 700)
        } else {
            factor = 0.0
        }

        r = pow(r * factor, 0.8)  // Gamma correction
        g = pow(g * factor, 0.8)
        b = pow(b * factor, 0.8)

        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Frequency Analysis

    /// Analyze HRV spectrum and return dominant band
    func analyzeHRVSpectrum(magnitudes: [Double], frequencies: [Double]) -> HRVAnalysis {
        var vlfPower: Double = 0.0
        var lfPower: Double = 0.0
        var hfPower: Double = 0.0

        for (i, freq) in frequencies.enumerated() {
            let power = magnitudes[i]

            if HRVBand.veryLowFrequency.range.contains(freq) {
                vlfPower += power
            } else if HRVBand.lowFrequency.range.contains(freq) {
                lfPower += power
            } else if HRVBand.highFrequency.range.contains(freq) {
                hfPower += power
            }
        }

        let totalPower = vlfPower + lfPower + hfPower
        let lfhfRatio = lfPower / max(hfPower, 0.001)  // Sympatho-vagal balance

        let dominantBand: HRVBand
        if vlfPower > lfPower && vlfPower > hfPower {
            dominantBand = .veryLowFrequency
        } else if lfPower > hfPower {
            dominantBand = .lowFrequency
        } else {
            dominantBand = .highFrequency
        }

        return HRVAnalysis(
            vlfPower: vlfPower,
            lfPower: lfPower,
            hfPower: hfPower,
            totalPower: totalPower,
            lfhfRatio: lfhfRatio,
            dominantBand: dominantBand
        )
    }

    struct HRVAnalysis {
        let vlfPower: Double
        let lfPower: Double
        let hfPower: Double
        let totalPower: Double
        let lfhfRatio: Double  // Sympatho-vagal balance (LF/HF ratio)
        let dominantBand: HRVBand

        var interpretation: String {
            if lfhfRatio > 2.5 {
                return "Sympathetic dominance (stress, fight-or-flight)"
            } else if lfhfRatio < 0.5 {
                return "Parasympathetic dominance (relaxation, rest-and-digest)"
            } else {
                return "Balanced autonomic activity"
            }
        }
    }

    /// Analyze EEG spectrum and return dominant band
    func analyzeEEGSpectrum(magnitudes: [Double], frequencies: [Double]) -> EEGAnalysis {
        var deltaPower: Double = 0.0
        var thetaPower: Double = 0.0
        var alphaPower: Double = 0.0
        var betaPower: Double = 0.0
        var gammaPower: Double = 0.0

        for (i, freq) in frequencies.enumerated() {
            let power = magnitudes[i]

            if EEGBand.delta.range.contains(freq) {
                deltaPower += power
            } else if EEGBand.theta.range.contains(freq) {
                thetaPower += power
            } else if EEGBand.alpha.range.contains(freq) {
                alphaPower += power
            } else if EEGBand.beta.range.contains(freq) {
                betaPower += power
            } else if EEGBand.gamma.range.contains(freq) {
                gammaPower += power
            }
        }

        let totalPower = deltaPower + thetaPower + alphaPower + betaPower + gammaPower

        let dominantBand: EEGBand
        let maxPower = max(deltaPower, thetaPower, alphaPower, betaPower, gammaPower)
        if maxPower == deltaPower {
            dominantBand = .delta
        } else if maxPower == thetaPower {
            dominantBand = .theta
        } else if maxPower == alphaPower {
            dominantBand = .alpha
        } else if maxPower == betaPower {
            dominantBand = .beta
        } else {
            dominantBand = .gamma
        }

        return EEGAnalysis(
            deltaPower: deltaPower,
            thetaPower: thetaPower,
            alphaPower: alphaPower,
            betaPower: betaPower,
            gammaPower: gammaPower,
            totalPower: totalPower,
            dominantBand: dominantBand
        )
    }

    struct EEGAnalysis {
        let deltaPower: Double
        let thetaPower: Double
        let alphaPower: Double
        let betaPower: Double
        let gammaPower: Double
        let totalPower: Double
        let dominantBand: EEGBand

        var mentalState: String {
            switch dominantBand {
            case .delta:
                return "Deep sleep or unconscious state"
            case .theta:
                return "Deep meditation, creative flow, or REM sleep"
            case .alpha:
                return "Relaxed awareness, calm, present moment"
            case .beta:
                return "Active thinking, problem solving, focused attention"
            case .gamma:
                return "Peak concentration, information processing, memory binding"
            }
        }
    }

    // MARK: - Real-Time Visualization

    /// Generate color gradient for frequency spectrum visualization
    func generateSpectrumGradient(frequencies: [Double], mappingMode: MappingMode) -> [Color] {
        return frequencies.map { freq in
            switch mappingMode {
            case .hrv:
                return mapHRVToColor(frequency: freq)
            case .eeg:
                return mapEEGToColor(frequency: freq)
            case .audioSpectral:
                return mapAudioToColor(frequency: freq)
            case .audioMusical:
                return mapAudioToMusicalColor(frequency: freq)
            }
        }
    }

    enum MappingMode {
        case hrv           // Heart rate variability (0.04-0.4 Hz)
        case eeg           // Brainwaves (0.5-100 Hz)
        case audioSpectral // Audio spectrum (20-20,000 Hz) linear
        case audioMusical  // Audio spectrum (20-20,000 Hz) musical octaves
    }

    // MARK: - Utility Functions

    /// Convert frequency to wavelength (if treating as EM wave)
    func frequencyToWavelength(frequency: Double) -> Double {
        // c = 299,792,458 m/s (speed of light)
        let c = 299_792_458.0
        return c / frequency
    }

    /// Convert wavelength to frequency
    func wavelengthToFrequency(wavelength: Double) -> Double {
        let c = 299_792_458.0
        return c / wavelength
    }

    /// Octave transpose frequency
    func transposeOctaves(frequency: Double, octaves: Int) -> Double {
        return frequency * pow(2.0, Double(octaves))
    }

    private init() {}
}

// MARK: - Preview / Debug

#if DEBUG
extension FrequencyToVisualMapper {
    /// Generate test gradients for visualization
    func generateTestGradients() -> [String: [Color]] {
        var gradients: [String: [Color]] = [:]

        // HRV gradient (0.04-0.4 Hz)
        let hrvFreqs = stride(from: 0.04, through: 0.4, by: 0.01).map { $0 }
        gradients["HRV"] = hrvFreqs.map { mapHRVToColor(frequency: $0) }

        // EEG gradient (0.5-100 Hz, logarithmic)
        let eegFreqs = stride(from: 0.5, through: 100.0, by: 1.0).map { $0 }
        gradients["EEG"] = eegFreqs.map { mapEEGToColor(frequency: $0) }

        // Audio gradient (20-20,000 Hz, logarithmic)
        let audioFreqs = (0...100).map { i in
            20.0 * pow(1000.0, Double(i) / 100.0)  // Log scale
        }
        gradients["Audio Spectral"] = audioFreqs.map { mapAudioToColor(frequency: $0) }
        gradients["Audio Musical"] = audioFreqs.map { mapAudioToMusicalColor(frequency: $0) }

        return gradients
    }
}
#endif
