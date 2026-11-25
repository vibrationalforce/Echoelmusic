import Foundation

/// One pad of a sliced sample (the break slicer, EchoelTools A11): where it starts, in frames of
/// the sampler's file. It plays to where the next slice starts, the last one to the file's end.
/// `tune` (semitones, −24 … 24) and `reverse` are optional and absent in the file at their
/// defaults. Stored in the song, inside format 4 (2026-11-04).
public struct SampleSlice: Codable, Equatable, Hashable, Sendable {
    public var start: Int
    public var tune: Double
    public var reverse: Bool

    public init(start: Int, tune: Double = 0, reverse: Bool = false) {
        self.start = start
        self.tune = tune
        self.reverse = reverse
    }

    private enum CodingKeys: String, CodingKey { case start, tune, reverse }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decode(Int.self, forKey: .start)
        tune = try c.decodeIfPresent(Double.self, forKey: .tune) ?? 0
        reverse = try c.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(start, forKey: .start)
        if tune != 0 { try c.encode(tune, forKey: .tune) }
        if reverse { try c.encode(reverse, forKey: .reverse) }
    }

    /// The most pads a sample is cut into, and the note the first one plays on (the first pad of
    /// a drum map); the others follow on consecutive notes.
    public static let maximumCount = 16
    public static let firstNote = 36
    public static let tuneRange: ClosedRange<Double> = -24...24

    /// Whether `slices` can cut a file of `frameCount` frames: one to sixteen, starts rising and
    /// inside the file, tunes finite and in range. Empty is "not sliced".
    static func validate(_ slices: [SampleSlice], frameCount: Int?) throws {
        guard slices.count <= maximumCount else {
            throw CommandError.invalidValue(parameter: "slices", reason: "at most \(maximumCount) slices")
        }
        var last = -1
        for slice in slices {
            guard slice.start > last else {
                throw CommandError.invalidValue(parameter: "slices", reason: "starts must rise and begin at 0 or later")
            }
            if let frameCount, slice.start >= frameCount {
                throw CommandError.invalidValue(parameter: "slices", reason: "a slice starts past the end of its file")
            }
            guard slice.tune.isFinite, tuneRange.contains(slice.tune) else {
                throw CommandError.invalidValue(parameter: "slices", reason: "a slice's tune is outside \(tuneRange)")
            }
            last = slice.start
        }
    }
}

/// Cutting a loop into pads and writing the pattern it played (the break slicer). Pure: the onsets
/// come from the app (`OnsetDetector` reads the file off the main thread), the result is commands
/// through the one door, as one undo step.
public enum BreakSlicing {
    /// The slice starts for a file: 0, then the onsets heard in it (seconds of the file), none
    /// closer than 30 ms to the one before — or, when there are more hits than pads, one start per
    /// step of the loop's grid (`gridStarts`). A file with fewer than two onsets past its
    /// start is cut into eight equal pads instead, so a loop always slices.
    /// With `bpm` — the loop's tempo, heard or stated (`TempoHint`) — the grid is the loop's beats at
    /// that tempo instead of a guess from its length, so a loop with a tail or a cut that is not
    /// exactly whole beats still lands on the song's grid.
    public static func starts(onsets: [Double], frameCount: Int, sampleRate: Double, bpm: Double? = nil) -> [Int] {
        guard frameCount > 1, sampleRate.isFinite, sampleRate > 0 else { return frameCount > 0 ? [0] : [] }
        let gap = Int(0.03 * sampleRate)
        var found: [Int] = []
        for seconds in onsets where seconds.isFinite {
            let frame = Int((seconds * sampleRate).rounded())
            guard frame >= gap, frame < frameCount - gap, frame - (found.last ?? 0) >= gap else { continue }
            found.append(frame)
        }
        guard found.count >= 2 else {
            let pads = 8
            return (0..<pads).map { frameCount * $0 / pads }.reduce(into: [Int]()) { if $1 > ($0.last ?? -1) { $0.append($1) } }
        }
        // More hits than pads: one pad per step of the loop's grid. Taking every n-th hit instead
        // (before 2026-11-19) left the others inside long pads, which play at the file's own speed —
        // off the song's grid wherever the song's tempo is not the loop's, so a chopped break ran
        // out of time and lost its groove (Michael, 10083).
        guard found.count < SampleSlice.maximumCount else {
            return gridStarts(hits: found, frameCount: frameCount, sampleRate: sampleRate, bpm: bpm)
        }
        return [0] + found
    }

