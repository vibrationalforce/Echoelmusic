// ISFShaderParser.swift
// Echoelmusic - Interactive Shader Format (ISF) Parser & Metal Converter
//
// Parses ISF shader files (.fs/.isf) used by VDMX, MadMapper, and the visual
// arts community. Converts ISF GLSL to Metal Shading Language for GPU rendering.
// Supports 200+ open-source ISF shaders from the community library.
//
// ISF Specification: https://isf.video/spec/
//
// Created 2026-02-23
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

#if canImport(Metal)
import Metal
#endif

#if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)

// MARK: - ISF Input Types

/// Supported ISF input types for shader parameters
public enum ISFInputType: String, Codable, Sendable {
    case float = "float"
    case long = "long"
    case bool = "bool"
    case point2D = "point2D"
    case color = "color"
    case image = "image"
    case audio = "audio"
    case audioFFT = "audioFFT"
    case event = "event"

    /// Metal type string for uniform buffer declarations
    var metalType: String {
        switch self {
        case .float: return "float"
        case .long: return "int"
        case .bool: return "bool"
        case .point2D: return "float2"
        case .color: return "float4"
        case .image: return "texture2d<float>"
        case .audio: return "texture2d<float>"
        case .audioFFT: return "texture2d<float>"
        case .event: return "bool"
        }
    }

    /// Whether this input type requires a texture binding rather than a uniform value
    var isTexture: Bool {
        switch self {
        case .image, .audio, .audioFFT:
            return true
        default:
            return false
        }
    }
}

// MARK: - ISF Input

/// Describes a single ISF shader input parameter
public struct ISFInput: Codable, Sendable, Identifiable {
    public var id: String { name }

    /// Parameter name used in shader source
    public let name: String

    /// Data type of the input
    public let type: ISFInputType

    /// Default value (type varies by input type)
    public let defaultValue: ISFValue?

    /// Minimum value for numeric types
    public let minValue: ISFValue?

    /// Maximum value for numeric types
    public let maxValue: ISFValue?

    /// Human-readable label for UI
    public let label: String?

    /// Discrete value labels for long/enum types
    public let labels: [String]?

    /// Discrete values for long/enum types
    public let values: [Int]?

    /// Maximum buffer size for audio/audioFFT types
    public let maxBufferSize: Int?

    enum CodingKeys: String, CodingKey {
        case name = "NAME"
        case type = "TYPE"
        case defaultValue = "DEFAULT"
        case minValue = "MIN"
        case maxValue = "MAX"
        case label = "LABEL"
        case labels = "LABELS"
        case values = "VALUES"
        // maxBufferSize shares the "MAX" JSON key with maxValue;
        // decoded manually in init(from:) based on input type.
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ISFInputType.self, forKey: .type)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        labels = try container.decodeIfPresent([String].self, forKey: .labels)
        values = try container.decodeIfPresent([Int].self, forKey: .values)

        // Parse default/min/max based on type
        let rawType = try container.decode(String.self, forKey: .type)
        switch rawType {
        case "float":
            defaultValue = try container.decodeIfPresent(Double.self, forKey: .defaultValue).map { .float($0) }
            minValue = try container.decodeIfPresent(Double.self, forKey: .minValue).map { .float($0) }
            maxValue = try container.decodeIfPresent(Double.self, forKey: .maxValue).map { .float($0) }
            maxBufferSize = nil
        case "long":
            defaultValue = try container.decodeIfPresent(Int.self, forKey: .defaultValue).map { .long($0) }
            minValue = try container.decodeIfPresent(Int.self, forKey: .minValue).map { .long($0) }
            maxValue = try container.decodeIfPresent(Int.self, forKey: .maxValue).map { .long($0) }
            maxBufferSize = nil
        case "bool":
            defaultValue = try container.decodeIfPresent(Bool.self, forKey: .defaultValue).map { .bool($0) }
            minValue = nil
            maxValue = nil
            maxBufferSize = nil
        case "point2D":
            defaultValue = try container.decodeIfPresent([Double].self, forKey: .defaultValue).map { .point2D($0) }
            minValue = try container.decodeIfPresent([Double].self, forKey: .minValue).map { .point2D($0) }
            maxValue = try container.decodeIfPresent([Double].self, forKey: .maxValue).map { .point2D($0) }
            maxBufferSize = nil
        case "color":
            defaultValue = try container.decodeIfPresent([Double].self, forKey: .defaultValue).map { .color($0) }
            minValue = nil
            maxValue = nil
            maxBufferSize = nil
        case "audio", "audioFFT":
            defaultValue = nil
            minValue = nil
            // For audio types, "MAX" represents maximum buffer size
            maxBufferSize = try container.decodeIfPresent(Int.self, forKey: .maxValue)
            maxValue = nil
        default:
            defaultValue = nil
            minValue = nil
            maxValue = nil
            maxBufferSize = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(labels, forKey: .labels)
        try container.encodeIfPresent(values, forKey: .values)
    }

