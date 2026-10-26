import Foundation
import XCTest
@testable import EchoelCore

final class PluginStateCaptureTests: XCTestCase {
    private let component = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                            manufacturer: PluginComponent.code("Acme"), name: "Mini",
                                            manufacturerName: "Acme")

    private func encoded(_ settings: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
    }

    func testAnUnloadedUnitDoesNotReadSettings() {
        var reads = 0
        let result = PluginStateCapture.evaluate(component: nil, expected: component, stored: Data([1])) {
            reads += 1
            return ["value": 2]
        }
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(reads, 0)
    }

    func testAReplacedUnitCannotDonateSettingsToTheNewPlugin() {
        var replacement = component
        replacement.subtype = PluginComponent.code("Next")
        var reads = 0
        let result = PluginStateCapture.evaluate(component: component, expected: replacement, stored: Data([1])) {
            reads += 1
            return ["oldPlugin": true]
        }
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(reads, 0, "the old unit may still be playing its replacement fade")
    }

    func testMissingSettingsAreUnavailableRatherThanUnchanged() {
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: Data([1])) { nil }
        XCTAssertEqual(result, .unavailable)
    }

    func testAnUnsupportedPropertyListValueIsNotSerializable() {
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: Data([1])) {
            ["unsupported": NSObject()]
        }
        XCTAssertEqual(result, .notSerializable)
    }

    func testAnEmptyDictionaryIsAValidFirstState() throws {
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: nil) { [:] }
        XCTAssertEqual(result, .changed(try encoded([:])))
    }

    func testEqualSerializedSettingsAreUnchanged() throws {
        let settings: [String: Any] = ["value": 2]
        let previous = try encoded(settings)
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: previous) { settings }
        XCTAssertEqual(result, .unchanged)
    }

    func testChangedSettingsKeepTheExistingBinaryPropertyListFormat() throws {
        let previous = try encoded(["value": 1])
        let settings: [String: Any] = ["value": 2]
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: previous) { settings }
        guard case .changed(let data) = result else { return XCTFail("new settings must be captured") }
        var format = PropertyListSerialization.PropertyListFormat.xml
        let decoded = try PropertyListSerialization.propertyList(from: data, format: &format) as? [String: Int]
        XCTAssertEqual(format, .binary)
        XCTAssertEqual(decoded, ["value": 2])
        XCTAssertNotEqual(data, previous)
    }

    func testTheCeilingAppliesToSerializedBytesIncludingPropertyListOverhead() throws {
        let settings: [String: Any] = ["bytes": Data(count: PluginComponent.maximumStateBytes)]
        let byteCount = try encoded(settings).count
        XCTAssertGreaterThan(byteCount, PluginComponent.maximumStateBytes)
        let result = PluginStateCapture.evaluate(component: component, expected: component, stored: nil) { settings }
        XCTAssertEqual(result, .tooLarge(byteCount: byteCount))
    }

    func testExactlyTheStateByteLimitIsAcceptedButOneMoreByteIsNot() throws {
        let limit = PluginComponent.maximumStateBytes
        let overhead = try encoded(["bytes": Data(count: limit)]).count - limit
        let boundary: [String: Any] = ["bytes": Data(count: limit - overhead)]
        XCTAssertEqual(try encoded(boundary).count, limit)
        let accepted = PluginStateCapture.evaluate(component: component, expected: component, stored: nil) { boundary }
        guard case .changed(let data) = accepted else { return XCTFail("the exact limit is allowed") }
        XCTAssertEqual(data.count, limit)

        let over: [String: Any] = ["bytes": Data(count: limit - overhead + 1)]
        XCTAssertEqual(try encoded(over).count, limit + 1)
        let rejected = PluginStateCapture.evaluate(component: component, expected: component, stored: nil) { over }
        XCTAssertEqual(rejected, .tooLarge(byteCount: limit + 1))
    }

    func testFailedCapturesPreserveTheLastDocumentState() throws {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, component).apply(to: &project)
        let previous = try encoded(["value": 1])
        try Command.setPluginState(track, previous).apply(to: &project)
        let before = project
        let settings: [[String: Any]?] = [nil, ["unsupported": NSObject()],
                                         ["bytes": Data(count: PluginComponent.maximumStateBytes)]]
        for candidate in settings {
            let result = PluginStateCapture.evaluate(component: component, expected: component, stored: previous) {
                candidate
            }
            if case .changed(let data) = result {
                try Command.setPluginState(track, data).apply(to: &project)
                XCTFail("a failed capture must never replace the document's state")
            }
            XCTAssertEqual(project, before)
            XCTAssertEqual(project.track(track)?.instrument.pluginState, previous)
        }
    }

    func testAValidCaptureStillWorksAfterAFailedAttempt() throws {
        let previous = try encoded(["value": 1])
        let failed = PluginStateCapture.evaluate(component: component, expected: component, stored: previous) { nil }
        XCTAssertEqual(failed, .unavailable)
        let settings: [String: Any] = ["value": 2]
        let next = PluginStateCapture.evaluate(component: component, expected: component, stored: previous) { settings }
        XCTAssertEqual(next, .changed(try encoded(settings)))
    }
}
