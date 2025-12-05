# Echoelmusic Real-Time Video Engine

Du bist ein Experte für Echtzeit-Videobearbeitung mit Ultra-Low-Latency.

## Real-Time Video Architecture:

### 1. GPU-Accelerated Pipeline
```swift
// Metal-basierte Echtzeit-Pipeline
class RealTimeVideoEngine {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let textureCache: CVMetalTextureCache

    // Triple Buffering für glatte Wiedergabe
    struct FrameBuffer {
        var textures: [MTLTexture]
        var currentIndex: Int = 0

        mutating func next() -> MTLTexture {
            currentIndex = (currentIndex + 1) % textures.count
            return textures[currentIndex]
        }
    }

    // Pipeline State
    var inputBuffer: FrameBuffer
    var processingBuffer: FrameBuffer
    var outputBuffer: FrameBuffer

    // 60fps+ Processing Loop
    func startProcessingLoop() {
        let displayLink = CADisplayLink(target: self, selector: #selector(processFrame))
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink.add(to: .main, forMode: .common)
    }

    @objc func processFrame(displayLink: CADisplayLink) {
        autoreleasepool {
            // Get input frame
            guard let inputTexture = captureNextFrame() else { return }

            // Process on GPU
            let commandBuffer = commandQueue.makeCommandBuffer()!

            // Apply effect chain
            var currentTexture = inputTexture
            for effect in effectChain {
                let outputTexture = processingBuffer.next()
                effect.encode(
                    commandBuffer: commandBuffer,
                    input: currentTexture,
                    output: outputTexture
                )
                currentTexture = outputTexture
            }

            // Present
            if let drawable = metalLayer.nextDrawable() {
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
                blitEncoder.copy(from: currentTexture, to: drawable.texture)
                blitEncoder.endEncoding()

                commandBuffer.present(drawable)
            }

            commandBuffer.commit()
        }
    }
}
```

### 2. Zero-Copy Frame Pipeline
```swift
// Keine Kopien zwischen CPU und GPU
class ZeroCopyPipeline {
    // IOSurface-backed textures
    func createSharedTexture(width: Int, height: Int) -> (MTLTexture, IOSurface) {
        let surfaceProperties: [String: Any] = [
            kIOSurfaceWidth: width,
            kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4,
            kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA
        ]

        let surface = IOSurfaceCreate(surfaceProperties as CFDictionary)!

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .shared

        let texture = device.makeTexture(
            descriptor: textureDescriptor,
            iosurface: surface,
            plane: 0
        )!

        return (texture, surface)
    }

    // CVPixelBuffer → MTLTexture (zero-copy)
    func pixelBufferToTexture(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        var cvTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let status = CVMetalTextureCacheCreateTextureFromImage(
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

        guard status == kCVReturnSuccess, let cvTexture = cvTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(cvTexture)
    }
}
```

