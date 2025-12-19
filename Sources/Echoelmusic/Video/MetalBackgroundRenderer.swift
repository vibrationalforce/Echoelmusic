//
//  MetalBackgroundRenderer.swift
//  Echoelmusic
//
//  Metal-accelerated background effect renderer
//  Bridges Swift to Metal shaders in BackgroundEffects.metal
//

import Foundation
import Metal
import CoreImage
import MetalKit

/// Metal-accelerated background renderer
@available(iOS 14.0, macOS 11.0, *)
class MetalBackgroundRenderer {

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    // Pipeline states
    private var angularGradientPipeline: MTLComputePipelineState?
    private var perlinNoisePipeline: MTLComputePipelineState?
    private var starParticlesPipeline: MTLComputePipelineState?
    private var starParticlesFastPipeline: MTLComputePipelineState?

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.library = library

        compileShaders()
    }

    private func compileShaders() {
        do {
            // Angular Gradient
            if let function = library.makeFunction(name: "angularGradient") {
                angularGradientPipeline = try device.makeComputePipelineState(function: function)
            }

            // Perlin Noise
            if let function = library.makeFunction(name: "perlinNoiseBackground") {
                perlinNoisePipeline = try device.makeComputePipelineState(function: function)
            }

            // Star Particles
            if let function = library.makeFunction(name: "starParticles") {
                starParticlesPipeline = try device.makeComputePipelineState(function: function)
            }

            // Star Particles (Fast)
            if let function = library.makeFunction(name: "starParticlesFast") {
                starParticlesFastPipeline = try device.makeComputePipelineState(function: function)
            }

        } catch {
            print("❌ Failed to compile Metal shaders: \(error)")
        }
    }

    // MARK: - Angular Gradient

    struct AngularGradientParams {
        var center: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var rotation: Float = 0.0
        var colorCount: UInt32 = 0
        var colors: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
                     SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) =
            (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
        var positions: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0, 0, 0, 0, 0, 0, 0, 0)
    }

    func renderAngularGradient(
        colors: [SIMD4<Float>],
        positions: [Float]? = nil,
        center: SIMD2<Float> = SIMD2<Float>(0.5, 0.5),
        rotation: Float = 0.0,
        size: CGSize
    ) -> CIImage? {
        guard let pipeline = angularGradientPipeline else { return nil }

        // Create output texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Prepare parameters
        var params = AngularGradientParams()
        params.center = center
        params.rotation = rotation
        params.colorCount = UInt32(min(colors.count, 8))

        // Fill color arrays
        let colorArray = [colors[0], colors[1], colors[2], colors[3],
                          colors[4], colors[5], colors[6], colors[7]]
        params.colors = (colorArray[0], colorArray[1], colorArray[2], colorArray[3],
                         colorArray[4], colorArray[5], colorArray[6], colorArray[7])

        // Fill position arrays (default: evenly spaced)
        let posArray: [Float]
        if let positions = positions, positions.count == colors.count {
            posArray = positions + Array(repeating: 0.0, count: 8 - positions.count)
        } else {
            posArray = (0..<8).map { colors.count > 1 ? Float($0) / Float(colors.count - 1) : 0.0 }
        }
        params.positions = (posArray[0], posArray[1], posArray[2], posArray[3],
                            posArray[4], posArray[5], posArray[6], posArray[7])

        // Dispatch compute shader
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<AngularGradientParams>.size, index: 0)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert MTLTexture to CIImage
        return CIImage(mtlTexture: outputTexture, options: nil)
    }

    // MARK: - Perlin Noise

    struct PerlinNoiseParams {
        var scale: Float = 5.0
        var octaves: UInt32 = 4
        var persistence: Float = 0.5
        var lacunarity: Float = 2.0
        var time: Float = 0.0
        var speed: Float = 1.0
    }

    func renderPerlinNoise(
        scale: Float = 5.0,
        octaves: UInt32 = 4,
        persistence: Float = 0.5,
        lacunarity: Float = 2.0,
        time: Float = 0.0,
        speed: Float = 1.0,
        size: CGSize
    ) -> CIImage? {
        guard let pipeline = perlinNoisePipeline else { return nil }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        var params = PerlinNoiseParams(
            scale: scale,
            octaves: octaves,
            persistence: persistence,
            lacunarity: lacunarity,
            time: time,
            speed: speed
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<PerlinNoiseParams>.size, index: 0)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return CIImage(mtlTexture: outputTexture, options: nil)
    }

    // MARK: - Star Particles

    struct StarParticlesParams {
        var starCount: UInt32 = 100
        var time: Float = 0.0
        var twinkleSpeed: Float = 2.0
        var minSize: Float = 1.0
        var maxSize: Float = 3.0
        var minBrightness: Float = 0.3
        var maxBrightness: Float = 1.0
        var starColor: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    }

    func renderStarParticles(
        starCount: UInt32 = 100,
        time: Float = 0.0,
        twinkleSpeed: Float = 2.0,
        minSize: Float = 1.0,
        maxSize: Float = 3.0,
        minBrightness: Float = 0.3,
        maxBrightness: Float = 1.0,
        starColor: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
        size: CGSize,
        useFastPath: Bool = true
    ) -> CIImage? {
        // Use fast path for > 200 stars
        let pipeline = (useFastPath && starCount > 200) ? starParticlesFastPipeline : starParticlesPipeline
        guard let pipeline = pipeline else { return nil }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        var params = StarParticlesParams(
            starCount: starCount,
            time: time,
            twinkleSpeed: twinkleSpeed,
            minSize: minSize,
            maxSize: maxSize,
            minBrightness: minBrightness,
            maxBrightness: maxBrightness,
            starColor: starColor
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<StarParticlesParams>.size, index: 0)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return CIImage(mtlTexture: outputTexture, options: nil)
    }
}

// MARK: - Convenience Extensions

@available(iOS 14.0, macOS 11.0, *)
extension MetalBackgroundRenderer {

    /// Convert SwiftUI Color to SIMD4<Float> (Metal format)
    static func colorToFloat4(_ color: CGColor) -> SIMD4<Float> {
        guard let components = color.components, components.count >= 3 else {
            return SIMD4<Float>(0, 0, 0, 1)
        }

        return SIMD4<Float>(
            Float(components[0]),
            Float(components[1]),
            Float(components[2]),
            components.count > 3 ? Float(components[3]) : 1.0
        )
    }
}
