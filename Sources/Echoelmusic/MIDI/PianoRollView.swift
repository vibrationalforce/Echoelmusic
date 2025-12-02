import SwiftUI
import AVFoundation

// MARK: - Piano Roll MIDI Editor
/// Professional piano roll for MIDI note editing
/// Full MIDI 2.0 + MPE Integration for expressive playback
/// Features: Note drawing, velocity editing, per-note expression, quantization

struct PianoRollView: View {
    @StateObject private var viewModel = PianoRollViewModel()

    // MIDI 2.0 + MPE Integration
    var midi2Manager: MIDI2Manager?
    var mpeZoneManager: MPEZoneManager?

    init(midi2Manager: MIDI2Manager? = nil, mpeZoneManager: MPEZoneManager? = nil) {
        self.midi2Manager = midi2Manager
        self.mpeZoneManager = mpeZoneManager
    }
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

                // MIDI 2.0 + MPE Toggle
                Toggle("MPE", isOn: $viewModel.useMPE)
                    .toggleStyle(.button)
                    .tint(viewModel.useMPE ? .green : .gray)

                // Expression Lane Selector
                Menu {
                    Button("Hide") { viewModel.expressionLane = nil }
                    Divider()
                    ForEach(PerNoteExpression.allCases, id: \.self) { expr in
                        Button {
                            viewModel.expressionLane = expr
                        } label: {
                            Label(expr.rawValue, systemImage: expr.icon)
                        }
                    }
                } label: {
                    Label(
                        viewModel.expressionLane?.rawValue ?? "Expression",
                        systemImage: viewModel.expressionLane?.icon ?? "slider.horizontal.3"
                    )
                }

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

    // MARK: - MIDI 2.0 + MPE

    @Published var expressionLane: PerNoteExpression? = nil // nil = hidden
    @Published var useMPE: Bool = true // Use MPE for polyphonic expression
    @Published var pitchBendRange: Int = 48 // Semitones (MPE default: 48)

    var midi2Manager: MIDI2Manager?
    var mpeZoneManager: MPEZoneManager?

    // Active MPE voices during playback
    private var activeVoices: [UUID: MPEZoneManager.MPEVoice] = [:]

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

    // MARK: - MIDI 2.0 + MPE Connection

    func connect(midi2: MIDI2Manager, mpe: MPEZoneManager) {
        self.midi2Manager = midi2
        self.mpeZoneManager = mpe

        // Configure MPE zone
        mpe.sendMPEConfiguration(memberChannels: 15)
        mpe.setPitchBendRange(semitones: UInt8(pitchBendRange))

        print("🎹 PianoRoll: Connected to MIDI 2.0 + MPE")
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

    // MARK: - Playback with MIDI 2.0 + MPE

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    private var playbackTimer: Timer?
    private var lastPlayheadPosition: Double = 0
    private var triggeredNotes: Set<UUID> = []

    private func startPlayback() {
        lastPlayheadPosition = playheadPosition
        triggeredNotes.removeAll()

        let beatsPerSecond = tempo / 60.0
        let updateInterval = 0.005 // 5ms for accurate timing

        playbackTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                let previousPosition = self.playheadPosition
                self.playheadPosition += beatsPerSecond * updateInterval

                // Check for notes to trigger
                for note in self.notes {
                    let noteID = note.id

                    // Note On
                    if note.startBeat >= previousPosition && note.startBeat < self.playheadPosition {
                        if !self.triggeredNotes.contains(noteID) {
                            self.triggerNoteOn(note)
                            self.triggeredNotes.insert(noteID)
                        }
                    }

                    // Note Off
                    let noteEnd = note.startBeat + note.duration
                    if noteEnd >= previousPosition && noteEnd < self.playheadPosition {
                        self.triggerNoteOff(note)
                        self.triggeredNotes.remove(noteID)
                    }

                    // Update per-note expression during playback
                    if self.triggeredNotes.contains(noteID) {
                        self.updateNoteExpression(note)
                    }
                }

                // Loop
                let totalBeats = self.duration / (60.0 / self.tempo)
                if self.playheadPosition >= totalBeats {
                    self.playheadPosition = 0
                    self.releaseAllVoices()
                    self.triggeredNotes.removeAll()
                }
            }
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        releaseAllVoices()
        triggeredNotes.removeAll()
    }

    // MARK: - MIDI 2.0 + MPE Note Triggering

    private func triggerNoteOn(_ note: MIDINote) {
        if useMPE, let mpe = mpeZoneManager {
            // Allocate MPE voice for polyphonic per-note expression
            if let voice = mpe.allocateVoice(note: UInt8(note.pitch), velocity: note.velocity32bit) {
                activeVoices[note.id] = voice

                // Apply initial per-note expression
                mpe.setVoicePitchBend(voice: voice, bend: note.pitchBend)
                mpe.setVoicePressure(voice: voice, pressure: note.pressure)
                mpe.setVoiceBrightness(voice: voice, brightness: note.brightness)
                mpe.setVoiceTimbre(voice: voice, timbre: note.timbre)

                print("🎹 MPE Note On: \(note.pitch) vel=\(note.velocity) ch=\(voice.channel + 1)")
            }
        } else if let midi2 = midi2Manager {
            // MIDI 2.0 without MPE (single channel)
            midi2.sendNoteOn(channel: 0, note: UInt8(note.pitch), velocity: note.velocity32bit)
            print("🎹 MIDI2 Note On: \(note.pitch) vel=\(note.velocity)")
        }
    }

    private func triggerNoteOff(_ note: MIDINote) {
        if useMPE, let mpe = mpeZoneManager {
            if let voice = activeVoices[note.id] {
                mpe.deallocateVoice(voice: voice)
                activeVoices.removeValue(forKey: note.id)
                print("🎹 MPE Note Off: \(note.pitch)")
            }
        } else if let midi2 = midi2Manager {
            midi2.sendNoteOff(channel: 0, note: UInt8(note.pitch))
            print("🎹 MIDI2 Note Off: \(note.pitch)")
        }
    }

    private func updateNoteExpression(_ note: MIDINote) {
        guard useMPE, let mpe = mpeZoneManager, let voice = activeVoices[note.id] else { return }

        // Get expression value at current playhead position
        let currentBeat = playheadPosition
        let relativePosition = currentBeat - note.startBeat

        // Apply automation if present
        if !note.pitchBendAutomation.isEmpty {
            let value = interpolateAutomation(note.pitchBendAutomation, at: relativePosition)
            mpe.setVoicePitchBend(voice: voice, bend: value)
        }

        if !note.pressureAutomation.isEmpty {
            let value = interpolateAutomation(note.pressureAutomation, at: relativePosition)
            mpe.setVoicePressure(voice: voice, pressure: value)
        }

        if !note.brightnessAutomation.isEmpty {
            let value = interpolateAutomation(note.brightnessAutomation, at: relativePosition)
            mpe.setVoiceBrightness(voice: voice, brightness: value)
        }
    }

    private func interpolateAutomation(_ points: [MIDINote.AutomationPoint], at beat: Double) -> Float {
        guard !points.isEmpty else { return 0.5 }

        let sorted = points.sorted { $0.beat < $1.beat }

        // Find surrounding points
        var before: MIDINote.AutomationPoint?
        var after: MIDINote.AutomationPoint?

        for point in sorted {
            if point.beat <= beat {
                before = point
            } else {
                after = point
                break
            }
        }

        // Interpolate
        if let b = before, let a = after {
            let t = Float((beat - b.beat) / (a.beat - b.beat))
            return b.value + (a.value - b.value) * t
        } else if let b = before {
            return b.value
        } else if let a = after {
            return a.value
        }

        return 0.5
    }

    private func releaseAllVoices() {
        if let mpe = mpeZoneManager {
            for (noteID, voice) in activeVoices {
                mpe.deallocateVoice(voice: voice)
            }
        }
        activeVoices.removeAll()
    }

    // MARK: - Per-Note Expression Editing

    func setNoteExpression(_ noteID: UUID, expression: PerNoteExpression, value: Float) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }

        switch expression {
        case .pitchBend:
            notes[index].pitchBend = max(-1, min(1, value))
        case .pressure:
            notes[index].pressure = max(0, min(1, value))
        case .brightness:
            notes[index].brightness = max(0, min(1, value))
        case .timbre:
            notes[index].timbre = max(0, min(1, value))
        }

        // Update live if playing
        if isPlaying, let voice = activeVoices[noteID], let mpe = mpeZoneManager {
            switch expression {
            case .pitchBend:
                mpe.setVoicePitchBend(voice: voice, bend: notes[index].pitchBend)
            case .pressure:
                mpe.setVoicePressure(voice: voice, pressure: notes[index].pressure)
            case .brightness:
                mpe.setVoiceBrightness(voice: voice, brightness: notes[index].brightness)
            case .timbre:
                mpe.setVoiceTimbre(voice: voice, timbre: notes[index].timbre)
            }
        }
    }

    func addExpressionAutomation(_ noteID: UUID, expression: PerNoteExpression, beat: Double, value: Float) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }

        let point = MIDINote.AutomationPoint(beat: beat, value: value)

        switch expression {
        case .pitchBend:
            notes[index].pitchBendAutomation.append(point)
        case .pressure:
            notes[index].pressureAutomation.append(point)
        case .brightness:
            notes[index].brightnessAutomation.append(point)
        case .timbre:
            // Would need to add timbreAutomation to MIDINote
            break
        }
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

// MARK: - MIDI Note Model (MIDI 2.0 + MPE)

struct MIDINote: Identifiable {
    var id = UUID()
    var pitch: Int       // MIDI note number (0-127)
    var velocity: Int    // 0-127 (displayed), internally 0.0-1.0 for MIDI 2.0
    var startBeat: Double
    var duration: Double // In beats

    // MIDI 2.0 Per-Note Expression
    var pitchBend: Float = 0.0      // -1.0 to +1.0 (MIDI 2.0: 32-bit resolution)
    var pressure: Float = 0.0       // 0.0 to 1.0 (aftertouch)
    var brightness: Float = 0.5     // 0.0 to 1.0 (CC74 / MPE Y-axis)
    var timbre: Float = 0.5         // 0.0 to 1.0 (CC71)

    // MPE Voice tracking
    var mpeVoiceID: UUID?

    // MIDI 2.0 32-bit velocity
    var velocity32bit: Float {
        Float(velocity) / 127.0
    }

    // Expression automation points
    var pitchBendAutomation: [AutomationPoint] = []
    var pressureAutomation: [AutomationPoint] = []
    var brightnessAutomation: [AutomationPoint] = []

    struct AutomationPoint: Identifiable {
        let id = UUID()
        var beat: Double
        var value: Float
    }
}

// MARK: - Per-Note Controller Type

enum PerNoteExpression: String, CaseIterable {
    case pitchBend = "Pitch Bend"
    case pressure = "Pressure"
    case brightness = "Brightness (Y)"
    case timbre = "Timbre"

    var icon: String {
        switch self {
        case .pitchBend: return "arrow.up.arrow.down"
        case .pressure: return "hand.point.down.fill"
        case .brightness: return "sun.max.fill"
        case .timbre: return "waveform"
        }
    }

    var range: ClosedRange<Float> {
        switch self {
        case .pitchBend: return -1.0...1.0
        case .pressure, .brightness, .timbre: return 0.0...1.0
        }
    }
}

// MARK: - Preview

#Preview {
    PianoRollView()
}
