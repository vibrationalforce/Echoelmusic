// AudioKeyAnalysis.swift
// Echoel — the PRODUCER that `TuningDetector` never had.
//
// ⭐ WHY THIS FILE EXISTS, AND WHY IT IS NOT A NEW ALGORITHM. Two pure, unit-tested types
// have been sitting in this repo with ZERO production callers, and they are the two halves
// of ONE capability: `DSP/PitchTracker` (YIN) produces exactly what
// `Core/TuningDetector.analyze(frequencies:)` (Krumhansl–Kessler) consumes — a list of
// fundamental frequencies in Hz. What was missing was never an estimator. It was the
// ability to READ PCM WINDOWS OUT OF A FILE. This file is that, and nothing else:
// window arithmetic that is pure, one decoder hop that is not, and no third estimator
// (#416 — whoever needs detected key uses `TuningDetector`, not a new one).
//
// ⛔ AND THE PRODUCER IS NOT A MICROPHONE. `TuningDetector`'s header used to name
// `MicrophoneManager.pitch`, deleted with #1302 (founder 2026-09-12, "Face und Audio Input
// komplett entfernen"), and the deletion is structural: `RecordRouteOwner` is an
// uninhabited enum, so the session can never rise to `.playAndRecord`. Audio input is a
// FOUNDER HOLD (`memory/decisions.md`, 2026-09-22). The producer is the IMPORTED FILE —
// Audio Import V1 (2026-09-22) made `AudioImport` the first user-reachable creator of an
// audio-bearing clip, and a managed copy on disk can be analysed at leisure.
//
// ⚠️ REALTIME LAW — THE REASON THIS IS NOT FOLDED INTO `AudioImport`. `AudioImport.perform`
// is `@MainActor` and synchronous. YIN is O(n·τ) per window; a few dozen windows is
// hundreds of millions of double operations, i.e. entire seconds. Running that inside the
// import transaction would freeze the door at the exact moment the user is watching it —
// the 10.76.48 lesson (never do per-item work on the main actor from a producer) in bulk
// form. Nothing here may be called from a render block, an audio tap, or the main actor.
// `analyse` is `nonisolated` and its one caller hops off first.
//
// ⚠️ AND IT IS NOT IN `DSP/`, DELIBERATELY. `DSP/` imports Foundation and Accelerate and
// nothing else, and the AUv3 extension compiles that directory in ISOLATION — a DSP file
// that reaches for AVFoundation is a BUILD failure there, not merely a hygiene lapse
// (`.claude/rules/swift-audio.md`). `PitchTracker` stays where it is; the decoder hop
// lives here, next to `AudioImport`, which already imports AVFoundation.
//
// ⭐ WHAT THIS DELIBERATELY DOES NOT DO: it never writes. `SessionContext` owns the musical
// key (`echoel.keyRoot` / `echoel.keyScale` / `echoel.a4Hz`) and stays the ONE owner.
// Detection REPORTS and the user DECIDES — `TuningDetector`'s own header already draws that
// line ("the UI lets the user confirm"). Silently re-keying a session because a file was
// imported would make the import an author of the song's key with nothing on screen saying
// so, and a control whose effect the user cannot see is the #164/#227 shape.
//
// ⚠️ NOR DOES IT ESTIMATE TEMPO. Audio Import V1's decision 7 was `nativeBPM = 0`, no
// estimate. A key detector that quietly also guessed BPM would reverse a founder decision
// from the adjacent slice.

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public enum AudioKeyAnalysis {

    // MARK: - Constants (named, because each one is a claim)

    /// The lowest fundamental the analysis looks for, in Hz. It is `PitchTracker`'s own
    /// default and is repeated here because `windowFrames(forSampleRate:)` DERIVES from it —
    /// the two must move together or every window silently returns nil (see that function).
    public static let minHz: Double = 50

    /// How many windows are read from one file, at most. It bounds BOTH the memory read and
    /// the YIN work, and it is the difference between "a second of analysis" and "an
    /// unbounded read of a two-hour file" — the failure mode this constant exists for.
    public static let maxWindows = 64

    // MARK: - Pure arithmetic (Foundation only — drivable without a file)

    /// The analysis window, in frames, for a file at `sampleRate`.
    ///
    /// ⚠️ THIS IS NOT A TUNING KNOB — IT IS A PRECONDITION OF `PitchTracker.detect`. That
    /// function computes `tauMax = min(n - 1, Int(sampleRate / minHz))` and then REFUSES
    /// unless `n >= tauMax * 2`. So a window that is fine at 44.1 kHz returns nil at every
    /// position of a 96 kHz file, and the failure is silent: no error, no log, just an empty
    /// list of fundamentals and a nil key. A fixed literal here would work on the machines
    /// anyone tests with and quietly do nothing on a high-rate file.
    ///
    /// The window is the next power of two at or above `2 · (sampleRate / minHz) + 2`,
    /// clamped so that neither a broken rate nor an absurd one can size an allocation.
    ///
    /// ⚠️ THE CEILING IS 32,768 AND THAT NUMBER WAS MEASURED, NOT PICKED. A first draft
    /// clamped at 16,384, which LOOKS generous and silently breaks the precondition above
    /// 327 kHz: `tauMax` keeps growing with the sample rate while the window stops, so at
    /// 768 kHz every window returns nil and the file simply has no detectable key — no
    /// error, no log. 32,768 keeps the precondition true for every rate `AVAudioFile` can
    /// present (it fails only above ~819 kHz, which no format reaches), and the cost is one
    /// 128 KB buffer per channel at a rate nothing actually uses. **A clamp that turns a
    /// correctness precondition into a silent nil is not a safety margin.**
    public static func windowFrames(forSampleRate sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else { return 2048 }
        let needed = 2 * Int(sampleRate / minHz) + 2
        var n = 2048
        while n < needed, n < 32_768 { n *= 2 }
        return Swift.min(n, 32_768)
    }

    /// Evenly spaced start frames for the windows to read, ascending, never running past the
    /// end of the file.
    ///
    /// ⚠️ THE WINDOWS DO NOT OVERLAP, and that is a correctness property rather than an
    /// efficiency one: the output feeds a PITCH-CLASS HISTOGRAM, so reading the same audio
    /// twice would weight whatever note happens to be there twice. The count is therefore
    /// capped by how many whole windows the file actually contains, not only by
    /// `maxWindows`.
    ///
    /// Returns an empty array for a file shorter than one window — "no evidence" rather than
    /// a short read, so the caller's nil means the same thing in both cases.
    public static func windowStarts(frameCount: Int64,
                                    windowFrames: Int,
                                    maxWindows: Int) -> [Int64] {
        guard windowFrames > 0, maxWindows > 0 else { return [] }
        let window = Int64(windowFrames)
        guard frameCount >= window else { return [] }

        let whole = Int(frameCount / window)
        let count = Swift.max(1, Swift.min(maxWindows, whole))
        let lastStart = frameCount - window
        guard count > 1 else { return [0] }

        var starts: [Int64] = []
        starts.reserveCapacity(count)
        for i in 0..<count {
            // Integer arithmetic on the INDEX, not a repeated stride, so rounding cannot
            // accumulate and the final start is exactly `lastStart`.
            let start = lastStart * Int64(i) / Int64(count - 1)
            if let previous = starts.last, start <= previous { continue }
            starts.append(start)
        }
        return starts
    }

    // MARK: - How sure is sure enough (#F3)

    /// The winning correlation below which no key is named. ⚠️ A JUDGEMENT, NOT A
    /// MEASUREMENT, and it is named rather than inlined so it can be argued with. A clearly
    /// tonal excerpt correlates ≈0.6–0.9 with its own Krumhansl profile; unpitched or
    /// atonal material lands near 0. Half of the achievable range is where "this has a
    /// tonal centre" stops being evidence. [NEEDS-FOUNDER-VERIFY]
    public static let keyConfidenceFloor: Double = 0.5

    /// The lead over the runner-up below which no key is named. ⚠️ ALSO A JUDGEMENT.
    /// Relative (C major / A minor) and parallel (C major / C minor) keys share most of
    /// their pitch classes, so their correlations sit close by construction — a lead this
    /// small means the material fits two keys equally and the winner is whichever one the
    /// loop reached first. [NEEDS-FOUNDER-VERIFY]
    public static let keyMarginFloor: Double = 0.05

    /// The ONE place the user-facing phrasing lives (#416). nil in ⇒ nil out: a thin
    /// estimate says NOTHING rather than guessing, which is what `analyze`'s nil return is
    /// for.
    ///
    /// ⚠️ THE WORDING IS A SUGGESTION ON PURPOSE. "sounds like" rather than "key:" — the
    /// estimate is a correlation over a pitch-class histogram, it is sometimes wrong, and
    /// nothing in the app acts on it. Prose that asserted it would be a claim the code
    /// cannot keep.
    ///
    /// ⛔ AND UNTIL #F3 THAT HEDGE WAS THE ONLY ONE, WHICH MADE IT A FIG LEAF. This function
    /// read `keyName` and `snappedA4` and never `confidence`, so it printed the same
    /// sentence at correlation 0.9 and at correlation 0.0 — and 0.0 is reachable:
    /// `analyze` returns non-nil on ≥8 valid pitches with NO floor on the correlation,
    /// `correlation` returns 0 for a flat histogram, `bestCorr` starts at −2.0 and the
    /// first candidate tried is root 0 major. So a drum loop that yields eight YIN hits
    /// was reported as "Sounds like C major" — a named key produced by the iteration order,
    /// not by the audio. `confidence` had ZERO readers in `Sources/` at the time.
    ///
    /// ⭐ THE KEY AND THE KAMMERTON ARE SEPARATE FACTS WITH SEPARATE EVIDENCE, so they are
    /// gated separately — the single most useful thing in this function. A4 comes from the
    /// CIRCULAR MEAN of each pitch's cents-deviation and never touches the key correlation,
    /// so a percussive file can have a trustworthy tuning reference and no key at all.
    /// Collapsing both behind one threshold would throw away a good measurement to hide a
    /// bad one.
    ///
    /// ⚠️ WHAT IS *NOT* GATED HERE, stated so nobody reads this as "both halves are now
    /// validated": the A4 half has no evidence measure of its own. The honest one is the
    /// circular-mean RESULTANT LENGTH (how concentrated the cents-deviations are), and
    /// `analyze` does not compute it — it keeps `sumSin`/`sumCos` only long enough to take
    /// the angle. A separate slice, deliberately: two weak gates are worse than one real
    /// one.
    public static func summarise(_ tuning: DetectedTuning?) -> String? {
        guard let tuning else { return nil }
        let a4 = Int(tuning.snappedA4().rounded())
        if tuning.confidence < keyConfidenceFloor {
            return "Key unclear — little tonal centre. A4 ≈ \(a4) Hz."
        }
        if tuning.keyMargin < keyMarginFloor {
            return "Key ambiguous — two keys fit equally well. A4 ≈ \(a4) Hz."
        }
        return "Sounds like \(tuning.keyName), A4 ≈ \(a4) Hz."
    }

    // MARK: - The one impure step

    #if canImport(AVFoundation)

    /// Read up to `maxWindows` windows spread across `url`, estimate a fundamental for each,
    /// and hand the survivors to `TuningDetector`. Returns nil when the file cannot be
    /// opened, is shorter than a window, or yields too little pitched material.
    ///
    /// ⚠️ NON-ISOLATED BY CONSTRUCTION, AND NEVER CALLED FROM THE MAIN ACTOR — see the
    /// realtime note in this file's header. The isolation is a fact about the TYPE rather
    /// than a keyword: `AudioKeyAnalysis` is a plain `enum` with no global actor, so this
    /// function already runs wherever its caller runs, and spelling `nonisolated` here would
    /// only be redundant. That is exactly why the discipline has to live at the CALL SITE —
    /// nothing in this signature can stop someone calling it from `body`. It is also never
    /// called from a render block or an audio tap: it opens a file, which is forbidden on
    /// the audio thread outright.
    ///
    /// ⚠️ NO RESAMPLING. `processingFormat` is already float32 deinterleaved, and the file's
    /// OWN sample rate is handed to `PitchTracker`, so a converter would add a failure mode
    /// (and an allocation) to buy nothing. Channels are averaged down to mono; a hard-panned
    /// instrument would otherwise be analysed at half amplitude on one side and vanish under
    /// the energy gate.
    public static func analyse(url: URL) -> DetectedTuning? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate.isFinite, sampleRate > 0, format.channelCount > 0 else { return nil }

        let window = windowFrames(forSampleRate: sampleRate)
        let starts = windowStarts(frameCount: file.length,
                                  windowFrames: window,
                                  maxWindows: maxWindows)
        guard !starts.isEmpty else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(window)) else {
            return nil
        }

        var fundamentals: [Double] = []
        fundamentals.reserveCapacity(starts.count)
        var mono = [Float](repeating: 0, count: window)

        for start in starts {
            // ⚠️ THE ONLY CANCELLATION POINT. `analyse` is synchronous, so a superseded
            // import would otherwise keep a core busy for the full run with an answer
            // nobody will read. Checked per WINDOW rather than per file because the
            // per-file granularity is the whole cost.
            if Task.isCancelled { return nil }
            file.framePosition = start
            do {
                try file.read(into: buffer, frameCount: AVAudioFrameCount(window))
            } catch {
                continue
            }
            guard buffer.frameLength == AVAudioFrameCount(window),
                  let channels = buffer.floatChannelData else { continue }

            let channelCount = Int(buffer.format.channelCount)
            let scale = 1 / Float(channelCount)
            for i in 0..<window {
                var sum: Float = 0
                for c in 0..<channelCount { sum += channels[c][i] }
                mono[i] = sum * scale
            }
            if let hz = PitchTracker.detect(mono, sampleRate: sampleRate, minHz: minHz) {
                fundamentals.append(hz)
            }
        }

        return TuningDetector().analyze(frequencies: fundamentals, minHz: minHz)
    }

    #endif
}
