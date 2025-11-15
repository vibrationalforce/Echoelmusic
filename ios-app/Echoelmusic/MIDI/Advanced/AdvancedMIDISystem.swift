import Foundation
import CoreMIDI
import Combine

// MARK: - Advanced MIDI System
// Professional MIDI features with MPE, microtuning, and advanced routing

/// Advanced MIDI processing and routing system
@MainActor
class AdvancedMIDISystem: ObservableObject {

    // MARK: - Published Properties
    @Published var midiDevices: [MIDIDevice] = []
    @Published var midiRouting: [MIDIRoute] = []
    @Published var mpeConfiguration: MPEConfiguration = MPEConfiguration()
    @Published var microtuning: MicrotuningSettings?
    @Published var arpeggiator: ArpeggiatorSettings = ArpeggiatorSettings()

    // MARK: - MIDI Device
    struct MIDIDevice: Identifiable {
        var id: MIDIEndpointRef
        var name: String
        var manufacturer: String
        var isInput: Bool
        var isOutput: Bool
        var connected: Bool
        var channels: [Int]  // Active MIDI channels
    }

    // MARK: - MIDI Routing
    struct MIDIRoute: Identifiable {
        var id: UUID
        var source: MIDISource
        var destination: MIDIDestination
        var channelMapping: [Int: Int]  // Input channel -> Output channel
        var transpose: Int  // Semitones
        var velocityCurve: VelocityCurve
        var filters: [MIDIFilter]
        var processors: [MIDIProcessor]
        var enabled: Bool

        enum MIDISource {
            case device(MIDIEndpointRef)
            case track(UUID)
            case generator(MIDIGenerator)
        }

        enum MIDIDestination {
            case device(MIDIEndpointRef)
            case track(UUID)
            case instrument(UUID)
        }
    }

    // MARK: - MPE (MIDI Polyphonic Expression)
    struct MPEConfiguration {
        var enabled: Bool = false
        var masterChannel: Int = 1  // Usually channel 1 or 16
        var memberChannels: [Int] = Array(2...15)  // Remaining channels
        var voiceAllocation: VoiceAllocation = .roundRobin
        var pitchBendRange: Int = 48  // Semitones
        var slideSensitivity: Float = 1.0

        enum VoiceAllocation {
            case roundRobin, oldest, lowestNote, highestNote
        }
    }

    struct MPEVoice {
        var channel: Int
        var note: UInt8
        var velocity: UInt8
        var pitchBend: Float  // -1 to 1
        var pressure: Float   // 0 to 1
        var timbre: Float     // CC74, 0 to 1
        var startTime: Date
    }

    // MARK: - Microtuning
    struct MicrotuningSettings {
        var tuningSystem: TuningSystem
        var rootNote: Int  // MIDI note number
        var customTuning: [Float]?  // Cents deviation from equal temperament

        enum TuningSystem: String, CaseIterable {
            case equalTemperament
            case justIntonation
            case pythagorean
            case meantone
            case werckmeister
            case kirnberger
            case custom

            var displayName: String {
                switch self {
                case .equalTemperament: return "12-TET (Equal Temperament)"
                case .justIntonation: return "Just Intonation (5-limit)"
                case .pythagorean: return "Pythagorean"
                case .meantone: return "Quarter-Comma Meantone"
                case .werckmeister: return "Werckmeister III"
                case .kirnberger: return "Kirnberger III"
                case .custom: return "Custom Tuning"
                }
            }
        }

        // Get frequency for MIDI note
        func frequency(forNote note: Int) -> Float {
            let a4Frequency: Float = 440.0
            let a4Note: Int = 69

            switch tuningSystem {
            case .equalTemperament:
                let semitones = Float(note - a4Note)
                return a4Frequency * pow(2.0, semitones / 12.0)

            case .justIntonation:
                return justIntonationFrequency(note: note, root: rootNote)

            case .pythagorean:
                return pythagoreanFrequency(note: note, root: rootNote)

            case .custom:
                if let cents = customTuning?[note % 12] {
                    let semitones = Float(note - a4Note) + (cents / 100.0)
                    return a4Frequency * pow(2.0, semitones / 12.0)
                }
                return frequency(forNote: note)

            default:
                return frequency(forNote: note)
            }
        }

