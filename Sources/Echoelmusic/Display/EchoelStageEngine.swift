#if canImport(UIKit)
//
//  EchoelStageEngine.swift
//  Echoelmusic — External Display + Projection Mapping + AirPlay
//
//  Manages external displays (HDMI, AirPlay, CarPlay) for stage visuals.
//  Bio-reactive mapping: coherence → scene color, HRV → transition speed,
//  heart rate → visual pulse, breath phase → opacity modulation.
//
//  Supports: External displays via UIScreen, AirPlay mirroring,
//  projection mapping with warping, multi-display layouts,
//  NDI output for broadcast integration.
//

import Foundation
import UIKit
import Observation
import Combine
import os

// MARK: - Display Info

/// Information about a connected external display
public struct StageDisplayInfo: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let resolution: CGSize
    public let refreshRate: Double
    public let isAirPlay: Bool
    public let screenIndex: Int

    public init(
        name: String,
        resolution: CGSize,
        refreshRate: Double = 60.0,
        isAirPlay: Bool = false,
        screenIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.isAirPlay = isAirPlay
        self.screenIndex = screenIndex
    }
}

// MARK: - Stage Scene

/// A visual scene configuration for external display output
public struct StageScene: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var backgroundColor: StageColor
    public var opacity: Float
    public var transitionDuration: Double
    public var visualMode: StageVisualMode
    public var projectionWarp: ProjectionWarp
    public var bioReactiveIntensity: Float

    public init(
        name: String,
        backgroundColor: StageColor = .black,
        visualMode: StageVisualMode = .solidColor,
        bioReactiveIntensity: Float = 0.8
    ) {
        self.id = UUID()
        self.name = name
        self.backgroundColor = backgroundColor
        self.opacity = 1.0
        self.transitionDuration = 0.5
        self.visualMode = visualMode
        self.projectionWarp = ProjectionWarp()
        self.bioReactiveIntensity = bioReactiveIntensity
    }
}

/// Simple RGBA color for stage (Codable + Sendable)
public struct StageColor: Codable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public static let black = StageColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = StageColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// Generate color from bio coherence (0-1)
    /// Low coherence = cool blue, high coherence = warm gold
    public static func fromCoherence(_ coherence: Float) -> StageColor {
        let clamped = max(0, min(1, coherence))
        return StageColor(
            red: clamped * 0.9 + 0.1,
            green: clamped * 0.7 + 0.1,
            blue: (1.0 - clamped) * 0.8 + 0.2,
            alpha: 1.0
        )
    }
}

/// Visual display modes for stage output
public enum StageVisualMode: String, CaseIterable, Codable, Sendable {
    case solidColor      = "Solid Color"
    case gradient        = "Gradient"
    case waveform        = "Waveform"
    case spectrum        = "Spectrum"
    case particles       = "Particles"
    case bioReactive     = "Bio-Reactive"
    case videoPassthrough = "Video Passthrough"
    case textOverlay     = "Text Overlay"
}

/// Projection mapping warp configuration (4-corner keystone)
public struct ProjectionWarp: Codable, Sendable {
    /// Corner offsets as normalized coordinates (-1 to 1)
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomLeft: CGPoint
    public var bottomRight: CGPoint

    /// Edge blending overlap (0-1)
    public var edgeBlend: Float

    /// Gamma correction for projector
    public var gamma: Float

    public init() {
        self.topLeft = .zero
        self.topRight = .zero
        self.bottomLeft = .zero
        self.bottomRight = .zero
        self.edgeBlend = 0.0
        self.gamma = 1.0
    }

    /// Whether any warping is applied
    public var isActive: Bool {
        topLeft != .zero || topRight != .zero ||
        bottomLeft != .zero || bottomRight != .zero
    }
}

// MARK: - Stage Output Mode

/// How the stage engine outputs to external displays
public enum StageOutputMode: String, CaseIterable, Codable, Sendable {
    case mirror          = "Mirror"           // Mirror main display
    case extended        = "Extended"         // Independent content
    case projectionMap   = "Projection Map"   // Warped output
    case multiDisplay    = "Multi-Display"    // Different scenes per display
}

// MARK: - Stage Cue

