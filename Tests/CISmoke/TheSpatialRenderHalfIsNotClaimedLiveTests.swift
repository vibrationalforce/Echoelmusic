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
//  ⭐ EXTENDED 2026-10-13 (GMMW deep audit). Claim 4 kept its own list and held FIVE of the
//  seven claim 1 names: `LightFixtureGroup` and `BioPhaser` could be deleted without a red,
//  while the register line that sends a session here says seven. Claims 1, 4 and 5 now read ONE
//  list, `cores` (#416). And two more files are unwired one hop down and were named by no
//  register — `Core/EchoelRenderLayout` and `Sequencer/AutomationGestureRecorder` (claim 5).
//
//  GRADED BY TRANSCRIPTION (`Tests/CISmoke/CLAUDE.md` §0). SOURCE-TEXT SCAN throughout.
//  2026-10-13 regrade, every claim driven in Python against this tree and the parent
//  `cc683262c` — identical in `Sources/`, because this slice touches no source file:
//  ZERO REGRESSIONS, ZERO ANCHOR ABSENCES; every assertion is green on both, so the new ones
//  are COUNTERWEIGHTS against a future deletion or wiring. Each was driven red by a mutant for
//  its named reason: claim 4 by deleting any of the four newly kept files; claim 5 by an
//  `EchoelRenderLayout` in `SpatialSceneStore`, a `Loudspeaker` in `AudioEngine`, an
//  `AutomationGestureRecorder` in `TimelineStore`, and its anchor by renaming the namesake
//  type. Green as intended: the same reference from a core or from the other leaned-on file
//  (the chain stays dead), and a mention in a comment. The stripper is TRAGEND for claim 1
//  (raw text books comment mentions in five files to five cores) and PROPHYLAKTISCH for claim 5
//  (0 of 16 verdicts flip); the word boundary in claim 5 is PROPHYLAKTISCH today (0 flip) and
//  keeps a future `LoudspeakerLayoutCache` from booking itself to `Loudspeaker` — mutant-shown.
//

import Foundation
import XCTest

final class TheSpatialRenderHalfIsNotClaimedLiveTests: XCTestCase {

    private struct AnchorMissing: Error { let reason: String }

    /// The seven render cores — the type and the file that declares it. ONE list for claims 1,
    /// 4 and 5 (#416): claim 4 kept its own copy until 2026-10-13 and had dropped two of them.
    private static let cores: [(type: String, path: String)] = [
        ("VBAPPanner", "Sources/Echoelmusic/Sync/VBAPPanner.swift"),
        ("AmbisonicsEncode", "Sources/Echoelmusic/Sync/AmbisonicsEncode.swift"),
        ("LightFixtureGroup", "Sources/Echoelmusic/Sync/LightFixtureGroup.swift"),
        ("BioPhaser", "Sources/Echoelmusic/Sync/BioPhaser.swift"),
        ("BinauralPanner", "Sources/Echoelmusic/DSP/BinauralPanner.swift"),
        ("EchoelSpaceReverb", "Sources/Echoelmusic/DSP/EchoelSpaceReverb.swift"),
        ("SpatialAutomationMapping", "Sources/Echoelmusic/Sequencer/SpatialAutomationMapping.swift"),
    ]

    /// The two files the cores lean on, one hop down (claim 5).
    private static let leanedOn = ["Sources/Echoelmusic/Core/EchoelRenderLayout.swift",
                                   "Sources/Echoelmusic/Sequencer/AutomationGestureRecorder.swift"]

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

