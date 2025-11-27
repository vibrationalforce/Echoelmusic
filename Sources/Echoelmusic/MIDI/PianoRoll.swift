//
//  PianoRoll.swift
//  Echoelmusic
//
//  Professional MIDI Piano Roll Editor
//  Logic Pro X / Cubase style MIDI note editing
//

import SwiftUI

// MARK: - MIDI Note Model

struct MIDINoteEvent: Identifiable, Codable {
    let id: UUID
    var note: UInt8  // 0-127
    var velocity: UInt8  // 0-127
    var channel: UInt8  // 0-15
    var startBeat: Double  // Musical time in beats
    var duration: Double  // In beats
    var isSelected: Bool = false

    init(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0, startBeat: Double, duration: Double) {
        self.id = UUID()
        self.note = note
        self.velocity = velocity
        self.channel = channel
        self.startBeat = startBeat
        self.duration = duration
    }

    var endBeat: Double {
        startBeat + duration
    }

    var noteName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let nameIndex = Int(note) % 12
        return "\(names[nameIndex])\(octave)"
    }
}

// MARK: - MIDI Clip Model

@MainActor
class MIDIClip: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var notes: [MIDINoteEvent] = []
    @Published var lengthInBeats: Double = 16.0  // 4 bars at 4/4
    @Published var timeSignatureNumerator: Int = 4
    @Published var timeSignatureDenominator: Int = 4

    init(name: String = "MIDI Clip", lengthInBeats: Double = 16.0) {
        self.id = UUID()
        self.name = name
        self.lengthInBeats = lengthInBeats
    }

    func addNote(_ note: MIDINoteEvent) {
        notes.append(note)
        notes.sort { $0.startBeat < $1.startBeat }
    }

    func removeNote(_ noteID: UUID) {
        notes.removeAll { $0.id == noteID }
    }

    func removeSelectedNotes() {
        notes.removeAll { $0.isSelected }
    }

    func selectNote(_ noteID: UUID, addToSelection: Bool = false) {
        if !addToSelection {
            for i in notes.indices {
                notes[i].isSelected = false
            }
        }

        if let index = notes.firstIndex(where: { $0.id == noteID }) {
            notes[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for i in notes.indices {
            notes[i].isSelected = true
        }
    }

    func deselectAll() {
        for i in notes.indices {
            notes[i].isSelected = false
        }
    }

    func quantize(to grid: QuantizationGrid) {
        for i in notes.indices {
            notes[i].startBeat = grid.quantize(notes[i].startBeat)
            notes[i].duration = grid.quantize(notes[i].duration)
        }
    }

    func transposeSelected(by semitones: Int) {
        for i in notes.indices where notes[i].isSelected {
            let newNote = Int(notes[i].note) + semitones
            notes[i].note = UInt8(max(0, min(127, newNote)))
        }
    }

    func scaleVelocitySelected(by factor: Float) {
        for i in notes.indices where notes[i].isSelected {
            let newVelocity = Float(notes[i].velocity) * factor
            notes[i].velocity = UInt8(max(1, min(127, Int(newVelocity))))
        }
    }
}

// MARK: - Quantization Grid

enum QuantizationGrid: String, CaseIterable {
    case bar = "Bar"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"
    case triplet = "1/8T"
    case dotted = "1/8."

    var beatsPerDivision: Double {
        switch self {
        case .bar: return 4.0
        case .half: return 2.0
        case .quarter: return 1.0
        case .eighth: return 0.5
        case .sixteenth: return 0.25
        case .thirtySecond: return 0.125
        case .triplet: return 1.0 / 3.0
        case .dotted: return 0.75
        }
    }

    func quantize(_ beat: Double) -> Double {
        let division = beatsPerDivision
        return round(beat / division) * division
    }
}

// MARK: - Piano Roll View

struct PianoRollView: View {
    @ObservedObject var clip: MIDIClip
    @State private var zoom: CGFloat = 1.0  // Horizontal zoom
    @State private var verticalZoom: CGFloat = 20.0  // Pixels per note
    @State private var selectedQuantization: QuantizationGrid = .sixteenth
    @State private var isDrawingMode: Bool = false
    @State private var draggedNote: UUID?
    @State private var resizingNote: UUID?
    @State private var scrollOffset: CGPoint = .zero

    private let pianoKeyWidth: CGFloat = 60
    private let beatWidth: CGFloat = 100  // Pixels per beat (before zoom)
    private let minNote: UInt8 = 0
    private let maxNote: UInt8 = 127

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Piano Keys (left sidebar)
                pianoKeysView

                // Main Grid Area
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        // Grid background
                        gridBackground

                        // MIDI Notes
                        ForEach(clip.notes) { note in
                            noteView(for: note)
                        }
                    }
                    .frame(width: beatWidth * zoom * CGFloat(clip.lengthInBeats),
                           height: CGFloat(maxNote - minNote) * verticalZoom)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                pianoRollToolbar
            }
        }
    }

    // MARK: - Piano Keys Sidebar

    var pianoKeysView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach((minNote...maxNote).reversed(), id: \.self) { noteNumber in
                    pianoKey(for: noteNumber)
                }
            }
        }
        .frame(width: pianoKeyWidth)
        .background(Color(white: 0.15))
    }

    func pianoKey(for noteNumber: UInt8) -> some View {
        let isBlackKey = [1, 3, 6, 8, 10].contains(Int(noteNumber) % 12)

        return HStack {
            Text(MIDINoteEvent(note: noteNumber, startBeat: 0, duration: 1).noteName)
                .font(.caption2)
                .foregroundColor(isBlackKey ? .white : .black)
                .frame(maxWidth: .infinity)
        }
        .frame(height: verticalZoom)
        .background(isBlackKey ? Color(white: 0.3) : Color(white: 0.9))
        .overlay(
            Rectangle()
                .stroke(Color(white: 0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Grid Background

    var gridBackground: some View {
        ZStack {
            // Horizontal lines (note separators)
            ForEach(minNote...maxNote, id: \.self) { noteNumber in
                let isBlackKey = [1, 3, 6, 8, 10].contains(Int(noteNumber) % 12)
                let y = CGFloat(maxNote - noteNumber) * verticalZoom

                Rectangle()
                    .fill(isBlackKey ? Color(white: 0.15) : Color(white: 0.2))
                    .frame(height: verticalZoom)
                    .offset(y: y)
            }

            // Vertical lines (beat grid)
            ForEach(0..<Int(clip.lengthInBeats * 4), id: \.self) { subdivision in
                let beat = Double(subdivision) * 0.25
                let x = CGFloat(beat) * beatWidth * zoom
                let isMajorGrid = subdivision % 4 == 0

                Rectangle()
                    .fill(isMajorGrid ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 1)
                    .offset(x: x)
            }
        }
        .onTapGesture { location in
            if isDrawingMode {
                addNoteAt(location: location)
            }
        }
    }

    // MARK: - Note View

    func noteView(for note: MIDINoteEvent) -> some View {
        let x = CGFloat(note.startBeat) * beatWidth * zoom
        let y = CGFloat(maxNote - note.note) * verticalZoom
        let width = CGFloat(note.duration) * beatWidth * zoom
        let height = verticalZoom

        let velocityAlpha = Double(note.velocity) / 127.0

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(velocityAlpha),
                        Color.blue.opacity(velocityAlpha)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height - 1)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(note.isSelected ? Color.yellow : Color.white.opacity(0.5), lineWidth: note.isSelected ? 2 : 1)
            )
            .cornerRadius(4)
            .offset(x: x, y: y)
            .onTapGesture {
                clip.selectNote(note.id, addToSelection: false)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        moveNote(note.id, by: value.translation)
                    }
            )
    }

    // MARK: - Toolbar

    var pianoRollToolbar: some View {
        Group {
            // Tool Selection
            Button {
                isDrawingMode.toggle()
            } label: {
                Image(systemName: isDrawingMode ? "pencil.circle.fill" : "arrow.up.left.and.arrow.down.right.circle")
                Text(isDrawingMode ? "Draw" : "Select")
            }

            Divider()

            // Quantization
            Picker("Quantize", selection: $selectedQuantization) {
                ForEach(QuantizationGrid.allCases, id: \.self) { grid in
                    Text(grid.rawValue).tag(grid)
                }
            }
            .pickerStyle(.menu)

            Button("Apply Quantize") {
                clip.quantize(to: selectedQuantization)
            }

            Divider()

            // Edit Tools
            Button("Delete") {
                clip.removeSelectedNotes()
            }
            .disabled(clip.notes.allSatisfy { !$0.isSelected })

            Button("Select All") {
                clip.selectAll()
            }

            Divider()

            // Zoom Controls
            Button {
                zoom = max(0.5, zoom - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }

            Text(String(format: "%.1fx", zoom))
                .frame(width: 40)

            Button {
                zoom = min(4.0, zoom + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }

            Divider()

            // Transpose
            Button {
                clip.transposeSelected(by: 12)
            } label: {
                Image(systemName: "arrow.up")
                Text("+12")
            }
            .disabled(clip.notes.allSatisfy { !$0.isSelected })

            Button {
                clip.transposeSelected(by: -12)
            } label: {
                Image(systemName: "arrow.down")
                Text("-12")
            }
            .disabled(clip.notes.allSatisfy { !$0.isSelected })
        }
    }

    // MARK: - Interaction Logic

    func addNoteAt(location: CGPoint) {
        let beat = Double(location.x / (beatWidth * zoom))
        let noteNumber = maxNote - UInt8(location.y / verticalZoom)

        let quantizedBeat = selectedQuantization.quantize(beat)
        let duration = selectedQuantization.beatsPerDivision

        let newNote = MIDINoteEvent(
            note: noteNumber,
            velocity: 100,
            startBeat: quantizedBeat,
            duration: duration
        )

        clip.addNote(newNote)
    }

    func moveNote(_ noteID: UUID, by translation: CGSize) {
        guard let index = clip.notes.firstIndex(where: { $0.id == noteID }) else { return }

        let beatDelta = Double(translation.width / (beatWidth * zoom))
        let noteDelta = -Int(translation.height / verticalZoom)

        var note = clip.notes[index]
        note.startBeat = max(0, note.startBeat + beatDelta)
        note.note = UInt8(max(0, min(127, Int(note.note) + noteDelta)))

        clip.notes[index] = note
    }
}

// MARK: - Step Sequencer (for drums)

@MainActor
class StepSequencerPattern: ObservableObject {
    struct Step {
        var isActive: Bool = false
        var velocity: UInt8 = 100
        var probability: Float = 1.0  // 0-1 (for generative patterns)
    }

    @Published var steps: [[Step]]  // [drum][step]
    @Published var currentStep: Int = 0
    @Published var isPlaying: Bool = false

    let drumNames: [String]
    let numSteps: Int

    init(drumNames: [String] = ["Kick", "Snare", "Hi-Hat", "Clap", "Tom"], numSteps: Int = 16) {
        self.drumNames = drumNames
        self.numSteps = numSteps
        self.steps = Array(repeating: Array(repeating: Step(), count: numSteps), count: drumNames.count)
    }

    func toggleStep(drum: Int, step: Int) {
        steps[drum][step].isActive.toggle()
    }

    func clearPattern() {
        steps = Array(repeating: Array(repeating: Step(), count: numSteps), count: drumNames.count)
    }

    func randomize() {
        for drumIndex in steps.indices {
            for stepIndex in steps[drumIndex].indices {
                steps[drumIndex][stepIndex].isActive = Bool.random()
            }
        }
    }
}

struct StepSequencerView: View {
    @ObservedObject var pattern: StepSequencerPattern

    var body: some View {
        VStack(spacing: 8) {
            Text("STEP SEQUENCER")
                .font(.headline)
                .foregroundColor(.cyan)

            // Grid
            VStack(spacing: 2) {
                ForEach(pattern.drumNames.indices, id: \.self) { drumIndex in
                    HStack(spacing: 0) {
                        // Drum name
                        Text(pattern.drumNames[drumIndex])
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                            .foregroundColor(.white)

                        // Steps
                        ForEach(0..<pattern.numSteps, id: \.self) { stepIndex in
                            stepButton(drum: drumIndex, step: stepIndex)
                        }
                    }
                }
            }

            // Controls
            HStack {
                Button(pattern.isPlaying ? "Stop" : "Play") {
                    pattern.isPlaying.toggle()
                }
                .buttonStyle(.borderedProminent)

                Button("Clear") {
                    pattern.clearPattern()
                }

                Button("Random") {
                    pattern.randomize()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }

    func stepButton(drum: Int, step: Int) -> some View {
        let isActive = pattern.steps[drum][step].isActive
        let isCurrent = step == pattern.currentStep && pattern.isPlaying
        let isDownbeat = step % 4 == 0

        return Button {
            pattern.toggleStep(drum: drum, step: step)
        } label: {
            Rectangle()
                .fill(isActive ? Color.cyan : Color(white: 0.3))
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isCurrent ? Color.yellow : (isDownbeat ? Color.white.opacity(0.5) : Color.clear),
                            lineWidth: isCurrent ? 3 : 1
                        )
                )
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Piano Roll") {
    let clip = MIDIClip(name: "Test Clip")

    // Add some test notes
    clip.addNote(MIDINoteEvent(note: 60, startBeat: 0, duration: 1))
    clip.addNote(MIDINoteEvent(note: 64, startBeat: 1, duration: 1))
    clip.addNote(MIDINoteEvent(note: 67, startBeat: 2, duration: 1))

    return PianoRollView(clip: clip)
}

#Preview("Step Sequencer") {
    StepSequencerView(pattern: StepSequencerPattern())
}
