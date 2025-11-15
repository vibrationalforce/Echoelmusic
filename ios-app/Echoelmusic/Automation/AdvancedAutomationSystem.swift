//
//  AdvancedAutomationSystem.swift
//  Echoelmusic
//
//  Advanced parameter automation with modulation matrix, LFOs,
//  envelopes, and macro controls for professional production.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Advanced Automation System

@MainActor
class AdvancedAutomationSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var automationLanes: [AutomationLane] = []
    @Published var modulationMatrix: ModulationMatrix = ModulationMatrix()
    @Published var macroControls: [MacroControl] = []
    @Published var lfos: [LFO] = []
    @Published var envelopes: [Envelope] = []
    @Published var isRecording: Bool = false
    @Published var recordMode: RecordMode = .latch
    @Published var selectedLane: AutomationLane?

    // MARK: - Settings

    var snapToGrid: Bool = true
    var gridResolution: NoteValue = .sixteenth
    var automationCurve: AutomationCurve = .linear

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var lastProcessTime: TimeInterval = 0

    // MARK: - Initialization

    init() {
        setupDefaultMacros()
        setupDefaultLFOs()
        setupDefaultEnvelopes()
    }

    // MARK: - Setup

    private func setupDefaultMacros() {
        // Create 8 macro controls
        for i in 1...8 {
            let macro = MacroControl(
                id: UUID(),
                name: "Macro \(i)",
                value: 0.5,
                range: 0...1
            )
            macroControls.append(macro)
        }
    }

    private func setupDefaultLFOs() {
        // Create 4 default LFOs
        for i in 1...4 {
            let lfo = LFO(
                id: UUID(),
                name: "LFO \(i)",
                waveform: .sine,
                rate: 1.0,
                depth: 0.5,
                phase: 0,
                syncToTempo: false
            )
            lfos.append(lfo)
        }
    }

    private func setupDefaultEnvelopes() {
        // Create default envelope
        let envelope = Envelope(
            id: UUID(),
            name: "Envelope 1",
            attack: 0.01,
            decay: 0.1,
            sustain: 0.7,
            release: 0.3
        )
        envelopes.append(envelope)
    }

    // MARK: - Automation Lane Management

    func createAutomationLane(for parameter: AutomatableParameter) -> AutomationLane {
        let lane = AutomationLane(
            id: UUID(),
            parameter: parameter,
            points: []
        )
        automationLanes.append(lane)
        return lane
    }

    func deleteAutomationLane(_ lane: AutomationLane) {
        automationLanes.removeAll { $0.id == lane.id }
    }

    func addAutomationPoint(to lane: AutomationLane, at time: TimeInterval, value: Float) {
        guard let index = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        let point = AutomationPoint(time: time, value: value, curve: automationCurve)
        updatedLane.points.append(point)
        updatedLane.points.sort { $0.time < $1.time }

        automationLanes[index] = updatedLane
    }

    func removeAutomationPoint(from lane: AutomationLane, at index: Int) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        updatedLane.points.remove(at: index)
        automationLanes[laneIndex] = updatedLane
    }

    func moveAutomationPoint(in lane: AutomationLane, at pointIndex: Int, to time: TimeInterval, value: Float) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        updatedLane.points[pointIndex].time = time
        updatedLane.points[pointIndex].value = value
        updatedLane.points.sort { $0.time < $1.time }

        automationLanes[laneIndex] = updatedLane
    }

    // MARK: - Automation Playback

    func getAutomatedValue(for parameter: AutomatableParameter, at time: TimeInterval) -> Float {
        // Find automation lane for parameter
        guard let lane = automationLanes.first(where: { $0.parameter == parameter }) else {
            return parameter.defaultValue
        }

        // If no points, return default
        if lane.points.isEmpty {
            return parameter.defaultValue
        }

        // Find surrounding points
        let beforePoint = lane.points.last { $0.time <= time }
        let afterPoint = lane.points.first { $0.time > time }

        if let before = beforePoint, let after = afterPoint {
            // Interpolate between points
            return interpolate(from: before, to: after, at: time)
        } else if let before = beforePoint {
            // After last point, hold value
            return before.value
        } else if let after = afterPoint {
            // Before first point, use default
            return parameter.defaultValue
        }

        return parameter.defaultValue
    }

    private func interpolate(from: AutomationPoint, to: AutomationPoint, at time: TimeInterval) -> Float {
        let duration = to.time - from.time
        guard duration > 0 else { return from.value }

        let progress = Float((time - from.time) / duration)

        switch from.curve {
        case .linear:
            return from.value + (to.value - from.value) * progress

        case .exponential:
            let expProgress = pow(progress, 2)
            return from.value + (to.value - from.value) * expProgress

        case .logarithmic:
            let logProgress = sqrt(progress)
            return from.value + (to.value - from.value) * logProgress

        case .sCurve:
            let sCurveProgress = (1 - cos(progress * .pi)) / 2
            return from.value + (to.value - from.value) * sCurveProgress

        case .step:
            return from.value

        case .bezier(let cp1, let cp2):
            let bezierProgress = cubicBezier(t: progress, p1: cp1, p2: cp2)
            return from.value + (to.value - from.value) * bezierProgress
        }
    }

    private func cubicBezier(t: Float, p1: Float, p2: Float) -> Float {
        let u = 1 - t
        let tt = t * t
        let uu = u * u

        return 3 * uu * t * p1 + 3 * u * tt * p2 + tt * t
    }

    // MARK: - Modulation Matrix

    func addModulation(source: ModulationSource, target: AutomatableParameter, amount: Float) {
        let routing = ModulationRouting(
            id: UUID(),
            source: source,
            target: target,
            amount: amount,
            enabled: true
        )
        modulationMatrix.routings.append(routing)
    }

    func removeModulation(_ routing: ModulationRouting) {
        modulationMatrix.routings.removeAll { $0.id == routing.id }
    }

    func processModulation(at time: TimeInterval, tempo: Double) -> [AutomatableParameter: Float] {
        var modulatedValues: [AutomatableParameter: Float] = [:]

        for routing in modulationMatrix.routings where routing.enabled {
            let sourceValue = getSourceValue(routing.source, at: time, tempo: tempo)
            let modulationAmount = sourceValue * routing.amount

            modulatedValues[routing.target, default: 0] += modulationAmount
        }

        return modulatedValues
    }

    private func getSourceValue(_ source: ModulationSource, at time: TimeInterval, tempo: Double) -> Float {
        switch source {
        case .lfo(let lfoID):
            guard let lfo = lfos.first(where: { $0.id == lfoID }) else { return 0 }
            return lfo.getValue(at: time, tempo: tempo)

        case .envelope(let envelopeID):
            guard let envelope = envelopes.first(where: { $0.id == envelopeID }) else { return 0 }
            return envelope.getValue(at: time)

        case .macro(let macroID):
            guard let macro = macroControls.first(where: { $0.id == macroID }) else { return 0 }
            return Float(macro.value)

        case .velocity:
            // In production, get from MIDI note
            return 0.8

        case .aftertouch:
            // In production, get from MIDI
            return 0

        case .modWheel:
            // In production, get from MIDI CC
            return 0

        case .pitchBend:
            // In production, get from MIDI
            return 0
        }
    }

    // MARK: - Recording

    func startRecording(lane: AutomationLane) {
        isRecording = true
        selectedLane = lane

        switch recordMode {
        case .latch:
            // Keep previous automation, add new points
            break

        case .overwrite:
            // Clear existing automation
            if let index = automationLanes.firstIndex(where: { $0.id == lane.id }) {
                automationLanes[index].points.removeAll()
            }

        case .touch:
            // Only record while touching
            break
        }
    }

    func recordAutomationValue(_ value: Float, at time: TimeInterval) {
        guard isRecording, let lane = selectedLane else { return }

        // Snap to grid if enabled
        let snappedTime = snapToGrid ? snapTimeToGrid(time) : time

        addAutomationPoint(to: lane, at: snappedTime, value: value)
    }

    func stopRecording() {
        isRecording = false
        selectedLane = nil
    }

    private func snapTimeToGrid(_ time: TimeInterval) -> TimeInterval {
        // In production, calculate based on tempo and grid resolution
        let gridSize = 0.25 // 1/4 second for example
        return round(time / gridSize) * gridSize
    }

    // MARK: - Automation Editing

    func scaleAutomation(in lane: AutomationLane, by factor: Float) {
        guard let index = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        for i in 0..<updatedLane.points.count {
            updatedLane.points[i].value *= factor
            updatedLane.points[i].value = min(max(updatedLane.points[i].value, 0), 1)
        }

        automationLanes[index] = updatedLane
    }

    func offsetAutomation(in lane: AutomationLane, by offset: Float) {
        guard let index = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        for i in 0..<updatedLane.points.count {
            updatedLane.points[i].value += offset
            updatedLane.points[i].value = min(max(updatedLane.points[i].value, 0), 1)
        }

        automationLanes[index] = updatedLane
    }

    func smoothAutomation(in lane: AutomationLane, amount: Float) {
        guard let index = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane
        let points = updatedLane.points

        for i in 1..<(points.count - 1) {
            let prev = points[i - 1].value
            let curr = points[i].value
            let next = points[i + 1].value

            let smoothed = (prev + curr * 2 + next) / 4
            updatedLane.points[i].value = curr * (1 - amount) + smoothed * amount
        }

        automationLanes[index] = updatedLane
    }

    func drawAutomationCurve(in lane: AutomationLane, from startTime: TimeInterval, to endTime: TimeInterval, startValue: Float, endValue: Float, curveType: AutomationCurve) {
        guard let index = automationLanes.firstIndex(where: { $0.id == lane.id }) else { return }

        var updatedLane = lane

        // Remove points in range
        updatedLane.points.removeAll { $0.time >= startTime && $0.time <= endTime }

        // Generate new curve
        let steps = 32
        for i in 0...steps {
            let progress = Float(i) / Float(steps)
            let time = startTime + (endTime - startTime) * TimeInterval(progress)

            let point = AutomationPoint(
                time: time,
                value: interpolateValue(startValue, endValue, progress: progress, curve: curveType),
                curve: curveType
            )

            updatedLane.points.append(point)
        }

        updatedLane.points.sort { $0.time < $1.time }
        automationLanes[index] = updatedLane
    }

    private func interpolateValue(_ start: Float, _ end: Float, progress: Float, curve: AutomationCurve) -> Float {
        switch curve {
        case .linear:
            return start + (end - start) * progress
        case .exponential:
            return start + (end - start) * pow(progress, 2)
        case .logarithmic:
            return start + (end - start) * sqrt(progress)
        case .sCurve:
            let sCurveProgress = (1 - cos(progress * .pi)) / 2
            return start + (end - start) * sCurveProgress
        case .step:
            return progress < 0.5 ? start : end
        case .bezier(let cp1, let cp2):
            let bezierProgress = cubicBezier(t: progress, p1: cp1, p2: cp2)
            return start + (end - start) * bezierProgress
        }
    }
}

