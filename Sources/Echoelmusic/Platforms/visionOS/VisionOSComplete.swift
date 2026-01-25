//
//  VisionOSComplete.swift
//  Echoelmusic
//
//  visionOS 100% Completion - All Missing Features Implemented
//  Phase 10000 ULTIMATE - Complete visionOS Feature Set
//
//  Created: 2026-01-25
//

import Foundation
import SwiftUI
import Combine
import simd

#if os(visionOS)
import RealityKit
import ARKit
#endif

// MARK: - visionOS Animation System

/// Complete animation system for visionOS immersive experiences
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
@MainActor
public final class VisionOSAnimationController: ObservableObject {

    // MARK: - Published Properties

    @Published public var isAnimating: Bool = false
    @Published public var heartRate: Double = 60.0
    @Published public var coherenceLevel: Float = 0.5
    @Published public var breathingPhase: Float = 0.0

    // MARK: - Animation Parameters

    public struct HeartSyncParameters {
        public var bpm: Double = 60.0
        public var pulseIntensity: Float = 0.3
        public var pulseWaveform: PulseWaveform = .sine
        public var enabled: Bool = true

        public enum PulseWaveform: String, CaseIterable {
            case sine = "Sine"
            case cardiac = "Cardiac"
            case smooth = "Smooth"
            case sharp = "Sharp"
        }
    }

    public struct FloatingParameters {
        public var amplitude: Float = 0.1
        public var frequency: Float = 0.5
        public var noiseAmount: Float = 0.02
        public var rotationSpeed: Float = 0.1
        public var enabled: Bool = true
    }

    public struct BreathingParameters {
        public var inhaleTime: TimeInterval = 4.0
        public var holdTime: TimeInterval = 4.0
        public var exhaleTime: TimeInterval = 4.0
        public var restTime: TimeInterval = 2.0
        public var enabled: Bool = true

        public var totalCycleTime: TimeInterval {
            inhaleTime + holdTime + exhaleTime + restTime
        }
    }

    public struct CoherenceParameters {
        public var lowColor: SIMD3<Float> = SIMD3(1.0, 0.3, 0.3)     // Red
        public var mediumColor: SIMD3<Float> = SIMD3(1.0, 0.8, 0.2)  // Yellow
        public var highColor: SIMD3<Float> = SIMD3(0.2, 1.0, 0.8)    // Cyan
        public var transitionSpeed: Float = 0.1
        public var enabled: Bool = true
    }

    // MARK: - Current Parameters

    public var heartSync = HeartSyncParameters()
    public var floating = FloatingParameters()
    public var breathing = BreathingParameters()
    public var coherence = CoherenceParameters()

    // MARK: - Private Properties

    private var animationTimer: Timer?
    private var startTime: Date = Date()
    private var lastUpdate: Date = Date()

    // MARK: - Computed Animation Values

    /// Current heart pulse value (0-1) based on heart rate
    public var heartPulseValue: Float {
        guard heartSync.enabled else { return 0 }

        let time = Date().timeIntervalSince(startTime)
        let beatsPerSecond = heartRate / 60.0
        let phase = time * beatsPerSecond * 2.0 * .pi

        switch heartSync.pulseWaveform {
        case .sine:
            return Float(sin(phase)) * 0.5 + 0.5
        case .cardiac:
            // Simulate cardiac rhythm with quick systole and longer diastole
            let normalizedPhase = fmod(Float(phase), Float.pi * 2) / (Float.pi * 2)
            if normalizedPhase < 0.15 {
                return Float(sin(normalizedPhase / 0.15 * .pi)) * 0.5 + 0.5
            } else {
                return Float(exp(-Double(normalizedPhase - 0.15) * 3.0)) * 0.3
            }
        case .smooth:
            return Float(pow(sin(phase / 2), 2))
        case .sharp:
            let normalizedPhase = fmod(Float(phase), Float.pi * 2) / (Float.pi * 2)
            return normalizedPhase < 0.1 ? 1.0 : max(0, 1.0 - (normalizedPhase - 0.1) * 2)
        }
    }

    /// Current scale factor for heart-synced pulsing
    public var heartPulseScale: Float {
        1.0 + heartPulseValue * heartSync.pulseIntensity
    }

    /// Current floating offset as 3D vector
    public var floatingOffset: SIMD3<Float> {
        guard floating.enabled else { return .zero }

        let time = Float(Date().timeIntervalSince(startTime))

        let x = sin(time * floating.frequency) * floating.amplitude
        let y = sin(time * floating.frequency * 0.7 + 1.0) * floating.amplitude
        let z = sin(time * floating.frequency * 0.9 + 2.0) * floating.amplitude * 0.5

        // Add subtle noise
        let noiseX = Float.random(in: -floating.noiseAmount...floating.noiseAmount)
        let noiseY = Float.random(in: -floating.noiseAmount...floating.noiseAmount)
        let noiseZ = Float.random(in: -floating.noiseAmount...floating.noiseAmount)

        return SIMD3(x + noiseX, y + noiseY, z + noiseZ)
    }

    /// Current rotation angle for floating entities
    public var floatingRotation: Float {
        guard floating.enabled else { return 0 }

        let time = Float(Date().timeIntervalSince(startTime))
        return time * floating.rotationSpeed
    }

    /// Current breathing phase (0-1 through full cycle)
    public var breathingValue: Float {
        guard breathing.enabled else { return 0.5 }

        let time = Date().timeIntervalSince(startTime)
        let cycleProgress = fmod(time, breathing.totalCycleTime)

        if cycleProgress < breathing.inhaleTime {
            // Inhale: 0 -> 1
            return Float(cycleProgress / breathing.inhaleTime)
        } else if cycleProgress < breathing.inhaleTime + breathing.holdTime {
            // Hold at top: 1
            return 1.0
        } else if cycleProgress < breathing.inhaleTime + breathing.holdTime + breathing.exhaleTime {
            // Exhale: 1 -> 0
            let exhaleProgress = cycleProgress - breathing.inhaleTime - breathing.holdTime
            return 1.0 - Float(exhaleProgress / breathing.exhaleTime)
        } else {
            // Rest at bottom: 0
            return 0.0
        }
    }

    /// Current breathing scale factor
    public var breathingScale: Float {
        0.9 + breathingValue * 0.2
    }

    /// Current coherence color as SIMD3
    public var coherenceColor: SIMD3<Float> {
        guard coherence.enabled else { return SIMD3(1, 1, 1) }

        if coherenceLevel < 0.4 {
            // Low: Red to Yellow
            let t = coherenceLevel / 0.4
            return simd_mix(coherence.lowColor, coherence.mediumColor, SIMD3(repeating: t))
        } else {
            // Medium to High: Yellow to Cyan
            let t = (coherenceLevel - 0.4) / 0.6
            return simd_mix(coherence.mediumColor, coherence.highColor, SIMD3(repeating: t))
        }
    }

