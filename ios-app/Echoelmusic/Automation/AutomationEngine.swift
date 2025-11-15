import Foundation
import SwiftUI
import Combine

// MARK: - Automation Engine
/// Advanced automation system with modulators, envelopes, and macro controls
/// Phase 12: Complete automation for all parameters
class AutomationEngine: ObservableObject {

    // MARK: - Published Properties
    @Published var modulators: [Modulator] = []
    @Published var macros: [MacroControl] = []
    @Published var selectedModulator: Modulator?

    // MARK: - Properties
    private let timeline: Timeline
    private var cancellables = Set<AnyCancellable>()

    // Playback sync
    private var currentTime: CMTime = .zero
    private var isPlaying: Bool = false

    // MARK: - Initialization
    init(timeline: Timeline) {
        self.timeline = timeline
        setupDefaultModulators()
    }

    // MARK: - Modulator Management

    func addModulator(_ modulator: Modulator) {
        modulators.append(modulator)
    }

    func removeModulator(_ id: UUID) {
        modulators.removeAll { $0.id == id }
    }

    func createLFO(name: String) -> LFOModulator {
        let lfo = LFOModulator(name: name)
        addModulator(lfo)
        return lfo
    }

    func createEnvelopeFollower(name: String, sourceTrack: Track?) -> EnvelopeFollower {
        let follower = EnvelopeFollower(name: name, sourceTrack: sourceTrack)
        addModulator(follower)
        return follower
    }

    func createRandomModulator(name: String) -> RandomModulator {
        let random = RandomModulator(name: name)
        addModulator(random)
        return random
    }

    // MARK: - Macro Controls

    func createMacro(name: String) -> MacroControl {
        let macro = MacroControl(name: name)
        macros.append(macro)
        return macro
    }

    func removeMacro(_ id: UUID) {
        macros.removeAll { $0.id == id }
    }

    // MARK: - Playback

    func update(time: CMTime, playing: Bool) {
        currentTime = time
        isPlaying = playing

        // Update all modulators
        let timeSeconds = time.seconds

        for i in 0..<modulators.count {
            modulators[i].update(time: timeSeconds, playing: playing)
        }

        // Update macros (which update their mapped parameters)
        for i in 0..<macros.count {
            macros[i].update()
        }
    }

    func reset() {
        for i in 0..<modulators.count {
            modulators[i].reset()
        }
    }

    // MARK: - Private

    private func setupDefaultModulators() {
        // Create some default LFOs for quick use
        _ = createLFO(name: "LFO 1")
        _ = createLFO(name: "LFO 2")
    }
}

// MARK: - Modulator Protocol

protocol Modulator: AnyObject, Identifiable, ObservableObject {
    var id: UUID { get }
    var name: String { get set }
    var value: Float { get }
    var depth: Float { get set }
    var enabled: Bool { get set }

    func update(time: Double, playing: Bool)
    func reset()
}

// MARK: - LFO Modulator

