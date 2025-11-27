// StepSequencerView.swift
// Echoelmusic - Professional Step Sequencer
// Rivals: FL Studio Step Sequencer, Ableton Push, Native Instruments Maschine

import SwiftUI
import AVFoundation
import Combine

// MARK: - Step Sequencer Data Models

/// A single step in the sequencer
struct SequencerStep: Identifiable, Codable {
    let id: UUID
    var isEnabled: Bool
    var velocity: Int // 0-127
    var pitch: Int? // Optional pitch offset
    var probability: Float // 0-1, chance of triggering
    var microTiming: Float // -50 to +50 ms offset
    var gate: Float // 0-1, note length multiplier
    var retrigger: Int // Number of retriggers (rolls)
    var accent: Bool

    static func `default`() -> SequencerStep {
        SequencerStep(
            id: UUID(),
            isEnabled: false,
            velocity: 100,
            pitch: nil,
            probability: 1.0,
            microTiming: 0,
            gate: 0.75,
            retrigger: 0,
            accent: false
        )
    }
}

/// A single row/instrument in the sequencer
struct SequencerRow: Identifiable, Codable {
    let id: UUID
    var name: String
    var midiNote: Int // Base MIDI note
    var midiChannel: Int
    var color: RowColor
    var steps: [SequencerStep]
    var isMuted: Bool
    var isSolo: Bool
    var volume: Float // 0-1
    var pan: Float // -1 to 1
    var swing: Float // 0-1

    enum RowColor: String, Codable, CaseIterable {
        case red, orange, yellow, green, cyan, blue, purple, pink, white

        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .white: return .white
            }
        }
    }

    static func drums() -> [SequencerRow] {
        let drumKit: [(String, Int, RowColor)] = [
            ("Kick", 36, .red),
            ("Snare", 38, .orange),
            ("Clap", 39, .yellow),
            ("Closed HH", 42, .green),
            ("Open HH", 46, .cyan),
            ("Rim", 37, .blue),
            ("Tom Low", 45, .purple),
            ("Tom High", 50, .pink),
        ]

        return drumKit.map { name, note, color in
            SequencerRow(
                id: UUID(),
                name: name,
                midiNote: note,
                midiChannel: 10, // Standard drum channel
                color: color,
                steps: (0..<16).map { _ in SequencerStep.default() },
                isMuted: false,
                isSolo: false,
                volume: 0.8,
                pan: 0,
                swing: 0
            )
        }
    }
}

/// Pattern containing multiple rows
struct SequencerPattern: Identifiable, Codable {
    let id: UUID
    var name: String
    var rows: [SequencerRow]
    var stepsPerBar: Int
    var bars: Int
    var swing: Float
    var timeSignature: TimeSignature

    struct TimeSignature: Codable {
        var numerator: Int
        var denominator: Int
    }

    var totalSteps: Int { stepsPerBar * bars }

    static func defaultDrumPattern() -> SequencerPattern {
        var pattern = SequencerPattern(
            id: UUID(),
            name: "Pattern 1",
            rows: SequencerRow.drums(),
            stepsPerBar: 16,
            bars: 1,
            swing: 0,
            timeSignature: TimeSignature(numerator: 4, denominator: 4)
        )

        // Pre-fill with a basic beat
        if pattern.rows.count >= 4 {
            // Kick on 1, 5, 9, 13 (4-on-the-floor)
            for step in [0, 4, 8, 12] {
                pattern.rows[0].steps[step].isEnabled = true
            }
            // Snare on 5, 13
            for step in [4, 12] {
                pattern.rows[1].steps[step].isEnabled = true
            }
            // Closed HH on every step
            for step in 0..<16 {
                pattern.rows[3].steps[step].isEnabled = step % 2 == 0
            }
        }

        return pattern
    }
}

// MARK: - Step Sequencer Engine

@MainActor
class StepSequencerEngine: ObservableObject {
    // Patterns
    @Published var patterns: [SequencerPattern] = []
    @Published var currentPatternIndex: Int = 0

    // Playback
    @Published var isPlaying: Bool = false
    @Published var currentStep: Int = 0
    @Published var tempo: Double = 120

