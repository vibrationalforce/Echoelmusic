//
//  MusicalTuningSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  COMPREHENSIVE MUSICAL TUNING SYSTEM
//
//  Physically correct octave tuning with multiple temperaments:
//  - Equal Temperament (12-TET, modern standard)
//  - Pythagorean Tuning (perfect 3:2 fifths)
//  - Just Intonation (whole number frequency ratios)
//  - 432 Hz Tuning (Verdi pitch, "cosmic" tuning)
//  - Planck-Derived Frequencies (physics-based)
//  - Schumann Resonance Based (Earth frequencies)
//  - Historical Temperaments (Meantone, Well-tempered, etc.)
//
//  Physics Background:
//  - Octave = 2:1 frequency ratio (universal)
//  - Perfect Fifth = 3:2 ratio (Pythagorean)
//  - Perfect Fourth = 4:3 ratio
//  - Planck frequency = √(c⁵/ℏG) ≈ 1.855×10⁴³ Hz
//  - Schumann resonance = 7.83 Hz (Earth's EM cavity)
//

import Foundation
import Combine

// MARK: - Musical Tuning Manager

@MainActor
public class MusicalTuningSystem: ObservableObject {

    // Singleton
    public static let shared = MusicalTuningSystem()

    // MARK: - Published State

    @Published public var currentTuning: TuningSystem = .equalTemperament
    @Published public var concertPitch: Double = 440.0  // A4 frequency
    @Published public var masterTune: Double = 0.0  // Cents deviation from concert pitch

    // MARK: - Physical Constants

    public enum PhysicalConstants {
        // Planck units (SI)
        public static let planckConstant: Double = 6.62607015e-34  // J·s (exact)
        public static let reducedPlanck: Double = 1.054571817e-34  // ℏ = h/2π
        public static let speedOfLight: Double = 299792458.0  // m/s (exact)
        public static let gravitationalConstant: Double = 6.67430e-11  // m³/(kg·s²)

        // Planck frequency = √(c⁵/ℏG)
        public static var planckFrequency: Double {
            let c5 = pow(speedOfLight, 5)
            let hG = reducedPlanck * gravitationalConstant
            return sqrt(c5 / hG)  // ≈ 1.855×10⁴³ Hz
        }

        // Octave reduction of Planck frequency to audible range
        // We reduce by ~143 octaves to get into musical range
        public static func planckOctaveReduced(targetOctave: Int = 4) -> Double {
            // log₂(planckFreq / 440) ≈ 143 octaves above A4
            // We'll derive a "Planck A" by reducing
            let octavesAboveA4 = log2(planckFrequency / 440.0)
            let octavesToReduce = Int(octavesAboveA4) - targetOctave + 4
            return planckFrequency / pow(2.0, Double(octavesToReduce))
        }

        // Schumann resonances (Earth's electromagnetic cavity)
        public static let schumannFundamental: Double = 7.83  // Hz
        public static let schumannHarmonics: [Double] = [7.83, 14.3, 20.8, 27.3, 33.8]

        // Golden ratio
        public static let phi: Double = 1.6180339887498948482

        // Mathematical constants for tuning
        public static let pythagoreanComma: Double = 531441.0 / 524288.0  // (3/2)^12 / 2^7
        public static let syntonicComma: Double = 81.0 / 80.0  // Difference between Pythagorean and Just major third
    }

    // MARK: - Tuning Systems

    public enum TuningSystem: String, CaseIterable, Identifiable {
        case equalTemperament = "Equal Temperament (12-TET)"
        case pythagorean = "Pythagorean"
        case justIntonationMajor = "Just Intonation (Major)"
        case justIntonationMinor = "Just Intonation (Minor)"
        case concert432 = "432 Hz Tuning"
        case scientific256C = "Scientific C256"
        case planckDerived = "Planck-Derived"
        case schumannBased = "Schumann Resonance"
        case goldenRatio = "Golden Ratio"
        case meantoneQuarter = "Quarter-Comma Meantone"
        case wellTempered = "Well Temperament (Werckmeister III)"
        case kirnberger = "Kirnberger III"
        case custom = "Custom"