// MARK: - LFO

class LFO: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var waveform: Waveform
    @Published var rate: Float // Hz or tempo-synced
    @Published var depth: Float
    @Published var phase: Float // 0-1
    @Published var syncToTempo: Bool
    @Published var tempoRate: NoteValue = .quarter
    @Published var bipolar: Bool = true
    @Published var enabled: Bool = true

    enum Waveform {
        case sine
        case triangle
        case square
        case sawtooth
        case reverseSawtooth
        case random
        case sampleAndHold
    }

    init(id: UUID, name: String, waveform: Waveform, rate: Float, depth: Float, phase: Float, syncToTempo: Bool) {
        self.id = id
        self.name = name
        self.waveform = waveform
        self.rate = rate
        self.depth = depth
        self.phase = phase
        self.syncToTempo = syncToTempo
    }

    func getValue(at time: TimeInterval, tempo: Double) -> Float {
        guard enabled else { return bipolar ? 0 : 0.5 }

        let frequency: Float
        if syncToTempo {
            let beatsPerSecond = Float(tempo / 60.0)
            frequency = beatsPerSecond * tempoRate.multiplier
        } else {
            frequency = rate
        }

        let t = Float(time) * frequency + phase
        let rawValue = getWaveformValue(t)
        let scaledValue = rawValue * depth

        return bipolar ? scaledValue : (scaledValue + 1) / 2
    }

    private func getWaveformValue(_ t: Float) -> Float {
        let normalizedT = t.truncatingRemainder(dividingBy: 1)

        switch waveform {
        case .sine:
            return sin(normalizedT * 2 * .pi)

        case .triangle:
            return normalizedT < 0.5
                ? (normalizedT * 4 - 1)
                : (3 - normalizedT * 4)

        case .square:
            return normalizedT < 0.5 ? 1 : -1

        case .sawtooth:
            return normalizedT * 2 - 1

        case .reverseSawtooth:
            return 1 - normalizedT * 2

        case .random:
            return Float.random(in: -1...1)

        case .sampleAndHold:
            let stepIndex = Int(t * 4) // 4 steps per cycle
            return Float(stepIndex % 2 == 0 ? 1 : -1)
        }
    }
}

