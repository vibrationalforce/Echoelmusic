// APartRepeatsAsALoopTests.swift
// Echoel — EP-6a (founder 2026-10-15: MIDI clips "entspannt" bearbeiten). Building a loop meant
// pressing Copy once per repetition, each its own Undo step. "Repeat" on the part bar writes N
// copies end to end at once.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (real `TimelineStore`): `repeatRegion(id:times:)` appends N copies
//      end to end on the same lane and clip, and ONE `undo()` removes all of them; 0, a count past
//      `maxRepeats` and an unknown part change nothing.
//   2. SOURCE-TEXT SCAN: the field rests at 0, writes once on commit through `repeatRegion`, and is
//      mounted on the part bar under the beat field.
//
// ⚠️ HONEST GRADING (#433): every claim is FORWARD — `repeatRegion` and the field are created here
// (one absence, #486). Transcribed, no local toolchain (§0).
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: select a one-bar MIDI part, Repeat 3 — four bars
// in a row; one Undo removes the three copies).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class APartRepeatsAsALoopTests: XCTestCase {

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    func testRepeatWritesCopiesEndToEndInOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let bar = TimelineTime.ticksPerBar
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 2 * bar, lengthTicks: bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [part]))

        timeline.repeatRegion(id: part.id, times: 3)
        let regions = timeline.document.regions.sorted { $0.startTick < $1.startTick }
        XCTAssertEqual(regions.map(\.startTick), [2 * bar, 3 * bar, 4 * bar, 5 * bar], "end to end after the part")
        XCTAssertTrue(regions.allSatisfy { $0.laneID == lane.id && $0.clipID == part.clipID && $0.lengthTicks == bar })
        XCTAssertEqual(Set(regions.map(\.id)).count, 4, "every copy has its own identity")

        timeline.undo()
        XCTAssertEqual(timeline.document.regions.map(\.id), [part.id], "one Undo removes all three copies")

        for refused in [0, TimelineStore.maxRepeats + 1] {
            timeline.repeatRegion(id: part.id, times: refused)
            XCTAssertEqual(timeline.document.regions.count, 1, "\(refused) copies is refused")
        }
        timeline.repeatRegion(id: UUID(), times: 2)
        XCTAssertEqual(timeline.document.regions.count, 1, "an unknown part changes nothing")
    }

    func testTheFieldRestsAtZeroAndWritesOnce() throws {
        let code = try source("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertTrue(code.contains("value: Binding(get: { draft ?? 0 }, set: { draft = $0 }),"),
                      "the field rests at 0 — it never claims copies that are not there")
        XCTAssertTrue(code.contains("timeline.repeatRegion(id: part.id, times: Int(times.rounded()))"),
                      "one commit through the store")
        guard let beat = code.range(of: "PartBeatField(part: part)"),
              let repeatField = code.range(of: "PartRepeatField(part: part)", range: beat.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the repeat field under the beat field")
        }
        XCTAssertLessThan(beat.lowerBound, repeatField.lowerBound)
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
