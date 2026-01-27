// ZernikePolynomials.swift
// Echoelmusic
//
// Zernike polynomial implementation for bioreactive light array control.
// Maps latent biometric dimensions to Zernike coefficients,
// generating complex, evolving intensity patterns.
//
// Mathematical Basis:
// Zernike polynomials form an orthonormal basis on the unit disk:
//   Z_n^m(ρ, φ) = R_n^m(ρ) × Θ_m(φ)
//
// where R_n^m is the radial polynomial and Θ_m is the azimuthal component.
//
// Applications:
// - Circular LED array intensity patterns
// - DMX fixture positioning
// - Spatial audio field shaping
// - Wavefront representation
//
// References:
// - Noll, R.J. (1976). Zernike polynomials and atmospheric turbulence
// - Born & Wolf (1999). Principles of Optics, Ch. 9
//
// Created 2026-01-25

import Foundation
import Accelerate

// MARK: - Zernike Mode

/// Single Zernike mode identifier
public struct ZernikeMode: Hashable, Codable, Sendable {
    /// Radial degree (n ≥ 0)
    public let n: Int

    /// Azimuthal frequency (|m| ≤ n, n-|m| even)
    public let m: Int

    /// Noll index (single-index ordering)
    public var nollIndex: Int {
        // Noll's sequential index j = n(n+1)/2 + |m| + ...
        let j = n * (n + 1) / 2 + abs(m)
        return m >= 0 ? j + 1 : j
    }

    /// OSA/ANSI index (alternative ordering)
    public var osaIndex: Int {
        return (n * (n + 2) + m) / 2
    }

    /// Human-readable name
    public var name: String {
        switch (n, m) {
        case (0, 0): return "Piston"
        case (1, 1): return "Tilt X"
        case (1, -1): return "Tilt Y"
        case (2, 0): return "Defocus"
        case (2, 2): return "Astigmatism 0°"
        case (2, -2): return "Astigmatism 45°"
        case (3, 1): return "Coma X"
        case (3, -1): return "Coma Y"
        case (3, 3): return "Trefoil 0°"
        case (3, -3): return "Trefoil 30°"
        case (4, 0): return "Spherical"
        case (4, 2): return "2nd Astig 0°"
        case (4, -2): return "2nd Astig 45°"
        case (4, 4): return "Tetrafoil 0°"
        case (4, -4): return "Tetrafoil 22.5°"
        case (5, 1): return "2nd Coma X"
        case (5, -1): return "2nd Coma Y"
        case (5, 3): return "2nd Trefoil 0°"
        case (5, -3): return "2nd Trefoil 30°"
        case (5, 5): return "Pentafoil 0°"
        case (5, -5): return "Pentafoil 18°"
        case (6, 0): return "2nd Spherical"
        default: return "Z(\(n),\(m))"
        }
    }

    public init(n: Int, m: Int) {
        precondition(n >= 0, "n must be non-negative")
        precondition(abs(m) <= n, "|m| must be ≤ n")
        precondition((n - abs(m)) % 2 == 0, "n - |m| must be even")
        self.n = n
        self.m = m
    }

    /// Create from Noll index
    public static func fromNoll(_ j: Int) -> ZernikeMode {
        // Inverse of Noll indexing
        var n = 0
        var sum = 0
        while sum + n + 1 < j {
            n += 1
            sum += n
        }
        let remainder = j - sum - 1
        let m: Int
        if n % 2 == 0 {
            m = remainder % 2 == 0 ? remainder : -(remainder + 1)
        } else {
            m = remainder % 2 == 0 ? remainder + 1 : -remainder
        }
        return ZernikeMode(n: n, m: m)
    }
}

// MARK: - Zernike Calculator

/// Calculator for Zernike polynomial values
public final class ZernikeCalculator: Sendable {

    // MARK: - Singleton

    public static let shared = ZernikeCalculator()

    // MARK: - Radial Polynomial Cache

