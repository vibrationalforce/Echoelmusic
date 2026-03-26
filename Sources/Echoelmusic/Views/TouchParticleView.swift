#if canImport(SwiftUI)
import SwiftUI

/// Touch-reactive particle system that makes each Sound World feel tangible.
/// Particles emanate from finger positions — like touching water, stars, or clouds.
/// Uses SwiftUI Canvas at 60fps for zero-interference with audio thread.
struct TouchParticleView: View {

    let touches: [EchoelInstrumentView.ActiveTouchPoint]
    let worldStyle: ParticleStyle
    @State private var particles: [Particle] = []
    @State private var frameTime: TimeInterval = 0

    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var life: CGFloat      // 1.0 → 0.0
        var size: CGFloat
        var hue: Double
        var saturation: Double
        var brightness: Double
        var opacity: CGFloat
    }

    enum ParticleStyle {
        case water       // Underwater, Ocean, Waterfall — ripples, flowing blue
        case organic     // Jungle, Forest — green spores, leaf dust
        case rain        // Rain — droplets falling down
        case stars       // Aurora, Atmosphere, Void — twinkling points
        case warmth      // Ember, Midnight — warm glowing embers
        case crystal     // Glass, Silk, Drift — sharp bright shards
        case cave        // Cave — amber dust motes

        /// Spawn particles for a touch at this position
        func spawn(at point: CGPoint, into particles: inout [Particle]) {
            let count = 3 // particles per frame per touch
            for _ in 0..<count {
                var p = Particle(
                    x: point.x, y: point.y,
                    vx: 0, vy: 0,
                    life: 1.0,
                    size: 4.0,
                    hue: 0, saturation: 0.5, brightness: 0.6, opacity: 0.5
                )

                switch self {
                case .water:
                    // Rippling outward, blue-cyan, slow drift
                    let angle = CGFloat.random(in: 0 ... (2.0 * CGFloat.pi))
                    let speed = CGFloat.random(in: 0.3...1.5)
                    p.vx = cos(angle) * speed
                    p.vy = sin(angle) * speed
                    p.size = CGFloat.random(in: 3...8)
                    p.hue = Double.random(in: 195...220) / 360.0
                    p.saturation = Double.random(in: 0.4...0.7)
                    p.brightness = Double.random(in: 0.4...0.7)
                    p.opacity = CGFloat.random(in: 0.15...0.4)
                    p.life = CGFloat.random(in: 0.6...1.0)

                case .organic:
                    // Floating upward, green spores
                    p.vx = CGFloat.random(in: -0.8...0.8)
                    p.vy = CGFloat.random(in: -1.5...-0.3)
                    p.size = CGFloat.random(in: 2...6)
                    p.hue = Double.random(in: 90...150) / 360.0
                    p.saturation = Double.random(in: 0.3...0.6)
                    p.brightness = Double.random(in: 0.3...0.6)
                    p.opacity = CGFloat.random(in: 0.1...0.35)

                case .rain:
                    // Falling down, blue-gray
                    p.vx = CGFloat.random(in: -0.2...0.2)
                    p.vy = CGFloat.random(in: 1.0...3.0)
                    p.size = CGFloat.random(in: 1.5...3.5)
                    p.hue = Double.random(in: 210...230) / 360.0
                    p.saturation = 0.15
                    p.brightness = Double.random(in: 0.5...0.7)
                    p.opacity = CGFloat.random(in: 0.2...0.45)

                case .stars:
                    // Twinkling, barely moving, white-cyan-violet
                    p.vx = CGFloat.random(in: -0.15...0.15)
                    p.vy = CGFloat.random(in: -0.15...0.15)
                    p.size = CGFloat.random(in: 1...4)
                    p.hue = Double.random(in: 180...280) / 360.0
                    p.saturation = Double.random(in: 0.1...0.4)
                    p.brightness = Double.random(in: 0.6...1.0)
                    p.opacity = CGFloat.random(in: 0.2...0.7)
                    p.life = CGFloat.random(in: 0.4...1.0)

                case .warmth:
                    // Rising embers, orange-red glow
                    p.vx = CGFloat.random(in: -0.5...0.5)
                    p.vy = CGFloat.random(in: -1.8...-0.5)
                    p.size = CGFloat.random(in: 2...5)
                    p.hue = Double.random(in: 10...40) / 360.0
                    p.saturation = Double.random(in: 0.6...0.9)
                    p.brightness = Double.random(in: 0.5...0.8)
                    p.opacity = CGFloat.random(in: 0.15...0.4)

                case .crystal:
                    // Sharp, quick, bright white-blue
                    let angle = CGFloat.random(in: 0 ... (2.0 * CGFloat.pi))
                    let speed = CGFloat.random(in: 0.5...2.5)
                    p.vx = cos(angle) * speed
                    p.vy = sin(angle) * speed
                    p.size = CGFloat.random(in: 1...3)
                    p.hue = Double.random(in: 200...240) / 360.0
                    p.saturation = Double.random(in: 0.05...0.2)
                    p.brightness = Double.random(in: 0.7...1.0)
                    p.opacity = CGFloat.random(in: 0.3...0.6)
                    p.life = CGFloat.random(in: 0.3...0.7)

                case .cave:
                    // Slow floating dust, amber-brown
                    p.vx = CGFloat.random(in: -0.3...0.3)
                    p.vy = CGFloat.random(in: -0.5...0.3)
                    p.size = CGFloat.random(in: 2...5)
                    p.hue = Double.random(in: 25...45) / 360.0
                    p.saturation = Double.random(in: 0.3...0.5)
                    p.brightness = Double.random(in: 0.3...0.5)
                    p.opacity = CGFloat.random(in: 0.1...0.25)
                    p.life = CGFloat.random(in: 0.5...1.0)
                }

                particles.append(p)
            }
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let dt: CGFloat = frameTime > 0 ? CGFloat(now - frameTime) : 0.016
                frameTime = now

                // Spawn particles at each touch point
                for touch in touches {
                    worldStyle.spawn(at: touch.location, into: &particles)
                }

                // Update and draw particles
                var alive: [Particle] = []
                alive.reserveCapacity(particles.count)

                for var p in particles {
                    // Age
                    p.life -= dt * 0.8
                    guard p.life > 0 else { continue }

                    // Move
                    p.x += p.vx
                    p.y += p.vy

                    // Slight drag
                    p.vx *= 0.98
                    p.vy *= 0.98

                    // Fade
                    let alpha = p.opacity * p.life

                    // Draw glow
                    let glowSize = p.size * 3.0
                    let color = Color(hue: p.hue, saturation: p.saturation, brightness: p.brightness)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: p.x - glowSize / 2,
                            y: p.y - glowSize / 2,
                            width: glowSize,
                            height: glowSize
                        )),
                        with: .color(color.opacity(Double(alpha) * 0.2))
                    )

                    // Draw core
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: p.x - p.size / 2,
                            y: p.y - p.size / 2,
                            width: p.size,
                            height: p.size
                        )),
                        with: .color(color.opacity(Double(alpha)))
                    )

                    alive.append(p)
                }

                // Cap particle count for performance
                if alive.count > 300 {
                    alive.removeFirst(alive.count - 300)
                }
                particles = alive
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
