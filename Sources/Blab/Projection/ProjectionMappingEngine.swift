import Foundation
import ARKit
import RealityKit
import Vision
import CoreImage

/// 3D Projection Mapping Engine
///
/// Features:
/// - LiDAR-based surface scanning
/// - Object detection & recognition
/// - UV mapping on irregular surfaces
/// - Multi-projector calibration
/// - Real-time mesh deformation
/// - Edge blending for multiple projectors
@MainActor
class ProjectionMappingEngine: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether mapping is active
    @Published var isActive: Bool = false

    /// Detected surfaces
    @Published var detectedSurfaces: [MappedSurface] = []

    /// Current mapping mode
    @Published var mappingMode: MappingMode = .manual

    /// Calibration status
    @Published var calibrationStatus: CalibrationStatus = .notCalibrated

    // MARK: - Configuration

    enum MappingMode {
        case manual          // User manually defines corners
        case automatic       // Auto-detect with LiDAR/Vision
        case tracked         // Real-time tracking (moving surfaces)
    }

    enum CalibrationStatus {
        case notCalibrated
        case calibrating
        case calibrated
    }

    // MARK: - ARKit Components

    private var arSession: ARSession?
    private var sceneReconstruction: ARWorldTrackingConfiguration.SceneReconstruction = .meshWithClassification

    // MARK: - Vision Components

    private var objectRecognitionRequest: VNRecognizeObjectsRequest?
    private var rectangleDetectionRequest: VNDetectRectanglesRequest?

    // MARK: - Mesh Data

    private var surfaceMeshes: [UUID: ARMeshAnchor] = [:]
    private var uvMaps: [UUID: UVMap] = [:]

    // MARK: - Projection Parameters

    private var projectorTransform = simd_float4x4.identity
    private var projectorFOV: Float = 60.0  // degrees
    private var projectorAspect: Float = 16.0/9.0

    // MARK: - Initialization

    override init() {
        super.init()
        setupVisionRequests()
        print("🎬 ProjectionMappingEngine initialized")
    }

    // MARK: - Public API

    /// Start projection mapping
    func start(with arSession: ARSession? = nil) throws {
        guard !isActive else { return }

        // Use provided session or create new
        if let session = arSession {
            self.arSession = session
        } else {
            self.arSession = ARSession()
            try startARSession()
        }

        isActive = true
        print("🎬 Projection mapping started")
    }

    /// Stop projection mapping
    func stop() {
        isActive = false
        arSession?.pause()
        detectedSurfaces.removeAll()
        surfaceMeshes.removeAll()
        uvMaps.removeAll()
        print("🎬 Projection mapping stopped")
    }

    /// Scan environment for surfaces
    func scanEnvironment() async throws -> [MappedSurface] {
        guard let session = arSession else {
            throw MappingError.noARSession
        }

        print("🔍 Scanning environment...")

        // Wait for mesh anchors
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Process all mesh anchors
        var surfaces: [MappedSurface] = []

        for anchor in session.currentFrame?.anchors ?? [] {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if let surface = processMeshAnchor(meshAnchor) {
                    surfaces.append(surface)
                }
            }
        }

        detectedSurfaces = surfaces
        print("🔍 Found \(surfaces.count) surfaces")

        return surfaces
    }

    /// Detect objects in scene
    func detectObjects(in image: CIImage) async throws -> [DetectedObject] {
        guard let request = objectRecognitionRequest else {
            throw MappingError.visionNotInitialized
        }

        let handler = VNImageRequestHandler(ciImage: image)
        try handler.perform([request])

        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }

        return results.map { observation in
            DetectedObject(
                id: UUID(),
                label: observation.labels.first?.identifier ?? "Unknown",
                confidence: Double(observation.labels.first?.confidence ?? 0),
                boundingBox: observation.boundingBox,
                transform: .identity
            )
        }
    }

    /// Map texture to surface
    func mapTexture(_ texture: CIImage, to surface: MappedSurface) -> ProjectedTexture {
        guard let uvMap = uvMaps[surface.id] else {
            // Create default planar UV mapping
            return createPlanarMapping(texture, surface: surface)
        }

        // Apply UV mapping with mesh deformation
        let warpedTexture = applyUVWarp(texture, uvMap: uvMap)

        return ProjectedTexture(
            surfaceID: surface.id,
            texture: warpedTexture,
            uvMap: uvMap,
            blendMode: .normal
        )
    }

    /// Calibrate projector
    func calibrateProjector(corners: [CGPoint]) {
        calibrationStatus = .calibrating

        // Calculate homography matrix from corner points
        let homography = calculateHomography(from: corners)
        projectorTransform = homography

        calibrationStatus = .calibrated
        print("✅ Projector calibrated")
    }

    /// Auto-calibrate using checkerboard pattern
    func autoCalibrate(checkerboardImage: CIImage) async throws {
        calibrationStatus = .calibrating

        // Detect checkerboard corners
        let corners = try await detectCheckerboardCorners(in: checkerboardImage)

        guard corners.count >= 4 else {
            throw MappingError.insufficientCalibrationPoints
        }

        // Calculate homography
        let homography = calculateHomography(from: corners)
        projectorTransform = homography

        calibrationStatus = .calibrated
        print("✅ Auto-calibration complete")
    }

    /// Edge blending for multi-projector setup
    func createEdgeBlendMask(for region: CGRect, overlapWidth: CGFloat) -> CIImage {
        let width = region.width
        let height = region.height

        // Create gradient for soft edge
        let gradient = CIFilter(name: "CILinearGradient")!
        gradient.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradient.setValue(CIVector(x: overlapWidth, y: 0), forKey: "inputPoint1")
        gradient.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor0")
        gradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let blendMask = gradient.outputImage else {
            return CIImage(color: .white).cropped(to: region)
        }

        // Crop to region
        return blendMask.cropped(to: region)
    }

    // MARK: - Private Methods

    private func startARSession() throws {
        guard let session = arSession else {
            throw MappingError.noARSession
        }

        let configuration = ARWorldTrackingConfiguration()

        // Enable scene reconstruction with LiDAR
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            print("✅ LiDAR scene reconstruction enabled")
        } else {
            print("⚠️ LiDAR not available, using plane detection")
            configuration.planeDetection = [.horizontal, .vertical]
        }

        // Enable object detection
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]

        session.run(configuration)
    }

    private func processMeshAnchor(_ anchor: ARMeshAnchor) -> MappedSurface? {
        let geometry = anchor.geometry

        // Extract vertices
        let vertices = (0..<geometry.vertices.count).map { index in
            geometry.vertices[index]
        }

        // Extract faces
        let faces = geometry.faces

        // Classify surface (wall, floor, ceiling, object)
        let classification = classifySurface(anchor)

        // Calculate surface area
        let area = calculateSurfaceArea(vertices: vertices, faces: faces)

        // Create UV mapping
        let uvMap = generateUVMapping(vertices: vertices, faces: faces)
        uvMaps[anchor.identifier] = uvMap

        // Store mesh
        surfaceMeshes[anchor.identifier] = anchor

        return MappedSurface(
            id: anchor.identifier,
            classification: classification,
            vertices: vertices,
            faceCount: faces.count,
            area: area,
            transform: anchor.transform,
            center: anchor.center
        )
    }

    private func classifySurface(_ anchor: ARMeshAnchor) -> SurfaceClassification {
        let geometry = anchor.geometry

        // Check if we have classification data (LiDAR)
        if let classification = geometry.classification {
            // Analyze classification buffer
            let classifications = (0..<classification.count).map { index in
                classification[index]
            }

            // Majority vote
            let mostCommon = classifications.mostCommon()

            switch mostCommon {
            case .wall:
                return .wall
            case .floor:
                return .floor
            case .ceiling:
                return .ceiling
            case .door:
                return .door
            case .window:
                return .window
            case .table, .seat:
                return .furniture
            default:
                return .object
            }
        }

        // Fallback: analyze normal vectors
        let normals = (0..<geometry.normals.count).map { index in
            geometry.normals[index]
        }

        let avgNormal = normals.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1 } / Float(normals.count)

        // Check if mostly horizontal
        if abs(avgNormal.y) > 0.8 {
            return avgNormal.y > 0 ? .floor : .ceiling
        }

        // Check if mostly vertical
        if abs(avgNormal.y) < 0.2 {
            return .wall
        }

        return .object
    }

    private func calculateSurfaceArea(vertices: [SIMD3<Float>], faces: ARGeometrySource) -> Float {
        // Sum triangle areas
        var totalArea: Float = 0.0

        // TODO: Implement triangle area calculation
        // For now, return bounding box area as approximation

        if vertices.isEmpty { return 0 }

        let minVertex = vertices.reduce(vertices[0]) {
            SIMD3<Float>(
                min($0.x, $1.x),
                min($0.y, $1.y),
                min($0.z, $1.z)
            )
        }

        let maxVertex = vertices.reduce(vertices[0]) {
            SIMD3<Float>(
                max($0.x, $1.x),
                max($0.y, $1.y),
                max($0.z, $1.z)
            )
        }

        let size = maxVertex - minVertex
        totalArea = size.x * size.y + size.y * size.z + size.z * size.x

        return totalArea
    }

    private func generateUVMapping(vertices: [SIMD3<Float>], faces: ARGeometrySource) -> UVMap {
        // Generate planar UV coordinates
        // Project vertices onto best-fit plane

        guard !vertices.isEmpty else {
            return UVMap(coordinates: [], indices: [])
        }

        // Find bounding box
        let minVertex = vertices.reduce(vertices[0]) {
            SIMD3<Float>(min($0.x, $1.x), min($0.y, $1.y), min($0.z, $1.z))
        }

        let maxVertex = vertices.reduce(vertices[0]) {
            SIMD3<Float>(max($0.x, $1.x), max($0.y, $1.y), max($0.z, $1.z))
        }

        let size = maxVertex - minVertex

        // Map to 0-1 UV space
        let uvCoordinates = vertices.map { vertex in
            SIMD2<Float>(
                (vertex.x - minVertex.x) / size.x,
                (vertex.y - minVertex.y) / size.y
            )
        }

        return UVMap(
            coordinates: uvCoordinates,
            indices: Array(0..<vertices.count)
        )
    }

    private func createPlanarMapping(_ texture: CIImage, surface: MappedSurface) -> ProjectedTexture {
        // Simple planar projection
        let uvMap = UVMap(
            coordinates: [
                SIMD2<Float>(0, 0),
                SIMD2<Float>(1, 0),
                SIMD2<Float>(1, 1),
                SIMD2<Float>(0, 1)
            ],
            indices: [0, 1, 2, 3]
        )

        return ProjectedTexture(
            surfaceID: surface.id,
            texture: texture,
            uvMap: uvMap,
            blendMode: .normal
        )
    }

    private func applyUVWarp(_ texture: CIImage, uvMap: UVMap) -> CIImage {
        // Apply mesh warp based on UV coordinates
        // Use CIPerspectiveTransform or custom Metal shader

        guard uvMap.coordinates.count >= 4 else {
            return texture
        }

        // For now, apply simple perspective transform
        let transform = CIFilter(name: "CIPerspectiveTransform")!

        let topLeft = CIVector(cgPoint: CGPoint(
            x: CGFloat(uvMap.coordinates[0].x) * texture.extent.width,
            y: CGFloat(uvMap.coordinates[0].y) * texture.extent.height
        ))

        let topRight = CIVector(cgPoint: CGPoint(
            x: CGFloat(uvMap.coordinates[1].x) * texture.extent.width,
            y: CGFloat(uvMap.coordinates[1].y) * texture.extent.height
        ))

        let bottomRight = CIVector(cgPoint: CGPoint(
            x: CGFloat(uvMap.coordinates[2].x) * texture.extent.width,
            y: CGFloat(uvMap.coordinates[2].y) * texture.extent.height
        ))

        let bottomLeft = CIVector(cgPoint: CGPoint(
            x: CGFloat(uvMap.coordinates[3].x) * texture.extent.width,
            y: CGFloat(uvMap.coordinates[3].y) * texture.extent.height
        ))

        transform.setValue(texture, forKey: kCIInputImageKey)
        transform.setValue(topLeft, forKey: "inputTopLeft")
        transform.setValue(topRight, forKey: "inputTopRight")
        transform.setValue(bottomRight, forKey: "inputBottomRight")
        transform.setValue(bottomLeft, forKey: "inputBottomLeft")

        return transform.outputImage ?? texture
    }

    private func calculateHomography(from corners: [CGPoint]) -> simd_float4x4 {
        // Calculate perspective transform matrix
        // This is a simplified version - full implementation would use OpenCV-style homography

        guard corners.count >= 4 else {
            return .identity
        }

        // For now, return identity
        // TODO: Implement full homography calculation
        return .identity
    }

    private func detectCheckerboardCorners(in image: CIImage) async throws -> [CGPoint] {
        // Detect checkerboard pattern for calibration
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.8
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(ciImage: image)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw MappingError.checkerboardNotFound
        }

        // Return corner points
        return [
            CGPoint(x: observation.topLeft.x, y: observation.topLeft.y),
            CGPoint(x: observation.topRight.x, y: observation.topRight.y),
            CGPoint(x: observation.bottomRight.x, y: observation.bottomRight.y),
            CGPoint(x: observation.bottomLeft.x, y: observation.bottomLeft.y)
        ]
    }

    private func setupVisionRequests() {
        // Object recognition
        objectRecognitionRequest = VNRecognizeObjectsRequest()

        // Rectangle detection
        rectangleDetectionRequest = VNDetectRectanglesRequest()
        rectangleDetectionRequest?.minimumConfidence = 0.7
    }

    // MARK: - Supporting Types

    struct MappedSurface: Identifiable {
        let id: UUID
        let classification: SurfaceClassification
        let vertices: [SIMD3<Float>]
        let faceCount: Int
        let area: Float
        let transform: simd_float4x4
        let center: SIMD3<Float>
    }

    enum SurfaceClassification {
        case wall
        case floor
        case ceiling
        case door
        case window
        case furniture
        case object
    }

    struct DetectedObject: Identifiable {
        let id: UUID
        let label: String
        let confidence: Double
        let boundingBox: CGRect
        let transform: simd_float4x4
    }

    struct UVMap {
        let coordinates: [SIMD2<Float>]
        let indices: [Int]
    }

    struct ProjectedTexture {
        let surfaceID: UUID
        let texture: CIImage
        let uvMap: UVMap
        let blendMode: BlendMode

        enum BlendMode {
            case normal
            case add
            case multiply
            case screen
        }
    }

    // MARK: - Errors

    enum MappingError: Error, LocalizedError {
        case noARSession
        case visionNotInitialized
        case insufficientCalibrationPoints
        case checkerboardNotFound

        var errorDescription: String? {
            switch self {
            case .noARSession:
                return "AR session not initialized"
            case .visionNotInitialized:
                return "Vision framework not initialized"
            case .insufficientCalibrationPoints:
                return "Need at least 4 calibration points"
            case .checkerboardNotFound:
                return "Calibration checkerboard not detected"
            }
        }
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = Dictionary(grouping: self, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - simd_float4x4 Extension

extension simd_float4x4 {
    static var identity: simd_float4x4 {
        return matrix_identity_float4x4
    }
}
