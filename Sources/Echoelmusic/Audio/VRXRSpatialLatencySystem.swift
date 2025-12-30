//
//  VRXRSpatialLatencySystem.swift
//  Echoelmusic
//
//  Created: December 2025
//  VR/XR SPATIAL AUDIO LATENCY COMPENSATION SYSTEM
//
//  "When your head moves, the audio follows... before you even notice"
//  Target: <15ms motion-to-photon equivalent for audio
//

import Foundation
import AVFoundation
import CoreMotion
import Accelerate
import simd
import Combine

#if canImport(ARKit)
import ARKit
#endif

// MARK: - VR/XR Audio Mode

/// Operating modes for spatial audio in VR/XR
public enum VRXRAudioMode: String, CaseIterable, Identifiable {
    case passthrough = "Passthrough"        // Real world audio
    case immersive = "Immersive"            // Full virtual audio
    case mixed = "Mixed Reality"            // Blend real + virtual
    case binaural = "Binaural"              // Headphone optimized
    case ambisonics = "Ambisonics"          // Full sphere capture
    case objectBased = "Object-Based"       // Dolby Atmos style

    public var id: String { rawValue }

    var description: String {
        switch self {
        case .passthrough: return "Hear the real world with spatial enhancements"
        case .immersive: return "Full virtual soundscape, real world muted"
        case .mixed: return "Blend virtual sounds with real environment"
        case .binaural: return "HRTF-based 3D audio for headphones"
        case .ambisonics: return "Full sphere spatial audio capture/playback"
        case .objectBased: return "Individual sound objects in 3D space"
        }
    }

    var targetLatencyMs: Double {
        switch self {
        case .passthrough: return 3.0   // Critical for real-world sync
        case .immersive: return 10.0    // More tolerance
        case .mixed: return 5.0         // Balance needed
        case .binaural: return 8.0
        case .ambisonics: return 15.0
        case .objectBased: return 10.0
        }
    }
}

// MARK: - Head Tracking Source

/// Source of head tracking data
public enum HeadTrackingSource: String, CaseIterable {
    case arkit = "ARKit"                    // iPhone/iPad ARKit
    case coreMotion = "CoreMotion"          // Device sensors
    case airPodsPro = "AirPods Pro"         // AirPods spatial audio
    case visionPro = "Vision Pro"           // visionOS tracking
    case externalTracker = "External"       // Lighthouse, Quest, etc.
    case prediction = "Prediction Only"     // No tracking, just predict

    var typicalLatencyMs: Double {
        switch self {
        case .arkit: return 8.0
        case .coreMotion: return 12.0
        case .airPodsPro: return 15.0
        case .visionPro: return 5.0
        case .externalTracker: return 3.0
        case .prediction: return 0.0
        }
    }

    var updateRateHz: Double {
        switch self {
        case .arkit: return 60.0
        case .coreMotion: return 100.0
        case .airPodsPro: return 60.0
        case .visionPro: return 90.0
        case .externalTracker: return 120.0
        case .prediction: return 1000.0  // Continuous
        }
    }
}

// MARK: - HRTF Profile

/// Head-Related Transfer Function profile
public struct HRTFProfile: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let headCircumference: Float     // cm
    public let earToEarDistance: Float      // cm
    public let earHeight: Float             // cm from top of head
    public let shoulderWidth: Float         // cm

    // Personalized ITD (Interaural Time Difference)
    public var itdMaxMs: Float {
        // Speed of sound: 343 m/s = 0.343 mm/μs
        // ITD = ear distance / speed of sound
        (earToEarDistance * 10) / 0.343 / 1000 // Convert to ms
    }

    // Default "average" profile
    public static let average = HRTFProfile(
        id: UUID(),
        name: "Average",
        headCircumference: 56.0,
        earToEarDistance: 17.5,
        earHeight: 10.0,
        shoulderWidth: 45.0
    )

    // Small head profile
    public static let small = HRTFProfile(
        id: UUID(),
        name: "Small",
        headCircumference: 52.0,
        earToEarDistance: 15.0,
        earHeight: 9.0,
        shoulderWidth: 40.0
    )

    // Large head profile
    public static let large = HRTFProfile(
        id: UUID(),
        name: "Large",
        headCircumference: 60.0,
        earToEarDistance: 20.0,
        earHeight: 11.0,
        shoulderWidth: 50.0
    )
}

