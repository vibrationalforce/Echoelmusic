import EchoelCore
import Foundation
import XCTest

/// The fingers on the note grid: each plays the cell it lands on, a slide strikes the next cell,
/// every release ends the pitch its finger struck, two fingers on one pitch end it with the last,
/// Hold keeps a lifted note until its cell is touched again, and when the grid goes away every
/// note ends. What is tested is what goes out to the live path, the one place a note could hang.
final class FieldGridTouchesTests: XCTestCase {
    private typealias Touches = FieldGridTouches
    private typealias Event = FieldGridTouches.Event

    /// C chromatic from C3 on the synth: twelve columns, three rows, MIDI 48 at the bottom left.
    private let grid = FieldGrid(context: MusicalContext(), device: .synth)
    /// A view 1,200 × 300 points, the cells over the whole of it: each cell 100 points square.
    private let geometry = FieldGrid.Geometry(viewWidth: 1_200, viewHeight: 300)

    /// The middle of a cell in `geometry`, in view points (y down), on `shown` (the chromatic `grid`,
    /// whose cells are 100 points wide, unless another is named).
    private func contact(column: Int, row: Int, of shown: FieldGrid? = nil, dx: Double = 0,
                         velocity: UInt8 = 100) -> Touches.Contact {
        let width = 1_200 / Double(Swift.max(1, (shown ?? grid).columns.count))
        return Touches.Contact(x: width * (Double(column) + 0.5) + dx, y: 300 - (100 * Double(row) + 50),
                               velocity: velocity)
    }

    /// Only the notes of `events`, without the drops.
    private func notes(_ events: [Event]) -> [Event] {
        events.filter { (event: Event) -> Bool in
            if case .drop = event { return false }
            return true
        }
    }

    /// The drops of `events`.
    private func drops(_ events: [Event]) -> [(x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool)] {
        events.compactMap { (event: Event) -> (x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool)? in
            guard case let .drop(x, y, toneHz, velocity, strong) = event else { return nil }
            return (x, y, toneHz, velocity, strong)
        }
    }

    // MARK: - One finger

    func testAFingerPlaysTheCellItLandsOnAndEndsItWhenItLifts() throws {
        var touches = Touches()
        let down = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        XCTAssertEqual(notes(down), [.noteOn(pitch: 48, velocity: 100)])
        XCTAssertEqual(touches.soundingPitches, [48])
        // The strike drops light where the finger is, in the Field's coordinates (y up), in the
        // colour of the note's frequency, as bright as the touch played on the keys' range.
        let strike = try XCTUnwrap(drops(down).first)
        XCTAssertEqual(drops(down).count, 1)
        XCTAssertTrue(strike.strong)
        XCTAssertEqual(strike.x, 50.0 / 1_200, accuracy: 1e-12)
        XCTAssertEqual(strike.y, 1 - 250.0 / 300, accuracy: 1e-12)
        XCTAssertEqual(strike.toneHz, grid.hertz(ofPitch: 48), accuracy: 1e-9)
        XCTAssertEqual(strike.velocity, 40.0 / 67, accuracy: 1e-12, "100 on the keys' 60 … 127")
        XCTAssertEqual(touches.ended(1), [.noteOff(pitch: 48)])
        XCTAssertEqual(touches.soundingPitches, [])
        XCTAssertEqual(touches.ended(1), [], "a finger that is up ends nothing")
        XCTAssertEqual(touches.moved(1, to: contact(column: 3, row: 0), on: grid, in: geometry), [])
    }

    func testTheSoftestAndTheHardestTouchDropTheFaintestAndTheBrightestLight() throws {
        var touches = Touches()
        let soft = touches.began(1, at: contact(column: 0, row: 0, velocity: TouchVelocity.softest), on: grid, in: geometry)
        let hard = touches.began(2, at: contact(column: 1, row: 0, velocity: TouchVelocity.hardest), on: grid, in: geometry)
        XCTAssertEqual(try XCTUnwrap(drops(soft).first).velocity, 0, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(drops(hard).first).velocity, 1, accuracy: 1e-12)
        XCTAssertEqual(notes(hard), [.noteOn(pitch: 49, velocity: 127)])
    }

