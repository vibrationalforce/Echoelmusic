//
//  DAWScoreView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  SCORE VIEW - Professional Musical Notation Editor
//  Features: Note input, playback, export to MusicXML/PDF, MIDI sync
//

import SwiftUI

struct DAWScoreView: View {
    @Binding var selectedTrack: UUID?
    @StateObject private var scoreEngine = ScoreEngine()

    @State private var selectedClef: Clef = .treble
    @State private var selectedNoteValue: NoteValue = .quarter
    @State private var selectedTool: ScoreTool = .select
    @State private var zoomLevel: CGFloat = 1.0
    @State private var showInspector: Bool = true
    @State private var isPlaying: Bool = false

    var body: some View {
        HSplitView {
            // Main score area
            VStack(spacing: 0) {
                // Toolbar
                ScoreToolbar(
                    selectedTool: $selectedTool,
                    selectedNoteValue: $selectedNoteValue,
                    selectedClef: $selectedClef,
                    zoomLevel: $zoomLevel,
                    isPlaying: $isPlaying,
                    showInspector: $showInspector
                )

                Divider()

                // Score canvas
                ScrollView([.horizontal, .vertical]) {
                    ScoreCanvasView(
                        scoreEngine: scoreEngine,
                        selectedTool: selectedTool,
                        selectedNoteValue: selectedNoteValue,
                        zoomLevel: zoomLevel
                    )
                    .frame(minWidth: 2000, minHeight: 1200)
                }
                .background(Color.white)

                Divider()

                // Playback controls
                ScorePlaybackBar(
                    scoreEngine: scoreEngine,
                    isPlaying: $isPlaying
                )
            }

            // Inspector panel
            if showInspector {
                ScoreInspectorView(
                    scoreEngine: scoreEngine,
                    selectedClef: $selectedClef
                )
                .frame(width: 280)
            }
        }
    }
}

// MARK: - Score Engine

class ScoreEngine: ObservableObject {
    @Published var measures: [Measure] = []
    @Published var tempo: Int = 120
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var keySignature: KeySignature = .cMajor
    @Published var currentPosition: Int = 0
    @Published var selectedNotes: Set<UUID> = []

    init() {
        // Create 16 empty measures
        measures = (0..<16).map { index in
            Measure(id: UUID(), number: index + 1, notes: [], clef: .treble)
        }
    }

    func addNote(_ note: Note, to measureIndex: Int) {
        guard measureIndex < measures.count else { return }
        measures[measureIndex].notes.append(note)
    }

    func removeNote(_ noteId: UUID, from measureIndex: Int) {
        guard measureIndex < measures.count else { return }
        measures[measureIndex].notes.removeAll { $0.id == noteId }
    }

    func play() {
        // Playback implementation
    }

    func stop() {
        currentPosition = 0
    }
}

// MARK: - Models

struct Measure: Identifiable {
    let id: UUID
    var number: Int
    var notes: [Note]
    var clef: Clef
}

struct Note: Identifiable {
    let id: UUID
    var pitch: Pitch
    var value: NoteValue
    var beat: Double
    var accidental: Accidental?
    var articulation: Articulation?
    var dynamic: Dynamic?
    var tie: TieDirection?
}

struct Pitch {
    var note: NoteName
    var octave: Int

    var midiNumber: Int {
        let baseValues: [NoteName: Int] = [
            .c: 0, .d: 2, .e: 4, .f: 5, .g: 7, .a: 9, .b: 11
        ]
        return (octave + 1) * 12 + (baseValues[note] ?? 0)
    }

    var staffPosition: Int {
        // Position on staff (0 = middle C for treble clef)
        let noteValues: [NoteName: Int] = [
            .c: 0, .d: 1, .e: 2, .f: 3, .g: 4, .a: 5, .b: 6
        ]
        return (noteValues[note] ?? 0) + (octave - 4) * 7
    }
}

enum NoteName: String, CaseIterable {
    case c = "C", d = "D", e = "E", f = "F", g = "G", a = "A", b = "B"
}

enum NoteValue: String, CaseIterable {
    case whole = "Whole"
    case half = "Half"
    case quarter = "Quarter"
    case eighth = "Eighth"
    case sixteenth = "16th"
    case thirtySecond = "32nd"

    var beats: Double {
        switch self {
        case .whole: return 4.0
        case .half: return 2.0
        case .quarter: return 1.0
        case .eighth: return 0.5
        case .sixteenth: return 0.25
        case .thirtySecond: return 0.125
        }
    }

