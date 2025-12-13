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

        print("✅ BackgroundSourceManager: Initialized")
    }

    deinit {
        stopVideoPlayback()
        stopDisplayLink()
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
            print("✅ BackgroundSourceManager: Set source to '\(source.displayName)'")

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ BackgroundSourceManager: Failed to set source - \(error)")
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
        // Use CIFilter hue adjust on radial gradient for angular effect
        let radial = try renderGradient(type: .radial, colors: colors, size: size)

        guard let hueFilter = CIFilter(name: "CIHueAdjust") else {
            return radial
        }

        // Create sweeping angular effect by combining with hue rotation
        hueFilter.setValue(radial, forKey: kCIInputImageKey)
        hueFilter.setValue(Float.pi, forKey: kCIInputAngleKey)

        return hueFilter.outputImage ?? radial
    }

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
        // Use CIFilter chain to create Perlin-like noise effect
        let noise = try renderNoise(size: size)

        // Apply Gaussian blur for smooth Perlin-like appearance
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            return noise
        }
        blurFilter.setValue(noise, forKey: kCIInputImageKey)
        blurFilter.setValue(8.0, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return noise }

        // Enhance contrast for cloud-like effect
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return blurred
        }
        contrastFilter.setValue(blurred, forKey: kCIInputImageKey)
        contrastFilter.setValue(2.0, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)

        return contrastFilter.outputImage?.cropped(to: CGRect(origin: .zero, size: size)) ?? noise
    }

    private func renderStars(size: CGSize) throws -> CIImage {
        // Black background with white star points
        let background = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))

        // Generate star field using noise threshold
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let noiseOutput = noiseFilter.outputImage else {
            return background
        }

        // Threshold noise to create sparse star points
        guard let thresholdFilter = CIFilter(name: "CIColorMatrix") else {
            return background
        }

        // High contrast to create sparse bright points (stars)
        let starThreshold: CGFloat = 0.97
        thresholdFilter.setValue(noiseOutput, forKey: kCIInputImageKey)
        thresholdFilter.setValue(CIVector(x: 10, y: 0, z: 0, w: 0), forKey: "inputRVector")
        thresholdFilter.setValue(CIVector(x: 0, y: 10, z: 0, w: 0), forKey: "inputGVector")
        thresholdFilter.setValue(CIVector(x: 0, y: 0, z: 10, w: 0), forKey: "inputBVector")
        thresholdFilter.setValue(CIVector(x: -starThreshold * 10, y: -starThreshold * 10, z: -starThreshold * 10, w: 1), forKey: "inputBiasVector")

        guard let stars = thresholdFilter.outputImage else { return background }

        // Composite stars over black background
        guard let compositeFilter = CIFilter(name: "CIAdditionCompositing") else {
            return stars.cropped(to: CGRect(origin: .zero, size: size))
        }
        compositeFilter.setValue(stars, forKey: kCIInputImageKey)
        compositeFilter.setValue(background, forKey: kCIInputBackgroundImageKey)

        return compositeFilter.outputImage?.cropped(to: CGRect(origin: .zero, size: size)) ?? background
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

        print("▶️ BackgroundSourceManager: Started video playback")
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

    private func startCameraCapture(position: AVCaptureDevice.Position) async throws {
        #if os(iOS) || os(macOS)
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Find camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw BackgroundError.cameraNotAvailable
        }

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Add video output for frame capture
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.captureSession = session

        // Start capture on background thread
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }

        print("📷 BackgroundSourceManager: Live camera started (\(position == .front ? "front" : "back"))")
        #else
        throw BackgroundError.cameraNotAvailable
        #endif
    }

    // MARK: - Echoelmusic Visual Integration

    private func startEchoelmusicVisual(type: EchoelmusicVisualType) async throws {
        // Create visual renderer with proper type
        let renderer = EchoelmusicVisualRenderer(device: device, type: type)

        // Configure based on visual type
        switch type {
        case .cymatics:
            renderer.frequency = 432.0  // Start with healing frequency
            renderer.amplitude = 0.8
        case .mandala:
            renderer.complexity = 8
            renderer.rotationSpeed = 0.5
        case .particles:
            renderer.particleCount = 1000
            renderer.emissionRate = 50
        case .waveform:
            renderer.lineWidth = 2.0
            renderer.smoothing = 0.3
        case .spectrum:
            renderer.barCount = 64
            renderer.peakHold = true
        }

        self.echoelmusicVisualRenderer = renderer

        print("🎨 BackgroundSourceManager: Started Echoelmusic visual '\(type.displayName)'")
    }

    // MARK: - Blur Background

    private func renderBlurBackground(type: BlurType, intensity: Float) async throws {
        // Use CIFilter for Gaussian blur effect
        let context = CIContext()

        // Create base image (solid color or captured frame)
        let baseColor: CIColor
        switch type {
        case .light:
            baseColor = CIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .dark:
            baseColor = CIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        case .adaptive:
            // Use system appearance
            baseColor = CIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        }

        // Create solid color image
        guard let colorGenerator = CIFilter(name: "CIConstantColorGenerator") else {
            try await setSource(.solidColor(.gray))
            return
        }
        colorGenerator.setValue(baseColor, forKey: kCIInputColorKey)

        guard let colorImage = colorGenerator.outputImage else {
            try await setSource(.solidColor(.gray))
            return
        }

        // Apply Gaussian blur
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            try await setSource(.solidColor(.gray))
            return
        }

        // Crop to reasonable size first
        let croppedImage = colorImage.cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        blurFilter.setValue(croppedImage, forKey: kCIInputImageKey)
        blurFilter.setValue(Double(intensity) * 30.0, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurFilter.outputImage else {
            try await setSource(.solidColor(.gray))
            return
        }

        // Render to CGImage
        if let cgImage = context.createCGImage(blurredImage, from: blurredImage.extent) {
            currentBackgroundImage = cgImage
            print("🎨 BackgroundSourceManager: Blur background rendered (intensity: \(intensity))")
        }
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
    private let ciContext: CIContext

    private var hrvCoherence: Float = 0.5
    private var heartRate: Float = 70.0

    // Configurable properties
    var frequency: Double = 440.0
    var amplitude: Double = 1.0
    var complexity: Int = 6
    var rotationSpeed: Double = 1.0
    var particleCount: Int = 500
    var emissionRate: Double = 25
    var lineWidth: Double = 1.5
    var smoothing: Double = 0.5
    var barCount: Int = 32
    var peakHold: Bool = false

    init(device: MTLDevice, type: BackgroundSourceManager.EchoelmusicVisualType) {
        self.device = device
        self.type = type
        self.ciContext = CIContext(mtlDevice: device)
    }

    func update(hrvCoherence: Float, heartRate: Float) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
    }

    func render(size: CGSize) async throws -> MTLTexture {
        // Generate visual based on type using CIFilters
        let ciImage = try generateVisual(size: size)

        // Create Metal texture
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

        // Render CIImage to texture
        ciContext.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())

        return texture
    }

    private func generateVisual(size: CGSize) throws -> CIImage {
        let time = CACurrentMediaTime()

        switch type {
        case .cymatics:
            return try generateCymatics(size: size, time: time)
        case .mandala:
            return try generateMandala(size: size, time: time)
        case .particles:
            return try generateParticles(size: size, time: time)
        case .waveform:
            return try generateWaveform(size: size, time: time)
        case .spectrum:
            return try generateSpectrum(size: size, time: time)
        }
    }

    private func generateCymatics(size: CGSize, time: Double) throws -> CIImage {
        // Create cymatics-like pattern using ripple effect
        guard let filter = CIFilter(name: "CIRippleTransition") else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        let blank = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.2))
            .cropped(to: CGRect(origin: .zero, size: size))

        filter.setValue(blank, forKey: kCIInputImageKey)
        filter.setValue(blank, forKey: "inputTargetImage")
        filter.setValue(CIVector(x: size.width/2, y: size.height/2), forKey: "inputCenter")
        filter.setValue(size.width * 0.8, forKey: "inputWidth")
        filter.setValue(sin(time * frequency / 100.0) * 0.5 + 0.5, forKey: "inputTime")

        return filter.outputImage ?? blank
    }

    private func generateMandala(size: CGSize, time: Double) throws -> CIImage {
        // Create kaleidoscope/mandala pattern
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let kaleidoscope = CIFilter(name: "CIKaleidoscope") else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        guard let noise = noiseFilter.outputImage else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        kaleidoscope.setValue(noise, forKey: kCIInputImageKey)
        kaleidoscope.setValue(CIVector(x: size.width/2, y: size.height/2), forKey: "inputCenter")
        kaleidoscope.setValue(complexity, forKey: "inputCount")
        kaleidoscope.setValue(time * rotationSpeed, forKey: "inputAngle")

        return kaleidoscope.outputImage?.cropped(to: CGRect(origin: .zero, size: size))
            ?? CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
    }

    private func generateParticles(size: CGSize, time: Double) throws -> CIImage {
        // Create particle-like effect using star burst
        guard let filter = CIFilter(name: "CIStarShineGenerator") else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        filter.setValue(CIVector(x: size.width/2, y: size.height/2), forKey: "inputCenter")
        filter.setValue(CIColor(red: Double(hrvCoherence), green: 0.5, blue: 1.0 - Double(hrvCoherence)), forKey: "inputColor")
        filter.setValue(size.width * 0.3, forKey: "inputRadius")
        filter.setValue(0.5, forKey: "inputCrossScale")
        filter.setValue(sin(time) * 5 + 10, forKey: "inputCrossAngle")

        let stars = filter.outputImage ?? CIImage(color: CIColor.black)
        let background = CIImage(color: CIColor(red: 0.05, green: 0.05, blue: 0.1))
            .cropped(to: CGRect(origin: .zero, size: size))

        guard let composite = CIFilter(name: "CIAdditionCompositing") else {
            return stars.cropped(to: CGRect(origin: .zero, size: size))
        }
        composite.setValue(stars, forKey: kCIInputImageKey)
        composite.setValue(background, forKey: kCIInputBackgroundImageKey)

        return composite.outputImage?.cropped(to: CGRect(origin: .zero, size: size)) ?? stars
    }

    private func generateWaveform(size: CGSize, time: Double) throws -> CIImage {
        // Create waveform-like stripes pattern
        guard let filter = CIFilter(name: "CIStripesGenerator") else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        let hue = Double(heartRate - 60) / 120.0  // Map heart rate to hue
        filter.setValue(CIColor(hue: CGFloat(hue), saturation: 0.8, brightness: 0.9), forKey: "inputColor0")
        filter.setValue(CIColor(hue: CGFloat(hue + 0.1), saturation: 0.6, brightness: 0.3), forKey: "inputColor1")
        filter.setValue(CIVector(x: size.width/2, y: size.height/2), forKey: "inputCenter")
        filter.setValue(lineWidth * 10, forKey: "inputWidth")
        filter.setValue(1.0, forKey: "inputSharpness")

        return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: size))
            ?? CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
    }

    private func generateSpectrum(size: CGSize, time: Double) throws -> CIImage {
        // Create spectrum-like gradient bars
        guard let filter = CIFilter(name: "CILinearGradient") else {
            return CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
        }

        filter.setValue(CIVector(x: 0, y: size.height/2), forKey: "inputPoint0")
        filter.setValue(CIVector(x: size.width, y: size.height/2), forKey: "inputPoint1")
        filter.setValue(CIColor(red: 1, green: 0, blue: 0), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0, green: 0, blue: 1), forKey: "inputColor1")

        return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: size))
            ?? CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
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
        }
    }
}