    /// Creates an ISFInput programmatically (not from JSON)
    public init(
        name: String,
        type: ISFInputType,
        defaultValue: ISFValue? = nil,
        minValue: ISFValue? = nil,
        maxValue: ISFValue? = nil,
        label: String? = nil,
        labels: [String]? = nil,
        values: [Int]? = nil,
        maxBufferSize: Int? = nil
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.label = label
        self.labels = labels
        self.values = values
        self.maxBufferSize = maxBufferSize
    }
}

// MARK: - ISF Value

/// Type-safe value container for ISF parameters
public enum ISFValue: Sendable {
    case float(Double)
    case long(Int)
    case bool(Bool)
    case point2D([Double])
    case color([Double])

    /// Convert to a float for uniform buffer packing
    public var asFloat: Float {
        switch self {
        case .float(let v): return Float(v)
        case .long(let v): return Float(v)
        case .bool(let v): return v ? 1.0 : 0.0
        case .point2D(let v): return Float(v.first ?? 0.0)
        case .color(let v): return Float(v.first ?? 0.0)
        }
    }
}

extension ISFValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .long(v)
        } else if let v = try? container.decode(Double.self) {
            self = .float(v)
        } else if let v = try? container.decode([Double].self) {
            self = v.count <= 2 ? .point2D(v) : .color(v)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported ISF value type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .float(let v): try container.encode(v)
        case .long(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .point2D(let v): try container.encode(v)
        case .color(let v): try container.encode(v)
        }
    }
}

// MARK: - ISF Pass

/// Describes a render pass in a multi-pass ISF shader
public struct ISFPass: Sendable {
    /// Target texture name (for multi-pass feedback)
    public let target: String?

    /// Whether the target texture persists between frames (feedback buffer)
    public let persistent: Bool

    /// Width expression (e.g., "$WIDTH/2", "640")
    public let widthExpression: String?

    /// Height expression (e.g., "$HEIGHT/2", "480")
    public let heightExpression: String?

    /// Whether this pass uses a float texture format
    public let isFloatTarget: Bool

    public init(
        target: String? = nil,
        persistent: Bool = false,
        widthExpression: String? = nil,
        heightExpression: String? = nil,
        isFloatTarget: Bool = false
    ) {
        self.target = target
        self.persistent = persistent
        self.widthExpression = widthExpression
        self.heightExpression = heightExpression
        self.isFloatTarget = isFloatTarget
    }
}

// MARK: - ISF Shader Descriptor

/// Complete parsed metadata from an ISF shader file
public struct ISFShaderDescriptor: Sendable {
    /// Human-readable description of the shader effect
    public let description: String

    /// Author credit
    public let credit: String

    /// ISF specification version ("2" is current)
    public let version: String

    /// Category tags for organizing shaders (e.g., "Generator", "Filter", "Transition")
    public let categories: [String]

    /// Input parameters the shader accepts
    public let inputs: [ISFInput]

    /// Render passes for multi-pass effects
    public let passes: [ISFPass]

    /// Raw GLSL source code (after metadata block)
    public let glslSource: String

    /// Original full source including metadata
    public let rawSource: String

    /// Shader filename (without extension)
    public var name: String = ""

    /// Whether this shader has audio-reactive inputs
    public var isAudioReactive: Bool {
        inputs.contains { $0.type == .audio || $0.type == .audioFFT }
    }

    /// Whether this shader uses multi-pass rendering
    public var isMultiPass: Bool {
        passes.count > 1
    }

    /// Whether this shader uses persistent feedback buffers
    public var usesFeedback: Bool {
        passes.contains { $0.persistent }
    }

    /// Texture inputs (image, audio, audioFFT)
    public var textureInputs: [ISFInput] {
        inputs.filter { $0.type.isTexture }
    }

    /// Uniform (non-texture) inputs
    public var uniformInputs: [ISFInput] {
        inputs.filter { !$0.type.isTexture }
    }
}

// MARK: - ISF Parse Error

