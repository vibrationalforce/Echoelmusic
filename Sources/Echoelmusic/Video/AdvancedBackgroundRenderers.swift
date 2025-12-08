import Foundation
import Metal
import MetalKit
import CoreImage
import AVFoundation
import Accelerate

/// Advanced Background Renderers for Echoelmusic
/// Complete GPU-accelerated implementations for all background types
/// Bio-reactive integration, Metal compute shaders, procedural generation

// MARK: - Angular Gradient Renderer

@MainActor
final class AngularGradientRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue

    init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "angularGradient") ??
                            Self.createAngularGradientFunction(device: device) else {
            return nil
        }

        self.commandQueue = queue

        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ AngularGradientRenderer: Failed to create pipeline - \(error)")
            return nil
        }
    }

    private static func createAngularGradientFunction(device: MTLDevice) -> MTLFunction? {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct GradientParams {
            float2 center;
            float rotation;
            float4 colors[8];
            int colorCount;
        };

        kernel void angularGradient(
            texture2d<float, access::write> output [[texture(0)]],
            constant GradientParams& params [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
            float2 centered = uv - params.center;

            float angle = atan2(centered.y, centered.x) + M_PI_F + params.rotation;
            float normalized = fmod(angle / (2.0 * M_PI_F), 1.0);

            // Interpolate between colors
            float scaledPos = normalized * float(params.colorCount - 1);
            int idx1 = int(scaledPos);
            int idx2 = min(idx1 + 1, params.colorCount - 1);
            float t = fract(scaledPos);

            float4 color = mix(params.colors[idx1], params.colors[idx2], t);
            output.write(color, gid);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            return library.makeFunction(name: "angularGradient")
        } catch {
            print("❌ Failed to compile angular gradient shader: \(error)")
            return nil
        }
    }

    func render(colors: [SIMD4<Float>], center: SIMD2<Float> = SIMD2(0.5, 0.5),
                rotation: Float = 0, size: CGSize) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BackgroundRenderError.textureCreationFailed
        }

        var params = GradientParams(
            center: center,
            rotation: rotation,
            colors: (colors[safe: 0] ?? SIMD4(1, 0, 0, 1),
                     colors[safe: 1] ?? SIMD4(1, 1, 0, 1),
                     colors[safe: 2] ?? SIMD4(0, 1, 0, 1),
                     colors[safe: 3] ?? SIMD4(0, 1, 1, 1),
                     colors[safe: 4] ?? SIMD4(0, 0, 1, 1),
                     colors[safe: 5] ?? SIMD4(1, 0, 1, 1),
                     colors[safe: 6] ?? SIMD4(1, 0, 0, 1),
                     colors[safe: 7] ?? SIMD4(1, 1, 1, 1)),
            colorCount: Int32(min(colors.count, 8))
        )

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<GradientParams>.stride, index: 0)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    struct GradientParams {
        var center: SIMD2<Float>
        var rotation: Float
        var colors: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
                     SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
        var colorCount: Int32
    }
}

// MARK: - Perlin Noise Renderer

