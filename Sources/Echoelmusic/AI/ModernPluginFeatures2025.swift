import Foundation
import Accelerate
import AVFoundation
import CoreML
import Combine

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: Modern Plugin Features 2025
// MARK: ═══════════════════════════════════════════════════════════════════════════════
///
/// Inspired by the latest 2025 plugin innovations:
/// - Sauceware Audio Spawn: AI MIDI generation with genre models
/// - Xfer Serum 2 / TheWaveWarden Spline: Spectral morphing wavetable synthesis
/// - THX Spatial Creator / DearVR: Advanced HRTF binaural rendering
/// - Minimal Audio Current 2: Hybrid multi-engine synthesis
/// - Sample 3: AI-powered smart sample chopping
///
/// All features integrate with Echoelmusic's bio-reactive systems for unique
/// health-aware music generation capabilities.
///

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: 1. SPAWN-STYLE AI MIDI GENERATOR
// MARK: ═══════════════════════════════════════════════════════════════════════════════

/// Genre-specific AI model for MIDI generation (Spawn-style)
public enum GenreAIModel: String, CaseIterable, Identifiable {
    case trap = "Trap"
    case melodicRap = "Melodic Rap"
    case era90s = "90's Era"
    case stadiumStatus = "Stadium Status"
    case lofi = "Lo-Fi"
    case edm = "EDM"
    case rnb = "R&B"
    case jazz = "Jazz"
    case ambient = "Ambient"
    case bioReactive = "Bio-Reactive"  // Unique to Echoelmusic

    public var id: String { rawValue }

    /// Typical BPM range for this genre
    var bpmRange: ClosedRange<Double> {
        switch self {
        case .trap: return 130...170
        case .melodicRap: return 140...160
        case .era90s: return 85...95
        case .stadiumStatus: return 120...140
        case .lofi: return 70...90
        case .edm: return 120...150
        case .rnb: return 60...80
        case .jazz: return 100...140
        case .ambient: return 60...80
        case .bioReactive: return 60...120  // Adapts to heart rate
        }
    }

    /// Preferred scales for this genre
    var preferredScales: [String] {
        switch self {
        case .trap: return ["minor", "phrygian", "harmonic_minor"]
        case .melodicRap: return ["minor", "dorian", "aeolian"]
        case .era90s: return ["minor", "dorian", "pentatonic"]
        case .stadiumStatus: return ["major", "mixolydian", "lydian"]
        case .lofi: return ["minor", "dorian", "pentatonic"]
        case .edm: return ["minor", "phrygian", "harmonic_minor"]
        case .rnb: return ["minor", "dorian", "mixolydian"]
        case .jazz: return ["dorian", "mixolydian", "lydian", "altered"]
        case .ambient: return ["lydian", "whole_tone", "pentatonic"]
        case .bioReactive: return ["major", "minor", "dorian"]  // Adapts to coherence
        }
    }

    /// Melodic density (notes per bar)
    var melodicDensity: ClosedRange<Int> {
        switch self {
        case .trap: return 4...16
        case .melodicRap: return 4...12
        case .era90s: return 2...8
        case .stadiumStatus: return 4...8
        case .lofi: return 2...6
        case .edm: return 8...16
        case .rnb: return 4...10
        case .jazz: return 6...16
        case .ambient: return 1...4
        case .bioReactive: return 2...12
        }
    }

    /// Chord complexity (extensions, alterations)
    var chordComplexity: Float {
        switch self {
        case .trap: return 0.3
        case .melodicRap: return 0.5
        case .era90s: return 0.6
        case .stadiumStatus: return 0.4
        case .lofi: return 0.7
        case .edm: return 0.3
        case .rnb: return 0.8
        case .jazz: return 1.0
        case .ambient: return 0.6
        case .bioReactive: return 0.5
        }
    }
}

/// AI-powered MIDI Generator inspired by Sauceware Spawn
@MainActor
public final class SpawnStyleMIDIGenerator: ObservableObject {

    // MARK: - Published State

    @Published public var currentGenre: GenreAIModel = .melodicRap
    @Published public var isGenerating: Bool = false
    @Published public var generatedMelody: [MIDINote] = []
    @Published public var generatedChords: [MIDIChord] = []
    @Published public var generatedBassline: [MIDINote] = []
    @Published public var currentBPM: Double = 140
    @Published public var currentKey: String = "C"
    @Published public var currentScale: String = "minor"

    // MARK: - Bio-Reactive Integration

    @Published public var bioReactiveEnabled: Bool = true
    @Published public var currentHRV: Float = 50.0
    @Published public var currentCoherence: Float = 0.5
    @Published public var currentHeartRate: Float = 72.0

    // MARK: - Markov Chain Transition Matrices

    /// Melodic interval transition probabilities (genre-specific)
    private var melodicTransitions: [[Float]] = []

    /// Rhythmic pattern probabilities
    private var rhythmicPatterns: [[Float]] = []

    /// Scale degrees for current scale
    private var scaleIntervals: [Int] = [0, 2, 3, 5, 7, 8, 10]  // Minor scale default

    // MARK: - Scale Library

    private let scaleLibrary: [String: [Int]] = [
        "major": [0, 2, 4, 5, 7, 9, 11],
        "minor": [0, 2, 3, 5, 7, 8, 10],
        "dorian": [0, 2, 3, 5, 7, 9, 10],
        "phrygian": [0, 1, 3, 5, 7, 8, 10],
        "lydian": [0, 2, 4, 6, 7, 9, 11],
        "mixolydian": [0, 2, 4, 5, 7, 9, 10],
        "aeolian": [0, 2, 3, 5, 7, 8, 10],
        "locrian": [0, 1, 3, 5, 6, 8, 10],
        "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
        "melodic_minor": [0, 2, 3, 5, 7, 9, 11],
        "pentatonic": [0, 2, 4, 7, 9],
        "blues": [0, 3, 5, 6, 7, 10],
        "whole_tone": [0, 2, 4, 6, 8, 10],
        "altered": [0, 1, 3, 4, 6, 8, 10]
    ]

    private let rootNotes: [String: Int] = [
        "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63,
        "E": 64, "F": 65, "F#": 66, "Gb": 66, "G": 67, "G#": 68,
        "Ab": 68, "A": 69, "A#": 70, "Bb": 70, "B": 71
    ]

    // MARK: - Initialization

    public init() {
        initializeTransitionMatrices()
        print("✅ SpawnStyleMIDIGenerator: Initialized with genre-specific AI models")
    }

    private func initializeTransitionMatrices() {
        // Initialize Markov chain transition matrices for melodic motion
        // 7x7 matrix for scale degree transitions (-3 to +3 steps)
        melodicTransitions = Array(repeating: Array(repeating: 0.0, count: 7), count: 7)

        // Default: prefer stepwise motion
        for i in 0..<7 {
            melodicTransitions[i][3] = 0.3  // Same note (index 3 = 0 steps)
            melodicTransitions[i][2] = 0.25 // Step down
            melodicTransitions[i][4] = 0.25 // Step up
            melodicTransitions[i][1] = 0.1  // Skip down
            melodicTransitions[i][5] = 0.1  // Skip up
            melodicTransitions[i][0] = 0.0  // Leap down (rare)
            melodicTransitions[i][6] = 0.0  // Leap up (rare)
        }
    }

    // MARK: - Genre Model Configuration

    private func configureForGenre(_ genre: GenreAIModel) {
        currentGenre = genre

        // Select random BPM within genre range
        currentBPM = Double.random(in: genre.bpmRange)

        // Select random scale from genre preferences
        if let randomScale = genre.preferredScales.randomElement() {
            currentScale = randomScale
            scaleIntervals = scaleLibrary[randomScale] ?? scaleLibrary["minor"]!
        }

        // Adjust transition matrices based on genre
        adjustTransitionsForGenre(genre)
    }

    private func adjustTransitionsForGenre(_ genre: GenreAIModel) {
        switch genre {
        case .trap:
            // More repetition, sudden jumps
            for i in 0..<7 {
                melodicTransitions[i][3] = 0.4   // More repetition
                melodicTransitions[i][0] = 0.05  // Occasional big leaps
                melodicTransitions[i][6] = 0.05
            }
        case .jazz:
            // More variety, larger intervals
            for i in 0..<7 {
                melodicTransitions[i][3] = 0.15  // Less repetition
                melodicTransitions[i][0] = 0.1   // More leaps
                melodicTransitions[i][6] = 0.1
                melodicTransitions[i][1] = 0.15
                melodicTransitions[i][5] = 0.15
            }
        case .ambient:
            // Slow, sustained, minimal movement
            for i in 0..<7 {
                melodicTransitions[i][3] = 0.5   // Lots of repetition/sustain
                melodicTransitions[i][2] = 0.2
                melodicTransitions[i][4] = 0.2
                melodicTransitions[i][0] = 0.0
                melodicTransitions[i][6] = 0.0
            }
        case .bioReactive:
            // Adapt based on coherence
            let coherenceFactor = currentCoherence
            for i in 0..<7 {
                // High coherence = more flowing, stepwise
                // Low coherence = more erratic
                melodicTransitions[i][3] = 0.2 + 0.3 * coherenceFactor
                melodicTransitions[i][2] = 0.2 + 0.1 * coherenceFactor
                melodicTransitions[i][4] = 0.2 + 0.1 * coherenceFactor
                melodicTransitions[i][0] = 0.1 * (1.0 - coherenceFactor)
                melodicTransitions[i][6] = 0.1 * (1.0 - coherenceFactor)
            }
        default:
            initializeTransitionMatrices()  // Reset to default
        }
    }

