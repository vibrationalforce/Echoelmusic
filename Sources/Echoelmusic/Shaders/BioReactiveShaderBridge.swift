// BioReactiveShaderBridge.swift
// Echoelmusic - SwiftUI Bridge for Bio-Reactive Metal Shaders
//
// Provides SwiftUI view modifiers for GPU-accelerated bio-reactive effects
// Target latency: < 20ms from sensor to visual feedback
//
// "I'm learnding!" - Ralph Wiggum, Shader Engineer
//
// Created 2026-02-04
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI

#if canImport(Metal)
import Metal
#endif

// MARK: - Shader Library Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
extension ShaderLibrary {

    /// Bio-reactive aura glow shader
    /// - Parameters:
    ///   - time: Animation time in seconds
    ///   - coherence: HRV coherence level (0-1)
    ///   - heartRate: Current heart rate in BPM
    ///   - breathPhase: Breathing cycle phase (0-1)
    ///   - confidence: AI prediction confidence (0-1)
    ///   - glowRadius: Glow radius in pixels
    static func bioReactiveAura(
        time: Float,
        coherence: Float,
        heartRate: Float,
        breathPhase: Float,
        confidence: Float,
        glowRadius: Float
    ) -> Shader {
        ShaderLibrary.default.bioReactiveAura(
            .float(time),
            .float(coherence),
            .float(heartRate),
            .float(breathPhase),
            .float(confidence),
            .float(glowRadius)
        )
    }

    /// Coherence ring pulse shader
    static func coherenceRing(
        time: Float,
        coherence: Float,
        heartRate: Float,
        ringWidth: Float = 0.02
    ) -> Shader {
        ShaderLibrary.default.coherenceRing(
            .float(time),
            .float(coherence),
            .float(heartRate),
            .float(ringWidth)
        )
    }

    /// Quantum field visualization shader
    static func quantumField(
        time: Float,
        coherence: Float,
        entanglement: Float = 0.0
    ) -> Shader {
        ShaderLibrary.default.quantumField(
            .float(time),
            .float(coherence),
            .float(entanglement)
        )
    }

    /// Breathing guide circle shader
    static func breathingGuide(
        breathPhase: Float,
        targetRate: Float = 6.0
    ) -> Shader {
        ShaderLibrary.default.breathingGuide(
            .float(breathPhase),
            .float(targetRate)
        )
    }

    /// Coherence particles shader
    static func coherenceParticles(
        time: Float,
        coherence: Float,
        particleCount: Int = 50
    ) -> Shader {
        ShaderLibrary.default.coherenceParticles(
            .float(time),
            .float(coherence),
            .int(Int32(particleCount))
        )
    }
}

// MARK: - Bio-Reactive Aura Modifier

/// View modifier that applies bio-reactive aura effect
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct BioReactiveAuraModifier: ViewModifier {
    @ObservedObject var healthKit: UnifiedHealthKitEngine

    let glowRadius: CGFloat
    let showParticles: Bool
    let showRing: Bool

    @State private var animationTime: Float = 0
    @State private var displayLink: Timer?

    public init(
        healthKit: UnifiedHealthKitEngine = .shared,
        glowRadius: CGFloat = 50,
        showParticles: Bool = true,
        showRing: Bool = true
    ) {
        self.healthKit = healthKit
        self.glowRadius = glowRadius
        self.showParticles = showParticles
        self.showRing = showRing
    }

    public func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSinceReferenceDate)

            content
                // Main aura glow
                .layerEffect(
                    ShaderLibrary.bioReactiveAura(
                        time: time,
                        coherence: Float(healthKit.coherence),
                        heartRate: Float(healthKit.heartRate),
                        breathPhase: Float(healthKit.respiratoryData.breathPhase),
                        confidence: 0.8,  // TODO: Get from WorldModel
                        glowRadius: Float(glowRadius)
                    ),
                    maxSampleOffset: CGSize(width: glowRadius, height: glowRadius)
                )
                // Optional heartbeat ring
                .layerEffect(
                    ShaderLibrary.coherenceRing(
                        time: time,
                        coherence: Float(healthKit.coherence),
                        heartRate: Float(healthKit.heartRate),
                        ringWidth: 0.015
                    ),
                    maxSampleOffset: .zero,
                    isEnabled: showRing
                )
                // Optional floating particles
                .layerEffect(
                    ShaderLibrary.coherenceParticles(
                        time: time,
                        coherence: Float(healthKit.coherence),
                        particleCount: 30
                    ),
                    maxSampleOffset: .zero,
                    isEnabled: showParticles
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bio-reactive aura visualization")
        .accessibilityValue("Coherence: \(Int(healthKit.coherence * 100))%")
    }
}

// MARK: - Breathing Guide Modifier

