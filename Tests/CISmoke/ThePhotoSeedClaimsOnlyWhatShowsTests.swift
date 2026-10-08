// ThePhotoSeedClaimsOnlyWhatShowsTests.swift
// Echoel — GMMW VV-2 ("the card claims only what shows"). A photo's contrast sets the visual's
// Detail, and Detail reaches the picture in exactly two ways: the donut renderer draws it as its
// band count, and the Metal field reads it through the Rings look only (`LookBlendMap.detailReach`).
// Rings is not one of the slider's shipped looks, so on a fresh install the photo card listed
// "Detail 40 → 78" and spoke of "contrast" for a change nobody could see. The card now asks
// whether Detail can show — Rings among the slider's looks, or donuts on — and only then shows the
// Detail line and names contrast. The photo still WRITES Detail (add Rings later and it shows;
// Undo takes it back with the rest); what changed is what the card promises.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END (`LookBlendMap`, `PhotoSeedText`): the reachable-set question agrees with the
//    renderer's mirror for every one-look sequence, edge indices included, and answers for the
//    whole sequence; the card's predicate reads the STORED sequence through the slider's own
//    parser (garbage plays the default) and counts the donut renderer.
// 2. END-TO-END (`PhotoSeedText`): three lines without Detail, four with it, in the Visual panel's
//    order; the two spoken hints drop "contrast" / "detail" exactly when Detail cannot show.
//    COUNTERWEIGHT (#343): the photo still changes Detail, so the four-line case is a real change.
// 3. SOURCE-TEXT SCAN (the card is a `View` no test renders): the card asks the ONE predicate,
//    hands its answer to all three wordings, reads the two keys with the Studio's own defaults, and
//    holds no second copy of the Rings rule (#416); `sequenceReachesDetail` asks the mirror.
//
// HONEST GRADING (§3). The file does not COMPILE on its parent (`596e7cf`): it names
// `LookBlendMap.sequenceReachesDetail`, `PhotoSeedText.detailShows`, `chooseHint`, `applyHint` and
// the `detailShows:` label, all created by this commit — no assertion has a verdict there; claims
// 1–3 are FORWARD guards (one absence, #486). Transcribed into Python (the parser, the mirror, the
// line builder, the hint choice and the card scan) and driven on the worktree: green. MUTANTS, each
// red for its named reason: `sequenceReachesDetail` as `contains(ringsStyleIndex)` (claim 1 at
// index −1, claim 3's mirror scan) · `detailShows` ignoring donuts (claim 1) · the Detail line
// always built (claim 2) · a hint that never switches (claim 2) · the card handing a literal
// `detailShows: true` to `changes` (claim 3, two answers instead of three). NOT pinned: whether a
// seed actually moves Detail far enough to see — that is MediaSeedLook's mapping, not this claim.
// DEVICE PROBE, open: with Rings off, the card shows three lines and VoiceOver's hints omit
// contrast/detail; with Rings added under "Slider looks", the fourth line appears.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePhotoSeedClaimsOnlyWhatShowsTests: XCTestCase {

    private struct AnchorMissing: Error {}

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    /// The text between the braces that open after `head`, brace-matched (#408/#454).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing()
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing()
    }

    private func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    // MARK: 1 — the reachable-set question is the renderer's mirror, asked of the stored sequence

    func testDetailShowsWhenRingsIsReachableOrDonutsArePlaying() {
        for index in [-1, 0, 2, 3, 5, 7, 9] {
            let reaches: Bool = LookBlendMap.detailReach(style: index, styleB: index, blend: 0) > 0.001
            XCTAssertEqual(LookBlendMap.sequenceReachesDetail([index]), reaches,
                           "look \(index): the reachable-set answer agrees with the renderer's mirror")
        }
        XCTAssertFalse(LookBlendMap.sequenceReachesDetail([3, 5, 7]), "Water · Aurora · Depth never draw Rings")
        XCTAssertTrue(LookBlendMap.sequenceReachesDetail([0, 3, 5, 7]), "the slider can be dragged onto Rings")
        XCTAssertTrue(LookBlendMap.sequenceReachesDetail([7, 0]), "anywhere in the sequence, not only first")
        XCTAssertFalse(LookBlendMap.sequenceReachesDetail([]))

        XCTAssertFalse(PhotoSeedText.detailShows(sliderLooks: "3,5,7", donuts: false))
        XCTAssertTrue(PhotoSeedText.detailShows(sliderLooks: "0,3,5,7", donuts: false))
        XCTAssertTrue(PhotoSeedText.detailShows(sliderLooks: "3,5,7", donuts: true),
                      "the donut renderer draws Detail as its band count, whatever the looks")
        XCTAssertEqual(PhotoSeedText.detailShows(sliderLooks: "garbage", donuts: false),
                       LookBlendMap.sequenceReachesDetail(LookBlendMap.defaultSequence),
                       "a stored value the slider cannot read plays the default — the card asks the same")
    }

    // MARK: 2 — three lines without Detail, four with it; the hints follow

    func testTheCardListsDetailAndNamesContrastOnlyWhereItShows() {
        let before = VisualLookSnapshot(intensity: 1, detail: 40, motion: 1, spread: 1, hue: 0, saturation: 1.05,
                                        presetID: "vapor")
        let photo = MediaSeed(version: MediaSeed.formatVersion, hue: 0.5, dominantRed: 0, dominantGreen: 0,
                              dominantBlue: 0, brightness: 0.5, saturation: 0.5, contrast: 0.9,
                              hasDominantColour: true, sampledPixels: 1)
        let after = before.applying(photo)
        XCTAssertNotEqual(after.detail.rounded(), before.detail.rounded(),
                          "COUNTERWEIGHT: the photo still writes Detail — hiding the line hides a promise, not a write")

        let hidden = PhotoSeedText.changes(from: before, to: after, detailShows: false)
        XCTAssertEqual(hidden.count, 3)
        XCTAssertEqual(hidden.filter { $0.hasPrefix("Detail ") }.count, 0, "no Detail line while it cannot show")
        let hiddenOrder: [Bool] = zip(hidden, ["Intensity ", "Hue ", "Saturation "]).map { $0.hasPrefix($1) }
        XCTAssertEqual(hiddenOrder, [true, true, true], "the Visual panel's order, Detail left out")

        let shown = PhotoSeedText.changes(from: before, to: after, detailShows: true)
        XCTAssertEqual(shown.count, 4)
        let shownOrder: [Bool] = zip(shown, ["Intensity ", "Detail ", "Hue ", "Saturation "]).map { $0.hasPrefix($1) }
        XCTAssertEqual(shownOrder, [true, true, true, true])
        XCTAssertTrue(shown.dropFirst().first?.contains("→") ?? false, "where it shows, the Detail line names a real change")

        XCTAssertFalse(PhotoSeedText.chooseHint(detailShows: false).contains("contrast"),
                       "contrast's one target is Detail — not named while Detail cannot show")
        XCTAssertTrue(PhotoSeedText.chooseHint(detailShows: true).contains("contrast"))
        XCTAssertFalse(PhotoSeedText.applyHint(detailShows: false).contains("detail"))
        XCTAssertTrue(PhotoSeedText.applyHint(detailShows: true).contains("detail"))
        for shows in [false, true] {
            XCTAssertTrue(PhotoSeedText.chooseHint(detailShows: shows).contains("colour"), "the colour always shapes")
            XCTAssertTrue(PhotoSeedText.applyHint(detailShows: shows).contains("hue"), "the hue is always set")
        }
    }

    // MARK: 3 — the card asks the one predicate; the predicate asks the mirror

    func testTheCardAsksOnePredicateAndKeepsNoCopyOfTheRingsRule() throws {
        let file = try code("Sources/Echoelmusic/Studio/PhotoSeedCard.swift")
        let card = try member("struct PhotoSeedCard: View", in: file)
        XCTAssertEqual(count("PhotoSeedText.detailShows(sliderLooks: sliderLooksRaw, donuts: spectralDonuts)", in: card), 1,
                       "the card derives its answer once")
        XCTAssertEqual(count("detailShows: detailShows", in: card), 3,
                       "the one answer reaches all three wordings: the lines, the header hint, the Apply hint")
        XCTAssertEqual(count("detailShows: true", in: card) + count("detailShows: false", in: card), 0,
                       "no wording is handed a constant")
        XCTAssertTrue(card.contains("@AppStorage(LookBlendMap.storageKey)"))
        XCTAssertTrue(card.contains("private var sliderLooksRaw = LookBlendMap.string(from: LookBlendMap.defaultSequence)"),
                      "the Studio's own default for the looks (#227)")
        XCTAssertTrue(card.contains("@AppStorage(StudioDefaultKeys.visualSpectralDonuts.key)"))
        XCTAssertTrue(card.contains("private var spectralDonuts = StudioDefaultKeys.visualSpectralDonuts.value"))
        for literal in ["Choose a photo;", "Sets the visuals'"] {
            XCTAssertEqual(count(literal, in: card), 0, "the card spells `\(literal)` itself instead of asking PhotoSeedText")
        }
        for copy in ["ringsStyleIndex", "rendersAsRings", "detailReach("] {
            XCTAssertFalse(file.contains(copy), "PhotoSeedCard keeps its own copy of the Rings rule: `\(copy)` (#416)")
        }

        let looks = try code("Sources/Echoelmusic/Studio/LookBlendMap.swift")
        let reaches = try member("static func sequenceReachesDetail(", in: looks)
        XCTAssertTrue(reaches.contains("rendersAsRings"), "the reachable set asks the renderer's mirror")
        XCTAssertFalse(reaches.contains("ringsStyleIndex") || reaches.contains("== 0"),
                       "an equality test is not the mirror — the shader draws every index at or below 0 as Rings")
    }
}
