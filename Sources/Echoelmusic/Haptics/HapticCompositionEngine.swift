// HapticCompositionEngine.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Haptic Composition Engine - Transform bio signals into rich haptic experiences
// Multi-sensory feedback for immersive audio-visual sessions
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine
#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - Haptic Constants

/// Constants for haptic composition
public enum HapticConstants {
    public static let maxIntensity: Float = 1.0
    public static let minIntensity: Float = 0.0
    public static let maxSharpness: Float = 1.0
    public static let coherenceThreshold: Float = 0.7
    public static let heartbeatBaseInterval: TimeInterval = 0.85  // ~70 BPM
    public static let breathCycleBase: TimeInterval = 5.0  // 12 breaths/min
    public static let quantumPulseInterval: TimeInterval = 0.1
}

// MARK: - Haptic Pattern Types

/// Types of haptic patterns the engine can generate
public enum CompositionPatternType: String, CaseIterable, Identifiable, Sendable {
    case heartbeat = "Heartbeat"
    case breathing = "Breathing"
    case coherencePulse = "Coherence Pulse"
    case quantumFlutter = "Quantum Flutter"
    case waveform = "Waveform"
    case notification = "Notification"
    case meditation = "Meditation"
    case energy = "Energy"
    case calm = "Calm"
    case alert = "Alert"
    case success = "Success"
    case warning = "Warning"
    case rhythmic = "Rhythmic"
    case ambient = "Ambient"
    case bioSync = "Bio Sync"

    public var id: String { rawValue }
}

// MARK: - Haptic Event

/// Individual haptic event in a composition
public struct HapticEvent: Identifiable, Sendable {
    public let id = UUID()
    public var time: TimeInterval
    public var duration: TimeInterval
    public var intensity: Float
    public var sharpness: Float
    public var type: EventType

    public enum EventType: String, Sendable {
        case transient = "Transient"
        case continuous = "Continuous"
        case audioBased = "Audio Based"
    }

    public init(time: TimeInterval, duration: TimeInterval = 0.1, intensity: Float = 0.5, sharpness: Float = 0.5, type: EventType = .transient) {
        self.time = time
        self.duration = duration
        self.intensity = intensity.clamped(to: 0...1)
        self.sharpness = sharpness.clamped(to: 0...1)
        self.type = type
    }
}

// MARK: - Haptic Composition

/// A complete haptic composition with multiple events
public struct HapticComposition: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var events: [HapticEvent]
    public var duration: TimeInterval
    public var looping: Bool
    public var intensity: Float  // Master intensity

    public init(name: String, events: [HapticEvent] = [], looping: Bool = false, intensity: Float = 1.0) {
        self.name = name
        self.events = events
        self.duration = events.map { $0.time + $0.duration }.max() ?? 0
        self.looping = looping
        self.intensity = intensity
    }
}

// MARK: - Bio Haptic Data

/// Biometric data for haptic generation
public struct BioHapticData: Equatable, Sendable {
    public var heartRate: Double = 70.0
    public var hrvMs: Double = 50.0
    public var coherence: Float = 0.5
    public var breathingRate: Double = 12.0
    public var breathPhase: Float = 0.0  // 0-1, 0=inhale start, 0.5=exhale start
    public var gsr: Float = 0.5
    public var quantumCoherence: Float = 0.5

    public init() {}

    /// Normalized heart rate (0-1 range, 50-120 BPM)
    public var normalizedHeartRate: Float {
        Float((heartRate - 50) / 70).clamped(to: 0...1)
    }

    /// Heart beat interval in seconds
    public var heartbeatInterval: TimeInterval {
        60.0 / heartRate
    }

    /// Breath cycle duration in seconds
    public var breathCycleDuration: TimeInterval {
        60.0 / breathingRate
    }
}

// MARK: - Haptic Engine State

/// State of the haptic engine
public enum HapticEngineState: String, CaseIterable, Sendable {
    case idle = "Idle"
    case playing = "Playing"
    case paused = "Paused"
    case preparing = "Preparing"
    case error = "Error"
}

// MARK: - Haptic Composition Engine

