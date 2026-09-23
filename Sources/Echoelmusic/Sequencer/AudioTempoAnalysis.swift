// AudioTempoAnalysis.swift
// Echoel — reads an imported file's MANAGED COPY into `TempoOnsetEnvelope` and asks
// `TempoDetector` for its native tempo. The file-reading twin of `AudioKeyAnalysis`, and
// deliberately the same shape: an impure `analyse(url:)` over AVFoundation, a pure
// `summarise(_:)` that decides every word the person sees.
//
// ⛔ OFFLINE ONLY. It reads up to `analysisSeconds` of audio and runs an O(n · lags)
// autocorrelation — seconds of work. Its one production caller runs it on
// `Task.detached(priority: .utility)`; it must never be reached from a view `body`, the main
// actor's hot path or a render callback. `Task.isCancelled` is checked per chunk so a
// superseded import stops reading.
//
// ⛔ IT WRITES NOTHING. It returns a `DetectedTempo?`; whether a clip adopts it is decided by
// `adoptableNativeBPM` below and written by `ClipStore.adoptDetectedNativeBPM` — never the
// transport, never `SessionContext`.

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public enum AudioTempoAnalysis {

    /// Longest stretch of audio analysed. Longer media is analysed from its MIDDLE — an intro
    /// or outro is the part of a song most likely to have no beat.
    public static let analysisSeconds: Double = 90

    /// The sentence appended to the import note, or nil when there is nothing to say
    /// (the file was too short or silent — a one-shot has no tempo, and saying so is noise).
    ///
    /// ⚠️ An UNKNOWN estimate says "Tempo unclear" rather than printing the number with a
    /// warning: a person who sees a BPM will use it, whatever the caveat beside it.
    public static func summarise(_ tempo: DetectedTempo?) -> String? {
        guard let tempo else { return nil }
        guard tempo.isKnown else { return "Tempo unclear." }
        let bpm = String(format: "%.1f", tempo.bpm)
        let alternative = String(format: "%.1f", tempo.octaveAlternativeBPM)
        if let bars = tempo.loopBars {
            return "Tempo ≈ \(bpm) BPM, a \(bars)-bar loop (or \(alternative))."
        }
        return "Tempo ≈ \(bpm) BPM (or \(alternative))."
    }

    /// The native tempo a clip may ADOPT from a detection, or nil to leave the clip alone.
    /// Pure, so the decision is driven by the blocking bundle with plain values; its one
    /// writer is `ClipStore.adoptDetectedNativeBPM`, which asks this and nothing else.
    ///
    /// ⚠️ NEVER-CLOBBER. A clip that already carries a native tempo keeps it — whoever or
    /// whatever set it, a detection does not get to overrule it. This is what keeps a detected
    /// fact from silently replacing an authored one once an authored writer exists.
    ///
    /// ⚠️ ONLY `isKnown`. An UNKNOWN estimate writes nothing, so its number never becomes a
    /// warp rate. A clip whose tempo stays 0 simply cannot warp, which is the honest state.
    public static func adoptableNativeBPM(current: Double, detected: DetectedTempo?) -> Double? {
        guard current.isFinite, current == 0 else { return nil }
        guard let detected, detected.isKnown else { return nil }
        let bpm = Clip.clampedNativeBPM(detected.bpm)
        return bpm > 0 ? bpm : nil
    }

    #if canImport(AVFoundation)

    /// The native tempo of the audio at `url`, or nil if it cannot be read or has no onsets.
    public static func analyse(url: URL) -> DetectedTempo? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        guard sampleRate.isFinite, sampleRate > 0, channelCount > 0,
              var envelope = TempoOnsetEnvelope(sampleRate: sampleRate,
                                                maxSeconds: analysisSeconds) else { return nil }

        let total = file.length
        guard total > 0 else { return nil }
        let window = Int64((analysisSeconds * sampleRate).rounded(.down))
        file.framePosition = total > window ? (total - window) / 2 : 0

        let chunk: AVAudioFrameCount = 16_384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return nil }
        var mono = [Float](repeating: 0, count: Int(chunk))
        let scale = 1 / Float(channelCount)

        while !envelope.isFull {
            if Task.isCancelled { return nil }
            do {
                try file.read(into: buffer, frameCount: chunk)
            } catch {
                break
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channels = buffer.floatChannelData else { break }
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channelCount { sum += channels[c][i] }
                mono[i] = sum * scale
            }
            envelope.append(mono[0..<frames])
        }

        return TempoDetector.estimate(envelope: envelope.values,
                                      envelopeRate: envelope.rate,
                                      mediaDurationSeconds: Double(total) / sampleRate)
    }

    #endif
}