    // MARK: - Bio-Reactive Adaptation

    public func updateBioData(hrv: Float, coherence: Float, heartRate: Float) {
        currentHRV = hrv
        currentCoherence = coherence
        currentHeartRate = heartRate

        if bioReactiveEnabled && currentGenre == .bioReactive {
            // Adapt BPM to heart rate (musical relationship)
            currentBPM = Double(heartRate) * (coherence > 0.5 ? 1.0 : 0.5)
            currentBPM = max(60, min(180, currentBPM))

            // Adapt scale to coherence
            if coherence > 0.7 {
                currentScale = "major"
            } else if coherence > 0.4 {
                currentScale = "dorian"
            } else {
                currentScale = "minor"
            }
            scaleIntervals = scaleLibrary[currentScale] ?? scaleLibrary["minor"]!

            adjustTransitionsForGenre(.bioReactive)
        }
    }

    // MARK: - Melody Generation

    public func generateMelody(bars: Int = 4, key: String? = nil) async -> [MIDINote] {
        isGenerating = true
        defer { isGenerating = false }

        let selectedKey = key ?? currentKey
        let rootMIDI = rootNotes[selectedKey] ?? 60

        // Build scale notes across 2 octaves
        var scaleNotes: [Int] = []
        for octave in 0..<2 {
            for interval in scaleIntervals {
                scaleNotes.append(rootMIDI + interval + (octave * 12))
            }
        }

        // Generate notes using Markov chain
        var notes: [MIDINote] = []
        var currentScaleIndex = scaleNotes.count / 2  // Start in middle
        let density = Int.random(in: currentGenre.melodicDensity)
        let totalNotes = bars * density

        var currentTime: Double = 0.0
        let barDuration = 60.0 / currentBPM * 4.0  // 4 beats per bar

        for i in 0..<totalNotes {
            // Choose next scale index using Markov chain
            let motion = sampleFromTransitionMatrix(currentScaleIndex % 7)
            currentScaleIndex = max(0, min(scaleNotes.count - 1, currentScaleIndex + motion))

            // Determine note duration based on genre
            let duration = generateRhythmicDuration(noteIndex: i, density: density)

            // Velocity with humanization
            let baseVelocity = (i % density == 0) ? 100 : 80
            let velocity = baseVelocity + Int.random(in: -10...10)

            let note = MIDINote(
                pitch: scaleNotes[currentScaleIndex],
                velocity: max(1, min(127, velocity)),
                startTime: currentTime,
                duration: duration
            )
            notes.append(note)

            currentTime += duration

            // Occasional rest
            if Float.random(in: 0...1) < 0.15 {
                currentTime += duration * 0.5
            }
        }

        generatedMelody = notes
        print("🎵 Generated \(notes.count) melody notes in \(selectedKey) \(currentScale) @ \(Int(currentBPM)) BPM")
        return notes
    }

    private func sampleFromTransitionMatrix(_ fromState: Int) -> Int {
        let probabilities = melodicTransitions[fromState]
        var random = Float.random(in: 0..<1)

        for (index, prob) in probabilities.enumerated() {
            random -= prob
            if random <= 0 {
                return index - 3  // Convert index to motion (-3 to +3)
            }
        }
        return 0
    }

    private func generateRhythmicDuration(noteIndex: Int, density: Int) -> Double {
        let beatDuration = 60.0 / currentBPM

        switch currentGenre {
        case .trap, .edm:
            // Fast, syncopated
            let divisions: [Double] = [0.25, 0.25, 0.5, 0.5, 0.75, 1.0]
            return beatDuration * (divisions.randomElement() ?? 0.5)
        case .era90s, .lofi:
            // More laid back
            let divisions: [Double] = [0.5, 1.0, 1.0, 1.5, 2.0]
            return beatDuration * (divisions.randomElement() ?? 1.0)
        case .ambient:
            // Long, sustained
            let divisions: [Double] = [2.0, 4.0, 4.0, 8.0]
            return beatDuration * (divisions.randomElement() ?? 4.0)
        case .jazz:
            // Swung, varied
            let isSwung = noteIndex % 2 == 1
            let base = isSwung ? 0.67 : 0.33  // Swing ratio
            return beatDuration * base * Double.random(in: 0.8...1.2)
        default:
            return beatDuration * Double([0.5, 0.5, 1.0, 1.0].randomElement() ?? 0.5)
        }
    }

    // MARK: - Chord Generation

    public func generateChordProgression(bars: Int = 4, key: String? = nil) async -> [MIDIChord] {
        isGenerating = true
        defer { isGenerating = false }

        let selectedKey = key ?? currentKey
        let rootMIDI = rootNotes[selectedKey] ?? 60

        // Common chord progressions by genre
        let progressions = getProgressionsForGenre()
        let selectedProgression = progressions.randomElement() ?? [0, 5, 3, 4]

        var chords: [MIDIChord] = []
        let chordsPerBar = bars >= 4 ? 1 : 2
        let totalChords = bars * chordsPerBar

        var currentTime: Double = 0.0
        let chordDuration = (60.0 / currentBPM * 4.0) / Double(chordsPerBar)

        for i in 0..<totalChords {
            let degree = selectedProgression[i % selectedProgression.count]
            let chordRoot = rootMIDI + scaleIntervals[degree % scaleIntervals.count]

            // Build chord based on complexity
            var chordNotes = buildChord(root: chordRoot, degree: degree)

            // Add extensions based on genre complexity
            if Float.random(in: 0...1) < currentGenre.chordComplexity {
                chordNotes = addChordExtensions(chordNotes, root: chordRoot, degree: degree)
            }

            let chord = MIDIChord(
                notes: chordNotes,
                startTime: currentTime,
                duration: chordDuration,
                velocity: 70 + Int.random(in: -5...5)
            )
            chords.append(chord)

            currentTime += chordDuration
        }

        generatedChords = chords
        print("🎹 Generated \(chords.count) chords in \(selectedKey) \(currentScale)")
        return chords
    }

    private func getProgressionsForGenre() -> [[Int]] {
        switch currentGenre {
        case .trap, .edm:
            return [
                [0, 5, 3, 4],     // i - VI - iv - V
                [0, 3, 5, 4],     // i - iv - VI - V
                [0, 0, 3, 3]      // i - i - iv - iv (dark)
            ]
        case .melodicRap, .rnb:
            return [
                [0, 4, 5, 3],     // i - V - VI - iv
                [0, 3, 4, 4],     // i - iv - V - V
                [1, 4, 0, 3]      // ii - V - I - IV
            ]
        case .era90s:
            return [
                [0, 3, 4, 3],     // i - iv - v - iv
                [0, 5, 3, 4],     // Classic
                [0, 1, 3, 4]      // i - ii - iv - v
            ]
        case .stadiumStatus:
            return [
                [0, 4, 5, 3],     // Anthemic
                [0, 3, 0, 4],     // I - IV - I - V
                [0, 5, 3, 4]      // Big energy
            ]
        case .jazz:
            return [
                [1, 4, 0, 0],     // ii - V - I - I
                [0, 5, 1, 4],     // I - VI - ii - V
                [2, 5, 1, 4]      // iii - VI - ii - V (Coltrane changes lite)
            ]
        case .ambient, .lofi:
            return [
                [0, 3, 0, 3],     // Minimal movement
                [0, 4, 3, 4],     // Gentle
                [0, 0, 3, 0]      // Drone-like
            ]
        case .bioReactive:
            // Adapt based on coherence
            if currentCoherence > 0.7 {
                return [[0, 4, 5, 3]]  // Resolved, happy
            } else if currentCoherence > 0.4 {
                return [[0, 3, 4, 4]]  // Neutral
            } else {
                return [[0, 5, 3, 4]]  // Tension
            }
        }
    }

    private func buildChord(root: Int, degree: Int) -> [Int] {
        // Build triad based on scale degree
        let third = root + (scaleIntervals.contains(4) ? 4 : 3)  // Major or minor third
        let fifth = root + 7
        return [root, third, fifth]
    }

    private func addChordExtensions(_ notes: [Int], root: Int, degree: Int) -> [Int] {
        var extended = notes

        // 7th
        if Float.random(in: 0...1) < currentGenre.chordComplexity {
            extended.append(root + (degree == 4 ? 11 : 10))  // Major 7 on V, minor 7 elsewhere
        }

        // 9th
        if currentGenre.chordComplexity > 0.6 && Float.random(in: 0...1) < 0.5 {
            extended.append(root + 14)
        }

        // 11th (jazz)
        if currentGenre == .jazz && Float.random(in: 0...1) < 0.3 {
            extended.append(root + 17)
        }

        return extended
    }

