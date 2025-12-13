import SwiftUI

/// Sacred Geometry visualization mode
/// Renders golden ratio spirals, Fibonacci patterns, and Metatron's cube
/// Audio frequency controls rotation speed, HRV controls color shift
struct SacredGeometryMode: View {
    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Detected frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100)
    var hrvCoherence: Double

    /// Heart Rate (BPM)
    var heartRate: Double

    /// Selected geometry pattern
    var pattern: GeometryPattern = .flowerOfLife

    @State private var rotation: Double = 0

    enum GeometryPattern: String, CaseIterable {
        case goldenSpiral = "Golden Spiral"
        case flowerOfLife = "Flower of Life"
        case metatronsCube = "Metatron's Cube"
        case sriYantra = "Sri Yantra"
        case fibonacciSpiral = "Fibonacci Spiral"
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseSize = min(size.width, size.height) * 0.4
                let time = timeline.date.timeIntervalSince1970

                // Rotation speed based on frequency
                let rotationSpeed = Double(frequency) / 500.0

                // Color based on HRV coherence
                let hue = hrvCoherence / 100.0 * 0.6
                let baseColor = Color(hue: hue, saturation: 0.7, brightness: 0.85)

                // Apply rotation
                var rotatedContext = context
                rotatedContext.translateBy(x: center.x, y: center.y)
                rotatedContext.rotate(by: .radians(time * rotationSpeed))
                rotatedContext.translateBy(x: -center.x, y: -center.y)

                // Draw based on selected pattern
                switch pattern {
                case .goldenSpiral:
                    drawGoldenSpiral(context: rotatedContext, center: center, size: baseSize, color: baseColor)
                case .flowerOfLife:
                    drawFlowerOfLife(context: rotatedContext, center: center, radius: baseSize, color: baseColor)
                case .metatronsCube:
                    drawMetatronsCube(context: rotatedContext, center: center, size: baseSize, color: baseColor)
                case .sriYantra:
                    drawSriYantra(context: rotatedContext, center: center, size: baseSize, color: baseColor)
                case .fibonacciSpiral:
                    drawFibonacciSpiral(context: rotatedContext, center: center, size: baseSize, color: baseColor, time: time)
                }

                // Draw pulsing aura based on audio level
                drawAura(context: context, center: center, size: baseSize, audioLevel: audioLevel, color: baseColor)
            }
        }
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Golden Spiral

    private func drawGoldenSpiral(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let phi: CGFloat = 1.618033988749895  // Golden ratio
        var path = Path()

        var currentSize = size * 0.1
        var currentCenter = center
        var angle: CGFloat = 0

        // Draw spiral with golden ratio
        for i in 0..<8 {
            let startAngle = angle
            let endAngle = angle + .pi / 2

            let rect = CGRect(
                x: currentCenter.x - currentSize,
                y: currentCenter.y - currentSize,
                width: currentSize * 2,
                height: currentSize * 2
            )

            path.addArc(
                center: currentCenter,
                radius: currentSize,
                startAngle: .radians(startAngle),
                endAngle: .radians(endAngle),
                clockwise: false
            )

            // Move to next quadrant
            let offset = currentSize * (1 - 1/phi)
            switch i % 4 {
            case 0:
                currentCenter.x += offset
            case 1:
                currentCenter.y += offset
            case 2:
                currentCenter.x -= offset
            case 3:
                currentCenter.y -= offset
            default:
                break
            }

            currentSize *= phi
            angle = endAngle
        }

        context.stroke(path, with: .color(color), lineWidth: 2)

        // Draw golden rectangles
        drawGoldenRectangles(context: context, center: center, size: size, color: color)
    }

    private func drawGoldenRectangles(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let phi: CGFloat = 1.618033988749895
        var currentSize = size
        var currentCenter = center

        for i in 0..<6 {
            let width = currentSize
            let height = currentSize / phi

            let rect = CGRect(
                x: currentCenter.x - width / 2,
                y: currentCenter.y - height / 2,
                width: width,
                height: height
            )

            var rectPath = Path()
            rectPath.addRect(rect)
            context.stroke(rectPath, with: .color(color.opacity(0.3)), lineWidth: 1)

            currentSize = height
        }
    }

    // MARK: - Flower of Life

    private func drawFlowerOfLife(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let circleRadius = radius / 3

        // Central circle
        drawCircle(context: context, center: center, radius: circleRadius, color: color)

        // First ring (6 circles)
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let x = center.x + cos(angle) * circleRadius
            let y = center.y + sin(angle) * circleRadius
            drawCircle(context: context, center: CGPoint(x: x, y: y), radius: circleRadius, color: color)
        }

        // Second ring (12 circles)
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            let distance = circleRadius * 1.732  // sqrt(3)
            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance
            drawCircle(context: context, center: CGPoint(x: x, y: y), radius: circleRadius, color: color.opacity(0.7))
        }

        // Outer boundary circle
        drawCircle(context: context, center: center, radius: radius, color: color.opacity(0.5))
    }

    private func drawCircle(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    // MARK: - Metatron's Cube

    private func drawMetatronsCube(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        // 13 circles of Metatron's cube
        let circleRadius = size / 6
        let mainRadius = size * 0.6

        // Center circle
        drawCircle(context: context, center: center, radius: circleRadius, color: color)

        // Inner ring (6 circles)
        var innerPoints: [CGPoint] = []
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 6
            let x = center.x + cos(angle) * mainRadius * 0.5
            let y = center.y + sin(angle) * mainRadius * 0.5
            let point = CGPoint(x: x, y: y)
            innerPoints.append(point)
            drawCircle(context: context, center: point, radius: circleRadius, color: color)
        }

        // Outer ring (6 circles)
        var outerPoints: [CGPoint] = []
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let x = center.x + cos(angle) * mainRadius
            let y = center.y + sin(angle) * mainRadius
            let point = CGPoint(x: x, y: y)
            outerPoints.append(point)
            drawCircle(context: context, center: point, radius: circleRadius, color: color)
        }

        // Connect all points with lines
        let allPoints = [center] + innerPoints + outerPoints
        for i in 0..<allPoints.count {
            for j in (i + 1)..<allPoints.count {
                var line = Path()
                line.move(to: allPoints[i])
                line.addLine(to: allPoints[j])
                context.stroke(line, with: .color(color.opacity(0.3)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Sri Yantra

    private func drawSriYantra(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        // Simplified Sri Yantra with nested triangles

        // Outer lotus petals (16)
        for i in 0..<16 {
            let angle = Double(i) * .pi / 8
            let petalPath = createPetal(center: center, angle: angle, size: size * 0.9)
            context.stroke(petalPath, with: .color(color.opacity(0.5)), lineWidth: 1)
        }

        // Inner lotus petals (8)
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 + .pi / 8
            let petalPath = createPetal(center: center, angle: angle, size: size * 0.7)
            context.stroke(petalPath, with: .color(color.opacity(0.6)), lineWidth: 1)
        }

        // Interlocking triangles (9 triangles creating 43 smaller triangles)
        drawInterlockingTriangles(context: context, center: center, size: size * 0.5, color: color)

        // Central bindu (point)
        var bindu = Path()
        bindu.addEllipse(in: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
        context.fill(bindu, with: .color(color))
    }

    private func createPetal(center: CGPoint, angle: Double, size: CGFloat) -> Path {
        var path = Path()
        let petalLength = size * 0.15
        let petalWidth = size * 0.05

        let tip = CGPoint(
            x: center.x + cos(angle) * size,
            y: center.y + sin(angle) * size
        )
        let base = CGPoint(
            x: center.x + cos(angle) * (size - petalLength),
            y: center.y + sin(angle) * (size - petalLength)
        )

        let perpAngle = angle + .pi / 2
        let left = CGPoint(
            x: base.x + cos(perpAngle) * petalWidth,
            y: base.y + sin(perpAngle) * petalWidth
        )
        let right = CGPoint(
            x: base.x - cos(perpAngle) * petalWidth,
            y: base.y - sin(perpAngle) * petalWidth
        )

        path.move(to: tip)
        path.addQuadCurve(to: left, control: CGPoint(
            x: (tip.x + left.x) / 2 + cos(perpAngle) * petalWidth * 0.5,
            y: (tip.y + left.y) / 2 + sin(perpAngle) * petalWidth * 0.5
        ))
        path.addLine(to: right)
        path.addQuadCurve(to: tip, control: CGPoint(
            x: (tip.x + right.x) / 2 - cos(perpAngle) * petalWidth * 0.5,
            y: (tip.y + right.y) / 2 - sin(perpAngle) * petalWidth * 0.5
        ))

        return path
    }

    private func drawInterlockingTriangles(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        // Upward triangles (4)
        let upwardSizes: [CGFloat] = [1.0, 0.7, 0.45, 0.2]
        for (index, scale) in upwardSizes.enumerated() {
            drawTriangle(
                context: context,
                center: CGPoint(x: center.x, y: center.y + size * 0.1 * CGFloat(index)),
                size: size * scale,
                pointingUp: true,
                color: color
            )
        }

        // Downward triangles (5)
        let downwardSizes: [CGFloat] = [0.9, 0.6, 0.35, 0.15]
        for (index, scale) in downwardSizes.enumerated() {
            drawTriangle(
                context: context,
                center: CGPoint(x: center.x, y: center.y - size * 0.08 * CGFloat(index)),
                size: size * scale,
                pointingUp: false,
                color: color
            )
        }
    }

    private func drawTriangle(context: GraphicsContext, center: CGPoint, size: CGFloat, pointingUp: Bool, color: Color) {
        var path = Path()
        let direction: CGFloat = pointingUp ? -1 : 1
        let height = size * 0.866  // sqrt(3)/2

        let top = CGPoint(x: center.x, y: center.y + direction * height * 0.67)
        let bottomLeft = CGPoint(x: center.x - size / 2, y: center.y - direction * height * 0.33)
        let bottomRight = CGPoint(x: center.x + size / 2, y: center.y - direction * height * 0.33)

        path.move(to: top)
        path.addLine(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.closeSubpath()

        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    // MARK: - Fibonacci Spiral

    private func drawFibonacciSpiral(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color, time: Double) {
        // Fibonacci sequence for sizing
        let fibonacci: [CGFloat] = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
        let scale = size / fibonacci.last!

        var path = Path()
        var currentX = center.x
        var currentY = center.y
        var angle: CGFloat = 0

        // Animate spiral growth
        let animatedSegments = Int((sin(time * 0.5) + 1) * 4) + 3

        for i in 0..<min(animatedSegments, fibonacci.count - 1) {
            let segmentSize = fibonacci[i] * scale

            // Draw arc for this segment
            path.addArc(
                center: CGPoint(x: currentX, y: currentY),
                radius: segmentSize,
                startAngle: .radians(angle),
                endAngle: .radians(angle + .pi / 2),
                clockwise: false
            )

            // Move center for next segment
            let offset = fibonacci[i] * scale * (1 - 1/1.618)
            switch i % 4 {
            case 0:
                currentX += segmentSize
            case 1:
                currentY += segmentSize
            case 2:
                currentX -= segmentSize
            case 3:
                currentY -= segmentSize
            default:
                break
            }

            angle += .pi / 2
        }

        context.stroke(path, with: .color(color), lineWidth: 2)

        // Draw Fibonacci rectangles
        drawFibonacciRectangles(context: context, center: center, scale: scale, fibonacci: fibonacci, color: color.opacity(0.3))
    }

    private func drawFibonacciRectangles(context: GraphicsContext, center: CGPoint, scale: CGFloat, fibonacci: [CGFloat], color: Color) {
        var currentX = center.x
        var currentY = center.y

        for i in 0..<fibonacci.count - 1 {
            let size = fibonacci[i] * scale

            var rectPath = Path()
            rectPath.addRect(CGRect(x: currentX, y: currentY, width: size, height: size))
            context.stroke(rectPath, with: .color(color), lineWidth: 0.5)

            switch i % 4 {
            case 0:
                currentX += size
            case 1:
                currentY += size
            case 2:
                currentX -= fibonacci[i + 1] * scale
            case 3:
                currentY -= fibonacci[i + 1] * scale
            default:
                break
            }
        }
    }

    // MARK: - Aura Effect

    private func drawAura(context: GraphicsContext, center: CGPoint, size: CGFloat, audioLevel: Float, color: Color) {
        let auraSize = size * 1.5 * (1 + CGFloat(audioLevel) * 0.3)

        for i in 0..<3 {
            let layerSize = auraSize * (1 + CGFloat(i) * 0.1)
            let opacity = 0.1 - Double(i) * 0.03

            var auraPath = Path()
            auraPath.addEllipse(in: CGRect(
                x: center.x - layerSize,
                y: center.y - layerSize,
                width: layerSize * 2,
                height: layerSize * 2
            ))

            context.fill(auraPath, with: .color(color.opacity(opacity)))
        }
    }
}
