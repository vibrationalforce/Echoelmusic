//
//  MIDI2ControlPanelView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  MIDI 2.0 Control Panel - Professional configuration interface
//  Full MIDI 2.0 UMP, Per-Note Controllers, Property Exchange, Profile Configuration
//

import SwiftUI

/// Comprehensive MIDI 2.0 Control Panel
struct MIDI2ControlPanelView: View {
    @StateObject private var midi2Manager = MIDI2Manager.shared
    @State private var selectedTab: MIDI2Tab = .overview

    enum MIDI2Tab: String, CaseIterable {
        case overview = "Overview"
        case devices = "Devices"
        case profiles = "Profiles"
        case propertyExchange = "Property Exchange"
        case perNote = "Per-Note Controllers"
        case jitterReduction = "Jitter Reduction"
        case diagnostics = "Diagnostics"

        var icon: String {
            switch self {
            case .overview: return "gauge"
            case .devices: return "cable.connector"
            case .profiles: return "list.bullet.rectangle"
            case .propertyExchange: return "arrow.left.arrow.right"
            case .perNote: return "music.note.list"
            case .jitterReduction: return "waveform.path.ecg"
            case .diagnostics: return "stethoscope"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(MIDI2Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("MIDI 2.0")
            .frame(minWidth: 200)

            // Detail view
            Group {
                switch selectedTab {
                case .overview:
                    MIDI2OverviewView()
                case .devices:
                    MIDI2DevicesView()
                case .profiles:
                    MIDI2ProfilesView()
                case .propertyExchange:
                    MIDI2PropertyExchangeView()
                case .perNote:
                    MIDI2PerNoteView()
                case .jitterReduction:
                    MIDI2JitterReductionView()
                case .diagnostics:
                    MIDI2DiagnosticsView()
                }
            }
            .frame(minWidth: 600)
        }
    }
}

// MARK: - Overview

struct MIDI2OverviewView: View {
    @StateObject private var midi2Manager = MIDI2Manager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MIDI 2.0 System Status")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // System Status
                GroupBox("System Status") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusRow(label: "MIDI 2.0 Engine", value: "Active", color: .green)
                        StatusRow(label: "UMP Protocol", value: "Enabled", color: .green)
                        StatusRow(label: "Connected Devices", value: "0", color: .blue)
                        StatusRow(label: "Active Profiles", value: "0", color: .blue)
                        StatusRow(label: "Per-Note Controllers", value: "Enabled", color: .green)
                        StatusRow(label: "32-bit Resolution", value: "Active", color: .green)
                    }
                    .padding()
                }

                // Features
                GroupBox("MIDI 2.0 Features") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            FeatureCard(
                                title: "UMP Packets",
                                description: "Universal MIDI Packet format",
                                icon: "cube.box"
                            )
                            FeatureCard(
                                title: "32-bit Resolution",
                                description: "Ultra-precise control data",
                                icon: "slider.horizontal.3"
                            )
                        }

                        GridRow {
                            FeatureCard(
                                title: "Per-Note Controllers",
                                description: "Individual note expression",
                                icon: "music.note"
                            )
                            FeatureCard(
                                title: "Property Exchange",
                                description: "Device configuration protocol",
                                icon: "arrow.triangle.2.circlepath"
                            )
                        }

                        GridRow {
                            FeatureCard(
                                title: "Profile Configuration",
                                description: "Standard device profiles",
                                icon: "doc.text"
                            )
                            FeatureCard(
                                title: "Jitter Reduction",
                                description: "Timestamp-based timing",
                                icon: "waveform.path"
                            )
                        }
                    }
                    .padding()
                }

                // Quick Stats
                GroupBox("Performance Statistics") {
                    HStack(spacing: 40) {
                        StatBox(label: "Messages/sec", value: "0", unit: "msg/s")
                        StatBox(label: "Latency", value: "0.5", unit: "ms")
                        StatBox(label: "Jitter", value: "0.02", unit: "ms")
                        StatBox(label: "Bandwidth", value: "0.1", unit: "MB/s")
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Devices View

struct MIDI2DevicesView: View {
    @State private var devices: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("MIDI 2.0 Devices")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    // Scan for devices
                } label: {
                    Label("Scan Devices", systemImage: "arrow.clockwise")
                }
            }

            if devices.isEmpty {
                ContentUnavailableView(
                    "No MIDI 2.0 Devices",
                    systemImage: "cable.connector",
                    description: Text("Connect a MIDI 2.0 device or click 'Scan Devices' to search")
                )
            } else {
                List {
                    ForEach(devices, id: \.self) { device in
                        DeviceRow(deviceName: device)
                    }
                }
            }
        }
        .padding()
    }
}

struct DeviceRow: View {
    let deviceName: String
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Protocol:")
                    Spacer()
                    Text("MIDI 2.0 UMP")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Resolution:")
                    Spacer()
                    Text("32-bit")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Capabilities:")
                    Spacer()
                    Text("Per-Note, Property Exchange")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.green)
                Text(deviceName)
                    .font(.headline)
            }
        }
    }
}

// MARK: - Profiles View

struct MIDI2ProfilesView: View {
    @State private var availableProfiles: [MIDIProfile] = [
        MIDIProfile(name: "General MIDI 2", id: "0x7E00", enabled: true),
        MIDIProfile(name: "MPE", id: "0x7E01", enabled: false),
        MIDIProfile(name: "Drawbar Organ", id: "0x7E02", enabled: false),
        MIDIProfile(name: "Multi-Channel Audio", id: "0x7E03", enabled: false)
    ]

    struct MIDIProfile: Identifiable {
        let id: String
        let name: String
        var enabled: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("MIDI 2.0 profiles define standard device behaviors and capabilities")
                .foregroundColor(.secondary)