    // MARK: - Bassline Generation

    public func generateBassline(bars: Int = 4, key: String? = nil) async -> [MIDINote] {
        isGenerating = true
        defer { isGenerating = false }

        let selectedKey = key ?? currentKey
        let rootMIDI = (rootNotes[selectedKey] ?? 60) - 24  // 2 octaves down

        var notes: [MIDINote] = []
        var currentTime: Double = 0.0
        let beatDuration = 60.0 / currentBPM

        let progressions = getProgressionsForGenre()
        let progression = progressions.randomElement() ?? [0, 5, 3, 4]

        for bar in 0..<bars {
            let degree = progression[bar % progression.count]
            let bassRoot = rootMIDI + scaleIntervals[degree % scaleIntervals.count]

            // Generate bass pattern based on genre
            let pattern = generateBassPattern(root: bassRoot, beatDuration: beatDuration)

            for note in pattern {
                var adjustedNote = note
                adjustedNote.startTime += currentTime
                notes.append(adjustedNote)
            }

            currentTime += beatDuration * 4  // One bar
        }

        generatedBassline = notes
        print("🎸 Generated \(notes.count) bassline notes")
        return notes
    }

    private func generateBassPattern(root: Int, beatDuration: Double) -> [MIDINote] {
        var notes: [MIDINote] = []

        switch currentGenre {
        case .trap:
            // 808-style: root on 1, ghost notes
            notes.append(MIDINote(pitch: root, velocity: 110, startTime: 0, duration: beatDuration * 2))
            if Float.random(in: 0...1) < 0.5 {
                notes.append(MIDINote(pitch: root, velocity: 80, startTime: beatDuration * 2.5, duration: beatDuration * 0.5))
            }
        case .era90s, .lofi:
            // Simple, groove-oriented
            notes.append(MIDINote(pitch: root, velocity: 100, startTime: 0, duration: beatDuration))
            notes.append(MIDINote(pitch: root + 7, velocity: 85, startTime: beatDuration * 2, duration: beatDuration * 0.5))
            notes.append(MIDINote(pitch: root, velocity: 90, startTime: beatDuration * 3, duration: beatDuration))
        case .edm:
            // Driving eighth notes
            for i in 0..<8 {
                let pitch = i % 4 == 0 ? root : root + (i % 2 == 0 ? 0 : 7)
                notes.append(MIDINote(pitch: pitch, velocity: i % 2 == 0 ? 100 : 80, startTime: beatDuration * Double(i) * 0.5, duration: beatDuration * 0.4))
            }
        case .jazz:
            // Walking bass
            let walkingNotes = [root, root + 2, root + 4, root + 5]
            for (i, pitch) in walkingNotes.enumerated() {
                notes.append(MIDINote(pitch: pitch, velocity: 90, startTime: beatDuration * Double(i), duration: beatDuration * 0.9))
            }
        default:
            // Basic root-fifth
            notes.append(MIDINote(pitch: root, velocity: 100, startTime: 0, duration: beatDuration * 2))
            notes.append(MIDINote(pitch: root + 7, velocity: 90, startTime: beatDuration * 2, duration: beatDuration * 2))
        }

        return notes
    }

    // MARK: - Full Generation

    public func generateFullArrangement(bars: Int = 8, key: String? = nil, genre: GenreAIModel? = nil) async -> MIDIArrangement {
        if let genre = genre {
            configureForGenre(genre)
        }

        let melody = await generateMelody(bars: bars, key: key)
        let chords = await generateChordProgression(bars: bars, key: key)
        let bassline = await generateBassline(bars: bars, key: key)

        return MIDIArrangement(
            melody: melody,
            chords: chords,
            bassline: bassline,
            bpm: currentBPM,
            key: key ?? currentKey,
            scale: currentScale,
            genre: currentGenre
        )
    }
}

// MARK: - MIDI Data Structures

public struct MIDINote: Identifiable, Equatable {
    public let id = UUID()
    public var pitch: Int           // 0-127
    public var velocity: Int        // 0-127
    public var startTime: Double    // In seconds
    public var duration: Double     // In seconds

    public init(pitch: Int, velocity: Int, startTime: Double, duration: Double) {
        self.pitch = pitch
        self.velocity = velocity
        self.startTime = startTime
        self.duration = duration
    }
}

public struct MIDIChord: Identifiable {
    public let id = UUID()
    public var notes: [Int]         // MIDI pitches
    public var startTime: Double
    public var duration: Double
    public var velocity: Int
}

public struct MIDIArrangement {
    public var melody: [MIDINote]
    public var chords: [MIDIChord]
    public var bassline: [MIDINote]
    public var bpm: Double
    public var key: String
    public var scale: String
    public var genre: GenreAIModel
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: 2. SPECTRAL MORPHING ENGINE (Serum 2 / Spline Style)
// MARK: ═══════════════════════════════════════════════════════════════════════════════

/// Spectral Morphing Wavetable Synthesizer Engine
/// Inspired by Xfer Serum 2 and TheWaveWarden Spline
@MainActor
public final class SpectralMorphingEngine: ObservableObject {

    // MARK: - Published State

    @Published public var morphX: Float = 0.5      // X-axis morph position
    @Published public var morphY: Float = 0.5      // Y-axis morph position (warp amount)
    @Published public var warpMode: WarpMode = .sync
    @Published public var isPlaying: Bool = false

    // MARK: - Wavetable Storage

    private var wavetableA: [Float] = []           // Source wavetable
    private var wavetableB: [Float] = []           // Target wavetable
    private var currentWavetable: [Float] = []     // Morphed result
    private let wavetableSize: Int = 2048
    private let numFrames: Int = 256               // Frames in wavetable

    // MARK: - FFT Setup

    private var fftSetup: vDSP_DFT_Setup?
    private var inverseFFTSetup: vDSP_DFT_Setup?

    // MARK: - Oscillator State

    private var phase: Float = 0.0
    private var frequency: Float = 440.0
    private let sampleRate: Float = 44100.0

    // MARK: - Warp Modes (Serum 2 / Spline style)

    public enum WarpMode: String, CaseIterable {
        case sync = "Sync"
        case bend = "Bend+"
        case bendMinus = "Bend-"
        case pwm = "PWM"
        case asym = "Asym+"
        case asymMinus = "Asym-"
        case flip = "Flip"
        case mirror = "Mirror"
        case remap = "Remap"
        case quantize = "Quantize"
        case fm = "FM"
        case am = "AM"
        case rm = "RM"
        case spectralBlur = "Spectral Blur"
        case spectralShift = "Spectral Shift"
        case harmonicStretch = "Harmonic Stretch"
    }

    // MARK: - Initialization

