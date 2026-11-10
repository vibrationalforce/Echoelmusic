import EchoelCore
import EchoelEngine
import Foundation
import Observation
import os
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health's heart rate as a body source (REC-1): what an Apple Watch, or another device that
/// writes to Health, measured. Off until the musician chooses it; only then does iOS ask, and it
/// asks to READ heart rate and nothing else — Echoel never writes to Health. The value never leaves
/// the device: Connections never read this class, and the modulation cell carries it as private,
/// so MIDI out sends nothing for it and the live stream's picture shows no pulse for it
/// (`ModulationInputs.shareableValue`, `FieldFrame.streamed`).
///
/// A Watch reading arrives 4 to 5 seconds late and, at rest, minutes apart, so this source is slow
/// modulation only: it glides over seconds, feeds the heart-rate source alone, and never sets the
/// beat (Flow does not follow it). A reading older than `HealthPulse.freshSeconds` by its
/// MEASUREMENT time reads as not measured (`HealthPulse`, `BodyChannel`).
@MainActor
@Observable
final class HealthHeartRate {
    enum Status: Equatable {
        case off
        /// No Health on this device, or this build carries no permission text.
        case unavailable
        case asking
        /// Asked; no recent reading. iOS does not say whether reading was allowed, so this is also
        /// what a refusal looks like.
        case waiting
        case measuring
    }

    private(set) var status: Status = .off
    private(set) var pulse = BodyChannel(maximumAgeMilliseconds: HealthPulse.freshMilliseconds)
    /// The last measured rate, only while `pulse` holds a value.
    private(set) var beatsPerMinute: Int?
    /// The sources this class feeds right now (heart rate or nothing). Changes only when the pulse
    /// starts or stops being measured, so a menu may read it (Law 6).
    private(set) var measuring: Set<ModulationSource> = []

    /// Slow on purpose: the reading is seconds old when it arrives.
    static let glideSeconds = 4.0
    static let glideStepSeconds = 1.0 / 15

