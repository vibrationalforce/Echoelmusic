import SwiftUI

// MARK: - Liquid Light Visualizer
// "Flüssiges Licht" - Die Signature-Visualisierung von Nia9ara/Echoelmusic
// Fließende Lichtströme die mit Coherence und Audio synchronisiert sind

struct LiquidLightVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    @State private var flowOffset: CGFloat = 0
    @State private var particles: [LiquidParticle] = []

    private let particleCount = 100

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            Canvas { context, size in
                let time = params.time

                // Draw flowing light streams
                drawLiquidStreams(context: context, size: size, time: time)

                // Draw light particles
                drawLightParticles(context: context, size: size, time: time)

                // Draw coherence glow
                drawCoherenceGlow(context: context, size: size)
            }
        }
        .onAppear {
            initializeParticles()
        }
    }

    // MARK: - Liquid Streams

    private func drawLiquidStreams(context: GraphicsContext, size: CGSize, time: Double) {
        let streamCount = 5
        let coherence = CGFloat(params.coherence)
        let energy = CGFloat(params.energy)

        for i in 0..<streamCount {
            let phase = Double(i) / Double(streamCount) * .pi * 2
            let streamPath = createStreamPath(
                size: size,
                time: time,
                phase: phase,
                coherence: coherence
            )

            // Gradient based on coherence
            let hue = Double(params.colorHue)
            let colors: [Color] = [
                Color(hue: hue, saturation: 0.8, brightness: 0.3),
                Color(hue: hue + 0.1, saturation: 0.9, brightness: 0.8 + Double(energy) * 0.2),
                Color(hue: hue + 0.2, saturation: 0.7, brightness: 0.4)
            ]

            // Draw glow
            context.stroke(
                streamPath,
                with: .color(colors[1].opacity(0.3)),
                lineWidth: 20 + energy * 10
            )

            // Draw core
            context.stroke(
                streamPath,
                with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: 0, y: size.height / 2),
                    endPoint: CGPoint(x: size.width, y: size.height / 2)
                ),
                lineWidth: 3 + energy * 5
            )
        }
    }

    private func createStreamPath(size: CGSize, time: Double, phase: Double, coherence: CGFloat) -> Path {
        var path = Path()

        let segments = 50
        let amplitude = size.height * 0.3 * (0.5 + coherence * 0.5)
        let frequency = 2.0 + Double(params.bassLevel) * 2.0

        for i in 0...segments {
            let x = CGFloat(i) / CGFloat(segments) * size.width
            let progress = Double(i) / Double(segments)

            // Multiple sine waves combined (liquid effect)
            let wave1 = sin(progress * frequency * .pi + time * 2 + phase) * amplitude
            let wave2 = sin(progress * frequency * 0.5 * .pi + time * 1.5 + phase * 2) * amplitude * 0.5
            let wave3 = sin(progress * frequency * 2 * .pi + time * 3 + phase * 0.5) * amplitude * 0.3

            // Audio modulation
            let audioMod = CGFloat(params.audioLevel) * 30 * sin(progress * 10 * .pi + time * 5)

            let y = size.height / 2 + wave1 + wave2 + wave3 + audioMod

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    // MARK: - Light Particles

    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            LiquidParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                vx: CGFloat.random(in: -0.002...0.002),
                vy: CGFloat.random(in: -0.002...0.002),
                size: CGFloat.random(in: 2...8),
                brightness: Float.random(in: 0.3...1.0),
                phase: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    private func drawLightParticles(context: GraphicsContext, size: CGSize, time: Double) {
        let coherence = params.coherence
        let energy = params.energy

        for i in particles.indices {
            var p = particles[i]

            // Update position
            let flowForce = sin(time * 2 + p.phase) * 0.001 * CGFloat(coherence)
            p.x += p.vx + flowForce
            p.y += p.vy + cos(time * 1.5 + p.phase) * 0.0005

            // Wrap around
            if p.x < 0 { p.x = 1 }
            if p.x > 1 { p.x = 0 }
            if p.y < 0 { p.y = 1 }
            if p.y > 1 { p.y = 0 }

            particles[i] = p

            // Draw
            let screenX = p.x * size.width
            let screenY = p.y * size.height

            // Pulsing size based on beat
            let pulseSize = p.size * (1 + CGFloat(params.beatPhase) * CGFloat(energy) * 0.5)

            let hue = Double(params.colorHue) + Double(p.phase / (.pi * 2)) * 0.2
            let alpha = Double(p.brightness) * Double(coherence) * 0.8 + 0.2

            // Glow
            let glowRect = CGRect(
                x: screenX - pulseSize * 2,
                y: screenY - pulseSize * 2,
                width: pulseSize * 4,
                height: pulseSize * 4
            )
            context.fill(
                Circle().path(in: glowRect),
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 0.8).opacity(alpha * 0.3))
            )

            // Core
            let coreRect = CGRect(
                x: screenX - pulseSize / 2,
                y: screenY - pulseSize / 2,
                width: pulseSize,
                height: pulseSize
            )
            context.fill(
                Circle().path(in: coreRect),
                with: .color(Color(hue: hue, saturation: 0.6, brightness: 1.0).opacity(alpha))
            )
        }
    }

    // MARK: - Coherence Glow

    private func drawCoherenceGlow(context: GraphicsContext, size: CGSize) {
        let coherence = CGFloat(params.coherence)
        let hue = Double(params.colorHue)

        // Central glow that grows with coherence
        let glowRadius = size.width * 0.3 * coherence + 50

        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let gradient = Gradient(colors: [
            Color(hue: hue, saturation: 0.9, brightness: 0.9).opacity(Double(coherence) * 0.4),
            Color(hue: hue, saturation: 0.8, brightness: 0.7).opacity(Double(coherence) * 0.2),
            Color.clear
        ])

        context.fill(
            Circle().path(in: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: glowRadius)
        )
    }
}

// MARK: - Liquid Particle Model

struct LiquidParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var brightness: Float
    var phase: Double
}

// MARK: - Preview

#Preview {
    LiquidLightVisualizer(params: UnifiedVisualSoundEngine.VisualParameters(
        audioLevel: 0.6,
        bassLevel: 0.7,
        coherence: 0.8,
        energy: 0.7,
        flow: 0.75,
        colorHue: 0.3,
        time: 0
    ))
    .frame(height: 400)
    .background(Color.black)
}
