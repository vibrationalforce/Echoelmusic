// TheVideoFrameIsPulledOnTheDrawTests.swift
// Echoel — GMMW VV-5b. A playing video's frames reach the visual through ONE lock leaf,
// `Studio/VideoLayerSlot.swift`, which every renderer of the field PULLS from inside `draw(in:)`:
// no queue of its own, no task, no observer, no delegate, nothing observable — and the VV-4 flash
// limiter counting every draw, deciding the gain on the very draw it counts, the layer as the screen
// shows it, on the display clock.
//
// ⚠️ SCOPE: NOTHING ATTACHES A VIDEO OUTPUT YET (claim 16). After this slice the picture is the
// pre-VV-5b field on every device; the first producer is VV-6 (it waits on VV-3) or VV-8.
//
// KIND, per assertion (Tests/CISmoke/CLAUDE.md §1):
// · SOURCE-TEXT SCANS — claims 1, 2, 3, 4, 16; the MSL half of 6; the renderer halves of 15 and 18.
//   They prove where text sits, never that a frame is shown. The stripper is TRAGEND for claim 1
//   (`@MainActor` occurs twice in the slot's own header comment and 0 times in its code: 1 of 22
//   banned tokens flips on raw text) and PROPHYLAKTISCH for every other scan.
// · END-TO-END BEHAVIOUR — claims 5–15 and 17–19 drive the shipped static functions and the REAL
//   pull, with a stand-in for `AVPlayerItemVideoOutput` (`VideoFrameOutput`: the three calls the slot
//   makes) and real CoreVideo 4:2:0 buffers. Nothing here mocks the slot itself.
// · DEVICE PROBES — open, none of this can see them: that `AVPlayerItemVideoOutput(outputSettings:)`
//   ACCEPTS the recipe (how it treats a key it does not take — accept, ignore or raise — is
//   unmeasured, and this bundle deliberately does not construct one: a raise would kill the test
//   host and read exactly like #396, taking every later guard's run with it); that the output
//   honours the 4:2:0 format and the size cap; what it does with a 601, wide-gamut or HDR clip; that
//   its buffers arrive in the track's natural orientation, so `preferredTransform` turns a portrait
//   clip upright; that a frame renders at all; memory, heat and the cost of the CPU read at 1080p.
//
// ⚠️ HONEST GRADING (§3), against the parent `70da6bb97`. This file DOES NOT COMPILE there — it names
// `VideoLayerSlot`, `VideoFrameOutput` and `footageDropped`, which this commit creates — so NO
// assertion has a verdict on the parent. Transcribed (§0) in Python against both trees instead:
// · FORWARD, one absence reported several times (#486) — the slot file is absent there: claims 1
//   and 2; claim 3's three output-call sites and its two order scans; the slot half of 6; claim 4's
//   `makeUIView` writer and its count of one `footageSource =`; claim 18's renderer half.
// · COUNTERWEIGHTS, green on both trees: claim 3's one `.pullFootageFrame(` site and the pull inside
//   `refreshFootage`; claim 4's sweep (every `: some View {` and `-> some View {` block in Sources/,
//   524 on both trees, 0 extraction failures, 0 hits — PROPHYLACTIC); claim 6's MSL half; claim 15's
//   renderer half; claim 16, a SCOPE PIN (it counts `.attachVideoOutput(` callers: 0 on both trees).
// · Claims 5–15 and 17–19's behaviour: FORWARD, on new symbols. NOT RUN (no toolchain). The
//   expectations come from the algebra and `VideoFlashLimiter`'s stated rules (#442) and were driven
//   through an exact Python port of the limiter and the pull: the 10 Hz strobe engages on its fifth
//   whole-step transition, three display frames apart, i.e. strobe frame 12; the 3.75 Hz strobe on
//   frame 32; claim 19's 13-frame strobe on frame 52 — each only after a lead-in long enough that the
//   fade-in's own counted rise has left the one-second window (with a 246-pull lead-in the port
//   engages the 10 Hz strobe at frame 9).
// · ZERO regressions are claimed: nothing on the parent could have been wrong the way these assert.
// Mutants, and the claims that catch each. DRIVEN through the port, one switch per mutant: a count
// on a new buffer only (17 — the paused clip stays at 0.05); a second renderer counted as a draw of
// its own (19 — it never engages); a buffer that reaches the second renderer counted at its own time
// (19's third case — it never engages); no reset on a nil map (18); the dial left out of the count (14 —
// 0.0025 instead of 0.05); the gain applied one frame late (9, 10, 19); media time for the limiter
// (10, a rate-2 stand-in); an uneased dial (11, 12, 13, 18); no fade back after a gap (11); the dial
// kept climbing while nothing was shown (12, 13); a stale frame kept after a refused buffer (13).
// ARGUED, not driven: a queue/task/observer in the slot (1); an unpaired unlock or a second instance
// (2); a second caller of the output, or the dial eased after the count (3 — in the port that mutant
// shows only through 19); a dropped turn, a trusted tx/ty, a stretched fit (5); a BT.601 or mistyped
// matrix (6); a format guess, swapped chroma bytes, chroma read at luma coordinates (7); a copy
// without `hasNewPixelBuffer`, or a second copy per pull (8); an uncapped or BGRA output, a lost
// IOSurface key (15); a renderer drop or a tier block the slot is never told of (18).

import AVFoundation
import CoreVideo
import Foundation
import XCTest
@testable import Echoelmusic

/// The display clock, moved by hand.
private final class ManualClock: @unchecked Sendable {
    var now = 0.0
}

/// Stands in for `AVPlayerItemVideoOutput`: hands a pending buffer out ONCE, as the real one does.
private final class StandInOutput: VideoFrameOutput {
    var pending: CVPixelBuffer?
    /// Every call, a buffer pending or not — a copy without `hasNewPixelBuffer`, or a second copy in
    /// one pull, shows here and nowhere else.
    var copyCalls = 0
    /// Media seconds per display second: a player at rate 2 reports twice the host time.
    var rate = 1.0

    func itemTime(forHostTime hostTimeInSeconds: CFTimeInterval) -> CMTime {
        CMTime(seconds: hostTimeInSeconds * rate, preferredTimescale: 600)
    }

    func hasNewPixelBuffer(forItemTime itemTime: CMTime) -> Bool {
        pending != nil
    }

    func copyPixelBuffer(forItemTime itemTime: CMTime,
                         itemTimeForDisplay outItemTimeForDisplay: UnsafeMutablePointer<CMTime>?) -> CVPixelBuffer? {
        copyCalls += 1
        guard let buffer = pending else { return nil }
        pending = nil
        return buffer
    }
}