/// View modifier that shows breathing guide overlay
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct BreathingGuideModifier: ViewModifier {
    @ObservedObject var healthKit: UnifiedHealthKitEngine

    let targetBreathRate: Double
    let opacity: Double

    public init(
        healthKit: UnifiedHealthKitEngine = .shared,
        targetBreathRate: Double = 6.0,  // 6 BPM for coherence
        opacity: Double = 0.5
    ) {
        self.healthKit = healthKit
        self.targetBreathRate = targetBreathRate
        self.opacity = opacity
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation) { _ in
                    Rectangle()
                        .fill(.clear)
                        .layerEffect(
                            ShaderLibrary.breathingGuide(
                                breathPhase: Float(healthKit.respiratoryData.breathPhase),
                                targetRate: Float(targetBreathRate)
                            ),
                            maxSampleOffset: .zero
                        )
                        .opacity(opacity)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Breathing guide")
            .accessibilityValue(healthKit.respiratoryData.breathPhase < 0.5 ? "Inhale" : "Exhale")
    }
}

// MARK: - Quantum Field Modifier

/// View modifier for quantum field visualization (multiplayer entanglement)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct QuantumFieldModifier: ViewModifier {
    @ObservedObject var healthKit: UnifiedHealthKitEngine

    let entanglement: Double
    let intensity: Double

    public init(
        healthKit: UnifiedHealthKitEngine = .shared,
        entanglement: Double = 0.0,
        intensity: Double = 0.3
    ) {
        self.healthKit = healthKit
        self.entanglement = entanglement
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSinceReferenceDate)

            content
                .layerEffect(
                    ShaderLibrary.quantumField(
                        time: time,
                        coherence: Float(healthKit.coherence * intensity),
                        entanglement: Float(entanglement)
                    ),
                    maxSampleOffset: .zero
                )
        }
    }
}

// MARK: - View Extensions

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
extension View {

    /// Apply bio-reactive aura glow effect
    /// - Parameters:
    ///   - healthKit: HealthKit engine for biometric data
    ///   - glowRadius: Glow effect radius
    ///   - showParticles: Whether to show floating particles
    ///   - showRing: Whether to show heartbeat ring
    public func bioReactiveAura(
        healthKit: UnifiedHealthKitEngine = .shared,
        glowRadius: CGFloat = 50,
        showParticles: Bool = true,
        showRing: Bool = true
    ) -> some View {
        modifier(BioReactiveAuraModifier(
            healthKit: healthKit,
            glowRadius: glowRadius,
            showParticles: showParticles,
            showRing: showRing
        ))
    }

    /// Show breathing guide overlay
    /// - Parameters:
    ///   - healthKit: HealthKit engine for breath phase
    ///   - targetRate: Target breathing rate (6 BPM recommended)
    ///   - opacity: Guide opacity
    public func breathingGuide(
        healthKit: UnifiedHealthKitEngine = .shared,
        targetRate: Double = 6.0,
        opacity: Double = 0.5
    ) -> some View {
        modifier(BreathingGuideModifier(
            healthKit: healthKit,
            targetBreathRate: targetRate,
            opacity: opacity
        ))
    }

    /// Apply quantum field visualization
    /// - Parameters:
    ///   - healthKit: HealthKit engine
    ///   - entanglement: Multiplayer entanglement level (0-1)
    ///   - intensity: Effect intensity
    public func quantumField(
        healthKit: UnifiedHealthKitEngine = .shared,
        entanglement: Double = 0.0,
        intensity: Double = 0.3
    ) -> some View {
        modifier(QuantumFieldModifier(
            healthKit: healthKit,
            entanglement: entanglement,
            intensity: intensity
        ))
    }
}

// MARK: - Fallback for older OS versions

/// Fallback aura implementation for iOS < 17.0
public struct FallbackAuraModifier: ViewModifier {
    @ObservedObject var healthKit: UnifiedHealthKitEngine
    let glowRadius: CGFloat

    @State private var pulseScale: CGFloat = 1.0

    public func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(auraColor, lineWidth: 3)
                    .blur(radius: glowRadius / 4)
                    .scaleEffect(pulseScale)
                    .opacity(0.6)
            }
            .onReceive(Timer.publish(every: 60.0 / max(healthKit.heartRate, 60), on: .main, in: .common).autoconnect()) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    pulseScale = 1.05
                }
                withAnimation(.easeIn(duration: 0.25).delay(0.15)) {
                    pulseScale = 1.0
                }
            }
    }

    private var auraColor: Color {
        switch healthKit.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
}

extension View {
    /// Cross-platform aura effect with automatic fallback
    @ViewBuilder
    public func adaptiveAura(
        healthKit: UnifiedHealthKitEngine = .shared,
        glowRadius: CGFloat = 50
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *) {
            self.bioReactiveAura(
                healthKit: healthKit,
                glowRadius: glowRadius,
                showParticles: true,
                showRing: true
            )
        } else {
            self.modifier(FallbackAuraModifier(healthKit: healthKit, glowRadius: glowRadius))
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Bio-Reactive Aura") {
    if #available(iOS 17.0, *) {
        VStack(spacing: 30) {
            // Coherence Orb with Aura
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 150, height: 150)
                .overlay {
                    VStack {
                        Text("72")
                            .font(.system(size: 48, weight: .bold))
                        Text("Coherence")
                            .font(.caption)
                    }
                }
                .bioReactiveAura(glowRadius: 60)

            // Card with Quantum Field
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(height: 120)
                .overlay {
                    Text("Bio-Reactive Session")
                        .font(.headline)
                }
                .quantumField(intensity: 0.2)
                .padding(.horizontal)

            // Breathing Guide
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .frame(height: 200)
                .breathingGuide(opacity: 0.7)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
