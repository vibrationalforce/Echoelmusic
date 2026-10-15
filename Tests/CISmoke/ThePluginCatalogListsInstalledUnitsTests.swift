//
//  ThePluginCatalogListsInstalledUnitsTests.swift
//  Production level H1 (founder 2026-10-13: „Solange keine vernünftige Produktionsumgebung wie
//  AUv3 Plugins für Effekte und MIDI Instrumente … vorhanden ist finde ich testen planlos. Sieh
//  zu das wir auf Produktion Level kommen.") — the first, READ-ONLY hosting step: the Device page
//  of a rack track lists the AUv3 instruments and effects installed on this iPhone.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `PluginDescriptor`, `PluginCatalog` and the row's
//    static helpers are shipped, pure, and called here directly. Claim 1: the three component
//    types round-trip between role and four-character code, an unknown type has no role, and a
//    non-printable byte is written as `?`. Claim 2: the order is one entry per component,
//    third-party before Apple, then maker and name case-blind. Claim 3 (H2c, replaced the H1
//    summary line): the row offers installed INSTRUMENTS but never this app's own unit or an
//    effect; a component is known by its codes; the note says what plays and, plainly, that the
//    effect inserts (H6) are not built yet; its screen opens since H3, its settings are kept since H4.
//  · SOURCE-TEXT SCAN (claim 4) — the row is a `View`: it is mounted only inside the rack-track
//    branch of the Device page, it queries the registry DETACHED, a pick goes through
//    `editLanePlugin` + `setLanePluginInstrument` (one Undo step), and neither the row nor the
//    catalog instantiates a unit — `HostedInstrumentHost` does. ⛔ H1 forbade a `Picker(` here
//    ("a menu that cannot load is a half door"); H2b made the load real, so H2c lifted it.
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

    // MARK: 3 — what the row offers and says (H2c)

    func testTheRowOffersInstalledInstrumentsButNeverItsOwn() {
        let synth = Self.unit("Synth", maker: "Acme", subtype: 0x7379_6E74, manufacturer: 0x4163_6D65)
        let own = Self.unit("Echoel", maker: "Echoel", subtype: 0x6563_686C,
                            manufacturer: HostedInstrumentHost.ownManufacturer)
        // COUNTERWEIGHT: an effect is listed, never offered as an instrument.
        let reverb = Self.unit("Verb", maker: "Acme", subtype: 0x7665_7262, manufacturer: 0x4163_6D65,
                               type: PluginCatalog.effectType)
        let offered = TrackPluginRow.offered([synth, own, reverb])
        XCTAssertEqual(offered.map(\.name), ["Synth"], "this app's own unit and effects are not offered")
        XCTAssertEqual(offered.first?.manufacturer, 0x4163_6D65)
        let twin = DeviceInsert.PluginComponent(type: synth.type, subtype: synth.subtype,
                                                manufacturer: synth.manufacturer, name: "Renamed",
                                                manufacturerName: "Acme")
        XCTAssertEqual(TrackPluginRow.key(for: offered[0]), TrackPluginRow.key(for: twin),
                       "a component is known by its codes, not its name")
    }

    func testTheRowSaysWhatPlaysAndPromisesNothingWithoutADoor() {
        let synth = DeviceInsert.PluginComponent(type: PluginCatalog.instrumentType, subtype: 1,
                                                 manufacturer: 2, name: "Synth", manufacturerName: "Acme")
        let playing = TrackPluginRow.note(current: synth, installed: 3, effects: 0)
        XCTAssertTrue(playing.contains("Synth"), playing)
        XCTAssertTrue(playing.contains("the piece keeps its settings"), "the song keeps the plugin's settings (H4): \(playing)")
        XCTAssertEqual(TrackPluginRow.note(current: nil, installed: 0, effects: 0),
                       "No Audio Unit instruments are installed on this iPhone.")
        // Kandidat A (g), 2026-10-15: no sentence about the effect insert until its door ships.
        XCTAssertEqual(TrackPluginRow.note(current: nil, installed: 2, effects: 4),
                       "Pick an installed instrument to play this track instead of its built-in voice.",
                       "the note promises nothing that has no door — installed effects are not announced")
    }

    // MARK: 4 — mounted on rack tracks, detached, and the pick goes through the one writer

    func testTheRowIsMountedOnRackTracksAndPicksThroughTheWriter() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspectorFile))
        guard let gate = inspector.range(of: "if !instruments.isEmpty {") else {
            return XCTFail("the Device page no longer has its rack-track branch")
        }
        let branch = String(inspector[gate.upperBound...].prefix(400))
        XCTAssertTrue(branch.contains("TrackPluginRow(laneID: laneID)"),
                      "the plugin row belongs inside the rack-track branch of the Device page")
        XCTAssertEqual(inspector.components(separatedBy: "TrackPluginRow(").count - 1, 1,
                       "the row is mounted exactly once")

        let row = SourceText.codeOnly(try text(Self.rowFile))
        XCTAssertTrue(row.contains("Task.detached"), "the registry query runs off the main actor")
        XCTAssertTrue(row.contains("PluginCatalog.installed(.instrument)"))
        XCTAssertTrue(row.contains("timeline.editLanePlugin(id: laneID) { timeline.setLanePluginInstrument(laneID, insert) }"),
                      "one pick, one Undo step, through the one writer")
        XCTAssertEqual(row.components(separatedBy: "setLanePluginInstrument(").count - 1, 1)
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a menu (Uncodixfy: no sheet)")

        let catalog = SourceText.codeOnly(try text(Self.catalogFile))
        for source in [row, catalog] {
            for loader in ["instantiate(", "AUAudioUnit(", "AVAudioUnit(", "attach("] {
                XCTAssertFalse(source.contains(loader),
                               "the row and the catalog never load a unit — `HostedInstrumentHost` does: found \(loader)")
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
