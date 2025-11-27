//
//  ScientificSonification.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  SCIENTIFIC SONIFICATION & FREQUENCY TRANSPOSITION
//
//  Wissenschaftlich korrekte Umwandlung von:
//  - Biofeedback-Daten → Hörbarer Bereich (Sonifikation)
//  - Audio → Sichtbarer Bereich (Cymatics, Spektralvisualisierung)
//  - Beliebige Frequenzen → Beliebiger Zielbereich (Oktavtransposition)
//
//  Basiert auf:
//  - Oktavierung: f' = f × 2^n (frequenzerhaltende Transposition)
//  - Lineare Skalierung: für nicht-harmonische Mappings
//  - Logarithmische Skalierung: für wahrnehmungsgerechte Darstellung
//
//  Frequenzbereiche (wissenschaftlich):
//  - Infraschall: < 20 Hz
//  - Hörbarer Bereich: 20 Hz - 20 kHz
//  - Ultraschall: > 20 kHz
//  - Sichtbares Licht: 430-770 THz (700-390 nm)
//  - EEG-Wellen: 0.5-100 Hz
//  - HRV-Frequenzen: 0.003-0.4 Hz
//

import Foundation
import Combine
import simd

// MARK: - Scientific Frequency Constants

public enum FrequencyConstants {

    // MARK: - Electromagnetic Spectrum (exact values)

    /// Speed of light in vacuum (exact, SI definition)
    public static let speedOfLight: Double = 299_792_458.0  // m/s

    /// Visible light range
    public enum VisibleLight {
        /// Red light: ~700 nm = 428 THz
        public static let redWavelength: Double = 700e-9  // meters
        public static let redFrequency: Double = speedOfLight / redWavelength  // ~428 THz

        /// Violet light: ~380 nm = 789 THz
        public static let violetWavelength: Double = 380e-9  // meters
        public static let violetFrequency: Double = speedOfLight / violetWavelength  // ~789 THz

        /// Frequency range
        public static let minFrequency: Double = 428e12  // Hz (red)
        public static let maxFrequency: Double = 789e12  // Hz (violet)

        /// Wavelength range
        public static let minWavelength: Double = 380e-9  // m (violet)
        public static let maxWavelength: Double = 700e-9  // m (red)
    }

    // MARK: - Audio Frequency Ranges

    public enum Audio {
        /// Infrasound (below human hearing)
        public static let infrasoundMax: Double = 20.0  // Hz

        /// Human audible range
        public static let audibleMin: Double = 20.0     // Hz
        public static let audibleMax: Double = 20_000.0 // Hz

        /// Ultrasound (above human hearing)
        public static let ultrasoundMin: Double = 20_000.0  // Hz

        /// Musical range (grand piano)
        public static let pianoMin: Double = 27.5    // A0
        public static let pianoMax: Double = 4186.0  // C8

        /// Comfortable listening range
        public static let comfortableMin: Double = 100.0
        public static let comfortableMax: Double = 8000.0
    }

    // MARK: - Biofeedback Frequency Ranges

    public enum Biofeedback {

        /// EEG Brainwave bands (clinical definitions)
        public enum EEG {
            /// Delta waves: 0.5-4 Hz (deep sleep)
            public static let deltaMin: Double = 0.5
            public static let deltaMax: Double = 4.0

            /// Theta waves: 4-8 Hz (drowsy, meditation)
            public static let thetaMin: Double = 4.0
            public static let thetaMax: Double = 8.0

            /// Alpha waves: 8-13 Hz (relaxed, awake)
            public static let alphaMin: Double = 8.0
            public static let alphaMax: Double = 13.0

            /// SMR (Sensorimotor rhythm): 12-15 Hz
            public static let smrMin: Double = 12.0
            public static let smrMax: Double = 15.0

            /// Beta waves: 13-30 Hz (active thinking)
            public static let betaMin: Double = 13.0
            public static let betaMax: Double = 30.0

            /// High Beta: 20-30 Hz (anxiety, stress)
            public static let highBetaMin: Double = 20.0
            public static let highBetaMax: Double = 30.0

            /// Gamma waves: 30-100 Hz (cognitive processing)
            public static let gammaMin: Double = 30.0
            public static let gammaMax: Double = 100.0