/// Errors that can occur during ISF shader parsing
public enum ISFParseError: Error, LocalizedError {
    case metadataBlockNotFound
    case invalidJSON(String)
    case missingRequiredField(String)
    case invalidInputType(String)
    case fileReadError(URL, Error)
    case emptySource
    case unsupportedVersion(String)

    public var errorDescription: String? {
        switch self {
        case .metadataBlockNotFound:
            return "ISF metadata block not found. Expected /*{ ... }*/ at start of file."
        case .invalidJSON(let detail):
            return "Invalid JSON in ISF metadata: \(detail)"
        case .missingRequiredField(let field):
            return "Required ISF field missing: \(field)"
        case .invalidInputType(let typeName):
            return "Unsupported ISF input type: \(typeName)"
        case .fileReadError(let url, let underlying):
            return "Failed to read ISF file at \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .emptySource:
            return "ISF shader source is empty"
        case .unsupportedVersion(let version):
            return "Unsupported ISF version: \(version). Only version 2 is supported."
        }
    }
}

// MARK: - ISF Shader Parser

/// Parses ISF (Interactive Shader Format) shaders and converts GLSL to Metal
///
/// ISF is the standard shader format used by VDMX, MadMapper, CoGe, and the
/// broader visual arts community. This parser extracts the JSON metadata block,
/// parses shader inputs/passes, and converts ISF GLSL to Metal Shading Language.
///
/// Usage:
/// ```swift
/// let descriptor = try ISFShaderParser.parse(source: isfSource)
/// let metalSource = ISFShaderParser.convertToMetal(
///     glslSource: descriptor.glslSource,
///     descriptor: descriptor
/// )
/// ```
public final class ISFShaderParser {

    // MARK: - Public API

    /// Parse ISF shader source string into a descriptor
    /// - Parameter source: Complete ISF shader source (metadata + GLSL)
    /// - Returns: Parsed shader descriptor with metadata and GLSL source
    /// - Throws: ISFParseError if the source cannot be parsed
    public static func parse(source: String) throws -> ISFShaderDescriptor {
        guard !source.isEmpty else {
            throw ISFParseError.emptySource
        }

        // Extract JSON metadata block between /*{ and }*/
        let (jsonString, glslSource) = try extractMetadataBlock(from: source)

        // Parse JSON metadata
        let metadata = try parseMetadata(json: jsonString)

        // Build descriptor
        var descriptor = ISFShaderDescriptor(
            description: metadata.description ?? "",
            credit: metadata.credit ?? "",
            version: metadata.version ?? "2",
            categories: metadata.categories ?? [],
            inputs: metadata.inputs ?? [],
            passes: parsePasses(metadata.passes),
            glslSource: glslSource,
            rawSource: source
        )

        // Validate version
        if let version = metadata.version, version != "2" && version != "2.0" {
            log.log(.warning, category: .video, "ISF version \(version) may not be fully supported")
        }

        return descriptor
    }

    /// Parse an ISF shader file at the given URL
    /// - Parameter url: File URL to a .fs or .isf shader file
    /// - Returns: Parsed shader descriptor
    /// - Throws: ISFParseError on file read or parse failure
    public static func parseFile(at url: URL) throws -> ISFShaderDescriptor {
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ISFParseError.fileReadError(url, error)
        }

