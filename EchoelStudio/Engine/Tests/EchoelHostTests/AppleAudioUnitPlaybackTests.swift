import AudioToolbox
import AVFoundation
import XCTest
@testable import EchoelHost

final class AppleAudioUnitPlaybackTests: XCTestCase {
    func testAppleLowPassProcessesAnImpulseThroughTheHost() throws {
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_LowPassFilter,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        for rate in [44_100.0, 48_000.0] {
            let unit = try AUAudioUnit(componentDescription: description)
            try UnitFormat.configureHostedBusses(unit, isEffect: true, sampleRate: rate)
            unit.maximumFramesToRender = 256
            try unit.allocateRenderResources()
            defer { unit.deallocateRenderResources() }
            let cutoff = try XCTUnwrap(unit.parameterTree?.parameter(withAddress: AUParameterAddress(kLowPassParam_CutoffFrequency)))
            cutoff.value = 500
            let effect = HostedEffect(render: unit.renderBlock, sampleRate: rate, maximumFrames: 256, owner: unit)
            var left = [Float](repeating: 0, count: 256)
            var right = left
            left[0] = 1
            right[0] = -0.5
            effect.process(frames: 256, left: &left, right: &right)
            XCTAssertEqual(effect.renderFailures, 0)
            XCTAssertTrue(left.allSatisfy { $0.isFinite } && right.allSatisfy { $0.isFinite })
            XCTAssertTrue(left.dropFirst().contains { abs($0) > 0.0001 }, "The impulse must be filtered")
            XCTAssertTrue(right.dropFirst().contains { abs($0) > 0.0001 })
            for frame in left.indices {
                XCTAssertEqual(right[frame], -0.5 * left[frame], accuracy: 0.0001)
            }
        }
    }

    func testAppleSamplerPlaysAScheduledNoteThroughTheHost() throws {
        let rate = 44_100.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192))
        buffer.frameLength = buffer.frameCapacity
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for i in 0..<Int(buffer.frameLength) {
            samples[i] = Float(0.4 * sin(Double(i) * 2 * Double.pi * 440 / rate))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let sampler = AVAudioUnitSampler()
        try sampler.loadAudioFiles(at: [url])
        let unit = sampler.auAudioUnit
        try UnitFormat.configureHostedBusses(unit, isEffect: false, sampleRate: rate)
        unit.maximumFramesToRender = 256
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        let hosted = HostedUnit(render: unit.renderBlock, scheduleMIDI: try XCTUnwrap(unit.scheduleMIDIEventBlock),
                                sampleRate: rate, maximumFrames: 256, owner: unit)
        hosted.noteOn(pitch: 60, velocity: 100, offset: 0)
        func renderPeak() -> Float {
            var peak: Float = 0
            for _ in 0..<16 {
                var left = [Float](repeating: 0, count: 256)
                var right = left
                hosted.render(frames: 256, left: &left, right: &right, gainLeft: 1, gainRight: 1)
                for sample in left + right {
                    XCTAssertTrue(sample.isFinite)
                    peak = max(peak, abs(sample))
                }
            }
            return peak
        }
        let peak = renderPeak()
        if peak == 0 {
            // A native note is a diagnostic control only. It cannot make this test pass.
            sampler.startNote(60, withVelocity: 100, onChannel: 0)
            let referencePeak = renderPeak()
            XCTFail("Silent hosted note; native note peak \(referencePeak), unit \(type(of: unit))")
        }
        XCTAssertEqual(hosted.renderFailures, 0)
        XCTAssertGreaterThan(peak, 0.001)
    }
}
