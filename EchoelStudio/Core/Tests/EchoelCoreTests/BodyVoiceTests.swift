import XCTest
@testable import EchoelCore

/// The Body voice (W12): a track the keys play and the body shapes through ordinary routes, silent
/// until switched on, shaped only by what a body source measures.
final class BodyVoiceTests: XCTestCase {
    private func apply(_ commands: [Command], to project: inout Project) throws {
        for command in commands { try command.apply(to: &project) }
    }

    private func switched(_ on: Bool, _ project: inout Project) throws {
        let change = try XCTUnwrap(BodyVoice.switching(on, in: project))
        try apply(change.commands, to: &project)
    }

    func testTheSwitchAddsTheBodyTrackOnceWithItsSoundAndRoutes() throws {
        var project = try StarterProject.empty.project()
        XCTAssertFalse(BodyVoice.isOn(in: project), "silent until switched on")
        XCTAssertNil(BodyVoice.switching(false, in: project), "off is where it stands")
        try switched(true, &project)
        XCTAssertTrue(BodyVoice.isOn(in: project))
        let voice = try XCTUnwrap(BodyVoice.track(in: project))
        XCTAssertEqual(voice.kind, .instrument)
        XCTAssertEqual(voice.instrument.device, .synth)
        XCTAssertEqual(voice.instrument.preset, BodyVoice.presetName)
        let engine = Int(voice.instrument.value(.engine).rounded())
        XCTAssertEqual(SynthParameter.engine.choices[engine], BodyVoice.engineName)
        XCTAssertEqual(voice.instrument.value(.character), BodyVoice.character)
        let routes = project.modRoutes.filter { $0.target.owner == .track(voice.id) }
        XCTAssertEqual(routes.count, BodyVoice.routes.count)
        for route in BodyVoice.routes {
            XCTAssertTrue(routes.contains { $0.source == route.source && $0.target.key == route.parameter.key
                                                && $0.depth == route.depth && $0.polarity == route.polarity && $0.enabled })
        }
        XCTAssertNil(BodyVoice.switching(true, in: project), "on is where it stands")
        XCTAssertEqual(project.tracks.filter { $0.name == BodyVoice.trackName }.count, 1)
    }

    func testOffMutesTheVoiceAndOnBringsItBackWithoutASecondTrack() throws {
        var project = try StarterProject.empty.project()
        try switched(true, &project)
        let routes = project.modRoutes
        try switched(false, &project)
        XCTAssertFalse(BodyVoice.isOn(in: project))
        XCTAssertEqual(BodyVoice.track(in: project)?.mixer.isMuted, true)
        XCTAssertEqual(project.modRoutes, routes, "muted, the voice keeps its routes")
        try switched(true, &project)
        XCTAssertTrue(BodyVoice.isOn(in: project))
        XCTAssertEqual(project.tracks.filter { $0.name == BodyVoice.trackName }.count, 1)
        XCTAssertEqual(project.modRoutes, routes)
    }

    /// Only what a body source measures moves the voice — the pulse, HRV, coherence and the breath
    /// the strap and the camera carry — and every route passes the song's own checks.
    func testEveryRouteFollowsAMeasuredSourceAndPassesTheSongsChecks() throws {
        let measured: Set<ModulationSource> = [.heartRate, .hrv, .coherence, .breath]
        XCTAssertTrue(BodyVoice.routes.allSatisfy { measured.contains($0.source) })
        var project = try StarterProject.empty.project()
        try switched(true, &project)
        XCTAssertNoThrow(try project.validate())
        let targets = Set(project.parameters.map(\.address))
        XCTAssertNoThrow(try Modulation.validate(project.modRoutes, targets: targets))
        let voice = try XCTUnwrap(BodyVoice.track(in: project))
        let vibrato = ParameterAddress(.track(voice.id), SynthParameter.vibrato.key)
        let slow = try Modulation.value(of: vibrato, base: 0, routes: project.modRoutes,
                                        sources: [.heartRate: 0.15], targets: targets)
        let fast = try Modulation.value(of: vibrato, base: 0, routes: project.modRoutes,
                                        sources: [.heartRate: 0.4], targets: targets)
        XCTAssertGreaterThan(fast, slow, "a faster pulse, a deeper vibrato")
        let unmeasured = try Modulation.value(of: vibrato, base: 0, routes: project.modRoutes,
                                              sources: [:], targets: targets)
        XCTAssertEqual(unmeasured, 0, "nothing measured, nothing moves")
    }

    /// The breath swells the voice's level both ways around where its sound sets it: up with a
    /// breath in, down with a breath out, never to silence, and exactly where it was while no
    /// breath is measured.
    func testTheBreathSwellsTheLevelAroundWhereTheSoundSetsIt() throws {
        var project = try StarterProject.empty.project()
        try switched(true, &project)
        let voice = try XCTUnwrap(BodyVoice.track(in: project))
        let level = ParameterAddress(.track(voice.id), SynthParameter.level.key)
        let descriptor = try XCTUnwrap(project.descriptor(for: level))
        let base = descriptor.normalized(voice.instrument.value(.level))
        let targets = Set(project.parameters.map(\.address))
        func moved(_ sources: [ModulationSource: Double]) throws -> Double {
            try Modulation.value(of: level, base: base, routes: project.modRoutes, sources: sources, targets: targets)
        }
        XCTAssertGreaterThan(try moved([.breath: 1]), base, "the top of a breath in, louder")
        XCTAssertLessThan(try moved([.breath: 0]), base, "the bottom of a breath out, softer")
        XCTAssertGreaterThan(try moved([.breath: 0]), 0, "a swell, not a gate")
        XCTAssertEqual(try moved([.breath: 0.5]), base, accuracy: 1e-12, "half way, where the sound sets it")
        XCTAssertEqual(try moved([:]), base, "no breath measured, the level as it is")
    }

    /// A song whose Body voice was made before the breath had a route keeps the routes it has:
    /// switching the voice off and on adds none.
    func testAVoiceMadeBeforeTheBreathKeepsItsRoutes() throws {
        var project = try StarterProject.empty.project()
        try switched(true, &project)
        let breath = try XCTUnwrap(project.modRoutes.first { $0.source == .breath })
        try Command.removeModRoute(breath.id).apply(to: &project)
        let earlier = project.modRoutes
        try switched(false, &project)
        try switched(true, &project)
        XCTAssertEqual(project.modRoutes, earlier)
        XCTAssertFalse(project.modRoutes.contains { $0.source == .breath })
    }

    func testAFullSongHasNoRoomForTheVoice() throws {
        var project = Project()
        for index in 0..<Track.limit(for: .instrument) {
            try Command.addTrack(id: TrackID(), name: "Track \(index + 1)", kind: .instrument, index: nil)
                .apply(to: &project)
        }
        XCTAssertFalse(BodyVoice.hasRoom(in: project))
        let change = try XCTUnwrap(BodyVoice.switching(true, in: project))
        var draft = project
        XCTAssertThrowsError(try apply(change.commands, to: &draft))
        XCTAssertTrue(BodyVoice.hasRoom(in: try StarterProject.empty.project()))
    }
}
