import Foundation
import SwiftUI
import Combine

// MARK: - Keyboard Configuration System
/// Comprehensive parameter configuration with automation, bio-reactivity, and presets
/// Designed for professional music production with neuro-quantum consciousness integration

// MARK: - Main Configuration Hub

@MainActor
public final class KeyboardConfigurationHub: ObservableObject {

    // MARK: - Singleton
    public static let shared = KeyboardConfigurationHub()

    // MARK: - Published Configuration
    @Published public var touchConfig = TouchConfiguration()
    @Published public var expressionConfig = ExpressionConfiguration()
    @Published public var mpeConfig = MPEConfiguration()
    @Published public var visualConfig = VisualConfiguration()
    @Published public var automationConfig = AutomationConfiguration()
    @Published public var bioConfig = BioReactiveConfiguration()
    @Published public var neuroConfig = NeuroQuantumConfiguration()
    @Published public var presets: [KeyboardPreset] = KeyboardPreset.defaults

    // MARK: - Active Preset
    @Published public var activePreset: KeyboardPreset?

    // MARK: - Automation State
    @Published public var automationEngines: [ParameterAutomation] = []
    @Published public var isAutomationEnabled: Bool = true

    // MARK: - Bio Input
    @Published public var currentHRV: Double = 50.0
    @Published public var currentHeartRate: Double = 72.0
    @Published public var currentCoherence: Double = 0.5
    @Published public var currentBreathRate: Double = 12.0

    // MARK: - Neuro State
    @Published public var brainwaveState: BrainwaveState = .alpha
    @Published public var consciousnessLevel: Double = 0.5
    @Published public var flowState: Double = 0.0

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBioReactiveBindings()
        setupAutomationTimer()
        EchoelLogger.success("KeyboardConfigurationHub initialized", category: EchoelLogger.midi)
    }

    // MARK: - Bio-Reactive Bindings
    private func setupBioReactiveBindings() {
        // HRV → Expression sensitivity
        $currentHRV
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] hrv in
                guard let self = self, self.bioConfig.hrvToExpressionEnabled else { return }
                let sensitivity = self.mapHRVToSensitivity(hrv)
                self.expressionConfig.pitchBendSensitivity = sensitivity
            }
            .store(in: &cancellables)

        // Heart Rate → Tempo/Feel
        $currentHeartRate
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] hr in
                guard let self = self, self.bioConfig.heartRateToTempoEnabled else { return }
                self.bioConfig.suggestedTempo = hr
            }
            .store(in: &cancellables)

        // Coherence → Visual feedback intensity
        $currentCoherence
            .sink { [weak self] coherence in
                guard let self = self, self.bioConfig.coherenceToVisualsEnabled else { return }
                self.visualConfig.feedbackIntensity = Float(coherence)
            }
            .store(in: &cancellables)
    }

    private func mapHRVToSensitivity(_ hrv: Double) -> Float {
        // Higher HRV = more relaxed = smoother expression
        // Lower HRV = more stressed = more responsive
        let normalized = (hrv - 20) / 80 // Normalize 20-100ms range
        return Float(0.5 + normalized * 0.5).clamped(0.3, 1.0)
    }

    // MARK: - Automation Timer
    private var automationTimer: Timer?

    private func setupAutomationTimer() {
        automationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAutomation()
            }
        }
    }

    private func updateAutomation() {
        guard isAutomationEnabled else { return }

        for automation in automationEngines where automation.isActive {
            let value = automation.currentValue
            applyAutomationValue(automation.targetParameter, value: value)
        }
    }

    private func applyAutomationValue(_ parameter: AutomatableParameter, value: Float) {
        switch parameter {
        case .pitchBendRange:
            expressionConfig.pitchBendRange = Int(value * 48)
        case .velocitySensitivity:
            touchConfig.velocitySensitivity = value
        case .aftertouch:
            expressionConfig.aftertouchSensitivity = value
        case .brightness:
            expressionConfig.defaultBrightness = value
        case .visualIntensity:
            visualConfig.feedbackIntensity = value
        case .keySize:
            touchConfig.keyWidthMultiplier = value
        }
    }

    // MARK: - Preset Management
    public func loadPreset(_ preset: KeyboardPreset) {
        touchConfig = preset.touchConfig
        expressionConfig = preset.expressionConfig
        mpeConfig = preset.mpeConfig
        visualConfig = preset.visualConfig
        activePreset = preset
        EchoelLogger.log("🎹", "Loaded preset: \(preset.name)", category: EchoelLogger.midi)
    }

    public func saveCurrentAsPreset(name: String) -> KeyboardPreset {
        let preset = KeyboardPreset(
            id: UUID(),
            name: name,
            touchConfig: touchConfig,
            expressionConfig: expressionConfig,
            mpeConfig: mpeConfig,
            visualConfig: visualConfig
        )
        presets.append(preset)
        return preset
    }
}

