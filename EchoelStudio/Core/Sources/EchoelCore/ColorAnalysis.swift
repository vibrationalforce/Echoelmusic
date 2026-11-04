import Foundation

/// What Auto Enhance and Match Color measure in a few frames of a part (COLOR), and the values they
/// derive from it. Pure functions of pixels: the app reads the frames off the main thread and hands
/// them in; nothing here touches a file. The results are only values for the grade's own controls —
/// the musician sees them, changes them, and one Undo takes them back.
public enum ColorAnalysis {
    /// The pixels worth reading: every channel a number. The rest are left out, never guessed.
    public static func usable(_ pixels: [ColorSample]) -> [ColorSample] {
        pixels.filter(\.isFinite).map {
            ColorSample(red: Swift.min(Swift.max($0.red, 0), 1), green: Swift.min(Swift.max($0.green, 0), 1),
                        blue: Swift.min(Swift.max($0.blue, 0), 1))
        }
    }

    /// At most `limit` pixels, taken evenly across `pixels`, so a measurement costs the same however
    /// large the frames were.
    public static func thinned(_ pixels: [ColorSample], limit: Int = 8_192) -> [ColorSample] {
        guard limit > 0, pixels.count > limit else { return pixels }
        let stride = Double(pixels.count) / Double(limit)
        return (0..<limit).map { pixels[Swift.min(pixels.count - 1, Int(Double($0) * stride))] }
    }

    /// The mean of each channel in linear light; nil without a usable pixel.
    public static func linearMeans(_ pixels: [ColorSample]) -> (red: Double, green: Double, blue: Double)? {
        let clean = usable(pixels)
        guard !clean.isEmpty else { return nil }
        var red = 0.0, green = 0.0, blue = 0.0
        for pixel in clean {
            red += ColorTransfer.decode(pixel.red)
            green += ColorTransfer.decode(pixel.green)
            blue += ColorTransfer.decode(pixel.blue)
        }
        let count = Double(clean.count)
        return (red / count, green / count, blue / count)
    }

    /// The encoded luma below which a share `fraction` (0 … 1) of the pixels lie; nil without a usable pixel.
    public static func lumaPercentile(_ pixels: [ColorSample], _ fraction: Double) -> Double? {
        let lumas = usable(pixels).map(\.luma).sorted()
        guard !lumas.isEmpty, fraction.isFinite else { return nil }
        let place = Swift.min(Swift.max(fraction, 0), 1) * Double(lumas.count - 1)
        let low = Int(place.rounded(.down)), high = Swift.min(low + 1, lumas.count - 1)
        return lumas[low] + (lumas[high] - lumas[low]) * (place - Double(low))
    }

