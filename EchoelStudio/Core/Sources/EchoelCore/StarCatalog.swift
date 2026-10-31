import Foundation

/// The stars a dark site shows the naked eye (sky source, founder 2026-10-31: "a good picture even
/// when it is dark"). The picture of the sky is computed from this table, the place and the time —
/// never taken from the camera — so it is sharp in total darkness and behind clouds.
///
/// Every star of the Yale Bright Star Catalogue, 5th revised edition (Hoffleit & Warren 1991, NASA
/// NSSDC/ADC, CDS catalogue V/50) down to visual magnitude 5.5 — about 2 900 stars — with the IAU
/// proper name of the brightest and best-known. Positions are J2000; `SkyBodies.precessed` brings
/// them to the equator of a date. Source, licence and how the table is built:
/// `docs/dev/SKY_DATA_SOURCES.md`. No constellation lines: the usual sets come from GPL software.
public enum StarCatalog {
    public struct Star: Equatable, Sendable, Identifiable {
        /// The Harvard Revised (Bright Star) number, the catalogue's own id.
        public let id: Int
        /// Right ascension and declination in degrees, equator and equinox J2000.
        public let rightAscension: Double
        public let declination: Double
        /// Visual magnitude: smaller is brighter (Sirius −1.46).
        public let magnitude: Double
        /// B−V colour index, nil where the catalogue gives none: about −0.3 for the hottest blue
        /// stars, 0 for white (Vega), 0.65 for the Sun, 1.5 and more for the coolest red ones.
        public let colorIndex: Double?
        /// The IAU proper name, for the named stars only.
        public let name: String?
    }

    /// The faintest magnitude the table holds.
    public static let faintestMagnitude = 5.5

    /// The whole table, parsed once on first use.
    public static let stars: [Star] = parse(StarCatalogData.table)

    /// One star per line: HR, right ascension, declination, magnitude, B−V or "-", optional name.
    /// A line that does not read as a star is skipped, never guessed.
    static func parse(_ table: String) -> [Star] {
        var out: [Star] = []
        out.reserveCapacity(2_900)
        for line in table.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 5)
            guard fields.count >= 5,
                  let hr = Int(fields[0]),
                  let ra = Double(fields[1]), ra.isFinite, (0..<360).contains(ra),
                  let dec = Double(fields[2]), dec.isFinite, abs(dec) <= 90,
                  let magnitude = Double(fields[3]), magnitude.isFinite else { continue }
            let color = Double(fields[4]).flatMap { $0.isFinite ? $0 : nil }
            let name = fields.count == 6 ? String(fields[5]) : nil
            out.append(Star(id: hr, rightAscension: ra, declination: dec, magnitude: magnitude,
                            colorIndex: color, name: name))
        }
        return out
    }

    // MARK: - Brightness and colour as plain numbers

    /// The brightest magnitude the 0 … 1 brightness scale distinguishes; anything brighter (the
    /// Moon, Venus, Jupiter) reads as 1.
    public static let brightestScaledMagnitude = -1.5

    /// Brightness 0 … 1 from a magnitude: 1 at −1.5 (Sirius) and brighter, 0 at the table's limit.
    /// Linear in magnitude, which is already logarithmic in light. Nil for a non-finite input.
    public static func brightness(magnitude: Double) -> Double? {
        guard magnitude.isFinite else { return nil }
        let span = faintestMagnitude - brightestScaledMagnitude
        return Swift.min(1, Swift.max(0, (faintestMagnitude - magnitude) / span))
    }

    /// The B−V range the 0 … 1 colour scale spans.
    public static let colorIndexRange = -0.4...2.0

    /// Colour 0 … 1 from B−V: 0 the hottest blue, 1 the coolest red. Nil for a non-finite input.
    public static func colorPosition(colorIndex: Double) -> Double? {
        guard colorIndex.isFinite else { return nil }
        let low = colorIndexRange.lowerBound, high = colorIndexRange.upperBound
        return Swift.min(1, Swift.max(0, (colorIndex - low) / (high - low)))
    }

    /// The surface temperature in kelvin a B−V index stands for (Ballesteros 2012, a black-body
    /// fit): about 10 000 K for B−V 0, 5 800 K for the Sun's 0.65. Nil for a non-finite input or
    /// one outside −0.4 … 2.0, where the fit means nothing.
    public static func temperature(colorIndex: Double) -> Double? {
        guard colorIndex.isFinite, colorIndexRange.contains(colorIndex) else { return nil }
        let first = 1 / (0.92 * colorIndex + 1.7)
        let second = 1 / (0.92 * colorIndex + 0.62)
        return 4_600 * (first + second)
    }

    public struct Color: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
    }

    /// The colour a star of `colorIndex` shows, each channel 0 … 1, from its temperature by a
    /// black-body approximation; white for a star without an index. For drawing only.
    public static func color(colorIndex: Double?) -> Color {
        guard let colorIndex, let kelvin = temperature(colorIndex: colorIndex) else {
            return Color(red: 1, green: 1, blue: 1)
        }
        let t = kelvin / 100
        let red: Double
        let green: Double
        let blue: Double
        if t <= 66 {
            red = 255
            green = 99.470_802_586_1 * Foundation.log(t) - 161.119_568_166_1
            blue = t <= 19 ? 0 : 138.517_731_223_1 * Foundation.log(t - 10) - 305.044_792_730_7
        } else {
            red = 329.698_727_446 * Foundation.pow(t - 60, -0.133_204_759_2)
            green = 288.122_169_528_3 * Foundation.pow(t - 60, -0.075_514_849_2)
            blue = 255
        }
        return Color(red: unit(red), green: unit(green), blue: unit(blue))
    }

    private static func unit(_ channel: Double) -> Double {
        guard channel.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, channel / 255))
    }
}
