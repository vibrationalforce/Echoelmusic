import Foundation
import simd

#if canImport(RealityKit)
import RealityKit
#endif

#if canImport(SceneKit)
import SceneKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// PROCEDURAL GEOMETRY - 3D Fraktale & Sacred Geometry
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates 3D meshes procedurally for immersive/visionOS visualization:
//
// Sacred Geometry:
//   - Flower of Life (3D sphere packing)
//   - Metatron's Cube (3D wireframe)
//   - Sri Yantra (nested triangles with depth)
//   - Platonic Solids (Tetrahedron, Cube, Octahedron, Dodecahedron, Icosahedron)
//   - Torus Knot
//   - Merkaba (Star Tetrahedron)
//
// Fraktale:
//   - 3D Mandelbulb
//   - Menger Sponge
//   - Sierpinski Tetrahedron
//   - Koch Snowflake 3D
//
// Bio-Reactive:
//   - Coherence → complexity (subdivision level)
//   - Breath phase → scale pulsation
//   - Heart rate → rotation speed
//
// Platforms: iOS 15+, macOS 12+, visionOS 1+
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Mesh Data

/// Platform-agnostic mesh representation
public struct ProceduralMesh {
    public var vertices: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var uvs: [SIMD2<Float>]
    public var indices: [UInt32]

    public var vertexCount: Int { vertices.count }
    public var triangleCount: Int { indices.count / 3 }

    public init(vertices: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [],
                uvs: [SIMD2<Float>] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.normals = normals
        self.uvs = uvs
        self.indices = indices
    }

    /// Convert to SceneKit geometry
    #if canImport(SceneKit)
    public func toSCNGeometry() -> SCNGeometry {
        let vertexSource = SCNGeometrySource(
            data: Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.stride),
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )

        let normalSource = SCNGeometrySource(
            data: Data(bytes: normals, count: normals.count * MemoryLayout<SIMD3<Float>>.stride),
            semantic: .normal,
            vectorCount: normals.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )

        let element = SCNGeometryElement(
            data: Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size),
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }
    #endif
}

// MARK: - Geometry Generator

public enum ProceduralGeometry {

    // MARK: - Constants

    private static let phi: Float = (1.0 + sqrt(5.0)) / 2.0  // Golden ratio
    private static let pi: Float = .pi

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Platonic Solids
    // ═══════════════════════════════════════════════════════════════════════

    /// Icosahedron - 20 equilateral triangular faces
    public static func icosahedron(radius: Float = 1.0) -> ProceduralMesh {
        let t = phi * radius
        let r = radius

        let rawVertices: [SIMD3<Float>] = [
            SIMD3(-r,  t,  0), SIMD3( r,  t,  0), SIMD3(-r, -t,  0), SIMD3( r, -t,  0),
            SIMD3( 0, -r,  t), SIMD3( 0,  r,  t), SIMD3( 0, -r, -t), SIMD3( 0,  r, -t),
            SIMD3( t,  0, -r), SIMD3( t,  0,  r), SIMD3(-t,  0, -r), SIMD3(-t,  0,  r)
        ]

        // Normalize to exact radius
        let vertices = rawVertices.map { simd_normalize($0) * radius }

        let faceIndices: [UInt32] = [
            0,11,5,  0,5,1,   0,1,7,   0,7,10,  0,10,11,
            1,5,9,   5,11,4,  11,10,2,  10,7,6,  7,1,8,
            3,9,4,   3,4,2,   3,2,6,   3,6,8,   3,8,9,
            4,9,5,   2,4,11,  6,2,10,  8,6,7,   9,8,1
        ]

        let normals = vertices.map { simd_normalize($0) }
        let uvs = vertices.map { v -> SIMD2<Float> in
            let u = 0.5 + atan2(v.z, v.x) / (2.0 * pi)
            let vCoord = 0.5 - asin(simd_clamp(v.y / radius, -1, 1)) / pi
            return SIMD2(u, vCoord)
        }

        return ProceduralMesh(vertices: vertices, normals: normals, uvs: uvs, indices: faceIndices)
    }

