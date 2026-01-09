// Visualizations.swift
// Complete visualization system with 5 modes

import SwiftUI

// MARK: - Visualization Container

public struct VisualizationView: View {
    let type: VisualizationType
    let bioData: BiometricData
    let isActive: Bool

    public init(type: VisualizationType, bioData: BiometricData, isActive: Bool) {
        self.type = type
        self.bioData = bioData
        self.isActive = isActive
    }

    public var body: some View {
        Group {
            switch type {
            case .coherence:
                CoherenceRingView(bioData: bioData, isActive: isActive)
            case .mandala:
                MandalaView(bioData: bioData, isActive: isActive)
            case .particles:
                ParticleView(bioData: bioData, isActive: isActive)
            case .waveform:
                WaveformView(bioData: bioData, isActive: isActive)
            case .spectrum:
                SpectrumView(bioData: bioData, isActive: isActive)
            }
        }
    }
}

// MARK: - Coherence Ring Visualization

public struct CoherenceRingView: View {
    let bioData: BiometricData
    let isActive: Bool

    @State private var pulseScale: Double = 1.0
    @State private var rotation: Double = 0

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Outer glow rings
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(coherenceColor.opacity(0.3 - Double(ring) * 0.08), lineWidth: 2)
                        .frame(width: size * (0.6 + Double(ring) * 0.15))
                        .scaleEffect(pulseScale + Double(ring) * 0.05)
                }

                // Main coherence circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [coherenceColor.opacity(0.8), coherenceColor.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
                    .frame(width: size * 0.5)
                    .scaleEffect(pulseScale)

                // Particle ring
                ForEach(0..<12, id: \.self) { i in
                    let angle = (Double(i) / 12.0) * 2 * .pi + rotation
                    let radius = size * 0.25
                    Circle()
                        .fill(coherenceColor)
                        .frame(width: 6)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                        .opacity(0.6)
                }

                // Center display
                VStack(spacing: 4) {
                    Text("\(Int(bioData.coherence))")
                        .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("COHERENCE")
                        .font(.system(size: size * 0.03, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear { startAnimations() }
    }

    private var coherenceColor: Color {
        switch bioData.coherenceLevel {
        case .low: return .purple
        case .medium: return .blue
        case .high: return .green
        }
    }

    private var pulseDuration: Double {
        60.0 / max(bioData.heartRate, 40)
    }

    private func startAnimations() {
        guard isActive else { return }

        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }

        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            rotation = .pi * 2
        }
    }
}

// MARK: - Mandala Visualization

public struct MandalaView: View {
    let bioData: BiometricData
    let isActive: Bool

    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0

    private let petalCount = 12

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Outer petals
                ForEach(0..<petalCount, id: \.self) { i in
                    petalView(index: i, size: size, layer: 0)
                }

                // Inner petals
                ForEach(0..<petalCount, id: \.self) { i in
                    petalView(index: i, size: size, layer: 1)
                }

                // Center
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, coherenceColor],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.08
                        )
                    )
                    .frame(width: size * 0.15)
                    .scaleEffect(scale)
            }
            .rotationEffect(.degrees(rotation))
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear { startAnimations() }
    }

    private func petalView(index: Int, size: CGFloat, layer: Int) -> some View {
        let angle = Double(index) / Double(petalCount) * 360
        let layerScale = layer == 0 ? 1.0 : 0.6
        let layerRotation = layer == 0 ? 0.0 : 15.0

        let hue = (Double(index) / Double(petalCount) + bioData.normalizedCoherence * 0.3)
            .truncatingRemainder(dividingBy: 1.0)

        return Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.7, brightness: 0.9),
                        Color(hue: hue, saturation: 0.5, brightness: 0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.12 * layerScale, height: size * 0.35 * layerScale)
            .offset(y: -size * 0.2 * layerScale)
            .rotationEffect(.degrees(angle + layerRotation))
            .opacity(0.7 + bioData.normalizedCoherence * 0.3)
    }

    private var coherenceColor: Color {
        Color(hue: bioData.normalizedCoherence * 0.3, saturation: 0.8, brightness: 0.9)
    }

    private func startAnimations() {
        guard isActive else { return }

        let speed = max(bioData.normalizedCoherence, 0.2)
        withAnimation(.linear(duration: 20 / speed).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        let pulseDuration = 60.0 / max(bioData.heartRate, 40)
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            scale = 1.15
        }
    }
}

