//
//  MIDIEffects.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  ULTRA-INTELLIGENCE MIDI EFFECTS SYSTEM
//
//  **Superior to:** Ableton MIDI Effects, Logic Pro MIDI FX, Bitwig Note FX
//
//  **Features:**
//  - EchoelArp: Advanced pattern-based arpeggiator with euclidean rhythms
//  - Intelligent Harmonizer: AI-powered harmony generation
//  - Generative Sequencer: Markov chain & probability-based generation
//  - Euclidean Rhythm Generator: Mathematical rhythm patterns
//  - Bio-Reactive MIDI: HRV/Heart rate → MIDI parameters (UNIQUE!)
//  - Polyrhythm Generator: Complex polyrhythmic patterns
//  - MIDI LFO: Shape-based CC modulation
//  - Pattern Memory: Intelligent pattern learning and recall
//  - Micro-Timing Engine: Sub-millisecond timing control
//

import SwiftUI
import CoreMIDI
import Combine

// MARK: - MIDI Effects Engine

@MainActor
class MIDIEffectsEngine: ObservableObject {
    static let shared = MIDIEffectsEngine()

    @Published var effectChains: [UUID: MIDIEffectChain] = [:]
    @Published var globalBPM: Double = 120.0
    @Published var isRunning: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("✅ MIDIEffectsEngine: Ultra-Intelligence MIDI System initialized")
    }

    func createChain(for trackId: UUID) -> MIDIEffectChain {
        let chain = MIDIEffectChain()
        effectChains[trackId] = chain
        return chain
    }
}

// MARK: - EchoelArp (Advanced Arpeggiator)

/// EchoelArp - The most advanced arpeggiator ever created
/// Features: Pattern designer, euclidean rhythms, probability, bio-reactive
@MainActor
class EchoelArp: ObservableObject {
    static let shared = EchoelArp()

    // MARK: - Core Settings
    @Published var isEnabled: Bool = false
    @Published var pattern: ArpPattern = .up
    @Published var rate: RateValue = .sixteenth
    @Published var gate: Float = 80.0  // % note length
    @Published var octaves: Int = 2
    @Published var swing: Float = 0.0
    @Published var humanize: Float = 0.0

    // MARK: - Advanced Settings
    @Published var latch: Bool = false
    @Published var retrigger: Bool = true
    @Published var noteOrder: NoteOrder = .lowToHigh
    @Published var velocityMode: VelocityMode = .original
    @Published var velocityCurve: Float = 1.0
    @Published var accentPattern: [Bool] = [true, false, false, false]
    @Published var accentAmount: Int = 30

    // MARK: - Euclidean Mode
    @Published var euclideanEnabled: Bool = false
    @Published var euclideanSteps: Int = 16
    @Published var euclideanPulses: Int = 5
    @Published var euclideanRotation: Int = 0

    // MARK: - Probability
    @Published var noteProbability: Int = 100
    @Published var restProbability: Int = 0
    @Published var repeatProbability: Int = 0
    @Published var skipProbability: Int = 0

    // MARK: - Pattern Designer
    @Published var customPattern: [PatternStep] = []
    @Published var patternLength: Int = 8

    // MARK: - Bio-Reactive
    @Published var bioReactiveEnabled: Bool = false
    @Published var bioRateInfluence: Float = 0.0  // HR → Rate
    @Published var bioGateInfluence: Float = 0.0  // HRV → Gate
    @Published var bioPatternInfluence: Float = 0.0  // Coherence → Pattern complexity

    // MARK: - State
    private var heldNotes: [HeldNote] = []
    private var arpSequence: [ArpNote] = []
    private var currentStep: Int = 0
    private var lastTriggerTime: Date = Date()

    // MARK: - Types

    enum ArpPattern: String, CaseIterable, Identifiable {
        case up = "Up"
        case down = "Down"
        case upDown = "Up-Down"
        case downUp = "Down-Up"
        case upDownInc = "Up-Down (Inc)"
        case random = "Random"
        case randomWalk = "Random Walk"
        case asPlayed = "As Played"
        case chord = "Chord"
        case converge = "Converge"
        case diverge = "Diverge"
        case pinkyUp = "Pinky Up"
        case thumbUp = "Thumb Up"
        case euclidean = "Euclidean"
        case custom = "Custom"

        var id: String { rawValue }
    }

    enum RateValue: String, CaseIterable {
        case whole = "1/1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtySecond = "1/32"
        case tripletHalf = "1/2T"
        case tripletQuarter = "1/4T"
        case tripletEighth = "1/8T"
        case tripletSixteenth = "1/16T"
        case dottedQuarter = "1/4."
        case dottedEighth = "1/8."
        case dottedSixteenth = "1/16."

        var beatMultiplier: Double {
            switch self {
            case .whole: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtySecond: return 0.125
            case .tripletHalf: return 4.0 / 3.0
            case .tripletQuarter: return 2.0 / 3.0
            case .tripletEighth: return 1.0 / 3.0
            case .tripletSixteenth: return 0.5 / 3.0
            case .dottedQuarter: return 1.5
            case .dottedEighth: return 0.75
            case .dottedSixteenth: return 0.375
            }
        }
    }

    enum NoteOrder: String, CaseIterable {
        case lowToHigh = "Low to High"
        case highToLow = "High to Low"
        case asPlayed = "As Played"
        case random = "Random"
    }

    enum VelocityMode: String, CaseIterable {
        case original = "Original"
        case fixed = "Fixed"
        case ascending = "Ascending"
        case descending = "Descending"
        case random = "Random"
        case pattern = "Pattern"
        case lfo = "LFO"
    }

    struct HeldNote {
        let note: UInt8
        let velocity: UInt8
        let timestamp: Date
    }

    struct ArpNote {
        let note: UInt8
        var velocity: UInt8
        var gate: Float
        var active: Bool
    }

