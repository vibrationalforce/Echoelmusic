import Foundation

/// The note grid over the Field: the picture made playable, as the earlier app's touch instrument
/// was (its `TouchPitchMap`, ported as rules, not as code). This is the grid's layout and what each
/// cell plays, sounds like and looks like; the view that draws it and takes the touches is the app's.
///
/// Columns run across one octave of the song's scale, the root at the left; rows are octaves, the
/// lowest at the bottom. So a column is one pitch class on every row and wears one light on every
/// row (`ToneLight`): an octave reads as a column of one colour.
///
/// A column is a pitch that SOUNDS, not a key. The built-in synth and sampler play the song's tone
/// system, which retunes the twelve keys by pitch class, and two keys of the scale can land on one
/// degree of it: under Maqām Bayātī C♯ and D both sound the quarter tone between them. The grid then
/// has one column for the two, so a chromatic song in Bayātī plays its seven degrees from seven
/// columns rather than twelve, five of which would repeat a neighbour. A hosted Audio Unit is never
/// retuned: it is sent plain MIDI notes and told neither the tone system nor the concert pitch. So
/// on a plugin track the columns are the scale's keys at twelve equal steps from A = 440 Hz,
/// whatever concert pitch the song names, and their light and hertz say so (`retunes`).
///
/// A device setting, like the keys strip: never a `Command`, never stored in the song. What a cell
/// plays goes the one live path every key on the screen goes. Pure; Foundation only.
public struct FieldGrid: Equatable, Sendable {
    /// One column: a key of the scale and the pitch it sounds.
    public struct Column: Equatable, Sendable {
        /// The key the column plays, in semitones above the root: one of the scale's `intervals`.
        /// Where two keys sound the column's pitch, the one written nearer it, the lower on a tie,
        /// because the key is what MIDI out sends and what a take records.
        public let interval: Int
        /// Where that key sounds, in cents above the root as the instrument plays it: 0 for the root,
        /// 150 for Bayātī's quarter tone, 100 × `interval` on an instrument that is not retuned.
        public let cents: Double
    }

    /// One cell: its column, its row from the bottom, and the note it plays.
    public struct Cell: Equatable, Hashable, Sendable, Identifiable {
        public let column: Int
        public let row: Int
        /// The cell's MIDI note by the grid's arithmetic: the root's octave plus the column's key. At
        /// the highest octave the top row can run past 127; such a cell is there and plays nothing
        /// (`isEnabled`), its note never folded into another octave.
        public let pitch: Int
        public var id: Int { row * 1_000 + column }
        /// Whether the cell plays: its note is a MIDI note, 0 … 127.
        public var isEnabled: Bool { (0...127).contains(pitch) }
    }

    /// The rows, bottom to top: three octaves, as on the earlier app's surface. Room for a line and
    /// its bass without moving, and few enough rows that each stays tall enough to slide along.
    public static let rowCount = 3
    /// The octave a new grid's bottom row starts in: the root in octave 3, C3 (MIDI 48) for C, where
    /// the keys strip starts too.
    public static let defaultLowestOctave = 3
    /// How far Octave − and + move the bottom row: from octave 0 (C0 is MIDI 12) to octave 6, where
    /// the top row reaches MIDI's last notes and, under a high root, runs past them (`Cell.isEnabled`).
    public static let octaveRange: ClosedRange<Int> = 0...6
    /// Two keys whose pitches lie closer than this, in cents, sound as one pitch and share a column;
    /// two keys whose distances from that pitch differ by less than this are equally near it, a tie.
    /// A cent is far finer than any step a tone system of the library takes (31 equal, the finest,
    /// steps 38.7 cents), so this only absorbs rounding.
    public static let samePitchCents = 1.0

