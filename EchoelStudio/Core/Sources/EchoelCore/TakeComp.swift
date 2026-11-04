import Foundation

public typealias TakeGroupID = Identifier<TakeGroup>

/// A take folder (Recovery 4, 2026-11-04): several takes of one track stacked as lanes, and the
/// comp — which take sounds over which stretch of the timeline. Non-destructive: every take stays
/// as it was recorded, a region on an audio track or a placed clip on an instrument track; the
/// comp is only a list of stretches, each naming a take. Optional inside format 4: a track
/// without takes stores no key, exactly as before, and an earlier build that meets one plays
/// every take as an ordinary region or clip.
public struct TakeGroup: Codable, Equatable, Sendable, Identifiable {
    public var id: TakeGroupID
    /// The takes, oldest first — the lanes from top to bottom: region ids on an audio track,
    /// placement ids on an instrument track. Two at least, each in one group only.
    public var takes: [UUID]
    /// Which take sounds where: rising, never overlapping, each naming one of `takes`. Where no
    /// stretch lies, the group is silent.
    public var comp: [CompSegment]

    public init(id: TakeGroupID = TakeGroupID(), takes: [UUID], comp: [CompSegment]) {
        self.id = id
        self.takes = takes
        self.comp = comp
    }

    /// The most takes one group holds, and the most stretches its comp has: far more than any
    /// session records; the bounds keep a damaged file from carrying millions.
    public static let maximumTakes = 64
    public static let maximumSegments = 4_096
}

/// One stretch of a comp: the take `take` sounds from `start` to `end` (ticks, end excluded).
public struct CompSegment: Codable, Equatable, Hashable, Sendable {
    public var start: Tick
    public var end: Tick
    public var take: UUID

    public init(start: Tick, end: Tick, take: UUID) {
        self.start = start
        self.end = end
        self.take = take
    }
}

public enum TakeComp {
    /// Half the crossfade at a cut between two takes: 5 ms either side, so the outgoing take falls
    /// and the incoming one rises over 10 ms around the cut — short enough not to smear an attack,
    /// long enough that a waveform cut mid-cycle does not click.
    public static let halfCrossfadeSeconds = 0.005

    /// `comp` with `take` sounding over `start ..< end` and everything else as it was; neighbours
    /// of one take that touch become one stretch. Rising and non-overlapping in, so out.
    public static func painting(_ comp: [CompSegment], take: UUID, from start: Tick, to end: Tick) -> [CompSegment] {
        guard start < end else { return comp }
        var result: [CompSegment] = []
        for segment in comp {
            if segment.end <= start || segment.start >= end {
                result.append(segment)
                continue
            }
            if segment.start < start { result.append(CompSegment(start: segment.start, end: start, take: segment.take)) }
            if segment.end > end { result.append(CompSegment(start: end, end: segment.end, take: segment.take)) }
        }
        result.append(CompSegment(start: start, end: end, take: take))
        result.sort { $0.start < $1.start }
        return merged(result)
    }

    /// `comp` with `take` sounding over the parts of `start ..< end` no stretch covers yet: an
    /// older take joining a folder fills its gaps and takes nothing from the takes chosen there.
    public static func filling(_ comp: [CompSegment], take: UUID, from start: Tick, to end: Tick) -> [CompSegment] {
        guard start < end else { return comp }
        var result = comp
        var cursor = start
        for segment in comp where segment.end > start && segment.start < end {
            if segment.start > cursor { result.append(CompSegment(start: cursor, end: segment.start, take: take)) }
            cursor = Swift.max(cursor, segment.end)
        }
        if cursor < end { result.append(CompSegment(start: cursor, end: end, take: take)) }
        result.sort { $0.start < $1.start }
        return merged(result)
    }

    /// The stretch a tap on a take lane chooses: the bar the tap falls in, inside the take.
    public static func stretch(tappedAt tick: Tick, in span: Range<Tick>, meter: MeterMap) -> Range<Tick>? {
        let at = Swift.max(0, tick)
        let bar = meter.barStart(at: at)
        let from = Swift.max(bar, span.lowerBound)
        let to = Swift.min(bar + meter.ticksPerBar(at: at), span.upperBound)
        return from < to ? from..<to : nil
    }