// MARK: - Touch Configuration

public struct TouchConfiguration: Codable, Equatable {
    // Key dimensions
    public var keyWidthMultiplier: Float = 1.0 // 0.5 - 2.0
    public var keyHeightMultiplier: Float = 1.0
    public var blackKeyRatio: Float = 0.6 // Black key width relative to white
    public var blackKeyHeightRatio: Float = 0.6

    // Velocity
    public var velocitySensitivity: Float = 1.0 // 0.0 = fixed, 1.0 = full range
    public var velocityCurve: VelocityCurveType = .linear
    public var fixedVelocity: Float = 0.8 // Used when sensitivity = 0
    public var velocityMin: Float = 0.1
    public var velocityMax: Float = 1.0

    // Touch response
    public var touchAreaExpansion: Float = 0.0 // Expand touch area for easier playing
    public var multiTouchEnabled: Bool = true
    public var maxSimultaneousTouches: Int = 15

    // Haptics
    public var hapticEnabled: Bool = true
    public var hapticIntensity: Float = 0.7
    public var hapticSharpness: Float = 0.5

    public enum VelocityCurveType: String, Codable, CaseIterable, Identifiable {
        case linear = "Linear"
        case soft = "Soft"
        case hard = "Hard"
        case sCurve = "S-Curve"
        case logarithmic = "Logarithmic"
        case exponential = "Exponential"

        public var id: String { rawValue }

        public func apply(_ input: Float) -> Float {
            switch self {
            case .linear: return input
            case .soft: return pow(input, 0.5)
            case .hard: return pow(input, 2.0)
            case .sCurve: return input * input * (3 - 2 * input)
            case .logarithmic: return log10(1 + input * 9) / log10(10)
            case .exponential: return (pow(2, input) - 1)
            }
        }
    }
}

// MARK: - Expression Configuration

public struct ExpressionConfiguration: Codable, Equatable {
    // Pitch Bend
    public var pitchBendEnabled: Bool = true
    public var pitchBendRange: Int = 48 // Semitones (±)
    public var pitchBendSensitivity: Float = 1.0
    public var pitchBendCurve: CurveType = .linear
    public var pitchBendSmoothing: Float = 0.1 // 0 = instant, 1 = very smooth

    // Aftertouch / Pressure
    public var aftertouchEnabled: Bool = true
    public var aftertouchSensitivity: Float = 1.0
    public var aftertouchThreshold: Float = 0.1
    public var aftertouchCurve: CurveType = .linear

    // Brightness (CC74)
    public var brightnessEnabled: Bool = true
    public var defaultBrightness: Float = 0.5
    public var brightnessSensitivity: Float = 1.0

    // Timbre (CC71)
    public var timbreEnabled: Bool = true
    public var defaultTimbre: Float = 0.5

    // Modulation
    public var modulationEnabled: Bool = true
    public var modulationSensitivity: Float = 1.0

    // Expression zones
    public var expressionZoneHeight: Float = 30.0 // Pixels
    public var slideToExpressionEnabled: Bool = true
    public var verticalExpressionAxis: ExpressionAxis = .pitchBend
    public var horizontalExpressionAxis: ExpressionAxis = .brightness

    public enum CurveType: String, Codable, CaseIterable, Identifiable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case sCurve = "S-Curve"

        public var id: String { rawValue }
    }

    public enum ExpressionAxis: String, Codable, CaseIterable, Identifiable {
        case pitchBend = "Pitch Bend"
        case brightness = "Brightness"
        case pressure = "Pressure"
        case timbre = "Timbre"
        case modulation = "Modulation"
        case none = "None"

        public var id: String { rawValue }
    }
}

// MARK: - MPE Configuration

public struct MPEConfiguration: Codable, Equatable {
    public var mpeEnabled: Bool = true
    public var memberChannels: Int = 15 // 1-15
    public var masterChannel: Int = 0 // 0 or 15
    public var pitchBendRange: Int = 48

