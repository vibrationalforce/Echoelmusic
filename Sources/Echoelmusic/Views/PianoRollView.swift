#if canImport(SwiftUI)
import SwiftUI

// MARK: - Piano Roll MIDI Editor
/// Professional piano roll editor (Logic Pro / FL Studio / Ableton style)
/// Features: note grid, velocity lane, snap-to-grid, draw/select/erase tools,
/// octave keyboard sidebar, zoom, scroll, multi-note selection

// MARK: - Piano Roll ViewModel

@MainActor
@Observable
final class PianoRollViewModel {

    // MARK: - Constants

    /// MIDI note range displayed (C1 to C7 = notes 24-96)
    static let lowestNote: UInt8 = 24
    static let highestNote: UInt8 = 96
    static let noteRange: Int = Int(highestNote - lowestNote) + 1

    /// Note names for keyboard labels
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - State

    var notes: [MIDINoteEvent] = []
    var selectedNoteIDs: Set<UUID> = []
    var tool: EditTool = .draw
    var snapDivision: SnapDivision = .quarter
    var zoom: CGFloat = 1.0
    var scrollOffset: CGPoint = .zero
    var totalBeats: Double = 16.0
    var showVelocityLane: Bool = true
    var clipName: String = "MIDI Clip"

    // MARK: - Edit Tool

    enum EditTool: String, CaseIterable {
        case draw = "Draw"
        case select = "Select"
        case erase = "Erase"

        var icon: String {
            switch self {
            case .draw: return "pencil"
            case .select: return "cursorarrow"
            case .erase: return "eraser"
            }
        }
    }

    // MARK: - Snap Division

    enum SnapDivision: String, CaseIterable {
        case whole = "1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtysecond = "1/32"
        case triplet = "1/4T"
        case off = "Off"

        /// Beat value for this division
        var beatValue: Double {
            switch self {
            case .whole: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtysecond: return 0.125
            case .triplet: return 1.0 / 3.0
            case .off: return 0.0
            }
        }
    }

    // MARK: - Note Helpers

    static func noteName(for midiNote: UInt8) -> String {
        let name = noteNames[Int(midiNote) % 12]
        let octave = Int(midiNote) / 12 - 1
        return "\(name)\(octave)"
    }

    static func isBlackKey(_ midiNote: UInt8) -> Bool {
        let pc = Int(midiNote) % 12
        return [1, 3, 6, 8, 10].contains(pc)
    }

    static func isC(_ midiNote: UInt8) -> Bool {
        Int(midiNote) % 12 == 0
    }

    /// Snap a beat position to the current grid
    func snapBeat(_ beat: Double) -> Double {
        guard snapDivision != .off, snapDivision.beatValue > 0 else { return beat }
        let grid = snapDivision.beatValue
        return (beat / grid).rounded() * grid
    }

    // MARK: - Note Operations

    func addNote(note: UInt8, startBeat: Double, duration: Double = 0, velocity: UInt8 = 100) {
        let dur = duration > 0 ? duration : snapDivision.beatValue > 0 ? snapDivision.beatValue : 0.25
        let snappedStart = snapBeat(startBeat)
        let event = MIDINoteEvent(
            note: note,
            velocity: velocity,
            startBeat: Swift.max(0, snappedStart),
            duration: dur
        )
        notes.append(event)
        selectedNoteIDs = [event.id]
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        selectedNoteIDs.remove(id)
    }

    func deleteSelected() {
        notes.removeAll { selectedNoteIDs.contains($0.id) }
        selectedNoteIDs.removeAll()
    }

    func selectAll() {
        selectedNoteIDs = Set(notes.map(\.id))
    }

