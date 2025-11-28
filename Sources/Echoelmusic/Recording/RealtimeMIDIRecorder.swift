//
//  RealtimeMIDIRecorder.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Professional Real-Time MIDI Recorder
//  Sample-accurate recording, quantization, overdub, punch-in/out
//  Logic Pro X / Cubase / Ableton Live level MIDI recording
//

import Foundation
import CoreMIDI
import Combine

/// Professional real-time MIDI recorder with advanced features
@MainActor
class RealtimeMIDIRecorder: ObservableObject {
    static let shared = RealtimeMIDIRecorder()

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var recordMode: RecordMode = .replace
    @Published var quantization: Quantization = .off
    @Published var inputQuantization: Bool = false
    @Published var midiTracks: [MIDITrack] = []
    @Published var activeTrack: UUID?
    @Published var punchMode: PunchMode = .manual
    @Published var punchIn: Double = 0.0  // beats
    @Published var punchOut: Double = 0.0  // beats
    @Published var metronome: MetronomeSettings = MetronomeSettings()
    @Published var midiThru: Bool = true
    @Published var recordedEvents: Int = 0

    // MARK: - Record Mode

    enum RecordMode: String, CaseIterable {
        case replace = "Replace"
        case overdub = "Overdub"
        case merge = "Merge"
        case soundOnSound = "Sound-on-Sound"
        case loopRecord = "Loop Record"
        case punchRecord = "Punch Record"

        var description: String {
            switch self {
            case .replace: return "Replace existing MIDI data"
            case .overdub: return "Add new MIDI to existing notes"
            case .merge: return "Merge new and existing MIDI"
            case .soundOnSound: return "Layer multiple takes"
            case .loopRecord: return "Record in a loop, adding each pass"
            case .punchRecord: return "Record only between punch points"
            }
        }
    }

    // MARK: - Quantization

    enum Quantization: String, CaseIterable {
        case off = "Off"
        case bar = "Bar"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtysecond = "1/32"
        case triplet = "Triplet 1/8"
        case swing = "Swing 16th"

        var beats: Double {
            switch self {
            case .off: return 0.0
            case .bar: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtysecond: return 0.125
            case .triplet: return 1.0 / 3.0
            case .swing: return 0.25
            }
        }

        func quantize(_ beat: Double) -> Double {
            guard self != .off else { return beat }

            let quantum = beats
            return round(beat / quantum) * quantum
        }
    }

    // MARK: - Punch Mode

    enum PunchMode: String, CaseIterable {
        case manual = "Manual"
        case auto = "Auto Punch"
        case loop = "Loop Punch"
        case preRoll = "Pre-Roll"
        case countIn = "Count-In"
    }

    // MARK: - MIDI Track

    struct MIDITrack: Identifiable {
        let id: UUID
        var name: String
        var channel: Int  // 1-16
        var inputDevice: String?
        var events: [MIDIEvent]
        var isArmed: Bool
        var isMuted: Bool
        var isSolo: Bool
        var color: String
        var takes: [Take]
        var quantize: Quantization

        struct Take: Identifiable {
            let id: UUID
            var name: String
            var timestamp: Date
            var events: [MIDIEvent]
            var isComposite: Bool  // Merged from multiple takes
        }

        static func create(name: String, channel: Int) -> MIDITrack {
            MIDITrack(
                id: UUID(),
                name: name,
                channel: channel,
                inputDevice: nil,
                events: [],
                isArmed: false,
                isMuted: false,
                isSolo: false,
                color: "#007AFF",
                takes: [],
                quantize: .off
            )
        }
    }

    // MARK: - MIDI Event

    struct MIDIEvent: Identifiable, Codable {
        let id: UUID
        var timestamp: UInt64  // Sample time
        var beat: Double  // Beat position
        var type: EventType
        var channel: Int  // 0-15
        var data1: UInt8  // Note number, CC number, etc.
        var data2: UInt8  // Velocity, CC value, etc.
        var duration: Double  // For note events (beats)

        enum EventType: String, Codable {
            case noteOn = "Note On"
            case noteOff = "Note Off"
            case controlChange = "Control Change"
            case programChange = "Program Change"
            case pitchBend = "Pitch Bend"
            case aftertouch = "Aftertouch"
            case polyAftertouch = "Poly Aftertouch"
            case sysex = "SysEx"
        }

        var note: Int { Int(data1) }
        var velocity: Int { Int(data2) }
        var cc: Int { Int(data1) }
        var value: Int { Int(data2) }

