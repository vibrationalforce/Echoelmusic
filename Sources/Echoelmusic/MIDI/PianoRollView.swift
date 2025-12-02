import SwiftUI
import AVFoundation

// MARK: - Piano Roll MIDI Editor
/// Professional piano roll for MIDI note editing
/// Features: Note drawing, velocity editing, quantization, snap-to-grid

struct PianoRollView: View {
    @StateObject private var viewModel = PianoRollViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Piano Keys (left side)
                PianoKeysView(
                    lowestNote: viewModel.lowestNote,
                    highestNote: viewModel.highestNote,
                    noteHeight: viewModel.noteHeight * scale
                )
                .frame(width: 60)

                // Note Grid (main area)
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Grid Background
                        NoteGridView(
                            viewModel: viewModel,
                            scale: scale
                        )

                        // MIDI Notes
                        ForEach(viewModel.notes) { note in
                            MIDINoteView(
                                note: note,
                                viewModel: viewModel,
                                scale: scale,
                                isSelected: viewModel.selectedNotes.contains(note.id)
                            )
                            .onTapGesture {
                                viewModel.toggleSelection(note.id)
                            }
                        }

                        // Playhead
                        PlayheadView(
                            position: viewModel.playheadPosition,
                            viewModel: viewModel,
                            scale: scale
                        )
                    }
                    .frame(
                        width: viewModel.gridWidth * scale,
                        height: CGFloat(viewModel.highestNote - viewModel.lowestNote + 1) * viewModel.noteHeight * scale
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if viewModel.editMode == .draw {
                                    viewModel.addNote(at: value.location, scale: scale)
                                }
                            }
                    )
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Edit Mode Picker
                Picker("Mode", selection: $viewModel.editMode) {
                    ForEach(PianoRollViewModel.EditMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Divider()

                // Quantize
                Menu {
                    ForEach(PianoRollViewModel.Quantize.allCases, id: \.self) { q in
                        Button(q.rawValue) {
                            viewModel.quantize = q
                        }
                    }
                } label: {
                    Label("Quantize: \(viewModel.quantize.rawValue)", systemImage: "squareshape.split.3x3")
                }

                Divider()

                // Velocity
                Slider(value: $viewModel.defaultVelocity, in: 0...127)
                    .frame(width: 100)
                Text("Vel: \(Int(viewModel.defaultVelocity))")

                Divider()

                // Zoom
                Button(action: { scale = max(0.5, scale - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                Button(action: { scale = min(3.0, scale + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }

                Spacer()

                // Transport
                Button(action: viewModel.togglePlayback) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
            }
        }
    }
}

// MARK: - Piano Keys View

struct PianoKeysView: View {
    let lowestNote: Int
    let highestNote: Int
    let noteHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach((lowestNote...highestNote).reversed(), id: \.self) { note in
                let isBlack = [1, 3, 6, 8, 10].contains(note % 12)
                let noteName = noteToName(note)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(isBlack ? Color.black : Color.white)
                        .frame(height: noteHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )

                    if note % 12 == 0 { // C notes
                        Text(noteName)
                            .font(.caption2)
                            .foregroundColor(isBlack ? .white : .black)
                            .padding(.leading, 4)
                    }
                }
            }
        }
    }

    func noteToName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = note / 12 - 1
        return "\(names[note % 12])\(octave)"
    }
}

// MARK: - Note Grid View

struct NoteGridView: View {
    @ObservedObject var viewModel: PianoRollViewModel
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let noteCount = viewModel.highestNote - viewModel.lowestNote + 1
            let noteHeight = viewModel.noteHeight * scale
            let beatWidth = viewModel.beatWidth * scale

            // Draw horizontal lines (note rows)
            for i in 0...noteCount {
                let y = CGFloat(i) * noteHeight
                let isBlack = [1, 3, 6, 8, 10].contains((viewModel.highestNote - i) % 12)

                // Background color for black keys
                if isBlack {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: noteHeight)),
                        with: .color(.gray.opacity(0.1))
                    )
                }

                // Grid line
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
            }

            // Draw vertical lines (beats)
            let totalBeats = Int(viewModel.duration / (60.0 / viewModel.tempo))
            for beat in 0...totalBeats {
                let x = CGFloat(beat) * beatWidth
                let isMeasure = beat % 4 == 0

                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    path,
                    with: .color(isMeasure ? .gray.opacity(0.5) : .gray.opacity(0.2)),
                    lineWidth: isMeasure ? 1 : 0.5
                )
            }
        }
    }
}

// MARK: - MIDI Note View

struct MIDINoteView: View {
    let note: MIDINote
    @ObservedObject var viewModel: PianoRollViewModel
    let scale: CGFloat
    let isSelected: Bool

    @State private var isDragging = false
    @State private var isResizing = false

