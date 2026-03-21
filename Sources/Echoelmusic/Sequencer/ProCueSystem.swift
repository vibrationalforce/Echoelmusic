#if canImport(AVFoundation)
// ProCueSystem.swift — Professional Cue System for Live Performance
// Ordered cue list with GO/PAUSE/BACK transport, bio-triggers,
// beat-sync, timeline mode, undo, and scene state management.

import Foundation
import AVFoundation
#if canImport(Observation)
import Observation
#endif
#if canImport(Combine)
import Combine
#endif

// MARK: - Top-Level Types (per CLAUDE.md — NOT nested)

/// Transition style applied when executing a cue
public enum CueTransitionType: Codable, Equatable, Sendable {
    case cut
    case crossfade(duration: TimeInterval)
    case fade(duration: TimeInterval)
    case wipe
}

/// Higher-level scene transition descriptor for inter-cue navigation
public enum CueSceneTransition: Codable, Equatable, Sendable {
    case instant
    case smooth(duration: TimeInterval)
    case beatSynced(bars: Int)
}

/// Filters which subsystems a cue affects
public enum CueSourceFilter: String, Codable, Equatable, Sendable, CaseIterable {
    case all
    case audioOnly
    case visualOnly
    case lightingOnly
}

// MARK: - Cue Trigger Condition

/// Defines when a cue should fire
public enum CueTriggerCondition: Codable, Equatable, Sendable {
    /// Manual GO trigger only
    case manual
    /// Auto-advance after the previous cue completes
    case autoFollow
    /// Fire when bio-coherence crosses a threshold (0-1)
    case bioCoherence(threshold: Float, direction: ThresholdDirection)
    /// Fire on the next bar boundary
    case beatSync(barCount: Int)
    /// Fire at an absolute timeline position (seconds from show start)
    case timeline(position: TimeInterval)

    public enum ThresholdDirection: String, Codable, Sendable {
        case rising
        case falling
    }
}

// MARK: - Scene State

/// Snapshot of the target scene when a cue is executed
public struct CueSceneState: Codable, Equatable, Sendable {
    public var audioLevel: Float
    public var visualMode: String
    public var lightingPreset: String
    public var videoClip: String?
    public var bpm: Double
    public var sourceFilter: CueSourceFilter

    public init(
        audioLevel: Float = 1.0,
        visualMode: String = "default",
        lightingPreset: String = "default",
        videoClip: String? = nil,
        bpm: Double = 120.0,
        sourceFilter: CueSourceFilter = .all
    ) {
        self.audioLevel = audioLevel.clamped(to: 0...1)
        self.visualMode = visualMode
        self.lightingPreset = lightingPreset
        self.videoClip = videoClip
        self.bpm = bpm.clamped(to: 20...300)
        self.sourceFilter = sourceFilter
    }
}

// MARK: - Pro Cue

/// A single cue in the cue list
public struct ProCue: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var notes: String
    public var trigger: CueTriggerCondition
    public var duration: TimeInterval
    public var transition: CueTransitionType
    public var sceneTransition: CueSceneTransition
    public var targetScene: CueSceneState
    public var sourceFilter: CueSourceFilter
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Cue",
        notes: String = "",
        trigger: CueTriggerCondition = .manual,
        duration: TimeInterval = 0,
        transition: CueTransitionType = .cut,
        sceneTransition: CueSceneTransition = .instant,
        targetScene: CueSceneState = CueSceneState(),
        sourceFilter: CueSourceFilter = .all,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.trigger = trigger
        self.duration = duration
        self.transition = transition
        self.sceneTransition = sceneTransition
        self.targetScene = targetScene
        self.sourceFilter = sourceFilter
        self.isEnabled = isEnabled
    }
}

// MARK: - Transport State

/// Current transport state of the cue system
public enum CueTransportState: String, Sendable {
    case idle
    case running
    case paused
}

// MARK: - Undo Snapshot

