import AudioToolbox
import AVFoundation
import XCTest
@testable import EchoelHost

/// Two of Apple's own units, played the way the app plays a unit from another maker: prepared by
/// `UnitPreparation` as the plugin host prepares one, then rendered through `HostedEffect` and
/// `HostedUnit`. Apple's units are on every Mac and every iPhone, so this is the nearest a test
/// gets to a unit that someone else wrote — what they prove about a third-party unit is only that
/// the host's side of the contract holds; the device says the rest.
final class AppleUnitPlaybackTests: XCTestCase {
    private let frames = 256

    /// What `PluginHost.prepare` does with a unit before it plays.
    private func prepareAsTheHostDoes(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double,
                                      state: Data? = nil) throws {
        try UnitPreparation.prepare(unit, isEffect: isEffect, sampleRate: sampleRate, maximumFrames: frames,
                                    state: state, clock: HostClock())
    }

    private func appleLowPass() throws -> AUAudioUnit {
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_LowPassFilter,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        return try AUAudioUnit(componentDescription: description)
    }

    func testTheAppleLowPassFiltersAStereoImpulseAtBothRates() throws {
        for rate in [44_100.0, 48_000.0] {
            let unit = try appleLowPass()
            try prepareAsTheHostDoes(unit, isEffect: true, sampleRate: rate)
            defer { unit.deallocateRenderResources() }
            let cutoff = try XCTUnwrap(unit.parameterTree?.parameter(withAddress: AUParameterAddress(kLowPassParam_CutoffFrequency)))
            cutoff.value = 500
            let effect = HostedEffect(render: unit.renderBlock, sampleRate: rate, maximumFrames: frames, owner: unit)
            var left = [Float](repeating: 0, count: frames)
            var right = [Float](repeating: 0, count: frames)
            left[0] = 1
            right[0] = -0.5
            effect.process(frames: frames, left: &left, right: &right)

            XCTAssertEqual(effect.renderFailures, 0, "at \(rate) Hz the unit refused the block")
            XCTAssertTrue(left.allSatisfy(\.isFinite) && right.allSatisfy(\.isFinite), "at \(rate) Hz")
            // A failed block leaves the bus as it was: the impulse at frame 0 and silence after it.
            let tail = Array(left.dropFirst())
            XCTAssertTrue(tail.contains { abs($0) > 0.000_1 }, "at \(rate) Hz the impulse was not filtered")
            XCTAssertLessThan(abs(left[0]), 0.999, "at \(rate) Hz the impulse passed unchanged")
            // Both channels through the same filter: the right one is the left one at −0.5.
            for frame in 0..<frames {
                XCTAssertEqual(right[frame], -0.5 * left[frame], accuracy: 0.000_1, "at \(rate) Hz, frame \(frame)")
            }
        }
    }

    func testTheMainBussesAreSwitchedOnAndInStereoAtTheEnginesRate() throws {
        for rate in [44_100.0, 48_000.0] {
            let unit = try appleLowPass()
            try prepareAsTheHostDoes(unit, isEffect: true, sampleRate: rate)
            defer { unit.deallocateRenderResources() }
            for bus in [unit.inputBusses[0], unit.outputBusses[0]] {
                XCTAssertTrue(bus.isEnabled, "at \(rate) Hz")
                XCTAssertEqual(bus.format.sampleRate, rate)
                XCTAssertTrue(UnitFormat.accepts(bus.format), "at \(rate) Hz: \(bus.format)")
            }
        }
    }

    /// The settings a song stored at one rate come back in a unit prepared at another: the state
    /// goes in before the busses are negotiated, and negotiating them does not undo it.
    func testSavedSettingsComeBackInAUnitPreparedAtAnotherRate() throws {
        let first = try appleLowPass()
        try prepareAsTheHostDoes(first, isEffect: true, sampleRate: 44_100)
        let address = AUParameterAddress(kLowPassParam_CutoffFrequency)
        try XCTUnwrap(first.parameterTree?.parameter(withAddress: address)).value = 750
        let settings = try XCTUnwrap(first.fullStateForDocument)
        first.deallocateRenderResources()
        let state = try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)

        let second = try appleLowPass()
        try prepareAsTheHostDoes(second, isEffect: true, sampleRate: 48_000, state: state)
        defer { second.deallocateRenderResources() }
        let cutoff = try XCTUnwrap(second.parameterTree?.parameter(withAddress: address))
        XCTAssertEqual(cutoff.value, 750, accuracy: 0.5)
        XCTAssertEqual(second.outputBusses[0].format.sampleRate, 48_000)
        XCTAssertEqual(second.inputBusses[0].format.sampleRate, 48_000)
        let effect = HostedEffect(render: second.renderBlock, sampleRate: 48_000, maximumFrames: frames, owner: second)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left[0] = 1
        right[0] = 1
        effect.process(frames: frames, left: &left, right: &right)
        XCTAssertEqual(effect.renderFailures, 0)
    }

    /// A state the unit cannot read is skipped; the unit starts from its own defaults and plays.
    func testUnreadableSavedSettingsLeaveTheUnitPlayable() throws {
        let unit = try appleLowPass()
        try prepareAsTheHostDoes(unit, isEffect: true, sampleRate: 48_000, state: Data([0x00, 0x01, 0x02]))
        defer { unit.deallocateRenderResources() }
        XCTAssertTrue(unit.renderResourcesAllocated)
    }

    func testTheAppleSamplerPlaysANoteSentThroughTheHostFromAGeneratedSoundFont() throws {
        // `Fixtures/Sine.sf2`: one looping 16-bit sine, 100 samples a period at 44.1 kHz, melodic
        // bank 0, program 0, keys 0–127, root key 69. Written by a short script from the SoundFont
        // 2.04 layout (RIFF `sfbk`: INFO, sdta, pdta); nothing in it is a recording.
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Sine", withExtension: "sf2"))
        for rate in [44_100.0, 48_000.0] {
            let sampler = AVAudioUnitSampler()
            let unit = sampler.auAudioUnit
            try prepareAsTheHostDoes(unit, isEffect: false, sampleRate: rate)
            defer { unit.deallocateRenderResources() }
            try sampler.loadSoundBankInstrument(at: url, program: 0,
                                                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            let hosted = HostedUnit(render: unit.renderBlock, scheduleMIDI: try XCTUnwrap(unit.scheduleMIDIEventBlock),
                                    sampleRate: rate, maximumFrames: frames, owner: unit)
            hosted.noteOn(pitch: 69, velocity: 100, offset: 0)
            var peak: Float = 0
            var finite = true
            for _ in 0..<16 {
                var left = [Float](repeating: 0, count: frames)
                var right = [Float](repeating: 0, count: frames)
                hosted.render(frames: frames, left: &left, right: &right, gainLeft: 1, gainRight: 1)
                for sample in left + right {
                    finite = finite && sample.isFinite
                    peak = Swift.max(peak, abs(sample))
                }
            }
            XCTAssertEqual(hosted.renderFailures, 0, "at \(rate) Hz the sampler refused a block")
            XCTAssertTrue(finite, "at \(rate) Hz")
            XCTAssertGreaterThan(peak, 0.001, "at \(rate) Hz the note sent through the host stayed silent")
        }
    }
}
