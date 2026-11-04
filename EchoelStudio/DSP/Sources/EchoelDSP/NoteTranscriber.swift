import Foundation

/// One note heard in a recording by `NoteTranscriber`: where it starts and how long it lasts, in
/// seconds from the first sample, its pitch as the median fundamental of its frames, and a
/// velocity from its loudest moment.
public struct TranscribedNote: Equatable, Sendable {
    public var start: Double
    public var length: Double
    /// The median fundamental over the note, in hertz.
    public var hertz: Double
    /// 1 … 127, from the note's loudest 5 ms (`NoteTranscriber.velocity(forDecibels:)`).
    public var velocity: Int

    public init(start: Double, length: Double, hertz: Double, velocity: Int) {
        self.start = start
        self.length = length
        self.hertz = hertz
        self.velocity = velocity
    }
}

/// What `NoteTranscriber` heard: the notes, rising, and how much of the sounding recording had
/// one clear pitch — low for a chord, a drum loop or noise, where only the leading voice (or
/// nothing) is found.
public struct Transcription: Equatable, Sendable {
    public var notes: [TranscribedNote]
    /// Of the frames loud enough to sound, the share with one pitch, 0 … 1; 1 when nothing sounds.
    public var voicedShare: Double

    public init(notes: [TranscribedNote], voicedShare: Double) {
        self.notes = notes
        self.voicedShare = voicedShare
    }
}

/// Audio to MIDI for ONE voice (A2M, 2026-11-04): a melody sung, whistled or played on a
/// single-note instrument becomes notes. No model and no dependency — three measurements that
/// already exist, combined by rules:
///
/// - the pitch, frame by frame, from `PitchTracker` (YIN), each reading placed at the middle of
///   the window it measured, so the tracker's latency does not move the notes;
/// - the level of every hop (5 ms) as RMS — it decides where sound starts and stops, with
///   hysteresis (a higher level to start than to keep sounding) so a note's tail does not flutter,
///   and the velocity;
/// - the onsets from `OnsetDetector`, which split a repeated note of the same pitch where it is
///   struck again, and pin a note's start to the millisecond.
///
/// Inside a sounding stretch a note changes pitch only when the new pitch holds for
/// `changeFrames` frames and lies more than `changeSemitones` away from the note's median, so
/// vibrato and a scoop stay one note. Frames without a clear pitch (a consonant, a breath, a
/// chord) are a gap: a short one is bridged, a longer one ends the note. Notes shorter than
/// `minimumLength` are dropped. Pure arithmetic: the same samples always give the same notes.
///
/// Offline only — it allocates. Polyphonic material is not separated; on a chord YIN finds one
/// pitch at best, and `voicedShare` says how little of the recording had one.
public enum NoteTranscriber {
    /// A pitch must leave the note's median by more than this to start a new note …
    public static let changeSemitones = 0.7
    /// … and stay there for this many frames (about 21 ms at 48 kHz).
    public static let changeFrames = 4
    /// A gap without pitch inside sound is bridged up to this long, in seconds.
    public static let maximumGap = 0.05
    /// The shortest note kept, in seconds.
    public static let minimumLength = 0.06
    /// The fewest frames with a pitch a note must have.
    public static let minimumVoicedFrames = 3
    /// Sound starts this far below the recording's loudest frame, and never below `floorDecibels`.
    public static let startBelowPeak = 40.0
    public static let floorDecibels = -60.0
    /// Sound stops this far below where it starts (the hysteresis).
    public static let stopBelowStart = 8.0
    /// An onset this close to a note's start, in seconds, is where the note starts.
    public static let onsetReach = 0.03
    /// An onset splits a note only where the level rises by this much around it, in dB — a new
    /// stroke, not a wobble of the same tone.
    public static let reattackRise = 6.0

    /// The velocity of a note whose loudest frame is `decibels` dBFS (RMS): −54 dB and below is 1,
    /// −6 dB and above 127, in proportion between.
    public static func velocity(forDecibels decibels: Double) -> Int {
        guard decibels.isFinite else { return 1 }
        let share = Swift.min(Swift.max((decibels + 54) / 48, 0), 1)
        return Swift.min(Swift.max(1 + Int((126 * share).rounded()), 1), 127)
    }

