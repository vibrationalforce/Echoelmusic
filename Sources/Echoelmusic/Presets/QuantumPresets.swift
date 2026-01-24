//
//  QuantumPresets.swift
//  Echoelmusic
//
//  Pre-configured quantum sessions and visualization presets
//  One-tap access to curated experiences
//
//  Created: 2026-01-05
//

import Foundation
import SwiftUI

// MARK: - Quantum Preset

public struct QuantumPreset: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: PresetCategory
    public let icon: String
    public let color: PresetColor

    // Quantum settings
    public let emulationMode: String
    public let visualizationType: String
    public let lightFieldGeometry: String

    // Audio settings
    public let binauralFrequency: Float?
    public let spatialMode: String?
    public let reverbWetness: Float

    // Bio-reactive settings
    public let coherenceTarget: Float
    public let breathingPaceSeconds: Float
    public let hrvSensitivity: Float

    // Accessibility
    public let colorScheme: String
    public let reducedMotion: Bool

    public enum PresetCategory: String, Codable, CaseIterable, Sendable {
        case meditation = "Meditation"
        case creativity = "Creativity"
        case focus = "Focus"
        case relaxation = "Relaxation"
        case energy = "Energy"
        case wellness = "Wellness"  // Renamed from "healing" - scientific terminology
        case exploration = "Exploration"
        case performance = "Performance"
    }

    public struct PresetColor: Codable, Sendable {
        public let hue: Float
        public let saturation: Float
        public let brightness: Float

        public init(hue: Float, saturation: Float, brightness: Float) {
            self.hue = hue
            self.saturation = saturation
            self.brightness = brightness
        }
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        category: PresetCategory,
        icon: String,
        color: PresetColor,
        emulationMode: String = "bioCoherent",
        visualizationType: String = "coherenceField",
        lightFieldGeometry: String = "fibonacci",
        binauralFrequency: Float? = nil,
        spatialMode: String? = nil,
        reverbWetness: Float = 0.3,
        coherenceTarget: Float = 0.7,
        breathingPaceSeconds: Float = 5.0,
        hrvSensitivity: Float = 1.0,
        colorScheme: String = "standard",
        reducedMotion: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.emulationMode = emulationMode
        self.visualizationType = visualizationType
        self.lightFieldGeometry = lightFieldGeometry
        self.binauralFrequency = binauralFrequency
        self.spatialMode = spatialMode
        self.reverbWetness = reverbWetness
        self.coherenceTarget = coherenceTarget
        self.breathingPaceSeconds = breathingPaceSeconds
        self.hrvSensitivity = hrvSensitivity
        self.colorScheme = colorScheme
        self.reducedMotion = reducedMotion
    }
}

// MARK: - Built-in Presets

public struct BuiltInPresets {

    // MARK: - Meditation Presets

    public static let deepMeditation = QuantumPreset(
        id: "deep-meditation",
        name: "Deep Meditation",
        description: "Enter profound states of inner stillness with theta wave entrainment",
        category: .meditation,
        icon: "brain.head.profile",
        color: .init(hue: 0.7, saturation: 0.6, brightness: 0.4),
        emulationMode: "bioCoherent",
        visualizationType: "waveFunction",
        lightFieldGeometry: "toroidal",
        binauralFrequency: 6.0, // Theta
        spatialMode: "ambisonics",
        reverbWetness: 0.5,
        coherenceTarget: 0.85,
        breathingPaceSeconds: 6.0,
        hrvSensitivity: 1.2
    )

    public static let heartCoherence = QuantumPreset(
        id: "heart-coherence",
        name: "Heart Coherence",
        description: "Synchronize breath and heart for optimal HRV coherence",
        category: .meditation,
        icon: "heart.fill",
        color: .init(hue: 0.95, saturation: 0.7, brightness: 0.6),
        emulationMode: "bioCoherent",
        visualizationType: "biophotonAura",
        lightFieldGeometry: "fibonacci",
        binauralFrequency: 10.0, // Alpha
        spatialMode: "binaural",
        reverbWetness: 0.3,
        coherenceTarget: 0.9,
        breathingPaceSeconds: 5.0,
        hrvSensitivity: 1.5
    )

    public static let morningAwakening = QuantumPreset(
        id: "morning-awakening",
        name: "Morning Awakening",
        description: "Gently transition from sleep to alert awareness",
        category: .meditation,
        icon: "sunrise.fill",
        color: .init(hue: 0.1, saturation: 0.8, brightness: 0.7),
        emulationMode: "quantumInspired",
        visualizationType: "sacredGeometry",
        lightFieldGeometry: "spherical",
        binauralFrequency: 14.0, // Low Beta
        spatialMode: "surround_3d",
        reverbWetness: 0.2,
        coherenceTarget: 0.6,
        breathingPaceSeconds: 4.0,
        hrvSensitivity: 0.8
    )