    var body: some View {
        let noteHeight = viewModel.noteHeight * scale
        let beatWidth = viewModel.beatWidth * scale

        let x = CGFloat(note.startBeat) * beatWidth
        let y = CGFloat(viewModel.highestNote - note.pitch) * noteHeight
        let width = CGFloat(note.duration) * beatWidth
        let height = noteHeight - 2

        // Velocity-based color
        let velocityColor = Color(
            hue: 0.6 - Double(note.velocity) / 127.0 * 0.3,
            saturation: 0.7,
            brightness: 0.5 + Double(note.velocity) / 127.0 * 0.3
        )

        RoundedRectangle(cornerRadius: 2)
            .fill(velocityColor)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .frame(width: max(4, width), height: height)
            .position(x: x + width / 2, y: y + height / 2 + 1)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if viewModel.editMode == .select {
                            viewModel.moveNote(note.id, by: value.translation, scale: scale)
                        }
                    }
            )
            .contextMenu {
                Button("Delete") {
                    viewModel.deleteNote(note.id)
                }
                Button("Duplicate") {
                    viewModel.duplicateNote(note.id)
                }
                Divider()
                Menu("Velocity") {
                    ForEach([32, 64, 96, 127], id: \.self) { vel in
                        Button("\(vel)") {
                            viewModel.setNoteVelocity(note.id, velocity: vel)
                        }
                    }
                }
            }
    }
}

// MARK: - Playhead View

struct PlayheadView: View {
    let position: Double
    @ObservedObject var viewModel: PianoRollViewModel
    let scale: CGFloat

    var body: some View {
        let beatWidth = viewModel.beatWidth * scale
        let x = CGFloat(position) * beatWidth

        Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .position(x: x, y: 0)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - View Model

@MainActor
class PianoRollViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var notes: [MIDINote] = []
    @Published var selectedNotes: Set<UUID> = []
    @Published var editMode: EditMode = .select
    @Published var quantize: Quantize = .sixteenth
    @Published var defaultVelocity: Double = 100
    @Published var isPlaying: Bool = false
    @Published var playheadPosition: Double = 0 // In beats

    // MARK: - Configuration

    let lowestNote: Int = 24  // C1
    let highestNote: Int = 96 // C7
    let noteHeight: CGFloat = 16
    let beatWidth: CGFloat = 40

    var tempo: Double = 120.0
    var duration: Double = 60.0 // seconds

    var gridWidth: CGFloat {
        CGFloat(duration / (60.0 / tempo)) * beatWidth
    }

    // MARK: - Edit Modes

    enum EditMode: String, CaseIterable {
        case select = "Select"
        case draw = "Draw"
        case erase = "Erase"
        case velocity = "Velocity"

        var icon: String {
            switch self {
            case .select: return "arrow.up.left.and.arrow.down.right"
            case .draw: return "pencil"
            case .erase: return "eraser"
            case .velocity: return "waveform"
            }
        }
    }

    enum Quantize: String, CaseIterable {
        case none = "Off"
        case whole = "1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtysecond = "1/32"

        var beats: Double {
            switch self {
            case .none: return 0
            case .whole: return 4
            case .half: return 2
            case .quarter: return 1
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtysecond: return 0.125
            }
        }
    }

    // MARK: - Note Operations

    func addNote(at location: CGPoint, scale: CGFloat) {
        let pitch = highestNote - Int(location.y / (noteHeight * scale))
        var startBeat = Double(location.x / (beatWidth * scale))

        // Quantize
        if quantize != .none {
            startBeat = (startBeat / quantize.beats).rounded() * quantize.beats
        }

        let note = MIDINote(
            pitch: max(lowestNote, min(highestNote, pitch)),
            velocity: Int(defaultVelocity),
            startBeat: startBeat,
            duration: quantize == .none ? 0.5 : quantize.beats
        )

        notes.append(note)
        print("🎹 Added note: \(note.pitch) at beat \(note.startBeat)")
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        selectedNotes.remove(id)
    }

    func duplicateNote(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        var newNote = note
        newNote.id = UUID()
        newNote.startBeat += note.duration
        notes.append(newNote)
    }

    func moveNote(_ id: UUID, by translation: CGSize, scale: CGFloat) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }

        let pitchDelta = -Int(translation.height / (noteHeight * scale))
        let beatDelta = Double(translation.width / (beatWidth * scale))

        notes[index].pitch = max(lowestNote, min(highestNote, notes[index].pitch + pitchDelta))
        notes[index].startBeat = max(0, notes[index].startBeat + beatDelta)
    }

    func setNoteVelocity(_ id: UUID, velocity: Int) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].velocity = velocity
    }

    func toggleSelection(_ id: UUID) {
        if selectedNotes.contains(id) {
            selectedNotes.remove(id)
        } else {
            selectedNotes.insert(id)
        }
    }

    func selectAll() {
        selectedNotes = Set(notes.map { $0.id })
    }

    func deselectAll() {
        selectedNotes.removeAll()
    }

    func deleteSelected() {
        notes.removeAll { selectedNotes.contains($0.id) }
        selectedNotes.removeAll()
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    private var playbackTimer: Timer?

    private func startPlayback() {
        let beatsPerSecond = tempo / 60.0
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.playheadPosition += beatsPerSecond * 0.016
                if self.playheadPosition >= self.duration / (60.0 / self.tempo) {
                    self.playheadPosition = 0
                }
            }
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Export

    func exportToMIDI() -> Data? {
        // Generate MIDI file data
        // In production: Use AudioToolbox MusicSequence
        print("📤 Exporting \(notes.count) notes to MIDI")
        return nil
    }

    func importFromMIDI(_ data: Data) {
        // Import MIDI file
        // In production: Parse MIDI data
        print("📥 Importing MIDI data")
    }
}

// MARK: - MIDI Note Model

struct MIDINote: Identifiable {
    var id = UUID()
    var pitch: Int       // MIDI note number (0-127)
    var velocity: Int    // 0-127
    var startBeat: Double
    var duration: Double // In beats
}

// MARK: - Preview

#Preview {
    PianoRollView()
}