    /// The notes in `samples`; nil when `isCancelled` returned true (it is asked once per hop).
    public static func transcribe(_ samples: [Float], sampleRate: Double,
                                  isCancelled: () -> Bool = { false }) -> Transcription? {
        let rate = sampleRate.isFinite && sampleRate >= 8_000 ? sampleRate : 48_000
        let tracker = PitchTracker(sampleRate: rate)
        let hop = tracker.hop
        let frameCount = samples.count / hop
        guard frameCount > 0 else { return Transcription(notes: [], voicedShare: 1) }

        // The tracker's window in input samples (`PitchTracker`: two periods of its lowest pitch,
        // in averaged samples). A reading describes the window that ends where it is taken.
        let analysedRate = rate / Double(tracker.factor)
        let window = 2 * Int(analysedRate / PitchTracker.minimumHertz) * tracker.factor

        var level = [Double](repeating: -200, count: frameCount)
        var hertz = [Double](repeating: 0, count: frameCount)
        var onsetDetector = OnsetDetector(sampleRate: rate)
        for frame in 0..<frameCount {
            if isCancelled() { return nil }
            let first = frame * hop
            var energy = 0.0
            for index in first..<(first + hop) {
                let raw = samples[index]
                let sample = raw.isFinite ? raw : 0
                energy += Double(sample) * Double(sample)
                if tracker.push(sample) {
                    let centre = index + 1 - window / 2
                    if centre >= 0, tracker.period > 0 {
                        let at = centre / hop
                        if at < frameCount { hertz[at] = tracker.frequency }
                    }
                }
            }
            let rms = (energy / Double(hop)).squareRoot()
            level[frame] = rms > 1e-10 ? 20 * Foundation.log10(rms) : -200
            samples.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress { onsetDetector.process(base + first, count: hop) }
            }
        }
        let onsets = onsetDetector.onsets
        let seconds = Double(hop) / rate

        guard let peak = level.max(), peak > floorDecibels else { return Transcription(notes: [], voicedShare: 1) }
        let startLevel = Swift.max(floorDecibels, peak - startBelowPeak)
        let stopLevel = startLevel - stopBelowStart
        let gapFrames = Swift.max(1, Int((maximumGap / seconds).rounded()))

        var segments: [Segment] = []
        var current: Segment?
        var pending: [(frame: Int, midi: Double)] = []
        var sounding = false
        var soundStart = 0
        var unvoicedRun = 0
        var soundingFrames = 0, voicedFrames = 0

        func close(at end: Int) {
            if var note = current {
                note.end = end
                segments.append(note)
            }
            current = nil
            pending.removeAll()
        }

        for frame in 0..<frameCount {
            if isCancelled() { return nil }
            let wasSounding = sounding
            sounding = wasSounding ? level[frame] >= stopLevel : level[frame] >= startLevel
            if !sounding {
                if wasSounding { close(at: frame) }
                unvoicedRun = 0
                continue
            }
            if !wasSounding { soundStart = frame }
            soundingFrames += 1
            guard hertz[frame] > 0 else {
                unvoicedRun += 1
                if unvoicedRun == gapFrames + 1, let note = current {
                    // The gap is too long to bridge: the note ended where its pitch did.
                    close(at: Swift.max(note.start + 1, frame - gapFrames))
                    soundStart = frame + 1
                }
                continue
            }
            voicedFrames += 1
            unvoicedRun = 0
            let midi = 69 + 12 * Foundation.log2(hertz[frame] / 440)
            guard var note = current else {
                // A note begins where its sound did, if that was only the tracker's latency ago.
                let lead = Int((Double(window) / Double(hop)).rounded()) + 2
                let start = frame - soundStart <= lead ? soundStart : frame
                var first = Segment(start: start)
                first.add(midi, frame: frame, level: level[frame])
                current = first
                continue
            }
            if Swift.abs(midi - note.median) <= changeSemitones {
                pending.removeAll()
                note.add(midi, frame: frame, level: level[frame])
                current = note
                continue
            }
            if let last = pending.last, Swift.abs(midi - last.midi) > changeSemitones { pending.removeAll() }
            pending.append((frame, midi))
            if pending.count >= changeFrames {
                let change = pending[0].frame
                let moved = pending
                close(at: change)
                var next = Segment(start: change)
                for entry in moved { next.add(entry.midi, frame: entry.frame, level: level[entry.frame]) }
                current = next
            }
        }
        close(at: frameCount)

