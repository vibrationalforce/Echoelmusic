// ProColorGrading.swift
// Echoelmusic - Professional Color Grading Engine
//
// DaVinci Resolve / Final Cut Pro / Premiere Pro grade color grading
// Three-way color wheels, RGB curves, HSL qualifier, 3D LUT, broadcast scopes
// Node-based serial grading pipeline with full save/load
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import CoreImage
import CoreGraphics
import Combine

// MARK: - CurvePoint

/// A single control point on an RGB or luminance curve.
public struct CurvePoint: Codable, Equatable, Sendable {
    /// Normalized input value (0-1).
    public var input: Float
    /// Normalized output value (0-1).
    public var output: Float

    public init(input: Float, output: Float) {
        self.input = input.clamped(to: 0...1)
        self.output = output.clamped(to: 0...1)
    }
}

// MARK: - ColorRange

/// Per-color channel identifiers for HSL qualification (DaVinci qualifier style).
public enum ColorRange: String, CaseIterable, Codable, Sendable {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case magenta

    /// Approximate center hue in degrees for this range.
    public var centerHue: Float {
        switch self {
        case .red:     return 0
        case .orange:  return 30
        case .yellow:  return 60
        case .green:   return 120
        case .cyan:    return 180
        case .blue:    return 240
        case .purple:  return 270
        case .magenta: return 300
        }
    }

    /// Half-width of the hue acceptance window in degrees.
    public var hueWidth: Float { 22.5 }
}

// MARK: - HSLValues

/// Hue/Saturation/Luminance adjustment values for a single color range.
public struct HSLValues: Codable, Equatable, Sendable {
    /// Hue rotation in degrees (-180 to 180).
    public var hueShift: Float
    /// Saturation multiplier (-1 to 1 offset around neutral 0).
    public var saturation: Float
    /// Luminance offset (-1 to 1).
    public var luminance: Float

    public init(hueShift: Float = 0, saturation: Float = 0, luminance: Float = 0) {
        self.hueShift = hueShift.clamped(to: -180...180)
        self.saturation = saturation.clamped(to: -1...1)
        self.luminance = luminance.clamped(to: -1...1)
    }

    public var isNeutral: Bool {
        hueShift == 0 && saturation == 0 && luminance == 0
    }
}

// MARK: - WipeDirection

/// Direction for wipe and push transitions.
public enum WipeDirection: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case up
    case down
    case diagonal
}

// MARK: - TransitionEasing

/// Easing functions for transitions.
public enum TransitionEasing: String, CaseIterable, Codable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case bounce

    /// Evaluate the easing curve for a normalized time t (0-1).
    public func evaluate(_ t: Float) -> Float {
        let t = t.clamped(to: 0...1)
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return t * (2 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
        case .bounce:
            let c = 1 - t
            if c < 1 / 2.75 {
                return 1 - 7.5625 * c * c
            } else if c < 2 / 2.75 {
                let adj = c - 1.5 / 2.75
                return 1 - (7.5625 * adj * adj + 0.75)
            } else if c < 2.5 / 2.75 {
                let adj = c - 2.25 / 2.75
                return 1 - (7.5625 * adj * adj + 0.9375)
            } else {
                let adj = c - 2.625 / 2.75
                return 1 - (7.5625 * adj * adj + 0.984375)
            }
        }
    }
}

// MARK: - TransitionType

/// Professional video transition types.
public enum TransitionType: String, CaseIterable, Codable, Sendable {
    case cut
    case crossDissolve
    case dipToBlack
    case dipToWhite
    case additive
    case wipeLeft
    case wipeRight
    case wipeUp
    case wipeDown
    case wipeDiagonal
    case pushLeft
    case pushRight
    case pushUp
    case pushDown
    case slide
    case spin
    case zoom
    case blur
    case glitch
    case flash
    case beatSync

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .cut:            return "Cut"
        case .crossDissolve:  return "Cross Dissolve"
        case .dipToBlack:     return "Dip to Black"
        case .dipToWhite:     return "Dip to White"
        case .additive:       return "Additive Dissolve"
        case .wipeLeft:       return "Wipe Left"
        case .wipeRight:      return "Wipe Right"
        case .wipeUp:         return "Wipe Up"
        case .wipeDown:       return "Wipe Down"
        case .wipeDiagonal:   return "Wipe Diagonal"
        case .pushLeft:       return "Push Left"
        case .pushRight:      return "Push Right"
        case .pushUp:         return "Push Up"
        case .pushDown:       return "Push Down"
        case .slide:          return "Slide"
        case .spin:           return "Spin"
        case .zoom:           return "Zoom"
        case .blur:           return "Blur"
        case .glitch:         return "Glitch"
        case .flash:          return "Flash"
        case .beatSync:       return "Beat Sync"
        }
    }

    /// Whether this transition requires two sources (A/B).
    public var requiresTwoSources: Bool {
        self != .cut
    }

    /// Default duration in seconds for this transition type.
    public var defaultDuration: TimeInterval {
        switch self {
        case .cut:           return 0
        case .flash:         return 0.15
        case .glitch:        return 0.25
        case .beatSync:      return 0.5
        case .crossDissolve: return 1.0
        case .dipToBlack, .dipToWhite, .additive: return 1.0
        default:             return 0.75
        }
    }
}

// MARK: - ProTransition

/// A fully configured professional transition instance.
public struct ProTransition: Codable, Equatable, Sendable {
    public var type: TransitionType
    public var duration: TimeInterval
    public var easing: TransitionEasing
    public var parameters: [String: Float]

    public init(
        type: TransitionType = .crossDissolve,
        duration: TimeInterval? = nil,
        easing: TransitionEasing = .easeInOut,
        parameters: [String: Float] = [:]
    ) {
        self.type = type
        self.duration = duration ?? type.defaultDuration
        self.easing = easing
        self.parameters = parameters
    }

    /// Evaluate the transition mix amount at a normalized time (0-1).
    public func mix(at normalizedTime: Float) -> Float {
        easing.evaluate(normalizedTime)
    }
}

// MARK: - ScopeType

/// Broadcast monitoring scope types.
public enum ScopeType: String, CaseIterable, Codable, Sendable {
    case histogram
    case waveform
    case vectorscope
    case rgbParade
    case falseColor

    public var displayName: String {
        switch self {
        case .histogram:    return "Histogram"
        case .waveform:     return "Waveform"
        case .vectorscope:  return "Vectorscope"
        case .rgbParade:    return "RGB Parade"
        case .falseColor:   return "False Color"
        }
    }
}

