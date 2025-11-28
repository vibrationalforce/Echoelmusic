//
//  PresetManager.swift
//  Echoelmusic
//
//  Universal Preset Management System
//  Save/Load presets for instruments, effects, and entire chains
//

import Foundation
import SwiftUI

// MARK: - Preset Protocol

protocol PresetCompatible {
    associatedtype PresetData: Codable
    func savePreset(name: String, author: String) -> Preset<PresetData>
    func loadPreset(_ preset: Preset<PresetData>)
}

// MARK: - Generic Preset Structure

struct Preset<T: Codable>: Codable, Identifiable {
    let id: UUID
    let name: String
    let author: String
    let category: String
    let tags: [String]
    let dateCreated: Date
    let dateModified: Date
    let version: String
    let data: T

    // Metadata
    var description: String?
    var isFavorite: Bool = false
    var isFactory: Bool = false
    var rating: Int = 0  // 0-5 stars

    init(name: String, author: String = "User", category: String = "Uncategorized",
         tags: [String] = [], data: T, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.author = author
        self.category = category
        self.tags = tags
        self.dateCreated = Date()
        self.dateModified = Date()
        self.version = "1.0.0"
        self.data = data
        self.description = description
    }
}

// MARK: - Preset Manager

@MainActor
class PresetManager: ObservableObject {
    static let shared = PresetManager()

    @Published var presetLibrary: [String: Any] = [:]  // [presetType: [Preset]]
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String = "All"
    @Published var sortMode: PresetSortMode = .dateModified

    enum PresetSortMode: String, CaseIterable {
        case name = "Name"
        case dateCreated = "Date Created"
        case dateModified = "Date Modified"
        case author = "Author"
        case rating = "Rating"
    }

    private let fileManager = FileManager.default
    private var presetsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Echoelmusic/Presets", isDirectory: true)
    }

    private init() {
        createPresetsDirectory()
        loadFactoryPresets()
    }

    private func createPresetsDirectory() {
        try? fileManager.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save & Load

    func savePreset<T: Codable>(_ preset: Preset<T>, type: String) throws {
        let typeDirectory = presetsDirectory.appendingPathComponent(type, isDirectory: true)
        try? fileManager.createDirectory(at: typeDirectory, withIntermediateDirectories: true)

        let fileName = "\(preset.name)_\(preset.id.uuidString).json"
        let fileURL = typeDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preset)

        try data.write(to: fileURL)
        print("✅ Preset saved: \(fileURL.path)")
    }

    func loadPreset<T: Codable>(type: String, id: UUID) throws -> Preset<T> {
        let typeDirectory = presetsDirectory.appendingPathComponent(type, isDirectory: true)

        // Find file with matching ID
        let files = try fileManager.contentsOfDirectory(at: typeDirectory,
                                                        includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles])

        guard let file = files.first(where: { $0.lastPathComponent.contains(id.uuidString) }) else {
            throw PresetError.presetNotFound
        }

        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        let preset = try decoder.decode(Preset<T>.self, from: data)

        return preset
    }

    func loadAllPresets<T: Codable>(type: String) -> [Preset<T>] {
        let typeDirectory = presetsDirectory.appendingPathComponent(type, isDirectory: true)

        guard let files = try? fileManager.contentsOfDirectory(at: typeDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles]) else {
            return []
        }

        var presets: [Preset<T>] = []
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let preset = try? decoder.decode(Preset<T>.self, from: data) {
                presets.append(preset)
            }
        }

        return presets
    }

    func deletePreset(type: String, id: UUID) throws {
        let typeDirectory = presetsDirectory.appendingPathComponent(type, isDirectory: true)

        let files = try fileManager.contentsOfDirectory(at: typeDirectory,
                                                        includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles])

        if let file = files.first(where: { $0.lastPathComponent.contains(id.uuidString) }) {
            try fileManager.removeItem(at: file)
            print("✅ Preset deleted: \(file.path)")
        }
    }

    // MARK: - Search & Filter

    func searchPresets<T: Codable>(_ presets: [Preset<T>], query: String) -> [Preset<T>] {
        guard !query.isEmpty else { return presets }

        return presets.filter { preset in
            preset.name.localizedCaseInsensitiveContains(query) ||
            preset.author.localizedCaseInsensitiveContains(query) ||
            preset.category.localizedCaseInsensitiveContains(query) ||
            preset.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    func sortPresets<T: Codable>(_ presets: [Preset<T>], by mode: PresetSortMode) -> [Preset<T>] {
        switch mode {
        case .name:
            return presets.sorted { $0.name < $1.name }
        case .dateCreated:
            return presets.sorted { $0.dateCreated > $1.dateCreated }
        case .dateModified:
            return presets.sorted { $0.dateModified > $1.dateModified }
        case .author:
            return presets.sorted { $0.author < $1.author }
        case .rating:
            return presets.sorted { $0.rating > $1.rating }
        }
    }

    func filterByCategory<T: Codable>(_ presets: [Preset<T>], category: String) -> [Preset<T>] {
        guard category != "All" else { return presets }
        return presets.filter { $0.category == category }
    }

    // MARK: - Factory Presets

    private func loadFactoryPresets() {
        // Load built-in factory presets
        print("📦 Loading factory presets...")
        // Factory presets would be bundled with the app
    }

    // MARK: - Import/Export

    func exportPreset<T: Codable>(_ preset: Preset<T>, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preset)
        try data.write(to: url)
        print("✅ Preset exported: \(url.path)")
    }

    func importPreset<T: Codable>(from url: URL, type: String) throws -> Preset<T> {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let preset = try decoder.decode(Preset<T>.self, from: data)

        // Save to presets directory
        try savePreset(preset, type: type)

        return preset
    }

    enum PresetError: LocalizedError {
        case presetNotFound
        case invalidFormat
        case saveFailed
        case loadFailed

        var errorDescription: String? {
            switch self {
            case .presetNotFound: return "Preset not found"
            case .invalidFormat: return "Invalid preset format"
            case .saveFailed: return "Failed to save preset"
            case .loadFailed: return "Failed to load preset"
            }
        }
    }
}