    /// The stretch a swipe along a take lane from `start` to `end` chooses, either direction: both
    /// ends on the grid, inside the take. Nil when nothing is left.
    public static func stretch(swipedFrom start: Tick, to end: Tick, in span: Range<Tick>, snap: SnapGrid,
                               meter: MeterMap) -> Range<Tick>? {
        let from = Swift.max(snap.nearest(Swift.min(start, end), meter: meter), span.lowerBound)
        let to = Swift.min(snap.nearest(Swift.max(start, end), meter: meter), span.upperBound)
        return from < to ? from..<to : nil
    }

    /// The stretches `take` sounds over in `comp`, in order.
    public static func chosen(_ take: UUID, in comp: [CompSegment]) -> [Range<Tick>] {
        comp.filter { $0.take == take }.map { $0.start..<$0.end }
    }

    /// Touching stretches of one take as one.
    static func merged(_ comp: [CompSegment]) -> [CompSegment] {
        var result: [CompSegment] = []
        for segment in comp {
            if let last = result.last, last.take == segment.take, last.end == segment.start {
                result[result.count - 1].end = segment.end
            } else {
                result.append(segment)
            }
        }
        return result
    }

    /// The comp a new folder starts with: each take over its own span, a later take over an earlier
    /// one where they overlap — what a musician who just recorded again wants to hear.
    public static func latestWins(_ spans: [(take: UUID, span: Range<Tick>)]) -> [CompSegment] {
        spans.reduce(into: []) { comp, entry in
            comp = painting(comp, take: entry.take, from: entry.span.lowerBound, to: entry.span.upperBound)
        }
    }
}

extension Track {
    /// The track's take folders; empty while it has none.
    public var takeGroups: [TakeGroup] {
        get { storedTakeGroups ?? [] }
        set { storedTakeGroups = newValue.isEmpty ? nil : newValue }
    }

    public func takeGroupIndex(_ id: TakeGroupID) -> Int? {
        takeGroups.firstIndex { $0.id == id }
    }

    /// The folder `take` is in, if any.
    public func takeGroup(holding take: UUID) -> TakeGroup? {
        takeGroups.first { $0.takes.contains(take) }
    }

    /// Whether `take` names something this track holds as a take: a region on an audio track, a
    /// placement on an instrument track.
    func holdsTake(_ take: UUID) -> Bool {
        switch kind {
        case .audio: regions.contains { $0.id.rawValue == take }
        case .instrument: placements.contains { $0.id.rawValue == take }
        case .returnTrack, .video: false
        }
    }

    /// The folders that play as folders: two takes or more that this track still holds. A folder
    /// cut down to one take — a song reduced for a bake — plays that take whole.
    var playingTakeGroups: [TakeGroup] {
        takeGroups.filter { $0.takes.lazy.filter(holdsTake).count >= 2 }
    }
}

extension Project {
    /// Where take `take` of `track` sounds on the timeline, ticks.
    public func takeSpan(_ take: UUID, on track: Track) -> Range<Tick>? {
        switch track.kind {
        case .audio:
            guard let region = track.regions.first(where: { $0.id.rawValue == take }),
                  let stop = Arranging.end(of: region, in: self), stop > region.start else { return nil }
            return region.start..<stop
        case .instrument:
            guard let placement = track.placements.first(where: { $0.id.rawValue == take }),
                  let stop = Arranging.end(of: placement, in: track), stop > placement.start else { return nil }
            return placement.start..<stop
        case .returnTrack, .video:
            return nil
        }
    }

    /// The takes of `track` other than `take` whose spans overlap its span: what a new take is
    /// folded with. Regions on an audio track, placements on an instrument track, in track order.
    func takes(overlapping take: UUID, on track: Track) -> [UUID] {
        guard let span = takeSpan(take, on: track) else { return [] }
        let ids: [UUID] = switch track.kind {
        case .audio: track.regions.map(\.id.rawValue)
        case .instrument: track.placements.map(\.id.rawValue)
        case .returnTrack, .video: []
        }
        return ids.filter { id in
            guard id != take, let other = takeSpan(id, on: track) else { return false }
            return other.overlaps(span)
        }
    }

