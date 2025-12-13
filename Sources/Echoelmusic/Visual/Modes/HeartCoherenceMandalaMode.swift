import SwiftUI

/// Heart Coherence Mandala Mode
/// Radial mandala pattern that pulsates with heart rate
/// Coherence level controls symmetry and complexity
/// HRV maps to color gradients
struct HeartCoherenceMandalaMode: View {
    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Detected frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100)
    var hrvCoherence: Double

    /// Heart Rate (BPM)
    var heartRate: Double

    /// HRV value in milliseconds
    var hrvMs: Double = 50.0

    @State private var pulsePhase: Double = 0
    @State private var lastBeatTime: Date = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2 - 20
                let time = timeline.date.timeIntervalSince1970

                // Calculate pulse based on heart rate
                let beatsPerSecond = heartRate / 60.0
                let pulsePhase = (time * beatsPerSecond * 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
                let pulseFactor = 1.0 + sin(pulsePhase) * 0.1

                // Draw background glow based on coherence
                drawCoherenceGlow(context: context, center: center, radius: maxRadius, coherence: hrvCoherence)

                // Draw mandala layers
                let layerCount = coherenceToLayerCount(hrvCoherence)
                for layer in 0..<layerCount {
                    let layerRadius = maxRadius * CGFloat(layerCount - layer) / CGFloat(layerCount) * pulseFactor
                    drawMandalaLayer(
                        context: context,
                        center: center,
                        radius: layerRadius,
                        layer: layer,
                        time: time,
                        coherence: hrvCoherence
                    )
                }

                // Draw central heart
                drawHeartCenter(context: context, center: center, pulsePhase: pulsePhase, coherence: hrvCoherence)

                // Draw HRV indicator ring
                drawHRVRing(context: context, center: center, radius: maxRadius * 0.3, hrvMs: hrvMs)

                // Draw heart rate display
                drawHeartRateDisplay(context: context, size: size, heartRate: heartRate)

                // Draw coherence score
                drawCoherenceScore(context: context, size: size, coherence: hrvCoherence)
            }
        }
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Coherence to Visual Mappings

    /// Map coherence to number of mandala layers (more coherence = more complex)
    private func coherenceToLayerCount(_ coherence: Double) -> Int {
        return 3 + Int(coherence / 20) // 3-8 layers
    }

    /// Map coherence to petal count (more coherence = more symmetry)
    private func coherenceToPetalCount(_ coherence: Double, layer: Int) -> Int {
        let base = 6 + layer * 2
        let coherenceBonus = Int(coherence / 25)
        return base + coherenceBonus
    }

    /// Map coherence to color
    private func coherenceToColor(_ coherence: Double) -> Color {
        // Low coherence: red/orange, High coherence: green/cyan
        let hue: Double
        if coherence < 30 {
            hue = 0.0 + coherence / 30 * 0.1 // Red to orange
        } else if coherence < 60 {
            hue = 0.1 + (coherence - 30) / 30 * 0.2 // Orange to yellow-green
        } else {
            hue = 0.3 + (coherence - 60) / 40 * 0.2 // Green to cyan
        }

        return Color(hue: hue, saturation: 0.7, brightness: 0.85)
    }

    // MARK: - Drawing Functions

    private func drawCoherenceGlow(context: GraphicsContext, center: CGPoint, radius: CGFloat, coherence: Double) {
        let color = coherenceToColor(coherence)
        let glowRadius = radius * (1.0 + CGFloat(coherence) / 200)

        for i in (0..<5).reversed() {
            let layerRadius = glowRadius * (1.0 - CGFloat(i) * 0.15)
            let opacity = 0.15 - Double(i) * 0.025

            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - layerRadius,
                y: center.y - layerRadius,
                width: layerRadius * 2,
                height: layerRadius * 2
            ))

            context.fill(path, with: .color(color.opacity(opacity)))
        }
    }

    private func drawMandalaLayer(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        layer: Int,
        time: Double,
        coherence: Double
    ) {
        let petalCount = coherenceToPetalCount(coherence, layer: layer)
        let color = coherenceToColor(coherence)

        // Rotation: layers rotate at different speeds, coherence affects smoothness
        let rotationSpeed = 0.1 + Double(layer) * 0.05
        let coherenceSmoothing = coherence / 100.0
        let rotation = time * rotationSpeed * (0.5 + coherenceSmoothing * 0.5)

        // Draw petals
        for i in 0..<petalCount {
            let angle = rotation + Double(i) / Double(petalCount) * 2 * .pi

            // Petal shape based on layer
            let petalLength = radius * 0.4
            let petalWidth = radius * 0.15 * (1.0 + CGFloat(coherence) / 200)

            drawPetal(
                context: context,
                center: center,
                angle: angle,
                length: petalLength,
                width: petalWidth,
                color: color,
                layer: layer
            )
        }

        // Draw layer ring
        var ringPath = Path()
        ringPath.addEllipse(in: CGRect(
            x: center.x - radius * 0.7,
            y: center.y - radius * 0.7,
            width: radius * 1.4,
            height: radius * 1.4
        ))
        context.stroke(ringPath, with: .color(color.opacity(0.3)), lineWidth: 1)
    }

    private func drawPetal(
        context: GraphicsContext,
        center: CGPoint,
        angle: Double,
        length: CGFloat,
        width: CGFloat,
        color: Color,
        layer: Int
    ) {
        var path = Path()

        let tipX = center.x + cos(angle) * length
        let tipY = center.y + sin(angle) * length

        let perpAngle = angle + .pi / 2
        let baseOffset = length * 0.3

        let baseX = center.x + cos(angle) * baseOffset
        let baseY = center.y + sin(angle) * baseOffset

        let leftX = baseX + cos(perpAngle) * width / 2
        let leftY = baseY + sin(perpAngle) * width / 2
        let rightX = baseX - cos(perpAngle) * width / 2
        let rightY = baseY - sin(perpAngle) * width / 2

        path.move(to: CGPoint(x: tipX, y: tipY))
        path.addQuadCurve(
            to: CGPoint(x: leftX, y: leftY),
            control: CGPoint(
                x: (tipX + leftX) / 2 + cos(perpAngle) * width * 0.3,
                y: (tipY + leftY) / 2 + sin(perpAngle) * width * 0.3
            )
        )
        path.addQuadCurve(
            to: CGPoint(x: rightX, y: rightY),
            control: CGPoint(x: baseX, y: baseY)
        )
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: tipY),
            control: CGPoint(
                x: (tipX + rightX) / 2 - cos(perpAngle) * width * 0.3,
                y: (tipY + rightY) / 2 - sin(perpAngle) * width * 0.3
            )
        )

        let opacity = 0.3 + Double(layer) * 0.1
        context.fill(path, with: .color(color.opacity(opacity)))
        context.stroke(path, with: .color(color.opacity(opacity + 0.3)), lineWidth: 1)
    }

    private func drawHeartCenter(context: GraphicsContext, center: CGPoint, pulsePhase: Double, coherence: Double) {
        let baseSize: CGFloat = 30
        let pulseFactor = 1.0 + sin(pulsePhase) * 0.3
        let size = baseSize * pulseFactor

        let color = coherenceToColor(coherence)

        // Draw heart shape
        let heartPath = createHeartPath(center: center, size: size)

        // Glow
        context.fill(heartPath, with: .color(color.opacity(0.5)))

        // Fill
        context.fill(heartPath, with: .color(color))

        // Stroke
        context.stroke(heartPath, with: .color(.white.opacity(0.8)), lineWidth: 2)
    }

    private func createHeartPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()

        let width = size
        let height = size * 0.9

        // Heart shape using bezier curves
        path.move(to: CGPoint(x: center.x, y: center.y + height * 0.35))

        // Left curve
        path.addCurve(
            to: CGPoint(x: center.x - width * 0.5, y: center.y - height * 0.15),
            control1: CGPoint(x: center.x - width * 0.1, y: center.y + height * 0.35),
            control2: CGPoint(x: center.x - width * 0.5, y: center.y + height * 0.1)
        )

        // Left top curve
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - height * 0.35),
            control1: CGPoint(x: center.x - width * 0.5, y: center.y - height * 0.4),
            control2: CGPoint(x: center.x - width * 0.15, y: center.y - height * 0.35)
        )

        // Right top curve
        path.addCurve(
            to: CGPoint(x: center.x + width * 0.5, y: center.y - height * 0.15),
            control1: CGPoint(x: center.x + width * 0.15, y: center.y - height * 0.35),
            control2: CGPoint(x: center.x + width * 0.5, y: center.y - height * 0.4)
        )

        // Right curve
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + height * 0.35),
            control1: CGPoint(x: center.x + width * 0.5, y: center.y + height * 0.1),
            control2: CGPoint(x: center.x + width * 0.1, y: center.y + height * 0.35)
        )

        return path
    }

    private func drawHRVRing(context: GraphicsContext, center: CGPoint, radius: CGFloat, hrvMs: Double) {
        // HRV variability visualization as irregular ring
        var path = Path()
        let segments = 60

        for i in 0...segments {
            let angle = Double(i) / Double(segments) * 2 * .pi
            // Vary radius based on simulated HRV variability
            let variation = sin(Double(i) * 0.5) * hrvMs / 200
            let r = radius * (1.0 + CGFloat(variation))

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.stroke(path, with: .color(Color.cyan.opacity(0.5)), lineWidth: 2)
    }

    private func drawHeartRateDisplay(context: GraphicsContext, size: CGSize, heartRate: Double) {
        let x: CGFloat = 20
        let y: CGFloat = 20

        // Heart icon
        let miniHeart = createHeartPath(center: CGPoint(x: x + 10, y: y + 10), size: 15)
        context.fill(miniHeart, with: .color(.red))

        // Heart rate text
        let hrText = Text("\(Int(heartRate)) BPM")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
        context.draw(hrText, at: CGPoint(x: x + 50, y: y + 10))
    }

    private func drawCoherenceScore(context: GraphicsContext, size: CGSize, coherence: Double) {
        let x = size.width - 100
        let y: CGFloat = 20

        let color = coherenceToColor(coherence)

        // Coherence label
        let labelText = Text("Coherence")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        context.draw(labelText, at: CGPoint(x: x + 40, y: y))

        // Score
        let scoreText = Text("\(Int(coherence))")
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundColor(color)
        context.draw(scoreText, at: CGPoint(x: x + 40, y: y + 30))

        // Level indicator
        let level: String
        if coherence >= 70 {
            level = "High"
        } else if coherence >= 40 {
            level = "Medium"
        } else {
            level = "Low"
        }

        let levelText = Text(level)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
        context.draw(levelText, at: CGPoint(x: x + 40, y: y + 55))
    }
}