        var descriptor = try parse(source: source)
        descriptor.name = url.deletingPathExtension().lastPathComponent
        return descriptor
    }

    /// Convert ISF GLSL source to Metal Shading Language
    /// - Parameters:
    ///   - glslSource: GLSL source code from ISF shader (after metadata block)
    ///   - descriptor: Parsed ISF descriptor for input/pass information
    /// - Returns: Metal Shading Language source string ready for compilation
    public static func convertToMetal(glslSource: String, descriptor: ISFShaderDescriptor) -> String {
        var metal = glslSource

        // --- Phase 1: Type replacements (GLSL -> Metal) ---

        // Vector types
        metal = metal.replacingOccurrences(of: "vec2", with: "float2")
        metal = metal.replacingOccurrences(of: "vec3", with: "float3")
        metal = metal.replacingOccurrences(of: "vec4", with: "float4")
        metal = metal.replacingOccurrences(of: "ivec2", with: "int2")
        metal = metal.replacingOccurrences(of: "ivec3", with: "int3")
        metal = metal.replacingOccurrences(of: "ivec4", with: "int4")
        metal = metal.replacingOccurrences(of: "bvec2", with: "bool2")
        metal = metal.replacingOccurrences(of: "bvec3", with: "bool3")
        metal = metal.replacingOccurrences(of: "bvec4", with: "bool4")

        // Matrix types
        metal = metal.replacingOccurrences(of: "mat2", with: "float2x2")
        metal = metal.replacingOccurrences(of: "mat3", with: "float3x3")
        metal = metal.replacingOccurrences(of: "mat4", with: "float4x4")

        // Sampler types
        metal = metal.replacingOccurrences(of: "sampler2D", with: "texture2d<float>")

        // --- Phase 2: Function replacements ---

        // mod(a, b) -> fmod(a, b)
        metal = replaceFunction(in: metal, name: "mod", with: "fmod")

        // texture2D(tex, coord) -> tex.sample(texSampler, coord)
        metal = replaceTexture2D(in: metal)

        // IMG_NORM_PIXEL(tex, coord) -> tex.sample(texSampler, coord)
        metal = replaceIMGNormPixel(in: metal)

        // IMG_PIXEL(tex, coord) -> tex.read(uint2(coord))
        metal = replaceIMGPixel(in: metal)

        // IMG_THIS_PIXEL(tex) -> tex.sample(texSampler, in.texCoord)
        metal = replaceIMGThisPixel(in: metal)

        // IMG_THIS_NORM_PIXEL(tex) -> tex.sample(texSampler, in.texCoord)
        metal = replaceIMGThisNormPixel(in: metal)

        // IMG_SIZE(tex) -> float2(tex.get_width(), tex.get_height())
        metal = replaceIMGSize(in: metal)

        // --- Phase 3: Built-in variable replacements ---

        // ISF built-in uniforms
        metal = metal.replacingOccurrences(of: "RENDERSIZE", with: "uniforms.resolution")
        metal = metal.replacingOccurrences(of: "TIME", with: "uniforms.time")
        metal = metal.replacingOccurrences(of: "TIMEDELTA", with: "uniforms.timeDelta")
        metal = metal.replacingOccurrences(of: "FRAMEINDEX", with: "uniforms.frameIndex")
        metal = metal.replacingOccurrences(of: "DATE", with: "uniforms.date")

        // Fragment coordinate replacements
        metal = metal.replacingOccurrences(of: "gl_FragCoord", with: "in.position")
        metal = metal.replacingOccurrences(of: "isf_FragNormCoord", with: "in.texCoord")
        metal = metal.replacingOccurrences(of: "gl_FragColor", with: "outputColor")

        // PASSINDEX for multi-pass
        for (index, pass) in descriptor.passes.enumerated() {
            if let target = pass.target {
                metal = metal.replacingOccurrences(
                    of: "PASSINDEX == \(index)",
                    with: "true /* pass \(index): \(target) */"
                )
            }
        }
        metal = metal.replacingOccurrences(of: "PASSINDEX", with: "uniforms.passIndex")

        // --- Phase 4: Qualifier cleanup ---

        // Remove GLSL qualifiers that don't exist in Metal
        metal = metal.replacingOccurrences(of: "varying ", with: "")
        metal = metal.replacingOccurrences(of: "uniform ", with: "")
        metal = metal.replacingOccurrences(of: "highp ", with: "")
        metal = metal.replacingOccurrences(of: "mediump ", with: "")
        metal = metal.replacingOccurrences(of: "lowp ", with: "")
        metal = metal.replacingOccurrences(of: "precision highp float;", with: "")
        metal = metal.replacingOccurrences(of: "precision mediump float;", with: "")

        // --- Phase 5: Wrap in Metal function signature ---

        let header = buildMetalHeader(descriptor: descriptor)
        let functionSignature = buildMetalFunctionSignature(descriptor: descriptor)
        let footer = buildMetalFooter()

        // Replace void main() with Metal fragment function
        if let mainRange = metal.range(of: "void main()") ??
           metal.range(of: "void main ()") ??
           metal.range(of: "void\tmain()") {
            // Find the opening brace after main()
            let afterMain = metal[mainRange.upperBound...]
            if let braceRange = afterMain.range(of: "{") {
                let beforeMain = String(metal[metal.startIndex..<mainRange.lowerBound])
                let afterBrace = String(metal[braceRange.upperBound...])

                // Build final Metal source
                metal = header + "\n"
                    + beforeMain + "\n"
                    + functionSignature + " {\n"
                    + "    float4 outputColor = float4(0.0, 0.0, 0.0, 1.0);\n"
                    + afterBrace

                // Replace the final closing brace with return + close
                if let lastBrace = metal.range(of: "}", options: .backwards) {
                    metal = String(metal[metal.startIndex..<lastBrace.lowerBound])
                        + "    return outputColor;\n"
                        + "}\n"
                        + footer
                }
            }
        } else {
            // No void main() found -- wrap entire code as a function body
            metal = header + "\n"
                + functionSignature + " {\n"
                + "    float4 outputColor = float4(0.0, 0.0, 0.0, 1.0);\n"
                + metal + "\n"
                + "    return outputColor;\n"
                + "}\n"
                + footer
        }

        return metal
    }

    // MARK: - Metadata Extraction

    /// Extract the JSON metadata block and GLSL source from ISF source
    private static func extractMetadataBlock(from source: String) throws -> (json: String, glsl: String) {
        // ISF metadata is enclosed in /*{ ... }*/
        guard let startRange = source.range(of: "/*{") ?? source.range(of: "/* {") else {
            throw ISFParseError.metadataBlockNotFound
        }

        // Find the matching }*/ closing delimiter
        guard let endRange = source.range(of: "}*/", range: startRange.upperBound..<source.endIndex) else {
            throw ISFParseError.metadataBlockNotFound
        }

        // Extract JSON (include the braces but not the comment delimiters)
        let jsonStart = source.index(startRange.lowerBound, offsetBy: 2) // skip /*
        let jsonEnd = source.index(endRange.upperBound, offsetBy: -2) // skip */
        let jsonString = String(source[jsonStart...jsonEnd])

        // GLSL source is everything after the metadata block
        let glslSource = String(source[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return (jsonString, glslSource)
    }

    // MARK: - JSON Metadata Parsing

    /// Internal raw metadata structure for JSON decoding
    private struct RawISFMetadata: Codable {
        let description: String?
        let credit: String?
        let version: String?
        let categories: [String]?
        let inputs: [ISFInput]?
        let passes: [[String: ISFPassValue]]?

        enum CodingKeys: String, CodingKey {
            case description = "DESCRIPTION"
            case credit = "CREDIT"
            case version = "ISFVSN"
            case categories = "CATEGORIES"
            case inputs = "INPUTS"
            case passes = "PASSES"
        }
    }

    /// Flexible pass value type for JSON parsing
    private enum ISFPassValue: Codable {
        case string(String)
        case bool(Bool)
        case int(Int)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let v = try? container.decode(Bool.self) {
                self = .bool(v)
            } else if let v = try? container.decode(Int.self) {
                self = .int(v)
            } else if let v = try? container.decode(String.self) {
                self = .string(v)
            } else {
                self = .string("")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let v): try container.encode(v)
            case .bool(let v): try container.encode(v)
            case .int(let v): try container.encode(v)
            }
        }

        var stringValue: String? {
            if case .string(let v) = self { return v }
            return nil
        }

        var boolValue: Bool {
            if case .bool(let v) = self { return v }
            return false
        }
    }

    /// Parse the JSON metadata string into structured data
    private static func parseMetadata(json: String) throws -> RawISFMetadata {
        guard let data = json.data(using: .utf8) else {
            throw ISFParseError.invalidJSON("Could not encode JSON as UTF-8")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(RawISFMetadata.self, from: data)
        } catch {
            throw ISFParseError.invalidJSON(error.localizedDescription)
        }
    }

    /// Convert raw pass dictionaries to ISFPass structures
    private static func parsePasses(_ rawPasses: [[String: ISFPassValue]]?) -> [ISFPass] {
        guard let rawPasses = rawPasses else {
            // Default: single pass with no target
            return [ISFPass()]
        }

        return rawPasses.map { dict in
            ISFPass(
                target: dict["TARGET"]?.stringValue,
                persistent: dict["PERSISTENT"]?.boolValue ?? false,
                widthExpression: dict["WIDTH"]?.stringValue,
                heightExpression: dict["HEIGHT"]?.stringValue,
                isFloatTarget: dict["FLOAT"]?.boolValue ?? false
            )
        }
    }

    // MARK: - GLSL to Metal Conversion Helpers

    /// Replace a GLSL function call pattern: funcName(args) -> replacement(args)
    private static func replaceFunction(in source: String, name: String, with replacement: String) -> String {
        // Simple word-boundary aware replacement
        var result = source
        let pattern = "\\b\(name)\\s*\\("
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        // Replace in reverse order to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let matched = String(result[range])
            let replaced = matched.replacingOccurrences(of: name, with: replacement)
            result.replaceSubrange(range, with: replaced)
        }

        return result
    }

    /// Replace texture2D(tex, coord) with tex.sample(texSampler, coord)
    private static func replaceTexture2D(in source: String) -> String {
        var result = source
        let pattern = "texture2D\\s*\\(\\s*(\\w+)\\s*,\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "\(texName).sample(texSampler, ")
        }

        return result
    }

    /// Replace IMG_NORM_PIXEL(tex, coord) with tex.sample(texSampler, coord)
    private static func replaceIMGNormPixel(in source: String) -> String {
        var result = source
        let pattern = "IMG_NORM_PIXEL\\s*\\(\\s*(\\w+)\\s*,\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "\(texName).sample(texSampler, ")
        }

        return result
    }

    /// Replace IMG_PIXEL(tex, coord) with tex.read(uint2(coord))
    private static func replaceIMGPixel(in source: String) -> String {
        var result = source
        let pattern = "IMG_PIXEL\\s*\\(\\s*(\\w+)\\s*,\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "\(texName).read(uint2(")
        }

        return result
    }

    /// Replace IMG_THIS_PIXEL(tex) with tex.sample(texSampler, in.texCoord)
    private static func replaceIMGThisPixel(in source: String) -> String {
        var result = source
        let pattern = "IMG_THIS_PIXEL\\s*\\(\\s*(\\w+)\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "\(texName).sample(texSampler, in.texCoord)")
        }

        return result
    }

    /// Replace IMG_THIS_NORM_PIXEL(tex) with tex.sample(texSampler, in.texCoord)
    private static func replaceIMGThisNormPixel(in source: String) -> String {
        var result = source
        let pattern = "IMG_THIS_NORM_PIXEL\\s*\\(\\s*(\\w+)\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "\(texName).sample(texSampler, in.texCoord)")
        }

        return result
    }

    /// Replace IMG_SIZE(tex) with float2(tex.get_width(), tex.get_height())
    private static func replaceIMGSize(in source: String) -> String {
        var result = source
        let pattern = "IMG_SIZE\\s*\\(\\s*(\\w+)\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let texNameRange = Range(match.range(at: 1), in: result) else { continue }
            let texName = String(result[texNameRange])
            result.replaceSubrange(range, with: "float2(\(texName).get_width(), \(texName).get_height())")
        }

        return result
    }

    // MARK: - Metal Source Generation

    /// Build the Metal header with includes, structs, and sampler
    private static func buildMetalHeader(descriptor: ISFShaderDescriptor) -> String {
        var header = """
        // Auto-generated Metal shader from ISF source
        // Original: \(descriptor.name.isEmpty ? "Unknown" : descriptor.name)
        // \(descriptor.description)
        // Credit: \(descriptor.credit)
        //
        // Generated by Echoelmusic ISFShaderParser

        #include <metal_stdlib>
        using namespace metal;

        // ISF Uniform buffer matching Echoelmusic bio-reactive pipeline
        struct ISFUniforms {
            float time;
            float timeDelta;
            int frameIndex;
            int passIndex;
            float2 resolution;
            float4 date; // (year, month, day, secondsSinceMidnight)

        """

        // Add user-defined uniform inputs
        for input in descriptor.uniformInputs {
            let metalType: String
            switch input.type {
            case .float: metalType = "float"
            case .long: metalType = "int"
            case .bool: metalType = "int" // Metal doesn't have bool in buffers
            case .point2D: metalType = "float2"
            case .color: metalType = "float4"
            default: continue
            }
            header += "    \(metalType) \(input.name);\n"
        }

        header += """
        };

        // Fragment input from vertex shader
        struct ISFVertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        // Texture sampler for ISF image inputs
        constexpr sampler texSampler(
            mag_filter::linear,
            min_filter::linear,
            s_address::clamp_to_edge,
            t_address::clamp_to_edge
        );

        """

        return header
    }

    /// Build the Metal fragment function signature with texture bindings
    private static func buildMetalFunctionSignature(descriptor: ISFShaderDescriptor) -> String {
        var sig = "fragment float4 isfShader(\n"
        sig += "    ISFVertexOut in [[stage_in]],\n"
        sig += "    constant ISFUniforms &uniforms [[buffer(0)]]"

        // Add texture parameters for image/audio/audioFFT inputs
        var textureIndex = 0
        for input in descriptor.textureInputs {
            sig += ",\n    texture2d<float> \(input.name) [[texture(\(textureIndex))]]"
            textureIndex += 1
        }

        // Add persistent pass textures
        for pass in descriptor.passes where pass.target != nil {
            sig += ",\n    texture2d<float> \(pass.target!) [[texture(\(textureIndex))]]"
            textureIndex += 1
        }

        sig += "\n)"
        return sig
    }

    /// Build the Metal footer (vertex shader for fullscreen quad)
    private static func buildMetalFooter() -> String {
        return """

        // Fullscreen quad vertex shader for ISF rendering
        vertex ISFVertexOut isfVertexShader(uint vertexID [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };

            ISFVertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.texCoord = positions[vertexID] * 0.5 + 0.5;
            out.texCoord.y = 1.0 - out.texCoord.y; // Flip Y for Metal
            return out;
        }
        """
    }
}

