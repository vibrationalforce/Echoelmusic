import CoreMotion
import EchoelCore
import EchoelEngine
import Foundation
import Observation
import Synchronization
import os

/// The iPhone itself as a body source (Recovery 9): its tilt, its turning and how much it is moved
/// become four modulation sources (`PhoneMotion`). Off until the musician turns it on in the Body
/// Source menu; it runs beside the pulse source rather than instead of it, because it feeds other
/// modulation cells — one producer per source still holds.
///
/// CoreMotion samples at 60 Hz on an operation queue of this class's own. Each sample goes straight
/// from that queue into the lock-free modulation cells: no hop to the main actor per sample (the
/// 10.76.48 lesson). The main actor only starts, stops, and four times a second looks whether
/// samples still arrive — that is all `measuring` follows, so a menu may read it (Law 6).
///
/// Device motion needs no permission and asks nothing. Provenance is the camera's and the strap's
/// (`BioEgressPolicy.allowsEgress(.motion)`): measured here, so the values may leave the device —
/// but only through a route the musician makes. Connections send no motion on their own.
@MainActor
@Observable
final class PhoneMotionSource {
    enum Status: Equatable {
        case off
        /// This device has no motion sensors.
        case unavailable
        /// On; no sample yet, or none for a while.
        case waiting
        case measuring
    }

    private(set) var status: Status = .off
    /// The sources this class feeds right now: all four or none. Changes only when samples start
    /// or stop arriving.
    private(set) var measuring: Set<ModulationSource> = []

    nonisolated static let sampleInterval = 1.0 / 60
    /// No sample for this long and the four sources are absent until samples come back.
    nonisolated static let staleSeconds = 0.5

    @ObservationIgnored var output: ModulationInputs?
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.echoelmusic.studio.body.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    @ObservationIgnored private var processor: PhoneMotionProcessor?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "body")

    var isOn: Bool { status != .off }

    /// The musician turned Phone Motion on.
    func start() {
        guard !isOn else { return }
        guard motion.isDeviceMotionAvailable else {
            status = .unavailable
            log.notice("motion: no device motion on this device")
            return
        }
        let processor = PhoneMotionProcessor(output: output)
        self.processor = processor
        status = .waiting
        motion.deviceMotionUpdateInterval = Self.sampleInterval
        // Roll and pitch need no north; `.xArbitraryZVertical` asks for no compass.
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue,
                                        withHandler: PhoneMotionProcessor.handler(processor, run: processor.currentRun))
        ticker = Task { @MainActor [weak self] in
            var seen: UInt64 = 0
            var quietTicks = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, let processor = self.processor else { return }
                let count = processor.sampleCount
                quietTicks = count == seen ? quietTicks + 1 : 0
                seen = count
                self.samplesArrive(quietTicks * 250 < Int(Self.staleSeconds * 1_000), count: count)
            }
        }
    }

    /// The musician turned it off, or chose Off: the sensor stops and the four values are gone.
    func stop() {
        guard isOn else { return }
        ticker?.cancel()
        ticker = nil
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        if let processor {
            // A sample already on the queue is from the run that just ended and writes nothing;
            // the clearing runs after it on the same serial queue, so nothing lands after the clear.
            processor.endRun()
            queue.addOperation { @Sendable in processor.clear() }
        }
        processor = nil
        for source in PhoneMotion.sources { output?.set(source, nil) }
        measuring = []
        status = .off
    }

    private func samplesArrive(_ fresh: Bool, count: UInt64) {
        guard isOn, let processor else { return }
        if fresh, count > 0 {
            if status != .measuring { status = .measuring }
            if measuring.isEmpty { measuring = Set(PhoneMotion.sources) }
        } else {
            if status == .measuring { status = .waiting }
            if !measuring.isEmpty {
                measuring = []
                // The cells belong to the queue while it runs; it clears them, and starts afresh.
                queue.addOperation { @Sendable in processor.clear() }
            }
        }
    }
}

/// What runs on the motion queue: the smoothing state and the run token. Every method but
/// `endRun`, `currentRun` and `sampleCount` is called only on that serial queue, so `motion` has one
/// thread; the token and the counter are atomics the main actor reads.
final class PhoneMotionProcessor: @unchecked Sendable {
    private let output: ModulationInputs?
    private var motion = PhoneMotion()
    private let run = Atomic<UInt64>(1)
    private let samples = Atomic<UInt64>(0)
    /// Measured on this device, like the camera and the strap.
    private let mayLeaveDevice = BioEgressPolicy.allowsEgress(.motion)

    init(output: ModulationInputs?) {
        self.output = output
    }

    var currentRun: UInt64 { run.load(ordering: .relaxed) }
    var sampleCount: UInt64 { samples.load(ordering: .relaxed) }

    /// The run is over: samples it already queued write nothing.
    func endRun() {
        _ = run.wrappingAdd(1, ordering: .relaxed)
    }

    /// One sample, on the queue.
    func take(_ reading: PhoneMotion.Reading, run token: UInt64) {
        guard run.load(ordering: .relaxed) == token else { return }
        let values = motion.take(reading)
        for source in PhoneMotion.sources {
            output?.set(source, values.value(for: source), mayLeaveDevice: mayLeaveDevice)
        }
        _ = samples.wrappingAdd(1, ordering: .relaxed)
    }

    /// The four sources absent, and the next sample starts afresh. On the queue.
    func clear() {
        motion.reset()
        for source in PhoneMotion.sources { output?.set(source, nil) }
    }

    /// The handler CoreMotion calls on the motion queue. Built outside the main actor and
    /// `@Sendable`, so it carries no main-actor isolation check into that queue
    /// (`.claude/rules/swift-audio.md`); it hands plain numbers to `take` and nothing else.
    nonisolated static func handler(_ processor: PhoneMotionProcessor, run token: UInt64) -> CMDeviceMotionHandler {
        let handler: @Sendable (CMDeviceMotion?, (any Error)?) -> Void = { data, _ in
            guard let data else { return }
            let reading = PhoneMotion.Reading(seconds: data.timestamp, roll: data.attitude.roll,
                                              pitch: data.attitude.pitch, yawRate: data.rotationRate.z,
                                              accelerationX: data.userAcceleration.x,
                                              accelerationY: data.userAcceleration.y,
                                              accelerationZ: data.userAcceleration.z)
            processor.take(reading, run: token)
        }
        return handler
    }
}
