import SwiftUI

/// Sacred Geometry visualization mode
/// Features Golden Ratio spirals, Fibonacci patterns, and Metatron's Cube
/// Audio frequency controls rotation speed, HRV controls color shifts
struct SacredGeometryMode: View {

    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Dominant frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100)
    var hrvCoherence: Double

    /// Heart rate (BPM)
    var heartRate: Double

    /// Pattern type selection
    @State private var patternType: SacredPattern = .goldenSpiral

    /// Animation phase
    @State private var animationPhase: Double = 0

    enum SacredPattern: String, CaseIterable {
        case goldenSpiral = "Golden Spiral"
        case fibonacciFlower = "Fibonacci Flower"
        case metatronsCube = "Metatron's Cube"
        case flowerOfLife = "Flower of Life"
    }

    // Sacred geometry constants
    private let phi: CGFloat = 1.618033988749895  // Golden Ratio
    private let fibonacci: [Int] = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) / 2.5
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Update animation phase based on frequency
                let rotationSpeed = Double(frequency) / 500.0 // Higher freq = faster rotation

                // Draw background glow
                drawBackgroundGlow(context: context, center: center, size: size, time: time)

                // Draw selected pattern
                switch patternType {
                case .goldenSpiral:
                    drawGoldenSpiral(context: context, center: center, radius: baseRadius, time: time, rotationSpeed: rotationSpeed)
                case .fibonacciFlower:
                    drawFibonacciFlower(context: context, center: center, radius: baseRadius, time: time, rotationSpeed: rotationSpeed)
                case .metatronsCube:
                    drawMetatronsCube(context: context, center: center, radius: baseRadius, time: time, rotationSpeed: rotationSpeed)
                case .flowerOfLife:
                    drawFlowerOfLife(context: context, center: center, radius: baseRadius, time: time, rotationSpeed: rotationSpeed)
                }

                // Overlay audio-reactive particles
                drawSacredParticles(context: context, center: center, radius: baseRadius, time: time)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color(hue: hrvCoherence / 200.0, saturation: 0.3, brightness: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cyclePattern()
                    }
                }
        )
    }

    // MARK: - Background Glow

    private func drawBackgroundGlow(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let glowRadius = min(size.width, size.height) * 0.4
        let coherenceNorm = hrvCoherence / 100.0

        // Pulsing glow based on heart rate
        let pulse = sin(time * heartRate / 30.0 * .pi) * 0.3 + 0.7

        let gradient = Gradient(colors: [
            Color(hue: coherenceNorm * 0.5, saturation: 0.6, brightness: 0.4 * pulse).opacity(0.3),
            Color.clear
        ])

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )
    }

    // MARK: - Golden Spiral

    private func drawGoldenSpiral(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, rotationSpeed: Double) {
        var path = Path()
        let segments = 200
        let maxAngle = 6.0 * .pi // 3 full rotations

        let rotation = time * rotationSpeed

        for i in 0..<segments {
            let t = Double(i) / Double(segments) * maxAngle
            let r = pow(phi, CGFloat(t / (0.5 * .pi))) * 5

            let angle = t + rotation
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Color based on HRV
        let hue = hrvCoherence / 100.0 * 0.3 + 0.1
        let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

        // Line width based on audio
        let lineWidth = 2.0 + CGFloat(audioLevel) * 4.0

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        // Draw golden rectangles
        drawGoldenRectangles(context: context, center: center, time: time, rotationSpeed: rotationSpeed)
    }

    private func drawGoldenRectangles(context: GraphicsContext, center: CGPoint, time: Double, rotationSpeed: Double) {
        let rotation = time * rotationSpeed
        var currentSize: CGFloat = 100

        for i in 0..<8 {
            let angle = Double(i) * 0.5 * .pi + rotation

            // Calculate rectangle position using Fibonacci-like growth
            let offset = currentSize * (phi - 1)

            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: center.x, y: center.y)
            transform = transform.rotated(by: angle)

            var rectPath = Path()
            rectPath.addRect(CGRect(x: -currentSize/2, y: -currentSize/2, width: currentSize, height: currentSize/phi))

            let transformedPath = rectPath.applying(transform)

            let hue = (hrvCoherence / 100.0 * 0.3) + Double(i) * 0.05
            let alpha = 0.3 + CGFloat(audioLevel) * 0.3

            context.stroke(
                transformedPath,
                with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.8).opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.5)
            )

            currentSize = currentSize / phi
        }
    }

    // MARK: - Fibonacci Flower

    private func drawFibonacciFlower(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, rotationSpeed: Double) {
        let goldenAngle = .pi * 2 * (1 - 1/phi) // ~137.5 degrees
        let seedCount = 200 + Int(audioLevel * 100) // 200-300 seeds

        let rotation = time * rotationSpeed * 0.2

        for i in 0..<seedCount {
            let angle = Double(i) * goldenAngle + rotation
            let r = sqrt(Double(i)) * 8

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r

            // Size varies with distance and audio
            let baseSize = 3.0 + Double(i) / Double(seedCount) * 5.0
            let size = baseSize * (0.8 + Double(audioLevel) * 0.4)

            // Color gradient from center outward
            let hue = (hrvCoherence / 100.0 * 0.3) + (Double(i) / Double(seedCount)) * 0.2
            let brightness = 0.6 + (Double(i) / Double(seedCount)) * 0.4

            let seedPath = Path(ellipseIn: CGRect(
                x: x - size/2,
                y: y - size/2,
                width: size,
                height: size
            ))

            context.fill(
                seedPath,
                with: .color(Color(hue: hue, saturation: 0.7, brightness: brightness))
            )
        }

        // Draw Fibonacci spiral overlay
        drawFibonacciSpiral(context: context, center: center, time: time, rotationSpeed: rotationSpeed)
    }

    private func drawFibonacciSpiral(context: GraphicsContext, center: CGPoint, time: Double, rotationSpeed: Double) {
        var path = Path()
        let rotation = time * rotationSpeed

        var currentX = center.x
        var currentY = center.y
        var fibIndex = 0

        for i in 0..<fibonacci.count - 1 {
            let fibValue = CGFloat(fibonacci[i]) * 5
            let startAngle = Angle(degrees: Double(fibIndex % 4) * 90 + rotation * 57.29578) // Convert radians to degrees
            let endAngle = startAngle + .degrees(90)

            let arcCenter = CGPoint(
                x: currentX + (fibIndex % 2 == 0 ? fibValue : -fibValue) * (fibIndex / 2 % 2 == 0 ? 1 : -1),
                y: currentY + (fibIndex % 2 == 1 ? fibValue : -fibValue) * (fibIndex / 2 % 2 == 0 ? 1 : -1)
            )

            path.addArc(
                center: arcCenter,
                radius: fibValue,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: fibIndex % 2 == 0
            )

            fibIndex += 1
        }

        let alpha = 0.4 + CGFloat(audioLevel) * 0.4
        context.stroke(
            path,
            with: .color(Color.white.opacity(alpha)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
    }

    // MARK: - Metatron's Cube

    private func drawMetatronsCube(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, rotationSpeed: Double) {
        let rotation = time * rotationSpeed * 0.3

        // Metatron's Cube has 13 circles arranged in the Flower of Life pattern
        // with lines connecting all center points

        let innerRadius = radius * 0.3
        let circleRadius = innerRadius / 3

        // Define 13 circle centers (center + 6 inner + 6 outer)
        var centers: [CGPoint] = [center]

        // Inner ring (6 circles)
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rotation
            centers.append(CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            ))
        }

        // Outer ring (6 circles)
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + .pi / 6 + rotation
            centers.append(CGPoint(
                x: center.x + cos(angle) * innerRadius * 2,
                y: center.y + sin(angle) * innerRadius * 2
            ))
        }

        // Draw connecting lines (all possible connections)
        let lineAlpha = 0.2 + Double(audioLevel) * 0.3
        for i in 0..<centers.count {
            for j in (i+1)..<centers.count {
                var linePath = Path()
                linePath.move(to: centers[i])
                linePath.addLine(to: centers[j])

                let hue = hrvCoherence / 100.0 * 0.3 + Double(i + j) / 26.0 * 0.2
                context.stroke(
                    linePath,
                    with: .color(Color(hue: hue, saturation: 0.6, brightness: 0.7).opacity(lineAlpha)),
                    style: StrokeStyle(lineWidth: 1)
                )
            }
        }

        // Draw circles
        for (index, circleCenter) in centers.enumerated() {
            let circlePath = Path(ellipseIn: CGRect(
                x: circleCenter.x - circleRadius,
                y: circleCenter.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))

            let hue = hrvCoherence / 100.0 * 0.3 + Double(index) / 13.0 * 0.2
            let alpha = 0.5 + Double(audioLevel) * 0.5

            context.stroke(
                circlePath,
                with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.9).opacity(alpha)),
                style: StrokeStyle(lineWidth: 2)
            )

            // Fill center circle
            if index == 0 {
                context.fill(
                    circlePath,
                    with: .color(Color(hue: hue, saturation: 0.5, brightness: 0.3).opacity(0.5))
                )
            }
        }

        // Draw platonic solids overlay
        drawPlatonicSolidOverlay(context: context, center: center, radius: innerRadius * 1.5, time: time, rotationSpeed: rotationSpeed)
    }

    private func drawPlatonicSolidOverlay(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, rotationSpeed: Double) {
        // Draw a hexagram (Star of David) - two overlapping triangles
        let rotation = time * rotationSpeed * 0.5

        for triangleIndex in 0..<2 {
            var trianglePath = Path()
            let baseRotation = rotation + Double(triangleIndex) * .pi / 6

            for i in 0..<4 {
                let angle = baseRotation + Double(i) * 2 * .pi / 3
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )

                if i == 0 {
                    trianglePath.move(to: point)
                } else {
                    trianglePath.addLine(to: point)
                }
            }
            trianglePath.closeSubpath()

            let alpha = 0.3 + Double(audioLevel) * 0.4
            context.stroke(
                trianglePath,
                with: .color(Color(hue: hrvCoherence / 200.0, saturation: 0.6, brightness: 0.8).opacity(alpha)),
                style: StrokeStyle(lineWidth: 2)
            )
        }
    }

    // MARK: - Flower of Life

    private func drawFlowerOfLife(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, rotationSpeed: Double) {
        let rotation = time * rotationSpeed * 0.2
        let circleRadius = radius / 3

        // Draw 7 circles (center + 6 around)
        var centers: [CGPoint] = [center]

        // First ring
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rotation
            centers.append(CGPoint(
                x: center.x + cos(angle) * circleRadius,
                y: center.y + sin(angle) * circleRadius
            ))
        }

        // Second ring (12 circles)
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6 + rotation
            centers.append(CGPoint(
                x: center.x + cos(angle) * circleRadius * 2,
                y: center.y + sin(angle) * circleRadius * 2
            ))
        }

        // Third ring (for full flower)
        for i in 0..<18 {
            let angle = Double(i) * .pi / 9 + rotation
            centers.append(CGPoint(
                x: center.x + cos(angle) * circleRadius * 3,
                y: center.y + sin(angle) * circleRadius * 3
            ))
        }

        // Draw all circles
        for (index, circleCenter) in centers.enumerated() {
            let circlePath = Path(ellipseIn: CGRect(
                x: circleCenter.x - circleRadius,
                y: circleCenter.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))

            // Color varies by ring
            let ring = index < 1 ? 0 : (index < 7 ? 1 : (index < 19 ? 2 : 3))
            let hue = hrvCoherence / 100.0 * 0.3 + Double(ring) * 0.1
            let alpha = 0.3 + Double(audioLevel) * 0.3 - Double(ring) * 0.05

            context.stroke(
                circlePath,
                with: .color(Color(hue: hue, saturation: 0.6, brightness: 0.8).opacity(max(0.1, alpha))),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }

        // Draw the vesica piscis overlaps with subtle fill
        drawVesicaPiscis(context: context, center: center, circleRadius: circleRadius, time: time)
    }

    private func drawVesicaPiscis(context: GraphicsContext, center: CGPoint, circleRadius: CGFloat, time: Double) {
        // Vesica Piscis is the intersection of two overlapping circles
        let offset = circleRadius / 2

        // This creates the characteristic almond shape at intersections
        let fillAlpha = 0.1 + Double(audioLevel) * 0.1
        let hue = hrvCoherence / 100.0 * 0.4

        // Draw a central vesica piscis
        var vesicaPath = Path()
        vesicaPath.addArc(
            center: CGPoint(x: center.x - offset, y: center.y),
            radius: circleRadius,
            startAngle: .degrees(-60),
            endAngle: .degrees(60),
            clockwise: false
        )
        vesicaPath.addArc(
            center: CGPoint(x: center.x + offset, y: center.y),
            radius: circleRadius,
            startAngle: .degrees(120),
            endAngle: .degrees(240),
            clockwise: false
        )

        context.fill(
            vesicaPath,
            with: .color(Color(hue: hue, saturation: 0.5, brightness: 0.8).opacity(fillAlpha))
        )
    }

    // MARK: - Sacred Particles

    private func drawSacredParticles(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let particleCount = 30 + Int(audioLevel * 50)

        for i in 0..<particleCount {
            // Spiral distribution
            let t = Double(i) / Double(particleCount)
            let goldenAngle = .pi * 2 * (1 - 1/phi)
            let angle = Double(i) * goldenAngle + time * 0.5
            let r = t * radius * 0.8

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r

            // Particle size based on audio
            let size = 2.0 + Double(audioLevel) * 4.0 * (1 - t)

            // Pulsing brightness
            let pulse = sin(time * 2 + Double(i) * 0.1) * 0.3 + 0.7
            let alpha = (0.3 + Double(audioLevel) * 0.5) * pulse * (1 - t * 0.5)

            let particlePath = Path(ellipseIn: CGRect(
                x: x - size/2,
                y: y - size/2,
                width: size,
                height: size
            ))

            context.fill(
                particlePath,
                with: .color(Color.white.opacity(alpha))
            )
        }
    }

    // MARK: - Pattern Cycling

    private func cyclePattern() {
        let patterns = SacredPattern.allCases
        guard let currentIndex = patterns.firstIndex(of: patternType) else { return }
        let nextIndex = (currentIndex + 1) % patterns.count
        patternType = patterns[nextIndex]
    }
}


// MARK: - Preview

#Preview {
    SacredGeometryMode(
        audioLevel: 0.5,
        frequency: 440,
        hrvCoherence: 65,
        heartRate: 72
    )
}
