import EchoelCore
import EchoelDSP
import EchoelKernels
import Foundation

/// Export ADM BWF: the song as a Broadcast Wave file with ADM metadata (ITU-R BS.2076-2 in the
/// `axml` chunk, the channel table of ITU-R BS.2088-1 in `chna`), for an immersive renderer or a
/// DAW that imports ADM. Every track that plays into the master is one audio object on its own
/// channel — the track's stem without its pan, downmixed to mono — placed where ADM-OSC places it
/// (`ADMObject.track`); the returns, and the tracks that play to an interface output of their own,
/// are one stereo bed as the mix hears them. Rendered offline through the same engine as every
/// export, one stem at a time, so the same song gives the same file, bit for bit.
///
/// Like the stems, the file leaves out the master's inserts: its channels add up to the mix before
/// them.
public enum ADMExport {
    public enum ExportError: Error, Equatable {
        /// `assemble` was given a different number of scratch files than the plan has parts.
        case partFilesMismatch
    }

    /// What goes where: each stem, and whether it is an object or part of the bed.
    public struct Plan: Sendable {
        public enum Role: Equatable, Sendable {
            /// Object `index` (0-based), on its own channel.
            case object(Int)
            case bed
        }

        public struct Part: Sendable {
            public let track: TrackID
            public let name: String
            public let role: Role
        }

        /// In song order.
        public let parts: [Part]
        /// The song every object stem renders from: the object tracks with their pan in the
        /// centre and no pan automation, since their place is in the metadata, not in the samples.
        public let objectSong: Project
        /// The song as it is, for the bed.
        public let song: Project

        public var hasBed: Bool { parts.contains { $0.role == .bed } }
        public var objects: [Part] { parts.filter { if case .object = $0.role { return true } else { return false } } }

        /// The song to render `part` from.
        public func project(for part: Part) -> Project {
            part.role == .bed ? song : objectSong
        }
    }

    /// The plan for `project`: every stem the mix hears (`OfflineRender.stems`), nil when there is none.
    public static func plan(for project: Project, samples: [MediaID: SampleBuffer] = [:]) -> Plan? {
        let stems = OfflineRender.stems(of: project, samples: samples)
        guard !stems.isEmpty else { return nil }
        var objectSong = project
        var parts: [Plan.Part] = []
        var objectCount = 0
        for stem in stems {
            guard let index = project.tracks.firstIndex(where: { $0.id == stem.track }) else { continue }
            let track = project.tracks[index]
            let isObject = track.kind != .returnTrack && track.output == nil
            if isObject {
                objectSong.tracks[index].mixer.pan = 0
                objectSong.automation.removeAll { $0.target == .pan(track.id) }
                parts.append(Plan.Part(track: track.id, name: track.name, role: .object(objectCount)))
                objectCount += 1
            } else {
                parts.append(Plan.Part(track: track.id, name: track.name, role: .bed))
            }
        }
        guard !parts.isEmpty else { return nil }
        return Plan(parts: parts, objectSong: objectSong, song: project)
    }

    /// The file's metadata for `plan` rendered to `frameCount` frames at `sampleRate`: each
    /// object's place from its track's pan and pan automation, as ADM-OSC sends it.
    public static func layout(_ plan: Plan, title: String, frameCount: Int, sampleRate: Double) -> ADMBWF.Layout {
        let duration = ADMBWF.duration(frames: frameCount, sampleRate: sampleRate)
        let tempoMap = PlaybackPlan(compiling: plan.song).tempoMap
        let objects = plan.objects.map { part -> ADMBWF.Object in
            let pan = plan.song.track(part.track)?.mixer.pan ?? 0
            let blocks = ADMBWF.blocks(pan: pan, lane: plan.song.automation(for: .pan(part.track)),
                                       tempoMap: tempoMap, duration: duration)
            return ADMBWF.Object(name: part.name, blocks: blocks)
        }
        return ADMBWF.Layout(title: title, hasBed: plan.hasBed, objects: objects, sampleRate: sampleRate,
                             duration: duration)
    }

    /// Renders `part` alone at `frameCount` frames into `url` as raw interleaved stereo 32-bit
    /// float, little-endian — a scratch file `assemble` reads back.
    public static func renderPart(_ part: Plan.Part, of plan: Plan, frameCount: Int, sampleRate: Double,
                                  samples: [MediaID: SampleBuffer] = [:],
                                  units: [TrackID: any HostedInstrument] = [:],
                                  effects: [TrackID: [any HostedProcessor]] = [:], to url: URL) throws {
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        var bytes: [UInt8] = []
        _ = try OfflineRender.render(plan.project(for: part), sampleRate: sampleRate, samples: samples, units: units,
                                     effects: effects, isolating: part.track, frameCount: frameCount) { left, right, count in
            let size = count * 8
            if bytes.count != size { bytes = [UInt8](repeating: 0, count: size) }
            bytes.withUnsafeMutableBufferPointer { out in
                for frame in 0..<count {
                    put(left[frame].bitPattern, into: out, at: frame * 8)
                    put(right[frame].bitPattern, into: out, at: frame * 8 + 4)
                }
            }
            try handle.write(contentsOf: bytes)
        }
    }