    /// The key's root as a pitch class, 0 = C … 11 = B.
    public let root: Int
    /// The octave the bottom row starts in, inside `octaveRange`.
    public let lowestOctave: Int
    /// The pitches the scale sounds in one octave, rising from the root. Never empty.
    public let columns: [Column]
    /// Whether the live instrument plays the song's tone system and concert pitch (`retunes`).
    public let isRetuned: Bool
    /// How far each pitch class (0 = C … 11 = B) sounds from twelve equal steps at A = 440 Hz on the
    /// live instrument, in cents: the song's tone system and concert pitch where it is retuned
    /// (`MusicalContext.centsTable`, held as the voices hold it); zero where it is not, at any
    /// concert pitch, since such an instrument is told neither.
    public let pitchClassCents: [Double]

    /// The grid for a song — `context` gives its key, scale, tone system and concert pitch — played on
    /// `device`, the live track's instrument, with the bottom row in `lowestOctave` (held inside
    /// `octaveRange`). A root outside 0 … 11 reads as its pitch class.
    public init(context: MusicalContext, device: InstrumentDevice, lowestOctave: Int = FieldGrid.defaultLowestOctave) {
        let tonic = Self.pitchClass(context.root)
        let retuned = Self.retunes(device)
        let table = retuned ? Self.installed(context.centsTable()) : [Double](repeating: 0, count: 12)
        self.init(root: tonic, lowestOctave: lowestOctave,
                  columns: Self.soundingColumns(of: context.scale, root: tonic, cents: table),
                  isRetuned: retuned, pitchClassCents: table)
    }

    private init(root: Int, lowestOctave: Int, columns: [Column], isRetuned: Bool, pitchClassCents: [Double]) {
        self.root = root
        self.lowestOctave = Swift.min(Swift.max(lowestOctave, Self.octaveRange.lowerBound), Self.octaveRange.upperBound)
        self.columns = columns
        self.isRetuned = isRetuned
        self.pitchClassCents = pitchClassCents
    }

    /// Whether `device` plays the song's tone system and concert pitch. The built-in synth and sampler
    /// do: the engine retunes them with every snapshot. A hosted Audio Unit does not: it is sent plain
    /// MIDI notes and no tuning, so it plays twelve equal steps at its own reference — A = 440 Hz, the
    /// MIDI standard, unless the unit is set otherwise — and the grid shows that rather than a tuning
    /// the unit does not play. The drum kit's notes name drums, not pitches, and an instrument of a
    /// later build plays nothing here.
    public static func retunes(_ device: InstrumentDevice) -> Bool {
        switch device {
        case .synth, .sampler: true
        case .drums, .plugin, .unrecognized: false
        }
    }

    // MARK: - Cells

    /// The note of the bottom-left cell: the root in `lowestOctave`, C3 (MIDI 48) for C in octave 3.
    public var lowestPitch: Int { (lowestOctave + 1) * 12 + root }

    /// The cell at `column` in `row` (0 is the bottom row); nil outside the grid.
    public func cell(column: Int, row: Int) -> Cell? {
        guard columns.indices.contains(column), (0..<Self.rowCount).contains(row) else { return nil }
        return Cell(column: column, row: row, pitch: note(column: column, row: row))
    }

    /// Every cell, the bottom row first and each row left to right, disabled ones included: the view
    /// draws them all.
    public var cells: [Cell] {
        var out: [Cell] = []
        out.reserveCapacity(columns.count * Self.rowCount)
        for row in 0..<Self.rowCount {
            for column in columns.indices {
                out.append(Cell(column: column, row: row, pitch: note(column: column, row: row)))
            }
        }
        return out
    }

    /// The cell under a place on the grid: `x` 0 … 1 from its left edge to its right, `y` 0 … 1 from
    /// its bottom edge to its top (`Geometry.place` turns a touch into one). A place outside the grid
    /// counts as the nearest edge cell; a coordinate that is not a finite number counts as the middle
    /// of its axis, so a touch the screen could not place plays the middle cell, never an edge.
    public func cell(atX x: Double, y: Double) -> Cell {
        let column = Self.part(x, of: columns.count)
        let row = Self.part(y, of: Self.rowCount)
        return Cell(column: column, row: row, pitch: note(column: column, row: row))
    }

    /// The note a touch at that place plays; nil on a disabled cell.
    public func pitch(atX x: Double, y: Double) -> Int? {
        let touched = cell(atX: x, y: y)
        return touched.isEnabled ? touched.pitch : nil
    }

