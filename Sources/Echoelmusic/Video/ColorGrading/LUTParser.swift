import Foundation
import simd

/// LUT (Look-Up Table) Parser for .cube and .3dl files
///
/// Supports:
/// - .cube files (32x32x32, 64x64x64 common sizes)
/// - .3dl files (Autodesk/Lustre format)
/// - Adobe Speedgrade LUTs
/// - DaVinci Resolve LUTs
///
/// LUT File Format:
/// - 3D LUT maps input RGB to output RGB
/// - Typically 33x33x33 (33³ = 35,937 entries)
/// - Or 65x65x65 (65³ = 274,625 entries)
class LUTParser {

    // MARK: - LUT Data Structure

    struct LUT3D {
        let size: Int                // Grid size (e.g., 33 for 33x33x33)
        let data: [SIMD3<Float>]     // RGB values (size³ entries)
        let title: String?
        let domain: (min: SIMD3<Float>, max: SIMD3<Float>)

        var totalEntries: Int {
            return size * size * size
        }
    }

    enum LUTError: Error {
        case invalidFormat
        case unsupportedSize
        case missingData
        case parseError(String)
    }


    // MARK: - Public API

    /// Parse .cube file
    static func parseCube(from url: URL) throws -> LUT3D {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parseCubeContent(content, filename: url.lastPathComponent)
    }

    /// Parse .3dl file
    static func parse3DL(from url: URL) throws -> LUT3D {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse3DLContent(content, filename: url.lastPathComponent)
    }