    // MARK: - Creativity Presets

    public static let creativeFlow = QuantumPreset(
        id: "creative-flow",
        name: "Creative Flow",
        description: "Access creative inspiration through quantum randomness",
        category: .creativity,
        icon: "paintpalette.fill",
        color: .init(hue: 0.8, saturation: 0.7, brightness: 0.6),
        emulationMode: "quantumInspired",
        visualizationType: "lightMandala",
        lightFieldGeometry: "merkaba",
        binauralFrequency: 10.0,
        spatialMode: "surround_4d",
        reverbWetness: 0.4,
        coherenceTarget: 0.65,
        breathingPaceSeconds: 4.5,
        hrvSensitivity: 1.0
    )

    public static let musicalInspiration = QuantumPreset(
        id: "musical-inspiration",
        name: "Musical Inspiration",
        description: "Generate quantum-inspired musical ideas and harmonies",
        category: .creativity,
        icon: "music.quarternote.3",
        color: .init(hue: 0.55, saturation: 0.8, brightness: 0.5),
        emulationMode: "hybridPhotonic",
        visualizationType: "interferencePattern",
        lightFieldGeometry: "gaussian",
        binauralFrequency: 8.0,
        spatialMode: "afa",
        reverbWetness: 0.35,
        coherenceTarget: 0.7,
        breathingPaceSeconds: 5.0,
        hrvSensitivity: 1.1
    )

    // MARK: - Focus Presets

    public static let deepFocus = QuantumPreset(
        id: "deep-focus",
        name: "Deep Focus",
        description: "Laser-sharp concentration for demanding tasks",
        category: .focus,
        icon: "target",
        color: .init(hue: 0.6, saturation: 0.9, brightness: 0.5),
        emulationMode: "classical",
        visualizationType: "coherenceField",
        lightFieldGeometry: "planar",
        binauralFrequency: 18.0, // Beta
        spatialMode: "stereo",
        reverbWetness: 0.1,
        coherenceTarget: 0.8,
        breathingPaceSeconds: 4.0,
        hrvSensitivity: 0.7
    )

    public static let flowState = QuantumPreset(
        id: "flow-state",
        name: "Flow State",
        description: "Enter the zone of effortless peak performance",
        category: .focus,
        icon: "bolt.fill",
        color: .init(hue: 0.15, saturation: 0.9, brightness: 0.6),
        emulationMode: "bioCoherent",
        visualizationType: "quantumTunnel",
        lightFieldGeometry: "vortex",
        binauralFrequency: 12.0,
        spatialMode: "surround_3d",
        reverbWetness: 0.25,
        coherenceTarget: 0.75,
        breathingPaceSeconds: 4.5,
        hrvSensitivity: 1.0
    )

    // MARK: - Relaxation Presets

    public static let deepRelaxation = QuantumPreset(
        id: "deep-relaxation",
        name: "Deep Relaxation",
        description: "Release tension and enter profound relaxation",
        category: .relaxation,
        icon: "leaf.fill",
        color: .init(hue: 0.35, saturation: 0.5, brightness: 0.4),
        emulationMode: "bioCoherent",
        visualizationType: "photonFlow",
        lightFieldGeometry: "fibonacci",
        binauralFrequency: 4.0, // Delta edge
        spatialMode: "binaural",
        reverbWetness: 0.6,
        coherenceTarget: 0.6,
        breathingPaceSeconds: 7.0,
        hrvSensitivity: 1.3
    )

    public static let sleepPreparation = QuantumPreset(
        id: "sleep-preparation",
        name: "Sleep Preparation",
        description: "Prepare body and mind for restful sleep",
        category: .relaxation,
        icon: "moon.fill",
        color: .init(hue: 0.7, saturation: 0.4, brightness: 0.2),
        emulationMode: "bioCoherent",
        visualizationType: "cosmicWeb",
        lightFieldGeometry: "toroidal",
        binauralFrequency: 2.0, // Delta
        spatialMode: "binaural",
        reverbWetness: 0.7,
        coherenceTarget: 0.5,
        breathingPaceSeconds: 8.0,
        hrvSensitivity: 0.5,
        reducedMotion: true
    )

    // MARK: - Energy Presets

    public static let energyBoost = QuantumPreset(
        id: "energy-boost",
        name: "Energy Boost",
        description: "Quick energizing session for instant vitality",
        category: .energy,
        icon: "battery.100.bolt",
        color: .init(hue: 0.08, saturation: 1.0, brightness: 0.7),
        emulationMode: "quantumInspired",
        visualizationType: "sacredGeometry",
        lightFieldGeometry: "merkaba",
        binauralFrequency: 25.0, // High Beta
        spatialMode: "surround_4d",
        reverbWetness: 0.15,
        coherenceTarget: 0.6,
        breathingPaceSeconds: 3.0,
        hrvSensitivity: 0.6
    )

