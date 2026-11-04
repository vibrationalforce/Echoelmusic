import Foundation

/// A video part's colour correction (COLOR, added inside format 4, 2026-11-05): exposure, contrast,
/// saturation, white balance (temperature and tint) and lift, gamma and gain on the picture's luma.
/// It never changes a file: the part shows its file through this mapping, in the video window and in
/// a video export alike, and one standard grade shows the file exactly as it is.
///
/// Stored as a video region's optional `grade`. Every key inside it is optional too — a missing one
/// reads as its standard value — so a later build can add a control without a format number.
///
/// The mapping works on the picture as encoded (sRGB, 0 … 1 per channel), in this order:
/// 1. white balance and exposure as gains in linear light: red `2^(e + t + n/2)`, green `2^(e − n)`,
///    blue `2^(e − t + n/2)` for exposure `e` (EV), temperature `t` and tint `n`;
/// 2. contrast per channel around `contrastPivot`;
/// 3. saturation, each channel's distance from the Rec. 709 luma scaled;
/// 4. lift, gamma and gain on the luma, `gain · (Y + lift·(1 − Y))^(1/gamma)`, the change added to
///    every channel so the hue stays.
/// Each stage at its standard value is skipped, and every result is held to 0 … 1.
public struct ColorGrade: Codable, Equatable, Hashable, Sendable {
    /// Stops of light, −3 … 3; 0 standard.
    public var exposure: Double
    /// Contrast factor around the pivot, 0 … 2; 1 standard.
    public var contrast: Double
    /// Colourfulness factor, 0 (grey) … 2; 1 standard.
    public var saturation: Double
    /// Blue (−1) … amber (+1); 0 standard. One unit is a stop more red and a stop less blue.
    public var temperature: Double
    /// Green (−1) … magenta (+1); 0 standard.
    public var tint: Double
    /// Raises (positive) or lowers the blacks, −0.5 … 0.5; 0 standard.
    public var lift: Double
    /// Midtones, 0.25 … 4 (above 1 brighter); 1 standard.
    public var gamma: Double
    /// Scales the luma, 0 … 2; 1 standard.
    public var gain: Double

    public init(exposure: Double = 0, contrast: Double = 1, saturation: Double = 1, temperature: Double = 0,
                tint: Double = 0, lift: Double = 0, gamma: Double = 1, gain: Double = 1) {
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
        self.lift = lift
        self.gamma = gamma
        self.gain = gain
    }

    /// The grade that shows the file as it is.
    public static let neutral = ColorGrade()

    public static let exposureRange: ClosedRange<Double> = -3...3
    public static let contrastRange: ClosedRange<Double> = 0...2
    public static let saturationRange: ClosedRange<Double> = 0...2
    public static let temperatureRange: ClosedRange<Double> = -1...1
    public static let tintRange: ClosedRange<Double> = -1...1
    public static let liftRange: ClosedRange<Double> = -0.5...0.5
    public static let gammaRange: ClosedRange<Double> = 0.25...4
    public static let gainRange: ClosedRange<Double> = 0...2

    /// The encoded level contrast turns around: about 18 % grey in sRGB.
    public static let contrastPivot = 0.46

    public var isNeutral: Bool { self == .neutral }

    /// Every value finite and within its range — what the editor and an opened song accept.
    public var isValid: Bool {
        Self.fits(exposure, Self.exposureRange) && Self.fits(contrast, Self.contrastRange)
            && Self.fits(saturation, Self.saturationRange) && Self.fits(temperature, Self.temperatureRange)
            && Self.fits(tint, Self.tintRange) && Self.fits(lift, Self.liftRange)
            && Self.fits(gamma, Self.gammaRange) && Self.fits(gain, Self.gainRange)
    }