    /// Auto-detect and parse LUT file
    static func parse(from url: URL) throws -> LUT3D {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "cube":
            return try parseCube(from: url)
        case "3dl":
            return try parse3DL(from: url)
        default:
            throw LUTError.invalidFormat
        }
    }


    // MARK: - .cube Parser

    private static func parseCubeContent(_ content: String, filename: String) throws -> LUT3D {
        var title: String?
        var size: Int?
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var lutData: [SIMD3<Float>] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse metadata
            if trimmed.hasPrefix("TITLE") {
                title = trimmed.replacingOccurrences(of: "TITLE", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                continue
            }

            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if let lastComponent = components.last, let parsedSize = Int(lastComponent) {
                    size = parsedSize
                }
                continue
            }

            if trimmed.hasPrefix("DOMAIN_MIN") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 4 {
                    domainMin = SIMD3<Float>(
                        Float(components[1]) ?? 0,
                        Float(components[2]) ?? 0,
                        Float(components[3]) ?? 0
                    )
                }
                continue
            }

            if trimmed.hasPrefix("DOMAIN_MAX") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 4 {
                    domainMax = SIMD3<Float>(
                        Float(components[1]) ?? 1,
                        Float(components[2]) ?? 1,
                        Float(components[3]) ?? 1
                    )
                }
                continue
            }

            // Parse RGB data
            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count >= 3 {
                if let r = Float(components[0]),
                   let g = Float(components[1]),
                   let b = Float(components[2]) {
                    lutData.append(SIMD3<Float>(r, g, b))
                }
            }
        }

        // Validate
        guard let lutSize = size else {
            throw LUTError.parseError("Missing LUT_3D_SIZE")
        }

        let expectedEntries = lutSize * lutSize * lutSize
        guard lutData.count == expectedEntries else {
            throw LUTError.parseError("Expected \(expectedEntries) entries, got \(lutData.count)")
        }

        return LUT3D(
            size: lutSize,
            data: lutData,
            title: title ?? filename,
            domain: (min: domainMin, max: domainMax)
        )
    }


    // MARK: - .3dl Parser

    private static func parse3DLContent(_ content: String, filename: String) throws -> LUT3D {
        var lutData: [SIMD3<Float>] = []
        var size = 0

        let lines = content.components(separatedBy: .newlines)

        // .3dl format is simpler - just RGB triplets
        // Typically 32x32x32 (32768 entries) or 16x16x16 (4096 entries)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count >= 3 {
                // .3dl values are typically 0-4095 (12-bit) or 0-1023 (10-bit)
                // Normalize to 0-1 range
                if let r = Float(components[0]),
                   let g = Float(components[1]),
                   let b = Float(components[2]) {

                    // Auto-detect range (most are 0-4095 for 12-bit)
                    let maxValue: Float = (r > 1.0 || g > 1.0 || b > 1.0) ? 4095.0 : 1.0

                    lutData.append(SIMD3<Float>(
                        r / maxValue,
                        g / maxValue,
                        b / maxValue
                    ))
                }
            }
        }

        // Infer size from entry count
        let entryCount = lutData.count
        size = Int(round(pow(Double(entryCount), 1.0/3.0)))

        let expectedEntries = size * size * size
        guard lutData.count == expectedEntries else {
            throw LUTError.parseError("Invalid .3dl entry count: \(lutData.count)")
        }

        return LUT3D(
            size: size,
            data: lutData,
            title: filename,
            domain: (min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(1, 1, 1))
        )
    }


    // MARK: - LUT Application Helper

    /// Sample LUT at normalized RGB position (0-1)
    static func sample(lut: LUT3D, at rgb: SIMD3<Float>) -> SIMD3<Float> {
        // Clamp input to domain
        let clamped = clamp(rgb, min: lut.domain.min, max: lut.domain.max)

        // Normalize to LUT grid space
        let normalized = (clamped - lut.domain.min) / (lut.domain.max - lut.domain.min)

        // Scale to LUT size
        let scaled = normalized * Float(lut.size - 1)

        // Trilinear interpolation
        let r0 = Int(floor(scaled.x))
        let g0 = Int(floor(scaled.y))
        let b0 = Int(floor(scaled.z))

        let r1 = min(r0 + 1, lut.size - 1)
        let g1 = min(g0 + 1, lut.size - 1)
        let b1 = min(b0 + 1, lut.size - 1)

        let fr = scaled.x - Float(r0)
        let fg = scaled.y - Float(g0)
        let fb = scaled.z - Float(b0)

        // Get 8 corner values
        let c000 = lut.data[index(r: r0, g: g0, b: b0, size: lut.size)]
        let c100 = lut.data[index(r: r1, g: g0, b: b0, size: lut.size)]
        let c010 = lut.data[index(r: r0, g: g1, b: b0, size: lut.size)]
        let c110 = lut.data[index(r: r1, g: g1, b: b0, size: lut.size)]
        let c001 = lut.data[index(r: r0, g: g0, b: b1, size: lut.size)]
        let c101 = lut.data[index(r: r1, g: g0, b: b1, size: lut.size)]
        let c011 = lut.data[index(r: r0, g: g1, b: b1, size: lut.size)]
        let c111 = lut.data[index(r: r1, g: g1, b: b1, size: lut.size)]

        // Trilinear interpolation
        let c00 = mix(c000, c100, t: fr)
        let c10 = mix(c010, c110, t: fr)
        let c01 = mix(c001, c101, t: fr)
        let c11 = mix(c011, c111, t: fr)

        let c0 = mix(c00, c10, t: fg)
        let c1 = mix(c01, c11, t: fg)

        return mix(c0, c1, t: fb)
    }

    /// Get 1D index from 3D coordinates
    private static func index(r: Int, g: Int, b: Int, size: Int) -> Int {
        return b * size * size + g * size + r
    }

    /// Linear interpolation
    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a * (1.0 - t) + b * t
    }

    /// Clamp vector to range
    private static func clamp(_ v: SIMD3<Float>, min: SIMD3<Float>, max: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            Swift.max(min.x, Swift.min(max.x, v.x)),
            Swift.max(min.y, Swift.min(max.y, v.y)),
            Swift.max(min.z, Swift.min(max.z, v.z))
        )
    }


    // MARK: - LUT Export

    /// Export LUT to .cube format
    static func exportToCube(lut: LUT3D, to url: URL) throws {
        var content = ""

        // Header
        if let title = lut.title {
            content += "TITLE \"\(title)\"\n"
        }
        content += "LUT_3D_SIZE \(lut.size)\n"
        content += "DOMAIN_MIN \(lut.domain.min.x) \(lut.domain.min.y) \(lut.domain.min.z)\n"
        content += "DOMAIN_MAX \(lut.domain.max.x) \(lut.domain.max.y) \(lut.domain.max.z)\n"
        content += "\n"

        // Data
        for rgb in lut.data {
            content += "\(rgb.x) \(rgb.y) \(rgb.z)\n"
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        print("💾 Exported LUT to: \(url.lastPathComponent)")
    }
}
