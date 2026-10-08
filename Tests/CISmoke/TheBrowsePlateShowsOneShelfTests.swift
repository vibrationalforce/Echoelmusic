// TheBrowsePlateShowsOneShelfTests.swift
// Echoel — GMMW P1-2 (founder 2026-10-08: „vermeide Unübersichtlichkeit", „Orientiere dich an den
// Bigplayern"). The Browse plate stacked the stored sounds, the media library and the two cards that
// shape the visual in one scroll. Every DAW browser asks for the category first and then lists it,
// so the plate now shows ONE shelf at a time behind a segmented row: Sounds · Media · Visuals — the
// cards' own headings ("Sounds", "Media Library", "Photo/Video to Visuals").
//
// WHAT IT PINS.
// 1. PURE: the three shelves, in that order; the plate opens on the sounds; each has its own word.
// 2. SOURCE: `browsePlate` starts with the segmented row, holds exactly one `if` per shelf, and
//    mounts every card inside its shelf's `if`. The photo and the video card stay behind their own
//    platform gates, inside the Visuals shelf.
// 3. SOURCE: the row is a segmented `Picker` over `BrowseShelf.allCases`, written only by a tap
//    (`@State`), and reads nothing hot — `WorkstationView` hosts pickers, so a hot read here would be
//    the 10.76.41/50 freeze.
// COUNTERWEIGHT (#343): each card still cleans up when it leaves — the photo and video cards cancel
// their read in `.onDisappear`, the library stops its preview. A shelf switch is the same event as
// leaving the plate, so this is what makes the switch safe.
// The mount counts stay where they are pinned today (#416): `SoundBrowserView()` once in Sources
// (`TheBrowsePlateOffersTheSoundsTests`), `MediaBrowserView()` once (`TheMediaLibraryIsBrowsedAndPlacedTests`),
// the two seed cards once each (`AVideoCardSaysWhatWasMeasuredTests`).
//
// Grading (§0, no Swift toolchain): on the parent (`3b15594`) this file does NOT COMPILE — it names
// `BrowseShelf`, which this commit creates — so no assertion has a verdict there; claims 1–3 are
// FORWARD guards and the counterweight is green on both trees. Claim 1 and every scan were
// transcribed into Python and driven on the worktree.
// NOT covered: how the segments read at large text sizes, and what VoiceOver speaks — device probes.
// NEEDS-FOUNDER-VERIFY: Browse → Sounds shows the stored sounds; Media shows the library; Visuals
// shows the photo and the video card. Apply a photo's look, switch to Sounds and back → the look
// stays on the visual, the card no longer holds the photo (the same as leaving the plate).

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class TheBrowsePlateShowsOneShelfTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    // MARK: 1 — three shelves, the sounds first

    func testThereAreThreeShelvesAndThePlateOpensOnTheSounds() {
        XCTAssertEqual(BrowseShelf.allCases, [.sounds, .media, .visuals], "Sounds · Media · Visuals")
        XCTAssertEqual(BrowseShelf.opening, .sounds, "the plate opens on the sounds, the first thing a track needs")
        let titles = BrowseShelf.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "each shelf has its own word")
        XCTAssertFalse(titles.contains(where: \.isEmpty), "no shelf is blank")
    }

    // MARK: 2 — one `if` per shelf, every card inside its shelf

    func testEveryCardSitsInsideItsShelf() throws {
        let plate = try member("private var browsePlate: some View {", in: try source(Self.workstation))
        guard let picker = plate.range(of: "browseShelfPicker"),
              let firstShelf = plate.range(of: "if browseShelf == .") else {
            return XCTFail("ANCHOR MISSING: `browseShelfPicker` or a shelf `if` in `browsePlate` (#454)")
        }
        XCTAssertLessThan(picker.lowerBound, firstShelf.lowerBound, "the segmented row comes first, above every shelf")

        let cards: [(BrowseShelf, [String])] = [
            (.sounds, ["SoundBrowserView()"]),
            (.media, ["MediaBrowserView()"]),
            (.visuals, ["#if canImport(PhotosUI) && canImport(ImageIO)", "PhotoSeedCard()",
                        "#if canImport(PhotosUI) && canImport(AVFoundation)", "VideoSeedCard(useSound: useVideoSound)"]),
        ]
        for (shelf, mounts) in cards {
            let head = "if browseShelf == .\(shelf.rawValue) {"
            XCTAssertEqual(plate.components(separatedBy: head).count - 1, 1, "exactly one `\(head)` in `browsePlate`")
            let body = try member(head, in: plate)
            for mount in mounts {
                XCTAssertEqual(plate.components(separatedBy: mount).count - 1, 1,
                               "`\(mount)` occurs exactly once on the plate — not lost, not shown twice")
                XCTAssertTrue(body.contains(mount), "`\(mount)` sits inside the \(shelf.rawValue) shelf")
            }
        }
    }

    // MARK: 3 — a segmented row, written by a tap

    func testTheRowIsASegmentedPickerWrittenByATap() throws {
        let code = try source(Self.workstation)
        XCTAssertEqual(code.components(separatedBy: "@State private var browseShelf = BrowseShelf.opening").count - 1, 1,
                       "the shelf is view state that starts at the opening shelf")
        let row = try member("private var browseShelfPicker: some View {", in: code)
        XCTAssertTrue(row.contains("Picker(\"Browse shelf\", selection: $browseShelf)"), "the row is a Picker over the shelf")
        XCTAssertTrue(row.contains("ForEach(BrowseShelf.allCases)"), "it offers every shelf")
        XCTAssertTrue(row.contains(".pickerStyle(.segmented)"), "a segmented row — named choices, not a number")
        for hot in ["player.", "transport.", "metronome.", "cameraRPPG", "masterLevel", "TimelineView("] {
            XCTAssertFalse(row.contains(hot), "`\(hot)` in the shelf row — `WorkstationView` hosts pickers (10.76.41/50)")
        }
        XCTAssertEqual(code.components(separatedBy: "browseShelf = ").count - 1, 1,
                       "nothing but a tap writes the shelf (one initialiser, no assignment)")
    }

    // MARK: 4 — counterweight: a card that leaves cleans up

    func testACardThatLeavesCleansUp() throws {
        for (path, needles) in [
            ("Sources/Echoelmusic/Studio/PhotoSeedCard.swift", ["loadTask?.cancel()", "MediaLookUndo.shared.showPhoto(nil)"]),
            ("Sources/Echoelmusic/Studio/VideoSeedCard.swift", ["loadTask?.cancel()", "soundTask?.cancel()", "MediaLookUndo.shared.showVideo(nil)"]),
            ("Sources/Echoelmusic/Studio/MediaBrowserView.swift", ["stopPreview()"]),
        ] {
            let leaf = try source(path)
            let leave = try member(".onDisappear {", in: leaf)
            for needle in needles {
                XCTAssertTrue(leave.contains(needle), "`\(path)` no longer runs `\(needle)` when it leaves — a shelf switch would leave it running")
            }
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(reason: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(reason: head)
    }
}
#endif
