// RecordingCanBeStoppedWithoutThePictureTests.swift
// Echoel — a running take must be endable from where its indicator points. BLOCKING. #387.
//
// THE DEFECT. `EchoelClipsMonitorMini` (header) turns red while `VisualRecorder` is capturing
// and taps through to the Video panel. The panel's top row said "Record in the visual window"
// — an invitation to start what was already running — and offered no way to end it. The only
// Stop lived on the floating visual window's own toolbar, so hiding the picture left the take
// running with its stop button off-screen.
//
// ⛔ WHY THAT COMBINATION IS WORSE THAN A MISSING FEATURE. #319 deliberately made hiding the
// picture mid-take SUPPORTED: the renderer stays alive so the clip does not lose its image.
// That fix is what turns "no stop in the panel" from an inconvenience into a trap — the app
// now encourages exactly the state in which the only exit is invisible. The two halves have to
// ship as one behaviour, so this guard holds the second half shut.
//
// ⚠️ WHY A SOURCE SCAN. `VideoLibraryPanelContent` needs a live `VisualRecorder`, an
// `AVAudioEngine` behind it and a Metal device to reach the recording state at all, and there
// is no local toolchain to stand that up. House pattern (`BioFXReachesEveryChainTests`,
// `ActiveTargetsIsAPerEditFactTests`). It proves the path is WRITTEN; it cannot tap it.
//
// ⭐ CLAIMS 5–7 ADDED BY #1198 (2026-09-10). Same file, same function, adjacent law: claim 4
// pins WHERE the re-entry guard sits in `stop()`, and #1198's release has to sit directly
// below it for the same double-tap reason. One home (#416) — not a new bundle.
//
// GRADING of 5–7, transcribed in Python and driven against `git show HEAD:<path>` and the
// worktree:
//  · claims 5 and 6 — REGRESSION, and they are ONE finding with two witnesses (#486):
//    `releaseResources()` did not exist on the parent, so claim 5 finds no `defer` and claim 6
//    finds no member. Counting that as two catches would be the flattering direction (#433).
//  · claim 7 — COUNTERWEIGHT, green on both trees and deliberately so. It is only interesting
//    AFTER #1198: once the pool is released on every stop, the rebuild in `capture` is what
//    separates a recorder that works twice from one that works once — and that failure would
//    be SILENT (a nil pool returns early, and a take with no frames reports itself "empty").
//
// ⚠️ WHAT NO CLAIM HERE CAN SEE. Whether the memory actually comes back is an INSTRUMENTS
// reading on a device, not a source scan. What is pinned is that the release is written, sits
// in the one position that is safe, clears every field its creator set, and cannot leave the
// next take without a pool. NEEDS-FOUNDER-VERIFY: record two or three takes in a row and watch
// whether the app's memory returns to its pre-take level.
//
// ⛔ #1198b (same day) — THE MANDATORY REVIEW FOUND THAT #1198's CENTRAL ARGUMENT WAS WRONG,
// and the wrong half had been written into TWO homes (the source comment and claim 5's failure
// message). #1198 argued that PLACEMENT was sufficient: the `defer` sits below the re-entry
// guard, therefore it cannot fire under a live take. The guard describes ENTRY. The `defer`
// fires at EXIT — after `VideoMuxer.mux`, a full `AVAssetExportSession` re-encode lasting
// SECONDS. In that window `recordState` is terminal, the floating window's button reads
// "record" again, and `VideoRecorder.startRecording` accepts every terminal state by design.
// So a tap arms a NEW take and the finishing mux then released ITS pool. Self-healing (the
// next frame rebuilds) but a mid-take reallocation on a 60 Hz path at the start of a
// performance.
//
// The repair is one condition asked at FIRE time — `if !video.recordState.isRecording` — and
// claim 5 now asserts it. Claim 5 also gained the check its own doc implied and did not make:
// the release must precede the first `return` after the guard, because a `defer` at the BOTTOM
// of `stop()` satisfies "after the guard" and covers none of the early exits.
//
// CLAIM 8 is new and covers the edit site #1198 left completely unguarded: `capture` has five
// returns too, THREE of them after `ensureResources` has allocated, and #1198 released on the
// success path only with a trailing line — the same defect it exists to remove, one branch
// deeper. Both halves are pinned: DEFERRED (covers the failure branches) and CONDITIONAL
// (a running take keeps its pool instead of rebuilding it every frame).
//
// GRADING of the #1198b additions, transcribed against `git show HEAD:<path>` (= the #1198
// tree) and the worktree: claim 5's condition assertion — REGRESSION · claim 8 — REGRESSION ·
// claim 5's first-return assertion and claim 6's flush-order assertion — COUNTERWEIGHTS, green
// on both trees, added because each names a way to satisfy the letter of a claim and lose it.
//
// ⭐ THE LESSON, and it is about REVIEW rather than about video: two commits in a row shipped a
// defect that only the mandatory review caught, and both were the same shape — a change whose
// argument was true of one scenario and asserted generally. Neither would have gone red.

