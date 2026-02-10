import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage
import SwiftUI
import Combine

/// Background Source Manager for Chroma Key Compositing
/// Supports multiple background types: images, videos, Echoelmusic visuals, virtual backgrounds
/// Bio-reactive backgrounds driven by HRV coherence and heart rate
@MainActor
class BackgroundSourceManager: ObservableObject {

    // MARK: - Published State

    @Published var currentSource: BackgroundSource = .solidColor(.black)
    @Published var availableSources: [BackgroundSource] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Bio-Reactive Parameters

    @Published var hrvCoherence: Float = 0.5  // 0-1
    @Published var heartRate: Float = 70.0   // BPM
    @Published var bioReactivityEnabled: Bool = true

    // MARK: - Metal & Core Image

    private let device: MTLDevice
    private let ciContext: CIContext
    private let textureLoader: MTKTextureLoader

    // MARK: - Video Playback

    private var videoPlayer: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?

    // MARK: - Echoelmusic Visual Integration

    private var echoelmusicVisualRenderer: EchoelmusicVisualRenderer?

    // MARK: - Current Texture Cache

    private var currentTexture: MTLTexture?
    private var cachedImage: CIImage?

    // MARK: - Background Source Types

    enum BackgroundSource: Identifiable, Equatable {
        case solidColor(Color)
        case gradient(GradientType, [Color])
        case image(URL)
        case video(URL, looping: Bool)
        case liveCamera(cameraPosition: AVCaptureDevice.Position)
        case echoelmusicVisual(EchoelmusicVisualType)
        case blur(BlurType, intensity: Float)
        case virtualBackground(VirtualType)

        var id: String {
            switch self {
            case .solidColor(let color): return "solid_\(color.description)"
            case .gradient(let type, _): return "gradient_\(type.rawValue)"
            case .image(let url): return "image_\(url.lastPathComponent)"
            case .video(let url, _): return "video_\(url.lastPathComponent)"
            case .liveCamera(let pos): return "camera_\(pos == .front ? "front" : "back")"
            case .echoelmusicVisual(let type): return "echoelmusic_\(type.rawValue)"
            case .blur(let type, _): return "blur_\(type.rawValue)"
            case .virtualBackground(let type): return "virtual_\(type.rawValue)"
            }
        }

        var displayName: String {
            switch self {
            case .solidColor: return "Solid Color"
            case .gradient(let type, _): return "\(type.rawValue) Gradient"
            case .image(let url): return url.deletingPathExtension().lastPathComponent
            case .video(let url, _): return url.deletingPathExtension().lastPathComponent
            case .liveCamera(let pos): return "\(pos == .front ? "Front" : "Back") Camera"
            case .echoelmusicVisual(let type): return "Echoelmusic: \(type.displayName)"
            case .blur(let type, _): return "\(type.rawValue) Blur"
            case .virtualBackground(let type): return "Virtual: \(type.rawValue)"
            }
        }

        static func == (lhs: BackgroundSource, rhs: BackgroundSource) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Gradient Types

    enum GradientType: String, CaseIterable {
        case linear = "Linear"
        case radial = "Radial"
        case angular = "Angular"
        case bioreactive = "Bio-Reactive"  // HRV-driven colors
    }

    // MARK: - Echoelmusic Visual Types

    enum EchoelmusicVisualType: String, CaseIterable {
        case cymatics = "Cymatics"
        case mandala = "Mandala"
        case particles = "Particles"
        case waveform = "Waveform"
        case spectral = "Spectral"

        var displayName: String {
            switch self {
            case .cymatics: return "Cymatics (Water Patterns)"
            case .mandala: return "Mandala (Sacred Geometry)"
            case .particles: return "Particles (Bio-Reactive)"
            case .waveform: return "Waveform (Audio)"
            case .spectral: return "Spectral (FFT)"
            }
        }
    }

    // MARK: - Blur Types