// MARK: - Envelope

class Envelope: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var attack: Float
    @Published var decay: Float
    @Published var sustain: Float
    @Published var release: Float
    @Published var enabled: Bool = true

    private var triggerTime: TimeInterval?
    private var releaseTime: TimeInterval?

    init(id: UUID, name: String, attack: Float, decay: Float, sustain: Float, release: Float) {
        self.id = id
        self.name = name
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }

    func trigger(at time: TimeInterval) {
        triggerTime = time
        releaseTime = nil
    }

    func release(at time: TimeInterval) {
        releaseTime = time
    }

    func getValue(at time: TimeInterval) -> Float {
        guard enabled, let trigger = triggerTime else { return 0 }

        let elapsed = Float(time - trigger)

        if let releaseT = releaseTime {
            // Release stage
            let releaseElapsed = Float(time - releaseT)
            let currentValue = getValue(at: releaseT) // Value when release was triggered
            let releaseProgress = min(releaseElapsed / release, 1)
            return currentValue * (1 - releaseProgress)
        }

        if elapsed < attack {
            // Attack stage
            return elapsed / attack

        } else if elapsed < attack + decay {
            // Decay stage
            let decayProgress = (elapsed - attack) / decay
            return 1 - (1 - sustain) * decayProgress

        } else {
            // Sustain stage
            return sustain
        }
    }
}