    // MARK: - What a cell sounds and looks like

    /// What `pitch` sounds on the live instrument, in hertz: 440 · 2^((pitch − 69) / 12 + c / 1200),
    /// `c` its pitch class's entry of `pitchClassCents` — the voices' own formula
    /// (`Temperament.frequency` in EchoelDSP), the concert pitch already in the table. On an
    /// instrument that is not retuned the table is zero, and this is
    /// `ToneLight.hertz(ofPitch:concertPitch:)` at 440.
    public func hertz(ofPitch pitch: Int) -> Double {
        let offset = pitchClassCents[Self.pitchClass(pitch)]
        return Self.referenceHertz * Foundation.pow(2, (Double(pitch) - 69) / 12 + offset / 1_200)
    }

    /// What `cell` sounds, in hertz.
    public func hertz(of cell: Cell) -> Double { hertz(ofPitch: cell.pitch) }

    /// A cell's light: the colour of what it sounds (`ToneLight.colour(forToneHz:)`). A column is one
    /// pitch class, so every cell of it, a disabled one too, wears one light.
    public func colour(of cell: Cell) -> ToneLight.RGB {
        ToneLight.colour(forToneHz: hertz(of: cell))
    }

    // MARK: - Octave − and +

    /// The same grid `steps` octaves higher (lower for a negative number), held inside `octaveRange`.
    public func shifted(byOctaves steps: Int) -> FieldGrid {
        let move = Swift.min(Swift.max(steps, -Self.octaveRange.count), Self.octaveRange.count)
        return FieldGrid(root: root, lowestOctave: lowestOctave + move, columns: columns, isRetuned: isRetuned,
                         pitchClassCents: pitchClassCents)
    }

    /// Whether Octave − can still move the grid down.
    public var canShiftDown: Bool { lowestOctave > Self.octaveRange.lowerBound }

    /// Whether Octave + can still move the grid up.
    public var canShiftUp: Bool { lowestOctave < Self.octaveRange.upperBound }

    // MARK: - Loudness from the contact

    /// A contact this narrow or narrower, in points, counts as the lightest touch …
    public static let lightestContactRadius = 6.0
    /// … and one this wide or wider as the firmest. Both radii are the earlier app's estimate (its
    /// touch instrument's note: a fingertip about 8, a flat finger 25 and more), carried over;
    /// neither app records measuring them on a device. What radius an ordinary tap reports, and in
    /// what steps, decides how much of the loudness range a finger can reach: a device question.
    public static let firmestContactRadius = 28.0

    /// How hard a touch on a cell plays. On the grid a finger's place is its pitch, so the place
    /// cannot carry the loudness as it does on a key (`TouchVelocity`); the contact does — how firmly
    /// the finger presses where the screen senses pressure (`force` of the most it can report,
    /// `maximumForce`, which is 0 where it senses none) and how much of the finger lies on the glass
    /// (`majorRadius`, points). Whichever says more wins, as on the earlier app's surface. The range
    /// is the keys' (`TouchVelocity.softest` … `hardest`, 60 … 127), so a cell and a key share their
    /// softest and their loudest. With Touch Loudness off (`placesLoudness` false), and for a touch
    /// whose contact says nothing (no pressure sensed, a radius that is no number), a cell plays
    /// `TouchVelocity.unplaced`, as a key does then.
    public static func velocity(force: Double, maximumForce: Double, majorRadius: Double,
                                placesLoudness: Bool) -> UInt8 {
        guard placesLoudness else { return TouchVelocity.unplaced }
        let pressure: Double? = maximumForce.isFinite && maximumForce > 0 && !force.isNaN
            ? Swift.min(1, Swift.max(0, force / maximumForce)) : nil
        let span = firmestContactRadius - lightestContactRadius
        let spread: Double? = majorRadius.isNaN
            ? nil : Swift.min(1, Swift.max(0, (majorRadius - lightestContactRadius) / span))
        let intent: Double
        switch (pressure, spread) {
        case let (pressed?, area?): intent = Swift.max(pressed, area)
        case let (pressed?, nil): intent = pressed
        case let (nil, area?): intent = area
        case (nil, nil): return TouchVelocity.unplaced
        }
        let softest = Double(TouchVelocity.softest), hardest = Double(TouchVelocity.hardest)
        let value = (softest + (hardest - softest) * intent).rounded()
        return UInt8(Swift.min(hardest, Swift.max(softest, value)))
    }

