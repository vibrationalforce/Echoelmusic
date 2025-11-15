//
//  Advanced3DVisualSystem.swift
//  Echoelmusic
//
//  Advanced 3D visual effects with particle systems, 3D scene graph,
//  and real-time rendering using Metal and Model I/O.
//

import SwiftUI
import Metal
import MetalKit
import ModelIO
import simd
import Combine

// MARK: - 3D Visual System

@MainActor
class Advanced3DVisualSystem: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var scene: Scene3D
    @Published var camera: Camera3D
    @Published var particleSystems: [ParticleSystem3D] = []
    @Published var lights: [Light3D] = []
    @Published var meshes: [Mesh3D] = []
    @Published var isRendering: Bool = false
    @Published var currentFPS: Double = 0
    @Published var renderTime: TimeInterval = 0

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var particlePipelineState: MTLRenderPipelineState?
    private var computePipelineState: MTLComputePipelineState?
    private var depthState: MTLDepthStencilState?

    // MARK: - Buffers

    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var particleBuffer: MTLBuffer?
    private var particleStateBuffer: MTLBuffer?

    // MARK: - Textures

    private var colorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var normalTexture: MTLTexture?
    private var particleTexture: MTLTexture?

    // MARK: - Timing

    private var lastFrameTime: TimeInterval = CACurrentMediaTime()
    private var frameCount: Int = 0
    private var fpsUpdateTime: TimeInterval = 0

    // MARK: - Initialization

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        self.scene = Scene3D()
        self.camera = Camera3D()

        super.init()

        setupMetal()
        setupDefaultScene()
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        // Create render pipeline for 3D meshes
        guard let library = device.makeDefaultLibrary() else { return }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex3D")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment3D")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        // Create pipeline for particles
        let particleDescriptor = MTLRenderPipelineDescriptor()
        particleDescriptor.vertexFunction = library.makeFunction(name: "vertexParticle3D")
        particleDescriptor.fragmentFunction = library.makeFunction(name: "fragmentParticle3D")
        particleDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        particleDescriptor.depthAttachmentPixelFormat = .depth32Float
        particleDescriptor.colorAttachments[0].isBlendingEnabled = true
        particleDescriptor.colorAttachments[0].rgbBlendOperation = .add
        particleDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        particleDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one

        particlePipelineState = try? device.makeRenderPipelineState(descriptor: particleDescriptor)

        // Create compute pipeline for particle simulation
        if let particleUpdateFunction = library.makeFunction(name: "updateParticles3D") {
            computePipelineState = try? device.makeComputePipelineState(function: particleUpdateFunction)
        }

        // Create depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    // MARK: - Scene Setup

    private func setupDefaultScene() {
        // Setup default camera
        camera.position = SIMD3<Float>(0, 0, 5)
        camera.target = SIMD3<Float>(0, 0, 0)
        camera.up = SIMD3<Float>(0, 1, 0)
        camera.fov = 60
        camera.near = 0.1
        camera.far = 100

        // Add default lights
        let keyLight = Light3D(
            type: .directional,
            position: SIMD3<Float>(5, 10, 5),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0
        )
        lights.append(keyLight)

        let fillLight = Light3D(
            type: .point,
            position: SIMD3<Float>(-5, 5, 5),
            color: SIMD3<Float>(0.5, 0.7, 1.0),
            intensity: 0.5
        )
        lights.append(fillLight)

        let ambientLight = Light3D(
            type: .ambient,
            position: .zero,
            color: SIMD3<Float>(1, 1, 1),
            intensity: 0.2
        )
        lights.append(ambientLight)
    }

    // MARK: - Rendering

    func render(to texture: MTLTexture, deltaTime: TimeInterval) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let startTime = CACurrentMediaTime()

        // Update particle systems on GPU
        updateParticles(commandBuffer: commandBuffer, deltaTime: Float(deltaTime))

        // Render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(scene.backgroundColor.x),
            green: Double(scene.backgroundColor.y),
            blue: Double(scene.backgroundColor.z),
            alpha: 1.0
        )
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // Create or update depth texture
        if depthTexture == nil || depthTexture?.width != texture.width || depthTexture?.height != texture.height {
            let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float,
                width: texture.width,
                height: texture.height,
                mipmapped: false
            )
            depthDescriptor.usage = [.renderTarget]
            depthDescriptor.storageMode = .private
            depthTexture = device.makeTexture(descriptor: depthDescriptor)
        }

        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.storeAction = .dontCare

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.setDepthStencilState(depthState)

        // Update uniforms
        updateUniforms(width: texture.width, height: texture.height)

        // Render meshes
        if let pipelineState = pipelineState {
            renderEncoder.setRenderPipelineState(pipelineState)
            renderMeshes(encoder: renderEncoder)
        }

        // Render particles
        if let particlePipelineState = particlePipelineState {
            renderEncoder.setRenderPipelineState(particlePipelineState)
            renderParticles(encoder: renderEncoder)
        }

        renderEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Update performance metrics
        renderTime = CACurrentMediaTime() - startTime
        updateFPS()
    }

    // MARK: - Particle Update

    private func updateParticles(commandBuffer: MTLCommandBuffer, deltaTime: Float) {
        guard let computePipeline = computePipelineState,
              !particleSystems.isEmpty else { return }

        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.setComputePipelineState(computePipeline)

        for (index, particleSystem) in particleSystems.enumerated() {
            particleSystem.update(deltaTime: deltaTime)

            // Update particle buffer
            if let buffer = particleSystem.particleBuffer {
                computeEncoder.setBuffer(buffer, offset: 0, index: 0)

                var params = ParticleUpdateParams(
                    deltaTime: deltaTime,
                    gravity: particleSystem.gravity,
                    damping: particleSystem.damping,
                    particleCount: UInt32(particleSystem.particles.count)
                )
                computeEncoder.setBytes(&params, length: MemoryLayout<ParticleUpdateParams>.stride, index: 1)

                let threadGroupSize = MTLSize(width: 256, height: 1, depth: 1)
                let threadGroups = MTLSize(
                    width: (particleSystem.particles.count + 255) / 256,
                    height: 1,
                    depth: 1
                )

                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            }
        }

        computeEncoder.endEncoding()
    }

    // MARK: - Mesh Rendering

    private func renderMeshes(encoder: MTLRenderCommandEncoder) {
        for mesh in meshes where mesh.isVisible {
            // Set vertex and index buffers
            if let vertexBuffer = mesh.vertexBuffer {
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            }

            if let uniformBuffer = uniformBuffer {
                encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            }

            // Set mesh transform
            var transform = mesh.transform
            encoder.setVertexBytes(&transform, length: MemoryLayout<matrix_float4x4>.stride, index: 2)

            // Set material properties
            var material = mesh.material
            encoder.setFragmentBytes(&material, length: MemoryLayout<Material3D>.stride, index: 0)

            // Set lights
            var lightData = lights.map { $0.toLightData() }
            encoder.setFragmentBytes(&lightData, length: MemoryLayout<LightData>.stride * lights.count, index: 1)
            var lightCount = Int32(lights.count)
            encoder.setFragmentBytes(&lightCount, length: MemoryLayout<Int32>.stride, index: 2)

            // Draw
            if let indexBuffer = mesh.indexBuffer {
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: mesh.indexCount,
                    indexType: .uint32,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0
                )
            } else {
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertexCount)
            }
        }
    }

    // MARK: - Particle Rendering

    private func renderParticles(encoder: MTLRenderCommandEncoder) {
        for particleSystem in particleSystems where particleSystem.isActive {
            if let particleBuffer = particleSystem.particleBuffer {
                encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)

                if let uniformBuffer = uniformBuffer {
                    encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                }

                var systemParams = particleSystem.getRenderParams()
                encoder.setVertexBytes(&systemParams, length: MemoryLayout<ParticleRenderParams>.stride, index: 2)
                encoder.setFragmentBytes(&systemParams, length: MemoryLayout<ParticleRenderParams>.stride, index: 0)

                encoder.drawPrimitives(
                    type: .point,
                    vertexStart: 0,
                    vertexCount: particleSystem.particles.count
                )
            }
        }
    }

    // MARK: - Uniforms

    private func updateUniforms(width: Int, height: Int) {
        let aspect = Float(width) / Float(height)

        var uniforms = Uniforms3D(
            projectionMatrix: camera.getProjectionMatrix(aspectRatio: aspect),
            viewMatrix: camera.getViewMatrix(),
            cameraPosition: camera.position,
            time: Float(CACurrentMediaTime())
        )

        if uniformBuffer == nil || uniformBuffer!.length < MemoryLayout<Uniforms3D>.stride {
            uniformBuffer = device.makeBuffer(
                bytes: &uniforms,
                length: MemoryLayout<Uniforms3D>.stride,
                options: .storageModeShared
            )
        } else {
            memcpy(uniformBuffer!.contents(), &uniforms, MemoryLayout<Uniforms3D>.stride)
        }
    }

    // MARK: - FPS Tracking

    private func updateFPS() {
        let currentTime = CACurrentMediaTime()
        frameCount += 1

        if currentTime - fpsUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - fpsUpdateTime)
            frameCount = 0
            fpsUpdateTime = currentTime
        }
    }

    // MARK: - Public Methods

    func addParticleSystem(_ system: ParticleSystem3D) {
        particleSystems.append(system)
        system.initialize(device: device)
    }

    func removeParticleSystem(_ system: ParticleSystem3D) {
        particleSystems.removeAll { $0.id == system.id }
    }

    func addMesh(_ mesh: Mesh3D) {
        meshes.append(mesh)
        mesh.createBuffers(device: device)
    }

    func removeMesh(_ mesh: Mesh3D) {
        meshes.removeAll { $0.id == mesh.id }
    }

    func addLight(_ light: Light3D) {
        lights.append(light)
    }

    func removeLight(_ light: Light3D) {
        lights.removeAll { $0.id == light.id }
    }
}