    private let factorialCache: [Int]

    private init() {
        // Pre-compute factorials up to 20!
        var cache = [1]
        for i in 1...20 {
            cache.append(cache[i-1] * i)
        }
        factorialCache = cache
    }

    private func factorial(_ n: Int) -> Int {
        guard n >= 0 && n < factorialCache.count else { return 1 }
        return factorialCache[n]
    }

    // MARK: - Radial Polynomial

    /// Calculate radial polynomial R_n^m(ρ)
    ///
    /// R_n^m(ρ) = Σ_{s=0}^{(n-|m|)/2} [(-1)^s (n-s)! / (s! ((n+|m|)/2-s)! ((n-|m|)/2-s)!)] ρ^{n-2s}
    public func radialPolynomial(n: Int, m: Int, rho: Float) -> Float {
        let absM = abs(m)
        guard (n - absM) % 2 == 0 else { return 0 }

        let upperLimit = (n - absM) / 2
        var sum: Float = 0

        for s in 0...upperLimit {
            let sign = (s % 2 == 0) ? 1.0 : -1.0
            let numerator = Float(factorial(n - s))
            let denom1 = Float(factorial(s))
            let denom2 = Float(factorial((n + absM) / 2 - s))
            let denom3 = Float(factorial((n - absM) / 2 - s))

            let denominator = denom1 * denom2 * denom3
            if denominator == 0 { continue }

            let coefficient = Float(sign) * numerator / denominator
            sum += coefficient * pow(rho, Float(n - 2 * s))
        }

        return sum
    }

    // MARK: - Full Zernike Polynomial

    /// Calculate Zernike polynomial Z_n^m(ρ, φ)
    ///
    /// For m ≥ 0: Z_n^m(ρ, φ) = R_n^m(ρ) × cos(mφ)
    /// For m < 0: Z_n^m(ρ, φ) = R_n^{|m|}(ρ) × sin(|m|φ)
    public func evaluate(mode: ZernikeMode, rho: Float, phi: Float) -> Float {
        guard rho <= 1.0 else { return 0 }

        let radial = radialPolynomial(n: mode.n, m: mode.m, rho: rho)

        if mode.m >= 0 {
            return radial * cos(Float(mode.m) * phi)
        } else {
            return radial * sin(Float(abs(mode.m)) * phi)
        }
    }

    /// Calculate multiple Zernike modes at once
    public func evaluateMultiple(modes: [ZernikeMode], rho: Float, phi: Float) -> [Float] {
        return modes.map { evaluate(mode: $0, rho: rho, phi: phi) }
    }

    // MARK: - Surface Evaluation

    /// Evaluate Zernike surface from coefficients
    ///
    /// W(ρ, φ) = Σ_j c_j Z_j(ρ, φ)
    public func evaluateSurface(
        coefficients: [ZernikeMode: Float],
        rho: Float,
        phi: Float
    ) -> Float {
        var sum: Float = 0
        for (mode, coefficient) in coefficients {
            sum += coefficient * evaluate(mode: mode, rho: rho, phi: phi)
        }
        return sum
    }

    /// Evaluate surface on a grid
    public func evaluateSurfaceGrid(
        coefficients: [ZernikeMode: Float],
        gridSize: Int = 64
    ) -> [[Float]] {
        var grid = [[Float]](repeating: [Float](repeating: 0, count: gridSize), count: gridSize)

        let center = Float(gridSize) / 2
        let scale = 1.0 / center

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let dx = (Float(x) - center) * scale
                let dy = (Float(y) - center) * scale
                let rho = sqrt(dx * dx + dy * dy)
                let phi = atan2(dy, dx)

                if rho <= 1.0 {
                    grid[y][x] = evaluateSurface(coefficients: coefficients, rho: rho, phi: phi)
                }
            }
        }

        return grid
    }
}

// MARK: - Light Array Configuration