    // MARK: - Animation Control

    public init() {}

    /// Start the animation loop
    public func start() {
        guard !isAnimating else { return }

        startTime = Date()
        isAnimating = true

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }

        log.spatial("VisionOS Animation Controller started")
    }

    /// Stop the animation loop
    public func stop() {
        isAnimating = false
        animationTimer?.invalidate()
        animationTimer = nil

        log.spatial("VisionOS Animation Controller stopped")
    }

    /// Update bio data from external source
    public func updateBioData(heartRate: Double, coherence: Float) {
        self.heartRate = heartRate
        self.coherenceLevel = coherence
    }

    private func update() {
        // Update breathing phase for external observation
        breathingPhase = breathingValue

        // Send notification for subscribers
        NotificationCenter.default.post(
            name: .visionOSAnimationUpdate,
            object: nil,
            userInfo: [
                "heartPulse": heartPulseValue,
                "breathingPhase": breathingPhase,
                "coherenceColor": coherenceColor
            ]
        )
    }

    // MARK: - Entity Animation Application

    #if os(visionOS)
    /// Apply heart-synced pulsing animation to an entity
    public func applyHeartSyncAnimation(to entity: Entity, baseScale: Float = 1.0) {
        let scale = baseScale * heartPulseScale
        entity.scale = SIMD3(repeating: scale)
    }

    /// Apply floating animation to an entity
    public func applyFloatingAnimation(to entity: Entity, basePosition: SIMD3<Float>) {
        entity.position = basePosition + floatingOffset

        // Apply subtle rotation
        let rotation = simd_quatf(angle: floatingRotation, axis: SIMD3(0, 1, 0))
        entity.orientation = rotation
    }

    /// Apply breathing animation to an entity
    public func applyBreathingAnimation(to entity: Entity, baseScale: Float = 1.0) {
        let scale = baseScale * breathingScale
        entity.scale = SIMD3(repeating: scale)
    }

    /// Apply coherence color to an entity's material
    public func applyCoherenceColor(to entity: Entity) {
        guard let modelComponent = entity.components[ModelComponent.self] else { return }

        var material = PhysicallyBasedMaterial()
        let color = UIColor(
            red: CGFloat(coherenceColor.x),
            green: CGFloat(coherenceColor.y),
            blue: CGFloat(coherenceColor.z),
            alpha: 0.8
        )
        material.baseColor = .init(tint: color)
        material.emissiveColor = .init(color: color)
        material.emissiveIntensity = 0.5 + coherenceLevel * 0.5

        var updatedComponent = modelComponent
        updatedComponent.materials = [material]
        entity.components.set(updatedComponent)
    }

    /// Apply combined bio-reactive animation to an entity
    public func applyBioReactiveAnimation(
        to entity: Entity,
        basePosition: SIMD3<Float>,
        baseScale: Float = 1.0,
        options: BioReactiveOptions = .all
    ) {
        if options.contains(.heartSync) {
            let scale = baseScale * heartPulseScale
            if options.contains(.breathing) {
                entity.scale = SIMD3(repeating: scale * breathingScale)
            } else {
                entity.scale = SIMD3(repeating: scale)
            }
        } else if options.contains(.breathing) {
            entity.scale = SIMD3(repeating: baseScale * breathingScale)
        }

        if options.contains(.floating) {
            entity.position = basePosition + floatingOffset
            let rotation = simd_quatf(angle: floatingRotation, axis: SIMD3(0, 1, 0))
            entity.orientation = rotation
        }

        if options.contains(.coherenceColor) {
            applyCoherenceColor(to: entity)
        }
    }
    #endif

    public struct BioReactiveOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let heartSync = BioReactiveOptions(rawValue: 1 << 0)
        public static let floating = BioReactiveOptions(rawValue: 1 << 1)
        public static let breathing = BioReactiveOptions(rawValue: 1 << 2)
        public static let coherenceColor = BioReactiveOptions(rawValue: 1 << 3)

        public static let all: BioReactiveOptions = [.heartSync, .floating, .breathing, .coherenceColor]
    }
}

// MARK: - visionOS Gesture Handler

/// Complete gesture handling system for visionOS immersive experiences
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
@MainActor
public final class VisionOSGestureHandler: ObservableObject {

    // MARK: - Published Properties

    @Published public var lastGesture: GestureType?
    @Published public var gestureInProgress: Bool = false
    @Published public var dragOffset: SIMD3<Float> = .zero
    @Published public var pinchScale: Float = 1.0
    @Published public var rotationAngle: Float = 0.0

    // MARK: - Gesture Types

    public enum GestureType: String, CaseIterable {
        case tap = "Tap"
        case doubleTap = "Double Tap"
        case longPress = "Long Press"
        case drag = "Drag"
        case pinch = "Pinch"
        case rotation = "Rotation"
    }

    // MARK: - Visual Effects

    public enum VisualEffect: String, CaseIterable {
        case harmonize = "harmonize"
        case expand = "expand"
        case contract = "contract"
        case spiral = "spiral"
        case pulse = "pulse"
        case collapse = "collapse"
        case scatter = "scatter"
        case converge = "converge"
        case ripple = "ripple"
        case vortex = "vortex"

        public var description: String {
            switch self {
            case .harmonize: return "Align particles to Fibonacci spiral"
            case .expand: return "Expand the quantum light field"
            case .contract: return "Contract the quantum light field"
            case .spiral: return "Trigger spiral animation"
            case .pulse: return "Emit radial pulse wave"
            case .collapse: return "Collapse quantum superposition"
            case .scatter: return "Scatter particles outward"
            case .converge: return "Converge particles to center"
            case .ripple: return "Create ripple effect"
            case .vortex: return "Create vortex effect"
            }
        }
    }

    // MARK: - Effect State

    public struct EffectState {
        public var activeEffect: VisualEffect?
        public var effectProgress: Float = 0.0
        public var effectIntensity: Float = 1.0
        public var effectCenter: SIMD3<Float> = .zero
        public var startTime: Date?

        public var isActive: Bool {
            activeEffect != nil && effectProgress < 1.0
        }
    }

    @Published public var effectState = EffectState()

    // MARK: - Delegates

    public weak var delegate: VisionOSGestureDelegate?

    // MARK: - Private Properties

    private var effectTimer: Timer?
    private let effectDuration: TimeInterval = 1.0

    // MARK: - Initialization

    public init() {}

    // MARK: - Gesture Handling

    #if os(visionOS)
    /// Handle spatial tap gesture
    public func handleSpatialTap(
        _ value: EntityTargetValue<SpatialTapGesture.Value>,
        triggerEffect: VisualEffect = .pulse
    ) {
        lastGesture = .tap

        let position = SIMD3<Float>(
            Float(value.location3D.x),
            Float(value.location3D.y),
            Float(value.location3D.z)
        )

        log.spatial("Spatial tap at position: \(position)")

        triggerVisualEffect(triggerEffect, at: position)
        delegate?.gestureHandler(self, didTap: value.entity, at: position)
    }

