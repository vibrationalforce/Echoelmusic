// MIDISequencer.swift
// MIDI Sequencer Engine
//
// Piano Roll + Step Sequencer for MIDI composition

import Foundation
import AVFoundation
import Combine

/// MIDI Sequencer Engine
class MIDISequencer: ObservableObject {

    // MARK: - Properties

    /// MIDI clip being edited
    @Published var clip: Clip

    /// Selected notes
    @Published var selectedNotes: Set<UUID> = []

    /// Current editing tool
    @Published var editingTool: EditingTool = .pencil

    /// Grid snap enabled
    @Published var snapEnabled: Bool = true

    /// Grid division
    @Published var gridDivision: GridDivision = .sixteenth

    /// Velocity for new notes
    @Published var defaultVelocity: UInt8 = 100

    /// Note duration for new notes (in grid divisions)
    @Published var defaultDuration: Int = 1

    /// Undo/redo stacks
    private var undoStack: [MIDIClipState] = []
    private var redoStack: [MIDIClipState] = []
    private let maxUndoSteps: Int = 100


    // MARK: - Initialization

    init(clip: Clip) {
        guard clip.type == .midi else {
            fatalError("MIDISequencer requires MIDI clip")
        }
        self.clip = clip

        // Ensure MIDI data exists
        if clip.midiData == nil {
            clip.midiData = MIDIClipData()
        }
    }


    // MARK: - Note Operations

    /// Add note to clip
    func addNote(
        position: Int64,
        duration: Int64,
        noteNumber: UInt8,
        velocity: UInt8? = nil,
        channel: UInt8 = 0
    ) {
        saveState()  // For undo

        let note = MIDINote(
            position: position,
            duration: duration,
            noteNumber: noteNumber,
            velocity: velocity ?? defaultVelocity,
            channel: channel
        )

        clip.midiData?.notes.append(note)
        clip.modifiedAt = Date()

        print("🎹 Added note: \(noteName(noteNumber)) @ \(position)")
    }

    /// Remove note from clip
    func removeNote(_ noteID: UUID) {
        saveState()

        clip.midiData?.notes.removeAll { $0.id == noteID }
        selectedNotes.remove(noteID)
        clip.modifiedAt = Date()
    }

    /// Remove selected notes
    func removeSelectedNotes() {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        clip.midiData?.notes.removeAll { selectedNotes.contains($0.id) }
        selectedNotes.removeAll()
        clip.modifiedAt = Date()
    }

    /// Move note to new position
    func moveNote(_ noteID: UUID, to position: Int64) {
        saveState()

        guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { return }

        clip.midiData?.notes[index].position = snapEnabled ? snapToGrid(position) : position
        clip.modifiedAt = Date()
    }

    /// Move selected notes by offset
    func moveSelectedNotes(by offset: Int64) {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        for noteID in selectedNotes {
            guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { continue }
            let newPosition = clip.midiData!.notes[index].position + offset
            clip.midiData?.notes[index].position = max(0, snapEnabled ? snapToGrid(newPosition) : newPosition)
        }

        clip.modifiedAt = Date()
    }

    /// Resize note
    func resizeNote(_ noteID: UUID, newDuration: Int64) {
        guard newDuration > 0 else { return }
        saveState()

        guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { return }

        clip.midiData?.notes[index].duration = snapEnabled ? snapToGrid(newDuration) : newDuration
        clip.modifiedAt = Date()
    }

    /// Change note pitch
    func changeNotePitch(_ noteID: UUID, newNoteNumber: UInt8) {
        guard newNoteNumber < 128 else { return }
        saveState()

        guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { return }

        clip.midiData?.notes[index].noteNumber = newNoteNumber
        clip.modifiedAt = Date()
    }

    /// Transpose selected notes by semitones
    func transposeSelectedNotes(by semitones: Int) {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        for noteID in selectedNotes {
            guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { continue }

            let currentNote = Int(clip.midiData!.notes[index].noteNumber)
            let newNote = max(0, min(127, currentNote + semitones))
            clip.midiData?.notes[index].noteNumber = UInt8(newNote)
        }

        clip.modifiedAt = Date()
    }

