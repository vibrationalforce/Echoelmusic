//
//  DAWPluginRackView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  PLUGIN RACK - AUv3, VST3, CLAP plugin management
//

import SwiftUI

struct DAWPluginRackView: View {
    @StateObject private var pluginHost = DAWPluginHost.shared
    @Binding var selectedTrack: UUID?

    @State private var showPluginBrowser: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Plugin browser toggle
            HStack {
                Text("Plugin Rack")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showPluginBrowser.toggle() }) {
                    Label("Add Plugin", systemImage: "plus.circle")
                }
            }
            .padding()

            Divider()

            // Loaded plugins
            ScrollView {
                if let trackId = selectedTrack {
                    VStack(spacing: 10) {
                        // Get plugins for selected track
                        ForEach(pluginsForTrack(trackId)) { plugin in
                            PluginSlotView(plugin: plugin)
                        }

                        // Empty slots
                        ForEach(0..<3, id: \.self) { slot in
                            EmptyPluginSlot(slot: slot)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Select a track to view plugins")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showPluginBrowser) {
            PluginBrowserView(selectedTrack: $selectedTrack)
        }
    }

    private func pluginsForTrack(_ trackId: UUID) -> [DAWPluginHost.LoadedPlugin] {
        pluginHost.loadedPlugins.filter { $0.trackId == trackId }
    }
}

struct PluginSlotView: View {
    let plugin: DAWPluginHost.LoadedPlugin

    @State private var showUI: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Plugin icon
                Image(systemName: "cube.fill")
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.descriptor.name)
                        .font(.headline)
                    Text(plugin.descriptor.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Bypass button
                Button(action: {}) {
                    Image(systemName: plugin.isBypassed ? "power" : "power.circle.fill")
                        .foregroundColor(plugin.isBypassed ? .gray : .green)
                }

                // Show UI button
                Button(action: { showUI.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }

            // Preset
            HStack {
                Text("Preset:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(plugin.currentPreset ?? "Default")
                    .font(.caption)

                Spacer()

                // CPU usage
                Text("CPU: \(String(format: "%.1f", plugin.cpuUsage * 100))%")
                    .font(.caption2)
                    .foregroundColor(plugin.cpuUsage > 0.5 ? .orange : .secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showUI) {
            PluginUIView(plugin: plugin)
        }
    }
}

struct EmptyPluginSlot: View {
    let slot: Int

    var body: some View {
        HStack {
            Image(systemName: "cube")
                .foregroundColor(.gray)
            Text("Empty Slot \(slot + 1)")
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {}) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
    }
}

struct PluginBrowserView: View {
    @StateObject private var pluginHost = DAWPluginHost.shared
    @Binding var selectedTrack: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedFormat: DAWPluginHost.PluginDescriptor.PluginFormat? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search plugins...", text: $searchText)
                }
                .padding()
                .background(Color.gray.opacity(0.1))

                // Format filter
                Picker("Format", selection: $selectedFormat) {
                    Text("All").tag(nil as DAWPluginHost.PluginDescriptor.PluginFormat?)
                    ForEach([DAWPluginHost.PluginDescriptor.PluginFormat.auv3, .vst3, .clap, .eoel], id: \.self) { format in
                        Text(format.rawValue).tag(format as DAWPluginHost.PluginDescriptor.PluginFormat?)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Plugin list
                List {
                    ForEach(filteredPlugins) { descriptor in
                        PluginRow(descriptor: descriptor) {
                            loadPlugin(descriptor)
                        }
                    }
                }
            }
            .navigationTitle("Plugin Browser")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredPlugins: [DAWPluginHost.PluginDescriptor] {
        pluginHost.availablePlugins.filter { descriptor in
            let matchesSearch = searchText.isEmpty ||
                descriptor.name.localizedCaseInsensitiveContains(searchText) ||
                descriptor.manufacturer.localizedCaseInsensitiveContains(searchText)

            let matchesFormat = selectedFormat == nil || descriptor.format == selectedFormat

            return matchesSearch && matchesFormat
        }
    }

    private func loadPlugin(_ descriptor: DAWPluginHost.PluginDescriptor) {
        guard let trackId = selectedTrack else { return }

        Task {
            do {
                let _ = try await pluginHost.loadPlugin(
                    descriptor: descriptor,
                    onTrack: trackId,
                    inSlot: pluginHost.loadedPlugins.filter { $0.trackId == trackId }.count
                )
                dismiss()
            } catch {
                print("Failed to load plugin: \(error)")
            }
        }
    }
}

struct PluginRow: View {
    let descriptor: DAWPluginHost.PluginDescriptor
    let onLoad: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.name)
                    .font(.headline)
                Text(descriptor.manufacturer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Format badge
            Text(descriptor.format.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(formatColor(descriptor.format))
                .foregroundColor(.white)
                .cornerRadius(4)

            Button(action: onLoad) {
                Image(systemName: "arrow.down.circle")
            }
        }
    }

    private func formatColor(_ format: DAWPluginHost.PluginDescriptor.PluginFormat) -> Color {
        switch format {
        case .auv3: return .blue
        case .vst3: return .purple
        case .clap: return .orange
        case .eoel: return .green
        }
    }
}

struct PluginUIView: View {
    let plugin: DAWPluginHost.LoadedPlugin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Plugin UI for \(plugin.descriptor.name)")
                    .font(.title2)

                // Would embed actual plugin UI here
                // For AUv3: AudioUnitViewController
                // For VST3: VST3 GUI wrapper
                // For CLAP: CLAP GUI wrapper

                Spacer()

                Text("Native plugin UI would appear here")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationTitle(plugin.descriptor.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct DAWPluginRackView_Previews: PreviewProvider {
    static var previews: some View {
        DAWPluginRackView(selectedTrack: .constant(UUID()))
            .frame(width: 800, height: 600)
    }
}
#endif
