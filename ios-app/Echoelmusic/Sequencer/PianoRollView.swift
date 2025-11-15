// PianoRollView.swift
// Piano Roll Editor UI
//
// Complete MIDI editor with piano keyboard and note editing

import SwiftUI

/// Piano Roll Editor View
struct PianoRollView: View {

    @ObservedObject var sequencer: MIDISequencer

    // View state
    @State private var zoomLevel: CGFloat = 100.0  // pixels per beat
    @State private var verticalZoom: CGFloat = 20.0  // pixels per key
    @State private var scrollOffset: CGPoint = .zero

    // Piano keyboard range
    let minNote: UInt8 = 0    // C-1
    let maxNote: UInt8 = 127  // G9
    let visibleNoteRange: Int = 36  // 3 octaves

    // Interaction
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var newNotePreview: (position: Int64, pitch: UInt8)?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            PianoRollToolbar(sequencer: sequencer)
                .frame(height: 50)
                .background(Color.black.opacity(0.3))

            // Main editor
            HStack(spacing: 0) {
                // Piano keyboard (left)
                PianoKeyboard(
                    minNote: minNote,
                    maxNote: maxNote,
                    verticalZoom: verticalZoom,
                    onKeyTap: { note in
                        playNote(note)
                    }
                )
                .frame(width: 80)

                // Piano roll grid
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        // Grid background
                        PianoRollGrid(
                            minNote: minNote,
                            maxNote: maxNote,
                            clipDuration: sequencer.clip.duration,
                            sampleRate: 48000.0,
                            tempo: 120.0,
                            zoomLevel: zoomLevel,
                            verticalZoom: verticalZoom,
                            gridDivision: sequencer.gridDivision
                        )

                        // Notes
                        ForEach(sequencer.clip.midiData?.notes ?? []) { note in
                            NoteView(
                                note: note,
                                sampleRate: 48000.0,
                                zoomLevel: zoomLevel,
                                verticalZoom: verticalZoom,
                                isSelected: sequencer.selectedNotes.contains(note.id),
                                onTap: { selectNote(note.id) },
                                onDrag: { offset in dragNote(note.id, offset: offset) },
                                onResize: { newDuration in resizeNote(note.id, newDuration: newDuration) }
                            )
                        }

                        // New note preview
                        if let preview = newNotePreview {
                            PreviewNoteView(
                                position: preview.position,
                                pitch: preview.pitch,
                                duration: sequencer.gridDivision.samplesPerDivision(tempo: 120.0, sampleRate: 48000.0),
                                sampleRate: 48000.0,
                                zoomLevel: zoomLevel,
                                verticalZoom: verticalZoom
                            )
                        }
                    }
                    .frame(
                        width: pianoRollWidth,
                        height: pianoRollHeight
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(value)
                            }
                            .onEnded { value in
                                handleDragEnd(value)
                            }
                    )
                }
                .coordinateSpace(name: "pianoRoll")
            }

            // Velocity editor
            VelocityEditorView(sequencer: sequencer, zoomLevel: zoomLevel)
                .frame(height: 100)
                .background(Color.black.opacity(0.2))
        }
        .background(Color.black.opacity(0.8))
    }


    // MARK: - Computed Properties

    private var pianoRollWidth: CGFloat {
        let clipDurationBeats = Double(sequencer.clip.duration) / 48000.0 * (120.0 / 60.0)
        return CGFloat(clipDurationBeats) * zoomLevel
    }

    private var pianoRollHeight: CGFloat {
        CGFloat(maxNote - minNote + 1) * verticalZoom
    }


    // MARK: - Interaction Handlers

    private func handleDrag(_ value: DragGesture.Value) {
        let location = value.location

        switch sequencer.editingTool {
        case .pencil:
            handlePencilDrag(location)
        case .eraser:
            handleEraserDrag(location)
        case .select:
            handleSelectDrag(value)
        case .cut:
            break
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        let location = value.location

        switch sequencer.editingTool {
        case .pencil:
            handlePencilDragEnd(location)
        default:
            break
        }

        isDragging = false
        newNotePreview = nil
    }

    private func handlePencilDrag(_ location: CGPoint) {
        // Calculate position and pitch from location
        let position = positionFromX(location.x)
        let pitch = pitchFromY(location.y)

        newNotePreview = (position, pitch)
    }

    private func handlePencilDragEnd(_ location: CGPoint) {
        // Add note at final position
        let position = positionFromX(location.x)
        let pitch = pitchFromY(location.y)

        // Snap to grid
        let snappedPosition = sequencer.snapToGrid(position)

        // Calculate duration
        let duration = sequencer.gridDivision.samplesPerDivision(tempo: 120.0, sampleRate: 48000.0)

        // Check if note already exists
        if !sequencer.hasNoteAt(position: snappedPosition, pitch: pitch) {
            sequencer.addNote(
                position: snappedPosition,
                duration: duration * Int64(sequencer.defaultDuration),
                noteNumber: pitch
            )
        }
    }

    private func handleEraserDrag(_ location: CGPoint) {
        // Find and delete notes at location
        let position = positionFromX(location.x)
        let pitch = pitchFromY(location.y)

        let notes = sequencer.notesAt(position: position, pitch: pitch)
        for note in notes {
            sequencer.removeNote(note.id)
        }
    }

    private func handleSelectDrag(_ value: DragGesture.Value) {
        // TODO: Implement selection rectangle
    }

    private func selectNote(_ noteID: UUID) {
        sequencer.selectNote(noteID, clearExisting: true)
    }

    private func dragNote(_ noteID: UUID, offset: CGSize) {
        let positionOffset = Int64(offset.width / zoomLevel * (120.0 / 60.0) * 48000.0)
        let pitchOffset = -Int(offset.height / verticalZoom)

        // TODO: Apply offset to note
    }

    private func resizeNote(_ noteID: UUID, newDuration: Int64) {
        sequencer.resizeNote(noteID, newDuration: newDuration)
    }

    private func playNote(_ noteNumber: UInt8) {
        // TODO: Trigger MIDI note preview
        print("🎹 Preview note: \(sequencer.noteName(noteNumber))")
    }


    // MARK: - Coordinate Conversion

    private func positionFromX(_ x: CGFloat) -> Int64 {
        let beats = Double(x) / Double(zoomLevel)
        let seconds = beats * (60.0 / 120.0)
        return Int64(seconds * 48000.0)
    }

    private func pitchFromY(_ y: CGFloat) -> UInt8 {
        let noteIndex = Int(y / verticalZoom)
        let pitch = Int(maxNote) - noteIndex
        return UInt8(max(0, min(127, pitch)))
    }

    private func xFromPosition(_ position: Int64) -> CGFloat {
        let seconds = Double(position) / 48000.0
        let beats = seconds * (120.0 / 60.0)
        return CGFloat(beats) * zoomLevel
    }

    private func yFromPitch(_ pitch: UInt8) -> CGFloat {
        let noteIndex = Int(maxNote) - Int(pitch)
        return CGFloat(noteIndex) * verticalZoom
    }
}