    /// The ADM BWF of `plan`: the parts' scratch files (`partFiles`, in the plan's order) read back
    /// together a block at a time — each object's two sides summed into its channel at the level a
    /// centred stereo pan gave them, the bed's parts added into its two channels in song order —
    /// and written in 24-bit with the `chna` and `axml` of `layout`.
    public static func assemble(_ plan: Plan, layout: ADMBWF.Layout, partFiles: [URL], frameCount: Int,
                                to url: URL, blockFrames: Int = 8_192) throws {
        guard partFiles.count == plan.parts.count else { throw ExportError.partFilesMismatch }
        let readers = try partFiles.map { try FileHandle(forReadingFrom: $0) }
        defer { for reader in readers { try? reader.close() } }
        let channels = layout.channelCount
        let writer = try BW64Writer(url: url, sampleRate: layout.sampleRate, channels: channels,
                                    chna: ADMBWF.chna(layout), axml: ADMBWF.axml(layout))
        let block = Swift.max(1, blockFrames)
        var mixed = [Float](repeating: 0, count: block * channels)
        // A centred pan put each side at cos(π/4); the object is the source at its own level.
        let downmix = Float(0.5.squareRoot())
        var done = 0
        while done < frameCount {
            let count = Swift.min(block, frameCount - done)
            for index in 0..<(count * channels) { mixed[index] = 0 }
            for (part, reader) in zip(plan.parts, readers) {
                let data = try reader.read(upToCount: count * 8) ?? Data()
                let frames = Swift.min(count, data.count / 8)
                data.withUnsafeBytes { raw in
                    for frame in 0..<frames {
                        let left = Float(bitPattern: word(raw, at: frame * 8))
                        let right = Float(bitPattern: word(raw, at: frame * 8 + 4))
                        let row = frame * channels
                        switch part.role {
                        case .bed:
                            mixed[row] += left
                            mixed[row + 1] += right
                        case .object(let index):
                            mixed[row + layout.channel(ofObject: index) - 1] = (left + right) * downmix
                        }
                    }
                }
            }
            try mixed.withUnsafeBufferPointer { try writer.append(interleaved: $0, frames: count) }
            done += count
        }
        try writer.finish()
    }

    /// The whole export without plugins: plan, measure, render each part into `scratch`, assemble
    /// into `url`. Nil when nothing plays. The scratch files are removed whatever happens.
    @discardableResult
    public static func export(_ project: Project, title: String, sampleRate: Double = 48_000,
                              samples: [MediaID: SampleBuffer] = [:], scratch: URL, to url: URL) throws -> ADMBWF.Layout? {
        guard let plan = plan(for: project, samples: samples) else { return nil }
        let frames = OfflineRender.render(project, sampleRate: sampleRate, samples: samples) { _, _, _ in }.frameCount
        guard frames > 0 else { return nil }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let files = plan.parts.indices.map { scratch.appendingPathComponent("part-\($0).f32") }
        defer { for file in files { try? FileManager.default.removeItem(at: file) } }
        for (part, file) in zip(plan.parts, files) {
            try renderPart(part, of: plan, frameCount: frames, sampleRate: sampleRate, samples: samples, to: file)
        }
        let layout = layout(plan, title: title, frameCount: frames, sampleRate: sampleRate)
        try assemble(plan, layout: layout, partFiles: files, frameCount: frames, to: url)
        return layout
    }

    private static func put(_ value: UInt32, into out: UnsafeMutableBufferPointer<UInt8>, at offset: Int) {
        for byte in 0..<4 { out[offset + byte] = UInt8(truncatingIfNeeded: value >> UInt32(8 * byte)) }
    }

    private static func word(_ raw: UnsafeRawBufferPointer, at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for byte in 0..<4 { value |= UInt32(raw[offset + byte]) << UInt32(8 * byte) }
        return value
    }
}

/// A Broadcast Wave 64 file (ITU-R BS.2088-1) written block by block: RIFF while it fits in 32-bit
/// sizes, RF64 with a `ds64` chunk past 4 GiB — the `JUNK` chunk reserved at the start becomes the
/// `ds64`, as the standard asks of a writer that cannot know the size ahead. 24-bit integer PCM,
/// any number of channels; `chna` and `axml` go before the samples.
public final class BW64Writer {
    public enum WriteError: Error, Equatable {
        case noChannels
    }

    private let handle: FileHandle
    public let channels: Int
    /// The byte where the samples start.
    private let dataStart: UInt64
    /// RIFF sizes past this become RF64: `UInt32.max` in a real file, smaller in a test.
    private let riffLimit: UInt64
    private var bytes: [UInt8] = []
    public private(set) var frameCount = 0

