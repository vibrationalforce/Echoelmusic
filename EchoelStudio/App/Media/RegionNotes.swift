import EchoelCore
import EchoelDSP
import EchoelHost
import Foundation

/// The hearing half of Convert to MIDI (A2M): the notes one voice plays in an audio region, by
/// EchoelDSP's `NoteTranscriber` over the frames the region plays. A plain function on no actor —
/// the caller runs it off the main thread and may cancel it; what is heard becomes a clip through
/// the one door (`AudioToMIDI.commands`).
enum RegionNotes {
    struct Heard: Sendable {
        var notes: [HeardNote]
        /// The share of the sounding frames that had one clear pitch (`Transcription.voicedShare`).
        var voicedShare: Double
    }

    /// The notes in frames `offset ..< offset + length` of the file at `url`; nil when it cannot
    /// be read, holds none of those frames, or the reading was cancelled.
    static func notes(of url: URL, offset: Int, length: Int, isCancelled: () -> Bool) -> Heard? {
        guard let mono = try? SampleFile.readMono(url, maximumSeconds: AudioFileImport.maximumSeconds,
                                                  maximumFrames: AudioFileImport.maximumFrames) else { return nil }
        let first = Swift.min(Swift.max(0, offset), mono.samples.count)
        let last = Swift.min(mono.samples.count, first + Swift.max(0, length))
        guard last > first, !isCancelled() else { return nil }
        let frames = Array(mono.samples[first..<last])
        guard let heard = NoteTranscriber.transcribe(frames, sampleRate: mono.sampleRate, isCancelled: isCancelled) else {
            return nil
        }
        let notes = heard.notes.map { HeardNote(start: $0.start, length: $0.length, hertz: $0.hertz, velocity: $0.velocity) }
        return Heard(notes: notes, voicedShare: heard.voicedShare)
    }
}
