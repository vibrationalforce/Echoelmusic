import SwiftUI

// MARK: - All Visualizer Implementations
// Sammlung aller Visualizer für das Unified Visual Sound System

// MARK: - Particle Visualizer

struct ParticleVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    @State private var particles: [VisualParticle] = []
    private let maxParticles = 300

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                updateAndDrawParticles(context: context, size: size)
            }
        }
        .onAppear {
            initParticles()
        }
    }

    private func initParticles() {
        particles = (0..<maxParticles).map { _ in
            VisualParticle()
        }
    }

    private func updateAndDrawParticles(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coherence = CGFloat(params.coherence)
        let energy = CGFloat(params.energy)

        for i in particles.indices {
            var p = particles[i]

            // Physics
            let dx = center.x - p.x * size.width
            let dy = center.y - p.y * size.height
            let dist = sqrt(dx * dx + dy * dy)

            // Coherence attracts to center
            if dist > 1 {
                p.vx += (dx / dist) * coherence * 0.0002
                p.vy += (dy / dist) * coherence * 0.0002
            }

            // Audio pushes outward
            p.vx += CGFloat.random(in: -1...1) * energy * 0.001
            p.vy += CGFloat.random(in: -1...1) * energy * 0.001

            // Damping
            p.vx *= 0.98
            p.vy *= 0.98

            // Update position
            p.x += p.vx
            p.y += p.vy

            // Wrap
            if p.x < 0 || p.x > 1 { p.x = 0.5 + CGFloat.random(in: -0.1...0.1) }
            if p.y < 0 || p.y > 1 { p.y = 0.5 + CGFloat.random(in: -0.1...0.1) }

            particles[i] = p

            // Draw
            let screenX = p.x * size.width
            let screenY = p.y * size.height
            let pSize = p.size * (1 + energy * 0.5)

            let hue = Double(params.colorHue) + Double(p.hueOffset)
            let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.9)

            // Glow
            context.fill(
                Circle().path(in: CGRect(x: screenX - pSize * 2, y: screenY - pSize * 2, width: pSize * 4, height: pSize * 4)),
                with: .color(color.opacity(0.2))
            )

            // Core
            context.fill(
                Circle().path(in: CGRect(x: screenX - pSize / 2, y: screenY - pSize / 2, width: pSize, height: pSize)),
                with: .color(color.opacity(Double(p.alpha)))
            )
        }
    }
}

struct VisualParticle {
    var x: CGFloat = CGFloat.random(in: 0...1)
    var y: CGFloat = CGFloat.random(in: 0...1)
    var vx: CGFloat = CGFloat.random(in: -0.01...0.01)
    var vy: CGFloat = CGFloat.random(in: -0.01...0.01)
    var size: CGFloat = CGFloat.random(in: 3...10)
    var alpha: Float = Float.random(in: 0.4...1.0)
    var hueOffset: Float = Float.random(in: 0...0.2)
}

// MARK: - Spectrum Visualizer

struct SpectrumVisualizer: View {
    let data: [Float]
    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        Canvas { context, size in
            guard !data.isEmpty else { return }

            let barCount = min(64, data.count)
            let barWidth = size.width / CGFloat(barCount) - 2

            for i in 0..<barCount {
                let magnitude = CGFloat(data[i])
                let barHeight = magnitude * size.height * 0.8

                let x = CGFloat(i) * (barWidth + 2) + 1
                let y = size.height - barHeight

                // Color based on frequency and coherence
                let hue = Double(i) / Double(barCount) * 0.4 + Double(params.colorHue)
                let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 0.9)

                // Glow
                context.fill(
                    RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: x - 1, y: y - 2, width: barWidth + 2, height: barHeight + 4)),
                    with: .color(color.opacity(0.3))
                )

                // Bar
                context.fill(
                    RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: x, y: y, width: barWidth, height: barHeight)),
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.6), color]),
                        startPoint: .init(x: x, y: size.height),
                        endPoint: .init(x: x, y: y)
                    )
                )
            }
        }
    }
}

// MARK: - Waveform Visualizer

