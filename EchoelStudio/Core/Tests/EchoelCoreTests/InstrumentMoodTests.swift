import XCTest
@testable import EchoelCore

/// The Instrument page's two picks (W12): Sound — a preset on an engine — and Mood — a few of the
/// synth's own values under a name. Each keeps the other.
final class InstrumentMoodTests: XCTestCase {
    private func apply(_ commands: [Command], to project: inout Project) throws {
        for command in commands { try command.apply(to: &project) }
    }

    func testAMoodSetsTheColourWithinRangeAndNeverTheEnvelopeOrTheEngine() {
        let colour: Set<SynthParameter> = [.cutoff, .resonance, .character, .filter]
        XCTAssertEqual(Set(InstrumentMood.all.map(\.name)).count, InstrumentMood.all.count, "every mood has its own name")
        for mood in InstrumentMood.all {
            XCTAssertEqual(Set(mood.values.keys), colour, mood.name)
            for (parameter, value) in mood.values {
                XCTAssertTrue(parameter.accepts(value), "\(mood.name) \(parameter.title) \(value)")
            }
        }
    }

    func testAChosenMoodIsTheCurrentOneAndAPresetsOwnSoundIsNone() throws {
        var project = try StarterProject.empty.project()
        let id = try XCTUnwrap(project.tracks.first).id
        XCTAssertNil(InstrumentMood.current(of: try XCTUnwrap(project.track(id)).instrument))
        for mood in InstrumentMood.all {
            try apply(mood.commands(for: id), to: &project)
            let instrument = try XCTUnwrap(project.track(id)).instrument
            XCTAssertEqual(InstrumentMood.current(of: instrument), mood)
        }
        for preset in InstrumentPreset.all {
            XCTAssertNil(InstrumentMood.current(of: InstrumentSettings(values: preset.values)), preset.name)
        }
    }

    func testChoosingAPresetKeepsTheEngineAndTheMood() throws {
        var project = try StarterProject.empty.project()
        let id = try XCTUnwrap(project.tracks.first).id
        let dark = try XCTUnwrap(InstrumentMood.all.first { $0.name == "Dark" })
        try apply(InstrumentSound.choosing(engine: 6, on: id) + dark.commands(for: id), to: &project)
        let dressed = try XCTUnwrap(project.track(id))
        try apply(InstrumentSound.choosing(preset: "Pluck", on: dressed), to: &project)
        let instrument = try XCTUnwrap(project.track(id)).instrument
        XCTAssertEqual(instrument.preset, "Pluck")
        XCTAssertEqual(instrument.value(.engine), 6, "the engine stays")
        XCTAssertEqual(InstrumentMood.current(of: instrument), dark, "the mood stays")
        let pluck = InstrumentSettings(values: try XCTUnwrap(InstrumentPreset.named("Pluck")).values)
        for parameter in [SynthParameter.attack, .decay, .sustain, .release, .waveform, .filterAmount, .filterDecay, .level] {
            XCTAssertEqual(instrument.value(parameter), pluck.value(parameter), "the pluck stays a pluck: \(parameter.title)")
        }
        try apply(InstrumentSound.choosing(engine: 2, on: id), to: &project)
        let after = try XCTUnwrap(project.track(id)).instrument
        XCTAssertEqual(after.value(.engine), 2)
        XCTAssertEqual(after.preset, "Pluck")
        XCTAssertEqual(InstrumentMood.current(of: after), dark)
    }
}
