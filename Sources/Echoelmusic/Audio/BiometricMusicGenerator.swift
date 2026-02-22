// BiometricMusicGenerator.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Biometric Music Generator - Create music from your body's rhythms
// Transform heart rate, HRV, breathing, and coherence into melodic compositions
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine
import QuartzCore

// MARK: - Generator Constants

/// Constants for biometric music generation
public enum BiometricMusicConstants {
    public static let baseOctave: Int = 4
    public static let maxPolyphony: Int = 8
    public static let minBPM: Double = 40.0
    public static let maxBPM: Double = 200.0
    public static let defaultBPM: Double = 120.0
    public static let quantizeResolution: Double = 16.0  // 16th notes
    public static let phi: Float = 1.618033988749895
    public static let schumannHz: Float = 7.83
}

// MARK: - Musical Scale

/// Musical scale definitions
public enum MusicalScale: String, CaseIterable, Identifiable, Sendable {
    case major = "Major"
    case minor = "Minor"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case aeolian = "Aeolian"
    case locrian = "Locrian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case wholeTone = "Whole Tone"
    case blues = "Blues"
    case chromatic = "Chromatic"
    case hungarianMinor = "Hungarian Minor"
    case japanese = "Japanese"
    case arabic = "Arabic"

    public var id: String { rawValue }

    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return Array(0...11)
        case .hungarianMinor: return [0, 2, 3, 6, 7, 8, 11]
        case .japanese: return [0, 1, 5, 7, 8]
        case .arabic: return [0, 1, 4, 5, 7, 8, 11]
        }
    }
}

// MARK: - Musical Note

/// A musical note with pitch, velocity, and duration
public struct BioMusicalNote: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var pitch: Int      // MIDI note number (0-127)
    public var velocity: Float // 0-1
    public var duration: TimeInterval
    public var startTime: TimeInterval
    public var channel: Int
    public var source: NoteSource

    public enum NoteSource: String, Sendable {
        case heartbeat = "Heartbeat"
        case hrv = "HRV"
        case breathing = "Breathing"
        case coherence = "Coherence"
        case melody = "Melody"
        case harmony = "Harmony"
        case bass = "Bass"
        case arpeggio = "Arpeggio"
    }

    public init(pitch: Int, velocity: Float = 0.8, duration: TimeInterval = 0.5, startTime: TimeInterval = 0, channel: Int = 0, source: NoteSource = .melody) {
        self.pitch = pitch.clamped(to: 0...127)
        self.velocity = velocity.clamped(to: 0...1)
        self.duration = duration
        self.startTime = startTime
        self.channel = channel
        self.source = source
    }

    public var noteName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = pitch / 12 - 1
        let note = pitch % 12
        return "\(names[note])\(octave)"
    }

    public var frequency: Float {
        440.0 * pow(2.0, Float(pitch - 69) / 12.0)
    }
}

// MARK: - Chord

/// A chord made of multiple notes
public struct Chord: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var rootNote: Int
    public var type: ChordType
    public var inversion: Int
    public var notes: [Int]

    public enum ChordType: String, CaseIterable, Sendable {
        case major = "Major"
        case minor = "Minor"
        case diminished = "Diminished"
        case augmented = "Augmented"
        case major7 = "Major 7"
        case minor7 = "Minor 7"
        case dominant7 = "Dominant 7"
        case suspended2 = "Sus2"
        case suspended4 = "Sus4"
        case add9 = "Add9"

        public var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .diminished: return [0, 3, 6]
            case .augmented: return [0, 4, 8]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .dominant7: return [0, 4, 7, 10]
            case .suspended2: return [0, 2, 7]
            case .suspended4: return [0, 5, 7]
            case .add9: return [0, 4, 7, 14]
            }
        }
    }

    public init(rootNote: Int, type: ChordType, inversion: Int = 0) {
        self.rootNote = rootNote
        self.type = type
        self.inversion = inversion

        var chordNotes = type.intervals.map { rootNote + $0 }

        // Apply inversion
        for _ in 0..<inversion {
            if let first = chordNotes.first {
                chordNotes.removeFirst()
                chordNotes.append(first + 12)
            }
        }

        self.notes = chordNotes
    }
}