            /// Full EEG range
            public static let fullMin: Double = 0.5
            public static let fullMax: Double = 100.0

            /// Band names and ranges
            public static let bands: [(name: String, min: Double, max: Double)] = [
                ("Delta", 0.5, 4.0),
                ("Theta", 4.0, 8.0),
                ("Alpha", 8.0, 13.0),
                ("SMR", 12.0, 15.0),
                ("Beta", 13.0, 30.0),
                ("Gamma", 30.0, 100.0)
            ]
        }

        /// Heart Rate Variability (HRV) frequency bands
        public enum HRV {
            /// Ultra-Low Frequency: < 0.003 Hz (circadian rhythms)
            public static let ulfMax: Double = 0.003

            /// Very Low Frequency: 0.003-0.04 Hz (thermoregulation)
            public static let vlfMin: Double = 0.003
            public static let vlfMax: Double = 0.04

            /// Low Frequency: 0.04-0.15 Hz (sympathetic + parasympathetic)
            public static let lfMin: Double = 0.04
            public static let lfMax: Double = 0.15

            /// High Frequency: 0.15-0.4 Hz (parasympathetic, respiratory)
            public static let hfMin: Double = 0.15
            public static let hfMax: Double = 0.4

            /// Full HRV spectral range
            public static let fullMin: Double = 0.003
            public static let fullMax: Double = 0.4

            /// Typical heart rate as frequency
            public static func heartRateToFrequency(_ bpm: Double) -> Double {
                return bpm / 60.0  // 60 BPM = 1 Hz
            }
        }

        /// Respiration
        public enum Respiration {
            /// Normal breathing: 12-20 breaths/minute = 0.2-0.33 Hz
            public static let normalMin: Double = 0.2   // 12 breaths/min
            public static let normalMax: Double = 0.33  // 20 breaths/min

            /// Slow breathing (meditation): 4-6 breaths/min = 0.067-0.1 Hz
            public static let slowMin: Double = 0.067
            public static let slowMax: Double = 0.1

            /// Full range
            public static let fullMin: Double = 0.05   // 3 breaths/min
            public static let fullMax: Double = 0.5    // 30 breaths/min
        }

        /// Galvanic Skin Response (GSR/EDA)
        public enum GSR {
            /// Tonic (baseline) changes: < 0.05 Hz
            public static let tonicMax: Double = 0.05

            /// Phasic (event-related) responses: 0.05-0.5 Hz
            public static let phasicMin: Double = 0.05
            public static let phasicMax: Double = 0.5
        }

        /// Electromyography (EMG)
        public enum EMG {
            /// Surface EMG range: 20-500 Hz
            public static let surfaceMin: Double = 20.0
            public static let surfaceMax: Double = 500.0

            /// Most muscle activity: 50-150 Hz
            public static let primaryMin: Double = 50.0
            public static let primaryMax: Double = 150.0
        }
    }

    // MARK: - Geophysical Frequencies

    public enum Geophysical {
        /// Schumann resonances (Earth-ionosphere cavity)
        /// Fundamental ≈ 7.83 Hz, harmonics at ~14.3, 20.8, 27.3, 33.8 Hz
        public static let schumannFundamental: Double = 7.83
        public static let schumannHarmonics: [Double] = [7.83, 14.3, 20.8, 27.3, 33.8, 39.0, 45.0]

        /// Earth's rotation frequency
        public static let earthRotation: Double = 1.0 / 86400.0  // ~11.6 µHz

        /// Tidal frequencies (lunar/solar)
        public static let lunarTidal: Double = 1.0 / (12.42 * 3600)  // ~22 µHz
    }
}

// MARK: - Frequency Transposition Engine

@MainActor
public class FrequencyTransposer: ObservableObject {

    public static let shared = FrequencyTransposer()

    // MARK: - Transposition Methods

    public enum TranspositionMethod {
        /// Octave transposition: f' = f × 2^n (preserves harmonic relationships)
        case octave

        /// Linear scaling: f' = f × k (simple multiplication)
        case linear

        /// Logarithmic scaling: preserves perceptual ratios
        case logarithmic

