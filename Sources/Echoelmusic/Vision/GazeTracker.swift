// GazeTracker.swift
// Echoelmusic - Eye Gaze Tracking for Bio-Reactive Control
// λ∞ Ralph Wiggum Loop Genius Mode
// Created 2026-01-06
//
// "The doctor said I wouldn't have so many nose bleeds if I kept my finger outta there."
// - Ralph Wiggum, Ophthalmologist
//
// ═══════════════════════════════════════════════════════════════════════════════
// Eye tracking for visionOS, iPad Pro with Face ID, and ARKit-enabled devices.
// Used for gaze-based audio-visual control and attention-aware experiences.
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import SwiftUI
import Combine
import simd

#if canImport(ARKit)
import ARKit
#endif

#if canImport(RealityKit)
import RealityKit
#endif

//==============================================================================
// MARK: - Gaze Data
//==============================================================================

/// Eye gaze tracking data
public struct GazeData: Equatable, Sendable {
    /// Gaze point in normalized screen coordinates (0-1)
    public var gazePoint: SIMD2<Float>

    /// Gaze direction vector in world space
    public var gazeDirection: SIMD3<Float>

    /// Eye openness (0 = closed, 1 = fully open)
    public var leftEyeOpenness: Float
    public var rightEyeOpenness: Float

    /// Pupil dilation (relative, 0-1)
    public var leftPupilDilation: Float
    public var rightPupilDilation: Float

    /// Blink detection
    public var isBlinking: Bool
    public var blinkRate: Float  // blinks per minute

    /// Fixation detection
    public var isFixating: Bool
    public var fixationDuration: TimeInterval
    public var fixationPoint: SIMD2<Float>?

    /// Saccade (rapid eye movement) detection
    public var isSaccade: Bool
    public var saccadeVelocity: Float

    /// Tracking confidence (0-1)
    public var confidence: Float

    /// Timestamp
    public var timestamp: Date

    public init(
        gazePoint: SIMD2<Float> = SIMD2(0.5, 0.5),
        gazeDirection: SIMD3<Float> = SIMD3(0, 0, -1),
        leftEyeOpenness: Float = 1.0,
        rightEyeOpenness: Float = 1.0,
        leftPupilDilation: Float = 0.5,
        rightPupilDilation: Float = 0.5,
        isBlinking: Bool = false,
        blinkRate: Float = 15.0,
        isFixating: Bool = false,
        fixationDuration: TimeInterval = 0,
        fixationPoint: SIMD2<Float>? = nil,
        isSaccade: Bool = false,
        saccadeVelocity: Float = 0,
        confidence: Float = 0,
        timestamp: Date = Date()
    ) {
        self.gazePoint = gazePoint
        self.gazeDirection = gazeDirection
        self.leftEyeOpenness = leftEyeOpenness
        self.rightEyeOpenness = rightEyeOpenness
        self.leftPupilDilation = leftPupilDilation
        self.rightPupilDilation = rightPupilDilation
        self.isBlinking = isBlinking
        self.blinkRate = blinkRate
        self.isFixating = isFixating
        self.fixationDuration = fixationDuration
        self.fixationPoint = fixationPoint
        self.isSaccade = isSaccade
        self.saccadeVelocity = saccadeVelocity
        self.confidence = confidence
        self.timestamp = timestamp
    }

    /// Average eye openness
    public var averageOpenness: Float {
        (leftEyeOpenness + rightEyeOpenness) / 2.0
    }

    /// Average pupil dilation
    public var averagePupilDilation: Float {
        (leftPupilDilation + rightPupilDilation) / 2.0
    }

    /// Attention level derived from gaze stability and pupil dilation
    public var attentionLevel: Float {
        let stabilityFactor = isFixating ? 1.0 : 0.5
        let dilationFactor = averagePupilDilation
        return Float(stabilityFactor) * 0.6 + dilationFactor * 0.4
    }
}

//==============================================================================
// MARK: - Gaze Zone
//==============================================================================