    /// No glide on this path: a finger that slides into the next cell ends its note and strikes the
    /// next one; along one cell it only leaves a wake drop every `wakeTravel` points.
    func testSlidingIntoAnotherCellEndsTheNoteAndStrikesTheNext() throws {
        var touches = Touches()
        _ = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        let next = touches.moved(1, to: contact(column: 1, row: 0, velocity: 90), on: grid, in: geometry)
        XCTAssertEqual(notes(next), [.noteOff(pitch: 48), .noteOn(pitch: 49, velocity: 90)],
                       "the old note ends before the new one starts")
        XCTAssertEqual(drops(next).map(\.strong), [true])
        XCTAssertEqual(touches.soundingPitches, [49])
        XCTAssertEqual(touches.moved(1, to: contact(column: 1, row: 0, dx: Touches.wakeTravel - 1), on: grid, in: geometry), [],
                       "not yet far enough for a wake drop")
        let wake = touches.moved(1, to: contact(column: 1, row: 0, dx: Touches.wakeTravel), on: grid, in: geometry)
        XCTAssertEqual(notes(wake), [], "the same cell plays on")
        let trail = try XCTUnwrap(drops(wake).first)
        XCTAssertFalse(trail.strong)
        XCTAssertEqual(trail.x, (150 + Touches.wakeTravel) / 1_200, accuracy: 1e-12)
        XCTAssertEqual(trail.toneHz, grid.hertz(ofPitch: 49), accuracy: 1e-9)
        XCTAssertEqual(touches.moved(1, to: contact(column: 1, row: 0, dx: Touches.wakeTravel + 5), on: grid, in: geometry), [],
                       "the travel counts from the last drop")
        XCTAssertEqual(drops(touches.moved(1, to: contact(column: 1, row: 1), on: grid, in: geometry)).count, 1)
        XCTAssertEqual(touches.ended(1), [.noteOff(pitch: 61)])
    }

