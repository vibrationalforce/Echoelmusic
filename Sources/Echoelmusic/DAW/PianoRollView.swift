// PianoRollView.swift
// Echoelmusic - Professional MIDI Piano Roll Editor
// Rivals: Ableton Live, FL Studio, Logic Pro, Cubase

import SwiftUI
import Combine

// MARK: - Piano Roll Engine

@MainActor
class PianoRollEngine: ObservableObject {
    // Note Data
    @Published var notes: [MIDINote] = []
    @Published var selectedNoteIds: Set<UUID> = []

    // View State
    @Published var horizontalZoom: Double = 40 // pixels per beat
    @Published var verticalZoom: Double = 16 // pixels per note
    @Published var scrollOffset: CGPoint = .zero
    @Published var visibleOctaveRange: ClosedRange<Int> = 0...10

    // Editing Mode
    @Published var editMode: EditMode = .select
    @Published var gridSnap: GridSnap = .sixteenth
    @Published var isSnapEnabled: Bool = true
    @Published var defaultVelocity: Int = 100
    @Published var defaultNoteLength: Double = 0.25 // beats

    // Playback
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Double = 0
    @Published var tempo: Double = 120
    @Published var loopStart: Double = 0
    @Published var loopEnd: Double = 4
    @Published var isLooping: Bool = true

    // Clipboard
    private var clipboard: [MIDINote] = []

    // Undo/Redo
    private var undoStack: [[MIDINote]] = []
    private var redoStack: [[MIDINote]] = []

    // MIDI Output
    var onNoteOn: ((Int, Int) -> Void)?
    var onNoteOff: ((Int) -> Void)?

    enum EditMode: String, CaseIterable {
        case select = "Select"
        case draw = "Draw"
        case erase = "Erase"
        case slice = "Slice"
        case velocity = "Velocity"
        case stretch = "Stretch"
    }

    enum GridSnap: String, CaseIterable {
        case off = "Off"
        case whole = "1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtySecond = "1/32"
        case tripletQuarter = "1/4T"
        case tripletEighth = "1/8T"
        case tripletSixteenth = "1/16T"

        var beatsValue: Double {
            switch self {
            case .off: return 0
            case .whole: return 4
            case .half: return 2
            case .quarter: return 1
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtySecond: return 0.125
            case .tripletQuarter: return 1.0/3.0
            case .tripletEighth: return 0.5/3.0
            case .tripletSixteenth: return 0.25/3.0
            }
        }
    }

    struct MIDINote: Identifiable, Codable, Equatable {
        let id: UUID
        var pitch: Int // 0-127
        var velocity: Int // 0-127
        var startBeat: Double
        var lengthBeats: Double
        var channel: Int
        var isSelected: Bool = false
        var isMuted: Bool = false

        var noteName: String {
            let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let octave = (pitch / 12) - 1
            let noteIndex = pitch % 12
            return "\(noteNames[noteIndex])\(octave)"
        }

        var isBlackKey: Bool {
            let noteInOctave = pitch % 12
            return [1, 3, 6, 8, 10].contains(noteInOctave)
        }
    }

    init() {
        // Demo notes
        loadDemoNotes()
    }

    private func loadDemoNotes() {
        notes = [
            MIDINote(id: UUID(), pitch: 60, velocity: 100, startBeat: 0, lengthBeats: 0.5, channel: 0),
            MIDINote(id: UUID(), pitch: 64, velocity: 90, startBeat: 0.5, lengthBeats: 0.5, channel: 0),
            MIDINote(id: UUID(), pitch: 67, velocity: 85, startBeat: 1, lengthBeats: 0.5, channel: 0),
            MIDINote(id: UUID(), pitch: 72, velocity: 110, startBeat: 1.5, lengthBeats: 1, channel: 0),
            MIDINote(id: UUID(), pitch: 60, velocity: 100, startBeat: 2.5, lengthBeats: 0.25, channel: 0),
            MIDINote(id: UUID(), pitch: 62, velocity: 95, startBeat: 2.75, lengthBeats: 0.25, channel: 0),
            MIDINote(id: UUID(), pitch: 64, velocity: 100, startBeat: 3, lengthBeats: 0.5, channel: 0),
            MIDINote(id: UUID(), pitch: 65, velocity: 105, startBeat: 3.5, lengthBeats: 0.5, channel: 0),
        ]
    }

