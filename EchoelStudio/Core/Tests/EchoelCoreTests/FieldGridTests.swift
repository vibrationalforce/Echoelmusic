import EchoelCore
import Foundation
import XCTest

/// The note grid over the Field: its columns are the pitches the song's scale sounds in one octave,
/// its rows are octaves, every column wears one colour on every row, and one rect places the cells,
/// the touches on them and the light under them.
final class FieldGridTests: XCTestCase {
    private func colourDistance(_ a: ToneLight.RGB, _ b: ToneLight.RGB) -> Double {
        Swift.max(Swift.abs(a.red - b.red), Swift.max(Swift.abs(a.green - b.green), Swift.abs(a.blue - b.blue)))
    }

    /// The notes of one row, left to right.
    private func notes(_ grid: FieldGrid, row: Int) -> [Int] {
        grid.columns.indices.compactMap { (column: Int) -> Int? in grid.cell(column: column, row: row)?.pitch }
    }

    private func bayati(root: Int = 0, scale: Scale = .chromatic, concertPitch: Double = 440) -> MusicalContext {
        MusicalContext(root: root, scale: scale, tuning: "maqam-bayati", concertPitch: concertPitch)
    }

    /// What a touch plays with Touch Loudness on.
    private func loudness(force: Double = 0, of maximum: Double = 0, radius: Double) -> UInt8 {
        FieldGrid.velocity(force: force, maximumForce: maximum, majorRadius: radius, placesLoudness: true)
    }