    /// A key, scale or octave change under a held finger: the release still ends what the finger
    /// struck, and the finger plays the new grid only once it moves.
    func testAReleaseEndsThePitchTheFingerStruckWhateverTheGridIsNow() {
        var touches = Touches()
        _ = touches.began(1, at: contact(column: 9, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.soundingPitches, [57], "A3")
        let higher = grid.shifted(byOctaves: 1)
        XCTAssertEqual(touches.ended(1), [.noteOff(pitch: 57)], "never A4, which it did not strike")

        _ = touches.began(2, at: contact(column: 9, row: 0), on: grid, in: geometry)
        XCTAssertEqual(notes(touches.moved(2, to: contact(column: 9, row: 0, dx: 1), on: higher, in: geometry)),
                       [.noteOff(pitch: 57), .noteOn(pitch: 69, velocity: 100)], "moved, it plays the grid as it is now")
        let major = FieldGrid(context: MusicalContext(scale: .major), device: .synth)
        XCTAssertEqual(touches.ended(2), [.noteOff(pitch: 69)])
        _ = touches.began(3, at: contact(column: 11, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.soundingPitches, [59], "B3")
        XCTAssertEqual(touches.moved(3, to: contact(column: 11, row: 0, dx: 1), on: major, in: geometry), [],
                       "the same place on C major is its seventh column, B3 again: the note it holds")
        XCTAssertEqual(touches.ended(3), [.noteOff(pitch: 59)])
    }

    /// A cell past MIDI's last note plays nothing; a finger sliding into it ends its note, and out
    /// of it strikes the next cell.
    func testACellPastTheLastNotePlaysNothing() {
        // B in the highest octave: the top row runs B8 (119) … A♯9 (130), past 127 from its tenth column.
        let high = FieldGrid(context: MusicalContext(root: 11), device: .synth, lowestOctave: 6)
        var touches = Touches()
        XCTAssertEqual(touches.began(1, at: contact(column: 9, row: 2), on: high, in: geometry), [])
        XCTAssertEqual(touches.soundingPitches, [])
        XCTAssertEqual(notes(touches.moved(1, to: contact(column: 8, row: 2), on: high, in: geometry)),
                       [.noteOn(pitch: 127, velocity: 100)])
        XCTAssertEqual(touches.moved(1, to: contact(column: 10, row: 2), on: high, in: geometry), [.noteOff(pitch: 127)])
        XCTAssertEqual(touches.ended(1), [])
        XCTAssertEqual(touches.soundingPitches, [])
    }

    /// A touch the screen could not place plays the middle cell, as `FieldGrid` says, and its drop
    /// lands on that cell rather than off the picture.
    func testATouchThatIsNoNumberPlaysTheMiddleCell() throws {
        var touches = Touches()
        let events = touches.began(1, at: Touches.Contact(x: .nan, y: .infinity, velocity: 100), on: grid, in: geometry)
        XCTAssertEqual(notes(events), [.noteOn(pitch: 66, velocity: 100)], "the middle column (F♯) of the middle row")
        let middle = try XCTUnwrap(grid.cell(column: 6, row: 1))
        let drop = try XCTUnwrap(drops(events).first)
        XCTAssertEqual(drop.x, geometry.uv(of: middle, in: grid).x, accuracy: 1e-12)
        XCTAssertEqual(drop.y, geometry.uv(of: middle, in: grid).y, accuracy: 1e-12)
        XCTAssertEqual(touches.moved(1, to: Touches.Contact(x: .nan, y: .nan, velocity: 100), on: grid, in: geometry), [],
                       "still the middle cell, and no travel to measure")
        XCTAssertEqual(touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry), [],
                       "a finger already down does not land twice")
        XCTAssertEqual(touches.ended(1), [.noteOff(pitch: 66)])
    }

    /// The cells lie in the play rect (inside the safe area) and the picture fills the whole view: a
    /// touch beside the cells plays the nearest one, and its drop falls where the finger is.
    func testATouchBesideTheCellsPlaysTheNearestAndDropsItsLightUnderTheFinger() throws {
        let inset = FieldGrid.Geometry(viewWidth: 1_200, viewHeight: 300,
                                       play: FieldGrid.Rect(x: 100, y: 0, width: 1_000, height: 300))
        var touches = Touches()
        let events = touches.began(1, at: Touches.Contact(x: 40, y: 280, velocity: 100), on: grid, in: inset)
        XCTAssertEqual(notes(events), [.noteOn(pitch: 48, velocity: 100)])
        let drop = try XCTUnwrap(drops(events).first)
        XCTAssertEqual(drop.x, 40.0 / 1_200, accuracy: 1e-12)
        XCTAssertEqual(drop.y, 1 - 280.0 / 300, accuracy: 1e-12)
        let cloud = try XCTUnwrap(touches.notes(on: grid).first)
        let cell = try XCTUnwrap(grid.cell(column: 0, row: 0))
        XCTAssertEqual(cloud.x, inset.uv(of: cell, in: grid).x, accuracy: 1e-12, "the cloud sits on the cell")
        XCTAssertEqual(cloud.y, inset.uv(of: cell, in: grid).y, accuracy: 1e-12)
    }

    // MARK: - Several fingers

    /// The engine pairs each note-on of a key with one note-off: the first of two fingers on one
    /// pitch to lift must not cut the note the other still holds.
    func testTwoFingersOnOnePitchEndItWithTheLastToLift() {
        var touches = Touches()
        XCTAssertEqual(notes(touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)),
                       [.noteOn(pitch: 48, velocity: 100)])
        XCTAssertEqual(notes(touches.began(2, at: contact(column: 0, row: 0, dx: 20, velocity: 120), on: grid, in: geometry)),
                       [.noteOn(pitch: 48, velocity: 120)], "the second finger strikes it again")
        XCTAssertEqual(touches.ended(1), [])
        XCTAssertEqual(touches.soundingPitches, [48])
        XCTAssertEqual(notes(touches.moved(2, to: contact(column: 2, row: 0), on: grid, in: geometry)),
                       [.noteOff(pitch: 48), .noteOn(pitch: 50, velocity: 100)])
        XCTAssertEqual(touches.ended(2), [.noteOff(pitch: 50)])
    }