    // View State
    @Published var selectedRowIndex: Int? = nil
    @Published var selectedStepIndices: Set<Int> = []
    @Published var editMode: EditMode = .velocity
    @Published var viewMode: ViewMode = .grid
    @Published var showVelocityLane: Bool = true

    // MIDI Output
    var onNoteOn: ((Int, Int, Int) -> Void)? // note, velocity, channel
    var onNoteOff: ((Int, Int) -> Void)? // note, channel

    // Playback Timer
    private var playbackTimer: Timer?
    private var lastStepTime: Date?

    enum EditMode: String, CaseIterable {
        case velocity = "Velocity"
        case probability = "Probability"
        case gate = "Gate"
        case pitch = "Pitch"
        case microTiming = "Micro Timing"
    }

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case piano = "Piano Roll"
        case list = "List"
    }

    var currentPattern: SequencerPattern {
        get {
            guard currentPatternIndex < patterns.count else {
                return SequencerPattern.defaultDrumPattern()
            }
            return patterns[currentPatternIndex]
        }
        set {
            guard currentPatternIndex < patterns.count else { return }
            patterns[currentPatternIndex] = newValue
        }
    }

    init() {
        patterns = [SequencerPattern.defaultDrumPattern()]
    }

    // MARK: - Transport

    func play() {
        isPlaying = true
        currentStep = 0
        startPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        currentStep = 0
        stopPlaybackTimer()
        allNotesOff()
    }

    func pause() {
        isPlaying = false
        stopPlaybackTimer()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func startPlaybackTimer() {
        let stepDuration = 60.0 / tempo / 4.0 // 16th notes
        lastStepTime = Date()

        playbackTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceStep()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func advanceStep() {
        guard isPlaying else { return }

        // Trigger notes for current step
        triggerStep(currentStep)

        // Advance
        currentStep = (currentStep + 1) % currentPattern.totalSteps
    }

    private func triggerStep(_ step: Int) {
        for row in currentPattern.rows {
            guard !row.isMuted else { continue }
            guard step < row.steps.count else { continue }

            let stepData = row.steps[step]
            guard stepData.isEnabled else { continue }

            // Check probability
            if stepData.probability < 1.0 && Float.random(in: 0...1) > stepData.probability {
                continue
            }

            // Calculate velocity (with accent)
            var velocity = stepData.velocity
            if stepData.accent {
                velocity = min(127, velocity + 20)
            }

            // Trigger note
            let note = row.midiNote + (stepData.pitch ?? 0)
            onNoteOn?(note, velocity, row.midiChannel)

            // Schedule note off based on gate
            let stepDuration = 60.0 / tempo / 4.0
            let noteDuration = stepDuration * Double(stepData.gate)

            DispatchQueue.main.asyncAfter(deadline: .now() + noteDuration) { [weak self] in
                self?.onNoteOff?(note, row.midiChannel)
            }

            // Handle retriggers (rolls)
            if stepData.retrigger > 0 {
                let retriggerInterval = stepDuration / Double(stepData.retrigger + 1)
                for i in 1...stepData.retrigger {
                    DispatchQueue.main.asyncAfter(deadline: .now() + retriggerInterval * Double(i)) { [weak self] in
                        self?.onNoteOn?(note, velocity, row.midiChannel)
                        DispatchQueue.main.asyncAfter(deadline: .now() + noteDuration * 0.5) {
                            self?.onNoteOff?(note, row.midiChannel)
                        }
                    }
                }
            }
        }
    }

    private func allNotesOff() {
        for row in currentPattern.rows {
            onNoteOff?(row.midiNote, row.midiChannel)
        }
    }

    // MARK: - Step Editing

    func toggleStep(row: Int, step: Int) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].isEnabled.toggle()

        // Trigger sound preview
        if patterns[currentPatternIndex].rows[row].steps[step].isEnabled {
            let rowData = currentPattern.rows[row]
            onNoteOn?(rowData.midiNote, 100, rowData.midiChannel)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onNoteOff?(rowData.midiNote, rowData.midiChannel)
            }
        }
    }

    func setStepVelocity(row: Int, step: Int, velocity: Int) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].velocity = max(1, min(127, velocity))
    }

    func setStepProbability(row: Int, step: Int, probability: Float) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].probability = max(0, min(1, probability))
    }

    func setStepGate(row: Int, step: Int, gate: Float) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].gate = max(0.01, min(1, gate))
    }

    func toggleAccent(row: Int, step: Int) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].accent.toggle()
    }

    func setRetrigger(row: Int, step: Int, count: Int) {
        guard row < currentPattern.rows.count,
              step < currentPattern.rows[row].steps.count else { return }

        patterns[currentPatternIndex].rows[row].steps[step].retrigger = max(0, min(8, count))
    }

    // MARK: - Row Management

    func toggleRowMute(row: Int) {
        guard row < currentPattern.rows.count else { return }
        patterns[currentPatternIndex].rows[row].isMuted.toggle()
    }

    func toggleRowSolo(row: Int) {
        guard row < currentPattern.rows.count else { return }
        patterns[currentPatternIndex].rows[row].isSolo.toggle()
    }

    func setRowVolume(row: Int, volume: Float) {
        guard row < currentPattern.rows.count else { return }
        patterns[currentPatternIndex].rows[row].volume = max(0, min(1, volume))
    }

    func setRowPan(row: Int, pan: Float) {
        guard row < currentPattern.rows.count else { return }
        patterns[currentPatternIndex].rows[row].pan = max(-1, min(1, pan))
    }

    // MARK: - Pattern Operations

    func clearRow(row: Int) {
        guard row < currentPattern.rows.count else { return }
        for step in patterns[currentPatternIndex].rows[row].steps.indices {
            patterns[currentPatternIndex].rows[row].steps[step].isEnabled = false
        }
    }

    func fillRow(row: Int, interval: Int = 1) {
        guard row < currentPattern.rows.count else { return }
        for step in patterns[currentPatternIndex].rows[row].steps.indices {
            patterns[currentPatternIndex].rows[row].steps[step].isEnabled = step % interval == 0
        }
    }

    func randomizeRow(row: Int, density: Float = 0.25) {
        guard row < currentPattern.rows.count else { return }
        for step in patterns[currentPatternIndex].rows[row].steps.indices {
            patterns[currentPatternIndex].rows[row].steps[step].isEnabled = Float.random(in: 0...1) < density
            if patterns[currentPatternIndex].rows[row].steps[step].isEnabled {
                patterns[currentPatternIndex].rows[row].steps[step].velocity = Int.random(in: 60...127)
            }
        }
    }

    func shiftRow(row: Int, by offset: Int) {
        guard row < currentPattern.rows.count else { return }
        let steps = patterns[currentPatternIndex].rows[row].steps
        let count = steps.count
        let normalizedOffset = ((offset % count) + count) % count

        var newSteps = Array(repeating: SequencerStep.default(), count: count)
        for (index, step) in steps.enumerated() {
            let newIndex = (index + normalizedOffset) % count
            newSteps[newIndex] = step
        }
        patterns[currentPatternIndex].rows[row].steps = newSteps
    }

    func copyRow(from sourceRow: Int, to destRow: Int) {
        guard sourceRow < currentPattern.rows.count,
              destRow < currentPattern.rows.count else { return }
        patterns[currentPatternIndex].rows[destRow].steps = patterns[currentPatternIndex].rows[sourceRow].steps
    }

    // MARK: - Pattern Management

    func addPattern() {
        let newPattern = SequencerPattern.defaultDrumPattern()
        patterns.append(newPattern)
    }

    func duplicatePattern() {
        var copy = currentPattern
        copy.id = UUID()
        copy.name += " (Copy)"
        patterns.append(copy)
    }

    func deletePattern(at index: Int) {
        guard patterns.count > 1 else { return }
        patterns.remove(at: index)
        if currentPatternIndex >= patterns.count {
            currentPatternIndex = patterns.count - 1
        }
    }

    func setPatternLength(steps: Int) {
        for rowIndex in patterns[currentPatternIndex].rows.indices {
            let currentSteps = patterns[currentPatternIndex].rows[rowIndex].steps
            if steps > currentSteps.count {
                let additionalSteps = (currentSteps.count..<steps).map { _ in SequencerStep.default() }
                patterns[currentPatternIndex].rows[rowIndex].steps.append(contentsOf: additionalSteps)
            } else {
                patterns[currentPatternIndex].rows[rowIndex].steps = Array(currentSteps.prefix(steps))
            }
        }
    }
}

