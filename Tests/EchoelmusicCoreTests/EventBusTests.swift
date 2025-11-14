import XCTest
@testable import EchoelmusicCore

final class EventBusTests: XCTestCase {

    @MainActor
    func testEventBusPublishSubscribe() async throws {
        let eventBus = EventBus.shared

        var receivedEvent: TestEvent?

        eventBus.subscribe(to: TestEvent.self) { event in
            receivedEvent = event
        }

        let testEvent = TestEvent(source: "test", message: "Hello")
        eventBus.publish(testEvent)

        // Give event time to propagate
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.message, "Hello")
    }
}

struct TestEvent: EventProtocol {
    let timestamp: Date = Date()
    let source: String
    let message: String
}
