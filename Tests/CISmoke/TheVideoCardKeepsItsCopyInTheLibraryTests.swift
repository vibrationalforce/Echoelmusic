// TheVideoCardKeepsItsCopyInTheLibraryTests.swift
// GMMW VV-3a (founder 2026-10-14: „Danach VV-3 und VV-6"). The video card's copy of a picked video
// moves from the temporary folder into the media library's `Media/Video`, through
// `MediaLibrary.importVideo` — its first production caller — and is kept for EVERY readable video
// while the card shows it, so the next slice (VV-6, "Show in Visuals") has a file to play.
//
// WHAT KIND OF GREEN THIS IS (Tests/CISmoke/CLAUDE.md §1):
//   · END-TO-END BEHAVIOUR (claim 3) — `VideoLibraryLeftovers.sweep` on a real folder: what a
//     killed app left goes, a fresh copy and anything that is not a regular file stay.
//   · SOURCE-TEXT SCAN (claims 1, 2, 4) — the card is a `View` no test can render.
//   · DEVICE PROBE, OPEN — the copy lands in `Media/Video` under the picked name, a second pick
//     removes the first, leaving the Browse shelf removes it, a relaunch after a kill sweeps it.
//
// ⚠️ WHAT THIS DOES NOT SAY: that a video is durable material. The card owns its copy only while
// it shows the video; a library entry that survives, with a delete door, is VV-10, and `MediaAsset.Kind`
// stays audio-only until then (`TheMediaLibraryIsBrowsedAndPlacedTests`).
//
// HONEST GRADING against the parent (fea0aebfc, §3): the file does NOT compile there — it calls
// `VideoLibraryLeftovers`, created by this commit — so no assertion has a verdict on the parent
// (ONE absence, #486). Claims 1, 2 and 4 are FORWARD guards, transcribed in Python against the
// worktree and against the parent's card, where each is red for its named reason (no caller of
// `importVideo`; the `temporaryDirectory` copy; no library sweep). COUNTERWEIGHTS (#343): claim
// 3's fresh copy, sub-folder and hidden file survive the sweep.
//
// `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheVideoCardKeepsItsCopyInTheLibraryTests: XCTestCase {

    private static let card = "Sources/Echoelmusic/Studio/VideoSeedCard.swift"

    // MARK: 1 — one writer of `Media/Video`, and it is the card

    func testTheCardIsTheOneCallerOfImportVideo() throws {
        XCTAssertEqual(try filesUnderSources(containing: "MediaLibrary.importVideo("), ["Studio/VideoSeedCard.swift"], """
            `MediaLibrary.importVideo` has a caller other than the video card. The card's appear-time \
            sweep removes EVERY file that arrived in `Media/Video` before the card appeared — right only \
            while the card is the one writer. A second writer (the VV-8 picture lane, VV-10's library) \
            must first make that sweep ask who still uses a file, in the same commit.
            """)
        let card = try code(Self.card)
        XCTAssertEqual(card.components(separatedBy: "MediaLibrary.importVideo(").count - 1, 1)
        // The copy happens inside the picker's import closure — off the main actor (`load` is not).
        let closure = try XCTUnwrap(card.range(of: "FileRepresentation(importedContentType: .movie) { received in"))
        let rest = card[closure.upperBound...]
        let end = try XCTUnwrap(rest.range(of: "\n        }"))
        XCTAssertTrue(rest[..<end.lowerBound].contains("try MediaLibrary.importVideo(from: received.file)"),
                      "the library copy is made in the picker's closure, not on the main actor")
    }

    // MARK: 2 — no copy in the temporary folder any more, and every readable video keeps its copy

    func testTheCopyNoLongerLivesInTheTemporaryFolder() throws {
        let card = try code(Self.card)
        XCTAssertFalse(card.contains("temporaryDirectory"), "the card still copies to the temporary folder")
        XCTAssertTrue(card.contains("if read != nil, !Task.isCancelled {"), "every readable video keeps its copy")
        XCTAssertTrue(card.contains("try? FileManager.default.removeItem(at: file.url)"),
                      "COUNTERWEIGHT: an unreadable or cancelled copy is removed — exactly that URL")
        XCTAssertTrue(card.contains("if let kept = keptVideo { try? FileManager.default.removeItem(at: kept.url) }"),
                      "letting the video go removes exactly the kept file")
    }

    #if canImport(SwiftUI) && canImport(PhotosUI) && canImport(AVFoundation)
    // MARK: 3 — the sweep removes what arrived before, and nothing else

    func testTheSweepRemovesOnlyOldRegularFiles() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("echoel-vv3a-sweep-\(UUID().uuidString)",
                                                               isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let left = dir.appendingPathComponent("Beach.mov")
        try Data([0]).write(to: left)
        let folder = dir.appendingPathComponent("Somebody's folder", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let hidden = dir.appendingPathComponent(".keep")
        try Data([0]).write(to: hidden)

        // COUNTERWEIGHT: a cutoff before the file arrived removes nothing — a fresh pick survives.
        let none = await VideoLibraryLeftovers.sweep(in: dir, addedBefore: .distantPast)
        XCTAssertEqual(none, 0)
        XCTAssertTrue(fm.fileExists(atPath: left.path), "a copy that arrived after the cutoff is not an orphan")

        let removed = await VideoLibraryLeftovers.sweep(in: dir, addedBefore: .distantFuture)
        if removed == 0, (try? left.resourceValues(forKeys: [.addedToDirectoryDateKey]))?.addedToDirectoryDate == nil {
            throw XCTSkip("this file system reports no added-to-folder date — the sweep keeps everything (fail-safe)")
        }
        XCTAssertEqual(removed, 1, "only the leftover video")
        XCTAssertFalse(fm.fileExists(atPath: left.path))
        XCTAssertTrue(fm.fileExists(atPath: folder.path), "a folder is never swept")
        XCTAssertTrue(fm.fileExists(atPath: hidden.path), "a hidden file is never swept")
        let nothing = await VideoLibraryLeftovers.sweep(in: nil, addedBefore: .distantFuture)
        XCTAssertEqual(nothing, 0, "no library folder, nothing to do")
    }
    #endif

    // MARK: 4 — the card sweeps the library when it appears, by arrival date

    func testTheCardSweepsTheLibraryWhenItAppears() throws {
        let card = try code(Self.card)
        XCTAssertTrue(card.contains("await VideoLibraryLeftovers.sweep(addedBefore: appeared)"),
                      "the card no longer sweeps what a killed app left in `Media/Video`")
        XCTAssertTrue(card.contains(".addedToDirectoryDateKey"), """
            the sweep must key on the date a file was ADDED to the folder — a copy can carry the \
            source's old creation date, and a fresh pick would then look like an orphan
            """)
        XCTAssertFalse(card.contains(".creationDateKey"), "creation date is the wrong clock for a copy")
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
