// ============================================================================
// ECHOELMUSIC - UNIVERSAL PRESET SYSTEM
// Save, Load, Share, Sync - All Your Creative Settings
// "Deine Kreativität, überall verfügbar - Your creativity, available everywhere"
// ============================================================================

import Foundation
import Combine
import SwiftUI

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: PRESET SYSTEM
// MARK: - ═══════════════════════════════════════════════════════════════════

/// Universal preset management for all Echoelmusic tools
@MainActor
public final class PresetSystem: ObservableObject {
    public static let shared = PresetSystem()

    // MARK: - Published State
    @Published public var userPresets: [Preset] = []
    @Published public var factoryPresets: [Preset] = []
    @Published public var favoritePresets: [Preset] = []
    @Published public var recentPresets: [Preset] = []
    @Published public var isCloudSyncEnabled: Bool = false
    @Published public var lastSyncDate: Date?

    // MARK: - Storage
    private let userDefaultsKey = "echoelmusic.presets.user"
    private let favoritesKey = "echoelmusic.presets.favorites"
    private let recentsKey = "echoelmusic.presets.recents"

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: PRESET MODEL
    // MARK: - ═══════════════════════════════════════════════════════════════

    public struct Preset: Identifiable, Codable, Hashable {
        public let id: UUID
        public var name: String
        public var category: Category
        public var toolType: ToolType
        public var parameters: [String: ParameterValue]
        public var tags: [String]
        public var author: String
        public var createdAt: Date
        public var modifiedAt: Date
        public var isFavorite: Bool
        public var isFactory: Bool
        public var version: Int

        // Optional metadata
        public var description: String?
        public var imageData: Data?
        public var audioPreviewURL: URL?

