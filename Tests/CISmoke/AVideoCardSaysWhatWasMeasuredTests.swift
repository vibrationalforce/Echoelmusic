// AVideoCardSaysWhatWasMeasuredTests.swift
// MV2b (founder order 2026-09-27): the video door — "Video to Visuals" on the Workstation plate.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on the card's pure wording (`VideoSeedText`).
//   · Claims 2–3 are SOURCE-TEXT SCANS: the card is a SwiftUI `View` no test can render.
//   · DEVICE PROBE, open: the system picker opens on videos, a picked clip shows a frame and its
//     readouts, Apply visibly changes the floating visual's movement, Undo brings it back, a photo
//     look blocks a video Apply until it is undone, VoiceOver reads every step, and nothing is cut
//     off at the largest text size. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (f2025268b, §3): the file does not COMPILE there — it names
// `VideoSeedText`, which this commit creates — so no assertion has a verdict on the parent. All
// claims are FORWARD guards (one absence, #486). Hand-transcribed in Python; mutants driven, each
// red for its named reason: the tempo read moved into `body` (claim 2), a detached read that a new
// pick cannot cancel (claim 2), the temporary copy never removed (claim 2), a second mount
// (claim 3), a sound claim beyond "not used yet" (claim 1).
//
// E12-1 (founder 2026-10-04) changed claim 1's sound line and claims 2–3's counts ON PURPOSE: the
// founder made video sound musical material, so "not used yet" is no longer the truth to pin. The
// new state words are pinned instead, the action count is 3 → 4 ("Use Its Sound"), and the mount
// passes the Workstation's import (`VideoSeedCard(useSound: useVideoSound)`). What the sound path
// itself must keep — one import door, no picture encoded — is `AVideoGivesItsSoundToTheOneImportDoorTests`.

import Foundation
import XCTest
@testable import Echoelmusic

final class AVideoCardSaysWhatWasMeasuredTests: XCTestCase {

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    private func seed(duration: Double = 8, transients: [Double] = []) -> VideoSeed {
        VideoSeed(version: VideoSeed.formatVersion, durationSeconds: duration, frameRate: 29.97,
                  brightness: 0.5, hue: 0, saturation: 0, hasDominantColour: false,
                  motionEnergy: 0.4, transientTimes: transients, sampledFrames: 32)
    }

    // MARK: 1 — the words are plain and claim nothing that was not measured

    func testTheCardSpeaksPlainly() {
        XCTAssertEqual(VideoSeedText.length(seed()), "Length 8.0 s, 30 fps")
        XCTAssertEqual(VideoSeedText.cuts([]), "No cuts or flashes")
        XCTAssertEqual(VideoSeedText.cuts([2]), "1 cut or flash: 2.0 s")
        XCTAssertEqual(VideoSeedText.cuts([1, 2, 3, 4, 5, 6, 7]),
                       "7 cuts or flashes: 1.0 s, 2.0 s, 3.0 s, 4.0 s, 5.0 s and 2 more",
                       "a long list is cut short and says how much was left out")
        XCTAssertEqual(VideoSeedText.bars(seed(duration: 8), bpm: 120), "About 4 bars of 4/4 at 120 BPM",
                       "8 s at 120 BPM is four 2-second bars, and the text says at which tempo")
        XCTAssertEqual(VideoSeedText.bars(seed(duration: 1), bpm: 120), "About 1 bar of 4/4 at 120 BPM")
        XCTAssertEqual(VideoSeedText.bars(seed(), bpm: .nan), "Length in bars: unknown")
        // E12-1 (founder 2026-10-04: video is musical material): the sound line follows what the
        // card can DO with the sound now. ⛔ It said "The sound is not used yet." while the beat
        // source was not built; that premise is gone with "Use Its Sound", so the words moved.
        XCTAssertEqual(VideoSeedText.sound(.none), "No sound.")
        XCTAssertEqual(VideoSeedText.sound(.usable),
                       "It has sound. Use Its Sound places it as a part on the first audio track.",
                       "the offer names the button and where the sound lands")
        XCTAssertEqual(VideoSeedText.sound(.placed), "Its sound is in the piece and in your library.")
        XCTAssertEqual(VideoSeedText.sound(.released), "It has sound. Choose the video again to use it.",
                       "a card that let the video go says how to get it back, never offers a dead button")
        XCTAssertFalse(VideoSeedText.sound(.usable).lowercased().contains("beat"),
                       "COUNTERWEIGHT: the sound is a part on an audio track, not a beat — nothing slices it")
        XCTAssertTrue(VideoSeedText.unreadable.contains("10 minutes"),
                      "the limit is named from `VideoSeedAnalysis.maxDurationSeconds`, not restated")
        XCTAssertFalse(VideoSeedText.unreadable.lowercased().contains("error"))

        let before = VisualLookSnapshot(intensity: 1, detail: 40, motion: 1, spread: 1, hue: 0, saturation: 1.05,
                                        presetID: "vapor")
        let lines = VideoSeedText.changes(from: before, to: before.applying(seed()))
        XCTAssertEqual(lines.count, 4)
        for name in ["Intensity", "Motion", "Hue", "Saturation"] {
            XCTAssertEqual(lines.filter { $0.hasPrefix(name + " ") }.count, 1, "one line names `\(name)`")
        }
    }

