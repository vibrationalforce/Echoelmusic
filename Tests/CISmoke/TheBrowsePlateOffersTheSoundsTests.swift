// TheBrowsePlateOffersTheSoundsTests.swift
// Echoel — DAW shell S6 (plan `scratchpads/PLAN_DAW_SHELL_2026-10-02.md`). The Browse plate
// lists the stored sounds (`SoundBrowserView`), and one tap gives the open synth track a sound —
// through the Device page's own seam, never a second sound logic (#416).
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR. The browser's target is the open track exactly when the Device page
//    would show that track's Sound row (`TrackMix.controls(…).sound`): a poly rack track yes; the
//    Echoel track, the sub-bass, the body voice, a bio curve, an audio track, a voiceless track,
//    no selection and a removed track no.
// 2. SOURCE-TEXT SCAN. The tap writes through `TrackMix.setSound` inside
//    `timeline.editLanePatch(id:)` (ONE Undo step), never the store's writer directly; store
//    order (the Device hint's "first of the Sounds"); a 44-pt row that is disabled without a target;
//    a header; no presentation modifier and no hot read.
// 3. SOURCE-TEXT SCAN. Mounted once, on the Browse plate.
// 4. The new words are catalogued in the app's one language, and the Browse door's hint names
//    the sounds (the renamed key is gone, so `StringCatalogIsHonestTests` has no orphan).
//
// GRADING (§3). Against the parent this file does NOT COMPILE — `SoundBrowserView` is new — so
// no assertion has a verdict there: ONE absence (#486). Claims 1–4 are FORWARD guards.
// COUNTERWEIGHTS (#343): claim 1's rows for the Echoel track, sub-bass, body voice, bio, audio and
// voiceless track restate `TheTrackChoosesItsSoundTests` claim 1 through the browser's own rule,
// and claim 2's "the census still finds the wrap" premise is `TheSoundChoiceIsOneUndoStepTests`
// claim 6, which this new caller must satisfy (its regex accepts `editLanePatch(id: target) {`).
// STRIPPER: `SourceText.codeOnly` — TRAGEND, measured: 2 of claim 2's verdicts flip on raw text
// (the one-write count reads 2, because the header quotes the call, and the `sortedPatches`
// absence fails, because the header names it); every other needle reads the same both ways.
//
// ⛔ HONEST LIMITS. Nothing here renders a view or plays a sound. Whether the list reads well on
// 375 pt, and whether the picked sound is heard on the track, is a DEVICE PROBE.
// NEEDS-FOUNDER-VERIFY: Arrange → Add MIDI Track → select it → Browse → Sounds: tap Bright Lead
// → the row shows a check; Arrange → Device page → Sound reads Bright Lead; Undo in the head →
// back to Default. With the Echoel track selected, every row is dimmed and the caption says to
// open a synth track.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheBrowsePlateOffersTheSoundsTests: XCTestCase {

    private static let browserPath = "Sources/Echoelmusic/Studio/SoundBrowserView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let stagePath = "Sources/Echoelmusic/Studio/StudioStage.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let browseHint = "The sounds, the media library and the photo and video that shape the visual."
    private static let retiredBrowseHint = "The media library and the photo and video that shape the visual."
    private static let newKeys = [
        "Tap a sound to give it to the open track: ",
        "Open a synth track in Arrange to give it one of these sounds.",
        "Gives the open synth track this sound. One Undo step",
        browseHint,
    ]

    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let lead = TimelineLane(name: "Lead", kind: .midi)
    private static let sub = TimelineLane(name: "Sub", kind: .midi, builtinInstrument: .subBass)
    private static let bodyVoice = TimelineLane(name: "Body voice", kind: .midi, builtinInstrument: .bioVoice)
    private static let curve = TimelineLane(name: "Curve", kind: .midi, isBio: true)
    private static let loop = TimelineLane(name: "Loop", kind: .audio)

    // MARK: 1 — the target is the Sound row's rule

    func testTheTargetIsTheOpenTrackWhoseVoiceTakesASound() throws {
        let lanes = [Self.keys, Self.lead, Self.sub, Self.bodyVoice, Self.curve, Self.loop]
        let document = TimelineDocument(lanes: lanes, regions: [])
        XCTAssertEqual(document.rollLaneID, Self.keys.id, "ANCHOR: the first non-bio MIDI lane is the Echoel track")

        XCTAssertEqual(SoundBrowserView.target(Self.lead.id, in: document, voiceCapacity: 4), Self.lead.id,
                       "a poly rack track takes a sound from the browser")
        XCTAssertNil(SoundBrowserView.target(Self.keys.id, in: document, voiceCapacity: 4),
                     "never the Echoel track — it keeps its sound on the Sound panel")
        XCTAssertNil(SoundBrowserView.target(Self.sub.id, in: document, voiceCapacity: 4), "the sub-bass takes no patch")
        XCTAssertNil(SoundBrowserView.target(Self.bodyVoice.id, in: document, voiceCapacity: 4), "the body voice takes no patch")
        XCTAssertNil(SoundBrowserView.target(Self.curve.id, in: document, voiceCapacity: 4), "a bio curve makes no sound")
        XCTAssertNil(SoundBrowserView.target(Self.loop.id, in: document, voiceCapacity: 4), "an audio track plays its file")
        XCTAssertNil(SoundBrowserView.target(Self.lead.id, in: document, voiceCapacity: 0),
                     "a track with no rack voice plays nothing")
        XCTAssertNil(SoundBrowserView.target(nil, in: document, voiceCapacity: 4), "no open track, no target")
        XCTAssertNil(SoundBrowserView.target(UUID(), in: document, voiceCapacity: 4), "a removed track is no target")

        // One rule (#416): wherever the Device page shows the Sound row, the browser targets that
        // track, and nowhere else.
        for lane in lanes {
            for capacity in [0, 1, 4] {
                let row = TrackMix.controls(of: lane.id, in: document, voiceCapacity: capacity)?.sound == true
                let browser = SoundBrowserView.target(lane.id, in: document, voiceCapacity: capacity) == lane.id
                XCTAssertEqual(row, browser, "\(lane.name) at capacity \(capacity): the browser and the Sound row disagree")
            }
        }
    }

    // MARK: 2 — the tap is the Sound row's write

    func testTheTapWritesThroughTheSoundRowsSeam() throws {
        let code = try source(Self.browserPath)
        XCTAssertEqual(code.components(separatedBy: "TrackMix.setSound(").count - 1, 1, "one write")
        XCTAssertTrue(code.contains("timeline.editLanePatch(id: target) {"),
                      "the pick runs inside the person's step — ONE Undo step (B2b)")
        let step = try member("timeline.editLanePatch(id: target) {", in: code)
        XCTAssertTrue(step.contains("TrackMix.setSound(.library(patch.id), laneID: target,"),
                      "the write inside the step is the funnel, with the tapped sound")
        XCTAssertFalse(code.contains(".setLanePatch("), "only `TrackMix.setSound` calls the store's sound writer")
        XCTAssertFalse(code.contains("markUsed("), "a tap records no use — the Sound panel ranks by use")
        XCTAssertTrue(code.contains("ForEach(patchStore.patches)"),
                      "store order — the Device hint's \"first of the Sounds\" is the same sound on both plates")
        XCTAssertFalse(code.contains("sortedPatches"), "a favorite is starred, not moved")
        XCTAssertTrue(code.contains("Self.target(selection.trackID, in: timeline.document,"),
                      "the body asks the one rule claim 1 drives")

        let row = try member("private func row(_ patch: SynthPatch, target: UUID?) -> some View {", in: code)
        XCTAssertTrue(row.contains("minHeight: 44"), "a 44-pt target")
        XCTAssertTrue(row.contains(".contentShape(Rectangle())"), "the whole row is the target")
        XCTAssertTrue(row.contains(".disabled(target == nil)"), "no pick without a track that takes one")
        XCTAssertTrue(row.contains(".accessibilityAddTraits(chosen ? .isSelected : [])"),
                      "the track's sound is said, not only drawn")
        XCTAssertTrue(code.contains(".accessibilityAddTraits(.isHeader)"), "the section is a heading")

        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(code.contains(modal), "the rows act in place, never through a modal (black-screen law)")
        }
        for hot in ["masterLevel", "masterVolume", "cameraRPPG", "transport.", "metronome.", "bus.", "playhead"] {
            XCTAssertFalse(code.contains(hot), "`\(hot)` is hot state — the browser reads only cold values")
        }
        let playerReads = code.components(separatedBy: "player.").count - 1
        XCTAssertEqual(playerReads, code.components(separatedBy: "player.laneVoiceCapacity").count - 1,
                       "the player is read for its voice capacity only — a cold number set once at start")
        XCTAssertGreaterThan(playerReads, 0, "ANCHOR: the capacity read")
    }

    // MARK: 3 — mounted once, on the Browse plate

    func testTheBrowserIsMountedOnceOnTheBrowsePlate() throws {
        let workstation = try source(Self.workstationPath)
        let plate = try member("private var browsePlate: some View {", in: workstation)
        XCTAssertTrue(plate.contains("SoundBrowserView()"), "the switcher's Browse has the sounds")
        XCTAssertTrue(plate.contains("MediaBrowserView()"), "counterweight: the media library is still there")

        let root = repoURL("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/Echoelmusic (#454)")
            throw AnchorMissing()
        }
        var mounts = 0
        var files = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            files += 1
            let text = SourceText.codeOnly((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            mounts += text.components(separatedBy: "SoundBrowserView()").count - 1
        }
        XCTAssertGreaterThan(files, 100, "ANCHOR: the walk saw the source tree")
        XCTAssertEqual(mounts, 1, "one door to the sounds' browser (one door per area)")
    }

    // MARK: 4 — the words are catalogued

    func testTheNewWordsAreInTheCatalog() throws {
        let data = try Data(contentsOf: repoURL(Self.catalogPath))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: the catalog's `strings` table (#454)")
            throw AnchorMissing()
        }
        func english(_ key: String) -> String? {
            guard let entry = strings[key] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  Set(localizations.keys) == ["en"],
                  let en = localizations["en"] as? [String: Any],
                  let unit = en["stringUnit"] as? [String: Any],
                  unit["state"] as? String == "translated" else { return nil }
            return unit["value"] as? String
        }
        for key in Self.newKeys {
            XCTAssertEqual(english(key), key, "`\(key)` is an English-only catalog key whose value is the key")
        }
        XCTAssertEqual(english("Sounds"), "Sounds", "the heading reuses the Device menu's own section word")
        XCTAssertNil(strings[Self.retiredBrowseHint], "the renamed hint's old key is gone — no orphan")

        let raw = try String(contentsOf: repoURL(Self.stagePath), encoding: .utf8)
        XCTAssertTrue(raw.contains("String(localized: \"\(Self.browseHint)\")"),
                      "the Browse door names the sounds it now reaches (#482: a door names what it reaches)")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor` (§2, #408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }

    private func repoURL(_ relativePath: String) -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relativePath)
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoURL(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
