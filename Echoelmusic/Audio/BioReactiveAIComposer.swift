//
//  BioReactiveAIComposer.swift
//  Echoelmusic
//
//  Created: December 2025
//  WORLD'S FIRST Bio-Reactive AI Music Generation System
//  Generates music in real-time based on HRV, Coherence, and Biometric Data
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Bio-Musical Mapping

/// Maps biometric states to musical parameters
enum BioMusicalState: String, CaseIterable {
    case deepCalm       // Very high coherence (>0.85), low HR
    case flowState      // High coherence (0.7-0.85), optimal HRV
    case creative       // Medium coherence, high HRV variability
    case energized      // Lower coherence, elevated HR
    case stressed       // Low coherence (<0.4), irregular HRV
    case meditative     // Very high coherence, very low HR

    var musicalCharacteristics: MusicalCharacteristics {
        switch self {
        case .deepCalm:
            return MusicalCharacteristics(
                tempo: 60...72,
                keyMode: .major,
                harmonyComplexity: 0.3,
                rhythmDensity: 0.2,
                dynamicRange: 0.3,
                dissonance: 0.1,
                preferredScales: [.major, .pentatonicMajor, .lydian],
                melodicDirection: .descending,
                noteSpacing: .sparse
            )

        case .flowState:
            return MusicalCharacteristics(
                tempo: 90...120,
                keyMode: .major,
                harmonyComplexity: 0.6,
                rhythmDensity: 0.5,
                dynamicRange: 0.5,
                dissonance: 0.2,
                preferredScales: [.major, .mixolydian, .dorian],
                melodicDirection: .balanced,
                noteSpacing: .medium
            )

        case .creative:
            return MusicalCharacteristics(
                tempo: 100...140,
                keyMode: .mixed,
                harmonyComplexity: 0.8,
                rhythmDensity: 0.6,
                dynamicRange: 0.7,
                dissonance: 0.4,
                preferredScales: [.dorian, .lydian, .melodicMinor],
                melodicDirection: .dynamic,
                noteSpacing: .varied
            )

        case .energized:
            return MusicalCharacteristics(
                tempo: 120...160,
                keyMode: .major,
                harmonyComplexity: 0.5,
                rhythmDensity: 0.8,
                dynamicRange: 0.8,
                dissonance: 0.3,
                preferredScales: [.major, .pentatonicMajor, .mixolydian],
                melodicDirection: .ascending,
                noteSpacing: .dense
            )

        case .stressed:
            return MusicalCharacteristics(
                tempo: 65...80,          // Slower to calm
                keyMode: .major,         // Major to uplift
                harmonyComplexity: 0.2,  // Simple for clarity
                rhythmDensity: 0.3,      // Less busy
                dynamicRange: 0.3,       // Gentle
                dissonance: 0.05,        // Consonant
                preferredScales: [.pentatonicMajor, .major],
                melodicDirection: .descending,
                noteSpacing: .sparse     // Breathing room
            )

        case .meditative:
            return MusicalCharacteristics(
                tempo: 50...65,
                keyMode: .modal,
                harmonyComplexity: 0.4,
                rhythmDensity: 0.1,
                dynamicRange: 0.2,
                dissonance: 0.15,
                preferredScales: [.pentatonicMajor, .wholeTone, .lydian],
                melodicDirection: .static,
                noteSpacing: .verySparse
            )
        }
    }
}

struct MusicalCharacteristics {
    let tempo: ClosedRange<Int>
    let keyMode: KeyMode
    let harmonyComplexity: Float       // 0-1
    let rhythmDensity: Float           // 0-1
    let dynamicRange: Float            // 0-1
    let dissonance: Float              // 0-1
    let preferredScales: [BioScale]
    let melodicDirection: MelodicDirection
    let noteSpacing: NoteSpacing

    enum KeyMode { case major, minor, modal, mixed }
    enum MelodicDirection { case ascending, descending, balanced, dynamic, `static` }
    enum NoteSpacing { case verySparse, sparse, medium, dense, varied }
}

// MARK: - Bio Scales

enum BioScale: String, CaseIterable {
    case major = "Major"
    case minor = "Natural Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case wholeTone = "Whole Tone"

    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        }
    }

    func noteInScale(degree: Int, root: Int) -> Int {
        let octave = degree / intervals.count
        let degreeInOctave = degree % intervals.count
        return root + intervals[degreeInOctave] + (octave * 12)
    }
}

// MARK: - Generated Music Elements

struct GeneratedNote: Identifiable {
    let id = UUID()
    var pitch: Int                    // MIDI note number
    var velocity: Int                 // 0-127
    var startBeat: Double
    var duration: Double
    var expression: NoteExpression

    struct NoteExpression {
        var pitchBend: Float = 0      // -1 to 1
        var pressure: Float = 0.5
        var brightness: Float = 0.5   // CC74
        var timbre: Float = 0.5       // CC71
    }
}

