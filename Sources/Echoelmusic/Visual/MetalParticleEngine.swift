import Foundation
import Metal
import MetalKit
import Combine

/// High-Performance Metal Particle Engine
/// Supports 100,000+ particles at 60 FPS using GPU compute shaders
/// Features biometric-driven physics and real-time interaction
@MainActor
class MetalParticleEngine: NSObject, ObservableObject {

    // MARK: - Configuration

    private(set) var particleCount: Int = 100_000  // 100k particles!

    // MARK: - Published State

    @Published var isRunning: Bool = false
    @Published var actualFPS: Double = 0.0
    @Published var gpuTime: Double = 0.0  // Milliseconds

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // Compute pipeline
    private var updatePipeline: MTLComputePipelineState?
    private var updateAdvancedPipeline: MTLComputePipelineState?

    // Render pipeline
    private var renderPipeline: MTLRenderPipelineState?

    // Buffers
    private var particleBuffer: MTLBuffer?
    private var biometricBuffer: MTLBuffer?

    // MARK: - Biometric Data

    struct BiometricData {
        var heartRate: Float = 60.0
        var hrv: Float = 50.0
        var eegWaves: SIMD4<Float> = SIMD4<Float>(0.25, 0.25, 0.25, 0.25)
        var breathing: Float = 0.0
        var movement: Float = 0.0
    }

    private var currentBiometrics = BiometricData()

    // MARK: - Particle Structure (must match Metal shader)

    struct Particle {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var color: SIMD4<Float>
        var size: Float
        var life: Float
        var age: Float
        var mass: Float
    }

    // MARK: - Performance Tracking

    private var lastUpdateTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: CFTimeInterval = 0

    // MARK: - Screen Size

    private var screenSize: SIMD2<Float> = SIMD2<Float>(1920, 1080)

    // MARK: - Initialization

    init?(device: MTLDevice, particleCount: Int = 100_000) {
        self.device = device
        self.particleCount = particleCount

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ MetalParticleEngine: Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue

        super.init()

        setupPipelines()
        setupBuffers()

        print("✅ MetalParticleEngine: Initialized with \(particleCount) particles")
    }

