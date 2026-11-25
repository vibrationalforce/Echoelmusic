import EchoelCore
import EchoelDSP
import EchoelHost
import Foundation

/// The reading half of Slice to Pads (the break slicer, EchoelTools A11): where hits begin in a
/// sampler's file, by `OnsetDetector`, and the loop's tempo, by `TempoDetector` and the file's
/// name (`TempoHint`). A plain function on no actor — the caller runs it off the main thread,
/// because a long file takes a while to read. The file stays as it is; what is found becomes
/// slices through the one door (`BreakSlicing.commands`).
enum BreakOnsets {
    struct Reading: Sendable {
        /// Where sounds begin, in seconds of the file, rising.
        var onsets: [Double]
        /// The loop's tempo when it was heard or its name states one; nil otherwise.
        var bpm: Double?
    }

    /// The hits and the tempo of the audio file at `url`, counted in bars of `beatsPerBar`
    /// quarter notes; none when it cannot be read.
    static func read(_ url: URL, name: String, beatsPerBar: Double) -> Reading {
        guard let mono = try? SampleFile.readMono(url, maximumSeconds: AudioFileImport.maximumSeconds,
                                                  maximumFrames: AudioFileImport.maximumFrames) else {
            return Reading(onsets: [], bpm: AudioRegion.nativeBPM(heard: TempoHint.bpm(inName: name)))
        }
        var detector = OnsetDetector(sampleRate: mono.sampleRate)
        detector.process(mono.samples)
        let heard = TempoDetector.detect(mono.samples, sampleRate: mono.sampleRate, beatsPerBar: beatsPerBar)
        let bpm = AudioRegion.nativeBPM(heard: TempoHint.resolve(name: name, heard: heard?.bpm))
        return Reading(onsets: detector.onsets, bpm: bpm)
    }
}
