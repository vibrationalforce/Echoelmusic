import Foundation

/// Where a picture cuts hard (CUT, 2026-11-01): the frames where the image changes at once instead
/// of moving. Each frame comes in as a small picture of its brightness — a grid of cells, 0 (black)
/// … 1 (white), the same grid for every frame — and its change is the mean difference of its cells
/// from the frame before. A hard cut is one frame whose change is large, clearly larger than the
/// frames on either side of it, and large against the changes around it: a pan, a zoom or a
/// moving subject change the picture over many frames, a fade by little in each, sensor noise by
/// almost nothing, and none of them is a cut.
///
/// Streaming: `add` every frame in presentation order, then read `cuts` once. Offline only — it
/// keeps one change per frame. A cell that is not a number counts as no change.
public struct CutDetector: Sendable {
    /// A cut changes the picture by at least this much: the mean cell difference, 0 … 1.
    static let floor: Float = 0.06
    /// … at least this many times the median change of the frames around it …
    static let medianRatio: Float = 3
    /// … and at least this many times the change of each frame next to it.
    static let isolation: Float = 2
    /// Frames either side for the running median.
    static let medianRadius = 15
    /// Two cuts are at least this far apart, in seconds; of two closer ones the larger stays.
    public static let shortestShot = 0.25

    private var previous: [Float] = []
    /// One per frame: how much it changed from the frame before (0 for the first).
    private var changes: [Float] = []
    private var times: [Double] = []

    public init() {}

    /// One frame at `time` seconds: its cells, row by row. A frame of another size than the one
    /// before starts afresh — it is not a cut.
    public mutating func add(_ cells: [Float], at time: Double) {
        var change: Float = 0
        if !cells.isEmpty, cells.count == previous.count {
            var sum: Float = 0
            for index in 0..<cells.count {
                let difference = Swift.abs(cells[index] - previous[index])
                if difference.isFinite { sum += Swift.min(difference, 1) }
            }
            change = sum / Float(cells.count)
        }
        previous = cells
        changes.append(change)
        times.append(time.isFinite ? time : times.last ?? 0)
    }

    /// The first frame of each new shot, in seconds, rising.
    public var cuts: [Double] {
        var picked: [(seconds: Double, change: Float)] = []
        var neighbourhood: [Float] = []
        neighbourhood.reserveCapacity(2 * Self.medianRadius)
        for frame in changes.indices.dropFirst() {
            let change = changes[frame]
            guard change >= Self.floor else { continue }
            let before = changes[frame - 1]
            let after = frame + 1 < changes.count ? changes[frame + 1] : 0
            guard change >= Self.isolation * before, change >= Self.isolation * after else { continue }
            neighbourhood.removeAll(keepingCapacity: true)
            for other in Swift.max(1, frame - Self.medianRadius)...Swift.min(changes.count - 1, frame + Self.medianRadius)
            where other != frame {
                neighbourhood.append(changes[other])
            }
            neighbourhood.sort()
            let median = neighbourhood.isEmpty ? 0 : neighbourhood[neighbourhood.count / 2]
            guard change >= Self.medianRatio * median else { continue }
            let seconds = times[frame]
            if let last = picked.last, seconds - last.seconds < Self.shortestShot {
                if change > last.change { picked[picked.count - 1] = (seconds, change) }
            } else {
                picked.append((seconds, change))
            }
        }
        return picked.map(\.seconds)
    }
}
