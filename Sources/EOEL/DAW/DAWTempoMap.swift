//
//  DAWTempoMap.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  PROFESSIONAL TEMPO MAP SYSTEM
//  Multiple tempos, tempo automation, tempo curves
//
//  **Features:**
//  - Multiple tempo changes in one session
//  - Tempo automation curves (linear, exponential, logarithmic)
//  - Ritardando (slow down) and Accelerando (speed up)
//  - Sample-accurate tempo changes
//  - Tempo ramping (smooth transitions)
//  - Sync to external tempo (MIDI clock, Ableton Link)
//

import Foundation

// MARK: - Tempo Map

/// Professional tempo map with automation curves
@MainActor
class DAWTempoMap: ObservableObject {
    static let shared = DAWTempoMap()

    // MARK: - Published Properties

    @Published var globalTempo: Double = 120.0  // BPM
    @Published var tempoChanges: [TempoChange] = []
    @Published var tempoAutomation: [TempoAutomationPoint] = []

    // Settings
    @Published var tempoLocked: Bool = false  // Lock tempo (ignore changes)
    @Published var enableTempoAutomation: Bool = true

    // External sync
    @Published var syncMode: TempoSyncMode = .internal
    @Published var externalTempo: Double = 120.0

    // MARK: - Tempo Change

    /// Single tempo change at a specific position
    struct TempoChange: Identifiable, Codable {
        let id: UUID
        let position: DAWTimelineEngine.TimelinePosition
        let tempo: Double  // BPM
        let curve: TempoCurve  // How to transition to this tempo
        let rampDuration: TimeInterval  // Duration of ramp in seconds

        init(
            position: DAWTimelineEngine.TimelinePosition,
            tempo: Double,
            curve: TempoCurve = .instant,
            rampDuration: TimeInterval = 0.0
        ) {
            self.id = UUID()
            self.position = position
            self.tempo = tempo
            self.curve = curve
            self.rampDuration = rampDuration
        }
    }

    enum TempoCurve: String, Codable, CaseIterable {
        case instant = "Instant"        // Immediate change
        case linear = "Linear"          // Linear ramp
        case exponential = "Exponential" // Smooth acceleration/deceleration
        case logarithmic = "Logarithmic" // Opposite of exponential
        case sCurve = "S-Curve"         // Ease in/out (sigmoid)

        var description: String {
            switch self {
            case .instant: return "Immediate tempo change"
            case .linear: return "Linear transition"
            case .exponential: return "Exponential curve (accelerando/ritardando)"
            case .logarithmic: return "Logarithmic curve"
            case .sCurve: return "S-curve (smooth ease in/out)"
            }
        }
    }

    // MARK: - Tempo Automation

    /// Tempo automation point (for drawing automation curves)
    struct TempoAutomationPoint: Identifiable, Codable {
        let id: UUID
        let position: DAWTimelineEngine.TimelinePosition
        let tempo: Double  // BPM
        let curve: AutomationCurve  // Curve to next point

        init(
            position: DAWTimelineEngine.TimelinePosition,
            tempo: Double,
            curve: AutomationCurve = .linear
        ) {
            self.id = UUID()
            self.position = position
            self.tempo = tempo
            self.curve = curve
        }
    }

    enum AutomationCurve: String, Codable, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case hold = "Hold"          // Hold value until next point
        case bezier = "Bezier"      // Smooth bezier curve