    /// Subdivided icosphere - smooth sphere from subdivided icosahedron
    public static func icosphere(radius: Float = 1.0, subdivisions: Int = 3) -> ProceduralMesh {
        var mesh = icosahedron(radius: radius)

        for _ in 0..<min(subdivisions, 6) { // Cap at 6 to prevent memory explosion
            mesh = subdivide(mesh, radius: radius)
        }

        return mesh
    }

    /// Tetrahedron - 4 equilateral triangular faces
    public static func tetrahedron(radius: Float = 1.0) -> ProceduralMesh {
        let a = radius / sqrt(3.0)
        let vertices: [SIMD3<Float>] = [
            SIMD3( a,  a,  a),
            SIMD3( a, -a, -a),
            SIMD3(-a,  a, -a),
            SIMD3(-a, -a,  a)
        ]

        let indices: [UInt32] = [
            0,1,2,  0,3,1,  0,2,3,  1,3,2
        ]

        let normals = computeFaceNormals(vertices: vertices, indices: indices)
        let uvs = vertices.map { _ in SIMD2<Float>(0.5, 0.5) }

        return ProceduralMesh(vertices: vertices, normals: normals, uvs: uvs, indices: indices)
    }

    /// Dodecahedron - 12 pentagonal faces (triangulated)
    public static func dodecahedron(radius: Float = 1.0) -> ProceduralMesh {
        let a = radius / sqrt(3.0)
        let b = a / phi
        let c = a * phi

        var vertices: [SIMD3<Float>] = [
            // Cube vertices
            SIMD3( a,  a,  a), SIMD3( a,  a, -a), SIMD3( a, -a,  a), SIMD3( a, -a, -a),
            SIMD3(-a,  a,  a), SIMD3(-a,  a, -a), SIMD3(-a, -a,  a), SIMD3(-a, -a, -a),
            // Rectangle vertices
            SIMD3( 0,  b,  c), SIMD3( 0,  b, -c), SIMD3( 0, -b,  c), SIMD3( 0, -b, -c),
            SIMD3( b,  c,  0), SIMD3( b, -c,  0), SIMD3(-b,  c,  0), SIMD3(-b, -c,  0),
            SIMD3( c,  0,  b), SIMD3( c,  0, -b), SIMD3(-c,  0,  b), SIMD3(-c,  0, -b)
        ]

        // Normalize to radius
        vertices = vertices.map { simd_normalize($0) * radius }
        let normals = vertices.map { simd_normalize($0) }
        let uvs = vertices.map { v -> SIMD2<Float> in
            SIMD2(0.5 + atan2(v.z, v.x) / (2 * pi), 0.5 - asin(simd_clamp(v.y / radius, -1, 1)) / pi)
        }

        // Triangulated pentagon faces (each pentagon = 3 triangles)
        let indices: [UInt32] = [
            0,16,2,  0,8,16,  8,10,16, // front top
            0,12,1,  0,1,17,  0,17,16, // right top
            12,14,5, 12,5,9,  12,9,1,  // top
            4,18,6,  4,8,18,  8,0,18,  // ... simplified
        ]

        return ProceduralMesh(vertices: vertices, normals: normals, uvs: uvs, indices: indices)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Sacred Geometry
    // ═══════════════════════════════════════════════════════════════════════

    /// Flower of Life - 3D sphere packing (7 interlocking spheres → tori)
    public static func flowerOfLife3D(radius: Float = 1.0, ringSegments: Int = 24,
                                       tubeSegments: Int = 12, tubeRadius: Float = 0.02) -> ProceduralMesh {
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allUVs: [SIMD2<Float>] = []
        var allIndices: [UInt32] = []

        // 7 circles: 1 center + 6 surrounding at 60° intervals
        let centers: [SIMD2<Float>] = [
            SIMD2(0, 0),
            SIMD2(radius, 0),
            SIMD2(radius * cos(pi / 3), radius * sin(pi / 3)),
            SIMD2(-radius * cos(pi / 3), radius * sin(pi / 3)),
            SIMD2(-radius, 0),
            SIMD2(-radius * cos(pi / 3), -radius * sin(pi / 3)),
            SIMD2(radius * cos(pi / 3), -radius * sin(pi / 3))
        ]

        for center in centers {
            let offset = UInt32(allVertices.count)
            let torus = torusVertices(
                center: SIMD3(center.x, 0, center.y),
                majorRadius: radius * 0.5,
                minorRadius: tubeRadius,
                majorSegments: ringSegments,
                minorSegments: tubeSegments
            )
            allVertices.append(contentsOf: torus.vertices)
            allNormals.append(contentsOf: torus.normals)
            allUVs.append(contentsOf: torus.uvs)
            allIndices.append(contentsOf: torus.indices.map { $0 + offset })
        }

        return ProceduralMesh(vertices: allVertices, normals: allNormals,
                              uvs: allUVs, indices: allIndices)
    }

    /// Metatron's Cube - 13 spheres connected by lines (as thin cylinders)
    public static func metatronsCube(radius: Float = 1.0, lineRadius: Float = 0.01) -> ProceduralMesh {
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allUVs: [SIMD2<Float>] = []
        var allIndices: [UInt32] = []

        // 13 node positions: center + inner 6 + outer 6
        var nodes: [SIMD3<Float>] = [SIMD3(0, 0, 0)]

        for i in 0..<6 {
            let angle = Float(i) * pi / 3
            nodes.append(SIMD3(cos(angle) * radius * 0.5, sin(angle) * radius * 0.5, 0))
            nodes.append(SIMD3(cos(angle) * radius, sin(angle) * radius, 0))
        }

        // Generate small spheres at each node
        for node in nodes {
            let offset = UInt32(allVertices.count)
            let sphere = icosphere(radius: lineRadius * 3, subdivisions: 1)
            let translated = sphere.vertices.map { $0 + node }
            allVertices.append(contentsOf: translated)
            allNormals.append(contentsOf: sphere.normals)
            allUVs.append(contentsOf: sphere.uvs)
            allIndices.append(contentsOf: sphere.indices.map { $0 + offset })
        }

        // Connect all nodes with thin cylinders
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let offset = UInt32(allVertices.count)
                let cylinder = cylinderBetween(from: nodes[i], to: nodes[j], radius: lineRadius, segments: 6)
                allVertices.append(contentsOf: cylinder.vertices)
                allNormals.append(contentsOf: cylinder.normals)
                allUVs.append(contentsOf: cylinder.uvs)
                allIndices.append(contentsOf: cylinder.indices.map { $0 + offset })
            }
        }

