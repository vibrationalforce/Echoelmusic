import AudioToolbox
import AVFoundation
import Foundation
import XCTest
@testable import EchoelHost

/// The plugin page around a hosted unit: how large its own interface is drawn, and the rows it
/// shows for a unit that brings no interface.
final class PluginPanelTests: XCTestCase {
    /// A unit of another maker that brings no interface of its own (it does not override
    /// `requestViewController`): three parameters the musician can move, one only to read, one
    /// without a range.
    private final class PlainUnit: AUAudioUnit {
        private var tree: AUParameterTree?

        override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
            try super.init(componentDescription: componentDescription, options: options)
            let writable: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
            let cutoff = AUParameterTree.createParameter(withIdentifier: "cutoff", name: "Cutoff", address: 10,
                                                         min: 20, max: 20_000, unit: .hertz, unitName: nil,
                                                         flags: writable, valueStrings: nil, dependentParameters: nil)
            let drive = AUParameterTree.createParameter(withIdentifier: "drive", name: "Drive", address: 11,
                                                        min: -12, max: 24, unit: .decibels, unitName: nil,
                                                        flags: writable, valueStrings: nil, dependentParameters: nil)
            let mode = AUParameterTree.createParameter(withIdentifier: "mode", name: "Mode", address: 12, min: 0, max: 2,
                                                       unit: .indexed, unitName: nil, flags: writable,
                                                       valueStrings: ["Low", "Band", "High"], dependentParameters: nil)
            let meter = AUParameterTree.createParameter(withIdentifier: "meter", name: "Meter", address: 13, min: 0, max: 1,
                                                        unit: .generic, unitName: nil, flags: [.flag_IsReadable],
                                                        valueStrings: nil, dependentParameters: nil)
            let flat = AUParameterTree.createParameter(withIdentifier: "flat", name: "Flat", address: 14, min: 1, max: 1,
                                                       unit: .generic, unitName: nil, flags: writable,
                                                       valueStrings: nil, dependentParameters: nil)
            let made = AUParameterTree.createTree(withChildren: [cutoff, drive, mode, meter, flat])
            let values = Values()
            made.implementorValueObserver = { parameter, value in values.set(parameter.address, value) }
            made.implementorValueProvider = { parameter in values.get(parameter.address) }
            tree = made
        }

