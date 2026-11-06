import EchoelCore
import EchoelDSP
import Foundation

/// The Field of a video export (wave W15): one `FieldFrame` for every frame of the film, built
/// from the song and its rendered mix alone, and the motion each one is drawn with — so the Field
/// over the picture is the Field of the song, frame for frame, and a second export of the same song
/// is the same film. Pure: the GPU draws what this computes and decides nothing itself.
///
/// The body is left out on purpose (the offline-export freeze): a pulse, HRV, coherence or breath is
/// a live reading, and the song stores none — there is no recorded body track, and none comes
/// without a format version. An export that read the sensors would change with the room it is made
/// in. The mix makes the same choice (an offline render reads no `ModulationInputs`), so picture and
/// sound tell one story. And the device's heat, battery and Reduce Motion belong to its screen, not
/// to a file: an export is drawn at full detail and never held still. Every flash guard and clock
/// ceiling still applies — they live in `FieldMotion` and `FieldLookMotion`, not in the device.
///
/// The looks are the musician's choice on the device, handed in (`FieldLookChoice`). A look that
/// listens to the master's partials hears them from the mix: each frame's partials come from the
/// live Field's own analyzer run over the rendered mix (`Peaks`), so a film hears what the window
/// heard while the song played.
public enum FieldExport {
    /// What one frame of a film shows: the Field's motion, its looks and, while a shown look is the
    /// Chladni plate, the plate's figure.
    public struct Shown: Equatable, Sendable {
        public var field: FieldMotion.Shown
        public var look: FieldLookMotion.Shown
        public var plate: ChladniMotion.Shown?

        public init(field: FieldMotion.Shown = FieldMotion.Shown(), look: FieldLookMotion.Shown = FieldLookMotion.Shown(),
                    plate: ChladniMotion.Shown? = nil) {
            self.field = field
            self.look = look
            self.plate = plate
        }
    }

    /// The film's frames a second: the video export's own rate.
    public static let framesPerSecond = 30

    /// The loudest sample of each frame's stretch of a mix, read block by block: frame `n` covers
    /// the samples from `n` to `n + 1` frame durations, rounded down, whatever the block size. A
    /// sample that is not a finite number counts as silence, as on the meter.
    ///
    /// Asked for `partials`, also each frame's strongest partials: the live Field's analyzer
    /// (`SpectrumAnalyzer`, its own size and peak picking) fed the mix summed to mono as the live
    /// tap sums it, and read where the frame ends — so frame `n` hears the analyzer's window ending
    /// with it, and how the mix is cut into blocks changes nothing. One reader at a time; a copy
    /// shares the analyzer.
    public struct Peaks: Sendable {
        public let sampleRate: Double
        /// The finished frames' peaks, linear, 1 = full scale.
        public private(set) var peaks: [Float] = []
        /// The finished frames' partials; empty unless asked for.
        public private(set) var partials: [SpectralPeaks] = []
        private let ear: SpectrumAnalyzer?
        private var loudest: Float = 0
        /// Samples read so far.
        private var position: Int64 = 0
        /// Where the frame being read starts and ends, in samples.
        private var frameStart: Int64 = 0
        private var frameEnd: Int64 = 1

        public init(sampleRate: Double, partials listening: Bool = false) {
            self.sampleRate = sampleRate.isFinite && sampleRate >= 1 ? sampleRate : 48_000
            ear = listening ? SpectrumAnalyzer(sampleRate: self.sampleRate) : nil
            frameEnd = end(of: 0)
        }

        /// The next `count` stereo samples.
        public mutating func add(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) {
            var index = 0
            while index < count {
                // At least one: the frame being read always ends past `position`.
                let take = Int(Swift.min(Int64(count - index), frameEnd - position))
                for sample in index..<(index + take) {
                    loudest = Swift.max(loudest, Self.level(left[sample]), Self.level(right[sample]))
                }
                if let ear {
                    // Mono as the live tap hears it: the mean of the two sides.
                    let first = index
                    withUnsafeTemporaryAllocation(of: Float.self, capacity: take) { mono in
                        mono.initialize(repeating: 0)
                        for offset in 0..<take { mono[offset] = 0.5 * (left[first + offset] + right[first + offset]) }
                        if let base = mono.baseAddress { ear.push(base, count: take) }
                    }
                }
                index += take
                position += Int64(take)
                if position >= frameEnd {
                    peaks.append(loudest)
                    if let ear { partials.append(ear.analyze()) }
                    loudest = 0
                    frameStart = frameEnd
                    frameEnd = end(of: peaks.count)
                }
            }
        }

        /// How much of the mix before the film's first frame the analyzer hears first
        /// (`hearBefore`): its window, so the first frames hear a full one, as the window heard the
        /// music playing up to them.
        public var hearingBefore: Int { ear?.size ?? 0 }

        /// Mix from before the film's first frame, for the analyzer only: no frame, no peak. Nothing
        /// without partials asked for.
        public func hearBefore(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) {
            guard let ear, count > 0 else { return }
            withUnsafeTemporaryAllocation(of: Float.self, capacity: count) { mono in
                mono.initialize(repeating: 0)
                for offset in 0..<count { mono[offset] = 0.5 * (left[offset] + right[offset]) }
                if let base = mono.baseAddress { ear.push(base, count: count) }
            }
        }

        /// Every frame's peak, the last one too when the mix ends inside it.
        public var finished: [Float] {
            position > frameStart ? peaks + [loudest] : peaks
        }

