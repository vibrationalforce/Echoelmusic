import EchoelCore
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
/// ceiling still applies — they live in `FieldMotion`, not in the device.
public enum FieldExport {
    /// The film's frames a second: the video export's own rate.
    public static let framesPerSecond = 30

    /// The loudest sample of each frame's stretch of a mix, read block by block: frame `n` covers
    /// the samples from `n` to `n + 1` frame durations, rounded down, whatever the block size. A
    /// sample that is not a finite number counts as silence, as on the meter.
    public struct Peaks: Sendable {
        public let sampleRate: Double
        /// The finished frames' peaks, linear, 1 = full scale.
        public private(set) var peaks: [Float] = []
        private var loudest: Float = 0
        /// Samples read so far.
        private var position: Int64 = 0
        /// Where the frame being read starts and ends, in samples.
        private var frameStart: Int64 = 0
        private var frameEnd: Int64 = 1

        public init(sampleRate: Double) {
            self.sampleRate = sampleRate.isFinite && sampleRate >= 1 ? sampleRate : 48_000
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
                index += take
                position += Int64(take)
                if position >= frameEnd {
                    peaks.append(loudest)
                    loudest = 0
                    frameStart = frameEnd
                    frameEnd = end(of: peaks.count)
                }
            }
        }

        /// Every frame's peak, the last one too when the mix ends inside it.
        public var finished: [Float] {
            position > frameStart ? peaks + [loudest] : peaks
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
        let signature = project.timeSignature
        let context = project.context
        var frames: [FieldFrame] = []
        frames.reserveCapacity(Swift.max(0, count))
        for index in 0..<Swift.max(0, count) {
            let seconds = start + Double(index) / Double(framesPerSecond)
            let level = index < levels.count ? levels[index] : 0
            frames.append(FieldFrame.at(tick: map.position(atSeconds: seconds), signature: signature, context: context,
                                        level: level, pulse: nil, hrv: nil, coherence: nil, isPlaying: true,
                                        breath: nil))
        }
        return frames
    }

    /// What the Field shows on each frame: the motion stepped from the first frame at the film's
    /// rate, at full detail and never held still.
    public static func motion(_ frames: [FieldFrame]) -> [FieldMotion.Shown] {
        var motion = FieldMotion()
        let seconds = 1 / Double(framesPerSecond)
        let patternScale = FieldDetail(level: .full).patternScale
        var shown: [FieldMotion.Shown] = []
        shown.reserveCapacity(frames.count)
        for frame in frames {
            shown.append(motion.step(frame, after: seconds, still: false, patternScale: patternScale))
        }
        return shown
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
