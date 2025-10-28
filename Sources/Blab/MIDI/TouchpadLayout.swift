import Foundation
import CoreGraphics

/// Touchpad layout systems for MPE controller
/// Supports multiple industry-standard layouts inspired by:
/// - Roli Seaboard (continuous surface)
/// - Roger Linn LinnStrument (isomorphic grid)
/// - Terpstra keyboard (hexagonal layout)
/// - GeoShred (free-form)
/// - Traditional piano layout
protocol TouchpadLayout {

    /// Layout name
    var name: String { get }

    /// Get MIDI note number for a touch position
    /// - Parameters:
    ///   - position: Touch position (normalized 0.0-1.0)
    ///   - bounds: Touchpad bounds
    ///   - rootNote: Root MIDI note (typically C3 = 48 or C4 = 60)
    ///   - scale: Optional scale constraint
    /// - Returns: MIDI note number
    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int

    /// Get visual position for a MIDI note (for drawing note guides)
    /// - Parameters:
    ///   - midiNote: MIDI note number
    ///   - bounds: Touchpad bounds
    ///   - rootNote: Root MIDI note
    /// - Returns: Position in touchpad bounds
    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint?

    /// Get all visible notes in the current view
    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int]
}


// MARK: - Continuous Layout (Roli Seaboard style)

/// Continuous surface - no discrete keys, smooth pitch control
struct ContinuousLayout: TouchpadLayout {

    let name = "Continuous Surface"

    /// Octave range displayed (e.g., 2 octaves = 24 semitones)
    var octaveRange: Float = 2.0

    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int {
        // Horizontal = pitch (continuous)
        // Vertical = timbre (doesn't affect note selection)

        let normalizedX = position.x / bounds.width
        let semitoneOffset = normalizedX * CGFloat(octaveRange * 12.0)

        return rootNote + Int(semitoneOffset)
    }

    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint? {
        let semitoneOffset = midiNote - rootNote
        let normalizedX = CGFloat(semitoneOffset) / CGFloat(octaveRange * 12.0)

        if normalizedX < 0 || normalizedX > 1.0 {
            return nil
        }

        return CGPoint(
            x: normalizedX * bounds.width,
            y: bounds.height / 2.0
        )
    }

    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int] {
        let totalSemitones = Int(octaveRange * 12.0)
        return (rootNote...(rootNote + totalSemitones)).map { $0 }
    }
}


// MARK: - Linear Piano Layout

/// Piano-style linear keyboard layout
struct LinearPianoLayout: TouchpadLayout {

    let name = "Linear Piano"

    /// Number of octaves to display
    var octaves: Int = 2

    /// Show black keys offset (traditional piano appearance)
    var offsetBlackKeys: Bool = true

    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int {
        let totalKeys = octaves * 12
        let keyWidth = bounds.width / CGFloat(totalKeys)
        let keyIndex = Int(position.x / keyWidth)

        return rootNote + keyIndex
    }

    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint? {
        let keyOffset = midiNote - rootNote
        let totalKeys = octaves * 12

        if keyOffset < 0 || keyOffset >= totalKeys {
            return nil
        }

        let keyWidth = bounds.width / CGFloat(totalKeys)
        let x = (CGFloat(keyOffset) + 0.5) * keyWidth

        // Black keys slightly higher than white keys
        let isBlackKey = [1, 3, 6, 8, 10].contains(keyOffset % 12)
        let y = isBlackKey ? bounds.height * 0.4 : bounds.height * 0.6

        return CGPoint(x: x, y: y)
    }

    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int] {
        let totalKeys = octaves * 12
        return (rootNote...<(rootNote + totalKeys)).map { $0 }
    }

    /// Check if MIDI note is a "black key" (sharps/flats)
    func isBlackKey(_ midiNote: Int) -> Bool {
        let pitchClass = midiNote % 12
        return [1, 3, 6, 8, 10].contains(pitchClass)
    }
}


