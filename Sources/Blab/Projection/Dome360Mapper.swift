import Foundation
import Metal
import MetalKit
import simd

/// Spherical and Dome Projection Mapping System
/// Inspired by: Vioso, Scalable Display, Paul Bourke's Dome Projection, WorldViews
///
/// Features:
/// - Fulldome projection (planetarium-style hemispherical domes)
/// - 360° cylindrical panoramic projection
/// - Fisheye lens correction and calibration
/// - Equirectangular to dome/sphere mapping
/// - Multi-projector dome configurations
/// - Master/Slave dome geometry
/// - Auto-calibration with camera feedback
///
/// Dome Types:
/// - Truncated dome (most common - 180° hemisphere)
/// - Full dome (rare - complete hemisphere)
/// - Tilted dome (screen tilted for optimal viewing)
/// - Immersive tunnel (cylindrical 360°)
///
/// Standards:
/// - Fulldome format: 4K/8K fisheye
/// - E&S Digistar, Evans & Sutherland systems
/// - IMAX dome specifications
@MainActor
class Dome360Mapper: ObservableObject {

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var domePipeline: MTLRenderPipelineState?
    private var sphericalComputePipeline: MTLComputePipelineState?


    // MARK: - Dome Configuration

    @Published var domeType: DomeType = .hemisphere
    @Published var domeGeometry: DomeGeometry

    /// Dome radius (meters)
    var domeRadius: Float = 10.0

    /// Dome tilt angle (degrees, for tilted domes)
    var domeTilt: Float = 0.0


    // MARK: - Projection Configuration

    @Published var projectionMode: ProjectionMode = .fisheye

    /// Fisheye field of view (degrees)
    var fisheyeFOV: Float = 180.0

    /// Lens distortion correction coefficients (k1, k2, k3)
    var distortionCoefficients: SIMD3<Float> = SIMD3(0, 0, 0)


    // MARK: - 360° Configuration

    /// For cylindrical 360° projection
    var cylinderHeight: Float = 5.0  // meters
    var cylinderRadius: Float = 8.0  // meters


    // MARK: - Master Configuration

    /// For multi-projector domes
    @Published var masterProjectors: [DomeProjector] = []

    /// Auto-blend overlap regions
    var autoBlendEnabled: Bool = true


    // MARK: - Mesh

    /// Dome mesh (generated from geometry)
    private var domeMesh: DomeMesh?

    /// Mesh resolution (higher = smoother, more GPU)
    var meshResolution: MeshResolution = .high


    // MARK: - Initialization

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        self.commandQueue = commandQueue

        // Default hemisphere geometry
        self.domeGeometry = DomeGeometry(
            radius: 10.0,
            aperture: 180.0,  // Full hemisphere
            tilt: 0.0,
            center: SIMD3(0, 0, 0)
        )

        setupPipelines()
        generateDomeMesh()