// MARK: - Scene 3D

struct Scene3D {
    var backgroundColor: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var ambientColor: SIMD3<Float> = SIMD3<Float>(0.2, 0.2, 0.2)
    var fogEnabled: Bool = false
    var fogColor: SIMD3<Float> = SIMD3<Float>(0.5, 0.5, 0.5)
    var fogStart: Float = 10
    var fogEnd: Float = 50
}

// MARK: - Camera 3D

class Camera3D: ObservableObject {
    @Published var position: SIMD3<Float> = SIMD3<Float>(0, 0, 5)
    @Published var target: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published var up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    @Published var fov: Float = 60
    @Published var near: Float = 0.1
    @Published var far: Float = 100

    func getViewMatrix() -> matrix_float4x4 {
        let z = normalize(position - target)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        return matrix_float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-dot(x, position), -dot(y, position), -dot(z, position), 1)
        )
    }

    func getProjectionMatrix(aspectRatio: Float) -> matrix_float4x4 {
        let fovRadians = fov * .pi / 180.0
        let ys = 1 / tan(fovRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = far / (near - far)

        return matrix_float4x4(
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1),
            SIMD4<Float>(0, 0, near * zs, 0)
        )
    }

    func orbit(deltaX: Float, deltaY: Float, radius: Float) {
        let theta = atan2(position.z - target.z, position.x - target.x) + deltaX
        let phi = asin((position.y - target.y) / radius) + deltaY

        position = SIMD3<Float>(
            target.x + radius * cos(phi) * cos(theta),
            target.y + radius * sin(phi),
            target.z + radius * cos(phi) * sin(theta)
        )
    }

    func pan(deltaX: Float, deltaY: Float) {
        let z = normalize(position - target)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        let offset = x * deltaX + y * deltaY
        position += offset
        target += offset
    }

    func zoom(delta: Float) {
        let direction = normalize(target - position)
        position += direction * delta
    }
}