    // MARK: - One rect

    /// A rectangle in a view's points from its top-left corner, y down: where a touch lands and a
    /// layer is drawn on the screen.
    public struct Rect: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public var midX: Double { x + width / 2 }
        public var midY: Double { y + height / 2 }
        public var maxX: Double { x + width }
        public var maxY: Double { y + height }
    }

    /// Where the grid lies over the picture. The Field fills the whole view (`viewWidth` ×
    /// `viewHeight` points) and the cells only `play`, the view inset by the safe area; the touches on
    /// the cells, the cells the view draws and the light the Field puts under them are all placed
    /// through this one rect, so a drop lands on the cell it came from. The earlier app drew its cells
    /// in the inset rect and its picture over the whole bounds, and in fullscreen its light sat off by
    /// the inset ("not pixel-exact in fullscreen", `TouchInstrumentView.swift`).
    ///
    /// A view whose width or height is not a positive, finite number counts as having no size; a
    /// `play` that is not such a rect counts as the whole view.
    public struct Geometry: Equatable, Sendable {
        public let viewWidth: Double
        public let viewHeight: Double
        public let play: Rect

        public init(viewWidth: Double, viewHeight: Double, play: Rect) {
            let width = viewWidth.isFinite && viewWidth > 0 ? viewWidth : 0
            let height = viewHeight.isFinite && viewHeight > 0 ? viewHeight : 0
            let isRect = play.x.isFinite && play.y.isFinite && play.width.isFinite && play.height.isFinite
                && play.width > 0 && play.height > 0
            self.viewWidth = width
            self.viewHeight = height
            self.play = isRect ? play : Rect(x: 0, y: 0, width: width, height: height)
        }

        /// The cells over the whole view.
        public init(viewWidth: Double, viewHeight: Double) {
            self.init(viewWidth: viewWidth, viewHeight: viewHeight,
                      play: Rect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        }

        /// A touch at (`x`, `y`) view points as a place on the grid: 0 … 1 across `play` from its left
        /// edge, 0 … 1 up it from its bottom edge, and beyond that outside it (`cell(atX:y:)` holds such
        /// a place to the edge cells). A `play` with no size places every touch in its middle.
        public func place(x: Double, y: Double) -> (x: Double, y: Double) {
            guard play.width > 0, play.height > 0 else { return (0.5, 0.5) }
            return ((x - play.x) / play.width, (play.maxY - y) / play.height)
        }

        /// The rect `cell` of `grid` is drawn in, view points: `play` cut into the grid's columns and
        /// rows, the bottom row at its bottom.
        public func frame(of cell: Cell, in grid: FieldGrid) -> Rect {
            let width = play.width / Double(Swift.max(1, grid.columns.count))
            let height = play.height / Double(FieldGrid.rowCount)
            return Rect(x: play.x + width * Double(cell.column),
                        y: play.y + height * Double(FieldGrid.rowCount - 1 - cell.row),
                        width: width, height: height)
        }

        /// The centre of `cell` in the Field's picture as its shader reads a place (`uv`, set in
        /// `FieldShader`'s `field_vertex`): 0 … 1 across the whole view, x to the right and y UP, the
        /// bottom-left corner at (0, 0). Held to the picture, so a cell partly off the view lights the
        /// picture's edge. A view with no size gives the cell's own place on the grid.
        public func uv(of cell: Cell, in grid: FieldGrid) -> (x: Double, y: Double) {
            guard viewWidth > 0, viewHeight > 0 else {
                let across = (Double(cell.column) + 0.5) / Double(Swift.max(1, grid.columns.count))
                let up = (Double(cell.row) + 0.5) / Double(FieldGrid.rowCount)
                return (FieldGrid.unit(across), FieldGrid.unit(up))
            }
            let drawn = frame(of: cell, in: grid)
            return (FieldGrid.unit(drawn.midX / viewWidth), FieldGrid.unit(1 - drawn.midY / viewHeight))
        }
    }

    // MARK: - The rules underneath

    /// The scale's keys in one octave as columns, rising from the root. A key sounds at its
    /// twelve-equal place plus its pitch class's entry of `cents`, measured from the root's; where two
    /// keys sound one pitch (within `samePitchCents`) they share one column, and it plays the key
    /// written nearer that pitch, the lower one on a tie. A table of zeros gives every key its own column.
    ///
    /// The nearer key rather than simply the lower, because the column's key is what MIDI out sends and
    /// what a take records: under just intonation E♭ (+86 cents) and E (−14) both sound the major
    /// third, and a synth on MIDI out, or the take played back in another tone system, hears E as that
    /// third and E♭ as a minor one.
    private static func soundingColumns(of scale: Scale, root: Int, cents: [Double]) -> [Column] {
        var kept: [Column] = []
        for interval in scale.intervals.sorted() {
            let written = Double(interval * 100)
            var sounding = written + cents[pitchClass(root + interval)] - cents[root]
            // A key the tone system plays at the octave above the root (the key under the root takes
            // the tonic above, `MusicalContext`) is the root's column one row up, not a column of its
            // own; one played below the root, the top of the octave below.
            if sounding >= 1_200 - Self.samePitchCents { sounding -= 1_200 }
            if sounding < -Self.samePitchCents { sounding += 1_200 }
            guard let index = kept.firstIndex(where: { Swift.abs($0.cents - sounding) < Self.samePitchCents }) else {
                kept.append(Column(interval: interval, cents: sounding))
                continue
            }
            let held = kept[index]
            let heldAway = Swift.abs(held.cents - Double(held.interval * 100))
            if Swift.abs(sounding - written) < heldAway - Self.samePitchCents {
                kept[index] = Column(interval: interval, cents: sounding)
            }
        }
        // Every scale has its root; a grid without a column could not place a touch.
        if kept.isEmpty { kept = [Column(interval: 0, cents: 0)] }
        return kept.sorted { $0.cents < $1.cents }
    }

    /// A cents table as the voices install it (`Temperament` in EchoelDSP): twelve entries, one that is
    /// not a number counted as zero and one beyond an octave either way held to the octave, so the grid
    /// never shows a tuning the voices would not play.
    private static func installed(_ table: [Double]) -> [Double] {
        (0..<12).map { (index: Int) -> Double in
            guard index < table.count, table[index].isFinite else { return 0 }
            return Swift.min(Swift.max(table[index], -centsLimit), centsLimit)
        }
    }

    /// The farthest the voices let a pitch class sit from its equal-tempered place, either way
    /// (`Temperament.limit` in EchoelDSP).
    private static let centsLimit = 1_200.0
    /// A4 of twelve equal steps: every cents table is measured from it.
    private static let referenceHertz = 440.0

    /// The cell's note: the root's octave, the column's key and the row's octaves.
    private func note(column: Int, row: Int) -> Int {
        lowestPitch + columns[column].interval + 12 * row
    }

    /// Which of `count` equal parts of 0 … 1 `place` falls in: outside, the nearer end; not a finite
    /// number, the middle.
    private static func part(_ place: Double, of count: Int) -> Int {
        guard count > 1 else { return 0 }
        let along = place.isFinite ? Swift.min(1, Swift.max(0, place)) : 0.5
        return Swift.min(count - 1, Int((along * Double(count)).rounded(.down)))
    }

    private static func pitchClass(_ pitch: Int) -> Int { ((pitch % 12) + 12) % 12 }

    /// `value` held to 0 … 1; not a number reads as the middle.
    private static func unit(_ value: Double) -> Double {
        value.isNaN ? 0.5 : Swift.min(1, Swift.max(0, value))
    }
}