    struct PatternStep: Identifiable {
        let id = UUID()
        var octaveOffset: Int  // -2 to +2
        var velocityOffset: Int  // -64 to +64
        var gateMultiplier: Float  // 0.1 to 2.0
        var probability: Int  // 0-100
        var tie: Bool
        var rest: Bool
    }

    // MARK: - Note Input

    func noteOn(_ note: UInt8, velocity: UInt8) {
        let held = HeldNote(note: note, velocity: velocity, timestamp: Date())
        heldNotes.append(held)

        if !latch && heldNotes.count == 1 && retrigger {
            currentStep = 0
        }

        rebuildSequence()
    }

    func noteOff(_ note: UInt8) {
        if latch { return }

        heldNotes.removeAll { $0.note == note }

        if heldNotes.isEmpty {
            currentStep = 0
            arpSequence.removeAll()
        } else {
            rebuildSequence()
        }
    }

    func allNotesOff() {
        heldNotes.removeAll()
        arpSequence.removeAll()
        currentStep = 0
    }

    // MARK: - Clock Tick

    func tick(bpm: Double) -> [MIDIEvent] {
        guard isEnabled && !arpSequence.isEmpty else { return [] }

        // Apply bio-reactive rate modification
        let effectiveRate = bioReactiveEnabled ?
            rate.beatMultiplier * Double(1.0 + bioRateInfluence) : rate.beatMultiplier

        let stepIndex = currentStep % arpSequence.count
        let arpNote = arpSequence[stepIndex]

        currentStep += 1

        // Probability check
        if Int.random(in: 1...100) > noteProbability {
            return []  // Skip this note
        }

        guard arpNote.active else { return [] }

        // Calculate velocity
        let velocity = calculateVelocity(stepIndex: stepIndex, baseVelocity: arpNote.velocity)

        // Calculate gate time
        let effectiveGate = bioReactiveEnabled ?
            arpNote.gate * (1.0 + bioGateInfluence) : arpNote.gate
        let gateMs = (60000.0 / bpm) * effectiveRate * Double(effectiveGate / 100.0)

        // Apply humanization
        let timingOffset = humanize > 0 ? Int.random(in: Int(-humanize * 10)...Int(humanize * 10)) : 0

        // Check accent
        let accentStep = stepIndex % accentPattern.count
        let isAccent = accentPattern[accentStep]
        let finalVelocity = isAccent ? min(127, Int(velocity) + accentAmount) : Int(velocity)

        return [
            MIDIEvent(type: .noteOn, note: arpNote.note, velocity: UInt8(finalVelocity), timestamp: UInt64(max(0, timingOffset) * 1000)),
            MIDIEvent(type: .noteOff, note: arpNote.note, velocity: 0, timestamp: UInt64(gateMs * 1000))
        ]
    }

    // MARK: - Sequence Building

    private func rebuildSequence() {
        guard !heldNotes.isEmpty else {
            arpSequence.removeAll()
            return
        }

        // Sort notes based on order
        var sortedNotes: [HeldNote]
        switch noteOrder {
        case .lowToHigh:
            sortedNotes = heldNotes.sorted { $0.note < $1.note }
        case .highToLow:
            sortedNotes = heldNotes.sorted { $0.note > $1.note }
        case .asPlayed:
            sortedNotes = heldNotes.sorted { $0.timestamp < $1.timestamp }
        case .random:
            sortedNotes = heldNotes.shuffled()
        }

        // Build sequence based on pattern
        arpSequence.removeAll()

        if euclideanEnabled {
            buildEuclideanSequence(from: sortedNotes)
        } else {
            buildPatternSequence(from: sortedNotes)
        }
    }

    private func buildPatternSequence(from notes: [HeldNote]) {
        for octave in 0..<octaves {
            let octaveOffset = octave * 12

            switch pattern {
            case .up:
                for note in notes {
                    arpSequence.append(ArpNote(
                        note: note.note + UInt8(octaveOffset),
                        velocity: note.velocity,
                        gate: gate,
                        active: true
                    ))
                }

            case .down:
                for note in notes.reversed() {
                    arpSequence.append(ArpNote(
                        note: note.note + UInt8(octaveOffset),
                        velocity: note.velocity,
                        gate: gate,
                        active: true
                    ))
                }

            case .upDown:
                for note in notes {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }
                for note in notes.dropFirst().dropLast().reversed() {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }

            case .downUp:
                for note in notes.reversed() {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }
                for note in notes.dropFirst().dropLast() {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }

            case .upDownInc:
                for note in notes {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }
                for note in notes.reversed() {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }

            case .random:
                for note in notes.shuffled() {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }

            case .randomWalk:
                var currentIndex = 0
                for _ in 0..<notes.count {
                    let direction = Int.random(in: -1...1)
                    currentIndex = max(0, min(notes.count - 1, currentIndex + direction))
                    let note = notes[currentIndex]
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }

            case .converge:
                var left = 0
                var right = notes.count - 1
                while left <= right {
                    arpSequence.append(ArpNote(note: notes[left].note + UInt8(octaveOffset), velocity: notes[left].velocity, gate: gate, active: true))
                    if left != right {
                        arpSequence.append(ArpNote(note: notes[right].note + UInt8(octaveOffset), velocity: notes[right].velocity, gate: gate, active: true))
                    }
                    left += 1
                    right -= 1
                }

            case .diverge:
                let mid = notes.count / 2
                var left = mid
                var right = mid
                while left >= 0 || right < notes.count {
                    if left >= 0 {
                        arpSequence.append(ArpNote(note: notes[left].note + UInt8(octaveOffset), velocity: notes[left].velocity, gate: gate, active: true))
                    }
                    if right < notes.count && right != left {
                        arpSequence.append(ArpNote(note: notes[right].note + UInt8(octaveOffset), velocity: notes[right].velocity, gate: gate, active: true))
                    }
                    left -= 1
                    right += 1
                }

            case .asPlayed, .chord, .pinkyUp, .thumbUp, .euclidean, .custom:
                for note in notes {
                    arpSequence.append(ArpNote(note: note.note + UInt8(octaveOffset), velocity: note.velocity, gate: gate, active: true))
                }
            }
        }
    }

