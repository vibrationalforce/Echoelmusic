import Foundation
import AVFoundation
import Combine
import simd

#if os(visionOS)
import RealityKit
import Spatial
#endif

/// Apple Immersive Video (AIV) Metadata Engine
/// Handles ILPD, motion comfort, FOV, and stereoscopic rendering metadata
/// for creating and playing back immersive audio-visual experiences
@MainActor
@Observable
class AIVMetadataEngine {

    // MARK: - Published State

    /// Current ILPD (Inter-Lens Pupillary Distance) in millimeters
    var currentILPD: Float = 63.0  // Average human IPD

    /// Motion comfort level (0.0 = high motion, 1.0 = static/comfortable)
    var motionComfortLevel: Float = 1.0

    /// Current field of view in degrees
    var fieldOfView: Float = 100.0

    /// Stereoscopic depth intensity (0.0 = 2D, 1.0 = full 3D)
    var stereoscopicDepth: Float = 1.0

    /// Is immersive mode active
    var isImmersiveActive: Bool = false

    /// Current comfort warnings
    var comfortWarnings: [ComfortWarning] = []

    // MARK: - AIV Metadata Structure

    struct AIVMetadata: Codable {
        // ILPD Data
        var ilpd: ILPDData

        // Motion Comfort
        var motionComfort: MotionComfortData

        // Field of View
        var fov: FOVData

        // Stereoscopic Parameters
        var stereo: StereoscopicData

        // Temporal Metadata (per-frame)
        var temporalMetadata: [TemporalFrame]

        // Bio-Reactive Parameters
        var bioReactive: BioReactiveMetadata

        // Audio Spatial Anchors
        var spatialAnchors: [SpatialAudioAnchor]
    }

    struct ILPDData: Codable {
        var baseIPD: Float = 63.0           // Base inter-pupillary distance (mm)
        var minIPD: Float = 54.0            // Minimum supported IPD
        var maxIPD: Float = 74.0            // Maximum supported IPD
        var convergenceDistance: Float = 2.0 // Meters to convergence point
        var parallaxScale: Float = 1.0       // Parallax intensity multiplier
        var depthRange: ClosedRange<Float> = 0.5...100.0  // Near/far depth in meters
    }

    struct MotionComfortData: Codable {
        var velocityThreshold: Float = 2.0      // Max comfortable velocity (m/s)
        var accelerationThreshold: Float = 1.0  // Max comfortable acceleration (m/s²)
        var rotationThreshold: Float = 45.0     // Max comfortable rotation (deg/s)
        var comfortScore: Float = 1.0           // Overall comfort score (0-1)
        var vignetteIntensity: Float = 0.0      // Comfort vignette when moving
        var horizonLock: Bool = true            // Lock horizon for comfort
        var teleportOnly: Bool = false          // No smooth locomotion
        var snapTurning: Bool = true            // Snap vs smooth turning
        var snapAngle: Float = 45.0             // Degrees per snap turn
    }

    struct FOVData: Codable {
        var horizontalFOV: Float = 100.0     // Horizontal field of view
        var verticalFOV: Float = 90.0        // Vertical field of view
        var peripheralDimming: Float = 0.0   // Dim peripheral vision for comfort
        var foveatedRendering: Bool = true   // Enable foveated rendering
        var foveationLevel: Int = 2          // 0=off, 1=low, 2=medium, 3=high
    }

    struct StereoscopicData: Codable {
        var renderMode: StereoRenderMode = .sideBySide
        var eyeOrder: EyeOrder = .leftFirst
        var depthQuality: DepthQuality = .high
        var occlusionHandling: Bool = true
        var reprojection: Bool = true
        var asyncTimeWarp: Bool = true

        enum StereoRenderMode: String, Codable {
            case sideBySide = "sbs"
            case topBottom = "tb"
            case multiview = "mv"
            case sequential = "seq"
        }

        enum EyeOrder: String, Codable {
            case leftFirst = "left"
            case rightFirst = "right"
        }

        enum DepthQuality: String, Codable {
            case low, medium, high, ultra
        }
    }

    struct TemporalFrame: Codable {
        var timestamp: TimeInterval
        var cameraPosition: SIMD3<Float>
        var cameraRotation: simd_quatf
        var velocity: SIMD3<Float>
        var acceleration: SIMD3<Float>
        var motionIntensity: Float
        var comfortAdjustments: ComfortAdjustments
    }

    struct ComfortAdjustments: Codable {
        var vignetteRadius: Float = 1.0
        var blurAmount: Float = 0.0
        var fovReduction: Float = 0.0
        var stabilizationStrength: Float = 0.0
    }

    struct BioReactiveMetadata: Codable {
        var hrvInfluence: Float = 0.5          // How much HRV affects experience
        var coherenceThreshold: Float = 0.7    // Coherence level for calm mode
        var stressReduction: Bool = true       // Enable stress-reducing adjustments
        var breathingSyncEnabled: Bool = true  // Sync visuals to breathing
        var adaptiveComfort: Bool = true       // Auto-adjust based on bio-data
    }

    struct SpatialAudioAnchor: Codable, Identifiable {
        let id: UUID
        var position: SIMD3<Float>
        var orientation: simd_quatf
        var audioSourceID: String
        var attenuationModel: AttenuationModel
        var spatializationMode: SpatializationMode

        enum AttenuationModel: String, Codable {
            case linear, logarithmic, inverse, none
        }

        enum SpatializationMode: String, Codable {
            case pointSource, ambisonic, stereo, hrtf
        }
    }

    // MARK: - Comfort Warning System

    struct ComfortWarning: Identifiable {
        let id = UUID()
        let type: WarningType
        let severity: Severity
        let message: String
        let timestamp: Date

        enum WarningType {
            case highMotion
            case rapidRotation
            case depthConflict
            case prolongedUse
            case ipdMismatch
        }

        enum Severity {
            case low, medium, high, critical
        }
    }

    // MARK: - Private Properties

    private var metadata: AIVMetadata?
    private var frameBuffer: [TemporalFrame] = []
    private var lastFrameTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var cumulativeMotion: Float = 0

    // Bio-data integration
    private var currentHRV: Float = 50.0
    private var currentCoherence: Float = 0.5

    // MARK: - Initialization

    init() {
        setupDefaultMetadata()
        print("🥽 AIVMetadataEngine: Initialized")
    }

    private func setupDefaultMetadata() {
        metadata = AIVMetadata(
            ilpd: ILPDData(),
            motionComfort: MotionComfortData(),
            fov: FOVData(),
            stereo: StereoscopicData(),
            temporalMetadata: [],
            bioReactive: BioReactiveMetadata(),
            spatialAnchors: []
        )
    }

    // MARK: - ILPD Calibration

    func calibrateIPD(_ measuredIPD: Float) {
        guard var meta = metadata else { return }

        // Clamp to safe range
        let clampedIPD = max(meta.ilpd.minIPD, min(meta.ilpd.maxIPD, measuredIPD))
        meta.ilpd.baseIPD = clampedIPD
        currentILPD = clampedIPD

        // Adjust parallax based on IPD difference from average
        let ipdDelta = clampedIPD - 63.0
        meta.ilpd.parallaxScale = 1.0 + (ipdDelta / 100.0)

        metadata = meta

        print("🥽 AIV: IPD calibrated to \(clampedIPD)mm, parallax scale: \(meta.ilpd.parallaxScale)")
    }

    func setConvergenceDistance(_ distance: Float) {
        guard var meta = metadata else { return }
        meta.ilpd.convergenceDistance = max(0.5, min(100.0, distance))
        metadata = meta
    }

    // MARK: - Motion Comfort Analysis

