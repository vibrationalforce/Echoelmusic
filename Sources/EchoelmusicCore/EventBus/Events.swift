import Foundation

// MARK: - Base Protocol

public protocol EventProtocol: Sendable {
    var timestamp: Date { get }
    var source: String { get }
}

// MARK: - Audio Events

public struct AudioEngineStartedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let sampleRate: Double
    public let bufferSize: Int

    public init(source: String = "AudioEngine", sampleRate: Double, bufferSize: Int) {
        self.timestamp = Date()
        self.source = source
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
    }
}

public struct AudioEngineStoppedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String

    public init(source: String = "AudioEngine") {
        self.timestamp = Date()
        self.source = source
    }
}

public struct AudioBufferReadyEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let level: Float
    public let pitch: Float?

    public init(source: String = "AudioEngine", level: Float, pitch: Float? = nil) {
        self.timestamp = Date()
        self.source = source
        self.level = level
        self.pitch = pitch
    }
}

// MARK: - Bio Events

public struct BioSignalUpdatedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let hrv: Double
    public let heartRate: Double
    public let coherence: Double

    public init(source: String = "HealthKitManager", hrv: Double, heartRate: Double, coherence: Double) {
        self.timestamp = Date()
        self.source = source
        self.hrv = hrv
        self.heartRate = heartRate
        self.coherence = coherence
    }
}

// MARK: - Control Events

public struct GestureDetectedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let gesture: String
    public let hand: String
    public let confidence: Float

    public init(source: String = "GestureRecognizer", gesture: String, hand: String, confidence: Float) {
        self.timestamp = Date()
        self.source = source
        self.gesture = gesture
        self.hand = hand
        self.confidence = confidence
    }
}

public struct ControlLoopTickEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let frameNumber: Int
    public let actualHz: Double

    public init(source: String = "UnifiedControlHub", frameNumber: Int, actualHz: Double) {
        self.timestamp = Date()
        self.source = source
        self.frameNumber = frameNumber
        self.actualHz = actualHz
    }
}

// MARK: - UI Events

public struct ModeChangedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let oldMode: String
    public let newMode: String

    public init(source: String = "UI", oldMode: String, newMode: String) {
        self.timestamp = Date()
        self.source = source
        self.oldMode = oldMode
        self.newMode = newMode
    }
}

public struct SessionLoadedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let sessionID: UUID
    public let sessionName: String

    public init(source: String = "SessionManager", sessionID: UUID, sessionName: String) {
        self.timestamp = Date()
        self.source = source
        self.sessionID = sessionID
        self.sessionName = sessionName
    }
}
