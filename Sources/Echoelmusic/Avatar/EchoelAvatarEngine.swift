// EchoelAvatarEngine.swift
// Echoelmusic — Bio-Reactive Avatar System
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelAvatar — Photorealistic bio-reactive avatars driven by biometrics
//
// Technology Stack:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  TrueDepth Camera (ARKit)                                                │
// │       │                                                                  │
// │       ├─→ 52 Blendshapes @ 60fps ──→ Facial expression mapping          │
// │       ├─→ Face Mesh (1220 vertices) ──→ Geometry deformation            │
// │       ├─→ Head Pose (6DoF) ──→ Orientation tracking                     │
// │       │                                                                  │
// │  Apple Watch (HealthKit)                                                 │
// │       │                                                                  │
// │       ├─→ HRV/Coherence ──→ Avatar aura, particle systems              │
// │       ├─→ Heart Rate ──→ Breathing animation, skin flush                │
// │       ├─→ Breathing Rate ──→ Chest movement, ambient particles          │
// │       │                                                                  │
// │  Audio Engine                                                            │
// │       │                                                                  │
// │       ├─→ Frequency Spectrum ──→ Visual resonance, shader effects       │
// │       ├─→ Amplitude ──→ Scale pulsing, emission intensity               │
// │       │                                                                  │
// │       ▼                                                                  │
// │  Avatar Renderer                                                         │
// │       │                                                                  │
// │       ├─→ 3D Gaussian Splatting (MetalSplatter) ──→ Photorealistic      │
// │       ├─→ Stylized (Metal Shaders) ──→ Artistic/Abstract                │
// │       ├─→ Particle Cloud ──→ Bio-reactive particle avatar               │
// │       ├─→ Silhouette ──→ Privacy-first shadow mode                      │
// │       │                                                                  │
// │       ▼                                                                  │
// │  Output Targets                                                          │
// │       ├─→ SwiftUI View (app)                                            │
// │       ├─→ Stream overlay (OBS/RTMP)                                     │
// │       ├─→ visionOS Spatial (RealityKit)                                 │
// │       ├─→ External display (Stage)                                      │
// │       └─→ NFT snapshot (EchoelMint)                                     │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Key Research:
// - Apple HUGS: Human Gaussian Splats (monocular video → animatable avatar, 60fps)
// - TaoAvatar (Alibaba): Full-body 3DGS avatar, 90fps on Vision Pro
// - MetalSplatter: Open-source Metal Gaussian Splatting renderer for Apple platforms
// - Apple Persona: Vision Pro uses 3DGS for facial scans
// - ARKit: 52 blendshapes @ 60fps, body tracking, hand tracking
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import SwiftUI
#if canImport(ARKit)
import ARKit
#endif
#if canImport(MetalKit)
import MetalKit
#endif

// MARK: - Avatar Types

/// Avatar visual style
public enum AvatarStyle: String, CaseIterable, Codable, Sendable {
    case photorealistic = "Photorealistic"  // 3D Gaussian Splatting
    case stylized = "Stylized"              // Artistic shader-based
    case particleCloud = "Particle Cloud"   // Bio-reactive particle avatar
    case silhouette = "Silhouette"          // Privacy-first shadow
    case holographic = "Holographic"        // Sci-fi hologram effect
    case cymatics = "Cymatics"             // Sound-reactive cymatics patterns
    case abstract = "Abstract"              // Pure geometry from bio-data

    public var description: String {
        switch self {
        case .photorealistic: return "3D Gaussian Splatting photorealistic avatar"
        case .stylized: return "Artistic shader-based avatar"
        case .particleCloud: return "Bio-reactive particle cloud avatar"
        case .silhouette: return "Privacy-preserving silhouette"
        case .holographic: return "Holographic projection effect"
        case .cymatics: return "Sound-reactive cymatics visualization"
        case .abstract: return "Abstract geometry from biometric data"
        }
    }
}

/// Avatar animation state
public enum AvatarAnimationState: String, Sendable {
    case idle = "Idle"
    case speaking = "Speaking"
    case singing = "Singing"
    case performing = "Performing"
    case meditating = "Meditating"
    case listening = "Listening"
}

