// AISceneDirector.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// AI Scene Director for Live Performance
// Intelligent camera switching, visual selection, and scene composition
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - Director Constants

/// Constants for AI scene direction
public enum DirectorConstants {
    public static let minShotDuration: TimeInterval = 2.0
    public static let maxShotDuration: TimeInterval = 30.0
    public static let defaultShotDuration: TimeInterval = 8.0
    public static let transitionDuration: TimeInterval = 0.5
    public static let beatLookAhead: TimeInterval = 0.1
    public static let coherenceThreshold: Float = 0.7
    public static let energyThreshold: Float = 0.8
}

// MARK: - Camera

/// Virtual camera for scene direction
public struct Camera: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var type: CameraType
    public var position: CameraPosition
    public var settings: CameraSettings
    public var isActive: Bool

    public enum CameraType: String, CaseIterable, Sendable {
        case wide = "Wide"
        case medium = "Medium"
        case closeUp = "Close-Up"
        case overhead = "Overhead"
        case pov = "POV"
        case artistic = "Artistic"
        case audience = "Audience"
        case detail = "Detail"
        case quantum = "Quantum"
        case bioReactive = "Bio-Reactive"
    }

    public struct CameraPosition: Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var z: Float
        public var pan: Float    // Horizontal rotation
        public var tilt: Float   // Vertical rotation
        public var roll: Float   // Roll rotation

        public init(x: Float = 0, y: Float = 0, z: Float = 5, pan: Float = 0, tilt: Float = 0, roll: Float = 0) {
            self.x = x
            self.y = y
            self.z = z
            self.pan = pan
            self.tilt = tilt
            self.roll = roll
        }
    }

    public struct CameraSettings: Equatable, Sendable {
        public var fov: Float = 60.0         // Field of view
        public var aperture: Float = 2.8     // f-stop
        public var focusDistance: Float = 3.0
        public var exposure: Float = 0.0     // EV adjustment
        public var zoom: Float = 1.0
        public var motionBlur: Float = 0.5

        public init() {}
    }

    public init(id: UUID = UUID(), name: String, type: CameraType) {
        self.id = id
        self.name = name
        self.type = type
        self.position = CameraPosition()
        self.settings = CameraSettings()
        self.isActive = true
    }
}

// MARK: - Scene

/// A composed scene with visual elements
public struct Scene: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var cameras: [Camera]
    public var activeCamera: UUID?
    public var visualLayers: [VisualLayer]
    public var lighting: LightingSetup
    public var mood: SceneMood
    public var duration: TimeInterval?

    public struct VisualLayer: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var type: VisualType
        public var opacity: Float
        public var blendMode: BlendMode
        public var parameters: [String: Float]

        public enum VisualType: String, CaseIterable, Sendable {
            case sacredGeometry = "Sacred Geometry"
            case particles = "Particles"
            case waveform = "Waveform"
            case fractals = "Fractals"
            case nebula = "Nebula"
            case quantum = "Quantum Field"
            case bioField = "Bio Field"
            case gradient = "Gradient"
            case video = "Video"
            case text = "Text"
        }

        public enum BlendMode: String, CaseIterable, Sendable {
            case normal, add, multiply, screen, overlay, softLight, hardLight
        }

        public init(type: VisualType, opacity: Float = 1.0, blendMode: BlendMode = .normal) {
            self.type = type
            self.opacity = opacity
            self.blendMode = blendMode
            self.parameters = [:]
        }
    }

    public struct LightingSetup: Equatable, Sendable {
        public var ambientColor: (r: Float, g: Float, b: Float)
        public var ambientIntensity: Float
        public var keyLightAngle: Float
        public var keyLightIntensity: Float
        public var fillRatio: Float
        public var rimEnabled: Bool

        public init() {
            self.ambientColor = (0.1, 0.1, 0.2)
            self.ambientIntensity = 0.3
            self.keyLightAngle = 45
            self.keyLightIntensity = 1.0
            self.fillRatio = 0.5
            self.rimEnabled = true
        }
    }

    public enum SceneMood: String, CaseIterable, Sendable {
        case energetic = "Energetic"
        case calm = "Calm"
        case mysterious = "Mysterious"
        case joyful = "Joyful"
        case intense = "Intense"
        case meditative = "Meditative"
        case cosmic = "Cosmic"
        case intimate = "Intimate"
        case triumphant = "Triumphant"
        case ethereal = "Ethereal"
    }

    public init(name: String, mood: SceneMood = .calm) {
        self.id = UUID()
        self.name = name
        self.cameras = []
        self.visualLayers = []
        self.lighting = LightingSetup()
        self.mood = mood
    }
}

