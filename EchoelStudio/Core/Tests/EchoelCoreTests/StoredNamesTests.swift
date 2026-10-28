import XCTest
@testable import EchoelCore

/// The names and positions a song file stores still mean what an earlier build meant by them
/// (ultra-audit C5). Measured 2026-10-20: the song file is the only thing Echoel writes —
/// `ProjectCodec` is the one encoder — so these are the names to freeze. The catalog's command
/// names, the Swift case names of `Command` and the assistant's tool names are stored nowhere
/// and are not frozen here; the day one of them is written to disk, it joins this file in the
/// same commit.
///
/// Two kinds of freeze. A NAME (a scale, a track kind, a parameter key) is never renamed. A
/// POSITION is stored too: an automation lane or a MIDI mapping on the scale, the tone system or
/// the synth waveform stores the INDEX of the choice, so a new choice goes at the end of its list
/// and never in the middle. Each list is compared whole and in order, so a new name fails here
/// until it is added — at the end.
final class StoredNamesTests: XCTestCase {
    private let scales = ["chromatic", "major", "minor", "dorian", "phrygian", "lydian", "mixolydian", "locrian",
                          "harmonicMinor", "melodicMinor", "majorPentatonic", "minorPentatonic", "blues", "wholeTone"]
    private let toneSystems = ["edo12", "edo24", "edo19", "edo31", "just-major", "just-minor", "pythagorean",
                               "meantone-quarter", "maqam-rast", "maqam-bayati", "maqam-hijaz", "gamelan-slendro",
                               "gamelan-pelog", "hirajoshi", "bohlen-pierce"]
    private let synthKeys = ["synth.waveform", "synth.cutoff", "synth.resonance", "synth.filterAmount",
                             "synth.filterDecay", "synth.attack", "synth.decay", "synth.sustain", "synth.release",
                             "synth.level", "synth.engine", "synth.character"]
    private let drumsKeys = ["drums.level"]
    private let samplerKeys = ["sampler.root", "sampler.attack", "sampler.release", "sampler.level", "sampler.mode"]

    func testEveryStoredNameStillReadsAsTheSameThing() {
        XCTAssertEqual(Scale.allCases.map(\.rawValue), scales, "never rename or reorder; a new scale goes at the end")
        XCTAssertEqual(TuningSystem.library.map(\.id), toneSystems, "never rename or reorder; a new one goes at the end")
        XCTAssertEqual(TrackKind.allCases.map(\.rawValue), ["instrument", "audio", "returnTrack"])
        XCTAssertEqual(MonitorMode.allCases.map(\.rawValue), ["auto", "in", "off"])
        // A modulation route stores its source, curve and polarity by name (W2).
        XCTAssertEqual(ModulationSource.allCases.map(\.rawValue),
                       ["body.heartRate", "body.hrv", "body.coherence", "body.breath", "lfo.1", "macro.1", "midi.cc.1"])
        for curve in ["linear", "square"] { XCTAssertNotNil(ModulationRoute.Curve(rawValue: curve), curve) }
        for polarity in ["unipolar", "bipolar"] { XCTAssertNotNil(ModulationRoute.Polarity(rawValue: polarity), polarity) }
        for device in ["synth", "drums", "sampler", "plugin"] {
            XCTAssertNotNil(InstrumentDevice(rawValue: device), device)
        }
        XCTAssertEqual(SynthParameter.all.map(\.key.rawValue), synthKeys, "a new synth parameter goes at the end")
        XCTAssertEqual(SynthParameter.waveform.choices, ["Sine", "Saw", "Square", "Triangle"],
                       "a lane stores the waveform's index")
        XCTAssertEqual(SynthParameter.engine.choices, ["Classic", "Supersaw", "FM", "Sub"],
                       "a lane stores the engine's index; a new engine goes at the end")
        // The drums' and the sampler's values are stored too (P1 A5); the order is also their
        // plugin's parameter address, which a host session saves.
        XCTAssertEqual(InstrumentDevice.drums.parameters.map(\.key.rawValue), drumsKeys, "a new row goes at the end")
        XCTAssertEqual(InstrumentDevice.sampler.parameters.map(\.key.rawValue), samplerKeys, "a new row goes at the end")
        XCTAssertEqual(SynthParameter.samplerMode.choices, ["Gate", "One-shot"], "the song stores the mode's index")
    }

    /// A track stores the name of the preset it was loaded from, and the Sound page shows it. Only
    /// the name is stored, never a position, and the song keeps its own values, so the order is
    /// free and a value may be retuned — only the "edited" mark reads the values back through the
    /// name, and a song that loaded the old value then reads as edited from today's preset, which
    /// it is. A renamed preset would leave every earlier song showing a sound the menu no longer
    /// offers, so a name stays.
    func testEveryStoredPresetNameStillNamesAPreset() {
        let names = ["Init", "Pluck", "Warm Pad", "Sub Bass", "Square Lead", "Soft Keys"]
        XCTAssertEqual(Set(InstrumentPreset.all.map(\.name)), Set(names), "never rename a preset; add a new one here")
        XCTAssertEqual(InstrumentSettings().preset, InstrumentPreset.initial.name)
    }

    /// A lane point or a mapped controller stored as index `i` sets the same scale and the same
    /// tone system it set when it was written.
    func testAStoredChoiceIndexStillChoosesTheSameScaleAndToneSystem() throws {
        for (index, name) in scales.enumerated() {
            var project = Project()
            try XCTUnwrap(Command.setParameter(.scale, to: Double(index))).apply(to: &project)
            XCTAssertEqual(project.context.scale.rawValue, name)
            XCTAssertEqual(project.value(of: .scale), Double(index))
        }
        for (index, id) in toneSystems.enumerated() {
            var project = Project()
            try XCTUnwrap(Command.setParameter(.tuning, to: Double(index))).apply(to: &project)
            XCTAssertEqual(project.context.tuning, id)
            XCTAssertEqual(project.value(of: .tuning), Double(index))
        }
    }

    /// Every key a mapping or a lane can name still finds its parameter: the song's own, the
    /// mixer's on the master and on a track, a send, every synth parameter, and both plugin forms.
    func testEveryStoredParameterKeyStillFindsItsParameter() throws {
        var project = Project()
        let keys = TrackID(), room = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: room, name: "Room", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: keys, to: room, db: -6).apply(to: &project)
        func finds(_ owner: ParameterAddress.Owner, _ key: String, line: UInt = #line) {
            XCTAssertNotNil(project.descriptor(for: ParameterAddress(owner, ParameterKey(rawValue: key))),
                            "\(owner) \(key)", line: line)
        }
        for key in ["tempo", "key.root", "key.scale", "tuning.system", "tuning.concertPitch", "groove.swing"] {
            finds(.project, key)
        }
        for key in ["mixer.volume", "mixer.pan"] {
            finds(.master, key)
            finds(.track(keys), key)
        }
        finds(.track(keys), "mixer.send/" + room.description)
        for key in synthKeys + drumsKeys + samplerKeys { finds(.track(keys), key) }

        let insert = InsertID()
        XCTAssertEqual(ParameterKey(rawValue: "plugin.instrument/12").pluginParameter, PluginParameter(.instrument, address: 12))
        XCTAssertEqual(ParameterKey(rawValue: "plugin.insert/\(insert)/3").pluginParameter,
                       PluginParameter(.insert(insert), address: 3))
        XCTAssertEqual(ParameterKey(rawValue: "mixer.send/\(room)").sendTarget, room)
    }
}
