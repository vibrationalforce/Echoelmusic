//
//  CymaticsEngine.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  CYMATICS ENGINE - Sound Visualization
//
//  Wissenschaftlich fundierte Visualisierung von Schallwellen basierend auf:
//
//  1. Chladni-Figuren (Ernst Chladni, 1787)
//     - Stehende Wellen auf schwingenden Platten
//     - Knotenlinien wo Amplitude = 0
//     - Muster hängt von Frequenz und Plattengeometrie ab
//
//  2. Modale Analyse
//     - Eigenmoden einer schwingenden Membran
//     - Bessel-Funktionen für kreisförmige Membranen
//     - Sinusfunktionen für rechteckige Membranen
//
//  3. Wellengleichung
//     - ∂²u/∂t² = c² ∇²u (2D Wellengleichung)
//     - c = √(T/ρ) (Ausbreitungsgeschwindigkeit)
//
//  Referenzen:
//  - Chladni, E.F.F. (1787). "Entdeckungen über die Theorie des Klanges"
//  - Rayleigh, Lord (1894). "The Theory of Sound"
//  - Fletcher & Rossing (1998). "The Physics of Musical Instruments"
//

import Foundation
import Combine
import simd
import Accelerate

// MARK: - Cymatics Engine

@MainActor
public class CymaticsEngine: ObservableObject {

    public static let shared = CymaticsEngine()

    // MARK: - Published State

    @Published public var currentFrequency: Double = 440.0
    @Published public var currentAmplitude: Double = 1.0
    @Published public var currentPattern: CymaticPattern?
    @Published public var visualizationMode: VisualizationMode = .chladni
    @Published public var plateGeometry: PlateGeometry = .circular

    // MARK: - Configuration

    public var resolution: Int = 256  // Grid resolution
    public var plateRadius: Double = 1.0  // Normalized plate radius
    public var dampingFactor: Double = 0.02  // Energy dissipation
    public var waveSpeed: Double = 1.0  // Wave propagation speed

    // MARK: - Types

    public enum VisualizationMode: String, CaseIterable {
        case chladni = "Chladni Figures"
        case standingWave = "Standing Waves"
        case waveInterference = "Wave Interference"
        case spectralColors = "Spectral Colors"
        case displacement3D = "3D Displacement"
    }

    public enum PlateGeometry: String, CaseIterable {
        case circular = "Circular"
        case square = "Square"
        case rectangular = "Rectangular"
        case hexagonal = "Hexagonal"
    }

    // MARK: - Chladni Figure Generation

    /// Generate Chladni pattern for given frequency
    /// Based on eigenmodes of vibrating plate
    public func generateChladniPattern(
        frequency: Double,
        modeM: Int? = nil,
        modeN: Int? = nil
    ) -> CymaticPattern {

        // Calculate mode numbers from frequency (or use provided)
        let (m, n) = modeM != nil && modeN != nil
            ? (modeM!, modeN!)
            : calculateModeNumbers(for: frequency)

        var pattern = CymaticPattern(
            frequency: frequency,
            modeM: m,
            modeN: n,
            geometry: plateGeometry,
            resolution: resolution
        )

        switch plateGeometry {
        case .circular:
            pattern.data = generateCircularChladni(m: m, n: n)
        case .square:
            pattern.data = generateSquareChladni(m: m, n: n)
        case .rectangular:
            pattern.data = generateRectangularChladni(m: m, n: n, aspectRatio: 1.5)
        case .hexagonal:
            pattern.data = generateHexagonalChladni(m: m, n: n)
        }

        currentPattern = pattern
        currentFrequency = frequency

        return pattern
    }

    /// Calculate mode numbers (m, n) from frequency
    /// Using simplified model: f_mn ∝ √(m² + n²)
    private func calculateModeNumbers(for frequency: Double) -> (Int, Int) {
        // Base frequency for mode (1,1)
        let baseFreq: Double = 100.0

        // Frequency ratio
        let ratio = frequency / baseFreq

        // Find closest mode combination
        // f_mn ∝ (m² + n²) for square plate
        let targetSum = ratio * ratio

        var bestM = 1, bestN = 1
        var bestError = Double.infinity

        for m in 1...20 {
            for n in 1...20 {
                let modeSum = Double(m * m + n * n)
                let error = abs(modeSum - targetSum)
                if error < bestError {
                    bestError = error
                    bestM = m
                    bestN = n
                }
            }
        }

        return (bestM, bestN)
    }