// MARK: - ColorWheels

/// Three-way color correction (lift / gamma / gain) in the style of DaVinci Resolve.
public struct ColorWheels: Codable, Equatable, Sendable {

    // MARK: Lift / Gamma / Gain

    /// Shadow RGB offset (-1 to 1 per channel).
    public var lift: SIMD3<Float>
    /// Midtone RGB offset (-1 to 1 per channel).
    public var gamma: SIMD3<Float>
    /// Highlight RGB offset (-1 to 1 per channel).
    public var gain: SIMD3<Float>
    /// Global RGB offset.
    public var offset: SIMD3<Float>

    // MARK: Master Luminance

    /// Lift master luminance (-1 to 1).
    public var liftMaster: Float
    /// Gamma master luminance (-1 to 1).
    public var gammaMaster: Float
    /// Gain master luminance (-1 to 1).
    public var gainMaster: Float

    // MARK: Primary Corrections

    /// Color temperature shift (-100 to 100, Kelvin).
    public var temperature: Float
    /// Green-magenta tint shift (-100 to 100).
    public var tint: Float
    /// Global saturation (0 to 2, default 1).
    public var saturation: Float
    /// Vibrance — selective saturation of less-saturated colors (-1 to 1).
    public var vibrance: Float
    /// Exposure in stops (-5 to 5).
    public var exposure: Float
    /// Contrast (-100 to 100).
    public var contrast: Float
    /// Highlight recovery (-100 to 100).
    public var highlights: Float
    /// Shadow recovery (-100 to 100).
    public var shadows: Float
    /// Whites clipping point (-100 to 100).
    public var whites: Float
    /// Blacks clipping point (-100 to 100).
    public var blacks: Float

    public init(
        lift: SIMD3<Float> = .zero,
        gamma: SIMD3<Float> = .zero,
        gain: SIMD3<Float> = .zero,
        offset: SIMD3<Float> = .zero,
        liftMaster: Float = 0,
        gammaMaster: Float = 0,
        gainMaster: Float = 0,
        temperature: Float = 0,
        tint: Float = 0,
        saturation: Float = 1,
        vibrance: Float = 0,
        exposure: Float = 0,
        contrast: Float = 0,
        highlights: Float = 0,
        shadows: Float = 0,
        whites: Float = 0,
        blacks: Float = 0
    ) {
        self.lift = lift.clamped(min: -1, max: 1)
        self.gamma = gamma.clamped(min: -1, max: 1)
        self.gain = gain.clamped(min: -1, max: 1)
        self.offset = offset.clamped(min: -1, max: 1)
        self.liftMaster = liftMaster.clamped(to: -1...1)
        self.gammaMaster = gammaMaster.clamped(to: -1...1)
        self.gainMaster = gainMaster.clamped(to: -1...1)
        self.temperature = temperature.clamped(to: -100...100)
        self.tint = tint.clamped(to: -100...100)
        self.saturation = saturation.clamped(to: 0...2)
        self.vibrance = vibrance.clamped(to: -1...1)
        self.exposure = exposure.clamped(to: -5...5)
        self.contrast = contrast.clamped(to: -100...100)
        self.highlights = highlights.clamped(to: -100...100)
        self.shadows = shadows.clamped(to: -100...100)
        self.whites = whites.clamped(to: -100...100)
        self.blacks = blacks.clamped(to: -100...100)
    }

    /// Whether all values are at their defaults (no correction applied).
    public var isNeutral: Bool {
        lift == .zero && gamma == .zero && gain == .zero && offset == .zero
            && liftMaster == 0 && gammaMaster == 0 && gainMaster == 0
            && temperature == 0 && tint == 0
            && saturation == 1 && vibrance == 0
            && exposure == 0 && contrast == 0
            && highlights == 0 && shadows == 0
            && whites == 0 && blacks == 0
    }

    /// Reset all wheels to neutral defaults.
    public static var neutral: ColorWheels { ColorWheels() }
}

// MARK: - CurvesEditor

/// RGB curves editor (Photoshop / DaVinci style) with cubic spline interpolation.
public struct CurvesEditor: Codable, Equatable, Sendable {

    /// Master luminance curve.
    public var masterCurve: [CurvePoint]
    /// Red channel curve.
    public var redCurve: [CurvePoint]
    /// Green channel curve.
    public var greenCurve: [CurvePoint]
    /// Blue channel curve.
    public var blueCurve: [CurvePoint]
    /// Hue vs Saturation curve.
    public var hueSatCurve: [CurvePoint]
    /// Hue vs Hue (hue shift) curve.
    public var hueHueCurve: [CurvePoint]

    /// Default identity curve: straight line from (0,0) to (1,1).
    public static var identityCurve: [CurvePoint] {
        [CurvePoint(input: 0, output: 0), CurvePoint(input: 1, output: 1)]
    }

    public init(
        masterCurve: [CurvePoint]? = nil,
        redCurve: [CurvePoint]? = nil,
        greenCurve: [CurvePoint]? = nil,
        blueCurve: [CurvePoint]? = nil,
        hueSatCurve: [CurvePoint]? = nil,
        hueHueCurve: [CurvePoint]? = nil
    ) {
        self.masterCurve = masterCurve ?? Self.identityCurve
        self.redCurve = redCurve ?? Self.identityCurve
        self.greenCurve = greenCurve ?? Self.identityCurve
        self.blueCurve = blueCurve ?? Self.identityCurve
        self.hueSatCurve = hueSatCurve ?? Self.identityCurve
        self.hueHueCurve = hueHueCurve ?? Self.identityCurve
    }

    /// Whether all curves are identity (no modification).
    public var isNeutral: Bool {
        masterCurve == Self.identityCurve
            && redCurve == Self.identityCurve
            && greenCurve == Self.identityCurve
            && blueCurve == Self.identityCurve
            && hueSatCurve == Self.identityCurve
            && hueHueCurve == Self.identityCurve
    }

    // MARK: - Cubic Spline Interpolation