struct GeneratedChord: Identifiable {
    let id = UUID()
    var root: Int                     // Root note MIDI
    var quality: ChordQuality
    var notes: [Int]                  // All chord tones
    var startBeat: Double
    var duration: Double
    var voicing: ChordVoicing

    enum ChordQuality: String, CaseIterable {
        case major, minor, diminished, augmented
        case major7, minor7, dominant7
        case add9, sus2, sus4
        case minor9, major9
    }

    enum ChordVoicing { case close, open, spread, drop2, drop3 }
}

struct GeneratedDrumPattern: Identifiable {
    let id = UUID()
    var kicks: [DrumHit] = []
    var snares: [DrumHit] = []
    var hiHats: [DrumHit] = []
    var toms: [DrumHit] = []
    var cymbals: [DrumHit] = []
    var percussion: [DrumHit] = []
    var lengthInBeats: Double = 4

    struct DrumHit {
        var beat: Double
        var velocity: Int
        var variation: Int = 0
    }
}

struct GeneratedPhrase {
    var notes: [GeneratedNote]
    var chords: [GeneratedChord]
    var drums: GeneratedDrumPattern
    var tempo: Double
    var scale: BioScale
    var rootNote: Int
}

// MARK: - AI Generation Parameters

struct AIGenerationConfig {
    var creativity: Float = 0.5        // 0 = predictable, 1 = experimental
    var energy: Float = 0.5            // 0 = calm, 1 = intense
    var complexity: Float = 0.5        // 0 = simple, 1 = complex
    var humanization: Float = 0.3      // Timing/velocity variation
    var bioReactivity: Float = 1.0     // How much bio data influences output

    // Generation modes
    var generateMelody: Bool = true
    var generateChords: Bool = true
    var generateDrums: Bool = true
    var generateBass: Bool = true

    // Style hints
    var genreHint: GenreHint = .ambient
    var instrumentHint: InstrumentHint = .piano

    enum GenreHint: String, CaseIterable {
        case ambient, electronic, acoustic, jazz, classical, lofi, cinematic
    }

    enum InstrumentHint: String, CaseIterable {
        case piano, synth, strings, guitar, bells, pads
    }
}

// MARK: - Biometric Input

struct BiometricInput {
    var heartRate: Double = 72
    var hrvSDNN: Double = 50           // HRV Standard Deviation
    var hrvRMSSD: Double = 40          // HRV Root Mean Square
    var coherenceScore: Double = 0.5   // 0-1 coherence
    var respirationRate: Double = 12   // Breaths per minute
    var skinConductance: Double = 0    // GSR if available
    var brainwaveState: BrainwaveState = .alpha

    enum BrainwaveState: String {
        case delta, theta, alpha, beta, gamma
    }

    var bioMusicalState: BioMusicalState {
        // Determine state based on biometrics
        if coherenceScore > 0.85 && heartRate < 60 {
            return .meditative
        } else if coherenceScore > 0.85 {
            return .deepCalm
        } else if coherenceScore > 0.7 && hrvSDNN > 45 {
            return .flowState
        } else if hrvSDNN > 55 && coherenceScore > 0.5 {
            return .creative
        } else if coherenceScore < 0.4 || hrvRMSSD < 20 {
            return .stressed
        } else if heartRate > 85 {
            return .energized
        } else {
            return .flowState
        }
    }
}

// MARK: - Markov Chain Melody Generator

class MarkovMelodyGenerator {
    private var transitionMatrix: [[Float]] = []
    private var scaleNotes: [Int] = []
    private let matrixSize = 12  // Chromatic

    init() {
        // Initialize with musical preferences
        initializeTransitionMatrix()
    }

    private func initializeTransitionMatrix() {
        // Probabilities for melodic intervals
        // Row = current note (relative to scale), Col = next note
        transitionMatrix = Array(repeating: Array(repeating: 0.0, count: matrixSize), count: matrixSize)

        // Musical interval preferences
        let intervalWeights: [Int: Float] = [
            0: 0.15,   // Unison (repeat)
            1: 0.20,   // Minor 2nd
            2: 0.25,   // Major 2nd (most common)
            3: 0.15,   // Minor 3rd
            4: 0.10,   // Major 3rd
            5: 0.05,   // Perfect 4th
            7: 0.05,   // Perfect 5th
            -1: 0.15,  // Down minor 2nd
            -2: 0.20   // Down major 2nd
        ]

        for row in 0..<matrixSize {
            var rowTotal: Float = 0
            for col in 0..<matrixSize {
                let interval = (col - row + 12) % 12
                let negInterval = -(12 - interval)
                let weight = intervalWeights[interval] ?? intervalWeights[negInterval] ?? 0.02
                transitionMatrix[row][col] = weight
                rowTotal += weight
            }
            // Normalize
            for col in 0..<matrixSize {
                transitionMatrix[row][col] /= rowTotal
            }
        }
    }

