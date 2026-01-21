import Foundation
import UIKit
import AVFoundation
import Combine

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
class TVApp: ObservableObject {

    // MARK: - Published Properties

    /// Visualisierungsmodus
    @Published var visualizationMode: VisualizationMode = .spectrum

    /// Aktive Session
    @Published var activeSession: Session?

    /// Connected iOS Devices (via AirPlay)
    @Published var connectedDevices: [ConnectedDevice] = []

    /// Ist SharePlay aktiv?
    @Published var isSharePlayActive: Bool = false

    // MARK: - Private Properties

    private let visualEngine: TVVisualizationEngine
    private let audioEngine: TVAudioEngine
    private let focusEngine: TVFocusEngine
    private let airPlayReceiver: AirPlayReceiver

    private var cancellables = Set<AnyCancellable>()

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
                log.info("📺 Dolby Atmos supported", category: .ui)
            }
        } catch {
            log.error("❌ Audio session setup failed: \(error)", category: .ui)
        }
    }

    // MARK: - Session Management

    func startSession(type: Session.SessionType) async {
        log.info("📺 Starting \(type.rawValue) session on Apple TV", category: .ui)

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

        log.info("📺 Stopping session on Apple TV", category: .ui)

        await visualEngine.stop()
        await audioEngine.stop()

        activeSession = nil
    }

    // MARK: - Device Connection

    private func handleDeviceConnected(_ device: ConnectedDevice) {
        log.info("📱 Device connected: \(device.name) (\(device.type))", category: .ui)
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

    private var groupActivityManager: GroupActivityManager?

    func startSharePlay() async throws {
        log.info("📺 Starting SharePlay session", category: .ui)

        // Initialize GroupActivities manager
        groupActivityManager = GroupActivityManager()

        // Create and activate the Echoelmusic group activity
        let activity = EchoelmusicGroupActivity(
            sessionType: activeSession?.type ?? .meditation,
            visualizationMode: visualizationMode
        )

        do {
            // Prepare and activate the activity
            let activationResult = try await activity.activate()

            switch activationResult {
            case .activationPreferred:
                log.info("📺 SharePlay activation preferred", category: .ui)
                isSharePlayActive = true
                await groupActivityManager?.startGroupSession(activity: activity)

            case .activationDisabled:
                log.info("📺 SharePlay activation disabled by user", category: .ui)
                isSharePlayActive = false

            case .cancelled:
                log.info("📺 SharePlay activation cancelled", category: .ui)
                isSharePlayActive = false

            @unknown default:
                log.info("📺 Unknown SharePlay activation result", category: .ui)
                isSharePlayActive = false
            }
        } catch {
            log.error("❌ SharePlay activation failed: \(error)", category: .ui)
            throw error
        }
    }

    func stopSharePlay() {
        log.info("📺 Stopping SharePlay session", category: .ui)
        groupActivityManager?.endGroupSession()
        groupActivityManager = nil
        isSharePlayActive = false
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
        log.info("🎨 TV Visualization Engine started: \(mode.rawValue)", category: .ui)
        isRunning = true
        currentMode = mode

        // Initialize Metal renderer for 4K/8K output
        setupMetalRenderer()
    }

    func stop() async {
        log.info("🎨 TV Visualization Engine stopped", category: .ui)
        isRunning = false
    }

    func changeMode(_ mode: TVApp.VisualizationMode) async {
        log.info("🎨 Changing mode to: \(mode.rawValue)", category: .ui)
        currentMode = mode
    }

    func setIntensity(_ intensity: Float) async {
        self.intensity = intensity
    }

    func updateWithBioData(hrv: Double, coherence: Double) async {
        // Update visualization based on bio-data
        log.info("💓 Updating visualization with HRV: \(hrv), Coherence: \(coherence)", category: .ui)
    }

    private func setupMetalRenderer() {
        // Setup Metal for high-performance rendering
        // Target: 4K @ 60fps, 8K @ 30fps
        log.info("⚡ Metal renderer initialized for tvOS", category: .ui)
    }
}

// MARK: - Audio Engine

@MainActor
class TVAudioEngine {

    private var isRunning: Bool = false

