import AudioToolbox
import AVFoundation
import XCTest
@testable import EchoelHost

/// A unit that builds a new parameter tree when its mode changes, and says so the way a unit
/// must: key-value observation of `parameterTree`.
private final class ModeUnit: AUAudioUnit {
    private var tree: AUParameterTree?

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        tree = Self.tree(cutoffMax: 20_000, extra: false)
    }

    override var parameterTree: AUParameterTree? {
        get { tree }
        set { tree = newValue }
    }

    /// The second mode: the cutoff reaches less far, and a drive appears.
    func switchMode() {
        willChangeValue(forKey: "parameterTree")
        tree = Self.tree(cutoffMax: 8_000, extra: true)
        didChangeValue(forKey: "parameterTree")
    }

    private static func tree(cutoffMax: Float, extra: Bool) -> AUParameterTree {
        let writable: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
        var children = [AUParameterTree.createParameter(withIdentifier: "cutoff", name: "Cutoff", address: 1, min: 20,
                                                         max: cutoffMax, unit: .hertz, unitName: nil, flags: writable,
                                                         valueStrings: nil, dependentParameters: nil)]
        if extra {
            children.append(AUParameterTree.createParameter(withIdentifier: "drive", name: "Drive", address: 2, min: 0,
                                                            max: 1, unit: .generic, unitName: nil, flags: writable,
                                                            valueStrings: nil, dependentParameters: nil))
        }
        return AUParameterTree.createTree(withChildren: children)
    }
}

final class ParameterTreeWatchTests: XCTestCase {
    private func makeUnit() throws -> ModeUnit {
        try ModeUnit(componentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: 0x6D6F_6465, componentManufacturer: 0x5465_7374,
            componentFlags: 0, componentFlagsMask: 0))
    }

    func testANewTreeIsSeenAndItsRangesAreTheOnesAutomationUses() async throws {
        let unit = try makeUnit()
        let changed = expectation(description: "the watch saw the new tree")
        changed.assertForOverFulfill = false
        let watch = ParameterTreeWatch(unit) { changed.fulfill() }
        XCTAssertEqual(HostedParameters.automatableRanges(unit.parameterTree), [1: 20...20_000])

        unit.switchMode()
        await fulfillment(of: [changed], timeout: 5)
        XCTAssertEqual(HostedParameters.automatableRanges(unit.parameterTree), [1: 20...8_000, 2: 0...1])
        withExtendedLifetime(watch) {}
    }

    func testAHostedUnitTakesTheNewRanges() {
        let hosted = HostedUnit(render: { _, _, _, _, _, _ in noErr }, scheduleMIDI: nil, sampleRate: 48_000,
                                maximumFrames: 256, owner: nil, parameterRanges: [1: 20...20_000])
        hosted.updateParameterRanges([1: 20...8_000, 2: 0...1])
        XCTAssertEqual(hosted.parameterRanges, [1: 20...8_000, 2: 0...1])
        let effect = HostedEffect(render: { _, _, _, _, _, _ in noErr }, sampleRate: 48_000, maximumFrames: 256,
                                  owner: nil, parameterRanges: [1: 20...20_000])
        effect.updateParameterRanges([:])
        XCTAssertEqual(effect.parameterRanges, [:])
    }

    func testAWatchThatIsGoneHearsNothing() throws {
        let unit = try makeUnit()
        let heard = expectation(description: "no call after the watch is gone")
        heard.isInverted = true
        var watch: ParameterTreeWatch? = ParameterTreeWatch(unit) { heard.fulfill() }
        XCTAssertNotNil(watch)
        watch = nil
        unit.switchMode()
        wait(for: [heard], timeout: 0.3)
    }

    func testOnlyWritableParametersWithARealRangeCanBeAutomated() {
        let writable: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
        let meter = AUParameterTree.createParameter(withIdentifier: "meter", name: "Meter", address: 3, min: 0, max: 1,
                                                    unit: .generic, unitName: nil, flags: [.flag_IsReadable],
                                                    valueStrings: nil, dependentParameters: nil)
        let flat = AUParameterTree.createParameter(withIdentifier: "flat", name: "Flat", address: 4, min: 1, max: 1,
                                                   unit: .generic, unitName: nil, flags: writable,
                                                   valueStrings: nil, dependentParameters: nil)
        let gain = AUParameterTree.createParameter(withIdentifier: "gain", name: "Gain", address: 5, min: -12, max: 12,
                                                   unit: .decibels, unitName: nil, flags: writable,
                                                   valueStrings: nil, dependentParameters: nil)
        let tree = AUParameterTree.createTree(withChildren: [meter, flat, gain])
        XCTAssertEqual(HostedParameters.automatableRanges(tree), [5: -12...12])
        XCTAssertEqual(HostedParameters.automatableRanges(nil), [:])
    }
}
