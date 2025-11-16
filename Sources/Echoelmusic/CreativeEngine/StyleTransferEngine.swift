import Foundation
import SwiftUI
import CoreML
import Vision
import CoreImage

/// Real-time neural style transfer using CoreML
/// Applies artistic styles to video frames based on biometric state
///
/// **Style Categories:**
/// - Calm (Low HR): Watercolor, Impressionist
/// - Balanced (Normal HR): Modern, Abstract
/// - Energized (High HR): Expressionist, Neon
///
/// **Performance:**
/// - Optimized CoreML models (FP16 quantized)
/// - Target: 30 FPS @ 512x512
/// - Neural Engine acceleration when available
///
/// **Models Required:**
/// - candy.mlmodel (Pop Art)
/// - mosaic.mlmodel (Mosaic)
/// - udnie.mlmodel (Geometric)
/// - Custom: bio_calm.mlmodel, bio_energized.mlmodel
///
/// **Usage:**
/// ```swift
/// let engine = StyleTransferEngine()
/// let styledImage = try await engine.applyStyle(to: image, style: .calm)
/// ```
@MainActor
public class StyleTransferEngine: ObservableObject {

    // MARK: - Style Categories

    public enum StyleCategory: String, CaseIterable {
        case calm = "Calm"
        case balanced = "Balanced"
        case energized = "Energized"
        case custom = "Custom"

        var description: String {
            switch self {
            case .calm: return "Watercolor & Impressionist (Slow HR)"
            case .balanced: return "Modern & Abstract (Normal HR)"
            case .energized: return "Expressionist & Neon (High HR)"
            case .custom: return "Bio-Reactive Custom Style"
            }
        }

        var color: Color {
            switch self {
            case .calm: return .blue
            case .balanced: return .green
            case .energized: return .orange
            case .custom: return .purple
            }
        }
    }

    // MARK: - Published State

    /// Current active style
    @Published public private(set) var currentStyle: StyleCategory = .balanced

    /// Whether style transfer is enabled
    @Published public var isEnabled: Bool = false

    /// Style intensity (0.0 - 1.0)
    @Published public var intensity: Double = 0.7

    /// Processing FPS
    @Published public private(set) var currentFPS: Double = 0.0

    // MARK: - Private State

    private var models: [StyleCategory: VNCoreMLModel] = [:]
    private var lastProcessTime = Date()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    public init() {
        loadModels()
    }

    // MARK: - Public Methods

    /// Apply style transfer to image
    public func applyStyle(to image: CGImage, style: StyleCategory? = nil) async throws -> CGImage {
        let targetStyle = style ?? currentStyle

        guard isEnabled else { return image }
        guard let model = models[targetStyle] else {
            print("⚠️ StyleTransferEngine: Model not loaded for \(targetStyle.rawValue)")
            return image
        }

        let startTime = Date()

        // Create Vision request
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("❌ StyleTransferEngine: Request error - \(error)")
            }
        }

        request.imageCropAndScaleOption = .scaleFill

        // Perform inference
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        // Extract result
        guard let results = request.results as? [VNPixelBufferObservation],
              let pixelBuffer = results.first?.pixelBuffer else {
            throw StyleTransferError.noResults
        }

        // Convert pixel buffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let outputImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw StyleTransferError.conversionFailed
        }

        // Blend with original based on intensity
        let blendedImage = blendImages(original: image, styled: outputImage, alpha: intensity)

        // Update FPS
        let elapsed = Date().timeIntervalSince(startTime)
        currentFPS = 1.0 / elapsed

        return blendedImage
    }

    /// Select style based on heart rate
    public func selectStyleFromHeartRate(_ heartRate: Double) {
        let newStyle: StyleCategory

        switch heartRate {
        case 0..<70:
            newStyle = .calm
        case 70..<90:
            newStyle = .balanced
        case 90...:
            newStyle = .energized
        default:
            newStyle = .balanced
        }

        if newStyle != currentStyle {
            currentStyle = newStyle
            print("🎨 StyleTransferEngine: Style changed to \(newStyle.rawValue)")
        }
    }

    // MARK: - Private Methods

    private func loadModels() {
        // In production: Load actual CoreML models
        // For now: Placeholder
        print("⚠️ StyleTransferEngine: CoreML models not yet bundled")
        print("   Required models: candy.mlmodel, mosaic.mlmodel, udnie.mlmodel")
        print("   Download from: https://github.com/likedan/Awesome-CoreML-Models")

        // TODO: Load models
        // if let modelURL = Bundle.main.url(forResource: "candy", withExtension: "mlmodelc") {
        //     let model = try? MLModel(contentsOf: modelURL)
        //     let visionModel = try? VNCoreMLModel(for: model)
        //     models[.calm] = visionModel
        // }
    }

    /// Blend original and styled images
    private func blendImages(original: CGImage, styled: CGImage, alpha: Double) -> CGImage {
        let originalCI = CIImage(cgImage: original)
        let styledCI = CIImage(cgImage: styled)

        // Create blend filter
        let filter = CIFilter(name: "CIBlendWithAlphaMask")
        filter?.setValue(originalCI, forKey: kCIInputBackgroundImageKey)
        filter?.setValue(styledCI, forKey: kCIInputImageKey)

        // Use alpha to control blend
        let alphaValue = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(alpha)))
        filter?.setValue(alphaValue, forKey: kCIInputMaskImageKey)

        guard let outputImage = filter?.outputImage,
              let result = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return styled
        }

        return result
    }
}

