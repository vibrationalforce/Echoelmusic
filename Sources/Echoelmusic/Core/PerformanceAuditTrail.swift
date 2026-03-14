// PerformanceAuditTrail.swift
// Echoelmusic - Structured Performance Event Logging
//
// Inspired by Paperclip's activity logging and audit trail pattern:
// all mutating actions are logged with actor identity, timestamp,
// and metadata for complete session reconstruction.
//
// Enables post-performance analysis: "what happened and when"
// for biofeedback sessions, live performances, and recordings.
//
// Supported Platforms: ALL
// Created 2026-03-14

import Foundation

// MARK: - Audit Event

/// A single audit event during a performance session
public struct AuditEvent: Codable, Sendable {

    /// Event categories
    public enum Category: String, Codable, Sendable {
        case audio      // Audio engine changes (effect added, parameter changed)
        case bio        // Bio-reactive events (HR spike, coherence change)
        case visual     // Visual engine changes (mode switch, color change)
        case session    // Session lifecycle (start, pause, resume, stop)
        case system     // System events (memory warning, CPU throttle)
        case midi       // MIDI events (note on/off, CC change)
        case light      // Lighting changes (DMX, Art-Net)
    }

    /// Event severity
    public enum Level: String, Codable, Sendable {
        case info       // Normal operation
        case notable    // Worth highlighting (coherence peak, bio milestone)
        case warning    // Soft limit exceeded
        case critical   // Hard limit exceeded, crash risk
    }

    public let id: UUID
    public let timestamp: Date
    public let category: Category
    public let level: Level
    public let action: String
    public let details: [String: String]

    public init(
        category: Category,
        level: Level = .info,
        action: String,
        details: [String: String] = [:]
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.category = category
        self.level = level
        self.action = action
        self.details = details
    }
}

// MARK: - Audit Trail

/// Append-only audit trail for performance sessions.
///
/// Records all significant events during a biofeedback/music session:
/// - Audio parameter changes
/// - Bio-reactive events (HR spikes, coherence shifts)
/// - Visual mode transitions
/// - Session lifecycle events
/// - System health warnings
///
/// Usage:
/// ```swift
/// let trail = PerformanceAuditTrail()
/// trail.log(.audio, action: "effect.added", details: ["type": "reverb", "mix": "0.3"])
/// trail.log(.bio, level: .notable, action: "coherence.peak", details: ["value": "0.95"])
///
/// // Post-session analysis
/// let bioEvents = trail.events(category: .bio)
/// let timeline = trail.timeline(from: startTime, to: endTime)
/// ```
public final class PerformanceAuditTrail: @unchecked Sendable {

    // MARK: - Properties

    /// All events in chronological order
    public private(set) var events: [AuditEvent] = []

    /// Session start time
    public let sessionStart: Date

    /// Maximum events before rotation (prevent unbounded growth)
    public var maxEvents: Int = 10_000

    /// Lock for thread-safe append
    private let lock = NSLock()

    // MARK: - Init

    public init() {
        self.sessionStart = Date()
    }

    // MARK: - Logging

    /// Log an audit event
    public func log(
        _ category: AuditEvent.Category,
        level: AuditEvent.Level = .info,
        action: String,
        details: [String: String] = [:]
    ) {
        let event = AuditEvent(
            category: category,
            level: level,
            action: action,
            details: details
        )

        lock.lock()
        events.append(event)

        // Rotate: keep most recent half when exceeding max
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents / 2))
        }
        lock.unlock()
    }

    // MARK: - Queries

    /// Filter events by category
    public func events(category: AuditEvent.Category) -> [AuditEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.category == category }
    }

    /// Filter events by level (this level and above)
    public func events(minLevel: AuditEvent.Level) -> [AuditEvent] {
        let levels: [AuditEvent.Level] = [.info, .notable, .warning, .critical]
        guard let minIndex = levels.firstIndex(of: minLevel) else { return [] }
        let includedLevels = Set(levels[minIndex...])

        lock.lock()
        defer { lock.unlock() }
        return events.filter { includedLevels.contains($0.level) }
    }

    /// Get events in a time range
    public func timeline(from start: Date, to end: Date) -> [AuditEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    /// Count events by category
    public func eventCounts() -> [AuditEvent.Category: Int] {
        lock.lock()
        defer { lock.unlock() }
        var counts: [AuditEvent.Category: Int] = [:]
        for event in events {
            counts[event.category, default: 0] += 1
        }
        return counts
    }

    /// Session duration so far
    public var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStart)
    }

    /// Total event count
    public var totalEvents: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }

    // MARK: - Export

    /// Export trail as JSON data
    public func exportJSON() throws -> Data {
        lock.lock()
        let snapshot = events
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Clear all events (for session reset)
    public func clear() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
}
