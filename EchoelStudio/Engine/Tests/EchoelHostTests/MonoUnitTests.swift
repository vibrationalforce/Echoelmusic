import AudioToolbox
import AVFoundation
import XCTest
@testable import EchoelHost

/// A unit of another maker whose busses take one channel only. As an effect it halves what it is
/// given; as an instrument it plays a constant. How it refuses stereo is the unit's own:
private final class MonoOnlyUnit: AUAudioUnit {
    enum Refusal {
        /// When the host sets the format (an AUv3 that checks `shouldChange`).
        case whenSet
        /// Only when it allocates (Apple's version-2 SDK checks its channels in `Initialize`).
        case atAllocation
        /// Its format never changes, not even to the one it has: mono at 48 kHz from the start.
        case fixed
    }

    static let level: Float = 0.25
    private let isEffect: Bool
    private let refusal: Refusal
    private var inputs: AUAudioUnitBusArray?
    private var outputs: AUAudioUnitBusArray?

    init(isEffect: Bool, refusal: Refusal = .whenSet) throws {
        self.isEffect = isEffect
        self.refusal = refusal
        let description = AudioComponentDescription(componentType: isEffect ? kAudioUnitType_Effect : kAudioUnitType_MusicDevice,
                                                    componentSubType: 0x6D6F_6E6F, componentManufacturer: 0x5465_7374,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try super.init(componentDescription: description, options: [])
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: refusal == .fixed ? 48_000 : 44_100, channels: 1) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let output = try AUAudioUnitBus(format: mono)
        output.maximumChannelCount = refusal == .atAllocation ? 2 : 1
        outputs = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [output])
        if isEffect {
            let input = try AUAudioUnitBus(format: mono)
            input.maximumChannelCount = refusal == .atAllocation ? 2 : 1
            inputs = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [input])
        }
        maximumFramesToRender = 4_096
    }

    override var inputBusses: AUAudioUnitBusArray {
        inputs ?? AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    override var outputBusses: AUAudioUnitBusArray {
        outputs ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        switch refusal {
        case .whenSet: format.channelCount == 1 && super.shouldChange(to: format, for: bus)
        case .atAllocation: super.shouldChange(to: format, for: bus)
        case .fixed: false
        }
    }

    override func allocateRenderResources() throws {
        var busses: [AUAudioUnitBus] = []
        for index in 0..<inputBusses.count { busses.append(inputBusses[index]) }
        for index in 0..<outputBusses.count { busses.append(outputBusses[index]) }
        if busses.contains(where: { $0.format.channelCount != 1 }) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        try super.allocateRenderResources()
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        let isEffect = self.isEffect
        return { flags, timestamp, frameCount, _, outputData, _, pullInput in
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count == 1, let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                return kAudioUnitErr_FormatNotSupported
            }
            let frames = Int(frameCount)
            if isEffect {
                guard let pullInput else { return kAudioUnitErr_NoConnection }
                let status = pullInput(flags, timestamp, frameCount, 0, outputData)
                guard status == noErr, let input = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return status }
                for i in 0..<frames { out[i] = 0.5 * input[i] }
            } else {
                for i in 0..<frames { out[i] = MonoOnlyUnit.level }
            }
            return noErr
        }
    }
}

/// A unit with mono busses plays through the host: the busses are negotiated down to one
/// channel, an instrument's channel plays on both sides, an effect hears the bus summed.
final class MonoUnitTests: XCTestCase {
    private let frames = 256

    func testABusThatRefusesStereoIsNegotiatedToMono() throws {
        let unit = try MonoOnlyUnit(isEffect: true)
        let layout = try UnitPreparation.prepare(unit, isEffect: true, sampleRate: 48_000, maximumFrames: frames,
                                                 state: nil, clock: nil)
        defer { unit.deallocateRenderResources() }
        XCTAssertEqual(layout, UnitPreparation.Layout(inputChannels: 1, outputChannels: 1))
        XCTAssertEqual(unit.inputBusses[0].format.sampleRate, 48_000)
        XCTAssertEqual(unit.outputBusses[0].format.channelCount, 1)
        XCTAssertTrue(unit.inputBusses[0].isEnabled)
    }

