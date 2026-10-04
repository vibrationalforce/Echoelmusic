//
//  ThePieceCarriesItsLightLookTests.swift
//  Restructure P2 (founder 2026-10-04, wörtlich: „Speichere lookIntensity als kreativen Zustand
//  des Stücks über den bestehenden Projektpfad. Prüfe Speichern, Wiederöffnen und den Wechsel
//  zwischen zwei Stücken mit unterschiedlichen Looks. Ältere Projekte erhalten einen definierten
//  Standardwert. Die Änderung folgt dem vorhandenen Bearbeitungs- und Undo-Vertrag.")
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–4) — `TimelineDocument` and `TimelineStore` are shipped,
//    Foundation-only types this bundle can drive: the JSON round trip the save path writes,
//    the legacy document without the key, a switch between two pieces through
//    `replaceDocument` (the Open path), and the edit/commit/undo/redo contract.
//  · SOURCE-TEXT SCAN (claims 5–6) — the projection hook in `EchoelmusicApp` and the field on
//    the Project plate. `WorkstationView.projectPlate` is `private` on a `View` and the app
//    wiring runs at launch; neither can be instantiated here.
//  · DEVICE PROBE, OPEN — that a fixture on Art-Net or sACN actually dims when the field goes
//    down, fades rather than jumps, and that a second piece opens at its own look. Marked
//    NEEDS-FOUNDER-VERIFY in `Studio/PieceLightLookField.swift`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `TimelineDocument.lightLookIntensity`, `TimelineStore.lightLook`, `editLightLook` and
//  `commitLightLook`, all created by this commit — so no assertion has a verdict on the
//  parent. All six claims are FORWARD guards; booking them as regressions would be the
//  flattering direction (#486: one absence, reported once). Claims 5–6 were transcribed in
//  Python against both trees: absent on the parent (the needles do not exist), present here.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePieceCarriesItsLightLookTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let plate = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let field = "Sources/Echoelmusic/Studio/PieceLightLookField.swift"

    // MARK: 1 — the look survives the save path's JSON, both ways

    func testTheLookSurvivesTheSavePathsRoundTrip() throws {
        var doc = TimelineDocument()
        doc.lightLookIntensity = 0.25
        let data = try JSONEncoder().encode(doc)
        let back = try JSONDecoder().decode(TimelineDocument.self, from: data)
        XCTAssertEqual(back.lightLookIntensity, 0.25, """
            A piece saved at look 0.25 reopened at \(String(describing: back.lightLookIntensity)). \
            The field is in `CodingKeys`, the lossy decoder AND the hand-written encoder — a new \
            field has to be in all three, and one of them lost it.
            """)
    }

    // MARK: 2 — an older piece, written before the key existed, plays at the defined default

    func testALegacyPieceWithoutTheKeyPlaysAtTheDefault() throws {
        // `encodeIfPresent` leaves the key out for nil — exactly the bytes a pre-P2 build wrote.
        let legacy = try JSONEncoder().encode(TimelineDocument())
        let text = String(decoding: legacy, as: UTF8.self)
        XCTAssertFalse(text.contains("lightLookIntensity"), """
            A never-set look wrote the key anyway. Write it with `encodeIfPresent`, so a piece \
            that never touched the light stays byte-compatible with older builds.
            """)
        let decoded = try JSONDecoder().decode(TimelineDocument.self, from: legacy)
        XCTAssertNil(decoded.lightLookIntensity, "a missing key must decode as 'never set', not as a value")

        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(decoded)
        XCTAssertEqual(timeline.lightLook, LightingStore.defaultLookIntensity, """
            An older piece opened at look \(timeline.lightLook), not at \
            `LightingStore.defaultLookIntensity`. The founder's rule: older pieces get a DEFINED \
            standard value — the one the rig had before the look existed.
            """)
    }

    // MARK: 3 — two pieces, two looks: an Open brings each piece's own look, and no history

    func testSwitchingBetweenTwoPiecesBringsEachPiecesOwnLook() {
        var dim = TimelineDocument()
        dim.lightLookIntensity = 0.2
        var bright = TimelineDocument()
        bright.lightLookIntensity = 0.9

        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        timeline.replaceDocument(dim)
        XCTAssertEqual(timeline.lightLook, 0.2, accuracy: 1e-6)
        timeline.editLightLook(0.5)
        timeline.commitLightLook()
        XCTAssertTrue(timeline.canUndo, "the edit on the first piece is one Undo step")

        timeline.replaceDocument(bright)
        XCTAssertEqual(timeline.lightLook, 0.9, accuracy: 1e-6, """
            The second piece opened at the first piece's look. Each piece carries its own.
            """)
        XCTAssertFalse(timeline.canUndo, """
            The first piece's look edit survived the Open. An Undo now would write 0.2 into the \
            second piece — `replaceDocument` clears the history AND the open look edit.
            """)
        // A late commit from a gesture that began on the first piece adds nothing to the second.
        timeline.commitLightLook()
        XCTAssertFalse(timeline.canUndo, "an edit opened on the previous piece must not commit into this one")

        timeline.replaceDocument(dim)
        XCTAssertEqual(timeline.lightLook, 0.2, accuracy: 1e-6, "back to the first piece, back to its look")
    }

    // MARK: 4 — the editing and Undo contract: one gesture, one step, and Undo respects later writes

    func testOneGestureIsOneUndoStepAndUndoLeavesALaterWriteAlone() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(TimelineDocument())
        XCTAssertFalse(timeline.canUndo)

        // A drag: three samples, one commit.
        for sample: Float in [0.8, 0.6, 0.4] { timeline.editLightLook(sample) }
        timeline.commitLightLook()
        XCTAssertEqual(timeline.lightLook, 0.4, accuracy: 1e-6)
        timeline.undo()
        XCTAssertEqual(timeline.lightLook, LightingStore.defaultLookIntensity, """
            One Undo did not take the whole drag back to where it began. Every drag sample \
            calls `editLightLook`; only `commitLightLook` pushes, so one gesture is one step.
            """)
        XCTAssertNil(timeline.document.lightLookIntensity, "undoing the first edit restores 'never set', not a copied 1.0")
        XCTAssertFalse(timeline.canUndo, "one gesture, one step")
        timeline.redo()
        XCTAssertEqual(timeline.lightLook, 0.4, accuracy: 1e-6, "Redo puts the gesture back")

        // A commit with no net change records nothing (the mixer's rule).
        timeline.editLightLook(0.4)
        timeline.commitLightLook()
        timeline.undo()
        XCTAssertEqual(timeline.lightLook, LightingStore.defaultLookIntensity,
                       "a no-op gesture added a step: the Undo above took back the real one instead")

        // Undo leaves a value written SINCE the step alone (the store's "after" rule).
        timeline.redo()
        timeline.setLightLook(0.7)
        timeline.undo()
        XCTAssertEqual(timeline.lightLook, 0.7, accuracy: 1e-6, """
            Undo overwrote a look written after the step. A step restores its value only while \
            the field still reads the step's 'after' — the contract every `HistoryStep` keeps.
            """)

        // Out-of-range and non-finite input is sanitised at the store, never stored raw.
        timeline.setLightLook(.nan)
        XCTAssertTrue(timeline.lightLook.isFinite)
        timeline.setLightLook(4)
        XCTAssertLessThanOrEqual(timeline.lightLook, 1)
    }

    // MARK: 5 — the document reaches the rig through the ONE canonical road

    func testTheAppProjectsTheDocumentThroughTheCanonicalParameter() throws {
        let app = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(app.contains("timelineStore?.lightLook"), """
            `EchoelmusicApp` no longer reads the piece's look. Without the projection, the field \
            saves a value the rig never sees.
            """)
        XCTAssertTrue(app.contains("applyReal(LightingParameterCatalog.lookIntensity, look)"), """
            The projection must go through `parameterRouter.applyReal(LightingParameterCatalog \
            .lookIntensity, …)` — the one bind is the only `setLookIntensity` caller \
            (`TheLightingLookIsACanonicalParameterTests` claim 7). A direct call would be a \
            second road to the same value.
            """)
        XCTAssertTrue(app.contains("projectLightLook()"), "the projection is applied once at launch, before any edit")
        XCTAssertTrue(app.contains("previousLookHook?()"), """
            `onDocumentChanged` is ONE slot. The look hook must CHAIN the hook installed before \
            it, or it silently replaces it — and whatever that hook did stops happening.
            """)
    }

    // MARK: 6 — the door: on the Project plate, writing the document, never the owner

    func testTheFieldSitsOnTheProjectPlateAndWritesTheDocument() throws {
        let plate = SourceText.codeOnly(try text(Self.plate))
        guard let start = plate.range(of: "private var projectPlate: some View") else {
            XCTFail("`projectPlate` is gone from `WorkstationView` — re-anchor this claim on the plate's new home")
            return
        }
        let body = String(plate[start.upperBound...].prefix(1200))
        XCTAssertTrue(body.contains("PieceLightLookField()"), "the light-look field left the Project plate — it has no other door")

        let field = SourceText.codeOnly(try text(Self.field))
        XCTAssertTrue(field.contains("timeline.editLightLook("), "the field must edit the DOCUMENT")
        XCTAssertTrue(field.contains("timeline.commitLightLook()"), "the field must commit once per gesture")
        XCTAssertTrue(field.contains("EchoelValueField("), "a numeric parameter row is an `EchoelValueField` (CLAUDE.md, Uncodixfy)")
        XCTAssertFalse(field.contains("setLookIntensity"), """
            The field writes the lighting owner directly. It must write the piece; the app \
            projects the piece into the owner, so Undo and Open reach the rig by the same road.
            """)
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
