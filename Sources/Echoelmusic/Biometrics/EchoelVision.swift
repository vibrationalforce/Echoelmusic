// EchoelVision.swift
// Eye Tracking & Gaze Integration for Echoelmusic
// Supports: ARKit (iOS), Tobii, Pupil Labs, Generic Webcam
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

import Foundation
import ARKit
import Combine

#if os(iOS)

/// Eye tracking metrics derived from gaze analysis
public struct EyeMetrics {
    // Gaze & Attention
    public var gazeX: Float = 0.5                  // Screen position X (0-1)
    public var gazeY: Float = 0.5                  // Screen position Y (0-1)
    public var fixationDuration: Float = 0         // ms (how long looking at point)
    public var saccadeVelocity: Float = 0          // °/s (rapid eye movement speed)

    // Pupillometry (Cognitive Load)
    public var pupilDiameter: Float = 0            // mm (2-8mm range)
    public var pupilDilation: Float = 0            // % change from baseline
    public var TEPR: Float = 0                     // Task-Evoked Pupillary Response

    // Blink Analysis (Stress & Fatigue)
    public var blinkRate: Float = 15               // blinks/minute (normal: 15-20)
    public var blinkDuration: Float = 150          // ms (100-400ms)
    public var partialBlinks: Int = 0              // Fatigue indicator

    // Cognitive State (derived)
    public var cognitiveLoad: Float = 0            // 0-100 (from pupil + fixation)
    public var fatigueLevel: Float = 0             // 0-100 (from blink patterns)
    public var emotionalValence: Float = 0         // -100 to +100 (from micro-expressions)

    // Metadata
    public var timestamp: UInt64 = 0               // μs since epoch
    public var confidence: Float = 100             // 0-100 (data quality)

    public init() {}
}

/// Neural state classification based on eye metrics
public enum CognitiveState {
    case deepFocus          // Long fixations, stable gaze, small pupils
    case lightFocus         // Moderate fixations
    case distracted         // Frequent saccades, wandering gaze
    case fatigued           // Increased blink rate, longer blinks
    case stressed           // Rapid saccades, dilated pupils
    case relaxed            // Slow movements, normal blink rate
    case engaged            // Moderate pupil dilation, focused gaze
    case disengaged         // Small pupils, infrequent fixations
}

/// Eye tracking device protocol
public protocol EyeTrackingDevice {
    func startTracking()
    func stopTracking()
    func getCurrentMetrics() -> EyeMetrics
    var isTracking: Bool { get }
}

/// ARKit-based eye tracking for iOS devices with TrueDepth camera
@available(iOS 14.0, *)
public class EchoelVisionARKit: NSObject, EyeTrackingDevice, ARSessionDelegate {

    // MARK: - Properties

    private var arSession: ARSession?
    private var currentMetrics = EyeMetrics()
    private var baselinePupilDiameter: Float = 4.5 // mm (average)

    private var lastGazePosition: SIMD2<Float> = [0.5, 0.5]
    private var fixationStartTime: UInt64 = 0
    private var isInFixation = false

    private var blinkHistory: [UInt64] = []        // Timestamps of recent blinks
    private var lastBlinkTime: UInt64 = 0

    public private(set) var isTracking = false

    // MARK: - Configuration

    public var fixationThreshold: Float = 0.02      // 2% screen movement
    public var fixationMinDuration: Float = 100     // ms
    public var blinkDetectionThreshold: Float = 0.3 // Eye openness threshold

    // MARK: - Initialization

    public override init() {
        super.init()
        arSession = ARSession()
        arSession?.delegate = self
    }

    // MARK: - EyeTrackingDevice Protocol

