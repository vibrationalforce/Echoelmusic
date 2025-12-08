// VideoLUTSystem.swift
// Echoelmusic - Professional Video LUT (Look-Up Table) System
//
// A++ Ultrahardthink Implementation
// Provides comprehensive color grading including:
// - 1D and 3D LUT support
// - .cube file import/export
// - Real-time LUT application
// - LUT blending and interpolation
// - Built-in creative LUTs
// - Bio-reactive color grading
// - HDR LUT support

import Foundation
import Combine
import CoreImage
import Accelerate
import os.log

#if canImport(Metal)
import Metal
#endif

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.video", category: "LUT")

// MARK: - LUT Types

public enum LUTType: String, Codable, CaseIterable, Sendable {
    case oneDimensional = "1D LUT"
    case threeDimensional = "3D LUT"

    public var description: String {
        switch self {
        case .oneDimensional:
            return "Single curve adjustments (gamma, contrast)"
        case .threeDimensional:
            return "Full color transform (color grading, film looks)"
        }
    }
}

// MARK: - LUT Data

/// Represents a color Look-Up Table
public struct LUTData: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: LUTType
    public var size: Int  // Cube size (e.g., 17, 33, 65 for 3D)
    public var domainMin: SIMD3<Float>
    public var domainMax: SIMD3<Float>
    public var data: [SIMD3<Float>]  // RGB values
    public var metadata: LUTMetadata

    public struct LUTMetadata: Codable, Sendable {
        public var title: String?
        public var author: String?
        public var copyright: String?
        public var comments: [String]
        public var inputColorSpace: String?
        public var outputColorSpace: String?

        public init() {
            comments = []
        }
    }

    public init(
        name: String,
        type: LUTType,
        size: Int,
        domainMin: SIMD3<Float> = SIMD3(0, 0, 0),
        domainMax: SIMD3<Float> = SIMD3(1, 1, 1)
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.size = size
        self.domainMin = domainMin
        self.domainMax = domainMax
        self.metadata = LUTMetadata()

        // Initialize identity LUT
        let dataSize = type == .oneDimensional ? size : size * size * size
        self.data = [SIMD3<Float>](repeating: SIMD3(0, 0, 0), count: dataSize)

        if type == .oneDimensional {
            for i in 0..<size {
                let value = Float(i) / Float(size - 1)
                self.data[i] = SIMD3(value, value, value)
            }
        } else {
            for b in 0..<size {
                for g in 0..<size {
                    for r in 0..<size {
                        let index = r + g * size + b * size * size
                        let rf = Float(r) / Float(size - 1)
                        let gf = Float(g) / Float(size - 1)
                        let bf = Float(b) / Float(size - 1)
                        self.data[index] = SIMD3(rf, gf, bf)
                    }
                }
            }
        }
    }

    /// Look up a color value in the LUT
    public func lookup(_ input: SIMD3<Float>) -> SIMD3<Float> {
        // Normalize input to domain
        let normalized = (input - domainMin) / (domainMax - domainMin)
        let clamped = simd_clamp(normalized, SIMD3(0, 0, 0), SIMD3(1, 1, 1))

        if type == .oneDimensional {
            return lookup1D(clamped)
        } else {
            return lookup3D(clamped)
        }
    }

    private func lookup1D(_ input: SIMD3<Float>) -> SIMD3<Float> {
        // Separate 1D lookup for each channel
        func lookupChannel(_ value: Float, channel: Int) -> Float {
            let scaled = value * Float(size - 1)
            let low = Int(scaled)
            let high = min(low + 1, size - 1)
            let frac = scaled - Float(low)

            let lowValue = data[low][channel]
            let highValue = data[high][channel]

            return lowValue + frac * (highValue - lowValue)
        }

        return SIMD3(
            lookupChannel(input.x, channel: 0),
            lookupChannel(input.y, channel: 1),
            lookupChannel(input.z, channel: 2)
        )
    }

    private func lookup3D(_ input: SIMD3<Float>) -> SIMD3<Float> {
        // Trilinear interpolation
        let scaled = input * Float(size - 1)

        let r0 = Int(scaled.x)
        let g0 = Int(scaled.y)
        let b0 = Int(scaled.z)

        let r1 = min(r0 + 1, size - 1)
        let g1 = min(g0 + 1, size - 1)
        let b1 = min(b0 + 1, size - 1)

        let fr = scaled.x - Float(r0)
        let fg = scaled.y - Float(g0)
        let fb = scaled.z - Float(b0)

        // 8 corners of the cube
        let c000 = data[r0 + g0 * size + b0 * size * size]
        let c100 = data[r1 + g0 * size + b0 * size * size]
        let c010 = data[r0 + g1 * size + b0 * size * size]
        let c110 = data[r1 + g1 * size + b0 * size * size]
        let c001 = data[r0 + g0 * size + b1 * size * size]
        let c101 = data[r1 + g0 * size + b1 * size * size]
        let c011 = data[r0 + g1 * size + b1 * size * size]
        let c111 = data[r1 + g1 * size + b1 * size * size]

        // Trilinear interpolation
        let c00 = c000 * (1 - fr) + c100 * fr
        let c01 = c001 * (1 - fr) + c101 * fr
        let c10 = c010 * (1 - fr) + c110 * fr
        let c11 = c011 * (1 - fr) + c111 * fr

        let c0 = c00 * (1 - fg) + c10 * fg
        let c1 = c01 * (1 - fg) + c11 * fg

        return c0 * (1 - fb) + c1 * fb
    }
}

