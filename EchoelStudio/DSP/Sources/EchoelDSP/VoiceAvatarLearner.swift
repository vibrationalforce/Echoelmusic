import Foundation

/// Learns a voice avatar (`VoiceAvatar`) from a recording — a take, an imported file, a bounced
/// synth, a noise. It measures the colour of the sound and keeps nothing that runs in time, so the
/// avatar cannot play back what it was learned from. Learn only from your own voice, or from a
/// sound you may use; never from another person's voice.
///
/// **Frames.** The recording is read in frames of `frameSeconds`, one every `hopSeconds`. A frame
/// sounds when its level (RMS, its mean taken out) reaches `silenceDecibels` and lies no more than
/// `quietBelowLoudest` under the loudest frame. A sounding frame is voiced when the `PitchTracker`
/// hears one pitch in the middle of it — every reading centred there has a period, and the longest
/// is at most `agreement` times the shortest — and the frame repeats at its period (normalised
/// correlation `minimumPeriodicity` or more). Its period is the shortest of the tracker's, twice it
/// and three times it that repeats nearly as well as the best of them (within `preference`): the
/// tracker hears a vowel whose first formant sits on its second harmonic an octave too high. A
/// voiced stretch shorter than `minimumVoicedRun` frames is taken as noise. Everything else that
/// sounds is noise: breath, a consonant, a hiss.
///
/// **The voiced envelope.** Each voiced frame's spectrum (Hann window, the package's radix-2 `FFT`)
/// is wrapped by its true envelope (Röbel & Rodet, DAFx 2005): cepstral smoothing, repeated over
/// the higher of the spectrum and the last envelope, so it comes to rest on the harmonics' peaks
/// rather than on the mean between them. It keeps sampleRate / (2 · f0) cepstral coefficients, so it
/// cannot follow the harmonics themselves. Before that the valleys between harmonics are filled —
/// the highest level within half a harmonic spacing, then the lowest of those (a closing), which
/// leaves every peak where it is — the spectrum below the fundamental holds the first harmonic's
/// level, and the spectrum is reduced to `resolutionFactor` bins per kept coefficient, each reduced
/// bin keeping the highest of the bins it covers; so a frame takes four or five rounds, where the
/// bare spectrum takes about 12 to 25 (measured on the bass's vowels). The envelope is read onto the
/// avatar's band grid in decibels: the mean over the band where it covers three bins or more, else
/// the value at the band's centre. A frame measures nothing below its fundamental — those bands hold
/// the first measured band's level — nor above `measuredShare` of the sample rate, where the bands
/// read the bottom of the range.
///
/// **Snapshots.** The voiced frames are grouped by k-means, deterministically (bisecting: the group
/// whose frames lie furthest from their envelope is cut in two along the direction in which its
/// frames differ most, then by k-means; no random seed and no unordered collection is involved), as
/// long as the halves differ by `splitDecibels` and each keeps `minimumSnapshotFrames` frames, up to
/// `VoiceAvatar.maximumSnapshots`. Two envelopes are compared by `shapeDistance`: over the bands both
/// measured, and only down to `heardDecibels` below their loudest band, where a sample dropped here
/// and there no longer moves them. Frames that read alike are one group whatever note they were sung
/// on, and frames that read differently are two groups even when they are one vowel: one vowel sung
/// an octave apart (A2 and A3) stays one group for oh, ah, eh and ee, but notes a third apart near
/// 200 Hz can split, because their harmonics sample a narrow formant differently (the limits below).
/// Each group's snapshot is the mean of its frames band by band, each frame first brought to the
/// group's level; the avatar orders the snapshots from dark to bright.
///
/// **Noise.** The noise envelope is the mean power spectrum of the unvoiced frames that lie more than
/// a frame's length from any voiced one, so no note's start or end is counted in it. With fewer than
/// `minimumNoiseFrames` of them it is the voiced envelope: the breath of a voice passes through the
/// same mouth. **Breath** is the share of the sound's energy that does not repeat: all of an
/// unvoiced frame's, and 1 − periodicity of a voiced one's. **The pitch range** lies between the
/// `pitchShares` of the voiced frames' fundamentals, so a stray reading does not stretch it.
/// **The vibrato** is the swing that best explains how the pitch moves about its straight line on
/// every voiced stretch of `vibratoMinimumSeconds` or more (`vibrato(of:voiced:framesPerSecond:)`).
///
/// **Limits**, measured on the vocal tract the choir engine sings through (`VocalTract`: a bass's
/// vowels oo, oh, ah, eh and ee, each sung on a sawtooth, at 48 kHz unless said):
/// - Formants. Sung up a line of six notes from 110 to 220 Hz and pooled, the first two formants of
///   ah (600 and 1040 Hz) and eh (400 and 1620 Hz) come out within 5 %, at 44.1 and 48 kHz. On one
///   note, ah's come out within 4 % at 110 Hz and within 8 % on every note of the line, but eh's
///   first reads as low as 333 Hz (at 165 Hz). The other three vowels lose a formant: oo its second
///   (600 Hz) on every note of the line (the nearest peak lies 18 % or more below it), oh its second
///   (750 Hz) at 165 and 220 Hz, and both of them pooled over the line, where the second reads as
///   part of the first (at 347 and 399 Hz); ee's first (250 Hz) reads 187 to 230 Hz on the notes up
///   to 147 Hz and 185 Hz pooled, and is not found above, so near the fundamental. Two formants
///   within about two harmonics of the note read as one: ah's on one note at 220 Hz at 44.1 kHz (at
///   48 kHz the second is found, at 1034 Hz), and a soprano's ah (800 and 1150 Hz) on notes from 262
///   to 440 Hz, at 882 Hz.
/// - Levels. At its first six harmonics a snapshot of ah reads the tract's own levels within 1.3 dB
///   on one note at 110, 131, 220 or 247 Hz and within 2.2 dB at 165 and 196 Hz, levels aligned.
///   Read at the harmonics of a note at 220 Hz, an avatar learned at 110 Hz and one learned at
///   220 Hz agree within 2 dB for ah, eh and ee, 2.7 dB for oh and 8.3 dB for oo; between those
///   harmonics, band by band from 220 Hz to 4 kHz, where a note played at another pitch falls, they
///   differ by up to 3.3 dB for ee, 4.1 for ah, 4.6 for eh, 8.4 for oo and 10.4 for oh.
/// - Snapshots. Notes whose frames read alike are pooled; where they do not, each becomes its own
///   snapshot. Each vowel sung 0.5 s on each of two notes, 13 pairs of notes from 110 to 330 Hz:
///   14 of the 65 takes learned two snapshots, among them oo at 110 and 220 Hz, and ah, eh and oh
///   at 196 and 247 Hz, which lie 4.5 to 5.1 dB apart (`shapeDistance`). Two vowels on one note lie
///   5.8 dB or more apart, except oo and oh, 2.5 to 6 dB apart from 110 to 220 Hz against
///   `splitDecibels` = 4, so they can read as one: the five vowels of one take on one note learn
///   five snapshots from 110 to 165 Hz, four at 196 and 220 Hz.
/// - Pitch. A pitch the tracker hears an octave high reads up to 1 % sharp once brought down (eh and
///   oh at 196 Hz), one it hears right within 0.01 %. Below 70 Hz a voice is noise to the tracker
///   (`PitchTracker.minimumHertz`).
///
/// Offline: it allocates, and its cost grows with the recording — 10 s of a sung vowel took 0.29 to
/// 0.39 s in a release build on one x86 core of the build machine, about 0.5 s a second of sound in
/// a debug build (measured). At most `maximumSpectrumFrames` voiced frames, and as many noise frames,
/// are measured for their spectra, evenly spread; pitch, breath and vibrato read every frame.
/// Deterministic: the same samples at the same rate always learn the same avatar, bit for bit.
/// `isCancelled` is asked between frames; once it says yes, the learning stops and nothing is
/// learned.
public enum VoiceAvatarLearner {
    // MARK: Frames