        /// Every frame's partials, the last one too when the mix ends inside it; empty unless asked
        /// for. One per frame of `finished`.
        public var finishedPartials: [SpectralPeaks] {
            guard let ear else { return [] }
            return position > frameStart ? partials + [ear.analyze()] : partials
        }

        /// Where frame `frame` ends, in samples: past where the frame before it ended, so every
        /// frame holds at least one sample.
        private func end(of frame: Int) -> Int64 {
            let end = Int64((Double(frame + 1) * sampleRate / Double(FieldExport.framesPerSecond)).rounded(.down))
            return Swift.max(end, frameStart + 1)
        }

        private static func level(_ sample: Float) -> Float {
            sample.isFinite ? Swift.abs(sample) : 0
        }
    }

    /// The level each frame shows: what the master meter would read at it — the frame's peak, held
    /// and falling at the meter's rate (`MeterBank.fallDecibelsPerSecond`) — through the square root,
    /// the curve `FieldFrame.current` reads the meter with.
    public static func levels(peaks: [Float]) -> [Double] {
        let fall = Foundation.pow(10, -Double(MeterBank.fallDecibelsPerSecond) / 20 / Double(framesPerSecond))
        var held = 0.0
        var levels: [Double] = []
        levels.reserveCapacity(peaks.count)
        for peak in peaks {
            let fresh = peak.isFinite ? Double(Swift.abs(peak)) : 0
            held = Swift.max(fresh, held * fall)
            levels.append(held.squareRoot())
        }
        return levels
    }

    /// The film's `count` frames, the first `fromSeconds` into the song: the song's beat and bar at
    /// each frame's time on its tempo map, its key's colour, `levels[n]` as frame `n`'s level
    /// (silence past their end), playing throughout — and no body reading.
    public static func frames(of project: Project, fromSeconds: Double, count: Int, levels: [Double]) -> [FieldFrame] {
        let start = fromSeconds.isFinite ? Swift.max(0, fromSeconds) : 0
        let map = project.tempoMap
        let meter = project.meterMap
        let context = project.context
        var frames: [FieldFrame] = []
        frames.reserveCapacity(Swift.max(0, count))
        for index in 0..<Swift.max(0, count) {
            let seconds = start + Double(index) / Double(framesPerSecond)
            let level = index < levels.count ? levels[index] : 0
            frames.append(FieldFrame.at(tick: map.position(atSeconds: seconds), meter: meter, context: context,
                                        level: level, pulse: nil, hrv: nil, coherence: nil, isPlaying: true,
                                        breath: nil))
        }
        return frames
    }

    /// What the Field shows on each frame: the motion stepped from the first frame at the film's
    /// rate, at full detail and never held still.
    public static func motion(_ frames: [FieldFrame]) -> [FieldMotion.Shown] {
        film(frames, look: FieldLookChoice()).map(\.field)
    }

    /// Every frame of the film: the motion, the looks of `look` hearing each frame's `partials`
    /// (silence past their end), and the plate while a shown look is the Chladni plate — stepped
    /// together from the first frame at the film's rate, in the order the Field window steps them,
    /// at full detail and never held still. Computed whole before a frame is drawn, so a frame is
    /// looked up by its time (`index(at:count:)`) and two exports of one song, one stretch and one
    /// choice are the same film.
    public static func film(_ frames: [FieldFrame], look: FieldLookChoice, partials: [SpectralPeaks] = []) -> [Shown] {
        var motion = FieldMotion()
        var looks = FieldLookMotion()
        var plate = ChladniMotion()
        let seconds = 1 / Double(framesPerSecond)
        let patternScale = FieldDetail(level: .full).patternScale
        var film: [Shown] = []
        film.reserveCapacity(frames.count)
        for (number, frame) in frames.enumerated() {
            let field = motion.step(frame, after: seconds, still: false, patternScale: patternScale)
            let heard = number < partials.count ? partials[number] : SpectralPeaks.silent
            let sound = FieldLookMotion.hearing(frequencies: heard.frequencies, amplitudes: heard.amplitudes,
                                                count: heard.count)
            let shown = looks.step(drawing: look, from: frame, hertz: sound.hertz, drive: sound.drive,
                                   fieldPhase: field.fieldPhase, after: seconds, still: false, patternScale: patternScale)
            // As the window: the plate is stepped only while one of the two looks is the plate.
            var figure: ChladniMotion.Shown?
            if shown.primary == .chladni || shown.partner == .chladni {
                let target = ChladniPlate.modes(frequencies: heard.frequencies, amplitudes: heard.amplitudes,
                                                count: heard.count)
                figure = plate.step(towards: target, after: seconds, still: false)
            }
            film.append(Shown(field: field, look: shown, plate: figure))
        }
        return film
    }

    /// The frame of a `count`-frame film shown at `seconds` into it: the nearest, 0 ..< `count`.
    /// A time before the film or not a finite number is its first frame, one past it the last.
    public static func index(at seconds: Double, count: Int) -> Int {
        guard count > 0, seconds.isFinite, seconds > 0 else { return 0 }
        let frame = (seconds * Double(framesPerSecond)).rounded()
        return frame >= Double(count - 1) ? count - 1 : Int(frame)
    }
}

extension FieldFrame {
    /// The frame without any body reading: what an export draws (`FieldExport`), and what the video
    /// window's layer shows, so the window previews the film the export will write.
    public var withoutBody: FieldFrame {
        var frame = self
        frame.pulse = nil
        frame.hrv = nil
        frame.coherence = nil
        frame.breath = nil
        return frame
    }
}
