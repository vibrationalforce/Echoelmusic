import EchoelCore
import EchoelHost
import XCTest

final class InstrumentStateTests: XCTestCase {
    /// A host session saved with the earlier app's instrument opens the synth at its defaults
    /// instead of replaying that instrument's values onto unrelated synth parameters (audit
    /// 2026-10-23); a state this app wrote, and every other instrument's, comes back whole.
    func testAnEarlierAppSessionUnderEchlOpensTheSynthAtItsDefaults() {
        let echl = OwnPlugin.legacyBodyVibe.component.subtype
        let earlier: [String: Any] = ["subtype": Int(echl), "data": Data([1, 2, 3]), "name": "Body"]
        let opened = InstrumentState.forBaseRestore(earlier, subtype: echl)
        XCTAssertNil(opened?["data"], "the earlier instrument's values by address are not replayed")
        XCTAssertEqual(opened?["name"] as? String, "Body", "the rest of the state passes")

        var ours = earlier
        ours[InstrumentState.markerKey] = 1
        XCTAssertEqual(InstrumentState.forBaseRestore(ours, subtype: echl)?["data"] as? Data, Data([1, 2, 3]),
                       "a state this app wrote keeps its values")
        XCTAssertEqual(InstrumentState.forBaseRestore(earlier, subtype: OwnPlugin.synth.component.subtype)?["data"] as? Data,
                       Data([1, 2, 3]), "only the echl door drops the snapshot")
        XCTAssertNil(InstrumentState.forBaseRestore(nil, subtype: echl))
    }
}