struct WaveformVisualizer: View {
    let data: [Float]
    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        Canvas { context, size in
            guard !data.isEmpty else { return }

            var path = Path()
            let centerY = size.height / 2

            for (i, sample) in data.enumerated() {
                let x = CGFloat(i) / CGFloat(data.count) * size.width
                let y = centerY - CGFloat(sample) * size.height * 0.4

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let hue = Double(params.colorHue)
            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

            // Glow
            context.stroke(path, with: .color(color.opacity(0.3)), lineWidth: 6)

            // Core
            context.stroke(path, with: .color(color), lineWidth: 2)

            // Center line
            var centerPath = Path()
            centerPath.move(to: CGPoint(x: 0, y: centerY))
            centerPath.addLine(to: CGPoint(x: size.width, y: centerY))
            context.stroke(centerPath, with: .color(Color.white.opacity(0.1)), lineWidth: 1)
        }
    }
}

// MARK: - Mandala Visualizer

struct MandalaVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) * 0.4
                let time = params.time

                for layer in 0..<6 {
                    let radius = maxRadius * (1 - CGFloat(layer) * 0.15)
                    let petalCount = 6 + layer * 2
                    let rotation = time * (0.1 + Double(layer) * 0.05) * (layer % 2 == 0 ? 1 : -1)

                    drawMandalaRing(
                        context: context,
                        center: center,
                        radius: radius,
                        petalCount: petalCount,
                        rotation: rotation,
                        layer: layer
                    )
                }
            }
        }
    }

    private func drawMandalaRing(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        petalCount: Int,
        rotation: Double,
        layer: Int
    ) {
        let hue = Double(params.colorHue) + Double(layer) * 0.1
        let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.85)
        let petalSize = radius * 0.2 * (1 + CGFloat(params.audioLevel) * 0.5)

        for i in 0..<petalCount {
            let angle = Double(i) / Double(petalCount) * .pi * 2 + rotation

            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius

            let petalRect = CGRect(
                x: x - petalSize / 2,
                y: y - petalSize / 2,
                width: petalSize,
                height: petalSize
            )

            context.fill(Circle().path(in: petalRect), with: .color(color.opacity(0.5)))
            context.stroke(Circle().path(in: petalRect), with: .color(color), lineWidth: 1)
        }
    }
}

// MARK: - Cymatics Visualizer

struct SimpleCymaticsVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) * 0.45
                let time = params.time

                // Draw interference pattern
                drawCymaticPattern(context: context, size: size, center: center, maxRadius: maxRadius, time: time)
            }
        }
    }

    private func drawCymaticPattern(
        context: GraphicsContext,
        size: CGSize,
        center: CGPoint,
        maxRadius: CGFloat,
        time: Double
    ) {
        let frequency = Double(params.frequency) / 100.0 + 2.0  // 2-6 waves
        let amplitude = CGFloat(params.audioLevel)
        let hue = Double(params.colorHue)

        // Draw concentric rings with interference
        for ring in 0..<20 {
            let baseRadius = maxRadius * CGFloat(ring) / 20.0
            let ringOffset = sin(time * 2 + Double(ring) * 0.5) * Double(amplitude) * 10

            let radius = baseRadius + CGFloat(ringOffset)
            let alpha = 1.0 - Double(ring) / 25.0

            var path = Path()
            let segments = 60

            for i in 0...segments {
                let angle = Double(i) / Double(segments) * .pi * 2
                let waveOffset = sin(angle * frequency + time * 3) * Double(amplitude) * 20

                let x = center.x + cos(angle) * (radius + CGFloat(waveOffset))
                let y = center.y + sin(angle) * (radius + CGFloat(waveOffset))

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubPath()

            let color = Color(hue: hue + Double(ring) * 0.02, saturation: 0.7, brightness: 0.9)
            context.stroke(path, with: .color(color.opacity(alpha)), lineWidth: 1.5)
        }
    }
}

// MARK: - Nebula Visualizer

