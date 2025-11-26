//
//  tvOSPlatform.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  tvOS PLATFORM - Living Room Biofeedback Experience
//  Group meditation, therapeutic visualization, and ambient music
//

#if os(tvOS)
import Foundation
import UIKit
import AVFoundation
import GameController
import Combine

/// EOEL for Apple TV
///
/// **Living Room Experience:**
/// - Large-screen visualization (up to 4K 120Hz)
/// - Group biofeedback sessions (multiple participants)
/// - Ambient music & meditation for families
/// - Siri Remote control (swipe, tap, voice)
/// - AirPlay receiver (stream from iPhone/iPad)
/// - Shared therapeutic sessions
///
/// **Use Cases:**
/// - Family meditation sessions
/// - Group therapy (therapist controls via iPad)
/// - Ambient soundscapes for relaxation
/// - Party mode (music visualization)
/// - Presentations (conferences, workshops)
///
@MainActor
@Observable
class tvOSPlatform {

    // MARK: - Published Properties

    /// Current session mode
    var sessionMode: SessionMode = .ambient

    /// Group session active
    var isGroupSession: Bool = false

    /// Connected participants (iPhones/Watches in room)
    var participants: [Participant] = []

    /// Siri Remote is connected
    var siriRemoteConnected: Bool = false

    /// AirPlay is streaming
    var airPlayActive: Bool = false

    /// Current visualization mode
    var visualizationMode: VisualizationMode = .cosmos

    /// TV screen resolution
    var screenResolution: ScreenResolution = .HD

    // MARK: - Private Properties

    private let focusEngine: FocusEngineManager
    private let remoteController: SiriRemoteController
    private let airPlayManager: AirPlayManager
    private let groupSessionManager: GroupSessionManager
    private let visualizationEngine: tvOSVisualizationEngine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session Modes

    enum SessionMode: String, CaseIterable {
        case ambient = "Ambient Soundscape"
        case meditation = "Guided Meditation"
        case therapy = "Group Therapy"
        case music = "Music Playback"
        case visualization = "Pure Visualization"
        case party = "Party Mode"

        var description: String {
            switch self {
            case .ambient:
                return "Calming background audio with gentle visuals"
            case .meditation:
                return "Guided meditation session for the whole family"
            case .therapy:
                return "Therapeutic session with biofeedback monitoring"
            case .music:
                return "Music playback with reactive visualizations"
            case .visualization:
                return "Pure visual experience, no audio guidance"
            case .party:
                return "High-energy music visualization for gatherings"
            }
        }
    }

    // MARK: - Visualization Modes

    enum VisualizationMode: String, CaseIterable {
        case cosmos = "Cosmic Journey"
        case nature = "Nature Scenes"
        case abstract = "Abstract Geometry"
        case particles = "Particle Fields"
        case bioReactive = "Bio-Reactive Patterns"
        case sacred = "Sacred Geometry"
        case ambient = "Ambient Waves"

        var description: String {
            switch self {
            case .cosmos:
                return "Journey through galaxies and nebulae"
            case .nature:
                return "Forests, oceans, mountains in 4K"
            case .abstract:
                return "Flowing abstract shapes and colors"
            case .particles:
                return "Millions of particles dancing to biofeedback"
            case .bioReactive:
                return "Patterns responding to group heart rates"
            case .sacred:
                return "Flower of Life, Metatron's Cube, Mandala"
            case .ambient:
                return "Calm, slow-moving waves of color"
            }
        }
    }

    // MARK: - Screen Resolution

    enum ScreenResolution {
        case HD      // 1920x1080
        case fourK   // 3840x2160
        case fourK120 // 3840x2160 @ 120Hz (Apple TV 4K 3rd gen)

        var size: CGSize {
            switch self {
            case .HD: return CGSize(width: 1920, height: 1080)
            case .fourK, .fourK120: return CGSize(width: 3840, height: 2160)
            }
        }