// MARK: - Bio Musical Data

/// Biometric data formatted for music generation
public struct BioMusicalData: Equatable, Sendable {
    public var heartRate: Double = 70.0
    public var hrvMs: Double = 50.0
    public var coherence: Float = 0.5
    public var breathingRate: Double = 12.0
    public var breathPhase: Float = 0.0  // 0-1
    public var gsr: Float = 0.5
    public var temperature: Float = 0.5
    public var eegAlpha: Float = 0.5
    public var eegBeta: Float = 0.5
    public var eegTheta: Float = 0.5

    public init() {}

    /// Heart rate as BPM for tempo
    public var tempoBPM: Double {
        heartRate.clamped(to: BiometricMusicConstants.minBPM...BiometricMusicConstants.maxBPM)
    }

    /// HRV as melodic variation (higher HRV = more variation)
    public var melodicVariation: Float {
        Float(hrvMs / 100.0).clamped(to: 0...1)
    }

    /// Coherence as harmonic consonance
    public var harmonicConsonance: Float {
        coherence
    }

    /// Breathing as dynamic envelope
    public var dynamicEnvelope: Float {
        sin(breathPhase * Float.pi)
    }

    /// GSR as intensity
    public var intensity: Float {
        gsr
    }
}

// MARK: - Generation Configuration

/// Configuration for the biometric music generator
public struct GeneratorConfiguration: Sendable {
    public var scale: MusicalScale = .pentatonicMajor
    public var rootNote: Int = 60  // Middle C
    public var octaveRange: ClosedRange<Int> = 3...5
    public var tempoSource: TempoSource = .heartRate
    public var melodySource: MelodySource = .hrv
    public var harmonySource: HarmonySource = .coherence
    public var rhythmSource: RhythmSource = .breathing
    public var enableBass: Bool = true
    public var enableArpeggio: Bool = true
    public var enablePad: Bool = true
    public var quantize: Bool = true
    public var humanize: Float = 0.1  // Timing variation

    public enum TempoSource: String, CaseIterable, Sendable {
        case heartRate = "Heart Rate"
        case fixed = "Fixed"
        case breathing = "Breathing"
        case hrv = "HRV"
    }

    public enum MelodySource: String, CaseIterable, Sendable {
        case hrv = "HRV"
        case coherence = "Coherence"
        case breathing = "Breathing"
        case gsr = "GSR"
        case eeg = "EEG"
    }

    public enum HarmonySource: String, CaseIterable, Sendable {
        case coherence = "Coherence"
        case hrv = "HRV"
        case breathing = "Breathing"
    }

    public enum RhythmSource: String, CaseIterable, Sendable {
        case breathing = "Breathing"
        case heartbeat = "Heartbeat"
        case hrv = "HRV"
        case fixed = "Fixed"
    }

    public init() {}
}

// MARK: - Generated Phrase

/// A phrase of generated music
public struct GeneratedPhrase: Identifiable, Sendable {
    public let id = UUID()
    public var notes: [BioMusicalNote]
    public var chords: [Chord]
    public var duration: TimeInterval
    public var tempo: Double
    public var timestamp: Date

    public init(notes: [BioMusicalNote] = [], chords: [Chord] = [], duration: TimeInterval = 4.0, tempo: Double = 120.0) {
        self.notes = notes
        self.chords = chords
        self.duration = duration
        self.tempo = tempo
        self.timestamp = Date()
    }
}

// MARK: - Biometric Music Generator

