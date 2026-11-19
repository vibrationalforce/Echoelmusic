import Foundation

/// The note value a time or a rate is at the song's tempo — the earlier app's studio calculator
/// (`Sources/Echoelmusic/DSP/StudioCalculator.swift`), ported as the one rule a value field needs
/// (Michael on 10083: „Weisst du noch der Studio calculator? So finesse vermisse ich.“). A delay
/// of 375 ms at 120 BPM is a dotted eighth; a 4 Hz rate is an eighth note. Only names what is
/// there: nothing is snapped or changed.
public enum TempoNote {
    public struct Division: Equatable, Sendable {
        /// Length in quarter notes.
        public let quarters: Double
        /// "1/8", "1/8 dotted", "1/8 triplet".
        public let name: String
    }

    /// 1/1 to 1/64, each straight, dotted and triplet — longest first.
    public static let divisions: [Division] = {
        var all: [Division] = []
        for denominator in [1, 2, 4, 8, 16, 32, 64] {
            let quarters = 4 / Double(denominator)
            all.append(Division(quarters: quarters, name: "1/\(denominator)"))
            all.append(Division(quarters: quarters * 1.5, name: "1/\(denominator) dotted"))
            all.append(Division(quarters: quarters * 2 / 3, name: "1/\(denominator) triplet"))
        }
        return all
    }()

    /// How close a value must be to a division to be named by it: one percent.
    public static let tolerance = 0.01

    /// Seconds of `division` at `bpm`; 0 for a tempo that is not a positive number.
    public static func seconds(of division: Division, bpm: Double) -> Double {
        guard bpm.isFinite, bpm > 0 else { return 0 }
        return division.quarters * 60 / bpm
    }

    /// The division `seconds` is at `bpm`, within `tolerance`; nil when it is none of them.
    public static func division(forSeconds seconds: Double, bpm: Double) -> Division? {
        guard seconds.isFinite, seconds > 0, bpm.isFinite, bpm > 0 else { return nil }
        let quarters = seconds * bpm / 60
        return divisions.first { Swift.abs(quarters - $0.quarters) <= $0.quarters * tolerance }
    }

    /// The division one cycle of `hertz` lasts at `bpm`, within `tolerance`; nil when none.
    public static func division(forHertz hertz: Double, bpm: Double) -> Division? {
        guard hertz.isFinite, hertz > 0 else { return nil }
        return division(forSeconds: 1 / hertz, bpm: bpm)
    }
}