    public init() {
        setupFFT()
        initializeWavetables()
        print("✅ SpectralMorphingEngine: Initialized with \(wavetableSize)-sample wavetables")
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(wavetableSize), .FORWARD)
        inverseFFTSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(wavetableSize), .INVERSE)
    }

    private func initializeWavetables() {
        // Initialize with basic waveforms
        wavetableA = generateSineWavetable()
        wavetableB = generateSawWavetable()
        currentWavetable = wavetableA
    }

    // MARK: - Wavetable Generation

    public func generateSineWavetable() -> [Float] {
        var wavetable = [Float](repeating: 0, count: wavetableSize)
        for i in 0..<wavetableSize {
            let phase = Float(i) / Float(wavetableSize) * 2.0 * .pi
            wavetable[i] = sin(phase)
        }
        return wavetable
    }

    public func generateSawWavetable() -> [Float] {
        var wavetable = [Float](repeating: 0, count: wavetableSize)
        for i in 0..<wavetableSize {
            wavetable[i] = 2.0 * (Float(i) / Float(wavetableSize)) - 1.0
        }
        return wavetable
    }

    public func generateSquareWavetable() -> [Float] {
        var wavetable = [Float](repeating: 0, count: wavetableSize)
        for i in 0..<wavetableSize {
            wavetable[i] = i < wavetableSize / 2 ? 1.0 : -1.0
        }
        return wavetable
    }

    public func generateTriangleWavetable() -> [Float] {
        var wavetable = [Float](repeating: 0, count: wavetableSize)
        for i in 0..<wavetableSize {
            let phase = Float(i) / Float(wavetableSize)
            if phase < 0.25 {
                wavetable[i] = phase * 4.0
            } else if phase < 0.75 {
                wavetable[i] = 2.0 - phase * 4.0
            } else {
                wavetable[i] = phase * 4.0 - 4.0
            }
        }
        return wavetable
    }

    // MARK: - Spectral Processing

    /// Convert wavetable to frequency domain
    private func toFrequencyDomain(_ wavetable: [Float]) -> (real: [Float], imag: [Float]) {
        guard let fftSetup = fftSetup else { return (wavetable, [Float](repeating: 0, count: wavetable.count)) }

        var realIn = wavetable
        var imagIn = [Float](repeating: 0, count: wavetable.count)
        var realOut = [Float](repeating: 0, count: wavetable.count)
        var imagOut = [Float](repeating: 0, count: wavetable.count)

        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)

        return (realOut, imagOut)
    }

    /// Convert frequency domain back to time domain
    private func toTimeDomain(real: [Float], imag: [Float]) -> [Float] {
        guard let inverseFFTSetup = inverseFFTSetup else { return real }

        var realIn = real
        var imagIn = imag
        var realOut = [Float](repeating: 0, count: real.count)
        var imagOut = [Float](repeating: 0, count: real.count)

        vDSP_DFT_Execute(inverseFFTSetup, &realIn, &imagIn, &realOut, &imagOut)

        // Normalize
        var scale = Float(1.0 / Float(real.count))
        vDSP_vsmul(realOut, 1, &scale, &realOut, 1, vDSP_Length(real.count))

        return realOut
    }

    // MARK: - Morphing

    /// Morph between two wavetables using spectral interpolation
    public func morph() {
        let spectrumA = toFrequencyDomain(wavetableA)
        let spectrumB = toFrequencyDomain(wavetableB)

        // Interpolate magnitudes and phases
        var morphedReal = [Float](repeating: 0, count: wavetableSize)
        var morphedImag = [Float](repeating: 0, count: wavetableSize)

        for i in 0..<wavetableSize {
            morphedReal[i] = spectrumA.real[i] * (1.0 - morphX) + spectrumB.real[i] * morphX
            morphedImag[i] = spectrumA.imag[i] * (1.0 - morphX) + spectrumB.imag[i] * morphX
        }

        // Apply warp mode
        applyWarpMode(&morphedReal, &morphedImag)

        // Convert back to time domain
        currentWavetable = toTimeDomain(real: morphedReal, imag: morphedImag)
    }

    // MARK: - Warp Modes Implementation

    private func applyWarpMode(_ real: inout [Float], _ imag: inout [Float]) {
        let warpAmount = morphY

        switch warpMode {
        case .sync:
            applyHardSync(&real, &imag, amount: warpAmount)
        case .bend:
            applyBend(&real, &imag, amount: warpAmount, direction: 1)
        case .bendMinus:
            applyBend(&real, &imag, amount: warpAmount, direction: -1)
        case .pwm:
            applyPWM(&real, &imag, amount: warpAmount)
        case .asym:
            applyAsymmetry(&real, &imag, amount: warpAmount, direction: 1)
        case .asymMinus:
            applyAsymmetry(&real, &imag, amount: warpAmount, direction: -1)
        case .flip:
            applyFlip(&real, &imag, amount: warpAmount)
        case .mirror:
            applyMirror(&real, &imag, amount: warpAmount)
        case .quantize:
            applyQuantize(&real, &imag, amount: warpAmount)
        case .fm:
            applyFM(&real, &imag, amount: warpAmount)
        case .am:
            applyAM(&real, &imag, amount: warpAmount)
        case .rm:
            applyRM(&real, &imag, amount: warpAmount)
        case .spectralBlur:
            applySpectralBlur(&real, &imag, amount: warpAmount)
        case .spectralShift:
            applySpectralShift(&real, &imag, amount: warpAmount)
        case .harmonicStretch:
            applyHarmonicStretch(&real, &imag, amount: warpAmount)
        case .remap:
            applyRemap(&real, &imag, amount: warpAmount)
        }
    }

    private func applyHardSync(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Hard sync effect - adds harmonics
        let syncRatio = 1.0 + amount * 3.0
        for i in 1..<wavetableSize/2 {
            let newBin = Int(Float(i) * syncRatio) % (wavetableSize/2)
            if newBin < wavetableSize/2 && newBin > 0 {
                real[i] += real[newBin] * amount * 0.5
                imag[i] += imag[newBin] * amount * 0.5
            }
        }
    }

    private func applyBend(_ real: inout [Float], _ imag: inout [Float], amount: Float, direction: Int) {
        // Spectral bend - shifts harmonics
        let shift = Int(amount * 10) * direction
        var newReal = [Float](repeating: 0, count: wavetableSize)
        var newImag = [Float](repeating: 0, count: wavetableSize)

        for i in 0..<wavetableSize/2 {
            let newIndex = max(0, min(wavetableSize/2 - 1, i + shift))
            newReal[newIndex] = real[i]
            newImag[newIndex] = imag[i]
        }

        // Blend
        for i in 0..<wavetableSize {
            real[i] = real[i] * (1.0 - amount) + newReal[i] * amount
            imag[i] = imag[i] * (1.0 - amount) + newImag[i] * amount
        }
    }

    private func applyPWM(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Pulse width modulation effect
        let pulseWidth = 0.1 + amount * 0.8
        for i in 1..<wavetableSize/2 {
            let harmonic = Float(i)
            let pwmFactor = sin(.pi * harmonic * pulseWidth)
            real[i] *= pwmFactor
            imag[i] *= pwmFactor
        }
    }

    private func applyAsymmetry(_ real: inout [Float], _ imag: inout [Float], amount: Float, direction: Int) {
        // Add even harmonics for asymmetry
        for i in stride(from: 2, to: wavetableSize/2, by: 2) {
            real[i] += real[i/2] * amount * 0.3 * Float(direction)
            imag[i] += imag[i/2] * amount * 0.3 * Float(direction)
        }
    }

    private func applyFlip(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Flip spectrum around center
        for i in 0..<wavetableSize/4 {
            let j = wavetableSize/2 - 1 - i
            let blendedReal = real[i] * (1.0 - amount) + real[j] * amount
            let blendedImag = imag[i] * (1.0 - amount) + imag[j] * amount
            real[i] = blendedReal
            imag[i] = blendedImag
        }
    }

    private func applyMirror(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Mirror harmonics
        for i in 0..<wavetableSize/4 {
            let mirrorIndex = wavetableSize/2 - i
            if mirrorIndex < wavetableSize {
                real[mirrorIndex] = real[i] * amount
                imag[mirrorIndex] = -imag[i] * amount
            }
        }
    }

    private func applyQuantize(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Quantize harmonics to create digital artifacts
        let levels = max(2, Int((1.0 - amount) * 64))
        let step = 2.0 / Float(levels)

        for i in 0..<wavetableSize {
            real[i] = round(real[i] / step) * step
            imag[i] = round(imag[i] / step) * step
        }
    }

    private func applyFM(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // FM-style spectral spreading
        let fmIndex = amount * 5.0
        for i in 1..<wavetableSize/2 {
            let spread = Int(fmIndex * sin(Float(i) * 0.1))
            if i + spread > 0 && i + spread < wavetableSize/2 {
                real[i + spread] += real[i] * 0.3
                imag[i + spread] += imag[i] * 0.3
            }
        }
    }

    private func applyAM(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Amplitude modulation - creates sidebands
        let modFreq = 3 + Int(amount * 10)
        for i in modFreq..<wavetableSize/2 - modFreq {
            real[i - modFreq] += real[i] * amount * 0.5
            real[i + modFreq] += real[i] * amount * 0.5
        }
    }

    private func applyRM(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Ring modulation
        let modFreq = 5 + Int(amount * 20)
        for i in 0..<wavetableSize/2 {
            let modulation = sin(Float(i) / Float(modFreq) * .pi * 2)
            real[i] *= 1.0 + modulation * amount
            imag[i] *= 1.0 + modulation * amount
        }
    }

    private func applySpectralBlur(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Blur spectrum by averaging neighbors
        let blurRadius = max(1, Int(amount * 10))
        var blurredReal = real
        var blurredImag = imag

        for i in blurRadius..<wavetableSize - blurRadius {
            var sumReal: Float = 0
            var sumImag: Float = 0
            for j in -blurRadius...blurRadius {
                sumReal += real[i + j]
                sumImag += imag[i + j]
            }
            blurredReal[i] = sumReal / Float(blurRadius * 2 + 1)
            blurredImag[i] = sumImag / Float(blurRadius * 2 + 1)
        }

        for i in 0..<wavetableSize {
            real[i] = real[i] * (1.0 - amount) + blurredReal[i] * amount
            imag[i] = imag[i] * (1.0 - amount) + blurredImag[i] * amount
        }
    }

    private func applySpectralShift(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Shift all harmonics up or down
        let shift = Int((amount - 0.5) * 40)
        var newReal = [Float](repeating: 0, count: wavetableSize)
        var newImag = [Float](repeating: 0, count: wavetableSize)

        for i in 0..<wavetableSize/2 {
            let newIndex = i + shift
            if newIndex >= 0 && newIndex < wavetableSize/2 {
                newReal[newIndex] = real[i]
                newImag[newIndex] = imag[i]
            }
        }

        real = newReal
        imag = newImag
    }

    private func applyHarmonicStretch(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Stretch/compress harmonic series
        let stretchFactor = 0.5 + amount * 1.5
        var newReal = [Float](repeating: 0, count: wavetableSize)
        var newImag = [Float](repeating: 0, count: wavetableSize)

        for i in 1..<wavetableSize/2 {
            let newIndex = Int(Float(i) * stretchFactor)
            if newIndex > 0 && newIndex < wavetableSize/2 {
                newReal[newIndex] += real[i]
                newImag[newIndex] += imag[i]
            }
        }

        for i in 0..<wavetableSize {
            real[i] = real[i] * (1.0 - amount) + newReal[i] * amount
            imag[i] = imag[i] * (1.0 - amount) + newImag[i] * amount
        }
    }

    private func applyRemap(_ real: inout [Float], _ imag: inout [Float], amount: Float) {
        // Remap harmonic positions using a curve
        var newReal = [Float](repeating: 0, count: wavetableSize)
        var newImag = [Float](repeating: 0, count: wavetableSize)

        for i in 1..<wavetableSize/2 {
            let normalized = Float(i) / Float(wavetableSize/2)
            let curved = pow(normalized, 1.0 + amount * 2.0)
            let newIndex = Int(curved * Float(wavetableSize/2))
            if newIndex > 0 && newIndex < wavetableSize/2 {
                newReal[newIndex] = real[i]
                newImag[newIndex] = imag[i]
            }
        }

        real = newReal
        imag = newImag
    }

    // MARK: - Audio Generation

    /// Generate audio samples from current morphed wavetable
    public func generateSamples(count: Int, frequency: Float) -> [Float] {
        self.frequency = frequency
        var output = [Float](repeating: 0, count: count)
        let phaseIncrement = frequency / sampleRate

        for i in 0..<count {
            // Linear interpolation for smooth wavetable reading
            let tablePosition = phase * Float(wavetableSize)
            let index0 = Int(tablePosition) % wavetableSize
            let index1 = (index0 + 1) % wavetableSize
            let fraction = tablePosition - Float(index0)

            output[i] = currentWavetable[index0] * (1.0 - fraction) + currentWavetable[index1] * fraction

            phase += phaseIncrement
            if phase >= 1.0 {
                phase -= 1.0
            }
        }

        return output
    }

    // MARK: - Wavetable Import

    public func setWavetableA(_ wavetable: [Float]) {
        guard wavetable.count == wavetableSize else {
            print("⚠️ Wavetable size mismatch. Expected \(wavetableSize), got \(wavetable.count)")
            return
        }
        wavetableA = wavetable
        morph()
    }

    public func setWavetableB(_ wavetable: [Float]) {
        guard wavetable.count == wavetableSize else {
            print("⚠️ Wavetable size mismatch. Expected \(wavetableSize), got \(wavetable.count)")
            return
        }
        wavetableB = wavetable
        morph()
    }

    /// Import audio file as wavetable
    public func importAudioAsWavetable(url: URL, slot: Int) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(wavetableSize)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SpectralMorphingEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        try file.read(into: buffer, frameCount: frameCount)

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "SpectralMorphingEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "No channel data"])
        }

        var wavetable = [Float](repeating: 0, count: wavetableSize)
        for i in 0..<wavetableSize {
            wavetable[i] = channelData[0][i]
        }

        if slot == 0 {
            wavetableA = wavetable
        } else {
            wavetableB = wavetable
        }

        morph()
        print("✅ Imported audio as wavetable (slot \(slot))")
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: 3. ADVANCED HRTF ENGINE (THX Spatial Creator / DearVR Style)
// MARK: ═══════════════════════════════════════════════════════════════════════════════