    func testAUnitThatRefusesStereoOnlyWhenItAllocatesIsAllocatedInMono() throws {
        for isEffect in [true, false] {
            let unit = try MonoOnlyUnit(isEffect: isEffect, refusal: .atAllocation)
            let layout = try UnitPreparation.prepare(unit, isEffect: isEffect, sampleRate: 48_000, maximumFrames: frames,
                                                     state: nil, clock: nil)
            defer { unit.deallocateRenderResources() }
            XCTAssertEqual(layout, UnitPreparation.Layout(inputChannels: isEffect ? 1 : 0, outputChannels: 1))
            XCTAssertTrue(unit.renderResourcesAllocated)
        }
    }

    func testABusAlreadyInMonoAtTheRateIsLeftAsItIs() throws {
        let unit = try MonoOnlyUnit(isEffect: true, refusal: .fixed)
        let layout = try UnitPreparation.prepare(unit, isEffect: true, sampleRate: 48_000, maximumFrames: frames,
                                                 state: nil, clock: nil)
        defer { unit.deallocateRenderResources() }
        XCTAssertEqual(layout, UnitPreparation.Layout(inputChannels: 1, outputChannels: 1))
    }

    func testAStereoUnitStaysStereo() throws {
        let unit = try AUAudioUnit(componentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_LowPassFilter,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        let layout = try UnitPreparation.prepare(unit, isEffect: true, sampleRate: 48_000, maximumFrames: frames,
                                                 state: nil, clock: nil)
        defer { unit.deallocateRenderResources() }
        XCTAssertEqual(layout, UnitPreparation.Layout(inputChannels: 2, outputChannels: 2))
    }

    func testAMonoInstrumentPlaysItsChannelOnBothSides() throws {
        let unit = try MonoOnlyUnit(isEffect: false)
        let layout = try UnitPreparation.prepare(unit, isEffect: false, sampleRate: 48_000, maximumFrames: frames,
                                                 state: nil, clock: nil)
        defer { unit.deallocateRenderResources() }
        let hosted = HostedUnit(render: unit.renderBlock, scheduleMIDI: nil, sampleRate: 48_000, maximumFrames: frames,
                                owner: unit, outputChannels: layout.outputChannels)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        hosted.render(frames: frames, left: &left, right: &right, gainLeft: 1, gainRight: 1)
        XCTAssertEqual(hosted.renderFailures, 0)
        XCTAssertEqual(left, [Float](repeating: MonoOnlyUnit.level, count: frames))
        XCTAssertEqual(right, [Float](repeating: MonoOnlyUnit.level, count: frames))
    }

    func testAMonoEffectHearsTheBusSummedAndPlaysOnBothSides() throws {
        let unit = try MonoOnlyUnit(isEffect: true)
        let layout = try UnitPreparation.prepare(unit, isEffect: true, sampleRate: 48_000, maximumFrames: frames,
                                                 state: nil, clock: nil)
        defer { unit.deallocateRenderResources() }
        let effect = HostedEffect(render: unit.renderBlock, sampleRate: 48_000, maximumFrames: frames, owner: unit,
                                  outputChannels: layout.outputChannels)
        var left = [Float](repeating: 1, count: frames)
        var right = [Float](repeating: 0.5, count: frames)
        effect.process(frames: frames, left: &left, right: &right)
        XCTAssertEqual(effect.renderFailures, 0)
        // Summed at half each: 0.75; halved by the unit: 0.375, on both sides.
        for frame in 0..<frames {
            XCTAssertEqual(left[frame], 0.375, accuracy: 0.000_01, "frame \(frame)")
            XCTAssertEqual(right[frame], 0.375, accuracy: 0.000_01, "frame \(frame)")
        }
    }
}
