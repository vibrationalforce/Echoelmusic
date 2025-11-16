import Foundation
import SwiftUI
import simd

/// Generates fractals synchronized to breathing rate
/// Creates mesmerizing recursive patterns that evolve with respiration
///
/// **Fractal Types:**
/// - Mandelbrot Set (classic)
/// - Julia Set (dynamic)
/// - Burning Ship (chaotic)
/// - Newton Fractal (smooth)
/// - Custom Bio-Fractal (breathing-optimized)
///
/// **Breathing Sync:**
/// - Slow breathing (4-8 BPM) → Deep, meditative fractals
/// - Normal breathing (10-16 BPM) → Balanced evolution
/// - Fast breathing (18+ BPM) → Rapid, energetic patterns
///
/// **Usage:**
/// ```swift
/// let generator = FractalGenerator()
/// let image = generator.generateFractal(parameters: params, size: CGSize(width: 512, height: 512))
/// ```
public class FractalGenerator {

    // MARK: - Fractal Types

    public enum FractalType {
        case mandelbrot
        case julia
        case burningShip
        case newton
        case bioFractal  // Custom: Optimized for biometric visualization

        var name: String {
            switch self {
            case .mandelbrot: return "Mandelbrot Set"
            case .julia: return "Julia Set"
            case .burningShip: return "Burning Ship"
            case .newton: return "Newton Fractal"
            case .bioFractal: return "Bio-Fractal"
            }
        }
    }

    // MARK: - State

    private var currentTime: Double = 0.0
    private var evolutionPhase: Double = 0.0

    // MARK: - Public Methods

