//
//  DAWAutomationSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  PROFESSIONAL AUTOMATION SYSTEM
//  Parameter automation, curve editing, automation modes
//
//  **Features:**
//  - Automate any parameter (volume, pan, plugin params, etc.)
//  - Multiple automation modes (Read, Write, Touch, Latch)
//  - Bezier curve editing
//  - Automation snapshots
//  - Automation lanes per track
//  - Sample-accurate automation
//

import Foundation
import SwiftUI

// MARK: - Automation System

/// Professional automation system for DAW parameters
@MainActor
class DAWAutomationSystem: ObservableObject {
    static let shared = DAWAutomationSystem()

    // MARK: - Published Properties

    @Published var automationLanes: [AutomationLane] = []
    @Published var selectedLane: UUID?
    @Published var automationMode: AutomationMode = .read

    // Settings
    @Published var globalAutomationEnabled: Bool = true
    @Published var automationResolution: Int64 = 480  // Samples between automation points (for recording)

    // MARK: - Automation Lane

    /// Automation lane for a specific parameter
    class AutomationLane: ObservableObject, Identifiable {
        let id: UUID
        let trackId: UUID
        let parameter: AutomatableParameter
        @Published var points: [AutomationPoint]
        @Published var enabled: Bool
        @Published var mode: AutomationMode

        init(
            trackId: UUID,
            parameter: AutomatableParameter,
            points: [AutomationPoint] = [],
            enabled: Bool = true,
            mode: AutomationMode = .read
        ) {
            self.id = UUID()
            self.trackId = trackId
            self.parameter = parameter
            self.points = points
            self.enabled = enabled
            self.mode = mode
        }
    }

    // MARK: - Automatable Parameter

    struct AutomatableParameter: Identifiable, Codable, Equatable {
        let id: UUID
        let name: String
        let type: ParameterType
        let minValue: Double
        let maxValue: Double
        let defaultValue: Double
        let unit: String

        init(
            name: String,
            type: ParameterType,
            minValue: Double,
            maxValue: Double,
            defaultValue: Double,
            unit: String = ""
        ) {
            self.id = UUID()
            self.name = name
            self.type = type
            self.minValue = minValue
            self.maxValue = maxValue
            self.defaultValue = defaultValue
            self.unit = unit
        }

        static func == (lhs: AutomatableParameter, rhs: AutomatableParameter) -> Bool {
            lhs.id == rhs.id
        }

        // Common parameters
        static let volume = AutomatableParameter(
            name: "Volume",
            type: .volume,
            minValue: -60.0,
            maxValue: 6.0,
            defaultValue: 0.0,
            unit: "dB"
        )

        static let pan = AutomatableParameter(
            name: "Pan",
            type: .pan,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: ""
        )

        static let mute = AutomatableParameter(
            name: "Mute",
            type: .boolean,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: ""
        )

        static let send = AutomatableParameter(
            name: "Send",
            type: .send,
            minValue: -60.0,
            maxValue: 6.0,
            defaultValue: -60.0,
            unit: "dB"
        )
    }

    enum ParameterType: String, Codable {
        case volume = "Volume"
        case pan = "Pan"
        case send = "Send"
        case plugin = "Plugin Parameter"
        case boolean = "Boolean"
        case custom = "Custom"
    }

    // MARK: - Automation Point

    struct AutomationPoint: Identifiable, Codable {
        let id: UUID
        let position: DAWTimelineEngine.TimelinePosition
        let value: Double  // Normalized to parameter range
        let curve: AutomationCurve
        let bezierControlPoint1: CGPoint?  // For bezier curves
        let bezierControlPoint2: CGPoint?

        init(
            position: DAWTimelineEngine.TimelinePosition,
            value: Double,
            curve: AutomationCurve = .linear,
            bezierControlPoint1: CGPoint? = nil,
            bezierControlPoint2: CGPoint? = nil
        ) {
            self.id = UUID()
            self.position = position
            self.value = value
            self.curve = curve
            self.bezierControlPoint1 = bezierControlPoint1
            self.bezierControlPoint2 = bezierControlPoint2
        }
    }

    enum AutomationCurve: String, Codable, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case hold = "Hold"
        case bezier = "Bezier"
        case sCurve = "S-Curve"