    /// Each value held to its range; a value that is not a number reads as its standard value.
    public var held: ColorGrade {
        ColorGrade(exposure: Self.hold(exposure, Self.exposureRange, 0), contrast: Self.hold(contrast, Self.contrastRange, 1),
                   saturation: Self.hold(saturation, Self.saturationRange, 1),
                   temperature: Self.hold(temperature, Self.temperatureRange, 0), tint: Self.hold(tint, Self.tintRange, 0),
                   lift: Self.hold(lift, Self.liftRange, 0), gamma: Self.hold(gamma, Self.gammaRange, 1),
                   gain: Self.hold(gain, Self.gainRange, 1))
    }

    private static func fits(_ value: Double, _ range: ClosedRange<Double>) -> Bool { value.isFinite && range.contains(value) }

    private static func hold(_ value: Double, _ range: ClosedRange<Double>, _ standard: Double) -> Double {
        guard value.isFinite else { return standard }
        return Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, saturation, temperature, tint, lift, gamma, gain
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(exposure: try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0,
                  contrast: try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1,
                  saturation: try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 1,
                  temperature: try values.decodeIfPresent(Double.self, forKey: .temperature) ?? 0,
                  tint: try values.decodeIfPresent(Double.self, forKey: .tint) ?? 0,
                  lift: try values.decodeIfPresent(Double.self, forKey: .lift) ?? 0,
                  gamma: try values.decodeIfPresent(Double.self, forKey: .gamma) ?? 1,
                  gain: try values.decodeIfPresent(Double.self, forKey: .gain) ?? 1)
    }
}

/// One pixel as encoded (sRGB), each channel 0 … 1.
public struct ColorSample: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Every channel a number.
    public var isFinite: Bool { red.isFinite && green.isFinite && blue.isFinite }

    /// Rec. 709 luma of the encoded values.
    public var luma: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
}

extension ColorGrade {
    /// The grade ready to apply to many pixels: its values held and its gains worked out once.
    public struct Mapping: Sendable {
        public let grade: ColorGrade
        private let gains: (red: Double, green: Double, blue: Double)?
        private let lumaCurve: Bool

        public init(_ grade: ColorGrade) {
            let held = grade.held
            self.grade = held
            if held.exposure != 0 || held.temperature != 0 || held.tint != 0 {
                gains = (Foundation.pow(2, held.exposure + held.temperature + held.tint / 2),
                         Foundation.pow(2, held.exposure - held.tint),
                         Foundation.pow(2, held.exposure - held.temperature + held.tint / 2))
            } else {
                gains = nil
            }
            lumaCurve = held.lift != 0 || held.gamma != 1 || held.gain != 1
        }

        /// `sample` through the grade; a channel that is not a number reads as 0.
        public func callAsFunction(_ sample: ColorSample) -> ColorSample {
            var red = Self.unit(sample.red), green = Self.unit(sample.green), blue = Self.unit(sample.blue)
            if let gains {
                red = ColorTransfer.encode(Swift.min(ColorTransfer.decode(red) * gains.red, 1))
                green = ColorTransfer.encode(Swift.min(ColorTransfer.decode(green) * gains.green, 1))
                blue = ColorTransfer.encode(Swift.min(ColorTransfer.decode(blue) * gains.blue, 1))
            }
            if grade.contrast != 1 {
                let pivot = ColorGrade.contrastPivot, factor = grade.contrast
                red = Self.unit(pivot + (red - pivot) * factor)
                green = Self.unit(pivot + (green - pivot) * factor)
                blue = Self.unit(pivot + (blue - pivot) * factor)
            }
            if grade.saturation != 1 {
                let luma = ColorSample(red: red, green: green, blue: blue).luma, factor = grade.saturation
                red = Self.unit(luma + (red - luma) * factor)
                green = Self.unit(luma + (green - luma) * factor)
                blue = Self.unit(luma + (blue - luma) * factor)
            }
            if lumaCurve {
                let luma = ColorSample(red: red, green: green, blue: blue).luma
                let change = Self.lumaCurve(luma, lift: grade.lift, gamma: grade.gamma, gain: grade.gain) - luma
                red = Self.unit(red + change)
                green = Self.unit(green + change)
                blue = Self.unit(blue + change)
            }
            return ColorSample(red: red, green: green, blue: blue)
        }

