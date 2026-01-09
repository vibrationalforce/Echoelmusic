// VisualMethodMapper.swift
// Echoelmusic - Visual Method Mapping System
//
// Inspired by nw_wrld's method assignment concept
// Maps bio-signals and sequencer triggers to visual parameters
//
// Features:
// - Declarative method mapping
// - Bio-signal to visual parameter binding
// - Sequencer trigger routing
// - Real-time parameter modulation
//
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine

// MARK: - Visual Method Mapper

/// Maps input signals to visual module methods
@MainActor
public final class VisualMethodMapper: ObservableObject {

    // MARK: - Singleton

    public static let shared = VisualMethodMapper()

    // MARK: - Published State

    @Published public var mappings: [MethodMapping] = []
    @Published public var activeModules: [VisualModule] = []

    // MARK: - Available Methods

    /// Visual methods that can be triggered or modulated
    public enum VisualMethod: String, CaseIterable, Identifiable, Codable {
        // Visibility
        case show = "show"
        case hide = "hide"
        case opacity = "opacity"

        // Transform
        case scale = "scale"
        case rotate = "rotate"
        case offset = "offset"

        // Animation
        case pulse = "pulse"
        case breathe = "breathe"
        case randomZoom = "randomZoom"

        // Color
        case hue = "hue"
        case saturation = "saturation"
        case brightness = "brightness"
        case colorShift = "colorShift"

        // Geometry
        case complexity = "complexity"
        case density = "density"
        case symmetry = "symmetry"

        // Particle
        case particleCount = "particleCount"
        case particleSpeed = "particleSpeed"
        case particleSize = "particleSize"

