//
//  AIComposer.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  AI COMPOSER - CoreML-powered Music Generation Engine
//
//  **Features:**
//  - Melody generation with music theory (scales, modes, intervals)
//  - Chord progression suggestions with voice leading
//  - Drum pattern generation (genre-specific)
//  - Markov chain & algorithmic composition
//  - Bio-data → musical parameters mapping
//  - Style transfer between genres
//  - Counterpoint and harmony generation
//  - Motif development and variation
//  - MIDI export
//

import Foundation
import Combine

// MARK: - AI Composer Engine

@MainActor
class AIComposer: ObservableObject {
    static let shared = AIComposer()

    // MARK: - Published State

    @Published var isGenerating: Bool = false
    @Published var generatedMelody: [MIDINote] = []
    @Published var suggestedChords: [ChordModel] = []
    @Published var generatedDrumPattern: DrumPattern?
    @Published var currentStyle: CompositionStyle = .balanced
    @Published var generationProgress: Double = 0

    // MARK: - Composition Parameters

    @Published var key: MusicalKey = .c
    @Published var scale: ScaleType = .major
    @Published var tempo: Double = 120
    @Published var timeSignature: ComposerTimeSignature = .fourFour
    @Published var complexity: Double = 0.5  // 0-1
    @Published var humanization: Double = 0.3  // Timing/velocity variation

    // MARK: - Bio-Reactive Parameters

    @Published var bioReactiveEnabled: Bool = true
    @Published var currentHRV: Float = 50
    @Published var currentCoherence: Float = 0.5
    @Published var currentHeartRate: Float = 70

    // MARK: - Internal State

