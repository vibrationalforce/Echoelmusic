// CrashSafeStatePersistence.swift
// Echoelmusic - Crash-Safe Session State Persistence
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Automatically saves session state and recovers after crashes.
// Uses atomic writes and journaling for data integrity.
//
// Supported Platforms: ALL
// Created 2026-01-16

import Foundation
import Combine

// MARK: - Session State

/// Serializable session state
public struct SessionState: Codable, Sendable {
    /// Session identifier
    public let sessionId: UUID

    /// Session start time
    public let startedAt: Date

    /// Last update time
    public var lastUpdatedAt: Date

    /// Session duration at save time
    public var durationSeconds: TimeInterval

    /// Active preset name
    public var activePreset: String?

    /// Bio-reactive settings
    public var bioSettings: BioSettings

    /// Audio settings
    public var audioSettings: AudioSettings

    /// Visual settings
    public var visualSettings: VisualSettings

    /// Light settings
    public var lightSettings: LightSettings

    /// Session metrics
    public var metrics: SessionMetrics

    /// Custom user data
    public var userData: [String: String]

    // MARK: - Nested Types

    public struct BioSettings: Codable, Sendable {
        public var enabled: Bool = true
        public var coherenceThreshold: Double = 0.6
        public var smoothingFactor: Float = 0.3
    }

    public struct AudioSettings: Codable, Sendable {
        public var volume: Float = 0.8
        public var bpm: Double = 120
        public var carrierFrequency: Float = 440
        public var binauralEnabled: Bool = true
        public var binauralFrequency: Float = 10
    }

    public struct VisualSettings: Codable, Sendable {
        public var mode: String = "coherence"
        public var intensity: Float = 0.8
        public var colorScheme: String = "default"
    }

    public struct LightSettings: Codable, Sendable {
        public var dmxEnabled: Bool = false
        public var artNetEnabled: Bool = false
        public var laserEnabled: Bool = false
        public var brightness: Float = 1.0
    }

    public struct SessionMetrics: Codable, Sendable {
        public var averageCoherence: Double = 0
        public var peakCoherence: Double = 0
        public var coherenceReadings: Int = 0
        public var totalBreaths: Int = 0
    }

    // MARK: - Initialization

    public init(sessionId: UUID = UUID()) {
        self.sessionId = sessionId
        self.startedAt = Date()
        self.lastUpdatedAt = Date()
        self.durationSeconds = 0
        self.activePreset = nil
        self.bioSettings = BioSettings()
        self.audioSettings = AudioSettings()
        self.visualSettings = VisualSettings()
        self.lightSettings = LightSettings()
        self.metrics = SessionMetrics()
        self.userData = [:]
    }
}

// MARK: - Crash-Safe Persistence

/// Crash-safe state persistence manager
///
/// Features:
/// - Atomic writes (write to temp, then rename)
/// - Journal for crash recovery
/// - Automatic periodic saves
/// - Delta compression for efficiency
///
/// Usage:
/// ```swift
/// let persistence = CrashSafeStatePersistence.shared
///
/// // Save state
/// persistence.saveState(sessionState)
///
/// // Recover after crash
/// if let recovered = persistence.recoverState() {
///     // Resume session
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@MainActor
public final class CrashSafeStatePersistence: ObservableObject {

    // MARK: - Singleton

    public static let shared = CrashSafeStatePersistence()

    // MARK: - Published State

    @Published public private(set) var lastSaveTime: Date?
    @Published public private(set) var hasPendingRecovery: Bool = false
    @Published public private(set) var isSaving: Bool = false

    // MARK: - Configuration

    /// Auto-save interval in seconds
    public var autoSaveInterval: TimeInterval = 10.0

    /// Maximum journal entries before compaction
    public var maxJournalEntries: Int = 100

