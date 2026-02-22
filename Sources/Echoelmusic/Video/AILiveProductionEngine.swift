// AILiveProductionEngine.swift
// Echoelmusic - AI-Driven Live Production & Intelligent Direction
// Created 2026-01-05 - Phase 8000 MAXIMUM OVERDRIVE

import Foundation
import SwiftUI
import Combine
import AVFoundation

//==============================================================================
// MARK: - AI Production Mode
//==============================================================================

/// AI-driven production modes for live events
public enum AIProductionMode: String, CaseIterable, Identifiable, Sendable {
    case concert = "concert"
    case meditation = "meditation"
    case dj = "dj_set"
    case workshop = "workshop"
    case interview = "interview"
    case presentation = "presentation"
    case immersiveExperience = "immersive"
    case bioReactive = "bio_reactive"
    case quantumShow = "quantum_show"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .concert: return "Concert"
        case .meditation: return "Meditation Session"
        case .dj: return "DJ Set"
        case .workshop: return "Workshop"
        case .interview: return "Interview"
        case .presentation: return "Presentation"
        case .immersiveExperience: return "Immersive Experience"
        case .bioReactive: return "Bio-Reactive Show"
        case .quantumShow: return "Quantum Light Show"
        }
    }

    public var description: String {
        switch self {
        case .concert: return "Dynamic camera switching for live music"
        case .meditation: return "Slow transitions, calm visuals, bio-sync"
        case .dj: return "Beat-synced cuts, energy-driven visuals"
        case .workshop: return "Educational focus, clear presentation"
        case .interview: return "Two-camera conversation flow"
        case .presentation: return "Screen share focus with speaker overlay"
        case .immersiveExperience: return "360° spatial experience"
        case .bioReactive: return "Visuals driven by audience biometrics"
        case .quantumShow: return "Quantum-inspired light synthesis"
        }
    }
}

//==============================================================================
// MARK: - Camera Source
//==============================================================================

public struct CameraSource: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: CameraType
    public var position: CameraPosition
    public var isActive: Bool
    public var isProgramOut: Bool
    public var isPreview: Bool
    public var url: URL?

    public init(
        id: UUID = UUID(),
        name: String = "Camera",
        type: CameraType = .wideShot,
        position: CameraPosition = .front,
        isActive: Bool = true,
        isProgramOut: Bool = false,
        isPreview: Bool = false,
        url: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.isActive = isActive
        self.isProgramOut = isProgramOut
        self.isPreview = isPreview
        self.url = url
    }

    public enum CameraType: String, CaseIterable, Sendable {
        case wideShot = "wide"
        case mediumShot = "medium"
        case closeUp = "closeup"
        case overhead = "overhead"
        case ptz = "ptz"
        case drone = "drone"
        case vr360 = "360"
        case screenCapture = "screen"
        case generative = "generative"
    }

    public enum CameraPosition: String, CaseIterable, Sendable {
        case front, left, right, back, overhead, roaming
    }
}

//==============================================================================
// MARK: - Transition Type
//==============================================================================

public enum TransitionType: String, CaseIterable, Identifiable, Sendable {
    case cut = "cut"
    case dissolve = "dissolve"
    case fade = "fade"
    case wipe = "wipe"
    case push = "push"
    case zoom = "zoom"
    case spin = "spin"
    case glitch = "glitch"
    case bioSync = "bio_sync"
    case quantumCollapse = "quantum_collapse"
    case heartbeat = "heartbeat"
    case breath = "breath"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    public var defaultDuration: Double {
        switch self {
        case .cut: return 0.0
        case .dissolve, .fade: return 1.0
        case .wipe, .push: return 0.5
        case .zoom, .spin: return 0.75
        case .glitch: return 0.2
        case .bioSync, .breath: return 2.0
        case .quantumCollapse, .heartbeat: return 0.5
        }
    }
}

//==============================================================================
// MARK: - AI Decision
//==============================================================================

/// AI-generated production decision
public struct AIDecision: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let action: AIAction
    public let confidence: Double
    public let reasoning: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: AIAction,
        confidence: Double,
        reasoning: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

