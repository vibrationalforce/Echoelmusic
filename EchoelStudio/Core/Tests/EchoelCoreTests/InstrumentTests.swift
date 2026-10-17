import XCTest
@testable import EchoelCore

final class InstrumentTests: XCTestCase {
    private func project() throws -> (Project, TrackID, TrackID) {
        var project = Project()
        let keys = TrackID(), audio = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: audio, name: "Vox", kind: .audio, index: nil).apply(to: &project)
        return (project, keys, audio)
    }

    func testEveryParameterHasAUniqueKeyAndASaneDefault() {
        let keys = SynthParameter.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
        for p in SynthParameter.all {
            XCTAssertTrue(p.accepts(p.defaultValue), p.title)
            XCTAssertTrue(p.key.rawValue.hasPrefix("synth."))
            if p.taper == .exponential { XCTAssertGreaterThan(p.range.lowerBound, 0, p.title) }
            if p.unit == .choice { XCTAssertEqual(p.choices.count, Int(p.range.upperBound - p.range.lowerBound) + 1) }
        }
    }

    func testEveryPresetLoadsAndOnlyUsesKnownValidValues() throws {
        var (project, keys, _) = try project()
        XCTAssertEqual(Set(InstrumentPreset.all.map(\.name)).count, InstrumentPreset.all.count)
        for preset in InstrumentPreset.all {
            for (key, value) in preset.values {
                let parameter = try XCTUnwrap(SynthParameter.named(ParameterKey(rawValue: key)), key)
                XCTAssertTrue(parameter.accepts(value), "\(preset.name) \(key) = \(value)")
            }
            try Command.loadInstrumentPreset(keys, name: preset.name).apply(to: &project)
            XCTAssertEqual(project.track(keys)?.instrument.preset, preset.name)
        }
    }

    func testAParameterChangeIsStoredAndReadThroughItsAddress() throws {
        var (project, keys, _) = try project()
        let address = ParameterAddress(.track(keys), SynthParameter.cutoff.key)
        XCTAssertEqual(project.value(of: address), SynthParameter.cutoff.defaultValue)
        let command = try XCTUnwrap(Command.setParameter(address, to: 2_000))
        try command.apply(to: &project)
        XCTAssertEqual(project.value(of: address), 2_000)
        XCTAssertEqual(project.track(keys)?.instrument.value(.cutoff), 2_000)
    }

    func testInvalidChangesAreRefused() throws {
        var (project, keys, audio) = try project()
        let bad: [Command] = [
            .setInstrumentParameter(keys, key: "synth.cutoff", value: 5),
            .setInstrumentParameter(keys, key: "synth.cutoff", value: .nan),
            .setInstrumentParameter(keys, key: "synth.waveform", value: 1.5),
            .setInstrumentParameter(keys, key: "synth.nope", value: 1),
            .setInstrumentParameter(audio, key: "synth.cutoff", value: 1_000),
            .loadInstrumentPreset(keys, name: "Nope"),
            .loadInstrumentPreset(audio, name: "Pluck"),
        ]
        let before = project
        for command in bad { XCTAssertThrowsError(try command.apply(to: &project), "\(command)") }
        XCTAssertEqual(project, before)
    }

    func testAudioTracksListNoSynthParameters() throws {
        let (project, _, audio) = try project()
        XCTAssertNil(project.value(of: ParameterAddress(.track(audio), SynthParameter.cutoff.key)))
        XCTAssertFalse(project.parameters.contains { $0.address.owner == .track(audio) && $0.address.key == SynthParameter.cutoff.key })
    }

    func testExponentialAndSteppedTapersRoundTrip() throws {
        let (project, keys, _) = try project()
        let cutoff = try XCTUnwrap(project.descriptor(for: ParameterAddress(.track(keys), SynthParameter.cutoff.key)))
        XCTAssertEqual(cutoff.value(forNormalized: 0), 20, accuracy: 1e-9)
        XCTAssertEqual(cutoff.value(forNormalized: 1), 18_000, accuracy: 1e-6)
        XCTAssertEqual(cutoff.normalized(cutoff.value(forNormalized: 0.37)), 0.37, accuracy: 1e-9)
        let wave = try XCTUnwrap(project.descriptor(for: ParameterAddress(.track(keys), SynthParameter.waveform.key)))
        XCTAssertEqual(wave.value(forNormalized: 0.4), 1)
        XCTAssertEqual(wave.choices, ["Sine", "Saw", "Square", "Triangle"])
    }

    func testASongWithoutInstrumentSettingsStillOpens() throws {
        let (project, keys, _) = try project()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try ProjectCodec.encode(project)) as? [String: Any])
        var tracks = try XCTUnwrap(json["tracks"] as? [[String: Any]])
        for i in tracks.indices { tracks[i].removeValue(forKey: "instrument") }
        json["tracks"] = tracks
        let old = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.track(keys)?.instrument, InstrumentSettings())
    }
}
