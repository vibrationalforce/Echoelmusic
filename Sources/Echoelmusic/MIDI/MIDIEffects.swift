import SwiftUI
import CoreMIDI

/// Professional MIDI Effects System
/// Logic Pro / Ableton / Bitwig level MIDI processing
@MainActor
class MIDIEffects: ObservableObject {

    // MARK: - Arpeggiator

    class Arpeggiator: ObservableObject {
        @Published var pattern: ArpPattern = .up
        @Published var rate: NoteValue = .sixteenth
        @Published var gate: Float = 80.0  // % (note length)
        @Published var octaves: Int = 1  // 1-4 octaves
        @Published var syncToHost: Bool = true
        @Published var latch: Bool = false  // Hold notes
        @Published var velocity: VelocityMode = .original
        @Published var velocityAmount: Int = 100  // 0-127
        @Published var swing: Float = 0.0  // % (0-100)
        @Published var bypass: Bool = false

        enum ArpPattern: String, CaseIterable {
            case up = "Up"
            case down = "Down"
            case upDown = "Up-Down"
            case downUp = "Down-Up"
            case upDown2 = "Up-Down (inclusive)"
            case random = "Random"
            case order = "As Played"
            case chord = "Chord"
        }

        enum NoteValue: String, CaseIterable {
            case whole = "1/1", half = "1/2", quarter = "1/4"
            case eighth = "1/8", sixteenth = "1/16", thirtysecond = "1/32"
            case triplet8 = "1/8T", triplet16 = "1/16T"
        }

        enum VelocityMode: String, CaseIterable {
            case original = "Original"
            case fixed = "Fixed"
            case ascending = "Ascending"
            case descending = "Descending"
            case random = "Random"
        }

        private var heldNotes: [UInt8] = []
        private var arpStep: Int = 0

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            if on {
                heldNotes.append(note)
                if !latch && heldNotes.count == 1 {
                    arpStep = 0
                }
            } else {
                heldNotes.removeAll { $0 == note }
                if !latch && heldNotes.isEmpty {
                    arpStep = 0
                }
            }

            return []  // Arp notes generated on clock tick
        }