    // MARK: - Setup Pipelines

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("❌ Failed to load Metal library")
            return
        }

        // Compute pipelines
        if let updateFunction = library.makeFunction(name: "updateParticles") {
            do {
                updatePipeline = try device.makeComputePipelineState(function: updateFunction)
                print("✅ Basic particle update pipeline created")
            } catch {
                print("❌ Failed to create update pipeline: \(error)")
            }
        }

        if let updateAdvancedFunction = library.makeFunction(name: "updateParticlesAdvanced") {
            do {
                updateAdvancedPipeline = try device.makeComputePipelineState(function: updateAdvancedFunction)
                print("✅ Advanced particle update pipeline created")
            } catch {
                print("❌ Failed to create advanced update pipeline: \(error)")
            }
        }

        // Render pipeline
        setupRenderPipeline()
    }

    private func setupRenderPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }

        let vertexFunction = library.makeFunction(name: "particleVertex")
        let fragmentFunction = library.makeFunction(name: "particleFragment")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable alpha blending
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ Particle render pipeline created")
        } catch {
            print("❌ Failed to create render pipeline: \(error)")
        }
    }

    // MARK: - Setup Buffers

    private func setupBuffers() {
        // Allocate particle buffer
        let particleSize = MemoryLayout<Particle>.stride
        let bufferSize = particleSize * particleCount

        particleBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)

        // Initialize particles
        initializeParticles()

        // Allocate biometric buffer
        biometricBuffer = device.makeBuffer(
            length: MemoryLayout<BiometricData>.stride,
            options: .storageModeShared
        )

        print("✅ Particle buffers allocated (\(bufferSize / 1024 / 1024) MB)")
    }

    private func initializeParticles() {
        guard let buffer = particleBuffer else { return }

        let particles = buffer.contents().bindMemory(to: Particle.self, capacity: particleCount)

        for i in 0..<particleCount {
            let angle = Float.random(in: 0..<(.pi * 2))
            let speed = Float.random(in: 50...200)

            particles[i] = Particle(
                position: SIMD2<Float>(
                    Float.random(in: 0...screenSize.x),
                    Float.random(in: 0...screenSize.y)
                ),
                velocity: SIMD2<Float>(
                    cos(angle) * speed,
                    sin(angle) * speed
                ),
                color: SIMD4<Float>(
                    Float.random(in: 0.5...1.0),
                    Float.random(in: 0.5...1.0),
                    Float.random(in: 0.5...1.0),
                    0.6
                ),
                size: Float.random(in: 2...8),
                life: Float.random(in: 0.5...1.0),
                age: 0.0,
                mass: 1.0
            )
        }

        print("✅ Initialized \(particleCount) particles")
    }

    // MARK: - Update

    func update(deltaTime: Float, biometrics: BiometricData) {
        guard isRunning,
              let pipeline = updatePipeline,
              let particleBuffer = particleBuffer,
              let biometricBuffer = biometricBuffer else {
            return
        }

        // Update biometric data
        currentBiometrics = biometrics

        // Copy biometric data to GPU
        let bioPointer = biometricBuffer.contents().bindMemory(to: BiometricData.self, capacity: 1)
        bioPointer.pointee = biometrics

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        // Encode compute command
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(biometricBuffer, offset: 0, index: 1)
        computeEncoder.setBytes([deltaTime], length: MemoryLayout<Float>.stride, index: 2)
        computeEncoder.setBytes([screenSize], length: MemoryLayout<SIMD2<Float>>.stride, index: 3)

        // Calculate thread groups
        let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
        let numGroups = MTLSize(
            width: (particleCount + 255) / 256,
            height: 1,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()

        // Track GPU time
        let startTime = CACurrentMediaTime()

        commandBuffer.addCompletedHandler { [weak self] _ in
            let endTime = CACurrentMediaTime()
            Task { @MainActor in
                self?.gpuTime = (endTime - startTime) * 1000.0  // Convert to ms
            }
        }

        commandBuffer.commit()

        // Track FPS
        trackFPS()
    }

    // MARK: - Render to Texture

    func renderToTexture(texture: MTLTexture) {
        guard let pipeline = renderPipeline,
              let particleBuffer = particleBuffer else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load  // Don't clear, overlay on existing
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes([screenSize], length: MemoryLayout<SIMD2<Float>>.stride, index: 1)

        // Draw all particles as points
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

        renderEncoder.endEncoding()
        commandBuffer.commit()
    }

    // MARK: - Render to MTKView

    func render(in view: MTKView, biometrics: BiometricData) {
        guard let drawable = view.currentDrawable,
              let pipeline = renderPipeline,
              let particleBuffer = particleBuffer else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes([screenSize], length: MemoryLayout<SIMD2<Float>>.stride, index: 1)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Control

    func start() {
        isRunning = true
        lastUpdateTime = CACurrentMediaTime()
        fpsUpdateTime = lastUpdateTime
        print("▶️ MetalParticleEngine: Started")
    }

    func stop() {
        isRunning = false
        print("⏹️ MetalParticleEngine: Stopped")
    }

    func setParticleCount(_ count: Int) {
        guard count > 0 && count <= 1_000_000 else {
            print("⚠️ Particle count must be 1-1,000,000")
            return
        }

        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        particleCount = count
        setupBuffers()

        if wasRunning {
            start()
        }

        print("🔄 Particle count set to \(count)")
    }

    func setScreenSize(width: Float, height: Float) {
        screenSize = SIMD2<Float>(width, height)
        print("📐 Screen size set to \(width)x\(height)")
    }

    // MARK: - FPS Tracking

    private func trackFPS() {
        frameCount += 1

        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - fpsUpdateTime

        if elapsed >= 1.0 {
            actualFPS = Double(frameCount) / elapsed
            frameCount = 0
            fpsUpdateTime = currentTime
        }
    }

    // MARK: - Advanced Mode

    func enableAdvancedMode() {
        guard let advancedPipeline = updateAdvancedPipeline else {
            print("⚠️ Advanced pipeline not available")
            return
        }

        updatePipeline = advancedPipeline
        print("✨ Advanced particle physics enabled (flocking, vortex)")
    }

    func disableAdvancedMode() {
        setupPipelines()  // Reset to basic pipeline
        print("✨ Basic particle physics enabled")
    }
}

// MARK: - MTKViewDelegate

extension MetalParticleEngine: MTKViewDelegate {

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        Task { @MainActor in
            setScreenSize(width: Float(size.width), height: Float(size.height))
        }
    }

    nonisolated func draw(in view: MTKView) {
        Task { @MainActor in
            let currentTime = CACurrentMediaTime()
            let deltaTime = Float(currentTime - lastUpdateTime)
            lastUpdateTime = currentTime

            // Update particles
            update(deltaTime: deltaTime, biometrics: currentBiometrics)

            // Render particles
            render(in: view, biometrics: currentBiometrics)
        }
    }
}