        /// Exponential mapping: for extreme range compression
        case exponential
    }

    // MARK: - Octave Transposition (Primary Method)

    /// Transpose a frequency by n octaves
    /// Fundamental principle: doubling frequency = one octave up
    public func transposeByOctaves(_ frequency: Double, octaves: Int) -> Double {
        return frequency * pow(2.0, Double(octaves))
    }

    /// Calculate octaves needed to reach target range
    public func octavesRequired(
        from sourceFrequency: Double,
        toRange targetMin: Double,
        _ targetMax: Double
    ) -> Int {
        guard sourceFrequency > 0 else { return 0 }

        // Target center frequency (geometric mean)
        let targetCenter = sqrt(targetMin * targetMax)

        // Octaves = log₂(target/source)
        let octaves = log2(targetCenter / sourceFrequency)

        return Int(round(octaves))
    }

    /// Transpose frequency into audible range
    public func transposeToAudible(
        _ frequency: Double,
        targetCenter: Double = 440.0
    ) -> (frequency: Double, octavesShifted: Int) {
        guard frequency > 0 else { return (targetCenter, 0) }

        let octaves = octavesRequired(
            from: frequency,
            toRange: FrequencyConstants.Audio.audibleMin,
            FrequencyConstants.Audio.audibleMax
        )

        let transposed = transposeByOctaves(frequency, octaves: octaves)
        return (transposed, octaves)
    }

    /// Transpose multiple frequencies maintaining their relationships
    public func transposeBandToAudible(
        frequencies: [Double],
        preserveRatios: Bool = true
    ) -> [(original: Double, transposed: Double, octaves: Int)] {
        guard !frequencies.isEmpty else { return [] }

        if preserveRatios {
            // Find center frequency of the band
            let minFreq = frequencies.min()!
            let maxFreq = frequencies.max()!
            let centerFreq = sqrt(minFreq * maxFreq)

            // Calculate single octave shift for entire band
            let octaves = octavesRequired(
                from: centerFreq,
                toRange: FrequencyConstants.Audio.comfortableMin,
                FrequencyConstants.Audio.comfortableMax
            )

            return frequencies.map { freq in
                (freq, transposeByOctaves(freq, octaves: octaves), octaves)
            }
        } else {
            // Individual transposition (loses harmonic relationships)
            return frequencies.map { freq in
                let (transposed, octaves) = transposeToAudible(freq)
                return (freq, transposed, octaves)
            }
        }
    }

    // MARK: - Biofeedback Sonification

    /// EEG brainwave to audible frequency mapping
    public struct EEGSonificationMapping {
        public let inputBand: String
        public let inputRange: ClosedRange<Double>
        public let outputRange: ClosedRange<Double>
        public let octavesShifted: Int

        public static let defaultMappings: [EEGSonificationMapping] = {
            let transposer = FrequencyTransposer.shared

            return FrequencyConstants.Biofeedback.EEG.bands.map { band in
                let (outputMin, octaves) = transposer.transposeToAudible(band.min)
                let outputMax = transposer.transposeByOctaves(band.max, octaves: octaves)

                return EEGSonificationMapping(
                    inputBand: band.name,
                    inputRange: band.min...band.max,
                    outputRange: outputMin...outputMax,
                    octavesShifted: octaves
                )
            }
        }()
    }

    /// Convert EEG frequency to audible tone
    public func sonifyEEG(
        _ eegFrequency: Double,
        octaveShift: Int? = nil
    ) -> Double {
        // Default: shift by ~5 octaves to bring 8 Hz alpha into ~256 Hz range
        let shift = octaveShift ?? 5
        return transposeByOctaves(eegFrequency, octaves: shift)
    }

    /// Convert HRV frequency to audible tone
    public func sonifyHRV(
        _ hrvFrequency: Double,
        octaveShift: Int? = nil
    ) -> Double {
        // HRV is very low frequency (0.003-0.4 Hz)
        // Need ~10-12 octaves to reach audible range
        let shift = octaveShift ?? 11
        return transposeByOctaves(hrvFrequency, octaves: shift)
    }

    /// Convert heart rate (BPM) to frequency
    public func heartRateToFrequency(_ bpm: Double) -> Double {
        return bpm / 60.0  // 60 BPM = 1 Hz
    }

