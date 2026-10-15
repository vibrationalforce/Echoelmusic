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
//   ⚠️ NOT ASSERTED: the camera prompt (`NSCameraUsageDescription`) still says "No images are
//      stored". `Resources/iOS/Info.plist` is founder-gated; the new sentence waits in
//      `scratchpads/LANDING_C1_camera_prompt.patch`. A claim here would be red on a correct tree
//      until he lands it (#364) — add it in the commit that lands the text.
//
// ⚠️ HONEST GRADING (#433). Claim 1 names `VideoTakeCard`, which this commit creates, so the file
// does NOT compile against the parent and no assertion has a verdict there (one absence, #486):
// all four claims are FORWARD. Transcribed in Python against the worktree. Stripper
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
        let open = try XCTUnwrap(slice(card, from: "private func openCamera() async {", to: "let recorder = VideoTakeCamera()"),
                                 "ANCHOR: `openCamera` is gone (#454)")
        XCTAssertTrue(open.contains("if cameraRPPG.isRunning {") && open.contains("cameraRPPG.stop()"),
                      "one lens, production first — the card stops the camera pulse BEFORE it builds the recorder")
        XCTAssertTrue(open.contains("pulsePaused = true"), "and remembers it, so the card can say the pulse is paused")
        XCTAssertTrue(card.contains("if pulsePaused {"))
        XCTAssertTrue(card.contains("land(file)"), "a finished take is handed to the Workstation")
        for store in ["TimelineStore", "ClipStore", "timeline.", "clipStore."] {
            XCTAssertFalse(card.contains(store), "the card writes no store (`\(store)`) — the Workstation lands the take")
        }
        XCTAssertTrue(card.contains(".onDisappear { camera?.close() }"), "leaving the plate releases the camera")
    }

    // MARK: 4 — the door

    func testTheDoorSharesTheImportLanding() throws {
        let door = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        let menu = try XCTUnwrap(slice(door, from: "private var addMenu: some View {", to: ".menuStyle(.button)"),
                                 "ANCHOR: the Add menu is gone (#454)")
        XCTAssertTrue(menu.contains("{ openVideoTake() } label: { Label(\"Record Video\""))
        XCTAssertTrue(door.contains("VideoTakeCard(land: { landVideo($0, discardSource: true) },"),
                      "the card is mounted in the plate and hands its take to the one landing")
        XCTAssertTrue(door.contains("landVideo(url, discardSource: false)"), "a picked file takes the same landing")
        XCTAssertEqual(door.components(separatedBy: "VideoImport.perform(").count - 1, 1,
                       "ONE landing for a picked file and a camera take (#416)")
        let landing = try XCTUnwrap(slice(door, from: "private func landVideo(", to: "private func openVideoTake("),
                                    "ANCHOR: `landVideo` is gone (#454)")
        XCTAssertTrue(landing.contains("if discardSource { try? FileManager.default.removeItem(at: url) }"),
                      "the take's temporary file is deleted once the copy exists or the landing refused")
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
