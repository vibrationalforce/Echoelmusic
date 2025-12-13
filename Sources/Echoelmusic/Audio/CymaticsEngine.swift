import Foundation
import Accelerate
import simd

/// Cymatics Engine - Scientific Visualization of Sound Waves
///
/// Based on the physics of standing waves and Chladni patterns.
/// Named after Ernst Chladni (1756-1827) who first demonstrated
/// how vibrating plates produce visible nodal patterns.
///
/// Physics Foundation:
/// - Standing waves occur when reflected waves interfere constructively/destructively
/// - Nodal lines appear where destructive interference creates zero amplitude
/// - Pattern complexity increases with frequency (more nodes at higher frequencies)
///
/// References:
/// - Chladni, E.F.F. (1787) "Entdeckungen über die Theorie des Klanges"
/// - Fletcher, N.H. & Rossing, T.D. (1998) "The Physics of Musical Instruments"
@MainActor
class CymaticsEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentFrequency: Float = 440.0
    @Published var amplitude: Float = 0.5
    @Published var plateGeometry: PlateGeometry = .circular
    @Published var dampingFactor: Float = 0.02
    @Published var patternData: [[Float]] = []

    // MARK: - Configuration

    /// Plate geometry affects nodal pattern shapes
    enum PlateGeometry: String, CaseIterable {
        case circular = "Circular"      // Bessel function patterns
        case square = "Square"          // 2D sine patterns
        case rectangular = "Rectangular" // Mixed mode patterns

        var aspectRatio: Float {
            switch self {
            case .circular: return 1.0
            case .square: return 1.0
            case .rectangular: return 1.5
            }
        }
    }

    /// Resolution of the simulation grid
    private let gridSize: Int = 128

    /// Speed of wave propagation (normalized)
    private let waveSpeed: Float = 1.0

    /// Time step for simulation
    private var time: Double = 0

    // MARK: - Physics Constants

    /// Bessel function zeros for circular plate modes
    /// These determine the radii of nodal circles
    private let besselZeros: [[Float]] = [
        [2.405, 5.520, 8.654, 11.792],  // J0 zeros
        [3.832, 7.016, 10.173, 13.324], // J1 zeros
        [5.136, 8.417, 11.620, 14.796], // J2 zeros
        [6.380, 9.761, 13.015, 16.223]  // J3 zeros
    ]

    // MARK: - Initialization

    init() {
        initializeGrid()
    }

    private func initializeGrid() {
        patternData = Array(
            repeating: Array(repeating: 0.0, count: gridSize),
            count: gridSize
        )
    }

    // MARK: - Pattern Generation

    /// Generate Chladni pattern for current frequency
    /// The pattern shows nodal lines where amplitude is zero
    func generatePattern() {
        switch plateGeometry {
        case .circular:
            generateCircularPattern()
        case .square:
            generateSquarePattern()
        case .rectangular:
            generateRectangularPattern()
        }
    }

    /// Circular plate: Chladni patterns follow Bessel functions
    /// u(r,θ,t) = J_m(k_mn * r) * cos(mθ) * cos(ωt)
    private func generateCircularPattern() {
        let center = Float(gridSize) / 2.0

        // Frequency determines which mode is excited
        // Higher frequency = higher mode numbers = more nodal circles
        let modeM = Int(currentFrequency / 200.0) % 4  // Angular mode
        let modeN = Int(currentFrequency / 100.0) % 4  // Radial mode

        let k = besselZeros[modeM][modeN] / center

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let dx = Float(x) - center
                let dy = Float(y) - center
                let r = sqrt(dx * dx + dy * dy)
                let theta = atan2(dy, dx)

                // Inside the plate boundary
                if r <= center {
                    // Bessel function approximation for visualization
                    let besselTerm = besselJ(order: modeM, x: k * r)
                    let angularTerm = cos(Float(modeM) * theta)
                    let timeTerm = cos(Float(time) * 2.0 * .pi)

                    // Apply damping at edges
                    let edgeFactor = 1.0 - pow(r / center, 4)

                    patternData[y][x] = besselTerm * angularTerm * timeTerm * edgeFactor * amplitude
                } else {
                    patternData[y][x] = 0
                }
            }
        }
    }

    /// Square plate: Standing waves form grid patterns
    /// u(x,y,t) = sin(nπx/L) * sin(mπy/L) * cos(ωt)
    private func generateSquarePattern() {
        // Mode numbers from frequency
        let modeM = max(1, Int(currentFrequency / 100.0))
        let modeN = max(1, Int(currentFrequency / 150.0))

        let L = Float(gridSize - 1)

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let spatialX = sin(Float(modeM) * .pi * Float(x) / L)
                let spatialY = sin(Float(modeN) * .pi * Float(y) / L)
                let timeTerm = cos(Float(time) * 2.0 * .pi)

                patternData[y][x] = spatialX * spatialY * timeTerm * amplitude
            }
        }
    }

    /// Rectangular plate: Mixed mode patterns
    private func generateRectangularPattern() {
        let modeM = max(1, Int(currentFrequency / 100.0))
        let modeN = max(1, Int(currentFrequency / 120.0))

        let Lx = Float(gridSize - 1)
        let Ly = Lx / plateGeometry.aspectRatio

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let spatialX = sin(Float(modeM) * .pi * Float(x) / Lx)
                let spatialY = sin(Float(modeN) * .pi * Float(y) / Ly)
                let timeTerm = cos(Float(time) * 2.0 * .pi)

                // Apply edge damping
                let edgeX = sin(.pi * Float(x) / Float(gridSize - 1))
                let edgeY = sin(.pi * Float(y) / Float(gridSize - 1))
                let edgeFactor = edgeX * edgeY

                patternData[y][x] = spatialX * spatialY * timeTerm * edgeFactor * amplitude
            }
        }
    }

    // MARK: - Time Evolution

    /// Advance simulation by one frame
    func update(deltaTime: Double) {
        time += deltaTime * Double(currentFrequency) / 100.0

        // Apply damping
        let dampingMultiplier = exp(-dampingFactor * Float(deltaTime))

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                patternData[y][x] *= dampingMultiplier
            }
        }

        generatePattern()
    }

    // MARK: - Frequency Analysis

    /// Calculate the resonant frequencies of the plate
    /// For a circular plate: f_mn = (α_mn / 2π) * √(D / ρh) / R²
    func resonantFrequencies(forPlate radius: Float, thickness: Float, density: Float, youngsModulus: Float) -> [Float] {
        var frequencies: [Float] = []

        // Flexural rigidity D = E*h³ / (12*(1-ν²))
        // Assuming Poisson's ratio ν = 0.3
        let poisson: Float = 0.3
        let D = youngsModulus * pow(thickness, 3) / (12.0 * (1.0 - poisson * poisson))

        // Wave speed factor
        let speedFactor = sqrt(D / (density * thickness)) / (radius * radius)

        // First few modes
        for m in 0..<3 {
            for n in 0..<3 {
                let alpha = besselZeros[m][n]
                let freq = alpha * alpha * speedFactor / (2.0 * .pi)
                frequencies.append(freq)
            }
        }

        return frequencies.sorted()
    }

    /// Get nodal line positions for current pattern
    /// Nodal lines occur where amplitude ≈ 0
    func nodalLinePositions() -> [(x: Int, y: Int)] {
        var nodal: [(x: Int, y: Int)] = []
        let threshold: Float = 0.05 * amplitude

        for y in 1..<(gridSize - 1) {
            for x in 1..<(gridSize - 1) {
                // Check for zero crossing
                if abs(patternData[y][x]) < threshold {
                    // Verify it's actually a nodal line (sign change in neighbors)
                    let signChanges = countSignChanges(x: x, y: y)
                    if signChanges >= 2 {
                        nodal.append((x, y))
                    }
                }
            }
        }

        return nodal
    }

    private func countSignChanges(x: Int, y: Int) -> Int {
        let current = patternData[y][x]
        var changes = 0

        let neighbors = [
            patternData[y-1][x], patternData[y+1][x],
            patternData[y][x-1], patternData[y][x+1]
        ]

        for neighbor in neighbors {
            if (current >= 0 && neighbor < 0) || (current < 0 && neighbor >= 0) {
                changes += 1
            }
        }

        return changes
    }

    // MARK: - Bessel Function Approximation

    /// Bessel function of the first kind (approximation for visualization)
    private func besselJ(order: Int, x: Float) -> Float {
        switch order {
        case 0:
            return besselJ0(x)
        case 1:
            return besselJ1(x)
        default:
            // Higher orders via recurrence: J_{n+1}(x) = (2n/x)J_n(x) - J_{n-1}(x)
            var jPrev = besselJ0(x)
            var jCurr = besselJ1(x)
            for n in 1..<order {
                let jNext = (2.0 * Float(n) / x) * jCurr - jPrev
                jPrev = jCurr
                jCurr = jNext
            }
            return jCurr
        }
    }

    /// J0(x) approximation (Abramowitz & Stegun)
    private func besselJ0(_ x: Float) -> Float {
        let ax = abs(x)

        if ax < 8.0 {
            let y = x * x
            let ans1 = 57568490574.0 + y * (-13362590354.0 + y * (651619640.7
                + y * (-11214424.18 + y * (77392.33017 + y * (-184.9052456)))))
            let ans2 = 57568490411.0 + y * (1029532985.0 + y * (9494680.718
                + y * (59272.64853 + y * (267.8532712 + y))))
            return Float(ans1 / ans2)
        } else {
            let z = 8.0 / ax
            let y = z * z
            let xx = ax - 0.785398164
            let ans1 = 1.0 + y * (-0.1098628627e-2 + y * (0.2734510407e-4
                + y * (-0.2073370639e-5 + y * 0.2093887211e-6)))
            let ans2 = -0.1562499995e-1 + y * (0.1430488765e-3
                + y * (-0.6911147651e-5 + y * (0.7621095161e-6 + y * (-0.934945152e-7))))
            return Float(sqrt(0.636619772 / Double(ax)) * (cos(Double(xx)) * ans1 - z * sin(Double(xx)) * ans2))
        }
    }

    /// J1(x) approximation (Abramowitz & Stegun)
    private func besselJ1(_ x: Float) -> Float {
        let ax = abs(x)

        if ax < 8.0 {
            let y = x * x
            let ans1 = x * (72362614232.0 + y * (-7895059235.0 + y * (242396853.1
                + y * (-2972611.439 + y * (15704.48260 + y * (-30.16036606))))))
            let ans2 = 144725228442.0 + y * (2300535178.0 + y * (18583304.74
                + y * (99447.43394 + y * (376.9991397 + y))))
            return Float(ans1 / ans2)
        } else {
            let z = 8.0 / ax
            let y = z * z
            let xx = ax - 2.356194491
            let ans1 = 1.0 + y * (0.183105e-2 + y * (-0.3516396496e-4
                + y * (0.2457520174e-5 + y * (-0.240337019e-6))))
            let ans2 = 0.04687499995 + y * (-0.2002690873e-3
                + y * (0.8449199096e-5 + y * (-0.88228987e-6 + y * 0.105787412e-6)))
            let ans = Float(sqrt(0.636619772 / Double(ax)) * (cos(Double(xx)) * ans1 - z * sin(Double(xx)) * ans2))
            return x < 0 ? -ans : ans
        }
    }
}