/// Stores enough state to revert the last cue execution
private struct CueUndoSnapshot: Sendable {
    let previousCueIndex: Int?
    let previousScene: CueSceneState
    let timestamp: Date
}

// MARK: - Pro Cue System

/// Professional cue system for live performance.
///
/// Manages an ordered list of cues with transport controls (GO/PAUSE/BACK),
/// bio-reactive triggers, beat-synchronized execution, timeline mode,
/// and single-level undo. Designed for theatrical and live music contexts
/// where deterministic, low-latency scene transitions are critical.
@preconcurrency @MainActor @Observable
public final class ProCueSystem {

    // MARK: - Singleton

    @MainActor public static let shared = ProCueSystem()

    // MARK: - Published State

    /// Ordered cue list
    public private(set) var cues: [ProCue] = []

    /// Index of the current (last executed) cue, nil if none executed
    public private(set) var currentCueIndex: Int?

    /// Current transport state
    public private(set) var transportState: CueTransportState = .idle

    /// Active scene state (what is currently live)
    public private(set) var activeScene: CueSceneState = CueSceneState()

    /// Whether auto-follow is globally enabled
    public var autoFollowEnabled: Bool = false

    /// Whether beat-sync triggers are armed
    public var beatSyncArmed: Bool = false

    /// Current coherence value fed from EchoelBio (0-1)
    public var currentCoherence: Float = 0.0

    /// Current beat position (bar number) fed from BPM engine
    public var currentBar: Int = 0

    /// Elapsed show time in seconds (for timeline mode)
    public var showElapsedTime: TimeInterval = 0.0

    /// Preview of the next cue (read-only snapshot, does not execute)
    public var nextCuePreview: ProCue? {
        guard let nextIndex = nextCueIndex else { return nil }
        guard nextIndex < cues.count else { return nil }
        return cues[nextIndex]
    }

    // MARK: - Integration Hooks

    /// Called after a cue is executed, with the cue and its index
    public var onCueExecuted: (@Sendable (ProCue, Int) -> Void)?

    /// Called when the active scene changes
    public var onSceneChanged: (@Sendable (CueSceneState) -> Void)?

    // MARK: - Private State

    private var undoSnapshot: CueUndoSnapshot?
    private var autoFollowTask: Task<Void, Never>?
    private var bioMonitorTask: Task<Void, Never>?
    private let log = EchoelLogger.shared

    // MARK: - Computed Properties

    /// Index of the next cue to be executed
    private var nextCueIndex: Int? {
        guard !cues.isEmpty else { return nil }
        guard let current = currentCueIndex else { return 0 }
        let next = current + 1
        return next < cues.count ? next : nil
    }

    /// Number of cues remaining after current position
    public var remainingCueCount: Int {
        guard let current = currentCueIndex else { return cues.count }
        return Swift.max(0, cues.count - current - 1)
    }

    // MARK: - Init

    private init() {
        log.log(.info, category: .system, "ProCueSystem initialized")
    }

    // MARK: - Cue List Management

    /// Append a cue to the end of the list
    public func addCue(_ cue: ProCue) {
        cues.append(cue)
        log.log(.info, category: .system, "Added cue: \(cue.name) (total: \(cues.count))")
    }

    /// Insert a cue at a specific position
    public func insertCue(_ cue: ProCue, at index: Int) {
        let safeIndex = Swift.min(Swift.max(0, index), cues.count)
        cues.insert(cue, at: safeIndex)
        // Adjust current index if insertion is before current position
        if let current = currentCueIndex, safeIndex <= current {
            currentCueIndex = current + 1
        }
        log.log(.info, category: .system, "Inserted cue: \(cue.name) at index \(safeIndex)")
    }