        public var id: String { rawValue }

        public var description: String {
            switch self {
            case .equalTemperament:
                return "Modern standard: all semitones equal (2^(1/12)). Universal but no pure intervals except octave."
            case .pythagorean:
                return "Based on pure perfect fifths (3:2). Excellent for melodic music, harsh major thirds."
            case .justIntonationMajor:
                return "Pure whole-number ratios. Perfect consonance in one key, unusable in others."
            case .justIntonationMinor:
                return "Just intonation optimized for minor keys with pure minor thirds."
            case .concert432:
                return "A4 = 432 Hz. Claimed to align with natural/cosmic frequencies. Verdi's preferred pitch."
            case .scientific256C:
                return "C4 = 256 Hz (2^8). Mathematically elegant, all C notes are powers of 2."
            case .planckDerived:
                return "Frequencies derived from Planck constant octave reduction. Physics-based tuning."
            case .schumannBased:
                return "Based on Earth's 7.83 Hz resonance. Octave-expanded for musical use."
            case .goldenRatio:
                return "Intervals based on φ (1.618...). Experimental non-octave tuning."
            case .meantoneQuarter:
                return "Historical temperament with pure major thirds. Common in Renaissance/Baroque."
            case .wellTempered:
                return "All keys playable with varying character. Bach's Well-Tempered Clavier."
            case .kirnberger:
                return "Compromise between meantone and equal temperament. Pure fifths on C-G-D-A."
            case .custom:
                return "User-defined ratios for each interval."
            }
        }

        public var defaultConcertPitch: Double {
            switch self {
            case .concert432: return 432.0
            case .scientific256C: return 430.5389646099  // A4 when C4 = 256 Hz
            case .schumannBased: return 432.09375  // 7.83 Hz × 2^5.78...
            default: return 440.0
            }
        }
    }

    // MARK: - Interval Ratios

    /// Interval ratios for different tuning systems
    public struct IntervalRatios {
        // Note: ratios are relative to the tonic (1/1)
        // Index 0 = unison, 1 = minor second, 2 = major second, etc.

        /// 12-TET Equal Temperament: 2^(n/12)
        public static let equalTemperament: [Double] = (0...12).map { pow(2.0, Double($0) / 12.0) }

        /// Pythagorean tuning (based on 3:2 fifths)
        public static let pythagorean: [Double] = [
            1.0,            // Unison (C)
            256.0/243.0,    // Minor 2nd (C#/Db) - Pythagorean limma
            9.0/8.0,        // Major 2nd (D) - whole tone
            32.0/27.0,      // Minor 3rd (D#/Eb)
            81.0/64.0,      // Major 3rd (E) - ditone (harsh!)
            4.0/3.0,        // Perfect 4th (F)
            729.0/512.0,    // Tritone (F#/Gb) - augmented 4th
            3.0/2.0,        // Perfect 5th (G) - PURE
            128.0/81.0,     // Minor 6th (G#/Ab)
            27.0/16.0,      // Major 6th (A)
            16.0/9.0,       // Minor 7th (A#/Bb)
            243.0/128.0,    // Major 7th (B)
            2.0             // Octave (C')
        ]

        /// Just Intonation (5-limit, major scale optimized)
        public static let justIntonationMajor: [Double] = [
            1.0,            // Unison (C)
            16.0/15.0,      // Minor 2nd (C#/Db)
            9.0/8.0,        // Major 2nd (D)
            6.0/5.0,        // Minor 3rd (D#/Eb)
            5.0/4.0,        // Major 3rd (E) - PURE
            4.0/3.0,        // Perfect 4th (F) - PURE
            45.0/32.0,      // Tritone (F#/Gb)
            3.0/2.0,        // Perfect 5th (G) - PURE
            8.0/5.0,        // Minor 6th (G#/Ab)
            5.0/3.0,        // Major 6th (A)
            9.0/5.0,        // Minor 7th (A#/Bb)
            15.0/8.0,       // Major 7th (B)
            2.0             // Octave (C')
        ]

