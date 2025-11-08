import Foundation
import SceneKit
import Metal
import simd

/// Hologram Projection System
///
/// Features:
/// - Laser-based hologram projection
/// - Volumetric display simulation
/// - Pepper's Ghost effect
/// - Structured light projection
/// - Real-time 3D rendering
/// - Depth-layered visuals
@MainActor
class HologramProjector: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether hologram is active
    @Published var isActive: Bool = false

    /// Current hologram mode
    @Published var hologramMode: HologramMode = .volumetric

    /// Projection intensity (0-1)
    @Published var intensity: Float = 0.8

    /// Depth layers
    @Published var depthLayers: Int = 10

    // MARK: - Configuration

    enum HologramMode {
        case volumetric      // 3D volumetric display
        case peppersGhost   // Pepper's Ghost illusion
        case laser           // Laser scanning
        case structured      // Structured light
    }

    // MARK: - SceneKit Components

    private var scene: SCNScene?
    private var hologramNode: SCNNode?
    private var particleSystem: SCNParticleSystem?

    // MARK: - Metal Components

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?

    // MARK: - Laser Parameters

    private var laserPoints: [SIMD3<Float>] = []
    private var laserColor: SIMD3<Float> = SIMD3<Float>(0, 1, 0)  // Green
    private var laserScanRate: Float = 30000  // Points per second

    // MARK: - Depth Planes

    private var depthPlanes: [DepthPlane] = []

    // MARK: - Initialization

    override init() {
        super.init()
        setup()
        print("✨ HologramProjector initialized")
    }

    // MARK: - Public API

    /// Start hologram projection
    func start() {
        guard !isActive else { return }

        isActive = true
        setupScene()
        print("✨ Hologram projection started: \(hologramMode)")
    }

    /// Stop hologram projection
    func stop() {
        isActive = false
        scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        hologramNode = nil
        print("✨ Hologram projection stopped")
    }

    /// Set hologram mode
    func setMode(_ mode: HologramMode) {
        hologramMode = mode
        if isActive {
            setupScene()
        }
    }

    /// Project 3D model as hologram
    func project(model: SCNNode, at position: SIMD3<Float>) {
        guard isActive else { return }

        switch hologramMode {
        case .volumetric:
            projectVolumetric(model: model, at: position)

        case .peppersGhost:
            projectPeppersGhost(model: model, at: position)

        case .laser:
            projectLaser(model: model, at: position)

        case .structured:
            projectStructuredLight(model: model, at: position)
        }
    }

    /// Create volumetric particles
    func createVolumetricParticles(count: Int, bounds: SCNVector3) -> SCNNode {
        let particleNode = SCNNode()

        for _ in 0..<count {
            let particle = SCNNode()

            // Random position within bounds
            particle.position = SCNVector3(
                Float.random(in: -bounds.x...bounds.x),
                Float.random(in: -bounds.y...bounds.y),
                Float.random(in: -bounds.z...bounds.z)
            )

            // Glowing sphere
            let sphere = SCNSphere(radius: 0.002)
            sphere.firstMaterial?.emission.contents = UIColor.cyan
            sphere.firstMaterial?.lightingModel = .constant
            particle.geometry = sphere

            particleNode.addChildNode(particle)
        }

        // Add glow effect
        addGlowEffect(to: particleNode)

        return particleNode
    }

    /// Create depth-layered hologram
    func createDepthLayers(image: UIImage, layerCount: Int) -> [DepthPlane] {
        var planes: [DepthPlane] = []

        let depthStep = 0.1 / Float(layerCount)

        for i in 0..<layerCount {
            let depth = Float(i) * depthStep
            let alpha = 1.0 - (Float(i) / Float(layerCount)) * 0.7

            let plane = DepthPlane(
                image: image,
                depth: depth,
                alpha: alpha,
                parallax: Float(i) * 0.01
            )

            planes.append(plane)
        }

        depthPlanes = planes
        return planes
    }

    /// Laser scan pattern
    func generateLaserScanPattern(for model: SCNNode) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []

        // Extract vertices from model
        if let geometry = model.geometry {
            points = extractVertices(from: geometry)
        }

        // Generate scan pattern (raster scan)
        let sortedPoints = points.sorted { p1, p2 in
            if abs(p1.y - p2.y) < 0.01 {
                return p1.x < p2.x
            }
            return p1.y > p2.y
        }

        laserPoints = sortedPoints
        return sortedPoints
    }

    /// Animate laser scan
    func animateLaserScan(duration: TimeInterval) {
        guard !laserPoints.isEmpty else { return }

        let pointsPerFrame = Int(Float(laserPoints.count) / Float(duration * 60))

        // TODO: Implement frame-by-frame laser animation
        print("✨ Animating laser scan: \(laserPoints.count) points")
    }

    // MARK: - Private Methods

    private func setup() {
        // Setup Metal
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()

        // Setup scene
        scene = SCNScene()
    }

    private func setupScene() {
        guard let scene = scene else { return }

        // Clear existing nodes
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 200
        scene.rootNode.addChildNode(ambientLight)

        // Mode-specific setup
        switch hologramMode {
        case .volumetric:
            setupVolumetricMode()
        case .peppersGhost:
            setupPeppersGhostMode()
        case .laser:
            setupLaserMode()
        case .structured:
            setupStructuredLightMode()
        }
    }

    private func setupVolumetricMode() {
        // Create particle system for volumetric effect
        particleSystem = SCNParticleSystem()
        particleSystem?.particleSize = 0.005
        particleSystem?.particleColor = .cyan
        particleSystem?.emissionDuration = 1000
        particleSystem?.birthRate = 1000
        particleSystem?.particleLifeSpan = 2.0
        particleSystem?.particleVelocity = 0.1
        particleSystem?.particleVelocityVariation = 0.05

        let emitter = SCNNode()
        emitter.addParticleSystem(particleSystem!)
        scene?.rootNode.addChildNode(emitter)
    }

    private func setupPeppersGhostMode() {
        // Setup angled reflective surface (45 degrees)
        let plane = SCNPlane(width: 1.0, height: 1.0)
        plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        plane.firstMaterial?.transparency = 0.3
        plane.firstMaterial?.isDoubleSided = true

        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles = SCNVector3(-.pi/4, 0, 0)
        scene?.rootNode.addChildNode(planeNode)
    }

    private func setupLaserMode() {
        // Setup laser scanning system
        print("✨ Laser mode: \(laserScanRate) Hz scan rate")
    }

    private func setupStructuredLightMode() {
        // Setup structured light projector
        let projectorLight = SCNNode()
        projectorLight.light = SCNLight()
        projectorLight.light?.type = .spot
        projectorLight.light?.intensity = 2000
        projectorLight.light?.spotInnerAngle = 30
        projectorLight.light?.spotOuterAngle = 60
        projectorLight.position = SCNVector3(0, 1, 1)
        projectorLight.eulerAngles = SCNVector3(-.pi/4, 0, 0)

        scene?.rootNode.addChildNode(projectorLight)
    }

    private func projectVolumetric(model: SCNNode, at position: SIMD3<Float>) {
        guard let scene = scene else { return }

        // Clone model
        let hologram = model.clone()
        hologram.position = SCNVector3(position.x, position.y, position.z)

        // Apply holographic material
        applyHolographicMaterial(to: hologram)

        // Add to scene
        scene.rootNode.addChildNode(hologram)
        hologramNode = hologram

        // Animate
        let rotation = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4)
        let repeatRotation = SCNAction.repeatForever(rotation)
        hologram.runAction(repeatRotation)

        // Add particle field
        let particles = createVolumetricParticles(count: 1000, bounds: SCNVector3(0.2, 0.2, 0.2))
        particles.position = hologram.position
        scene.rootNode.addChildNode(particles)
    }

    private func projectPeppersGhost(model: SCNNode, at position: SIMD3<Float>) {
        guard let scene = scene else { return }

        // Project model onto angled plane
        let hologram = model.clone()
        hologram.position = SCNVector3(position.x, position.y - 0.5, position.z)

        // Semi-transparent ghostly appearance
        applyGhostMaterial(to: hologram)

        scene.rootNode.addChildNode(hologram)
        hologramNode = hologram
    }

    private func projectLaser(model: SCNNode, at position: SIMD3<Float>) {
        // Generate laser scan pattern
        let scanPoints = generateLaserScanPattern(for: model)

        // Create line segments between points
        let laserNode = createLaserVisualization(points: scanPoints)
        laserNode.position = SCNVector3(position.x, position.y, position.z)

        scene?.rootNode.addChildNode(laserNode)
        hologramNode = laserNode

        // Animate scan
        animateLaserScan(duration: 2.0)
    }

    private func projectStructuredLight(model: SCNNode, at position: SIMD3<Float>) {
        guard let scene = scene else { return }

        // Project with structured light patterns
        let hologram = model.clone()
        hologram.position = SCNVector3(position.x, position.y, position.z)

        // Apply light pattern texture
        applyStructuredLightMaterial(to: hologram)

        scene.rootNode.addChildNode(hologram)
        hologramNode = hologram
    }

    private func applyHolographicMaterial(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            child.geometry?.firstMaterial?.emission.contents = UIColor.cyan
            child.geometry?.firstMaterial?.transparency = 0.7
            child.geometry?.firstMaterial?.lightingModel = .constant
            child.geometry?.firstMaterial?.isDoubleSided = true
        }
    }

    private func applyGhostMaterial(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            child.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            child.geometry?.firstMaterial?.transparency = 0.4
            child.geometry?.firstMaterial?.lightingModel = .blinn
        }
    }

    private func applyStructuredLightMaterial(to node: SCNNode) {
        // Create striped pattern texture
        let stripeTexture = generateStripePattern(width: 512, height: 512, stripeWidth: 16)

        node.enumerateChildNodes { child, _ in
            child.geometry?.firstMaterial?.diffuse.contents = stripeTexture
            child.geometry?.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.3)
        }
    }

    private func addGlowEffect(to node: SCNNode) {
        // Add bloom/glow post-processing
        // This would typically be done in the renderer
    }

    private func extractVertices(from geometry: SCNGeometry) -> [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []

        guard let source = geometry.sources(for: .vertex).first else {
            return vertices
        }

        let stride = source.dataStride
        let offset = source.dataOffset
        let data = source.data

        for i in 0..<source.vectorCount {
            let byteOffset = offset + (i * stride)

            let x = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: byteOffset, as: Float.self)
            }

            let y = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: byteOffset + 4, as: Float.self)
            }

            let z = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: byteOffset + 8, as: Float.self)
            }

            vertices.append(SIMD3<Float>(x, y, z))
        }

        return vertices
    }

    private func createLaserVisualization(points: [SIMD3<Float>]) -> SCNNode {
        let container = SCNNode()

        // Create line geometry connecting points
        guard points.count > 1 else { return container }

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]

            let line = createLine(from: start, to: end, color: .green)
            container.addChildNode(line)
        }

        return container
    }

    private func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor) -> SCNNode {
        let vector = end - start
        let length = simd_length(vector)

        let cylinder = SCNCylinder(radius: 0.001, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.emission.contents = color
        cylinder.firstMaterial?.lightingModel = .constant

        let line = SCNNode(geometry: cylinder)

        // Position and orient line
        let midpoint = (start + end) / 2
        line.position = SCNVector3(midpoint.x, midpoint.y, midpoint.z)

        // Calculate rotation to align with vector
        let direction = simd_normalize(vector)
        let defaultDirection = SIMD3<Float>(0, 1, 0)
        let axis = simd_cross(defaultDirection, direction)
        let angle = acos(simd_dot(defaultDirection, direction))

        if simd_length(axis) > 0.001 {
            line.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }

        return line
    }

    private func generateStripePattern(width: Int, height: Int, stripeWidth: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            var currentX = 0

            while currentX < width {
                // White stripe
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(x: currentX, y: 0, width: stripeWidth, height: height))

                // Black stripe
                context.cgContext.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(x: currentX + stripeWidth, y: 0, width: stripeWidth, height: height))

                currentX += stripeWidth * 2
            }
        }
    }

    // MARK: - Supporting Types

    struct DepthPlane {
        let image: UIImage
        let depth: Float
        let alpha: Float
        let parallax: Float
    }
}