    enum BlurType: String, CaseIterable {
        case gaussian = "Gaussian"
        case bokeh = "Bokeh"
        case motion = "Motion"
    }

    // MARK: - Virtual Background Types

    enum VirtualType: String, CaseIterable {
        case checkerboard = "Checkerboard"
        case noise = "Noise"
        case perlinNoise = "Perlin Noise"
        case stars = "Stars"
    }

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device

        // Create Core Image context
        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .name: "BackgroundContext"
        ])

        // Create texture loader
        self.textureLoader = MTKTextureLoader(device: device)

        // Initialize available sources
        initializeDefaultSources()

        log.video("✅ BackgroundSourceManager: Initialized")
    }

    deinit {
        // stopVideoPlayback()/stopDisplayLink() are @MainActor-isolated, cannot call from deinit
        // AVPlayer and display link will be cleaned up on deallocation
    }

    // MARK: - Initialize Default Sources

    private func initializeDefaultSources() {
        availableSources = [
            // Solid colors
            .solidColor(.black),
            .solidColor(.white),
            .solidColor(.blue),
            .solidColor(.green),

            // Gradients
            .gradient(.linear, [.blue, .purple]),
            .gradient(.radial, [.pink, .orange]),
            .gradient(.bioreactive, [.red, .green, .blue]),  // HRV-driven

            // Echoelmusic Visuals (all bio-reactive)
            .echoelmusicVisual(.cymatics),
            .echoelmusicVisual(.mandala),
            .echoelmusicVisual(.particles),
            .echoelmusicVisual(.waveform),
            .echoelmusicVisual(.spectral),

            // Blur backgrounds
            .blur(.gaussian, intensity: 0.5),
            .blur(.bokeh, intensity: 0.7),

            // Virtual backgrounds
            .virtualBackground(.checkerboard),
            .virtualBackground(.noise),
            .virtualBackground(.stars)
        ]
    }

    // MARK: - Set Background Source

    func setSource(_ source: BackgroundSource) async throws {
        isLoading = true
        errorMessage = nil

        // Stop previous source
        await stopCurrentSource()

        // Start new source
        currentSource = source

        do {
            switch source {
            case .solidColor, .gradient, .virtualBackground:
                // Render once
                try await renderStaticSource(source)

            case .image(let url):
                try await loadImage(from: url)

            case .video(let url, let looping):
                try await startVideoPlayback(url: url, looping: looping)

            case .liveCamera(let position):
                try await startCameraCapture(position: position)

            case .echoelmusicVisual(let type):
                try await startEchoelmusicVisual(type: type)

            case .blur(let type, let intensity):
                try await renderBlurBackground(type: type, intensity: intensity)
            }

            isLoading = false
            log.video("✅ BackgroundSourceManager: Set source to '\(source.displayName)'")

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            log.video("❌ BackgroundSourceManager: Failed to set source - \(error)", level: .error)
            throw error
        }
    }

    // MARK: - Get Current Texture

    func getCurrentTexture(size: CGSize) async throws -> MTLTexture {
        // Check if we need to update (for animated sources)
        switch currentSource {
        case .video, .liveCamera, .echoelmusicVisual, .gradient(.bioreactive, _):
            // These sources need continuous updates
            return try await updateAnimatedSource(size: size)

        default:
            // Static sources - return cached texture
            if let texture = currentTexture {
                return texture
            } else {
                // Render on-demand
                return try await renderStaticSource(currentSource, size: size)
            }
        }
    }

    // MARK: - Render Static Source

    @discardableResult
    private func renderStaticSource(_ source: BackgroundSource, size: CGSize = CGSize(width: 1920, height: 1080)) async throws -> MTLTexture {
        let ciImage: CIImage

        switch source {
        case .solidColor(let color):
            ciImage = try renderSolidColor(color, size: size)

        case .gradient(let type, let colors):
            ciImage = try renderGradient(type: type, colors: colors, size: size)

        case .virtualBackground(let type):
            ciImage = try renderVirtualBackground(type: type, size: size)

        default:
            throw BackgroundError.unsupportedStaticSource
        }

        // Convert CIImage to MTLTexture
        let texture = try createTexture(from: ciImage)
        currentTexture = texture
        cachedImage = ciImage

        return texture
    }

    // MARK: - Solid Color Rendering

    private func renderSolidColor(_ color: Color, size: CGSize) throws -> CIImage {
        // Convert SwiftUI Color to CIColor
        let ciColor: CIColor

        #if os(iOS)
        let uiColor = UIColor(color)
        ciColor = CIColor(color: uiColor)
        #else
        let nsColor = NSColor(color)
        ciColor = CIColor(color: nsColor) ?? CIColor(red: 0, green: 0, blue: 0)
        #endif

        // Create solid color image
        return CIImage(color: ciColor).cropped(to: CGRect(origin: .zero, size: size))
    }

    // MARK: - Gradient Rendering

    private func renderGradient(type: GradientType, colors: [Color], size: CGSize) throws -> CIImage {
        // Create gradient filter based on type
        let filter: CIFilter?

        switch type {
        case .linear:
            filter = CIFilter(name: "CILinearGradient")
            filter?.setValue(CIVector(x: 0, y: size.height), forKey: "inputPoint0")
            filter?.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint1")

        case .radial:
            filter = CIFilter(name: "CIRadialGradient")
            filter?.setValue(CIVector(x: size.width/2, y: size.height/2), forKey: "inputCenter")
            filter?.setValue(0, forKey: "inputRadius0")
            filter?.setValue(size.width/2, forKey: "inputRadius1")

        case .angular:
            // Custom angular gradient (not built-in)
            return try renderAngularGradient(colors: colors, size: size)

        case .bioreactive:
            // HRV-driven gradient colors
            return try renderBioReactiveGradient(size: size)
        }

        // Set colors (for linear/radial)
        if let filter = filter, colors.count >= 2 {
            #if os(iOS)
            let color0 = CIColor(color: UIColor(colors[0]))
            let color1 = CIColor(color: UIColor(colors[1]))
            #else
            let color0 = CIColor(color: NSColor(colors[0])) ?? CIColor.black
            let color1 = CIColor(color: NSColor(colors[1])) ?? CIColor.white
            #endif

            filter.setValue(color0, forKey: "inputColor0")
            filter.setValue(color1, forKey: "inputColor1")

            guard let outputImage = filter.outputImage else {
                throw BackgroundError.gradientRenderingFailed
            }

            return outputImage.cropped(to: CGRect(origin: .zero, size: size))
        }

        throw BackgroundError.gradientRenderingFailed
    }

    // MARK: - Bio-Reactive Gradient

    private func renderBioReactiveGradient(size: CGSize) throws -> CIImage {
        guard bioReactivityEnabled else {
            // Fallback to simple gradient
            return try renderGradient(type: .linear, colors: [.blue, .purple], size: size)
        }

        // Map HRV coherence (0-1) to hue (0-360)
        // Low coherence (0.0) → Red (0°)
        // Medium coherence (0.5) → Yellow (60°)
        // High coherence (1.0) → Blue/Purple (240°)
        let hue = Double(hrvCoherence) * 240.0 / 360.0

        // Map heart rate to saturation
        let saturation = Double(min(1.0, (heartRate - 40.0) / 80.0))

        let color1 = Color(hue: hue, saturation: saturation, brightness: 0.6)
        let color2 = Color(hue: hue + 0.2, saturation: saturation * 0.8, brightness: 0.9)

        return try renderGradient(type: .radial, colors: [color1, color2], size: size)
    }

    // MARK: - Angular Gradient (Custom)

    private func renderAngularGradient(colors: [Color], size: CGSize) throws -> CIImage {
        // Custom angular gradient using Core Graphics
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)

        let uiImage = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height)

            // Draw angular gradient segments
            let segmentCount = 360
            let angleStep = 2.0 * .pi / Double(segmentCount)

            for i in 0..<segmentCount {
                let startAngle = Double(i) * angleStep
                let endAngle = Double(i + 1) * angleStep

                // Interpolate color based on angle
                let colorIndex = Double(i) / Double(segmentCount) * Double(colors.count - 1)
                let lowerIndex = Int(colorIndex)
                let upperIndex = min(lowerIndex + 1, colors.count - 1)
                let fraction = colorIndex - Double(lowerIndex)

                let color1 = UIColor(colors[lowerIndex])
                let color2 = UIColor(colors[upperIndex])
                let blendedColor = blendColors(color1, color2, fraction: CGFloat(fraction))

                ctx.setFillColor(blendedColor.cgColor)
                ctx.move(to: center)
                ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                ctx.closePath()
                ctx.fillPath()
            }
        }

        guard let ciImage = CIImage(image: uiImage) else {
            throw BackgroundError.gradientRenderingFailed
        }

        return ciImage
        #else
        // Fallback for non-iOS platforms
        return try renderGradient(type: .radial, colors: colors, size: size)
        #endif
    }

    #if os(iOS)
    private func blendColors(_ c1: UIColor, _ c2: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1 + (a2 - a1) * fraction
        )
    }
    #endif

    // MARK: - Virtual Background Rendering

    private func renderVirtualBackground(type: VirtualType, size: CGSize) throws -> CIImage {
        switch type {
        case .checkerboard:
            return try renderCheckerboard(size: size)

        case .noise:
            return try renderNoise(size: size)

        case .perlinNoise:
            return try renderPerlinNoise(size: size)

        case .stars:
            return try renderStars(size: size)
        }
    }

    private func renderCheckerboard(size: CGSize) throws -> CIImage {
        guard let filter = CIFilter(name: "CICheckerboardGenerator") else {
            throw BackgroundError.filterNotAvailable("CICheckerboardGenerator")
        }

        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor(red: 0.9, green: 0.9, blue: 0.9), forKey: "inputColor1")
        filter.setValue(40.0, forKey: "inputWidth")

        guard let output = filter.outputImage else {
            throw BackgroundError.virtualBackgroundFailed
        }

        return output.cropped(to: CGRect(origin: .zero, size: size))
    }

    private func renderNoise(size: CGSize) throws -> CIImage {
        guard let filter = CIFilter(name: "CIRandomGenerator") else {
            throw BackgroundError.filterNotAvailable("CIRandomGenerator")
        }

        guard let output = filter.outputImage else {
            throw BackgroundError.virtualBackgroundFailed
        }

        return output.cropped(to: CGRect(origin: .zero, size: size))
    }

    private func renderPerlinNoise(size: CGSize) throws -> CIImage {
        // Perlin-like noise implementation using Core Graphics
        #if os(iOS)
        let scale: CGFloat = 0.02  // Noise scale
        let renderer = UIGraphicsImageRenderer(size: size)

        let uiImage = renderer.image { context in
            let ctx = context.cgContext

            // Sample at lower resolution for performance
            let sampleStep = 4
            for y in stride(from: 0, to: Int(size.height), by: sampleStep) {
                for x in stride(from: 0, to: Int(size.width), by: sampleStep) {
                    // Simplified Perlin-like noise using sine waves
                    let nx = Double(x) * Double(scale)
                    let ny = Double(y) * Double(scale)

                    // Multi-octave noise approximation
                    var noise: Double = 0
                    noise += sin(nx * 1.0 + ny * 1.0) * 0.5
                    noise += sin(nx * 2.0 - ny * 0.5) * 0.25
                    noise += sin(nx * 4.0 + ny * 2.0) * 0.125
                    noise += sin(ny * 3.0 - nx * 1.5) * 0.125

                    // Normalize to 0-1 range
                    let value = (noise + 1.0) / 2.0

                    let gray = CGFloat(value)
                    ctx.setFillColor(UIColor(white: gray, alpha: 1.0).cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: sampleStep, height: sampleStep))
                }
            }
        }

        guard let ciImage = CIImage(image: uiImage) else {
            throw BackgroundError.virtualBackgroundFailed
        }

        return ciImage
        #else
        return try renderNoise(size: size)
        #endif
    }

    private func renderStars(size: CGSize) throws -> CIImage {
        // Starfield background with random star particles
        #if os(iOS)
        let starCount = 500
        let renderer = UIGraphicsImageRenderer(size: size)

        let uiImage = renderer.image { context in
            let ctx = context.cgContext

            // Fill black background
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            // Generate deterministic stars (seeded random)
            srand48(42)  // Fixed seed for consistent starfield

            for _ in 0..<starCount {
                let x = CGFloat(drand48()) * size.width
                let y = CGFloat(drand48()) * size.height
                let brightness = CGFloat(drand48() * 0.5 + 0.5)  // 0.5-1.0
                let starSize = CGFloat(drand48() * 2 + 1)  // 1-3 pixels

                // Star color (mostly white with slight color variation)
                let colorVariation = drand48() * 0.1
                let r = min(1.0, brightness + colorVariation)
                let g = min(1.0, brightness + colorVariation * 0.5)
                let b = min(1.0, brightness + colorVariation * 0.8)

                ctx.setFillColor(UIColor(red: r, green: g, blue: b, alpha: brightness).cgColor)

                // Draw star with glow effect
                let rect = CGRect(x: x - starSize/2, y: y - starSize/2, width: starSize, height: starSize)
                ctx.fillEllipse(in: rect)

                // Add glow for brighter stars
                if brightness > 0.8 {
                    ctx.setFillColor(UIColor(white: brightness, alpha: 0.3).cgColor)
                    let glowRect = rect.insetBy(dx: -1, dy: -1)
                    ctx.fillEllipse(in: glowRect)
                }
            }
        }

        guard let ciImage = CIImage(image: uiImage) else {
            throw BackgroundError.virtualBackgroundFailed
        }

        return ciImage
        #else
        // Fallback for non-iOS
        return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        #endif
    }

    // MARK: - Load Image

    private func loadImage(from url: URL) async throws {
        let data = try Data(contentsOf: url)

        #if os(iOS)
        guard let uiImage = UIImage(data: data) else {
            throw BackgroundError.imageLoadingFailed(url)
        }
        cachedImage = CIImage(image: uiImage)
        #else
        guard let nsImage = NSImage(data: data) else {
            throw BackgroundError.imageLoadingFailed(url)
        }
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw BackgroundError.imageLoadingFailed(url)
        }
        cachedImage = CIImage(cgImage: cgImage)
        #endif

        if let ciImage = cachedImage {
            currentTexture = try createTexture(from: ciImage)
        }
    }

    // MARK: - Video Playback

    private func startVideoPlayback(url: URL, looping: Bool) async throws {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        // Create video output for frame extraction
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        playerItem.add(videoOutput)
        self.videoOutput = videoOutput

        // Create player
        let player = AVPlayer(playerItem: playerItem)
        self.videoPlayer = player

        // Loop if requested
        if looping {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        // Start playback
        player.play()

        // Start display link for frame updates
        startDisplayLink()

        log.video("▶️ BackgroundSourceManager: Started video playback")
    }

    private func stopVideoPlayback() {
        videoPlayer?.pause()
        videoPlayer = nil
        videoOutput = nil
        stopDisplayLink()
    }

    // MARK: - Display Link (for video frame updates)

    private func startDisplayLink() {
        #if os(iOS)
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
        #endif
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkCallback() {
        // Update video frame
        Task { @MainActor in
            _ = try? await getCurrentTexture(size: CGSize(width: 1920, height: 1080))
        }
    }

    // MARK: - Camera Capture

    private var captureSession: AVCaptureSession?
    private var cameraOutput: AVCaptureVideoDataOutput?
    private var cameraTexture: MTLTexture?

    private func startCameraCapture(position: AVCaptureDevice.Position) async throws {
        #if os(iOS)
        // Live camera capture using AVCaptureSession
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        // Find camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw BackgroundError.cameraNotAvailable
        }

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw BackgroundError.cameraConfigurationFailed
        }
        session.addInput(input)

        // Add output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard session.canAddOutput(output) else {
            throw BackgroundError.cameraConfigurationFailed
        }
        session.addOutput(output)

        self.captureSession = session
        self.cameraOutput = output

        // Start capture on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        log.video("📷 BackgroundSourceManager: Live camera capture started (\(position == .front ? "front" : "back") camera)")
        #else
        throw BackgroundError.cameraNotAvailable
        #endif
    }

    private func stopCameraCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        cameraOutput = nil
        cameraTexture = nil
    }

    // MARK: - Echoelmusic Visual Integration

    private func startEchoelmusicVisual(type: EchoelmusicVisualType) async throws {
        // Integrate with Echoelmusic visual renderers
        let renderer = EchoelmusicVisualRenderer(device: device, type: type)

        // Configure renderer based on type
        switch type {
        case .cymatics:
            renderer.configure(parameters: [
                "frequency": 432.0,
                "amplitude": 0.8,
                "resolution": 256
            ])
        case .mandala:
            renderer.configure(parameters: [
                "symmetry": 8,
                "rotationSpeed": 0.5,
                "colorCycle": true
            ])
        case .particles:
            renderer.configure(parameters: [
                "particleCount": 10000,
                "lifespan": 3.0,
                "emissionRate": 500
            ])
        case .waveform:
            renderer.configure(parameters: [
                "fftSize": 2048,
                "smoothing": 0.8,
                "style": "circular"
            ])
        case .spectral:
            renderer.configure(parameters: [
                "fftSize": 4096,
                "bands": 64,
                "colorScheme": "rainbow"
            ])
        }

        // Start renderer
        await renderer.start()
        echoelmusicVisualRenderer = renderer

        log.video("🎨 BackgroundSourceManager: Started Echoelmusic visual '\(type.displayName)' with \(type.rawValue) renderer")
    }

    // MARK: - Blur Background

    private var blurredTexture: MTLTexture?

    private func renderBlurBackground(type: BlurType, intensity: Float) async throws {
        // Blur background using CIFilter
        // First render a base gradient to blur
        let baseImage = try renderGradient(type: .linear, colors: [.blue, .purple], size: CGSize(width: 1920, height: 1080))

        // Select blur filter based on type
        let blurredImage: CIImage

        switch type {
        case .gaussian:
            guard let filter = CIFilter(name: "CIGaussianBlur") else {
                throw BackgroundError.filterNotAvailable("CIGaussianBlur")
            }
            filter.setValue(baseImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 50.0, forKey: kCIInputRadiusKey)  // 0-50 radius
            guard let output = filter.outputImage else {
                throw BackgroundError.blurRenderingFailed
            }
            blurredImage = output.cropped(to: baseImage.extent)

        case .bokeh:
            // Bokeh effect using disc blur
            guard let filter = CIFilter(name: "CIDiscBlur") else {
                // Fallback to gaussian if disc blur not available
                guard let gaussianFilter = CIFilter(name: "CIGaussianBlur") else {
                    throw BackgroundError.filterNotAvailable("CIGaussianBlur")
                }
                gaussianFilter.setValue(baseImage, forKey: kCIInputImageKey)
                gaussianFilter.setValue(intensity * 30.0, forKey: kCIInputRadiusKey)
                guard let output = gaussianFilter.outputImage else {
                    throw BackgroundError.blurRenderingFailed
                }
                blurredImage = output.cropped(to: baseImage.extent)
                break
            }
            filter.setValue(baseImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 30.0, forKey: kCIInputRadiusKey)
            guard let output = filter.outputImage else {
                throw BackgroundError.blurRenderingFailed
            }
            blurredImage = output.cropped(to: baseImage.extent)

        case .motion:
            guard let filter = CIFilter(name: "CIMotionBlur") else {
                throw BackgroundError.filterNotAvailable("CIMotionBlur")
            }
            filter.setValue(baseImage, forKey: kCIInputImageKey)
            filter.setValue(intensity * 40.0, forKey: kCIInputRadiusKey)
            filter.setValue(0.0, forKey: kCIInputAngleKey)  // Horizontal motion
            guard let output = filter.outputImage else {
                throw BackgroundError.blurRenderingFailed
            }
            blurredImage = output.cropped(to: baseImage.extent)
        }

        // Render blurred image to texture
        blurredTexture = try createTexture(from: blurredImage)
        currentTexture = blurredTexture
        log.video("🔵 BackgroundSourceManager: Applied \(type.rawValue) blur with intensity \(String(format: "%.1f", intensity))")
    }

    // MARK: - Update Animated Source

    private func updateAnimatedSource(size: CGSize) async throws -> MTLTexture {
        switch currentSource {
        case .video:
            return try await updateVideoFrame(size: size)

        case .echoelmusicVisual(let type):
            return try await updateEchoelmusicVisual(type: type, size: size)

        case .gradient(.bioreactive, _):
            // Re-render gradient with updated bio params
            return try await renderStaticSource(currentSource, size: size)

        default:
            // Shouldn't reach here
            return try await renderStaticSource(currentSource, size: size)
        }
    }

    private func updateVideoFrame(size: CGSize) async throws -> MTLTexture {
        guard let videoOutput = videoOutput, let player = videoPlayer else {
            throw BackgroundError.videoPlaybackNotActive
        }

        let currentTime = player.currentTime()
        if videoOutput.hasNewPixelBuffer(forItemTime: currentTime) {
            guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
                throw BackgroundError.videoFrameExtractionFailed
            }

            // Convert pixel buffer to CIImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            currentTexture = try createTexture(from: ciImage)
        }

        return currentTexture ?? (try await renderStaticSource(.solidColor(.black), size: size))
    }

    private func updateEchoelmusicVisual(type: EchoelmusicVisualType, size: CGSize) async throws -> MTLTexture {
        guard let renderer = echoelmusicVisualRenderer else {
            throw BackgroundError.echoelmusicVisualNotActive
        }

        // Update bio parameters
        renderer.update(hrvCoherence: hrvCoherence, heartRate: heartRate)

        // Render frame
        return try await renderer.render(size: size)
    }

    // MARK: - Stop Current Source

    private func stopCurrentSource() async {
        stopVideoPlayback()
        echoelmusicVisualRenderer = nil
        currentTexture = nil
        cachedImage = nil
    }

    // MARK: - Texture Creation

    private func createTexture(from ciImage: CIImage) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = Int(ciImage.extent.width)
        descriptor.height = Int(ciImage.extent.height)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw BackgroundError.textureCreationFailed
        }

        // Render CIImage to MTLTexture
        ciContext.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())

        return texture
    }

    // MARK: - Update Bio Parameters

    func updateBioParameters(coherence: Float, heartRate: Float) {
        self.hrvCoherence = coherence
        self.heartRate = heartRate
    }
}

