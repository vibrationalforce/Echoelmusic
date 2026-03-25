#if canImport(SwiftUI)
import SwiftUI

/// Bouncing rhythm orbs that pulse across the screen synced to BPM.
/// Parabolic arcs (gravity-like) make the motion feel natural.
/// Can be used as BPM metronome or breath-pacing visual guide.
struct RhythmOrbsView: View {

    let bpm: Double
    let orbCount: Int
    let color: Color

    init(bpm: Double = 120.0, orbCount: Int = 4, color: Color = Color.white.opacity(0.15)) {
        self.bpm = bpm
        self.orbCount = orbCount
        self.color = color
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let beatDuration = 60.0 / max(bpm, 20.0)

                for i in 0..<orbCount {
                    let phaseOffset = Double(i) / Double(orbCount)
                    drawOrb(
                        context: context,
                        size: size,
                        time: now,
                        beatDuration: beatDuration,
                        phaseOffset: phaseOffset,
                        orbIndex: i
                    )
                }
            }
        }
        .allowsHitTesting(false) // Orbs don't interfere with touch
    }

    private func drawOrb(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        beatDuration: TimeInterval,
        phaseOffset: Double,
        orbIndex: Int
    ) {
        // t = position within beat (0-1)
        let totalPhase = time / beatDuration + phaseOffset
        let t = totalPhase.truncatingRemainder(dividingBy: 1.0)

        // X: linear sweep left-to-right
        let x = CGFloat(t) * size.width

        // Y: parabolic arc — ball "falls" into each beat, "bounces" to next
        // y = -4h * t * (t-1) gives a nice parabola peaking at t=0.5
        let bounceHeight = size.height * 0.3 // 30% of screen height
        let baseY = size.height * 0.15 // top area
        let parabola = -4.0 * CGFloat(t) * (CGFloat(t) - 1.0) // 0→1→0
        let y = baseY + bounceHeight * (1.0 - parabola)

        // Size: slightly larger at apex, smaller at edges
        let baseSize: CGFloat = 8.0
        let sizeMultiplier = 0.7 + parabola * 0.6 // 0.7-1.3
        let orbSize = baseSize * sizeMultiplier

        // Opacity: brighter at apex
        let opacity = 0.3 + parabola * 0.5 // 0.3-0.8

        // Trail: fading dots behind the orb
        let trailCount = 5
        for trail in 0..<trailCount {
            let trailT = t - Double(trail + 1) * 0.02
            guard trailT > 0 else { continue }
            let trailX = CGFloat(trailT) * size.width
            let trailParabola = -4.0 * CGFloat(trailT) * (CGFloat(trailT) - 1.0)
            let trailY = baseY + bounceHeight * (1.0 - trailParabola)
            let trailOpacity = opacity * (1.0 - Double(trail + 1) / Double(trailCount + 1)) * 0.3
            let trailSize = orbSize * 0.6

            let trailRect = CGRect(
                x: trailX - trailSize / 2,
                y: trailY - trailSize / 2,
                width: trailSize,
                height: trailSize
            )
            context.fill(
                Path(ellipseIn: trailRect),
                with: .color(color.opacity(trailOpacity))
            )
        }

        // Main orb
        let orbRect = CGRect(
            x: x - orbSize / 2,
            y: y - orbSize / 2,
            width: orbSize,
            height: orbSize
        )
        context.fill(
            Path(ellipseIn: orbRect),
            with: .color(color.opacity(opacity))
        )

        // Glow effect: larger, softer circle behind
        let glowSize = orbSize * 2.5
        let glowRect = CGRect(
            x: x - glowSize / 2,
            y: y - glowSize / 2,
            width: glowSize,
            height: glowSize
        )
        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(color.opacity(opacity * 0.15))
        )
    }
}
#endif
