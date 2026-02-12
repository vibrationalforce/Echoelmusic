import SwiftUI

// MARK: - Vaporwave Visualizer
// Retro-futuristisches Neon Grid mit Audio-Reaktivität
// Inspired by: 80s aesthetic, Outrun, synthwave

struct VaporwaveVisualizer: View {
    let params: UnifiedVisualSoundEngine.VisualParameters
    let spectrum: [Float]

    @State private var gridOffset: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            Canvas { context, size in
                let time = params.time

                // Draw sunset gradient background
                drawSunsetBackground(context: context, size: size)

                // Draw sun
                drawSun(context: context, size: size, time: time)

                // Draw perspective grid
                drawPerspectiveGrid(context: context, size: size, time: time)

                // Draw spectrum bars on grid
                drawSpectrumOnGrid(context: context, size: size)

                // Draw neon lines
                drawNeonLines(context: context, size: size, time: time)

                // Draw scan lines overlay
                drawScanLines(context: context, size: size)
            }
        }
    }

    // MARK: - Sunset Background

    private func drawSunsetBackground(context: GraphicsContext, size: CGSize) {
        let gradient = Gradient(colors: [
            Color(red: 0.1, green: 0.0, blue: 0.2),   // Deep purple
            Color(red: 0.3, green: 0.0, blue: 0.3),   // Purple
            Color(red: 0.6, green: 0.1, blue: 0.3),   // Magenta
            Color(red: 1.0, green: 0.3, blue: 0.2),   // Orange
            Color(red: 1.0, green: 0.6, blue: 0.2),   // Yellow-orange
        ])

        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Rectangle().path(in: rect),
            with: .linearGradient(gradient, startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0, y: size.height))
        )
    }

    // MARK: - Sun

    private func drawSun(context: GraphicsContext, size: CGSize, time: Double) {
        let coherence = CGFloat(params.coherence)
        let energy = CGFloat(params.energy)

        let sunRadius = size.width * 0.15 * (1 + energy * 0.2)
        let sunCenter = CGPoint(x: size.width / 2, y: size.height * 0.35)

        // Sun gradient
        let sunGradient = Gradient(colors: [
            Color(red: 1.0, green: 0.9, blue: 0.3),   // Bright yellow
            Color(red: 1.0, green: 0.5, blue: 0.2),   // Orange
            Color(red: 1.0, green: 0.2, blue: 0.4),   // Pink-red
        ])

        // Outer glow
        let glowRadius = sunRadius * 1.5
        context.fill(
            Circle().path(in: CGRect(
                x: sunCenter.x - glowRadius,
                y: sunCenter.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.5),
                    Color.clear
                ]),
                center: sunCenter,
                startRadius: sunRadius * 0.8,
                endRadius: glowRadius
            )
        )

        // Main sun
        context.fill(
            Circle().path(in: CGRect(
                x: sunCenter.x - sunRadius,
                y: sunCenter.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            )),
            with: .radialGradient(sunGradient, center: sunCenter, startRadius: 0, endRadius: sunRadius)
        )

        // Sun stripes (vaporwave aesthetic)
        let stripeCount = 5
        for i in 0..<stripeCount {
            let stripeY = sunCenter.y + sunRadius * 0.3 + CGFloat(i) * sunRadius * 0.15
            let stripeWidth = sqrt(sunRadius * sunRadius - pow(stripeY - sunCenter.y, 2)) * 2

            if stripeWidth > 0 {
                var stripePath = Path()
                stripePath.move(to: CGPoint(x: sunCenter.x - stripeWidth / 2, y: stripeY))
                stripePath.addLine(to: CGPoint(x: sunCenter.x + stripeWidth / 2, y: stripeY))

                context.stroke(
                    stripePath,
                    with: .color(Color(red: 0.1, green: 0.0, blue: 0.2)),
                    lineWidth: sunRadius * 0.08
                )
            }
        }
    }

    // MARK: - Perspective Grid

    private func drawPerspectiveGrid(context: GraphicsContext, size: CGSize, time: Double) {
        let horizonY = size.height * 0.5
        let vanishingPoint = CGPoint(x: size.width / 2, y: horizonY)

        let gridColor = VaporwaveColors.neonCyan.opacity(0.6 + Double(params.audioLevel) * 0.4)

        // Horizontal lines with perspective
        let lineCount = 20
        let animatedOffset = CGFloat(time.truncatingRemainder(dividingBy: 1.0))

        for i in 0..<lineCount {
            let progress = (CGFloat(i) + animatedOffset) / CGFloat(lineCount)
            let y = horizonY + pow(progress, 2) * (size.height - horizonY)

            // Audio modulation
            let audioMod = spectrum.count > i ? CGFloat(spectrum[i]) * 5 : 0

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y + audioMod))
            path.addLine(to: CGPoint(x: size.width, y: y + audioMod))

            let lineWidth = 1 + progress * 2
            context.stroke(path, with: .color(gridColor), lineWidth: lineWidth)
        }

        // Vertical lines converging to vanishing point
        let vLineCount = 15
        for i in 0...vLineCount {
            let bottomX = CGFloat(i) / CGFloat(vLineCount) * size.width

            var path = Path()
            path.move(to: CGPoint(x: bottomX, y: size.height))
            path.addLine(to: vanishingPoint)

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }

    // MARK: - Spectrum on Grid

    private func drawSpectrumOnGrid(context: GraphicsContext, size: CGSize) {
        guard !spectrum.isEmpty else { return }

        let horizonY = size.height * 0.5
        let barCount = min(32, spectrum.count)
        let barWidth = size.width / CGFloat(barCount)

        for i in 0..<barCount {
            let magnitude = CGFloat(spectrum[i])
            let barHeight = magnitude * size.height * 0.3

            let x = CGFloat(i) * barWidth
            let y = horizonY

            // Bar gradient (neon)
            let hue = Double(i) / Double(barCount) * 0.3 + Double(params.colorHue)

            let rect = CGRect(x: x, y: y, width: barWidth - 2, height: barHeight)

            // Glow
            context.fill(
                Rectangle().path(in: rect.insetBy(dx: -2, dy: -2)),
                with: .color(Color(hue: hue, saturation: 0.9, brightness: 1.0).opacity(0.3))
            )

            // Bar
            context.fill(
                Rectangle().path(in: rect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: 0.8, brightness: 0.8),
                        Color(hue: hue + 0.1, saturation: 0.9, brightness: 1.0)
                    ]),
                    startPoint: .init(x: x, y: y + barHeight),
                    endPoint: .init(x: x, y: y)
                )
            )
        }
    }

    // MARK: - Neon Lines

    private func drawNeonLines(context: GraphicsContext, size: CGSize, time: Double) {
        let energy = CGFloat(params.energy)
        let coherence = CGFloat(params.coherence)

        // Side neon lines that pulse with audio
        let lineColors: [Color] = [
            VaporwaveColors.neonPink,
            VaporwaveColors.neonCyan,
            VaporwaveColors.neonPurple
        ]

        for (index, color) in lineColors.enumerated() {
            let offset = CGFloat(index) * 10
            let pulse = sin(time * 3 + Double(index)) * 0.3 + 0.7

            // Left line
            var leftPath = Path()
            leftPath.move(to: CGPoint(x: 30 + offset, y: 0))
            leftPath.addLine(to: CGPoint(x: 30 + offset, y: size.height))

            // Right line
            var rightPath = Path()
            rightPath.move(to: CGPoint(x: size.width - 30 - offset, y: 0))
            rightPath.addLine(to: CGPoint(x: size.width - 30 - offset, y: size.height))

            let lineWidth = 2 + energy * 3

            // Glow
            context.stroke(leftPath, with: .color(color.opacity(0.3 * pulse)), lineWidth: lineWidth * 3)
            context.stroke(rightPath, with: .color(color.opacity(0.3 * pulse)), lineWidth: lineWidth * 3)

            // Core
            context.stroke(leftPath, with: .color(color.opacity(pulse)), lineWidth: lineWidth)
            context.stroke(rightPath, with: .color(color.opacity(pulse)), lineWidth: lineWidth)
        }
    }

    // MARK: - Scan Lines

    private func drawScanLines(context: GraphicsContext, size: CGSize) {
        // CRT scan line effect
        let lineSpacing: CGFloat = 3

        context.withCGContext { cg in
            cg.setFillColor(CGColor(gray: 0, alpha: 0.15))

            var y: CGFloat = 0
            while y < size.height {
                cg.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += lineSpacing
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VaporwaveVisualizer(
        params: UnifiedVisualSoundEngine.VisualParameters(
            audioLevel: 0.6,
            bassLevel: 0.7,
            coherence: 0.8,
            energy: 0.7,
            colorHue: 0.5,
            time: 0
        ),
        spectrum: (0..<64).map { Float.random(in: 0...1) * (1.0 - Float($0) / 64.0) }
    )
    .frame(height: 400)
}
#endif
