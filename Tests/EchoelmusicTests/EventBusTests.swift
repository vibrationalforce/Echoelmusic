// EventBusTests.swift
// Echoelmusic - EventBus Test Suite
// Wise Mode Implementation

import XCTest
import Combine
@testable import Echoelmusic

@MainActor
final class EventBusTests: XCTestCase {

    // MARK: - Properties

    var eventBus: EventBus!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        eventBus = EventBus.shared
        eventBus.clearHistory()
        eventBus.unsubscribeAll()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        eventBus.clearHistory()
        eventBus.unsubscribeAll()
        super.tearDown()
    }

    // MARK: - Basic Event Tests

    func testEmitEvent() {
        var received = false

        _ = eventBus.subscribe { event in
            if case .audioEngineStarted = event {
                received = true
            }
        }

        eventBus.emit(.audioEngineStarted)

        // Allow main queue to process
        let expectation = XCTestExpectation(description: "Event received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(received)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testEventHistory() {
        eventBus.emit(.audioEngineStarted)
        eventBus.emit(.audioEngineStopped)
        eventBus.emit(.audioLevelChanged(0.5))

        let history = eventBus.getHistory()
        XCTAssertEqual(history.count, 3)
    }

    func testClearHistory() {
        eventBus.emit(.audioEngineStarted)
        eventBus.emit(.audioEngineStopped)

        eventBus.clearHistory()

        let history = eventBus.getHistory()
        XCTAssertEqual(history.count, 0)
    }

    // MARK: - Subscription Tests

    func testSubscribeWithMatching() {
        var receivedLevel: Float?

        _ = eventBus.subscribe(matching: { event -> Float? in
            if case .audioLevelChanged(let level) = event { return level }
            return nil
        }, handler: { level in
            receivedLevel = level
        })

        eventBus.emit(.audioLevelChanged(0.75))

        let expectation = XCTestExpectation(description: "Level received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedLevel, 0.75)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testUnsubscribe() {
        var callCount = 0

        let subscriptionId = eventBus.subscribe { _ in
            callCount += 1
        }

        eventBus.emit(.audioEngineStarted)

        let expectation1 = XCTestExpectation(description: "First event")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(callCount, 1)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)

        eventBus.unsubscribe(subscriptionId)
        eventBus.emit(.audioEngineStarted)

        let expectation2 = XCTestExpectation(description: "After unsubscribe")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(callCount, 1, "Should not receive events after unsubscribe")
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
    }

    // MARK: - Convenience Subscriber Tests

    func testOnAudioLevel() {
        var receivedLevel: Float?

        _ = eventBus.onAudioLevel { level in
            receivedLevel = level
        }

        eventBus.emit(.audioLevelChanged(0.5))

        let expectation = XCTestExpectation(description: "Audio level")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedLevel, 0.5)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnMIDINoteOn() {
        var receivedNote: UInt8?
        var receivedVelocity: UInt8?
        var receivedChannel: UInt8?

        _ = eventBus.onMIDINoteOn { note, velocity, channel in
            receivedNote = note
            receivedVelocity = velocity
            receivedChannel = channel
        }

        eventBus.emit(.midiNoteOn(note: 60, velocity: 100, channel: 1))

        let expectation = XCTestExpectation(description: "MIDI note on")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedNote, 60)
            XCTAssertEqual(receivedVelocity, 100)
            XCTAssertEqual(receivedChannel, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnHeartRate() {
        var receivedBPM: Double?

        _ = eventBus.onHeartRate { bpm in
            receivedBPM = bpm
        }

        eventBus.emit(.heartRateUpdated(bpm: 72.5))

        let expectation = XCTestExpectation(description: "Heart rate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedBPM, 72.5)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnGesture() {
        var receivedGesture: GestureEventType?

        _ = eventBus.onGesture { gesture in
            receivedGesture = gesture
        }

        eventBus.emit(.gestureRecognized(.pinch))

        let expectation = XCTestExpectation(description: "Gesture")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedGesture, .pinch)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnError() {
        var receivedDomain: String?
        var receivedMessage: String?

        _ = eventBus.onError { domain, message in
            receivedDomain = domain
            receivedMessage = message
        }

        eventBus.emit(.errorOccurred(domain: "Audio", message: "Buffer underrun"))

        let expectation = XCTestExpectation(description: "Error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(receivedDomain, "Audio")
            XCTAssertEqual(receivedMessage, "Buffer underrun")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Event Equality Tests

    func testEventEquality() {
        XCTAssertEqual(AppEvent.audioEngineStarted, AppEvent.audioEngineStarted)
        XCTAssertEqual(AppEvent.audioEngineStopped, AppEvent.audioEngineStopped)
        XCTAssertEqual(AppEvent.audioLevelChanged(0.5), AppEvent.audioLevelChanged(0.5))
        XCTAssertNotEqual(AppEvent.audioLevelChanged(0.5), AppEvent.audioLevelChanged(0.6))

        XCTAssertEqual(
            AppEvent.midiNoteOn(note: 60, velocity: 100, channel: 1),
            AppEvent.midiNoteOn(note: 60, velocity: 100, channel: 1)
        )
        XCTAssertNotEqual(
            AppEvent.midiNoteOn(note: 60, velocity: 100, channel: 1),
            AppEvent.midiNoteOn(note: 61, velocity: 100, channel: 1)
        )
    }

    // MARK: - Gesture Event Type Tests

    func testAllGestureTypes() {
        let gestures: [GestureEventType] = [
            .pinch, .spread, .fist, .point,
            .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
            .rotate, .tap, .doubleTap, .longPress
        ]

        XCTAssertEqual(gestures.count, 12)

        for gesture in gestures {
            XCTAssertFalse(gesture.rawValue.isEmpty)
        }
    }

    // MARK: - Multiple Events Tests

    func testEmitMultipleEvents() {
        var eventCount = 0

        _ = eventBus.subscribe { _ in
            eventCount += 1
        }

        let events: [AppEvent] = [
            .audioEngineStarted,
            .audioLevelChanged(0.5),
            .midiNoteOn(note: 60, velocity: 100, channel: 1),
            .heartRateUpdated(bpm: 72),
            .audioEngineStopped
        ]

        eventBus.emit(events)

        let expectation = XCTestExpectation(description: "Multiple events")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(eventCount, 5)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - History Filtering Tests

    func testHistoryFiltering() {
        eventBus.emit(.audioEngineStarted)
        eventBus.emit(.midiNoteOn(note: 60, velocity: 100, channel: 1))
        eventBus.emit(.audioLevelChanged(0.5))
        eventBus.emit(.midiNoteOff(note: 60, channel: 1))
        eventBus.emit(.audioEngineStopped)

        let midiEvents = eventBus.getHistory { event in
            switch event {
            case .midiNoteOn, .midiNoteOff, .midiControlChange, .midiPitchBend:
                return true
            default:
                return false
            }
        }

        XCTAssertEqual(midiEvents.count, 2)
    }
}

// MARK: - Performance Tests

extension EventBusTests {

    func testEventEmissionPerformance() {
        measure {
            for i in 0..<1000 {
                eventBus.emit(.audioLevelChanged(Float(i) / 1000.0))
            }
        }
    }

    func testHistoryAccessPerformance() {
        // Populate history
        for i in 0..<500 {
            eventBus.emit(.audioLevelChanged(Float(i) / 500.0))
        }

        measure {
            for _ in 0..<100 {
                _ = eventBus.getHistory(limit: 100)
            }
        }
    }
}
