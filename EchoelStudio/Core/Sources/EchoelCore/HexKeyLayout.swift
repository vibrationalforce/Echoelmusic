import Foundation

/// The hex keyboard (Instrument page, second play surface): an isomorphic harmonic table of
/// pointy-top hexagons in rows, every odd row shifted right by half a cell. Each of the six
/// neighbours of a cell is one interval, the same everywhere on the board: to the right a major
/// third, up and to the left a minor third, up and to the right a fifth (the two thirds stacked).
/// So a chord or a scale has ONE shape, wherever it is played: a major triad is a small triangle
/// pointing up, a minor triad one pointing down.
///
/// The board is MIDI notes only. What a note sounds like — the song's tone system, its key lock —
/// is decided after it, on the one live path the piano keys play through as well.
public struct HexKeyLayout: Sendable, Equatable {
    /// One step to the right, in semitones: a major third.
    public static let rightStep = 4
    /// One step up and to the left: a minor third.
    public static let upLeftStep = 3
    /// One step up and to the right: a fifth, the sum of the two.
    public static let upRightStep = rightStep + upLeftStep

    /// A hexagon's height over its width (pointy top): 2 / √3.
    public static let heightPerWidth = 2 / 3.0.squareRoot()
    /// From one row's centres to the next, in cell widths: three quarters of a hexagon's height.
    public static let rowSpacing = 0.75 * heightPerWidth

    /// One cell: where it sits (column in its row, row from the bottom) and the note it plays.
    public struct Cell: Sendable, Hashable, Identifiable {
        public let column: Int
        public let row: Int
        public let pitch: Int
        public var id: Int { row * 1_000 + column }
        /// The note's pitch class, 0 (C) … 11 (B).
        public var pitchClass: Int { ((pitch % 12) + 12) % 12 }
        /// The centre, in cell widths from the board's left edge.
        public var x: Double { Double(column) + (row % 2 == 0 ? 0.5 : 1.0) }
        /// The centre, in cell widths from the board's bottom edge.
        public var y: Double { HexKeyLayout.heightPerWidth / 2 + Double(row) * HexKeyLayout.rowSpacing }
    }

    public let columns: Int
    public let rows: Int
    /// The note of the bottom-left cell.
    public let lowest: Int

    public init(columns: Int, rows: Int, lowest: Int) {
        self.columns = Swift.max(1, columns)
        self.rows = Swift.max(1, rows)
        self.lowest = lowest
    }

    /// The note of the cell at `column` in `row`. Rows climb alternately up-left and up-right,
    /// which the half-cell shift of the odd rows draws.
    public static func pitch(column: Int, row: Int, lowest: Int) -> Int {
        let r = Swift.max(0, row)
        let upRights = (r + 1) / 2
        let upLefts = r / 2
        return lowest + rightStep * column + upRightStep * upRights + upLeftStep * upLefts
    }

    /// Every cell that plays a MIDI note (0 … 127), bottom row first, left to right.
    public var cells: [Cell] {
        var out: [Cell] = []
        out.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let pitch = Self.pitch(column: column, row: row, lowest: lowest)
                if (0...127).contains(pitch) { out.append(Cell(column: column, row: row, pitch: pitch)) }
            }
        }
        return out
    }

    /// The board's size in cell widths: each row is half a cell wider than its cells (the shift),
    /// and the rows stack at `rowSpacing`.
    public var width: Double { Double(columns) + (rows > 1 ? 0.5 : 0) }
    public var height: Double { Self.heightPerWidth + Double(rows - 1) * Self.rowSpacing }

    /// The most columns and rows of cells at least `minimumCell` wide that fit `width` × `height`
    /// (points); at least one of each. Non-finite or non-positive sizes give one cell.
    public static func fitting(width: Double, height: Double, minimumCell: Double) -> (columns: Int, rows: Int) {
        guard width.isFinite, height.isFinite, minimumCell.isFinite, width > 0, height > 0, minimumCell > 0 else {
            return (1, 1)
        }
        let columns = Swift.max(1, Int((width / minimumCell - 0.5).rounded(.down)))
        let cell = width / (Double(columns) + 0.5)
        let free = height / cell - heightPerWidth
        let rows = free < 0 ? 1 : 1 + Int((free / rowSpacing).rounded(.down))
        return (columns, Swift.max(1, Swift.min(rows, 24)))
    }
}
