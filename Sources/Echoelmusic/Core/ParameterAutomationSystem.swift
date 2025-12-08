// ParameterAutomationSystem.swift
// Echoelmusic - Professional Parameter Automation System
//
// A++ Ultrahardthink Implementation
// Provides comprehensive automation including:
// - Multi-curve automation lanes
// - Bezier curve editing
// - LFO-based automation
// - Envelope followers
// - Automation recording and playback
// - Tempo-synced automation
// - Bio-reactive automation modulation

import Foundation
import Combine
import Accelerate
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.core", category: "Automation")

// MARK: - Automation Point

/// A single automation point in a lane
public struct AutomationPoint: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var time: Double      // Time in seconds (or beats if tempo-synced)
    public var value: Float      // 0.0 to 1.0 normalized
    public var curve: CurveType
    public var tension: Float    // For bezier curves (-1.0 to 1.0)

    public enum CurveType: String, Codable, CaseIterable, Sendable {
        case linear = "Linear"
        case step = "Step"
        case smooth = "Smooth"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case bezier = "Bezier"
        case sine = "Sine"
        case hold = "Hold"

        public func interpolate(from: Float, to: Float, progress: Float, tension: Float = 0.0) -> Float {
            let t = max(0.0, min(1.0, progress))

            switch self {
            case .linear:
                return from + (to - from) * t

            case .step:
                return t < 1.0 ? from : to

            case .smooth:
                // Smoothstep (Hermite)
                let smoothT = t * t * (3.0 - 2.0 * t)
                return from + (to - from) * smoothT

            case .exponential:
                let expT = (exp(t * 3.0) - 1.0) / (exp(3.0) - 1.0)
                return from + (to - from) * expT

            case .logarithmic:
                let logT = log10(1.0 + t * 9.0)
                return from + (to - from) * logT

            case .bezier:
                // Cubic bezier with tension control
                let cp1 = from + (to - from) * (0.5 + tension * 0.5)
                let cp2 = from + (to - from) * (0.5 - tension * 0.5)
                let t2 = t * t
                let t3 = t2 * t
                let mt = 1.0 - t
                let mt2 = mt * mt
                let mt3 = mt2 * mt
                return mt3 * from + 3.0 * mt2 * t * cp1 + 3.0 * mt * t2 * cp2 + t3 * to

            case .sine:
                let sineT = (1.0 - cos(t * .pi)) / 2.0
                return from + (to - from) * sineT

            case .hold:
                return from
            }
        }
    }

    public init(
        time: Double,
        value: Float,
        curve: CurveType = .smooth,
        tension: Float = 0.0
    ) {
        self.id = UUID()
        self.time = time
        self.value = max(0.0, min(1.0, value))
        self.curve = curve
        self.tension = max(-1.0, min(1.0, tension))
    }
}

// MARK: - Automation Lane

/// A lane containing automation points for a single parameter
public struct AutomationLane: Codable, Identifiable, Sendable {
    public let id: UUID
    public var parameterId: String
    public var parameterName: String
    public var points: [AutomationPoint]
    public var isEnabled: Bool
    public var isMuted: Bool
    public var color: AutomationColor
    public var defaultValue: Float
    public var loopMode: LoopMode
    public var tempoSync: Bool

    public enum LoopMode: String, Codable, CaseIterable, Sendable {
        case none = "None"
        case loop = "Loop"
        case pingPong = "Ping Pong"
        case oneShot = "One Shot"
    }

    public struct AutomationColor: Codable, Sendable {
        public var red: Float
        public var green: Float
        public var blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public static let red = AutomationColor(red: 1.0, green: 0.3, blue: 0.3)
        public static let green = AutomationColor(red: 0.3, green: 1.0, blue: 0.3)
        public static let blue = AutomationColor(red: 0.3, green: 0.5, blue: 1.0)
        public static let yellow = AutomationColor(red: 1.0, green: 0.9, blue: 0.3)
        public static let purple = AutomationColor(red: 0.8, green: 0.3, blue: 1.0)
        public static let orange = AutomationColor(red: 1.0, green: 0.6, blue: 0.2)
        public static let cyan = AutomationColor(red: 0.3, green: 0.9, blue: 0.9)
        public static let pink = AutomationColor(red: 1.0, green: 0.5, blue: 0.7)
    }

