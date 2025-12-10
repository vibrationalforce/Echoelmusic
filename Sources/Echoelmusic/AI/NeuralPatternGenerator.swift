import Foundation

/// Neural Pattern Generator
///
/// AI-powered pattern generation for:
/// - Drum patterns (genre-specific)
/// - Basslines (chord-following)
/// - Arpeggios
/// - Rhythmic variations
/// - Fill generation
///
public final class NeuralPatternGenerator {

    // MARK: - Types

    /// Music style for generation
    public enum MusicStyle: String, CaseIterable {
        case electronic = "Electronic"
        case hiphop = "Hip-Hop"
        case rock = "Rock"
        case jazz = "Jazz"
        case latin = "Latin"
        case funk = "Funk"
        case reggae = "Reggae"
        case dnb = "Drum & Bass"
        case house = "House"
        case trap = "Trap"
    }

    /// Chord symbol
    public struct ChordSymbol {
        public let root: String
        public let type: ChordType

        public init(root: String, type: ChordType) {
            self.root = root
            self.type = type
        }

        public enum ChordType {
            case major, minor, major7, minor7, dominant7, diminished, augmented, sus4, sus2
        }

        var rootMIDI: Int {
            let noteMap: [String: Int] = [
                "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
                "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
                "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11
            ]

            // Extract root note from chord symbol (e.g., "Cmaj7" -> "C", "F#m" -> "F#")
            var rootNote = root
            if root.count > 1 {
                let secondChar = root[root.index(root.startIndex, offsetBy: 1)]
                if secondChar != "#" && secondChar != "b" {
                    rootNote = String(root.first!)
                } else {
                    rootNote = String(root.prefix(2))
                }
            }

            return noteMap[rootNote] ?? 0
        }
    }

    /// Generated drum pattern
    public struct DrumPattern {
        public let kicks: [Bool]      // Kick drum hits
        public let snares: [Bool]     // Snare hits
        public let hihats: [Bool]     // Hi-hat hits (can include open/closed)
        public let percussion: [Bool] // Additional percussion
        public let velocities: [[Int]] // Velocity for each instrument [kicks, snares, hihats, perc]
        public let style: MusicStyle
        public let bars: Int
    }

    /// Bassline note
    public struct BassNote {
        public let pitch: Int
        public let startStep: Int
        public let duration: Int  // In steps
        public let velocity: Int
    }

    /// Arpeggio pattern
    public enum ArpeggioPattern: CaseIterable {
        case up, down, upDown, downUp, random, order
    }

    /// Note rate
    public enum NoteRate: CaseIterable {
        case whole, half, quarter, eighth, sixteenth, thirtySecond, triplet
    }

    // MARK: - Neural Network Weights

    private var drumPatternWeights: [[Float]] = []
    private var basslineWeights: [[Float]] = []
    private var variationWeights: [[Float]] = []

    // MARK: - Style Templates

    private var styleTemplates: [MusicStyle: DrumTemplate] = [:]

    private struct DrumTemplate {
        let kickPattern: [Float]      // Probability per step
        let snarePattern: [Float]
        let hihatPattern: [Float]
        let percPattern: [Float]
        let swingAmount: Float
        let ghostNoteProb: Float
    }

    // MARK: - Initialization

    public init() {
        loadNeuralWeights()
        loadStyleTemplates()
    }

    private func loadNeuralWeights() {
        // Initialize neural weights for pattern generation
        let scale = sqrt(2.0 / 64.0)

        // Drum pattern weights
        drumPatternWeights = (0..<32).map { _ in
            (0..<64).map { _ in Float.random(in: -scale...scale) }
        }

        // Bassline weights
        basslineWeights = (0..<24).map { _ in
            (0..<48).map { _ in Float.random(in: -scale...scale) }
        }

        // Variation weights
        variationWeights = (0..<16).map { _ in
            (0..<32).map { _ in Float.random(in: -scale...scale) }
        }
    }