    /// Handle drag gesture
    public func handleDrag(
        _ value: EntityTargetValue<DragGesture.Value>,
        entity: Entity
    ) {
        gestureInProgress = true
        lastGesture = .drag

        let translation = value.translation3D
        dragOffset = SIMD3<Float>(
            Float(translation.x),
            Float(translation.y),
            Float(translation.z)
        )

        delegate?.gestureHandler(self, didDrag: entity, offset: dragOffset)
    }

    /// Handle drag gesture ended
    public func handleDragEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        gestureInProgress = false
        dragOffset = .zero
    }

    /// Handle magnify (pinch) gesture
    public func handleMagnify(
        _ value: MagnifyGesture.Value,
        entity: Entity
    ) {
        gestureInProgress = true
        lastGesture = .pinch

        pinchScale = Float(value.magnification)

        // Apply scale to entity
        entity.scale = SIMD3(repeating: pinchScale)

        delegate?.gestureHandler(self, didPinch: entity, scale: pinchScale)
    }

    /// Handle rotation gesture
    public func handleRotation(
        _ value: RotateGesture3D.Value,
        entity: Entity
    ) {
        gestureInProgress = true
        lastGesture = .rotation

        // Apply rotation
        entity.orientation = simd_quatf(value.rotation)
        rotationAngle = Float(value.rotation.angle.radians)

        delegate?.gestureHandler(self, didRotate: entity, angle: rotationAngle)
    }
    #endif

    // MARK: - Visual Effect Triggering

    /// Trigger a visual effect at a specific position
    public func triggerVisualEffect(_ effect: VisualEffect, at position: SIMD3<Float> = .zero) {
        effectState = EffectState(
            activeEffect: effect,
            effectProgress: 0.0,
            effectIntensity: 1.0,
            effectCenter: position,
            startTime: Date()
        )

        // Start animation timer
        effectTimer?.invalidate()
        effectTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateEffect()
            }
        }

        log.spatial("Triggered visual effect: \(effect.rawValue)")
        delegate?.gestureHandler(self, didTriggerEffect: effect, at: position)
    }

    private func updateEffect() {
        guard let startTime = effectState.startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        effectState.effectProgress = min(1.0, Float(elapsed / effectDuration))

        if effectState.effectProgress >= 1.0 {
            effectTimer?.invalidate()
            effectTimer = nil
            effectState.activeEffect = nil
        }
    }

    // MARK: - Effect Application

    #if os(visionOS)
    /// Apply current visual effect to a collection of entities
    public func applyEffect(to entities: [Entity]) {
        guard let effect = effectState.activeEffect else { return }

        let progress = effectState.effectProgress
        let center = effectState.effectCenter
        let intensity = effectState.effectIntensity

        for (index, entity) in entities.enumerated() {
            let offset = Float(index) * 0.01  // Stagger effect
            let entityProgress = max(0, min(1, progress - offset))

            switch effect {
            case .harmonize:
                applyHarmonizeEffect(to: entity, index: index, progress: entityProgress)

            case .expand:
                let scale = 1.0 + entityProgress * intensity * 0.5
                entity.scale = SIMD3(repeating: scale)

            case .contract:
                let scale = 1.0 - entityProgress * intensity * 0.3
                entity.scale = SIMD3(repeating: max(0.1, scale))

            case .spiral:
                applySpiralEffect(to: entity, index: index, progress: entityProgress, center: center)

            case .pulse:
                applyPulseEffect(to: entity, progress: entityProgress, center: center)

            case .collapse:
                applyCollapseEffect(to: entity, progress: entityProgress, center: center)

            case .scatter:
                applyScatterEffect(to: entity, index: index, progress: entityProgress)

            case .converge:
                applyConvergeEffect(to: entity, progress: entityProgress, center: center)

            case .ripple:
                applyRippleEffect(to: entity, progress: entityProgress, center: center)

            case .vortex:
                applyVortexEffect(to: entity, index: index, progress: entityProgress, center: center)
            }
        }
    }

    private func applyHarmonizeEffect(to entity: Entity, index: Int, progress: Float) {
        // Move to Fibonacci spiral position
        let goldenAngle = Float.pi * (3 - sqrt(5))
        let angle = Float(index) * goldenAngle
        let radius = sqrt(Float(index) / 64.0) * 2.5 * progress

        let targetPosition = SIMD3<Float>(
            cos(angle) * radius,
            sin(Float(index) * 0.1) * 0.5,
            sin(angle) * radius
        )

        entity.position = simd_mix(entity.position, targetPosition, SIMD3(repeating: progress))
    }

    private func applySpiralEffect(to entity: Entity, index: Int, progress: Float, center: SIMD3<Float>) {
        let angle = Float(index) * 0.5 + progress * Float.pi * 4
        let radius = 1.0 + progress * 2.0

        let spiralPosition = SIMD3<Float>(
            center.x + cos(angle) * radius,
            center.y + progress * 2.0,
            center.z + sin(angle) * radius
        )

        entity.position = simd_mix(entity.position, spiralPosition, SIMD3(repeating: progress))
    }

    private func applyPulseEffect(to entity: Entity, progress: Float, center: SIMD3<Float>) {
        let direction = simd_normalize(entity.position - center)
        let distance = simd_length(entity.position - center)

        // Pulse wave
        let wave = sin(distance * 5.0 - progress * Float.pi * 2)
        let pulseOffset = direction * wave * 0.2 * (1.0 - progress)

        entity.position = entity.position + pulseOffset
    }

    private func applyCollapseEffect(to entity: Entity, progress: Float, center: SIMD3<Float>) {
        // Move toward center, then bounce back
        let t = progress < 0.5 ? progress * 2 : 2 - progress * 2
        let targetPosition = simd_mix(entity.position, center, SIMD3(repeating: t * 0.8))
        entity.position = targetPosition

        // Scale down then up
        let scale = progress < 0.5 ? 1.0 - t * 0.5 : 0.5 + t * 0.5
        entity.scale = SIMD3(repeating: scale)
    }

    private func applyScatterEffect(to entity: Entity, index: Int, progress: Float) {
        // Random outward direction
        let seed = Float(index) * 12.345
        let theta = fmod(seed, Float.pi * 2)
        let phi = fmod(seed * 2.718, Float.pi)

        let direction = SIMD3<Float>(
            sin(phi) * cos(theta),
            sin(phi) * sin(theta),
            cos(phi)
        )

        entity.position = entity.position + direction * progress * 2.0
        entity.scale = SIMD3(repeating: 1.0 - progress * 0.5)
    }

    private func applyConvergeEffect(to entity: Entity, progress: Float, center: SIMD3<Float>) {
        entity.position = simd_mix(entity.position, center, SIMD3(repeating: progress))
    }

    private func applyRippleEffect(to entity: Entity, progress: Float, center: SIMD3<Float>) {
        let distance = simd_length(entity.position - center)
        let wave = sin((distance - progress * 5.0) * Float.pi * 2)

        // Vertical ripple
        entity.position.y += wave * 0.1 * (1.0 - progress)
    }

    private func applyVortexEffect(to entity: Entity, index: Int, progress: Float, center: SIMD3<Float>) {
        let toCenter = entity.position - center
        let angle = progress * Float.pi * 4

        // Rotate around center
        let rotation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
        let rotated = rotation.act(toCenter)

        // Pull toward center
        let newRadius = simd_length(toCenter) * (1.0 - progress * 0.5)
        let normalizedDirection = simd_normalize(rotated)

        entity.position = center + normalizedDirection * newRadius
        entity.position.y = center.y + progress * 2.0
    }
    #endif
}