    public func startTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("[EchoelVision] Face tracking not supported on this device")
            return
        }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true

        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true

        print("[EchoelVision] ARKit eye tracking started")
    }

    public func stopTracking() {
        arSession?.pause()
        isTracking = false
        print("[EchoelVision] ARKit eye tracking stopped")
    }

    public func getCurrentMetrics() -> EyeMetrics {
        return currentMetrics
    }

    // MARK: - ARSessionDelegate

    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        updateMetrics(from: faceAnchor)
    }

    // MARK: - Metrics Processing

    private func updateMetrics(from faceAnchor: ARFaceAnchor) {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000) // μs

        // Extract look-at point (gaze direction)
        if let leftEye = faceAnchor.leftEyeTransform,
           let rightEye = faceAnchor.rightEyeTransform {

            // Calculate gaze direction (simplified - assumes looking at screen)
            let gazeDirection = calculateGazeDirection(leftEye: leftEye, rightEye: rightEye)
            let screenPosition = mapGazeToScreen(gazeDirection)

            currentMetrics.gazeX = screenPosition.x
            currentMetrics.gazeY = screenPosition.y

            // Detect fixations
            let movement = distance(screenPosition, lastGazePosition)
            if movement < fixationThreshold {
                if !isInFixation {
                    fixationStartTime = timestamp
                    isInFixation = true
                } else {
                    currentMetrics.fixationDuration = Float(timestamp - fixationStartTime) / 1000.0 // ms
                }
            } else {
                isInFixation = false
                currentMetrics.fixationDuration = 0

                // Calculate saccade velocity
                let timeDelta = Float(timestamp - currentMetrics.timestamp) / 1_000_000.0 // seconds
                if timeDelta > 0 {
                    currentMetrics.saccadeVelocity = (movement * 50) / timeDelta // Approximate °/s
                }
            }

            lastGazePosition = screenPosition
        }

        // Extract eye blink data
        if let leftEyeBlink = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue,
           let rightEyeBlink = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue {

            let avgBlink = (leftEyeBlink + rightEyeBlink) / 2.0

            // Detect blink event
            if avgBlink > blinkDetectionThreshold {
                if timestamp - lastBlinkTime > 50_000 { // Min 50ms between blinks
                    blinkHistory.append(timestamp)
                    lastBlinkTime = timestamp

                    // Keep only last minute of blink history
                    blinkHistory = blinkHistory.filter { timestamp - $0 < 60_000_000 }

                    // Calculate blink rate
                    currentMetrics.blinkRate = Float(blinkHistory.count)

                    // Estimate blink duration (simplified)
                    currentMetrics.blinkDuration = 150 // Default ms
                }
            }
        }

        // Extract pupil dilation (not directly available in ARKit, use proxy)
        // Note: ARKit doesn't provide direct pupil diameter, so we use eye openness as proxy
        if let leftEyeOpen = faceAnchor.blendShapes[.eyeWideLeft]?.floatValue,
           let rightEyeOpen = faceAnchor.blendShapes[.eyeWideRight]?.floatValue {

            let avgOpenness = (leftEyeOpen + rightEyeOpen) / 2.0

            // Estimate pupil diameter (inverse correlation with brightness)
            currentMetrics.pupilDiameter = baselinePupilDiameter * (1.0 + avgOpenness * 0.3)
            currentMetrics.pupilDilation = ((currentMetrics.pupilDiameter - baselinePupilDiameter) / baselinePupilDiameter) * 100
        }

        // Calculate derived cognitive metrics
        updateCognitiveMetrics()

        currentMetrics.timestamp = timestamp
        currentMetrics.confidence = 95 // ARKit is generally high quality
    }

    private func calculateGazeDirection(leftEye: simd_float4x4, rightEye: simd_float4x4) -> SIMD3<Float> {
        // Average the look-at direction from both eyes
        let leftLookAt = SIMD3<Float>(leftEye.columns.2.x, leftEye.columns.2.y, leftEye.columns.2.z)
        let rightLookAt = SIMD3<Float>(rightEye.columns.2.x, rightEye.columns.2.y, rightEye.columns.2.z)
        return normalize((leftLookAt + rightLookAt) / 2.0)
    }

    private func mapGazeToScreen(_ gazeDirection: SIMD3<Float>) -> SIMD2<Float> {
        // Simplified mapping: assume user is looking at screen perpendicular
        // X and Y components of gaze direction map to screen coordinates
        let x = (gazeDirection.x + 1.0) / 2.0  // Map [-1, 1] to [0, 1]
        let y = (gazeDirection.y + 1.0) / 2.0  // Map [-1, 1] to [0, 1]
        return SIMD2<Float>(clamp(x, 0, 1), clamp(y, 0, 1))
    }

    private func updateCognitiveMetrics() {
        // Cognitive load: Higher with longer fixations and larger pupils
        let fixationFactor = min(currentMetrics.fixationDuration / 1000.0, 1.0) // Normalize to 0-1
        let pupilFactor = abs(currentMetrics.pupilDilation) / 50.0 // Normalize to 0-1
        currentMetrics.cognitiveLoad = (fixationFactor * 0.4 + pupilFactor * 0.6) * 100

        // Fatigue: Higher with increased blink rate and longer blinks
        let normalBlinkRate: Float = 17.5 // Average blinks/minute
        let blinkRateDeviation = abs(currentMetrics.blinkRate - normalBlinkRate) / normalBlinkRate
        currentMetrics.fatigueLevel = min(blinkRateDeviation * 100, 100)

        // Emotional valence: Simplified (would need more complex analysis)
        currentMetrics.emotionalValence = 0 // Neutral by default
    }

    private func distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        return length(a - b)
    }

    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }

    // MARK: - Cognitive State Classification

    public func getCognitiveState() -> CognitiveState {
        // Deep focus: Long fixations, low saccade velocity
        if currentMetrics.fixationDuration > 500 && currentMetrics.saccadeVelocity < 50 {
            return .deepFocus
        }

        // Fatigued: High blink rate
        if currentMetrics.blinkRate > 25 {
            return .fatigued
        }

        // Stressed: High saccade velocity, dilated pupils
        if currentMetrics.saccadeVelocity > 200 && currentMetrics.pupilDilation > 20 {
            return .stressed
        }

        // Engaged: Moderate cognitive load, focused gaze
        if currentMetrics.cognitiveLoad > 40 && currentMetrics.fixationDuration > 200 {
            return .engaged
        }

        // Distracted: Frequent saccades, short fixations
        if currentMetrics.saccadeVelocity > 100 && currentMetrics.fixationDuration < 100 {
            return .distracted
        }

        // Relaxed: Normal metrics
        if currentMetrics.blinkRate < 20 && currentMetrics.cognitiveLoad < 30 {
            return .relaxed
        }

        return .lightFocus
    }

    // MARK: - Audio Parameter Mapping

    /// Map eye metrics to audio parameters
    public func mapToAudioParameters() -> [String: Float] {
        return [
            "stereo_pan": currentMetrics.gazeX * 2.0 - 1.0,              // -1 to 1
            "filter_cutoff": currentMetrics.gazeY * 18000 + 200,         // 200-18200 Hz
            "reverb_size": currentMetrics.pupilDilation / 100.0,         // 0-1
            "compression_ratio": 1.0 + (currentMetrics.cognitiveLoad / 50.0), // 1-3
            "lfo_speed": currentMetrics.blinkRate / 60.0,                // Hz
            "delay_time": currentMetrics.fixationDuration / 1000.0,      // seconds
        ]
    }
}