// MARK: - Isomorphic Grid (Linnstrument style)

/// Isomorphic grid layout - consistent intervals in all directions
/// Inspired by Roger Linn LinnStrument and Lumatone
struct IsomorphicGridLayout: TouchpadLayout {

    let name = "Isomorphic Grid"

    /// Number of rows
    var rows: Int = 8

    /// Number of columns
    var columns: Int = 16

    /// Interval pattern
    var pattern: IsomorphicPattern = .fourthsAndSemitones

    enum IsomorphicPattern {
        case fourthsAndSemitones  // Rows = +5 semitones, Columns = +1 semitone
        case fifthsAndSemitones   // Rows = +7 semitones, Columns = +1 semitone
        case wholeTones           // Rows = +2 semitones, Columns = +2 semitones
        case harmonicTable        // Rows = +7, Columns = +4 (fifths and thirds)

        var rowInterval: Int {
            switch self {
            case .fourthsAndSemitones: return 5   // Perfect fourth
            case .fifthsAndSemitones: return 7    // Perfect fifth
            case .wholeTones: return 2            // Whole tone
            case .harmonicTable: return 7         // Perfect fifth
            }
        }

        var columnInterval: Int {
            switch self {
            case .fourthsAndSemitones: return 1   // Semitone
            case .fifthsAndSemitones: return 1    // Semitone
            case .wholeTones: return 2            // Whole tone
            case .harmonicTable: return 4         // Major third
            }
        }
    }

    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int {
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        let col = Int(position.x / cellWidth)
        let row = Int(position.y / cellHeight)

        let semitonesFromRoot = row * pattern.rowInterval + col * pattern.columnInterval

        return rootNote + semitonesFromRoot
    }

    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint? {
        let semitonesFromRoot = midiNote - rootNote

        // Find best grid position for this note
        // This is simplified - actual isomorphic layouts can have multiple positions for same note

        let col = semitonesFromRoot % pattern.columnInterval
        let row = semitonesFromRoot / pattern.rowInterval

        if row < 0 || row >= rows || col < 0 || col >= columns {
            return nil
        }

        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        return CGPoint(
            x: (CGFloat(col) + 0.5) * cellWidth,
            y: (CGFloat(row) + 0.5) * cellHeight
        )
    }

    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int] {
        var notes = Set<Int>()

        for row in 0..<rows {
            for col in 0..<columns {
                let semitones = row * pattern.rowInterval + col * pattern.columnInterval
                notes.insert(rootNote + semitones)
            }
        }

        return Array(notes).sorted()
    }
}


// MARK: - Hexagonal Layout (Terpstra style)

/// Hexagonal lattice layout
/// Inspired by Terpstra keyboard - harmonically organized hexagonal grid
struct HexagonalLayout: TouchpadLayout {

    let name = "Hexagonal Grid"

    /// Hex grid dimensions
    var hexRows: Int = 6
    var hexColumns: Int = 10

    /// Hex size (radius)
    var hexSize: CGFloat = 50.0