class LFOModulator: Modulator, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var value: Float = 0.0
    @Published var depth: Float = 1.0
    @Published var enabled: Bool = true

    // LFO Parameters
    @Published var rate: Float = 1.0           // Hz
    @Published var waveform: Waveform = .sine
    @Published var phase: Float = 0.0          // 0-1
    @Published var sync: SyncMode = .free
    @Published var retrigger: Bool = false

    private var currentPhase: Float = 0.0
    private var lastTime: Double = 0.0

    enum Waveform: String, CaseIterable {
        case sine, triangle, square, saw, random

        func generate(phase: Float) -> Float {
            let normalizedPhase = phase.truncatingRemainder(dividingBy: 1.0)

            switch self {
            case .sine:
                return sin(normalizedPhase * 2.0 * .pi)

            case .triangle:
                if normalizedPhase < 0.5 {
                    return normalizedPhase * 4.0 - 1.0
                } else {
                    return 3.0 - normalizedPhase * 4.0
                }

            case .square:
                return normalizedPhase < 0.5 ? 1.0 : -1.0

            case .saw:
                return normalizedPhase * 2.0 - 1.0

            case .random:
                // Sample-and-hold random
                return Float.random(in: -1...1)
            }
        }
    }

    enum SyncMode: String, CaseIterable {
        case free           // Free running
        case beatSync       // Sync to beat (1/4, 1/8, etc.)
        case barSync        // Sync to bar
    }

    init(name: String) {
        self.name = name
        self.currentPhase = phase
    }

    func update(time: Double, playing: Bool) {
        guard enabled else {
            value = 0.0
            return
        }

        // Calculate delta time
        let dt = playing ? Float(time - lastTime) : 0.0
        lastTime = time

        // Update phase based on rate
        if sync == .free {
            currentPhase += dt * rate
        } else {
            // TODO: Implement beat/bar sync (requires tempo from timeline)
            currentPhase += dt * rate
        }

        // Generate waveform value
        let rawValue = waveform.generate(phase: currentPhase)

        // Apply depth
        value = rawValue * depth
    }

    func reset() {
        currentPhase = phase
        lastTime = 0.0
    }
}

// MARK: - Envelope Follower

class EnvelopeFollower: Modulator, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var value: Float = 0.0
    @Published var depth: Float = 1.0
    @Published var enabled: Bool = true

    // Envelope Parameters
    @Published var attack: Float = 0.01        // Seconds
    @Published var release: Float = 0.1        // Seconds
    @Published var sourceTrack: Track?

    private var currentEnvelope: Float = 0.0

    init(name: String, sourceTrack: Track?) {
        self.name = name
        self.sourceTrack = sourceTrack
    }

    func update(time: Double, playing: Bool) {
        guard enabled, let track = sourceTrack else {
            value = 0.0
            return
        }

        // Get audio level from track (simplified - would need actual audio analysis)
        let audioLevel = getAudioLevel(from: track, at: time)

        // Apply attack/release envelope
        if audioLevel > currentEnvelope {
            // Attack phase
            let attackRate = 1.0 / max(attack, 0.001)
            currentEnvelope = min(currentEnvelope + Float(attackRate * 0.016), audioLevel) // Assuming ~60fps update
        } else {
            // Release phase
            let releaseRate = 1.0 / max(release, 0.001)
            currentEnvelope = max(currentEnvelope - Float(releaseRate * 0.016), audioLevel)
        }

        // Apply depth
        value = currentEnvelope * depth
    }

    func reset() {
        currentEnvelope = 0.0
    }

    private func getAudioLevel(from track: Track, at time: Double) -> Float {
        // TODO: Implement actual audio level detection
        // This would analyze the track's audio buffer and return RMS or peak level
        // For now, return a placeholder
        return 0.5
    }
}

// MARK: - Random Modulator

class RandomModulator: Modulator, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var value: Float = 0.0
    @Published var depth: Float = 1.0
    @Published var enabled: Bool = true

    // Random Parameters
    @Published var rate: Float = 1.0           // Updates per second
    @Published var smoothing: Float = 0.5      // 0 = stepped, 1 = smooth
    @Published var bipolar: Bool = true        // -1 to 1, or 0 to 1

    private var targetValue: Float = 0.0
    private var currentValue: Float = 0.0
    private var timeSinceUpdate: Float = 0.0
    private var lastTime: Double = 0.0

    init(name: String) {
        self.name = name
        generateNewTarget()
    }

    func update(time: Double, playing: Bool) {
        guard enabled else {
            value = 0.0
            return
        }

        let dt = playing ? Float(time - lastTime) : 0.0
        lastTime = time

        timeSinceUpdate += dt

        // Check if it's time to generate new target
        let updateInterval = 1.0 / max(rate, 0.1)
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0.0
            generateNewTarget()
        }

        // Interpolate towards target based on smoothing
        if smoothing > 0 {
            let smoothRate = smoothing * 10.0 // Adjust smoothing speed
            currentValue += (targetValue - currentValue) * min(dt * smoothRate, 1.0)
        } else {
            currentValue = targetValue
        }

        // Apply depth
        value = currentValue * depth
    }

    func reset() {
        generateNewTarget()
        currentValue = targetValue
        timeSinceUpdate = 0.0
        lastTime = 0.0
    }

    private func generateNewTarget() {
        if bipolar {
            targetValue = Float.random(in: -1...1)
        } else {
            targetValue = Float.random(in: 0...1)
        }
    }
}