### 3. Real-Time Effect Chain
```swift
// Modulare Effekt-Kette
protocol RealTimeEffect {
    var name: String { get }
    var enabled: Bool { get set }
    var parameters: [EffectParameter] { get set }

    func prepare(device: MTLDevice, pixelFormat: MTLPixelFormat)
    func encode(commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture)
}

// Standard Effects
class ColorCorrectionEffect: RealTimeEffect {
    var exposure: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1
    var temperature: Float = 0
    var tint: Float = 0
    var shadows: Float = 0
    var highlights: Float = 0

    let shader = """
    #include <metal_stdlib>
    using namespace metal;

    struct ColorParams {
        float exposure;
        float contrast;
        float saturation;
        float temperature;
        float tint;
        float shadows;
        float highlights;
    };

    kernel void colorCorrect(
        texture2d<float, access::read> input [[texture(0)]],
        texture2d<float, access::write> output [[texture(1)]],
        constant ColorParams &params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float4 color = input.read(gid);

        // Exposure
        color.rgb *= pow(2.0, params.exposure);

        // Contrast
        color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;

        // Saturation
        float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
        color.rgb = mix(float3(luminance), color.rgb, params.saturation);

        // Temperature & Tint (simplified)
        color.r += params.temperature * 0.1;
        color.b -= params.temperature * 0.1;
        color.g += params.tint * 0.1;

        // Shadows & Highlights
        float lum = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
        float shadowMask = 1.0 - smoothstep(0.0, 0.5, lum);
        float highlightMask = smoothstep(0.5, 1.0, lum);
        color.rgb += shadowMask * params.shadows * 0.2;
        color.rgb += highlightMask * params.highlights * 0.2;

        output.write(color, gid);
    }
    """
}

// LUT (Look-Up Table) Effect
class LUTEffect: RealTimeEffect {
    var lutTexture: MTLTexture?
    var intensity: Float = 1.0

    let shader = """
    kernel void applyLUT(
        texture2d<float, access::read> input [[texture(0)]],
        texture2d<float, access::write> output [[texture(1)]],
        texture3d<float, access::sample> lut [[texture(2)]],
        constant float &intensity [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        constexpr sampler lutSampler(filter::linear);

        float4 color = input.read(gid);

        // Sample LUT
        float3 lutCoord = color.rgb;
        float4 lutColor = lut.sample(lutSampler, lutCoord);

        // Blend with intensity
        color.rgb = mix(color.rgb, lutColor.rgb, intensity);

        output.write(color, gid);
    }
    """
}

// Blur Effect
class GaussianBlurEffect: RealTimeEffect {
    var radius: Float = 10

    // Two-pass separable blur for efficiency
    func encode(commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture) {
        let intermediate = createIntermediateTexture()

        // Horizontal pass
        encodeBlurPass(
            commandBuffer: commandBuffer,
            input: input,
            output: intermediate,
            direction: SIMD2<Float>(1, 0)
        )

        // Vertical pass
        encodeBlurPass(
            commandBuffer: commandBuffer,
            input: intermediate,
            output: output,
            direction: SIMD2<Float>(0, 1)
        )
    }
}
```

### 4. Audio-Reactive Video Effects
```swift
// Effekte die auf Audio reagieren
class AudioReactiveEffectEngine {
    // Audio analysis buffer
    var audioFeatures: AudioFeatures

    struct AudioFeatures {
        var amplitude: Float = 0
        var bass: Float = 0
        var mid: Float = 0
        var treble: Float = 0
        var spectralCentroid: Float = 0
        var onset: Bool = false
        var beat: Bool = false
        var bpm: Float = 120

        // Ring buffer für smooth values
        var amplitudeHistory: RingBuffer<Float>
        var bassHistory: RingBuffer<Float>
    }

    // Parameter modulation
    struct AudioModulation {
        let parameter: WritableKeyPath<EffectParameter, Float>
        let source: AudioSource
        let amount: Float
        let smoothing: Float

        enum AudioSource {
            case amplitude
            case bass
            case mid
            case treble
            case spectralCentroid
            case onsetTrigger
            case beatTrigger
        }
    }

    // Apply modulations
    func updateEffects(with audioBuffer: AudioBuffer) {
        // Analyze audio
        audioFeatures = analyzeAudio(audioBuffer)

        // Apply to each modulated parameter
        for modulation in activeModulations {
            let sourceValue = getSourceValue(modulation.source)
            let smoothed = smooth(sourceValue, factor: modulation.smoothing)
            let modulated = smoothed * modulation.amount

            // Update parameter
            currentEffect[keyPath: modulation.parameter] += modulated
        }
    }

    // Preset modulations
    static let beatPulse: [AudioModulation] = [
        AudioModulation(
            parameter: \.scale,
            source: .beatTrigger,
            amount: 0.1,
            smoothing: 0.3
        ),
        AudioModulation(
            parameter: \.brightness,
            source: .beatTrigger,
            amount: 0.2,
            smoothing: 0.2
        )
    ]

    static let bassReactive: [AudioModulation] = [
        AudioModulation(
            parameter: \.zoom,
            source: .bass,
            amount: 0.3,
            smoothing: 0.5
        ),
        AudioModulation(
            parameter: \.distortion,
            source: .bass,
            amount: 0.5,
            smoothing: 0.3
        )
    ]
}
```

