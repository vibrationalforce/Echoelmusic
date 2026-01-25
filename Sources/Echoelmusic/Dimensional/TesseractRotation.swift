// TesseractRotation.swift
// Echoelmusic
//
// 4D Hypercube (Tesseract) rotation for spatial audio and lighting modulation.
// Maps N-dimensional latent state to rotation angles in 4D space,
// then projects to 3D for physical speaker/light array positioning.
//
// Mathematical Basis:
// - 4D rotation group SO(4) has 6 independent rotation planes
// - Each plane parameterized by angle θᵢ
// - Biometric latent dimensions map to rotation angles
// - 3D projection reveals complex, evolving spatial patterns
//
// References:
// - Coxeter, H.S.M. (1973). Regular Polytopes
// - Hanson, A.J. (1994). Quaternion Rotations in 4D
//
// Created 2026-01-25

import Foundation
import Accelerate
import simd

// MARK: - 4D Vector

/// A point or vector in 4-dimensional space
public struct Vector4: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float

    public init(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0, _ w: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let zero = Vector4(0, 0, 0, 0)
    public static let unitX = Vector4(1, 0, 0, 0)
    public static let unitY = Vector4(0, 1, 0, 0)
    public static let unitZ = Vector4(0, 0, 1, 0)
    public static let unitW = Vector4(0, 0, 0, 1)

    public var magnitude: Float {
        sqrt(x*x + y*y + z*z + w*w)
    }

    public var normalized: Vector4 {
        let m = magnitude
        guard m > 0 else { return .zero }
        return Vector4(x/m, y/m, z/m, w/m)
    }

    /// Project to 3D by discarding w (orthographic projection)
    public var xyz: SIMD3<Float> {
        SIMD3(x, y, z)
    }

    /// Perspective projection from 4D to 3D
    public func perspectiveProject(distance: Float = 2.0) -> SIMD3<Float> {
        let scale = distance / (distance - w)
        return SIMD3(x * scale, y * scale, z * scale)
    }

    public static func + (lhs: Vector4, rhs: Vector4) -> Vector4 {
        Vector4(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z, lhs.w + rhs.w)
    }

    public static func * (lhs: Vector4, rhs: Float) -> Vector4 {
        Vector4(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs, lhs.w * rhs)
    }

    public static func dot(_ a: Vector4, _ b: Vector4) -> Float {
        a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
    }
}

// MARK: - 4x4 Matrix (for 4D transformations)

/// 4x4 matrix for 4D transformations
public struct Matrix4x4: Sendable {
    public var elements: [Float]  // Row-major, 16 elements

    public init(_ elements: [Float]) {
        precondition(elements.count == 16)
        self.elements = elements
    }

    public static let identity = Matrix4x4([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    ])

    /// Multiply matrix by vector
    public func transform(_ v: Vector4) -> Vector4 {
        let x = elements[0] * v.x + elements[1] * v.y + elements[2] * v.z + elements[3] * v.w
        let y = elements[4] * v.x + elements[5] * v.y + elements[6] * v.z + elements[7] * v.w
        let z = elements[8] * v.x + elements[9] * v.y + elements[10] * v.z + elements[11] * v.w
        let w = elements[12] * v.x + elements[13] * v.y + elements[14] * v.z + elements[15] * v.w
        return Vector4(x, y, z, w)
    }

    /// Matrix multiplication
    public static func * (a: Matrix4x4, b: Matrix4x4) -> Matrix4x4 {
        var result = [Float](repeating: 0, count: 16)

        for i in 0..<4 {
            for j in 0..<4 {
                var sum: Float = 0
                for k in 0..<4 {
                    sum += a.elements[i * 4 + k] * b.elements[k * 4 + j]
                }
                result[i * 4 + j] = sum
            }
        }

        return Matrix4x4(result)
    }
}

// MARK: - Rotation Plane

/// The 6 rotation planes in 4D space
public enum RotationPlane4D: Int, CaseIterable, Sendable {
    case xy = 0  // X-Y plane
    case xz = 1  // X-Z plane
    case xw = 2  // X-W plane (4D specific)
    case yz = 3  // Y-Z plane
    case yw = 4  // Y-W plane (4D specific)
    case zw = 5  // Z-W plane (4D specific)