/// Advanced Head-Related Transfer Function Engine for binaural 3D audio
/// Inspired by THX Spatial Creator and DearVR Pro
@MainActor
public final class AdvancedHRTFEngine: ObservableObject {

    // MARK: - Published State

    @Published public var isActive: Bool = false
    @Published public var headTrackingEnabled: Bool = false
    @Published public var roomSimulationEnabled: Bool = true
    @Published public var currentHRTFProfile: HRTFProfile = .neutral
    @Published public var roomType: RoomType = .studio
    @Published public var listenerPosition: SIMD3<Float> = .zero
    @Published public var listenerOrientation: SIMD3<Float> = SIMD3<Float>(0, 0, -1)  // Forward

    // MARK: - HRTF Data

    private var hrtfFiltersLeft: [[Float]] = []    // Azimuth x Elevation filters
    private var hrtfFiltersRight: [[Float]] = []
    private let hrtfFilterLength: Int = 128
    private let azimuthResolution: Int = 36        // 10-degree steps
    private let elevationResolution: Int = 18      // 10-degree steps

    // MARK: - Room Simulation

    private var earlyReflections: [Reflection] = []
    private var lateReverb: [Float] = []
    private let maxReflections: Int = 24

    // MARK: - Processing Buffers

    private var convolutionBufferLeft: [Float] = []
    private var convolutionBufferRight: [Float] = []

    // MARK: - HRTF Profiles

    public enum HRTFProfile: String, CaseIterable {
        case neutral = "Neutral (THX)"
        case small = "Small Head"
        case large = "Large Head"
        case inEar = "In-Ear Optimized"
        case overEar = "Over-Ear Optimized"
        case custom = "Custom"

        var headRadius: Float {
            switch self {
            case .neutral: return 0.0875     // 8.75 cm (average)
            case .small: return 0.080        // 8.0 cm
            case .large: return 0.095        // 9.5 cm
            case .inEar: return 0.0875
            case .overEar: return 0.0875
            case .custom: return 0.0875
            }
        }

        var earSpacing: Float {
            switch self {
            case .neutral: return 0.15       // 15 cm
            case .small: return 0.14
            case .large: return 0.16
            case .inEar: return 0.15
            case .overEar: return 0.15
            case .custom: return 0.15
            }
        }
    }

    // MARK: - Room Types

    public enum RoomType: String, CaseIterable {
        case anechoic = "Anechoic"
        case studio = "Studio"
        case livingRoom = "Living Room"
        case concert = "Concert Hall"
        case cathedral = "Cathedral"
        case outdoor = "Outdoor"

        var dimensions: SIMD3<Float> {
            switch self {
            case .anechoic: return SIMD3<Float>(0, 0, 0)
            case .studio: return SIMD3<Float>(6, 4, 3)
            case .livingRoom: return SIMD3<Float>(8, 5, 2.7)
            case .concert: return SIMD3<Float>(40, 25, 15)
            case .cathedral: return SIMD3<Float>(60, 30, 25)
            case .outdoor: return SIMD3<Float>(100, 100, 50)
            }
        }

        var rt60: Float {  // Reverb time in seconds
            switch self {
            case .anechoic: return 0.0
            case .studio: return 0.3
            case .livingRoom: return 0.5
            case .concert: return 1.8
            case .cathedral: return 4.0
            case .outdoor: return 0.1
            }
        }

        var absorptionCoefficient: Float {
            switch self {
            case .anechoic: return 1.0
            case .studio: return 0.7
            case .livingRoom: return 0.5
            case .concert: return 0.3
            case .cathedral: return 0.15
            case .outdoor: return 0.9
            }
        }
    }

    // MARK: - Reflection Structure

    struct Reflection {
        var delay: Float           // In samples
        var gain: Float            // Attenuation
        var direction: SIMD3<Float>  // Direction from listener
        var filterCoeffs: [Float]  // Air absorption filter
    }

    // MARK: - Initialization

    public init() {
        initializeHRTFFilters()
        print("✅ AdvancedHRTFEngine: Initialized with \(azimuthResolution * elevationResolution) HRTF positions")
    }

    private func initializeHRTFFilters() {
        // Generate simplified HRTF filters using spherical head model
        // In production, these would be loaded from measured HRTF databases (SOFA format)

        hrtfFiltersLeft = []
        hrtfFiltersRight = []

        for elevation in 0..<elevationResolution {
            let elevAngle = Float(elevation - elevationResolution/2) * 10.0 * .pi / 180.0

            for azimuth in 0..<azimuthResolution {
                let azAngle = Float(azimuth) * 10.0 * .pi / 180.0

                // Generate filter for this direction
                let (leftFilter, rightFilter) = generateHRTFPair(azimuth: azAngle, elevation: elevAngle)
                hrtfFiltersLeft.append(leftFilter)
                hrtfFiltersRight.append(rightFilter)
            }
        }

        // Initialize processing buffers
        convolutionBufferLeft = [Float](repeating: 0, count: hrtfFilterLength)
        convolutionBufferRight = [Float](repeating: 0, count: hrtfFilterLength)
    }

    // MARK: - HRTF Generation (Spherical Head Model)

