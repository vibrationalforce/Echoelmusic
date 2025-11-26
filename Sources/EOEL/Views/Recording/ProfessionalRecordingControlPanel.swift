//
//  ProfessionalRecordingControlPanel.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Professional Recording Control Panel
//  Logic Pro X / Cubase / Pro Tools level recording interface
//  Clock, MIDI sync, direct monitoring, hardware integration
//

import SwiftUI

/// Professional recording control panel - complete recording studio
struct ProfessionalRecordingControlPanel: View {
    @StateObject private var clock = MasterClockSystem.shared
    @StateObject private var monitoring = DirectMonitoringSystem.shared
    @StateObject private var hardware = HardwareIntegrationManager.shared
    @StateObject private var recorder = RealtimeMIDIRecorder.shared

    @State private var selectedTab: RecordingTab = .transport
    @State private var showHardwareScan = false
    @State private var showMonitoringSetup = false

    enum RecordingTab: String, CaseIterable {
        case transport = "Transport"
        case midiTracks = "MIDI Tracks"
        case monitoring = "Monitoring"
        case hardware = "Hardware"
        case clock = "Clock & Sync"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab Bar
            tabBar

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                transportView
                    .tag(RecordingTab.transport)

                midiTracksView
                    .tag(RecordingTab.midiTracks)

                monitoringView
                    .tag(RecordingTab.monitoring)

                hardwareView
                    .tag(RecordingTab.hardware)

