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
            `releaseResources()` is released ABOVE the re-entry guard in `stop()`.

            That is the double-tap hazard claim 4 documents, wearing a different hat: the \
            SECOND caller returns at the guard while the FIRST is still writing frames, so a \
            release above the guard frees the pool out from under a live take.
            """)
    }

    // MARK: - 6. the release actually clears everything the creator set

    /// REGRESSION (#1198). Four fields are set by `ensureResources`; a release that clears
    /// three of them leaves `ensureResources` reading a stale size next to a nil pool — a
    /// state that says "wrong size" when it means "no pool". The flush is separate from
    /// dropping the reference: it makes the texture release happen at the end of the take
    /// rather than whenever the last reference dies.
    func testTheReleaseClearsEveryFieldTheCreatorSet() throws {
        let release = try memberBody(startingWith: "private func releaseResources()",
                                     in: Self.recorder).joined(separator: "\n")
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