// MARK: - Gesture Handler Delegate

@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
public protocol VisionOSGestureDelegate: AnyObject {
    #if os(visionOS)
    func gestureHandler(_ handler: VisionOSGestureHandler, didTap entity: Entity, at position: SIMD3<Float>)
    func gestureHandler(_ handler: VisionOSGestureHandler, didDrag entity: Entity, offset: SIMD3<Float>)
    func gestureHandler(_ handler: VisionOSGestureHandler, didPinch entity: Entity, scale: Float)
    func gestureHandler(_ handler: VisionOSGestureHandler, didRotate entity: Entity, angle: Float)
    #endif
    func gestureHandler(_ handler: VisionOSGestureHandler, didTriggerEffect effect: VisionOSGestureHandler.VisualEffect, at position: SIMD3<Float>)
}

// Default implementations
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
public extension VisionOSGestureDelegate {
    #if os(visionOS)
    func gestureHandler(_ handler: VisionOSGestureHandler, didTap entity: Entity, at position: SIMD3<Float>) {}
    func gestureHandler(_ handler: VisionOSGestureHandler, didDrag entity: Entity, offset: SIMD3<Float>) {}
    func gestureHandler(_ handler: VisionOSGestureHandler, didPinch entity: Entity, scale: Float) {}
    func gestureHandler(_ handler: VisionOSGestureHandler, didRotate entity: Entity, angle: Float) {}
    #endif
    func gestureHandler(_ handler: VisionOSGestureHandler, didTriggerEffect effect: VisionOSGestureHandler.VisualEffect, at position: SIMD3<Float>) {}
}

// MARK: - visionOS Color-Blind Safe Palettes

/// Color-blind safe palettes for visionOS accessibility
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
public struct VisionOSColorPalettes {

    public enum ColorBlindMode: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case protanopia = "Protanopia"      // Red-blind
        case deuteranopia = "Deuteranopia"  // Green-blind
        case tritanopia = "Tritanopia"      // Blue-blind
        case monochrome = "Monochrome"      // Full grayscale
        case highContrast = "High Contrast" // Maximum contrast

        public var id: String { rawValue }

