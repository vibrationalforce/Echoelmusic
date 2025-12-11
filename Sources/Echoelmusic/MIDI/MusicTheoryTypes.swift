// MusicTheoryTypes.swift
// Echoelmusic - Music Theory Data Types
// SPDX-License-Identifier: MIT
//
// Extracted from TouchInstruments.swift for reusability

import Foundation

// MARK: - Musical Scale

/// Musical scale definitions with intervals
public enum MusicalScale: String, CaseIterable, Sendable {
    case major = "Major"
    case minor = "Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case chromatic = "Chromatic"
    case wholeNote = "Whole Tone"

    /// Semitone intervals from root
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .wholeNote: return [0, 2, 4, 6, 8, 10]
        }
    }

    /// Number of notes in scale
    public var noteCount: Int { intervals.count }

    /// Calculate MIDI note for scale degree
    public func noteInScale(degree: Int, root: UInt8) -> UInt8 {
        let octaveOffset = degree / intervals.count
        let scaleIndex = ((degree % intervals.count) + intervals.count) % intervals.count
        let note = Int(root) + (octaveOffset * 12) + intervals[scaleIndex]
        return UInt8(max(0, min(127, note)))
    }

    /// Get all notes in scale for given root and octave range
    public func allNotes(root: UInt8, octaves: Int = 1) -> [UInt8] {
        var notes: [UInt8] = []
        for octave in 0..<octaves {
            for interval in intervals {
                let note = Int(root) + (octave * 12) + interval
                if note >= 0 && note <= 127 {
                    notes.append(UInt8(note))
                }
            }
        }
        return notes
    }

    /// Check if note belongs to scale
    public func contains(note: UInt8, root: UInt8) -> Bool {
        let interval = (Int(note) - Int(root) + 1200) % 12
        return intervals.contains(interval)
    }

    /// Quantize note to nearest scale tone
    public func quantize(note: UInt8, root: UInt8) -> UInt8 {
        let octave = Int(note) / 12
        let pitchClass = Int(note) % 12
        let rootPitchClass = Int(root) % 12

        // Find nearest scale tone
        var minDistance = 12
        var nearestInterval = 0

        for interval in intervals {
            let scalePitchClass = (rootPitchClass + interval) % 12
            let distance = min(
                abs(pitchClass - scalePitchClass),
                12 - abs(pitchClass - scalePitchClass)
            )
            if distance < minDistance {
                minDistance = distance
                nearestInterval = interval
            }
        }

        let quantizedNote = (octave * 12) + ((rootPitchClass + nearestInterval) % 12)
        return UInt8(max(0, min(127, quantizedNote)))
    }
}

// MARK: - Chord Type

/// Chord type definitions with intervals
public enum ChordType: String, CaseIterable, Sendable {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Dim"
    case augmented = "Aug"
    case major7 = "Maj7"
    case minor7 = "Min7"
    case dominant7 = "7"
    case sus2 = "Sus2"
    case sus4 = "Sus4"
    case add9 = "Add9"
    case power = "5"
    case minor9 = "Min9"
    case major9 = "Maj9"
    case dominant9 = "9"
    case diminished7 = "Dim7"
    case halfDiminished = "ø7"

    /// Semitone intervals from root
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .dominant7: return [0, 4, 7, 10]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .add9: return [0, 4, 7, 14]
        case .power: return [0, 7]
        case .minor9: return [0, 3, 7, 10, 14]
        case .major9: return [0, 4, 7, 11, 14]
        case .dominant9: return [0, 4, 7, 10, 14]
        case .diminished7: return [0, 3, 6, 9]
        case .halfDiminished: return [0, 3, 6, 10]
        }
    }

    /// Calculate chord notes from root
    public func notes(root: UInt8) -> [UInt8] {
        intervals.compactMap { interval in
            let note = Int(root) + interval
            return note <= 127 ? UInt8(note) : nil
        }
    }

    /// Get chord with specific inversion
    public func notes(root: UInt8, inversion: Int) -> [UInt8] {
        var chordNotes = notes(root: root)
        guard inversion > 0 && inversion < chordNotes.count else {
            return chordNotes
        }

        // Move bottom notes up an octave
        for i in 0..<inversion {
            if chordNotes[i] + 12 <= 127 {
                chordNotes[i] += 12
            }
        }
        return chordNotes.sorted()
    }

    /// Symbol representation
    public var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "°"
        case .augmented: return "+"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .dominant7: return "7"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .add9: return "add9"
        case .power: return "5"
        case .minor9: return "m9"
        case .major9: return "maj9"
        case .dominant9: return "9"
        case .diminished7: return "°7"
        case .halfDiminished: return "ø7"
        }
    }
}