/// Predefined gaze zones for interaction
public enum GazeZone: String, CaseIterable, Identifiable, Sendable {
    case topLeft = "top_left"
    case topCenter = "top_center"
    case topRight = "top_right"
    case centerLeft = "center_left"
    case center = "center"
    case centerRight = "center_right"
    case bottomLeft = "bottom_left"
    case bottomCenter = "bottom_center"
    case bottomRight = "bottom_right"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Get zone from normalized gaze point
    public static func from(point: SIMD2<Float>) -> GazeZone {
        let x = point.x
        let y = point.y

        let col: Int
        if x < 0.33 { col = 0 }
        else if x < 0.66 { col = 1 }
        else { col = 2 }

        let row: Int
        if y < 0.33 { row = 0 }
        else if y < 0.66 { row = 1 }
        else { row = 2 }

        let zones: [[GazeZone]] = [
            [.topLeft, .topCenter, .topRight],
            [.centerLeft, .center, .centerRight],
            [.bottomLeft, .bottomCenter, .bottomRight]
        ]

        return zones[row][col]
    }
}

//==============================================================================
// MARK: - Gaze Gesture
//==============================================================================

/// Gaze-based gestures
public enum GazeGesture: String, CaseIterable, Identifiable, Sendable {
    case dwell = "dwell"              // Look at something for duration
    case blink = "blink"              // Single blink
    case doubleBlink = "double_blink" // Two quick blinks
    case wink = "wink"                // One eye blink
    case squint = "squint"            // Partial eye close
    case widenEyes = "widen_eyes"     // Eyes wide open
    case lookAway = "look_away"       // Gaze leaves screen
    case lookBack = "look_back"       // Gaze returns to screen
    case circularGaze = "circular"    // Circular eye movement
    case horizontalSweep = "horizontal_sweep"
    case verticalSweep = "vertical_sweep"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

//==============================================================================
// MARK: - Gaze Tracker Delegate
//==============================================================================

/// Protocol for receiving gaze tracking updates
public protocol GazeTrackerDelegate: AnyObject {
    func gazeTracker(_ tracker: GazeTracker, didUpdateGaze data: GazeData)
    func gazeTracker(_ tracker: GazeTracker, didDetectGesture gesture: GazeGesture)
    func gazeTracker(_ tracker: GazeTracker, didEnterZone zone: GazeZone)
    func gazeTracker(_ tracker: GazeTracker, didExitZone zone: GazeZone)
    func gazeTrackerDidLoseTracking(_ tracker: GazeTracker)
}

// Default implementations
public extension GazeTrackerDelegate {
    func gazeTracker(_ tracker: GazeTracker, didUpdateGaze data: GazeData) {}
    func gazeTracker(_ tracker: GazeTracker, didDetectGesture gesture: GazeGesture) {}
    func gazeTracker(_ tracker: GazeTracker, didEnterZone zone: GazeZone) {}
    func gazeTracker(_ tracker: GazeTracker, didExitZone zone: GazeZone) {}
    func gazeTrackerDidLoseTracking(_ tracker: GazeTracker) {}
}

//==============================================================================
// MARK: - Gaze Tracker
//==============================================================================

/// Eye gaze tracking engine for bio-reactive control
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class GazeTracker: NSObject, ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    @Published public var isTracking: Bool = false
    @Published public var isAvailable: Bool = false
    @Published public var currentGaze: GazeData = GazeData()
    @Published public var currentZone: GazeZone = .center
    @Published public var recentGestures: [GazeGesture] = []

    // Derived metrics for audio-visual control
    @Published public var attentionLevel: Float = 0.5
    @Published public var focusIntensity: Float = 0.5
    @Published public var gazeStability: Float = 0.5
    @Published public var arousalLevel: Float = 0.5  // From pupil dilation

    // Calibration
    @Published public var isCalibrated: Bool = false
    @Published public var calibrationProgress: Float = 0.0

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    public weak var delegate: GazeTrackerDelegate?

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // Tracking history for gesture detection
    private var gazeHistory: [GazeData] = []
    private let maxHistoryLength = 60  // 1 second at 60fps

    // Fixation detection
    private var fixationStartTime: Date?
    private var lastFixationPoint: SIMD2<Float>?
    private let fixationThreshold: Float = 0.05  // 5% of screen
    private let fixationMinDuration: TimeInterval = 0.3

    // Blink detection
    private var lastBlinkTime: Date?
    private var blinkCount: Int = 0
    private var blinkWindowStart: Date?

    // Zone tracking
    private var lastZone: GazeZone = .center

    // Smoothing
    private var smoothedGazePoint: SIMD2<Float> = SIMD2(0.5, 0.5)
    private let smoothingFactor: Float = 0.3