    func analyzeFrameMotion(
        position: SIMD3<Float>,
        rotation: simd_quatf,
        timestamp: TimeInterval
    ) -> Float {
        let deltaTime = timestamp - lastFrameTime
        guard deltaTime > 0, deltaTime < 1.0 else {
            lastFrameTime = timestamp
            return 1.0
        }

        // Calculate velocity and acceleration
        var velocity: SIMD3<Float> = .zero
        var acceleration: SIMD3<Float> = .zero

        if let lastFrame = frameBuffer.last {
            velocity = (position - lastFrame.cameraPosition) / Float(deltaTime)
            acceleration = (velocity - lastFrame.velocity) / Float(deltaTime)
        }

        // Calculate motion intensity
        let linearSpeed = simd_length(velocity)
        let linearAccel = simd_length(acceleration)

        // Calculate rotation speed (simplified)
        var rotationSpeed: Float = 0.0
        if let lastFrame = frameBuffer.last {
            let rotDiff = rotation * lastFrame.cameraRotation.inverse
            rotationSpeed = abs(rotDiff.angle) * (180.0 / .pi) / Float(deltaTime)
        }

        // Compute comfort score
        guard let meta = metadata else { return 1.0 }

        var comfortScore: Float = 1.0

        // Penalize high linear velocity
        if linearSpeed > meta.motionComfort.velocityThreshold {
            let excess = linearSpeed - meta.motionComfort.velocityThreshold
            comfortScore -= min(0.5, excess * 0.1)
        }

        // Penalize high acceleration
        if linearAccel > meta.motionComfort.accelerationThreshold {
            let excess = linearAccel - meta.motionComfort.accelerationThreshold
            comfortScore -= min(0.3, excess * 0.15)
        }

        // Penalize rapid rotation
        if rotationSpeed > meta.motionComfort.rotationThreshold {
            let excess = rotationSpeed - meta.motionComfort.rotationThreshold
            comfortScore -= min(0.4, excess * 0.01)
        }

        // Apply bio-reactive adjustments
        if meta.bioReactive.adaptiveComfort {
            // Lower comfort threshold when stressed
            if currentCoherence < meta.bioReactive.coherenceThreshold {
                comfortScore *= 0.8 + (currentCoherence * 0.2)
            }
        }

        comfortScore = max(0.0, min(1.0, comfortScore))
        motionComfortLevel = comfortScore

        // Calculate comfort adjustments
        let adjustments = calculateComfortAdjustments(comfortScore: comfortScore)

        // Store frame
        let frame = TemporalFrame(
            timestamp: timestamp,
            cameraPosition: position,
            cameraRotation: rotation,
            velocity: velocity,
            acceleration: acceleration,
            motionIntensity: 1.0 - comfortScore,
            comfortAdjustments: adjustments
        )

        frameBuffer.append(frame)
        if frameBuffer.count > 300 { // Keep ~5 seconds at 60fps
            frameBuffer.removeFirst()
        }

        lastFrameTime = timestamp
        cumulativeMotion += 1.0 - comfortScore

        // Check for warnings
        checkComfortWarnings(comfortScore: comfortScore, rotationSpeed: rotationSpeed)

        return comfortScore
    }

    private func calculateComfortAdjustments(comfortScore: Float) -> ComfortAdjustments {
        var adjustments = ComfortAdjustments()

        // Apply vignette for motion
        if comfortScore < 0.7 {
            adjustments.vignetteRadius = 0.6 + (comfortScore * 0.4)
        }

        // Apply blur for very uncomfortable motion
        if comfortScore < 0.4 {
            adjustments.blurAmount = (0.4 - comfortScore) * 2.0
        }

        // Reduce FOV for extreme motion
        if comfortScore < 0.3 {
            adjustments.fovReduction = (0.3 - comfortScore) * 50.0
        }

        // Apply stabilization
        adjustments.stabilizationStrength = max(0, 1.0 - comfortScore)

        return adjustments
    }