    /// One start per step of the loop's grid: sixteenths of its beats (`beats(forSeconds:)`), halved
    /// until `SampleSlice.maximumCount` pads hold them. A step starts at the hit nearest its grid
    /// line within half a step — the hit's own frame, so a late or early hit keeps its feel — or on
    /// the line where no hit is near. Every pad is then one step of the music long.
    static func gridStarts(hits: [Int], frameCount: Int, sampleRate: Double, bpm: Double? = nil) -> [Int] {
        let beatCount = beats(forSeconds: Double(frameCount) / sampleRate, bpm: bpm)
        var steps = beatCount * 4
        while steps > SampleSlice.maximumCount { steps /= 2 }
        guard steps > 1 else { return [0] }
        if let tempo = usable(bpm) {
            // The grid of the loop's beats at its tempo, not of its length.
            let stepFrames = Double(beatCount) * 60 / tempo * sampleRate / Double(steps)
            let reach = Int(stepFrames / 2)
            var starts = [0]
            for step in 1..<steps {
                let line = Int((stepFrames * Double(step)).rounded())
                var start = line
                if let near = hits.min(by: { Swift.abs($0 - line) < Swift.abs($1 - line) }), Swift.abs(near - line) <= reach {
                    start = near
                }
                guard let last = starts.last, start > last, start < frameCount else { continue }
                starts.append(start)
            }
            return starts
        }
        let reach = frameCount / steps / 2
        var starts = [0]
        for step in 1..<steps {
            let line = Int(Int64(frameCount) * Int64(step) / Int64(steps))
            var start = line
            if let near = hits.min(by: { Swift.abs($0 - line) < Swift.abs($1 - line) }), Swift.abs(near - line) <= reach {
                start = near
            }
            guard let last = starts.last, start > last, start < frameCount else { continue }
            starts.append(start)
        }
        return starts
    }

    /// How many quarter notes a loop of `seconds` spans: the power of two whose tempo lands in
    /// 80 … 160 BPM — a two-second loop is four beats at 120, a 1.4-second one four at 171 → two at
    /// 86. The pattern spreads the loop over these beats, so it plays at the song's tempo.
    /// With a usable `bpm` it is the loop's length in beats at that tempo, rounded, at least one.
    public static func beats(forSeconds seconds: Double, bpm: Double? = nil) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 4 }
        if let tempo = usable(bpm) {
            let counted = (seconds * tempo / 60).rounded()
            return counted.isFinite ? Swift.max(1, Swift.min(256, Int(counted))) : 4
        }
        var beats = 1
        while beats < 256, 60 * Double(beats) / seconds < 80 { beats *= 2 }
        return beats
    }

    /// The pattern the loop played, one note per slice on its pad, spread over `beats(forSeconds:)`
    /// quarters so the break plays at the song's tempo: each slice at its share of the loop, each as
    /// long as its slice. The clip is that many quarters long.
    /// With a usable `bpm` each slice sits where it falls at the loop's tempo — its seconds in the
    /// file as quarters — rather than at its share of the file's length.
    public static func pattern(starts: [Int], frameCount: Int, sampleRate: Double, bpm: Double? = nil,
                               velocity: Int = 100) -> (notes: [Note], length: Tick) {
        guard frameCount > 0, sampleRate.isFinite, sampleRate > 0, !starts.isEmpty else { return ([], MusicalTime.ticksPerQuarter) }
        let tempo = usable(bpm)
        let beats = beats(forSeconds: Double(frameCount) / sampleRate, bpm: tempo)
        let length = Tick(beats) * MusicalTime.ticksPerQuarter
        func tick(_ frame: Int) -> Tick {
            if let tempo {
                return Tick((Double(frame) / sampleRate * tempo / 60 * Double(MusicalTime.ticksPerQuarter)).rounded())
            }
            return Tick((Double(frame) / Double(frameCount) * Double(length)).rounded())
        }
        var notes: [Note] = []
        for (index, start) in starts.enumerated() where index < SampleSlice.maximumCount {
            let stop = index + 1 < starts.count ? starts[index + 1] : frameCount
            let from = tick(start)
            let to = Swift.min(tick(stop), length)
            guard to > from else { continue }
            notes.append(Note(pitch: SampleSlice.firstNote + index, velocity: velocity, start: from, length: to - from))
        }
        return (notes, length)
    }

    /// Slice to Pads: the commands that cut `track`'s sample at `starts` and — with `writePattern` —
    /// write the pattern it played as a new clip named after the file, placed at `at`. Perform them
    /// as one step (`ProjectStore.perform(_:title:)`), so one undo takes all of it back.
    public static func commands(track: TrackID, file: MediaFile, starts: [Int], writePattern: Bool, bpm: Double? = nil,
                                clip: ClipID = ClipID(), placement: PlacementID = PlacementID(), at: Tick = 0) -> [Command] {
        var commands: [Command] = [.setSamplerSlices(track, starts.map { SampleSlice(start: $0) })]
        guard writePattern else { return commands }
        let made = pattern(starts: starts, frameCount: file.frameCount, sampleRate: file.sampleRate, bpm: bpm)
        guard !made.notes.isEmpty else { return commands }
        let trimmed = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Break" : String(trimmed.prefix(Names.maximumLength))
        commands.append(.createClip(track: track, id: clip, name: name, length: made.length))
        commands.append(.addNotes(clip, made.notes))
        commands.append(.placeClip(track: track, id: placement, clip: clip, start: at))
        return commands
    }

    /// A loop tempo the slicer may place by: finite and in `AudioRegion.nativeBPMRange`.
    static func usable(_ bpm: Double?) -> Double? {
        guard let bpm, bpm.isFinite, AudioRegion.nativeBPMRange.contains(bpm) else { return nil }
        return bpm
    }
}