// MARK: - ISF Shader Library

/// Manages a collection of loaded ISF shaders with caching and Metal conversion
///
/// Provides a centralized registry for ISF shaders, including built-in shaders
/// and user-loaded shaders. Caches both parsed descriptors and converted Metal source.
@MainActor
public class ISFShaderLibrary: ObservableObject {

    // MARK: - Published State

    /// All loaded shader descriptors
    @Published public private(set) var shaders: [ISFShaderDescriptor] = []

    /// Names of all loaded shaders for quick lookup
    @Published public private(set) var shaderNames: [String] = []

    /// Whether the library is currently loading shaders
    @Published public private(set) var isLoading: Bool = false

    /// Last error encountered during loading
    @Published public private(set) var lastError: String?

    // MARK: - Caches

    /// Cache of parsed descriptors keyed by shader name
    private var descriptorCache: [String: ISFShaderDescriptor] = [:]

    /// Cache of converted Metal source keyed by shader name
    private var metalSourceCache: [String: String] = [:]

    #if canImport(Metal)
    /// Cache of compiled Metal libraries keyed by shader name
    private var metalLibraryCache: [String: MTLLibrary] = [:]

    /// Metal device for shader compilation
    private var device: MTLDevice?
    #endif

    // MARK: - Initialization

    public init() {
        #if canImport(Metal)
        device = MTLCreateSystemDefaultDevice()
        #endif
    }

