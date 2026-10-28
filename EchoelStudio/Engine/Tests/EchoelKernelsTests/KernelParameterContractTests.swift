import EchoelCore
import XCTest
@testable import EchoelKernels

/// What a host stores for an Echoel instrument: automation and presets keyed by each parameter's
/// identifier and by its address, which is its index. The lists are written out here on purpose
/// — a rename, a new range or a reordering is a break for every saved host session, so it has to
/// show up as a failing line, not pass because both sides were derived from the same table.
final class KernelParameterContractTests: XCTestCase {
    private func entry(_ identifier: String, _ title: String, _ unit: ParameterUnit, _ range: ClosedRange<Double>,
                       _ defaultValue: Double, _ choices: [String] = []) -> InstrumentKernelParameter {
        InstrumentKernelParameter(identifier: identifier, title: title, unit: unit, range: range,
                                  defaultValue: defaultValue, choices: choices)
    }

    func testTheSynthPublishesItsParametersInTheirHostOrder() {
        XCTAssertEqual(SynthKernel.parameters, [
            entry("synth_waveform", "Waveform", .choice, 0...3, 1, ["Sine", "Saw", "Square", "Triangle"]),
            entry("synth_cutoff", "Cutoff", .hertz, 20...18_000, 800),
            entry("synth_resonance", "Resonance", .amount, 0...0.95, 0.3),
            entry("synth_filterAmount", "Filter Envelope", .octaves, 0...8, 3),
            entry("synth_filterDecay", "Filter Decay", .seconds, 0.001...10, 0.3),
            entry("synth_attack", "Attack", .seconds, 0.001...10, 0.003),
            entry("synth_decay", "Decay", .seconds, 0.001...10, 0.2),
            entry("synth_sustain", "Sustain", .amount, 0...1, 0.7),
            entry("synth_release", "Release", .seconds, 0.001...10, 0.25),
            entry("synth_level", "Level", .amount, 0...1, 0.25),
            // Appended 2026-10-28: new values join at the end, so every earlier address holds.
            entry("synth_engine", "Engine", .choice, 0...4, 0, ["Classic", "Supersaw", "FM", "Sub", "Morph"]),
            entry("synth_character", "Character", .amount, 0...1, 0.5),
            entry("synth_filter", "Filter", .choice, 0...1, 0, ["Clean", "Ladder"]),
        ])
    }

    func testTheDrumsPublishTheirLevel() {
        XCTAssertEqual(DrumKernel.parameters, [entry("drums_level", "Level", .amount, 0...1, 0.8)])
    }

    func testTheSamplerPublishesItsParametersInTheirHostOrder() {
        XCTAssertEqual(SamplerKernel.parameters, [
            entry("sampler_root", "Root key", .amount, 0...127, 60),
            entry("sampler_attack", "Attack", .seconds, 0.001...2, 0.001),
            entry("sampler_release", "Release", .seconds, 0.01...5, 0.15),
            entry("sampler_level", "Level", .amount, 0...1, 0.8),
            entry("sampler_mode", "Mode", .choice, 0...1, 0, ["Gate", "One-shot"]),
        ])
    }
}
