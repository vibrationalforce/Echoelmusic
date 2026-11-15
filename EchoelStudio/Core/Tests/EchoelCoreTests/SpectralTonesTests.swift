import Foundation
import XCTest
@testable import EchoelCore

/// Lines of the hydrogen atom's and of everyday molecules' spectra as tones: the line's frequency —
/// the speed of light times its wavenumber — halved by whole octaves into octave 3, by the same
/// arithmetic as the cycles (`CycleTone`).
final class SpectralTonesTests: XCTestCase {
    private func line(_ id: String) throws -> SpectralLine {
        try XCTUnwrap(SpectralLibrary.all.first { $0.id == id }, id)
    }

    func testHydrogenAlphaIsTheRedLineAt656NanometresAndLandsOnAFlat3() throws {
        let alpha = try line("hydrogen.balmerAlpha")
        let tone = try XCTUnwrap(alpha.tone)
        XCTAssertEqual(1e7 / alpha.wavenumber, 656.47, accuracy: 0.01, "Rydberg-formula wavelength in vacuum, nm")
        XCTAssertEqual(alpha.hertz, 4.566_738e14, accuracy: 1e9, "456.67 THz")
        XCTAssertEqual(tone.octaves, -41, "halved 41 times")
        XCTAssertEqual(tone.tempo, 97.35, accuracy: 0.005)
        XCTAssertEqual(tone.hertz, 207.67, accuracy: 0.01)
        XCTAssertEqual(tone.pitch % 12, 8, "A♭ / G♯")
        XCTAssertEqual(tone.concertPitch, 440.04, accuracy: 0.01)
    }

    func testTheHydrogenSeriesFollowTheRydbergFormula() throws {
        // ν̃ = R_H (1/n₁² − 1/n₂²), R_H = R∞ / (1 + mₑ/mₚ) with CODATA 2022 values.
        let rydberg = 10_973_731.568_157 / (1 + 5.446_170_214_889e-4) / 100
        XCTAssertEqual(SpectralLibrary.hydrogenRydberg, rydberg, accuracy: 1e-3)
        let alpha = try XCTUnwrap(SpectralLibrary.hydrogenWavenumber(lower: 2, upper: 3))
        XCTAssertEqual(alpha, rydberg * (1.0 / 4 - 1.0 / 9), accuracy: 1e-6)
        XCTAssertNil(SpectralLibrary.hydrogenWavenumber(lower: 3, upper: 3), "a line needs a higher upper level")
        XCTAssertNil(SpectralLibrary.hydrogenWavenumber(lower: 0, upper: 2), "levels start at 1")
        // Lyman α is exactly four times Balmer β: the same tone, two octaves apart.
        let lyman = try XCTUnwrap(try line("hydrogen.lymanAlpha").tone)
        let beta = try XCTUnwrap(try line("hydrogen.balmerBeta").tone)
        XCTAssertEqual(lyman.hertz, beta.hertz, accuracy: 1e-6)
        XCTAssertEqual(beta.octaves - lyman.octaves, 2)
    }

    func testEveryLineGivesItsToneKeyAndConcertPitch() throws {
        // python3: c · 100 · ν̃ halved into 127.09 … 254.18 Hz; the key as the keys spell it.
        let table: [(String, Double, String, Double)] = [
            ("hydrogen.lymanAlpha", 140.178, "C♯3", 445.04), ("hydrogen.balmerAlpha", 207.671, "G♯3", 440.04),
            ("hydrogen.balmerBeta", 140.178, "C♯3", 445.04), ("hydrogen.balmerGamma", 156.999, "D♯3", 444.06),
            ("hydrogen.balmerDelta", 166.137, "E3", 443.53), ("hydrogen.paschenAlpha", 145.370, "D3", 435.62),
            ("water.symmetricStretch", 199.423, "G3", 447.69), ("water.bend", 173.957, "F3", 438.34),
            ("water.antisymmetricStretch", 204.822, "G♯3", 434.00), ("carbonDioxide.pairLow", 140.192, "C♯3", 445.08),
            ("carbonDioxide.pairHigh", 151.400, "D♯3", 428.22), ("carbonDioxide.bend", 145.491, "D3", 435.98),
            ("carbonDioxide.antisymmetricStretch", 128.096, "C3", 430.86), ("oxygen.stretch", 169.747, "F3", 427.74),
            ("nitrogen.stretch", 254.108, "B3", 452.77), ("carbonMonoxide.stretch", 233.753, "A♯3", 441.27),
            ("methane.symmetricStretch", 159.070, "D♯3", 449.92), ("methane.bend", 167.304, "E3", 446.65),
            ("methane.antisymmetricStretch", 164.632, "E3", 439.51), ("methane.deformation", 142.437, "C♯3", 452.21),
            ("ozone.symmetricStretch", 240.595, "B3", 428.69), ("ozone.bend", 152.908, "D♯3", 432.49),
            ("ozone.antisymmetricStretch", 227.289, "A♯3", 429.06), ("ammonia.symmetricStretch", 181.973, "F♯3", 432.81),
            ("ammonia.umbrella", 207.221, "G♯3", 439.09), ("ammonia.antisymmetricStretch", 187.808, "F♯3", 446.69),
            ("ammonia.deformation", 177.447, "F3", 447.14),
        ]
        XCTAssertEqual(table.count, SpectralLibrary.all.count, "every line is in the table")
        for (id, hertz, key, concertPitch) in table {
            let tone = try XCTUnwrap(try line(id).tone, id)
            XCTAssertEqual(tone.hertz, hertz, accuracy: 0.002, id)
            XCTAssertEqual(NoteEditing.name(of: tone.pitch), key, id)
            XCTAssertEqual(tone.concertPitch, concertPitch, accuracy: 0.006, id)
        }
        // Hydrogen's other lines, Rydberg-formula wavelengths in vacuum (nm).
        for (id, nanometres) in [("hydrogen.lymanAlpha", 121.57), ("hydrogen.balmerBeta", 486.27),
                                 ("hydrogen.balmerGamma", 434.17), ("hydrogen.balmerDelta", 410.29),
                                 ("hydrogen.paschenAlpha", 1875.63)] {
            XCTAssertEqual(1e7 / (try line(id).wavenumber), nanometres, accuracy: 0.01, id)
        }
    }