        // 3D
        case cameraDistance = "cameraDistance"
        case cameraRotation = "cameraRotation"
        case fieldOfView = "fieldOfView"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .show: return "Show"
            case .hide: return "Hide"
            case .opacity: return "Opacity"
            case .scale: return "Scale"
            case .rotate: return "Rotate"
            case .offset: return "Offset"
            case .pulse: return "Pulse"
            case .breathe: return "Breathe"
            case .randomZoom: return "Random Zoom"
            case .hue: return "Hue"
            case .saturation: return "Saturation"
            case .brightness: return "Brightness"
            case .colorShift: return "Color Shift"
            case .complexity: return "Complexity"
            case .density: return "Density"
            case .symmetry: return "Symmetry"
            case .particleCount: return "Particle Count"
            case .particleSpeed: return "Particle Speed"
            case .particleSize: return "Particle Size"
            case .cameraDistance: return "Camera Distance"
            case .cameraRotation: return "Camera Rotation"
            case .fieldOfView: return "Field of View"
            }
        }

        public var isTrigger: Bool {
            switch self {
            case .show, .hide, .pulse, .randomZoom:
                return true
            default:
                return false
            }
        }

        public var isContinuous: Bool {
            !isTrigger
        }

        public var category: MethodCategory {
            switch self {
            case .show, .hide, .opacity:
                return .visibility
            case .scale, .rotate, .offset:
                return .transform
            case .pulse, .breathe, .randomZoom:
                return .animation
            case .hue, .saturation, .brightness, .colorShift:
                return .color
            case .complexity, .density, .symmetry:
                return .geometry
            case .particleCount, .particleSpeed, .particleSize:
                return .particle
            case .cameraDistance, .cameraRotation, .fieldOfView:
                return .camera
            }
        }
    }

    public enum MethodCategory: String, CaseIterable {
        case visibility = "Visibility"
        case transform = "Transform"
        case animation = "Animation"
        case color = "Color"
        case geometry = "Geometry"
        case particle = "Particle"
        case camera = "3D Camera"
    }

    // MARK: - Input Sources

    /// Sources that can drive visual methods
    public enum InputSource: String, CaseIterable, Identifiable, Codable {
        // Bio Signals (Continuous)
        case heartRate = "heartRate"
        case hrvCoherence = "hrvCoherence"
        case hrvVariability = "hrvVariability"
        case breathingRate = "breathingRate"
        case breathingPhase = "breathingPhase"

        // Sequencer (Trigger)
        case sequencerChannel1 = "seqCh1"
        case sequencerChannel2 = "seqCh2"
        case sequencerChannel3 = "seqCh3"
        case sequencerChannel4 = "seqCh4"
        case sequencerChannel5 = "seqCh5"
        case sequencerChannel6 = "seqCh6"
        case sequencerChannel7 = "seqCh7"
        case sequencerChannel8 = "seqCh8"

        // Audio Analysis
        case audioLevel = "audioLevel"
        case audioBass = "audioBass"
        case audioMid = "audioMid"
        case audioHigh = "audioHigh"
        case audioBeatDetect = "audioBeat"

        // MIDI
        case midiNote = "midiNote"
        case midiVelocity = "midiVelocity"
        case midiCC = "midiCC"
        case midiPitchBend = "midiPitchBend"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .heartRate: return "Heart Rate"
            case .hrvCoherence: return "HRV Coherence"
            case .hrvVariability: return "HRV Variability"
            case .breathingRate: return "Breathing Rate"
            case .breathingPhase: return "Breathing Phase"
            case .sequencerChannel1: return "Seq Ch 1"
            case .sequencerChannel2: return "Seq Ch 2"
            case .sequencerChannel3: return "Seq Ch 3"
            case .sequencerChannel4: return "Seq Ch 4"
            case .sequencerChannel5: return "Seq Ch 5"
            case .sequencerChannel6: return "Seq Ch 6"
            case .sequencerChannel7: return "Seq Ch 7"
            case .sequencerChannel8: return "Seq Ch 8"
            case .audioLevel: return "Audio Level"
            case .audioBass: return "Bass"
            case .audioMid: return "Mid"
            case .audioHigh: return "High"
            case .audioBeatDetect: return "Beat Detect"
            case .midiNote: return "MIDI Note"
            case .midiVelocity: return "MIDI Velocity"
            case .midiCC: return "MIDI CC"
            case .midiPitchBend: return "Pitch Bend"
            }
        }

        public var isTrigger: Bool {
            switch self {
            case .audioBeatDetect, .midiNote:
                return true
            case .sequencerChannel1, .sequencerChannel2, .sequencerChannel3,
                 .sequencerChannel4, .sequencerChannel5, .sequencerChannel6,
                 .sequencerChannel7, .sequencerChannel8:
                return true
            default:
                return false
            }
        }

        public var category: SourceCategory {
            switch self {
            case .heartRate, .hrvCoherence, .hrvVariability, .breathingRate, .breathingPhase:
                return .bio
            case .sequencerChannel1, .sequencerChannel2, .sequencerChannel3,
                 .sequencerChannel4, .sequencerChannel5, .sequencerChannel6,
                 .sequencerChannel7, .sequencerChannel8:
                return .sequencer
            case .audioLevel, .audioBass, .audioMid, .audioHigh, .audioBeatDetect:
                return .audio
            case .midiNote, .midiVelocity, .midiCC, .midiPitchBend:
                return .midi
            }
        }
    }

    public enum SourceCategory: String, CaseIterable {
        case bio = "Bio Signals"
        case sequencer = "Sequencer"
        case audio = "Audio"
        case midi = "MIDI"
    }

    // MARK: - Mapping Configuration

    public struct MethodMapping: Identifiable, Codable {
        public let id: UUID
        public var source: InputSource
        public var method: VisualMethod
        public var targetModule: String
        public var enabled: Bool

        // Mapping curve
        public var inputMin: Float
        public var inputMax: Float
        public var outputMin: Float
        public var outputMax: Float
        public var curve: MappingCurve
        public var smoothing: Float

        public init(
            id: UUID = UUID(),
            source: InputSource,
            method: VisualMethod,
            targetModule: String = "default",
            enabled: Bool = true,
            inputMin: Float = 0.0,
            inputMax: Float = 1.0,
            outputMin: Float = 0.0,
            outputMax: Float = 1.0,
            curve: MappingCurve = .linear,
            smoothing: Float = 0.5
        ) {
            self.id = id
            self.source = source
            self.method = method
            self.targetModule = targetModule
            self.enabled = enabled
            self.inputMin = inputMin
            self.inputMax = inputMax
            self.outputMin = outputMin
            self.outputMax = outputMax
            self.curve = curve
            self.smoothing = smoothing
        }

        /// Apply mapping curve to input value
        public func apply(value: Float) -> Float {
            // Normalize input
            let normalized = (value - inputMin) / (inputMax - inputMin)
            let clamped = max(0, min(1, normalized))

            // Apply curve
            let curved = curve.apply(clamped)

            // Map to output range
            return outputMin + curved * (outputMax - outputMin)
        }
    }

    public enum MappingCurve: String, CaseIterable, Codable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case sCurve = "S-Curve"
        case sine = "Sine"
        case stepped = "Stepped"

        public func apply(_ value: Float) -> Float {
            switch self {
            case .linear:
                return value
            case .exponential:
                return value * value
            case .logarithmic:
                return sqrt(value)
            case .sCurve:
                return value * value * (3.0 - 2.0 * value)
            case .sine:
                return sin(value * .pi / 2)
            case .stepped:
                return floor(value * 4) / 4
            }
        }
    }

    // MARK: - Visual Module

    public struct VisualModule: Identifiable {
        public let id: String
        public let name: String
        public let category: String
        public var parameters: [String: Float]

        public init(id: String, name: String, category: String) {
            self.id = id
            self.name = name
            self.category = category
            self.parameters = [:]
        }
    }

    // MARK: - Initialization

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupSequencerListener()
        loadDefaultMappings()
    }

    private func setupSequencerListener() {
        NotificationCenter.default.publisher(for: .sequencerStepTriggered)
            .sink { [weak self] notification in
                self?.handleSequencerTrigger(notification)
            }
            .store(in: &cancellables)
    }

    private func handleSequencerTrigger(_ notification: Notification) {
        guard let channel = notification.userInfo?["channel"] as? VisualStepSequencer.Channel,
              let velocity = notification.userInfo?["velocity"] as? Float else { return }

        let source = sequencerChannelToSource(channel)
        triggerMappings(for: source, value: velocity)
    }

    private func sequencerChannelToSource(_ channel: VisualStepSequencer.Channel) -> InputSource {
        switch channel.rawValue {
        case 0: return .sequencerChannel1
        case 1: return .sequencerChannel2
        case 2: return .sequencerChannel3
        case 3: return .sequencerChannel4
        case 4: return .sequencerChannel5
        case 5: return .sequencerChannel6
        case 6: return .sequencerChannel7
        case 7: return .sequencerChannel8
        default: return .sequencerChannel1
        }
    }

    // MARK: - Mapping Management

    public func addMapping(_ mapping: MethodMapping) {
        mappings.append(mapping)
    }

    public func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    public func updateMapping(_ mapping: MethodMapping) {
        if let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
            mappings[index] = mapping
        }
    }

    // MARK: - Signal Processing

    public func processInput(source: InputSource, value: Float) {
        for mapping in mappings where mapping.source == source && mapping.enabled {
            let outputValue = mapping.apply(value: value)
            applyToModule(mapping: mapping, value: outputValue)
        }
    }

    private func triggerMappings(for source: InputSource, value: Float) {
        for mapping in mappings where mapping.source == source && mapping.enabled {
            let outputValue = mapping.apply(value: value)
            applyToModule(mapping: mapping, value: outputValue)
        }
    }

    private func applyToModule(mapping: MethodMapping, value: Float) {
        // Post notification for visual renderers to handle
        NotificationCenter.default.post(
            name: .visualMethodTriggered,
            object: nil,
            userInfo: [
                "method": mapping.method,
                "value": value,
                "module": mapping.targetModule
            ]
        )
    }

    // MARK: - Default Mappings

    private func loadDefaultMappings() {
        mappings = [
            // HRV Coherence → Opacity (high coherence = more visible)
            MethodMapping(
                source: .hrvCoherence,
                method: .opacity,
                outputMin: 0.3,
                outputMax: 1.0,
                curve: .sCurve
            ),

            // Breathing Phase → Scale (breathe animation)
            MethodMapping(
                source: .breathingPhase,
                method: .scale,
                outputMin: 0.9,
                outputMax: 1.1,
                curve: .sine
            ),

            // Audio Bass → Pulse
            MethodMapping(
                source: .audioBass,
                method: .pulse,
                curve: .exponential
            ),

            // Sequencer Ch1 → Show
            MethodMapping(
                source: .sequencerChannel1,
                method: .show
            )
        ]
    }

    // MARK: - Presets

    public static let mappingPresets: [String: [MethodMapping]] = [
        "Meditation": [
            MethodMapping(source: .hrvCoherence, method: .opacity, outputMin: 0.2, outputMax: 1.0),
            MethodMapping(source: .breathingPhase, method: .scale, outputMin: 0.95, outputMax: 1.05, curve: .sine),
            MethodMapping(source: .heartRate, method: .hue, outputMin: 0.5, outputMax: 0.7)
        ],
        "Performance": [
            MethodMapping(source: .audioBass, method: .pulse, curve: .exponential),
            MethodMapping(source: .audioMid, method: .colorShift),
            MethodMapping(source: .audioHigh, method: .particleSpeed),
            MethodMapping(source: .sequencerChannel1, method: .show),
            MethodMapping(source: .sequencerChannel2, method: .hide)
        ],
        "Ambient": [
            MethodMapping(source: .hrvCoherence, method: .brightness, outputMin: 0.3, outputMax: 0.8, curve: .logarithmic),
            MethodMapping(source: .breathingPhase, method: .cameraDistance, outputMin: 2.0, outputMax: 5.0, curve: .sine),
            MethodMapping(source: .hrvVariability, method: .complexity, curve: .sCurve)
        ]
    ]

    public func loadPreset(_ name: String) {
        if let preset = Self.mappingPresets[name] {
            mappings = preset
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let visualMethodTriggered = Notification.Name("visualMethodTriggered")
}

// MARK: - SwiftUI View

public struct VisualMethodMapperView: View {
    @ObservedObject var mapper = VisualMethodMapper.shared

    @State private var selectedSource: VisualMethodMapper.InputSource = .hrvCoherence
    @State private var selectedMethod: VisualMethodMapper.VisualMethod = .opacity

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("METHOD MAPPER")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)

                Spacer()

                // Preset Menu
                Menu {
                    ForEach(Array(VisualMethodMapper.mappingPresets.keys), id: \.self) { name in
                        Button(name) {
                            mapper.loadPreset(name)
                        }
                    }
                } label: {
                    Text("Presets")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Active Mappings
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(mapper.mappings) { mapping in
                        MappingRow(mapping: mapping) {
                            mapper.removeMapping(id: mapping.id)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            // Add New Mapping
            HStack {
                Picker("Source", selection: $selectedSource) {
                    ForEach(VisualMethodMapper.InputSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)

                Picker("Method", selection: $selectedMethod) {
                    ForEach(VisualMethodMapper.VisualMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Button(action: {
                    let newMapping = VisualMethodMapper.MethodMapping(
                        source: selectedSource,
                        method: selectedMethod
                    )
                    mapper.addMapping(newMapping)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

struct MappingRow: View {
    let mapping: VisualMethodMapper.MethodMapping
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Source
            Text(mapping.source.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(sourceColor(mapping.source))
                .frame(width: 80, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(.gray)

            // Method
            Text(mapping.method.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)

            Spacer()

            // Curve indicator
            Text(mapping.curve.rawValue)
                .font(.system(size: 8))
                .foregroundColor(.gray)

            // Enable/Disable toggle
            Circle()
                .fill(mapping.enabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func sourceColor(_ source: VisualMethodMapper.InputSource) -> Color {
        switch source.category {
        case .bio: return .red
        case .sequencer: return .cyan
        case .audio: return .green
        case .midi: return .yellow
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VisualMethodMapperView_Previews: PreviewProvider {
    static var previews: some View {
        VisualMethodMapperView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif
