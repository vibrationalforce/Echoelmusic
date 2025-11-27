//
//  EchoelCalculator.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  ECHOELCALCULATOR - Complete Audio Toolkit
//  Inspired by Sengpiel Audio but with MORE features
//
//  **Features:**
//  - BPM ↔ ms/Hz/Samples conversion
//  - Frequency ↔ MIDI Note ↔ Wavelength
//  - Delay Time Calculator (with note values)
//  - Room Acoustics (RT60, early reflections)
//  - dB calculations (SPL, dBFS, voltage)
//  - Filter frequency calculations
//  - Psychoacoustic calculations
//  - Speed of Sound calculations
//  - Sample Rate conversions
//  - Musical intervals and ratios
//

import Foundation
import SwiftUI

// MARK: - EchoelCalculator

@MainActor
class EchoelCalculator: ObservableObject {
    static let shared = EchoelCalculator()

    // MARK: - Constants

    struct AudioConstants {
        // Speed of sound
        static let speedOfSoundAt20C: Double = 343.2  // m/s at 20°C
        static let speedOfSoundAt0C: Double = 331.3   // m/s at 0°C

        // Reference frequencies
        static let a4Frequency: Double = 440.0        // Concert pitch A4
        static let middleCFrequency: Double = 261.63  // C4

        // Reference levels
        static let referenceDBSPL: Double = 20e-6     // 20 µPa (threshold of hearing)
        static let referenceVoltage: Double = 0.775   // dBu reference
        static let referenceDBFS: Double = 1.0        // Full scale

        // Sample rates
        static let cdSampleRate: Double = 44100.0
        static let professionalSampleRate: Double = 48000.0
        static let highResSampleRate: Double = 96000.0
        static let ultraHighResSampleRate: Double = 192000.0
    }

    // MARK: - BPM Calculations

    /// Convert BPM to milliseconds per beat
    func bpmToMs(bpm: Double) -> Double {
        guard bpm > 0 else { return 0 }
        return 60000.0 / bpm
    }

    /// Convert milliseconds to BPM
    func msToBpm(ms: Double) -> Double {
        guard ms > 0 else { return 0 }
        return 60000.0 / ms
    }

    /// Convert BPM to Hz (beats per second)
    func bpmToHz(bpm: Double) -> Double {
        return bpm / 60.0
    }

    /// Convert Hz to BPM
    func hzToBpm(hz: Double) -> Double {
        return hz * 60.0
    }

    /// Convert BPM to samples per beat
    func bpmToSamples(bpm: Double, sampleRate: Double = 48000) -> Double {
        let ms = bpmToMs(bpm: bpm)
        return msToSamples(ms: ms, sampleRate: sampleRate)
    }

    // MARK: - Delay Time Calculator

    struct DelayTime {
        let noteValue: NoteValue
        let ms: Double
        let samples: Int
        let hz: Double

        enum NoteValue: String, CaseIterable {
            case whole = "1/1"
            case half = "1/2"
            case quarter = "1/4"
            case eighth = "1/8"
            case sixteenth = "1/16"
            case thirtySecond = "1/32"
            case sixtyFourth = "1/64"
            case halfDotted = "1/2."
            case quarterDotted = "1/4."
            case eighthDotted = "1/8."
            case sixteenthDotted = "1/16."
            case halfTriplet = "1/2T"
            case quarterTriplet = "1/4T"
            case eighthTriplet = "1/8T"
            case sixteenthTriplet = "1/16T"

            var multiplier: Double {
                switch self {
                case .whole: return 4.0
                case .half: return 2.0
                case .quarter: return 1.0
                case .eighth: return 0.5
                case .sixteenth: return 0.25
                case .thirtySecond: return 0.125
                case .sixtyFourth: return 0.0625
                case .halfDotted: return 3.0           // 2 * 1.5
                case .quarterDotted: return 1.5        // 1 * 1.5
                case .eighthDotted: return 0.75        // 0.5 * 1.5
                case .sixteenthDotted: return 0.375    // 0.25 * 1.5
                case .halfTriplet: return 4.0 / 3.0    // 2 * 2/3
                case .quarterTriplet: return 2.0 / 3.0 // 1 * 2/3
                case .eighthTriplet: return 1.0 / 3.0  // 0.5 * 2/3
                case .sixteenthTriplet: return 1.0 / 6.0
                }
            }
        }
    }

