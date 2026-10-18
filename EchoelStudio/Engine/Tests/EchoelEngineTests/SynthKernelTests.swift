import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

final class SynthKernelTests: XCTestCase {
    private func render(_ kernel: SynthKernel, frames: Int, gain: Float = 1) -> ([Float], [Float]) {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: gain)
            }
        }
        return (left, right)
    }

    private func peak(_ samples: [Float]) -> Float { samples.map(abs).max() ?? 0 }

    func testANoteSoundsOnBothChannelsAndAllNotesOffReleasesIt() {
        let kernel = SynthKernel(sampleRate: 48_000)
        XCTAssertEqual(peak(render(kernel, frames: 512).0), 0)
        kernel.receive(status: 0x90, 60, 100)
        let (left, right) = render(kernel, frames: 4_800)
        XCTAssertGreaterThan(peak(left), 0.01)
        XCTAssertEqual(left, right)
        kernel.receive(status: 0xB0, 123, 0)
        _ = render(kernel, frames: 48_000)
        XCTAssertEqual(peak(render(kernel, frames: 512).0), 0, "released and decayed")
    }

    func testParametersAreClampedAndChangeTheSound() {
        let kernel = SynthKernel(sampleRate: 48_000)
        let level = SynthParameter.all.firstIndex { $0.key == SynthParameter.level.key } ?? -1
        kernel.setParameter(level, 5)
        XCTAssertEqual(kernel.parameter(level), 1)
        kernel.setParameter(level, .nan)
        XCTAssertEqual(kernel.parameter(level), 1)
        kernel.receive(status: 0x90, 60, 127)
        let loud = peak(render(kernel, frames: 4_800).0)
        kernel.setParameter(level, 0)
        _ = render(kernel, frames: 4_800)            // the level glides down (5 ms)
        XCTAssertLessThan(peak(render(kernel, frames: 960).0), 1e-6)
        XCTAssertGreaterThan(loud, 0)
    }

    func testEverySynthParameterSetsExactlyOnePatchField() {
        XCTAssertEqual(PatchField.allCases.map(\.parameter.key), SynthParameter.all.map(\.key),
                       "one field per parameter, in the document's order")
        for parameter in SynthParameter.all {
            XCTAssertEqual(PatchField(parameter.key)?.parameter.key, parameter.key)
        }
        XCTAssertNil(PatchField(ParameterKey(rawValue: "synth.unknown")))
    }

    func testTheKernelSoundsExactlyLikeASongTrackWithTheSameValues() {
        // Every parameter away from its default, so a field one path forgot would show.
        var settings = InstrumentSettings()
        for parameter in SynthParameter.all {
            let span = parameter.range.upperBound - parameter.range.lowerBound
            settings.values[parameter.key.rawValue] = parameter.taper == .stepped
                ? parameter.range.upperBound : parameter.range.lowerBound + span * 0.37
        }
        settings.values[SynthParameter.level.key.rawValue] = 0.5
        let kernel = SynthKernel(sampleRate: 48_000)
        for (i, parameter) in SynthParameter.all.enumerated() {
            kernel.setParameter(i, Float(settings.value(parameter)))
        }
        // The same steps on both sides: a synth on the default patch takes the new one, renders a
        // moment of silence, then plays one note — in the kernel's 4,096-frame chunks.
        var track = PolySynth(sampleRate: 48_000)
        track.setPatch(SynthPatch(settings))
        var silence = [Float](repeating: 0, count: 64)
        silence.withUnsafeMutableBufferPointer { track.render(into: $0) }
        _ = render(kernel, frames: 64)               // the kernel takes its new values on a render
        kernel.receive(status: 0x90, 57, 110)
        track.noteOn(pitch: 57, velocity: 110)
        let fromKernel = render(kernel, frames: 4_800).0
        var fromTrack = [Float](repeating: 0, count: 4_800)
        fromTrack.withUnsafeMutableBufferPointer { all in
            guard let base = all.baseAddress else { return }
            track.render(into: UnsafeMutableBufferPointer(start: base, count: 4_096))
            track.render(into: UnsafeMutableBufferPointer(start: base + 4_096, count: 704))
        }
        XCTAssertGreaterThan(peak(fromTrack), 0.001)
        XCTAssertEqual(fromKernel, fromTrack)
    }

    func testDemoGainScalesTheOutput() {
        let kernel = SynthKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 60, 100)
        XCTAssertEqual(peak(render(kernel, frames: 2_048, gain: 0).0), 0)
    }

    func testEveryInstrumentKernelPublishesStableDistinctParametersAndPlaysThroughTheProtocol() {
        let kinds: [any InstrumentKernel.Type] = [SynthKernel.self, DrumKernel.self]
        for kind in kinds {
            let parameters = kind.parameters
            XCTAssertFalse(parameters.isEmpty)
            XCTAssertEqual(Set(parameters.map(\.identifier)).count, parameters.count)
            XCTAssertFalse(parameters.contains { $0.identifier.contains(".") }, "hosts key automation on the identifier")
            let kernel = kind.init(sampleRate: 48_000, maximumFrames: 512)
            for (index, parameter) in parameters.enumerated() {
                XCTAssertEqual(Double(kernel.parameter(index)), parameter.defaultValue, accuracy: 1e-6)
            }
        }
        XCTAssertEqual(SynthKernel.parameters.count, SynthParameter.all.count)
        XCTAssertEqual(SynthKernel.parameters.first?.identifier,
                       SynthParameter.all.first?.key.rawValue.replacingOccurrences(of: ".", with: "_"))
    }
}