    /// Generate fractal image from parameters
    public func generateFractal(
        parameters: FractalParameters,
        type: FractalType = .bioFractal,
        size: CGSize,
        colorScheme: BiometricColorScheme
    ) -> CGImage? {

        // Update evolution phase based on breathing
        evolutionPhase += parameters.iterationSpeed * 0.016 // Assume 60 FPS

        // Create pixel buffer
        let width = Int(size.width)
        let height = Int(size.height)
        var pixels = [SIMD4<UInt8>](repeating: SIMD4<UInt8>(0, 0, 0, 255), count: width * height)

        // Generate fractal
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x

                // Map pixel to complex plane
                let real = Double(x) / Double(width) * 4.0 - 2.0
                let imag = Double(y) / Double(height) * 4.0 - 2.0
                let c = ComplexNumber(real: real, imag: imag)

                // Compute fractal value
                let value = computeFractal(c: c, type: type, parameters: parameters)

                // Convert to color
                pixels[index] = valueToColor(value, colorScheme: colorScheme)
            }
        }

        // Create CGImage from pixels
        return createCGImage(from: pixels, width: width, height: height)
    }

    /// Generate fractal for SwiftUI Canvas (faster, lower res)
    public func generateFractalPaths(
        parameters: FractalParameters,
        bounds: CGRect,
        colorScheme: BiometricColorScheme
    ) -> [(Path, Color)] {

        var paths: [(Path, Color)] = []

        // Generate concentric fractal rings
        let ringCount = min(parameters.complexity, 12)

        for i in 0..<ringCount {
            let t = Double(i) / Double(ringCount)
            let radius = t * min(bounds.width, bounds.height) / 2

            let path = createFractalRing(
                center: CGPoint(x: bounds.midX, y: bounds.midY),
                radius: radius,
                complexity: parameters.complexity,
                phase: evolutionPhase
            )

            // Color based on depth and heart rate
            let hue = (colorScheme.hue + t * 60).truncatingRemainder(dividingBy: 360)
            let color = Color(
                hue: hue / 360.0,
                saturation: colorScheme.saturation * (1.0 - t * 0.3),
                brightness: colorScheme.brightness
            )

            paths.append((path, color))
        }

        return paths
    }

    // MARK: - Private Methods

    /// Compute fractal value at point c
    private func computeFractal(c: ComplexNumber, type: FractalType, parameters: FractalParameters) -> Double {
        switch type {
        case .mandelbrot:
            return mandelbrot(c: c, maxIterations: parameters.complexity)
        case .julia:
            let juliaC = ComplexNumber(
                real: 0.285 + 0.01 * cos(evolutionPhase),
                imag: 0.01 + 0.01 * sin(evolutionPhase)
            )
            return julia(z: c, c: juliaC, maxIterations: parameters.complexity)
        case .burningShip:
            return burningShip(c: c, maxIterations: parameters.complexity)
        case .newton:
            return newton(z: c, maxIterations: parameters.complexity)
        case .bioFractal:
            return bioFractal(c: c, parameters: parameters)
        }
    }

    /// Mandelbrot set: z = z² + c
    private func mandelbrot(c: ComplexNumber, maxIterations: Int) -> Double {
        var z = ComplexNumber.zero
        var iteration = 0

        while iteration < maxIterations && z.magnitude < 4.0 {
            z = z * z + c
            iteration += 1
        }

        return Double(iteration) / Double(maxIterations)
    }

    /// Julia set: z = z² + c (fixed c)
    private func julia(z: ComplexNumber, c: ComplexNumber, maxIterations: Int) -> Double {
        var z = z
        var iteration = 0

        while iteration < maxIterations && z.magnitude < 4.0 {
            z = z * z + c
            iteration += 1
        }

        return Double(iteration) / Double(maxIterations)
    }

    /// Burning Ship: z = (|Re(z)| + i|Im(z)|)² + c
    private func burningShip(c: ComplexNumber, maxIterations: Int) -> Double {
        var z = ComplexNumber.zero
        var iteration = 0

        while iteration < maxIterations && z.magnitude < 4.0 {
            let absZ = ComplexNumber(real: abs(z.real), imag: abs(z.imag))
            z = absZ * absZ + c
            iteration += 1
        }

        return Double(iteration) / Double(maxIterations)
    }

    /// Newton fractal: Finding roots of z³ - 1
    private func newton(z: ComplexNumber, maxIterations: Int) -> Double {
        var z = z
        var iteration = 0

        while iteration < maxIterations {
            // f(z) = z³ - 1
            // f'(z) = 3z²
            let z3 = z * z * z
            let f = z3 - ComplexNumber(real: 1, imag: 0)
            let fPrime = z * z * ComplexNumber(real: 3, imag: 0)

            if fPrime.magnitude < 1e-10 { break }

            z = z - (f / fPrime)
            iteration += 1

            // Check convergence
            if f.magnitude < 1e-6 { break }
        }

        return Double(iteration) / Double(maxIterations)
    }

    /// Custom bio-fractal optimized for breathing visualization
    private func bioFractal(c: ComplexNumber, parameters: FractalParameters) -> Double {
        var z = ComplexNumber.zero
        var iteration = 0

        // Breathing-modulated constant
        let breathPhase = evolutionPhase * parameters.breathingRate / 60.0
        let breathModulation = ComplexNumber(
            real: 0.3 * cos(breathPhase),
            imag: 0.3 * sin(breathPhase)
        )

        let modifiedC = c + breathModulation

        while iteration < parameters.complexity && z.magnitude < 4.0 {
            // Custom iteration: z = sin(z²) + c
            let z2 = z * z
            z = ComplexNumber(
                real: sin(z2.real) * cosh(z2.imag),
                imag: cos(z2.real) * sinh(z2.imag)
            ) + modifiedC

            iteration += 1
        }

        return Double(iteration) / Double(parameters.complexity)
    }

    /// Create fractal ring path
    private func createFractalRing(center: CGPoint, radius: Double, complexity: Int, phase: Double) -> Path {
        var path = Path()

        let segments = complexity * 4
        var points: [CGPoint] = []

        for i in 0..<segments {
            let angle = Double(i) / Double(segments) * 2 * .pi
            let perturbation = sin(angle * Double(complexity) + phase) * 0.1 * radius

            let x = center.x + CGFloat((radius + perturbation) * cos(angle))
            let y = center.y + CGFloat((radius + perturbation) * sin(angle))

            points.append(CGPoint(x: x, y: y))
        }

        // Create smooth path
        guard !points.isEmpty else { return path }

        path.move(to: points[0])

        for i in 1..<points.count {
            path.addLine(to: points[i])
        }

        path.closeSubpath()

        return path
    }

    /// Convert fractal value to color
    private func valueToColor(_ value: Double, colorScheme: BiometricColorScheme) -> SIMD4<UInt8> {
        if value >= 1.0 {
            // Inside fractal set - use base color
            return SIMD4<UInt8>(0, 0, 0, 255)
        }

        // Outside - use gradient based on escape time
        let hue = (colorScheme.hue + value * 120).truncatingRemainder(dividingBy: 360)
        let saturation = colorScheme.saturation
        let brightness = colorScheme.brightness * value

        // Convert HSB to RGB
        let rgb = hsbToRGB(h: hue / 360.0, s: saturation, b: brightness)

        return SIMD4<UInt8>(
            UInt8(rgb.x * 255),
            UInt8(rgb.y * 255),
            UInt8(rgb.z * 255),
            255
        )
    }

    /// HSB to RGB conversion
    private func hsbToRGB(h: Double, s: Double, b: Double) -> SIMD3<Double> {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c

        var rgb = SIMD3<Double>(0, 0, 0)

        switch h * 6 {
        case 0..<1: rgb = SIMD3(c, x, 0)
        case 1..<2: rgb = SIMD3(x, c, 0)
        case 2..<3: rgb = SIMD3(0, c, x)
        case 3..<4: rgb = SIMD3(0, x, c)
        case 4..<5: rgb = SIMD3(x, 0, c)
        default: rgb = SIMD3(c, 0, x)
        }

        return rgb + SIMD3(repeating: m)
    }

    /// Create CGImage from pixel array
    private func createCGImage(from pixels: [SIMD4<UInt8>], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        guard let data = context.data else { return nil }
        data.copyMemory(from: pixels, byteCount: pixels.count * MemoryLayout<SIMD4<UInt8>>.stride)

        return context.makeImage()
    }
}

