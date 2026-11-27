import Foundation

/// The notes the note grids sound, for the Field's clouds (G5): each grid's own, and all of them
/// together. A grid lies over the full-screen Field and one over the Field card on the Instrument
/// page. A window shows one of them at a time, but an iPad can show two windows of the app side by
/// side, a grid in each, while every picture of the app draws one set of clouds. A grid's view hands
/// in what it sounds each time it is drawn again (`FieldGridTouches.notes(on:)`), with no finger down
/// that is nothing; kept per grid, that nothing empties its own share and never the notes of the
/// grid being played.
///
/// The clouds show at most `FieldTouchLight.cloudSlots` notes, the first ones first, so the order
/// says which: the grid whose notes changed last comes first, as within a grid the newest note does.
/// The same notes handed in again change nothing, not even the order, so a grid that is merely drawn
/// again never pushes ahead of one being played.
///
/// A value type, so the rule is tested here; the app keeps one for the process (`FieldTouchChannel`).
public struct FieldGridSounding: Equatable, Sendable {
    /// One grid's notes, never empty: a grid that sounds nothing has no share.
    private struct Share: Equatable, Sendable {
        let grid: UUID
        let notes: [FieldTouchLight.Note]
    }

    /// The grids that sound something, the one whose notes changed last first.
    private var shares: [Share] = []

    /// Every grid's notes, as the clouds read them (`FieldTouchLight.shown`): the grid whose notes
    /// changed last first, each grid's notes in their own order, and a note two grids sound once,
    /// from the first of them.
    public private(set) var notes: [FieldTouchLight.Note] = []

    public init() {}

    /// The grid `grid` sounds `sounding` from now on, in place of what it sounded before; none when
    /// it sounds nothing or goes. The other grids' notes stay as they are.
    public mutating func sound(_ sounding: [FieldTouchLight.Note], from grid: UUID) {
        let held = shares.firstIndex { (share: Share) -> Bool in share.grid == grid }
        let before = held.map { (index: Int) -> [FieldTouchLight.Note] in shares[index].notes } ?? []
        guard before != sounding else { return }
        if let held { shares.remove(at: held) }
        if !sounding.isEmpty { shares.insert(Share(grid: grid, notes: sounding), at: 0) }
        notes = Self.together(shares)
    }

    /// The shares' notes one after the other, each note once, the first time it comes.
    private static func together(_ shares: [Share]) -> [FieldTouchLight.Note] {
        var shown = Set<Int>()
        var out: [FieldTouchLight.Note] = []
        for share in shares {
            for note in share.notes where shown.insert(note.id).inserted {
                out.append(note)
            }
        }
        return out
    }
}