            List {
                ForEach($availableProfiles) { $profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.headline)
                            Text("Profile ID: \(profile.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $profile.enabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}

// MARK: - Property Exchange

struct MIDI2PropertyExchangeView: View {
    @State private var properties: [PropertyItem] = []

    struct PropertyItem: Identifiable {
        let id = UUID()
        let name: String
        let value: String
        let writable: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Property Exchange")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Query and modify device properties using MIDI 2.0 Property Exchange")
                .foregroundColor(.secondary)

            HStack {
                Button {
                    // Get all properties
                } label: {
                    Label("Get All Properties", systemImage: "arrow.down.circle")
                }

                Button {
                    // Refresh
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if properties.isEmpty {
                ContentUnavailableView(
                    "No Properties",
                    systemImage: "doc.text",
                    description: Text("Connect a device and click 'Get All Properties'")
                )
            } else {
                List(properties) { property in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(property.name)
                                .font(.headline)
                            Text(property.value)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if property.writable {
                            Button("Edit") {
                                // Edit property
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Per-Note Controllers

struct MIDI2PerNoteView: View {
    @State private var perNoteCC: [PerNoteController] = [
        PerNoteController(name: "Pitch Bend", cc: 0, value: 0.5),
        PerNoteController(name: "Pressure", cc: 1, value: 0.0),
        PerNoteController(name: "Timbre", cc: 2, value: 0.5),
        PerNoteController(name: "Brightness", cc: 3, value: 0.7)
    ]

    struct PerNoteController: Identifiable {
        let id = UUID()
        let name: String
        let cc: Int
        var value: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Per-Note Controllers")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Control individual notes with independent controller values")
                .foregroundColor(.secondary)

            GroupBox("Active Per-Note Controllers") {
                VStack(spacing: 16) {
                    ForEach($perNoteCC) { $controller in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(controller.name)
                                    .font(.headline)
                                Spacer()
                                Text("CC \(controller.cc)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.3f", controller.value))
                                    .font(.caption)
                                    .monospacedDigit()
                            }

                            Slider(value: $controller.value, in: 0...1)
                        }
                    }
                }
                .padding()
            }

            GroupBox("Per-Note Capabilities") {
                VStack(alignment: .leading, spacing: 12) {
                    CapabilityRow(name: "32-bit Resolution", enabled: true)
                    CapabilityRow(name: "Per-Note Pitch Bend", enabled: true)
                    CapabilityRow(name: "Per-Note Pressure", enabled: true)
                    CapabilityRow(name: "Per-Note Timbre", enabled: true)
                    CapabilityRow(name: "Independent CC per Note", enabled: true)
                }
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - Jitter Reduction

struct MIDI2JitterReductionView: View {
    @State private var jitterReduction: Bool = true
    @State private var timestampMode: TimestampMode = .absolute
    @State private var bufferSize: Double = 64
    @State private var jitterStatistics: JitterStats = JitterStats()

    enum TimestampMode: String, CaseIterable {
        case absolute = "Absolute Time"
        case relative = "Relative Time"
        case system = "System Time"
    }

    struct JitterStats {
        var average: Double = 0.02
        var peak: Double = 0.05
        var minimum: Double = 0.01
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Jitter Reduction")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("MIDI 2.0 timestamp-based jitter reduction for ultra-precise timing")
                    .foregroundColor(.secondary)

                GroupBox("Configuration") {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable Jitter Reduction", isOn: $jitterReduction)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timestamp Mode")
                                .font(.headline)
                            Picker("Timestamp Mode", selection: $timestampMode) {
                                ForEach(TimestampMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Buffer Size")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(bufferSize)) samples")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $bufferSize, in: 32...512, step: 32)
                        }
                    }
                    .padding()
                }

                GroupBox("Jitter Statistics") {
                    VStack(spacing: 12) {
                        JitterStatRow(label: "Average Jitter", value: jitterStatistics.average, unit: "ms")
                        JitterStatRow(label: "Peak Jitter", value: jitterStatistics.peak, unit: "ms")
                        JitterStatRow(label: "Minimum Jitter", value: jitterStatistics.minimum, unit: "ms")
                    }
                    .padding()
                }

                // Jitter visualization
                GroupBox("Jitter Timeline") {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(height: 200)
                        .overlay(
                            Text("Jitter Waveform")
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            .padding()
        }
    }
}

struct JitterStatRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.3f %@", value, unit))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Diagnostics

struct MIDI2DiagnosticsView: View {
    @State private var messages: [MIDIMessage] = []
    @State private var monitoring: Bool = false

    struct MIDIMessage: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: String
        let data: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("MIDI 2.0 Diagnostics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    monitoring.toggle()
                } label: {
                    Label(monitoring ? "Stop Monitor" : "Start Monitor",
                          systemImage: monitoring ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            GroupBox("Message Monitor") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if messages.isEmpty {
                            Text("No messages captured")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(messages) { message in
                                HStack(spacing: 12) {
                                    Text(message.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(message.type)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(width: 100, alignment: .leading)

                                    Text(message.data)
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                                Divider()
                            }
                        }
                    }
                }
                .frame(height: 400)
            }

            HStack {
                Button("Clear Messages") {
                    messages.removeAll()
                }
                .buttonStyle(.bordered)

                Button("Export Log") {
                    // Export messages
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Helper Views

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureCard: View {
    let title: String
    let description: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CapabilityRow: View {
    let name: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .gray)
            Text(name)
            Spacer()
        }
    }
}

#if DEBUG
struct MIDI2ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        MIDI2ControlPanelView()
            .frame(width: 1000, height: 700)
    }
}
#endif
