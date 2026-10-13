//
//  ThePluginCatalogListsInstalledUnitsTests.swift
//  Production level H1 (founder 2026-10-13: „Solange keine vernünftige Produktionsumgebung wie
//  AUv3 Plugins für Effekte und MIDI Instrumente … vorhanden ist finde ich testen planlos. Sieh
//  zu das wir auf Produktion Level kommen.") — the first, READ-ONLY hosting step: the Device page
//  of a rack track lists the AUv3 instruments and effects installed on this iPhone.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `PluginDescriptor`, `PluginCatalog` and
//    `TrackPluginRow.summary` are shipped, pure, and called here directly. Claim 1: the three
//    component types round-trip between role and four-character code, an unknown type has no
//    role, and a non-printable byte is written as `?`. Claim 2: the order is one entry per
//    component, third-party before Apple, then maker and name case-blind. Claim 3: the row's one
//    line says "none" when nothing is installed and names at most three units per kind.
//  · SOURCE-TEXT SCAN (claim 4) — the row is a `View`: it is mounted only inside the rack-track
//    branch of the Device page, it queries the registry DETACHED, and neither it nor the catalog
//    instantiates a unit or offers a picker — H1 lists, H2 loads.
//  · DEVICE PROBE, OPEN — that the list matches what AUM shows on the founder's iPhone: the
//    NEEDS-FOUNDER-VERIFY ask at `TrackPluginRow`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — every type it
//  names is created by this commit — so no assertion has a verdict on the parent (ONE absence,
//  #486). Claims 1–3 are forward guards transcribed by reading `fourCC`, `role(forType:)`,
//  `ordered` and `summary`; claim 4's needles were grepped against the worktree. COUNTERWEIGHTS
//  (#343): claim 1's unknown type, claim 2's duplicate, claim 3's empty catalog.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePluginCatalogListsInstalledUnitsTests: XCTestCase {

    private static let catalogFile = "Sources/Echoelmusic/Audio/PluginCatalog.swift"
    private static let rowFile = "Sources/Echoelmusic/Studio/TrackPluginRow.swift"
    private static let inspectorFile = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    private static func unit(_ name: String, maker: String, subtype: UInt32,
                             manufacturer: UInt32,
                             type: UInt32 = PluginCatalog.instrumentType) -> PluginDescriptor {
        PluginDescriptor(type: type, subtype: subtype, manufacturer: manufacturer,
                         name: name, manufacturerName: maker, version: 1)
    }

    // MARK: 1 — role ↔ four-character code

    func testTheThreeComponentTypesRoundTrip() {
        XCTAssertEqual(PluginDescriptor.fourCC(PluginCatalog.instrumentType), "aumu")
        XCTAssertEqual(PluginDescriptor.fourCC(PluginCatalog.effectType), "aufx")
        XCTAssertEqual(PluginDescriptor.fourCC(PluginCatalog.musicEffectType), "aumf")
        XCTAssertEqual(PluginDescriptor.fourCC(PluginCatalog.appleManufacturer), "appl")
        for role in PluginDescriptor.Role.allCases {
            XCTAssertEqual(PluginCatalog.role(forType: PluginCatalog.type(for: role)), role,
                           "\(role) must map back to itself")
        }
        // COUNTERWEIGHT: a generator ('augn') is not a role this catalog offers.
        XCTAssertNil(PluginCatalog.role(forType: 0x6175_676E))
        XCTAssertEqual(PluginDescriptor.fourCC(0x6100_0A62), "a??b",
                       "a byte outside printable ASCII is written as ?")
        let u = Self.unit("Pad", maker: "Maker", subtype: 0x7061_6473, manufacturer: 0x6D6B_7231)
        XCTAssertEqual(u.id, "aumu/pads/mkr1")
        XCTAssertEqual(u.role, .instrument)
        XCTAssertFalse(u.isApple)
    }

    // MARK: 2 — one entry per component, third-party first

    func testTheOrderIsThirdPartyFirstThenMakerAndName() {
        let apple = Self.unit("DLSMusicDevice", maker: "Apple", subtype: 0x646C_7320,
                              manufacturer: PluginCatalog.appleManufacturer)
        let zeta = Self.unit("bass", maker: "zeta", subtype: 0x6261_7373, manufacturer: 0x7A65_7461)
        let alphaB = Self.unit("Bells", maker: "Alpha", subtype: 0x6265_6C6C, manufacturer: 0x616C_7068)
        let alphaA = Self.unit("arp", maker: "alpha", subtype: 0x6172_7020, manufacturer: 0x616C_7068)
        // COUNTERWEIGHT: the system listing the same component twice keeps one entry.
        let ordered = PluginCatalog.ordered([apple, zeta, alphaB, alphaA, zeta])
        XCTAssertEqual(ordered.map(\.name), ["arp", "Bells", "bass", "DLSMusicDevice"])
        XCTAssertTrue(ordered.last?.isApple ?? false, "Apple's own units come last")
    }

    // MARK: 3 — the row's one line

    func testTheRowSaysNoneOrNamesAtMostThreePerKind() {
        // COUNTERWEIGHT: an empty catalog says so, it does not render an empty line.
        XCTAssertEqual(TrackPluginRow.summary(instruments: [], effects: []),
                       "No Audio Unit instruments or effects are installed.")
        let four = (0..<4).map {
            Self.unit("I\($0)", maker: "M", subtype: UInt32(0x6100_0000 + $0), manufacturer: 0x6D6D_6D6D)
        }
        let line = TrackPluginRow.summary(instruments: four, effects: [])
        XCTAssertTrue(line.hasPrefix("4 instruments: I0, I1, I2 +1"), line)
        XCTAssertTrue(line.hasSuffix("No effects"), line)
        XCTAssertFalse(line.contains("I3"), "at most three names per kind")
    }

    // MARK: 4 — mounted on rack tracks, detached, and it loads nothing

    func testTheRowIsMountedOnRackTracksAndLoadsNothing() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspectorFile))
        guard let gate = inspector.range(of: "if !instruments.isEmpty {") else {
            return XCTFail("the Device page no longer has its rack-track branch")
        }
        let branch = String(inspector[gate.upperBound...].prefix(400))
        XCTAssertTrue(branch.contains("TrackPluginRow()"),
                      "the plugin row belongs inside the rack-track branch of the Device page")
        XCTAssertEqual(inspector.components(separatedBy: "TrackPluginRow(").count - 1, 1,
                       "the row is mounted exactly once")

        let row = SourceText.codeOnly(try text(Self.rowFile))
        XCTAssertTrue(row.contains("Task.detached"), "the registry query runs off the main actor")
        XCTAssertTrue(row.contains("PluginCatalog.installed(.instrument)"))
        XCTAssertFalse(row.contains("Picker("), "H1 lists; a menu that cannot load is a half door")

        let catalog = SourceText.codeOnly(try text(Self.catalogFile))
        for source in [row, catalog] {
            for loader in ["instantiate(", "AUAudioUnit(", "AVAudioUnit(", "attach("] {
                XCTAssertFalse(source.contains(loader), "H1 must not load a unit: found \(loader)")
            }
        }
    }

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
