import AVFoundation
import EchoelCore
import XCTest
@testable import EchoelEngine

final class StandardEffectUnitTests: XCTestCase {
    private func unit(_ effect: StandardEffect) throws -> StandardEffectUnit {
        let unit = try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(effect.component))
        try unit.allocateRenderResources()
        return unit
    }

    private func render(_ unit: StandardEffectUnit, _ input: [Float]) -> [Float] {
        let effect = HostedEffect(render: unit.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: unit)
        var left = input, right = input
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let n = Swift.min(256, l.count - done)
                    effect.process(frames: n, left: a + done, right: b + done)
                    done += n
                }
            }
        }
        return left
    }

    func testEachStandardEffectIsAStereoEffectWithItsParametersInATree() throws {
        for effect in StandardEffect.allCases {
            let u = try unit(effect)
            XCTAssertEqual(u.effect, effect)
            XCTAssertEqual(u.inputBusses.count, 1)
            XCTAssertEqual(u.outputBusses.count, 1)
            XCTAssertEqual(u.parameterTree?.allParameters.count, EffectKernel.parameters(for: effect).count)
        }
        XCTAssertThrowsError(try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(OwnPlugin.synth.component)),
                             "only a standard effect's id makes one")
    }

    func testTheDelayRepeatsAnImpulseWhenItsTreeSaysSo() throws {
        let delay = try unit(.delay)
        let tree = try XCTUnwrap(delay.parameterTree)
        tree.parameter(withAddress: 0)?.value = 0.01 // time
        tree.parameter(withAddress: 1)?.value = 0 // feedback
        tree.parameter(withAddress: 2)?.value = 1 // mix
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        let out = render(delay, impulse)
        XCTAssertEqual(out[0], 0, accuracy: 1e-6, "fully wet")
        XCTAssertEqual(out[480], 1, accuracy: 0.05, "10 ms later, across block boundaries")
        XCTAssertEqual(tree.parameter(withAddress: 2)?.value, 1, "the tree reads what the kernel holds")
    }

    func testARegisteredEffectLoadsLikeAnyAudioUnit() throws {
        StandardEffectUnit.register()
        let loaded = expectation(description: "instantiated")
        nonisolated(unsafe) var found: AUAudioUnit?
        AUAudioUnit.instantiate(with: StandardEffectUnit.audioComponent(StandardEffect.reverb.component), options: []) { unit, _ in
            found = unit
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)
        XCTAssertTrue(found is StandardEffectUnit)
    }
}
