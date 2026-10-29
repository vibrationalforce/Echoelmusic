import Foundation

/// A 3×3 preset grid per genre — the Loop-Generator's shortcut when the musician does not want
/// to spell out a prompt (wave W11.1b). The matrix picks `(energy, density)` from a 3×3 cell;
/// brightness, tempo and scale default to the genre's house values, which the musician may still
/// overwrite before generating.
///
/// Pure value, no state. The grid is a cosmetic index into `VibeParameters` — it does not
/// change the song, is never persisted and holds no decision of its own.
public struct VibeMatrix: Equatable, Sendable {

    public enum EnergyBand: Int, CaseIterable, Sendable { case low = 0, mid = 1, high = 2 }
    public enum DensityBand: Int, CaseIterable, Sendable { case sparse = 0, medium = 1, dense = 2 }

    public struct Cell: Equatable, Sendable {
        /// A short label a UI can show inside the 3×3 cell. The label is cosmetic and may change;
        /// it is not stored in a song.
        public var label: String
        public var energy: EnergyBand
        public var density: DensityBand

        public init(label: String, energy: EnergyBand, density: DensityBand) {
            self.label = label
            self.energy = energy
            self.density = density
        }
    }

    public let genre: VibeParameters.Genre
    private let cells: [[Cell]]

    public init(genre: VibeParameters.Genre) {
        self.genre = genre
        self.cells = Self.cells(for: genre)
    }

    /// Look up the cell at (energy, density). The grid is indexed from the top-left in UI terms:
    /// `(low, sparse)` is the quietest, `(high, dense)` the busiest.
    public func cell(energy: EnergyBand, density: DensityBand) -> Cell {
        cells[energy.rawValue][density.rawValue]
    }

    /// All nine cells, left-to-right, top-to-bottom — useful for a `ForEach` in a UI.
    public var allCells: [Cell] { cells.flatMap { $0 } }

    /// Turn a `(energy, density)` cell into a full `VibeParameters` using the genre's defaults
    /// for the three remaining axes. The musician can edit the result before generating; the
    /// matrix only picks a starting point.
    public func parameters(at energy: EnergyBand, density: DensityBand) -> VibeParameters {
        let houseValues = Self.houseValues(for: genre)
        return VibeParameters(
            genre: genre,
            energy: Self.midpoint(of: energy),
            density: Self.midpoint(of: density),
            brightness: houseValues.brightness,
            targetBPM: houseValues.bpm,
            targetKeyRoot: houseValues.root,
            targetScale: houseValues.scale
        )
    }

    // MARK: - Preset grid

    private static func cells(for genre: VibeParameters.Genre) -> [[Cell]] {
        switch genre {
        case .hipHop: return hipHopCells
        case .chill:  return chillCells
        case .score:  return scoreCells
        case .edm:    return edmCells
        }
    }

    private static let hipHopCells: [[Cell]] = [
        [.init(label: "Lo-Fi",      energy: .low,  density: .sparse),
         .init(label: "Soul Beat",  energy: .low,  density: .medium),
         .init(label: "Boom Bap",   energy: .low,  density: .dense)],
        [.init(label: "Trap Slow",  energy: .mid,  density: .sparse),
         .init(label: "Hip Hop",    energy: .mid,  density: .medium),
         .init(label: "Trap Fast",  energy: .mid,  density: .dense)],
        [.init(label: "Phonk",      energy: .high, density: .sparse),
         .init(label: "Drill",      energy: .high, density: .medium),
         .init(label: "Rage",       energy: .high, density: .dense)],
    ]

    private static let chillCells: [[Cell]] = [
        [.init(label: "Ambient",    energy: .low,  density: .sparse),
         .init(label: "Downtempo",  energy: .low,  density: .medium),
         .init(label: "Trip Hop",   energy: .low,  density: .dense)],
        [.init(label: "Chillhop",   energy: .mid,  density: .sparse),
         .init(label: "Lounge",     energy: .mid,  density: .medium),
         .init(label: "Nu Jazz",    energy: .mid,  density: .dense)],
        [.init(label: "Chillwave",  energy: .high, density: .sparse),
         .init(label: "Future Soul", energy: .high, density: .medium),
         .init(label: "Breakbeat",  energy: .high, density: .dense)],
    ]

    private static let scoreCells: [[Cell]] = [
        [.init(label: "Drone",      energy: .low,  density: .sparse),
         .init(label: "Minimal",    energy: .low,  density: .medium),
         .init(label: "Chamber",    energy: .low,  density: .dense)],
        [.init(label: "Suspense",   energy: .mid,  density: .sparse),
         .init(label: "Underscore", energy: .mid,  density: .medium),
         .init(label: "Orchestral", energy: .mid,  density: .dense)],
        [.init(label: "Climax",     energy: .high, density: .sparse),
         .init(label: "Action",     energy: .high, density: .medium),
         .init(label: "Hybrid",     energy: .high, density: .dense)],
    ]

    private static let edmCells: [[Cell]] = [
        [.init(label: "Deep House", energy: .low,  density: .sparse),
         .init(label: "Progressive",energy: .low,  density: .medium),
         .init(label: "Future Bass",energy: .low,  density: .dense)],
        [.init(label: "House",      energy: .mid,  density: .sparse),
         .init(label: "Techno",     energy: .mid,  density: .medium),
         .init(label: "Tech House", energy: .mid,  density: .dense)],
        [.init(label: "Hard Techno",energy: .high, density: .sparse),
         .init(label: "DnB",        energy: .high, density: .medium),
         .init(label: "Hardcore",   energy: .high, density: .dense)],
    ]

    // MARK: - House values per genre

    struct HouseValues {
        var bpm: Double
        var brightness: Double
        var root: Int
        var scale: Scale
    }

    static func houseValues(for genre: VibeParameters.Genre) -> HouseValues {
        switch genre {
        case .hipHop: return HouseValues(bpm: 90,  brightness: 0.45, root: 0, scale: .minor)
        case .chill:  return HouseValues(bpm: 72,  brightness: 0.55, root: 9, scale: .minorPentatonic)
        case .score:  return HouseValues(bpm: 68,  brightness: 0.40, root: 2, scale: .dorian)
        case .edm:    return HouseValues(bpm: 128, brightness: 0.65, root: 0, scale: .minor)
        }
    }

    // MARK: - Band midpoints

    private static func midpoint(of band: EnergyBand) -> Double {
        switch band { case .low: 0.2; case .mid: 0.5; case .high: 0.8 }
    }
    private static func midpoint(of band: DensityBand) -> Double {
        switch band { case .sparse: 0.2; case .medium: 0.5; case .dense: 0.8 }
    }
}