    func testALineWithoutAWavenumberHasNoTone() {
        for wavenumber in [0, -1595, Double.nan, Double.infinity] {
            let empty = SpectralLine(id: "test", substance: "Test", line: "Test", spokenSubstance: "Test", spokenLine: "Test",
                                     kind: .molecule, wavenumber: wavenumber, source: "Test")
            XCTAssertNil(empty.tone, "\(wavenumber)")
        }
    }

    func testTheMoleculesAreTheMeasuredFundamentals() throws {
        // Wavenumbers in cm⁻¹, gas phase (Shimanouchi, NSRDS-NBS 39, for the polyatomic molecules;
        // O₂ and N₂ from diatomic constants; CO from high-resolution work), and the tone each gives
        // (python3: c · 100 · ν̃ halved into 127.09 … 254.18 Hz).
        let expected: [(String, Double, Double)] = [
            ("water.bend", 1595, 173.957), ("water.symmetricStretch", 3657, 199.423),
            ("water.antisymmetricStretch", 3756, 204.822), ("carbonDioxide.bend", 667, 145.491),
            ("carbonDioxide.antisymmetricStretch", 2349, 128.096), ("oxygen.stretch", 1556.4, 169.747),
            ("nitrogen.stretch", 2329.9, 254.108), ("carbonMonoxide.stretch", 2143.27, 233.753),
            ("methane.symmetricStretch", 2917, 159.070), ("ozone.symmetricStretch", 1103, 240.595),
        ]
        for (id, wavenumber, hertz) in expected {
            let found = try line(id)
            XCTAssertEqual(found.wavenumber, wavenumber, accuracy: 0.05, id)
            XCTAssertEqual(try XCTUnwrap(found.tone, id).hertz, hertz, accuracy: 0.002, id)
        }
    }

    func testEveryLineHasAToneInOctaveThreeAConcertPitchTheSongAcceptsAndItsSource() {
        XCTAssertGreaterThanOrEqual(SpectralLibrary.all.count, 20)
        let ids = SpectralLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique")
        for line in SpectralLibrary.all {
            guard let tone = line.tone else { return XCTFail("\(line.id) has no tone") }
            XCTAssertTrue((48...59).contains(tone.pitch), line.id)
            XCTAssertTrue(MusicalContext.concertPitchRange.contains(tone.concertPitch), line.id)
            XCTAssertFalse(line.substance.isEmpty, line.id)
            XCTAssertFalse(line.line.isEmpty, line.id)
            XCTAssertFalse(line.spokenSubstance.isEmpty || line.spokenLine.isEmpty, line.id)
            XCTAssertFalse(line.source.isEmpty, line.id)
            XCTAssertTrue(line.wavenumber.isFinite && line.wavenumber > 0, line.id)
        }
        for kind in SpectralLine.Kind.allCases {
            XCTAssertFalse(SpectralLibrary.all.filter { $0.kind == kind }.isEmpty, "\(kind) has lines")
        }
    }

    func testNoWordOfTheSpectralLibraryIsOneEchoelNeverUses() {
        var texts = [SpectralLibrary.method, SpectralLibrary.credit]
        texts += SpectralLine.Kind.allCases.map(\.title)
        texts += SpectralLibrary.all.flatMap { [$0.substance, $0.line, $0.spokenSubstance, $0.spokenLine, $0.source] }
        for text in texts {
            let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            XCTAssertTrue(words.isDisjoint(with: LearnGuideTests.forbiddenWords), text)
            for phrase in LearnGuideTests.forbiddenPhrases {
                XCTAssertFalse(text.lowercased().contains(phrase), "\(text): \(phrase)")
            }
        }
        XCTAssertTrue(SpectralLibrary.method.contains("claim nothing about what a tone does"),
                      "the page says it is arithmetic, not an effect")
    }
}
