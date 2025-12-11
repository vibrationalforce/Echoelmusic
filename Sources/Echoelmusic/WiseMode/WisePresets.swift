import Foundation
import SwiftUI
import Combine

// MARK: - Wise Presets System
/// Benutzerdefinierte Mode-Kombinationen speichern und laden
/// Ermöglicht personalisierte Wise-Erfahrungen

/// Ein Wise Preset speichert eine vollständige Konfiguration
struct WisePreset: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var color: PresetColor
    var configuration: WiseModeConfiguration
    var isDefault: Bool
    var isFavorite: Bool
    var usageCount: Int
    var lastUsed: Date?
    var createdAt: Date
    var tags: [String]

    init(
        name: String,
        description: String = "",
        icon: String = "slider.horizontal.3",
        color: PresetColor = .blue,
        configuration: WiseModeConfiguration,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.configuration = configuration
        self.isDefault = isDefault
        self.isFavorite = false
        self.usageCount = 0
        self.lastUsed = nil
        self.createdAt = Date()
        self.tags = []
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WisePreset, rhs: WisePreset) -> Bool {
        lhs.id == rhs.id
    }
}

/// Preset-Farben für UI-Darstellung
enum PresetColor: String, Codable, CaseIterable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case cyan = "Cyan"
    case indigo = "Indigo"
    case mint = "Mint"

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .mint: return .mint
        }
    }
}

/// Preset-Kategorie für Organisation
enum PresetCategory: String, Codable, CaseIterable {
    case productivity = "Productivity"
    case creativity = "Creativity"
    case wellness = "Wellness"
    case sleep = "Sleep"
    case social = "Social"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .productivity: return "brain.head.profile"
        case .creativity: return "paintbrush"
        case .wellness: return "heart.circle"
        case .sleep: return "moon.zzz"
        case .social: return "person.3"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Wise Preset Manager

/// Verwaltung aller Wise Presets
@MainActor
class WisePresetManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WisePresetManager()

    // MARK: - Published State

    @Published var presets: [WisePreset] = []
    @Published var favoritePresets: [WisePreset] = []
    @Published var recentPresets: [WisePreset] = []
    @Published var selectedPreset: WisePreset?

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let maxRecentPresets = 5

    // MARK: - Callbacks

    var onPresetApplied: ((WisePreset) -> Void)?

    // MARK: - Initialization

    private init() {
        loadPresets()
        createDefaultPresetsIfNeeded()
        updateDerivedLists()

        print("🎨 WisePresetManager: Initialized with \(presets.count) presets")
    }

    // MARK: - CRUD Operations

    /// Erstellt ein neues Preset
    func createPreset(
        name: String,
        description: String = "",
        icon: String = "slider.horizontal.3",
        color: PresetColor = .blue,
        configuration: WiseModeConfiguration,
        tags: [String] = []
    ) -> WisePreset {
        var preset = WisePreset(
            name: name,
            description: description,
            icon: icon,
            color: color,
            configuration: configuration
        )
        preset.tags = tags

        presets.append(preset)
        savePresets()
        updateDerivedLists()

        print("✨ Created preset: \(name)")
        return preset
    }

    /// Erstellt ein Preset aus der aktuellen Konfiguration
    func createPresetFromCurrent(name: String, description: String = "") -> WisePreset {
        let currentConfig = WiseModeManager.shared.currentConfiguration
        return createPreset(
            name: name,
            description: description,
            icon: currentConfig.mode.icon,
            color: PresetColor.allCases.randomElement() ?? .blue,
            configuration: currentConfig
        )
    }