final class TheVideoFrameIsPulledOnTheDrawTests: XCTestCase {

    private static let slotPath = "Sources/Echoelmusic/Studio/VideoLayerSlot.swift"
    private static let rendererPath = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let tick = 1.0 / 60

    /// Pulls of steady footage before a strobe: the dial's whole climb (`1 / (release x tick)`, 240)
    /// plus two counting windows, so the climb's own counted rise has left the window when the strobe
    /// starts and only the strobe's transitions are counted (#442 — derived, not tuned).
    private static var leadIn: Int {
        let climb = Int((1 / (VideoFlashLimiter.releasePerSecond * tick)).rounded())
        let windows = 2 * Int((VideoFlashLimiter.windowSeconds / tick).rounded())
        return climb + windows
    }

    // MARK: - Source text

    /// Claim 1 — the slot owns no queue, task, timer, observer, delegate or observation.
    func testTheSlotOwnsNoQueueTaskObserverOrObservation() throws {
        let slot = try code(Self.slotPath)
        XCTAssertTrue(slot.contains("func pullFootageFrame(viewportAspect: Float) -> FootageFrame? {"),
                      "ANCHOR: the slot no longer implements the pull — re-anchor before trusting the rest (VV-5b)")
        let banned = ["DispatchQueue", "DispatchSource", "OperationQueue", "Timer", "CADisplayLink",
                      "Task {", "Task.", "Task<", "async ", "await ", "@MainActor", "MainActor.",
                      "@Observable", "ObservableObject", "@Published", ".sink", "NotificationCenter",
                      "addObserver", "setDelegate(", "addPeriodicTimeObserver", "addBoundaryTimeObserver",
                      "requestNotificationOfMediaDataChange"]
        let hits = banned.filter { slot.contains($0) }
        XCTAssertTrue(hits.isEmpty, """
            `VideoLayerSlot` now contains \(hits.joined(separator: ", ")). A queue or task of its own \
            is a second clock and a hop per frame (10.76.48: the hop flood that froze the menus); an \
            observer or delegate is a closure a framework calls on a worker, and formed in a \
            main-actor owner it traps at its entry (builds 2613/2618); anything observable lets a \
            body subscribe to a 60 Hz value (10.76.41/50). The frame moves when a renderer asks (VV-5b).
            """)
    }

    /// Claim 2 — one NSLock leaf, every lock released by a `defer`, and one instance in Sources.
    func testTheSlotIsOneLockLeafWithOneInstance() throws {
        let slot = try code(Self.slotPath)
        let declaration = try XCTUnwrap(slot.components(separatedBy: "\n").first { $0.contains("final class VideoLayerSlot:") },
                                        "ANCHOR: `final class VideoLayerSlot:` is gone — re-anchor (VV-5b)")
        XCTAssertTrue(declaration.contains("FootageFrameSource") && declaration.contains("@unchecked Sendable"), """
            The slot no longer declares itself a `FootageFrameSource` and `@unchecked Sendable` — the \
            lock leaf the renderer pulls from inside its draw. Its isolation is claim 1's (VV-5b).
            """)
        XCTAssertTrue(slot.contains("private let lock = NSLock()"), "the slot lost its lock (VV-5b)")
        let locks = count("lock.lock()", in: slot)
        let deferred = count("defer { lock.unlock() }", in: slot)
        XCTAssertGreaterThanOrEqual(locks, 4, "attach, dial, detach and pull each take the lock (VV-5b)")
        XCTAssertEqual(locks, deferred, "a lock without a deferred unlock — an early return leaves the slot locked and the next draw deadlocks the main thread (VV-5b)")
        XCTAssertEqual(count("lock.unlock()", in: slot), deferred, "an unlock outside a `defer` (VV-5b)")
        let constructions = try sources().filter { count("VideoLayerSlot(", in: $0.code) > 0 }
        XCTAssertEqual(constructions.map { $0.name }, ["VideoLayerSlot.swift"], """
            `VideoLayerSlot(` is constructed outside its own file. A second slot is a second caller of \
            a video output: the two would take each other's buffers (`hasNewPixelBuffer` hands each \
            out once) and keep two limiter states for one picture (VV-5b).
            """)
        XCTAssertEqual(constructions.map { count("VideoLayerSlot(", in: $0.code) }.reduce(0, +), 1,
                       "expected exactly one construction, `static let shared` (VV-5b)")
    }

    /// Claim 3 — only the slot touches the output, only `refreshFootage` pulls, and inside the pull the
    /// copy comes before the dial's ease, the ease before the cache, the cache before the count, and the
    /// count before the frame is offered.
    func testOnlyTheSlotTouchesTheOutputAndOnlyTheRendererPulls() throws {
        let files = try sources()
        func sites(_ needle: String) -> [String] {
            files.flatMap { file in Array(repeating: file.name, count: count(needle, in: file.code)) }
        }
        for call in [".itemTime(forHostTime:", ".hasNewPixelBuffer(forItemTime:", ".copyPixelBuffer(forItemTime:"] {
            XCTAssertEqual(sites(call), ["VideoLayerSlot.swift"], """
                `\(call)` is called \(sites(call)). The slot must be the ONE caller of a video output: a \
                second consumer takes buffers the slot never counts, so a strobe frame could reach a \
                screen without passing the limiter (VV-5b).
                """)
        }
        XCTAssertEqual(sites(".pullFootageFrame("), ["MetalBioView.swift"], """
            The pull has a caller other than the renderer's one footage refresh. A second pull in one \
            draw can take a NEWER buffer than the one on screen, and the two encodes would then show \
            different frames. A slice that needs the frame elsewhere (the stream's affine, say) derives \
            it from the frame bound this draw — and if a second pull is ever right, move this claim in \
            the same commit (#364, VV-5b).
            """)
        let renderer = try code(Self.rendererPath)
        let refresh = try XCTUnwrap(body(of: "private func refreshFootage(", in: renderer),
                                    "ANCHOR: `refreshFootage()` is gone — re-anchor (VV-5b)")
        XCTAssertTrue(refresh.contains(".pullFootageFrame("), "the pull left `refreshFootage()` (VV-5b)")
        let slot = try code(Self.slotPath)
        let pull = try XCTUnwrap(body(of: "func pullFootageFrame(viewportAspect: Float) -> FootageFrame?", in: slot),
                                 "ANCHOR: the slot's pull is gone — re-anchor (VV-5b)")
        let order = ["lock.lock()", ".hasNewPixelBuffer(", ".copyPixelBuffer(", "easeDialLocked(",
                     "ingestLocked(", "countLocked(", "frameLocked("]
        let at = order.map { pull.range(of: $0)?.lowerBound }
        XCTAssertFalse(at.contains(where: { $0 == nil }), "a step of the pull is missing: \(order) (VV-5b)")
        let found = at.compactMap { $0 }
        XCTAssertEqual(found, found.sorted(), """
            The pull's order changed — expected \(order.joined(separator: " < ")). The dial is eased \
            BEFORE the count so the limiter counts the level this very pull will show, and the count \
            runs before the frame is offered so the gain rides on the draw it decided — one frame \
            late, the engaging edge of a strobe is shown at the old gain (`UserFootageCannotStrobeTests` \
            claim 1's premise, VV-5b).
            """)
        let counting = try XCTUnwrap(body(of: "private func countLocked(", in: slot), "ANCHOR: `countLocked` is gone (VV-5b)")
        let law = ["* easedDial", "limiter.step("].map { counting.range(of: $0)?.lowerBound }
        XCTAssertFalse(law.contains(where: { $0 == nil }), """
            The count lost the dial in its cells, or its limiter step. Without the dial the limiter \
            counts the FILE, while the screen shows dial x gain x cell — a dial climbing against \
            falling footage then makes reversals no channel counts (VV-5b).
            """)
        let lawFound = law.compactMap { $0 }
        XCTAssertEqual(lawFound, lawFound.sorted(), "the dial is applied after the limiter has stepped (VV-5b)")
    }