        var notes: [TranscribedNote] = []
        for segment in segments {
            for piece in split(segment, at: onsets, level: level, seconds: seconds) {
                guard piece.frames.count >= minimumVoicedFrames else { continue }
                var start = Double(piece.start) * seconds
                let end = Double(piece.end) * seconds
                if let onset = onsets.min(by: { Swift.abs($0 - start) < Swift.abs($1 - start) }),
                   Swift.abs(onset - start) <= onsetReach, onset < end {
                    start = onset
                }
                guard end - start >= minimumLength else { continue }
                let median = piece.median
                notes.append(TranscribedNote(start: start, length: end - start,
                                             hertz: 440 * Foundation.pow(2, (median - 69) / 12),
                                             velocity: velocity(forDecibels: piece.loudest)))
            }
        }
        let share = soundingFrames > 0 ? Double(voicedFrames) / Double(soundingFrames) : 1
        return Transcription(notes: notes, voicedShare: share)
    }

    /// A stretch of frames with one pitch: frames `start ..< end`, the pitches of its voiced frames
    /// (MIDI, fractional) kept sorted for the median, and its loudest frame in dB.
    struct Segment {
        var start: Int
        var end: Int
        var frames: [Double] = []
        var loudest = -200.0
        /// Pitches with the frame each came from, for a split.
        var voiced: [(frame: Int, midi: Double, level: Double)] = []

        init(start: Int) {
            self.start = start
            end = start
        }

        /// A voiced frame: its pitch joins the median, and the stretch reaches past it.
        mutating func add(_ midi: Double, frame: Int, level: Double) {
            let at = frames.firstIndex(where: { $0 > midi }) ?? frames.count
            frames.insert(midi, at: at)
            loudest = Swift.max(loudest, level)
            voiced.append((frame, midi, level))
            end = Swift.max(end, frame + 1)
        }

        var median: Double {
            guard !frames.isEmpty else { return 0 }
            let middle = frames.count / 2
            return frames.count % 2 == 1 ? frames[middle] : (frames[middle - 1] + frames[middle]) / 2
        }
    }

    /// `segment` cut where a new stroke of the same pitch begins: an onset at least the shortest
    /// note from either end, where the level rises by `reattackRise` from just before to just after.
    static func split(_ segment: Segment, at onsets: [Double], level: [Double], seconds: Double) -> [Segment] {
        let shortest = Int((minimumLength / seconds).rounded(.up))
        var cuts: [Int] = []
        for onset in onsets {
            let frame = Int((onset / seconds).rounded())
            guard frame - segment.start >= shortest, segment.end - frame >= shortest,
                  frame - (cuts.last ?? segment.start) >= shortest else { continue }
            let before = level[Swift.max(segment.start, frame - 4)...frame].min() ?? 0
            let after = level[frame...Swift.min(level.count - 1, frame + 6)].max() ?? 0
            if after - before >= reattackRise { cuts.append(frame) }
        }
        guard !cuts.isEmpty else { return [segment] }
        var pieces: [Segment] = []
        var from = segment.start
        for stop in cuts + [segment.end] {
            var piece = Segment(start: from)
            for entry in segment.voiced where entry.frame >= from && entry.frame < stop {
                piece.add(entry.midi, frame: entry.frame, level: entry.level)
            }
            piece.end = stop
            pieces.append(piece)
            from = stop
        }
        return pieces
    }
}
