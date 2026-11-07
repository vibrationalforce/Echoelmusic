import Foundation
import XCTest
@testable import EchoelCore

/// The fade grips on a region's top corners and their VoiceOver actions: each ends in ONE
/// `setRegionFades` that the song accepts, held inside the region as it plays now.
final class RegionFadeDragTests: XCTestCase {
    private let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    private func song() throws -> (Project, TrackID, RegionID) {
        var p = Project(tempo: 120)
        let audio = TrackID(), region = RegionID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: audio, id: region, media: file.id, start: 0).apply(to: &p)
        return (p, audio, region)
    }

    private func placed(_ p: Project, _ track: TrackID) throws -> (Track, AudioRegion) {
        let t = try XCTUnwrap(p.track(track))
        return (t, try XCTUnwrap(t.regions.first))
    }

    func testAFadeOnATrimmedRegionStaysInsideTheTrimmedLength() throws {
        var (p, audio, id) = try song()
        try Command.setRegionFades(track: audio, id, fadeIn: 0, fadeOut: 9_600,
                                   fadeInCurve: .equalPower, fadeOutCurve: .sCurve).apply(to: &p)
        try Command.trimRegion(track: audio, id, offset: 0, length: 24_000).apply(to: &p)
        var (t, r) = try placed(p, audio)
        // Dragged far past the end: the fade-in reaches the fade-out, never the file's length.
        let rise = try XCTUnwrap(Arranging.faded(r, edge: .start, toFrames: 100_000, in: t))
        XCTAssertEqual(rise, .setRegionFades(track: audio, id, fadeIn: 14_400, fadeOut: 9_600,
                                             fadeInCurve: .equalPower, fadeOutCurve: .sCurve))
        try rise.apply(to: &p)
        (t, r) = try placed(p, audio)
        XCTAssertEqual((r.fadeIn ?? 0) + (r.fadeOut ?? 0), r.length)
        XCTAssertEqual(r.fadeInCurve, .equalPower, "the curves are kept")
        XCTAssertEqual(r.fadeOutCurve, .sCurve)

        // And the fade-out, dragged as far, only takes what the fade-in leaves: here nothing
        // more, so no command at all.
        XCTAssertEqual(Arranging.fadeLengths(r, edge: .end, toFrames: 1_000_000).fadeOut, 9_600)
        XCTAssertNil(Arranging.faded(r, edge: .end, toFrames: 1_000_000, in: t))
    }

    func testANegativeFadeClampsToNone() throws {
        var (p, audio, id) = try song()
        try Command.setRegionFades(track: audio, id, fadeIn: 4_800, fadeOut: 4_800,
                                   fadeInCurve: .linear, fadeOutCurve: .exponential).apply(to: &p)
        var (t, r) = try placed(p, audio)
        XCTAssertEqual(Arranging.fadeLengths(r, edge: .start, toFrames: -500).fadeIn, 0)
        XCTAssertEqual(Arranging.fadeLengths(r, edge: .end, toFrames: Int.min).fadeOut, 0)
        try XCTUnwrap(Arranging.faded(r, edge: .start, toFrames: -500, in: t)).apply(to: &p)
        (t, r) = try placed(p, audio)
        XCTAssertNil(r.fadeIn)
        XCTAssertEqual(r.fadeOut, 4_800)
        // Already none: no command, so no empty undo step.
        XCTAssertNil(Arranging.faded(r, edge: .start, toFrames: -1, in: t))
    }

    func testADragOfAFifthOfTheRegionIsAFifthOfItsFrames() throws {
        let (p, audio, _) = try song()
        let (_, r) = try placed(p, audio)
        XCTAssertEqual(Arranging.fadeFrames(r, edge: .start, dragged: 20, widthPoints: 100), 19_200)
        // The fade-out grows to the left.
        XCTAssertEqual(Arranging.fadeFrames(r, edge: .end, dragged: -20, widthPoints: 100), 19_200)
        XCTAssertEqual(Arranging.fadeFrames(r, edge: .end, dragged: 20, widthPoints: 100), -19_200)
        XCTAssertEqual(Arranging.fadeFrames(r, edge: .start, dragged: .nan, widthPoints: 100), 0)
        XCTAssertEqual(Arranging.fadeFrames(r, edge: .start, dragged: 20, widthPoints: 0), 0)
    }

    func testOneBeatLongerAndShorterIsTheSameCommandAndOneUndoStep() async throws {
        let (p, audio, id) = try song()
        let (t, r) = try placed(p, audio)
        // 120 BPM at 48 kHz: one beat is half a second, 24 000 frames.
        let longer = try XCTUnwrap(Arranging.faded(r, edge: .start, byBeats: 1, in: t, project: p))
        XCTAssertEqual(longer, Arranging.faded(r, edge: .start, toFrames: 24_000, in: t))
        let fall = try XCTUnwrap(Arranging.faded(r, edge: .end, byBeats: 1, in: t, project: p))
        XCTAssertEqual(fall, .setRegionFades(track: audio, id, fadeIn: 0, fadeOut: 24_000,
                                             fadeInCurve: .linear, fadeOutCurve: .linear))
        XCTAssertNil(Arranging.faded(r, edge: .start, byBeats: -1, in: t, project: p), "no fade has nothing to shorten")
        try await MainActor.run {
            let store = ProjectStore(project: p)
            try store.perform(longer)
            XCTAssertEqual(store.project.track(audio)?.regions.first?.fadeIn, 24_000)
            store.undo()
            XCTAssertEqual(store.project, p)
        }
    }
}