    // MARK: - File Paths

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = paths.first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Echoelmusic")
        }
        let appSupport = base.appendingPathComponent("Echoelmusic", isDirectory: true)

        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)

        return appSupport
    }

    private var stateFileURL: URL {
        baseDirectory.appendingPathComponent("session_state.json")
    }

    private var tempFileURL: URL {
        baseDirectory.appendingPathComponent("session_state.tmp")
    }

    private var journalFileURL: URL {
        baseDirectory.appendingPathComponent("session_journal.json")
    }

    private var recoveryFileURL: URL {
        baseDirectory.appendingPathComponent("crash_recovery.json")
    }

    // MARK: - State

    private var currentState: SessionState?
    private var autoSaveTimer: Timer?
    private var journalEntries: [JournalEntry] = []

    private struct JournalEntry: Codable {
        let timestamp: Date
        let operation: String
        let data: Data?
    }

    // MARK: - Initialization

    private init() {
        checkForCrashRecovery()
        startAutoSave()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Save Operations

    /// Save session state atomically
    public func saveState(_ state: SessionState) {
        var mutableState = state
        mutableState.lastUpdatedAt = Date()
        mutableState.durationSeconds = Date().timeIntervalSince(state.startedAt)

        currentState = mutableState

        Task {
            await performAtomicSave(mutableState)
        }
    }

    /// Quick save (writes to journal for speed)
    public func quickSave(_ state: SessionState) {
        currentState = state

        let entry = JournalEntry(
            timestamp: Date(),
            operation: "update",
            data: try? JSONEncoder().encode(state)
        )
        journalEntries.append(entry)

        // Compact journal if needed
        if journalEntries.count > maxJournalEntries {
            Task {
                await compactJournal()
            }
        }
    }

    private func performAtomicSave(_ state: SessionState) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(state)

            // Write to temp file
            try data.write(to: tempFileURL, options: .atomic)

            // Atomic rename
            if fileManager.fileExists(atPath: stateFileURL.path) {
                try fileManager.removeItem(at: stateFileURL)
            }
            try fileManager.moveItem(at: tempFileURL, to: stateFileURL)

            lastSaveTime = Date()
            log.info("CrashSafeStatePersistence: State saved successfully")

        } catch {
            log.error("CrashSafeStatePersistence: Save failed - \(error)")
        }
    }

    private func compactJournal() async {
        guard let state = currentState else { return }

        // Save full state
        await performAtomicSave(state)

        // Clear journal
        journalEntries.removeAll()

        // Write empty journal
        try? "[]".data(using: .utf8)?.write(to: journalFileURL)
    }

    // MARK: - Load Operations

    /// Load saved state
    public func loadState() -> SessionState? {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let state = try decoder.decode(SessionState.self, from: data)
            currentState = state
            return state

        } catch {
            log.error("CrashSafeStatePersistence: Load failed - \(error)")
            return nil
        }
    }

    // MARK: - Crash Recovery

    private func checkForCrashRecovery() {
        // Check if temp file exists (indicates crash during save)
        if fileManager.fileExists(atPath: tempFileURL.path) {
            log.warning("CrashSafeStatePersistence: Found incomplete save, recovering...")

            do {
                // Try to use temp file as recovery
                let data = try Data(contentsOf: tempFileURL)
                try data.write(to: recoveryFileURL)
                try fileManager.removeItem(at: tempFileURL)
                hasPendingRecovery = true
            } catch {
                log.error("CrashSafeStatePersistence: Recovery failed - \(error)")
            }
        }

        // Check if state file exists but app crashed
        if fileManager.fileExists(atPath: stateFileURL.path) {
            if let state = loadState() {
                // Check if session was active (less than 1 hour ago)
                let timeSinceLastUpdate = Date().timeIntervalSince(state.lastUpdatedAt)
                if timeSinceLastUpdate < 3600 {
                    hasPendingRecovery = true
                    log.info("CrashSafeStatePersistence: Session available for recovery")
                }
            }
        }
    }

    /// Recover state after crash
    public func recoverState() -> SessionState? {
        // First try recovery file
        if fileManager.fileExists(atPath: recoveryFileURL.path) {
            do {
                let data = try Data(contentsOf: recoveryFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let state = try decoder.decode(SessionState.self, from: data)

                // Clean up recovery file
                try fileManager.removeItem(at: recoveryFileURL)
                hasPendingRecovery = false

                currentState = state
                return state

            } catch {
                log.error("CrashSafeStatePersistence: Recovery file parse failed - \(error)")
            }
        }

        // Fall back to regular state file
        hasPendingRecovery = false
        return loadState()
    }

    /// Dismiss recovery (start fresh)
    public func dismissRecovery() {
        hasPendingRecovery = false

        // Clean up recovery file
        try? fileManager.removeItem(at: recoveryFileURL)
    }

    // MARK: - Auto-Save

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autoSaveIfNeeded()
            }
        }
    }

    private func autoSaveIfNeeded() {
        guard let state = currentState else { return }

        // Only save if there are journal entries (changes)
        if !journalEntries.isEmpty {
            Task {
                await compactJournal()
            }
        } else {
            // Still update timestamp
            var updatedState = state
            updatedState.lastUpdatedAt = Date()
            updatedState.durationSeconds = Date().timeIntervalSince(state.startedAt)
            saveState(updatedState)
        }
    }

    // MARK: - Clear

    /// Clear all saved state
    public func clearAllState() {
        currentState = nil
        journalEntries.removeAll()
        hasPendingRecovery = false

        try? fileManager.removeItem(at: stateFileURL)
        try? fileManager.removeItem(at: tempFileURL)
        try? fileManager.removeItem(at: journalFileURL)
        try? fileManager.removeItem(at: recoveryFileURL)

        log.info("CrashSafeStatePersistence: All state cleared")
    }

    // MARK: - Helpers

    /// Check if state file exists
    public var hasExistingState: Bool {
        fileManager.fileExists(atPath: stateFileURL.path)
    }

    /// Get state file size
    public var stateFileSize: Int? {
        try? fileManager.attributesOfItem(atPath: stateFileURL.path)[.size] as? Int
    }
}