    public var name: String {
        switch self {
        case .xy: return "XY (Roll)"
        case .xz: return "XZ (Pitch)"
        case .xw: return "XW (4D Twist)"
        case .yz: return "YZ (Yaw)"
        case .yw: return "YW (4D Tilt)"
        case .zw: return "ZW (4D Spin)"
        }
    }
}

// MARK: - Rotation Matrices

extension Matrix4x4 {

    /// Create rotation matrix for a specific plane
    public static func rotation(plane: RotationPlane4D, angle: Float) -> Matrix4x4 {
        let c = cos(angle)
        let s = sin(angle)

        var m = Matrix4x4.identity.elements

        switch plane {
        case .xy:
            m[0] = c;  m[1] = -s
            m[4] = s;  m[5] = c

        case .xz:
            m[0] = c;  m[2] = -s
            m[8] = s;  m[10] = c

        case .xw:
            m[0] = c;  m[3] = -s
            m[12] = s; m[15] = c

        case .yz:
            m[5] = c;  m[6] = -s
            m[9] = s;  m[10] = c

        case .yw:
            m[5] = c;  m[7] = -s
            m[13] = s; m[15] = c

        case .zw:
            m[10] = c; m[11] = -s
            m[14] = s; m[15] = c
        }

        return Matrix4x4(m)
    }

    /// Create combined rotation from 6 angles
    public static func rotation4D(angles: [Float]) -> Matrix4x4 {
        precondition(angles.count == 6)

        var result = Matrix4x4.identity

        for (i, plane) in RotationPlane4D.allCases.enumerated() {
            let rot = Matrix4x4.rotation(plane: plane, angle: angles[i])
            result = result * rot
        }

        return result
    }
}

// MARK: - Tesseract Vertices

/// Generate the 16 vertices of a unit tesseract
public func tesseractVertices() -> [Vector4] {
    var vertices: [Vector4] = []

    for x in [-1.0, 1.0] as [Float] {
        for y in [-1.0, 1.0] as [Float] {
            for z in [-1.0, 1.0] as [Float] {
                for w in [-1.0, 1.0] as [Float] {
                    vertices.append(Vector4(x, y, z, w) * 0.5)
                }
            }
        }
    }

    return vertices
}

/// Generate the 32 edges of a tesseract (pairs of vertex indices)
public func tesseractEdges() -> [(Int, Int)] {
    var edges: [(Int, Int)] = []
    let vertices = tesseractVertices()

    for i in 0..<vertices.count {
        for j in (i + 1)..<vertices.count {
            // Two vertices are connected if they differ in exactly one coordinate
            let diff = Vector4(
                abs(vertices[i].x - vertices[j].x),
                abs(vertices[i].y - vertices[j].y),
                abs(vertices[i].z - vertices[j].z),
                abs(vertices[i].w - vertices[j].w)
            )

            let diffCount = (diff.x > 0.5 ? 1 : 0) +
                           (diff.y > 0.5 ? 1 : 0) +
                           (diff.z > 0.5 ? 1 : 0) +
                           (diff.w > 0.5 ? 1 : 0)

            if diffCount == 1 {
                edges.append((i, j))
            }
        }
    }

    return edges
}

// MARK: - Tesseract Rotation Engine