    // Voice allocation
    public var voiceAllocationMode: VoiceAllocationMode = .roundRobin
    public var voiceStealingEnabled: Bool = true
    public var voiceStealingMode: VoiceStealingMode = .oldest

    // Per-note expression
    public var perNotePitchBendEnabled: Bool = true
    public var perNotePressureEnabled: Bool = true
    public var perNoteBrightnessEnabled: Bool = true

    public enum VoiceAllocationMode: String, Codable, CaseIterable, Identifiable {
        case roundRobin = "Round Robin"
        case lowestAvailable = "Lowest Available"
        case highestAvailable = "Highest Available"
        case leastRecentlyUsed = "LRU"

        public var id: String { rawValue }
    }

    public enum VoiceStealingMode: String, Codable, CaseIterable, Identifiable {
        case oldest = "Oldest"
        case quietest = "Quietest"
        case lowest = "Lowest Note"
        case highest = "Highest Note"

        public var id: String { rawValue }
    }
}

// MARK: - Visual Configuration

public struct VisualConfiguration: Codable, Equatable {
    // Colors
    public var whiteKeyColor: String = "#FFFFFF"
    public var blackKeyColor: String = "#2C2C2C"
    public var pressedKeyColor: String = "#4A90D9"
    public var expressionIndicatorColor: String = "#00FF88"

    // Feedback
    public var feedbackIntensity: Float = 0.8
    public var showPitchBendIndicator: Bool = true
    public var showPressureIndicator: Bool = true
    public var showNoteNames: Bool = true
    public var showOctaveIndicator: Bool = true
    public var showVelocityFeedback: Bool = true

    // Animation
    public var keyPressAnimation: Bool = true
    public var keyPressScale: Float = 0.95
    public var animationDuration: Float = 0.1

    // Theme
    public var theme: KeyboardTheme = .default

    public enum KeyboardTheme: String, Codable, CaseIterable, Identifiable {
        case `default` = "Default"
        case dark = "Dark"
        case ocean = "Ocean"
        case sunset = "Sunset"
        case forest = "Forest"
        case cosmic = "Cosmic"
        case bioReactive = "Bio-Reactive"
        case neuro = "Neuro"

        public var id: String { rawValue }
    }
}

// MARK: - Automation Configuration

public struct AutomationConfiguration: Codable, Equatable {
    public var automationEnabled: Bool = true
    public var midiLearnEnabled: Bool = true
    public var lfoEnabled: Bool = false
    public var envelopeEnabled: Bool = false

    // LFO settings
    public var lfoRate: Float = 1.0 // Hz
    public var lfoDepth: Float = 0.5
    public var lfoWaveform: LFOWaveform = .sine

    // Envelope settings
    public var attack: Float = 0.01
    public var decay: Float = 0.1
    public var sustain: Float = 0.7
    public var release: Float = 0.3

    public enum LFOWaveform: String, Codable, CaseIterable, Identifiable {
        case sine = "Sine"
        case triangle = "Triangle"
        case square = "Square"
        case sawtooth = "Sawtooth"
        case random = "Random"

        public var id: String { rawValue }
    }
}

// MARK: - Bio-Reactive Configuration

public struct BioReactiveConfiguration: Codable, Equatable {
    public var bioReactiveEnabled: Bool = true

    // HRV mapping
    public var hrvToExpressionEnabled: Bool = true
    public var hrvSensitivity: Float = 1.0
    public var hrvSmoothing: Float = 0.3

    // Heart Rate mapping
    public var heartRateToTempoEnabled: Bool = false
    public var heartRateToVelocityEnabled: Bool = false
    public var suggestedTempo: Double = 120.0

    // Coherence mapping
    public var coherenceToVisualsEnabled: Bool = true
    public var coherenceToHarmonicsEnabled: Bool = false
    public var coherenceThreshold: Float = 0.5

    // Breath mapping
    public var breathToExpressionEnabled: Bool = false
    public var breathToPitchEnabled: Bool = false

    // Healing mode
    public var healingModeEnabled: Bool = false
    public var healingFrequency: HealingFrequency = .love528