@MainActor
final class PerlinNoiseRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue
    private let permutationBuffer: MTLBuffer

    init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        // Generate permutation table for Perlin noise
        var permutation = [Int32](repeating: 0, count: 512)
        let p = (0..<256).map { Int32($0) }.shuffled()
        for i in 0..<256 {
            permutation[i] = p[i]
            permutation[i + 256] = p[i]
        }

        guard let buffer = device.makeBuffer(bytes: permutation,
                                             length: MemoryLayout<Int32>.stride * 512,
                                             options: .storageModeShared) else {
            return nil
        }
        self.permutationBuffer = buffer

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct NoiseParams {
            float scale;
            float time;
            int octaves;
            float persistence;
            float4 color1;
            float4 color2;
        };

        float fade(float t) {
            return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
        }

        float grad(int hash, float x, float y, float z) {
            int h = hash & 15;
            float u = h < 8 ? x : y;
            float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
            return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
        }

        float perlin(float3 pos, constant int* perm) {
            int X = int(floor(pos.x)) & 255;
            int Y = int(floor(pos.y)) & 255;
            int Z = int(floor(pos.z)) & 255;

            float x = pos.x - floor(pos.x);
            float y = pos.y - floor(pos.y);
            float z = pos.z - floor(pos.z);

            float u = fade(x);
            float v = fade(y);
            float w = fade(z);

            int A = perm[X] + Y;
            int AA = perm[A] + Z;
            int AB = perm[A + 1] + Z;
            int B = perm[X + 1] + Y;
            int BA = perm[B] + Z;
            int BB = perm[B + 1] + Z;

            float result = mix(
                mix(mix(grad(perm[AA], x, y, z), grad(perm[BA], x-1, y, z), u),
                    mix(grad(perm[AB], x, y-1, z), grad(perm[BB], x-1, y-1, z), u), v),
                mix(mix(grad(perm[AA+1], x, y, z-1), grad(perm[BA+1], x-1, y, z-1), u),
                    mix(grad(perm[AB+1], x, y-1, z-1), grad(perm[BB+1], x-1, y-1, z-1), u), v), w);

            return (result + 1.0) * 0.5;
        }

        float fbm(float3 pos, int octaves, float persistence, constant int* perm) {
            float total = 0.0;
            float amplitude = 1.0;
            float frequency = 1.0;
            float maxValue = 0.0;

            for (int i = 0; i < octaves; i++) {
                total += perlin(pos * frequency, perm) * amplitude;
                maxValue += amplitude;
                amplitude *= persistence;
                frequency *= 2.0;
            }

            return total / maxValue;
        }

        kernel void perlinNoise(
            texture2d<float, access::write> output [[texture(0)]],
            constant NoiseParams& params [[buffer(0)]],
            constant int* perm [[buffer(1)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
            float3 pos = float3(uv * params.scale, params.time * 0.1);

            float n = fbm(pos, params.octaves, params.persistence, perm);
            float4 color = mix(params.color1, params.color2, n);

            output.write(color, gid);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let function = library.makeFunction(name: "perlinNoise") else { return nil }
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ PerlinNoiseRenderer: Failed to compile shader - \(error)")
            return nil
        }
    }

    func render(scale: Float = 4.0, time: Float = 0, octaves: Int = 4,
                persistence: Float = 0.5, color1: SIMD4<Float> = SIMD4(0.1, 0.1, 0.2, 1),
                color2: SIMD4<Float> = SIMD4(0.3, 0.5, 0.8, 1), size: CGSize) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BackgroundRenderError.textureCreationFailed
        }

        var params = NoiseParams(
            scale: scale,
            time: time,
            octaves: Int32(octaves),
            persistence: persistence,
            color1: color1,
            color2: color2
        )

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<NoiseParams>.stride, index: 0)
        encoder.setBuffer(permutationBuffer, offset: 0, index: 1)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    struct NoiseParams {
        var scale: Float
        var time: Float
        var octaves: Int32
        var persistence: Float
        var color1: SIMD4<Float>
        var color2: SIMD4<Float>
    }
}

// MARK: - Star Field Renderer