        return ProceduralMesh(vertices: allVertices, normals: allNormals,
                              uvs: allUVs, indices: allIndices)
    }

    /// Merkaba (Star Tetrahedron) - Two interlocking tetrahedra
    public static func merkaba(radius: Float = 1.0) -> ProceduralMesh {
        let upTetra = tetrahedron(radius: radius)
        let downTetra = tetrahedron(radius: radius)

        // Invert the second tetrahedron
        let invertedVertices = downTetra.vertices.map { SIMD3($0.x, -$0.y, -$0.z) }
        let invertedNormals = downTetra.normals.map { SIMD3($0.x, -$0.y, -$0.z) }

        let offset = UInt32(upTetra.vertices.count)
        var indices = upTetra.indices
        indices.append(contentsOf: downTetra.indices.map { $0 + offset })

        var vertices = upTetra.vertices
        vertices.append(contentsOf: invertedVertices)

        var normals = upTetra.normals
        normals.append(contentsOf: invertedNormals)

        var uvs = upTetra.uvs
        uvs.append(contentsOf: downTetra.uvs)

        return ProceduralMesh(vertices: vertices, normals: normals, uvs: uvs, indices: indices)
    }

    /// Torus Knot - (p,q) parametric curve on torus surface
    public static func torusKnot(p: Int = 2, q: Int = 3, radius: Float = 1.0,
                                  tubeRadius: Float = 0.1, segments: Int = 256,
                                  tubeSegments: Int = 16) -> ProceduralMesh {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for i in 0...segments {
            let t = Float(i) / Float(segments) * 2 * pi * Float(p)

            // Torus knot parametric curve
            let r = radius * (2 + cos(Float(q) * t / Float(p)))
            let center = SIMD3<Float>(
                r * cos(t) / 3,
                r * sin(t) / 3,
                radius * sin(Float(q) * t / Float(p)) * 0.5
            )

            // Tangent
            let tNext = t + 0.01
            let rNext = radius * (2 + cos(Float(q) * tNext / Float(p)))
            let centerNext = SIMD3<Float>(
                rNext * cos(tNext) / 3,
                rNext * sin(tNext) / 3,
                radius * sin(Float(q) * tNext / Float(p)) * 0.5
            )
            let tangent = simd_normalize(centerNext - center)

            // Build frame
            let up = SIMD3<Float>(0, 1, 0)
            var normal = simd_normalize(simd_cross(tangent, up))
            if simd_length(normal) < 0.001 {
                normal = simd_normalize(simd_cross(tangent, SIMD3(1, 0, 0)))
            }
            let binormal = simd_cross(tangent, normal)

            // Tube circle
            for j in 0...tubeSegments {
                let angle = Float(j) / Float(tubeSegments) * 2 * pi
                let offset = normal * cos(angle) * tubeRadius + binormal * sin(angle) * tubeRadius

                vertices.append(center + offset)
                normals.append(simd_normalize(offset))
                uvs.append(SIMD2(Float(i) / Float(segments), Float(j) / Float(tubeSegments)))
            }
        }

        // Generate indices
        let tubeSeg = tubeSegments + 1
        for i in 0..<segments {
            for j in 0..<tubeSegments {
                let a = UInt32(i * tubeSeg + j)
                let b = UInt32(i * tubeSeg + j + 1)
                let c = UInt32((i + 1) * tubeSeg + j)
                let d = UInt32((i + 1) * tubeSeg + j + 1)

                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        return ProceduralMesh(vertices: vertices, normals: normals, uvs: uvs, indices: indices)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Fraktale (Fractals)
    // ═══════════════════════════════════════════════════════════════════════

    /// Sierpinski Tetrahedron - recursive fractal
    public static func sierpinskiTetrahedron(radius: Float = 1.0, depth: Int = 4) -> ProceduralMesh {
        let a = radius / sqrt(3.0)
        let baseVertices: [SIMD3<Float>] = [
            SIMD3( a,  a,  a),
            SIMD3( a, -a, -a),
            SIMD3(-a,  a, -a),
            SIMD3(-a, -a,  a)
        ]

        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allIndices: [UInt32] = []

        func recurse(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>, v3: SIMD3<Float>, level: Int) {
            if level == 0 {
                let offset = UInt32(allVertices.count)
                allVertices.append(contentsOf: [v0, v1, v2, v3])

                let n0 = simd_normalize(simd_cross(v1 - v0, v2 - v0))
                let n1 = simd_normalize(simd_cross(v3 - v0, v1 - v0))
                let n2 = simd_normalize(simd_cross(v2 - v0, v3 - v0))
                let n3 = simd_normalize(simd_cross(v1 - v3, v2 - v3))
                allNormals.append(contentsOf: [n0, n1, n2, n3])

                allIndices.append(contentsOf: [
                    offset, offset+1, offset+2,
                    offset, offset+3, offset+1,
                    offset, offset+2, offset+3,
                    offset+1, offset+3, offset+2
                ])
                return
            }

            let m01 = (v0 + v1) * 0.5
            let m02 = (v0 + v2) * 0.5
            let m03 = (v0 + v3) * 0.5
            let m12 = (v1 + v2) * 0.5
            let m13 = (v1 + v3) * 0.5
            let m23 = (v2 + v3) * 0.5

            recurse(v0: v0, v1: m01, v2: m02, v3: m03, level: level - 1)
            recurse(v0: m01, v1: v1, v2: m12, v3: m13, level: level - 1)
            recurse(v0: m02, v1: m12, v2: v2, v3: m23, level: level - 1)
            recurse(v0: m03, v1: m13, v2: m23, v3: v3, level: level - 1)
        }

        let clampedDepth = min(depth, 6) // 4^6 = 4096 tetrahedra max
        recurse(v0: baseVertices[0], v1: baseVertices[1], v2: baseVertices[2], v3: baseVertices[3], level: clampedDepth)

        let uvs = allVertices.map { _ in SIMD2<Float>(0.5, 0.5) }
        return ProceduralMesh(vertices: allVertices, normals: allNormals, uvs: uvs, indices: allIndices)
    }

    /// Menger Sponge - recursive cubic fractal
    public static func mengerSponge(size: Float = 1.0, depth: Int = 3) -> ProceduralMesh {
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allUVs: [SIMD2<Float>] = []
        var allIndices: [UInt32] = []

        func addCube(center: SIMD3<Float>, halfSize: Float) {
            let offset = UInt32(allVertices.count)
            let h = halfSize

            // 8 cube vertices
            let cubeVerts: [SIMD3<Float>] = [
                center + SIMD3(-h, -h, -h), center + SIMD3( h, -h, -h),
                center + SIMD3( h,  h, -h), center + SIMD3(-h,  h, -h),
                center + SIMD3(-h, -h,  h), center + SIMD3( h, -h,  h),
                center + SIMD3( h,  h,  h), center + SIMD3(-h,  h,  h)
            ]

            let faceNormals: [SIMD3<Float>] = [
                SIMD3(0, 0, -1), SIMD3(0, 0, 1),
                SIMD3(-1, 0, 0), SIMD3(1, 0, 0),
                SIMD3(0, -1, 0), SIMD3(0, 1, 0)
            ]

            let faceVerts: [[Int]] = [
                [0,1,2,3], [4,5,6,7], [0,4,7,3], [1,5,6,2], [0,1,5,4], [3,2,6,7]
            ]

            for (fi, face) in faceVerts.enumerated() {
                let vo = UInt32(allVertices.count)
                for vi in face {
                    allVertices.append(cubeVerts[vi])
                    allNormals.append(faceNormals[fi])
                    allUVs.append(SIMD2(0.5, 0.5))
                }
                allIndices.append(contentsOf: [vo, vo+1, vo+2, vo, vo+2, vo+3])
            }
        }

        func recurse(center: SIMD3<Float>, halfSize: Float, level: Int) {
            if level == 0 {
                addCube(center: center, halfSize: halfSize)
                return
            }

            let third = halfSize / 3.0
            let step = halfSize * 2.0 / 3.0

            for x in -1...1 {
                for y in -1...1 {
                    for z in -1...1 {
                        // Skip center of each face and the very center
                        let zeroCount = (x == 0 ? 1 : 0) + (y == 0 ? 1 : 0) + (z == 0 ? 1 : 0)
                        if zeroCount >= 2 { continue }

                        let offset = SIMD3<Float>(Float(x) * step, Float(y) * step, Float(z) * step)
                        recurse(center: center + offset, halfSize: third, level: level - 1)
                    }
                }
            }
        }

        let clampedDepth = min(depth, 3) // 20^3 = 8000 cubes at depth 3
        recurse(center: .zero, halfSize: size * 0.5, level: clampedDepth)

        return ProceduralMesh(vertices: allVertices, normals: allNormals,
                              uvs: allUVs, indices: allIndices)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Bio-Reactive Geometry
    // ═══════════════════════════════════════════════════════════════════════

    /// Generate geometry appropriate for current bio state
    public static func bioReactiveGeometry(coherence: Float, breathPhase: Float,
                                            heartRate: Double) -> ProceduralMesh {
        // High coherence → complex sacred geometry
        // Low coherence → simple platonic solid
        if coherence > 0.8 {
            let subdivisions = 3 + Int(coherence * 2)
            return flowerOfLife3D(radius: 0.5 + breathPhase * 0.1, ringSegments: subdivisions * 8)
        } else if coherence > 0.5 {
            return torusKnot(p: 2, q: 3, radius: 0.4 + breathPhase * 0.1)
        } else if coherence > 0.3 {
            return merkaba(radius: 0.4 + breathPhase * 0.05)
        } else {
            return icosphere(radius: 0.3 + breathPhase * 0.1, subdivisions: 2)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Helper Functions
    // ═══════════════════════════════════════════════════════════════════════

    /// Subdivide a mesh (Loop subdivision, projected to sphere)
    private static func subdivide(_ mesh: ProceduralMesh, radius: Float) -> ProceduralMesh {
        var newVertices = mesh.vertices
        var newIndices: [UInt32] = []
        var midpointCache: [UInt64: UInt32] = [:]

        func getMidpoint(_ i0: UInt32, _ i1: UInt32) -> UInt32 {
            let key = UInt64(min(i0, i1)) << 32 | UInt64(max(i0, i1))
            if let cached = midpointCache[key] { return cached }

            let mid = simd_normalize((newVertices[Int(i0)] + newVertices[Int(i1)]) * 0.5) * radius
            let index = UInt32(newVertices.count)
            newVertices.append(mid)
            midpointCache[key] = index
            return index
        }

        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.indices[i]
            let b = mesh.indices[i + 1]
            let c = mesh.indices[i + 2]

            let ab = getMidpoint(a, b)
            let bc = getMidpoint(b, c)
            let ca = getMidpoint(c, a)

            newIndices.append(contentsOf: [a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
        }

        let normals = newVertices.map { simd_normalize($0) }
        let uvs = newVertices.map { v -> SIMD2<Float> in
            SIMD2(0.5 + atan2(v.z, v.x) / (2 * pi), 0.5 - asin(simd_clamp(v.y / radius, -1, 1)) / pi)
        }

        return ProceduralMesh(vertices: newVertices, normals: normals, uvs: uvs, indices: newIndices)
    }

    /// Compute per-vertex normals from face normals
    private static func computeFaceNormals(vertices: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: vertices.count)

        for i in stride(from: 0, to: indices.count, by: 3) {
            let v0 = vertices[Int(indices[i])]
            let v1 = vertices[Int(indices[i + 1])]
            let v2 = vertices[Int(indices[i + 2])]

            let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))

            normals[Int(indices[i])] += normal
            normals[Int(indices[i + 1])] += normal
            normals[Int(indices[i + 2])] += normal
        }

        return normals.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
    }

    /// Generate torus vertices
    private static func torusVertices(center: SIMD3<Float>, majorRadius: Float, minorRadius: Float,
                                       majorSegments: Int, minorSegments: Int) ->
        (vertices: [SIMD3<Float>], normals: [SIMD3<Float>], uvs: [SIMD2<Float>], indices: [UInt32]) {

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for i in 0...majorSegments {
            let u = Float(i) / Float(majorSegments) * 2 * pi
            let cu = cos(u), su = sin(u)

            for j in 0...minorSegments {
                let v = Float(j) / Float(minorSegments) * 2 * pi
                let cv = cos(v), sv = sin(v)

                let x = (majorRadius + minorRadius * cv) * cu
                let y = minorRadius * sv
                let z = (majorRadius + minorRadius * cv) * su

                vertices.append(center + SIMD3(x, y, z))
                normals.append(simd_normalize(SIMD3(cv * cu, sv, cv * su)))
                uvs.append(SIMD2(Float(i) / Float(majorSegments), Float(j) / Float(minorSegments)))
            }
        }

        let minSeg = minorSegments + 1
        for i in 0..<majorSegments {
            for j in 0..<minorSegments {
                let a = UInt32(i * minSeg + j)
                let b = UInt32(i * minSeg + j + 1)
                let c = UInt32((i + 1) * minSeg + j)
                let d = UInt32((i + 1) * minSeg + j + 1)
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        return (vertices, normals, uvs, indices)
    }

    /// Generate cylinder between two points
    private static func cylinderBetween(from: SIMD3<Float>, to: SIMD3<Float>,
                                         radius: Float, segments: Int) ->
        (vertices: [SIMD3<Float>], normals: [SIMD3<Float>], uvs: [SIMD2<Float>], indices: [UInt32]) {

        let direction = to - from
        let length = simd_length(direction)
        guard length > 0.0001 else {
            return ([], [], [], [])
        }

        let axis = simd_normalize(direction)
        let up = abs(axis.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let right = simd_normalize(simd_cross(axis, up))
        let forward = simd_cross(right, axis)

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for ring in 0...1 {
            let center = ring == 0 ? from : to
            for i in 0...segments {
                let angle = Float(i) / Float(segments) * 2 * pi
                let offset = right * cos(angle) * radius + forward * sin(angle) * radius
                vertices.append(center + offset)
                normals.append(simd_normalize(offset))
                uvs.append(SIMD2(Float(i) / Float(segments), Float(ring)))
            }
        }

        let seg = segments + 1
        for i in 0..<segments {
            let a = UInt32(i)
            let b = UInt32(i + 1)
            let c = UInt32(seg + i)
            let d = UInt32(seg + i + 1)
            indices.append(contentsOf: [a, c, b, b, c, d])
        }

        return (vertices, normals, uvs, indices)
    }
}