    public enum HealingFrequency: String, Codable, CaseIterable, Identifiable {
        case liberation396 = "396 Hz - Liberation"
        case transformation417 = "417 Hz - Transformation"
        case love528 = "528 Hz - Love/DNA Repair"
        case connection639 = "639 Hz - Connection"
        case expression741 = "741 Hz - Expression"
        case intuition852 = "852 Hz - Intuition"
        case unity963 = "963 Hz - Unity"

        public var id: String { rawValue }

        public var frequency: Double {
            switch self {
            case .liberation396: return 396.0
            case .transformation417: return 417.0
            case .love528: return 528.0
            case .connection639: return 639.0
            case .expression741: return 741.0
            case .intuition852: return 852.0
            case .unity963: return 963.0
            }
        }
    }
}

// MARK: - Neuro-Quantum Configuration

public struct NeuroQuantumConfiguration: Codable, Equatable {
    public var neuroModeEnabled: Bool = false

    // Brainwave entrainment
    public var brainwaveEntrainmentEnabled: Bool = false
    public var targetBrainwave: BrainwaveState = .alpha

    // Consciousness mapping
    public var consciousnessToScaleEnabled: Bool = false
    public var consciousnessToHarmonyEnabled: Bool = false

    // Flow state
    public var flowStateDetectionEnabled: Bool = false
    public var flowStateThreshold: Float = 0.7

    // Quantum randomness
    public var quantumRandomnessEnabled: Bool = false
    public var quantumInfluence: Float = 0.1

    // Intention setting
    public var intentionModeEnabled: Bool = false
    public var currentIntention: MusicalIntention = .creativity
}

// MARK: - Brainwave State

public enum BrainwaveState: String, Codable, CaseIterable, Identifiable {
    case delta = "Delta (0.5-4 Hz) - Deep Sleep"
    case theta = "Theta (4-8 Hz) - Meditation"
    case alpha = "Alpha (8-12 Hz) - Relaxation"
    case beta = "Beta (12-30 Hz) - Focus"
    case gamma = "Gamma (30-100 Hz) - Insight"

    public var id: String { rawValue }

    public var frequencyRange: ClosedRange<Double> {
        switch self {
        case .delta: return 0.5...4.0
        case .theta: return 4.0...8.0
        case .alpha: return 8.0...12.0
        case .beta: return 12.0...30.0
        case .gamma: return 30.0...100.0
        }
    }

    public var suggestedTempo: Double {
        switch self {
        case .delta: return 60
        case .theta: return 72
        case .alpha: return 90
        case .beta: return 120
        case .gamma: return 140
        }
    }

    public var suggestedScale: String {
        switch self {
        case .delta: return "Pentatonic Minor"
        case .theta: return "Lydian"
        case .alpha: return "Major"
        case .beta: return "Mixolydian"
        case .gamma: return "Chromatic"
        }
    }
}

// MARK: - Musical Intention

public enum MusicalIntention: String, Codable, CaseIterable, Identifiable {
    case creativity = "Creativity"
    case relaxation = "Relaxation"
    case focus = "Focus"
    case healing = "Healing"
    case joy = "Joy"
    case meditation = "Meditation"
    case energy = "Energy"
    case love = "Love"
    case transformation = "Transformation"

    public var id: String { rawValue }

    public var suggestedMode: String {
        switch self {
        case .creativity: return "Lydian"
        case .relaxation: return "Major Pentatonic"
        case .focus: return "Dorian"
        case .healing: return "Ionian (528Hz tuning)"
        case .joy: return "Major"
        case .meditation: return "Whole Tone"
        case .energy: return "Mixolydian"
        case .love: return "Lydian"
        case .transformation: return "Harmonic Minor"
        }
    }
}

// MARK: - Automatable Parameter

public enum AutomatableParameter: String, Codable, CaseIterable, Identifiable {
    case pitchBendRange = "Pitch Bend Range"
    case velocitySensitivity = "Velocity Sensitivity"
    case aftertouch = "Aftertouch"
    case brightness = "Brightness"
    case visualIntensity = "Visual Intensity"
    case keySize = "Key Size"

    public var id: String { rawValue }

    public var range: ClosedRange<Float> {
        switch self {
        case .pitchBendRange: return 0...1 // Maps to 0-48 semitones
        case .velocitySensitivity: return 0...1
        case .aftertouch: return 0...1
        case .brightness: return 0...1
        case .visualIntensity: return 0...1
        case .keySize: return 0.5...2.0
        }
    }
}

// MARK: - Parameter Automation

