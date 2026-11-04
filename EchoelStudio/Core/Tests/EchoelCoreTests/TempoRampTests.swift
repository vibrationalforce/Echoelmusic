import Foundation
import XCTest
@testable import EchoelCore

/// Tempo ramps: a change with a `linear` curve is reached by a glide from the tempo before it.
final class TempoRampTests: XCTestCase {
    private let quarter = MusicalTime.ticksPerQuarter
    private let bar = MusicalTime.ticksPerBar(.common)

    /// 120 BPM at 0, gliding to 240 at bar 5 (four bars), then holding.
    private var ramp: TempoMap {
        TempoMap(bpm: 120, changes: [TempoChange(tick: 4 * bar, bpm: 240, curve: .linear)])
    }

    func testALinearChangeGlidesAndArrivesOnItsTick() {
        let map = ramp
        XCTAssertTrue(map.hasRamps)
        XCTAssertEqual(map.bpm(at: 0), 120)
        XCTAssertEqual(map.bpm(at: 2 * bar), 180, accuracy: 1e-9, "halfway in ticks, halfway in tempo")
        XCTAssertEqual(map.bpm(at: 4 * bar), 240)
        XCTAssertEqual(map.bpm(at: 9 * bar), 240, "after the change it holds")
        // ∫ 60 / (ppq · (120 + k·t)) dt over the ramp = 60 / (ppq · k) · ln 2, k = 120 / (4 bars).
        let k = 120 / Double(4 * bar)
        let expected = 60 / (Double(quarter) * k) * Foundation.log(2)
        XCTAssertEqual(map.seconds(at: 4 * bar), expected, accuracy: 1e-9)
        // The same, summed tick by tick at the midpoint tempo of each tick.
        var summed = 0.0
        for tick in 0..<Int(4 * bar) {
            summed += 60 / ((120 + k * (Double(tick) + 0.5)) * Double(quarter))
        }
        XCTAssertEqual(map.seconds(at: 4 * bar), summed, accuracy: 1e-6)
        // Held at 240 after: one quarter is a quarter second.
        XCTAssertEqual(map.seconds(at: 4 * bar + quarter) - map.seconds(at: 4 * bar), 0.25, accuracy: 1e-12)
    }

    func testARitardandoSlowsDownAndStaysContinuous() {
        let map = TempoMap(bpm: 140, changes: [TempoChange(tick: bar, bpm: 140),
                                               TempoChange(tick: 3 * bar, bpm: 70, curve: .linear),
                                               TempoChange(tick: 5 * bar, bpm: 100)])
        XCTAssertEqual(map.segments.map(\.isRamp), [false, true, false, false])
        var previousSeconds = -1.0, previousGap = 0.0
        for tick in stride(from: bar, to: 3 * bar, by: Int(quarter)) {
            let gap = map.seconds(at: tick + quarter) - map.seconds(at: tick)
            XCTAssertGreaterThan(gap, previousGap, "each beat of a ritardando is longer than the one before")
            XCTAssertGreaterThan(map.seconds(at: tick), previousSeconds)
            previousGap = gap
            previousSeconds = map.seconds(at: tick)
        }
        XCTAssertEqual(map.bpm(at: 5 * bar - 1), 70, "a step after the ramp still holds the ramp's arrival")
        XCTAssertEqual(map.bpm(at: 5 * bar), 100)
    }

    func testTicksSecondsAndPositionsRoundTripThroughRamps() {
        let map = TempoMap(bpm: 90, changes: [TempoChange(tick: bar, bpm: 174, curve: .linear),
                                              TempoChange(tick: 3 * bar, bpm: 60, curve: .linear),
                                              TempoChange(tick: 7 * bar, bpm: 73.5)])
        var previous = -1.0
        for tick in stride(from: Tick(0), through: 10 * bar, by: 97) {
            let seconds = map.seconds(at: tick)
            XCTAssertGreaterThan(seconds, previous)
            previous = seconds
            XCTAssertEqual(map.tick(atSeconds: seconds + 1e-9), tick, "\(tick)")
            let position = Double(tick) + 0.37
            XCTAssertEqual(map.position(atSeconds: map.seconds(atPosition: position)), position, accuracy: 1e-6)
        }
    }

    /// A ramp over the whole song at the slowest tempos: past 2^32 samples (about 12 h at 96 kHz),
    /// every sample still maps to the tick sounding on it and back.
    func testTheClockStaysExactPastTwoToTheThirtyTwoSamples() {
        let map = TempoMap(bpm: 20, changes: [TempoChange(tick: MusicalTime.maximumTick, bpm: 30, curve: .linear)])
        let time = TimeConversion(tempoMap: map, sampleRate: 96_000)
        let last = time.sample(at: MusicalTime.maximumTick)
        XCTAssertGreaterThan(last, Int64(1) << 32)
        var previous: Int64 = -1
        for tick in stride(from: MusicalTime.maximumTick - 50 * bar, through: MusicalTime.maximumTick, by: 331) {
            let sample = time.sample(at: tick)
            XCTAssertGreaterThan(sample, previous)
            previous = sample
            // The tick sounding on a sample is the one whose sample it has passed, and not the next.
            let sounding = time.tick(atSample: sample + 1)
            XCTAssertTrue(sounding == tick, "\(tick) → \(sample) → \(sounding)")
            XCTAssertLessThanOrEqual(time.sample(at: sounding), sample + 1)
            XCTAssertGreaterThan(time.sample(at: sounding + 1), sample + 1)
        }
    }

