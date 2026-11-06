import EchoelCore
import Foundation
import XCTest
@testable import EchoelKernels

final class VocalStripTests: XCTestCase {
    private let positions: [Float] = [0, 0.25, 0.5, 0.75, 1, -1, 2, .nan, .infinity, -.infinity]

    private func inserts(of chain: VocalChain) -> [Insert] {
        chain.stages.map { (stage: VocalChain.Stage) -> Insert in
            Insert(plugin: stage.effect.component, state: stage.state)
        }
    }

    private func values(_ settings: [VocalChain.Stage.Setting]) -> [String: Float] {
        var values: [String: Float] = [:]
        for setting in settings { values[setting.identifier] = setting.value }
        return values
    }

    func testEveryFaderEndAndEveryStrayPositionStaysInsideTheParameterRanges() {
        for control in VocalStrip.Control.allCases {
            let parameters = EffectKernel.parameters(for: control.effect)
            for position in positions {
                let settings = control.settings(at: position)
                XCTAssertFalse(settings.isEmpty)
                for setting in settings {
                    let parameter = parameters.first { $0.identifier == setting.identifier }
                    XCTAssertNotNil(parameter, "\(control.title): \(control.effect.title) has no \(setting.identifier)")
                    XCTAssertTrue(setting.value.isFinite, "\(control.title) at \(position)")
                    if let parameter {
                        XCTAssertTrue(parameter.range.contains(setting.value),
                                      "\(control.title) at \(position): \(setting.identifier) \(setting.value)")
                    }
                }
            }
            // The ends are where the curve says, and a stray position holds to the nearest end.
            XCTAssertEqual(control.settings(at: -1), control.settings(at: 0))
            XCTAssertEqual(control.settings(at: 2), control.settings(at: 1))
            XCTAssertEqual(control.settings(at: .nan), control.settings(at: 0))
            XCTAssertNotEqual(control.settings(at: 0), control.settings(at: 1), "\(control.title) moves something")
        }
    }

    func testFaderToValuesToFaderComesBackWhereItWas() throws {
        for control in VocalStrip.Control.allCases {
            for step in 0...20 {
                let position = Float(step) / 20
                let settings = values(control.settings(at: position))
                let read = try XCTUnwrap(control.position(from: { settings[$0] }))
                XCTAssertEqual(read, position, accuracy: 1e-4, "\(control.title) at \(position)")
                // And through what an insert stores.
                let state = try XCTUnwrap(StandardEffectSettings.state(settings, for: control.effect))
                let insert = Insert(plugin: control.effect.component, state: state)
                let stored = try XCTUnwrap(control.position(in: insert))
                XCTAssertEqual(stored, position, accuracy: 1e-4, "\(control.title) at \(position), stored")
            }
        }
    }

    func testAFaderShowsNothingForAnUnknownValueAndHoldsAnyOtherInsideItsTravel() {
        for control in VocalStrip.Control.allCases {
            XCTAssertNil(control.position(from: { _ in nil }))
            XCTAssertNil(control.position(from: { _ in Float.nan }))
            XCTAssertNil(control.position(in: Insert(plugin: control.effect.component)))
            for value: Float in [-1_000, -60, 0, 24, 1_000] {
                let shown = control.position(from: { _ in value })
                XCTAssertNotNil(shown)
                if let shown { XCTAssertTrue((0...1).contains(shown), "\(control.title) for \(value)") }
            }
        }
    }

    func testEveryVocalChainGetsAStripThatMovesItsOwnEffects() throws {
        for chain in VocalChain.allCases {
            let chainInserts = inserts(of: chain)
            let strip = try XCTUnwrap(VocalStrip(inserts: chainInserts), chain.title)
            let hasRoom = chain.stages.contains { $0.effect == .reverb }
            let expected: [VocalStrip.Control] = hasRoom ? [.deEss, .level, .air, .space] : [.deEss, .level, .air]
            XCTAssertEqual(strip.faders.map(\.control), expected, chain.title)
            for fader in strip.faders {
                let insert = try XCTUnwrap(chainInserts.first { $0.id == fader.insert })
                XCTAssertEqual(StandardEffect(component: insert.plugin), fader.control.effect, chain.title)
                // The air fader takes the shelf, never the low cut in front.
                if fader.control == .air { XCTAssertNotEqual(insert.id, chainInserts.first?.id) }
                // The fader shows where the chain's own sound is.
                let shown = try XCTUnwrap(fader.control.position(in: insert), "\(chain.title) \(fader.control.title)")
                XCTAssertTrue((0...1).contains(shown))
            }
        }
    }

