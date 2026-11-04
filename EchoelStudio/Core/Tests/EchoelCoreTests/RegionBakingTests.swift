import Foundation
import XCTest
@testable import EchoelCore

/// W3: a region baked with pitch correction or a granular texture plays a new file, keeps its
/// original and its settings, reverts to the same stretch, and all of it is one undo step.
final class RegionBakingTests: XCTestCase {
    private let original = MediaFile(name: "Voice", path: "Media/voice.wav", frameCount: 96_000, sampleRate: 48_000)

    private func song() throws -> (Project, TrackID, RegionID) {
        var p = Project(tempo: 120)
        let audio = TrackID(), region = RegionID()
        try Command.addTrack(id: audio, name: "Voice", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(original).apply(to: &p)
        try Command.placeAudio(track: audio, id: region, media: original.id, start: 960).apply(to: &p)
        // The region plays frames 12 000 … 60 000 of its file.
        try Command.trimRegion(track: audio, region, offset: 12_000, length: 48_000).apply(to: &p)
        return (p, audio, region)
    }

    private func baked(frames: Int = 48_000) -> MediaFile {
        MediaFile(name: "Voice (tuned)", path: "Media/\(UUID()).wav", frameCount: frames, sampleRate: 48_000)
    }

    private let tuning = RegionBaking.PitchCorrection(strength: 0.8, retune: 0.02)

    func testABakePointsTheRegionAtItsFileAndRevertRestoresTheOriginal() throws {
        var (p, audio, region) = try song()
        let plain = try XCTUnwrap(p.track(audio)?.regions.first)
        let file = baked()
        let bake = RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)
        try Command.bakeRegion(track: audio, region, media: file, bake: bake).apply(to: &p)
        let after = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(after.media, file.id)
        XCTAssertEqual(after.offset, 0)
        XCTAssertEqual(after.length, 48_000)
        XCTAssertEqual(after.start, 960)
        XCTAssertEqual(after.bake, bake)
        XCTAssertNotNil(p.mediaFile(original.id), "the original stays in the song")
        XCTAssertNotNil(p.mediaFile(file.id))
        try p.validate()

        try Command.revertRegionBake(track: audio, region).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.first, plain, "Revert gives back the region as it was")
        XCTAssertThrowsError(try Command.revertRegionBake(track: audio, region).apply(to: &p), "nothing left to revert")
    }

    func testABakedRegionIsBakedAgainFromItsOriginalAndATrimRevertsToTheSameStretch() throws {
        var (p, audio, region) = try song()
        try Command.bakeRegion(track: audio, region, media: baked(),
                               bake: RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)).apply(to: &p)
        // A trim inside the baked file: 6 000 frames in, 20 000 long.
        try Command.trimRegion(track: audio, region, offset: 6_000, length: 20_000).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.first?.original.offset, 18_000)
        // Baked again, with a texture, from the original — never from the first bake's file.
        let second = baked(frames: 20_000)
        let texture = RegionBaking.GrainTexture(size: 0.05, density: 0.7, scatter: 0.1, pitch: 7, seed: 99)
        XCTAssertThrowsError(try Command.bakeRegion(track: audio, region, media: second,
                                                    bake: RegionBaking(source: try XCTUnwrap(p.track(audio)?.regions.first?.media),
                                                                       sourceOffset: 0, texture: texture)).apply(to: &p))
        try Command.bakeRegion(track: audio, region, media: second,
                               bake: RegionBaking(source: original.id, sourceOffset: 18_000, pitchCorrection: tuning,
                                                  texture: texture)).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.first?.offset, 0)
        try Command.revertRegionBake(track: audio, region).apply(to: &p)
        let reverted = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(reverted.media, original.id)
        XCTAssertEqual(reverted.offset, 18_000)
        XCTAssertEqual(reverted.length, 20_000)
        XCTAssertNil(reverted.bake)
    }

    func testASplitBakedRegionRevertsEachHalfToItsOwnStretch() throws {
        var (p, audio, region) = try song()
        try Command.bakeRegion(track: audio, region, media: baked(),
                               bake: RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)).apply(to: &p)
        let tail = RegionID()
        // 120 BPM: one beat is 24 000 frames; cut one beat in.
        try Command.splitRegion(track: audio, region, at: 960 + 960, newID: tail).apply(to: &p)
        try Command.revertRegionBake(track: audio, tail).apply(to: &p)
        let back = try XCTUnwrap(p.track(audio)?.regions.first { $0.id == tail })
        XCTAssertEqual(back.media, original.id)
        XCTAssertEqual(back.offset, 36_000)
        XCTAssertEqual(back.length, 24_000)
    }

    func testABakeAndItsRevertAreOneUndoStepEach() async throws {
        let (p, audio, region) = try song()
        let file = baked()
        let bake = RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)
        let source = original.id
        try await MainActor.run {
            let store = ProjectStore(project: p)
            try store.perform(.bakeRegion(track: audio, region, media: file, bake: bake))
            try store.perform(.revertRegionBake(track: audio, region))
            XCTAssertEqual(store.project.track(audio)?.regions.first?.media, source)
            store.undo()
            XCTAssertEqual(store.project.track(audio)?.regions.first?.media, file.id)
            store.undo()
            XCTAssertEqual(store.project, p, "one undo takes the whole bake back, the file's record with it")
        }
    }

    func testABakeOutsideItsRangesOrItsOriginalIsRefusedAndChangesNothing() throws {
        var (p, audio, region) = try song()
        let before = p
        let refused: [(MediaFile, RegionBaking)] = [
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000)),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: .init(strength: .nan))),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: .init(strength: 1.5))),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: .init(retune: -1))),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, texture: .init(size: 2))),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, texture: .init(pitch: .infinity))),
            (baked(), RegionBaking(source: original.id, sourceOffset: 12_000, texture: .init(seed: -1))),
            (baked(), RegionBaking(source: MediaID(), sourceOffset: 12_000, pitchCorrection: tuning)),
            (baked(), RegionBaking(source: original.id, sourceOffset: -1, pitchCorrection: tuning)),
            (baked(), RegionBaking(source: original.id, sourceOffset: 20_000, pitchCorrection: tuning)),
            (baked(frames: 40_000), RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)),
            (MediaFile(name: "x", path: "Media/x.wav", frameCount: 48_000, sampleRate: 44_100),
             RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)),
            (MediaFile(name: "x", path: "/etc/x.wav", frameCount: 48_000, sampleRate: 48_000),
             RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)),
            (original, RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)),
        ]
        for (file, bake) in refused {
            XCTAssertThrowsError(try Command.bakeRegion(track: audio, region, media: file, bake: bake).apply(to: &p), "\(bake)")
        }
        XCTAssertThrowsError(try Command.bakeRegion(track: audio, RegionID(), media: baked(),
                                                    bake: RegionBaking(source: original.id, sourceOffset: 12_000,
                                                                       pitchCorrection: tuning)).apply(to: &p))
        XCTAssertEqual(p, before)
    }

    func testRemovingTheOriginalKeepsTheBakedRegionWithoutAWayBack() throws {
        var (p, audio, region) = try song()
        let file = baked()
        try Command.bakeRegion(track: audio, region, media: file,
                               bake: RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning)).apply(to: &p)
        try Command.removeMedia(original.id).apply(to: &p)
        let kept = try XCTUnwrap(p.track(audio)?.regions.first)
        XCTAssertEqual(kept.media, file.id)
        XCTAssertNil(kept.bake)
        try p.validate()
    }

    func testABakedRegionSurvivesTheCodecAndABrokenBakeRefusesTheSong() throws {
        var (p, audio, region) = try song()
        let bake = RegionBaking(source: original.id, sourceOffset: 12_000, pitchCorrection: tuning,
                                texture: .init(size: 0.1, density: 0.3, scatter: 0.2, pitch: -12, seed: 4_294_967_295))
        try Command.bakeRegion(track: audio, region, media: baked(), bake: bake).apply(to: &p)
        let data = try ProjectCodec.encode(p)
        XCTAssertEqual(try ProjectCodec.decode(data), p)
        let text = String(decoding: data, as: UTF8.self)
        let broken = text.replacingOccurrences(of: "\"sourceOffset\" : 12000", with: "\"sourceOffset\" : 90000")
        XCTAssertNotEqual(broken, text, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), "a bake whose original cannot hold the region")
    }

    func testTheCommandsAreInTheCatalog() {
        let names = Set(CommandCatalog.all.map(\.name))
        XCTAssertTrue(names.isSuperset(of: ["audio.bake", "audio.revertBake"]))
    }
}