    func testANudgeInARampFallsBetweenItsTicks() {
        let time = TimeConversion(tempoMap: ramp, sampleRate: 48_000)
        for tick in stride(from: Tick(0), to: 4 * bar, by: 503) {
            let nudged = time.sample(at: tick, nudge: 0.5)
            XCTAssertGreaterThanOrEqual(nudged, time.sample(at: tick))
            XCTAssertLessThanOrEqual(nudged, time.sample(at: tick + 1))
            XCTAssertEqual(nudged, MusicalTime.integer((ramp.seconds(atPosition: Double(tick) + 0.5) * 48_000).rounded(.down)))
            XCTAssertEqual(time.sample(at: tick, nudge: 0), time.sample(at: tick))
        }
        XCTAssertEqual(time.samplesPerTick(at: 2 * bar), 48_000 * 60 / (180 * Double(quarter)), accuracy: 1e-9)
    }

    /// A song without ramps converts to exactly the numbers it did before ramps existed.
    func testAStepSongIsBitIdenticalToTheMapBeforeRamps() {
        let map = TempoMap(bpm: 97, changes: [TempoChange(tick: bar, bpm: 131.5), TempoChange(tick: 6 * bar, bpm: 64)])
        XCTAssertFalse(map.hasRamps)
        func old(_ tick: Tick) -> Double {
            // The arithmetic of the map before 2026-11-04, copied.
            let starts: [(Tick, Double, Double)] = [(0, 97, 0),
                                                    (bar, 131.5, Double(bar) * 60 / (97 * Double(quarter)))]
            let third = starts[1].2 + Double(5 * bar) * 60 / (131.5 * Double(quarter))
            let all = starts + [(6 * bar, 64, third)]
            let s = all.last { $0.0 <= tick } ?? all[0]
            return s.2 + Double(tick - s.0) * (60 / (s.1 * Double(quarter)))
        }
        for tick in stride(from: Tick(0), through: 9 * bar, by: 211) {
            XCTAssertEqual(map.seconds(at: tick), old(tick), "\(tick)")
        }
        let time = TimeConversion(tempoMap: map, sampleRate: 48_000)
        for tick in stride(from: Tick(0), through: 9 * bar, by: 211) {
            let seconds = old(tick) + 0.3 * 60 / (map.bpm(at: tick) * Double(quarter))
            XCTAssertEqual(time.sample(at: tick, nudge: 0.3), MusicalTime.integer((seconds * 48_000).rounded(.down)))
        }
    }

    // MARK: - Format

    func testAStepChangeIsWrittenWithoutACurve() throws {
        var project = Project(name: "Steps")
        try Command.setTempoChange(at: bar, bpm: 97).apply(to: &project)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let change = try XCTUnwrap((root["tempoChanges"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(change.keys), ["tick", "bpm"], "a step is stored exactly as before ramps")
    }

    func testALinearChangeSurvivesTheCodecAndAnUnknownCurveIsKeptAsAStep() throws {
        var project = Project(name: "Ramp")
        try Command.setTempoChange(at: bar, bpm: 97).apply(to: &project)
        try Command.setTempoCurve(at: bar, curve: .linear).apply(to: &project)
        let data = try ProjectCodec.encode(project)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let change = try XCTUnwrap((root["tempoChanges"] as? [[String: Any]])?.first)
        XCTAssertEqual(change["curve"] as? String, "linear")
        XCTAssertEqual(try ProjectCodec.decode(data), project)

        // A curve from a later build: the song opens, the name is kept, it plays as a step.
        var json = root
        json["tempoChanges"] = [["tick": bar, "bpm": 97, "curve": "s-shaped"]]
        let later = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(later.tempoChanges.first?.curve, .step)
        XCTAssertEqual(later.tempoChanges.first?.unrecognizedCurve, "s-shaped")
        XCTAssertFalse(later.tempoMap.hasRamps)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(later)) as? [String: Any])
        XCTAssertEqual((saved["tempoChanges"] as? [[String: Any]])?.first?["curve"] as? String, "s-shaped")
    }

    // MARK: - Commands

    func testTheCurveCommandSetsKeepsAndUndoes() async throws {
        var project = Project(tempo: 100)
        try Command.setTempoChange(at: 2 * bar, bpm: 140).apply(to: &project)
        let before = project
        let bar = self.bar
        try await MainActor.run {
            let store = ProjectStore(project: before)
            try store.perform(.setTempoCurve(at: 2 * bar, curve: .linear))
            XCTAssertEqual(store.project.tempoChanges.first?.curve, .linear)
            XCTAssertEqual(store.project.tempoMap.bpm(at: bar), 120, accuracy: 1e-9)
            // A new tempo for the change keeps its ramp.
            try store.perform(.setTempoChange(at: 2 * bar, bpm: 160))
            XCTAssertEqual(store.project.tempoChanges, [TempoChange(tick: 2 * bar, bpm: 160, curve: .linear)])
            XCTAssertEqual(store.undoTitle, "Set Tempo Change")
            store.undo()
            XCTAssertEqual(store.undoTitle, "Set Tempo Curve")
            store.undo()
            XCTAssertEqual(store.project, before)
        }
    }

    func testACurveForNoChangeIsRefusedAndLeavesTheProjectAlone() throws {
        var project = Project()
        try Command.setTempoChange(at: bar, bpm: 130).apply(to: &project)
        let before = project
        XCTAssertThrowsError(try Command.setTempoCurve(at: 2 * bar, curve: .linear).apply(to: &project))
        XCTAssertThrowsError(try Command.setTempoCurve(at: 0, curve: .linear).apply(to: &project))
        XCTAssertEqual(project, before)
        XCTAssertTrue(CommandCatalog.all.map(\.name).contains("tempo.change.curve"))
    }
}
