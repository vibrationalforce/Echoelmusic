import SwiftUI

/// Professional Piano Roll MIDI Editor
/// Full user control over MIDI notes - draw, edit, quantize
/// NOT AI-generated - USER creates every note!
@MainActor
struct PianoRollView: View {

    // MARK: - Properties

    @ObservedObject var dawCore: DAWCore
    let clipId: UUID

    // MARK: - State

    @State private var zoom: CGFloat = 1.0
    @State private var verticalZoom: CGFloat = 1.0
    @State private var selectedNotes: Set<UUID> = []
    @State private var isDrawing = false
    @State private var drawStartPosition: CGPoint?
    @State private var showQuantizeMenu = false
    @State private var selectedQuantization: DAWCore.Quantization = .sixteenth

    // MARK: - Constants

    private let noteHeight: CGFloat = 20
    private let beatWidth: CGFloat = 100
    private let pianoKeyWidth: CGFloat = 80

    // MARK: - Computed Properties

    private var clip: DAWCore.Clip? {
        for track in dawCore.project.tracks {
            if let foundClip = track.clips.first(where: { $0.id == clipId }) {
                return foundClip
            }
        }
        return nil
    }

    private var midiNotes: [DAWCore.MIDIClip.MIDINote] {
        guard let clip = clip,
              case .midi(let midiClip) = clip.type else {
            return []
        }
        return midiClip.notes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Main Editor
            HStack(spacing: 0) {
                // Piano Keys
                pianoKeys
                    .frame(width: pianoKeyWidth)

                Divider()

                // Note Grid
                noteGrid
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Piano Roll")
                .font(.headline)

            Spacer()

            // Quantize Button
            Button(action: { showQuantizeMenu.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.3x3")
                    Text("Quantize")
                    Text(selectedQuantization.displayName)
                        .foregroundColor(.secondary)
                }
            }
            .popover(isPresented: $showQuantizeMenu) {
                QuantizeMenu(
                    selectedQuantization: $selectedQuantization,
                    onQuantize: {
                        if let clip = clip {
                            dawCore.quantizeNotes(in: clip.id, to: selectedQuantization)
                        }
                    }
                )
            }

            Divider()
                .frame(height: 20)

            // Horizontal Zoom
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)

                Button(action: { zoom = max(0.5, zoom - 0.1) }) {
                    Image(systemName: "minus")
                }

                Text("\(Int(zoom * 100))%")
                    .font(.caption)
                    .frame(width: 50)

                Button(action: { zoom = min(3.0, zoom + 0.1) }) {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            // Vertical Zoom
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)

                Button(action: { verticalZoom = max(0.5, verticalZoom - 0.1) }) {
                    Image(systemName: "minus")
                }

                Text("\(Int(verticalZoom * 100))%")
                    .font(.caption)
                    .frame(width: 50)

                Button(action: { verticalZoom = min(2.0, verticalZoom + 0.1) }) {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            // Delete Selected
            Button(action: deleteSelectedNotes) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedNotes.isEmpty)

            // Select All
            Button(action: selectAllNotes) {
                Label("Select All", systemImage: "checkmark.circle")
            }
        }
        .padding()
        .frame(height: 50)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Piano Keys