    /// Calculate all delay times for a given BPM
    func calculateDelayTimes(bpm: Double, sampleRate: Double = 48000) -> [DelayTime] {
        let quarterNoteMs = bpmToMs(bpm: bpm)

        return DelayTime.NoteValue.allCases.map { noteValue in
            let ms = quarterNoteMs * noteValue.multiplier
            let samples = Int(ms * sampleRate / 1000.0)
            let hz = 1000.0 / ms

            return DelayTime(
                noteValue: noteValue,
                ms: ms,
                samples: samples,
                hz: hz
            )
        }
    }

    /// Get delay time for specific note value
    func delayTimeForNote(_ noteValue: DelayTime.NoteValue, bpm: Double, sampleRate: Double = 48000) -> DelayTime {
        let quarterNoteMs = bpmToMs(bpm: bpm)
        let ms = quarterNoteMs * noteValue.multiplier
        let samples = Int(ms * sampleRate / 1000.0)
        let hz = 1000.0 / ms

        return DelayTime(noteValue: noteValue, ms: ms, samples: samples, hz: hz)
    }

    // MARK: - Frequency Calculations

    /// Convert frequency to MIDI note number
    func frequencyToMIDI(_ frequency: Double, a4: Double = 440.0) -> Double {
        guard frequency > 0 else { return 0 }
        return 69.0 + 12.0 * log2(frequency / a4)
    }

    /// Convert MIDI note number to frequency
    func midiToFrequency(_ midiNote: Double, a4: Double = 440.0) -> Double {
        return a4 * pow(2.0, (midiNote - 69.0) / 12.0)
    }

    /// Convert frequency to note name
    func frequencyToNoteName(_ frequency: Double, a4: Double = 440.0) -> String {
        let midiNote = frequencyToMIDI(frequency, a4: a4)
        return midiNoteToName(Int(round(midiNote)))
    }

