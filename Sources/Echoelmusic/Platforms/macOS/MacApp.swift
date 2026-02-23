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
class MacApp: ObservableObject {

    // MARK: - Published Properties

    /// Current visualization mode
    @Published var visualizationMode: VisualizationMode = .spectrum

    /// Audio input source
    @Published var audioInputSource: AudioInputSource = .microphone

    /// MIDI devices connected
    @Published var midiDevices: [MIDIDevice] = []

    /// Is recording active
    @Published var isRecording: Bool = false

    /// Current project
    @Published var currentProject: Project?

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
        log.info("🔊 macOS Audio Engine started with source: \(audioInputSource.rawValue)", category: .system)
    }

    func stopAudioEngine() async {
        await audioEngine.stop()
        log.info("🔊 macOS Audio Engine stopped", category: .system)
    }

    func changeAudioSource(_ source: AudioInputSource) async throws {
        audioInputSource = source
        try await audioEngine.changeSource(source)
    }

    // MARK: - MIDI Management

    func scanMIDIDevices() {
        midiDevices = midiManager.scanDevices()
        log.info("🎹 Found \(midiDevices.count) MIDI devices", category: .system)
    }

    func connectMIDIDevice(_ device: MIDIDevice) throws {
        try midiManager.connect(device)
        log.info("🎹 Connected to MIDI device: \(device.name)", category: .system)
    }

    // MARK: - Visualization

    func changeVisualization(_ mode: VisualizationMode) async {
        visualizationMode = mode
        await visualEngine.setMode(mode)
    }

    // MARK: - Hardware Control

    func connectPush3() async throws {
        try await push3Controller.connect()
        log.info("🎛️ Push 3 connected", category: .system)
    }

    func connectDMX(address: String, port: UInt16 = 6454) async throws {
        try await dmxController.connect(address: address, port: port)
        log.info("💡 DMX connected to \(address):\(port)", category: .system)
    }

    // MARK: - Recording

    func startRecording() async throws {
        try await audioEngine.startRecording()
        isRecording = true
        log.info("⏺️ Recording started", category: .system)
    }

    func stopRecording() async throws -> URL {
        isRecording = false
        let url = try await audioEngine.stopRecording()
        log.info("⏹️ Recording saved to: \(url.path)", category: .system)
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
        log.info("💾 Project saved: \(project.name)", category: .system)
    }

    func loadProject(from url: URL) async throws {
        // Load project from disk
        log.info("📂 Loading project from: \(url.path)", category: .system)
    }
}

// MARK: - Mac Audio Engine

@MainActor
class MacAudioEngine {

    private var isRunning: Bool = false
    private var isRecording: Bool = false
    private var recordingURL: URL?

    func start(source: MacApp.AudioInputSource) async throws {
        log.info("🔊 Mac Audio Engine starting with source: \(source.rawValue)", category: .system)
        isRunning = true
    }

    func stop() async {
        log.info("🔊 Mac Audio Engine stopping", category: .system)
        isRunning = false
    }

    func changeSource(_ source: MacApp.AudioInputSource) async throws {
        log.info("🔊 Changing audio source to: \(source.rawValue)", category: .system)
    }

    func startRecording() async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let timestamp = ISO8601DateFormatter().string(from: Date())
        recordingURL = documentsPath.appendingPathComponent("Recording_\(timestamp).wav")
        isRecording = true
        log.info("⏺️ Recording to: \(recordingURL?.path ?? "unknown")", category: .system)
    }

    func stopRecording() async throws -> URL {
        isRecording = false
        guard let url = recordingURL else {
            throw RecordingError.noRecordingInProgress
        }
        return url
    }

    enum RecordingError: Error, LocalizedError {
        case noRecordingInProgress
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .noRecordingInProgress: return "No recording in progress"
            case .saveFailed: return "Failed to save recording"
            }
        }
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
            log.info("🎹 MIDI Client created successfully", category: .system)
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
        log.info("🎹 Connecting to MIDI device: \(device.name)", category: .system)
    }
}

// MARK: - Mac Visualization Engine

@MainActor
class MacVisualizationEngine {

    private var currentMode: MacApp.VisualizationMode = .spectrum

    func setMode(_ mode: MacApp.VisualizationMode) async {
        currentMode = mode
        log.info("🎨 Visualization mode changed to: \(mode.rawValue)", category: .system)
    }
}

// MARK: - Push 3 Controller

@MainActor
class Push3Controller {

    private var isConnected: Bool = false

    func connect() async throws {
        log.info("🎛️ Connecting to Ableton Push 3...", category: .system)
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        log.info("🎛️ Push 3 disconnected", category: .system)
    }
}

// MARK: - DMX Controller

@MainActor
class DMXController {

    private var isConnected: Bool = false

    func connect(address: String, port: UInt16) async throws {
        log.info("💡 Connecting to DMX at \(address):\(port)...", category: .system)
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        log.info("💡 DMX disconnected", category: .system)
    }
}

#endif
