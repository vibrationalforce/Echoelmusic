// SpatialTrajectory.swift
// Spatial S-A2 (ADR-007 §2, ADR-008 §6, accepted 2026-10-04): WHERE each object of an immersive
// master was, over the piece, stamped on the SAMPLE clock. A pure value — Foundation only, no
// clock, no randomness, no store — so the stem capture (S-A3) can feed it, the export folder
// (S-A4) can write it and the ADM BWF writer (S-A5) can turn it into audioBlockFormats, and all
// three read ONE trajectory.
//
// THE RULES (each one a decision, not a default):
// · Time is an INTEGER sample index at `sampleRate`, never a Double of seconds and never `Date()`.
//   How many decimals a file gets is the WRITER's decision (ADR-007 K5); a stored Double would
//   have made it here, silently, and rounding error would have broken block contiguity.
// · Recording runs at `recordRateHz` (20 Hz). A held position costs TWO points however long it
//   is held: the first and the latest sample of the hold. That compression is exact — the
//   linear interpolation between the points of the result reproduces every recorded sample.
// · Thinning is TIME-FAITHFUL Ramer–Douglas–Peucker: a point is compared with the interpolation
//   of the kept neighbours AT ITS OWN TIME (synchronised distance), never with the perpendicular
//   distance to the path — a perpendicular test would erase a pause or a change of speed, and
//   the studio would hear the object arrive early. Bounds: ≤ 1° azimuth, ≤ 1° elevation (each
//   on its own, which is stricter than a great-circle angle near the poles) and ≤ 0.01 distance,
//   plus a maximum block length, so no single audioBlockFormat spans too much time.
// · Azimuth interpolates along the SHORTER arc: 170° → −170° passes 180°, not 0°.
//
// Built: yes. Wired: NO — nothing records a trajectory in the app yet (S-A3 will). Device: no.

import Foundation

// MARK: - One object's path

public struct SpatialTrajectory: Codable, Sendable, Equatable {

    public static let formatVersion = 1
    /// Control rate of the recording (ADR-007 §2, research §5). The real information rate is
    /// ~1 Hz (the bio bus law); 20 Hz keeps a hand-dragged object smooth.
    public static let recordRateHz = 20
    public static let maxAngleErrorDegrees: Float = 1
    public static let maxDistanceError: Float = 0.01

    public struct Point: Codable, Sendable, Equatable {
        /// Sample index at the trajectory's `sampleRate`, from the start of the master.
        public let sampleTime: Int64
        public let position: SpatialPosition

        public init(sampleTime: Int64, position: SpatialPosition) {
            self.sampleTime = sampleTime
            self.position = position
        }
    }

    public let version: Int
    public let objectID: String
    public let sampleRate: Int
    public private(set) var points: [Point]

    /// A non-positive rate falls back to the master's rate — a trajectory without a clock is not one.
    public init(objectID: String, sampleRate: Int = ImmersiveMasterPlan.sampleRate) {
        self.version = Self.formatVersion
        self.objectID = objectID
        self.sampleRate = sampleRate > 0 ? sampleRate : ImmersiveMasterPlan.sampleRate
        self.points = []
    }

    /// Samples between two recordings at `recordRateHz`, never below 1.
    public static func controlInterval(sampleRate: Int) -> Int64 {
        Int64(max(1, sampleRate / recordRateHz))
    }

    /// Records one position. Returns false — and records nothing — for a negative time or a time
    /// that does not move forward: a trajectory is a function of time, one place per instant.
    @discardableResult
    public mutating func append(sampleTime: Int64, position: SpatialPosition) -> Bool {
        guard sampleTime >= 0 else { return false }
        if let last = points.last, sampleTime <= last.sampleTime { return false }
        let point = Point(sampleTime: sampleTime, position: position)
        let count = points.count
        // A hold: the last two points already sit at this place, so the newest one only moves the
        // END of the hold. First and latest sample of a hold survive; everything between is exact
        // under linear interpolation and costs nothing.
        if count >= 2,
           points[count - 1].position == position,
           points[count - 2].position == position {
            points[count - 1] = point
        } else {
            points.append(point)
        }
        return true
    }

