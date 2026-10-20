import Foundation
import XCTest
@testable import EchoelCore

/// The two files of the earlier app, in the shape its encoder writes (keys as declared, UUIDs
/// as strings, 480 ticks to the quarter, an empty clip slot as null).
final class LegacySongTests: XCTestCase {
    private let keys = "A1B2C3D4-0000-4000-8000-000000000001"
    private let vox = "A1B2C3D4-0000-4000-8000-000000000002"
    private let bio = "A1B2C3D4-0000-4000-8000-000000000003"
    private let part = "C0000000-0000-4000-8000-000000000001"

    private var timeline: Data {
        Data("""
        {"automation":[],"schemaVersion":1,
         "lanes":[
          {"builtinInstrument":"polySynth","detuneCents":0,"id":"\(keys)","isArmed":false,"isBio":false,"isMuted":false,
           "isSoloed":true,"kind":"midi","level":0.5,"name":"Keys","octaveDouble":0,"pan":-0.25,"transposeSemitones":2},
          {"detuneCents":0,"id":"\(vox)","isArmed":false,"isBio":false,"isMuted":true,"isSoloed":false,"kind":"audio",
           "level":1,"name":"  ","octaveDouble":0,"pan":0,"transposeSemitones":0},
          {"id":"\(bio)","kind":"visual","name":"Light"},
          {"kind":"midi"}
         ],
         "regions":[
          {"clipID":"\(part)","contentOffsetSeconds":0,"contentOffsetTicks":0,"fadeInTicks":0,"fadeOutTicks":0,"gain":1,
           "id":"R0000000-0000-4000-8000-000000000001","laneID":"\(keys)","lengthTicks":1920,"startTick":3840,
           "stretchMode":"clean","transposeSemitones":0,"warpEnabled":false},
          {"clipID":"\(part)","contentOffsetSeconds":0,"contentOffsetTicks":480,"gain":1,
           "id":"R0000000-0000-4000-8000-000000000002","laneID":"\(keys)","lengthTicks":960,"startTick":0,
           "transposeSemitones":-12,"warpEnabled":false},
          {"clipID":"\(part)","id":"R0000000-0000-4000-8000-000000000003","laneID":"\(keys)","lengthTicks":1920,"startTick":7680,
           "contentOffsetTicks":0,"transposeSemitones":0},
          {"broken":true}
         ]}
        """.utf8)
    }

    private var clips: Data {
        Data("""
        [{"automation":[],"colorIndex":0,"composerOwned":false,"id":"\(part)","kind":"midi","name":"Verse",
          "melody":{"notes":[
            {"id":"N1","lengthSteps":4,"lengthTicks":480,"pitch":60,"role":"lead","startStep":0,"startTick":0,"velocity":0.5},
            {"id":"N2","lengthSteps":4,"pitch":64,"role":"lead","startStep":8,"velocity":1},
            {"id":"N3","lengthTicks":240,"pitch":127,"role":"lead","startTick":600,"velocity":0.8},
            {"pitch":"not a number"}]},
          "nativeBPM":0,"schemaVersion":1},
         null,null,null,null,null,null,null]
        """.utf8)
    }

    func testTheSongKeepsItsLanesNotesAndMix() throws {
        let project = try LegacySong.project(timeline: timeline, clips: clips, tempo: 93, name: "Night")
        XCTAssertEqual(project.name, "Night")
        XCTAssertEqual(project.tempo, 93)
        XCTAssertEqual(project.tracks.map(\.name), ["Keys", "Track 2", "Track 4"], "a visual lane is left behind")
        XCTAssertEqual(project.tracks.map(\.kind), [.instrument, .audio, .instrument])
        let keys = project.tracks[0]
        XCTAssertEqual(keys.mixer.volumeDB, 20 * Foundation.log10(0.5), accuracy: 1e-9)
        XCTAssertEqual(keys.mixer.pan, -0.25)
        XCTAssertTrue(keys.mixer.isSoloed)
        XCTAssertTrue(project.tracks[1].mixer.isMuted)
        XCTAssertNoThrow(try project.validate())
    }

    func testRegionsBecomePlacementsAndEachStretchOneClip() throws {
        let keys = try LegacySong.project(timeline: timeline, clips: clips, tempo: 120, name: "N").tracks[0]
        XCTAssertEqual(keys.clips.count, 2, "two regions play the same whole clip; one plays a trimmed stretch")
        XCTAssertEqual(keys.placements.map(\.start).sorted(), [0, 7_680, 15_360], "480 ticks to the quarter become 960")
        let whole = try XCTUnwrap(keys.clips.first { $0.length == 3_840 })
        XCTAssertEqual(whole.name, "Verse")
        // Lane transpose +2; 127 + 2 leaves the keyboard and is dropped; steps stand in for missing ticks.
        XCTAssertEqual(whole.notes.map { "\($0.pitch)@\($0.start)+\($0.length) v\($0.velocity)" },
                       ["62@0+960 v64", "66@1920+960 v127"])
        let trimmed = try XCTUnwrap(keys.clips.first { $0.length == 1_920 })
        XCTAssertEqual(trimmed.notes.map { "\($0.pitch)@\($0.start)" }, ["117@240", "54@960"],
                       "offset 480 old ticks, so the first note falls before it; region −12 and lane +2")
    }

