//
// PresetBrowserView.swift
// Echoelmusic
//
// SwiftUI view for browsing, searching, and managing presets
//

import SwiftUI

struct PresetBrowserView: View {

    // MARK: - Properties

    @StateObject private var presetManager = PresetManager()
    @State private var searchText = ""
    @State private var selectedCategory: PresetCategory?
    @State private var showingFactoryOnly = false
    @State private var showingFavoritesOnly = false
    @State private var showingImportSheet = false
    @State private var showingShareSheet = false
    @State private var presetToShare: Preset?
    @State private var shareURL: URL?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding()

                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil && !showingFavoritesOnly,
                            action: {
                                selectedCategory = nil
                                showingFavoritesOnly = false
                            }
                        )

                        FilterChip(
                            title: "Favorites",
                            icon: "heart.fill",
                            isSelected: showingFavoritesOnly,
                            action: {
                                showingFavoritesOnly.toggle()
                                selectedCategory = nil
                            }
                        )

                        ForEach(PresetCategory.allCases, id: \.self) { category in
                            if category != .custom {
                                FilterChip(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        selectedCategory = category == selectedCategory ? nil : category
                                        showingFavoritesOnly = false
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)

                // Preset Grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(filteredPresets) { preset in
                            PresetCard(
                                preset: preset,
                                onSelect: {
                                    selectPreset(preset)
                                },
                                onFavorite: {
                                    presetManager.toggleFavorite(id: preset.id)
                                },
                                onShare: {
                                    sharePreset(preset)
                                },
                                onDelete: preset.isFactory ? nil : {
                                    deletePreset(preset)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingImportSheet = true }) {
                            Label("Import Preset", systemImage: "square.and.arrow.down")
                        }

                        Button(action: { }) {
                            Label("Create New", systemImage: "plus")
                        }

                        Divider()

                        Button(action: { showingFactoryOnly.toggle() }) {
                            Label(
                                showingFactoryOnly ? "Show All" : "Factory Only",
                                systemImage: "star.fill"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(item: $presetToShare) { preset in
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredPresets: [Preset] {
        var presets = showingFactoryOnly ?
            presetManager.factoryPresets :
            presetManager.factoryPresets + presetManager.userPresets

        // Filter by favorites
        if showingFavoritesOnly {
            presets = presets.filter { $0.isFavorite }
        }

        // Filter by category
        if let category = selectedCategory {
            presets = presets.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            presets = presets.filter { preset in
                preset.name.localizedCaseInsensitiveContains(searchText) ||
                preset.description.localizedCaseInsensitiveContains(searchText) ||
                preset.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return presets
    }

    // MARK: - Actions

    private func selectPreset(_ preset: Preset) {
        presetManager.currentPreset = preset
        // Apply preset to audio engine
        // NotificationCenter.default.post(name: .presetSelected, object: preset)
        dismiss()
    }

    private func sharePreset(_ preset: Preset) {
        presetToShare = preset

        presetManager.sharePreset(preset) { url in
            if let url = url {
                shareURL = url
            }
        }
    }

    private func deletePreset(_ preset: Preset) {
        _ = presetManager.deletePreset(id: preset.id)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = presetManager.importPreset(from: url)

        case .failure(let error):
            print("Import error: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct PresetCard: View {
    let preset: Preset
    let onSelect: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category & Favorite
            HStack {
                Label(preset.category.rawValue, systemImage: preset.category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onFavorite) {
                    Image(systemName: preset.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(preset.isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Name
            Text(preset.name)
                .font(.headline)
                .lineLimit(2)

            // Description
            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(preset.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            // Actions
            HStack(spacing: 16) {
                Button(action: onSelect) {
                    Text("Apply")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    if let deleteAction = onDelete {
                        Button(role: .destructive, action: deleteAction) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct FilterChip: View {
    let title: String
    var icon: String?
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
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search presets...", text: $text)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct PresetBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        PresetBrowserView()
    }
}