                clockSyncView
                    .tag(RecordingTab.clock)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 1000, minHeight: 800)
        .onAppear {
            // Auto-scan hardware on launch
            Task {
                await hardware.scanDevices()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Logo & Title
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)

                    Text("Professional Recording")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Text("Studio-Grade Recording System")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Panel
            HStack(spacing: 16) {
                // Clock Status
                statusBadge(
                    title: "Clock",
                    value: clock.isRunning ? "Running" : "Stopped",
                    color: clock.isRunning ? .green : .gray
                )

                Divider().frame(height: 30)

                // Tempo
                statusBadge(
                    title: "Tempo",
                    value: "\(Int(clock.tempo)) BPM",
                    color: .blue
                )

                Divider().frame(height: 30)

                // Sample Rate
                statusBadge(
                    title: "Sample Rate",
                    value: "\(Int(clock.sampleRate)) Hz",
                    color: .purple
                )

                Divider().frame(height: 30)

                // Latency
                statusBadge(
                    title: "Latency",
                    value: String(format: "%.1f ms", monitoring.measuredLatency),
                    color: monitoring.measuredLatency < 5 ? .green : .orange
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func statusBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(RecordingTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconForTab(tab))
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.red.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .red : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.gray.opacity(0.05))
    }

    private func iconForTab(_ tab: RecordingTab) -> String {
        switch tab {
        case .transport: return "play.circle"
        case .midiTracks: return "music.note.list"
        case .monitoring: return "headphones"
        case .hardware: return "cube.box"
        case .clock: return "timer"
        }
    }

    // MARK: - Transport View

    private var transportView: some View {
        VStack(spacing: 24) {
            // Transport Controls
            GroupBox("Transport") {
                VStack(spacing: 20) {
                    // Play/Stop/Record Buttons
                    HStack(spacing: 16) {
                        Button {
                            if clock.isRunning {
                                clock.stop()
                            } else {
                                clock.start()
                            }
                        } label: {
                            Label(clock.isRunning ? "Stop" : "Play",
                                  systemImage: clock.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(clock.isRunning ? .red : .green)

                        Button {
                            recorder.toggleRecording()
                        } label: {
                            Label(recorder.isRecording ? "Stop Recording" : "Record",
                                  systemImage: "record.circle.fill")
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(recorder.activeTrack == nil)
                    }

                    // Position Display
                    HStack(spacing: 20) {
                        // Bar:Beat:Tick
                        VStack(spacing: 4) {
                            Text("Position")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%03d:%d.%02d",
                                       clock.currentBar + 1,
                                       Int(clock.currentBeat.truncatingRemainder(dividingBy: Double(clock.timeSignature.numerator))) + 1,
                                       Int((clock.currentBeat.truncatingRemainder(dividingBy: 1)) * 100)))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                        }

                        Divider().frame(height: 60)

                        // MTC
                        VStack(spacing: 4) {
                            Text("MTC")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(clock.currentMTC.description)
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        }

                        Divider().frame(height: 60)

                        // Samples
                        VStack(spacing: 4) {
                            Text("Samples")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(clock.currentSample)")
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                        }
                    }
                }
                .padding()
            }

            HStack(spacing: 24) {
                // Tempo Control
                GroupBox("Tempo") {
                    VStack(spacing: 12) {
                        Text("\(Int(clock.tempo))")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                        Text("BPM")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Slider(value: Binding(
                            get: { clock.tempo },
                            set: { MasterClockSystem.shared.tempo = $0 }
                        ), in: 40...240, step: 1)
                    }
                    .padding()
                }

                // Time Signature
                GroupBox("Time Signature") {
                    HStack(spacing: 12) {
                        ForEach([(3, 4), (4, 4), (5, 4), (6, 8), (7, 8)], id: \.0) { num, den in
                            Button {
                                clock.timeSignature = MasterClockSystem.TimeSignature(numerator: num, denominator: den)
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(num)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    Divider()
                                    Text("\(den)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                }
                                .frame(width: 50, height: 50)
                                .background(
                                    clock.timeSignature.numerator == num &&
                                    clock.timeSignature.denominator == den ?
                                    Color.red.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - MIDI Tracks View

    private var midiTracksView: some View {
        VStack(spacing: 16) {
            // Toolbar
            HStack {
                Button {
                    let channel = recorder.midiTracks.count + 1
                    recorder.addTrack(name: "MIDI \(channel)", channel: channel)
                } label: {
                    Label("Add Track", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                // Record Mode
                Picker("Record Mode", selection: $recorder.recordMode) {
                    ForEach(RealtimeMIDIRecorder.RecordMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                // Quantization
                Picker("Quantize", selection: $recorder.quantization) {
                    ForEach(RealtimeMIDIRecorder.Quantization.allCases, id: \.self) { quant in
                        Text(quant.rawValue).tag(quant)
                    }
                }
                .frame(width: 150)
            }
            .padding(.horizontal)

            // Track List
            if recorder.midiTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No MIDI Tracks")
                        .font(.headline)
                    Text("Click 'Add Track' to create a MIDI track")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(recorder.midiTracks) { track in
                            MIDITrackRow(track: track, recorder: recorder)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }

    // MARK: - Monitoring View

    private var monitoringView: some View {
        VStack(spacing: 24) {
            // Monitoring Controls
            GroupBox("Direct Monitoring") {
                VStack(spacing: 16) {
                    HStack {
                        Toggle("Enable Direct Monitoring", isOn: Binding(
                            get: { monitoring.isEnabled },
                            set: { enabled in
                                if enabled {
                                    try? monitoring.enable()
                                } else {
                                    monitoring.disable()
                                }
                            }
                        ))
                        .toggleStyle(.switch)

                        Spacer()

                        // Monitor Mode
                        Picker("Mode", selection: $monitoring.monitorMode) {
                            ForEach(DirectMonitoringSystem.MonitorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .frame(width: 300)
                    }

                    if monitoring.isEnabled {
                        HStack(spacing: 20) {
                            metricBox(title: "Buffer Size", value: "\(monitoring.hardwareBufferSize) samples")
                            metricBox(title: "Latency", value: String(format: "%.2f ms", monitoring.measuredLatency))
                            metricBox(title: "DSP Load", value: String(format: "%.1f%%", monitoring.dspLoad))
                        }
                    }
                }
                .padding()
            }

            // Monitor Inputs
            GroupBox("Monitor Inputs") {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(monitoring.monitorInputs) { input in
                            MonitorInputRow(input: input)
                        }

                        if monitoring.monitorInputs.isEmpty {
                            VStack(spacing: 8) {
                                Text("No Monitor Inputs")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Button("Add Input") {
                                    monitoring.addInput(name: "Input \(monitoring.monitorInputs.count + 1)",
                                                      channel: monitoring.monitorInputs.count)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(40)
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .padding()
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Hardware View

    private var hardwareView: some View {
        VStack(spacing: 24) {
            // Hardware Toolbar
            HStack {
                Text("\(hardware.midiDevices.count) MIDI • \(hardware.audioDevices.count) Audio")
                    .font(.headline)

                Spacer()

                if hardware.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning...")
                        .font(.caption)
                }

                Button {
                    Task {
                        await hardware.scanDevices()
                    }
                } label: {
                    Label("Scan Devices", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(hardware.isScanning)

                Button {
                    hardware.configureTightDrumRecording()
                } label: {
                    Label("Tight Drums", systemImage: "waveform")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Device Lists
            HStack(spacing: 16) {
                // MIDI Devices
                GroupBox("MIDI Devices") {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(hardware.midiDevices) { device in
                                MIDIDeviceRow(device: device)
                            }

                            if hardware.midiDevices.isEmpty {
                                Text("No MIDI devices found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }

                // Audio Devices
                GroupBox("Audio Devices") {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(hardware.audioDevices) { device in
                                AudioDeviceRow(device: device)
                            }

                            if hardware.audioDevices.isEmpty {
                                Text("No audio devices found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - Clock & Sync View

    private var clockSyncView: some View {
        VStack(spacing: 24) {
            // Clock Source
            GroupBox("Clock Source") {
                VStack(spacing: 16) {
                    Picker("Source", selection: $clock.clockSource) {
                        ForEach(MasterClockSystem.ClockSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(clock.clockSource.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }

            // Sync Settings
            HStack(spacing: 16) {
                GroupBox("MIDI Sync") {
                    VStack(spacing: 12) {
                        Toggle("MIDI Clock", isOn: $clock.midiClockEnabled)
                        Divider()
                        Toggle("MIDI Time Code (MTC)", isOn: $clock.mtcEnabled)
                        Divider()
                        Toggle("MIDI Machine Control (MMC)", isOn: $clock.mmcEnabled)
                    }
                    .padding()
                }

                GroupBox("External Sync") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(syncStatusColor)
                                    .frame(width: 8, height: 8)
                                Text(clock.externalSyncStatus.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }

                        Divider()

                        HStack {
                            Text("Latency Compensation:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f ms", clock.totalLatency))
                                .font(.caption.monospaced())
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .padding()
    }

    private var syncStatusColor: Color {
        switch clock.externalSyncStatus {
        case .disconnected: return .gray
        case .searching: return .yellow
        case .locked: return .green
        case .drifting: return .orange
        case .error: return .red
        }
    }
}

// MARK: - MIDI Track Row

struct MIDITrackRow: View {
    let track: RealtimeMIDIRecorder.MIDITrack
    @ObservedObject var recorder: RealtimeMIDIRecorder

    var body: some View {
        HStack(spacing: 12) {
            // Color stripe
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4)

            // Record Arm
            Button {
                recorder.armTrack(track.id)
            } label: {
                Image(systemName: track.isArmed ? "record.circle.fill" : "record.circle")
                    .foregroundColor(track.isArmed ? .red : .gray)
            }
            .buttonStyle(.plain)

            // Mute/Solo
            HStack(spacing: 4) {
                Button("M") {
                    // Toggle mute
                }
                .frame(width: 24, height: 24)
                .background(track.isMuted ? Color.orange : Color.gray.opacity(0.2))
                .cornerRadius(4)

                Button("S") {
                    // Toggle solo
                }
                .frame(width: 24, height: 24)
                .background(track.isSolo ? Color.yellow : Color.gray.opacity(0.2))
                .cornerRadius(4)
            }
            .font(.caption)
            .buttonStyle(.plain)

            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Channel \(track.channel) • \(track.events.count) events")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Takes
            if !track.takes.isEmpty {
                Text("\(track.takes.count) takes")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            // Clear
            Button {
                recorder.clearTrack(track.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding()
        .background(track.isArmed ? Color.red.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Monitor Input Row

struct MonitorInputRow: View {
    let input: DirectMonitoringSystem.MonitorInput

    var body: some View {
        HStack(spacing: 12) {
            // Level Meter
            VStack(spacing: 2) {
                ForEach(0..<10) { i in
                    let level = Int(input.peakLevel * 10)
                    Rectangle()
                        .fill(i < level ? (i < 7 ? Color.green : (i < 9 ? Color.yellow : Color.red)) : Color.gray.opacity(0.2))
                        .frame(height: 3)
                }
            }
            .frame(width: 20, height: 40)

            // Input Info
            VStack(alignment: .leading, spacing: 2) {
                Text(input.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Ch \(input.channel + 1)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Effects Count
            if !input.effectChain.isEmpty {
                Text("\(input.effectChain.count) FX")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            // Volume
            Slider(value: .constant(input.volume), in: 0...1)
                .frame(width: 100)

            // Mute
            Button {
                // Toggle mute
            } label: {
                Image(systemName: input.muted ? "speaker.slash.fill" : "speaker.wave.2")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - MIDI Device Row

struct MIDIDeviceRow: View {
    let device: HardwareIntegrationManager.MIDIDevice

    var body: some View {
        HStack {
            Image(systemName: "pianokeys")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(device.manufacturer)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Features
            HStack(spacing: 4) {
                ForEach(device.features, id: \.self) { feature in
                    Text(feature.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            Circle()
                .fill(device.isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Audio Device Row

struct AudioDeviceRow: View {
    let device: HardwareIntegrationManager.AudioDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hifispeaker.fill")
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(device.manufacturer)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(device.transportType.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                infoLabel(title: "Sample Rate", value: "\(Int(device.currentSampleRate)) Hz")
                infoLabel(title: "Inputs", value: "\(device.inputChannels)")
                infoLabel(title: "Outputs", value: "\(device.outputChannels)")
                infoLabel(title: "Latency", value: String(format: "%.1f ms", device.latency.total))
            }
        }
        .padding(.vertical, 8)
    }

    private func infoLabel(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ProfessionalRecordingControlPanel()
        .frame(width: 1200, height: 900)
}