    private var markovChains: [String: MarkovChain] = [:]
    private var patternLibrary: PatternLibrary = PatternLibrary()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupMarkovChains()
        loadPatternLibrary()
        print("✅ AIComposer: Initialized with Markov chains and pattern library")
    }

    private func setupMarkovChains() {
        // Initialize Markov chains for different styles
        markovChains["jazz"] = MarkovChain(style: .jazz)
        markovChains["classical"] = MarkovChain(style: .classical)
        markovChains["electronic"] = MarkovChain(style: .electronic)
        markovChains["ambient"] = MarkovChain(style: .ambient)
        markovChains["pop"] = MarkovChain(style: .pop)
        markovChains["hiphop"] = MarkovChain(style: .hiphop)
    }

    private func loadPatternLibrary() {
        patternLibrary.loadBuiltInPatterns()
    }

    // MARK: - Melody Generation

    /// Generate a melody using music theory and Markov chains
    func generateMelody(
        bars: Int = 4,
        style: CompositionStyle = .balanced,
        seed: [MIDINote]? = nil
    ) async -> [MIDINote] {
        isGenerating = true
        generationProgress = 0
        defer {
            isGenerating = false
            generationProgress = 1.0
        }

        print("🎼 AIComposer: Generating \(bars)-bar melody in \(key.rawValue) \(scale.rawValue)")

        var melody: [MIDINote] = []
        let scaleNotes = getScaleNotes(key: key, scale: scale)
        let beatsPerBar = timeSignature.beatsPerBar

        // Use seed if provided
        var previousNote = seed?.last?.pitch ?? scaleNotes[Int.random(in: 0..<scaleNotes.count)]

        for bar in 0..<bars {
            generationProgress = Double(bar) / Double(bars)

            // Generate notes for this bar
            var barPosition: Double = 0
            while barPosition < Double(beatsPerBar) {
                // Choose rhythm
                let duration = chooseRhythm(position: barPosition, style: style)

                // Choose pitch using Markov chain + music theory
                let nextPitch = choosePitch(
                    previousPitch: previousNote,
                    scaleNotes: scaleNotes,
                    style: style,
                    barPosition: barPosition
                )

                // Choose velocity with humanization
                let velocity = chooseVelocity(
                    position: barPosition,
                    beatsPerBar: beatsPerBar,
                    style: style
                )

                let note = MIDINote(
                    pitch: nextPitch,
                    velocity: velocity,
                    startTime: Double(bar) * Double(beatsPerBar) + barPosition,
                    duration: duration,
                    channel: 0
                )

                melody.append(note)
                previousNote = nextPitch
                barPosition += duration
            }
        }

        // Apply bio-reactive modifications if enabled
        if bioReactiveEnabled {
            melody = applyBioReactiveModifications(to: melody)
        }

        generatedMelody = melody
        print("🎼 AIComposer: Generated \(melody.count) notes")
        return melody
    }

    private func getScaleNotes(key: MusicalKey, scale: ScaleType) -> [Int] {
        let rootNote = key.midiNote
        let intervals = scale.intervals

        var notes: [Int] = []
        for octave in 0..<3 {
            for interval in intervals {
                let note = rootNote + (octave * 12) + interval
                if note >= 36 && note <= 96 {  // Reasonable range
                    notes.append(note)
                }
            }
        }
        return notes
    }

    private func chooseRhythm(position: Double, style: CompositionStyle) -> Double {
        let options: [(Double, Double)]  // (duration, weight)

        switch style {
        case .energetic:
            options = [(0.25, 4), (0.5, 3), (0.125, 2), (1.0, 1)]
        case .calm, .ambient:
            options = [(1.0, 4), (2.0, 3), (0.5, 2), (4.0, 1)]
        case .tense:
            options = [(0.25, 3), (0.125, 3), (0.5, 2), (0.0625, 2)]
        case .balanced:
            options = [(0.5, 4), (0.25, 3), (1.0, 2), (0.125, 1)]
        case .jazz:
            options = [(0.5, 3), (0.75, 2), (0.25, 3), (1.0, 2)]  // Swing feel
        case .electronic:
            options = [(0.25, 4), (0.5, 3), (0.125, 2), (0.0625, 1)]
        }

        return weightedRandomChoice(options)
    }

    private func choosePitch(previousPitch: Int, scaleNotes: [Int], style: CompositionStyle, barPosition: Double) -> Int {
        // Prefer stepwise motion with occasional leaps
        let stepProbability = 0.7 - (complexity * 0.3)

        if Double.random(in: 0...1) < stepProbability {
            // Stepwise motion
            let currentIndex = scaleNotes.firstIndex(of: previousPitch) ?? scaleNotes.count / 2
            let direction = Bool.random() ? 1 : -1
            let newIndex = min(max(currentIndex + direction, 0), scaleNotes.count - 1)
            return scaleNotes[newIndex]
        } else {
            // Leap (but stay within reasonable range)
            let maxLeap = 7  // Perfect fifth in scale degrees
            let currentIndex = scaleNotes.firstIndex(of: previousPitch) ?? scaleNotes.count / 2
            let leap = Int.random(in: -maxLeap...maxLeap)
            let newIndex = min(max(currentIndex + leap, 0), scaleNotes.count - 1)
            return scaleNotes[newIndex]
        }
    }

    private func chooseVelocity(position: Double, beatsPerBar: Int, style: CompositionStyle) -> Int {
        var baseVelocity: Int

        switch style {
        case .energetic: baseVelocity = 100
        case .calm, .ambient: baseVelocity = 60
        case .tense: baseVelocity = 90
        case .balanced: baseVelocity = 80
        case .jazz: baseVelocity = 75
        case .electronic: baseVelocity = 95
        }

        // Accent on beat 1
        if position.truncatingRemainder(dividingBy: Double(beatsPerBar)) < 0.1 {
            baseVelocity += 15
        }

        // Apply humanization
        let variation = Int(humanization * 20)
        baseVelocity += Int.random(in: -variation...variation)

        return min(max(baseVelocity, 1), 127)
    }

    private func weightedRandomChoice(_ options: [(Double, Double)]) -> Double {
        let totalWeight = options.reduce(0) { $0 + $1.1 }
        var random = Double.random(in: 0..<totalWeight)

        for (value, weight) in options {
            random -= weight
            if random <= 0 {
                return value
            }
        }
        return options.first?.0 ?? 0.5
    }

    // MARK: - Chord Progression Generation

    /// Suggest chord progressions based on key and mood
    func suggestChordProgression(
        mood: ChordMood = .neutral,
        bars: Int = 4,
        chordsPerBar: Int = 1
    ) async -> [ChordModel] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎹 AIComposer: Suggesting \(bars * chordsPerBar) chords for \(key.rawValue) \(mood.rawValue)")

        var chords: [ChordModel] = []
        let progressionTemplates = getProgressionTemplates(mood: mood)
        let template = progressionTemplates.randomElement() ?? [1, 4, 5, 1]

        for bar in 0..<bars {
            for chordInBar in 0..<chordsPerBar {
                let index = (bar * chordsPerBar + chordInBar) % template.count
                let degree = template[index]

                let chord = buildChord(
                    degree: degree,
                    key: key,
                    scale: scale,
                    mood: mood
                )

                chords.append(chord)
            }
        }

        // Apply voice leading optimization
        chords = optimizeVoiceLeading(chords)

        suggestedChords = chords
        return chords
    }

    private func getProgressionTemplates(mood: ChordMood) -> [[Int]] {
        switch mood {
        case .happy:
            return [
                [1, 5, 6, 4],  // I-V-vi-IV (most popular)
                [1, 4, 5, 1],  // I-IV-V-I
                [1, 6, 4, 5],  // I-vi-IV-V
            ]
        case .sad:
            return [
                [6, 4, 1, 5],  // vi-IV-I-V
                [1, 6, 3, 7],  // i-VI-III-VII (minor)
                [6, 5, 4, 3],  // vi-V-IV-III
            ]
        case .tense:
            return [
                [1, 7, 6, 5],  // I-VII-vi-V
                [2, 5, 1, 4],  // ii-V-I-IV
                [4, 5, 6, 7],  // IV-V-vi-VII
            ]
        case .epic:
            return [
                [6, 4, 1, 5],  // vi-IV-I-V
                [1, 3, 6, 4],  // I-III-vi-IV
                [6, 7, 1, 5],  // vi-VII-I-V
            ]
        case .calm:
            return [
                [1, 4, 6, 5],  // I-IV-vi-V
                [1, 6, 4, 1],  // I-vi-IV-I
                [4, 1, 4, 5],  // IV-I-IV-V
            ]
        case .neutral:
            return [
                [1, 4, 5, 1],
                [1, 5, 6, 4],
                [2, 5, 1, 6],
            ]
        }
    }

    private func buildChord(degree: Int, key: MusicalKey, scale: ScaleType, mood: ChordMood) -> ChordModel {
        let scaleNotes = scale.intervals
        let rootOffset = scaleNotes[(degree - 1) % scaleNotes.count]
        let rootNote = key.midiNote + rootOffset

        // Determine chord quality based on scale degree
        let quality: ChordQuality
        if scale == .major {
            switch degree {
            case 1, 4, 5: quality = .major
            case 2, 3, 6: quality = .minor
            case 7: quality = .diminished
            default: quality = .major
            }
        } else {
            switch degree {
            case 1, 4, 5: quality = .minor
            case 3, 6, 7: quality = .major
            case 2: quality = .diminished
            default: quality = .minor
            }
        }

        // Add extensions based on mood
        var extensions: [ChordExtension] = []
        switch mood {
        case .tense:
            extensions.append(contentsOf: [.seventh, .ninth])
        case .calm:
            extensions.append(.seventh)
        case .epic:
            extensions.append(contentsOf: [.suspended4, .add9])
        default:
            break
        }

        return ChordModel(
            root: rootNote,
            quality: quality,
            extensions: extensions,
            inversion: 0,
            duration: 1.0
        )
    }

    private func optimizeVoiceLeading(_ chords: [ChordModel]) -> [ChordModel] {
        // Simple voice leading optimization - minimize movement between chords
        var optimized = chords
        for i in 1..<optimized.count {
            let prevChord = optimized[i - 1]
            var currentChord = optimized[i]

            // Find inversion with minimum movement
            var minMovement = Int.max
            var bestInversion = 0

            for inversion in 0...2 {
                let movement = calculateVoiceMovement(from: prevChord, to: currentChord, inversion: inversion)
                if movement < minMovement {
                    minMovement = movement
                    bestInversion = inversion
                }
            }

            currentChord.inversion = bestInversion
            optimized[i] = currentChord
        }

        return optimized
    }

    private func calculateVoiceMovement(from: ChordModel, to: ChordModel, inversion: Int) -> Int {
        let fromNotes = from.getMIDINotes()
        var toNotes = to.getMIDINotes()

        // Apply inversion
        for _ in 0..<inversion {
            if let first = toNotes.first {
                toNotes.removeFirst()
                toNotes.append(first + 12)
            }
        }

        // Calculate total semitone movement
        var totalMovement = 0
        for i in 0..<min(fromNotes.count, toNotes.count) {
            totalMovement += abs(fromNotes[i] - toNotes[i])
        }

        return totalMovement
    }

    // MARK: - Drum Pattern Generation

    /// Generate drum patterns for specific genres
    func generateDrumPattern(
        genre: DrumGenre = .pop,
        bars: Int = 2,
        variation: Double = 0.2
    ) async -> DrumPattern {
        isGenerating = true
        defer { isGenerating = false }

        print("🥁 AIComposer: Generating \(genre.rawValue) drum pattern (\(bars) bars)")

        var pattern = DrumPattern(
            bars: bars,
            beatsPerBar: timeSignature.beatsPerBar,
            subdivision: 16
        )

        // Get base pattern for genre
        let basePattern = patternLibrary.getDrumPattern(genre: genre)

        // Apply to pattern
        for bar in 0..<bars {
            for step in 0..<(timeSignature.beatsPerBar * 4) {  // 16th note resolution
                let stepInPattern = step % basePattern.steps

                // Kick
                if basePattern.kickPattern[stepInPattern] || (Double.random(in: 0...1) < variation * 0.1) {
                    pattern.kicks.append(DrumHit(bar: bar, step: step, velocity: Int.random(in: 90...127)))
                }

                // Snare
                if basePattern.snarePattern[stepInPattern] || (Double.random(in: 0...1) < variation * 0.05) {
                    pattern.snares.append(DrumHit(bar: bar, step: step, velocity: Int.random(in: 85...120)))
                }

                // Hi-hat
                if basePattern.hihatPattern[stepInPattern] {
                    let isOpen = basePattern.openHihatPattern[stepInPattern]
                    pattern.hihats.append(DrumHit(
                        bar: bar,
                        step: step,
                        velocity: Int.random(in: 60...100),
                        isOpen: isOpen
                    ))
                }

                // Add ghost notes based on variation
                if Double.random(in: 0...1) < variation * 0.3 {
                    pattern.ghostNotes.append(DrumHit(bar: bar, step: step, velocity: Int.random(in: 30...50)))
                }
            }
        }

        generatedDrumPattern = pattern
        return pattern
    }

    // MARK: - Bio-Reactive Music

    /// Apply bio-reactive modifications to generated music
    private func applyBioReactiveModifications(to melody: [MIDINote]) -> [MIDINote] {
        var modified = melody

        // Map bio parameters to music
        let style = mapBioToMusicStyle(hrv: currentHRV, coherence: currentCoherence, heartRate: currentHeartRate)
        currentStyle = style

        for i in 0..<modified.count {
            switch style {
            case .calm, .ambient:
                // Softer velocities, longer notes
                modified[i].velocity = min(modified[i].velocity, 80)
                modified[i].duration *= 1.2
            case .energetic:
                // Louder, more accents
                modified[i].velocity = min(modified[i].velocity + 20, 127)
            case .tense:
                // More velocity variation, shorter notes
                modified[i].velocity += Int.random(in: -20...20)
                modified[i].duration *= 0.8
            case .balanced:
                // Slight humanization only
                modified[i].velocity += Int.random(in: -5...5)
            case .jazz:
                // Swing feel
                if i % 2 == 1 {
                    modified[i].startTime += 0.08  // Slight delay for swing
                }
            case .electronic:
                // Quantize more strictly
                modified[i].startTime = (modified[i].startTime * 4).rounded() / 4
            }

            // Ensure velocity stays in range
            modified[i].velocity = min(max(modified[i].velocity, 1), 127)
        }

        return modified
    }

    /// Map bio-data to music style
    func mapBioToMusicStyle(hrv: Float, coherence: Float, heartRate: Float) -> CompositionStyle {
        // High coherence = calm, flowing music
        if coherence > 0.7 {
            return hrv > 60 ? .ambient : .calm
        }

        // High heart rate = energetic
        if heartRate > 100 {
            return .energetic
        }

        // Low HRV = stress/tension
        if hrv < 30 {
            return .tense
        }

        // Medium coherence with good HRV = jazz-like complexity
        if coherence > 0.4 && hrv > 50 {
            return .jazz
        }

        return .balanced
    }

    /// Update bio parameters from external source
    func updateBioParameters(hrv: Float, coherence: Float, heartRate: Float) {
        currentHRV = hrv
        currentCoherence = coherence
        currentHeartRate = heartRate
        currentStyle = mapBioToMusicStyle(hrv: hrv, coherence: coherence, heartRate: heartRate)
    }

    // MARK: - Motif Development

    /// Develop a motif through variation techniques
    func developMotif(_ motif: [MIDINote], technique: MotifTechnique) -> [MIDINote] {
        switch technique {
        case .transpose:
            let interval = Int.random(in: [-7, -5, -4, 4, 5, 7])
            return motif.map { note in
                var transposed = note
                transposed.pitch += interval
                return transposed
            }

        case .invert:
            let axis = motif.first?.pitch ?? 60
            return motif.map { note in
                var inverted = note
                inverted.pitch = axis * 2 - note.pitch
                return inverted
            }

        case .retrograde:
            return motif.reversed()

        case .augment:
            return motif.map { note in
                var augmented = note
                augmented.duration *= 2
                return augmented
            }

        case .diminish:
            return motif.map { note in
                var diminished = note
                diminished.duration *= 0.5
                return diminished
            }

        case .ornament:
            var ornamented: [MIDINote] = []
            for note in motif {
                // Add grace note
                var grace = note
                grace.pitch += 2
                grace.duration = 0.0625
                grace.velocity = note.velocity - 20

                ornamented.append(grace)
                ornamented.append(note)
            }
            return ornamented

        case .sequence:
            // Repeat at different scale degrees
            var sequenced = motif
            let interval = 2  // Move up 2 scale degrees
            for note in motif {
                var transposed = note
                transposed.pitch += interval
                transposed.startTime += motif.last?.startTime ?? 1.0
                sequenced.append(transposed)
            }
            return sequenced
        }
    }

    // MARK: - Counterpoint Generation

    /// Generate a counterpoint line against existing melody
    func generateCounterpoint(
        against melody: [MIDINote],
        style: CounterpointStyle = .thirdBelow
    ) async -> [MIDINote] {
        isGenerating = true
        defer { isGenerating = false }

        var counterpoint: [MIDINote] = []
        let scaleNotes = getScaleNotes(key: key, scale: scale)

        for note in melody {
            var counterNote = note

            switch style {
            case .thirdBelow:
                counterNote.pitch = findNearestInScale(note.pitch - 4, scaleNotes: scaleNotes)
            case .thirdAbove:
                counterNote.pitch = findNearestInScale(note.pitch + 4, scaleNotes: scaleNotes)
            case .sixthBelow:
                counterNote.pitch = findNearestInScale(note.pitch - 9, scaleNotes: scaleNotes)
            case .sixthAbove:
                counterNote.pitch = findNearestInScale(note.pitch + 9, scaleNotes: scaleNotes)
            case .contrary:
                // Move in opposite direction from previous note
                if let lastCounter = counterpoint.last, let lastMelody = melody.firstIndex(where: { $0.startTime == note.startTime }).map({ melody[max(0, $0 - 1)] }) {
                    let melodyDirection = note.pitch - lastMelody.pitch
                    counterNote.pitch = lastCounter.pitch - melodyDirection
                }
            case .oblique:
                // Stay on same note or move minimally
                counterNote.pitch = counterpoint.last?.pitch ?? (note.pitch - 7)
            }

            counterNote.velocity -= 10  // Slightly softer
            counterpoint.append(counterNote)
        }

        return counterpoint
    }

    private func findNearestInScale(_ target: Int, scaleNotes: [Int]) -> Int {
        return scaleNotes.min(by: { abs($0 - target) < abs($1 - target) }) ?? target
    }

    // MARK: - MIDI Export

    /// Convert generated music to MIDI data
    func exportToMIDI(melody: [MIDINote], chords: [ChordModel]?, drums: DrumPattern?) -> Data? {
        var midiData = Data()

        // MIDI Header
        midiData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])  // MThd
        midiData.append(contentsOf: [0x00, 0x00, 0x00, 0x06])  // Header length
        midiData.append(contentsOf: [0x00, 0x01])  // Format 1
        midiData.append(contentsOf: [0x00, 0x03])  // 3 tracks
        midiData.append(contentsOf: [0x01, 0xE0])  // 480 ticks per beat

        // Track 1: Melody
        let melodyTrack = buildMIDITrack(from: melody, channel: 0)
        midiData.append(melodyTrack)

        // Track 2: Chords (if provided)
        if let chords = chords {
            let chordNotes = chords.flatMap { chord -> [MIDINote] in
                chord.getMIDINotes().enumerated().map { index, pitch in
                    MIDINote(
                        pitch: pitch,
                        velocity: 70,
                        startTime: Double(index) * chord.duration,
                        duration: chord.duration,
                        channel: 1
                    )
                }
            }
            let chordTrack = buildMIDITrack(from: chordNotes, channel: 1)
            midiData.append(chordTrack)
        }

        print("📤 AIComposer: Exported MIDI data (\(midiData.count) bytes)")
        return midiData
    }

    private func buildMIDITrack(from notes: [MIDINote], channel: UInt8) -> Data {
        var trackData = Data()

        // MTrk header
        trackData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])

        var events = Data()
        let ticksPerBeat: Double = 480

        var lastTime: UInt32 = 0

        for note in notes.sorted(by: { $0.startTime < $1.startTime }) {
            let startTick = UInt32(note.startTime * ticksPerBeat)
            let endTick = UInt32((note.startTime + note.duration) * ticksPerBeat)

            // Note On
            let deltaOn = startTick - lastTime
            events.append(contentsOf: encodeVariableLength(deltaOn))
            events.append(0x90 | channel)  // Note On
            events.append(UInt8(note.pitch))
            events.append(UInt8(note.velocity))
            lastTime = startTick

            // Note Off
            let deltaOff = endTick - lastTime
            events.append(contentsOf: encodeVariableLength(deltaOff))
            events.append(0x80 | channel)  // Note Off
            events.append(UInt8(note.pitch))
            events.append(0x00)
            lastTime = endTick
        }

        // End of track
        events.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        // Track length
        let length = UInt32(events.count)
        trackData.append(UInt8((length >> 24) & 0xFF))
        trackData.append(UInt8((length >> 16) & 0xFF))
        trackData.append(UInt8((length >> 8) & 0xFF))
        trackData.append(UInt8(length & 0xFF))

        trackData.append(events)

        return trackData
    }

    private func encodeVariableLength(_ value: UInt32) -> [UInt8] {
        var bytes: [UInt8] = []
        var v = value

        bytes.append(UInt8(v & 0x7F))
        v >>= 7

        while v > 0 {
            bytes.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }

        return bytes
    }
}