    /// Remove a cue by ID
    @discardableResult
    public func removeCue(id: UUID) -> ProCue? {
        guard let index = cues.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = cues.remove(at: index)
        // Adjust current index
        if let current = currentCueIndex {
            if index < current {
                currentCueIndex = current - 1
            } else if index == current {
                currentCueIndex = current > 0 ? current - 1 : nil
            }
        }
        log.log(.info, category: .system, "Removed cue: \(removed.name)")
        return removed
    }

    /// Move a cue from one position to another
    public func moveCue(from source: Int, to destination: Int) {
        guard source >= 0, source < cues.count else { return }
        guard destination >= 0, destination <= cues.count else { return }
        let cue = cues.remove(at: source)
        let adjustedDest = destination > source ? destination - 1 : destination
        let safeDest = Swift.min(adjustedDest, cues.count)
        cues.insert(cue, at: safeDest)
        log.log(.info, category: .system, "Moved cue: \(cue.name) from \(source) to \(safeDest)")
    }

    /// Replace a cue at a given index
    public func updateCue(at index: Int, with cue: ProCue) {
        guard index >= 0, index < cues.count else { return }
        cues[index] = cue
    }

    /// Remove all cues and reset state
    public func clearAllCues() {
        cues.removeAll()
        currentCueIndex = nil
        transportState = .idle
        undoSnapshot = nil
        cancelAutoFollow()
        log.log(.info, category: .system, "All cues cleared")
    }

    // MARK: - Transport Controls

    /// Execute the next cue (GO)
    public func go() {
        guard !cues.isEmpty else {
            log.log(.info, category: .system, "GO ignored — cue list empty")
            return
        }

        guard let nextIndex = nextCueIndex else {
            log.log(.info, category: .system, "GO ignored — no more cues")
            return
        }

        executeCue(at: nextIndex)
    }

    /// Pause the current cue execution and auto-follow timers
    public func pause() {
        guard transportState == .running else { return }
        transportState = .paused
        cancelAutoFollow()
        log.log(.info, category: .system, "Transport paused at cue \(currentCueIndex ?? -1)")
    }

    /// Resume from pause
    public func resume() {
        guard transportState == .paused else { return }
        transportState = .running

        // Restart auto-follow if applicable
        if let index = currentCueIndex, index < cues.count {
            let cue = cues[index]
            if autoFollowEnabled, cue.duration > 0 {
                scheduleAutoFollow(after: cue.duration)
            }
        }
        log.log(.info, category: .system, "Transport resumed")
    }

    /// Go back to the previous cue (BACK)
    public func back() {
        guard let current = currentCueIndex, current > 0 else {
            log.log(.info, category: .system, "BACK ignored — at start")
            return
        }
        cancelAutoFollow()
        let previousIndex = current - 1
        executeCue(at: previousIndex)
    }

    /// Jump to a specific cue by index
    public func jumpTo(index: Int) {
        guard index >= 0, index < cues.count else { return }
        cancelAutoFollow()
        executeCue(at: index)
    }

    /// Jump to a specific cue by ID
    public func jumpTo(id: UUID) {
        guard let index = cues.firstIndex(where: { $0.id == id }) else { return }
        jumpTo(index: index)
    }

    /// Reset transport to the beginning without clearing cues
    public func resetTransport() {
        cancelAutoFollow()
        currentCueIndex = nil
        transportState = .idle
        undoSnapshot = nil
        log.log(.info, category: .system, "Transport reset to top of cue list")
    }

    // MARK: - Undo

    /// Undo the last cue execution, restoring the previous scene state
    public func undoLastCue() {
        guard let snapshot = undoSnapshot else {
            log.log(.info, category: .system, "Undo ignored — no snapshot available")
            return
        }
        cancelAutoFollow()
        currentCueIndex = snapshot.previousCueIndex
        activeScene = snapshot.previousScene
        undoSnapshot = nil
        transportState = currentCueIndex != nil ? .running : .idle
        onSceneChanged?(activeScene)
        log.log(.info, category: .system, "Undo executed — reverted to cue index \(snapshot.previousCueIndex?.description ?? "none")")
    }

