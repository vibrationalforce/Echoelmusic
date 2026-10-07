//
//  TheStemSessionEndsEveryTakeAtOneLengthTests.swift
//  Spatial S-A3c-2a. ADR-008 §2–§5: one owner arms every generated voice's tap, drains the rings
//  while the take runs, and ends the take only when no render pass can still hold a ring — with
//  every stem file the same length, and every interruption reported, never swallowed.
//  `StemCaptureSession` is that owner; this guard pins it on real taps, rings and files.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–10) — the shipped session, tap points, rings and writer. The
//    test thread plays the audio thread: it hands blocks to `StemTapPoint.capture` through a real
//    `AudioBufferList` + `AudioTimeStamp`, the seam an `AVAudioSourceNode` uses. Nothing is mocked.
//  · NOT PINNED, and said so: that the drain TIMER fires on time (claim 6 drives the drain by
//    hand, so the verdict never depends on a scheduler), and that anything in the app constructs
//    a session — nothing does yet (S-A3c-2b). Built: yes · wired: no · device: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid arming a voice stereo — it pins
//  that a MONO source gets one stem and never reads a second buffer.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `StemCaptureSession` is
//  created by this commit (ONE absence, #486). The session's bookkeeping (arm-all-or-none, the
//  common end, the per-take counter deltas, `isClean`) was transcribed in Python: claim 3 is red
//  against a mutant that arms before checking every tap, claim 4 against one that ends at the
//  FIRST stem's end, claim 5 against one that ignores the invalid-time delta in `isClean`,
//  claim 6 against one whose `isClean` ignores silenced frames, claim 8 against one without the
//  duplicate-tap check, claim 9 against one that compares names before `fileSafe` or case-sensitive,
//  claim 10 against a `deinit`/`abort` that only cancels the timer (the first draft, review
//  2026-10-07 HIGH 1) and against one that never releases the claim. File round trips have no
//  transcription — their verdict is the CI run alone.
//
//  `Tests/CISmoke` is the blocking bundle.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
@testable import Echoelmusic

final class TheStemSessionEndsEveryTakeAtOneLengthTests: XCTestCase {

    private static let rate = 48_000.0
    private var directory = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StemSession-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Values on the 2^-8 grid inside ±0.5 survive a 24-bit integer round trip.
    private func ramp(_ count: Int, from first: Int = 0, sign: Float = 1) -> [Float] {
        (0..<count).map { sign * Float(((first + $0) % 100) + 1) / 256 }
    }