    /// Sonify heart rate directly
    public func sonifyHeartRate(
        _ bpm: Double,
        octaveShift: Int? = nil
    ) -> Double {
        let freq = heartRateToFrequency(bpm)
        let shift = octaveShift ?? 8  // ~8 octaves brings 1 Hz to ~256 Hz
        return transposeByOctaves(freq, octaves: shift)
    }

    // MARK: - Audio to Visual Transposition

    /// Map audio frequency to visible light wavelength
    /// Uses ~40 octave transposition (log₂(430 THz / 440 Hz) ≈ 39.9)
    public func audioToVisibleLight(_ audioFrequency: Double) -> VisibleLightResult {
        // Audible range: ~20-20000 Hz
        // Visible range: ~430-790 THz (about 40 octaves higher)

        let octavesToLight: Double = 40.0  // Approximate shift

        // Map audio frequency to light frequency
        let lightFrequency = audioFrequency * pow(2.0, octavesToLight)

        // Clamp to visible range
        let clampedFrequency = max(
            FrequencyConstants.VisibleLight.minFrequency,
            min(FrequencyConstants.VisibleLight.maxFrequency, lightFrequency)
        )

        // Convert to wavelength
        let wavelength = FrequencyConstants.speedOfLight / clampedFrequency

        // Convert to RGB color
        let color = wavelengthToRGB(wavelength * 1e9)  // Convert to nm

        return VisibleLightResult(
            audioFrequency: audioFrequency,
            lightFrequency: clampedFrequency,
            wavelength: wavelength,
            wavelengthNm: wavelength * 1e9,
            rgb: color,
            octavesShifted: Int(octavesToLight)
        )
    }

    public struct VisibleLightResult {
        public let audioFrequency: Double   // Hz
        public let lightFrequency: Double   // Hz
        public let wavelength: Double       // meters
        public let wavelengthNm: Double     // nanometers
        public let rgb: (r: Double, g: Double, b: Double)
        public let octavesShifted: Int
    }

    /// Convert wavelength (nm) to RGB
    /// Based on CIE color matching functions (simplified)
    public func wavelengthToRGB(_ wavelengthNm: Double) -> (r: Double, g: Double, b: Double) {
        let w = wavelengthNm

        var r: Double = 0, g: Double = 0, b: Double = 0

        if w >= 380 && w < 440 {
            r = -(w - 440) / (440 - 380)
            g = 0
            b = 1
        } else if w >= 440 && w < 490 {
            r = 0
            g = (w - 440) / (490 - 440)
            b = 1
        } else if w >= 490 && w < 510 {
            r = 0
            g = 1
            b = -(w - 510) / (510 - 490)
        } else if w >= 510 && w < 580 {
            r = (w - 510) / (580 - 510)
            g = 1
            b = 0
        } else if w >= 580 && w < 645 {
            r = 1
            g = -(w - 645) / (645 - 580)
            b = 0
        } else if w >= 645 && w <= 780 {
            r = 1
            g = 0
            b = 0
        }

        // Intensity correction for edges of visible spectrum
        var intensity: Double
        if w >= 380 && w < 420 {
            intensity = 0.3 + 0.7 * (w - 380) / (420 - 380)
        } else if w >= 420 && w <= 700 {
            intensity = 1.0
        } else if w > 700 && w <= 780 {
            intensity = 0.3 + 0.7 * (780 - w) / (780 - 700)
        } else {
            intensity = 0.0
        }

        return (r * intensity, g * intensity, b * intensity)
    }

    // MARK: - Linear & Logarithmic Mapping

    /// Linear frequency mapping (non-octave based)
    public func mapLinear(
        _ value: Double,
        fromRange: ClosedRange<Double>,
        toRange: ClosedRange<Double>
    ) -> Double {
        let normalized = (value - fromRange.lowerBound) / (fromRange.upperBound - fromRange.lowerBound)
        return toRange.lowerBound + normalized * (toRange.upperBound - toRange.lowerBound)
    }