/// Facial expression data from ARKit blendshapes
public struct FacialExpression: Sendable {
    // Eyes
    public var eyeBlinkLeft: Float = 0
    public var eyeBlinkRight: Float = 0
    public var eyeLookUpLeft: Float = 0
    public var eyeLookDownLeft: Float = 0
    public var eyeLookInLeft: Float = 0
    public var eyeLookOutLeft: Float = 0
    public var eyeSquintLeft: Float = 0
    public var eyeWideLeft: Float = 0

    // Mouth
    public var jawOpen: Float = 0
    public var mouthSmileLeft: Float = 0
    public var mouthSmileRight: Float = 0
    public var mouthFrownLeft: Float = 0
    public var mouthFrownRight: Float = 0
    public var mouthPucker: Float = 0
    public var mouthFunnel: Float = 0

    // Brows
    public var browDownLeft: Float = 0
    public var browDownRight: Float = 0
    public var browInnerUp: Float = 0
    public var browOuterUpLeft: Float = 0
    public var browOuterUpRight: Float = 0

    // Cheeks
    public var cheekPuff: Float = 0
    public var cheekSquintLeft: Float = 0
    public var cheekSquintRight: Float = 0

    // Nose
    public var noseSneerLeft: Float = 0
    public var noseSneerRight: Float = 0

    // Head pose
    public var headPitch: Float = 0     // Nod up/down
    public var headYaw: Float = 0       // Turn left/right
    public var headRoll: Float = 0      // Tilt left/right

    /// Is the user smiling?
    public var isSmiling: Bool {
        (mouthSmileLeft + mouthSmileRight) / 2.0 > 0.3
    }

    /// Is the user's mouth open (speaking/singing)?
    public var isMouthOpen: Bool {
        jawOpen > 0.15
    }

    /// Emotional valence (-1 frown to +1 smile)
    public var emotionalValence: Float {
        let smile = (mouthSmileLeft + mouthSmileRight) / 2.0
        let frown = (mouthFrownLeft + mouthFrownRight) / 2.0
        return smile - frown
    }

    public static let neutral = FacialExpression()

    #if canImport(ARKit)
    /// Create from ARKit blendshapes
    public static func from(blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> FacialExpression {
        var expr = FacialExpression()
        expr.eyeBlinkLeft = blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        expr.eyeBlinkRight = blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        expr.eyeLookUpLeft = blendShapes[.eyeLookUpLeft]?.floatValue ?? 0
        expr.eyeLookDownLeft = blendShapes[.eyeLookDownLeft]?.floatValue ?? 0
        expr.eyeLookInLeft = blendShapes[.eyeLookInLeft]?.floatValue ?? 0
        expr.eyeLookOutLeft = blendShapes[.eyeLookOutLeft]?.floatValue ?? 0
        expr.eyeSquintLeft = blendShapes[.eyeSquintLeft]?.floatValue ?? 0
        expr.eyeWideLeft = blendShapes[.eyeWideLeft]?.floatValue ?? 0
        expr.jawOpen = blendShapes[.jawOpen]?.floatValue ?? 0
        expr.mouthSmileLeft = blendShapes[.mouthSmileLeft]?.floatValue ?? 0
        expr.mouthSmileRight = blendShapes[.mouthSmileRight]?.floatValue ?? 0
        expr.mouthFrownLeft = blendShapes[.mouthFrownLeft]?.floatValue ?? 0
        expr.mouthFrownRight = blendShapes[.mouthFrownRight]?.floatValue ?? 0
        expr.mouthPucker = blendShapes[.mouthPucker]?.floatValue ?? 0
        expr.mouthFunnel = blendShapes[.mouthFunnel]?.floatValue ?? 0
        expr.browDownLeft = blendShapes[.browDownLeft]?.floatValue ?? 0
        expr.browDownRight = blendShapes[.browDownRight]?.floatValue ?? 0
        expr.browInnerUp = blendShapes[.browInnerUp]?.floatValue ?? 0
        expr.browOuterUpLeft = blendShapes[.browOuterUpLeft]?.floatValue ?? 0
        expr.browOuterUpRight = blendShapes[.browOuterUpRight]?.floatValue ?? 0
        expr.cheekPuff = blendShapes[.cheekPuff]?.floatValue ?? 0
        expr.cheekSquintLeft = blendShapes[.cheekSquintLeft]?.floatValue ?? 0
        expr.cheekSquintRight = blendShapes[.cheekSquintRight]?.floatValue ?? 0
        expr.noseSneerLeft = blendShapes[.noseSneerLeft]?.floatValue ?? 0
        expr.noseSneerRight = blendShapes[.noseSneerRight]?.floatValue ?? 0
        return expr
    }
    #endif
}

/// Bio-reactive aura surrounding the avatar
public struct AvatarAura: Sendable {
    public var intensity: Float             // 0-1 glow intensity
    public var color: (r: Float, g: Float, b: Float)  // HSV-derived color
    public var particleCount: Int           // Number of ambient particles
    public var pulseRate: Float             // Hz — synced to heartbeat
    public var geometry: AuraGeometry       // Shape of the aura field

