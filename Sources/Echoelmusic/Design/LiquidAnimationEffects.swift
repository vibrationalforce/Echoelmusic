//
//  LiquidAnimationEffects.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Liquid Animation Effects
//  Smooth, fluid animations for vaporwave aesthetic
//  Morphing, flowing, pulsing, glowing effects
//

import SwiftUI

// MARK: - Liquid Morph Transition

/// Smooth morphing transition between views
struct LiquidMorphTransition: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.0 : 0.8)
            .opacity(isActive ? 1.0 : 0.0)
            .blur(radius: isActive ? 0 : 10)
            .animation(VaporwaveDesignSystem.Animation.liquid, value: isActive)
    }
}

extension View {
    func liquidMorph(isActive: Bool) -> some View {
        modifier(LiquidMorphTransition(isActive: isActive))
    }
}

// MARK: - Glow Pulse Effect

/// Pulsing neon glow animation
struct GlowPulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(isPulsing ? intensity : intensity * 0.5),
                radius: isPulsing ? 20 : 10
            )
            .shadow(
                color: color.opacity(isPulsing ? intensity * 0.8 : intensity * 0.4),
                radius: isPulsing ? 30 : 15
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func glowPulse(color: Color = VaporwaveDesignSystem.Colors.neonCyan, intensity: Double = 0.6) -> some View {
        modifier(GlowPulseEffect(color: color, intensity: intensity))
    }
}

// MARK: - Liquid Loading Indicator

struct LiquidLoadingIndicator: View {
    @State private var isAnimating = false
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 3)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating ? 1.5 : 0.5)
                    .opacity(isAnimating ? 0.0 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.5),
                        value: isAnimating
                    )
            }

            Circle()
                .fill(color)
                .frame(width: size * 0.3, height: size * 0.3)
                .shadow(color: color, radius: 10)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Holographic Shimmer

/// Animated holographic shimmer effect
struct HolographicShimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        VaporwaveDesignSystem.Colors.neonCyan.opacity(0.3),
                        VaporwaveDesignSystem.Colors.neonPink.opacity(0.3),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(phase))
                .blur(radius: 5)
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

extension View {
    func holographicShimmer() -> some View {
        modifier(HolographicShimmer())
    }
}

// MARK: - Liquid Wave Effect

struct LiquidWaveEffect: View {
    @State private var waveOffset: CGFloat = 0
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var amplitude: CGFloat = 20
    var frequency: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let midHeight = geometry.size.height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in stride(from: 0, through: geometry.size.width, by: 1) {
                    let relativeX = x / geometry.size.width
                    let sine = sin((relativeX * frequency * .pi * 2) + waveOffset)
                    let y = midHeight + (sine * amplitude)

                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.6), color.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    waveOffset = .pi * 2
                }
            }
        }
    }
}

// MARK: - Floating Animation

struct FloatingAnimation: ViewModifier {
    @State private var isFloating = false
    let distance: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -distance : distance)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
    }
}

extension View {
    func floating(distance: CGFloat = 10, duration: Double = 2.0) -> some View {
        modifier(FloatingAnimation(distance: distance, duration: duration))
    }
}

// MARK: - Rotate Continuously

struct ContinuousRotation: ViewModifier {
    @State private var rotation: Double = 0
    let duration: Double
    let clockwise: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = clockwise ? 360 : -360
                }
            }
    }
}

extension View {
    func rotatesContinuously(duration: Double = 2.0, clockwise: Bool = true) -> some View {
        modifier(ContinuousRotation(duration: duration, clockwise: clockwise))
    }
}

// MARK: - Neon Border Animation

struct AnimatedNeonBorder: View {
    @State private var phase: CGFloat = 0
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var cornerRadius: CGFloat = VaporwaveDesignSystem.CornerRadius.medium

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        color,
                        color.opacity(0.5),
                        color,
                        color.opacity(0.5),
                        color
                    ],
                    center: .center,
                    angle: .degrees(phase)
                ),
                lineWidth: 2
            )
            .shadow(color: color.opacity(0.6), radius: 10)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

// MARK: - Ripple Effect

struct RippleEffect: View {
    @State private var ripples: [Ripple] = []
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan

    struct Ripple: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0
        var opacity: Double = 1
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(ripple.scale)
                        .opacity(ripple.opacity)
                        .frame(width: 50, height: 50)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .onAppear {
                addRipple()
            }
        }
    }

    private func addRipple() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            var newRipple = Ripple()

            withAnimation(.easeOut(duration: 2)) {
                newRipple.scale = 4
                newRipple.opacity = 0
            }

            ripples.append(newRipple)

            // Remove old ripples
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                ripples.removeFirst()
            }
        }
    }
}

// MARK: - Glitch Effect