    /// One render block through a real `AudioBufferList`, one buffer per channel.
    private func render(_ tap: StemTapPoint, _ channels: [[Float]], at sampleTime: Double, valid: Bool = true) {
        let frames = channels.first?.count ?? 0
        let abl = AudioBufferList.allocate(maximumBuffers: channels.count)
        var storage: [UnsafeMutablePointer<Float>] = []
        for (i, channel) in channels.enumerated() {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: max(frames, 1))
            data.initialize(from: channel, count: frames)
            storage.append(data)
            abl[i] = AudioBuffer(mNumberChannels: 1,
                                 mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                                 mData: UnsafeMutableRawPointer(data))
        }
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = sampleTime
        stamp.mFlags = valid ? .sampleTimeValid : []
        withUnsafePointer(to: &stamp) { tap.capture(abl.unsafeMutablePointer, frameCount: frames, timestamp: $0) }
        for data in storage { data.deallocate() }
        free(abl.unsafeMutablePointer)
    }

    private func samples(_ name: String) throws -> [Float] {
        let file = try AVAudioFile(forReading: directory.appendingPathComponent(name + ".wav"))
        let frames = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: max(frames, 1)) else {
            XCTFail("no read buffer"); return []
        }
        try file.read(into: buffer, frameCount: frames)
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    private func assertSamples(_ actual: [Float], _ expected: [Float], _ message: String = "",
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "length — \(message)", file: file, line: line)
        for (index, (a, e)) in zip(actual, expected).enumerated() where abs(a - e) > 1e-5 {
            XCTFail("sample \(index): \(a) ≠ \(e) — \(message)", file: file, line: line)
            return
        }
    }

    private func session(_ sources: [StemCaptureSession.Source], ringFrames: Int = 4_096,
                         drainInterval: TimeInterval? = 0.25) -> StemCaptureSession {
        StemCaptureSession(sources: sources, directory: directory, sampleRate: Self.rate,
                           ringFrames: ringFrames, drainInterval: drainInterval)
    }

    // MARK: 1 — a take writes one file per stem, every one the same length, and lets go of every ring

    func testATakeWritesEveryStemAndReleasesEveryRing() async throws {
        let synth = StemTapPoint(), pad = StemTapPoint()
        let take = session([.init(name: "Synth", tap: synth, channels: .mono),
                            .init(name: "Pad", tap: pad, channels: .stereo)])
        try take.start(atSampleTime: 1_000)
        XCTAssertTrue(synth.isArmed && pad.isArmed, "every tap is armed for the take")
        for block in 0..<4 {
            let time = Double(1_000 + block * 64)
            render(synth, [ramp(64, from: block * 64)], at: time)
            render(pad, [ramp(64, from: block * 64), ramp(64, from: block * 64, sign: -1)], at: time)
        }
        let outcome = try await take.stop()
        XCTAssertEqual(outcome.stems.map(\.name), ["Synth", "Pad L", "Pad R"], "a stereo voice is two stems")
        XCTAssertEqual(outcome.stems.map(\.framesWritten), [256, 256, 256])
        XCTAssertTrue(outcome.isClean)
        XCTAssertEqual(outcome.files.count, 3)
        assertSamples(try samples("Synth"), ramp(256))
        assertSamples(try samples("Pad L"), ramp(256))
        assertSamples(try samples("Pad R"), ramp(256, sign: -1))
        XCTAssertFalse(synth.isArmed || pad.isArmed, "the take disarms every tap")
        XCTAssertFalse(synth.hasRetiredTarget || pad.hasRetiredTarget,
                       "the take ends only when no render pass can still hold a ring")
    }

    // MARK: 2 — a mono voice is armed mono: one stem, and a second buffer is never read

    func testAMonoVoiceGetsOneStemAndNeverItsSecondBuffer() async throws {
        let bass = StemTapPoint()
        let take = session([.init(name: "Bass", tap: bass, channels: .mono)])
        try take.start(atSampleTime: 0)
        // A two-buffer block, as the format-less fallback node would hand a mono voice.
        render(bass, [ramp(64), [Float](repeating: 0.25, count: 64)], at: 0)
        let outcome = try await take.stop()
        XCTAssertEqual(outcome.files.count, 1, "a mono source is ONE stem (S-A3b-2 note L-g)")
        assertSamples(try samples("Bass"), ramp(64), "only buffer 0 reaches the stem")
    }

    // MARK: 3 — one busy tap refuses the whole take before anything is armed

    func testABusyTapRefusesTheWholeTake() throws {
        let free = StemTapPoint(), busy = StemTapPoint()
        let other = StemTapTarget(left: StemCaptureRing(capacityFrames: 64, startSampleTime: 0), right: nil)
        XCTAssertTrue(busy.arm(other))
        let take = session([.init(name: "A", tap: free, channels: .mono),
                            .init(name: "B", tap: busy, channels: .mono)])
        XCTAssertThrowsError(try take.start(atSampleTime: 0)) {
            XCTAssertEqual($0 as? StemCaptureSession.SessionError, .tapBusy)
        }
        XCTAssertFalse(free.isArmed, "no take starts with a stem missing — nothing was armed")
        busy.disarm()
    }

    // MARK: 4 — a stem that rendered less is padded to the common end, and that is not a failure

    func testAShortStemIsPaddedToTheCommonEnd() async throws {
        let long = StemTapPoint(), short = StemTapPoint()
        // The SHORT stem comes first: an end taken from the first stem would cut the long one.
        let take = session([.init(name: "Short", tap: short, channels: .mono),
                            .init(name: "Long", tap: long, channels: .mono)])
        try take.start(atSampleTime: 500)
        for block in 0..<4 { render(long, [ramp(64, from: block * 64)], at: Double(500 + block * 64)) }
        for block in 0..<2 { render(short, [ramp(64, from: block * 64)], at: Double(500 + block * 64)) }
        let outcome = try await take.stop()
        XCTAssertEqual(outcome.stems.map(\.framesWritten), [256, 256], "the end is the last frame ANY stem got")
        XCTAssertEqual(outcome.stems.map(\.paddedFrames), [128, 0], "the fill is reported")
        XCTAssertTrue(outcome.isClean, "a silent tail is honest, not an interruption")
        assertSamples(Array(try samples("Short").suffix(128)), [Float](repeating: 0, count: 128))
    }

    // MARK: 5 — a block without a valid time makes the take unclean, loudly

    func testAnInvalidTimestampMakesTheTakeUnclean() async throws {
        let voice = StemTapPoint()
        let take = session([.init(name: "Body", tap: voice, channels: .mono)])
        try take.start(atSampleTime: 0)
        render(voice, [ramp(64)], at: 0)
        render(voice, [ramp(64)], at: 64, valid: false)
        let outcome = try await take.stop()
        XCTAssertEqual(outcome.invalidTimeBlocks, 1, "the skipped block is counted for THIS take")
        XCTAssertFalse(outcome.isClean, "an unclean take must never pass as a stem set")
    }

    // MARK: 6 — draining while the take runs keeps a small ring whole; not draining is caught

    func testTheDrainKeepsTheRingWholeAndALossIsCaught() async throws {
        let kept = StemTapPoint()
        let drained = session([.init(name: "Kept", tap: kept, channels: .mono)], ringFrames: 64, drainInterval: nil)
        try drained.start(atSampleTime: 0)
        for block in 0..<10 {
            render(kept, [ramp(32, from: block * 32)], at: Double(block * 32))
            try drained.drainNow()
        }
        let good = try await drained.stop()
        XCTAssertEqual(good.stems.first?.silencedFrames, 0)
        XCTAssertTrue(good.isClean)
        assertSamples(try samples("Kept"), ramp(320))

        let lost = StemTapPoint()
        let starved = session([.init(name: "Lost", tap: lost, channels: .mono)], ringFrames: 64, drainInterval: nil)
        try starved.start(atSampleTime: 0)
        for block in 0..<10 { render(lost, [ramp(32, from: block * 32)], at: Double(block * 32)) }
        let bad = try await starved.stop()
        XCTAssertEqual(bad.stems.first?.framesWritten, 320, "the loss keeps the length")
        XCTAssertGreaterThan(bad.stems.first?.silencedFrames ?? 0, 0)
        XCTAssertFalse(bad.isClean, "an overflowed ring is an interruption, never a quiet stem")
    }

    // MARK: 7 — misuse is refused, and a stem name is a safe file name

    func testMisuseIsRefusedAndNamesAreFileSafe() async throws {
        let take = session([.init(name: "X", tap: StemTapPoint(), channels: .mono)])
        do { _ = try await take.stop(); XCTFail("stop before start") } catch {
            XCTAssertEqual(error as? StemCaptureSession.SessionError, .notRunning)
        }
        try take.start(atSampleTime: 0)
        XCTAssertThrowsError(try take.start(atSampleTime: 0)) {
            XCTAssertEqual($0 as? StemCaptureSession.SessionError, .alreadyStarted)
        }
        _ = try await take.stop()
        do { _ = try await take.stop(); XCTFail("stop twice") } catch {
            XCTAssertEqual(error as? StemCaptureSession.SessionError, .notRunning)
        }
        XCTAssertThrowsError(try session([]).start(atSampleTime: 0)) {
            XCTAssertEqual($0 as? StemCaptureSession.SessionError, .noSources)
        }
        XCTAssertEqual(StemCaptureSession.fileSafe("a/b:c"), "a-b-c")
        XCTAssertEqual(StemCaptureSession.fileSafe("//"), "Stem")
    }

    // MARK: 8 — one tap twice, or one tap in two live takes, is refused: a tap has ONE owner

    func testATapHasOneOwner() async throws {
        let tap = StemTapPoint()
        XCTAssertThrowsError(try session([.init(name: "A", tap: tap, channels: .mono),
                                          .init(name: "B", tap: tap, channels: .mono)]).start(atSampleTime: 0)) {
            XCTAssertEqual($0 as? StemCaptureSession.SessionError, .duplicateTap)
        }
        XCTAssertFalse(tap.isArmed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path),
                       "a refused take is refused before anything is written")

        let first = session([.init(name: "First", tap: tap, channels: .mono)])
        try first.start(atSampleTime: 0)
        XCTAssertThrowsError(try session([.init(name: "Second", tap: tap, channels: .mono)]).start(atSampleTime: 0)) {
            XCTAssertEqual($0 as? StemCaptureSession.SessionError, .tapBusy, "a live take owns its taps")
        }
        _ = try await first.stop()
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("First.wav").path),
                      "the refused second take removed nothing of the first")
    }

    // MARK: 9 — stem names that collide as FILE names are refused before anything is armed

    func testCollidingStemFileNamesAreRefused() throws {
        let one = StemTapPoint(), two = StemTapPoint()
        let cases: [[StemCaptureSession.Source]] = [
            [.init(name: "Pad L", tap: one, channels: .mono), .init(name: "Pad", tap: two, channels: .stereo)],
            [.init(name: "a/b", tap: one, channels: .mono), .init(name: "a:b", tap: two, channels: .mono)],
            [.init(name: "Lead", tap: one, channels: .mono), .init(name: "LEAD", tap: two, channels: .mono)],
        ]
        for sources in cases {
            XCTAssertThrowsError(try session(sources).start(atSampleTime: 0)) {
                XCTAssertEqual($0 as? StemCaptureSession.SessionError, .nameCollision, "\(sources.map(\.name))")
            }
            XCTAssertFalse(one.isArmed || two.isArmed, "nothing is armed for a refused take")
        }
    }

    // MARK: 10 — an aborted or dropped take disarms, deletes its files and frees its taps

    func testAnAbortedOrDroppedTakeFreesItsTaps() throws {
        let voice = StemTapPoint()
        let aborted = session([.init(name: "Gone", tap: voice, channels: .mono)], drainInterval: nil)
        try aborted.start(atSampleTime: 0)
        render(voice, [ramp(64)], at: 0)
        aborted.abort()
        XCTAssertFalse(voice.isArmed, "abort disarms")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Gone.wav").path),
                       "an aborted take leaves no stem behind")

        // No timer: its tick holds the session for a moment, and `deinit` must run HERE.
        var dropped: StemCaptureSession? = session([.init(name: "Dropped", tap: voice, channels: .mono)],
                                                   drainInterval: nil)
        try dropped?.start(atSampleTime: 0)
        render(voice, [ramp(64)], at: 0)
        dropped = nil
        XCTAssertFalse(voice.isArmed, "a dropped take disarms in deinit, it does not leave the tap writing")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Dropped.wav").path))

        let next = session([.init(name: "Next", tap: voice, channels: .mono)])
        XCTAssertNoThrow(try next.start(atSampleTime: 0), "the next take finds the tap free (review 2026-10-07)")
        next.abort()
    }
}
#endif