// MARK: - Step Sequencer View

struct StepSequencerView: View {
    @StateObject private var engine = StepSequencerEngine()
    @State private var showingSettings = false

    private let stepSize: CGFloat = 40
    private let rowHeaderWidth: CGFloat = 120
    private let velocityLaneHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            toolbar

            // Main Grid
            HStack(spacing: 0) {
                // Row Headers
                rowHeaders

                // Step Grid
                stepGrid
            }

            // Velocity Lane
            if engine.showVelocityLane {
                velocityLane
            }

            // Pattern Bar
            patternBar
        }
        .background(Color.black)
        .sheet(isPresented: $showingSettings) {
            SequencerSettingsView(engine: engine)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Logo
            Text("STEP SEQUENCER")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.cyan)

            Divider().frame(height: 30)

            // Transport
            HStack(spacing: 8) {
                Button(action: { engine.currentStep = 0 }) {
                    Image(systemName: "backward.end.fill")
                }

                Button(action: engine.togglePlayback) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                }
                .foregroundColor(engine.isPlaying ? .green : .white)

                Button(action: engine.stop) {
                    Image(systemName: "stop.fill")
                }
            }
            .foregroundColor(.white)

            Divider().frame(height: 30)

            // Tempo
            HStack(spacing: 4) {
                Text("\(Int(engine.tempo))")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Text("BPM")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Stepper("", value: $engine.tempo, in: 20...300, step: 1)
                    .labelsHidden()
                    .frame(width: 80)
            }

            Divider().frame(height: 30)

            // Edit Mode
            Picker("Mode", selection: $engine.editMode) {
                ForEach(StepSequencerEngine.EditMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            // Swing
            HStack(spacing: 4) {
                Text("SWING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Slider(value: Binding(
                    get: { Double(engine.currentPattern.swing) },
                    set: { engine.patterns[engine.currentPatternIndex].swing = Float($0) }
                ), in: 0...1)
                    .frame(width: 80)
                Text("\(Int(engine.currentPattern.swing * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 30)
            }

            // Settings
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
    }

    // MARK: - Row Headers

    private var rowHeaders: some View {
        VStack(spacing: 1) {
            // Header
            HStack {
                Text("INSTRUMENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(Color(white: 0.15))

            // Rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(engine.currentPattern.rows.indices, id: \.self) { rowIndex in
                        SequencerRowHeader(
                            row: engine.currentPattern.rows[rowIndex],
                            rowIndex: rowIndex,
                            engine: engine,
                            isSelected: engine.selectedRowIndex == rowIndex
                        )
                        .frame(height: stepSize)
                    }
                }
            }
        }
        .frame(width: rowHeaderWidth)
        .background(Color(white: 0.1))
    }

    // MARK: - Step Grid

    private var stepGrid: some View {
        VStack(spacing: 1) {
            // Step Numbers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(0..<engine.currentPattern.totalSteps, id: \.self) { step in
                        ZStack {
                            Rectangle()
                                .fill(step == engine.currentStep ? Color.cyan.opacity(0.3) : Color(white: 0.15))

                            Text("\(step + 1)")
                                .font(.system(size: 9, weight: step % 4 == 0 ? .bold : .regular, design: .monospaced))
                                .foregroundColor(step % 4 == 0 ? .white : .gray)
                        }
                        .frame(width: stepSize, height: 24)
                    }
                }
            }

            // Grid
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 1) {
                    ForEach(engine.currentPattern.rows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 1) {
                            ForEach(0..<engine.currentPattern.totalSteps, id: \.self) { stepIndex in
                                StepButton(
                                    step: engine.currentPattern.rows[rowIndex].steps[stepIndex],
                                    rowIndex: rowIndex,
                                    stepIndex: stepIndex,
                                    rowColor: engine.currentPattern.rows[rowIndex].color,
                                    isCurrentStep: stepIndex == engine.currentStep && engine.isPlaying,
                                    engine: engine
                                )
                                .frame(width: stepSize, height: stepSize)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Velocity Lane

    private var velocityLane: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Text(engine.editMode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: rowHeaderWidth)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        if let selectedRow = engine.selectedRowIndex {
                            ForEach(0..<engine.currentPattern.totalSteps, id: \.self) { stepIndex in
                                VelocityBar(
                                    step: engine.currentPattern.rows[selectedRow].steps[stepIndex],
                                    rowIndex: selectedRow,
                                    stepIndex: stepIndex,
                                    engine: engine
                                )
                                .frame(width: stepSize, height: velocityLaneHeight)
                            }
                        }
                    }
                }
            }
            .frame(height: velocityLaneHeight)
            .background(Color(white: 0.08))
        }
    }

    // MARK: - Pattern Bar

    private var patternBar: some View {
        HStack(spacing: 8) {
            // Pattern Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(engine.patterns.indices, id: \.self) { index in
                        Button(action: { engine.currentPatternIndex = index }) {
                            Text(engine.patterns[index].name)
                                .font(.system(size: 11, weight: engine.currentPatternIndex == index ? .bold : .regular))
                                .foregroundColor(engine.currentPatternIndex == index ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(engine.currentPatternIndex == index ? Color.cyan : Color(white: 0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: engine.addPattern) {
                        Image(systemName: "plus")
                            .foregroundColor(.gray)
                            .padding(6)
                            .background(Color(white: 0.2))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Quick Actions
            HStack(spacing: 4) {
                Button("Clear") {
                    if let row = engine.selectedRowIndex {
                        engine.clearRow(row: row)
                    }
                }
                .buttonStyle(SequencerButtonStyle())

                Button("Fill") {
                    if let row = engine.selectedRowIndex {
                        engine.fillRow(row: row, interval: 4)
                    }
                }
                .buttonStyle(SequencerButtonStyle())

                Button("Random") {
                    if let row = engine.selectedRowIndex {
                        engine.randomizeRow(row: row)
                    }
                }
                .buttonStyle(SequencerButtonStyle())

                Button("<<") {
                    if let row = engine.selectedRowIndex {
                        engine.shiftRow(row: row, by: -1)
                    }
                }
                .buttonStyle(SequencerButtonStyle())

                Button(">>") {
                    if let row = engine.selectedRowIndex {
                        engine.shiftRow(row: row, by: 1)
                    }
                }
                .buttonStyle(SequencerButtonStyle())
            }

            // Length
            HStack(spacing: 4) {
                Text("LENGTH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)

                Picker("", selection: Binding(
                    get: { engine.currentPattern.totalSteps },
                    set: { engine.setPatternLength(steps: $0) }
                )) {
                    Text("8").tag(8)
                    Text("16").tag(16)
                    Text("32").tag(32)
                    Text("64").tag(64)
                }
                .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }
}

// MARK: - Supporting Views

struct SequencerRowHeader: View {
    let row: SequencerRow
    let rowIndex: Int
    @ObservedObject var engine: StepSequencerEngine
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            // Color indicator
            Rectangle()
                .fill(row.color.color)
                .frame(width: 4)

            // Name
            Text(row.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Mute/Solo
            HStack(spacing: 2) {
                Button(action: { engine.toggleRowMute(row: rowIndex) }) {
                    Text("M")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 16, height: 16)
                .background(row.isMuted ? Color.orange.opacity(0.5) : Color(white: 0.2))
                .foregroundColor(row.isMuted ? .orange : .gray)
                .cornerRadius(2)

                Button(action: { engine.toggleRowSolo(row: rowIndex) }) {
                    Text("S")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 16, height: 16)
                .background(row.isSolo ? Color.cyan.opacity(0.5) : Color(white: 0.2))
                .foregroundColor(row.isSolo ? .cyan : .gray)
                .cornerRadius(2)
            }
        }
        .padding(.horizontal, 4)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            engine.selectedRowIndex = rowIndex
        }
    }
}

struct StepButton: View {
    let step: SequencerStep
    let rowIndex: Int
    let stepIndex: Int
    let rowColor: SequencerRow.RowColor
    let isCurrentStep: Bool
    @ObservedObject var engine: StepSequencerEngine

    var body: some View {
        Button(action: {
            engine.toggleStep(row: rowIndex, step: stepIndex)
        }) {
            ZStack {
                // Background
                Rectangle()
                    .fill(backgroundColor)

                // Step indicator
                if step.isEnabled {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rowColor.color.opacity(velocityOpacity))
                        .padding(4)

                    // Accent indicator
                    if step.accent {
                        VStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }

                    // Probability indicator
                    if step.probability < 1.0 {
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: CGFloat(step.probability) * 30, height: 2)
                        }
                        .padding(.bottom, 2)
                    }

                    // Retrigger indicator
                    if step.retrigger > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<min(step.retrigger, 4), id: \.self) { _ in
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 3, height: 3)
                            }
                        }
                    }
                }

                // Playhead indicator
                if isCurrentStep {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.cyan, lineWidth: 2)
                        .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        let isDownbeat = stepIndex % 4 == 0
        let isOffbeat = stepIndex % 2 == 1

        if isDownbeat {
            return Color(white: 0.2)
        } else if isOffbeat {
            return Color(white: 0.12)
        }
        return Color(white: 0.15)
    }

    private var velocityOpacity: Double {
        0.4 + Double(step.velocity) / 127.0 * 0.6
    }
}