    /// A hand: five fingers play, another plays nothing, even after one of the five lifts, until it
    /// lifts itself.
    func testASixthFingerPlaysNothingUntilItLifts() {
        var touches = Touches()
        XCTAssertEqual(Touches.maximumFingers, 5)
        for finger in 0..<5 {
            XCTAssertEqual(notes(touches.began(finger, at: contact(column: finger, row: 0), on: grid, in: geometry)),
                           [.noteOn(pitch: 48 + finger, velocity: 100)])
        }
        XCTAssertEqual(touches.began(5, at: contact(column: 5, row: 0), on: grid, in: geometry), [])
        XCTAssertEqual(touches.ended(0), [.noteOff(pitch: 48)])
        XCTAssertEqual(touches.moved(5, to: contact(column: 6, row: 0), on: grid, in: geometry), [])
        XCTAssertEqual(touches.ended(5), [])
        XCTAssertEqual(touches.soundingPitches, [49, 50, 51, 52])
        XCTAssertEqual(notes(touches.began(6, at: contact(column: 7, row: 0), on: grid, in: geometry)),
                       [.noteOn(pitch: 55, velocity: 100)], "a new finger has room again")
    }

    // MARK: - Hold

    func testHoldKeepsALiftedNoteUntilItsCellIsTouchedAgain() {
        var touches = Touches()
        XCTAssertEqual(touches.setHold(true), [])
        XCTAssertTrue(touches.holds)
        _ = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.ended(1), [], "Hold keeps it")
        XCTAssertEqual(touches.soundingPitches, [48])
        XCTAssertEqual(touches.began(2, at: contact(column: 0, row: 0, dx: 30), on: grid, in: geometry), [.noteOff(pitch: 48)],
                       "a second tap ends it, strikes nothing and drops no light")
        XCTAssertEqual(touches.moved(2, to: contact(column: 1, row: 0), on: grid, in: geometry), [],
                       "the finger that ended it plays nothing until it lifts")
        XCTAssertEqual(touches.ended(2), [])
        XCTAssertEqual(touches.soundingPitches, [])
        XCTAssertEqual(notes(touches.began(3, at: contact(column: 0, row: 0), on: grid, in: geometry)),
                       [.noteOn(pitch: 48, velocity: 100)], "and a third tap plays it again")
    }

    /// Hold switched off ends the notes it kept, never one a finger still holds, which ends when its
    /// finger lifts; switched on again, it keeps what lifts from then on.
    func testSwitchingHoldOffEndsWhatItKeptButNotWhatAFingerHolds() {
        var touches = Touches()
        _ = touches.setHold(true)
        _ = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        _ = touches.ended(1)
        _ = touches.began(2, at: contact(column: 4, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.setHold(true), [], "on is on")
        XCTAssertEqual(touches.setHold(false), [.noteOff(pitch: 48)])
        XCTAssertFalse(touches.holds)
        XCTAssertEqual(touches.soundingPitches, [52])
        XCTAssertEqual(touches.setHold(false), [])
        XCTAssertEqual(touches.ended(2), [.noteOff(pitch: 52)], "Hold is off when this finger lifts")
        _ = touches.began(3, at: contact(column: 5, row: 0), on: grid, in: geometry)
        _ = touches.setHold(true)
        XCTAssertEqual(touches.ended(3), [], "a finger down when Hold came on keeps its note as it lifts")
        XCTAssertEqual(touches.setHold(false), [.noteOff(pitch: 53)])
        // A kept note a finger has slid onto sounds on under the finger and ends with it.
        _ = touches.setHold(true)
        _ = touches.began(4, at: contact(column: 0, row: 0), on: grid, in: geometry)
        _ = touches.ended(4)
        _ = touches.began(5, at: contact(column: 1, row: 0), on: grid, in: geometry)
        _ = touches.moved(5, to: contact(column: 0, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.setHold(false), [], "the finger on it still holds C3")
        XCTAssertEqual(touches.soundingPitches, [48])
        XCTAssertEqual(touches.ended(5), [.noteOff(pitch: 48)])
    }

    /// A slide is not a tap: a finger sliding over a note Hold keeps strikes it again and leaves it
    /// sounding; lifted, it keeps the note it ends on as well.
    func testAFingerSlidingOverAKeptNoteLeavesItSounding() {
        var touches = Touches()
        _ = touches.setHold(true)
        _ = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        _ = touches.ended(1)
        _ = touches.began(2, at: contact(column: 1, row: 0), on: grid, in: geometry)
        XCTAssertEqual(notes(touches.moved(2, to: contact(column: 0, row: 0), on: grid, in: geometry)),
                       [.noteOff(pitch: 49), .noteOn(pitch: 48, velocity: 100)])
        XCTAssertEqual(notes(touches.moved(2, to: contact(column: 2, row: 0), on: grid, in: geometry)),
                       [.noteOn(pitch: 50, velocity: 100)], "C3 stays: Hold keeps it")
        XCTAssertEqual(touches.ended(2), [])
        XCTAssertEqual(touches.soundingPitches, [48, 50])
    }

    // MARK: - Gone

    /// The grid switched off, the full screen left, a touch the system cancelled: every note ends,
    /// what Hold kept too, once each; the fingers still on the glass play nothing more.
    func testGoingAwayEndsEveryNoteHoldKeptToo() {
        var touches = Touches()
        _ = touches.setHold(true)
        _ = touches.began(1, at: contact(column: 0, row: 0), on: grid, in: geometry)
        _ = touches.ended(1)
        _ = touches.began(2, at: contact(column: 3, row: 0), on: grid, in: geometry)
        _ = touches.began(3, at: contact(column: 3, row: 0, dx: 10), on: grid, in: geometry)
        _ = touches.began(4, at: contact(column: 0, row: 0), on: grid, in: geometry)
        XCTAssertEqual(touches.soundingPitches, [51])
        XCTAssertEqual(touches.releaseAll(), [.noteOff(pitch: 51)], "the fourth finger already ended C3")
        _ = touches.began(5, at: contact(column: 7, row: 1), on: grid, in: geometry)
        _ = touches.ended(5)
        _ = touches.began(6, at: contact(column: 2, row: 2), on: grid, in: geometry)
        XCTAssertEqual(touches.releaseAll(), [.noteOff(pitch: 67), .noteOff(pitch: 74)])
        XCTAssertEqual(touches.soundingPitches, [])
        XCTAssertTrue(touches.holds, "Hold is the musician's switch: going away does not turn it off")
        XCTAssertEqual(touches.moved(6, to: contact(column: 3, row: 2), on: grid, in: geometry), [])
        XCTAssertEqual(touches.ended(6), [])
        XCTAssertEqual(touches.releaseAll(), [])
    }

    // MARK: - The clouds

    /// Every note that sounds is a cloud on the cell it was struck on, once however many fingers
    /// hold it: the fingers' notes first, the newest first, then what Hold keeps.
    func testTheCloudsAreTheNotesThatSoundOnTheirCells() throws {
        var touches = Touches()
        _ = touches.setHold(true)
        _ = touches.began(1, at: contact(column: 4, row: 2, velocity: 127), on: grid, in: geometry)
        _ = touches.ended(1)
        _ = touches.began(2, at: contact(column: 0, row: 0, velocity: 60), on: grid, in: geometry)
        _ = touches.began(3, at: contact(column: 7, row: 1), on: grid, in: geometry)
        _ = touches.began(4, at: contact(column: 7, row: 1, dx: 10), on: grid, in: geometry)
        let clouds = touches.notes(on: grid)
        XCTAssertEqual(clouds.map(\.id), [67, 48, 76])
        XCTAssertTrue(clouds.allSatisfy(\.isLive))
        let fifth = try XCTUnwrap(grid.cell(column: 7, row: 1))
        XCTAssertEqual(clouds[0].x, geometry.uv(of: fifth, in: grid).x, accuracy: 1e-12)
        XCTAssertEqual(clouds[0].y, geometry.uv(of: fifth, in: grid).y, accuracy: 1e-12)
        XCTAssertEqual(clouds[0].toneHz, grid.hertz(ofPitch: 67), accuracy: 1e-9)
        XCTAssertEqual(clouds[1].level, 60.0 / 127, accuracy: 1e-12, "as bright as it was played")
        XCTAssertEqual(clouds[2].level, 1, accuracy: 1e-12)
        // A retuned instrument's cloud wears the colour of what it sounds.
        let bayati = FieldGrid(context: MusicalContext(tuning: "maqam-bayati"), device: .synth)
        var quarter = Touches()
        XCTAssertEqual(notes(quarter.began(1, at: contact(column: 1, row: 0, of: bayati), on: bayati, in: geometry)),
                       [.noteOn(pitch: 49, velocity: 100)], "the quarter tone's column plays C♯3")
        XCTAssertEqual(try XCTUnwrap(quarter.notes(on: bayati).first).toneHz, bayati.hertz(ofPitch: 49), accuracy: 1e-9)
        _ = touches.releaseAll()
        XCTAssertEqual(touches.notes(on: grid).count, 0)
    }

    // MARK: - Nothing hangs

    /// A long walk of fingers landing, sliding and lifting, Hold switched and the octave moved, read
    /// by a receiver that keeps the notes as the engine does (a second note-on of a held key strikes
    /// it again, a note-off ends it): every note-off ends a note that sounds, what the receiver holds
    /// is always what the grid says sounds, and once the grid goes away nothing sounds.
    func testEveryNoteThatStartsEndsAndNoReleaseCutsAnotherNote() {
        var touches = Touches()
        var heard = Set<Int>()
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
        func hear(_ events: [Event], step: Int) {
            for event in events {
                switch event {
                case let .noteOn(pitch, velocity):
                    XCTAssertTrue((0...127).contains(pitch), "step \(step)")
                    XCTAssertGreaterThan(velocity, 0, "step \(step)")
                    heard.insert(pitch)
                case let .noteOff(pitch):
                    XCTAssertTrue(heard.contains(pitch), "step \(step): a note-off for \(pitch), which does not sound")
                    heard.remove(pitch)
                case .drop:
                    break
                }
            }
        }
        var down = Set<Int>()
        var octave = 0
        for step in 0..<4_000 {
            let shown = grid.shifted(byOctaves: octave)
            let finger = next(7)
            let place = Touches.Contact(x: Double(next(1_300)) - 50, y: Double(next(400)) - 50,
                                        velocity: UInt8(60 + next(68)))
            switch next(10) {
            case 0, 1, 2:
                hear(touches.began(finger, at: place, on: shown, in: geometry), step: step)
                down.insert(finger)
            case 3, 4, 5:
                hear(touches.moved(finger, to: place, on: shown, in: geometry), step: step)
            case 6, 7:
                hear(touches.ended(finger), step: step)
                down.remove(finger)
            case 8:
                hear(touches.setHold(next(2) == 0), step: step)
            default:
                octave = next(5) - 3
            }
            XCTAssertEqual(Set(touches.soundingPitches), heard, "step \(step)")
            XCTAssertEqual(touches.soundingPitches, touches.soundingPitches.sorted(), "step \(step)")
        }
        // Leave notes sounding for the last release to mean something: every finger lifts under
        // Hold, and one more lands.
        hear(touches.setHold(true), step: -1)
        for finger in down { hear(touches.ended(finger), step: -1) }
        let free = (0..<12).first { (column: Int) -> Bool in !heard.contains(48 + column) } ?? 0
        hear(touches.began(99, at: contact(column: free, row: 0), on: grid, in: geometry), step: -1)
        XCTAssertFalse(heard.isEmpty)
        XCTAssertEqual(Set(touches.soundingPitches), heard)
        hear(touches.releaseAll(), step: -1)
        XCTAssertEqual(heard, [], "nothing hangs")
        XCTAssertEqual(touches.soundingPitches, [])
        XCTAssertEqual(touches.ended(99), [], "a finger still down after the grid went ends nothing")
    }
}