    static let ds64Size = 28

    public convenience init(url: URL, sampleRate: Double, channels: Int, chna: Data, axml: Data) throws {
        try self.init(url: url, sampleRate: sampleRate, channels: channels, chna: chna, axml: axml,
                      riffLimit: UInt64(UInt32.max))
    }

    init(url: URL, sampleRate: Double, channels: Int, chna: Data, axml: Data, riffLimit: UInt64) throws {
        guard channels > 0 else { throw WriteError.noChannels }
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        self.channels = channels
        self.riffLimit = riffLimit
        var head = Data()
        head.append(contentsOf: Array("RIFF".utf8))
        WAVFile.append(UInt32(0), to: &head)
        head.append(contentsOf: Array("WAVE".utf8))
        head.append(contentsOf: Array("JUNK".utf8))
        WAVFile.append(UInt32(Self.ds64Size), to: &head)
        head.append(Data(count: Self.ds64Size))
        head.append(Self.format(channels: channels, sampleRate: sampleRate))
        Self.appendChunk("chna", chna, to: &head)
        Self.appendChunk("axml", axml, to: &head)
        head.append(contentsOf: Array("data".utf8))
        WAVFile.append(UInt32(0), to: &head)
        dataStart = UInt64(head.count)
        try handle.write(contentsOf: head)
    }

    /// The `fmt ` chunk: integer PCM, 24-bit.
    static func format(channels: Int, sampleRate: Double) -> Data {
        let rate = UInt32(sampleRate > 0 && sampleRate.isFinite ? Swift.min(sampleRate.rounded(), 768_000) : 48_000)
        var out = Data()
        out.append(contentsOf: Array("fmt ".utf8))
        WAVFile.append(UInt32(16), to: &out)
        WAVFile.append(UInt16(1), to: &out)
        WAVFile.append(UInt16(clamping: channels), to: &out)
        WAVFile.append(rate, to: &out)
        WAVFile.append(rate &* UInt32(clamping: channels * 3), to: &out)
        WAVFile.append(UInt16(clamping: channels * 3), to: &out)
        WAVFile.append(UInt16(24), to: &out)
        return out
    }

    static func appendChunk(_ id: String, _ body: Data, to out: inout Data) {
        out.append(contentsOf: Array(id.utf8))
        WAVFile.append(UInt32(clamping: body.count), to: &out)
        out.append(body)
        if body.count % 2 == 1 { out.append(0) }
    }

    /// Appends `frames` interleaved frames of `channels` samples, clipped at full scale.
    public func append(interleaved samples: UnsafeBufferPointer<Float>, frames: Int) throws {
        let count = Swift.min(Swift.max(0, frames), samples.count / channels)
        guard count > 0 else { return }
        let size = count * channels * 3
        if bytes.count != size { bytes = [UInt8](repeating: 0, count: size) }
        bytes.withUnsafeMutableBufferPointer { out in
            for index in 0..<(count * channels) {
                let value = UInt32(bitPattern: WAVFile.integer(samples[index], bits: 24))
                out[index * 3] = UInt8(truncatingIfNeeded: value)
                out[index * 3 + 1] = UInt8(truncatingIfNeeded: value >> 8)
                out[index * 3 + 2] = UInt8(truncatingIfNeeded: value >> 16)
            }
        }
        try handle.write(contentsOf: bytes)
        frameCount += count
    }

    /// Pads the samples to an even length, writes the sizes — as RF64 when they do not fit RIFF —
    /// and closes the file.
    public func finish() throws {
        let dataSize = UInt64(frameCount) * UInt64(channels * 3)
        if dataSize % 2 == 1 {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([0]))
        }
        let riffSize = dataStart + dataSize + dataSize % 2 - 8
        if riffSize <= riffLimit && dataSize <= riffLimit {
            try handle.seek(toOffset: 4)
            try handle.write(contentsOf: Self.le(UInt32(riffSize)))
            try handle.seek(toOffset: dataStart - 4)
            try handle.write(contentsOf: Self.le(UInt32(dataSize)))
        } else {
            var head = Data(Array("RF64".utf8))
            WAVFile.append(UInt32.max, to: &head)
            head.append(contentsOf: Array("WAVE".utf8))
            head.append(contentsOf: Array("ds64".utf8))
            WAVFile.append(UInt32(Self.ds64Size), to: &head)
            WAVFile.append(riffSize, to: &head)
            WAVFile.append(dataSize, to: &head)
            WAVFile.append(UInt64(frameCount), to: &head)
            WAVFile.append(UInt32(0), to: &head)                         // no table
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: head)
            try handle.seek(toOffset: dataStart - 4)
            try handle.write(contentsOf: Self.le(UInt32.max))
        }
        try handle.close()
    }

    private static func le(_ value: UInt32) -> Data {
        var out = Data()
        WAVFile.append(value, to: &out)
        return out
    }
}