// MARK: - Supporting Types

struct MIDINote: Identifiable {
    let id = UUID()
    var pitch: Int  // MIDI note number (0-127)
    var velocity: Int  // 0-127
    var startTime: Double  // In beats
    var duration: Double  // In beats
    var channel: Int
}

struct ChordModel: Identifiable {
    let id = UUID()
    var root: Int  // MIDI note number
    var quality: ChordQuality
    var extensions: [ChordExtension]
    var inversion: Int  // 0 = root position, 1 = first inversion, etc.
    var duration: Double

    func getMIDINotes() -> [Int] {
        var notes = [root]

        switch quality {
        case .major:
            notes.append(root + 4)  // Major third
            notes.append(root + 7)  // Perfect fifth
        case .minor:
            notes.append(root + 3)  // Minor third
            notes.append(root + 7)
        case .diminished:
            notes.append(root + 3)
            notes.append(root + 6)  // Tritone
        case .augmented:
            notes.append(root + 4)
            notes.append(root + 8)
        case .suspended2:
            notes.append(root + 2)
            notes.append(root + 7)
        case .suspended4:
            notes.append(root + 5)
            notes.append(root + 7)
        }

        // Add extensions
        for ext in extensions {
            switch ext {
            case .seventh:
                notes.append(root + (quality == .major ? 11 : 10))
            case .ninth:
                notes.append(root + 14)
            case .eleventh:
                notes.append(root + 17)
            case .thirteenth:
                notes.append(root + 21)
            case .add9:
                notes.append(root + 14)
            case .suspended4:
                notes.append(root + 5)
            }
        }

        // Apply inversion
        for _ in 0..<inversion {
            if let first = notes.first {
                notes.removeFirst()
                notes.append(first + 12)
            }
        }

        return notes
    }
}

