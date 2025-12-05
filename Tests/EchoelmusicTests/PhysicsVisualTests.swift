import XCTest
@testable import Echoelmusic

/// Tests for the Physics/Antigravity Visual Engine
final class PhysicsVisualTests: XCTestCase {

    // MARK: - Particle Tests

    func testParticleCreation() {
        let particle = TestParticle(
            position: SIMD2<Float>(0.5, 0.5),
            velocity: SIMD2<Float>(0.1, -0.1),
            size: 2.0,
            life: 5.0
        )

        XCTAssertEqual(particle.position.x, 0.5)
        XCTAssertEqual(particle.position.y, 0.5)
        XCTAssertEqual(particle.size, 2.0)
        XCTAssertEqual(particle.life, 5.0)
    }

    func testParticleUpdate() {
        var particle = TestParticle(
            position: SIMD2<Float>(0.5, 0.5),
            velocity: SIMD2<Float>(0.1, 0.1),
            size: 2.0,
            life: 5.0
        )

        let dt: Float = 0.016 // ~60fps
        particle.update(dt: dt)

        XCTAssertGreaterThan(particle.position.x, 0.5)
        XCTAssertGreaterThan(particle.position.y, 0.5)
        XCTAssertLessThan(particle.life, 5.0)
    }

    // MARK: - Force Field Tests

    func testGravityForce() {
        let gravity = GravityForce(strength: SIMD2<Float>(0, -9.8))
        let position = SIMD2<Float>(0.5, 0.5)

        let force = gravity.calculate(at: position)

        XCTAssertEqual(force.x, 0)
        XCTAssertLessThan(force.y, 0) // Downward force
    }

    func testAttractorForce() {
        let attractor = AttractorForce(
            position: SIMD2<Float>(0.5, 0.5),
            strength: 100,
            falloff: 2.0
        )

        // Particle away from center
        let particlePos = SIMD2<Float>(0.7, 0.5)
        let force = attractor.calculate(at: particlePos)

        XCTAssertLessThan(force.x, 0) // Force pointing toward attractor
    }

    func testRepulsorForce() {
        let repulsor = RepulsorForce(
            position: SIMD2<Float>(0.5, 0.5),
            strength: 100,
            falloff: 2.0
        )

        let particlePos = SIMD2<Float>(0.6, 0.5)
        let force = repulsor.calculate(at: particlePos)

        XCTAssertGreaterThan(force.x, 0) // Force pointing away from repulsor
    }

    func testVortexForce() {
        let vortex = VortexForce(
            position: SIMD2<Float>(0.5, 0.5),
            strength: 5.0,
            radius: 0.3
        )

        let particlePos = SIMD2<Float>(0.6, 0.5)
        let force = vortex.calculate(at: particlePos)

        // Vortex should create tangential force
        XCTAssertNotEqual(force.x, 0)
        XCTAssertNotEqual(force.y, 0)
    }

    func testTurbulenceForce() {
        let turbulence = TurbulenceForce(
            strength: 1.0,
            scale: 0.1,
            seed: 42
        )

        let pos1 = SIMD2<Float>(0.3, 0.3)
        let pos2 = SIMD2<Float>(0.7, 0.7)

        let force1 = turbulence.calculate(at: pos1)
        let force2 = turbulence.calculate(at: pos2)

        // Different positions should (usually) give different forces
        XCTAssertTrue(force1.x != force2.x || force1.y != force2.y)
    }

    // MARK: - Particle System Tests

    func testParticleSystemCreation() {
        let system = TestParticleSystem(maxParticles: 10000)

        XCTAssertEqual(system.maxParticles, 10000)
        XCTAssertEqual(system.activeParticles, 0)
    }

    func testParticleEmission() {
        let system = TestParticleSystem(maxParticles: 1000)

        system.emit(count: 100, at: SIMD2<Float>(0.5, 0.5))

        XCTAssertEqual(system.activeParticles, 100)
    }

    func testParticleSystemUpdate() {
        let system = TestParticleSystem(maxParticles: 1000)
        system.emit(count: 50, at: SIMD2<Float>(0.5, 0.5))

        let initialCount = system.activeParticles
        system.update(dt: 10.0) // Long dt to expire some particles

        // Some particles should have expired
        XCTAssertLessThanOrEqual(system.activeParticles, initialCount)
    }

    // MARK: - Audio Reactivity Tests

    func testAudioReactiveMapping() {
        let mapper = AudioReactiveMapper()

        let audioLevel: Float = 0.8
        let mapped = mapper.mapToSize(audioLevel, baseSize: 2.0, multiplier: 2.0)

        XCTAssertGreaterThan(mapped, 2.0)
        XCTAssertLessThanOrEqual(mapped, 4.0)
    }

    func testFrequencyBandMapping() {
        let mapper = AudioReactiveMapper()

        let bands: [Float] = [0.1, 0.5, 0.8, 0.3, 0.2] // Low to high
        let colors = mapper.mapToColors(bands)

        XCTAssertEqual(colors.count, bands.count)
    }

    // MARK: - Preset Tests

    func testPresetApplication() {
        let system = TestParticleSystem(maxParticles: 1000)

        let preset = PhysicsPresetConfig(
            name: "Cosmic",
            gravity: SIMD2<Float>(0, -0.5),
            turbulence: 0.3,
            particleSize: 3.0,
            particleLife: 5.0
        )

        system.applyPreset(preset)

        XCTAssertEqual(system.config.particleSize, 3.0)
        XCTAssertEqual(system.config.particleLife, 5.0)
    }