        private func justIntonationFrequency(note: Int, root: Int) -> Float {
            let ratios: [Float] = [
                1.0,       // 1/1  - Unison
                16.0/15.0, // 16/15 - Minor second
                9.0/8.0,   // 9/8   - Major second
                6.0/5.0,   // 6/5   - Minor third
                5.0/4.0,   // 5/4   - Major third
                4.0/3.0,   // 4/3   - Perfect fourth
                45.0/32.0, // 45/32 - Augmented fourth
                3.0/2.0,   // 3/2   - Perfect fifth
                8.0/5.0,   // 8/5   - Minor sixth
                5.0/3.0,   // 5/3   - Major sixth
                16.0/9.0,  // 16/9  - Minor seventh
                15.0/8.0   // 15/8  - Major seventh
            ]

            let octaves = (note - root) / 12
            let degree = (note - root) % 12

            let rootFreq: Float = 440.0 * pow(2.0, Float(root - 69) / 12.0)
            return rootFreq * ratios[degree] * pow(2.0, Float(octaves))
        }

        private func pythagoreanFrequency(note: Int, root: Int) -> Float {
            // Pythagorean tuning based on perfect fifths
            let ratios: [Float] = [
                1.0,         // 1/1
                256.0/243.0, // Pythagorean minor second
                9.0/8.0,     // Major second
                32.0/27.0,   // Pythagorean minor third
                81.0/64.0,   // Pythagorean major third
                4.0/3.0,     // Perfect fourth
                1024.0/729.0,// Augmented fourth
                3.0/2.0,     // Perfect fifth
                128.0/81.0,  // Pythagorean minor sixth
                27.0/16.0,   // Pythagorean major sixth
                16.0/9.0,    // Pythagorean minor seventh
                243.0/128.0  // Pythagorean major seventh
            ]

            let octaves = (note - root) / 12
            let degree = (note - root) % 12

            let rootFreq: Float = 440.0 * pow(2.0, Float(root - 69) / 12.0)
            return rootFreq * ratios[degree] * pow(2.0, Float(octaves))
        }
    }

    // MARK: - Arpeggiator
    struct ArpeggiatorSettings {
        var enabled: Bool = false
        var mode: ArpMode = .up
        var rate: NoteValue = .sixteenth
        var octaves: Int = 1
        var gateLength: Float = 0.75  // 0-1
        var swing: Float = 0  // 0-1
        var velocity: VelocityMode = .asPlayed

        enum ArpMode: String, CaseIterable {
            case up, down, upDown, downUp
            case random, chord, pattern

            var displayName: String {
                switch self {
                case .up: return "Up"
                case .down: return "Down"
                case .upDown: return "Up/Down"
                case .downUp: return "Down/Up"
                case .random: return "Random"
                case .chord: return "Chord"
                case .pattern: return "Pattern"
                }
            }
        }

        enum NoteValue: String, CaseIterable {
            case whole, half, quarter, eighth, sixteenth, thirtySecond

            var duration: Double {
                switch self {
                case .whole: return 4.0
                case .half: return 2.0
                case .quarter: return 1.0
                case .eighth: return 0.5
                case .sixteenth: return 0.25
                case .thirtySecond: return 0.125
                }
            }
        }

        enum VelocityMode {
            case asPlayed, fixed(UInt8), accent(pattern: [UInt8])
        }
    }

    // MARK: - MIDI Filters
    enum MIDIFilter {
        case channelFilter(channels: [Int])
        case noteRange(min: Int, max: Int)
        case velocityRange(min: Int, max: Int)
        case ccFilter(controllers: [Int])
        case programChange(allow: Bool)
        case pitchBend(allow: Bool)
        case aftertouch(allow: Bool)
    }

    // MARK: - MIDI Processors
    enum MIDIProcessor {
        case velocityScale(amount: Float)  // 0-2
        case randomize(velocity: Float, timing: Float)
        case humanize(timing: Float, velocity: Float)
        case quantize(grid: GridValue)
        case delay(time: Double, feedback: Float, mix: Float)
        case chordTrigger(chord: [Int])  // Interval offsets