    private func generateHRTFPair(azimuth: Float, elevation: Float) -> ([Float], [Float]) {
        let headRadius = currentHRTFProfile.headRadius
        let earSpacing = currentHRTFProfile.earSpacing

        // Calculate ITD (Interaural Time Difference) using Woodworth formula
        let speedOfSound: Float = 343.0
        let sampleRate: Float = 44100.0

        // Angle to each ear
        let leftAngle = azimuth + .pi / 2
        let rightAngle = azimuth - .pi / 2

        // Path difference
        let itd = headRadius / speedOfSound * (sin(leftAngle) + leftAngle)
        let itdSamples = itd * sampleRate

        // Generate minimum-phase impulse responses
        var leftFilter = [Float](repeating: 0, count: hrtfFilterLength)
        var rightFilter = [Float](repeating: 0, count: hrtfFilterLength)

        // Simple model: delay + head shadow (low-pass for contralateral ear)
        let leftDelay = max(0, Int(itdSamples))
        let rightDelay = max(0, Int(-itdSamples))

        // ILD (Interaural Level Difference) - simple head shadow model
        let shadowFreq: Float = 1500.0  // Frequency where shadowing begins
        let leftGain = azimuth < 0 ? 1.0 : Float(pow(10.0, -abs(azimuth) * 0.5))
        let rightGain = azimuth > 0 ? 1.0 : Float(pow(10.0, -abs(azimuth) * 0.5))

        // Create impulse responses
        if leftDelay < hrtfFilterLength {
            leftFilter[leftDelay] = leftGain
            // Add some spectral coloring
            for i in (leftDelay + 1)..<min(leftDelay + 10, hrtfFilterLength) {
                leftFilter[i] = leftGain * 0.1 * exp(-Float(i - leftDelay) * 0.5)
            }
        }

        if rightDelay < hrtfFilterLength {
            rightFilter[rightDelay] = rightGain
            for i in (rightDelay + 1)..<min(rightDelay + 10, hrtfFilterLength) {
                rightFilter[i] = rightGain * 0.1 * exp(-Float(i - rightDelay) * 0.5)
            }
        }

        // Apply elevation effect (pinna filtering simulation)
        applyPinnaEffect(&leftFilter, elevation: elevation)
        applyPinnaEffect(&rightFilter, elevation: elevation)

        return (leftFilter, rightFilter)
    }

    private func applyPinnaEffect(_ filter: inout [Float], elevation: Float) {
        // Simple pinna model: notch filter that moves with elevation
        // Real pinna filtering is much more complex
        let notchFreq = 8000.0 + Double(elevation) * 2000.0
        let sampleRate = 44100.0
        let normalizedFreq = notchFreq / sampleRate

        // Apply subtle notch (simplified)
        let notchIndex = Int(normalizedFreq * Double(hrtfFilterLength))
        if notchIndex > 0 && notchIndex < hrtfFilterLength - 1 {
            filter[notchIndex] *= 0.5
            filter[notchIndex - 1] *= 0.7
            filter[notchIndex + 1] *= 0.7
        }
    }

    // MARK: - Binaural Processing

    /// Process mono source to binaural stereo
    public func processToBinaural(monoInput: [Float], sourcePosition: SIMD3<Float>) -> (left: [Float], right: [Float]) {
        // Calculate direction from listener to source
        let direction = sourcePosition - listenerPosition
        let distance = simd_length(direction)
        let normalizedDirection = distance > 0 ? direction / distance : SIMD3<Float>(0, 0, -1)

        // Convert to spherical coordinates
        let azimuth = atan2(normalizedDirection.x, -normalizedDirection.z)
        let elevation = asin(normalizedDirection.y)

        // Get HRTF filter index
        let azimuthIndex = Int((azimuth / .pi + 1.0) * Float(azimuthResolution) / 2.0) % azimuthResolution
        let elevationIndex = max(0, min(elevationResolution - 1, Int((elevation / .pi + 0.5) * Float(elevationResolution))))
        let filterIndex = elevationIndex * azimuthResolution + azimuthIndex

        // Get filters
        let leftFilter = hrtfFiltersLeft[min(filterIndex, hrtfFiltersLeft.count - 1)]
        let rightFilter = hrtfFiltersRight[min(filterIndex, hrtfFiltersRight.count - 1)]

        // Distance attenuation (inverse square law)
        let distanceGain = 1.0 / max(1.0, distance)

        // Convolve input with HRTF filters
        var leftOutput = convolve(monoInput, with: leftFilter)
        var rightOutput = convolve(monoInput, with: rightFilter)

        // Apply distance attenuation
        vDSP_vsmul(leftOutput, 1, [distanceGain], &leftOutput, 1, vDSP_Length(leftOutput.count))
        vDSP_vsmul(rightOutput, 1, [distanceGain], &rightOutput, 1, vDSP_Length(rightOutput.count))

        // Add room simulation if enabled
        if roomSimulationEnabled && roomType != .anechoic {
            let (roomLeft, roomRight) = addRoomSimulation(monoInput, sourcePosition: sourcePosition)
            vDSP_vadd(leftOutput, 1, roomLeft, 1, &leftOutput, 1, vDSP_Length(leftOutput.count))
            vDSP_vadd(rightOutput, 1, roomRight, 1, &rightOutput, 1, vDSP_Length(rightOutput.count))
        }

        return (leftOutput, rightOutput)
    }

    private func convolve(_ input: [Float], with filter: [Float]) -> [Float] {
        let outputLength = input.count + filter.count - 1
        var output = [Float](repeating: 0, count: outputLength)

        vDSP_conv(input, 1, filter, 1, &output, 1, vDSP_Length(outputLength), vDSP_Length(filter.count))

        // Trim to input length
        return Array(output.prefix(input.count))
    }

    // MARK: - Room Simulation

    private func addRoomSimulation(_ input: [Float], sourcePosition: SIMD3<Float>) -> (left: [Float], right: [Float]) {
        let dimensions = roomType.dimensions
        let absorption = roomType.absorptionCoefficient
        let rt60 = roomType.rt60

        var leftOutput = [Float](repeating: 0, count: input.count)
        var rightOutput = [Float](repeating: 0, count: input.count)

        // Generate early reflections using image source method (simplified)
        let reflections = generateEarlyReflections(sourcePosition: sourcePosition, roomDimensions: dimensions)

        for reflection in reflections {
            // Process each reflection through HRTF
            let delayedInput = delaySignal(input, samples: Int(reflection.delay))
            let attenuatedInput = delayedInput.map { $0 * reflection.gain }

            let (refLeft, refRight) = processToBinauralSimple(attenuatedInput, direction: reflection.direction)

            vDSP_vadd(leftOutput, 1, refLeft, 1, &leftOutput, 1, vDSP_Length(leftOutput.count))
            vDSP_vadd(rightOutput, 1, refRight, 1, &rightOutput, 1, vDSP_Length(rightOutput.count))
        }

        // Add late reverb (simplified feedback delay network)
        if rt60 > 0.1 {
            let reverbGain = 0.3 * (1.0 - absorption)
            let (reverbLeft, reverbRight) = generateLateReverb(input, rt60: rt60, gain: reverbGain)

            vDSP_vadd(leftOutput, 1, reverbLeft, 1, &leftOutput, 1, vDSP_Length(leftOutput.count))
            vDSP_vadd(rightOutput, 1, reverbRight, 1, &rightOutput, 1, vDSP_Length(rightOutput.count))
        }

        return (leftOutput, rightOutput)
    }

    private func generateEarlyReflections(sourcePosition: SIMD3<Float>, roomDimensions: SIMD3<Float>) -> [Reflection] {
        guard roomDimensions.x > 0 else { return [] }

        var reflections: [Reflection] = []
        let sampleRate: Float = 44100.0
        let speedOfSound: Float = 343.0

        // First-order reflections (6 walls)
        let walls: [(normal: SIMD3<Float>, distance: Float)] = [
            (SIMD3<Float>(1, 0, 0), roomDimensions.x / 2),    // Right wall
            (SIMD3<Float>(-1, 0, 0), roomDimensions.x / 2),   // Left wall
            (SIMD3<Float>(0, 1, 0), roomDimensions.y / 2),    // Ceiling
            (SIMD3<Float>(0, -1, 0), roomDimensions.y / 2),   // Floor
            (SIMD3<Float>(0, 0, 1), roomDimensions.z / 2),    // Front wall
            (SIMD3<Float>(0, 0, -1), roomDimensions.z / 2)    // Back wall
        ]

        for (normal, wallDistance) in walls {
            // Image source position
            let imageSource = sourcePosition - 2.0 * simd_dot(sourcePosition - listenerPosition, normal) * normal
            let pathLength = simd_length(imageSource - listenerPosition)
            let delaySamples = pathLength / speedOfSound * sampleRate
            let gain = roomType.absorptionCoefficient / max(1.0, pathLength)

            let direction = simd_normalize(imageSource - listenerPosition)

            reflections.append(Reflection(
                delay: delaySamples,
                gain: gain,
                direction: direction,
                filterCoeffs: []
            ))
        }

        return reflections
    }

    private func processToBinauralSimple(_ input: [Float], direction: SIMD3<Float>) -> ([Float], [Float]) {
        // Simplified binaural processing for reflections
        let azimuth = atan2(direction.x, -direction.z)

        // Simple panning based on azimuth
        let leftGain = cos((azimuth + .pi/2) / 2)
        let rightGain = cos((azimuth - .pi/2) / 2)

        var leftOutput = input.map { $0 * leftGain }
        var rightOutput = input.map { $0 * rightGain }

        return (leftOutput, rightOutput)
    }