/// Configuration for a circular light array
public struct LightArrayConfig: Sendable {
    public let lightCount: Int
    public let radius: Float  // Physical radius in meters
    public let centerX: Float
    public let centerY: Float

    /// Position of each light in polar coordinates (rho, phi)
    public let lightPositions: [(rho: Float, phi: Float)]

    /// Create with lights arranged in concentric rings
    public init(
        lightCount: Int,
        radius: Float = 1.0,
        centerX: Float = 0,
        centerY: Float = 0,
        arrangement: LightArrangement = .concentric
    ) {
        self.lightCount = lightCount
        self.radius = radius
        self.centerX = centerX
        self.centerY = centerY

        switch arrangement {
        case .concentric:
            self.lightPositions = Self.concentricArrangement(count: lightCount)
        case .spiral:
            self.lightPositions = Self.spiralArrangement(count: lightCount)
        case .grid:
            self.lightPositions = Self.gridArrangement(count: lightCount)
        case .random:
            self.lightPositions = Self.randomArrangement(count: lightCount)
        }
    }

    public enum LightArrangement: String, Sendable {
        case concentric
        case spiral
        case grid
        case random
    }

    private static func concentricArrangement(count: Int) -> [(rho: Float, phi: Float)] {
        var positions: [(Float, Float)] = []

        // Determine number of rings
        let ringCount = Int(ceil(sqrt(Float(count) / .pi)))
        var remaining = count

        for ring in 1...ringCount {
            let rho = Float(ring) / Float(ringCount)
            let circumference = 2 * Float.pi * rho
            let lightsInRing = min(remaining, max(1, Int(circumference * Float(count) / (2 * .pi))))

            for i in 0..<lightsInRing {
                let phi = 2 * Float.pi * Float(i) / Float(lightsInRing)
                positions.append((rho, phi))
            }

            remaining -= lightsInRing
            if remaining <= 0 { break }
        }

        return positions
    }

    private static func spiralArrangement(count: Int) -> [(rho: Float, phi: Float)] {
        let goldenAngle = Float.pi * (3 - sqrt(5))
        return (0..<count).map { i in
            let rho = sqrt(Float(i + 1) / Float(count))
            let phi = Float(i) * goldenAngle
            return (rho, phi)
        }
    }

    private static func gridArrangement(count: Int) -> [(rho: Float, phi: Float)] {
        var positions: [(Float, Float)] = []
        let side = Int(ceil(sqrt(Float(count))))

        for y in 0..<side {
            for x in 0..<side {
                if positions.count >= count { break }

                let dx = (Float(x) - Float(side - 1) / 2) / Float(side / 2)
                let dy = (Float(y) - Float(side - 1) / 2) / Float(side / 2)
                let rho = sqrt(dx * dx + dy * dy)

                if rho <= 1.0 {
                    let phi = atan2(dy, dx)
                    positions.append((rho, phi))
                }
            }
        }

        return positions
    }

    private static func randomArrangement(count: Int) -> [(rho: Float, phi: Float)] {
        return (0..<count).map { _ in
            // Uniform distribution on disk
            let r = sqrt(Float.random(in: 0...1))
            let theta = Float.random(in: 0...(2 * .pi))
            return (r, theta)
        }
    }
}

// MARK: - Bioreactive Zernike Engine

