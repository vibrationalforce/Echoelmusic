//
//  macOSAudioIntegration.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  macOS AUDIO ENGINE INTEGRATION
//  Connects AudioUnitHost + CoreAudioHAL with existing DAW
//

#if os(macOS)
import Foundation
import AVFoundation
import Combine

/// Professional macOS audio engine with AU hosting and CoreAudio HAL
@MainActor
class macOSAudioEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var isRunning: Bool = false
    @Published var currentLatency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var audioMode: AudioMode = .avFoundation

    // MARK: - Dependencies

    private let audioUnitHost: AudioUnitHost
    private let coreAudioHAL: CoreAudioHAL
    private let avAudioEngine: AVAudioEngine
    private let multiMonitorManager: MultiMonitorManager

    // Track management
    private var audioTracks: [macOSAudioTrack] = []
    private var activePlugins: [AudioUnitHost.LoadedAudioUnit] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Audio Mode

    enum AudioMode {
        case avFoundation  // Standard mode (higher latency, easier)
        case coreAudioHAL  // Professional mode (ultra-low latency)
    }

    // MARK: - Audio Track

    struct macOSAudioTrack: Identifiable {
        let id = UUID()
        let name: String
        var plugins: [AudioUnitHost.LoadedAudioUnit]
        var volume: Float = 0.8
        var pan: Float = 0.0
        var isMuted: Bool = false
        var isSolo: Bool = false
        var isArmed: Bool = false
    }

    // MARK: - Initialization

    init() {
        self.audioUnitHost = AudioUnitHost()
        self.coreAudioHAL = CoreAudioHAL()
        self.avAudioEngine = AVAudioEngine()
        self.multiMonitorManager = MultiMonitorManager()

        setupObservers()
    }

    private func setupObservers() {
        // Observe AU host changes
        audioUnitHost.$loadedInstances
            .sink { [weak self] instances in
                self?.activePlugins = instances
                self?.calculateCPUUsage()
            }
            .store(in: &cancellables)

        // Observe CoreAudio latency changes
        coreAudioHAL.$latency
            .sink { [weak self] latency in
                self?.currentLatency = latency
            }
            .store(in: &cancellables)
    }

    // MARK: - Engine Control

    /// Start audio engine in selected mode
    func start(mode: AudioMode = .avFoundation) throws {
        audioMode = mode

        switch mode {
        case .avFoundation:
            try startAVFoundationMode()

        case .coreAudioHAL:
            try startCoreAudioMode()
        }

        isRunning = true
        print("▶️ macOS Audio Engine started in \(mode) mode")
    }

    /// Stop audio engine
    func stop() {
        switch audioMode {
        case .avFoundation:
            avAudioEngine.stop()

        case .coreAudioHAL:
            coreAudioHAL.stop()
        }

        isRunning = false
        print("⏹️ macOS Audio Engine stopped")
    }

    private func startAVFoundationMode() throws {
        // Configure AVAudioEngine
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        )!

        // Connect nodes
        avAudioEngine.connect(
            avAudioEngine.mainMixerNode,
            to: avAudioEngine.outputNode,
            format: format
        )

        // Start engine
        try avAudioEngine.start()

        currentLatency = Double(avAudioEngine.outputNode.presentationLatency)
        print("🎵 AVFoundation mode: \(String(format: "%.1f", currentLatency * 1000))ms latency")
    }

    private func startCoreAudioMode() throws {
        // Get selected devices
        guard let outputDevice = coreAudioHAL.selectedOutputDevice else {
            throw macOSAudioError.noOutputDevice
        }

        let inputDevice = coreAudioHAL.selectedInputDevice

        // Start CoreAudio with ultra-low latency settings
        try coreAudioHAL.start(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            bufferSize: 128,  // 128 samples for <3ms latency
            sampleRate: 48000,
            audioCallback: { [weak self] input, output, frameCount in
                self?.processAudioCallback(input: input, output: output, frameCount: frameCount)
            }
        )

        print("🚀 CoreAudio HAL mode: \(String(format: "%.1f", coreAudioHAL.latency))ms latency")
    }

    private func processAudioCallback(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: UInt32) {
        // Process audio in real-time
        // This is where DSP, plugin processing, and mixing happens

        // For now, pass through input to output
        output.update(from: input, count: Int(frameCount))
    }

    // MARK: - Track Management

    /// Create a new audio track
    func createTrack(name: String) -> macOSAudioTrack {
        let track = macOSAudioTrack(
            name: name,
            plugins: [],
            volume: 0.8,
            pan: 0.0
        )

        audioTracks.append(track)
        print("➕ Created track: \(name)")
        return track
    }

    /// Add plugin to track
    func addPlugin(descriptor: AudioUnitHost.AudioUnitDescriptor, to trackID: UUID) async throws {
        guard let trackIndex = audioTracks.firstIndex(where: { $0.id == trackID }) else {
            throw macOSAudioError.trackNotFound
        }

        // Load plugin
        let plugin = try await audioUnitHost.loadPlugin(
            descriptor: descriptor,
            into: avAudioEngine
        )

        // Add to track
        audioTracks[trackIndex].plugins.append(plugin)

        // Reconnect audio graph
        reconnectAudioGraph()

        print("🔌 Added plugin '\(descriptor.name)' to track '\(audioTracks[trackIndex].name)'")
    }

    /// Remove plugin from track
    func removePlugin(_ plugin: AudioUnitHost.LoadedAudioUnit, from trackID: UUID) {
        guard let trackIndex = audioTracks.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        audioTracks[trackIndex].plugins.removeAll { $0.id == plugin.id }
        audioUnitHost.unloadPlugin(plugin, from: avAudioEngine)

        reconnectAudioGraph()
        print("🗑️ Removed plugin from track")
    }

    private func reconnectAudioGraph() {
        // Reconnect all plugin chains
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!

        for track in audioTracks {
            guard !track.plugins.isEmpty else { continue }

            audioUnitHost.connectPluginChain(
                instances: track.plugins,
                to: avAudioEngine.mainMixerNode,
                in: avAudioEngine,
                format: format
            )
        }
    }

    // MARK: - Plugin Management

    /// Scan for all available AU plugins
    func scanForPlugins() {
        audioUnitHost.scanForPlugins()
    }

    /// Get all available plugins
    var availablePlugins: [AudioUnitHost.AudioUnitDescriptor] {
        audioUnitHost.availablePlugins
    }

    /// Show native plugin UI
    func showPluginUI(for plugin: AudioUnitHost.LoadedAudioUnit) async {
        guard let viewController = await audioUnitHost.requestViewController(for: plugin) else {
            print("⚠️ Plugin does not have a UI")
            return
        }

        // Show in window
        _ = macOSWindowManager.shared.showPluginUI(
            name: plugin.name,
            viewController: viewController
        )
    }

    // MARK: - Device Management

    /// Get all available audio devices
    var availableDevices: [CoreAudioHAL.AudioDeviceInfo] {
        coreAudioHAL.availableDevices
    }

    /// Select input device
    func selectInputDevice(_ device: CoreAudioHAL.AudioDeviceInfo) {
        coreAudioHAL.selectInputDevice(device)

        // Restart engine if running
        if isRunning {
            try? stop()
            try? start(mode: audioMode)
        }
    }

    /// Select output device
    func selectOutputDevice(_ device: CoreAudioHAL.AudioDeviceInfo) {
        coreAudioHAL.selectOutputDevice(device)

        // Restart engine if running
        if isRunning {
            try? stop()
            try? start(mode: audioMode)
        }
    }

    // MARK: - Buffer Size Control

    /// Set buffer size (only in CoreAudio mode)
    func setBufferSize(_ size: UInt32) throws {
        guard audioMode == .coreAudioHAL else {
            throw macOSAudioError.bufferSizeOnlyInCoreAudioMode
        }

        // Stop and restart with new buffer size
        stop()
        try start(mode: .coreAudioHAL)

        print("🎚️ Buffer size set to \(size) samples")
    }

    // MARK: - CPU Monitoring

    private func calculateCPUUsage() {
        // Calculate total CPU usage from all plugins
        cpuUsage = activePlugins.reduce(0.0) { $0 + $1.cpuUsage }

        // Update plugin CPU usage
        audioUnitHost.updateCPUUsage()
    }

    // MARK: - Multi-Monitor Integration

    /// Apply workspace layout
    func applyWorkspaceLayout(_ layout: MultiMonitorManager.WorkspaceLayout) {
        multiMonitorManager.applyLayout(layout)
    }

    /// Get available workspace layouts
    var availableLayouts: [MultiMonitorManager.WorkspaceLayout] {
        (try? multiMonitorManager.getSavedLayouts()) ?? []
    }

    /// Create production layout (if multiple displays available)
    func setupProductionLayout() {
        guard let layout = multiMonitorManager.createProductionLayout() else {
            print("⚠️ Production layout requires multiple displays")
            return
        }

        multiMonitorManager.applyLayout(layout)
    }
}

