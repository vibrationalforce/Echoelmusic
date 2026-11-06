import Foundation
import XCTest
@testable import EchoelCore

/// AUD-2 warp: a region that follows the song's tempo spans its native beats.
final class RegionWarpTests: XCTestCase {
    /// One second at 48 kHz.
    private let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 48_000, sampleRate: 48_000)

    private func song(tempo: Double) throws -> (Project, TrackID, RegionID) {
        var p = Project(tempo: tempo)
        let audio = TrackID(), region = RegionID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: audio, id: region, media: file.id, start: 960).apply(to: &p)
        return (p, audio, region)
    }

    func testAWarpedRegionSpansItsNativeBeatsAtAnySongTempo() throws {
        for tempo in [60.0, 120, 150] {
            var (p, audio, region) = try song(tempo: tempo)
            let plain = try XCTUnwrap(Arranging.end(of: try XCTUnwrap(p.track(audio)?.regions.first), in: p))
            XCTAssertEqual(Double(plain), 960 + 960 * tempo / 60, accuracy: 1, "at the file's speed: one second of the song")
            try Command.setRegionWarp(track: audio, region, nativeBPM: 120, followsTempo: true).apply(to: &p)
            let warped = try XCTUnwrap(p.track(audio)?.regions.first)
            XCTAssertEqual(Arranging.end(of: warped, in: p), 960 + 1_920, "one second at 120 BPM is two beats")
            // Off again keeps the native tempo for next time.
            try Command.setRegionWarp(track: audio, region, nativeBPM: 120, followsTempo: false).apply(to: &p)
            XCTAssertEqual(p.track(audio)?.regions.first?.nativeBPM, 120)
            XCTAssertNil(p.track(audio)?.regions.first?.warpBPM)
        }
    }

    func testWarpIsValidatedAndOneUndoStep() async throws {
        let (p, audio, region) = try song(tempo: 90)
        var bad = p
        for bpm in [Double.nan, 0, 19.9, 1_000] {
            XCTAssertThrowsError(try Command.setRegionWarp(track: audio, region, nativeBPM: bpm, followsTempo: true).apply(to: &bad), "\(bpm)")
        }
        XCTAssertEqual(bad, p)
        try await MainActor.run {
            let store = ProjectStore(project: p)
            try store.perform(.setRegionWarp(track: audio, region, nativeBPM: 100, followsTempo: true))
            XCTAssertEqual(store.project.track(audio)?.regions.first?.warpBPM, 100)
            store.undo()
            XCTAssertEqual(store.project, p)
        }
    }

    func testFollowingARegionWithNoTempoStartsFromTheHeardOneInOneUndoStep() async throws {
        let (p, audio, region) = try song(tempo: 90)
        let plain = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertFalse(plain.hasNativeBPM)
        let start = plain.warpStart(heard: 127.63, songBPM: 90)
        XCTAssertEqual(start.bpm, 127.63)
        XCTAssertEqual(start.source, .heard)
        try await MainActor.run {
            let store = ProjectStore(project: p)
            try store.perform(.setRegionWarp(track: audio, region, nativeBPM: start.bpm, followsTempo: true))
            XCTAssertEqual(store.project.track(audio)?.regions.first?.warpBPM, 127.63)
            store.undo()
            XCTAssertEqual(store.project, p, "one step undoes it")
        }

        // Nothing heard, or nothing usable: the song's tempo, held to the range.
        for heard in [nil, Double.nan, 0, 1_000] as [Double?] {
            let fallback = plain.warpStart(heard: heard, songBPM: 90)
            XCTAssertEqual(fallback.bpm, 90, "\(String(describing: heard))")
            XCTAssertEqual(fallback.source, .song)
        }
        XCTAssertEqual(plain.warpStart(heard: nil, songBPM: .nan).bpm, 120)
        XCTAssertEqual(plain.warpStart(heard: nil, songBPM: 5).bpm, AudioRegion.nativeBPMRange.lowerBound)

        // A set tempo is never overruled by a detection.
        var set = plain
        set.nativeBPM = 100
        XCTAssertTrue(set.hasNativeBPM)
        XCTAssertEqual(set.warpStart(heard: 128, songBPM: 90).bpm, 100)
        XCTAssertEqual(set.warpStart(heard: 128, songBPM: 90).source, .stored)
    }

    func testAHeardTempoRidesAlongOnImportWithWarpOff() throws {
        var (p, audio, region) = try song(tempo: 90)
        let heard = try XCTUnwrap(AudioRegion.nativeBPM(heard: 128))
        XCTAssertNil(AudioRegion.nativeBPM(heard: nil))
        XCTAssertNil(AudioRegion.nativeBPM(heard: .infinity))
        let before = try XCTUnwrap(Arranging.end(of: try XCTUnwrap(p.track(audio)?.regions.first), in: p))
        try Command.setRegionWarp(track: audio, region, nativeBPM: heard, followsTempo: false).apply(to: &p)
        let placed = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(placed.nativeBPM, 128)
        XCTAssertNil(placed.warpBPM, "it plays as imported")
        XCTAssertEqual(Arranging.end(of: placed, in: p), before)
        XCTAssertEqual(placed.warpStart(heard: nil, songBPM: 90).bpm, 128, "Follow Song Tempo starts from it")
    }

    func testAFractionalNativeTempoRoundTripsThroughTheSongFile() throws {
        var (p, audio, region) = try song(tempo: 120)
        try Command.setRegionWarp(track: audio, region, nativeBPM: 127.63, followsTempo: true).apply(to: &p)
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(p))
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded.track(audio)?.regions.first?.nativeBPM, 127.63)
        XCTAssertEqual(decoded.track(audio)?.regions.first?.warpBPM, 127.63)
    }

    func testFittingALoopToItsBarsEndsItOnTheBarLineAtAnySongTempo() throws {
        // A 4-bar loop at 128 BPM: 7.5 s at 48 kHz, at bar 1.
        let loop = MediaFile(name: "Loop", path: "Media/loop128.wav", frameCount: 360_000, sampleRate: 48_000)
        for tempo in [60.0, 97.3, 128, 174] {
            var p = Project(tempo: tempo)
            let audio = TrackID(), region = RegionID()
            try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
            try Command.addMedia(loop).apply(to: &p)
            try Command.placeAudio(track: audio, id: region, media: loop.id, start: 0).apply(to: &p)
            let placed = try XCTUnwrap(p.track(audio)?.regions.first)
            let fitted = try XCTUnwrap(placed.nativeBPM(forBars: 4, sampleRate: loop.sampleRate))
            XCTAssertEqual(fitted, 128, "exactly")
            try Command.setRegionWarp(track: audio, region, nativeBPM: fitted, followsTempo: true).apply(to: &p)
            let warped = try XCTUnwrap(p.track(audio)?.regions.first)
            let bar5 = 4 * MusicalTime.ticksPerBar(p.timeSignature)
            XCTAssertEqual(Arranging.end(of: warped, in: p), bar5, "at \(tempo) BPM the loop ends on bar 5")
        }

        let plain = AudioRegion(media: loop.id, start: 0, length: 360_000)
        XCTAssertEqual(plain.nativeBPM(forBars: 2, sampleRate: 48_000), 64)
        XCTAssertEqual(plain.nativeBPM(forBars: 3, sampleRate: 48_000, quartersPerBar: 3), 72, "3/4")
        XCTAssertNil(plain.nativeBPM(forBars: 0, sampleRate: 48_000))
        XCTAssertNil(plain.nativeBPM(forBars: 4, sampleRate: .nan))
        XCTAssertNil(plain.nativeBPM(forBars: 4, sampleRate: 0))
        XCTAssertNil(plain.nativeBPM(forBars: 4, sampleRate: 48_000, quartersPerBar: .infinity))
        XCTAssertNil(plain.nativeBPM(forBars: 1_000, sampleRate: 48_000), "past the range")
    }

    func testSplitTrimAndDuplicateCountAWarpedRegionInBeats() throws {
        var (p, audio, region) = try song(tempo: 60)
        try Command.setRegionWarp(track: audio, region, nativeBPM: 120, followsTempo: true).apply(to: &p)
        // One beat in: half the file, whatever the song's tempo.
        let tail = RegionID()
        try Command.splitRegion(track: audio, region, at: 960 + 960, newID: tail).apply(to: &p)
        let parts = try XCTUnwrap(p.track(audio)?.regions)
        XCTAssertEqual(parts.map(\.length), [24_000, 24_000])
        XCTAssertEqual(parts.map(\.warpBPM), [120, 120])
        XCTAssertEqual(Arranging.end(of: parts[1], in: p), 960 + 1_920)

        // Extending the head's end by a beat takes a beat of the file: 24 000 frames at 120 BPM.
        let track = try XCTUnwrap(p.track(audio))
        let longer = try XCTUnwrap(Arranging.trimmed(parts[0], edge: .end, byTicks: 960, in: track, project: p))
        var trimmed = p
        for command in longer { try command.apply(to: &trimmed) }
        XCTAssertEqual(trimmed.track(audio)?.regions.first?.length, 48_000)

        let copies = try XCTUnwrap(Arranging.duplicated(parts[1], in: track, project: p))
        for command in copies { try command.apply(to: &p) }
        let copy = try XCTUnwrap(p.track(audio)?.regions.last)
        XCTAssertEqual(copy.start, 960 + 1_920)
        XCTAssertEqual(copy.warpBPM, 120)
    }

    func testAnEarlierBuildsSongPlaysPlain() throws {
        let (p, audio, _) = try song(tempo: 120)
        let region = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertNil(region.warpBPM)
        XCTAssertNil(region.nativeBPM)
        XCTAssertTrue(CommandCatalog.all.map(\.name).contains("audio.warp"))
    }
}