        var description: String {
            switch type {
            case .noteOn, .noteOff:
                return "\(type.rawValue): \(noteName) Vel:\(velocity)"
            case .controlChange:
                return "CC\(cc): \(value)"
            case .programChange:
                return "Program: \(data1)"
            case .pitchBend:
                let bend = Int(data1) | (Int(data2) << 7)
                return "Pitch Bend: \(bend - 8192)"
            default:
                return type.rawValue
            }
        }

        var noteName: String {
            let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let octave = (note / 12) - 1
            let noteIndex = note % 12
            return "\(notes[noteIndex])\(octave)"
        }
    }

    // MARK: - Metronome

    struct MetronomeSettings {
        var enabled: Bool = true
        var countIn: Int = 0  // bars
        var volume: Float = 0.7
        var accentFirstBeat: Bool = true
        var duringPlayback: Bool = false
        var duringRecording: Bool = true
    }

    // MARK: - Recording State

    private var recordingStartSample: UInt64 = 0
    private var recordingStartBeat: Double = 0.0
    private var currentTake: MIDITrack.Take?
    private var pendingNoteOffs: [UInt8: MIDIEvent] = [:]  // Note number -> Note on event

    // MARK: - Recording Control

    func startRecording() {
        guard !isRecording else { return }
        guard let trackID = activeTrack else {
            print("❌ No track armed for recording")
            return
        }

        isRecording = true
        isPlaying = true
        recordingStartSample = MasterClockSystem.shared.currentSample
        recordingStartBeat = MasterClockSystem.shared.currentBeat
        recordedEvents = 0
        pendingNoteOffs.removeAll()

        // Create new take
        let take = MIDITrack.Take(
            id: UUID(),
            name: "Take \(Date())",
            timestamp: Date(),
            events: [],
            isComposite: false
        )
        currentTake = take

        // Start master clock if not running
        if !MasterClockSystem.shared.isRunning {
            MasterClockSystem.shared.start()
        }

        print("🔴 Recording started on track: \(trackID)")
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false

        // Process pending note-offs (notes that haven't been released)
        for (_, noteOnEvent) in pendingNoteOffs {
            let currentBeat = MasterClockSystem.shared.currentBeat
            var completedEvent = noteOnEvent
            completedEvent.duration = currentBeat - noteOnEvent.beat

            currentTake?.events.append(completedEvent)
        }
        pendingNoteOffs.removeAll()

        // Save take to active track
        if var take = currentTake,
           let trackID = activeTrack,
           let trackIndex = midiTracks.firstIndex(where: { $0.id == trackID }) {

            // Apply quantization if enabled
            if midiTracks[trackIndex].quantize != .off {
                take.events = quantizeEvents(take.events, quantization: midiTracks[trackIndex].quantize)
            }

            // Handle record mode
            switch recordMode {
            case .replace:
                midiTracks[trackIndex].events = take.events
                midiTracks[trackIndex].takes = [take]

            case .overdub, .merge:
                midiTracks[trackIndex].events.append(contentsOf: take.events)
                midiTracks[trackIndex].takes.append(take)

            case .soundOnSound:
                midiTracks[trackIndex].takes.append(take)

            case .loopRecord:
                midiTracks[trackIndex].takes.append(take)
                // Create composite take from all loop passes
                createCompositeTake(trackIndex: trackIndex)

            case .punchRecord:
                punchInEvents(take.events, trackIndex: trackIndex)
            }

            print("✅ Recording stopped - \(take.events.count) events captured")
        }

        currentTake = nil
        recordedEvents = 0
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - MIDI Input Handling

    func receiveMIDIEvent(status: UInt8, data1: UInt8, data2: UInt8) {
        guard isRecording, let trackID = activeTrack else {
            // MIDI thru even when not recording
            if midiThru {
                // Forward to output
            }
            return
        }

        let channel = Int(status & 0x0F)
        let messageType = status & 0xF0

        var eventType: MIDIEvent.EventType

        switch messageType {
        case 0x80:  // Note Off
            eventType = .noteOff
        case 0x90:  // Note On
            eventType = data2 > 0 ? .noteOn : .noteOff
        case 0xB0:  // Control Change
            eventType = .controlChange
        case 0xC0:  // Program Change
            eventType = .programChange
        case 0xE0:  // Pitch Bend
            eventType = .pitchBend
        case 0xD0:  // Channel Aftertouch
            eventType = .aftertouch
        case 0xA0:  // Poly Aftertouch
            eventType = .polyAftertouch
        default:
            return
        }

        // Get compensated timestamp
        let timestamp = MasterClockSystem.shared.getCompensatedSampleTime()
        var beat = MasterClockSystem.shared.currentBeat

        // Apply input quantization if enabled
        if inputQuantization, let trackIndex = midiTracks.firstIndex(where: { $0.id == trackID }) {
            let quant = midiTracks[trackIndex].quantize
            beat = quant.quantize(beat)
        }

        // Check punch mode
        if punchMode == .auto {
            if beat < punchIn || beat > punchOut {
                return  // Outside punch range
            }
        }

        var event = MIDIEvent(
            id: UUID(),
            timestamp: timestamp,
            beat: beat,
            type: eventType,
            channel: channel,
            data1: data1,
            data2: data2,
            duration: 0.0
        )

        // Handle note on/off pairing
        if eventType == .noteOn {
            // Store note on for duration calculation
            pendingNoteOffs[data1] = event
        } else if eventType == .noteOff {
            // Find matching note on
            if let noteOnEvent = pendingNoteOffs[data1] {
                var completedEvent = noteOnEvent
                completedEvent.duration = beat - noteOnEvent.beat
                currentTake?.events.append(completedEvent)
                pendingNoteOffs.removeValue(forKey: data1)
                recordedEvents += 1
            }
        } else {
            // Non-note events
            currentTake?.events.append(event)
            recordedEvents += 1
        }

        // MIDI thru
        if midiThru {
            // Forward to output
        }
    }

    // MARK: - Quantization

    private func quantizeEvents(_ events: [MIDIEvent], quantization: Quantization) -> [MIDIEvent] {
        return events.map { event in
            var quantized = event
            quantized.beat = quantization.quantize(event.beat)
            return quantized
        }
    }

    func applyQuantization(to trackID: UUID, quantization: Quantization) {
        guard let index = midiTracks.firstIndex(where: { $0.id == trackID }) else { return }

        midiTracks[index].events = quantizeEvents(midiTracks[index].events, quantization: quantization)
        midiTracks[index].quantize = quantization

        print("🎯 Quantization applied: \(quantization.rawValue)")
    }

    // MARK: - Overdub & Takes

    private func createCompositeTake(trackIndex: Int) {
        let allEvents = midiTracks[trackIndex].takes.flatMap { $0.events }

        let composite = MIDITrack.Take(
            id: UUID(),
            name: "Composite",
            timestamp: Date(),
            events: allEvents.sorted { $0.beat < $1.beat },
            isComposite: true
        )

        midiTracks[trackIndex].events = composite.events
        midiTracks[trackIndex].takes.append(composite)

        print("🎼 Created composite take from \(midiTracks[trackIndex].takes.count) takes")
    }

    func selectTake(_ takeID: UUID, for trackID: UUID) {
        guard let trackIndex = midiTracks.firstIndex(where: { $0.id == trackID }),
              let take = midiTracks[trackIndex].takes.first(where: { $0.id == takeID }) else { return }

        midiTracks[trackIndex].events = take.events
        print("✅ Selected take: \(take.name)")
    }

    func deleteTake(_ takeID: UUID, from trackID: UUID) {
        guard let trackIndex = midiTracks.firstIndex(where: { $0.id == trackID }) else { return }

        midiTracks[trackIndex].takes.removeAll { $0.id == takeID }
    }

    // MARK: - Punch Recording

    private func punchInEvents(_ events: [MIDIEvent], trackIndex: Int) {
        // Remove events in punch range
        var existingEvents = midiTracks[trackIndex].events.filter { event in
            event.beat < punchIn || event.beat > punchOut
        }

        // Add new events
        existingEvents.append(contentsOf: events)
        existingEvents.sort { $0.beat < $1.beat }

        midiTracks[trackIndex].events = existingEvents

        print("✂️ Punch recording: Replaced beats \(punchIn) to \(punchOut)")
    }

    // MARK: - Track Management

    func addTrack(name: String, channel: Int) {
        let track = MIDITrack.create(name: name, channel: channel)
        midiTracks.append(track)
        print("➕ Added MIDI track: \(name) (Ch \(channel))")
    }

    func removeTrack(_ id: UUID) {
        midiTracks.removeAll { $0.id == id }
    }

    func armTrack(_ id: UUID) {
        // Disarm all other tracks
        for index in midiTracks.indices {
            midiTracks[index].isArmed = (midiTracks[index].id == id)
        }
        activeTrack = id
        print("🎙️ Armed track: \(id)")
    }

    func clearTrack(_ id: UUID) {
        guard let index = midiTracks.firstIndex(where: { $0.id == id }) else { return }
        midiTracks[index].events.removeAll()
        midiTracks[index].takes.removeAll()
    }

    // MARK: - MIDI File Import/Export

    func exportToMIDIFile(trackID: UUID) -> Data? {
        guard let track = midiTracks.first(where: { $0.id == trackID }) else { return nil }

        // Create MIDI file data
        // Simplified - real implementation would use proper MIDI file format

        var data = Data()

        // MIDI Header
        data.append(contentsOf: "MThd".utf8)  // Chunk type
        data.append(contentsOf: [0, 0, 0, 6])  // Header length
        data.append(contentsOf: [0, 1])  // Format 1
        data.append(contentsOf: [0, 1])  // 1 track
        data.append(contentsOf: [0, 96])  // 96 PPQN

        // MIDI Track
        data.append(contentsOf: "MTrk".utf8)

        var trackData = Data()

        for event in track.events.sorted(by: { $0.beat < $1.beat }) {
            // Delta time (simplified)
            let ticks = Int(event.beat * 96.0)
            trackData.append(UInt8(ticks & 0x7F))

            // MIDI event
            let status = eventTypeToStatus(event.type) | UInt8(event.channel)
            trackData.append(status)
            trackData.append(event.data1)
            if event.type != .programChange {
                trackData.append(event.data2)
            }
        }

        // Track length
        let length = UInt32(trackData.count)
        data.append(UInt8((length >> 24) & 0xFF))
        data.append(UInt8((length >> 16) & 0xFF))
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))

