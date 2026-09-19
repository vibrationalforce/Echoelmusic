//
//  TheSpatialRenderHalfIsNotClaimedLiveTests.swift
//  Echoelmusic — CISmoke (BLOCKING bundle)
//
//  WHY THIS EXISTS (#1379, Deep Function Check 2026-09-19).
//
//  "Space" is one of the five words in the product's own identity line, and the register a
//  session reads before deciding what is safe to delete said seven of its cores were unwired —
//  measured over `Sync/` only. Three identically dead twins sat one directory over in `DSP/`
//  and `Sequencer/`, and TWO LIVE COMMENTS asserted that one of them renders:
//
//    · `Core/SpatialSceneStore.swift:4`  — "the VBAPPanner / BinauralPanner render"
//    · `Audio/AudioEngine.swift:27`      — "with `DSP/BinauralPanner` for the cues"
//
//  Both false. The CONTROL half of the space leg is real and ships — `SpatialSceneStore` →
//  `ADMOSCSender` → `/adm/obj/{n}/*` object positions on the wire. The RENDER half (panning,
//  ambisonic encode, binaural cues) has no production caller at all. That distinction is what
//  store copy and website copy get written from, and an over-claim there is a 2.3 rejection.
//
//  ⭐ THE LAW THIS PINS: an audit inherits the boundaries of its own search path. The
//  2026-09-02 run was correct AND complete — for `Sync/`. It wrote "VIER `Sync/`-Kerne" and was
//  honest; the next reader took it as a total, because the scope lived in the sentence and not
//  in anyone's memory. **Whoever writes a scope into a register line writes down what the scope
//  EXCLUDED.** Cousin of #867 one level up: there a neighbour is claimed without being
//  measured; here a neighbour is silently left out.
//
//  ⚠️ WHAT THIS GUARD DOES NOT DO (#364): it does NOT forbid wiring any of these — that is the
//  EchoelRender path and it is wanted. It goes red on the day one gains a caller, and names the
//  prose to move with it. It does NOT require the files to exist forever, and it does not scan
//  `CLAUDE.md` negatively (#491).
//
//  GRADED BY TRANSCRIPTION (`Tests/CISmoke/CLAUDE.md` §0).
//

import XCTest

final class TheSpatialRenderHalfIsNotClaimedLiveTests: XCTestCase {