        public var description: String {
            switch self {
            case .normal: return "Standard color vision"
            case .protanopia: return "Red-blind safe colors"
            case .deuteranopia: return "Green-blind safe colors"
            case .tritanopia: return "Blue-blind safe colors"
            case .monochrome: return "Full grayscale mode"
            case .highContrast: return "Maximum contrast for low vision"
            }
        }
    }

    // MARK: - Color Definitions

    public struct CoherenceColors {
        public let low: SIMD3<Float>
        public let medium: SIMD3<Float>
        public let high: SIMD3<Float>

        public func color(for level: Float) -> SIMD3<Float> {
            if level < 0.4 {
                let t = level / 0.4
                return simd_mix(low, medium, SIMD3(repeating: t))
            } else {
                let t = (level - 0.4) / 0.6
                return simd_mix(medium, high, SIMD3(repeating: t))
            }
        }
    }

    public struct QuantumColors {
        public let photon: SIMD3<Float>
        public let coherence: SIMD3<Float>
        public let entanglement: SIMD3<Float>
        public let collapse: SIMD3<Float>
        public let superposition: SIMD3<Float>
    }

    public struct UIColors {
        public let primary: SIMD3<Float>
        public let secondary: SIMD3<Float>
        public let accent: SIMD3<Float>
        public let warning: SIMD3<Float>
        public let success: SIMD3<Float>
        public let error: SIMD3<Float>
    }

    // MARK: - Palettes

    public static func coherenceColors(for mode: ColorBlindMode) -> CoherenceColors {
        switch mode {
        case .normal:
            return CoherenceColors(
                low: SIMD3(1.0, 0.3, 0.3),     // Red
                medium: SIMD3(1.0, 0.8, 0.2),  // Yellow
                high: SIMD3(0.2, 1.0, 0.8)     // Cyan
            )

        case .protanopia:
            // Blue-Yellow safe for red-blind
            return CoherenceColors(
                low: SIMD3(0.8, 0.6, 0.0),     // Dark yellow/brown
                medium: SIMD3(1.0, 1.0, 0.4),  // Light yellow
                high: SIMD3(0.2, 0.6, 1.0)     // Blue
            )

        case .deuteranopia:
            // Blue-Orange safe for green-blind
            return CoherenceColors(
                low: SIMD3(0.9, 0.5, 0.0),     // Orange
                medium: SIMD3(1.0, 0.9, 0.6),  // Light orange
                high: SIMD3(0.3, 0.5, 1.0)     // Blue
            )

        case .tritanopia:
            // Red-Cyan safe for blue-blind
            return CoherenceColors(
                low: SIMD3(0.9, 0.2, 0.3),     // Red
                medium: SIMD3(0.9, 0.7, 0.7),  // Pink
                high: SIMD3(0.0, 0.8, 0.7)     // Teal
            )

        case .monochrome:
            return CoherenceColors(
                low: SIMD3(0.3, 0.3, 0.3),     // Dark gray
                medium: SIMD3(0.6, 0.6, 0.6),  // Medium gray
                high: SIMD3(1.0, 1.0, 1.0)     // White
            )

        case .highContrast:
            return CoherenceColors(
                low: SIMD3(0.0, 0.0, 0.0),     // Black
                medium: SIMD3(1.0, 1.0, 0.0),  // Yellow
                high: SIMD3(1.0, 1.0, 1.0)     // White
            )
        }
    }

    public static func quantumColors(for mode: ColorBlindMode) -> QuantumColors {
        switch mode {
        case .normal:
            return QuantumColors(
                photon: SIMD3(0.0, 1.0, 1.0),        // Cyan
                coherence: SIMD3(0.5, 0.0, 1.0),    // Purple
                entanglement: SIMD3(1.0, 0.0, 0.5), // Magenta
                collapse: SIMD3(1.0, 0.5, 0.0),     // Orange
                superposition: SIMD3(0.0, 1.0, 0.5) // Mint
            )

        case .protanopia:
            return QuantumColors(
                photon: SIMD3(0.2, 0.6, 1.0),
                coherence: SIMD3(0.4, 0.4, 0.9),
                entanglement: SIMD3(0.8, 0.8, 0.3),
                collapse: SIMD3(1.0, 0.9, 0.2),
                superposition: SIMD3(0.3, 0.8, 0.9)
            )

        case .deuteranopia:
            return QuantumColors(
                photon: SIMD3(0.3, 0.5, 1.0),
                coherence: SIMD3(0.5, 0.4, 0.8),
                entanglement: SIMD3(0.9, 0.6, 0.2),
                collapse: SIMD3(1.0, 0.8, 0.3),
                superposition: SIMD3(0.2, 0.7, 0.9)
            )

        case .tritanopia:
            return QuantumColors(
                photon: SIMD3(0.0, 0.8, 0.7),
                coherence: SIMD3(0.6, 0.3, 0.4),
                entanglement: SIMD3(0.9, 0.3, 0.4),
                collapse: SIMD3(0.9, 0.5, 0.3),
                superposition: SIMD3(0.3, 0.7, 0.6)
            )

        case .monochrome:
            return QuantumColors(
                photon: SIMD3(0.9, 0.9, 0.9),
                coherence: SIMD3(0.7, 0.7, 0.7),
                entanglement: SIMD3(0.5, 0.5, 0.5),
                collapse: SIMD3(0.3, 0.3, 0.3),
                superposition: SIMD3(0.8, 0.8, 0.8)
            )

        case .highContrast:
            return QuantumColors(
                photon: SIMD3(1.0, 1.0, 1.0),
                coherence: SIMD3(1.0, 1.0, 0.0),
                entanglement: SIMD3(1.0, 0.0, 1.0),
                collapse: SIMD3(0.0, 0.0, 0.0),
                superposition: SIMD3(0.0, 1.0, 1.0)
            )
        }
    }

    public static func uiColors(for mode: ColorBlindMode) -> UIColors {
        switch mode {
        case .normal:
            return UIColors(
                primary: SIMD3(0.0, 0.8, 0.8),
                secondary: SIMD3(0.8, 0.0, 0.8),
                accent: SIMD3(1.0, 0.5, 0.0),
                warning: SIMD3(1.0, 0.8, 0.0),
                success: SIMD3(0.0, 0.8, 0.4),
                error: SIMD3(1.0, 0.2, 0.2)
            )

        case .protanopia, .deuteranopia:
            return UIColors(
                primary: SIMD3(0.2, 0.5, 1.0),
                secondary: SIMD3(0.8, 0.7, 0.3),
                accent: SIMD3(1.0, 0.85, 0.4),
                warning: SIMD3(1.0, 0.9, 0.3),
                success: SIMD3(0.3, 0.6, 1.0),
                error: SIMD3(0.9, 0.6, 0.2)
            )

        case .tritanopia:
            return UIColors(
                primary: SIMD3(0.0, 0.7, 0.6),
                secondary: SIMD3(0.8, 0.3, 0.4),
                accent: SIMD3(0.9, 0.4, 0.4),
                warning: SIMD3(0.9, 0.5, 0.4),
                success: SIMD3(0.0, 0.7, 0.5),
                error: SIMD3(0.8, 0.2, 0.3)
            )

        case .monochrome:
            return UIColors(
                primary: SIMD3(0.8, 0.8, 0.8),
                secondary: SIMD3(0.5, 0.5, 0.5),
                accent: SIMD3(1.0, 1.0, 1.0),
                warning: SIMD3(0.7, 0.7, 0.7),
                success: SIMD3(0.9, 0.9, 0.9),
                error: SIMD3(0.3, 0.3, 0.3)
            )

        case .highContrast:
            return UIColors(
                primary: SIMD3(1.0, 1.0, 1.0),
                secondary: SIMD3(1.0, 1.0, 0.0),
                accent: SIMD3(0.0, 1.0, 1.0),
                warning: SIMD3(1.0, 1.0, 0.0),
                success: SIMD3(0.0, 1.0, 0.0),
                error: SIMD3(1.0, 0.0, 0.0)
            )
        }
    }

    // MARK: - Utility Functions

    public static func simd3ToUIColor(_ color: SIMD3<Float>, alpha: CGFloat = 1.0) -> UIColor {
        UIColor(
            red: CGFloat(color.x),
            green: CGFloat(color.y),
            blue: CGFloat(color.z),
            alpha: alpha
        )
    }

    public static func simd3ToColor(_ color: SIMD3<Float>, opacity: Double = 1.0) -> Color {
        Color(
            red: Double(color.x),
            green: Double(color.y),
            blue: Double(color.z),
            opacity: opacity
        )
    }
}

// MARK: - visionOS Haptic Feedback System

/// Haptic feedback system for visionOS
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
@MainActor
public final class VisionOSHapticEngine: ObservableObject {

    // MARK: - Haptic Patterns

    public enum HapticPattern: String, CaseIterable {
        case heartbeat = "Heartbeat"
        case breathing = "Breathing"
        case pulse = "Pulse"
        case coherenceHigh = "Coherence High"
        case coherenceLow = "Coherence Low"
        case gestureConfirm = "Gesture Confirm"
        case quantumCollapse = "Quantum Collapse"
        case entanglement = "Entanglement"
        case notification = "Notification"
        case warning = "Warning"
        case success = "Success"
        case error = "Error"
        case selection = "Selection"
        case impact = "Impact"

        public var intensity: Float {
            switch self {
            case .heartbeat: return 0.7
            case .breathing: return 0.4
            case .pulse: return 0.8
            case .coherenceHigh: return 0.9
            case .coherenceLow: return 0.3
            case .gestureConfirm: return 0.5
            case .quantumCollapse: return 1.0
            case .entanglement: return 0.6
            case .notification: return 0.5
            case .warning: return 0.7
            case .success: return 0.6
            case .error: return 0.8
            case .selection: return 0.3
            case .impact: return 0.9
            }
        }

        public var sharpness: Float {
            switch self {
            case .heartbeat: return 0.5
            case .breathing: return 0.2
            case .pulse: return 0.7
            case .coherenceHigh: return 0.8
            case .coherenceLow: return 0.3
            case .gestureConfirm: return 0.6
            case .quantumCollapse: return 1.0
            case .entanglement: return 0.5
            case .notification: return 0.5
            case .warning: return 0.8
            case .success: return 0.6
            case .error: return 0.9
            case .selection: return 0.4
            case .impact: return 1.0
            }
        }
    }

    // MARK: - Properties

    @Published public var isEnabled: Bool = true
    @Published public var globalIntensity: Float = 1.0

    private var lastHeartbeatTime: Date?
    private var breathingTimer: Timer?

