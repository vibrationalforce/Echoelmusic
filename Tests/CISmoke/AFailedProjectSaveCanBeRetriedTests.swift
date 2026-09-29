// BEHAVIOUR: exercise ProjectStore's actual write boundary, including a failed
// write followed by a retry. Device rendering of the error banner is separate.
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AFailedProjectSaveCanBeRetriedTests: XCTestCase {
    func testAFailedWriteDoesNotPretendThatTheProjectWasSaved() {
        let disk = AppGroupStore(subdirectory: "SaveFailure-\(UUID().uuidString)")
        var acceptsWrites = false
        var written: [Project] = []
        let store = ProjectStore(store: disk, writeProjects: { projects in
            guard acceptsWrites else { return false }
            written = projects
            return true
        })
        let project = Project(
            name: "Own composition", styleRaw: "ambient", keyRoot: 0,
            scaleRaw: "major", bpm: 96, modeRaw: "flowFree",
            fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
            toneSystemID: nil, moodFields: nil, artist: "",
            patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
            drumSteps: [], drumAccents: [])

        store.save(project)
        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertNotNil(store.saveError)
        XCTAssertNil(store.lastSavedAt)
        XCTAssertTrue(store.hasPendingSave)
        XCTAssertEqual(store.recoveryProject(id: project.id)?.id, project.id)

        acceptsWrites = true
        XCTAssertTrue(store.retrySave())
        XCTAssertEqual(written.map { $0.id }, [project.id])
        XCTAssertEqual(store.projects.map { $0.id }, [project.id])
        XCTAssertNil(store.saveError)
        XCTAssertNotNil(store.lastSavedAt)
        XCTAssertFalse(store.hasPendingSave)
    }

    func testANewerFailedSaveKeepsEarlierPendingProjects() {
        let disk = AppGroupStore(subdirectory: "SaveQueue-\(UUID().uuidString)")
        var acceptsWrites = false
        let store = ProjectStore(store: disk, writeProjects: { _ in acceptsWrites })
        func project(_ name: String) -> Project {
            Project(name: name, styleRaw: "ambient", keyRoot: 0, scaleRaw: "major",
                    bpm: 96, modeRaw: "flowFree", fxCharacterRaw: "warm",
                    loopBars: 4, a4Hz: 440, toneSystemID: nil, moodFields: nil,
                    artist: "", patch: SynthPatch(name: "Default"), notes: [],
                    rawTake: nil, drumSteps: [], drumAccents: [])
        }
        let first = project("First")
        let second = project("Second")
        store.save(first)
        store.save(second)
        acceptsWrites = true
        XCTAssertTrue(store.retrySave())
        XCTAssertEqual(Set(store.projects.map { $0.id }), Set([first.id, second.id]))
    }

    func testFailedRecoveryRetainsTheSongAcrossAnotherAutosave() throws {
        var acceptsWrites = false
        let store = ProjectStore(store: AppGroupStore(subdirectory: UUID().uuidString),
                                 writeProjects: { _ in acceptsWrites })
        var live = Project(name: "Own song", styleRaw: "ambient", keyRoot: 0,
            scaleRaw: "major", bpm: 96, modeRaw: "flowFree", fxCharacterRaw: "warm",
            loopBars: 4, a4Hz: 440, toneSystemID: nil, moodFields: nil, artist: "",
            patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
            drumSteps: [], drumAccents: [])
        live.id = Project.autosaveSlotID
        let song = Data("the retained session envelope".utf8)
        live.setSessionEnvelope(song)
        store.save(live)
        live.setSessionEnvelope(nil)
        live.name = "Legacy take"
        let second = try XCTUnwrap(SessionSaveOpen.recoveryRow(live: live,
            takeIsLive: true, songHasUserParts: false,
            existingSlot: store.recoveryProject(id: Project.autosaveSlotID)))
        store.save(second)
        acceptsWrites = true
        XCTAssertTrue(store.retrySave())
        XCTAssertEqual(store.project(id: Project.autosaveSlotID)?.sessionEnvelope, song)
    }

    func testImportReportsAWriteFailureThenRetriesTheSameFreshIdentity() throws {
        var acceptsWrites = false
        let store = ProjectStore(store: AppGroupStore(subdirectory: UUID().uuidString),
                                 writeProjects: { _ in acceptsWrites })
        let bytes = Data(#"{"name":"Arriving"}"#.utf8)
        XCTAssertThrowsError(try store.importProject(fromDocument: bytes)) { error in
            XCTAssertTrue(ProjectStore.isPersistenceFailure(error))
        }
        XCTAssertTrue(store.projects.isEmpty)
        acceptsWrites = true
        XCTAssertTrue(store.retrySave())
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertNil(store.saveError)
        XCTAssertEqual(store.projects.first?.name, "Arriving")
    }
}
