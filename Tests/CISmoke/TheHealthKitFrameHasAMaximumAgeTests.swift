// TheHealthKitFrameHasAMaximumAgeTests.swift
// Echoel — #1215 (audit 2026-09-10 `bio-pipeline-2`). A HealthKit heart-rate sample older than
// `HealthKitBioPublisher.maxMeasurementAge` is not published as the body.
//
// THE RISK. The anchored query's initial batch can deliver the newest sample of the last HOUR.
// The bridge stamps RECEIPT time (right, #98c2: a resting Watch writes every ~3 min and the
// 90 s `usableBio` window must not drop it), but that same stamp made a 45-minute-old number a
// "live" pulse on the strip and the composer's body for 90 s. Nothing distinguished the two.
//
// WHAT THIS PINS. (1) A 45-minute-old snapshot publishes NOTHING. (2) COUNTERWEIGHT — the
// 180 s resting-Watch case still publishes (the #98c2 contract, pinned in the non-blocking
// suite, restated here so the ceiling can never be tightened past the design case). (3) The
// constant is above 180 s and below one hour, by value.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`2b387b3`) and this tree: claim 1
// RED on the parent (no age gate — the frame reaches the bus), GREEN here; claims 2 and 3 green
// on both trees (claim 3's constant does not exist on the parent; its transcription reads the
// 180 s design case as the only bound there).
//
// ⚠️ THE LIMIT. Ten minutes is a judgment value; whether the Watch's resting cadence makes the
// strip look empty too often is the founder's device look (marker on the constant).

#if canImport(HealthKit)
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheHealthKitFrameHasAMaximumAgeTests: XCTestCase {

    private func awaitLatestBio(_ bus: EngineBus, tries: Int = 40) async -> BioSampleFrame? {
        for _ in 0..<tries {
            if let f = bus.latestBio { return f }
            await Task.yield()
        }
        return bus.latestBio
    }

    private func publish(ageSeconds: TimeInterval) async -> BioSampleFrame? {
        let engine = EchoelBioEngine.shared
        let savedSource = engine.dataSource
        let savedSnap = engine.snapshot
        let savedHasHR = engine.hasHRSample
        defer { engine.dataSource = savedSource; engine.snapshot = savedSnap
                engine.hasHRSample = savedHasHR }
        engine.hasHRSample = true
        var snap = BioSnapshot()
        snap.heartRate = 63
        snap.timestamp = Date(timeIntervalSinceNow: -ageSeconds)
        engine.dataSource = .healthKit
        engine.snapshot = snap
        let bus = EngineBus()
        HealthKitBioPublisher(engine: engine).publishIfFresh(to: bus)
        return await awaitLatestBio(bus, tries: 8)
    }

    /// Claim 1 — a 45-minute-old sample is not the body.
    func testAFortyFiveMinuteOldSampleIsNotPublished() async {
        let f = await publish(ageSeconds: 45 * 60)
        XCTAssertNil(f, "a 45-minute-old HealthKit sample reached the bus as a live frame (#1215)")
    }

    /// Claim 2 — counterweight: the 180 s resting-Watch case still publishes (#98c2).
    func testTheRestingWatchCaseStillPublishes() async {
        let f = await publish(ageSeconds: 180)
        XCTAssertNotNil(f, "the 180 s resting-Watch reading must still publish — the age " +
                           "ceiling was tightened past the #98c2 design case (#1215)")
        XCTAssertEqual(f?.heartRateBPM ?? 0, 63, accuracy: 0.5)
    }

    /// Claim 3 — the ceiling sits between the design case and the query's hour.
    func testTheCeilingSitsBetweenTheDesignCaseAndTheHour() {
        XCTAssertGreaterThan(HealthKitBioPublisher.maxMeasurementAge, 180)
        XCTAssertLessThan(HealthKitBioPublisher.maxMeasurementAge, 3600)
    }
}
#endif
