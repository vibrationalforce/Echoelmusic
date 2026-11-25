import Foundation

/// The tempo a loop's file name states, and how it meets the tempo heard in the file. Producers name
/// loops by their tempo ("jungle 132", "break_174bpm"); the detector cannot hear a loop shorter
/// than `TempoDetector.minimumSeconds` and folds every reading into one octave, so the name decides
/// where it is clear and the ear decides where it is not.
public enum TempoHint {
    /// Tempos a bare number in a name is read as: below and above it, a number is more likely a
    /// take, a year or a model ("808") than a tempo. A number marked "bpm" may be anywhere in
    /// `AudioRegion.nativeBPMRange`.
    public static let bareRange: ClosedRange<Double> = 60...200
    /// How far a stated and a heard tempo may differ and still be the same pulse.
    public static let agreement: Double = 0.04

    /// The tempo `name` states, or nil. A number next to "bpm" wins; else the one standalone
    /// number in `bareRange` — two such numbers are ambiguous and state nothing.
    public static func bpm(inName name: String) -> Double? {
        let characters = Array(name.lowercased())
        var marked: [Double] = []
        var bare: [Double] = []
        var index = 0
        while index < characters.count {
            guard characters[index].isASCII, characters[index].isNumber else { index += 1; continue }
            let first = index
            while index < characters.count, characters[index].isASCII, characters[index].isNumber { index += 1 }
            var last = index
            // One decimal part: "87.5".
            if index + 1 < characters.count, characters[index] == ".", characters[index + 1].isASCII, characters[index + 1].isNumber {
                index += 1
                while index < characters.count, characters[index].isASCII, characters[index].isNumber { index += 1 }
                last = index
            }
            guard let value = Double(String(characters[first..<last])), value.isFinite else { continue }
            let before = first > 0 ? characters[first - 1] : " "
            let after = last < characters.count ? characters[last] : " "
            if isMarked(characters, before: first, after: last) {
                if AudioRegion.nativeBPMRange.contains(value) { marked.append(value) }
            } else if !before.isLetter, !after.isLetter, before != ".", bareRange.contains(value) {
                bare.append(value)
            }
        }
        if let first = marked.first { return first }
        return bare.count == 1 ? bare[0] : nil
    }

    /// The native tempo to use: the stated one when nothing was heard, or when it is the heard pulse
    /// at the same, double or half speed (the detector's octave is a convention); otherwise what was
    /// heard. Nil when neither says anything.
    public static func resolve(name: String, heard: Double?) -> Double? {
        let stated = bpm(inName: name)
        guard let heard, heard.isFinite, heard > 0 else { return stated }
        guard let stated else { return heard }
        for factor in [1.0, 2.0, 0.5] where Swift.abs(heard * factor / stated - 1) <= agreement {
            return stated
        }
        return heard
    }

    /// Whether the digits at `before ..< after` sit next to "bpm", with at most one space, "_" or
    /// "-" between.
    private static func isMarked(_ characters: [Character], before: Int, after: Int) -> Bool {
        let word: [Character] = ["b", "p", "m"]
        var cursor = after
        if cursor < characters.count, " _-".contains(characters[cursor]) { cursor += 1 }
        if cursor + 3 <= characters.count, Array(characters[cursor..<cursor + 3]) == word { return true }
        var end = before
        if end > 0, " _-".contains(characters[end - 1]) { end -= 1 }
        return end >= 3 && Array(characters[end - 3..<end]) == word
    }
}
