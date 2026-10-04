// TheBroadcastSendsTheMasterAndThePictureTogetherTests.swift
// Echoel — Broadcast B1 (founder release 2026-10-04, "BROADCAST AUSFÜHREN"): the stream path
// above the wire.
//
// WHAT IT GUARDS. A stream sends two tracks that a viewer must hear and see together, taken
// from the app without disturbing it: the MASTER MIX (after the master chain) from the ring the
// recorder already keeps, and the Echoelmusic VISUAL from a second draw of the one Metal view.
// Each RTMP track counts its timestamps from its own first message, so both are released only
// from one shared start `T0`; an overrun becomes silence, never a jump, so the sync survives
// it; the stream has ONE lifecycle owner (Go Live / Stop), and the stream key never reaches a
// status line.
//
// §1 LIMITS, per claim:
// · Claims 1–4 are PURE: the timebase, the start gate, the ring read plan, the destination
//   rules, redaction and the reconnect policy, as values.
// · Claim 5 is END-TO-END BEHAVIOUR of the publisher with a FAKE engine — it proves the phase
//   machine and the key's absence from every status sentence, not RTMP. Whether a real server
//   accepts the publish, and whether a receiver plays sound and picture in sync, are two further
//   facts no test here can reach (`docs/dev/BROADCAST_HAISHINKIT_FINISH.md` §4).
// · Claim 6 drives the PUMP with a synthetic master ring and a recording sink: sample-exact
//   start at T0, contiguous chunks, silence on overrun, black when no picture exists. It proves
//   the rules on the pump's queue, not the render thread's timing on a device.
// · Claim 7 is a SOURCE-TEXT SCAN: the master tap gained only the four-cell anchor (no lock,
//   no allocation, no actor hop), the stream installs no tap of its own, the renderer never
//   flips `framebufferOnly`, and the Patchbay no longer starts or stops the stream.
// · DEVICE PROBE, open: CPU/GPU cost of the second draw while live, thermal behaviour, and A/V
//   drift over a long stream against a receiver.
//
// §3 HONEST GRADING against the parent (470563f23): this file names `BroadcastTimebase`,
// `BroadcastStartGate`, `MasterRingReadPlan`, `BroadcastMasterPump`, `BroadcastEngine`,
// `BroadcastPhase` and `RetroCapture.masterRingView()`, none of which exist there — it DOES NOT
// COMPILE against the parent, so no assertion has a verdict there; graded by transcription.
// Claims 1–6 are FORWARD guards (they drive symbols this commit creates). Claim 7 carries one
// REGRESSION half for its named reason — the parent's `applyRouting` called `broadcast.start()`
// / `broadcast.stop()` from the Patchbay — and COUNTERWEIGHTS (the tap still fills the ring;
// `framebufferOnly` untouched; one master tap).
// Stripper `SourceText.codeOnly`: TRAGEND for claim 7 (the headers of `RetroCapture`, the
// renderer and `EchoelmusicApp` all name the forbidden shapes in prose).

#if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
import AVFoundation
import CoreVideo
import Foundation
import XCTest
@testable import Echoelmusic

// MARK: - Test doubles

/// A master ring the test writes: sample value == absolute frame index, so continuity is
/// readable from the samples themselves.
private final class SyntheticRing: MasterRingSource, @unchecked Sendable {
    private let lock = NSLock()
    private var view: MasterRingView
    init(writeFrame: Int64, capacity: Int, anchor: BroadcastAudioAnchor?) {
        view = MasterRingView(writeFrame: writeFrame, capacity: capacity, anchor: anchor)
    }
    func set(writeFrame: Int64) {
        lock.lock(); defer { lock.unlock() }
        view = MasterRingView(writeFrame: writeFrame, capacity: view.capacity, anchor: view.anchor)
    }
    func masterRingView() -> MasterRingView { lock.lock(); defer { lock.unlock() }; return view }
    func copyMasterFrames(from start: Int64, count: Int,
                          left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) -> Bool {
        let v = masterRingView()
        guard start >= 0, start + Int64(count) <= v.writeFrame,
              v.writeFrame - start <= Int64(v.capacity) else { return false }
        for i in 0..<count { left[i] = Float(start + Int64(i)); right[i] = -Float(start + Int64(i)) }
        return true
    }
}

