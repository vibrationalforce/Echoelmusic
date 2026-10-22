import XCTest
@testable import EchoelCore

/// Every built-in device has one parameter table in Core. A command writes all three and a song
/// stores them; a lane plays the synth's only, for now.
final class InstrumentTablesTests: XCTestCase {
    func testEveryRowOfEveryTableIsSaneAndNamedForItsDevice() {
        for device in InstrumentDevice.allCases {
            for row in device.parameters {
                XCTAssertTrue(row.key.rawValue.hasPrefix(device.rawValue + "."), "\(row.key.rawValue) on \(device)")
                XCTAssertTrue(row.accepts(row.defaultValue), "\(row.key.rawValue) default")
                if row.taper == .exponential { XCTAssertGreaterThan(row.range.lowerBound, 0, row.key.rawValue) }
                if row.unit == .choice {
                    XCTAssertEqual(row.choices.count, Int(row.range.upperBound - row.range.lowerBound) + 1, row.key.rawValue)
                }
            }
        }
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
    /// row, stored in the track's `values` and read back through its address. A lane does not play
    /// it yet, so the automation menu does not list it and a lane on it is refused.
    func testADrumsOrSamplerValueIsWrittenAndStoredButTakesNoLaneYet() throws {
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
            XCTAssertEqual(project.descriptor(for: address)?.title, "Sampler \(row.title)")
            XCTAssertNotNil(Command.setParameter(address, to: row.defaultValue), row.key.rawValue)
            XCTAssertNoThrow(try project.validate(), row.key.rawValue)
            let before = project
            XCTAssertThrowsError(try Command.setInstrumentParameter(track, key: row.key.rawValue, value: value + 1)
                .apply(to: &project), row.key.rawValue)
            XCTAssertThrowsError(try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: row.defaultValue)])
                .apply(to: &project), "a lane here would never be heard")
            XCTAssertEqual(project, before)
        }
        XCTAssertThrowsError(try Command.setInstrumentParameter(track, key: "sampler.mode", value: 0.5).apply(to: &project),
                             "a choice is a whole index")
        let listed = project.parameters.map(\.address.key.rawValue)
        XCTAssertFalse(listed.contains { $0.hasPrefix("drums.") || $0.hasPrefix("sampler.") }, "\(listed)")
        var written = project
        written.tracks[0].instrument.values["sampler.attack"] = 9
        XCTAssertThrowsError(try written.validate(), "a song file holding a value outside its row is refused")
    }
}