    /// The length of one analysis frame and the step from one frame to the next, in seconds.
    public static let frameSeconds = 0.04
    public static let hopSeconds = 0.01
    /// The sample rates the learner reads.
    public static let sampleRates: ClosedRange<Double> = 8_000 ... 384_000
    /// A frame sounds when its level reaches this, in dBFS …
    public static let silenceDecibels = -60.0
    /// … and lies no further than this below the loudest frame: room tone between phrases is not
    /// part of the sound.
    public static let quietBelowLoudest = 50.0
    /// The fewest sounding frames an avatar is learned from: 0.1 s of sound.
    public static let minimumSoundingFrames = 10

    // MARK: Voicing

    /// The tracker's readings in the middle of a frame agree when the longest period is at most this
    /// many times the shortest: about half a semitone.
    static let agreement = 1.03
    /// A voiced frame repeats at its period at least this well (normalised correlation).
    static let minimumPeriodicity = 0.5
    /// A longer period replaces the one the tracker heard only when it repeats better by more than
    /// this (normalised correlation): a note that repeats at its period also repeats at twice it.
    static let preference = 0.05
    /// A voiced stretch shorter than this many frames is noise: a tracker reading a period into a
    /// consonant now and then is not a voice.
    static let minimumVoicedRun = 3

    // MARK: Envelopes

    /// How far below its loudest band a learned table reaches, in decibels. What lies further down
    /// is held there: the measurement's own floor, not the colour of the sound.
    static let rangeDecibels: Float = 80
    /// The true envelope stops when no bin of the spectrum stands more than this many decibels
    /// above it …
    static let envelopeToleranceDecibels: Float = 1
    /// … or after this many rounds.
    static let maximumEnvelopeRounds = 32
    /// The valleys between harmonics are filled over this share of a harmonic spacing either side.
    static let valleyShare = 0.5
    /// The spectrum the envelope wraps is reduced to this many bins per cepstral coefficient the
    /// envelope keeps, never below the frame's own resolution.
    static let resolutionFactor = 4
    /// Bands above this share of the sample rate are not measured.
    static let measuredShare = 0.45
    /// At most this many voiced frames, and as many noise frames, are measured for their spectra: a
    /// minute of each, evenly spread over the recording.
    static let maximumSpectrumFrames = 6_000

    // MARK: Snapshots

    /// Two groups of voiced frames are two snapshots only when their envelopes differ by at least
    /// this much (`shapeDistance`, in decibels). Measured on the bass's vowels: one vowel sung at A2
    /// and at A3 differs by 1.5 to 2.6 (ee, ah, eh, oh), oo by 4.1; two vowels on one note differ by
    /// 5.8 or more, but oo and oh by only 2.5 to 6 from 110 to 220 Hz …
    static let splitDecibels: Float = 4
    /// … and each holds at least this many frames.
    static let minimumSnapshotFrames = 5
    /// Two envelopes are compared down to this far below their loudest band, in decibels. Further
    /// down a measurement wavers most: compared all the way down, the two vowels of a take with one
    /// sample in about 10 000 dropped learn four snapshots instead of two (measured).
    static let heardDecibels: Float = 50
    /// Rounds of k-means after the groups are found, and in each cut.
    static let maximumRefinements = 20
    /// Fewer clean noise frames than this, and the noise envelope is the voiced one.
    static let minimumNoiseFrames = 10

    // MARK: Pitch and vibrato

    /// The pitch range lies between these shares of the voiced frames' fundamentals.
    static let pitchShares = (lowest: 0.05, highest: 0.95)
    /// The vibrato rates tried, in hertz, and the step between two of them.
    static let vibratoRates: ClosedRange<Double> = 3 ... 12
    static let vibratoRateStep = 0.05
    /// A voiced stretch is read for vibrato when it lasts at least this long, in seconds, and its
    /// pitch never jumps `vibratoJumpCents` from one frame to the next.
    static let vibratoMinimumSeconds = 0.5
    static let vibratoJumpCents = 100.0
    /// A vibrato is found when its swing explains at least this share of how the pitch moves about
    /// its line, and swings at least `vibratoMinimumCents` either way.
    static let vibratoMinimumShare = 0.5
    static let vibratoMinimumCents = 5.0

    /// Why nothing was learned. Nothing is half learned: a learning that fails leaves no avatar.
    public enum Failure: Error, Equatable, Sendable {
        /// `isCancelled` said stop.
        case cancelled
        /// The sample rate is not a number, or lies outside `sampleRates`.
        case unsupportedSampleRate
        /// The recording is too short, or too little of it sounds: fewer than
        /// `minimumSoundingFrames` frames.
        case tooShort
        /// Nothing in it sounds: every frame lies below `silenceDecibels`.
        case silent
        /// The avatar refused what it was given (`VoiceAvatar.Refusal`): the label is checked
        /// before anything is listened to.
        case refused(VoiceAvatar.Refusal)
    }

