import Foundation

/// The flash limit for a film being exported (2026-11-19). The video window caps footage frame by
/// frame as it shows it (`VideoFlashWatch`); an export wrote the footage as it was, so a strobe cut
/// into a song went into the film unchecked. This collects the gain `VideoFlashLimit` answers for
/// every frame of the film, in order, before the film is written, and the export draws the footage
/// of each frame at its gain — as the window shows footage (the window also dims a Field drawn over
/// it; the export leaves the Field, which has its own limit, as it is).
///
/// One gain a frame, at `framesPerSecond`: frame `n` is the picture at `n / framesPerSecond`
/// seconds, the export's own clock, so a gain is looked up by time and the order AVFoundation asks
/// for frames in does not matter. A value type; nothing here knows a video framework.
public struct ExportFlashGains: Sendable, Equatable {
    /// Seconds between two frames of the film.
    public let frameSeconds: Double
    /// Another picture is drawn over the footage (the Field layer): see
    /// `VideoFlashLimit.next(time:frame:blended:)`.
    public let blended: Bool
    /// The gain of each frame so far, in order; 1 where nothing flashes.
    public private(set) var gains: [Double] = []
    private var limit = VideoFlashLimit()

    public init(framesPerSecond: Int, blended: Bool) {
        frameSeconds = 1 / Double(Swift.max(1, framesPerSecond))
        self.blended = blended
    }

    /// Counts the film's next frame and answers its gain.
    @discardableResult
    public mutating func add(_ frame: VideoFlashCells) -> Double {
        let gain = limit.next(time: Double(gains.count) * frameSeconds, frame: frame, blended: blended)
        gains.append(gain)
        return gain
    }

    /// Whether any frame is shown below full: only then does the export draw the gains.
    public var dims: Bool { gains.contains { $0 < 1 } }

    /// The gain of the frame shown at `seconds`; past the last counted frame, the last gain (a
    /// frame the measuring pass did not see is not brightened), and 1 for an empty film.
    public func gain(at seconds: Double) -> Double {
        guard let last = gains.last else { return 1 }
        guard seconds.isFinite, seconds > 0 else { return gains[0] }
        // A frame's time is a multiple of the frame length; the allowance keeps a time computed as
        // n · length on frame n rather than n − 1.
        let index = Int((seconds / frameSeconds + 1e-6).rounded(.down))
        return index < gains.count ? gains[index] : last
    }

    public static func == (lhs: ExportFlashGains, rhs: ExportFlashGains) -> Bool {
        lhs.frameSeconds == rhs.frameSeconds && lhs.blended == rhs.blended && lhs.gains == rhs.gains
    }
}