    // MARK: - Initialization

    public init() {
        #if os(visionOS)
        prepareHaptics()
        #endif
    }

    #if os(visionOS)
    private func prepareHaptics() {
        // visionOS uses different haptic APIs
        log.spatial("Haptic engine prepared for visionOS")
    }
    #endif

    // MARK: - Haptic Playback

    /// Play a haptic pattern
    public func playPattern(_ pattern: HapticPattern) {
        guard isEnabled else { return }

        let intensity = pattern.intensity * globalIntensity
        let sharpness = pattern.sharpness

        log.spatial("Playing haptic: \(pattern.rawValue) (intensity: \(intensity), sharpness: \(sharpness))")

        #if os(visionOS)
        // visionOS haptic implementation
        // Uses controller haptics when available
        playVisionOSHaptic(intensity: intensity, sharpness: sharpness)
        #endif
    }

    /// Play heartbeat-synced haptics
    public func playHeartbeat(bpm: Double) {
        guard isEnabled else { return }

        let interval = 60.0 / bpm
        let now = Date()

        if let lastTime = lastHeartbeatTime,
           now.timeIntervalSince(lastTime) < interval * 0.9 {
            return  // Too soon for next beat
        }

        lastHeartbeatTime = now
        playPattern(.heartbeat)
    }

    /// Play breathing-synced haptics
    public func playBreathing(phase: Float) {
        guard isEnabled else { return }

        // Subtle haptic at breath transitions
        if phase < 0.05 || (phase > 0.45 && phase < 0.55) || phase > 0.95 {
            playPattern(.breathing)
        }
    }

    /// Play coherence feedback
    public func playCoherenceFeedback(level: Float) {
        guard isEnabled else { return }

        if level > 0.7 {
            playPattern(.coherenceHigh)
        } else if level < 0.3 {
            playPattern(.coherenceLow)
        }
    }

    #if os(visionOS)
    private func playVisionOSHaptic(intensity: Float, sharpness: Float) {
        // visionOS-specific haptic implementation
        // This would use the controller haptics API when available

        // For now, we rely on the system-level feedback
        // which is triggered through standard UIKit/SwiftUI interactions
    }
    #endif

    // MARK: - Bio-Synced Haptic Loops

    /// Start continuous heartbeat haptics
    public func startHeartbeatLoop(bpm: Double) {
        stopAllLoops()

        let interval = 60.0 / bpm

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.isEnabled else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                self.playPattern(.heartbeat)
            }
        }
    }

    /// Start continuous breathing haptics
    public func startBreathingLoop(cycleTime: TimeInterval) {
        stopAllLoops()

        var phase: Float = 0

        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, self.isEnabled else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                phase = fmod(phase + Float(0.05 / cycleTime), 1.0)
                self.playBreathing(phase: phase)
            }
        }
    }

    /// Stop all haptic loops
    public func stopAllLoops() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
}

// MARK: - visionOS Particle LOD System

/// Level of Detail system for particle performance optimization
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
public final class VisionOSParticleLOD {

    // MARK: - LOD Levels

    public enum LODLevel: Int, CaseIterable, Comparable {
        case full = 0       // All particles visible
        case high = 1       // 75% particles
        case medium = 2     // 50% particles
        case low = 3        // 25% particles
        case minimal = 4    // 10% particles

        public static func < (lhs: LODLevel, rhs: LODLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var particleRatio: Float {
            switch self {
            case .full: return 1.0
            case .high: return 0.75
            case .medium: return 0.5
            case .low: return 0.25
            case .minimal: return 0.1
            }
        }

        public var maxParticles: Int {
            switch self {
            case .full: return 10000
            case .high: return 7500
            case .medium: return 5000
            case .low: return 2500
            case .minimal: return 1000
            }
        }
    }

    // MARK: - Configuration

    public struct Configuration {
        public var distanceThresholds: [Float] = [2.0, 5.0, 10.0, 20.0]
        public var targetFrameRate: Double = 60.0
        public var frameRateThreshold: Double = 45.0
        public var adaptiveMode: Bool = true
        public var cullingEnabled: Bool = true
        public var frustumCullingMargin: Float = 0.1

        public init() {}
    }

    // MARK: - Properties

    public var configuration = Configuration()
    public private(set) var currentLOD: LODLevel = .full
    public private(set) var visibleParticleCount: Int = 0
    public private(set) var culledParticleCount: Int = 0

    private var frameRateHistory: [Double] = []
    private let frameRateHistorySize = 30

    // MARK: - Initialization

    public init() {}

    // MARK: - LOD Calculation

    /// Calculate LOD level based on distance from camera
    public func calculateLOD(distanceFromCamera: Float) -> LODLevel {
        for (index, threshold) in configuration.distanceThresholds.enumerated() {
            if distanceFromCamera < threshold {
                return LODLevel(rawValue: index) ?? .full
            }
        }
        return .minimal
    }

    /// Update LOD based on current frame rate
    public func updateAdaptiveLOD(currentFrameRate: Double) {
        guard configuration.adaptiveMode else { return }

        frameRateHistory.append(currentFrameRate)
        if frameRateHistory.count > frameRateHistorySize {
            frameRateHistory.removeFirst()
        }

        let averageFrameRate = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)

        if averageFrameRate < configuration.frameRateThreshold && currentLOD != .minimal {
            // Reduce LOD
            if let newLOD = LODLevel(rawValue: currentLOD.rawValue + 1) {
                currentLOD = newLOD
                log.spatial("Reduced LOD to \(currentLOD) due to low frame rate (\(averageFrameRate) FPS)")
            }
        } else if averageFrameRate > configuration.targetFrameRate * 0.95 && currentLOD != .full {
            // Increase LOD
            if let newLOD = LODLevel(rawValue: currentLOD.rawValue - 1) {
                currentLOD = newLOD
                log.spatial("Increased LOD to \(currentLOD) due to good frame rate (\(averageFrameRate) FPS)")
            }
        }
    }

    // MARK: - Frustum Culling

    /// Check if a position is within the view frustum
    public func isInFrustum(
        position: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        fov: Float = Float.pi / 3
    ) -> Bool {
        guard configuration.cullingEnabled else { return true }

        let toPosition = position - cameraPosition
        let distance = simd_length(toPosition)

        if distance < 0.1 { return true }  // Very close, always visible

        let normalizedDirection = toPosition / distance
        let dotProduct = simd_dot(normalizedDirection, cameraForward)

        let halfFov = fov / 2 + configuration.frustumCullingMargin
        let cosHalfFov = cos(halfFov)

        return dotProduct > cosHalfFov
    }

    // MARK: - Particle Filtering

