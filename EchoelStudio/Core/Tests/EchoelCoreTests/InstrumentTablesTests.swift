import XCTest
@testable import EchoelCore

/// Every built-in device has one parameter table in Core. The drums' and the sampler's are read
/// only, for now: no command writes them and no song lists them.
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

    func testTheSynthTableIsTheOneCommandsUseAndTheOthersAreTheirPluginsToday() {
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

    func testNoCommandWritesADrumsOrSamplerValueYet() throws {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Sampler", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentDevice(track, .sampler).apply(to: &project)
        let before = project
        for row in InstrumentDevice.drums.parameters + InstrumentDevice.sampler.parameters {
            XCTAssertThrowsError(try Command.setInstrumentParameter(track, key: row.key.rawValue, value: row.defaultValue)
                .apply(to: &project), row.key.rawValue)
        }
        XCTAssertEqual(project, before)
        let listed = project.parameters.map(\.address.key.rawValue)
        XCTAssertFalse(listed.contains { $0.hasPrefix("drums.") || $0.hasPrefix("sampler.") }, "\(listed)")
    }
}
