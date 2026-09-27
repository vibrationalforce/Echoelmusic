// APhotoIsReadSmallAndOffTheStageTests.swift
// MS3 (founder order 2026-09-27): the door — "Photo to Visuals" on the Workstation plate — and the
// ImageIO step behind it.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END: claim 1 writes real PNG files with ImageIO and decodes them
//     through the shipped `PhotoSeedDecoder`; claim 2 drives the card's pure wording.
//   · Claims 3–4 are SOURCE-TEXT SCANS: the card is a SwiftUI `View` no test can render.
//   · DEVICE PROBE, open: the system photo picker opens from the button, a picked photo shows,
//     Apply changes the floating visual, Undo brings it back, VoiceOver reads every step, and
//     nothing is truncated at the largest text size. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (92a9dfd2e, §3): the file does not COMPILE there — it names
// `PhotoSeedDecoder` and `PhotoSeedText`, which this commit creates — so no assertion has a
// verdict on the parent. Claims 1–4 are FORWARD guards (one absence, #486); claim 4's premise that
// the Workstation still owns exactly one file importer and no sheet is a COUNTERWEIGHT, green on
// both trees. Hand-transcribed in Python for claims 2–4; claim 1 needs ImageIO and is graded by
// the gate alone. Mutants driven: the card presenting a `.sheet`, the decode moved out of the
// detached task, the temp copy never removed, the full-size decode `CGImageSourceCreateImageAtIndex`,
// a second mount — each red for its named reason.

import Foundation
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Echoelmusic

final class APhotoIsReadSmallAndOffTheStageTests: XCTestCase {

    // MARK: fixtures