// MARK: - Light 3D

class Light3D: Identifiable, ObservableObject {
    let id = UUID()

    enum LightType {
        case directional
        case point
        case spot
        case ambient
    }

    @Published var type: LightType
    @Published var position: SIMD3<Float>
    @Published var direction: SIMD3<Float> = SIMD3<Float>(0, -1, 0)
    @Published var color: SIMD3<Float>
    @Published var intensity: Float
    @Published var range: Float = 10
    @Published var spotAngle: Float = 45
    @Published var spotSoftness: Float = 0.5

    init(type: LightType, position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float) {
        self.type = type
        self.position = position
        self.color = color
        self.intensity = intensity
    }

    func toLightData() -> LightData {
        LightData(
            position: SIMD4<Float>(position.x, position.y, position.z, 0),
            direction: SIMD4<Float>(direction.x, direction.y, direction.z, 0),
            color: SIMD4<Float>(color.x, color.y, color.z, 1),
            intensity: intensity,
            range: range,
            spotAngle: spotAngle,
            spotSoftness: spotSoftness,
            type: type.rawValue
        )
    }
}

extension Light3D.LightType {
    var rawValue: Int32 {
        switch self {
        case .directional: return 0
        case .point: return 1
        case .spot: return 2
        case .ambient: return 3
        }
    }
}

