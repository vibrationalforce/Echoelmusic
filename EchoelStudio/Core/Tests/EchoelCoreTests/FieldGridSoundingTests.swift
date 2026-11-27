import Foundation
import XCTest
@testable import EchoelCore

/// The notes the note grids sound, each grid's own (G5). The full-screen Field and the Field card
/// on the Instrument page each carry a grid, an iPad can show both at once in two windows, and
/// every picture of the app draws one set of clouds: a grid that sounds nothing never takes the
/// clouds of a grid being played, a grid that goes takes only its own, and the clouds read every
/// grid's notes, the grid that changed last first.
final class FieldGridSoundingTests: XCTestCase {
    /// A note of the grid as its clouds read it, at (`x`, 0.5).
    private func note(_ pitch: Int, x: Double = 0.5) -> FieldTouchLight.Note {
        FieldTouchLight.Note(id: pitch, toneHz: 440, x: x, y: 0.5, level: 0.8, isLive: true)
    }

    func testAGridThatSoundsNothingLeavesTheNotesOfAnother() {
        let played = UUID(), idle = UUID()
        var sounding = FieldGridSounding()
        sounding.sound([note(60), note(64)], from: played)
        sounding.sound([], from: idle)
        XCTAssertEqual(sounding.notes, [note(60), note(64)], "a grid drawn again with no finger down takes nothing")
        sounding.sound([], from: idle)
        XCTAssertEqual(sounding.notes, [note(60), note(64)])
    }

    func testEachGridKeepsItsOwnNotesAndTheGridChangedLastComesFirst() {
        let card = UUID(), fullScreen = UUID()
        var sounding = FieldGridSounding()
        sounding.sound([note(60)], from: card)
        sounding.sound([note(67)], from: fullScreen)
        XCTAssertEqual(sounding.notes, [note(67), note(60)], "the grid played last comes first")
        // The card's grid is drawn again and hands in the note it holds: nothing changes, not even
        // the order.
        sounding.sound([note(60)], from: card)
        XCTAssertEqual(sounding.notes, [note(67), note(60)])
        // A second finger on the card: its grid comes first, in its own order.
        sounding.sound([note(62), note(60)], from: card)
        XCTAssertEqual(sounding.notes, [note(62), note(60), note(67)])
        // The full-screen grid's note ends there, and only there.
        sounding.sound([], from: fullScreen)
        XCTAssertEqual(sounding.notes, [note(62), note(60)])
    }

    func testAGridThatGoesTakesOnlyItsOwnNotes() {
        let card = UUID(), fullScreen = UUID()
        var sounding = FieldGridSounding()
        sounding.sound([note(60)], from: card)
        sounding.sound([note(67)], from: fullScreen)
        sounding.sound([], from: card)
        XCTAssertEqual(sounding.notes, [note(67)])
        sounding.sound([], from: card)
        XCTAssertEqual(sounding.notes, [note(67)], "a second release finds nothing of its own")
        sounding.sound([], from: fullScreen)
        XCTAssertEqual(sounding.notes, [])
        XCTAssertEqual(sounding, FieldGridSounding(), "nothing is kept of a grid that sounds nothing")
    }

    func testANoteTwoGridsSoundIsOneCloudFromTheGridChangedLast() {
        let card = UUID(), fullScreen = UUID()
        var sounding = FieldGridSounding()
        sounding.sound([note(60, x: 0.1)], from: card)
        sounding.sound([note(60, x: 0.9), note(64)], from: fullScreen)
        XCTAssertEqual(sounding.notes, [note(60, x: 0.9), note(64)])
        sounding.sound([], from: fullScreen)
        XCTAssertEqual(sounding.notes, [note(60, x: 0.1)], "the card's note shows again where it was struck")
    }

    /// The case the grid's view meets: one grid is played while another, with no finger down, is
    /// drawn again and hands in what it sounds — nothing, at every redraw. The played note's cloud
    /// stays lit, and stays when a finger lands on the other grid and lifts.
    func testAnIdleGridDrawnAgainLeavesTheCloudOfTheGridBeingPlayed() throws {
        let grid = FieldGrid(context: MusicalContext(), device: .synth)
        let geometry = FieldGrid.Geometry(viewWidth: 1_200, viewHeight: 300)
        var played = FieldGridTouches(), idle = FieldGridTouches()
        let fullScreen = UUID(), card = UUID()
        var sounding = FieldGridSounding()
        let down = played.began(1, at: FieldGridTouches.Contact(x: 50, y: 250, velocity: 100), on: grid, in: geometry)
        XCTAssertTrue(down.contains(.noteOn(pitch: 48, velocity: 100)))
        sounding.sound(played.notes(on: grid), from: fullScreen)
        sounding.sound(idle.notes(on: grid), from: card)
        XCTAssertEqual(sounding.notes, played.notes(on: grid))
        XCTAssertEqual(sounding.notes.map(\.id), [48])
        var light = FieldTouchLight()
        let frame = light.shown(now: 0, still: false, sounding: sounding.notes)
        let lit = frame.clouds.filter { (spot: FieldTouchLight.Spot) -> Bool in spot.amplitude > 0 }
        XCTAssertEqual(lit.count, 1)
        let cloud = try XCTUnwrap(lit.first)
        XCTAssertEqual(cloud.amplitude, 100.0 / 127, accuracy: 1e-9, "as bright as the note was played")
        _ = idle.began(1, at: FieldGridTouches.Contact(x: 1_150, y: 50, velocity: 90), on: grid, in: geometry)
        sounding.sound(idle.notes(on: grid), from: card)
        XCTAssertEqual(sounding.notes.map(\.id), [83, 48], "both grids' notes, the one touched last first")
        _ = idle.ended(1)
        sounding.sound(idle.notes(on: grid), from: card)
        XCTAssertEqual(sounding.notes, played.notes(on: grid))
    }
}
