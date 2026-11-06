import Foundation

/// A heard tone as light, by the physics of octave transposition: double a frequency enough
/// times and it reaches the band the eye sees (light runs about 384 … 789 THz, barely one
/// octave), and its wavelength is then c / f. Every octave of a tone lands on the same light, so
/// A4 and A5 wear one colour. Taking the tone up by 40-odd octaves is an artistic convention —
/// sound is a pressure wave and light an electromagnetic one; nothing here says a note IS a
/// colour — and the convention is stated once, here, so every surface uses the same one: the
/// Field's shader (`FieldShader.toneColour`), the lamp, the keys and the note editor.
///
/// The visible band is barely one octave, and where the eye's response fades (deep red, deep
/// violet) a plain transposition would show a dark colour. The circle is closed along the CIE
/// purple line instead: between 640 nm and 420 nm the colour is the pure spectral one; across
/// the seam it blends the two edge colours at an even presence, so no pitch is ever dark.
///
/// Colours are LINEAR sRGB, each channel 0 … 1, as Doubles — Core knows nothing of a screen.
/// Pure; Foundation only.
public enum ToneLight {
    /// Linear sRGB, each channel 0 … 1 (not gamma-encoded).
    public struct RGB: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = ToneLight.unit(red)
            self.green = ToneLight.unit(green)
            self.blue = ToneLight.unit(blue)
        }

        public init(grey: Double) { self.init(red: grey, green: grey, blue: grey) }

        /// The brightest channel.
        public var peak: Double { Swift.max(red, Swift.max(green, blue)) }

        /// Each channel times `factor` (a dimmer), held to 0 … 1.
        public func scaled(by factor: Double) -> RGB {
            let k = factor.isFinite ? factor : 0
            return RGB(red: red * k, green: green * k, blue: blue * k)
        }

        /// The colour from gamma-encoded sRGB components (what a screen colour is written in).
        public init(encodedRed: Double, green: Double, blue: Double) {
            self.init(red: ToneLight.decode(encodedRed), green: ToneLight.decode(green), blue: ToneLight.decode(blue))
        }

        /// The relative luminance (WCAG 2.x, Rec. 709 weights on linear channels), 0 … 1.
        public var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

        /// The same colour gamma-encoded for a screen (the sRGB transfer, IEC 61966-2-1).
        public var encoded: RGB {
            RGB(red: ToneLight.encode(red), green: ToneLight.encode(green), blue: ToneLight.encode(blue))
        }
    }

    // MARK: - The constants (the shader is written from these)

    /// The speed of light, nanometres a second.
    public static let speedOfLightNanometresPerSecond = 2.99792458e17
    /// The top of the one light octave every tone is folded into, nanometres: deep red.
    public static let anchorNanometres = 780.0
    /// Where the pure spectrum ends and the purple line begins, nanometres.
    public static let redEdgeNanometres = 640.0
    public static let violetEdgeNanometres = 420.0
    /// The two edges as places in the folded octave (`t`, 0 ..< 1, λ = 780 nm / 2^t).
    public static let redEdge = Foundation.log2(anchorNanometres / redEdgeNanometres)
    public static let violetEdge = Foundation.log2(anchorNanometres / violetEdgeNanometres)

    /// The same numbers as Metal float tokens. The shader is compiled from text at runtime, so a
    /// bad token would only show on the device; these are written from the constants above
    /// (fixed-point, POSIX — no locale can put a comma in them), and `ToneLightTests` reads each
    /// back as a number and compares it with its constant.
    public static let speedOfLightLiteral = "2.99792458e17"
    public static let anchorLiteral = String(format: "%.1f", anchorNanometres)
    public static let redEdgeNanometresLiteral = String(format: "%.1f", redEdgeNanometres)
    public static let violetEdgeNanometresLiteral = String(format: "%.1f", violetEdgeNanometres)
    public static let redEdgeLiteral = String(format: "%.9f", redEdge)
    public static let violetEdgeLiteral = String(format: "%.9f", violetEdge)

    /// What an invalid tone (NaN, infinite, zero, negative) shows: a mid grey, never black.
    public static let neutral = RGB(grey: 0.216)

    // MARK: - A tone's light

    /// How many octaves up `toneHz` lands in the light octave below 780 nm; nil for an invalid tone.
    public static func octaves(forToneHz toneHz: Double) -> Int? {
        guard let p = fold(toneHz) else { return nil }
        let up = p.rounded(.up)
        guard up.isFinite, Swift.abs(up) < 4_096 else { return nil }
        return Int(up)
    }

    /// The tone's frequency taken up by `octaves(forToneHz:)`, hertz (about 384 … 769 THz).
    public static func lightHertz(forToneHz toneHz: Double) -> Double? {
        guard let up = octaves(forToneHz: toneHz) else { return nil }
        return toneHz * Foundation.pow(2, Double(up))
    }

    /// The wavelength of that light, nanometres (390 … 780).
    public static func wavelength(forToneHz toneHz: Double) -> Double? {
        guard let light = lightHertz(forToneHz: toneHz), light > 0 else { return nil }
        return speedOfLightNanometresPerSecond / light
    }

    /// The tone's colour on the closed spectral circle: the colour the Field shows for it.
    public static func colour(forToneHz toneHz: Double) -> RGB {
        guard let p = fold(toneHz) else { return neutral }
        var t = p.rounded(.up) - p
        if t >= 1 { t -= 1 }
        if t >= redEdge && t <= violetEdge {
            return spectrum(nanometres: anchorNanometres / Foundation.pow(2, t))
        }
        // Across the seam: the purple line from the red edge to the violet edge.
        let seam = redEdge + 1 - violetEdge
        let s = t < redEdge ? (redEdge - t) / seam : (redEdge + 1 - t) / seam
        let red = spectrum(nanometres: redEdgeNanometres)
        let violet = spectrum(nanometres: violetEdgeNanometres)
        var r = red.red + (violet.red - red.red) * s
        var g = red.green + (violet.green - red.green) * s
        var b = red.blue + (violet.blue - red.blue) * s
        // A mix of two hues dips in its peak channel half way; lift it back to the interpolated
        // peak, so the seam is as present as its neighbours and meets them exactly at both edges.
        let m = Swift.max(r, Swift.max(g, b))
        let target = red.peak + (violet.peak - red.peak) * s
        if m > 1e-6 {
            let k = target / m
            r *= k; g *= k; b *= k
        }
        return RGB(red: r, green: g, blue: b)
    }

    /// A wavelength's colour, linear sRGB: the CIE 1931 colour-matching functions (the
    /// Wyman/Sloan/Shirley 2013 analytic fit) to XYZ, to sRGB (D65), desaturated towards neutral
    /// by the most negative channel rather than clipped per channel, so the deep red and violet
    /// bands keep their hue. The shader's `wavelengthToRGB` is the same function.
    public static func spectrum(nanometres: Double) -> RGB {
        guard nanometres.isFinite else { return neutral }
        func lobe(_ x: Double, _ mu: Double, _ s1: Double, _ s2: Double) -> Double {
            let t = (x - mu) / (x < mu ? s1 : s2)
            return Foundation.exp(-0.5 * t * t)
        }
        let wl = nanometres
        let x = Swift.max(0, 1.056 * lobe(wl, 599.8, 37.9, 31.0) + 0.362 * lobe(wl, 442.0, 16.0, 26.7)
            - 0.065 * lobe(wl, 501.1, 20.4, 26.2))
        let y = Swift.max(0, 0.821 * lobe(wl, 568.8, 46.9, 40.5) + 0.286 * lobe(wl, 530.9, 16.3, 31.1))
        let z = Swift.max(0, 1.217 * lobe(wl, 437.0, 11.8, 36.0) + 0.681 * lobe(wl, 459.0, 26.0, 13.8))
        var r = 3.2406 * x - 1.5372 * y - 0.4986 * z
        var g = -0.9689 * x + 1.8758 * y + 0.0415 * z
        var b = 0.0557 * x - 0.2040 * y + 1.0570 * z
        let w = Swift.min(0, Swift.min(r, Swift.min(g, b)))
        r -= w; g -= w; b -= w
        let m = Swift.max(r, Swift.max(g, b))
        if m > 1 { r /= m; g /= m; b /= m }
        return RGB(red: r, green: g, blue: b)
    }

    // MARK: - On a key, a lamp, a screen

    /// The equal-tempered pitch `pitch` (MIDI number) at `concertPitch` (A4), hertz; a concert
    /// pitch that is not a positive, finite number counts as 440.
    public static func hertz(ofPitch pitch: Int, concertPitch: Double) -> Double {
        let a4 = concertPitch.isFinite && concertPitch > 0 ? concertPitch : 440
        return a4 * Foundation.pow(2, (Double(pitch) - 69) / 12)
    }

    /// `colour` brought `saturation` of the way out of its own grey (0 grey … 1 as it is) and then
    /// to the relative luminance `luminance` — never above it: a colour whose brightest channel
    /// reaches 1 first stays darker, so a light label over it only gains contrast. The hue (the
    /// pitch) survives; only how strong and how bright it is change.
    public static func shade(_ colour: RGB, saturation: Double, luminance: Double) -> RGB {
        let keep = unit(saturation), target = unit(luminance)
        let grey = colour.luminance
        let r = grey + (colour.red - grey) * keep
        let g = grey + (colour.green - grey) * keep
        let b = grey + (colour.blue - grey) * keep
        let lit = 0.2126 * r + 0.7152 * g + 0.0722 * b
        guard lit > 1e-9 else { return RGB(grey: target) }
        let peak = Swift.max(r, Swift.max(g, b))
        let k = Swift.min(target / lit, peak > 1e-9 ? 1 / peak : 1)
        return RGB(red: r * k, green: g * k, blue: b * k)
    }

    /// A key's fill (the hex keyboard's cells): the key's light, muted and dark enough that the
    /// app's text colour on it clears WCAG AA (`Contrast.textMinimum`) for every pitch.
    public static let keyFillSaturation = 0.6
    public static let keyFillLuminance = 0.10
    public static func keyFill(forToneHz toneHz: Double) -> RGB {
        shade(colour(forToneHz: toneHz), saturation: keyFillSaturation, luminance: keyFillLuminance)
    }

    /// A note's fill in the piano roll: its pitch's light, muted, brightness following its
    /// velocity (`noteFillQuietest` at velocity 0 … `noteFillLoudest` at 127, relative luminance).
    /// A deep blue cannot reach a high luminance inside the gamut; it stays as bright as it can.
    public static let noteFillSaturation = 0.55
    public static let noteFillQuietest = 0.20
    public static let noteFillLoudest = 0.55
    public static func noteFill(forToneHz toneHz: Double, velocity: Int) -> RGB {
        let strength = Double(Swift.min(Swift.max(velocity, 0), 127)) / 127
        let target = noteFillQuietest + (noteFillLoudest - noteFillQuietest) * strength
        return shade(colour(forToneHz: toneHz), saturation: noteFillSaturation, luminance: target)
    }

    /// The label for text on `fill`: black or white, whichever contrasts more. One of the two
    /// always clears 4.58:1 (they tie where the fill's luminance is √0.0525 − 0.05 ≈ 0.18), so a
    /// name on any colour reads at WCAG AA.
    public static func label(on fill: RGB) -> RGB {
        let black = RGB(grey: 0), white = RGB(grey: 1)
        return Contrast.ratio(black, fill) >= Contrast.ratio(white, fill) ? black : white
    }

    // MARK: - Helpers

    /// log2(f_anchor / f): how many octaves below the light octave's bottom the tone sits.
    /// nil for a tone that is not a positive, finite frequency.
    private static func fold(_ toneHz: Double) -> Double? {
        guard toneHz.isFinite, toneHz > 0 else { return nil }
        let p = Foundation.log2(speedOfLightNanometresPerSecond / anchorNanometres / toneHz)
        return p.isFinite ? p : nil
    }

    static func encode(_ linear: Double) -> Double {
        let c = unit(linear)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * Foundation.pow(c, 1 / 2.4) - 0.055
    }

    static func decode(_ encoded: Double) -> Double {
        let c = unit(encoded)
        return c <= 0.04045 ? c / 12.92 : Foundation.pow((c + 0.055) / 1.055, 2.4)
    }

    static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, value))
    }
}