    /// Change note velocity
    func changeNoteVelocity(_ noteID: UUID, newVelocity: UInt8) {
        guard newVelocity < 128 else { return }
        saveState()

        guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { return }

        clip.midiData?.notes[index].velocity = newVelocity
        clip.modifiedAt = Date()
    }

    /// Change velocity for selected notes
    func changeSelectedNotesVelocity(by delta: Int) {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        for noteID in selectedNotes {
            guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { continue }

            let currentVelocity = Int(clip.midiData!.notes[index].velocity)
            let newVelocity = max(1, min(127, currentVelocity + delta))
            clip.midiData?.notes[index].velocity = UInt8(newVelocity)
        }

        clip.modifiedAt = Date()
    }


    // MARK: - Selection

    /// Select note
    func selectNote(_ noteID: UUID, clearExisting: Bool = true) {
        if clearExisting {
            selectedNotes.removeAll()
        }
        selectedNotes.insert(noteID)
    }

    /// Deselect note
    func deselectNote(_ noteID: UUID) {
        selectedNotes.remove(noteID)
    }

    /// Select all notes
    func selectAll() {
        guard let notes = clip.midiData?.notes else { return }
        selectedNotes = Set(notes.map { $0.id })
    }

    /// Deselect all notes
    func deselectAll() {
        selectedNotes.removeAll()
    }

    /// Select notes in region
    func selectNotesInRegion(start: Int64, end: Int64, minPitch: UInt8, maxPitch: UInt8) {
        guard let notes = clip.midiData?.notes else { return }

        selectedNotes.removeAll()

        for note in notes {
            let noteEnd = note.position + note.duration
            let overlaps = !(noteEnd <= start || note.position >= end)
            let inPitchRange = note.noteNumber >= minPitch && note.noteNumber <= maxPitch

            if overlaps && inPitchRange {
                selectedNotes.insert(note.id)
            }
        }
    }


    // MARK: - Grid Snapping

    /// Snap position to grid
    func snapToGrid(_ position: Int64) -> Int64 {
        guard snapEnabled else { return position }

        let gridSize = gridDivision.samplesPerDivision(tempo: 120.0, sampleRate: 48000.0)
        return (position / gridSize) * gridSize
    }


    // MARK: - Quantization

    /// Quantize selected notes to grid
    func quantizeSelectedNotes() {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        let gridSize = gridDivision.samplesPerDivision(tempo: 120.0, sampleRate: 48000.0)

        for noteID in selectedNotes {
            guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { continue }

            let currentPosition = clip.midiData!.notes[index].position
            let quantizedPosition = (currentPosition / gridSize) * gridSize
            clip.midiData?.notes[index].position = quantizedPosition
        }

        clip.modifiedAt = Date()
        print("🎵 Quantized \(selectedNotes.count) notes to grid")
    }


    // MARK: - Humanization

    /// Humanize selected notes (add timing/velocity variation)
    func humanizeSelectedNotes(timingAmount: Float = 0.1, velocityAmount: Float = 0.1) {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        let gridSize = gridDivision.samplesPerDivision(tempo: 120.0, sampleRate: 48000.0)
        let maxTimingOffset = Int64(Float(gridSize) * timingAmount)
        let maxVelocityOffset = Int(127.0 * velocityAmount)

        for noteID in selectedNotes {
            guard let index = clip.midiData?.notes.firstIndex(where: { $0.id == noteID }) else { continue }

            // Randomize timing
            let timingOffset = Int64.random(in: -maxTimingOffset...maxTimingOffset)
            clip.midiData?.notes[index].position = max(0, clip.midiData!.notes[index].position + timingOffset)

            // Randomize velocity
            let velocityOffset = Int.random(in: -maxVelocityOffset...maxVelocityOffset)
            let currentVelocity = Int(clip.midiData!.notes[index].velocity)
            let newVelocity = max(1, min(127, currentVelocity + velocityOffset))
            clip.midiData?.notes[index].velocity = UInt8(newVelocity)
        }

        clip.modifiedAt = Date()
        print("🎭 Humanized \(selectedNotes.count) notes")
    }