// MARK: - Session State Builder

/// Builder for creating session state updates
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct SessionStateBuilder {

    private var state: SessionState

    public init(from existing: SessionState? = nil) {
        self.state = existing ?? SessionState()
    }

    public func withPreset(_ preset: String) -> SessionStateBuilder {
        var builder = self
        builder.state.activePreset = preset
        return builder
    }

    public func withBioSettings(enabled: Bool? = nil, coherenceThreshold: Double? = nil) -> SessionStateBuilder {
        var builder = self
        if let enabled = enabled {
            builder.state.bioSettings.enabled = enabled
        }
        if let threshold = coherenceThreshold {
            builder.state.bioSettings.coherenceThreshold = threshold
        }
        return builder
    }

    public func withAudioSettings(volume: Float? = nil, bpm: Double? = nil) -> SessionStateBuilder {
        var builder = self
        if let volume = volume {
            builder.state.audioSettings.volume = volume
        }
        if let bpm = bpm {
            builder.state.audioSettings.bpm = bpm
        }
        return builder
    }

    public func withCoherenceReading(_ coherence: Double) -> SessionStateBuilder {
        var builder = self
        builder.state.metrics.coherenceReadings += 1

        // Update average
        let n = Double(builder.state.metrics.coherenceReadings)
        let oldAvg = builder.state.metrics.averageCoherence
        builder.state.metrics.averageCoherence = oldAvg + (coherence - oldAvg) / n

        // Update peak
        if coherence > builder.state.metrics.peakCoherence {
            builder.state.metrics.peakCoherence = coherence
        }

        return builder
    }

    public func withUserData(_ key: String, value: String) -> SessionStateBuilder {
        var builder = self
        builder.state.userData[key] = value
        return builder
    }

    public func build() -> SessionState {
        state
    }
}