// MARK: - Spatial Audio Source

/// A 3D audio source in the virtual environment
public struct SpatialAudioSource: Identifiable {
    public let id: UUID
    public var name: String

    // 3D Position (meters)
    public var position: simd_float3

    // Velocity for Doppler (m/s)
    public var velocity: simd_float3 = .zero

    // Audio properties
    public var gain: Float = 1.0
    public var innerConeAngle: Float = 360    // Degrees, omnidirectional
    public var outerConeAngle: Float = 360
    public var outerConeGain: Float = 0.0

    // Distance attenuation
    public var referenceDistance: Float = 1.0
    public var maxDistance: Float = 100.0
    public var rolloffFactor: Float = 1.0

    // Occlusion/Obstruction
    public var occlusionFactor: Float = 0.0   // 0 = no occlusion
    public var obstructionFactor: Float = 0.0

    // Reverb send
    public var reverbSend: Float = 0.3

    // Audio buffer
    public var audioBuffer: AVAudioPCMBuffer?
    public var isLooping: Bool = false
    public var isPlaying: Bool = false

    /// Distance from listener
    public func distance(from listenerPos: simd_float3) -> Float {
        simd_length(position - listenerPos)
    }

    /// Direction from listener (normalized)
    public func direction(from listenerPos: simd_float3) -> simd_float3 {
        simd_normalize(position - listenerPos)
    }

    /// Gain based on distance
    public func distanceGain(from listenerPos: simd_float3) -> Float {
        let dist = max(distance(from: listenerPos), referenceDistance)
        if dist >= maxDistance { return 0 }

        // Inverse distance attenuation
        let attenuation = referenceDistance / (referenceDistance + rolloffFactor * (dist - referenceDistance))
        return attenuation * gain * (1.0 - occlusionFactor * 0.5)
    }
}

// MARK: - Motion Prediction

/// Kalman filter based motion prediction
final class MotionPredictor {

    // State: [x, y, z, vx, vy, vz, ax, ay, az]
    private var state: simd_float3 = .zero
    private var velocity: simd_float3 = .zero
    private var acceleration: simd_float3 = .zero

    // Covariance matrix (simplified as diagonal)
    private var positionVariance: simd_float3 = simd_float3(repeating: 1.0)
    private var velocityVariance: simd_float3 = simd_float3(repeating: 1.0)

    // Process noise
    private let processNoise: Float = 0.1
    // Measurement noise
    private let measurementNoise: Float = 0.01

    private var lastUpdateTime: TimeInterval = 0

    /// Update with new measurement
    func update(position: simd_float3, timestamp: TimeInterval) {
        let dt = Float(timestamp - lastUpdateTime)

        guard dt > 0 && dt < 0.5 else {
            // Reset on large gap
            state = position
            velocity = .zero
            acceleration = .zero
            lastUpdateTime = timestamp
            return
        }

        // Predict step
        let predictedPos = state + velocity * dt + 0.5 * acceleration * dt * dt
        let predictedVel = velocity + acceleration * dt

        // Update step (simplified Kalman)
        let innovation = position - predictedPos

        // Kalman gain (simplified)
        let K: Float = 0.5

        // Update state
        state = predictedPos + K * innovation
        velocity = predictedVel + K * innovation / dt

        // Update acceleration estimate
        if lastUpdateTime > 0 {
            acceleration = (velocity - predictedVel) / dt * 0.3 + acceleration * 0.7
        }

        lastUpdateTime = timestamp
    }

