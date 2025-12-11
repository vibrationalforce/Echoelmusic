// EventBus.swift
// Echoelmusic - Decoupled Event Communication
// Wise Mode Implementation

import Foundation
import Combine
import simd

// MARK: - App Events

/// All events that can be published through the event bus
public enum AppEvent: Equatable {

    // MARK: - Audio Events
    case audioEngineStarted
    case audioEngineStopped
    case audioLevelChanged(Float)
    case audioBufferProcessed(frameCount: Int)
    case audioFormatChanged(sampleRate: Double, channels: Int)

    // MARK: - MIDI Events
    case midiConnected(device: String)
    case midiDisconnected(device: String)
    case midiNoteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    case midiNoteOff(note: UInt8, channel: UInt8)
    case midiControlChange(controller: UInt8, value: UInt8, channel: UInt8)
    case midiPitchBend(value: UInt16, channel: UInt8)
    case midiAftertouch(pressure: UInt8, channel: UInt8)

    // MARK: - Spatial Events
    case spatialModeChanged(SpatialMode)
    case listenerPositionChanged(SIMD3<Float>)
    case sourcePositionChanged(sourceId: String, position: SIMD3<Float>)
    case headTrackingUpdated(yaw: Float, pitch: Float, roll: Float)

    // MARK: - Visual Events
    case visualizationModeChanged(VisualizationModeType)
    case visualizationParameterChanged(parameter: String, value: Float)
    case renderFrameCompleted(fps: Double)

    // MARK: - Biofeedback Events
    case heartRateUpdated(bpm: Double)
    case hrvUpdated(rmssd: Double)
    case coherenceUpdated(score: Double)
    case biofeedbackStateChanged(isMonitoring: Bool)

    // MARK: - Face Tracking Events
    case faceTrackingStarted
    case faceTrackingStopped
    case faceExpressionChanged([String: Float])

    // MARK: - Gesture Events
    case gestureRecognized(GestureEventType)
    case handTrackingUpdated(leftHand: Bool, rightHand: Bool)

    // MARK: - Recording Events
    case recordingStarted(sessionId: String)
    case recordingStopped(sessionId: String, duration: TimeInterval)
    case recordingPaused
    case recordingResumed
    case trackAdded(trackId: String)
    case trackRemoved(trackId: String)

    // MARK: - LED Events
    case ledConnected(device: String)
    case ledDisconnected(device: String)
    case ledPatternChanged(LEDPattern)
    case ledColorChanged(r: UInt8, g: UInt8, b: UInt8)

    // MARK: - System Events
    case appBecameActive
    case appResignedActive
    case memoryWarning
    case errorOccurred(domain: String, message: String)

    // MARK: - Equatable

    public static func == (lhs: AppEvent, rhs: AppEvent) -> Bool {
        switch (lhs, rhs) {
        case (.audioEngineStarted, .audioEngineStarted),
             (.audioEngineStopped, .audioEngineStopped),
             (.faceTrackingStarted, .faceTrackingStarted),
             (.faceTrackingStopped, .faceTrackingStopped),
             (.recordingPaused, .recordingPaused),
             (.recordingResumed, .recordingResumed),
             (.appBecameActive, .appBecameActive),
             (.appResignedActive, .appResignedActive),
             (.memoryWarning, .memoryWarning):
            return true
        case (.audioLevelChanged(let a), .audioLevelChanged(let b)):
            return a == b
        case (.midiNoteOn(let n1, let v1, let c1), .midiNoteOn(let n2, let v2, let c2)):
            return n1 == n2 && v1 == v2 && c1 == c2
        case (.spatialModeChanged(let a), .spatialModeChanged(let b)):
            return a == b
        case (.visualizationModeChanged(let a), .visualizationModeChanged(let b)):
            return a == b
        case (.heartRateUpdated(let a), .heartRateUpdated(let b)):
            return a == b
        case (.coherenceUpdated(let a), .coherenceUpdated(let b)):
            return a == b
        case (.ledPatternChanged(let a), .ledPatternChanged(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Gesture event types
public enum GestureEventType: String, Equatable {
    case pinch = "Pinch"
    case spread = "Spread"
    case fist = "Fist"
    case point = "Point"
    case swipeLeft = "SwipeLeft"
    case swipeRight = "SwipeRight"
    case swipeUp = "SwipeUp"
    case swipeDown = "SwipeDown"
    case rotate = "Rotate"
    case tap = "Tap"
    case doubleTap = "DoubleTap"
    case longPress = "LongPress"
}

// MARK: - Event Bus

/// Centralized event bus for decoupled communication between modules
@MainActor
public final class EventBus: ObservableObject {

    // MARK: - Singleton

    public static let shared = EventBus()

    // MARK: - Publishers

    private let subject = PassthroughSubject<AppEvent, Never>()

    /// Publisher for all events
    public var publisher: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - Event History

    private var eventHistory: [EventRecord] = []
    private let maxHistorySize = 500

    public struct EventRecord: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let event: AppEvent
    }

    // MARK: - Subscriptions

    private var subscriptions: [UUID: AnyCancellable] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Publishing

    /// Emit an event to all subscribers
    public func emit(_ event: AppEvent) {
        // Record event
        eventHistory.append(EventRecord(timestamp: Date(), event: event))
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst()
        }

        // Log event
        Logger.debug("Event: \(event)", category: .system)

        // Publish
        subject.send(event)
    }

    /// Emit multiple events
    public func emit(_ events: [AppEvent]) {
        events.forEach { emit($0) }
    }

    // MARK: - Subscribing

    /// Subscribe to all events
    public func subscribe(handler: @escaping (AppEvent) -> Void) -> UUID {
        let id = UUID()
        subscriptions[id] = publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
        return id
    }

    /// Subscribe to specific event type using pattern matching
    public func subscribe<T>(
        matching extractor: @escaping (AppEvent) -> T?,
        handler: @escaping (T) -> Void
    ) -> UUID {
        let id = UUID()
        subscriptions[id] = publisher
            .compactMap(extractor)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
        return id
    }

    /// Unsubscribe from events
    public func unsubscribe(_ id: UUID) {
        subscriptions[id]?.cancel()
        subscriptions.removeValue(forKey: id)
    }

    /// Unsubscribe all
    public func unsubscribeAll() {
        subscriptions.values.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    // MARK: - Convenience Subscribers

    /// Subscribe to audio level changes
    public func onAudioLevel(handler: @escaping (Float) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .audioLevelChanged(let level) = event { return level }
            return nil
        }, handler: handler)
    }

    /// Subscribe to MIDI note on events
    public func onMIDINoteOn(handler: @escaping (UInt8, UInt8, UInt8) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .midiNoteOn(let note, let velocity, let channel) = event {
                return (note, velocity, channel)
            }
            return nil
        }, handler: { handler($0.0, $0.1, $0.2) })
    }