// MARK: - Mesh 3D

class Mesh3D: Identifiable, ObservableObject {
    let id = UUID()

    @Published var vertices: [Vertex3D] = []
    @Published var indices: [UInt32] = []
    @Published var transform: matrix_float4x4 = matrix_identity_float4x4
    @Published var material: Material3D = Material3D()
    @Published var isVisible: Bool = true

    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?

    var vertexCount: Int { vertices.count }
    var indexCount: Int { indices.count }

    func createBuffers(device: MTLDevice) {
        if !vertices.isEmpty {
            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<Vertex3D>.stride * vertices.count,
                options: .storageModeShared
            )
        }

        if !indices.isEmpty {
            indexBuffer = device.makeBuffer(
                bytes: indices,
                length: MemoryLayout<UInt32>.stride * indices.count,
                options: .storageModeShared
            )
        }
    }

    static func createCube(size: Float = 1.0) -> Mesh3D {
        let mesh = Mesh3D()
        let s = size / 2

        // Vertices (positions, normals, UVs)
        mesh.vertices = [
            // Front face
            Vertex3D(position: SIMD3(-s, -s,  s), normal: SIMD3(0, 0, 1), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3( s, -s,  s), normal: SIMD3(0, 0, 1), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3( s,  s,  s), normal: SIMD3(0, 0, 1), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3(-s,  s,  s), normal: SIMD3(0, 0, 1), uv: SIMD2(0, 1)),
            // Back face
            Vertex3D(position: SIMD3( s, -s, -s), normal: SIMD3(0, 0, -1), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3(-s, -s, -s), normal: SIMD3(0, 0, -1), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3(-s,  s, -s), normal: SIMD3(0, 0, -1), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3( s,  s, -s), normal: SIMD3(0, 0, -1), uv: SIMD2(0, 1)),
            // Top face
            Vertex3D(position: SIMD3(-s,  s,  s), normal: SIMD3(0, 1, 0), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3( s,  s,  s), normal: SIMD3(0, 1, 0), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3( s,  s, -s), normal: SIMD3(0, 1, 0), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3(-s,  s, -s), normal: SIMD3(0, 1, 0), uv: SIMD2(0, 1)),
            // Bottom face
            Vertex3D(position: SIMD3(-s, -s, -s), normal: SIMD3(0, -1, 0), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3( s, -s, -s), normal: SIMD3(0, -1, 0), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3( s, -s,  s), normal: SIMD3(0, -1, 0), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3(-s, -s,  s), normal: SIMD3(0, -1, 0), uv: SIMD2(0, 1)),
            // Right face
            Vertex3D(position: SIMD3( s, -s,  s), normal: SIMD3(1, 0, 0), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3( s, -s, -s), normal: SIMD3(1, 0, 0), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3( s,  s, -s), normal: SIMD3(1, 0, 0), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3( s,  s,  s), normal: SIMD3(1, 0, 0), uv: SIMD2(0, 1)),
            // Left face
            Vertex3D(position: SIMD3(-s, -s, -s), normal: SIMD3(-1, 0, 0), uv: SIMD2(0, 0)),
            Vertex3D(position: SIMD3(-s, -s,  s), normal: SIMD3(-1, 0, 0), uv: SIMD2(1, 0)),
            Vertex3D(position: SIMD3(-s,  s,  s), normal: SIMD3(-1, 0, 0), uv: SIMD2(1, 1)),
            Vertex3D(position: SIMD3(-s,  s, -s), normal: SIMD3(-1, 0, 0), uv: SIMD2(0, 1)),
        ]

        // Indices
        mesh.indices = [
            0, 1, 2, 2, 3, 0,       // Front
            4, 5, 6, 6, 7, 4,       // Back
            8, 9, 10, 10, 11, 8,    // Top
            12, 13, 14, 14, 15, 12, // Bottom
            16, 17, 18, 18, 19, 16, // Right
            20, 21, 22, 22, 23, 20  // Left
        ]

        return mesh
    }

    static func createSphere(radius: Float = 1.0, segments: Int = 32) -> Mesh3D {
        let mesh = Mesh3D()

        for lat in 0...segments {
            let theta = Float(lat) * .pi / Float(segments)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for lon in 0...segments {
                let phi = Float(lon) * 2 * .pi / Float(segments)
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)

                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta

                let position = SIMD3<Float>(x, y, z) * radius
                let normal = normalize(SIMD3<Float>(x, y, z))
                let uv = SIMD2<Float>(Float(lon) / Float(segments), Float(lat) / Float(segments))

                mesh.vertices.append(Vertex3D(position: position, normal: normal, uv: uv))
            }
        }

        for lat in 0..<segments {
            for lon in 0..<segments {
                let first = UInt32(lat * (segments + 1) + lon)
                let second = UInt32(first + segments + 1)

                mesh.indices.append(contentsOf: [
                    first, second, first + 1,
                    second, second + 1, first + 1
                ])
            }
        }

        return mesh
    }
}