    /// Claim 4 — the ONE writer of `footageSource` is `makeUIView`, and no SwiftUI view block reads a
    /// player or a frame.
    func testEveryRendererGetsTheSlotInMakeUIViewAndNoViewReadsAPlayer() throws {
        let renderer = try code(Self.rendererPath)
        let make = try XCTUnwrap(body(of: "func makeUIView(context: Context) -> MTKView", in: renderer),
                                 "ANCHOR: `makeUIView` is gone — re-anchor (VV-5b)")
        XCTAssertTrue(make.contains("context.coordinator.footageSource = VideoLayerSlot.shared"),
                      "`makeUIView` no longer gives the renderer the slot — every footage path returns nil again (VV-5b)")
        let files = try sources()
        XCTAssertEqual(files.map { count("footageSource =", in: $0.code) }.reduce(0, +), 1, """
            Expected exactly one writer of `footageSource` in Sources/. A second writer (a reset in \
            `dismantleUIView`, a test seam) may be right — then move this claim in the same commit and \
            say why the slot stays the only source (#364, VV-5b).
            """)
        let reads = ["AVPlayer(", "AVPlayerItem(", "AVQueuePlayer(", "AVPlayerItemVideoOutput(", "itemTime(",
                     "copyPixelBuffer", "hasNewPixelBuffer", "pullFootageFrame", "currentTime()", "timeControlStatus"]
        var blocks = 0
        var unreadable: [String] = []
        var offenders: [String] = []
        for file in files {
            for anchor in [": some View {", "-> some View {"] {
                var cursor = file.code.startIndex
                while let hit = file.code.range(of: anchor, range: cursor ..< file.code.endIndex) {
                    cursor = hit.upperBound
                    guard let block = braceBlock(in: file.code, from: hit.lowerBound) else {
                        unreadable.append(file.name)
                        break
                    }
                    blocks += 1
                    for read in reads where block.contains(read) { offenders.append("\(file.name): \(read)") }
                }
            }
        }
        XCTAssertGreaterThan(blocks, 300, "only \(blocks) view blocks read — the sweep is broken, not the tree (#454)")
        XCTAssertTrue(unreadable.isEmpty, "view blocks whose braces did not match: \(unreadable) — fix the extraction before trusting a green")
        XCTAssertTrue(offenders.isEmpty, """
            A SwiftUI view block now touches a player or a frame: \(offenders.joined(separator: ", ")). \
            A player CONSTRUCTED in a body is rebuilt on every evaluation; a time or status shown in a \
            body needs an observer writing view state, and that observer belongs to the owner, not to \
            the view (a 60 Hz write into a body's state tears down any open menu, 10.76.41/50). A door \
            action calls an owner or slot method and never spells the player or the output (VV-5b).
            """)
    }

    // MARK: - Behaviour

    /// Claim 5 — the viewport map fits, turns, ignores the file's translation, and refuses nonsense.
    func testTheViewportMapFitsTurnsAndRefuses() throws {
        func point(_ map: CGAffineTransform, _ u: Double, _ v: Double) -> (x: Double, y: Double) {
            let p = CGPoint(x: u, y: v).applying(map)
            return (Double(p.x), Double(p.y))
        }
        func expect(_ p: (x: Double, y: Double), _ x: Double, _ y: Double, _ what: String) {
            XCTAssertEqual(p.x, x, accuracy: 1e-9, what)
            XCTAssertEqual(p.y, y, accuracy: 1e-9, what)
        }
        let same = try XCTUnwrap(VideoLayerSlot.viewportToImage(viewportAspect: 16.0 / 9.0, bufferWidth: 1920,
                                                                bufferHeight: 1080, transform: .identity))
        expect(point(same, 0, 0), 0, 0, "same aspect, no turn: top-left is top-left")
        expect(point(same, 1, 1), 1, 1, "same aspect, no turn: bottom-right is bottom-right")
        expect(point(same, 0.25, 0.75), 0.25, 0.75, "same aspect, no turn: the identity")

        let fitHeight: Double = (9.0 / 16.0) * (1080.0 / 1920.0)
        let fitTop: Double = (1 - fitHeight) / 2
        let card = try XCTUnwrap(VideoLayerSlot.viewportToImage(viewportAspect: 9.0 / 16.0, bufferWidth: 1920,
                                                                bufferHeight: 1080, transform: .identity))
        expect(point(card, 0.5, 0.5), 0.5, 0.5, "the card's centre is the clip's centre")
        expect(point(card, 0, fitTop), 0, 0, "the fitted picture's top-left is the clip's")
        expect(point(card, 1, fitTop + fitHeight), 1, 1, "the fitted picture's bottom-right is the clip's")
        XCTAssertLessThan(point(card, 0.5, 0.1).y, 0, "above the fitted picture is letterbox — the shader shows the field there")

        let quarter = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let turned = try XCTUnwrap(VideoLayerSlot.viewportToImage(viewportAspect: 9.0 / 16.0, bufferWidth: 1920,
                                                                  bufferHeight: 1080, transform: quarter))
        expect(point(turned, 0, 0), 0, 1, "a phone's portrait clip: the card's top-left is the pixels' bottom-left")
        expect(point(turned, 1, 0), 0, 0, "top-right is the pixels' top-left")
        expect(point(turned, 0, 1), 1, 1, "bottom-left is the pixels' bottom-right")
        expect(point(turned, 1, 1), 1, 0, "bottom-right is the pixels' top-right — it fills the card, no letterbox")
        let junk = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 12345, ty: -678)
        XCTAssertEqual(VideoLayerSlot.viewportToImage(viewportAspect: 9.0 / 16.0, bufferWidth: 1920,
                                                      bufferHeight: 1080, transform: junk), turned,
                       "the file's own tx/ty must not move the picture — the corners decide")