    var symbol: String {
        switch self {
        case .whole: return "𝅝"
        case .half: return "𝅗𝅥"
        case .quarter: return "♩"
        case .eighth: return "♪"
        case .sixteenth: return "𝅘𝅥𝅯"
        case .thirtySecond: return "𝅘𝅥𝅰"
        }
    }
}

enum Clef: String, CaseIterable {
    case treble = "Treble"
    case bass = "Bass"
    case alto = "Alto"
    case tenor = "Tenor"

    var symbol: String {
        switch self {
        case .treble: return "𝄞"
        case .bass: return "𝄢"
        case .alto: return "𝄡"
        case .tenor: return "𝄡"
        }
    }
}

enum Accidental: String {
    case sharp = "♯"
    case flat = "♭"
    case natural = "♮"
    case doubleSharp = "𝄪"
    case doubleFlat = "𝄫"
}

enum Articulation: String {
    case staccato, accent, tenuto, marcato, fermata
}

enum Dynamic: String {
    case ppp, pp, p, mp, mf, f, ff, fff
}

enum TieDirection {
    case start, end
}

struct TimeSignature: Equatable {
    var numerator: Int
    var denominator: Int

    static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    static let sixEight = TimeSignature(numerator: 6, denominator: 8)
    static let twoFour = TimeSignature(numerator: 2, denominator: 4)

    var display: String { "\(numerator)/\(denominator)" }
}

enum KeySignature: String, CaseIterable {
    case cMajor = "C Major"
    case gMajor = "G Major"
    case dMajor = "D Major"
    case aMajor = "A Major"
    case eMajor = "E Major"
    case bMajor = "B Major"
    case fSharpMajor = "F# Major"
    case fMajor = "F Major"
    case bFlatMajor = "Bb Major"
    case eFlatMajor = "Eb Major"
    case aFlatMajor = "Ab Major"

    var sharps: Int {
        switch self {
        case .cMajor: return 0
        case .gMajor: return 1
        case .dMajor: return 2
        case .aMajor: return 3
        case .eMajor: return 4
        case .bMajor: return 5
        case .fSharpMajor: return 6
        default: return 0
        }
    }

    var flats: Int {
        switch self {
        case .fMajor: return 1
        case .bFlatMajor: return 2
        case .eFlatMajor: return 3
        case .aFlatMajor: return 4
        default: return 0
        }
    }
}

enum ScoreTool: String, CaseIterable {
    case select = "Select"
    case note = "Note"
    case rest = "Rest"
    case eraser = "Eraser"
    case slur = "Slur"
    case dynamic = "Dynamic"
    case text = "Text"

    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .note: return "music.note"
        case .rest: return "pause"
        case .eraser: return "eraser"
        case .slur: return "curlybraces"
        case .dynamic: return "speaker.wave.2"
        case .text: return "textformat"
        }
    }
}

// MARK: - Score Toolbar

struct ScoreToolbar: View {
    @Binding var selectedTool: ScoreTool
    @Binding var selectedNoteValue: NoteValue
    @Binding var selectedClef: Clef
    @Binding var zoomLevel: CGFloat
    @Binding var isPlaying: Bool
    @Binding var showInspector: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Tool selection
            HStack(spacing: 4) {
                ForEach(ScoreTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .frame(width: 32, height: 32)
                            .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(tool.rawValue)
                }
            }

            Divider()
                .frame(height: 30)