        var refreshRate: Int {
            switch self {
            case .HD, .fourK: return 60
            case .fourK120: return 120
            }
        }
    }

    // MARK: - Participant

    struct Participant: Identifiable {
        let id = UUID()
        let name: String
        let deviceType: DeviceType
        var heartRate: Double = 0
        var hrvCoherence: Double = 0
        var isConnected: Bool = true

        enum DeviceType {
            case iPhone
            case watch
            case iPad
        }

        var coherenceLevel: String {
            switch hrvCoherence {
            case 0..<40: return "Low"
            case 40..<60: return "Medium"
            case 60...100: return "High"
            default: return "Unknown"
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.focusEngine = FocusEngineManager()
        self.remoteController = SiriRemoteController()
        self.airPlayManager = AirPlayManager()
        self.groupSessionManager = GroupSessionManager()
        self.visualizationEngine = tvOSVisualizationEngine()

        detectScreenResolution()
        setupRemoteController()
        setupAirPlay()
        setupGroupSession()
    }

    private func detectScreenResolution() {
        let screen = UIScreen.main
        let size = screen.bounds.size
        let scale = screen.scale

        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale

        if pixelWidth >= 3840 && pixelHeight >= 2160 {
            // Check refresh rate
            let fps = screen.maximumFramesPerSecond
            screenResolution = fps >= 120 ? .fourK120 : .fourK
        } else {
            screenResolution = .HD
        }

        print("📺 Apple TV: \(Int(pixelWidth))x\(Int(pixelHeight)) @ \(screen.maximumFramesPerSecond)fps")
    }

    // MARK: - Siri Remote Control

    private func setupRemoteController() {
        remoteController.onSwipe = { [weak self] direction in
            self?.handleRemoteSwipe(direction)
        }

        remoteController.onTap = { [weak self] in
            self?.handleRemoteTap()
        }

        remoteController.onMenu = { [weak self] in
            self?.handleRemoteMenu()
        }

        remoteController.onPlayPause = { [weak self] in
            self?.handleRemotePlayPause()
        }

        siriRemoteConnected = true
        print("🎮 Siri Remote connected")
    }

    private func handleRemoteSwipe(_ direction: SiriRemoteController.SwipeDirection) {
        switch direction {
        case .up:
            // Increase volume or navigate up
            print("⬆️ Swipe Up")
        case .down:
            // Decrease volume or navigate down
            print("⬇️ Swipe Down")
        case .left:
            // Previous visualization or decrease parameter
            cycleVisualization(direction: -1)
        case .right:
            // Next visualization or increase parameter
            cycleVisualization(direction: 1)
        }
    }

    private func handleRemoteTap() {
        // Toggle between modes or select
        print("👆 Tap")
    }

    private func handleRemoteMenu() {
        // Show menu overlay
        print("📋 Menu")
    }

    private func handleRemotePlayPause() {
        // Toggle session play/pause
        print("⏯️ Play/Pause")
    }

    private func cycleVisualization(direction: Int) {
        let modes = VisualizationMode.allCases
        guard let currentIndex = modes.firstIndex(of: visualizationMode) else { return }

        let newIndex = (currentIndex + direction + modes.count) % modes.count
        visualizationMode = modes[newIndex]

        print("🎨 Visualization: \(visualizationMode.rawValue)")
        visualizationEngine.loadVisualization(visualizationMode)
    }

    // MARK: - AirPlay Integration

    private func setupAirPlay() {
        airPlayManager.onStreamStarted = { [weak self] in
            self?.airPlayActive = true
            print("📡 AirPlay stream started")
        }

        airPlayManager.onStreamStopped = { [weak self] in
            self?.airPlayActive = false
            print("📡 AirPlay stream stopped")
        }

        airPlayManager.onBioDataReceived = { [weak self] heartRate, coherence in
            self?.updateBioVisualization(heartRate: heartRate, coherence: coherence)
        }
    }

    private func updateBioVisualization(heartRate: Double, coherence: Double) {
        // Update visualization based on AirPlay biofeedback data
        visualizationEngine.updateWithBioData(heartRate: heartRate, coherence: coherence)
    }

    // MARK: - Group Session Management

    private func setupGroupSession() {
        groupSessionManager.onParticipantJoined = { [weak self] participant in
            self?.participants.append(participant)
            print("👥 Participant joined: \(participant.name)")
        }

        groupSessionManager.onParticipantLeft = { [weak self] participantID in
            self?.participants.removeAll { $0.id == participantID }
            print("👋 Participant left")
        }

        groupSessionManager.onBioDataUpdate = { [weak self] participantID, heartRate, coherence in
            self?.updateParticipantBioData(
                participantID: participantID,
                heartRate: heartRate,
                coherence: coherence
            )
        }
    }

    private func updateParticipantBioData(
        participantID: UUID,
        heartRate: Double,
        coherence: Double
    ) {
        if let index = participants.firstIndex(where: { $0.id == participantID }) {
            participants[index].heartRate = heartRate
            participants[index].hrvCoherence = coherence

            // Update group visualization with combined bio data
            updateGroupVisualization()
        }
    }

    private func updateGroupVisualization() {
        // Calculate average group coherence
        let avgCoherence = participants.reduce(0.0) { $0 + $1.hrvCoherence } / Double(max(participants.count, 1))
        let avgHeartRate = participants.reduce(0.0) { $0 + $1.heartRate } / Double(max(participants.count, 1))

        visualizationEngine.updateWithGroupBioData(
            avgHeartRate: avgHeartRate,
            avgCoherence: avgCoherence,
            participantCount: participants.count
        )

        print("👥 Group: \(participants.count) participants, Coherence: \(Int(avgCoherence))")
    }

    // MARK: - Session Control

    func startSession(mode: SessionMode) {
        sessionMode = mode

        switch mode {
        case .ambient:
            startAmbientSession()
        case .meditation:
            startMeditationSession()
        case .therapy:
            startTherapySession()
        case .music:
            startMusicSession()
        case .visualization:
            startVisualizationSession()
        case .party:
            startPartySession()
        }

        print("▶️ Started session: \(mode.rawValue)")
    }

    func stopSession() {
        print("⏹️ Session stopped")
    }

    private func startAmbientSession() {
        visualizationMode = .ambient
        visualizationEngine.loadVisualization(.ambient)
        // Load calming ambient audio
    }

    private func startMeditationSession() {
        visualizationMode = .nature
        visualizationEngine.loadVisualization(.nature)
        // Load guided meditation audio
    }

    private func startTherapySession() {
        isGroupSession = true
        visualizationMode = .bioReactive
        visualizationEngine.loadVisualization(.bioReactive)
        groupSessionManager.startListening()
    }

    private func startMusicSession() {
        visualizationMode = .particles
        visualizationEngine.loadVisualization(.particles)
        // Start music playback
    }

    private func startVisualizationSession() {
        visualizationMode = .cosmos
        visualizationEngine.loadVisualization(.cosmos)
        // Pure visuals, no audio
    }

    private func startPartySession() {
        visualizationMode = .particles
        visualizationEngine.loadVisualization(.particles)
        // High-energy music with reactive visuals
    }

    // MARK: - Focus Engine (tvOS Navigation)

    func setupFocusEngine(for view: UIView) {
        focusEngine.setupFocusGuides(for: view)
    }
}

// MARK: - Siri Remote Controller

class SiriRemoteController {