    /// Logarithmic frequency mapping (perceptually uniform)
    public func mapLogarithmic(
        _ value: Double,
        fromRange: ClosedRange<Double>,
        toRange: ClosedRange<Double>
    ) -> Double {
        guard value > 0, fromRange.lowerBound > 0, toRange.lowerBound > 0 else {
            return toRange.lowerBound
        }

        let logInput = log10(value)
        let logInputMin = log10(fromRange.lowerBound)
        let logInputMax = log10(fromRange.upperBound)
        let logOutputMin = log10(toRange.lowerBound)
        let logOutputMax = log10(toRange.upperBound)

        let normalized = (logInput - logInputMin) / (logInputMax - logInputMin)
        let logOutput = logOutputMin + normalized * (logOutputMax - logOutputMin)

        return pow(10, logOutput)
    }

    // MARK: - Utility

    /// Format frequency for display
    public func formatFrequency(_ frequency: Double) -> String {
        if frequency >= 1e12 {
            return String(format: "%.2f THz", frequency / 1e12)
        } else if frequency >= 1e9 {
            return String(format: "%.2f GHz", frequency / 1e9)
        } else if frequency >= 1e6 {
            return String(format: "%.2f MHz", frequency / 1e6)
        } else if frequency >= 1e3 {
            return String(format: "%.2f kHz", frequency / 1e3)
        } else if frequency >= 1 {
            return String(format: "%.2f Hz", frequency)
        } else if frequency >= 0.001 {
            return String(format: "%.2f mHz", frequency * 1e3)
        } else {
            return String(format: "%.4f µHz", frequency * 1e6)
        }
    }

    /// Calculate frequency ratio in cents
    public func frequencyRatioInCents(_ freq1: Double, _ freq2: Double) -> Double {
        guard freq1 > 0 && freq2 > 0 else { return 0 }
        return 1200.0 * log2(freq2 / freq1)
    }

    private init() {}
}

// MARK: - Biofeedback Sonification Engine

@MainActor
public class BiofeedbackSonificationEngine: ObservableObject {

    public static let shared = BiofeedbackSonificationEngine()

    private let transposer = FrequencyTransposer.shared

    // MARK: - Published State

    @Published public var isActive: Bool = false
    @Published public var currentMode: SonificationMode = .eeg
    @Published public var octaveShift: Int = 8

    // MARK: - Sonification Modes

    public enum SonificationMode: String, CaseIterable {
        case eeg = "EEG Brainwaves"
        case hrv = "Heart Rate Variability"
        case heartRate = "Heart Rate"
        case respiration = "Respiration"
        case emg = "Muscle Activity (EMG)"
        case gsr = "Skin Conductance (GSR)"
        case combined = "Combined Biometrics"
    }

    // MARK: - Sonification Parameters

    public struct SonificationParameters {
        public var baseOctaveShift: Int
        public var frequencyRange: ClosedRange<Double>
        public var amplitudeMapping: AmplitudeMapping
        public var harmonicContent: HarmonicContent

        public enum AmplitudeMapping {
            case linear
            case logarithmic
            case exponential
        }

        public enum HarmonicContent {
            case pureTone
            case richHarmonics
            case noise
        }

        public static var eegDefaults: SonificationParameters {
            SonificationParameters(
                baseOctaveShift: 5,  // 8 Hz → 256 Hz
                frequencyRange: 100...2000,
                amplitudeMapping: .logarithmic,
                harmonicContent: .richHarmonics
            )
        }

        public static var hrvDefaults: SonificationParameters {
            SonificationParameters(
                baseOctaveShift: 11,  // 0.1 Hz → 204 Hz
                frequencyRange: 50...500,
                amplitudeMapping: .linear,
                harmonicContent: .pureTone
            )
        }

        public static var heartRateDefaults: SonificationParameters {
            SonificationParameters(
                baseOctaveShift: 8,  // 1 Hz → 256 Hz
                frequencyRange: 200...800,
                amplitudeMapping: .linear,
                harmonicContent: .pureTone
            )
        }
    }

    // MARK: - Real-time Sonification