    func setVelocity(_ velocity: UInt8, for noteID: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].velocity = velocity
    }

    func moveNote(id: UUID, deltaBeat: Double, deltaPitch: Int) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let newStart = snapBeat(notes[idx].startBeat + deltaBeat)
        let newNote = Int(notes[idx].note) + deltaPitch
        guard newNote >= Int(Self.lowestNote), newNote <= Int(Self.highestNote) else { return }
        notes[idx].startBeat = Swift.max(0, newStart)
        notes[idx].note = UInt8(newNote)
    }

    func resizeNote(id: UUID, newDuration: Double) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let minDur = snapDivision.beatValue > 0 ? snapDivision.beatValue : 0.0625
        notes[idx].duration = Swift.max(minDur, newDuration)
    }

    /// Load demo notes for preview
    func loadDemoNotes() {
        guard notes.isEmpty else { return }
        // C major arpeggio pattern
        let pattern: [(UInt8, Double, Double)] = [
            (60, 0, 1), (64, 1, 1), (67, 2, 1), (72, 3, 0.5),
            (71, 3.5, 0.5), (67, 4, 1), (64, 5, 0.5), (65, 5.5, 0.5),
            (67, 6, 2), (60, 8, 1), (62, 9, 0.5), (64, 9.5, 0.5),
            (65, 10, 1), (67, 11, 1), (72, 12, 2), (71, 14, 1), (69, 15, 1),
        ]
        for (note, start, dur) in pattern {
            let vel = UInt8.random(in: 70...120)
            notes.append(MIDINoteEvent(note: note, velocity: vel, startBeat: start, duration: dur))
        }
    }
}

// MARK: - Piano Roll View

struct PianoRollView: View {
    @Environment(\.isEmbeddedInPanel) private var isEmbeddedInPanel
    @State private var viewModel = PianoRollViewModel()

    /// Row height per MIDI note
    private let noteRowHeight: CGFloat = 14
    /// Keyboard sidebar width
    private let keyboardWidth: CGFloat = 48
    /// Velocity lane height
    private let velocityLaneHeight: CGFloat = 80
    /// Header height
    private let headerBarHeight: CGFloat = 28

    /// Pixels per beat at zoom 1.0
    private let basePixelsPerBeat: CGFloat = 60

    private var pixelsPerBeat: CGFloat {
        basePixelsPerBeat * viewModel.zoom
    }

    private var gridHeight: CGFloat {
        CGFloat(PianoRollViewModel.noteRange) * noteRowHeight
    }