/// Engine for bioreactive tesseract rotation
///
/// Maps latent biometric dimensions to 4D rotation angles,
/// creating complex, evolving spatial patterns for speaker
/// and light array positioning.
///
/// Usage:
/// ```swift
/// let engine = TesseractRotationEngine()
///
/// // Configure speaker positions in 4D
/// engine.setSpeakerPositions(count: 8)
///
/// // Update from latent state
/// engine.updateFromLatent(latentState)
///
/// // Get 3D positions for physical speakers
/// let positions = engine.get3DPositions()
/// ```
@MainActor
public final class TesseractRotationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var rotationAngles: [Float] = [0, 0, 0, 0, 0, 0]
    @Published public private(set) var positions4D: [Vector4] = []
    @Published public private(set) var positions3D: [SIMD3<Float>] = []

    // MARK: - Configuration

    /// Rotation speed multipliers for each plane
    public var rotationSpeeds: [Float] = [1, 1, 1, 1, 1, 1]

    /// Base rotation rates (radians per second)
    public var baseRotationRates: [Float] = [0.1, 0.05, 0.02, 0.08, 0.03, 0.01]

    /// Scale factor for 3D projection
    public var projectionScale: Float = 1.0

    /// Projection type
    public var usePerpsectiveProjection: Bool = true
    public var perspectiveDistance: Float = 3.0

    /// Latent-to-rotation mapping (6 angles from N latent dims)
    public var latentMapping: [[Float]] = [
        [1.0, 0.0, 0.0, 0.0],  // XY from arousal
        [0.0, 1.0, 0.0, 0.0],  // XZ from valence
        [0.5, 0.5, 0.0, 0.0],  // XW from arousal+valence
        [0.0, 0.0, 1.0, 0.0],  // YZ from coherence
        [0.0, 0.0, 0.5, 0.5],  // YW from coherence+attention
        [0.3, 0.3, 0.3, 0.0]   // ZW from combined
    ]

    // MARK: - Private State

    private var originalPositions: [Vector4] = []
    private var currentRotation: Matrix4x4 = .identity
    private var angularVelocities: [Float] = [0, 0, 0, 0, 0, 0]

    // MARK: - Initialization

    public init() {
        // Default: cube corners in 4D (8 speakers)
        setSpeakerPositions(count: 8)
    }

    // MARK: - Configuration

    /// Configure speaker positions
    /// - Parameter count: Number of speakers (supports 4, 8, 16)
    public func setSpeakerPositions(count: Int) {
        switch count {
        case 4:
            // Tetrahedron in 4D
            originalPositions = [
                Vector4(1, 1, 1, -1).normalized * 0.5,
                Vector4(1, -1, -1, -1).normalized * 0.5,
                Vector4(-1, 1, -1, -1).normalized * 0.5,
                Vector4(-1, -1, 1, -1).normalized * 0.5
            ]

        case 8:
            // Hypercube vertices on one "face"
            var positions: [Vector4] = []
            for x in [-1.0, 1.0] as [Float] {
                for y in [-1.0, 1.0] as [Float] {
                    for z in [-1.0, 1.0] as [Float] {
                        positions.append(Vector4(x, y, z, 0) * 0.5)
                    }
                }
            }
            originalPositions = positions

        case 16:
            // Full tesseract
            originalPositions = tesseractVertices()

        default:
            // Distribute points on 3-sphere (4D sphere surface)
            originalPositions = fibonacciSphere4D(count: count)
        }

        positions4D = originalPositions
        updateProjection()
    }

    /// Custom speaker positions
    public func setCustomPositions(_ positions: [Vector4]) {
        originalPositions = positions
        positions4D = positions
        updateProjection()
    }

    // MARK: - Bioreactive Update

    /// Update rotation from latent biometric state
    public func updateFromLatent(_ latent: [Float], deltaTime: Float = 1/60) {
        // Map latent dimensions to target angular velocities
        var targetVelocities = [Float](repeating: 0, count: 6)

        for i in 0..<6 {
            var velocity = baseRotationRates[i]

            for j in 0..<min(latent.count, latentMapping[i].count) {
                let latentValue = latent[j] - 0.5  // Center around 0
                velocity += latentValue * latentMapping[i][j] * rotationSpeeds[i]
            }

            targetVelocities[i] = velocity
        }

        // Smooth velocity changes
        for i in 0..<6 {
            angularVelocities[i] = angularVelocities[i] * 0.9 + targetVelocities[i] * 0.1
        }

        // Update angles
        for i in 0..<6 {
            rotationAngles[i] += angularVelocities[i] * deltaTime
            // Keep angles in reasonable range
            if rotationAngles[i] > .pi * 2 {
                rotationAngles[i] -= .pi * 2
            } else if rotationAngles[i] < -.pi * 2 {
                rotationAngles[i] += .pi * 2
            }
        }

        // Compute rotation matrix
        currentRotation = Matrix4x4.rotation4D(angles: rotationAngles)

        // Transform positions
        positions4D = originalPositions.map { currentRotation.transform($0) }

        // Project to 3D
        updateProjection()
    }

    /// Direct angle update (for manual control)
    public func setRotationAngles(_ angles: [Float]) {
        guard angles.count == 6 else { return }
        rotationAngles = angles
        currentRotation = Matrix4x4.rotation4D(angles: angles)
        positions4D = originalPositions.map { currentRotation.transform($0) }
        updateProjection()
    }

    // MARK: - Projection

    private func updateProjection() {
        if usePerpsectiveProjection {
            positions3D = positions4D.map {
                $0.perspectiveProject(distance: perspectiveDistance) * projectionScale
            }
        } else {
            positions3D = positions4D.map { $0.xyz * projectionScale }
        }
    }

    /// Get speaker positions as array for audio engine
    public func getSpeakerPositions() -> [(x: Float, y: Float, z: Float)] {
        return positions3D.map { (x: $0.x, y: $0.y, z: $0.z) }
    }

    /// Get positions as normalized azimuth/elevation pairs
    public func getSphericalPositions() -> [(azimuth: Float, elevation: Float, distance: Float)] {
        return positions3D.map { pos in
            let distance = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            let azimuth = atan2(pos.x, pos.z) * 180 / .pi
            let elevation = asin(pos.y / max(distance, 0.001)) * 180 / .pi
            return (azimuth: azimuth, elevation: elevation, distance: distance)
        }
    }
}