// MARK: - Errors

public enum StyleTransferError: Error {
    case modelNotLoaded
    case noResults
    case conversionFailed

    var description: String {
        switch self {
        case .modelNotLoaded: return "CoreML model not loaded"
        case .noResults: return "No results from model inference"
        case .conversionFailed: return "Failed to convert pixel buffer to image"
        }
    }
}

// MARK: - SwiftUI View

/// Style transfer preview view
public struct StyleTransferPreviewView: View {

    @StateObject var engine = StyleTransferEngine()
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var previewImage: CGImage?

    public init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    public var body: some View {
        VStack(spacing: 20) {

            // Style selector
            Picker("Style", selection: $engine.currentStyle) {
                ForEach(StyleTransferEngine.StyleCategory.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Preview
            if let image = previewImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))

                            Text("Style Transfer Preview")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    )
            }

            // Intensity slider
            VStack(spacing: 8) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Text("\(Int(engine.intensity * 100))%")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                Slider(value: $engine.intensity, in: 0...1)
                    .tint(.cyan)
            }
            .padding(.horizontal, 20)

            // Enable toggle
            Toggle(isOn: $engine.isEnabled) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.cyan)

                    Text("Enable Style Transfer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
            .padding(.horizontal, 20)

            // FPS indicator
            if engine.isEnabled {
                HStack {
                    Image(systemName: "gauge")
                        .font(.system(size: 12))

                    Text("\(Int(engine.currentFPS)) FPS")
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 20)
        .onChange(of: healthKitManager.heartRate) { heartRate in
            engine.selectStyleFromHeartRate(heartRate)
        }
    }
}

// MARK: - Model Download Instructions

/*
 🎨 STYLE TRANSFER MODELS

 To enable real-time style transfer, download CoreML models:

 1. Visit: https://github.com/likedan/Awesome-CoreML-Models
 2. Download models:
    - FNS-Candy.mlmodel (Pop Art style)
    - FNS-Mosaic.mlmodel (Mosaic style)
    - FNS-Udnie.mlmodel (Geometric style)

 3. Add to Xcode:
    - Drag .mlmodel files into Xcode project
    - Ensure "Target Membership" is checked
    - Xcode will compile to .mlmodelc

 4. Update loadModels() to reference bundled models

 Alternative: Train custom bio-reactive models
 - Use CreateML or Turi Create
 - Train on artwork paired with biometric data
 - Export as CoreML

 Performance Tips:
 - Use FP16 quantized models for speed
 - Enable Neural Engine: model.configuration.computeUnits = .all
 - Pre-warm models on app launch
 - Use Metal for post-processing
 */