// MARK: - Particle System 3D

class ParticleSystem3D: Identifiable, ObservableObject {
    let id = UUID()

    @Published var particles: [Particle3D] = []
    @Published var emitterPosition: SIMD3<Float> = .zero
    @Published var emitterVelocity: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    @Published var emitterSpread: Float = 0.5
    @Published var particleLifetime: Float = 2.0
    @Published var particleSize: Float = 0.1
    @Published var particleColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    @Published var gravity: SIMD3<Float> = SIMD3<Float>(0, -9.8, 0)
    @Published var damping: Float = 0.99
    @Published var emissionRate: Float = 100 // particles per second
    @Published var maxParticles: Int = 10000
    @Published var isActive: Bool = true
    @Published var blendMode: BlendMode = .additive

    var particleBuffer: MTLBuffer?
    private var timeSinceLastEmission: Float = 0

    enum BlendMode {
        case additive
        case alpha
    }

    func initialize(device: MTLDevice) {
        createParticleBuffer(device: device)
    }

    private func createParticleBuffer(device: MTLDevice) {
        if !particles.isEmpty {
            particleBuffer = device.makeBuffer(
                bytes: particles,
                length: MemoryLayout<Particle3D>.stride * particles.count,
                options: .storageModeShared
            )
        }
    }

    func update(deltaTime: Float) {
        guard isActive else { return }

        // Emit new particles
        timeSinceLastEmission += deltaTime
        let particlesToEmit = Int(timeSinceLastEmission * emissionRate)

        if particlesToEmit > 0 {
            timeSinceLastEmission = 0

            for _ in 0..<particlesToEmit {
                if particles.count < maxParticles {
                    emitParticle()
                }
            }
        }

        // Update existing particles
        particles = particles.filter { particle in
            particle.age < particle.lifetime
        }

        for i in 0..<particles.count {
            particles[i].age += deltaTime
            particles[i].velocity += gravity * deltaTime
            particles[i].velocity *= damping
            particles[i].position += particles[i].velocity * deltaTime

            // Update alpha based on age
            let lifeRatio = particles[i].age / particles[i].lifetime
            particles[i].color.w = particleColor.w * (1.0 - lifeRatio)
        }
    }

    private func emitParticle() {
        let randomAngle = Float.random(in: 0...(2 * .pi))
        let randomPitch = Float.random(in: -emitterSpread...emitterSpread)

        let velocity = SIMD3<Float>(
            emitterVelocity.x + cos(randomAngle) * emitterSpread,
            emitterVelocity.y + randomPitch,
            emitterVelocity.z + sin(randomAngle) * emitterSpread
        )

        let particle = Particle3D(
            position: emitterPosition,
            velocity: velocity,
            color: particleColor,
            size: particleSize,
            lifetime: particleLifetime,
            age: 0
        )

        particles.append(particle)
    }