// MARK: - Cube File Parser

public final class CubeFileParser {
    public enum ParseError: Error, LocalizedError {
        case invalidFormat
        case missingSize
        case invalidData
        case unsupportedType

        public var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid .cube file format"
            case .missingSize: return "Missing LUT_3D_SIZE or LUT_1D_SIZE"
            case .invalidData: return "Invalid color data"
            case .unsupportedType: return "Unsupported LUT type"
            }
        }
    }

    /// Parse a .cube file
    public static func parse(_ content: String) throws -> LUTData {
        var lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        var title: String?
        var size: Int?
        var type: LUTType?
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var data: [SIMD3<Float>] = []

        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            if components.isEmpty { continue }

            switch components[0].uppercased() {
            case "TITLE":
                title = components.dropFirst().joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            case "LUT_3D_SIZE":
                if let s = Int(components[1]) {
                    size = s
                    type = .threeDimensional
                }

            case "LUT_1D_SIZE":
                if let s = Int(components[1]) {
                    size = s
                    type = .oneDimensional
                }

            case "DOMAIN_MIN":
                if components.count >= 4,
                   let r = Float(components[1]),
                   let g = Float(components[2]),
                   let b = Float(components[3]) {
                    domainMin = SIMD3(r, g, b)
                }

            case "DOMAIN_MAX":
                if components.count >= 4,
                   let r = Float(components[1]),
                   let g = Float(components[2]),
                   let b = Float(components[3]) {
                    domainMax = SIMD3(r, g, b)
                }

            default:
                // Try to parse as color data
                if components.count >= 3,
                   let r = Float(components[0]),
                   let g = Float(components[1]),
                   let b = Float(components[2]) {
                    data.append(SIMD3(r, g, b))
                }
            }
        }

        guard let lutSize = size, let lutType = type else {
            throw ParseError.missingSize
        }

        let expectedSize = lutType == .oneDimensional ? lutSize : lutSize * lutSize * lutSize
        guard data.count == expectedSize else {
            throw ParseError.invalidData
        }

        var lut = LUTData(name: title ?? "Imported LUT", type: lutType, size: lutSize, domainMin: domainMin, domainMax: domainMax)
        lut.data = data

        return lut
    }

    /// Export LUT to .cube format
    public static func export(_ lut: LUTData) -> String {
        var lines: [String] = []

        // Header
        lines.append("# Created by Echoelmusic")
        lines.append("TITLE \"\(lut.name)\"")

        if lut.type == .threeDimensional {
            lines.append("LUT_3D_SIZE \(lut.size)")
        } else {
            lines.append("LUT_1D_SIZE \(lut.size)")
        }

        lines.append("DOMAIN_MIN \(lut.domainMin.x) \(lut.domainMin.y) \(lut.domainMin.z)")
        lines.append("DOMAIN_MAX \(lut.domainMax.x) \(lut.domainMax.y) \(lut.domainMax.z)")
        lines.append("")

        // Data
        for color in lut.data {
            lines.append(String(format: "%.6f %.6f %.6f", color.x, color.y, color.z))
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - LUT Filter

/// Core Image filter for applying LUTs
public class LUTFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    @objc dynamic var lutData: Data?
    @objc dynamic var lutSize: Int = 33
    @objc dynamic var intensity: Float = 1.0

    public override var outputImage: CIImage? {
        guard let input = inputImage,
              let data = lutData else {
            return inputImage
        }

        // Create color cube from LUT data
        guard let colorCubeFilter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return input
        }

        colorCubeFilter.setValue(data, forKey: "inputCubeData")
        colorCubeFilter.setValue(lutSize, forKey: "inputCubeDimension")
        colorCubeFilter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        colorCubeFilter.setValue(input, forKey: kCIInputImageKey)

        guard let lutOutput = colorCubeFilter.outputImage else {
            return input
        }

        // Blend with original based on intensity
        if intensity >= 1.0 {
            return lutOutput
        }

        let blendFilter = CIFilter(name: "CISourceOverCompositing")
        blendFilter?.setValue(lutOutput.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity))
        ]), forKey: kCIInputImageKey)
        blendFilter?.setValue(input.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(1.0 - intensity))
        ]), forKey: kCIInputBackgroundImageKey)

        return blendFilter?.outputImage
    }
}