import Foundation
import XCTest

final class RecordingCanBeStoppedWithoutThePictureTests: XCTestCase {

    private static let panel = "Sources/Echoelmusic/Studio/VideoLibraryPanel.swift"
    private static let header = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    /// Named once (#1198 added three claims that read it; claim 4 spelled the path inline).
    private static let recorder = "Sources/Echoelmusic/Video/VisualRecorder.swift"

    /// ⭐ THE GUARD, and it is POSITIONAL rather than a pair of `contains`. "The file mentions
    /// `recorder.isRecording` somewhere" and "the file mentions `stopRow` somewhere" are both
    /// true of a panel that renders the stop row in the WRONG branch — i.e. of the defect with
    /// extra code in it. The stop row has to sit inside the recording branch.
    func testTheStopRowIsRenderedWhileRecording() throws {
        let body = try memberBody(startingWith: "var body: some View", in: Self.panel)
        guard let test = body.firstIndex(where: { $0.contains("if recorder.isRecording") }) else {
            return XCTFail("""
                the Video panel no longer branches on `recorder.isRecording` (#387):
                \(body.joined(separator: "\n"))
                """)
        }
        let elseIndex = body[(test + 1)...].firstIndex { $0.contains("} else {") } ?? body.endIndex
        let whileRecording = body[(test + 1)..<elseIndex]
        XCTAssertTrue(whileRecording.contains(where: { $0.contains("stopRow") }), """
            `stopRow` is no longer what the panel shows WHILE a clip is recording. Whatever \
            stands there instead, the take can only be ended from the visual window again — \
            and #319 made hiding that window mid-take a supported thing to do.
            branch: \(Array(whileRecording).map { $0.trimmingCharacters(in: .whitespaces) })
            """)
    }

    /// The row has to actually end the take AND surface the result. A stop without the reload
    /// is the quieter half of the same defect: the recording ends, the list below still shows
    /// what it showed a minute ago, and the clip the user just made looks lost.
    func testTheStopRowStopsAndRefreshes() throws {
        let row = try memberBody(startingWith: "private var stopRow: some View", in: Self.panel)
        XCTAssertTrue(row.contains(where: { $0.contains("await recorder.stop()") }), """
            `stopRow` no longer calls `recorder.stop()` — it is a button that says "stop" and \
            does not:
            \(row.joined(separator: "\n"))
            """)
        XCTAssertTrue(row.contains(where: { $0.contains("reload()") }), """
            `stopRow` no longer reloads the library after stopping. The clip lands in \
            Documents/Videos either way, but the list the user is looking at does not show it \
            until the panel is closed and reopened — which reads as a lost recording.
            """)
    }