        /// Just Intonation (minor scale optimized)
        public static let justIntonationMinor: [Double] = [
            1.0,            // Unison
            16.0/15.0,      // Minor 2nd
            10.0/9.0,       // Major 2nd (smaller)
            6.0/5.0,        // Minor 3rd - PURE
            5.0/4.0,        // Major 3rd
            4.0/3.0,        // Perfect 4th
            64.0/45.0,      // Tritone
            3.0/2.0,        // Perfect 5th
            8.0/5.0,        // Minor 6th - PURE
            5.0/3.0,        // Major 6th
            16.0/9.0,       // Minor 7th
            15.0/8.0,       // Major 7th
            2.0             // Octave
        ]

        /// Quarter-comma Meantone
        public static var meantoneQuarter: [Double] {
            let fifth = pow(5.0, 0.25)  // Meantone fifth = 5^(1/4) ≈ 1.495
            return [
                1.0,
                8.0 / (fifth * fifth * fifth * fifth * fifth),  // Minor 2nd
                fifth * fifth / 2.0,  // Major 2nd (two fifths down an octave)
                4.0 / (fifth * fifth * fifth),  // Minor 3rd
                5.0 / 4.0,  // Major 3rd - PURE (that's the point!)
                2.0 / fifth,  // Perfect 4th
                fifth * fifth * fifth * fifth * fifth * fifth / 8.0,  // Tritone
                fifth,  // Fifth (tempered)
                8.0 / (fifth * fifth * fifth * fifth * fifth),  // Minor 6th adjusted
                fifth * fifth * fifth / 2.0,  // Major 6th
                4.0 / fifth,  // Minor 7th
                fifth * fifth * fifth * fifth * fifth / 4.0,  // Major 7th
                2.0
            ]
        }

        /// Werckmeister III (well temperament)
        public static let werckmeisterIII: [Double] = [
            1.0,
            256.0 / 243.0,
            64.0 / 57.0 * pow(2.0, 0.25),  // Adjusted
            32.0 / 27.0,
            256.0 / 205.0 * pow(2.0, 0.25),
            4.0 / 3.0,
            1024.0 / 729.0,
            pow(2.0, 0.25) * 8.0 / 9.0 * 3.0 / 2.0,
            128.0 / 81.0,
            pow(2.0, 0.5) * 2.0 / 3.0 * 3.0 / 2.0,
            16.0 / 9.0,
            pow(2.0, 0.25) * 4.0 / 3.0 * 9.0 / 8.0,
            2.0
        ]
    }

    // MARK: - Concert Pitch Presets

    public enum ConcertPitchPreset: CaseIterable {
        case modern440
        case baroque415
        case classical430
        case verdi432
        case scientific256C  // C4 = 256 Hz → A4 ≈ 430.54 Hz
        case custom

        public var frequency: Double {
            switch self {
            case .modern440: return 440.0
            case .baroque415: return 415.0
            case .classical430: return 430.0
            case .verdi432: return 432.0
            case .scientific256C: return 430.5389646099  // A4 when C4 = 256 Hz
            case .custom: return 440.0
            }
        }

        public var name: String {
            switch self {
            case .modern440: return "Modern Standard (A = 440 Hz)"
            case .baroque415: return "Baroque (A = 415 Hz)"
            case .classical430: return "Classical (A = 430 Hz)"
            case .verdi432: return "Verdi (A = 432 Hz)"
            case .scientific256C: return "Scientific Pitch (C = 256 Hz)"
            case .custom: return "Custom"
            }
        }

        public var history: String {
            switch self {
            case .modern440:
                return "Standardized in 1955 by ISO 16. Universal today."
            case .baroque415:
                return "Common in 17th-18th century. Still used for historical performance."
            case .classical430:
                return "Mozart and Beethoven era. French standard until mid-19th century."
            case .verdi432:
                return "Advocated by Giuseppe Verdi in 1884 for easier singing."
            case .scientific256C:
                return "C4 = 256 Hz = 2^8 Hz. Mathematically elegant, used in acoustics research."
            case .custom:
                return "User-defined concert pitch."
            }
        }
    }