    /// Takes that no longer exist leave their folders, with the stretches that named them; a
    /// folder down to one take is no folder. Run after every command (`Command.apply`), so a
    /// deleted region, placement or track never leaves a folder naming it. A song that needs
    /// nothing is not touched, so its storage is not copied.
    mutating func pruneTakeGroups() {
        for t in tracks.indices where !tracks[t].takeGroups.isEmpty {
            let track = tracks[t]
            var seen = Set<UUID>()
            var groups: [TakeGroup] = []
            for var group in track.takeGroups {
                group.takes = group.takes.filter { track.holdsTake($0) && seen.insert($0).inserted }
                let kept = Set(group.takes)
                group.comp = group.comp.filter { kept.contains($0.take) }
                if group.takes.count >= 2 { groups.append(group) }
            }
            if groups != track.takeGroups { tracks[t].takeGroups = groups }
        }
    }

    /// A track's folders as the editor keeps them: only an audio or an instrument track has any;
    /// unique folder ids; two to `maximumTakes` takes each, each a region or placement of the
    /// track and in one folder only; a comp of rising, non-overlapping stretches inside the song,
    /// each naming a take of its folder.
    static func validateTakeGroups(of track: Track) throws {
        guard !track.takeGroups.isEmpty else { return }
        guard track.kind == .audio || track.kind == .instrument else {
            throw invalid("takeGroups", "only an audio or an instrument track records takes")
        }
        var groupIDs = Set<TakeGroupID>(), takes = Set<UUID>()
        for group in track.takeGroups {
            guard groupIDs.insert(group.id).inserted else { throw CommandError.duplicateID(group.id.description) }
            guard (2...TakeGroup.maximumTakes).contains(group.takes.count) else {
                throw invalid("takeGroups", "a folder holds 2…\(TakeGroup.maximumTakes) takes")
            }
            for take in group.takes {
                guard takes.insert(take).inserted else { throw invalid("takeGroups", "a take is in two folders, or twice in one") }
                guard track.holdsTake(take) else { throw invalid("takeGroups", "a take names nothing on its track") }
            }
            guard group.comp.count <= TakeGroup.maximumSegments else {
                throw invalid("takeGroups", "a comp has more than \(TakeGroup.maximumSegments) stretches")
            }
            var previous: Tick = 0
            for segment in group.comp {
                guard segment.start >= previous, segment.start < segment.end, segment.end <= MusicalTime.maximumTick else {
                    throw invalid("takeGroups", "a comp's stretches rise from 0, never overlap and end inside the song")
                }
                guard group.takes.contains(segment.take) else { throw invalid("takeGroups", "a comp names a take of another folder") }
                previous = segment.end
            }
        }
    }
}

// MARK: - Editing (through the commands)

extension Track {
    /// A take cut in two at `tick` (Split): the part after the cut, `tail`, joins the folder right
    /// after the take, and the comp's stretches of the take past the cut name it — the folder
    /// sounds as before.
    mutating func splitTake(_ head: UUID, at tick: Tick, into tail: UUID) {
        guard let g = takeGroups.firstIndex(where: { $0.takes.contains(head) }),
              let at = takeGroups[g].takes.firstIndex(of: head) else { return }
        var group = takeGroups[g]
        group.takes.insert(tail, at: at + 1)
        var comp: [CompSegment] = []
        for segment in group.comp {
            guard segment.take == head, segment.end > tick else {
                comp.append(segment)
                continue
            }
            if segment.start < tick { comp.append(CompSegment(start: segment.start, end: tick, take: head)) }
            comp.append(CompSegment(start: Swift.max(segment.start, tick), end: segment.end, take: tail))
        }
        group.comp = comp
        takeGroups[g] = group
    }
}