    func testTheStripFindsTheChainAmongOtherEffectsAndFromTheTrack() throws {
        var chainInserts = inserts(of: .clean)
        chainInserts.insert(Insert(plugin: StandardEffect.chorus.component), at: 2)
        chainInserts.append(Insert(plugin: StandardEffect.delay.component, isBypassed: true))
        let strip = try XCTUnwrap(VocalStrip(inserts: chainInserts))
        XCTAssertEqual(strip.faders.count, VocalStrip.Control.allCases.count)
        for fader in strip.faders {
            let insert = try XCTUnwrap(chainInserts.first { $0.id == fader.insert })
            XCTAssertEqual(StandardEffect(component: insert.plugin), fader.control.effect)
        }
    }

    /// What the page does when a finger lets go: the effect's settings go into the song as one
    /// step. The strip stays on the track, its fader shows the new place, and one undo brings the
    /// old sound and the old place back.
    func testAStoredFaderMoveIsOneUndoStepAndTheStripReadsItBack() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            try store.perform(.addTrack(id: track, name: "Vocal", kind: .audio, index: nil))
            let empty = try XCTUnwrap(store.project.track(track))
            try store.perform(VocalChain.clean.commands(for: empty), title: VocalChain.actionTitle)
            let applied = try XCTUnwrap(store.project.track(track))
            let strip = try XCTUnwrap(VocalStrip(track: applied))
            for fader in strip.faders {
                let effect = fader.control.effect
                let insert = try XCTUnwrap(applied.inserts.first { $0.id == fader.insert })
                let before = try XCTUnwrap(fader.control.position(in: insert))
                // The insert's values by identifier, with the fader's over them.
                let parameters = EffectKernel.parameters(for: effect)
                var values: [String: Float] = [:]
                let original = try XCTUnwrap(insert.state)
                for stored in StandardEffectSettings.values(in: original, for: effect) {
                    if let parameter = parameters.first(where: { $0.address == stored.address }) {
                        values[parameter.identifier] = stored.value
                    }
                }
                let kept = values.count
                for setting in fader.control.settings(at: 0.9) { values[setting.identifier] = setting.value }
                let state = StandardEffectSettings.state(values, for: effect)
                let steps = store.undoStack.count
                try store.perform([.setInsertState(track: track, fader.insert, state)], title: fader.control.actionTitle)
                XCTAssertEqual(store.undoStack.count, steps + 1)
                XCTAssertEqual(store.undoTitle, fader.control.actionTitle)
                let moved = try XCTUnwrap(store.project.track(track))
                XCTAssertEqual(VocalStrip(track: moved), strip, "the strip survives its own move")
                let now = try XCTUnwrap(moved.inserts.first { $0.id == fader.insert })
                XCTAssertEqual(try XCTUnwrap(fader.control.position(in: now)), 0.9, accuracy: 1e-4)
                // The chain's other values of that effect are kept.
                let written = try XCTUnwrap(now.state)
                let stored = StandardEffectSettings.values(in: written, for: effect)
                XCTAssertGreaterThanOrEqual(stored.count, kept)
                store.undo()
                let undone = try XCTUnwrap(store.project.track(track)?.inserts.first { $0.id == fader.insert })
                XCTAssertEqual(try XCTUnwrap(fader.control.position(in: undone)), before, accuracy: 1e-4)
            }
        }
    }

    func testATrackWithoutAVocalChainGetsNoStrip() {
        let none: [[StandardEffect]] = [
            [],
            [.chorus, .delay],
            [.deEsser, .compressor],
            [.equalizer, .deEsser, .compressor],
            // Out of the chain's order: the compressor before the de-esser.
            [.equalizer, .compressor, .deEsser, .equalizer, .reverb],
        ]
        for effects in none {
            let list = effects.map { (effect: StandardEffect) -> Insert in Insert(plugin: effect.component) }
            XCTAssertNil(VocalStrip(inserts: list), "\(effects.map(\.title))")
        }
    }
}