    private func delaySignal(_ input: [Float], samples: Int) -> [Float] {
        guard samples > 0 && samples < input.count else { return input }

        var output = [Float](repeating: 0, count: input.count)
        for i in samples..<input.count {
            output[i] = input[i - samples]
        }
        return output
    }

    private func generateLateReverb(_ input: [Float], rt60: Float, gain: Float) -> ([Float], [Float]) {
        // Simplified late reverb using allpass filters
        let sampleRate: Float = 44100.0
        let decaySamples = Int(rt60 * sampleRate)

        var leftOutput = [Float](repeating: 0, count: input.count)
        var rightOutput = [Float](repeating: 0, count: input.count)

        // Multiple delay lines with different lengths
        let delayLengths = [1557, 1617, 1491, 1422, 1277, 1356]  // Prime-ish numbers for diffusion
        let feedbackGain = pow(10.0, -3.0 / rt60 / sampleRate)  // -60dB at RT60

        for (index, delayLength) in delayLengths.enumerated() {
            let isLeft = index % 2 == 0
            var buffer = [Float](repeating: 0, count: delayLength)
            var writeIndex = 0

            for i in 0..<input.count {
                let readIndex = (writeIndex - delayLength + buffer.count) % buffer.count
                let delayed = buffer[readIndex]
                let newSample = input[i] + delayed * Float(feedbackGain) * gain
                buffer[writeIndex] = newSample

                if isLeft {
                    leftOutput[i] += delayed * gain / Float(delayLengths.count)
                } else {
                    rightOutput[i] += delayed * gain / Float(delayLengths.count)
                }

                writeIndex = (writeIndex + 1) % buffer.count
            }
        }

        return (leftOutput, rightOutput)
    }

    // MARK: - Head Tracking Integration

    public func updateHeadOrientation(yaw: Float, pitch: Float, roll: Float) {
        guard headTrackingEnabled else { return }

        // Convert Euler angles to direction vector
        let yawRad = yaw * .pi / 180.0
        let pitchRad = pitch * .pi / 180.0

        listenerOrientation = SIMD3<Float>(
            sin(yawRad) * cos(pitchRad),
            sin(pitchRad),
            -cos(yawRad) * cos(pitchRad)
        )
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: 4. SMART SAMPLE PROCESSOR (Sample 3 Style)
// MARK: ═══════════════════════════════════════════════════════════════════════════════

/// AI-powered sample processing with smart chopping and time-stretching
/// Inspired by Sample 3 and similar modern samplers
@MainActor
public final class SmartSampleProcessor: ObservableObject {

    // MARK: - Published State

    @Published public var isProcessing: Bool = false
    @Published public var detectedTransients: [TransientMarker] = []
    @Published public var detectedTempo: Double = 120.0
    @Published public var slices: [SampleSlice] = []

    // MARK: - Sample Data

    private var sampleData: [Float] = []
    private var sampleRate: Float = 44100.0

    // MARK: - Transient Detection Parameters

    @Published public var transientSensitivity: Float = 0.5
    @Published public var minSliceLength: Float = 0.05  // 50ms minimum

    // MARK: - Structures

    public struct TransientMarker: Identifiable {
        public let id = UUID()
        public var position: Int       // Sample position
        public var strength: Float     // Transient strength 0-1
        public var type: TransientType

        public enum TransientType {
            case percussive
            case melodic
            case mixed
        }
    }

    public struct SampleSlice: Identifiable {
        public let id = UUID()
        public var startSample: Int
        public var endSample: Int
        public var data: [Float]
        public var pitch: Float?       // Detected pitch if melodic
        public var isPercussive: Bool
    }

    // MARK: - Initialization

    public init() {
        print("✅ SmartSampleProcessor: Initialized")
    }

    // MARK: - Sample Loading

    public func loadSample(_ data: [Float], sampleRate: Float) {
        self.sampleData = data
        self.sampleRate = sampleRate
        print("📁 Loaded sample: \(data.count) samples @ \(sampleRate) Hz")
    }

    public func loadFromURL(_ url: URL) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SmartSampleProcessor", code: -1)
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "SmartSampleProcessor", code: -2)
        }

        sampleData = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        sampleRate = Float(format.sampleRate)