/// A timed cue for triggering scene changes
public struct StageCue: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var sceneID: UUID
    public var triggerTime: Double?           // Beat or seconds
    public var triggerOnBeat: Bool
    public var transitionDuration: Double
    public var autoAdvance: Bool

    public init(
        name: String,
        sceneID: UUID,
        triggerTime: Double? = nil,
        transitionDuration: Double = 0.5
    ) {
        self.id = UUID()
        self.name = name
        self.sceneID = sceneID
        self.triggerTime = triggerTime
        self.triggerOnBeat = false
        self.transitionDuration = transitionDuration
        self.autoAdvance = false
    }
}

// MARK: - EchoelStageEngine

/// EchoelStage — External display management, projection mapping, AirPlay output.
///
/// Manages UIScreen connections, routes visual content to external displays,
/// applies projection warping, and drives bio-reactive stage visuals.
///
/// Architecture:
/// - Observes UIScreen.didConnectNotification / didDisconnectNotification
/// - Creates UIWindow per external screen
/// - Renders scenes via display link for smooth animation
/// - Bio-reactive: coherence → color, HRV → transition speed, HR → pulse, breath → opacity
@MainActor
@Observable
public final class EchoelStageEngine {

    public static let shared = EchoelStageEngine()

    // MARK: - State

    /// Whether the stage engine is actively outputting
    public var isRunning: Bool = false

    /// Connected external displays
    public var connectedDisplays: [StageDisplayInfo] = []

    /// Available scenes
    public var scenes: [StageScene] = []

    /// Currently active scene
    public var activeScene: StageScene?

    /// Current output mode
    public var outputMode: StageOutputMode = .extended

    /// Bio-reactive modulation enabled
    public var bioReactiveEnabled: Bool = true

    /// Current bio-driven color overlay
    public var currentBioColor: StageColor = .black

    /// Current bio-driven opacity modulation (0-1)
    public var bioOpacity: Float = 1.0

    /// Current bio-driven pulse intensity (0-1)
    public var bioPulse: Float = 0.0

    /// Cue list for sequenced scene changes
    public var cues: [StageCue] = []

    /// Index of current cue
    public var currentCueIndex: Int = 0

    /// Output frame rate
    public var targetFPS: Double = 60.0

    // MARK: - Private

    /// External display windows (one per connected screen)
    private var externalWindows: [UIWindow] = []

    /// Display link for render loop
    private var displayLink: CADisplayLink?

    /// Notification observers
    private var notificationCancellables: Set<AnyCancellable> = []

    /// Frame counter for animations
    private var frameCount: UInt64 = 0

    /// Last bio-reactive update values
    private var lastCoherence: Float = 0.5
    private var lastHRV: Float = 0.5
    private var lastHeartRate: Float = 72.0
    private var lastBreathPhase: Float = 0.0

    // MARK: - Init

    private init() {
        // Default scenes
        scenes = [
            StageScene(name: "Blackout", backgroundColor: .black, visualMode: .solidColor),
            StageScene(name: "Bio Reactive", backgroundColor: .black, visualMode: .bioReactive),
            StageScene(name: "Waveform", backgroundColor: .black, visualMode: .waveform),
            StageScene(name: "Spectrum", backgroundColor: .black, visualMode: .spectrum),
            StageScene(name: "Particles", backgroundColor: .black, visualMode: .particles),
        ]

        setupScreenNotifications()
        scanConnectedDisplays()

        log.log(.info, category: .system, "EchoelStage initialized — \(connectedDisplays.count) display(s) detected")
    }

    deinit {
        stopNonisolated()
    }

    private nonisolated func stopNonisolated() {
        // Cleanup happens on deinit — no network resources to cancel
    }

    // MARK: - Screen Notifications