    private var pianoKeys: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach((0..<128).reversed(), id: \.self) { note in
                    PianoKeyView(note: note, height: noteHeight * verticalZoom)
                }
            }
        }
        .background(Color.secondary.opacity(0.03))
    }

    // MARK: - Note Grid

    private var noteGrid: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Grid Background
                    gridBackground

                    // MIDI Notes
                    ForEach(midiNotes) { note in
                        NoteView(
                            note: note,
                            isSelected: selectedNotes.contains(note.id),
                            noteHeight: noteHeight * verticalZoom,
                            beatWidth: beatWidth * zoom
                        )
                        .onTapGesture {
                            toggleNoteSelection(note.id)
                        }
                    }

                    // Draw Preview
                    if isDrawing, let start = drawStartPosition {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 50 * zoom, height: noteHeight * verticalZoom)
                            .position(start)
                    }
                }
                .frame(
                    width: (clip?.duration ?? 4) * beatWidth * zoom,
                    height: 128 * noteHeight * verticalZoom
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(at: value.location, isEnded: false)
                        }
                        .onEnded { value in
                            handleDrag(at: value.location, isEnded: true)
                        }
                )
            }
        }
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        ZStack {
            // Horizontal lines (notes)
            VStack(spacing: 0) {
                ForEach(0..<128, id: \.self) { note in
                    Rectangle()
                        .fill(isBlackKey(note) ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.03))
                        .frame(height: noteHeight * verticalZoom)
                        .border(Color.secondary.opacity(0.1), width: 0.5)
                }
            }

            // Vertical lines (beats)
            HStack(spacing: 0) {
                ForEach(0..<Int((clip?.duration ?? 4) * 4), id: \.self) { subdivision in
                    let isBeat = subdivision % 4 == 0
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: beatWidth * zoom / 4)
                        .border(Color.secondary.opacity(isBeat ? 0.3 : 0.1), width: isBeat ? 1 : 0.5)
                }
            }
        }
    }

    // MARK: - Helpers

    private func isBlackKey(_ note: Int) -> Bool {
        let noteInOctave = note % 12
        return [1, 3, 6, 8, 10].contains(noteInOctave) // C#, D#, F#, G#, A#
    }

    private func toggleNoteSelection(_ noteId: UUID) {
        if selectedNotes.contains(noteId) {
            selectedNotes.remove(noteId)
        } else {
            selectedNotes.insert(noteId)
        }
    }

    private func selectAllNotes() {
        selectedNotes = Set(midiNotes.map { $0.id })
    }

    private func deleteSelectedNotes() {
        guard let clip = clip else { return }

        for noteId in selectedNotes {
            dawCore.deleteMIDINote(clipId: clip.id, noteId: noteId)
        }

        selectedNotes.removeAll()
    }

    private func handleDrag(at location: CGPoint, isEnded: Bool) {
        if !isEnded {
            // Drawing mode - show preview
            drawStartPosition = location
            isDrawing = true
        } else {
            // Create note
            guard let clip = clip else { return }

            // Calculate pitch from Y position
            let pitch = 127 - Int(location.y / (noteHeight * verticalZoom))

            // Calculate time from X position
            let time = location.x / (beatWidth * zoom)

            // Default duration: 1 beat
            let duration = 1.0

            // Add note
            dawCore.addMIDINote(to: clip.id, pitch: pitch, velocity: 100, startTime: time, duration: duration)

            // Reset draw state
            isDrawing = false
            drawStartPosition = nil

            DebugConsole.shared.debug("Added MIDI note: pitch=\(pitch), time=\(time)", category: "PianoRoll")
        }
    }
}

// MARK: - Piano Key View

struct PianoKeyView: View {
    let note: Int
    let height: CGFloat

    private var isBlackKey: Bool {
        let noteInOctave = note % 12
        return [1, 3, 6, 8, 10].contains(noteInOctave)
    }

    private var noteName: String {
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        return "\(notes[note % 12])\(octave)"
    }

    var body: some View {
        HStack {
            Text(noteName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isBlackKey ? .white : .primary)
                .padding(.leading, 4)

            Spacer()

            // Middle C indicator
            if note == 60 {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 4)
            }
        }
        .frame(height: height)
        .background(isBlackKey ? Color.secondary : Color.secondary.opacity(0.1))
        .border(Color.secondary.opacity(0.3), width: 0.5)
    }
}

// MARK: - Note View

struct NoteView: View {
    let note: DAWCore.MIDIClip.MIDINote
    let isSelected: Bool
    let noteHeight: CGFloat
    let beatWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(velocityColor)
            .frame(
                width: note.duration * beatWidth,
                height: noteHeight * 0.9
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .overlay(
                Text("\(note.velocity)")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 2),
                alignment: .leading
            )
            .position(
                x: note.startTime * beatWidth + (note.duration * beatWidth / 2),
                y: CGFloat(127 - note.pitch) * noteHeight + (noteHeight / 2)
            )
    }

    private var velocityColor: Color {
        let intensity = Double(note.velocity) / 127.0
        return Color.blue.opacity(0.5 + (intensity * 0.5))
    }
}

// MARK: - Quantize Menu

struct QuantizeMenu: View {
    @Binding var selectedQuantization: DAWCore.Quantization
    let onQuantize: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantize")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(DAWCore.Quantization.allCases, id: \.self) { quantization in
                Button(action: {
                    selectedQuantization = quantization
                }) {
                    HStack {
                        Image(systemName: selectedQuantization == quantization ? "checkmark.circle.fill" : "circle")
                        Text(quantization.displayName)
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button(action: {
                onQuantize()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Apply Quantize")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 200)
    }
}

// MARK: - Quantization Extension

extension DAWCore.Quantization {
    var displayName: String {
        switch self {
        case .whole: return "1/1"
        case .half: return "1/2"
        case .quarter: return "1/4"
        case .eighth: return "1/8"
        case .sixteenth: return "1/16"
        case .thirtysecond: return "1/32"
        }
    }
}
