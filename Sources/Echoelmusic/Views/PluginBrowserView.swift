import SwiftUI
import AVFoundation

// MARK: - Plugin Browser View
// Browse, load, and manage AU/VST3 plugins

public struct PluginBrowserView: View {
    @StateObject private var pluginHost = AUv3PluginHost.shared

    @State private var searchText = ""
    @State private var selectedType: PluginType? = nil
    @State private var selectedFormat: PluginFormat? = nil
    @State private var selectedCategory: PluginCategory? = nil
    @State private var selectedPlugin: PluginDescription?
    @State private var showPluginDetail = false

    private var filteredPlugins: [PluginDescription] {
        PluginBrowser.filter(
            plugins: pluginHost.availablePlugins,
            type: selectedType,
            format: selectedFormat,
            category: selectedCategory,
            search: searchText
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Plugin list
                if pluginHost.isScanning {
                    scanningView
                } else if filteredPlugins.isEmpty {
                    emptyView
                } else {
                    pluginList
                }
            }
            .navigationTitle("Plugins")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await pluginHost.scanPlugins() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search plugins")
            .sheet(isPresented: $showPluginDetail) {
                if let plugin = selectedPlugin {
                    PluginDetailView(plugin: plugin)
                }
            }
        }
        .task {
            if pluginHost.availablePlugins.isEmpty {
                await pluginHost.scanPlugins()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Type filter
                FilterMenu(
                    title: selectedType?.rawValue.capitalized ?? "Type",
                    isActive: selectedType != nil
                ) {
                    Button("All Types") { selectedType = nil }
                    Divider()
                    ForEach([PluginType.effect, .instrument, .generator, .analyzer], id: \.self) { type in
                        Button(type.rawValue.capitalized) { selectedType = type }
                    }
                }

                // Format filter
                FilterMenu(
                    title: selectedFormat?.rawValue.uppercased() ?? "Format",
                    isActive: selectedFormat != nil
                ) {
                    Button("All Formats") { selectedFormat = nil }
                    Divider()
                    Button("Audio Unit") { selectedFormat = .audioUnit }
                    Button("AUv3") { selectedFormat = .auv3 }
                    Button("VST3") { selectedFormat = .vst3 }
                }

                // Category filter
                FilterMenu(
                    title: selectedCategory?.rawValue.capitalized ?? "Category",
                    isActive: selectedCategory != nil
                ) {
                    Button("All Categories") { selectedCategory = nil }
                    Divider()
                    ForEach(PluginCategory.allCases, id: \.self) { category in
                        Button(category.rawValue.capitalized) { selectedCategory = category }
                    }
                }

                Spacer()

                // Stats
                Text("\(filteredPlugins.count) plugins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }

    // MARK: - Plugin List

    private var pluginList: some View {
        List {
            ForEach(groupedPlugins.keys.sorted(), id: \.self) { manufacturer in
                Section(manufacturer) {
                    ForEach(groupedPlugins[manufacturer] ?? []) { plugin in
                        PluginRow(plugin: plugin) {
                            selectedPlugin = plugin
                            showPluginDetail = true
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var groupedPlugins: [String: [PluginDescription]] {
        PluginBrowser.groupByManufacturer(filteredPlugins)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning for plugins...")
                .font(.headline)

            Text("This may take a moment")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No plugins found")
                .font(.headline)

            Text("Install Audio Units or VST3 plugins to see them here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Scan for Plugins") {
                Task { await pluginHost.scanPlugins() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Supporting Views

struct FilterMenu<Content: View>: View {
    let title: String
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct PluginRow: View {
    let plugin: PluginDescription
    let onSelect: () -> Void

    @State private var isLoading = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconForType(plugin.type))
                    .font(.title2)
                    .foregroundStyle(colorForFormat(plugin.format))
                    .frame(width: 40)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(plugin.format.rawValue.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForFormat(plugin.format).opacity(0.2))
                            .foregroundStyle(colorForFormat(plugin.format))
                            .clipShape(Capsule())

                        Text(plugin.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("v\(plugin.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Load button
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func iconForType(_ type: PluginType) -> String {
        switch type {
        case .effect: return "slider.horizontal.3"
        case .instrument: return "pianokeys"
        case .generator: return "waveform"
        case .analyzer: return "waveform.badge.magnifyingglass"
        }
    }

    private func colorForFormat(_ format: PluginFormat) -> Color {
        switch format {
        case .audioUnit: return .blue
        case .auv3: return .purple
        case .vst3: return .orange
        }
    }
}

struct PluginDetailView: View {
    let plugin: PluginDescription
    @Environment(\.dismiss) private var dismiss

    @StateObject private var pluginHost = AUv3PluginHost.shared
    @State private var loadedPlugin: LoadedPlugin?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedPreset: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    pluginHeader

                    // Load button
                    if loadedPlugin == nil {
                        loadSection
                    } else {
                        // Parameters
                        parametersSection

                        // Presets
                        presetsSection
                    }
                }
                .padding()
            }
            .navigationTitle(plugin.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var pluginHeader: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: iconForType(plugin.type))
                .font(.system(size: 48))
                .foregroundStyle(colorForFormat(plugin.format))

            // Info
            VStack(spacing: 4) {
                Text(plugin.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(plugin.manufacturer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Badges
            HStack(spacing: 12) {
                Badge(text: plugin.format.rawValue.uppercased(), color: colorForFormat(plugin.format))
                Badge(text: plugin.type.rawValue.capitalized, color: .gray)
                Badge(text: plugin.category.rawValue.capitalized, color: .gray)
            }

            // Channels
            HStack(spacing: 24) {
                VStack {
                    Text("\(plugin.inputChannels)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Inputs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(plugin.outputChannels)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Outputs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var loadSection: some View {
        VStack(spacing: 16) {
            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button(action: loadPlugin) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Load Plugin", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Parameters")
                .font(.headline)

            if let loaded = loadedPlugin {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(loaded.parameters) { param in
                        ParameterControl(parameter: param) { newValue in
                            pluginHost.setParameter(
                                pluginId: plugin.identifier,
                                parameterId: param.identifier,
                                value: newValue
                            )
                        }
                    }
                }
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Presets")
                .font(.headline)

            HStack {
                Button("Save Preset") {
                    Task {
                        _ = try? await pluginHost.saveUserPreset(plugin.identifier, name: "New Preset")
                    }
                }
                .buttonStyle(.bordered)

                Button("Load Preset") {
                    // Show preset picker
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func loadPlugin() {
        isLoading = true
        error = nil

        Task {
            do {
                loadedPlugin = try await pluginHost.loadPlugin(plugin.identifier)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func iconForType(_ type: PluginType) -> String {
        switch type {
        case .effect: return "slider.horizontal.3"
        case .instrument: return "pianokeys"
        case .generator: return "waveform"
        case .analyzer: return "waveform.badge.magnifyingglass"
        }
    }

    private func colorForFormat(_ format: PluginFormat) -> Color {
        switch format {
        case .audioUnit: return .blue
        case .auv3: return .purple
        case .vst3: return .orange
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ParameterControl: View {
    let parameter: PluginParameter
    let onChange: (Float) -> Void

    @State private var localValue: Float

    init(parameter: PluginParameter, onChange: @escaping (Float) -> Void) {
        self.parameter = parameter
        self.onChange = onChange
        self._localValue = State(initialValue: parameter.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(parameter.name)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text(String(format: "%.2f", localValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $localValue, in: parameter.minValue...parameter.maxValue)
                .onChange(of: localValue) { _, newValue in
                    onChange(newValue)
                }

            if !parameter.unit.isEmpty {
                Text(parameter.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PluginBrowserView()
}