/// Main engine for generating music from biometric data
@MainActor
public final class BiometricMusicGenerator: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var currentPhrase: GeneratedPhrase?
    @Published public private(set) var currentTempo: Double = 120.0
    @Published public private(set) var currentScale: MusicalScale = .pentatonicMajor
    @Published public private(set) var activeNotes: [BioMusicalNote] = []

    @Published public var configuration = GeneratorConfiguration()
    @Published public var bioData = BioMusicalData()

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var beatCounter: Int = 0
    private var measureCounter: Int = 0
    private var lastBeatTime: CFTimeInterval = CACurrentMediaTime()
    private var phraseHistory: [GeneratedPhrase] = []
    private var melodyMemory: [Int] = []  // Recent pitches for continuity
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Markov Chain for Melody

    private var markovTransitions: [Int: [Int: Float]] = [:]

    // MARK: - Initialization

    public init() {
        initializeMarkovChain()
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func initializeMarkovChain() {
        // Initialize basic melodic tendencies
        // Step motion is more likely than leaps
        let intervals = configuration.scale.intervals

        for interval in intervals {
            var transitions: [Int: Float] = [:]

            for targetInterval in intervals {
                let distance = abs(targetInterval - interval)
                // Prefer small intervals
                let probability: Float
                switch distance {
                case 0: probability = 0.15  // Repeat
                case 1, 2: probability = 0.35  // Step
                case 3, 4: probability = 0.25  // Third
                case 5, 7: probability = 0.15  // Fourth/Fifth
                default: probability = 0.1   // Larger leaps
                }
                transitions[targetInterval] = probability
            }

            markovTransitions[interval] = transitions
        }
    }

    // MARK: - Generation Control

    /// Start generating music
    public func startGenerating() {
        guard !isGenerating else { return }

        isGenerating = true
        startGenerationLoop()

        log.audio("BiometricMusicGenerator: Started generating")
    }

    /// Stop generating music
    public func stopGenerating() {
        isGenerating = false
        stopGenerationLoop()
        activeNotes.removeAll()

        log.audio("BiometricMusicGenerator: Stopped generating")
    }

    // MARK: - Generation Loop

    private func startGenerationLoop() {
        // Update at tempo-based interval
        updateTempo()

        let beatInterval = 60.0 / currentTempo
        updateTimer = Timer.scheduledTimer(withTimeInterval: beatInterval / 4, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.generateTick()
            }
        }
    }

    private func stopGenerationLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func generateTick() {
        guard isGenerating else { return }

        // Update tempo based on bio data
        updateTempo()

        // Restart timer if tempo changed significantly
        let beatInterval = 60.0 / currentTempo
        if abs(beatInterval / 4 - (updateTimer?.timeInterval ?? 0)) > 0.01 {
            stopGenerationLoop()
            startGenerationLoop()
        }

        // Generate on each 16th note
        beatCounter += 1

        // Generate different elements at different times
        if beatCounter % 4 == 0 {
            // Quarter note: melody
            generateMelody()
        }

        if beatCounter % 8 == 0 {
            // Half note: harmony
            generateHarmony()
        }

        if beatCounter % 16 == 0 {
            // Whole note: bass
            if configuration.enableBass {
                generateBass()
            }
            measureCounter += 1
        }

        if beatCounter % 2 == 0 && configuration.enableArpeggio {
            // Eighth note: arpeggio
            generateArpeggio()
        }

        // Clear old notes
        let elapsed = CACurrentMediaTime() - lastBeatTime
        activeNotes.removeAll { note in
            elapsed > note.startTime + note.duration
        }
    }

    // MARK: - Tempo

    private func updateTempo() {
        switch configuration.tempoSource {
        case .heartRate:
            currentTempo = bioData.tempoBPM
        case .fixed:
            currentTempo = BiometricMusicConstants.defaultBPM
        case .breathing:
            // Map breathing rate to tempo range
            currentTempo = 60.0 + bioData.breathingRate * 5
        case .hrv:
            // Higher HRV = slightly slower, more relaxed tempo
            let hrvFactor = 1.0 - (bioData.hrvMs / 100.0) * 0.2
            currentTempo = BiometricMusicConstants.defaultBPM * hrvFactor
        }

        currentTempo = currentTempo.clamped(to: BiometricMusicConstants.minBPM...BiometricMusicConstants.maxBPM)
    }

    // MARK: - Melody Generation

    private func generateMelody() {
        let variation = bioData.melodicVariation
        let intervals = configuration.scale.intervals

        // Determine if we should generate a note (breathing affects this)
        let noteProbability = 0.5 + bioData.dynamicEnvelope * 0.3
        guard Float.random(in: 0...1) < noteProbability else { return }

        // Get next pitch using Markov chain
        let nextPitch: Int

        if let lastPitch = melodyMemory.last {
            let lastInterval = (lastPitch - configuration.rootNote) % 12
            let normalizedInterval = intervals.min(by: { abs($0 - lastInterval) < abs($1 - lastInterval) }) ?? 0

            if let transitions = markovTransitions[normalizedInterval] {
                // Weighted random selection
                let total = transitions.values.reduce(0, +)
                var random = Float.random(in: 0..<total)

                var selectedInterval = intervals.first ?? 0
                for (interval, probability) in transitions {
                    random -= probability
                    if random <= 0 {
                        selectedInterval = interval
                        break
                    }
                }

                // Add variation based on HRV
                let octaveShift = variation > 0.6 ? (Int.random(in: -1...1) * 12) : 0

                nextPitch = configuration.rootNote + selectedInterval + octaveShift
            } else {
                nextPitch = configuration.rootNote + (intervals.randomElement() ?? 0)
            }
        } else {
            // Start with root or fifth
            let startOptions = [0, 7]
            nextPitch = configuration.rootNote + (startOptions.randomElement() ?? 0)
        }

        // Apply coherence-based octave placement
        let octave = configuration.octaveRange.lowerBound + Int(bioData.coherence * Float(configuration.octaveRange.count))
        let finalPitch = (nextPitch % 12) + (octave * 12)

        // Create note
        let velocity = 0.5 + bioData.dynamicEnvelope * 0.3 + Float.random(in: -0.1...0.1)
        let duration = (60.0 / currentTempo) * Double.random(in: 0.5...1.5)

        let note = BioMusicalNote(
            pitch: finalPitch,
            velocity: velocity,
            duration: duration,
            startTime: CACurrentMediaTime() - lastBeatTime,
            channel: 0,
            source: .melody
        )

        activeNotes.append(note)
        melodyMemory.append(finalPitch)

        // Keep memory limited
        if melodyMemory.count > 8 {
            melodyMemory.removeFirst()
        }
    }

    // MARK: - Harmony Generation

    private func generateHarmony() {
        let consonance = bioData.harmonicConsonance
        let intervals = configuration.scale.intervals

        // Choose chord type based on coherence
        let chordType: Chord.ChordType
        if consonance > 0.7 {
            // High coherence: consonant chords
            chordType = [.major, .major7, .suspended4].randomElement() ?? .major
        } else if consonance > 0.4 {
            // Medium coherence: neutral chords
            chordType = [.minor, .minor7, .suspended2].randomElement() ?? .minor
        } else {
            // Low coherence: more tension
            chordType = [.dominant7, .diminished, .augmented].randomElement() ?? .dominant7
        }

        // Choose root based on position in progression
        let progressionRoots = [0, 5, 3, 4]  // I-V-IV-V style
        let rootInterval = progressionRoots[measureCounter % progressionRoots.count]
        let rootNote = configuration.rootNote + rootInterval

        let chord = Chord(rootNote: rootNote, type: chordType, inversion: Int.random(in: 0...1))

        // Create notes for chord
        let velocity: Float = 0.4 + consonance * 0.2
        let duration = (60.0 / currentTempo) * 2  // Half note

        for pitch in chord.notes {
            let octavePitch = pitch + (configuration.octaveRange.lowerBound - 1) * 12

            let note = BioMusicalNote(
                pitch: octavePitch,
                velocity: velocity,
                duration: duration,
                startTime: CACurrentMediaTime() - lastBeatTime,
                channel: 1,
                source: .harmony
            )

            activeNotes.append(note)
        }
    }

    // MARK: - Bass Generation

    private func generateBass() {
        let intervals = configuration.scale.intervals

        // Bass follows root of harmony
        let progressionRoots = [0, 5, 3, 4]
        let rootInterval = progressionRoots[measureCounter % progressionRoots.count]

        // Bass in low octave
        let bassPitch = configuration.rootNote + rootInterval - 24  // 2 octaves down

        let velocity: Float = 0.6 + bioData.intensity * 0.2
        let duration = (60.0 / currentTempo) * 4  // Whole note

        let note = BioMusicalNote(
            pitch: bassPitch,
            velocity: velocity,
            duration: duration,
            startTime: CACurrentMediaTime() - lastBeatTime,
            channel: 2,
            source: .bass
        )

        activeNotes.append(note)

        // Octave bass on higher energy
        if bioData.intensity > 0.6 {
            let octaveNote = BioMusicalNote(
                pitch: bassPitch + 12,
                velocity: velocity * 0.7,
                duration: duration * 0.5,
                startTime: CACurrentMediaTime() - lastBeatTime,
                channel: 2,
                source: .bass
            )
            activeNotes.append(octaveNote)
        }
    }

    // MARK: - Arpeggio Generation

    private func generateArpeggio() {
        guard bioData.coherence > 0.3 else { return }  // Only on moderate coherence

        let intervals = configuration.scale.intervals

        // Arpeggio pattern based on breathing phase
        let patternIndex = Int(bioData.breathPhase * 4) % 4
        let arpeggioIntervals = [0, 4, 7, 4]  // Up-down pattern
        let interval = arpeggioIntervals[patternIndex]

        guard let scaleInterval = intervals.first(where: { $0 >= interval }) ?? intervals.last else { return }

        let pitch = configuration.rootNote + scaleInterval + (configuration.octaveRange.lowerBound * 12)

        let velocity: Float = 0.3 + bioData.dynamicEnvelope * 0.2
        let duration = (60.0 / currentTempo) * 0.25

        let note = BioMusicalNote(
            pitch: pitch,
            velocity: velocity,
            duration: duration,
            startTime: CACurrentMediaTime() - lastBeatTime,
            channel: 3,
            source: .arpeggio
        )

        activeNotes.append(note)
    }

    // MARK: - Bio Data Update

    /// Update biometric data
    public func updateBioData(heartRate: Double? = nil, hrv: Double? = nil, coherence: Float? = nil,
                             breathingRate: Double? = nil, breathPhase: Float? = nil, gsr: Float? = nil) {
        if let hr = heartRate { bioData.heartRate = hr }
        if let hrvVal = hrv { bioData.hrvMs = hrvVal }
        if let coh = coherence { bioData.coherence = coh }
        if let br = breathingRate { bioData.breathingRate = br }
        if let bp = breathPhase { bioData.breathPhase = bp }
        if let gsrVal = gsr { bioData.gsr = gsrVal }
    }

    // MARK: - Scale Selection

    /// Auto-select scale based on coherence
    public func autoSelectScale() {
        let coherence = bioData.coherence

        if coherence > 0.8 {
            currentScale = .lydian  // Bright, uplifting
        } else if coherence > 0.6 {
            currentScale = .major
        } else if coherence > 0.4 {
            currentScale = .pentatonicMajor  // Safe, consonant
        } else if coherence > 0.2 {
            currentScale = .dorian  // Slightly darker
        } else {
            currentScale = .pentatonicMinor  // Darker but still consonant
        }

        configuration.scale = currentScale
        initializeMarkovChain()  // Rebuild transitions for new scale
    }

    // MARK: - Phrase Export

    /// Get current phrase as MIDI-ready data
    public func exportCurrentPhrase() -> GeneratedPhrase {
        let duration = (60.0 / currentTempo) * Double(beatCounter)

        return GeneratedPhrase(
            notes: activeNotes,
            chords: [],  // Would include current chord progression
            duration: duration,
            tempo: currentTempo
        )
    }

    /// Clear melody memory and start fresh
    public func resetMelody() {
        melodyMemory.removeAll()
        beatCounter = 0
        measureCounter = 0
    }
}

// MARK: - Extensions
// Note: clamped(to:) extensions moved to NumericExtensions.swift