    func testExtremeNumbersInADamagedFileAreLeftOutInsteadOfTrapping() throws {
        let big = Int64.max, small = Int64.min
        let timeline = Data("""
        {"lanes":[{"id":"\(keys)","kind":"midi","name":"Keys","transposeSemitones":\(Int.max)}],
         "regions":[
          {"clipID":"\(part)","laneID":"\(keys)","lengthTicks":\(big),"startTick":0},
          {"clipID":"\(part)","laneID":"\(keys)","lengthTicks":1920,"startTick":\(big)},
          {"clipID":"\(part)","laneID":"\(keys)","lengthTicks":1920,"startTick":0,"contentOffsetTicks":\(big)},
          {"clipID":"\(part)","laneID":"\(keys)","lengthTicks":1920,"startTick":0,"transposeSemitones":\(Int.min)}
         ]}
        """.utf8)
        let clips = Data("""
        [{"id":"\(part)","kind":"midi","name":"Verse","melody":{"notes":[
          {"pitch":60,"startStep":\(big)},
          {"pitch":60,"startTick":\(small)},
          {"pitch":\(Int.max),"startTick":0},
          {"pitch":200,"startTick":0,"lengthTicks":\(big)},
          {"pitch":64,"startTick":0,"lengthSteps":\(big)}]}}]
        """.utf8)
        let project = try LegacySong.project(timeline: timeline, clips: clips, tempo: 120, name: "N")
        let keys = try XCTUnwrap(project.tracks.first)
        XCTAssertEqual(keys.placements.count, 1, "only the region whose numbers fit a song is placed")
        XCTAssertNoThrow(try project.validate())
    }

    func testAVelocityFarOutOfRangeIsHeldToTheKeyboardInsteadOfTrapping() throws {
        let timeline = Data("""
        {"lanes":[{"id":"\(keys)","kind":"midi","name":"Keys"}],
         "regions":[{"clipID":"\(part)","laneID":"\(keys)","lengthTicks":1920,"startTick":0}]}
        """.utf8)
        let clips = Data("""
        [{"id":"\(part)","kind":"midi","name":"Verse","melody":{"notes":[
          {"pitch":60,"startTick":0,"lengthTicks":480,"velocity":1e30},
          {"pitch":62,"startTick":480,"lengthTicks":480,"velocity":-1e30}]}}]
        """.utf8)
        let project = try LegacySong.project(timeline: timeline, clips: clips, tempo: 120, name: "N")
        let clip = try XCTUnwrap(project.tracks.first?.clips.first)
        let velocities = clip.notes.sorted { $0.pitch < $1.pitch }.map(\.velocity)
        XCTAssertEqual(velocities, [EchoelCore.Note.velocityRange.upperBound, EchoelCore.Note.velocityRange.lowerBound])
    }

    func testASongWithoutLanesIsNotImported() {
        XCTAssertThrowsError(try LegacySong.project(timeline: Data(#"{"lanes":[],"regions":[]}"#.utf8), clips: Data("[]".utf8),
                                                    tempo: 120, name: "N"))
        XCTAssertThrowsError(try LegacySong.project(timeline: Data("nonsense".utf8), clips: clips, tempo: 120, name: "N"))
    }

    func testUnreadableClipsLeaveTheLanesAndAnOutOfRangeTempoIsClamped() throws {
        let project = try LegacySong.project(timeline: timeline, clips: Data("{".utf8), tempo: .infinity, name: "")
        XCTAssertEqual(project.name, "Imported Song")
        XCTAssertEqual(project.tempo, Tempo.defaultBPM)
        XCTAssertTrue(project.tracks[0].clips.isEmpty)
        XCTAssertEqual(try LegacySong.project(timeline: timeline, clips: clips, tempo: 5, name: "N").tempo, Tempo.range.lowerBound)
    }

    func testTheLibraryReadsEverySavedSongsEnvelope() throws {
        let timelineObject = try JSONSerialization.jsonObject(with: timeline)
        let clipsObject = try JSONSerialization.jsonObject(with: clips)
        let envelope: [String: Any] = [
            "envelopeVersion": 1, "meta": ["name": "Inner"],
            "timebase": ["ppq": 480, "tempoMap": ["entries": [["atTick": 0, "bpm": 101, "curve": "step"]]]],
            "content": ["timeline": timelineObject, "clipSlots": clipsObject, "playerAutomation": []],
        ]
        let session = try JSONSerialization.data(withJSONObject: envelope).base64EncodedString()
        let rows: [Any] = [["name": "Saved", "bpm": 90, "session": session], ["name": "Broken", "session": "AAAA"], 7]
        let songs = LegacySong.library(try JSONSerialization.data(withJSONObject: rows))
        XCTAssertEqual(songs.map(\.name), ["Saved"])
        XCTAssertEqual(songs.first?.tempo, 101, "the envelope's tempo map wins over the row's copy")
        XCTAssertEqual(songs.first?.tracks.first?.clips.count, 2)
        XCTAssertTrue(LegacySong.library(Data("{}".utf8)).isEmpty)
    }

    func testFindingNothingNeverFinishesTheImport() {
        // A build without the App Group cannot see the earlier app's container: it finds no song.
        // Marking that run done would stop a later build with the group from ever looking.
        for attempts in [1, 3, 99] {
            XCTAssertFalse(LegacySong.importIsFinished(foundSongs: false, failures: 0, attempts: attempts, attemptLimit: 3))
        }
        XCTAssertTrue(LegacySong.importIsFinished(foundSongs: true, failures: 0, attempts: 1, attemptLimit: 3))
        XCTAssertFalse(LegacySong.importIsFinished(foundSongs: true, failures: 2, attempts: 2, attemptLimit: 3),
                       "a run with failures is retried")
        XCTAssertTrue(LegacySong.importIsFinished(foundSongs: true, failures: 2, attempts: 3, attemptLimit: 3),
                      "and given up after the limit")
    }
}