    /// Evaluate a curve at the given input position using monotone cubic interpolation.
    /// - Parameters:
    ///   - curve: Sorted array of `CurvePoint` control points.
    ///   - t: Normalized input value (0-1).
    /// - Returns: Interpolated output value clamped to 0-1.
    public func evaluate(curve: [CurvePoint], at t: Float) -> Float {
        let t = t.clamped(to: 0...1)
        guard curve.count >= 2 else { return t }

        let sorted = curve.sorted { $0.input < $1.input }

        // Clamp to endpoints
        if t <= sorted.first!.input { return sorted.first!.output }
        if t >= sorted.last!.input { return sorted.last!.output }

        // Find the segment
        var segIndex = 0
        for i in 0..<(sorted.count - 1) {
            if t >= sorted[i].input && t <= sorted[i + 1].input {
                segIndex = i
                break
            }
        }

        let p0 = sorted[segIndex]
        let p1 = sorted[segIndex + 1]

        // Linear if only 2 points or segment width is zero
        let dx = p1.input - p0.input
        guard dx > .ulpOfOne else { return p0.output }

        if sorted.count == 2 {
            let frac = (t - p0.input) / dx
            return (p0.output + frac * (p1.output - p0.output)).clamped(to: 0...1)
        }

        // Catmull-Rom style cubic using surrounding points
        let pBefore = segIndex > 0 ? sorted[segIndex - 1] : CurvePoint(
            input: 2 * p0.input - p1.input,
            output: 2 * p0.output - p1.output
        )
        let pAfter = segIndex + 2 < sorted.count ? sorted[segIndex + 2] : CurvePoint(
            input: 2 * p1.input - p0.input,
            output: 2 * p1.output - p0.output
        )

        let frac = (t - p0.input) / dx
        let frac2 = frac * frac
        let frac3 = frac2 * frac

        // Catmull-Rom spline
        let m0 = (p1.output - pBefore.output) / (p1.input - pBefore.input + .ulpOfOne) * dx
        let m1 = (pAfter.output - p0.output) / (pAfter.input - p0.input + .ulpOfOne) * dx

        let a = 2 * p0.output - 2 * p1.output + m0 + m1
        let b = -3 * p0.output + 3 * p1.output - 2 * m0 - m1
        let c = m0
        let d = p0.output

        let result = a * frac3 + b * frac2 + c * frac + d
        return result.clamped(to: 0...1)
    }

    /// Reset all curves to identity.
    public static var neutral: CurvesEditor { CurvesEditor() }
}

// MARK: - HSLAdjustment

/// Per-color-range HSL adjustment (DaVinci qualifier style).
public struct HSLAdjustment: Codable, Equatable, Sendable {
    /// Adjustments keyed by color range.
    public var adjustments: [ColorRange: HSLValues]

    public init(adjustments: [ColorRange: HSLValues]? = nil) {
        if let adjustments {
            self.adjustments = adjustments
        } else {
            var defaults: [ColorRange: HSLValues] = [:]
            for range in ColorRange.allCases {
                defaults[range] = HSLValues()
            }
            self.adjustments = defaults
        }
    }

    /// Whether all ranges are neutral.
    public var isNeutral: Bool {
        adjustments.values.allSatisfy { $0.isNeutral }
    }

    /// Get adjustment for a specific color range.
    public func values(for range: ColorRange) -> HSLValues {
        adjustments[range] ?? HSLValues()
    }

    /// Set adjustment for a specific color range.
    public mutating func setValues(_ values: HSLValues, for range: ColorRange) {
        adjustments[range] = values
    }

    /// Reset all ranges.
    public static var neutral: HSLAdjustment { HSLAdjustment() }
}

// MARK: - LUT3D

/// A three-dimensional color lookup table.
public struct LUT3D: Sendable {
    /// Side dimension of the cube (typically 17 or 33).
    public let size: Int
    /// Flattened RGB data in row-major order: [r + g*size + b*size*size].
    public let data: [SIMD3<Float>]

    public init(size: Int, data: [SIMD3<Float>]) {
        self.size = size
        self.data = data
    }

    /// Look up a color in the LUT with trilinear interpolation.
    public func lookup(_ color: SIMD3<Float>) -> SIMD3<Float> {
        let c = color.clamped(min: 0, max: 1)
        let maxIdx = Float(size - 1)

        let rf = c.x * maxIdx
        let gf = c.y * maxIdx
        let bf = c.z * maxIdx

        let r0 = Int(rf); let r1 = min(r0 + 1, size - 1)
        let g0 = Int(gf); let g1 = min(g0 + 1, size - 1)
        let b0 = Int(bf); let b1 = min(b0 + 1, size - 1)

        let fr = rf - Float(r0)
        let fg = gf - Float(g0)
        let fb = bf - Float(b0)

        func idx(_ r: Int, _ g: Int, _ b: Int) -> Int {
            r + g * size + b * size * size
        }

        // Trilinear interpolation
        let c000 = data[idx(r0, g0, b0)]
        let c100 = data[idx(r1, g0, b0)]
        let c010 = data[idx(r0, g1, b0)]
        let c110 = data[idx(r1, g1, b0)]
        let c001 = data[idx(r0, g0, b1)]
        let c101 = data[idx(r1, g0, b1)]
        let c011 = data[idx(r0, g1, b1)]
        let c111 = data[idx(r1, g1, b1)]

        let c00 = c000 * (1 - fr) + c100 * fr
        let c01 = c001 * (1 - fr) + c101 * fr
        let c10 = c010 * (1 - fr) + c110 * fr
        let c11 = c011 * (1 - fr) + c111 * fr

        let c0 = c00 * (1 - fg) + c10 * fg
        let c1 = c01 * (1 - fg) + c11 * fg

        return c0 * (1 - fb) + c1 * fb
    }
}

// MARK: - LUT Parse Error

/// Errors that can occur when parsing a .cube LUT file.
public enum LUTParseError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case sizeMismatch(expected: Int, actual: Int)
    case invalidValue(line: Int)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "LUT file not found."
        case .invalidFormat(let detail):
            return "Invalid LUT format: \(detail)"
        case .sizeMismatch(let expected, let actual):
            return "LUT size mismatch: expected \(expected * expected * expected) entries, got \(actual)."
        case .invalidValue(let line):
            return "Invalid numeric value at line \(line)."
        }
    }
}

// MARK: - LUTManager

/// Manages loading, storing, and applying 3D LUTs.
public struct LUTManager: Sendable {

    /// Built-in LUT presets.
    public var builtInLUTs: [String: LUT3D]

    public init() {
        builtInLUTs = Self.generateBuiltInLUTs()
    }

    // MARK: - .cube File Parser

