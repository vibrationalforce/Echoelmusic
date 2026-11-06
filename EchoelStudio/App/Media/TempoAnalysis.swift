import EchoelCore
import EchoelDSP
import EchoelHost
import Foundation

/// The hearing half of warp (W-1): the tempo an audio region's file was played at, by EchoelDSP's
/// `TempoDetector` over the frames the region plays. A plain function on no actor — the caller
/// runs it off the main thread and may cancel it, like `RegionNotes`; what is heard becomes the
/// region's native tempo through the one door (`Command.setRegionWarp`).
enum TempoAnalysis {
    /// The tempo of frames `offset ..< offset + length` of the file at `url`, in bars of
    /// `beatsPerBar` quarter notes; nil when it cannot be read, holds none of those frames, has no
    /// steady pulse, or the reading was cancelled.
    static func tempo(of url: URL, offset: Int, length: Int, beatsPerBar: Double,
                      isCancelled: () -> Bool) -> DetectedTempo? {
        guard let mono = try? SampleFile.readMono(url, maximumSeconds: AudioFileImport.maximumSeconds,
                                                  maximumFrames: AudioFileImport.maximumFrames) else { return nil }
        let first = Swift.min(Swift.max(0, offset), mono.samples.count)
        let last = Swift.min(mono.samples.count, first + Swift.max(0, length))
        guard last > first, !isCancelled() else { return nil }
        let frames = Array(mono.samples[first..<last])
        return TempoDetector.detect(frames, sampleRate: mono.sampleRate, beatsPerBar: beatsPerBar, isCancelled: isCancelled)
    }

    /// Quarter notes in the bar at `tick` of the song's meter: what a heard loop is counted in.
    static func beatsPerBar(at tick: Tick, in project: Project) -> Double {
        let bar = project.meterMap.ticksPerBar(at: tick)
        guard bar > 0 else { return 4 }
        return Double(bar) / Double(MusicalTime.ticksPerQuarter)
    }
}