    /// Subscribe to heart rate updates
    public func onHeartRate(handler: @escaping (Double) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .heartRateUpdated(let bpm) = event { return bpm }
            return nil
        }, handler: handler)
    }

    /// Subscribe to coherence updates
    public func onCoherence(handler: @escaping (Double) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .coherenceUpdated(let score) = event { return score }
            return nil
        }, handler: handler)
    }

    /// Subscribe to gesture events
    public func onGesture(handler: @escaping (GestureEventType) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .gestureRecognized(let gesture) = event { return gesture }
            return nil
        }, handler: handler)
    }

    /// Subscribe to spatial mode changes
    public func onSpatialModeChange(handler: @escaping (SpatialMode) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .spatialModeChanged(let mode) = event { return mode }
            return nil
        }, handler: handler)
    }

    /// Subscribe to visualization mode changes
    public func onVisualizationModeChange(handler: @escaping (VisualizationModeType) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .visualizationModeChanged(let mode) = event { return mode }
            return nil
        }, handler: handler)
    }

    /// Subscribe to errors
    public func onError(handler: @escaping (String, String) -> Void) -> UUID {
        subscribe(matching: { event in
            if case .errorOccurred(let domain, let message) = event {
                return (domain, message)
            }
            return nil
        }, handler: { handler($0.0, $0.1) })
    }

    // MARK: - History Access

    /// Get recent events
    public func getHistory(limit: Int = 100) -> [EventRecord] {
        Array(eventHistory.suffix(limit))
    }

    /// Get events of specific type
    public func getHistory(matching predicate: (AppEvent) -> Bool) -> [EventRecord] {
        eventHistory.filter { predicate($0.event) }
    }

    /// Clear event history
    public func clearHistory() {
        eventHistory.removeAll()
    }
}

// MARK: - Event Bus Extensions

extension EventBus {

    /// Emit audio-related event
    public func emitAudio(_ event: AppEvent) {
        guard case .audioEngineStarted = event else {
            if case .audioEngineStopped = event { } else {
                if case .audioLevelChanged = event { } else {
                    if case .audioBufferProcessed = event { } else {
                        if case .audioFormatChanged = event { } else {
                            Logger.warning("emitAudio called with non-audio event", category: .audio)
                            return
                        }
                    }
                }
            }
        }
        emit(event)
    }

    /// Emit MIDI-related event
    public func emitMIDI(_ event: AppEvent) {
        emit(event)
    }

    /// Emit biofeedback-related event
    public func emitBio(_ event: AppEvent) {
        emit(event)
    }
}

// MARK: - Reactive Extensions

extension Publisher where Output == AppEvent, Failure == Never {

    /// Filter for audio events
    public func audioEvents() -> AnyPublisher<AppEvent, Never> {
        filter { event in
            switch event {
            case .audioEngineStarted, .audioEngineStopped, .audioLevelChanged, .audioBufferProcessed, .audioFormatChanged:
                return true
            default:
                return false
            }
        }
        .eraseToAnyPublisher()
    }

    /// Filter for MIDI events
    public func midiEvents() -> AnyPublisher<AppEvent, Never> {
        filter { event in
            switch event {
            case .midiConnected, .midiDisconnected, .midiNoteOn, .midiNoteOff, .midiControlChange, .midiPitchBend, .midiAftertouch:
                return true
            default:
                return false
            }
        }
        .eraseToAnyPublisher()
    }

    /// Filter for biofeedback events
    public func biofeedbackEvents() -> AnyPublisher<AppEvent, Never> {
        filter { event in
            switch event {
            case .heartRateUpdated, .hrvUpdated, .coherenceUpdated, .biofeedbackStateChanged:
                return true
            default:
                return false
            }
        }
        .eraseToAnyPublisher()
    }

    /// Throttle high-frequency events
    public func throttled(interval: TimeInterval) -> AnyPublisher<AppEvent, Never> {
        throttle(for: .seconds(interval), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
}