    // MARK: - Snapping

    func snapToGrid(_ beat: Double) -> Double {
        guard isSnapEnabled, gridSnap != .off else { return beat }
        let snapValue = gridSnap.beatsValue
        return round(beat / snapValue) * snapValue
    }

    // MARK: - Note Management

    func addNote(pitch: Int, startBeat: Double, length: Double? = nil, velocity: Int? = nil) {
        saveUndoState()
        let note = MIDINote(
            id: UUID(),
            pitch: max(0, min(127, pitch)),
            velocity: velocity ?? defaultVelocity,
            startBeat: snapToGrid(startBeat),
            lengthBeats: length ?? defaultNoteLength,
            channel: 0
        )
        notes.append(note)

        // Trigger MIDI output
        onNoteOn?(note.pitch, note.velocity)

        // Schedule note off
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.onNoteOff?(note.pitch)
        }
    }

    func deleteNote(_ noteId: UUID) {
        saveUndoState()
        notes.removeAll { $0.id == noteId }
        selectedNoteIds.remove(noteId)
    }

    func deleteSelectedNotes() {
        saveUndoState()
        notes.removeAll { selectedNoteIds.contains($0.id) }
        selectedNoteIds.removeAll()
    }

    func moveNote(_ noteId: UUID, toPitch: Int, toBeat: Double) {
        saveUndoState()
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].pitch = max(0, min(127, toPitch))
            notes[index].startBeat = snapToGrid(toBeat)
        }
    }

    func resizeNote(_ noteId: UUID, newLength: Double) {
        saveUndoState()
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].lengthBeats = max(gridSnap.beatsValue, snapToGrid(newLength))
        }
    }

    func setNoteVelocity(_ noteId: UUID, velocity: Int) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].velocity = max(1, min(127, velocity))
        }
    }

    func moveSelectedNotes(pitchDelta: Int, beatDelta: Double) {
        saveUndoState()
        for noteId in selectedNoteIds {
            if let index = notes.firstIndex(where: { $0.id == noteId }) {
                notes[index].pitch = max(0, min(127, notes[index].pitch + pitchDelta))
                notes[index].startBeat = max(0, snapToGrid(notes[index].startBeat + beatDelta))
            }
        }
    }

    // MARK: - Selection

    func selectNote(_ noteId: UUID, addToSelection: Bool = false) {
        if !addToSelection {
            selectedNoteIds.removeAll()
        }
        selectedNoteIds.insert(noteId)
    }

    func deselectNote(_ noteId: UUID) {
        selectedNoteIds.remove(noteId)
    }

    func selectAll() {
        selectedNoteIds = Set(notes.map { $0.id })
    }

    func deselectAll() {
        selectedNoteIds.removeAll()
    }

    func selectNotesInRect(startPitch: Int, endPitch: Int, startBeat: Double, endBeat: Double) {
        let minPitch = min(startPitch, endPitch)
        let maxPitch = max(startPitch, endPitch)
        let minBeat = min(startBeat, endBeat)
        let maxBeat = max(startBeat, endBeat)

        for note in notes {
            if note.pitch >= minPitch && note.pitch <= maxPitch &&
               note.startBeat < maxBeat && note.startBeat + note.lengthBeats > minBeat {
                selectedNoteIds.insert(note.id)
            }
        }
    }

    // MARK: - Clipboard Operations

    func copySelectedNotes() {
        clipboard = notes.filter { selectedNoteIds.contains($0.id) }
    }

    func cutSelectedNotes() {
        copySelectedNotes()
        deleteSelectedNotes()
    }

    func paste(atBeat: Double? = nil) {
        guard !clipboard.isEmpty else { return }
        saveUndoState()

        let minBeat = clipboard.map { $0.startBeat }.min() ?? 0
        let pasteOffset = (atBeat ?? currentBeat) - minBeat

        selectedNoteIds.removeAll()

        for note in clipboard {
            var newNote = note
            newNote.id = UUID()
            newNote.startBeat += pasteOffset
            notes.append(newNote)
            selectedNoteIds.insert(newNote.id)
        }
    }

    // MARK: - Quantization

    func quantizeSelectedNotes() {
        saveUndoState()
        for noteId in selectedNoteIds {
            if let index = notes.firstIndex(where: { $0.id == noteId }) {
                notes[index].startBeat = snapToGrid(notes[index].startBeat)
            }
        }
    }

    func quantizeAllNotes() {
        saveUndoState()
        for index in notes.indices {
            notes[index].startBeat = snapToGrid(notes[index].startBeat)
        }
    }

    // MARK: - Transposition

    func transposeSelectedNotes(semitones: Int) {
        saveUndoState()
        for noteId in selectedNoteIds {
            if let index = notes.firstIndex(where: { $0.id == noteId }) {
                let newPitch = notes[index].pitch + semitones
                notes[index].pitch = max(0, min(127, newPitch))
            }
        }
    }

    // MARK: - Velocity Editing

    func scaleSelectedVelocities(factor: Double) {
        for noteId in selectedNoteIds {
            if let index = notes.firstIndex(where: { $0.id == noteId }) {
                let newVelocity = Int(Double(notes[index].velocity) * factor)
                notes[index].velocity = max(1, min(127, newVelocity))
            }
        }
    }

    func humanizeSelectedNotes(timingAmount: Double, velocityAmount: Int) {
        saveUndoState()
        for noteId in selectedNoteIds {
            if let index = notes.firstIndex(where: { $0.id == noteId }) {
                // Randomize timing
                let timingOffset = Double.random(in: -timingAmount...timingAmount)
                notes[index].startBeat = max(0, notes[index].startBeat + timingOffset)

                // Randomize velocity
                let velocityOffset = Int.random(in: -velocityAmount...velocityAmount)
                notes[index].velocity = max(1, min(127, notes[index].velocity + velocityOffset))
            }
        }
    }

    // MARK: - Undo/Redo

    private func saveUndoState() {
        undoStack.append(notes)
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(notes)
        notes = previousState
        selectedNoteIds.removeAll()
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(notes)
        notes = nextState
        selectedNoteIds.removeAll()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Playback

    func play() {
        isPlaying = true
    }

    func stop() {
        isPlaying = false
        currentBeat = 0
    }

    func pause() {
        isPlaying = false
    }

    // MARK: - Utilities

    func getClipLength() -> Double {
        guard let maxEnd = notes.map({ $0.startBeat + $0.lengthBeats }).max() else { return 4 }
        return max(4, ceil(maxEnd / 4) * 4)
    }

    func pitchToY(_ pitch: Int) -> CGFloat {
        CGFloat(127 - pitch) * verticalZoom
    }

    func yToPitch(_ y: CGFloat) -> Int {
        127 - Int(y / verticalZoom)
    }

    func beatToX(_ beat: Double) -> CGFloat {
        CGFloat(beat) * horizontalZoom
    }

    func xToBeat(_ x: CGFloat) -> Double {
        Double(x) / horizontalZoom
    }
}