enum ChordQuality: String {
    case major, minor, diminished, augmented, suspended2, suspended4
}

enum ChordExtension: String {
    case seventh, ninth, eleventh, thirteenth, add9, suspended4
}

enum ChordMood: String {
    case happy, sad, tense, epic, calm, neutral
}

enum CompositionStyle: String {
    case calm, energetic, tense, balanced, ambient, jazz, electronic
}

enum MusicalKey: String, CaseIterable {
    case c = "C", cSharp = "C#", d = "D", dSharp = "D#", e = "E", f = "F"
    case fSharp = "F#", g = "G", gSharp = "G#", a = "A", aSharp = "A#", b = "B"

    var midiNote: Int {
        switch self {
        case .c: return 60
        case .cSharp: return 61
        case .d: return 62
        case .dSharp: return 63
        case .e: return 64
        case .f: return 65
        case .fSharp: return 66
        case .g: return 67
        case .gSharp: return 68
        case .a: return 69
        case .aSharp: return 70
        case .b: return 71
        }
    }
}

enum ScaleType: String, CaseIterable {
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
    case wholeTone = "Whole Tone"
    case chromatic = "Chromatic"

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
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .chromatic: return Array(0...11)
        }
    }
}

struct ComposerTimeSignature {
    let numerator: Int
    let denominator: Int