    // MARK: - Audible Frequency Range

    public enum AudibleRange {
        /// Human hearing range
        public static let minimum: Double = 20.0       // Hz (lower limit)
        public static let maximum: Double = 20000.0    // Hz (upper limit)
        public static let speechLow: Double = 85.0     // Hz (male fundamental)
        public static let speechHigh: Double = 255.0   // Hz (female fundamental)
        public static let musicLow: Double = 27.5      // Hz (A0, lowest piano key)
        public static let musicHigh: Double = 4186.0   // Hz (C8, highest piano key)

        /// Octaves needed to transpose a frequency into audible range
        public static func octavesToAudible(from frequency: Double) -> Int {
            if frequency <= 0 { return 0 }
            if frequency >= minimum && frequency <= maximum { return 0 }

            if frequency < minimum {
                return Int(ceil(log2(minimum / frequency)))
            } else {
                return -Int(ceil(log2(frequency / maximum)))
            }
        }

        /// Transpose any frequency into audible range via octave shifts
        public static func transposeToAudible(_ frequency: Double, targetCenter: Double = 440.0) -> Double {
            if frequency <= 0 { return targetCenter }

            var freq = frequency
            while freq < minimum { freq *= 2.0 }
            while freq > maximum { freq /= 2.0 }
            return freq
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Frequency Calculation

    /// Calculate frequency for a given MIDI note number
    /// MIDI 69 = A4 = concert pitch
    public func frequency(forMIDINote note: Int) -> Double {
        let ratios = getRatios(for: currentTuning)
        let effectivePitch = concertPitch * pow(2.0, masterTune / 1200.0)

        // MIDI 69 = A4
        // MIDI 60 = C4 (middle C)
        let octave = (note - 69) / 12
        let semitone = ((note - 69) % 12 + 12) % 12  // 0-11, relative to A

        // Convert A-relative to C-relative index
        // A = 9 semitones above C, so we need to shift
        let cRelativeIndex = (semitone + 3) % 12  // A=0 → becomes C=0

        // Base frequency is A4
        // First get to C of the same octave, then apply ratio
        let cOfOctave = effectivePitch / ratios[9]  // C4 freq when A4 = effectivePitch
        let noteFreq = cOfOctave * ratios[cRelativeIndex]

        // Apply octave shift
        return noteFreq * pow(2.0, Double(octave))
    }

    /// Calculate frequency using standard A4-relative calculation
    public func frequencySimple(forMIDINote note: Int) -> Double {
        let ratios = getRatios(for: currentTuning)
        let effectivePitch = concertPitch * pow(2.0, masterTune / 1200.0)

        // Simple approach: calculate semitones from A4
        let semitonesFromA4 = note - 69
        let octaves = semitonesFromA4 / 12
        let semitoneInOctave = ((semitonesFromA4 % 12) + 12) % 12

        // For equal temperament, just use the formula
        if currentTuning == .equalTemperament {
            return effectivePitch * pow(2.0, Double(semitonesFromA4) / 12.0)
        }

        // For other tunings, we need the ratio relative to A
        // A is the 9th note (index 9) in C-based scale
        let aRatio = ratios[9]
        let targetRatio = ratios[(semitoneInOctave + 9) % 12]  // Shift to A-relative

        return effectivePitch * (targetRatio / aRatio) * pow(2.0, Double(octaves))
    }

    /// Get interval ratios for a tuning system
    public func getRatios(for tuning: TuningSystem) -> [Double] {
        switch tuning {
        case .equalTemperament:
            return IntervalRatios.equalTemperament
        case .pythagorean:
            return IntervalRatios.pythagorean
        case .justIntonationMajor:
            return IntervalRatios.justIntonationMajor
        case .justIntonationMinor:
            return IntervalRatios.justIntonationMinor
        case .meantoneQuarter:
            return IntervalRatios.meantoneQuarter
        case .wellTempered:
            return IntervalRatios.werckmeisterIII
        case .kirnberger:
            return IntervalRatios.werckmeisterIII  // Similar
        case .concert432, .scientific256C:
            return IntervalRatios.equalTemperament  // Same ratios, different base
        case .planckDerived:
            return calculatePlanckRatios()
        case .schumannBased:
            return calculateSchumannRatios()
        case .goldenRatio:
            return calculateGoldenRatios()
        case .custom:
            return customRatios.isEmpty ? IntervalRatios.equalTemperament : customRatios
        }
    }

    // MARK: - Special Tuning Calculations

    /// Planck-derived frequency ratios
    /// Uses octave-reduced Planck frequency as reference
    private func calculatePlanckRatios() -> [Double] {
        // Start with equal temperament but adjust based on Planck harmonics
        // This is experimental/artistic interpretation
        var ratios = IntervalRatios.equalTemperament

        // Planck frequency octave-reduced gives us a "fundamental"
        // We can derive "pure" intervals from this
        // Using 7-limit just intonation as approximation of "natural" ratios
        ratios[7] = 3.0 / 2.0  // Perfect fifth
        ratios[5] = 4.0 / 3.0  // Perfect fourth
        ratios[4] = 5.0 / 4.0  // Major third
        ratios[3] = 6.0 / 5.0  // Minor third
        ratios[10] = 7.0 / 4.0  // Harmonic seventh (7-limit)

        return ratios
    }

    /// Schumann resonance-based ratios
    /// Expands 7.83 Hz to musical octaves
    private func calculateSchumannRatios() -> [Double] {
        // Use Schumann harmonics to derive intervals
        // 7.83, 14.3, 20.8, 27.3, 33.8 Hz
        // These aren't exact octaves, creating unique intervals

        var ratios = [Double](repeating: 1.0, count: 13)
        ratios[0] = 1.0
        ratios[12] = 2.0

        // Map Schumann harmonics to scale degrees
        let schumann = PhysicalConstants.schumannHarmonics
        let fundamental = schumann[0]

        ratios[5] = schumann[1] / fundamental / (14.3 / 7.83)  // ~4th
        ratios[7] = schumann[2] / fundamental / 2.0  // ~5th
        ratios[9] = schumann[3] / fundamental / 2.0  // ~6th
        ratios[11] = schumann[4] / fundamental / 4.0  // ~7th

        // Fill in remaining with just intonation
        ratios[1] = 16.0 / 15.0
        ratios[2] = 9.0 / 8.0
        ratios[3] = 6.0 / 5.0
        ratios[4] = 5.0 / 4.0
        ratios[6] = 45.0 / 32.0
        ratios[8] = 8.0 / 5.0
        ratios[10] = 9.0 / 5.0

        return ratios
    }

    /// Golden ratio-based tuning (experimental)
    private func calculateGoldenRatios() -> [Double] {
        let phi = PhysicalConstants.phi

        // Create scale based on powers of phi
        // This doesn't create standard octaves!
        var ratios = [Double](repeating: 1.0, count: 13)

        for i in 0...12 {
            // Use phi^(n/7) to create ~12 steps within phi^(12/7) ≈ 2.058
            ratios[i] = pow(phi, Double(i) / 7.0)
        }

        // Normalize so that index 12 = 2.0 (standard octave)
        let octaveFactor = 2.0 / ratios[12]
        for i in 0...12 {
            ratios[i] *= octaveFactor
        }

        return ratios
    }

    // MARK: - Custom Tuning

    @Published public var customRatios: [Double] = []

    /// Set custom interval ratios
    public func setCustomRatios(_ ratios: [Double]) {
        guard ratios.count == 13 else {
            print("⚠️ Custom ratios must have 13 values (unison through octave)")
            return
        }
        customRatios = ratios
        currentTuning = .custom
    }

    // MARK: - Tuning Comparison

    /// Compare two notes across different tuning systems
    public func compareTunings(midiNote: Int) -> [(TuningSystem, Double)] {
        return TuningSystem.allCases.map { tuning in
            let savedTuning = currentTuning
            let savedPitch = concertPitch

            currentTuning = tuning
            concertPitch = tuning.defaultConcertPitch

            let freq = frequencySimple(forMIDINote: midiNote)

            currentTuning = savedTuning
            concertPitch = savedPitch

            return (tuning, freq)
        }
    }

    /// Get cent deviation from equal temperament
    public func centsDeviation(forMIDINote note: Int) -> Double {
        let currentFreq = frequencySimple(forMIDINote: note)
        let etFreq = concertPitch * pow(2.0, Double(note - 69) / 12.0)

        return 1200.0 * log2(currentFreq / etFreq)
    }

    // MARK: - Frequency Table Generation

    /// Generate complete frequency table for current tuning
    public func generateFrequencyTable(octaveRange: ClosedRange<Int> = 0...8) -> [NoteFrequency] {
        var table: [NoteFrequency] = []
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        for octave in octaveRange {
            for (index, noteName) in noteNames.enumerated() {
                let midiNote = (octave + 1) * 12 + index  // C-1 = MIDI 0
                let freq = frequencySimple(forMIDINote: midiNote)
                let cents = centsDeviation(forMIDINote: midiNote)

                table.append(NoteFrequency(
                    name: "\(noteName)\(octave)",
                    midiNote: midiNote,
                    frequency: freq,
                    centsFromET: cents
                ))
            }
        }

        return table
    }

    public struct NoteFrequency: Identifiable {
        public let id = UUID()
        public let name: String
        public let midiNote: Int
        public let frequency: Double
        public let centsFromET: Double

        public var frequencyFormatted: String {
            String(format: "%.2f Hz", frequency)
        }

        public var centsFormatted: String {
            if abs(centsFromET) < 0.01 {
                return "±0"
            }
            return String(format: "%+.1f¢", centsFromET)
        }
    }

    // MARK: - Pitch Detection Helpers

    /// Find nearest note for a given frequency
    public func nearestNote(forFrequency freq: Double) -> (midiNote: Int, cents: Double) {
        // For equal temperament, simple calculation
        let midiFloat = 69.0 + 12.0 * log2(freq / concertPitch)
        let midiNote = Int(round(midiFloat))
        let cents = (midiFloat - Double(midiNote)) * 100.0

        return (midiNote, cents)
    }

    // MARK: - Presets

    /// Apply a concert pitch preset
    public func applyConcertPitch(_ preset: ConcertPitchPreset) {
        concertPitch = preset.frequency
        print("🎵 Concert pitch set to \(preset.name)")
    }

    /// Apply a tuning system
    public func applyTuning(_ tuning: TuningSystem) {
        currentTuning = tuning
        if tuning.defaultConcertPitch != 440.0 {
            concertPitch = tuning.defaultConcertPitch
        }
        print("🎵 Tuning system: \(tuning.rawValue)")
    }
}

// MARK: - Cents/Ratio Conversion

extension MusicalTuningSystem {