        var description: String {
            switch self {
            case .linear: return "Linear interpolation"
            case .exponential: return "Exponential curve (smooth)"
            case .logarithmic: return "Logarithmic curve"
            case .hold: return "Hold value (stepped)"
            case .bezier: return "Bezier curve (custom)"
            case .sCurve: return "S-curve (ease in/out)"
            }
        }
    }

    // MARK: - Automation Mode

    enum AutomationMode: String, CaseIterable {
        case off = "Off"
        case read = "Read"
        case write = "Write"
        case touch = "Touch"
        case latch = "Latch"

        var description: String {
            switch self {
            case .off:
                return "Automation disabled"
            case .read:
                return "Read automation data (playback)"
            case .write:
                return "Write automation (overwrite all)"
            case .touch:
                return "Write only while touching control"
            case .latch:
                return "Write after touching, continue until stopped"
            }
        }

        var icon: String {
            switch self {
            case .off: return "xmark.circle"
            case .read: return "play.circle"
            case .write: return "pencil.circle"
            case .touch: return "hand.tap"
            case .latch: return "lock.circle"
            }
        }
    }

    // MARK: - Lane Management

    /// Create automation lane for a parameter
    func createLane(trackId: UUID, parameter: AutomatableParameter) -> AutomationLane {
        let lane = AutomationLane(trackId: trackId, parameter: parameter)
        automationLanes.append(lane)
        print("📊 Created automation lane for \(parameter.name)")
        return lane
    }

    /// Remove automation lane
    func removeLane(id: UUID) {
        automationLanes.removeAll { $0.id == id }
        print("📊 Removed automation lane")
    }

    /// Get lanes for a specific track
    func lanes(forTrack trackId: UUID) -> [AutomationLane] {
        automationLanes.filter { $0.trackId == trackId }
    }

    /// Get lane for a specific parameter
    func lane(forTrack trackId: UUID, parameter: AutomatableParameter) -> AutomationLane? {
        automationLanes.first { $0.trackId == trackId && $0.parameter == parameter }
    }

    // MARK: - Point Management

    /// Add automation point to a lane
    func addPoint(
        toLane laneId: UUID,
        at position: DAWTimelineEngine.TimelinePosition,
        value: Double,
        curve: AutomationCurve = .linear
    ) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }) else { return }

        let point = AutomationPoint(position: position, value: value, curve: curve)
        automationLanes[laneIndex].points.append(point)
        automationLanes[laneIndex].points.sort { $0.position < $1.position }

        print("📍 Added automation point: \(value) at \(position.samples) samples")
    }

    /// Remove automation point
    func removePoint(fromLane laneId: UUID, pointId: UUID) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }) else { return }
        automationLanes[laneIndex].points.removeAll { $0.id == pointId }
    }

    /// Move automation point
    func movePoint(
        inLane laneId: UUID,
        pointId: UUID,
        to newPosition: DAWTimelineEngine.TimelinePosition,
        value: Double
    ) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }),
              let pointIndex = automationLanes[laneIndex].points.firstIndex(where: { $0.id == pointId }) else { return }

        let oldPoint = automationLanes[laneIndex].points[pointIndex]
        let newPoint = AutomationPoint(
            position: newPosition,
            value: value,
            curve: oldPoint.curve,
            bezierControlPoint1: oldPoint.bezierControlPoint1,
            bezierControlPoint2: oldPoint.bezierControlPoint2
        )

        automationLanes[laneIndex].points[pointIndex] = newPoint
        automationLanes[laneIndex].points.sort { $0.position < $1.position }
    }

    /// Update point curve
    func updatePointCurve(
        inLane laneId: UUID,
        pointId: UUID,
        curve: AutomationCurve,
        controlPoint1: CGPoint? = nil,
        controlPoint2: CGPoint? = nil
    ) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }),
              let pointIndex = automationLanes[laneIndex].points.firstIndex(where: { $0.id == pointId }) else { return }

        let oldPoint = automationLanes[laneIndex].points[pointIndex]
        let newPoint = AutomationPoint(
            position: oldPoint.position,
            value: oldPoint.value,
            curve: curve,
            bezierControlPoint1: controlPoint1,
            bezierControlPoint2: controlPoint2
        )

        automationLanes[laneIndex].points[pointIndex] = newPoint
    }

    // MARK: - Value Calculation

    /// Get automated value at a specific position
    func value(
        forLane laneId: UUID,
        at position: DAWTimelineEngine.TimelinePosition
    ) -> Double? {
        guard let lane = automationLanes.first(where: { $0.id == laneId }),
              lane.enabled,
              globalAutomationEnabled else { return nil }

        // No points - use default
        guard !lane.points.isEmpty else {
            return lane.parameter.defaultValue
        }

        let sortedPoints = lane.points.sorted { $0.position < $1.position }

        // Before first point
        guard let firstPoint = sortedPoints.first, position >= firstPoint.position else {
            return lane.parameter.defaultValue
        }

        // After last point
        guard let lastPoint = sortedPoints.last, position <= lastPoint.position else {
            return lastPoint.value
        }

        // Find surrounding points
        let previousPoints = sortedPoints.filter { $0.position <= position }
        let nextPoints = sortedPoints.filter { $0.position > position }

        guard let previousPoint = previousPoints.last else {
            return lane.parameter.defaultValue
        }

        // Exactly on a point
        if previousPoint.position == position {
            return previousPoint.value
        }

        // Between points
        guard let nextPoint = nextPoints.first else {
            return previousPoint.value
        }

        // Interpolate
        let totalDistance = Double(nextPoint.position.samples - previousPoint.position.samples)
        let currentDistance = Double(position.samples - previousPoint.position.samples)
        let progress = currentDistance / totalDistance

        return interpolate(
            from: previousPoint.value,
            to: nextPoint.value,
            progress: progress,
            curve: previousPoint.curve,
            controlPoint1: previousPoint.bezierControlPoint1,
            controlPoint2: previousPoint.bezierControlPoint2
        )
    }

    // MARK: - Interpolation

    private func interpolate(
        from startValue: Double,
        to endValue: Double,
        progress: Double,
        curve: AutomationCurve,
        controlPoint1: CGPoint?,
        controlPoint2: CGPoint?
    ) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))

        switch curve {
        case .hold:
            return startValue

        case .linear:
            return startValue + (endValue - startValue) * clampedProgress

        case .exponential:
            // Exponential curve (smooth acceleration)
            let adjustedProgress = pow(clampedProgress, 2.0)
            return startValue + (endValue - startValue) * adjustedProgress

        case .logarithmic:
            // Logarithmic curve (smooth deceleration)
            let adjustedProgress = 1.0 - pow(1.0 - clampedProgress, 2.0)
            return startValue + (endValue - startValue) * adjustedProgress

        case .sCurve:
            // S-curve (ease in/out)
            let smoothProgress = clampedProgress * clampedProgress * (3.0 - 2.0 * clampedProgress)
            return startValue + (endValue - startValue) * smoothProgress

        case .bezier:
            // Cubic bezier curve
            if let cp1 = controlPoint1, let cp2 = controlPoint2 {
                let t = clampedProgress
                let oneMinusT = 1.0 - t

                // Cubic bezier formula: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
                let y = oneMinusT * oneMinusT * oneMinusT * startValue +
                        3.0 * oneMinusT * oneMinusT * t * cp1.y +
                        3.0 * oneMinusT * t * t * cp2.y +
                        t * t * t * endValue

                return y
            } else {
                // Fallback to S-curve if no control points
                let smoothProgress = clampedProgress * clampedProgress * (3.0 - 2.0 * clampedProgress)
                return startValue + (endValue - startValue) * smoothProgress
            }
        }
    }

    // MARK: - Automation Recording

    private var recordingLanes: [UUID: [AutomationPoint]] = [:]

    /// Start recording automation for a lane
    func startRecording(lane laneId: UUID) {
        recordingLanes[laneId] = []
        print("🔴 Started recording automation for lane \(laneId)")
    }

    /// Record a value during automation recording
    func recordValue(
        forLane laneId: UUID,
        at position: DAWTimelineEngine.TimelinePosition,
        value: Double
    ) {
        guard recordingLanes[laneId] != nil else { return }

        let point = AutomationPoint(position: position, value: value)
        recordingLanes[laneId]?.append(point)
    }

    /// Stop recording and commit recorded points
    func stopRecording(lane laneId: UUID, mode: AutomationMode) {
        guard let recordedPoints = recordingLanes[laneId],
              let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }) else { return }

        switch mode {
        case .off, .read:
            break

        case .write:
            // Replace all existing points
            automationLanes[laneIndex].points = recordedPoints

        case .touch, .latch:
            // Merge with existing points
            automationLanes[laneIndex].points.append(contentsOf: recordedPoints)
            automationLanes[laneIndex].points.sort { $0.position < $1.position }
        }

        recordingLanes.removeValue(forKey: laneId)
        print("⏹️ Stopped recording automation: \(recordedPoints.count) points")
    }

    // MARK: - Automation Snapshots

    struct AutomationSnapshot: Codable {
        let timestamp: Date
        let lanes: [LaneSnapshot]

        struct LaneSnapshot: Codable {
            let trackId: UUID
            let parameter: AutomatableParameter
            let points: [AutomationPoint]
        }
    }

    /// Create snapshot of all automation
    func createSnapshot() -> AutomationSnapshot {
        let laneSnapshots = automationLanes.map { lane in
            AutomationSnapshot.LaneSnapshot(
                trackId: lane.trackId,
                parameter: lane.parameter,
                points: lane.points
            )
        }

        return AutomationSnapshot(timestamp: Date(), lanes: laneSnapshots)
    }

    /// Restore from snapshot
    func restoreSnapshot(_ snapshot: AutomationSnapshot) {
        automationLanes.removeAll()

        for laneSnapshot in snapshot.lanes {
            let lane = AutomationLane(
                trackId: laneSnapshot.trackId,
                parameter: laneSnapshot.parameter,
                points: laneSnapshot.points
            )
            automationLanes.append(lane)
        }

        print("📸 Restored automation snapshot from \(snapshot.timestamp)")
    }

    // MARK: - Utilities

    /// Clear all automation in a lane
    func clearLane(id: UUID) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == id }) else { return }
        automationLanes[laneIndex].points.removeAll()
        print("🗑️ Cleared automation lane")
    }

    /// Thin automation (reduce point count while maintaining shape)
    func thinAutomation(lane laneId: UUID, tolerance: Double = 0.01) {
        guard let laneIndex = automationLanes.firstIndex(where: { $0.id == laneId }) else { return }

        let points = automationLanes[laneIndex].points
        guard points.count > 2 else { return }

        var thinnedPoints: [AutomationPoint] = [points.first!]

        for i in 1..<(points.count - 1) {
            let prev = points[i - 1]
            let current = points[i]
            let next = points[i + 1]

            // Calculate expected value at current position
            let progress = Double(current.position.samples - prev.position.samples) / Double(next.position.samples - prev.position.samples)
            let expectedValue = prev.value + (next.value - prev.value) * progress

            // Keep point if it deviates significantly
            if abs(current.value - expectedValue) > tolerance {
                thinnedPoints.append(current)
            }
        }

        thinnedPoints.append(points.last!)

        let originalCount = points.count
        let thinnedCount = thinnedPoints.count

        automationLanes[laneIndex].points = thinnedPoints
        print("✂️ Thinned automation: \(originalCount) → \(thinnedCount) points")
    }

    // MARK: - Initialization

    private init() {}
}