    /// A pixel in CIE L*a*b* (D65).
    public static func lab(_ pixel: ColorSample) -> (l: Double, a: Double, b: Double) {
        let red = ColorTransfer.decode(pixel.red), green = ColorTransfer.decode(pixel.green), blue = ColorTransfer.decode(pixel.blue)
        let x = (0.412_456_4 * red + 0.357_576_1 * green + 0.180_437_5 * blue) / 0.950_47
        let y = 0.212_672_9 * red + 0.715_152_2 * green + 0.072_175_0 * blue
        let z = (0.019_333_9 * red + 0.119_192_0 * green + 0.950_304_1 * blue) / 1.088_83
        func f(_ t: Double) -> Double { t > 216.0 / 24_389 ? Foundation.cbrt(t) : (24_389.0 / 27 * t + 16) / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Mean and spread of each L*a*b* channel — what Reinhard's colour transfer moves.
    public struct LabStatistics: Equatable, Sendable {
        public var meanL: Double, meanA: Double, meanB: Double
        public var deviationL: Double, deviationA: Double, deviationB: Double

        /// The spread of the colour around its mean, both chroma axes together.
        public var chromaDeviation: Double { (deviationA * deviationA + deviationB * deviationB).squareRoot() }
    }

    /// The statistics of `pixels`; nil without a usable pixel.
    public static func labStatistics(_ pixels: [ColorSample]) -> LabStatistics? {
        let values = usable(pixels).map(lab)
        guard !values.isEmpty else { return nil }
        let count = Double(values.count)
        let meanL = values.reduce(0) { $0 + $1.l } / count
        let meanA = values.reduce(0) { $0 + $1.a } / count
        let meanB = values.reduce(0) { $0 + $1.b } / count
        func deviation(_ part: ((l: Double, a: Double, b: Double)) -> Double, _ mean: Double) -> Double {
            (values.reduce(0) { $0 + (part($1) - mean) * (part($1) - mean) } / count).squareRoot()
        }
        return LabStatistics(meanL: meanL, meanA: meanA, meanB: meanB,
                             deviationL: deviation({ $0.l }, meanL), deviationA: deviation({ $0.a }, meanA),
                             deviationB: deviation({ $0.b }, meanB))
    }
}

extension ColorGrade {
    /// Where Auto Enhance puts the median luma (encoded): about 18 % grey, the contrast pivot.
    public static let autoMedian = ColorGrade.contrastPivot
    /// The encoded luma span Auto Enhance aims the 2nd to 98th percentile at.
    public static let autoSpread = 0.86
    /// The exposure Auto Enhance chooses at most, either way.
    public static let autoExposureRange: ClosedRange<Double> = -2...2
    /// The contrast Auto Enhance chooses, at least and at most.
    public static let autoContrastRange: ClosedRange<Double> = 0.6...1.8

    /// Gray World: the white balance under which the mean colour of `pixels` is neutral — the
    /// three linear channel means equal, at their geometric mean. Only temperature and tint are
    /// set; a picture without a usable pixel, or with a black channel, gets the standard grade.
    public static func grayWorld(_ pixels: [ColorSample]) -> ColorGrade {
        guard let means = ColorAnalysis.linearMeans(pixels), means.red > 1e-6, means.green > 1e-6, means.blue > 1e-6 else {
            return .neutral
        }
        let middle = Foundation.cbrt(means.red * means.green * means.blue)
        let red = Foundation.log2(middle / means.red), green = Foundation.log2(middle / means.green)
        let blue = Foundation.log2(middle / means.blue)
        // red = t + n/2, green = −n, blue = −t + n/2 (the gains of `Mapping`).
        var grade = ColorGrade.neutral
        grade.temperature = Self.held((red - blue) / 2, temperatureRange)
        grade.tint = Self.held(-green, tintRange)
        return grade
    }

    /// Auto Enhance: Gray World for the white balance, the exposure that brings the median luma to
    /// `autoMedian`, then the contrast that spreads the 2nd to 98th percentile over `autoSpread`.
    /// Saturation, lift, gamma and gain stay standard. Derived from `pixels` — a few frames of the
    /// part as its file shows them, with no grade.
    public static func autoEnhanced(_ pixels: [ColorSample]) -> ColorGrade {
        let clean = ColorAnalysis.thinned(ColorAnalysis.usable(pixels))
        guard !clean.isEmpty else { return .neutral }
        var grade = grayWorld(clean)
        if let median = ColorAnalysis.lumaPercentile(grade.apply(clean), 0.5), median > 1e-4 {
            let stops = Foundation.log2(ColorTransfer.decode(autoMedian) / ColorTransfer.decode(median))
            grade.exposure = held(stops, autoExposureRange)
        }
        // The spread, measured again after each step: a channel that clips narrows it, so a few
        // rounds land where one division would fall short.
        for _ in 0..<4 {
            let shown = grade.apply(clean)
            guard let low = ColorAnalysis.lumaPercentile(shown, 0.02), let high = ColorAnalysis.lumaPercentile(shown, 0.98),
                  high - low > 1e-3 else { break }
            let next = held(grade.contrast * autoSpread / (high - low), autoContrastRange)
            if abs(next - grade.contrast) < 1e-3 { break }
            grade.contrast = next
        }
        return grade
    }

    /// Match Color: the grade under which `source` (a few frames of this part, ungraded) takes the
    /// colour statistics of `target` (a few frames of the other part as it shows) — Reinhard's
    /// transfer in L*a*b*, carried out with the grade's own controls: exposure moves the mean
    /// lightness, contrast its spread, temperature and tint the mean colour, saturation the colour's
    /// spread. The two chroma spreads are matched together, the one thing a single saturation
    /// control can do. Lift, gamma and gain stay standard. Without usable pixels on either side the
    /// standard grade comes back.
    public static func matched(_ source: [ColorSample], to target: [ColorSample]) -> ColorGrade {
        let from = ColorAnalysis.thinned(ColorAnalysis.usable(source), limit: 4_096)
        guard !from.isEmpty, let goal = ColorAnalysis.labStatistics(ColorAnalysis.thinned(ColorAnalysis.usable(target))) else {
            return .neutral
        }
        let wanted = [goal.meanL, goal.deviationL, goal.chromaDeviation, goal.meanB, goal.meanA]
        func measured(_ values: [Double]) -> [Double]? {
            guard let stats = ColorAnalysis.labStatistics(grade(values).apply(from)) else { return nil }
            return [stats.meanL, stats.deviationL, stats.chromaDeviation, stats.meanB, stats.meanA]
        }
        // exposure, contrast, saturation, temperature, tint — each driving one statistic, Newton on all five.
        let ranges = [exposureRange, contrastRange, saturationRange, temperatureRange, tintRange]
        let steps = [0.02, 0.02, 0.02, 0.02, 0.02]
        var values = [0.0, 1, 1, 0, 0]
        for _ in 0..<16 {
            guard let now = measured(values) else { break }
            let residual = (0..<5).map { wanted[$0] - now[$0] }
            if residual.allSatisfy({ abs($0) < 0.05 }) { break }
            var jacobian = [[Double]](repeating: [Double](repeating: 0, count: 5), count: 5)
            for column in 0..<5 {
                var nudged = values
                let step = values[column] + steps[column] > ranges[column].upperBound ? -steps[column] : steps[column]
                nudged[column] += step
                guard let moved = measured(nudged) else { return grade(values) }
                for row in 0..<5 { jacobian[row][column] = (moved[row] - now[row]) / step }
            }
            guard let change = solve(jacobian, residual) else { break }
            for index in 0..<5 {
                // At most a quarter of a range per round, so a flat spot cannot throw it far.
                let span = ranges[index].upperBound - ranges[index].lowerBound
                let limited = Swift.min(Swift.max(change[index], -span / 4), span / 4)
                values[index] = held(values[index] + (limited.isFinite ? limited : 0), ranges[index])
            }
        }
        return grade(values)
    }

    private static func grade(_ values: [Double]) -> ColorGrade {
        ColorGrade(exposure: values[0], contrast: values[1], saturation: values[2], temperature: values[3], tint: values[4])
    }

    private static func held(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return Swift.min(Swift.max(0, range.lowerBound), range.upperBound) }
        return Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    /// `matrix · x = vector` by Gaussian elimination with partial pivoting; nil when singular.
    static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        let size = vector.count
        guard matrix.count == size, matrix.allSatisfy({ $0.count == size }) else { return nil }
        var rows = matrix
        var right = vector
        for column in 0..<size {
            var pivot = column
            for row in column..<size where abs(rows[row][column]) > abs(rows[pivot][column]) { pivot = row }
            guard abs(rows[pivot][column]) > 1e-9 else { return nil }
            rows.swapAt(column, pivot)
            right.swapAt(column, pivot)
            for row in (column + 1)..<size {
                let factor = rows[row][column] / rows[column][column]
                for inner in column..<size { rows[row][inner] -= factor * rows[column][inner] }
                right[row] -= factor * right[column]
            }
        }
        var result = [Double](repeating: 0, count: size)
        for row in stride(from: size - 1, through: 0, by: -1) {
            var sum = right[row]
            for inner in (row + 1)..<size { sum -= rows[row][inner] * result[inner] }
            result[row] = sum / rows[row][row]
        }
        return result.allSatisfy(\.isFinite) ? result : nil
    }
}