// MARK: - Piano Roll Toolbar

struct PianoRollToolbar: View {
    @ObservedObject var sequencer: MIDISequencer

    var body: some View {
        HStack(spacing: 20) {
            // Editing tools
            HStack(spacing: 8) {
                ForEach(EditingTool.allCases, id: \.self) { tool in
                    Button(action: { sequencer.editingTool = tool }) {
                        Image(systemName: iconForTool(tool))
                            .font(.system(size: 20))
                            .foregroundColor(sequencer.editingTool == tool ? .blue : .white)
                            .frame(width: 40, height: 40)
                            .background(
                                sequencer.editingTool == tool ?
                                    Color.blue.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(6)
                    }
                }
            }

            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.3))

            // Grid settings
            HStack(spacing: 8) {
                Toggle("Snap", isOn: $sequencer.snapEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .font(.caption)

                Picker("Grid", selection: $sequencer.gridDivision) {
                    ForEach(GridDivision.allCases, id: \.self) { division in
                        Text(division.rawValue).tag(division)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 80)
            }

            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.3))

            // Operations
            HStack(spacing: 8) {
                Button(action: { sequencer.quantizeSelectedNotes() }) {
                    Label("Quantize", systemImage: "waveform.path.ecg")
                }

                Button(action: { sequencer.humanizeSelectedNotes() }) {
                    Label("Humanize", systemImage: "waveform")
                }

                Button(action: { sequencer.removeSelectedNotes() }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .font(.caption)

            Spacer()

            // Undo/Redo
            HStack(spacing: 8) {
                Button(action: { sequencer.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }

                Button(action: { sequencer.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
            }
            .font(.system(size: 20))
        }
        .padding(.horizontal)
        .foregroundColor(.white)
    }

    private func iconForTool(_ tool: EditingTool) -> String {
        switch tool {
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        case .select: return "cursor.rays"
        case .cut: return "scissors"
        }
    }
}


// MARK: - Piano Keyboard

struct PianoKeyboard: View {
    let minNote: UInt8
    let maxNote: UInt8
    let verticalZoom: CGFloat
    let onKeyTap: (UInt8) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach((minNote...maxNote).reversed(), id: \.self) { noteNumber in
                PianoKeyView(
                    noteNumber: noteNumber,
                    height: verticalZoom,
                    onTap: { onKeyTap(noteNumber) }
                )
            }
        }
        .background(Color.black.opacity(0.5))
    }
}


// MARK: - Piano Key

struct PianoKeyView: View {
    let noteNumber: UInt8
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isBlackKey ? Color.black : Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                if !isBlackKey && isC {
                    Text(noteName)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
            }
        }
        .frame(height: height)
    }