    public init(
        parameterId: String,
        parameterName: String,
        defaultValue: Float = 0.5,
        color: AutomationColor = .blue
    ) {
        self.id = UUID()
        self.parameterId = parameterId
        self.parameterName = parameterName
        self.points = []
        self.isEnabled = true
        self.isMuted = false
        self.color = color
        self.defaultValue = defaultValue
        self.loopMode = .none
        self.tempoSync = false
    }

    /// Get value at specific time
    public func getValue(at time: Double, loopDuration: Double? = nil) -> Float {
        guard !points.isEmpty else { return defaultValue }

        var adjustedTime = time

        // Handle looping
        if let duration = loopDuration, duration > 0 {
            switch loopMode {
            case .none, .oneShot:
                break
            case .loop:
                adjustedTime = time.truncatingRemainder(dividingBy: duration)
            case .pingPong:
                let cycle = Int(time / duration)
                let remainder = time.truncatingRemainder(dividingBy: duration)
                adjustedTime = cycle % 2 == 0 ? remainder : duration - remainder
            }
        }

        // Find surrounding points
        let sortedPoints = points.sorted { $0.time < $1.time }

        if adjustedTime <= sortedPoints.first!.time {
            return sortedPoints.first!.value
        }

        if adjustedTime >= sortedPoints.last!.time {
            return sortedPoints.last!.value
        }

        // Find interpolation segment
        for i in 0..<(sortedPoints.count - 1) {
            let p1 = sortedPoints[i]
            let p2 = sortedPoints[i + 1]

            if adjustedTime >= p1.time && adjustedTime <= p2.time {
                let segmentDuration = p2.time - p1.time
                let progress = Float((adjustedTime - p1.time) / segmentDuration)
                return p1.curve.interpolate(from: p1.value, to: p2.value, progress: progress, tension: p1.tension)
            }
        }

        return defaultValue
    }

    /// Add a point
    public mutating func addPoint(_ point: AutomationPoint) {
        points.append(point)
        points.sort { $0.time < $1.time }
    }

    /// Remove a point
    public mutating func removePoint(id: UUID) {
        points.removeAll { $0.id == id }
    }

    /// Update a point
    public mutating func updatePoint(_ point: AutomationPoint) {
        if let index = points.firstIndex(where: { $0.id == point.id }) {
            points[index] = point
            points.sort { $0.time < $1.time }
        }
    }

    /// Clear all points
    public mutating func clearPoints() {
        points.removeAll()
    }

    /// Get duration (time of last point)
    public var duration: Double {
        points.max(by: { $0.time < $1.time })?.time ?? 0
    }
}

// MARK: - LFO Automation Source

/// LFO-based automation generator
public struct LFOAutomation: Codable, Identifiable, Sendable {
    public let id: UUID
    public var shape: LFOShape
    public var frequency: Float      // Hz (or beats if tempo-synced)
    public var amplitude: Float      // 0.0 to 1.0
    public var offset: Float         // Center offset (0.0 to 1.0)
    public var phase: Float          // Initial phase (0.0 to 1.0)
    public var tempoSync: Bool
    public var syncDivision: SyncDivision

    public enum LFOShape: String, Codable, CaseIterable, Sendable {
        case sine = "Sine"
        case triangle = "Triangle"
        case square = "Square"
        case sawtooth = "Sawtooth"
        case sawtoothReverse = "Reverse Saw"
        case random = "Random"
        case smoothRandom = "Smooth Random"
        case exponential = "Exponential"

