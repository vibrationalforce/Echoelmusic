import AudioToolbox
import EchoelCore
import Foundation
import XCTest
@testable import EchoelHost

/// What the plugin page's preset menu offers for a hosted unit, and what choosing and saving do.
final class HostedPresetsTests: XCTestCase {
    /// What the fake unit's render plays: its implementor's value, set through the tree.
    private final class Level: @unchecked Sendable {
        var value: AUValue = 0
    }

    /// A unit of another maker with three factory presets that set its one parameter, and user
    /// presets kept in memory as the system's preset store keeps them on disk.
    private final class PresetUnit: AUAudioUnit {
        static let levels: [AUValue] = [0.1, 0.5, 0.9]

        let level = Level()
        private var tree: AUParameterTree?
        private var chosen: AUAudioUnitPreset?
        private var saved: [AUAudioUnitPreset] = []
        private var savedLevels: [Int: AUValue] = [:]
        private let factory: [AUAudioUnitPreset]

        init(presetNames: [String]) throws {
            factory = presetNames.enumerated().map { index, name in
                let preset = AUAudioUnitPreset()
                preset.number = index
                preset.name = name
                return preset
            }
            let description = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0x7072_7374,
                                                        componentManufacturer: 0x5465_7374, componentFlags: 0,
                                                        componentFlagsMask: 0)
            try super.init(componentDescription: description, options: [])
            let gain = AUParameterTree.createParameter(withIdentifier: "gain", name: "Gain", address: 0, min: 0, max: 1,
                                                       unit: .linearGain, unitName: nil,
                                                       flags: [.flag_IsReadable, .flag_IsWritable],
                                                       valueStrings: nil, dependentParameters: nil)
            let made = AUParameterTree.createTree(withChildren: [gain])
            let box = self.level
            made.implementorValueObserver = { _, value in box.value = value }
            made.implementorValueProvider = { _ in box.value }
            tree = made
        }

        private var gain: AUParameter? { tree?.parameter(withAddress: 0) }

        override var parameterTree: AUParameterTree? {
            get { tree }
            set { tree = newValue }
        }

        override var factoryPresets: [AUAudioUnitPreset]? { factory }
        override var supportsUserPresets: Bool { true }
        override var userPresets: [AUAudioUnitPreset] { saved }

        override var currentPreset: AUAudioUnitPreset? {
            get { chosen }
            set {
                guard let newValue else {
                    chosen = nil
                    return
                }
                if newValue.number >= 0, newValue.number < Self.levels.count {
                    gain?.value = Self.levels[newValue.number]
                } else if let stored = savedLevels[newValue.number] {
                    gain?.value = stored
                } else {
                    return
                }
                chosen = newValue
            }
        }

        override func saveUserPreset(_ userPreset: AUAudioUnitPreset) throws {
            saved.removeAll { $0.number == userPreset.number }
            saved.append(userPreset)
            savedLevels[userPreset.number] = level.value
        }