    private func checkComfortWarnings(comfortScore: Float, rotationSpeed: Float) {
        // High motion warning
        if comfortScore < 0.3 {
            addWarning(type: .highMotion, severity: .high,
                      message: "High motion detected. Consider taking a break.")
        }

        // Rapid rotation warning
        if rotationSpeed > 90.0 {
            addWarning(type: .rapidRotation, severity: .medium,
                      message: "Rapid head rotation detected.")
        }

        // Prolonged use warning
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration > 30 * 60 && cumulativeMotion > 100 {
                addWarning(type: .prolongedUse, severity: .medium,
                          message: "Consider taking a break after 30 minutes.")
            }
        }
    }

    private func addWarning(type: ComfortWarning.WarningType, severity: ComfortWarning.Severity, message: String) {
        // Don't duplicate recent warnings
        let recentWarnings = comfortWarnings.filter {
            Date().timeIntervalSince($0.timestamp) < 30
        }
        guard !recentWarnings.contains(where: { $0.type == type }) else { return }

        let warning = ComfortWarning(type: type, severity: severity, message: message, timestamp: Date())
        comfortWarnings.append(warning)

        // Keep only last 10 warnings
        if comfortWarnings.count > 10 {
            comfortWarnings.removeFirst()
        }

        print("⚠️ AIV Comfort Warning: \(message)")
    }

    // MARK: - Bio-Reactive Integration

    func updateBioData(hrv: Float, coherence: Float) {
        currentHRV = hrv
        currentCoherence = coherence

        guard var meta = metadata, meta.bioReactive.stressReduction else { return }

        // Adjust comfort thresholds based on stress level
        if coherence < 0.5 {
            // User is stressed - be more conservative
            meta.motionComfort.velocityThreshold = 1.5
            meta.motionComfort.rotationThreshold = 30.0
            meta.motionComfort.vignetteIntensity = 0.3
        } else if coherence > 0.8 {
            // User is calm - allow more motion
            meta.motionComfort.velocityThreshold = 3.0
            meta.motionComfort.rotationThreshold = 60.0
            meta.motionComfort.vignetteIntensity = 0.0
        }

        metadata = meta
    }

    // MARK: - Stereoscopic Depth Control

    func setStereoscopicDepth(_ depth: Float) {
        stereoscopicDepth = max(0.0, min(1.0, depth))

        guard var meta = metadata else { return }
        meta.ilpd.parallaxScale = depth
        metadata = meta
    }

    func setDepthRange(near: Float, far: Float) {
        guard var meta = metadata else { return }
        meta.ilpd.depthRange = near...far
        metadata = meta
    }

    // MARK: - Spatial Audio Anchors

    func addSpatialAudioAnchor(
        position: SIMD3<Float>,
        orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        audioSourceID: String,
        attenuationModel: SpatialAudioAnchor.AttenuationModel = .logarithmic,
        spatializationMode: SpatialAudioAnchor.SpatializationMode = .hrtf
    ) -> UUID {
        let anchor = SpatialAudioAnchor(
            id: UUID(),
            position: position,
            orientation: orientation,
            audioSourceID: audioSourceID,
            attenuationModel: attenuationModel,
            spatializationMode: spatializationMode
        )

        metadata?.spatialAnchors.append(anchor)

        print("🔊 AIV: Added spatial audio anchor at \(position)")
        return anchor.id
    }

    func updateSpatialAudioAnchor(id: UUID, position: SIMD3<Float>?, orientation: simd_quatf?) {
        guard var meta = metadata,
              let index = meta.spatialAnchors.firstIndex(where: { $0.id == id }) else { return }

        if let pos = position {
            meta.spatialAnchors[index].position = pos
        }
        if let rot = orientation {
            meta.spatialAnchors[index].orientation = rot
        }

        metadata = meta
    }

    func removeSpatialAudioAnchor(id: UUID) {
        metadata?.spatialAnchors.removeAll { $0.id == id }
    }

    // MARK: - Session Management

    func startImmersiveSession() {
        isImmersiveActive = true
        sessionStartTime = Date()
        cumulativeMotion = 0
        frameBuffer.removeAll()
        comfortWarnings.removeAll()

        print("🥽 AIV: Immersive session started")
    }

    func endImmersiveSession() {
        isImmersiveActive = false

        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("🥽 AIV: Immersive session ended. Duration: \(Int(duration))s, Cumulative motion: \(cumulativeMotion)")
        }

        sessionStartTime = nil
    }

    // MARK: - Export/Import Metadata

    func exportMetadata() -> Data? {
        guard let meta = metadata else { return nil }
        return try? JSONEncoder().encode(meta)
    }

    func importMetadata(_ data: Data) -> Bool {
        guard let meta = try? JSONDecoder().decode(AIVMetadata.self, from: data) else {
            return false
        }
        metadata = meta
        currentILPD = meta.ilpd.baseIPD
        return true
    }

    // MARK: - Comfort Presets

    enum ComfortPreset {
        case comfortable   // Maximum comfort, minimal motion
        case moderate      // Balanced experience
        case intense       // Full motion, experienced users
        case accessibility // Extra comfort for sensitive users
    }

    func applyComfortPreset(_ preset: ComfortPreset) {
        guard var meta = metadata else { return }

        switch preset {
        case .comfortable:
            meta.motionComfort.velocityThreshold = 1.0
            meta.motionComfort.rotationThreshold = 30.0
            meta.motionComfort.teleportOnly = true
            meta.motionComfort.snapTurning = true
            meta.motionComfort.horizonLock = true
            meta.fov.peripheralDimming = 0.3

        case .moderate:
            meta.motionComfort.velocityThreshold = 2.0
            meta.motionComfort.rotationThreshold = 45.0
            meta.motionComfort.teleportOnly = false
            meta.motionComfort.snapTurning = true
            meta.motionComfort.horizonLock = true
            meta.fov.peripheralDimming = 0.1

        case .intense:
            meta.motionComfort.velocityThreshold = 5.0
            meta.motionComfort.rotationThreshold = 90.0
            meta.motionComfort.teleportOnly = false
            meta.motionComfort.snapTurning = false
            meta.motionComfort.horizonLock = false
            meta.fov.peripheralDimming = 0.0

        case .accessibility:
            meta.motionComfort.velocityThreshold = 0.5
            meta.motionComfort.rotationThreshold = 20.0
            meta.motionComfort.teleportOnly = true
            meta.motionComfort.snapTurning = true
            meta.motionComfort.snapAngle = 30.0
            meta.motionComfort.horizonLock = true
            meta.fov.peripheralDimming = 0.5
            meta.stereo.depthQuality = .medium
            stereoscopicDepth = 0.5
        }

        metadata = meta
        print("🥽 AIV: Applied comfort preset: \(preset)")
    }

    // MARK: - Real-time Adjustments

    func getComfortAdjustmentsForFrame() -> ComfortAdjustments {
        return frameBuffer.last?.comfortAdjustments ?? ComfortAdjustments()
    }

    func getCurrentRenderParameters() -> (ilpd: Float, parallaxScale: Float, fovReduction: Float) {
        guard let meta = metadata else {
            return (63.0, 1.0, 0.0)
        }

        let adjustments = getComfortAdjustmentsForFrame()

        return (
            ilpd: currentILPD,
            parallaxScale: meta.ilpd.parallaxScale * stereoscopicDepth,
            fovReduction: adjustments.fovReduction
        )
    }
}

// MARK: - simd_quatf Codable Extension

extension simd_quatf: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, z, w
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Float.self, forKey: .x)
        let y = try container.decode(Float.self, forKey: .y)
        let z = try container.decode(Float.self, forKey: .z)
        let w = try container.decode(Float.self, forKey: .w)
        self.init(ix: x, iy: y, iz: z, r: w)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imag.x, forKey: .x)
        try container.encode(imag.y, forKey: .y)
        try container.encode(imag.z, forKey: .z)
        try container.encode(real, forKey: .w)
    }
}