public class ParameterAutomation: ObservableObject, Identifiable {
    public let id = UUID()
    public var targetParameter: AutomatableParameter
    public var isActive: Bool = false

    @Published public var lfoRate: Float = 1.0
    @Published public var lfoDepth: Float = 0.5
    @Published public var waveform: AutomationConfiguration.LFOWaveform = .sine

    private var phase: Float = 0
    private var lastUpdateTime: Date = Date()

    public init(target: AutomatableParameter) {
        self.targetParameter = target
    }

    public var currentValue: Float {
        let now = Date()
        let elapsed = Float(now.timeIntervalSince(lastUpdateTime))
        lastUpdateTime = now

        phase += elapsed * lfoRate * 2 * .pi
        if phase > 2 * .pi { phase -= 2 * .pi }

        let lfoValue: Float
        switch waveform {
        case .sine:
            lfoValue = sin(phase)
        case .triangle:
            lfoValue = 2 * abs(phase / .pi - 1) - 1
        case .square:
            lfoValue = phase < .pi ? 1 : -1
        case .sawtooth:
            lfoValue = phase / .pi - 1
        case .random:
            lfoValue = Float.random(in: -1...1)
        }

        let range = targetParameter.range
        let center = (range.upperBound + range.lowerBound) / 2
        let amplitude = (range.upperBound - range.lowerBound) / 2 * lfoDepth

        return center + lfoValue * amplitude
    }
}

// MARK: - Keyboard Preset

public struct KeyboardPreset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var touchConfig: TouchConfiguration
    public var expressionConfig: ExpressionConfiguration
    public var mpeConfig: MPEConfiguration
    public var visualConfig: VisualConfiguration

    public static let defaults: [KeyboardPreset] = [
        .init(
            id: UUID(),
            name: "Default",
            touchConfig: TouchConfiguration(),
            expressionConfig: ExpressionConfiguration(),
            mpeConfig: MPEConfiguration(),
            visualConfig: VisualConfiguration()
        ),
        .init(
            id: UUID(),
            name: "MPE Expressive",
            touchConfig: TouchConfiguration(velocitySensitivity: 1.0, velocityCurve: .sCurve),
            expressionConfig: ExpressionConfiguration(pitchBendRange: 48, aftertouchSensitivity: 1.0),
            mpeConfig: MPEConfiguration(mpeEnabled: true, memberChannels: 15),
            visualConfig: VisualConfiguration(feedbackIntensity: 1.0)
        ),
        .init(
            id: UUID(),
            name: "Soft Piano",
            touchConfig: TouchConfiguration(velocitySensitivity: 0.8, velocityCurve: .soft),
            expressionConfig: ExpressionConfiguration(pitchBendEnabled: false, aftertouchEnabled: true),
            mpeConfig: MPEConfiguration(mpeEnabled: false),
            visualConfig: VisualConfiguration(theme: .default)
        ),
        .init(
            id: UUID(),
            name: "Synth Lead",
            touchConfig: TouchConfiguration(velocitySensitivity: 0.6, velocityCurve: .hard),
            expressionConfig: ExpressionConfiguration(pitchBendRange: 12, brightnessEnabled: true),
            mpeConfig: MPEConfiguration(mpeEnabled: true, memberChannels: 8),
            visualConfig: VisualConfiguration(theme: .cosmic)
        ),
        .init(
            id: UUID(),
            name: "Meditation",
            touchConfig: TouchConfiguration(velocitySensitivity: 0.4, velocityCurve: .soft, hapticIntensity: 0.3),
            expressionConfig: ExpressionConfiguration(pitchBendEnabled: false),
            mpeConfig: MPEConfiguration(mpeEnabled: false),
            visualConfig: VisualConfiguration(theme: .ocean, feedbackIntensity: 0.5)
        ),
        .init(
            id: UUID(),
            name: "Bio-Reactive",
            touchConfig: TouchConfiguration(velocitySensitivity: 1.0),
            expressionConfig: ExpressionConfiguration(pitchBendRange: 24),
            mpeConfig: MPEConfiguration(mpeEnabled: true),
            visualConfig: VisualConfiguration(theme: .bioReactive, feedbackIntensity: 1.0)
        )
    ]
}

// MARK: - Float Clamped Extension

private extension Float {
    func clamped(_ min: Float, _ max: Float) -> Float {
        Swift.min(Swift.max(self, min), max)
    }
}