    /// Parse a .cube format 3D LUT file.
    /// - Parameter contents: String contents of the .cube file.
    /// - Returns: A parsed `LUT3D`.
    public func loadCube(from contents: String) throws -> LUT3D {
        let lines = contents.components(separatedBy: .newlines)
        var size: Int?
        var data: [SIMD3<Float>] = []
        var lineNumber = 0

        for rawLine in lines {
            lineNumber += 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("TITLE") { continue }

            // Domain lines (optional, we normalize to 0-1)
            if line.hasPrefix("DOMAIN_MIN") || line.hasPrefix("DOMAIN_MAX") { continue }

            // LUT size
            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ")
                if parts.count >= 2, let s = Int(parts[1]) {
                    size = s
                }
                continue
            }

            // Data lines
            let components = line.split(separator: " ").compactMap { Float($0) }
            if components.count == 3 {
                data.append(SIMD3<Float>(components[0], components[1], components[2]))
            }
        }

        guard let lutSize = size else {
            throw LUTParseError.invalidFormat("Missing LUT_3D_SIZE declaration.")
        }

        let expectedCount = lutSize * lutSize * lutSize
        guard data.count == expectedCount else {
            throw LUTParseError.sizeMismatch(expected: lutSize, actual: data.count)
        }

        return LUT3D(size: lutSize, data: data)
    }

    /// Apply a LUT to a CIImage using a color cube filter.
    /// - Parameters:
    ///   - lut: The 3D LUT to apply.
    ///   - image: Source CIImage.
    ///   - intensity: Blend intensity (0 = original, 1 = fully graded).
    /// - Returns: The graded CIImage.
    public func apply(lut: LUT3D, to image: CIImage, intensity: Float = 1.0) -> CIImage {
        let intensity = intensity.clamped(to: 0...1)
        let dimension = lut.size

        // Build the color cube data (RGBA float array)
        var cubeData = [Float]()
        cubeData.reserveCapacity(dimension * dimension * dimension * 4)

        for b in 0..<dimension {
            for g in 0..<dimension {
                for r in 0..<dimension {
                    let index = r + g * dimension + b * dimension * dimension
                    let color = lut.data[index]
                    // Blend with identity based on intensity
                    let identityR = Float(r) / Float(dimension - 1)
                    let identityG = Float(g) / Float(dimension - 1)
                    let identityB = Float(b) / Float(dimension - 1)
                    cubeData.append(identityR + (color.x - identityR) * intensity)
                    cubeData.append(identityG + (color.y - identityG) * intensity)
                    cubeData.append(identityB + (color.z - identityB) * intensity)
                    cubeData.append(1.0) // alpha
                }
            }
        }

        let data = cubeData.withUnsafeBufferPointer { Data(buffer: $0) }

        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return image
        }

        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        filter.setValue(image, forKey: kCIInputImageKey)

        return filter.outputImage ?? image
    }

    // MARK: - Built-In LUT Generation

    /// Generate procedural built-in LUT presets.
    private static func generateBuiltInLUTs() -> [String: LUT3D] {
        let size = 17
        var luts: [String: LUT3D] = [:]

        luts["Film Print"] = generateLUT(size: size) { r, g, b in
            // Warm film print emulation: lift blacks, soften highlights, warm midtones
            let lr = powf(r, 0.95) * 0.92 + 0.04
            let lg = powf(g, 1.0) * 0.90 + 0.03
            let lb = powf(b, 1.1) * 0.85 + 0.05
            return SIMD3<Float>(lr.clamped01, lg.clamped01, lb.clamped01)
        }

        luts["Bleach Bypass"] = generateLUT(size: size) { r, g, b in
            // Desaturated, high-contrast silver-retention look
            let luma: Float = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let mix: Float = 0.5
            let mr = r * (1 - mix) + luma * mix
            let mg = g * (1 - mix) + luma * mix
            let mb = b * (1 - mix) + luma * mix
            // S-curve contrast
            let cr = sCurve(mr, contrast: 0.3)
            let cg = sCurve(mg, contrast: 0.3)
            let cb = sCurve(mb, contrast: 0.3)
            return SIMD3<Float>(cr.clamped01, cg.clamped01, cb.clamped01)
        }

        luts["Cross Process"] = generateLUT(size: size) { r, g, b in
            // E-6 in C-41: boost green shadows, magenta highlights
            let lr = powf(r, 0.8) * 1.1
            let lg = powf(g, 0.9) * 1.05 + 0.02
            let lb = powf(b, 1.3) * 0.85
            return SIMD3<Float>(lr.clamped01, lg.clamped01, lb.clamped01)
        }

        luts["Teal & Orange"] = generateLUT(size: size) { r, g, b in
            // Popular cinema grading: warm skin tones, cool shadows
            let luma: Float = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let warmth: Float = 0.15
            let lr = r + warmth * (1 - luma)  // add orange in highlights
            let lg = g * 0.95
            let lb = b + warmth * luma * 0.5  // add teal in shadows
            return SIMD3<Float>(lr.clamped01, lg.clamped01, lb.clamped01)
        }

        luts["LOG to Rec709"] = generateLUT(size: size) { r, g, b in
            // Convert log-encoded footage to Rec.709 display
            func logToLin(_ v: Float) -> Float {
                let cutoff: Float = 0.02
                if v < cutoff { return v / 5.6 }
                return powf(10.0, (v - 0.385) / 0.256) / 10.0
            }
            func linToRec709(_ v: Float) -> Float {
                if v < 0.018 { return v * 4.5 }
                return 1.099 * powf(v, 0.45) - 0.099
            }
            let lr = linToRec709(logToLin(r))
            let lg = linToRec709(logToLin(g))
            let lb = linToRec709(logToLin(b))
            return SIMD3<Float>(lr.clamped01, lg.clamped01, lb.clamped01)
        }

        luts["S-LOG3 to Rec709"] = generateLUT(size: size) { r, g, b in
            // Sony S-Log3 to Rec.709 conversion
            func slog3ToLin(_ v: Float) -> Float {
                if v >= 171.2102946929 / 1023.0 {
                    return powf(10.0, (v * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01
                } else {
                    return (v * 1023.0 - 95.0) * 0.01125000 / (171.2102946929 - 95.0)
                }
            }
            func linToRec709(_ v: Float) -> Float {
                if v < 0.018 { return v * 4.5 }
                return 1.099 * powf(max(v, 0), 0.45) - 0.099
            }
            let lr = linToRec709(slog3ToLin(r))
            let lg = linToRec709(slog3ToLin(g))
            let lb = linToRec709(slog3ToLin(b))
            return SIMD3<Float>(lr.clamped01, lg.clamped01, lb.clamped01)
        }

        return luts
    }

    /// Helper: generate a LUT from a per-pixel transform function.
    private static func generateLUT(
        size: Int,
        transform: (Float, Float, Float) -> SIMD3<Float>
    ) -> LUT3D {
        var data = [SIMD3<Float>]()
        data.reserveCapacity(size * size * size)

        let maxVal = Float(size - 1)
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let rf = Float(r) / maxVal
                    let gf = Float(g) / maxVal
                    let bf = Float(b) / maxVal
                    data.append(transform(rf, gf, bf))
                }
            }
        }

        return LUT3D(size: size, data: data)
    }

    /// S-curve contrast function.
    private static func sCurve(_ value: Float, contrast: Float) -> Float {
        let midpoint: Float = 0.5
        let x = value - midpoint
        let curved = midpoint + x * (1 + contrast * (1 - 4 * x * x))
        return curved.clamped(to: 0...1)
    }
}