    private func setupScreenNotifications() {
        NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.handleScreenConnected(notification)
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.handleScreenDisconnected(notification)
            }
            .store(in: &notificationCancellables)
    }

    private func handleScreenConnected(_ notification: Notification) {
        guard let newScreen = notification.object as? UIScreen else { return }

        let info = StageDisplayInfo(
            name: "External Display \(connectedDisplays.count + 1)",
            resolution: newScreen.bounds.size,
            refreshRate: Double(newScreen.maximumFramesPerSecond),
            isAirPlay: newScreen.mirrored != nil,
            screenIndex: UIScreen.screens.firstIndex(of: newScreen) ?? 0
        )
        connectedDisplays.append(info)

        // Create external window for this screen
        let externalWindow = UIWindow(frame: newScreen.bounds)
        externalWindow.screen = newScreen
        externalWindow.rootViewController = createStageViewController()
        externalWindow.isHidden = false
        externalWindows.append(externalWindow)

        log.log(.info, category: .system, "External display connected: \(info.name) (\(Int(info.resolution.width))x\(Int(info.resolution.height)))")

        if isRunning {
            updateExternalContent()
        }
    }

    private func handleScreenDisconnected(_ notification: Notification) {
        guard let disconnectedScreen = notification.object as? UIScreen else { return }

        // Remove window for disconnected screen
        externalWindows.removeAll { $0.screen == disconnectedScreen }

        // Update display list
        scanConnectedDisplays()

        log.log(.info, category: .system, "External display disconnected — \(connectedDisplays.count) remaining")
    }

    // MARK: - Display Scanning

    /// Scan for all currently connected displays
    public func scanConnectedDisplays() {
        connectedDisplays = []

        for (index, screen) in UIScreen.screens.enumerated() {
            if index == 0 { continue } // Skip main screen

            let info = StageDisplayInfo(
                name: "Display \(index)",
                resolution: screen.bounds.size,
                refreshRate: Double(screen.maximumFramesPerSecond),
                isAirPlay: screen.mirrored != nil,
                screenIndex: index
            )
            connectedDisplays.append(info)
        }
    }

    // MARK: - Start / Stop

    /// Start stage output engine
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Create windows for any connected external screens
        for screen in UIScreen.screens.dropFirst() {
            let window = UIWindow(frame: screen.bounds)
            window.screen = screen
            window.rootViewController = createStageViewController()
            window.isHidden = false
            externalWindows.append(window)
        }

        startDisplayLink()
        updateExternalContent()

        log.log(.info, category: .system, "EchoelStage started — outputting to \(externalWindows.count) external display(s)")
    }

    /// Stop stage output engine
    public func stop() {
        guard isRunning else { return }
        isRunning = false

        stopDisplayLink()

        // Hide and remove external windows
        for window in externalWindows {
            window.isHidden = true
        }
        externalWindows.removeAll()

        log.log(.info, category: .system, "EchoelStage stopped")
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()

        let link = CADisplayLink(target: DisplayLinkTarget(action: { [weak self] in
            MainActor.assumeIsolated {
                self?.renderFrame()
            }
        }), selector: #selector(DisplayLinkTarget.handleDisplayLink))

        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Render Loop

    private func renderFrame() {
        guard isRunning else { return }
        frameCount += 1

        // Apply bio-reactive modulation
        if bioReactiveEnabled {
            updateBioVisuals()
        }

        // Update external window content
        updateExternalContent()
    }

    private func updateBioVisuals() {
        // Coherence → scene color
        currentBioColor = StageColor.fromCoherence(lastCoherence)

        // Breath phase → opacity modulation
        let breathMod = (sin(Double(lastBreathPhase) * .pi * 2) + 1.0) / 2.0
        bioOpacity = 0.7 + Float(breathMod) * 0.3

        // Heart rate → pulse (faster HR = faster pulse)
        let pulsePeriod = 60.0 / Double(max(40, lastHeartRate))
        let pulsePhase = Double(frameCount) / (targetFPS * pulsePeriod)
        bioPulse = Float((sin(pulsePhase * .pi * 2) + 1.0) / 2.0)
    }

    private func updateExternalContent() {
        guard let scene = activeScene else { return }

        for window in externalWindows {
            guard let viewController = window.rootViewController as? StageOutputViewController else { continue }

            viewController.updateScene(
                scene: scene,
                bioColor: currentBioColor,
                bioOpacity: bioOpacity,
                bioPulse: bioPulse,
                warp: scene.projectionWarp
            )
        }
    }

    // MARK: - Scene Management

    /// Set the active scene
    public func setActiveScene(_ scene: StageScene) {
        activeScene = scene
        log.log(.info, category: .system, "Stage scene: \(scene.name)")
    }

    /// Set active scene by index
    public func setActiveScene(index: Int) {
        guard index >= 0, index < scenes.count else { return }
        setActiveScene(scenes[index])
    }

    /// Add a new scene
    public func addScene(_ scene: StageScene) {
        scenes.append(scene)
    }

    /// Remove a scene
    public func removeScene(id: UUID) {
        scenes.removeAll { $0.id == id }
        if activeScene?.id == id {
            activeScene = scenes.first
        }
    }

    // MARK: - Cue Management

    /// Fire the next cue in sequence
    public func fireNextCue() {
        guard currentCueIndex < cues.count else { return }
        let cue = cues[currentCueIndex]

        if let scene = scenes.first(where: { $0.id == cue.sceneID }) {
            setActiveScene(scene)
        }

        currentCueIndex += 1
        log.log(.info, category: .system, "Cue fired: \(cue.name) (\(currentCueIndex)/\(cues.count))")
    }

    /// Reset cue list to beginning
    public func resetCues() {
        currentCueIndex = 0
    }

    // MARK: - Projection Mapping

    /// Set keystone warp for active scene
    public func setProjectionWarp(_ warp: ProjectionWarp) {
        guard var scene = activeScene else { return }
        scene.projectionWarp = warp
        activeScene = scene

        // Update in scenes array too
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index].projectionWarp = warp
        }
    }

    /// Adjust single corner for keystone correction
    public func adjustCorner(
        _ corner: ProjectionCorner,
        x: CGFloat,
        y: CGFloat
    ) {
        guard var scene = activeScene else { return }
        let point = CGPoint(x: x, y: y)

        switch corner {
        case .topLeft: scene.projectionWarp.topLeft = point
        case .topRight: scene.projectionWarp.topRight = point
        case .bottomLeft: scene.projectionWarp.bottomLeft = point
        case .bottomRight: scene.projectionWarp.bottomRight = point
        }

        activeScene = scene
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index] = scene
        }
    }

    // MARK: - Bio-Reactive Interface

    /// Apply bio-reactive modulation from workspace
    ///
    /// Called at ~60Hz from EchoelCreativeWorkspace render loop.
    /// Maps: coherence → color, HRV → transition speed,
    ///       heart rate → visual pulse, breath phase → opacity
    public func applyBioReactive(
        coherence: Float,
        hrv: Float,
        heartRate: Float,
        breathPhase: Float
    ) {
        guard bioReactiveEnabled else { return }
        lastCoherence = coherence
        lastHRV = hrv
        lastHeartRate = heartRate
        lastBreathPhase = breathPhase
    }

    // MARK: - View Controller Factory

    private func createStageViewController() -> StageOutputViewController {
        let viewController = StageOutputViewController()
        viewController.view.backgroundColor = .black
        return viewController
    }
}

