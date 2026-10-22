import XCTest
@testable import EchoelCore

/// Every built-in device has one parameter table in Core. A command writes all three, a song
/// stores them, and a lane plays the rows of the device the track plays.
final class InstrumentTablesTests: XCTestCase {
    func testEveryRowOfEveryTableIsSaneAndNamedForItsDevice() {
        for device in InstrumentDevice.allCases {
            for row in device.parameters {
                XCTAssertTrue(row.key.rawValue.hasPrefix(device.rawValue + "."), "\(row.key.rawValue) on \(device)")
                XCTAssertTrue(row.accepts(row.defaultValue), "\(row.key.rawValue) default")
                XCTAssertTrue(row.accepts(row.songDefault), "\(row.key.rawValue) song default")
                if row.taper == .exponential { XCTAssertGreaterThan(row.range.lowerBound, 0, row.key.rawValue) }
                if row.unit == .choice {
                    XCTAssertEqual(row.choices.count, Int(row.range.upperBound - row.range.lowerBound) + 1, row.key.rawValue)
                }
            }
        }
    }

    /// The app always played the kit at unity while the Drums plugin starts at 0.8: a song that
    /// stores no level plays and resets to unity, the plugin keeps its own default, and every other
    /// row has one default for both.
    func testASongPlaysItsDrumsAtUnityWhileThePluginStartsAtItsDefault() throws {
        XCTAssertEqual(SynthParameter.drumsLevel.songDefault, 1)
        XCTAssertEqual(SynthParameter.drumsLevel.defaultValue, 0.8)
        XCTAssertEqual(InstrumentSettings().value(.drumsLevel), 1)
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        let address = ParameterAddress(.track(track), SynthParameter.drumsLevel.key)
        XCTAssertEqual(project.value(of: address), 1)
        XCTAssertEqual(project.descriptor(for: address)?.defaultValue, 1, "a double tap returns to unity")
        for row in InstrumentDevice.allCases.flatMap(\.parameters) where row.key != SynthParameter.drumsLevel.key {
            XCTAssertEqual(row.songDefault, row.defaultValue, row.key.rawValue)
        }
    }

    /// A lane on a device the track no longer plays waits in the song, silent; its title says so,
    /// so it never reads like the playing device's lane of the same name.
    func testALaneOfADeviceThatIsNotPlayingIsNamedForThatDevice() throws {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        let synthLevel = ParameterAddress(.track(track), SynthParameter.level.key)
        try Command.setAutomation(synthLevel, points: [AutomationPoint(tick: 0, value: 0.5)]).apply(to: &project)
        XCTAssertEqual(project.descriptor(for: synthLevel)?.title, "Beat Level", "the playing synth's row keeps its name")
        try Command.setInstrumentDevice(track, .drums).apply(to: &project)
        XCTAssertEqual(project.descriptor(for: synthLevel)?.title, "Beat Synth Level (not playing)")
        let drumsLevel = ParameterAddress(.track(track), SynthParameter.drumsLevel.key)
        XCTAssertEqual(project.descriptor(for: drumsLevel)?.title, "Beat Level", "the kit's row, which plays, keeps the plain name")
        XCTAssertEqual(project.parameters.filter { $0.address.owner == .track(track) }.map(\.title).filter { $0.contains("Level") },
                       ["Beat Level"], "the menu offers only the playing row")
    }