    /// The avatar of `samples`, one channel at `sampleRate`, called `label`, from `origin`. Samples
    /// that are not finite are silence. An avatar without a voiced snapshot holds no voice, so it is
    /// a sound's: `ownVoice` becomes `sound` there — the learner never says it measured a voice it
    /// did not hear — and `factory` stays. `isCancelled` is asked between frames.
    public static func learn(from samples: [Float], sampleRate: Double, label: String, origin: VoiceAvatar.Origin,
                             isCancelled: () -> Bool = { false }) throws(Failure) -> VoiceAvatar {
        guard sampleRate.isFinite, sampleRates.contains(sampleRate) else { throw .unsupportedSampleRate }
        do {
            _ = try VoiceAvatar(label: label, origin: origin, snapshots: [], noise: floorTable, breath: 0)
        } catch {
            throw .refused(error)
        }
        let framing = Framing(sampleRate: sampleRate)
        guard samples.count >= framing.frameLength + (minimumSoundingFrames - 1) * framing.hop else { throw .tooShort }

        let heard = try listen(to: samples, framing: framing, isCancelled: isCancelled)
        guard let loudest = heard.levels.max(), loudest >= silenceDecibels else { throw .silent }
        let gate = Swift.max(silenceDecibels, loudest - quietBelowLoudest)
        let sounding = heard.levels.map { (level: Double) -> Bool in level >= gate }
        guard sounding.filter({ (sounds: Bool) -> Bool in sounds }).count >= minimumSoundingFrames else { throw .tooShort }

        let voicing = try voice(samples, framing: framing, heard: heard, sounding: sounding, isCancelled: isCancelled)
        var analysis = SpectrumAnalysis(framing: framing)
        var envelopes: [EnvelopeFrame] = []
        for frame in spread(voicing.voiced, atMost: maximumSpectrumFrames) {
            if isCancelled() { throw .cancelled }
            envelopes.append(analysis.envelope(of: samples, frame: frame, fundamental: voicing.fundamentals[frame]))
        }
        let noiseFrames = clearNoise(sounding: sounding, voicing: voicing, framing: framing)
        for frame in noiseFrames {
            if isCancelled() { throw .cancelled }
            analysis.addNoise(of: samples, frame: frame)
        }

        let groups = try snapshotGroups(envelopes, isCancelled: isCancelled)
        let snapshots = groups.map { (members: [Int]) -> [Float] in pooled(members, envelopes).table }
        let noise: [Float]
        if !noiseFrames.isEmpty {
            noise = analysis.noiseTable()
        } else if !envelopes.isEmpty {
            noise = pooled(Array(envelopes.indices), envelopes).table
        } else {
            noise = floorTable
        }
        var breathEnergy = 0.0, soundEnergy = 0.0
        for frame in sounding.indices where sounding[frame] {
            soundEnergy += heard.energies[frame]
            breathEnergy += heard.energies[frame] * voicing.aperiodicities[frame]
        }
        let fundamentals = voicing.voiced.map { (frame: Int) -> Double in voicing.fundamentals[frame] }
        let declared: VoiceAvatar.Origin = snapshots.isEmpty && origin == .ownVoice ? .sound : origin
        do {
            return try VoiceAvatar(label: label, origin: declared, snapshots: snapshots, noise: noise,
                                   breath: Float(soundEnergy > 0 ? breathEnergy / soundEnergy : 1),
                                   pitchRange: pitchRange(of: fundamentals),
                                   vibrato: vibrato(of: voicing.fundamentals, voiced: voicing.voiced,
                                                    framesPerSecond: framing.framesPerSecond))
        } catch {
            throw .refused(error)
        }
    }

    /// Every band at the floor: nothing measured there.
    static var floorTable: [Float] {
        [Float](repeating: VoiceAvatar.floorDecibels, count: VoiceAvatar.bandCount)
    }

    /// At most `limit` of `frames`, evenly spread and in order; all of them when they are fewer.
    static func spread(_ frames: [Int], atMost limit: Int) -> [Int] {
        guard frames.count > limit, limit > 0 else { return frames }
        return (0..<limit).map { (index: Int) -> Int in frames[index * frames.count / limit] }
    }

    // MARK: Listening

    /// How a recording is cut into frames at one sample rate.
    struct Framing {
        let sampleRate: Double
        /// Samples per frame, and between two frames.
        let frameLength: Int
        let hop: Int
        /// Points in a frame's transform: the power of two at or above the frame.
        let size: Int

        init(sampleRate: Double) {
            self.sampleRate = sampleRate
            frameLength = Swift.max(64, Int((VoiceAvatarLearner.frameSeconds * sampleRate).rounded()))
            hop = Swift.max(16, Int((VoiceAvatarLearner.hopSeconds * sampleRate).rounded()))
            var power = 64
            while power < frameLength { power <<= 1 }
            size = power
        }

        /// The frames that fit in `samples` samples.
        func frameCount(of samples: Int) -> Int {
            samples >= frameLength ? (samples - frameLength) / hop + 1 : 0
        }

        var framesPerSecond: Double { sampleRate / Double(hop) }
    }

    /// What the first pass heard: each frame's energy (its mean taken out) and level in dBFS, and
    /// the tracker's readings, each at the middle of the window it measured, with the step between
    /// two readings.
    struct Heard {
        var energies: [Double]
        var levels: [Double]
        var readings: [(centre: Int, period: Double)]
        var readingStep: Int
    }

    /// Sample `index`, or silence where it is not finite.
    @inline(__always)
    static func sample(_ samples: [Float], _ index: Int) -> Float {
        let value = samples[index]
        return value.isFinite ? value : 0
    }

    /// The first pass, frame by frame: every sample through the `PitchTracker`, every frame's energy
    /// and level.
    static func listen(to samples: [Float], framing: Framing, isCancelled: () -> Bool) throws(Failure) -> Heard {
        let count = framing.frameCount(of: samples.count)
        let tracker = PitchTracker(sampleRate: framing.sampleRate)
        // The tracker's window in input samples: two periods of its lowest pitch, in averaged samples.
        let window = 2 * Int(framing.sampleRate / Double(tracker.factor) / PitchTracker.minimumHertz) * tracker.factor
        var heard = Heard(energies: [Double](repeating: 0, count: count),
                          levels: [Double](repeating: -.infinity, count: count), readings: [], readingStep: tracker.hop)
        var pushed = 0
        for frame in 0..<count {
            if isCancelled() { throw .cancelled }
            let start = frame * framing.hop, stop = start + framing.frameLength
            while pushed < stop {
                if tracker.push(sample(samples, pushed)) {
                    heard.readings.append((centre: pushed + 1 - window / 2, period: tracker.period))
                }
                pushed += 1
            }
            var sum = 0.0, squares = 0.0
            for index in start..<stop {
                let value = Double(sample(samples, index))
                sum += value
                squares += value * value
            }
            let length = Double(framing.frameLength)
            let energy = Swift.max(squares - sum * sum / length, 0)
            heard.energies[frame] = energy.isFinite ? energy : 0
            let rms = (heard.energies[frame] / length).squareRoot()
            heard.levels[frame] = rms > 1e-12 ? 20 * Foundation.log10(rms) : -.infinity
        }
        return heard
    }

    /// The voiced frames: each frame's fundamental (0 where it has none), how much of each sounding
    /// frame does not repeat (1 for an unvoiced one, 1 − periodicity for a voiced one), and the
    /// voiced frames in order.
    struct Voicing {
        var fundamentals: [Double]
        var aperiodicities: [Double]
        var voiced: [Int]
    }