    /// ⛔ THE INDICATOR AND THE EXIT ARE ONE FEATURE. The header tile is what tells the user a
    /// clip is capturing; if it stopped leading to this panel, the stop row above would be
    /// correct code nobody can find. Tied here so the two cannot drift apart silently.
    ///
    /// ⚠️ SAY IT PLAINLY: this test was ALREADY GREEN before #387 — the tile and its door were
    /// never the broken half. It is a ratchet, not a repro, and it is in this file rather than
    /// its own because it only earns its place next to the row it protects. Do not read a green
    /// here as evidence that the stop path works; the two tests above are the ones that moved.
    func testTheHeaderIndicatorStillLeadsToThisPanel() throws {
        let tile = try memberBody(startingWith: "struct EchoelClipsMonitorMini", in: Self.header)
        XCTAssertTrue(tile.contains(where: { $0.contains("recorder.isRecording") }), """
            the header clips tile no longer reports the recording state — nothing on the main \
            surface says a take is running.
            """)
        XCTAssertTrue(tile.contains(where: { $0.contains(#"object: "video""# ) }), """
            the header clips tile no longer opens the Video panel. That panel holds the only \
            Stop that is reachable while the picture is hidden (#387), so this tap is the \
            route to it — if the door moved, move this needle with it in the same commit.
            \(tile.joined(separator: "\n"))
            """)
    }

    /// ⛔ THE SECOND STOP MUST NOT SILENCE THE FIRST ONE'S CLIP. Adding a second tappable Stop
    /// (the panel row above) made an older hole reachable a second way: `VisualRecorder.stop()`
    /// had no entry guard, so two calls enqueued in the same run-loop turn interleaved —
    /// A sets `.finishing` and suspends inside `stopRecording`'s continuation, B falls through
    /// and nils `audioEngine`, A resumes and takes the "no audio" escape. The take is saved
    /// SILENT. Found by the reviewer on `691f213`.
    ///
    /// ⚠️ POSITIONAL, because position is the whole invariant. A guard placed anywhere after
    /// `audioEngine = nil` is decoration: the damage is already done by then. So the assertion
    /// is that it is the FIRST statement of the function, which is also the only place it can
    /// be while remaining correct.
    func testStoppingTwiceCannotStripTheAudio() throws {
        let stop = try memberBody(startingWith: "func stop() async -> URL?",
                                  in: Self.recorder)
        let statements = stop.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        XCTAssertEqual(statements.first, "guard video.recordState == .recording else { return nil }", """
            `VisualRecorder.stop()` does not OPEN with its re-entry guard. First statement is:
            \(statements.first ?? "<none>")

            Both Stop controls — the visual window's toolbar and the Video panel's row (#387) — \
            funnel through this one function, and a second entry that gets past this line nils \
            `audioEngine` out from under the first, which then saves the clip without its \
            master mix. A guard placed lower down cannot prevent that; it has to be first.
            """)
    }

    // MARK: - 5. the take hands its pooled frame memory back

    /// REGRESSION (#1198). `ensureResources` built a `CVPixelBufferPool` and a
    /// `CVMetalTextureCache` on the first captured frame and NOTHING released them. A pool
    /// RECYCLES rather than frees, so every buffer it ever handed out stayed resident: at
    /// 1080p BGRA that is 1920 × 1080 × 4 ≈ 8.3 MB each, held for the rest of the process, in
    /// IOSurface memory rather than on the heap — which is why it is invisible where a session
    /// would look for it. Measured against the founder's 2026-09-09 report of intermittent
    /// memory growth; this is the half of it that is genuinely memory.
    ///
    /// ⚠️ POSITIONAL, for the same reason claim 4 is. The release must sit BELOW the re-entry
    /// guard: the second caller of a double-tap returns above that line while the FIRST is
    /// still writing, and releasing there would pull the pool out from under a live take. A
    /// `contains` check would call both placements correct.
    func testStoppingATakeReleasesThePooledFrameMemory() throws {
        let stop = try memberBody(startingWith: "func stop() async -> URL?",
                                  in: Self.recorder)
        let statements = stop.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let guardIndex = statements.firstIndex(of:
                "guard video.recordState == .recording else { return nil }") else {
            XCTFail("""
                the re-entry guard is gone from `stop()` — claim 4 says what that costs. \
                Claim 5 is positional relative to it and cannot be graded without it.
                """)
            return
        }
        guard let releaseIndex = statements.firstIndex(where: {
            $0.contains("defer") && $0.contains("releaseResources()")
        }) else {
            XCTFail("""
                `VisualRecorder.stop()` no longer defers `releaseResources()`.

                Without it the pixel-buffer pool and the Metal texture cache built for the take \
                stay resident for the whole process — a pool recycles, it does not free, so \
                ~8.3 MB per 1080p buffer never comes back. `defer` and not a trailing line \
                because `stop()` has five returns and the two failure ones (writer refused / no \
                frame arrived) are precisely the runs a user retries immediately.

                This does NOT forbid moving the release elsewhere (#364) — but if it moves, the \
                #1198 block in `stop()` and this claim move with it, in the same commit.
                """)
            return
        }
        XCTAssertGreaterThan(releaseIndex, guardIndex, """
            `releaseResources()` is deferred ABOVE the re-entry guard in `stop()`.

            That is the double-tap hazard claim 4 documents, wearing a different hat: the \
            SECOND caller returns at the guard while the FIRST is still writing frames.
            """)
        // ⭐ #1198b — POSITION IS NOT ENOUGH, AND THE FIRST VERSION OF THIS CLAIM STOPPED HERE.
        // A `defer` written at the BOTTOM of `stop()` — below `guard let videoURL else` —
        // satisfies "after the guard" and does NOT run for two of the five returns, i.e.
        // exactly the failure this claim's own doc says it exists to prevent. One more line
        // closes it: the release has to precede the first `return` after the guard.
        if let firstReturn = statements[guardIndex...].dropFirst()
            .firstIndex(where: { $0.hasPrefix("return ") || $0 == "return" }) {
            XCTAssertLessThan(releaseIndex, firstReturn, """
                the deferred release sits BELOW an early `return` in `stop()`. `defer` only \
                covers exits that happen after it is REGISTERED, so every return above it is \
                unguarded — and the two easiest to write above it are the failure returns, \
                which are the runs a user retries immediately.
                """)
        }
        // ⛔ AND THE CONDITION IS THE #1198b REPAIR ITSELF. The first version relied on
        // placement alone and its comment argued that placement below the guard was
        // sufficient. It is not: the guard proves `.recording` AT ENTRY, the `defer` fires at
        // EXIT — after a `VideoMuxer.mux` that runs for seconds, by which time the button has
        // flipped back to "record" and a tap can arm a NEW take. Found by the mandatory
        // review. Asking the state at FIRE time is what makes the placement claim true.
        XCTAssertTrue(statements[releaseIndex].contains("!video.recordState.isRecording"), """
            the deferred release in `stop()` is unconditional. It fires at EXIT, after \
            `VideoMuxer.mux` — a full `AVAssetExportSession` re-encode lasting seconds. In \
            that window `recordState` is already terminal, the window's button reads "record" \
            again, and `VideoRecorder.startRecording` accepts every terminal state. An \
            unconditional release then tears down the pool of the take that is now running.

            Placement below the re-entry guard does NOT cover this — that guard describes \
            entry, this `defer` describes exit.
            """)
    }

    // MARK: - 8. the capture path releases on its failure branches too

    /// REGRESSION (#1198b). `capture(from:in:device:)` has five returns as well, and THREE of
    /// them are after `ensureResources` has already built the pool and the cache. The first
    /// version of #1198 released on the success path only, with a trailing line — reproducing
    /// the very defect it was written to remove, one branch deeper and silently. Found by the
    /// mandatory review, not by a guard, which is why this claim exists.
    ///
    /// Both halves are asserted: the release is DEFERRED (so the failure branches are covered)
    /// and it is CONDITIONAL (so a running take keeps its pool instead of rebuilding it at
    /// 60 Hz, which the source calls "the opposite trade").
    func testTheCapturePathReleasesOnEveryExitButNotDuringATake() throws {
        let capture = try memberBody(
            startingWith: "func capture(from source: MTLTexture", in: Self.recorder)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let releaseIndex = capture.firstIndex(where: {
            $0.hasPrefix("defer") && $0.contains("releaseResources()")
        }) else {
            XCTFail("""
                `capture(from:in:device:)` does not DEFER its release. A trailing line covers \
                the success path only, and three of this function's five returns happen after \
                `ensureResources` has already allocated.
                """)
            return
        }
        XCTAssertTrue(capture[releaseIndex].contains("!video.recordState.isRecording"), """
            the release in `capture` is unconditional. During a take the next frame is 1/60 s \
            away, so releasing here rebuilds the pool and the texture cache EVERY FRAME — the \
            opposite of what #1198 is for, and it would leave claims 5, 6 and 7 green.
            """)
        if let build = capture.firstIndex(where: { $0.hasPrefix("ensureResources(width:") }) {
            XCTAssertLessThan(releaseIndex, build, """
                the deferred release is registered AFTER `ensureResources`. `defer` covers only \
                exits below its registration, so the branches between the allocation and this \
                line are exactly the ones left uncovered.
                """)
        }
    }

    // MARK: - 6. the release actually clears everything the creator set

    /// REGRESSION (#1198). Four fields are set by `ensureResources`; a release that clears
    /// three of them leaves `ensureResources` reading a stale size next to a nil pool — a
    /// state that says "wrong size" when it means "no pool". The flush is separate from
    /// dropping the reference: it makes the texture release happen at the end of the take
    /// rather than whenever the last reference dies.
    func testTheReleaseClearsEveryFieldTheCreatorSet() throws {
        let lines = try memberBody(startingWith: "private func releaseResources()",
                                   in: Self.recorder)
        let release = lines.joined(separator: "\n")
        // ⭐ #1198b — ORDER, not just presence. `contains` on a joined string cannot see that
        // the flush comes AFTER the nil, which would make it a no-op and stay green.
        if let flush = lines.firstIndex(where: { $0.contains("CVMetalTextureCacheFlush") }),
           let drop = lines.firstIndex(where: { $0.contains("textureCache = nil") }) {
            XCTAssertLessThan(flush, drop, """
                `releaseResources()` flushes the texture cache AFTER dropping the reference to \
                it, which flushes nothing. The flush is what makes the texture release happen \
                at the end of the take rather than whenever the last reference dies.
                """)
        }
        for needle in ["CVMetalTextureCacheFlush", "textureCache = nil", "pool = nil",
                       "poolWidth = 0", "poolHeight = 0"] {
            XCTAssertTrue(release.contains(needle), """
                `releaseResources()` no longer does `\(needle)`.

                `ensureResources` decides on `pool == nil || poolWidth != width`, so the size \
                fields and the pool have to be cleared together or the next take reads a state \
                that cannot occur.
                """)
        }
    }

    // MARK: - 7. counterweight — a released pool is rebuilt, not missed

    /// COUNTERWEIGHT (#343). Claims 5 and 6 are only safe while the capture path still REBUILDS
    /// what they tear down. If `ensureResources` ever stops being called before the pool is
    /// read, #1198 turns from a memory fix into a recorder that works exactly once — the
    /// failure would be silent, because `capture` returns early on a nil pool and a take with
    /// no frames reports itself as "empty".
    func testTheCapturePathStillRebuildsWhatTheStopReleased() throws {
        let capture = try memberBody(
            startingWith: "func capture(from source: MTLTexture", in: Self.recorder)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let build = capture.firstIndex(where: { $0.hasPrefix("ensureResources(width:") }),
              let read = capture.firstIndex(where: { $0.contains("let cache = textureCache") })
        else {
            XCTFail("""
                `capture(from:in:device:)` no longer both builds (`ensureResources(width:`) and \
                reads (`let cache = textureCache`) the pooled resources. #1198 releases them on \
                stop, so this rebuild is what keeps a SECOND take possible. Re-anchor both \
                needles rather than dropping this claim.
                """)
            return
        }
        XCTAssertLessThan(build, read, """
            `capture` reads the pool before it ensures it. After #1198 the pool is nil at the \
            start of every take, so this ordering is the difference between a recorder that \
            works twice and one that works once.
            """)
    }

    // MARK: - 9. the frame OWNS the texture it is the destination of

    /// REGRESSION (#1204). `CVMetalTextureGetTexture` hands back a texture CoreVideo owns; it
    /// is valid only while its `CVMetalTexture` wrapper lives. In `capture` the wrapper's last
    /// USE was that one getter call, and Swift ARC is not scope-based — so it could be released
    /// there, while the blit it is the DESTINATION of is still in flight. Release the wrapper
    /// early and `CVMetalTextureCacheFlush` — which `releaseResources` calls — is free to treat
    /// the cache entry as unused and recycle it under the GPU.
    ///
    /// ⛔ SAY THAT NARROWLY. An earlier draft of this claim said the destination "stayed alive
    /// only because" `MetalBioView` uses `makeCommandBuffer()`. The mandatory review measured
    /// that down: `box.pb` already pins the IOSurface and `dst` is a strong reference the
    /// retained command buffer also holds, so the OBJECT was never at risk of deallocation.
    /// What was unheld is the WRAPPER, which is what marks the cache entry in use. Smaller
    /// hazard, still real, and enough on its own.
    ///
    /// ⚠️ THE SLICE ALSO CREATED A NEED IT HAD TO ANSWER, which is why `cache` is boxed too:
    /// once a `CVMetalTexture` provably outlives `capture`, `releaseResources()` setting
    /// `textureCache = nil` — reachable from `stop()` with a blit in flight — raises exactly
    /// the question this file answers explicitly for the pool. Owning it beats assuming it.
    ///
    /// ⚠️ IT DOES NOT RETIRE THE CROSS-FILE INVARIANT: the blit has TWO textures and the
    /// SOURCE is the drawable, which this file does not own. Asserting the fix generally when
    /// it covers one half is #1198b's exact mistake.
    ///
    /// SOURCE-TEXT SCAN (§1): it proves the ownership is written down, not that a GPU ran.
    ///
    /// ⛔ AND THE `dead-needles.py` GREEN DOES NOT COVER THESE NEEDLES. An earlier draft of
    /// this header claimed that tool would have caught a needle that cannot match. It would
    /// not: its shape 3 only reads a `contains` assertion whose receiver is PROVABLY source
    /// text — the `Self.` binds it knows, or a helper that provably returns
    /// `SourceText.codeOnly(…)`. This file binds through its own hand-rolled `codeLines`, so
    /// NONE of its nine claims are in that net. The needles here were transcribed by hand
    /// against both trees instead; that is the evidence, not the tool's exit code.
    ///
    /// GRADING against `git show HEAD:<path>` (§3), transcribed in Python (§0, no toolchain):
    /// FOUR REGRESSIONS — the two fields, the argument pair, and the USE. The USE is its own
    /// finding, not a second witness: a captured field nothing reads is a dead capture and may
    /// be dropped, so owning without using proves nothing. Its POSITION is a fifth, separate
    /// assertion for the same reason claim 8 checks order — see the note on it below.
    /// THREE COUNTERWEIGHTS, green on both trees (#343).
    ///
    /// ⛔ A SIXTH NEEDLE WAS WRITTEN AND REMOVED BEFORE IT SHIPPED, because it could only ever
    /// have been red: it pinned the `releaseResources` warning about `MetalBioView`'s
    /// command-buffer choice — text that lives ONLY in a `///` block, which `codeLines` drops.
    /// A prose obligation belongs in a failure MESSAGE, not in a scan (the same reason
    /// CLAUDE.md deliberately gets no text-scan guard, #491). It is in the first message below.
    func testTheBoxedFrameOwnsItsDestinationTexture() throws {
        let text = try codeLines(Self.recorder).joined(separator: "\n")

        XCTAssertTrue(text.contains("let tex: CVMetalTexture"), """
            `FrameBox` no longer carries the frame's `CVMetalTexture`. Releasing that wrapper \
            while the blit is in flight lets `CVMetalTextureCacheFlush` recycle the cache \
            entry under the GPU (#1204). If you removed the field on purpose, pull the ⭐ block \
            on `FrameBox` and the safety bullets of `releaseResources` along in the SAME \
            commit (#364).
            """)

        XCTAssertTrue(text.contains("let cache: CVMetalTextureCache"), """
            `FrameBox` no longer carries the texture cache. #1204 made that load-bearing: a \
            boxed `CVMetalTexture` now provably outlives `capture`, and `releaseResources()` \
            — reachable from `stop()` with a blit in flight — sets `textureCache = nil`. \
            Whether a `CVMetalTexture` retains its cache is then an ASSUMPTION; owning it is \
            the answer this file gives for the pool one bullet away.
            """)

        // ⚠️ ONE assertion for both arguments on purpose. `CVPixelBuffer` and `CVMetalTexture`
        // are both typealiases of `CVImageBuffer`, so the call site would compile with `pb:`
        // and `tex:` swapped — the labels are the only thing separating them.
        XCTAssertTrue(text.contains("tex: cvTex, cache: cache"), """
            the `FrameBox` built in `capture` no longer receives the texture wrapper and its \
            cache, so the fields exist and own nothing (#1204).
            """)

        // Its own finding, not a second witness for the fields: a stored field that nothing
        // reads is a DEAD capture. Ownership a compiler may optimise away is a belief about
        // optimisation, which is the class of argument this repo keeps retracting.
        for held in ["withExtendedLifetime(box.tex) {}", "withExtendedLifetime(box.cache) {}"] {
            XCTAssertTrue(text.contains(held), """
                `\(held)` is gone. Nothing in the GPU-completion handler then USES that boxed \
                value, so the capture is dead and may be dropped; `withExtendedLifetime` is \
                the documented way to hold it to the one moment it stops being needed. Two \
                separate calls on purpose — one call over a tuple would rest on `_fixLifetime` \
                keeping every element of an aggregate alive, which is a belief about lowering \
                (#1204).
                """)
        }

        // ⭐ POSITION, not presence — the fifth assertion, and the mandatory review is what
        // asked for it. Move the `withExtendedLifetime` line up beside `let box = …` and every
        // assertion above stays green while the fix is VOID: the lifetime would end inside
        // `capture`, which is exactly the pre-#1204 state. Same defect claim 1 in this file is
        // written positionally to avoid.
        let capture = try memberBody(
            startingWith: "func capture(from source: MTLTexture", in: Self.recorder)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let handler = capture.firstIndex(where: {
            $0.hasPrefix("commandBuffer.addCompletedHandler")
        }) else {
            XCTFail("""
                `capture` no longer registers a GPU-completion handler. #1204's whole claim is                 that the destination texture lives until that handler runs; with no handler                 there is nothing for the boxed lifetime to reach.
                """)
            return
        }
        guard let hold = capture.firstIndex(where: {
            $0.hasPrefix("withExtendedLifetime(")
        }) else {
            XCTFail("the lifetime extension is gone from `capture` entirely (#1204).")
            return
        }
        XCTAssertGreaterThan(hold, handler, """
            the `withExtendedLifetime` call sits OUTSIDE the GPU-completion handler. Then the             wrapper's lifetime ends when `capture` returns — the exact state #1204 exists to             leave, with every presence check still green.
            """)

        // COUNTERWEIGHT: the thing being boxed must still be the thing the blit writes into.
        // Box a different wrapper and every assertion above stays green.
        XCTAssertTrue(text.contains("let dst = CVMetalTextureGetTexture(cvTex)"), """
            the blit destination is no longer derived from `cvTex`, so boxing `cvTex` no \
            longer extends the lifetime of anything this frame writes into (#1204).
            """)

        // COUNTERWEIGHT: the release path this all guards must still exist. If `stop()` stopped
        // releasing, the ownership argument above would be true and pointless.
        XCTAssertTrue(text.contains("CVMetalTextureCacheFlush(textureCache, 0)"), """
            `releaseResources` no longer flushes the texture cache. That flush is the hazard \
            #1204's boxed wrapper exists to be safe against; without it this claim guards a \
            danger that is no longer there, and the prose above must be re-argued (#364).
            """)
    }

    // MARK: - Source helpers

    /// Lines of a member, from the line that starts with `prefix` to the closing `}` at that
    /// line's OWN indentation. Structural, not a line count.
    private func memberBody(startingWith prefix: String, in path: String) throws -> [String] {
        let lines = try codeLines(path)
        guard let start = lines.firstIndex(where: { $0.contains(prefix) }) else {
            XCTFail("""
                `\(prefix)` is gone from \(path). If it was renamed, move this guard with it — \
                do not leave a check for a member that no longer exists.
                """)
            return []
        }
        let indent = lines[start].prefix { $0 == " " }.count
        let close = lines[(start + 1)...].firstIndex {
            $0.trimmingCharacters(in: .whitespaces) == "}"
                && $0.prefix { c in c == " " }.count == indent
        } ?? lines.endIndex
        return Array(lines[start..<close])
    }

    /// Every line that is not a whole-line comment. Load-bearing: the ⭐ block above the
    /// `recorder` declaration quotes `recorder.isRecording` and the old row's wording verbatim
    /// while explaining them, and a scan that read prose would count the explanation as code.
    private func codeLines(_ path: String) throws -> [String] {
        let url = try repoRoot().appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    /// Repo root, derived from this file's compile-time path (`Tests/CISmoke/…`).
    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("""
                source tree not present at \(sources.path) — this test inspects source text, so \
                it SKIPS rather than reporting a green it did not earn
                """)
        }
        return root
    }
}
