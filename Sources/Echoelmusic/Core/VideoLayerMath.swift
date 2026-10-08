// VideoLayerMath.swift
// Echoel — GMMW VV-4: the pure arithmetic a footage layer needs before it can be drawn — how big the
// picture is once the file's own orientation is applied, where it sits fitted into the visual, how
// bright a pixel is, and the region luminances `VideoFlashLimiter` counts on. Foundation only, so the
// blocking bundle drives every function and no renderer has to be trusted with the numbers.
//
// ⭐ ORIENTATION COMES FROM THE FILE'S TRANSFORM, NOT ITS PIXEL SIZE. A phone stores a portrait clip
// as landscape pixels plus a quarter-turn `preferredTransform`; fitting the pixel size would show it
// on its side and squashed. The four matrix entries (a, b, c, d) are passed as Doubles rather than a
// `CGAffineTransform`, so this file needs no graphics framework; the translation does not change a
// size and is not needed.
//
// ⭐ LUMINANCE IS WCAG's relative luminance: the sRGB curve undone (IEC 61966-2-1, 0.04045 knee —
// WCAG 2.x quotes 0.03928, and the two differ by less than one 8-bit step), then the BT.709 weights.
// Video is usually BT.709-encoded; its weights are the same, its transfer curve differs slightly, and
// for a flash COUNT that difference is far below the threshold.
//
// Guard: `UserFootageCannotStrobeTests`.

import Foundation

public enum VideoLayerMath {

    /// The BT.709 weights of linear red, green and blue in relative luminance.
    public static let redWeight = 0.2126
    public static let greenWeight = 0.7152
    public static let blueWeight = 0.0722

    /// Cells per side handed to the flash limiter (an 8 × 8 grid). The limiter reads them through
    /// overlapping 2 × 2 and 4 × 4 windows, so its smallest window is a sixteenth of the picture —
    /// about the smallest area WCAG counts on a phone held at reading distance — and it can sit at
    /// any half-window offset (review of VV-4: fixed 4 × 4 blocks diluted a flash on a corner).
    public static let flashCellsPerSide = 8

    /// The relative luminance of an sRGB colour whose components are 0…1. Non-finite components
    /// read as 0 and every component is clamped first, so the answer is always 0…1.
    public static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ component: Double) -> Double {
            let c = component.isFinite ? Swift.min(1, Swift.max(0, component)) : 0
            return c <= 0.04045 ? c / 12.92 : Foundation.pow((c + 0.055) / 1.055, 2.4)
        }
        let r: Double = redWeight * linear(red)
        let g: Double = greenWeight * linear(green)
        let b: Double = blueWeight * linear(blue)
        return Swift.min(1, r + g + b)
    }

    /// The mean of each `blocks × blocks` block of a row-major `side × side` grid, row-major.
    /// nil when the grid is not `side × side` (a side too large to square counts as that, it does
    /// not trap), when `side` does not divide into `blocks`, or when a value is non-finite — the
    /// limiter then gets no frame rather than a wrong one.
    public static func regionMeans(_ grid: [Double], side: Int, blocks: Int) -> [Double]? {
        guard side > 0, blocks > 0, side % blocks == 0 else { return nil }
        let (cellCount, overflow) = side.multipliedReportingOverflow(by: side)
        guard !overflow, grid.count == cellCount, grid.allSatisfy({ $0.isFinite }) else { return nil }
        let span = side / blocks
        let cellsPerBlock = Double(span * span)
        var means: [Double] = []
        means.reserveCapacity(blocks * blocks)
        for blockRow in 0..<blocks {
            for blockColumn in 0..<blocks {
                var sum = 0.0
                for y in (blockRow * span)..<((blockRow + 1) * span) {
                    for x in (blockColumn * span)..<((blockColumn + 1) * span) {
                        sum += grid[y * side + x]
                    }
                }
                means.append(sum / cellsPerBlock)
            }
        }
        return means
    }

    /// How a file's transform turns its pixels: whole quarter turns counter-clockwise (0…3) in the
    /// transform's own convention, and whether it mirrors.
    public struct Orientation: Equatable, Sendable {
        public var quarterTurns: Int
        public var mirrored: Bool
    }

    /// The orientation of a transform's (a, b, c, d), or nil when it is not finite or not invertible.
    public static func orientation(a: Double, b: Double, c: Double, d: Double) -> Orientation? {
        guard [a, b, c, d].allSatisfy({ $0.isFinite }) else { return nil }
        let determinant: Double = a * d - b * c
        guard determinant != 0 else { return nil }
        let turns = Int((Foundation.atan2(b, a) / (Double.pi / 2)).rounded())
        return Orientation(quarterTurns: ((turns % 4) + 4) % 4, mirrored: determinant < 0)
    }

    /// The size a picture of `width × height` pixels is SHOWN at once its transform is applied —
    /// the bounding box of the turned rectangle. nil for a non-finite or empty result.
    public static func displaySize(width: Double, height: Double,
                                   a: Double, b: Double, c: Double, d: Double) -> (width: Double, height: Double)? {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        let shownWidth: Double = Swift.abs(a * width) + Swift.abs(c * height)
        let shownHeight: Double = Swift.abs(b * width) + Swift.abs(d * height)
        guard shownWidth.isFinite, shownHeight.isFinite, shownWidth > 0, shownHeight > 0 else { return nil }
        return (shownWidth, shownHeight)
    }

    /// A picture fitted whole into a container, centred: the rectangle it covers, in the
    /// container's units, origin top-left.
    public struct Fit: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    /// `content` fitted whole into `container` (aspect-fit, letterboxed), or nil when either size is
    /// not finite and positive.
    public static func aspectFit(contentWidth: Double, contentHeight: Double,
                                 containerWidth: Double, containerHeight: Double) -> Fit? {
        let sizes = [contentWidth, contentHeight, containerWidth, containerHeight]
        guard sizes.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let scale = Swift.min(containerWidth / contentWidth, containerHeight / contentHeight)
        let width: Double = contentWidth * scale
        let height: Double = contentHeight * scale
        return Fit(x: (containerWidth - width) / 2, y: (containerHeight - height) / 2,
                   width: width, height: height)
    }
}