// MARK: - Piano Roll View

struct PianoRollView: View {
    @StateObject private var engine = PianoRollEngine()
    @State private var isDragging = false
    @State private var isDrawing = false
    @State private var selectionRect: CGRect?
    @State private var dragStartNote: PianoRollEngine.MIDINote?
    @State private var dragStartPosition: CGPoint = .zero

    private let keyboardWidth: CGFloat = 60
    private let toolbarHeight: CGFloat = 44
    private let velocityLaneHeight: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            // Main Editor
            HStack(spacing: 0) {
                // Piano Keyboard
                pianoKeyboard

                // Note Grid
                noteGridView
            }

            // Velocity Lane
            velocityLaneView
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Edit Mode Picker
            Picker("Mode", selection: $engine.editMode) {
                ForEach(PianoRollEngine.EditMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Divider().frame(height: 24)

            // Grid Snap
            HStack(spacing: 4) {
                Toggle(isOn: $engine.isSnapEnabled) {
                    Image(systemName: "square.grid.3x3")
                }
                .toggleStyle(.button)

                Picker("Grid", selection: $engine.gridSnap) {
                    ForEach(PianoRollEngine.GridSnap.allCases, id: \.self) { snap in
                        Text(snap.rawValue).tag(snap)
                    }
                }
                .frame(width: 80)
            }

            Divider().frame(height: 24)

            // Transport
            HStack(spacing: 4) {
                Button(action: engine.stop) {
                    Image(systemName: "stop.fill")
                }

                Button(action: { engine.isPlaying ? engine.pause() : engine.play() }) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                }

                Toggle(isOn: $engine.isLooping) {
                    Image(systemName: "repeat")
                }
                .toggleStyle(.button)
            }

            Divider().frame(height: 24)

            // Actions
            HStack(spacing: 4) {
                Button(action: engine.undo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!engine.canUndo)

                Button(action: engine.redo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!engine.canRedo)

                Divider().frame(height: 24)

                Button("Quantize") {
                    if engine.selectedNoteIds.isEmpty {
                        engine.quantizeAllNotes()
                    } else {
                        engine.quantizeSelectedNotes()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Zoom
            HStack(spacing: 8) {
                Button(action: { engine.horizontalZoom = max(10, engine.horizontalZoom - 10) }) {
                    Image(systemName: "minus.magnifyingglass")
                }

                Text("\(Int(engine.horizontalZoom))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Button(action: { engine.horizontalZoom = min(200, engine.horizontalZoom + 10) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: toolbarHeight)
        .background(Color(white: 0.15))
    }

    // MARK: - Piano Keyboard

    private var pianoKeyboard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach((0...127).reversed(), id: \.self) { pitch in
                    PianoKeyView(
                        pitch: pitch,
                        height: engine.verticalZoom,
                        isPressed: isKeyPressed(pitch: pitch),
                        onPress: { previewNote(pitch: pitch) },
                        onRelease: { stopPreviewNote(pitch: pitch) }
                    )
                }
            }
        }
        .frame(width: keyboardWidth)
        .background(Color(white: 0.2))
    }

    private func isKeyPressed(pitch: Int) -> Bool {
        // Check if any playing note has this pitch
        guard engine.isPlaying else { return false }
        return engine.notes.contains { note in
            note.pitch == pitch &&
            note.startBeat <= engine.currentBeat &&
            note.startBeat + note.lengthBeats > engine.currentBeat
        }
    }

    private func previewNote(pitch: Int) {
        engine.onNoteOn?(pitch, engine.defaultVelocity)
    }

    private func stopPreviewNote(pitch: Int) {
        engine.onNoteOff?(pitch)
    }

    // MARK: - Note Grid

    private var noteGridView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Grid Background
                    gridBackground(size: CGSize(
                        width: max(geometry.size.width, engine.getClipLength() * engine.horizontalZoom),
                        height: 128 * engine.verticalZoom
                    ))

                    // Notes
                    notesView

                    // Playhead
                    if engine.isPlaying || engine.currentBeat > 0 {
                        playheadView
                    }

                    // Selection Rectangle
                    if let rect = selectionRect {
                        Rectangle()
                            .stroke(Color.cyan, lineWidth: 1)
                            .background(Color.cyan.opacity(0.1))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }

                    // Loop Region
                    if engine.isLooping {
                        loopRegionOverlay
                    }
                }
                .frame(
                    width: max(geometry.size.width, engine.getClipLength() * engine.horizontalZoom + 100),
                    height: 128 * engine.verticalZoom
                )
                .contentShape(Rectangle())
                .gesture(gridGesture)
            }
        }
    }

    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Draw horizontal lines (pitch separators)
            for pitch in 0...127 {
                let y = CGFloat(127 - pitch) * engine.verticalZoom
                let isC = pitch % 12 == 0
                let isBlackKey = [1, 3, 6, 8, 10].contains(pitch % 12)

                // Row background
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: engine.verticalZoom)),
                    with: .color(isBlackKey ? Color(white: 0.08) : Color(white: 0.12))
                )

                // Octave line
                if isC {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y + engine.verticalZoom))
                            path.addLine(to: CGPoint(x: size.width, y: y + engine.verticalZoom))
                        },
                        with: .color(Color(white: 0.3)),
                        lineWidth: 1
                    )
                }
            }

            // Draw vertical lines (beat grid)
            let totalBeats = Int(size.width / engine.horizontalZoom) + 1
            for beat in 0...totalBeats {
                let x = CGFloat(beat) * engine.horizontalZoom
                let isBar = beat % 4 == 0
                let isBeat = beat % 1 == 0

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isBar ? Color(white: 0.4) : Color(white: 0.2)),
                    lineWidth: isBar ? 1 : 0.5
                )

                // Sub-divisions based on grid snap
                if engine.gridSnap != .off && engine.gridSnap != .whole {
                    let subDivisions = Int(1.0 / engine.gridSnap.beatsValue)
                    for sub in 1..<subDivisions {
                        let subX = x + CGFloat(sub) * engine.gridSnap.beatsValue * engine.horizontalZoom
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: subX, y: 0))
                                path.addLine(to: CGPoint(x: subX, y: size.height))
                            },
                            with: .color(Color(white: 0.15)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
        }
    }

    private var notesView: some View {
        ForEach(engine.notes) { note in
            NoteView(
                note: note,
                engine: engine,
                isSelected: engine.selectedNoteIds.contains(note.id)
            )
            .offset(
                x: engine.beatToX(note.startBeat),
                y: engine.pitchToY(note.pitch)
            )
        }
    }

    private var playheadView: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: 128 * engine.verticalZoom)
            .offset(x: engine.beatToX(engine.currentBeat) - 1)
    }

    private var loopRegionOverlay: some View {
        HStack(spacing: 0) {
            // Before loop (dimmed)
            if engine.loopStart > 0 {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: engine.beatToX(engine.loopStart))
            }

            // Loop region markers
            Rectangle()
                .fill(Color.yellow.opacity(0.1))
                .frame(width: engine.beatToX(engine.loopEnd - engine.loopStart))
                .overlay(
                    VStack {
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(height: 3)
                        Spacer()
                    }
                )
        }
        .allowsHitTesting(false)
    }

    private var gridGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleGridDrag(value: value)
            }
            .onEnded { value in
                handleGridDragEnd(value: value)
            }
    }

    private func handleGridDrag(value: DragGesture.Value) {
        let location = value.location
        let pitch = engine.yToPitch(location.y)
        let beat = engine.xToBeat(location.x)

        switch engine.editMode {
        case .select:
            // Update selection rectangle
            let startX = min(value.startLocation.x, location.x)
            let startY = min(value.startLocation.y, location.y)
            let width = abs(location.x - value.startLocation.x)
            let height = abs(location.y - value.startLocation.y)
            selectionRect = CGRect(x: startX, y: startY, width: width, height: height)

        case .draw:
            if !isDrawing {
                isDrawing = true
                engine.addNote(pitch: pitch, startBeat: beat)
            }

        case .erase:
            // Find and delete note under cursor
            if let note = findNote(at: location) {
                engine.deleteNote(note.id)
            }

        default:
            break
        }
    }

    private func handleGridDragEnd(value: DragGesture.Value) {
        switch engine.editMode {
        case .select:
            if let rect = selectionRect {
                let startPitch = engine.yToPitch(rect.minY)
                let endPitch = engine.yToPitch(rect.maxY)
                let startBeat = engine.xToBeat(rect.minX)
                let endBeat = engine.xToBeat(rect.maxX)
                engine.selectNotesInRect(startPitch: startPitch, endPitch: endPitch, startBeat: startBeat, endBeat: endBeat)
            }
            selectionRect = nil

        case .draw:
            isDrawing = false

        default:
            break
        }
    }

    private func findNote(at point: CGPoint) -> PianoRollEngine.MIDINote? {
        let pitch = engine.yToPitch(point.y)
        let beat = engine.xToBeat(point.x)

        return engine.notes.first { note in
            note.pitch == pitch &&
            note.startBeat <= beat &&
            note.startBeat + note.lengthBeats > beat
        }
    }

    // MARK: - Velocity Lane

    private var velocityLaneView: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                // Label
                Text("VEL")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: keyboardWidth)
                    .background(Color(white: 0.15))

                // Velocity bars
                GeometryReader { geometry in
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .bottom) {
                            // Background
                            Rectangle()
                                .fill(Color(white: 0.08))

                            // Velocity bars for each note
                            ForEach(engine.notes) { note in
                                VelocityBarView(
                                    note: note,
                                    engine: engine,
                                    laneHeight: velocityLaneHeight - 10
                                )
                                .offset(x: engine.beatToX(note.startBeat))
                            }
                        }
                        .frame(
                            width: max(geometry.size.width, engine.getClipLength() * engine.horizontalZoom),
                            height: velocityLaneHeight
                        )
                    }
                }
            }
        }
        .frame(height: velocityLaneHeight)
    }
}