    func generateMelody(
        scale: BioScale,
        rootNote: Int,
        lengthBeats: Double,
        characteristics: MusicalCharacteristics,
        config: AIGenerationConfig
    ) -> [GeneratedNote] {

        var notes: [GeneratedNote] = []
        var currentBeat: Double = 0
        var currentDegree = 0  // Start on root
        let scaleSize = scale.intervals.count

        // Determine note density based on characteristics
        let avgNoteDuration = getNoteDuration(spacing: characteristics.noteSpacing)
        let totalNotes = Int(lengthBeats / avgNoteDuration)

        for _ in 0..<totalNotes {
            guard currentBeat < lengthBeats else { break }

            // Get next scale degree using Markov chain
            let chromatic = scale.intervals[currentDegree % scaleSize] % 12
            let nextChromatic = sampleNextNote(currentChromatic: chromatic, creativity: config.creativity)

            // Find closest scale degree
            currentDegree = findClosestScaleDegree(targetChromatic: nextChromatic, scale: scale, currentDegree: currentDegree)

            // Calculate actual pitch
            let octaveShift = (currentDegree / scaleSize) - 1
            let pitch = rootNote + scale.intervals[currentDegree % scaleSize] + (octaveShift * 12)

            // Constrain to reasonable range
            let constrainedPitch = max(36, min(96, pitch))

            // Determine duration with variation
            var duration = avgNoteDuration
            if characteristics.noteSpacing == .varied {
                let variations: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]
                duration = variations.randomElement()! * avgNoteDuration
            }

            // Humanization
            let humanOffset = Double.random(in: -0.02...0.02) * Double(config.humanization)
            let humanVelocity = Int.random(in: -10...10) * Int(config.humanization * 30)

            // Velocity based on characteristics
            let baseVelocity = Int(70 + characteristics.dynamicRange * 40)
            let velocity = max(30, min(127, baseVelocity + humanVelocity))

            // Expression based on bio state
            let expression = GeneratedNote.NoteExpression(
                pitchBend: Float.random(in: -0.1...0.1) * config.humanization,
                pressure: 0.5 + Float.random(in: -0.2...0.2) * characteristics.dynamicRange,
                brightness: 0.3 + characteristics.harmonyComplexity * 0.5,
                timbre: 0.5
            )

            let note = GeneratedNote(
                pitch: constrainedPitch,
                velocity: velocity,
                startBeat: max(0, currentBeat + humanOffset),
                duration: duration * 0.9,  // Slight gap between notes
                expression: expression
            )

            notes.append(note)
            currentBeat += duration
        }

        // Apply melodic direction preference
        notes = applyMelodicDirection(notes: notes, direction: characteristics.melodicDirection)

        return notes
    }

    private func sampleNextNote(currentChromatic: Int, creativity: Float) -> Int {
        let row = currentChromatic % matrixSize
        var probabilities = transitionMatrix[row]

        // Add randomness based on creativity
        if creativity > 0.5 {
            for i in 0..<probabilities.count {
                probabilities[i] = probabilities[i] * (1 - creativity) + Float.random(in: 0...1) * creativity * 0.3
            }
        }

        // Sample from distribution
        let total = probabilities.reduce(0, +)
        var sample = Float.random(in: 0..<total)

        for (i, prob) in probabilities.enumerated() {
            sample -= prob
            if sample <= 0 {
                return i
            }
        }

        return (currentChromatic + 2) % 12  // Default: step up
    }

    private func findClosestScaleDegree(targetChromatic: Int, scale: BioScale, currentDegree: Int) -> Int {
        var closestDegree = currentDegree
        var minDistance = Int.max

        let searchRange = max(0, currentDegree - 3)...(currentDegree + 3)

        for degree in searchRange {
            let noteChromatic = scale.intervals[degree % scale.intervals.count] % 12
            let distance = abs(noteChromatic - targetChromatic)
            if distance < minDistance {
                minDistance = distance
                closestDegree = degree
            }
        }

        return closestDegree
    }

    private func getNoteDuration(spacing: MusicalCharacteristics.NoteSpacing) -> Double {
        switch spacing {
        case .verySparse: return 2.0
        case .sparse: return 1.0
        case .medium: return 0.5
        case .dense: return 0.25
        case .varied: return 0.5
        }
    }

    private func applyMelodicDirection(notes: [GeneratedNote], direction: MusicalCharacteristics.MelodicDirection) -> [GeneratedNote] {
        guard notes.count > 1 else { return notes }

        var modified = notes

        switch direction {
        case .ascending:
            // Sort by time, then ensure general upward trend
            for i in 1..<modified.count {
                if modified[i].pitch < modified[i-1].pitch - 5 {
                    modified[i].pitch = modified[i-1].pitch + Int.random(in: 0...2)
                }
            }
        case .descending:
            for i in 1..<modified.count {
                if modified[i].pitch > modified[i-1].pitch + 5 {
                    modified[i].pitch = modified[i-1].pitch - Int.random(in: 0...2)
                }
            }
        case .balanced, .dynamic, .static:
            break  // Keep as generated
        }

        return modified
    }
}