    // MARK: - Circular Plate (Bessel Functions)

    /// Generate Chladni pattern for circular plate
    /// Uses Bessel functions J_m(k_mn * r) * cos(m * θ)
    private func generateCircularChladni(m: Int, n: Int) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        // k_mn: nth zero of Bessel function J_m
        let k_mn = besselZero(m: m, n: n)

        let center = Double(resolution) / 2.0

        for y in 0..<resolution {
            for x in 0..<resolution {
                // Normalized coordinates
                let dx = (Double(x) - center) / center
                let dy = (Double(y) - center) / center
                let r = sqrt(dx * dx + dy * dy)
                let theta = atan2(dy, dx)

                // Outside plate
                if r > 1.0 {
                    data[y][x] = 0
                    continue
                }

                // Displacement: J_m(k_mn * r) * cos(m * θ)
                let radialPart = besselJ(n: m, x: k_mn * r)
                let angularPart = cos(Double(m) * theta)
                data[y][x] = radialPart * angularPart
            }
        }

        return normalizePattern(data)
    }

    /// Approximate Bessel function J_n(x)
    private func besselJ(n: Int, x: Double) -> Double {
        // Use series expansion for small x
        if abs(x) < 1e-10 {
            return n == 0 ? 1.0 : 0.0
        }

        // Numerical approximation using series
        var sum = 0.0
        let nFact = factorial(n)

        for k in 0..<50 {
            let sign = (k % 2 == 0) ? 1.0 : -1.0
            let term = sign * pow(x / 2, Double(n + 2 * k)) / (Double(factorial(k)) * Double(factorial(n + k)))
            sum += term

            if abs(term) < 1e-15 { break }
        }

        return sum
    }

    /// Approximate zeros of Bessel function (k_mn)
    private func besselZero(m: Int, n: Int) -> Double {
        // McMahon's approximation for large zeros
        // j_m,n ≈ (n + m/2 - 1/4)π for large n
        let approximate = (Double(n) + Double(m) / 2.0 - 0.25) * Double.pi

        // First few exact values for common modes
        let exactZeros: [[Double]] = [
            [2.4048, 5.5201, 8.6537, 11.7915, 14.9309],  // m=0
            [3.8317, 7.0156, 10.1735, 13.3237, 16.4706], // m=1
            [5.1356, 8.4172, 11.6198, 14.7960, 17.9598], // m=2
            [6.3802, 9.7610, 13.0152, 16.2235, 19.4094], // m=3
            [7.5883, 11.0647, 14.3725, 17.6160, 20.8269] // m=4
        ]

        if m < exactZeros.count && n <= exactZeros[m].count {
            return exactZeros[m][n - 1]
        }

        return approximate
    }

    // MARK: - Square Plate

    /// Generate Chladni pattern for square plate
    /// Uses sin(m*π*x) * sin(n*π*y) ± sin(n*π*x) * sin(m*π*y)
    private func generateSquareChladni(m: Int, n: Int) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        for y in 0..<resolution {
            for x in 0..<resolution {
                // Normalized coordinates 0 to 1
                let xNorm = Double(x) / Double(resolution - 1)
                let yNorm = Double(y) / Double(resolution - 1)

                // Chladni pattern: combination of two modes
                // Z = sin(mπx)sin(nπy) + sin(nπx)sin(mπy)
                let mode1 = sin(Double(m) * Double.pi * xNorm) * sin(Double(n) * Double.pi * yNorm)
                let mode2 = sin(Double(n) * Double.pi * xNorm) * sin(Double(m) * Double.pi * yNorm)

                data[y][x] = mode1 + mode2
            }
        }

        return normalizePattern(data)
    }

    // MARK: - Rectangular Plate

    /// Generate Chladni pattern for rectangular plate
    private func generateRectangularChladni(m: Int, n: Int, aspectRatio: Double) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        let width = Double(resolution)
        let height = Double(resolution) / aspectRatio

        for y in 0..<resolution {
            for x in 0..<resolution {
                let xNorm = Double(x) / width
                let yNorm = Double(y) / height

                // Rectangular mode shape
                let mode = sin(Double(m) * Double.pi * xNorm) * sin(Double(n) * Double.pi * yNorm)

                data[y][x] = mode
            }
        }

        return normalizePattern(data)
    }

    // MARK: - Hexagonal Plate

    /// Generate Chladni pattern for hexagonal plate (approximation)
    private func generateHexagonalChladni(m: Int, n: Int) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        let center = Double(resolution) / 2.0

        // Hexagonal boundary check
        func isInsideHexagon(_ x: Double, _ y: Double) -> Bool {
            let dx = abs(x - center) / center
            let dy = abs(y - center) / center
            return dy < 0.866 && dy + dx * 0.5 < 0.866
        }

        for y in 0..<resolution {
            for x in 0..<resolution {
                if !isInsideHexagon(Double(x), Double(y)) {
                    data[y][x] = 0
                    continue
                }

                // Approximate hexagonal modes using combination of plane waves
                let xNorm = (Double(x) - center) / center
                let yNorm = (Double(y) - center) / center

                // Three-fold symmetry
                let angle1 = 0.0
                let angle2 = 2.0 * Double.pi / 3.0
                let angle3 = 4.0 * Double.pi / 3.0

                let wave1 = cos(Double(m) * Double.pi * (xNorm * cos(angle1) + yNorm * sin(angle1)))
                let wave2 = cos(Double(m) * Double.pi * (xNorm * cos(angle2) + yNorm * sin(angle2)))
                let wave3 = cos(Double(m) * Double.pi * (xNorm * cos(angle3) + yNorm * sin(angle3)))

                data[y][x] = wave1 + wave2 + wave3
            }
        }

        return normalizePattern(data)
    }

    // MARK: - Standing Wave Visualization

    /// Generate standing wave pattern
    public func generateStandingWave(
        frequency: Double,
        wavelength: Double,
        time: Double = 0
    ) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        let k = 2.0 * Double.pi / wavelength  // Wave number
        let omega = 2.0 * Double.pi * frequency  // Angular frequency

        for y in 0..<resolution {
            for x in 0..<resolution {
                let xPos = Double(x) / Double(resolution) * wavelength * 3
                let yPos = Double(y) / Double(resolution) * wavelength * 3

                // 2D standing wave: cos(kx)cos(ky)cos(ωt)
                let spatial = cos(k * xPos) * cos(k * yPos)
                let temporal = cos(omega * time)

                data[y][x] = spatial * temporal
            }
        }

        return normalizePattern(data)
    }

    // MARK: - Wave Interference Pattern

    /// Generate interference pattern from multiple sources
    public func generateInterferencePattern(
        sources: [WaveSource],
        frequency: Double,
        time: Double = 0
    ) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        let wavelength = waveSpeed / frequency
        let k = 2.0 * Double.pi / wavelength
        let omega = 2.0 * Double.pi * frequency

        for y in 0..<resolution {
            for x in 0..<resolution {
                var totalAmplitude = 0.0

                for source in sources {
                    // Distance from source
                    let dx = Double(x) - source.x * Double(resolution)
                    let dy = Double(y) - source.y * Double(resolution)
                    let distance = sqrt(dx * dx + dy * dy)

                    // Wave from this source
                    let phase = k * distance - omega * time + source.phase
                    let amplitude = source.amplitude * cos(phase) / max(1, sqrt(distance))

                    totalAmplitude += amplitude
                }

                data[y][x] = totalAmplitude
            }
        }

        return normalizePattern(data)
    }

    public struct WaveSource {
        public let x: Double  // 0-1 normalized position
        public let y: Double
        public let amplitude: Double
        public let phase: Double

        public init(x: Double, y: Double, amplitude: Double = 1.0, phase: Double = 0.0) {
            self.x = x
            self.y = y
            self.amplitude = amplitude
            self.phase = phase
        }
    }

    // MARK: - Frequency to Color Mapping

    /// Map frequency to visible light color (scientific approximation)
    public func frequencyToColor(_ frequency: Double) -> (r: Double, g: Double, b: Double) {
        // Map audio frequency to wavelength via octave transposition
        // ~40 octaves from audio to visible light
        let transposer = FrequencyTransposer.shared
        let result = transposer.audioToVisibleLight(frequency)
        return result.rgb
    }

    /// Generate spectral color pattern from frequency content
    public func generateSpectralPattern(frequencies: [(frequency: Double, amplitude: Double)]) -> [[Double]] {
        var data = [[Double]](repeating: [Double](repeating: 0, count: resolution), count: resolution)

        // Each frequency creates rings
        for y in 0..<resolution {
            for x in 0..<resolution {
                let xNorm = Double(x) / Double(resolution - 1) * 2 - 1
                let yNorm = Double(y) / Double(resolution - 1) * 2 - 1
                let r = sqrt(xNorm * xNorm + yNorm * yNorm)

                var totalValue = 0.0
                for (freq, amp) in frequencies {
                    // Higher frequency = more rings
                    let rings = freq / 100.0
                    totalValue += amp * sin(r * rings * Double.pi * 2)
                }

                data[y][x] = totalValue
            }
        }

        return normalizePattern(data)
    }

    // MARK: - Helpers

    private func normalizePattern(_ data: [[Double]]) -> [[Double]] {
        var result = data

        // Find min and max
        var minVal = Double.infinity
        var maxVal = -Double.infinity

        for row in data {
            for val in row {
                minVal = min(minVal, val)
                maxVal = max(maxVal, val)
            }
        }

        // Normalize to -1...1
        let range = maxVal - minVal
        if range > 0 {
            for y in 0..<data.count {
                for x in 0..<data[y].count {
                    result[y][x] = (data[y][x] - minVal) / range * 2 - 1
                }
            }
        }

        return result
    }

    private func factorial(_ n: Int) -> Int {
        if n <= 1 { return 1 }
        return n * factorial(n - 1)
    }

    private init() {}
}