struct VelocityBar: View {
    let step: SequencerStep
    let rowIndex: Int
    let stepIndex: Int
    @ObservedObject var engine: StepSequencerEngine

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                Rectangle()
                    .fill(step.isEnabled ? Color.cyan : Color(white: 0.2))
                    .frame(
                        width: geometry.size.width - 4,
                        height: currentBarHeight(in: geometry.size.height)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newValue = 1.0 - value.location.y / geometry.size.height
                                updateValue(Float(max(0, min(1, newValue))))
                            }
                    )
            }
        }
    }

    private func currentBarHeight(in totalHeight: CGFloat) -> CGFloat {
        let value: Float
        switch engine.editMode {
        case .velocity:
            value = Float(step.velocity) / 127.0
        case .probability:
            value = step.probability
        case .gate:
            value = step.gate
        case .pitch:
            value = Float(step.pitch ?? 0 + 12) / 24.0
        case .microTiming:
            value = (step.microTiming + 50) / 100.0
        }
        return totalHeight * CGFloat(value) * 0.9
    }

    private func updateValue(_ normalized: Float) {
        switch engine.editMode {
        case .velocity:
            engine.setStepVelocity(row: rowIndex, step: stepIndex, velocity: Int(normalized * 127))
        case .probability:
            engine.setStepProbability(row: rowIndex, step: stepIndex, probability: normalized)
        case .gate:
            engine.setStepGate(row: rowIndex, step: stepIndex, gate: normalized)
        case .pitch:
            let pitch = Int(normalized * 24) - 12
            engine.patterns[engine.currentPatternIndex].rows[rowIndex].steps[stepIndex].pitch = pitch
        case .microTiming:
            let timing = normalized * 100 - 50
            engine.patterns[engine.currentPatternIndex].rows[rowIndex].steps[stepIndex].microTiming = timing
        }
    }
}