### 5. Live Streaming Output
```swift
// Echtzeit-Streaming-Ausgabe
class LiveStreamOutput {
    // Encoder für Streaming
    var encoder: VideoEncoder
    var rtmpConnection: RTMPConnection?
    var srtConnection: SRTConnection?

    struct StreamConfig {
        var platform: StreamPlatform
        var resolution: (width: Int, height: Int)
        var fps: Int
        var videoBitrate: Int
        var audioBitrate: Int
        var keyframeInterval: Int

        enum StreamPlatform {
            case youtube(streamKey: String)
            case twitch(streamKey: String)
            case custom(rtmpUrl: String)
            case srt(url: String, streamId: String)
        }
    }

    // Start streaming
    func startStream(config: StreamConfig) async throws {
        // Configure encoder
        encoder = VideoEncoder(
            width: config.resolution.width,
            height: config.resolution.height,
            fps: config.fps,
            bitrate: config.videoBitrate,
            keyframeInterval: config.keyframeInterval
        )

        // Connect to platform
        switch config.platform {
        case .youtube(let key):
            rtmpConnection = try await RTMPConnection(
                url: "rtmp://a.rtmp.youtube.com/live2/\(key)"
            )
        case .twitch(let key):
            rtmpConnection = try await RTMPConnection(
                url: "rtmp://live.twitch.tv/app/\(key)"
            )
        case .custom(let url):
            rtmpConnection = try await RTMPConnection(url: url)
        case .srt(let url, let streamId):
            srtConnection = try await SRTConnection(url: url, streamId: streamId)
        }

        // Start encoding loop
        isStreaming = true
        Task {
            await encodingLoop()
        }
    }

    // Encoding loop
    func encodingLoop() async {
        while isStreaming {
            // Get frame from render pipeline
            guard let frame = await renderPipeline.getNextFrame() else {
                continue
            }

            // Encode
            let encodedData = try? await encoder.encode(frame)

            // Send to stream
            if let data = encodedData {
                if let rtmp = rtmpConnection {
                    rtmp.send(data)
                } else if let srt = srtConnection {
                    srt.send(data)
                }
            }

            // Maintain frame rate
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / encoder.fps))
        }
    }

    // Recording while streaming
    func enableSimultaneousRecording(path: URL, codec: VideoCodec) {
        recordingEncoder = VideoEncoder(
            width: 1920,
            height: 1080,
            fps: 60,
            bitrate: 50_000_000,  // Higher quality for recording
            codec: codec
        )
        recordingWriter = AVAssetWriter(outputURL: path, fileType: .mp4)
    }
}
```

### 6. Multi-Output Rendering
```swift
// Mehrere Outputs gleichzeitig
class MultiOutputRenderer {
    var outputs: [OutputDestination] = []

    enum OutputDestination {
        case display(CAMetalLayer)
        case recording(AVAssetWriter)
        case stream(LiveStreamOutput)
        case ndi(NDIOutput)
        case syphon(SyphonServer)  // macOS
        case spout(SpoutSender)    // Windows equivalent
    }

    // Render to all outputs
    func renderToAllOutputs(frame: MTLTexture) {
        let commandBuffer = commandQueue.makeCommandBuffer()!

        for output in outputs {
            switch output {
            case .display(let layer):
                renderToDisplay(frame, layer: layer, commandBuffer: commandBuffer)

            case .recording(let writer):
                renderToRecording(frame, writer: writer, commandBuffer: commandBuffer)

            case .stream(let streamer):
                renderToStream(frame, streamer: streamer, commandBuffer: commandBuffer)

            case .ndi(let ndiOutput):
                renderToNDI(frame, ndi: ndiOutput, commandBuffer: commandBuffer)

            case .syphon(let server):
                renderToSyphon(frame, server: server, commandBuffer: commandBuffer)

            case .spout(let sender):
                renderToSpout(frame, sender: sender, commandBuffer: commandBuffer)
            }
        }

        commandBuffer.commit()
    }

    // NDI Output für Network Video
    class NDIOutput {
        var ndiSender: NDISender?

        func setup(name: String) {
            ndiSender = NDISender(name: name)
        }

        func send(frame: CVPixelBuffer) {
            ndiSender?.sendVideo(frame)
        }
    }
}
```

