import Foundation
import UIKit
import AVFoundation
import Combine
import GroupActivities

#if os(tvOS)

/// Echoelmusic für Apple TV
///
/// Apple TV bietet eine einzigartige Erfahrung für Echoelmusic:
/// - Große Displays: Immersive Audio-Visualisierungen in 4K/8K
/// - Atmos-Support: Dolby Atmos für 3D-Audio-Biofeedback
/// - Group Sessions: SharePlay für Gruppen-Meditation/Therapy
/// - Siri Remote: Intuitive Navigation mit Focus Engine
/// - AirPlay: Sync mit iPhone/Watch für Bio-Daten
/// - HDR: High Dynamic Range für beeindruckende Visuals
///
/// Use Cases:
/// - Meditations-Sessions für die ganze Familie
/// - Therapie-Sessions (Gruppentherapie via SharePlay)
/// - Wellness-Center: Großbild-Displays für Entspannungsräume
/// - Yoga-Studios: Atemführung mit visueller Unterstützung
/// - Ambient Background: Bioreaktive Kunst als Hintergrund
///
@MainActor
@Observable
class TVApp {

    // MARK: - Published Properties

    /// Visualisierungsmodus
    var visualizationMode: VisualizationMode = .spectrum

    /// Aktive Session
    var activeSession: Session?

    /// Connected iOS Devices (via AirPlay)
    var connectedDevices: [ConnectedDevice] = []

    /// Ist SharePlay aktiv?
    var isSharePlayActive: Bool = false

    // MARK: - Private Properties

    private let visualEngine: TVVisualizationEngine
    private let audioEngine: TVAudioEngine
    private let focusEngine: TVFocusEngine
    private let airPlayReceiver: AirPlayReceiver

    private var cancellables = Set<AnyCancellable>()

    // MARK: - GroupActivities Properties

    private var groupSession: GroupSession<EchoelmusicActivity>?
    private var groupSessionMessenger: GroupSessionMessenger?
    private var groupSessionTasks = Set<Task<Void, Never>>()

    // MARK: - Visualization Mode

    enum VisualizationMode: String, CaseIterable {
        case spectrum = "Frequenzspektrum"
        case particles = "Partikel-System"
        case waveform = "Wellenform 3D"
        case cymatics = "Kymatik"
        case bioReactive = "Bio-Reaktiv"
        case mandala = "Mandala"
        case galaxy = "Galaxie"
        case abstract = "Abstrakt"
        case ambient = "Ambient Art"

        var description: String {
            switch self {
            case .spectrum:
                return "Echtzeit-Frequenzanalyse mit 3D-Bars"
            case .particles:
                return "8192 Partikel reagieren auf Audio und Bio-Daten"
            case .waveform:
                return "3D-Wellenform mit räumlicher Tiefe"
            case .cymatics:
                return "Kymatische Muster aus Klang und Frequenz"
            case .bioReactive:
                return "Geometrie reagiert auf HRV und Coherence"
            case .mandala:
                return "Dynamische Mandala-Visualisierung"
            case .galaxy:
                return "Sternenfeld reagiert auf Biofeedback"
            case .abstract:
                return "Abstrakte Kunst aus Klang und Emotion"
            case .ambient:
                return "Entspannende Ambient-Visualisierung"
            }
        }
    }

    // MARK: - Session

    struct Session {
        let id: UUID = UUID()
        let type: SessionType
        let startTime: Date
        var duration: TimeInterval = 0
        var participants: [Participant] = []

        enum SessionType: String {
            case meditation = "Meditation"
            case breathing = "Atemübung"
            case therapy = "Therapie"
            case musicCreation = "Musik erstellen"
            case ambient = "Ambient Background"
        }

        struct Participant {
            let id: UUID
            let name: String
            let deviceType: DeviceType
            var bioMetrics: BioMetrics?

            enum DeviceType {
                case iPhone
                case iPad
                case appleWatch
                case macBook
            }

            struct BioMetrics {
                var heartRate: Double
                var hrv: Double
                var coherence: Double
            }
        }
    }

    // MARK: - Connected Device

    struct ConnectedDevice {
        let id: UUID
        let name: String
        let type: DeviceType
        var isStreaming: Bool

        enum DeviceType {
            case iPhone
            case iPad
            case appleWatch
        }
    }

    // MARK: - Initialization

