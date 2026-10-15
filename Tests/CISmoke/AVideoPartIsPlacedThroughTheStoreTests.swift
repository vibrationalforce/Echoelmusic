// AVideoPartIsPlacedThroughTheStoreTests.swift
// Echoel — One World P1/P2 (founder 2026-10-15: "Video Spur fehlt"). The first reachable producer
// of a picture part: "Import Video" copies a picked file into `Media/Picture`, measures the COPY,
// and lands a `.video` clip plus one region on the video track the picture lane shows — clip first,
// region second, through the two stores.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`VideoImport.plan`, pure): the refusals in the audio import's order —
//      no readable length, then no video track, then a full part grid; a success is a `.video` clip
//      at the managed copy, spanning the file in whole bars at the song tempo (4.5 s at 120 BPM =
//      2.25 bars → 3, written from the algebra, #442), after the track's last part, on the FIRST
//      video track — the one `VideoLanePlayer.shownLane` names (#416).
//   2. END-TO-END BEHAVIOUR: what lands is what plays — the landed region is executable by the
//      Play predicate when its file resolves, and the engine's shot shows it.
//   3. SOURCE-TEXT SCAN: the transaction writes the clip BEFORE the region and deletes the copy on
//      a refusal; the copy goes to `Media/Picture` through the ONE function, which only
//      `VideoImport` calls; `resolveRef` looks there; the Workstation is the one door
//      (`VideoImport.perform(` and the track creator once each), its two menu items sit in the Add
//      menu, and the importer stays ONE.
//
// ⚠️ HONEST GRADING (#433). This file names `VideoImport` and `MediaLibrary.importPictureVideo`,
// which this same commit creates, so it does NOT compile against the parent and no assertion has a
// verdict there (one absence, #486): claims 1–3 are FORWARD. Transcribed in Python against the
// worktree. Stripper `SourceText.codeOnly`: TRAGEND for the `importPictureVideo(` census (the
// MediaLibrary doc names `VideoImport`, and the VideoImport header names the function in prose —
// a raw census would count the header as a second caller).
//
// ⚠️ THE LIMIT. Nothing here picks a file, copies one or measures one: whether the system picker
// offers the person's videos, whether the copy is fast enough on a long file and whether the part
// plays in time are DEVICE PROBES (NEEDS-FOUNDER-VERIFY: Add → Add Video Track, Add → Import Video,
// pick a clip, press Play — the picture runs with the song).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AVideoPartIsPlacedThroughTheStoreTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let managed = URL(fileURLWithPath: "/media/Picture/dawn.mov")

    private func plan(_ seconds: Double?, _ doc: TimelineDocument, slot: Int? = 0) -> Result<VideoImport.Landing, VideoImport.Failure> {
        VideoImport.plan(managed: Self.managed, durationSeconds: seconds, document: doc, freeSlotIndex: slot, bpm: 120,
                         videoLane: 0)
    }

    private func failure(_ result: Result<VideoImport.Landing, VideoImport.Failure>) -> VideoImport.Failure? {
        if case .failure(let f) = result { return f }
        return nil
    }

    // MARK: 1 — the plan

    func testThePlanRefusesInOrderAndLandsOnTheShownVideoTrack() throws {
        let video = TimelineLane(name: "Video 1", kind: .video)
        let second = TimelineLane(name: "Video 2", kind: .video)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let earlier = TimelineRegion(laneID: video.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * Self.bar)
        let doc = TimelineDocument(lanes: [audio, video, second], regions: [earlier])

        for bad in [nil, 0, -1, Double.nan, Double.infinity] as [Double?] {
            XCTAssertEqual(failure(plan(bad, doc)), .unreadableVideo, "no readable length: \(String(describing: bad))")
        }
        let noTrack = TimelineDocument(lanes: [audio], regions: [])
        XCTAssertEqual(failure(plan(nil, noTrack)), .unreadableVideo, "the file is refused first — the founder's order")
        XCTAssertEqual(failure(plan(4.5, noTrack)), .noPictureLane)
        XCTAssertEqual(failure(plan(4.5, doc, slot: nil)), .clipGridFull)

        guard case .success(let landing) = plan(4.5, doc, slot: 7) else { return XCTFail("a readable video lands") }
        XCTAssertEqual(landing.clip.kind, .video)
        XCTAssertEqual(landing.clip.mediaRef, Self.managed.path, "the clip points at the managed COPY")
        XCTAssertEqual(landing.clip.nativeDurationSeconds, 4.5)
        XCTAssertEqual(landing.clip.name, "dawn")
        XCTAssertEqual(landing.laneID, video.id, "the FIRST video track — the one the picture lane shows")
        XCTAssertEqual(VideoLanePlayer.shownLane(in: doc), video.id, "premise: the engine shows that one")
        XCTAssertEqual(landing.region.laneID, video.id)
        XCTAssertEqual(landing.region.clipID, landing.clip.id)
        XCTAssertEqual(landing.region.startTick, 2 * Self.bar, "after the track's last part")
        XCTAssertEqual(landing.region.lengthTicks, 3 * Self.bar, "4.5 s at 120 BPM is 2.25 bars, covered by 3")
        XCTAssertEqual(landing.slotIndex, 7)
    }

    // MARK: 2 — what lands is what plays

    func testTheLandedPartIsWhatTheEnginePlays() throws {
        let video = TimelineLane(name: "Video 1", kind: .video)
        let empty = TimelineDocument(lanes: [video], regions: [])
        guard case .success(let landing) = plan(4.5, empty) else { return XCTFail("a readable video lands") }
        let doc = TimelineDocument(lanes: [video], regions: [landing.region])
        let resolve: (UUID) -> URL? = { $0 == landing.clip.id ? Self.managed : nil }
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc, clips: [landing.clip], bpm: 120, resolveAudio: resolve),
                      "a landed picture part offers Play")
        let shot = try XCTUnwrap(VideoLanePlan.shot(in: doc, laneID: video.id, at: Self.bar, bpm: 120,
                                                    clip: { $0 == landing.clip.id ? landing.clip : nil },
                                                    resolveURL: resolve))
        XCTAssertEqual(shot.url, Self.managed)
        XCTAssertEqual(shot.mediaSeconds, 2, "one bar in at 120 BPM is 2 s of the file")
        let past = try XCTUnwrap(VideoLanePlan.shot(in: doc, laneID: video.id, at: 2 * Self.bar + Self.bar / 2, bpm: 120,
                                                    clip: { $0 == landing.clip.id ? landing.clip : nil },
                                                    resolveURL: resolve))
        XCTAssertTrue(past.holdsLastFrame, "past 4.5 s the covering bar holds the file's last frame")
    }

    // MARK: 3 — the transaction, the home and the door

    func testTheTransactionTheHomeAndTheDoor() throws {
        let importer = try code("Sources/Echoelmusic/Sequencer/VideoImport.swift")
        let commit = try XCTUnwrap(slice(importer, from: "public static func commit(", to: "#if canImport(AVFoundation)"),
                                   "ANCHOR: `VideoImport.commit` is gone (#454)")
        let clipWrite = try XCTUnwrap(commit.range(of: "clipStore.setClip(at: landing.slotIndex, landing.clip)"))
        let regionWrite = try XCTUnwrap(commit.range(of: "timeline.addRegion(landing.region)"))
        XCTAssertLessThan(clipWrite.lowerBound, regionWrite.lowerBound,
                          "the clip is written FIRST — playback resolves `clipID` through `ClipStore`")
        XCTAssertTrue(commit.contains("deleteManagedCopy(managed)"), "a refusal deletes exactly the copy it made")
        XCTAssertTrue(importer.contains("try MediaLibrary.importPictureVideo(from: pickedURL)"))
        XCTAssertTrue(importer.contains("timeline.addLane(kind: .video)"))

        let library = try code("Sources/Echoelmusic/Core/MediaLibrary.swift")
        XCTAssertTrue(library.contains("try copyIn(source, subdirectory: \"Media/Picture\", fallbackExt: \"mov\")"),
                      "picture parts live in `Media/Picture` — the video card sweeps `Media/Video` (VV-3a)")
        XCTAssertTrue(library.contains("\"Media/Audio\", \"Media/Video\", \"Media/Image\", \"Media/Picture\""),
                      "`resolveRef` looks in the picture home too, or a part would go dark after an app update (H6)")
        XCTAssertEqual(try filesUnderSources(containing: "importPictureVideo("),
                       ["Core/MediaLibrary.swift", "Sequencer/VideoImport.swift"], "one caller of the picture copy")

        let door = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(try filesUnderSources(containing: "VideoImport.perform("), ["Studio/WorkstationView.swift"])
        XCTAssertEqual(door.components(separatedBy: "VideoImport.addVideoTrack(timeline: timeline)").count - 1, 1)
        let menu = try XCTUnwrap(slice(door, from: "private var addMenu: some View {", to: ".menuStyle(.button)"),
                                 "ANCHOR: the Add menu is gone (#454)")
        XCTAssertTrue(menu.contains("{ addVideoTrack() } label: { Label(\"Add Video Track\""))
        XCTAssertTrue(menu.contains("{ openImporter(.video) } label: { Label(\"Import Video\""))
        XCTAssertEqual(door.components(separatedBy: ".fileImporter(").count - 1, 1, "still ONE importer (#W1)")
        XCTAssertTrue(door.contains("case .video: return UTType.movie"), "the importer asks for a movie when opened for video")
    }

    // MARK: helpers

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

    private func code(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            return ""
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// Every Swift file under `Sources/Echoelmusic/` whose CODE contains `needle`, relative, sorted.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("could not walk \(root.path)")
            return []
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }
}
