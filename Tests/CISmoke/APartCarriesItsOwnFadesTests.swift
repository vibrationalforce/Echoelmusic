// APartCarriesItsOwnFadesTests.swift
// Echoel — an audio part carries its own fade-in and fade-out (audio editor W4a, founder
// 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.").
//
// WHY: every DAW fades a part's edges, and a timeline part had nowhere to keep a fade — the only
// fade lengths in the repo lived on `AudioClipRegion`, whose executor has no caller (#1381). W4a
// is the MODEL half: `TimelineRegion.fadeInTicks`/`fadeOutTicks`, ONE envelope rule
// (`FadeEnvelope`, moved out of `AudioClipRegion.fadeMultiplier`, not restated), what split, join
// and combine do with a fade, and the store's one writer. The player reads them from W4b and the
// part bar's fields are the door from W4c — so nothing here claims a fade is HEARD.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — the one rule: linear ramps, "in wins" on overlap, junk lengths are no fade, the
//    level stays finite and inside 0…1 on a grid that includes NaN, ±∞ and out-of-range times;
//    `AudioClipRegion.fadeMultiplier` gives exactly what the rule gives.
// 2. END-TO-END — the model: the initializer and the decoder hold a fade at ≥ 0, a legacy
//    document without the keys decodes with hard edges, and a round trip keeps both.
// 3. END-TO-END — split keeps the fade-in on the left piece and the fade-out on the right, and
//    Join of a clean split gives back the part EXACTLY; a fade at the seam makes Join refuse.
// 4. END-TO-END on the real store — one set is ONE undo step for both lengths; unchanged, unknown
//    or refused input records nothing; the stored lengths are what the part can sound; the
//    store's split, join and combine carry the outer fades.
// 5. SOURCE-TEXT SCAN — the rule is declared once, and both of its users ask it instead of
//    restating it.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `FadeEnvelope`,
// `fadeInTicks` and `setRegionFades`, which this commit creates, so it does NOT COMPILE against
// the parent — no assertion has a verdict there (one absence, #486). Claims 1–4 transcribed in
// Python against the work tree's arithmetic; claim 5 is a forward guard. Whether a fade SOUNDS
// right is W4b's device probe and open.

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class APartCarriesItsOwnFadesTests: XCTestCase {

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    // MARK: 1 — the one rule

    func testTheOneRuleRampsLinearlyAndTheFadeInWins() {
        let g = FadeEnvelope.gain
        XCTAssertEqual(g(0, 4, 2, 0), 0, accuracy: 1e-12, "a fade-in starts silent")
        XCTAssertEqual(g(1, 4, 2, 0), 0.5, accuracy: 1e-12, "and rises linearly")
        XCTAssertEqual(g(2, 4, 2, 0), 1, accuracy: 1e-12, "full at its end")
        XCTAssertEqual(g(3, 4, 0, 2), 0.5, accuracy: 1e-12, "a fade-out falls linearly")
        XCTAssertEqual(g(4, 4, 0, 2), 0, accuracy: 1e-12, "and ends silent")
        XCTAssertEqual(g(2, 4, 0, 2), 1, accuracy: 1e-12, "it starts at duration − fade-out")
        XCTAssertEqual(g(2, 4, 0, 0), 1, accuracy: 1e-12, "no fade is unity")

        let overlap = FadeEnvelope.effective(fadeIn: 3, fadeOut: 3, duration: 2)
        XCTAssertEqual(overlap.fadeIn, 2, "a fade-in longer than the part fills it")
        XCTAssertEqual(overlap.fadeOut, 0, "in wins: nothing is left for the fade-out")
        let shared = FadeEnvelope.effective(fadeIn: 1, fadeOut: 5, duration: 4)
        XCTAssertEqual(shared.fadeIn, 1)
        XCTAssertEqual(shared.fadeOut, 3, "the fade-out gets what the fade-in leaves")

        let junk = FadeEnvelope.effective(fadeIn: .nan, fadeOut: -1, duration: 4)
        XCTAssertEqual(junk.fadeIn, 0, "a non-finite length is no fade")
        XCTAssertEqual(junk.fadeOut, 0, "a negative length is no fade")
        XCTAssertEqual(FadeEnvelope.effective(fadeIn: .infinity, fadeOut: 1, duration: 4).fadeIn, 0)
        let degenerate: [Double] = [0, -1, .nan, .infinity]
        for duration in degenerate {
            let none = FadeEnvelope.effective(fadeIn: 1, fadeOut: 1, duration: duration)
            XCTAssertEqual(none.fadeIn + none.fadeOut, 0, "duration \(duration) leaves room for no fade")
            XCTAssertEqual(g(0.5, duration, 1, 1), 1, "duration \(duration) plays at unity")
        }
        XCTAssertEqual(g(.nan, 4, 2, 0), 0, accuracy: 1e-12, "a non-finite time reads at the start")

        let times: [Double] = [-1, 0, 0.25, 1, 1.5, 2, 2.75, 3.5, 4, 5, .nan, .infinity, -.infinity]
        let lengths: [Double] = [0, 0.5, 1, 2, 3, 5, .nan, -2, .infinity]
        for t in times { for fin in lengths { for fout in lengths {
            let level = g(t, 4, fin, fout)
            XCTAssertTrue(level.isFinite && level >= 0 && level <= 1,
                          "level \(level) at t=\(t), in=\(fin), out=\(fout) left 0…1")
        } } }
    }

    func testTheClipFadeIsTheSameRule() {
        let grid: [Double] = [0, 0.1, 0.5, 1, 1.9, 2, 2.5, 3.2, 4]
        for fin in [0.0, 1, 2.5, 6] { for fout in [0.0, 1, 3, 6] {
            let clip = AudioClipRegion(startSeconds: 1, endSeconds: 5, fadeInSeconds: fin, fadeOutSeconds: fout)
            for t in grid {
                XCTAssertEqual(clip.fadeMultiplier(atElapsed: t),
                               Float(FadeEnvelope.gain(atElapsed: t, duration: 4, fadeIn: fin, fadeOut: fout)),
                               "the clip's fade and the rule disagree at t=\(t), in=\(fin), out=\(fout)")
            }
        } }
    }

    // MARK: 2 — the model holds a fade at ≥ 0 and a legacy part has none

    func testThePartStoresItsFadesAndALegacyPartHasNone() throws {
        let clamped = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                     fadeInTicks: -5, fadeOutTicks: -1)
        XCTAssertEqual(clamped.fadeInTicks, 0, "a negative fade-in is stored as none")
        XCTAssertEqual(clamped.fadeOutTicks, 0, "a negative fade-out is stored as none")
        let plain = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680)
        XCTAssertEqual(plain.fadeInTicks + plain.fadeOutTicks, 0, "a new part starts with hard edges")

        let part = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 960, lengthTicks: 7_680,
                                  fadeInTicks: 960, fadeOutTicks: 1_920)
        let data = try JSONEncoder().encode(part)
        XCTAssertEqual(try JSONDecoder().decode(TimelineRegion.self, from: data), part, "a round trip keeps both")
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("a part did not encode as a JSON object")
        }
        XCTAssertEqual(object["fadeInTicks"] as? Int, 960, "the fade-in is written under its key")
        XCTAssertEqual(object["fadeOutTicks"] as? Int, 1_920, "the fade-out is written under its key")
        object.removeValue(forKey: "fadeInTicks")
        object.removeValue(forKey: "fadeOutTicks")
        let legacy = try JSONDecoder().decode(TimelineRegion.self,
                                              from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.fadeInTicks + legacy.fadeOutTicks, 0, "a part saved before W4a has hard edges")
        XCTAssertEqual(legacy.lengthTicks, part.lengthTicks, "and nothing else of it is lost")
        object["fadeInTicks"] = -40
        object["fadeOutTicks"] = -1
        let negative = try JSONDecoder().decode(TimelineRegion.self,
                                                from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(negative.fadeInTicks + negative.fadeOutTicks, 0, "a negative stored fade decodes as none")
    }

    // MARK: 3 — split keeps the outer fades; Join of a clean split is exact; a seam fade refuses

    func testSplitKeepsTheOuterFadesAndJoinGivesThePartBack() {
        let part = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                  fadeInTicks: 960, fadeOutTicks: 1_920)
        guard let (left, right) = part.split(at: 3_840, bpm: 120) else {
            return XCTFail("a part did not split at its middle")
        }
        XCTAssertEqual(left.fadeInTicks, 960, "the fade-in stays on the left piece")
        XCTAssertEqual(left.fadeOutTicks, 0, "the cut is a hard edge on the left")
        XCTAssertEqual(right.fadeInTicks, 0, "the cut is a hard edge on the right")
        XCTAssertEqual(right.fadeOutTicks, 1_920, "the fade-out stays on the right piece")
        XCTAssertTrue(left.abuts(right, bpm: 120), "a clean split always rejoins")
        XCTAssertEqual(left.merged(with: right), part, "Join of a clean split is the part again, fades and all")

        var leftFaded = left
        leftFaded.fadeOutTicks = 10
        XCTAssertFalse(leftFaded.abuts(right, bpm: 120), "a fade-out at the seam would vanish — Join refuses")
        var rightFaded = right
        rightFaded.fadeInTicks = 10
        XCTAssertFalse(left.abuts(rightFaded, bpm: 120), "a fade-in at the seam would vanish — Join refuses")

        // Counterweight (#343): a part without fades splits and rejoins exactly as before W4a.
        let plain = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 7_680)
        guard let (a, b) = plain.split(at: 1_000, bpm: 120) else { return XCTFail("a plain part did not split") }
        XCTAssertTrue(a.abuts(b, bpm: 120))
        XCTAssertEqual(a.merged(with: b), plain)
        var louder = b
        louder.gain = 0.5
        XCTAssertFalse(a.abuts(louder, bpm: 120), "Join still refuses halves of different level (CLIP-6)")
    }

    // MARK: 4 — the store: one step for both lengths, stored as they can sound

    func testOneSetIsOneUndoStepAndStoresWhatThePartCanSound() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        func stored() -> (Int, Int)? {
            timeline.document.regions.first { $0.id == part.id }.map { ($0.fadeInTicks, $0.fadeOutTicks) }
        }

        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")
        timeline.setRegionFades(id: part.id, fadeInTicks: 960, fadeOutTicks: 1_920)
        XCTAssertEqual(stored()?.0, 960)
        XCTAssertEqual(stored()?.1, 1_920)
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(stored()?.0, 0, "ONE undo step takes the fade-in back")
        XCTAssertEqual(stored()?.1, 0, "and the fade-out with it")
        XCTAssertFalse(timeline.canUndo, "and it was exactly one")

        timeline.setRegionFades(id: part.id, fadeInTicks: 0, fadeOutTicks: 0)
        XCTAssertFalse(timeline.canUndo, "unchanged lengths record nothing")
        timeline.setRegionFades(id: UUID(), fadeInTicks: 960, fadeOutTicks: 960)
        XCTAssertFalse(timeline.canUndo, "a part that is gone records nothing")
        timeline.setRegionFades(id: part.id, fadeInTicks: -5, fadeOutTicks: Int.min)
        XCTAssertFalse(timeline.canUndo, "negative lengths are no fade — nothing changed, nothing recorded")

        let cases: [(Int, Int, Int, Int)] = [(10_000, 500, 7_680, 0), (-5, 99_999, 0, 7_680),
                                            (5_000, 5_000, 5_000, 2_680), (Int.max, Int.max, 7_680, 0)]
        for (fadeIn, fadeOut, wantIn, wantOut) in cases {
            timeline.setRegionFades(id: part.id, fadeInTicks: fadeIn, fadeOutTicks: fadeOut)
            XCTAssertEqual(stored()?.0, wantIn, "(\(fadeIn), \(fadeOut)) stored fade-in")
            XCTAssertEqual(stored()?.1, wantOut, "(\(fadeIn), \(fadeOut)) stored fade-out — in wins, held to the part")
        }
    }

    func testTheStoresSplitJoinAndCombineCarryTheOuterFades() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                  fadeInTicks: 960, fadeOutTicks: 1_920)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))

        timeline.splitRegion(id: part.id, atTick: 3_840, bpm: 120)
        guard let left = timeline.document.regions.first(where: { $0.id == part.id }),
              let right = timeline.document.regions.first(where: { $0.id != part.id }) else {
            return XCTFail("the store did not split the part")
        }
        XCTAssertEqual([left.fadeInTicks, left.fadeOutTicks, right.fadeInTicks, right.fadeOutTicks],
                       [960, 0, 0, 1_920], "the store's split keeps the outer fades")
        timeline.setRegionFades(id: right.id, fadeInTicks: 10, fadeOutTicks: 1_920)
        XCTAssertFalse(timeline.canMergeRegionWithNext(id: part.id, bpm: 120), "a seam fade refuses Join")
        timeline.setRegionFades(id: right.id, fadeInTicks: 0, fadeOutTicks: 1_920)
        XCTAssertTrue(timeline.canMergeRegionWithNext(id: part.id, bpm: 120))
        timeline.mergeRegionWithNext(id: part.id, bpm: 120)
        XCTAssertEqual(timeline.document.regions, [part], "the store's Join gives the part back exactly")

        let clip = UUID()
        let first = TimelineRegion(laneID: audio.id, clipID: clip, startTick: 0, lengthTicks: 1_920,
                                   fadeInTicks: 100, fadeOutTicks: 50)
        let middle = TimelineRegion(laneID: audio.id, clipID: clip, startTick: 1_920, lengthTicks: 1_920)
        let last = TimelineRegion(laneID: audio.id, clipID: clip, startTick: 5_000, lengthTicks: 1_000,
                                  fadeInTicks: 30, fadeOutTicks: 200)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [first, middle, last]))
        timeline.combineRegions(ids: [first.id, middle.id, last.id])
        guard timeline.document.regions.count == 1, let combined = timeline.document.regions.first else {
            return XCTFail("three parts of one clip did not combine")
        }
        XCTAssertEqual(combined.lengthTicks, 6_000)
        XCTAssertEqual(combined.fadeInTicks, 100, "the combined part starts with the first part's fade-in")
        XCTAssertEqual(combined.fadeOutTicks, 200, "and ends with the LAST part's fade-out, not the first's")
    }

    // MARK: 5 — one rule, asked by both of its users

    func testTheRuleIsDeclaredOnceAndAskedByBothUsers() throws {
        let declarers = try sourceFiles { $0.contains("enum FadeEnvelope") }
        XCTAssertEqual(declarers, ["Sources/Echoelmusic/Sequencer/FadeEnvelope.swift"], "one rule, one home (#416)")

        let clip = try source("Sources/Echoelmusic/Sequencer/AudioClipRegion.swift")
        guard let multiplier = Self.body(after: "public func fadeMultiplier(atElapsed elapsed: Double) -> Float", in: clip) else {
            return XCTFail("ANCHOR MISSING: `AudioClipRegion.fadeMultiplier` (#454)")
        }
        XCTAssertTrue(multiplier.contains("FadeEnvelope.gain("), "the clip's fade no longer asks the rule")
        for restated in ["/ fin", "/ fout", "dur - "] {
            XCTAssertFalse(multiplier.contains(restated), "the clip's fade restates the rule (`\(restated)`)")
        }

        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        guard let setter = Self.body(after: "public func setRegionFades(id: UUID, fadeInTicks: Int, fadeOutTicks: Int)", in: store) else {
            return XCTFail("ANCHOR MISSING: `TimelineStore.setRegionFades` (#454)")
        }
        XCTAssertTrue(setter.contains("FadeEnvelope.effective("), "the store's setter no longer asks the rule")
        XCTAssertTrue(setter.contains("snapshotForUndo()"), "the setter records no undo step")
        XCTAssertEqual(setter.components(separatedBy: "snapshotForUndo()").count - 1, 1, "one step for both lengths")
    }

    // MARK: helpers

    /// The brace-matched body of the first declaration starting with `signature`, or nil.
    private static func body(after signature: String, in code: String) -> String? {
        guard let start = code.range(of: signature),
              let open = code[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }

    private static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: Self.root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }

    /// The `Sources/` files whose code (comments stripped) satisfies `matches`, repo-relative, sorted.
    private func sourceFiles(_ matches: (String) -> Bool) throws -> [String] {
        let base = Self.root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate Sources/ — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8) else {
                continue
            }
            if matches(SourceText.codeOnly(text)) { hits.append("Sources/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