        print("📁 Loaded: \(url.lastPathComponent) (\(sampleData.count) samples)")
    }

    // MARK: - Smart Transient Detection

    public func detectTransients() async -> [TransientMarker] {
        isProcessing = true
        defer { isProcessing = false }

        guard !sampleData.isEmpty else { return [] }

        var markers: [TransientMarker] = []

        // Calculate energy envelope
        let windowSize = Int(sampleRate * 0.01)  // 10ms windows
        let hopSize = windowSize / 4

        var envelope: [Float] = []
        var spectralFlux: [Float] = []

        // Energy envelope
        for i in stride(from: 0, to: sampleData.count - windowSize, by: hopSize) {
            let window = Array(sampleData[i..<(i + windowSize)])
            var energy: Float = 0
            vDSP_svesq(window, 1, &energy, vDSP_Length(windowSize))
            envelope.append(sqrt(energy / Float(windowSize)))
        }

        // Onset detection function (first-order difference of energy)
        var onsetFunction: [Float] = []
        for i in 1..<envelope.count {
            let diff = max(0, envelope[i] - envelope[i-1])
            onsetFunction.append(diff)
        }

        // Adaptive thresholding
        let medianWindowSize = 10
        let threshold = transientSensitivity * 0.5

        for i in medianWindowSize..<(onsetFunction.count - medianWindowSize) {
            let localWindow = Array(onsetFunction[(i - medianWindowSize)..<(i + medianWindowSize)])
            let localMean = localWindow.reduce(0, +) / Float(localWindow.count)
            let localMax = localWindow.max() ?? 0

            if onsetFunction[i] > localMean + threshold * (localMax - localMean) {
                // Found a transient
                let samplePosition = i * hopSize
                let strength = min(1.0, onsetFunction[i] / localMax)

                // Classify transient type based on spectral content
                let type = classifyTransient(at: samplePosition)

                markers.append(TransientMarker(
                    position: samplePosition,
                    strength: strength,
                    type: type
                ))
            }
        }

        // Remove duplicates within minimum slice length
        let minSamples = Int(minSliceLength * sampleRate)
        var filteredMarkers: [TransientMarker] = []

        for marker in markers {
            if let last = filteredMarkers.last {
                if marker.position - last.position > minSamples {
                    filteredMarkers.append(marker)
                } else if marker.strength > last.strength {
                    filteredMarkers[filteredMarkers.count - 1] = marker
                }
            } else {
                filteredMarkers.append(marker)
            }
        }

        detectedTransients = filteredMarkers
        print("🎯 Detected \(filteredMarkers.count) transients")
        return filteredMarkers
    }

    private func classifyTransient(at position: Int) -> TransientMarker.TransientType {
        // Analyze spectral content around transient
        let windowSize = min(2048, sampleData.count - position)
        guard position + windowSize <= sampleData.count else { return .mixed }

        let window = Array(sampleData[position..<(position + windowSize)])

        // Calculate spectral centroid
        var magnitudes = [Float](repeating: 0, count: windowSize/2)

        // Simple DFT magnitude calculation
        for k in 0..<windowSize/2 {
            var realSum: Float = 0
            var imagSum: Float = 0
            for n in 0..<windowSize {
                let angle = -2.0 * .pi * Float(k * n) / Float(windowSize)
                realSum += window[n] * cos(angle)
                imagSum += window[n] * sin(angle)
            }
            magnitudes[k] = sqrt(realSum * realSum + imagSum * imagSum)
        }

        // Spectral centroid
        var weightedSum: Float = 0
        var totalMag: Float = 0
        for k in 0..<magnitudes.count {
            weightedSum += Float(k) * magnitudes[k]
            totalMag += magnitudes[k]
        }

        let centroid = totalMag > 0 ? weightedSum / totalMag : 0
        let centroidHz = centroid * sampleRate / Float(windowSize)

        // Classify based on centroid
        if centroidHz > 4000 {
            return .percussive
        } else if centroidHz < 1000 {
            return .melodic
        } else {
            return .mixed
        }
    }

    // MARK: - Smart Chopping

    public func smartChop() async -> [SampleSlice] {
        isProcessing = true
        defer { isProcessing = false }

        // Detect transients if not already done
        if detectedTransients.isEmpty {
            _ = await detectTransients()
        }

        var newSlices: [SampleSlice] = []

        // Create slices between transients
        var startPosition = 0

        for (index, marker) in detectedTransients.enumerated() {
            if index == 0 && marker.position > 0 {
                // First slice before first transient (if any)
                let sliceData = Array(sampleData[0..<marker.position])
                if sliceData.count > Int(minSliceLength * sampleRate) {
                    newSlices.append(SampleSlice(
                        startSample: 0,
                        endSample: marker.position,
                        data: sliceData,
                        pitch: nil,
                        isPercussive: false
                    ))
                }
            }

            startPosition = marker.position
            let endPosition: Int

            if index < detectedTransients.count - 1 {
                endPosition = detectedTransients[index + 1].position
            } else {
                endPosition = sampleData.count
            }

            let sliceData = Array(sampleData[startPosition..<endPosition])

            // Detect pitch for melodic content
            var detectedPitch: Float? = nil
            if marker.type == .melodic || marker.type == .mixed {
                detectedPitch = detectPitch(in: sliceData)
            }

            newSlices.append(SampleSlice(
                startSample: startPosition,
                endSample: endPosition,
                data: sliceData,
                pitch: detectedPitch,
                isPercussive: marker.type == .percussive
            ))
        }

        slices = newSlices
        print("✂️ Created \(newSlices.count) slices")
        return newSlices
    }

    // MARK: - Pitch Detection (Autocorrelation)

    private func detectPitch(in data: [Float]) -> Float? {
        guard data.count > 256 else { return nil }

        let analysisSize = min(4096, data.count)
        let analysisData = Array(data.prefix(analysisSize))

        // Autocorrelation
        var correlation = [Float](repeating: 0, count: analysisSize)
        vDSP_conv(analysisData, 1, analysisData, 1, &correlation, 1, vDSP_Length(analysisSize), vDSP_Length(analysisSize))

        // Find first peak after lag 0
        let minLag = Int(sampleRate / 1000)  // Max 1000 Hz
        let maxLag = Int(sampleRate / 50)    // Min 50 Hz

        var maxCorr: Float = 0
        var maxLag = minLag

        for lag in minLag..<min(maxLag, correlation.count) {
            if correlation[lag] > maxCorr {
                maxCorr = correlation[lag]
                maxLag = lag
            }
        }

        // Convert lag to frequency
        let pitch = sampleRate / Float(maxLag)

        // Validate pitch range (50-1000 Hz)
        if pitch >= 50 && pitch <= 1000 && maxCorr > correlation[0] * 0.5 {
            return pitch
        }

        return nil
    }

    // MARK: - Time Stretching (WSOLA-based)

    public func timeStretch(_ data: [Float], ratio: Float) -> [Float] {
        guard ratio > 0 && ratio != 1.0 else { return data }

        let outputLength = Int(Float(data.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)

        let windowSize = 1024
        let hopSizeIn = windowSize / 4
        let hopSizeOut = Int(Float(hopSizeIn) * ratio)

        // WSOLA: Waveform Similarity Overlap-Add
        var inputPosition = 0
        var outputPosition = 0

        // Hann window
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        while outputPosition + windowSize < outputLength && inputPosition + windowSize < data.count {
            // Extract and window grain
            var grain = [Float](repeating: 0, count: windowSize)
            for i in 0..<windowSize {
                let idx = inputPosition + i
                if idx < data.count {
                    grain[i] = data[idx] * window[i]
                }
            }

            // Overlap-add to output
            for i in 0..<windowSize {
                let idx = outputPosition + i
                if idx < outputLength {
                    output[idx] += grain[i]
                }
            }

            inputPosition += hopSizeIn
            outputPosition += hopSizeOut
        }

        // Normalize
        var maxVal: Float = 0
        vDSP_maxv(output, 1, &maxVal, vDSP_Length(outputLength))
        if maxVal > 0 {
            var scale = 0.9 / maxVal
            vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(outputLength))
        }

        return output
    }

    // MARK: - Pitch Shifting

    public func pitchShift(_ data: [Float], semitones: Float) -> [Float] {
        // Pitch shift using time stretch + resample
        let ratio = pow(2.0, semitones / 12.0)

        // Time stretch to change pitch without changing duration
        let stretched = timeStretch(data, ratio: ratio)

        // Resample back to original length
        let targetLength = data.count
        var output = [Float](repeating: 0, count: targetLength)

        for i in 0..<targetLength {
            let srcPosition = Float(i) * Float(stretched.count) / Float(targetLength)
            let srcIndex = Int(srcPosition)
            let fraction = srcPosition - Float(srcIndex)

            if srcIndex < stretched.count - 1 {
                output[i] = stretched[srcIndex] * (1.0 - fraction) + stretched[srcIndex + 1] * fraction
            } else if srcIndex < stretched.count {
                output[i] = stretched[srcIndex]
            }
        }

        return output
    }

    // MARK: - Tempo Detection

    public func detectTempo() async -> Double {
        isProcessing = true
        defer { isProcessing = false }

        guard !sampleData.isEmpty else { return 120.0 }

        // Onset detection for tempo
        let windowSize = Int(sampleRate * 0.01)
        let hopSize = windowSize / 2

        var onsets: [Float] = []

        for i in stride(from: windowSize, to: sampleData.count - windowSize, by: hopSize) {
            let current = Array(sampleData[i..<(i + windowSize)])
            let previous = Array(sampleData[(i - windowSize)..<i])

            var currentEnergy: Float = 0
            var previousEnergy: Float = 0
            vDSP_svesq(current, 1, &currentEnergy, vDSP_Length(windowSize))
            vDSP_svesq(previous, 1, &previousEnergy, vDSP_Length(windowSize))

            let onset = max(0, currentEnergy - previousEnergy)
            onsets.append(onset)
        }

        // Autocorrelation of onset function
        let correlationLength = min(onsets.count, Int(4.0 * sampleRate / Float(hopSize)))  // Up to 4 seconds
        var correlation = [Float](repeating: 0, count: correlationLength)

        for lag in 0..<correlationLength {
            var sum: Float = 0
            for i in 0..<(onsets.count - lag) {
                sum += onsets[i] * onsets[i + lag]
            }
            correlation[lag] = sum
        }

        // Find peaks in tempo range (60-200 BPM)
        let minLag = Int(60.0 / 200.0 * sampleRate / Float(hopSize))
        let maxLag = Int(60.0 / 60.0 * sampleRate / Float(hopSize))

        var maxCorr: Float = 0
        var bestLag = minLag

        for lag in minLag..<min(maxLag, correlationLength) {
            if correlation[lag] > maxCorr {
                maxCorr = correlation[lag]
                bestLag = lag
            }
        }

        // Convert lag to BPM
        let tempo = 60.0 / (Double(bestLag) * Double(hopSize) / Double(sampleRate))

        detectedTempo = tempo
        print("🎵 Detected tempo: \(Int(tempo)) BPM")
        return tempo
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: 5. UNIFIED MODERN PLUGIN HUB
// MARK: ═══════════════════════════════════════════════════════════════════════════════

/// Central hub integrating all modern plugin features
/// with Echoelmusic's bio-reactive capabilities
@MainActor
public final class ModernPluginHub: ObservableObject {

    // MARK: - Engines

    @Published public var midiGenerator = SpawnStyleMIDIGenerator()
    @Published public var spectralEngine = SpectralMorphingEngine()
    @Published public var hrtfEngine = AdvancedHRTFEngine()
    @Published public var sampleProcessor = SmartSampleProcessor()

    // MARK: - Bio Integration

    @Published public var bioIntegrationEnabled: Bool = true

    // MARK: - Initialization

    public init() {
        print("═══════════════════════════════════════════════════════════════")
        print("  MODERN PLUGIN HUB 2025")
        print("  Inspired by: Spawn, Serum 2, THX Spatial, Sample 3")
        print("  Enhanced with: Echoelmusic Bio-Reactive Technology")
        print("═══════════════════════════════════════════════════════════════")
    }

    // MARK: - Bio-Reactive Updates

    public func updateBioMetrics(hrv: Float, coherence: Float, heartRate: Float) {
        guard bioIntegrationEnabled else { return }

        // Update MIDI generator for bio-reactive composition
        midiGenerator.updateBioData(hrv: hrv, coherence: coherence, heartRate: heartRate)

        // Adapt spectral morphing based on coherence
        spectralEngine.morphY = coherence

        // Adjust spatial processing based on HRV
        let spatialWidth = hrv / 100.0  // Higher HRV = wider spatial field
        hrtfEngine.roomSimulationEnabled = coherence > 0.5
    }

    // MARK: - Quick Actions

    /// Generate a full bio-reactive musical phrase
    public func generateBioReactivePhrase(bars: Int = 4) async -> MIDIArrangement {
        return await midiGenerator.generateFullArrangement(
            bars: bars,
            genre: .bioReactive
        )
    }

    /// Process audio through spectral morphing
    public func processSpectralMorph(input: [Float], morphX: Float, morphY: Float, warpMode: SpectralMorphingEngine.WarpMode) -> [Float] {
        spectralEngine.morphX = morphX
        spectralEngine.morphY = morphY
        spectralEngine.warpMode = warpMode
        spectralEngine.morph()
        return spectralEngine.generateSamples(count: input.count, frequency: 440.0)
    }

    /// Spatialize mono audio to binaural
    public func spatializeToBinaural(mono: [Float], position: SIMD3<Float>) -> (left: [Float], right: [Float]) {
        return hrtfEngine.processToBinaural(monoInput: mono, sourcePosition: position)
    }

    /// Smart chop a sample
    public func smartChopSample(_ url: URL) async throws -> [SmartSampleProcessor.SampleSlice] {
        try await sampleProcessor.loadFromURL(url)
        return await sampleProcessor.smartChop()
    }
}
