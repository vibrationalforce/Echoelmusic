import EchoelCore
import EchoelDSP
import Foundation

/// Renders a whole song faster than real time through the same `EngineCore` that plays it
/// live, so an export sounds exactly like playback (click off). Main thread or a background
/// task — never the render thread: it allocates the output.
public enum OfflineRender {
    public struct Result: Sendable {
        public let left: [Float]
        public let right: [Float]
        public let sampleRate: Double
        /// The largest absolute sample, before any clipping a file format applies.
        public let peak: Float
        public var frameCount: Int { left.count }
    }

    /// The song from its start to the end of its last note, plus `tailSeconds` so releases
    /// ring out. An empty song renders nothing. `samples` are the loaded media files, as for
    /// live playback; a sampler whose file is missing stays silent in the export too.
    public static func render(_ project: Project, sampleRate: Double = 48_000, tailSeconds: Double = 2,
                              samples: [MediaID: SampleBuffer] = [:]) -> Result {
        let plan = PlaybackPlan(compiling: project)
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        guard plan.songEnd > 0 else { return Result(left: [], right: [], sampleRate: rate, peak: 0) }

        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: plan, project: project, slots: slots.slots, sampleRate: rate, generation: 1,
                                    samples: samples))
        core.play()

        let time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: rate)
        let tail = Int64(Swift.max(0, tailSeconds.isFinite ? tailSeconds : 0) * rate)
        let frames = Int(time.sample(at: plan.songEnd) + tail)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                core.render(frameCount: frames, left: lp, right: rp)
            }
        }
        let peak = Swift.max(left.reduce(0) { Swift.max($0, Swift.abs($1)) },
                             right.reduce(0) { Swift.max($0, Swift.abs($1)) })
        return Result(left: left, right: right, sampleRate: rate, peak: peak)
    }
}

/// A stereo PCM WAV file (RIFF, little-endian, interleaved). 24-bit by default, the studio
/// standard; samples beyond full scale are clipped, never wrapped.
public enum WAVFile {
    public enum BitDepth: Int, Sendable { case sixteen = 16, twentyFour = 24 }

    public static func data(left: [Float], right: [Float], sampleRate: Double, bitDepth: BitDepth = .twentyFour) -> Data {
        let frames = Swift.min(left.count, right.count)
        let bytesPerSample = bitDepth.rawValue / 8
        let channels = 2
        let dataSize = frames * channels * bytesPerSample
        let rate = UInt32(sampleRate > 0 && sampleRate.isFinite ? sampleRate.rounded() : 48_000)

        var out = Data(capacity: 44 + dataSize)
        out.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize), to: &out)
        out.append(contentsOf: Array("WAVE".utf8))
        out.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16), to: &out)                                   // fmt chunk size
        append(UInt16(1), to: &out)                                    // PCM
        append(UInt16(channels), to: &out)
        append(rate, to: &out)
        append(rate * UInt32(channels * bytesPerSample), to: &out)     // byte rate
        append(UInt16(channels * bytesPerSample), to: &out)            // block align
        append(UInt16(bitDepth.rawValue), to: &out)
        out.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize), to: &out)

        var bytes = [UInt8](repeating: 0, count: dataSize)
        var i = 0
        func put(_ sample: Float) {
            let value = integer(sample, bits: bitDepth.rawValue)
            for b in 0..<bytesPerSample {
                bytes[i] = UInt8(truncatingIfNeeded: value >> (8 * b))
                i += 1
            }
        }
        for frame in 0..<frames {
            put(left[frame])
            put(right[frame])
        }
        out.append(contentsOf: bytes)
        return out
    }

    /// Full scale maps to the largest positive code; non-finite samples become silence.
    static func integer(_ sample: Float, bits: Int) -> Int32 {
        let maximum = Float((1 << (bits - 1)) - 1)
        guard sample.isFinite else { return 0 }
        let clipped = Swift.min(Swift.max(sample, -1), 1)
        return Int32((clipped * maximum).rounded())
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