    private func assertRect(_ rect: FieldGrid.Rect, _ x: Double, _ y: Double, _ width: Double, _ height: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rect.x, x, accuracy: 1e-9, "x", file: file, line: line)
        XCTAssertEqual(rect.y, y, accuracy: 1e-9, "y", file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: 1e-9, "width", file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: 1e-9, "height", file: file, line: line)
    }

    // MARK: - Columns and rows

    func testAChromaticSongHasTwelveColumnsFromTheRootAndThreeOctaveRows() {
        let grid = FieldGrid(context: MusicalContext(), device: .synth)
        XCTAssertEqual(FieldGrid.rowCount, 3)
        XCTAssertEqual(grid.columns.map(\.interval), Array(0...11))
        XCTAssertEqual(grid.lowestOctave, 3)
        XCTAssertEqual(grid.lowestPitch, 48, "C3, where the keys strip starts as well")
        XCTAssertEqual(notes(grid, row: 0), Array(48...59))
        XCTAssertEqual(notes(grid, row: 1), Array(60...71))
        XCTAssertEqual(notes(grid, row: 2), Array(72...83))
        XCTAssertEqual(grid.cells.count, 36)
        XCTAssertTrue(grid.cells.allSatisfy(\.isEnabled))
        XCTAssertEqual(grid.cells.first.map { [$0.column, $0.row, $0.pitch] }, [0, 0, 48], "the bottom row comes first")
        XCTAssertEqual(grid.cells.last.map { [$0.column, $0.row, $0.pitch] }, [11, 2, 83])
        XCTAssertEqual(Set(grid.cells.map(\.id)).count, 36)
        XCTAssertNil(grid.cell(column: 12, row: 0))
        XCTAssertNil(grid.cell(column: -1, row: 0))
        XCTAssertNil(grid.cell(column: 0, row: 3))
    }

    func testCMajorPlaysItsSevenKeysAcrossAndEachRowOneOctaveHigher() throws {
        let grid = FieldGrid(context: MusicalContext(scale: .major), device: .synth)
        XCTAssertEqual(grid.columns.map(\.interval), [0, 2, 4, 5, 7, 9, 11])
        XCTAssertEqual(notes(grid, row: 0), [48, 50, 52, 53, 55, 57, 59])
        XCTAssertEqual(notes(grid, row: 1), [60, 62, 64, 65, 67, 69, 71])
        XCTAssertEqual(notes(grid, row: 2), [72, 74, 76, 77, 79, 81, 83])
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 5, row: 0))), 220, accuracy: 1e-9, "A3")
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 5, row: 1))), 440, accuracy: 1e-9, "A4")
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 0, row: 1))), 261.625565301, accuracy: 1e-6, "C4")
    }

    /// The earlier app's lesson: a degree high in the scale crosses into the next octave NUMBER and
    /// stays in its row — D Dorian's C is C4 in the bottom row, not the first note of the next.
    func testDDorianStartsOnItsRootAndAHighDegreeStaysInItsRow() throws {
        let grid = FieldGrid(context: MusicalContext(root: 2, scale: .dorian), device: .synth)
        XCTAssertEqual(grid.columns.map(\.interval), [0, 2, 3, 5, 7, 9, 10])
        XCTAssertEqual(grid.lowestPitch, 50, "D3")
        XCTAssertEqual(notes(grid, row: 0), [50, 52, 53, 55, 57, 59, 60])
        XCTAssertEqual(notes(grid, row: 2), [74, 76, 77, 79, 81, 83, 84])
        let seventh = try XCTUnwrap(grid.cell(column: 6, row: 0))
        XCTAssertEqual(NoteEditing.name(of: seventh.pitch), "C4")
    }

    // MARK: - What sounds

    /// Twelve keys, seven pitches: under Maqām Bayātī C♯ and D both sound the quarter tone
    /// between them, E♭ and E both sound E♭, and so on. The grid shows the seven, one column each.
    func testMaqamBayatiOverAChromaticSongPlaysItsSevenDegreesFromSevenColumns() throws {
        let grid = FieldGrid(context: bayati(), device: .synth)
        XCTAssertTrue(grid.isRetuned)
        let cents = grid.columns.map(\.cents)
        XCTAssertEqual(cents.count, 7)
        for (index, expected) in [0.0, 150, 300, 500, 700, 800, 1_000].enumerated() where index < cents.count {
            XCTAssertEqual(cents[index], expected, accuracy: 1e-9, "column \(index)")
        }
        // C♯ (+50) and D (−50) are written equally near the quarter tone: the lower key plays it.
        XCTAssertEqual(grid.columns.map(\.interval), [0, 1, 3, 5, 7, 8, 10])
        let quarterTone = try XCTUnwrap(grid.cell(column: 1, row: 0))
        XCTAssertEqual(quarterTone.pitch, 49)
        XCTAssertEqual(grid.hertz(of: quarterTone), 142.652351012, accuracy: 1e-6, "C3 and 150 cents")
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 6, row: 1))), 466.163761518, accuracy: 1e-6,
                       "B♭4 is a degree of Bayātī and sounds as written")
        XCTAssertEqual(FieldGrid(context: bayati(), device: .sampler).columns, grid.columns,
                       "the sampler is retuned as the synth is")
    }

    /// A hosted Audio Unit gets plain MIDI notes and no tuning, so it plays twelve equal steps at
    /// A = 440 Hz whatever the song says; the grid must not show a tuning it does not hear.
    func testAPluginTrackPlaysTheScaleAtTwelveEqualStepsBecauseNothingRetunesIt() throws {
        let grid = FieldGrid(context: bayati(concertPitch: 432), device: .plugin)
        XCTAssertFalse(grid.isRetuned)
        XCTAssertEqual(grid.columns.map(\.interval), Array(0...11))
        XCTAssertEqual(grid.columns.map(\.cents), (0...11).map { (step: Int) -> Double in Double(step * 100) })
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 1, row: 0))), 138.591315488, accuracy: 1e-6,
                       "C♯3 at twelve equal steps")
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 9, row: 0))), 220, accuracy: 1e-9,
                       "A3 at 440, not at the song's 432")
        for cell in grid.cells {
            XCTAssertEqual(grid.hertz(of: cell), ToneLight.hertz(ofPitch: cell.pitch, concertPitch: 440), accuracy: 1e-9)
        }
        XCTAssertTrue(FieldGrid.retunes(.synth))
        XCTAssertTrue(FieldGrid.retunes(.sampler))
        XCTAssertFalse(FieldGrid.retunes(.plugin))
        XCTAssertFalse(FieldGrid.retunes(.drums), "a drum note names a drum, not a pitch")
        XCTAssertFalse(FieldGrid.retunes(.unrecognized))
    }

    func testTheSongsConcertPitchIsInWhatARetunedCellSounds() throws {
        let grid = FieldGrid(context: MusicalContext(concertPitch: 432), device: .synth)
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 9, row: 0))), 216, accuracy: 1e-9, "A3")
        XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 9, row: 1))), 432, accuracy: 1e-9, "A4")
        // Columns are measured from the root: the shift moves every key alike and no column.
        for (index, column) in grid.columns.enumerated() {
            XCTAssertEqual(column.cents, Double(index * 100), accuracy: 1e-9)
        }
        XCTAssertEqual(FieldGrid(context: bayati(concertPitch: 415), device: .synth).columns.map(\.interval),
                       FieldGrid(context: bayati(), device: .synth).columns.map(\.interval))
    }

    /// Two keys on one degree leave the column to the key written nearer the pitch it sounds, so
    /// MIDI out and a recorded take carry the nearest written note, not merely the lower one.
    func testTwoKeysOnOneDegreeLeaveTheColumnToTheKeyWrittenNearerIt() throws {
        // Just intonation, major: E♭ (+86 ct) and E (−14 ct) both sound the just major third.
        let just = FieldGrid(context: MusicalContext(tuning: "just-major"), device: .synth)
        XCTAssertEqual(just.columns.map(\.interval), [0, 2, 4, 5, 7, 9, 11], "C D E F G A B")
        let cents = just.columns.map(\.cents)
        let ratios: [Double] = [1, 9.0 / 8, 5.0 / 4, 4.0 / 3, 3.0 / 2, 5.0 / 3, 15.0 / 8]
        for (index, expected) in ratios.map({ (ratio: Double) -> Double in 1_200 * Foundation.log2(ratio) }).enumerated()
            where index < cents.count {
            XCTAssertEqual(cents[index], expected, accuracy: 1e-6, "column \(index)")
        }
        let c3 = just.hertz(of: try XCTUnwrap(just.cell(column: 0, row: 0)))
        let e3 = just.hertz(of: try XCTUnwrap(just.cell(column: 2, row: 0)))
        XCTAssertEqual(e3 / c3, 1.25, accuracy: 1e-6, "a just major third, 5 : 4")
        // Hirajōshi: F♯ and G both sound its fifth, and G plays it.
        XCTAssertEqual(FieldGrid(context: MusicalContext(tuning: "hirajoshi"), device: .synth).columns.map(\.interval),
                       [0, 2, 3, 7, 8])
    }

    /// 24 equal and Bohlen–Pierce move none of the twelve keys (the keys retune by pitch class, and
    /// these systems have nothing for one to move to), so the grid honestly shows twelve equal steps.
    func testAToneSystemThatMovesNoKeySoundsTwelveEqualSteps() {
        for system in ["edo24", "bohlen-pierce"] {
            let grid = FieldGrid(context: MusicalContext(tuning: system), device: .synth)
            XCTAssertEqual(grid.columns.map(\.interval), Array(0...11), system)
            for (index, column) in grid.columns.enumerated() {
                XCTAssertEqual(column.cents, Double(index * 100), accuracy: 1e-9, system)
            }
        }
    }

    /// Over every tone system, scale, a spread of roots and concert pitches: the columns rise from
    /// the root, each is its own pitch, each sounds where it says, and every key of the scale sounds
    /// the pitch of one of them — nothing the scale can play is missing from the grid.
    func testEveryColumnIsItsOwnPitchAndEveryKeyOfTheScaleSoundsOne() {
        for system in TuningSystem.library {
            for scale in Scale.allCases {
                for root in [0, 2, 7, 11] {
                    for concertPitch in [415.0, 440, 466] {
                        let context = MusicalContext(root: root, scale: scale, tuning: system.id, concertPitch: concertPitch)
                        let label = "\(system.id) \(scale) root \(root) A = \(concertPitch)"
                        let grid = FieldGrid(context: context, device: .synth)
                        let rootHertz = grid.hertz(ofPitch: grid.lowestPitch)
                        XCTAssertEqual(grid.columns.first?.interval, 0, label)
                        XCTAssertLessThanOrEqual(grid.columns.count, scale.intervals.count, label)
                        for (lower, upper) in zip(grid.columns, grid.columns.dropFirst()) {
                            XCTAssertGreaterThan(upper.cents - lower.cents, FieldGrid.samePitchCents, label)
                        }
                        for column in grid.columns {
                            let heard = 1_200 * Foundation.log2(grid.hertz(ofPitch: grid.lowestPitch + column.interval) / rootHertz)
                            XCTAssertEqual(column.cents, heard, accuracy: 1e-6, "\(label) column \(column.interval)")
                            XCTAssertTrue((0..<1_200).contains(column.cents), label)
                        }
                        for interval in scale.intervals {
                            let heard = 1_200 * Foundation.log2(grid.hertz(ofPitch: grid.lowestPitch + interval) / rootHertz)
                            // A key heard at the octave above the root is the root's column one row up.
                            let found = grid.columns.contains { (column: FieldGrid.Column) -> Bool in
                                Swift.abs(column.cents - heard) < FieldGrid.samePitchCents
                                    || Swift.abs(column.cents + 1_200 - heard) < FieldGrid.samePitchCents
                            }
                            XCTAssertTrue(found, "\(label): interval \(interval) sounds no column's pitch")
                        }
                        let plain = FieldGrid(context: context, device: .plugin)
                        XCTAssertEqual(plain.columns.map(\.interval), scale.intervals.sorted(), label)
                    }
                }
            }
        }
    }

    /// The rule rests on this: a cent is far finer than any step a tone system of the library takes,
    /// so only rounding, never a real degree, falls inside it.
    func testTheSamePitchToleranceIsFarFinerThanAnyToneSystemsStep() {
        XCTAssertEqual(FieldGrid.samePitchCents, 1)
        for system in TuningSystem.library where Swift.abs(system.periodCents - 1_200) < 1 {
            let steps = zip(system.degreesCents, system.degreesCents.dropFirst()).map { (pair: (Double, Double)) -> Double in
                pair.1 - pair.0
            }
            XCTAssertGreaterThan(steps.min() ?? .infinity, 30 * FieldGrid.samePitchCents, system.id)
        }
    }

    // MARK: - Colour

    /// The octave analogy: a column is one pitch class, so every cell of it wears one light, on
    /// every row and at every octave — for any key, scale, tone system and either kind of instrument.
    func testEveryColumnWearsOneColourOnEveryRow() {
        let contexts = [MusicalContext(), MusicalContext(root: 2, scale: .dorian), bayati(),
                        MusicalContext(root: 9, scale: .minor, tuning: "just-minor", concertPitch: 432.1),
                        MusicalContext(root: 11, tuning: "edo31", concertPitch: 415)]
        for context in contexts {
            for device in [InstrumentDevice.synth, .plugin] {
                for octave in FieldGrid.octaveRange {
                    let grid = FieldGrid(context: context, device: device, lowestOctave: octave)
                    for cell in grid.cells {
                        guard let bottom = grid.cell(column: cell.column, row: 0) else {
                            XCTFail("no bottom cell for column \(cell.column)")
                            continue
                        }
                        XCTAssertLessThan(colourDistance(grid.colour(of: cell), grid.colour(of: bottom)), 1e-9,
                                          "\(context.tuning) \(device) octave \(octave) cell \(cell.id)")
                    }
                }
            }
        }
    }

    func testACellWearsTheLightOfWhatItSounds() throws {
        let grid = FieldGrid(context: bayati(), device: .synth)
        for cell in grid.cells {
            XCTAssertEqual(grid.colour(of: cell), ToneLight.colour(forToneHz: grid.hertz(of: cell)))
        }
        // The quarter tone wears its own light, not C♯'s.
        let quarterTone = grid.colour(of: try XCTUnwrap(grid.cell(column: 1, row: 0)))
        XCTAssertLessThan(colourDistance(quarterTone, ToneLight.colour(forToneHz: 142.652351012)), 1e-9)
        XCTAssertGreaterThan(colourDistance(quarterTone, ToneLight.colour(forToneHz: 138.591315488)), 0.01)
        // Seven degrees, seven lights.
        let lights = grid.columns.indices.compactMap { (column: Int) -> ToneLight.RGB? in
            grid.cell(column: column, row: 0).map { grid.colour(of: $0) }
        }
        XCTAssertEqual(lights.count, 7)
        for (left, right) in zip(lights, lights.dropFirst()) {
            XCTAssertGreaterThan(colourDistance(left, right), 0.01)
        }
    }

    // MARK: - Octave − and +

    func testOctaveMinusAndPlusMoveTheGridWithinZeroToSix() {
        XCTAssertEqual(FieldGrid.defaultLowestOctave, 3)
        XCTAssertEqual(FieldGrid.octaveRange, 0...6)
        let grid = FieldGrid(context: MusicalContext(), device: .synth)
        XCTAssertEqual(grid.lowestOctave, FieldGrid.defaultLowestOctave)
        let up = grid.shifted(byOctaves: 1)
        XCTAssertEqual(up.lowestOctave, 4)
        XCTAssertEqual(up.lowestPitch, 60)
        XCTAssertEqual(up.columns, grid.columns)
        XCTAssertEqual(grid.shifted(byOctaves: -1).lowestPitch, 36)

        let lowest = FieldGrid(context: MusicalContext(), device: .synth, lowestOctave: -4)
        XCTAssertEqual(lowest.lowestOctave, 0)
        XCTAssertEqual(lowest.lowestPitch, 12, "C0: the grid never reaches below MIDI 12")
        XCTAssertFalse(lowest.canShiftDown)
        XCTAssertTrue(lowest.canShiftUp)
        XCTAssertEqual(lowest.shifted(byOctaves: -1).lowestOctave, 0)

        let highest = FieldGrid(context: MusicalContext(), device: .synth, lowestOctave: 11)
        XCTAssertEqual(highest.lowestOctave, 6)
        XCTAssertTrue(highest.canShiftDown)
        XCTAssertFalse(highest.canShiftUp)
        XCTAssertEqual(highest.shifted(byOctaves: 1).lowestOctave, 6)

        XCTAssertEqual(grid.shifted(byOctaves: Int.max).lowestOctave, 6)
        XCTAssertEqual(grid.shifted(byOctaves: Int.min).lowestOctave, 0)
        XCTAssertEqual(FieldGrid(context: MusicalContext(), device: .synth, lowestOctave: Int.min).lowestOctave, 0)
    }

    /// At the highest octave a high root takes the top row past MIDI's last note: those cells are
    /// there and play nothing. A note is never folded into another octave to fill them.
    func testAtTheHighestOctaveACellAboveMIDI127IsDisabledNeverWrapped() {
        let grid = FieldGrid(context: MusicalContext(root: 11), device: .synth, lowestOctave: 6)
        XCTAssertEqual(grid.lowestPitch, 95, "B6")
        let top = grid.columns.indices.compactMap { (column: Int) -> FieldGrid.Cell? in grid.cell(column: column, row: 2) }
        XCTAssertEqual(top.map(\.pitch), Array(119...130))
        XCTAssertEqual(top.filter { !$0.isEnabled }.map(\.pitch), [128, 129, 130])
        XCTAssertEqual(grid.cells.filter(\.isEnabled).count, 33)
        let corner = grid.cell(atX: 0.99, y: 0.99)
        XCTAssertEqual(corner.pitch, 130, "B6 + 11 + 24: the top row's last cell")
        XCTAssertEqual(NoteEditing.name(of: corner.pitch), "A♯9")
        XCTAssertNil(grid.pitch(atX: 0.99, y: 0.99), "the A♯9 cell (MIDI 130) plays nothing")
        XCTAssertEqual(grid.pitch(atX: 8.5 / 12, y: 0.99), 127, "G9, MIDI's highest note, still plays")
        XCTAssertEqual(grid.pitch(atX: 0.99, y: 0.5), 118, "the row below plays")
        for root in 0...11 {
            let low = FieldGrid(context: MusicalContext(root: root), device: .synth, lowestOctave: 0)
            XCTAssertTrue(low.cells.allSatisfy(\.isEnabled), "root \(root) at octave 0")
            let high = FieldGrid(context: MusicalContext(root: root), device: .synth, lowestOctave: 6)
            XCTAssertTrue(high.cells.filter { $0.row < 2 }.allSatisfy(\.isEnabled), "root \(root): only the top row can end")
        }
    }

    // MARK: - Touching a place

    func testAPlaceOnTheGridPicksItsCellAndAPlaceOutsideItTheNearestEdgeCell() {
        let grid = FieldGrid(context: MusicalContext(scale: .major), device: .synth)
        XCTAssertEqual(grid.pitch(atX: 0, y: 0), 48)
        XCTAssertEqual(grid.pitch(atX: 0.999, y: 0.01), 59)
        XCTAssertEqual(grid.pitch(atX: 0.5, y: 0.5), 65, "the middle cell: F4")
        XCTAssertEqual(grid.pitch(atX: 0.2, y: 0.9), 74, "the second column of the top row: D5")
        let cell = grid.cell(atX: 0.2, y: 0.9)
        XCTAssertEqual([cell.column, cell.row], [1, 2])
        XCTAssertEqual(grid.pitch(atX: 1, y: 1), 83, "the far edges belong to the last cells")
        XCTAssertEqual(grid.pitch(atX: -0.4, y: 0.5), 60)
        XCTAssertEqual(grid.pitch(atX: 1.8, y: 2), 83)
        XCTAssertEqual(grid.pitch(atX: 0.5, y: -3), 53)
        XCTAssertEqual(grid.pitch(atX: 1e300, y: -1e300), 59, "far outside is still the edge")
    }

    func testAPlaceThatIsNoFiniteNumberCountsAsTheMiddleOfItsAxis() {
        let grid = FieldGrid(context: MusicalContext(scale: .major), device: .synth)
        XCTAssertEqual(grid.pitch(atX: .nan, y: .nan), 65, "the middle cell")
        XCTAssertEqual(grid.pitch(atX: .infinity, y: -.infinity), 65)
        XCTAssertEqual(grid.pitch(atX: .nan, y: 0.1), 53, "the middle column, the bottom row")
        XCTAssertEqual(grid.pitch(atX: 0.1, y: .infinity), 60, "the first column, the middle row")
    }

    // MARK: - Loudness from the contact

    func testTheContactSetsTheLoudnessFromSixtyToOneHundredTwentySeven() {
        XCTAssertEqual(FieldGrid.lightestContactRadius, 6)
        XCTAssertEqual(FieldGrid.firmestContactRadius, 28)
        XCTAssertEqual(loudness(radius: 6), 60, "6 points and narrower: TouchVelocity.softest")
        XCTAssertEqual(loudness(radius: 3), 60)
        XCTAssertEqual(loudness(radius: 8), 66, "60 + 67 × 2/22 = 66.09")
        XCTAssertEqual(loudness(radius: 17), 94, "60 + 67 × 0.5 = 93.5, rounded away from zero")
        XCTAssertEqual(loudness(radius: 28), 127, "28 points and wider: TouchVelocity.hardest")
        XCTAssertEqual(loudness(radius: 100), 127)
        XCTAssertEqual(loudness(radius: .infinity), 127)
        XCTAssertEqual(loudness(force: 3, of: 6, radius: 6), 94, "half the most pressure the screen reports")
        XCTAssertEqual(loudness(force: 1.5, of: 6, radius: 28), 127, "whichever says more wins")
        XCTAssertEqual(loudness(force: 6, of: 6, radius: 8), 127)
        XCTAssertEqual(loudness(force: 9, of: 6, radius: 6), 127, "more than the most is the most")
        XCTAssertEqual(loudness(force: -2, of: 6, radius: 6), 60)
        XCTAssertEqual(loudness(force: 5, of: 0, radius: 17), 94, "a screen that senses no pressure: the contact alone")
        var last = loudness(radius: 0)
        for step in 1...80 {
            let now = loudness(radius: Double(step) / 2)
            XCTAssertGreaterThanOrEqual(now, last, "a wider contact is never softer: \(Double(step) / 2) pt")
            last = now
        }
    }

    func testWithTouchLoudnessOffOrNothingKnownACellPlaysTheUnplacedLoudness() {
        XCTAssertEqual(FieldGrid.velocity(force: 0, maximumForce: 0, majorRadius: 6, placesLoudness: false),
                       TouchVelocity.unplaced)
        XCTAssertEqual(FieldGrid.velocity(force: 6, maximumForce: 6, majorRadius: 28, placesLoudness: false), 100)
        XCTAssertEqual(FieldGrid.velocity(force: 0, maximumForce: 0, majorRadius: .nan, placesLoudness: true),
                       TouchVelocity.unplaced, "no pressure sensed and no contact measured")
        XCTAssertEqual(FieldGrid.velocity(force: .nan, maximumForce: .nan, majorRadius: .nan, placesLoudness: true), 100)
        XCTAssertEqual(FieldGrid.velocity(force: 3, maximumForce: 6, majorRadius: .nan, placesLoudness: true), 94,
                       "the pressure alone")
        XCTAssertEqual(FieldGrid.velocity(force: .nan, maximumForce: 6, majorRadius: 28, placesLoudness: true), 127,
                       "the contact alone")
        XCTAssertEqual(FieldGrid.velocity(force: 3, maximumForce: .nan, majorRadius: 6, placesLoudness: true), 60)
    }

    // MARK: - One rect

    /// The picture fills the whole view, the cells only the part inside the safe area. One rect
    /// maps both, so the light under a cell is that cell's, not the earlier app's few points off.
    func testTheGeometryPutsACellsLightUnderTheCell() throws {
        let grid = FieldGrid(context: MusicalContext(scale: .majorPentatonic), device: .synth)
        XCTAssertEqual(grid.columns.count, 5)
        let geometry = FieldGrid.Geometry(viewWidth: 500, viewHeight: 1_000,
                                          play: FieldGrid.Rect(x: 0, y: 100, width: 500, height: 750))
        let bottomMiddle = try XCTUnwrap(grid.cell(column: 2, row: 0))
        assertRect(geometry.frame(of: bottomMiddle, in: grid), 200, 600, 100, 250)
        let low = geometry.uv(of: bottomMiddle, in: grid)
        XCTAssertEqual(low.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(low.y, 0.275, accuracy: 1e-12, "uv runs up: 1 − 725 / 1000")
        let corner = geometry.uv(of: try XCTUnwrap(grid.cell(column: 0, row: 2)), in: grid)
        XCTAssertEqual(corner.x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(corner.y, 0.775, accuracy: 1e-12)
        let middle = geometry.uv(of: try XCTUnwrap(grid.cell(column: 2, row: 1)), in: grid)
        XCTAssertEqual(middle.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(middle.y, 0.525, accuracy: 1e-12, "the cells sit 25 points above the picture's middle")

        let place = geometry.place(x: 250, y: 725)
        XCTAssertEqual(place.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(place.y, 1.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(grid.cell(atX: place.x, y: place.y), bottomMiddle)
        let above = geometry.place(x: 250, y: 40)
        XCTAssertGreaterThan(above.y, 1, "the safe area above the cells is above the grid")
        XCTAssertEqual(grid.cell(atX: above.x, y: above.y).row, 2, "and plays the top row")
    }

    /// A phone on its side: the picture fills 852 × 393 points, the cells keep clear of the camera
    /// housing on both sides and of the home indicator below. Every cell's centre, touched, plays
    /// that cell, and its light sits at that same point of the picture.
    func testATouchAtACellsCentrePlaysThatCellAndItsLightSitsThere() {
        let grid = FieldGrid(context: MusicalContext(root: 2, scale: .dorian), device: .synth)
        let geometry = FieldGrid.Geometry(viewWidth: 852, viewHeight: 393,
                                          play: FieldGrid.Rect(x: 59, y: 0, width: 734, height: 372))
        for cell in grid.cells {
            let frame = geometry.frame(of: cell, in: grid)
            let place = geometry.place(x: frame.midX, y: frame.midY)
            XCTAssertEqual(grid.cell(atX: place.x, y: place.y), cell)
            let uv = geometry.uv(of: cell, in: grid)
            XCTAssertEqual(uv.x, frame.midX / 852, accuracy: 1e-12)
            XCTAssertEqual(uv.y, 1 - frame.midY / 393, accuracy: 1e-12)
        }
        let first = geometry.frame(of: grid.cell(atX: 0, y: 0), in: grid)
        XCTAssertEqual(first.x, 59, accuracy: 1e-9, "the bottom-left cell starts at the play rect's corner")
        XCTAssertEqual(first.maxY, 372, accuracy: 1e-9)
        let last = geometry.frame(of: grid.cell(atX: 1, y: 1), in: grid)
        XCTAssertEqual(last.maxX, 793, accuracy: 1e-9, "and the top-right cell ends at the opposite one")
        XCTAssertEqual(last.y, 0, accuracy: 1e-9)
    }

    func testAGeometryWithoutASizeKeepsEveryAnswerFiniteAndOnThePicture() throws {
        let grid = FieldGrid(context: MusicalContext(scale: .majorPentatonic), device: .synth)
        let broken = [FieldGrid.Geometry(viewWidth: 0, viewHeight: 0),
                      FieldGrid.Geometry(viewWidth: .nan, viewHeight: 800),
                      FieldGrid.Geometry(viewWidth: 500, viewHeight: .infinity,
                                         play: FieldGrid.Rect(x: .nan, y: 0, width: 10, height: 10)),
                      FieldGrid.Geometry(viewWidth: 100, viewHeight: 100,
                                         play: FieldGrid.Rect(x: -50, y: 0, width: 200, height: 100))]
        for geometry in broken {
            for cell in grid.cells {
                let uv = geometry.uv(of: cell, in: grid)
                XCTAssertTrue((0...1).contains(uv.x) && (0...1).contains(uv.y), "\(geometry) \(cell.id)")
                let frame = geometry.frame(of: cell, in: grid)
                XCTAssertTrue([frame.x, frame.y, frame.width, frame.height].allSatisfy(\.isFinite), "\(geometry)")
            }
            let place = geometry.place(x: 30, y: 40)
            XCTAssertTrue(place.x.isFinite && place.y.isFinite, "\(geometry)")
        }
        // With no size to measure against, a cell's light is its own place on the grid.
        let sizeless = FieldGrid.Geometry(viewWidth: 0, viewHeight: 0)
        let middle = sizeless.uv(of: try XCTUnwrap(grid.cell(column: 2, row: 1)), in: grid)
        XCTAssertEqual(middle.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(middle.y, 0.5, accuracy: 1e-12)
        let corner = sizeless.uv(of: try XCTUnwrap(grid.cell(column: 0, row: 0)), in: grid)
        XCTAssertEqual(corner.x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(corner.y, 1.0 / 6, accuracy: 1e-12)
        let nowhere = sizeless.place(x: 3, y: 4)
        XCTAssertEqual([nowhere.x, nowhere.y], [0.5, 0.5], "a play rect with no size places a touch in its middle")
        // A play rect that is no rect reads as the whole view.
        XCTAssertEqual(FieldGrid.Geometry(viewWidth: 500, viewHeight: 1_000,
                                          play: FieldGrid.Rect(x: 0, y: .nan, width: 500, height: 750)),
                       FieldGrid.Geometry(viewWidth: 500, viewHeight: 1_000))
        XCTAssertEqual(FieldGrid.Geometry(viewWidth: 500, viewHeight: 1_000).play,
                       FieldGrid.Rect(x: 0, y: 0, width: 500, height: 1_000))
    }

    // MARK: - What the door would refuse

    /// The door refuses such a context, and the voices would play it as twelve equal steps at
    /// A = 440 Hz (EchoelDSP's `Temperament` counts a cents value that is no number as zero): the
    /// grid shows what they would play, never a column made of no number.
    func testAContextTheDoorWouldRefuseShowsWhatTheVoicesWouldPlay() throws {
        for broken in [Double.nan, 0, -440] {
            let grid = FieldGrid(context: bayati(concertPitch: broken), device: .synth)
            XCTAssertEqual(grid.columns.map(\.interval), Array(0...11), "concert pitch \(broken)")
            XCTAssertTrue(grid.columns.allSatisfy { $0.cents.isFinite })
            XCTAssertEqual(grid.hertz(of: try XCTUnwrap(grid.cell(column: 9, row: 0))), 220, accuracy: 1e-9)
        }
        let huge = FieldGrid(context: MusicalContext(concertPitch: 1e6), device: .synth)
        XCTAssertEqual(huge.hertz(of: try XCTUnwrap(huge.cell(column: 9, row: 0))), 440, accuracy: 1e-9,
                       "a shift beyond an octave is held to one, as the voices hold it")
        let wide = FieldGrid(context: MusicalContext(root: 14, scale: .dorian), device: .synth)
        XCTAssertEqual(wide.root, 2, "a root outside 0 … 11 reads as its pitch class")
        XCTAssertEqual(wide.lowestPitch, 50)
        XCTAssertEqual(FieldGrid(context: MusicalContext(root: -3, scale: .major), device: .synth).lowestPitch, 57)
    }
}