/// Engine for bioreactive light pattern generation using Zernike polynomials
///
/// Maps latent biometric dimensions to Zernike coefficients,
/// generating evolving intensity patterns for light arrays.
///
/// Usage:
/// ```swift
/// let engine = ZernikeLightEngine(lightCount: 64)
///
/// // Configure coefficient mapping
/// engine.setLatentMapping(latentIndex: 0, mode: ZernikeMode(n: 0, m: 0), weight: 0.5)
/// engine.setLatentMapping(latentIndex: 1, mode: ZernikeMode(n: 2, m: 0), weight: 0.3)
///
/// // Update from biometric state
/// engine.updateFromLatent(latentState)
///
/// // Get light intensities
/// let intensities = engine.getLightIntensities()
/// ```
@MainActor
public final class ZernikeLightEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var coefficients: [ZernikeMode: Float] = [:]
    @Published public private(set) var lightIntensities: [Float] = []
    @Published public private(set) var surfaceGrid: [[Float]] = []

    // MARK: - Configuration

    public let config: LightArrayConfig
    public let calculator = ZernikeCalculator.shared

    /// Active Zernike modes (up to 36 modes for n ≤ 5)
    public var activeModes: [ZernikeMode] = []

    /// Mapping from latent dimension index to Zernike coefficients
    /// latentMapping[latentIndex] = [(mode, weight), ...]
    public var latentMapping: [[ZernikeMode: Float]] = []

    /// Base coefficients (static offset)
    public var baseCoefficients: [ZernikeMode: Float] = [:]

    /// Coefficient smoothing (0 = instant, 1 = frozen)
    public var smoothingFactor: Float = 0.1

    /// Intensity range
    public var minIntensity: Float = 0.0
    public var maxIntensity: Float = 1.0

    /// Animation rates for each mode (radians per second)
    public var animationRates: [ZernikeMode: Float] = [:]

    // MARK: - Private State

    private var targetCoefficients: [ZernikeMode: Float] = [:]
    private var animationPhases: [ZernikeMode: Float] = [:]

    // MARK: - Initialization

    public init(lightCount: Int = 64, arrangement: LightArrayConfig.LightArrangement = .concentric) {
        self.config = LightArrayConfig(
            lightCount: lightCount,
            arrangement: arrangement
        )

        setupDefaultModes()
        setupDefaultMapping()
    }

    public init(config: LightArrayConfig) {
        self.config = config
        setupDefaultModes()
        setupDefaultMapping()
    }

    private func setupDefaultModes() {
        // First 15 Zernike modes (up to n=4)
        activeModes = [
            ZernikeMode(n: 0, m: 0),   // Piston
            ZernikeMode(n: 1, m: 1),   // Tilt X
            ZernikeMode(n: 1, m: -1),  // Tilt Y
            ZernikeMode(n: 2, m: 0),   // Defocus
            ZernikeMode(n: 2, m: 2),   // Astigmatism 0°
            ZernikeMode(n: 2, m: -2),  // Astigmatism 45°
            ZernikeMode(n: 3, m: 1),   // Coma X
            ZernikeMode(n: 3, m: -1),  // Coma Y
            ZernikeMode(n: 3, m: 3),   // Trefoil 0°
            ZernikeMode(n: 3, m: -3),  // Trefoil 30°
            ZernikeMode(n: 4, m: 0),   // Spherical
            ZernikeMode(n: 4, m: 2),   // 2nd Astig 0°
            ZernikeMode(n: 4, m: -2),  // 2nd Astig 45°
            ZernikeMode(n: 4, m: 4),   // Tetrafoil 0°
            ZernikeMode(n: 4, m: -4)   // Tetrafoil 22.5°
        ]

        // Initialize coefficients
        for mode in activeModes {
            coefficients[mode] = 0
            targetCoefficients[mode] = 0
            animationPhases[mode] = 0
        }

        // Set base piston (overall brightness)
        baseCoefficients[ZernikeMode(n: 0, m: 0)] = 0.5

        lightIntensities = [Float](repeating: 0.5, count: config.lightCount)
    }

    private func setupDefaultMapping() {
        // 8 latent dimensions -> Zernike coefficients
        latentMapping = [
            // Arousal (PC1) -> Piston (brightness) and Defocus
            [
                ZernikeMode(n: 0, m: 0): 0.3,
                ZernikeMode(n: 2, m: 0): 0.2
            ],
            // Valence (PC2) -> Tilt X
            [
                ZernikeMode(n: 1, m: 1): 0.25
            ],
            // Coherence (PC3) -> Spherical aberration (radial symmetry)
            [
                ZernikeMode(n: 4, m: 0): 0.3,
                ZernikeMode(n: 2, m: 0): 0.15
            ],
            // Attention (PC4) -> Astigmatism (focus on one axis)
            [
                ZernikeMode(n: 2, m: 2): 0.2
            ],
            // PC5 -> Tilt Y
            [
                ZernikeMode(n: 1, m: -1): 0.2
            ],
            // PC6 -> Coma
            [
                ZernikeMode(n: 3, m: 1): 0.15,
                ZernikeMode(n: 3, m: -1): 0.15
            ],
            // PC7 -> Trefoil
            [
                ZernikeMode(n: 3, m: 3): 0.15
            ],
            // PC8 -> Tetrafoil
            [
                ZernikeMode(n: 4, m: 4): 0.1
            ]
        ]
    }

    // MARK: - Configuration

    /// Set mapping from latent dimension to Zernike mode
    public func setLatentMapping(latentIndex: Int, mode: ZernikeMode, weight: Float) {
        while latentMapping.count <= latentIndex {
            latentMapping.append([:])
        }
        latentMapping[latentIndex][mode] = weight

        if !activeModes.contains(mode) {
            activeModes.append(mode)
            coefficients[mode] = 0
            targetCoefficients[mode] = 0
        }
    }

    /// Set animation rate for a mode
    public func setAnimationRate(mode: ZernikeMode, rate: Float) {
        animationRates[mode] = rate
        animationPhases[mode] = 0
    }

    // MARK: - Bioreactive Update

    /// Update from latent biometric state
    public func updateFromLatent(_ latent: [Float], deltaTime: Float = 1/60) {
        // Calculate target coefficients from latent state
        for mode in activeModes {
            var target = baseCoefficients[mode] ?? 0

            for (latentIndex, mapping) in latentMapping.enumerated() {
                if latentIndex < latent.count, let weight = mapping[mode] {
                    let latentValue = latent[latentIndex] - 0.5  // Center around 0
                    target += latentValue * weight
                }
            }

            // Apply animation if set
            if let rate = animationRates[mode], rate != 0 {
                animationPhases[mode] = (animationPhases[mode] ?? 0) + rate * deltaTime
                target *= 1.0 + 0.3 * sin(animationPhases[mode] ?? 0)
            }

            targetCoefficients[mode] = target
        }

        // Smooth coefficient changes
        for mode in activeModes {
            let current = coefficients[mode] ?? 0
            let target = targetCoefficients[mode] ?? 0
            let smoothed = current + (1 - smoothingFactor) * (target - current)
            coefficients[mode] = smoothed
        }

        // Calculate light intensities
        updateLightIntensities()
    }

    /// Direct coefficient update
    public func setCoefficients(_ newCoefficients: [ZernikeMode: Float]) {
        for (mode, value) in newCoefficients {
            coefficients[mode] = value
            targetCoefficients[mode] = value
        }
        updateLightIntensities()
    }

    // MARK: - Intensity Calculation

    private func updateLightIntensities() {
        lightIntensities = config.lightPositions.map { position in
            let intensity = calculator.evaluateSurface(
                coefficients: coefficients,
                rho: position.rho,
                phi: position.phi
            )

            // Normalize and clamp
            let normalized = (intensity + 1) / 2  // Map [-1, 1] to [0, 1]
            return minIntensity + (maxIntensity - minIntensity) * max(0, min(1, normalized))
        }
    }

    /// Update surface grid for visualization
    public func updateSurfaceGrid(gridSize: Int = 64) {
        surfaceGrid = calculator.evaluateSurfaceGrid(
            coefficients: coefficients,
            gridSize: gridSize
        )
    }

    // MARK: - Output

    /// Get DMX values (0-255)
    public func getDMXValues() -> [UInt8] {
        return lightIntensities.map { UInt8(max(0, min(255, $0 * 255))) }
    }

    /// Get RGB values for colored lights (single hue)
    public func getRGBValues(hue: Float = 0.5, saturation: Float = 0.7) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        return lightIntensities.map { intensity in
            let (r, g, b) = hsvToRGB(h: hue, s: saturation, v: intensity)
            return (
                r: UInt8(max(0, min(255, r * 255))),
                g: UInt8(max(0, min(255, g * 255))),
                b: UInt8(max(0, min(255, b * 255)))
            )
        }
    }

    /// Get Cartesian positions with intensities
    public func getLightPositionsWithIntensities() -> [(x: Float, y: Float, intensity: Float)] {
        return zip(config.lightPositions, lightIntensities).map { position, intensity in
            let x = config.centerX + config.radius * position.rho * cos(position.phi)
            let y = config.centerY + config.radius * position.rho * sin(position.phi)
            return (x: x, y: y, intensity: intensity)
        }
    }
}