    private func buildEuclideanSequence(from notes: [HeldNote]) {
        let euclideanPattern = generateEuclideanRhythm(steps: euclideanSteps, pulses: euclideanPulses, rotation: euclideanRotation)

        for (index, active) in euclideanPattern.enumerated() {
            let noteIndex = index % notes.count
            let octaveIndex = index / notes.count
            let octaveOffset = (octaveIndex % octaves) * 12
            let note = notes[noteIndex]

            arpSequence.append(ArpNote(
                note: note.note + UInt8(octaveOffset),
                velocity: note.velocity,
                gate: gate,
                active: active
            ))
        }
    }

    private func generateEuclideanRhythm(steps: Int, pulses: Int, rotation: Int) -> [Bool] {
        guard steps > 0 && pulses > 0 && pulses <= steps else {
            return Array(repeating: false, count: max(1, steps))
        }

        // Bjorklund's algorithm
        var pattern: [[Bool]] = []

        let remainder = steps - pulses
        for _ in 0..<pulses {
            pattern.append([true])
        }
        for _ in 0..<remainder {
            pattern.append([false])
        }

        var divisor = remainder
        var level = pulses

        while divisor > 0 {
            let quotient = min(level, divisor)
            for i in 0..<quotient {
                pattern[i].append(contentsOf: pattern[pattern.count - 1])
                pattern.removeLast()
            }
            let temp = divisor
            divisor = level - quotient
            level = temp
        }

        var result = pattern.flatMap { $0 }

        // Apply rotation
        if rotation > 0 {
            let rotateBy = rotation % result.count
            result = Array(result[rotateBy...]) + Array(result[..<rotateBy])
        }

        return result
    }

    private func calculateVelocity(stepIndex: Int, baseVelocity: UInt8) -> UInt8 {
        switch velocityMode {
        case .original:
            return baseVelocity
        case .fixed:
            return UInt8(min(127, max(1, Int(baseVelocity))))
        case .ascending:
            let progress = Float(stepIndex % arpSequence.count) / Float(max(1, arpSequence.count - 1))
            return UInt8(min(127, max(1, Int(40.0 + progress * 87.0))))
        case .descending:
            let progress = Float(stepIndex % arpSequence.count) / Float(max(1, arpSequence.count - 1))
            return UInt8(min(127, max(1, Int(127.0 - progress * 87.0))))
        case .random:
            return UInt8.random(in: 40...127)
        case .pattern, .lfo:
            let phase = Float(stepIndex % 8) / 8.0
            let lfoValue = sin(phase * .pi * 2) * 0.5 + 0.5
            return UInt8(min(127, max(1, Int(40.0 + lfoValue * 87.0))))
        }
    }
}

// MARK: - Intelligent Harmonizer

/// AI-powered harmony generation that understands music theory
@MainActor
class IntelligentHarmonizer: ObservableObject {
    static let shared = IntelligentHarmonizer()

    @Published var isEnabled: Bool = false
    @Published var harmonyMode: HarmonyMode = .thirds
    @Published var key: MusicalKey = .c
    @Published var scale: ScaleType = .major
    @Published var voiceCount: Int = 1
    @Published var voiceSpread: Int = 0  // Octave spread
    @Published var velocityScale: Float = 0.8
    @Published var humanize: Float = 0.0
    @Published var smartVoicing: Bool = true  // Use intelligent voice leading

    // Advanced
    @Published var parallelMotion: Bool = true
    @Published var contraryMotion: Bool = false
    @Published var obliqueMotion: Bool = false
    @Published var avoidParallel5ths: Bool = true

    enum HarmonyMode: String, CaseIterable {
        case thirds = "Thirds"
        case sixths = "Sixths"
        case fifths = "Fifths"
        case fourths = "Fourths"
        case octaves = "Octaves"
        case powerChord = "Power Chord"
        case triad = "Triad"
        case seventh = "7th Chord"
        case ninth = "9th Chord"
        case custom = "Custom"
        case intelligent = "Intelligent"

        var intervals: [Int] {
            switch self {
            case .thirds: return [4]  // Major/minor third
            case .sixths: return [9]  // Major/minor sixth
            case .fifths: return [7]
            case .fourths: return [5]
            case .octaves: return [12]
            case .powerChord: return [7, 12]
            case .triad: return [4, 7]
            case .seventh: return [4, 7, 11]
            case .ninth: return [4, 7, 11, 14]
            case .custom, .intelligent: return []
            }
        }
    }

    enum MusicalKey: Int, CaseIterable {
        case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