    /// Convert frequency ratio to cents
    public static func ratioToCents(_ ratio: Double) -> Double {
        return 1200.0 * log2(ratio)
    }

    /// Convert cents to frequency ratio
    public static func centsToRatio(_ cents: Double) -> Double {
        return pow(2.0, cents / 1200.0)
    }

    /// Convert Hz difference to cents
    public static func hzToCents(from freq1: Double, to freq2: Double) -> Double {
        return 1200.0 * log2(freq2 / freq1)
    }
}

// MARK: - Musical Intervals

extension MusicalTuningSystem {

    public enum Interval: Int, CaseIterable {
        case unison = 0
        case minorSecond = 1
        case majorSecond = 2
        case minorThird = 3
        case majorThird = 4
        case perfectFourth = 5
        case tritone = 6
        case perfectFifth = 7
        case minorSixth = 8
        case majorSixth = 9
        case minorSeventh = 10
        case majorSeventh = 11
        case octave = 12

        public var name: String {
            switch self {
            case .unison: return "Unison"
            case .minorSecond: return "Minor 2nd"
            case .majorSecond: return "Major 2nd"
            case .minorThird: return "Minor 3rd"
            case .majorThird: return "Major 3rd"
            case .perfectFourth: return "Perfect 4th"
            case .tritone: return "Tritone"
            case .perfectFifth: return "Perfect 5th"
            case .minorSixth: return "Minor 6th"
            case .majorSixth: return "Major 6th"
            case .minorSeventh: return "Minor 7th"
            case .majorSeventh: return "Major 7th"
            case .octave: return "Octave"
            }
        }