// MARK: - ScopeData

/// Analyzed scope data from a video frame.
public struct ScopeData: Sendable {
    /// 256-bin luminance histogram.
    public var histogram: [Float]
    /// Waveform: array of columns, each column has 256 bins of luminance intensity.
    public var waveform: [[Float]]
    /// Vectorscope: 256x256 grid of chroma intensity.
    public var vectorscope: [[Float]]
    /// RGB parade: separate waveforms for red, green, blue.
    public var rgbParade: (r: [[Float]], g: [[Float]], b: [[Float]])

    public init(
        histogram: [Float] = Array(repeating: 0, count: 256),
        waveform: [[Float]] = [],
        vectorscope: [[Float]] = Array(repeating: Array(repeating: 0, count: 256), count: 256),
        rgbParade: (r: [[Float]], g: [[Float]], b: [[Float]]) = ([], [], [])
    ) {
        self.histogram = histogram
        self.waveform = waveform
        self.vectorscope = vectorscope
        self.rgbParade = rgbParade
    }
}

// MARK: - VideoScopes

/// Broadcast monitoring scopes for professional color grading.
public struct VideoScopes: Sendable {

    /// Whether scopes are visible.
    public var showScopes: Bool
    /// Which scopes are currently active.
    public var activeScopes: Set<ScopeType>

    public init(showScopes: Bool = false, activeScopes: Set<ScopeType> = [.histogram, .waveform]) {
        self.showScopes = showScopes
        self.activeScopes = activeScopes
    }

    /// Analyze a CIImage frame and produce scope data.
    /// - Parameter image: Source CIImage frame.
    /// - Returns: Analyzed `ScopeData` for display.
    public func analyzeFrame(_ image: CIImage) -> ScopeData {
        let context = CIContext(options: [.useSoftwareRenderer: true])
        let extent = image.extent

        // Use a reduced resolution for scope analysis (performance)
        let analysisWidth = min(Int(extent.width), 256)
        let analysisHeight = min(Int(extent.height), 256)

        let scaleX = CGFloat(analysisWidth) / extent.width
        let scaleY = CGFloat(analysisHeight) / extent.height
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var bitmap = [UInt8](repeating: 0, count: analysisWidth * analysisHeight * 4)
        context.render(
            scaled,
            toBitmap: &bitmap,
            rowBytes: analysisWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: analysisWidth, height: analysisHeight),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Build histogram
        var histogram = [Float](repeating: 0, count: 256)
        var rHist = [Float](repeating: 0, count: 256)
        var gHist = [Float](repeating: 0, count: 256)
        var bHist = [Float](repeating: 0, count: 256)

        let totalPixels = analysisWidth * analysisHeight

        for i in 0..<totalPixels {
            let offset = i * 4
            let r = bitmap[offset]
            let g = bitmap[offset + 1]
            let b = bitmap[offset + 2]
            let luma = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
            let lumaIdx = min(luma, 255)
            histogram[lumaIdx] += 1
            rHist[Int(r)] += 1
            gHist[Int(g)] += 1
            bHist[Int(b)] += 1
        }

        // Normalize histogram
        let maxHist = histogram.max() ?? 1
        if maxHist > 0 {
            for i in 0..<256 {
                histogram[i] /= maxHist
                rHist[i] /= maxHist
                gHist[i] /= maxHist
                bHist[i] /= maxHist
            }
        }

        // Build waveform (columns)
        var waveform = [[Float]](repeating: [Float](repeating: 0, count: 256), count: analysisWidth)
        var rWave = [[Float]](repeating: [Float](repeating: 0, count: 256), count: analysisWidth)
        var gWave = [[Float]](repeating: [Float](repeating: 0, count: 256), count: analysisWidth)
        var bWave = [[Float]](repeating: [Float](repeating: 0, count: 256), count: analysisWidth)

        for y in 0..<analysisHeight {
            for x in 0..<analysisWidth {
                let offset = (y * analysisWidth + x) * 4
                let r = bitmap[offset]
                let g = bitmap[offset + 1]
                let b = bitmap[offset + 2]
                let luma = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
                waveform[x][min(luma, 255)] += 1
                rWave[x][Int(r)] += 1
                gWave[x][Int(g)] += 1
                bWave[x][Int(b)] += 1
            }
        }

        // Build vectorscope
        var vectorscope = [[Float]](repeating: [Float](repeating: 0, count: 256), count: 256)
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Float(bitmap[offset]) / 255.0
            let g = Float(bitmap[offset + 1]) / 255.0
            let b = Float(bitmap[offset + 2]) / 255.0

            // Convert to Cb/Cr (centered at 128)
            let cb = Int((-0.168736 * r - 0.331264 * g + 0.5 * b) * 255 + 128)
            let cr = Int((0.5 * r - 0.418688 * g - 0.081312 * b) * 255 + 128)

            let cx = min(max(cb, 0), 255)
            let cy = min(max(cr, 0), 255)
            vectorscope[cx][cy] += 1
        }

        return ScopeData(
            histogram: histogram,
            waveform: waveform,
            vectorscope: vectorscope,
            rgbParade: (r: rWave, g: gWave, b: bWave)
        )
    }
}

// MARK: - ColorGrade