// MARK: - Chord Progression Generator

class ChordProgressionGenerator {

    private let commonProgressions: [[Int]] = [
        [1, 5, 6, 4],      // I-V-vi-IV (Pop)
        [1, 4, 5, 1],      // I-IV-V-I (Blues/Rock)
        [2, 5, 1, 1],      // ii-V-I (Jazz)
        [1, 6, 4, 5],      // I-vi-IV-V (50s)
        [6, 4, 1, 5],      // vi-IV-I-V (Modern)
        [1, 4, 6, 5],      // I-IV-vi-V
        [1, 5, 4, 4],      // I-V-IV-IV
        [4, 5, 3, 6],      // IV-V-iii-vi
    ]

    func generateProgression(
        scale: BioScale,
        rootNote: Int,
        lengthBeats: Double,
        characteristics: MusicalCharacteristics,
        config: AIGenerationConfig
    ) -> [GeneratedChord] {

        var chords: [GeneratedChord] = []

        // Select progression based on complexity
        let progressionIndex: Int
        if config.complexity < 0.3 {
            progressionIndex = Int.random(in: 0...2)  // Simple progressions
        } else if config.complexity < 0.7 {
            progressionIndex = Int.random(in: 0...5)
        } else {
            progressionIndex = Int.random(in: 0..<commonProgressions.count)
        }

        let progression = commonProgressions[progressionIndex]
        let beatsPerChord = lengthBeats / Double(progression.count)

        for (index, degree) in progression.enumerated() {
            let chordRoot = scale.noteInScale(degree: degree - 1, root: rootNote)

            // Determine chord quality based on scale and degree
            let quality = determineChordQuality(
                degree: degree,
                scale: scale,
                complexity: characteristics.harmonyComplexity
            )

            // Build chord notes
            let chordNotes = buildChordNotes(
                root: chordRoot,
                quality: quality,
                voicing: config.complexity > 0.5 ? .open : .close
            )

            let chord = GeneratedChord(
                root: chordRoot,
                quality: quality,
                notes: chordNotes,
                startBeat: Double(index) * beatsPerChord,
                duration: beatsPerChord * 0.95,
                voicing: config.complexity > 0.5 ? .open : .close
            )

            chords.append(chord)
        }

        return chords
    }

    private func determineChordQuality(
        degree: Int,
        scale: BioScale,
        complexity: Float
    ) -> GeneratedChord.ChordQuality {

        // Natural chord qualities for major scale degrees
        let naturalQualities: [Int: GeneratedChord.ChordQuality] = [
            1: .major, 2: .minor, 3: .minor,
            4: .major, 5: .major, 6: .minor, 7: .diminished
        ]

        var quality = naturalQualities[degree] ?? .major

        // Add extensions based on complexity
        if complexity > 0.6 {
            switch quality {
            case .major: quality = Float.random(in: 0...1) > 0.5 ? .major7 : .add9
            case .minor: quality = .minor7
            default: break
            }
        }

        return quality
    }

    private func buildChordNotes(
        root: Int,
        quality: GeneratedChord.ChordQuality,
        voicing: GeneratedChord.ChordVoicing
    ) -> [Int] {

        var intervals: [Int]

        switch quality {
        case .major: intervals = [0, 4, 7]
        case .minor: intervals = [0, 3, 7]
        case .diminished: intervals = [0, 3, 6]
        case .augmented: intervals = [0, 4, 8]
        case .major7: intervals = [0, 4, 7, 11]
        case .minor7: intervals = [0, 3, 7, 10]
        case .dominant7: intervals = [0, 4, 7, 10]
        case .add9: intervals = [0, 4, 7, 14]
        case .sus2: intervals = [0, 2, 7]
        case .sus4: intervals = [0, 5, 7]
        case .minor9: intervals = [0, 3, 7, 10, 14]
        case .major9: intervals = [0, 4, 7, 11, 14]
        }

        var notes = intervals.map { root + $0 }

        // Apply voicing
        switch voicing {
        case .open:
            // Spread notes across octaves
            if notes.count >= 3 {
                notes[1] += 12
            }
        case .drop2:
            if notes.count >= 4 {
                notes[1] -= 12
            }
        case .spread:
            for i in 1..<notes.count {
                notes[i] += (i * 5)  // Spread more
            }
        default:
            break
        }

        return notes
    }
}

// MARK: - Drum Pattern Generator

class DrumPatternGenerator {

