// TheTrackChoosesItsSoundTests.swift
// Echoel — Workstation redesign B2a (plan `scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md`,
// "Presets je Spur"). A track's own timbre (`TimelineLane.patch`) was read by the player on every
// part load (`MultiRollFanout.patch(forSlot:)` → `slotPatchSink` → `LaneVoiceRack.applyPatch`),
// and its one writer (`TimelineStore.setLanePatch`) had NO production caller — the engine half
// was done and doorless. The track inspector's Device page now offers the choice on a POLY rack
// track.
//
// WHAT IT PINS.
// 1. The rule: the Sound row exists only on a poly rack track — never on the Echoel track (its
//    patch sink swaps the instrument's own voice), a sub, body-voice, bio, audio, visual or
//    voiceless track (a lane patch moves nothing there).
// 2. The choice: no patch is Default; a stored sound is named by its id; a copy no stored sound
//    equals — from elsewhere, or edited since — is the piece's KEPT copy.
// 3. On a real `TimelineStore`: a pick lands on the lane as a copy, the player's own slot rule
//    reads it, Default clears it; a re-pick, the kept copy or an unknown id write nothing.
// 4. COUNTERWEIGHTS (#343), no new symbol: the sinks play what the row promises (nil → the first
//    stored sound; `applyPatch` reaches the poly voice; the roll lane's sink is the instrument's
//    voice), and a factory sound survives the song's save unchanged — the premise `.kept` stands
//    on (`SynthPatch.init(from:)` ends in `clampToBounds()`).
// 5. Source: one write through `TrackMix.setSound`; a menu Picker with the hint, a 44-pt target,
//    mounted once under `if controls.sound {`; the hint is the catalog key.
// 6. The new words are in the catalog (with German until 2026-10-02; English-only since).
//
// GRADING (§3). Against the parent this file does NOT COMPILE — `TrackMix.SoundChoice`,
// `keptSound`, `soundChoice`, `setSound`, `soundHint` and `Controls.sound` are new — so no
// assertion has a verdict there: ONE absence (#486). Claims 1, 2, 3a, 3b, 5 and 6 are FORWARD
// guards. Claims 4a and 4b name no new symbol and are COUNTERWEIGHTS, green in intent on both
// trees: every needle in 4a was grepped on d05aa750f; 4b is UNMEASURED (no toolchain) — a red
// there is a real finding against the kept-copy rule, not against this file. §0 transcription
// of the whole file against the worktree is OWED by the implementing session.
//
// ⛔ HONEST LIMITS. Since B2b a pick is ONE Undo step (`.lanePatch`, `TheSoundChoiceIsOneUndoStepTests`), so a
// pick that replaces a kept copy loses it only past the history's reach (an Open, a relaunch, 50
// later steps). Default is the first stored sound, captured at launch, not the Echoel's
// live sound. The Echoel track keeps its sound on the Sound panel. Sound names are user data and
// are not translated. A pick while playing releases EVERY rack lane's held notes once
// (`refreshStructure` → `flushPumps`). Whether the chosen sound SOUNDS right is a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → Add MIDI Track → select it → Device → Sound: Bright Lead →
// New MIDI Part, write notes, Play → the second track plays Bright Lead while the Echoel keeps
// its own sound; Sound: Default → Warm Pad; change it while playing → held notes on every extra
// track stop once.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTrackChoosesItsSoundTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let appPath = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let rackPath = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"
    private static let patchStorePath = "Sources/Echoelmusic/Core/PatchStore.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    /// The hint's catalog KEY, spelled here so the lookup does not depend on the test host's locale.
    private static let hintKey = "The sound EchoelSynth plays this track's parts with. Default plays the first of the Sounds. The piece keeps its own copy of the chosen sound"

    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let lead = TimelineLane(name: "Lead", kind: .midi)
    private static let sub = TimelineLane(name: "Sub", kind: .midi, builtinInstrument: .subBass)
    private static let bodyVoice = TimelineLane(name: "Body voice", kind: .midi, builtinInstrument: .bioVoice)
    private static let curve = TimelineLane(name: "Curve", kind: .midi, isBio: true)
    private static let loop = TimelineLane(name: "Loop", kind: .audio)
    private static let look = TimelineLane(name: "Look", kind: .visual)

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    private func factoryLibrary() throws -> [SynthPatch] {
        let sounds = SynthPatch.factory
        guard sounds.count >= 2 else {
            XCTFail("ANCHOR MISSING: the factory sounds need two entries for this file (#454)")
            throw AnchorMissing()
        }
        return sounds
    }

    // MARK: 1 — the rule

    func testOnlyAPolyRackTrackOffersASound() throws {
        let lanes = [Self.keys, Self.lead, Self.sub, Self.bodyVoice, Self.curve, Self.loop, Self.look]
        let document = TimelineDocument(lanes: lanes, regions: [])
        XCTAssertEqual(document.rollLaneID, Self.keys.id, "ANCHOR: the first non-bio MIDI lane is the Echoel track")
        func sound(_ lane: TimelineLane, _ capacity: Int) -> Bool? {
            TrackMix.controls(of: lane.id, in: document, voiceCapacity: capacity)?.sound
        }
        XCTAssertEqual(sound(Self.lead, 4), true, "a poly rack track chooses its sound")
        // Counterweights (#343): nowhere else.
        XCTAssertEqual(sound(Self.keys, 4), false, "never the Echoel track — its patch sink swaps the instrument's voice")
        XCTAssertEqual(sound(Self.sub, 4), false, "the sub-bass takes no patch")
        XCTAssertEqual(sound(Self.bodyVoice, 4), false, "the body voice takes no patch")
        XCTAssertEqual(sound(Self.lead, 0), false, "a track with no rack voice plays nothing")
        XCTAssertEqual(sound(Self.curve, 4), false, "a bio curve makes no sound")
        XCTAssertEqual(sound(Self.loop, 4), false, "an audio track plays its file")
        XCTAssertEqual(sound(Self.look, 4), false, "a visual track plays nothing")
    }

    // MARK: 2 — the choice

    func testTheChoiceIsDefaultAStoredSoundOrThePiecesCopy() throws {
        let sounds = try factoryLibrary()
        let picked = sounds[1]
        var edited = sounds[1]
        edited.brightness = edited.brightness > 0.5 ? 0.1 : 0.9
        let foreign = SynthPatch(name: "From another install", brightness: 0.77)
        let lanes = [Self.keys,
                     TimelineLane(name: "A", kind: .midi),
                     TimelineLane(name: "B", kind: .midi, patch: picked),
                     TimelineLane(name: "C", kind: .midi, patch: foreign),
                     TimelineLane(name: "D", kind: .midi, patch: edited)]
        let document = TimelineDocument(lanes: lanes, regions: [])
        XCTAssertEqual(TrackMix.soundChoice(of: lanes[1].id, in: document, library: sounds), .standard,
                       "no lane patch is Default")
        XCTAssertNil(TrackMix.keptSound(of: lanes[1].id, in: document, library: sounds))
        XCTAssertEqual(TrackMix.soundChoice(of: lanes[2].id, in: document, library: sounds), .library(picked.id))
        XCTAssertNil(TrackMix.keptSound(of: lanes[2].id, in: document, library: sounds),
                     "a sound the store holds is not a kept copy")
        XCTAssertEqual(TrackMix.soundChoice(of: lanes[3].id, in: document, library: sounds), .kept)
        XCTAssertEqual(TrackMix.keptSound(of: lanes[3].id, in: document, library: sounds), foreign,
                       "a sound from elsewhere is shown, not hidden behind Default")
        XCTAssertEqual(TrackMix.soundChoice(of: lanes[4].id, in: document, library: sounds), .kept,
                       "the same id with other values is the piece's copy, not the stored sound")
    }

    // MARK: 3 — on the real store, read by the player's own slot rule

    func testTheChoiceReachesThePlayersPatchRule() throws {
        let sounds = try factoryLibrary()
        let timeline = TimelineStore()
        let originalDocument = timeline.document
        restore.append { timeline.replaceDocument(originalDocument) }
        timeline.replaceDocument(TimelineDocument(lanes: [Self.keys, Self.lead], regions: []))
        let rollLane = timeline.document.rollLaneID
        guard let slot = MultiRollFanout.slot(forLaneID: Self.lead.id, in: timeline.document,
                                              rollLane: rollLane, capacity: 4) else {
            XCTFail("ANCHOR MISSING: the second MIDI track has no rack slot at capacity 4 (#454)")
            throw AnchorMissing()
        }
        XCTAssertNil(MultiRollFanout.patch(forSlot: slot, in: timeline.document, rollLane: rollLane))

        TrackMix.setSound(.library(sounds[1].id), laneID: Self.lead.id, library: sounds, timeline: timeline)
        XCTAssertEqual(timeline.document.lanes.first { $0.id == Self.lead.id }?.patch, sounds[1],
                       "the lane carries a copy of the chosen sound")
        XCTAssertEqual(MultiRollFanout.patch(forSlot: slot, in: timeline.document, rollLane: rollLane), sounds[1],
                       "the slot the player loads applies it")

        TrackMix.setSound(.standard, laneID: Self.lead.id, library: sounds, timeline: timeline)
        XCTAssertNil(timeline.document.lanes.first { $0.id == Self.lead.id }?.patch, "Default clears the lane patch")
        XCTAssertNil(timeline.document.lanes.first { $0.id == Self.keys.id }?.patch,
                     "counterweight: the Echoel track is untouched")
    }

    func testAPickThatChangesNothingWritesNothing() throws {
        let sounds = try factoryLibrary()
        let foreign = SynthPatch(name: "From another install", brightness: 0.77)
        let kept = TimelineLane(name: "Kept", kind: .midi, patch: foreign)
        let timeline = TimelineStore()
        let originalDocument = timeline.document
        restore.append { timeline.replaceDocument(originalDocument) }
        timeline.replaceDocument(TimelineDocument(lanes: [Self.keys, Self.lead, kept], regions: []))
        let before = timeline.document

        TrackMix.setSound(.kept, laneID: kept.id, library: sounds, timeline: timeline)
        XCTAssertEqual(timeline.document, before, "the kept copy is shown, and picking it writes nothing")
        TrackMix.setSound(.library(UUID()), laneID: kept.id, library: sounds, timeline: timeline)
        XCTAssertEqual(timeline.document, before, "an id the store does not hold writes nothing")
        TrackMix.setSound(.standard, laneID: Self.lead.id, library: sounds, timeline: timeline)
        XCTAssertEqual(timeline.document, before, "Default on a track already at Default writes nothing")

        TrackMix.setSound(.library(sounds[1].id), laneID: Self.lead.id, library: sounds, timeline: timeline)
        let picked = timeline.document
        XCTAssertNotEqual(picked, before, "counterweight: a real change still writes")
        TrackMix.setSound(.library(sounds[1].id), laneID: Self.lead.id, library: sounds, timeline: timeline)
        XCTAssertEqual(timeline.document, picked, "a re-pick of what already plays writes nothing")
    }

    // MARK: 4a — the sinks play what the row promises (COUNTERWEIGHT, no new symbol)

    func testTheSinksPlayWhatTheRowPromises() throws {
        let app = try source(Self.appPath)
        XCTAssertEqual(app.components(separatedBy: "let fallbackPatch = patchStore.patches.first").count - 1, 1,
                       "Default plays the first stored sound — reword `TrackMix.soundHint` if this moves")
        XCTAssertEqual(app.components(separatedBy:
            "if let resolved = patch ?? fallbackPatch { laneVoiceRack?.applyPatch(slot: slot, resolved) }").count - 1, 1,
                       "a nil lane patch resolves to that fallback at the slot sink")
        XCTAssertTrue(app.contains("timelinePlayer.rollPatchSink = { [weak polyVoice] patch in"),
                      "the roll lane's patch reaches the instrument's own voice — why the Echoel track has no row")
        let store = try source(Self.patchStorePath)
        XCTAssertTrue(store.contains("self.patches = SynthPatch.factory + cleanedUser"),
                      "the store lists factory sounds first, so the first of the Sounds is fixed")
        let rack = try source(Self.rackPath)
        let apply = try member("public func applyPatch(slot: Int, _ patch: SynthPatch) {", in: rack)
        XCTAssertTrue(apply.contains("voice(slot: slot)?.apply(patch)"),
                      "a lane patch reaches the slot's POLY voice — the reason the row is poly-only")
    }

    // MARK: 4b — a factory sound survives the song's save (COUNTERWEIGHT — the premise of `.kept`)

    func testAFactorySoundSurvivesTheSongsSaveUnchanged() throws {
        for sound in try factoryLibrary() {
            let lane = TimelineLane(name: "T", kind: .midi, patch: sound)
            let document = TimelineDocument(lanes: [Self.keys, lane], regions: [])
            let data = try JSONEncoder().encode(document)
            let back = try JSONDecoder().decode(TimelineDocument.self, from: data)
            XCTAssertEqual(back.lanes.first { $0.id == lane.id }?.patch, sound, """
                factory “\(sound.name)” does not survive the song's save unchanged \
                (`SynthPatch.init(from:)` ends in `clampToBounds()`). Every pick of it would then \
                read as the piece's kept copy after a reopen — compare by something else, or fix \
                the factory value, before trusting `TrackMix.keptSound`.
                """)
        }
    }

    // MARK: 5 — the row

    func testTheRowWritesThroughTheStoreAndIsANamedChoice() throws {
        let code = try source(Self.inspectorPath)
        XCTAssertEqual(code.components(separatedBy: "timeline.setLanePatch(").count - 1, 1,
                       "one write, inside `TrackMix.setSound`")
        XCTAssertTrue(code.contains("@Environment(PatchStore.self) private var patchStore"),
                      "the sounds come from the one owner the root injects")
        XCTAssertTrue(code.contains("String(localized: \"\(Self.hintKey)\")"), "the hint is a catalog key")
        XCTAssertTrue(TrackMix.soundHint.contains("Default plays the first of the Sounds"),
                      "the hint names the menu's own section, not a second word for it")
        XCTAssertFalse(TrackMix.soundHint.lowercased().contains("library"),
                       "\"library\" names the piece Library in this app's chrome — one word per thing")
        let row = try member("private var soundRow: some View {", in: code)
        XCTAssertTrue(row.contains(
            "TrackMix.setSound(choice, laneID: laneID, library: patchStore.patches, timeline: timeline)"),
                      "the pick still writes through the one funnel (since B2b inside `editLanePatch`)")
        XCTAssertTrue(row.contains("Text(\"Default\").tag(TrackMix.SoundChoice.standard)"))
        XCTAssertTrue(row.contains("Section(\"In this piece\")"), "the kept copy is shown, never hidden")
        XCTAssertTrue(row.contains("ForEach(patchStore.patches)"),
                      "store order (factory first) — `sortedPatches` would put a favourite first and the hint would lie")
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a menu Picker, not a number field")
        XCTAssertTrue(row.contains(".accessibilityHint(TrackMix.soundHint)"), "one wording (#416)")
        XCTAssertTrue(row.contains(".frame(minHeight: 44)"), "a 44-pt target")
        XCTAssertFalse(row.contains("EchoelValueField("), "a named choice is not a number field")
        let body = try member("var body: some View {", in: code)
        let gate = try member("if controls.sound {", in: body)
        XCTAssertTrue(gate.contains("soundRow"), "no row where a lane patch moves nothing")
        XCTAssertEqual(code.components(separatedBy: "soundRow").count - 1, 2, "declared once, mounted once")
    }

    // MARK: 6 — the new words are catalogued, in the app's one language (German until 2026-10-02)

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
        XCTAssertEqual(english("In this piece"), "In this piece")
        XCTAssertEqual(english(Self.hintKey).map { $0.contains("Sounds") }, true,
                       "the hint names the same menu section („Sounds“)")
        for reused in ["Sound", "Default", "Sounds"] {
            XCTAssertEqual(english(reused), reused, "`\(reused)` is a reused key and must stay an English-only catalog key")
        }
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