        func tick(tempo: Double) -> [MIDIEvent] {
            guard !heldNotes.isEmpty || (latch && !heldNotes.isEmpty) else {
                return []
            }

            let sortedNotes = generateArpSequence()
            guard !sortedNotes.isEmpty else { return [] }

            let noteIndex = arpStep % sortedNotes.count
            let note = sortedNotes[noteIndex]

            let vel = calculateVelocity(step: arpStep)
            arpStep += 1

            return [
                MIDIEvent(type: .noteOn, note: note, velocity: vel, timestamp: 0),
                MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: calculateGateTime(tempo: tempo))
            ]
        }

        private func generateArpSequence() -> [UInt8] {
            let sorted = heldNotes.sorted()
            var sequence: [UInt8] = []

            for octave in 0..<octaves {
                let transposed = sorted.map { $0 + UInt8(octave * 12) }

                switch pattern {
                case .up:
                    sequence.append(contentsOf: transposed)
                case .down:
                    sequence.append(contentsOf: transposed.reversed())
                case .upDown:
                    sequence.append(contentsOf: transposed)
                    sequence.append(contentsOf: transposed.dropFirst().dropLast().reversed())
                case .upDown2:
                    sequence.append(contentsOf: transposed)
                    sequence.append(contentsOf: transposed.reversed())
                case .downUp:
                    sequence.append(contentsOf: transposed.reversed())
                    sequence.append(contentsOf: transposed.dropFirst().dropLast())
                case .random:
                    sequence.append(contentsOf: transposed.shuffled())
                case .order:
                    sequence.append(contentsOf: transposed)
                case .chord:
                    sequence = transposed
                    break
                }
            }

            return sequence
        }

        private func calculateVelocity(step: Int) -> UInt8 {
            switch velocity {
            case .original:
                return UInt8(velocityAmount)
            case .fixed:
                return UInt8(velocityAmount)
            case .ascending:
                let count = heldNotes.count * octaves
                return UInt8(min(127, 60 + (step % count) * 10))
            case .descending:
                let count = heldNotes.count * octaves
                return UInt8(max(40, 127 - (step % count) * 10))
            case .random:
                return UInt8.random(in: 40...127)
            }
        }

        private func calculateGateTime(tempo: Double) -> UInt64 {
            // Calculate gate time based on tempo and gate %
            return 100000  // Microseconds
        }
    }

    // MARK: - Chord Generator

    class ChordGenerator: ObservableObject {
        @Published var chordType: ChordType = .major
        @Published var voicing: Voicing = .close
        @Published var inversion: Int = 0  // 0-3
        @Published var octaveSpread: Int = 0  // 0-2
        @Published var velocitySpread: Int = 0  // Velocity variation between notes
        @Published var humanize: Int = 0  // Timing variation (ms)
        @Published var bypass: Bool = false

        enum ChordType: String, CaseIterable {
            // Triads
            case major = "Major"
            case minor = "Minor"
            case diminished = "Diminished"
            case augmented = "Augmented"
            case sus2 = "Sus2"
            case sus4 = "Sus4"

            // 7th chords
            case major7 = "Major 7"
            case minor7 = "Minor 7"
            case dominant7 = "Dominant 7"
            case diminished7 = "Diminished 7"
            case halfDiminished7 = "Half Diminished 7"

            // Extended
            case major9 = "Major 9"
            case minor9 = "Minor 9"
            case dominant9 = "Dominant 9"
            case major11 = "Major 11"
            case dominant13 = "Dominant 13"

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
                case .halfDiminished7: return [0, 3, 6, 10]
                case .major9: return [0, 4, 7, 11, 14]
                case .minor9: return [0, 3, 7, 10, 14]
                case .dominant9: return [0, 4, 7, 10, 14]
                case .major11: return [0, 4, 7, 11, 14, 17]
                case .dominant13: return [0, 4, 7, 10, 14, 21]
                }
            }
        }

        enum Voicing: String, CaseIterable {
            case close = "Close"
            case open = "Open"
            case drop2 = "Drop 2"
            case drop3 = "Drop 3"
            case spread = "Spread"
        }

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            guard on else {
                // Note off - turn off all chord notes
                return generateChordNotes(root: note, velocity: 0, noteOn: false)
            }

            return generateChordNotes(root: note, velocity: velocity, noteOn: true)
        }

        private func generateChordNotes(root: UInt8, velocity: UInt8, noteOn: Bool) -> [MIDIEvent] {
            var events: [MIDIEvent] = []
            let intervals = applyVoicing(chordType.intervals)

            for (index, interval) in intervals.enumerated() {
                let note = root + UInt8(interval)
                let vel = velocity + UInt8(Int.random(in: -velocitySpread...velocitySpread))
                let timestamp = UInt64(Int.random(in: 0...humanize))

                events.append(MIDIEvent(
                    type: noteOn ? .noteOn : .noteOff,
                    note: note,
                    velocity: vel,
                    timestamp: timestamp
                ))
            }

            return events
        }

        private func applyVoicing(_ intervals: [Int]) -> [Int] {
            var voiced = intervals

            // Apply inversion
            for _ in 0..<inversion {
                if let first = voiced.first {
                    voiced.removeFirst()
                    voiced.append(first + 12)
                }
            }

            // Apply voicing
            switch voicing {
            case .close:
                break  // No modification
            case .open:
                // Spread every other note up an octave
                for i in stride(from: 1, to: voiced.count, by: 2) {
                    voiced[i] += 12
                }
            case .drop2:
                // Drop second note down an octave
                if voiced.count >= 2 {
                    voiced[1] -= 12
                }
            case .drop3:
                // Drop third note down an octave
                if voiced.count >= 3 {
                    voiced[2] -= 12
                }
            case .spread:
                // Spread notes across multiple octaves
                for i in 1..<voiced.count {
                    voiced[i] += 12 * i
                }
            }

            return voiced.sorted()
        }
    }

    // MARK: - Scale Quantizer

    class ScaleQuantizer: ObservableObject {
        @Published var scale: Scale = .major
        @Published var root: Note = .c
        @Published var mode: QuantizeMode = .nearest
        @Published var strength: Float = 100.0  // % (0 = bypass, 100 = hard quantize)
        @Published var bypass: Bool = false

        enum Scale: String, CaseIterable {
            case major = "Major (Ionian)"
            case minor = "Minor (Aeolian)"
            case dorian = "Dorian"
            case phrygian = "Phrygian"
            case lydian = "Lydian"
            case mixolydian = "Mixolydian"
            case locrian = "Locrian"
            case harmonicMinor = "Harmonic Minor"
            case melodicMinor = "Melodic Minor"
            case pentatonicMajor = "Pentatonic Major"
            case pentatonicMinor = "Pentatonic Minor"
            case blues = "Blues"
            case wholeTone = "Whole Tone"
            case chromatic = "Chromatic"

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
                case .wholeTone: return [0, 2, 4, 6, 8, 10]
                case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
                }
            }
        }

        enum Note: Int, CaseIterable {
            case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

            var name: String {
                ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue]
            }
        }

        enum QuantizeMode: String, CaseIterable {
            case nearest = "Nearest"
            case up = "Up"
            case down = "Down"
        }

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            guard on else {
                return [MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: 0)]
            }

            let quantized = quantizeToScale(note)
            return [MIDIEvent(type: .noteOn, note: quantized, velocity: velocity, timestamp: 0)]
        }

        private func quantizeToScale(_ note: UInt8) -> UInt8 {
            let octave = Int(note) / 12
            let pitchClass = Int(note) % 12

            let rootOffset = (pitchClass - root.rawValue + 12) % 12
            let scaleNotes = scale.intervals.map { ($0 + root.rawValue) % 12 }

            let quantizedPitchClass: Int
            switch mode {
            case .nearest:
                quantizedPitchClass = scaleNotes.min(by: {
                    abs($0 - rootOffset) < abs($1 - rootOffset)
                }) ?? pitchClass
            case .up:
                quantizedPitchClass = scaleNotes.first { $0 >= rootOffset } ?? scaleNotes.first ?? pitchClass
            case .down:
                quantizedPitchClass = scaleNotes.last { $0 <= rootOffset } ?? scaleNotes.last ?? pitchClass
            }

            return UInt8(octave * 12 + (quantizedPitchClass + root.rawValue) % 12)
        }
    }

    // MARK: - MIDI Echo/Delay

    class MIDIEcho: ObservableObject {
        @Published var delay: Float = 500.0  // ms
        @Published var feedback: Int = 50  // % (0-100)
        @Published var velocityDecay: Int = 10  // % per echo
        @Published var syncToTempo: Bool = true
        @Published var noteValue: NoteValue = .eighth
        @Published var maxEchoes: Int = 8
        @Published var bypass: Bool = false

        enum NoteValue: String, CaseIterable {
            case quarter = "1/4", eighth = "1/8", sixteenth = "1/16"
            case triplet8 = "1/8T", triplet16 = "1/16T", dotted8 = "1/8."
        }

        private var echoBuffer: [(note: UInt8, velocity: UInt8, time: UInt64)] = []

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool, tempo: Double) -> [MIDIEvent] {
            guard on else { return [] }

            var events: [MIDIEvent] = []
            events.append(MIDIEvent(type: .noteOn, note: note, velocity: velocity, timestamp: 0))

            // Generate echoes
            var echoVel = Int(velocity)
            var echoTime: UInt64 = UInt64(delay * 1000)  // Convert to microseconds

            for i in 1...maxEchoes {
                echoVel = echoVel * (100 - velocityDecay) / 100
                guard echoVel > 10 else { break }

                events.append(MIDIEvent(type: .noteOn, note: note, velocity: UInt8(echoVel), timestamp: echoTime))
                events.append(MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: echoTime + 50000))

                echoTime += UInt64(delay * 1000)

                if feedback < Int.random(in: 0...100) {
                    break
                }
            }

            return events
        }
    }

    // MARK: - Randomizer

    class Randomizer: ObservableObject {
        @Published var pitchAmount: Int = 0  // Semitones (0-12)
        @Published var velocityAmount: Int = 0  // % (0-100)
        @Published var timingAmount: Int = 0  // ms (0-100)
        @Published var gateAmount: Int = 0  // % (0-100)
        @Published var probability: Int = 100  // % chance of note triggering
        @Published var bypass: Bool = false

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            guard on else {
                return [MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: 0)]
            }

            // Probability gate
            guard Int.random(in: 1...100) <= probability else {
                return []
            }

            // Randomize pitch
            let pitchVariation = Int.random(in: -pitchAmount...pitchAmount)
            let randomizedNote = UInt8(max(0, min(127, Int(note) + pitchVariation)))

            // Randomize velocity
            let velVariation = Int.random(in: -velocityAmount...velocityAmount)
            let randomizedVel = UInt8(max(1, min(127, Int(velocity) + velVariation)))

            // Randomize timing
            let timingVariation = UInt64(Int.random(in: -timingAmount...timingAmount) * 1000)

            return [MIDIEvent(
                type: .noteOn,
                note: randomizedNote,
                velocity: randomizedVel,
                timestamp: timingVariation
            )]
        }
    }

    // MARK: - Humanizer

    class Humanizer: ObservableObject {
        @Published var timing: Int = 10  // ms (0-50)
        @Published var velocity: Int = 10  // % (0-30)
        @Published var duration: Int = 5  // % (0-20)
        @Published var swing: Float = 0.0  // % (0-100)
        @Published var bypass: Bool = false

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            guard on else {
                return [MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: 0)]
            }

            // Humanize timing
            let timingOffset = UInt64(Int.random(in: -timing...timing) * 1000)

            // Humanize velocity
            let velVariation = Int.random(in: -velocity...velocity)
            let humanizedVel = UInt8(max(1, min(127, Int(velocity) * (100 + velVariation) / 100)))

            return [MIDIEvent(
                type: .noteOn,
                note: note,
                velocity: humanizedVel,
                timestamp: timingOffset
            )]
        }
    }

    // MARK: - Transpose

    class Transpose: ObservableObject {
        @Published var semitones: Int = 0  // -24 to +24
        @Published var octaves: Int = 0  // -4 to +4
        @Published var constrainToRange: Bool = true
        @Published var bypass: Bool = false

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            let transposed = Int(note) + semitones + (octaves * 12)
            let finalNote = UInt8(max(0, min(127, transposed)))

            return [MIDIEvent(
                type: on ? .noteOn : .noteOff,
                note: finalNote,
                velocity: velocity,
                timestamp: 0
            )]
        }
    }

    // MARK: - Velocity Processor

    class VelocityProcessor: ObservableObject {
        @Published var mode: VelocityMode = .add
        @Published var amount: Int = 0  // -64 to +64
        @Published var curve: Float = 1.0  // 0.1 to 3.0 (exponential curve)
        @Published var compressThreshold: Int = 100
        @Published var compressRatio: Float = 2.0
        @Published var randomAmount: Int = 0
        @Published var bypass: Bool = false

        enum VelocityMode: String, CaseIterable {
            case add = "Add"
            case scale = "Scale"
            case compress = "Compress"
            case expand = "Expand"
            case fixed = "Fixed"
            case curve = "Curve"
        }

        func processNote(_ note: UInt8, velocity: UInt8, on: Bool) -> [MIDIEvent] {
            guard on else {
                return [MIDIEvent(type: .noteOff, note: note, velocity: 0, timestamp: 0)]
            }

            var processedVel = Int(velocity)

            switch mode {
            case .add:
                processedVel += amount
            case .scale:
                processedVel = processedVel * (100 + amount) / 100
            case .compress:
                if processedVel > compressThreshold {
                    let over = processedVel - compressThreshold
                    processedVel = compressThreshold + Int(Float(over) / compressRatio)
                }
            case .expand:
                processedVel = Int(pow(Float(processedVel) / 127.0, curve) * 127.0)
            case .fixed:
                processedVel = amount + 64
            case .curve:
                processedVel = Int(pow(Float(processedVel) / 127.0, curve) * 127.0)
            }

            // Add randomization
            if randomAmount > 0 {
                processedVel += Int.random(in: -randomAmount...randomAmount)
            }

            let finalVel = UInt8(max(1, min(127, processedVel)))

            return [MIDIEvent(type: .noteOn, note: note, velocity: finalVel, timestamp: 0)]
        }
    }

    // MARK: - CC Mapper

    class CCMapper: ObservableObject {
        @Published var mappings: [CCMapping] = []
        @Published var bypass: Bool = false

        struct CCMapping: Identifiable {
            let id = UUID()
            var sourceCC: Int
            var targetCC: Int
            var minInput: Int
            var maxInput: Int
            var minOutput: Int
            var maxOutput: Int
            var curve: Float
            var invert: Bool
        }

        func processCC(_ cc: Int, value: Int) -> [(cc: Int, value: Int)] {
            var events: [(cc: Int, value: Int)] = []

            for mapping in mappings {
                guard mapping.sourceCC == cc else { continue }

                // Map input range to output range
                let inputNorm = Float(value - mapping.minInput) / Float(mapping.maxInput - mapping.minInput)
                let curved = pow(inputNorm, mapping.curve)
                let inverted = mapping.invert ? (1.0 - curved) : curved
                let output = mapping.minOutput + Int(inverted * Float(mapping.maxOutput - mapping.minOutput))

                events.append((cc: mapping.targetCC, value: max(0, min(127, output))))
            }

            return events
        }
    }

    // MARK: - MIDI Event

    struct MIDIEvent {
        let type: EventType
        let note: UInt8
        let velocity: UInt8
        let timestamp: UInt64  // Microseconds from now

        enum EventType {
            case noteOn, noteOff, cc
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
                case arpeggiator, chordGenerator, scaleQuantizer
                case midiEcho, randomizer, humanizer
                case transpose, velocityProcessor, ccMapper
            }
        }

        func processEvent(_ event: MIDIEvent) -> [MIDIEvent] {
            var events = [event]

            for effect in effects where !effect.bypass && effect.enabled {
                events = processWithEffect(events, effect: effect)
            }

            return events
        }

        private func processWithEffect(_ events: [MIDIEvent], effect: MIDIEffect) -> [MIDIEvent] {
            // Route to appropriate effect
            return events
        }
    }
}