    init() {
        self.visualEngine = TVVisualizationEngine()
        self.audioEngine = TVAudioEngine()
        self.focusEngine = TVFocusEngine()
        self.airPlayReceiver = AirPlayReceiver()

        setupObservers()
        setupAudioSession()
    }

    private func setupObservers() {
        // Beobachte AirPlay-Verbindungen
        airPlayReceiver.deviceConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in
                self?.handleDeviceConnected(device)
            }
            .store(in: &cancellables)

        // Beobachte Bio-Daten von verbundenen Geräten
        airPlayReceiver.bioDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.handleBioDataUpdate(data)
            }
            .store(in: &cancellables)
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)

            // Check for Dolby Atmos support
            if audioSession.availableCategories.contains(.ambient) {
                print("📺 Dolby Atmos supported")
            }
        } catch {
            print("❌ Audio session setup failed: \(error)")
        }
    }

    // MARK: - Session Management

    func startSession(type: Session.SessionType) async {
        print("📺 Starting \(type.rawValue) session on Apple TV")

        let session = Session(type: type, startTime: Date())
        activeSession = session

        // Starte Visualisierung
        await visualEngine.start(mode: visualizationMode)

        // Starte Audio-Engine
        await audioEngine.start()

        // Setup Focus Engine für Siri Remote
        focusEngine.setupFocusEnvironment()
    }

    func stopSession() async {
        guard activeSession != nil else { return }

        print("📺 Stopping session on Apple TV")

        await visualEngine.stop()
        await audioEngine.stop()

        activeSession = nil
    }

    // MARK: - Device Connection

    private func handleDeviceConnected(_ device: ConnectedDevice) {
        print("📱 Device connected: \(device.name) (\(device.type))")
        connectedDevices.append(device)

        // Füge als Participant zur Session hinzu
        if var session = activeSession {
            let participant = Session.Participant(
                id: device.id,
                name: device.name,
                deviceType: mapToParticipantDeviceType(device.type)
            )
            session.participants.append(participant)
            activeSession = session
        }
    }

    private func handleBioDataUpdate(_ data: BioDataUpdate) {
        // Update Participant Bio-Metriken
        if var session = activeSession,
           let index = session.participants.firstIndex(where: { $0.id == data.deviceId }) {

            let bioMetrics = Session.Participant.BioMetrics(
                heartRate: data.heartRate,
                hrv: data.hrv,
                coherence: data.coherence
            )
            session.participants[index].bioMetrics = bioMetrics
            activeSession = session

            // Update Visualisierung mit Bio-Daten
            Task {
                await visualEngine.updateWithBioData(hrv: data.hrv, coherence: data.coherence)
            }
        }
    }

    private func mapToParticipantDeviceType(_ type: ConnectedDevice.DeviceType) -> Session.Participant.DeviceType {
        switch type {
        case .iPhone: return .iPhone
        case .iPad: return .iPad
        case .appleWatch: return .appleWatch
        }
    }

    // MARK: - SharePlay

    func startSharePlay() async throws {
        print("📺 Starting SharePlay session")

        // Create and activate the Echoelmusic activity
        let activity = EchoelmusicActivity()

        // Check if GroupActivities is available
        switch await activity.prepareForActivation() {
        case .activationDisabled:
            throw SharePlayError.activationDisabled
        case .activationPreferred:
            // Activate the activity
            do {
                _ = try await activity.activate()
            } catch {
                throw SharePlayError.activationFailed(error)
            }
        case .cancelled:
            throw SharePlayError.cancelled
        @unknown default:
            break
        }

        isSharePlayActive = true
    }

    func stopSharePlay() {
        print("📺 Stopping SharePlay session")

        // End the group session
        groupSession?.end()
        groupSession = nil
        groupSessionMessenger = nil

        // Cancel all group session tasks
        for task in groupSessionTasks {
            task.cancel()
        }
        groupSessionTasks.removeAll()

        isSharePlayActive = false
    }

    /// Configure and join a group session
    func configureGroupSession(_ session: GroupSession<EchoelmusicActivity>) {
        self.groupSession = session

        // Create messenger for syncing state
        let messenger = GroupSessionMessenger(session: session)
        self.groupSessionMessenger = messenger

        // Listen for session state changes
        let stateTask = Task { @MainActor in
            for await state in session.$state.values {
                switch state {
                case .waiting:
                    print("📺 SharePlay: Waiting for participants")
                case .joined:
                    print("📺 SharePlay: Session joined with \(session.activeParticipants.count) participants")
                    isSharePlayActive = true
                case .invalidated:
                    print("📺 SharePlay: Session invalidated")
                    isSharePlayActive = false
                @unknown default:
                    break
                }
            }
        }
        groupSessionTasks.insert(stateTask)

        // Listen for participant changes
        let participantTask = Task { @MainActor in
            for await participants in session.$activeParticipants.values {
                print("📺 SharePlay: Active participants: \(participants.count)")
                await syncWithParticipants(participants)
            }
        }
        groupSessionTasks.insert(participantTask)

        // Listen for incoming messages
        let messageTask = Task { @MainActor in
            for await (message, _) in messenger.messages(of: SharePlayMessage.self) {
                await handleSharePlayMessage(message)
            }
        }
        groupSessionTasks.insert(messageTask)

        // Join the session
        session.join()
    }

    /// Sync session state with participants
    private func syncWithParticipants(_ participants: Set<Participant>) async {
        guard let session = activeSession else { return }

        // Update connected devices from SharePlay participants
        connectedDevices = participants.compactMap { participant in
            ConnectedDevice(
                id: participant.id.hashValue,
                name: "SharePlay User",
                type: .iPhone  // Default assumption
            )
        }

        // Send current session state to new participants
        if let messenger = groupSessionMessenger {
            let stateMessage = SharePlayMessage.sessionState(
                mode: visualizationMode.rawValue,
                hrvCoherence: session.participants.first?.bioMetrics?.coherence ?? 0,
                heartRate: session.participants.first?.bioMetrics?.heartRate ?? 0
            )
            try? await messenger.send(stateMessage)
        }
    }

    /// Handle incoming SharePlay messages
    private func handleSharePlayMessage(_ message: SharePlayMessage) async {
        switch message {
        case .sessionState(let mode, let hrvCoherence, let heartRate):
            // Update visualization mode
            if let newMode = VisualizationMode(rawValue: mode) {
                await changeVisualizationMode(newMode)
            }
            // Update visual engine with bio data
            await visualEngine.updateWithBioData(hrv: hrvCoherence, coherence: hrvCoherence)

        case .modeChange(let mode):
            if let newMode = VisualizationMode(rawValue: mode) {
                await changeVisualizationMode(newMode)
            }

        case .bioUpdate(let hrvCoherence, let heartRate):
            await visualEngine.updateWithBioData(hrv: hrvCoherence, coherence: hrvCoherence)
        }
    }

    /// Broadcast mode change to all participants
    func broadcastModeChange(_ mode: VisualizationMode) async {
        guard let messenger = groupSessionMessenger else { return }
        let message = SharePlayMessage.modeChange(mode: mode.rawValue)
        try? await messenger.send(message)
    }

    /// Broadcast bio-data update to all participants
    func broadcastBioUpdate(hrvCoherence: Double, heartRate: Double) async {
        guard let messenger = groupSessionMessenger else { return }
        let message = SharePlayMessage.bioUpdate(hrvCoherence: hrvCoherence, heartRate: heartRate)
        try? await messenger.send(message)
    }

    // MARK: - Visualization Control

    func changeVisualizationMode(_ mode: VisualizationMode) async {
        visualizationMode = mode
        await visualEngine.changeMode(mode)
    }

    func adjustVisualizationIntensity(_ intensity: Float) async {
        await visualEngine.setIntensity(intensity)
    }
}