    /// Interval pattern (what each direction represents)
    var horizontalInterval: Int = 7   // Perfect fifth (default)
    var diagonalInterval: Int = 4     // Major third (default)

    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int {
        // Convert position to hex grid coordinates
        let hex = pixelToHex(position, hexSize: hexSize)

        // Map hex coordinates to MIDI note
        let semitones = hex.q * horizontalInterval + hex.r * diagonalInterval

        return rootNote + semitones
    }

    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint? {
        // This is complex - hexagonal layouts can have multiple representations
        // Simplified implementation
        let semitonesFromRoot = midiNote - rootNote

        // Find hex coordinates (simplified)
        let q = semitonesFromRoot / horizontalInterval
        let r = (semitonesFromRoot % horizontalInterval) / diagonalInterval

        return hexToPixel(HexCoord(q: q, r: r), hexSize: hexSize)
    }

    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int] {
        var notes = Set<Int>()

        // Generate all hex positions in view
        for q in 0..<hexColumns {
            for r in 0..<hexRows {
                let semitones = q * horizontalInterval + r * diagonalInterval
                notes.insert(rootNote + semitones)
            }
        }

        return Array(notes).sorted()
    }

    // MARK: - Hex Grid Math

    struct HexCoord {
        let q: Int  // Column
        let r: Int  // Row
    }

    /// Convert pixel position to hex coordinate
    private func pixelToHex(_ point: CGPoint, hexSize: CGFloat) -> HexCoord {
        let x = point.x
        let y = point.y

        // Flat-top hexagon math
        let q = (x * sqrt(3.0)/3.0 - y / 3.0) / hexSize
        let r = y * 2.0/3.0 / hexSize

        return hexRound(q: q, r: r)
    }

    /// Convert hex coordinate to pixel position
    private func hexToPixel(_ hex: HexCoord, hexSize: CGFloat) -> CGPoint {
        let x = hexSize * (sqrt(3.0) * CGFloat(hex.q) + sqrt(3.0)/2.0 * CGFloat(hex.r))
        let y = hexSize * (3.0/2.0 * CGFloat(hex.r))

        return CGPoint(x: x, y: y)
    }

    /// Round fractional hex coordinates to nearest hex
    private func hexRound(q: CGFloat, r: CGFloat) -> HexCoord {
        let s = -q - r

        var rq = round(q)
        var rr = round(r)
        let rs = round(s)

        let qDiff = abs(rq - q)
        let rDiff = abs(rr - r)
        let sDiff = abs(rs - s)

        if qDiff > rDiff && qDiff > sDiff {
            rq = -rr - rs
        } else if rDiff > sDiff {
            rr = -rq - rs
        }

        return HexCoord(q: Int(rq), r: Int(rr))
    }
}


// MARK: - Scale-Constrained Layout

/// Wrapper that constrains any layout to a specific scale
/// Only allows notes that exist in the selected scale
struct ScaleConstrainedLayout: TouchpadLayout {

    let name: String
    let baseLayout: TouchpadLayout
    let scale: MicrotonalScale

    init(baseLayout: TouchpadLayout, scale: MicrotonalScale) {
        self.name = "\(baseLayout.name) (\(scale.name))"
        self.baseLayout = baseLayout
        self.scale = scale
    }

    func midiNote(
        for position: CGPoint,
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> Int {
        let baseNote = baseLayout.midiNote(
            for: position,
            in: bounds,
            rootNote: rootNote,
            scale: self.scale
        )

        // Snap to nearest note in scale
        return nearestScaleNote(baseNote, rootNote: rootNote)
    }

    func position(
        for midiNote: Int,
        in bounds: CGRect,
        rootNote: Int
    ) -> CGPoint? {
        return baseLayout.position(
            for: midiNote,
            in: bounds,
            rootNote: rootNote
        )
    }

    func visibleNotes(
        in bounds: CGRect,
        rootNote: Int,
        scale: MicrotonalScale?
    ) -> [Int] {
        let baseNotes = baseLayout.visibleNotes(
            in: bounds,
            rootNote: rootNote,
            scale: self.scale
        )

        // Filter to only scale notes
        return baseNotes.filter { note in
            isNoteInScale(note, rootNote: rootNote)
        }
    }

    private func isNoteInScale(_ midiNote: Int, rootNote: Int) -> Bool {
        let offset = (midiNote - rootNote) % scale.notesPerOctave
        return offset >= 0 && offset < scale.notesPerOctave
    }

    private func nearestScaleNote(_ midiNote: Int, rootNote: Int) -> Int {
        let octave = (midiNote - rootNote) / scale.notesPerOctave
        let offset = (midiNote - rootNote) % scale.notesPerOctave

        // Find nearest scale degree
        let nearestDegree = min(max(offset, 0), scale.notesPerOctave - 1)

        return rootNote + octave * scale.notesPerOctave + nearestDegree
    }
}
