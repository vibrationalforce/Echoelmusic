import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelKernels

final class MasterAssistantTests: XCTestCase {
    private let rate = 48_000.0

    /// Deterministic noise, one-pole low-passed so it tilts down like a mix, at `amplitude`.
    private func mix(seconds: Double = 4, amplitude: Float, seed: UInt32, smoothing: Float = 0.6) -> [Float] {
        var state = seed
        var held: Float = 0
        return (0..<Int(rate * seconds)).map { (_: Int) -> Float in
            state = state &* 1_664_525 &+ 1_013_904_223
            let unit: Float = Float(state >> 8) / Float(1 << 24) * 2 - 1
            held = held * smoothing + unit * (1 - smoothing)
            return held * amplitude
        }
    }

    private func analyse(_ left: [Float], _ right: [Float]) -> MixAnalysis {
        var analyzer = MixAnalyzer(sampleRate: rate)
        left.withUnsafeBufferPointer { l in
            right.withUnsafeBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                analyzer.process(left: a, right: b, count: l.count)
            }
        }
        return analyzer.analysis
    }

    /// Runs `stages` as the engine would: each insert's kernel at the values its state carries.
    private func play(_ stages: [MasterSuggestion.Stage], _ left: [Float], _ right: [Float]) -> (left: [Float], right: [Float]) {
        var l = left, r = right
        for stage in stages {
            let kernel = EffectKernel(effect: stage.effect, sampleRate: rate)
            for setting in StandardEffectSettings.values(in: stage.state ?? Data(), for: stage.effect) {
                kernel.setParameter(setting.address, setting.value)
            }
            l.withUnsafeMutableBufferPointer { a in
                r.withUnsafeMutableBufferPointer { b in
                    guard let x = a.baseAddress, let y = b.baseAddress else { return }
                    var done = 0
                    while done < a.count {
                        let n = Swift.min(512, a.count - done)
                        kernel.process(left: x + done, right: y + done, frames: n)
                        done += n
                    }
                }
            }
        }
        return (l, r)
    }

    private func setting(_ suggestion: MasterSuggestion, _ effect: StandardEffect, _ identifier: String) -> Float? {
        suggestion.stages.first { $0.effect == effect }?.values.first { $0.identifier == identifier }?.value
    }

    func testASilentMixHasNoSuggestion() {
        let quiet = [Float](repeating: 0, count: 48_000)
        XCTAssertNil(MasterAssistant.suggest(from: analyse(quiet, quiet), target: .streaming))
    }

    func testEveryValueCarriesAReasonAndAnInRangeNumber() throws {
        let left = mix(amplitude: 0.05, seed: 1), right = mix(amplitude: 0.05, seed: 2)
        let suggestion = try XCTUnwrap(MasterAssistant.suggest(from: analyse(left, right), target: .streaming))
        XCTAssertEqual(suggestion.stages.map(\.effect).first, .equalizer)
        XCTAssertEqual(suggestion.stages.map(\.effect).last, .limiter, "the limiter ends the chain")
        for stage in suggestion.stages {
            let parameters = EffectKernel.parameters(for: stage.effect)
            for value in stage.values {
                let parameter = try XCTUnwrap(parameters.first { $0.identifier == value.identifier })
                XCTAssertTrue(parameter.range.contains(value.value), "\(stage.effect) \(value.identifier)")
                XCTAssertFalse(value.reason.isEmpty)
                XCTAssertNil(value.reason.range(of: "\\b(AI|KI)\\b", options: .regularExpression), "no model runs here")
            }
        }
        XCTAssertEqual(setting(suggestion, .limiter, "ceiling"), Float(ExportLoudness.truePeakCeiling))
    }

    func testTheSameMixGivesTheSameChain() {
        let left = mix(amplitude: 0.05, seed: 3), right = mix(amplitude: 0.05, seed: 4)
        let report = analyse(left, right)
        XCTAssertEqual(MasterAssistant.suggest(from: report, target: .podcast, tone: .warm),
                       MasterAssistant.suggest(from: report, target: .podcast, tone: .warm))
    }

    /// The measured chain brings a quiet mix near the target and keeps the peak under the ceiling.
    func testTheChainBringsAQuietMixTowardTheTargetUnderTheCeiling() throws {
        let left = mix(amplitude: 0.05, seed: 5), right = mix(amplitude: 0.05, seed: 6)
        let before = analyse(left, right)
        let suggestion = try XCTUnwrap(MasterAssistant.suggest(from: before, target: .streaming))
        let gain = try XCTUnwrap(setting(suggestion, .limiter, "gain"))
        XCTAssertEqual(Double(gain), MasterAssistant.halfDecibel(-14 - before.integratedLoudness), accuracy: 0.01)
        let out = play(suggestion.stages, left, right)
        let after = analyse(out.left, out.right)
        XCTAssertLessThan(Swift.abs(after.integratedLoudness - -14), Swift.abs(before.integratedLoudness - -14),
                          "closer to the target than before")
        XCTAssertEqual(after.integratedLoudness, -14, accuracy: 3)
        XCTAssertLessThanOrEqual(after.truePeak, ExportLoudness.truePeakCeiling + 0.5)
    }

    func testALoudMixLowersTheFaderInsteadOfTheLimiter() throws {
        let left = mix(amplitude: 0.9, seed: 7, smoothing: 0), right = mix(amplitude: 0.9, seed: 8, smoothing: 0)
        let report = analyse(left, right)
        XCTAssertGreaterThan(report.integratedLoudness, -14)
        let suggestion = try XCTUnwrap(MasterAssistant.suggest(from: report, target: .streaming, masterVolume: -2))
        XCTAssertEqual(setting(suggestion, .limiter, "gain"), 0)
        let fader = try XCTUnwrap(suggestion.masterVolume)
        XCTAssertEqual(fader, MasterAssistant.halfDecibel(-2 + (-14 - report.integratedLoudness)), accuracy: 0.01)
        XCTAssertNotNil(suggestion.masterVolumeReason)
    }

    /// A mix far brighter than the reference gets darker shelves, within the shelf limit.
    func testABrightMixTiltsDarker() throws {
        let left = mix(amplitude: 0.05, seed: 9, smoothing: 0), right = mix(amplitude: 0.05, seed: 10, smoothing: 0)
        let report = analyse(left, right)
        XCTAssertGreaterThan(report.tilt ?? 0, 2, "white noise rises")
        let suggestion = try XCTUnwrap(MasterAssistant.suggest(from: report, target: .streaming, tone: .transparent))
        XCTAssertEqual(setting(suggestion, .equalizer, "lowGain"), Float(MasterAssistant.maximumTiltShelf))
        XCTAssertEqual(setting(suggestion, .equalizer, "highGain"), Float(-MasterAssistant.maximumTiltShelf))
        XCTAssertEqual(setting(suggestion, .equalizer, "highMidGain"), 0, "transparent adds no presence")
    }

    func testTheTonesAreTheEarlierAppsCurvesOnTopOfTheTilt() throws {
        let left = mix(amplitude: 0.05, seed: 11), right = mix(amplitude: 0.05, seed: 12)
        let report = analyse(left, right)
        let flat = try XCTUnwrap(MasterAssistant.suggest(from: report, target: .streaming, tone: .transparent))
        for tone in MasterTone.allCases {
            let toned = try XCTUnwrap(MasterAssistant.suggest(from: report, target: .streaming, tone: tone))
            let gains = tone.gains
            for (identifier, offset) in [("lowGain", gains.low), ("highMidGain", gains.presence), ("highGain", gains.air)] {
                let difference = Double((setting(toned, .equalizer, identifier) ?? 0) - (setting(flat, .equalizer, identifier) ?? 0))
                XCTAssertEqual(difference, offset, accuracy: 0.001, "\(tone) \(identifier)")
            }
        }
        XCTAssertEqual(MasterTone.allCases.map(\.rawValue), ["balanced", "warm", "bright", "transparent"],
                       "the device keeps these names; a new tone goes at the end")
        XCTAssertEqual(Set(MasterTone.allCases.map { "\($0.gains)" }).count, MasterTone.allCases.count, "no two alike")
    }

    func testAWideLowEndIsMadeMonoAndAMonoMixIsLeftAlone() throws {
        let left = mix(amplitude: 0.05, seed: 13), right = mix(amplitude: 0.05, seed: 14)
        let wide = try XCTUnwrap(MasterAssistant.suggest(from: analyse(left, right), target: .streaming))
        XCTAssertEqual(setting(wide, .midSide, "monoBelow"), 120)
        let mono = try XCTUnwrap(MasterAssistant.suggest(from: analyse(left, left), target: .streaming))
        XCTAssertFalse(mono.stages.contains { $0.effect == .midSide })
        XCTAssertTrue(mono.notes.contains { $0.hasPrefix("Stereo image left alone") })
    }

    func testTheStateCarriesTheValuesByIdentifier() throws {
        let data = try XCTUnwrap(StandardEffectSettings.state(["gain": 6, "ceiling": -1, "nonsense": 3, "release": .nan],
                                                             for: .limiter))
        let values = StandardEffectSettings.values(in: data, for: .limiter)
        XCTAssertEqual(values.map(\.address), [0, 1], "unknown and non-finite values are dropped")
        XCTAssertEqual(values.map(\.value), [6, -1])
        let clamped = try XCTUnwrap(StandardEffectSettings.state(["gain": 99], for: .limiter))
        XCTAssertEqual(StandardEffectSettings.values(in: clamped, for: .limiter).first?.value, 24)
        XCTAssertTrue(StandardEffectSettings.values(in: Data([1, 2, 3]), for: .limiter).isEmpty)
    }

    func testApplyingIsOneUndoStepThatReplacesTheMastersEffects() async throws {
        let left = mix(amplitude: 0.05, seed: 15), right = mix(amplitude: 0.05, seed: 16)
        let suggestion = try XCTUnwrap(MasterAssistant.suggest(from: analyse(left, right), target: .broadcast))
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.addMasterInsert(id: InsertID(), plugin: StandardEffect.reverb.component, index: nil))
            let before = store.project
            let steps = store.undoStack.count
            try store.perform(suggestion.commands(for: store.project), title: MasterSuggestion.actionTitle)
            XCTAssertEqual(store.undoStack.count, steps + 1)
            XCTAssertEqual(store.undoTitle, MasterSuggestion.actionTitle)
            XCTAssertEqual(store.project.masterInserts.map(\.plugin), suggestion.stages.map(\.effect.component))
            for (insert, stage) in zip(store.project.masterInserts, suggestion.stages) {
                XCTAssertEqual(insert.state, stage.state)
                XCTAssertFalse(insert.isBypassed)
            }
            XCTAssertNoThrow(try store.project.validate())
            store.undo()
            XCTAssertEqual(store.project, before)
        }
    }
}
