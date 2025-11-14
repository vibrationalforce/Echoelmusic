import XCTest
@testable import EchoelmusicCore

final class StateGraphTests: XCTestCase {

    enum TestState: Hashable, Sendable {
        case idle
        case running
        case paused
        case stopped
    }

    func testStateTransition() {
        let graph = StateGraph<TestState>(initialState: .idle)

        // Define allowed transitions
        graph.allow(from: .idle, to: .running)
        graph.allow(from: .running, to: .paused)
        graph.allow(from: .paused, to: .running)
        graph.allow(from: .running, to: .stopped)

        XCTAssertEqual(graph.currentState, .idle)

        // Allowed transition should succeed
        XCTAssertTrue(graph.transition(to: .running))
        XCTAssertEqual(graph.currentState, .running)

        // Disallowed transition should fail
        XCTAssertFalse(graph.transition(to: .idle))
        XCTAssertEqual(graph.currentState, .running)

        // Allowed transition should succeed
        XCTAssertTrue(graph.transition(to: .paused))
        XCTAssertEqual(graph.currentState, .paused)
    }
}