    /// Process incoming biofeedback sample and return audio frequency
    public func processSample(
        _ sample: BiofeedbackSample
    ) -> SonificationResult {
        switch sample.type {
        case .eegPower(let band, let power):
            return sonifyEEGPower(band: band, power: power)

        case .hrvFrequency(let frequency, let amplitude):
            return sonifyHRVFrequency(frequency: frequency, amplitude: amplitude)

        case .heartRate(let bpm):
            return sonifyHeartRate(bpm: bpm)

        case .respiration(let rate):
            return sonifyRespiration(rate: rate)

        case .emg(let frequency, let amplitude):
            return sonifyEMG(frequency: frequency, amplitude: amplitude)

        case .gsr(let level, let changeRate):
            return sonifyGSR(level: level, changeRate: changeRate)
        }
    }

    // MARK: - Individual Sonification Methods

    private func sonifyEEGPower(band: String, power: Double) -> SonificationResult {
        // Find band center frequency
        let bandFreq: Double
        switch band.lowercased() {
        case "delta": bandFreq = 2.0
        case "theta": bandFreq = 6.0
        case "alpha": bandFreq = 10.0
        case "smr": bandFreq = 13.5
        case "beta": bandFreq = 20.0
        case "gamma": bandFreq = 50.0
        default: bandFreq = 10.0
        }

        let audioFreq = transposer.transposeByOctaves(bandFreq, octaves: 5)
        let amplitude = min(1.0, power)  // Normalize power to 0-1

        return SonificationResult(
            frequency: audioFreq,
            amplitude: amplitude,
            octavesShifted: 5,
            sourceDescription: "\(band) band (\(bandFreq) Hz)"
        )
    }

    private func sonifyHRVFrequency(frequency: Double, amplitude: Double) -> SonificationResult {
        let audioFreq = transposer.transposeByOctaves(frequency, octaves: 11)

        return SonificationResult(
            frequency: audioFreq,
            amplitude: amplitude,
            octavesShifted: 11,
            sourceDescription: "HRV \(String(format: "%.3f", frequency)) Hz"
        )
    }

    private func sonifyHeartRate(bpm: Double) -> SonificationResult {
        let heartFreq = bpm / 60.0  // Convert BPM to Hz
        let audioFreq = transposer.transposeByOctaves(heartFreq, octaves: 8)

        // Map BPM to amplitude (higher HR = louder)
        let amplitude = transposer.mapLinear(bpm, fromRange: 40...180, toRange: 0.3...1.0)

        return SonificationResult(
            frequency: audioFreq,
            amplitude: amplitude,
            octavesShifted: 8,
            sourceDescription: "\(Int(bpm)) BPM"
        )
    }

    private func sonifyRespiration(rate: Double) -> SonificationResult {
        let breathFreq = rate / 60.0  // Breaths per minute to Hz
        let audioFreq = transposer.transposeByOctaves(breathFreq, octaves: 9)

        return SonificationResult(
            frequency: audioFreq,
            amplitude: 0.5,
            octavesShifted: 9,
            sourceDescription: "\(Int(rate)) breaths/min"
        )
    }

    private func sonifyEMG(frequency: Double, amplitude: Double) -> SonificationResult {
        // EMG is already in audible range (20-500 Hz)
        // Just pass through with amplitude modulation
        let audioFreq = max(20, min(500, frequency))

        return SonificationResult(
            frequency: audioFreq,
            amplitude: amplitude,
            octavesShifted: 0,
            sourceDescription: "EMG \(Int(frequency)) Hz"
        )
    }

    private func sonifyGSR(level: Double, changeRate: Double) -> SonificationResult {
        // GSR changes are very slow, map level to pitch
        let audioFreq = transposer.mapLinear(level, fromRange: 0...100, toRange: 200...800)

        // Change rate affects amplitude
        let amplitude = transposer.mapLinear(abs(changeRate), fromRange: 0...10, toRange: 0.1...1.0)

        return SonificationResult(
            frequency: audioFreq,
            amplitude: amplitude,
            octavesShifted: 0,  // Not octave-based
            sourceDescription: "GSR level \(Int(level))%"
        )
    }

    private init() {}
}

// MARK: - Supporting Types

public struct BiofeedbackSample {
    public let timestamp: TimeInterval
    public let type: SampleType

    public enum SampleType {
        case eegPower(band: String, power: Double)
        case hrvFrequency(frequency: Double, amplitude: Double)
        case heartRate(bpm: Double)
        case respiration(rate: Double)
        case emg(frequency: Double, amplitude: Double)
        case gsr(level: Double, changeRate: Double)
    }

