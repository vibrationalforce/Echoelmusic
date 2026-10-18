import XCTest
@testable import EchoelCore

final class PluginTests: XCTestCase {
    private let synth = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                        manufacturer: PluginComponent.code("Acme"), name: "Mini", manufacturerName: "Acme")

    private func project() throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        return (project, track)
    }

    func testComponentCodesAndRoles() {
        XCTAssertEqual(PluginComponent.code("aumu"), 0x6175_6D75)
        XCTAssertEqual(PluginComponent.code("toolong"), 0)
        XCTAssertEqual(synth.role, .instrument)
        var effect = synth
        effect.type = PluginComponent.code("aufx")
        XCTAssertEqual(effect.role, .effect)
        effect.type = PluginComponent.code("xxxx")
        XCTAssertNil(effect.role)
    }

    func testChoosingAPluginPlaysItAndClearingReturnsToTheSynth() throws {
        var (p, track) = try project()
        try Command.setInstrumentPlugin(track, synth).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.device, .plugin)
        XCTAssertEqual(p.track(track)?.instrument.plugin, synth)

        // Switching to a built-in instrument keeps the plugin for switching back.
        try Command.setInstrumentDevice(track, .drums).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.plugin, synth)
        try Command.setInstrumentDevice(track, .plugin).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.device, .plugin)

        try Command.setInstrumentPlugin(track, nil).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.device, .synth)
        XCTAssertNil(p.track(track)?.instrument.plugin)
    }

    func testStateBelongsToItsPluginAndHasACeiling() throws {
        var (p, track) = try project()
        XCTAssertThrowsError(try Command.setPluginState(track, Data([1])).apply(to: &p), "no plugin yet")
        try Command.setInstrumentPlugin(track, synth).apply(to: &p)
        try Command.setPluginState(track, Data([1, 2, 3])).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.pluginState, Data([1, 2, 3]))

        // The same plugin chosen again keeps its settings; another one starts fresh.
        try Command.setInstrumentPlugin(track, synth).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.pluginState, Data([1, 2, 3]))
        var other = synth
        other.subtype = PluginComponent.code("Maxi")
        try Command.setInstrumentPlugin(track, other).apply(to: &p)
        XCTAssertNil(p.track(track)?.instrument.pluginState)

        let before = p
        XCTAssertThrowsError(try Command.setPluginState(track, Data(count: PluginComponent.maximumStateBytes + 1)).apply(to: &p))
        XCTAssertEqual(p, before)
    }

    func testOnlyAnInstrumentPluginPlaysAnInstrumentTrack() throws {
        var (p, track) = try project()
        let before = p
        var effect = synth
        effect.type = PluginComponent.code("aufx")
        XCTAssertThrowsError(try Command.setInstrumentPlugin(track, effect).apply(to: &p))
        XCTAssertThrowsError(try Command.setInstrumentDevice(track, .plugin).apply(to: &p), "no plugin chosen")
        XCTAssertEqual(p, before)
    }

    func testAPluginTrackSurvivesTheCodec() throws {
        var (p, track) = try project()
        try Command.setInstrumentPlugin(track, synth).apply(to: &p)
        try Command.setPluginState(track, Data([9, 8, 7])).apply(to: &p)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)), p)
    }
}

final class OwnPluginTests: XCTestCase {
    func testOwnPluginsAreInstrumentsOrEffectsUnderOurManufacturer() {
        XCTAssertFalse(OwnPlugin.all.isEmpty)
        XCTAssertEqual(Set(OwnPlugin.all.map(\.productID)).count, OwnPlugin.all.count)
        for plugin in OwnPlugin.all {
            XCTAssertEqual(plugin.component.manufacturer, PluginComponent.code("Echo"))
            XCTAssertNotNil(plugin.component.role)
            XCTAssertTrue(plugin.productID.hasPrefix("com.echoelmusic.studio."))
        }
    }

    func testTheStandardEffectsAreDistinctEffectsThatKnowThemselvesAgain() {
        let components = StandardEffect.allCases.map(\.component)
        XCTAssertEqual(Set(components).count, StandardEffect.allCases.count)
        let sold = Set(OwnPlugin.all.map(\.component.subtype))
        for effect in StandardEffect.allCases {
            XCTAssertEqual(effect.component.role, .effect)
            XCTAssertEqual(effect.component.manufacturer, PluginComponent.code("Echo"))
            XCTAssertFalse(sold.contains(effect.component.subtype), "a free effect is never a product")
            XCTAssertEqual(StandardEffect(component: effect.component), effect)
        }
        XCTAssertNil(StandardEffect(component: OwnPlugin.synth.component))
    }

    func testTheExtensionCopiesNeverShareAnIdWithTheFreeOnes() {
        let free = Set(StandardEffect.allCases.map(\.component))
        let sold = StandardEffect.allCases.map(\.extensionComponent)
        XCTAssertEqual(Set(sold).count, StandardEffect.allCases.count)
        for (effect, component) in zip(StandardEffect.allCases, sold) {
            XCTAssertFalse(free.contains(component), "one id, two registrations: which loads is chance")
            XCTAssertEqual(component.role, .effect)
            XCTAssertEqual(StandardEffect(extensionComponent: component), effect)
            XCTAssertNil(StandardEffect(component: component), "the app's own chain never takes the paid copy")
            XCTAssertNil(StandardEffect(extensionComponent: effect.component))
        }
        XCTAssertTrue(OwnPlugin.all.contains(OwnPlugin.effects))
    }
}
