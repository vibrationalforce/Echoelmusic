// TheEngineLifecycleSpeaksInTheDiagLogTests — pins #859, the sixth crash log's answer.
//
// THE FINDING (founder device log v10.79.428, build 2546): the isInputConnToConverter
// SIGABRT fired 24 s after a healthy launch with NO monitoring line in the log at all —
// no toggle, no `monitor: ON`, nothing. The stack came out of a Task continuation on the
// main queue (libswift_Concurrency + libdispatch), i.e. one of the ASYNC engine-lifecycle
// paths: interruption resume, route loss, media-services reset, or the de-bounced
// self-heal restart. Every one of those paths spoke ONLY os_log — which the exported
// diag file does not carry — so the log showed 24 seconds of silence before the crash.
// Three of six crash logs stalled on exactly this invisibility.
//
// #859 therefore extends the #854 breadcrumb discipline to the engine lifecycle:
// `logEngineLifecycle` writes `engine: …` into the SAME exported file as `monitor: …`,
// and every async restart path plus both ObjC-asserting `start()` attempts carry a rung.
// It also closes the one MEASURED hazard on such a path: the configuration-change
// watchdog read `masterEngine.inputNode` on EVERY change while running — the first
// access forces the I/O unit to grow an input bus, converter machinery a playback-only
// session cannot back — although the value is only used while monitoring is on.
//
// ⚠️ WHAT IS DELIBERATELY NOT PINNED (#364): the wording of any rung beyond its stable
// prefix, the 300 ms settle, maxRecoveryAttempts. Pinned is STRUCTURE: the shared file,
// a rung per path, rungs around both start attempts, and the inputNode gate ORDER.
//
// ⚠️ HONEST LIMIT (§1): source-text scans — no AVAudioEngine runs in a test host, and
// whether the next crash log actually names its path is the founder's next device log.
//
// ⭐ GRADING (§3), claims 1–5: FORWARD in full — every needle names #859 text created in
// the same commit; red at the parent by the one shared absence (#486). The ordering walks
// could never have a verdict there. Counterweights: the claim-4 gate needles are the ones
// TheMonitoringSurvivesEngineRecoveryTests claim 3 already holds green on both trees.
//
// ⭐ GRADING, claim 12 (#875): a COUNTERWEIGHT, green on both trees, and the flattering
// reading is available so it is refused here. It fixes nothing and instruments nothing —
// all five sites were ALREADY route-guarded when I read them, which is the finding. Its
// value is that the audit stops being a thing one session did once: a SIXTH site now goes
// red instead of joining four crash-adjacent hazards unreviewed. Note what it deliberately
// is NOT: a check of WHY each site is safe. The smarter version — look back N characters
// for the route claim — called 4 of 5 unguarded at a 260-character window, all four false.
// A count that admits its own blindness beats a scan that cries wolf (#665, #874).
//
// ⭐ GRADING, claims 10 and 11 + claim 8s three new rows (#862b), and the honest split
// here is UNFLATTERING, which is the point. Claim 10 is FORWARD (its five `on N/5`
// stages are created by this commit; 2 assertions red at the parent by absence). Claim
// 11 and the three overload rows added to claim 8 are COUNTERWEIGHTS — green on BOTH
// trees — because the rungs they pin already existed and #862 simply failed to guard
// them. Booking those four as regressions would say this commit fixed something it only
// FENCED. What they buy is real all the same: a cleanup slice can no longer delete four
// rungs on a green gate under a test whose name promises full coverage (#374).
//
// ⭐ GRADING, claims 8 and 9 (#862): FORWARD IN FULL, and saying so matters — every
// needle names a rung this same commit creates, so all six assertions are red at the
// parent by ABSENCE, none by regression. Booking them as regressions would be the
// flattering-direction defect §3 names. What they are NOT is padding: the absence they
// describe was real and shipped, and two independent audits of one device log found it.
// The anchor-uniqueness assertions inside claim 8 ARE counterweights — green on both.
//
// ⭐ GRADING, claim 7 (#860b): TWO REGRESSIONS — both helpers put `os_log` before the
// breadcrumb on the parent, red for exactly the reason the claim names. Claim 6's third
// case is red there by needle absence (the rung was renamed to say `engine.prepare()` in
// the same commit that added this line, so the old spelling is gone from BOTH trees —
// `dead-needles.py` confirms no guard still hunts it). The anchor-uniqueness assertion is
// a COUNTERWEIGHT: green on both trees today, and it exists because the header used to
// claim a check that the code did not perform.
//
// ⭐ GRADING, claim 6 (#860) — the strongest in this file, and transcribed against BOTH
// trees rather than reasoned: TWO REGRESSIONS (the interruption and route-lost rungs sit
// AFTER `masterEngine.pause()` on the parent, red for exactly the reason the claim's name
// gives — #367) and ONE FORWARD (the `prepare` rung is created by this commit, so it is
// red there by absence, not by order). All three green on the worktree.
//
// ⭐ GRADING, claims (c2)/(c3) + (d) (#907) — this slice REWRITES (c2), so the WHOLE method
// was driven on both trees, not just the changed lines (§3's delta-blindness warning).
// Against the parent (#906): THREE FORWARDS (the three unnumbered literals do not exist
// there, so (c2) is red by absence) and TWO REGRESSIONS — (c3) selects both of #906's
// numbered `… n/N SKIPPED` lines and fails, and (d)'s pin of 15 meets an actual 14. On the
// worktree all are green. Four negative drives were transcribed rather than reasoned: the
// emitter lifted out of its `else {}` (adjacency RED while the ordering claim stays GREEN —
// that is the hole (c2)'s new pin exists for), a trailing `// #907: was 1/2` comment (stays
// GREEN — the false red M2 would otherwise have caused), and an interpolated rung (fires the
// interpolation claim). ⚠️ (c3)'s `AudioEngine` half WAS a TRIPWIRE, not a counterweight:
// measured 3 selected lines in `AudioConfiguration` and ZERO in `AudioEngine`.
// ⭐ #913 CHANGED THAT — the tripwire fired as designed, in the good direction. The two new
// pre-rung exits are unnumbered `monitor:` skips, so (c3)'s `AudioEngine` half now selects
// TWO lines and both pass: it is a LIVE counterweight, not a tripwire. Do not re-quote the
// ZERO — the number was a measurement of a tree that no longer exists.
//
// ⛔ GRADING, claims (c3) + (c4) (#908) — AND THE FIRST DRAFT OF THIS BLOCK SAID (c3) WAS
// RETIRED. It is not. #908 taught `scripts/diag-ladder.py` a terminator, and I concluded the
// numbered spelling was safe; the review disproved it with a log: `on 4/5 SKIPPED` WALKS ON,
// so a log ending there is a death in the TAP REGION (⚠️ #956 widened it: the rung now re-reads the node's output format first, and it can end in `on 5/5 SKIPPED: node reports no usable tap format`, which is a REPORT and not a death), and the draft printed `⏹ ended`,
// exit 0. In a LOG the walks-on and the returning form are the same shape, so the tool
// rescues only UNNUMBERED terminators and (c3) is what keeps the ambiguous spelling out of
// `Sources/`. (c3) is graded: red on `da06482` (both numbered lines), green on the worktree;
// its `AudioEngine` half selected ZERO lines at the time and was a TRIPWIRE (see the ⭐
// above: #913 made it a live counterweight with two selected lines). Its
// interpolation half is a separate assertion and was nearly lost with it.
// (c4) is graded across THREE trees: `b0d6480` → BOTH session functions red, `da06482` →
// `downgradeToPlaybackAfterRecording` red, worktree → green; plus four mutants on the
// worktree (wrapped breadcrumb GREEN, trailing comment GREEN, `if … { return }` RED, silent
// `throw` RED) — its own first draft failed all four.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheEngineLifecycleSpeaksInTheDiagLogTests: XCTestCase {

    private static let enginePath = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let configPath = "Sources/Echoelmusic/Audio/AudioConfiguration.swift"

    // MARK: - 1: the helper writes the EXPORTED file, not only os_log

    func testTheLifecycleHelperWritesTheBreadcrumbFile() throws {
        let code = try code(Self.enginePath)
        XCTAssertEqual(occurrences(of: "EchoelCrashLog.breadcrumb(\"engine: \\(message)\")", in: code), 1, """
            `logEngineLifecycle` no longer writes the exported diag file — the async \
            lifecycle paths fall silent again, and the next start-shaped ObjC assert \
            is another 24 seconds of nothing before a crash (the v428 log).
            """)
    }

    // MARK: - 2: every async lifecycle path leaves a rung

    func testEveryLifecyclePathCarriesARung() throws {
        let code = try code(Self.enginePath)
        for needle in ["logEngineLifecycle(\"interrupted — pausing\")",
                       // ⚠️ #871: this needle used to read `…("interruption ended — restarting")`
                       // and the rung now carries an interpolated `(monitoring: …)` suffix on
                       // its own line, so both the closing paren AND the `logEngineLifecycle(`
                       // prefix stopped adjoining it. The #655/#656 shape — caught by this test
                       // before the commit instead of by a red run after it.
                       // Anchored on the QUOTED STRING alone, deliberately: the first draft of
                       // this repair spelled the line break and sixteen spaces into the needle,
                       // which would have gone red on a reformat that changed nothing. That the
                       // rung is written through `logEngineLifecycle` is claim 1's job, not
                       // this one's; here the guarantee is only that the path still speaks.
                       "\"interruption ended — restarting",
                       "logEngineLifecycle(\"interruption restart FAILED",
                       "logEngineLifecycle(\"media services reset — recovering\")",
                       "logEngineLifecycle(\"route lost — recovering",
                       "logEngineLifecycle(\"self-heal attempt",
                       "logEngineLifecycle(\"self-heal gave up",
                       "logEngineLifecycle(\"self-heal recovered"] {
            XCTAssertGreaterThanOrEqual(occurrences(of: needle, in: code), 1, """
                `\(needle)` is gone. Each async lifecycle path must speak in the \
                exported log (#859) — a silent path is the v428 triage stall again.
                """)
        }
    }

    // MARK: - 3: rungs around BOTH ObjC-asserting start attempts

    func testTheStartAttemptsAreLaddered() throws {
        let code = try code(Self.enginePath)
        guard let anchor = code.range(of: "logEngineLifecycle(\"start 1/2: starting master engine\")") else {
            XCTFail("the start 1/2 rung is gone — a start-shaped death reads as silence again (§4).")
            return
        }
        // ⛔ #964 — THIS WAS `prefix(1_200)` AND #964 LEFT IT 296 CHARACTERS OF SLACK.
        // A fixed window is a date (#408): #964 added the failure-naming lines between the two
        // start attempts, moving the second `try masterEngine.start()` from offset 492 to 880.
        // The next person to add a few lines there reddens a ladder claim for a reason that has
        // nothing to do with the ladder. The bound is structural instead:
        //
        // ⛔ #966 — #964 PRINTED 965 / 235 / 998→1875 HERE AND ALL THREE WERE MEASURED WITH THE
        // WRONG READER. Those are `SourceText.codeOnly` figures — which is what the NEW guard's
        // `retryRegion` uses — while THIS claim reads through `code(_:)` below, a whole-line
        // `//` filter that keeps trailing comments and blank lines. Under its own reader:
        // 880, 296 characters of slack, window 977 → 1685. Same defect class as #965's corpus
        // error one cycle earlier: **a measurement is tied to its READER the way a count is tied
        // to its corpus**, and quoting one beside the other claim is not a rounding error.
        // Re-derive with the reader this claim actually uses:
        //
        //   python3 -c "import subprocess; \
        //   t=subprocess.run(['git','show','HEAD:Sources/Echoelmusic/Audio/AudioEngine.swift'], \
        //   capture_output=True,text=True).stdout; \
        //   c='\n'.join(l for l in t.split('\n') if not l.strip().startswith('//')); \
        //   a=c.find('logEngineLifecycle(\"start 1/2: starting master engine\")'); \
        //   f=c.find('try masterEngine.start()',a); \
        //   print(c.find('try masterEngine.start()',f+24)-a, c.find('startMeterPollTimer()',a)-a)"
        // the rest of the `if !masterEngine.isRunning` block, which ends at the tap re-install.
        // `startMeterPollTimer()` occurs twice in the file (call and declaration) and the CALL
        // is the first — asserted, not assumed, because "the first hit is the one I mean" is
        // how an anchor silently moves.
        XCTAssertEqual(occurrences(of: "startMeterPollTimer()", in: code), 2, """
            `startMeterPollTimer()` no longer occurs exactly twice (call + declaration). \
            This claim uses the CALL as the end of its window; re-anchor before trusting it (#408).
            """)
        let afterAnchor = code[anchor.lowerBound...]
        let windowEnd = afterAnchor.range(of: "startMeterPollTimer()")?.lowerBound
            ?? afterAnchor.endIndex
        let window = String(afterAnchor[..<windowEnd])
        var cursor = window.startIndex
        for step in ["try masterEngine.start()",
                     "logEngineLifecycle(\"start 2/2: retry after session reconfigure\")",
                     "try masterEngine.start()"] {
            guard let r = window.range(of: step, range: cursor..<window.endIndex) else {
                XCTFail("""
                    start ladder broken at `\(step)` — both start attempts can die in \
                    the isInputConnToConverter ObjC assert that never reaches the \
                    catch; each needs its rung BEFORE the call (#859, the #854 shape).
                    """)
                return
            }
            cursor = r.upperBound
        }
    }

    // ⛔ #1302 (founder 2026-09-12, "Face und Audio Input komplett entfernen") —
    // `testTheSuspectPathIsSplitByTwoUnnumberedMarkers` STOOD HERE AND IS GONE WITH BOTH ITS
    // SUBJECTS. It pinned the #910 marker on the two paths that touched an input node —
    // `AudioEngine`'s `on 1/5` monitoring rung and `MicrophoneManager`'s `mic: start 2/3` — and
    // neither file nor rung exists any more.
    //
    // ⭐ THE TWO LAWS IT ENFORCED SURVIVE AND ARE WHAT THE NEXT LADDER NEEDS: (1) a marker sits
    // BETWEEN its rung and the call it splits — before the rung it says nothing new, after the
    // call it describes a step that already happened (#860/#878). (2) The marker's line must BE
    // the emitter, never a statement inside a branch that happens to contain it: a breadcrumb
    // wrapped in `if wasRunning { … }` stops meaning "control reached here", which is exactly
    // how #631's breadcrumb came to read as confirmation of its opposite.


    // MARK: - 6: a rung stands BEFORE its AVFAudio call, never after (#860)

    /// ⛔ THE DEFECT THIS PINS IS ONE #859 SHIPPED. Three rungs sat AFTER the graph call
    /// they described — `pause()` twice and `prepare()` once — so a death inside that call
    /// logged NOTHING: the witness stood on the far side of the event. Measured, not
    /// reasoned: the v429 device log (seventh crash of the isInputConnToConverter family)
    /// carried the launch rungs, proving the mechanism works, and then not ONE of the 22
    /// rungs before a SIGABRT out of a main-queue Task continuation.
    ///
    /// A ladder whose rungs trail their steps is worse than none — it reads as "this path
    /// was not taken" when the truth is "this path died mid-step".
    ///
    /// ⚠️ NOT PINNED (#364): the rung wording, beyond the prefix a sibling claim already
    /// owns. Pinned is ORDER only, which is the part that carries the law.
    func testEachRungStandsBeforeItsGraphCall() throws {
        let code = try code(Self.enginePath)
        // anchor, rung, graph call, window — uniqueness is ASSERTED below, not asserted
        // in prose: #860b, reviewer, found this comment claiming a check it did not do.
        let cases: [(String, String, String, Int)] = [
            ("onInterruptionBegan = { [weak self] in",
             "logEngineLifecycle(\"interrupted — pausing\")",
             "masterEngine.pause()", 700),
            ("onRouteDeviceLost = { [weak self] in",
             "logEngineLifecycle(\"route lost — recovering",
             "masterEngine.pause()", 900),
            ("    func start() {",
             "logEngineLifecycle(\"engine.prepare() — allocating graph resources\")",
             "masterEngine.prepare()", 900),
        ]
        for (anchor, rung, call, window) in cases {
            XCTAssertEqual(occurrences(of: anchor, in: code), 1, """
                `\(anchor)` is no longer unique in the file (#408). `range(of:)` takes the \
                FIRST match, so the window below would open on the wrong site and could \
                hand back a green for a function this claim never meant to inspect.
                """)
            guard let a = code.range(of: anchor) else {
                XCTFail("anchor `\(anchor)` is gone — re-anchor this claim (§4).")
                return
            }
            let body = String(code[a.lowerBound...].prefix(window))
            guard let r = body.range(of: rung), let c = body.range(of: call) else {
                XCTFail("""
                    `\(rung)` or `\(call)` left the window under `\(anchor)`. Re-measure \
                    the window before widening it — and keep the rung: without it a death \
                    inside `\(call)` is silence in the exported log (#860).
                    """)
                return
            }
            XCTAssertTrue(r.lowerBound < c.lowerBound, """
                The rung for `\(call)` sits AFTER the call again (#860). A pause/prepare \
                that raises the isInputConnToConverter ObjC assert then logs nothing, and \
                the next crash log reads as "path not taken" instead of naming the step.
                """)
        }
    }


    // MARK: - 7: the witness writes the DURABLE sink first (#860b)

    /// ⛔ THE LADDER HAD ITS OWN #860 DEFECT, one level down. Both helpers called the
    /// slow shared sink (`os_log`, which locks and can be throttled) BEFORE the durable
    /// unbuffered `write(2)`. A process dying between those two statements loses the rung
    /// and the path reads as never-taken — precisely what the ladder exists to prevent.
    ///
    /// ⚠️ Order only (#364): the message text, the prefixes and the level default are
    /// free to change.
    func testTheDurableSinkIsWrittenFirst() throws {
        let code = try code(Self.enginePath)
        for (fn, crumb, oslog) in [
            ("private func logEngineLifecycle", "EchoelCrashLog.breadcrumb(\"engine: ", "log.audio(\"Engine lifecycle: "),
            ("private func logMonitorOutcome", "EchoelCrashLog.breadcrumb(\"monitor: ", "log.audio(\"Input monitoring: "),
        ] {
            guard let a = code.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor this claim (§4).")
                return
            }
            let body = String(code[a.lowerBound...].prefix(400))
            guard let c = body.range(of: crumb), let o = body.range(of: oslog) else {
                XCTFail("both sinks must stay in `\(fn)` — the exported log is the only one the founder sends.")
                return
            }
            XCTAssertTrue(c.lowerBound < o.lowerBound, """
                `\(fn)` writes os_log before the breadcrumb again (#860b). os_log locks in \
                the unified-logging subsystem; a death between the two statements loses the \
                rung, and a lost rung reads as a path never taken.
                """)
        }
    }


    // MARK: - 8: every graph-mutating entry point carries a rung (#862)

    /// ⛔ TWO INDEPENDENT AUDITS OF THE v429 LOG LANDED HERE. `restartOrDegrade` held the
    /// FIFTH `masterEngine.start()` in the file and one of the TWO without a rung (#862b
    /// retracts #862's "the only one" — the other is on the monitoring ON path, claim 10) — and #858
    /// established that the isInputConnToConverter assert fires INSIDE `start()` as an ObjC
    /// exception no Swift `catch` sees, so its own `do` block cannot report its death. Its
    /// five callers are all hot graph edits (pause → mutate → restart), and that whole
    /// family spoke only `log.audio`, which the exported diag file does not carry.
    ///
    /// ⚠️ PRESENCE only, not wording or argument (#364). What must not come back is a
    /// graph mutation the founder's log cannot see.
    func testEveryGraphMutationLeavesARung() throws {
        let code = try code(Self.enginePath)
        for (fn, rung) in [
            ("private func restartOrDegrade", "logEngineLifecycle(\"restart after "),
            ("func attachSourceNode", "logEngineLifecycle(\"graph: attach source node"),
            ("func detachSourceNode", "logEngineLifecycle(\"graph: detach source node"),
            ("func detachPlayerNode(_ node: AVAudioPlayerNode) {", "logEngineLifecycle(\"graph: detach player node"),
            ("func stop(reason: StopReason)", "logEngineLifecycle(\"stop ("),
            // ⛔ #862b (reviewer G) — THE THREE OVERLOADS #862 CREATED AND DID NOT PIN.
            // The method name says EVERY; the table held five of eight. A cleanup slice
            // could have deleted these three rungs on a green gate, under a test whose
            // name still promised full coverage — the #374 lying-name shape.
            ("func attachPlayerNode(_ node: AVAudioPlayerNode, format: AVAudioFormat) {",
             "logEngineLifecycle(\"graph: attach player node"),
            ("through timePitch: AVAudioUnitTimePitch,",
             "logEngineLifecycle(\"graph: attach player node + time-pitch"),
            ("func detachPlayerNode(_ node: AVAudioPlayerNode, timePitch: AVAudioUnitTimePitch) {",
             "logEngineLifecycle(\"graph: detach player node + time-pitch"),
        ] {
            XCTAssertEqual(occurrences(of: fn, in: code), 1,
                           "`\(fn)` is no longer unique — re-anchor this claim (#408, §4).")
            guard let a = code.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor this claim (§4).")
                return
            }
            let body = String(code[a.lowerBound...].prefix(700))
            XCTAssertTrue(body.contains(rung), """
                `\(fn)` mutates the AVFAudio graph and no longer announces itself in the \
                exported diag file (#862). os_log does not reach that file — a death here \
                is 14 seconds of silence and a SIGABRT, which is the v429 log exactly.
                """)
        }
    }

    /// The rung must PRECEDE the start it describes — the #860 rule, applied to the
    /// fifth start().
    func testTheRestartRungPrecedesItsStart() throws {
        let code = try code(Self.enginePath)
        guard let a = code.range(of: "private func restartOrDegrade") else {
            XCTFail("`restartOrDegrade` is gone — re-anchor this claim (§4).")
            return
        }
        let body = String(code[a.lowerBound...].prefix(700))
        guard let r = body.range(of: "logEngineLifecycle(\"restart after "),
              let c = body.range(of: "try masterEngine.start()") else {
            XCTFail("the restart rung or its start() left the window — re-measure before widening it.")
            return
        }
        XCTAssertTrue(r.lowerBound < c.lowerBound, """
            The restart rung sits AFTER `try masterEngine.start()` — the #860 defect on the \
            one start() that had no witness at all. The assert this family raises is an ObjC \
            exception; the catch below never runs, so a rung behind the call writes nothing.
            """)
    }


    /// The eighth #862 rung — `start()`'s already-running half — had no claim at all.
    func testTheLiveStartBranchSpeaks() throws {
        let code = try code(Self.enginePath)
        XCTAssertEqual(occurrences(of: "logEngineLifecycle(\"start: re-arming taps", in: code), 1, """
            `start: re-arming taps…` is gone (#862b, reviewer G). Entering `start()` with the \
            engine already running skips all three rungs inside `if !masterEngine.isRunning` \
            and lands on live tap surgery — the branch was silent before this line.
            """)
    }

    // ⛔ #1302 (founder 2026-09-12, "Face und Audio Input komplett entfernen") — SIX SECTION
    // HEADINGS STOOD HERE AND ARE GONE WITH THEIR CLAIMS, all of them monitoring: 4 (the
    // watchdog reads `inputNode` only under the monitoring gate), 5 (the voice-timbre chain
    // speaks too), 10 (the ON path is staged like the OFF path), 14 (the input switch reaches
    // the exported log), 16 (a numbered step always emits, taken or skipped) and 18 (the two
    // PRE-RUNG exits of `setInputMonitoring` announce themselves). The numbering of what
    // remains is deliberately NOT renumbered: the gaps are the record, and the numbers are
    // cited from commit messages and from `CLAUDE.md`.

    // MARK: - helpers (the house shape: strip comments, skip on no tree)

    // MARK: - 13: the SESSION half of the ladder speaks too (#878)

    /// ⛔ THE HOLE THIS CLOSES. `AudioConfiguration` carried FIFTEEN AVAudioSession calls
    /// (comment-stripped count) and exactly ONE breadcrumb — `latencyBreadcrumb`, which is a
    /// measurement, not a rung. So every rung on the engine side that hands off to a category
    /// flip (`mic: stop 3/3 — releasing record route`, `on N/5`, `off N/5`) ended at the
    /// boundary and the next stretch was dark. A category move is the neighbourhood the
    /// `isInputConnToConverter` family lives in.
    ///
    /// ⚠️ THE LADDER IS DELIBERATELY NOT A CENSUS OF ALL FIFTEEN, and this claim does not
    /// pretend otherwise. It covers the THREE category-transition functions. The rest
    /// (`setLatencyMode`, `measureLatency`, the interruption handler) either repeat on a
    /// path the engine side already narrates or are measurements. A future session that
    /// wants full coverage is adding work, not fixing a defect — this forbids nothing (#364).
    func testTheSessionTransitionsCarryRungs() throws {
        let config = try code("Sources/Echoelmusic/Audio/AudioConfiguration.swift")

        // (a) Every rung exists exactly once.
        for rung in ["session: configure 1/4 — setCategory(",
                     "session: configure 2/4 — setPreferredSampleRate",
                     "session: configure 3/4 — setPreferredIOBufferDuration",
                     "session: configure 4/4 — setActive",
                     "session: raise 1/2 — setCategory(.playAndRecord)",
                     "session: raise 2/2 — setActive",
                     "session: lower 1/1 — setCategory(.playback)"] {
            XCTAssertEqual(occurrences(of: rung, in: config), 1,
                           "`\(rung)` is gone — the session half falls diag-dark again (#878).")
        }

        // (b) ORDER: a rung stands BEFORE the call it names, inside its OWN function window
        //     (the anchor is asserted unique first — #408).
        let ordered: [(fn: String, rung: String, call: String)] = [
            // #879 (reviewer): rung 1/4 had EXISTENCE but no ORDER, because its named call
            // is two-branched and no single needle fits both arms. Moving it below the
            // branch would have kept all sixteen assertions green while the rung described
            // a category that had already been set. The BRANCH KEYWORD is the stable
            // anchor — the rung must precede the `if`, so it covers both arms.
            ("static func configureAudioSession", "session: configure 1/4",
             "if recordingRouteNeeded {"),
            ("static func configureAudioSession", "session: configure 2/4",
             "setPreferredSampleRate(preferredSampleRate)"),
            ("static func configureAudioSession", "session: configure 3/4",
             "setPreferredIOBufferDuration(bufferDuration)"),
            ("static func configureAudioSession", "session: configure 4/4",
             "setActive(true, options: .notifyOthersOnDeactivation)"),
            ("static func upgradeToPlayAndRecord", "session: raise 1/2 — setCategory",
             "setCategory(.playAndRecord, mode: .default, options: recordOptions)"),
            ("static func upgradeToPlayAndRecord", "session: raise 2/2 — setActive",
             "setActive(true, options: .notifyOthersOnDeactivation)"),
            ("static func downgradeToPlaybackAfterRecording", "session: lower 1/1 — setCategory",
             "setCategory(.playback, mode: .default,"),
        ]
        for (fn, rung, call) in ordered {
            XCTAssertEqual(occurrences(of: fn, in: config), 1,
                           "`\(fn)` is no longer unique — the window would open elsewhere (#408).")
            guard let a = config.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor this claim (§4).")
                return
            }
            let body = String(config[a.lowerBound...].prefix(1_800))
            guard let r = body.range(of: rung), let c = body.range(of: call) else {
                XCTFail("`\(rung)` or `\(call)` left the window under `\(fn)` — re-measure "
                        + "before widening it.")
                return
            }
            XCTAssertTrue(r.lowerBound < c.lowerBound, """
                The rung for `\(call)` sits AFTER the call again (#860/#878). A session move \
                that raises the ObjC assert then logs nothing, and the next crash log reads \
                as "path not taken" instead of naming the step.
                """)
        }

        // (c) AND THE MIRROR IMAGE, which is the part that is easy to get wrong: both
        //     transitions have a no-op guard, so the rung must sit AFTER it. Announcing a
        //     raise the guard then skips writes a step into the log that never happened —
        //     just as misleading as a trailing rung, and in the opposite direction.
        for (fn, noOpGuard, rung) in [
            ("static func upgradeToPlayAndRecord",
             "guard audioSession.category != .playAndRecord", "session: raise 1/2 — setCategory"),
            ("static func downgradeToPlaybackAfterRecording",
             "guard audioSession.category != .playback", "session: lower 1/1 — setCategory"),
        ] {
            guard let a = config.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor (§4). A bare `return` here would have "
                        + "exited the whole test method and reported GREEN (#907 review).")
                return
            }
            let body = String(config[a.lowerBound...].prefix(1_800))
            guard let g = body.range(of: noOpGuard), let r = body.range(of: rung) else {
                XCTFail("the no-op guard or its rung left `\(fn)` — re-anchor (§4).")
                return
            }
            XCTAssertTrue(g.lowerBound < r.lowerBound, """
                `\(fn)` announces its session move BEFORE the guard that may skip it (#878). \
                The log then names a step the code did not take.
                """)
        }

        // (c2) #906 — A SKIPPED STEP SAYS SO. Both category moves had a guard that
        //      returned in SILENCE, and the ladder's own law reads silence between two rungs
        //      as a DEATH: `releaseRecordRoute` printed "holders none, lowering" and returned
        //      TRUE while nothing had been lowered. The law is not new — `AudioEngine` has
        //      carried `on 4/5 SKIPPED:` since #862b — it simply had not reached this file.
        //
        // ⛔ #907 — #906 WROTE THEM NUMBERED (`raise 1/2 SKIPPED`) AND THAT LIED IN THE OTHER
        //    DIRECTION. `diag-ladder.py`'s LOG mode kept the LAST `raise n/2` it saw and had
        //    NO NOTION OF A SKIP — it has one for UNNUMBERED lines since #908 — so a healthy
        //    SECOND claim ended its ladder at 1/2 and the tool called a two-owner run a
        //    DEATH — on exactly the path #888 exists to illuminate. Reproduced on a
        //    synthetic log both ways. The literals below are unnumbered now, and (c3) below
        //    keeps the numbered form out. (⛔ #908's first draft retired (c3), believing the
        //    tool had made it safe; the review disproved that with a walks-on log. Restored.)
        //
        // ⭐ THE THIRD TUPLE IS NEW IN #907 — AND IT IS NOT A NO-OP GUARD, which is why the
        //    wording around it says "a guard" rather than "the no-op guard" (#907 review, M1).
        //    The two category comparisons really do find nothing to do; this one can return
        //    while the category IS raised, so its message carries "category left as-is".
        //    It was left silent by #906 on two reasons that were both measurably wrong: it
        //    fires after a THROWN configure too, and only one of the three claim sites
        //    configures first — so the
        //    session can sit on `.playAndRecord` with nobody holding it while the log says
        //    "holders none, lowering".
        //
        // ⚠️ THE ORDERING HERE IS THE OPPOSITE OF (b)'s, and that is the point: a SKIPPED
        //    line stands INSIDE the guard, i.e. AFTER the guard text and BEFORE the real
        //    rung. #878 forbids announcing a step the guard then skips; announcing that it
        //    WAS skipped is the honest half of the same law.
        //
        // ⚠️ ORDER ALONE IS NOT ENOUGH — the #907 review named the hole: lift the emitter OUT
        //    of the `else { }` onto the statement right after the guard and `g < s < r` still
        //    holds, while the line now fires on EVERY successful move. So ADJACENCY is pinned
        //    too: the emitter must be followed immediately by the guard's own `return`, which
        //    is exactly what it cannot be outside the block.
        for (fn, noOpGuard, skipped, rung) in [
            ("static func upgradeToPlayAndRecord",
             "guard audioSession.category != .playAndRecord",
             "session: raise SKIPPED — category already .playAndRecord",
             "session: raise 1/2 — setCategory"),
            ("static func downgradeToPlaybackAfterRecording",
             "guard isSessionConfigured else",
             "session: lower SKIPPED — never configured; category left as-is",
             "session: lower 1/1 — setCategory"),
            ("static func downgradeToPlaybackAfterRecording",
             "guard audioSession.category != .playback",
             "session: lower SKIPPED — category already .playback",
             "session: lower 1/1 — setCategory"),
        ] {
            XCTAssertEqual(occurrences(of: skipped, in: config), 1, """
                a guard in `\(fn)` no longer says it skipped (#906/#907). It then returns \
                in silence while its caller has already written a line implying the move \
                happened — and by this ladder's own law (#859–#862b) the silence that \
                follows reads as a death inside the step, not as a step that never ran.
                """)
            let emitter = "EchoelCrashLog.breadcrumb(\"\(skipped)\")"
            guard let e = config.range(of: emitter) else {
                XCTFail("the SKIPPED emitter for `\(fn)` is gone — re-anchor (§4).")
                return
            }
            // ⚠️ INDENTATION IS DELIBERATELY NOT PART OF THE NEEDLE. A hard `"\n            "`
            //    would go RED the day the guard is nested one level deeper — a false red on a
            //    correct tree, which is the defect class this bundle exists to avoid (#665).
            //    Only "nothing but whitespace between the emitter and a `return`" is asserted.
            let afterEmitter = config[e.upperBound...].drop { $0.isWhitespace }
            XCTAssertTrue(afterEmitter.hasPrefix("return"), """
                the SKIPPED emitter in `\(fn)` is no longer the last statement before its \
                guard's `return` (#907 review). Outside the `else { }` block the same line \
                fires on every SUCCESSFUL move, so the log then claims a skip that did not \
                happen — the ordering claim below cannot see that, which is why this exists.
                """)
            guard let a = config.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor (§4). A bare `return` here would have "
                        + "exited the whole test method, taking the remaining tuples, the "
                        + "(c4) claims and the (d) count pin with it, and reported GREEN.")
                return
            }
            let body = String(config[a.lowerBound...].prefix(1_800))
            guard let g = body.range(of: noOpGuard), let s = body.range(of: skipped),
                  let r = body.range(of: rung) else {
                XCTFail("the guard, its SKIPPED line or the real rung left `\(fn)` — "
                        + "re-anchor (§4).")
                return
            }
            XCTAssertTrue(g.lowerBound < s.lowerBound && s.lowerBound < r.lowerBound, """
                the SKIPPED line in `\(fn)` is no longer INSIDE the guard it belongs to. It \
                must sit after the guard and before the real rung: ahead of the guard it \
                announces a skip that may not happen, and after the rung it describes a step \
                that did.
                """)
        }

        // (c3) #907, RESTORED BY THE #908 REVIEW — a SKIPPED step that EXITS must not carry
        //      a rung number. #908's first draft retired this, on the reasoning that the tool
        //      had been taught to read the numbered form. That was wrong, and the review
        //      proved it with a log: `on 4/5 SKIPPED` in `AudioEngine` WALKS ON (`on 5/5:
        //      installing input tap` follows), so a log ending on that line is a death in the
        //      TAP REGION — the `isInputConnToConverter` family the ladder exists for — and
        //      (⚠️ #956: that region gained a node-format read and a SECOND skip reason, so an
        //      end there can also be a REPORT; the twin note in this file's header says the
        //      same, and #456's law is that a repair goes into every home, not the one you
        //      happened to be editing)
        //      the draft printed `⏹ ended`, exit 0, telling the reader not to look there.
        //
        // ⭐ THE REASON IT CANNOT BE FIXED IN THE TOOL: in a LOG, a numbered skip that WALKS ON
        //    and a numbered skip that RETURNS are the SAME SHAPE. Nothing in the line tells
        //    them apart, so the tool must read both as deaths — and this guard is what keeps
        //    the returning kind out of the source. `scripts/diag-ladder.py` now rescues only
        //    an UNNUMBERED terminator, which claims no step and therefore cannot be ambiguous.
        //    So the division of labour is: the TOOL learned `mic: start REFUSED` (mid-ladder,
        //    unnumbered — the case no wording could fix); this CLAIM keeps the ambiguous
        //    spelling out. Neither replaces the other.
        //
        // ⛔ GRADED: red on `da06482` (#906) — it selects both numbered lines — and green on
        //    the worktree. `AudioEngine`'s two legal `on 4/5 SKIPPED:` lines are NOT selected
        //    (their next line is `}`, and `setInputMonitoring` returns `Bool`). What
        //    protects those two lines is claim 12, which pins them PRESENT.
        // ⭐ #913: this half is no longer a tripwire — the two new unnumbered pre-rung skips
        //    (`on SKIPPED`, `off SKIPPED`) ARE selected here and pass, so `AudioEngine` is a
        //    live counterweight. The tripwire caught its first case, which is the outcome a
        //    tripwire is written for.
        for (path, text) in [("Audio/AudioConfiguration.swift", config),
                             ("Audio/AudioEngine.swift",
                              try code("Sources/Echoelmusic/Audio/AudioEngine.swift"))] {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            for (i, line) in lines.enumerated() where line.contains("SKIPPED") {
                let next = lines.dropFirst(i + 1)
                    .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                guard next.hasPrefix("return") || next.hasPrefix("throw") else { continue }

                // Read the MESSAGE, never the line: the stripper only drops lines that BEGIN
                // with `//`, so a trailing `// #907: was 1/2` survives and a raw-line scan
                // would redden a line carrying no number at all.
                guard let open = line.firstIndex(of: "\""),
                      let close = line.lastIndex(of: "\""), open < close else { continue }
                let message = String(line[line.index(after: open)..<close])
                XCTAssertFalse(message.contains("\\("), """
                    a SKIPPED breadcrumb in `\(path)` builds its rung number by interpolation:
                    \(line.trimmingCharacters(in: .whitespaces))
                    Neither this claim nor `scripts/diag-ladder.py` can read that — the tool's \
                    rung regex allows no interpolation in a prefix, so the rung vanishes from \
                    `--source` entirely and the ladder silently reports one emitter fewer.
                    """)
                XCTAssertFalse(carriesRungNumber(message), """
                    a SKIPPED step in `\(path)` is NUMBERED and then exits (#907/#908):
                    \(line.trimmingCharacters(in: .whitespaces))
                    In a LOG this is indistinguishable from a skip that WALKS ON, so \
                    `scripts/diag-ladder.py` must read it as a death — and it will, on a run \
                    that was healthy. Drop the number: an UNNUMBERED skip is a state line the \
                    tool rescues correctly. Numbering stays honest only where the ladder walks \
                    on past it (`on 4/5 SKIPPED`, with `on 5/5` following).
                    """)
            }
        }

        // (c4) #908 — AND THE CLASS BEHIND #906 AND #907 BOTH: a SILENT exit on a route
        //      transition. The #907 review named it — "nothing in the file detects a NEW
        //      silent return added to either function" — which is exactly how the
        //      `isSessionConfigured` gap survived a whole cycle. Every exit from the two
        //      session moves must ANNOUNCE itself. No number to go stale (#903).
        //
        // ⛔ ITS FIRST DRAFT WAS WRONG IN BOTH DIRECTIONS, mutation-driven by the #908 review:
        //    it FALSE-REDDENED a wrapped breadcrumb (the form written in the very file it
        //    scans, `route: release … FAILED (`), a widened `#if os(macOS) || os(watchOS)`,
        //    and a `return` inside a nested closure; and it stayed GREEN on `if x { return }`,
        //    on `else{return}` without inner spaces, on a trailing-comment `return`, and on a
        //    silent `throw` — the last a straight regression, since the claim it replaced
        //    covered `throw` explicitly. Both halves are rewritten below.
        //
        // ⭐ GRADED ACROSS THREE TREES: `b0d6480` → BOTH functions red, `da06482` (#906) →
        //    `downgradeToPlaybackAfterRecording` red, worktree → green. Plus four mutants
        //    driven on the worktree: wrapped breadcrumb GREEN, trailing comment GREEN,
        //    `if … { return }` RED, silent `throw` RED.
        for fn in ["static func upgradeToPlayAndRecord",
                   "static func downgradeToPlaybackAfterRecording"] {
            guard let a = config.range(of: fn) else {
                XCTFail("`\(fn)` is gone — re-anchor (§4). This `return` exits the whole test "
                        + "method, so the claims below it do not run either (#907 review).")
                return
            }
            // Bounded by the NEXT declaration, never by a character budget: a window that
            // overruns into the next function counted five exits where there are two.
            let rest = config[a.upperBound...]
            let end = rest.range(of: "\n    static func")?.lowerBound ?? rest.endIndex
            let body = String(rest[..<end])

            // Whitespace-squashed, so `else { return }`, `else{return}` and `if x { return }`
            // are one shape. `{throw` is here because both functions are `throws`.
            let squashed = body.split(whereSeparator: { $0.isWhitespace }).joined()
            for silent in ["{return", "{throw"] {
                XCTAssertFalse(squashed.contains(silent), """
                    `\(fn)` has a one-line silent exit (`\(silent)…`) — an exit on a route
                    transition that writes nothing (#908). Its caller has already written
                    `route: …`, so by this ladder's own law (#859–#862b) the silence that
                    follows reads as a death inside the step. Put a breadcrumb in the block
                    before the exit, unnumbered.
                    """)
            }

            let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let statement = trimmed.components(separatedBy: "//")[0]
                    .trimmingCharacters(in: .whitespaces)
                guard statement == "return" || statement.hasPrefix("return ")
                        || statement.hasPrefix("throw ") else { continue }

                // Walk back to the line that OPENS the enclosing block and look at the whole
                // block, not at one line: the announcing breadcrumb is often wrapped over two.
                var block: [String] = []
                var compileTimeOnly = false
                for previous in lines[..<i].reversed() {
                    let p = previous.trimmingCharacters(in: .whitespaces)
                    if p.isEmpty { continue }
                    if p.hasPrefix("#if os(macOS)") { compileTimeOnly = true; break }
                    if p.hasSuffix("{") { break }
                    block.append(p)
                }
                if compileTimeOnly { continue }

                XCTAssertTrue(block.contains { $0.contains("EchoelCrashLog.breadcrumb(") }, """
                    an exit in `\(fn)` is not announced (#908):
                    \(trimmed)
                    Nothing in its block writes a breadcrumb, so the log shows `route: …`
                    followed by silence and the next reader calls that a death. The
                    `#if os(macOS)` return is exempt — it is compile-time, so no iOS log can
                    ever show it.
                    """)
            }
        }

        // (d) The rung count is pinned so a rung added to a REPEATING path is visible. It is
        //     a checklist, not an objection. If this number moved, check the new site is a
        //     discrete lifecycle event and not something that runs per buffer — `breadcrumb`
        //     allocates and does an unbuffered `write(2)`.
        //
        // ⛔ #903 — THIS PIN WAS RED ON A CORRECT TREE FOR THIRTEEN COMMITS, and that is the
        // whole reason it exists. It said 8: seven transition rungs plus `latencyBreadcrumb`.
        // #888 then added THREE `route:` lines (one claim, two release) and did not come back
        // here — its commit message says "the tool still derives exactly 8 ladders", which is
        // `diag-ladder.py`'s ladder count, a DIFFERENT quantity that happens to share the
        // number. Measured: `bd38cc3~1` = 8, `bd38cc3`…#902's parent = 11, today = 12. Nothing
        // caught it because §5 holds — the pipeline reports `failure` on every push, so a
        // genuinely red guard is indistinguishable from the host dying (#655/#656).
        //
        // ⚠️ AND #902 WALKED PAST IT AGAIN. Its commit message claims "all eleven neighbouring
        // claims over this file drive GREEN on both trees". This is the TWELFTH, it is over
        // this file, and it counts the very line #902 added — the #453→#477 rule reproduced
        // exactly: a hand survey said eleven, and a guard selected a twelfth.
        //
        // ⭐ #906 — AND THE TOOL WRITTEN FOR THIS PIN CAUGHT ITS NEXT MOVE, ONE CYCLE LATER.
        // #906 added two SKIPPED lines; `python3 scripts/count-pins.py` printed
        // `pinned 12, actual 14` before the commit existed. The same drift went unseen for
        // thirteen commits when only CI was watching (#903). That is the whole argument for
        // the checker, in one line of output.
        //
        // ⭐ #907 — AND IT CAUGHT ITS OWN NEXT MOVE AGAIN, WHICH IS THE POINT OF A CHECKER
        // THAT RUNS LOCALLY: #907 gave the third silent return (`guard isSessionConfigured`)
        // a line, so the tool printed `pinned 14, actual 15` before the commit existed.
        //
        // ⭐ #961 — AND IT CAUGHT ITS OWN NEXT MOVE A THIRD TIME. #961 added the granted-rate
        // read-back after `setActive` (one unconditional line reporting asked-vs-granted, one
        // inside the `catch` of the buffer re-ask); `python3 scripts/count-pins.py` printed
        // `pinned 15, actual 17` before the commit existed. Both are discrete: they run once
        // per `configureAudioSession`, the same lifecycle event the four numbered rungs above
        // them already narrate — not a per-buffer or tick-rate path.
        //
        // ⭐ #968 — AND A FOURTH TIME, on the commit that made the rule systematic. #968 asked
        // the opposite question to every predecessor: not "does a new line belong here" but
        // "which lifecycle `catch` blocks in this file speak ONLY to os_log". Three did — the
        // buffer re-assert on downgrade, the reactivate after an interruption, the reconfigure
        // after a media-services reset — and the last two are the ones where audio is DEAD and
        // the exported log said nothing. `python3 scripts/count-pins.py` printed
        // `pinned 17, actual 20` before the commit existed. All three are discrete failure
        // events on a path the numbered rungs already narrate; none is per-buffer or tick-rate.
        //
        // ⛔ #1028 — AND THIS PIN WAS RED ON A CORRECT TREE, found by `count-pins.py` and by
        // nothing else. It read 20 while the file held 22, and both extra sites were added by
        // commits that judged them correctly and simply did not move the number. Neither gate
        // could say so: CI/CD reports `failure` on every push (#396), so a genuinely red guard
        // in the blocking bundle is indistinguishable from the host dying — the §4/§5 pattern,
        // now recorded a fourth time. The two sites, each already carrying its own reasoning
        // at the call site, and each checked against the rule this message states:
        //   · the `.playback` OPTION-SET refusal inside `configure` (#954/#961) — a `catch`
        //     that fires at most once per configure, deliberately UNNUMBERED so `diag-ladder`
        //     reads it as detail rather than a fifth rung of a four-rung ladder.
        //   · `applyStoredLatencyMode`'s refusal of the STORED buffer tier — one shot at
        //     launch, breadcrumb before `os_log` (#859), because a refusal that reaches only
        //     `os_log` is invisible in the file the founder shares.
        // Both are discrete failure events on a path the numbered rungs already narrate.
        // Neither is per-buffer or tick-rate, so both belong; the count follows them.
        //
        // TODAY'S ARITHMETIC: seven transition rungs + THREE `SKIPPED` state lines +
        // `latencyBreadcrumb` + one `route: claim` + THREE `route: release` outcomes +
        // the granted-rate line + the refused-re-ask outcome + THREE lifecycle-`catch`
        // outcomes (lower re-assert, interruption reactivate, media reset) + the
        // option-set-refusal fallback + the stored-tier refusal = 22.
        XCTAssertEqual(occurrences(of: "EchoelCrashLog.breadcrumb(", in: config), 22, """
            The breadcrumb count in AudioConfiguration changed. Confirm the new site is a \
            discrete event (launch, route transition, a lifecycle failure), never a per-buffer \
            or tick-rate path, then update this number and say why in the same commit. Today: \
            seven transition rungs + three SKIPPED state lines + latencyBreadcrumb + one route \
            claim + three route-release outcomes + the granted-rate read-back + its \
            refused-re-ask outcome + three lifecycle-catch outcomes + the option-set-refusal \
            fallback + the stored-buffer-tier refusal. RUN `python3 scripts/count-pins.py` \
            BEFORE PUSHING — this pin was red for a stretch of commits and no gate said so.
            """)
    }

    /// No `breadcrumb` line in the given source may interpolate the input UID.
    private func assertNoUIDInAnyBreadcrumb(_ source: String) throws {
        for line in source.split(separator: "\n", omittingEmptySubsequences: false)
        where line.contains("EchoelCrashLog.breadcrumb") {
            XCTAssertFalse(line.contains("\\(id)"), """
                A breadcrumb writes the raw input UID: \(line.trimmingCharacters(in: .whitespaces)). \
                A UID is opaque to a reader and can be MAC-derived on Bluetooth — it adds risk \
                and no information. Write the device label through \
                `AudioConfiguration.routeLabel` instead (#880).
                """)
        }
    }

    /// True when the message carries a ladder rung NUMBER (`n/N`) — the shape
    /// `scripts/diag-ladder.py` walks. Digit-slash-digit, no regex: a spaced division
    /// (`a / b`) is deliberately not a match, and neither is a bare `/` in prose.
    // ⛔ #1302 — `lineContaining(_:in:)` stood here and went with its last caller (the two
    // positional markers, above). It returned the single trimmed SOURCE line carrying a needle,
    // so a claim could read what the code emits instead of the literal the test file wrote
    // (#910 review, M3) — a shape worth re-adding rather than re-deriving.

    private func carriesRungNumber(_ line: String) -> Bool {
        let c = Array(line)
        guard c.count > 2 else { return false }
        for i in 1..<(c.count - 1) where c[i] == "/" {
            if c[i - 1].isNumber && c[i + 1].isNumber { return true }
        }
        return false
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func code(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let text = try String(contentsOf: root.appendingPathComponent(relativePath),
                              encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}