    /// Convert MIDI note to name (e.g., 60 → "C4")
    func midiNoteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }

    /// Convert note name to MIDI (e.g., "C4" → 60)
    func noteNameToMIDI(_ name: String) -> Int? {
        let noteValues: [String: Int] = [
            "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
            "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
            "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11
        ]

        // Parse note name and octave
        var notePart = ""
        var octavePart = ""

        for char in name {
            if char.isNumber || char == "-" {
                octavePart.append(char)
            } else {
                notePart.append(char)
            }
        }

        guard let noteValue = noteValues[notePart],
              let octave = Int(octavePart) else { return nil }

        return (octave + 1) * 12 + noteValue
    }

    /// Calculate wavelength from frequency
    func frequencyToWavelength(_ frequency: Double, speedOfSound: Double = 343.2) -> Double {
        guard frequency > 0 else { return 0 }
        return speedOfSound / frequency
    }

    /// Calculate frequency from wavelength
    func wavelengthToFrequency(_ wavelength: Double, speedOfSound: Double = 343.2) -> Double {
        guard wavelength > 0 else { return 0 }
        return speedOfSound / wavelength
    }

    /// Calculate period from frequency
    func frequencyToPeriod(_ frequency: Double) -> Double {
        guard frequency > 0 else { return 0 }
        return 1.0 / frequency
    }

    // MARK: - dB Calculations

    /// Convert linear amplitude to dB
    func linearToDb(_ linear: Double) -> Double {
        guard linear > 0 else { return -Double.infinity }
        return 20.0 * log10(linear)
    }

    /// Convert dB to linear amplitude
    func dbToLinear(_ db: Double) -> Double {
        return pow(10.0, db / 20.0)
    }

    /// Convert power ratio to dB
    func powerToDb(_ power: Double) -> Double {
        guard power > 0 else { return -Double.infinity }
        return 10.0 * log10(power)
    }

    /// Convert dB to power ratio
    func dbToPower(_ db: Double) -> Double {
        return pow(10.0, db / 10.0)
    }

    /// Add dB values (correct way)
    func addDb(_ db1: Double, _ db2: Double) -> Double {
        let linear1 = dbToLinear(db1)
        let linear2 = dbToLinear(db2)
        return linearToDb(linear1 + linear2)
    }

    /// Convert dBFS to dBu (assuming +4 dBu = -18 dBFS)
    func dbfsToDbU(_ dbfs: Double, headroom: Double = 18.0) -> Double {
        return dbfs + headroom + 4.0
    }

    /// Convert dBu to dBFS
    func dbuToDbFS(_ dbu: Double, headroom: Double = 18.0) -> Double {
        return dbu - headroom - 4.0
    }

    /// Calculate SPL from voltage
    func voltageToSPL(_ voltage: Double, sensitivity: Double = 94.0, referenceVoltage: Double = 1.0) -> Double {
        guard voltage > 0 else { return 0 }
        return sensitivity + 20.0 * log10(voltage / referenceVoltage)
    }

    // MARK: - Room Acoustics

    /// Calculate RT60 using Sabine formula
    func calculateRT60Sabine(volume: Double, absorptionArea: Double) -> Double {
        guard absorptionArea > 0 else { return 0 }
        return 0.161 * volume / absorptionArea
    }

    /// Calculate RT60 using Eyring formula
    func calculateRT60Eyring(volume: Double, surfaceArea: Double, averageAbsorption: Double) -> Double {
        guard surfaceArea > 0, averageAbsorption > 0, averageAbsorption < 1 else { return 0 }
        return 0.161 * volume / (-surfaceArea * log(1.0 - averageAbsorption))
    }

    /// Calculate early reflection time
    func calculateEarlyReflection(distance: Double, speedOfSound: Double = 343.2) -> Double {
        return (distance * 2.0) / speedOfSound * 1000.0  // ms
    }

    /// Calculate critical distance
    func calculateCriticalDistance(volume: Double, rt60: Double) -> Double {
        guard rt60 > 0 else { return 0 }
        return 0.057 * sqrt(volume / rt60)
    }

    // MARK: - Speed of Sound

    /// Calculate speed of sound at temperature (Celsius)
    func speedOfSound(temperature: Double) -> Double {
        return 331.3 + 0.606 * temperature
    }

    /// Calculate speed of sound in medium
    func speedOfSoundInMedium(bulkModulus: Double, density: Double) -> Double {
        guard density > 0 else { return 0 }
        return sqrt(bulkModulus / density)
    }

    // MARK: - Sample Rate Conversions

    /// Convert milliseconds to samples
    func msToSamples(ms: Double, sampleRate: Double = 48000) -> Double {
        return ms * sampleRate / 1000.0
    }

    /// Convert samples to milliseconds
    func samplesToMs(samples: Double, sampleRate: Double = 48000) -> Double {
        return samples * 1000.0 / sampleRate
    }

    /// Calculate Nyquist frequency
    func nyquistFrequency(sampleRate: Double) -> Double {
        return sampleRate / 2.0
    }

    /// Calculate samples needed for frequency at sample rate
    func samplesPerCycle(frequency: Double, sampleRate: Double = 48000) -> Double {
        guard frequency > 0 else { return 0 }
        return sampleRate / frequency
    }

    // MARK: - Filter Calculations

    /// Calculate filter cutoff from time constant
    func timeConstantToFrequency(rc: Double) -> Double {
        guard rc > 0 else { return 0 }
        return 1.0 / (2.0 * .pi * rc)
    }

    /// Calculate time constant from cutoff frequency
    func frequencyToTimeConstant(frequency: Double) -> Double {
        guard frequency > 0 else { return 0 }
        return 1.0 / (2.0 * .pi * frequency)
    }

    /// Calculate Q from bandwidth
    func bandwidthToQ(centerFrequency: Double, bandwidth: Double) -> Double {
        guard bandwidth > 0 else { return 0 }
        return centerFrequency / bandwidth
    }

    /// Calculate bandwidth from Q
    func qToBandwidth(centerFrequency: Double, q: Double) -> Double {
        guard q > 0 else { return 0 }
        return centerFrequency / q
    }

    /// Calculate octave bandwidth from Q
    func qToOctaves(q: Double) -> Double {
        guard q > 0 else { return 0 }
        return 2.0 * asinh(1.0 / (2.0 * q)) / log(2.0)
    }

    /// Calculate Q from octave bandwidth
    func octavesToQ(octaves: Double) -> Double {
        guard octaves > 0 else { return 0 }
        return 1.0 / (2.0 * sinh(log(2.0) * octaves / 2.0))
    }

    // MARK: - Musical Intervals

    struct MusicalInterval {
        let name: String
        let semitones: Int
        let ratio: Double
        let cents: Double
    }

    let musicalIntervals: [MusicalInterval] = [
        MusicalInterval(name: "Unison", semitones: 0, ratio: 1.0, cents: 0),
        MusicalInterval(name: "Minor 2nd", semitones: 1, ratio: 16.0/15.0, cents: 100),
        MusicalInterval(name: "Major 2nd", semitones: 2, ratio: 9.0/8.0, cents: 200),
        MusicalInterval(name: "Minor 3rd", semitones: 3, ratio: 6.0/5.0, cents: 300),
        MusicalInterval(name: "Major 3rd", semitones: 4, ratio: 5.0/4.0, cents: 400),
        MusicalInterval(name: "Perfect 4th", semitones: 5, ratio: 4.0/3.0, cents: 500),
        MusicalInterval(name: "Tritone", semitones: 6, ratio: 45.0/32.0, cents: 600),
        MusicalInterval(name: "Perfect 5th", semitones: 7, ratio: 3.0/2.0, cents: 700),
        MusicalInterval(name: "Minor 6th", semitones: 8, ratio: 8.0/5.0, cents: 800),
        MusicalInterval(name: "Major 6th", semitones: 9, ratio: 5.0/3.0, cents: 900),
        MusicalInterval(name: "Minor 7th", semitones: 10, ratio: 9.0/5.0, cents: 1000),
        MusicalInterval(name: "Major 7th", semitones: 11, ratio: 15.0/8.0, cents: 1100),
        MusicalInterval(name: "Octave", semitones: 12, ratio: 2.0, cents: 1200)
    ]

    /// Convert semitones to frequency ratio
    func semitonesToRatio(_ semitones: Double) -> Double {
        return pow(2.0, semitones / 12.0)
    }

    /// Convert frequency ratio to semitones
    func ratioToSemitones(_ ratio: Double) -> Double {
        guard ratio > 0 else { return 0 }
        return 12.0 * log2(ratio)
    }

    /// Convert semitones to cents
    func semitonesToCents(_ semitones: Double) -> Double {
        return semitones * 100.0
    }

    /// Convert cents to semitones
    func centsToSemitones(_ cents: Double) -> Double {
        return cents / 100.0
    }

    /// Convert cents to frequency ratio
    func centsToRatio(_ cents: Double) -> Double {
        return pow(2.0, cents / 1200.0)
    }

    /// Convert frequency ratio to cents
    func ratioToCents(_ ratio: Double) -> Double {
        guard ratio > 0 else { return 0 }
        return 1200.0 * log2(ratio)
    }

    // MARK: - Psychoacoustic Calculations

    /// Calculate loudness in phons from dB SPL (simplified)
    func splToPhons(spl: Double, frequency: Double) -> Double {
        // Simplified equal-loudness contour approximation
        // Full implementation would use ISO 226
        let frequencyCorrection: Double
        if frequency < 1000 {
            frequencyCorrection = -10.0 * log10(frequency / 1000.0)
        } else if frequency > 4000 {
            frequencyCorrection = -5.0 * log10(frequency / 1000.0)
        } else {
            frequencyCorrection = 0
        }
        return spl + frequencyCorrection
    }

    /// Calculate bark scale from frequency
    func frequencyToBark(_ frequency: Double) -> Double {
        return 13.0 * atan(0.00076 * frequency) + 3.5 * atan(pow(frequency / 7500.0, 2))
    }

    /// Calculate ERB (Equivalent Rectangular Bandwidth)
    func calculateERB(_ frequency: Double) -> Double {
        return 24.7 * (4.37 * frequency / 1000.0 + 1.0)
    }

    /// Calculate critical bandwidth
    func criticalBandwidth(_ frequency: Double) -> Double {
        return 25.0 + 75.0 * pow(1.0 + 1.4 * pow(frequency / 1000.0, 2), 0.69)
    }

    // MARK: - Convenience Report

    func generateFullReport(bpm: Double, frequency: Double, sampleRate: Double = 48000) -> AudioReport {
        let delayTimes = calculateDelayTimes(bpm: bpm, sampleRate: sampleRate)
        let midiNote = frequencyToMIDI(frequency)
        let noteName = frequencyToNoteName(frequency)
        let wavelength = frequencyToWavelength(frequency)
        let period = frequencyToPeriod(frequency)

        return AudioReport(
            bpm: bpm,
            msPerBeat: bpmToMs(bpm: bpm),
            frequency: frequency,
            midiNote: midiNote,
            noteName: noteName,
            wavelength: wavelength,
            period: period,
            samplesPerCycle: samplesPerCycle(frequency: frequency, sampleRate: sampleRate),
            delayTimes: delayTimes,
            bark: frequencyToBark(frequency),
            erb: calculateERB(frequency),
            criticalBandwidth: criticalBandwidth(frequency)
        )
    }

    struct AudioReport {
        let bpm: Double
        let msPerBeat: Double
        let frequency: Double
        let midiNote: Double
        let noteName: String
        let wavelength: Double
        let period: Double
        let samplesPerCycle: Double
        let delayTimes: [DelayTime]
        let bark: Double
        let erb: Double
        let criticalBandwidth: Double
    }

    // MARK: - Initialization

    private init() {
        print("🧮 EchoelCalculator initialized")
        print("   Audio toolkit ready (Sengpiel-style + more)")
    }
}