    static func voice(_ samples: [Float], framing: Framing, heard: Heard, sounding: [Bool],
                      isCancelled: () -> Bool) throws(Failure) -> Voicing {
        let count = sounding.count
        var voicing = Voicing(fundamentals: [Double](repeating: 0, count: count),
                              aperiodicities: [Double](repeating: 1, count: count), voiced: [])
        var periodicities = [Double](repeating: 0, count: count)
        // The middle of a frame, wide enough to hold a reading at any rate: at 8 kHz the tracker
        // reads every 16 ms.
        let span = Swift.max(framing.hop, heard.readingStep + 1)
        var samplesOfFrame = [Double](repeating: 0, count: framing.frameLength)
        var next = 0
        for frame in 0..<count {
            if isCancelled() { throw .cancelled }
            let centre = frame * framing.hop + framing.frameLength / 2
            let from = centre - span / 2, to = from + span
            while next < heard.readings.count, heard.readings[next].centre < from { next += 1 }
            guard sounding[frame] else { continue }
            var shortest = Double.infinity, longest = 0.0, total = 0.0, found = 0
            var unpitched = false
            var reading = next
            while reading < heard.readings.count, heard.readings[reading].centre < to {
                let period = heard.readings[reading].period
                if period > 0 {
                    shortest = Swift.min(shortest, period)
                    longest = Swift.max(longest, period)
                    total += period
                    found += 1
                } else {
                    unpitched = true
                }
                reading += 1
            }
            guard !unpitched, found > 0, longest <= shortest * agreement else { continue }
            // The tracker hears a vowel whose first formant sits on its second or third harmonic an
            // octave or more too high. Of the period it heard and twice and three times that, the
            // shortest that repeats nearly as well as the best is the note's: the shortest lag that
            // repeats is the period, YIN's own rule.
            let heardPeriod = total / Double(found)
            let start = frame * framing.hop
            var mean = 0.0
            for index in 0..<framing.frameLength { mean += Double(sample(samples, start + index)) }
            mean /= Double(framing.frameLength)
            for index in 0..<framing.frameLength { samplesOfFrame[index] = Double(sample(samples, start + index)) - mean }
            var candidates: [(period: Double, periodicity: Double)] = []
            for times in 1...3 {
                let period = heardPeriod * Double(times)
                guard Int(period.rounded()) + 2 < framing.frameLength / 2 else { break }
                candidates.append((period, repeating(samplesOfFrame, period: period)))
            }
            let best = candidates.reduce(-1.0) { (top: Double, candidate: (period: Double, periodicity: Double)) -> Double in
                Swift.max(top, candidate.periodicity)
            }
            guard let chosen = candidates.first(where: { (candidate: (period: Double, periodicity: Double)) -> Bool in
                candidate.periodicity >= best - preference
            }), chosen.periodicity >= minimumPeriodicity else { continue }
            voicing.fundamentals[frame] = framing.sampleRate / chosen.period
            periodicities[frame] = chosen.periodicity
        }
        // A voiced stretch too short to be a voice is noise, and so is a voice too short for a snapshot.
        var runs: [Range<Int>] = []
        var frame = 0
        while frame < count {
            guard voicing.fundamentals[frame] > 0 else {
                frame += 1
                continue
            }
            var end = frame
            while end < count, voicing.fundamentals[end] > 0 { end += 1 }
            if end - frame >= minimumVoicedRun {
                runs.append(frame..<end)
            } else {
                for index in frame..<end { voicing.fundamentals[index] = 0 }
            }
            frame = end
        }
        let voicedCount = runs.reduce(0) { (total: Int, run: Range<Int>) -> Int in total + run.count }
        for run in runs {
            for index in run {
                if voicedCount < minimumSnapshotFrames {
                    voicing.fundamentals[index] = 0
                } else {
                    voicing.aperiodicities[index] = Swift.min(Swift.max(1 - periodicities[index], 0), 1)
                    voicing.voiced.append(index)
                }
            }
        }
        return voicing
    }

    /// How well a frame (its mean taken out) repeats `period` samples later: the highest normalised
    /// correlation over the whole-sample lags within two of the period, refined by a parabola
    /// through its neighbours. About 1 for a tone that repeats, about 0 for noise.
    static func repeating(_ frame: [Double], period: Double) -> Double {
        let length = frame.count
        let centre = Int(period.rounded())
        var scores = [Double](repeating: -1, count: 5)
        for slot in 0..<5 {
            let lag = centre - 2 + slot
            guard lag >= 1, lag < length / 2 else { continue }
            var cross = 0.0, first = 0.0, second = 0.0
            for index in 0..<(length - lag) {
                let a = frame[index], b = frame[index + lag]
                cross += a * b
                first += a * a
                second += b * b
            }
            let energy = first * second
            scores[slot] = energy > 0 ? cross / energy.squareRoot() : 0
        }
        var best = 0
        for slot in 1..<5 where scores[slot] > scores[best] { best = slot }
        var height = scores[best]
        if best > 0, best < 4, scores[best - 1] > -1, scores[best + 1] > -1 {
            let before = scores[best - 1], after = scores[best + 1]
            let curve = before - 2 * height + after
            if curve < 0 {
                let offset = Swift.min(Swift.max(0.5 * (before - after) / curve, -0.5), 0.5)
                height -= 0.25 * (before - after) * offset
            }
        }
        return height.isFinite ? Swift.min(Swift.max(height, -1), 1) : 0
    }

    /// The unvoiced sounding frames that lie more than a frame's length from every voiced frame, so
    /// that none of them holds part of a note; none when they are fewer than `minimumNoiseFrames`.
    /// At most `maximumSpectrumFrames`, evenly spread.
    static func clearNoise(sounding: [Bool], voicing: Voicing, framing: Framing) -> [Int] {
        let margin = (framing.frameLength + framing.hop - 1) / framing.hop
        var nearVoice = [Bool](repeating: false, count: sounding.count)
        for frame in voicing.voiced {
            for other in Swift.max(0, frame - margin)...Swift.min(sounding.count - 1, frame + margin) {
                nearVoice[other] = true
            }
        }
        let clear = sounding.indices.filter { (frame: Int) -> Bool in
            sounding[frame] && voicing.fundamentals[frame] == 0 && !nearVoice[frame]
        }
        return clear.count >= minimumNoiseFrames ? spread(clear, atMost: maximumSpectrumFrames) : []
    }

    // MARK: Spectra

    /// One voiced frame's envelope on the band grid, or a group's: decibels, its loudest measured
    /// band at 0, nothing below `-rangeDecibels`. Bands `first … last` were measured; those below
    /// hold the first one's level, those above read the bottom of the range.
    struct EnvelopeFrame {
        var table: [Float]
        var first: Int
        var last: Int
    }

    /// The transforms and buffers the frames share, and the noise frames' power, summed.
    struct SpectrumAnalysis {
        let framing: Framing
        private let window: [Float]
        private var transforms: [FFT?]
        private var real: [Float]
        private var imaginary: [Float]
        private var logs: [Float]
        private var closed: [Float]
        private var noisePower: [Double]
        /// The last band measured: the highest centre at or below `measuredShare` of the rate.
        let lastMeasured: Int