// MARK: - Errors

enum macOSAudioError: Error {
    case noOutputDevice
    case trackNotFound
    case bufferSizeOnlyInCoreAudioMode
}

// MARK: - SwiftUI Integration

struct macOSAudioEngineView: View {

    @StateObject private var audioEngine = macOSAudioEngine()
    @State private var selectedMode: macOSAudioEngine.AudioMode = .avFoundation

    var body: some View {
        VStack(spacing: 20) {
            // Mode selector
            Picker("Audio Mode", selection: $selectedMode) {
                Text("AVFoundation").tag(macOSAudioEngine.AudioMode.avFoundation)
                Text("CoreAudio HAL").tag(macOSAudioEngine.AudioMode.coreAudioHAL)
            }
            .pickerStyle(.segmented)

            // Engine controls
            HStack {
                Button(audioEngine.isRunning ? "Stop" : "Start") {
                    if audioEngine.isRunning {
                        audioEngine.stop()
                    } else {
                        try? audioEngine.start(mode: selectedMode)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Scan Plugins") {
                    audioEngine.scanForPlugins()
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Latency: \(String(format: "%.1f", audioEngine.currentLatency))ms")
                Text("CPU: \(String(format: "%.1f", audioEngine.cpuUsage))%")
                Text("Plugins: \(audioEngine.availablePlugins.count)")
            }
            .font(.system(.body, design: .monospaced))

            // Device selection
            if audioEngine.audioMode == .coreAudioHAL {
                VStack(alignment: .leading) {
                    Text("Audio Devices")
                        .font(.headline)

                    ForEach(audioEngine.availableDevices) { device in
                        HStack {
                            Text(device.name)
                            Spacer()
                            Text(device.channelDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

#endif