    private struct AnchorMissing: Error { let reason: String }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private func productionCode() throws -> [(name: String, code: String)] {
        let sources = repoRoot.appendingPathComponent("Sources")
        guard let walk = FileManager.default.enumerator(at: sources,
                                                        includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "Sources/ is not enumerable — re-anchor, do not skip.")
        }
        let files = walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        guard files.count > 50 else {
            throw AnchorMissing(reason: """
                Only \(files.count) Swift files under Sources/. An absence claim over an empty \
                corpus is not a measurement (#454).
                """)
        }
        return try files.map { ($0.lastPathComponent,
                                SourceText.codeOnly(try String(contentsOf: $0, encoding: .utf8))) }
    }

    // MARK: - Claim 1 — the render half has no production caller, across BOTH directories

    /// The seven are listed together ON PURPOSE. Splitting them by directory is exactly how
    /// three of them stayed invisible for seventeen days.
    func testTheSpatialRenderCoresHaveNoProductionCaller() throws {
        let corpus = try productionCode()

        // (type, the file that declares it — its own file is not a "caller")
        let cores = [("VBAPPanner", "VBAPPanner.swift"),
                     ("AmbisonicsEncode", "AmbisonicsEncode.swift"),
                     ("LightFixtureGroup", "LightFixtureGroup.swift"),
                     ("BioPhaser", "BioPhaser.swift"),
                     ("BinauralPanner", "BinauralPanner.swift"),
                     ("EchoelSpaceReverb", "EchoelSpaceReverb.swift"),
                     ("SpatialAutomationMapping", "SpatialAutomationMapping.swift")]

        for (type, own) in cores {
            let callers = corpus
                .filter { $0.name != own && $0.code.contains(type) }
                .map(\.name)
                .sorted()
            XCTAssertTrue(callers.isEmpty, """
                `\(type)` now has production callers: \(callers.joined(separator: ", ")).
                That is the EchoelRender work, not a defect — but it changes what the product
                may claim, so three things move in the SAME commit (#456):
                  1. `CLAUDE.md`'s register bullet "Die RAUM-RENDER-Hälfte, sieben Kerne" — the
                     count and the membership both change.
                  2. `memory/LEDGER_COUNTS.md` §AB.1, the spatial cluster row.
                  3. Any copy that describes the space leg — `docs/overview.html`,
                     `docs/architecture.html`, `ContentPipeline/CLAIMS.md`. Until now the honest
                     line is "object POSITIONS on the wire", not "rendered spatial audio".
                """)
        }
    }

    // MARK: - Claim 2 — the two comments that asserted a render no longer do

    /// These are the reason the gap was worse than a missing register line: a session reading
    /// either file was told, in prose, that the render half works.
    ///
    /// ⛔ THE FIRST DRAFT OF THIS CLAIM WAS A NAIVE `XCTAssertFalse(contains:)` AND IT WENT RED
    /// ON THE CORRECT TREE — because the repair KEEPS the struck sentence, quoted, as the
    /// record of what was retracted. That is the #491 trap, which this repo had so far only
    /// hit inside `CLAUDE.md`; it applies to any file that documents its own corrections.
    /// The form that works: the phrase MAY appear, but every line carrying it must also carry
    /// the retraction stamp `#1379`. Re-asserting it as fact — a new line without the stamp —
    /// still goes red, which is the behaviour the claim was written for.
    func testNoCommentClaimsTheBinauralPannerRenders() throws {
        let cases = [("Sources/Echoelmusic/Core/SpatialSceneStore.swift",
                      "VBAPPanner / BinauralPanner render",
                      "the panners render"),
                     ("Sources/Echoelmusic/Audio/AudioEngine.swift",
                      "with `DSP/BinauralPanner` for the cues",
                      "`BinauralPanner` is the cue source")]

        for (path, needle, what) in cases {
            let unstamped = try source(path)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { $0.contains(needle) && !$0.contains("#1379") }
            XCTAssertTrue(unstamped.isEmpty, """
                \(path) states that \(what), on a line that is not marked as a retraction:
                \(unstamped.joined(separator: " / "))
                Measured #1379: `BinauralPanner`, `VBAPPanner` and `AmbisonicsEncode` have ZERO
                production callers. The honest sentence is that `ADMOSCSender` streams object
                POSITIONS; nothing in this app renders a binaural mix. If that changed, claim 1
                above is red too — fix it by wiring them, not by re-asserting it here.
                """)
        }
    }

    // MARK: - Claim 3 — counterweight: the control half IS real and must stay named

    /// Without this the cheapest way to "fix" claims 1–2 would be to stop describing the space
    /// leg at all — trading an over-claim for an under-claim, which #496 already cost a cycle.
    func testTheControlHalfOfTheSpaceLegIsStillNamed() throws {
        let sender = SourceText.codeOnly(try source("Sources/Echoelmusic/Sync/ADMOSCSender.swift"))
        XCTAssertTrue(sender.contains("/adm/obj/"), """
            `ADMOSCSender` no longer builds `/adm/obj/…` addresses. That IS the space leg — the
            control half, the half that ships. If it is gone, the identity line's "Space" and
            every ADM-OSC claim on the website lose their last support.
            """)
        let store = try source("Sources/Echoelmusic/Core/SpatialSceneStore.swift")
        XCTAssertTrue(store.contains("ADMOSCSender"), """
            `SpatialSceneStore` no longer names `ADMOSCSender` — the consumer that makes this
            store an output rather than a model. Keep the true half of the sentence.
            """)
    }

    // MARK: - Claim 4 — the cores are not deleted

    func testTheSpatialCoresAreKept() throws {
        for path in ["Sources/Echoelmusic/Sync/VBAPPanner.swift",
                     "Sources/Echoelmusic/Sync/AmbisonicsEncode.swift",
                     "Sources/Echoelmusic/DSP/BinauralPanner.swift",
                     "Sources/Echoelmusic/DSP/EchoelSpaceReverb.swift",
                     "Sources/Echoelmusic/Sequencer/SpatialAutomationMapping.swift"] {
            XCTAssertNoThrow(try source(path), """
                \(path) is gone. Unreachable is NOT a reason to delete here: EchoelLux L2/L3 and
                the EchoelRender path need exactly these, and they are pure, tested value types
                costing nothing at runtime. The defect this guard records was never their
                existence — it was that they were unreachable AND unwritten-down.
                """)
        }
    }
}
