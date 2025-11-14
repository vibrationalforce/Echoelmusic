import XCTest
@testable import EchoelmusicBio

final class BioMappingGraphTests: XCTestCase {

    func testAddMapping() {
        let graph = BioMappingGraph()

        let mapping = BioMappingGraph.Mapping(
            bioSignal: .hrv,
            targetParameter: "filterCutoff",
            mappingCurve: .linear,
            intensity: 1.0
        )

        graph.addMapping(mapping)

        let mappings = graph.getMappings(for: .hrv)
        XCTAssertEqual(mappings.count, 1)
        XCTAssertEqual(mappings.first?.targetParameter, "filterCutoff")
    }

    func testApplyMappings() {
        let graph = BioMappingGraph()

        graph.addMapping(.init(
            bioSignal: .hrv,
            targetParameter: "reverb",
            mappingCurve: .linear,
            intensity: 1.0
        ))

        let bioValues: [BioMappingGraph.BioSignalType: Double] = [
            .hrv: 0.5
        ]

        let parameters = graph.applyMappings(bioValues: bioValues)

        XCTAssertNotNil(parameters["reverb"])
        XCTAssertEqual(parameters["reverb"], 0.5, accuracy: 0.01)
    }
}