    // MARK: - Bio-Trigger Monitoring

    /// Update coherence value and check bio-triggers.
    /// Call this from the bio-feedback pipeline at the bio loop rate.
    public func updateCoherence(_ value: Float) {
        let previous = currentCoherence
        currentCoherence = value.clamped(to: 0...1)

        guard transportState != .paused else { return }
        guard let nextIndex = nextCueIndex else { return }

        let nextCue = cues[nextIndex]
        guard nextCue.isEnabled else { return }

        switch nextCue.trigger {
        case .bioCoherence(let threshold, let direction):
            let crossed: Bool
            switch direction {
            case .rising:
                crossed = previous < threshold && currentCoherence >= threshold
            case .falling:
                crossed = previous > threshold && currentCoherence <= threshold
            }
            if crossed {
                log.log(.info, category: .system, "Bio-trigger fired — coherence \(direction.rawValue) through \(threshold)")
                executeCue(at: nextIndex)
            }
        default:
            break
        }
    }

    /// Update beat position and check beat-sync triggers.
    /// Call this from the BPM engine on each bar boundary.
    public func updateBar(_ bar: Int) {
        let previousBar = currentBar
        currentBar = bar

        guard beatSyncArmed else { return }
        guard transportState != .paused else { return }
        guard let nextIndex = nextCueIndex else { return }

        let nextCue = cues[nextIndex]
        guard nextCue.isEnabled else { return }

        if case .beatSync(let barCount) = nextCue.trigger {
            guard barCount > 0 else { return }
            if bar > previousBar, bar % barCount == 0 {
                log.log(.info, category: .system, "Beat-sync trigger fired at bar \(bar)")
                executeCue(at: nextIndex)
            }
        }
    }

    /// Update show elapsed time and check timeline triggers.
    /// Call this from a high-resolution timer at the show clock rate.
    public func updateShowTime(_ elapsed: TimeInterval) {
        showElapsedTime = elapsed

        guard transportState != .paused else { return }
        guard let nextIndex = nextCueIndex else { return }

        let nextCue = cues[nextIndex]
        guard nextCue.isEnabled else { return }

        if case .timeline(let position) = nextCue.trigger {
            if elapsed >= position {
                log.log(.info, category: .system, "Timeline trigger at \(position)s (show time: \(elapsed)s)")
                executeCue(at: nextIndex)
            }
        }
    }

    // MARK: - Cue Execution (Private)

    /// Execute a cue at the given index, storing undo state
    private func executeCue(at index: Int) {
        guard index >= 0, index < cues.count else { return }
        let cue = cues[index]
        guard cue.isEnabled else {
            log.log(.info, category: .system, "Skipped disabled cue: \(cue.name)")
            return
        }

        // Store undo snapshot
        undoSnapshot = CueUndoSnapshot(
            previousCueIndex: currentCueIndex,
            previousScene: activeScene,
            timestamp: Date()
        )

        // Apply scene state
        activeScene = cue.targetScene
        currentCueIndex = index
        transportState = .running

        log.log(.info, category: .system, "Executed cue \(index): \(cue.name) [\(cue.transition)]")

        // Notify integration hooks
        onCueExecuted?(cue, index)
        onSceneChanged?(activeScene)

        // Schedule auto-follow if enabled and cue has a duration
        cancelAutoFollow()
        if autoFollowEnabled || cue.trigger == .autoFollow {
            if cue.duration > 0 {
                scheduleAutoFollow(after: cue.duration)
            }
        }
    }

    // MARK: - Auto-Follow

    private func scheduleAutoFollow(after delay: TimeInterval) {
        cancelAutoFollow()
        autoFollowTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return // Cancelled
            }
            guard let self else { return }
            guard self.transportState == .running else { return }
            self.go()
        }
    }

    private func cancelAutoFollow() {
        autoFollowTask?.cancel()
        autoFollowTask = nil
    }
}

// MARK: - Numeric Clamping

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#endif