/// Main haptic composition and playback engine
@MainActor
public final class HapticCompositionEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: HapticEngineState = .idle
    @Published public private(set) var isSupported: Bool = false
    @Published public private(set) var currentComposition: HapticComposition?
    @Published public private(set) var currentPattern: CompositionPatternType = .coherencePulse

    @Published public var masterIntensity: Float = 1.0
    @Published public var bioSyncEnabled: Bool = true
    @Published public var quantumSyncEnabled: Bool = true

    // MARK: - Bio Data

    public var bioData = BioHapticData()

    // MARK: - Private Properties

    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    public init() {
        checkHapticSupport()
        setupEngine()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Setup

    private func checkHapticSupport() {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        isSupported = capabilities.supportsHaptics
    }

    private func setupEngine() {
        guard isSupported else {
            log.info("HapticCompositionEngine: Haptics not supported on this device", category: .system)
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true

            // Handle engine reset
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }

            // Handle engine stop
            engine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.handleEngineStopped(reason: reason)
                }
            }

            try engine?.start()
            state = .idle
            log.info("HapticCompositionEngine: Engine initialized successfully", category: .system)

        } catch {
            log.error("HapticCompositionEngine: Failed to create engine: \(error)", category: .system)
            state = .error
        }
    }

    private func restartEngine() {
        do {
            try engine?.start()
            state = .idle
        } catch {
            log.error("HapticCompositionEngine: Failed to restart engine: \(error)", category: .system)
            state = .error
        }
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        switch reason {
        case .audioSessionInterrupt:
            log.warning("HapticCompositionEngine: Audio session interrupted", category: .system)
        case .applicationSuspended:
            log.info("HapticCompositionEngine: Application suspended", category: .system)
        case .engineDestroyed:
            log.info("HapticCompositionEngine: Engine destroyed", category: .system)
        case .gameControllerDisconnect:
            log.info("HapticCompositionEngine: Game controller disconnected", category: .system)
        case .idleTimeout:
            log.info("HapticCompositionEngine: Idle timeout", category: .system)
        case .notifyWhenFinished:
            log.info("HapticCompositionEngine: Playback finished", category: .system)
        case .systemError:
            log.error("HapticCompositionEngine: System error", category: .system)
        @unknown default:
            log.warning("HapticCompositionEngine: Unknown stop reason", category: .system)
        }
        state = .idle
    }

    // MARK: - Pattern Generation

    /// Generate a haptic pattern based on type and bio data
    public func generatePattern(_ type: CompositionPatternType) -> HapticComposition {
        currentPattern = type

        switch type {
        case .heartbeat:
            return generateHeartbeatPattern()
        case .breathing:
            return generateBreathingPattern()
        case .coherencePulse:
            return generateCoherencePulsePattern()
        case .quantumFlutter:
            return generateQuantumFlutterPattern()
        case .waveform:
            return generateWaveformPattern()
        case .notification:
            return generateNotificationPattern()
        case .meditation:
            return generateMeditationPattern()
        case .energy:
            return generateEnergyPattern()
        case .calm:
            return generateCalmPattern()
        case .alert:
            return generateAlertPattern()
        case .success:
            return generateSuccessPattern()
        case .warning:
            return generateWarningPattern()
        case .rhythmic:
            return generateRhythmicPattern()
        case .ambient:
            return generateAmbientPattern()
        case .bioSync:
            return generateBioSyncPattern()
        }
    }

    // MARK: - Pattern Generators

    private func generateHeartbeatPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let interval = bioSyncEnabled ? bioData.heartbeatInterval : HapticConstants.heartbeatBaseInterval
        let intensity = Float(0.6 + bioData.normalizedHeartRate * 0.4)

        // Two-beat pattern: lub-dub
        for beat in 0..<4 {
            let baseTime = TimeInterval(beat) * interval

            // First beat (lub) - stronger
            events.append(HapticEvent(
                time: baseTime,
                duration: 0.1,
                intensity: intensity * masterIntensity,
                sharpness: 0.7,
                type: .transient
            ))

            // Second beat (dub) - softer
            events.append(HapticEvent(
                time: baseTime + 0.15,
                duration: 0.08,
                intensity: intensity * 0.6 * masterIntensity,
                sharpness: 0.5,
                type: .transient
            ))
        }

        return HapticComposition(name: "Heartbeat", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateBreathingPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let cycleDuration = bioSyncEnabled ? bioData.breathCycleDuration : HapticConstants.breathCycleBase
        let inhaleDuration = cycleDuration * 0.4
        let exhaleDuration = cycleDuration * 0.6

        // Inhale - rising intensity
        let inhaleSteps = 10
        for step in 0..<inhaleSteps {
            let progress = Float(step) / Float(inhaleSteps)
            let time = TimeInterval(step) * inhaleDuration / TimeInterval(inhaleSteps)

            events.append(HapticEvent(
                time: time,
                duration: inhaleDuration / TimeInterval(inhaleSteps),
                intensity: progress * 0.7 * masterIntensity,
                sharpness: 0.3 + progress * 0.2,
                type: .continuous
            ))
        }

        // Exhale - falling intensity
        let exhaleSteps = 15
        for step in 0..<exhaleSteps {
            let progress = Float(step) / Float(exhaleSteps)
            let time = inhaleDuration + TimeInterval(step) * exhaleDuration / TimeInterval(exhaleSteps)

            events.append(HapticEvent(
                time: time,
                duration: exhaleDuration / TimeInterval(exhaleSteps),
                intensity: (1.0 - progress) * 0.7 * masterIntensity,
                sharpness: 0.5 - progress * 0.3,
                type: .continuous
            ))
        }

        return HapticComposition(name: "Breathing", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateCoherencePulsePattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let coherence = bioSyncEnabled ? bioData.coherence : 0.5
        let pulseCount = Int(5 + coherence * 10)  // More pulses at higher coherence

        for i in 0..<pulseCount {
            let progress = Float(i) / Float(pulseCount)
            let time = TimeInterval(i) * 0.2

            // Intensity rises then falls based on coherence
            let envelope = sin(progress * Float.pi)
            let intensity = envelope * coherence * masterIntensity

            events.append(HapticEvent(
                time: time,
                duration: 0.15,
                intensity: intensity,
                sharpness: 0.3 + coherence * 0.4,
                type: .transient
            ))
        }

        return HapticComposition(name: "Coherence Pulse", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateQuantumFlutterPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let quantumCoherence = quantumSyncEnabled ? bioData.quantumCoherence : 0.5

        // Rapid, irregular pulses simulating quantum fluctuations
        var time: TimeInterval = 0
        for _ in 0..<20 {
            let interval = TimeInterval.random(in: 0.02...0.1) * TimeInterval(1.5 - quantumCoherence)
            let intensity = Float.random(in: 0.3...0.9) * masterIntensity
            let sharpness = Float.random(in: 0.6...1.0)

            events.append(HapticEvent(
                time: time,
                duration: 0.03,
                intensity: intensity,
                sharpness: sharpness,
                type: .transient
            ))

            time += interval
        }

        return HapticComposition(name: "Quantum Flutter", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateWaveformPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let steps = 30
        let duration = 3.0

        for step in 0..<steps {
            let progress = Float(step) / Float(steps)
            let time = TimeInterval(step) * duration / TimeInterval(steps)

            // Sine wave intensity
            let wave = sin(progress * Float.pi * 4) * 0.5 + 0.5

            events.append(HapticEvent(
                time: time,
                duration: duration / TimeInterval(steps),
                intensity: wave * masterIntensity,
                sharpness: 0.4,
                type: .continuous
            ))
        }

        return HapticComposition(name: "Waveform", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateNotificationPattern() -> HapticComposition {
        let events = [
            HapticEvent(time: 0, duration: 0.1, intensity: 0.8 * masterIntensity, sharpness: 0.8, type: .transient),
            HapticEvent(time: 0.15, duration: 0.1, intensity: 0.6 * masterIntensity, sharpness: 0.6, type: .transient),
            HapticEvent(time: 0.3, duration: 0.15, intensity: 1.0 * masterIntensity, sharpness: 1.0, type: .transient)
        ]
        return HapticComposition(name: "Notification", events: events, looping: false, intensity: masterIntensity)
    }

    private func generateMeditationPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let cycleDuration = 8.0  // Slow, meditative pace

        // Gentle, slow waves
        let steps = 40
        for step in 0..<steps {
            let progress = Float(step) / Float(steps)
            let time = TimeInterval(step) * cycleDuration / TimeInterval(steps)

            // Very gentle sine wave
            let wave = sin(progress * Float.pi * 2) * 0.3 + 0.3

            events.append(HapticEvent(
                time: time,
                duration: cycleDuration / TimeInterval(steps),
                intensity: wave * masterIntensity,
                sharpness: 0.2,
                type: .continuous
            ))
        }

        return HapticComposition(name: "Meditation", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateEnergyPattern() -> HapticComposition {
        var events: [HapticEvent] = []

        // Building, energetic pulses
        for i in 0..<16 {
            let progress = Float(i) / 16.0
            let time = TimeInterval(i) * 0.1

            events.append(HapticEvent(
                time: time,
                duration: 0.05,
                intensity: (0.4 + progress * 0.6) * masterIntensity,
                sharpness: 0.7 + progress * 0.3,
                type: .transient
            ))
        }

        return HapticComposition(name: "Energy", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateCalmPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let duration = 6.0

        // Very gentle, continuous hum
        events.append(HapticEvent(
            time: 0,
            duration: duration,
            intensity: 0.2 * masterIntensity,
            sharpness: 0.1,
            type: .continuous
        ))

        // Occasional soft pulses
        for i in 0..<3 {
            events.append(HapticEvent(
                time: TimeInterval(i + 1) * 1.5,
                duration: 0.3,
                intensity: 0.3 * masterIntensity,
                sharpness: 0.2,
                type: .transient
            ))
        }

        return HapticComposition(name: "Calm", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateAlertPattern() -> HapticComposition {
        var events: [HapticEvent] = []

        // Sharp, attention-grabbing pulses
        for i in 0..<5 {
            events.append(HapticEvent(
                time: TimeInterval(i) * 0.12,
                duration: 0.05,
                intensity: 1.0 * masterIntensity,
                sharpness: 1.0,
                type: .transient
            ))
        }

        return HapticComposition(name: "Alert", events: events, looping: false, intensity: masterIntensity)
    }

    private func generateSuccessPattern() -> HapticComposition {
        let events = [
            HapticEvent(time: 0, duration: 0.1, intensity: 0.5 * masterIntensity, sharpness: 0.5, type: .transient),
            HapticEvent(time: 0.1, duration: 0.1, intensity: 0.7 * masterIntensity, sharpness: 0.6, type: .transient),
            HapticEvent(time: 0.2, duration: 0.2, intensity: 1.0 * masterIntensity, sharpness: 0.8, type: .transient)
        ]
        return HapticComposition(name: "Success", events: events, looping: false, intensity: masterIntensity)
    }

    private func generateWarningPattern() -> HapticComposition {
        var events: [HapticEvent] = []

        // Two strong pulses
        events.append(HapticEvent(time: 0, duration: 0.15, intensity: 0.9 * masterIntensity, sharpness: 0.9, type: .transient))
        events.append(HapticEvent(time: 0.25, duration: 0.15, intensity: 0.9 * masterIntensity, sharpness: 0.9, type: .transient))

        return HapticComposition(name: "Warning", events: events, looping: false, intensity: masterIntensity)
    }

    private func generateRhythmicPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let bpm: Double = bioSyncEnabled ? bioData.heartRate : 120
        let beatInterval = 60.0 / bpm

        // 4/4 rhythm pattern
        for beat in 0..<8 {
            let time = TimeInterval(beat) * beatInterval
            let isDownbeat = beat % 4 == 0
            let isUpbeat = beat % 2 == 0

            let intensity: Float = isDownbeat ? 1.0 : (isUpbeat ? 0.7 : 0.4)

            events.append(HapticEvent(
                time: time,
                duration: 0.05,
                intensity: intensity * masterIntensity,
                sharpness: isDownbeat ? 0.8 : 0.5,
                type: .transient
            ))
        }

        return HapticComposition(name: "Rhythmic", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateAmbientPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        let duration = 10.0

        // Random gentle pulses
        var time: TimeInterval = 0
        while time < duration {
            let interval = TimeInterval.random(in: 0.5...2.0)
            let intensity = Float.random(in: 0.1...0.4)

            events.append(HapticEvent(
                time: time,
                duration: 0.3,
                intensity: intensity * masterIntensity,
                sharpness: 0.2,
                type: .transient
            ))

            time += interval
        }

        return HapticComposition(name: "Ambient", events: events, looping: true, intensity: masterIntensity)
    }

    private func generateBioSyncPattern() -> HapticComposition {
        var events: [HapticEvent] = []
        var time: TimeInterval = 0

        // Combine heartbeat and breathing
        let heartInterval = bioData.heartbeatInterval
        let breathDuration = bioData.breathCycleDuration

        // Add heartbeat events
        for _ in 0..<4 {
            events.append(HapticEvent(
                time: time,
                duration: 0.1,
                intensity: 0.6 * masterIntensity,
                sharpness: 0.7,
                type: .transient
            ))
            time += heartInterval
        }

        // Overlay breath wave
        let breathSteps = 20
        for step in 0..<breathSteps {
            let progress = Float(step) / Float(breathSteps)
            let breathTime = TimeInterval(step) * breathDuration / TimeInterval(breathSteps)

            let wave = sin(progress * Float.pi) * 0.4

            events.append(HapticEvent(
                time: breathTime,
                duration: breathDuration / TimeInterval(breathSteps),
                intensity: wave * masterIntensity,
                sharpness: 0.3,
                type: .continuous
            ))
        }

        return HapticComposition(name: "Bio Sync", events: events, looping: true, intensity: masterIntensity)
    }

    // MARK: - Playback

    /// Play a haptic composition
    public func play(_ composition: HapticComposition) {
        guard isSupported, let engine = engine else {
            log.warning("HapticCompositionEngine: Cannot play - engine not available", category: .system)
            return
        }

        do {
            let pattern = try createHapticPattern(from: composition)
            let player = try engine.makeAdvancedPlayer(with: pattern)

            // Handle completion
            player.completionHandler = { [weak self] error in
                Task { @MainActor in
                    if let error = error {
                        log.error("HapticCompositionEngine: Playback error: \(error)", category: .system)
                    }

                    if composition.looping {
                        self?.play(composition)
                    } else {
                        self?.state = .idle
                        self?.currentComposition = nil
                    }
                }
            }

            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
            currentComposition = composition
            state = .playing

            log.info("HapticCompositionEngine: Playing '\(composition.name)'", category: .system)

        } catch {
            log.error("HapticCompositionEngine: Failed to play: \(error)", category: .system)
            state = .error
        }
    }

    /// Play a pattern type
    public func playPattern(_ type: CompositionPatternType) {
        let composition = generatePattern(type)
        play(composition)
    }

    /// Stop playback
    public func stop() {
        try? continuousPlayer?.cancel()
        continuousPlayer = nil
        currentComposition = nil
        state = .idle
        log.info("HapticCompositionEngine: Stopped", category: .system)
    }

    /// Pause playback
    public func pause() {
        guard state == .playing else { return }
        try? continuousPlayer?.pause(atTime: CHHapticTimeImmediate)
        state = .paused
    }

    /// Resume playback
    public func resume() {
        guard state == .paused else { return }
        try? continuousPlayer?.resume(atTime: CHHapticTimeImmediate)
        state = .playing
    }

    // MARK: - Quick Haptics

    /// Play a single transient haptic
    public func playTransient(intensity: Float = 0.5, sharpness: Float = 0.5) {
        guard isSupported, let engine = engine else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * masterIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

        } catch {
            log.error("HapticCompositionEngine: Transient failed: \(error)", category: .system)
        }
    }

    /// Play impact feedback
    public func playImpact(style: ImpactStyle = .medium) {
        let intensity: Float
        let sharpness: Float

        switch style {
        case .light:
            intensity = 0.4
            sharpness = 0.4
        case .medium:
            intensity = 0.7
            sharpness = 0.6
        case .heavy:
            intensity = 1.0
            sharpness = 0.8
        case .soft:
            intensity = 0.5
            sharpness = 0.2
        case .rigid:
            intensity = 0.8
            sharpness = 1.0
        }

        playTransient(intensity: intensity, sharpness: sharpness)
    }

    public enum ImpactStyle {
        case light, medium, heavy, soft, rigid
    }

    // MARK: - Helpers

    private func createHapticPattern(from composition: HapticComposition) throws -> CHHapticPattern {
        var hapticEvents: [CHHapticEvent] = []

        for event in composition.events {
            let hapticEvent: CHHapticEvent

            switch event.type {
            case .transient:
                hapticEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                    ],
                    relativeTime: event.time
                )

            case .continuous, .audioBased:
                hapticEvent = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                    ],
                    relativeTime: event.time,
                    duration: event.duration
                )
            }

            hapticEvents.append(hapticEvent)
        }

        return try CHHapticPattern(events: hapticEvents, parameters: [])
    }

    // MARK: - Bio Data Update

    /// Update bio data for sync
    public func updateBioData(_ data: BioHapticData) {
        bioData = data

        // If currently playing bio-synced pattern, regenerate
        if state == .playing, bioSyncEnabled {
            if [.heartbeat, .breathing, .bioSync, .coherencePulse].contains(currentPattern) {
                let newComposition = generatePattern(currentPattern)
                play(newComposition)
            }
        }
    }

    /// Update quantum coherence
    public func updateQuantumCoherence(_ coherence: Float) {
        bioData.quantumCoherence = coherence

        if state == .playing, quantumSyncEnabled, currentPattern == .quantumFlutter {
            let newComposition = generatePattern(.quantumFlutter)
            play(newComposition)
        }
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift
