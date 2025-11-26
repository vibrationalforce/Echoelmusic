//
//  MIDIRouter.swift
//  EOEL
//
//  MIDI Routing System - Connects MIDI sources to instruments
//  Routes: Hardware MIDI → Piano Roll → Sampler/Instruments → Audio Output
//

import Foundation
import CoreMIDI

// MARK: - MIDI Router

@MainActor
class MIDIRouter: ObservableObject {
    static let shared = MIDIRouter()

    // Connected instruments
    @Published var instruments: [UUID: any MIDIInstrumentProtocol] = [:]

    // Connected samplers
    @Published var samplers: [UUID: ProfessionalSampler] = [:]

    // MIDI clips for playback
    @Published var activeClips: [UUID: MIDIClip] = [:]

    // Current master clock position
    private var currentBeat: Double = 0.0
    private var isPlaying: Bool = false

    // MIDI input from hardware
    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0

    // Routing settings
    @Published var routingMode: RoutingMode = .allInstruments
    @Published var selectedInstrumentID: UUID?

    // Round-robin state
    private var roundRobinIndex: Int = 0

    enum RoutingMode {
        case allInstruments      // Send to all instruments
        case selectedOnly        // Send to selected instrument only
        case roundRobin          // Cycle through instruments
        case layering            // Trigger all with velocity scaling
    }

    private init() {
        setupMIDIInput()
    }

    // MARK: - Setup

    private func setupMIDIInput() {
        var client = MIDIClientRef()
        let status = MIDIClientCreateWithBlock("EOELMIDIRouter" as CFString, &client) { [weak self] notification in
            // Handle MIDI system changes
            print("MIDI system changed: \(notification)")
        }

        guard status == noErr else {
            print("❌ Failed to create MIDI client: \(status)")
            return
        }

        midiClient = client

        var inputPort = MIDIPortRef()
        let inputStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            "EOELInput" as CFString,
            .midi_1_0,
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIEvents(eventList)
        }

        guard inputStatus == noErr else {
            print("❌ Failed to create MIDI input port: \(inputStatus)")
            return
        }

        midiInputPort = inputPort

