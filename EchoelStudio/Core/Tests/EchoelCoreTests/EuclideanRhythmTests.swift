import XCTest
@testable import EchoelCore

final class EuclideanRhythmTests: XCTestCase {
    private func text(_ hits: Int, _ steps: Int, _ rotation: Int = 0) -> String? {
        StepEditing.euclidean(hits: hits, steps: steps, rotation: rotation).map { String($0.map { $0 ? "x" : "." }) }
    }

    func testTheKnownRhythmsComeOut() {
        XCTAssertEqual(text(3, 8), "x..x..x.", "the tresillo")
        XCTAssertEqual(text(4, 16), "x...x...x...x...", "four on the floor")
        XCTAssertEqual(text(8, 8), "xxxxxxxx")
        XCTAssertEqual(text(0, 8), "........")
        XCTAssertEqual(text(1, 1), "x")
    }

    func testEveryRhythmHasItsHitsAsEvenlyAsTheStepsAllow() {
        for steps in 1...24 {
            for hits in 1...steps {
                guard let pattern = StepEditing.euclidean(hits: hits, steps: steps) else { return XCTFail("\(hits)/\(steps)") }
                XCTAssertEqual(pattern.filter { $0 }.count, hits)
                XCTAssertTrue(pattern[0], "it starts on a hit")
                // The gaps between hits differ by at most one step: the Euclidean property.
                let onsets = pattern.indices.filter { pattern[$0] }
                let gaps = onsets.indices.map { index in
                    (index + 1 < onsets.count ? onsets[index + 1] : onsets[0] + steps) - onsets[index]
                }
                XCTAssertLessThanOrEqual((gaps.max() ?? 0) - (gaps.min() ?? 0), 1, "\(hits) over \(steps)")
            }
        }
    }

    func testRotationTurnsTheCycleEitherWay() {
        XCTAssertEqual(text(3, 8, 1), ".x..x..x")
        XCTAssertEqual(text(3, 8, -1), "..x..x.x")
        XCTAssertEqual(text(3, 8, 9), text(3, 8, 1))
        XCTAssertEqual(text(3, 8, .min), text(3, 8, Int.min % 8))
        XCTAssertNotNil(text(5, 16, .max))
    }

    func testOutOfRangeIsRefused() {
        XCTAssertNil(text(1, 0))
        XCTAssertNil(text(1, 65))
        XCTAssertNil(text(9, 8))
        XCTAssertNil(text(-1, 8))
    }

    func testTheGridFillsOneLaneOverTheClipAndKeepsTheOthers() throws {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Beat", length: 2 * 3_840).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 36, velocity: 100, start: 480, length: 240),
                                    Note(pitch: 38, velocity: 127, start: 960, length: 240)]).apply(to: &project)
        let before = try XCTUnwrap(project.clip(clip))
        let commands = try XCTUnwrap(StepEditing.euclid(in: before, pitch: 36, hits: 5, steps: 16, step: 240))
        for command in commands { try command.apply(to: &project) }
        let after = try XCTUnwrap(project.clip(clip))
        let kicks: [Tick] = after.notes.filter { $0.pitch == 36 }.map(\.start).sorted()
        XCTAssertEqual(kicks.count, 10, "five hits a bar over two bars")
        XCTAssertFalse(kicks.contains(480), "what the lane held is replaced")
        XCTAssertEqual(after.notes.filter { $0.pitch == 38 }.count, 1, "the snare stays")
        XCTAssertNil(StepEditing.euclid(in: after, pitch: 36, hits: 5, steps: 16, step: 240), "the same rhythm again changes nothing")
        XCTAssertNil(StepEditing.euclid(in: after, pitch: 36, hits: 17, steps: 16, step: 240))
    }

    func testRotatingALaneWrapsRoundTheClip() throws {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Beat", length: 3_840).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 36, velocity: 100, start: 0, length: 240),
                                    Note(pitch: 36, velocity: 100, start: 3_600, length: 240),
                                    Note(pitch: 38, velocity: 100, start: 960, length: 240)]).apply(to: &project)
        let command = try XCTUnwrap(StepEditing.rotateLane(in: try XCTUnwrap(project.clip(clip)), pitch: 36, by: 1, step: 240))
        try command.apply(to: &project)
        let rotated = try XCTUnwrap(project.clip(clip))
        let kicks: [Tick] = rotated.notes.filter { $0.pitch == 36 }.map(\.start).sorted()
        XCTAssertEqual(kicks, [0, 240], "the last step wraps to the first")
        XCTAssertEqual(rotated.notes.first { $0.pitch == 38 }?.start, 960)
        XCTAssertNil(StepEditing.rotateLane(in: rotated, pitch: 36, by: 16, step: 240), "a whole cycle changes nothing")
        XCTAssertNil(StepEditing.rotateLane(in: rotated, pitch: 49, by: 1, step: 240))
        _ = StepEditing.rotateLane(in: rotated, pitch: 36, by: .min, step: 240)   // reduced first, no overflow trap
    }
}
