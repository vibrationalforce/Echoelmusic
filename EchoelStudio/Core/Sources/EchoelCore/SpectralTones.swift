import Foundation

/// One line of a spectrum — of the hydrogen atom, or a vibration of an everyday molecule — as a
/// tone (Cycle Tones, Molecules; founder 2026-11-15). The line's frequency is the speed of light
/// times its wavenumber; halved by whole octaves into octave 3 it is a tone with a tempo and a
/// concert pitch, by the same arithmetic as the cycles (`CycleTone`). Only physics and everyday
/// molecules (founder 2026-11-15).
public struct SpectralLine: Equatable, Sendable, Identifiable {
    public enum Kind: String, CaseIterable, Sendable {
        case hydrogen, molecule

        /// The section title on the Molecules page.
        public var title: String {
            switch self {
            case .hydrogen: "Hydrogen Atom"
            case .molecule: "Everyday Molecules"
            }
        }
    }

    /// Stable name, `substance.line` (never stored in a song).
    public let id: String
    /// The atom or molecule, with its formula: "Water H₂O".
    public let substance: String
    /// Which line: "Bend (ν₂)", "Balmer α (3 → 2)".
    public let line: String
    /// The same two in plain words, as VoiceOver reads them: "Water, H 2 O" and "Bend, mode 2".
    public let spokenSubstance: String
    public let spokenLine: String
    public let kind: Kind
    /// Wavenumber in cm⁻¹.
    public let wavenumber: Double
    public let source: String

    /// The line's frequency in hertz: c · ν̃.
    public var hertz: Double { SpectralLibrary.speedOfLight * 100 * wavenumber }

    /// The line as a tone; nil only for a wavenumber that is not a positive number.
    public var tone: CycleTone? {
        guard wavenumber.isFinite, wavenumber > 0 else { return nil }
        return CycleTone(periodSeconds: 1 / hertz)
    }
}

/// The lines Cycle Tones offers under Molecules: the hydrogen atom's first lines, computed from the
/// Rydberg formula, and the fundamental vibrations of everyday molecules, measured in the gas
/// phase. The words the page shows live here, so a test reads them (Law 8).
public enum SpectralLibrary {
    /// The speed of light in m/s (exact by the SI definition of the metre).
    public static let speedOfLight = 299_792_458.0
    /// The Rydberg constant for hydrogen in cm⁻¹: R∞ / (1 + mₑ/mₚ) with R∞ = 10 973 731.568 157 m⁻¹
    /// and mₑ/mₚ = 5.446 170 214 889 × 10⁻⁴ (CODATA 2022).
    public static let hydrogenRydberg = 109_677.583_402_773

    static let codata = "Rydberg formula, CODATA 2022 constants"
    static let shimanouchi = "T. Shimanouchi, Tables of Molecular Vibrational Frequencies (NSRDS-NBS 39, 1972), gas phase"
    static let rothman = "Gas-phase Raman, AFGL/HITRAN (Rothman and Young 1981)"
    static let coxon = "Gas-phase band origin, Coxon and Hajigeorgiou (2004)"
    static let diatomics = "Gas-phase fundamental, NIST CCCBDB diatomic constants (Irikura 2007)"

    /// How every number on the page is made, and what its words mean.
    public static let method = "A line of a spectrum is one exact frequency: for the hydrogen atom, a colour of light it gives "
        + "off when it falls from one energy level to a lower one (Balmer α, 3 → 2, is its red line at 656 nm); for a "
        + "molecule, a way its atoms vibrate, numbered ν₁, ν₂ … (the centre of that vibration's band). The wavenumber, in "
        + "waves per centimetre (cm⁻¹), times the speed of light is the frequency. Each tone is that frequency halved by "
        + "whole octaves until its nearest key lies in octave 3, C3 to B3. Its tempo is the same tone seven octaves lower, "
        + "in beats per minute. Its concert pitch is the A at which, in twelve equal steps, the tone is exactly its key. "
        + "The tuning fork beside a line sets the song's key, concert pitch or tempo to it, and Undo takes it back. These "
        + "are calculations from measured vibrations and, for hydrogen, from the Rydberg formula; they claim nothing about "
        + "what a tone does to a listener."

    /// Whose method and whose numbers, as they were checked.
    public static let credit = "Method after Hans Cousto, Die Kosmische Oktave (1984). Hydrogen from the Rydberg formula "
        + "with CODATA 2022 constants. The vibrations of water, carbon dioxide, methane, ozone and ammonia as compiled by "
        + "T. Shimanouchi (NSRDS-NBS 39, 1972); oxygen and nitrogen from diatomic constants (Irikura 2007); carbon "
        + "dioxide's pair of lines from Rothman and Young (1981) and carbon monoxide from Coxon and Hajigeorgiou (2004)."

    /// The wavenumber of hydrogen's line from level `upper` down to level `lower`, in cm⁻¹; nil when
    /// the levels do not make a line (`lower` from 1, `upper` above it).
    public static func hydrogenWavenumber(lower: Int, upper: Int) -> Double? {
        guard lower >= 1, upper > lower else { return nil }
        let l = Double(lower), u = Double(upper)
        return hydrogenRydberg * (1 / (l * l) - 1 / (u * u))
    }

    private static func hydrogen(_ id: String, _ name: String, spoken: String, lower: Int, upper: Int) -> SpectralLine {
        SpectralLine(id: "hydrogen." + id, substance: "Hydrogen H", line: name + " (\(upper) → \(lower))",
                     spokenSubstance: "Hydrogen", spokenLine: spoken + ", level \(upper) to \(lower)",
                     kind: .hydrogen, wavenumber: hydrogenWavenumber(lower: lower, upper: upper) ?? 0, source: codata)
    }