        var description: String {
            switch self {
            case .linear: return "Linear interpolation"
            case .exponential: return "Exponential curve"
            case .logarithmic: return "Logarithmic curve"
            case .hold: return "Hold value (stepped)"
            case .bezier: return "Smooth bezier curve"
            }
        }
    }

    // MARK: - Sync Mode

    enum TempoSyncMode: String, CaseIterable {
        case internal = "Internal"          // Use internal tempo map
        case midiClock = "MIDI Clock"       // Sync to external MIDI clock
        case abletonLink = "Ableton Link"   // Sync to Ableton Link
        case mtc = "MTC"                    // MIDI Time Code
        case manual = "Manual Tap"          // Tap tempo

        var description: String {
            switch self {
            case .internal: return "Use internal tempo map"
            case .midiClock: return "Sync to external MIDI clock"
            case .abletonLink: return "Sync to Ableton Link network"
            case .mtc: return "Sync to MIDI Time Code"
            case .manual: return "Manual tap tempo"
            }
        }
    }

    // MARK: - Tempo Calculation

    /// Get tempo at a specific timeline position
    func tempo(at position: DAWTimelineEngine.TimelinePosition, sampleRate: Double) -> Double {
        guard !tempoLocked else { return globalTempo }

        // External sync
        if syncMode != .internal {
            return externalTempo
        }

        // Check tempo automation first (higher priority)
        if enableTempoAutomation, !tempoAutomation.isEmpty {
            return automatedTempo(at: position, sampleRate: sampleRate)
        }

        // Check tempo changes
        if !tempoChanges.isEmpty {
            return tempoFromChanges(at: position, sampleRate: sampleRate)
        }

        // Default to global tempo
        return globalTempo
    }

    /// Get tempo from tempo changes (with curves)
    private func tempoFromChanges(at position: DAWTimelineEngine.TimelinePosition, sampleRate: Double) -> Double {
        // Find the most recent tempo change before or at this position
        let previousChanges = tempoChanges
            .filter { $0.position <= position }
            .sorted { $0.position > $1.position }

        guard let currentChange = previousChanges.first else {
            return globalTempo
        }

        // Check if we're in a ramp
        if currentChange.rampDuration > 0 {
            let rampEndPosition = DAWTimelineEngine.TimelinePosition(
                samples: currentChange.position.samples + Int64(currentChange.rampDuration * sampleRate)
            )

            if position <= rampEndPosition {
                // We're in the ramp - interpolate tempo
                let previousTempo = previousChanges.dropFirst().first?.tempo ?? globalTempo
                let progress = Double(position.samples - currentChange.position.samples) / Double(rampEndPosition.samples - currentChange.position.samples)

                return interpolate(
                    from: previousTempo,
                    to: currentChange.tempo,
                    progress: progress,
                    curve: currentChange.curve
                )
            }
        }

        return currentChange.tempo
    }

    /// Get tempo from automation points
    private func automatedTempo(at position: DAWTimelineEngine.TimelinePosition, sampleRate: Double) -> Double {
        let sortedPoints = tempoAutomation.sorted { $0.position < $1.position }

        // Find surrounding automation points
        let previousPoints = sortedPoints.filter { $0.position <= position }
        let nextPoints = sortedPoints.filter { $0.position > position }

        guard let previousPoint = previousPoints.last else {
            // Before first point - use global tempo
            return globalTempo
        }

        guard let nextPoint = nextPoints.first else {
            // After last point - use last point's tempo
            return previousPoint.tempo
        }

        // Interpolate between points
        let totalDistance = Double(nextPoint.position.samples - previousPoint.position.samples)
        let currentDistance = Double(position.samples - previousPoint.position.samples)
        let progress = currentDistance / totalDistance

        return interpolateAutomation(
            from: previousPoint.tempo,
            to: nextPoint.tempo,
            progress: progress,
            curve: previousPoint.curve
        )
    }

    // MARK: - Interpolation

    /// Interpolate tempo with curve
    private func interpolate(from startTempo: Double, to endTempo: Double, progress: Double, curve: TempoCurve) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))

        switch curve {
        case .instant:
            return endTempo

        case .linear:
            return startTempo + (endTempo - startTempo) * clampedProgress

        case .exponential:
            // Exponential curve: y = start * (end/start)^x
            let ratio = endTempo / startTempo
            return startTempo * pow(ratio, clampedProgress)

        case .logarithmic:
            // Logarithmic curve (inverse of exponential)
            let adjustedProgress = 1.0 - pow(1.0 - clampedProgress, 2.0)
            return startTempo + (endTempo - startTempo) * adjustedProgress

        case .sCurve:
            // S-curve (sigmoid): smooth ease in and ease out
            let smoothProgress = clampedProgress * clampedProgress * (3.0 - 2.0 * clampedProgress)
            return startTempo + (endTempo - startTempo) * smoothProgress
        }
    }

    /// Interpolate automation with curve
    private func interpolateAutomation(from startTempo: Double, to endTempo: Double, progress: Double, curve: AutomationCurve) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))

        switch curve {
        case .hold:
            return startTempo

        case .linear:
            return startTempo + (endTempo - startTempo) * clampedProgress

        case .exponential:
            let ratio = endTempo / startTempo
            return startTempo * pow(ratio, clampedProgress)

        case .logarithmic:
            let adjustedProgress = 1.0 - pow(1.0 - clampedProgress, 2.0)
            return startTempo + (endTempo - startTempo) * adjustedProgress

        case .bezier:
            // Cubic bezier (simplified - would need control points for full bezier)
            let smoothProgress = clampedProgress * clampedProgress * (3.0 - 2.0 * clampedProgress)
            return startTempo + (endTempo - startTempo) * smoothProgress
        }
    }

    // MARK: - Tempo Change Management

    /// Add a tempo change
    func addTempoChange(
        at position: DAWTimelineEngine.TimelinePosition,
        tempo: Double,
        curve: TempoCurve = .instant,
        rampDuration: TimeInterval = 0.0
    ) {
        let change = TempoChange(
            position: position,
            tempo: tempo,
            curve: curve,
            rampDuration: rampDuration
        )
        tempoChanges.append(change)
        tempoChanges.sort { $0.position < $1.position }
        print("🎼 Added tempo change: \(tempo) BPM at \(position.samples) samples")
    }

    /// Remove tempo change
    func removeTempoChange(id: UUID) {
        tempoChanges.removeAll { $0.id == id }
        print("🎼 Removed tempo change")
    }

    /// Clear all tempo changes
    func clearTempoChanges() {
        tempoChanges.removeAll()
        print("🎼 Cleared all tempo changes")
    }

    // MARK: - Tempo Automation Management

    /// Add automation point
    func addAutomationPoint(
        at position: DAWTimelineEngine.TimelinePosition,
        tempo: Double,
        curve: AutomationCurve = .linear
    ) {
        let point = TempoAutomationPoint(
            position: position,
            tempo: tempo,
            curve: curve
        )
        tempoAutomation.append(point)
        tempoAutomation.sort { $0.position < $1.position }
        print("📈 Added tempo automation point: \(tempo) BPM at \(position.samples) samples")
    }

    /// Remove automation point
    func removeAutomationPoint(id: UUID) {
        tempoAutomation.removeAll { $0.id == id }
        print("📈 Removed tempo automation point")
    }

    /// Clear all automation
    func clearAutomation() {
        tempoAutomation.removeAll()
        print("📈 Cleared tempo automation")
    }

    // MARK: - Musical Effects

    /// Add ritardando (gradual slow down)
    func addRitardando(
        from startPosition: DAWTimelineEngine.TimelinePosition,
        to endPosition: DAWTimelineEngine.TimelinePosition,
        startTempo: Double,
        endTempo: Double
    ) {
        addTempoChange(
            at: startPosition,
            tempo: endTempo,
            curve: .exponential,
            rampDuration: (endPosition - startPosition).toSeconds(sampleRate: 48000.0)
        )
        print("🎵 Added ritardando: \(startTempo) → \(endTempo) BPM")
    }

    /// Add accelerando (gradual speed up)
    func addAccelerando(
        from startPosition: DAWTimelineEngine.TimelinePosition,
        to endPosition: DAWTimelineEngine.TimelinePosition,
        startTempo: Double,
        endTempo: Double
    ) {
        addTempoChange(
            at: startPosition,
            tempo: endTempo,
            curve: .exponential,
            rampDuration: (endPosition - startPosition).toSeconds(sampleRate: 48000.0)
        )
        print("🎵 Added accelerando: \(startTempo) → \(endTempo) BPM")
    }

    // MARK: - Tap Tempo

    private var tapTimes: [Date] = []
    private let maxTapInterval: TimeInterval = 2.0  // Max 2 seconds between taps

    /// Tap tempo - call this on each tap
    func tap() {
        let now = Date()

        // Remove old taps
        tapTimes.removeAll { now.timeIntervalSince($0) > maxTapInterval }

        // Add new tap
        tapTimes.append(now)

        // Calculate tempo from taps
        if tapTimes.count >= 2 {
            let intervals = zip(tapTimes.dropLast(), tapTimes.dropFirst()).map { $1.timeIntervalSince($0) }
            let averageInterval = intervals.reduce(0.0, +) / Double(intervals.count)
            let calculatedTempo = 60.0 / averageInterval

            // Update tempo
            if syncMode == .manual {
                externalTempo = calculatedTempo
            } else {
                globalTempo = calculatedTempo
            }

            print("👆 Tap tempo: \(String(format: "%.1f", calculatedTempo)) BPM (\(tapTimes.count) taps)")
        }
    }

    /// Reset tap tempo
    func resetTap() {
        tapTimes.removeAll()
        print("👆 Tap tempo reset")
    }

    // MARK: - Presets

    struct TempoPreset: Codable {
        let name: String
        let tempo: Double
        let description: String

        static let presets: [TempoPreset] = [
            TempoPreset(name: "Largo", tempo: 50.0, description: "Very slow (40-60 BPM)"),
            TempoPreset(name: "Adagio", tempo: 70.0, description: "Slow (66-76 BPM)"),
            TempoPreset(name: "Andante", tempo: 90.0, description: "Walking pace (76-108 BPM)"),
            TempoPreset(name: "Moderato", tempo: 110.0, description: "Moderate (108-120 BPM)"),
            TempoPreset(name: "Allegro", tempo: 140.0, description: "Fast (120-156 BPM)"),
            TempoPreset(name: "Presto", tempo: 180.0, description: "Very fast (168-200 BPM)"),
            TempoPreset(name: "Prestissimo", tempo: 220.0, description: "Extremely fast (>200 BPM)"),
        ]
    }

    func applyPreset(_ preset: TempoPreset) {
        globalTempo = preset.tempo
        print("🎼 Applied tempo preset: \(preset.name) (\(preset.tempo) BPM)")
    }

    // MARK: - Initialization

    private init() {}
}