// MARK: - Direction Decision

/// AI decision for scene direction
public struct DirectionDecision: Identifiable, Sendable {
    public let id = UUID()
    public var type: DecisionType
    public var confidence: Float  // 0-1
    public var reason: String
    public var timestamp: Date
    public var parameters: [String: Any]

    public enum DecisionType: String, CaseIterable, Sendable {
        case switchCamera = "Switch Camera"
        case addVisual = "Add Visual"
        case removeVisual = "Remove Visual"
        case adjustLighting = "Adjust Lighting"
        case changeMood = "Change Mood"
        case triggerEffect = "Trigger Effect"
        case startTransition = "Start Transition"
        case adjustTempo = "Adjust Tempo"
        case highlight = "Highlight"
        case hold = "Hold"
    }

    public init(type: DecisionType, confidence: Float, reason: String, parameters: [String: Any] = [:]) {
        self.type = type
        self.confidence = confidence
        self.reason = reason
        self.timestamp = Date()
        self.parameters = parameters
    }
}

// MARK: - Performance Context

/// Context for AI decision making
public struct PerformanceContext: Sendable {
    public var currentBPM: Float = 120
    public var beatPhase: Float = 0.0  // 0-1 within current beat
    public var measurePhase: Float = 0.0  // 0-1 within current measure
    public var audioEnergy: Float = 0.5
    public var audioSpectrum: [Float] = []
    public var coherence: Float = 0.5
    public var groupEnergy: Float = 0.5
    public var participantCount: Int = 1
    public var timeInCurrentShot: TimeInterval = 0
    public var sessionDuration: TimeInterval = 0
    public var mood: Scene.SceneMood = .calm
    public var isClimax: Bool = false
    public var isTransition: Bool = false

    public init() {}

    public var isOnBeat: Bool {
        beatPhase < 0.1 || beatPhase > 0.9
    }

    public var isOnDownbeat: Bool {
        measurePhase < 0.05 || measurePhase > 0.95
    }

    public var suggestedShotDuration: TimeInterval {
        // Higher energy = shorter shots
        let energyFactor = 1.0 - Double(audioEnergy) * 0.5
        let baseDuration = DirectorConstants.defaultShotDuration * energyFactor

        // Coherence modulates variation
        let coherenceFactor = 1.0 + Double(coherence) * 0.3

        return (baseDuration * coherenceFactor).clamped(to: DirectorConstants.minShotDuration...DirectorConstants.maxShotDuration)
    }
}

// MARK: - AI Scene Director