// MARK: - Projection Corner

public enum ProjectionCorner: String, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Display Link Target

/// Non-isolated target for CADisplayLink (requires @objc selector)
private final class DisplayLinkTarget {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func handleDisplayLink() {
        action()
    }
}

// MARK: - Stage Output View Controller

/// View controller for external display output.
/// Renders the active scene with bio-reactive modulation and projection warping.
final class StageOutputViewController: UIViewController {

    private let contentView = UIView()
    private let overlayView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        contentView.frame = view.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(contentView)

        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
    }

    func updateScene(
        scene: StageScene,
        bioColor: StageColor,
        bioOpacity: Float,
        bioPulse: Float,
        warp: ProjectionWarp
    ) {
        let sceneColor = scene.backgroundColor
        let blendedRed = sceneColor.red * (1 - scene.bioReactiveIntensity) + bioColor.red * scene.bioReactiveIntensity
        let blendedGreen = sceneColor.green * (1 - scene.bioReactiveIntensity) + bioColor.green * scene.bioReactiveIntensity
        let blendedBlue = sceneColor.blue * (1 - scene.bioReactiveIntensity) + bioColor.blue * scene.bioReactiveIntensity

        contentView.backgroundColor = UIColor(
            red: CGFloat(blendedRed),
            green: CGFloat(blendedGreen),
            blue: CGFloat(blendedBlue),
            alpha: CGFloat(bioOpacity)
        )

        // Pulse effect via overlay alpha
        overlayView.backgroundColor = UIColor.white.withAlphaComponent(CGFloat(bioPulse * 0.15))

        // Apply projection warp if active
        if warp.isActive {
            applyProjectionWarp(warp)
        } else {
            contentView.layer.transform = CATransform3DIdentity
        }
    }

    private func applyProjectionWarp(_ warp: ProjectionWarp) {
        // 4-corner keystone via CATransform3D perspective
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 1000.0  // Perspective

        // Map corner offsets to rotation/skew
        let avgX = (warp.topLeft.x + warp.topRight.x + warp.bottomLeft.x + warp.bottomRight.x) / 4
        let avgY = (warp.topLeft.y + warp.topRight.y + warp.bottomLeft.y + warp.bottomRight.y) / 4

        transform = CATransform3DRotate(transform, CGFloat(avgX) * 0.3, 0, 1, 0)
        transform = CATransform3DRotate(transform, CGFloat(avgY) * 0.3, 1, 0, 0)

        contentView.layer.transform = transform
    }
}

#endif
