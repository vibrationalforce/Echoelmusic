//
//  AWorkingCopyThatCannotBeWrittenSaysSoTests.swift
//  Restructure A1, step 3 (founder 2026-10-04: „Speicherfehler müssen sichtbar ankommen; ein
//  fehlgeschlagenes Sichern darf keinen stillen Projektverlust verursachen.")
//
//  The working copy of the piece — the song document (`TimelineStore`) and the clip grid
//  (`ClipStore`) — is written after every edit. `AppGroupStore.save` answers whether the write
//  reached the disk, and #514 measured that no call site read the answer: a failed write looked
//  saved for the rest of the session and the OLDER file came back on the next launch. Both stores
//  now record the outcome, and `WorkingCopyStatusView` shows it with "Write again".
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `TimelineStore`, `ClipStore`, `TimelineDocument` and
//    `Clip` are shipped. A NaN makes `JSONEncoder` throw (#512), which is a REAL failed write, not
//    a mock. Both claims restore the stores they touch.
//  · SOURCE-TEXT SCAN (claims 3–4) — `WorkingCopyStatusView` and `WorkspaceView` are `View`s.
//  · DEVICE PROBE, OPEN — that the notice reads well and "Write again" clears it after storage is
//    freed. A full disk cannot be produced here.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `workingCopyNotWritten`, `gridNotWritten` and `retryWrite()`, created by this commit — so no
//  assertion has a verdict on the parent (ONE absence, #486). Claims 1–2 are FORWARD guards,
//  transcribed by reading `persist`/`flushPendingSave`/`recordWrite`; claims 3–4's needles were
//  grepped against the worktree.
//  COUNTERWEIGHTS (#343): the premise halves of claims 1–2 (a finite song / grid writes and the
//  flag stays down) and claim 4 (the root body does not read the flags itself).
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AWorkingCopyThatCannotBeWrittenSaysSoTests: XCTestCase {

    private static let notice = "Sources/Echoelmusic/Studio/WorkingCopyStatusView.swift"
    private static let root = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let timelineStore = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let clipStore = "Sources/Echoelmusic/Core/ClipStore.swift"

    // MARK: 1 — a song that cannot be written raises the flag; the next clean write lowers it

    func testASongThatCannotBeWrittenRaisesTheFlag() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Good", kind: .audio)], regions: []))
        XCTAssertFalse(timeline.workingCopyNotWritten, "premise: a finite song writes")

        var lane = TimelineLane(name: "Broken", kind: .audio)
        lane.level = .nan
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: []))
        XCTAssertTrue(timeline.workingCopyNotWritten, """
            A song that could not be written left `workingCopyNotWritten` down. The write's answer \
            was dropped again, and the older file would come back on the next launch unannounced. \
            (Premise: a NaN lane level makes JSONEncoder throw, #512.)
            """)

        XCTAssertFalse(timeline.flushPendingSave(), "a retry of the same broken song cannot succeed")

        timeline.replaceDocument(original)
        XCTAssertFalse(timeline.workingCopyNotWritten,
                       "the next clean write must lower the flag — any edit, not only \"Write again\"")
    }

    // MARK: 2 — a clip grid that cannot be written raises its flag; the next clean write lowers it

    func testAGridThatCannotBeWrittenRaisesTheFlag() {
        let clips = ClipStore()
        let original = clips.slots
        defer { clips.replaceSlots(original) }

        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        XCTAssertFalse(clips.gridNotWritten, "premise: an empty grid writes")

        clips.setClip(at: 0, Clip(name: "Broken", kind: .audio, nativeDurationSeconds: .nan))
        XCTAssertTrue(clips.gridNotWritten, """
            A clip grid that could not be written left `gridNotWritten` down. (Premise: a NaN \
            duration makes JSONEncoder throw; if the clip type starts sanitising it, this claim \
            needs a new failure, not a weaker assertion.)
            """)
        XCTAssertFalse(clips.retryWrite(), "a retry of the same broken grid cannot succeed")

        clips.clear(at: 0)
        XCTAssertFalse(clips.gridNotWritten, "the next clean write must lower the flag")
        XCTAssertTrue(clips.retryWrite(), "COUNTERWEIGHT: \"Write again\" on a clean grid reports success")
    }

    // MARK: 3 — the notice reads both flags and its button writes both stores

    func testTheNoticeReadsBothStoresAndWritesBothAgain() throws {
        let code = SourceText.codeOnly(try text(Self.notice))
        for needle in ["@Environment(TimelineStore.self) private var timeline",
                       "@Environment(ClipStore.self) private var clips",
                       "if timeline.workingCopyNotWritten || clips.gridNotWritten {",
                       "Button(\"Write again\") {",
                       "timeline.flushPendingSave()",
                       "clips.retryWrite()",
                       ".frame(minHeight: 44)"] {
            XCTAssertTrue(code.contains(needle), "`WorkingCopyStatusView` lost `\(needle)`")
        }
        XCTAssertTrue(SourceText.codeOnly(try text(Self.root)).contains("WorkingCopyStatusView()"),
                      "the root no longer mounts the notice — a failed write would be silent again")

        let timelineCode = SourceText.codeOnly(try text(Self.timelineStore))
        XCTAssertTrue(timelineCode.contains("self.recordWrite(self.store.save(snapshot, name: Self.fileName))"),
                      "the debounced song write no longer records its answer")
        XCTAssertFalse(timelineCode.contains("_ = self.store.save(") || timelineCode.contains("_ = store.save("),
                       "`TimelineStore` discards a write's answer again (#514)")
        XCTAssertTrue(SourceText.codeOnly(try text(Self.clipStore))
                        .contains("let written = store.save(Self.storedGrid(slots), name: Self.fileName)"),
                      "the clip grid write no longer records its answer")
    }

    // MARK: 4 — COUNTERWEIGHT: the root body does not read the flags itself (leaf law)

    func testTheRootDoesNotReadTheFlags() throws {
        let code = SourceText.codeOnly(try text(Self.root))
        for flag in ["workingCopyNotWritten", "gridNotWritten"] {
            XCTAssertFalse(code.contains(flag), """
                `WorkspaceView` reads `\(flag)` itself. The read belongs in the leaf — the root \
                hosts every surface below it (10.76.41/50 law).
                """)
        }
    }

    // MARK: - helpers

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