    func generatePattern(
        lengthBeats: Double,
        characteristics: MusicalCharacteristics,
        config: AIGenerationConfig
    ) -> GeneratedDrumPattern {

        var pattern = GeneratedDrumPattern(lengthInBeats: lengthBeats)

        let density = characteristics.rhythmDensity

        // Kicks - on downbeats, more on higher density
        pattern.kicks = generateKicks(length: lengthBeats, density: density, config: config)

        // Snares - typically beats 2 and 4
        pattern.snares = generateSnares(length: lengthBeats, density: density, config: config)

        // Hi-hats - 8th or 16th notes based on density
        pattern.hiHats = generateHiHats(length: lengthBeats, density: density, config: config)

        // Add fills based on complexity
        if config.complexity > 0.5 {
            pattern.toms = generateTomFills(length: lengthBeats, config: config)
        }

        return pattern
    }

    private func generateKicks(
        length: Double,
        density: Float,
        config: AIGenerationConfig
    ) -> [GeneratedDrumPattern.DrumHit] {

        var kicks: [GeneratedDrumPattern.DrumHit] = []
        let beatsPerMeasure = 4.0

        for beat in stride(from: 0, to: length, by: 1) {
            let positionInMeasure = beat.truncatingRemainder(dividingBy: beatsPerMeasure)

            // Always kick on beat 1
            if positionInMeasure == 0 {
                kicks.append(GeneratedDrumPattern.DrumHit(
                    beat: beat + humanize(config),
                    velocity: 100 + Int.random(in: -10...10)
                ))
            }

            // Kick on beat 3 for higher density
            if positionInMeasure == 2 && density > 0.3 {
                kicks.append(GeneratedDrumPattern.DrumHit(
                    beat: beat + humanize(config),
                    velocity: 90 + Int.random(in: -10...10)
                ))
            }

            // Syncopated kicks for high density
            if density > 0.6 && Float.random(in: 0...1) < density * 0.3 {
                kicks.append(GeneratedDrumPattern.DrumHit(
                    beat: beat + 0.5 + humanize(config),
                    velocity: 80 + Int.random(in: -10...10)
                ))
            }
        }

        return kicks
    }

    private func generateSnares(
        length: Double,
        density: Float,
        config: AIGenerationConfig
    ) -> [GeneratedDrumPattern.DrumHit] {

        var snares: [GeneratedDrumPattern.DrumHit] = []

        for beat in stride(from: 1, to: length, by: 2) {
            // Snare on 2 and 4
            snares.append(GeneratedDrumPattern.DrumHit(
                beat: beat + humanize(config),
                velocity: 100 + Int.random(in: -10...10)
            ))

            // Ghost notes for higher density
            if density > 0.5 && Float.random(in: 0...1) < density * 0.4 {
                let ghostBeat = beat - 0.5
                if ghostBeat >= 0 {
                    snares.append(GeneratedDrumPattern.DrumHit(
                        beat: ghostBeat + humanize(config),
                        velocity: 50 + Int.random(in: -10...10),
                        variation: 1  // Ghost note
                    ))
                }
            }
        }

        return snares
    }

    private func generateHiHats(
        length: Double,
        density: Float,
        config: AIGenerationConfig
    ) -> [GeneratedDrumPattern.DrumHit] {

        var hiHats: [GeneratedDrumPattern.DrumHit] = []
        let step: Double

        if density < 0.3 {
            step = 1.0  // Quarter notes
        } else if density < 0.6 {
            step = 0.5  // 8th notes
        } else {
            step = 0.25 // 16th notes
        }

        for beat in stride(from: 0, to: length, by: step) {
            let isDownbeat = beat.truncatingRemainder(dividingBy: 1) == 0
            let isOffbeat = beat.truncatingRemainder(dividingBy: 0.5) == 0 && !isDownbeat

            var velocity = 80
            if isDownbeat { velocity = 100 }
            else if isOffbeat { velocity = 70 }
            else { velocity = 60 }

            // Open/closed variation
            let isOpen = isOffbeat && Float.random(in: 0...1) < 0.2

            hiHats.append(GeneratedDrumPattern.DrumHit(
                beat: beat + humanize(config),
                velocity: velocity + Int.random(in: -10...10),
                variation: isOpen ? 1 : 0
            ))
        }

        return hiHats
    }

    private func generateTomFills(
        length: Double,
        config: AIGenerationConfig
    ) -> [GeneratedDrumPattern.DrumHit] {

        var toms: [GeneratedDrumPattern.DrumHit] = []

        // Add fill before phrase end
        let fillStart = max(0, length - 1)

        for i in 0..<4 {
            toms.append(GeneratedDrumPattern.DrumHit(
                beat: fillStart + Double(i) * 0.25 + humanize(config),
                velocity: 80 + i * 5,
                variation: (3 - i)  // High to low tom
            ))
        }

        return toms
    }

    private func humanize(_ config: AIGenerationConfig) -> Double {
        return Double.random(in: -0.02...0.02) * Double(config.humanization)
    }
}

// MARK: - Bass Generator

class BassGenerator {