// MARK: - Macro Control

class MacroControl: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var value: Float = 0.0          // 0-1
    @Published var mappings: [ParameterMapping] = []

    init(name: String) {
        self.name = name
    }

    func addMapping(_ mapping: ParameterMapping) {
        mappings.append(mapping)
    }

    func removeMapping(_ id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    func update() {
        // Update all mapped parameters
        for mapping in mappings {
            mapping.apply(macroValue: value)
        }
    }
}

// MARK: - Parameter Mapping

class ParameterMapping: ObservableObject, Identifiable {
    let id = UUID()
    @Published var target: ParameterTarget
    @Published var range: ClosedRange<Float>
    @Published var curve: MappingCurve = .linear

    enum ParameterTarget {
        case trackVolume(Track)
        case trackPan(Track)
        case effectParameter(effect: String, parameter: String)
        case clipGain(Clip)
        // Add more as needed
    }

    enum MappingCurve {
        case linear
        case exponential
        case logarithmic
        case sCurve

        func apply(value: Float) -> Float {
            switch self {
            case .linear:
                return value

            case .exponential:
                return value * value

            case .logarithmic:
                return sqrt(value)

            case .sCurve:
                // Sigmoid-like curve
                let x = value * 2.0 - 1.0
                return (x * x * x + x) / 2.0 + 0.5
            }
        }
    }

    init(target: ParameterTarget, range: ClosedRange<Float>) {
        self.target = target
        self.range = range
    }

    func apply(macroValue: Float) {
        // Apply curve
        let curvedValue = curve.apply(value: macroValue)

        // Map to range
        let mappedValue = range.lowerBound + curvedValue * (range.upperBound - range.lowerBound)

        // Apply to target
        switch target {
        case .trackVolume(let track):
            track.volume = mappedValue

        case .trackPan(let track):
            track.pan = mappedValue

        case .clipGain(let clip):
            clip.gain = mappedValue

        case .effectParameter:
            // TODO: Implement effect parameter mapping
            break
        }
    }
}

// MARK: - Automation Envelope (Extended from Timeline)

extension AutomationEnvelope {
    /// Evaluates automation at given time with modulation
    func evaluateWithModulation(at time: Int64, modulator: Modulator?) -> Float {
        // Get base automation value
        let baseValue = evaluate(at: time)

        // Apply modulation if present
        guard let mod = modulator, mod.enabled else {
            return baseValue
        }

        // Modulation adds to base value (could also multiply, etc.)
        let modulatedValue = baseValue + mod.value

        // Clamp to parameter range
        return max(0.0, min(1.0, modulatedValue))
    }
}

// MARK: - Automation Recording

class AutomationRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordMode: RecordMode = .overwrite

    private var recordedPoints: [AutomationPoint] = []
    private var targetEnvelope: AutomationEnvelope?

    enum RecordMode {
        case overwrite      // Replace existing automation
        case latch          // Write while playing, latch on stop
        case touch          // Write only when touching parameter
        case add            // Add to existing automation
    }

    func startRecording(envelope: AutomationEnvelope) {
        isRecording = true
        targetEnvelope = envelope
        recordedPoints.removeAll()

        if recordMode == .overwrite {
            envelope.points.removeAll()
        }
    }

    func stopRecording() {
        isRecording = false

        // Apply recorded points to envelope
        if let envelope = targetEnvelope {
            switch recordMode {
            case .overwrite:
                envelope.points = recordedPoints

            case .latch, .touch:
                envelope.points.append(contentsOf: recordedPoints)
                envelope.points.sort { $0.time < $1.time }

            case .add:
                // Merge with existing automation
                for point in recordedPoints {
                    if let existingIndex = envelope.points.firstIndex(where: { $0.time == point.time }) {
                        envelope.points[existingIndex].value += point.value
                    } else {
                        envelope.points.append(point)
                    }
                }
                envelope.points.sort { $0.time < $1.time }
            }
        }

        recordedPoints.removeAll()
        targetEnvelope = nil
    }

    func recordPoint(time: Int64, value: Float) {
        guard isRecording else { return }
        recordedPoints.append(AutomationPoint(time: time, value: value))
    }
}

// MARK: - Preset System

struct AutomationPreset: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: Category
    let modulators: [ModulatorData]
    let macros: [MacroData]
    let createdAt: Date

    enum Category: String, Codable {
        case rhythmic, ambient, evolving, reactive, creative
    }

    struct ModulatorData: Codable {
        let type: String // "LFO", "EnvelopeFollower", "Random"
        let name: String
        let parameters: [String: Float]
    }

    struct MacroData: Codable {
        let name: String
        let mappings: [MappingData]
    }

    struct MappingData: Codable {
        let targetType: String
        let rangeMin: Float
        let rangeMax: Float
        let curve: String
    }
}

class AutomationPresetManager: ObservableObject {
    @Published var presets: [AutomationPreset] = []
    @Published var currentPreset: AutomationPreset?

    private let presetsURL: URL

    init() {
        // Get presets directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        presetsURL = documentsURL.appendingPathComponent("AutomationPresets")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: presetsURL, withIntermediateDirectories: true)

        loadPresets()
        createFactoryPresets()
    }

    func savePreset(name: String, category: AutomationPreset.Category, engine: AutomationEngine) {
        // Convert current engine state to preset data
        var modulatorData: [AutomationPreset.ModulatorData] = []

        for modulator in engine.modulators {
            if let lfo = modulator as? LFOModulator {
                modulatorData.append(AutomationPreset.ModulatorData(
                    type: "LFO",
                    name: lfo.name,
                    parameters: [
                        "rate": lfo.rate,
                        "depth": lfo.depth,
                        "phase": lfo.phase,
                        "waveform": Float(LFOModulator.Waveform.allCases.firstIndex(of: lfo.waveform) ?? 0)
                    ]
                ))
            }
            // Add more modulator types...
        }

        let preset = AutomationPreset(
            id: UUID(),
            name: name,
            category: category,
            modulators: modulatorData,
            macros: [],
            createdAt: Date()
        )

        presets.append(preset)
        savePresets()
    }

    func loadPreset(_ preset: AutomationPreset, into engine: AutomationEngine) {
        // Clear existing
        engine.modulators.removeAll()
        engine.macros.removeAll()

        // Create modulators from preset
        for data in preset.modulators {
            switch data.type {
            case "LFO":
                let lfo = engine.createLFO(name: data.name)
                lfo.rate = data.parameters["rate"] ?? 1.0
                lfo.depth = data.parameters["depth"] ?? 1.0
                lfo.phase = data.parameters["phase"] ?? 0.0

            default:
                break
            }
        }

        currentPreset = preset
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }

    private func loadPresets() {
        // Load presets from disk
        // TODO: Implement file-based preset loading
    }

    private func savePresets() {
        // Save presets to disk
        // TODO: Implement file-based preset saving
    }

    private func createFactoryPresets() {
        // Create some default presets if none exist
        if presets.isEmpty {
            // TODO: Add factory presets
        }
    }
}
