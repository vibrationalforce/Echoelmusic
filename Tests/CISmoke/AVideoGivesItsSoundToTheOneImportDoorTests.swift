// AVideoGivesItsSoundToTheOneImportDoorTests.swift
// Restructure E12-1 (founder 2026-10-04: „Beats aus Samples und Video als musikalisches Material
// gehören bereits zum DMMW-Ziel. Plane dafür jeweils den kleinsten vollständigen Nutzerweg.")
//
// The smallest complete path for a video's sound: "Use Its Sound" on the video card exports the
// sound track to a temporary `.m4a` (`VideoSound`) and hands it to the Workstation's ONE import
// door, which copies it into the library, places it as a part on the first audio track, and
// starts the same tempo and key analysis as a file from Files.
//
// WHAT KIND OF GREEN THIS IS (Tests/CISmoke/CLAUDE.md §1):
//   · END-TO-END BEHAVIOUR (claims 1–2) — `VideoSound.soundFileBase` names the file, and
//     `VideoSound.discard` removes exactly the folder `extract` makes and nothing else.
//   · SOURCE-TEXT SCAN (claims 3–5) — the card and the Workstation are `View`s no test can render.
//     Claim 3: there is still ONE import door (`AudioImport.perform` has one caller, and the card
//     never names the importer). Claim 4: no picture is encoded (#1304). Claim 5: the card keeps
//     the video's copy only while its sound can be used, and offers the button only then.
//   · DEVICE PROBE, OPEN — the export actually produces audio for a real clip, the part plays,
//     the file appears in the library, VoiceOver reads the button: G8 in `docs/dev/FOUNDER_INBOX.md`.
//
// HONEST GRADING against the parent (861f78568, §3): the file does NOT compile there — it calls
// `VideoSound`, created by this commit — so no assertion has a verdict on the parent (ONE absence,
// #486). Every claim is a FORWARD guard, transcribed in Python against the worktree; mutants
// driven, each red for its named reason: a second `AudioImport.perform(` caller (claim 3), the card
// naming `AudioImport` (claim 3), a video export preset (claim 4), `discard` without its prefix
// check (claim 2), the button shown in every state (claim 5). COUNTERWEIGHTS (#343): claim 2's
// foreign folder survives; claim 3's Files import still goes through the same function.
//
// `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class AVideoGivesItsSoundToTheOneImportDoorTests: XCTestCase {

    private static let card = "Sources/Echoelmusic/Studio/VideoSeedCard.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let sound = "Sources/Echoelmusic/Sequencer/VideoSound.swift"

    #if canImport(AVFoundation)
    // MARK: 1 — the sound file is named after the video

    func testTheSoundIsNamedAfterTheVideo() {
        XCTAssertEqual(VideoSound.soundFileBase(videoName: "Beach"), "Beach sound")
        XCTAssertEqual(VideoSound.soundFileBase(videoName: "  Beach \n"), "Beach sound",
                       "whitespace around the picker's name is not part of the name")
        XCTAssertEqual(VideoSound.soundFileBase(videoName: "   "), "Video sound",
                       "an empty name still gives the library a readable one")
    }

    // MARK: 2 — the export's folder is removed, and only that folder

    func testDiscardRemovesOnlyTheExportFolder() throws {
        let fm = FileManager.default
        let export = fm.temporaryDirectory
            .appendingPathComponent("echoel-video-sound-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: export, withIntermediateDirectories: true)
        let file = export.appendingPathComponent("Beach sound.m4a")
        try Data([0]).write(to: file)
        VideoSound.discard(file)
        XCTAssertFalse(fm.fileExists(atPath: export.path), "the export's own folder goes with the file")

        // COUNTERWEIGHT: a file anywhere else is never the export's to remove.
        let foreign = fm.temporaryDirectory
            .appendingPathComponent("echoel-other-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: foreign, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: foreign) }
        let kept = foreign.appendingPathComponent("Kick.wav")
        try Data([0]).write(to: kept)
        VideoSound.discard(kept)
        XCTAssertTrue(fm.fileExists(atPath: kept.path), """
            `VideoSound.discard` removed a folder it did not make. It must check the \
            `echoel-video-sound-` prefix — a library or project folder handed to it would be deleted.
            """)
    }
    #endif

    // MARK: 3 — one import door: the card hands the file over, the Workstation imports it

    func testTheSoundGoesThroughTheOneImportDoor() throws {
        XCTAssertEqual(try filesUnderSources(containing: "AudioImport.perform("), ["Studio/WorkstationView.swift"], """
            `AudioImport.perform` has a second caller. The video's sound must land through the \
            Workstation's door (`useVideoSound` → `importAudioFile`), so placement, library copy and \
            analysis stay one transaction.
            """)
        let card = try code(Self.card)
        for importer in ["AudioImport", "MediaLibrary", "ClipStore", "TimelineStore", "tuningPending"] {
            XCTAssertFalse(card.contains(importer), "the video card reaches into the import: `\(importer)`")
        }
        XCTAssertEqual(card.components(separatedBy: "useSound(").count - 1, 1, "the card calls the door once")
        XCTAssertTrue(card.contains("let useSound: @MainActor (URL) -> VideoSoundLanding"))

        let workstation = try code(Self.workstation)
        XCTAssertEqual(workstation.components(separatedBy: "AudioImport.perform(").count - 1, 1)
        XCTAssertTrue(workstation.contains("private func importAudioFile(_ url: URL) -> Bool {"))
        XCTAssertTrue(workstation.contains("let placed = importAudioFile(file)"),
                      "the video's sound goes through the one import function")
        XCTAssertTrue(workstation.contains("importAudioFile(url)"),
                      "COUNTERWEIGHT: a file from Files still goes through the same function")
        XCTAssertTrue(workstation.contains("VideoSeedCard(useSound: useVideoSound)"))
    }

    // MARK: 4 — no picture is encoded

    func testOnlySoundIsExported() throws {
        let sound = try code(Self.sound)
        XCTAssertTrue(sound.contains("presetName: AVAssetExportPresetAppleM4A"), "the audio-only preset")
        XCTAssertTrue(sound.contains("try await session.export(to: out, as: .m4a)"))
        for video in ["AVAssetWriter", "mediaType: .video", "AVAssetExportPresetHighestQuality",
                      "AVAssetExportPresetPassthrough", ".mov", ".mp4"] {
            XCTAssertFalse(sound.contains(video), "the sound export writes a picture: `\(video)` (#1304)")
        }
        XCTAssertTrue(sound.contains("loadTracks(withMediaType: .audio)"), "a video without sound exports nothing")
    }

    // MARK: 5 — the copy is kept only while its sound can be used

    func testTheCardKeepsTheVideoOnlyWhileItsSoundCanBeUsed() throws {
        let card = try code(Self.card)
        XCTAssertTrue(card.contains("if soundState(read) == .usable { soundButton }"), """
            The button is no longer offered only while the card holds the video. In any other state \
            it would export from a file that is gone, or place the same sound twice.
            """)
        XCTAssertTrue(card.contains("if read?.hasAudioTrack == true, !Task.isCancelled {"),
                      "only a video with sound keeps its copy")
        XCTAssertTrue(card.contains("try? FileManager.default.removeItem(at: file.url)"),
                      "COUNTERWEIGHT: every other copy is removed right after the read")
        XCTAssertGreaterThanOrEqual(card.components(separatedBy: "discardSoundSource()").count - 1, 4,
                                    "the declaration plus three calls: a new pick, the card going away and a placed sound each let the copy go")
        XCTAssertTrue(card.contains("VideoSound.discard(extracted)"), "the exported file is removed after the import copied it")
        XCTAssertTrue(card.contains(".disabled(soundTask != nil)"), "one export at a time")
        XCTAssertTrue(card.contains(".accessibilityLabel(\"Use its sound\")"))
    }

    // MARK: - helpers

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func code(_ relative: String) throws -> String {
        let file = repoRoot().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: file, encoding: .utf8))
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot enumerate Sources/Echoelmusic — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }
}