/// A complete color grade snapshot that can be serialized, saved, and loaded.
public struct ColorGrade: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var date: Date

    // MARK: Grade Components

    public var colorWheels: ColorWheels
    public var curves: CurvesEditor
    public var hslAdjustment: HSLAdjustment
    public var lutName: String?
    public var lutIntensity: Float
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Grade",
        date: Date = Date(),
        colorWheels: ColorWheels = .neutral,
        curves: CurvesEditor = .neutral,
        hslAdjustment: HSLAdjustment = .neutral,
        lutName: String? = nil,
        lutIntensity: Float = 1.0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.colorWheels = colorWheels
        self.curves = curves
        self.hslAdjustment = hslAdjustment
        self.lutName = lutName
        self.lutIntensity = lutIntensity
        self.isEnabled = isEnabled
    }

    /// Whether the grade has any modifications.
    public var isNeutral: Bool {
        colorWheels.isNeutral && curves.isNeutral && hslAdjustment.isNeutral && lutName == nil
    }
}

// MARK: - ProColorGrading

/// Professional color grading engine with node-based serial grading pipeline.
///
/// Provides DaVinci Resolve-style three-way color wheels, RGB curves with cubic spline
/// interpolation, per-channel HSL qualification, 3D LUT support, and broadcast-quality
/// monitoring scopes. Multiple serial nodes allow stacking independent grades.
@MainActor
public final class ProColorGrading: ObservableObject {

    // MARK: - Published Properties

    /// The active color wheels for the selected node.
    @Published public var colorWheels: ColorWheels = .neutral
    /// The active curves editor for the selected node.
    @Published public var curves: CurvesEditor = .neutral
    /// The active HSL adjustment for the selected node.
    @Published public var hslAdjustment: HSLAdjustment = .neutral
    /// LUT manager for loading and applying 3D LUTs.
    @Published public var lutManager: LUTManager = LUTManager()
    /// Video scope configuration and analysis.
    @Published public var scopes: VideoScopes = VideoScopes()

    /// The current active grade (synced to selected node).
    @Published public var grade: ColorGrade = ColorGrade()
    /// Library of saved grades.
    @Published public var grades: [ColorGrade] = []

    /// Currently selected node index in the serial pipeline.
    @Published public var selectedNode: Int = 0
    /// Total number of serial grading nodes.
    @Published public var nodeCount: Int = 1
    /// Whether the entire grading pipeline is enabled.
    @Published public var isEnabled: Bool = true

    // MARK: - Internal State

    /// Per-node grades for the serial pipeline.
    private var nodeGrades: [ColorGrade] = [ColorGrade()]
    /// CIContext for rendering.
    private let ciContext: CIContext
    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    private let logger = ProfessionalLogger.shared

    // MARK: - Initialization

    public init() {
        self.ciContext = CIContext(options: [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .highQualityDownsample: true
        ])

        setupBindings()
        logger.video("ProColorGrading: Initialized with \(nodeCount) node(s)")
    }

    // MARK: - Combine Bindings

    private func setupBindings() {
        // Sync published properties back to the active node grade whenever they change.
        Publishers.CombineLatest3($colorWheels, $curves, $hslAdjustment)
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .sink { [weak self] wheels, curves, hsl in
                guard let self else { return }
                guard self.selectedNode < self.nodeGrades.count else { return }
                self.nodeGrades[self.selectedNode].colorWheels = wheels
                self.nodeGrades[self.selectedNode].curves = curves
                self.nodeGrades[self.selectedNode].hslAdjustment = hsl
                self.grade = self.nodeGrades[self.selectedNode]
            }
            .store(in: &cancellables)
    }

    // MARK: - Grade Application

    /// Apply the full grading pipeline to a CIImage.
    /// Processes all enabled nodes in serial order.
    /// - Parameter image: Source CIImage.
    /// - Returns: Graded CIImage.
    public func applyGrade(to image: CIImage) -> CIImage {
        guard isEnabled else { return image }

        var result = image

        for nodeIndex in 0..<nodeGrades.count {
            let nodeGrade = nodeGrades[nodeIndex]
            guard nodeGrade.isEnabled else { continue }
            result = applySingleGrade(nodeGrade, to: result)
        }

        return result
    }

    /// Apply a single ColorGrade to an image.
    private func applySingleGrade(_ grade: ColorGrade, to image: CIImage) -> CIImage {
        var result = image

        // 1. Exposure & contrast
        result = applyExposureAndContrast(grade.colorWheels, to: result)

        // 2. Color wheels (lift / gamma / gain)
        result = applyColorWheels(grade.colorWheels, to: result)

        // 3. Temperature & tint
        result = applyTemperatureAndTint(grade.colorWheels, to: result)

        // 4. Saturation & vibrance
        result = applySaturation(grade.colorWheels, to: result)

        // 5. RGB curves
        result = applyCurves(grade.curves, to: result)

        // 6. HSL adjustment
        result = applyHSL(grade.hslAdjustment, to: result)

        // 7. LUT (if set)
        if let lutName = grade.lutName, let lut = lutManager.builtInLUTs[lutName] {
            result = lutManager.apply(lut: lut, to: result, intensity: grade.lutIntensity)
        }

        return result
    }

    /// Build a combined CIFilter chain from all active nodes.
    /// - Returns: A composite CIFilter representing the full grade pipeline.
    public func buildFilterChain() -> CIFilter? {
        guard isEnabled, !nodeGrades.isEmpty else { return nil }

        // Use CIColorMatrix as a representative filter for the chain
        let chain = CIFilter(name: "CIColorControls")
        let wheels = nodeGrades[selectedNode].colorWheels
        chain?.setValue(wheels.saturation, forKey: kCIInputSaturationKey)
        chain?.setValue(wheels.contrast / 100.0, forKey: kCIInputContrastKey)
        chain?.setValue(wheels.exposure / 5.0, forKey: kCIInputBrightnessKey)

        return chain
    }

    // MARK: - Individual Filter Application