    private static func molecule(_ id: String, _ substance: String, _ line: String, _ wavenumber: Double,
                                 spoken: (substance: String, line: String), source: String = shimanouchi) -> SpectralLine {
        SpectralLine(id: id, substance: substance, line: line, spokenSubstance: spoken.substance, spokenLine: spoken.line,
                     kind: .molecule, wavenumber: wavenumber, source: source)
    }

    public static let all: [SpectralLine] = hydrogenLines + molecules

    static let hydrogenLines: [SpectralLine] = [
        hydrogen("lymanAlpha", "Lyman α", spoken: "Lyman alpha", lower: 1, upper: 2),
        hydrogen("balmerAlpha", "Balmer α", spoken: "Balmer alpha", lower: 2, upper: 3),
        hydrogen("balmerBeta", "Balmer β", spoken: "Balmer beta", lower: 2, upper: 4),
        hydrogen("balmerGamma", "Balmer γ", spoken: "Balmer gamma", lower: 2, upper: 5),
        hydrogen("balmerDelta", "Balmer δ", spoken: "Balmer delta", lower: 2, upper: 6),
        hydrogen("paschenAlpha", "Paschen α", spoken: "Paschen alpha", lower: 3, upper: 4),
    ]

    // Methane ν₄: Shimanouchi's 1306 is the band's peak; its origin lies at about 1310.76, which
    // would put the tone on D3 instead of C♯3. The polyatomic rows keep one source, his table.
    static let molecules: [SpectralLine] = [
        molecule("water.symmetricStretch", "Water H₂O", "Symmetric stretch (ν₁)", 3657, spoken: ("Water, H 2 O", "Symmetric stretch, mode 1")),
        molecule("water.bend", "Water H₂O", "Bend (ν₂)", 1595, spoken: ("Water, H 2 O", "Bend, mode 2")),
        molecule("water.antisymmetricStretch", "Water H₂O", "Antisymmetric stretch (ν₃)", 3756,
                 spoken: ("Water, H 2 O", "Antisymmetric stretch, mode 3")),
        molecule("carbonDioxide.pairLow", "Carbon dioxide CO₂", "Stretch and bend mixed, lower (ν₁ / 2ν₂)", 1285.41,
                 spoken: ("Carbon dioxide, C O 2", "Stretch and bend mixed, the lower of the pair"), source: rothman),
        molecule("carbonDioxide.pairHigh", "Carbon dioxide CO₂", "Stretch and bend mixed, upper (ν₁ / 2ν₂)", 1388.18,
                 spoken: ("Carbon dioxide, C O 2", "Stretch and bend mixed, the upper of the pair"), source: rothman),
        molecule("carbonDioxide.bend", "Carbon dioxide CO₂", "Bend (ν₂)", 667, spoken: ("Carbon dioxide, C O 2", "Bend, mode 2")),
        molecule("carbonDioxide.antisymmetricStretch", "Carbon dioxide CO₂", "Antisymmetric stretch (ν₃)", 2349,
                 spoken: ("Carbon dioxide, C O 2", "Antisymmetric stretch, mode 3")),
        molecule("oxygen.stretch", "Oxygen O₂", "Stretch", 1556.4, spoken: ("Oxygen, O 2", "Stretch"), source: diatomics),
        molecule("nitrogen.stretch", "Nitrogen N₂", "Stretch", 2329.9, spoken: ("Nitrogen, N 2", "Stretch"), source: diatomics),
        molecule("carbonMonoxide.stretch", "Carbon monoxide CO", "Stretch", 2143.27,
                 spoken: ("Carbon monoxide, C O", "Stretch"), source: coxon),
        molecule("methane.symmetricStretch", "Methane CH₄", "Symmetric stretch (ν₁)", 2917, spoken: ("Methane, C H 4", "Symmetric stretch, mode 1")),
        molecule("methane.bend", "Methane CH₄", "Bend (ν₂)", 1534, spoken: ("Methane, C H 4", "Bend, mode 2")),
        molecule("methane.antisymmetricStretch", "Methane CH₄", "Antisymmetric stretch (ν₃)", 3019,
                 spoken: ("Methane, C H 4", "Antisymmetric stretch, mode 3")),
        molecule("methane.deformation", "Methane CH₄", "Deformation (ν₄)", 1306, spoken: ("Methane, C H 4", "Deformation, mode 4")),
        molecule("ozone.symmetricStretch", "Ozone O₃", "Symmetric stretch (ν₁)", 1103, spoken: ("Ozone, O 3", "Symmetric stretch, mode 1")),
        molecule("ozone.bend", "Ozone O₃", "Bend (ν₂)", 701, spoken: ("Ozone, O 3", "Bend, mode 2")),
        molecule("ozone.antisymmetricStretch", "Ozone O₃", "Antisymmetric stretch (ν₃)", 1042,
                 spoken: ("Ozone, O 3", "Antisymmetric stretch, mode 3")),
        molecule("ammonia.symmetricStretch", "Ammonia NH₃", "Symmetric stretch (ν₁)", 3337, spoken: ("Ammonia, N H 3", "Symmetric stretch, mode 1")),
        molecule("ammonia.umbrella", "Ammonia NH₃", "Umbrella (ν₂, mean of its pair)", 950,
                 spoken: ("Ammonia, N H 3", "Umbrella, mode 2, the mean of its pair")),
        molecule("ammonia.antisymmetricStretch", "Ammonia NH₃", "Antisymmetric stretch (ν₃)", 3444,
                 spoken: ("Ammonia, N H 3", "Antisymmetric stretch, mode 3")),
        molecule("ammonia.deformation", "Ammonia NH₃", "Deformation (ν₄)", 1627, spoken: ("Ammonia, N H 3", "Deformation, mode 4")),
    ]
}
