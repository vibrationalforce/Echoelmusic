// MediaSeed.swift
// Echoel — what a picture gives to the music and the visuals, measured once (founder order
// 2026-09-27: "Foto und Video werden zu kreativem Material"). A seed is the deterministic,
// numeric summary of a still: dominant colour, brightness, saturation, contrast. It is the
// thing a surface APPLIES — never the picture itself.
//
// ⭐ PURE AND FOUNDATION-ONLY, ON PURPOSE. Decoding a file is ImageIO's job and happens off the
// main actor (`Studio/PhotoSeedDecoder`); this file sees only an already-downsampled RGBA8
// buffer. So the whole rule set — what "dominant" means, how contrast is normalised, what an
// invalid buffer does — is drivable by the blocking bundle without a picture, a camera or a
// device, and the same bytes always give the same seed.
//
// ⭐ BOUNDED BY CONSTRUCTION. `analyzeRGBA8` refuses a buffer wider or taller than
// `maxAnalysisSide`: the decoder must downsample first. The loop is therefore at most
// `maxAnalysisSide²` pixels with a fixed 36-bin histogram — no allocation that grows with
// the picture.
//
// ⚠️ WHAT THE NUMBERS ARE, AND ARE NOT.
// · `brightness` is the mean Rec. 709 luma of the sRGB-ENCODED values (0…1). It is a picture
//   statistic, not a light measurement.
// · `saturation` is the mean HSV saturation (0…1).
// · `contrast` is the RMS contrast of that luma, normalised by 0.5 — the largest standard
//   deviation a 0…1 signal can have — so 1 is a pure black/white checkerboard.
// · `hue` is the weighted mean hue of the strongest 10° hue bin, where a pixel votes with
//   saturation × value. Pixels too grey or too dark to have a hue do not vote. A picture in
//   which fewer than `minColourShare` of the pixels vote has NO dominant colour, and says so
//   (`hasDominantColour == false`) instead of reporting the hue of its noise.
// ⛔ Nothing here detects a body, a face or a scene. It is colour statistics.

import Foundation

/// The numeric summary of one still picture.
public struct MediaSeed: Codable, Sendable, Equatable {

    /// Bumped when the analysis changes meaning, so a stored seed can say which rules made it.
    public static let formatVersion = 1

    public var version: Int
    /// Weighted mean hue of the dominant hue bin, 0 ≤ hue < 1 (one turn). 0 when there is no
    /// dominant colour.
    public var hue: Double
    /// Mean sRGB of the dominant bin's voting pixels, each 0…1. When there is no dominant
    /// colour this is the mean colour of the whole picture.
    public var dominantRed: Double
    public var dominantGreen: Double
    public var dominantBlue: Double
    /// Mean Rec. 709 luma, 0…1.
    public var brightness: Double
    /// Mean HSV saturation, 0…1.
    public var saturation: Double
    /// RMS luma contrast normalised to 0…1.
    public var contrast: Double
    /// False for a grey, near-black or colour-noise picture: then `hue` means nothing.
    public var hasDominantColour: Bool
    /// How many pixels were read (after the decoder's downsampling).
    public var sampledPixels: Int
}

/// The analysis rules. Every threshold is named here once.
public enum MediaSeedAnalysis {

    /// The longest side the analysis accepts. The decoder downsamples to this first.
    public static let maxAnalysisSide = 256
    /// Number of hue bins (10° each).
    public static let hueBins = 36
    /// A pixel below this HSV saturation has no hue to vote with.
    public static let chromaFloor = 0.12
    /// A pixel below this HSV value is too dark to have a hue.
    public static let valueFloor = 0.08
    /// Share of all pixels that must vote before a picture has a dominant colour.
    public static let minColourShare = 0.05

    /// The seed of a tightly or loosely packed RGBA8 buffer (alpha is ignored), or `nil` when
    /// the buffer cannot be what it claims: a non-positive or over-limit size, a row stride
    /// shorter than a row, or fewer bytes than the rows need. `nil` is the safe fallback — the
    /// caller applies nothing and says the picture could not be read.
    public static func analyzeRGBA8(_ bytes: [UInt8], width: Int, height: Int,
                                    bytesPerRow: Int) -> MediaSeed? {
        guard width > 0, height > 0,
              width <= maxAnalysisSide, height <= maxAnalysisSide,
              bytesPerRow >= width * 4,
              bytes.count >= bytesPerRow * (height - 1) + width * 4 else { return nil }

        var binWeight = [Double](repeating: 0, count: hueBins)
        var binHue = [Double](repeating: 0, count: hueBins)
        var binR = [Double](repeating: 0, count: hueBins)
        var binG = [Double](repeating: 0, count: hueBins)
        var binB = [Double](repeating: 0, count: hueBins)
        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var sumLuma = 0.0, sumLumaSquared = 0.0, sumSaturation = 0.0
        var voters = 0

        for y in 0..<height {
            let row = y * bytesPerRow
            for x in 0..<width {
                let i = row + x * 4
                let r = Double(bytes[i]) / 255
                let g = Double(bytes[i + 1]) / 255
                let b = Double(bytes[i + 2]) / 255
                sumR += r; sumG += g; sumB += b
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                sumLuma += luma
                sumLumaSquared += luma * luma
                let hsv = Self.hsv(r, g, b)
                sumSaturation += hsv.s
                guard hsv.s >= chromaFloor, hsv.v >= valueFloor else { continue }
                voters += 1
                let bin = Swift.min(Int(hsv.h * Double(hueBins)), hueBins - 1)
                let weight = hsv.s * hsv.v
                binWeight[bin] += weight
                binHue[bin] += hsv.h * weight
                binR[bin] += r * weight
                binG[bin] += g * weight
                binB[bin] += b * weight
            }
        }

        let count = Double(width * height)
        let meanLuma = sumLuma / count
        let variance = Swift.max(0, sumLumaSquared / count - meanLuma * meanLuma)
        let contrast = Swift.min(1, variance.squareRoot() / 0.5)

        // First maximum wins, so ties resolve to the lowest hue: the same bytes, the same seed.
        var best = 0
        for bin in 1..<hueBins where binWeight[bin] > binWeight[best] { best = bin }
        let hasColour = Double(voters) / count >= minColourShare && binWeight[best] > 0

        let hue: Double, red: Double, green: Double, blue: Double
        if hasColour {
            let w = binWeight[best]
            let h = binHue[best] / w
            hue = h >= 1 ? 0 : h
            red = binR[best] / w; green = binG[best] / w; blue = binB[best] / w
        } else {
            hue = 0
            red = sumR / count; green = sumG / count; blue = sumB / count
        }
        return MediaSeed(version: MediaSeed.formatVersion, hue: hue,
                         dominantRed: red, dominantGreen: green, dominantBlue: blue,
                         brightness: meanLuma, saturation: sumSaturation / count,
                         contrast: contrast, hasDominantColour: hasColour,
                         sampledPixels: width * height)
    }

    /// HSV of one sRGB pixel; h in 0..<1. Grey returns h = 0, s = 0.
    static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
        let maxC = Swift.max(r, g, b)
        let minC = Swift.min(r, g, b)
        let delta = maxC - minC
        guard maxC > 0, delta > 0 else { return (0, 0, maxC) }
        var h: Double
        if maxC == r {
            h = (g - b) / delta
            if h < 0 { h += 6 }
        } else if maxC == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h /= 6
        return (h >= 1 ? 0 : h, delta / maxC, maxC)
    }
}