// MARK: - Calculator View

struct EchoelCalculatorView: View {
    @StateObject private var calculator = EchoelCalculator.shared
    @State private var bpm: Double = 120
    @State private var frequency: Double = 440
    @State private var midiNote: Double = 69
    @State private var sampleRate: Double = 48000

    var body: some View {
        NavigationStack {
            Form {
                // BPM Section
                Section("BPM / Tempo") {
                    HStack {
                        Text("BPM")
                        Slider(value: $bpm, in: 20...300)
                        Text("\(Int(bpm))")
                    }

                    LabeledContent("ms per beat", value: String(format: "%.2f ms", calculator.bpmToMs(bpm: bpm)))
                    LabeledContent("Hz", value: String(format: "%.4f Hz", calculator.bpmToHz(bpm: bpm)))
                    LabeledContent("Samples/beat", value: "\(Int(calculator.bpmToSamples(bpm: bpm, sampleRate: sampleRate)))")
                }

                // Delay Times
                Section("Delay Times @ \(Int(bpm)) BPM") {
                    let delayTimes = calculator.calculateDelayTimes(bpm: bpm, sampleRate: sampleRate)
                    ForEach(delayTimes.prefix(8), id: \.noteValue) { delay in
                        HStack {
                            Text(delay.noteValue.rawValue)
                                .frame(width: 50, alignment: .leading)
                            Spacer()
                            Text(String(format: "%.2f ms", delay.ms))
                            Spacer()
                            Text("\(delay.samples) smp")
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }

                // Frequency Section
                Section("Frequency / Pitch") {
                    HStack {
                        Text("Hz")
                        Slider(value: $frequency, in: 20...20000)
                        Text(String(format: "%.1f", frequency))
                    }

                    LabeledContent("MIDI Note", value: String(format: "%.2f", calculator.frequencyToMIDI(frequency)))
                    LabeledContent("Note Name", value: calculator.frequencyToNoteName(frequency))
                    LabeledContent("Wavelength", value: String(format: "%.3f m", calculator.frequencyToWavelength(frequency)))
                    LabeledContent("Period", value: String(format: "%.6f s", calculator.frequencyToPeriod(frequency)))
                }

                // MIDI to Frequency
                Section("MIDI Note") {
                    HStack {
                        Text("MIDI")
                        Slider(value: $midiNote, in: 0...127)
                        Text("\(Int(midiNote))")
                    }

                    LabeledContent("Frequency", value: String(format: "%.2f Hz", calculator.midiToFrequency(midiNote)))
                    LabeledContent("Note Name", value: calculator.midiNoteToName(Int(midiNote)))
                }

                // Psychoacoustics
                Section("Psychoacoustics @ \(Int(frequency)) Hz") {
                    LabeledContent("Bark Scale", value: String(format: "%.2f Bark", calculator.frequencyToBark(frequency)))
                    LabeledContent("ERB", value: String(format: "%.2f Hz", calculator.calculateERB(frequency)))
                    LabeledContent("Critical Bandwidth", value: String(format: "%.2f Hz", calculator.criticalBandwidth(frequency)))
                }

                // Sample Rate
                Section("Sample Rate") {
                    Picker("Sample Rate", selection: $sampleRate) {
                        Text("44.1 kHz").tag(44100.0)
                        Text("48 kHz").tag(48000.0)
                        Text("96 kHz").tag(96000.0)
                        Text("192 kHz").tag(192000.0)
                    }

                    LabeledContent("Nyquist", value: String(format: "%.0f Hz", calculator.nyquistFrequency(sampleRate: sampleRate)))
                    LabeledContent("Samples/cycle", value: String(format: "%.2f", calculator.samplesPerCycle(frequency: frequency, sampleRate: sampleRate)))
                }
            }
            .navigationTitle("EchoelCalculator")
        }
    }
}

// MARK: - Debug

#if DEBUG
extension EchoelCalculator {
    func testCalculator() {
        print("🧪 Testing EchoelCalculator...")

        // BPM tests
        print("\n📊 BPM Calculations:")
        print("  120 BPM → \(bpmToMs(bpm: 120)) ms")
        print("  500 ms → \(msToBpm(ms: 500)) BPM")

        // Frequency tests
        print("\n🎵 Frequency Calculations:")
        print("  440 Hz → MIDI \(frequencyToMIDI(440))")
        print("  MIDI 60 → \(midiToFrequency(60)) Hz")
        print("  440 Hz → \(frequencyToNoteName(440))")
        print("  440 Hz wavelength → \(frequencyToWavelength(440)) m")

        // Delay times
        print("\n⏱️ Delay Times @ 120 BPM:")
        for delay in calculateDelayTimes(bpm: 120).prefix(5) {
            print("  \(delay.noteValue.rawValue): \(String(format: "%.2f", delay.ms)) ms")
        }

        // dB calculations
        print("\n📢 dB Calculations:")
        print("  0.5 linear → \(linearToDb(0.5)) dB")
        print("  -6 dB → \(dbToLinear(-6)) linear")

        // Intervals
        print("\n🎹 Musical Intervals:")
        print("  7 semitones ratio → \(semitonesToRatio(7))")
        print("  1.5 ratio → \(ratioToSemitones(1.5)) semitones")

        print("\n✅ EchoelCalculator test complete")
    }
}
#endif
