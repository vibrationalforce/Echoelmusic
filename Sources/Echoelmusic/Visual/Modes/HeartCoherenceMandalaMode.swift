import SwiftUI

/// Heart Coherence Mandala Mode
/// A radial mandala pattern that pulsates with heart rate
/// Symmetry degree reflects HRV coherence, colors shift with HRV state
struct HeartCoherenceMandalaMode: View {

    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Dominant frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100) - drives symmetry and stability
    var hrvCoherence: Double

    /// Heart rate (BPM) - drives pulsation rhythm
    var heartRate: Double

    /// HRV RMSSD (ms) - drives color intensity
    var hrvRMSSD: Double = 50

    /// Number of mandala layers
    @State private var layerCount: Int = 7

    /// Petal count per layer (varies with coherence)
    private var petalCount: Int {
        // Higher coherence = more petals (more symmetry)
        let baseCount = 6
        let coherenceBonus = Int(hrvCoherence / 100.0 * 12)
        return baseCount + coherenceBonus // 6-18 petals
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2.2

                // Draw background gradient based on coherence state
                drawCoherenceBackground(context: context, size: size, time: time)

                // Draw heart pulse ring
                drawHeartPulseRing(context: context, center: center, radius: maxRadius, time: time)

                // Draw mandala layers from outside to inside
                for layer in (0..<layerCount).reversed() {
                    let layerRadius = maxRadius * (1.0 - CGFloat(layer) * 0.12)
                    drawMandalaLayer(
                        context: context,
                        center: center,
                        radius: layerRadius,
                        layer: layer,
                        time: time
                    )
                }

                // Draw center heart
                drawCenterHeart(context: context, center: center, time: time)

                // Draw coherence particles
                drawCoherenceParticles(context: context, center: center, radius: maxRadius, time: time)

                // Draw HRV indicator ring
                drawHRVIndicator(context: context, center: center, radius: maxRadius * 0.15, time: time)
            }
        }
        .background(Color.black)
    }

    // MARK: - Coherence Background

    private func drawCoherenceBackground(context: GraphicsContext, size: CGSize, time: Double) {
        // Background color shifts from warm (stress) to cool (coherence)
        let coherenceNorm = hrvCoherence / 100.0
        let hue = 0.0 + coherenceNorm * 0.6 // Red to cyan

        // Subtle pulse with heart rate
        let pulse = sin(time * heartRate / 60.0 * 2 * .pi) * 0.1 + 0.9

        let gradient = Gradient(colors: [
            Color(hue: hue, saturation: 0.3, brightness: 0.15 * pulse),
            Color.black
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: size.width/2, y: size.height/2),
                startRadius: 0,
                endRadius: max(size.width, size.height)
            )
        )
    }

    // MARK: - Heart Pulse Ring

    private func drawHeartPulseRing(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Pulsating ring that follows heartbeat
        let heartPhase = time * heartRate / 60.0 * 2 * .pi
        let pulse = (sin(heartPhase) + 1) / 2  // 0-1

        // Expand ring on beat
        let ringRadius = radius + CGFloat(pulse) * 20
        let lineWidth = 2.0 + CGFloat(pulse) * 3.0
        let alpha = 0.3 + pulse * 0.4

        var ringPath = Path()
        ringPath.addEllipse(in: CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))

        // Color based on coherence
        let hue = hrvCoherence / 100.0 * 0.3
        let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

        context.stroke(
            ringPath,
            with: .color(color.opacity(alpha)),
            style: StrokeStyle(lineWidth: lineWidth)
        )

        // Inner glow
        context.stroke(
            ringPath,
            with: .color(color.opacity(alpha * 0.3)),
            style: StrokeStyle(lineWidth: lineWidth * 3)
        )
    }

    // MARK: - Mandala Layer

    private func drawMandalaLayer(context: GraphicsContext, center: CGPoint, radius: CGFloat, layer: Int, time: Double) {
        // Rotation speed varies by layer (inner layers rotate faster)
        let rotationSpeed = 0.1 * Double(layerCount - layer)
        let rotation = time * rotationSpeed

        // Petal count varies with coherence
        let petals = petalCount - layer  // Outer layers have more petals

        // Layer-specific styling
        let layerHue = (hrvCoherence / 100.0 * 0.3) + Double(layer) / Double(layerCount) * 0.3
        let coherenceStability = hrvCoherence / 100.0

        // Symmetry breaks down with low coherence
        let asymmetryFactor = (1.0 - coherenceStability) * 0.1

        for i in 0..<petals {
            let baseAngle = Double(i) / Double(petals) * 2 * .pi

            // Add slight asymmetry for low coherence
            let asymmetry = sin(Double(i) * 3.14) * asymmetryFactor
            let angle = baseAngle + rotation + asymmetry

            // Petal size pulsates with heart rate
            let heartPhase = time * heartRate / 60.0 * 2 * .pi
            let pulse = (sin(heartPhase + Double(layer) * 0.5) + 1) / 2

            // Audio modulation
            let audioMod = 1.0 + Double(audioLevel) * 0.3

            let petalLength = radius * 0.3 * (0.8 + pulse * 0.4) * audioMod
            let petalWidth = radius * 0.1 * (0.8 + pulse * 0.2)

            drawPetal(
                context: context,
                center: center,
                angle: angle,
                distance: radius * 0.7,
                length: petalLength,
                width: petalWidth,
                hue: layerHue,
                layer: layer,
                petalIndex: i
            )
        }

        // Draw connecting ring between layers
        drawLayerRing(context: context, center: center, radius: radius * 0.85, layer: layer, time: time)
    }

    private func drawPetal(context: GraphicsContext, center: CGPoint, angle: Double, distance: CGFloat, length: CGFloat, width: CGFloat, hue: Double, layer: Int, petalIndex: Int) {

        // Calculate petal center position
        let petalCenter = CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )

        // Create petal shape (ellipse rotated to point outward)
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: petalCenter.x, y: petalCenter.y)
        transform = transform.rotated(by: angle + .pi / 2)

        var petalPath = Path()
        petalPath.addEllipse(in: CGRect(
            x: -width/2,
            y: -length/2,
            width: width,
            height: length
        ))

        let transformedPath = petalPath.applying(transform)

        // Gradient fill
        let saturation = 0.6 + (hrvCoherence / 100.0) * 0.3
        let brightness = 0.7 + Double(audioLevel) * 0.2

        let petalColor = Color(hue: hue + Double(petalIndex) * 0.01, saturation: saturation, brightness: brightness)

        // Fill with gradient
        context.fill(
            transformedPath,
            with: .color(petalColor.opacity(0.7))
        )

        // Stroke outline
        context.stroke(
            transformedPath,
            with: .color(petalColor.opacity(0.9)),
            style: StrokeStyle(lineWidth: 1)
        )
    }

    private func drawLayerRing(context: GraphicsContext, center: CGPoint, radius: CGFloat, layer: Int, time: Double) {
        var ringPath = Path()
        ringPath.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        let hue = hrvCoherence / 100.0 * 0.3 + Double(layer) * 0.05
        let alpha = 0.1 + (hrvCoherence / 100.0) * 0.2

        context.stroke(
            ringPath,
            with: .color(Color(hue: hue, saturation: 0.5, brightness: 0.7).opacity(alpha)),
            style: StrokeStyle(lineWidth: 1)
        )
    }

    // MARK: - Center Heart

    private func drawCenterHeart(context: GraphicsContext, center: CGPoint, time: Double) {
        // Heart pulse animation
        let heartPhase = time * heartRate / 60.0 * 2 * .pi
        let pulse = (sin(heartPhase) + 1) / 2

        let baseSize: CGFloat = 30
        let size = baseSize * (1.0 + CGFloat(pulse) * 0.3)

        // Draw glowing heart shape
        let heartPath = createHeartPath(center: center, size: size)

        // Glow layers
        for glowLayer in 0..<4 {
            let glowAlpha = 0.1 * (1.0 - Double(glowLayer) / 4.0) * (0.5 + pulse * 0.5)
            let glowScale = 1.0 + Double(glowLayer) * 0.3

            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: center.x, y: center.y)
            transform = transform.scaledBy(x: glowScale, y: glowScale)
            transform = transform.translatedBy(x: -center.x, y: -center.y)

            let scaledPath = heartPath.applying(transform)

            // Color based on coherence
            let heartHue = hrvCoherence > 50 ? 0.95 : 0.0  // Pink for high coherence, red for low
            context.fill(
                scaledPath,
                with: .color(Color(hue: heartHue, saturation: 0.8, brightness: 0.9).opacity(glowAlpha))
            )
        }

        // Main heart fill
        let heartColor = hrvCoherence > 50
            ? Color(hue: 0.95, saturation: 0.7, brightness: 0.9)  // Pink
            : Color(hue: 0.0, saturation: 0.8, brightness: 0.8)   // Red

        context.fill(heartPath, with: .color(heartColor))

        // Draw heart rate text
        let hrText = Text("\(Int(heartRate))")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)

        context.draw(hrText, at: CGPoint(x: center.x, y: center.y + 2))
    }

    private func createHeartPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()

        let topY = center.y - size * 0.3
        let bottomY = center.y + size * 0.5

        // Start at bottom point
        path.move(to: CGPoint(x: center.x, y: bottomY))

        // Left curve
        path.addCurve(
            to: CGPoint(x: center.x - size * 0.5, y: topY),
            control1: CGPoint(x: center.x - size * 0.2, y: center.y + size * 0.2),
            control2: CGPoint(x: center.x - size * 0.5, y: center.y - size * 0.1)
        )

        // Left top bump
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - size * 0.15),
            control1: CGPoint(x: center.x - size * 0.5, y: topY - size * 0.3),
            control2: CGPoint(x: center.x - size * 0.15, y: topY - size * 0.15)
        )

        // Right top bump
        path.addCurve(
            to: CGPoint(x: center.x + size * 0.5, y: topY),
            control1: CGPoint(x: center.x + size * 0.15, y: topY - size * 0.15),
            control2: CGPoint(x: center.x + size * 0.5, y: topY - size * 0.3)
        )

        // Right curve
        path.addCurve(
            to: CGPoint(x: center.x, y: bottomY),
            control1: CGPoint(x: center.x + size * 0.5, y: center.y - size * 0.1),
            control2: CGPoint(x: center.x + size * 0.2, y: center.y + size * 0.2)
        )

        return path
    }

    // MARK: - Coherence Particles

    private func drawCoherenceParticles(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Particles flow inward with high coherence, scatter with low coherence
        let particleCount = 50 + Int(hrvCoherence / 2)
        let coherenceNorm = hrvCoherence / 100.0

        for i in 0..<particleCount {
            // Particle position varies based on coherence
            let baseAngle = Double(i) / Double(particleCount) * 2 * .pi + time * 0.3
            let variation = (1.0 - coherenceNorm) * sin(Double(i) * 2.7 + time)

            let angle = baseAngle + variation

            // Distance from center
            let baseDistance = radius * (0.3 + Double(i % 10) / 10.0 * 0.6)
            let distanceVariation = sin(time * 2 + Double(i)) * 20 * (1 - coherenceNorm)
            let distance = baseDistance + distanceVariation

            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance

            // Particle size and opacity
            let size = 2.0 + coherenceNorm * 2.0 + Double(audioLevel) * 2.0
            let alpha = 0.2 + coherenceNorm * 0.4

            // Color based on position and coherence
            let hue = coherenceNorm * 0.3 + (distance / radius) * 0.2

            let particlePath = Path(ellipseIn: CGRect(
                x: x - size/2,
                y: y - size/2,
                width: size,
                height: size
            ))

            context.fill(
                particlePath,
                with: .color(Color(hue: hue, saturation: 0.6, brightness: 0.9).opacity(alpha))
            )
        }
    }

    // MARK: - HRV Indicator

    private func drawHRVIndicator(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Small indicator showing HRV RMSSD value
        let indicatorCenter = CGPoint(x: center.x, y: center.y + radius * 5)

        // Background circle
        let bgPath = Path(ellipseIn: CGRect(
            x: indicatorCenter.x - radius,
            y: indicatorCenter.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        context.fill(bgPath, with: .color(Color.white.opacity(0.1)))

        // HRV arc
        let hrvNorm = min(hrvRMSSD / 100.0, 1.0)
        let endAngle = Angle(degrees: -90 + hrvNorm * 360)

        var arcPath = Path()
        arcPath.addArc(
            center: indicatorCenter,
            radius: radius - 3,
            startAngle: .degrees(-90),
            endAngle: endAngle,
            clockwise: false
        )

        let hrvColor = hrvNorm > 0.5
            ? Color.green
            : (hrvNorm > 0.3 ? Color.yellow : Color.red)

        context.stroke(
            arcPath,
            with: .color(hrvColor),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )

        // HRV text
        let hrvText = Text("HRV")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.gray)

        context.draw(hrvText, at: CGPoint(x: indicatorCenter.x, y: indicatorCenter.y - 4))

        let valueText = Text("\(Int(hrvRMSSD))")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white)

        context.draw(valueText, at: CGPoint(x: indicatorCenter.x, y: indicatorCenter.y + 6))
    }
}


// MARK: - Preview

#Preview("High Coherence") {
    HeartCoherenceMandalaMode(
        audioLevel: 0.5,
        frequency: 432,
        hrvCoherence: 85,
        heartRate: 65,
        hrvRMSSD: 70
    )
}

#Preview("Low Coherence") {
    HeartCoherenceMandalaMode(
        audioLevel: 0.7,
        frequency: 440,
        hrvCoherence: 25,
        heartRate: 90,
        hrvRMSSD: 30
    )
}
