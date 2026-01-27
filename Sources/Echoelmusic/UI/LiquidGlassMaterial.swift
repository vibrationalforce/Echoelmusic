// LiquidGlassMaterial.swift
// Echoelmusic
//
// Next-Gen "Liquid Glass" UI Material System
// Prepared for iOS 18+ / visionOS 2+ advanced material APIs
//
// Created: 2026-01-25
// Phase 10000 ULTRA MODE - Next-Gen UI

import SwiftUI

// MARK: - Liquid Glass Configuration

/// Configuration for liquid glass material effects
public struct LiquidGlassConfiguration: Sendable, Equatable {
    /// Context for the material (affects blur and refraction)
    public enum Context: String, Sendable {
        case interactive       // High responsiveness, moderate blur
        case ambient           // Subtle, background element
        case prominent         // Strong effect, foreground element
        case immersive         // Full spatial effect (visionOS)
    }

    /// Refraction intensity (0.0 - 1.0)
    public var refractionIntensity: Double

    /// Blur radius
    public var blurRadius: Double

    /// Tint color
    public var tintColor: Color

    /// Tint opacity
    public var tintOpacity: Double

    /// Shadow configuration
    public var shadowRadius: Double
    public var shadowOpacity: Double

    /// Whether to use hardware-accelerated ray tracing (future M-series)
    public var useHardwareRayTracing: Bool

    /// Animation response time
    public var animationResponse: Double

    public init(
        refractionIntensity: Double = 0.3,
        blurRadius: Double = 20,
        tintColor: Color = .white,
        tintOpacity: Double = 0.1,
        shadowRadius: Double = 10,
        shadowOpacity: Double = 0.2,
        useHardwareRayTracing: Bool = true,
        animationResponse: Double = 0.3
    ) {
        self.refractionIntensity = refractionIntensity
        self.blurRadius = blurRadius
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.useHardwareRayTracing = useHardwareRayTracing
        self.animationResponse = animationResponse
    }

    // MARK: - Presets

    public static let interactive = LiquidGlassConfiguration(
        refractionIntensity: 0.4,
        blurRadius: 25,
        tintOpacity: 0.15,
        animationResponse: 0.2
    )

    public static let ambient = LiquidGlassConfiguration(
        refractionIntensity: 0.2,
        blurRadius: 30,
        tintOpacity: 0.08,
        animationResponse: 0.5
    )

    public static let prominent = LiquidGlassConfiguration(
        refractionIntensity: 0.5,
        blurRadius: 20,
        tintOpacity: 0.2,
        shadowRadius: 15,
        animationResponse: 0.25
    )

    public static let immersive = LiquidGlassConfiguration(
        refractionIntensity: 0.6,
        blurRadius: 35,
        tintOpacity: 0.12,
        useHardwareRayTracing: true,
        animationResponse: 0.15
    )

    /// Bio-reactive configuration that responds to coherence
    public static func bioReactive(coherence: Double) -> LiquidGlassConfiguration {
        LiquidGlassConfiguration(
            refractionIntensity: 0.3 + (coherence * 0.3),
            blurRadius: 20 + (coherence * 15),
            tintColor: coherenceColor(coherence),
            tintOpacity: 0.1 + (coherence * 0.1),
            shadowRadius: 10 + (coherence * 10),
            animationResponse: 0.3 - (coherence * 0.15)
        )
    }

    private static func coherenceColor(_ coherence: Double) -> Color {
        if coherence > 0.7 {
            return Color.green
        } else if coherence > 0.4 {
            return Color.blue
        } else {
            return Color.purple
        }
    }
}

// MARK: - Liquid Glass View Modifier