/// AI-powered scene direction engine
@MainActor
public final class AISceneDirector: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isDirecting: Bool = false
    @Published public private(set) var currentScene: Scene?
    @Published public private(set) var activeCamera: Camera?
    @Published public private(set) var decisions: [DirectionDecision] = []
    @Published public private(set) var context = PerformanceContext()

    @Published public var autoDirectEnabled: Bool = true
    @Published public var directionStyle: DirectionStyle = .balanced
    @Published public var creativityLevel: Float = 0.5  // 0=conservative, 1=experimental

    // MARK: - Direction Styles

    public enum DirectionStyle: String, CaseIterable, Sendable {
        case conservative = "Conservative"
        case balanced = "Balanced"
        case dynamic = "Dynamic"
        case experimental = "Experimental"
        case meditative = "Meditative"
        case cinematic = "Cinematic"
        case concert = "Concert"
        case abstract = "Abstract"
    }

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var lastCameraSwitch: Date = Date()
    private var shotHistory: [(camera: UUID, duration: TimeInterval)] = []
    private var moodHistory: [Scene.SceneMood] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupDefaultScene()
    }

    private func setupDefaultScene() {
        var scene = Scene(name: "Default Scene", mood: .calm)

        // Add default cameras
        scene.cameras = [
            Camera(name: "Wide Shot", type: .wide),
            Camera(name: "Medium Shot", type: .medium),
            Camera(name: "Close-Up", type: .closeUp),
            Camera(name: "Artistic", type: .artistic),
            Camera(name: "Bio-Reactive", type: .bioReactive)
        ]

        // Add default visual layers
        scene.visualLayers = [
            Scene.VisualLayer(type: .gradient, opacity: 0.5, blendMode: .normal),
            Scene.VisualLayer(type: .particles, opacity: 0.3, blendMode: .add)
        ]

        scene.activeCamera = scene.cameras.first?.id
        currentScene = scene
        activeCamera = scene.cameras.first
    }

    // MARK: - Direction Control

    /// Start AI direction
    public func startDirecting() {
        guard !isDirecting else { return }

        isDirecting = true
        startUpdateLoop()
        logDecision(.hold, confidence: 1.0, reason: "Direction started")

        print("AISceneDirector: Started directing")
    }

    /// Stop AI direction
    public func stopDirecting() {
        isDirecting = false
        stopUpdateLoop()
        logDecision(.hold, confidence: 1.0, reason: "Direction stopped")

        print("AISceneDirector: Stopped directing")
    }

    /// Manual camera switch
    public func switchToCamera(_ cameraId: UUID) {
        guard let scene = currentScene,
              let camera = scene.cameras.first(where: { $0.id == cameraId }) else {
            return
        }

        performCameraSwitch(to: camera, reason: "Manual switch")
    }

    /// Manual mood change
    public func setMood(_ mood: Scene.SceneMood) {
        currentScene?.mood = mood
        moodHistory.append(mood)
        logDecision(.changeMood, confidence: 1.0, reason: "Manual mood change to \(mood.rawValue)")
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func update() {
        guard isDirecting, autoDirectEnabled else { return }

        // Update timing context
        context.timeInCurrentShot = Date().timeIntervalSince(lastCameraSwitch)
        context.sessionDuration += 1.0/30.0

        // Make AI decisions
        let decision = analyzeAndDecide()

        // Execute decision
        executeDecision(decision)
    }

    // MARK: - AI Analysis & Decision Making

    private func analyzeAndDecide() -> DirectionDecision {
        // Check if it's time for a camera switch
        if shouldSwitchCamera() {
            return decideCameraSwitch()
        }

        // Check if visuals should change
        if shouldUpdateVisuals() {
            return decideVisualChange()
        }

        // Check if mood should change
        if shouldChangeMood() {
            return decideMoodChange()
        }

        // Check for special triggers
        if context.isClimax {
            return DirectionDecision(type: .triggerEffect, confidence: 0.9, reason: "Climax detected", parameters: ["effect": "burst"])
        }

        // Default: hold current state
        return DirectionDecision(type: .hold, confidence: 0.5, reason: "Maintaining current composition")
    }

    private func shouldSwitchCamera() -> Bool {
        let timeSinceSwitch = context.timeInCurrentShot
        let suggestedDuration = context.suggestedShotDuration

        // Style-based adjustments
        let styleMultiplier: Double
        switch directionStyle {
        case .conservative, .meditative:
            styleMultiplier = 1.5
        case .balanced:
            styleMultiplier = 1.0
        case .dynamic, .concert:
            styleMultiplier = 0.7
        case .experimental, .abstract:
            styleMultiplier = 0.5 + Double.random(in: 0...0.5)
        case .cinematic:
            styleMultiplier = 1.2
        }

        let targetDuration = suggestedDuration * styleMultiplier

        // On-beat switching for dynamic styles
        if directionStyle == .dynamic || directionStyle == .concert {
            if timeSinceSwitch > targetDuration * 0.8 && context.isOnDownbeat {
                return true
            }
        }

        return timeSinceSwitch >= targetDuration
    }

    private func shouldUpdateVisuals() -> Bool {
        // Update visuals every 15-30 seconds based on style
        let interval: TimeInterval
        switch directionStyle {
        case .experimental, .abstract:
            interval = 10.0
        case .dynamic:
            interval = 15.0
        default:
            interval = 25.0
        }

        return Int(context.sessionDuration) % Int(interval) == 0 && context.isOnBeat
    }

    private func shouldChangeMood() -> Bool {
        // Mood changes are less frequent
        let moodDuration: TimeInterval = 60.0  // Minimum 1 minute per mood

        // Check for significant coherence changes
        if context.coherence > DirectorConstants.coherenceThreshold && currentScene?.mood != .meditative {
            return true
        }

        // Check for energy spikes
        if context.audioEnergy > DirectorConstants.energyThreshold && currentScene?.mood == .calm {
            return true
        }

        return false
    }

    private func decideCameraSwitch() -> DirectionDecision {
        guard let scene = currentScene else {
            return DirectionDecision(type: .hold, confidence: 0.5, reason: "No scene available")
        }

        // Score each camera based on context
        var cameraScores: [(camera: Camera, score: Float)] = []

        for camera in scene.cameras where camera.isActive {
            var score: Float = 0.5

            // Avoid recently used cameras
            let recentlyUsed = shotHistory.suffix(3).contains { $0.camera == camera.id }
            if recentlyUsed { score -= 0.3 }

            // Match camera type to context
            switch camera.type {
            case .wide:
                if context.participantCount > 5 { score += 0.2 }
                if context.isTransition { score += 0.3 }

            case .closeUp:
                if context.coherence > 0.7 { score += 0.3 }
                if context.audioEnergy < 0.5 { score += 0.2 }

            case .overhead:
                if currentScene?.mood == .cosmic { score += 0.3 }

            case .artistic:
                score += creativityLevel * 0.3
                if directionStyle == .experimental { score += 0.2 }

            case .bioReactive:
                if context.coherence > 0.5 { score += 0.4 }

            case .quantum:
                if directionStyle == .abstract { score += 0.3 }

            default:
                score += 0.1
            }

            // Add some randomness based on creativity level
            score += Float.random(in: 0...creativityLevel * 0.2)

            cameraScores.append((camera, score))
        }

        // Select highest scoring camera
        guard let best = cameraScores.max(by: { $0.score < $1.score }) else {
            return DirectionDecision(type: .hold, confidence: 0.5, reason: "No suitable camera found")
        }

        return DirectionDecision(
            type: .switchCamera,
            confidence: best.score,
            reason: "Switching to \(best.camera.name) - best match for current context",
            parameters: ["cameraId": best.camera.id.uuidString]
        )
    }

    private func decideVisualChange() -> DirectionDecision {
        // Decide what visual layers to add/remove based on context
        let visualType: Scene.VisualLayer.VisualType

        if context.coherence > 0.7 {
            visualType = .sacredGeometry
        } else if context.audioEnergy > 0.7 {
            visualType = .particles
        } else if currentScene?.mood == .cosmic {
            visualType = .nebula
        } else if currentScene?.mood == .meditative {
            visualType = .bioField
        } else {
            visualType = .waveform
        }

        return DirectionDecision(
            type: .addVisual,
            confidence: 0.7,
            reason: "Adding \(visualType.rawValue) layer for current mood",
            parameters: ["visualType": visualType.rawValue]
        )
    }

    private func decideMoodChange() -> DirectionDecision {
        let newMood: Scene.SceneMood

        if context.coherence > 0.8 {
            newMood = .meditative
        } else if context.audioEnergy > 0.8 {
            newMood = .energetic
        } else if context.groupEnergy > 0.7 {
            newMood = .joyful
        } else if context.participantCount > 20 {
            newMood = .cosmic
        } else {
            newMood = .calm
        }

        return DirectionDecision(
            type: .changeMood,
            confidence: 0.6,
            reason: "Context suggests \(newMood.rawValue) mood",
            parameters: ["mood": newMood.rawValue]
        )
    }

    // MARK: - Decision Execution

    private func executeDecision(_ decision: DirectionDecision) {
        switch decision.type {
        case .switchCamera:
            if let idString = decision.parameters["cameraId"] as? String,
               let id = UUID(uuidString: idString),
               let camera = currentScene?.cameras.first(where: { $0.id == id }) {
                performCameraSwitch(to: camera, reason: decision.reason)
            }

        case .addVisual:
            if let typeString = decision.parameters["visualType"] as? String,
               let type = Scene.VisualLayer.VisualType(rawValue: typeString) {
                addVisualLayer(type: type)
            }

        case .removeVisual:
            if let layerId = decision.parameters["layerId"] as? String,
               let id = UUID(uuidString: layerId) {
                removeVisualLayer(id: id)
            }

        case .changeMood:
            if let moodString = decision.parameters["mood"] as? String,
               let mood = Scene.SceneMood(rawValue: moodString) {
                currentScene?.mood = mood
                moodHistory.append(mood)
            }

        case .triggerEffect:
            if let effect = decision.parameters["effect"] as? String {
                triggerEffect(effect)
            }

        case .adjustLighting, .startTransition, .adjustTempo, .highlight, .hold:
            // These are logged but may not need immediate action
            break
        }

        logDecision(decision.type, confidence: decision.confidence, reason: decision.reason)
    }

    private func performCameraSwitch(to camera: Camera, reason: String) {
        // Record shot duration
        let duration = Date().timeIntervalSince(lastCameraSwitch)
        if let currentId = activeCamera?.id {
            shotHistory.append((currentId, duration))
            if shotHistory.count > 50 { shotHistory.removeFirst() }
        }

        // Switch camera
        activeCamera = camera
        currentScene?.activeCamera = camera.id
        lastCameraSwitch = Date()

        logDecision(.switchCamera, confidence: 0.8, reason: reason)
        print("AISceneDirector: Switched to \(camera.name)")
    }

    private func addVisualLayer(type: Scene.VisualLayer.VisualType) {
        let layer = Scene.VisualLayer(type: type, opacity: 0.5, blendMode: .add)
        currentScene?.visualLayers.append(layer)

        // Limit layer count
        if (currentScene?.visualLayers.count ?? 0) > 5 {
            currentScene?.visualLayers.removeFirst()
        }
    }

    private func removeVisualLayer(id: UUID) {
        currentScene?.visualLayers.removeAll { $0.id == id }
    }

    private func triggerEffect(_ effect: String) {
        // Effects are logged and can be used by visual engine
        logDecision(.triggerEffect, confidence: 0.9, reason: "Triggered effect: \(effect)")
    }

    private func logDecision(_ type: DirectionDecision.DecisionType, confidence: Float, reason: String) {
        let decision = DirectionDecision(type: type, confidence: confidence, reason: reason)
        decisions.append(decision)

        if decisions.count > 100 {
            decisions.removeFirst(decisions.count - 100)
        }
    }

    // MARK: - Context Updates

    /// Update performance context
    public func updateContext(bpm: Float? = nil, beatPhase: Float? = nil, measurePhase: Float? = nil,
                             audioEnergy: Float? = nil, coherence: Float? = nil, groupEnergy: Float? = nil,
                             participantCount: Int? = nil, isClimax: Bool? = nil) {
        if let bpm = bpm { context.currentBPM = bpm }
        if let beatPhase = beatPhase { context.beatPhase = beatPhase }
        if let measurePhase = measurePhase { context.measurePhase = measurePhase }
        if let audioEnergy = audioEnergy { context.audioEnergy = audioEnergy }
        if let coherence = coherence { context.coherence = coherence }
        if let groupEnergy = groupEnergy { context.groupEnergy = groupEnergy }
        if let participantCount = participantCount { context.participantCount = participantCount }
        if let isClimax = isClimax { context.isClimax = isClimax }
    }

    /// Update audio spectrum
    public func updateSpectrum(_ spectrum: [Float]) {
        context.audioSpectrum = spectrum
    }

    // MARK: - Scene Management

    /// Load a new scene
    public func loadScene(_ scene: Scene) {
        currentScene = scene
        activeCamera = scene.cameras.first { $0.id == scene.activeCamera } ?? scene.cameras.first
        logDecision(.hold, confidence: 1.0, reason: "Loaded scene: \(scene.name)")
    }

    /// Add a camera to current scene
    public func addCamera(_ camera: Camera) {
        currentScene?.cameras.append(camera)
    }

    /// Remove a camera from current scene
    public func removeCamera(_ cameraId: UUID) {
        currentScene?.cameras.removeAll { $0.id == cameraId }

        // Switch if active camera was removed
        if activeCamera?.id == cameraId {
            activeCamera = currentScene?.cameras.first
            currentScene?.activeCamera = activeCamera?.id
        }
    }
}

// MARK: - Double Extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}