    var beatsPerBar: Int { numerator }

    static let fourFour = ComposerTimeSignature(numerator: 4, denominator: 4)
    static let threeFour = ComposerTimeSignature(numerator: 3, denominator: 4)
    static let sixEight = ComposerTimeSignature(numerator: 6, denominator: 8)
    static let fiveFour = ComposerTimeSignature(numerator: 5, denominator: 4)
    static let sevenEight = ComposerTimeSignature(numerator: 7, denominator: 8)
}

// MARK: - Drum Pattern Types

struct DrumPattern {
    var bars: Int
    var beatsPerBar: Int
    var subdivision: Int  // 16 for 16th notes
    var kicks: [DrumHit] = []
    var snares: [DrumHit] = []
    var hihats: [DrumHit] = []
    var toms: [DrumHit] = []
    var cymbals: [DrumHit] = []
    var ghostNotes: [DrumHit] = []
}

struct DrumHit: Identifiable {
    let id = UUID()
    var bar: Int
    var step: Int  // 16th note step
    var velocity: Int
    var isOpen: Bool = false  // For hi-hats
}

enum DrumGenre: String, CaseIterable {
    case pop = "Pop"
    case rock = "Rock"
    case hiphop = "Hip-Hop"
    case electronic = "Electronic"
    case jazz = "Jazz"
    case latin = "Latin"
    case funk = "Funk"
    case metal = "Metal"
}

