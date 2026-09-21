// TheProjectEnvelopeImportsWithoutRestructuringTests.swift
// Echoel — #1419. ONE envelope over the five SONG roots, and an importer that only READS.
//
// WHAT THIS PINS. `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md` measured TWELVE persisted
// roots: five describe the PIECE, seven describe the APP (the user's patch library, their FX
// and mood presets, the modulation matrix, the signal routes, the track FX, the bio log).
// `DMMWProject` carries the five. An envelope that swallowed the library would turn "open a
// project" into "replace the app's state" — the user would lose their own presets because they
// loaded somebody else's piece. Claim 6 is that line, made executable.
//
// ⚠️ THE RISK THIS SLICE ACTUALLY CARRIES, and why claim 7 exists. Nothing writes this type.
// The old files stay the truth on disk, so a wrong import costs a corrected function and not a
// user's piece. The moment a writer lands, claim 7 is the claim to REPLACE in the same commit —
// it is a statement about today, not a prohibition (#364).
//
// ⭐ WRITING THE CODE CORRECTED THE DESIGN TWICE, and both corrections are pinned here rather
// than only apologised for in prose:
// · The design said `Project.notes` would be "lifted into a region" at import. It cannot be, in
//   one step: a `TimelineRegion` carries a `clipID` and the notes live in `Clip.melody`, so
//   lifting means MINTING a clip — restructuring, which an importer must not do, because a
//   restructuring import can only be checked against "did it guess the way I would have",
//   never against "did it lose anything". Claim 2 checks the second question, which is the
//   only one an importer owes an answer to.
// · The design said automation has TWO homes. It has THREE — `AutomationState.lanes`,
//   `TimelineDocument.automation` and `Clip.automation`. The third is a different SCOPE
//   (clip-relative, not song-absolute) and is deliberately NOT folded; claim 3 pins the rule
//   for the two that genuinely duplicate.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–5 are end-to-end behaviour over
// the real types and were transcribed into Python and driven against a hand-model of the
// importer; claims 6–8 are source-text scans and were driven directly against this tree. RED on
// `b67688c72` by ABSENCE — both subject files are new there, so the bundle does not build at
// all. NOT compile-verified: a transcription does not run Swift's type checker.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheProjectEnvelopeImportsWithoutRestructuringTests: XCTestCase {

    private static let envelopePath = "Sources/Echoelmusic/Core/DMMWProject.swift"
    private static let importerPath = "Sources/Echoelmusic/Core/DMMWProjectImport.swift"
    private static let projectPath  = "Sources/Echoelmusic/Core/Project.swift"

    // MARK: Reading

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath). A guard that cannot find its "
                    + "subject is not a pass — re-anchor it rather than letting it stay green "
                    + "(#454).")
            return ""
        }
        return text
    }

    /// Comment-stripped, because every claim below asks about CODE. A prose mention that
    /// satisfies a presence check is a false green, and a prose mention that trips an absence
    /// check is a false red — both are the #1376 defect, and both are avoided the same way.
    private func code(_ relativePath: String) -> String {
        source(relativePath)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: Fixtures

    private func note(_ pitch: Int, _ step: Int) -> Note {
        Note(pitch: pitch, startStep: step, lengthSteps: 2, velocity: 0.7, role: .lead)
    }

    private func lane(_ parameter: String, _ value: Double) -> AutomationLane {
        AutomationLane(parameter: parameter,
                       points: [AutomationPoint(tick: 0, value: value)])
    }

    /// Distinctive in EVERY field, so claim 2 fails on a dropped one rather than matching a
    /// default that happens to agree.
    private func fixtureProject() -> Project {
        Project(name: "Harbour Take",
                styleRaw: "dubTechno",
                keyRoot: 7,
                scaleRaw: "dorian",
                bpm: 97.5,
                modeRaw: "flowFree",
                fxCharacterRaw: "warm",
                loopBars: 8,
                a4Hz: 432,
                toneSystemID: "just-intonation",
                moodFields: ["weird": 0.25],
                artist: "Echoel",
                patch: SynthPatch(name: "Harbour Pad"),
                notes: [note(60, 0), note(64, 2)],
                rawTake: Project.RawTake(styleRaw: "ambient", bars: [[note(67, 0)]]),
                drumSteps: [[true, false]],
                drumAccents: [[false, true]])
    }

    private func fixtureEnvelope(
        timelineAutomation: [AutomationLane] = [],
        playerAutomation: [AutomationLane] = [],
        clipSlots: [Clip?] = [Clip(name: "A"), nil, Clip(name: "B")]
    ) -> DMMWProject {
        DMMWProjectImport.envelope(
            project: fixtureProject(),
            timeline: TimelineDocument(automation: timelineAutomation),
            clipSlots: clipSlots,
            songForm: Arrangement(sections: [ArrangementSection(name: "Intro", lengthBars: 4)]),
            playerAutomation: playerAutomation,
            ppq: Note.ticksPerQuarter,
            sampleRate: 48_000)
    }

    // MARK: 1 — the scalar tempo becomes a MAP, and leaves no second home behind

    func testTheScalarTempoBecomesAConstantMapAndNothingElse() {
        let envelope = fixtureEnvelope()

        XCTAssertEqual(envelope.timebase.tempoMap.entries.count, 1, """
            A project carries ONE tempo, so its map must carry exactly one entry. More than one
            means the importer invented a tempo change the user never wrote; zero would mean
            `TempoMap` normalised the project's tempo away.
            """)
        XCTAssertEqual(envelope.timebase.tempoMap.entries.first?.bpm ?? 0, 97.5, accuracy: 1e-9,
            "The project's BPM did not survive the conversion to a constant map.")
        XCTAssertEqual(DMMWProjectImport.openingTempo(of: envelope), 97.5, accuracy: 1e-9, """
            `openingTempo` is the ONE reader that hides whether a project came in as a scalar or
            as a curve. If it disagrees with the map's first entry, that abstraction leaks and
            every caller has to know the difference again.
            """)

        // The structural half: rule 2 is "bpm BECOMES the map", not "bpm sits beside it".
        let envelopeCode = code(Self.envelopePath)
        XCTAssertNil(envelopeCode.range(of: "var bpm\\b", options: .regularExpression), """
            \(Self.envelopePath) declares a `bpm` field. That is one decision in two homes
            (#416) inside the very type built to end it: a later edit to either one has no way
            to disagree loudly. The tempo lives in `timebase.tempoMap` and nowhere else.
            """)
    }

    // MARK: 2 — lossless: every stored field of `Project` arrives somewhere

    func testTheImportDropsNothingTheProjectCarried() {
        let project = fixtureProject()
        let envelope = fixtureEnvelope()

        XCTAssertEqual(envelope.meta.id, project.id)
        XCTAssertEqual(envelope.meta.name, "Harbour Take")
        XCTAssertEqual(envelope.meta.artist, "Echoel")
        XCTAssertEqual(envelope.meta.savedAt, project.savedAt)

        XCTAssertEqual(envelope.musical.keyRoot, 7)
        XCTAssertEqual(envelope.musical.scaleRaw, "dorian")
        XCTAssertEqual(envelope.musical.styleRaw, "dubTechno")
        XCTAssertEqual(envelope.musical.modeRaw, "flowFree")
        XCTAssertEqual(envelope.musical.a4Hz, 432, accuracy: 1e-9)
        XCTAssertEqual(envelope.musical.toneSystemID, "just-intonation")
        XCTAssertEqual(envelope.musical.moodFields?["weird"] ?? 0, 0.25, accuracy: 1e-6)

        XCTAssertEqual(envelope.sound.patch.name, "Harbour Pad")
        XCTAssertEqual(envelope.sound.fxCharacterRaw, "warm")

        XCTAssertEqual(envelope.legacy.notes.count, 2, """
            The take did not survive. It rides in `legacy` WHOLE and is not lifted into a
            region: a region references a `clipID` and the notes live in `Clip.melody`, so
            lifting means minting a clip — restructuring, which is the writer's decision.
            """)
        XCTAssertEqual(envelope.legacy.rawTakeStyleRaw, "ambient", """
            The raw take's GENRE is the field `rebalanceTake()` needs and the one an importer is
            most likely to drop, because it looks redundant beside `musical.styleRaw`. It is
            not: the take was composed in one genre and the project may since have moved.
            """)
        XCTAssertEqual(envelope.legacy.rawTakeBars.count, 1)
        XCTAssertEqual(envelope.legacy.drumSteps, [[true, false]], """
            The drum payload is gone. It cannot SOUND since #166/#167 removed the drum voice —
            and a project written by an older build still carries it (#527). Reading it and
            never writing it forward is the whole rule; dropping it at import loses it.
            """)
        XCTAssertEqual(envelope.legacy.drumAccents, [[false, true]])
        XCTAssertEqual(envelope.legacy.loopBars, 8)

        // And the half a behaviour test cannot reach: a field ADDED to `Project` tomorrow.
        // Stored properties only — a computed `var` closes its brace on the same line.
        var stored: [String] = []
        for line in source(Self.projectPath).components(separatedBy: "\n") {
            guard line.hasPrefix("    public var "), !line.contains("{") else { continue }
            let name = line.dropFirst("    public var ".count)
                .prefix { $0.isLetter || $0.isNumber }
            if !name.isEmpty { stored.append(String(name)) }
        }
        XCTAssertGreaterThan(stored.count, 10, """
            The `public var` walk over \(Self.projectPath) found \(stored.count) stored fields.
            A parser that matches (almost) nothing is a finding, never a pass — the declaration
            style changed and this claim stopped asking its question.
            """)

        // `schemaVersion` is the ONE exemption, and it has a reason: the version belongs on the
        // ENVELOPE, once, not in each compartment — an envelope whose compartments each version
        // themselves is one you can only open once.
        let importerCode = code(Self.importerPath)
        let unread = stored.filter { $0 != "schemaVersion" && !importerCode.contains("project.\($0)") }
        XCTAssertTrue(unread.isEmpty, """
            \(Self.importerPath) never reads: \(unread.joined(separator: ", ")).
            A field added to `Project` without a home in the envelope is data that loads today
            and disappears the day a writer lands. Give it a compartment, or put it in `legacy`
            with the reason at the line — do NOT silence this by widening the exemption.
            """)
    }

    // MARK: 3 — the automation duplication is decided, and deciding it loses nothing

    func testThePlayerAutomationSurvivesOnlyWhereTheTimelineIsSilent() {
        let envelope = fixtureEnvelope(
            timelineAutomation: [lane("filter.cutoff", 0.9)],
            playerAutomation: [lane("filter.cutoff", 0.1), lane("mix.level", 0.4)])

        XCTAssertEqual(envelope.content.timeline.automation.map(\.parameter), ["filter.cutoff"],
            "The timeline's own lanes must pass through untouched — it is the winner, not a peer.")
        XCTAssertEqual(envelope.content.playerAutomation.map(\.parameter), ["mix.level"], """
            The merge rule is wrong. "Timeline wins" is a READING rule: the player's lane for a
            parameter the timeline already drives is dropped, and every other player lane is
            CARRIED. An importer that deleted them all would turn a visible duplication into a
            silent loss — the #527 shape, where a root with no surface is still the only thing
            holding somebody's data.
            """)
        XCTAssertEqual(envelope.content.playerAutomation.first?.points.first?.value ?? -1, 0.4,
                       accuracy: 1e-9,
            "A surviving lane must arrive whole, not as a parameter name with empty keyframes.")
    }

    // MARK: 4 — the clip grid is POSITIONAL

    func testTheClipGridKeepsItsHoles() {
        let envelope = fixtureEnvelope()

        XCTAssertEqual(envelope.content.clipSlots.count, 3, """
            The clip grid was compacted. `ClipStore` persists `[Clip?]` — a fixed grid where the
            INDEX is the identity a saved arrangement refers to. Removing the holes silently
            renumbers every slot anything points at.
            """)
        XCTAssertNil(envelope.content.clipSlots[1], "Slot 1 was a hole and must stay one.")
        XCTAssertEqual(envelope.content.clipSlots[0]?.name, "A")
        XCTAssertEqual(envelope.content.clipSlots[2]?.name, "B")
        XCTAssertEqual(envelope.content.songForm.sections.first?.name, "Intro",
                       "The song form is a SONG root and rides in the envelope, not beside it.")
    }

    // MARK: 5 — it round-trips, and an older envelope still opens

    func testTheEnvelopeRoundTripsAndAMissingVersionReadsAsOne() throws {
        let envelope = fixtureEnvelope(timelineAutomation: [lane("filter.cutoff", 0.9)],
                                       playerAutomation: [lane("mix.level", 0.4)])
        let data = try JSONEncoder().encode(envelope)
        let back = try JSONDecoder().decode(DMMWProject.self, from: data)

        // Compartment by compartment, so a red NAMES the compartment instead of saying "not
        // equal" about a type with six of them.
        XCTAssertEqual(back.envelopeVersion, envelope.envelopeVersion, "version")
        XCTAssertEqual(back.meta, envelope.meta, "meta did not round-trip")
        XCTAssertEqual(back.timebase, envelope.timebase, "timebase did not round-trip")
        XCTAssertEqual(back.musical, envelope.musical, "musical did not round-trip")
        XCTAssertEqual(back.content, envelope.content, "content did not round-trip")
        XCTAssertEqual(back.sound, envelope.sound, "sound did not round-trip")
        XCTAssertEqual(back.legacy, envelope.legacy, "legacy did not round-trip")

        // An envelope written before the version existed must still open. This is the property
        // a version stamp only has if it can be ABSENT — added as a required field, every
        // pre-existing document is indistinguishable from the new format.
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("the encoded envelope is not a JSON object")
        }
        XCTAssertNotNil(object["envelopeVersion"],
                        "the encoder must WRITE the version, or nothing can branch on it later")
        object.removeValue(forKey: "envelopeVersion")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let old = try JSONDecoder().decode(DMMWProject.self, from: stripped)
        XCTAssertEqual(old.envelopeVersion, 1, """
            An envelope with no version must read as 1. If this throws instead, the decode is
            strict on the one field that is allowed to be missing and every document written
            before the stamp is unopenable.
            """)
        XCTAssertEqual(old.meta.name, "Harbour Take",
                       "the rest of a version-less envelope must still arrive")
    }

    // MARK: 6 — the seven APP roots stay OUT

    func testTheEnvelopeDoesNotSwallowTheLibraryOrTheSettings() {
        let text = code(Self.envelopePath) + "\n" + code(Self.importerPath)
        let appRoots = ["PatchStore", "FXPresetStore", "MoodPresetStore", "ModulationEngine",
                        "ModulationMatrix", "SignalRouter", "TrackFXStore", "SessionRecorder"]
        let swallowed = appRoots.filter { text.contains($0) }
        XCTAssertTrue(swallowed.isEmpty, """
            The envelope layer names: \(swallowed.joined(separator: ", ")).
            Those are APP state — the user's patch library, their FX and mood presets, the
            modulation matrix, the signal routes, the track FX, the bio log. Packing any of them
            into a project turns "open a project" into "replace the app's state", and the user
            loses their own presets because they opened somebody else's piece. Five SONG roots,
            nothing else. The ONE thing a project carries by value is the patch that makes it
            sound (`SynthPatch`, small and piece-defining) — that is the type, never the store.
            """)
    }

    // MARK: 7 — importer first, writer second

    func testThereIsNoWriterAndNoCallSiteYet() throws {
        let importerCode = code(Self.importerPath)
        let funcs = importerCode.components(separatedBy: "func ").count - 1
        XCTAssertEqual(funcs, 2, """
            \(Self.importerPath) declares \(funcs) functions; it declares exactly two on
            purpose — `envelope(...)` and `openingTempo(of:)`. Nothing in here writes. When the
            writer lands, it is a DECISION about the on-disk format and it gets its own slice,
            its own gate and this claim replaced in the same commit (#364 — this forbids
            nothing, it records what is true today).
            """)
        for absent in ["func write", "func save", "func apply", "func store"] {
            XCTAssertFalse(importerCode.contains(absent),
                           "\(Self.importerPath) grew `\(absent)` — see the message above.")
        }

        // And nothing in the app reaches for it yet. A call site is what turns a wrong import
        // from a corrected function into a user's lost piece.
        let sources = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        var callers: [String] = []
        let walker = FileManager.default.enumerator(atPath: sources.path)
        while let entry = walker?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }
            let relative = "Sources/Echoelmusic/" + entry
            guard relative != Self.envelopePath, relative != Self.importerPath else { continue }
            if code(relative).contains("DMMWProject") { callers.append(relative) }
        }
        XCTAssertTrue(callers.isEmpty, """
            \(callers.joined(separator: ", ")) reach(es) the envelope. The whole risk mitigation
            of this slice is that the five source roots stay the truth on disk and nothing reads
            the new shape — if the import is wrong, the cost is a corrected function. Wiring it
            up is the writer's slice, and it takes this claim with it.
            """)
    }

    // MARK: 8 — the layer stays Foundation-only

    func testTheEnvelopeLayerStaysFoundationOnly() {
        for path in [Self.envelopePath, Self.importerPath] {
            var imports = Set<String>()
            for line in code(path).components(separatedBy: "\n") where line.hasPrefix("import ") {
                imports.insert(String(line.dropFirst("import ".count)
                    .prefix { $0.isLetter || $0.isNumber }))
            }
            XCTAssertEqual(imports, ["Foundation"], """
                \(path) imports \(imports.sorted().joined(separator: ", ")).
                Every type this envelope carries — `TimelineDocument`, `Clip`, `Arrangement`,
                `AutomationLane`, `SynthPatch`, `Note`, `Timebase` — is Foundation-only, and
                that is the property that would let this layer be lifted into its own target
                (the `EchoelCore` target is founder-gated: `project.yml`, report do not edit).
                One UI or engine import here spends that property for good.
                """)
        }
    }
}