        /// Below this the gamma curve runs straight to 0, so its slope stays finite at black.
        static let gammaToe = 1.0 / 128

        static func lumaCurve(_ luma: Double, lift: Double, gamma: Double, gain: Double) -> Double {
            let base = Swift.max(luma + lift * (1 - luma), 0)
            let power = 1 / gamma
            let shaped = base >= gammaToe ? Foundation.pow(base, power) : base * Foundation.pow(gammaToe, power - 1)
            return gain * shaped
        }

        static func unit(_ value: Double) -> Double {
            guard value.isFinite else { return 0 }
            return Swift.min(Swift.max(value, 0), 1)
        }
    }

    /// `sample` through this grade.
    public func apply(_ sample: ColorSample) -> ColorSample { Mapping(self)(sample) }

    /// `samples` through this grade.
    public func apply(_ samples: [ColorSample]) -> [ColorSample] {
        let mapping = Mapping(self)
        return samples.map { mapping($0) }
    }

    /// The edge of the colour cube the picture is drawn through. The video window and the export
    /// both draw through this one cube, so they show one picture.
    public static let cubeSize = 64

    /// The grade as a colour cube: `size`³ entries of red, green, blue, alpha (alpha 1), red changing
    /// fastest, then green, then blue — the layout Core Image's colour cube reads.
    public func cube(size: Int = ColorGrade.cubeSize) -> [Float] {
        let edge = Swift.max(2, size)
        let mapping = Mapping(self)
        let step = 1 / Double(edge - 1)
        var data = [Float](repeating: 1, count: edge * edge * edge * 4)
        var index = 0
        for blue in 0..<edge {
            for green in 0..<edge {
                for red in 0..<edge {
                    let out = mapping(ColorSample(red: Double(red) * step, green: Double(green) * step, blue: Double(blue) * step))
                    data[index] = Float(out.red)
                    data[index + 1] = Float(out.green)
                    data[index + 2] = Float(out.blue)
                    index += 4
                }
            }
        }
        return data
    }

    /// What a colour cube made by `cube(size:)` shows for `sample`: trilinear between its entries,
    /// as Core Image reads it.
    public static func lookUp(_ sample: ColorSample, in cube: [Float], size: Int) -> ColorSample {
        let edge = Swift.max(2, size)
        guard cube.count == edge * edge * edge * 4 else { return sample }
        func position(_ value: Double) -> (Int, Double) {
            let scaled = Mapping.unit(value) * Double(edge - 1)
            let low = Swift.min(Int(scaled.rounded(.down)), edge - 2)
            return (low, scaled - Double(low))
        }
        let (r0, fr) = position(sample.red), (g0, fg) = position(sample.green), (b0, fb) = position(sample.blue)
        var out = [0.0, 0.0, 0.0]
        for corner in 0..<8 {
            let dr = corner & 1, dg = (corner >> 1) & 1, db = (corner >> 2) & 1
            let weight = (dr == 1 ? fr : 1 - fr) * (dg == 1 ? fg : 1 - fg) * (db == 1 ? fb : 1 - fb)
            guard weight > 0 else { continue }
            let entry = (((b0 + db) * edge + (g0 + dg)) * edge + (r0 + dr)) * 4
            for channel in 0..<3 { out[channel] += weight * Double(cube[entry + channel]) }
        }
        return ColorSample(red: out[0], green: out[1], blue: out[2])
    }
}

/// The sRGB transfer curve.
public enum ColorTransfer {
    /// Encoded 0 … 1 to linear light.
    public static func decode(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : Foundation.pow((value + 0.055) / 1.055, 2.4)
    }

    /// Linear light 0 … 1 to encoded.
    public static func encode(_ value: Double) -> Double {
        value <= 0.003_130_8 ? value * 12.92 : 1.055 * Foundation.pow(value, 1 / 2.4) - 0.055
    }
}