        XCTAssertNil(VideoLayerSlot.viewportToImage(viewportAspect: 0, bufferWidth: 1920, bufferHeight: 1080, transform: .identity))
        XCTAssertNil(VideoLayerSlot.viewportToImage(viewportAspect: .nan, bufferWidth: 1920, bufferHeight: 1080, transform: .identity))
        XCTAssertNil(VideoLayerSlot.viewportToImage(viewportAspect: 1, bufferWidth: 0, bufferHeight: 1080, transform: .identity))
        XCTAssertNil(VideoLayerSlot.viewportToImage(viewportAspect: 1, bufferWidth: 1920, bufferHeight: 1080,
                                                    transform: CGAffineTransform(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0)),
                     "a transform that cannot be inverted has no picture")
    }

    /// Claim 6 — the CPU reads colour exactly as the shader shows it, and the two matrices agree.
    func testTheCPUReadsColourExactlyAsTheShaderDoes() throws {
        let neutral = 128.0 / 255.0
        XCTAssertEqual(VideoLayerSlot.shownLuminance(y: 1, cb: neutral, cr: neutral, videoRange: false), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerSlot.shownLuminance(y: 0, cb: neutral, cr: neutral, videoRange: false), 0, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerSlot.shownLuminance(y: 16.0 / 255.0, cb: neutral, cr: neutral, videoRange: true), 0, accuracy: 1e-12,
                       "video range: 16 is black")
        XCTAssertEqual(VideoLayerSlot.shownLuminance(y: 235.0 / 255.0, cb: neutral, cr: neutral, videoRange: true), 1, accuracy: 1e-9,
                       "video range: 235 is white")
        let kr = VideoLayerMath.redWeight
        let kb = VideoLayerMath.blueWeight
        let redCb: Double = neutral + (0 - kr) / (2 * (1 - kb))
        let redCr: Double = neutral + (1 - kr) / (2 * (1 - kr))
        XCTAssertEqual(VideoLayerSlot.shownLuminance(y: kr, cb: redCb, cr: redCr, videoRange: false), kr, accuracy: 1e-9,
                       "pure red, BT.709-encoded, must read back as red's luminance weight — a 601 or mistyped matrix leaks green")

        let metal = try text(Self.rendererPath)
        func literals(_ pattern: String) throws -> [Double] {
            let regex = try NSRegularExpression(pattern: pattern)
            let ns = metal as NSString
            let matches = regex.matches(in: metal, range: NSRange(location: 0, length: ns.length))
            XCTAssertEqual(matches.count, 1, "the MSL footage matrix line `\(pattern)` is not there exactly once — re-anchor (VV-5b)")
            guard let match = matches.first else { return [] }
            return (1 ..< match.numberOfRanges).compactMap { Double(ns.substring(with: match.range(at: $0))) }
        }
        let red = try literals("luma \\+ ([0-9.]+) \\* ch\\.y,")
        let green = try literals("luma - ([0-9.]+) \\* ch\\.x - ([0-9.]+) \\* ch\\.y,")
        let blue = try literals("luma \\+ ([0-9.]+) \\* ch\\.x\\)")
        guard red.count == 1, green.count == 2, blue.count == 1 else {
            return XCTFail("the MSL matrix literals could not be read — re-anchor (VV-5b)")
        }
        let rule = "the shader's matrix and the limiter's CPU matrix disagree — the limiter would count a picture the screen does not show (#416, VV-5b)"
        XCTAssertEqual(red[0], VideoLayerSlot.crToRed, accuracy: 5e-5, rule)
        XCTAssertEqual(green[0], VideoLayerSlot.cbToGreen, accuracy: 5e-5, rule)
        XCTAssertEqual(green[1], VideoLayerSlot.crToGreen, accuracy: 5e-5, rule)
        XCTAssertEqual(blue[0], VideoLayerSlot.cbToBlue, accuracy: 5e-5, rule)
        let slot = try code(Self.slotPath)
        for expansion in ["16.0 / 255.0", "255.0 / 219.0", "128.0 / 255.0", "255.0 / 224.0"] {
            XCTAssertTrue(metal.contains(expansion) && slot.contains(expansion),
                          "the range expansion `\(expansion)` is no longer written in both the shader and the slot (VV-5b)")
        }
    }

    /// Claim 7 — the cells come from both planes of a real 4:2:0 buffer, at the right chroma
    /// coordinates, and any other format is refused.
    func testTheCellsComeFromBothPlanesAndRefuseOtherFormats() throws {
        var samples: [Double] = []
        let side = VideoLayerMath.flashCellsPerSide
        let white = try XCTUnwrap(VideoLayerSlot.flashCells(of: try planar { _, _ in 255 }, samples: &samples))
        XCTAssertEqual(white.count, side * side)
        XCTAssertTrue(white.allSatisfy { Swift.abs($0 - 1) < 1e-12 }, "a white frame must read 1 in every cell")
        let split = try XCTUnwrap(VideoLayerSlot.flashCells(of: try planar { x, _ in x < 32 ? 255 : 0 }, samples: &samples))
        for row in 0 ..< side {
            for column in 0 ..< side {
                XCTAssertEqual(split[row * side + column], column < side / 2 ? 1 : 0, accuracy: 1e-12,
                               "cell \(row),\(column) of a left-white, right-black frame")
            }
        }
        let videoWhite = try XCTUnwrap(VideoLayerSlot.flashCells(
            of: try planar(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) { _, _ in 235 }, samples: &samples))
        XCTAssertTrue(videoWhite.allSatisfy { Swift.abs($0 - 1) < 1e-9 }, "video-range 235 is white")
        let videoBlack = try XCTUnwrap(VideoLayerSlot.flashCells(
            of: try planar(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) { _, _ in 16 }, samples: &samples))
        XCTAssertTrue(videoBlack.allSatisfy { Swift.abs($0) < 1e-12 }, "video-range 16 is black")

        // The CHROMA plane: BT.709 pure red as full-range bytes (Y 54, Cb 99, Cr 255). Every expected
        // value is the slot's own `shownLuminance` of the same bytes (claim 6 holds that function to
        // the shader); the first assertion ties those bytes to red.
        let redLuminance = VideoLayerSlot.shownLuminance(y: 54.0 / 255.0, cb: 99.0 / 255.0, cr: 1, videoRange: false)
        let greyLuminance = VideoLayerSlot.shownLuminance(y: 54.0 / 255.0, cb: 128.0 / 255.0, cr: 128.0 / 255.0,
                                                          videoRange: false)
        XCTAssertEqual(redLuminance, VideoLayerMath.redWeight, accuracy: 0.005, "the test bytes are not BT.709 red")
        XCTAssertGreaterThan(redLuminance - greyLuminance, 0.1, "red and grey must be told apart by more than a step")
        let red = try XCTUnwrap(VideoLayerSlot.flashCells(
            of: try planar(luma: { _, _ in 54 }, chroma: { _, _ in (99, 255) }), samples: &samples))
        XCTAssertTrue(red.allSatisfy { Swift.abs($0 - redLuminance) < 1e-12 }, """
            a red frame no longer reads as red — Cb and Cr swapped, or the chroma plane not read (VV-5b)
            """)
        // Red chroma in the top-left QUADRANT of the chroma plane only: a reader that takes chroma at
        // the luma coordinates (no 2:1 scale) lands outside the quadrant for half the red cells.
        let quadrant = try XCTUnwrap(VideoLayerSlot.flashCells(
            of: try planar(luma: { _, _ in 54 }, chroma: { x, y in x < 16 && y < 16 ? (99, 255) : (128, 128) }),
            samples: &samples))
        for row in 0 ..< side {
            for column in 0 ..< side {
                let inside = row < side / 2 && column < side / 2
                XCTAssertEqual(quadrant[row * side + column], inside ? redLuminance : greyLuminance, accuracy: 1e-12,
                               "cell \(row),\(column): chroma read at the wrong coordinate (VV-5b)")
            }
        }

        XCTAssertNil(VideoLayerSlot.flashCells(of: try bgra(), samples: &samples),
                     "a format the renderer would not bind must yield no cells — fail closed, never a guess")
        XCTAssertEqual(samples.count, VideoLayerSlot.samplesPerSide * VideoLayerSlot.samplesPerSide)
    }

    /// Claim 8 — one new buffer is one frame for every puller: copied once, one sequence, never 0.
    func testOneNewBufferIsOneFrameForEveryPuller() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        XCTAssertNil(slot.pullFootageFrame(viewportAspect: 1), "nothing attached: nil — the state the app ships in")
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        XCTAssertNil(slot.pullFootageFrame(viewportAspect: 1), "attached, no buffer yet: still nil")
        let white = try planar { _, _ in 255 }
        for k in 1 ... Self.leadIn {
            clock.now = Double(k) * Self.tick
            output.pending = white
            _ = slot.pullFootageFrame(viewportAspect: 1)
        }
        output.pending = try planar { _, _ in 255 }
        clock.now += Self.tick
        let callsBefore = output.copyCalls
        let window = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 9.0 / 16.0))
        let beamer = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 16.0 / 9.0))
        XCTAssertEqual(output.copyCalls - callsBefore, 1, """
            Two renderers in one pass made \(output.copyCalls - callsBefore) copy calls. The output hands \
            each buffer out once: a copy without `hasNewPixelBuffer`, or a second copy, is a second \
            consumer the limiter never sees (VV-5b).
            """)
        XCTAssertNotEqual(window.sequence, 0, "0 is the renderer's 'no footage'")
        XCTAssertEqual(window.sequence, beamer.sequence)
        XCTAssertTrue(window.pixelBuffer === beamer.pixelBuffer)
        XCTAssertEqual(window.opacity, 1, "COUNTERWEIGHT: the dial has climbed, so the comparison below is not 0 = 0")
        XCTAssertEqual(window.opacity, beamer.opacity, "two renderers in one pass show one level")
        XCTAssertNotEqual(window.viewportToImage, beamer.viewportToImage, "each puller gets the map for its own aspect")
        output.pending = try planar { _, _ in 255 }
        clock.now += Self.tick
        let next = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1))
        XCTAssertGreaterThan(next.sequence, window.sequence, "a new buffer gets a new, larger number")
        clock.now += Self.tick
        let callsIdle = output.copyCalls
        XCTAssertEqual(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).sequence, next.sequence,
                       "no new buffer, no new number — the #1244 skip may keep the bound pair")
        XCTAssertEqual(output.copyCalls, callsIdle, "a pull with no new buffer must not call the copy at all (VV-5b)")
    }

    /// Claim 9 — a 10 Hz strobe is capped ON the frame the limiter engages, and stays capped.
    func testAStrobeIsCappedOnTheFrameItEngages() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        let black = try planar { _, _ in 0 }
        var last: FootageFrame?
        for k in 0 ..< Self.leadIn {
            clock.now = Double(k) * Self.tick
            output.pending = white
            last = slot.pullFootageFrame(viewportAspect: 1)
        }
        XCTAssertEqual(try XCTUnwrap(last).opacity, 1, "steady footage keeps the whole gain once the dial has eased up — the counterweight")
        let start = Double(Self.leadIn) * Self.tick
        var opacities: [Float] = []
        for j in 0 ..< 120 {
            clock.now = start + Double(j) * Self.tick
            output.pending = (j / 3) % 2 == 0 ? black : white
            opacities.append(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity)
        }
        let capped = Float(VideoFlashLimiter.engagedGain) + 1e-6
        let engaging = 3 * (VideoFlashLimiter.engageTransitions - 1)
        XCTAssertEqual(opacities[engaging - 1], 1, "one transition short of the limiter's count does not engage it")
        XCTAssertLessThanOrEqual(opacities[engaging], capped, """
            The engaging transition's OWN frame is shown at the old gain. The cap must ride on the \
            draw whose cells engaged it (VideoFlashLimiter header; UserFootageCannotStrobeTests claim 1).
            """)
        for j in engaging ..< opacities.count {
            XCTAssertLessThanOrEqual(opacities[j], capped, "strobe frame \(j) escaped the cap")
        }
    }

    /// Claim 10 — the limiter counts on the DISPLAY clock: a rate-2 player's media time would halve
    /// every frequency and let a 3.75 Hz strobe through.
    func testTheLimiterRunsOnTheDisplayClock() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        output.rate = 2
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        let black = try planar { _, _ in 0 }
        for k in 0 ..< Self.leadIn {
            clock.now = Double(k) * Self.tick
            output.pending = white
            _ = slot.pullFootageFrame(viewportAspect: 1)
        }
        let start = Double(Self.leadIn) * Self.tick
        var opacities: [Float] = []
        for j in 0 ..< 180 {
            clock.now = start + Double(j) * Self.tick
            output.pending = (j / 8) % 2 == 0 ? black : white
            opacities.append(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity)
        }
        let engaging = 8 * (VideoFlashLimiter.engageTransitions - 1)
        XCTAssertEqual(opacities[engaging - 1], 1, "one transition short on the screen does not engage the limiter")
        let capped = Float(VideoFlashLimiter.engagedGain) + 1e-6
        for j in engaging ..< opacities.count {
            XCTAssertLessThanOrEqual(opacities[j], capped, """
                A 3.75 Hz on-screen strobe at playback rate 2 was not capped at frame \(j). On media time \
                its transitions are 0.27 s apart, four per second, and the limiter never engages — the \
                header requires the display clock (VideoFlashLimiter.swift, VV-5b).
                """)
        }
    }

    /// Claim 11 — the dial eases no faster than the limiter's own climb, and a layer returning after
    /// a gap no renderer pulled across fades in.
    func testTheDialEasesAndAReturningLayerFadesIn() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        let limit = Float(VideoFlashLimiter.releasePerSecond * Self.tick) + 1e-6
        var previous: Float = 0
        for k in 0 ..< 260 {
            clock.now = Double(k) * Self.tick
            output.pending = white
            let opacity = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity
            XCTAssertGreaterThanOrEqual(opacity, previous, "frame \(k): the fade-in went backwards")
            XCTAssertLessThanOrEqual(opacity - previous, limit, "frame \(k): the dial moved faster than the limiter's own climb")
            previous = opacity
        }
        XCTAssertEqual(previous, 1, "the dial reaches its target")
        slot.setDial(0.5)
        clock.now += Self.tick
        output.pending = white
        let lowered = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity
        XCTAssertLessThan(lowered, 1)
        XCTAssertLessThanOrEqual(1 - lowered, limit, "a lowered dial falls no faster than it rises")
        clock.now += 0.5
        output.pending = white
        XCTAssertEqual(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity, 0, """
            After half a second in which NO renderer pulled (every mount tier-blocked or hidden, a \
            remount) the layer came back at full level in one frame — a presence snap the limiter \
            never counted (VV-5b).
            """)
    }

    /// Claim 12 — a dial cannot climb while nothing is shown: the first frame after a wait fades in.
    func testTheFirstFrameAfterAWaitFadesIn() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        for k in 0 ..< 120 {
            clock.now = Double(k) * Self.tick
            XCTAssertNil(slot.pullFootageFrame(viewportAspect: 1), "pull \(k): no buffer yet, nothing to show")
        }
        clock.now += Self.tick
        output.pending = try planar { _, _ in 255 }
        let first = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity
        XCTAssertLessThanOrEqual(first, Float(VideoFlashLimiter.releasePerSecond * Self.tick) + 1e-6, """
            Two seconds of waiting for the player's first buffer let the dial climb unseen, and the \
            first frame appeared at that level in one step — the snap the fade-in exists to prevent \
            (VV-5b).
            """)
    }

    /// Claim 13 — a buffer the renderer would not bind drops the layer on that frame, and the next
    /// good one fades back in.
    func testAnUnreadableFrameDropsTheLayer() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        var shown: FootageFrame?
        for k in 0 ..< 260 {
            clock.now = Double(k) * Self.tick
            output.pending = white
            shown = slot.pullFootageFrame(viewportAspect: 1)
        }
        let before = try XCTUnwrap(shown)
        XCTAssertEqual(before.opacity, 1, "COUNTERWEIGHT: the layer was fully up before the refusal")
        clock.now += Self.tick
        output.pending = try bgra()
        XCTAssertNil(slot.pullFootageFrame(viewportAspect: 1), """
            An unreadable buffer kept the previous frame on screen. Fail closed: a frame the limiter \
            could not count must not be replaced by a stale one either (K5a's frozen frame, VV-5b).
            """)
        clock.now += Self.tick
        XCTAssertNil(slot.pullFootageFrame(viewportAspect: 1), "no new buffer after a refusal: still nothing")
        clock.now += Self.tick
        output.pending = white
        let back = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1))
        XCTAssertGreaterThan(back.sequence, before.sequence)
        XCTAssertLessThanOrEqual(back.opacity, Float(VideoFlashLimiter.releasePerSecond * Self.tick) + 1e-6,
                                 "the layer came back at full level after a refusal — it must fade in (VV-5b)")
    }

    /// Claim 14 — the limiter counts the layer AT THE DIAL: a full-contrast cell checkerboard
    /// reversing at 10 Hz under a 0.05 dial swings 0.05 on the screen, half the WCAG step, and is
    /// not capped. Every window holds as many white cells as black, so only the cell channels see it.
    func testTheLimiterCountsTheLayerAtTheDial() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        let dial = 0.05
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: dial)
        let square = 64 / VideoLayerMath.flashCellsPerSide   // one limiter cell per square (`planar`'s side)
        let even = try planar { x, y in (x / square + y / square) % 2 == 0 ? 255 : 0 }
        let odd = try planar { x, y in (x / square + y / square) % 2 == 0 ? 0 : 255 }
        let settled = Int((dial / (VideoFlashLimiter.releasePerSecond * Self.tick)).rounded(.up))
        for k in 0 ..< 240 {
            clock.now = Double(k) * Self.tick
            output.pending = (k / 3) % 2 == 0 ? even : odd
            let opacity = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity
            if k >= settled {
                XCTAssertEqual(opacity, Float(dial), accuracy: 1e-6, """
                    Pull \(k): the layer was capped although the screen swings by \(dial), under the \
                    WCAG step. The limiter is counting the FILE, not the layer — and the same \
                    multiplication is what lets it see a dial climbing against falling footage, which \
                    is the direction that matters. If a second count on the undimmed file is ever \
                    added on purpose, move this claim in the same commit (#364, VV-5b).
                    """)
            }
        }
    }

    /// Claim 15 — the output asks for exactly what the renderer binds, with documented keys only.
    func testTheOutputAsksForWhatTheRendererBinds() throws {
        let settings = VideoLayerSlot.outputSettings(naturalWidth: 3840, naturalHeight: 2160)
        XCTAssertEqual(settings[kCVPixelBufferPixelFormatTypeKey as String] as? OSType,
                       kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertEqual(settings[kCVPixelBufferMetalCompatibilityKey as String] as? Bool, true)
        XCTAssertNotNil(settings[kCVPixelBufferIOSurfacePropertiesKey as String],
                        "without IOSurface backing the texture cache cannot make zero-copy views (VV-5b)")
        XCTAssertEqual(settings[AVVideoAllowWideColorKey] as? Bool, false, "the shader decodes 8-bit BT.709, not wide colour")
        XCTAssertNil(settings[AVVideoColorPropertiesKey], """
            The recipe carries `AVVideoColorPropertiesKey`. The Discussion of Apple's \
            `init(outputSettings:)` page names only `kCVPixelBuffer*` keys and `AVVideoAllowWideColorKey` \
            for uncompressed output, and how the initializer treats any other key (accept, ignore or \
            raise) is unmeasured. If a device run has shown the key is accepted, add it and move this \
            assertion in the same commit (#364, VV-5b).
            """)
        let scale = VideoLayerSlot.maxLongSidePixels / 3840
        XCTAssertLessThan(scale, 1, "COUNTERWEIGHT: a 4K clip is above the cap, so the size below is a scaled one")
        XCTAssertEqual(settings[kCVPixelBufferWidthKey as String] as? Int, Int((3840 * scale / 2).rounded()) * 2,
                       "a 4K clip is decoded with its long side at the cap")
        XCTAssertEqual(settings[kCVPixelBufferHeightKey as String] as? Int, Int((2160 * scale / 2).rounded()) * 2,
                       "and its aspect kept")
        let small = try XCTUnwrap(VideoLayerSlot.outputPixelSize(naturalWidth: 1280, naturalHeight: 720))
        XCTAssertEqual(small.width, 1280, "never scaled up")
        XCTAssertEqual(small.height, 720)
        XCTAssertNil(VideoLayerSlot.outputPixelSize(naturalWidth: 0, naturalHeight: 720))
        XCTAssertNil(VideoLayerSlot.outputSettings(naturalWidth: .nan, naturalHeight: 720)[kCVPixelBufferWidthKey as String])
        let renderer = try code(Self.rendererPath)
        XCTAssertTrue(renderer.contains("case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: videoRange = true"),
                      "COUNTERWEIGHT: the renderer no longer binds the format the output asks for — no layer, no log (VV-5a/VV-5b)")
    }

    /// Claim 16 — the honest scope: nothing attaches a video output yet.
    func testNothingAttachesAVideoOutputYet() throws {
        let attaches = try sources().map { count(".attachVideoOutput(", in: $0.code) }.reduce(0, +)
        XCTAssertEqual(attaches, 0, """
            Something now attaches a video output — VV-6 or VV-8, the first time own footage can reach \
            the visual. Flip this claim in THAT commit and move the prose with it (#456): the scope \
            paragraph of `VideoLayerSlot`, the `FootageFrame` and `refreshFootage` docs in \
            `MetalBioView`, and the plan rows. This claim does not forbid the door (#364).
            """)
    }

    /// Claim 17 — the limiter counts every DRAW, not only a new buffer: after a strobe engaged the
    /// cap, a paused clip — the same frame on screen, no new buffer — releases on the display clock.
    func testAPausedClipReleasesTheCapOnTheDisplayClock() throws {
        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        let black = try planar { _, _ in 0 }
        for k in 0 ..< Self.leadIn {
            clock.now = Double(k) * Self.tick
            output.pending = white
            _ = slot.pullFootageFrame(viewportAspect: 1)
        }
        let start = Double(Self.leadIn) * Self.tick
        var strobed: FootageFrame?
        for j in 0 ..< 120 {
            clock.now = start + Double(j) * Self.tick
            output.pending = (j / 3) % 2 == 0 ? black : white
            strobed = slot.pullFootageFrame(viewportAspect: 1)
        }
        let capped = try XCTUnwrap(strobed)
        XCTAssertLessThanOrEqual(capped.opacity, Float(VideoFlashLimiter.engagedGain) + 1e-6,
                                 "COUNTERWEIGHT: the 10 Hz strobe engaged the cap (claim 9)")
        // The window empties, the hold runs out, the gain climbs back at the release rate — plus a second.
        let pause = VideoFlashLimiter.windowSeconds + VideoFlashLimiter.holdSeconds
            + (1 - VideoFlashLimiter.engagedGain) / VideoFlashLimiter.releasePerSecond + 1
        let pauseStart = clock.now
        var paused: FootageFrame?
        for k in 1 ... Int((pause / Self.tick).rounded(.up)) {
            clock.now = pauseStart + Double(k) * Self.tick
            paused = slot.pullFootageFrame(viewportAspect: 1)
        }
        let still = try XCTUnwrap(paused)
        XCTAssertEqual(still.sequence, capped.sequence, "COUNTERWEIGHT: no new buffer arrived — the clip is paused")
        XCTAssertEqual(still.opacity, 1, """
            A paused clip stayed at the capped level for \(pause) s. The limiter is counted only when a \
            new buffer arrives, so between buffers it neither sees the dial move on the screen nor \
            lets its own gain release — the screen and the count part company (VV-5b review).
            """)
    }

    /// Claim 18 — a frame the renderer could not show, or a pull with no map, fades back in like a
    /// refused buffer: the renderer tells the slot (`footageDropped`) and the dial drops to 0.
    func testADroppedFrameFadesBackIn() throws {
        let renderer = try code(Self.rendererPath)
        let refresh = try XCTUnwrap(body(of: "private func refreshFootage(", in: renderer),
                                    "ANCHOR: `refreshFootage()` is gone — re-anchor (VV-5b)")
        XCTAssertEqual(count(".footageDropped()", in: refresh), 3, """
            `refreshFootage()` no longer reports all three of its drops to the slot: a map it will not \
            use, a frame it cannot bind, and a layer the tier hid. Unreported, the layer comes back at \
            the dial's level in one step — and a drop that repeats is a strobe no channel counted. If \
            two exits are merged into one, move this count in the same commit (#364, VV-5b review).
            """)

        let clock = ManualClock()
        let slot = VideoLayerSlot(clock: { clock.now })
        let output = StandInOutput()
        slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
        let white = try planar { _, _ in 255 }
        var shown: FootageFrame?
        for k in 0 ..< Self.leadIn {
            clock.now = Double(k) * Self.tick
            output.pending = white
            shown = slot.pullFootageFrame(viewportAspect: 1)
        }
        XCTAssertEqual(try XCTUnwrap(shown).opacity, 1, "COUNTERWEIGHT: the layer was fully up")
        let fadeStep = Float(VideoFlashLimiter.releasePerSecond * Self.tick) + 1e-6
        slot.footageDropped()
        clock.now += Self.tick
        XCTAssertLessThanOrEqual(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity, fadeStep,
                                 "after a frame the renderer could not show, the layer came back at full level (VV-5b review)")
        for _ in 0 ..< Self.leadIn {
            clock.now += Self.tick
            shown = slot.pullFootageFrame(viewportAspect: 1)
        }
        XCTAssertEqual(try XCTUnwrap(shown).opacity, 1, "COUNTERWEIGHT: the layer climbed back")
        clock.now += Self.tick
        XCTAssertNil(slot.pullFootageFrame(viewportAspect: 0), "a viewport with no aspect has no map, so no frame")
        clock.now += Self.tick
        XCTAssertLessThanOrEqual(try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 1)).opacity, fadeStep,
                                 "after a pull with no map, the layer came back at full level (VV-5b review)")
    }

    /// Claim 19 — two renderers in one layout pass are ONE draw for the limiter: the second pull,
    /// within `VideoFlashLimiter.shortestFrameSeconds` of the first, shares its count, and a new
    /// buffer that reaches the second pull is counted at the first one's time. Counted on its own
    /// time, each pass would advance the limiter's clock by at least that minimum on top of the frame,
    /// its one-second window would cover less than a real second, and a strobe the window must catch
    /// would pass. The strobe here is 13 display frames per half-period: five transitions span
    /// 4 x 13 / 60 = 0.87 s on the display clock, inside the window. The second pull comes a hundredth
    /// of the shortest frame after the first; counted on its own time, each pass advances the limiter
    /// by a display frame plus 0.99 of the shortest frame — about 1.25 times fast, so the same five
    /// transitions span 1.08 s, outside it.
    func testTwoRenderersInOnePassCountOnce() throws {
        func engagingFrame(secondRenderer: Bool, bufferOnSecond: Bool) throws -> Int? {
            let clock = ManualClock()
            let slot = VideoLayerSlot(clock: { clock.now })
            let output = StandInOutput()
            slot.attachVideoOutput(output, preferredTransform: .identity, dial: 1)
            let white = try planar { _, _ in 255 }
            let black = try planar { _, _ in 0 }
            for k in 0 ..< Self.leadIn {
                clock.now = Double(k) * Self.tick
                output.pending = white
                _ = slot.pullFootageFrame(viewportAspect: 1)
            }
            let start = Double(Self.leadIn) * Self.tick
            let capped = Float(VideoFlashLimiter.engagedGain) + 1e-6
            for j in 0 ..< 180 {
                let now = start + Double(j) * Self.tick
                let buffer = (j / 13) % 2 == 0 ? black : white
                clock.now = now
                if !bufferOnSecond { output.pending = buffer }
                var shown = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 9.0 / 16.0))
                if secondRenderer {
                    clock.now = now + VideoFlashLimiter.shortestFrameSeconds / 100
                    if bufferOnSecond { output.pending = buffer }
                    let second = try XCTUnwrap(slot.pullFootageFrame(viewportAspect: 16.0 / 9.0))
                    if bufferOnSecond { shown = second }
                }
                if shown.opacity <= capped { return j }
            }
            return nil
        }
        let engaging = 13 * (VideoFlashLimiter.engageTransitions - 1)
        XCTAssertEqual(try engagingFrame(secondRenderer: false, bufferOnSecond: false), engaging,
                       "COUNTERWEIGHT: one renderer — the strobe is capped on the transition that engages the limiter")
        XCTAssertEqual(try engagingFrame(secondRenderer: true, bufferOnSecond: false), engaging, """
            With a second renderer pulling in the same pass the strobe was capped at a different frame \
            (or never). The second pull was counted as a draw of its own and ran the limiter's clock \
            ahead of the display's (VV-5b review).
            """)
        XCTAssertEqual(try engagingFrame(secondRenderer: true, bufferOnSecond: true), engaging, """
            With every new buffer reaching the SECOND renderer of a pass the strobe was capped at a \
            different frame (or never). That buffer was counted at its own time, a hundredth of the \
            shortest frame late, and the limiter's clamp stepped its clock by the whole shortest frame \
            (VV-5b review).
            """)
    }

    // MARK: - Helpers

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func code(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try text(relativePath))
    }

    /// Every Swift file under Sources/, comment-stripped.
    private func sources() throws -> [(name: String, code: String)] {
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("could not walk \(root.path)")
            return []
        }
        var files: [(name: String, code: String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append((url.lastPathComponent, SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        XCTAssertGreaterThan(files.count, 250, "only \(files.count) Swift files read — the walk failed (#454)")
        return files
    }

    private func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// The brace-matched block whose first `{` is at or after `from`. nil — never "" — when unmatched (#926).
    private func braceBlock(in code: String, from: String.Index) -> String? {
        guard let open = code.range(of: "{", range: from ..< code.endIndex) else { return nil }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound ... index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// The body of the member whose declaration starts with `anchor` (an anchor WITHOUT its brace).
    private func body(of anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        return braceBlock(in: code, from: start.upperBound)
    }

    /// A real 4:2:0 bi-planar buffer: luma `luma(x, y)` per pixel, chroma `chroma(x, y)` = (Cb, Cr) per
    /// chroma sample (half the luma size on each side), neutral by default.
    private func planar(_ format: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                        side: Int = 64,
                        luma: (Int, Int) -> UInt8,
                        chroma: (Int, Int) -> (UInt8, UInt8) = { _, _ in (128, 128) }) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, side, side, format, nil, &created), kCVReturnSuccess)
        let buffer = try XCTUnwrap(created)
        XCTAssertEqual(CVPixelBufferGetPlaneCount(buffer), 2)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let lumaBase = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(buffer, 0))
        let lumaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        for y in 0 ..< CVPixelBufferGetHeightOfPlane(buffer, 0) {
            for x in 0 ..< CVPixelBufferGetWidthOfPlane(buffer, 0) {
                lumaBase.storeBytes(of: luma(x, y), toByteOffset: y * lumaStride + x, as: UInt8.self)
            }
        }
        let chromaBase = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(buffer, 1))
        let chromaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        for y in 0 ..< CVPixelBufferGetHeightOfPlane(buffer, 1) {
            for x in 0 ..< CVPixelBufferGetWidthOfPlane(buffer, 1) {
                let (cb, cr) = chroma(x, y)
                chromaBase.storeBytes(of: cb, toByteOffset: y * chromaStride + x * 2, as: UInt8.self)
                chromaBase.storeBytes(of: cr, toByteOffset: y * chromaStride + x * 2 + 1, as: UInt8.self)
            }
        }
        return buffer
    }

    private func bgra(side: Int = 64) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, side, side, kCVPixelFormatType_32BGRA, nil, &created), kCVReturnSuccess)
        return try XCTUnwrap(created)
    }
}
