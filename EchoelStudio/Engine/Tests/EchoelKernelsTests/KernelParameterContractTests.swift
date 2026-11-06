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
            // Choir appended 2026-11-01 (VOX): a wider range keeps every stored index.
            // Pluck (A6), Wavetable and Texture (A10) appended 2026-11-04.
            entry("synth_engine", "Engine", .choice, 0...10, 0,
                  ["Classic", "Supersaw", "FM", "Sub", "Morph", "Mallet", "DDSP", "Choir", "Pluck", "Wavetable", "Texture"]),
            entry("synth_character", "Character", .amount, 0...1, 0.5),
            entry("synth_filter", "Filter", .choice, 0...1, 0, ["Clean", "Ladder"]),
            // Appended 2026-11-01 (W12): the vibrato a route moves with the pulse.
            entry("synth_vibrato", "Vibrato", .amount, 0...1, 0),
            // Appended 2026-11-04 (A2): the bass-line slide and accent.
            entry("synth_slide", "Slide", .seconds, 0...2, 0),
            entry("synth_accent", "Accent", .amount, 0...1, 0),
            // Appended 2026-11-04 (A10): the texture engine's automaton.
            entry("synth_textureRule", "Rule", .choice, 0...7, 0, ["90", "30", "110", "150", "184", "45", "73", "105"]),
            entry("synth_textureDensity", "Density", .amount, 0...1, 0.6),
            entry("synth_textureRate", "Evolve Rate", .hertz, 0...40, 8),
            entry("synth_textureSeed", "Seed", .amount, 0...9_999, 0),
            // Appended 2026-11-06: the DDSP engine's spectral profile.
            entry("synth_ddspProfile", "Profile", .choice, 0...9, 0,
                  ["Character", "Metallic", "Hollow", "Bell", "Flat", "Bowed", "Brass", "Low Bowed", "Reed", "Double Reed"]),
        ])
    }

    func testTheDrumsPublishTheirLevelThenTheirSound() {
        XCTAssertEqual(DrumKernel.parameters, [
            entry("drums_level", "Level", .amount, 0...1, 0.8),
            // Appended 2026-11-04 (EchoelTools A11): the kit's sound.
            entry("drums_kickGlide", "Kick Glide", .amount, 0...4, 1),
            entry("drums_hatModel", "Hats", .choice, 0...1, 0, ["Noise", "Metal"]),
            entry("drums_tomModel", "Toms", .choice, 0...1, 0, ["Sine", "Modal"]),
            entry("drums_kick_tune", "Kick Tune", .amount, -24...24, 0),
            entry("drums_kick_decay", "Kick Decay", .amount, 0.1...4, 1),
            entry("drums_kick_level", "Kick Level", .amount, 0...1, 1),
            entry("drums_snare_tune", "Snare Tune", .amount, -24...24, 0),
            entry("drums_snare_decay", "Snare Decay", .amount, 0.1...4, 1),
            entry("drums_snare_level", "Snare Level", .amount, 0...1, 1),
            entry("drums_clap_tune", "Clap Tune", .amount, -24...24, 0),
            entry("drums_clap_decay", "Clap Decay", .amount, 0.1...4, 1),
            entry("drums_clap_level", "Clap Level", .amount, 0...1, 1),
            entry("drums_lowTom_tune", "Low Tom Tune", .amount, -24...24, 0),
            entry("drums_lowTom_decay", "Low Tom Decay", .amount, 0.1...4, 1),
            entry("drums_lowTom_level", "Low Tom Level", .amount, 0...1, 1),
            entry("drums_highTom_tune", "High Tom Tune", .amount, -24...24, 0),
            entry("drums_highTom_decay", "High Tom Decay", .amount, 0.1...4, 1),
            entry("drums_highTom_level", "High Tom Level", .amount, 0...1, 1),
            entry("drums_closedHat_tune", "Closed Hat Tune", .amount, -24...24, 0),
            entry("drums_closedHat_decay", "Closed Hat Decay", .amount, 0.1...4, 1),
            entry("drums_closedHat_level", "Closed Hat Level", .amount, 0...1, 1),
            entry("drums_openHat_tune", "Open Hat Tune", .amount, -24...24, 0),
            entry("drums_openHat_decay", "Open Hat Decay", .amount, 0.1...4, 1),
            entry("drums_openHat_level", "Open Hat Level", .amount, 0...1, 1),
            entry("drums_crash_tune", "Crash Tune", .amount, -24...24, 0),
            entry("drums_crash_decay", "Crash Decay", .amount, 0.1...4, 1),
            entry("drums_crash_level", "Crash Level", .amount, 0...1, 1),
        ])
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