struct NebulaVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    @State private var cloudPoints: [CloudPoint] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                if cloudPoints.isEmpty {
                    initClouds(size: size)
                }
                drawNebula(context: context, size: size)
            }
        }
    }

    private func initClouds(size: CGSize) {
        cloudPoints = (0..<50).map { _ in
            CloudPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                radius: CGFloat.random(in: 50...150),
                hueOffset: Float.random(in: 0...0.3),
                phase: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    private func drawNebula(context: GraphicsContext, size: CGSize) {
        let time = params.time
        let energy = CGFloat(params.energy)
        let baseHue = Double(params.colorHue)

        for cloud in cloudPoints {
            let pulseScale = 1 + sin(time + cloud.phase) * 0.2 * Double(energy)
            let radius = cloud.radius * CGFloat(pulseScale)

            let hue = baseHue + Double(cloud.hueOffset)
            let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.7)

            let gradient = RadialGradient(
                colors: [color.opacity(0.4), color.opacity(0.1), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )

            let rect = CGRect(
                x: cloud.x - radius,
                y: cloud.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.fill(Ellipse().path(in: rect), with: .radialGradient(
                Gradient(colors: [color.opacity(0.3), color.opacity(0.1), Color.clear]),
                center: CGPoint(x: cloud.x, y: cloud.y),
                startRadius: 0,
                endRadius: radius
            ))
        }
    }
}

struct CloudPoint {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var hueOffset: Float
    var phase: Double
}

// MARK: - Kaleidoscope Visualizer

struct KaleidoscopeVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let segments = 8
                let time = params.time

                for segment in 0..<segments {
                    let angle = Double(segment) / Double(segments) * .pi * 2

                    context.drawLayer { layerContext in
                        layerContext.translateBy(x: center.x, y: center.y)
                        layerContext.rotate(by: Angle(radians: angle))

                        if segment % 2 == 1 {
                            layerContext.scaleBy(x: -1, y: 1)
                        }

                        drawSegmentContent(context: layerContext, size: size, time: time)
                    }
                }
            }
        }
    }

    private func drawSegmentContent(context: GraphicsContext, size: CGSize, time: Double) {
        let maxDist = min(size.width, size.height) * 0.4
        let energy = CGFloat(params.energy)
        let hue = Double(params.colorHue)

        for i in 0..<10 {
            let dist = CGFloat(i) / 10.0 * maxDist
            let wobble = sin(time * 3 + Double(i) * 0.5) * 10 * Double(energy)

            let x = dist + CGFloat(wobble)
            let y = sin(time * 2 + Double(i)) * 30 * Double(energy)

            let dotSize = 5 + energy * 10 * (1 - CGFloat(i) / 10.0)
            let color = Color(hue: (hue + Double(i) * 0.05).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.9)

            context.fill(
                Circle().path(in: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)),
                with: .color(color.opacity(0.8))
            )
        }
    }
}

// MARK: - Flow Field Visualizer

struct FlowFieldVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters

    @State private var flowParticles: [FlowParticle] = []
    private let particleCount = 500

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                if flowParticles.isEmpty {
                    initFlowParticles(size: size)
                }
                updateAndDrawFlow(context: context, size: size)
            }
        }
    }

    private func initFlowParticles(size: CGSize) {
        flowParticles = (0..<particleCount).map { _ in
            FlowParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                prevX: 0,
                prevY: 0,
                hue: Float.random(in: 0...0.2)
            )
        }
    }

    private func updateAndDrawFlow(context: GraphicsContext, size: CGSize) {
        let time = params.time
        let scale = 0.005  // Noise scale
        let speed = CGFloat(params.energy) * 3 + 1

        for i in flowParticles.indices {
            var p = flowParticles[i]
            p.prevX = p.x
            p.prevY = p.y

            // Perlin-like noise field (simplified)
            let angle = noise(x: p.x * CGFloat(scale), y: p.y * CGFloat(scale), time: time) * .pi * 2

            p.x += cos(angle) * speed
            p.y += sin(angle) * speed

            // Wrap
            if p.x < 0 { p.x = size.width; p.prevX = p.x }
            if p.x > size.width { p.x = 0; p.prevX = p.x }
            if p.y < 0 { p.y = size.height; p.prevY = p.y }
            if p.y > size.height { p.y = 0; p.prevY = p.y }

            flowParticles[i] = p

            // Draw line
            let hue = Double(params.colorHue) + Double(p.hue)
            let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.85)

            var path = Path()
            path.move(to: CGPoint(x: p.prevX, y: p.prevY))
            path.addLine(to: CGPoint(x: p.x, y: p.y))

            context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 1)
        }
    }

    private func noise(x: CGFloat, y: CGFloat, time: Double) -> CGFloat {
        // Simplified noise function
        return CGFloat(sin(Double(x) * 3 + time) * cos(Double(y) * 3 + time * 0.7) +
                      sin(Double(x + y) * 2 + time * 1.3) * 0.5)
    }
}

struct FlowParticle {
    var x: CGFloat
    var y: CGFloat
    var prevX: CGFloat
    var prevY: CGFloat
    var hue: Float
}