    func generateBassLine(
        chords: [GeneratedChord],
        scale: BioScale,
        characteristics: MusicalCharacteristics,
        config: AIGenerationConfig
    ) -> [GeneratedNote] {

        var bassNotes: [GeneratedNote] = []

        for chord in chords {
            let bassRoot = chord.root - 24  // Two octaves below

            // Root on downbeat
            bassNotes.append(GeneratedNote(
                pitch: bassRoot,
                velocity: 100,
                startBeat: chord.startBeat,
                duration: 0.9,
                expression: .init()
            ))

            // Pattern based on density
            if characteristics.rhythmDensity > 0.4 && chord.duration >= 2 {
                // Add fifth
                bassNotes.append(GeneratedNote(
                    pitch: bassRoot + 7,
                    velocity: 85,
                    startBeat: chord.startBeat + 1,
                    duration: 0.9,
                    expression: .init()
                ))
            }

            if characteristics.rhythmDensity > 0.6 && chord.duration >= 3 {
                // Walking bass
                bassNotes.append(GeneratedNote(
                    pitch: bassRoot + 3,
                    velocity: 75,
                    startBeat: chord.startBeat + 2,
                    duration: 0.9,
                    expression: .init()
                ))
            }

            if characteristics.rhythmDensity > 0.7 && chord.duration >= 4 {
                // Approach note
                let approachNote = bassRoot + (Float.random(in: 0...1) > 0.5 ? 5 : -2)
                bassNotes.append(GeneratedNote(
                    pitch: approachNote,
                    velocity: 70,
                    startBeat: chord.startBeat + 3,
                    duration: 0.5,
                    expression: .init()
                ))
            }
        }

        return bassNotes
    }
}

// MARK: - Bio-Reactive AI Composer (Main Engine)
/// Migrated to @Observable for better performance (Swift 5.9+)

@MainActor
@Observable
final class BioReactiveAIComposer {

    // Observable state
    var isGenerating = false
    var currentBioState: BioMusicalState = .flowState
    var currentPhrase: GeneratedPhrase?
    var generationHistory: [GeneratedPhrase] = []
    var config = AIGenerationConfig()
    var biometrics = BiometricInput()

    // Tempo sync
    var currentTempo: Double = 90
    var isPlaying = false

    // Generation components
    private let melodyGenerator = MarkovMelodyGenerator()
    private let chordGenerator = ChordProgressionGenerator()
    private let drumGenerator = DrumPatternGenerator()
    private let bassGenerator = BassGenerator()

    // Real-time generation queue
    private var generationQueue = DispatchQueue(label: "ai.composer.generation", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()

    // MIDI output (connect to MIDI2Manager)
    var midi2Manager: Any?  // MIDI2Manager
    var mpeZoneManager: Any? // MPEZoneManager

    init() {
        setupBiometricObserver()
    }

    // MARK: - Public API

    /// Generate a complete musical phrase based on current biometrics
    func generatePhrase(lengthBars: Int = 4) async -> GeneratedPhrase {
        isGenerating = true
        defer { isGenerating = false }

        // Update bio state
        currentBioState = biometrics.bioMusicalState
        let characteristics = currentBioState.musicalCharacteristics

        // Calculate tempo from bio data + characteristics
        let bioTempo = calculateBioTempo()
        currentTempo = bioTempo

        // Choose scale based on state
        let scale = characteristics.preferredScales.randomElement() ?? .major
        let rootNote = 60  // C4

        let lengthBeats = Double(lengthBars) * 4

        // Generate all elements
        async let melody = generateMelodyAsync(scale: scale, root: rootNote, length: lengthBeats, chars: characteristics)
        async let chords = generateChordsAsync(scale: scale, root: rootNote, length: lengthBeats, chars: characteristics)
        async let drums = generateDrumsAsync(length: lengthBeats, chars: characteristics)

        let (melodyResult, chordsResult, drumsResult) = await (melody, chords, drums)

        // Generate bass based on chords
        let bassLine = bassGenerator.generateBassLine(
            chords: chordsResult,
            scale: scale,
            characteristics: characteristics,
            config: config
        )

        // Combine melody and bass
        var allNotes = melodyResult
        if config.generateBass {
            allNotes.append(contentsOf: bassLine)
        }

        let phrase = GeneratedPhrase(
            notes: allNotes,
            chords: chordsResult,
            drums: drumsResult,
            tempo: bioTempo,
            scale: scale,
            rootNote: rootNote
        )

        currentPhrase = phrase
        generationHistory.append(phrase)

        return phrase
    }

    /// Real-time continuous generation based on bio input
    func startContinuousGeneration() {
        isPlaying = true

        Timer.publish(every: 4.0 / (currentTempo / 60.0), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }

                Task {
                    await self.generatePhrase(lengthBars: 1)
                }
            }
            .store(in: &cancellables)
    }

    func stopContinuousGeneration() {
        isPlaying = false
        cancellables.removeAll()
    }

