// TheSoundListShowsItsTypeTests.swift
// Echoel — the sound list shows Name · Type · favourite and filters by type (founder 2026-10-15,
// after the Analog Console preset browser). The type is DERIVED from a patch's own parameters
// (`SoundType.of`), never stored.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR: every factory sound has its type (the golden table is the ear decision
//      made visible — a re-tuning shows up here), and every type has at least one factory sound.
//   2. END-TO-END BEHAVIOUR: the edges — a weak instrument blend is not orchestral, an unknown
//      timbre is not orchestral, case does not matter, non-finite parameters fall to Lead.
//   3. END-TO-END BEHAVIOUR: the filter admits exactly what it names.
//   4. SOURCE-TEXT SCAN: the browser keeps store order and filters in place, the star is its own
//      toggle, the filter is a menu Picker, nothing new is persisted on `SynthPatch`.
//
// ⚠️ HONEST GRADING (#433). `SoundType` and `SoundFilter` are created by this commit, so the file
// does not compile against the parent: one absence (#486), every claim FORWARD. The golden table was
// derived by hand from `SynthPatch.rawFactory` and re-derived independently by a second reader.
//
// ⚠️ THE LIMIT. Whether the star and the row each take their own tap on a 375-pt phone is a DEVICE
// PROBE (NEEDS-FOUNDER-VERIFY: Browse → Sounds → Type ▸ Bass shows Deep Sub only; star Pluck, then
// Favorites shows Pluck).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSoundListShowsItsTypeTests: XCTestCase {

    // MARK: 1 — the golden table

    private static let golden: [String: SoundType] = [
        "Warm Pad": .pad, "Warm Strings": .pad, "Choir Vox": .pad, "Drone": .pad, "Echoel Field": .pad,
        "Bright Lead": .lead, "Hollow Reed": .lead, "Vapor Lead": .lead, "Brass Tuba": .lead,
        "Deep Sub": .bass,
        "Soft Keys": .keys,
        "Pluck": .pluck,
        "Glass Bell": .bell, "Metallic": .bell,
        "Violin": .orchestral, "Flute": .orchestral, "Trumpet": .orchestral,
        "Cello": .orchestral, "Clarinet": .orchestral, "Oboe": .orchestral,
    ]

    func testEveryFactorySoundHasItsType() {
        XCTAssertEqual(SynthPatch.factory.count, Self.golden.count, "a factory sound was added or removed — give it a type here")
        for patch in SynthPatch.factory {
            guard let expected = Self.golden[patch.name] else {
                XCTFail("`\(patch.name)` has no row in the golden table")
                continue
            }
            XCTAssertEqual(SoundType.of(patch), expected, "\(patch.name)")
        }
        for type in SoundType.allCases {
            XCTAssertTrue(SynthPatch.factory.contains { SoundType.of($0) == type },
                          "`\(type)` has no factory sound — its filter would show an empty list")
        }
    }

    // MARK: 2 — the edges

    func testTheEdgesOfTheRules() {
        var weak = SynthPatch(name: "weak", attack: 0.12, timbreProfile: "Violin", timbreBlend: 0.4)
        XCTAssertEqual(SoundType.of(weak), .pad, "a weak instrument blend is not orchestral")
        weak.timbreProfile = "VIOLIN"
        weak.timbreBlend = 0.9
        XCTAssertEqual(SoundType.of(weak), .orchestral, "case does not matter")
        let unknown = SynthPatch(name: "unknown", attack: 0.003, sustain: 0, filterCutoff: 4000,
                                 timbreProfile: "", timbreBlend: 0.9)
        XCTAssertEqual(SoundType.of(unknown), .pluck, "no timbre is not orchestral")
        let broken = SynthPatch(name: "nan", attack: .nan, decay: .nan, sustain: .nan, release: .nan,
                                spectralShape: "natural", filterCutoff: .nan)
        XCTAssertEqual(SoundType.of(broken), .lead, "non-finite parameters fail every rule")
        #if canImport(Accelerate)
        XCTAssertEqual(SoundType.orchestralTimbres,
                       Set(EchoelDDSP.InstrumentTimbre.allCases.map { $0.rawValue.lowercased() }),
                       "the mirror of the instrument timbres is complete")
        #endif
    }

    // MARK: 3 — the filter

    func testTheFilterAdmitsWhatItNames() {
        let pluck = SynthPatch.factory.first { $0.name == "Pluck" }
        let sub = SynthPatch.factory.first { $0.name == "Deep Sub" }
        guard let pluck, let sub else { return XCTFail("ANCHOR MISSING: the factory sounds Pluck and Deep Sub") }
        XCTAssertTrue(SoundFilter.all.admits(pluck, favorite: false))
        XCTAssertTrue(SoundFilter.favorites.admits(pluck, favorite: true))
        XCTAssertFalse(SoundFilter.favorites.admits(pluck, favorite: false))
        XCTAssertTrue(SoundFilter.type(.bass).admits(sub, favorite: false))
        XCTAssertFalse(SoundFilter.type(.bass).admits(pluck, favorite: true))
        XCTAssertEqual(SoundFilter.choices.count, 2 + SoundType.allCases.count)
    }

    // MARK: 4 — the browser

    func testTheBrowserFiltersInPlaceAndPersistsNothingNew() throws {
        let browser = try code("Sources/Echoelmusic/Studio/SoundBrowserView.swift")
        XCTAssertTrue(browser.contains("ForEach(patchStore.patches)"), "store order is kept")
        XCTAssertFalse(browser.contains("sortedPatches"), "filtered, never re-sorted")
        XCTAssertTrue(browser.contains("filter.admits(patch, favorite: favorite)"), "the filter decides each row")
        XCTAssertEqual(browser.components(separatedBy: "patchStore.toggleFavorite(id:").count - 1, 1,
                       "one star toggle")
        XCTAssertTrue(browser.contains(".pickerStyle(.menu)"), "named values are a menu Picker")
        XCTAssertTrue(browser.contains("@State private var filter: SoundFilter = .all"), "the filter is per view")
        XCTAssertFalse(browser.contains("EchoelTheme.accent"), "the accent is the body's signal only")
        let patch = try code("Sources/Echoelmusic/DSP/SynthPatch.swift")
        XCTAssertFalse(patch.contains("soundType") || patch.contains("var category"),
                       "the type is derived — nothing new is stored on a patch")
        let type = try code("Sources/Echoelmusic/Studio/SoundType.swift")
        XCTAssertFalse(type.contains("import SwiftUI"), "the rule is plain Foundation")
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