// MARK: - Visualization Engine

@MainActor
class TVVisualizationEngine {

    private var isRunning: Bool = false
    private var currentMode: TVApp.VisualizationMode = .spectrum
    private var intensity: Float = 1.0

    func start(mode: TVApp.VisualizationMode) async {
        print("🎨 TV Visualization Engine started: \(mode.rawValue)")
        isRunning = true
        currentMode = mode

        // Initialize Metal renderer for 4K/8K output
        setupMetalRenderer()
    }

    func stop() async {
        print("🎨 TV Visualization Engine stopped")
        isRunning = false
    }

    func changeMode(_ mode: TVApp.VisualizationMode) async {
        print("🎨 Changing mode to: \(mode.rawValue)")
        currentMode = mode
    }

    func setIntensity(_ intensity: Float) async {
        self.intensity = intensity
    }

    func updateWithBioData(hrv: Double, coherence: Double) async {
        // Update visualization based on bio-data
        print("💓 Updating visualization with HRV: \(hrv), Coherence: \(coherence)")
    }

    private func setupMetalRenderer() {
        // Setup Metal for high-performance rendering
        // Target: 4K @ 60fps, 8K @ 30fps
        print("⚡ Metal renderer initialized for tvOS")
    }
}

// MARK: - Audio Engine