    // MARK: 2 — a leaf: no modal, nothing hot in `body`, a cancellable read, the copy removed

    func testTheCardAddsNoModalAndReadsNothingHot() throws {
        let card = try code("Sources/Echoelmusic/Studio/VideoSeedCard.swift")
        for modal in [".sheet(", ".fullScreenCover(", ".fileImporter(", ".alert(", ".popover("] {
            XCTAssertFalse(card.contains(modal), "the card presents `\(modal)` — the system picker is its only presentation")
        }
        XCTAssertEqual(card.components(separatedBy: "PhotosPicker(").count - 1, 1)
        XCTAssertTrue(card.contains("PhotosPicker(selection: $item, matching: .videos)"))
        XCTAssertEqual(card.components(separatedBy: "pattern.tempo").count - 1, 1, "the tempo is read once")
        let load = try XCTUnwrap(card.range(of: "private func load("), "the load handler")
        let tempo = try XCTUnwrap(card.range(of: "let bpm = beatPlayer.pattern.tempo"))
        XCTAssertGreaterThan(tempo.lowerBound, load.lowerBound,
                             "the ~20 Hz tempo is read in the handler, never in `body` (the menu-freeze law)")
        XCTAssertTrue(card.contains("read = await VideoSeedReader.read(url: file.url)"))
        XCTAssertFalse(card.contains("Task.detached"),
                       "a detached read would not inherit the cancel of a newer pick")
        XCTAssertTrue(card.contains("try? FileManager.default.removeItem(at: file.url)"), "the copy is removed")
        XCTAssertTrue(card.contains("guard !Task.isCancelled else { return }"))
        XCTAssertTrue(card.contains("MediaLookUndo.shared"), "one way back, shared with the photo card")
        for hot in ["masterLevel", "currentTick", "latestBio", "cameraRPPG", "metronome."] {
            XCTAssertFalse(card.contains(hot), "the card reads the hot value `\(hot)`")
        }
        for raw in ["Slider(", "Stepper("] { XCTAssertFalse(card.contains(raw)) }
        let buttons = card.components(separatedBy: "Button {").count - 1
        XCTAssertGreaterThanOrEqual(buttons, 3)
        XCTAssertGreaterThanOrEqual(card.components(separatedBy: ".accessibilityLabel(").count - 1, buttons + 1,
                                    "every action — the picker included — carries a spoken name")
        XCTAssertTrue(card.contains(".frame(minWidth: 92, minHeight: 44)"), "44 pt targets (the header)")
        // Same shared face as the photo card — see APhotoIsReadSmallAndOffTheStageTests claim 3.
        // E12-1: Choose · Apply · Undo · Use Its Sound.
        XCTAssertEqual(card.components(separatedBy: "MediaActionLabel(title:").count - 1, 4)
        XCTAssertFalse(card.contains("func actionLabel("), "the isolated helper is the compile error")
        XCTAssertTrue(try code("Sources/Echoelmusic/Studio/MediaActionLabel.swift")
            .contains(".frame(minWidth: 92, minHeight: 44)"), "44 pt targets (the actions)")
    }

    // MARK: 3 — mounted once, beside the photo card, on a plate that still owns no modal

    func testTheWorkstationMountsTheVideoCardOnce() throws {
        let workstation = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "VideoSeedCard(useSound: useVideoSound)").count - 1, 1)
        XCTAssertEqual(workstation.components(separatedBy: "VideoSeedCard(").count - 1, 1, "one mount")
        XCTAssertEqual(workstation.components(separatedBy: "PhotoSeedCard()").count - 1, 1)
        for owned in ["PhotosPicker", "MediaLookUndo", "VideoSeedReader"] {
            XCTAssertFalse(workstation.contains(owned), "the Workstation reaches into the card's `\(owned)`")
        }
        XCTAssertEqual(workstation.components(separatedBy: ".fileImporter(").count - 1, 1)
        XCTAssertEqual(workstation.components(separatedBy: ".sheet(").count - 1, 0)
    }
}