public enum AIAction: Sendable {
    case switchCamera(sourceID: UUID, transition: TransitionType)
    case adjustVisuals(intensity: Double, mode: String)
    case triggerEffect(effectName: String)
    case adjustAudio(parameter: String, value: Double)
    case triggerLighting(cue: String)
    case startRecording
    case stopRecording
    case insertGraphic(graphicID: String)
    case adjustPacing(bpm: Double)
    case triggerBioSync(coherenceTarget: Double)
}

//==============================================================================
// MARK: - Production Event
//==============================================================================

public struct ProductionEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: EventType
    public let data: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        data: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.data = data
    }

    public enum EventType: String, Sendable {
        case cameraSwitched
        case transitionStarted
        case effectTriggered
        case recordingStarted
        case recordingEnded
        case streamStarted
        case streamEnded
        case bioEvent
        case beatDetected
        case audioPeak
        case coherencePeak
        case breathCycle
        case aiDecisionMade
    }
}

//==============================================================================
// MARK: - Streaming Output
//==============================================================================

public struct StreamingOutput: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var platform: StreamPlatform
    public var url: URL?
    public var streamKey: String?
    public var isActive: Bool
    public var bitrate: Int
    public var resolution: (width: Int, height: Int)

    public init(
        id: UUID = UUID(),
        name: String = "Stream",
        platform: StreamPlatform = .custom,
        url: URL? = nil,
        streamKey: String? = nil,
        isActive: Bool = false,
        bitrate: Int = 6000,
        resolution: (width: Int, height: Int) = (1920, 1080)
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.url = url
        self.streamKey = streamKey
        self.isActive = isActive
        self.bitrate = bitrate
        self.resolution = resolution
    }

    public enum StreamPlatform: String, CaseIterable, Identifiable, Sendable {
        case youtube = "YouTube"
        case twitch = "Twitch"
        case facebook = "Facebook"
        case instagram = "Instagram"
        case tiktok = "TikTok"
        case custom = "Custom RTMP"
        case srt = "SRT"
        case webrtc = "WebRTC"
        case ndi = "NDI"

        public var id: String { rawValue }
    }
}