    func getRenderParams() -> ParticleRenderParams {
        ParticleRenderParams(
            size: particleSize,
            color: particleColor
        )
    }

    // Preset particle systems
    static func createFireSystem() -> ParticleSystem3D {
        let system = ParticleSystem3D()
        system.emitterVelocity = SIMD3<Float>(0, 2, 0)
        system.emitterSpread = 0.3
        system.particleLifetime = 1.5
        system.particleSize = 0.2
        system.particleColor = SIMD4<Float>(1, 0.5, 0, 1)
        system.gravity = SIMD3<Float>(0, 1, 0)
        system.damping = 0.95
        system.emissionRate = 50
        system.blendMode = .additive
        return system
    }

    static func createSmokeSystem() -> ParticleSystem3D {
        let system = ParticleSystem3D()
        system.emitterVelocity = SIMD3<Float>(0, 0.5, 0)
        system.emitterSpread = 0.5
        system.particleLifetime = 3.0
        system.particleSize = 0.5
        system.particleColor = SIMD4<Float>(0.5, 0.5, 0.5, 0.5)
        system.gravity = SIMD3<Float>(0, 0.2, 0)
        system.damping = 0.98
        system.emissionRate = 30
        system.blendMode = .alpha
        return system
    }

    static func createSparkSystem() -> ParticleSystem3D {
        let system = ParticleSystem3D()
        system.emitterVelocity = SIMD3<Float>(0, 3, 0)
        system.emitterSpread = 1.5
        system.particleLifetime = 0.8
        system.particleSize = 0.05
        system.particleColor = SIMD4<Float>(1, 1, 0, 1)
        system.gravity = SIMD3<Float>(0, -9.8, 0)
        system.damping = 0.99
        system.emissionRate = 200
        system.blendMode = .additive
        return system
    }
}

// MARK: - Data Structures

struct Vertex3D {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
}

struct Particle3D {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var color: SIMD4<Float>
    var size: Float
    var lifetime: Float
    var age: Float
}

struct Material3D {
    var albedo: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    var metallic: Float = 0.0
    var roughness: Float = 0.5
    var emission: SIMD3<Float> = .zero
    var emissionStrength: Float = 0.0
}

struct Uniforms3D {
    var projectionMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
    var cameraPosition: SIMD3<Float>
    var time: Float
}

struct LightData {
    var position: SIMD4<Float>
    var direction: SIMD4<Float>
    var color: SIMD4<Float>
    var intensity: Float
    var range: Float
    var spotAngle: Float
    var spotSoftness: Float
    var type: Int32
    var padding: SIMD3<Float> = .zero
}

struct ParticleUpdateParams {
    var deltaTime: Float
    var gravity: SIMD3<Float>
    var damping: Float
    var particleCount: UInt32
}

struct ParticleRenderParams {
    var size: Float
    var color: SIMD4<Float>
}

// MARK: - SwiftUI View

struct Advanced3DVisualView: View {
    @StateObject private var visualSystem: Advanced3DVisualSystem
    @State private var displayLink: CADisplayLink?

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        _visualSystem = StateObject(wrappedValue: Advanced3DVisualSystem(device: device, commandQueue: commandQueue))
    }

    var body: some View {
        VStack {
            MetalView3D(visualSystem: visualSystem)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Stats
            HStack {
                Text("FPS: \(Int(visualSystem.currentFPS))")
                Spacer()
                Text("Render: \(String(format: "%.2f", visualSystem.renderTime * 1000))ms")
                Spacer()
                Text("Particles: \(visualSystem.particleSystems.reduce(0) { $0 + $1.particles.count })")
            }
            .font(.system(.caption, design: .monospaced))
            .padding()
        }
    }
}

struct MetalView3D: UIViewRepresentable {
    let visualSystem: Advanced3DVisualSystem

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = visualSystem.device
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(visualSystem: visualSystem)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let visualSystem: Advanced3DVisualSystem
        var lastFrameTime: TimeInterval = CACurrentMediaTime()

        init(visualSystem: Advanced3DVisualSystem) {
            self.visualSystem = visualSystem
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }

            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastFrameTime
            lastFrameTime = currentTime

            visualSystem.render(to: drawable.texture, deltaTime: deltaTime)
        }
    }
}