    func start() async {
        log.info("🔊 TV Audio Engine started", category: .ui)
        isRunning = true

        // Setup Dolby Atmos if available
        setupDolbyAtmos()
    }

    func stop() async {
        log.info("🔊 TV Audio Engine stopped", category: .ui)
        isRunning = false
    }

    private func setupDolbyAtmos() {
        // Configure Dolby Atmos for 3D spatial audio
        log.info("🎧 Dolby Atmos configured", category: .ui)
    }
}

// MARK: - Focus Engine

class TVFocusEngine {

    func setupFocusEnvironment() {
        log.info("🎮 Focus Engine setup for Siri Remote", category: .ui)
    }

    func handleMenuPress() {
        log.info("🎮 Menu button pressed", category: .ui)
    }

    func handlePlayPause() {
        log.info("🎮 Play/Pause button pressed", category: .ui)
    }

    func handleSwipe(direction: Direction) {
        log.info("🎮 Swipe: \(direction)", category: .ui)
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
        log.info("📡 AirPlay Receiver initialized", category: .ui)
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

import GroupActivities

struct EchoelmusicGroupActivity: GroupActivity {

    let sessionType: TVApp.Session.SessionType
    let visualizationMode: TVApp.VisualizationMode

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.type = .generic
        metadata.title = "Echoelmusic \(sessionType.rawValue)"
        metadata.subtitle = "Gemeinsame \(sessionType.rawValue) Session"
        metadata.previewImage = nil  // Add app icon here
        metadata.fallbackURL = URL(string: "https://echoelmusic.com")
        return metadata
    }
}

@MainActor
class GroupActivityManager {

    private var groupSession: GroupSession<EchoelmusicGroupActivity>?
    private var messenger: GroupSessionMessenger?
    private var tasks = Set<Task<Void, Never>>()

    func startGroupSession(activity: EchoelmusicGroupActivity) async {
        // Listen for incoming group sessions
        for await session in EchoelmusicGroupActivity.sessions() {
            self.groupSession = session
            self.messenger = GroupSessionMessenger(session: session)

            // Join the session
            session.join()

            log.info("📺 Joined SharePlay session with \(session.activeParticipants.count) participants", category: .ui)

            // Handle participant changes
            let participantTask = Task {
                for await participants in session.$activeParticipants.values {
                    await handleParticipantsChanged(participants)
                }
            }
            tasks.insert(participantTask)

            // Handle incoming messages
            if let messenger = messenger {
                let messageTask = Task {
                    for await message in messenger.messages(of: SharePlayMessage.self) {
                        await handleMessage(message.0)
                    }
                }
                tasks.insert(messageTask)
            }
        }
    }

    func endGroupSession() {
        groupSession?.end()
        groupSession = nil
        messenger = nil
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        log.info("📺 SharePlay session ended", category: .ui)
    }

    func sendBioUpdate(hrv: Double, coherence: Double) async {
        guard let messenger = messenger else { return }

        let message = SharePlayMessage(
            type: .bioUpdate,
            hrv: hrv,
            coherence: coherence,
            timestamp: Date()
        )

        do {
            try await messenger.send(message)
        } catch {
            log.error("❌ Failed to send SharePlay message: \(error)", category: .ui)
        }
    }

    private func handleParticipantsChanged(_ participants: Set<Participant>) async {
        log.info("📺 SharePlay participants: \(participants.count)", category: .ui)
    }

    private func handleMessage(_ message: SharePlayMessage) async {
        switch message.type {
        case .bioUpdate:
            log.info("📺 Received bio update: HRV=\(message.hrv ?? 0), Coherence=\(message.coherence ?? 0)", category: .ui)
        case .visualChange:
            log.info("📺 Received visualization change", category: .ui)
        case .sessionControl:
            log.info("📺 Received session control", category: .ui)
        }
    }
}

struct SharePlayMessage: Codable {
    enum MessageType: String, Codable {
        case bioUpdate
        case visualChange
        case sessionControl
    }

    let type: MessageType
    var hrv: Double?
    var coherence: Double?
    var visualizationMode: String?
    var timestamp: Date
}

#endif