        public init(
            id: UUID = UUID(),
            name: String,
            category: Category,
            toolType: ToolType,
            parameters: [String: ParameterValue] = [:],
            tags: [String] = [],
            author: String = "User",
            description: String? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.toolType = toolType
            self.parameters = parameters
            self.tags = tags
            self.author = author
            self.createdAt = Date()
            self.modifiedAt = Date()
            self.isFavorite = false
            self.isFactory = false
            self.version = 1
            self.description = description
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public static func == (lhs: Preset, rhs: Preset) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Categories

    public enum Category: String, Codable, CaseIterable {
        case synthesis = "Synthesis"
        case effects = "Effects"
        case mixing = "Mixing"
        case mastering = "Mastering"
        case visualizer = "Visualizer"
        case lighting = "Lighting"
        case regeneration = "Regeneration"
        case biofeedback = "Biofeedback"
        case voice = "Voice"
        case custom = "Custom"

        public var icon: String {
            switch self {
            case .synthesis: return "waveform"
            case .effects: return "dial.max"
            case .mixing: return "slider.horizontal.3"
            case .mastering: return "gauge"
            case .visualizer: return "sparkles"
            case .lighting: return "lightbulb"
            case .regeneration: return "heart.circle"
            case .biofeedback: return "waveform.path.ecg"
            case .voice: return "mic"
            case .custom: return "star"
            }
        }
    }

    // MARK: - Tool Types

    public enum ToolType: String, Codable, CaseIterable {
        // Super Tools
        case echoelSynthesis = "EchoelSynthesis"
        case echoelProcess = "EchoelProcess"
        case echoelMind = "EchoelMind"
        case echoelLife = "EchoelLife"
        case echoelVision = "EchoelVision"

        // Specific Tools
        case moogBass = "Moog Bass"
        case acidBass = "Acid Bass"
        case parametricEQ = "Parametric EQ"
        case compressor = "Compressor"
        case reverb = "Reverb"
        case delay = "Delay"
        case limiter = "Limiter"

        // Regeneration
        case visualRegeneration = "Visual Regeneration"
        case audioVisualSync = "Audio-Visual Sync"

        // Other
        case global = "Global"
        case session = "Session"
    }

    // MARK: - Parameter Values

    public enum ParameterValue: Codable, Hashable {
        case float(Float)
        case int(Int)
        case bool(Bool)
        case string(String)
        case floatArray([Float])
        case stringArray([String])
        case dictionary([String: String])

        public var floatValue: Float? {
            if case .float(let v) = self { return v }
            return nil
        }

        public var intValue: Int? {
            if case .int(let v) = self { return v }
            return nil
        }

        public var boolValue: Bool? {
            if case .bool(let v) = self { return v }
            return nil
        }

        public var stringValue: String? {
            if case .string(let v) = self { return v }
            return nil
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: INITIALIZATION
    // MARK: - ═══════════════════════════════════════════════════════════════

    private init() {
        loadUserPresets()
        loadFactoryPresets()
        loadFavorites()
        loadRecents()
        print("🎛️ PresetSystem: Initialized with \(userPresets.count) user presets, \(factoryPresets.count) factory presets")
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: CRUD OPERATIONS
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Save a new preset
    public func savePreset(_ preset: Preset) {
        var newPreset = preset
        newPreset.modifiedAt = Date()

        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            userPresets[index] = newPreset
        } else {
            userPresets.append(newPreset)
        }

        persistUserPresets()
        addToRecents(newPreset)
        print("💾 Saved preset: \(preset.name)")
    }

    /// Delete a preset
    public func deletePreset(_ preset: Preset) {
        userPresets.removeAll { $0.id == preset.id }
        favoritePresets.removeAll { $0.id == preset.id }
        recentPresets.removeAll { $0.id == preset.id }
        persistUserPresets()
        persistFavorites()
        persistRecents()
        print("🗑️ Deleted preset: \(preset.name)")
    }

    /// Duplicate a preset
    public func duplicatePreset(_ preset: Preset) -> Preset {
        var duplicate = preset
        duplicate.id = UUID()
        duplicate.name = "\(preset.name) Copy"
        duplicate.createdAt = Date()
        duplicate.modifiedAt = Date()
        duplicate.isFactory = false
        savePreset(duplicate)
        return duplicate
    }

    /// Toggle favorite status
    public func toggleFavorite(_ preset: Preset) {
        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            userPresets[index].isFavorite.toggle()
            if userPresets[index].isFavorite {
                favoritePresets.append(userPresets[index])
            } else {
                favoritePresets.removeAll { $0.id == preset.id }
            }
            persistUserPresets()
            persistFavorites()
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: SEARCH & FILTER
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Search presets by name or tags
    public func search(query: String, in presets: [Preset]? = nil) -> [Preset] {
        let searchIn = presets ?? (userPresets + factoryPresets)
        guard !query.isEmpty else { return searchIn }

        let lowercasedQuery = query.lowercased()
        return searchIn.filter { preset in
            preset.name.lowercased().contains(lowercasedQuery) ||
            preset.tags.contains { $0.lowercased().contains(lowercasedQuery) } ||
            preset.author.lowercased().contains(lowercasedQuery) ||
            (preset.description?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    /// Filter presets by category
    public func filter(by category: Category, in presets: [Preset]? = nil) -> [Preset] {
        let filterIn = presets ?? (userPresets + factoryPresets)
        return filterIn.filter { $0.category == category }
    }

    /// Filter presets by tool type
    public func filter(by toolType: ToolType, in presets: [Preset]? = nil) -> [Preset] {
        let filterIn = presets ?? (userPresets + factoryPresets)
        return filterIn.filter { $0.toolType == toolType }
    }

    /// Get all presets sorted by recent usage
    public func getAllPresetsSortedByRecent() -> [Preset] {
        var all = userPresets + factoryPresets
        let recentIds = Set(recentPresets.map { $0.id })
        all.sort { preset1, preset2 in
            let recent1 = recentIds.contains(preset1.id)
            let recent2 = recentIds.contains(preset2.id)
            if recent1 && !recent2 { return true }
            if !recent1 && recent2 { return false }
            return preset1.modifiedAt > preset2.modifiedAt
        }
        return all
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: RECENTS
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func addToRecents(_ preset: Preset) {
        recentPresets.removeAll { $0.id == preset.id }
        recentPresets.insert(preset, at: 0)
        if recentPresets.count > 20 {
            recentPresets = Array(recentPresets.prefix(20))
        }
        persistRecents()
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: IMPORT / EXPORT
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Export preset to JSON data
    public func exportPreset(_ preset: Preset) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(preset)
    }

    /// Export multiple presets to JSON data
    public func exportPresets(_ presets: [Preset]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(presets)
    }

    /// Import preset from JSON data
    public func importPreset(from data: Data) -> Preset? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Preset.self, from: data)
    }

    /// Import multiple presets from JSON data
    public func importPresets(from data: Data) -> [Preset]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Preset].self, from: data)
    }

    /// Import and save preset from file URL
    public func importFromFile(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }

        if let preset = importPreset(from: data) {
            var imported = preset
            imported.isFactory = false
            savePreset(imported)
            return true
        } else if let presets = importPresets(from: data) {
            for preset in presets {
                var imported = preset
                imported.isFactory = false
                savePreset(imported)
            }
            return true
        }

        return false
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: PERSISTENCE
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func persistUserPresets() {
        if let data = exportPresets(userPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadUserPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let presets = importPresets(from: data) {
            userPresets = presets
        }
    }

    private func persistFavorites() {
        let ids = favoritePresets.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: favoritesKey)
    }

    private func loadFavorites() {
        if let ids = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            let idSet = Set(ids.compactMap { UUID(uuidString: $0) })
            favoritePresets = userPresets.filter { idSet.contains($0.id) }
        }
    }

    private func persistRecents() {
        let ids = recentPresets.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: recentsKey)
    }

    private func loadRecents() {
        if let ids = UserDefaults.standard.stringArray(forKey: recentsKey) {
            let allPresets = userPresets + factoryPresets
            recentPresets = ids.compactMap { idString -> Preset? in
                guard let id = UUID(uuidString: idString) else { return nil }
                return allPresets.first { $0.id == id }
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: FACTORY PRESETS
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func loadFactoryPresets() {
        factoryPresets = [
            // Synthesis Presets
            Preset(name: "Classic Moog Bass", category: .synthesis, toolType: .moogBass,
                   parameters: ["cutoff": .float(800), "resonance": .float(0.4), "osc1Level": .float(1.0)],
                   tags: ["bass", "analog", "classic"], author: "Echoelmusic", description: "Warm, punchy Moog-style bass"),

            Preset(name: "Acid Squelch", category: .synthesis, toolType: .acidBass,
                   parameters: ["cutoff": .float(400), "resonance": .float(0.8), "envMod": .float(0.9)],
                   tags: ["acid", "303", "techno"], author: "Echoelmusic", description: "Classic TB-303 acid sound"),

            // Effects Presets
            Preset(name: "Vocal Presence", category: .effects, toolType: .parametricEQ,
                   parameters: ["band1Freq": .float(200), "band1Gain": .float(-3), "band2Freq": .float(3000), "band2Gain": .float(4)],
                   tags: ["vocal", "presence", "clarity"], author: "Echoelmusic", description: "Enhance vocal clarity"),

            Preset(name: "Smooth Compression", category: .effects, toolType: .compressor,
                   parameters: ["threshold": .float(-18), "ratio": .float(3), "attack": .float(10), "release": .float(100)],
                   tags: ["smooth", "glue", "dynamics"], author: "Echoelmusic", description: "Gentle dynamic control"),

            // Mastering Presets
            Preset(name: "Loud Master", category: .mastering, toolType: .limiter,
                   parameters: ["threshold": .float(-1), "ceiling": .float(-0.3), "release": .float(50)],
                   tags: ["loud", "master", "streaming"], author: "Echoelmusic", description: "Maximized loudness for streaming"),

            // Regeneration Presets
            Preset(name: "Brain Health 40Hz", category: .regeneration, toolType: .audioVisualSync,
                   parameters: ["frequency": .float(40), "audioType": .string("isochronic"), "carrier": .float(200)],
                   tags: ["gamma", "brain", "health", "MIT"], author: "Echoelmusic", description: "40Hz gamma entrainment (MIT protocol)"),

            Preset(name: "Deep Relaxation", category: .regeneration, toolType: .audioVisualSync,
                   parameters: ["frequency": .float(6), "audioType": .string("binaural"), "carrier": .float(136.1)],
                   tags: ["theta", "relaxation", "meditation"], author: "Echoelmusic", description: "Theta wave deep relaxation"),

            Preset(name: "Focus Mode", category: .regeneration, toolType: .audioVisualSync,
                   parameters: ["frequency": .float(18), "audioType": .string("isochronic"), "carrier": .float(250)],
                   tags: ["beta", "focus", "concentration"], author: "Echoelmusic", description: "Beta wave focus enhancement")
        ]

        // Mark all factory presets
        for i in 0..<factoryPresets.count {
            factoryPresets[i].isFactory = true
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: CONVENIENCE EXTENSIONS
// MARK: - ═══════════════════════════════════════════════════════════════════

extension PresetSystem {
    /// Create a preset from current tool state
    public func createPreset(
        name: String,
        category: Category,
        toolType: ToolType,
        captureParameters: () -> [String: ParameterValue]
    ) -> Preset {
        let preset = Preset(
            name: name,
            category: category,
            toolType: toolType,
            parameters: captureParameters()
        )
        savePreset(preset)
        return preset
    }

    /// Quick save with auto-generated name
    public func quickSave(
        category: Category,
        toolType: ToolType,
        captureParameters: () -> [String: ParameterValue]
    ) -> Preset {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let name = "\(toolType.rawValue) - \(dateFormatter.string(from: Date()))"

        return createPreset(
            name: name,
            category: category,
            toolType: toolType,
            captureParameters: captureParameters
        )
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: DOCUMENTATION
// MARK: - ═══════════════════════════════════════════════════════════════════

/**
 ╔═══════════════════════════════════════════════════════════════════════════╗
 ║                    PRESET SYSTEM - FEATURE MAP                            ║
 ╠═══════════════════════════════════════════════════════════════════════════╣
 ║                                                                           ║
 ║  CORE FEATURES                                                           ║
 ║  ├─ Save/Load presets for all tools                                      ║
 ║  ├─ Factory presets included                                             ║
 ║  ├─ User presets with persistence                                        ║
 ║  ├─ Favorites and recents tracking                                       ║
 ║  └─ Search and filter by category/tool                                   ║
 ║                                                                           ║
 ║  IMPORT/EXPORT                                                           ║
 ║  ├─ JSON format for portability                                          ║
 ║  ├─ Single or batch export                                               ║
 ║  └─ Import from file                                                     ║
 ║                                                                           ║
 ║  CATEGORIES                                                               ║
 ║  ├─ Synthesis, Effects, Mixing, Mastering                               ║
 ║  ├─ Visualizer, Lighting                                                 ║
 ║  ├─ Regeneration, Biofeedback                                            ║
 ║  └─ Voice, Custom                                                        ║
 ║                                                                           ║
 ║  FUTURE: Cloud Sync                                                      ║
 ║  ├─ iCloud integration                                                   ║
 ║  ├─ Cross-device sync                                                    ║
 ║  └─ Community sharing                                                    ║
 ║                                                                           ║
 ╚═══════════════════════════════════════════════════════════════════════════╝
 */