        // Connect to all MIDI sources
        connectAllSources()
    }

    private func connectAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(midiInputPort, source, nil)
        }
        print("✅ Connected to \(sourceCount) MIDI sources")
    }

    // MARK: - MIDI Event Handling

    private func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let packet = eventList.pointee.packet

        // Extract MIDI message
        let numWords = Int(packet.wordCount)
        guard numWords > 0 else { return }

        withUnsafePointer(to: packet.words) { wordsPtr in
            wordsPtr.withMemoryRebound(to: UInt32.self, capacity: numWords) { words in
                let word = words[0]

                let status = UInt8((word >> 16) & 0xFF)
                let data1 = UInt8((word >> 8) & 0xFF)
                let data2 = UInt8(word & 0xFF)

                processMIDIMessage(status: status, data1: data1, data2: data2)
            }
        }
    }

    private func processMIDIMessage(status: UInt8, data1: UInt8, data2: UInt8) {
        let messageType = status & 0xF0
        let channel = status & 0x0F

        switch messageType {
        case 0x90:  // Note On
            if data2 > 0 {  // Velocity > 0
                routeNoteOn(note: data1, velocity: data2, channel: channel)
            } else {
                routeNoteOff(note: data1, channel: channel)
            }

        case 0x80:  // Note Off
            routeNoteOff(note: data1, channel: channel)

        case 0xB0:  // Control Change
            routeCC(controller: data1, value: data2, channel: channel)

        case 0xE0:  // Pitch Bend
            let pitchBend = Int(data2) << 7 | Int(data1)
            routePitchBend(value: pitchBend, channel: channel)

        case 0xD0:  // Channel Pressure
            routeChannelPressure(pressure: data1, channel: channel)

        default:
            break
        }
    }

    // MARK: - Note Routing

    func routeNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        // Clamp to valid range
        let clampedNote = AudioUtilities.clampMIDINote(Int(note))
        let clampedVelocity = AudioUtilities.clampMIDIVelocity(Int(velocity))

        switch routingMode {
        case .allInstruments:
            // Send to all samplers
            for sampler in samplers.values {
                sampler.noteOn(note: clampedNote, velocity: clampedVelocity)
            }

            // Send to all instruments
            for instrument in instruments.values {
                instrument.noteOn(note: clampedNote, velocity: clampedVelocity, channel: channel)
            }

        case .selectedOnly:
            // Send to selected instrument only
            if let selectedID = selectedInstrumentID {
                if let sampler = samplers[selectedID] {
                    sampler.noteOn(note: clampedNote, velocity: clampedVelocity)
                } else if let instrument = instruments[selectedID] {
                    instrument.noteOn(note: clampedNote, velocity: clampedVelocity, channel: channel)
                }
            }

        case .roundRobin:
            // Round-robin: cycle through all available instruments
            let allIDs = Array(samplers.keys) + Array(instruments.keys)
            guard !allIDs.isEmpty else { return }

            // Get next instrument in round-robin sequence
            let targetID = allIDs[roundRobinIndex % allIDs.count]

            // Route to selected instrument
            if let sampler = samplers[targetID] {
                sampler.noteOn(note: clampedNote, velocity: clampedVelocity)
            } else if let instrument = instruments[targetID] {
                instrument.noteOn(note: clampedNote, velocity: clampedVelocity, channel: channel)
            }

            // Advance round-robin counter
            roundRobinIndex = (roundRobinIndex + 1) % allIDs.count

        case .layering:
            // Send to all with velocity scaling
            let instrumentCount = Float(samplers.count + instruments.count)
            let scaledVelocity = AudioUtilities.clampMIDIVelocity(
                Int(Float(velocity) / sqrt(instrumentCount))
            )

            for sampler in samplers.values {
                sampler.noteOn(note: clampedNote, velocity: scaledVelocity)
            }
        }
    }

    func routeNoteOff(note: UInt8, channel: UInt8 = 0) {
        // Send note off to all active instruments
        for sampler in samplers.values {
            sampler.noteOff(note: note)
        }

        for instrument in instruments.values {
            instrument.noteOff(note: note, channel: channel)
        }
    }

    private func routeCC(controller: UInt8, value: UInt8, channel: UInt8) {
        // Route CC to instruments that support it
        for instrument in instruments.values {
            instrument.handleCC(controller: controller, value: value, channel: channel)
        }
    }

    private func routePitchBend(value: Int, channel: UInt8) {
        let normalizedBend = Float(value - 8192) / 8192.0  // -1.0 to +1.0
        for instrument in instruments.values {
            instrument.handlePitchBend(bend: normalizedBend, channel: channel)
        }
    }

    private func routeChannelPressure(pressure: UInt8, channel: UInt8) {
        for instrument in instruments.values {
            instrument.handleChannelPressure(pressure: pressure, channel: channel)
        }
    }

    // MARK: - Clip Playback

    func updatePlayback(beat: Double, isPlaying: Bool) {
        self.currentBeat = beat
        self.isPlaying = isPlaying

        guard isPlaying else { return }

        // Check all active clips for notes at current beat
        for (_, clip) in activeClips {
            let notesToPlay = clip.notes.filter { note in
                // Check if note starts at current beat (with small tolerance)
                abs(note.startBeat - beat) < 0.01
            }

            for note in notesToPlay {
                routeNoteOn(note: note.note, velocity: note.velocity, channel: note.channel)
            }

            // Check for note offs
            let notesToStop = clip.notes.filter { note in
                let endBeat = note.startBeat + note.duration
                abs(endBeat - beat) < 0.01
            }

            for note in notesToStop {
                routeNoteOff(note: note.note, channel: note.channel)
            }
        }
    }

    // MARK: - Instrument Management

    func registerSampler(_ sampler: ProfessionalSampler, id: UUID) {
        samplers[id] = sampler
        print("✅ Registered sampler: \(sampler.name)")
    }

    func unregisterSampler(id: UUID) {
        samplers.removeValue(forKey: id)
    }

    func registerInstrument(_ instrument: any MIDIInstrumentProtocol, id: UUID) {
        instruments[id] = instrument
        print("✅ Registered instrument: \(id)")
    }

    func unregisterInstrument(id: UUID) {
        instruments.removeValue(forKey: id)
    }

    // MARK: - Clip Management

    func addClip(_ clip: MIDIClip, id: UUID) {
        activeClips[id] = clip
    }

    func removeClip(id: UUID) {
        activeClips.removeValue(forKey: id)
    }

    // MARK: - All Notes Off

    func allNotesOff() {
        for note: UInt8 in 0...127 {
            routeNoteOff(note: note)
        }
    }
}

// MARK: - MIDI Instrument Protocol

protocol MIDIInstrumentProtocol {
    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    func noteOff(note: UInt8, channel: UInt8)
    func handleCC(controller: UInt8, value: UInt8, channel: UInt8)
    func handlePitchBend(bend: Float, channel: UInt8)
    func handleChannelPressure(pressure: UInt8, channel: UInt8)
}

// MARK: - Extension for Existing Sampler

extension ProfessionalSampler: MIDIInstrumentProtocol {
    func handleCC(controller: UInt8, value: UInt8, channel: UInt8) {
        // Map common CCs
        switch controller {
        case 7:  // Volume
            self.masterVolume = Float(value) / 127.0
        case 10:  // Pan
            // Would apply to all regions
            break
        case 74:  // Brightness (filter cutoff)
            if filterEnabled {
                filterCutoff = 200.0 + (Float(value) / 127.0) * 19800.0  // 200Hz to 20kHz
            }
        default:
            break
        }
    }

    func handlePitchBend(bend: Float, channel: UInt8) {
        // Apply pitch bend to master tuning (±200 cents)
        self.masterTuning = bend * 200.0
    }

    func handleChannelPressure(pressure: UInt8, channel: UInt8) {
        // Could modulate volume or filter
    }
}
