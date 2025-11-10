import Foundation
import CoreImage
import AVFoundation
import UIKit

/// Real-time Video Effects Engine
///
/// Features:
/// - Audio-reactive video effects
/// - CoreImage filter chains
/// - Chroma key / green screen
/// - Camera input processing
/// - Bio-reactive video parameters
@MainActor
class VideoEffectsEngine: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether effects are active
    @Published var isActive: Bool = false

    /// Current effect preset
    @Published var currentPreset: EffectPreset = .none

    /// Effect intensity (0-1)
    @Published var intensity: Double = 1.0

    // MARK: - CoreImage Context

    private let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
        .outputColorSpace: CGColorSpaceCreateDeviceRGB()
    ])

    // MARK: - Effect Presets

    enum EffectPreset: String, CaseIterable {
        case none = "None"
        case audioReactive = "Audio Reactive"
        case chromaKey = "Chroma Key"
        case kaleidoscope = "Kaleidoscope"
        case pixelate = "Pixelate"
        case bloom = "Bloom"
        case vortex = "Vortex"
        case crystallize = "Crystallize"
        case edgeGlow = "Edge Glow"
        case colorInvert = "Color Invert"
        case thermal = "Thermal"
        case comicBook = "Comic Book"
    }

    // MARK: - Audio Reactive Parameters

    private var audioLevel: Float = 0.0
    private var audioFrequency: Float = 0.0
    private var fftMagnitudes: [Float] = []

    // MARK: - Bio Reactive Parameters

    private var hrvCoherence: Double = 50.0
    private var heartRate: Double = 70.0

    // MARK: - Camera Capture

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    // MARK: - Public API

    /// Start video effects engine
    func start() {
        guard !isActive else { return }
        isActive = true
        print("🎬 VideoEffectsEngine started")
    }

    /// Stop video effects engine
    func stop() {
        isActive = false
        stopCameraCapture()
        print("🎬 VideoEffectsEngine stopped")
    }

    /// Set effect preset
    func setPreset(_ preset: EffectPreset) {
        currentPreset = preset
        print("🎬 Effect preset: \(preset.rawValue)")
    }

    /// Apply effects to image
    func applyEffects(to image: UIImage) -> UIImage {
        guard isActive, currentPreset != .none else { return image }
        guard let ciImage = CIImage(image: image) else { return image }

        var processedImage = ciImage

        // Apply selected effect
        switch currentPreset {
        case .none:
            break

        case .audioReactive:
            processedImage = applyAudioReactiveEffect(to: processedImage)

        case .chromaKey:
            processedImage = applyChromaKey(to: processedImage, targetColor: .green)

        case .kaleidoscope:
            processedImage = applyKaleidoscope(to: processedImage, count: Int(audioLevel * 12) + 3)

        case .pixelate:
            processedImage = applyPixelate(to: processedImage, scale: Double(10 + audioLevel * 40))

        case .bloom:
            processedImage = applyBloom(to: processedImage, intensity: intensity)

        case .vortex:
            processedImage = applyVortex(to: processedImage, angle: Double(audioLevel * 360))

        case .crystallize:
            processedImage = applyCrystallize(to: processedImage, radius: Double(10 + audioLevel * 50))

        case .edgeGlow:
            processedImage = applyEdgeGlow(to: processedImage)

        case .colorInvert:
            processedImage = applyColorInvert(to: processedImage)

        case .thermal:
            processedImage = applyThermalEffect(to: processedImage)

        case .comicBook:
            processedImage = applyComicBook(to: processedImage)
        }

        // Render to UIImage
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    /// Update audio parameters for reactive effects
    func updateAudioParameters(level: Float, frequency: Float, fft: [Float]) {
        audioLevel = level
        audioFrequency = frequency
        fftMagnitudes = fft
    }

    /// Update bio parameters for reactive effects
    func updateBioParameters(hrv: Double, heartRate: Double, coherence: Double) {
        self.hrvCoherence = coherence
        self.heartRate = heartRate
    }

    /// Start camera capture
    func startCameraCapture(position: AVCaptureDevice.Position = .front, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) throws {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        // Find camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw VideoEffectsError.cameraNotAvailable
        }

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw VideoEffectsError.cannotAddInput
        }
        session.addInput(input)

        // Add output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "com.blab.video"))
        guard session.canAddOutput(output) else {
            throw VideoEffectsError.cannotAddOutput
        }
        session.addOutput(output)

        captureSession = session
        videoOutput = output
        currentCameraPosition = position

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        print("🎬 Camera capture started (\(position == .front ? "front" : "back"))")
    }

    /// Stop camera capture
    func stopCameraCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        print("🎬 Camera capture stopped")
    }

    /// Switch camera
    func switchCamera() throws {
        guard let session = captureSession else { return }

        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front

        session.beginConfiguration()

        // Remove old input
        for input in session.inputs {
            session.removeInput(input)
        }

        // Add new input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            throw VideoEffectsError.cameraNotAvailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw VideoEffectsError.cannotAddInput
        }
        session.addInput(input)

        session.commitConfiguration()
        currentCameraPosition = newPosition

        print("🎬 Camera switched to \(newPosition == .front ? "front" : "back")")
    }

    // MARK: - Effect Implementations

    private func applyAudioReactiveEffect(to image: CIImage) -> CIImage {
        // Hue rotation based on audio frequency
        let hueAngle = Double(audioFrequency / 1000.0) * .pi

        guard let filter = CIFilter(name: "CIHueAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(hueAngle, forKey: kCIInputAngleKey)

        var output = filter.outputImage ?? image

        // Exposure based on audio level
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return output }
        exposureFilter.setValue(output, forKey: kCIInputImageKey)
        exposureFilter.setValue(Double(audioLevel) * 0.5, forKey: kCIInputEVKey)

        return exposureFilter.outputImage ?? output
    }

    private func applyChromaKey(to image: CIImage, targetColor: UIColor) -> CIImage {
        guard let filter = CIFilter(name: "CIChromaKeyFilter") else {
            // Fallback: manual chroma key
            return applyManualChromaKey(to: image, targetColor: targetColor)
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIColor(color: targetColor), forKey: "inputColor")
        filter.setValue(0.4, forKey: "inputThreshold")
        filter.setValue(0.1, forKey: "inputSmoothing")

        return filter.outputImage ?? image
    }

    private func applyManualChromaKey(to image: CIImage, targetColor: UIColor) -> CIImage {
        // Simple green screen using color cube
        let greenMin = CIVector(x: 0, y: 0.3, z: 0)
        let greenMax = CIVector(x: 0.3, y: 1, z: 0.3)

        guard let filter = CIFilter(name: "CIColorCube") else { return image }

        // Create color cube data (simplified)
        let size = 64
        let cubeData = createChromaKeyCubeData(size: size, targetColor: targetColor)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(size, forKey: "inputCubeDimension")
        filter.setValue(cubeData, forKey: "inputCubeData")

        return filter.outputImage ?? image
    }

    private func createChromaKeyCubeData(size: Int, targetColor: UIColor) -> Data {
        var cubeData = Data(count: size * size * size * 4)

        var rgb: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) = (0, 0, 0, 0)
        targetColor.getRed(&rgb.r, green: &rgb.g, blue: &rgb.b, alpha: &rgb.a)

        let threshold: CGFloat = 0.4

        cubeData.withUnsafeMutableBytes { ptr in
            let buffer = ptr.bindMemory(to: Float.self)

            for z in 0..<size {
                for y in 0..<size {
                    for x in 0..<size {
                        let r = Float(x) / Float(size - 1)
                        let g = Float(y) / Float(size - 1)
                        let b = Float(z) / Float(size - 1)

                        let idx = (z * size * size + y * size + x) * 4

                        // Check if color is close to target (green screen)
                        let distance = sqrt(
                            pow(r - Float(rgb.r), 2) +
                            pow(g - Float(rgb.g), 2) +
                            pow(b - Float(rgb.b), 2)
                        )

                        if distance < Float(threshold) {
                            // Make transparent
                            buffer[idx] = r
                            buffer[idx + 1] = g
                            buffer[idx + 2] = b
                            buffer[idx + 3] = 0  // Alpha = 0 (transparent)
                        } else {
                            // Keep original
                            buffer[idx] = r
                            buffer[idx + 1] = g
                            buffer[idx + 2] = b
                            buffer[idx + 3] = 1  // Alpha = 1 (opaque)
                        }
                    }
                }
            }
        }

        return cubeData
    }

    private func applyKaleidoscope(to image: CIImage, count: Int) -> CIImage {
        guard let filter = CIFilter(name: "CIKaleidoscope") else { return image }

        let center = CIVector(x: image.extent.width / 2, y: image.extent.height / 2)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(count, forKey: "inputCount")
        filter.setValue(center, forKey: kCIInputCenterKey)
        filter.setValue(Double.pi / 3, forKey: kCIInputAngleKey)

        return filter.outputImage ?? image
    }

    private func applyPixelate(to image: CIImage, scale: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIPixellate") else { return image }

        let center = CIVector(x: image.extent.width / 2, y: image.extent.height / 2)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(scale * intensity, forKey: kCIInputScaleKey)
        filter.setValue(center, forKey: kCIInputCenterKey)

        return filter.outputImage ?? image
    }

    private func applyBloom(to image: CIImage, intensity: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIBloom") else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(intensity * 10, forKey: kCIInputIntensityKey)
        filter.setValue(25.0, forKey: kCIInputRadiusKey)

        return filter.outputImage ?? image
    }

    private func applyVortex(to image: CIImage, angle: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIVortexDistortion") else { return image }

        let center = CIVector(x: image.extent.width / 2, y: image.extent.height / 2)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(center, forKey: kCIInputCenterKey)
        filter.setValue(angle * intensity, forKey: kCIInputAngleKey)
        filter.setValue(300.0, forKey: kCIInputRadiusKey)

        return filter.outputImage ?? image
    }

    private func applyCrystallize(to image: CIImage, radius: Double) -> CIImage {
        guard let filter = CIFilter(name: "CICrystallize") else { return image }

        let center = CIVector(x: image.extent.width / 2, y: image.extent.height / 2)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(radius * intensity, forKey: kCIInputRadiusKey)
        filter.setValue(center, forKey: kCIInputCenterKey)

        return filter.outputImage ?? image
    }

    private func applyEdgeGlow(to image: CIImage) -> CIImage {
        // Edge detection + glow
        guard let edges = CIFilter(name: "CIEdges"),
              let bloom = CIFilter(name: "CIBloom") else {
            return image
        }

        edges.setValue(image, forKey: kCIInputImageKey)
        edges.setValue(1.0 * intensity, forKey: kCIInputIntensityKey)

        guard let edgeImage = edges.outputImage else { return image }

        bloom.setValue(edgeImage, forKey: kCIInputImageKey)
        bloom.setValue(intensity * 5, forKey: kCIInputIntensityKey)
        bloom.setValue(15.0, forKey: kCIInputRadiusKey)

        guard let glowImage = bloom.outputImage else { return image }

        // Composite
        return glowImage.composited(over: image)
    }

    private func applyColorInvert(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorInvert") else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)

        return filter.outputImage ?? image
    }

    private func applyThermalEffect(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIFalseColor") else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIColor(red: 1, green: 0, blue: 0), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0, green: 0, blue: 1), forKey: "inputColor1")

        return filter.outputImage ?? image
    }

    private func applyComicBook(to image: CIImage) -> CIImage {
        guard let posterize = CIFilter(name: "CIColorPosterize"),
              let edges = CIFilter(name: "CIEdges") else {
            return image
        }

        // Posterize colors
        posterize.setValue(image, forKey: kCIInputImageKey)
        posterize.setValue(6, forKey: "inputLevels")

        guard let posterizedImage = posterize.outputImage else { return image }

        // Add edge lines
        edges.setValue(posterizedImage, forKey: kCIInputImageKey)
        edges.setValue(2.0, forKey: kCIInputIntensityKey)

        guard let edgeImage = edges.outputImage else { return posterizedImage }

        // Composite
        return posterizedImage.applyingFilter("CIMultiplyBlendMode", parameters: [
            kCIInputBackgroundImageKey: edgeImage
        ])
    }

    // MARK: - Errors

    enum VideoEffectsError: Error, LocalizedError {
        case cameraNotAvailable
        case cannotAddInput
        case cannotAddOutput

        var errorDescription: String? {
            switch self {
            case .cameraNotAvailable:
                return "Camera not available"
            case .cannotAddInput:
                return "Cannot add camera input"
            case .cannotAddOutput:
                return "Cannot add video output"
            }
        }
    }
}