/// Manager for all EchoelVision devices
public class EchoelVisionManager {

    public static let shared = EchoelVisionManager()

    private var activeDevice: EyeTrackingDevice?
    private var metricsPublisher = PassthroughSubject<EyeMetrics, Never>()

    private init() {}

    /// Start eye tracking with the best available device
    public func startTracking() {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            if ARFaceTrackingConfiguration.isSupported {
                let arkit = EchoelVisionARKit()
                arkit.startTracking()
                activeDevice = arkit

                // Poll metrics at 60 Hz
                Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                    guard let self = self, let device = self.activeDevice else { return }
                    let metrics = device.getCurrentMetrics()
                    self.metricsPublisher.send(metrics)
                }

                print("[EchoelVision] Started with ARKit")
                return
            }
        }
        #endif

        print("[EchoelVision] No compatible eye tracking device found")
    }

    /// Stop eye tracking
    public func stopTracking() {
        activeDevice?.stopTracking()
        activeDevice = nil
        print("[EchoelVision] Tracking stopped")
    }

    /// Subscribe to eye metrics updates
    public func subscribeToMetrics() -> AnyPublisher<EyeMetrics, Never> {
        return metricsPublisher.eraseToAnyPublisher()
    }

    /// Get current metrics
    public func getCurrentMetrics() -> EyeMetrics? {
        return activeDevice?.getCurrentMetrics()
    }
}

#endif // os(iOS)