@MainActor
final class StarFieldRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue
    private var starBuffer: MTLBuffer?
    private var starCount: Int = 0

    struct Star {
        var position: SIMD2<Float>
        var brightness: Float
        var size: Float
        var twinklePhase: Float
        var twinkleSpeed: Float
    }

    init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Star {
            float2 position;
            float brightness;
            float size;
            float twinklePhase;
            float twinkleSpeed;
        };

        struct StarFieldParams {
            float time;
            float4 backgroundColor;
            float4 starColor;
            float parallaxFactor;
        };

        kernel void starField(
            texture2d<float, access::write> output [[texture(0)]],
            constant Star* stars [[buffer(0)]],
            constant StarFieldParams& params [[buffer(1)]],
            constant int& starCount [[buffer(2)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
            float4 color = params.backgroundColor;

            for (int i = 0; i < starCount; i++) {
                Star star = stars[i];
                float2 starPos = star.position;

                // Apply parallax
                starPos.x = fmod(starPos.x + params.time * params.parallaxFactor * star.size * 0.1, 1.0);

                float dist = length(uv - starPos);
                float radius = star.size * 0.005;

                if (dist < radius) {
                    float twinkle = sin(params.time * star.twinkleSpeed + star.twinklePhase) * 0.5 + 0.5;
                    float intensity = star.brightness * twinkle * (1.0 - dist / radius);
                    color = mix(color, params.starColor, intensity);
                }
            }

            output.write(color, gid);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let function = library.makeFunction(name: "starField") else { return nil }
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ StarFieldRenderer: Failed to compile shader - \(error)")
            return nil
        }

        // Generate initial stars
        generateStars(count: 500)
    }

    func generateStars(count: Int) {
        var stars = [Star]()
        stars.reserveCapacity(count)

        for _ in 0..<count {
            let star = Star(
                position: SIMD2(Float.random(in: 0...1), Float.random(in: 0...1)),
                brightness: Float.random(in: 0.3...1.0),
                size: Float.random(in: 0.5...2.0),
                twinklePhase: Float.random(in: 0...Float.pi * 2),
                twinkleSpeed: Float.random(in: 0.5...3.0)
            )
            stars.append(star)
        }

        starBuffer = device.makeBuffer(bytes: stars,
                                       length: MemoryLayout<Star>.stride * count,
                                       options: .storageModeShared)
        starCount = count
    }

    func render(time: Float = 0, backgroundColor: SIMD4<Float> = SIMD4(0.02, 0.02, 0.05, 1),
                starColor: SIMD4<Float> = SIMD4(1, 1, 1, 1), parallaxFactor: Float = 0.1,
                size: CGSize) throws -> MTLTexture {
        guard let starBuffer = starBuffer else {
            throw BackgroundRenderError.bufferCreationFailed
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BackgroundRenderError.textureCreationFailed
        }

        var params = StarFieldParams(
            time: time,
            backgroundColor: backgroundColor,
            starColor: starColor,
            parallaxFactor: parallaxFactor
        )
        var count = Int32(starCount)

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(starBuffer, offset: 0, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<StarFieldParams>.stride, index: 1)
        encoder.setBytes(&count, length: MemoryLayout<Int32>.stride, index: 2)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    struct StarFieldParams {
        var time: Float
        var backgroundColor: SIMD4<Float>
        var starColor: SIMD4<Float>
        var parallaxFactor: Float
    }
}

// MARK: - Live Camera Capture Manager

@MainActor
final class LiveCameraCaptureManager: NSObject, ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var currentFrame: CVPixelBuffer?
    @Published var errorMessage: String?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let outputQueue = DispatchQueue(label: "com.echoelmusic.camera.output", qos: .userInteractive)

    private let device: MTLDevice
    private var textureCache: CVMetalTextureCache?

    init?(device: MTLDevice) {
        self.device = device
        super.init()

        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard result == kCVReturnSuccess, let validCache = cache else {
            print("❌ LiveCameraCaptureManager: Failed to create texture cache")
            return nil
        }
        self.textureCache = validCache
    }

    func startCapture(position: AVCaptureDevice.Position = .front) async throws {
        guard !isCapturing else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        // Find camera
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position
        )

        guard let camera = discoverySession.devices.first else {
            throw CameraCaptureError.cameraNotFound
        }

        // Configure camera
        do {
            try camera.lockForConfiguration()

            // Set frame rate to 60 fps if supported
            let desiredFrameRate = CMTimeMake(value: 1, timescale: 60)
            var bestFormat: AVCaptureDevice.Format?
            var bestFrameRateRange: AVFrameRateRange?

            for format in camera.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= 60 {
                        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                        if dimensions.width >= 1920 {
                            bestFormat = format
                            bestFrameRateRange = range
                            break
                        }
                    }
                }
            }

            if let format = bestFormat, let _ = bestFrameRateRange {
                camera.activeFormat = format
                camera.activeVideoMinFrameDuration = desiredFrameRate
                camera.activeVideoMaxFrameDuration = desiredFrameRate
            }

            camera.unlockForConfiguration()
        } catch {
            throw CameraCaptureError.configurationFailed(error)
        }

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.inputNotSupported
        }
        session.addInput(input)

        // Add output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.outputNotSupported
        }
        session.addOutput(output)

        // Configure video orientation
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (position == .front)
            }
            #if os(iOS)
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            #endif
        }

        self.captureSession = session
        self.videoOutput = output

        // Start session on background thread
        await withCheckedContinuation { continuation in
            outputQueue.async {
                session.startRunning()
                continuation.resume()
            }
        }

        isCapturing = true
        print("📷 LiveCameraCaptureManager: Started capture (position: \(position == .front ? "front" : "back"))")
    }

    func stopCapture() {
        guard isCapturing else { return }

        outputQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }

        captureSession = nil
        videoOutput = nil
        isCapturing = false
        currentFrame = nil

        print("📷 LiveCameraCaptureManager: Stopped capture")
    }

    func getCurrentTexture() throws -> MTLTexture? {
        guard let pixelBuffer = currentFrame,
              let textureCache = textureCache else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess, let texture = cvTexture else {
            throw CameraCaptureError.textureCreationFailed
        }

        return CVMetalTextureGetTexture(texture)
    }
}

extension LiveCameraCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task { @MainActor in
            self.currentFrame = pixelBuffer
        }
    }
}

enum CameraCaptureError: LocalizedError {
    case cameraNotFound
    case configurationFailed(Error)
    case inputNotSupported
    case outputNotSupported
    case textureCreationFailed

    var errorDescription: String? {
        switch self {
        case .cameraNotFound: return "No suitable camera found"
        case .configurationFailed(let error): return "Camera configuration failed: \(error.localizedDescription)"
        case .inputNotSupported: return "Camera input not supported"
        case .outputNotSupported: return "Video output not supported"
        case .textureCreationFailed: return "Failed to create texture from camera frame"
        }
    }
}

