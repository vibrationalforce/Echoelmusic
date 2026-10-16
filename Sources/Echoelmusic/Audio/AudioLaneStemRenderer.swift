#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// LS-ST3b (ADR-008 K1): renders ONE audio lane of a song as a stem file, offline, from its files
/// and the document — no tap, no device timing, the same answer every time.
///
/// WHAT IT WRITES: one mono file in `StemFileWriter.fileSettings` (24-bit PCM, the take's rate),
/// starting at song tick 0 and exactly as long as the SONG (`document.endTick`), so every lane's
/// stem has the same zero point and the same length (ADR-008 §5). Gaps are silence in place. A
/// multi-channel source is folded to mono by averaging — the stem is dry and mono, the space is
/// made in the studio from the trajectory (ADR-008 §3).
///
/// WHAT IT CARRIES: the part's own gain and its fades (asked of `AudioRegionPlayback.fadePlan`, the
/// live player's rule). Lane level, mute and pan are NOT in the file — they are the exporter's, as
/// for the generated voices' stems (K2: pre-fader).
///
/// WHAT IT REFUSES, loudly and before a single byte is written (ADR-008: "nie still"): a lane
/// that is not an audio lane of this document (a silent stem would read as a real one), a warped
/// part, a transposed part, a lane with an enabled effect (that includes grain), a clip whose file
/// does not resolve or open, and a file whose rate differs from the stem's — each of those would
/// make a stem that does not sound like the song. Rate conversion and the stretcher are later
/// slices; until then the refusal is the honest answer.
///
/// Not thread-confined, never on an audio thread (file I/O). Built: yes · wired: NO — no exporter
/// calls it yet · device: no.
enum AudioLaneStemRenderer {

    enum Refusal: Error, Equatable {
        case badTempo
        case noSuchAudioLane
        case warped(regionID: UUID)
        case transposed(regionID: UUID)
        case laneHasEffects
        case unresolved(clipID: UUID)
        case sampleRateMismatch(clipID: UUID, fileRate: Double)
        case formatUnavailable
    }

    struct Report: Equatable {
        /// Frames in the file — the song's length at the stem rate.
        let frames: Int64
        /// Segments that put audio into the file.
        let segmentsWritten: Int
    }

    static func render(document: TimelineDocument, laneID: UUID, bpm: Double, sampleRate: Double,
                       to url: URL, resolveURL: (UUID) -> URL?,
                       nativeBPM: (UUID) -> Double = { _ in 0 },
                       chunkFrames: Int = 4_096) throws -> Report {
        guard bpm.isFinite, bpm > 0, sampleRate.isFinite, sampleRate > 0 else { throw Refusal.badTempo }
        guard let lane = document.lanes.first(where: { $0.id == laneID }), lane.kind == .audio else {
            throw Refusal.noSuchAudioLane
        }
        if lane.deviceChain?.inserts
            .contains(where: { $0.isEnabled }) == true {
            throw Refusal.laneHasEffects
        }
        let segments = AudioLaneStemPlan.segments(in: document, laneID: laneID, bpm: bpm,
                                                  nativeBPM: nativeBPM)
        var regions: [UUID: TimelineRegion] = [:]
        for region in document.regions where region.laneID == laneID { regions[region.id] = region }

        // Every refusal is decided here, before the output file exists — and every buffer is
        // allocated here too, so nothing after the file opens can fail for want of memory.
        let chunk = Swift.min(Swift.max(1, chunkFrames), 1 << 20)
        var sources: [UUID: AVAudioFile] = [:]
        var inputs: [UUID: AVAudioPCMBuffer] = [:]
        for segment in segments {
            guard segment.rate == 1 else { throw Refusal.warped(regionID: segment.regionID) }
            if let region = regions[segment.regionID],
               AudioTranspose.semitones(for: region, in: document) != 0 {
                throw Refusal.transposed(regionID: segment.regionID)
            }
            guard sources[segment.clipID] == nil else { continue }
            guard let source = resolveURL(segment.clipID),
                  let file = try? AVAudioFile(forReading: source) else {
                throw Refusal.unresolved(clipID: segment.clipID)
            }
            let fileRate = file.processingFormat.sampleRate
            guard fileRate == sampleRate else {
                throw Refusal.sampleRateMismatch(clipID: segment.clipID, fileRate: fileRate)
            }
            guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                               frameCapacity: AVAudioFrameCount(chunk)) else {
                throw Refusal.formatUnavailable
            }
            sources[segment.clipID] = file
            inputs[segment.clipID] = input
        }