    public init(timestamp: TimeInterval, type: SampleType) {
        self.timestamp = timestamp
        self.type = type
    }
}

public struct SonificationResult {
    public let frequency: Double      // Output audio frequency in Hz
    public let amplitude: Double      // 0-1
    public let octavesShifted: Int    // How many octaves transposed
    public let sourceDescription: String

    public var midiNote: Int {
        // Convert frequency to MIDI note number
        // MIDI 69 = A4 = 440 Hz
        return Int(round(69 + 12 * log2(frequency / 440.0)))
    }

    public var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Frequency Table Generator

extension FrequencyTransposer {

    /// Generate transposition table for a frequency range
    public func generateTranspositionTable(
        sourceRange: ClosedRange<Double>,
        targetRange: ClosedRange<Double>,
        steps: Int = 12
    ) -> [TranspositionTableEntry] {
        var table: [TranspositionTableEntry] = []

        let sourceLogMin = log10(sourceRange.lowerBound)
        let sourceLogMax = log10(sourceRange.upperBound)

        for i in 0..<steps {
            let t = Double(i) / Double(steps - 1)
            let sourceFreq = pow(10, sourceLogMin + t * (sourceLogMax - sourceLogMin))

            let octaves = octavesRequired(from: sourceFreq, toRange: targetRange.lowerBound, targetRange.upperBound)
            let targetFreq = transposeByOctaves(sourceFreq, octaves: octaves)

            table.append(TranspositionTableEntry(
                sourceFrequency: sourceFreq,
                targetFrequency: targetFreq,
                octavesShifted: octaves,
                ratio: targetFreq / sourceFreq
            ))
        }

        return table
    }

    public struct TranspositionTableEntry {
        public let sourceFrequency: Double
        public let targetFrequency: Double
        public let octavesShifted: Int
        public let ratio: Double

        public var description: String {
            return "\(FrequencyTransposer.shared.formatFrequency(sourceFrequency)) → \(FrequencyTransposer.shared.formatFrequency(targetFrequency)) (+\(octavesShifted) oct)"
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension FrequencyTransposer {

    func printTranspositionExamples() {
        print("\n🔊 Frequency Transposition Examples")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // EEG Brainwaves
        print("\nEEG Brainwaves → Audible:")
        for band in FrequencyConstants.Biofeedback.EEG.bands {
            let center = (band.min + band.max) / 2
            let (transposed, octaves) = transposeToAudible(center)
            print("  \(band.name) (\(band.min)-\(band.max) Hz) → \(formatFrequency(transposed)) (+\(octaves) octaves)")
        }

        // HRV
        print("\nHRV Bands → Audible:")
        let hrvBands = [
            ("VLF", 0.003, 0.04),
            ("LF", 0.04, 0.15),
            ("HF", 0.15, 0.4)
        ]
        for band in hrvBands {
            let center = (band.1 + band.2) / 2
            let (transposed, octaves) = transposeToAudible(center)
            print("  \(band.0) (\(band.1)-\(band.2) Hz) → \(formatFrequency(transposed)) (+\(octaves) octaves)")
        }

        // Heart Rate
        print("\nHeart Rate → Audible:")
        for bpm in [60.0, 80.0, 100.0, 120.0] {
            let freq = heartRateToFrequency(bpm)
            let (transposed, octaves) = transposeToAudible(freq)
            print("  \(Int(bpm)) BPM (\(formatFrequency(freq))) → \(formatFrequency(transposed)) (+\(octaves) octaves)")
        }

        // Audio to Light
        print("\nAudio → Visible Light:")
        for note in [("A2", 110.0), ("A3", 220.0), ("A4", 440.0), ("A5", 880.0), ("A6", 1760.0)] {
            let result = audioToVisibleLight(note.1)
            print("  \(note.0) (\(formatFrequency(note.1))) → \(String(format: "%.0f", result.wavelengthNm)) nm (RGB: \(String(format: "%.2f, %.2f, %.2f", result.rgb.r, result.rgb.g, result.rgb.b)))")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
#endif