// MARK: - Cymatic Pattern

public struct CymaticPattern: Identifiable {
    public let id = UUID()
    public let frequency: Double
    public let modeM: Int
    public let modeN: Int
    public let geometry: CymaticsEngine.PlateGeometry
    public let resolution: Int
    public var data: [[Double]]  // Amplitude values -1 to 1

    public var modeDescription: String {
        return "(\(modeM), \(modeN))"
    }

    /// Calculate theoretical resonant frequency for this mode
    /// For square plate: f_mn ∝ √(m² + n²)
    public var theoreticalFrequency: Double {
        let baseFreq = 100.0  // Fundamental frequency
        return baseFreq * sqrt(Double(modeM * modeM + modeN * modeN))
    }

    /// Get nodal line positions (where amplitude ≈ 0)
    public var nodalLineCount: Int {
        return modeM + modeN - 2
    }

    public init(
        frequency: Double,
        modeM: Int,
        modeN: Int,
        geometry: CymaticsEngine.PlateGeometry,
        resolution: Int
    ) {
        self.frequency = frequency
        self.modeM = modeM
        self.modeN = modeN
        self.geometry = geometry
        self.resolution = resolution
        self.data = []
    }
}

// MARK: - Real-time Audio Visualization

extension CymaticsEngine {

    /// Process audio buffer and generate corresponding pattern
    public func processAudioBuffer(
        magnitudes: [Float],
        frequencies: [Double]
    ) -> CymaticPattern? {
        guard !magnitudes.isEmpty else { return nil }

        // Find dominant frequency
        var maxMag: Float = 0
        var maxIndex = 0
        for (index, mag) in magnitudes.enumerated() {
            if mag > maxMag {
                maxMag = mag
                maxIndex = index
            }
        }

        guard maxIndex < frequencies.count else { return nil }

        let dominantFreq = frequencies[maxIndex]
        currentAmplitude = Double(maxMag)

        return generateChladniPattern(frequency: dominantFreq)
    }