// MARK: - Complex Number

/// Complex number for fractal calculations
struct ComplexNumber {
    var real: Double
    var imag: Double

    static let zero = ComplexNumber(real: 0, imag: 0)

    var magnitude: Double {
        sqrt(real * real + imag * imag)
    }

    static func +(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real + rhs.real, imag: lhs.imag + rhs.imag)
    }

    static func -(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real - rhs.real, imag: lhs.imag - rhs.imag)
    }

    static func *(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(
            real: lhs.real * rhs.real - lhs.imag * rhs.imag,
            imag: lhs.real * rhs.imag + lhs.imag * rhs.real
        )
    }

    static func /(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        let denominator = rhs.real * rhs.real + rhs.imag * rhs.imag
        return ComplexNumber(
            real: (lhs.real * rhs.real + lhs.imag * rhs.imag) / denominator,
            imag: (lhs.imag * rhs.real - lhs.real * rhs.imag) / denominator
        )
    }
}

// MARK: - SwiftUI View

/// Fractal visualization view
public struct FractalVisualizationView: View {

    @ObservedObject var visualMapper: BiometricVisualMapper

    private let generator = FractalGenerator()

    public init(visualMapper: BiometricVisualMapper) {
        self.visualMapper = visualMapper
    }

    public var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let paths = generator.generateFractalPaths(
                    parameters: visualMapper.fractalParameters,
                    bounds: CGRect(origin: .zero, size: size),
                    colorScheme: visualMapper.colorScheme
                )

                for (path, color) in paths {
                    context.stroke(path, with: .color(color), lineWidth: 2)
                }
            }
        }
        .drawingGroup()
    }
}