    // MARK: - Loading

    /// Load a single ISF shader from a URL
    /// - Parameter url: File URL to the .fs or .isf shader
    /// - Returns: The parsed descriptor, or nil if loading failed
    @discardableResult
    public func loadShader(from url: URL) -> ISFShaderDescriptor? {
        do {
            var descriptor = try ISFShaderParser.parseFile(at: url)
            if descriptor.name.isEmpty {
                descriptor.name = url.deletingPathExtension().lastPathComponent
            }

            // Cache descriptor
            descriptorCache[descriptor.name] = descriptor

            // Convert and cache Metal source
            let metalSource = ISFShaderParser.convertToMetal(
                glslSource: descriptor.glslSource,
                descriptor: descriptor
            )
            metalSourceCache[descriptor.name] = metalSource

            // Compile Metal library
            #if canImport(Metal)
            compileMetalLibrary(name: descriptor.name, source: metalSource)
            #endif

            // Add to published array if not already present
            if !shaders.contains(where: { $0.name == descriptor.name }) {
                shaders.append(descriptor)
                shaderNames.append(descriptor.name)
            }

            lastError = nil
            log.log(.info, category: .video, "Loaded ISF shader: \(descriptor.name)")
            return descriptor
        } catch {
            lastError = error.localizedDescription
            log.log(.error, category: .video, "Failed to load ISF shader at \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    /// Load all ISF shaders from a directory
    /// - Parameter directoryURL: Directory containing .fs and .isf files
    public func loadShaders(from directoryURL: URL) {
        isLoading = true
        defer { isLoading = false }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            lastError = "Cannot enumerate directory: \(directoryURL.path)"
            return
        }

        var loadedCount = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "fs" || ext == "isf" else { continue }

            if loadShader(from: fileURL) != nil {
                loadedCount += 1
            }
        }

        log.log(.info, category: .video, "Loaded \(loadedCount) ISF shaders from \(directoryURL.lastPathComponent)")
    }

    /// Load built-in ISF shaders bundled with the app
    public func loadBuiltInShaders() {
        isLoading = true
        defer { isLoading = false }

        // Look for ISF shaders in the main bundle
        guard let bundleURL = Bundle.main.resourceURL else {
            log.log(.warning, category: .video, "No bundle resource URL for built-in ISF shaders")
            return
        }

        // Check standard locations for ISF shaders
        let searchPaths = [
            bundleURL.appendingPathComponent("ISF"),
            bundleURL.appendingPathComponent("Shaders/ISF"),
            bundleURL.appendingPathComponent("Resources/ISF")
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                loadShaders(from: path)
            }
        }

        log.log(.info, category: .video, "Built-in ISF shader loading complete. Total: \(shaders.count)")
    }