        init(framing: Framing) {
            self.framing = framing
            let length = framing.frameLength
            window = (0..<length).map { (index: Int) -> Float in
                Float(0.5 - 0.5 * Foundation.cos(2 * Double.pi * (Double(index) + 0.5) / Double(length)))
            }
            var exponents = 0
            while (1 << exponents) < framing.size { exponents += 1 }
            transforms = [FFT?](repeating: nil, count: exponents + 1)
            real = [Float](repeating: 0, count: framing.size)
            imaginary = [Float](repeating: 0, count: framing.size)
            logs = [Float](repeating: 0, count: framing.size / 2 + 1)
            closed = [Float](repeating: 0, count: framing.size / 2 + 1)
            noisePower = [Double](repeating: 0, count: framing.size / 2 + 1)
            var last = VoiceAvatar.bandCount - 1
            let top = VoiceAvatarLearner.measuredShare * framing.sampleRate
            while last > 0, Double(VoiceAvatar.centre(ofBand: last)) > top { last -= 1 }
            lastMeasured = last
        }

        /// The transform of `size` points (a power of two), made the first time it is asked for.
        private mutating func transform(_ size: Int) -> FFT {
            var exponent = 0
            while (1 << exponent) < size { exponent += 1 }
            if exponent < transforms.count, let made = transforms[exponent] { return made }
            let made = FFT(size: size)
            if exponent < transforms.count { transforms[exponent] = made }
            return made
        }

        /// The frame's samples, its mean taken out, scaled to a peak of 1, windowed and padded with
        /// zeros, then transformed: `real` and `imaginary` hold its spectrum. Returns the peak the
        /// frame was divided by; 0 for a frame of silence.
        private mutating func spectrum(of samples: [Float], frame: Int) -> Double {
            let start = frame * framing.hop, length = framing.frameLength
            var mean = 0.0
            for index in start..<(start + length) { mean += Double(VoiceAvatarLearner.sample(samples, index)) }
            mean /= Double(length)
            var peak = 0.0
            for index in start..<(start + length) {
                peak = Swift.max(peak, Swift.abs(Double(VoiceAvatarLearner.sample(samples, index)) - mean))
            }
            let scale = peak > 0 && peak.isFinite ? 1 / peak : 0
            for index in 0..<framing.size {
                if index < length {
                    let value = (Double(VoiceAvatarLearner.sample(samples, start + index)) - mean) * scale
                    real[index] = Float(value) * window[index]
                } else {
                    real[index] = 0
                }
                imaginary[index] = 0
            }
            transform(framing.size).transform(real: &real, imaginary: &imaginary)
            return scale > 0 ? peak : 0
        }

        /// The envelope of a voiced frame whose fundamental is `fundamental` hertz.
        mutating func envelope(of samples: [Float], frame: Int, fundamental: Double) -> EnvelopeFrame {
            _ = spectrum(of: samples, frame: frame)
            let half = framing.size / 2
            let binHertz = framing.sampleRate / Double(framing.size)
            var loudest = -Float.infinity
            for bin in 0...half {
                let power = real[bin] * real[bin] + imaginary[bin] * imaginary[bin]
                logs[bin] = 0.5 * logf(Swift.max(power, 1e-30))
                loudest = Swift.max(loudest, logs[bin])
            }
            // Below the fundamental there is nothing to wrap: it holds the first harmonic's peak, so
            // the hole at 0 Hz cannot make the envelope ring. Nothing lies further below the loudest
            // bin than a table reaches.
            let below = Swift.min(Int((fundamental / binHertz).rounded()), half)
            var harmonic = -Float.infinity
            let near = Swift.min(half, Swift.max(0, Int((0.5 * fundamental / binHertz).rounded())))
            let far = Swift.min(half, Swift.max(near, Int((1.5 * fundamental / binHertz).rounded())))
            for bin in near...far { harmonic = Swift.max(harmonic, logs[bin]) }
            let bottom = loudest - VoiceAvatarLearner.rangeDecibels / VoiceAvatarLearner.decibelsPerNeper
            for bin in 0...half {
                if bin < below { logs[bin] = harmonic }
                logs[bin] = Swift.max(logs[bin], bottom)
            }
            // The valleys between harmonics filled: the highest level within `valleyShare` of a
            // harmonic spacing, then the lowest of those. Every peak keeps its place and level.
            let reach = Int((VoiceAvatarLearner.valleyShare * fundamental / binHertz).rounded())
            if reach > 0 {
                for bin in 0...half {
                    var top = -Float.infinity
                    for index in Swift.max(0, bin - reach)...Swift.min(half, bin + reach) { top = Swift.max(top, logs[index]) }
                    closed[bin] = top
                }
                for bin in 0...half {
                    var low = Float.infinity
                    for index in Swift.max(0, bin - reach)...Swift.min(half, bin + reach) { low = Swift.min(low, closed[index]) }
                    logs[bin] = low
                }
            }
            let order = Swift.max(2, Swift.min(Int(framing.sampleRate / (2 * fundamental)), half - 2))
            let (curve, resolution) = trueEnvelope(order: order)
            // The first band at or above the fundamental: below it the frame measured nothing.
            var lowest = 0
            while lowest < lastMeasured, Double(VoiceAvatar.centre(ofBand: lowest)) < fundamental { lowest += 1 }
            var table = [Float](repeating: -VoiceAvatarLearner.rangeDecibels, count: VoiceAvatar.bandCount)
            let reducedHertz = framing.sampleRate / Double(resolution)
            for band in lowest...lastMeasured {
                table[band] = VoiceAvatarLearner.decibelsPerNeper * Self.read(curve, band: band, binHertz: reducedHertz)
            }
            return EnvelopeFrame(table: VoiceAvatarLearner.normalised(table, first: lowest, last: lastMeasured),
                                 first: lowest, last: lastMeasured)
        }