    /// Get RGB image data from pattern
    public func patternToRGBData(
        _ pattern: CymaticPattern,
        colorScheme: ColorScheme = .blueWhite
    ) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: pattern.resolution * pattern.resolution * 4)

        for y in 0..<pattern.resolution {
            for x in 0..<pattern.resolution {
                let value = pattern.data[y][x]  // -1 to 1
                let normalized = (value + 1) / 2  // 0 to 1

                let (r, g, b) = colorScheme.colorForValue(normalized)

                let index = (y * pattern.resolution + x) * 4
                pixels[index] = UInt8(r * 255)
                pixels[index + 1] = UInt8(g * 255)
                pixels[index + 2] = UInt8(b * 255)
                pixels[index + 3] = 255  // Alpha
            }
        }

        return pixels
    }

    public enum ColorScheme {
        case blueWhite
        case heatmap
        case spectral
        case grayscale
        case blackWhite

        func colorForValue(_ value: Double) -> (Double, Double, Double) {
            switch self {
            case .blueWhite:
                return (value, value, 1.0)
            case .heatmap:
                // Blue → Cyan → Green → Yellow → Red
                if value < 0.25 {
                    return (0, value * 4, 1)
                } else if value < 0.5 {
                    return (0, 1, 1 - (value - 0.25) * 4)
                } else if value < 0.75 {
                    return ((value - 0.5) * 4, 1, 0)
                } else {
                    return (1, 1 - (value - 0.75) * 4, 0)
                }
            case .spectral:
                // Map to visible spectrum
                let wavelength = 380 + value * 320  // 380-700 nm
                return FrequencyTransposer.shared.wavelengthToRGB(wavelength)
            case .grayscale:
                return (value, value, value)
            case .blackWhite:
                let bw = value > 0.5 ? 1.0 : 0.0
                return (bw, bw, bw)
            }
        }
    }
}