// MARK: - Particle Visualization

public struct ParticleView: View {
    let bioData: BiometricData
    let isActive: Bool

    @State private var particles: [ParticleData] = []

    private let maxParticles = 60

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.x * size.width - particle.size / 2,
                            y: particle.y * size.height - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )

                        context.fill(
                            Circle().path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
            }
            .onAppear {
                initializeParticles()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startAnimation()
                }
            }
        }
    }

    private func initializeParticles() {
        particles = (0..<maxParticles).map { _ in
            ParticleData(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                vx: Double.random(in: -0.002...0.002),
                vy: Double.random(in: -0.002...0.002),
                size: CGFloat.random(in: 4...12),
                color: particleColor(),
                opacity: Double.random(in: 0.4...0.9)
            )
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        let speed = 1.0 + bioData.normalizedCoherence * 2.0

        for i in particles.indices {
            particles[i].x += particles[i].vx * speed
            particles[i].y += particles[i].vy * speed

            // Wrap around edges
            if particles[i].x < 0 { particles[i].x = 1 }
            if particles[i].x > 1 { particles[i].x = 0 }
            if particles[i].y < 0 { particles[i].y = 1 }
            if particles[i].y > 1 { particles[i].y = 0 }

            // Pulsing opacity
            let pulse = sin(Date().timeIntervalSince1970 * bioData.heartRate / 30)
            particles[i].opacity = 0.5 + pulse * 0.3 + bioData.normalizedCoherence * 0.2
        }
    }

    private func particleColor() -> Color {
        Color(hue: Double.random(in: 0.5...0.8), saturation: 0.7, brightness: 0.9)
    }
}

struct ParticleData: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Waveform Visualization

public struct WaveformView: View {
    let bioData: BiometricData
    let isActive: Bool

    @State private var phase: Double = 0

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.016)) { _ in
                Canvas { context, size in
                    let path = createWaveformPath(size: size)
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [coherenceColor, coherenceColor.opacity(0.5)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                }
            }
            .onAppear { startAnimation() }
        }
    }

    private func createWaveformPath(size: CGSize) -> Path {
        var path = Path()
        let midY = size.height / 2
        let amplitude = size.height * 0.3 * CGFloat(bioData.normalizedCoherence + 0.3)

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, to: size.width, by: 2) {
            let normalizedX = x / size.width
            let wave1 = sin((normalizedX * 4 + phase) * .pi * 2) * amplitude
            let wave2 = sin((normalizedX * 8 + phase * 1.5) * .pi * 2) * amplitude * 0.3
            let y = midY + wave1 + wave2

            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }

    private var coherenceColor: Color {
        switch bioData.coherenceLevel {
        case .low: return .purple
        case .medium: return .cyan
        case .high: return .green
        }
    }

    private func startAnimation() {
        guard isActive else { return }

        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            phase += 0.02 * (1 + bioData.normalizedCoherence)
        }
    }
}

// MARK: - Spectrum Visualization

public struct SpectrumView: View {
    let bioData: BiometricData
    let isActive: Bool

    private let barCount = 24

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { i in
                    SpectrumBar(
                        index: i,
                        total: barCount,
                        coherence: bioData.normalizedCoherence,
                        heartRate: bioData.heartRate
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SpectrumBar: View {
    let index: Int
    let total: Int
    let coherence: Double
    let heartRate: Double

    @State private var height: CGFloat = 0.3

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(height: geometry.size.height * height)
            }
        }
        .onAppear { animate() }
    }

    private var barColor: Color {
        let hue = Double(index) / Double(total) * 0.3 + coherence * 0.2
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }

    private func animate() {
        let delay = Double(index) * 0.05
        let duration = 60.0 / heartRate

        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            height = 0.3 + CGFloat(coherence) * 0.5 + CGFloat.random(in: 0...0.2)
        }
    }
}