// MARK: - Helper Functions

/// Generate points on a 4D Fibonacci sphere
private func fibonacciSphere4D(count: Int) -> [Vector4] {
    var points: [Vector4] = []

    let goldenRatio = (1 + sqrt(5.0)) / 2
    let angleIncrement1 = 2 * Float.pi / pow(Float(goldenRatio), 2)
    let angleIncrement2 = 2 * Float.pi / Float(goldenRatio)

    for i in 0..<count {
        let t = Float(i) / Float(count - 1)

        // Parametric 4D sphere
        let theta1 = Float(i) * angleIncrement1
        let theta2 = Float(i) * angleIncrement2
        let phi = acos(1 - 2 * t)

        let x = sin(phi) * cos(theta1) * cos(theta2)
        let y = sin(phi) * cos(theta1) * sin(theta2)
        let z = sin(phi) * sin(theta1)
        let w = cos(phi)

        points.append(Vector4(x, y, z, w) * 0.5)
    }

    return points
}

// MARK: - Visualization Support

extension TesseractRotationEngine {

    /// Get tesseract wireframe for visualization
    public func getWireframe() -> (vertices: [SIMD3<Float>], edges: [(Int, Int)]) {
        let vertices4D = tesseractVertices()
        let rotated = vertices4D.map { currentRotation.transform($0) }

        let projected: [SIMD3<Float>]
        if usePerpsectiveProjection {
            projected = rotated.map { $0.perspectiveProject(distance: perspectiveDistance) * projectionScale }
        } else {
            projected = rotated.map { $0.xyz * projectionScale }
        }

        return (vertices: projected, edges: tesseractEdges())
    }

    /// Get inner cube (w = -0.5) and outer cube (w = +0.5) for visualization
    public func getInnerOuterCubes() -> (inner: [SIMD3<Float>], outer: [SIMD3<Float>]) {
        var inner: [SIMD3<Float>] = []
        var outer: [SIMD3<Float>] = []

        let vertices4D = tesseractVertices()
        for v in vertices4D {
            let rotated = currentRotation.transform(v)
            let projected = usePerpsectiveProjection
                ? rotated.perspectiveProject(distance: perspectiveDistance) * projectionScale
                : rotated.xyz * projectionScale

            if v.w < 0 {
                inner.append(projected)
            } else {
                outer.append(projected)
            }
        }

        return (inner, outer)
    }
}
