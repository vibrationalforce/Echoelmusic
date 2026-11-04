import EchoelCore
import EchoelDSP
import EchoelHost
import Foundation

/// The reading half of Slice to Pads (the break slicer, EchoelTools A11): where hits begin in a
/// sampler's file, by `OnsetDetector`. A plain function on no actor — the caller runs it off the
/// main thread, because a long file takes a while to read. The file stays as it is; what is found
/// becomes slices through the one door (`BreakSlicing.commands`).
enum BreakOnsets {
    /// Where sounds begin in the audio file at `url`, in seconds of the file, rising; none when it
    /// cannot be read.
    static func onsets(of url: URL) -> [Double] {
        guard let mono = try? SampleFile.readMono(url, maximumSeconds: AudioFileImport.maximumSeconds) else { return [] }
        var detector = OnsetDetector(sampleRate: mono.sampleRate)
        detector.process(mono.samples)
        return detector.onsets
    }
}