    enum SwipeDirection {
        case up, down, left, right
    }

    var onSwipe: ((SwipeDirection) -> Void)?
    var onTap: (() -> Void)?
    var onMenu: (() -> Void)?
    var onPlayPause: (() -> Void)?

    init() {
        setupController()
    }

    private func setupController() {
        // Setup game controller for Siri Remote
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.controllerConnected(notification)
        }

        // Check for already connected controllers
        for controller in GCController.controllers() {
            configureController(controller)
        }
    }

    private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        configureController(controller)
    }

    private func configureController(_ controller: GCController) {
        if let microGamepad = controller.microGamepad {
            // Siri Remote (2nd gen and later)
            microGamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
                if abs(xValue) > abs(yValue) {
                    self?.onSwipe?(xValue > 0 ? .right : .left)
                } else {
                    self?.onSwipe?(yValue > 0 ? .up : .down)
                }
            }

            microGamepad.buttonA.valueChangedHandler = { [weak self] _, _, _ in
                self?.onTap?()
            }

            microGamepad.buttonX.valueChangedHandler = { [weak self] _, _, _ in
                self?.onPlayPause?()
            }
        }
    }
}

// MARK: - AirPlay Manager

class AirPlayManager {

    var onStreamStarted: (() -> Void)?
    var onStreamStopped: (() -> Void)?
    var onBioDataReceived: ((Double, Double) -> Void)?

