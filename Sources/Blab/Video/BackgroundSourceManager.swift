import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage
import SwiftUI
import Combine

/// Background Source Manager for Chroma Key Compositing
/// Supports multiple background types: images, videos, BLAB visuals, virtual backgrounds
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

    // MARK: - BLAB Visual Integration

    private var blabVisualRenderer: BLABVisualRenderer?

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
        case blabVisual(BLABVisualType)
        case blur(BlurType, intensity: Float)
        case virtualBackground(VirtualType)

        var id: String {
            switch self {
            case .solidColor(let color): return "solid_\(color.description)"
            case .gradient(let type, _): return "gradient_\(type.rawValue)"
            case .image(let url): return "image_\(url.lastPathComponent)"
            case .video(let url, _): return "video_\(url.lastPathComponent)"
            case .liveCamera(let pos): return "camera_\(pos == .front ? "front" : "back")"
            case .blabVisual(let type): return "blab_\(type.rawValue)"
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
            case .blabVisual(let type): return "BLAB: \(type.displayName)"
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

    // MARK: - BLAB Visual Types

    enum BLABVisualType: String, CaseIterable {
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

            // BLAB Visuals (all bio-reactive)
            .blabVisual(.cymatics),
            .blabVisual(.mandala),
            .blabVisual(.particles),
            .blabVisual(.waveform),
            .blabVisual(.spectral),

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

            case .blabVisual(let type):
                try await startBLABVisual(type: type)

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
        case .video, .liveCamera, .blabVisual, .gradient(.bioreactive, _):
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
        // TODO: Implement custom angular gradient using Metal shader
        // For now, fallback to radial
        return try renderGradient(type: .radial, colors: colors, size: size)
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
        // TODO: Implement Perlin noise using Metal shader
        // For now, use random noise
        return try renderNoise(size: size)
    }

    private func renderStars(size: CGSize) throws -> CIImage {
        // Black background with white star points
        let background = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))

        // TODO: Add star particles using Metal compute shader
        // For now, return black background
        return background
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

    private func startCameraCapture(position: AVCaptureDevice.Position) async throws {
        // TODO: Implement live camera capture using AVCaptureSession
        // For now, use solid color as placeholder
        try await setSource(.solidColor(.blue))
        print("⚠️ BackgroundSourceManager: Live camera not yet implemented")
    }

    // MARK: - BLAB Visual Integration

    private func startBLABVisual(type: BLABVisualType) async throws {
        // TODO: Integrate with existing BLAB visual renderers
        // (CymaticsRenderer, MandalaRenderer, ParticleSystem, etc.)

        // For now, create placeholder
        blabVisualRenderer = BLABVisualRenderer(device: device, type: type)

        print("🎨 BackgroundSourceManager: Started BLAB visual '\(type.displayName)'")
    }

    // MARK: - Blur Background

    private func renderBlurBackground(type: BlurType, intensity: Float) async throws {
        // TODO: Implement blur using CIFilter
        try await setSource(.solidColor(.gray))
        print("⚠️ BackgroundSourceManager: Blur backgrounds not yet fully implemented")
    }

    // MARK: - Update Animated Source

    private func updateAnimatedSource(size: CGSize) async throws -> MTLTexture {
        switch currentSource {
        case .video:
            return try await updateVideoFrame(size: size)

        case .blabVisual(let type):
            return try await updateBLABVisual(type: type, size: size)

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

    private func updateBLABVisual(type: BLABVisualType, size: CGSize) async throws -> MTLTexture {
        guard let renderer = blabVisualRenderer else {
            throw BackgroundError.blabVisualNotActive
        }

        // Update bio parameters
        renderer.update(hrvCoherence: hrvCoherence, heartRate: heartRate)

        // Render frame
        return try await renderer.render(size: size)
    }

    // MARK: - Stop Current Source

    private func stopCurrentSource() async {
        stopVideoPlayback()
        blabVisualRenderer = nil
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

// MARK: - BLAB Visual Renderer (Placeholder)

@MainActor
class BLABVisualRenderer {
    private let device: MTLDevice
    private let type: BackgroundSourceManager.BLABVisualType

    private var hrvCoherence: Float = 0.5
    private var heartRate: Float = 70.0

    init(device: MTLDevice, type: BackgroundSourceManager.BLABVisualType) {
        self.device = device
        self.type = type
    }

    func update(hrvCoherence: Float, heartRate: Float) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
    }

    func render(size: CGSize) async throws -> MTLTexture {
        // TODO: Integrate with actual BLAB visual renderers
        // (CymaticsRenderer, MandalaRenderer, etc.)

        // For now, create empty texture
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

        return texture
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
    case blabVisualNotActive
    case textureCreationFailed

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
        case .blabVisualNotActive:
            return "BLAB visual renderer is not active"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        }
    }
}