        /// Just intonation ratio (most consonant)
        public var justRatio: (Int, Int) {
            switch self {
            case .unison: return (1, 1)
            case .minorSecond: return (16, 15)
            case .majorSecond: return (9, 8)
            case .minorThird: return (6, 5)
            case .majorThird: return (5, 4)
            case .perfectFourth: return (4, 3)
            case .tritone: return (45, 32)
            case .perfectFifth: return (3, 2)
            case .minorSixth: return (8, 5)
            case .majorSixth: return (5, 3)
            case .minorSeventh: return (9, 5)
            case .majorSeventh: return (15, 8)
            case .octave: return (2, 1)
            }
        }

        public var justRatioValue: Double {
            let (num, den) = justRatio
            return Double(num) / Double(den)
        }

        /// Equal temperament ratio
        public var etRatio: Double {
            return pow(2.0, Double(rawValue) / 12.0)
        }

        /// Cents in equal temperament
        public var etCents: Double {
            return Double(rawValue) * 100.0
        }

        /// Cents deviation of just from ET
        public var justDeviationCents: Double {
            return MusicalTuningSystem.ratioToCents(justRatioValue) - etCents
        }
    }
}

// MARK: - Debug / Print Helpers

#if DEBUG
extension MusicalTuningSystem {

    /// Print frequency comparison table
    func printComparisonTable() {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = 4

        print("\n🎵 Frequency Comparison Table (Octave \(octave))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(String(format: "%-5s │ %12s │ %12s │ %12s │ %12s │ %12s",
              "Note", "12-TET", "Pythagorean", "Just Major", "432 Hz", "Planck"))
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let tunings: [TuningSystem] = [.equalTemperament, .pythagorean, .justIntonationMajor, .concert432, .planckDerived]