    // MARK: - Performance Tests

    func testParticleUpdatePerformance() {
        let system = TestParticleSystem(maxParticles: 100000)
        system.emit(count: 50000, at: SIMD2<Float>(0.5, 0.5))

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(options: options) {
            system.update(dt: 0.016)
        }
    }

    func testForceCalculationPerformance() {
        let forces: [ForceCalculator] = [
            GravityForce(strength: SIMD2<Float>(0, -9.8)),
            AttractorForce(position: SIMD2<Float>(0.5, 0.5), strength: 100, falloff: 2),
            VortexForce(position: SIMD2<Float>(0.5, 0.5), strength: 5, radius: 0.3),
            TurbulenceForce(strength: 1, scale: 0.1, seed: 42)
        ]

        let positions = (0..<10000).map { _ in
            SIMD2<Float>(Float.random(in: 0...1), Float.random(in: 0...1))
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(options: options) {
            for pos in positions {
                for force in forces {
                    _ = force.calculate(at: pos)
                }
            }
        }
    }
}

// MARK: - Test Support Types

struct TestParticle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var size: Float
    var life: Float

    mutating func update(dt: Float) {
        position += velocity * dt
        life -= dt
    }
}

protocol ForceCalculator {
    func calculate(at position: SIMD2<Float>) -> SIMD2<Float>
}

struct GravityForce: ForceCalculator {
    let strength: SIMD2<Float>

    func calculate(at position: SIMD2<Float>) -> SIMD2<Float> {
        return strength
    }
}

struct AttractorForce: ForceCalculator {
    let position: SIMD2<Float>
    let strength: Float
    let falloff: Float

    func calculate(at particlePos: SIMD2<Float>) -> SIMD2<Float> {
        let direction = position - particlePos
        let distance = simd_length(direction)
        guard distance > 0.001 else { return .zero }

        let normalizedDir = direction / distance
        let forceMagnitude = strength / pow(distance, falloff)

        return normalizedDir * forceMagnitude
    }
}

struct RepulsorForce: ForceCalculator {
    let position: SIMD2<Float>
    let strength: Float
    let falloff: Float

    func calculate(at particlePos: SIMD2<Float>) -> SIMD2<Float> {
        let direction = particlePos - position
        let distance = simd_length(direction)
        guard distance > 0.001 else { return .zero }

        let normalizedDir = direction / distance
        let forceMagnitude = strength / pow(distance, falloff)

        return normalizedDir * forceMagnitude
    }
}

struct VortexForce: ForceCalculator {
    let position: SIMD2<Float>
    let strength: Float
    let radius: Float

    func calculate(at particlePos: SIMD2<Float>) -> SIMD2<Float> {
        let direction = particlePos - position
        let distance = simd_length(direction)
        guard distance > 0.001 && distance < radius else { return .zero }

        // Perpendicular direction for rotation
        let tangent = SIMD2<Float>(-direction.y, direction.x) / distance
        let forceMagnitude = strength * (1 - distance / radius)

        return tangent * forceMagnitude
    }
}

struct TurbulenceForce: ForceCalculator {
    let strength: Float
    let scale: Float
    let seed: UInt64

    func calculate(at position: SIMD2<Float>) -> SIMD2<Float> {
        // Simple noise-based turbulence
        let x = sin(position.x * 10 + Float(seed)) * strength
        let y = cos(position.y * 10 + Float(seed)) * strength
        return SIMD2<Float>(x, y)
    }
}

class TestParticleSystem {
    let maxParticles: Int
    var particles: [TestParticle] = []
    var config = ParticleConfig()

    struct ParticleConfig {
        var particleSize: Float = 2.0
        var particleLife: Float = 5.0
    }

    var activeParticles: Int { particles.count }

    init(maxParticles: Int) {
        self.maxParticles = maxParticles
    }

    func emit(count: Int, at position: SIMD2<Float>) {
        for _ in 0..<min(count, maxParticles - particles.count) {
            particles.append(TestParticle(
                position: position,
                velocity: SIMD2<Float>(
                    Float.random(in: -0.1...0.1),
                    Float.random(in: -0.1...0.1)
                ),
                size: config.particleSize,
                life: config.particleLife
            ))
        }
    }

    func update(dt: Float) {
        particles = particles.compactMap { particle in
            var p = particle
            p.update(dt: dt)
            return p.life > 0 ? p : nil
        }
    }

    func applyPreset(_ preset: PhysicsPresetConfig) {
        config.particleSize = preset.particleSize
        config.particleLife = preset.particleLife
    }
}

struct PhysicsPresetConfig {
    let name: String
    let gravity: SIMD2<Float>
    let turbulence: Float
    let particleSize: Float
    let particleLife: Float
}

class AudioReactiveMapper {
    func mapToSize(_ level: Float, baseSize: Float, multiplier: Float) -> Float {
        return baseSize + level * baseSize * (multiplier - 1)
    }

    func mapToColors(_ bands: [Float]) -> [(Float, Float, Float)] {
        return bands.map { band in
            (band, 1 - band, 0.5)
        }
    }
}