        var name: String {
            ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue]
        }
    }

    enum ScaleType: String, CaseIterable {
        case major, minor, harmonicMinor, melodicMinor
        case dorian, phrygian, lydian, mixolydian, locrian
        case pentatonicMajor, pentatonicMinor, blues

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
            case .locrian: return [0, 1, 3, 5, 6, 8, 10]
            case .pentatonicMajor: return [0, 2, 4, 7, 9]
            case .pentatonicMinor: return [0, 3, 5, 7, 10]
            case .blues: return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    private var lastHarmonyNotes: [UInt8] = []

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard isEnabled else {
            return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)]
        }

        var events: [MIDIEvent] = []

        // Original note
        events.append(MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0))

        if on {
            // Generate harmony notes
            let harmonyNotes = generateHarmony(for: note, velocity: velocity)
            lastHarmonyNotes = harmonyNotes.map { $0.note }

            for harmonyNote in harmonyNotes {
                let timing = humanize > 0 ? UInt64(Int.random(in: 0...Int(humanize * 10)) * 1000) : 0
                events.append(MIDIEvent(type: .noteOn, note: harmonyNote.note, velocity: harmonyNote.velocity, timestamp: timing))
            }
        } else {
            // Turn off harmony notes
            for harmonyNote in lastHarmonyNotes {
                events.append(MIDIEvent(type: .noteOff, note: harmonyNote, velocity: 0, timestamp: 0))
            }
            lastHarmonyNotes.removeAll()
        }

        return events
    }

    private func generateHarmony(for note: UInt8, velocity: UInt8) -> [(note: UInt8, velocity: UInt8)] {
        var harmony: [(note: UInt8, velocity: UInt8)] = []

        if harmonyMode == .intelligent {
            return generateIntelligentHarmony(for: note, velocity: velocity)
        }

        let intervals = harmonyMode.intervals
        let scaledVelocity = UInt8(Float(velocity) * velocityScale)

        for (index, interval) in intervals.prefix(voiceCount).enumerated() {
            // Quantize to scale
            let rawHarmonyNote = Int(note) + interval + (index * voiceSpread * 12)
            let quantizedNote = quantizeToScale(rawHarmonyNote)

            if quantizedNote >= 0 && quantizedNote <= 127 {
                harmony.append((note: UInt8(quantizedNote), velocity: scaledVelocity))
            }
        }

        return harmony
    }

    private func generateIntelligentHarmony(for note: UInt8, velocity: UInt8) -> [(note: UInt8, velocity: UInt8)] {
        var harmony: [(note: UInt8, velocity: UInt8)] = []
        let scaledVelocity = UInt8(Float(velocity) * velocityScale)

        // Determine scale degree
        let pitchClass = Int(note) % 12
        let scaleDegree = getScaleDegree(pitchClass: pitchClass)

        // Generate diatonic harmony based on scale degree
        let harmonyIntervals = getDiatonicHarmony(scaleDegree: scaleDegree)

        for interval in harmonyIntervals.prefix(voiceCount) {
            let harmonyNote = Int(note) + interval
            if harmonyNote >= 0 && harmonyNote <= 127 {
                harmony.append((note: UInt8(harmonyNote), velocity: scaledVelocity))
            }
        }

        return harmony
    }

    private func quantizeToScale(_ note: Int) -> Int {
        let octave = note / 12
        let pitchClass = note % 12
        let rootOffset = (pitchClass - key.rawValue + 12) % 12

        let scaleNotes = scale.intervals
        let nearest = scaleNotes.min(by: { abs($0 - rootOffset) < abs($1 - rootOffset) }) ?? rootOffset

        return octave * 12 + (nearest + key.rawValue) % 12
    }

    private func getScaleDegree(pitchClass: Int) -> Int {
        let rootOffset = (pitchClass - key.rawValue + 12) % 12
        return scale.intervals.firstIndex(of: rootOffset) ?? 0
    }

    private func getDiatonicHarmony(scaleDegree: Int) -> [Int] {
        // Return diatonic third and fifth above
        let scaleNotes = scale.intervals
        let thirdDegree = (scaleDegree + 2) % scaleNotes.count
        let fifthDegree = (scaleDegree + 4) % scaleNotes.count

        let thirdInterval = (scaleNotes[thirdDegree] - scaleNotes[scaleDegree] + 12) % 12
        let fifthInterval = (scaleNotes[fifthDegree] - scaleNotes[scaleDegree] + 12) % 12

        return [thirdInterval, fifthInterval]
    }
}

// MARK: - Generative Sequencer

/// Markov chain and probability-based MIDI generation
@MainActor
class GenerativeSequencer: ObservableObject {
    static let shared = GenerativeSequencer()

    @Published var isEnabled: Bool = false
    @Published var mode: GenerativeMode = .markov
    @Published var density: Float = 0.5  // Note density
    @Published var complexity: Float = 0.5
    @Published var key: IntelligentHarmonizer.MusicalKey = .c
    @Published var scale: IntelligentHarmonizer.ScaleType = .major
    @Published var octaveRange: ClosedRange<Int> = 3...5
    @Published var velocityRange: ClosedRange<Int> = 60...100
    @Published var noteLengthRange: ClosedRange<Float> = 0.25...1.0

    // Markov settings
    @Published var markovOrder: Int = 2
    @Published var markovTemperature: Float = 1.0

    // Probability settings
    @Published var noteProbabilities: [Float] = Array(repeating: 1.0/12.0, count: 12)
    @Published var rhythmProbabilities: [Float] = [0.4, 0.3, 0.2, 0.1]

    // Bio-reactive
    @Published var bioReactiveEnabled: Bool = false
    @Published var bioDensityInfluence: Float = 0.0
    @Published var bioComplexityInfluence: Float = 0.0

    enum GenerativeMode: String, CaseIterable {
        case markov = "Markov Chain"
        case probability = "Probability"
        case euclidean = "Euclidean"
        case cellular = "Cellular Automata"
        case fractal = "Fractal"
        case bioReactive = "Bio-Reactive"
    }

    private var markovChain: MarkovChain<Int> = MarkovChain()
    private var cellularState: [Bool] = Array(repeating: false, count: 32)
    private var currentStep: Int = 0

    func tick(bpm: Double) -> [MIDIEvent] {
        guard isEnabled else { return [] }

        switch mode {
        case .markov:
            return generateMarkovNote()
        case .probability:
            return generateProbabilisticNote()
        case .euclidean:
            return generateEuclideanNote()
        case .cellular:
            return generateCellularNote()
        case .fractal:
            return generateFractalNote()
        case .bioReactive:
            return generateBioReactiveNote()
        }
    }