        /// The true envelope (Röbel & Rodet) of `logs`, keeping `order` cepstral coefficients, on the
        /// spectrum reduced to `resolutionFactor` bins per coefficient (each reduced bin the highest
        /// of the bins it covers): smoothed, then smoothed again over the higher of the spectrum and
        /// the last envelope, until no bin stands more than `envelopeToleranceDecibels` above it. The
        /// envelope in nepers (natural log of magnitude), bins 0 … resolution / 2, and the resolution.
        private mutating func trueEnvelope(order: Int) -> (curve: [Float], resolution: Int) {
            let size = framing.size
            var resolution = 64
            while resolution < VoiceAvatarLearner.resolutionFactor * order + 2, resolution < size { resolution <<= 1 }
            let step = size / resolution
            let half = resolution / 2
            var reduced = [Float](repeating: -.infinity, count: half + 1)
            for bin in 0...half {
                let centre = bin * step
                let low = Swift.max(0, centre - step / 2), high = Swift.min(size / 2, centre + step / 2)
                var top = -Float.infinity
                for index in low...high { top = Swift.max(top, logs[index]) }
                reduced[bin] = top
            }
            var loudest = -Float.infinity
            for bin in 0...half { loudest = Swift.max(loudest, reduced[bin]) }
            let counted = loudest - VoiceAvatarLearner.rangeDecibels / VoiceAvatarLearner.decibelsPerNeper
            let tolerance = VoiceAvatarLearner.envelopeToleranceDecibels / VoiceAvatarLearner.decibelsPerNeper
            let fourier = transform(resolution)
            var re = [Float](repeating: 0, count: resolution), im = [Float](repeating: 0, count: resolution)
            var curve = [Float](repeating: -.infinity, count: half + 1)
            let scale = 1 / Float(resolution)
            for _ in 0..<VoiceAvatarLearner.maximumEnvelopeRounds {
                // The higher of the spectrum and the envelope, mirrored: a real, even sequence, whose
                // transform is real and even too, so one forward transform serves either way.
                for bin in 0...half {
                    let value = Swift.max(reduced[bin], curve[bin])
                    re[bin] = value
                    if bin > 0, bin < half { re[resolution - bin] = value }
                }
                for index in 0..<resolution { im[index] = 0 }
                fourier.transform(real: &re, imaginary: &im)
                for quefrency in 0..<resolution {
                    re[quefrency] = quefrency > order && quefrency < resolution - order ? 0 : re[quefrency] * scale
                    im[quefrency] = 0
                }
                fourier.transform(real: &re, imaginary: &im)
                var worst: Float = 0
                for bin in 0...half {
                    curve[bin] = re[bin]
                    if reduced[bin] >= counted { worst = Swift.max(worst, reduced[bin] - re[bin]) }
                }
                if worst < tolerance { break }
            }
            return (curve, resolution)
        }

        /// A curve over bins `binHertz` apart, read for band `band`: its mean over the bins inside the
        /// band (from halfway to the band below to halfway to the band above, on a log axis) where
        /// there are three or more, else its value at the band's centre on a straight line between
        /// the two nearest bins.
        static func read(_ curve: [Float], band: Int, binHertz: Double) -> Float {
            let centre = Double(VoiceAvatar.centre(ofBand: band))
            let edge = VoiceAvatar.bandRatio.squareRoot()
            let last = curve.count - 1
            let low = Int((centre / edge / binHertz).rounded(.up)), high = Int((centre * edge / binHertz).rounded(.down))
            if high - low >= 2, low >= 0, high <= last {
                var sum = 0.0
                for bin in low...high { sum += Double(curve[bin]) }
                return Float(sum / Double(high - low + 1))
            }
            let position = Swift.min(Swift.max(centre / binHertz, 0), Double(last))
            let below = Swift.min(Int(position), last), above = Swift.min(below + 1, last)
            let t = Float(position - Double(below))
            return curve[below] + (curve[above] - curve[below]) * t
        }

        /// Adds a noise frame's power spectrum, at the frame's own level, to the sum.
        mutating func addNoise(of samples: [Float], frame: Int) {
            let peak = spectrum(of: samples, frame: frame)
            guard peak > 0 else { return }
            let squared = peak * peak
            for bin in 0...(framing.size / 2) {
                let power = Double(real[bin] * real[bin] + imaginary[bin] * imaginary[bin]) * squared
                if power.isFinite { noisePower[bin] += power }
            }
        }

        /// The noise frames' mean power spectrum on the band grid, as a table.
        func noiseTable() -> [Float] {
            var loudest = 0.0
            for bin in noisePower.indices { loudest = Swift.max(loudest, noisePower[bin]) }
            guard loudest > 0, loudest.isFinite else { return VoiceAvatarLearner.floorTable }
            let levels = noisePower.map { (power: Double) -> Float in
                Float(10 * Foundation.log10(Swift.max(power / loudest, 1e-30)))
            }
            let binHertz = framing.sampleRate / Double(framing.size)
            var table = [Float](repeating: -VoiceAvatarLearner.rangeDecibels, count: VoiceAvatar.bandCount)
            for band in 0...lastMeasured {
                table[band] = Self.read(levels, band: band, binHertz: binHertz)
            }
            return VoiceAvatarLearner.normalised(table, first: 0, last: lastMeasured)
        }
    }

    /// Decibels in one neper: 20 / ln 10.
    static let decibelsPerNeper: Float = 8.685_889_6

    /// A table whose bands `first … last` were measured, put so the loudest of them is at 0 dB and
    /// none lies more than `rangeDecibels` below it; the bands below `first` hold its level, those
    /// above `last` read the bottom of the range.
    static func normalised(_ table: [Float], first: Int, last: Int) -> [Float] {
        var result = [Float](repeating: -rangeDecibels, count: table.count)
        guard first >= 0, first <= last, last < table.count else { return result }
        var loudest = -Float.infinity
        for band in first...last where table[band].isFinite { loudest = Swift.max(loudest, table[band]) }
        guard loudest.isFinite else { return result }
        for band in first...last {
            let level = table[band] - loudest
            result[band] = level.isFinite ? Swift.max(level, -rangeDecibels) : -rangeDecibels
        }
        for band in 0..<first { result[band] = result[first] }
        return result
    }

    // MARK: Snapshots

    /// How differently two tables are shaped, whatever their levels: the RMS of their difference
    /// about its own mean, in decibels, over the bands both measured (all of them when those do not
    /// meet), each level held at `heardDecibels` below its table's loudest band.
    static func shapeDistance(_ a: EnvelopeFrame, _ b: EnvelopeFrame) -> Float {
        var low = Swift.max(a.first, b.first), high = Swift.min(a.last, b.last)
        if low > high {
            low = 0
            high = Swift.min(a.table.count, b.table.count) - 1
        }
        guard low <= high else { return 0 }
        let quiet = -Double(heardDecibels)
        let count = Double(high - low + 1)
        var mean = 0.0
        for band in low...high {
            mean += Swift.max(Double(a.table[band]), quiet) - Swift.max(Double(b.table[band]), quiet)
        }
        mean /= count
        var sum = 0.0
        for band in low...high {
            let difference = Swift.max(Double(a.table[band]), quiet) - Swift.max(Double(b.table[band]), quiet) - mean
            sum += difference * difference
        }
        return Float((sum / count).squareRoot())
    }

