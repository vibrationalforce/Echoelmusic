// =============================================================================
// ECHOELMUSIC - PRESET MANAGER
// =============================================================================
// Centralized preset management for all engines and features
// =============================================================================

import Foundation

/// Manages all presets across the Echoelmusic ecosystem
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public final class PresetManager: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = PresetManager()

    // MARK: - Properties

    private var userPresets: [String: Preset] = [:]
    private let userPresetsKey = "echoelmusic.user.presets"

    // MARK: - Preset Categories

    public enum Category: String, CaseIterable, Sendable {
        case bioReactive = "Bio-Reactive"
        case musical = "Musical"
        case visual = "Visual"
        case lighting = "Lighting"
        case streaming = "Streaming"
        case collaboration = "Collaboration"
        case quantum = "Quantum"
        case wellness = "Wellness"
    }

    // MARK: - Initialization

    private init() {
        loadUserPresets()
    }

    // MARK: - Preset Structure

    public struct Preset: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let category: String
        public let description: String
        public let parameters: [String: Double]
        public let isFactory: Bool
        public let createdAt: Date

        public init(
            id: String = UUID().uuidString,
            name: String,
            category: String,
            description: String,
            parameters: [String: Double],
            isFactory: Bool = false,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.description = description
            self.parameters = parameters
            self.isFactory = isFactory
            self.createdAt = createdAt
        }
    }

    // MARK: - Factory Presets

    public var factoryPresets: [Preset] {
        [
            // Bio-Reactive Presets
            Preset(
                id: "bio-meditation",
                name: "Deep Meditation",
                category: Category.bioReactive.rawValue,
                description: "Optimized for deep meditative states with HRV coherence tracking",
                parameters: ["coherenceTarget": 0.8, "breathingRate": 6.0, "visualIntensity": 0.3],
                isFactory: true
            ),
            Preset(
                id: "bio-focus",
                name: "Active Focus",
                category: Category.bioReactive.rawValue,
                description: "Enhanced focus mode with beta wave optimization",
                parameters: ["coherenceTarget": 0.6, "breathingRate": 12.0, "visualIntensity": 0.5],
                isFactory: true
            ),
            Preset(
                id: "bio-relax",
                name: "Relaxation",
                category: Category.bioReactive.rawValue,
                description: "Gentle relaxation with alpha wave enhancement",
                parameters: ["coherenceTarget": 0.7, "breathingRate": 8.0, "visualIntensity": 0.4],
                isFactory: true
            ),

            // Musical Presets
            Preset(
                id: "music-ambient",
                name: "Ambient Drone",
                category: Category.musical.rawValue,
                description: "Evolving ambient textures with bio-reactive modulation",
                parameters: ["filterCutoff": 0.3, "reverbMix": 0.7, "delayTime": 0.5],
                isFactory: true
            ),
            Preset(
                id: "music-techno",
                name: "Techno Minimal",
                category: Category.musical.rawValue,
                description: "Driving minimal techno with heart-synced kick",
                parameters: ["filterCutoff": 0.6, "reverbMix": 0.2, "drive": 0.4],
                isFactory: true
            ),

            // Quantum Presets
            Preset(
                id: "quantum-coherent",
                name: "Quantum Coherence",
                category: Category.quantum.rawValue,
                description: "Full quantum-inspired processing with bio-coupling",
                parameters: ["quantumCoherence": 0.9, "entanglementStrength": 0.7, "fieldGeometry": 1.0],
                isFactory: true
            ),
            Preset(
                id: "quantum-classical",
                name: "Classical Mode",
                category: Category.quantum.rawValue,
                description: "Standard processing without quantum effects",
                parameters: ["quantumCoherence": 0.0, "entanglementStrength": 0.0, "fieldGeometry": 0.0],
                isFactory: true
            ),

            // Visual Presets
            Preset(
                id: "visual-mandala",
                name: "Sacred Mandala",
                category: Category.visual.rawValue,
                description: "Rotating sacred geometry patterns",
                parameters: ["symmetry": 8.0, "rotation": 0.5, "colorCycle": 0.3],
                isFactory: true
            ),
            Preset(
                id: "visual-nebula",
                name: "Cosmic Nebula",
                category: Category.visual.rawValue,
                description: "Flowing cosmic nebula visualization",
                parameters: ["particleDensity": 0.8, "flowSpeed": 0.4, "colorRange": 0.9],
                isFactory: true
            ),

            // Wellness Presets
            Preset(
                id: "wellness-morning",
                name: "Morning Energize",
                category: Category.wellness.rawValue,
                description: "Energizing morning routine with light therapy",
                parameters: ["lightIntensity": 0.8, "colorTemp": 6500, "duration": 15.0],
                isFactory: true
            ),
            Preset(
                id: "wellness-sleep",
                name: "Sleep Preparation",
                category: Category.wellness.rawValue,
                description: "Wind down for restful sleep",
                parameters: ["lightIntensity": 0.2, "colorTemp": 2700, "duration": 30.0],
                isFactory: true
            )
        ]
    }

    // MARK: - Preset Access

    /// Get all presets (factory + user)
    public var allPresets: [Preset] {
        factoryPresets + Array(userPresets.values)
    }

    /// Get presets by category
    public func presets(for category: Category) -> [Preset] {
        allPresets.filter { $0.category == category.rawValue }
    }

    /// Get preset by ID
    public func preset(withId id: String) -> Preset? {
        if let factory = factoryPresets.first(where: { $0.id == id }) {
            return factory
        }
        return userPresets[id]
    }

    // MARK: - User Presets

    /// Save a user preset
    public func saveUserPreset(_ preset: Preset) {
        var mutablePreset = preset
        userPresets[preset.id] = mutablePreset
        persistUserPresets()
    }

    /// Delete a user preset
    public func deleteUserPreset(withId id: String) {
        userPresets.removeValue(forKey: id)
        persistUserPresets()
    }

    /// Create preset from current state
    public func createPreset(
        name: String,
        category: Category,
        description: String,
        parameters: [String: Double]
    ) -> Preset {
        let preset = Preset(
            name: name,
            category: category.rawValue,
            description: description,
            parameters: parameters,
            isFactory: false
        )
        saveUserPreset(preset)
        return preset
    }

    // MARK: - Persistence

    private func loadUserPresets() {
        guard let data = UserDefaults.standard.data(forKey: userPresetsKey),
              let presets = try? JSONDecoder().decode([String: Preset].self, from: data) else {
            return
        }
        userPresets = presets
    }

    private func persistUserPresets() {
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        UserDefaults.standard.set(data, forKey: userPresetsKey)
    }

    // MARK: - Export/Import

    /// Export presets to JSON data
    public func exportPresets(_ presets: [Preset]) -> Data? {
        try? JSONEncoder().encode(presets)
    }

    /// Import presets from JSON data
    public func importPresets(from data: Data) -> [Preset]? {
        guard let presets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return nil
        }
        for preset in presets where !preset.isFactory {
            saveUserPreset(preset)
        }
        return presets
    }
}