        enum GridValue {
            case quarter, eighth, sixteenth, triplet
        }
    }

    // MARK: - Velocity Curve
    enum VelocityCurve {
        case linear
        case logarithmic
        case exponential
        case custom([Float])  // 128 values for 0-127 velocity

        func transform(_ velocity: UInt8) -> UInt8 {
            let input = Float(velocity) / 127.0

            let output: Float
            switch self {
            case .linear:
                output = input

            case .logarithmic:
                output = log10(1.0 + input * 9.0)

            case .exponential:
                output = pow(input, 2.0)

            case .custom(let curve):
                output = curve[Int(velocity)]
            }

            return UInt8(max(0, min(127, output * 127.0)))
        }
    }

    // MARK: - MIDI Generators
    enum MIDIGenerator {
        case lfo(rate: Float, depth: Float, target: MIDITarget)
        case randomWalk(step: Int, rate: Float)
        case euclideanPattern(steps: Int, pulses: Int, rotation: Int)
        case sequencer(pattern: [MIDIEvent])

        enum MIDITarget {
            case note, velocity, cc(Int), pitchBend
        }
    }

    struct MIDIEvent {
        var type: EventType
        var channel: Int
        var data1: UInt8
        var data2: UInt8
        var timestamp: Date

        enum EventType {
            case noteOn, noteOff
            case controlChange, programChange
            case pitchBend, aftertouch
            case polyAftertouch
        }
    }

    // MARK: - MIDI Learn
    @Published var midiLearnMode: Bool = false
    @Published var midiMappings: [MIDIMapping] = []

    struct MIDIMapping: Identifiable {
        var id: UUID
        var source: MIDISource
        var target: MappingTarget
        var minValue: Float
        var maxValue: Float
        var curve: VelocityCurve

        struct MIDISource {
            var channel: Int
            var controller: Int?  // nil for note velocity
            var note: Int?        // For note-based control
        }

        struct MappingTarget {
            var parameter: String
            var type: ParameterType

            enum ParameterType {
                case trackVolume(UUID)
                case trackPan(UUID)
                case effectParameter(effectID: UUID, parameter: String)
                case instrumentParameter(instrumentID: UUID, parameter: String)
                case globalParameter(name: String)
            }
        }
    }

    // MARK: - MIDI Effects
    func processMIDI(_ event: MIDIEvent, through route: MIDIRoute) -> [MIDIEvent] {
        var events = [event]

        // Apply filters
        for filter in route.filters {
            events = events.filter { applyFilter($0, filter: filter) }
        }

        // Apply processors
        for processor in route.processors {
            events = events.flatMap { applyProcessor($0, processor: processor) }
        }

        // Apply transpose
        events = events.map { transposeEvent($0, semitones: route.transpose) }

        // Apply velocity curve
        events = events.map { applyVelocityCurve($0, curve: route.velocityCurve) }

        return events
    }

    private func applyFilter(_ event: MIDIEvent, filter: MIDIFilter) -> Bool {
        switch filter {
        case .channelFilter(let channels):
            return channels.contains(event.channel)

        case .noteRange(let min, let max):
            if case .noteOn = event.type {
                return Int(event.data1) >= min && Int(event.data1) <= max
            }
            return true

        case .velocityRange(let min, let max):
            if case .noteOn = event.type {
                return Int(event.data2) >= min && Int(event.data2) <= max
            }
            return true

        default:
            return true
        }
    }