struct SequencerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color(white: 0.35) : Color(white: 0.25))
            )
    }
}

struct SequencerSettingsView: View {
    @ObservedObject var engine: StepSequencerEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Pattern Settings") {
                    TextField("Pattern Name", text: Binding(
                        get: { engine.currentPattern.name },
                        set: { engine.patterns[engine.currentPatternIndex].name = $0 }
                    ))

                    Picker("Steps per Bar", selection: Binding(
                        get: { engine.currentPattern.stepsPerBar },
                        set: { engine.patterns[engine.currentPatternIndex].stepsPerBar = $0 }
                    )) {
                        Text("8").tag(8)
                        Text("16").tag(16)
                        Text("32").tag(32)
                    }

                    Picker("Bars", selection: Binding(
                        get: { engine.currentPattern.bars },
                        set: { engine.patterns[engine.currentPatternIndex].bars = $0 }
                    )) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                }

                Section("View") {
                    Toggle("Show Velocity Lane", isOn: $engine.showVelocityLane)

                    Picker("View Mode", selection: $engine.viewMode) {
                        ForEach(StepSequencerEngine.ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Actions") {
                    Button("Duplicate Pattern") {
                        engine.duplicatePattern()
                    }

                    Button("Delete Pattern", role: .destructive) {
                        engine.deletePattern(at: engine.currentPatternIndex)
                    }
                    .disabled(engine.patterns.count <= 1)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StepSequencerView()
        .preferredColorScheme(.dark)
        .frame(width: 1200, height: 700)
}