    // MARK: - Lookup

    /// Get a shader descriptor by name
    /// - Parameter name: Shader name (filename without extension)
    /// - Returns: The cached descriptor, or nil if not loaded
    public func getShaderDescriptor(name: String) -> ISFShaderDescriptor? {
        return descriptorCache[name]
    }

    /// Get the converted Metal source for a shader
    /// - Parameter name: Shader name
    /// - Returns: Metal Shading Language source string, or nil if not converted
    public func getMetalSource(name: String) -> String? {
        return metalSourceCache[name]
    }

    #if canImport(Metal)
    /// Get a compiled Metal library for a shader
    /// - Parameter name: Shader name
    /// - Returns: Compiled MTLLibrary, or nil if not compiled
    public func getMetalLibrary(name: String) -> MTLLibrary? {
        return metalLibraryCache[name]
    }
    #endif

    /// Get all shaders in a specific category
    /// - Parameter category: ISF category (e.g., "Generator", "Filter", "Transition")
    /// - Returns: Array of matching shader descriptors
    public func shaders(inCategory category: String) -> [ISFShaderDescriptor] {
        return shaders.filter { $0.categories.contains(category) }
    }

    /// Get all audio-reactive shaders
    public var audioReactiveShaders: [ISFShaderDescriptor] {
        return shaders.filter { $0.isAudioReactive }
    }