    /// The seven are listed together ON PURPOSE, in `cores` above. Splitting them by directory
    /// is exactly how three of them stayed invisible for seventeen days.
    func testTheSpatialRenderCoresHaveNoProductionCaller() throws {
        let corpus = try productionCode()

        for core in Self.cores {
            let type = core.type
            let own = URL(fileURLWithPath: core.path).lastPathComponent  // not a "caller"
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

    // MARK: - Claim 4 — the cores, and the two files they lean on, are not deleted

    /// ⛔ Until 2026-10-13 this claim carried its own list of FIVE paths while claim 1 named
    /// seven, so `LightFixtureGroup` and `BioPhaser` could go without a red. It reads `cores`.
    func testTheSpatialCoresAreKept() throws {
        for path in Self.cores.map(\.path) + Self.leanedOn {
            XCTAssertNoThrow(try source(path), """
                \(path) is gone. Unreachable is NOT a reason to delete here: EchoelLux L2/L3, the
                EchoelRender path and spatial gesture automation need exactly these, and they are
                pure, tested value types costing nothing at runtime. The defect this guard records
                was never their existence — it was that they were unreachable AND unwritten-down.
                """)
        }
    }

    // MARK: - Claim 5 — the two files the cores lean on are reachable only through them

    /// Measured 2026-10-13 (GMMW deep audit), comment-stripped and word-bounded: one hop below
    /// the seven sit two files no register named. `Core/EchoelRenderLayout.swift` declares
    /// fifteen top-level types (the IEM loudspeaker layout plus the EchoelRender block); the only
    /// one another production file names is `Loudspeaker`, and the only file naming it is
    /// `VBAPPanner`. `Sequencer/AutomationGestureRecorder.swift` is named by
    /// `SpatialAutomationMapping` alone. Both are as unwired as the seven: a cleanup that asks
    /// "who calls this?" finds a caller that itself has none, and a register that asks that
    /// question per entry cannot see that two orphans are one chain.
    ///
    /// A reference from a core or from the other leaned-on file keeps the chain dead and stays
    /// green. Word-bounded because `Loudspeaker` is a prefix of `LoudspeakerLayout`, declared in
    /// the same file.
    func testTheFilesTheCoresLeanOnHaveNoOtherCaller() throws {
        let corpus = try productionCode()
        let deadChain = Set((Self.cores.map(\.path) + Self.leanedOn)
            .map { URL(fileURLWithPath: $0).lastPathComponent })

        for path in Self.leanedOn {
            let own = URL(fileURLWithPath: path).lastPathComponent
            let types = try topLevelTypes(in: SourceText.codeOnly(source(path)))
            let namesake = String(own.dropLast(".swift".count))
            guard types.contains(namesake) else {
                throw AnchorMissing(reason: """
                    The declaration scan found \(types) in \(path), not `\(namesake)` itself. A \
                    scan that matches nothing is a finding, never a pass — re-anchor (#454).
                    """)
            }
            for type in types {
                let outside = corpus
                    .filter { !deadChain.contains($0.name) && mentions($0.code, type) }
                    .map(\.name)
                    .sorted()
                XCTAssertTrue(outside.isEmpty, """
                    `\(type)` (declared in \(path)) is now named by production code outside the \
                    seven spatial cores: \(outside.joined(separator: ", ")).
                    That is EchoelRender or gesture-automation work, not a defect — but the file \
                    stops being an orphan, so two things move in the SAME commit (#456):
                      1. `docs/dev/FEATURE_STATUS.md` §2c, the Raum-Render row that names it.
                      2. `memory/LEDGER_COUNTS.md` §AB.6, the row for this file.
                    """)
            }
        }
    }

    // MARK: - Helpers for claim 5

    /// Column-0 type declarations only. Nested types are indented and stay out on purpose: a
    /// nested name like `Issue` would match every other file that declares its own.
    private func topLevelTypes(in code: String) throws -> [String] {
        let declaration = try NSRegularExpression(
            pattern: #"^(?:(?:public|internal|fileprivate|private|open) )?(?:final )?(?:struct|enum|class|protocol|actor) ([A-Z][A-Za-z0-9_]*)"#,
            options: [.anchorsMatchLines])
        let ns = code as NSString
        return declaration.matches(in: code, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 && $0.range(at: 1).location != NSNotFound
                ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }

    private func mentions(_ code: String, _ type: String) -> Bool {
        code.contains(type) && code.range(of: "\\b\(type)\\b", options: .regularExpression) != nil
    }
}