        guard let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                       channels: 1, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(chunk)),
              let outData = out.floatChannelData?[0] else { throw Refusal.formatUnavailable }
        let total = Int64(AudioLaneStemPlan.frame(atTick: document.endTick, bpm: bpm, sampleRate: sampleRate))
        do {
            return try write(segments: segments, regions: regions, sources: sources, inputs: inputs,
                             to: url, bpm: bpm, sampleRate: sampleRate, total: total,
                             out: out, outData: outData, chunk: chunk)
        } catch {
            // A read or write that fails part-way must not leave a stem that looks complete.
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private static func write(segments: [AudioLaneStemSegment], regions: [UUID: TimelineRegion],
                              sources: [UUID: AVAudioFile], inputs: [UUID: AVAudioPCMBuffer],
                              to url: URL, bpm: Double, sampleRate: Double, total: Int64,
                              out: AVAudioPCMBuffer, outData: UnsafeMutablePointer<Float>,
                              chunk: Int) throws -> Report {
        let file = try AVAudioFile(forWriting: url, settings: StemFileWriter.fileSettings(sampleRate: sampleRate),
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        var written: Int64 = 0

        func pad(to end: Int64) throws {
            while written < end {
                let count = Int(Swift.min(Int64(chunk), end - written))
                outData.update(repeating: 0, count: count)
                out.frameLength = AVAudioFrameCount(count)
                try file.write(from: out)
                written += Int64(count)
            }
        }

        var segmentsWritten = 0
        for segment in segments {
            guard let source = sources[segment.clipID], let input = inputs[segment.clipID],
                  let frames = AudioLaneStemPlan.frames(for: segment, bpm: bpm, sampleRate: sampleRate,
                                                        fileFrames: Int(source.length)) else { continue }
            let destination = Int64(frames.destinationStart)
            // The plan is ordered and its touching edges share a frame; nothing may write backwards.
            guard destination >= written, destination < total else { continue }
            try pad(to: destination)
            let region = regions[segment.regionID]
            let gain = region?.gain ?? 1
            let fades = region.flatMap { AudioRegionPlayback.fadePlan(for: $0, bpm: bpm, stretchRate: 1) }
            let count = Int(Swift.min(Int64(frames.count), total - destination))
            source.framePosition = AVAudioFramePosition(frames.sourceStart)
            var done = 0
            while done < count {
                try source.read(into: input, frameCount: AVAudioFrameCount(Swift.min(chunk, count - done)))
                let got = Int(input.frameLength)
                guard got > 0, let channels = input.floatChannelData else { break }
                let channelCount = Int(input.format.channelCount)
                guard channelCount > 0 else { break }
                for i in 0..<got {
                    var sum: Float = 0
                    for c in 0..<channelCount { sum += channels[c][i] }
                    var level = gain
                    if let fades {
                        let moment = Double(frames.sourceStart + done + i) / sampleRate
                        level *= Float(fades.gain(atMediaSeconds: moment))
                    }
                    outData[i] = sum / Float(channelCount) * level
                }
                out.frameLength = AVAudioFrameCount(got)
                try file.write(from: out)
                written += Int64(got)
                done += got
            }
            if done > 0 { segmentsWritten += 1 }
        }
        try pad(to: total)
        return Report(frames: written, segmentsWritten: segmentsWritten)
    }
}
#endif