        override var parameterTree: AUParameterTree? {
            get { tree }
            set { tree = newValue }
        }
    }

    /// What the fake unit's render would play, per address.
    private final class Values: @unchecked Sendable {
        private var stored: [UInt64: AUValue] = [:]
        func set(_ address: UInt64, _ value: AUValue) { stored[address] = value }
        func get(_ address: UInt64) -> AUValue { stored[address] ?? 0 }
    }

    private func plainUnit() throws -> PlainUnit {
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0x706C_6E31,
                                                    componentManufacturer: 0x5465_7374, componentFlags: 0,
                                                    componentFlagsMask: 0)
        return try PlainUnit(componentDescription: description, options: [])
    }

    // MARK: - Size

    /// A tablet's area takes the full-size interface; a phone's takes the compact one, whichever
    /// order the unit reports them in.
    func testTheLargestReportedSizeThatFitsIsChosen() {
        let reported = [PluginViewSize.compact, PluginViewSize.expanded]
        XCTAssertEqual(PluginViewSize.choose(reported: reported, available: CGSize(width: 1100, height: 760), preferredHeight: 0),
                       .configuration(index: 1, size: CGSize(width: 1024, height: 700)))
        XCTAssertEqual(PluginViewSize.choose(reported: reported, available: CGSize(width: 390, height: 560), preferredHeight: 0),
                       .configuration(index: 0, size: CGSize(width: 320, height: 240)))
        XCTAssertEqual(PluginViewSize.choose(reported: [PluginViewSize.expanded, PluginViewSize.compact], available: CGSize(width: 1024, height: 700),
                                             preferredHeight: 0),
                       .configuration(index: 0, size: CGSize(width: 1024, height: 700)), "an exact fit fits")
    }

    /// No reported size — or none that fits — keeps the unit's preferred height between 240 and
    /// 560 points, 360 when it states none; a broken area fits nothing.
    func testWithoutAFittingReportedSizeThePreferredHeightIsClamped() {
        let phone = CGSize(width: 390, height: 560)
        XCTAssertEqual(PluginViewSize.choose(reported: [], available: phone, preferredHeight: 900), .height(560))
        XCTAssertEqual(PluginViewSize.choose(reported: [], available: phone, preferredHeight: 100), .height(240))
        XCTAssertEqual(PluginViewSize.choose(reported: [], available: phone, preferredHeight: 400), .height(400))
        XCTAssertEqual(PluginViewSize.choose(reported: [], available: phone, preferredHeight: 0), .height(360))
        XCTAssertEqual(PluginViewSize.choose(reported: [], available: phone, preferredHeight: .nan), .height(360))
        XCTAssertEqual(PluginViewSize.choose(reported: [PluginViewSize.expanded], available: phone, preferredHeight: 300),
                       .height(300))
        XCTAssertEqual(PluginViewSize.choose(reported: [PluginViewSize.compact], available: CGSize(width: CGFloat.nan, height: 500),
                                             preferredHeight: 300), .height(300))
        XCTAssertEqual(PluginViewSize.choose(reported: [CGSize(width: 0, height: 0)], available: phone, preferredHeight: 300),
                       .height(300))
        XCTAssertEqual(PluginViewSize.clampedHeight(900, ceiling: 760), 760, "an expanded page raises the ceiling")
    }

    // MARK: - Generic parameters

    /// A unit without an interface of its own and three parameters the musician can move gives
    /// three rows with name, unit and range; the one only to read and the one without a range are
    /// left out.
    func testAUnitWithoutAnInterfaceGivesOneRowPerWritableParameter() throws {
        let unit = try plainUnit()
        let rows = HostedParameters.rows(of: unit)
        XCTAssertEqual(rows.map(\.address), [10, 11, 12])
        XCTAssertEqual(rows.map(\.name), ["Cutoff", "Drive", "Mode"])
        XCTAssertEqual(rows.map(\.unitName), ["Hz", "dB", ""])
        let ranges: [ClosedRange<Float>] = [20...20_000, -12...24, 0...2]
        XCTAssertEqual(rows.map(\.range), ranges)
        let choices: [[String]] = [[], [], ["Low", "Band", "High"]]
        XCTAssertEqual(rows.map(\.choices), choices)
        XCTAssertEqual(rows[2].choice(at: 1), "Band")
        XCTAssertEqual(rows[2].position(ofChoice: 2), 1)
        XCTAssertNil(rows[2].position(ofChoice: 3))
    }

    /// Moving a row sets the value clamped to its range; a NaN — as a value or as a position —
    /// changes nothing.
    func testMovingARowSetsAClampedNaNSafeValue() throws {
        let unit = try plainUnit()
        let drive = try XCTUnwrap(unit.parameterTree?.parameter(withAddress: 11))

        XCTAssertEqual(HostedParameters.set(11, to: 6, on: unit), 6)
        XCTAssertEqual(drive.value, 6)
        XCTAssertEqual(HostedParameters.set(11, to: 99, on: unit), 24)
        XCTAssertEqual(drive.value, 24)
        XCTAssertEqual(HostedParameters.set(11, to: -99, on: unit), -12)
        XCTAssertNil(HostedParameters.set(11, to: .nan, on: unit))
        XCTAssertEqual(drive.value, -12, "a NaN leaves the unit as it was")

        XCTAssertEqual(HostedParameters.set(drive, toPosition: 0.5), 6)
        XCTAssertEqual(drive.value, 6)
        XCTAssertEqual(HostedParameters.set(drive, toPosition: 3), 24)
        XCTAssertNil(HostedParameters.set(drive, toPosition: .nan))
        XCTAssertEqual(drive.value, 24)

        XCTAssertNil(HostedParameters.set(13, to: 0.5, on: unit), "a parameter only to read is not moved")
        XCTAssertNil(HostedParameters.set(99, to: 0.5, on: unit), "nor one the unit does not have")
    }
}