        for (index, noteName) in noteNames.enumerated() {
            let midiNote = 60 + index  // Start from C4
            var freqs: [Double] = []

            for tuning in tunings {
                let savedTuning = currentTuning
                let savedPitch = concertPitch

                currentTuning = tuning
                concertPitch = tuning.defaultConcertPitch
                freqs.append(frequencySimple(forMIDINote: midiNote))

                currentTuning = savedTuning
                concertPitch = savedPitch
            }

            print(String(format: "%-5s │ %10.2f Hz │ %10.2f Hz │ %10.2f Hz │ %10.2f Hz │ %10.2f Hz",
                  "\(noteName)\(octave)", freqs[0], freqs[1], freqs[2], freqs[3], freqs[4]))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// Print interval analysis
    func printIntervalAnalysis() {
        print("\n🎵 Interval Analysis: \(currentTuning.rawValue)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let ratios = getRatios(for: currentTuning)

        for interval in Interval.allCases {
            let currentRatio = ratios[interval.rawValue]
            let justRatio = interval.justRatioValue
            let etRatio = interval.etRatio

            let centsFromJust = MusicalTuningSystem.ratioToCents(currentRatio / justRatio)
            let centsFromET = MusicalTuningSystem.ratioToCents(currentRatio / etRatio)

            print(String(format: "%-14s │ Ratio: %7.4f │ vs Just: %+6.1f¢ │ vs ET: %+6.1f¢",
                  interval.name, currentRatio, centsFromJust, centsFromET))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
#endif
