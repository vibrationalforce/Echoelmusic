import SwiftUI

/// NDI Settings View - Configure NDI audio streaming
///
/// Features:
/// - Enable/Disable NDI output
/// - Configure source name and quality
/// - Monitor connected receivers
/// - View streaming statistics
/// - Discover NDI devices on network
///
/// Usage:
/// ```swift
/// NDISettingsView(controlHub: hub)
/// ```
@available(iOS 15.0, *)
struct NDISettingsView: View {

    @ObservedObject var config = NDIConfiguration.shared
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var discovery: NDIDeviceDiscovery

    @State private var showingAdvancedSettings = false
    @State private var showingDeviceList = false

    // Refresh timer for statistics
    @State private var statisticsTimer: Timer?

    init(controlHub: UnifiedControlHub) {
        self.controlHub = controlHub
        self.discovery = NDIDeviceDiscovery()
    }

    var body: some View {
        Form {
            // MARK: - Status Section
            Section {
                HStack {
                    Image(systemName: controlHub.isNDIEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(controlHub.isNDIEnabled ? .green : .gray)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NDI Audio Output")
                            .font(.headline)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { controlHub.isNDIEnabled },
                        set: { _ in controlHub.toggleNDI() }
                    ))
                    .labelsHidden()
                }
            } header: {
                Text("Status")
            } footer: {
                Text("Stream audio to NDI-compatible devices on your network (DAWs, OBS, vMix, etc.)")
            }

            // MARK: - Configuration Section
            if controlHub.isNDIEnabled {
                Section("Configuration") {
                    // Source Name
                    HStack {
                        Label("Source Name", systemImage: "wifi")
                        Spacer()
                        TextField("BLAB iOS", text: $config.sourceName)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                    }

                    // Preset
                    Picker("Quality Preset", selection: Binding(
                        get: { getCurrentPreset() },
                        set: { controlHub.applyNDIPreset($0) }
                    )) {
                        ForEach(NDIConfiguration.Preset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }

                    // Biometric Metadata
                    Toggle("Include Biometric Data", isOn: $config.sendBiometricMetadata)
                }

                // MARK: - Connection Status
                Section {
                    HStack {
                        Label("Connected Receivers", systemImage: "network")
                        Spacer()
                        Text("\(controlHub.ndiConnectionCount)")
                            .font(.headline)
                            .foregroundColor(controlHub.hasNDIConnections ? .green : .secondary)
                    }

                    if let stats = controlHub.ndiStatistics {
                        HStack {
                            Label("Frames Sent", systemImage: "waveform")
                            Spacer()
                            Text("\(stats.framesSent)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Label("Data Sent", systemImage: "arrow.up.circle")
                            Spacer()
                            Text(stats.bytesSent.formatted(.byteCount(style: .memory)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if stats.droppedFrames > 0 {
                            HStack {
                                Label("Dropped Frames", systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(stats.droppedFrames)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Statistics update every second while streaming")
                }

                // MARK: - Device Discovery
                Section {
                    Button {
                        showingDeviceList.toggle()
                    } label: {
                        HStack {
                            Label("Discovered Devices", systemImage: "list.bullet")
                            Spacer()
                            Text("\(discovery.devices.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Network")
                } footer: {
                    Text("NDI devices automatically discovered on your local network")
                }

                // MARK: - Advanced Settings
                Section {
                    Button {
                        showingAdvancedSettings.toggle()
                    } label: {
                        HStack {
                            Label("Advanced Settings", systemImage: "gearshape.2")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }

            // MARK: - Quick Actions
            Section {
                Button {
                    controlHub.printNDIStatistics()
                } label: {
                    Label("Print Statistics to Console", systemImage: "doc.text")
                }

                Button {
                    config.resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
                .foregroundColor(.orange)
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("NDI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdvancedSettings) {
            NDIAdvancedSettingsView(config: config)
        }
        .sheet(isPresented: $showingDeviceList) {
            NDIDeviceListView(discovery: discovery, controlHub: controlHub)
        }
        .onAppear {
            // Start discovery
            discovery.start()

            // Start statistics update timer
            statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Force view refresh
                objectWillChange.send()
            }
        }
        .onDisappear {
            // Stop discovery
            discovery.stop()

            // Stop timer
            statisticsTimer?.invalidate()
            statisticsTimer = nil
        }
    }

    // MARK: - Helpers

    private var statusText: String {
        if controlHub.isNDIEnabled {
            if controlHub.hasNDIConnections {
                return "Streaming to \(controlHub.ndiConnectionCount) receiver\(controlHub.ndiConnectionCount == 1 ? "" : "s")"
            } else {
                return "Ready - No receivers connected"
            }
        } else {
            return "Disabled"
        }
    }

    private func getCurrentPreset() -> NDIConfiguration.Preset {
        // Determine current preset from settings
        switch (config.sampleRate, config.bufferSize) {
        case (44100, 128): return .lowLatency
        case (48000, 256): return .balanced
        case (96000, 512): return .highQuality
        case (48000, 256) where config.bitDepth == 24: return .broadcast
        default: return .balanced
        }
    }
}

// MARK: - Advanced Settings View

@available(iOS 15.0, *)
struct NDIAdvancedSettingsView: View {
    @ObservedObject var config: NDIConfiguration
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Audio Format") {
                    Picker("Sample Rate", selection: $config.sampleRate) {
                        Text("44.1 kHz").tag(44100.0)
                        Text("48 kHz").tag(48000.0)
                        Text("88.2 kHz").tag(88200.0)
                        Text("96 kHz").tag(96000.0)
                    }

                    Stepper("Channels: \(config.channelCount)", value: $config.channelCount, in: 1...64)

                    Picker("Bit Depth", selection: $config.bitDepth) {
                        Text("16-bit").tag(16)
                        Text("24-bit").tag(24)
                        Text("32-bit").tag(32)
                    }

                    Toggle("Use Floating Point", isOn: $config.useFloat)
                }

                Section("Performance") {
                    Picker("Buffer Size", selection: $config.bufferSize) {
                        Text("64 frames (ultra-low)").tag(64)
                        Text("128 frames (low)").tag(128)
                        Text("256 frames (balanced)").tag(256)
                        Text("512 frames (stable)").tag(512)
                        Text("1024 frames (safe)").tag(1024)
                    }

                    Stepper("Max Queue: \(config.maxQueueSize)", value: $config.maxQueueSize, in: 5...50)
                }

                Section("Metadata") {
                    Toggle("Send Biometric Data", isOn: $config.sendBiometricMetadata)

                    HStack {
                        Text("Update Interval")
                        Spacer()
                        Text(String(format: "%.1fs", config.metadataInterval))
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $config.metadataInterval, in: 0.1...5.0, step: 0.1)
                }

                Section("Network") {
                    TextField("Groups (comma-separated)", text: $config.groups)

                    Stepper("Multicast TTL: \(config.multicastTTL)", value: $config.multicastTTL, in: 1...255)

                    Toggle("Prefer TCP over UDP", isOn: $config.preferTCP)
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Device List View

@available(iOS 15.0, *)
struct NDIDeviceListView: View {
    @ObservedObject var discovery: NDIDeviceDiscovery
    @ObservedObject var controlHub: UnifiedControlHub
    @Environment(\.dismiss) var dismiss

    @State private var showingAddDevice = false
    @State private var newDeviceName = ""
    @State private var newDeviceIP = ""
    @State private var newDevicePort = "5960"

    var body: some View {
        NavigationView {
            List {
                if discovery.devices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No NDI Devices Found")
                            .font(.headline)

                        Text("Make sure NDI devices are on the same network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(discovery.devices) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.headline)

                            HStack {
                                Image(systemName: "network")
                                    .font(.caption)
                                Text("\(device.ipAddress):\(device.port)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                controlHub.removeNDIDevice(id: device.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("NDI Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddDevice.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDevice) {
                addDeviceSheet
            }
        }
    }

    private var addDeviceSheet: some View {
        NavigationView {
            Form {
                Section("Device Information") {
                    TextField("Name", text: $newDeviceName)
                    TextField("IP Address", text: $newDeviceIP)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", text: $newDevicePort)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddDevice = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let port = UInt16(newDevicePort) {
                            controlHub.addNDIDevice(
                                name: newDeviceName,
                                ipAddress: newDeviceIP,
                                port: port
                            )
                        }
                        showingAddDevice = false
                    }
                    .disabled(newDeviceName.isEmpty || newDeviceIP.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct NDISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NDISettingsView(controlHub: UnifiedControlHub())
        }
    }
}
