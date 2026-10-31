import Foundation

/// The decisions of a video export as pure functions (wave W7, C6): the frame shapes social
/// platforms take, how a picture fills or fits one without losing its file, which stretch of the
/// song a short export covers, how long the export runs, and the gain that brings the mix to the
/// loudness social platforms play at. The app renders and writes; nothing here touches a file.
///
/// Material is never cut to fit: a long-form export runs as long as the longer of the mix and the
/// picture, and a short one covers exactly the stretch the musician chose. No length is capped.
public enum VideoExportPlan {
    /// The frame of the exported file.
    public enum Shape: String, CaseIterable, Sendable {
        /// 9:16, 1080 × 1920 — Reels, Shorts, TikTok, Stories.
        case vertical
        /// 16:9, 1920 × 1080 — YouTube, long form.
        case landscape
        /// 1:1, 1080 × 1080.
        case square
        /// 4:5, 1080 × 1350 — the tallest a feed post shows.
        case portrait

        public var width: Int {
            switch self {
            case .vertical, .square, .portrait: 1_080
            case .landscape: 1_920
            }
        }

        public var height: Int {
            switch self {
            case .vertical: 1_920
            case .landscape: 1_080
            case .square: 1_080
            case .portrait: 1_350
            }
        }

        public var title: String {
            switch self {
            case .vertical: "9:16"
            case .landscape: "16:9"
            case .square: "1:1"
            case .portrait: "4:5"
            }
        }
    }

    /// How a picture of another shape sits in the frame. Either way the file stays whole; only
    /// what the export shows of it differs.
    public enum Fit: String, CaseIterable, Sendable {
        /// Fills the frame; the overhang is outside the frame (cropped in the export only).
        case fill
        /// Shows the whole picture; the rest of the frame is black.
        case fit
    }

    public enum Codec: String, CaseIterable, Sendable {
        case h264
        case hevc
    }

    /// Where a picture of `source` size sits in a frame of `target` size: the scale and the offset
    /// of its top-left corner, centred. Nil for a size that is not a picture.
    public static func placement(sourceWidth: Double, sourceHeight: Double, targetWidth: Double, targetHeight: Double,
                                 fit: Fit) -> (scale: Double, x: Double, y: Double)? {
        guard sourceWidth.isFinite, sourceHeight.isFinite, targetWidth.isFinite, targetHeight.isFinite,
              sourceWidth > 0, sourceHeight > 0, targetWidth > 0, targetHeight > 0 else { return nil }
        let across = targetWidth / sourceWidth
        let down = targetHeight / sourceHeight
        let scale = fit == .fill ? Swift.max(across, down) : Swift.min(across, down)
        return (scale, (targetWidth - sourceWidth * scale) / 2, (targetHeight - sourceHeight * scale) / 2)
    }

    // MARK: - Short and long

    /// The lengths a short export is suggested at, in seconds; each becomes whole bars.
    public static let shortFormSeconds: [Double] = [15, 30, 60, 90]

    /// The stretch of whole bars from `startBar` (1-based) that lasts closest to `seconds` at the
    /// song's tempo map, at least one bar: the tick range a short export of about that length covers.
    public static func shortRange(in project: Project, startBar: Int, seconds: Double) -> ClosedRange<Tick>? {
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        guard bar > 0, startBar >= 1, seconds.isFinite, seconds > 0 else { return nil }
        let (start, overflow) = Tick(startBar - 1).multipliedReportingOverflow(by: bar)
        guard !overflow, start < MusicalTime.maximumTick else { return nil }
        let map = project.tempoMap
        let target = map.tick(atSeconds: map.seconds(at: start) + seconds)
        let end = Swift.max(start + bar, Arranging.nearestBar(target, signature: project.timeSignature))
        return start...Swift.min(end, MusicalTime.maximumTick)
    }

    /// The seconds of song time `ticks` covers.
    public static func seconds(of ticks: ClosedRange<Tick>, in project: Project) -> (from: Double, to: Double) {
        let map = project.tempoMap
        return (map.seconds(at: ticks.lowerBound), map.seconds(at: ticks.upperBound))
    }

    /// How long a long-form export runs: the longer of the mix and the picture — never one cut to
    /// the other (the old bug: a 3-second sound once cut a 60-second take to 3 seconds).
    public static func longFormSeconds(mixSeconds: Double, of project: Project) -> Double {
        let mix = mixSeconds.isFinite ? Swift.max(0, mixSeconds) : 0
        return Swift.max(mix, VideoPlan.programEnd(of: project))
    }

    /// The song's cut list between `from` and `to` seconds, shifted so the export starts at 0.
    public static func program(of project: Project, from: Double, to: Double) -> [VideoPlan.Segment] {
        guard from.isFinite, to.isFinite, to > from else { return [] }
        return VideoPlan.program(of: project).compactMap { segment in
            let start = Swift.max(segment.songSeconds, from)
            let stop = Swift.min(segment.songEnd, to)
            guard stop > start else { return nil }
            return VideoPlan.Segment(region: segment.region, media: segment.media,
                                     fileSeconds: segment.fileSeconds + (start - segment.songSeconds),
                                     songSeconds: start - from, duration: stop - start)
        }
    }

    // MARK: - Loudness

    /// The integrated loudness social platforms play at, LUFS (BS.1770).
    public static let socialLoudness: Double = -14
    /// The true-peak ceiling the gain respects, dBTP, so the lossy encoding does not clip.
    public static let truePeakCeiling: Double = -1

    /// The gain in decibels that brings a mix measured at `integrated` LUFS with `truePeak` dBTP to
    /// `socialLoudness`, lowered when the peak would pass the ceiling. 0 for a silent or unmeasured
    /// mix: nothing is raised that was not measured.
    public static func loudnessGain(integrated: Double, truePeak: Double) -> Double {
        guard integrated.isFinite, integrated > -70 else { return 0 }
        var gain = socialLoudness - integrated
        if truePeak.isFinite { gain = Swift.min(gain, truePeakCeiling - truePeak) }
        return gain.isFinite ? gain : 0
    }
}