// MARK: - Physical Constants for Cymatics

extension CymaticsEngine {

    /// Calculate resonant frequency for circular membrane (drumhead)
    /// f_mn = (α_mn / 2πR) * √(T/σ)
    /// where α_mn is the nth zero of Bessel function J_m
    /// T = tension, σ = surface density, R = radius
    public func circularMembraneFrequency(
        m: Int,
        n: Int,
        radius: Double,
        tension: Double,
        surfaceDensity: Double
    ) -> Double {
        let alpha_mn = besselZero(m: m, n: n)
        let c = sqrt(tension / surfaceDensity)  // Wave speed
        return (alpha_mn * c) / (2 * Double.pi * radius)
    }

    /// Calculate resonant frequency for rectangular membrane
    /// f_mn = (c/2) * √((m/L_x)² + (n/L_y)²)
    public func rectangularMembraneFrequency(
        m: Int,
        n: Int,
        lengthX: Double,
        lengthY: Double,
        waveSpeed c: Double
    ) -> Double {
        let term = sqrt(pow(Double(m) / lengthX, 2) + pow(Double(n) / lengthY, 2))
        return (c / 2.0) * term
    }

    /// Calculate resonant frequency for square plate (Chladni)
    /// f_mn ∝ (m² + n²) / L² * √(E*h² / (12*ρ*(1-ν²)))
    /// Simplified: f_mn = f_11 * √(m² + n²)
    public func squarePlateFrequency(
        m: Int,
        n: Int,
        fundamentalFrequency f11: Double
    ) -> Double {
        return f11 * sqrt(Double(m * m + n * n))
    }
}

// MARK: - Debug

#if DEBUG
extension CymaticsEngine {

    func printModeTable() {
        print("\n🌊 Chladni Mode Frequencies (Square Plate)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Mode (m,n) │ Frequency Ratio │ Nodal Lines")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for m in 1...5 {
            for n in m...5 {
                let ratio = sqrt(Double(m * m + n * n))
                let nodal = m + n - 2
                print(String(format: "  (%d,%d)    │     %.3f       │     %d", m, n, ratio, nodal))
            }
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
#endif
