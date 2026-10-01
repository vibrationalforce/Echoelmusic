// TheGenreIsAStyleOnTheEchoelDeviceTests.swift
// Echoel — the genre left the always-visible header and became the Echoel instrument's STYLE, chosen
// on that device (the Echoel track's inspector row). Workstation redesign A2, founder 2026-10-01.
//
// WHY: the founder, beside the tablet workstation mockup — *„Grundsätzlich finde ich das Ding mit
// den Genres und die rudimentären Bedienungen nicht so schön."* Answered in
// `scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md` (a): the genre is not the first control of
// the chrome any more, it is a property of the generator device. In a workstation a style belongs to
// the instrument that plays it — a header that leads with a genre reads as a preset toy.
//
// THE THREE CLAIMS:
// 1. The header strip builds no genre control and binds no genre key — one door, not two.
// 2. The door is the Echoel track's inspector row, it says "Style", and the catalog gives it German.
//    The read-only instance line under that row names the same fact with the same word (A2 follow-up).
// 3. Counterweights — the funnel is intact: the row writes the song through ONE store call and posts
//    `"echoelGenre"`; the instrument adopts it; the OSC cue still posts `"genre"`; the row still
//    offers the curated shelves; the default document still has the MIDI lane the row lives on.
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both trees):
// all scans are SOURCE-TEXT. Parent tree: claim 1 is a REGRESSION guard (red there for its named
// reason — the strip built `labeled("Genre")` and bound `StudioDefaultKeys.genre.key`); claim 2 is
// red there by ABSENCE of the new spelling (`Text("Style")`, the catalog key) — one absence (#486);
// claim 3 is all COUNTERWEIGHTS, green on both. The two instance-line needles were added one commit
// later (A2 follow-up): against THAT parent they are a REGRESSION pair, red for their named reason
// (`fact("Genre", …)`), and green after. DEVICE PROBE, open: the Style row is found by a
// player who used to see the genre in the header — that is a reading, not a scan.

import XCTest

final class TheGenreIsAStyleOnTheEchoelDeviceTests: XCTestCase {

    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let store = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let instanceLine = "Sources/Echoelmusic/Studio/EchoelInstanceLine.swift"

    // MARK: 1 — the header builds no genre control

    func testTheHeaderStripBuildsNoGenreControl() throws {
        let file = SourceText.codeOnly(try text(Self.workspace))
        guard let start = file.range(of: "struct CompositionHeaderStrip: View {") else {
            return XCTFail("ANCHOR MISSING: `struct CompositionHeaderStrip: View {` (#454)")
        }
        let rest = file[start.upperBound...]
        let end = rest.range(of: "\nstruct ")?.lowerBound ?? rest.endIndex
        let strip = String(rest[..<end])
        XCTAssertTrue(strip.contains("labeled(\"Key\")"),
                      "the scan reached the strip's controls — otherwise the absences below prove nothing")
        for banned in ["labeled(\"Genre\")", "Picker(\"Genre\"", "StudioDefaultKeys.genre.key",
                       "posts: \"genre\"", "MusicStyle.Subcategory.allCases"] {
            XCTAssertFalse(strip.contains(banned), """
                `CompositionHeaderStrip` contains `\(banned)` again.

                The founder moved the genre out of the always-visible bar on 2026-10-01 — it is \
                the Echoel instrument's STYLE, chosen on the Echoel track's inspector row. A second \
                door to one setting is the drift A2 removed.
                """)
        }
    }

    // MARK: 2 — the one door says "Style", in both languages

    func testTheEchoelTrackRowIsTheStyleDoor() throws {
        let file = SourceText.codeOnly(try text(Self.inspector))
        guard let decl = file.range(of: "private var echoelGenreRow: some View {"),
              let next = file.range(of: "private var ", range: decl.upperBound..<file.endIndex) else {
            return XCTFail("ANCHOR MISSING: `echoelGenreRow` and the member after it (#454)")
        }
        let row = String(file[decl.upperBound..<next.lowerBound])
        XCTAssertTrue(row.contains("Text(\"Style\")"), "the row's caption names the device's style")
        XCTAssertTrue(row.contains("Picker(\"Style\""), "VoiceOver hears the same word the caption shows")
        XCTAssertFalse(row.contains("Text(\"Genre\")"), "two words for one thing on one row (rule 1)")

        // The read-only instance line under the row names the same fact, so it says the same word.
        let instance = SourceText.codeOnly(try text(Self.instanceLine))
        XCTAssertTrue(instance.contains("fact(\"Style\", genre.displayName)"),
                      "the instance line under the Style row names the genre with the row's word")
        XCTAssertFalse(instance.contains("fact(\"Genre\""), "two words for one thing on one surface (rule 1)")

        let strings = try catalogStrings()
        XCTAssertEqual(german(of: "Style", in: strings), "Stil", "the row reads „Stil“ in German")
        XCTAssertNotNil(german(of: "The style the Echoel instrument composes in. The piece keeps it", in: strings),
                        "the row's hint has its German line")
    }

    // MARK: 3 — counterweights: the funnel behind the door is intact

    func testTheStyleStillReachesTheInstrument() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspector))
        XCTAssertTrue(inspector.contains("set: { TrackMix.pickEchoelGenre($0, timeline: timeline) }"),
                      "the row writes through the one pick function")
        XCTAssertTrue(inspector.contains("timeline.setEchoelGenre(genre)"), "which writes the song once")
        XCTAssertTrue(inspector.contains("ForEach(MusicStyle.Subcategory.allCases) { shelf in"),
                      "the row offers the curated shelves — the root `GenreSubcategoryTests` pins")
        XCTAssertTrue(inspector.contains("if controls.genre {"), "the row is still mounted in the inspector")

        let studio = SourceText.codeOnly(try text(Self.studio))
        XCTAssertTrue(studio.contains("case \"echoelGenre\":"), "the instrument still listens for the device's style")
        XCTAssertTrue(studio.contains("adoptEchoelGenreFromSong(announce: true)"),
                      "and adopts it with the full genre semantics")

        let app = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(app.contains("NotificationCenter.default.post(name: .echoelCompositionEdited, object: \"genre\")"),
                      "the OSC cue `/echoelmusic/ctrl/genre` still reaches the instrument's funnel")

        let store = SourceText.codeOnly(try text(Self.store))
        XCTAssertTrue(store.contains("let midiLane = TimelineLane(name: \"MIDI 1\", kind: .midi)"),
                      "the default document still seeds the MIDI lane the Echoel row lives on — without it the style has no door")
    }

    // MARK: helpers

    private func catalogStrings() throws -> [String: Any] {
        let data = Data(try text(Self.catalog).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let strings = root?["strings"] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: the catalog has no `strings` table (#454)")
            return [:]
        }
        return strings
    }

    private func german(of key: String, in strings: [String: Any]) -> String? {
        let entry = strings[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any]
        let de = localizations?["de"] as? [String: Any]
        let unit = de?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