    /// Predict future position
    func predict(deltaTime: Float) -> simd_float3 {
        return state + velocity * deltaTime + 0.5 * acceleration * deltaTime * deltaTime
    }

    /// Predict future velocity
    func predictVelocity(deltaTime: Float) -> simd_float3 {
        return velocity + acceleration * deltaTime
    }
}

// MARK: - VR/XR Spatial Latency System

/// Complete VR/XR spatial audio system with latency compensation
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
public final class VRXRSpatialLatencySystem {

    // MARK: - Singleton
    public static let shared = VRXRSpatialLatencySystem()

    // MARK: - Observable State

    public var mode: VRXRAudioMode = .immersive
    public var trackingSource: HeadTrackingSource = .coreMotion
    public var hrtfProfile: HRTFProfile = .average

    public var isRunning = false
    public var isTrackingActive = false

    // Listener state
    public var listenerPosition: simd_float3 = .zero
    public var listenerRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    public var listenerVelocity: simd_float3 = .zero

    // Predicted state (for rendering)
    public var predictedPosition: simd_float3 = .zero
    public var predictedRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    // Latency metrics
    public var trackingLatencyMs: Double = 0
    public var renderLatencyMs: Double = 0
    public var totalMotionToSoundMs: Double = 0

    // Audio sources
    public var sources: [SpatialAudioSource] = []

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine!
    private var environmentNode: AVAudioEnvironmentNode!

    private let motionManager = CMMotionManager()
    private var positionPredictor = MotionPredictor()
    private var rotationPredictor = MotionPredictor()

    // Prediction time based on system latency
    private var predictionTimeS: Float = 0.015  // 15ms default

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()

        audioEngine.attach(environmentNode)

        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: format)

        // Configure environment
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: 0, y: 0, z: -1),
            up: AVAudio3DVector(x: 0, y: 1, z: 0)
        )

        // Configure distance attenuation
        environmentNode.distanceAttenuationParameters.referenceDistance = 1.0
        environmentNode.distanceAttenuationParameters.maximumDistance = 100.0
        environmentNode.distanceAttenuationParameters.rolloffFactor = 1.0
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .inverse

        // Configure reverb
        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.level = -20
        environmentNode.reverbParameters.loadFactoryReverbPreset(.mediumRoom)
    }

    // MARK: - Public API

    /// Start the spatial audio system
    public func start() throws {
        guard !isRunning else { return }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        // Start audio engine
        try audioEngine.start()

        // Start head tracking
        startHeadTracking()

        // Start prediction update loop
        startPredictionLoop()

        isRunning = true

        #if DEBUG
        debugLog("🥽", "VR/XR Spatial System started")
        debugLog("🥽", "   Mode: \(mode.rawValue)")
        debugLog("🥽", "   Tracking: \(trackingSource.rawValue)")
        debugLog("🥽", "   Target latency: <\(mode.targetLatencyMs)ms")
        #endif
    }

    /// Stop the system
    public func stop() {
        guard isRunning else { return }

        stopHeadTracking()
        updateTimer?.invalidate()
        updateTimer = nil

        audioEngine.stop()
        isRunning = false

        #if DEBUG
        debugLog("🥽", "VR/XR Spatial System stopped")
        #endif
    }

    /// Add a spatial audio source
    public func addSource(_ source: SpatialAudioSource) {
        sources.append(source)

        // Create and attach player node
        // (In full implementation, would manage AVAudioPlayerNode per source)
    }

    /// Remove a spatial audio source
    public func removeSource(id: UUID) {
        sources.removeAll { $0.id == id }
    }

    /// Update listener pose (from external tracking)
    public func updateListenerPose(
        position: simd_float3,
        rotation: simd_quatf,
        velocity: simd_float3 = .zero,
        timestamp: TimeInterval = CACurrentMediaTime()
    ) {
        listenerPosition = position
        listenerRotation = rotation
        listenerVelocity = velocity

        // Update predictors
        positionPredictor.update(position: position, timestamp: timestamp)

        // Convert rotation to euler for prediction
        let eulerAngles = rotation.eulerAngles
        rotationPredictor.update(position: eulerAngles, timestamp: timestamp)

        // Calculate predicted state
        updatePrediction()
    }

    /// Set prediction time based on total system latency
    public func setPredictionTime(ms: Float) {
        predictionTimeS = ms / 1000.0
    }

    // MARK: - Private Methods

    private func startHeadTracking() {
        switch trackingSource {
        case .coreMotion:
            startCoreMotionTracking()
        case .airPodsPro:
            // AirPods tracking via AVAudioSession (simplified)
            startCoreMotionTracking()
        default:
            // Other sources would be handled by external systems
            break
        }

        isTrackingActive = true
    }

    private func stopHeadTracking() {
        motionManager.stopDeviceMotionUpdates()
        isTrackingActive = false
    }

    private func startCoreMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            #if DEBUG
            debugLog("⚠️", "Device motion not available")
            #endif
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / trackingSource.updateRateHz

        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            Task { @MainActor in
                self?.processMotionUpdate(motion)
            }
        }
    }

    private func processMotionUpdate(_ motion: CMDeviceMotion) {
        let timestamp = motion.timestamp

        // Get rotation as quaternion
        let q = motion.attitude.quaternion
        let rotation = simd_quatf(
            ix: Float(q.x),
            iy: Float(q.y),
            iz: Float(q.z),
            r: Float(q.w)
        )

        // Estimate position from acceleration (very rough)
        // In real VR, position would come from external tracking
        let accel = motion.userAcceleration
        let velocity = simd_float3(
            Float(accel.x) * 0.01,
            Float(accel.y) * 0.01,
            Float(accel.z) * 0.01
        )

        updateListenerPose(
            position: listenerPosition + velocity,
            rotation: rotation,
            velocity: velocity,
            timestamp: timestamp
        )

        // Update tracking latency
        trackingLatencyMs = trackingSource.typicalLatencyMs
    }

    private func startPredictionLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePrediction()
                self?.updateEnvironmentNode()
            }
        }
    }

    private func updatePrediction() {
        // Predict future position
        predictedPosition = positionPredictor.predict(deltaTime: predictionTimeS)

        // Predict future rotation
        let predictedEuler = rotationPredictor.predict(deltaTime: predictionTimeS)
        predictedRotation = simd_quatf(eulerAngles: predictedEuler)
    }

    private func updateEnvironmentNode() {
        // Apply predicted position
        environmentNode.listenerPosition = AVAudio3DPoint(
            x: predictedPosition.x,
            y: predictedPosition.y,
            z: predictedPosition.z
        )

        // Apply predicted rotation
        let forward = predictedRotation.act(simd_float3(0, 0, -1))
        let up = predictedRotation.act(simd_float3(0, 1, 0))

        environmentNode.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: forward.x, y: forward.y, z: forward.z),
            up: AVAudio3DVector(x: up.x, y: up.y, z: up.z)
        )

        // Update total latency calculation
        totalMotionToSoundMs = trackingLatencyMs + renderLatencyMs
    }
}

// MARK: - Quaternion Extensions

extension simd_quatf {
    /// Create quaternion from euler angles (radians)
    init(eulerAngles: simd_float3) {
        let cx = cos(eulerAngles.x * 0.5)
        let sx = sin(eulerAngles.x * 0.5)
        let cy = cos(eulerAngles.y * 0.5)
        let sy = sin(eulerAngles.y * 0.5)
        let cz = cos(eulerAngles.z * 0.5)
        let sz = sin(eulerAngles.z * 0.5)

        self.init(
            ix: sx * cy * cz - cx * sy * sz,
            iy: cx * sy * cz + sx * cy * sz,
            iz: cx * cy * sz - sx * sy * cz,
            r: cx * cy * cz + sx * sy * sz
        )
    }

    /// Convert to euler angles (radians)
    var eulerAngles: simd_float3 {
        let sinr_cosp = 2 * (real * imag.x + imag.y * imag.z)
        let cosr_cosp = 1 - 2 * (imag.x * imag.x + imag.y * imag.y)
        let roll = atan2(sinr_cosp, cosr_cosp)

        let sinp = 2 * (real * imag.y - imag.z * imag.x)
        let pitch: Float
        if abs(sinp) >= 1 {
            pitch = copysign(Float.pi / 2, sinp)
        } else {
            pitch = asin(sinp)
        }

        let siny_cosp = 2 * (real * imag.z + imag.x * imag.y)
        let cosy_cosp = 1 - 2 * (imag.y * imag.y + imag.z * imag.z)
        let yaw = atan2(siny_cosp, cosy_cosp)

        return simd_float3(roll, pitch, yaw)
    }

    /// Conjugate (inverse for unit quaternion)
    var conjugate: simd_quatf {
        simd_quatf(ix: -imag.x, iy: -imag.y, iz: -imag.z, r: real)
    }

    /// Rotate a vector by this quaternion
    func act(_ v: simd_float3) -> simd_float3 {
        let qv = simd_quatf(ix: v.x, iy: v.y, iz: v.z, r: 0)
        let result = self * qv * conjugate
        return simd_float3(result.imag.x, result.imag.y, result.imag.z)
    }
}

// MARK: - SwiftUI View

import SwiftUI

public struct VRXRSpatialView: View {
    @StateObject private var system = VRXRSpatialLatencySystem.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("🥽 VR/XR SPATIAL AUDIO")
                        .font(.title2.bold())
                    Text("Motion-compensated 3D sound")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(system.isTrackingActive ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.2)))

            // Mode Picker
            Picker("Mode", selection: $system.mode) {
                ForEach(VRXRAudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Tracking Source
            Picker("Tracking", selection: $system.trackingSource) {
                ForEach(HeadTrackingSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }

            // Latency Display
            VStack(spacing: 8) {
                HStack {
                    latencyItem("Tracking", system.trackingLatencyMs)
                    latencyItem("Render", system.renderLatencyMs)
                    latencyItem("Total", system.totalMotionToSoundMs)
                }

                // Latency bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(latencyColor)
                            .frame(width: geo.size.width * min(1, CGFloat(system.totalMotionToSoundMs / system.mode.targetLatencyMs)))
                    }
                }
                .frame(height: 8)

                Text(system.totalMotionToSoundMs < system.mode.targetLatencyMs ? "✅ Within target" : "⚠️ Above target")
                    .font(.caption)
                    .foregroundColor(system.totalMotionToSoundMs < system.mode.targetLatencyMs ? .green : .orange)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))

            // Listener Position
            VStack(alignment: .leading, spacing: 8) {
                Text("LISTENER POSITION")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack {
                    positionDisplay("X", system.predictedPosition.x)
                    positionDisplay("Y", system.predictedPosition.y)
                    positionDisplay("Z", system.predictedPosition.z)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))

            // Start/Stop
            Button(action: toggleSystem) {
                HStack {
                    Image(systemName: system.isRunning ? "stop.fill" : "play.fill")
                    Text(system.isRunning ? "Stop Tracking" : "Start Tracking")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(system.isRunning ? Color.red : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private var latencyColor: Color {
        let ratio = system.totalMotionToSoundMs / system.mode.targetLatencyMs
        if ratio < 0.5 { return .green }
        if ratio < 1.0 { return .yellow }
        return .red
    }

    private func latencyItem(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", value))
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func positionDisplay(_ axis: String, _ value: Float) -> some View {
        VStack(spacing: 2) {
            Text(axis)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(String(format: "%.2f", value))
                .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleSystem() {
        if system.isRunning {
            system.stop()
        } else {
            try? system.start()
        }
    }
}

#Preview {
    VRXRSpatialView()
        .preferredColorScheme(.dark)
}

// MARK: - Backward Compatibility

extension VRXRSpatialLatencySystem: ObservableObject { }
