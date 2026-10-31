import Foundation

/// The one way a number reads on screen. It follows the reader's locale — "76,5 BPM" in German,
/// "76.5 BPM" in English — so the tempo, a level, a time and a rate never disagree about the
/// decimal separator on the same screen (device video 10021: the tempo read "76,5" beside
/// "-5.6 dB"). No grouping (a tempo of 1200 is "1200"), a space before the unit, and the font
/// that shows it (`Theme.Font.value`) has tabular figures, so a changing number never jitters.
///
/// Every number shown in a view goes through here — `ParameterFormat` does, and so must a new
/// readout in any module. Typed numbers use the same style on the number pad.
///
/// It lives in `Plugins/Shared` and is Foundation-only, so the AUv3 extension compiles the same
/// file (`project.yml`: the app lists it by path, like `EchoelBrand`): a value in the plugin
/// window reads exactly as the same value in the Studio.
enum NumberText {
    /// `value` with exactly `decimals` digits after the separator.
    static func string(_ value: Double, decimals: Int) -> String {
        guard value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(decimals)).grouping(.never))
    }

    /// `value` with as few digits after the separator as it needs, at most `decimalsUpTo`:
    /// a beat reads "3", "2,5" or "1,25".
    static func string(_ value: Double, decimalsUpTo: Int) -> String {
        guard value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...Swift.max(0, decimalsUpTo))).grouping(.never))
    }

    /// `value` and its unit, a space between: "120,0 BPM", "-6,0 dB", "250 ms".
    static func string(_ value: Double, decimals: Int, unit: String) -> String {
        string(value, decimals: decimals) + " " + unit
    }

    /// `value` with as few places as it needs, at most `decimalsUpTo`, and its unit: a tempo reads
    /// "120 BPM", "100,5 BPM" or "100,25 BPM" — never "120,00 BPM".
    static func string(_ value: Double, decimalsUpTo: Int, unit: String) -> String {
        string(value, decimalsUpTo: decimalsUpTo) + " " + unit
    }

    /// A percentage, US style without a space before the sign: "50%", "+25%" when `signed`.
    static func percent(_ value: Double, decimals: Int = 0, signed: Bool = false) -> String {
        guard value.isFinite else { return "–%" }
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(decimals)).grouping(.never)
        let number = signed ? value.formatted(style.sign(strategy: .always(includingZero: false)))
            : value.formatted(style)
        return number + "%"
    }

    /// With its sign always shown, for an offset or a gain that can go either way: "+3,0 dB".
    static func signed(_ value: Double, decimals: Int, unit: String) -> String {
        guard value.isFinite else { return "– " + unit }
        let number = value.formatted(.number.precision(.fractionLength(decimals)).grouping(.never)
            .sign(strategy: .always(includingZero: false)))
        return number + " " + unit
    }
}