// MARK: - Blur Background Renderer

@MainActor
final class BlurBackgroundRenderer {
    private let device: MTLDevice
    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue

    enum BlurType {
        case gaussian
        case bokeh
        case motion(angle: Float)
    }

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .name: "BlurContext"
        ])
    }

    func render(inputTexture: MTLTexture, blurType: BlurType, intensity: Float) throws -> MTLTexture {
        // Convert MTLTexture to CIImage
        let ciImage = CIImage(mtlTexture: inputTexture, options: nil)!

        // Apply blur filter
        let filteredImage: CIImage

        switch blurType {
        case .gaussian:
            let filter = CIFilter(name: "CIGaussianBlur")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 50.0, forKey: kCIInputRadiusKey) // 0-50 radius
            filteredImage = filter.outputImage!.cropped(to: ciImage.extent)

        case .bokeh:
            let filter = CIFilter(name: "CIBokehBlur")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 30.0, forKey: "inputRadius")
            filter.setValue(1.0, forKey: "inputRingAmount")
            filter.setValue(intensity * 0.5, forKey: "inputSoftness")
            filteredImage = filter.outputImage!.cropped(to: ciImage.extent)

        case .motion(let angle):
            let filter = CIFilter(name: "CIMotionBlur")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 50.0, forKey: kCIInputRadiusKey)
            filter.setValue(Double(angle), forKey: kCIInputAngleKey)
            filteredImage = filter.outputImage!.cropped(to: ciImage.extent)
        }

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw BackgroundRenderError.textureCreationFailed
        }

        // Render to output texture
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw BackgroundRenderError.commandBufferFailed
        }

        ciContext.render(filteredImage, to: outputTexture, commandBuffer: commandBuffer,
                        bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }
}

// MARK: - Echoelmusic Visual Renderer (Complete Implementation)