    func testNoTwoDevicesShareAKey() {
        // A track keeps one `values` dictionary whatever its device, so keys must be unique across tables.
        let keys = InstrumentDevice.allCases.flatMap(\.parameters).map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testEachDeviceHasOneTableInItsPluginsOrder() {
        XCTAssertEqual(InstrumentDevice.synth.parameters, SynthParameter.all)
        XCTAssertEqual(InstrumentDevice.drums.parameters.map(\.key.rawValue), ["drums.level"])
        XCTAssertEqual(InstrumentDevice.sampler.parameters.map(\.key.rawValue),
                       ["sampler.root", "sampler.attack", "sampler.release", "sampler.level", "sampler.mode"])
        XCTAssertEqual(InstrumentDevice.plugin.parameters, [])
        XCTAssertEqual(InstrumentDevice.unrecognized.parameters, [])
    }

    func testTheSynthTableIsItsCaseListAndEveryKeyFindsItsCase() {
        XCTAssertEqual(SynthParameter.all, SynthParameter.Name.allCases.map(\.parameter))
        for name in SynthParameter.Name.allCases {
            XCTAssertEqual(SynthParameter.Name(name.parameter.key), name)
        }
        XCTAssertNil(SynthParameter.Name(ParameterKey(rawValue: "sampler.root")), "the case list is the synth's only")
        XCTAssertEqual(SynthParameter.cutoff, SynthParameter.Name.cutoff.parameter)
    }

    /// A drums or sampler value is written by the command a synth value is, checked against its
    /// row, stored in the track's `values` and read back through its address; a lane on it is
    /// checked against the same row. The automation menu lists the rows of the device that plays.
    func testADrumsOrSamplerValueIsWrittenStoredAndTakesALane() throws {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Sampler", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentDevice(track, .sampler).apply(to: &project)
        for row in InstrumentDevice.drums.parameters + InstrumentDevice.sampler.parameters {
            let address = ParameterAddress(.track(track), row.key)
            let value = row.range.upperBound
            try Command.setInstrumentParameter(track, key: row.key.rawValue, value: value).apply(to: &project)
            XCTAssertEqual(project.track(track)?.instrument.values[row.key.rawValue], value, row.key.rawValue)
            XCTAssertEqual(project.value(of: address), value, row.key.rawValue)
            // The kit's row on a sampler track names the kit: its lane would be silent here.
            let playing = InstrumentDevice.sampler.parameters.contains { $0.key == row.key }
            XCTAssertEqual(project.descriptor(for: address)?.title,
                           playing ? "Sampler \(row.title)" : "Sampler Drums \(row.title) (not playing)")
            XCTAssertNotNil(Command.setParameter(address, to: row.defaultValue), row.key.rawValue)
            XCTAssertNoThrow(try project.validate(), row.key.rawValue)
            let before = project
            XCTAssertThrowsError(try Command.setInstrumentParameter(track, key: row.key.rawValue, value: value + 1)
                .apply(to: &project), row.key.rawValue)
            XCTAssertEqual(project, before)

            var laned = project
            try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: row.defaultValue)]).apply(to: &laned)
            XCTAssertEqual(laned.automation(for: address)?.points.count, 1, row.key.rawValue)
            XCTAssertNoThrow(try laned.validate(), row.key.rawValue)
            let held = laned
            XCTAssertThrowsError(try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: row.range.upperBound + 1)])
                .apply(to: &laned), "a point outside the row is refused")
            XCTAssertEqual(laned, held)
        }
        XCTAssertThrowsError(try Command.setInstrumentParameter(track, key: "sampler.mode", value: 0.5).apply(to: &project),
                             "a choice is a whole index")
        func listed(_ project: Project) -> [String] {
            project.parameters.filter { $0.address.owner == .track(track) }.map(\.address.key.rawValue)
                .filter { $0.hasPrefix("synth.") || $0.hasPrefix("drums.") || $0.hasPrefix("sampler.") }
        }
        let samplerKeys: [String] = InstrumentDevice.sampler.parameters.map(\.key.rawValue)
        XCTAssertEqual(listed(project), samplerKeys, "the sampler's rows, not the synth's")
        try Command.setInstrumentDevice(track, .drums).apply(to: &project)
        XCTAssertEqual(listed(project), ["drums.level"])
        try Command.setInstrumentDevice(track, .synth).apply(to: &project)
        let synthKeys: [String] = SynthParameter.all.map(\.key.rawValue)
        XCTAssertEqual(listed(project), synthKeys)
        var written = project
        written.tracks[0].instrument.values["sampler.attack"] = 9
        XCTAssertThrowsError(try written.validate(), "a song file holding a value outside its row is refused")
    }
}
