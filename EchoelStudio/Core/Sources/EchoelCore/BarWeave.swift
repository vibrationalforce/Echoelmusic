import Foundation

/// The Weave look's pattern (`FieldPattern.weave`): an elementary cellular automaton, rule 90, on a
/// ring of `width` cells, one generation per bar of the song, started from the song's key. The
/// picture shows the last `history` generations as rows, the newest at the bottom.
///
/// - The first row is the key: its pitch classes (`MusicalContext` root and scale) as twelve cells
///   in the middle of the ring, C leftmost. Each key and scale weaves its own figure.
/// - Rule 90: a cell is lit when exactly one of its two neighbours was. The rule is linear over
///   GF(2) — one generation is T = S + S⁻¹, where S turns the ring by one cell — and in
///   characteristic 2, T^(2^k) = S^(2^k) + S^(−2^k). So any generation is computed directly, one
///   pair of turns per set bit of its number (`row(_:seed:)`): the same row for the same bar
///   wherever and whenever it is drawn, after any seek, with no state carried from frame to frame.
/// - The ring's length is odd, so a weave that has started never dies out: after one generation
///   every row has an even number of lit cells, and only the empty and the full ring step to empty.
///
/// The rows are a function of the key and the place in the song; how the picture moves to a new
/// place (gliding, or fading through dark) is `FieldLookMotion`'s.
///
/// Pure arithmetic on one `UInt64` per row.
public enum BarWeave {
    /// Cells around the ring: odd, and within one 64-bit word.
    public static let width = 61
    /// Generations on screen.
    public static let history = 48
    /// The first of the key's twelve cells, so they sit in the middle of the ring.
    public static let keyOffset = 24
    /// How fast the picture may follow the song, in rows a second (half the Field's clock ceiling,
    /// `FieldPulse.maximumRateHz`): a lit row that passes a point lights it and lets it go, so a point
    /// changes at most twice per row — two and a half times a second here, under the six
    /// transitions (three flashes) a second the flash law allows. A song with faster bars is followed late, and once it
    /// is more than `maximumLead` rows ahead the picture fades through dark to it.
    public static let maximumRowsPerSecond = FieldPulse.maximumRateHz / 2
    /// The most rows the picture glides to; a place further ahead, any place behind (a seek, the
    /// loop's wrap) and a new key are taken through dark instead (`FieldLookMotion`).
    public static let maximumLead = 2.0
    /// A step back shorter than this many bars is no step back: a paused playhead re-rounded by a
    /// tempo change, or a frame read across a new tempo, moves a tick, and the picture stays.
    public static let backwardTolerance = 0.01

    static let mask: UInt64 = (1 << UInt64(width)) - 1

    /// The key's pitch classes as a mask, bit `n` for pitch class `n` (C = 0).
    public static func keyMask(_ context: MusicalContext) -> UInt16 {
        let intervals = context.scale.intervals
        var mask: UInt16 = 0
        for pitchClass in 0..<12 where intervals.contains(((pitchClass - context.root) % 12 + 12) % 12) {
            mask |= 1 << UInt16(pitchClass)
        }
        return mask
    }

    /// The first row: the key's twelve cells in the middle of the ring; one lit cell in the middle
    /// for a key without pitch classes.
    public static func seed(keyMask: UInt16) -> UInt64 {
        var row: UInt64 = 0
        for pitchClass in 0..<12 where keyMask & (1 << UInt16(pitchClass)) != 0 {
            row |= 1 << UInt64(keyOffset + pitchClass)
        }
        return row == 0 ? 1 << UInt64(width / 2) : row
    }

    /// The ring turned by `cells` (positive: towards higher cells), wrapping at `width`.
    static func turn(_ row: UInt64, by cells: Int) -> UInt64 {
        let shift = ((cells % width) + width) % width
        let ring = row & mask
        guard shift != 0 else { return ring }
        return ((ring << UInt64(shift)) | (ring >> UInt64(width - shift))) & mask
    }