    /// The position at `sampleTime` under linear interpolation of the stored points — the same
    /// reading every bound in `thinned` is measured against. Before the first point it holds the
    /// first, after the last it holds the last. Nil only for an empty trajectory.
    public func position(atSampleTime sampleTime: Int64) -> SpatialPosition? {
        guard let first = points.first, let last = points.last else { return nil }
        if sampleTime <= first.sampleTime { return first.position }
        if sampleTime >= last.sampleTime { return last.position }
        // Binary search for the segment that contains the time.
        var lo = 0
        var hi = points.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if points[mid].sampleTime <= sampleTime { lo = mid } else { hi = mid }
        }
        return Self.interpolate(points[lo], points[hi], at: sampleTime)
    }

    // MARK: Thinning

    /// The fewest points whose interpolation stays within the bounds at EVERY recorded sample,
    /// then cut so no two neighbours are further apart than `maxBlockSamples` (the cuts lie on
    /// the thinned line and change nothing about it). First and last point always survive.
    /// A non-positive `maxBlockSamples` means no limit.
    public func thinned(maxAngleError: Float = SpatialTrajectory.maxAngleErrorDegrees,
                        maxDistanceError: Float = SpatialTrajectory.maxDistanceError,
                        maxBlockSamples: Int64) -> SpatialTrajectory {
        // Empty has nothing to thin. Two points have nothing to drop — but a HOLD is two points
        // however long it lasts, and it still owes the block cut below, so it must not return here.
        guard !points.isEmpty else { return self }
        let angleBound = maxAngleError.isFinite && maxAngleError > 0 ? maxAngleError : Self.maxAngleErrorDegrees
        let distanceBound = maxDistanceError.isFinite && maxDistanceError > 0 ? maxDistanceError : Self.maxDistanceError
        let kept = points.count > 2
            ? keptPoints(angleBound: angleBound, distanceBound: distanceBound)
            : points

        // 2. Block length AFTER the thinning, by inserting points that lie ON the thinned line at
        //    `start + k · maxBlockSamples`. A point on the line does not move the interpolation, so
        //    the error bound of step 1 stays exact — splitting at RECORDED points instead would
        //    move the line under points already judged and could double their error, and a hold
        //    (two points, however long) has no recorded point in between to split at.
        var result = SpatialTrajectory(objectID: objectID, sampleRate: sampleRate)
        guard maxBlockSamples > 0 else {
            result.points = kept
            return result
        }
        var split: [Point] = [kept[0]]
        for (a, b) in zip(kept, kept.dropFirst()) {
            var border = a.sampleTime + maxBlockSamples
            while border < b.sampleTime {
                split.append(Point(sampleTime: border, position: Self.interpolate(a, b, at: border)))
                border += maxBlockSamples
            }
            split.append(b)
        }
        result.points = split
        return result
    }

    /// 1. Iterative RDP over the whole path — a long take must not recurse thousands of frames
    ///    deep. Every span that ends up between two kept points was checked with NO interior
    ///    point above the bounds, so the bound is exact against the kept line.
    private func keptPoints(angleBound: Float, distanceBound: Float) -> [Point] {
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var spans: [(start: Int, end: Int)] = [(start: 0, end: points.count - 1)]
        while let span = spans.popLast() {
            guard span.end - span.start > 1 else { continue }
            var worstIndex = -1
            var worstScore: Float = 1
            for index in (span.start + 1)..<span.end {
                let score = Self.errorScore(of: points[index], between: points[span.start], and: points[span.end],
                                            angleBound: angleBound, distanceBound: distanceBound)
                if score > worstScore {          // strictly worse: ties keep the earlier index
                    worstScore = score
                    worstIndex = index
                }
            }
            guard worstIndex >= 0 else { continue }
            keep[worstIndex] = true
            spans.append((start: span.start, end: worstIndex))
            spans.append((start: worstIndex, end: span.end))
        }
        return zip(points, keep).compactMap { $0.1 ? $0.0 : nil }
    }

    // MARK: Writers

    /// `sample_time,seconds,azimuth,elevation,distance`, one row per point. Seconds are exact to
    /// nine decimals from integer arithmetic; angles and distance carry four. Byte-stable.
    public func csv() -> String {
        var lines = ["sample_time,seconds,azimuth,elevation,distance"]
        lines.reserveCapacity(points.count + 1)
        for point in points {
            lines.append("\(point.sampleTime),\(Self.seconds(point.sampleTime, rate: sampleRate)),"
                         + "\(Self.fixed(point.position.azimuth)),\(Self.fixed(point.position.elevation)),"
                         + "\(Self.fixed(point.position.distance))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Sorted-key JSON: the same trajectory always encodes to the same bytes.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    // MARK: Pure helpers

    /// Wraps any angle into −180 … +180.
    static func wrapDegrees(_ angle: Float) -> Float {
        guard angle.isFinite else { return 0 }
        var wrapped = fmodf(angle + 180, 360)
        if wrapped < 0 { wrapped += 360 }
        return wrapped - 180
    }

    static func interpolate(_ a: Point, _ b: Point, at sampleTime: Int64) -> SpatialPosition {
        // The ends and a hold answer with the stored value itself: the wrap below is exact in
        // real numbers but not in Float, and a hold must reproduce its position bit for bit.
        if sampleTime <= a.sampleTime || a.position == b.position { return a.position }
        if sampleTime >= b.sampleTime { return b.position }
        let span = b.sampleTime - a.sampleTime
        let t = Float(Double(sampleTime - a.sampleTime) / Double(span))
        let azimuthStep = wrapDegrees(b.position.azimuth - a.position.azimuth)
        return SpatialPosition(
            azimuth: wrapDegrees(a.position.azimuth + azimuthStep * t),
            elevation: a.position.elevation + (b.position.elevation - a.position.elevation) * t,
            distance: a.position.distance + (b.position.distance - a.position.distance) * t)
    }

    /// The largest of the three errors, each divided by its bound — above 1 means "keep me".
    static func errorScore(of point: Point, between a: Point, and b: Point,
                           angleBound: Float, distanceBound: Float) -> Float {
        let predicted = interpolate(a, b, at: point.sampleTime)
        let azimuth = abs(wrapDegrees(point.position.azimuth - predicted.azimuth)) / angleBound
        let elevation = abs(point.position.elevation - predicted.elevation) / angleBound
        let distance = abs(point.position.distance - predicted.distance) / distanceBound
        return max(azimuth, max(elevation, distance))
    }

    static func seconds(_ sampleTime: Int64, rate: Int) -> String {
        let rate64 = Int64(max(1, rate))
        let whole = sampleTime / rate64
        let remainder = sampleTime % rate64
        let nanos = remainder * 1_000_000_000 / rate64
        let fraction = String(nanos)
        return "\(whole)." + String(repeating: "0", count: max(0, 9 - fraction.count)) + fraction
    }

    static func fixed(_ value: Float) -> String {
        String(format: "%.4f", Double(value))
    }
}

// MARK: - Every object of a scene

/// The recorder's state: one trajectory per scene object, sampled from the ONE scene at the
/// control rate. An object that joins mid-take starts where it joined; one that leaves keeps the
/// points it had — a stem does not vanish because its lane was deleted after the take.
public struct SpatialTrajectoryRecording: Codable, Sendable, Equatable {

    public let sampleRate: Int
    public private(set) var trajectories: [String: SpatialTrajectory]

    public init(sampleRate: Int = ImmersiveMasterPlan.sampleRate) {
        self.sampleRate = sampleRate > 0 ? sampleRate : ImmersiveMasterPlan.sampleRate
        self.trajectories = [:]
    }

    /// Records every object of `scene` at `sampleTime`.
    public mutating func sample(_ scene: SpatialScene, atSampleTime sampleTime: Int64) {
        for object in scene.objects {
            var trajectory = trajectories[object.id]
                ?? SpatialTrajectory(objectID: object.id, sampleRate: sampleRate)
            trajectory.append(sampleTime: sampleTime, position: object.position)
            trajectories[object.id] = trajectory
        }
    }

    public func trajectory(objectID: String) -> SpatialTrajectory? {
        trajectories[objectID]
    }

    /// Object ids in a stable order, so a writer enumerates the same files every time.
    public var objectIDs: [String] { trajectories.keys.sorted() }
}