//==============================================================================
// MARK: - AI Live Production Engine
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
@MainActor
public final class AILiveProductionEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    // State
    @Published public var isLive: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var productionMode: AIProductionMode = .concert
    @Published public var aiAutoDirectEnabled: Bool = true

    // Sources
    @Published public var cameraSources: [CameraSource] = []
    @Published public var programSource: UUID? = nil
    @Published public var previewSource: UUID? = nil

    // Transitions
    @Published public var currentTransition: TransitionType = .dissolve
    @Published public var transitionDuration: Double = 1.0
    @Published public var isTransitioning: Bool = false

    // Bio-reactive
    @Published public var coherence: Double = 0.5
    @Published public var heartRate: Double = 70.0
    @Published public var breathPhase: Double = 0.5
    @Published public var bioSyncEnabled: Bool = true

    // Audio
    @Published public var audioLevel: Double = 0.0
    @Published public var bpm: Double = 120.0
    @Published public var beatDetected: Bool = false

    // AI
    @Published public var aiConfidence: Double = 0.8
    @Published public var recentDecisions: [AIDecision] = []
    @Published public var eventLog: [ProductionEvent] = []

    // Streaming
    @Published public var streamingOutputs: [StreamingOutput] = []

    // Stats
    @Published public var uptime: TimeInterval = 0
    @Published public var frameDrops: Int = 0
    @Published public var outputFPS: Double = 60.0

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    private var cancellables = Set<AnyCancellable>()
    private var productionTimer: Timer?
    private var startTime: Date?

    // AI Parameters
    private var lastCameraSwitchTime: Date = Date.distantPast
    private var minSwitchInterval: TimeInterval = 3.0
    private var energyLevel: Double = 0.5
    private var attentionZones: [CGRect] = []

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        setupDefaultSources()
    }

    deinit {
        productionTimer?.invalidate()
    }

    private func setupDefaultSources() {
        cameraSources = [
            CameraSource(name: "Main Wide", type: .wideShot, position: .front),
            CameraSource(name: "Close Up", type: .closeUp, position: .front),
            CameraSource(name: "Side Left", type: .mediumShot, position: .left),
            CameraSource(name: "Side Right", type: .mediumShot, position: .right),
            CameraSource(name: "Overhead", type: .overhead, position: .overhead),
            CameraSource(name: "Generative", type: .generative, position: .front)
        ]

        if let firstID = cameraSources.first?.id {
            programSource = firstID
        }
        if cameraSources.count > 1 {
            previewSource = cameraSources[1].id
        }
    }

    //==========================================================================
    // MARK: - Production Control
    //==========================================================================

    public func goLive() {
        guard !isLive else { return }
        isLive = true
        startTime = Date()

        logEvent(.streamStarted)

        productionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        log.video("LIVE: Production started")
    }

    public func stopLive() {
        isLive = false
        productionTimer?.invalidate()
        productionTimer = nil
        logEvent(.streamEnded)

        log.video("OFFLINE: Production ended")
    }

    public func startRecording() {
        isRecording = true
        logEvent(.recordingStarted)
    }

    public func stopRecording() {
        isRecording = false
        logEvent(.recordingEnded)
    }

    private func tick() {
        guard isLive else { return }

        // Update uptime
        if let start = startTime {
            uptime = Date().timeIntervalSince(start)
        }

        // AI auto-direction
        if aiAutoDirectEnabled {
            processAIDirection()
        }

        // Bio-sync updates
        if bioSyncEnabled {
            processBioSync()
        }
    }

    //==========================================================================
    // MARK: - Camera Switching
    //==========================================================================

    public func switchToCamera(_ sourceID: UUID, transition: TransitionType? = nil) {
        guard let source = cameraSources.first(where: { $0.id == sourceID }) else { return }
        guard sourceID != programSource else { return }

        let trans = transition ?? currentTransition

        isTransitioning = true

        // Move current program to preview
        previewSource = programSource

        // Switch to new source
        programSource = sourceID

        logEvent(.cameraSwitched, data: ["camera": source.name, "transition": trans.rawValue])

        // Complete transition
        DispatchQueue.main.asyncAfter(deadline: .now() + trans.defaultDuration) { [weak self] in
            self?.isTransitioning = false
        }
    }

    public func cut() {
        if let preview = previewSource {
            switchToCamera(preview, transition: .cut)
        }
    }

    public func dissolve() {
        if let preview = previewSource {
            switchToCamera(preview, transition: .dissolve)
        }
    }

    //==========================================================================
    // MARK: - AI Direction
    //==========================================================================

    private func processAIDirection() {
        // Check if enough time has passed since last switch
        let timeSinceLastSwitch = Date().timeIntervalSince(lastCameraSwitchTime)
        guard timeSinceLastSwitch >= minSwitchInterval else { return }

        // Calculate optimal camera based on mode and context
        let decision = calculateAIDecision()

        if decision.confidence > 0.7 {
            executeAIDecision(decision)
            recentDecisions.insert(decision, at: 0)
            if recentDecisions.count > 20 {
                recentDecisions.removeLast()
            }
        }
    }

    private func calculateAIDecision() -> AIDecision {
        var confidence = 0.0
        var action: AIAction = .adjustPacing(bpm: bpm)
        var reasoning = ""

        switch productionMode {
        case .concert, .dj:
            // Beat-driven switching
            if beatDetected && energyLevel > 0.7 {
                if let closeUpID = cameraSources.first(where: { $0.type == .closeUp })?.id {
                    action = .switchCamera(sourceID: closeUpID, transition: .cut)
                    confidence = 0.8
                    reasoning = "High energy beat detected, switching to close-up"
                }
            } else if coherence > 0.8 {
                if let wideID = cameraSources.first(where: { $0.type == .wideShot })?.id {
                    action = .switchCamera(sourceID: wideID, transition: .dissolve)
                    confidence = 0.75
                    reasoning = "High coherence, showing wider perspective"
                }
            }

        case .meditation:
            // Slow, calm transitions
            if breathPhase < 0.2 || breathPhase > 0.8 {
                // At breath extremes, consider transition
                if let generativeID = cameraSources.first(where: { $0.type == .generative })?.id {
                    action = .switchCamera(sourceID: generativeID, transition: .breath)
                    confidence = 0.6
                    reasoning = "Breath cycle transition point"
                }
            }

        case .bioReactive:
            // Follow coherence closely
            if coherence > 0.9 {
                action = .triggerEffect(effectName: "coherence_burst")
                confidence = 0.9
                reasoning = "Peak coherence - triggering visual effect"
            } else if coherence < 0.3 {
                action = .adjustVisuals(intensity: 0.3, mode: "calm")
                confidence = 0.7
                reasoning = "Low coherence - reducing visual intensity"
            }

        case .quantumShow:
            // Random but controlled
            let randomFactor = Double.random(in: 0...1)
            if randomFactor > 0.85 {
                action = .triggerEffect(effectName: "quantum_collapse")
                confidence = 0.6
                reasoning = "Quantum probability event"
            }

        default:
            // Standard interview/presentation logic
            let timeFactor = min(1.0, Date().timeIntervalSince(lastCameraSwitchTime) / 10.0)
            confidence = timeFactor * 0.6
            if confidence > 0.5 {
                let nextCameraIndex = Int.random(in: 0..<cameraSources.count)
                action = .switchCamera(sourceID: cameraSources[nextCameraIndex].id, transition: .dissolve)
                reasoning = "Variety switch after \(Int(timeFactor * 10))s"
            }
        }

        return AIDecision(action: action, confidence: confidence, reasoning: reasoning)
    }

    private func executeAIDecision(_ decision: AIDecision) {
        switch decision.action {
        case .switchCamera(let sourceID, let transition):
            switchToCamera(sourceID, transition: transition)
            lastCameraSwitchTime = Date()

        case .adjustVisuals(let intensity, let mode):
            // Would trigger visual engine adjustments
            logEvent(.effectTriggered, data: ["effect": "visual_adjust", "intensity": "\(intensity)", "mode": mode])

        case .triggerEffect(let effectName):
            logEvent(.effectTriggered, data: ["effect": effectName])

        case .adjustPacing(let newBPM):
            bpm = newBPM

        case .triggerBioSync(let coherenceTarget):
            // Would sync with bio modulator
            logEvent(.bioEvent, data: ["target_coherence": "\(coherenceTarget)"])

        default:
            break
        }

        logEvent(.aiDecisionMade, data: ["action": "\(decision.action)", "confidence": "\(decision.confidence)"])
    }

    //==========================================================================
    // MARK: - Bio-Sync
    //==========================================================================

    private func processBioSync() {
        // Adjust transition timing based on breath
        if breathPhase > 0.4 && breathPhase < 0.6 {
            // At breath midpoint - stable
            minSwitchInterval = 4.0
        } else {
            // At extremes - can switch faster
            minSwitchInterval = 2.0
        }

        // Adjust energy based on heart rate and coherence
        let hrFactor = (heartRate - 60) / 80.0 // Normalize 60-140 BPM to 0-1
        energyLevel = (hrFactor + coherence) / 2.0
    }

    public func updateBioData(coherence: Double, heartRate: Double, breathPhase: Double) {
        self.coherence = coherence
        self.heartRate = heartRate
        self.breathPhase = breathPhase

        // Check for significant bio events
        if coherence > 0.9 {
            logEvent(.coherencePeak)
        }
        if breathPhase < 0.05 || breathPhase > 0.95 {
            logEvent(.breathCycle)
        }
    }

    //==========================================================================
    // MARK: - Audio Analysis
    //==========================================================================

    public func updateAudioData(level: Double, bpm: Double, beat: Bool) {
        self.audioLevel = level
        self.bpm = bpm

        if beat && !beatDetected {
            beatDetected = true
            logEvent(.beatDetected)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.beatDetected = false
            }
        }

        if level > 0.9 {
            logEvent(.audioPeak)
        }
    }

    //==========================================================================
    // MARK: - Event Logging
    //==========================================================================

    private func logEvent(_ type: ProductionEvent.EventType, data: [String: String] = [:]) {
        let event = ProductionEvent(type: type, data: data)
        eventLog.insert(event, at: 0)
        if eventLog.count > 100 {
            eventLog.removeLast()
        }
    }

    //==========================================================================
    // MARK: - Streaming
    //==========================================================================

    public func addStreamOutput(_ output: StreamingOutput) {
        streamingOutputs.append(output)
    }

    public func removeStreamOutput(id: UUID) {
        streamingOutputs.removeAll { $0.id == id }
    }

    public func startStreaming(outputID: UUID) {
        if let index = streamingOutputs.firstIndex(where: { $0.id == outputID }) {
            streamingOutputs[index].isActive = true
        }
    }

    public func stopStreaming(outputID: UUID) {
        if let index = streamingOutputs.firstIndex(where: { $0.id == outputID }) {
            streamingOutputs[index].isActive = false
        }
    }

    //==========================================================================
    // MARK: - Presets
    //==========================================================================

    public func loadConcertPreset() {
        productionMode = .concert
        currentTransition = .cut
        transitionDuration = 0.0
        minSwitchInterval = 2.0
        aiAutoDirectEnabled = true
    }

    public func loadMeditationPreset() {
        productionMode = .meditation
        currentTransition = .breath
        transitionDuration = 2.0
        minSwitchInterval = 10.0
        bioSyncEnabled = true
        aiAutoDirectEnabled = true
    }

    public func loadDJPreset() {
        productionMode = .dj
        currentTransition = .glitch
        transitionDuration = 0.2
        minSwitchInterval = 1.5
        aiAutoDirectEnabled = true
    }

    public func loadBioReactivePreset() {
        productionMode = .bioReactive
        currentTransition = .bioSync
        transitionDuration = 1.5
        minSwitchInterval = 3.0
        bioSyncEnabled = true
        aiAutoDirectEnabled = true
    }

    public func loadQuantumShowPreset() {
        productionMode = .quantumShow
        currentTransition = .quantumCollapse
        transitionDuration = 0.5
        minSwitchInterval = 2.0
        aiAutoDirectEnabled = true
    }
}

