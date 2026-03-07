#if canImport(AVFoundation)
// BusinessTests.swift
// Echoelmusic — Phase 4 Test Coverage: Business Logic
//
// Tests for EchoelProduct, EchoelEntitlement, EchoelStore,
// and AudioConfiguration types.

import XCTest
@testable import Echoelmusic

// MARK: - EchoelProduct Tests

final class EchoelProductTests: XCTestCase {

    func testAllCases() {
        let cases = EchoelProduct.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.proMonthly))
        XCTAssertTrue(cases.contains(.proYearly))
        XCTAssertTrue(cases.contains(.proLifetime))
    }

    func testSubscriptions() {
        let subs = EchoelProduct.subscriptions
        XCTAssertTrue(subs.contains(.proMonthly))
        XCTAssertTrue(subs.contains(.proYearly))
    }

    func testSubscriptionGroupID() {
        let groupID = EchoelProduct.subscriptionGroupID
        XCTAssertFalse(groupID.isEmpty)
    }
}

// MARK: - EchoelEntitlement Tests

final class EchoelEntitlementTests: XCTestCase {

    func testComparable() {
        XCTAssertTrue(EchoelEntitlement.free < .session)
        XCTAssertTrue(EchoelEntitlement.session < .pro)
    }

    func testRawValues() {
        XCTAssertEqual(EchoelEntitlement.free.rawValue, 0)
        XCTAssertEqual(EchoelEntitlement.session.rawValue, 1)
        XCTAssertEqual(EchoelEntitlement.pro.rawValue, 2)
    }
}

// MARK: - EchoelStore Tests

@MainActor
final class EchoelStoreTests: XCTestCase {

    func testSharedInstance() {
        let store = EchoelStore.shared
        XCTAssertNotNil(store)
    }

    func testInitialState() {
        let store = EchoelStore.shared
        XCTAssertEqual(store.entitlement, .free)
        XCTAssertFalse(store.isPurchasing)
    }

    func testIsPro() {
        let store = EchoelStore.shared
        // Default should be free
        XCTAssertFalse(store.isPro)
    }
}

// MARK: - LatencyMode Tests

final class LatencyModeTests: XCTestCase {

    func testBufferSizes() {
        XCTAssertEqual(AudioConfiguration.LatencyMode.ultraLow.bufferSize, 128)
        XCTAssertEqual(AudioConfiguration.LatencyMode.low.bufferSize, 256)
        XCTAssertEqual(AudioConfiguration.LatencyMode.normal.bufferSize, 512)
    }

    func testDescriptions() {
        for mode in [AudioConfiguration.LatencyMode.ultraLow, .low, .normal] {
            XCTAssertFalse(mode.description.isEmpty)
        }
    }
}

// MARK: - AudioConfiguration Tests

final class AudioConfigurationTests: XCTestCase {

    func testPreferredSampleRate() {
        XCTAssertEqual(AudioConfiguration.preferredSampleRate, 48000.0, accuracy: 0.1)
    }

    func testFallbackSampleRate() {
        XCTAssertEqual(AudioConfiguration.fallbackSampleRate, 44100.0, accuracy: 0.1)
    }

    func testBufferSizes() {
        XCTAssertEqual(AudioConfiguration.ultraLowLatencyBufferSize, 128)
        XCTAssertEqual(AudioConfiguration.lowLatencyBufferSize, 256)
        XCTAssertEqual(AudioConfiguration.normalBufferSize, 512)
    }

    func testIOBufferDuration() {
        let duration = AudioConfiguration.ioBufferDuration(for: 48000)
        // At 48kHz with default buffer: 512/48000 ≈ 0.0107s
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThan(duration, 0.1)
    }

    func testLatencyStats() {
        let stats = AudioConfiguration.latencyStats()
        XCTAssertFalse(stats.isEmpty)
    }
}

// MARK: - InstrumentOrchestrator.DrumType Tests

@MainActor
final class DrumTypeTests: XCTestCase {

    func testAllCases() {
        let cases = InstrumentOrchestrator.DrumType.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 10)
        XCTAssertTrue(cases.contains(.kick))
        XCTAssertTrue(cases.contains(.snare))
        XCTAssertTrue(cases.contains(.hiHatClosed))
        XCTAssertTrue(cases.contains(.hiHatOpen))
        XCTAssertTrue(cases.contains(.clap))
        XCTAssertTrue(cases.contains(.cowbell))
        XCTAssertTrue(cases.contains(.crash))
        XCTAssertTrue(cases.contains(.ride))
    }
}
#endif