    @ObservationIgnored var output: ModulationInputs?
    @ObservationIgnored private var run: UInt64 = 0
    @ObservationIgnored private var sequence: Int64 = 0
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var glide: Task<Void, Never>?
    @ObservationIgnored private var gliding: Double?
    @ObservationIgnored private let started = ContinuousClock.now
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "body")
    #if canImport(HealthKit)
    @ObservationIgnored private var health: HKHealthStore?
    @ObservationIgnored private var query: HKAnchoredObjectQuery?
    #endif

    var isOn: Bool { status != .off }

    /// iOS ends the app at the first Health request when the build carries no reason text, so
    /// nothing is asked without it.
    static var hasUsageDescription: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String)?.isEmpty == false
    }

    /// The musician chose Apple Health.
    func start() {
        guard !isOn else { return }
        run &+= 1
        apply(.start(.health, .unknown))
        #if canImport(HealthKit)
        guard Self.hasUsageDescription, HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            status = .unavailable
            return
        }
        status = .asking
        let health = self.health ?? HKHealthStore()
        self.health = health
        let current = run
        let answered: @Sendable (Bool, (any Error)?) -> Void = { [weak self] success, _ in
            Task { @MainActor [weak self] in self?.authorized(success, run: current) }
        }
        health.requestAuthorization(toShare: nil, read: [type], completion: answered)
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.apply(.tick)
            }
        }
        glide = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.glideStepSeconds))
                self?.glideTowardsPulse()
            }
        }
        #else
        status = .unavailable
        #endif
    }

    /// The musician chose another source or Off: the query ends and the value is gone.
    func stop() {
        guard isOn else { return }
        run &+= 1
        ticker?.cancel()
        glide?.cancel()
        ticker = nil
        glide = nil
        #if canImport(HealthKit)
        if let query, let health { health.stop(query) }
        query = nil
        #endif
        gliding = nil
        measuring = []
        output?.set(.heartRate, nil, mayLeaveDevice: false)
        apply(.stop)
        status = .off
    }

    // MARK: - Steps

    /// The producer's clock, ahead of zero so a reading from before the app started is old, not
    /// negative (`HealthPulse.clockLeadMilliseconds`).
    private var nowMilliseconds: Int64 {
        let elapsed = ContinuousClock.now - started
        return HealthPulse.clockLeadMilliseconds + elapsed.components.seconds * 1_000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }

    private func apply(_ event: BodyChannel.Event) {
        do {
            _ = try pulse.step(event, at: nowMilliseconds)
        } catch {
            log.error("body clock went back — \(String(describing: error), privacy: .public)")
        }
        if pulse.value == nil {
            beatsPerMinute = nil
            if status == .measuring { status = .waiting }
        }
    }

    private func glideTowardsPulse() {
        guard let target = pulse.value else {
            if gliding != nil {
                gliding = nil
                output?.set(.heartRate, nil, mayLeaveDevice: false)
            }
            if !measuring.isEmpty { measuring = [] }
            return
        }
        let factor = 1 - Foundation.exp(-Self.glideStepSeconds / Self.glideSeconds)
        let next = gliding.map { $0 + (target - $0) * factor } ?? target
        gliding = next
        output?.set(.heartRate, next, mayLeaveDevice: false)
        if measuring != [.heartRate] { measuring = [.heartRate] }
    }

    private func received(beatsPerMinute bpm: Double, measuredAt end: Date, run current: UInt64) {
        guard isOn, current == run else { return }
        sequence += 1
        let sample = HealthPulse.sample(beatsPerMinute: bpm, measuredSecondsAgo: Date().timeIntervalSince(end),
                                        nowMilliseconds: nowMilliseconds, epoch: pulse.epoch, sequence: sequence)
        apply(.sample(sample))
        if pulse.value != nil {
            beatsPerMinute = Int(bpm.rounded())
            status = .measuring
        }
    }

    #if canImport(HealthKit)
    private func authorized(_ success: Bool, run current: UInt64) {
        guard isOn, current == run, let health,
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        guard success else {
            log.error("health: authorization request failed")
            status = .unavailable
            return
        }
        status = .waiting
        let deliver: @Sendable (Double, Date) -> Void = { [weak self] bpm, end in
            Task { @MainActor [weak self] in self?.received(beatsPerMinute: bpm, measuredAt: end, run: current) }
        }
        let heartQuery = HealthHeartRateQuery.make(type: type, deliver: deliver)
        health.execute(heartQuery)
        query = heartQuery
    }
    #endif
}

#if canImport(HealthKit)
/// The anchored query, outside the main actor: HealthKit calls its handlers on a queue of its own,
/// so they are `@Sendable` and hand only plain numbers to the main actor.
enum HealthHeartRateQuery {
    static func make(type: HKQuantityType, deliver: @escaping @Sendable (Double, Date) -> Void) -> HKAnchoredObjectQuery {
        let since = Date().addingTimeInterval(-HealthPulse.freshSeconds)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, (any Error)?) -> Void = {
            _, samples, _, _, _ in
            guard let reading = HealthHeartRateQuery.newest(samples) else { return }
            deliver(reading.beatsPerMinute, reading.end)
        }
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit,
                                          resultsHandler: handler)
        query.updateHandler = handler
        return query
    }

    /// The newest heart-rate reading of a batch: the only one that can still move anything.
    static func newest(_ samples: [HKSample]?) -> (beatsPerMinute: Double, end: Date)? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        var best: (beatsPerMinute: Double, end: Date)?
        for case let sample as HKQuantitySample in samples ?? [] {
            guard sample.quantity.is(compatibleWith: unit) else { continue }
            if let current = best, current.end >= sample.endDate { continue }
            best = (sample.quantity.doubleValue(for: unit), sample.endDate)
        }
        return best
    }
}
#endif