/// Records what the pump hands over.
private final class RecordingSink: BroadcastMediaSink, @unchecked Sendable {
    private let lock = NSLock()
    private var _audio: [(first: Float, count: Int, ticks: UInt64)] = []
    private var _video: [UInt64] = []
    func appendAudio(_ chunk: BroadcastAudioChunk) {
        let n = Int(chunk.buffer.frameLength)
        let first = chunk.buffer.floatChannelData.map { $0[0][0] } ?? .nan
        lock.lock(); _audio.append((first, n, chunk.hostTicks)); lock.unlock()
    }
    func appendVideo(_ frame: BroadcastVideoFrame, stampTicks: UInt64) {
        lock.lock(); _video.append(stampTicks); lock.unlock()
    }
    var audio: [(first: Float, count: Int, ticks: UInt64)] { lock.lock(); defer { lock.unlock() }; return _audio }
    var video: [UInt64] { lock.lock(); defer { lock.unlock() }; return _video }
}

/// An engine that never touches a network.
private final class FakeEngine: BroadcastEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var lost: (@Sendable () -> Void)?
    var failNext: BroadcastEngineError?
    private(set) var receivedNames: [String] = []
    func start(url: String, streamName: String, settings: BroadcastEncodeSettings) async throws -> BroadcastMediaSink {
        lock.lock(); receivedNames.append(streamName); let fail = failNext; lock.unlock()
        if let fail { throw fail }
        return RecordingSink()
    }
    func stop() async {}
    func setConnectionLostHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); lost = handler; lock.unlock()
    }
    func dropConnection() { lock.lock(); let h = lost; lock.unlock(); h?() }
}

private final class MemoryKeyStore: StreamSecretStore {
    var value: String?
    init(_ value: String?) { self.value = value }
    func read() -> String? { value }
    @discardableResult func write(_ secret: String) -> Bool { value = secret.isEmpty ? nil : secret; return true }
    @discardableResult func delete() -> Bool { value = nil; return true }
}

@MainActor
final class TheBroadcastSendsTheMasterAndThePictureTogetherTests: XCTestCase {

    private static let tb = BroadcastTimebase(ticksPerSecond: 1_000_000_000)   // 1 tick = 1 ns
    private static let key = "live_secret_9876"

    // MARK: 1 — one clock: ticks ↔ seconds, frames ↔ host time

    func testTheTimebaseAndTheAnchorAreInverse() {
        let tb = Self.tb
        XCTAssertEqual(tb.ticks(seconds: 1.5), 1_500_000_000)
        XCTAssertEqual(tb.seconds(ticks: 250_000_000), 0.25, accuracy: 1e-12)
        XCTAssertEqual(tb.ticks(seconds: .nan), 0, "a non-finite duration is no time, never a trap")
        XCTAssertEqual(BroadcastTimebase(ticksPerSecond: 0).ticksPerSecond, 1e9, "a zero rate falls back, never divides")

        let anchor = BroadcastAudioAnchor(frame: 48_000, hostTicks: 2_000_000_000, sampleRate: 48_000)
        XCTAssertEqual(anchor.hostTicks(forFrame: 96_000, timebase: tb), 3_000_000_000)
        XCTAssertEqual(anchor.hostTicks(forFrame: 0, timebase: tb), 1_000_000_000, "history behind the anchor is addressable")
        XCTAssertEqual(anchor.frame(atHostTicks: 3_000_000_000, timebase: tb), 96_000)
        // Rounded UP: the first audio frame is never earlier than T0.
        XCTAssertEqual(anchor.frame(atHostTicks: 2_000_000_001, timebase: tb), 48_001)
        XCTAssertFalse(BroadcastAudioAnchor(frame: 0, hostTicks: 1, sampleRate: .nan).isUsable)
    }

