// AVideoTakeLandsThroughTheImportDoorTests.swift
// Echoel — One World C1 (founder 2026-10-15: "Video capture … Die workstation sollte alles
// können"). "Record Video" in the Workstation records the rear camera into a temporary file and
// lands it through the SAME transaction as "Import Video" — copy into `Media/Picture`, measure the
// copy, clip first, region second — then deletes the temporary file.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR: the card's recording clock reads minutes and seconds, never negative.
//   2. SOURCE-TEXT SCAN — the recorder: video only (no audio device), the app's audio session is
//      never touched (set BEFORE configuration, the "camera kills audio" law of `CameraCapture`),
//      the rear lens, not a main-actor type, every closure it hands its queue spelled `@Sendable`
//      (2613/2618), and no `NSLock` taken in an `async` body (`noasync`).
//   3. SOURCE-TEXT SCAN — the card: one camera owner, and production wins (founder 2026-10-15:
//      "Biofeedback ist nur ein kleines gimmick") — opening the card stops a running camera pulse
//      and says so; it hands the file over and writes no store.
//   4. SOURCE-TEXT SCAN — the door: "Record Video" sits in the Add menu, the card is mounted in the
//      plate (no new modal), a take and a picked file share ONE landing (`landVideo`), the take's
//      temporary file is deleted, and a piece without a video track gets one first.
//   6. SOURCE-TEXT SCAN — one take at a time, by identity (ChatGPT/Astra review of `e27de94d9`,
//      2026-10-15, findings 1–10): a take owns its file URLs and ignores answers for others; no
//      new take while the last one finalises (the bookkeeping is `VideoTakeLedger`, driven end to end
//      in `ATakeIsLandedExactlyOnceTests`); the result names each lens;
//      an unusable file is deleted; the cost is read after the commit; each take is upright as
//      held; the card holds a STARTING take and never drops it; a cancelled open builds nothing;
//      the landing fixes lanes by ID, lands both lenses at one position, and never deletes a take.
//   5. SOURCE-TEXT SCAN — both lenses (M1, the YoloBox replacement): a multi-cam phone records the
//      rear AND the front lens into two files (rear → video track 0, front → track 1, created
//      through the same creator when missing); a phone that cannot sustain both
//      (`hardwareCost > 1.0`) falls back to the rear lens; the lens choice reopens the camera only
//      after the old session let go of it.
//   ⚠️ NOT ASSERTED: the camera prompt (`NSCameraUsageDescription`) still says "No images are
//      stored" and names only the rear lens. `Resources/iOS/Info.plist` is founder-gated; the new
//      sentence (both lenses) waits in `scratchpads/LANDING_C1_camera_prompt.patch`. A claim here
//      would be red on a correct tree until the founder lands it (#364) — add it in that commit.
//
// ⚠️ HONEST GRADING (#433). Claim 1 names `VideoTakeCard`, which this commit creates, so the file
// does NOT compile against the parent and no assertion has a verdict there (one absence, #486):
// all four claims are FORWARD. Claim 5 and the M1 needles of claims 3 and 4 (`land(file, lane)`,
// `videoLane:`) are FORWARD against `fac13cdad` too: there the recorder has one lens and the
// landing one track. Transcribed in Python against the worktree. Stripper
// `SourceText.codeOnly`: TRAGEND for claim 2's `@MainActor` absence (the recorder's header names
// the attribute in prose; raw it would be red) — measured, not assumed. PROPHYLAKTISCH for the
// audio-device absence (0 raw hits either way).
//
// ⚠️ THE LIMIT. Nothing here opens a camera. Whether the preview shows, whether the take is
// upright, whether recording during playback stutters the song, and whether the take lands in
// time are DEVICE PROBES (NEEDS-FOUNDER-VERIFY: Add → Record Video, Record, ten seconds, Stop).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AVideoTakeLandsThroughTheImportDoorTests: XCTestCase {

    // MARK: 1 — the recording clock

    #if canImport(AVFoundation) && canImport(UIKit)
    func testTheRecordingClockReadsMinutesAndSeconds() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertTrue(VideoTakeCard.elapsed(from: start, to: start.addingTimeInterval(67)).hasSuffix(" 1:07"))
        XCTAssertTrue(VideoTakeCard.elapsed(from: start, to: start.addingTimeInterval(9.9)).hasSuffix(" 0:09"),
                      "whole seconds, truncated")
        XCTAssertTrue(VideoTakeCard.elapsed(from: start, to: start.addingTimeInterval(-5)).hasSuffix(" 0:00"),
                      "a clock that steps back never reads negative")
    }
    #endif

    // MARK: 2 — the recorder

    func testTheRecorderIsVideoOnlyAndOffMain() throws {
        let camera = try code("Sources/Echoelmusic/Video/VideoTakeCamera.swift")
        XCTAssertTrue(camera.contains("let output = AVCaptureMovieFileOutput()"))
        XCTAssertFalse(camera.contains("for: .audio"), "no microphone input — the sound comes with the microphone landing")
        XCTAssertTrue(camera.contains("position: .back"), "the rear lens")
        XCTAssertFalse(camera.contains("@MainActor"), "the recorder is not a main-actor type — its queue closures must not inherit it")
        let audioLaw = try XCTUnwrap(camera.range(of: "session.automaticallyConfiguresApplicationAudioSession = false"),
                                     "the capture session must never touch the app's audio session (camera kills audio)")
        let configure = try XCTUnwrap(camera.range(of: "session.beginConfiguration()"))
        XCTAssertLessThan(audioLaw.lowerBound, configure.lowerBound, "set BEFORE configuration, as `CameraCapture` does")
        let hops = camera.components(separatedBy: "queue.async {").count - 1
        XCTAssertGreaterThan(hops, 0, "ANCHOR: the recorder no longer uses its queue")
        XCTAssertEqual(camera.components(separatedBy: "queue.async { @Sendable").count - 1, hops,
                       "every closure handed to the session queue is spelled `@Sendable` (2613/2618)")
        // NSLock is `noasync`: the lock is taken only in synchronous helpers and continuation bodies.
        for body in asyncBodies(in: camera) {
            XCTAssertFalse(body.contains("lock.lock()") && !body.contains("withCheckedContinuation"),
                           "an `async` body takes the lock directly — move it into a synchronous helper")
        }
    }

    // MARK: 3 — the card

    func testTheCardTakesTheCameraFromThePulseAndWritesNoStore() throws {
        let card = try code("Sources/Echoelmusic/Studio/VideoTakeCard.swift")
        let open = try XCTUnwrap(slice(card, from: "private func openCamera() async {", to: "let recorder = VideoTakeCamera(bothCameras: bothCameras)"),
                                 "ANCHOR: `openCamera` is gone (#454)")
        XCTAssertTrue(open.contains("if cameraRPPG.isRunning {") && open.contains("cameraRPPG.stop()"),
                      "one lens, production first — the card stops the camera pulse BEFORE it builds the recorder")
        XCTAssertTrue(open.contains("pulsePaused = true"), "and remembers it, so the card can say the pulse is paused")
        XCTAssertTrue(card.contains("if pulsePaused {"))
        XCTAssertTrue(card.contains("land(files)") && card.contains("let land: (VideoTakeCamera.TakeFiles) -> Void"),
                      "a finished take is handed over WHOLE, each file under its lens — never as a numbered list")
        XCTAssertFalse(card.contains("files.enumerated()"),
                       "a position in a list is not a lens: a failed rear take would relabel the front file (finding 5)")
        for store in ["TimelineStore", "ClipStore", "timeline.", "clipStore."] {
            XCTAssertFalse(card.contains(store), "the card writes no store (`\(store)`) — the Workstation lands the take")
        }
        XCTAssertTrue(card.contains(".onDisappear { leave() }"), "leaving the plate releases the camera")
        let leave = try XCTUnwrap(slice(card, from: "private func leave() {", to: "private func shut() {"),
                                  "ANCHOR: `leave` is gone (#454)")
        XCTAssertTrue(leave.contains("if case .taken(let files) = await camera.stopRecording() { land(files) }"),
                      "leaving mid-take keeps the take — it is landed, never left in tmp")
        XCTAssertTrue(leave.contains("if phase == .recording || phase == .starting {"),
                      "leaving while the take is STARTING stops and lands it too (finding 3)")
        XCTAssertTrue(card.contains(".disabled(phase == .starting || phase == .recording || phase == .saving)"),
                      "the card cannot be closed while a take starts, records or saves")
        let starting = try XCTUnwrap(slice(card, from: "private func record() {", to: "private func stop() {"),
                                     "ANCHOR: `record` is gone (#454)")
        XCTAssertTrue(starting.contains("phase = .starting") && starting.contains("guard phase == .starting else { return }"),
                      "Record holds the card in `.starting` until the camera confirms, and a late answer changes nothing")
        let reopen = try XCTUnwrap(slice(card, from: "private func openCamera() async {", to: "private func record() {"))
        XCTAssertEqual(reopen.components(separatedBy: "guard !Task.isCancelled else").count - 1, 2,
                       "a cancelled open builds no recorder after the wait, and closes the one it opened (finding 4)")
        XCTAssertTrue(card.contains(".onChange(of: cameraRPPG.isRunning) { _, running in"),
                      "a camera pulse started mid-card ends the take instead of reading Recording over nothing")
    }

    // MARK: 5 — both lenses (M1)

    func testBothLensesFallBackToTheRearOne() throws {
        let camera = try code("Sources/Echoelmusic/Video/VideoTakeCamera.swift")
        XCTAssertTrue(camera.contains("AVCaptureMultiCamSession.isMultiCamSupported"),
                      "both lenses only on a phone that has a multi-cam session")
        XCTAssertTrue(camera.contains("position: .front"), "the second lens is the front one")
        XCTAssertTrue(camera.contains("let frontOutput = AVCaptureMovieFileOutput()"), "its own file")
        let both = try XCTUnwrap(slice(camera, from: "private func wireBoth(", to: "func startRecording("),
                                 "ANCHOR: `wireBoth` is gone (#454)")
        XCTAssertFalse(both.contains("hardwareCost"), "the cost is not read mid-configuration any more (finding 9)")
        let commit = try XCTUnwrap(camera.range(of: "session.commitConfiguration()"))
        let cost = try XCTUnwrap(camera.range(of: "multi.hardwareCost > 1.0"),
                                 "a phone that cannot sustain both lenses records the rear one alone")
        XCTAssertLessThan(commit.lowerBound, cost.lowerBound, "the cost is read AFTER the commit, as AVMultiCamPiP does")
        XCTAssertTrue(camera.contains("multi.removeConnection(front)"))
        XCTAssertTrue(camera.contains("rotation?.videoRotationAngleForHorizonLevelCapture"),
                      "each take is upright the way the phone is held, not a fixed 90° (finding 10)")
        XCTAssertTrue(camera.contains("connection.isVideoMirrored = false"), "the front take is unmirrored, as a camera records")
        let card = try code("Sources/Echoelmusic/Studio/VideoTakeCard.swift")
        XCTAssertTrue(card.contains(".task(id: bothCameras) { await openCamera() }"), "the lens choice reopens the camera")
        let open = try XCTUnwrap(slice(card, from: "private func openCamera() async {", to: "let opened = await recorder.open()"))
        XCTAssertTrue(open.contains("await camera?.closeAndWait()"),
                      "the old session lets go of the camera BEFORE the new one asks for it")
    }

    // MARK: 6 — one take at a time, by identity (review 2026-10-15)

    func testATakeOwnsItsFilesAndIsNeverMixedWithAnother() throws {
        let camera = try code("Sources/Echoelmusic/Video/VideoTakeCamera.swift")
        XCTAssertTrue(camera.contains("typealias TakeFiles = VideoTakeLedger.Files"), "a result names each lens")
        let ledger = try code("Sources/Echoelmusic/Video/VideoTakeLedger.swift")
        let begin = try XCTUnwrap(slice(ledger, from: "mutating func begin(", to: "mutating func requestStop("),
                                  "ANCHOR: the ledger's `begin` is gone (#454)")
        XCTAssertTrue(begin.contains("guard !takeInFlight, unclaimed == nil else { return false }"),
                      "no new take while the last one is still finalising its files (finding 1)")
        let finished = try XCTUnwrap(slice(ledger, from: "mutating func fileFinished(", to: "\n}\n"),
                                     "ANCHOR: the ledger's `fileFinished` is gone (#454)")
        XCTAssertTrue(finished.contains("guard isRear || isFront else { return (false, []) }"),
                      "an answer for a file this take does not own is ignored, never counted for another take")
        XCTAssertTrue(camera.contains("if !written { try? FileManager.default.removeItem(at: url) }"),
                      "a file AVFoundation calls unusable is not left behind (finding 8)")
        XCTAssertTrue(camera.contains("let step = ledger.fileFinished(url, written: written)"),
                      "the camera keeps no bookkeeping of its own — the ledger decides (B1)")

        let importer = try code("Sources/Echoelmusic/Sequencer/VideoImport.swift")
        XCTAssertTrue(importer.contains("deleteManagedCopy: { url in try? FileManager.default.removeItem(at: url) })"),
                      "a refused PICKED file deletes the copy it made")
        XCTAssertTrue(importer.contains("deleteManagedCopy: { _ in })"),
                      "a refused landing never deletes a take (finding 2)")
        let library = try code("Sources/Echoelmusic/Core/MediaLibrary.swift")
        XCTAssertTrue(library.contains("try FileManager.default.moveItem(at: source, to: dest)"),
                      "a take is MOVED into the library, not copied")
    }

    // MARK: 4 — the door

    func testTheDoorSharesTheImportLanding() throws {
        let door = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        let menu = try XCTUnwrap(slice(door, from: "private var addMenu: some View {", to: ".menuStyle(.button)"),
                                 "ANCHOR: the Add menu is gone (#454)")
        XCTAssertTrue(menu.contains("{ openVideoTake() } label: { Label(\"Record Video\""))
        XCTAssertTrue(door.contains("VideoTakeCard(land: { landTake($0) },"),
                      "the card is mounted in the plate and hands its take to the Workstation")
        XCTAssertTrue(door.contains("landVideo(url, laneID: lane.id)"),
                      "a picked file takes the same landing, onto the top video track")
        XCTAssertEqual(door.components(separatedBy: "VideoImport.perform(").count - 1, 1,
                       "ONE landing for a picked file (#416)")
        XCTAssertEqual(door.components(separatedBy: "VideoImport.performTake(").count - 1, 1,
                       "ONE landing for a camera take — both lenses in one transaction (B3)")
        let landing = try XCTUnwrap(slice(door, from: "private func landVideo(", to: "private func openVideoTake("),
                                    "ANCHOR: `landVideo` is gone (#454)")
        XCTAssertFalse(landing.contains("removeItem"), "the landing never deletes the file it was handed (finding 2)")
        XCTAssertTrue(landing.contains("bpm: bpm, laneID: laneID, startTick: nil)"),
                      "the lane is fixed by ID before the `await`, never re-read as a position (finding 6)")
        let take = try XCTUnwrap(slice(door, from: "private func landTake(", to: "private func landVideo("),
                                 "ANCHOR: `landTake` is gone (#454)")
        XCTAssertTrue(take.contains("addVideoTrack()"),
                      "a front take gets its own video track, through the same creator, before it lands")
        XCTAssertTrue(take.contains("rearLane: top, frontLane: below)"),
                      "both lenses land through ONE transaction, on lanes fixed before the `await` (findings 6, 7)")
        let open = try XCTUnwrap(slice(door, from: "private func openVideoTake(", to: "\n    }\n"))
        XCTAssertTrue(open.contains("if VideoImport.pictureLane(in: timeline.document) == nil { addVideoTrack() }"),
                      "a take needs a video track to land on — through the same creator as Add Video Track")
        XCTAssertEqual(door.components(separatedBy: ".fileImporter(").count - 1, 1, "still ONE importer (#W1)")
        XCTAssertFalse(door.contains(".sheet(") || door.contains(".fullScreenCover("),
                       "the camera card stands in the plate — no modal")
    }

    // MARK: helpers

    /// The bodies of the `async` functions in `text`, each from its declaration to the next `func`.
    private func asyncBodies(in text: String) -> [String] {
        text.components(separatedBy: "func ").dropFirst().filter { chunk in
            guard let paren = chunk.range(of: ")") else { return false }
            return chunk[paren.upperBound...].prefix(12).contains("async")
        }
    }

    private func slice(_ text: String, from: String, to: String) -> String? {
        guard let start = text.range(of: from),
              let end = text.range(of: to, range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.lowerBound..<end.lowerBound])
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func raw(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            return ""
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func code(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try raw(relativePath))
    }
}