    // MARK: - Wellness Presets (No Medical Claims)

    /// Schumann Resonance - Earth's electromagnetic frequency (7.83Hz)
    /// Scientific basis: Measurable ELF resonance. Subjective relaxation only.
    public static let schumannResonance = QuantumPreset(
        id: "schumann-resonance",
        name: "Earth Resonance",
        description: "7.83Hz Schumann resonance for grounding (no medical claims)",
        category: .wellness,
        icon: "globe.europe.africa.fill",
        color: .init(hue: 0.35, saturation: 0.5, brightness: 0.4),
        emulationMode: "bioCoherent",
        visualizationType: "coherenceField",
        lightFieldGeometry: "toroidal",
        binauralFrequency: 7.83, // Schumann resonance (scientifically measured)
        spatialMode: "ambisonics",
        reverbWetness: 0.45,
        coherenceTarget: 0.75,
        breathingPaceSeconds: 6.0,
        hrvSensitivity: 1.2
    )

    // MARK: - Exploration Presets

    public static let cosmicExplorer = QuantumPreset(
        id: "cosmic-explorer",
        name: "Cosmic Explorer",
        description: "Journey through quantum realms and cosmic structures",
        category: .exploration,
        icon: "sparkles",
        color: .init(hue: 0.75, saturation: 0.8, brightness: 0.4),
        emulationMode: "fullQuantum",
        visualizationType: "cosmicWeb",
        lightFieldGeometry: "merkaba",
        binauralFrequency: 5.5,
        spatialMode: "surround_4d",
        reverbWetness: 0.55,
        coherenceTarget: 0.7,
        breathingPaceSeconds: 5.5,
        hrvSensitivity: 1.2
    )

    public static let lucidDreaming = QuantumPreset(
        id: "lucid-dreaming",
        name: "Lucid Dreaming",
        description: "Prepare consciousness for lucid dream exploration",
        category: .exploration,
        icon: "cloud.fill",
        color: .init(hue: 0.65, saturation: 0.5, brightness: 0.3),
        emulationMode: "quantumInspired",
        visualizationType: "holographicDisplay",
        lightFieldGeometry: "vortex",
        binauralFrequency: 4.5,
        spatialMode: "binaural",
        reverbWetness: 0.6,
        coherenceTarget: 0.65,
        breathingPaceSeconds: 6.5,
        hrvSensitivity: 1.0
    )

    // MARK: - Performance Presets

    public static let stagePresence = QuantumPreset(
        id: "stage-presence",
        name: "Stage Presence",
        description: "Optimal state for live performance and public speaking",
        category: .performance,
        icon: "person.wave.2.fill",
        color: .init(hue: 0.0, saturation: 0.8, brightness: 0.6),
        emulationMode: "bioCoherent",
        visualizationType: "lightMandala",
        lightFieldGeometry: "spherical",
        binauralFrequency: 15.0,
        spatialMode: "surround_3d",
        reverbWetness: 0.2,
        coherenceTarget: 0.85,
        breathingPaceSeconds: 4.0,
        hrvSensitivity: 0.9
    )

    // MARK: - All Presets

    public static let all: [QuantumPreset] = [
        // Meditation
        deepMeditation,
        heartCoherence,
        morningAwakening,
        // Creativity
        creativeFlow,
        musicalInspiration,
        // Focus
        deepFocus,
        flowState,
        // Relaxation
        deepRelaxation,
        sleepPreparation,
        // Energy
        energyBoost,
        // Wellness (no medical claims - for relaxation only)
        schumannResonance,
        // Exploration
        cosmicExplorer,
        lucidDreaming,
        // Performance
        stagePresence
    ]

    public static func presets(for category: QuantumPreset.PresetCategory) -> [QuantumPreset] {
        all.filter { $0.category == category }
    }
}

// MARK: - Preset Manager

@MainActor
public class PresetManager: ObservableObject {

    @Published public var currentPreset: QuantumPreset?
    @Published public var customPresets: [QuantumPreset] = []
    @Published public var favoritePresetIds: Set<String> = []
    @Published public var recentPresetIds: [String] = []

    public static let shared = PresetManager()

    private let userDefaultsKey = "quantum_custom_presets"
    private let favoritesKey = "quantum_favorite_presets"
    private let recentKey = "quantum_recent_presets"

    private init() {
        loadPresets()
    }

    // MARK: - Preset Loading