    /// Update biometrics from external source
    func updateBiometrics(_ input: BiometricInput) {
        biometrics = input
        currentBioState = input.bioMusicalState

        // Smooth tempo transition
        let targetTempo = calculateBioTempo()
        withAnimation(.easeInOut(duration: 2.0)) {
            currentTempo = targetTempo
        }
    }

    // MARK: - Private Generation Methods

    private func generateMelodyAsync(
        scale: BioScale,
        root: Int,
        length: Double,
        chars: MusicalCharacteristics
    ) async -> [GeneratedNote] {
        guard config.generateMelody else { return [] }

        return await withCheckedContinuation { continuation in
            generationQueue.async {
                let melody = self.melodyGenerator.generateMelody(
                    scale: scale,
                    rootNote: root,
                    lengthBeats: length,
                    characteristics: chars,
                    config: self.config
                )
                continuation.resume(returning: melody)
            }
        }
    }

    private func generateChordsAsync(
        scale: BioScale,
        root: Int,
        length: Double,
        chars: MusicalCharacteristics
    ) async -> [GeneratedChord] {
        guard config.generateChords else { return [] }

        return await withCheckedContinuation { continuation in
            generationQueue.async {
                let chords = self.chordGenerator.generateProgression(
                    scale: scale,
                    rootNote: root,
                    lengthBeats: length,
                    characteristics: chars,
                    config: self.config
                )
                continuation.resume(returning: chords)
            }
        }
    }

    private func generateDrumsAsync(
        length: Double,
        chars: MusicalCharacteristics
    ) async -> GeneratedDrumPattern {
        guard config.generateDrums else {
            return GeneratedDrumPattern(lengthInBeats: length)
        }

        return await withCheckedContinuation { continuation in
            generationQueue.async {
                let drums = self.drumGenerator.generatePattern(
                    lengthBeats: length,
                    characteristics: chars,
                    config: self.config
                )
                continuation.resume(returning: drums)
            }
        }
    }

    private func calculateBioTempo() -> Double {
        let chars = currentBioState.musicalCharacteristics
        let tempoRange = chars.tempo

        // Base tempo from bio state range
        var tempo = Double(tempoRange.lowerBound + tempoRange.upperBound) / 2

        // Modify based on heart rate (subtle influence)
        let hrInfluence = (biometrics.heartRate - 72) * 0.5
        tempo += hrInfluence * Double(config.bioReactivity)

        // Modify based on coherence (higher coherence = more stable tempo)
        if biometrics.coherenceScore < 0.4 {
            // Add slight tempo variation for stressed state
            tempo += Double.random(in: -5...5)
        }

        // Constrain to range
        return max(Double(tempoRange.lowerBound), min(Double(tempoRange.upperBound), tempo))
    }

    private func setupBiometricObserver() {
        // This would connect to HealthKitManager in production
        // For now, simulate periodic updates
        #if DEBUG
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Simulate bio variation
                self?.biometrics.heartRate += Double.random(in: -2...2)
                self?.biometrics.coherenceScore += Float.random(in: -0.05...0.05)
                self?.biometrics.coherenceScore = max(0, min(1, self?.biometrics.coherenceScore ?? 0.5))
            }
            .store(in: &cancellables)
        #endif
    }
}

// MARK: - SwiftUI Visualization

struct BioReactiveComposerView: View {
    @StateObject private var composer = BioReactiveAIComposer()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with bio state
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bio-Reactive AI Composer")
                        .font(.title2.bold())

                    HStack(spacing: 16) {
                        Label(composer.currentBioState.rawValue, systemImage: "brain.head.profile")
                            .foregroundColor(colorForState(composer.currentBioState))

                        Label(String(format: "%.0f BPM", composer.currentTempo), systemImage: "metronome")

                        Label(String(format: "%.0f%%", composer.biometrics.coherenceScore * 100), systemImage: "heart.fill")
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }

                Spacer()

                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    if composer.isPlaying {
                        composer.stopContinuousGeneration()
                    } else {
                        composer.startContinuousGeneration()
                    }
                }) {
                    Image(systemName: composer.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Biometric visualization
            BiometricVisualization(biometrics: composer.biometrics, state: composer.currentBioState)
                .frame(height: 120)
                .padding()

            Divider()

            // Generated music visualization
            if let phrase = composer.currentPhrase {
                PhraseVisualization(phrase: phrase)
                    .padding()
            } else {
                ContentUnavailableView(
                    "No Music Generated",
                    systemImage: "music.note",
                    description: Text("Press play to start bio-reactive composition")
                )
            }

            Spacer()

            // Controls
            HStack(spacing: 20) {
                // Generation toggles
                Toggle("Melody", isOn: $composer.config.generateMelody)
                Toggle("Chords", isOn: $composer.config.generateChords)
                Toggle("Drums", isOn: $composer.config.generateDrums)
                Toggle("Bass", isOn: $composer.config.generateBass)

                Spacer()

                // Single phrase generation
                Button("Generate Phrase") {
                    Task {
                        await composer.generatePhrase()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(composer.isGenerating)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            ComposerSettingsView(config: $composer.config)
        }
    }

    func colorForState(_ state: BioMusicalState) -> Color {
        switch state {
        case .deepCalm: return .blue
        case .flowState: return .green
        case .creative: return .purple
        case .energized: return .orange
        case .stressed: return .red
        case .meditative: return .indigo
        }
    }
}

struct BiometricVisualization: View {
    let biometrics: BiometricInput
    let state: BioMusicalState

    var body: some View {
        HStack(spacing: 20) {
            // Heart rate gauge
            Gauge(value: biometrics.heartRate, in: 40...140) {
                Text("HR")
            } currentValueLabel: {
                Text(String(format: "%.0f", biometrics.heartRate))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.red)

            // Coherence gauge
            Gauge(value: Double(biometrics.coherenceScore), in: 0...1) {
                Text("Coherence")
            } currentValueLabel: {
                Text(String(format: "%.0f%%", biometrics.coherenceScore * 100))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.green)

            // HRV gauge
            Gauge(value: biometrics.hrvSDNN, in: 0...100) {
                Text("HRV")
            } currentValueLabel: {
                Text(String(format: "%.0f", biometrics.hrvSDNN))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.blue)

            Spacer()

            // State indicator
            VStack {
                Image(systemName: iconForState(state))
                    .font(.largeTitle)
                    .foregroundColor(colorForState(state))

                Text(state.rawValue)
                    .font(.caption)
            }
            .frame(width: 100)
        }
    }

    func iconForState(_ state: BioMusicalState) -> String {
        switch state {
        case .deepCalm: return "leaf.fill"
        case .flowState: return "arrow.triangle.2.circlepath"
        case .creative: return "lightbulb.fill"
        case .energized: return "bolt.fill"
        case .stressed: return "exclamationmark.triangle"
        case .meditative: return "moon.fill"
        }
    }

    func colorForState(_ state: BioMusicalState) -> Color {
        switch state {
        case .deepCalm: return .blue
        case .flowState: return .green
        case .creative: return .purple
        case .energized: return .orange
        case .stressed: return .red
        case .meditative: return .indigo
        }
    }
}

struct PhraseVisualization: View {
    let phrase: GeneratedPhrase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Info bar
            HStack {
                Label(phrase.scale.rawValue, systemImage: "music.note.list")
                Label(String(format: "%.0f BPM", phrase.tempo), systemImage: "metronome")
                Label("\(phrase.notes.count) notes", systemImage: "waveform")
                Label("\(phrase.chords.count) chords", systemImage: "pianokeys")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Piano roll visualization
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                Canvas { context, size in
                    // Draw notes
                    for note in phrase.notes {
                        let x = note.startBeat / (phrase.drums.lengthInBeats) * width
                        let noteHeight: CGFloat = 4
                        let y = height - CGFloat(note.pitch - 36) / 60 * height

                        let noteWidth = note.duration / phrase.drums.lengthInBeats * width

                        let rect = CGRect(x: x, y: y, width: max(2, noteWidth), height: noteHeight)
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 2),
                            with: .color(.blue.opacity(Double(note.velocity) / 127))
                        )
                    }

                    // Draw chord roots
                    for chord in phrase.chords {
                        let x = chord.startBeat / phrase.drums.lengthInBeats * width
                        let y = height - CGFloat(chord.root - 36) / 60 * height

                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                            with: .color(.purple)
                        )
                    }
                }
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ComposerSettingsView: View {
    @Binding var config: AIGenerationConfig
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Generation Style") {
                    Slider(value: $config.creativity, in: 0...1) {
                        Text("Creativity: \(Int(config.creativity * 100))%")
                    }

                    Slider(value: $config.energy, in: 0...1) {
                        Text("Energy: \(Int(config.energy * 100))%")
                    }

                    Slider(value: $config.complexity, in: 0...1) {
                        Text("Complexity: \(Int(config.complexity * 100))%")
                    }

                    Slider(value: $config.humanization, in: 0...1) {
                        Text("Humanization: \(Int(config.humanization * 100))%")
                    }
                }

                Section("Bio Reactivity") {
                    Slider(value: $config.bioReactivity, in: 0...1) {
                        Text("Bio Influence: \(Int(config.bioReactivity * 100))%")
                    }
                }

                Section("Style") {
                    Picker("Genre", selection: $config.genreHint) {
                        ForEach(AIGenerationConfig.GenreHint.allCases, id: \.self) { genre in
                            Text(genre.rawValue.capitalized).tag(genre)
                        }
                    }

                    Picker("Instrument", selection: $config.instrumentHint) {
                        ForEach(AIGenerationConfig.InstrumentHint.allCases, id: \.self) { inst in
                            Text(inst.rawValue.capitalized).tag(inst)
                        }
                    }
                }
            }
            .navigationTitle("Composer Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Backward Compatibility

extension BioReactiveAIComposer: ObservableObject { }
