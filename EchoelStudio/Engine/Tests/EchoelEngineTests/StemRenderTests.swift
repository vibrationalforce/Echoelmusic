import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelEngine

/// A stem export: each track or return the mix hears, rendered on its own at the mix's length.
/// Without master inserts the stems add up to the mix, sample by sample, so a DAW that lays them
/// side by side at bar 1 plays the song.
final class StemRenderTests: XCTestCase {
    private struct Song {
        var project: Project
        var keys: TrackID
        var lead: TrackID
        var loop: TrackID
        var room: TrackID
        var samples: [MediaID: SampleBuffer]
    }

    /// Two synth tracks panned apart, one riding its fader along a lane; an audio track; a return
    /// fed by a synth and the audio track; the master turned down.
    private func song() throws -> Song {
        var project = Project(tempo: 120)
        let keys = TrackID(), lead = TrackID(), loop = TrackID(), room = TrackID()
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        let voices: [(TrackID, String, Int, Tick)] = [(keys, "Keys", 60, 0), (lead, "Lead", 67, 480)]
        for (track, name, pitch, start) in voices {
            let clip = ClipID()
            try Command.addTrack(id: track, name: name, kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: name, length: bar).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: pitch, start: start, length: 960)]).apply(to: &project)
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        try Command.setPan(.track(keys), pan: -0.5).apply(to: &project)
        try Command.setPan(.track(lead), pan: 0.6).apply(to: &project)
        try Command.setAutomation(.volume(lead), points: [AutomationPoint(tick: 0, value: -12),
                                                          AutomationPoint(tick: bar, value: 0)]).apply(to: &project)
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 48_000, sampleRate: 48_000)
        try Command.addTrack(id: loop, name: "Loop", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(file).apply(to: &project)
        try Command.placeAudio(track: loop, id: RegionID(), media: file.id, start: 0).apply(to: &project)
        try Command.addTrack(id: room, name: "Room", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: keys, to: room, db: -6).apply(to: &project)
        try Command.setSend(track: loop, to: room, db: -3).apply(to: &project)
        try Command.setVolume(.master, db: -3).apply(to: &project)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.25, count: 48_000), sampleRate: 48_000))
        return Song(project: project, keys: keys, lead: lead, loop: loop, room: room, samples: [file.id: buffer])
    }

    /// The largest difference, per sample, between the mix and the sum of the stems.
    private func gap(_ project: Project, samples: [MediaID: SampleBuffer], stems: [OfflineRender.Stem]) -> (Float, Int) {
        let mix = OfflineRender.render(project, samples: samples)
        var left = [Float](repeating: 0, count: mix.frameCount), right = left
        for stem in stems {
            let part = OfflineRender.render(project, samples: samples, isolating: stem.track, frameCount: mix.frameCount)
            XCTAssertEqual(part.frameCount, mix.frameCount, stem.name)
            XCTAssertEqual(part.sampleRate, 48_000)
            for index in 0..<Swift.min(part.frameCount, mix.frameCount) {
                left[index] += part.left[index]
                right[index] += part.right[index]
            }
        }
        var largest: Float = 0
        for index in 0..<mix.frameCount {
            largest = Swift.max(largest, Swift.abs(mix.left[index] - left[index]), Swift.abs(mix.right[index] - right[index]))
        }
        return (largest, mix.frameCount)
    }

    func testTheStemsAreEveryHeardSourceAndAddUpToTheMix() throws {
        let s = try song()
        let stems = OfflineRender.stems(of: s.project, samples: s.samples)
        XCTAssertEqual(stems.map(\.track), [s.keys, s.lead, s.loop, s.room])
        XCTAssertEqual(stems.map(\.name), ["01 Keys", "02 Lead", "03 Loop", "04 Room"])
        let (largest, frames) = gap(s.project, samples: s.samples, stems: stems)
        XCTAssertGreaterThan(frames, 48_000)
        XCTAssertLessThan(largest, 1e-5, "the stems add up to the mix")
        let room = OfflineRender.render(s.project, samples: s.samples, isolating: s.room, frameCount: frames)
        XCTAssertGreaterThan(room.peak, 0.01, "the return carries what is sent to it")
    }

    /// Mute and solo decide as they do for the mix: a muted track and one a solo silences have no
    /// stem, and a soloed return is the whole mix on its own.
    func testMuteAndSoloDecideTheStemsAsTheyDoTheMix() throws {
        var s = try song()
        try Command.setMute(s.lead, true).apply(to: &s.project)
        var stems = OfflineRender.stems(of: s.project, samples: s.samples)
        XCTAssertEqual(stems.map(\.track), [s.keys, s.loop, s.room])
        XCTAssertLessThan(gap(s.project, samples: s.samples, stems: stems).0, 1e-5)

        try Command.setSolo(s.room, true).apply(to: &s.project)
        stems = OfflineRender.stems(of: s.project, samples: s.samples)
        XCTAssertEqual(stems.map(\.track), [s.room], "the solo silences the tracks; their sends still reach the return")
        XCTAssertLessThan(gap(s.project, samples: s.samples, stems: stems).0, 1e-5)
    }

    func testTwoTracksOfOneNameAreTwoFilesInMixerOrder() throws {
        var project = Project()
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        for name in ["Bass", "Bass", "A/B"] {
            let track = TrackID(), clip = ClipID()
            try Command.addTrack(id: track, name: name, kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: name, length: bar).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: 48, start: 0, length: 480)]).apply(to: &project)
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        let silent = TrackID()
        try Command.addTrack(id: silent, name: "Empty", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertEqual(OfflineRender.stems(of: project).map(\.name), ["01 Bass", "02 Bass", "03 A-B"],
                       "a track that plays nothing has no stem")
        let quiet = OfflineRender.render(project, isolating: silent, frameCount: 1_000)
        XCTAssertEqual(quiet.frameCount, 1_000, "silence where the source plays nothing, at the length asked")
        XCTAssertEqual(quiet.peak, 0)
    }
}
