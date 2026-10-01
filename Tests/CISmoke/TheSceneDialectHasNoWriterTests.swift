//
//  TheSceneDialectHasNoWriterTests.swift
//  Echoelmusic — CISmoke (BLOCKING bundle)
//
//  THE FINDING (#745). `ADMOSCSender.sceneDialect` is a three-way choice of OSC
//  wire format — ADM-OSC polar, ADM-OSC Cartesian, IEM MultiEncoder — that is
//  fully implemented in `SpatialSceneOSCFormatter`, golden-file tested, READ on
//  the live send path, and written by NOTHING in `Sources/`. Measured with
//  comments stripped: the name occurs twice in code, both inside
//  `ADMOSCSender.swift` (the declaration and the read). Two of the three
//  dialects can never reach a wire.
//
//  WHY IT WAS *NOT* DOORED IN THE SAME COMMIT (#745): the branch that reads it
//  sat behind `streamsScene`, whose only writer was a `Toggle` in the doorless
//  `ImmersiveStageView` — SECOND-ORDER doorless, so a picker would have been a
//  control nobody can open.
//  ⛔ SINCE C4a THAT PREMISE IS GONE: Routing's "Every track as its own object
//  (ADM-OSC)" switch (`PatchbayView.admSceneStreamRow`) is a second, REACHABLE
//  writer of `streamsScene`. The dialect is now the `AutoMixChain.preset` (#736)
//  shape — a live choice with no control — and stays a constant on purpose for
//  one slice: both labels that arm the branch name ADM-OSC, the one dialect that
//  can happen. The picker is the next slice; claims 1 and 8 are its notification.
//
//  ⚠️ THIS GUARD FORBIDS NOTHING (#364). Claims 1, 4 and 5 go red the day a door
//  IS built — that red is the notification, not the verdict, and each message
//  names the prose to move in the same commit (#456).
//
//  GRADING — ONE EPOCH, this tree (parent of #745). Every claim was transcribed
//  into Python and run against the worktree before the push, and each was driven
//  red on a deliberately mutated copy:
//    1 FORWARD      — passes today; red when any other file names `sceneDialect`.
//                     Simulated red by writing the name into a scratch copy of
//                     `EchoelStudioView.swift`'s code region.
//    2 REGRESSION   — red on the parent if the read is removed from `sendIfFresh`.
//    3 REGRESSION   — red if the `if streamsScene` gate goes.
//    4 FORWARD      — red when a FOURTH file names `streamsScene` (C4a admitted
//                     the third, Routing; it was red on that tree until it did).
//    5 FORWARD      — red when `ImmersiveStageView(` gains a construction site.
//    6 COUNTERWEIGHT — red if the two unreachable dialect cases are "cleaned up".
//                     This is the content, not decoration (#343): without it the
//                     cheapest way to satisfy claims 1–5 forever is to delete the
//                     capability the identity line's immersive pillar is aimed at.
//    7 REGRESSION   — red if either ⛔ retraction is deleted ("kept the LINE, lost
//                     the FACT").
//    8 COUNTERWEIGHT — the stage toggle still names ADM-OSC, the one dialect that
//                     can happen. Widening it is CORRECT work; the message says so.
//  Ten mutants were run (claims 6 and 7 twice, once per needle); each turned
//  EXACTLY its own claim red and left the other seven green.
//
//  ⛔ AND THE MUTATION HARNESS LIED TWICE BEFORE IT TOLD THE TRUTH — recorded
//  because the fix is not obvious and the failure looked like a passing run:
//    · It listed `Sources/` ONCE, before creating the mutant file. Claims 1, 4 and
//      5 are FORWARD claims about "some OTHER file names X", so a cached file list
//      cannot see the file the mutant just added: all three reported "no red" and
//      would have been signed off as unfalsifiable. Walk the tree INSIDE the check,
//      every time — the same reason claim 1 walks rather than greps a fixed list.
//    · The first claim-6 mutant renamed `case admOSCCartesian` to
//      `…CartesianXX`, and the needle is a SUBSTRING, so the rename changed
//      nothing the assertion could see. A mutation that the assertion cannot
//      distinguish from the original is not a mutation; delete the line instead.
//    Both are the #739 shape one level up: a control its own known-positive passes
//    is not a control, and that applies to the harness, not only to the guard.
//
//  STRIPPER LABEL — MEASURED, not assumed (#453/#477), and the SCOPE is stated
//  because a count without one is not reproducible. Unit = 8 claims / 10 needles.
//  Each needle was counted raw and comments-stripped in the file its own claim
//  reads. Only claim 7's two needles are comment-only (raw 1 / code 0 each) —
//  it reads RAW on purpose, because its needles ARE the retraction text. Every
//  other needle's match is code (identical raw and stripped counts), so prose
//  cannot satisfy it. TRAGEND = 1 of 8 claims (2 of 10 needles).
//
//  ⚠️ THE LIMIT FIRST. This proves no line in `Sources/` can choose a dialect, and
//  that the prose agrees. It proves NOTHING about whether the Cartesian or IEM
//  bytes are correct on a real renderer — that is a device probe with hardware
//  nobody here has.
//

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSceneDialectHasNoWriterTests: XCTestCase {

    private struct DialectAnchorMissing: Error, CustomStringConvertible {
        let reason: String
        var description: String { "scene-dialect anchor missing: \(reason)" }
    }

    private static let senderRelative = "Echoelmusic/Sync/ADMOSCSender.swift"
    private static let stageRelative = "Echoelmusic/Studio/ImmersiveStageView.swift"
    private static let formatterRelative = "Echoelmusic/Sync/SpatialSceneOSC.swift"
    private static let routingRelative = "Echoelmusic/Studio/PatchbayView.swift"
    private static let sender = "Sources/" + senderRelative
    private static let stage = "Sources/" + stageRelative
    private static let formatter = "Sources/" + formatterRelative

    // MARK: - 1: THE FINDING — nothing outside the declaring file names the dialect

    func testNothingOutsideTheSenderNamesTheSceneDialect() throws {
        let others: [String] = try filesNaming("sceneDialect", excluding: [Self.senderRelative])
        XCTAssertTrue(others.isEmpty, """
            `sceneDialect` is now named outside `ADMOSCSender.swift`, in: \
            \(others.joined(separator: ", ")).

            That is GOOD NEWS if it is a real picker — this guard does NOT forbid building \
            one (#364); its red is what tells you one was built. It fires on a mere READ too, \
            deliberately: a needle list of write shapes misses `$sender.sceneDialect`, the \
            `@Bindable` form the existing `streamsScene` toggle already uses and therefore \
            the likeliest door of all. The repair is not to relax this — move the ⛔ block \
            above the declaration in `ADMOSCSender.swift` and the header block in \
            `SpatialSceneOSC.swift` in the SAME commit (#456), and widen the toggle label \
            claim 8 pins.
            """)
    }

    // MARK: - 2: the read is real — this is a live property, not a leftover

    func testTheSendPathStillReadsTheDialect() throws {
        let code: String = try codeOf(Self.sender)
        XCTAssertTrue(code.contains("dialect: sceneDialect"), """
            `sendIfFresh` no longer passes `sceneDialect` to `send(scene:dialect:)` in \
            \(Self.sender).

            Without that read the property is not "doorless", it is DEAD — a different \
            finding with a different repair (delete it, do not door it). Either way the ⛔ \
            block above the declaration is now wrong and is the work.
            """)
    }

    // MARK: - 3: the gate is real — the read sits behind the parked flag

    func testTheDialectReadSitsBehindTheStreamFlag() throws {
        let code: String = try codeOf(Self.sender)
        XCTAssertTrue(code.contains("if streamsScene {"), """
            `sendIfFresh` no longer gates the scene branch on `streamsScene` in \(Self.sender).

            The whole "Release stays bit-identical" argument in `SpatialSceneOSC.swift`'s \
            header rests on that gate being closed by default. If the branch now runs \
            unconditionally, the bio→object path and the scene path both address \
            `/adm/obj/1` and collide — and the dialect stops being unreachable, so it needs \
            a picker after all.
            """)
    }

    // MARK: - 4: the flag's writers are the parked stage and the Routing switch (C4a)

    func testOnlyTheStageAndTheRoutingSwitchNameTheStreamFlag() throws {
        let others: [String] = try filesNaming(
            "streamsScene",
            excluding: [Self.senderRelative, Self.stageRelative, Self.routingRelative])
        XCTAssertTrue(others.isEmpty, """
            `streamsScene` is now named outside `ADMOSCSender.swift`, \
            `ImmersiveStageView.swift` and `PatchbayView.swift`, in: \
            \(others.joined(separator: ", ")).

            Since C4a the scene stream is armed from Routing, so `sceneDialect` is already a \
            live choice with no control (the `AutoMixChain.preset` #736 shape). A THIRD writer \
            is a second door to the same flag — and two switches for one value is how a \
            relaunch and a live edit come to disagree. Check whether the new site should be a \
            door to the EXISTING switch instead (#472: trace it to a rendering parent first), \
            and move this claim's excludes together with claim 3 of \
            `TheTrackObjectsFollowThePieceAndHaveASwitchTests` in the same commit (#456).
            """)
    }

    // MARK: - 5: the stage really is doorless

    func testTheImmersiveStageStillHasNoConstructionSite() throws {
        let sites: [String] = try filesNaming("ImmersiveStageView(", excluding: [Self.stageRelative])
        XCTAssertTrue(sites.isEmpty, """
            `ImmersiveStageView` is now constructed in: \(sites.joined(separator: ", ")).

            This guard does NOT forbid that (#364) — ship-gate 4 calls light/space \
            "demonstrable", and mounting the stage is exactly how it becomes demonstrable. \
            Since C4a `sceneDialect` is already reachable without a control (Routing arms \
            the branch); a mounted stage is a SECOND door to it. Build the picker once, widen \
            BOTH labels that name ADM-OSC (claim 8's and the Routing switch's), and rewrite \
            the ⛔ blocks in `ADMOSCSender.swift` and `SpatialSceneOSC.swift` in the SAME \
            commit (#456).
            """)
    }

    // MARK: - 6: COUNTERWEIGHT — the unreachable dialects are not tidy-up material

    func testTheTwoUnreachableDialectsStillExist() throws {
        let code: String = try codeOf(Self.formatter)
        for needle in ["case admOSCCartesian", "case iemMultiEncoder(plugin: String)"] {
            XCTAssertTrue(code.contains(needle), """
                `\(needle)` is gone from \(Self.formatter).

                Deleting the unreachable dialects is the cheapest way to make claims 1–5 \
                true forever, and it would cost the thing the immersive pillar is FOR: \
                Cartesian-only consoles and the IEM suite are named rigs, not hypotheticals. \
                If this was a deliberate scope cut, say so at the enum and in \
                `SpatialSceneOSC.swift`'s header — do not let a guard's silence stand in \
                for the decision.
                """)
        }
    }

    // MARK: - 7: the two retractions are still on record (reads RAW on purpose)

    func testBothRetractionsAreStillOnRecord() throws {
        let senderRaw: String = try rawText(Self.sender)
        XCTAssertTrue(senderRaw.contains("SECOND-ORDER DOORLESS"), """
            The ⛔ block above `sceneDialect` is gone from \(Self.sender).

            If a picker was built it SHOULD change — but then claim 1 is red in this same run \
            and the replacement text is the work. If it was merely deleted, nothing records \
            that two of three dialects cannot reach a wire, and the next session reads a \
            configurable property that is not configurable.
            """)
        let formatterRaw: String = try rawText(Self.formatter)
        XCTAssertTrue(formatterRaw.contains("NO CALLERS YET"), """
            The ⛔ header retraction is gone from \(Self.formatter).

            It records that the header's old "no callers yet" reason was measured false while \
            its CONCLUSION held (#402). Losing it invites the next session to re-derive the \
            same wrong reason from the same paragraph.
            """)
    }

    // MARK: - 8: COUNTERWEIGHT — the toggle names the one dialect that can happen

    func testTheStageToggleStillNamesTheOneReachableDialect() throws {
        let code: String = try codeOf(Self.stage)
        XCTAssertTrue(code.contains("Stream to renderer (ADM-OSC)"), """
            The stage toggle no longer names ADM-OSC in \(Self.stage).

            WIDENING that label is CORRECT work once a picker exists — this claim exists so \
            the label and the picker move together, not to freeze the copy. If you widened \
            it, claim 1 should be red in the same run; if it is not, the label now promises \
            a choice the app cannot make.
            """)
    }

    // MARK: - helpers

    /// Files under `Sources/` whose code (comments stripped) names `needle`, excluding the
    /// given relative paths by EXACT match — `hasSuffix` would also excuse a future
    /// `LegacyADMOSCSender.swift` anywhere in the tree.
    private func filesNaming(_ needle: String, excluding: [String]) throws -> [String] {
        let base = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw DialectAnchorMissing(reason: "cannot walk Sources/")
        }
        var hits: [String] = []
        var seen = 0
        var sawExcluded: Set<String> = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            seen += 1
            if excluding.contains(rel) {
                sawExcluded.insert(rel)
                continue
            }
            let text: String = SourceText.codeOnly(
                try String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8))
            if text.contains(needle) { hits.append(rel) }
        }
        guard seen > 200 else {
            throw DialectAnchorMissing(reason: """
                only \(seen) Swift files walked under Sources/; the tree holds well over three \
                hundred, so this walk saw a partial checkout and would report a green it did \
                not earn (#454)
                """)
        }
        let missing = excluding.filter({ !sawExcluded.contains($0) })
        guard missing.isEmpty else {
            throw DialectAnchorMissing(reason: """
                \(missing.joined(separator: ", ")) was not among the \(seen) files walked — it \
                moved or was renamed. This FAILS rather than skips: a rename would otherwise \
                leave this claim reporting "no writers" for state that still exists (#454)
                """)
        }
        return hits.sorted()
    }

    private func codeOf(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawText(relativePath))
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw DialectAnchorMissing(reason: """
                \(relativePath) is not present while `Sources/` is — the anchor moved. A \
                missing TREE skips (see `repoRoot`); a missing ANCHOR fails (#454)
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