            // Note value selection
            HStack(spacing: 4) {
                ForEach(NoteValue.allCases, id: \.self) { value in
                    Button {
                        selectedNoteValue = value
                    } label: {
                        Text(value.symbol)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .background(selectedNoteValue == value ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(value.rawValue)
                }
            }

            Divider()
                .frame(height: 30)

            // Clef selection
            Picker("Clef", selection: $selectedClef) {
                ForEach(Clef.allCases, id: \.self) { clef in
                    Text(clef.symbol + " " + clef.rawValue).tag(clef)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button { zoomLevel = max(0.5, zoomLevel - 0.1) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                Text("\(Int(zoomLevel * 100))%")
                    .frame(width: 45)
                    .font(.caption)
                Button { zoomLevel = min(2.0, zoomLevel + 0.1) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }

            Divider()
                .frame(height: 30)

            // View toggles
            Toggle("Inspector", isOn: $showInspector)
                .toggleStyle(.button)

            // Export menu
            Menu {
                Button("Export as PDF") { }
                Button("Export as MusicXML") { }
                Button("Export as MIDI") { }
                Divider()
                Button("Print...") { }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Score Canvas

struct ScoreCanvasView: View {
    @ObservedObject var scoreEngine: ScoreEngine
    let selectedTool: ScoreTool
    let selectedNoteValue: NoteValue
    let zoomLevel: CGFloat

    let staffSpacing: CGFloat = 10
    let measureWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 60) {
            // Title area
            VStack(alignment: .center, spacing: 8) {
                Text("Untitled Score")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Composer: ")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)

            // Score systems (groups of measures)
            ForEach(0..<4, id: \.self) { systemIndex in
                ScoreSystemView(
                    measures: Array(scoreEngine.measures.dropFirst(systemIndex * 4).prefix(4)),
                    scoreEngine: scoreEngine,
                    selectedTool: selectedTool,
                    selectedNoteValue: selectedNoteValue,
                    staffSpacing: staffSpacing,
                    measureWidth: measureWidth,
                    zoomLevel: zoomLevel
                )
            }

            Spacer()
        }
        .padding(40)
        .scaleEffect(zoomLevel)
    }
}

struct ScoreSystemView: View {
    let measures: [Measure]
    @ObservedObject var scoreEngine: ScoreEngine
    let selectedTool: ScoreTool
    let selectedNoteValue: NoteValue
    let staffSpacing: CGFloat
    let measureWidth: CGFloat
    let zoomLevel: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Clef and key signature
            VStack(spacing: 0) {
                // Treble staff
                StaffWithClefView(clef: .treble, keySignature: scoreEngine.keySignature, staffSpacing: staffSpacing)

                Spacer()
                    .frame(height: 30)

                // Bass staff
                StaffWithClefView(clef: .bass, keySignature: scoreEngine.keySignature, staffSpacing: staffSpacing)
            }
            .frame(width: 80)

            // Measures
            ForEach(measures) { measure in
                MeasureView(
                    measure: measure,
                    scoreEngine: scoreEngine,
                    selectedTool: selectedTool,
                    selectedNoteValue: selectedNoteValue,
                    staffSpacing: staffSpacing,
                    measureWidth: measureWidth
                )
            }
        }
    }
}

struct StaffWithClefView: View {
    let clef: Clef
    let keySignature: KeySignature
    let staffSpacing: CGFloat

    var body: some View {
        Canvas { context, size in
            // Draw 5 staff lines
            for i in 0..<5 {
                let y = CGFloat(i) * staffSpacing + 20
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.black),
                    lineWidth: 1
                )
            }

            // Draw clef
            context.draw(
                Text(clef.symbol)
                    .font(.system(size: clef == .treble ? 50 : 40)),
                at: CGPoint(x: 25, y: staffSpacing * 2 + 20)
            )

            // Draw key signature sharps/flats
            if keySignature.sharps > 0 {
                for i in 0..<keySignature.sharps {
                    context.draw(
                        Text("♯").font(.system(size: 20)),
                        at: CGPoint(x: 55 + CGFloat(i) * 12, y: staffSpacing * CGFloat(i % 2) + 25)
                    )
                }
            }
        }
        .frame(width: 80, height: staffSpacing * 4 + 40)
    }
}

struct MeasureView: View {
    let measure: Measure
    @ObservedObject var scoreEngine: ScoreEngine
    let selectedTool: ScoreTool
    let selectedNoteValue: NoteValue
    let staffSpacing: CGFloat
    let measureWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let staffHeight = staffSpacing * 4 + 40

            // Draw treble staff lines
            for i in 0..<5 {
                let y = CGFloat(i) * staffSpacing + 20
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.black),
                    lineWidth: 1
                )
            }

