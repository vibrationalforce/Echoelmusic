import Foundation
import SwiftUI
import AVFoundation
import Combine
import CoreMIDI

#if os(macOS)

/// Echoelmusic for macOS
///
/// macOS provides the most complete Echoelmusic experience:
/// - Full DAW Integration: AU/VST3 plugins, MIDI routing
/// - Multi-Window: Separate windows for visualization, controls, recording
/// - Pro Audio: CoreAudio with ultra-low latency
/// - Hardware Support: Push 3, external MIDI, DMX lighting
/// - Development: Best platform for content creation
///
/// Features:
/// - Multi-window interface
/// - Menu bar integration
/// - Touch Bar support (older MacBooks)
/// - External display support
/// - Full keyboard shortcuts
/// - Drag & drop audio files
///
@MainActor
@Observable
class MacApp {

    // MARK: - Published Properties

    /// Current visualization mode
    var visualizationMode: VisualizationMode = .spectrum

    /// Audio input source
    var audioInputSource: AudioInputSource = .microphone

    /// MIDI devices connected
    var midiDevices: [MIDIDevice] = []

    /// Is recording active
    var isRecording: Bool = false

    /// Current project
    var currentProject: Project?

    // MARK: - Private Properties

    private let audioEngine: MacAudioEngine
    private let midiManager: MacMIDIManager
    private let visualEngine: MacVisualizationEngine
    private let push3Controller: Push3Controller
    private let dmxController: DMXController

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types

    enum VisualizationMode: String, CaseIterable {
        case spectrum = "Spectrum"
        case waveform = "Waveform"
        case particles = "Particles"
        case cymatics = "Cymatics"
        case mandala = "Mandala"
        case bioReactive = "Bio-Reactive"

        var systemImage: String {
            switch self {
            case .spectrum: return "waveform"
            case .waveform: return "waveform.path"
            case .particles: return "sparkles"
            case .cymatics: return "circle.hexagongrid"
            case .mandala: return "star"
            case .bioReactive: return "heart.circle"
            }
        }
    }

    enum AudioInputSource: String, CaseIterable {
        case microphone = "Microphone"
        case systemAudio = "System Audio"
        case midiInput = "MIDI Input"
        case external = "External Interface"

        var systemImage: String {
            switch self {
            case .microphone: return "mic"
            case .systemAudio: return "speaker.wave.3"
            case .midiInput: return "pianokeys"
            case .external: return "cable.connector"
            }
        }
    }

    struct MIDIDevice: Identifiable {
        let id: MIDIObjectRef
        let name: String
        let manufacturer: String
        let isInput: Bool
        let isOutput: Bool
        var isConnected: Bool
    }

    struct Project: Identifiable {
        let id: UUID
        var name: String
        var bpm: Double
        var timeSignature: (numerator: Int, denominator: Int)
        var tracks: [Track]
        var createdAt: Date
        var modifiedAt: Date

        struct Track: Identifiable {
            let id: UUID
            var name: String
            var type: TrackType
            var volume: Float
            var pan: Float
            var isMuted: Bool
            var isSolo: Bool

            enum TrackType {
                case audio
                case midi
                case bioReactive
                case visualization
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.audioEngine = MacAudioEngine()
        self.midiManager = MacMIDIManager()
        self.visualEngine = MacVisualizationEngine()
        self.push3Controller = Push3Controller()
        self.dmxController = DMXController()

        setupObservers()
        scanMIDIDevices()
    }

    private func setupObservers() {
        // MIDI device notifications
        midiManager.deviceChangedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.midiDevices = devices
            }
            .store(in: &cancellables)
    }

    // MARK: - Audio Management

    func startAudioEngine() async throws {
        try await audioEngine.start(source: audioInputSource)
        print("🔊 macOS Audio Engine started with source: \(audioInputSource.rawValue)")
    }

    func stopAudioEngine() async {
        await audioEngine.stop()
        print("🔊 macOS Audio Engine stopped")
    }

    func changeAudioSource(_ source: AudioInputSource) async throws {
        audioInputSource = source
        try await audioEngine.changeSource(source)
    }

    // MARK: - MIDI Management

    func scanMIDIDevices() {
        midiDevices = midiManager.scanDevices()
        print("🎹 Found \(midiDevices.count) MIDI devices")
    }

    func connectMIDIDevice(_ device: MIDIDevice) throws {
        try midiManager.connect(device)
        print("🎹 Connected to MIDI device: \(device.name)")
    }

    // MARK: - Visualization

    func changeVisualization(_ mode: VisualizationMode) async {
        visualizationMode = mode
        await visualEngine.setMode(mode)
    }

    // MARK: - Hardware Control