//==============================================================================
// MARK: - AI Live Production View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct AILiveProductionView: View {
    @ObservedObject var engine: AILiveProductionEngine
    @State private var showSettings = false
    @State private var showEventLog = false

    public init(engine: AILiveProductionEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top bar
            ProductionTopBar(engine: engine, showSettings: $showSettings)

            // Main content
            HStack(spacing: 0) {
                // Preview/Program monitors
                VStack(spacing: 8) {
                    PreviewMonitor(engine: engine)
                    ProgramMonitor(engine: engine)
                }
                .frame(maxWidth: .infinity)

                // Side panel
                ProductionSidePanel(engine: engine)
                    .frame(width: 250)
            }

            // Bottom controls
            ProductionControlBar(engine: engine, showEventLog: $showEventLog)
        }
        .sheet(isPresented: $showSettings) {
            ProductionSettingsView(engine: engine)
        }
        .sheet(isPresented: $showEventLog) {
            EventLogView(events: engine.eventLog)
        }
    }
}

//==============================================================================
// MARK: - Production Top Bar
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ProductionTopBar: View {
    @ObservedObject var engine: AILiveProductionEngine
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isLive ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
                Text(engine.isLive ? "LIVE" : "OFFLINE")
                    .font(.caption.bold())
                    .foregroundColor(engine.isLive ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(6)

            // Uptime
            if engine.isLive {
                Text(formatDuration(engine.uptime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Mode indicator
            Text(engine.productionMode.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(4)

            // AI indicator
            if engine.aiAutoDirectEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                    Text("AI")
                }
                .font(.caption)
                .foregroundColor(.cyan)
            }

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gear")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

//==============================================================================
// MARK: - Preview Monitor
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct PreviewMonitor: View {
    @ObservedObject var engine: AILiveProductionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIEW")
                .font(.caption2.bold())
                .foregroundColor(.yellow)

            ZStack {
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)

                if let previewID = engine.previewSource,
                   let source = engine.cameraSources.first(where: { $0.id == previewID }) {
                    VStack {
                        Image(systemName: cameraIcon(for: source.type))
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(source.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func cameraIcon(for type: CameraSource.CameraType) -> String {
        switch type {
        case .wideShot: return "camera"
        case .mediumShot: return "camera"
        case .closeUp: return "camera.metering.center.weighted"
        case .overhead: return "camera.metering.matrix"
        case .ptz: return "camera.aperture"
        case .drone: return "airplane"
        case .vr360: return "globe"
        case .screenCapture: return "rectangle.on.rectangle"
        case .generative: return "wand.and.stars"
        }
    }
}

//==============================================================================
// MARK: - Program Monitor
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ProgramMonitor: View {
    @ObservedObject var engine: AILiveProductionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PROGRAM")
                    .font(.caption2.bold())
                    .foregroundColor(.red)

                if engine.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("REC")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            ZStack {
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)

                if let programID = engine.programSource,
                   let source = engine.cameraSources.first(where: { $0.id == programID }) {
                    VStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text(source.name)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                // Transition overlay
                if engine.isTransitioning {
                    Color.white.opacity(0.3)
                }

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 3)
            }

            // Stats bar
            HStack {
                Text("\(Int(engine.outputFPS)) FPS")
                    .font(.caption2.monospacedDigit())
                Spacer()
                if engine.frameDrops > 0 {
                    Text("\(engine.frameDrops) drops")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

//==============================================================================
// MARK: - Production Side Panel
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ProductionSidePanel: View {
    @ObservedObject var engine: AILiveProductionEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Camera sources
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOURCES")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(engine.cameraSources) { source in
                        CameraSourceButton(source: source, engine: engine)
                    }
                }

                Divider()

                // Bio meters
                VStack(alignment: .leading, spacing: 8) {
                    Text("BIO-SYNC")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    BioMeterRow(label: "Coherence", value: engine.coherence, color: .cyan)
                    BioMeterRow(label: "Heart Rate", value: engine.heartRate / 200, color: .pink)
                    BioMeterRow(label: "Breath", value: engine.breathPhase, color: .green)
                }

                Divider()

                // AI status
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI DIRECTOR")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Toggle("Auto Direction", isOn: $engine.aiAutoDirectEnabled)
                        .font(.caption)

                    if let lastDecision = engine.recentDecisions.first {
                        Text(lastDecision.reasoning)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

//==============================================================================
// MARK: - Camera Source Button
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct CameraSourceButton: View {
    let source: CameraSource
    @ObservedObject var engine: AILiveProductionEngine

    var isProgram: Bool {
        engine.programSource == source.id
    }

    var isPreview: Bool {
        engine.previewSource == source.id
    }

    var body: some View {
        Button {
            if isProgram {
                // Already program, do nothing
            } else if isPreview {
                // Take to program
                engine.cut()
            } else {
                // Set as preview
                engine.previewSource = source.id
            }
        } label: {
            HStack {
                Text(source.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                if isProgram {
                    Text("PGM")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                } else if isPreview {
                    Text("PVW")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                }
            }
            .padding(8)
            .background(
                isProgram ? Color.red.opacity(0.3) :
                isPreview ? Color.yellow.opacity(0.3) :
                Color(.systemGray5)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

//==============================================================================
// MARK: - Bio Meter Row
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioMeterRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption2.monospacedDigit())
            }
            .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 4)
        }
    }
}

//==============================================================================
// MARK: - Production Control Bar
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ProductionControlBar: View {
    @ObservedObject var engine: AILiveProductionEngine
    @Binding var showEventLog: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Transition buttons
            Button("CUT") { engine.cut() }
                .buttonStyle(TransitionButtonStyle(isActive: engine.currentTransition == .cut))

            Button("DSLV") { engine.dissolve() }
                .buttonStyle(TransitionButtonStyle(isActive: engine.currentTransition == .dissolve))

            Divider()
                .frame(height: 30)

            // Live control
            Button(engine.isLive ? "STOP" : "GO LIVE") {
                if engine.isLive {
                    engine.stopLive()
                } else {
                    engine.goLive()
                }
            }
            .buttonStyle(LiveButtonStyle(isLive: engine.isLive))

            // Record control
            Button {
                if engine.isRecording {
                    engine.stopRecording()
                } else {
                    engine.startRecording()
                }
            } label: {
                Image(systemName: engine.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundColor(engine.isRecording ? .red : .primary)
            }

            Spacer()

            // Event log
            Button { showEventLog = true } label: {
                Image(systemName: "list.bullet.rectangle")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct TransitionButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color(.systemGray5))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(6)
    }
}

struct LiveButtonStyle: ButtonStyle {
    let isLive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isLive ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

//==============================================================================
// MARK: - Production Settings View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ProductionSettingsView: View {
    @ObservedObject var engine: AILiveProductionEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Production Mode") {
                    Picker("Mode", selection: $engine.productionMode) {
                        ForEach(AIProductionMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section("Transitions") {
                    Picker("Default Transition", selection: $engine.currentTransition) {
                        ForEach(TransitionType.allCases) { trans in
                            Text(trans.displayName).tag(trans)
                        }
                    }

                    Slider(value: $engine.transitionDuration, in: 0...5) {
                        Text("Duration: \(engine.transitionDuration, specifier: "%.1f")s")
                    }
                }

                Section("AI Director") {
                    Toggle("Auto Direction", isOn: $engine.aiAutoDirectEnabled)
                    Toggle("Bio-Sync", isOn: $engine.bioSyncEnabled)
                }

                Section("Presets") {
                    Button("Concert") { engine.loadConcertPreset() }
                    Button("Meditation") { engine.loadMeditationPreset() }
                    Button("DJ Set") { engine.loadDJPreset() }
                    Button("Bio-Reactive") { engine.loadBioReactivePreset() }
                    Button("Quantum Show") { engine.loadQuantumShowPreset() }
                }
            }
            .navigationTitle("Production Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

//==============================================================================
// MARK: - Event Log View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct EventLogView: View {
    let events: [ProductionEvent]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(events) { event in
                HStack {
                    Image(systemName: iconForEvent(event.type))
                        .foregroundColor(colorForEvent(event.type))

                    VStack(alignment: .leading) {
                        Text(event.type.rawValue)
                            .font(.caption.bold())
                        if !event.data.isEmpty {
                            Text(event.data.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(event.timestamp, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Event Log")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func iconForEvent(_ type: ProductionEvent.EventType) -> String {
        switch type {
        case .cameraSwitched: return "camera"
        case .transitionStarted: return "arrow.left.arrow.right"
        case .effectTriggered: return "wand.and.stars"
        case .recordingStarted, .recordingEnded: return "record.circle"
        case .streamStarted, .streamEnded: return "antenna.radiowaves.left.and.right"
        case .bioEvent: return "heart.fill"
        case .beatDetected: return "waveform"
        case .audioPeak: return "speaker.wave.3.fill"
        case .coherencePeak: return "sparkles"
        case .breathCycle: return "wind"
        case .aiDecisionMade: return "brain"
        }
    }

    private func colorForEvent(_ type: ProductionEvent.EventType) -> Color {
        switch type {
        case .cameraSwitched: return .blue
        case .transitionStarted: return .purple
        case .effectTriggered: return .orange
        case .recordingStarted, .recordingEnded: return .red
        case .streamStarted, .streamEnded: return .green
        case .bioEvent, .coherencePeak: return .cyan
        case .beatDetected, .audioPeak: return .yellow
        case .breathCycle: return .mint
        case .aiDecisionMade: return .purple
        }
    }
}