    private func writePNG(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> URL {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-seed-test-\(UUID().uuidString).png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
                                                                        UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "the fixture PNG was written")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    // MARK: 1 — a real file, decoded small, gives the right seed; a broken one gives none

    func testALargePhotoIsDecodedToBoundedThumbnails() throws {
        let url = try writePNG(width: 1600, height: 900, red: 1, green: 0, blue: 0)
        let decoded = try XCTUnwrap(PhotoSeedDecoder.decode(url: url))
        XCTAssertLessThanOrEqual(max(decoded.preview.width, decoded.preview.height), PhotoSeedDecoder.previewSide,
                                 "the preview is a thumbnail, never the full picture")
        XCTAssertLessThanOrEqual(decoded.seed.sampledPixels,
                                 MediaSeedAnalysis.maxAnalysisSide * MediaSeedAnalysis.maxAnalysisSide,
                                 "the numbers come from the small thumbnail — the work is bounded")
        XCTAssertGreaterThan(decoded.seed.sampledPixels, 0)
        XCTAssertTrue(decoded.seed.hasDominantColour)
        // Hue is a TURN: red sits on the wrap, so one stray unit of blue from colour matching reads
        // 0.999…, which is 0.02° from red. The distance is measured around the circle (review MED).
        let turn = decoded.seed.hue
        XCTAssertLessThan(Swift.min(turn, 1 - turn), 0.01, "a red picture reads as red — got \(turn)")
        XCTAssertEqual(decoded.seed.contrast, 0, accuracy: 0.01, "a flat picture has no contrast")
    }

    func testTheSameFileGivesTheSameSeed() throws {
        let url = try writePNG(width: 300, height: 200, red: 0.2, green: 0.4, blue: 0.9)
        let first = try XCTUnwrap(PhotoSeedDecoder.decode(url: url))
        let second = try XCTUnwrap(PhotoSeedDecoder.decode(url: url))
        XCTAssertEqual(first.seed, second.seed)
    }

    func testAFileThatIsNoPictureGivesNoSeed() throws {
        let garbage = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-seed-test-\(UUID().uuidString).jpg")
        try Data("this is not a picture".utf8).write(to: garbage)
        addTeardownBlock { try? FileManager.default.removeItem(at: garbage) }
        XCTAssertNil(PhotoSeedDecoder.decode(url: garbage), "unreadable media → no seed, nothing applied")
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("echoel-seed-missing-\(UUID().uuidString).png")
        XCTAssertNil(PhotoSeedDecoder.decode(url: missing))
    }

    // MARK: 2 — the words are plain, and a colour always has words beside it

    func testTheCardSpeaksPlainly() {
        func seed(hue: Double, coloured: Bool) -> MediaSeed {
            MediaSeed(version: MediaSeed.formatVersion, hue: hue, dominantRed: 0, dominantGreen: 0, dominantBlue: 0,
                      brightness: 0.5, saturation: 0.5, contrast: 0.5, hasDominantColour: coloured, sampledPixels: 1)
        }
        XCTAssertEqual(PhotoSeedText.colour(seed(hue: 0.5, coloured: false)), "No main colour")
        XCTAssertEqual(PhotoSeedText.colour(seed(hue: 0, coloured: true)), "Main colour: hue 0°")
        XCTAssertEqual(PhotoSeedText.colour(seed(hue: 0.5, coloured: true)), "Main colour: hue 180°")
        XCTAssertEqual(PhotoSeedText.colour(seed(hue: 0.9999, coloured: true)), "Main colour: hue 0°",
                       "a full turn is 0°, never 360°")
        XCTAssertEqual(PhotoSeedText.percent(0.456), "46 %")
        XCTAssertEqual(PhotoSeedText.percent(.nan), "0 %")
        XCTAssertEqual(PhotoSeedText.percent(3), "100 %")
        XCTAssertTrue(PhotoSeedText.change("Detail", 40, 40).hasSuffix("unchanged"),
                      "an unchanged value says so instead of showing an arrow to itself")
        XCTAssertTrue(PhotoSeedText.change("Detail", 40, 58).contains("→"))
        XCTAssertFalse(PhotoSeedText.unreadable.contains("error"), "an everyday sentence, not an error code")

        let before = VisualLookSnapshot(intensity: 1, detail: 40, motion: 1, spread: 1, hue: 0, saturation: 1.05,
                                        presetID: "vapor")
        let lines = PhotoSeedText.changes(from: before, to: before.applying(seed(hue: 0.5, coloured: true)))
        XCTAssertEqual(lines.count, 4)
        for name in ["Intensity", "Detail", "Colour turn", "Saturation"] {
            XCTAssertEqual(lines.filter { $0.hasPrefix(name + " ") }.count, 1, "one line names `\(name)`")
        }
    }

    // MARK: 3 — the card is a leaf: no modal, work off the main actor, nothing hot, labels on every action

    func testTheCardAddsNoModalAndReadsInTheBackground() throws {
        let card = try code("Sources/Echoelmusic/Studio/PhotoSeedCard.swift")
        for modal in [".sheet(", ".fullScreenCover(", ".fileImporter(", ".alert(", ".popover("] {
            XCTAssertFalse(card.contains(modal), "the card presents `\(modal)` — the system picker is its only presentation")
        }
        XCTAssertEqual(card.components(separatedBy: "PhotosPicker(").count - 1, 1)
        XCTAssertTrue(card.contains("Task.detached(priority: .userInitiated)"), "the decode runs off the main actor")
        XCTAssertTrue(card.contains("PhotoSeedDecoder.decode(url: url)"))
        XCTAssertTrue(card.contains("FileManager.default.removeItem(at: url)"), "the temporary copy is removed")
        XCTAssertTrue(card.contains("guard !Task.isCancelled else { return }"),
                      "a newer pick discards an older pick's result")
        for hot in ["masterLevel", "currentTick", "latestBio", "cameraRPPG", "metronome."] {
            XCTAssertFalse(card.contains(hot), "the card reads the hot value `\(hot)`")
        }
        for raw in ["Slider(", "Stepper("] { XCTAssertFalse(card.contains(raw)) }
        let buttons = card.components(separatedBy: "Button {").count - 1
        XCTAssertGreaterThanOrEqual(buttons, 3)
        XCTAssertGreaterThanOrEqual(card.components(separatedBy: ".accessibilityLabel(").count - 1, buttons + 1,
                                    "every action — the picker included — carries a spoken name")
        XCTAssertTrue(card.contains(".frame(minWidth: 92, minHeight: 44)"), "44 pt targets")

        let decoder = try code("Sources/Echoelmusic/Studio/PhotoSeedDecoder.swift")
        XCTAssertTrue(decoder.contains("kCGImageSourceThumbnailMaxPixelSize"))
        XCTAssertTrue(decoder.contains("thumbnail(of: source, maxSide: MediaSeedAnalysis.maxAnalysisSide)"),
                      "the analysis size is the core's own limit (#416)")
        XCTAssertFalse(decoder.contains("CGImageSourceCreateImageAtIndex"),
                       "a full-resolution decode would hold a 48-megapixel photo in memory")
    }

    // MARK: 4 — mounted once, on the Workstation plate, which owns none of its state

    func testTheWorkstationMountsTheCardOnce() throws {
        let workstation = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "PhotoSeedCard()").count - 1, 1)
        for owned in ["PhotosPicker", "MediaSeedApplication", "VisualLookSnapshot"] {
            XCTAssertFalse(workstation.contains(owned), "the Workstation reaches into the card's `\(owned)`")
        }
        XCTAssertEqual(workstation.components(separatedBy: ".fileImporter(").count - 1, 1,
                       "still exactly one file importer on the plate (#W1)")
        XCTAssertEqual(workstation.components(separatedBy: ".sheet(").count - 1, 0)
    }
}