        public func getValue(at phase: Float) -> Float {
            let p = phase.truncatingRemainder(dividingBy: 1.0)

            switch self {
            case .sine:
                return (sin(p * 2.0 * .pi) + 1.0) / 2.0

            case .triangle:
                return p < 0.5 ? p * 2.0 : 2.0 - p * 2.0

            case .square:
                return p < 0.5 ? 1.0 : 0.0

            case .sawtooth:
                return p

            case .sawtoothReverse:
                return 1.0 - p

            case .random:
                // Use phase as seed for deterministic randomness
                let seed = UInt64(p * 1000000)
                var rng = SeededRandomGenerator(seed: seed)
                return Float.random(in: 0..<1, using: &rng)

            case .smoothRandom:
                // Interpolated random
                let seed1 = UInt64(floor(p * 10))
                let seed2 = seed1 + 1
                var rng1 = SeededRandomGenerator(seed: seed1)
                var rng2 = SeededRandomGenerator(seed: seed2)
                let v1 = Float.random(in: 0..<1, using: &rng1)
                let v2 = Float.random(in: 0..<1, using: &rng2)
                let t = (p * 10).truncatingRemainder(dividingBy: 1.0)
                return v1 + (v2 - v1) * t * t * (3.0 - 2.0 * t)

            case .exponential:
                return exp(p * 2.0 - 2.0)
            }
        }
    }

    public enum SyncDivision: String, Codable, CaseIterable, Sendable {
        case whole = "1/1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtySecond = "1/32"
        case dottedHalf = "1/2."
        case dottedQuarter = "1/4."
        case dottedEighth = "1/8."
        case tripletHalf = "1/2T"
        case tripletQuarter = "1/4T"
        case tripletEighth = "1/8T"

        public var beatsMultiplier: Float {
            switch self {
            case .whole: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtySecond: return 0.125
            case .dottedHalf: return 3.0
            case .dottedQuarter: return 1.5
            case .dottedEighth: return 0.75
            case .tripletHalf: return 4.0 / 3.0
            case .tripletQuarter: return 2.0 / 3.0
            case .tripletEighth: return 1.0 / 3.0
            }
        }
    }

    public init(
        shape: LFOShape = .sine,
        frequency: Float = 1.0,
        amplitude: Float = 1.0,
        offset: Float = 0.5,
        phase: Float = 0.0,
        tempoSync: Bool = false,
        syncDivision: SyncDivision = .quarter
    ) {
        self.id = UUID()
        self.shape = shape
        self.frequency = frequency
        self.amplitude = amplitude
        self.offset = offset
        self.phase = phase
        self.tempoSync = tempoSync
        self.syncDivision = syncDivision
    }

    public func getValue(at time: Double, tempo: Double = 120.0) -> Float {
        var effectiveFrequency = frequency

        if tempoSync {
            let beatsPerSecond = tempo / 60.0
            effectiveFrequency = Float(beatsPerSecond) / syncDivision.beatsMultiplier
        }

        let currentPhase = phase + Float(time) * effectiveFrequency
        let rawValue = shape.getValue(at: currentPhase)

        // Scale and offset
        return offset + (rawValue - 0.5) * amplitude
    }
}

// MARK: - Seeded Random Generator

private struct SeededRandomGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Envelope Follower

/// Audio envelope follower for dynamics-based automation
public struct EnvelopeFollower: Codable, Identifiable, Sendable {
    public let id: UUID
    public var attack: Float         // seconds
    public var release: Float        // seconds
    public var threshold: Float      // 0.0 to 1.0
    public var ratio: Float          // Compression ratio
    public var gain: Float           // Output gain
    public var isInverted: Bool

    public init(
        attack: Float = 0.01,
        release: Float = 0.1,
        threshold: Float = 0.0,
        ratio: Float = 1.0,
        gain: Float = 1.0,
        isInverted: Bool = false
    ) {
        self.id = UUID()
        self.attack = attack
        self.release = release
        self.threshold = threshold
        self.ratio = ratio
        self.gain = gain
        self.isInverted = isInverted
    }
}

// MARK: - Automation Recording

/// Recorded automation data
public struct AutomationRecording: Codable, Identifiable, Sendable {
    public let id: UUID
    public var parameterId: String
    public var startTime: Double
    public var samples: [RecordedSample]
    public var sampleRate: Double