// MARK: - Debug

#if DEBUG
extension DAWAutomationSystem {
    func testAutomationSystem() {
        print("🧪 Testing Automation System...")

        // Create track
        let trackId = UUID()

        // Create volume automation lane
        let volumeLane = createLane(trackId: trackId, parameter: .volume)

        // Add automation points
        addPoint(toLane: volumeLane.id, at: .zero, value: 0.0, curve: .linear)
        addPoint(toLane: volumeLane.id, at: DAWTimelineEngine.TimelinePosition(seconds: 5.0, sampleRate: 48000.0), value: -6.0, curve: .exponential)
        addPoint(toLane: volumeLane.id, at: DAWTimelineEngine.TimelinePosition(seconds: 10.0, sampleRate: 48000.0), value: 0.0, curve: .sCurve)

        // Test value calculation
        let testPositions: [TimeInterval] = [0, 2.5, 5, 7.5, 10]
        for seconds in testPositions {
            let position = DAWTimelineEngine.TimelinePosition(seconds: seconds, sampleRate: 48000.0)
            if let value = self.value(forLane: volumeLane.id, at: position) {
                print("  Volume at \(seconds)s: \(String(format: "%.2f", value)) dB")
            }
        }

        // Test snapshot
        let snapshot = createSnapshot()
        print("  Created snapshot with \(snapshot.lanes.count) lanes")

        print("✅ Automation System test complete")
    }
}
#endif