        override var fullStateForDocument: [String: Any]? {
            get { ["gain": NSNumber(value: level.value)] }
            set {
                if let value = (newValue?["gain"] as? NSNumber)?.floatValue { gain?.value = value }
            }
        }
    }

    private let component = PluginComponent(type: PluginComponent.code("aufx"), subtype: 0x7072_7374,
                                            manufacturer: 0x5465_7374, name: "Preset Test", manufacturerName: "Test")

    private func entry(_ number: Int, _ name: String) -> HostedPresets.Entry {
        HostedPresets.Entry(number: number, name: name)
    }

    /// Factory presets in the unit's order, then the user's by name; a number appears once, and an
    /// entry on the wrong side of zero or without a name is not offered.
    func testFactoryAndUserPresetsMergeIntoOneMenuFactoryFirst() {
        let menu = HostedPresets.menu(factory: [entry(2, "Wide"), entry(0, "Init"), entry(-4, "Stray"), entry(2, "Twice"),
                                                entry(1, "  ")],
                                      user: [entry(-1, "Verse"), entry(-2, "Bridge"), entry(3, "Positive")])
        XCTAssertEqual(menu.map(\.name), ["Wide", "Init", "Bridge", "Verse"])
        XCTAssertEqual(menu.map(\.number), [2, 0, -2, -1])
        XCTAssertEqual(menu.map(\.isUser), [false, false, true, true])
        XCTAssertTrue(HostedPresets.menu(factory: [], user: []).isEmpty)
    }

    /// A song saved with a preset this copy of the plugin does not list resolves to nothing — no
    /// crash, no wrong preset.
    func testAStaleNumberResolvesToNil() {
        let menu = [entry(0, "Init"), entry(1, "Lead"), entry(-1, "Mine")]
        XCTAssertEqual(HostedPresets.resolve(1, in: menu), entry(1, "Lead"))
        XCTAssertEqual(HostedPresets.resolve(-1, in: menu), entry(-1, "Mine"))
        XCTAssertNil(HostedPresets.resolve(7, in: menu))
        XCTAssertNil(HostedPresets.resolve(-9, in: menu))
        XCTAssertNil(HostedPresets.resolve(nil, in: menu))
        XCTAssertNil(HostedPresets.resolve(0, in: []))
    }

    /// The previous and next arrows walk the menu and wrap; with nothing chosen, forward is the
    /// first and back the last.
    func testThePresetArrowsWalkTheMenuAndWrap() {
        let menu = [entry(0, "Init"), entry(1, "Lead"), entry(-1, "Mine")]
        XCTAssertEqual(HostedPresets.step(from: entry(0, "Init"), by: 1, in: menu), entry(1, "Lead"))
        XCTAssertEqual(HostedPresets.step(from: entry(-1, "Mine"), by: 1, in: menu), entry(0, "Init"))
        XCTAssertEqual(HostedPresets.step(from: entry(0, "Init"), by: -1, in: menu), entry(-1, "Mine"))
        XCTAssertEqual(HostedPresets.step(from: nil, by: 1, in: menu), entry(0, "Init"))
        XCTAssertEqual(HostedPresets.step(from: nil, by: -1, in: menu), entry(-1, "Mine"))
        XCTAssertEqual(HostedPresets.step(from: entry(9, "Gone"), by: 1, in: menu), entry(0, "Init"))
        XCTAssertNil(HostedPresets.step(from: nil, by: 1, in: []))
    }

    /// The first user preset is −1, the next one below the lowest; a typed name is trimmed and an
    /// empty one is refused.
    func testUserNumbersCountDownAndNamesAreTrimmed() {
        XCTAssertEqual(HostedPresets.nextUserNumber(after: []), -1)
        XCTAssertEqual(HostedPresets.nextUserNumber(after: [entry(-1, "A"), entry(-5, "B")]), -6)
        XCTAssertEqual(HostedPresets.userName("  Chorus Pad \n"), "Chorus Pad")
        XCTAssertNil(HostedPresets.userName(" \n "))
    }

    /// Choosing preset 2 moves what the unit plays, and the capture after it stores the new value —
    /// the settings the song keeps (`PluginStateCapture`, the path the page's capture takes).
    func testChoosingAPresetChangesTheUnitAndTheNextCaptureStoresIt() throws {
        let unit = try PresetUnit(presetNames: ["Soft", "Medium", "Loud"])
        XCTAssertEqual(HostedPresets.menu(of: unit).map(\.name), ["Soft", "Medium", "Loud"])
        XCTAssertTrue(HostedPresets.choose(0, on: unit))
        guard case .changed(let before) = PluginStateCapture.evaluate(component: component, expected: component, stored: nil,
                                                                      settings: { unit.fullStateForDocument }) else {
            return XCTFail("the first capture stores the unit's settings")
        }

        XCTAssertTrue(HostedPresets.choose(2, on: unit))
        XCTAssertEqual(unit.level.value, PresetUnit.levels[2])
        XCTAssertEqual(HostedPresets.current(of: unit), entry(2, "Loud"))
        guard case .changed(let after) = PluginStateCapture.evaluate(component: component, expected: component,
                                                                     stored: before,
                                                                     settings: { unit.fullStateForDocument }) else {
            return XCTFail("a new preset is a change the song takes")
        }
        let stored = try XCTUnwrap(PropertyListSerialization.propertyList(from: after, format: nil) as? [String: Any])
        XCTAssertEqual((stored["gain"] as? NSNumber)?.floatValue, PresetUnit.levels[2])

        XCTAssertFalse(HostedPresets.choose(7, on: unit), "a number the unit does not list")
        XCTAssertEqual(unit.level.value, PresetUnit.levels[2], "leaves it as it was")
        XCTAssertEqual(HostedPresets.current(of: unit), entry(2, "Loud"))
    }

    /// A saved user preset joins the menu after the factory ones, and choosing it brings its sound
    /// back. Saving again under the same name keeps its number.
    func testASavedUserPresetAppearsInTheMenuAndCanBeChosen() throws {
        let unit = try PresetUnit(presetNames: ["Soft", "Medium", "Loud"])
        XCTAssertTrue(HostedPresets.choose(1, on: unit))
        let saved = try XCTUnwrap(try HostedPresets.saveUserPreset(named: " My Sound ", on: unit))
        XCTAssertEqual(saved, entry(-1, "My Sound"))
        XCTAssertEqual(HostedPresets.menu(of: unit).map(\.name), ["Soft", "Medium", "Loud", "My Sound"])

        XCTAssertTrue(HostedPresets.choose(2, on: unit))
        XCTAssertTrue(HostedPresets.choose(-1, on: unit))
        XCTAssertEqual(unit.level.value, PresetUnit.levels[1])

        XCTAssertEqual(try HostedPresets.saveUserPreset(named: "My Sound", on: unit), entry(-1, "My Sound"))
        XCTAssertEqual(try HostedPresets.saveUserPreset(named: "Other", on: unit), entry(-2, "Other"))
        XCTAssertNil(try HostedPresets.saveUserPreset(named: "   ", on: unit), "no name, nothing saved")
        XCTAssertEqual(HostedPresets.menu(of: unit).filter(\.isUser).map(\.name), ["My Sound", "Other"])
    }
}