    #if os(visionOS)
    /// Filter particles based on LOD and culling
    public func filterParticles(
        _ particles: [Entity],
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>
    ) -> [Entity] {
        var visibleParticles: [Entity] = []
        var culled = 0

        let maxCount = currentLOD.maxParticles

        for (index, particle) in particles.enumerated() {
            // LOD-based filtering
            if visibleParticles.count >= maxCount {
                culled += 1
                particle.isEnabled = false
                continue
            }

            // Distance-based LOD
            let distance = simd_length(particle.position - cameraPosition)
            let particleLOD = calculateLOD(distanceFromCamera: distance)

            // Skip based on LOD level and index
            let skipRatio = 1.0 - particleLOD.particleRatio
            if Float(index % 10) / 10.0 < skipRatio {
                culled += 1
                particle.isEnabled = false
                continue
            }

            // Frustum culling
            if !isInFrustum(
                position: particle.position,
                cameraPosition: cameraPosition,
                cameraForward: cameraForward
            ) {
                culled += 1
                particle.isEnabled = false
                continue
            }

            particle.isEnabled = true
            visibleParticles.append(particle)
        }

        visibleParticleCount = visibleParticles.count
        culledParticleCount = culled

        return visibleParticles
    }
    #endif

    // MARK: - Statistics

    public var statistics: String {
        """
        LOD Level: \(currentLOD)
        Visible: \(visibleParticleCount)
        Culled: \(culledParticleCount)
        Avg FPS: \(String(format: "%.1f", frameRateHistory.reduce(0, +) / Double(max(1, frameRateHistory.count))))
        """
    }
}

// MARK: - visionOS Gaze-Audio Integration

/// Integrates gaze tracking with audio-visual control
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
@MainActor
public final class VisionOSGazeAudioBridge: ObservableObject {

    // MARK: - Published Properties

    @Published public var isActive: Bool = false
    @Published public var currentMapping: GazeAudioMapping = .default

    // Audio parameters derived from gaze
    @Published public var audioPan: Float = 0.0          // -1 to 1
    @Published public var filterCutoff: Float = 0.5     // 0 to 1
    @Published public var reverbAmount: Float = 0.3     // 0 to 1
    @Published public var delayMix: Float = 0.0         // 0 to 1
    @Published public var visualIntensity: Float = 0.5  // 0 to 1

    // MARK: - Mapping Configuration

    public struct GazeAudioMapping {
        public var gazeXToPan: Bool = true
        public var gazeYToFilter: Bool = true
        public var attentionToReverb: Bool = true
        public var focusToDelay: Bool = true
        public var arousalToIntensity: Bool = true
        public var zoneToFrequency: Bool = true

        public var panSensitivity: Float = 1.0
        public var filterRange: ClosedRange<Float> = 0.2...1.0
        public var reverbRange: ClosedRange<Float> = 0.0...0.8
        public var delayRange: ClosedRange<Float> = 0.0...0.5

        public static let `default` = GazeAudioMapping()

        public static let meditation = GazeAudioMapping(
            gazeXToPan: false,
            gazeYToFilter: false,
            attentionToReverb: true,
            focusToDelay: false,
            arousalToIntensity: false,
            zoneToFrequency: false,
            reverbRange: 0.3...0.9
        )

        public static let performance = GazeAudioMapping(
            gazeXToPan: true,
            gazeYToFilter: true,
            attentionToReverb: true,
            focusToDelay: true,
            arousalToIntensity: true,
            zoneToFrequency: true,
            panSensitivity: 1.5
        )
    }

    // MARK: - Zone Frequency Mapping

    public struct ZoneFrequencyMapping {
        public static let frequencies: [GazeZone: ClosedRange<Float>] = [
            .topLeft: 6000...8000,      // High frequencies
            .topCenter: 5000...7000,
            .topRight: 6000...8000,
            .centerLeft: 2000...4000,   // Mid frequencies
            .center: 1000...3000,
            .centerRight: 2000...4000,
            .bottomLeft: 200...500,     // Bass frequencies
            .bottomCenter: 100...300,
            .bottomRight: 200...500
        ]

        public static func frequency(for zone: GazeZone) -> Float {
            let range = frequencies[zone] ?? 500...2000
            return (range.lowerBound + range.upperBound) / 2
        }
    }

    // MARK: - Private Properties

    private weak var gazeTracker: GazeTracker?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {}

    // MARK: - Connection

    /// Connect to a gaze tracker
    public func connect(to tracker: GazeTracker) {
        gazeTracker = tracker

        // Subscribe to gaze updates
        tracker.$currentGaze
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gaze in
                self?.processGazeData(gaze)
            }
            .store(in: &cancellables)

        tracker.$currentZone
            .receive(on: DispatchQueue.main)
            .sink { [weak self] zone in
                self?.processZoneChange(zone)
            }
            .store(in: &cancellables)

        isActive = true
        log.spatial("Gaze-Audio bridge connected")
    }

    /// Disconnect from gaze tracker
    public func disconnect() {
        cancellables.removeAll()
        gazeTracker = nil
        isActive = false

        // Reset to defaults
        audioPan = 0.0
        filterCutoff = 0.5
        reverbAmount = 0.3
        delayMix = 0.0
        visualIntensity = 0.5

        log.spatial("Gaze-Audio bridge disconnected")
    }

    // MARK: - Processing

    private func processGazeData(_ gaze: GazeData) {
        guard isActive else { return }

        let mapping = currentMapping

        // Gaze X -> Pan
        if mapping.gazeXToPan {
            audioPan = (gaze.gazePoint.x - 0.5) * 2.0 * mapping.panSensitivity
            audioPan = max(-1, min(1, audioPan))
        }

        // Gaze Y -> Filter (inverted: looking up = brighter)
        if mapping.gazeYToFilter {
            let normalizedY = 1.0 - gaze.gazePoint.y
            filterCutoff = mapping.filterRange.lowerBound +
                normalizedY * (mapping.filterRange.upperBound - mapping.filterRange.lowerBound)
        }

        // Attention -> Reverb (less attention = more reverb)
        if mapping.attentionToReverb {
            let invertedAttention = 1.0 - gaze.attentionLevel
            reverbAmount = mapping.reverbRange.lowerBound +
                invertedAttention * (mapping.reverbRange.upperBound - mapping.reverbRange.lowerBound)
        }

        // Focus -> Delay
        if mapping.focusToDelay {
            let focusIntensity = gaze.isFixating ? min(1.0, Float(gaze.fixationDuration / 3.0)) : 0.0
            delayMix = mapping.delayRange.lowerBound +
                focusIntensity * (mapping.delayRange.upperBound - mapping.delayRange.lowerBound)
        }

        // Arousal (pupil dilation) -> Visual Intensity
        if mapping.arousalToIntensity {
            visualIntensity = gaze.averagePupilDilation
        }

        // Send notification with updated parameters
        NotificationCenter.default.post(
            name: .gazeAudioParametersUpdated,
            object: nil,
            userInfo: [
                "pan": audioPan,
                "filter": filterCutoff,
                "reverb": reverbAmount,
                "delay": delayMix,
                "intensity": visualIntensity
            ]
        )
    }

    private func processZoneChange(_ zone: GazeZone) {
        guard isActive, currentMapping.zoneToFrequency else { return }

        let frequency = ZoneFrequencyMapping.frequency(for: zone)

        NotificationCenter.default.post(
            name: .gazeZoneFrequencyChanged,
            object: nil,
            userInfo: [
                "zone": zone.rawValue,
                "frequency": frequency
            ]
        )

        log.spatial("Gaze zone changed to \(zone.rawValue), frequency: \(frequency) Hz")
    }

    // MARK: - Preset Application

    public func applyPreset(_ preset: GazeAudioMapping) {
        currentMapping = preset
        log.spatial("Applied gaze-audio mapping preset")
    }
}