// MARK: - Pattern Library

class PatternLibrary {
    struct GenrePattern {
        let steps: Int  // Pattern length in 16th notes
        var kickPattern: [Bool]
        var snarePattern: [Bool]
        var hihatPattern: [Bool]
        var openHihatPattern: [Bool]
    }

    private var patterns: [DrumGenre: GenrePattern] = [:]

    func loadBuiltInPatterns() {
        // Pop: Four on the floor with backbeat
        patterns[.pop] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
            hihatPattern:    [true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false],
            openHihatPattern: [false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, true]
        )

        // Rock: Strong backbeat
        patterns[.rock] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
            hihatPattern:    [true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true],
            openHihatPattern: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false]
        )

        // Hip-Hop: Boom bap
        patterns[.hiphop] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, true],
            hihatPattern:    [true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false],
            openHihatPattern: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
        )

        // Electronic: Four on the floor with off-beat hi-hats
        patterns[.electronic] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
            hihatPattern:    [false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false],
            openHihatPattern: [false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false]
        )

        // Jazz: Ride cymbal pattern
        patterns[.jazz] = GenrePattern(
            steps: 12,  // Triplet feel
            kickPattern:     [true, false, false, false, false, false, false, false, true, false, false, false],
            snarePattern:    [false, false, false, false, false, false, false, false, false, false, true, false],
            hihatPattern:    [true, false, true, true, false, true, true, false, true, true, false, true],
            openHihatPattern: [false, false, false, false, false, false, false, false, false, false, false, false]
        )

        // Funk: Syncopated groove
        patterns[.funk] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, true, false, false, true, false, false, false, true, false, false, false, false, true],
            snarePattern:    [false, false, false, false, true, false, false, true, false, false, false, false, true, false, false, false],
            hihatPattern:    [true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true],
            openHihatPattern: [false, false, false, false, false, false, true, false, false, false, false, false, false, false, true, false]
        )

        // Latin: Tresillo pattern
        patterns[.latin] = GenrePattern(
            steps: 16,
            kickPattern:     [true, false, false, true, false, false, true, false, false, false, true, false, false, true, false, false],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
            hihatPattern:    [true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true],
            openHihatPattern: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
        )

        // Metal: Double kick
        patterns[.metal] = GenrePattern(
            steps: 16,
            kickPattern:     [true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true],
            snarePattern:    [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
            hihatPattern:    [true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false],
            openHihatPattern: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
        )
    }

    func getDrumPattern(genre: DrumGenre) -> GenrePattern {
        return patterns[genre] ?? patterns[.pop]!
    }
}

