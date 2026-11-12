import Foundation
import XCTest
@testable import EchoelCore

/// What the plugin browser lists: Echoel first, then recent, then the installed units by maker.
final class PluginCatalogFilterTests: XCTestCase {
    private func unit(_ name: String, maker: String, subtype: String) -> PluginComponent {
        PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code(subtype),
                        manufacturer: PluginComponent.code(String(maker.prefix(4)).padding(toLength: 4, withPad: "x",
                                                                                         startingAt: 0)),
                        name: name, manufacturerName: maker)
    }

    private var echoelEQ: PluginComponent { StandardEffect.equalizer.component }
    private var echoelDelay: PluginComponent { StandardEffect.delay.component }

    private lazy var shimmer = unit("Shimmer", maker: "Zeta Audio", subtype: "shim")
    private lazy var crusher = unit("Crusher", maker: "Zeta Audio", subtype: "crsh")
    private lazy var amp = unit("Amp Room", maker: "Alpha Labs", subtype: "ampr")
    private lazy var echo = unit("Échoes", maker: "Beta", subtype: "echs")

    private func titles(_ sections: [PluginCatalogFilter.Section]) -> [String] { sections.map(\.title) }

    private func names(_ section: PluginCatalogFilter.Section?) -> [String] { section?.components.map(\.name) ?? [] }

    /// Without a search: Echoel's own in their order, nothing recent yet, the makers alphabetical
    /// and their units alphabetical within.
    /// A unit the component manager did not report but the direct scan found is in the catalogue:
    /// a device that answers the manager with Apple's units alone still lists the others.
    func testTheCatalogueTakesAUnitTheManagerMissedFromTheScan() {
        let apple = unit("AUDelay", maker: "Apple", subtype: "dely")
        let catalogue = PluginCatalogFilter.catalogue(managed: [apple], scanned: [apple, shimmer, amp])
        XCTAssertEqual(catalogue.map(\.name), ["Amp Room", "AUDelay", "Shimmer"])
    }

    /// A unit both readings found is listed once, under the names the component manager gave it.
    func testAUnitBothReadingsFindIsListedOnceWithTheManagersNames() {
        var scannedShimmer = shimmer
        scannedShimmer.name = "shimmer (scan)"
        scannedShimmer.manufacturerName = "ZETA"
        let catalogue = PluginCatalogFilter.catalogue(managed: [shimmer], scanned: [scannedShimmer])
        XCTAssertEqual(catalogue, [shimmer])
    }

    /// Echoel's own units are never in the catalogue, whichever reading reports them: the app
    /// plays them itself.
    func testTheCatalogueLeavesEchoelsOwnUnitsOut() {
        var own = unit("Echoelmusic: Synth", maker: "Echoelmusic", subtype: "eSyn")
        own.manufacturer = PluginCatalogFilter.ownManufacturer
        let catalogue = PluginCatalogFilter.catalogue(managed: [own, crusher], scanned: [own])
        XCTAssertEqual(catalogue, [crusher])
    }

    /// The system names a registered component "Maker: Name"; the scan splits it at the first
    /// separator, and a name without one is all name.
    func testAFullNameSplitsIntoMakerAndName() {
        XCTAssertTrue(PluginCatalogFilter.split(fullName: "Moog Music: Model D") == ("Moog Music", "Model D"))
        XCTAssertTrue(PluginCatalogFilter.split(fullName: "Lab: Delay: Tape") == ("Lab", "Delay: Tape"))
        XCTAssertTrue(PluginCatalogFilter.split(fullName: "Plain Name") == ("", "Plain Name"))
        XCTAssertTrue(PluginCatalogFilter.split(fullName: "Maker: ") == ("", "Maker:"))
    }

    func testEchoelComesFirstThenTheMakersAlphabetically() {
        let sections = PluginCatalogFilter.sections(installed: [shimmer, amp, crusher, echo], own: [echoelEQ, echoelDelay],
                                                    recents: [], query: "")
        XCTAssertEqual(titles(sections), ["Echoelmusic", "Alpha Labs", "Beta", "Zeta Audio"])
        XCTAssertEqual(names(sections.first), ["Echoel EQ", "Echoel Delay"], "Echoel's own keep their order")
        XCTAssertEqual(names(sections.last), ["Crusher", "Shimmer"])
        let kinds: [PluginCatalogFilter.Section.Kind] = [.own, .maker("Alpha Labs"), .maker("Beta"), .maker("Zeta Audio")]
        XCTAssertEqual(sections.map(\.kind), kinds)
    }

    /// The search reads name and maker, every word, ignoring case and accents; a section with
    /// nothing left goes.
    func testTheSearchMatchesNameAndMaker() {
        let all = [shimmer, amp, crusher, echo]
        let byName = PluginCatalogFilter.sections(installed: all, own: [echoelEQ], recents: [], query: "  shim ")
        XCTAssertEqual(titles(byName), ["Zeta Audio"])
        XCTAssertEqual(names(byName.first), ["Shimmer"])

        let byMaker = PluginCatalogFilter.sections(installed: all, own: [echoelEQ], recents: [], query: "ZETA")
        XCTAssertEqual(names(byMaker.first), ["Crusher", "Shimmer"])

        XCTAssertEqual(names(PluginCatalogFilter.sections(installed: all, recents: [], query: "echoes").first), ["Échoes"])
        XCTAssertEqual(titles(PluginCatalogFilter.sections(installed: all, own: [echoelEQ], recents: [], query: "eq")), ["Echoelmusic"])
        XCTAssertTrue(PluginCatalogFilter.sections(installed: all, own: [echoelEQ], recents: [], query: "zeta amp").isEmpty,
                      "every word must match one unit")
        XCTAssertTrue(PluginCatalogFilter.matches(amp, query: "alpha room"))
        XCTAssertFalse(PluginCatalogFilter.matches(amp, query: "beta"))
    }

    /// The recent list puts the last one used first, keeps one entry per unit and at most eight.
    func testRecentsAreMostRecentFirstAndCappedAtEight() {
        var recents: [PluginComponent] = []
        recents = PluginCatalogFilter.recording(amp, in: recents)
        recents = PluginCatalogFilter.recording(shimmer, in: recents)
        recents = PluginCatalogFilter.recording(amp, in: recents)
        XCTAssertEqual(recents.map(\.name), ["Amp Room", "Shimmer"])

        let many = (0..<12).map { unit("Unit \($0)", maker: "Gamma", subtype: String(format: "u%03d", $0)) }
        for component in many { recents = PluginCatalogFilter.recording(component, in: recents) }
        XCTAssertEqual(recents.count, PluginCatalogFilter.recentLimit)
        XCTAssertEqual(recents.first?.name, "Unit 11")
        XCTAssertEqual(recents.last?.name, "Unit 4")
    }

    /// The recent section shows the recent units still installed, newest first, under the search,
    /// with the catalogue's names; they stay in their maker's section too.
    func testTheRecentSectionShowsWhatIsStillInstalled() {
        let gone = unit("Removed", maker: "Delta", subtype: "gone")
        var renamed = shimmer
        renamed.name = "Shimmer (old name)"
        let sections = PluginCatalogFilter.sections(installed: [shimmer, amp, crusher], own: [echoelEQ],
                                                    recents: [crusher, gone, renamed, echoelEQ], query: "")
        XCTAssertEqual(titles(sections), ["Echoelmusic", "Recent", "Alpha Labs", "Zeta Audio"])
        XCTAssertEqual(names(sections[1]), ["Crusher", "Shimmer", "Echoel EQ"])
        XCTAssertEqual(names(sections[3]), ["Crusher", "Shimmer"])

        let searched = PluginCatalogFilter.sections(installed: [shimmer, amp, crusher], recents: [crusher, shimmer], query: "shim")
        XCTAssertEqual(titles(searched), ["Recent", "Zeta Audio"])
        XCTAssertEqual(names(searched.first), ["Shimmer"])

        let full = (0..<10).map { unit("Unit \($0)", maker: "Gamma", subtype: String(format: "u%03d", $0)) }
        let capped = PluginCatalogFilter.sections(installed: full, recents: full, query: "")
        XCTAssertEqual(capped.first?.components.count, PluginCatalogFilter.recentLimit)
    }

    /// An installed unit with Echoel's manufacturer joins Echoel's section, not a maker's; a unit
    /// that names no maker is grouped under "Other".
    func testEchoelsOwnInstalledUnitsAndUnnamedMakersFindTheirSections() {
        let nameless = PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("nnmd"),
                                       manufacturer: PluginComponent.code("Anon"), name: "Plain", manufacturerName: " ")
        let sections = PluginCatalogFilter.sections(installed: [echoelDelay, nameless], own: [echoelEQ], recents: [], query: "")
        XCTAssertEqual(titles(sections), ["Echoelmusic", "Other"])
        XCTAssertEqual(names(sections.first), ["Echoel EQ", "Echoel Delay"])
        XCTAssertEqual(PluginCatalogFilter.makerName(nameless), "Other")
    }
}