// MARK: - Echoelmusic Visual Renderer (Placeholder)

@MainActor
class EchoelmusicVisualRenderer {
    private let device: MTLDevice
    private let type: BackgroundSourceManager.EchoelmusicVisualType

    private var hrvCoherence: Float = 0.5
    private var heartRate: Float = 70.0

    init(device: MTLDevice, type: BackgroundSourceManager.EchoelmusicVisualType) {
        self.device = device
        self.type = type
    }

    func update(hrvCoherence: Float, heartRate: Float) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
    }

    var parameters: [String: Any] = [:]

    func configure(parameters: [String: Any]) {
        self.parameters = parameters
    }

    func start() async {
        // Initialize renderer resources based on type
        log.video("🎨 EchoelmusicVisualRenderer: Started \(type.rawValue)")
    }

    func render(size: CGSize) async throws -> MTLTexture {
        // Render visual frame based on type
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = Int(size.width)
        descriptor.height = Int(size.height)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw BackgroundError.textureCreationFailed
        }

        // Render based on visual type (dispatch to appropriate renderer)
        switch type {
        case .cymatics:
            // Render cymatics water patterns based on frequency and coherence
            renderCymaticsToTexture(texture)
        case .mandala:
            // Render sacred geometry mandala with rotation
            renderMandalaToTexture(texture)
        case .particles:
            // Render bio-reactive particle system
            renderParticlesToTexture(texture)
        case .waveform:
            // Render audio waveform visualization
            renderWaveformToTexture(texture)
        case .spectral:
            // Render FFT spectral analysis
            renderSpectralToTexture(texture)
        }

        return texture
    }

    private func renderCymaticsToTexture(_ texture: MTLTexture) {
        // Cymatics rendering - water ripple patterns based on coherence
        let frequency = parameters["frequency"] as? Float ?? 432.0
        let amplitude = parameters["amplitude"] as? Float ?? hrvCoherence
        log.video("🎨 Cymatics: freq=\(frequency)Hz, amp=\(amplitude), coherence=\(hrvCoherence)")
    }

    private func renderMandalaToTexture(_ texture: MTLTexture) {
        // Mandala rendering - sacred geometry with symmetry
        let symmetry = parameters["symmetry"] as? Int ?? 8
        let rotationSpeed = parameters["rotationSpeed"] as? Float ?? 0.5
        log.video("🎨 Mandala: symmetry=\(symmetry), rotation=\(rotationSpeed), coherence=\(hrvCoherence)")
    }

    private func renderParticlesToTexture(_ texture: MTLTexture) {
        // Particle system rendering - bio-reactive particles
        let particleCount = parameters["particleCount"] as? Int ?? 10000
        log.video("🎨 Particles: count=\(particleCount), heartRate=\(heartRate), coherence=\(hrvCoherence)")
    }

    private func renderWaveformToTexture(_ texture: MTLTexture) {
        // Waveform rendering - audio visualization
        let fftSize = parameters["fftSize"] as? Int ?? 2048
        log.video("🎨 Waveform: fftSize=\(fftSize), coherence=\(hrvCoherence)")
    }

    private func renderSpectralToTexture(_ texture: MTLTexture) {
        // Spectral analysis rendering - FFT bars
        let bands = parameters["bands"] as? Int ?? 64
        log.video("🎨 Spectral: bands=\(bands), coherence=\(hrvCoherence)")
    }
}

// MARK: - Errors

enum BackgroundError: LocalizedError {
    case unsupportedStaticSource
    case gradientRenderingFailed
    case filterNotAvailable(String)
    case virtualBackgroundFailed
    case imageLoadingFailed(URL)
    case videoPlaybackNotActive
    case videoFrameExtractionFailed
    case echoelmusicVisualNotActive
    case textureCreationFailed
    case cameraNotAvailable
    case cameraConfigurationFailed
    case blurRenderingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedStaticSource:
            return "This background source cannot be rendered as static"
        case .gradientRenderingFailed:
            return "Failed to render gradient"
        case .filterNotAvailable(let name):
            return "Core Image filter '\(name)' not available"
        case .virtualBackgroundFailed:
            return "Failed to generate virtual background"
        case .imageLoadingFailed(let url):
            return "Failed to load image from \(url.lastPathComponent)"
        case .videoPlaybackNotActive:
            return "Video playback is not active"
        case .videoFrameExtractionFailed:
            return "Failed to extract video frame"
        case .echoelmusicVisualNotActive:
            return "Echoelmusic visual renderer is not active"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .cameraConfigurationFailed:
            return "Failed to configure camera capture"
        case .blurRenderingFailed:
            return "Failed to render blur effect"
        }
    }
}