    /// One generation of rule 90.
    static func step(_ row: UInt64) -> UInt64 {
        turn(row, by: 1) ^ turn(row, by: -1)
    }

    /// Generation `generation` of the weave that starts at `seed`; empty before the first.
    public static func row(_ generation: Int64, seed: UInt64) -> UInt64 {
        guard generation >= 0 else { return 0 }
        var ring = seed & mask
        var remaining = UInt64(generation)
        var distance = 1   // 2^k, reduced around the ring
        while remaining != 0 {
            if remaining & 1 == 1 { ring = turn(ring, by: distance) ^ turn(ring, by: -distance) }
            remaining >>= 1
            distance = (distance * 2) % width
        }
        return ring
    }

    /// Whether cell `cell` (0 ..< `width`) of `row` is lit.
    public static func isLit(_ row: UInt64, cell: Int) -> Bool {
        guard cell >= 0, cell < width else { return false }
        return row & (1 << UInt64(cell)) != 0
    }

    /// The words the shader reads (`FieldShader`'s `Weave`): the scroll — how far the newest row
    /// has come in, 0 … 1 — and the weave's light, 0 … 1, as floats' bits, two spare words, then
    /// each of the `history` rows, newest first, as its low and its high 32 bits. `position` is the
    /// shown place in bars, counted so the key's row stands complete at 1
    /// (`FieldLookMotion.Shown.weavePosition`).
    public static func words(position: Double, seed: UInt64, light: Double) -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 4 + 2 * history)
        let place = position.isFinite ? Swift.max(position, 0) : 0
        let newest = place.rounded(.down)
        out[0] = Float(place - newest).bitPattern
        out[1] = Float(clamp(light, 0, 1)).bitPattern
        let first = Int64(Swift.min(newest, Double(Int64.max / 2)))
        for index in 0..<history {
            let row = Self.row(first - Int64(index), seed: seed)
            out[4 + 2 * index] = UInt32(truncatingIfNeeded: row)
            out[5 + 2 * index] = UInt32(truncatingIfNeeded: row >> 32)
        }
        return out
    }

    /// The weave's light at (`u`, `v`) — the picture's coordinates, 0 … 1 from the bottom left — in
    /// a frame of `aspect`, before the colour: square cells, `width` across; the newest row slides
    /// in from the bottom, lit as far as it has come; the history fades out at its top. `level` is
    /// the master's guarded loudness (`FieldMotion.Shown.levelLight`), `strength` the weave's own
    /// guarded light (`FieldLookMotion.Shown.weaveLight`). The shader's `weaveColour` computes
    /// exactly this.
    public static func light(u: Double, v: Double, aspect: Double, position: Double, seed: UInt64, level: Double,
                             strength: Double) -> Double {
        let place = position.isFinite ? Swift.max(position, 0) : 0
        let newest = place.rounded(.down), scroll = place - newest
        let side = aspect.isFinite && aspect > 0 ? aspect : 1
        let x = clamp(u, 0, 1) * Double(width), rowsUp = clamp(v, 0, 1) * Double(width) / side
        let offset = scroll - rowsUp
        let back = -offset.rounded(.down)
        guard back >= 0, back < Double(history) else { return 0 }
        let fy = offset - offset.rounded(.down), fx = x - x.rounded(.down)
        let cell = Swift.min(Int(x), width - 1)
        guard isLit(row(Int64(newest) - Int64(back), seed: seed), cell: cell) else { return 0 }
        let edge = Swift.max(Swift.abs(fx - 0.5), Swift.abs(fy - 0.5))
        let shape = 1 - smoothstep(0.3, 0.5, edge)
        let fade = back == 0 ? scroll : 1
        let top = 1 - smoothstep(Double(history) - 8, Double(history), rowsUp)
        let drive = 0.35 + 0.65 * clamp(level, 0, 1)
        return clamp(shape * fade * top * drive * clamp(strength, 0, 1), 0, 1)
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        value.isFinite ? Swift.min(Swift.max(value, low), high) : low
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }
}