    private func applyProcessor(_ event: MIDIEvent, processor: MIDIProcessor) -> [MIDIEvent] {
        switch processor {
        case .velocityScale(let amount):
            var modifiedEvent = event
            if case .noteOn = event.type {
                let scaled = Float(event.data2) * amount
                modifiedEvent.data2 = UInt8(max(1, min(127, scaled)))
            }
            return [modifiedEvent]

        case .chordTrigger(let intervals):
            var chordEvents: [MIDIEvent] = [event]
            if case .noteOn = event.type {
                for interval in intervals {
                    var chordNote = event
                    chordNote.data1 = UInt8(max(0, min(127, Int(event.data1) + interval)))
                    chordEvents.append(chordNote)
                }
            }
            return chordEvents

        case .humanize(let timing, let velocity):
            var humanized = event
            // Add timing variation (would adjust timestamp)
            // Add velocity variation
            if case .noteOn = event.type {
                let velocityVariation = Float.random(in: -velocity...velocity) * 20.0
                let newVelocity = Float(event.data2) + velocityVariation
                humanized.data2 = UInt8(max(1, min(127, newVelocity)))
            }
            return [humanized]

        default:
            return [event]
        }
    }

    private func transposeEvent(_ event: MIDIEvent, semitones: Int) -> MIDIEvent {
        var transposed = event
        if case .noteOn = event.type {
            let newNote = Int(event.data1) + semitones
            transposed.data1 = UInt8(max(0, min(127, newNote)))
        }
        return transposed
    }

    private func applyVelocityCurve(_ event: MIDIEvent, curve: VelocityCurve) -> MIDIEvent {
        var modified = event
        if case .noteOn = event.type {
            modified.data2 = curve.transform(event.data2)
        }
        return modified
    }

    // MARK: - MPE Processing
    private var mpeVoices: [MPEVoice] = []

    func allocateMPEVoice(note: UInt8, velocity: UInt8) -> Int? {
        guard mpeConfiguration.enabled else { return nil }

        // Find available channel
        let availableChannels = mpeConfiguration.memberChannels.filter { channel in
            !mpeVoices.contains { $0.channel == channel }
        }

        guard let channel = availableChannels.first else { return nil }

        // Create voice
        let voice = MPEVoice(
            channel: channel,
            note: note,
            velocity: velocity,
            pitchBend: 0,
            pressure: 0,
            timbre: 0,
            startTime: Date()
        )

        mpeVoices.append(voice)
        return channel
    }

    func releaseMPEVoice(note: UInt8) {
        mpeVoices.removeAll { $0.note == note }
    }

    func updateMPEVoice(channel: Int, pitchBend: Float?, pressure: Float?, timbre: Float?) {
        if let index = mpeVoices.firstIndex(where: { $0.channel == channel }) {
            if let bend = pitchBend {
                mpeVoices[index].pitchBend = bend
            }
            if let press = pressure {
                mpeVoices[index].pressure = press
            }
            if let timb = timbre {
                mpeVoices[index].timbre = timb
            }
        }
    }

    // MARK: - Arpeggiator Processing
    func processArpeggiator(heldNotes: [UInt8], tempo: Double) -> [MIDIEvent] {
        guard arpeggiator.enabled, !heldNotes.isEmpty else { return [] }

        var arpNotes: [UInt8] = []

        // Generate arpeggiated pattern
        switch arpeggiator.mode {
        case .up:
            arpNotes = Array(heldNotes.sorted())

        case .down:
            arpNotes = Array(heldNotes.sorted().reversed())

        case .upDown:
            let sorted = heldNotes.sorted()
            arpNotes = sorted + sorted.dropFirst().dropLast().reversed()

        case .downUp:
            let sorted = heldNotes.sorted().reversed()
            arpNotes = sorted + sorted.dropFirst().dropLast().reversed()

        case .random:
            arpNotes = heldNotes.shuffled()

        case .chord:
            arpNotes = heldNotes

        case .pattern:
            // Would use custom pattern
            arpNotes = heldNotes
        }

        // Expand across octaves
        if arpeggiator.octaves > 1 {
            var expandedNotes: [UInt8] = []
            for octave in 0..<arpeggiator.octaves {
                expandedNotes += arpNotes.map { UInt8(Int($0) + (octave * 12)) }
            }
            arpNotes = expandedNotes
        }

        // Convert to MIDI events (simplified)
        var events: [MIDIEvent] = []
        for note in arpNotes {
            let event = MIDIEvent(
                type: .noteOn,
                channel: 1,
                data1: note,
                data2: 100,
                timestamp: Date()
            )
            events.append(event)
        }

        return events
    }
}