            // Draw bass staff lines
            let bassOffset = staffHeight + 30
            for i in 0..<5 {
                let y = CGFloat(i) * staffSpacing + bassOffset
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.black),
                    lineWidth: 1
                )
            }

            // Draw barline at end
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: size.width - 1, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 1, y: bassOffset + staffSpacing * 4))
                },
                with: .color(.black),
                lineWidth: 1
            )

            // Draw measure number
            context.draw(
                Text("\(measure.number)")
                    .font(.caption)
                    .foregroundColor(.secondary),
                at: CGPoint(x: 10, y: 10)
            )

            // Draw notes
            for note in measure.notes {
                let x = 20 + CGFloat(note.beat) * 40
                let y = calculateNoteY(pitch: note.pitch, staffSpacing: staffSpacing)

                // Note head
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 6, y: y - 4, width: 12, height: 8)),
                    with: .color(.black)
                )

                // Stem (for quarter notes and shorter)
                if note.value != .whole && note.value != .half {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x + 5, y: y))
                            path.addLine(to: CGPoint(x: x + 5, y: y - 30))
                        },
                        with: .color(.black),
                        lineWidth: 1
                    )
                }

                // Accidental
                if let accidental = note.accidental {
                    context.draw(
                        Text(accidental.rawValue)
                            .font(.system(size: 14)),
                        at: CGPoint(x: x - 15, y: y)
                    )
                }
            }
        }
        .frame(width: measureWidth, height: staffSpacing * 4 + 40 + 30 + staffSpacing * 4 + 20)
        .contentShape(Rectangle())
        .onTapGesture { location in
            if selectedTool == .note {
                addNoteAt(location: location)
            }
        }
    }

    private func calculateNoteY(pitch: Pitch, staffSpacing: CGFloat) -> CGFloat {
        // Middle C is at position 0
        let position = pitch.staffPosition
        // Each position is half a staff spacing
        return 60 - CGFloat(position) * (staffSpacing / 2)
    }

    private func addNoteAt(location: CGPoint) {
        // Calculate beat from x position
        let beat = Double((location.x - 20) / 40)

        // Calculate pitch from y position
        let position = Int((60 - location.y) / (staffSpacing / 2))
        let noteIndex = ((position % 7) + 7) % 7
        let octave = 4 + position / 7
        let noteNames: [NoteName] = [.c, .d, .e, .f, .g, .a, .b]

        let note = Note(
            id: UUID(),
            pitch: Pitch(note: noteNames[noteIndex], octave: octave),
            value: selectedNoteValue,
            beat: beat,
            accidental: nil,
            articulation: nil,
            dynamic: nil,
            tie: nil
        )

        if let measureIndex = scoreEngine.measures.firstIndex(where: { $0.id == measure.id }) {
            scoreEngine.addNote(note, to: measureIndex)
        }
    }
}

// MARK: - Playback Bar

struct ScorePlaybackBar: View {
    @ObservedObject var scoreEngine: ScoreEngine
    @Binding var isPlaying: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Transport controls
            Button { scoreEngine.stop(); isPlaying = false } label: {
                Image(systemName: "stop.fill")
            }

            Button {
                isPlaying.toggle()
                if isPlaying { scoreEngine.play() } else { scoreEngine.stop() }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }

            Divider()
                .frame(height: 20)

            // Tempo
            HStack {
                Image(systemName: "metronome")
                Text("♩ =")
                TextField("", value: $scoreEngine.tempo, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                Text("BPM")
            }

            Divider()
                .frame(height: 20)

            // Time signature
            Text(scoreEngine.timeSignature.display)
                .font(.title3)
                .fontWeight(.medium)

            Divider()
                .frame(height: 20)

            // Key signature
            Text(scoreEngine.keySignature.rawValue)
                .font(.subheadline)

            Spacer()

            // Position
            Text("Measure: \(scoreEngine.currentPosition + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Inspector View

struct ScoreInspectorView: View {
    @ObservedObject var scoreEngine: ScoreEngine
    @Binding var selectedClef: Clef

    var body: some View {
        Form {
            Section("Score Settings") {
                Picker("Key Signature", selection: $scoreEngine.keySignature) {
                    ForEach(KeySignature.allCases, id: \.self) { key in
                        Text(key.rawValue).tag(key)
                    }
                }

                HStack {
                    Text("Time Signature")
                    Spacer()
                    Picker("", selection: $scoreEngine.timeSignature) {
                        Text("4/4").tag(TimeSignature.fourFour)
                        Text("3/4").tag(TimeSignature.threeFour)
                        Text("6/8").tag(TimeSignature.sixEight)
                        Text("2/4").tag(TimeSignature.twoFour)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }

                Stepper("Tempo: \(scoreEngine.tempo) BPM", value: $scoreEngine.tempo, in: 40...240)
            }

            Section("Document") {
                LabeledContent("Measures", value: "\(scoreEngine.measures.count)")
                LabeledContent("Notes", value: "\(scoreEngine.measures.flatMap { $0.notes }.count)")
            }

            Section("Selection") {
                if scoreEngine.selectedNotes.isEmpty {
                    Text("No notes selected")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(scoreEngine.selectedNotes.count) notes selected")
                    Button("Delete Selected", role: .destructive) {
                        // Delete action
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#if DEBUG
struct DAWScoreView_Previews: PreviewProvider {
    static var previews: some View {
        DAWScoreView(selectedTrack: .constant(UUID()))
            .frame(width: 1400, height: 900)
    }
}
#endif