    private var isBlackKey: Bool {
        let note = Int(noteNumber) % 12
        return [1, 3, 6, 8, 10].contains(note)
    }

    private var isC: Bool {
        Int(noteNumber) % 12 == 0
    }

    private var noteName: String {
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(noteNumber) / 12 - 1
        let note = notes[Int(noteNumber) % 12]
        return "\(note)\(octave)"
    }
}


// MARK: - Piano Roll Grid

struct PianoRollGrid: View {
    let minNote: UInt8
    let maxNote: UInt8
    let clipDuration: Int64
    let sampleRate: Double
    let tempo: Double
    let zoomLevel: CGFloat
    let verticalZoom: CGFloat
    let gridDivision: GridDivision

    var body: some View {
        Canvas { context, size in
            // Horizontal lines (piano keys)
            for noteNumber in minNote...maxNote {
                let y = yFromPitch(noteNumber)
                let isBlackKey = [1, 3, 6, 8, 10].contains(Int(noteNumber) % 12)

                // Key background
                var bgRect = Path()
                bgRect.addRect(CGRect(x: 0, y: y, width: size.width, height: verticalZoom))
                context.fill(
                    bgRect,
                    with: .color(isBlackKey ? Color.black.opacity(0.2) : Color.white.opacity(0.05))
                )

                // Grid line
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 1)
            }

            // Vertical lines (beats)
            let beatsPerSecond = tempo / 60.0
            let clipDurationSeconds = Double(clipDuration) / sampleRate
            let clipDurationBeats = clipDurationSeconds * beatsPerSecond

            let gridSize = gridDivision.samplesPerDivision(tempo: tempo, sampleRate: sampleRate)
            let gridSizeSeconds = Double(gridSize) / sampleRate
            let gridSizeBeats = gridSizeSeconds * beatsPerSecond

            var beat = 0.0
            while beat < clipDurationBeats {
                let x = CGFloat(beat) * zoomLevel
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))

                let isBarLine = beat.truncatingRemainder(dividingBy: 4.0) == 0
                let opacity: CGFloat = isBarLine ? 0.3 : 0.1
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: isBarLine ? 2 : 1)

                beat += gridSizeBeats
            }
        }
    }

    private func yFromPitch(_ pitch: UInt8) -> CGFloat {
        let noteIndex = Int(maxNote) - Int(pitch)
        return CGFloat(noteIndex) * verticalZoom
    }
}