// MARK: - Video LUT Manager

@MainActor
public final class VideoLUTManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = VideoLUTManager()

    // MARK: - Published State

    @Published public private(set) var availableLUTs: [LUTData] = []
    @Published public var currentLUT: LUTData?
    @Published public var intensity: Float = 1.0
    @Published public private(set) var isProcessing: Bool = false

    // MARK: - Private Properties

    private var ciContext: CIContext?

    #if canImport(Metal)
    private var metalDevice: MTLDevice?
    #endif

    // MARK: - Initialization

    private init() {
        setupCoreImage()
        loadBuiltInLUTs()
    }

    private func setupCoreImage() {
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            metalDevice = device
            ciContext = CIContext(mtlDevice: device)
        } else {
            ciContext = CIContext()
        }
        #else
        ciContext = CIContext()
        #endif
    }

    // MARK: - LUT Management

    public func addLUT(_ lut: LUTData) {
        availableLUTs.append(lut)
        logger.info("Added LUT: \(lut.name)")
    }

    public func removeLUT(id: UUID) {
        availableLUTs.removeAll { $0.id == id }
        if currentLUT?.id == id {
            currentLUT = nil
        }
    }

    public func selectLUT(_ lut: LUTData?) {
        currentLUT = lut
        logger.info("Selected LUT: \(lut?.name ?? "None")")
    }

    // MARK: - Import/Export

    public func importCubeFile(from url: URL) async throws -> LUTData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lut = try CubeFileParser.parse(content)
        addLUT(lut)
        return lut
    }

    public func exportCubeFile(_ lut: LUTData, to url: URL) throws {
        let content = CubeFileParser.export(lut)
        try content.write(to: url, atomically: true, encoding: .utf8)
        logger.info("Exported LUT to: \(url.path)")
    }

    // MARK: - Image Processing

    public func applyLUT(to image: CIImage) -> CIImage? {
        guard let lut = currentLUT else { return image }

        // Convert LUT data to Core Image format
        let cubeData = convertToCubeData(lut)

        let filter = LUTFilter()
        filter.inputImage = image
        filter.lutData = cubeData
        filter.lutSize = lut.size
        filter.intensity = intensity

        return filter.outputImage
    }

    private func convertToCubeData(_ lut: LUTData) -> Data {
        var floatData = [Float]()
        floatData.reserveCapacity(lut.data.count * 4)

        for color in lut.data {
            floatData.append(color.x)
            floatData.append(color.y)
            floatData.append(color.z)
            floatData.append(1.0)  // Alpha
        }

        return floatData.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - LUT Generation

    /// Generate a custom LUT from parameters
    public func generateLUT(
        name: String,
        size: Int = 33,
        adjustments: ColorAdjustments
    ) -> LUTData {
        var lut = LUTData(name: name, type: .threeDimensional, size: size)

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let index = r + g * size + b * size * size
                    var color = SIMD3<Float>(
                        Float(r) / Float(size - 1),
                        Float(g) / Float(size - 1),
                        Float(b) / Float(size - 1)
                    )

                    // Apply adjustments
                    color = applyAdjustments(color, adjustments: adjustments)

                    lut.data[index] = color
                }
            }
        }

        return lut
    }

    public struct ColorAdjustments: Sendable {
        public var exposure: Float = 0           // -2 to 2
        public var contrast: Float = 1           // 0 to 2
        public var saturation: Float = 1         // 0 to 2
        public var temperature: Float = 0        // -100 to 100
        public var tint: Float = 0               // -100 to 100
        public var highlights: Float = 0         // -1 to 1
        public var shadows: Float = 0            // -1 to 1
        public var lift: SIMD3<Float> = .zero    // RGB lift
        public var gamma: SIMD3<Float> = .one    // RGB gamma
        public var gain: SIMD3<Float> = .one     // RGB gain

        public init() {}
    }

    private func applyAdjustments(_ input: SIMD3<Float>, adjustments: ColorAdjustments) -> SIMD3<Float> {
        var color = input

        // Exposure
        color *= pow(2.0, adjustments.exposure)

        // Lift/Gamma/Gain (CDL)
        color = adjustments.lift + (color - adjustments.lift) * adjustments.gain
        color = pow(color, 1.0 / adjustments.gamma)

        // Contrast
        color = (color - 0.5) * adjustments.contrast + 0.5

        // Saturation
        let luma = color.x * 0.2126 + color.y * 0.7152 + color.z * 0.0722
        let lumaVec = SIMD3<Float>(repeating: luma)
        color = lumaVec + (color - lumaVec) * adjustments.saturation

        // Temperature/Tint (simplified)
        if adjustments.temperature != 0 {
            let tempFactor = adjustments.temperature / 100.0
            color.x += tempFactor * 0.1
            color.z -= tempFactor * 0.1
        }

        if adjustments.tint != 0 {
            let tintFactor = adjustments.tint / 100.0
            color.y += tintFactor * 0.1
        }

        // Shadows/Highlights
        if adjustments.shadows != 0 || adjustments.highlights != 0 {
            let shadowMask = pow(1.0 - luma, 2)
            let highlightMask = pow(luma, 2)

            color += SIMD3<Float>(repeating: adjustments.shadows * shadowMask * 0.2)
            color += SIMD3<Float>(repeating: adjustments.highlights * highlightMask * 0.2)
        }

        // Clamp
        return simd_clamp(color, SIMD3(0, 0, 0), SIMD3(1, 1, 1))
    }

    // MARK: - LUT Blending

    /// Blend two LUTs together
    public func blendLUTs(_ lut1: LUTData, _ lut2: LUTData, factor: Float) -> LUTData? {
        guard lut1.type == lut2.type && lut1.size == lut2.size else {
            logger.error("Cannot blend LUTs with different types or sizes")
            return nil
        }

        var result = lut1
        result.name = "Blend: \(lut1.name) + \(lut2.name)"

        for i in 0..<result.data.count {
            result.data[i] = lut1.data[i] * (1 - factor) + lut2.data[i] * factor
        }

        return result
    }

    // MARK: - Bio-Reactive Color Grading

    /// Generate LUT adjustments based on bio-data
    public func bioReactiveAdjustments(
        heartRate: Float,
        hrv: Float,
        coherence: Float
    ) -> ColorAdjustments {
        var adjustments = ColorAdjustments()

        // High coherence = warmer, more saturated
        adjustments.saturation = 0.8 + coherence * 0.4
        adjustments.temperature = coherence * 30 - 15

        // HRV affects contrast
        adjustments.contrast = 0.9 + hrv / 100.0 * 0.3

        // Heart rate affects brightness/exposure
        let normalizedHR = (heartRate - 60) / 60  // 0 at 60 BPM, 1 at 120 BPM
        adjustments.exposure = normalizedHR * -0.2  // Slightly darker when excited

        // Stressed (low HRV) = cooler shadows
        if hrv < 30 {
            adjustments.lift = SIMD3(0, 0, 0.02)  // Blue lift
        }

        // Relaxed (high coherence) = warm highlights
        if coherence > 0.7 {
            adjustments.gain = SIMD3(1.02, 1.0, 0.98)  // Warm gain
        }

        return adjustments
    }

    // MARK: - Built-In LUTs

    private func loadBuiltInLUTs() {
        // Cinematic looks
        availableLUTs.append(createCinematicLUT())
        availableLUTs.append(createTealOrangeLUT())
        availableLUTs.append(createVintageLUT())
        availableLUTs.append(createBleachBypassLUT())
        availableLUTs.append(createCrossPro cessLUT())
        availableLUTs.append(createFilmNoirLUT())
        availableLUTs.append(createVaporwaveLUT())
        availableLUTs.append(createCyberpunkLUT())
        availableLUTs.append(createPastelDreamLUT())
        availableLUTs.append(createHighContrastBWLUT())

        logger.info("Loaded \(availableLUTs.count) built-in LUTs")
    }

    private func createCinematicLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.contrast = 1.15
        adjustments.saturation = 0.9
        adjustments.shadows = 0.05
        adjustments.highlights = -0.1
        adjustments.lift = SIMD3(0.02, 0.01, 0.03)

        return generateLUT(name: "Cinematic", adjustments: adjustments)
    }

    private func createTealOrangeLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.contrast = 1.1
        adjustments.temperature = 15
        adjustments.lift = SIMD3(0, 0.02, 0.04)
        adjustments.gain = SIMD3(1.05, 0.98, 0.95)

        return generateLUT(name: "Teal & Orange", adjustments: adjustments)
    }

    private func createVintageLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 0.75
        adjustments.contrast = 0.95
        adjustments.lift = SIMD3(0.03, 0.02, 0.01)
        adjustments.gamma = SIMD3(1.1, 1.05, 1.0)

        return generateLUT(name: "Vintage Film", adjustments: adjustments)
    }

    private func createBleachBypassLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 0.6
        adjustments.contrast = 1.3
        adjustments.highlights = -0.15

        return generateLUT(name: "Bleach Bypass", adjustments: adjustments)
    }

    private func createCrossPro cessLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 1.2
        adjustments.lift = SIMD3(0, 0.03, 0.05)
        adjustments.gain = SIMD3(1.1, 1.0, 0.9)

        return generateLUT(name: "Cross Process", adjustments: adjustments)
    }

    private func createFilmNoirLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 0.0
        adjustments.contrast = 1.4
        adjustments.shadows = -0.1
        adjustments.highlights = 0.1

        return generateLUT(name: "Film Noir", adjustments: adjustments)
    }

    private func createVaporwaveLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 1.3
        adjustments.lift = SIMD3(0.05, 0, 0.08)
        adjustments.gain = SIMD3(1.0, 0.95, 1.1)
        adjustments.tint = 20

        return generateLUT(name: "Vaporwave", adjustments: adjustments)
    }

    private func createCyberpunkLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.contrast = 1.25
        adjustments.saturation = 1.2
        adjustments.lift = SIMD3(0, 0.02, 0.05)
        adjustments.gain = SIMD3(1.1, 0.95, 1.05)
        adjustments.shadows = 0.05

        return generateLUT(name: "Cyberpunk", adjustments: adjustments)
    }

    private func createPastelDreamLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 0.7
        adjustments.contrast = 0.85
        adjustments.exposure = 0.15
        adjustments.lift = SIMD3(0.05, 0.05, 0.05)

        return generateLUT(name: "Pastel Dream", adjustments: adjustments)
    }

    private func createHighContrastBWLUT() -> LUTData {
        var adjustments = ColorAdjustments()
        adjustments.saturation = 0.0
        adjustments.contrast = 1.5
        adjustments.shadows = -0.15
        adjustments.highlights = 0.15

        return generateLUT(name: "High Contrast B&W", adjustments: adjustments)
    }
}

// MARK: - LUT Presets

extension VideoLUTManager {
    public enum LUTPreset: String, CaseIterable {
        case none = "None"
        case cinematic = "Cinematic"
        case tealOrange = "Teal & Orange"
        case vintage = "Vintage Film"
        case bleachBypass = "Bleach Bypass"
        case crossProcess = "Cross Process"
        case filmNoir = "Film Noir"
        case vaporwave = "Vaporwave"
        case cyberpunk = "Cyberpunk"
        case pastelDream = "Pastel Dream"
        case highContrastBW = "High Contrast B&W"
    }

    public func applyPreset(_ preset: LUTPreset) {
        if preset == .none {
            currentLUT = nil
            return
        }

        currentLUT = availableLUTs.first { $0.name == preset.rawValue }
    }
}