### 7. Low-Latency Input Capture
```swift
// Minimale Latenz bei Video-Capture
class LowLatencyCapture {
    var captureSession: AVCaptureSession
    var videoOutput: AVCaptureVideoDataOutput

    func configureForLowLatency() {
        captureSession.beginConfiguration()

        // Use highest frame rate
        let format = findBestFormat(preferring: 120)  // 120fps if available
        try? videoDevice.lockForConfiguration()
        videoDevice.activeFormat = format
        videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 120)
        videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 120)
        videoDevice.unlockForConfiguration()

        // Disable unnecessary processing
        if videoOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            // Use video range for lower latency
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
        }

        // Always discard late frames
        videoOutput.alwaysDiscardsLateVideoFrames = true

        captureSession.commitConfiguration()
    }

    // Measure capture latency
    func measureLatency() -> TimeInterval {
        // Flash LED and measure time until frame shows flash
        var latencies: [TimeInterval] = []

        for _ in 0..<10 {
            let flashTime = Date()
            setFlash(true)

            let detectedFrame = waitForBrightnessIncrease()
            let detectedTime = detectedFrame.timestamp

            latencies.append(detectedTime.timeIntervalSince(flashTime))
            setFlash(false)
        }

        return latencies.sorted()[latencies.count / 2]  // Median
    }
}
```

### 8. Performance Monitoring
```swift
// Echtzeit Performance-Monitoring
class VideoPerformanceMonitor {
    // Metrics
    struct Metrics {
        var fps: Float = 0
        var frameTime: TimeInterval = 0
        var gpuUtilization: Float = 0
        var encoderLoad: Float = 0
        var droppedFrames: Int = 0
        var latency: TimeInterval = 0
        var bufferLevel: Float = 0
    }

    var currentMetrics = Metrics()
    var metricsHistory = RingBuffer<Metrics>(capacity: 300)  // 5 seconds @ 60fps

    // Track frame timing
    var lastFrameTime: CFTimeInterval = 0

    func recordFrame(timestamp: CFTimeInterval) {
        let frameTime = timestamp - lastFrameTime
        lastFrameTime = timestamp

        currentMetrics.frameTime = frameTime
        currentMetrics.fps = Float(1.0 / frameTime)

        // Check for dropped frames
        let expectedFrameTime = 1.0 / 60.0
        if frameTime > expectedFrameTime * 1.5 {
            currentMetrics.droppedFrames += Int(frameTime / expectedFrameTime) - 1
        }

        metricsHistory.append(currentMetrics)
    }

    // GPU timing
    func measureGPUTime(commandBuffer: MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { [weak self] cb in
            let gpuTime = cb.gpuEndTime - cb.gpuStartTime
            self?.currentMetrics.gpuUtilization = Float(gpuTime / (1.0 / 60.0))
        }
    }

    // Adaptive quality
    func adaptQualityIfNeeded() {
        let avgFPS = metricsHistory.average(\.fps)

        if avgFPS < 55 {
            // Reduce quality
            reduceEffectQuality()
        } else if avgFPS > 59 && currentQuality < maxQuality {
            // Increase quality
            increaseEffectQuality()
        }
    }
}
```

## Chaos Computer Club Real-Time Philosophy:
```
- Jeder Frame zählt
- Messe, optimiere, wiederhole
- GPU ist dein Freund
- Zero-Copy wenn möglich
- Latenz ist der ultimative Feind
- 60fps ist das Minimum, 120fps ist das Ziel
- Dropped Frames sind inakzeptabel
```

Rendere Video in Echtzeit mit minimaler Latenz in Echoelmusic.