// MARK: - Note View

struct NoteView: View {
    let note: MIDINote
    let sampleRate: Double
    let zoomLevel: CGFloat
    let verticalZoom: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onResize: (Int64) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(noteColor.opacity(isSelected ? 1.0 : 0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .frame(width: noteWidth, height: verticalZoom - 2)
            .offset(x: noteOffsetX, y: noteOffsetY)
            .onTapGesture {
                onTap()
            }
    }

    private var noteWidth: CGFloat {
        let durationSeconds = Double(note.duration) / sampleRate
        let durationBeats = durationSeconds * (120.0 / 60.0)
        return max(10, CGFloat(durationBeats) * zoomLevel)
    }

    private var noteOffsetX: CGFloat {
        let positionSeconds = Double(note.position) / sampleRate
        let positionBeats = positionSeconds * (120.0 / 60.0)
        return CGFloat(positionBeats) * zoomLevel
    }

    private var noteOffsetY: CGFloat {
        let noteIndex = 127 - Int(note.noteNumber)
        return CGFloat(noteIndex) * verticalZoom + 1
    }

    private var noteColor: Color {
        Color.blue.opacity(Double(note.velocity) / 127.0)
    }
}


// MARK: - Preview Note View

struct PreviewNoteView: View {
    let position: Int64
    let pitch: UInt8
    let duration: Int64
    let sampleRate: Double
    let zoomLevel: CGFloat
    let verticalZoom: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.green.opacity(0.5))
            .frame(width: noteWidth, height: verticalZoom - 2)
            .offset(x: noteOffsetX, y: noteOffsetY)
    }

    private var noteWidth: CGFloat {
        let durationSeconds = Double(duration) / sampleRate
        let durationBeats = durationSeconds * (120.0 / 60.0)
        return max(10, CGFloat(durationBeats) * zoomLevel)
    }

    private var noteOffsetX: CGFloat {
        let positionSeconds = Double(position) / sampleRate
        let positionBeats = positionSeconds * (120.0 / 60.0)
        return CGFloat(positionBeats) * zoomLevel
    }

    private var noteOffsetY: CGFloat {
        let noteIndex = 127 - Int(pitch)
        return CGFloat(noteIndex) * verticalZoom + 1
    }
}


// MARK: - Velocity Editor

struct VelocityEditorView: View {
    @ObservedObject var sequencer: MIDISequencer
    let zoomLevel: CGFloat

    var body: some View {
        Canvas { context, size in
            guard let notes = sequencer.clip.midiData?.notes else { return }

            for note in notes {
                let x = xFromPosition(note.position)
                let width = widthFromDuration(note.duration)
                let height = CGFloat(note.velocity) / 127.0 * size.height

                var path = Path()
                path.addRect(CGRect(
                    x: x,
                    y: size.height - height,
                    width: max(2, width),
                    height: height
                ))

                let isSelected = sequencer.selectedNotes.contains(note.id)
                context.fill(
                    path,
                    with: .color(isSelected ? Color.blue : Color.gray.opacity(0.6))
                )
            }
        }
        .background(Color.black.opacity(0.3))
    }

    private func xFromPosition(_ position: Int64) -> CGFloat {
        let seconds = Double(position) / 48000.0
        let beats = seconds * (120.0 / 60.0)
        return CGFloat(beats) * zoomLevel
    }

    private func widthFromDuration(_ duration: Int64) -> CGFloat {
        let seconds = Double(duration) / 48000.0
        let beats = seconds * (120.0 / 60.0)
        return CGFloat(beats) * zoomLevel
    }
}


// MARK: - Preview

struct PianoRollView_Previews: PreviewProvider {
    static var previews: some View {
        let clip = Clip.midiClip(
            name: "MIDI Clip",
            startPosition: 0,
            duration: 48000 * 8  // 8 seconds
        )

        let sequencer = MIDISequencer(clip: clip)

        return PianoRollView(sequencer: sequencer)
            .preferredColorScheme(.dark)
    }
}
