import EchoelCore
import XCTest
@testable import EchoelEngine

final class ModulationInputsTests: XCTestCase {
    func testEverySourceStartsAbsent() {
        let inputs = ModulationInputs()
        for source in ModulationSource.allCases { XCTAssertNil(inputs.value(source), source.rawValue) }
    }

    func testAMeasurementIsReadBackAndClearedOnNil() {
        let inputs = ModulationInputs()
        inputs.set(.heartRate, 0.4)
        inputs.set(.breath, 1)
        XCTAssertEqual(inputs.value(.heartRate), 0.4)
        XCTAssertEqual(inputs.value(.breath), 1)
        XCTAssertNil(inputs.value(.hrv), "one source does not fill another")
        inputs.set(.heartRate, nil)
        XCTAssertNil(inputs.value(.heartRate), "a stopped source is absent again")
        inputs.clear()
        XCTAssertNil(inputs.value(.breath))
    }

    /// G-A M09: a value out of the domain is absent, not clamped into the strongest swing.
    func testAValueOutsideZeroToOneIsAbsent() {
        let inputs = ModulationInputs()
        for bad in [-0.01, 1.01, .nan, .infinity] {
            inputs.set(.coherence, 0.5)
            inputs.set(.coherence, bad)
            XCTAssertNil(inputs.value(.coherence), "\(bad)")
        }
    }

    func testTheIndexIsTheSourcesPlaceInTheList() {
        let inputs = ModulationInputs()
        inputs.set(.macro1, 0.25)
        let index = ModulationInputs.index(.macro1)
        XCTAssertEqual(index.flatMap { inputs.value(at: $0) }, 0.25)
        XCTAssertNil(inputs.value(at: -1))
        XCTAssertNil(inputs.value(at: ModulationSource.allCases.count))
    }
}