    public struct RecordedSample: Codable, Sendable {
        public var time: Double
        public var value: Float
    }

    public init(parameterId: String, startTime: Double, sampleRate: Double = 60.0) {
        self.id = UUID()
        self.parameterId = parameterId
        self.startTime = startTime
        self.samples = []
        self.sampleRate = sampleRate
    }

    /// Convert to automation points with simplification
    public func toAutomationPoints(tolerance: Float = 0.01) -> [AutomationPoint] {
        guard samples.count >= 2 else {
            return samples.map { AutomationPoint(time: $0.time, value: $0.value) }
        }

        // Douglas-Peucker simplification
        var points = simplifyPath(samples, tolerance: tolerance)

        return points.map { AutomationPoint(time: $0.time, value: $0.value, curve: .smooth) }
    }

    private func simplifyPath(_ samples: [RecordedSample], tolerance: Float) -> [RecordedSample] {
        guard samples.count > 2 else { return samples }

        // Find point with maximum distance from line
        var maxDistance: Float = 0
        var maxIndex = 0

        let first = samples.first!
        let last = samples.last!

        for i in 1..<(samples.count - 1) {
            let distance = perpendicularDistance(samples[i], first, last)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance > tolerance, recursively simplify
        if maxDistance > tolerance {
            let left = simplifyPath(Array(samples[0...maxIndex]), tolerance: tolerance)
            let right = simplifyPath(Array(samples[maxIndex...]), tolerance: tolerance)

            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    private func perpendicularDistance(_ point: RecordedSample, _ lineStart: RecordedSample, _ lineEnd: RecordedSample) -> Float {
        let dx = lineEnd.time - lineStart.time
        let dy = lineEnd.value - lineStart.value

        let mag = sqrt(Float(dx * dx) + dy * dy)
        if mag == 0 { return abs(point.value - lineStart.value) }

        let u = Float((point.time - lineStart.time) * dx + Double(point.value - lineStart.value) * Double(dy)) / (mag * mag)

        let closestX = lineStart.time + Double(u) * dx
        let closestY = lineStart.value + u * dy

        return sqrt(Float(pow(point.time - closestX, 2)) + pow(point.value - closestY, 2))
    }
}

// MARK: - Automation Manager

@MainActor
public final class AutomationManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = AutomationManager()

    // MARK: - Published State

    @Published public private(set) var lanes: [AutomationLane] = []
    @Published public private(set) var lfoSources: [String: LFOAutomation] = [:]
    @Published public private(set) var envelopeFollowers: [String: EnvelopeFollower] = [:]
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var currentTime: Double = 0.0
    @Published public var tempo: Double = 120.0

    // MARK: - Configuration

    public var recordingSampleRate: Double = 60.0  // Samples per second during recording
    public var playbackSmoothing: Float = 0.0      // 0.0 to 1.0

    // MARK: - Private Properties

    private var displayLink: CADisplayLink?
    private var startTime: Date?
    private var activeRecordings: [String: AutomationRecording] = [:]
    private var smoothedValues: [String: Float] = [:]
    private var envelopeStates: [String: Float] = [:]
    private var cancellables = Set<AnyCancellable>()

    // Callbacks
    private var parameterCallbacks: [String: (Float) -> Void] = [:]

    // MARK: - Initialization

    private init() {
        loadSavedAutomation()
    }

    // MARK: - Lane Management

    public func addLane(
        parameterId: String,
        parameterName: String,
        defaultValue: Float = 0.5,
        color: AutomationLane.AutomationColor = .blue
    ) -> AutomationLane {
        let lane = AutomationLane(
            parameterId: parameterId,
            parameterName: parameterName,
            defaultValue: defaultValue,
            color: color
        )
        lanes.append(lane)
        saveAutomation()
        logger.info("Added automation lane: \(parameterName)")
        return lane
    }

    public func removeLane(id: UUID) {
        lanes.removeAll { $0.id == id }
        saveAutomation()
    }

    public func getLane(for parameterId: String) -> AutomationLane? {
        lanes.first { $0.parameterId == parameterId }
    }

    public func updateLane(_ lane: AutomationLane) {
        if let index = lanes.firstIndex(where: { $0.id == lane.id }) {
            lanes[index] = lane
            saveAutomation()
        }
    }

    // MARK: - Point Management

    public func addPoint(to laneId: UUID, point: AutomationPoint) {
        if let index = lanes.firstIndex(where: { $0.id == laneId }) {
            lanes[index].addPoint(point)
            saveAutomation()
        }
    }

    public func removePoint(from laneId: UUID, pointId: UUID) {
        if let index = lanes.firstIndex(where: { $0.id == laneId }) {
            lanes[index].removePoint(id: pointId)
            saveAutomation()
        }
    }

    public func updatePoint(in laneId: UUID, point: AutomationPoint) {
        if let index = lanes.firstIndex(where: { $0.id == laneId }) {
            lanes[index].updatePoint(point)
            saveAutomation()
        }
    }

    // MARK: - LFO Sources

    public func addLFO(for parameterId: String, lfo: LFOAutomation) {
        lfoSources[parameterId] = lfo
        saveAutomation()
        logger.info("Added LFO for: \(parameterId)")
    }

    public func removeLFO(for parameterId: String) {
        lfoSources.removeValue(forKey: parameterId)
        saveAutomation()
    }

    // MARK: - Envelope Followers

    public func addEnvelopeFollower(for parameterId: String, envelope: EnvelopeFollower) {
        envelopeFollowers[parameterId] = envelope
        envelopeStates[parameterId] = 0.0
        saveAutomation()
        logger.info("Added envelope follower for: \(parameterId)")
    }

    public func removeEnvelopeFollower(for parameterId: String) {
        envelopeFollowers.removeValue(forKey: parameterId)
        envelopeStates.removeValue(forKey: parameterId)
        saveAutomation()
    }

    /// Process audio input for envelope followers
    public func processEnvelopeInput(_ level: Float, sampleRate: Float) {
        for (parameterId, envelope) in envelopeFollowers {
            let current = envelopeStates[parameterId] ?? 0.0

            // Calculate coefficient
            let isAttacking = level > current
            let time = isAttacking ? envelope.attack : envelope.release
            let coeff = exp(-1.0 / (time * sampleRate))

            // Apply envelope
            var newValue = coeff * current + (1.0 - coeff) * level

            // Apply threshold and ratio
            if newValue > envelope.threshold {
                let excess = newValue - envelope.threshold
                newValue = envelope.threshold + excess / envelope.ratio
            }

            // Apply gain and inversion
            newValue *= envelope.gain
            if envelope.isInverted {
                newValue = 1.0 - newValue
            }

            envelopeStates[parameterId] = newValue
        }
    }

    // MARK: - Playback

    public func play() {
        guard !isPlaying else { return }

        startTime = Date()
        isPlaying = true
        startDisplayLink()
        logger.info("Automation playback started")
    }

    public func stop() {
        isPlaying = false
        stopDisplayLink()
        logger.info("Automation playback stopped")
    }

    public func pause() {
        isPlaying = false
        stopDisplayLink()
    }

    public func seek(to time: Double) {
        currentTime = max(0, time)
        if isPlaying {
            startTime = Date().addingTimeInterval(-time)
        }
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard isPlaying, let start = startTime else { return }

        currentTime = Date().timeIntervalSince(start)

        // Process all lanes
        for lane in lanes where lane.isEnabled && !lane.isMuted {
            let loopDuration = lane.loopMode != .none ? lane.duration : nil
            var value = lane.getValue(at: currentTime, loopDuration: loopDuration)

            // Add LFO modulation
            if let lfo = lfoSources[lane.parameterId] {
                let lfoValue = lfo.getValue(at: currentTime, tempo: tempo)
                value = max(0.0, min(1.0, value + (lfoValue - 0.5) * 2.0))
            }

            // Add envelope follower modulation
            if let envValue = envelopeStates[lane.parameterId] {
                value = max(0.0, min(1.0, value * envValue))
            }

            // Apply smoothing
            if playbackSmoothing > 0 {
                let prev = smoothedValues[lane.parameterId] ?? value
                value = prev + (1.0 - playbackSmoothing) * (value - prev)
                smoothedValues[lane.parameterId] = value
            }

            // Send to callback
            if let callback = parameterCallbacks[lane.parameterId] {
                callback(value)
            }
        }

        // Process LFO-only parameters
        for (parameterId, lfo) in lfoSources {
            if lanes.first(where: { $0.parameterId == parameterId }) == nil {
                let value = lfo.getValue(at: currentTime, tempo: tempo)
                if let callback = parameterCallbacks[parameterId] {
                    callback(value)
                }
            }
        }
    }

    // MARK: - Recording

    public func startRecording(for parameterId: String) {
        guard !isRecording else { return }

        activeRecordings[parameterId] = AutomationRecording(
            parameterId: parameterId,
            startTime: currentTime,
            sampleRate: recordingSampleRate
        )
        isRecording = true
        logger.info("Started recording automation for: \(parameterId)")
    }

    public func recordValue(_ value: Float, for parameterId: String) {
        guard isRecording else { return }

        if var recording = activeRecordings[parameterId] {
            let sample = AutomationRecording.RecordedSample(
                time: currentTime,
                value: value
            )
            recording.samples.append(sample)
            activeRecordings[parameterId] = recording
        }
    }

    public func stopRecording(simplifyTolerance: Float = 0.01) {
        guard isRecording else { return }

        for (parameterId, recording) in activeRecordings {
            let points = recording.toAutomationPoints(tolerance: simplifyTolerance)

            // Find or create lane
            var laneIndex = lanes.firstIndex(where: { $0.parameterId == parameterId })
            if laneIndex == nil {
                let newLane = addLane(parameterId: parameterId, parameterName: parameterId)
                laneIndex = lanes.firstIndex(where: { $0.id == newLane.id })
            }

            // Add recorded points
            if let index = laneIndex {
                for point in points {
                    lanes[index].addPoint(point)
                }
            }

            logger.info("Recorded \(points.count) automation points for: \(parameterId)")
        }

        activeRecordings.removeAll()
        isRecording = false
        saveAutomation()
    }

    // MARK: - Callbacks

    public func registerCallback(for parameterId: String, callback: @escaping (Float) -> Void) {
        parameterCallbacks[parameterId] = callback
    }

    public func unregisterCallback(for parameterId: String) {
        parameterCallbacks.removeValue(forKey: parameterId)
    }

    // MARK: - Value Retrieval

    /// Get current automation value for a parameter
    public func getValue(for parameterId: String) -> Float? {
        guard let lane = lanes.first(where: { $0.parameterId == parameterId }) else {
            // Check LFO only
            if let lfo = lfoSources[parameterId] {
                return lfo.getValue(at: currentTime, tempo: tempo)
            }
            return nil
        }

        guard lane.isEnabled && !lane.isMuted else { return lane.defaultValue }

        let loopDuration = lane.loopMode != .none ? lane.duration : nil
        var value = lane.getValue(at: currentTime, loopDuration: loopDuration)

        // Add LFO modulation
        if let lfo = lfoSources[parameterId] {
            let lfoValue = lfo.getValue(at: currentTime, tempo: tempo)
            value = max(0.0, min(1.0, value + (lfoValue - 0.5) * 2.0))
        }

        // Add envelope follower modulation
        if let envValue = envelopeStates[parameterId] {
            value = max(0.0, min(1.0, value * envValue))
        }

        return value
    }

    // MARK: - Persistence

    private func saveAutomation() {
        do {
            let data = AutomationData(
                lanes: lanes,
                lfoSources: lfoSources,
                envelopeFollowers: envelopeFollowers
            )
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(data)
            UserDefaults.standard.set(encoded, forKey: "com.echoelmusic.automation")
        } catch {
            logger.error("Failed to save automation: \(error.localizedDescription)")
        }
    }

    private func loadSavedAutomation() {
        guard let data = UserDefaults.standard.data(forKey: "com.echoelmusic.automation") else { return }

        do {
            let decoder = JSONDecoder()
            let automationData = try decoder.decode(AutomationData.self, from: data)
            lanes = automationData.lanes
            lfoSources = automationData.lfoSources
            envelopeFollowers = automationData.envelopeFollowers
            logger.info("Loaded \(self.lanes.count) automation lanes")
        } catch {
            logger.error("Failed to load automation: \(error.localizedDescription)")
        }
    }

    public func exportAutomation() throws -> Data {
        let data = AutomationData(
            lanes: lanes,
            lfoSources: lfoSources,
            envelopeFollowers: envelopeFollowers
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    public func importAutomation(from data: Data, merge: Bool = false) throws {
        let decoder = JSONDecoder()
        let automationData = try decoder.decode(AutomationData.self, from: data)

        if merge {
            lanes.append(contentsOf: automationData.lanes)
            lfoSources.merge(automationData.lfoSources) { _, new in new }
            envelopeFollowers.merge(automationData.envelopeFollowers) { _, new in new }
        } else {
            lanes = automationData.lanes
            lfoSources = automationData.lfoSources
            envelopeFollowers = automationData.envelopeFollowers
        }

        saveAutomation()
    }

    public func clearAllAutomation() {
        lanes.removeAll()
        lfoSources.removeAll()
        envelopeFollowers.removeAll()
        saveAutomation()
        logger.info("Cleared all automation")
    }
}

// MARK: - Automation Data Container

private struct AutomationData: Codable {
    let lanes: [AutomationLane]
    let lfoSources: [String: LFOAutomation]
    let envelopeFollowers: [String: EnvelopeFollower]
}

// MARK: - Automation Presets

public struct AutomationPreset: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var lanes: [AutomationLane]
    public var lfoSources: [String: LFOAutomation]

    public init(name: String, lanes: [AutomationLane] = [], lfoSources: [String: LFOAutomation] = [:]) {
        self.id = UUID()
        self.name = name
        self.lanes = lanes
        self.lfoSources = lfoSources
    }

    // Built-in presets

    public static let sidechain: AutomationPreset = {
        var lane = AutomationLane(parameterId: "volume", parameterName: "Volume")
        lane.addPoint(AutomationPoint(time: 0.0, value: 1.0, curve: .step))
        lane.addPoint(AutomationPoint(time: 0.0, value: 0.3, curve: .exponential))
        lane.addPoint(AutomationPoint(time: 0.25, value: 1.0, curve: .smooth))
        lane.loopMode = .loop
        return AutomationPreset(name: "Sidechain Pump", lanes: [lane])
    }()

    public static let filterSweep: AutomationPreset = {
        var lane = AutomationLane(parameterId: "filter.cutoff", parameterName: "Filter Cutoff")
        lane.addPoint(AutomationPoint(time: 0.0, value: 0.0, curve: .smooth))
        lane.addPoint(AutomationPoint(time: 4.0, value: 1.0, curve: .smooth))
        lane.addPoint(AutomationPoint(time: 8.0, value: 0.0, curve: .smooth))
        return AutomationPreset(name: "Filter Sweep", lanes: [lane])
    }()

    public static let tremolo: AutomationPreset = {
        let lfo = LFOAutomation(
            shape: .sine,
            frequency: 4.0,
            amplitude: 0.3,
            offset: 0.7,
            tempoSync: true,
            syncDivision: .eighth
        )
        return AutomationPreset(name: "Tremolo", lfoSources: ["volume": lfo])
    }()

    public static let autoPan: AutomationPreset = {
        let lfo = LFOAutomation(
            shape: .triangle,
            frequency: 1.0,
            amplitude: 1.0,
            offset: 0.5,
            tempoSync: true,
            syncDivision: .half
        )
        return AutomationPreset(name: "Auto Pan", lfoSources: ["pan": lfo])
    }()
}