    #if canImport(ARKit)
    private var arSession: ARSession?
    private var faceAnchor: ARFaceAnchor?
    #endif

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public override init() {
        super.init()
        checkAvailability()
    }

    private func checkAvailability() {
        #if canImport(ARKit) && !targetEnvironment(simulator)
        isAvailable = ARFaceTrackingConfiguration.isSupported
        #else
        isAvailable = false
        #endif
    }

    //==========================================================================
    // MARK: - Tracking Control
    //==========================================================================

    /// Start eye gaze tracking
    public func startTracking() {
        guard !isTracking else { return }

        #if canImport(ARKit) && !targetEnvironment(simulator)
        startARKitTracking()
        #else
        startSimulatedTracking()
        #endif

        isTracking = true
        log.spatial("👁️ GazeTracker: Started tracking")
    }

    /// Stop eye gaze tracking
    public func stopTracking() {
        isTracking = false
        updateTimer?.invalidate()
        updateTimer = nil

        #if canImport(ARKit)
        arSession?.pause()
        arSession = nil
        #endif

        log.spatial("👁️ GazeTracker: Stopped tracking")
    }

    #if canImport(ARKit) && !targetEnvironment(simulator)
    private func startARKitTracking() {
        arSession = ARSession()
        arSession?.delegate = self

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true

        arSession?.run(configuration)
    }
    #endif

