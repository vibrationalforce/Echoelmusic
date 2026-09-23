// TheAudioLaneProducerIsTheImportDoorTests.swift
// Echoel - the census of who can put an audio region on an audio lane. #527, closed by
// Audio Import V1 (founder 2026-09-22).
//
// THIS FILE WAS `TheAudioLanesHaveNoProducerTests.swift` AND THAT NAME IS NOW A FALSE
// STATEMENT (#374 - a test name states a fact). Its finding was real and stood for four
// months: `AudioLanePlayer` was constructed by `EchoelmusicApp` and driven by
// `TimelineRegionPlayer` on every prime/apply/stop, `TimelineAudioSink` was injected into
// it, and NOTHING a user could reach ever put an audio region on an audio lane - so `apply`
// walked `doc.audioLaneIDs` and found nothing, every step, forever.
// `Sequencer/AudioImport.swift` is the producer, and `WorkstationView`'s "Import Audio" row
// is its door.
//
// WHAT SURVIVES UNCHANGED, AND IT IS MOST OF THE FILE. The census was never an argument for
// deletion - it was an argument that a SECOND producer must be a decision rather than a
// drift, and that is exactly as true with one door as with none. Every counterweight below
// stands: the recorder chain is still doorless, the migration still seeds an EMPTY audio
// lane, both MIDI region creators still build `kind: .midi`, and the layer is still wired to
// the transport. What changed is one number in one set. (S2, 2026-09-23, added a THIRD MIDI
// region creator — `MIDIImport.plan`, doored by "Import MIDI" — and it too builds
// `kind: .midi` with notes in `Clip.melody`, never an audio-bearing clip; its own guard is
// `TheWorkstationImportsMIDITests`.)
//
// THE MEASUREMENT, because "one door" is a claim like any other. Every audio-bearing region
// creator in `Sources/` is accounted for:
//   - `TimelineStore.migrate(sections:)` seeds an empty `Audio 1` lane and puts EVERY
//     region on the MIDI lane - driven end-to-end below, not scanned.
//   - `ensureComposerRegion` / `ensureUserMidiRegion` build their clip `kind: .midi` by
//     construction - TRUE of both, and the only thing that is. #865: this file used to
//     call them "the two region creators a door can reach", and that is HALF false.
//     Measured 2026-08-29: `.ensureComposerRegion(` has one production caller
//     (`Studio/EchoelStudioView.swift`); `.ensureUserMidiRegion(` has ZERO - its only
//     callers are in the non-blocking `UserMidiRegionStoreTests`. It belongs with the
//     `RecordController` chain below as BUILT-BUT-DOORLESS, not up here as reachable.
//     That is why the wrong reason survived so long - a wrong reason pointing at a right
//     answer is invisible until someone reads the reason (#367).
//   - `RecordController` -> `TakeRecorder` -> `AudioClipFactory` is still the DOORLESS
//     audio-bearing chain: `TakeRecorder` is constructed only from `RecordController`, and
//     `RecordController.arm()` has zero callers (#204). That chain is untouched by this
//     slice and must stay untouched - it needs an audio INPUT, which this app does not
//     have (#1302).
//   - `AudioImport.plan` is the SECOND caller of `AudioClipFactory` and the FIRST with a
//     door. It is behaviour-tested in `TheWorkstationImportsAudioTests`, which owns every
//     claim about WHAT it produces; this file owns only the census of WHO may produce.
//
// IT STILL DOES NOT ARGUE FOR DELETION, and the reason is unchanged. `TimelineDocument` is
// PERSISTED and decoded at launch, so a project from any build can carry an audio region,
// and this coordinator is the only thing that would play it. The default document
// deliberately still seeds an EMPTY audio lane, because the founder asked for the multi-lane
// shape ("mehrere") from day one - and that lane is now the thing an import lands on, so
// dropping it would take the import door's only target with it.
//
// AND IT FORBIDS NOTHING (#364). A second import door, a lane creator, a re-doored recorder
// are all legitimate work. What it forbids is landing one while the prose still counts one
// producer. When an assertion here goes red for that reason, the repair is to move the block
// in `AudioLanePlayer.swift` and the register line in CLAUDE.md IN THE SAME COMMIT, not to
// relax the assertion.
//
// HONEST GRADING (#433/#464/#486). This file names no symbol this commit adds, so it
// COMPILES against the parent and every assertion has a verdict there. Transcribed by hand
// (a Python rebuild of `SourceText.codeOnly`, run against the parent and the worktree):
//   - TWO assertions are REGRESSIONS in the intended direction - the factory-caller set (one
//     entry on the parent, two on the worktree) and the header claim, which on the parent
//     still states that nothing reachable fills an audio lane.
//   - The rest are COUNTERWEIGHTS, green on both trees, and they are the value (#343). A
//     tree that adds the door and then deletes the wiring, or drops the seeded audio lane,
//     or lets a MIDI region creator start making audio clips, satisfies the new census and
//     breaks what it describes.
//   - The migration assertion drives shipped code end to end - `TimelineStore.migrate` is a
//     pure `static` over `public` Foundation-only value types. The chain assertions are
//     source scans.
//
// `SourceText.codeOnly` IS LOAD-BEARING and that is MEASURED rather than assumed (#484 and
// #485 each had to withdraw the stronger claim once, #486 twice). The culprit is
// `AudioClipFactory.swift` line 1 - `// AudioClipFactory.swift`, the file's own name. A
// needle shaped `TypeName.` matches every Swift file's header comment, so the chain equality
// would be RED ON CORRECT CODE without the stripper, for a reason that has nothing to do
// with this slice and applies to every scan of that shape anyone writes here.
//
// AND THE LIMIT FIRST. Nothing here plays audio or proves silence on a device. It proves
// which lines in `Sources/` can create an audio-bearing region, and that the prose describing
// that set agrees with it. `Tests/CISmoke` is the blocking bundle; a missing tree SKIPS
// (#454).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAudioLaneProducerIsTheImportDoorTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let player = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"

    // MARK: - The finding

    /// The header must NAME the producer, and must not still count zero.
    ///
    /// Two halves, because the stale shape has two forms. POSITIVE: the file has to say where
    /// an audio region comes from, so the next reader of `apply` walking an empty
    /// `audioLaneIDs` knows whether that is a bug or an empty song. NEGATIVE: the two
    /// withdrawn sentences must stay withdrawn.
    ///
    /// ⛔ THE NEGATIVE HALF IS SCANNED ON A WHITESPACE-NORMALISED HEADER, NOT PER LINE, AND
    /// THE FIRST DRAFT OF THIS CLAIM WAS A NEEDLE THAT COULD NEVER MATCH (#367/#454). It
    /// filtered LINES carrying the phrase — and on the parent tree that sentence is WRAPPED
    /// ("because nothing a / user can reach ever puts…"), so the scan found nothing and read
    /// as a pass on the very tree whose prose it was written to catch. A comment in this repo
    /// is re-wrapped by every edit that touches the paragraph above it, so a per-line needle
    /// into a prose block is unsound by construction. Normalising joins the wrap.
    ///
    /// ⚠️ AND THE TENSE IS THE DISCRIMINATOR, deliberately. The corrected header narrates the
    /// old finding in the PAST ("nothing a user COULD reach ever PUT"), which is how a
    /// retraction stays readable; what is banned is the header asserting it of TODAY. A
    /// rewrite that flips that sentence back to the present goes red — exactly when it should.
    func testTheHeaderNamesTheProducerInsteadOfCountingZero() throws {
        let header = try rawText(Self.player)

        XCTAssertTrue(header.contains("AudioImport"), """
            `AudioLanePlayer`'s header no longer names `AudioImport`. This layer is a \
            reconciler with no producer of its own, so its header is the one place a reader \
            arriving from `apply` learns where an audio region can come from. For four months \
            the answer was "nowhere", and saying so was the whole value of the ⛔ block; the \
            answer is now the Workstation import door, and saying THAT is the same value.
            """)

        let flat = Self.normalisedComment(header)

        // The over-claim: legal ONLY as the quoted subject of its own retraction.
        let overClaim = "audio lanes now sound in time with the arrangement"
        XCTAssertEqual(Self.occurrences(of: overClaim, in: flat),
                       Self.occurrences(of: "SAID \"\(overClaim)\"", in: flat), """
            `AudioLanePlayer` states "\(overClaim)" somewhere other than inside its own \
            retraction. It is an unconditional capability claim and the truth is \
            conditional: an audio lane sounds once a user has imported onto it, and the \
            default document seeds an EMPTY audio lane, so a fresh install still walks this \
            layer and finds nothing.
            """)

        // The under-claim: false since Audio Import V1, in any position.
        let underClaim = "nothing a user can reach ever puts an audio region"
        XCTAssertEqual(Self.occurrences(of: underClaim, in: flat), 0, """
            `AudioLanePlayer` states "\(underClaim)" in the PRESENT tense. That was true for \
            four months and is not any more: `AudioImport.plan` calls `AudioClipFactory` and \
            `WorkstationView` calls `AudioImport.perform`. Repeating it sends the next reader \
            hunting for a producer that is one file away — and it is the sentence that would \
            justify deleting this layer as dead.
            """)
    }

    /// A comment block with its `//` markers dropped and every run of whitespace collapsed to
    /// one space, so a needle into PROSE survives the re-wrapping that any neighbouring edit
    /// causes. Deliberately NOT `SourceText.codeOnly` — that one blanks comments, and the
    /// claims above are ABOUT the comments.
    private static func normalisedComment(_ text: String) -> String {
        var out = ""
        var lastWasSpace = false
        for character in text {
            if character.isWhitespace {
                if !lastWasSpace { out.append(" ") }
                lastWasSpace = true
            } else if character == "/", out.hasSuffix("/") {
                // ⛔ THIS LINE READ `lastWasSpace = false` AND THAT SINGLE WORD MADE THE
                // WHOLE CLAIM VACUOUS. Dropping the second `/` of a `// ` marker leaves the
                // newline's space already in `out`; saying "the last character was not a
                // space" then let the marker's OWN trailing space through as a second one,
                // so every wrapped sentence normalised with a DOUBLE space at the wrap and
                // no single-spaced needle could match it. Measured on the parent tree: the
                // withdrawn sentence wraps exactly there, and the scan reported 0.
                lastWasSpace = out.hasSuffix(" ")
            } else {
                out.append(character)
                lastWasSpace = false
            }
        }
        return out
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var index = text.startIndex
        while let found = text.range(of: needle, range: index..<text.endIndex) {
            count += 1
            index = found.upperBound
        }
        return count
    }

    /// The legacy migration seeds an audio lane and puts nothing on it.
    ///
    /// Driven end to end rather than scanned: `migrate` is pure over `public`
    /// Foundation-only value types, so this is real behaviour, not text.
    func testTheMigrationSeedsAnEmptyAudioLane() throws {
        let sections = [
            ArrangementSection(clipID: UUID(), name: "A", lengthBars: 2),
            ArrangementSection(clipID: nil, name: "gap", lengthBars: 1),
            ArrangementSection(clipID: UUID(), name: "B", lengthBars: 4)
        ]
        let doc = TimelineStore.migrate(sections: sections)

        XCTAssertEqual(doc.audioLaneIDs.count, 1, """
            The migrated document no longer carries exactly one audio lane. The empty \
            `Audio 1` lane is deliberate — the founder asked for the multi-lane shape \
            ("mehrere") from day one — and it is what makes the absence of any audio region \
            visible rather than invisible.
            """)
        let audioLane = try XCTUnwrap(doc.audioLaneIDs.first)
        for region in doc.regions {
            XCTAssertNotEqual(region.laneID, audioLane, """
                `TimelineStore.migrate` placed a region on the AUDIO lane. Every region it \
                creates belongs to the MIDI lane; a section carries a MIDI clip. If audio \
                migration is genuinely being added, the header ⛔ block in \
                `AudioLanePlayer.swift` and CLAUDE.md's doorless register both count zero \
                producers and must move in the same commit.
                """)
        }
        XCTAssertFalse(doc.regions.isEmpty, """
            The migration produced no regions at all, so the assertion above passed \
            vacuously (#343). Two of the three fixture sections carry a clip id.
            """)
    }

    /// BOTH MIDI region creators build MIDI clips, by construction. Renamed in #865: the old
    /// name said "Reachable", and only one of the two is (#374 — a test name states a fact).
    func testBothMidiRegionCreatorsMakeMidiClips() throws {
        let store = SourceText.codeOnly(try rawText("\(Self.sourcesRoot)/Core/TimelineStore.swift"))
        for creator in ["ensureComposerRegion", "ensureUserMidiRegion"] {
            let body = try body(of: creator, in: store)
            XCTAssertTrue(body.contains("kind: .midi"), """
                `\(creator)` no longer builds its clip with `kind: .midi`. These two are the \
                MIDI-only region creators — one reachable, one not (see the header) — beside \
                the doorless `RecordController` chain and the Workstation import door. If \
                either can now make an AUDIO clip, there is a third audio-bearing producer \
                nobody has counted: the census one MARK down, `AudioLanePlayer`'s header and \
                CLAUDE.md's register all name a set that would no longer be the set. Note \
                what CLAUDE.md actually says: it claims CONSTRUCTION (`kind: .midi`), never \
                reachability, so it is NOT stale today and must not be "corrected" from here.
                """)
        }
    }

    /// The asymmetry itself (#865). Pinned because the prose above is only as good as the
    /// measurement behind it, and that measurement had been wrong for the life of the file.
    ///
    /// ⚠️ THIS FORBIDS NOTHING (#364). Dooring `ensureUserMidiRegion` — giving the user a way
    /// to add their own MIDI clip to a lane — is legitimate, wanted work. This assertion goes
    /// red on the day it lands, and its job is to say WHICH PROSE moves in that same commit,
    /// not to argue against the change. Mitigate by updating; never by deleting.
    func testOnlyOneOfTheTwoMidiCreatorsHasADoor() throws {
        let composerCallers = try filesUnderSources(containing: ".ensureComposerRegion(")
        XCTAssertEqual(composerCallers, ["Studio/EchoelStudioView.swift"], """
            `ensureComposerRegion` is now called from \
            \(composerCallers.isEmpty ? "nothing" : composerCallers.joined(separator: ", ")). \
            If it lost its caller, the composer clip has no producer either and the header's \
            census needs re-reading. If it gained one, say where the second door is.
            """)

        let userCallers = try filesUnderSources(containing: ".ensureUserMidiRegion(")
        XCTAssertTrue(userCallers.isEmpty, """
            `ensureUserMidiRegion` now has a production caller: \
            \(userCallers.joined(separator: ", ")). That is a NEW DOOR, and it is very likely \
            correct work — this is not an objection. It is a checklist. Three places call this \
            creator unreachable and must move in the same commit: (1) this file's header \
            bullet, (2) the failure message of `testBothMidiRegionCreatorsMakeMidiClips`, \
            (3) this test's own name and doc. Verify the new door creates `kind: .midi` only; \
            an audio-bearing clip here would be a THIRD audio-bearing producer (after the \
            doorless recorder chain and the Workstation import door) and falsify this file's \
            census.
            """)
    }

    // MARK: - Counterweights (#343)

    /// THE CENSUS — exactly TWO callers mint an audio-bearing clip, and only one has a door.
    ///
    /// ⭐ THIS IS THE ASSERTION AUDIO IMPORT V1 CHANGED, and it is the whole record of the
    /// change in this file. It read `["Sequencer/TakeRecorder.swift"]` for four months; the
    /// second entry is the import path. Each link is measured separately, because the finding
    /// is the CHAIN: a caller anywhere along it is a door, and a door is what changes the
    /// verdict.
    ///
    /// ⚠️ IT FORBIDS NO THIRD CALLER (#364) — it prices one. A sampler, a paste, a project
    /// importer are all legitimate; each must arrive with its own behaviour guard and with
    /// this line, `AudioLanePlayer`'s header block and CLAUDE.md's register moved in the same
    /// commit. A pinned SET rather than a count, so the failure message names WHO appeared.
    func testTheAudioBearingProducersAreTheRecorderChainAndTheImportDoor() throws {
        let factoryCallers = try filesUnderSources(containing: "AudioClipFactory.")
        XCTAssertEqual(factoryCallers,
                       ["Sequencer/AudioImport.swift", "Sequencer/TakeRecorder.swift"], """
            `AudioClipFactory` is now called from \
            \(factoryCallers.isEmpty ? "nothing" : factoryCallers.joined(separator: ", ")). \
            It is the one thing that mints an audio-bearing clip, and the expected set is \
            exactly two: `AudioImport` (the Workstation door, Audio Import V1) and \
            `TakeRecorder` (the doorless recorder chain, #204). Losing `AudioImport` takes \
            the audio lanes back to having no reachable producer at all; gaining a third \
            entry is a new path to a sounding audio lane and needs the prose moved with it.
            """)

        let recorderBuilders = try filesUnderSources(containing: "TakeRecorder(")
            .filter { $0 != "Sequencer/TakeRecorder.swift" }
        XCTAssertEqual(recorderBuilders, ["Core/RecordController.swift"], """
            `TakeRecorder` is now constructed by \
            \(recorderBuilders.isEmpty ? "nothing" : recorderBuilders.joined(separator: ", ")). \
            The RECORDER chain runs RecordController → TakeRecorder → AudioClipFactory and is \
            still inert because its first link is doorless (#204) — and it must stay that \
            way here: it needs an audio INPUT, which this app does not have (#1302). Audio \
            Import V1 deliberately did NOT re-door it; it added a parallel producer that \
            reads a file the user already owns.
            """)

        // ⛔ A THIRD ASSERTION WAS DRAFTED HERE AND DELETED BEFORE IT SHIPPED, because it
        // was RED ON CORRECT CODE (#364/#367). It scanned `Sources/` for `.arm()` to pin
        // that `RecordController.arm()` still has no caller — and the one hit is
        // `voice.arm()` in `EchoelStudioView`, the "Body voice" switch (#277), a completely
        // unrelated receiver. A bare member needle cannot express "on THIS type"; the
        // recorder chain is already pinned one assertion up, by its CONSTRUCTOR, which is a
        // name only `RecordController` writes. Recorded rather than dropped silently: the
        // next reader will have the same idea.
    }

    /// COUNTERWEIGHT — the layer must stay WIRED.
    ///
    /// The tempting cleanup after reading the finding is to unwire "dead" audio lanes.
    /// `TimelineDocument` is persisted and decoded at launch, so a project written by a build
    /// whose recorder path was reachable can still carry an audio region — and this
    /// coordinator is the only thing that would play it. Unwiring turns "obviously absent"
    /// into "silently silent".
    func testTheLayerIsStillWiredToTheTransport() throws {
        let app = SourceText.codeOnly(try rawText("\(Self.sourcesRoot)/EchoelmusicApp.swift"))
        XCTAssertTrue(app.contains("timelinePlayer.audioLanes = AudioLanePlayer("), """
            `AudioLanePlayer` is no longer attached to the transport in `EchoelmusicApp`. \
            That is not a cleanup: a persisted `TimelineDocument` carrying an audio region \
            would then decode, appear in the arrangement and never make a sound, with \
            nothing left to explain why.
            """)

        let player = SourceText.codeOnly(try rawText(Self.player))
        for entry in ["public func apply(", "public func prime(", "public func stopAll("] {
            XCTAssertTrue(player.contains(entry), """
                `AudioLanePlayer` no longer declares `\(entry)…`. The transport drives the \
                layer through exactly these three; losing one leaves audio lanes that start \
                and never stop, or stop and never start.
                """)
        }
    }

    // MARK: - Reading the source

    /// #1240 — thrown after `XCTFail` when a creator's anchor is missing, so the calling claim
    /// stops (it has nothing to scan) AND the run is red (it asserted the anchor and lost).
    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body of `name` inside `code`, so a needle cannot be satisfied by a
    /// neighbouring declaration. Throws rather than returning "" when the anchor is missing
    /// (#454) — a vanished creator must not read as a pass.
    private func body(of name: String, in code: String) throws -> String {
        guard let start = code.range(of: "func \(name)"),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex)
        else {
            // #1240: the file is present and the anchor is not — that is a red, not a skip. A
            // skip is the honest answer only when the TREE is missing (the `fileExists` form);
            // here it would let a rename of the creator read as green. The throw keeps the
            // caller's `try` contract; XCTFail is what makes it red.
            XCTFail("`func \(name)` is not in TimelineStore.swift — the anchor moved; re-anchor this guard (#1240: XCTFail for a missed anchor, XCTSkip only for a missing tree)")
            throw AnchorMissing(name: name)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        throw XCTSkip("unbalanced braces after `func \(name)` — refusing to guess its body")
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("""
                \(relativePath) is not present — this guard inspects source text, so it SKIPS \
                rather than reporting a green it did not earn (#454)
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
