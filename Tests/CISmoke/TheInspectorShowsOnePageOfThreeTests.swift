// TheInspectorShowsOnePageOfThreeTests.swift
// Echoel — Workstation redesign A8 (remainder): the open track's inspector shows ONE page of
// three — Track (name · level · pan · remove), Part (the track's parts) or Device (what plays
// it · instrument · instance · style · effect) — chosen by a segmented control at its top.
//
// WHAT THIS PINS, AND THE RISK IT ANSWERS. One inline area, three pages: the risk is not the
// control, it is a row that goes missing (a page gate that swallowed a row nobody re-homed),
// a second truth about the chosen page (an `@State` in a view rebuilt per track by
// `.id(row.id)`, or a persisted copy beside the owner), a Part page that is an empty box on a
// bio track, and a typed name lost when its page leaves the screen.
//
// 1. END-TO-END (pure + the real `@MainActor` owner): which pages a track offers — Part exactly
//    where `TrackParts.arrangeable` says (#416: the rule `TrackPartsView` hides itself by);
//    the page drawn falls back to Track; the choice outlives a change of track, a close and a
//    clear, and a bio track never erases it.
// 2. SOURCE-TEXT SCAN: the body draws one `Picker`, segmented, whose setter commits the name
//    first; each page gate appears once and holds its rows, each row once.
// 3. SOURCE-TEXT SCAN: the choice is view state on the ONE owner — one writer, no persistence.
// 4. COUNTERWEIGHTS (#343): no modal and no hot read in the inspector; the name still commits
//    on close; the instance request still runs on appear; the Workstation still mounts the
//    inspector, the part bar, the arm switch, the pitch field and the part-tempo rows once
//    each; `TrackPartsView` keeps its own gate; the three segment words are German.
//
// Grading (Tests/CISmoke/CLAUDE.md §0/§3 — no Swift toolchain in a web session):
// · Parent (aea9096f6): this file does NOT compile there — `TrackInspectorPage`,
//   `TrackMix.inspectorPages`, `WorkstationSelection.inspectorPage`/`showInspectorPage` are
//   new. No assertion has a verdict on the parent; claims 2–3 are red there by ONE absence,
//   reported once (#486). Claim 1 is FORWARD (it drives symbols this commit creates).
//   Claim 4 is COUNTERWEIGHTS, green on both trees except its catalog half for the two new
//   keys ("Inspector", the hint), which belongs to the same one absence.
// · This tree: every claim transcribed into Python and driven green.
// · Stripper (`SourceText.codeOnly`): PROPHYLAKTISCH — 0 of the source verdicts flip between
//   raw and stripped text on either tree.
// NOT covered: whether the segments render, fit, or read well — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → open a MIDI track: the control reads „Spur | Teil | Gerät"
// and each page shows only its rows; type a new name, tap „Gerät" before Return — the name is
// kept; open another track — the same page stays; open the bio track — two segments, Spur shown;
// in landscape (A9) the three words fit the 260-pt column at the largest text size; a tap near
// the top or bottom edge of a segment still switches (the hit area is the control's own height,
// not the 44-pt frame around it).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheInspectorShowsOnePageOfThreeTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let ownerPath = "Sources/Echoelmusic/Studio/WorkstationSelection.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let partsViewPath = "Sources/Echoelmusic/Studio/TrackPartsView.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let sourcesRoot = "Sources/Echoelmusic"

    private struct AnchorMissing: Error {}

    // MARK: 1 — END-TO-END: the pages a track offers, and the choice that outlives the track

    func testATrackOffersItsPagesAndTheChoiceOutlivesTheTrack() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let loop = TimelineLane(name: "Loop", kind: .audio)
        let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let look = TimelineLane(name: "Look", kind: .visual)
        let doc = TimelineDocument(lanes: [keys, loop, body, look], regions: [])

        XCTAssertEqual(TrackMix.inspectorPages(of: keys.id, in: doc), [.track, .part, .device])
        XCTAssertEqual(TrackMix.inspectorPages(of: loop.id, in: doc), [.track, .part, .device])
        XCTAssertEqual(TrackMix.inspectorPages(of: body.id, in: doc), [.track, .device],
                       "a bio track has no parts to arrange — a Part page there is an empty box")
        XCTAssertEqual(TrackMix.inspectorPages(of: look.id, in: doc), [.track, .device])
        for lane in doc.lanes {
            XCTAssertEqual(TrackMix.inspectorPages(of: lane.id, in: doc).contains(.part),
                           TrackParts.arrangeable(lane.id, in: doc),
                           "Part is offered exactly where TrackPartsView draws rows (#416)")
        }

        XCTAssertEqual(TrackInspectorPage.shown(.device, offered: [.track, .part, .device]), .device)
        XCTAssertEqual(TrackInspectorPage.shown(.part, offered: [.track, .device]), .track,
                       "a track without the chosen page shows Track — every track has a name")
        XCTAssertEqual(TrackInspectorPage.shown(.track, offered: [.track, .device]), .track)

        let selection = WorkstationSelection()
        XCTAssertEqual(selection.inspectorPage, .track, "a fresh owner opens on Track")
        selection.showInspectorPage(.device)
        selection.selectTrack(keys.id)
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives opening a track")
        selection.toggleTrack(keys.id)
        XCTAssertNil(selection.trackID, "toggling the open track closes it")
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives a close")
        selection.clear()
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives a clear")

        selection.showInspectorPage(.part)
        selection.selectTrack(body.id)
        XCTAssertEqual(TrackInspectorPage.shown(selection.inspectorPage,
                                                offered: TrackMix.inspectorPages(of: body.id, in: doc)),
                       .track, "the bio track draws Track")
        XCTAssertEqual(selection.inspectorPage, .part,
                       "and does not erase the choice — the next MIDI track opens on Part again")
    }

    // MARK: 2 — SOURCE: one segmented control, one page at a time

    func testTheInspectorDrawsOnePageAtATime() throws {
        let code = SourceText.codeOnly(try text(Self.inspectorPath))
        let body = try member("var body: some View {", in: code)

        XCTAssertTrue(body.contains("let pages = TrackMix.inspectorPages(of: laneID, in: document)"))
        XCTAssertTrue(body.contains("let page = TrackInspectorPage.shown(selection.inspectorPage, offered: pages)"))
        XCTAssertEqual(occurrences("selection.inspectorPage", in: body), 1,
                       "the body reads the choice once, through `shown`")
        XCTAssertTrue(code.contains("@Environment(WorkstationSelection.self) private var selection"),
                      "the inspector reads the ONE owner")

        XCTAssertTrue(body.contains("Picker(\"Inspector\", selection: Binding<TrackInspectorPage>("))
        XCTAssertTrue(body.contains(".pickerStyle(.segmented)"),
                      "segmented: no popover for a re-render to tear down")
        XCTAssertEqual(occurrences("Picker(", in: body), 1, "one page control; the menus live in members")
        XCTAssertTrue(body.contains("Text(\"Track\").tag(TrackInspectorPage.track)"))
        XCTAssertTrue(body.contains("Text(\"Device\").tag(TrackInspectorPage.device)"))
        let partGate = try member("if pages.contains(.part) {", in: body)
        XCTAssertTrue(partGate.contains("Text(\"Part\").tag(TrackInspectorPage.part)"),
                      "the Part segment exists only where the page does")

        guard let setter = body.range(of: "set: { picked in"),
              let write = body.range(of: "selection.showInspectorPage(picked)", range: setter.upperBound..<body.endIndex) else {
            XCTFail("ANCHOR MISSING: the page control's setter (#454)")
            throw AnchorMissing()
        }
        XCTAssertTrue(body[setter.upperBound..<write.lowerBound].contains("commitName()"),
                      "a typed name is stored before its page leaves the screen")

        let pages: [(gate: String, rows: [String])] = [
            ("if page == .device {", ["TrackMix.deviceName(controls.role)", "openDeviceButton",
                                     "instrumentRow(instruments)", "EchoelInstanceLine()",
                                     "echoelGenreRow", "echoelEffectRow", "effectRow"]),
            ("if page == .track {", ["TextField(\"Track name\"", "label: \"Level\"", "label: \"Pan\"",
                                    "removeRow(removal)"]),
            ("if page == .part {", ["TrackPartsView(laneID: laneID)"]),
        ]
        for (gate, rows) in pages {
            XCTAssertEqual(occurrences(gate, in: body), 1, "one gate per page: \(gate)")
            let page = try member(gate, in: body)
            for row in rows {
                XCTAssertTrue(page.contains(row), "\(row) lost its page (\(gate))")
                XCTAssertEqual(occurrences(row, in: body), 1, "\(row) is drawn once — on its page")
            }
        }
    }

    // MARK: 3 — SOURCE: the choice is view state on the one owner

    func testTheChoiceIsViewStateOnTheOneOwner() throws {
        let owner = SourceText.codeOnly(try text(Self.ownerPath))
        XCTAssertTrue(owner.contains("public private(set) var inspectorPage: TrackInspectorPage = .track"))
        XCTAssertTrue(owner.contains("public func showInspectorPage(_ page: TrackInspectorPage) {"))
        XCTAssertTrue(owner.contains("offered.contains(chosen) ? chosen : .track"),
                      "one fallback rule, on the type")
        XCTAssertFalse(owner.contains("Codable"), "the selection is never persisted")
        XCTAssertFalse(owner.contains("UserDefaults"), "the selection is never persisted")

        let inspector = SourceText.codeOnly(try text(Self.inspectorPath))
        for forbidden in ["@AppStorage", "@SceneStorage", "UserDefaults", "@State private var page"] {
            XCTAssertFalse(inspector.contains(forbidden),
                           "\(forbidden): a second home for the page — the inspector is rebuilt per track")
        }

        XCTAssertEqual(try filesUnderSources(containing: "showInspectorPage("),
                       ["Studio/TrackInspectorView.swift", "Studio/WorkstationSelection.swift"],
                       "one caller (the page control) and the declaration")
        XCTAssertEqual(try filesUnderSources(containing: "inspectorPage = "),
                       ["Studio/WorkstationSelection.swift"], "one writer")
    }

    // MARK: 4 — COUNTERWEIGHTS: the neighbours keep their doors

    func testTheNeighboursKeepTheirDoors() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspectorPath))
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(inspector.contains(modal), "\(modal): the pages are inline, never a modal")
        }
        for hot in ["isPlaying", "currentTick", "latestBio", "masterLevel", "TimelineView(",
                    "CameraRPPGBioPublisher"] {
            XCTAssertFalse(inspector.contains(hot), "\(hot): a hot read rebuilds the menus above")
        }
        XCTAssertTrue(inspector.contains(".onDisappear { commitName() }"), "the name commits on close")
        let appear = try member(".onAppear {", in: inspector)
        XCTAssertTrue(appear.contains("TrackMix.requestEchoelInstanceIfMissing("),
                      "the instance request does not wait for the Device page")

        let workstation = SourceText.codeOnly(try text(Self.workstationPath))
        for door in ["TrackInspectorView(laneID: row.id)", "SelectedPartBar(playFrom:",
                     "TrackArmToggle(laneID: row.id)", "pitchField(row)", "partTempoRows(laneID: row.id)"] {
            XCTAssertEqual(occurrences(door, in: workstation), 1, "\(door) is still mounted once")
        }
        let parts = SourceText.codeOnly(try text(Self.partsViewPath))
        XCTAssertTrue(parts.contains("if TrackParts.arrangeable(laneID, in: document) {"),
                      "TrackPartsView keeps its own gate — the Part page relies on the same rule")

        let strings = try catalogStrings()
        for key in ["Track", "Part", "Device", "Inspector",
                    "Shows this track, its parts or the device that plays it"] {
            XCTAssertEqual(englishValue(of: key, in: strings), key, "`\(key)` is an English-only catalog key")
        }
    }

    // MARK: helpers

    /// The brace-matched block that opens at `anchor` (#408), string-literal aware. A missed
    /// anchor fails AND throws (#926) — an empty slice would make every `contains` vacuous.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var inString = false
        var escaped = false
        var index = code.index(before: start.upperBound)
        while index < code.endIndex {
            let ch = code[index]
            if inString {
                if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { inString = false }
            } else if ch == "\"" {
                inString = true
            } else if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: no closing brace after `\(anchor)` (#454)")
        throw AnchorMissing()
    }

    private func occurrences(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Swift files under `Sources/Echoelmusic` whose CODE (comments blanked) contains `needle`,
    /// as "<dir>/<file>" paths, sorted.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk \(Self.sourcesRoot) (#454)")
            throw AnchorMissing()
        }
        var seen = 0
        var hits: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            seen += 1
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains(needle) {
                hits.append(url.pathComponents.suffix(2).joined(separator: "/"))
            }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw too few files to mean anything — a parser that matches nothing is a finding")
        return hits.sorted()
    }

    private func catalogStrings() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalogPath))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: Localizable.xcstrings is not the JSON shape this guard reads (#454)")
            throw AnchorMissing()
        }
        return strings
    }

    /// The `en` value of `key` — nil when the key is missing or the entry still carries a second
    /// language. The app speaks one language since 2026-10-02 (founder: "Nur Englisch"); this helper
    /// read the `de` unit until then.
    private func englishValue(of key: String, in strings: [String: Any]) -> String? {
        let entry = strings[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any] ?? [:]
        guard Set(localizations.keys) == ["en"] else { return nil }
        let en = localizations["en"] as? [String: Any]
        let unit = en?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }
}