extension Project {
    /// `foldTake`: the take joins the folder of a take it overlaps, or a new folder `newGroup`
    /// with every take it overlaps, and sounds over its whole span. Older takes that join fill
    /// only where nothing is chosen yet.
    mutating func foldTake(_ take: UUID, on trackID: TrackID, newGroup: TakeGroupID) throws {
        let t = try requireTrack(trackID)
        var track = tracks[t]
        guard track.kind == .audio || track.kind == .instrument else {
            throw Self.invalid("track", "only an audio or an instrument track records takes")
        }
        guard let span = takeSpan(take, on: track) else {
            throw Self.invalid("take", "names no region or placement of the track")
        }
        let others = takes(overlapping: take, on: track)
        guard !others.isEmpty else { return }
        var groups = track.takeGroups
        let g: Int
        if let held = groups.firstIndex(where: { $0.takes.contains(take) }) {
            g = held
        } else if let joined = groups.firstIndex(where: { !Set($0.takes).isDisjoint(with: others) }) {
            g = joined
        } else {
            guard !groups.contains(where: { $0.id == newGroup }) else { throw CommandError.duplicateID(newGroup.description) }
            groups.append(TakeGroup(id: newGroup, takes: [], comp: []))
            g = groups.count - 1
        }
        let free = others.filter { other in !groups.contains { $0.takes.contains(other) } }
        for other in free {
            groups[g].takes.append(other)
            if let otherSpan = takeSpan(other, on: track) {
                groups[g].comp = TakeComp.filling(groups[g].comp, take: other, from: otherSpan.lowerBound, to: otherSpan.upperBound)
            }
        }
        // The new take last: the bottom lane, and what sounds over its span.
        groups[g].takes.removeAll { $0 == take }
        groups[g].takes.append(take)
        groups[g].comp = TakeComp.painting(groups[g].comp, take: take, from: span.lowerBound, to: span.upperBound)
        track.takeGroups = groups
        try Self.validateTakeGroups(of: track)
        tracks[t] = track
    }

    /// `compTake`: take `take` of folder `group` sounds over `start ..< end`.
    mutating func compTake(_ take: UUID, in group: TakeGroupID, on trackID: TrackID, from start: Tick, to end: Tick) throws {
        let t = try requireTrack(trackID)
        var track = tracks[t]
        guard let g = track.takeGroupIndex(group) else {
            throw Self.invalid("group", "no such take folder on the track")
        }
        guard track.takeGroups[g].takes.contains(take) else { throw Self.invalid("take", "is not a take of the folder") }
        guard start >= 0, start < end, end <= MusicalTime.maximumTick else {
            throw Self.invalid("end", "the stretch runs from 0 or later to after its start, inside the song")
        }
        track.takeGroups[g].comp = TakeComp.painting(track.takeGroups[g].comp, take: take, from: start, to: end)
        try Self.validateTakeGroups(of: track)
        tracks[t] = track
    }
}

// MARK: - Playing a comp

