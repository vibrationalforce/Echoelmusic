// PresetSystem.swift
// Complete preset management system

import Foundation

// MARK: - Preset Model

public struct Preset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var visualization: VisualizationType
    public var audioMode: AudioMode
    public var binauralState: BinauralState
    public var baseFrequency: Float
    public var volume: Float
    public var icon: String
    public var colorHex: String
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        visualization: VisualizationType = .coherence,
        audioMode: AudioMode = .ambient,
        binauralState: BinauralState = .alpha,
        baseFrequency: Float = 440.0,
        volume: Float = 0.7,
        icon: String = "star",
        colorHex: String = "#3B82F6",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.visualization = visualization
        self.audioMode = audioMode
        self.binauralState = binauralState
        self.baseFrequency = baseFrequency
        self.volume = volume
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
    }

    // Codable support for enums
    enum CodingKeys: String, CodingKey {
        case id, name, visualization, audioMode, binauralState
        case baseFrequency, volume, icon, colorHex, isDefault
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        let vizRaw = try container.decode(String.self, forKey: .visualization)
        visualization = VisualizationType(rawValue: vizRaw) ?? .coherence

        let audioRaw = try container.decode(String.self, forKey: .audioMode)
        audioMode = AudioMode(rawValue: audioRaw) ?? .ambient

        let binauralRaw = try container.decode(String.self, forKey: .binauralState)
        binauralState = BinauralState(rawValue: binauralRaw) ?? .alpha

        baseFrequency = try container.decode(Float.self, forKey: .baseFrequency)
        volume = try container.decode(Float.self, forKey: .volume)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(visualization.rawValue, forKey: .visualization)
        try container.encode(audioMode.rawValue, forKey: .audioMode)
        try container.encode(binauralState.rawValue, forKey: .binauralState)
        try container.encode(baseFrequency, forKey: .baseFrequency)
        try container.encode(volume, forKey: .volume)
        try container.encode(icon, forKey: .icon)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(isDefault, forKey: .isDefault)
    }
}

// MARK: - Preset Manager

@MainActor
public final class PresetManager: ObservableObject {
    @Published public var presets: [Preset] = []
    @Published public var activePreset: Preset?

    private let storageKey = "echoelmusic_presets_v2"

    public init() {
        loadPresets()
    }

    // MARK: - Persistence

    public func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        } else {
            presets = DefaultPresets.all
            savePresets()
        }
    }

    public func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - CRUD Operations

    public func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }

    public func updatePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

    public func deletePreset(_ preset: Preset) {
        guard !preset.isDefault else { return }  // Can't delete defaults
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    public func resetToDefaults() {
        presets = DefaultPresets.all
        activePreset = nil
        savePresets()
    }

    // MARK: - Apply Preset

    public func applyPreset(_ preset: Preset) {
        activePreset = preset
    }
}

// MARK: - Default Presets

public enum DefaultPresets {
    public static let all: [Preset] = [
        // Meditation - Mandala + Binaural Theta
        Preset(
            name: "Meditation",
            visualization: .mandala,
            audioMode: .binaural,
            binauralState: .theta,
            baseFrequency: 220.0,  // A3 - warm, grounding
            volume: 0.5,
            icon: "leaf.fill",
            colorHex: "#10B981",
            isDefault: true
        ),

        // Focus - Particles + Binaural Beta
        Preset(
            name: "Focus",
            visualization: .particles,
            audioMode: .binaural,
            binauralState: .beta,
            baseFrequency: 440.0,  // A4 - standard concert pitch
            volume: 0.6,
            icon: "target",
            colorHex: "#3B82F6",
            isDefault: true
        ),

        // Relax - Coherence + Drone
        Preset(
            name: "Relax",
            visualization: .coherence,
            audioMode: .drone,
            binauralState: .alpha,
            baseFrequency: 329.628,  // E4 - warm, open
            volume: 0.5,
            icon: "moon.fill",
            colorHex: "#8B5CF6",
            isDefault: true
        ),

        // Energy - Waveform + Ambient
        Preset(
            name: "Energy",
            visualization: .waveform,
            audioMode: .ambient,
            binauralState: .gamma,
            baseFrequency: 659.255,  // E5 - bright, energetic
            volume: 0.7,
            icon: "bolt.fill",
            colorHex: "#F59E0B",
            isDefault: true
        ),

        // Sleep - Mandala + Binaural Delta
        Preset(
            name: "Sleep",
            visualization: .mandala,
            audioMode: .binaural,
            binauralState: .delta,
            baseFrequency: 130.813,  // C3 - deep, calming
            volume: 0.3,
            icon: "bed.double.fill",
            colorHex: "#6366F1",
            isDefault: true
        ),

        // Creative - Spectrum + Drone
        Preset(
            name: "Creative",
            visualization: .spectrum,
            audioMode: .drone,
            binauralState: .alpha,
            baseFrequency: 523.251,  // C5 - clear, centered
            volume: 0.6,
            icon: "paintpalette.fill",
            colorHex: "#EC4899",
            isDefault: true
        ),

        // Performance - Particles + Silence
        Preset(
            name: "Performance",
            visualization: .particles,
            audioMode: .silence,
            binauralState: .alpha,
            baseFrequency: 440.0,  // A4 - standard
            volume: 0.0,
            icon: "star.fill",
            colorHex: "#EF4444",
            isDefault: true
        ),

        // Breathwork - Coherence + Ambient
        Preset(
            name: "Breathwork",
            visualization: .coherence,
            audioMode: .ambient,
            binauralState: .alpha,
            baseFrequency: 261.626,  // C4 - middle C, natural center
            volume: 0.5,
            icon: "wind",
            colorHex: "#06B6D4",
            isDefault: true
        )
    ]
}
