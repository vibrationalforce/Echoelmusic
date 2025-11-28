//
//  LightingControlView.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Copyright © 2025 Echoelmusic. All rights reserved.
//

import SwiftUI

struct LightingControlView: View {
    @EnvironmentObject var lightingController: UnifiedLightingController
    @State private var masterBrightness: Double = 1.0
    @State private var selectedSystem: UnifiedLightingController.LightingSystem?

    var body: some View {
        NavigationView {
            List {
                // Audio Reactive Toggle
                Section {
                    Toggle("Audio-Reactive Lighting", isOn: $lightingController.audioReactiveEnabled)
                        .tint(.purple)
                } header: {
                    Text("Audio Integration")
                } footer: {
                    Text("Lights respond to music in real-time: Bass→Red, Mids→Green, Treble→Blue")
                }

                // Master Controls
                Section("Master Controls") {
                    VStack(alignment: .leading) {
                        Text("Master Brightness")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Slider(value: $masterBrightness, in: 0...1)
                            .onChange(of: masterBrightness) { _, newValue in
                                Task {
                                    await lightingController.setAllLights(brightness: newValue)
                                }
                            }

                        HStack {
                            Text("0%")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(masterBrightness * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                            Spacer()
                            Text("100%")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                // Connected Systems
                Section("Connected Systems (\(lightingController.connectedSystems.count))") {
                    ForEach(lightingController.connectedSystems, id: \.self) { system in
                        NavigationLink(destination: SystemDetailView(system: system)) {
                            HStack {
                                Image(systemName: system.icon)
                                    .foregroundColor(.purple)
                                Text(system.rawValue)
                                Spacer()
                                Text("\(lightsCount(for: system))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // All Lights
                Section("All Lights (\(lightingController.allLights.count))") {
                    ForEach(lightingController.allLights) { light in
                        LightRow(light: light)
                    }
                }
            }
            .navigationTitle("Lighting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: discoverDevices) {
                        Label("Discover", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
        }
    }

    private func lightsCount(for system: UnifiedLightingController.LightingSystem) -> Int {
        lightingController.allLights.filter { $0.system == system }.count
    }

    private func discoverDevices() {
        Task {
            try? await lightingController.discoverDevices()
        }
    }
}

// MARK: - Light Row

struct LightRow: View {
    let light: UnifiedLight

    var body: some View {
        HStack {
            Circle()
                .fill(light.isReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading) {
                Text(light.name)
                    .font(.headline)
                Text(light.system.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(light.brightness * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - System Detail View

struct SystemDetailView: View {
    let system: UnifiedLightingController.LightingSystem

    var body: some View {
        List {
            Section("System Information") {
                LabeledContent("Name", value: system.rawValue)
                LabeledContent("Status", value: "Connected")
            }
        }
        .navigationTitle(system.rawValue)
    }
}

// MARK: - Preview

#Preview {
    LightingControlView()
        .environmentObject(UnifiedLightingController())
}
