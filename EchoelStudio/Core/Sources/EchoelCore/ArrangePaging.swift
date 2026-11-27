/// Where the arrangement's lanes scroll to by themselves. Two moments decide it, both pure
/// arithmetic on the lanes' points, so the view only reads and writes the scroll position:
///
/// - While the song plays and the lanes follow it, the page turns once the playhead reaches the
///   last tenth of the view or has left it (a loop's wrap, a locate), so the playhead then stands
///   a tenth of the width in from the left (`target(showing:ticksPerPoint:left:width:)`).
/// - When Arrange opens again — after a look at the Mixer, or at the next launch of the window —
///   it opens where it was left, not at bar 1 (A88-5). It turns to where Play starts instead only
///   when the playhead moved while another view was open (a Stop or a locate there), the song is
///   stopped and the lanes follow the playhead, and only if Play's start would be out of sight
///   from the kept place
///   (`opening(leftEdge:playheadWhenLeft:restingAt:playing:follows:ticksPerPoint:width:contentWidth:)`).
///
/// What is kept when Arrange is left is the tick at the lanes' left edge
/// (`leftEdgeTick(atX:ticksPerPoint:)`) and the tick the playhead stood on
/// (`playheadTick(heard:)`): ticks, not points, so a zoom or a meter changed in the meantime still
/// opens on the same bar. Both are kept per window (`storageKey`, `playheadStorageKey`), never in
/// the song, and neither is an edit — so a song opened meanwhile opens on the window's place too,
/// held to its own last page.
public enum ArrangePaging {
    /// Where the tick at the lanes' left edge is kept when Arrange is left: in the window's scene
    /// storage, never in the song file.
    public static let storageKey = "arrange.leftEdgeTick"
    /// Where the tick the playhead stood on is kept when Arrange is left, beside the left edge.
    public static let playheadStorageKey = "arrange.playheadTick"
    /// What the playhead's storage holds until Arrange is first left in a window. No tick is
    /// negative, so it never reads as one (`keptTick(_:)`).
    public static let nothingKept = -1
    /// A page turned to a position puts it this share of the width in from the left edge, and the
    /// page turns once the position comes within this share of the right edge.
    public static let leadIn: Double = 0.1

    /// The x the lanes' left edge scrolls to so that `position` (in ticks) shows a tenth of the
    /// width in from the left — or nil while it shows already, short of the last tenth. A position
    /// that is not a number is read as the playhead line draws it (`TimelineGeometry`, the start).
    /// Nil too while the lanes have no width yet or a number of the view is not finite.
    public static func target(showing position: Double, ticksPerPoint: Double, left: Double, width: Double) -> Double? {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0, left.isFinite, width.isFinite, width > 0 else { return nil }
        let x = TimelineGeometry.x(ofPosition: position, ticksPerPoint: ticksPerPoint)
        let inset = width * leadIn
        guard x > left + width - inset || x < left else { return nil }
        return Swift.max(0, x - inset)
    }

    /// The tick at the lanes' left edge `x` points in, to keep when Arrange is left: to the nearest
    /// tick, never before the song's start nor past the last tick a song holds. A scale that is not
    /// a positive number keeps the start.
    public static func leftEdgeTick(atX x: Double, ticksPerPoint: Double) -> Tick {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        return TimelineGeometry.tick(clamping: (x * ticksPerPoint).rounded())
    }

    /// The tick to keep for where the playhead stands when Arrange is left, from where it is heard
    /// (`AudioEngine.heardTick(in:)`): stopped, that is the transport's resting tick, kept exactly,
    /// so it compares equal to it on the way back; playing, the tick it has reached. A position that
    /// is not a number is kept as the start, where the playhead line draws it.
    public static func playheadTick(heard position: Double) -> Tick {
        TimelineGeometry.tick(clamping: position)
    }

    /// The playhead's tick as its storage holds it: nil while nothing was kept (`nothingKept`, or
    /// any other negative number), and never past the last tick a song holds.
    public static func keptTick(_ stored: Int) -> Tick? {
        guard stored >= 0 else { return nil }
        return Swift.min(Tick(stored), MusicalTime.maximumTick)
    }

    /// The x the lanes' left edge opens at: the place kept when Arrange was left (`leftEdge`), held
    /// to the lanes' last page (`contentWidth` points; the song may have grown shorter meanwhile).
    ///
    /// Where Play starts (`resting`, the transport's resting tick) decides instead only when the
    /// playhead moved while Arrange was away: it stood on `playheadWhenLeft` then, and nil — nothing
    /// kept yet in this window — counts as moved. Then, while the song is stopped and the lanes
    /// follow the playhead, a start out of sight from the kept place, or in its last tenth, opens a
    /// tenth in from the left: the page the follower would turn. A playhead that stands where it
    /// stood opens the kept place, in sight or not: the musician scrolled away from it. Playing,
    /// the follower turns the page itself; with Follow off the kept place alone decides. Without a
    /// width nothing can be judged, so the kept place opens as it is; a scale that is not a
    /// positive number opens at the start.
    public static func opening(leftEdge: Tick, playheadWhenLeft: Tick?, restingAt resting: Tick, playing: Bool,
                               follows: Bool, ticksPerPoint: Double, width: Double, contentWidth: Double) -> Double {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        let kept = TimelineGeometry.x(ofTick: leftEdge, ticksPerPoint: ticksPerPoint)
        guard width.isFinite, width > 0 else { return kept }
        let last = contentWidth.isFinite ? Swift.max(0, contentWidth - width) : Double.infinity
        let left = Swift.min(kept, last)
        let moved = playheadWhenLeft.map { $0 != resting } ?? true
        guard !playing, follows, moved,
              let page = target(showing: Double(resting), ticksPerPoint: ticksPerPoint, left: left, width: width)
        else { return left }
        return Swift.min(page, last)
    }
}
