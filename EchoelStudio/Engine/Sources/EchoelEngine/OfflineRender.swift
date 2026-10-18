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

    /// What a streamed render produced.
    public struct Summary: Sendable {
        public let frameCount: Int
        public let sampleRate: Double
        /// The largest absolute sample, before any clipping a file format applies.
        public let peak: Float
    }

    /// The song from its start to the end of its last note or audio region, plus `tailSeconds` so releases
    /// ring out. An empty song renders nothing. `samples` are the loaded media files, as for
    /// live playback; a sampler whose file is missing stays silent in the export too. `units` and
    /// `effects` are plugin units prepared at `sampleRate` for this render alone — never the live
    /// ones, which the render thread is calling. Holds the whole song in memory: for a file, use
    /// the streaming form.
    public static func render(_ project: Project, sampleRate: Double = 48_000, tailSeconds: Double = 2,
                              samples: [MediaID: SampleBuffer] = [:], units: [TrackID: HostedUnit] = [:],
                              effects: [TrackID: [HostedEffect]] = [:]) -> Result {
        var left: [Float] = [], right: [Float] = []
        let summary = render(project, sampleRate: sampleRate, tailSeconds: tailSeconds, samples: samples,
                             units: units, effects: effects) { l, r, count in
            left.append(contentsOf: UnsafeBufferPointer(start: l, count: count))
            right.append(contentsOf: UnsafeBufferPointer(start: r, count: count))
        }
        return Result(left: left, right: right, sampleRate: summary.sampleRate, peak: summary.peak)
    }

    /// The same render, handed to `write` one block at a time, so a song of any length needs only
    /// two blocks of memory. `write` may throw to stop; the render stops with it.
    public static func render(_ project: Project, sampleRate: Double = 48_000, tailSeconds: Double = 2,
                              samples: [MediaID: SampleBuffer] = [:], units: [TrackID: HostedUnit] = [:],
                              effects: [TrackID: [HostedEffect]] = [:], blockFrames: Int = 16_384,
                              into write: (UnsafePointer<Float>, UnsafePointer<Float>, Int) throws -> Void) rethrows -> Summary {
        let plan = PlaybackPlan(compiling: project)
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        let snapshot = EngineSnapshot(plan: plan, project: project, slots: slots.slots, sampleRate: rate, generation: 1,
                                      samples: samples, units: units, effects: effects)
        guard plan.songEnd > 0 || snapshot.audioEnd > 0 else { return Summary(frameCount: 0, sampleRate: rate, peak: 0) }
        core.publish(snapshot)
        core.play()

        let time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: rate)
        let tail = Int64(Swift.max(0, tailSeconds.isFinite ? tailSeconds : 0) * rate)
        let frames = Int(Swift.max(time.sample(at: plan.songEnd), snapshot.audioEnd) + tail)
        let block = Swift.max(1, blockFrames)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: block)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: block)
        defer {
            left.deallocate()
            right.deallocate()
        }
        var peak: Float = 0
        var done = 0
        while done < frames {
            let count = Swift.min(block, frames - done)
            left.update(repeating: 0, count: count)
            right.update(repeating: 0, count: count)
            core.render(frameCount: count, left: left, right: right)
            for i in 0..<count {
                peak = Swift.max(peak, Swift.abs(left[i]), Swift.abs(right[i]))
            }
            try write(left, right, count)
            done += count
        }
        return Summary(frameCount: frames, sampleRate: rate, peak: peak)
    }
}

/// A stereo PCM WAV file (RIFF, little-endian, interleaved). 24-bit by default, the studio
/// standard; samples beyond full scale are clipped, never wrapped.
public enum WAVFile {
    public enum BitDepth: Int, Sendable { case sixteen = 16, twentyFour = 24 }

    public static func data(left: [Float], right: [Float], sampleRate: Double, bitDepth: BitDepth = .twentyFour) -> Data {
        let frames = Swift.min(left.count, right.count, maximumFrames(bitDepth))
        let bytesPerSample = bitDepth.rawValue / 8
        let dataSize = frames * 2 * bytesPerSample
        var out = header(frames: frames, sampleRate: sampleRate, bitDepth: bitDepth)
        out.reserveCapacity(44 + dataSize)

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

    /// The most stereo frames one file can hold: RIFF counts its size in 32 bits (about six and a
    /// half hours at 48 kHz in 24-bit).
    public static func maximumFrames(_ bitDepth: BitDepth) -> Int {
        (Int(UInt32.max) - 36) / (2 * bitDepth.rawValue / 8)
    }

    /// The 44-byte header for `frames` stereo frames.
    static func header(frames: Int, sampleRate: Double, bitDepth: BitDepth) -> Data {
        let bytesPerSample = bitDepth.rawValue / 8
        let channels = 2
        let dataSize = Swift.min(frames, maximumFrames(bitDepth)) * channels * bytesPerSample
        let rate = UInt32(sampleRate > 0 && sampleRate.isFinite ? Swift.min(sampleRate.rounded(), 768_000) : 48_000)

        var out = Data(capacity: 44)
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
        return out
    }

    /// Full scale maps to the largest positive code; non-finite samples become silence.
    static func integer(_ sample: Float, bits: Int) -> Int32 {
        let maximum = Float((1 << (bits - 1)) - 1)
        guard sample.isFinite else { return 0 }
        let clipped = Swift.min(Swift.max(sample, -1), 1)
        return Int32((clipped * maximum).rounded())
    }

    static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}

/// Writes a stereo WAV file block by block, so an export never holds the song in memory. The
/// header is written first with the sizes left open and completed by `finish`.
public final class WAVWriter {
    public enum WriteError: Error, Equatable {
        /// The song is longer than one WAV file can hold (`WAVFile.maximumFrames`).
        case tooLong
    }

    private let handle: FileHandle
    private let bitDepth: WAVFile.BitDepth
    private let sampleRate: Double
    private var bytes: [UInt8] = []
    public private(set) var frameCount = 0

    /// Creates `url`, replacing a file that is there.
    public init(url: URL, sampleRate: Double, bitDepth: WAVFile.BitDepth = .twentyFour) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        try handle.write(contentsOf: WAVFile.header(frames: 0, sampleRate: sampleRate, bitDepth: bitDepth))
    }

    public func append(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) throws {
        guard count > 0 else { return }
        guard frameCount + count <= WAVFile.maximumFrames(bitDepth) else { throw WriteError.tooLong }
        let bytesPerSample = bitDepth.rawValue / 8
        let size = count * 2 * bytesPerSample
        if bytes.count != size { bytes = [UInt8](repeating: 0, count: size) }
        let bits = bitDepth.rawValue
        bytes.withUnsafeMutableBufferPointer { out in
            var i = 0
            func put(_ sample: Float) {
                let value = WAVFile.integer(sample, bits: bits)
                for b in 0..<bytesPerSample {
                    out[i] = UInt8(truncatingIfNeeded: value >> (8 * b))
                    i += 1
                }
            }
            for frame in 0..<count {
                put(left[frame])
                put(right[frame])
            }
        }
        try handle.write(contentsOf: bytes)
        frameCount += count
    }

    /// Writes the sizes into the header and closes the file.
    public func finish() throws {
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: WAVFile.header(frames: frameCount, sampleRate: sampleRate, bitDepth: bitDepth))
        try handle.close()
    }
}