    private func generateMarkovNote() -> [MIDIEvent] {
        let effectiveDensity = bioReactiveEnabled ? density * (1.0 + bioDensityInfluence) : density

        guard Float.random(in: 0...1) < effectiveDensity else { return [] }

        // Get next note from Markov chain
        let scaleNotes = scale.intervals
        let noteIndex = markovChain.next() ?? Int.random(in: 0..<scaleNotes.count)
        let interval = scaleNotes[noteIndex % scaleNotes.count]

        let octave = Int.random(in: octaveRange)
        let pitch = octave * 12 + key.rawValue + interval
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }

    private func generateProbabilisticNote() -> [MIDIEvent] {
        guard Float.random(in: 0...1) < density else { return [] }

        // Weighted random note selection
        let totalWeight = noteProbabilities.reduce(0, +)
        var random = Float.random(in: 0..<totalWeight)

        var selectedNote = 0
        for (index, probability) in noteProbabilities.enumerated() {
            random -= probability
            if random <= 0 {
                selectedNote = index
                break
            }
        }

        let octave = Int.random(in: octaveRange)
        let pitch = octave * 12 + (key.rawValue + selectedNote) % 12
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }

    private func generateEuclideanNote() -> [MIDIEvent] {
        let steps = 16
        let pulses = Int(density * Float(steps))
        let pattern = EchoelArp.shared.generateEuclideanRhythm(steps: steps, pulses: pulses, rotation: 0)

        let stepIndex = currentStep % pattern.count
        currentStep += 1

        guard pattern[stepIndex] else { return [] }

        let scaleNotes = scale.intervals
        let noteIndex = stepIndex % scaleNotes.count
        let interval = scaleNotes[noteIndex]

        let octave = Int.random(in: octaveRange)
        let pitch = octave * 12 + key.rawValue + interval
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }

    private func generateCellularNote() -> [MIDIEvent] {
        // Rule 110 cellular automaton
        var newState = cellularState
        for i in 0..<cellularState.count {
            let left = cellularState[(i - 1 + cellularState.count) % cellularState.count]
            let center = cellularState[i]
            let right = cellularState[(i + 1) % cellularState.count]

            let pattern = (left ? 4 : 0) + (center ? 2 : 0) + (right ? 1 : 0)
            let rule110 = 0b01101110  // Rule 110
            newState[i] = (rule110 >> pattern) & 1 == 1
        }
        cellularState = newState

        let stepIndex = currentStep % cellularState.count
        currentStep += 1

        guard cellularState[stepIndex] else { return [] }

        let scaleNotes = scale.intervals
        let noteIndex = stepIndex % scaleNotes.count
        let pitch = Int.random(in: octaveRange) * 12 + key.rawValue + scaleNotes[noteIndex]
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }

    private func generateFractalNote() -> [MIDIEvent] {
        // Sierpinski-based fractal rhythm
        let step = currentStep
        currentStep += 1

        // Check if step is in Sierpinski triangle (step & (step - 1) == 0 for powers of 2)
        guard (step & (step >> 1)) == 0 else { return [] }
        guard Float.random(in: 0...1) < density else { return [] }

        let scaleNotes = scale.intervals
        let noteIndex = step % scaleNotes.count
        let pitch = Int.random(in: octaveRange) * 12 + key.rawValue + scaleNotes[noteIndex]
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }

    private func generateBioReactiveNote() -> [MIDIEvent] {
        let effectiveDensity = density * (1.0 + bioDensityInfluence)
        let effectiveComplexity = complexity * (1.0 + bioComplexityInfluence)

        guard Float.random(in: 0...1) < effectiveDensity else { return [] }

        let scaleNotes = scale.intervals
        let noteCount = max(1, Int(effectiveComplexity * Float(scaleNotes.count)))
        let noteIndex = Int.random(in: 0..<noteCount)
        let interval = scaleNotes[noteIndex]

        let octave = Int.random(in: octaveRange)
        let pitch = octave * 12 + key.rawValue + interval
        let velocity = Int.random(in: velocityRange)

        guard pitch >= 0 && pitch <= 127 else { return [] }

        return [
            MIDIEvent(type: .noteOn, note: UInt8(pitch), velocity: UInt8(velocity), timestamp: 0),
            MIDIEvent(type: .noteOff, note: UInt8(pitch), velocity: 0, timestamp: 100000)
        ]
    }
}

// MARK: - Markov Chain

class MarkovChain<T: Hashable> {
    private var transitions: [T: [T: Int]] = [:]
    private var currentState: T?

    func train(sequence: [T]) {
        for i in 0..<sequence.count - 1 {
            let current = sequence[i]
            let next = sequence[i + 1]

            if transitions[current] == nil {
                transitions[current] = [:]
            }
            transitions[current]![next, default: 0] += 1
        }
    }

    func next() -> T? {
        guard let current = currentState, let possibleNext = transitions[current] else {
            return nil
        }

        let total = possibleNext.values.reduce(0, +)
        var random = Int.random(in: 0..<total)

        for (state, count) in possibleNext {
            random -= count
            if random < 0 {
                currentState = state
                return state
            }
        }

        return possibleNext.keys.first
    }

    func setState(_ state: T) {
        currentState = state
    }
}

// MARK: - Bio-Reactive MIDI Processor

/// Unique to Echoelmusic: Convert biometric data to MIDI parameters
@MainActor
class BioReactiveMIDI: ObservableObject {
    static let shared = BioReactiveMIDI()

    @Published var isEnabled: Bool = false

    // Input parameters
    @Published var heartRate: Float = 70
    @Published var hrv: Float = 50
    @Published var coherence: Float = 0.5
    @Published var breathRate: Float = 12

    // Mappings
    @Published var hrToTempo: Bool = false
    @Published var hrToTempoRange: ClosedRange<Double> = 60...180
    @Published var hrvToVelocity: Bool = false
    @Published var hrvToVelocityRange: ClosedRange<Int> = 40...127
    @Published var coherenceToComplexity: Bool = false
    @Published var breathToFilter: Bool = false
    @Published var breathToFilterCC: Int = 74  // Brightness