// MARK: - Chladni Pattern Analysis

extension CymaticsEngine {

    /// Analyze the current pattern and return statistics
    struct PatternAnalysis {
        let nodalLineCount: Int
        let symmetryOrder: Int
        let estimatedMode: (m: Int, n: Int)
        let totalEnergy: Float
        let edgeEnergy: Float
        let centerEnergy: Float
    }

    func analyzePattern() -> PatternAnalysis {
        let nodal = nodalLinePositions()
        let center = gridSize / 2
        let centerRadius = gridSize / 4

        var totalEnergy: Float = 0
        var edgeEnergy: Float = 0
        var centerEnergy: Float = 0

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let energy = patternData[y][x] * patternData[y][x]
                totalEnergy += energy

                let dx = x - center
                let dy = y - center
                let r = sqrt(Float(dx * dx + dy * dy))

                if r < Float(centerRadius) {
                    centerEnergy += energy
                } else {
                    edgeEnergy += energy
                }
            }
        }

        // Estimate mode from frequency
        let modeM = Int(currentFrequency / 200.0) % 4
        let modeN = Int(currentFrequency / 100.0) % 4

        return PatternAnalysis(
            nodalLineCount: nodal.count,
            symmetryOrder: max(1, modeM),
            estimatedMode: (modeM, modeN),
            totalEnergy: totalEnergy,
            edgeEnergy: edgeEnergy,
            centerEnergy: centerEnergy
        )
    }
}