    // MARK: - Pattern Operations

    /// Duplicate selected notes at offset
    func duplicateSelectedNotes(offset: Int64) {
        guard !selectedNotes.isEmpty else { return }
        saveState()

        var newNotes: [MIDINote] = []

        for noteID in selectedNotes {
            guard let note = clip.midiData?.notes.first(where: { $0.id == noteID }) else { continue }

            let newNote = MIDINote(
                position: note.position + offset,
                duration: note.duration,
                noteNumber: note.noteNumber,
                velocity: note.velocity,
                channel: note.channel
            )
            newNotes.append(newNote)
        }

        clip.midiData?.notes.append(contentsOf: newNotes)
        clip.modifiedAt = Date()

        print("📋 Duplicated \(newNotes.count) notes")
    }


    // MARK: - Undo/Redo

    private func saveState() {
        guard let midiData = clip.midiData else { return }

        // Create snapshot
        let state = MIDIClipState(midiData: midiData)

        undoStack.append(state)

        // Limit undo stack size
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }

        // Clear redo stack
        redoStack.removeAll()
    }

    func undo() {
        guard let lastState = undoStack.popLast() else { return }

        // Save current state to redo
        if let currentData = clip.midiData {
            redoStack.append(MIDIClipState(midiData: currentData))
        }

        // Restore previous state
        clip.midiData = lastState.midiData
        clip.modifiedAt = Date()

        print("↶ Undo")
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }

        // Save current state to undo
        if let currentData = clip.midiData {
            undoStack.append(MIDIClipState(midiData: currentData))
        }

        // Restore next state
        clip.midiData = nextState.midiData
        clip.modifiedAt = Date()

        print("↷ Redo")
    }


    // MARK: - Utilities

    /// Get note name from MIDI number
    func noteName(_ noteNumber: UInt8) -> String {
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(noteNumber) / 12 - 1
        let note = notes[Int(noteNumber) % 12]
        return "\(note)\(octave)"
    }

    /// Get notes at position
    func notesAt(position: Int64, pitch: UInt8) -> [MIDINote] {
        guard let notes = clip.midiData?.notes else { return [] }

        return notes.filter { note in
            note.noteNumber == pitch &&
            note.position <= position &&
            (note.position + note.duration) > position
        }
    }

    /// Check if note exists at position/pitch
    func hasNoteAt(position: Int64, pitch: UInt8) -> Bool {
        !notesAt(position: position, pitch: pitch).isEmpty
    }
}


// MARK: - Supporting Types

/// Editing tool
enum EditingTool: String, CaseIterable {
    case pencil = "Pencil"
    case eraser = "Eraser"
    case select = "Select"
    case cut = "Cut"
}

/// Grid division
enum GridDivision: String, CaseIterable {
    case whole = "1"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtysecond = "1/32"

    /// Get samples per division
    func samplesPerDivision(tempo: Double, sampleRate: Double) -> Int64 {
        let beatsPerSecond = tempo / 60.0
        let samplesPerBeat = Int64(sampleRate / beatsPerSecond)

        switch self {
        case .whole: return samplesPerBeat * 4
        case .half: return samplesPerBeat * 2
        case .quarter: return samplesPerBeat
        case .eighth: return samplesPerBeat / 2
        case .sixteenth: return samplesPerBeat / 4
        case .thirtysecond: return samplesPerBeat / 8
        }
    }
}

/// MIDI clip state (for undo/redo)
struct MIDIClipState {
    let midiData: MIDIClipData
}


// MARK: - MIDI Note Extensions

extension MIDINote {
    /// Get note frequency (Hz)
    var frequency: Double {
        440.0 * pow(2.0, (Double(noteNumber) - 69.0) / 12.0)
    }

    /// Check if note overlaps with another
    func overlaps(with other: MIDINote) -> Bool {
        let thisEnd = position + duration
        let otherEnd = other.position + other.duration

        return !(thisEnd <= other.position || position >= otherEnd)
    }
}
