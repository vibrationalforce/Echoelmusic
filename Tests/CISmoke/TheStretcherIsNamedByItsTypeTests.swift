//
//  TheStretcherIsNamedByItsTypeTests.swift
//  Echoelmusic — CISmoke (BLOCKING bundle)
//
//  WHY THIS EXISTS (#1376, Deep Function Check 2026-09-19).
//
//  `CLAUDE.md` listed `DSP/EchoelWSOLA` under "app-unwired pure cores" and cited, as its
//  evidence, `git grep -n "EchoelWSOLA(" -- Sources` → 0. `EchoelWSOLA` is the FILE's name.
//  The only type the file declares is `WSOLAStretcher`. So that needle returns 0 for EVERY
//  possible state of this repository, forever — including a state where the stretcher runs in
//  five surfaces. `.claude/rules/context.md` §2 states the law it broke: *a parser that matches
//  nothing is a finding, never a pass.*
//
//  The cost was not cosmetic. The register is what a session reads BEFORE deciding what is
//  safe to delete, `StretchMode.beats.isImplemented` is deliberately `true`, and regions
//  persist `stretchMode` — so a cleanup cycle could have looked up the cited command, seen 0,
//  and deleted the time-stretch that saved projects depend on.
//
//  ⭐ THE LAW THIS PINS, and it is wider than WSOLA: when a claim has TWO carriers, measure
//  them SEPARATELY. #1230 retracted "executors: AudioClipPlayer AND TimelineAudioSink" as a
//  unit; the first half was right (that file is dead) and the second was wrong (that sink is
//  live). A needle spelled with a name NEITHER carrier bears returns the same nothing for
//  both, so the retraction came out exactly as coarse as its instrument.
//
//  ⚠️ WHAT THIS GUARD DOES NOT DO (#364 — a guard must never forbid correct work):
//  · It does NOT require the stretcher to keep any particular number of call sites. Wiring a
//    new surface to it, or removing the dead `AudioClipPlayer` sites, both stay legal.
//  · It does NOT require `.beats` to stay `isImplemented`. That is a document question the
//    founder owns (persisted regions carry `stretchMode`).
//  · It does NOT text-scan `CLAUDE.md`. That file quotes retracted claims on purpose, so a
//    negative scan would strike its own retraction (#491).
//  What it DOES pin is the thing that made the false entry undetectable: the file/type name
//  split, and the fact that the live consumer is a consumer at all.
//
//  GRADED BY TRANSCRIPTION (`Tests/CISmoke/CLAUDE.md` §0) — there is no Swift toolchain in a
//  web session. Every assertion below was re-implemented in Python and driven against the
//  tree, plus mutants, before the commit.
//

import XCTest

final class TheStretcherIsNamedByItsTypeTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        // `try`, never `try?` — a moved or renamed file must FAIL LOUDLY (#454). A silent nil
        // here would turn every assertion below into a vacuous pass.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - Claim 1 — the file does not declare a type called after itself

    /// This is the exact shape that made the false register entry unfalsifiable. If someone
    /// ever DOES declare `EchoelWSOLA`, this goes red and the prose that says "it is a
    /// filename" has to be re-read — which is the correct outcome either way.
    func testTheWSOLAFileDeclaresTheStretcherAndNoTypeNamedAfterTheFile() throws {
        let src = try source("Sources/Echoelmusic/DSP/EchoelWSOLA.swift")
        XCTAssertFalse(src.isEmpty, "EchoelWSOLA.swift read as empty — the path moved.")

        XCTAssertTrue(src.contains("public struct WSOLAStretcher"), """
            `DSP/EchoelWSOLA.swift` no longer declares `public struct WSOLAStretcher`.
            That type IS the stretcher; the filename is not a type. If it was renamed, the
            three prose homes have to move with it (#456): this file's own `.beats` doc in
            `Sequencer/StretchMode.swift`, the bullet in
            `ANonFiniteControlCannotReachTheRenderTests`, and the register line in `CLAUDE.md`.
            """)

        for shape in ["struct EchoelWSOLA", "class EchoelWSOLA", "enum EchoelWSOLA"] {
            XCTAssertFalse(src.contains(shape), """
                A type named `EchoelWSOLA` now exists (`\(shape)`).
                For four cycles the register claimed this core was unwired on the strength of
                `git grep -n "EchoelWSOLA(" -- Sources` → 0 — a needle that could not match
                because no such type existed. If one exists now, that needle finally MEANS
                something, and `memory/LEDGER_COUNTS.md` §AA plus the `.beats` doc in
                `StretchMode.swift` must be re-read before either is trusted again.
                """)
        }
    }

    // MARK: - Claim 2 — the stretcher has a live consumer, named

    func testTheTimelineSinkConstructsTheStretcher() throws {
        let sink = try source("Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift")
        XCTAssertTrue(sink.contains("WSOLAStretcher()"), """
            `TimelineAudioSink` no longer constructs `WSOLAStretcher()`.
            This was THE fact #1230 missed and #1376 restored: the timeline half of the
            executor sentence is live, only the `AudioClipPlayer` half was dead. If the sink
            genuinely stopped using it, that is legal work — but then `CLAUDE.md`'s corrected
            register line ("VERDRAHTET ohne Erzeuger (#527-Lage)") is wrong again and must be
            re-measured with `git grep -n "WSOLAStretcher(" -- Sources`, not with the filename.
            """)
        XCTAssertTrue(sink.contains("func prepareBeats("), """
            `TimelineAudioSink.prepareBeats` is gone — that is the method the stretcher renders
            in, and the one `AudioLanePlayer` calls. Re-read Claim 3 with it.
            """)
    }

    /// The consumer is only a consumer if something injects it. A type constructed nowhere is
    /// exactly the state the register WRONGLY claimed, so this half has to be pinned too.
    func testTheTimelineSinkIsInjectedInProduction() throws {
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("TimelineAudioSink(engine:"), """
            `EchoelmusicApp` no longer constructs `TimelineAudioSink(engine:)`.
            Without this line the sink is a type nobody makes, and the WSOLA chain would be
            unreachable for real — which would move the register entry BACK to the unwired list.
            Do not let that happen silently: it is a category change, and the category decides
            whether deleting the stretcher is safe.
            """)
    }

    // MARK: - Claim 3 — the chain from the transport to the stretcher is unbroken

    func testTheLanePlayerRoutesBeatsRegionsToTheSink() throws {
        let lane = try source("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")

        XCTAssertTrue(lane.contains("capabilities: StretchMode.timelineCapabilities"), """
            `AudioLanePlayer` no longer resolves its regions with `timelineCapabilities`.
            That set is what lets `.beats` survive `StretchPlan.resolve` instead of falling
            back to `.clean` — without it the `prepareBeats` branch below is dead code.
            """)
        XCTAssertTrue(lane.contains("plan.mode == .beats"), """
            The `.beats` gate in `AudioLanePlayer` is gone — the branch that reaches WSOLA.
            """)
        XCTAssertTrue(lane.contains(".prepareBeats(url:"), """
            `AudioLanePlayer` no longer calls `prepareBeats(url:…)`. This is the last link
            between the transport and the stretcher; with it gone the corrected register entry
            in `CLAUDE.md` over-claims and must be re-measured.
            """)

        let stretch = try source("Sources/Echoelmusic/Sequencer/StretchMode.swift")
        XCTAssertTrue(stretch.contains("timelineCapabilities: Set<StretchMode> = [.clean, .tape, .beats]"), """
            `timelineCapabilities` no longer contains `.beats`.
            Removing it is legal work — but it makes the timeline stretcher unreachable, so the
            `CLAUDE.md` register line and `StretchMode`'s own `.beats` doc move in the same
            commit (#456).
            """)
    }

    // MARK: - Claim 4 — the retraction names the real type, not just the filename

    /// The original defect was prose that discussed a FILENAME as if it were the thing. This
    /// asserts the corrected doc cannot silently slide back into that habit.
    func testTheBeatsDocNamesTheStretcherType() throws {
        let stretch = try source("Sources/Echoelmusic/Sequencer/StretchMode.swift")
        XCTAssertTrue(stretch.contains("WSOLAStretcher"), """
            `StretchMode.swift` no longer names `WSOLAStretcher` anywhere.
            Its `.beats` doc is the canonical account of what does and does not execute; if it
            names only the filename again, the next audit repeats #1230 exactly.
            """)
        XCTAssertTrue(stretch.contains("TimelineAudioSink"), """
            The `.beats` doc no longer names `TimelineAudioSink` — the live executor. Naming
            only the dead one (`AudioClipPlayer`) is how the register got this backwards.
            """)
    }

    // MARK: - Claim 5 — counterweight: the dead half stays named as dead

    /// Without this, a later cleanup could "fix" the doc by calling BOTH executors live again —
    /// the mirror image of #1230's error, and just as wrong.
    func testTheDeadPreviewExecutorIsStillNamedAsDead() throws {
        let player = try source("Sources/Echoelmusic/Sequencer/AudioClipPlayer.swift")
        XCTAssertFalse(player.isEmpty, """
            `Sequencer/AudioClipPlayer.swift` is gone. Deleting it is defensible — it has zero
            callers and zero tests — but thirteen comments in eight other files name it, several
            of them as the LIVE renderer (`DSP/AudioOutputGuard.swift:74`,
            `Sequencer/TimelineScheduling.swift:114`). Those move in the same commit, and
            `StretchMode.previewCapabilities` loses its stated consumer.
            """)
        let stretch = try source("Sources/Echoelmusic/Sequencer/StretchMode.swift")
        XCTAssertTrue(stretch.contains("previewCapabilities"), """
            `previewCapabilities` is gone from `StretchMode`. It is kept ON PURPOSE with no live
            consumer (#1376) — it records the shape a re-doored editor preview would take.
            """)
    }
}