// MARK: - Preset Browser View

struct PresetBrowserView<T: Codable>: View {
    let presetType: String
    @State private var presets: [Preset<T>] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var sortMode: PresetManager.PresetSortMode = .dateModified
    @State private var selectedPreset: Preset<T>?

    let onLoadPreset: (Preset<T>) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            HStack(spacing: 0) {
                // Categories Sidebar
                categoriesSidebar

                Divider()

                // Preset List
                presetList
            }
        }
        .onAppear {
            loadPresets()
        }
    }

    // MARK: - Toolbar

    var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search presets...", text: $searchText)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.15))
            )

            // Sort
            Picker("Sort", selection: $sortMode) {
                ForEach(PresetManager.PresetSortMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            // Actions
            Button {
                // Save current as new preset
            } label: {
                Label("Save New", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(white: 0.1))
    }

    // MARK: - Categories Sidebar

    var categoriesSidebar: some View {
        List(selection: $selectedCategory) {
            Section("Categories") {
                NavigationLink("All", value: "All")
                NavigationLink("Factory", value: "Factory")
                NavigationLink("User", value: "User")
                NavigationLink("Favorites", value: "Favorites")

                Divider()

                // Dynamic categories from presets
                ForEach(uniqueCategories, id: \.self) { category in
                    NavigationLink(category, value: category)
                }
            }
        }
        .frame(width: 200)
        .background(Color(white: 0.12))
    }

    var uniqueCategories: [String] {
        Array(Set(presets.map { $0.category })).sorted()
    }

    // MARK: - Preset List

    var presetList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredAndSortedPresets) { preset in
                    presetCard(preset)
                }
            }
            .padding()
        }
    }

    func presetCard(_ preset: Preset<T>) -> some View {
        Button {
            selectedPreset = preset
            onLoadPreset(preset)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        if preset.isFactory {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }

                        if preset.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Text(preset.author)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let description = preset.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }

                    HStack {
                        ForEach(preset.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                // Rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < preset.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPreset?.id == preset.id ? Color.cyan.opacity(0.2) : Color(white: 0.15))
            )
        }
        .buttonStyle(.plain)
    }

    var filteredAndSortedPresets: [Preset<T>] {
        var filtered = presets

        // Search
        if !searchText.isEmpty {
            filtered = PresetManager.shared.searchPresets(filtered, query: searchText)
        }

        // Category
        if selectedCategory != "All" {
            filtered = PresetManager.shared.filterByCategory(filtered, category: selectedCategory)
        }

        // Special filters
        switch selectedCategory {
        case "Factory":
            filtered = filtered.filter { $0.isFactory }
        case "User":
            filtered = filtered.filter { !$0.isFactory }
        case "Favorites":
            filtered = filtered.filter { $0.isFavorite }
        default:
            break
        }

        // Sort
        return PresetManager.shared.sortPresets(filtered, by: sortMode)
    }

    private func loadPresets() {
        presets = PresetManager.shared.loadAllPresets(type: presetType)
    }
}

// MARK: - Example Preset Data Structures

struct InstrumentPresetData: Codable {
    var waveform: String
    var attackTime: Float
    var decayTime: Float
    var sustainLevel: Float
    var releaseTime: Float
    var filterCutoff: Float
    var filterResonance: Float
    var lfoRate: Float
    var lfoAmount: Float
}

struct EffectPresetData: Codable {
    var effectType: String
    var parameters: [String: Float]
}

// MARK: - Preview

#Preview("Preset Browser") {
    // Create sample presets
    let sampleData = InstrumentPresetData(
        waveform: "Saw",
        attackTime: 0.01,
        decayTime: 0.1,
        sustainLevel: 0.7,
        releaseTime: 0.3,
        filterCutoff: 2000,
        filterResonance: 1.5,
        lfoRate: 2.0,
        lfoAmount: 0.5
    )

    PresetBrowserView<InstrumentPresetData>(
        presetType: "Synth",
        onLoadPreset: { preset in
            print("Loading preset: \(preset.name)")
        }
    )
}