    private func startSimulatedTracking() {
        // Simulate gaze data for testing/demo
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateGazeUpdate()
            }
        }
    }

    private func simulateGazeUpdate() {
        let time = Date().timeIntervalSinceReferenceDate

        // Simulate natural eye movement
        let baseX: Float = 0.5 + Float(sin(time * 0.5)) * 0.2
        let baseY: Float = 0.5 + Float(cos(time * 0.3)) * 0.15
        let noise = SIMD2<Float>(Float.random(in: -0.02...0.02), Float.random(in: -0.02...0.02))

        var gazeData = GazeData()
        gazeData.gazePoint = SIMD2(baseX, baseY) + noise
        gazeData.gazeDirection = SIMD3(gazeData.gazePoint.x - 0.5, gazeData.gazePoint.y - 0.5, -1).normalized
        gazeData.leftEyeOpenness = 0.9 + Float.random(in: -0.1...0.1)
        gazeData.rightEyeOpenness = 0.9 + Float.random(in: -0.1...0.1)
        gazeData.leftPupilDilation = 0.5 + Float(sin(time * 0.1)) * 0.2
        gazeData.rightPupilDilation = 0.5 + Float(sin(time * 0.1)) * 0.2
        gazeData.confidence = 0.9
        gazeData.timestamp = Date()

        // Simulate occasional blinks
        if Int(time * 60) % 180 == 0 {  // Every ~3 seconds
            gazeData.isBlinking = true
            gazeData.leftEyeOpenness = 0.0
            gazeData.rightEyeOpenness = 0.0
        }

        processGazeUpdate(gazeData)
    }

    //==========================================================================
    // MARK: - Gaze Processing
    //==========================================================================

    private func processGazeUpdate(_ rawData: GazeData) {
        var data = rawData

        // Smooth gaze point
        smoothedGazePoint = smoothedGazePoint * (1 - smoothingFactor) + data.gazePoint * smoothingFactor
        data.gazePoint = smoothedGazePoint

        // Update history
        gazeHistory.append(data)
        if gazeHistory.count > maxHistoryLength {
            gazeHistory.removeFirst()
        }

        // Detect fixation
        detectFixation(&data)

        // Detect blinks
        detectBlinks(&data)

        // Detect gestures
        detectGestures()

        // Update zone
        let newZone = GazeZone.from(point: data.gazePoint)
        if newZone != lastZone {
            delegate?.gazeTracker(self, didExitZone: lastZone)
            delegate?.gazeTracker(self, didEnterZone: newZone)
            lastZone = newZone
            currentZone = newZone
        }

        // Update derived metrics
        updateDerivedMetrics(data)

        // Store and notify
        currentGaze = data
        delegate?.gazeTracker(self, didUpdateGaze: data)
    }

    private func detectFixation(_ data: inout GazeData) {
        if let lastPoint = lastFixationPoint {
            let distance = simd_distance(data.gazePoint, lastPoint)

            if distance < fixationThreshold {
                // Still fixating
                if let startTime = fixationStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    if duration >= fixationMinDuration {
                        data.isFixating = true
                        data.fixationDuration = duration
                        data.fixationPoint = lastPoint
                    }
                }
            } else {
                // Started new potential fixation
                fixationStartTime = Date()
                lastFixationPoint = data.gazePoint
                data.isFixating = false
            }
        } else {
            lastFixationPoint = data.gazePoint
            fixationStartTime = Date()
        }
    }

    private func detectBlinks(_ data: inout GazeData) {
        let eyesClosed = data.averageOpenness < 0.2

        if eyesClosed && lastBlinkTime == nil {
            // Blink started
            lastBlinkTime = Date()
        } else if !eyesClosed, let blinkStartTime = lastBlinkTime {
            // Blink ended
            let blinkDuration = Date().timeIntervalSince(blinkStartTime)

            if blinkDuration < 0.5 {  // Valid blink duration
                blinkCount += 1

                // Check for double blink
                if let windowStart = blinkWindowStart {
                    if Date().timeIntervalSince(windowStart) < 0.8 && blinkCount >= 2 {
                        notifyGesture(.doubleBlink)
                        blinkCount = 0
                        blinkWindowStart = nil
                    }
                } else {
                    blinkWindowStart = Date()
                    notifyGesture(.blink)
                }
            }

            lastBlinkTime = nil
        }

        // Calculate blink rate
        if let windowStart = blinkWindowStart,
           Date().timeIntervalSince(windowStart) > 60 {
            data.blinkRate = Float(blinkCount)
            blinkCount = 0
            blinkWindowStart = Date()
        }
    }

    private func detectGestures() {
        guard gazeHistory.count >= 30 else { return }

        let recent = Array(gazeHistory.suffix(30))
        guard !recent.isEmpty else { return }

        // Single-pass computation — avoid 5× intermediate array allocations
        var sumOpenness: Float = 0
        var minX: Float = .infinity, maxX: Float = -.infinity
        var minY: Float = .infinity, maxY: Float = -.infinity
        for data in recent {
            sumOpenness += data.averageOpenness
            minX = min(minX, data.gazePoint.x)
            maxX = max(maxX, data.gazePoint.x)
            minY = min(minY, data.gazePoint.y)
            maxY = max(maxY, data.gazePoint.y)
        }
        let avgOpenness = sumOpenness / Float(recent.count)

        // Detect widen eyes (sustained high openness)
        if avgOpenness > 0.95 {
            notifyGesture(.widenEyes)
        }

        // Detect squint (sustained partial close)
        if avgOpenness > 0.3 && avgOpenness < 0.7 {
            notifyGesture(.squint)
        }

        // Detect horizontal sweep
        if maxX - minX > 0.6 {
            notifyGesture(.horizontalSweep)
        }

        // Detect vertical sweep
        if maxY - minY > 0.6 {
            notifyGesture(.verticalSweep)
        }
    }

    private func notifyGesture(_ gesture: GazeGesture) {
        // Debounce
        if !recentGestures.isEmpty && recentGestures.last == gesture {
            return
        }

        recentGestures.append(gesture)
        if recentGestures.count > 10 {
            recentGestures.removeFirst()
        }

        delegate?.gazeTracker(self, didDetectGesture: gesture)
    }

    private func updateDerivedMetrics(_ data: GazeData) {
        // Attention level from fixation and openness
        let fixationFactor: Float = data.isFixating ? 1.0 : 0.5
        let opennessFactor = data.averageOpenness
        attentionLevel = fixationFactor * 0.6 + opennessFactor * 0.4

        // Focus intensity from fixation duration
        if data.isFixating {
            focusIntensity = min(1.0, Float(data.fixationDuration / 5.0))
        } else {
            focusIntensity *= 0.95  // Decay
        }

        // Gaze stability from movement variance
        if gazeHistory.count >= 10 {
            let recent = Array(gazeHistory.suffix(10))
            let avgPoint = recent.reduce(SIMD2<Float>.zero) { $0 + $1.gazePoint } / Float(recent.count)
            let variance = recent.map { simd_distance($0.gazePoint, avgPoint) }.reduce(0, +) / Float(recent.count)
            gazeStability = max(0, 1.0 - variance * 10)
        }

        // Arousal from pupil dilation
        arousalLevel = data.averagePupilDilation
    }

    //==========================================================================
    // MARK: - Calibration
    //==========================================================================

    /// Start calibration process
    public func startCalibration() {
        isCalibrated = false
        calibrationProgress = 0.0

        // Calibration would involve looking at specific points
        // For now, simulate calibration
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                self.calibrationProgress += 0.05
                if self.calibrationProgress >= 1.0 {
                    self.calibrationProgress = 1.0
                    self.isCalibrated = true
                    timer.invalidate()
                    log.spatial("👁️ GazeTracker: Calibration complete")
                }
            }
        }
    }

    //==========================================================================
    // MARK: - Audio-Visual Mapping
    //==========================================================================

    /// Get parameters for audio-visual control
    public func getControlParameters() -> GazeControlParameters {
        GazeControlParameters(
            gazeX: currentGaze.gazePoint.x,
            gazeY: currentGaze.gazePoint.y,
            attention: attentionLevel,
            focus: focusIntensity,
            stability: gazeStability,
            arousal: arousalLevel,
            zone: currentZone,
            isFixating: currentGaze.isFixating,
            isBlinking: currentGaze.isBlinking
        )
    }
}