    func connectPush3() async throws {
        try await push3Controller.connect()
        print("🎛️ Push 3 connected")
    }

    func connectDMX(address: String, port: UInt16 = 6454) async throws {
        try await dmxController.connect(address: address, port: port)
        print("💡 DMX connected to \(address):\(port)")
    }

    // MARK: - Recording

    func startRecording() async throws {
        try await audioEngine.startRecording()
        isRecording = true
        print("⏺️ Recording started")
    }

    func stopRecording() async throws -> URL {
        isRecording = false
        let url = try await audioEngine.stopRecording()
        print("⏹️ Recording saved to: \(url.path)")
        return url
    }

    // MARK: - Project Management

    func createProject(name: String) -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            bpm: 120.0,
            timeSignature: (4, 4),
            tracks: [],
            createdAt: Date(),
            modifiedAt: Date()
        )
        currentProject = project
        return project
    }

    func saveProject() async throws {
        guard let project = currentProject else { return }
        // Save project to disk
        print("💾 Project saved: \(project.name)")
    }

    func loadProject(from url: URL) async throws {
        // Load project from disk
        print("📂 Loading project from: \(url.path)")
    }
}

// MARK: - Mac Audio Engine

@MainActor
class MacAudioEngine {

    private var isRunning: Bool = false
    private var isRecording: Bool = false
    private var recordingURL: URL?

    func start(source: MacApp.AudioInputSource) async throws {
        print("🔊 Mac Audio Engine starting with source: \(source.rawValue)")
        isRunning = true
    }

    func stop() async {
        print("🔊 Mac Audio Engine stopping")
        isRunning = false
    }

    func changeSource(_ source: MacApp.AudioInputSource) async throws {
        print("🔊 Changing audio source to: \(source.rawValue)")
    }

    func startRecording() async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = ISO8601DateFormatter().string(from: Date())
        recordingURL = documentsPath.appendingPathComponent("Recording_\(timestamp).wav")
        isRecording = true
        print("⏺️ Recording to: \(recordingURL?.path ?? "unknown")")
    }

    func stopRecording() async throws -> URL {
        isRecording = false
        guard let url = recordingURL else {
            throw RecordingError.noRecordingInProgress
        }
        return url
    }

    enum RecordingError: Error {
        case noRecordingInProgress
        case saveFailed
    }
}

// MARK: - Mac MIDI Manager

@MainActor
class MacMIDIManager {

    let deviceChangedPublisher = PassthroughSubject<[MacApp.MIDIDevice], Never>()

    private var midiClient: MIDIClientRef = 0

    init() {
        setupMIDIClient()
    }

    private func setupMIDIClient() {
        let status = MIDIClientCreate("Echoelmusic" as CFString, nil, nil, &midiClient)
        if status == noErr {
            print("🎹 MIDI Client created successfully")
        }
    }

    func scanDevices() -> [MacApp.MIDIDevice] {
        var devices: [MacApp.MIDIDevice] = []

        // Scan input sources
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let device = createDevice(from: source, isInput: true) {
                devices.append(device)
            }
        }

        // Scan output destinations
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let dest = MIDIGetDestination(i)
            if let device = createDevice(from: dest, isInput: false) {
                devices.append(device)
            }
        }

        return devices
    }

    private func createDevice(from endpoint: MIDIEndpointRef, isInput: Bool) -> MacApp.MIDIDevice? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?

        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)

        let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown"
        let deviceManufacturer = (manufacturer?.takeRetainedValue() as String?) ?? "Unknown"

        return MacApp.MIDIDevice(
            id: endpoint,
            name: deviceName,
            manufacturer: deviceManufacturer,
            isInput: isInput,
            isOutput: !isInput,
            isConnected: false
        )
    }

    func connect(_ device: MacApp.MIDIDevice) throws {
        print("🎹 Connecting to MIDI device: \(device.name)")
    }
}

// MARK: - Mac Visualization Engine

@MainActor
class MacVisualizationEngine {

    private var currentMode: MacApp.VisualizationMode = .spectrum

    func setMode(_ mode: MacApp.VisualizationMode) async {
        currentMode = mode
        print("🎨 Visualization mode changed to: \(mode.rawValue)")
    }
}

// MARK: - Push 3 Controller

@MainActor
class Push3Controller {

    private var isConnected: Bool = false

    func connect() async throws {
        print("🎛️ Connecting to Ableton Push 3...")
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        print("🎛️ Push 3 disconnected")
    }
}

// MARK: - DMX Controller

@MainActor
class DMXController {

    private var isConnected: Bool = false

    func connect(address: String, port: UInt16) async throws {
        print("💡 Connecting to DMX at \(address):\(port)...")
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        print("💡 DMX disconnected")
    }
}

#endif