    /// The envelope a group of voiced frames shares: band by band, the mean of the frames that
    /// measured the band, each frame first brought to the group's level over the bands every one of
    /// them measured; normalised as a table.
    static func pooled(_ members: [Int], _ frames: [EnvelopeFrame]) -> EnvelopeFrame {
        guard let head = members.first else {
            return EnvelopeFrame(table: floorTable, first: 0, last: VoiceAvatar.bandCount - 1)
        }
        var common = (low: frames[head].first, high: frames[head].last)
        var union = common
        for member in members {
            common = (Swift.max(common.low, frames[member].first), Swift.min(common.high, frames[member].last))
            union = (Swift.min(union.low, frames[member].first), Swift.max(union.high, frames[member].last))
        }
        let bands = VoiceAvatar.bandCount
        var sums = [Double](repeating: 0, count: bands), counts = [Int](repeating: 0, count: bands)
        for member in members {
            let frame = frames[member]
            let low = common.low <= common.high ? common.low : frame.first
            let high = common.low <= common.high ? common.high : frame.last
            var offset = 0.0
            for band in low...high { offset += Double(frame.table[band]) }
            offset /= Double(high - low + 1)
            for band in frame.first...frame.last {
                sums[band] += Double(frame.table[band]) - offset
                counts[band] += 1
            }
        }
        var table = [Float](repeating: -rangeDecibels, count: bands)
        for band in union.low...union.high where counts[band] > 0 {
            table[band] = Float(sums[band] / Double(counts[band]))
        }
        return EnvelopeFrame(table: normalised(table, first: union.low, last: union.high), first: union.low, last: union.high)
    }

    /// The voiced frames in groups, one group per snapshot, each group's members in order (see the
    /// type: bisecting k-means, then k-means over all the groups, joining any that have come to lie
    /// closer than `splitDecibels` and giving away the frames of any left smaller than
    /// `minimumSnapshotFrames`).
    static func snapshotGroups(_ frames: [EnvelopeFrame], isCancelled: () -> Bool) throws(Failure) -> [[Int]] {
        guard !frames.isEmpty else { return [] }
        var groups: [[Int]] = [Array(frames.indices)]
        var settled = [false]
        while groups.count < VoiceAvatar.maximumSnapshots {
            if isCancelled() { throw .cancelled }
            var target = -1
            var widest = -1.0
            for (index, members) in groups.enumerated() where !settled[index] {
                let width = scatter(members, frames)
                if width > widest {
                    widest = width
                    target = index
                }
            }
            guard target >= 0 else { break }
            guard let halves = halve(groups[target], frames),
                  halves.0.count >= minimumSnapshotFrames, halves.1.count >= minimumSnapshotFrames,
                  shapeDistance(pooled(halves.0, frames), pooled(halves.1, frames)) >= splitDecibels else {
                settled[target] = true
                continue
            }
            groups[target] = halves.0
            settled[target] = false
            groups.append(halves.1)
            settled.append(false)
        }
        return groups.count > 1 ? try refined(groups, frames, isCancelled: isCancelled) : groups
    }

    /// The sum of the squared distances of a group's frames from its envelope.
    static func scatter(_ members: [Int], _ frames: [EnvelopeFrame]) -> Double {
        let centre = pooled(members, frames)
        var sum = 0.0
        for member in members {
            let distance = Double(shapeDistance(frames[member], centre))
            sum += distance * distance
        }
        return sum
    }

    /// A group cut in two: first by which side of the group's mean each frame lies on, along the
    /// direction in which its frames differ most (power iteration, starting from the frame furthest
    /// from the mean, the first of two as far), then by k-means with two. Nil when the frames do not
    /// differ.
    static func halve(_ members: [Int], _ frames: [EnvelopeFrame]) -> ([Int], [Int])? {
        guard members.count >= 2 else { return nil }
        let bands = VoiceAvatar.bandCount
        // Each frame about its own mean level, then about the group's mean of those.
        var rows: [[Double]] = []
        rows.reserveCapacity(members.count)
        var centre = [Double](repeating: 0, count: bands)
        for member in members {
            let table = frames[member].table
            var level = 0.0
            for band in 0..<bands { level += Double(table[band]) }
            level /= Double(bands)
            let row = (0..<bands).map { (band: Int) -> Double in Double(table[band]) - level }
            for band in 0..<bands { centre[band] += row[band] }
            rows.append(row)
        }
        for band in 0..<bands { centre[band] /= Double(members.count) }
        for index in rows.indices {
            for band in 0..<bands { rows[index][band] -= centre[band] }
        }
        var direction = rows[0]
        var furthest = -1.0
        for row in rows {
            var length = 0.0
            for band in 0..<bands { length += row[band] * row[band] }
            if length > furthest {
                furthest = length
                direction = row
            }
        }
        guard furthest > 1e-12 else { return nil }
        for _ in 0..<30 {
            var next = [Double](repeating: 0, count: bands)
            for row in rows {
                var projection = 0.0
                for band in 0..<bands { projection += row[band] * direction[band] }
                for band in 0..<bands { next[band] += projection * row[band] }
            }
            var length = 0.0
            for band in 0..<bands { length += next[band] * next[band] }
            guard length > 1e-24 else { break }
            let scale = 1 / length.squareRoot()
            for band in 0..<bands { next[band] *= scale }
            direction = next
        }
        var first: [Int] = [], second: [Int] = []
        for (index, row) in rows.enumerated() {
            var projection = 0.0
            for band in 0..<bands { projection += row[band] * direction[band] }
            if projection > 0 { second.append(members[index]) } else { first.append(members[index]) }
        }
        guard !first.isEmpty, !second.isEmpty else { return nil }
        for _ in 0..<maximumRefinements {
            let a = pooled(first, frames), b = pooled(second, frames)
            var nextFirst: [Int] = [], nextSecond: [Int] = []
            for member in members {
                if shapeDistance(frames[member], b) < shapeDistance(frames[member], a) {
                    nextSecond.append(member)
                } else {
                    nextFirst.append(member)
                }
            }
            guard !nextFirst.isEmpty, !nextSecond.isEmpty else { break }
            if nextFirst == first, nextSecond == second { break }
            first = nextFirst
            second = nextSecond
        }
        return (first, second)
    }

    /// k-means over all the groups: every frame to the nearest group's envelope (the first of two as
    /// near), until nothing moves; then the two nearest groups are joined while they lie closer than
    /// `splitDecibels`, and a group left with fewer than `minimumSnapshotFrames` frames gives them to
    /// the nearest other one.
    static func refined(_ start: [[Int]], _ frames: [EnvelopeFrame], isCancelled: () -> Bool) throws(Failure) -> [[Int]] {
        var groups = start
        for _ in 0..<maximumRefinements {
            if isCancelled() { throw .cancelled }
            let centres = groups.map { (members: [Int]) -> EnvelopeFrame in pooled(members, frames) }
            var next = [[Int]](repeating: [], count: groups.count)
            for index in frames.indices {
                next[nearest(frames[index], centres)].append(index)
            }
            next = next.filter { (members: [Int]) -> Bool in !members.isEmpty }
            if next == groups { break }
            groups = next
        }
        while groups.count > 1 {
            if isCancelled() { throw .cancelled }
            let centres = groups.map { (members: [Int]) -> EnvelopeFrame in pooled(members, frames) }
            var pair = (0, 1)
            var closest = Float.infinity
            for a in 0..<groups.count {
                for b in (a + 1)..<groups.count {
                    let distance = shapeDistance(centres[a], centres[b])
                    if distance < closest {
                        closest = distance
                        pair = (a, b)
                    }
                }
            }
            guard closest < splitDecibels else { break }
            groups[pair.0] = (groups[pair.0] + groups[pair.1]).sorted()
            groups.remove(at: pair.1)
        }
        while groups.count > 1,
              let small = groups.firstIndex(where: { (members: [Int]) -> Bool in members.count < minimumSnapshotFrames }) {
            if isCancelled() { throw .cancelled }
            let members = groups.remove(at: small)
            let centres = groups.map { (members: [Int]) -> EnvelopeFrame in pooled(members, frames) }
            for member in members {
                groups[nearest(frames[member], centres)].append(member)
            }
            for index in groups.indices { groups[index].sort() }
        }
        return groups
    }