// MARK: - Debug

#if DEBUG
extension DAWTempoMap {
    func testTempoMap() {
        print("🧪 Testing Tempo Map...")

        // Test tempo changes
        addTempoChange(at: .zero, tempo: 120.0)
        addTempoChange(at: DAWTimelineEngine.TimelinePosition(seconds: 10.0, sampleRate: 48000.0), tempo: 140.0, curve: .linear, rampDuration: 2.0)
        addTempoChange(at: DAWTimelineEngine.TimelinePosition(seconds: 20.0, sampleRate: 48000.0), tempo: 100.0, curve: .exponential, rampDuration: 4.0)

        // Test tempo calculation
        let testPositions: [TimeInterval] = [0, 5, 10, 11, 15, 20, 22, 25]
        for seconds in testPositions {
            let position = DAWTimelineEngine.TimelinePosition(seconds: seconds, sampleRate: 48000.0)
            let tempo = self.tempo(at: position, sampleRate: 48000.0)
            print("  Tempo at \(seconds)s: \(String(format: "%.2f", tempo)) BPM")
        }

        // Test automation
        enableTempoAutomation = true
        addAutomationPoint(at: .zero, tempo: 120.0)
        addAutomationPoint(at: DAWTimelineEngine.TimelinePosition(seconds: 10.0, sampleRate: 48000.0), tempo: 150.0, curve: .bezier)
        addAutomationPoint(at: DAWTimelineEngine.TimelinePosition(seconds: 20.0, sampleRate: 48000.0), tempo: 100.0, curve: .exponential)

        // Test tap tempo
        resetTap()
        for _ in 0..<4 {
            tap()
            Thread.sleep(forTimeInterval: 0.5)  // 120 BPM
        }

        print("✅ Tempo Map test complete")
    }
}
#endif