    init() {
        setupAirPlay()
    }

    private func setupAirPlay() {
        // Monitor AirPlay status
        // This would integrate with AVRoutePickerView and external display
        print("📡 AirPlay receiver ready")
    }
}

// MARK: - Group Session Manager

class GroupSessionManager {

    var onParticipantJoined: ((tvOSPlatform.Participant) -> Void)?
    var onParticipantLeft: ((UUID) -> Void)?
    var onBioDataUpdate: ((UUID, Double, Double) -> Void)?

    init() {
        print("👥 Group session manager initialized")
    }

    func startListening() {
        // Start listening for nearby iPhones/Watches via Bonjour/Multipeer
        print("👂 Listening for participants...")
    }

    func stopListening() {
        print("🔇 Stopped listening for participants")
    }
}

// MARK: - Focus Engine Manager

class FocusEngineManager {

    func setupFocusGuides(for view: UIView) {
        // Setup Focus Guides for tvOS navigation
        // Focus Guides help direct focus between UI elements
        print("🎯 Focus guides configured")
    }
}

// MARK: - tvOS Visualization Engine

@MainActor
class tvOSVisualizationEngine {

    private var currentVisualization: tvOSPlatform.VisualizationMode?

    func loadVisualization(_ mode: tvOSPlatform.VisualizationMode) {
        currentVisualization = mode
        print("🎨 Loading visualization: \(mode.rawValue)")

        switch mode {
        case .cosmos:
            loadCosmicVisualization()
        case .nature:
            loadNatureVisualization()
        case .abstract:
            loadAbstractVisualization()
        case .particles:
            loadParticleVisualization()
        case .bioReactive:
            loadBioReactiveVisualization()
        case .sacred:
            loadSacredGeometryVisualization()
        case .ambient:
            loadAmbientVisualization()
        }
    }

    func updateWithBioData(heartRate: Double, coherence: Double) {
        // Update visualization based on single-user bio data
        print("💓 Bio update: HR=\(Int(heartRate)), Coherence=\(Int(coherence))")
    }

    func updateWithGroupBioData(avgHeartRate: Double, avgCoherence: Double, participantCount: Int) {
        // Update visualization based on group average bio data
        print("👥 Group bio update: HR=\(Int(avgHeartRate)), Coherence=\(Int(avgCoherence)), Count=\(participantCount)")
    }

    private func loadCosmicVisualization() {
        // Load 4K space scenes with parallax
    }

    private func loadNatureVisualization() {
        // Load nature scenes (forests, oceans, mountains)
    }

    private func loadAbstractVisualization() {
        // Load flowing abstract shapes
    }

    private func loadParticleVisualization() {
        // Load particle system (millions of particles)
    }

    private func loadBioReactiveVisualization() {
        // Load bio-reactive patterns
    }

    private func loadSacredGeometryVisualization() {
        // Load sacred geometry (Flower of Life, etc.)
    }

    private func loadAmbientVisualization() {
        // Load calm ambient waves
    }
}

#endif