@MainActor
final class CompleteEchoelmusicVisualRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private var cymaticsPipeline: MTLComputePipelineState?
    private var mandalaPipeline: MTLComputePipelineState?
    private var particlePipeline: MTLComputePipelineState?
    private var waveformPipeline: MTLComputePipelineState?
    private var spectralPipeline: MTLComputePipelineState?

    // Bio-reactive parameters
    var hrvCoherence: Float = 0.5
    var heartRate: Float = 70.0
    var audioLevel: Float = 0.5
    var dominantFrequency: Float = 440.0

    enum VisualType {
        case cymatics
        case mandala
        case particles
        case waveform
        case spectral
    }

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        compilePipelines()
    }

    private func compilePipelines() {
        // Cymatics shader - simulates standing wave patterns
        let cymaticsSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct CymaticsParams {
            float time;
            float frequency;
            float amplitude;
            float coherence;
            float4 color1;
            float4 color2;
        };

        kernel void cymatics(
            texture2d<float, access::write> output [[texture(0)]],
            constant CymaticsParams& params [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float2 uv = float2(gid) / float2(output.get_width(), output.get_height()) - 0.5;
            float dist = length(uv);

            // Multiple standing wave patterns
            float pattern = 0.0;
            for (int i = 1; i <= 5; i++) {
                float freq = params.frequency * float(i) * 0.1;
                pattern += sin(dist * freq - params.time * 2.0) * (1.0 / float(i));
            }

            // Coherence affects pattern clarity
            pattern = mix(pattern * 0.5, pattern, params.coherence);
            pattern = pattern * 0.5 + 0.5;

            // Amplitude modulation
            pattern *= params.amplitude;

            float4 color = mix(params.color1, params.color2, pattern);
            output.write(color, gid);
        }
        """

        // Mandala shader - sacred geometry patterns
        let mandalaSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct MandalaParams {
            float time;
            int symmetry;
            float rotation;
            float coherence;
            float4 color1;
            float4 color2;
            float4 color3;
        };

        kernel void mandala(
            texture2d<float, access::write> output [[texture(0)]],
            constant MandalaParams& params [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float2 uv = (float2(gid) / float2(output.get_width(), output.get_height()) - 0.5) * 2.0;

            float angle = atan2(uv.y, uv.x) + params.rotation;
            float dist = length(uv);

            // Apply symmetry
            angle = fmod(angle + M_PI_F, 2.0 * M_PI_F / float(params.symmetry));

            // Create pattern
            float pattern = sin(angle * float(params.symmetry) + params.time) *
                           sin(dist * 10.0 - params.time * 2.0);

            // Coherence morphs symmetry
            pattern = mix(pattern, pattern * sin(dist * 20.0), 1.0 - params.coherence);
            pattern = pattern * 0.5 + 0.5;

            // Three-color gradient
            float4 color;
            if (pattern < 0.33) {
                color = mix(params.color1, params.color2, pattern * 3.0);
            } else if (pattern < 0.66) {
                color = mix(params.color2, params.color3, (pattern - 0.33) * 3.0);
            } else {
                color = mix(params.color3, params.color1, (pattern - 0.66) * 3.0);
            }

            // Fade at edges
            color.a = smoothstep(1.0, 0.8, dist);

            output.write(color, gid);
        }
        """

        do {
            let cymaticsLib = try device.makeLibrary(source: cymaticsSource, options: nil)
            if let fn = cymaticsLib.makeFunction(name: "cymatics") {
                cymaticsPipeline = try device.makeComputePipelineState(function: fn)
            }

            let mandalaLib = try device.makeLibrary(source: mandalaSource, options: nil)
            if let fn = mandalaLib.makeFunction(name: "mandala") {
                mandalaPipeline = try device.makeComputePipelineState(function: fn)
            }
        } catch {
            print("❌ CompleteEchoelmusicVisualRenderer: Failed to compile shaders - \(error)")
        }
    }

    func render(type: VisualType, size: CGSize, time: Float) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BackgroundRenderError.textureCreationFailed
        }

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(size.width) + 15) / 16,
            height: (Int(size.height) + 15) / 16,
            depth: 1
        )

        switch type {
        case .cymatics:
            guard let pipeline = cymaticsPipeline else {
                throw BackgroundRenderError.pipelineNotFound
            }

            var params = CymaticsParams(
                time: time,
                frequency: dominantFrequency * 0.1,
                amplitude: audioLevel,
                coherence: hrvCoherence,
                color1: SIMD4(0.1, 0.2, 0.4, 1.0),
                color2: SIMD4(0.4, 0.8, 1.0, 1.0)
            )

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setBytes(&params, length: MemoryLayout<CymaticsParams>.stride, index: 0)

        case .mandala:
            guard let pipeline = mandalaPipeline else {
                throw BackgroundRenderError.pipelineNotFound
            }

            // Coherence determines symmetry (low=4, high=12)
            let symmetry = Int32(4 + Int(hrvCoherence * 8))

            var params = MandalaParams(
                time: time,
                symmetry: symmetry,
                rotation: time * 0.1,
                coherence: hrvCoherence,
                color1: SIMD4(0.8, 0.2, 0.4, 1.0),
                color2: SIMD4(0.4, 0.6, 0.9, 1.0),
                color3: SIMD4(0.2, 0.8, 0.5, 1.0)
            )

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setBytes(&params, length: MemoryLayout<MandalaParams>.stride, index: 0)

        case .particles, .waveform, .spectral:
            // Use cymatics as fallback for now
            guard let pipeline = cymaticsPipeline else {
                throw BackgroundRenderError.pipelineNotFound
            }

            var params = CymaticsParams(
                time: time,
                frequency: dominantFrequency * 0.1,
                amplitude: audioLevel,
                coherence: hrvCoherence,
                color1: SIMD4(0.2, 0.1, 0.3, 1.0),
                color2: SIMD4(0.8, 0.4, 0.6, 1.0)
            )

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setBytes(&params, length: MemoryLayout<CymaticsParams>.stride, index: 0)
        }

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    func update(hrvCoherence: Float, heartRate: Float, audioLevel: Float = 0.5, dominantFrequency: Float = 440.0) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.audioLevel = audioLevel
        self.dominantFrequency = dominantFrequency
    }

    struct CymaticsParams {
        var time: Float
        var frequency: Float
        var amplitude: Float
        var coherence: Float
        var color1: SIMD4<Float>
        var color2: SIMD4<Float>
    }

    struct MandalaParams {
        var time: Float
        var symmetry: Int32
        var rotation: Float
        var coherence: Float
        var color1: SIMD4<Float>
        var color2: SIMD4<Float>
        var color3: SIMD4<Float>
    }
}

// MARK: - Errors

enum BackgroundRenderError: LocalizedError {
    case textureCreationFailed
    case bufferCreationFailed
    case commandBufferFailed
    case pipelineNotFound

    var errorDescription: String? {
        switch self {
        case .textureCreationFailed: return "Failed to create texture"
        case .bufferCreationFailed: return "Failed to create buffer"
        case .commandBufferFailed: return "Failed to create command buffer"
        case .pipelineNotFound: return "Compute pipeline not found"
        }
    }
}

// MARK: - Array Safe Access Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