// MARK: - Helper Functions

private func hsvToRGB(h: Float, s: Float, v: Float) -> (Float, Float, Float) {
    let c = v * s
    let x = c * (1 - abs(fmod(h * 6, 2) - 1))
    let m = v - c

    let (r, g, b): (Float, Float, Float)

    switch Int(h * 6) % 6 {
    case 0: (r, g, b) = (c, x, 0)
    case 1: (r, g, b) = (x, c, 0)
    case 2: (r, g, b) = (0, c, x)
    case 3: (r, g, b) = (0, x, c)
    case 4: (r, g, b) = (x, 0, c)
    default: (r, g, b) = (c, 0, x)
    }

    return (r + m, g + m, b + m)
}

// MARK: - Preset Patterns

extension ZernikeLightEngine {

    /// Preset pattern configurations
    public enum Preset: String, CaseIterable, Sendable {
        case uniform
        case gradient
        case focus
        case spiral
        case meditation
        case energetic
        case cosmic
    }

    /// Apply a preset configuration
    public func applyPreset(_ preset: Preset) {
        // Clear current
        for mode in activeModes {
            coefficients[mode] = 0
            animationRates.removeValue(forKey: mode)
        }

        switch preset {
        case .uniform:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.7

        case .gradient:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.5
            coefficients[ZernikeMode(n: 1, m: 1)] = 0.3

        case .focus:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.6
            coefficients[ZernikeMode(n: 2, m: 0)] = -0.4  // Negative defocus = central bright
            coefficients[ZernikeMode(n: 4, m: 0)] = 0.2

        case .spiral:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.5
            coefficients[ZernikeMode(n: 3, m: 3)] = 0.3
            animationRates[ZernikeMode(n: 3, m: 3)] = 0.5

        case .meditation:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.4
            coefficients[ZernikeMode(n: 4, m: 0)] = 0.3  // Spherical - radial symmetry
            animationRates[ZernikeMode(n: 4, m: 0)] = 0.1  // Slow pulsing

        case .energetic:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.6
            coefficients[ZernikeMode(n: 2, m: 2)] = 0.25
            coefficients[ZernikeMode(n: 3, m: 3)] = 0.2
            coefficients[ZernikeMode(n: 4, m: 4)] = 0.15
            animationRates[ZernikeMode(n: 3, m: 3)] = 1.0
            animationRates[ZernikeMode(n: 4, m: 4)] = 0.7

        case .cosmic:
            coefficients[ZernikeMode(n: 0, m: 0)] = 0.3
            coefficients[ZernikeMode(n: 2, m: 0)] = 0.2
            coefficients[ZernikeMode(n: 3, m: 1)] = 0.15
            coefficients[ZernikeMode(n: 3, m: -1)] = 0.15
            coefficients[ZernikeMode(n: 4, m: 0)] = 0.25
            animationRates[ZernikeMode(n: 3, m: 1)] = 0.3
            animationRates[ZernikeMode(n: 3, m: -1)] = -0.2  // Counter-rotate
        }

        updateLightIntensities()
    }
}