    /// The index of the envelope in `centres` nearest `frame`; the first of two as near.
    static func nearest(_ frame: EnvelopeFrame, _ centres: [EnvelopeFrame]) -> Int {
        var best = 0
        var closest = Float.infinity
        for (index, centre) in centres.enumerated() {
            let distance = shapeDistance(frame, centre)
            if distance < closest {
                closest = distance
                best = index
            }
        }
        return best
    }

    // MARK: Pitch

    /// The voiced frames' fundamentals at `pitchShares`, on straight lines between the two nearest
    /// in order; nil without any.
    static func pitchRange(of fundamentals: [Double]) -> (lowest: Float, highest: Float)? {
        guard !fundamentals.isEmpty else { return nil }
        let sorted = fundamentals.sorted()
        func at(_ share: Double) -> Double {
            let position = share * Double(sorted.count - 1)
            let below = Int(position.rounded(.down)), above = Swift.min(below + 1, sorted.count - 1)
            return sorted[below] + (sorted[above] - sorted[below]) * (position - Double(below))
        }
        return (lowest: Float(at(pitchShares.lowest)), highest: Float(at(pitchShares.highest)))
    }

    /// The vibrato the voiced frames sang with, or nil. On every stretch of consecutive voiced frames
    /// at least `vibratoMinimumSeconds` long whose pitch never jumps `vibratoJumpCents`, the pitch in
    /// cents less its least-squares straight line is fitted with a swing (a cosine and a sine) at
    /// every rate in `vibratoRates`; the rate whose swings explain the most, all stretches together,
    /// refined by a parabola, and the amplitude of its swing, the stretches weighed by length. Nil
    /// when the swing explains less than `vibratoMinimumShare` of what the lines leave, or swings
    /// less than `vibratoMinimumCents`.
    static func vibrato(of fundamentals: [Double], voiced: [Int], framesPerSecond: Double) -> VoiceAvatar.Vibrato? {
        let shortest = Int((vibratoMinimumSeconds * framesPerSecond).rounded(.up))
        var stretches: [[Double]] = []
        var index = 0
        while index < voiced.count {
            var end = index + 1
            while end < voiced.count, voiced[end] == voiced[end - 1] + 1,
                  Swift.abs(cents(fundamentals[voiced[end]]) - cents(fundamentals[voiced[end - 1]])) < vibratoJumpCents {
                end += 1
            }
            if end - index >= shortest {
                let pitch = (index..<end).map { (position: Int) -> Double in cents(fundamentals[voiced[position]]) }
                stretches.append(detrended(pitch))
            }
            index = end
        }
        guard !stretches.isEmpty else { return nil }
        var total = 0.0
        for stretch in stretches {
            for value in stretch { total += value * value }
        }
        guard total > 0 else { return nil }
        let steps = Int(((vibratoRates.upperBound - vibratoRates.lowerBound) / vibratoRateStep).rounded())
        var explained = [Double](repeating: 0, count: steps + 1)
        for step in 0...steps {
            let rate = vibratoRates.lowerBound + Double(step) * vibratoRateStep
            for stretch in stretches { explained[step] += swing(stretch, rate: rate, framesPerSecond: framesPerSecond).power }
        }
        var best = 0
        for step in 1...steps where explained[step] > explained[best] { best = step }
        guard explained[best] >= vibratoMinimumShare * total else { return nil }
        var rate = vibratoRates.lowerBound + Double(best) * vibratoRateStep
        if best > 0, best < steps {
            let before = explained[best - 1], at = explained[best], after = explained[best + 1]
            let curve = before - 2 * at + after
            if curve < 0 { rate += vibratoRateStep * Swift.min(Swift.max(0.5 * (before - after) / curve, -0.5), 0.5) }
        }
        var depth = 0.0, weight = 0.0
        for stretch in stretches {
            depth += swing(stretch, rate: rate, framesPerSecond: framesPerSecond).amplitude * Double(stretch.count)
            weight += Double(stretch.count)
        }
        depth /= weight
        guard depth >= vibratoMinimumCents else { return nil }
        return VoiceAvatar.Vibrato(rate: Float(rate), depth: Float(depth))
    }

    /// A fundamental in cents above 440 Hz.
    static func cents(_ hertz: Double) -> Double {
        1_200 * Foundation.log2(hertz / 440)
    }

    /// `values` less their least-squares straight line.
    static func detrended(_ values: [Double]) -> [Double] {
        let count = Double(values.count)
        let middle = (count - 1) / 2
        var mean = 0.0, slope = 0.0, squares = 0.0
        for (index, value) in values.enumerated() {
            mean += value
            let x = Double(index) - middle
            slope += x * value
            squares += x * x
        }
        mean /= count
        slope = squares > 0 ? slope / squares : 0
        return values.enumerated().map { (index: Int, value: Double) -> Double in
            value - mean - slope * (Double(index) - middle)
        }
    }

    /// The swing at `rate` hertz that best fits `values`, one per frame (least squares on a cosine
    /// and a sine): its amplitude, and the part of the values' sum of squares it explains.
    static func swing(_ values: [Double], rate: Double, framesPerSecond: Double) -> (amplitude: Double, power: Double) {
        let step = 2 * Double.pi * rate / framesPerSecond
        var cc = 0.0, ss = 0.0, cs = 0.0, xc = 0.0, xs = 0.0
        for (index, value) in values.enumerated() {
            let c = Foundation.cos(step * Double(index)), s = Foundation.sin(step * Double(index))
            cc += c * c
            ss += s * s
            cs += c * s
            xc += value * c
            xs += value * s
        }
        let determinant = cc * ss - cs * cs
        guard determinant > 1e-12 else { return (0, 0) }
        let a = (xc * ss - xs * cs) / determinant, b = (xs * cc - xc * cs) / determinant
        return ((a * a + b * b).squareRoot(), a * xc + b * xs)
    }
}
