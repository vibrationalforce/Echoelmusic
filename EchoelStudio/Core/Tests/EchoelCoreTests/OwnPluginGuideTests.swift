import XCTest
@testable import EchoelCore

/// What every place that explains Echoelmusic's own Audio Units says about them in other apps:
/// what they are, how to load one, what a device has tried and what it has not — built from the
/// units, and nothing wider than what a device showed.
final class OwnPluginGuideTests: XCTestCase {
    private func unit(_ name: String, subtype: String) -> OwnPlugin {
        OwnPlugin(component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code(subtype),
                                             manufacturer: PluginComponent.code("Echo"), name: name,
                                             manufacturerName: "Echoelmusic"),
                  summary: "A unit for the test.")
    }

    private func lines(of guide: OwnPluginGuide) -> [String] {
        [guide.what, guide.howToLoad, guide.tried, guide.untested]
    }

    func testTheShippedInstrumentsAreNamedForOtherApps() {
        let guide = OwnPluginGuide()
        XCTAssertEqual(guide.what, "Synth, Drums and Sampler as Audio Units for other apps. In Echoelmusic they are built in.")
        XCTAssertEqual(guide.howToLoad,
                       "In the other app, add an Audio Unit instrument and choose Synth, Drums or Sampler by Echoelmusic.")
    }

    func testTheTriedLineIsTheOneSentenceADeviceShowedAndStandsOnlyInItsOwnLine() {
        let guide = OwnPluginGuide()
        XCTAssertEqual(guide.tried, "The synthesizer has been tried in AUM on an iPhone.")
        for line in [guide.what, guide.howToLoad] {
            XCTAssertFalse(line.contains("AUM"), "a host is named only where a device tried it: \(line)")
            XCTAssertFalse(line.contains("tried") || line.contains("tested"), line)
        }
        XCTAssertFalse(guide.untested.contains("AUM"), guide.untested)
    }

    /// What no device has tried stands beside the one sentence that a device allows, so the page
    /// never reads wider than it: every unit but the synthesizer, the free ones too, and every
    /// other host app.
    func testTheUntestedLineNamesEveryUnitButTheSynthesizer() {
        let guide = OwnPluginGuide()
        XCTAssertEqual(guide.untested, "Drums, Sampler, Effects and other host apps are not yet tested.")
        for unit in OwnPlugin.instruments + OwnPlugin.free where unit.id != OwnPlugin.synth.id {
            XCTAssertTrue(guide.untested.contains(unit.component.name), "\(unit.component.name) in: \(guide.untested)")
        }
        XCTAssertFalse(guide.untested.lowercased().contains("synth"), "the synthesizer is the one tried: \(guide.untested)")
    }

    func testAFourthUnitJoinsEveryLineWithoutAChangeOfThePage() {
        let guide = OwnPluginGuide(units: OwnPlugin.instruments + [unit("Voice", subtype: "eVoc")])
        XCTAssertEqual(guide.what, "Synth, Drums, Sampler and Voice as Audio Units for other apps. In Echoelmusic they are built in.")
        XCTAssertEqual(guide.howToLoad,
                       "In the other app, add an Audio Unit instrument and choose Synth, Drums, Sampler or Voice by Echoelmusic.")
        XCTAssertEqual(guide.tried, OwnPluginGuide().tried, "a new unit is not tried by being listed")
        XCTAssertEqual(guide.untested, "Drums, Sampler, Voice, Effects and other host apps are not yet tested.")
    }

    func testOneUnitReadsAsOneAndTwoAsAPair() {
        let one = OwnPluginGuide(units: [OwnPlugin.synth], free: [])
        XCTAssertEqual(one.what, "Synth as an Audio Unit for other apps. In Echoelmusic it is built in.")
        XCTAssertEqual(one.howToLoad, "In the other app, add an Audio Unit instrument and choose Synth by Echoelmusic.")
        XCTAssertEqual(one.untested, "Other host apps are not yet tested.", "the synthesizer alone: only the hosts")
        let two = OwnPluginGuide(units: [OwnPlugin.synth, OwnPlugin.drums], free: [])
        XCTAssertEqual(two.what, "Synth and Drums as Audio Units for other apps. In Echoelmusic they are built in.")
        XCTAssertEqual(two.howToLoad, "In the other app, add an Audio Unit instrument and choose Synth or Drums by Echoelmusic.")
        XCTAssertEqual(two.untested, "Drums and other host apps are not yet tested.")
    }

    func testTheMakerIsTheOneTheHostShows() {
        let guide = OwnPluginGuide()
        XCTAssertTrue(guide.howToLoad.hasSuffix("by \(OwnPlugin.synth.component.manufacturerName)."), guide.howToLoad)
    }

    func testNoUnitsReadAsTheOnesTheAppShips() {
        XCTAssertEqual(OwnPluginGuide(units: []), OwnPluginGuide(), "a page never shows a sentence with a hole in it")
    }

    func testNoLineSellsOrUsesAWordTheLanguageRuleForbids() {
        let banned = ["wellness", "therapy", "healing", "medical", "meditation", "relax", "auto-tune", "autotune", " ai ",
                      "purchase", "price", "buy", "sale"]
        for line in lines(of: OwnPluginGuide(units: OwnPlugin.instruments + [unit("Voice", subtype: "eVoc")])) {
            for word in banned {
                XCTAssertFalse((" " + line.lowercased() + " ").contains(word), "\(word) in: \(line)")
            }
        }
    }
}