// MARK: - Piano Key View

struct PianoKeyView: View {
    let pitch: Int
    let height: CGFloat
    let isPressed: Bool
    var onPress: () -> Void
    var onRelease: () -> Void

    private var isBlackKey: Bool {
        [1, 3, 6, 8, 10].contains(pitch % 12)
    }

    private var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (pitch / 12) - 1
        let noteIndex = pitch % 12
        if noteIndex == 0 { // Only show octave for C
            return "C\(octave)"
        }
        return noteNames[noteIndex]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(keyColor)

            // Note label
            if pitch % 12 == 0 { // C notes
                Text(noteName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isBlackKey ? .white : .black)
                    .padding(.leading, 4)
            }
        }
        .frame(height: height)
        .overlay(
            Rectangle()
                .stroke(Color(white: 0.3), lineWidth: 0.5)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }

    private var keyColor: Color {
        if isPressed {
            return .cyan
        }
        return isBlackKey ? Color(white: 0.2) : Color(white: 0.9)
    }
}

// MARK: - Note View

struct NoteView: View {
    let note: PianoRollEngine.MIDINote
    @ObservedObject var engine: PianoRollEngine
    let isSelected: Bool

    @State private var isDragging = false
    @State private var isResizing = false

    private var noteColor: Color {
        // Color based on velocity
        let intensity = Double(note.velocity) / 127.0
        return Color(
            hue: 0.55, // Cyan
            saturation: 0.8,
            brightness: 0.4 + intensity * 0.6
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Note body
            RoundedRectangle(cornerRadius: 2)
                .fill(noteColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isSelected ? Color.white : noteColor.opacity(0.8), lineWidth: isSelected ? 2 : 1)
                )

            // Note name (if wide enough)
            if note.lengthBeats * engine.horizontalZoom > 30 {
                Text(note.noteName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 3)
            }

            // Resize handle
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLength = note.lengthBeats + Double(value.translation.width) / engine.horizontalZoom
                                engine.resizeNote(note.id, newLength: newLength)
                            }
                    )
            }
        }
        .frame(
            width: max(4, note.lengthBeats * engine.horizontalZoom),
            height: engine.verticalZoom - 1
        )
        .opacity(note.isMuted ? 0.4 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        if !isSelected {
                            engine.selectNote(note.id)
                        }
                    }
                    let pitchDelta = -Int(value.translation.height / engine.verticalZoom)
                    let beatDelta = Double(value.translation.width) / engine.horizontalZoom
                    engine.moveSelectedNotes(pitchDelta: pitchDelta, beatDelta: beatDelta)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onTapGesture {
            if engine.editMode == .erase {
                engine.deleteNote(note.id)
            } else {
                engine.selectNote(note.id, addToSelection: false)
            }
        }
    }
}

// MARK: - Velocity Bar View

struct VelocityBarView: View {
    let note: PianoRollEngine.MIDINote
    @ObservedObject var engine: PianoRollEngine
    let laneHeight: CGFloat

    private var barHeight: CGFloat {
        CGFloat(note.velocity) / 127.0 * laneHeight
    }

    private var barColor: Color {
        let intensity = Double(note.velocity) / 127.0
        if intensity > 0.9 {
            return .red
        } else if intensity > 0.7 {
            return .orange
        } else if intensity > 0.5 {
            return .yellow
        }
        return .cyan
    }

    var body: some View {
        VStack {
            Spacer()

            Rectangle()
                .fill(barColor)
                .frame(
                    width: max(4, note.lengthBeats * engine.horizontalZoom - 2),
                    height: barHeight
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newVelocity = 127 - Int((value.location.y / laneHeight) * 127)
                            engine.setNoteVelocity(note.id, velocity: newVelocity)
                        }
                )
        }
        .frame(height: laneHeight)
    }
}

// MARK: - Preview

#Preview {
    PianoRollView()
        .preferredColorScheme(.dark)
        .frame(width: 1200, height: 800)
}
