//
//  SettingsView.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Copyright © 2025 Echoelmusic. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioEngine: EchoelmusicAudioEngine
    @StateObject private var tuningSettings = TuningSettings.shared

    @State private var sampleRate: Double = 48000
    @State private var bufferSize: Int = 128
    @State private var enableLowLatency: Bool = true

    var body: some View {
        NavigationView {
            List {
                // Audio Settings
                Section("Audio") {
                    Picker("Sample Rate", selection: $sampleRate) {
                        Text("44.1 kHz").tag(44100.0)
                        Text("48 kHz").tag(48000.0)
                        Text("96 kHz").tag(96000.0)
                        Text("192 kHz").tag(192000.0)
                    }

                    Picker("Buffer Size", selection: $bufferSize) {
                        Text("64 samples").tag(64)
                        Text("128 samples").tag(128)
                        Text("256 samples").tag(256)
                        Text("512 samples").tag(512)
                    }

                    Toggle("Low Latency Mode", isOn: $enableLowLatency)

                    LabeledContent("Current Latency") {
                        Text("\(String(format: "%.2f", audioEngine.currentLatency * 1000))ms")
                            .foregroundColor(.secondary)
                    }
                }

                // Tuning & Pitch Settings (NEW)
                Section("Stimmung & Tonhöhe") {
                    NavigationLink {
                        TuningSettingsView()
                    } label: {
                        HStack {
                            Label("Kammerton", systemImage: "tuningfork")
                            Spacer()
                            Text("A4 = \(String(format: "%.1f", tuningSettings.concertPitch)) Hz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        TuningSystemSelectionView()
                    } label: {
                        HStack {
                            Label("Stimmungssystem", systemImage: "waveform.path")
                            Spacer()
                            Text(MusicalTuningSystem.shared.currentTuning.rawValue.components(separatedBy: " ").first ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        KeySelectionView()
                    } label: {
                        HStack {
                            Label("Tonart", systemImage: "music.note")
                            Spacer()
                            Text(tuningSettings.keyDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Biofeedback Translation (NEW)
                Section("Biofeedback") {
                    NavigationLink {
                        BiofeedbackTranslationToolView()
                    } label: {
                        Label("Biofeedback Translation Tool", systemImage: "waveform.path.ecg")
                    }

                    NavigationLink {
                        FrequencyVisualizationSettingsView()
                    } label: {
                        Label("Frequenz-Visualisierung", systemImage: "eye")
                    }
                }

                // Lighting Settings
                Section("Lighting") {
                    NavigationLink("Connected Systems") {
                        Text("Lighting Systems")
                    }
                    NavigationLink("Audio-Reactive Settings") {
                        Text("Audio-Reactive Config")
                    }
                }

                // EoelWork Settings
                Section("EoelWork") {
                    NavigationLink("Profile") {
                        Text("User Profile")
                    }
                    NavigationLink("Subscription") {
                        SubscriptionView()
                    }
                    NavigationLink("Industries") {
                        Text("Industry Preferences")
                    }
                }

                // Photonic Systems
                Section("Photonic Systems") {
                    NavigationLink("LiDAR Settings") {
                        Text("LiDAR Configuration")
                    }
                    NavigationLink("Laser Safety") {
                        Text("Safety Protocols")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "3.0.0")
                    LabeledContent("Build", value: "1")
                    NavigationLink("Licenses") {
                        Text("Open Source Licenses")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Quick Access Views

struct TuningSystemSelectionView: View {
    @StateObject private var tuningSystem = MusicalTuningSystem.shared

    var body: some View {
        List {
            ForEach(MusicalTuningSystem.TuningSystem.allCases, id: \.self) { system in
                Button {
                    tuningSystem.applyTuning(system)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(system.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(system.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if tuningSystem.currentTuning == system {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Stimmungssystem")
    }
}

struct KeySelectionView: View {
    @StateObject private var settings = TuningSettings.shared

    var body: some View {
        Form {
            Section("Grundton") {
                Picker("Grundton", selection: $settings.rootNote) {
                    ForEach(TuningSettings.RootNote.allCases, id: \.self) { note in
                        Text(note.name).tag(note)
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Skala") {
                Picker("Skala", selection: $settings.scaleMode) {
                    ForEach(TuningSettings.ScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }

            Section("Aktuell") {
                HStack {
                    Text("Tonart")
                    Spacer()
                    Text(settings.keyDescription)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .navigationTitle("Tonart")
    }
}

struct FrequencyVisualizationSettingsView: View {
    @StateObject private var visualMapper = FrequencyToVisualMapper.shared

    var body: some View {
        List {
            Section("Mapping-Modus") {
                ForEach([
                    ("HRV", "Herzratenvariabilität (0.04-0.4 Hz)", FrequencyToVisualMapper.MappingMode.hrv),
                    ("EEG", "Gehirnwellen (0.5-100 Hz)", FrequencyToVisualMapper.MappingMode.eeg),
                    ("Audio Spektral", "Audible (20-20k Hz) linear", FrequencyToVisualMapper.MappingMode.audioSpectral),
                    ("Audio Musikalisch", "Audible (20-20k Hz) oktaviert", FrequencyToVisualMapper.MappingMode.audioMusical)
                ], id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.headline)
                        Text(item.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Frequenzbänder") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HRV Bänder")
                        .font(.headline)
                    HStack {
                        bandIndicator("VLF", color: .purple, range: "0.003-0.04 Hz")
                        bandIndicator("LF", color: .blue, range: "0.04-0.15 Hz")
                        bandIndicator("HF", color: .green, range: "0.15-0.4 Hz")
                    }
                }
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("EEG Bänder")
                        .font(.headline)
                    HStack {
                        bandIndicator("δ", color: .purple, range: "0.5-4")
                        bandIndicator("θ", color: .blue, range: "4-8")
                        bandIndicator("α", color: .cyan, range: "8-13")
                        bandIndicator("β", color: .yellow, range: "13-30")
                        bandIndicator("γ", color: .red, range: "30-100")
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Frequenz-Visualisierung")
    }

    private func bandIndicator(_ name: String, color: Color, range: String) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )
            Text(range)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Subscription View

struct SubscriptionView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EoelWork Monthly")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("$6.99/month")
                        .font(.title3)
                        .foregroundColor(.purple)

                    Text("Zero commission on all gigs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }

            Section {
                FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited gig applications")
                FeatureRow(icon: "checkmark.circle.fill", text: "AI-powered matching")
                FeatureRow(icon: "checkmark.circle.fill", text: "8+ industries")
                FeatureRow(icon: "checkmark.circle.fill", text: "Emergency gig notifications")
                FeatureRow(icon: "checkmark.circle.fill", text: "Direct client messaging")
            }

            Section {
                Button(action: {}) {
                    Text("Subscribe Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Subscription")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(EchoelmusicAudioEngine.shared)
}