    // MARK: 2 — both tracks start at T0

    func testBothTracksStartAtTheSameInstant() {
        let t0: UInt64 = 5_000_000_000
        XCTAssertNil(BroadcastStartGate.videoStamp(renderedAt: t0 - 1, startTicks: t0, isFirst: true),
                     "a picture from before T0 is not sent at all")
        XCTAssertEqual(BroadcastStartGate.videoStamp(renderedAt: t0 + 7_000_000, startTicks: t0, isFirst: true), t0,
                       "the FIRST picture carries T0, so the picture track's zero is the audio track's zero")
        XCTAssertEqual(BroadcastStartGate.videoStamp(renderedAt: t0 + 40_000_000, startTicks: t0, isFirst: false),
                       t0 + 40_000_000, "later pictures carry their own render time")
        let anchor = BroadcastAudioAnchor(frame: 0, hostTicks: 4_000_000_000, sampleRate: 48_000)
        XCTAssertEqual(BroadcastStartGate.firstAudioFrame(anchor: anchor, startTicks: t0, timebase: Self.tb), 48_000,
                       "the first audio frame is the one rendered at T0")
        XCTAssertNil(BroadcastStartGate.firstAudioFrame(anchor: nil, startTicks: t0, timebase: Self.tb))
        XCTAssertGreaterThan(BroadcastStartGate.startTicks(now: 1_000, timebase: Self.tb), 1_000,
                             "T0 sits ahead of the decision, so neither track starts on stale material")
    }

    // MARK: 3 — an overrun is silence, never a jump

    func testAnOverrunBecomesSilenceNotAJump() {
        let view = MasterRingView(writeFrame: 10_000, capacity: 48_000, anchor: nil)
        XCTAssertEqual(MasterRingReadPlan.next(readFrame: 10_000, view: view, maxChunk: 1024), .wait)
        XCTAssertEqual(MasterRingReadPlan.next(readFrame: 9_500, view: view, maxChunk: 1024), .read(from: 9_500, count: 500))
        XCTAssertEqual(MasterRingReadPlan.next(readFrame: 0, view: view, maxChunk: 1024), .read(from: 0, count: 1024))
        let behind = MasterRingView(writeFrame: 100_000, capacity: 48_000, anchor: nil)
        guard case .silence(let from, let count) = MasterRingReadPlan.next(readFrame: 0, view: behind, maxChunk: 1024) else {
            return XCTFail("a reader more than half a ring behind must silence the gap")
        }
        XCTAssertEqual(from, 0, "the silence starts exactly where the reader stood — no frame is skipped")
        XCTAssertEqual(count, 1024)
        XCTAssertEqual(MasterRingReadPlan.next(readFrame: 0, view: MasterRingView(writeFrame: 5, capacity: 0, anchor: nil),
                                               maxChunk: 1024), .wait, "an empty ring is no work, never a trap")
    }

    // MARK: 4 — the destination, the key and the retries

    func testTheDestinationKeyAndRetriesFollowTheRules() {
        XCTAssertNil(BroadcastDestination.validate("rtmp://a.rtmp.example.com/live2"))
        XCTAssertNil(BroadcastDestination.validate("rtmps://a.rtmp.example.com:443/live2"))
        XCTAssertEqual(BroadcastDestination.validate(""), .notConfigured)
        XCTAssertEqual(BroadcastDestination.validate("srt://host:9000"), .unsupportedScheme, "SRT is not in this build")
        XCTAssertEqual(BroadcastDestination.validate("https://example.com"), .unsupportedScheme)
        XCTAssertEqual(BroadcastDestination.validate("rtmp://"), .invalidURL)
        XCTAssertEqual(BroadcastDestination.validate("rtmp://host/live two"), .invalidURL)
        XCTAssertTrue(BroadcastDestination.isEncrypted("RTMPS://host/app"))
        XCTAssertFalse(BroadcastDestination.isEncrypted("rtmp://host/app"))

        XCTAssertEqual(BroadcastRedaction.scrub("publish rtmp://h/app/\(Self.key) failed", secret: Self.key),
                       "publish rtmp://h/app/••• failed")
        XCTAssertEqual(BroadcastRedaction.scrub("the end", secret: "e"), "the end", "a one-letter key masks no ordinary words")

        XCTAssertEqual((1...5).compactMap { BroadcastReconnectPolicy.delaySeconds(attempt: $0) }, [1, 2, 4, 8, 16])
        XCTAssertNil(BroadcastReconnectPolicy.delaySeconds(attempt: 6), "retries are bounded — the stream ENDS and says so")
        XCTAssertNil(BroadcastReconnectPolicy.delaySeconds(attempt: 0))
        for failure in [BroadcastFailure.engineMissing, .notConfigured, .noSound, .invalidURL, .unsupportedScheme,
                        .connectFailed, .publishRejected, .retriesExhausted] {
            XCTAssertFalse(BroadcastStatusWords.text(for: failure).isEmpty, "\(failure) has a sentence")
        }
        XCTAssertFalse(BroadcastStatusWords.text(for: .connecting, encrypted: false).localizedCaseInsensitiveContains("live"),
                       "connecting never claims live")
    }