    /// Aktualisiert ein bestehendes Preset
    func updatePreset(_ preset: WisePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
            updateDerivedLists()

            print("📝 Updated preset: \(preset.name)")
        }
    }

    /// Löscht ein Preset
    func deletePreset(_ preset: WisePreset) {
        guard !preset.isDefault else {
            print("⚠️ Cannot delete default preset")
            return
        }

        presets.removeAll { $0.id == preset.id }
        savePresets()
        updateDerivedLists()

        print("🗑️ Deleted preset: \(preset.name)")
    }

    /// Wendet ein Preset an
    func applyPreset(_ preset: WisePreset) {
        // Update usage stats
        if var updatedPreset = presets.first(where: { $0.id == preset.id }) {
            updatedPreset.usageCount += 1
            updatedPreset.lastUsed = Date()
            updatePreset(updatedPreset)
        }

        // Apply configuration
        let manager = WiseModeManager.shared
        manager.switchMode(to: preset.configuration.mode)
        manager.updateConfiguration(preset.configuration)

        selectedPreset = preset
        onPresetApplied?(preset)

        print("▶️ Applied preset: \(preset.name)")
    }

    /// Markiert ein Preset als Favorit
    func toggleFavorite(_ preset: WisePreset) {
        if var updatedPreset = presets.first(where: { $0.id == preset.id }) {
            updatedPreset.isFavorite.toggle()
            updatePreset(updatedPreset)
        }
    }

    /// Dupliziert ein Preset
    func duplicatePreset(_ preset: WisePreset) -> WisePreset {
        return createPreset(
            name: "\(preset.name) Copy",
            description: preset.description,
            icon: preset.icon,
            color: preset.color,
            configuration: preset.configuration,
            tags: preset.tags
        )
    }

    // MARK: - Search & Filter

    /// Sucht Presets nach Name oder Tags
    func searchPresets(query: String) -> [WisePreset] {
        guard !query.isEmpty else { return presets }

        let lowercasedQuery = query.lowercased()
        return presets.filter { preset in
            preset.name.lowercased().contains(lowercasedQuery) ||
            preset.description.lowercased().contains(lowercasedQuery) ||
            preset.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Filtert Presets nach Mode
    func filterByMode(_ mode: WiseMode) -> [WisePreset] {
        presets.filter { $0.configuration.mode == mode }
    }

    /// Sortiert Presets nach Nutzung
    func sortedByUsage() -> [WisePreset] {
        presets.sorted { $0.usageCount > $1.usageCount }
    }

    // MARK: - Import/Export

    /// Exportiert alle Presets als JSON
    func exportPresets() -> Data? {
        try? JSONEncoder().encode(presets)
    }

    /// Exportiert ein einzelnes Preset
    func exportPreset(_ preset: WisePreset) -> Data? {
        try? JSONEncoder().encode(preset)
    }

    /// Importiert Presets aus JSON
    func importPresets(from data: Data) throws {
        let importedPresets = try JSONDecoder().decode([WisePreset].self, from: data)

        for var preset in importedPresets {
            // Generate new ID to avoid conflicts
            preset = WisePreset(
                name: preset.name,
                description: preset.description,
                icon: preset.icon,
                color: preset.color,
                configuration: preset.configuration
            )
            presets.append(preset)
        }

        savePresets()
        updateDerivedLists()

        print("📥 Imported \(importedPresets.count) presets")
    }

    /// Importiert ein einzelnes Preset
    func importPreset(from data: Data) throws -> WisePreset {
        let preset = try JSONDecoder().decode(WisePreset.self, from: data)

        var newPreset = WisePreset(
            name: preset.name,
            description: preset.description,
            icon: preset.icon,
            color: preset.color,
            configuration: preset.configuration
        )
        newPreset.tags = preset.tags

        presets.append(newPreset)
        savePresets()
        updateDerivedLists()

        return newPreset
    }

    // MARK: - Default Presets

    private func createDefaultPresetsIfNeeded() {
        guard presets.isEmpty else { return }

        // Deep Focus Preset
        let focusConfig = WiseModeConfiguration(mode: .focus)
        var focusPreset = WisePreset(
            name: "Deep Focus",
            description: "Maximale Konzentration für anspruchsvolle Aufgaben",
            icon: "brain.head.profile",
            color: .cyan,
            configuration: focusConfig,
            isDefault: true
        )
        focusPreset.tags = ["productivity", "focus", "work"]
        presets.append(focusPreset)

        // Creative Flow Preset
        let flowConfig = WiseModeConfiguration(mode: .flow)
        var flowPreset = WisePreset(
            name: "Creative Flow",
            description: "Optimale Bedingungen für kreative Arbeit",
            icon: "water.waves",
            color: .blue,
            configuration: flowConfig,
            isDefault: true
        )
        flowPreset.tags = ["creativity", "flow", "music"]
        presets.append(flowPreset)

        // Healing Session Preset
        let healingConfig = WiseModeConfiguration(mode: .healing)
        var healingPreset = WisePreset(
            name: "Healing Session",
            description: "Therapeutische Frequenzen für Regeneration",
            icon: "heart.circle",
            color: .pink,
            configuration: healingConfig,
            isDefault: true
        )
        healingPreset.tags = ["wellness", "healing", "therapy"]
        presets.append(healingPreset)

        // Deep Meditation Preset
        let meditationConfig = WiseModeConfiguration(mode: .meditation)
        var meditationPreset = WisePreset(
            name: "Deep Meditation",
            description: "Tiefe meditative Zustände erreichen",
            icon: "figure.mind.and.body",
            color: .purple,
            configuration: meditationConfig,
            isDefault: true
        )
        meditationPreset.tags = ["meditation", "mindfulness", "calm"]
        presets.append(meditationPreset)

        // Morning Energy Preset
        var energizeConfig = WiseModeConfiguration(mode: .energize)
        energizeConfig.binauralFrequency = 20.0
        var energizePreset = WisePreset(
            name: "Morning Energy",
            description: "Energetischer Start in den Tag",
            icon: "bolt.fill",
            color: .orange,
            configuration: energizeConfig,
            isDefault: true
        )
        energizePreset.tags = ["energy", "morning", "motivation"]
        presets.append(energizePreset)

        // Sleep Preparation Preset
        var sleepConfig = WiseModeConfiguration(mode: .sleep)
        sleepConfig.binauralFrequency = 2.0
        var sleepPreset = WisePreset(
            name: "Sleep Preparation",
            description: "Sanfter Übergang in erholsamen Schlaf",
            icon: "moon.zzz",
            color: .indigo,
            configuration: sleepConfig,
            isDefault: true
        )
        sleepPreset.tags = ["sleep", "relax", "night"]
        presets.append(sleepPreset)

        // Group Harmony Preset
        let socialConfig = WiseModeConfiguration(mode: .social)
        var socialPreset = WisePreset(
            name: "Group Harmony",
            description: "Optimiert für gemeinsame Sessions",
            icon: "person.3",
            color: .green,
            configuration: socialConfig,
            isDefault: true
        )
        socialPreset.tags = ["social", "group", "harmony"]
        presets.append(socialPreset)

        savePresets()
        print("🎨 Created \(presets.count) default presets")
    }

    // MARK: - Persistence

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            userDefaults.set(data, forKey: "wisePresets.all")
        }
    }

    private func loadPresets() {
        if let data = userDefaults.data(forKey: "wisePresets.all"),
           let loaded = try? JSONDecoder().decode([WisePreset].self, from: data) {
            presets = loaded
        }
    }

    private func updateDerivedLists() {
        favoritePresets = presets.filter { $0.isFavorite }
        recentPresets = presets
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(maxRecentPresets)
            .map { $0 }
    }
}

// MARK: - Preset Card View

struct WisePresetCard: View {
    let preset: WisePreset
    let onTap: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: preset.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(preset.color.color.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !preset.description.isEmpty {
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Label("\(preset.usageCount)", systemImage: "play.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(preset.configuration.mode.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(preset.configuration.mode.color.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Favorite Button
                Button(action: onFavorite) {
                    Image(systemName: preset.isFavorite ? "star.fill" : "star")
                        .foregroundColor(preset.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preset Picker View

struct WisePresetPicker: View {
    @ObservedObject var presetManager = WisePresetManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: PresetCategory?

    var filteredPresets: [WisePreset] {
        var result = presetManager.searchPresets(query: searchText)
        if let category = selectedCategory {
            result = result.filter { $0.tags.contains(category.rawValue.lowercased()) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search presets...", text: $searchText)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(PresetCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }

            // Presets Grid
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredPresets) { preset in
                        WisePresetCard(
                            preset: preset,
                            onTap: { presetManager.applyPreset(preset) },
                            onFavorite: { presetManager.toggleFavorite(preset) }
                        )
                    }
                }
            }
        }
        .padding()
    }
}

struct CategoryChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