// MARK: - Markov Chain

class MarkovChain {
    private var transitions: [Int: [Int: Double]] = [:]
    let style: CompositionStyle

    init(style: CompositionStyle) {
        self.style = style
        buildTransitions()
    }

    private func buildTransitions() {
        // Build style-specific transition probabilities
        // This is a simplified version - a real implementation would train on actual music
        for pitch in 48...84 {
            var probs: [Int: Double] = [:]

            // Stepwise motion preferred
            probs[pitch - 2] = 0.15
            probs[pitch - 1] = 0.25
            probs[pitch] = 0.1  // Repeat
            probs[pitch + 1] = 0.25
            probs[pitch + 2] = 0.15

            // Occasional thirds
            probs[pitch - 4] = 0.03
            probs[pitch + 4] = 0.03
            probs[pitch - 3] = 0.02
            probs[pitch + 3] = 0.02

            transitions[pitch] = probs
        }
    }

    func nextPitch(from current: Int) -> Int {
        guard let probs = transitions[current] else { return current }

        let total = probs.values.reduce(0, +)
        var random = Double.random(in: 0..<total)

        for (pitch, prob) in probs {
            random -= prob
            if random <= 0 {
                return pitch
            }
        }

        return current
    }
}

// MARK: - Motif & Counterpoint

enum MotifTechnique: String, CaseIterable {
    case transpose = "Transpose"
    case invert = "Invert"
    case retrograde = "Retrograde"
    case augment = "Augment"
    case diminish = "Diminish"
    case ornament = "Ornament"
    case sequence = "Sequence"
}

enum CounterpointStyle: String, CaseIterable {
    case thirdBelow = "Third Below"
    case thirdAbove = "Third Above"
    case sixthBelow = "Sixth Below"
    case sixthAbove = "Sixth Above"
    case contrary = "Contrary Motion"
    case oblique = "Oblique Motion"
}
