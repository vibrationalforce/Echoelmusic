// ProStreamEngine.swift
// Echoelmusic - Professional Streaming/Broadcasting Engine
//
// OBS Studio-class streaming engine with scenes, sources, encoding,
// multi-destination streaming, replay buffer, studio mode, and hotkeys.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import AVFoundation
import Combine

// MARK: - ProStreamEngine

/// Professional streaming and broadcasting engine.
///
/// Provides OBS Studio-class scene management, multi-destination streaming,
/// hardware encoding, replay buffer, studio mode, and hotkey automation.
@MainActor
public final class ProStreamEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public var scenes: [ProStreamScene] = []
    @Published public var programScene: ProStreamScene?
    @Published public var previewScene: ProStreamScene?
    @Published public var outputs: [StreamOutput] = []
    @Published public var isLive: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var studioMode: Bool = false
    @Published public var stats: StreamStats = StreamStats()

    // MARK: - Public Properties

    public var replayBuffer: ReplayBuffer = ReplayBuffer()
    public var hotkeys: [StreamHotkey] = []
    public var globalTransition: StreamSceneTransition = StreamSceneTransition(type: .fade, duration: 0.3, audioFade: true)
    public var audioMixer: StreamAudioMixer = StreamAudioMixer()
    public var multiStreamConfig: MultiStreamConfig = MultiStreamConfig()

    // MARK: - Private Properties

    private let log = ProfessionalLogger.shared
    private var cancellables = Set<AnyCancellable>()
    private var statsTimer: Timer?
    private var startTime: Date?

    // MARK: - Initialization

    public init() {
        log.log(.info, category: .streaming, "ProStreamEngine initialized")
    }

    deinit {
        statsTimer?.invalidate()
    }

    // MARK: - Scene Management

    /// Create a new scene and add it to the scene list
    @discardableResult
    public func addScene(name: String, color: SceneColor = .blue) -> ProStreamScene {
        let scene = ProStreamScene(name: name, color: color)
        scenes.append(scene)
        log.log(.info, category: .streaming, "Scene added: \(name)")

        // If this is the first scene, make it the program scene
        if scenes.count == 1 {
            programScene = scene
            if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
                scenes[index].isActive = true
            }
        }

        return scene
    }

    /// Remove a scene by ID
    public func removeScene(id: UUID) {
        scenes.removeAll { $0.id == id }
        if programScene?.id == id {
            programScene = scenes.first
        }
        if previewScene?.id == id {
            previewScene = nil
        }
        log.log(.info, category: .streaming, "Scene removed: \(id)")
    }

    /// Switch the live (program) output to a scene using the global transition
    public func switchScene(_ scene: ProStreamScene) {
        switchScene(scene, transition: globalTransition)
    }

    /// Switch scene by name (used by cue system bridge)
    public func switchSceneByName(_ name: String) {
        if let scene = scenes.first(where: { $0.name == name }) {
            switchScene(scene)
        }
    }

    /// Switch the live (program) output to a scene with a specific transition
    public func switchScene(_ scene: ProStreamScene, transition: StreamSceneTransition) {
        let previousID = programScene?.id

        // Batch scene state mutations into a single array update to reduce re-renders
        var updatedScenes = scenes
        if let prevID = previousID, let index = updatedScenes.firstIndex(where: { $0.id == prevID }) {
            updatedScenes[index].isActive = false
        }
        if let index = updatedScenes.firstIndex(where: { $0.id == scene.id }) {
            updatedScenes[index].isActive = true
        }
        scenes = updatedScenes
        programScene = scene

        log.log(
            .info,
            category: .streaming,
            "Scene switched to '\(scene.name)' (transition: \(transition.duration)s)"
        )
    }

    /// Set a scene as the studio mode preview
    public func setPreviewScene(_ scene: ProStreamScene) {
        // Batch preview state mutations into a single array update
        var updatedScenes = scenes
        if let prevID = previewScene?.id, let index = updatedScenes.firstIndex(where: { $0.id == prevID }) {
            updatedScenes[index].isPreview = false
        }
        if let index = updatedScenes.firstIndex(where: { $0.id == scene.id }) {
            updatedScenes[index].isPreview = true
        }
        scenes = updatedScenes
        previewScene = scene
        log.log(.debug, category: .streaming, "Preview set to '\(scene.name)'")
    }

    /// Studio mode: send the preview scene to program using the global transition
    public func transitionToProgram() {
        guard studioMode, let preview = previewScene else {
            log.log(.warning, category: .streaming, "Cannot transition: studio mode off or no preview")
            return
        }
        switchScene(preview, transition: preview.transition)
        previewScene = nil
        log.log(.info, category: .streaming, "Preview transitioned to program")
    }

    /// Studio mode: quick transition with a specific type (bypasses scene transition setting)
    public func quickTransition(type: StreamTransitionType) {
        guard studioMode, let preview = previewScene else { return }
        let transition = StreamSceneTransition(type: type, duration: 0.3, audioFade: true)
        switchScene(preview, transition: transition)
        previewScene = nil
    }

    // MARK: - Source Management

    /// Add a source to a scene and return it
    @discardableResult
    public func addSource(to sceneID: UUID, type: StreamSourceType, name: String) -> StreamSource? {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }) else {
            log.log(.error, category: .streaming, "Scene not found: \(sceneID)")
            return nil
        }

        let source = StreamSource(name: name, type: type)
        scenes[sceneIndex].sources.append(source)

        // Add a mixer channel for audio sources
        switch type {
        case .audioInput, .audioOutput, .camera, .mediaFile, .videoCapture, .ndiInput, .deckLink:
            let channel = AudioMixerChannel(name: name, sourceID: source.id)
            audioMixer.channels.append(channel)
        default:
            break
        }

        log.log(.info, category: .streaming, "Source '\(name)' added to scene")
        return source
    }

    /// Remove a source from a scene by IDs
    public func removeSource(from sceneID: UUID, sourceID: UUID) {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        scenes[sceneIndex].sources.removeAll { $0.id == sourceID }
        audioMixer.channels.removeAll { $0.sourceID == sourceID }
        log.log(.info, category: .streaming, "Source removed: \(sourceID)")
    }

    /// Toggle visibility of a source within its scene
    public func toggleSourceVisibility(sceneID: UUID, sourceID: UUID) {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        guard let sourceIndex = scenes[sceneIndex].sources.firstIndex(where: { $0.id == sourceID }) else { return }
        scenes[sceneIndex].sources[sourceIndex].isVisible.toggle()
    }

    /// Reorder sources within a scene (move from one index to another)
    public func reorderSource(sceneID: UUID, from: Int, to: Int) {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        guard from >= 0, from < scenes[sceneIndex].sources.count,
              to >= 0, to < scenes[sceneIndex].sources.count else { return }
        let source = scenes[sceneIndex].sources.remove(at: from)
        scenes[sceneIndex].sources.insert(source, at: to)
    }

    /// Add a filter to a source
    @discardableResult
    public func addFilter(to sceneID: UUID, sourceID: UUID, filter: StreamSourceFilter) -> Bool {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }),
              let sourceIndex = scenes[sceneIndex].sources.firstIndex(where: { $0.id == sourceID }) else {
            return false
        }
        scenes[sceneIndex].sources[sourceIndex].filters.append(filter)
        return true
    }

    // MARK: - Stream Control

    /// Start streaming on a specific output
    public func startStream(output: inout StreamOutput) {
        guard output.state == .idle || output.state == .error("") else {
            log.log(.warning, category: .streaming, "Output '\(output.name)' already active")
            return
        }

        output.state = .connecting
        updateOutput(output)

        // Simulate connection establishment
        var localOutput = output
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            localOutput.state = .active
            self.updateOutput(localOutput)
            self.refreshLiveState()
            self.startStatsCollection()
            self.log.log(.info, category: .streaming, "Stream started: \(localOutput.name)")
        }
    }

    /// Stop streaming on a specific output
    public func stopStream(output: inout StreamOutput) {
        output.state = .idle
        output.stats = OutputStats()
        updateOutput(output)
        refreshLiveState()
        log.log(.info, category: .streaming, "Stream stopped: \(output.name)")
    }

    /// Start all configured stream outputs
    public func startAllStreams() {
        for i in outputs.indices {
            if outputs[i].type != .recording && outputs[i].type != .replayBuffer {
                outputs[i].state = .connecting
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            for i in self.outputs.indices {
                if self.outputs[i].state == .connecting {
                    self.outputs[i].state = .active
                }
            }
            self.refreshLiveState()
            self.startStatsCollection()
            self.log.log(.info, category: .streaming, "All streams started (\(self.outputs.count) outputs)")
        }
    }

    /// Stop all stream outputs
    public func stopAllStreams() {
        for i in outputs.indices {
            outputs[i].state = .idle
            outputs[i].stats = OutputStats()
        }
        refreshLiveState()
        stopStatsCollection()
        log.log(.info, category: .streaming, "All streams stopped")
    }

    /// Start local recording
    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        // Ensure there is a recording output
        if !outputs.contains(where: { $0.type == .recording }) {
            let config = OutputConfig(
                recordingPath: NSTemporaryDirectory(),
                recordFormat: .mkv
            )
            let output = StreamOutput(name: "Recording", type: .recording, config: config, state: .active)
            outputs.append(output)
        } else if let index = outputs.firstIndex(where: { $0.type == .recording }) {
            outputs[index].state = .active
        }

        startStatsCollection()
        log.log(.info, category: .recording, "Recording started")
    }

    /// Stop local recording
    public func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        if let index = outputs.firstIndex(where: { $0.type == .recording }) {
            outputs[index].state = .idle
        }

        log.log(.info, category: .recording, "Recording stopped")
    }

    /// Toggle the replay buffer on/off
    public func toggleReplayBuffer() {
        replayBuffer.isActive.toggle()
        log.log(
            .info,
            category: .streaming,
            "Replay buffer \(replayBuffer.isActive ? "enabled" : "disabled") (\(replayBuffer.bufferDuration)s)"
        )
    }

    /// Save the current replay buffer contents to disk
    @discardableResult
    public func saveReplay() -> URL? {
        return replayBuffer.saveReplay()
    }

    /// Start the virtual camera output
    public func startVirtualCamera() {
        if !outputs.contains(where: { $0.type == .virtualCamera }) {
            let output = StreamOutput(name: "Virtual Camera", type: .virtualCamera, state: .active)
            outputs.append(output)
        } else if let index = outputs.firstIndex(where: { $0.type == .virtualCamera }) {
            outputs[index].state = .active
        }
        log.log(.info, category: .streaming, "Virtual camera started")
    }

    /// Stop the virtual camera output
    public func stopVirtualCamera() {
        if let index = outputs.firstIndex(where: { $0.type == .virtualCamera }) {
            outputs[index].state = .idle
        }
        log.log(.info, category: .streaming, "Virtual camera stopped")
    }

    // MARK: - Hotkey Management

    /// Register a new hotkey mapping
    @discardableResult
    public func addHotkey(name: String = "", trigger: HotkeyTrigger, action: HotkeyAction) -> StreamHotkey {
        let hotkeyName = name.isEmpty ? "Hotkey \(hotkeys.count + 1)" : name
        let hotkey = StreamHotkey(name: hotkeyName, trigger: trigger, action: action)
        hotkeys.append(hotkey)
        log.log(.debug, category: .streaming, "Hotkey registered: \(hotkeyName)")
        return hotkey
    }

    /// Remove a hotkey by ID
    public func removeHotkey(id: UUID) {
        hotkeys.removeAll { $0.id == id }
    }

    /// Process an incoming hotkey trigger and execute the bound action
    public func processHotkey(_ trigger: HotkeyTrigger) {
        for hotkey in hotkeys {
            if triggersMatch(hotkey.trigger, trigger) {
                executeAction(hotkey.action)
                log.log(.debug, category: .streaming, "Hotkey fired: \(hotkey.name)")
            }
        }
    }

    // MARK: - Stats

    /// Compute and return the current aggregate stream stats
    public func getStats() -> StreamStats {
        var aggregated = StreamStats()
        var activeCount = 0

        for output in outputs where output.state == .active {
            activeCount += 1
            aggregated.totalBitrate += output.stats.bitrate
            aggregated.droppedFrames += output.stats.droppedFrames
            aggregated.totalFrames += output.stats.totalFrames
            aggregated.bandwidthUsed += output.stats.bytesSent
            if output.stats.fps > aggregated.videoFPS {
                aggregated.videoFPS = output.stats.fps
            }
        }

        if let start = startTime {
            aggregated.uptime = Date().timeIntervalSince(start)
        }

        aggregated.quality = computeQuality(stats: aggregated)
        return aggregated
    }

    // MARK: - Studio Mode

    /// Toggle studio mode on or off
    public func toggleStudioMode() {
        studioMode.toggle()
        if studioMode {
            // In studio mode, current program stays; first non-program scene becomes preview
            if let firstNonProgram = scenes.first(where: { $0.id != programScene?.id }) {
                setPreviewScene(firstNonProgram)
            }
        } else {
            previewScene = nil
            for i in scenes.indices {
                scenes[i].isPreview = false
            }
        }
        log.log(.info, category: .streaming, "Studio mode \(studioMode ? "enabled" : "disabled")")
    }

    // MARK: - Output Management

    /// Add a stream output destination
    @discardableResult
    public func addOutput(name: String, type: OutputType, config: OutputConfig = OutputConfig()) -> StreamOutput {
        let output = StreamOutput(name: name, type: type, config: config)
        outputs.append(output)
        log.log(.info, category: .streaming, "Output added: \(name) (\(type.rawValue))")
        return output
    }

    /// Remove an output by ID
    public func removeOutput(id: UUID) {
        outputs.removeAll { $0.id == id }
    }

    // MARK: - Static Factory Methods

    /// Default setup with 3 scenes (Main, BRB, Ending), camera + mic + desktop sources
    public static func defaultSetup() -> ProStreamEngine {
        let engine = ProStreamEngine()

        // Scene 1: Main
        let mainScene = engine.addScene(name: "Main", color: SceneColor.green)
        engine.addSource(to: mainScene.id, type: .camera(index: 0), name: "Camera")
        engine.addSource(to: mainScene.id, type: .audioInput(device: "default"), name: "Microphone")
        engine.addSource(to: mainScene.id, type: .screenCapture, name: "Desktop Capture")

        // Scene 2: BRB
        let brbScene = engine.addScene(name: "BRB", color: SceneColor.yellow)
        engine.addSource(to: brbScene.id, type: .imageFile(URL(fileURLWithPath: "/brb.png")), name: "BRB Image")
        engine.addSource(to: brbScene.id, type: .audioInput(device: "default"), name: "Microphone")

        // Scene 3: Ending
        let endScene = engine.addScene(name: "Ending", color: SceneColor.red)
        engine.addSource(to: endScene.id, type: .colorSource(color: "#000000"), name: "Black Background")
        engine.addSource(to: endScene.id, type: .textGDI, name: "Thanks for Watching")

        engine.log.log(.info, category: .streaming, "Default setup created (3 scenes)")
        return engine
    }

    /// Music streaming setup with DAW capture, camera, visualizer, and bio overlay
    public static func musicStreamSetup() -> ProStreamEngine {
        let engine = ProStreamEngine()

        // Scene 1: Performance
        let perfScene = engine.addScene(name: "Performance", color: SceneColor.purple)
        engine.addSource(to: perfScene.id, type: .windowCapture, name: "DAW Capture")
        engine.addSource(to: perfScene.id, type: .camera(index: 0), name: "Artist Camera")
        engine.addSource(to: perfScene.id, type: .visualizer, name: "Audio Visualizer")
        engine.addSource(to: perfScene.id, type: .bioMetrics, name: "Bio Overlay")
        engine.addSource(to: perfScene.id, type: .audioOutput(device: "default"), name: "DAW Audio")

        // Scene 2: Close-Up
        let closeScene = engine.addScene(name: "Close-Up", color: SceneColor.cyan)
        engine.addSource(to: closeScene.id, type: .camera(index: 0), name: "Artist Camera")
        engine.addSource(to: closeScene.id, type: .audioOutput(device: "default"), name: "DAW Audio")

        // Scene 3: Visualizer Full
        let vizScene = engine.addScene(name: "Visualizer", color: SceneColor.blue)
        engine.addSource(to: vizScene.id, type: .visualizer, name: "Full Screen Visualizer")
        engine.addSource(to: vizScene.id, type: .audioOutput(device: "default"), name: "DAW Audio")

        engine.log.log(.info, category: .streaming, "Music stream setup created (3 scenes)")
        return engine
    }

    /// VJ streaming setup with VJ layers, DMX preview, laser preview, and multi-cam
    public static func vjStreamSetup() -> ProStreamEngine {
        let engine = ProStreamEngine()

        // Scene 1: Main Show
        let showScene = engine.addScene(name: "Main Show", color: SceneColor.purple)
        engine.addSource(to: showScene.id, type: .vjLayer, name: "VJ Layer A")
        engine.addSource(to: showScene.id, type: .vjLayer, name: "VJ Layer B")
        engine.addSource(to: showScene.id, type: .dmxPreview, name: "DMX Preview")
        engine.addSource(to: showScene.id, type: .audioInput(device: "default"), name: "Main Audio")

        // Scene 2: Laser Show
        let laserScene = engine.addScene(name: "Laser Show", color: SceneColor.green)
        engine.addSource(to: laserScene.id, type: .vjLayer, name: "Laser Preview")
        engine.addSource(to: laserScene.id, type: .dmxPreview, name: "DMX Lighting")
        engine.addSource(to: laserScene.id, type: .audioInput(device: "default"), name: "Main Audio")

        // Scene 3: Multi-Cam
        let multiScene = engine.addScene(name: "Multi-Cam", color: SceneColor.orange)
        engine.addSource(to: multiScene.id, type: .camera(index: 0), name: "Camera 1")
        engine.addSource(to: multiScene.id, type: .camera(index: 1), name: "Camera 2")
        engine.addSource(to: multiScene.id, type: .camera(index: 2), name: "Camera 3")
        engine.addSource(to: multiScene.id, type: .audioInput(device: "default"), name: "Main Audio")

        // Scene 4: PiP (Crowd + VJ)
        let pipScene = engine.addScene(name: "PiP Crowd", color: SceneColor.cyan)
        engine.addSource(to: pipScene.id, type: .vjLayer, name: "VJ Background")
        engine.addSource(to: pipScene.id, type: .camera(index: 0), name: "Crowd Camera")
        engine.addSource(to: pipScene.id, type: .audioInput(device: "default"), name: "Main Audio")

        engine.log.log(.info, category: .streaming, "VJ stream setup created (4 scenes)")
        return engine
    }

    /// Podcast setup with 2 cameras, 2 mics, screen share, and overlays
    public static func podcastSetup() -> ProStreamEngine {
        let engine = ProStreamEngine()

        // Scene 1: Dual Camera
        let dualScene = engine.addScene(name: "Dual Camera", color: SceneColor.blue)
        engine.addSource(to: dualScene.id, type: .camera(index: 0), name: "Host Camera")
        engine.addSource(to: dualScene.id, type: .camera(index: 1), name: "Guest Camera")
        engine.addSource(to: dualScene.id, type: .audioInput(device: "mic-host"), name: "Host Mic")
        engine.addSource(to: dualScene.id, type: .audioInput(device: "mic-guest"), name: "Guest Mic")
        engine.addSource(to: dualScene.id, type: .imageFile(URL(fileURLWithPath: "/overlay.png")), name: "Lower Third")

        // Scene 2: Host Solo
        let hostScene = engine.addScene(name: "Host Solo", color: SceneColor.green)
        engine.addSource(to: hostScene.id, type: .camera(index: 0), name: "Host Camera")
        engine.addSource(to: hostScene.id, type: .audioInput(device: "mic-host"), name: "Host Mic")
        engine.addSource(to: hostScene.id, type: .audioInput(device: "mic-guest"), name: "Guest Mic")

        // Scene 3: Guest Solo
        let guestScene = engine.addScene(name: "Guest Solo", color: SceneColor.orange)
        engine.addSource(to: guestScene.id, type: .camera(index: 1), name: "Guest Camera")
        engine.addSource(to: guestScene.id, type: .audioInput(device: "mic-host"), name: "Host Mic")
        engine.addSource(to: guestScene.id, type: .audioInput(device: "mic-guest"), name: "Guest Mic")

        // Scene 4: Screen Share
        let screenScene = engine.addScene(name: "Screen Share", color: SceneColor.yellow)
        engine.addSource(to: screenScene.id, type: .screenCapture, name: "Screen Capture")
        engine.addSource(to: screenScene.id, type: .camera(index: 0), name: "Host Camera PiP")
        engine.addSource(to: screenScene.id, type: .audioInput(device: "mic-host"), name: "Host Mic")
        engine.addSource(to: screenScene.id, type: .audioInput(device: "mic-guest"), name: "Guest Mic")

        // Scene 5: BRB
        let brbScene = engine.addScene(name: "BRB", color: SceneColor.red)
        engine.addSource(to: brbScene.id, type: .imageFile(URL(fileURLWithPath: "/podcast-brb.png")), name: "BRB Card")
        engine.addSource(to: brbScene.id, type: .audioInput(device: "default"), name: "Background Music")

        engine.log.log(.info, category: .streaming, "Podcast setup created (5 scenes)")
        return engine
    }

    // MARK: - Private Helpers

    /// Update an output in the outputs array by ID
    private func updateOutput(_ output: StreamOutput) {
        if let index = outputs.firstIndex(where: { $0.id == output.id }) {
            outputs[index] = output
        } else {
            outputs.append(output)
        }
    }

    /// Recalculate the isLive flag based on active outputs
    private func refreshLiveState() {
        isLive = outputs.contains { output in
            if case .active = output.state { return true }
            return false
        }
    }

    /// Start periodic stats collection
    private func startStatsCollection() {
        guard statsTimer == nil else { return }
        startTime = startTime ?? Date()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }

    /// Stop periodic stats collection
    private func stopStatsCollection() {
        guard !isLive && !isRecording else { return }
        statsTimer?.invalidate()
        statsTimer = nil
        startTime = nil
    }

    /// Update aggregate stats from all active outputs
    private func updateStats() {
        stats = getStats()
    }

    /// Determine stream quality from aggregate stats
    private func computeQuality(stats: StreamStats) -> StreamQualityLevel {
        let dropRate = stats.dropPercentage
        if dropRate < 0.1 {
            return .excellent
        } else if dropRate < 1.0 {
            return .good
        } else if dropRate < 5.0 {
            return .fair
        } else if dropRate < 10.0 {
            return .poor
        } else {
            return .critical
        }
    }

    /// Check if two hotkey triggers match
    private func triggersMatch(_ a: HotkeyTrigger, _ b: HotkeyTrigger) -> Bool {
        switch (a, b) {
        case let (.keyboard(keyA, modsA), .keyboard(keyB, modsB)):
            return keyA == keyB && Set(modsA) == Set(modsB)
        case let (.midiNote(noteA, chA), .midiNote(noteB, chB)):
            return noteA == noteB && chA == chB
        case let (.midiCC(ccA, chA, _), .midiCC(ccB, chB, _)):
            return ccA == ccB && chA == chB
        case let (.oscMessage(addrA), .oscMessage(addrB)):
            return addrA == addrB
        default:
            return false
        }
    }

    /// Execute a hotkey action
    private func executeAction(_ action: HotkeyAction) {
        switch action {
        case .switchScene(let id):
            if let scene = scenes.first(where: { $0.id == id }) {
                if studioMode {
                    setPreviewScene(scene)
                } else {
                    switchScene(scene)
                }
            }

        case .toggleSource(let id):
            for sceneIndex in scenes.indices {
                if let sourceIndex = scenes[sceneIndex].sources.firstIndex(where: { $0.id == id }) {
                    scenes[sceneIndex].sources[sourceIndex].isVisible.toggle()
                }
            }

        case .startStream:
            startAllStreams()

        case .stopStream:
            stopAllStreams()

        case .startRecording:
            startRecording()

        case .stopRecording:
            stopRecording()

        case .saveReplay:
            _ = saveReplay()

        case .toggleMute(let sourceID):
            audioMixer.toggleMute(for: sourceID)

        case .pushToTalk(let sourceID):
            // Unmute while held; re-mute is handled by key release (not modeled here)
            if let index = audioMixer.channels.firstIndex(where: { $0.sourceID == sourceID }) {
                audioMixer.channels[index].mute = false
            }

        case .transition:
            transitionToProgram()

        case .toggleStudioMode:
            toggleStudioMode()
        }
    }
}