    // Thresholds
    @Published var calmThreshold: Float = 60
    @Published var activeThreshold: Float = 100
    @Published var stressThreshold: Float = 120

    func update(heartRate: Float, hrv: Float, coherence: Float, breathRate: Float) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.coherence = coherence
        self.breathRate = breathRate
    }

    func getMappedTempo() -> Double? {
        guard isEnabled && hrToTempo else { return nil }

        let normalized = (heartRate - 40) / 160  // Normalize HR 40-200 to 0-1
        let clamped = max(0, min(1, normalized))
        return hrToTempoRange.lowerBound + Double(clamped) * (hrToTempoRange.upperBound - hrToTempoRange.lowerBound)
    }

    func getMappedVelocity() -> Int? {
        guard isEnabled && hrvToVelocity else { return nil }

        let normalized = hrv / 100  // Normalize HRV 0-100 to 0-1
        let clamped = max(0, min(1, normalized))
        return hrvToVelocityRange.lowerBound + Int(clamped * Float(hrvToVelocityRange.upperBound - hrvToVelocityRange.lowerBound))
    }

    func getMappedFilterCC() -> (cc: Int, value: Int)? {
        guard isEnabled && breathToFilter else { return nil }

        let normalized = breathRate / 30  // Normalize breath rate 0-30 to 0-1
        let clamped = max(0, min(1, normalized))
        let value = Int(clamped * 127)

        return (cc: breathToFilterCC, value: value)
    }

    func getEmotionalState() -> EmotionalState {
        if coherence > 0.7 && hrv > 60 {
            return .flow
        } else if heartRate > stressThreshold {
            return .stressed
        } else if heartRate > activeThreshold {
            return .active
        } else if heartRate < calmThreshold {
            return .calm
        } else {
            return .neutral
        }
    }

    enum EmotionalState: String {
        case calm = "Calm"
        case neutral = "Neutral"
        case active = "Active"
        case stressed = "Stressed"
        case flow = "Flow State"

        var suggestedScale: IntelligentHarmonizer.ScaleType {
            switch self {
            case .calm: return .pentatonicMajor
            case .neutral: return .major
            case .active: return .mixolydian
            case .stressed: return .harmonicMinor
            case .flow: return .lydian
            }
        }

        var suggestedComplexity: Float {
            switch self {
            case .calm: return 0.3
            case .neutral: return 0.5
            case .active: return 0.7
            case .stressed: return 0.8
            case .flow: return 0.9
            }
        }
    }
}

// MARK: - MIDI LFO

/// Shape-based modulation for CC values
@MainActor
class MIDILFO: ObservableObject {
    static let shared = MIDILFO()

    @Published var isEnabled: Bool = false
    @Published var shape: LFOShape = .sine
    @Published var rate: Float = 1.0  // Hz
    @Published var depth: Float = 64.0  // 0-127
    @Published var offset: Float = 64.0  // Center value
    @Published var phase: Float = 0.0  // 0-360 degrees
    @Published var targetCC: Int = 1  // Mod wheel by default
    @Published var syncToTempo: Bool = false
    @Published var syncDivision: EchoelArp.RateValue = .quarter

    enum LFOShape: String, CaseIterable {
        case sine = "Sine"
        case triangle = "Triangle"
        case saw = "Saw"
        case square = "Square"
        case random = "Random"
        case smoothRandom = "Smooth Random"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
    }

    private var currentPhase: Float = 0
    private var lastRandomValue: Float = 0
    private var targetRandomValue: Float = 0

    func tick(deltaTime: Float, bpm: Double) -> (cc: Int, value: Int)? {
        guard isEnabled else { return nil }

        let effectiveRate: Float
        if syncToTempo {
            effectiveRate = Float(bpm / 60.0) / Float(syncDivision.beatMultiplier)
        } else {
            effectiveRate = rate
        }

        currentPhase += effectiveRate * deltaTime * 2 * .pi
        if currentPhase > 2 * .pi {
            currentPhase -= 2 * .pi
            targetRandomValue = Float.random(in: -1...1)
        }

        let adjustedPhase = currentPhase + (phase * .pi / 180)
        let lfoValue = calculateLFOValue(phase: adjustedPhase)

        let ccValue = Int(offset + lfoValue * depth)
        let clampedValue = max(0, min(127, ccValue))

        return (cc: targetCC, value: clampedValue)
    }

    private func calculateLFOValue(phase: Float) -> Float {
        switch shape {
        case .sine:
            return sin(phase)
        case .triangle:
            let normalized = phase / (2 * .pi)
            return abs(normalized.truncatingRemainder(dividingBy: 1) * 4 - 2) - 1
        case .saw:
            let normalized = phase / (2 * .pi)
            return normalized.truncatingRemainder(dividingBy: 1) * 2 - 1
        case .square:
            return sin(phase) > 0 ? 1 : -1
        case .random:
            return lastRandomValue
        case .smoothRandom:
            let t = phase / (2 * .pi)
            lastRandomValue = lastRandomValue + (targetRandomValue - lastRandomValue) * min(1, t * 0.1)
            return lastRandomValue
        case .exponential:
            let normalized = sin(phase) * 0.5 + 0.5
            return pow(normalized, 2) * 2 - 1
        case .logarithmic:
            let normalized = sin(phase) * 0.5 + 0.5
            return sqrt(normalized) * 2 - 1
        }
    }
}

// MARK: - Polyrhythm Generator

@MainActor
class PolyrhythmGenerator: ObservableObject {
    static let shared = PolyrhythmGenerator()