// MARK: - Macro Control

struct MacroControl: Identifiable {
    let id: UUID
    var name: String
    var value: Double
    var range: ClosedRange<Double>
    var linkedParameters: [AutomatableParameter] = []
}

// MARK: - Modulation Matrix

struct ModulationMatrix {
    var routings: [ModulationRouting] = []
}

struct ModulationRouting: Identifiable {
    let id: UUID
    var source: ModulationSource
    var target: AutomatableParameter
    var amount: Float
    var enabled: Bool
}

enum ModulationSource: Hashable, Codable {
    case lfo(UUID)
    case envelope(UUID)
    case macro(UUID)
    case velocity
    case aftertouch
    case modWheel
    case pitchBend
}

// MARK: - Automation Data

struct AutomationLane: Identifiable, Equatable {
    let id: UUID
    var parameter: AutomatableParameter
    var points: [AutomationPoint]
    var enabled: Bool = true
    var color: String = "blue"
}

struct AutomationPoint: Identifiable, Equatable {
    let id = UUID()
    var time: TimeInterval
    var value: Float
    var curve: AutomationCurve
}

enum AutomationCurve: Equatable, Codable {
    case linear
    case exponential
    case logarithmic
    case sCurve
    case step
    case bezier(cp1: Float, cp2: Float)
}

enum AutomatableParameter: Hashable, Codable {
    case volume
    case pan
    case mute
    case effectParameter(effectID: UUID, parameterIndex: Int)
    case instrumentParameter(instrumentID: UUID, parameterIndex: Int)
    case sendLevel(sendIndex: Int)
    case pitch
    case tempo
    case custom(name: String)

    var defaultValue: Float {
        switch self {
        case .volume: return 0.8
        case .pan: return 0.5
        case .mute: return 0
        case .effectParameter: return 0.5
        case .instrumentParameter: return 0.5
        case .sendLevel: return 0
        case .pitch: return 0.5
        case .tempo: return 120
        case .custom: return 0.5
        }
    }
}