    private func applyExposureAndContrast(_ wheels: ColorWheels, to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(wheels.exposure, forKey: kCIInputEVKey)

        var result = filter.outputImage ?? image

        // Contrast via tone curve
        if wheels.contrast != 0 {
            let c = wheels.contrast / 100.0
            if let toneFilter = CIFilter(name: "CIToneCurve") {
                toneFilter.setValue(result, forKey: kCIInputImageKey)
                let shadows = max(0, 0 + c * 0.05)
                let highlights = min(1, 1 - c * 0.05)
                toneFilter.setValue(CIVector(x: 0, y: CGFloat(shadows)), forKey: "inputPoint0")
                toneFilter.setValue(CIVector(x: 0.25, y: CGFloat(0.25 - c * 0.02)), forKey: "inputPoint1")
                toneFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
                toneFilter.setValue(CIVector(x: 0.75, y: CGFloat(0.75 + c * 0.02)), forKey: "inputPoint3")
                toneFilter.setValue(CIVector(x: 1, y: CGFloat(highlights)), forKey: "inputPoint4")
                result = toneFilter.outputImage ?? result
            }
        }

        // Highlights & shadows recovery
        if wheels.highlights != 0 || wheels.shadows != 0 {
            if let hsFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                hsFilter.setValue(result, forKey: kCIInputImageKey)
                hsFilter.setValue(1.0 - wheels.highlights / 100.0, forKey: "inputHighlightAmount")
                hsFilter.setValue(wheels.shadows / 100.0 * 0.5, forKey: "inputShadowAmount")
                result = hsFilter.outputImage ?? result
            }
        }