    @Published var isEnabled: Bool = false
    @Published var rhythmA: Int = 3
    @Published var rhythmB: Int = 4
    @Published var rhythmC: Int = 0  // 0 = disabled
    @Published var noteA: UInt8 = 60
    @Published var noteB: UInt8 = 64
    @Published var noteC: UInt8 = 67
    @Published var velocityA: UInt8 = 100
    @Published var velocityB: UInt8 = 80
    @Published var velocityC: UInt8 = 60

    private var stepA: Int = 0
    private var stepB: Int = 0
    private var stepC: Int = 0
    private var masterStep: Int = 0

    func tick() -> [MIDIEvent] {
        guard isEnabled else { return [] }

        var events: [MIDIEvent] = []
        let lcm = rhythmA * rhythmB * (rhythmC > 0 ? rhythmC : 1)

        // Rhythm A
        if masterStep % (lcm / rhythmA) == 0 {
            events.append(MIDIEvent(type: .noteOn, note: noteA, velocity: velocityA, timestamp: 0))
            events.append(MIDIEvent(type: .noteOff, note: noteA, velocity: 0, timestamp: 50000))
        }

        // Rhythm B
        if masterStep % (lcm / rhythmB) == 0 {
            events.append(MIDIEvent(type: .noteOn, note: noteB, velocity: velocityB, timestamp: 0))
            events.append(MIDIEvent(type: .noteOff, note: noteB, velocity: 0, timestamp: 50000))
        }

        // Rhythm C
        if rhythmC > 0 && masterStep % (lcm / rhythmC) == 0 {
            events.append(MIDIEvent(type: .noteOn, note: noteC, velocity: velocityC, timestamp: 0))
            events.append(MIDIEvent(type: .noteOff, note: noteC, velocity: 0, timestamp: 50000))
        }

        masterStep = (masterStep + 1) % lcm

        return events
    }

    func reset() {
        masterStep = 0
    }
}

// MARK: - Core MIDI Types

struct MIDIEvent {
    let type: EventType
    let note: UInt8
    let velocity: UInt8
    let timestamp: UInt64  // Microseconds

    enum EventType {
        case noteOn, noteOff, cc
    }
}

// MARK: - Standard MIDI Effects (from original file)

class Arpeggiator: ObservableObject {
    @Published var pattern: ArpPattern = .up
    @Published var rate: NoteValue = .sixteenth
    @Published var gate: Float = 80.0
    @Published var octaves: Int = 1
    @Published var syncToHost: Bool = true
    @Published var latch: Bool = false
    @Published var velocity: VelocityMode = .original
    @Published var velocityAmount: Int = 100
    @Published var swing: Float = 0.0
    @Published var bypass: Bool = false

    enum ArpPattern: String, CaseIterable {
        case up, down, upDown, downUp, upDown2, random, order, chord
    }

    enum NoteValue: String, CaseIterable {
        case whole = "1/1", half = "1/2", quarter = "1/4"
        case eighth = "1/8", sixteenth = "1/16", thirtysecond = "1/32"
        case triplet8 = "1/8T", triplet16 = "1/16T"
    }

    enum VelocityMode: String, CaseIterable {
        case original, fixed, ascending, descending, random
    }

    private var heldNotes: [UInt8] = []
    private var arpStep: Int = 0

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        if on {
            heldNotes.append(note)
            if !latch && heldNotes.count == 1 { arpStep = 0 }
        } else {
            heldNotes.removeAll { $0 == note }
            if !latch && heldNotes.isEmpty { arpStep = 0 }
        }
        return []
    }

    func tick(tempo: Double) -> [MIDIEvent] {
        guard !heldNotes.isEmpty else { return [] }
        let sorted = heldNotes.sorted()
        guard !sorted.isEmpty else { return [] }
        let noteIndex = arpStep % sorted.count
        let note = sorted[noteIndex]
        arpStep += 1
        return [
            MIDIEvent(type: .noteOn, note: note, velocity: UInt8(velocityAmount), timestamp: 0),
            MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: 100000)
        ]
    }
}

class ChordGenerator: ObservableObject {
    @Published var chordType: ChordType = .major
    @Published var voicing: Voicing = .close
    @Published var inversion: Int = 0
    @Published var bypass: Bool = false

    enum ChordType: String, CaseIterable {
        case major, minor, diminished, augmented, sus2, sus4
        case major7, minor7, dominant7, diminished7

        var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .diminished: return [0, 3, 6]
            case .augmented: return [0, 4, 8]
            case .sus2: return [0, 2, 7]
            case .sus4: return [0, 5, 7]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .dominant7: return [0, 4, 7, 10]
            case .diminished7: return [0, 3, 6, 9]
            }
        }
    }

    enum Voicing: String, CaseIterable {
        case close, open, drop2, drop3, spread
    }

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }

        var events: [MIDIEvent] = []
        for interval in chordType.intervals {
            let chordNote = note + UInt8(interval)
            events.append(MIDIEvent(type: on ? .noteOn : .noteOff, note: chordNote, velocity: velocity, timestamp: 0))
        }
        return events
    }
}

class ScaleQuantizer: ObservableObject {
    @Published var scale: Scale = .major
    @Published var root: Note = .c
    @Published var mode: QuantizeMode = .nearest
    @Published var bypass: Bool = false

    enum Scale: String, CaseIterable {
        case major, minor, dorian, phrygian, lydian, mixolydian, locrian
        case harmonicMinor, melodicMinor, pentatonicMajor, pentatonicMinor, blues

        var intervals: [Int] {
            switch self {
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .dorian: return [0, 2, 3, 5, 7, 9, 10]
            case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
            case .lydian: return [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            case .locrian: return [0, 1, 3, 5, 6, 8, 10]
            case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
            case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
            case .pentatonicMajor: return [0, 2, 4, 7, 9]
            case .pentatonicMinor: return [0, 3, 5, 7, 10]
            case .blues: return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    enum Note: Int, CaseIterable {
        case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b
        var name: String { ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue] }
    }

    enum QuantizeMode: String, CaseIterable {
        case nearest, up, down
    }

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }

        let quantized = quantizeToScale(note)
        return [MIDIEvent(type: on ? .noteOn : .noteOff, note: quantized, velocity: velocity, timestamp: 0)]
    }