enum RecordMode {
    case latch      // Keep previous automation, add new
    case overwrite  // Replace all automation
    case touch      // Record only while touching
}

enum NoteValue {
    case whole
    case half
    case quarter
    case eighth
    case sixteenth
    case thirtySecond

    var multiplier: Float {
        switch self {
        case .whole: return 1.0
        case .half: return 2.0
        case .quarter: return 4.0
        case .eighth: return 8.0
        case .sixteenth: return 16.0
        case .thirtySecond: return 32.0
        }
    }
}

// MARK: - SwiftUI Views

struct AutomationLaneView: View {
    @Binding var lane: AutomationLane
    let width: CGFloat
    let height: CGFloat
    let duration: TimeInterval

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Rectangle()
                .fill(Color.gray.opacity(0.1))

            // Grid
            AutomationGridView(divisions: 8, width: width, height: height)

            // Automation curve
            AutomationCurveView(points: lane.points, width: width, height: height, duration: duration)

            // Points
            ForEach(Array(lane.points.enumerated()), id: \.element.id) { index, point in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .position(
                        x: CGFloat(point.time / duration) * width,
                        y: height - CGFloat(point.value) * height
                    )
            }
        }
        .frame(width: width, height: height)
    }
}

struct AutomationGridView: View {
    let divisions: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Horizontal lines
            ForEach(0..<divisions + 1) { i in
                Path { path in
                    let y = CGFloat(i) / CGFloat(divisions) * height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }

            // Vertical lines
            ForEach(0..<divisions + 1) { i in
                Path { path in
                    let x = CGFloat(i) / CGFloat(divisions) * width
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
    }
}

struct AutomationCurveView: View {
    let points: [AutomationPoint]
    let width: CGFloat
    let height: CGFloat
    let duration: TimeInterval

    var body: some View {
        Path { path in
            guard !points.isEmpty else { return }

            let firstPoint = points[0]
            path.move(to: CGPoint(
                x: CGFloat(firstPoint.time / duration) * width,
                y: height - CGFloat(firstPoint.value) * height
            ))

            for point in points.dropFirst() {
                path.addLine(to: CGPoint(
                    x: CGFloat(point.time / duration) * width,
                    y: height - CGFloat(point.value) * height
                ))
            }
        }
        .stroke(Color.accentColor, lineWidth: 2)
    }
}

struct ModulationMatrixView: View {
    @ObservedObject var automationSystem: AdvancedAutomationSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Modulation Matrix")
                .font(.headline)

            ForEach(automationSystem.modulationMatrix.routings) { routing in
                HStack {
                    Text(sourceText(routing.source))
                        .frame(width: 100, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    Text(targetText(routing.target))
                        .frame(width: 100, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { Double(routing.amount) },
                            set: { _ in }
                        ),
                        in: -1...1
                    )
                    .frame(width: 150)

                    Toggle("", isOn: Binding(
                        get: { routing.enabled },
                        set: { _ in }
                    ))
                }
            }
        }
        .padding()
    }

    private func sourceText(_ source: ModulationSource) -> String {
        switch source {
        case .lfo(let id):
            return automationSystem.lfos.first { $0.id == id }?.name ?? "LFO"
        case .envelope(let id):
            return automationSystem.envelopes.first { $0.id == id }?.name ?? "Envelope"
        case .macro(let id):
            return automationSystem.macroControls.first { $0.id == id }?.name ?? "Macro"
        case .velocity: return "Velocity"
        case .aftertouch: return "Aftertouch"
        case .modWheel: return "Mod Wheel"
        case .pitchBend: return "Pitch Bend"
        }
    }

    private func targetText(_ target: AutomatableParameter) -> String {
        switch target {
        case .volume: return "Volume"
        case .pan: return "Pan"
        case .mute: return "Mute"
        case .effectParameter: return "Effect"
        case .instrumentParameter: return "Instrument"
        case .sendLevel: return "Send"
        case .pitch: return "Pitch"
        case .tempo: return "Tempo"
        case .custom(let name): return name
        }
    }
}