//==============================================================================
// MARK: - Gaze Control Parameters
//==============================================================================

/// Parameters for mapping gaze to audio-visual control
public struct GazeControlParameters: Sendable {
    public let gazeX: Float          // 0-1 horizontal position
    public let gazeY: Float          // 0-1 vertical position
    public let attention: Float      // 0-1 attention level
    public let focus: Float          // 0-1 focus intensity
    public let stability: Float      // 0-1 gaze stability
    public let arousal: Float        // 0-1 arousal/alertness
    public let zone: GazeZone        // Current gaze zone
    public let isFixating: Bool      // Currently fixating
    public let isBlinking: Bool      // Currently blinking

    /// Map to audio pan (-1 to 1)
    public var audioPan: Float {
        (gazeX - 0.5) * 2.0
    }

    /// Map to filter cutoff (0-1)
    public var filterCutoff: Float {
        attention * stability
    }

    /// Map to reverb amount (0-1)
    public var reverbAmount: Float {
        1.0 - focus
    }

    /// Map to visual intensity (0-1)
    public var visualIntensity: Float {
        (attention + arousal) / 2.0
    }
}

//==============================================================================
// MARK: - ARKit Delegate
//==============================================================================

#if canImport(ARKit)
@available(iOS 15.0, *)
extension GazeTracker: ARSessionDelegate {
    nonisolated public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    processFaceAnchor(faceAnchor)
                }
            }
        }
    }

    @MainActor
    private func processFaceAnchor(_ anchor: ARFaceAnchor) {
        var data = GazeData()

        // Get eye transforms
        let leftEye = anchor.leftEyeTransform
        let rightEye = anchor.rightEyeTransform

        // Calculate gaze direction (average of both eyes)
        let leftDir = SIMD3<Float>(leftEye.columns.2.x, leftEye.columns.2.y, leftEye.columns.2.z)
        let rightDir = SIMD3<Float>(rightEye.columns.2.x, rightEye.columns.2.y, rightEye.columns.2.z)
        data.gazeDirection = simd_normalize((leftDir + rightDir) / 2.0)

        // Project to screen coordinates (simplified)
        data.gazePoint = SIMD2(
            0.5 + data.gazeDirection.x * 0.5,
            0.5 - data.gazeDirection.y * 0.5
        )

        // Get blend shapes for eye state
        if let blendShapes = anchor.blendShapes as? [ARFaceAnchor.BlendShapeLocation: NSNumber] {
            data.leftEyeOpenness = 1.0 - (blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
            data.rightEyeOpenness = 1.0 - (blendShapes[.eyeBlinkRight]?.floatValue ?? 0)

            // Pupil dilation from eye wide blend shapes
            data.leftPupilDilation = blendShapes[.eyeWideLeft]?.floatValue ?? 0.5
            data.rightPupilDilation = blendShapes[.eyeWideRight]?.floatValue ?? 0.5
        }

        data.confidence = anchor.isTracked ? 1.0 : 0.0
        data.timestamp = Date()

        processGazeUpdate(data)
    }
}
#endif

//==============================================================================
// MARK: - SIMD Extension
//==============================================================================

extension SIMD3 where Scalar == Float {
    var normalized: SIMD3<Float> {
        let len = simd_length(self)
        return len > 0 ? self / len : self
    }
}