    // MARK: 5 — the publisher's phases, with a fake engine; the key never reaches a status line

    func testThePublisherWalksItsPhasesAndNeverShowsTheKey() async throws {
        let engine = FakeEngine()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "echoel.test.broadcast.\(UUID().uuidString)"))
        let publisher = BroadcastPublisher(keyStore: MemoryKeyStore(Self.key), defaults: defaults, engine: engine)
        let previousURL = UserDefaults.standard.string(forKey: "broadcast.url")
        addTeardownBlock { UserDefaults.standard.set(previousURL, forKey: "broadcast.url") }
        XCTAssertTrue(publisher.engineAvailable)
        publisher.url = "rtmp://ingest.example.invalid/live/\(Self.key)"   // a key pasted into the URL, too

        publisher.start()
        XCTAssertEqual(publisher.phase, .failed(.noSound), "no master ring attached → an honest sentence, no connect")
        XCTAssertTrue(engine.receivedNames.isEmpty)

        let ring = SyntheticRing(writeFrame: 0, capacity: 48_000, anchor: nil)
        publisher.attach(ring: ring)
        publisher.start()
        XCTAssertEqual(publisher.phase, .connecting)
        try await waitUntil { publisher.phase == .live }
        XCTAssertEqual(engine.receivedNames, [Self.key], "the key reaches the engine as the publish name, and only there")
        XCTAssertFalse(publisher.statusMessage.contains(Self.key))
        XCTAssertTrue(publisher.isLive)

        engine.dropConnection()
        try await waitUntil { publisher.phase == .reconnecting(attempt: 1) }
        XCTAssertFalse(publisher.statusMessage.contains(Self.key))
        XCTAssertTrue(publisher.isLive, "while reconnecting the button still reads Stop")

        publisher.stop()
        try await waitUntil { publisher.phase == .idle }
        XCTAssertFalse(publisher.isLive)

        engine.failNext = .publishRejected
        publisher.start()
        try await waitUntil { publisher.phase == .failed(.publishRejected) }
        XCTAssertFalse(publisher.statusMessage.contains(Self.key))
        XCTAssertEqual(publisher.statusMessage, BroadcastStatusWords.text(for: .publishRejected))
    }

    // MARK: 6 — the pump: sample-exact start, contiguous chunks, silence on overrun, black picture

    func testThePumpStartsAtT0AndKeepsTheAudioContiguous() throws {
        let anchor = BroadcastAudioAnchor(frame: 0, hostTicks: 1_000_000_000, sampleRate: 48_000)
        let ring = SyntheticRing(writeFrame: 30_000, capacity: 1_440_000, anchor: anchor)
        let tap = BroadcastVideoTap()
        let clock = Clock(1_400_000_000)
        let pump = BroadcastMasterPump(ring: ring, video: tap, timebase: Self.tb, now: { clock.value })
        let sink = RecordingSink()
        let t0: UInt64 = 1_500_000_000                                   // = frame 24 000
        pump.start(sink: sink, spec: .standard, startTicks: t0)
        defer { pump.stop() }
        pump.tickForTesting()

        let audio = sink.audio
        let first = try XCTUnwrap(audio.first, "no audio left the pump")
        XCTAssertEqual(first.first, 24_000, "the first sample sent is the one rendered at T0")
        XCTAssertEqual(first.ticks, t0, "and it is stamped T0")
        var expected: Float = 24_000
        for chunk in audio {
            XCTAssertEqual(chunk.first, expected, "chunks are contiguous — no frame skipped or repeated")
            expected += Float(chunk.count)
        }
        XCTAssertEqual(expected, 30_000, "everything written up to the tap's head was sent")
        XCTAssertTrue(sink.video.isEmpty, "no picture before T0")

        // The reader falls far behind: the gap is filled with silence, the position does not jump.
        ring.set(writeFrame: 30_000 + 1_000_000)
        pump.tickForTesting()
        XCTAssertGreaterThan(pump.snapshot().silencedSeconds, 0, "an overrun is counted")
        let afterOverrun = sink.audio.dropFirst(audio.count)
        let silent = try XCTUnwrap(afterOverrun.first)
        XCTAssertEqual(silent.first, 0, "the silenced chunk carries zeros")
        XCTAssertEqual(silent.ticks, anchor.hostTicks(forFrame: 30_000, timebase: Self.tb),
                       "and the time of the frames it replaces — the sound does not move earlier")
    }

    func testWithNoPictureTheStreamSendsBlackAndSaysSo() throws {
        let anchor = BroadcastAudioAnchor(frame: 0, hostTicks: 1_000_000_000, sampleRate: 48_000)
        let ring = SyntheticRing(writeFrame: 0, capacity: 48_000, anchor: anchor)
        let tap = BroadcastVideoTap()
        let t0: UInt64 = 2_000_000_000
        let clock = Clock(t0 + 600_000_000)                              // 0.6 s after T0, nothing drawn
        let pump = BroadcastMasterPump(ring: ring, video: tap, timebase: Self.tb, now: { clock.value })
        let sink = RecordingSink()
        pump.start(sink: sink, spec: BroadcastVideoSpec(width: 16, height: 16, framesPerSecond: 30), startTicks: t0)
        defer { pump.stop() }
        pump.tickForTesting()
        XCTAssertEqual(sink.video.first, t0, "the first (black) picture still carries T0")
        XCTAssertEqual(pump.snapshot().picture, .black)

        // A real picture arrives: it is sent with its own time and the state says "rendering".
        let spec = try XCTUnwrap(tap.dueFrame(nowTicks: t0 + 700_000_000))
        let pb = try XCTUnwrap(BroadcastFrameTarget.blackFrame(width: spec.width, height: spec.height))
        tap.deliver(BroadcastVideoFrame(pixelBuffer: pb, hostTicks: t0 + 700_000_000, metalTexture: nil))
        clock.value = t0 + 710_000_000
        pump.tickForTesting()
        XCTAssertEqual(sink.video.last, t0 + 700_000_000)
        XCTAssertEqual(pump.snapshot().picture, .rendering)
        XCTAssertEqual(sink.video, sink.video.sorted(), "picture stamps never go backwards")
    }

    func testTheVideoTapIsBounded() throws {
        let tap = BroadcastVideoTap()
        XCTAssertNil(tap.dueFrame(nowTicks: 1), "nothing is due while no stream wants pictures")
        tap.enable(BroadcastVideoSpec(width: 16, height: 16, framesPerSecond: 30), timebase: Self.tb)
        XCTAssertNotNil(tap.dueFrame(nowTicks: 1_000_000_000))
        XCTAssertNil(tap.dueFrame(nowTicks: 1_010_000_000), "at most one picture per frame interval")
        XCTAssertNotNil(tap.dueFrame(nowTicks: 1_040_000_000))
        XCTAssertNil(tap.dueFrame(nowTicks: 1_080_000_000), "at most \(BroadcastVideoTap.maxInFlight) in flight")
        XCTAssertGreaterThan(tap.droppedFrames, 0, "a shed picture is counted")
        let pb = try XCTUnwrap(BroadcastFrameTarget.blackFrame(width: 16, height: 16))
        for i in 0..<(BroadcastVideoTap.capacity + 2) {
            tap.deliver(BroadcastVideoFrame(pixelBuffer: pb, hostTicks: UInt64(i + 1), metalTexture: nil))
        }
        XCTAssertEqual(tap.drain().count, BroadcastVideoTap.capacity, "the handoff never grows past its capacity")
    }

    // MARK: 7 — SOURCE: the tap gained only the anchor; one lifecycle owner; the drawable stays write-only

    func testTheRenderPathsGainedNoLockAndThePatchbayOwnsNothing() throws {
        let capture = try source("Sources/Echoelmusic/Audio/RetroCapture.swift")
        let tap = try tapBody(capture)
        XCTAssertTrue(tap.contains("anchorPtr[2] = when.hostTime"), "the anchor write is in the master tap")
        XCTAssertTrue(tap.contains("ringPtr[slot]"), "counterweight: the tap still fills the ring")
        let banned = ["NSLock", ".lock()", "Task {", "Task.detached", "DispatchQueue", "BroadcastVideoTap",
                      "BroadcastMasterPump", "AVAudioPCMBuffer(", "log.log", "os_log", "Array(", ".append("]
        let hits = banned.filter { tap.contains($0) }
        XCTAssertTrue(hits.isEmpty, "the master tap contains \(hits) — the render thread must not learn a stream exists")

        let sourcesWithTaps = try filesUnderSources { $0.contains("installTap(onBus:") }
        XCTAssertFalse(sourcesWithTaps.contains { $0.hasPrefix("Stream/") },
                       "the stream installs no tap of its own — it reads the recorder's ring")

        let renderer = try source("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertFalse(renderer.contains("framebufferOnly = false"),
                       "the on-screen drawable stays write-only; the stream renders its own target")
        XCTAssertTrue(renderer.contains("BroadcastVideoTap.shared.dueFrame("), "the renderer asks the tap")

        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertFalse(app.contains("broadcast.start()") || app.contains("broadcast.stop()"), """
            `EchoelmusicApp` starts or stops the stream. The stream has ONE lifecycle owner — Go Live / \
            Stop in `BroadcastView` — for the BLE-3 reason: a routing edit must never end a live stream.
            """)
        let publisher = try source("Sources/Echoelmusic/Stream/BroadcastPublisher.swift")
        XCTAssertFalse(publisher.contains("\\(streamKey"), "the key is never interpolated into a string")
        XCTAssertFalse(publisher.contains("\\(key"), "nor under a local name")
    }

    // MARK: - Helpers

    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: UInt64
        init(_ v: UInt64) { _value = v }
        var value: UInt64 {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("condition not reached within 3 s", file: file, line: line)
    }

    private struct AnchorMissing: Error { let reason: String }

    /// The closure passed to the master `installTap`, comments stripped (same bounds as
    /// `TheCaptureTapDoesNotTouchTheDiskTests`).
    private func tapBody(_ code: String) throws -> String {
        let lines = code.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { $0.contains("node.installTap(onBus: 0") }),
              let close = lines[(open + 1)...].firstIndex(where: { $0 == "        }" }) else {
            throw AnchorMissing(reason: "the master tap closure in RetroCapture moved — re-anchor (#454)")
        }
        return lines[open...close].joined(separator: "\n")
    }

    private func filesUnderSources(_ match: (String) -> Bool) throws -> [String] {
        let root = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw AnchorMissing(reason: "cannot enumerate Sources — a scan that saw nothing is not a pass")
        }
        var hits: [String] = []
        var scanned = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            scanned += 1
            if match(SourceText.codeOnly(text)) { hits.append(relative) }
        }
        XCTAssertGreaterThan(scanned, 100, "the walker must actually see the sources (#454)")
        return hits
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
#endif
