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
    @StateObject private var lightingController = UnifiedLightingController()
    @StateObject private var eoelWorkBackend = EchoelmusicWorkBackend.shared

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
                    NavigationLink {
                        LightingControlView()
                    } label: {
                        HStack {
                            Label("Connected Systems", systemImage: "lightbulb.fill")
                            Spacer()
                            Text("\(lightingController.connectedSystems.count) systems")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        AudioReactiveLightingSettingsView()
                    } label: {
                        HStack {
                            Label("Audio-Reactive Settings", systemImage: "waveform.path")
                            Spacer()
                            if lightingController.audioReactiveEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // EoelWork Settings
                Section("EoelWork") {
                    NavigationLink {
                        EoelWorkProfileView()
                    } label: {
                        HStack {
                            Label("Profile", systemImage: "person.circle")
                            Spacer()
                            if let user = eoelWorkBackend.currentUser {
                                Text(user.profile.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Label("Subscription", systemImage: "creditcard")
                            Spacer()
                            Text("$6.99/mo")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }

                    NavigationLink {
                        IndustryPreferencesView()
                    } label: {
                        HStack {
                            Label("Industries", systemImage: "building.2")
                            Spacer()
                            Text("8+ available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        GigSearchView()
                    } label: {
                        Label("Find Gigs", systemImage: "magnifyingglass")
                    }
                }

                // Photonic Systems
                Section("Photonic Systems") {
                    NavigationLink {
                        LiDARSettingsView()
                    } label: {
                        Label("LiDAR Settings", systemImage: "sensor.tag.radiowaves.forward")
                    }

                    NavigationLink {
                        LaserSafetyView()
                    } label: {
                        Label("Laser Safety", systemImage: "exclamationmark.triangle")
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

// MARK: - Audio-Reactive Lighting Settings

struct AudioReactiveLightingSettingsView: View {
    @StateObject private var lightingController = UnifiedLightingController()

    @State private var bassToRed: Bool = true
    @State private var midsToGreen: Bool = true
    @State private var trebleToBlue: Bool = true
    @State private var sensitivity: Double = 0.7
    @State private var updateRate: Double = 60.0

    var body: some View {
        Form {
            Section("Audio Mapping") {
                Toggle("Bass → Red", isOn: $bassToRed)
                Toggle("Mids → Green", isOn: $midsToGreen)
                Toggle("Treble → Blue", isOn: $trebleToBlue)
            }

            Section("Sensitivity") {
                VStack(alignment: .leading) {
                    Text("Response Sensitivity: \(Int(sensitivity * 100))%")
                        .font(.caption)
                    Slider(value: $sensitivity, in: 0.1...1.0)
                }

                VStack(alignment: .leading) {
                    Text("Update Rate: \(Int(updateRate)) FPS")
                        .font(.caption)
                    Slider(value: $updateRate, in: 15...120, step: 15)
                }
            }

            Section("Preview") {
                HStack(spacing: 20) {
                    Circle()
                        .fill(Color.red.opacity(bassToRed ? sensitivity : 0.2))
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(Color.green.opacity(midsToGreen ? sensitivity : 0.2))
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(Color.blue.opacity(trebleToBlue ? sensitivity : 0.2))
                        .frame(width: 50, height: 50)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("Audio-Reactive")
    }
}

// MARK: - EoelWork Profile View

struct EoelWorkProfileView: View {
    @StateObject private var backend = EchoelmusicWorkBackend.shared
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var hourlyRate: String = ""

    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Name", text: $name)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Professional") {
                HStack {
                    Text("Hourly Rate")
                    Spacer()
                    TextField("$", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("/hr")
                }
            }

            Section("Statistics") {
                if let user = backend.currentUser {
                    LabeledContent("Rating", value: String(format: "%.1f ⭐", user.rating))
                    LabeledContent("Completed Gigs", value: "\(user.completedGigs)")
                } else {
                    Text("Sign in to view stats")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Save Profile") {
                    // Save profile action
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            if let user = backend.currentUser {
                name = user.profile.name
                bio = user.profile.bio
                hourlyRate = user.profile.hourlyRate != nil ? "\(user.profile.hourlyRate!)" : ""
            }
        }
    }
}

// MARK: - Industry Preferences View

struct IndustryPreferencesView: View {
    @State private var selectedIndustries: Set<String> = []

    let industries = [
        ("music", "Music & Audio", "Music production, sound engineering, DJing"),
        ("film", "Film & Video", "Cinematography, editing, post-production"),
        ("events", "Events & Entertainment", "Live events, festivals, corporate"),
        ("hospitality", "Hospitality", "Hotels, restaurants, catering"),
        ("healthcare", "Healthcare", "Medical facilities, wellness centers"),
        ("retail", "Retail", "Stores, malls, pop-up shops"),
        ("education", "Education", "Schools, universities, training"),
        ("tech", "Technology", "IT, software, hardware")
    ]

    var body: some View {
        List {
            Section {
                Text("Select the industries you want to receive gig notifications for.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Industries") {
                ForEach(industries, id: \.0) { industry in
                    Button {
                        if selectedIndustries.contains(industry.0) {
                            selectedIndustries.remove(industry.0)
                        } else {
                            selectedIndustries.insert(industry.0)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(industry.1)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(industry.2)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedIndustries.contains(industry.0) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }

            Section {
                Text("\(selectedIndustries.count) industries selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Industries")
    }
}

// MARK: - Gig Search View

struct GigSearchView: View {
    @StateObject private var backend = EchoelmusicWorkBackend.shared
    @State private var searchQuery: String = ""
    @State private var selectedUrgency: String = "all"

    var body: some View {
        List {
            Section {
                TextField("Search gigs...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)

                Picker("Urgency", selection: $selectedUrgency) {
                    Text("All").tag("all")
                    Text("Emergency").tag("emergency")
                    Text("Urgent").tag("urgent")
                    Text("Normal").tag("normal")
                }
                .pickerStyle(.segmented)
            }

            Section("Available Gigs (\(backend.availableGigs.count))") {
                if backend.availableGigs.isEmpty {
                    Text("No gigs found. Try adjusting your filters.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(backend.availableGigs, id: \.id) { gig in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gig.title)
                                .font(.headline)
                            Text(gig.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            HStack {
                                Text("$\(Int(gig.budget))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Spacer()
                                Text(gig.urgency.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(urgencyColor(gig.urgency).opacity(0.2))
                                    .foregroundColor(urgencyColor(gig.urgency))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Find Gigs")
        .task {
            try? await backend.searchGigs()
        }
    }

    private func urgencyColor(_ urgency: Gig.Urgency) -> Color {
        switch urgency {
        case .emergency: return .red
        case .urgent: return .orange
        case .normal: return .blue
        case .flexible: return .green
        }
    }
}

// MARK: - LiDAR Settings View

struct LiDARSettingsView: View {
    @State private var lidarEnabled: Bool = true
    @State private var scanResolution: Double = 0.5
    @State private var maxRange: Double = 5.0

    var body: some View {
        Form {
            Section {
                Toggle("Enable LiDAR", isOn: $lidarEnabled)
            }

            Section("Scan Settings") {
                VStack(alignment: .leading) {
                    Text("Resolution: \(String(format: "%.2f", scanResolution))m")
                        .font(.caption)
                    Slider(value: $scanResolution, in: 0.01...1.0)
                }

                VStack(alignment: .leading) {
                    Text("Max Range: \(String(format: "%.1f", maxRange))m")
                        .font(.caption)
                    Slider(value: $maxRange, in: 1.0...10.0)
                }
            }

            Section("Applications") {
                NavigationLink("Spatial Audio Mapping") {
                    Text("Use LiDAR to map room acoustics")
                }
                NavigationLink("Projection Mapping") {
                    Text("Automatic surface detection")
                }
                NavigationLink("Gesture Recognition") {
                    Text("3D hand/body tracking")
                }
            }
        }
        .navigationTitle("LiDAR Settings")
    }
}

// MARK: - Laser Safety View

struct LaserSafetyView: View {
    @State private var safetyModeEnabled: Bool = true
    @State private var maxPowerLevel: Double = 0.3
    @State private var eyeSafeMode: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Safety Mode", isOn: $safetyModeEnabled)
                    .tint(.green)
            } footer: {
                Text("Always keep safety mode enabled during live performances.")
                    .font(.caption)
            }

            Section("Power Limits") {
                VStack(alignment: .leading) {
                    Text("Max Power: \(Int(maxPowerLevel * 100))%")
                        .font(.caption)
                    Slider(value: $maxPowerLevel, in: 0.1...1.0)
                }

                Toggle("Eye-Safe Mode (Class 1)", isOn: $eyeSafeMode)
            }

            Section("Safety Classes") {
                SafetyClassRow(className: "Class 1", description: "Safe for all uses", color: .green)
                SafetyClassRow(className: "Class 2", description: "Safe with blink reflex", color: .yellow)
                SafetyClassRow(className: "Class 3R", description: "Low risk, limited power", color: .orange)
                SafetyClassRow(className: "Class 3B", description: "Hazardous, direct view", color: .red)
                SafetyClassRow(className: "Class 4", description: "High power, skin/fire hazard", color: .purple)
            }

            Section("Compliance") {
                LabeledContent("IEC 60825-1", value: "✓")
                LabeledContent("FDA/CDRH", value: "✓")
                LabeledContent("EN 60825-1", value: "✓")
            }
        }
        .navigationTitle("Laser Safety")
    }
}

struct SafetyClassRow: View {
    let className: String
    let description: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                Text(className)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(EchoelmusicAudioEngine.shared)
}