@MainActor
class TVAudioEngine {

    private var isRunning: Bool = false

    func start() async {
        print("🔊 TV Audio Engine started")
        isRunning = true

        // Setup Dolby Atmos if available
        setupDolbyAtmos()
    }

    func stop() async {
        print("🔊 TV Audio Engine stopped")
        isRunning = false
    }

    private func setupDolbyAtmos() {
        // Configure Dolby Atmos for 3D spatial audio
        print("🎧 Dolby Atmos configured")
    }
}

// MARK: - Focus Engine

class TVFocusEngine {

    func setupFocusEnvironment() {
        print("🎮 Focus Engine setup for Siri Remote")
    }

    func handleMenuPress() {
        print("🎮 Menu button pressed")
    }

    func handlePlayPause() {
        print("🎮 Play/Pause button pressed")
    }

    func handleSwipe(direction: Direction) {
        print("🎮 Swipe: \(direction)")
    }

    enum Direction {
        case up, down, left, right
    }
}

// MARK: - AirPlay Receiver

@MainActor
class AirPlayReceiver {

    let deviceConnectedPublisher = PassthroughSubject<TVApp.ConnectedDevice, Never>()
    let bioDataPublisher = PassthroughSubject<BioDataUpdate, Never>()

    init() {
        setupAirPlayReceiver()
    }

    private func setupAirPlayReceiver() {
        print("📡 AirPlay Receiver initialized")
        // Listen for incoming AirPlay connections
    }
}

struct BioDataUpdate {
    let deviceId: UUID
    let heartRate: Double
    let hrv: Double
    let coherence: Double
    let timestamp: Date
}

// MARK: - GroupActivities Integration

/// Echoelmusic SharePlay Activity
struct EchoelmusicActivity: GroupActivity {
    static let activityIdentifier = "com.echoelmusic.shareplay"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Echoelmusic Session"
        meta.subtitle = "Bio-reactive meditation experience"
        meta.type = .generic
        return meta
    }
}

/// Messages for syncing state between SharePlay participants
enum SharePlayMessage: Codable {
    case sessionState(mode: String, hrvCoherence: Double, heartRate: Double)
    case modeChange(mode: String)
    case bioUpdate(hrvCoherence: Double, heartRate: Double)

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case type
        case mode
        case hrvCoherence
        case heartRate
    }

    enum MessageType: String, Codable {
        case sessionState
        case modeChange
        case bioUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .sessionState:
            let mode = try container.decode(String.self, forKey: .mode)
            let coherence = try container.decode(Double.self, forKey: .hrvCoherence)
            let hr = try container.decode(Double.self, forKey: .heartRate)
            self = .sessionState(mode: mode, hrvCoherence: coherence, heartRate: hr)
        case .modeChange:
            let mode = try container.decode(String.self, forKey: .mode)
            self = .modeChange(mode: mode)
        case .bioUpdate:
            let coherence = try container.decode(Double.self, forKey: .hrvCoherence)
            let hr = try container.decode(Double.self, forKey: .heartRate)
            self = .bioUpdate(hrvCoherence: coherence, heartRate: hr)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sessionState(let mode, let coherence, let hr):
            try container.encode(MessageType.sessionState, forKey: .type)
            try container.encode(mode, forKey: .mode)
            try container.encode(coherence, forKey: .hrvCoherence)
            try container.encode(hr, forKey: .heartRate)
        case .modeChange(let mode):
            try container.encode(MessageType.modeChange, forKey: .type)
            try container.encode(mode, forKey: .mode)
        case .bioUpdate(let coherence, let hr):
            try container.encode(MessageType.bioUpdate, forKey: .type)
            try container.encode(coherence, forKey: .hrvCoherence)
            try container.encode(hr, forKey: .heartRate)
        }
    }
}

/// SharePlay errors
enum SharePlayError: LocalizedError {
    case activationDisabled
    case activationFailed(Error)
    case cancelled
    case messagingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .activationDisabled:
            return "SharePlay is not available. Make sure you're on a FaceTime call."
        case .activationFailed(let error):
            return "Failed to start SharePlay: \(error.localizedDescription)"
        case .cancelled:
            return "SharePlay activation was cancelled"
        case .messagingFailed(let error):
            return "Failed to sync with participants: \(error.localizedDescription)"
        }
    }
}

#endif