    private var gridWidth: CGFloat {
        CGFloat(viewModel.totalBeats) * pixelsPerBeat
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbeddedInPanel {
                toolBar
            } else {
                compactToolBar
            }

            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Beat ruler + grid area
                    HStack(spacing: 0) {
                        // Keyboard sidebar
                        keyboardSidebar
                            .frame(width: keyboardWidth)

                        // Main grid area (ruler on top, notes below)
                        VStack(spacing: 0) {
                            beatRuler(width: geo.size.width - keyboardWidth)
                                .frame(height: headerBarHeight)

                            noteGrid(size: CGSize(
                                width: geo.size.width - keyboardWidth,
                                height: geo.size.height
                                    - headerBarHeight
                                    - (viewModel.showVelocityLane ? velocityLaneHeight : 0)
                            ))
                        }
                    }

                    // Velocity lane
                    if viewModel.showVelocityLane {
                        HStack(spacing: 0) {
                            velocityLabel
                                .frame(width: keyboardWidth, height: velocityLaneHeight)
                            velocityLane(width: geo.size.width - keyboardWidth)
                                .frame(height: velocityLaneHeight)
                        }
                    }
                }
            }
        }
        .background(EchoelBrand.bgDeep)
        .onAppear {
            viewModel.loadDemoNotes()
        }
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: EchoelSpacing.sm) {
            // Clip name
            Text(viewModel.clipName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            toolButtons
            snapPicker
            zoomControl
            velocityToggle
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.xs)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    private var compactToolBar: some View {
        HStack(spacing: EchoelSpacing.xs) {
            toolButtons
            Spacer()
            snapPicker
            zoomControl
            velocityToggle
        }
        .padding(.horizontal, EchoelSpacing.sm)
        .padding(.vertical, EchoelSpacing.xs)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    private var toolButtons: some View {
        HStack(spacing: 2) {
            ForEach(PianoRollViewModel.EditTool.allCases, id: \.self) { tool in
                Button {
                    viewModel.tool = tool
                    HapticHelper.impact(.light)
                } label: {
                    Image(systemName: tool.icon)
                        .font(.system(size: 12, weight: viewModel.tool == tool ? .bold : .regular))
                        .foregroundColor(viewModel.tool == tool ? EchoelBrand.sky : EchoelBrand.textSecondary)
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: EchoelRadius.xs)
                                .fill(viewModel.tool == tool ? EchoelBrand.sky.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tool.rawValue) tool")
            }
        }
    }

    private var snapPicker: some View {
        Menu {
            ForEach(PianoRollViewModel.SnapDivision.allCases, id: \.self) { div in
                Button {
                    viewModel.snapDivision = div
                } label: {
                    HStack {
                        Text(div.rawValue)
                        if viewModel.snapDivision == div {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "grid")
                    .font(.system(size: 10))
                Text(viewModel.snapDivision.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(EchoelBrand.textSecondary)
            .padding(.horizontal, EchoelSpacing.xs)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.xs)
                    .fill(EchoelBrand.bgElevated)
            )
        }
    }

    private var zoomControl: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.zoom = Swift.max(0.25, viewModel.zoom - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)

            Text("\(Int(viewModel.zoom * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 32)

            Button {
                viewModel.zoom = Swift.min(4.0, viewModel.zoom + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var velocityToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.showVelocityLane.toggle()
            }
        } label: {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11))
                .foregroundColor(viewModel.showVelocityLane ? EchoelBrand.coral : EchoelBrand.textSecondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle velocity lane")
    }

    // MARK: - Beat Ruler

    private func beatRuler(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { context, size in
                let totalBeats = viewModel.totalBeats
                let ppb = pixelsPerBeat

                for beat in 0...Int(totalBeats) {
                    let x = CGFloat(beat) * ppb
                    guard x <= size.width else { break }

                    let isMeasure = beat % 4 == 0
                    let measureNum = beat / 4 + 1

                    // Tick mark
                    let tickHeight: CGFloat = isMeasure ? 10 : 5
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: size.height - tickHeight))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(path, with: .color(EchoelBrand.textSecondary.opacity(isMeasure ? 0.6 : 0.3)),
                                   lineWidth: isMeasure ? 1 : 0.5)

                    // Measure number
                    if isMeasure {
                        let text = Text("\(measureNum)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(EchoelBrand.textSecondary)
                        context.draw(context.resolve(text), at: CGPoint(x: x + 4, y: 6), anchor: .topLeading)
                    }
                }
            }
            .frame(width: gridWidth, height: headerBarHeight)
        }
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    // MARK: - Keyboard Sidebar

    private var keyboardSidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach((Int(PianoRollViewModel.lowestNote)...Int(PianoRollViewModel.highestNote)).reversed(), id: \.self) { midiNote in
                    let note = UInt8(midiNote)
                    let isBlack = PianoRollViewModel.isBlackKey(note)
                    let isCNote = PianoRollViewModel.isC(note)

                    HStack(spacing: 0) {
                        // Note label
                        Text(isCNote || isBlack ? PianoRollViewModel.noteName(for: note) : "")
                            .font(.system(size: 8, weight: isCNote ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isCNote ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 4)
                    }
                    .frame(height: noteRowHeight)
                    .background(isBlack ? Color.white.opacity(0.03) : Color.clear)
                    .overlay(alignment: .bottom) {
                        if isCNote {
                            Rectangle().fill(EchoelBrand.textSecondary.opacity(0.2)).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(EchoelBrand.border).frame(width: 0.5)
        }
    }

    // MARK: - Note Grid

    private func noteGrid(size: CGSize) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                // Background grid
                gridBackground

                // Notes
                ForEach(viewModel.notes) { note in
                    noteRect(note)
                }
            }
            .frame(width: gridWidth, height: gridHeight)
            .contentShape(Rectangle())
            .gesture(gridTapGesture)
        }
    }

    private var gridBackground: some View {
        Canvas { context, size in
            let ppb = pixelsPerBeat
            let rowH = noteRowHeight
            let totalBeats = viewModel.totalBeats

            // Draw horizontal note rows
            for i in 0..<PianoRollViewModel.noteRange {
                let y = CGFloat(i) * rowH
                let midiNote = UInt8(Int(PianoRollViewModel.highestNote) - i)
                let isBlack = PianoRollViewModel.isBlackKey(midiNote)
                let isCNote = PianoRollViewModel.isC(midiNote)

                // Row fill for black keys
                if isBlack {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: rowH)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.02)))
                }

                // Row separator — thicker for C notes
                if isCNote {
                    let line = Path { p in
                        p.move(to: CGPoint(x: 0, y: y + rowH))
                        p.addLine(to: CGPoint(x: size.width, y: y + rowH))
                    }
                    context.stroke(line, with: .color(EchoelBrand.textSecondary.opacity(0.15)), lineWidth: 0.5)
                }
            }

            // Vertical beat lines
            for beat in 0...Int(totalBeats) {
                let x = CGFloat(beat) * ppb
                guard x <= size.width else { break }

                let isMeasure = beat % 4 == 0
                let isHalf = beat % 2 == 0
                let line = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                let alpha: Double = isMeasure ? 0.2 : (isHalf ? 0.08 : 0.04)
                context.stroke(line, with: .color(EchoelBrand.textSecondary.opacity(alpha)),
                               lineWidth: isMeasure ? 1 : 0.5)
            }

            // Sub-beat grid lines based on snap
            let snapVal = viewModel.snapDivision.beatValue
            if snapVal > 0 && snapVal < 1 {
                let steps = Int(totalBeats / snapVal)
                for step in 0...steps {
                    let x = CGFloat(step) * CGFloat(snapVal) * ppb
                    guard x <= size.width else { break }
                    let beatPos = Double(step) * snapVal
                    // Skip if already drawn as a beat line
                    if beatPos.truncatingRemainder(dividingBy: 1.0) == 0 { continue }
                    let line = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(line, with: .color(EchoelBrand.textSecondary.opacity(0.03)), lineWidth: 0.5)
                }
            }
        }
    }

    // MARK: - Note Rect

    private func noteRect(_ note: MIDINoteEvent) -> some View {
        let x = CGFloat(note.startBeat) * pixelsPerBeat
        let w = CGFloat(note.duration) * pixelsPerBeat
        let row = Int(PianoRollViewModel.highestNote) - Int(note.note)
        let y = CGFloat(row) * noteRowHeight

        let isSelected = viewModel.selectedNoteIDs.contains(note.id)
        let velocityAlpha = Double(note.velocity) / 127.0
        let noteColor = noteColorForPitch(note.note)

        return RoundedRectangle(cornerRadius: 2)
            .fill(noteColor.opacity(0.3 + velocityAlpha * 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.white : noteColor.opacity(0.7), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .overlay(alignment: .leading) {
                // Note name inside large-enough notes
                if w > 30 {
                    Text(PianoRollViewModel.noteName(for: note.note))
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 3)
                }
            }
            .frame(width: Swift.max(4, w), height: noteRowHeight - 1)
            .position(x: x + w / 2, y: y + noteRowHeight / 2)
            .onTapGesture {
                handleNoteTap(note)
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        handleNoteDrag(note, translation: drag.translation)
                    }
            )
    }

    /// Color per pitch class (chromatic coloring like FL Studio)
    private func noteColorForPitch(_ midiNote: UInt8) -> Color {
        let pc = Int(midiNote) % 12
        switch pc {
        case 0: return EchoelBrand.sky          // C
        case 1: return EchoelBrand.violet       // C#
        case 2: return EchoelBrand.emerald      // D
        case 3: return EchoelBrand.violet       // D#
        case 4: return EchoelBrand.sky          // E
        case 5: return EchoelBrand.coral        // F
        case 6: return EchoelBrand.violet       // F#
        case 7: return EchoelBrand.emerald      // G
        case 8: return EchoelBrand.violet       // G#
        case 9: return Color(red: 1, green: 0.8, blue: 0.2) // A — gold
        case 10: return EchoelBrand.violet      // A#
        case 11: return EchoelBrand.coral       // B
        default: return EchoelBrand.sky
        }
    }

    // MARK: - Velocity Lane

    private func velocityLane(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { context, size in
                let ppb = pixelsPerBeat

                // Background lines at velocity 64 and 100
                for level in [32, 64, 100, 127] {
                    let y = size.height * (1.0 - Double(level) / 127.0)
                    let line = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(line, with: .color(EchoelBrand.textSecondary.opacity(0.1)), lineWidth: 0.5)

                    // Label
                    if level == 64 || level == 127 {
                        let text = Text("\(level)")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(EchoelBrand.textSecondary.opacity(0.4))
                        context.draw(context.resolve(text), at: CGPoint(x: 2, y: y - 4), anchor: .topLeading)
                    }
                }

                // Velocity bars for each note
                for note in viewModel.notes {
                    let x = CGFloat(note.startBeat) * ppb
                    let barWidth: CGFloat = Swift.max(3, CGFloat(note.duration) * ppb * 0.3)
                    let height = size.height * CGFloat(note.velocity) / 127.0
                    let y = size.height - height

                    let isSelected = viewModel.selectedNoteIDs.contains(note.id)
                    let color = isSelected ? EchoelBrand.sky : EchoelBrand.coral

                    let rect = CGRect(x: x - barWidth / 2, y: y, width: barWidth, height: height)
                    let roundedPath = Path(roundedRect: rect, cornerRadius: 1)
                    context.fill(roundedPath, with: .color(color.opacity(0.7)))
                }
            }
            .frame(width: gridWidth, height: velocityLaneHeight)
            .contentShape(Rectangle())
            .gesture(velocityDragGesture)
        }
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    private var velocityLabel: some View {
        VStack {
            Text("VEL")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.coral.opacity(0.6))
                .tracking(1)
        }
        .frame(maxHeight: .infinity)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(EchoelBrand.border).frame(width: 0.5)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    // MARK: - Gestures

    private var gridTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let beat = Double(value.location.x / pixelsPerBeat)
                let row = Int(value.location.y / noteRowHeight)
                let midiNote = UInt8(Swift.max(0, Swift.min(Int(PianoRollViewModel.highestNote) - row,
                                                            Int(PianoRollViewModel.highestNote))))
                guard midiNote >= PianoRollViewModel.lowestNote else { return }

                switch viewModel.tool {
                case .draw:
                    viewModel.addNote(note: midiNote, startBeat: beat)
                    HapticHelper.impact(.light)
                case .select:
                    viewModel.selectedNoteIDs.removeAll()
                case .erase:
                    break
                }
            }
    }

    private var velocityDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let beat = Double(drag.location.x / pixelsPerBeat)
                let velocity = UInt8(Swift.max(1, Swift.min(127, Int((1.0 - drag.location.y / velocityLaneHeight) * 127))))

                // Find closest note to this beat position
                if let closest = viewModel.notes.min(by: {
                    abs($0.startBeat - beat) < abs($1.startBeat - beat)
                }), abs(closest.startBeat - beat) < 0.5 {
                    viewModel.setVelocity(velocity, for: closest.id)
                }
            }
    }

    // MARK: - Interaction Handlers

    private func handleNoteTap(_ note: MIDINoteEvent) {
        switch viewModel.tool {
        case .draw, .select:
            viewModel.selectedNoteIDs = [note.id]
            HapticHelper.impact(.light)
        case .erase:
            viewModel.deleteNote(id: note.id)
            HapticHelper.impact(.medium)
        }
    }

    private func handleNoteDrag(_ note: MIDINoteEvent, translation: CGSize) {
        guard viewModel.tool == .select || viewModel.tool == .draw else { return }
        let deltaBeat = Double(translation.width / pixelsPerBeat)
        let deltaPitch = -Int(translation.height / noteRowHeight)
        viewModel.moveNote(id: note.id, deltaBeat: deltaBeat, deltaPitch: deltaPitch)
    }
}
#endif
