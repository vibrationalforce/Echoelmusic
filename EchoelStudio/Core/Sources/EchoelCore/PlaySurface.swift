import Foundation

/// The surface the screen offers for playing a track's instrument by hand: keys for an instrument
/// whose keys pick a pitch, pads for one whose keys pick a sound — the drums of a kit, the slices
/// a sample is cut into. Pure, so the choice and the pads' order are tested here.
public enum PlaySurface: Equatable, Sendable {
    /// Piano keys or the hex keyboard.
    case keys
    /// The drum kit's pads.
    case drumPads
    /// One pad per slice of the sampler's file; pad `index` plays note `SampleSlice.firstNote + index`.
    case slicePads(count: Int)

    /// The surface for `instrument`. A sampler is played on keys while its file is whole and on
    /// pads once it is cut: its slices sit on consecutive notes from `SampleSlice.firstNote`, below
    /// where a keyboard on the screen starts.
    public static func surface(for instrument: InstrumentSettings) -> PlaySurface {
        switch instrument.device {
        case .drums:
            return .drumPads
        case .sampler:
            guard let slices = instrument.slices, !slices.isEmpty else { return .keys }
            return .slicePads(count: Swift.min(slices.count, SampleSlice.maximumCount))
        case .synth, .plugin, .unrecognized:
            return .keys
        }
    }

    /// The pads `0 ..< count` in rows of `columns` as a screen shows them, the top row first: the
    /// first pad sits at the bottom left and the numbers rise to the right and then upward, as on
    /// a drum machine. Only the top row may be short. No rows for no pads; fewer than one column
    /// counts as one.
    public static func padRows(count: Int, columns: Int) -> [[Int]] {
        guard count > 0 else { return [] }
        let width = Swift.max(1, columns)
        var rows: [[Int]] = []
        var first = 0
        while first < count {
            rows.append(Array(first..<Swift.min(first + width, count)))
            first += width
        }
        return rows.reversed()
    }
}