    private func loadPresets() {
        // Load custom presets
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let presets = try? JSONDecoder().decode([QuantumPreset].self, from: data) {
            customPresets = presets
        }

        // Load favorites
        if let ids = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoritePresetIds = Set(ids)
        }

        // Load recent
        if let ids = UserDefaults.standard.array(forKey: recentKey) as? [String] {
            recentPresetIds = ids
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(Array(favoritePresetIds), forKey: favoritesKey)
        UserDefaults.standard.set(recentPresetIds, forKey: recentKey)
    }

    // MARK: - Public Methods

    public var allPresets: [QuantumPreset] {
        BuiltInPresets.all + customPresets
    }

    public var favoritePresets: [QuantumPreset] {
        allPresets.filter { favoritePresetIds.contains($0.id) }
    }

    public var recentPresets: [QuantumPreset] {
        recentPresetIds.compactMap { id in
            allPresets.first { $0.id == id }
        }
    }

    public func apply(_ preset: QuantumPreset, to hub: UnifiedControlHub) {
        // Apply quantum mode
        if let mode = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) {
            hub.setQuantumMode(mode)
        }

        // Track as recent
        addToRecent(preset.id)

        currentPreset = preset
        log.info("[Presets] Applied: \(preset.name)", category: .system)
    }

    public func toggleFavorite(_ presetId: String) {
        if favoritePresetIds.contains(presetId) {
            favoritePresetIds.remove(presetId)
        } else {
            favoritePresetIds.insert(presetId)
        }
        savePresets()
    }

    public func isFavorite(_ presetId: String) -> Bool {
        favoritePresetIds.contains(presetId)
    }

    public func addCustomPreset(_ preset: QuantumPreset) {
        customPresets.append(preset)
        savePresets()
    }

    public func deleteCustomPreset(_ presetId: String) {
        customPresets.removeAll { $0.id == presetId }
        favoritePresetIds.remove(presetId)
        recentPresetIds.removeAll { $0 == presetId }
        savePresets()
    }

    private func addToRecent(_ presetId: String) {
        recentPresetIds.removeAll { $0 == presetId }
        recentPresetIds.insert(presetId, at: 0)
        if recentPresetIds.count > 10 {
            recentPresetIds = Array(recentPresetIds.prefix(10))
        }
        savePresets()
    }
}

// MARK: - Preset Picker View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct PresetPickerView: View {
    @ObservedObject var presetManager = PresetManager.shared
    @State private var selectedCategory: QuantumPreset.PresetCategory?
    @State private var searchText = ""

    let onSelect: (QuantumPreset) -> Void

    public init(onSelect: @escaping (QuantumPreset) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationView {
            List {
                // Recent section
                if !presetManager.recentPresets.isEmpty && searchText.isEmpty {
                    Section("Recent") {
                        ForEach(presetManager.recentPresets.prefix(3)) { preset in
                            PresetRow(preset: preset, isFavorite: presetManager.isFavorite(preset.id)) {
                                onSelect(preset)
                            } onToggleFavorite: {
                                presetManager.toggleFavorite(preset.id)
                            }
                        }
                    }
                }

                // Favorites section
                if !presetManager.favoritePresets.isEmpty && searchText.isEmpty {
                    Section("Favorites") {
                        ForEach(presetManager.favoritePresets) { preset in
                            PresetRow(preset: preset, isFavorite: true) {
                                onSelect(preset)
                            } onToggleFavorite: {
                                presetManager.toggleFavorite(preset.id)
                            }
                        }
                    }
                }

                // Category sections
                ForEach(QuantumPreset.PresetCategory.allCases, id: \.self) { category in
                    let presets = filteredPresets(for: category)
                    if !presets.isEmpty {
                        Section(category.rawValue) {
                            ForEach(presets) { preset in
                                PresetRow(preset: preset, isFavorite: presetManager.isFavorite(preset.id)) {
                                    onSelect(preset)
                                } onToggleFavorite: {
                                    presetManager.toggleFavorite(preset.id)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search presets")
            .navigationTitle("Quantum Presets")
        }
    }

    private func filteredPresets(for category: QuantumPreset.PresetCategory) -> [QuantumPreset] {
        let categoryPresets = presetManager.allPresets.filter { $0.category == category }

        if searchText.isEmpty {
            return categoryPresets
        }

        return categoryPresets.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct PresetRow: View {
    let preset: QuantumPreset
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Icon with color
                ZStack {
                    Circle()
                        .fill(Color(
                            hue: Double(preset.color.hue),
                            saturation: Double(preset.color.saturation),
                            brightness: Double(preset.color.brightness)
                        ))
                        .frame(width: 40, height: 40)

                    Image(systemName: preset.icon)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.headline)

                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
    }
}