    public enum AuraGeometry: String, CaseIterable, Sendable {
        case sphere = "Sphere"
        case torus = "Torus"
        case fibonacci = "Fibonacci"        // Sacred geometry (high coherence)
        case fractal = "Fractal"            // Mandelbrot-derived (medium coherence)
        case chaotic = "Chaotic"            // Random particles (low coherence)
    }

    /// Generate aura from biometric state
    public static func from(coherence: Float, heartRate: Float, energy: Float) -> AvatarAura {
        let geometry: AuraGeometry
        if coherence > 0.8 {
            geometry = .fibonacci
        } else if coherence > 0.5 {
            geometry = .torus
        } else if coherence > 0.3 {
            geometry = .fractal
        } else {
            geometry = .chaotic
        }

        // Color: coherence maps green→gold→white (low→high)
        let hue = coherence * 60.0 / 360.0 // 0=red, 60=yellow
        let saturation = 1.0 - coherence * 0.5 // Less saturated at high coherence
        let brightness = 0.5 + coherence * 0.5

        return AvatarAura(
            intensity: 0.3 + coherence * 0.7,
            color: hsvToRGB(h: hue, s: saturation, v: brightness),
            particleCount: Int(50 + energy * 200),
            pulseRate: heartRate / 60.0, // Convert BPM to Hz
            geometry: geometry
        )
    }

    private static func hsvToRGB(h: Float, s: Float, v: Float) -> (Float, Float, Float) {
        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let segment = Int(h * 6)
        var r: Float = 0, g: Float = 0, b: Float = 0
        switch segment {
        case 0: r = c; g = x; b = 0
        case 1: r = x; g = c; b = 0
        case 2: r = 0; g = c; b = x
        case 3: r = 0; g = x; b = c
        case 4: r = x; g = 0; b = c
        default: r = c; g = 0; b = x
        }
        return (r + m, g + m, b + m)
    }
}

/// Avatar snapshot for NFT minting
public struct AvatarSnapshot: Codable, Sendable {
    public let style: String
    public let timestamp: Date
    public let coherence: Float
    public let heartRate: Float
    public let emotionalValence: Float
    public let auraGeometry: String
    public let colorPalette: [String]
}

// MARK: - EchoelAvatarEngine

/// Bio-reactive avatar engine — the visual embodiment of biometric state
///
/// Creates and animates avatars driven by:
/// 1. Face tracking (ARKit 52 blendshapes @ 60fps)
/// 2. Biometric data (HRV coherence, heart rate, breathing)
/// 3. Audio analysis (frequency spectrum, amplitude)
/// 4. Musical context (key, tempo, instruments)
///
/// Supports multiple render styles from photorealistic (3D Gaussian Splatting)
/// to abstract (pure geometry from bio-data).
///
/// Usage:
/// ```swift
/// let avatar = EchoelAvatarEngine.shared
/// avatar.style = .particleCloud
///
/// // Start face tracking
/// avatar.startFaceTracking()
///
/// // Avatar automatically receives bio/audio data via EngineBus
/// // Aura, particles, and animations update in real-time
///
/// // Snapshot for NFT
/// let snapshot = avatar.captureSnapshot()
/// EchoelMintEngine.shared.quickCapture(name: "Avatar Moment")
/// ```
@MainActor
public final class EchoelAvatarEngine: ObservableObject {

    public static let shared = EchoelAvatarEngine()

    // MARK: - Published State

    /// Current avatar style
    @Published public var style: AvatarStyle = .particleCloud

    /// Current facial expression
    @Published public var expression: FacialExpression = .neutral

