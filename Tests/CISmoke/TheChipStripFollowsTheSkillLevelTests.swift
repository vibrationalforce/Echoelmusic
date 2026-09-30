// TheChipStripFollowsTheSkillLevelTests.swift
// Echoel — interface audit 2026-09-30, "SkillLevel anschließen: Einsteiger = drei Chips".
// `SkillLevel` (Core) existed with ZERO readers: three levels, two monotone gates, a picker
// blurb, and nothing changed when you switched it. Its first consumer is the Instrument stage's
// chip strip: `EchoelStudioView.chips(for:)` filters the standing `studioChips` by the level the
// user picked in Save & Export — Beginner = Sound · Mood · Save/Export, Producer adds FX · Mix ·
// Tempo · Field · Workstation, Pro adds Master.
//
// ⛔ THE LAW THIS FILE MUST NOT UNDO. #568 thinned the strip to one chip for the first three
// launches and the founder rejected it on device ("Du hast mega viel gelöscht", #572); the
// strip's own doc says "do NOT re-introduce a maturity-gated strip without a founder ask". A
// level the USER picks, persisted, with default `.pro` (= the whole strip) is not that: a fresh
// install sees exactly what it saw before this key existed. Claim 1 pins that default as the
// decision it is.
//
// WHAT THIS GUARDS.
//   1. END-TO-END: the key's default is `.pro` and round-trips; the two gates are monotone and
//      Beginner passes neither (the essentials are unconditional in the filter, not gated).
//   2. SOURCE: the strip reads the persisted level (unknown raw → the default, never thinner),
//      `chips(for:)` is a FILTER over `studioChips` whose three unconditional cases are exactly
//      Sound · Mood · Save/Export, whose Producer cases are the five, whose Pro case is Master;
//      `visibleChips` takes that filtered strip and still appends the displayed menu.
//   3. SOURCE: the door — `skillLevelRow` is built once in `utilityRow`, is a segmented
//      `Picker` over `SkillLevel.allCases` bound to the key, and `.export` (its host) is one of
//      the three unconditional chips, so the switch can never hide itself.
//   4. COUNTERWEIGHTS (#343): the standing `studioChips` array is unchanged and `.bio` is still
//      not in it (#290); the filter takes a LEVEL and reads no launch count or clock (#572).
//
// ⚠️ LIMIT. Claims 2–4 are source text; nothing here renders the strip. That Beginner reads as a
// calm three and not as "lost features" is a founder call on device — the reason the default is
// not Beginner.
//
// ⚠️ GRADING (§3): claims 1 and 4's gate half are green on both trees (the type existed). On
// the parent `StudioDefaultKeys.skillLevel` does not exist — claim 1's default assertion cannot
// compile (ONE absence, #486); claims 2–3 are the needles born here, red together; claim 4's
// array and `.bio` pins are counterweights, green on both. Transcribed in Python: WORK all
// green; parent = one absence + the born needles.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheChipStripFollowsTheSkillLevelTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: 1 — the default is the whole strip

    func testTheDefaultLevelIsProAndTheGatesAreMonotone() {
        XCTAssertEqual(StudioDefaultKeys.skillLevel.value, .pro,
                       "a fresh install must see the whole strip — a thinned first impression was rejected on device (#572)")
        XCTAssertEqual(StudioDefaultKeys.skillLevel.key, "studio.skillLevel")
        XCTAssertEqual(SkillLevel(rawValue: StudioDefaultKeys.skillLevel.value.rawValue), .pro)
        XCTAssertEqual(SkillLevel.allCases, [.beginner, .producer, .pro])
        XCTAssertFalse(SkillLevel.beginner.showsSongs)
        XCTAssertFalse(SkillLevel.beginner.showsProTabs)
        XCTAssertTrue(SkillLevel.producer.showsSongs)
        XCTAssertFalse(SkillLevel.producer.showsProTabs)
        XCTAssertTrue(SkillLevel.pro.showsSongs && SkillLevel.pro.showsProTabs)
    }

    // MARK: 2 — the strip is a filter over the standing list, by the persisted level

    func testTheStripFiltersTheStandingChipsByThePersistedLevel() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("@AppStorage(StudioDefaultKeys.skillLevel.key)"),
                      "the studio reads the ONE persisted level (H15-KEYSTORE)")
        XCTAssertTrue(code.contains("SkillLevel(rawValue: skillLevelRaw) ?? StudioDefaultKeys.skillLevel.value"),
                      "an unknown raw value resolves to the default — the whole strip, never a thinner one by accident")
        let filter = try body(from: "private static func chips(for level: SkillLevel) -> [StudioMenu] {",
                              to: "private var visibleChips: [StudioMenu] {", in: code)
        XCTAssertTrue(filter.contains("studioChips.filter { menu in"),
                      "the level FILTERS the standing strip — never a second list, so the order stays the signal chain")
        XCTAssertTrue(filter.contains("case .sound, .mood, .export:") && filter.contains("return true"),
                      "Beginner's three are unconditional: Sound · Mood · Save/Export")
        XCTAssertTrue(filter.contains("case .effects, .mix, .composition, .field, .workstation:")
                      && filter.contains("return level.showsSongs"),
                      "Producer adds the five shaping and song-building chips through the `showsSongs` gate")
        XCTAssertTrue(filter.contains("case .master:") && filter.contains("return level.showsProTabs"),
                      "Pro adds Master through the `showsProTabs` gate")
        let visible = try body(from: "private var visibleChips: [StudioMenu] {",
                               to: "@State private var chipStripHasMoreTrailing", in: code)
        XCTAssertTrue(visible.contains("let strip = Self.chips(for: skillLevel)"),
                      "the strip on screen is the filtered one")
        XCTAssertTrue(visible.contains("strip.contains(displayedMenu) ? strip : strip + [displayedMenu]"),
                      "the displayed menu is still appended — a chip the level hides is removed from the BAR, never from the app")
    }

    // MARK: 3 — the door, and why it cannot hide itself

    func testTheLevelPickerLivesInSaveAndExportAndCannotHideItself() throws {
        let code = try source(Self.studio)
        let plate = try body(from: "private var utilityRow: some View {",
                             to: "private var skillLevelRow: some View {", in: code)
        XCTAssertEqual(plate.components(separatedBy: "skillLevelRow").count - 1, 1,
                       "Save & Export builds the level row exactly once")
        let row = try body(from: "private var skillLevelRow: some View {",
                           to: "private var soundResetRow: some View {", in: code)
        XCTAssertTrue(row.contains("Picker(\"Chips on the strip\", selection: $skillLevelRaw)"),
                      "the picker binds the persisted key — one writer")
        XCTAssertTrue(row.contains("ForEach(SkillLevel.allCases)") && row.contains(".tag(level.rawValue)"),
                      "every level is offered, tagged by its raw value")
        XCTAssertTrue(row.contains(".pickerStyle(.segmented)"), "a named choice is a segmented picker, not a number field")
        XCTAssertTrue(row.contains(".accessibilityLabel(\"How much of the strip you see\")"))
        XCTAssertTrue(row.contains("Text(skillLevel.blurb)"), "the chosen level says what it shows")
        XCTAssertFalse(row.contains("Slider(") || row.contains("EchoelValueField("),
                       "a level is a name, not a quantity")
        // `.export` hosts the picker and is unconditional in the filter (claim 2) — restated
        // here as the property that matters: the switch is reachable at every level.
        let filter = try body(from: "private static func chips(for level: SkillLevel) -> [StudioMenu] {",
                              to: "private var visibleChips: [StudioMenu] {", in: code)
        XCTAssertTrue(filter.contains("case .sound, .mood, .export:"),
                      "`.export` must stay unconditional — it is the chip the level picker lives behind")
    }

    // MARK: 4 — counterweights: the standing list, the pill's door, no clock

    func testTheStandingStripAndThePillDoorAreUntouchedAndNoClockThinsTheStrip() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("[.sound, .effects, .mix, .master, .mood, .composition, .field, .workstation, .export]"),
                      "the standing `studioChips` array is unchanged — the level filters it, it does not replace it")
        let head = try body(from: "private static let studioChips: [StudioMenu] =",
                            to: "private static func chips(for level: SkillLevel)", in: code)
        XCTAssertFalse(head.contains(".bio"), "`.bio` is still not a chip — the pulse pill is its door (#290)")
        let filter = try body(from: "private static func chips(for level: SkillLevel) -> [StudioMenu] {",
                              to: "private var visibleChips: [StudioMenu] {", in: code)
        for clock in ["Date(", "launch", "instrumentHintShows", "UserDefaults"] {
            XCTAssertFalse(filter.contains(clock),
                           "the filter reads `\(clock)` — the strip must follow the user's LEVEL, never a launch count or a clock (#572)")
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text between two unique anchors, starting WITH the opening marker.
    private func body(from start: String, to end: String, in code: String) throws -> String {
        guard let s = code.range(of: start), let e = code.range(of: end, range: s.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(start)` → `\(end)` (#454)")
            throw AnchorMissing(name: start)
        }
        return String(code[s.lowerBound..<e.lowerBound])
    }
}