// MARK: - Note Names

/// MIDI note name utilities
public enum NoteUtility {
    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    /// Get note name from MIDI number (sharps)
    public static func name(for midiNote: UInt8, useFlats: Bool = false) -> String {
        let names = useFlats ? flatNames : noteNames
        return names[Int(midiNote) % 12]
    }

    /// Get full note name with octave
    public static func fullName(for midiNote: UInt8, useFlats: Bool = false) -> String {
        let noteName = name(for: midiNote, useFlats: useFlats)
        let octave = Int(midiNote) / 12 - 1
        return "\(noteName)\(octave)"
    }

    /// Get MIDI note from name
    public static func midiNote(name: String, octave: Int) -> UInt8? {
        let upperName = name.uppercased()
        if let index = noteNames.firstIndex(of: upperName) {
            let note = (octave + 1) * 12 + index
            return note >= 0 && note <= 127 ? UInt8(note) : nil
        }
        if let index = flatNames.firstIndex(of: upperName) {
            let note = (octave + 1) * 12 + index
            return note >= 0 && note <= 127 ? UInt8(note) : nil
        }
        return nil
    }

    /// Get chord name from root and type
    public static func chordName(root: UInt8, type: ChordType, useFlats: Bool = false) -> String {
        "\(name(for: root, useFlats: useFlats))\(type.symbol)"
    }

    /// Frequency for MIDI note (A4 = 440Hz)
    public static func frequency(for midiNote: UInt8, a4: Double = 440.0) -> Double {
        a4 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
    }

    /// MIDI note for frequency
    public static func midiNote(for frequency: Double, a4: Double = 440.0) -> UInt8 {
        let note = 69.0 + 12.0 * log2(frequency / a4)
        return UInt8(max(0, min(127, Int(round(note)))))
    }
}

// MARK: - Key Signature

/// Musical key signature
public struct KeySignature: Equatable, Sendable {
    public let root: UInt8
    public let scale: MusicalScale

    public init(root: UInt8, scale: MusicalScale = .major) {
        self.root = root % 12  // Normalize to pitch class
        self.scale = scale
    }

    /// Common key signatures
    public static let cMajor = KeySignature(root: 0, scale: .major)
    public static let gMajor = KeySignature(root: 7, scale: .major)
    public static let dMajor = KeySignature(root: 2, scale: .major)
    public static let aMinor = KeySignature(root: 9, scale: .minor)
    public static let eMinor = KeySignature(root: 4, scale: .minor)

    /// Display name
    public var displayName: String {
        let rootName = NoteUtility.name(for: root)
        return "\(rootName) \(scale.rawValue)"
    }

    /// Relative major/minor
    public var relative: KeySignature {
        if scale == .major {
            return KeySignature(root: (root + 9) % 12, scale: .minor)
        } else {
            return KeySignature(root: (root + 3) % 12, scale: .major)
        }
    }

    /// Parallel major/minor
    public var parallel: KeySignature {
        KeySignature(root: root, scale: scale == .major ? .minor : .major)
    }
}

// MARK: - Time Signature

/// Musical time signature
public struct TimeSignature: Equatable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Common time signatures
    public static let common = TimeSignature(numerator: 4, denominator: 4)
    public static let waltz = TimeSignature(numerator: 3, denominator: 4)
    public static let cut = TimeSignature(numerator: 2, denominator: 2)
    public static let sixEight = TimeSignature(numerator: 6, denominator: 8)

    /// Beats per bar
    public var beatsPerBar: Int { numerator }

    /// Beat duration in quarter notes
    public var beatDuration: Double { 4.0 / Double(denominator) }

    /// Display string
    public var displayString: String { "\(numerator)/\(denominator)" }
}