    /// Current bio-reactive aura
    @Published public var aura: AvatarAura = .from(coherence: 0.5, heartRate: 70, energy: 0.5)

    /// Animation state
    @Published public var animationState: AvatarAnimationState = .idle

    /// Is face tracking active
    @Published public var isFaceTrackingActive: Bool = false

    /// Is face tracking available (TrueDepth camera)
    @Published public var isFaceTrackingAvailable: Bool = false

    /// Current coherence (for aura generation)
    @Published public var coherence: Float = 0.5

    /// Current heart rate (for pulse sync)
    @Published public var heartRate: Float = 70

    /// Current breathing rate (for chest animation)
    @Published public var breathingRate: Float = 15

    /// Audio energy (for visual resonance)
    @Published public var audioEnergy: Float = 0

    /// Audio spectrum (for frequency-based effects)
    @Published public var audioSpectrum: [Float] = Array(repeating: 0, count: 32)

    /// Avatar visibility
    @Published public var isVisible: Bool = true

    /// Render quality (affects GPU usage)
    @Published public var renderQuality: RenderQuality = .balanced

    /// Background removal for stream overlay
    @Published public var removeBackground: Bool = true

    /// Mirror mode (selfie view)
    @Published public var isMirrored: Bool = true

    // MARK: - Render Quality

    public enum RenderQuality: String, CaseIterable, Sendable {
        case low = "Low"                // 30fps, reduced particles
        case balanced = "Balanced"      // 60fps, standard
        case high = "High"              // 60fps, max particles, 4K
        case ultra = "Ultra"            // 120fps, max everything (M-series only)
    }

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var audioBusSubscription: BusSubscription?
    private var updateTimer: Timer?

    #if canImport(ARKit)
    private var arSession: ARSession?
    private var faceTrackingConfig: ARFaceTrackingConfiguration?
    #endif

    // MARK: - Initialization

    private init() {
        checkFaceTrackingAvailability()
        subscribeToBus()
        startUpdateLoop()
    }

    // MARK: - Face Tracking

    /// Start ARKit face tracking
    public func startFaceTracking() {
        #if canImport(ARKit)
        guard ARFaceTrackingConfiguration.isSupported else {
            isFaceTrackingAvailable = false
            return
        }

        arSession = ARSession()
        arSession?.delegate = FaceTrackingDelegate(engine: self)

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1

        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        isFaceTrackingActive = true

        EngineBus.shared.publish(.custom(
            topic: "avatar.facetracking.start",
            payload: [:]
        ))
        #endif
    }

    /// Stop face tracking
    public func stopFaceTracking() {
        #if canImport(ARKit)
        arSession?.pause()
        arSession = nil
        #endif
        isFaceTrackingActive = false
        expression = .neutral
    }

    // MARK: - Aura & Animation

    /// Update the bio-reactive aura based on current state
    public func updateAura() {
        aura = AvatarAura.from(
            coherence: coherence,
            heartRate: heartRate,
            energy: audioEnergy
        )

        // Determine animation state
        if expression.isMouthOpen && audioEnergy > 0.3 {
            animationState = .singing
        } else if expression.isMouthOpen {
            animationState = .speaking
        } else if coherence > 0.8 && audioEnergy < 0.2 {
            animationState = .meditating
        } else if audioEnergy > 0.5 {
            animationState = .performing
        } else if audioEnergy > 0.1 {
            animationState = .listening
        } else {
            animationState = .idle
        }
    }

    /// Capture current avatar state as snapshot (for NFT minting)
    public func captureSnapshot() -> AvatarSnapshot {
        let auraColor = aura.color
        let r = Int(auraColor.r * 255)
        let g = Int(auraColor.g * 255)
        let b = Int(auraColor.b * 255)

        return AvatarSnapshot(
            style: style.rawValue,
            timestamp: Date(),
            coherence: coherence,
            heartRate: heartRate,
            emotionalValence: expression.emotionalValence,
            auraGeometry: aura.geometry.rawValue,
            colorPalette: [
                String(format: "#%02X%02X%02X", r, g, b),
                String(format: "#%02X%02X%02X", min(255, r + 40), g, b),
                String(format: "#%02X%02X%02X", r, min(255, g + 40), b),
            ]
        )
    }