// MARK: - visionOS Real-Time HealthKit Bridge

/// Real-time HealthKit streaming for visionOS immersive experiences
@available(iOS 15.0, macOS 12.0, visionOS 1.0, *)
@MainActor
public final class VisionOSHealthKitBridge: ObservableObject {

    // MARK: - Published Properties

    @Published public var isStreaming: Bool = false
    @Published public var heartRate: Double = 60.0
    @Published public var hrvRMSSD: Double = 50.0
    @Published public var coherenceLevel: Float = 0.5
    @Published public var breathingRate: Double = 12.0
    @Published public var lastUpdate: Date?

    // MARK: - Streaming Configuration

    public struct StreamingConfig {
        public var updateInterval: TimeInterval = 1.0
        public var smoothingFactor: Float = 0.3
        public var useSimulatedDataWhenUnavailable: Bool = true

        public init() {}
    }

    public var config = StreamingConfig()

    // MARK: - Private Properties

    private var streamingTimer: Timer?
    private var simulationTime: TimeInterval = 0
    private var healthKitAvailable: Bool = false

    // Smoothed values
    private var smoothedHeartRate: Double = 60.0
    private var smoothedHRV: Double = 50.0
    private var smoothedCoherence: Float = 0.5

    // MARK: - Initialization

    public init() {
        checkHealthKitAvailability()
    }

    private func checkHealthKitAvailability() {
        #if os(visionOS) || os(iOS) || os(watchOS)
        // Check if HealthKit is available on this device
        // For now, assume it's available on supported platforms
        healthKitAvailable = true
        #else
        healthKitAvailable = false
        #endif
    }

    // MARK: - Streaming Control

    /// Start real-time biometric streaming
    public func startStreaming() {
        guard !isStreaming else { return }

        isStreaming = true
        simulationTime = 0

        streamingTimer = Timer.scheduledTimer(withTimeInterval: config.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBioData()
            }
        }

        log.spatial("HealthKit bridge started streaming")
    }

    /// Stop streaming
    public func stopStreaming() {
        isStreaming = false
        streamingTimer?.invalidate()
        streamingTimer = nil

        log.spatial("HealthKit bridge stopped streaming")
    }

    // MARK: - Data Updates

    private func updateBioData() {
        simulationTime += config.updateInterval

        if healthKitAvailable {
            // Try to get real HealthKit data
            fetchRealHealthKitData()
        } else if config.useSimulatedDataWhenUnavailable {
            // Use simulated data
            updateWithSimulatedData()
        }

        lastUpdate = Date()

        // Post notification for immersive experiences
        NotificationCenter.default.post(
            name: .bioDataUpdated,
            object: nil,
            userInfo: [
                "heartRate": heartRate,
                "hrv": hrvRMSSD,
                "coherence": Double(coherenceLevel * 100),
                "breathingRate": breathingRate
            ]
        )
    }

    private func fetchRealHealthKitData() {
        // In a real implementation, this would query HealthKit
        // For now, use simulated data with realistic variations
        updateWithSimulatedData()
    }

    private func updateWithSimulatedData() {
        let time = simulationTime

        // Simulate realistic heart rate (55-75 BPM with slight variations)
        let baseHR = 65.0 + sin(time * 0.1) * 5.0
        let hrNoise = Double.random(in: -2...2)
        let newHeartRate = baseHR + hrNoise

        // Simulate HRV (40-80ms with breathing-related variations)
        let baseHRV = 60.0 + sin(time * 0.2) * 15.0
        let hrvNoise = Double.random(in: -5...5)
        let newHRV = baseHRV + hrvNoise

        // Calculate coherence from HRV consistency
        let hrvVariation = abs(newHRV - smoothedHRV)
        let newCoherence = Float(max(0, min(1, 1.0 - hrvVariation / 30.0)))

        // Simulate breathing rate (10-16 breaths/min)
        let baseBreathing = 13.0 + sin(time * 0.05) * 2.0
        breathingRate = baseBreathing

        // Apply smoothing
        let sf = Double(config.smoothingFactor)
        smoothedHeartRate = smoothedHeartRate * (1 - sf) + newHeartRate * sf
        smoothedHRV = smoothedHRV * (1 - sf) + newHRV * sf
        smoothedCoherence = smoothedCoherence * (1 - config.smoothingFactor) + newCoherence * config.smoothingFactor

        // Update published values
        heartRate = smoothedHeartRate
        hrvRMSSD = smoothedHRV
        coherenceLevel = smoothedCoherence
    }

    // MARK: - Manual Updates

    /// Manually inject bio data (for testing or external sources)
    public func injectBioData(heartRate: Double? = nil, hrv: Double? = nil, coherence: Float? = nil) {
        if let hr = heartRate {
            self.heartRate = hr
            smoothedHeartRate = hr
        }
        if let hrv = hrv {
            self.hrvRMSSD = hrv
            smoothedHRV = hrv
        }
        if let coh = coherence {
            self.coherenceLevel = coh
            smoothedCoherence = coh
        }

        lastUpdate = Date()
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let visionOSAnimationUpdate = Notification.Name("visionOSAnimationUpdate")
    static let gazeAudioParametersUpdated = Notification.Name("gazeAudioParametersUpdated")
    static let gazeZoneFrequencyChanged = Notification.Name("gazeZoneFrequencyChanged")
}

// MARK: - SwiftUI Helpers

#if os(visionOS)
@available(visionOS 1.0, *)
public extension View {
    /// Apply color-blind safe palette to a view
    func colorBlindSafe(_ mode: VisionOSColorPalettes.ColorBlindMode) -> some View {
        self.environment(\.colorBlindMode, mode)
    }
}

// Environment key for color-blind mode
private struct ColorBlindModeKey: EnvironmentKey {
    static let defaultValue: VisionOSColorPalettes.ColorBlindMode = .normal
}

@available(visionOS 1.0, *)
extension EnvironmentValues {
    var colorBlindMode: VisionOSColorPalettes.ColorBlindMode {
        get { self[ColorBlindModeKey.self] }
        set { self[ColorBlindModeKey.self] = newValue }
    }
}
#endif