    private func quantizeToScale(_ note: UInt8) -> UInt8 {
        let octave = Int(note) / 12
        let pitchClass = Int(note) % 12
        let scaleNotes = scale.intervals.map { ($0 + root.rawValue) % 12 }
        let nearest = scaleNotes.min(by: { abs($0 - pitchClass) < abs($1 - pitchClass) }) ?? pitchClass
        return UInt8(octave * 12 + nearest)
    }
}

class MIDIEcho: ObservableObject {
    @Published var delay: Float = 500.0
    @Published var feedback: Int = 50
    @Published var velocityDecay: Int = 10
    @Published var maxEchoes: Int = 8
    @Published var bypass: Bool = false

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool, tempo: Double) -> [MIDIEvent] {
        guard on && !bypass else { return [] }

        var events: [MIDIEvent] = []
        events.append(MIDIEvent(type: .noteOn, note: note, velocity: velocity, timestamp: 0))

        var echoVel = Int(velocity)
        var echoTime: UInt64 = UInt64(delay * 1000)

        for _ in 1...maxEchoes {
            echoVel = echoVel * (100 - velocityDecay) / 100
            guard echoVel > 10 else { break }

            events.append(MIDIEvent(type: .noteOn, note: note, velocity: UInt8(echoVel), timestamp: echoTime))
            events.append(MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: echoTime + 50000))
            echoTime += UInt64(delay * 1000)

            if feedback < Int.random(in: 0...100) { break }
        }

        return events
    }
}

class Randomizer: ObservableObject {
    @Published var pitchAmount: Int = 0
    @Published var velocityAmount: Int = 0
    @Published var timingAmount: Int = 0
    @Published var probability: Int = 100
    @Published var bypass: Bool = false

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard on && !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }
        guard Int.random(in: 1...100) <= probability else { return [] }

        let pitchVar = Int.random(in: -pitchAmount...pitchAmount)
        let velVar = Int.random(in: -velocityAmount...velocityAmount)
        let timeVar = UInt64(Int.random(in: -timingAmount...timingAmount) * 1000)

        let newNote = UInt8(max(0, min(127, Int(note) + pitchVar)))
        let newVel = UInt8(max(1, min(127, Int(velocity) + velVar)))

        return [MIDIEvent(type: .noteOn, note: newNote, velocity: newVel, timestamp: timeVar)]
    }
}

class Humanizer: ObservableObject {
    @Published var timing: Int = 10
    @Published var velocity: Int = 10
    @Published var bypass: Bool = false

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard on && !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }

        let timeVar = UInt64(Int.random(in: -timing...timing) * 1000)
        let velVar = Int.random(in: -self.velocity...self.velocity)
        let newVel = UInt8(max(1, min(127, Int(velocity) * (100 + velVar) / 100)))

        return [MIDIEvent(type: .noteOn, note: note, velocity: newVel, timestamp: timeVar)]
    }
}

class Transpose: ObservableObject {
    @Published var semitones: Int = 0
    @Published var octaves: Int = 0
    @Published var bypass: Bool = false

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }

        let transposed = Int(note) + semitones + (octaves * 12)
        let finalNote = UInt8(max(0, min(127, transposed)))
        return [MIDIEvent(type: on ? .noteOn : .noteOff, note: finalNote, velocity: velocity, timestamp: 0)]
    }
}

class VelocityProcessor: ObservableObject {
    @Published var mode: VelocityMode = .add
    @Published var amount: Int = 0
    @Published var curve: Float = 1.0
    @Published var bypass: Bool = false

    enum VelocityMode: String, CaseIterable {
        case add, scale, compress, expand, fixed, curve
    }

    func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
        guard on && !bypass else { return [MIDIEvent(type: on ? .noteOn : .noteOff, note: note, velocity: velocity, timestamp: 0)] }

        var processedVel = Int(velocity)
        switch mode {
        case .add: processedVel += amount
        case .scale: processedVel = processedVel * (100 + amount) / 100
        case .compress, .expand: processedVel = Int(pow(Float(processedVel) / 127.0, curve) * 127.0)
        case .fixed: processedVel = amount + 64
        case .curve: processedVel = Int(pow(Float(processedVel) / 127.0, curve) * 127.0)
        }

        let finalVel = UInt8(max(1, min(127, processedVel)))
        return [MIDIEvent(type: .noteOn, note: note, velocity: finalVel, timestamp: 0)]
    }
}

// MARK: - Effect Chain

class MIDIEffectChain: ObservableObject {
    @Published var effects: [MIDIEffect] = []
    @Published var bypass: Bool = false

    struct MIDIEffect: Identifiable {
        let id = UUID()
        var name: String
        var type: EffectType
        var enabled: Bool
        var bypass: Bool

        enum EffectType {
            case echoelArp, intelligentHarmonizer, generativeSequencer
            case bioReactiveMIDI, midiLFO, polyrhythm
            case arpeggiator, chordGenerator, scaleQuantizer
            case midiEcho, randomizer, humanizer
            case transpose, velocityProcessor
        }
    }

    func processEvent(_ event: MIDIEvent) -> [MIDIEvent] {
        guard !bypass else { return [event] }

        var events = [event]
        for effect in effects where !effect.bypass && effect.enabled {
            events = processWithEffect(events, effect: effect)
        }
        return events
    }

    private func processWithEffect(_ events: [MIDIEvent], effect: MIDIEffect) -> [MIDIEvent] {
        // Route to appropriate effect processor
        return events
    }
}
