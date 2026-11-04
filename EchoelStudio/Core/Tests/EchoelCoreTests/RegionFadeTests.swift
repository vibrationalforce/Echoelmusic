import Foundation
import XCTest
@testable import EchoelCore

/// AUD-2 (founder 2026-11-04): a region's fades, level and warp, carried over from the earlier
/// app's `FadeEnvelope` rule ("in wins") into today's region.
final class RegionFadeTests: XCTestCase {
    private let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    private func song() throws -> (Project, TrackID, RegionID) {
        var p = Project(tempo: 120)
        let audio = TrackID(), region = RegionID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: audio, id: region, media: file.id, start: 0).apply(to: &p)
        return (p, audio, region)
    }

    func testFadesAndGainAreSetValidatedAndLeaveTheSongAloneWhenRefused() throws {
        var (p, audio, region) = try song()
        try Command.setRegionFades(track: audio, region, fadeIn: 4_800, fadeOut: 9_600,
                                   fadeInCurve: .equalPower, fadeOutCurve: .sCurve).apply(to: &p)
        try Command.setRegionGain(track: audio, region, gainDB: -6).apply(to: &p)
        let r = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(r.fadeIn, 4_800)
        XCTAssertEqual(r.fadeOut, 9_600)
        XCTAssertEqual(r.fadeInCurve, .equalPower)
        XCTAssertEqual(r.fadeOutCurve, .sCurve)
        XCTAssertEqual(r.gainDB, -6)
        XCTAssertEqual(r.linearGain, pow(10, -6.0 / 20), accuracy: 1e-12)

        let before = p
        for (rise, fall) in [(-1, 0), (0, -1), (96_001, 0), (50_000, 46_001)] {
            XCTAssertThrowsError(try Command.setRegionFades(track: audio, region, fadeIn: rise, fadeOut: fall,
                                                            fadeInCurve: .linear, fadeOutCurve: .linear).apply(to: &p), "\(rise)/\(fall)")
        }
        for gain in [Double.nan, .infinity, -61, 25] {
            XCTAssertThrowsError(try Command.setRegionGain(track: audio, region, gainDB: gain).apply(to: &p), "\(gain)")
        }
        XCTAssertThrowsError(try Command.setRegionGain(track: audio, RegionID(), gainDB: 0).apply(to: &p))
        XCTAssertEqual(p, before)

        // Back to none: the stored region is the plain one again.
        try Command.setRegionFades(track: audio, region, fadeIn: 0, fadeOut: 0, fadeInCurve: .linear, fadeOutCurve: .linear).apply(to: &p)
        try Command.setRegionGain(track: audio, region, gainDB: 0).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.first, AudioRegion(id: region, media: file.id, start: 0, length: 96_000))
    }

    func testFadesAndGainAreOneUndoStepEach() async throws {
        let (p, audio, region) = try song()
        try await MainActor.run {
            let store = ProjectStore(project: p)
            try store.perform(.setRegionFades(track: audio, region, fadeIn: 1_000, fadeOut: 2_000,
                                              fadeInCurve: .exponential, fadeOutCurve: .linear))
            try store.perform(.setRegionGain(track: audio, region, gainDB: 3))
            XCTAssertEqual(store.project.track(audio)?.regions.first?.gainDB, 3)
            store.undo()
            XCTAssertNil(store.project.track(audio)?.regions.first?.gainDB)
            XCTAssertEqual(store.project.track(audio)?.regions.first?.fadeIn, 1_000)
            store.undo()
            XCTAssertEqual(store.project, p)
        }
    }

    func testSplitTrimDuplicateAndConsolidateKeepTheFades() throws {
        var (p, audio, region) = try song()
        try Command.setRegionFades(track: audio, region, fadeIn: 30_000, fadeOut: 20_000,
                                   fadeInCurve: .sCurve, fadeOutCurve: .equalPower).apply(to: &p)
        try Command.setRegionGain(track: audio, region, gainDB: -3).apply(to: &p)
        // 120 BPM: one beat is 24 000 frames; cut after two beats.
        let tail = RegionID()
        try Command.splitRegion(track: audio, region, at: 2 * MusicalTime.ticksPerQuarter, newID: tail).apply(to: &p)
        let parts = try XCTUnwrap(p.track(audio)?.regions)
        XCTAssertEqual(parts.map(\.length), [48_000, 48_000])
        XCTAssertEqual(parts[0].fadeIn, 30_000)
        XCTAssertNil(parts[0].fadeOut, "the cut does not fade")
        XCTAssertNil(parts[1].fadeIn)
        XCTAssertEqual(parts[1].fadeOut, 20_000)
        XCTAssertEqual(parts[1].fadeOutCurve, .equalPower)
        XCTAssertEqual(parts.map(\.gainDB), [-3, -3])

        // Joined again, the whole has the head's fade-in and the tail's fade-out.
        let track = try XCTUnwrap(p.track(audio))
        let join = try XCTUnwrap(Arranging.consolidated(parts[0], in: track, project: p))
        var joined = p
        try join.apply(to: &joined)
        let whole = try XCTUnwrap(joined.track(audio)?.regions.first)
        XCTAssertEqual(whole.length, 96_000)
        XCTAssertEqual(whole.fadeIn, 30_000)
        XCTAssertEqual(whole.fadeOut, 20_000)
        XCTAssertEqual(whole.fadeInCurve, .sCurve)

        // A shorter region keeps what fits, the fade-in first.
        try Command.trimRegion(track: audio, region, offset: 0, length: 35_000).apply(to: &p)
        let short = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(short.fadeIn, 30_000)

        // A duplicate fades and sounds as the original.
        let source = try XCTUnwrap(p.track(audio)?.regions.last)
        let copies = try XCTUnwrap(Arranging.duplicated(source, in: try XCTUnwrap(p.track(audio)), project: p))
        for command in copies { try command.apply(to: &p) }
        let copy = try XCTUnwrap(p.track(audio)?.regions.last)
        XCTAssertNotEqual(copy.id, source.id)
        XCTAssertEqual(copy.fadeOut, source.fadeOut)
        XCTAssertEqual(copy.fadeOutCurve, source.fadeOutCurve)
        XCTAssertEqual(copy.gainDB, source.gainDB)
    }

    func testTwoLevelsOrAFadeInsideNeedABounce() throws {
        var (p, audio, region) = try song()
        let tail = RegionID()
        try Command.splitRegion(track: audio, region, at: 2 * MusicalTime.ticksPerQuarter, newID: tail).apply(to: &p)
        try Command.setRegionGain(track: audio, tail, gainDB: -6).apply(to: &p)
        let parts = try XCTUnwrap(p.track(audio)?.regions)
        XCTAssertNil(p.joinedWithoutRendering(parts), "two levels")
        try Command.setRegionGain(track: audio, tail, gainDB: 0).apply(to: &p)
        try Command.setRegionFades(track: audio, region, fadeIn: 0, fadeOut: 100, fadeInCurve: .linear, fadeOutCurve: .linear).apply(to: &p)
        XCTAssertNil(p.joinedWithoutRendering(try XCTUnwrap(p.track(audio)?.regions)), "a fade at the seam")
    }

    func testEveryCurveRunsFromSilenceToFullAndRises() {
        for curve in FadeCurve.allCases {
            XCTAssertEqual(curve.level(0), 0, accuracy: 1e-12, "\(curve)")
            XCTAssertEqual(curve.level(1), 1, accuracy: 1e-12, "\(curve)")
            XCTAssertEqual(curve.level(.nan), 0, "\(curve)")
            XCTAssertEqual(curve.level(2), 1, "\(curve)")
            let steps = (0...100).map { curve.level(Double($0) / 100) }
            XCTAssertTrue(zip(steps, steps.dropFirst()).allSatisfy { $0 <= $1 }, "\(curve) never falls")
        }
        XCTAssertEqual(FadeCurve.equalPower.level(0.5), 0.5.squareRoot(), accuracy: 1e-12)
    }

    /// The fields are optional inside format 4: a plain region writes none of them, a faded one
    /// writes them by name, a curve from a later build is kept and plays linear, and a reader
    /// that knows only the five first keys — an earlier build — reads the region as before.
    func testTheFieldsAreOptionalNamedAndIgnoredByAnEarlierReader() throws {
        var (p, audio, region) = try song()
        let plain = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(try XCTUnwrap(p.track(audio)?.regions.first))) as? [String: Any])
        XCTAssertEqual(Set(plain.keys), ["id", "media", "start", "offset", "length"])

        try Command.setRegionFades(track: audio, region, fadeIn: 480, fadeOut: 960, fadeInCurve: .equalPower, fadeOutCurve: .linear).apply(to: &p)
        try Command.setRegionGain(track: audio, region, gainDB: -4.5).apply(to: &p)
        let data = try ProjectCodec.encode(p)
        XCTAssertEqual(try ProjectCodec.decode(data), p)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let stored = try XCTUnwrap((tracks.first?["regions"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(stored.keys), ["id", "media", "start", "offset", "length", "fadeIn", "fadeOut", "fadeInCurve", "gainDB"])
        XCTAssertEqual(stored["fadeInCurve"] as? String, "equalPower")

        struct EarlierRegion: Decodable, Equatable { let id: UUID; let media: UUID; let start: Int; let offset: Int; let length: Int }
        let earlier = try JSONDecoder().decode(EarlierRegion.self, from: JSONSerialization.data(withJSONObject: stored))
        XCTAssertEqual(earlier.length, 96_000)
        XCTAssertEqual(earlier.offset, 0)

        var later = stored
        later["fadeOutCurve"] = "spiral"
        let read = try JSONDecoder().decode(AudioRegion.self, from: JSONSerialization.data(withJSONObject: later))
        XCTAssertEqual(read.fadeOutCurve, .linear, "an unknown curve plays linear")
        XCTAssertEqual(read.unrecognizedFadeCurves, ["spiral"])
        let back = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(read)) as? [String: Any])
        XCTAssertEqual(back["fadeOutCurve"] as? String, "spiral", "and is saved back unchanged")
    }

    func testASongWithFadesLongerThanTheRegionIsRefused() throws {
        var (p, audio, _) = try song()
        let t = try XCTUnwrap(p.trackIndex(audio))
        p.tracks[t].regions[0].fadeIn = 96_001
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(p)))
        p.tracks[t].regions[0].fadeIn = nil
        p.tracks[t].regions[0].gainDB = 99
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(p)))
    }

    func testTheCommandsAreInTheCatalog() {
        let names = Set(CommandCatalog.all.map(\.name))
        XCTAssertTrue(names.isSuperset(of: ["audio.fades", "audio.gain"]))
    }
}