    private func loadStyleTemplates() {
        // 16-step patterns (one bar at 16th notes)

        // Electronic / EDM
        styleTemplates[.electronic] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
            percPattern:  [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
            swingAmount: 0,
            ghostNoteProb: 0.1
        )

        // Hip-Hop
        styleTemplates[.hiphop] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            percPattern:  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
            swingAmount: 0.2,
            ghostNoteProb: 0.15
        )

        // Rock
        styleTemplates[.rock] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
            percPattern:  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
            swingAmount: 0,
            ghostNoteProb: 0.2
        )

        // Jazz
        styleTemplates[.jazz] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0],
            hihatPattern: [1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
            percPattern:  [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
            swingAmount: 0.5,
            ghostNoteProb: 0.3
        )

        // Latin
        styleTemplates[.latin] = DrumTemplate(
            kickPattern: [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1],
            hihatPattern: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
            percPattern:  [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
            swingAmount: 0.1,
            ghostNoteProb: 0.25
        )

        // Funk
        styleTemplates[.funk] = DrumTemplate(
            kickPattern: [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1],
            hihatPattern: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            percPattern:  [0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0],
            swingAmount: 0.15,
            ghostNoteProb: 0.35
        )

        // House
        styleTemplates[.house] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
            percPattern:  [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
            swingAmount: 0,
            ghostNoteProb: 0.1
        )

        // Drum & Bass
        styleTemplates[.dnb] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            percPattern:  [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
            swingAmount: 0,
            ghostNoteProb: 0.2
        )

        // Trap
        styleTemplates[.trap] = DrumTemplate(
            kickPattern: [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            hihatPattern: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            percPattern:  [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
            swingAmount: 0,
            ghostNoteProb: 0.1
        )

        // Reggae
        styleTemplates[.reggae] = DrumTemplate(
            kickPattern: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            snarePattern: [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
            hihatPattern: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
            percPattern:  [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
            swingAmount: 0.3,
            ghostNoteProb: 0.15
        )
    }

    // MARK: - Drum Pattern Generation

    /// Generate a drum pattern for the specified style
    public func generateDrumPattern(
        style: MusicStyle,
        bars: Int,
        tempo: Int
    ) async -> DrumPattern {
        guard let template = styleTemplates[style] else {
            return DrumPattern(
                kicks: [], snares: [], hihats: [], percussion: [],
                velocities: [], style: style, bars: bars
            )
        }

        let stepsPerBar = 16
        let totalSteps = bars * stepsPerBar

        var kicks = [Bool](repeating: false, count: totalSteps)
        var snares = [Bool](repeating: false, count: totalSteps)
        var hihats = [Bool](repeating: false, count: totalSteps)
        var percussion = [Bool](repeating: false, count: totalSteps)

        var kickVelocities = [Int](repeating: 0, count: totalSteps)
        var snareVelocities = [Int](repeating: 0, count: totalSteps)
        var hihatVelocities = [Int](repeating: 0, count: totalSteps)
        var percVelocities = [Int](repeating: 0, count: totalSteps)

        for bar in 0..<bars {
            for step in 0..<stepsPerBar {
                let globalStep = bar * stepsPerBar + step
                let templateStep = step % template.kickPattern.count

                // Kick
                if Float.random(in: 0..<1) < template.kickPattern[templateStep] {
                    kicks[globalStep] = true
                    kickVelocities[globalStep] = generateVelocity(base: 100, step: step)
                }

                // Snare
                if Float.random(in: 0..<1) < template.snarePattern[templateStep] {
                    snares[globalStep] = true
                    snareVelocities[globalStep] = generateVelocity(base: 90, step: step)
                }

                // Hi-hat
                if Float.random(in: 0..<1) < template.hihatPattern[templateStep] {
                    hihats[globalStep] = true
                    hihatVelocities[globalStep] = generateVelocity(base: 70, step: step)
                }

                // Percussion
                if Float.random(in: 0..<1) < template.percPattern[templateStep] {
                    percussion[globalStep] = true
                    percVelocities[globalStep] = generateVelocity(base: 60, step: step)
                }

                // Add ghost notes
                if Float.random(in: 0..<1) < template.ghostNoteProb && !snares[globalStep] {
                    snares[globalStep] = true
                    snareVelocities[globalStep] = Int.random(in: 20...40)
                }
            }
        }

        // Add variation to last bar
        if bars > 1 {
            addFill(
                kicks: &kicks,
                snares: &snares,
                hihats: &hihats,
                startStep: (bars - 1) * stepsPerBar + 12,
                style: style
            )
        }

        return DrumPattern(
            kicks: kicks,
            snares: snares,
            hihats: hihats,
            percussion: percussion,
            velocities: [kickVelocities, snareVelocities, hihatVelocities, percVelocities],
            style: style,
            bars: bars
        )
    }

    private func generateVelocity(base: Int, step: Int) -> Int {
        // Emphasize downbeats
        let emphasis = (step % 4 == 0) ? 15 : 0
        let humanization = Int.random(in: -10...10)
        return max(1, min(127, base + emphasis + humanization))
    }

    private func addFill(
        kicks: inout [Bool],
        snares: inout [Bool],
        hihats: inout [Bool],
        startStep: Int,
        style: MusicStyle
    ) {
        guard startStep < kicks.count - 3 else { return }

        // Simple fill pattern
        for i in 0..<4 {
            let step = startStep + i
            if step < snares.count {
                snares[step] = true
                kicks[step] = (i == 3)  // Kick on last step
            }
        }
    }

    // MARK: - Bassline Generation

    /// Generate a bassline following chord progression
    public func generateBassline(
        chords: [ChordSymbol],
        style: MusicStyle,
        bars: Int
    ) async -> [BassNote] {
        guard !chords.isEmpty else { return [] }

        var notes: [BassNote] = []
        let stepsPerBar = 16
        let stepsPerChord = (bars * stepsPerBar) / chords.count

        for (chordIndex, chord) in chords.enumerated() {
            let startStep = chordIndex * stepsPerChord
            let rootNote = 36 + chord.rootMIDI  // Bass octave (C2 = 36)

            // Generate bass pattern based on style
            let pattern = getBassPatternForStyle(style, stepsPerChord: stepsPerChord)

            for (stepOffset, noteInfo) in pattern.enumerated() {
                if noteInfo.play {
                    let pitch = rootNote + noteInfo.interval
                    notes.append(BassNote(
                        pitch: pitch,
                        startStep: startStep + stepOffset,
                        duration: noteInfo.duration,
                        velocity: noteInfo.velocity
                    ))
                }
            }
        }

        return notes
    }

    private struct BassStepInfo {
        let play: Bool
        let interval: Int  // From root
        let duration: Int
        let velocity: Int
    }

    private func getBassPatternForStyle(_ style: MusicStyle, stepsPerChord: Int) -> [BassStepInfo] {
        var pattern: [BassStepInfo] = []

        switch style {
        case .electronic, .house:
            // Pumping 8th note bass
            for i in 0..<stepsPerChord {
                let play = (i % 2 == 0)
                pattern.append(BassStepInfo(play: play, interval: 0, duration: 2, velocity: 100))
            }

        case .funk:
            // Syncopated funky bass
            let funkPattern = [true, false, false, true, false, false, true, false,
                              false, true, false, false, true, false, true, false]
            for i in 0..<stepsPerChord {
                let play = funkPattern[i % 16]
                let interval = (i % 8 == 3) ? 7 : 0  // Fifth on some beats
                pattern.append(BassStepInfo(play: play, interval: interval, duration: 1, velocity: 90 + Int.random(in: -10...10)))
            }

        case .rock:
            // Root-fifth pattern
            for i in 0..<stepsPerChord {
                let play = (i % 4 == 0) || (i % 4 == 2)
                let interval = (i % 8 >= 4) ? 7 : 0  // Alternate root and fifth
                pattern.append(BassStepInfo(play: play, interval: interval, duration: 2, velocity: 95))
            }

        case .hiphop, .trap:
            // Sparse, heavy bass
            let trapPattern = [true, false, false, false, false, false, true, false,
                              false, false, true, false, false, false, false, false]
            for i in 0..<stepsPerChord {
                let play = trapPattern[i % 16]
                pattern.append(BassStepInfo(play: play, interval: 0, duration: 3, velocity: 110))
            }

        case .jazz:
            // Walking bass line
            let intervals = [0, 2, 4, 5, 7, 9, 11, 12]
            for i in 0..<stepsPerChord {
                let play = (i % 4 == 0)
                let interval = intervals[i % intervals.count]
                pattern.append(BassStepInfo(play: play, interval: interval, duration: 4, velocity: 80))
            }

        default:
            // Simple root note pattern
            for i in 0..<stepsPerChord {
                let play = (i % 4 == 0)
                pattern.append(BassStepInfo(play: play, interval: 0, duration: 4, velocity: 90))
            }
        }

        return pattern
    }

    // MARK: - Arpeggio Generation

    /// Generate an arpeggio pattern
    public func generateArpeggio(
        chord: ChordSymbol,
        pattern: ArpeggioPattern,
        octaves: Int,
        rate: NoteRate
    ) async -> [BassNote] {
        // Get chord tones
        var chordTones = getChordTones(chord)

        // Extend to multiple octaves
        var extendedTones: [Int] = []
        for octave in 0..<octaves {
            for tone in chordTones {
                extendedTones.append(tone + octave * 12)
            }
        }

        // Apply pattern
        var orderedTones: [Int] = []

        switch pattern {
        case .up:
            orderedTones = extendedTones
        case .down:
            orderedTones = extendedTones.reversed()
        case .upDown:
            orderedTones = extendedTones + extendedTones.dropLast().reversed()
        case .downUp:
            orderedTones = extendedTones.reversed() + extendedTones.dropFirst()
        case .random:
            orderedTones = extendedTones.shuffled()
        case .order:
            orderedTones = extendedTones
        }

        // Convert to notes
        let basePitch = 48 + chord.rootMIDI  // C3
        let stepDuration = getStepDuration(rate)

        var notes: [BassNote] = []
        for (i, interval) in orderedTones.enumerated() {
            notes.append(BassNote(
                pitch: basePitch + interval,
                startStep: i * stepDuration,
                duration: stepDuration,
                velocity: 80 + Int.random(in: -5...5)
            ))
        }

        return notes
    }

    private func getChordTones(_ chord: ChordSymbol) -> [Int] {
        switch chord.type {
        case .major:
            return [0, 4, 7]
        case .minor:
            return [0, 3, 7]
        case .major7:
            return [0, 4, 7, 11]
        case .minor7:
            return [0, 3, 7, 10]
        case .dominant7:
            return [0, 4, 7, 10]
        case .diminished:
            return [0, 3, 6]
        case .augmented:
            return [0, 4, 8]
        case .sus4:
            return [0, 5, 7]
        case .sus2:
            return [0, 2, 7]
        }
    }

    private func getStepDuration(_ rate: NoteRate) -> Int {
        switch rate {
        case .whole: return 16
        case .half: return 8
        case .quarter: return 4
        case .eighth: return 2
        case .sixteenth: return 1
        case .thirtySecond: return 1
        case .triplet: return 2  // Simplified
        }
    }

    // MARK: - Pattern Variation

    /// Generate a variation of an existing drum pattern
    public func generateVariation(
        of pattern: DrumPattern,
        intensity: Float  // 0.0 = subtle, 1.0 = completely different
    ) async -> DrumPattern {
        var kicks = pattern.kicks
        var snares = pattern.snares
        var hihats = pattern.hihats
        var percussion = pattern.percussion

        let numChanges = Int(Float(kicks.count) * intensity * 0.3)

        for _ in 0..<numChanges {
            let step = Int.random(in: 0..<kicks.count)

            // Randomly modify one of the instruments
            switch Int.random(in: 0..<4) {
            case 0:
                kicks[step] = !kicks[step]
            case 1:
                snares[step] = !snares[step]
            case 2:
                hihats[step] = !hihats[step]
            default:
                percussion[step] = !percussion[step]
            }
        }

        return DrumPattern(
            kicks: kicks,
            snares: snares,
            hihats: hihats,
            percussion: percussion,
            velocities: pattern.velocities,
            style: pattern.style,
            bars: pattern.bars
        )
    }
}