extension Track {
    /// The audio regions the track plays: each region outside a folder as it is, and for each
    /// folder the pieces of its takes its comp chooses — at a cut between two takes the outgoing
    /// one falls and the incoming one rises over `TakeComp.halfCrossfadeSeconds` either side, with
    /// equal power; where a piece meets silence it rises or falls over the same span, unless it is
    /// the take's own edge, which keeps the take's own fade. Compiled off the render thread; the
    /// engine and the export both play this list, so they play the same comp.
    public func playedRegions(in project: Project) -> [AudioRegion] {
        let groups = kind == .audio ? playingTakeGroups : []
        guard !groups.isEmpty else { return regions }
        let grouped = Set(groups.flatMap(\.takes))
        var result = regions.filter { !grouped.contains($0.id.rawValue) }
        for group in groups {
            for (i, segment) in group.comp.enumerated() {
                guard let region = regions.first(where: { $0.id.rawValue == segment.take }) else { continue }
                // A cut between two parts of one recording that a split left side by side is no cut:
                // the file runs on, so nothing fades there.
                let before = i > 0 && group.comp[i - 1].end == segment.start
                    ? regions.first { $0.id.rawValue == group.comp[i - 1].take } : nil
                let after = i + 1 < group.comp.count && group.comp[i + 1].start == segment.end
                    ? regions.first { $0.id.rawValue == group.comp[i + 1].take } : nil
                let crossIn = before.map { !Self.continues($0, into: region, at: segment.start, in: project) } ?? false
                let crossOut = after.map { !Self.continues(region, into: $0, at: segment.end, in: project) } ?? false
                if let piece = Self.piece(of: region, segment, crossIn: crossIn, crossOut: crossOut, in: project) {
                    result.append(piece)
                }
            }
        }
        // Stable, so a plain region keeps its place among those starting on its tick.
        return result.enumerated().sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Whether `next` carries on `previous`'s file at `tick` without a break: one file, `previous`
    /// ending and `next` starting there, the frames following on.
    static func continues(_ previous: AudioRegion, into next: AudioRegion, at tick: Tick, in project: Project) -> Bool {
        previous.media == next.media && previous.offset + previous.length == next.offset
            && next.start == tick && Arranging.end(of: previous, in: project).map { Swift.abs($0 - tick) <= 1 } == true
            && previous.warpBPM == next.warpBPM
    }

    /// Half a crossfade at `tick`, in ticks of the tempo there; at least one.
    static func halfCrossfadeTicks(at tick: Tick, in project: Project) -> Tick {
        let bpm = project.tempoMap.bpm(at: Swift.max(0, tick))
        let ticks = TakeComp.halfCrossfadeSeconds * bpm / 60 * Double(MusicalTime.ticksPerQuarter)
        guard ticks.isFinite, ticks > 0 else { return 1 }
        return Swift.max(1, Tick(ticks.rounded(.up)))
    }

    /// The part of `region` that `segment` chooses, as a region of its own.
    static func piece(of region: AudioRegion, _ segment: CompSegment, crossIn: Bool, crossOut: Bool,
                      in project: Project) -> AudioRegion? {
        guard let stop = Arranging.end(of: region, in: project) else { return nil }
        let half = { (tick: Tick) -> Tick in halfCrossfadeTicks(at: tick, in: project) }
        let from = Swift.max(region.start, crossIn ? segment.start - half(segment.start) : segment.start)
        let to = Swift.min(stop, crossOut ? segment.end + half(segment.end) : segment.end)
        guard from < to else { return nil }
        func frames(_ tick: Tick) -> Int? {
            if tick <= region.start { return 0 }
            if tick >= stop { return region.length }
            guard let value = project.fileFrames(of: region, at: tick), value.isFinite else { return nil }
            return Swift.min(Swift.max(Int(value.rounded()), 0), region.length)
        }
        guard let first = frames(from), let last = frames(to), last > first else { return nil }
        var piece = region
        piece.start = from
        piece.offset = region.offset + first
        piece.length = last - first
        // Rising: the take's own fade where the piece starts with the take; over the crossfade at a
        // cut; over one crossfade's length where it comes in out of silence.
        if from == region.start {
            piece.fadeIn = region.fadeIn
        } else {
            let peak = crossIn ? segment.start + half(segment.start) : from + 2 * half(from)
            piece.fadeIn = frames(Swift.min(peak, to)).map { $0 - first }
            piece.fadeInCurve = .equalPower
        }
        if to == stop {
            let own = region.effectiveFades.fadeOut
            piece.fadeOut = own > 0 ? Swift.min(own, piece.length) : nil
        } else {
            let fall = crossOut ? segment.end - half(segment.end) : to - 2 * half(to)
            piece.fadeOut = frames(Swift.max(fall, from)).map { last - $0 }
            piece.fadeOutCurve = .equalPower
        }
        // Held inside the piece, the rise first ("in wins"), as every region's are.
        let (rise, fallFrames) = piece.effectiveFades
        piece.fadeIn = rise > 0 ? rise : nil
        piece.fadeOut = fallFrames > 0 ? fallFrames : nil
        return piece
    }
}