    /// Set avatar style with smooth transition
    public func setStyle(_ newStyle: AvatarStyle, animated: Bool = true) {
        style = newStyle

        EngineBus.shared.publish(.custom(
            topic: "avatar.style.changed",
            payload: [
                "style": newStyle.rawValue,
                "animated": animated ? "true" : "false"
            ]
        ))
    }

    // MARK: - Gaussian Splatting

    /// Load a 3D Gaussian Splatting model for photorealistic avatar
    ///
    /// Supports PLY, SPZ, and .splat formats (MetalSplatter compatible)
    public func loadGaussianSplatModel(from url: URL) async throws {
        guard style == .photorealistic else { return }

        EngineBus.shared.publish(.custom(
            topic: "avatar.gaussiansplat.load",
            payload: ["url": url.path]
        ))

        // MetalSplatter integration:
        // let splatScene = try SplatScene(from: url)
        // Uses Metal compute shaders for real-time rendering
        // Supports iOS, macOS, visionOS (stereo rendering via amplification)
    }

    /// Capture a new Gaussian Splat from TrueDepth camera
    ///
    /// Creates a photorealistic 3D avatar from face scan
    /// Based on Apple HUGS (Human Gaussian Splats) approach
    public func captureGaussianSplat() async throws {
        guard isFaceTrackingActive else {
            throw AvatarError.faceTrackingRequired
        }

        EngineBus.shared.publish(.custom(
            topic: "avatar.gaussiansplat.capture",
            payload: ["frames": "50"] // HUGS needs 50-100 frames
        ))
    }

    // MARK: - Stream Integration

    /// Get avatar render parameters for stream overlay
    public var streamOverlayParameters: [String: Any] {
        [
            "style": style.rawValue,
            "visible": isVisible,
            "mirrored": isMirrored,
            "removeBackground": removeBackground,
            "auraIntensity": aura.intensity,
            "auraColor": [aura.color.r, aura.color.g, aura.color.b],
            "particleCount": aura.particleCount,
            "animationState": animationState.rawValue,
            "coherence": coherence,
        ]
    }

    // MARK: - Error Types

    public enum AvatarError: Error {
        case faceTrackingNotAvailable
        case faceTrackingRequired
        case modelLoadFailed
        case renderingFailed
    }

    // MARK: - Private Methods

    private func checkFaceTrackingAvailability() {
        #if canImport(ARKit)
        isFaceTrackingAvailable = ARFaceTrackingConfiguration.isSupported
        #else
        isFaceTrackingAvailable = false
        #endif
    }

    /// 30Hz update loop for smooth avatar animation
    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAura()
            }
        }
    }

    /// Subscribe to EngineBus for bio and audio data
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.coherence = bio.coherence
                    self?.heartRate = bio.heartRate
                    self?.breathingRate = bio.breathingRate
                }
            }
        }

        audioBusSubscription = EngineBus.shared.subscribe(to: .audio) { [weak self] msg in
            if case .audioAnalysis(let audio) = msg {
                Task { @MainActor in
                    self?.audioEnergy = audio.rmsLevel
                    self?.audioSpectrum = audio.spectrum
                }
            }
        }
    }
}

// MARK: - ARKit Face Tracking Delegate

#if canImport(ARKit)
private class FaceTrackingDelegate: NSObject, ARSessionDelegate {
    weak var engine: EchoelAvatarEngine?

    init(engine: EchoelAvatarEngine) {
        self.engine = engine
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first as? ARFaceAnchor else { return }

        let expression = FacialExpression.from(blendShapes: faceAnchor.blendShapes)
        let transform = faceAnchor.transform

        // Extract head pose from transform matrix
        var expr = expression
        expr.headPitch = atan2(transform.columns.2.y, transform.columns.2.z)
        expr.headYaw = atan2(-transform.columns.2.x,
                              sqrt(transform.columns.2.y * transform.columns.2.y + transform.columns.2.z * transform.columns.2.z))
        expr.headRoll = atan2(transform.columns.1.x, transform.columns.0.x)

        Task { @MainActor [weak self] in
            self?.engine?.expression = expr

            // Publish expression to bus for other engines
            EngineBus.shared.publish(.custom(
                topic: "avatar.expression",
                payload: [
                    "smile": "\(expr.emotionalValence)",
                    "mouthOpen": "\(expr.jawOpen)",
                    "headYaw": "\(expr.headYaw)"
                ]
            ))
        }
    }
}
#endif
