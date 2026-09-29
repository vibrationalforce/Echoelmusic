// ThePlateShowsHowAPieceIsMadeTests — DMMW Phase 1 (founder 2026-09-29): "Die Oberfläche muss
// nach dem Start sofort zeigen, wie man ein Stück erstellt. Keine leeren Platzhalter ohne
// Aktion." The Workstation opens with "Create a piece" and five steps (`ComposeGuide`,
// `WorkstationView.composeGuide`, `ComposeGuideCard`).
//
// WHAT IS PINNED, and which kind of claim each is (§1):
//   1–5  END-TO-END BEHAVIOUR — `ComposeGuide` is a pure value type driven with real
//        `TimelineDocument`s and `Clip`s: the step order an empty song walks, the ONE next step,
//        the composer's take not counting as the user's notes, the part "Write notes" selects,
//        and every step speaking its position and state in words.
//   6–8  SOURCE-TEXT SCAN — the card and the Workstation's members are `private` on a `View`.
//        6: the guide is mounted FIRST on the plate, and every step runs an EXISTING path (the
//        same function the creation row runs, the one Play/Stop, the chrome door) — no new
//        write, no new modal. 7: the card has no store read and no path that acts on focus or on
//        a swipe (only `Button` activation). 8: the new-part transaction has ONE call site in the
//        view, which the row and the guide share (#416).
//
// GRADING (§3). Against the PARENT tree this file does NOT COMPILE — it names `ComposeGuide`,
// which this same commit creates — so no assertion has a verdict there. Every claim is a
// FORWARD guard; none is a regression. Transcribed in Python against THIS tree (no toolchain
// here): the state table for the five fixtures below was re-derived by hand from
// `ComposeGuide.baseState`/`state(of:)`, and claims 6–8 were driven as scans over the
// comment-stripped view (each needle found exactly where claimed; the modal, gesture and
// store-read negatives found nothing in the card).
//
// ⛔ HONEST LIMIT: nothing here proves how the card LOOKS, that it fits a phone at AX5, or that
// VoiceOver reads it well — DEVICE PROBE, open. NEEDS-FOUNDER-VERIFY: fresh install → Workstation
// → tap the five steps in order; confirm each one ticks and that "Write notes" leads to Notes.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePlateShowsHowAPieceIsMadeTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: - fixtures

    private func facts(_ document: TimelineDocument, _ clips: [Clip],
                       canPlay: Bool = false, isPlaying: Bool = false) -> ComposeGuide.Facts {
        ComposeGuide.facts(document: document, clips: clips, canPlay: canPlay, isPlaying: isPlaying)
    }

    private func states(_ f: ComposeGuide.Facts) -> [ComposeGuide.State] {
        ComposeGuide.Step.allCases.map { ComposeGuide.state(of: $0, f) }
    }

    // MARK: - 1. an empty song: step 1 is THE next step, and nothing else pretends to be ready

    func testAnEmptySongStartsAtStepOneAndWaitsForTheRest() {
        let f = facts(TimelineDocument(), [])
        XCTAssertEqual(ComposeGuide.Step.allCases.map(\.rawValue), [1, 2, 3, 4, 5],
                       "five steps, numbered as the card shows them")
        XCTAssertEqual(states(f), [.next, .waiting, .waiting, .waiting, .waiting], """
            An empty song has exactly one thing to do: add a MIDI track. A later step that read \
            as available would be a door that does nothing (#164/#227).
            """)
        XCTAssertEqual(ComposeGuide.doneCount(f), 0)
        XCTAssertEqual(ComposeGuide.headerLabel(f), "Create a piece, 0 of 5 steps done")
    }

    // MARK: - 2. the steps advance off the song itself

    func testTheNextStepFollowsTheSong() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let trackOnly = facts(TimelineDocument(lanes: [keys], regions: []), [])
        XCTAssertEqual(states(trackOnly), [.done, .next, .waiting, .waiting, .waiting])

        let empty = Clip(name: "part", kind: .midi, melody: MelodyClip(notes: []))
        let region = TimelineRegion(laneID: keys.id, clipID: empty.id, startTick: 0,
                                    lengthTicks: 4 * Self.bar)
        let emptyPart = facts(TimelineDocument(lanes: [keys], regions: [region]), [empty])
        XCTAssertEqual(states(emptyPart), [.done, .done, .next, .waiting, .ready], """
            An empty part: write notes next. Save is available (the song holds the user's part — \
            `SessionSaveOpen.songHasUserParts`, the Studio's own predicate), Play is not.
            """)

        let written = Clip(id: empty.id, name: "part", kind: .midi,
                           melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        let withNotes = facts(TimelineDocument(lanes: [keys], regions: [region]), [written],
                              canPlay: true)
        XCTAssertEqual(states(withNotes), [.done, .done, .done, .next, .ready])
        XCTAssertEqual(ComposeGuide.title(.play, withNotes), "Play the song")

        let playing = facts(TimelineDocument(lanes: [keys], regions: [region]), [written],
                            canPlay: true, isPlaying: true)
        XCTAssertEqual(ComposeGuide.state(of: .play, playing), .done)
        XCTAssertEqual(ComposeGuide.title(.play, playing), "Stop the song",
                       "while the song plays, step 4 is its Stop — the one transport, both ways")
        XCTAssertEqual(ComposeGuide.state(of: .save, playing), .next)
        XCTAssertEqual(ComposeGuide.doneCount(playing), 4,
                       "Save never reads as done — nothing here can know the song is unchanged since")
    }

    // MARK: - 3. the composer's take is not the user's part

    func testTheComposersTakeDoesNotTickOffTheUsersSteps() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let take = Clip(name: "Composed", kind: .midi,
                        melody: MelodyClip(notes: [Note(pitch: 64, startStep: 0)]),
                        composerOwned: true)
        let region = TimelineRegion(laneID: keys.id, clipID: take.id, startTick: 0, lengthTicks: Self.bar)
        let f = facts(TimelineDocument(lanes: [keys], regions: [region]), [take], canPlay: true)
        XCTAssertFalse(f.hasPart, "a composer-owned clip is the instrument's take, not the user's part")
        XCTAssertFalse(f.hasNotes, "…and its notes must not tick off \"Write notes\"")
        XCTAssertEqual(ComposeGuide.state(of: .part, f), .next)
        XCTAssertEqual(ComposeGuide.state(of: .play, f), .ready,
                       "Play follows the engine's own guard, not the guide's steps — it can play the take")
        XCTAssertNil(ComposeGuide.partToWrite(document: TimelineDocument(lanes: [keys], regions: [region]),
                                              clips: [take]),
                     "\"Write notes\" must never open the composer's clip for editing")
    }

    // MARK: - 4. "Write notes" selects the first EMPTY part on the import's track

    func testWriteNotesSelectsTheFirstEmptyPartOnTheImportsTrack() {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let full = Clip(name: "a", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
        let empty = Clip(name: "b", kind: .midi, melody: MelodyClip(notes: []))
        let onBio = Clip(name: "c", kind: .midi, melody: MelodyClip(notes: []))
        let first = TimelineRegion(laneID: keys.id, clipID: full.id, startTick: 0, lengthTicks: Self.bar)
        let second = TimelineRegion(laneID: keys.id, clipID: empty.id, startTick: Self.bar,
                                    lengthTicks: Self.bar)
        let bioPart = TimelineRegion(laneID: bio.id, clipID: onBio.id, startTick: 0, lengthTicks: Self.bar)
        let document = TimelineDocument(lanes: [bio, keys], regions: [bioPart, second, first])
        XCTAssertEqual(document.rollLaneID, keys.id, "fixture premise: the import's track skips the bio lane")
        XCTAssertEqual(ComposeGuide.partToWrite(document: document, clips: [full, empty, onBio]), second.id, """
            With one part written and one empty, "Write notes" opens the EMPTY one — never the bio \
            lane's, which the note editor refuses.
            """)
        let allFull = TimelineDocument(lanes: [bio, keys], regions: [first])
        XCTAssertEqual(ComposeGuide.partToWrite(document: allFull, clips: [full]), first.id,
                       "with no empty part, the first part — the step still does something")
    }

    // MARK: - 5. every step speaks its place and its state in words

    func testEveryStepSpeaksItsPositionAndState() {
        let fixtures = [facts(TimelineDocument(), []),
                        facts(TimelineDocument(lanes: [TimelineLane(name: "Keys", kind: .midi)],
                                               regions: []), [])]
        for f in fixtures {
            for step in ComposeGuide.Step.allCases {
                let spoken = ComposeGuide.spokenLabel(step, f)
                XCTAssertTrue(spoken.hasPrefix("Step \(step.rawValue) of 5, \(ComposeGuide.title(step, f)), "),
                              "`\(spoken)` does not say which step it is (#482)")
                let words: [ComposeGuide.State: String] = [.done: "done", .next: "next step",
                                                           .ready: "available", .waiting: "not yet available"]
                let state = ComposeGuide.state(of: step, f)
                XCTAssertTrue(spoken.hasSuffix(words[state] ?? "?"),
                              "`\(spoken)` hides its state — colour and icon may not be the only carrier")
                XCTAssertFalse(ComposeGuide.detail(step, f).isEmpty, """
                    step \(step.rawValue) shows no line of its own in state \(state) — a disabled \
                    step must say what it is waiting for, never sit there silent
                    """)
            }
        }
    }

    // MARK: - 6. SCAN — mounted first, and every step is an existing path

    func testTheGuideIsMountedFirstAndRunsTheExistingPaths() throws {
        let code = try source(Self.view)
        let body = try member("var body: some View {", in: code)
        guard let stack = body.range(of: "VStack(alignment: .leading, spacing: 10) {") else {
            return XCTFail("ANCHOR MISSING: the Workstation's plate stack (#454)")
        }
        let afterStack = body[stack.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(afterStack.hasPrefix("composeGuide\n"), """
            "Create a piece" must be the FIRST thing on the plate — the founder's order is that the \
            surface shows how to make a piece at once, not below the arrangement.
            """)

        let guide = try member("private var composeGuide: some View {", in: code)
        for needle in ["canPlay: songCanStart(), isPlaying: player.isPlaying",
                       "case .track:", "addMIDITrack()",
                       "case .part:", "newMIDIPart()",
                       "case .notes:", "ComposeGuide.partToWrite(document: timeline.document, clips: clips)",
                       "selection.selectRegion(id, in: timeline.document)",
                       "case .play:",
                       "if player.isPlaying { player.stop() } else { startTimeline(fromTick: 0, launching: []) }",
                       "case .save:",
                       "NotificationCenter.default.post(name: .echoelChromeDoor, object: \"save\")"] {
            XCTAssertTrue(guide.contains(needle), "the guide no longer runs `\(needle)` — each step must be an existing path")
        }
        let track = try member("private func addMIDITrack() {", in: code)
        XCTAssertTrue(track.contains("MIDIImport.addMIDITrack(timeline: timeline)"),
                      "step 1 must be the Add MIDI Track row's own action")
        let row = try member("private var addMIDITrackRow: some View {", in: code)
        XCTAssertTrue(row.contains("addMIDITrack()"), "the row and the guide must share ONE action (#416)")
    }

    // MARK: - 7. SCAN — the card reads no store, adds no modal, and acts only on activation

    func testTheCardReadsNoStoreAndActsOnlyOnActivation() throws {
        let code = try source(Self.view)
        let card = try member("private struct ComposeGuideCard: View {", in: code)
        XCTAssertFalse(card.contains("@Environment"), """
            The card reads a store — it must stay a leaf that is handed its facts, so it cannot \
            subscribe to anything the Workstation does not already read.
            """)
        for banned in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog(", ".popover(",
                       ".fileImporter(", ".onAppear", ".task", ".onChange(", "Gesture(", ".gesture(",
                       ".onTapGesture", "accessibilityAction"] {
            XCTAssertFalse(card.contains(banned), """
                the card carries `\(banned)` — no new modal (black-screen law), and nothing that acts \
                on appearing, on focus or on a swipe: exploring the list with VoiceOver must start nothing
                """)
        }
        XCTAssertEqual(card.components(separatedBy: "Button {").count - 1, 2,
                       "two buttons: the header fold and the step row")
        XCTAssertEqual(card.components(separatedBy: "minHeight: 44").count - 1, 2,
                       "both buttons keep a 44 pt target")
        XCTAssertTrue(card.contains(".accessibilityLabel(ComposeGuide.spokenLabel(step, facts))"))
        XCTAssertTrue(card.contains(".accessibilityLabel(ComposeGuide.headerLabel(facts))"))
        XCTAssertTrue(card.contains(".disabled(state == .waiting)"),
                      "a waiting step is disabled — and its detail line says why (claim 5)")
        XCTAssertFalse(card.contains("minimumScaleFactor"), "Dynamic Type grows the text, never shrinks it")
    }

    // MARK: - 8. SCAN — one transaction, two doors

    func testTheNewPartTransactionHasOneCallSite() throws {
        let code = try source(Self.view)
        XCTAssertEqual(code.components(separatedBy: "MIDIImport.addEmptyPart(").count - 1, 1, """
            The empty-part transaction is called from more than one place in the view — the row \
            and the guide must share `newMIDIPart()`, or the two doors drift apart (#416).
            """)
        XCTAssertEqual(code.components(separatedBy: "MIDIImport.addMIDITrack(").count - 1, 1)
    }

    // MARK: - helpers

    /// The member starting at `declaration`, brace-matched (#408) — never a fixed window.
    private func member(_ declaration: String, in code: String) throws -> String {
        guard let start = code.range(of: declaration),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(declaration)` (#454)")
            return ""
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(declaration)`")
        return ""
    }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present at \(url.path) — this claim inspects source text")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