        data.append(trackData)

        return data
    }

    private func eventTypeToStatus(_ type: MIDIEvent.EventType) -> UInt8 {
        switch type {
        case .noteOn: return 0x90
        case .noteOff: return 0x80
        case .controlChange: return 0xB0
        case .programChange: return 0xC0
        case .pitchBend: return 0xE0
        case .aftertouch: return 0xD0
        case .polyAftertouch: return 0xA0
        case .sysex: return 0xF0
        }
    }

    // MARK: - Utilities

    func getEventsInRange(from startBeat: Double, to endBeat: Double, trackID: UUID) -> [MIDIEvent] {
        guard let track = midiTracks.first(where: { $0.id == trackID }) else { return [] }

        return track.events.filter { event in
            event.beat >= startBeat && event.beat <= endBeat
        }
    }

    func deleteEventsInRange(from startBeat: Double, to endBeat: Double, trackID: UUID) {
        guard let index = midiTracks.firstIndex(where: { $0.id == trackID }) else { return }

        midiTracks[index].events.removeAll { event in
            event.beat >= startBeat && event.beat <= endBeat
        }

        print("🗑️ Deleted events from beat \(startBeat) to \(endBeat)")
    }

    func transposeEvents(by semitones: Int, trackID: UUID) {
        guard let index = midiTracks.firstIndex(where: { $0.id == trackID }) else { return }

        midiTracks[index].events = midiTracks[index].events.map { event in
            var transposed = event
            if event.type == .noteOn || event.type == .noteOff {
                let newNote = Int(event.data1) + semitones
                transposed.data1 = UInt8(max(0, min(127, newNote)))
            }
            return transposed
        }

        print("🎵 Transposed by \(semitones) semitones")
    }

    func scaleVelocity(by factor: Float, trackID: UUID) {
        guard let index = midiTracks.firstIndex(where: { $0.id == trackID }) else { return }

        midiTracks[index].events = midiTracks[index].events.map { event in
            var scaled = event
            if event.type == .noteOn {
                let newVelocity = Float(event.data2) * factor
                scaled.data2 = UInt8(max(1, min(127, Int(newVelocity))))
            }
            return scaled
        }

        print("🔊 Scaled velocity by \(factor)x")
    }

    // MARK: - Statistics

    func getRecordingStats(trackID: UUID) -> RecordingStats? {
        guard let track = midiTracks.first(where: { $0.id == trackID }) else { return nil }

        let noteEvents = track.events.filter { $0.type == .noteOn }
        let velocities = noteEvents.map { Float($0.velocity) }

        return RecordingStats(
            totalEvents: track.events.count,
            noteEvents: noteEvents.count,
            averageVelocity: velocities.isEmpty ? 0 : velocities.reduce(0, +) / Float(velocities.count),
            takes: track.takes.count,
            duration: track.events.last?.beat ?? 0.0
        )
    }

    struct RecordingStats {
        let totalEvents: Int
        let noteEvents: Int
        let averageVelocity: Float
        let takes: Int
        let duration: Double
    }

    // MARK: - Initialization

    private init() {}
}

#Preview {
    Text("Realtime MIDI Recorder")
}