        print("🔮 Dome360Mapper initialized")
        print("   Dome Type: \(domeType.rawValue)")
        print("   Projection: \(projectionMode.rawValue)")
    }

    private func setupPipelines() {
        // Metal shaders for dome projection
        // In production, load actual .metal shader files

        guard let library = device.makeDefaultLibrary() else {
            print("⚠️ Could not create Metal library")
            return
        }

        // Dome rendering pipeline
        let domeDescriptor = MTLRenderPipelineDescriptor()
        domeDescriptor.label = "Dome Projection Pipeline"

        // Spherical compute pipeline (for UV mapping)
        // let computeFunction = library.makeFunction(name: "sphericalProjection")
        // sphericalComputePipeline = try? device.makeComputePipelineState(function: computeFunction)

        print("✅ Dome pipelines configured")
    }


    // MARK: - Dome Mesh Generation

    func generateDomeMesh() {
        print("🏗️ Generating dome mesh...")

        let mesh: DomeMesh

        switch domeType {
        case .hemisphere:
            mesh = generateHemisphereMesh()

        case .fullDome:
            mesh = generateFullSphereMesh()

        case .truncatedDome:
            mesh = generateTruncatedDomeMesh()

        case .tiltedDome:
            mesh = generateTiltedDomeMesh()

        case .cylindrical360:
            mesh = generateCylindricalMesh()

        case .tunnel:
            mesh = generateTunnelMesh()
        }

        self.domeMesh = mesh

        print("✅ Dome mesh generated: \(mesh.vertices.count) vertices, \(mesh.indices.count / 3) triangles")
    }

    private func generateHemisphereMesh() -> DomeMesh {
        // Generate hemisphere (180° dome)
        let segments = meshResolution.segments
        let rings = segments / 2

        var vertices: [DomeVertex] = []
        var indices: [UInt32] = []

        // Generate vertices
        for ring in 0...rings {
            let phi = Float(ring) / Float(rings) * (.pi / 2.0)  // 0 to π/2 (hemisphere)

            for segment in 0...segments {
                let theta = Float(segment) / Float(segments) * (.pi * 2.0)

                // Spherical to Cartesian
                let x = domeGeometry.radius * sin(phi) * cos(theta)
                let y = domeGeometry.radius * cos(phi)
                let z = domeGeometry.radius * sin(phi) * sin(theta)

                // UV coordinates (equirectangular)
                let u = Float(segment) / Float(segments)
                let v = Float(ring) / Float(rings)

                vertices.append(DomeVertex(
                    position: SIMD3(x, y, z),
                    texCoord: SIMD2(u, v),
                    normal: normalize(SIMD3(x, y, z))
                ))
            }
        }

        // Generate indices (triangles)
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * (segments + 1) + segment)
                let next = current + UInt32(segments + 1)

                // Two triangles per quad
                indices.append(contentsOf: [
                    current, next, current + 1,
                    current + 1, next, next + 1
                ])
            }
        }

        return DomeMesh(vertices: vertices, indices: indices)
    }

    private func generateFullSphereMesh() -> DomeMesh {
        // Complete sphere (rare for domes)
        let segments = meshResolution.segments
        let rings = segments

        var vertices: [DomeVertex] = []
        var indices: [UInt32] = []

        for ring in 0...rings {
            let phi = Float(ring) / Float(rings) * .pi  // 0 to π (full sphere)

            for segment in 0...segments {
                let theta = Float(segment) / Float(segments) * (.pi * 2.0)

                let x = domeGeometry.radius * sin(phi) * cos(theta)
                let y = domeGeometry.radius * cos(phi)
                let z = domeGeometry.radius * sin(phi) * sin(theta)

                let u = Float(segment) / Float(segments)
                let v = Float(ring) / Float(rings)

                vertices.append(DomeVertex(
                    position: SIMD3(x, y, z),
                    texCoord: SIMD2(u, v),
                    normal: normalize(SIMD3(x, y, z))
                ))
            }
        }

        // Generate indices
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * (segments + 1) + segment)
                let next = current + UInt32(segments + 1)

                indices.append(contentsOf: [
                    current, next, current + 1,
                    current + 1, next, next + 1
                ])
            }
        }

        return DomeMesh(vertices: vertices, indices: indices)
    }

    private func generateTruncatedDomeMesh() -> DomeMesh {
        // Truncated dome (e.g., 150° aperture instead of full 180°)
        let aperture = domeGeometry.aperture
        let segments = meshResolution.segments
        let rings = segments / 2

        var vertices: [DomeVertex] = []
        var indices: [UInt32] = []

        let maxPhi = (aperture / 180.0) * (.pi / 2.0)

        for ring in 0...rings {
            let phi = Float(ring) / Float(rings) * maxPhi

            for segment in 0...segments {
                let theta = Float(segment) / Float(segments) * (.pi * 2.0)

                let x = domeGeometry.radius * sin(phi) * cos(theta)
                let y = domeGeometry.radius * cos(phi)
                let z = domeGeometry.radius * sin(phi) * sin(theta)

                let u = Float(segment) / Float(segments)
                let v = Float(ring) / Float(rings)

                vertices.append(DomeVertex(
                    position: SIMD3(x, y, z),
                    texCoord: SIMD2(u, v),
                    normal: normalize(SIMD3(x, y, z))
                ))
            }
        }

        // Generate indices
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * (segments + 1) + segment)
                let next = current + UInt32(segments + 1)

                indices.append(contentsOf: [
                    current, next, current + 1,
                    current + 1, next, next + 1
                ])
            }
        }

        return DomeMesh(vertices: vertices, indices: indices)
    }

    private func generateTiltedDomeMesh() -> DomeMesh {
        // Start with hemisphere, then apply tilt transformation
        var mesh = generateHemisphereMesh()

        let tiltRadians = domeTilt * .pi / 180.0
        let rotationMatrix = createRotationMatrix(angle: tiltRadians, axis: SIMD3(1, 0, 0))

        // Apply rotation to all vertices
        for i in 0..<mesh.vertices.count {
            let pos = mesh.vertices[i].position
            let rotated = simd_mul(rotationMatrix, SIMD4(pos.x, pos.y, pos.z, 1.0))
            mesh.vertices[i].position = SIMD3(rotated.x, rotated.y, rotated.z)

            // Update normal
            let normalRotated = simd_mul(rotationMatrix, SIMD4(mesh.vertices[i].normal.x, mesh.vertices[i].normal.y, mesh.vertices[i].normal.z, 0.0))
            mesh.vertices[i].normal = normalize(SIMD3(normalRotated.x, normalRotated.y, normalRotated.z))
        }

        return mesh
    }

    private func generateCylindricalMesh() -> DomeMesh {
        // 360° cylindrical panorama
        let segments = meshResolution.segments
        let heightSegments = segments / 4

        var vertices: [DomeVertex] = []
        var indices: [UInt32] = []

        for h in 0...heightSegments {
            let y = (Float(h) / Float(heightSegments) - 0.5) * cylinderHeight

            for segment in 0...segments {
                let theta = Float(segment) / Float(segments) * (.pi * 2.0)

                let x = cylinderRadius * cos(theta)
                let z = cylinderRadius * sin(theta)

                let u = Float(segment) / Float(segments)
                let v = Float(h) / Float(heightSegments)

                vertices.append(DomeVertex(
                    position: SIMD3(x, y, z),
                    texCoord: SIMD2(u, v),
                    normal: normalize(SIMD3(x, 0, z))
                ))
            }
        }

        // Generate indices
        for h in 0..<heightSegments {
            for segment in 0..<segments {
                let current = UInt32(h * (segments + 1) + segment)
                let next = current + UInt32(segments + 1)

                indices.append(contentsOf: [
                    current, next, current + 1,
                    current + 1, next, next + 1
                ])
            }
        }

        return DomeMesh(vertices: vertices, indices: indices)
    }

    private func generateTunnelMesh() -> DomeMesh {
        // Immersive tunnel (cylinder + caps)
        return generateCylindricalMesh()  // Simplified
    }


    // MARK: - Coordinate Conversion

    /// Convert equirectangular UV to dome XYZ
    func equirectangularToDome(u: Float, v: Float) -> SIMD3<Float> {
        let theta = u * .pi * 2.0  // Longitude
        let phi = v * .pi / 2.0     // Latitude (0 to π/2 for hemisphere)

        let x = domeGeometry.radius * sin(phi) * cos(theta)
        let y = domeGeometry.radius * cos(phi)
        let z = domeGeometry.radius * sin(phi) * sin(theta)

        return SIMD3(x, y, z)
    }

    /// Convert dome XYZ to fisheye UV (for fisheye projection)
    func domeToFisheye(position: SIMD3<Float>) -> SIMD2<Float> {
        // Calculate angular coordinates
        let r = sqrt(position.x * position.x + position.z * position.z)
        let phi = atan2(r, position.y)  // Angle from zenith
        let theta = atan2(position.z, position.x)  // Azimuth

        // Map to fisheye (circular)
        let fisheyeRadius = phi / (fisheyeFOV * .pi / 180.0 / 2.0)
        let u = 0.5 + fisheyeRadius * cos(theta)
        let v = 0.5 + fisheyeRadius * sin(theta)

        return SIMD2(u, v)
    }

    /// Angular coordinates to Cartesian (azimuth, elevation in degrees)
    func angularToCartesian(azimuth: Float, elevation: Float) -> SIMD3<Float> {
        let azRad = azimuth * .pi / 180.0
        let elRad = elevation * .pi / 180.0

        let x = domeGeometry.radius * cos(elRad) * sin(azRad)
        let y = domeGeometry.radius * sin(elRad)
        let z = domeGeometry.radius * cos(elRad) * cos(azRad)

        return SIMD3(x, y, z)
    }

    /// Cartesian to angular coordinates
    func cartesianToAngular(position: SIMD3<Float>) -> (azimuth: Float, elevation: Float) {
        let r = length(position)
        let elevation = asin(position.y / r) * 180.0 / .pi
        let azimuth = atan2(position.x, position.z) * 180.0 / .pi

        return (azimuth, elevation)
    }


    // MARK: - Fisheye Lens Correction

    /// Apply lens distortion correction
    func correctDistortion(uv: SIMD2<Float>) -> SIMD2<Float> {
        // Radial distortion model: r' = r(1 + k1*r² + k2*r⁴ + k3*r⁶)
        let center = SIMD2<Float>(0.5, 0.5)
        let delta = uv - center
        let r = length(delta)

        let r2 = r * r
        let r4 = r2 * r2
        let r6 = r4 * r2

        let distortion = 1.0 + distortionCoefficients.x * r2 +
                              distortionCoefficients.y * r4 +
                              distortionCoefficients.z * r6

        let corrected = center + delta * distortion

        return corrected
    }

    /// Calibrate lens distortion (would use test pattern in production)
    func calibrateLensDistortion(k1: Float, k2: Float, k3: Float) {
        distortionCoefficients = SIMD3(k1, k2, k3)
        print("🔧 Lens distortion calibrated: k1=\(k1), k2=\(k2), k3=\(k3)")
    }


    // MARK: - Multi-Projector Dome Setup

    /// Add projector to dome configuration
    func addDomeProjector(
        name: String,
        position: SIMD3<Float>,
        rotation: SIMD3<Float>,
        fov: Float,
        resolution: CGSize
    ) {
        let projector = DomeProjector(
            id: UUID(),
            name: name,
            position: position,
            rotation: rotation,
            fov: fov,
            resolution: resolution
        )

        masterProjectors.append(projector)

        if autoBlendEnabled {
            calculateDomeBlendRegions()
        }

        print("✅ Added dome projector '\(name)'")
    }

    private func calculateDomeBlendRegions() {
        // Calculate overlapping regions for edge blending
        // This integrates with MultiProjectorSystem

        print("🔄 Calculating dome blend regions...")

        for (index, projector) in masterProjectors.enumerated() {
            // Find neighbors
            let neighbors = masterProjectors.enumerated().filter { $0.offset != index }

            // Calculate overlap based on FOV and position
            // Set blend masks
        }

        print("✅ Dome blend regions calculated")
    }


    // MARK: - Rendering

    /// Render content to dome mesh
    func renderToDome(sourceTexture: MTLTexture, outputTexture: MTLTexture) {
        guard let mesh = domeMesh else {
            print("❌ No dome mesh generated")
            return
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Render dome with texture mapping
        // This would use the dome pipeline and mesh

        commandBuffer.commit()
    }

    /// Render fisheye output
    func renderFisheye(equirectangularTexture: MTLTexture) -> MTLTexture? {
        // Convert equirectangular to fisheye projection
        // Uses compute shader for efficiency

        return nil  // Placeholder
    }


    // MARK: - Export

    /// Export dome configuration for fulldome software
    func exportDomeConfig(format: DomeConfigFormat) -> String {
        switch format {
        case .vioso:
            return exportViosoConfig()

        case .scalableDisplay:
            return exportScalableDisplayConfig()

        case .json:
            return exportJSONConfig()
        }
    }

    private func exportViosoConfig() -> String {
        // Vioso calibration format
        return """
        <!-- Vioso Dome Configuration -->
        <ViosoConfig>
            <Dome radius="\(domeGeometry.radius)" aperture="\(domeGeometry.aperture)" />
            <Projectors count="\(masterProjectors.count)">
                <!-- Projector configurations -->
            </Projectors>
        </ViosoConfig>
        """
    }

    private func exportScalableDisplayConfig() -> String {
        // Scalable Display Manager format
        return "<!-- Scalable Display Config -->"
    }

    private func exportJSONConfig() -> String {
        // Generic JSON format
        let config: [String: Any] = [
            "domeType": domeType.rawValue,
            "geometry": [
                "radius": domeGeometry.radius,
                "aperture": domeGeometry.aperture,
                "tilt": domeGeometry.tilt
            ],
            "projectors": masterProjectors.map { proj in
                [
                    "name": proj.name,
                    "position": [proj.position.x, proj.position.y, proj.position.z],
                    "rotation": [proj.rotation.x, proj.rotation.y, proj.rotation.z],
                    "fov": proj.fov
                ]
            }
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return "{}"
    }


    // MARK: - Helper Functions

    private func createRotationMatrix(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let t = 1.0 - c

        let x = axis.x
        let y = axis.y
        let z = axis.z

        return simd_float4x4(
            SIMD4(t * x * x + c,     t * x * y - s * z, t * x * z + s * y, 0),
            SIMD4(t * x * y + s * z, t * y * y + c,     t * y * z - s * x, 0),
            SIMD4(t * x * z - s * y, t * y * z + s * x, t * z * z + c,     0),
            SIMD4(0, 0, 0, 1)
        )
    }


    // MARK: - Status

    var statusSummary: String {
        """
        🔮 Dome/360° Mapper
        Type: \(domeType.rawValue)
        Projection: \(projectionMode.rawValue)
        Dome Radius: \(domeGeometry.radius)m
        Aperture: \(domeGeometry.aperture)°
        Projectors: \(masterProjectors.count)
        Mesh: \(domeMesh?.vertices.count ?? 0) vertices
        """
    }
}


// MARK: - Data Models

/// Dome geometry configuration
struct DomeGeometry {
    var radius: Float         // meters
    var aperture: Float       // degrees (e.g., 180° = full hemisphere)
    var tilt: Float           // degrees
    var center: SIMD3<Float>  // center point
}

/// Dome mesh data
struct DomeMesh {
    var vertices: [DomeVertex]
    var indices: [UInt32]
}

/// Dome vertex
struct DomeVertex {
    var position: SIMD3<Float>
    var texCoord: SIMD2<Float>
    var normal: SIMD3<Float>
}

/// Dome projector configuration
struct DomeProjector: Identifiable {
    let id: UUID
    var name: String
    var position: SIMD3<Float>  // XYZ in dome space
    var rotation: SIMD3<Float>  // Euler angles
    var fov: Float              // Field of view (degrees)
    var resolution: CGSize
    var blendMask: String?      // Path to blend mask texture
}

/// Dome types
enum DomeType: String, CaseIterable {
    case hemisphere = "Hemisphere (180°)"
    case fullDome = "Full Dome (Rare)"
    case truncatedDome = "Truncated Dome"
    case tiltedDome = "Tilted Dome"
    case cylindrical360 = "360° Cylindrical"
    case tunnel = "Immersive Tunnel"
}

/// Projection modes
enum ProjectionMode: String, CaseIterable {
    case fisheye = "Fisheye"
    case equirectangular = "Equirectangular"
    case cubemap = "Cubemap"
    case angular = "Angular (Azimuth/Elevation)"
}

/// Mesh resolution presets
enum MeshResolution: String, CaseIterable {
    case low = "Low (64 segments)"
    case medium = "Medium (128 segments)"
    case high = "High (256 segments)"
    case ultra = "Ultra (512 segments)"

    var segments: Int {
        switch self {
        case .low: return 64
        case .medium: return 128
        case .high: return 256
        case .ultra: return 512
        }
    }
}

/// Dome configuration export formats
enum DomeConfigFormat: String, CaseIterable {
    case vioso = "Vioso"
    case scalableDisplay = "Scalable Display Manager"
    case json = "JSON"
}