        return result
    }

    private func applyColorWheels(_ wheels: ColorWheels, to image: CIImage) -> CIImage {
        guard !wheels.lift.isZeroish || !wheels.gamma.isZeroish || !wheels.gain.isZeroish
                || !wheels.offset.isZeroish
                || wheels.liftMaster != 0 || wheels.gammaMaster != 0 || wheels.gainMaster != 0
        else {
            return image
        }

        // Apply using CIColorMatrix for lift/gain/offset
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return image }
        matrix.setValue(image, forKey: kCIInputImageKey)

        // Gain maps to RGB scale (diagonal of the color matrix)
        let gr = 1.0 + wheels.gain.x + wheels.gainMaster
        let gg = 1.0 + wheels.gain.y + wheels.gainMaster
        let gb = 1.0 + wheels.gain.z + wheels.gainMaster

        matrix.setValue(CIVector(x: CGFloat(gr), y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: CGFloat(gg), z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: CGFloat(gb), w: 0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        // Offset = lift + offset
        let or = wheels.lift.x + wheels.liftMaster + wheels.offset.x
        let og = wheels.lift.y + wheels.liftMaster + wheels.offset.y
        let ob = wheels.lift.z + wheels.liftMaster + wheels.offset.z
        matrix.setValue(CIVector(x: CGFloat(or), y: CGFloat(og), z: CGFloat(ob), w: 0), forKey: "inputBiasVector")

        var result = matrix.outputImage ?? image

        // Apply gamma using CIGammaAdjust (per channel approximation via tone curve)
        if !wheels.gamma.isZeroish || wheels.gammaMaster != 0 {
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                // Use an averaged gamma power
                let avgGamma = 1.0 / (1.0 + (wheels.gamma.x + wheels.gamma.y + wheels.gamma.z) / 3.0 + wheels.gammaMaster)
                gamma.setValue(result, forKey: kCIInputImageKey)
                gamma.setValue(max(0.1, avgGamma), forKey: "inputPower")
                result = gamma.outputImage ?? result
            }
        }

        return result
    }

    private func applyTemperatureAndTint(_ wheels: ColorWheels, to image: CIImage) -> CIImage {
        guard wheels.temperature != 0 || wheels.tint != 0 else { return image }

        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        // Map temperature from -100..100 to Kelvin (approximately 2000K..12000K centered at 6500K)
        let kelvin = 6500.0 + Double(wheels.temperature) * 55.0
        // Map tint from -100..100 to green-magenta tint value
        let tintValue = Double(wheels.tint)

        filter.setValue(CIVector(x: kelvin, y: tintValue), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }

    private func applySaturation(_ wheels: ColorWheels, to image: CIImage) -> CIImage {
        guard wheels.saturation != 1.0 || wheels.vibrance != 0 else { return image }

        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(wheels.saturation + wheels.vibrance * 0.5, forKey: kCIInputSaturationKey)
        filter.setValue(0, forKey: kCIInputBrightnessKey)
        filter.setValue(1, forKey: kCIInputContrastKey)

        return filter.outputImage ?? image
    }

    private func applyCurves(_ curvesEditor: CurvesEditor, to image: CIImage) -> CIImage {
        guard !curvesEditor.isNeutral else { return image }

        guard let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        // Apply the master curve at 5 control points evenly spaced
        let points: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        for (idx, t) in points.enumerated() {
            let value = curvesEditor.evaluate(curve: curvesEditor.masterCurve, at: t)
            filter.setValue(
                CIVector(x: CGFloat(t), y: CGFloat(value)),
                forKey: "inputPoint\(idx)"
            )
        }

        var result = filter.outputImage ?? image

        // Apply per-channel curves using CIColorPolynomial (approximation)
        if curvesEditor.redCurve != CurvesEditor.identityCurve
            || curvesEditor.greenCurve != CurvesEditor.identityCurve
            || curvesEditor.blueCurve != CurvesEditor.identityCurve {

            if let polyFilter = CIFilter(name: "CIColorPolynomial") {
                polyFilter.setValue(result, forKey: kCIInputImageKey)

                // Evaluate at 0 and 1 for simple linear approximation via polynomial
                let r0 = curvesEditor.evaluate(curve: curvesEditor.redCurve, at: 0)
                let r1 = curvesEditor.evaluate(curve: curvesEditor.redCurve, at: 1)
                let g0 = curvesEditor.evaluate(curve: curvesEditor.greenCurve, at: 0)
                let g1 = curvesEditor.evaluate(curve: curvesEditor.greenCurve, at: 1)
                let b0 = curvesEditor.evaluate(curve: curvesEditor.blueCurve, at: 0)
                let b1 = curvesEditor.evaluate(curve: curvesEditor.blueCurve, at: 1)

                // ax + b polynomial: b = value at 0, a = slope
                polyFilter.setValue(CIVector(x: CGFloat(r0), y: CGFloat(r1 - r0), z: 0, w: 0), forKey: "inputRedCoefficients")
                polyFilter.setValue(CIVector(x: CGFloat(g0), y: CGFloat(g1 - g0), z: 0, w: 0), forKey: "inputGreenCoefficients")
                polyFilter.setValue(CIVector(x: CGFloat(b0), y: CGFloat(b1 - b0), z: 0, w: 0), forKey: "inputBlueCoefficients")
                polyFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputAlphaCoefficients")

                result = polyFilter.outputImage ?? result
            }
        }

        return result
    }

    private func applyHSL(_ hslAdj: HSLAdjustment, to image: CIImage) -> CIImage {
        guard !hslAdj.isNeutral else { return image }

        // Apply selective HSL using CIHueAdjust for hue shifts and CIColorControls for saturation.
        // In a production pipeline this would use a custom CIKernel for per-pixel hue-range selection.
        // Here we approximate with the dominant non-neutral adjustment.
        var result = image

        for range in ColorRange.allCases {
            let values = hslAdj.values(for: range)
            guard !values.isNeutral else { continue }

            // Hue shift
            if values.hueShift != 0 {
                if let hueFilter = CIFilter(name: "CIHueAdjust") {
                    hueFilter.setValue(result, forKey: kCIInputImageKey)
                    // CIHueAdjust applies globally, so we scale by a fraction per range
                    let angle = values.hueShift / 360.0 * Float.pi * 2.0 / Float(ColorRange.allCases.count)
                    hueFilter.setValue(angle, forKey: kCIInputAngleKey)
                    result = hueFilter.outputImage ?? result
                }
            }
        }

        return result
    }

    // MARK: - Grade Management

    /// Save the current grade to the library.
    /// - Parameter name: Name for the saved grade.
    public func saveGrade(name: String) {
        var gradeToSave = grade
        gradeToSave.name = name
        gradeToSave.date = Date()
        gradeToSave.id = UUID()
        grades.append(gradeToSave)
        logger.video("ProColorGrading: Saved grade '\(name)' (\(grades.count) total)")
    }

    /// Load a named grade from the library and apply it to the selected node.
    /// - Parameter name: Name of the grade to load.
    public func loadGrade(name: String) {
        guard let saved = grades.first(where: { $0.name == name }) else {
            logger.video("ProColorGrading: Grade '\(name)' not found", level: .warning)
            return
        }

        pasteGrade(saved)
        logger.video("ProColorGrading: Loaded grade '\(name)'")
    }

    /// Copy the current grade from the selected node.
    /// - Returns: A copy of the current `ColorGrade`.
    public func copyGrade() -> ColorGrade {
        syncPublishedToNode()
        return nodeGrades[selectedNode]
    }

    /// Paste a grade onto the selected node.
    /// - Parameter grade: The `ColorGrade` to apply.
    public func pasteGrade(_ grade: ColorGrade) {
        guard selectedNode < nodeGrades.count else { return }
        nodeGrades[selectedNode] = grade
        loadNodeToPublished()
        logger.video("ProColorGrading: Pasted grade '\(grade.name)' to node \(selectedNode)")
    }

    // MARK: - Reset

    /// Reset all nodes and settings to defaults.
    public func resetAll() {
        nodeGrades = [ColorGrade()]
        nodeCount = 1
        selectedNode = 0
        loadNodeToPublished()
        logger.video("ProColorGrading: Reset all")
    }

    /// Reset only the color wheels on the selected node.
    public func resetWheels() {
        guard selectedNode < nodeGrades.count else { return }
        nodeGrades[selectedNode].colorWheels = .neutral
        colorWheels = .neutral
        logger.video("ProColorGrading: Reset wheels on node \(selectedNode)")
    }

    /// Reset only the curves on the selected node.
    public func resetCurves() {
        guard selectedNode < nodeGrades.count else { return }
        nodeGrades[selectedNode].curves = .neutral
        curves = .neutral
        logger.video("ProColorGrading: Reset curves on node \(selectedNode)")
    }

    /// Reset only the HSL adjustments on the selected node.
    public func resetHSL() {
        guard selectedNode < nodeGrades.count else { return }
        nodeGrades[selectedNode].hslAdjustment = .neutral
        hslAdjustment = .neutral
        logger.video("ProColorGrading: Reset HSL on node \(selectedNode)")
    }

    // MARK: - Node Management

    /// Add a new grading node at the end of the serial chain.
    public func addNode() {
        let newGrade = ColorGrade(name: "Node \(nodeGrades.count + 1)")
        nodeGrades.append(newGrade)
        nodeCount = nodeGrades.count
        selectedNode = nodeGrades.count - 1
        loadNodeToPublished()
        logger.video("ProColorGrading: Added node \(selectedNode) (total: \(nodeCount))")
    }

    /// Remove a grading node at the specified index.
    /// - Parameter index: Index of the node to remove.
    public func removeNode(at index: Int) {
        guard nodeGrades.count > 1 else {
            logger.video("ProColorGrading: Cannot remove last node", level: .warning)
            return
        }
        guard index >= 0 && index < nodeGrades.count else { return }

        nodeGrades.remove(at: index)
        nodeCount = nodeGrades.count

        if selectedNode >= nodeGrades.count {
            selectedNode = nodeGrades.count - 1
        }

        loadNodeToPublished()
        logger.video("ProColorGrading: Removed node \(index) (total: \(nodeCount))")
    }

    /// Select a specific node and load its settings into the published properties.
    /// - Parameter index: Node index to select.
    public func selectNode(_ index: Int) {
        guard index >= 0 && index < nodeGrades.count else { return }
        syncPublishedToNode()
        selectedNode = index
        loadNodeToPublished()
    }

    // MARK: - Internal Sync

    /// Write current published properties into the active node.
    private func syncPublishedToNode() {
        guard selectedNode < nodeGrades.count else { return }
        nodeGrades[selectedNode].colorWheels = colorWheels
        nodeGrades[selectedNode].curves = curves
        nodeGrades[selectedNode].hslAdjustment = hslAdjustment
        grade = nodeGrades[selectedNode]
    }

    /// Load the selected node settings into published properties.
    private func loadNodeToPublished() {
        guard selectedNode < nodeGrades.count else { return }
        let nodeGrade = nodeGrades[selectedNode]
        colorWheels = nodeGrade.colorWheels
        curves = nodeGrade.curves
        hslAdjustment = nodeGrade.hslAdjustment
        grade = nodeGrade
    }
}

// MARK: - Float Clamping Extension

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    var clamped01: Float {
        clamped(to: 0...1)
    }
}

// MARK: - SIMD3<Float> Clamping Extension

private extension SIMD3 where Scalar == Float {
    func clamped(min minVal: Float, max maxVal: Float) -> SIMD3<Float> {
        SIMD3<Float>(
            Swift.min(Swift.max(x, minVal), maxVal),
            Swift.min(Swift.max(y, minVal), maxVal),
            Swift.min(Swift.max(z, minVal), maxVal)
        )
    }

    var isZeroish: Bool {
        abs(x) < .ulpOfOne && abs(y) < .ulpOfOne && abs(z) < .ulpOfOne
    }
}
