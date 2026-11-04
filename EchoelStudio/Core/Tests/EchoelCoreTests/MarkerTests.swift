import Foundation
import XCTest
@testable import EchoelCore

/// Timeline markers (PRO-W1): named positions, one per tick, changed only through the door.
final class MarkerTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    func testMarkersAreAddedInTimeOrderAndRenamedMovedAndRemoved() throws {
        var project = Project()
        try Command.addMarker(at: 8 * bar, name: " Drop ").apply(to: &project)
        try Command.addMarker(at: 0, name: "Intro").apply(to: &project)
        XCTAssertEqual(project.markers, [Marker(tick: 0, name: "Intro"), Marker(tick: 8 * bar, name: "Drop")])
        try Command.renameMarker(at: 8 * bar, name: "Chorus").apply(to: &project)
        XCTAssertEqual(project.marker(at: 8 * bar)?.name, "Chorus")
        try Command.moveMarker(from: 0, to: 12 * bar).apply(to: &project)
        XCTAssertEqual(project.markers.map(\.tick), [8 * bar, 12 * bar], "a moved marker keeps the order")
        XCTAssertEqual(project.markers.last?.name, "Intro")
        try Command.removeMarker(at: 8 * bar).apply(to: &project)
        XCTAssertEqual(project.markers, [Marker(tick: 12 * bar, name: "Intro")])
    }

    func testTheDoorRefusesWhatAMarkerCannotBe() throws {
        var project = Project()
        try Command.addMarker(at: bar, name: "A").apply(to: &project)
        let before = project
        let refused: [Command] = [
            .addMarker(at: bar, name: "Twice"),
            .addMarker(at: -1, name: "Before"),
            .addMarker(at: MusicalTime.maximumTick + 1, name: "After"),
            .addMarker(at: 2 * bar, name: "   "),
            .renameMarker(at: 3 * bar, name: "Nobody"),
            .renameMarker(at: bar, name: ""),
            .moveMarker(from: 3 * bar, to: 4 * bar),
            .moveMarker(from: bar, to: -bar),
            .removeMarker(at: 5 * bar),
        ]
        for command in refused {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
            XCTAssertEqual(project, before, "a refused command leaves the song as it was")
        }
        try Command.addMarker(at: 2 * bar, name: "B").apply(to: &project)
        XCTAssertThrowsError(try Command.moveMarker(from: bar, to: 2 * bar).apply(to: &project), "onto another marker")
    }

    func testASongHoldsABoundedNumberOfMarkers() throws {
        var project = Project()
        project.markers = (0..<Marker.maximumCount).map { Marker(tick: Tick($0), name: "M\($0)") }
        XCTAssertThrowsError(try Command.addMarker(at: bar * 100, name: "One more").apply(to: &project))
    }

    func testANewMarkerGetsTheNextFreeName() throws {
        var project = Project()
        XCTAssertEqual(project.nextMarkerName(), "Marker 1")
        try Command.addMarker(at: 0, name: "Marker 2").apply(to: &project)
        XCTAssertEqual(project.nextMarkerName(), "Marker 3", "a taken name is skipped")
    }

    func testMarkerSecondsFollowTheTempoMap() throws {
        var project = Project(tempo: 120)
        try Command.setTempoChange(at: 4 * bar, bpm: 60).apply(to: &project)
        try Command.addMarker(at: 4 * bar, name: "Slow").apply(to: &project)
        try Command.addMarker(at: 5 * bar, name: "Later").apply(to: &project)
        let seconds = project.markerSeconds().map(\.seconds)
        XCTAssertEqual(seconds[0], 8, accuracy: 1e-9, "four bars of 4/4 at 120")
        XCTAssertEqual(seconds[1], 12, accuracy: 1e-9, "then one bar at 60")
    }

    func testEachMarkerEditIsOneUndoStep() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.addMarker(at: 0, name: "Intro"))
            try store.perform(.moveMarker(from: 0, to: 960))
            XCTAssertEqual(store.undoTitle, "Move Marker")
            store.undo()
            XCTAssertEqual(store.project.markers, [Marker(tick: 0, name: "Intro")])
            store.undo()
            XCTAssertTrue(store.project.markers.isEmpty)
            store.redo()
            XCTAssertEqual(store.undoTitle, "Add Marker")
        }
    }

    func testTheCatalogNamesTheMarkerCommands() {
        let names = Set(CommandCatalog.all.map(\.name))
        XCTAssertTrue(["marker.add", "marker.rename", "marker.move", "marker.remove"].allSatisfy(names.contains))
    }
}