    /// Get all unique categories across loaded shaders
    public var allCategories: [String] {
        let categories = Set(shaders.flatMap { $0.categories })
        return Array(categories).sorted()
    }

    // MARK: - Cache Management

    /// Remove a shader from the library and caches
    /// - Parameter name: Shader name to remove
    public func removeShader(name: String) {
        shaders.removeAll { $0.name == name }
        shaderNames.removeAll { $0 == name }
        descriptorCache.removeValue(forKey: name)
        metalSourceCache.removeValue(forKey: name)
        #if canImport(Metal)
        metalLibraryCache.removeValue(forKey: name)
        #endif
    }

    /// Clear all caches and loaded shaders
    public func clearAll() {
        shaders.removeAll()
        shaderNames.removeAll()
        descriptorCache.removeAll()
        metalSourceCache.removeAll()
        #if canImport(Metal)
        metalLibraryCache.removeAll()
        #endif
    }

    // MARK: - Metal Compilation

    #if canImport(Metal)
    /// Compile Metal source into a library for GPU execution
    private func compileMetalLibrary(name: String, source: String) {
        guard let device = device else { return }

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            metalLibraryCache[name] = library
            log.log(.info, category: .video, "Compiled Metal library for ISF shader: \(name)")
        } catch {
            // Metal compilation failures are common for complex ISF shaders;
            // the converted source may need manual adjustments for edge cases
            log.log(.warning, category: .video, "Metal compilation failed for ISF shader '\(name)': \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - ISF Shader Runtime Values

/// Holds runtime values for ISF shader uniforms, used when dispatching shaders
public struct ISFShaderValues: Sendable {
    /// Current animation time in seconds
    public var time: Float = 0

    /// Time since last frame in seconds
    public var timeDelta: Float = 0

    /// Current frame number
    public var frameIndex: Int = 0

    /// Current render pass index
    public var passIndex: Int = 0

    /// Output resolution in pixels
    public var resolution: SIMD2<Float> = .zero

    /// Date components (year, month, day, secondsSinceMidnight)
    public var date: SIMD4<Float> = .zero

    /// User-defined input values keyed by input name
    public var inputValues: [String: ISFValue] = [:]

    public init() {}

    /// Set a float input value
    public mutating func setFloat(_ name: String, value: Float) {
        inputValues[name] = .float(Double(value))
    }

    /// Set a boolean input value
    public mutating func setBool(_ name: String, value: Bool) {
        inputValues[name] = .bool(value)
    }

    /// Set a point2D input value
    public mutating func setPoint2D(_ name: String, x: Float, y: Float) {
        inputValues[name] = .point2D([Double(x), Double(y)])
    }

    /// Set a color input value
    public mutating func setColor(_ name: String, r: Float, g: Float, b: Float, a: Float = 1.0) {
        inputValues[name] = .color([Double(r), Double(g), Double(b), Double(a)])
    }

    /// Get the value for an input, falling back to the descriptor's default
    public func getValue(for input: ISFInput) -> ISFValue? {
        return inputValues[input.name] ?? input.defaultValue
    }
}

#endif // os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
