import EchoelCore
import Foundation
import XCTest
@testable import EchoelKernels

final class VocalChainTests: XCTestCase {
    func testEverySettingNamesAParameterOfItsEffectWithinItsRange() {
        for chain in VocalChain.allCases {
            for stage in chain.stages {
                let parameters = EffectKernel.parameters(for: stage.effect)
                for setting in stage.settings {
                    let parameter = parameters.first { $0.identifier == setting.identifier }
                    XCTAssertNotNil(parameter, "\(chain.title): \(stage.effect.title) has no \(setting.identifier)")
                    if let parameter {
                        XCTAssertTrue(parameter.range.contains(setting.value),
                                      "\(chain.title): \(setting.identifier) \(setting.value) outside \(parameter.range)")
                    }
                }
                XCTAssertEqual(Set(stage.settings.map(\.identifier)).count, stage.settings.count,
                               "\(chain.title): no identifier twice in one stage")
            }
        }
    }

    func testTheStoredStateCarriesEverySettingUnclamped() throws {
        for chain in VocalChain.allCases {
            for stage in chain.stages {
                let data = try XCTUnwrap(stage.state)
                let stored = StandardEffectSettings.values(in: data, for: stage.effect)
                XCTAssertEqual(stored.count, stage.settings.count, "\(chain.title): nothing dropped")
                let parameters = EffectKernel.parameters(for: stage.effect)
                for setting in stage.settings {
                    let address = parameters.first { $0.identifier == setting.identifier }?.address
                    XCTAssertEqual(stored.first { $0.address == address }?.value, setting.value)
                }
            }
        }
    }

    func testEveryChainFitsATrackAndUsesOnlyStandardEffects() {
        XCTAssertGreaterThanOrEqual(VocalChain.allCases.count, 3)
        for chain in VocalChain.allCases {
            XCTAssertFalse(chain.stages.isEmpty)
            XCTAssertLessThanOrEqual(chain.stages.count, Insert.maximumPerTrack)
            XCTAssertTrue(chain.stages.contains { $0.effect == .deEsser }, "\(chain.title) tames sibilance")
            XCTAssertEqual(chain.stages.first?.effect, .equalizer, "\(chain.title) cuts the lows first")
            XCTAssertTrue(chain.stages.first?.settings.contains { $0.identifier == "highpass" } ?? false)
            XCTAssertFalse(chain.title.isEmpty)
            XCTAssertFalse(chain.summary.isEmpty)
        }
        XCTAssertEqual(Set(VocalChain.allCases.map(\.title)).count, VocalChain.allCases.count, "no two names alike")
    }

    func testApplyingIsOneUndoStepThatReplacesTheTracksEffects() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            try store.perform(.addTrack(id: track, name: "Vocal", kind: .audio, index: nil))
            try store.perform(.addInsert(track: track, id: InsertID(), plugin: StandardEffect.chorus.component, index: nil))
            try store.perform(.addInsert(track: track, id: InsertID(), plugin: StandardEffect.delay.component, index: nil))
            for chain in VocalChain.allCases {
                let before = store.project
                let steps = store.undoStack.count
                let current = try XCTUnwrap(store.project.track(track))
                try store.perform(chain.commands(for: current), title: VocalChain.actionTitle)
                XCTAssertEqual(store.undoStack.count, steps + 1)
                XCTAssertEqual(store.undoTitle, VocalChain.actionTitle)
                let inserts = try XCTUnwrap(store.project.track(track)).inserts
                XCTAssertEqual(inserts.map(\.plugin), chain.stages.map(\.effect.component))
                for (insert, stage) in zip(inserts, chain.stages) {
                    XCTAssertEqual(insert.state, stage.state)
                    XCTAssertFalse(insert.isBypassed)
                }
                XCTAssertNoThrow(try store.project.validate())
                store.undo()
                XCTAssertEqual(store.project, before)
            }
        }
    }

    func testAVideoTrackRefusesTheChainAndNothingChanges() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            try store.perform(.addTrack(id: track, name: "Picture", kind: .video, index: nil))
            let before = store.project
            let steps = store.undoStack.count
            let current = try XCTUnwrap(store.project.track(track))
            XCTAssertThrowsError(try store.perform(VocalChain.clean.commands(for: current), title: VocalChain.actionTitle))
            XCTAssertEqual(store.project, before)
            XCTAssertEqual(store.undoStack.count, steps)
        }
    }
}