/// A view modifier that applies liquid glass material effect
public struct LiquidGlassMaterialModifier: ViewModifier {
    let configuration: LiquidGlassConfiguration
    let cornerRadius: Double

    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(
                liquidGlassBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(configuration.shadowOpacity),
                radius: configuration.shadowRadius,
                x: 0,
                y: configuration.shadowRadius / 2
            )
    }

    @ViewBuilder
    private var liquidGlassBackground: some View {
        ZStack {
            // Base blur layer
            if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
                // Use newer material APIs when available
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .saturation(1.2)
                    .brightness(colorScheme == .dark ? 0.05 : -0.02)
            } else {
                // Fallback for older systems
                Rectangle()
                    .fill(.ultraThinMaterial)
            }

            // Tint overlay
            configuration.tintColor
                .opacity(configuration.tintOpacity)

            // Refraction simulation layer (gradient overlay)
            LinearGradient(
                colors: [
                    .white.opacity(configuration.refractionIntensity * 0.3),
                    .clear,
                    .black.opacity(configuration.refractionIntensity * 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Inner highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.5),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Refractive Depth Modifier

/// Simulates depth-based refraction for UI elements (M-series optimization ready)
public struct RefractiveDepthModifier: ViewModifier {
    let depth: Double  // 0.0 = flat, 1.0 = maximum depth
    let lightAngle: Angle

    public func body(content: Content) -> some View {
        content
            .overlay(
                // Top light reflection
                LinearGradient(
                    colors: [
                        .white.opacity(0.4 * depth),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .allowsHitTesting(false)
            )
            .shadow(
                color: .black.opacity(0.3 * depth),
                radius: 8 * depth,
                x: cos(lightAngle.radians) * 4 * depth,
                y: sin(lightAngle.radians) * 4 * depth
            )
            .scaleEffect(1.0 + (depth * 0.02))  // Subtle "pop" effect
    }
}

// MARK: - SwiftUI View Extensions

public extension View {

    /// Applies liquid glass material effect
    /// - Parameters:
    ///   - configuration: The glass configuration
    ///   - cornerRadius: Corner radius for the glass shape
    /// - Returns: View with liquid glass effect
    func liquidGlassMaterial(
        _ configuration: LiquidGlassConfiguration = .interactive,
        cornerRadius: Double = 20
    ) -> some View {
        modifier(LiquidGlassMaterialModifier(
            configuration: configuration,
            cornerRadius: cornerRadius
        ))
    }

    /// Applies liquid glass with context preset
    /// - Parameters:
    ///   - context: The usage context
    ///   - cornerRadius: Corner radius
    /// - Returns: View with context-appropriate glass effect
    func liquidGlassMaterial(
        context: LiquidGlassConfiguration.Context,
        cornerRadius: Double = 20
    ) -> some View {
        let config: LiquidGlassConfiguration
        switch context {
        case .interactive:
            config = .interactive
        case .ambient:
            config = .ambient
        case .prominent:
            config = .prominent
        case .immersive:
            config = .immersive
        }
        return liquidGlassMaterial(config, cornerRadius: cornerRadius)
    }

    /// Applies bio-reactive liquid glass that responds to coherence level
    /// - Parameters:
    ///   - coherence: Current coherence level (0.0 - 1.0)
    ///   - cornerRadius: Corner radius
    /// - Returns: View with bio-reactive glass effect
    func bioReactiveLiquidGlass(
        coherence: Double,
        cornerRadius: Double = 20
    ) -> some View {
        liquidGlassMaterial(
            .bioReactive(coherence: coherence),
            cornerRadius: cornerRadius
        )
    }

    /// Applies refractive depth effect for 3D-like appearance
    /// - Parameters:
    ///   - depth: Depth intensity (0.0 - 1.0)
    ///   - lightAngle: Light source angle
    /// - Returns: View with depth effect
    func refractiveDepth(
        _ depth: Double = 0.5,
        lightAngle: Angle = .degrees(-45)
    ) -> some View {
        modifier(RefractiveDepthModifier(depth: depth, lightAngle: lightAngle))
    }
}

// MARK: - Liquid Glass Card Component

/// A pre-styled card with liquid glass effect
public struct LiquidGlassCard<Content: View>: View {
    let configuration: LiquidGlassConfiguration
    let cornerRadius: Double
    let content: Content

    public init(
        configuration: LiquidGlassConfiguration = .interactive,
        cornerRadius: Double = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .liquidGlassMaterial(configuration, cornerRadius: cornerRadius)
    }
}

// MARK: - Animated Liquid Glass

/// Liquid glass with animated refraction based on motion
public struct AnimatedLiquidGlass<Content: View>: View {
    @State private var animationPhase: Double = 0
    let content: Content
    let animationSpeed: Double

    public init(
        animationSpeed: Double = 1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.animationSpeed = animationSpeed
        self.content = content()
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            let phase = timeline.date.timeIntervalSince1970 * animationSpeed

            content
                .liquidGlassMaterial(
                    LiquidGlassConfiguration(
                        refractionIntensity: 0.3 + sin(phase) * 0.1,
                        blurRadius: 20 + sin(phase * 0.5) * 5,
                        tintOpacity: 0.1 + sin(phase * 0.3) * 0.05
                    )
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidGlassMaterial_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple, .blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Interactive context
                Text("Interactive Glass")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .liquidGlassMaterial(context: .interactive)

                // Prominent with depth
                Text("Prominent + Depth")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .liquidGlassMaterial(context: .prominent)
                    .refractiveDepth(0.7)

                // Bio-reactive
                Text("Bio-Reactive (70% coherence)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .bioReactiveLiquidGlass(coherence: 0.7)

                // Card component
                LiquidGlassCard(configuration: .ambient) {
                    VStack {
                        Image(systemName: "waveform.circle")
                            .font(.largeTitle)
                        Text("Glass Card")
                    }
                    .foregroundColor(.white)
                }
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