struct GlitchEffect: ViewModifier {
    @State private var offset: CGSize = .zero
    @State private var isGlitching = false

    func body(content: Content) -> some View {
        ZStack {
            // Red channel
            content
                .foregroundColor(VaporwaveDesignSystem.Colors.neonPink)
                .offset(x: isGlitching ? offset.width : 0, y: isGlitching ? offset.height : 0)
                .opacity(0.5)

            // Green channel
            content
                .foregroundColor(VaporwaveDesignSystem.Colors.laserGreen)
                .offset(x: isGlitching ? -offset.width : 0, y: isGlitching ? -offset.height : 0)
                .opacity(0.5)

            // Main content
            content
        }
        .onAppear {
            startGlitching()
        }
    }

    private func startGlitching() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                isGlitching = true
                offset = CGSize(width: CGFloat.random(in: -5...5), height: CGFloat.random(in: -5...5))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.linear(duration: 0.1)) {
                    isGlitching = false
                    offset = .zero
                }
            }
        }
    }
}

extension View {
    func glitchEffect() -> some View {
        modifier(GlitchEffect())
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    @State private var offset: CGFloat = 0
    var spacing: CGFloat = 4
    var opacity: Double = 0.1

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: spacing) {
                ForEach(0..<Int(geometry.size.height / (spacing * 2)), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(opacity))
                        .frame(height: spacing)
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    offset = spacing * 2
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Particle Burst

struct ParticleBurst: View {
    @State private var particles: [Particle] = []
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    let particleCount: Int = 20

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var scale: CGFloat = 1.0
        var opacity: Double = 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(width: 4 * particle.scale, height: 4 * particle.scale)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .blur(radius: 1)
                }
            }
            .onAppear {
                burst(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
            }
        }
    }

    private func burst(at point: CGPoint) {
        particles = (0..<particleCount).map { i in
            let angle = (Double(i) / Double(particleCount)) * .pi * 2
            let velocity = CGVector(
                dx: cos(angle) * Double.random(in: 50...150),
                dy: sin(angle) * Double.random(in: 50...150)
            )

            return Particle(position: point, velocity: velocity)
        }

        animateParticles()
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.dx * 0.02
                particles[i].position.y += particles[i].velocity.dy * 0.02
                particles[i].velocity.dy += 9.8 * 0.02  // Gravity
                particles[i].opacity -= 0.02
                particles[i].scale *= 0.98
            }

            if particles.first?.opacity ?? 1.0 <= 0 {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Liquid Button Press

struct LiquidButtonPress: ViewModifier {
    @State private var isPressed = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? 0.1 : 0.0)
            .animation(VaporwaveDesignSystem.Animation.bouncySpring, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

extension View {
    func liquidButtonPress(action: @escaping () -> Void) -> some View {
        modifier(LiquidButtonPress(action: action))
    }
}

// MARK: - Preview

#Preview("Liquid Animations") {
    ZStack {
        VaporwaveDesignSystem.Colors.spaceGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveDesignSystem.Spacing.xxlarge) {
                // Glow Pulse
                VStack {
                    NeonText(text: "GLOW PULSE", color: VaporwaveDesignSystem.Colors.neonCyan)
                    Circle()
                        .fill(VaporwaveDesignSystem.Colors.neonCyan)
                        .frame(width: 60, height: 60)
                        .glowPulse(color: VaporwaveDesignSystem.Colors.neonCyan)
                }

                // Loading Indicator
                VStack {
                    NeonText(text: "LOADING", color: VaporwaveDesignSystem.Colors.neonPink)
                    LiquidLoadingIndicator(color: VaporwaveDesignSystem.Colors.neonPink)
                }

                // Liquid Wave
                VStack {
                    NeonText(text: "LIQUID WAVE", color: VaporwaveDesignSystem.Colors.laserGreen)
                    LiquidWaveEffect(color: VaporwaveDesignSystem.Colors.laserGreen)
                        .frame(height: 100)
                }

                // Floating
                VStack {
                    NeonText(text: "FLOATING", color: VaporwaveDesignSystem.Colors.electricBlue)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 48))
                        .foregroundColor(VaporwaveDesignSystem.Colors.electricBlue)
                        .floating()
                }

                // Rotation
                VStack {
                    NeonText(text: "ROTATION", color: VaporwaveDesignSystem.Colors.neonPurple)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(VaporwaveDesignSystem.Colors.neonPurple)
                        .rotatesContinuously()
                }

                // Animated Border
                VStack {
                    NeonText(text: "ANIMATED BORDER", color: VaporwaveDesignSystem.Colors.sunsetOrange)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 200, height: 100)
                        .overlay(
                            AnimatedNeonBorder(color: VaporwaveDesignSystem.Colors.sunsetOrange)
                        )
                }
            }
            .padding()
        }
    }
}
